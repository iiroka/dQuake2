/*
 * Copyright (C) 1997-2001 Id Software, Inc.
 * Copyright (C) 2019      Iiro Kaihlaniemi
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 *
 * =======================================================================
 *
 * The low level, platform independant network code
 *
 * =======================================================================
 */
import 'dart:convert';
import 'dart:typed_data';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/readbuf.dart';
import 'package:dQuakeWeb/shared/writebuf.dart';
import 'clientserver.dart';
import 'cvar.dart';
import 'net.dart';
import 'frame.dart' show curtime;

/*
 * packet header
 * -------------
 * 31	sequence
 * 1	does this message contain a reliable payload
 * 31	acknowledge sequence
 * 1	acknowledge receipt of even/odd message
 * 16	qport
 *
 * The remote connection never knows if it missed a reliable message,
 * the local side detects that it has been dropped by seeing a sequence
 * acknowledge higher thatn the last reliable sequence, but without the
 * correct even/odd bit for the reliable set.
 *
 * If the sender notices that a reliable message has been dropped, it
 * will be retransmitted.  It will not be retransmitted again until a
 * message after the retransmit has been acknowledged and the reliable
 * still failed to get there.
 *
 * if the sequence number is -1, the packet should be handled without a
 * netcon
 *
 * The reliable message can be added to at any time by doing MSG_Write*
 * (&netchan->message, <data>).
 *
 * If the message buffer is overflowed, either by a single message, or
 * by multiple frames worth piling up while the last reliable transmit
 * goes unacknowledged, the netchan signals a fatal error.
 *
 * Reliable messages are always placed first in a packet, then the
 * unreliable message is included if there is sufficient room.
 *
 * To the receiver, there is no distinction between the reliable and
 * unreliable parts of the message, they are just processed out as a
 * single larger message.
 *
 * Illogical packet sequence numbers cause the packet to be dropped, but
 * do not kill the connection.  This, combined with the tight window of
 * valid reliable acknowledgement numbers provides protection against
 * malicious address spoofing.
 *
 * The qport field is a workaround for bad address translating routers
 * that sometimes remap the client's source port on a packet during
 * gameplay.
 *
 * If the base part of the net address matches and the qport matches,
 * then the channel matches even if the IP port differs.  The IP port
 * should be updated to the new value before sending out any replies.
 *
 * If there is no information that needs to be transfered on a given
 * frame, such as during the connection stage while waiting for the
 * client to load, then a packet only needs to be delivered if there is
 * something in the unacknowledged reliable
 */

cvar_t showpackets;
cvar_t showdrop;
cvar_t qport;

Netchan_Init() {
	/* pick a port value that should be nice and random */
	int port = DateTime.now().millisecondsSinceEpoch & 0xffff;

	showpackets = Cvar_Get("showpackets", "0", 0);
	showdrop = Cvar_Get("showdrop", "0", 0);
	qport = Cvar_Get("qport", port.toString(), CVAR_NOSET);
}

/*
 * Sends an out-of-band datagram
 */
Netchan_OutOfBand(netsrc_t net_socket, netadr_t adr, Uint8List data) {

	/* write the packet header */
  var send = Writebuf.size(MAX_MSGLEN);
  send.WriteLong(-1); /* -1 sequence means out of band */
	send.Write(data);

	/* send the datagram */
	NET_SendPacket(net_socket, send.Data(), adr);
}

/*
 * Sends a text message in an out-of-band datagram
 */
Netchan_OutOfBandPrint(netsrc_t net_socket, netadr_t adr, String msg) =>
	Netchan_OutOfBand(net_socket, adr, Uint8List.fromList(Utf8Encoder().convert(msg).toList()));


class netchan_t {
	bool fatal_error = false;

	netsrc_t sock;

	int dropped = 0;                    /* between last packet and previous */

	int last_received = 0;              /* for timeouts */
	int last_sent = 0;                  /* for retransmits */

	netadr_t remote_address;
	int port = 0;                      /* qport value to write when transmitting */

	/* sequencing variables */
	int incoming_sequence = 0;
	int incoming_acknowledged = 0;
	int incoming_reliable_acknowledged = 0;         /* single bit */

	int incoming_reliable_sequence = 0;             /* single bit, maintained local */

	int outgoing_sequence = 0;
	int reliable_sequence = 0;                  /* single bit */
	int last_reliable_sequence = 0;             /* sequence number of last send */

	/* reliable staging and holding areas */
  Writebuf message = Writebuf.size(MAX_MSGLEN - 16);

	/* message is copied to this buffer when it is first transfered */
  Int8List reliable_buf;

  /*
   * called to open a channel to a remote system
   */ 
  Setup(netsrc_t sock, netadr_t adr, int qport) {
	  this.fatal_error = false;
	  this.sock = sock;
	  this.dropped = 0;
	  this.last_received = curtime;
	  this.last_sent = 0;
	  this.remote_address = adr;
    this.port = qport;
	  this.incoming_sequence = 0;  
	  this.incoming_acknowledged = 0;
	  this.incoming_reliable_acknowledged = 0;
	  this.incoming_reliable_sequence = 0;
	  this.outgoing_sequence = 1;
	  this.reliable_sequence = 0;
	  this.last_reliable_sequence = 0;
    this.message.Init();
    this.reliable_buf = null;
    this.message.allowoverflow = true;
  }

  /*
  * Returns true if the last reliable message has acked
  */
  bool CanReliable() {
    if (this.reliable_buf != null) {
      return false; /* waiting for ack */
    }
    return true;
  }

  bool NeedReliable() {

    /* if the remote side dropped the last reliable message, resend it */
    if ((this.incoming_acknowledged > this.last_reliable_sequence) &&
      (this.incoming_reliable_acknowledged != this.reliable_sequence)) {
      return true;
    }

    /* if the reliable transmit buffer is empty, copy the current message out */
    if (this.reliable_buf == null && this.message.cursize > 0) {
      return true;
    }

    return false;
  }

  /*
  * tries to send an unreliable message to a connection, and handles the
  * transmition / retransmition of the reliable messages.
  *
  * A 0 length will still generate a packet and deal with the reliable messages.
  */
  Transmit(Int8List data) {
    // sizebuf_t send;
    // byte send_buf[MAX_MSGLEN];
    // qboolean send_reliable;
    // unsigned w1, w2;

    /* check for message overflow */
    if (this.message.overflowed) {
      this.fatal_error = true;
    //   Com_Printf("%s:Outgoing message overflow\n",
    //       NET_AdrToString(chan->remote_address));
      return;
    }

    final send_reliable = this.NeedReliable();

    if (this.reliable_buf == null && this.message.cursize > 0) {
      this.reliable_buf = this.message.Data();
      this.message.cursize = 0;
      this.reliable_sequence ^= 1;
    }

    /* write the packet header */
    var send = Writebuf.size(MAX_MSGLEN);

    final w1 = (this.outgoing_sequence & 0x7FFFFFFF) | (send_reliable ? 0x80000000 : 0);
    final w2 = (this.incoming_sequence & 0x7FFFFFFF) | (this.incoming_reliable_sequence << 31);

    this.outgoing_sequence++;
    this.last_sent = curtime;

    send.WriteLong(w1);
    send.WriteLong(w2);

    /* send the qport if we are a client */
    if (this.sock == netsrc_t.NS_CLIENT) {
      send.WriteShort(qport.integer);
    }

    /* copy the reliable message to the packet first */
    if (send_reliable && this.reliable_buf != null) {
      send.Write(this.reliable_buf);
      this.last_reliable_sequence = this.outgoing_sequence;
    }

    /* add the unreliable part if space is available */
    if (data != null) {
      if (send.data.lengthInBytes - send.cursize >= data.lengthInBytes) {
        send.Write(data);
      }else {
        Com_Printf("Netchan_Transmit: dumped unreliable\n");
      }
    }

    /* send the datagram */
    NET_SendPacket(this.sock, send.Data(), this.remote_address);

    if (showpackets.boolean) {
      if (send_reliable) {
        Com_Printf("send ${send.cursize} : s=${this.outgoing_sequence - 1} reliable=${this.reliable_sequence} ack=${this.incoming_sequence} rack=${this.incoming_reliable_sequence}\n");
      } else {
        Com_Printf("send ${send.cursize} : s=${this.outgoing_sequence - 1} ack=${this.incoming_sequence} rack=${this.incoming_reliable_sequence}\n");
      }
    }
  }

  /*
  * called when the current net_message is from remote_address
  * modifies net_message so that it points to the packet payload
  */
  bool Process(Readbuf msg) {
    // unsigned sequence, sequence_ack;
    // unsigned reliable_ack, reliable_message;

    /* get sequence numbers */
    msg.BeginReading();
    var sequence = msg.ReadLong();
    var sequence_ack = msg.ReadLong();

    /* read the qport if we are a server */
    if (this.sock == netsrc_t.NS_SERVER) {
      msg.ReadShort();
    }

    final reliable_message = (sequence >> 31) & 1;
    final reliable_ack = (sequence_ack >> 31) & 1;

    sequence &= 0x7FFFFFFF;
    sequence_ack &= 0x7FFFFFFF;

    // if (showpackets->value)
    // {
    //   if (reliable_message)
    //   {
    //     Com_Printf("recv %4i : s=%i reliable=%i ack=%i rack=%i\n",
    //         msg->cursize, sequence,
    //         chan->incoming_reliable_sequence ^ 1,
    //         sequence_ack, reliable_ack);
    //   }
    //   else
    //   {
    //     Com_Printf("recv %4i : s=%i ack=%i rack=%i\n",
    //         msg->cursize, sequence, sequence_ack,
    //         reliable_ack);
    //   }
    // }

    /* discard stale or duplicated packets */
    if (sequence <= this.incoming_sequence) {
    //   if (showdrop->value)
    //   {
    //     Com_Printf("%s:Out of order packet %i at %i\n",
    //         NET_AdrToString(chan->remote_address),
    //         sequence, chan->incoming_sequence);
    //   }

      return false;
    }

    /* dropped packets don't keep the message from being used */
    this.dropped = sequence - (this.incoming_sequence + 1);

    // if (chan->dropped > 0)
    // {
    //   if (showdrop->value)
    //   {
    //     Com_Printf("%s:Dropped %i packets at %i\n",
    //         NET_AdrToString(chan->remote_address),
    //         chan->dropped, sequence);
    //   }
    // }

    /* if the current outgoing reliable message has been acknowledged
    * clear the buffer to make way for the next */
    if (reliable_ack == this.reliable_sequence) {
      this.reliable_buf = null; /* it has been received */
    }

    /* if this message contains a reliable message, bump incoming_reliable_sequence */
    this.incoming_sequence = sequence;
    this.incoming_acknowledged = sequence_ack;
    this.incoming_reliable_acknowledged = reliable_ack;

    if (reliable_message != 0) {
      this.incoming_reliable_sequence ^= 1;
    }

    /* the message can now be read from the current message pointer */
    this.last_received = curtime;

    return true;
  }

}
