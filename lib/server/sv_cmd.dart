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
 * Server commands received by clients. There are only two ways on which
 * those can be received. Typed via stdin into the server console or via
 * a network / internal communication datagram.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/cmdparser.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/filesystem.dart';
import 'sv_init.dart' show SV_Map;
import 'server.dart';
import 'sv_main.dart' show SV_Shutdown;

/*
 * Puts the server in demo mode on a specific map/cinematic
 */
SV_DemoMap_f(List<String> args) async {
	if (args.length != 2) {
		Com_Printf("USAGE: demomap <demoname.dm2>\n");
		return;
	}

	await SV_Map(true, args[1], false);
}

/*
 * Saves the state of the map just being exited and goes to a new map.
 *
 * If the initial character of the map string is '*', the next map is
 * in a new unit, so the current savegame directory is cleared of
 * map files.
 *
 * Example:
 *   inter.cin+jail
 *
 * Clears the archived maps, plays the inter.cin cinematic, then
 * goes to map jail.bsp.
 */
SV_GameMap_f(List<String> args) async {
	// char *map;
	// int i;
	// client_t *cl;
	// qboolean *savedInuse;

	if (args.length != 2) {
		Com_Printf("USAGE: gamemap <map>\n");
		return;
	}

	Com_DPrintf("SV_GameMap(${args[1]})\n");

	// FS_CreatePath(va("%s/save/current/", FS_Gamedir()));

	/* check for clearing the current savegame */
	String map = args[1];

	if (map[0] == '*') {
		/* wipe all the *.sav files */
		// SV_WipeSavegame("current");
	} else {
		/* save the map just exited */
		if (sv.state == server_state_t.ss_game) {
			/* clear all the client inuse flags before saving so that
			   when the level is re-entered, the clients will spawn
			   at spawn points instead of occupying body shells */
			// savedInuse = malloc(maxclients->value * sizeof(qboolean));

			// for (i = 0, cl = svs.clients; i < maxclients->value; i++, cl++)
			// {
			// 	savedInuse[i] = cl->edict->inuse;
			// 	cl->edict->inuse = false;
			// }

			// SV_WriteLevelFile();

			// /* we must restore these for clients to transfer over correctly */
			// for (i = 0, cl = svs.clients; i < maxclients->value; i++, cl++)
			// {
			// 	cl->edict->inuse = savedInuse[i];
			// }

			// free(savedInuse);
		}
	}

	// it's possible to start a map with the wrong case, e.g. "/map BASE1"
	// (even though the mapfile is maps/base1.bsp)
	// however, that will screw up the corresponding savegame (for going back to last map)
	// which will then be called baseq2/save/bla/BASE1.sav - because when going back to the
	// map from base2 it will look for .../base1.sav
	// so try to fix the mapname here
	// NOTE: does not properly handle all variations like base2$base1 and whatever else we forgot
	//       but so far we haven't run into problems with that anyway
	// char mapPath[MAX_QPATH];
	// {
	// 	qboolean haveStar = (map[0] == '*');
	// 	snprintf(mapPath, sizeof(mapPath), "maps/%s.bsp", haveStar ? map+1 : map);

	// 	fileHandle_t f = -1;
	// 	if(FS_FOpenFile(mapPath, &f, false) >= 0)
	// 	{
	// 		const char* realMapPath = FS_GetFilenameForHandle(f);
	// 		// now mapPath contains the fixed path
	// 		Q_strlcpy(mapPath, realMapPath, sizeof(mapPath));
	// 		FS_FCloseFile(f);

	// 		map = mapPath + 4; // skip "maps"
	// 		if(haveStar)
	// 			map[0] = '*'; // restore it (=> replace '/' by '*')
	// 		else
	// 			++map; // skip '/'

	// 		map[strlen(map)-4] = '\0'; // cut off ".bsp"
	// 	}
	// }


	/* start up the next map */
	SV_Map(false, map, false);

	/* archive server state */
	svs.mapcmd = map;

	/* copy off the level to the autosave slot */
	// if (!dedicated->value)
	// {
	// 	SV_WriteServerFile(true);
	// 	SV_CopySaveGame("current", "save0");
	// }
}

/*
 * Goes directly to a given map without any savegame archiving.
 * For development work
 */
SV_Map_f(List<String> args) async {

	if (args.length != 2) {
		Com_Printf("USAGE: map <mapname>\n");
		return;
	}

	/* if not a pcx, demo, or cinematic, check to make sure the level exists */
	final map = args[1];
	if (!map.contains(".") && !map.contains("\$") && map[0] != '*') {
	  final expanded = "maps/${map}.bsp";

		if (!await FS_CheckFile(expanded)) {
			Com_Printf("Can't find $expanded\n");
			return;
		}
	}

	sv.state = server_state_t.ss_dead; /* don't save current level when changing */
	// SV_WipeSavegame("current");
	await SV_GameMap_f(args);
}


/*
 * Kick everyone off, possibly in preparation for a new game
 */
SV_KillServer_f(List<String> args) async {
	if (!svs.initialized) {
		return;
	}

	SV_Shutdown("Server was killed.\n", false);
	// NET_Config(false);   /* close network sockets */
}


SV_InitOperatorCommands() {
	// Cmd_AddCommand("heartbeat", SV_Heartbeat_f);
	// Cmd_AddCommand("kick", SV_Kick_f);
	// Cmd_AddCommand("status", SV_Status_f);
	// Cmd_AddCommand("serverinfo", SV_Serverinfo_f);
	// Cmd_AddCommand("dumpuser", SV_DumpUser_f);

	Cmd_AddCommand("map", SV_Map_f);
	Cmd_AddCommand("demomap", SV_DemoMap_f);
	Cmd_AddCommand("gamemap", SV_GameMap_f);
	// Cmd_AddCommand("setmaster", SV_SetMaster_f);

	// if (dedicated->value)
	// {
	// 	Cmd_AddCommand("say", SV_ConSay_f);
	// }

	// Cmd_AddCommand("serverrecord", SV_ServerRecord_f);
	// Cmd_AddCommand("serverstop", SV_ServerStop_f);

	// Cmd_AddCommand("save", SV_Savegame_f);
	// Cmd_AddCommand("load", SV_Loadgame_f);

	Cmd_AddCommand("killserver", SV_KillServer_f);

	// Cmd_AddCommand("sv", SV_ServerCommand_f);
}