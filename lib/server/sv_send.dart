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
 * Message sending and multiplexing.
 *
 * =======================================================================
 */

import 'dart:typed_data';

import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/frame.dart' show curtime;
import 'package:dQuakeWeb/server/server.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/shared/writebuf.dart';
import 'sv_user.dart' show SV_Nextserver;
import 'sv_main.dart' show sv_paused;
import 'sv_entities.dart' show SV_BuildClientFrame, SV_WriteFrameToClient;

/*
 * Sends text to all active clients
 */
SV_BroadcastCommand(String msg) {

	if (sv.state.index == 0) {
		return;
	}

	sv.multicast.WriteByte(svc_ops_e.svc_stufftext.index);
	sv.multicast.WriteString(msg);
	SV_Multicast(null, multicast_t.MULTICAST_ALL_R);
}

bool SV_SendClientDatagram(client_t client) {
	// byte msg_buf[MAX_MSGLEN];
	// sizebuf_t msg;

	SV_BuildClientFrame(client);

  final msg = Writebuf.size(MAX_MSGLEN);
	msg.allowoverflow = true;

	/* send over all the relevant entity_state_t
	   and the player_state_t */
	SV_WriteFrameToClient(client, msg);

	/* copy the accumulated multicast datagram
	   for this client out to the message
	   it is necessary for this to be after the WriteEntities
	   so that entity references will be current */
	if (client.datagram.overflowed) {
		Com_Printf("WARNING: datagram overflowed for ${client.name}\n");
	} else {
		msg.Write(client.datagram.Data());
	}

	client.datagram.Clear();

	// if (msg.overflowed)
	// {
	// 	/* must have room left for the packet header */
	// 	Com_Printf("WARNING: msg overflowed for %s\n", client->name);
	// 	SZ_Clear(&msg);
	// }

	/* send the datagram */
	client.netchan.Transmit(msg.Data());

	// /* record the size for rate estimation */
	// client->message_size[sv.framenum % RATE_MESSAGES] = msg.cursize;

	return true;
}

SV_DemoCompleted() {
  sv.demoOffset = 0;
  sv.demobuffer = null;
	SV_Nextserver();
}

/*
 * Sends the contents of sv.multicast to a subset of the clients,
 * then clears sv.multicast.
 *
 * MULTICAST_ALL	same as broadcast (origin can be NULL)
 * MULTICAST_PVS	send to clients potentially visible from org
 * MULTICAST_PHS	send to clients potentially hearable from org
 */
SV_Multicast(List<double> origin, multicast_t to) {
	// client_t *client;
	// byte *mask;
	// int leafnum = 0, cluster;
	// int j;
	// qboolean reliable;
	// int area1, area2;

	bool reliable = false;

	if ((to != multicast_t.MULTICAST_ALL_R) && (to != multicast_t.MULTICAST_ALL)) {
	// 	leafnum = CM_PointLeafnum(origin);
	// 	area1 = CM_LeafArea(leafnum);
	} else {
	// 	area1 = 0;
	}

	/* if doing a serverrecord, store everything */
	// if (svs.demofile)
	// {
	// 	SZ_Write(&svs.demo_multicast, sv.multicast.data, sv.multicast.cursize);
	// }

	switch (to) {
		case multicast_t.MULTICAST_ALL_R:
			reliable = true; /* intentional fallthrough */
      continue multicast_all;
    multicast_all:
		case multicast_t.MULTICAST_ALL:
	// 		mask = NULL;
			break;

	// 	case MULTICAST_PHS_R:
	// 		reliable = true; /* intentional fallthrough */
	// 	case MULTICAST_PHS:
	// 		leafnum = CM_PointLeafnum(origin);
	// 		cluster = CM_LeafCluster(leafnum);
	// 		mask = CM_ClusterPHS(cluster);
	// 		break;

	// 	case MULTICAST_PVS_R:
	// 		reliable = true; /* intentional fallthrough */
	// 	case MULTICAST_PVS:
	// 		leafnum = CM_PointLeafnum(origin);
	// 		cluster = CM_LeafCluster(leafnum);
	// 		mask = CM_ClusterPVS(cluster);
	// 		break;

		default:
			Com_Error(ERR_FATAL, "SV_Multicast: bad to:$to");
	}

	/* send the data to all relevent clients */
	for (var client in svs.clients) {
		if ((client.state == client_state_t.cs_free) || (client.state == client_state_t.cs_zombie))  {
			continue;
		}

		if ((client.state != client_state_t.cs_spawned) && !reliable) {
			continue;
		}

	// 	if (mask)
	// 	{
	// 		leafnum = CM_PointLeafnum(client->edict->s.origin);
	// 		cluster = CM_LeafCluster(leafnum);
	// 		area2 = CM_LeafArea(leafnum);

	// 		if (!CM_AreasConnected(area1, area2))
	// 		{
	// 			continue;
	// 		}

	// 		if (mask && (!(mask[cluster >> 3] & (1 << (cluster & 7)))))
	// 		{
	// 			continue;
	// 		}
	// 	}

		if (reliable) {
			client.netchan.message.Write(sv.multicast.Data());
		} else {
			client.datagram.Write(sv.multicast.Data());
		}
	}

	sv.multicast.Clear();
}


SV_SendClientMessages() {

  Int8List msgbuf;

	/* read the next demo message if needed */
	if (sv.demobuffer != null && (sv.state == server_state_t.ss_demo)) {
		if (!sv_paused.boolean) {
			/* get the next message */
      if (sv.demoOffset + 4 > sv.demobuffer.lengthInBytes) {
  			SV_DemoCompleted();
				return;      
      }
      final msglen = sv.demobuffer.asByteData(sv.demoOffset, 4).getInt32(0, Endian.little);
      sv.demoOffset += 4;
			if (msglen == -1) {
				SV_DemoCompleted();
				return;
			}

			if (msglen > MAX_MSGLEN) {
				Com_Error(ERR_DROP,
						"SV_SendClientMessages: msglen > MAX_MSGLEN");
			}

      if (sv.demoOffset + msglen > sv.demobuffer.lengthInBytes) {
        sv.demoOffset += msglen;
  			SV_DemoCompleted();
				return;      
      }

      msgbuf = sv.demobuffer.asInt8List(sv.demoOffset, msglen);
      sv.demoOffset += msglen;
		}
	}

	/* send a message to each connected client */
	for (client_t c in svs.clients) {
		if (c.state == client_state_t.cs_free) {
			continue;
		}

		/* if the reliable message 
		   overflowed, drop the 
		   client */
		if (c.netchan.message.overflowed) {
			// c.netchan.message.Clear()
			// SZ_Clear(&c->datagram);
			// SV_BroadcastPrintf(PRINT_HIGH, "%s overflowed\n", c->name);
			// SV_DropClient(c);
		}

		if ((sv.state == server_state_t.ss_cinematic) ||
			(sv.state == server_state_t.ss_demo) ||
			(sv.state == server_state_t.ss_pic)) {
			c.netchan.Transmit(msgbuf);
		} else if (c.state == client_state_t.cs_spawned) {
			/* don't overrun bandwidth */
			// if (SV_RateDrop(c))
			// {
			// 	continue;
			// }

			SV_SendClientDatagram(c);
		} else {
			/* just update reliable	if needed */
			if (c.netchan.message.cursize > 0 ||
				(curtime - c.netchan.last_sent > 1000)) {
			c.netchan.Transmit(null);
			}
		}
	}
}