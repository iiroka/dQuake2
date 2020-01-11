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
 * Misc. utility functions for the game logic.
 *
 * =======================================================================
 */
import 'dart:js_util';
import 'dart:math';

import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'game.dart';
import 'g_combat.dart';
import 'g_main.dart';

G_ProjectSource(List<double> point, List<double> distance, List<double> forward,
		List<double> right, List<double> result) {
	result[0] = point[0] + forward[0] * distance[0] + right[0] * distance[1];
	result[1] = point[1] + forward[1] * distance[0] + right[1] * distance[1];
	result[2] = point[2] + forward[2] * distance[0] + right[2] * distance[1] +
				distance[2];
}


/*
 * Searches all active entities for the next
 * one that holds the matching string at fieldofs
 * (use the FOFS() macro) in the structure.
 *
 * Searches beginning at the edict after from, or
 * the beginning. If NULL, NULL will be returned
 * if the end of the list is reached.
 */
edict_t G_Find(edict_t from, String field, String match) {

  int from_i = 0;
	if (from != null) {
		from_i = from.index + 1;
	}

	if (match == null || match.isEmpty) {
		return null;
	}

	for ( ; from_i < globals.num_edicts; from_i++) {
    from = g_edicts[from_i];
		if (!from.inuse) {
			continue;
		}

    final prob = getProperty(from, field);
		if (prob == null || !(prob is String)) {
			continue;
		}

		if (prob == match) {
			return from;
		}
	}

	return null;
}

/*
 * Returns entities that have origins
 * within a spherical area
 */
edict_t findradius(edict_t from, List<double> org, double rad) {

  int from_i;
	if (from == null) {
		from_i = 0;
	} else {
		from_i = from.index + 1;
	}

	for ( ; from_i < globals.num_edicts; from_i++) {
    from = g_edicts[from_i];
		if (!from.inuse) {
			continue;
		}

		if (from.solid == solid_t.SOLID_NOT) {
			continue;
		}

    List<double> eorg = List.generate(3, (j) => org[j] - (from.s.origin[j] +
					   (from.mins[j] + from.maxs[j]) * 0.5));

		if (VectorLength(eorg) > rad) {
			continue;
		}

		return from;
	}

	return null;
}


/*
 * Searches all active entities for
 * the next one that holds the matching
 * string at fieldofs (use the FOFS() macro)
 * in the structure.
 *
 * Searches beginning at the edict after from,
 * or the beginning. If NULL, NULL will be
 * returned if the end of the list is reached.
 */
edict_t G_PickTarget(String targetname) {

	if (targetname == null) {
		Com_Printf("G_PickTarget called with NULL targetname\n");
		return null;
	}

  edict_t ent;
  List<edict_t> choice = [];
	while (true)
	{
		ent = G_Find(ent, "targetname", targetname);

		if (ent == null) {
			break;
		}

		choice.add(ent);
	}

	if (choice.isEmpty) {
		Com_Printf("G_PickTarget: target $targetname not found\n");
		return null;
	}

	return choice[randk() % choice.length];
}

Think_Delay(edict_t ent) {
	if (ent == null) {
		return;
	}

	G_UseTargets(ent, ent.activator);
	G_FreeEdict(ent);
}

/*
 * The global "activator" should be set to
 * the entity that initiated the firing.
 *
 * If self.delay is set, a DelayedUse entity
 * will be created that will actually do the
 * SUB_UseTargets after that many seconds have passed.
 *
 * Centerprints any self.message to the activator.
 *
 * Search for (string)targetname in all entities that
 * match (string)self.target and call their .use function
 */
G_UseTargets(edict_t ent, edict_t activator) {

	if (ent == null || activator == null) {
		return;
	}

	/* check for a delay */
	if (ent.delay != 0) {
		/* create a temp object to fire at a later time */
		var t = G_Spawn();
		t.classname = "DelayedUse";
		t.nextthink = level.time + ent.delay;
		t.think = Think_Delay;
		t.activator = activator;

		if (activator == null) {
			Com_Printf("Think_Delay with no activator\n");
		}

		t.message = ent.message;
		t.target = ent.target;
		t.killtarget = ent.killtarget;
		return;
	}

	/* print the message */
	if ((ent.message != null) && (activator.svflags & SVF_MONSTER) == 0) {
		// gi.centerprintf(activator, ent.message);

		// if (ent.noise_index) {
		// 	gi.sound(activator, CHAN_AUTO, ent->noise_index, 1, ATTN_NORM, 0);
		// } else {
		// 	gi.sound(activator, CHAN_AUTO, gi.soundindex(
		// 					"misc/talk1.wav"), 1, ATTN_NORM, 0);
		// }
	}

	/* kill killtargets */
	if (ent.killtarget != null) {
		edict_t t = null;

		while ((t = G_Find(t, "targetname", ent.killtarget)) != null) {
			/* decrement secret count if target_secret is removed */
			if (t.classname == "target_secret") {
				level.total_secrets--;
			}
			/* same deal with target_goal, but also turn off CD music if applicable */
			else if (t.classname == "target_goal")
			{
				level.total_goals--;

				if (level.found_goals >= level.total_goals) {
					PF_Configstring (CS_CDTRACK, "0");
				}
			}

			G_FreeEdict(t);

			if (!ent.inuse) {
				Com_Printf("entity was removed while using killtargets\n");
				return;
			}
		}
	}

	/* fire targets */
	if (ent.target != null) {
		edict_t t = null;

		while ((t = G_Find(t, "targetname", ent.target)) != null) {
			/* doors fire area portals in a specific way */
			if ((t.classname == "func_areaportal") &&
				(ent.classname == "func_door" ||
				 ent.classname == "func_door_rotating")) {
				continue;
			}

			if (t == ent) {
				Com_Printf("WARNING: Entity used itself.\n");
			} else {
				if (t.use != null) {
					t.use(t, ent, activator);
				}
			}

			if (!ent.inuse) {
				Com_Printf("entity was removed while using targets\n");
				return;
			}
		}
	}
}

const List<double> VEC_UP = [0, -1, 0];
const List<double> MOVEDIR_UP = [0, 0, 1];
const List<double> VEC_DOWN = [0, -2, 0];
const List<double> MOVEDIR_DOWN = [0, 0, -1];

G_SetMovedir(List<double> angles, List<double> movedir) {
	if (angles == VEC_UP) {
    movedir.setAll(0, MOVEDIR_UP);
	} else if (angles == VEC_DOWN) {
    movedir.setAll(0, MOVEDIR_DOWN);
	} else {
		AngleVectors(angles, movedir, null, null);
	}
	angles.fillRange(0, 3, 0);
}

double vectoyaw(List<double> vec) {
	double yaw = 0;

	if (vec[PITCH] == 0)
	{
		yaw = 0;

		if (vec[YAW] > 0)
		{
			yaw = 90;
		}
		else if (vec[YAW] < 0)
		{
			yaw = -90;
		}
	}
	else
	{
		yaw = (atan2(vec[YAW], vec[PITCH]) * 180 / pi);

		if (yaw < 0)
		{
			yaw += 360;
		}
	}

	return yaw;
}

vectoangles(List<double> value1, List<double> angles) {
	double yaw, pitch;

	if ((value1[1] == 0) && (value1[0] == 0))
	{
		yaw = 0;

		if (value1[2] > 0)
		{
			pitch = 90;
		}
		else
		{
			pitch = 270;
		}
	}
	else
	{
		if (value1[0] != 0)
		{
			yaw = (atan2(value1[1], value1[0]) * 180 ~/ pi).toDouble();
		}
		else if (value1[1] > 0)
		{
			yaw = 90;
		}
		else
		{
			yaw = -90;
		}

		if (yaw < 0)
		{
			yaw += 360;
		}

		double forward = sqrt(value1[0] * value1[0] + value1[1] * value1[1]);
		pitch = (atan2(value1[2], forward) * 180 ~/ pi).toDouble();

		if (pitch < 0)
		{
			pitch += 360;
		}
	}

	angles[PITCH] = -pitch;
	angles[YAW] = yaw;
	angles[ROLL] = 0;
}

G_InitEdict(edict_t e) {
	e.inuse = true;
	e.classname = "noclass";
	e.gravity = 1.0;
  e.s.number = e.index;
}

/*
 * Either finds a free edict, or allocates a
 * new one.  Try to avoid reusing an entity
 * that was recently freed, because it can
 * cause the client to think the entity
 * morphed into something else instead of
 * being removed and recreated, which can
 * cause interpolated angles and bad trails.
 */
edict_t G_Spawn() {

  int i;
	for (i = maxclients.integer + 1; i < globals.num_edicts; i++) {
	  final e = g_edicts[i];
		/* the first couple seconds of
		   server time can involve a lot of
		   freeing and allocating, so relax
		   the replacement policy */
		if (!e.inuse && ((e.freetime < 2) || (level.time - e.freetime > 0.5))) {
			G_InitEdict(e);
			return e;
		}
	}

	if (i == game.maxentities) {
		Com_Error(ERR_DROP, "Game Error: ED_Alloc: no free edicts");
	}

  final e = g_edicts[i];
	globals.num_edicts++;
	G_InitEdict(e);
	return e;
}

/*
 * Marks the edict as free
 */
G_FreeEdict(edict_t ed) {
	SV_UnlinkEdict(ed); /* unlink from world */

	if (deathmatch.boolean || coop.boolean) {
		if (ed.index <= (maxclients.integer + BODY_QUEUE_SIZE)) {
			return;
		}
	} else {
		if (ed.index <= maxclients.integer) {
			return;
		}
	}

	ed.clear();
	ed.classname = "freed";
	ed.freetime = level.time;
	ed.inuse = false;
}

G_TouchTriggers(edict_t ent) {

	if (ent == null) {
		return;
	}

	/* dead things don't activate triggers! */
	if ((ent.client != null || (ent.svflags & SVF_MONSTER) != 0) && (ent.health <= 0)) {
		return;
	}

	var touch = SV_AreaEdicts(ent.absmin, ent.absmax, AREA_TRIGGERS);

	/* be careful, it is possible to have an entity in this
	   list removed before we get to it (killtriggered) */
	for (int i = 0; i < touch.length; i++) {
		var hit = touch[i] as edict_t;

		if (!hit.inuse) {
			continue;
		}

		if (hit.touch == null) {
			continue;
		}

		hit.touch(hit, ent, null, null);
	}
}

/*
 * Kills all entities that would touch the
 * proposed new positioning of ent. Ent s
 * hould be unlinked before calling this!
 */
bool KillBox(edict_t ent) {

	if (ent == null) {
		return false;
	}

	while (true) {
		final tr = SV_Trace(ent.s.origin, ent.mins, ent.maxs, ent.s.origin,
				null, MASK_PLAYERSOLID);

		if (tr.ent == null) {
			break;
		}

		/* nail it */
		T_Damage(tr.ent, ent, ent, [0,0,0], ent.s.origin, [0,0,0],
				100000, 0, DAMAGE_NO_PROTECTION, MOD_TELEFRAG);

		/* if we didn't kill it, fail */
		if (tr.ent.solid != solid_t.SOLID_NOT) {
			return false;
		}
	}

	return true; /* all clear */
}