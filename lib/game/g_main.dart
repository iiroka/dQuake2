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
 * Jump in into the game.so and support functions.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'game.dart';
import 'g_ai.dart' show AI_SetSightClient;
import 'g_spawn.dart' show G_SpawnEntities;
import 'g_items.dart';
import 'g_monster.dart';
import 'g_phys.dart';
import 'player/client.dart' show G_ClientConnect, ClientBeginServerFrame, 
    G_ClientBegin, G_ClientThink, G_ClientUserinfoChanged;
import 'player/view.dart';

Quake2Game globals;

/* ====================================================================== */

ClientEndServerFrames() {

	/* calc the player views now that all
	   pushing  and damage has been added */
	for (int i = 0; i < maxclients.integer; i++) {
		final ent = g_edicts[1 + i];

		if (!ent.inuse || ent.client == null) {
			continue;
		}

		ClientEndServerFrame(ent);
	}
}


class Quake2Game extends game_export_t{

  Init() {
    globals = this;
    // gi.dprintf("Game is starting up.\n");
    // gi.dprintf("Game is %s built on %s.\n", GAMEVERSION, BUILD_DATE);

    gun_x = Cvar_Get("gun_x", "0", 0);
    gun_y = Cvar_Get("gun_y", "0", 0);
    gun_z = Cvar_Get("gun_z", "0", 0);
    sv_rollspeed = Cvar_Get("sv_rollspeed", "200", 0);
    sv_rollangle = Cvar_Get("sv_rollangle", "2", 0);
    sv_maxvelocity = Cvar_Get("sv_maxvelocity", "2000", 0);
    sv_gravity = Cvar_Get("sv_gravity", "800", 0);

    /* noset vars */
    dedicated = Cvar_Get("dedicated", "0", CVAR_NOSET);

    // /* latched vars */
    sv_cheats = Cvar_Get("cheats", "0", CVAR_SERVERINFO | CVAR_LATCH);
    // Cvar_Get("gamename", GAMEVERSION, CVAR_SERVERINFO | CVAR_LATCH);
    // Cvar_Get("gamedate", BUILD_DATE, CVAR_SERVERINFO | CVAR_LATCH);
    maxclients = Cvar_Get("maxclients", "4", CVAR_SERVERINFO | CVAR_LATCH);
    maxspectators = Cvar_Get("maxspectators", "4", CVAR_SERVERINFO);
    deathmatch = Cvar_Get("deathmatch", "0", CVAR_LATCH);
    coop = Cvar_Get("coop", "0", CVAR_LATCH);
    skill = Cvar_Get("skill", "1", CVAR_LATCH);
    maxentities = Cvar_Get("maxentities", "1024", CVAR_LATCH);

    /* change anytime vars */
    dmflags = Cvar_Get("dmflags", "0", CVAR_SERVERINFO);
    fraglimit = Cvar_Get("fraglimit", "0", CVAR_SERVERINFO);
    timelimit = Cvar_Get("timelimit", "0", CVAR_SERVERINFO);
    password = Cvar_Get("password", "", CVAR_USERINFO);
    spectator_password = Cvar_Get("spectator_password", "", CVAR_USERINFO);
    needpass = Cvar_Get("needpass", "0", CVAR_SERVERINFO);
    filterban = Cvar_Get("filterban", "1", 0);
    g_select_empty = Cvar_Get("g_select_empty", "0", CVAR_ARCHIVE);
    run_pitch = Cvar_Get("run_pitch", "0.002", 0);
    run_roll = Cvar_Get("run_roll", "0.005", 0);
    bob_up = Cvar_Get("bob_up", "0.005", 0);
    bob_pitch = Cvar_Get("bob_pitch", "0.002", 0);
    bob_roll = Cvar_Get("bob_roll", "0.002", 0);

    /* flood control */
    flood_msgs = Cvar_Get("flood_msgs", "4", 0);
    flood_persecond = Cvar_Get("flood_persecond", "4", 0);
    flood_waitdelay = Cvar_Get("flood_waitdelay", "10", 0);

    /* dm map list */
    sv_maplist = Cvar_Get("sv_maplist", "", 0);

    /* items */
    InitItems();

    game.helpmessage1 = "";
    game.helpmessage2 = "";

    /* initialize all entities for this game */
    game.maxentities = maxentities.integer;
    g_edicts = List.generate(game.maxentities, (i) => edict_t(i));
    this.edicts = g_edicts;
    this.max_edicts = game.maxentities;

    /* initialize all clients for this game */
    game.maxclients = maxclients.integer;
    game.clients = List.generate(game.maxclients, (i) => gclient_t(i));
    this.num_edicts = game.maxclients + 1;
  }

  /*
  * Advances the world by 0.1 seconds
  */
  Future<void> RunFrame() async {
    // int i;
    // edict_t *ent;

    level.framenum++;
    level.time = level.framenum * FRAMETIME;

    // gibsthisframe = 0;
    // debristhisframe = 0;

    /* choose a client for monsters to target this frame */
    AI_SetSightClient();

    /* exit intermissions */
    if (level.exitintermission != 0) {
      // ExitLevel();
      return;
    }

    /* treat each object in turn
      even the world gets a chance
      to think */
    for (int i = 0; i < globals.num_edicts; i++) {
      var ent = g_edicts[i];
      if (!ent.inuse) {
        continue;
      }

      level.current_entity = ent;

      ent.s.old_origin.setAll(0, ent.s.origin);

      /* if the ground entity moved, make sure we are still on it */
      if ((ent.groundentity != null) &&
        (ent.groundentity.linkcount != ent.groundentity_linkcount)) {
        ent.groundentity = null;

        if ((ent.flags & (FL_SWIM | FL_FLY)) == 0 &&
          (ent.svflags & SVF_MONSTER) != 0) {
          M_CheckGround(ent);
        }
      }

      if ((i > 0) && (i <= maxclients.integer)) {
        ClientBeginServerFrame(ent);
        continue;
      }

      await G_RunEntity(ent);
    }

    /* see if it is time to end a deathmatch */
    // CheckDMRules();

    /* see if needpass needs updated */
    // CheckNeedPass();

    /* build the playerstate_t structures for all players */
    ClientEndServerFrames();
  }


  Future<void> SpawnEntities(String mapname, String entstring, String spawnpoint) async => await G_SpawnEntities(mapname, entstring, spawnpoint);
  Future<bool> ClientConnect(edict_s ent, String userinfo) async => await G_ClientConnect(ent as edict_t, userinfo);
  void ClientUserinfoChanged(edict_s ent, String userinfo) => G_ClientUserinfoChanged(ent, userinfo);
  void ClientBegin(edict_s ent) => G_ClientBegin(ent as edict_t);
  void ClientThink(edict_s ent, usercmd_t cmd) => G_ClientThink(ent as edict_t, cmd);
}