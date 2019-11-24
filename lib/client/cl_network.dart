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
 * This file implements generic network functions
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'package:dQuakeWeb/shared/readbuf.dart';
import 'package:dQuakeWeb/shared/writebuf.dart';

import 'client.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cmdparser.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/net.dart';
import 'package:dQuakeWeb/common/netchan.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'menu/menu.dart' show M_ForceMenuOff;
import 'cl_parse.dart' show CL_ParseServerMessage;
import 'cl_main.dart' show CL_ClearState, cl_timeout;
import 'cl_screen.dart' show SCR_EndLoadingPlaque, SCR_BeginLoadingPlaque;

CL_ForwardToServer_f(List<String> args) async {
	if ((cls.state != connstate_t.ca_connected) && (cls.state != connstate_t.ca_active)) {
		Com_Printf("Can't \"${args[0]}\", not connected\n");
		return;
	}

	/* don't forward the first argument */
	if (args.length > 1) {
		cls.netchan.message.WriteByte(clc_ops_e.clc_stringcmd.index);
    var str = StringBuffer();
    for (int i = 1; i < args.length; i++) {
      str.write(args[i]);
      if (i != (args.length - 1)) {
        str.write(" ");
      }
    }
    cls.netchan.message.WriteString(str.toString());
	}
}

/*
 * Called after an ERR_DROP was thrown
 */
CL_Drop() {
	if (cls.state == connstate_t.ca_uninitialized) {
		return;
	}

	if (cls.state == connstate_t.ca_disconnected) {
		return;
	}

	CL_Disconnect();

	/* drop loading plaque unless this is the initial game start */
	if (cls.disable_servercount != -1) {
		SCR_EndLoadingPlaque();  /* get rid of loading plaque */
	}
}

/*
 * We have gotten a challenge from the server, so try and
 * connect.
 */
CL_SendConnectPacket() {

  final adr = netadr_t.fromString(cls.servername);
	if (adr == null) {
		Com_Printf("Bad server address\n");
		cls.connect_time = 0;
		return;
	}

	if (adr.port == 0) {
		adr.port = PORT_SERVER;
	}

	final port = Cvar_VariableValue("qport");

	userinfo_modified = false;

	Netchan_OutOfBandPrint(netsrc_t.NS_CLIENT, adr, 
    "connect $PROTOCOL_VERSION $port ${cls.challenge} \"${Cvar_Userinfo()}\"\n");
}

/*
 * Resend a connect message if the last one has timed out
 */
CL_CheckForResend() {

	/* if the local server is running and we aren't just connect */
	if ((cls.state == connstate_t.ca_disconnected) && Com_ServerState() != 0) {
		cls.state = connstate_t.ca_connecting;
		cls.servername = "localhost";
		/* we don't need a challenge on the localhost */
		CL_SendConnectPacket();
		return;
	}

	/* resend if we haven't gotten a reply yet */
	if (cls.state != connstate_t.ca_connecting) {
		return;
	}

	if (cls.realtime - cls.connect_time < 3000) {
		return;
	}

  final adr = netadr_t.fromString(cls.servername);
	if (adr == null) {
		Com_Printf("Bad server address\n");
		cls.state = connstate_t.ca_disconnected;
		return;
	}
	if (adr.port == 0) {
		adr.port = PORT_SERVER;
	}

	cls.connect_time = cls.realtime.toDouble();

	Com_Printf("Connecting to ${cls.servername}...\n");

	Netchan_OutOfBandPrint(netsrc_t.NS_CLIENT, adr, "getchallenge\n");
}

/*
 * Goes from a connected state to full screen
 * console state Sends a disconnect message to
 * the server This is also called on Com_Error, so
 * it shouldn't cause any errors
 */
CL_Disconnect() {

	if (cls.state == connstate_t.ca_disconnected) {
		return;
	}

	// if (cl_timedemo && cl_timedemo->value)
	// {
	// 	int time;

	// 	time = Sys_Milliseconds() - cl.timedemo_start;

	// 	if (time > 0)
	// 	{
	// 		Com_Printf("%i frames, %3.1f seconds: %3.1f fps\n",
	// 				cl.timedemo_frames, time / 1000.0,
	// 				cl.timedemo_frames * 1000.0 / time);
	// 	}
	// }

	// VectorClear(cl.refdef.blend);

	// R_SetPalette(NULL);

	M_ForceMenuOff();

	cls.connect_time = 0;

	// SCR_StopCinematic();

	// OGG_Stop();

	// if (cls.demorecording) {
	// 	CL_Stop_f();
	// }

	/* send a disconnect message to the server */
  Writebuf send = Writebuf.size(32);
  send.WriteByte(clc_ops_e.clc_stringcmd.index);
  send.WriteString("disconnect");

	cls.netchan.Transmit(send.Data());
	cls.netchan.Transmit(send.Data());
	cls.netchan.Transmit(send.Data());

	CL_ClearState();

	/* stop file download */
	// if (cls.download) {
	// 	fclose(cls.download);
	// 	cls.download = NULL;
	// }

// #ifdef USE_CURL
// 	CL_CancelHTTPDownloads(true);
// 	cls.downloadReferer[0] = 0;
// 	cls.downloadname[0] = 0;
// 	cls.downloadposition = 0;
// #endif

	cls.state = connstate_t.ca_disconnected;

	// snd_is_underwater = false;

	// save config for old game/mod
	// CL_WriteConfiguration();

	// we disconnected, so revert to default game/mod (might have been different mod on MP server)
	// Cvar_Set("game", userGivenGame);
}

/*
 * Just sent as a hint to the client that they should
 * drop to full console
 */
CL_Changing_f(List<String> args) async {
	/* if we are downloading, we don't change!
	   This so we don't suddenly stop downloading a map */
	// if (cls.download) {
	// 	return;
	// }

	await SCR_BeginLoadingPlaque();
	cls.state = connstate_t.ca_connected; /* not active anymore, but not disconnected */
	Com_Printf("\nChanging map...\n");

// #ifdef USE_CURL
// 	if (cls.downloadServerRetry[0] != 0)
// 	{
// 		CL_SetHTTPServer(cls.downloadServerRetry);
// 	}
// #endif
}

/*
 * The server is changing levels
 */
CL_Reconnect_f(List<String> args) async {
	/* if we are downloading, we don't change!
	   This so we don't suddenly stop downloading a map */
	// if (cls.download) {
	// 	return;
	// }

	// S_StopAllSounds();

	if (cls.state == connstate_t.ca_connected) {
		Com_Printf("reconnecting...\n");
		cls.state = connstate_t.ca_connected;
		cls.netchan.message.WriteChar(clc_ops_e.clc_stringcmd.index);
		cls.netchan.message.WriteString("new");
		return;
	}

	if (cls.servername.isNotEmpty) {
		if (cls.state.index >= connstate_t.ca_connected.index) {
			CL_Disconnect();
			cls.connect_time = (cls.realtime - 1500).toDouble();
		}
		else
		{
			cls.connect_time = -99999; /* Hack: fire immediately */
		}

		cls.state = connstate_t.ca_connecting;

		Com_Printf("reconnecting...\n");
	}
}

/*
 * Responses to broadcasts, etc
 */
CL_ConnectionlessPacket(Readbuf msg, netadr_t adr) async {

	msg.BeginReading();
	msg.ReadLong(); /* skip the -1 */

	final s = msg.ReadStringLine();

	final args = Cmd_TokenizeString(s, false);

	Com_Printf("$adr: ${args[0]}\n");

// 	/* server connection */
	if (args[0] == "client_connect") {
		if (cls.state == connstate_t.ca_connected) {
			Com_Printf("Dup connect received.  Ignored.\n");
			return;
		}

		cls.netchan.Setup(netsrc_t.NS_CLIENT, adr, cls.quakePort);
// 		char *buff = NET_AdrToString(cls.netchan.remote_address);

// 		for(int i = 1; i < Cmd_Argc(); i++)
// 		{
// 			char *p = Cmd_Argv(i);

// 			if(!strncmp(p, "dlserver=", 9))
// 			{
// #ifdef USE_CURL
// 				p += 9;
// 				Com_sprintf(cls.downloadReferer, sizeof(cls.downloadReferer), "quake2://%s", buff);
// 				CL_SetHTTPServer (p);

// 				if (cls.downloadServer[0])
// 				{
// 					Com_Printf("HTTP downloading enabled, URL: %s\n", cls.downloadServer);
// 				}
// #else
// 				Com_Printf("HTTP downloading supported by server but not the client.\n");
// #endif
// 			}
// 		}

		/* Put client into pause mode when connecting to a local server.
		   This prevents the world from being forwarded while the client
		   is connecting, loading assets, etc. It's not 100%, there're
		   still 4 world frames (for baseq2) processed in the game and
		   100 frames by the server if the player enters a level that he
		   or she already visited. In practise both shouldn't be a big
		   problem. 4 frames are hardly enough for monsters staring to
		   attack and in most levels the starting area in unreachable by
		   monsters and free from environmental effects.

		   Com_Serverstate() returns 2 if the server is local and we're
		   running a real game and no timedemo, cinematic, etc. The 2 is
		   taken from the server_state_t enum value 'ss_game'. If it's a
		   local server, maxclients aus either 0 (for single player), or
		   2 to 8 (coop and deathmatch) if we're reaching this code.
		   For remote servers it's always 1. So this should trigger only
		   if it's a local single player server.

		   Since the player can load savegames from a paused state (e.g.
		   through the console) we'll need to communicate if we entered
		   paused mode (and it should left as soon as the player joined
		   the server) or if it was already there.

		   Last but not least this can be disabled by cl_loadpaused 0. */
// 		if (Com_ServerState() == 2 && (Cvar_VariableValue("maxclients") <= 1))
// 		{
// 			if (cl_loadpaused->value)
// 			{
// 				if (!cl_paused->value)
// 				{
// 					paused_at_load = true;
// 					Cvar_Set("paused", "1");
// 				}
// 			}
// 		}

		cls.netchan.message.WriteChar(clc_ops_e.clc_stringcmd.index);
		cls.netchan.message.WriteString("new");
		cls.state = connstate_t.ca_connected;
		return;
	}

// 	/* server responding to a status broadcast */
// 	if (!strcmp(c, "info"))
// 	{
// 		CL_ParseStatusMessage();
// 		return;
// 	}

	/* remote command from gui front end */
	if (args[0] == "cmd") {
		if (!adr.IsLocalAddress()) {
			Com_Printf("Command packet from remote host.  Ignored.\n");
			return;
		}

		Cbuf_AddText(msg.ReadString());
		Cbuf_AddText("\n");
		return;
	}

	/* print command from somewhere */
  if (args[0] ==  "print") {
		Com_Printf(msg.ReadString());
		return;
	}

	/* ping from somewhere */
  if (args[0] ==  "ping") {
		Netchan_OutOfBandPrint(netsrc_t.NS_CLIENT, adr, "ack");
		return;
	}

	/* challenge from the server we are connecting to */
	if (args[0] == "challenge") {
		cls.challenge = int.parse(args[1]);
		CL_SendConnectPacket();
		return;
	}

	/* echo request from server */
	if (args[0] ==  "echo") {
		Netchan_OutOfBandPrint(netsrc_t.NS_CLIENT, adr, args[1]);
		return;
	}

	Com_Printf("Unknown command.\n");
}

CL_ReadPackets() async {
  PacketInfo info;
	while ((info = NET_GetPacket(netsrc_t.NS_CLIENT)) != null) {
		/* remote command packet */
    if (info.data.buffer.asByteData().getInt32(0, Endian.little) == -1) {
			CL_ConnectionlessPacket(Readbuf(info.data), info.adr);
			continue;
		}

		if ((cls.state == connstate_t.ca_disconnected) || (cls.state == connstate_t.ca_connecting)) {
			continue; /* dump it if not connected */
		}

		if (info.data.length < 8) {
			Com_Printf("${info.adr}: Runt packet\n");
			continue;
		}


		/* packet from server */
		// if (!NET_CompareAdr(net_from, cls.netchan.remote_address))
		// {
		// 	Com_DPrintf("%s:sequenced packet without connection\n",
		// 			NET_AdrToString(net_from));
		// 	continue;
		// }

    var msg = Readbuf(info.data);
		if (!cls.netchan.Process(msg)) {
			continue; /* wasn't accepted for some reason */
		}

		await CL_ParseServerMessage(msg);
	}

	/* check timeout */
	if ((cls.state.index >= connstate_t.ca_connected.index) &&
		(cls.realtime - cls.netchan.last_received > cl_timeout.integer * 1000)) {
		if (++cl.timeoutcount > 5)
		{
			Com_Printf("\nServer connection timed out.\n");
			CL_Disconnect();
			return;
		}
	} else {
		cl.timeoutcount = 0;
	}
}

