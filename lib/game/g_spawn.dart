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
 * Item spawning.
 *
 * =======================================================================
 */
import 'dart:js_util';

import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_game.dart';

import 'game.dart';
import 'g_func.dart';
import 'g_utils.dart';
import 'g_items.dart';
import 'g_main.dart' show globals;
import 'g_misc.dart';
import 'g_target.dart' show SP_target_temp_entity, SP_target_speaker, SP_target_explosion,
  SP_target_splash, SP_target_secret;
import 'g_trigger.dart' show SP_trigger_relay, SP_trigger_always, SP_trigger_once,
  SP_trigger_multiple;
import 'savegame/savegame.dart';
import 'player/client.dart' show SP_info_player_start, SaveClientData, InitBodyQue;
import 'player/trail.dart' show PlayerTrail_Init;
import 'monster/soldier/soldier.dart' show SP_monster_soldier_light, SP_monster_soldier, SP_monster_soldier_ss;
import 'monster/infantry/infantry.dart' show SP_monster_infantry;

final spawns = {
  "item_health": SP_item_health,
	"item_health_small": SP_item_health_small,
	"item_health_large": SP_item_health_large,
	"item_health_mega": SP_item_health_mega,

	"info_player_start": SP_info_player_start,

  "func_button": SP_func_button,
	"func_door": SP_func_door,
  "func_areaportal": SP_func_areaportal,
  "func_wall": SP_func_wall,
	"func_timer": SP_func_timer,

  "trigger_always": SP_trigger_always,
  "trigger_once": SP_trigger_once,
  "trigger_multiple": SP_trigger_multiple,
	"trigger_relay": SP_trigger_relay,

  "target_temp_entity": SP_target_temp_entity,
	"target_speaker": SP_target_speaker,
  "target_explosion": SP_target_explosion,
  "target_secret": SP_target_secret,
  "target_splash": SP_target_splash,

	"worldspawn": SP_worldspawn,

	"light": SP_light,
	"path_corner": SP_path_corner,
  "point_combat": SP_point_combat,

  "misc_explobox": SP_misc_explobox,
  "misc_deadsoldier": SP_misc_deadsoldier,

  "monster_infantry": SP_monster_infantry,
	"monster_soldier_light": SP_monster_soldier_light,
	"monster_soldier": SP_monster_soldier,
	"monster_soldier_ss": SP_monster_soldier_ss,

};

/*
 * Finds the spawn function for
 * the entity and calls it
 */
ED_CallSpawn(edict_t ent) async {

	if (ent == null) {
		return;
	}

	if (ent.classname == null) {
		Com_Printf("ED_CallSpawn: NULL classname\n");
		G_FreeEdict(ent);
		return;
	}

	/* check item spawn functions */
	for (var item in itemlist) {
		if (item.classname == null) {
			continue;
		}

		if (item.classname == ent.classname) {
			/* found it */
			SpawnItem(ent, item);
			return;
		}
	}

	/* check normal spawn functions */
  final s = spawns[ent.classname];
  if (s != null) {
    /* found it */
    await s(ent);
    return;
  }

	Com_Printf("${ent.classname} doesn't have a spawn function\n");
}


/*
 * Takes a key/value pair and sets
 * the binary values in an edict
 */
ED_ParseField(String key, String value, edict_t ent) {

	if (key == null || value == null) {
		return;
	}

	for (var f in fields) {
		if ((f.flags & FFL_NOSPAWN) == 0 && f.name.toLowerCase() == key.toLowerCase()) {
			/* found it */
      Object b;
			if ((f.flags & FFL_ENTS) != 0) {
        b = ent.s;
      } else if ((f.flags & FFL_SPAWNTEMP) != 0) {
				b = st;
			} else {
				b = ent;
			}

      String fname = f.fname != null ? f.fname : key;

			switch (f.type) {
				case fieldtype_t.F_LSTRING:
          setProperty(b, fname, value);
					break;
				case fieldtype_t.F_VECTOR:
          final split = value.split(" ");
          setProperty(b, fname, [ double.parse(split[0]), double.parse(split[1]), double.parse(split[2])]);
					break;
				case fieldtype_t.F_INT:
          setProperty(b, fname, int.parse(value));
					break;
				case fieldtype_t.F_FLOAT:
          setProperty(b, fname, double.parse(value));
					break;
				case fieldtype_t.F_ANGLEHACK:
          final v = double.parse(value);
          setProperty(b, fname, List<double>.from([ 0, v, 0]));
					break;
				case fieldtype_t.F_IGNORE:
					break;
				default:
					break;
			}

			return;
		}
	}

	Com_Printf("$key is not a field\n");
}

/*
 * Parses an edict out of the given string,
 * returning the new position ed should be
 * a properly initialized empty edict.
 */
int ED_ParseEdict(String data, int index, edict_t ent) {

	if (ent == null) {
		return -1;
	}

	var init = false;
  st = spawn_temp_t();

	/* go through all the dictionary pairs */
	while (true) {
		/* parse key */
		var res = COM_Parse(data, index);
    if (res == null) {
			Com_Error(ERR_DROP, "Game Error: ED_ParseEntity: EOF without closing brace");
    }
    var keyname = res.token;
    index = res.index;

		if (keyname[0] == '}') {
			break;
		}

		/* parse value */
		res = COM_Parse(data, index);
		if (res == null) {
			Com_Error(ERR_DROP, "Game Error: ED_ParseEntity: EOF without closing brace");
		}
    var token = res.token;
    index = res.index;

		if (token[0] == '}') {
			Com_Error(ERR_DROP, "Game Error: ED_ParseEntity: closing brace without data");
		}

		init = true;

		/* keynames with a leading underscore are
		   used for utility comments, and are
		   immediately discarded by quake */
		if (keyname[0] == '_') {
			continue;
		}

		ED_ParseField(keyname, token, ent);
	}

	if (!init) {
    ent.clear();
  }

	return index;
}

/*
 * Chain together all entities with a matching team field.
 *
 * All but the first will have the FL_TEAMSLAVE flag set.
 * All but the last will have the teamchain field set to the next one
 */
G_FindTeams() {
	// edict_t *e, *e2, *chain;
	// int i, j;
	// int c, c2;

	int c = 0;
	int c2 = 0;

	for (int i = 1; i < globals.num_edicts; i++) {
    var e = g_edicts[i];
		if (!e.inuse) {
			continue;
		}

		if (e.team == null) {
			continue;
		}

		if ((e.flags & FL_TEAMSLAVE) != 0) {
			continue;
		}

		edict_t chain = e;
		e.teammaster = e;
		c++;
		c2++;

		for (int j = i + 1; j < globals.num_edicts; j++) {
      var e2 = g_edicts[j];
			if (!e2.inuse) {
				continue;
			}

			if (e2.team == null) {
				continue;
			}

			if ((e2.flags & FL_TEAMSLAVE) != 0) {
				continue;
			}

			if (e.team == e2.team) {
				c2++;
				chain.teamchain = e2;
				e2.teammaster = e;
				chain = e2;
				e2.flags |= FL_TEAMSLAVE;
			}
		}
	}

	Com_Printf("$c teams with $c2 entities.\n");
}

/*
 * Creates a server's entity / program execution context by
 * parsing textual entity definitions out of an ent file.
 */
G_SpawnEntities(String mapname, String entities, String spawnpoint) async {
	// edict_t *ent;
	// int inhibit;
	// const char *com_token;
	// int i;
	// float skill_level;
	// static qboolean monster_count_city3 = false;

	if (mapname == null || entities == null || spawnpoint == null) {
		return;
	}

	int skill_level = skill.value.floor();
	if (skill_level < 0) {
		skill_level = 0;
	}

	if (skill_level > 3) {
		skill_level = 3;
	}

	if (skill.integer != skill_level) {
		Cvar_ForceSet("skill", skill_level.toString());
	}

	SaveClientData();

	// gi.FreeTags(TAG_LEVEL);

  level = level_locals_t();
  for (int i = 0; i < g_edicts.length; i++) {
    g_edicts[i].clear();
  }

	level.mapname = mapname;
	game.spawnpoint = spawnpoint;

	/* set client fields on player ents */
	for (int i = 0; i < game.maxclients; i++) {
		g_edicts[i + 1].client = game.clients[i];
	}

	edict_t ent = null;
	int inhibit = 0;

	/* parse ents */
  var index = 0;
	while (true) {
		/* parse the opening brace */
		var res = COM_Parse(entities, index);
		if (res == null) {
			break;
		}
    var token = res.token;
    index = res.index;

		if (token[0] != '{') {
	    Com_Error(ERR_DROP, "Game Error: ED_LoadFromFile: found $token when expecting {");
		}

		if (ent == null) {
			ent = g_edicts[0];
		} else {
			ent = G_Spawn();
		}

		index = ED_ParseEdict(entities, index, ent);

	// 	/* yet another map hack */
	// 	if (!Q_stricmp(level.mapname, "command") &&
	// 		!Q_stricmp(ent->classname, "trigger_once") &&
	// 	   	!Q_stricmp(ent->model, "*27"))
	// 	{
	// 		ent->spawnflags &= ~SPAWNFLAG_NOT_HARD;
	// 	}

		/*
		 * The 'monsters' count in city3.bsp is wrong.
		 * There're two monsters triggered in a hidden
		 * and unreachable room next to the security
		 * pass.
		 *
		 * We need to make sure that this hack is only
		 * applied once!
		 */
	// 	if(!Q_stricmp(level.mapname, "city3") && !monster_count_city3)
	// 	{
	// 		level.total_monsters = level.total_monsters - 2;
	// 		monster_count_city3 = true;
	// 	}

		/* remove things (except the world) from
		   different skill levels or deathmatch */
		if (ent != g_edicts[0]) {
			if (deathmatch.boolean) {
				if ((ent.spawnflags & SPAWNFLAG_NOT_DEATHMATCH) != 0) {
					G_FreeEdict(ent);
					inhibit++;
					continue;
				}
			} else {
				if (((skill.integer == 0) &&
					 (ent.spawnflags & SPAWNFLAG_NOT_EASY) != 0) ||
					((skill.integer == 1) &&
					 (ent.spawnflags & SPAWNFLAG_NOT_MEDIUM) != 0) ||
					(((skill.integer == 2) ||
					  (skill.integer == 3)) &&
					 (ent.spawnflags & SPAWNFLAG_NOT_HARD) != 0)
					)
				{
					G_FreeEdict(ent);
					inhibit++;
					continue;
				}
			}

			ent.spawnflags &=
				~(SPAWNFLAG_NOT_EASY | SPAWNFLAG_NOT_MEDIUM |
				  SPAWNFLAG_NOT_HARD |
				  SPAWNFLAG_NOT_COOP | SPAWNFLAG_NOT_DEATHMATCH);
		}

		await ED_CallSpawn(ent);
	}

	Com_Printf("$inhibit entities inhibited.\n");

	G_FindTeams();

	PlayerTrail_Init();
}

/* =================================================================== */

const single_statusbar =
	"yb	-24 "

/* health */
	"xv	0 "
	"hnum "
	"xv	50 "
	"pic 0 "

/* ammo */
	"if 2 "
	"	xv	100 "
	"	anum "
	"	xv	150 "
	"	pic 2 "
	"endif "

/* armor */
	"if 4 "
	"	xv	200 "
	"	rnum "
	"	xv	250 "
	"	pic 4 "
	"endif "

/* selected item */
	"if 6 "
	"	xv	296 "
	"	pic 6 "
	"endif "

	"yb	-50 "

/* picked up item */
	"if 7 "
	"	xv	0 "
	"	pic 7 "
	"	xv	26 "
	"	yb	-42 "
	"	stat_string 8 "
	"	yb	-50 "
	"endif "

/* timer */
	"if 9 "
	"	xv	262 "
	"	num	2	10 "
	"	xv	296 "
	"	pic	9 "
	"endif "

/*  help / weapon icon */
	"if 11 "
	"	xv	148 "
	"	pic	11 "
	"endif "
;

const dm_statusbar =
	"yb	-24 "

/* health */
	"xv	0 "
	"hnum "
	"xv	50 "
	"pic 0 "

/* ammo */
	"if 2 "
	"	xv	100 "
	"	anum "
	"	xv	150 "
	"	pic 2 "
	"endif "

/* armor */
	"if 4 "
	"	xv	200 "
	"	rnum "
	"	xv	250 "
	"	pic 4 "
	"endif "

/* selected item */
	"if 6 "
	"	xv	296 "
	"	pic 6 "
	"endif "

	"yb	-50 "

/* picked up item */
	"if 7 "
	"	xv	0 "
	"	pic 7 "
	"	xv	26 "
	"	yb	-42 "
	"	stat_string 8 "
	"	yb	-50 "
	"endif "

/* timer */
	"if 9 "
	"	xv	246 "
	"	num	2	10 "
	"	xv	296 "
	"	pic	9 "
	"endif "

/*  help / weapon icon */
	"if 11 "
	"	xv	148 "
	"	pic	11 "
	"endif "

/*  frags */
	"xr	-50 "
	"yt 2 "
	"num 3 14 "

/* spectator */
	"if 17 "
	"xv 0 "
	"yb -58 "
	"string2 \"SPECTATOR MODE\" "
	"endif "

/* chase camera */
	"if 16 "
	"xv 0 "
	"yb -68 "
	"string \"Chasing\" "
	"xv 64 "
	"stat_string 16 "
	"endif "
;


/*QUAKED worldspawn (0 0 0) ?
 *
 * Only used for the world.
 *  "sky"		environment map name
 *  "skyaxis"	vector axis for rotating sky
 *  "skyrotate"	speed of rotation in degrees/second
 *  "sounds"	music cd track number
 *  "gravity"	800 is default gravity
 *  "message"	text to print at user logon
 */
SP_worldspawn(edict_t ent) async {
	if (ent == null) {
		return;
	}

	ent.movetype = movetype_t.MOVETYPE_PUSH;
	ent.solid = solid_t.SOLID_BSP;
	ent.inuse = true; /* since the world doesn't use G_Spawn() */
	ent.s.modelindex = 1; /* world model is always index 1 */

	/* --------------- */

	/* reserve some spots for dead
	   player bodies for coop / deathmatch */
	InitBodyQue();

	/* set configstrings for items */
	SetItemNames();

	if (st.nextmap != null) {
		level.nextmap = st.nextmap;
	}

	/* make some data visible to the server */
	if (ent.message != null && ent.message.isEmpty) {
		PF_Configstring(CS_NAME, ent.message);
		level.level_name = ent.message;
	}  else {
	  level.level_name = level.mapname;
	}

	if (st.sky != null && st.sky.isNotEmpty) {
		PF_Configstring(CS_SKY, st.sky);
	} else {
		PF_Configstring(CS_SKY, "unit1_");
	}

	PF_Configstring(CS_SKYROTATE, st.skyrotate.toString());

	PF_Configstring(CS_SKYAXIS, "${st.skyaxis[0]} ${st.skyaxis[1]} ${st.skyaxis[2]}");

	PF_Configstring(CS_CDTRACK, ent.sounds.toString());

	PF_Configstring(CS_MAXCLIENTS,maxclients.integer.toString());

	/* status bar program */
	if (deathmatch.boolean) {
		PF_Configstring(CS_STATUSBAR, dm_statusbar);
	} else {
		PF_Configstring(CS_STATUSBAR, single_statusbar);
	}

	/* --------------- */

	/* help icon for statusbar */
	SV_ImageIndex("i_help");
	level.pic_health = SV_ImageIndex("i_health");
	SV_ImageIndex("help");
	SV_ImageIndex("field_3");

	// if (!st.gravity)
	// {
	// 	gi.cvar_set("sv_gravity", "800");
	// }
	// else
	// {
	// 	gi.cvar_set("sv_gravity", st.gravity);
	// }

	snd_fry = SV_SoundIndex("player/fry.wav"); /* standing in lava / slime */

	PrecacheItem(FindItem("Blaster"));

	SV_SoundIndex("player/lava1.wav");
	SV_SoundIndex("player/lava2.wav");

	SV_SoundIndex("misc/pc_up.wav");
	SV_SoundIndex("misc/talk1.wav");

	SV_SoundIndex("misc/udeath.wav");

	/* gibs */
	SV_SoundIndex("items/respawn1.wav");

	/* sexed sounds */
	SV_SoundIndex("*death1.wav");
	SV_SoundIndex("*death2.wav");
	SV_SoundIndex("*death3.wav");
	SV_SoundIndex("*death4.wav");
	SV_SoundIndex("*fall1.wav");
	SV_SoundIndex("*fall2.wav");
	SV_SoundIndex("*gurp1.wav"); /* drowning damage */
	SV_SoundIndex("*gurp2.wav");
	SV_SoundIndex("*jump1.wav"); /* player jump */
	SV_SoundIndex("*pain25_1.wav");
	SV_SoundIndex("*pain25_2.wav");
	SV_SoundIndex("*pain50_1.wav");
	SV_SoundIndex("*pain50_2.wav");
	SV_SoundIndex("*pain75_1.wav");
	SV_SoundIndex("*pain75_2.wav");
	SV_SoundIndex("*pain100_1.wav");
	SV_SoundIndex("*pain100_2.wav");

	/* sexed models: THIS ORDER MUST MATCH THE DEFINES IN g_local.h
	   you can add more, max 19 (pete change)these models are only
	   loaded in coop or deathmatch. not singleplayer. */
	// if (coop->value || deathmatch->value)
	// {
	// 	gi.modelindex("#w_blaster.md2");
	// 	gi.modelindex("#w_shotgun.md2");
	// 	gi.modelindex("#w_sshotgun.md2");
	// 	gi.modelindex("#w_machinegun.md2");
	// 	gi.modelindex("#w_chaingun.md2");
	// 	gi.modelindex("#a_grenades.md2");
	// 	gi.modelindex("#w_glauncher.md2");
	// 	gi.modelindex("#w_rlauncher.md2");
	// 	gi.modelindex("#w_hyperblaster.md2");
	// 	gi.modelindex("#w_railgun.md2");
	// 	gi.modelindex("#w_bfg.md2");
	// }

	/* ------------------- */

	SV_SoundIndex("player/gasp1.wav"); /* gasping for air */
	SV_SoundIndex("player/gasp2.wav"); /* head breaking surface, not gasping */

	SV_SoundIndex("player/watr_in.wav"); /* feet hitting water */
	SV_SoundIndex("player/watr_out.wav"); /* feet leaving water */

	SV_SoundIndex("player/watr_un.wav"); /* head going underwater */

	SV_SoundIndex("player/u_breath1.wav");
	SV_SoundIndex("player/u_breath2.wav");

	SV_SoundIndex("items/pkup.wav"); /* bonus item pickup */
	SV_SoundIndex("world/land.wav"); /* landing thud */
	SV_SoundIndex("misc/h2ohit1.wav"); /* landing splash */

	SV_SoundIndex("items/damage.wav");
	SV_SoundIndex("items/protect.wav");
	SV_SoundIndex("items/protect4.wav");
	SV_SoundIndex("weapons/noammo.wav");

	SV_SoundIndex("infantry/inflies1.wav");

	sm_meat_index = SV_ModelIndex("models/objects/gibs/sm_meat/tris.md2");
	SV_ModelIndex("models/objects/gibs/arm/tris.md2");
	SV_ModelIndex("models/objects/gibs/bone/tris.md2");
	SV_ModelIndex("models/objects/gibs/bone2/tris.md2");
	SV_ModelIndex("models/objects/gibs/chest/tris.md2");
	SV_ModelIndex("models/objects/gibs/skull/tris.md2");
	SV_ModelIndex("models/objects/gibs/head2/tris.md2");

	/* Setup light animation tables. 'a'
	   is total darkness, 'z' is doublebright. */

	/* 0 normal */
	PF_Configstring(CS_LIGHTS + 0, "m");

	/* 1 FLICKER (first variety) */
	PF_Configstring(CS_LIGHTS + 1, "mmnmmommommnonmmonqnmmo");

	/* 2 SLOW STRONG PULSE */
	PF_Configstring(CS_LIGHTS + 2, "abcdefghijklmnopqrstuvwxyzyxwvutsrqponmlkjihgfedcba");

	/* 3 CANDLE (first variety) */
	PF_Configstring(CS_LIGHTS + 3, "mmmmmaaaaammmmmaaaaaabcdefgabcdefg");

	/* 4 FAST STROBE */
	PF_Configstring(CS_LIGHTS + 4, "mamamamamama");

	/* 5 GENTLE PULSE 1 */
	PF_Configstring(CS_LIGHTS + 5, "jklmnopqrstuvwxyzyxwvutsrqponmlkj");

	/* 6 FLICKER (second variety) */
	PF_Configstring(CS_LIGHTS + 6, "nmonqnmomnmomomno");

	/* 7 CANDLE (second variety) */
	PF_Configstring(CS_LIGHTS + 7, "mmmaaaabcdefgmmmmaaaammmaamm");

	/* 8 CANDLE (third variety) */
	PF_Configstring(CS_LIGHTS + 8, "mmmaaammmaaammmabcdefaaaammmmabcdefmmmaaaa");

	/* 9 SLOW STROBE (fourth variety) */
	PF_Configstring(CS_LIGHTS + 9, "aaaaaaaazzzzzzzz");

	/* 10 FLUORESCENT FLICKER */
	PF_Configstring(CS_LIGHTS + 10, "mmamammmmammamamaaamammma");

	/* 11 SLOW PULSE NOT FADE TO BLACK */
	PF_Configstring(CS_LIGHTS + 11, "abcdefghijklmnopqrrqponmlkjihgfedcba");

	/* styles 32-62 are assigned by the light program for switchable lights */

	/* 63 testing */
	PF_Configstring(CS_LIGHTS + 63, "a");
}