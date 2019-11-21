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
 * Server main function and correspondig stuff
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/net.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/readbuf.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/shared/writebuf.dart';
import 'server.dart';
import 'sv_cmd.dart' show SV_InitOperatorCommands;
import 'sv_conless.dart' show SV_ConnectionlessPacket;
import 'sv_send.dart' show SV_SendClientMessages;
import 'sv_user.dart' show SV_ExecuteClientMessage;
import 'sv_game.dart' show ge;

cvar_t sv_paused;
cvar_t sv_timedemo;
cvar_t sv_enforcetime;
cvar_t timeout; /* seconds without any message */
cvar_t zombietime; /* seconds to sink messages after disconnect */
cvar_t rcon_password; /* password for remote server commands */
cvar_t allow_download;
cvar_t allow_download_players;
cvar_t allow_download_models;
cvar_t allow_download_sounds;
cvar_t allow_download_maps;
cvar_t sv_airaccelerate;
cvar_t sv_noreload; /* don't reload level state when reentering */
cvar_t maxclients; /* rename sv_maxclients */
cvar_t sv_showclamp;
cvar_t hostname;
cvar_t public_server; /* should heartbeats be sent */
cvar_t sv_entfile; /* External entity files. */
cvar_t sv_downloadserver; /* Download server. */

/*
 * Called when the player is totally leaving the server, either willingly
 * or unwillingly.  This is NOT called if the entire server is quiting
 * or crashing.
 */
SV_DropClient(client_t drop) {
	/* add the disconnect */
	drop.netchan.message.WriteByte(svc_ops_e.svc_disconnect.index);

	if (drop.state == client_state_t.cs_spawned) {
		/* call the prog function for removing a client
		   this will remove the body, among other things */
		// ge.ClientDisconnect(drop.edict);
	}

	// if (drop.download) {
	// 	FS_FreeFile(drop->download);
	// 	drop->download = NULL;
	// }

	drop.state = client_state_t.cs_zombie; /* become free in a few seconds */
	drop.name = "";
}

/*
 * Pull specific info from a newly changed userinfo string
 * into a more C freindly form.
 */
SV_UserinfoChanged(client_t cl) {

	/* call prog code to allow overrides */
	// ge.ClientUserinfoChanged(cl->edict, cl->userinfo);

	/* name for C code */
	cl.name = Info_ValueForKey(cl.userinfo, "name");

	/* mask off high bit */
	// for (i = 0; i < sizeof(cl->name); i++)
	// {
	// 	cl->name[i] &= 127;
	// }

	/* rate command */
	var val = Info_ValueForKey(cl.userinfo, "rate");

	if (val.isNotEmpty) {
		cl.rate = int.parse(val);

		if (cl.rate < 100) {
			cl.rate = 100;
		}

		if (cl.rate > 15000) {
			cl.rate = 15000;
		}
	} else {
		cl.rate = 5000;
	}

	/* msg command */
	val = Info_ValueForKey(cl.userinfo, "msg");

	if (val.isNotEmpty) {
		cl.messagelevel = int.parse(val);
	}
}

/*
 * Only called at quake2.exe startup, not for each game
 */
SV_Init() {
	SV_InitOperatorCommands();

	rcon_password = Cvar_Get("rcon_password", "", 0);
	Cvar_Get("skill", "1", 0);
	Cvar_Get("deathmatch", "0", CVAR_LATCH);
	Cvar_Get("coop", "0", CVAR_LATCH);
	// Cvar_Get("dmflags", va("%i", DF_INSTANT_ITEMS), CVAR_SERVERINFO);
	Cvar_Get("fraglimit", "0", CVAR_SERVERINFO);
	Cvar_Get("timelimit", "0", CVAR_SERVERINFO);
	Cvar_Get("cheats", "0", CVAR_SERVERINFO | CVAR_LATCH);
	Cvar_Get("protocol", PROTOCOL_VERSION.toString(), CVAR_SERVERINFO | CVAR_NOSET);
	maxclients = Cvar_Get("maxclients", "1", CVAR_SERVERINFO | CVAR_LATCH);
	hostname = Cvar_Get("hostname", "noname", CVAR_SERVERINFO | CVAR_ARCHIVE);
	timeout = Cvar_Get("timeout", "125", 0);
	zombietime = Cvar_Get("zombietime", "2", 0);
	sv_showclamp = Cvar_Get("showclamp", "0", 0);
	sv_paused = Cvar_Get("paused", "0", 0);
	sv_timedemo = Cvar_Get("timedemo", "0", 0);
	sv_enforcetime = Cvar_Get("sv_enforcetime", "0", 0);
	allow_download = Cvar_Get("allow_download", "1", CVAR_ARCHIVE);
	allow_download_players = Cvar_Get("allow_download_players", "0", CVAR_ARCHIVE);
	allow_download_models = Cvar_Get("allow_download_models", "1", CVAR_ARCHIVE);
	allow_download_sounds = Cvar_Get("allow_download_sounds", "1", CVAR_ARCHIVE);
	allow_download_maps = Cvar_Get("allow_download_maps", "1", CVAR_ARCHIVE);
	sv_downloadserver = Cvar_Get ("sv_downloadserver", "", 0);

	sv_noreload = Cvar_Get("sv_noreload", "0", 0);

	sv_airaccelerate = Cvar_Get("sv_airaccelerate", "0", CVAR_LATCH);

	public_server = Cvar_Get("public", "0", 0);

	sv_entfile = Cvar_Get("sv_entfile", "1", CVAR_ARCHIVE);
}

SV_ReadPackets() async {

  PacketInfo info;
  while ((info = NET_GetPacket(netsrc_t.NS_SERVER)) != null)  {
		/* check for connectionless packet (0xffffffff) first */
    if (info.data.buffer.asByteData().getInt32(0, Endian.little) == -1) {
			await SV_ConnectionlessPacket(Readbuf(info.data), info.adr);
			continue;
		}

    final msg = Readbuf(info.data);
		/* read the qport out of the message so we can fix up
		   stupid address translating routers */
		msg.BeginReading();
		msg.ReadLong(); /* sequence number */
		msg.ReadLong(); /* sequence number */
		int qport = msg.ReadShort() & 0xffff;

		/* check for packets from connected clients */
    for (client_t cl in svs.clients) {
			if (cl.state == client_state_t.cs_free) {
				continue;
			}

		// 	if (!NET_CompareBaseAdr(net_from, cl->netchan.remote_address))
		// 	{
		// 		continue;
		// 	}

			if (cl.netchan.port != qport) {
				continue;
			}

			if (cl.netchan.remote_address.port != info.adr.port) {
				Com_Printf("SV_ReadPackets: fixing up a translated port\n");
				cl.netchan.remote_address.port = info.adr.port;
			}

			if (cl.netchan.Process(msg)) {
				/* this is a valid, sequenced packet, so process it */
				if (cl.state != client_state_t.cs_zombie) {
					cl.lastmessage = svs.realtime; /* don't timeout */

					if (!(sv.demobuffer != null && (sv.state == server_state_t.ss_demo))) {
						await SV_ExecuteClientMessage(cl, msg);
					}
				}
			}

			break;
		}

	}
}

/*
 * This has to be done before the world logic, because
 * player processing happens outside RunWorldFrame
 */
SV_PrepWorldFrame() {

	for (int i = 0; i < ge.num_edicts; i++) {
		var ent = ge.edicts[i];
		/* events only last for a single message */
		ent.s.event = 0;
	}
}

SV_RunGameFrame() async {
// #ifndef DEDICATED_ONLY
// 	if (host_speeds->value)
// 	{
// 		time_before_game = Sys_Milliseconds();
// 	}
// #endif

	/* we always need to bump framenum, even if we
	   don't run the world, otherwise the delta
	   compression can get confused when a client
	   has the "current" frame */
	sv.framenum++;
	sv.time = sv.framenum * 100;

	/* don't run if paused */
	if (!sv_paused.boolean || (maxclients.integer > 1)) {
		await ge.RunFrame();

		/* never get more than one tic behind */
		if (sv.time < svs.realtime) {
			if (sv_showclamp.boolean) {
				Com_Printf("sv highclamp ${sv.time} ${svs.realtime}\n");
			}

			svs.realtime = sv.time;
		}
	}

// #ifndef DEDICATED_ONLY
// 	if (host_speeds->value)
// 	{
// 		time_after_game = Sys_Milliseconds();
// 	}
// #endif
}


SV_Frame(int msec) async {
// #ifndef DEDICATED_ONLY
// 	time_before_game = time_after_game = 0;
// #endif

	/* if server is not active, do nothing */
	if (!svs.initialized) {
		return;
	}

	svs.realtime += msec;

	/* keep the random time dependent */
	randk();

	/* check timeouts */
	// SV_CheckTimeouts();

	/* get packets from clients */
	await SV_ReadPackets();

	/* move autonomous things around if enough time has passed */
	if (!sv_timedemo.boolean && (svs.realtime < sv.time)) {
		/* never let the time get too far off */
		if (sv.time - svs.realtime > 100) {
			if (sv_showclamp.boolean) {
				Com_Printf("sv lowclamp\n");
			}
			svs.realtime = sv.time - 100;
		}

    await Future.delayed(Duration(milliseconds: sv.time - svs.realtime));
		// NET_Sleep(sv.time - svs.realtime);
		return;
	}

	/* update ping based on the last known frame from all clients */
	// SV_CalcPings();

	/* give the clients some timeslices */
	// SV_GiveMsec();

	/* let everything in the world think and move */
	await SV_RunGameFrame();

	/* send messages back to the clients that had packets read this frame */
	SV_SendClientMessages();

	/* save the entire world state if recording a serverdemo */
	// SV_RecordDemoMessage();

	/* send a heartbeat to the master if needed */
	// Master_Heartbeat();

	/* clear teleport flags, etc for next frame */
	SV_PrepWorldFrame();
}

/*
 * Used by SV_Shutdown to send a final message to all
 * connected clients before the server goes down. The 
 * messages are sent immediately, not just stuck on the
 * outgoing message list, because the server is going
 * to totally exit after returning from this function.
 */
SV_FinalMessage(String message, bool reconnect) {
	var msg = Writebuf.size(MAX_MSGLEN);
  msg.Init();

	msg.WriteByte(svc_ops_e.svc_print.index);
	msg.WriteByte(PRINT_HIGH);
	msg.WriteString(message);

	if (reconnect) {
		msg.WriteByte(svc_ops_e.svc_reconnect.index);
	} else {
		msg.WriteByte(svc_ops_e.svc_disconnect.index);
	}

	/* stagger the packets to crutch operating system limited buffers */
	/* DG: we can't just use the maxclients cvar here for the number of clients,
	 *     because this is called by SV_Shutdown() and the shut down server might have
	 *     a different number of clients (e.g. 1 if it's single player), when maxclients
	 *     has already been set to a higher value for multiplayer (e.g. 4 for coop)
	 *     Luckily, svs.num_client_entities = maxclients->value * UPDATE_BACKUP * 64;
	 *     with the maxclients value from when the current server was started (see SV_InitGame())
	 *     so we can just calculate the right number of clients from that
	 */
	for (var cl in svs.clients) {
		if (cl.state.index >= client_state_t.cs_connected.index) {
			cl.netchan.Transmit(msg.Data());
		}
	}

	for (var cl in svs.clients) {
		if (cl.state.index >= client_state_t.cs_connected.index) {
			cl.netchan.Transmit(msg.Data());
		}
  }
}

/*
 * Called when each game quits,
 * before Sys_Quit or Sys_Error
 */
SV_Shutdown(String finalmsg, bool reconnect) {
	if (svs.clients.isNotEmpty) {
		SV_FinalMessage(finalmsg, reconnect);
	}

	// Master_Shutdown();
	// SV_ShutdownGameProgs();

	/* free current level */
  sv = server_t();
	Com_SetServerState(sv.state.index);

	/* free server static data */
  svs = server_static_t();
}
