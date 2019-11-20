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
 * Connectionless server commands.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/frame.dart' show curtime;
import 'package:dQuakeWeb/common/cmdparser.dart';
import 'package:dQuakeWeb/common/netchan.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/readbuf.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'server.dart';
import 'sv_main.dart' show SV_UserinfoChanged;
import 'sv_game.dart' show ge;

/*
 * Returns a challenge number that can be used
 * in a subsequent client_connect command.
 * We do this to prevent denial of service attacks that
 * flood the server with invalid connection IPs.  With a
 * challenge, they must give a valid IP address.
 */
SVC_GetChallenge(netadr_t adr) {

	int oldest = 0;
	int oldestTime = 0x7fffffff;

	/* see if we already have a challenge for this ip */
  int i;
	for (i = 0; i < MAX_CHALLENGES; i++) {
		if (adr == svs.challenges[i].adr) {
			break;
		}

		if (svs.challenges[i].time < oldestTime) {
			oldestTime = svs.challenges[i].time;
			oldest = i;
		}
	}

	if (i == MAX_CHALLENGES) {
		/* overwrite the oldest */
		svs.challenges[oldest].challenge = randk() & 0x7fff;
		svs.challenges[oldest].adr = adr;
		svs.challenges[oldest].time = curtime;
		i = oldest;
	}

	/* send it back */
	Netchan_OutOfBandPrint(netsrc_t.NS_SERVER, adr, "challenge ${svs.challenges[i].challenge}");
}

/*
 * A connection request that did not come from the master
 */
SVC_DirectConnect(List<String> args, netadr_t adr) async {

	Com_DPrintf("SVC_DirectConnect ()\n");

  final version = int.parse(args[1]);
	if (version != PROTOCOL_VERSION) {
		Netchan_OutOfBandPrint(netsrc_t.NS_SERVER, adr,
				"print\nServer is version $YQ2VERSION.\n");
		Com_DPrintf("    rejected connect from version $version\n");
		return;
	}

  final qport = int.parse(args[2]);
  final challenge = int.parse(args[3]);
  var userinfo = args[4];

	/* force the IP key/value pair so the game can filter based on ip */
  userinfo += "\\ip\\" + adr.toString();

	/* attractloop servers are ONLY for local clients */
	if (sv.attractloop) {
		if (!adr.IsLocalAddress()) {
			Com_Printf("Remote connect in attract loop.  Ignored.\n");
			Netchan_OutOfBandPrint(netsrc_t.NS_SERVER, adr,
					"print\nConnection refused.\n");
			return;
		}
	}

	/* see if the challenge is valid */
	if (!adr.IsLocalAddress()) {
    int i;
		for (i = 0; i < MAX_CHALLENGES; i++) {
// 			if (NET_CompareBaseAdr(net_from, svs.challenges[i].adr))
// 			{
// 				if (challenge == svs.challenges[i].challenge)
// 				{
// 					break; /* good */
// 				}

// 				Netchan_OutOfBandPrint(NS_SERVER, adr,
// 						"print\nBad challenge.\n");
// 				return;
// 			}
		}

// 		if (i == MAX_CHALLENGES)
// 		{
// 			Netchan_OutOfBandPrint(NS_SERVER, adr,
// 					"print\nNo challenge for address.\n");
// 			return;
// 		}
	}

// 	newcl = &temp;
// 	memset(newcl, 0, sizeof(client_t));

// 	/* if there is already a slot for this ip, reuse it */
// 	for (i = 0, cl = svs.clients; i < maxclients->value; i++, cl++)
// 	{
// 		if (cl->state < cs_connected)
// 		{
// 			continue;
// 		}

// 		if (NET_CompareBaseAdr(adr, cl->netchan.remote_address) &&
// 			((cl->netchan.qport == qport) ||
// 			 (adr.port == cl->netchan.remote_address.port)))
// 		{
// 			if (!NET_IsLocalAddress(adr))
// 			{
// 				Com_DPrintf("%s:reconnect rejected : too soon\n",
// 						NET_AdrToString(adr));
// 				return;
// 			}

// 			Com_Printf("%s:reconnect\n", NET_AdrToString(adr));
// 			newcl = cl;
// 			goto gotnewcl;
// 		}
// 	}

	/* find a client slot */
	client_t newcl;
  for (client_t cl in svs.clients) {
		if (cl.state == client_state_t.cs_free) {
			newcl = cl;
			break;
		}
	}

	if (newcl == null) {
		Netchan_OutOfBandPrint(netsrc_t.NS_SERVER, adr, "print\nServer is full.\n");
		Com_DPrintf("Rejected a connection.\n");
		return;
	}

// gotnewcl:

	/* build a new connection  accept the new client this
	   is the only place a client_t is ever initialized */
  newcl.clear();
	sv_client = newcl;
	int edictnum = newcl.index + 1;
	var ent = ge.edicts[edictnum];
	newcl.edict = ent;
	newcl.challenge = challenge; /* save challenge for checksumming */

	/* get the game a chance to reject this connection or modify the userinfo */
	if (!await ge.ClientConnect(ent, userinfo)) {
// 		if (*Info_ValueForKey(userinfo, "rejmsg"))
// 		{
// 			Netchan_OutOfBandPrint(NS_SERVER, adr,
// 					"print\n%s\nConnection refused.\n",
// 					Info_ValueForKey(userinfo, "rejmsg"));
// 		}
// 		else
// 		{
// 			Netchan_OutOfBandPrint(NS_SERVER, adr,
// 					"print\nConnection refused.\n");
// 		}

		Com_DPrintf("Game rejected a connection.\n");
		return;
	}

	/* parse some info from the info strings */
  newcl.userinfo = userinfo;
	SV_UserinfoChanged(newcl);

// 	/* send the connect packet to the client */
// 	if (sv_downloadserver->string[0])
// 	{
// 		Netchan_OutOfBandPrint(NS_SERVER, adr, "client_connect dlserver=%s", sv_downloadserver->string);
// 	}
// 	else
// 	{
		Netchan_OutOfBandPrint(netsrc_t.NS_SERVER, adr, "client_connect");
// 	}

  newcl.netchan.Setup(netsrc_t.NS_SERVER, adr, qport);

	newcl.state = client_state_t.cs_connected;

  newcl.datagram.Init();
	newcl.datagram.allowoverflow = true;
	newcl.lastmessage = svs.realtime;  /* don't timeout */
	newcl.lastconnect = svs.realtime;
}


/*
 * A connectionless packet has four leading 0xff
 * characters to distinguish it from a game channel.
 * Clients that are in the game can still send
 * connectionless packets.
 */
SV_ConnectionlessPacket(Readbuf msg, netadr_t from) async {
	// char *s;
	// char *c;

	msg.BeginReading();
	msg.ReadLong(); /* skip the -1 marker */

	final s = msg.ReadStringLine();
	final args = Cmd_TokenizeString(s, false);
	Com_DPrintf("Packet ${from} : ${args[0]}\n");

	// if (!strcmp(c, "ping"))
	// {
	// 	SVC_Ping();
	// }
	// else if (!strcmp(c, "ack"))
	// {
	// 	SVC_Ack();
	// }
	// else if (!strcmp(c, "status"))
	// {
	// 	SVC_Status();
	// }
	// else if (!strcmp(c, "info"))
	// {
	// 	SVC_Info();
	// }
	// else
  if (args[0] == "getchallenge") {
		SVC_GetChallenge(from);
	} else  if (args[0] == "connect") {
		await SVC_DirectConnect(args, from);
	// }
	// else if (!strcmp(c, "rcon"))
	// {
	// 	SVC_RemoteCommand();
	} else {
		Com_Printf("bad connectionless packet from $from:\n$s\n");
	}
}

