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
 * Interface between client <-> game and client calculations.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/pmove.dart' show Pmove;
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import '../game.dart';
import '../g_items.dart';
import '../g_utils.dart';
import 'view.dart';
import 'weapon.dart';

/*
 * Some maps have no unnamed (e.g. generic)
 * info_player_start. This is no problem in
 * normal gameplay, but if the map is loaded
 * via console there is a huge chance that
 * the player will spawn in the wrong point.
 * Therefore create an unnamed info_player_start
 * at the correct point.
 */
_SP_CreateUnnamedSpawn(edict_t self) {
	final spot = G_Spawn();
	if (self == null) {
		return;
	}

	/* mine1 */
  // if (Q_stricmp(level.mapname, "mine1") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "mintro") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }

	// /* mine2 */
  //   if (Q_stricmp(level.mapname, "mine2") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "mine1") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }

	// /* mine3 */
  //   if (Q_stricmp(level.mapname, "mine3") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "mine2a") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }

	// /* mine4 */
  //   if (Q_stricmp(level.mapname, "mine4") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "mine3") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }

 	// /* power2 */
  //   if (Q_stricmp(level.mapname, "power2") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "power1") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }

	// /* waste1 */
  //   if (Q_stricmp(level.mapname, "waste1") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "power2") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }

	// /* waste2 */
  //   if (Q_stricmp(level.mapname, "waste2") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "waste1") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }

	// /* waste3 */
  //   if (Q_stricmp(level.mapname, "waste3") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "waste2") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }

	// /* city3 */
  //   if (Q_stricmp(level.mapname, "city2") == 0)
	// {
	// 	if (Q_stricmp(self->targetname, "city2NL") == 0)
	// 	{
	// 		spot->classname = self->classname;
	// 		spot->s.origin[0] = self->s.origin[0];
	// 		spot->s.origin[1] = self->s.origin[1];
	// 		spot->s.origin[2] = self->s.origin[2];
	// 		spot->s.angles[1] = self->s.angles[1];
	// 		spot->targetname = NULL;

	// 		return;
	// 	}
	// }
}

/*
 * QUAKED info_player_start (1 0 0) (-16 -16 -24) (16 16 32)
 * The normal starting point for a level.
 */
SP_info_player_start(edict_t self) async {
	if (self == null) {
		return;
	}

    /* Call function to hack unnamed spawn points */
	self.think = _SP_CreateUnnamedSpawn;
	self.nextthink = level.time + FRAMETIME;

	if (!coop.boolean) {
		return;
	}

	if (level.mapname == "security") {
		/* invoke one of our gross, ugly, disgusting hacks */
		// self.think = SP_CreateCoopSpots;
		self.nextthink = level.time + FRAMETIME;
	}
}

/* ======================================================================= */

/*
 * This is only called when the game first
 * initializes in single player, but is called
 * after each death and level change in deathmatch
 */
InitClientPersistant(gclient_t client) {

	if (client == null) {
		return;
	}

	client.pers.clear();

	var item = FindItem("Blaster");
	client.pers.selected_item = item.index;
	// client.pers.inventory[client.pers.selected_item] = 1;

	client.pers.weapon = item;

	client.pers.health = 100;
	client.pers.max_health = 100;

	client.pers.max_bullets = 200;
	client.pers.max_shells = 100;
	client.pers.max_rockets = 50;
	client.pers.max_grenades = 50;
	client.pers.max_cells = 200;
	client.pers.max_slugs = 50;

	client.pers.connected = true;
}


InitClientResp(gclient_t client) {
	if (client == null) {
		return;
	}

	client.resp.clear();
	client.resp.enterframe = level.framenum;
	client.resp.coop_respawn.copy(client.pers);
}

/*
 * Some information that should be persistant, like health,
 * is still stored in the edict structure, so it needs to
 * be mirrored out to the client structure before all the
 * edicts are wiped.
 */
SaveClientData() {

	for (int i = 0; i < game.maxclients; i++) {
		var ent = g_edicts[1 + i];

		if (!ent.inuse) {
			continue;
		}

		game.clients[i].pers.health = ent.health;
		game.clients[i].pers.max_health = ent.max_health;
		game.clients[i].pers.savedFlags = (ent.flags & (FL_GODMODE | FL_NOTARGET | FL_POWER_ARMOR));

		if (coop.boolean) {
			game.clients[i].pers.score = (ent.client as gclient_t).resp.score;
		}
	}
}

FetchClientEntData(edict_t ent) {
	if (ent == null) {
		return;
	}

	ent.health = (ent.client as gclient_t).pers.health;
	ent.max_health = (ent.client as gclient_t).pers.max_health;
	ent.flags |= (ent.client as gclient_t).pers.savedFlags;

	if (coop.boolean) {
		(ent.client as gclient_t).resp.score = (ent.client as gclient_t).pers.score;
	}
}

/*
 * Chooses a player start, deathmatch start, coop start, etc
 */
SelectSpawnPoint(edict_t ent, List<double> origin, List<double> angles) {
	// edict_t *spot = NULL;
	// edict_t *coopspot = NULL;
	// int index;
	// int counter = 0;
	// vec3_t d;

	if (ent == null) {
		return;
	}

  edict_t spot;
	if (deathmatch.boolean) {
		// spot = SelectDeathmatchSpawnPoint();
	} else if (coop.boolean) {
		// spot = SelectCoopSpawnPoint(ent);
	}

	/* find a single player start spot */
	if (spot == null) {
		while ((spot = G_Find(spot, "classname", "info_player_start")) != null) {
			if (game.spawnpoint.isEmpty && spot.targetname == null) {
				break;
			}

			if (game.spawnpoint.isEmpty || spot.targetname == null) {
				continue;
			}

			if (game.spawnpoint == spot.targetname) {
				break;
			}
		}

		if (spot == null) {
			if (game.spawnpoint.isEmpty) {
				/* there wasn't a spawnpoint without a target, so use any */
				spot = G_Find(spot, "classname", "info_player_start");
			}

			if (spot == null) {
				Com_Error(ERR_DROP, "Game Error: Couldn't find spawn point ${game.spawnpoint}\n");
			}
		}
	}

	/* If we are in coop and we didn't find a coop
	   spawnpoint due to map bugs (not correctly
	   connected or the map was loaded via console
	   and thus no previously map is known to the
	   client) use one in 550 units radius. */
	if (coop.boolean) {
		// final index = ent.client.index;

		// if (Q_stricmp(spot->classname, "info_player_start") == 0 && index != 0)
		// {
		// 	while(counter < 3)
		// 	{
		// 		coopspot = G_Find(coopspot, FOFS(classname), "info_player_coop");

		// 		if (!coopspot)
		// 		{
		// 			break;
		// 		}

		// 		VectorSubtract(coopspot->s.origin, spot->s.origin, d);

		// 		if ((VectorLength(d) < 550))
		// 		{
		// 			if (index == counter)
		// 			{
		// 				spot = coopspot;
		// 				break;
		// 			}
		// 			else
		// 			{
		// 				counter++;
		// 			}
		// 		}
		// 	}
		// }
	}

  origin.setAll(0, spot.s.origin);
	origin[2] += 9;
  angles.setAll(0, spot.s.angles);
}

/* ====================================================================== */

InitBodyQue() {
	if (deathmatch.boolean || coop.boolean) {

		level.body_que = 0;

		for (int i = 0; i < BODY_QUEUE_SIZE; i++) {
			final ent = G_Spawn();
			ent.classname = "bodyque";
		}
	}
}

/* ============================================================== */

/*
 * Called when a player connects to
 * a server or respawns in a deathmatch.
 */
PutClientInServer(edict_t ent) {

	if (ent == null) {
		return;
	}

	List<double> mins = [-16, -16, -24];
	List<double> maxs = [16, 16, 32];

	/* find a spawn point do it before setting
	   health back up, so farthest ranging
	   doesn't count this client */
  List<double> spawn_origin = [0,0,0];
  List<double> spawn_angles = [0,0,0];
	SelectSpawnPoint(ent, spawn_origin, spawn_angles);

	int index = ent.index - 1;
	var client = ent.client as gclient_t;

	/* deathmatch wipes most client data every spawn */
  var resp = client_respawn_t();
	if (deathmatch.boolean) {
		resp.copy(client.resp);
		var userinfo = String.fromCharCodes(client.pers.userinfo.codeUnits);
		InitClientPersistant(client);
		G_ClientUserinfoChanged(ent, userinfo);
	} else if (coop.boolean) {
		resp.copy(client.resp);
		var userinfo = String.fromCharCodes(client.pers.userinfo.codeUnits);
		resp.coop_respawn.game_helpchanged = client.pers.game_helpchanged;
		resp.coop_respawn.helpchanged = client.pers.helpchanged;
		client.pers.copy(resp.coop_respawn);
		G_ClientUserinfoChanged(ent, userinfo);

		if (resp.score > client.pers.score) {
			client.pers.score = resp.score;
		}
	}

  var userinfo = String.fromCharCodes(client.pers.userinfo.codeUnits);
	G_ClientUserinfoChanged(ent, userinfo);

	/* clear everything but the persistant data */
  client.clearTemp();

	if (client.pers.health <= 0) {
		InitClientPersistant(client);
	}

	client.resp.copy(resp);

	/* copy some data from the client to the entity */
	FetchClientEntData(ent);

	/* clear entity values */
	ent.groundentity = null;
	ent.client = game.clients[index];
	ent.takedamage = damage_t.DAMAGE_AIM.index;
	ent.movetype = movetype_t.MOVETYPE_WALK;
	ent.viewheight = 22;
	ent.inuse = true;
	ent.classname = "player";
	ent.mass = 200;
	ent.solid = solid_t.SOLID_BBOX;
	ent.deadflag = DEAD_NO;
	ent.air_finished = level.time + 12;
	ent.clipmask = MASK_PLAYERSOLID;
	ent.model = "players/male/tris.md2";
	// ent->pain = player_pain;
	// ent->die = player_die;
	ent.waterlevel = 0;
	ent.watertype = 0;
	ent.flags &= ~FL_NO_KNOCKBACK;
	ent.svflags = 0;

  ent.mins.setAll(0, mins);
  ent.maxs.setAll(0, maxs);
  ent.velocity.fillRange(0, 3, 0);

	/* clear playerstate values */
  ent.client.ps.clear();

	client.ps.pmove.origin[0] = (spawn_origin[0] * 8).toInt();
	client.ps.pmove.origin[1] = (spawn_origin[1] * 8).toInt();
	client.ps.pmove.origin[2] = (spawn_origin[2] * 8).toInt();

	if (deathmatch.boolean && (dmflags.integer & DF_FIXED_FOV) != 0) {
		client.ps.fov = 90;
	}
	else
	{
		client.ps.fov = (int.tryParse(Info_ValueForKey(client.pers.userinfo, "fov")) ?? 0).toDouble();
		if (client.ps.fov < 1) {
			client.ps.fov = 90;
		} else if (client.ps.fov > 160) {
			client.ps.fov = 160;
		}
	}

	client.ps.gunindex = SV_ModelIndex(client.pers.weapon.view_model);

	/* clear entity state values */
	ent.s.effects = 0;
	ent.s.modelindex = 255; /* will use the skin specified model */
	ent.s.modelindex2 = 255; /* custom gun model */

	/* sknum is player num and weapon number
	   weapon number will be added in changeweapon */
	ent.s.skinnum = ent.index - 1;

	ent.s.frame = 0;
  ent.s.origin.setAll(0, spawn_origin);
	ent.s.origin[2] += 1;  /* make sure off ground */
  ent.s.old_origin.setAll(0, ent.s.origin);

	/* set the delta angle */
	for (int i = 0; i < 3; i++) {
		client.ps.pmove.delta_angles[i] = ANGLE2SHORT(
				spawn_angles[i] - client.resp.cmd_angles[i]);
	}

	ent.s.angles[PITCH] = 0;
	ent.s.angles[YAW] = spawn_angles[YAW];
	ent.s.angles[ROLL] = 0;
  client.ps.viewangles.setAll(0, ent.s.angles);
  client.v_angle.setAll(0, ent.s.angles);

	// /* spawn a spectator */
	// if (client->pers.spectator)
	// {
	// 	client->chase_target = NULL;

	// 	client->resp.spectator = true;

	// 	ent->movetype = MOVETYPE_NOCLIP;
	// 	ent->solid = SOLID_NOT;
	// 	ent->svflags |= SVF_NOCLIENT;
	// 	ent->client->ps.gunindex = 0;
	// 	gi.linkentity(ent);
	// 	return;
	// }
	// else
	// {
		client.resp.spectator = false;
	// }

	if (!KillBox(ent)) {
		/* could't spawn in? */
	}

	SV_LinkEdict(ent);

	/* force the current weapon up */
	client.newweapon = client.pers.weapon;
	// ChangeWeapon(ent);
}

/*
 * called when a client has finished connecting, and is ready
 * to be placed into the game.  This will happen every level load.
 */
G_ClientBegin(edict_t ent) {
	if (ent == null) {
		return;
	}

	ent.client = game.clients[ent.index - 1];

	if (deathmatch.boolean) {
		// ClientBeginDeathmatch(ent);
		return;
	}

	/* if there is already a body waiting for us (a loadgame),
	   just take it, otherwise spawn one from scratch */
	if (ent.inuse == true) {
		/* the client has cleared the client side viewangles upon
		   connecting to the server, which is different than the
		   state when the game is saved, so we need to compensate
		   with deltaangles */
		for (int i = 0; i < 3; i++) {
			ent.client.ps.pmove.delta_angles[i] = ANGLE2SHORT(
					ent.client.ps.viewangles[i]);
		}
	} else {
		/* a spawn point will completely reinitialize the entity
		   except for the persistant data that was initialized at
		   ClientConnect() time */
		G_InitEdict(ent);
		ent.classname = "player";
		InitClientResp(ent.client);
		PutClientInServer(ent);
	}

	if (level.intermissiontime != 0) {
		// MoveClientToIntermission(ent);
	} else {
		/* send effect if in a multiplayer game */
		// if (game.maxclients > 1) {
		// 	gi.WriteByte(svc_muzzleflash);
		// 	gi.WriteShort(ent - g_edicts);
		// 	gi.WriteByte(MZ_LOGIN);
		// 	gi.multicast(ent->s.origin, MULTICAST_PVS);

		// 	gi.bprintf(PRINT_HIGH, "%s entered the game\n",
		// 			ent->client->pers.netname);
		// }
	}

	/* make sure all view stuff is valid */
	ClientEndServerFrame(ent);
}


/*
 * Called whenever the player updates a userinfo variable.
 * The game can override any of the settings in place
 * (forcing skins or names, etc) before copying it off.
 */
G_ClientUserinfoChanged(edict_t ent, String userinfo) {

	if (ent == null || userinfo == null) {
		return;
	}

	/* check for malformed or illegal info strings */
	if (!Info_Validate(userinfo)) {
		userinfo = "\\name\\badinfo\\skin\\male/grunt";
	}

	/* set name */
	var s = Info_ValueForKey(userinfo, "name");
	(ent.client as gclient_t).pers.netname = s;

	/* set spectator */
	s = Info_ValueForKey(userinfo, "spectator");

	/* spectators are only supported in deathmatch */
	if (deathmatch.boolean && s.isNotEmpty && s != "0") {
		(ent.client as gclient_t).pers.spectator = true;
	} else {
		(ent.client as gclient_t).pers.spectator = false;
	}

	/* set skin */
	s = Info_ValueForKey(userinfo, "skin");

	int playernum = ent.index - 1;

	/* combine name and skin into a configstring */
	PF_Configstring(CS_PLAYERSKINS + playernum,
			"${(ent.client as gclient_t).pers.netname}\\$s");

	/* fov */
	if (deathmatch.boolean && (dmflags.integer & DF_FIXED_FOV) != 0)
	{
		ent.client.ps.fov = 90;
	}
	else
	{
    ent.client.ps.fov = (int.tryParse(Info_ValueForKey(userinfo, "fov")) ?? 0).toDouble();

		if (ent.client.ps.fov < 1) {
			ent.client.ps.fov = 90;
		} else if (ent.client.ps.fov > 160) {
			ent.client.ps.fov = 160;
		}
	}

	/* handedness */
	s = Info_ValueForKey(userinfo, "hand");

	if (s.isNotEmpty) {
		(ent.client as gclient_t).pers.hand = int.parse(s);
	}

	/* save off the userinfo in case we want to check something later */
	(ent.client as gclient_t).pers.userinfo = String.fromCharCodes(userinfo.codeUnits);
}


/*
 * Called when a player begins connecting to the server.
 * The game can refuse entrance to a client by returning false.
 * If the client is allowed, the connection process will continue
 * and eventually get to ClientBegin(). Changing levels will NOT
 * cause this to be called again, but loadgames will.
 */
Future<bool> G_ClientConnect(edict_t ent, String userinfo) async {
	// char *value;

	if (ent == null || userinfo == null) {
		return false;
	}

	/* check to see if they are on the banned IP list */
	var value = Info_ValueForKey(userinfo, "ip");

	// if (SV_FilterPacket(value))
	// {
	// 	Info_SetValueForKey(userinfo, "rejmsg", "Banned.");
	// 	return false;
	// }

	/* check for a spectator */
	value = Info_ValueForKey(userinfo, "spectator");

	if (deathmatch.boolean && value.isNotEmpty && value != "0") {
	// 	int i, numspec;

	// 	if (*spectator_password->string &&
	// 		strcmp(spectator_password->string, "none") &&
	// 		strcmp(spectator_password->string, value))
	// 	{
	// 		Info_SetValueForKey(userinfo, "rejmsg",
	// 				"Spectator password required or incorrect.");
	// 		return false;
	// 	}

	// 	/* count spectators */
	// 	for (i = numspec = 0; i < maxclients->value; i++)
	// 	{
	// 		if (g_edicts[i + 1].inuse && g_edicts[i + 1].client->pers.spectator)
	// 		{
	// 			numspec++;
	// 		}
	// 	}

	// 	if (numspec >= maxspectators->value)
	// 	{
	// 		Info_SetValueForKey(userinfo, "rejmsg",
	// 				"Server spectator limit is full.");
	// 		return false;
	// 	}
	} else {
		/* check for a password */
	// 	value = Info_ValueForKey(userinfo, "password");

	// 	if (*password->string && strcmp(password->string, "none") &&
	// 		strcmp(password->string, value))
	// 	{
	// 		Info_SetValueForKey(userinfo, "rejmsg",
	// 				"Password required or incorrect.");
	// 		return false;
	// 	}
	}

	/* they can connect */
	ent.client = game.clients[ent.index - 1];

	/* if there is already a body waiting for us (a loadgame),
	   just take it, otherwise spawn one from scratch */
	if (ent.inuse == false) {
		/* clear the respawning variables */
		InitClientResp(ent.client as gclient_t);

		if (!game.autosaved || (ent.client as gclient_t).pers.weapon == null) {
			InitClientPersistant(ent.client);
		}
	}

	G_ClientUserinfoChanged(ent, userinfo);

	if (game.maxclients > 1) {
	  Com_Printf("${(ent.client as gclient_t).pers.netname} connected\n");
	}

	ent.svflags = 0; /* make sure we start with known default */
	(ent.client as gclient_t).pers.connected = true;
	return true;
}

/* ============================================================== */

edict_t pm_passent;

/*
 * pmove doesn't need to know
 * about passent and contentmask
 */
trace_t PM_trace(List<double> start, List<double> mins, List<double> maxs, List<double> end) {
	if (pm_passent.health > 0) {
		return SV_Trace(start, mins, maxs, end, pm_passent, MASK_PLAYERSOLID);
	} else {
		return SV_Trace(start, mins, maxs, end, pm_passent, MASK_DEADSOLID);
	}
}

/*
 * This will be called once for each client frame, which will
 * usually be a couple times for each server frame.
 */
G_ClientThink(edict_t ent, usercmd_t ucmd) {

	if (ent == null || ucmd == null) {
		return;
	}

	level.current_entity = ent;
	final client = ent.client as gclient_t;

	// if (level.intermissiontime)
	// {
	// 	client->ps.pmove.pm_type = PM_FREEZE;

	// 	/* can exit intermission after five seconds */
	// 	if ((level.time > level.intermissiontime + 5.0) &&
	// 		(ucmd->buttons & BUTTON_ANY))
	// 	{
	// 		level.exitintermission = true;
	// 	}

	// 	return;
	// }

	pm_passent = ent;

	if (client.chase_target != null) {
		client.resp.cmd_angles[0] = SHORT2ANGLE(ucmd.angles[0]);
		client.resp.cmd_angles[1] = SHORT2ANGLE(ucmd.angles[1]);
		client.resp.cmd_angles[2] = SHORT2ANGLE(ucmd.angles[2]);
	} else {
		/* set up for pmove */
    final pm = pmove_t();

		if (ent.movetype == movetype_t.MOVETYPE_NOCLIP) {
			client.ps.pmove.pm_type = pmtype_t.PM_SPECTATOR;
		} else if (ent.s.modelindex != 255) {
			client.ps.pmove.pm_type = pmtype_t.PM_GIB;
		} else if (ent.deadflag != 0) {
			client.ps.pmove.pm_type = pmtype_t.PM_DEAD;
		} else {
			client.ps.pmove.pm_type = pmtype_t.PM_NORMAL;
		}

		client.ps.pmove.gravity = sv_gravity.integer;
		pm.s.copy(client.ps.pmove);

		for (int i = 0; i < 3; i++) {
			pm.s.origin[i] = (ent.s.origin[i] * 8).toInt();
			/* save to an int first, in case the short overflows
			 * so we get defined behavior (at least with -fwrapv) */
			int tmpVel = (ent.velocity[i] * 8).toInt();
			pm.s.velocity[i] = tmpVel;
		}

    if (client.old_pmove == pm.s) {
      pm.snapinitial = true;
    }

		pm.cmd.copy(ucmd);

		pm.trace = PM_trace; /* adds default parms */
		pm.pointcontents = SV_PointContents;

		/* perform a pmove */
		Pmove(pm);

		/* save results of pmove */
		client.ps.pmove.copy(pm.s);
		client.old_pmove.copy(pm.s);

		for (int i = 0; i < 3; i++) {
			ent.s.origin[i] = pm.s.origin[i] * 0.125;
			ent.velocity[i] = pm.s.velocity[i] * 0.125;
		}

    ent.mins.setAll(0, pm.mins);
    ent.maxs.setAll(0, pm.maxs);

		client.resp.cmd_angles[0] = SHORT2ANGLE(ucmd.angles[0]);
		client.resp.cmd_angles[1] = SHORT2ANGLE(ucmd.angles[1]);
		client.resp.cmd_angles[2] = SHORT2ANGLE(ucmd.angles[2]);

	// 	if (ent->groundentity && !pm.groundentity && (pm.cmd.upmove >= 10) &&
	// 		(pm.waterlevel == 0))
	// 	{
	// 		gi.sound(ent, CHAN_VOICE, gi.soundindex(
	// 						"*jump1.wav"), 1, ATTN_NORM, 0);
	// 		PlayerNoise(ent, ent->s.origin, PNOISE_SELF);
	// 	}

		ent.viewheight = pm.viewheight.toInt();
		ent.waterlevel = pm.waterlevel;
		ent.watertype = pm.watertype;
		ent.groundentity = pm.groundentity;

		if (pm.groundentity != null) {
			ent.groundentity_linkcount = (pm.groundentity as edict_t).linkcount;
		}

		if (ent.deadflag != 0) {
			client.ps.viewangles[ROLL] = 40;
			client.ps.viewangles[PITCH] = -15;
			client.ps.viewangles[YAW] = client.killer_yaw;
		} else {
      client.v_angle.setAll(0, pm.viewangles);
      client.ps.viewangles.setAll(0, pm.viewangles);
		}

		SV_LinkEdict(ent);

		if (ent.movetype != movetype_t.MOVETYPE_NOCLIP) {
			G_TouchTriggers(ent);
		}

		/* touch other objects */
		for (int i = 0; i < pm.numtouch; i++) {
			var other = pm.touchents[i] as edict_t;

      int j;
			for (j = 0; j < i; j++) {
				if (pm.touchents[j] == other) {
					break;
				}
			}

			if (j != i) {
				continue; /* duplicated */
			}

			if (other.touch == null) {
				continue;
			}

			other.touch(other, ent, null, null);
		}
	}

	client.oldbuttons = client.buttons;
	client.buttons = ucmd.buttons;
	client.latched_buttons |= client.buttons & ~client.oldbuttons;

	/* save light level the player is standing
	   on for monster sighting AI */
	ent.light_level = ucmd.lightlevel;

	/* fire weapon from final position if needed */
	// if ((client.latched_buttons & BUTTON_ATTACK) != 0) {
	// 	if (client->resp.spectator)
	// 	{
	// 		client->latched_buttons = 0;

	// 		if (client->chase_target)
	// 		{
	// 			client->chase_target = NULL;
	// 			client->ps.pmove.pm_flags &= ~PMF_NO_PREDICTION;
	// 		}
	// 		else
	// 		{
	// 			GetChaseTarget(ent);
	// 		}
	// 	}
	// 	else if (!client->weapon_thunk)
	// 	{
	// 		client->weapon_thunk = true;
	// 		Think_Weapon(ent);
	// 	}
	// }

	// if (client->resp.spectator)
	// {
	// 	if (ucmd->upmove >= 10)
	// 	{
	// 		if (!(client->ps.pmove.pm_flags & PMF_JUMP_HELD))
	// 		{
	// 			client->ps.pmove.pm_flags |= PMF_JUMP_HELD;

	// 			if (client->chase_target)
	// 			{
	// 				ChaseNext(ent);
	// 			}
	// 			else
	// 			{
	// 				GetChaseTarget(ent);
	// 			}
	// 		}
	// 	}
	// 	else
	// 	{
	// 		client->ps.pmove.pm_flags &= ~PMF_JUMP_HELD;
	// 	}
	// }

	/* update chase cam if being followed */
	// for (i = 1; i <= maxclients->value; i++)
	// {
	// 	other = g_edicts + i;

	// 	if (other->inuse && (other->client->chase_target == ent))
	// 	{
	// 		UpdateChaseCam(other);
	// 	}
	// }
}

/*
 * This will be called once for each server
 * frame, before running any other entities
 * in the world.
 */
ClientBeginServerFrame(edict_t ent) {

	if (ent == null) {
		return;
	}

	if (level.intermissiontime == 0) {
		return;
	}

	var client = ent.client as gclient_t;

	if (deathmatch.boolean &&
		(client.pers.spectator != client.resp.spectator) &&
		((level.time - client.respawn_time) >= 5)) {
	// 	spectator_respawn(ent);
		return;
	}

	// /* run weapon animations if it hasn't been done by a ucmd_t */
	if (!client.weapon_thunk && !client.resp.spectator) {
		Think_Weapon(ent);
	} else {
		client.weapon_thunk = false;
	}

	if (ent.deadflag != 0) {
		/* wait for any button just going down */
		if (level.time > client.respawn_time) {
			/* in deathmatch, only wait for attack button */
      int buttonMask;
			if (deathmatch.boolean) {
				buttonMask = BUTTON_ATTACK;
			} else {
				buttonMask = -1;
			}

			if ((client.latched_buttons & buttonMask) != 0 ||
				(deathmatch.boolean && (dmflags.integer & DF_FORCE_RESPAWN) != 0)) {
	// 			respawn(ent);
				client.latched_buttons = 0;
			}
		}

		return;
	}

	/* add player trail so monsters can follow */
	if (!deathmatch.boolean) {
	// 	if (!visible(ent, PlayerTrail_LastSpot())) {
	// 		PlayerTrail_Add(ent->s.old_origin);
	// 	}
	}

	client.latched_buttons = 0;
}
