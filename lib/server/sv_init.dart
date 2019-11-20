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
 * Server startup.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/collision.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'server.dart';
import 'sv_main.dart';
import 'sv_send.dart';
import 'sv_game.dart' show SV_InitGameProgs, ge;
import 'sv_world.dart' show SV_ClearWorld;

int SV_FindIndex(String name, int start, int max, bool create) {

	if (name == null || name.isEmpty) {
		return 0;
	}

  int i;
	for (i = 1; i < max && sv.configstrings[start + i].isNotEmpty; i++) {
		if (sv.configstrings[start + i] == name) {
			return i;
		}
	}

	if (!create) {
		return 0;
	}

	if (i == max) {
		Com_Error(ERR_DROP, "*Index: overflow");
	}

	sv.configstrings[start + i] = name;
	if (sv.state != server_state_t.ss_loading) {
		/* send the update to everyone */
		sv.multicast.WriteChar(svc_ops_e.svc_configstring.index);
		sv.multicast.WriteShort(start + i);
		sv.multicast.WriteString(name);
		SV_Multicast([0,0,0], multicast_t.MULTICAST_ALL_R);
	}

	return i;
}

int SV_ModelIndex(String name) => SV_FindIndex(name, CS_MODELS, MAX_MODELS, true);

int SV_SoundIndex(String name) => SV_FindIndex(name, CS_SOUNDS, MAX_SOUNDS, true);

int SV_ImageIndex(String name) => SV_FindIndex(name, CS_IMAGES, MAX_IMAGES, true);

/*
 * Entity baselines are used to compress the update messages
 * to the clients -- only the fields that differ from the
 * baseline will be transmitted
 */
SV_CreateBaseline() {

	for (int entnum = 1; entnum < ge.num_edicts; entnum++) {
		var svent = ge.edicts[entnum];
		if (!svent.inuse) {
			continue;
		}

		if (svent.s.modelindex == 0 && svent.s.sound == 0 && svent.s.effects == 0) {
			continue;
		}

		svent.s.number = entnum;

		/* take current state as baseline */
    svent.s.old_origin.setAll(0, svent.s.origin);
		sv.baselines[entnum].copy(svent.s);
	}
}

/*
 * Change the server to a new map, taking all connected
 * clients along with it.
 */
SV_SpawnServer(String server, String spawnpoint, server_state_t serverstate,
  bool attractloop, bool loadgame) async {

	if (attractloop) {
		Cvar_Set("paused", "0");
	}

	Com_Printf("------- server initialization ------\n");
	Com_DPrintf("SpawnServer: $server\n");

  sv.demobuffer = null;

	svs.spawncount++; /* any partially connected client will be restarted */
	sv.state = server_state_t.ss_dead;
	Com_SetServerState(sv.state.index);

	/* wipe the entire per-level structure */
  sv = server_t();
	svs.realtime = 0;
	sv.loadgame = loadgame;
	sv.attractloop = attractloop;

	/* save name for levels that don't set message */
	sv.configstrings[CS_NAME] = server;

	// if (Cvar_VariableValue("deathmatch"))
	// {
	// 	sprintf(sv.configstrings[CS_AIRACCEL], "%g", sv_airaccelerate->value);
	// 	pm_airaccelerate = sv_airaccelerate->value;
	// }
	// else
	// {
	// 	strcpy(sv.configstrings[CS_AIRACCEL], "0");
	// 	pm_airaccelerate = 0;
	// }

  sv.multicast.Init();

	sv.name = server;

	/* leave slots at start for clients only */
	for (int i = 0; i < maxclients.integer; i++) {
		/* needs to reconnect */
		if (svs.clients[i].state.index > client_state_t.cs_connected.index) {
			svs.clients[i].state = client_state_t.cs_connected;
		}

		svs.clients[i].lastframe = -1;
	}

	sv.time = 1000;

	sv.name = server;
	sv.configstrings[CS_NAME] = server;

  List<int> checksum = [0];
	if (serverstate != server_state_t.ss_game) {
		sv.models[1] = await CM_LoadMap("", false, checksum); /* no real map */
	} else {
	  sv.configstrings[CS_MODELS + 1] = "maps/$server.bsp";
		sv.models[1] = await CM_LoadMap(sv.configstrings[CS_MODELS + 1],
				false, checksum);
	}

	// Com_sprintf(sv.configstrings[CS_MAPCHECKSUM],
	// 		sizeof(sv.configstrings[CS_MAPCHECKSUM]),
	// 		"%i", checksum);

	/* clear physics interaction links */
	SV_ClearWorld();

	for (int i = 1; i < CM_NumInlineModels(); i++) {
		sv.configstrings[CS_MODELS + 1 + i] = "*$i";
		sv.models[i + 1] = CM_InlineModel(sv.configstrings[CS_MODELS + 1 + i]);
	}

	/* spawn the rest of the entities on the map */
	sv.state = server_state_t.ss_loading;
	Com_SetServerState(sv.state.index);

	/* load and spawn all other entities */
	await ge.SpawnEntities(sv.name, CM_EntityString(), spawnpoint);

	/* run two frames to allow everything to settle */
	await ge.RunFrame();
	await ge.RunFrame();

	/* verify game didn't clobber important stuff */
	// if ((int)checksum !=
	// 	(int)strtol(sv.configstrings[CS_MAPCHECKSUM], (char **)NULL, 10))
	// {
	// 	Com_Error(ERR_DROP, "Game DLL corrupted server configstrings");
	// }

	/* all precaches are complete */
	sv.state = serverstate;
	Com_SetServerState(sv.state.index);

	/* create a baseline for more efficient communications */
	SV_CreateBaseline();

	// /* check for a savegame */
	// SV_CheckForSavegame();

	/* set serverinfo variable */
	Cvar_FullSet("mapname", sv.name, CVAR_SERVERINFO | CVAR_NOSET);

	Com_Printf("------------------------------------\n\n");
}

/*
 * A brand new game has been started
 */
SV_InitGame() {

	if (svs.initialized) {
		/* cause any connected clients to reconnect */
		SV_Shutdown("Server restarted\n", true);
	} else {
		/* make sure the client is down */
		// CL_Drop();
		// SCR_BeginLoadingPlaque();
	}

	/* get any latched variable changes (maxclients, etc) */
	// Cvar_GetLatchedVars();

	svs.initialized = true;

	if (Cvar_VariableBool("coop") && Cvar_VariableBool("deathmatch")) {
		Com_Printf("Deathmatch and Coop both set, disabling Coop\n");
		Cvar_FullSet("coop", "0", CVAR_SERVERINFO | CVAR_LATCH);
	}

	/* dedicated servers can't be single player and are usually DM
	   so unless they explicity set coop, force it to deathmatch */
	// if (dedicated.value) {
	// 	if (!Cvar_VariableValue("coop")) {
	// 		Cvar_FullSet("deathmatch", "1", CVAR_SERVERINFO | CVAR_LATCH);
	// 	}
	// }

	/* init clients */
	if (Cvar_VariableBool("deathmatch"))
	{
		if (maxclients.integer <= 1)
		{
			Cvar_FullSet("maxclients", "8", CVAR_SERVERINFO | CVAR_LATCH);
		}
		else if (maxclients.integer > MAX_CLIENTS)
		{
			Cvar_FullSet("maxclients", MAX_CLIENTS.toString(), CVAR_SERVERINFO | CVAR_LATCH);
		}
	}
	else if (Cvar_VariableBool("coop"))
	{
		if ((maxclients.integer <= 1) || (maxclients.integer > 4))
		{
			Cvar_FullSet("maxclients", "4", CVAR_SERVERINFO | CVAR_LATCH);
		}
	}
	else /* non-deathmatch, non-coop is one player */
	{
		Cvar_FullSet("maxclients", "1", CVAR_SERVERINFO | CVAR_LATCH);
	}

	svs.spawncount = randk();
  svs.clients = List.generate(maxclients.integer, (i) => client_t(i));
	svs.num_client_entities = maxclients.integer * UPDATE_BACKUP * 64;
	svs.client_entities = List.generate(svs.num_client_entities, (i) => entity_state_t());

	// /* init network stuff */
	// NET_Config((maxclients->value > 1));

	/* heartbeats will always be sent to the id master */
	svs.last_heartbeat = -99999; /* send immediately */
	// Com_sprintf(idmaster, sizeof(idmaster), "192.246.40.37:%i", PORT_MASTER);
	// NET_StringToAdr(idmaster, &master_adr[0]);

	/* init game */
	SV_InitGameProgs();

	for (int i = 0; i < maxclients.integer; i++){
		var ent = ge.edicts[i + 1];
		ent.s.number = i + 1;
		svs.clients[i].edict = ent;
    svs.clients[i].lastcmd.clear();
	}
}

/*
 * the full syntax is:
 *
 * map [*]<map>$<startspot>+<nextserver>
 *
 * command from the console or progs.
 * Map can also be a.cin, .pcx, or .dm2 file
 * Nextserver is used to allow a cinematic to play, then proceed to
 * another level:
 *
 *  map tram.cin+jail_e3
 */
SV_Map(bool attractloop, String levelstring, bool loadgame) async {

	sv.loadgame = loadgame;
	sv.attractloop = attractloop;

	if ((sv.state == server_state_t.ss_dead) && !sv.loadgame) {
		SV_InitGame(); /* the game is just starting */
	}

	var level = levelstring;

	/* if there is a + in the map, set nextserver to the remainder */
	int ch = level.indexOf("+");

	if (ch >= 0) {
		Cvar_Set("nextserver", "gamemap \"${level.substring(ch + 1)}\"");
    level = level.substring(0, ch);
	} else {
		Cvar_Set("nextserver", "");
	}

	/* hack for end game screen in coop mode */
// 	if (Cvar_VariableValue("coop") && !Q_stricmp(level, "victory.pcx"))
// 	{
// 		Cvar_Set("nextserver", "gamemap \"*base1\"");
// 	}

	/* if there is a $, use the remainder as a spawnpoint */
	ch = level.indexOf('\$');
  var spawnpoint = "";

	if (ch >= 0) {
    spawnpoint = level.substring(ch + 1);
    level = level.substring(0, ch);
	}

	/* skip the end-of-unit flag if necessary */
	if (level[0] == '*') {
    level = level.substring(1);
	}

  if (level.endsWith(".cin")) {
// 		SCR_BeginLoadingPlaque(); /* for local system */
		SV_BroadcastCommand("changing\n");
		await SV_SpawnServer(level, spawnpoint, server_state_t.ss_cinematic, attractloop, loadgame);
	} else   if (level.endsWith(".dm2")) {
// 		SCR_BeginLoadingPlaque(); /* for local system */
		SV_BroadcastCommand("changing\n");
		await SV_SpawnServer(level, spawnpoint, server_state_t.ss_demo, attractloop, loadgame);
	} else   if (level.endsWith(".pcx")) {
// 		SCR_BeginLoadingPlaque(); /* for local system */
		SV_BroadcastCommand("changing\n");
		await SV_SpawnServer(level, spawnpoint, server_state_t.ss_pic, attractloop, loadgame);
	} else {
// 		SCR_BeginLoadingPlaque(); /* for local system */
		SV_BroadcastCommand("changing\n");
// 		SV_SendClientMessages();
		await SV_SpawnServer(level, spawnpoint, server_state_t.ss_game, attractloop, loadgame);
// 		Cbuf_CopyToDefer();
	}

	SV_BroadcastCommand("reconnect\n");
}
