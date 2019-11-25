/*
 * Copyright (C) 1997-2001 Id Software, Inc.
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
 * Here are the client, server and game are tied together.
 *
 * =======================================================================
 */
import 'shared.dart';

/*
 * !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 *
 * THIS FILE IS _VERY_ FRAGILE AND THERE'S NOTHING IN IT THAT CAN OR
 * MUST BE CHANGED. IT'S MOST LIKELY A VERY GOOD IDEA TO CLOSE THE
 * EDITOR NOW AND NEVER LOOK BACK. OTHERWISE YOU MAY SCREW UP EVERYTHING!
 *
 * !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 */

const SVF_NOCLIENT = 0x00000001; /* don't send entity to clients, even if it has effects */
const SVF_DEADMONSTER = 0x00000002; /* treat as CONTENTS_DEADMONSTER for collision */
const SVF_MONSTER = 0x00000004; /* treat as CONTENTS_MONSTER for collision */

const MAX_ENT_CLUSTERS = 16;

enum solid_t {
	SOLID_NOT, /* no interaction with other objects */
	SOLID_TRIGGER, /* only touch when inside, after moving */
	SOLID_BBOX, /* touch on edge */
	SOLID_BSP /* bsp clip, touch on edge */
}

/* =============================================================== */

/* link_t is only used for entity area links now */
class link_t {
	link_t prev, next;
}

class gclient_s {
	player_state_t ps = player_state_t();      /* communicated by server to clients */
	int ping = 0;
	/* the game dll can add anything it wants
	   after  this point in the structure */
}

class edict_s extends link_t {
  final int index;
	entity_state_t s = entity_state_t();
	gclient_s client;
	bool inuse = false;
	int linkcount = 0;

	// link_t area;                    /* linked to a division node or leaf */

	int num_clusters = 0;               /* if -1, use headnode instead */
	List<int> clusternums = List(MAX_ENT_CLUSTERS);
	int headnode = 0;                   /* unused if num_clusters != -1 */
	int areanum = 0, areanum2 = 0;

	int svflags = 0;                    /* SVF_NOCLIENT, SVF_DEADMONSTER, SVF_MONSTER, etc */
	List<double> mins = [0,0,0], maxs = [0,0,0];
	List<double> absmin = [0,0,0], absmax = [0,0,0], size = [0,0,0];
	solid_t solid = solid_t.SOLID_NOT;
	int clipmask = 0;
	edict_s owner;

	/* the game dll can add anything it wants
	   after this point in the structure */

  edict_s(this.index);
}

/* functions exported by the game subsystem */
abstract class game_export_t {
	// int apiversion;

	/* the init function will only be called when a game starts,
	   not each time a level is loaded.  Persistant data for clients
	   and the server can be allocated in init */
	void Init();
	// void (*Shutdown)(void);

	/* each new level entered will cause a call to SpawnEntities */
	Future<void> SpawnEntities(String mapname, String entstring, String spawnpoint);

	/* Read/Write Game is for storing persistant cross level information
	   about the world state and the clients.
	   WriteGame is called every time a level is exited.
	   ReadGame is called on a loadgame. */
	// void (*WriteGame)(char *filename, qboolean autosave);
	// void (*ReadGame)(char *filename);

	/* ReadLevel is called after the default
	   map information has been loaded with
	   SpawnEntities */
	// void (*WriteLevel)(char *filename);
	// void (*ReadLevel)(char *filename);

	Future<bool> ClientConnect(edict_s ent, String userinfo);
	void ClientBegin(edict_s ent);
	void ClientUserinfoChanged(edict_s ent, String userinfo);
	// void (*ClientDisconnect)(edict_t *ent);
	// void (*ClientCommand)(edict_t *ent);
	void ClientThink(edict_s ent, usercmd_t cmd);

	Future<void> RunFrame();

	/* ServerCommand will be called when an "sv <command>"
	   command is issued on the  server console. The game can
	   issue gi.argc() / gi.argv() commands to get the rest
	   of the parameters */
	// void (*ServerCommand)(void);

	/* global variables shared between game and server */

	/* The edict array is allocated in the game dll so it
	   can vary in size from one game to another.
	   The size will be fixed when ge->Init() is called */
	List<edict_s> edicts;
	int num_edicts;             /* current number, <= max_edicts */
	int max_edicts;
}
