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
 * Network connections over IPv4, IPv6 and IPX via Winsocks.
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'package:dQuakeWeb/shared/common.dart';

const MAX_LOOPBACK = 4;

class loopback_t {
	List<Int8List> msgs = List(MAX_LOOPBACK);
	int geti = 0, sendi = 0;
}

final loopbacks = [loopback_t(), loopback_t()];

/* ============================================================================= */

Int8List NET_GetLoopPacket(netsrc_t sock) {
	final loop = loopbacks[sock.index];
	if (loop.sendi - loop.geti > MAX_LOOPBACK) {
		loop.geti = loop.sendi - MAX_LOOPBACK;
	}

	if (loop.geti >= loop.sendi) {
		return null;
	}

	final i = loop.geti & (MAX_LOOPBACK - 1);
	loop.geti++;

  return loop.msgs[i];
}

NET_SendLoopPacket(netsrc_t sock, Int8List data) {

	final loop = loopbacks[sock.index ^ 1];

	final i = loop.sendi & (MAX_LOOPBACK - 1);
	loop.sendi++;

	loop.msgs[i] = data;
}

/* ============================================================================= */

class PacketInfo {
  Int8List data;
  netadr_t adr;
}

PacketInfo NET_GetPacket(netsrc_t sock) {
	// int ret;
	// struct sockaddr_storage from;
	// socklen_t fromlen;
	// int net_socket;
	// int protocol;
	// int err;

  var data = NET_GetLoopPacket(sock);
  if (data != null) {
    final info = PacketInfo();
    info.data = data;
    info.adr = netadr_t();
    info.adr.type = netadrtype_t.NA_LOOPBACK;
    return info;
  }

	// for (protocol = 0; protocol < 3; protocol++)
	// {
	// 	if (protocol == 0)
	// 	{
	// 		net_socket = ip_sockets[sock];
	// 	}
	// 	else if (protocol == 1)
	// 	{
	// 		net_socket = ip6_sockets[sock];
	// 	}
	// 	else
	// 	{
	// 		net_socket = ipx_sockets[sock];
	// 	}

	// 	if (!net_socket)
	// 	{
	// 		continue;
	// 	}

	// 	fromlen = sizeof(from);
	// 	ret = recvfrom(net_socket, (char *)net_message->data,
	// 			net_message->maxsize, 0, (struct sockaddr *)&from,
	// 			&fromlen);

	// 	SockadrToNetadr(&from, net_from);

	// 	if (ret == -1)
	// 	{
	// 		err = WSAGetLastError();

	// 		if (err == WSAEWOULDBLOCK)
	// 		{
	// 			continue;
	// 		}

	// 		if (err == WSAEMSGSIZE)
	// 		{
	// 			Com_Printf("Warning:  Oversize packet from %s\n",
	// 					NET_AdrToString(*net_from));
	// 			continue;
	// 		}

	// 		if (dedicated->value) /* let dedicated servers continue after errors */
	// 		{
	// 			Com_Printf("NET_GetPacket: %s from %s\n", NET_ErrorString(),
	// 					NET_AdrToString(*net_from));
	// 		}
	// 		else
	// 		{
	// 			Com_Printf("NET_GetPacket: %s from %s",
	// 					NET_ErrorString(), NET_AdrToString(*net_from));
	// 		}

	// 		continue;
	// 	}

	// 	if (ret == net_message->maxsize)
	// 	{
	// 		Com_Printf("Oversize packet from %s\n", NET_AdrToString(*net_from));
	// 		continue;
	// 	}

	// 	net_message->cursize = ret;
	// 	return true;
	// }

	return null;
}

/* ============================================================================= */

NET_SendPacket(netsrc_t sock, Int8List data, netadr_t to) {

	switch (to.type)
	{
		case netadrtype_t.NA_LOOPBACK:
			NET_SendLoopPacket(sock, data);
			return;
		default:
			print("NET_SendPacket: bad address type");
			return;
	}

}