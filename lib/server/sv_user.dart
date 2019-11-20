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
 * Server side user (player entity) moving.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/filesystem.dart';
import 'package:dQuakeWeb/common/cmdparser.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/readbuf.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'server.dart';
import 'sv_main.dart';
import 'sv_game.dart' show ge;

const MAX_STRINGCMDS = 8;

edict_s sv_player;

SV_BeginDemoserver() async {

	final name = "demos/" + sv.name;
  sv.demobuffer = await FS_LoadFile(name);
  sv.demoOffset = 0;

	if (sv.demobuffer == null) {
		Com_Error(ERR_DROP, "Couldn't open $name\n");
	}
}

/*
 * Sends the first message from the server to a connected client.
 * This will be sent on the initial connection and upon each server load.
 */
SV_New_f(List<String> args) async {

	Com_DPrintf("New() from ${sv_client.name}\n");

	if (sv_client.state != client_state_t.cs_connected) {
		Com_Printf("New not valid -- already spawned\n");
		return;
	}

	/* demo servers just dump the file message */
	if (sv.state == server_state_t.ss_demo) {
		await SV_BeginDemoserver();
		return;
	}

	/* serverdata needs to go over for all types of servers
	   to make sure the protocol is right, and to set the gamedir */
	// gamedir = (char *)Cvar_VariableString("gamedir");

	// /* send the serverdata */
  sv_client.netchan.message.WriteByte(svc_ops_e.svc_serverdata.index);
  sv_client.netchan.message.WriteLong(PROTOCOL_VERSION);
  sv_client.netchan.message.WriteLong(svs.spawncount);
  sv_client.netchan.message.WriteByte(sv.attractloop ? 1 : 0);
	sv_client.netchan.message.WriteString("");

  int playernum;
	if ((sv.state == server_state_t.ss_cinematic) || (sv.state == server_state_t.ss_pic)) {
		playernum = -1;
	} else {
		playernum = sv_client.index;
	}

	sv_client.netchan.message.WriteShort(playernum);

	/* send full levelname */
	sv_client.netchan.message.WriteString(sv.configstrings[CS_NAME]);

	/* game server */
	if (sv.state == server_state_t.ss_game) {
		/* set up the entity for the client */
		var ent = ge.edicts[playernum + 1];
		ent.s.number = playernum + 1;
		sv_client.edict = ent;
    sv_client.lastcmd.clear();

		/* begin fetching configstrings */
	  sv_client.netchan.message.WriteByte(svc_ops_e.svc_stufftext.index);
		sv_client.netchan.message.WriteString("cmd configstrings ${svs.spawncount} 0\n");
	}
}

SV_Configstrings_f(List<String> args) async {
	int start;

	Com_DPrintf("Configstrings() from ${sv_client.name}\n");

	if (sv_client.state != client_state_t.cs_connected) {
		Com_Printf("configstrings not valid -- already spawned\n");
		return;
	}

	/* handle the case of a level changing while a client was connecting */
	if (int.parse(args[1]) & 0xFFFFFFFF != svs.spawncount) {
		Com_Printf("SV_Configstrings_f from different level\n");
		SV_New_f([]);
		return;
	}

	start = int.parse(args[2]);

	/* write a packet full of data */
	while (sv_client.netchan.message.cursize < MAX_MSGLEN / 2 &&
		   start < MAX_CONFIGSTRINGS) {
		if (sv.configstrings[start].isNotEmpty) {
			sv_client.netchan.message.WriteByte(svc_ops_e.svc_configstring.index);
			sv_client.netchan.message.WriteShort(start);
			sv_client.netchan.message.WriteString(sv.configstrings[start]);
		}

		start++;
	}

	/* send next command */
	if (start == MAX_CONFIGSTRINGS) {
		sv_client.netchan.message.WriteByte(svc_ops_e.svc_stufftext.index);
		sv_client.netchan.message.WriteString("cmd baselines ${svs.spawncount} 0\n");
	} else {
		sv_client.netchan.message.WriteByte(svc_ops_e.svc_stufftext.index);
		sv_client.netchan.message.WriteString("cmd configstrings ${svs.spawncount} $start\n");
	}
}

SV_Baselines_f(List<String> args) async {

	Com_DPrintf("Baselines() from ${sv_client.name}\n");

	if (sv_client.state != client_state_t.cs_connected) {
		Com_Printf("baselines not valid -- already spawned\n");
		return;
	}

	/* handle the case of a level changing while a client was connecting */
	if (int.parse(args[1]) & 0xFFFFFFFF != svs.spawncount) {
		Com_Printf("SV_Baselines_f from different level\n");
		SV_New_f([]);
		return;
	}

	var start = int.parse(args[2]);
	entity_state_t nullstate = entity_state_t();

	/* write a packet full of data */
	while (sv_client.netchan.message.cursize < MAX_MSGLEN / 2 &&
		   start < MAX_EDICTS) {
		var base = sv.baselines[start];

		if (base.modelindex != 0 || base.sound != 0 || base.effects != 0) {
			sv_client.netchan.message.WriteByte(svc_ops_e.svc_spawnbaseline.index);
			sv_client.netchan.message.WriteDeltaEntity(nullstate, base, true, true);
		}

		start++;
	}

	/* send next command */
	if (start == MAX_EDICTS) {
    sv_client.netchan.message.WriteByte(svc_ops_e.svc_stufftext.index);
		sv_client.netchan.message.WriteString("precache ${svs.spawncount}\n");
	}
	else
	{
    sv_client.netchan.message.WriteByte(svc_ops_e.svc_stufftext.index);
		sv_client.netchan.message.WriteString("cmd baselines ${svs.spawncount} $start\n");
	}
}

SV_Begin_f(List<String> args) async {

	Com_DPrintf("Begin() from ${sv_client.name}\n");

	/* handle the case of a level changing while a client was connecting */
	if (int.parse(args[1]) & 0xFFFFFFFF != svs.spawncount) {
		Com_Printf("SV_Begin_f from different level\n");
		SV_New_f([]);
		return;
	}

	sv_client.state = client_state_t.cs_spawned;

	/* call the game begin function */
	ge.ClientBegin(sv_player);

	// Cbuf_InsertFromDefer();
}

SV_Nextserver() {

	if ((sv.state == server_state_t.ss_game) ||
		((sv.state == server_state_t.ss_pic) &&
		 !Cvar_VariableBool("coop")))
	{
		return; /* can't nextserver while playing a normal game */
	}

	svs.spawncount++; /* make sure another doesn't sneak in */
	final v = Cvar_VariableString("nextserver");

	if (v == null || v.isEmpty) {
		Cbuf_AddText("killserver\n");
	} else {
		Cbuf_AddText(v);
		Cbuf_AddText("\n");
	}

	Cvar_Set("nextserver", "");
}

/*
 * A cinematic has completed or been aborted by a client, so move
 * to the next server,
 */
SV_Nextserver_f(List<String> args) async {

	if (int.parse(args[1]) & 0xFFFFFFFF != svs.spawncount) {
		Com_DPrintf("Nextserver() from wrong level, from ${sv_client.name} ${args[1]} != ${svs.spawncount}\n");
		return; /* leftover from last server */
	}

	Com_DPrintf("Nextserver() from ${sv_client.name}\n");
	SV_Nextserver();
}

final ucmds = {
  "new": SV_New_f,
  "configstrings": SV_Configstrings_f,
  "baselines": SV_Baselines_f,
  "begin": SV_Begin_f,

  "nextserver": SV_Nextserver_f
};

SV_ExecuteUserCommand(String s) {

	/* Security Fix... This is being set to false so that client's can't
	   macro expand variables on the server.  It seems unlikely that a
	   client ever ought to need to be able to do this... */
	final args = Cmd_TokenizeString(s, false);
	sv_player = sv_client.edict;

  final u = ucmds[args[0]];
  if (u != null) {
    u(args);
    return;
  }

  print("Unknwon UserCommand ${args[0]}");
	// if (!u->name && (sv.state == ss_game))
	// {
	// 	ge->ClientCommand(sv_player);
	// }
}

SV_ClientThink(client_t cl, usercmd_t cmd) async {
	cl.commandMsec -= cmd.msec;

	if ((cl.commandMsec < 0) && sv_enforcetime.boolean) {
		Com_DPrintf("commandMsec underflow from ${cl.name}\n");
		return;
	}

	// ge->ClientThink(cl->edict, cmd);
}

/*
 * The current net_message is parsed for the given client
 */
SV_ExecuteClientMessage(client_t cl, Readbuf msg) async {

	sv_client = cl;
	sv_player = sv_client.edict;

	/* only allow one move command */
	var move_issued = false;
	var stringCmdCount = 0;

	while (true)
	{
		if (msg.readcount > msg.data.lengthInBytes) {
			Com_Printf("SV_ReadClientMessage: badread\n");
			// SV_DropClient(cl);
			return;
		}

		final c = msg.ReadByte();
		if (c == -1) {
			break;
		}

		switch (clc_ops_e.values[c])
		{
			case clc_ops_e.clc_nop:
				break;

			case clc_ops_e.clc_userinfo:
				cl.userinfo = msg.ReadString();
				SV_UserinfoChanged(cl);
				break;

			case clc_ops_e.clc_move:

				if (move_issued) {
					return; /* someone is trying to cheat... */
				}

				move_issued = true;
			// 	checksumIndex = net_message.readcount;
				final checksum = msg.ReadByte();
				var lastframe = msg.ReadLong();

				if (lastframe != cl.lastframe) {
					cl.lastframe = lastframe;

					if (cl.lastframe > 0) {
			// 			cl->frame_latency[cl->lastframe & (LATENCY_COUNTS - 1)] =
			// 				svs.realtime - cl->frames[cl->lastframe & UPDATE_MASK].senttime;
					}
				}

        final oldest = usercmd_t();
			  msg.ReadDeltaUsercmd(usercmd_t(), oldest);
        final oldcmd = usercmd_t();
				msg.ReadDeltaUsercmd(oldest, oldcmd);
        final newcmd = usercmd_t();
				msg.ReadDeltaUsercmd(oldcmd, newcmd);

				if (cl.state != client_state_t.cs_spawned) {
					cl.lastframe = -1;
					break;
				}

			// 	/* if the checksum fails, ignore the rest of the packet */
			// 	calculatedChecksum = COM_BlockSequenceCRCByte(
			// 		net_message.data + checksumIndex + 1,
			// 		net_message.readcount - checksumIndex - 1,
			// 		cl->netchan.incoming_sequence);

			// 	if (calculatedChecksum != checksum)
			// 	{
			// 		Com_DPrintf("Failed command checksum for %s (%d != %d)/%d\n",
			// 				cl->name, calculatedChecksum, checksum,
			// 				cl->netchan.incoming_sequence);
			// 		return;
			// 	}

				if (!sv_paused.boolean) {
					int net_drop = cl.netchan.dropped;

					if (net_drop < 20) {
						while (net_drop > 2) {
							await SV_ClientThink(cl, cl.lastcmd);
							net_drop--;
						}

						if (net_drop > 1) {
							await SV_ClientThink(cl, oldest);
						}

						if (net_drop > 0) {
							await SV_ClientThink(cl, oldcmd);
						}
					}

					await SV_ClientThink(cl, newcmd);
				}

				cl.lastcmd.copy(newcmd);
				break;

			case clc_ops_e.clc_stringcmd:
				final s = msg.ReadString();

				/* malicious users may try using too many string commands */
				if (++stringCmdCount < MAX_STRINGCMDS) {
					SV_ExecuteUserCommand(s);
				}

				if (cl.state == client_state_t.cs_zombie) {
					return; /* disconnect command */
				}

				break;

			default:
				Com_Printf("SV_ReadClientMessage: unknown command char\n");
				// SV_DropClient(cl);
				return;

		}
	}
}
