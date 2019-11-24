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
 * Miscellaneos entities, functs and functions.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_world.dart' show SV_LinkEdict;

import 'game.dart';
import 'g_utils.dart';

/* ===================================================== */

/*
 * QUAKED path_corner (.5 .3 0) (-8 -8 -8) (8 8 8) TELEPORT
 * Target: next path corner
 * Pathtarget: gets used when an entity that has
 *             this path_corner targeted touches it
 */
path_corner_touch(edict_t self, edict_t other, cplane_t plane /* unused */,
		csurface_t surf /* unused */) {
	// vec3_t v;
	// edict_t *next;

	if (self == null || other == null) {
		return;
	}

	if (other.movetarget != self) {
		return;
	}

	if (other.enemy != null) {
		return;
	}

	if (self.pathtarget != null) {
		final savetarget = self.target;
		self.target = self.pathtarget;
		G_UseTargets(self, other);
		self.target = savetarget;
	}

  edict_t next;
	if (self.target != null) {
		// next = G_PickTarget(self->target);
	}

	if ((next != null) && (next.spawnflags & 1) != 0) {
		// VectorCopy(next->s.origin, v);
		// v[2] += next->mins[2];
		// v[2] -= other->mins[2];
		// VectorCopy(v, other->s.origin);
		// next = G_PickTarget(next->target);
		// other.s.event = EV_OTHER_TELEPORT;
	}

	other.goalentity = other.movetarget = next;

	if (self.wait != 0) {
		other.monsterinfo.pausetime = level.time + self.wait;
		other.monsterinfo.stand(other);
		return;
	}

	if (other.movetarget == null) {
		other.monsterinfo.pausetime = level.time + 100000000;
		other.monsterinfo.stand(other);
	} else {
    List<double> v = [0,0,0];
		VectorSubtract(other.goalentity.s.origin, other.s.origin, v);
		other.ideal_yaw = vectoyaw(v);
	}
}

SP_path_corner(edict_t self) {
	if (self == null) {
		return;
	}

	if (self.targetname == null) {
		Com_Printf("path_corner with no targetname at ${self.s.origin}\n");
		G_FreeEdict(self);
		return;
	}

	self.solid = solid_t.SOLID_TRIGGER;
	self.touch = path_corner_touch;
  self.mins = [-8, -8, -8];
  self.maxs = [8, 8, 8];
	self.svflags |= SVF_NOCLIENT;
	SV_LinkEdict(self);
}

const _START_OFF = 1;

/*
 * QUAKED light (0 1 0) (-8 -8 -8) (8 8 8) START_OFF
 * Non-displayed light.
 * Default light value is 300.
 * Default style is 0.
 * If targeted, will toggle between on and off.
 * Default _cone value is 10 (used to set size of light for spotlights)
 */
light_use(edict_t self, edict_t other /* unused */, edict_t activator /* unused */) {

	if (self == null) {
		return;
	}

	if ((self.spawnflags & _START_OFF) != 0) {
		PF_Configstring(CS_LIGHTS + self.style, "m");
		self.spawnflags &= ~_START_OFF;
	} else {
		PF_Configstring(CS_LIGHTS + self.style, "a");
		self.spawnflags |= _START_OFF;
	}
}

SP_light(edict_t self) {
	if (self == null) {
		return;
	}

	/* no targeted lights in deathmatch, because they cause global messages */
	if (self.targetname == null || deathmatch.boolean) {
		G_FreeEdict(self);
		return;
	}

	if (self.style >= 32) {
		self.use = light_use;

		if ((self.spawnflags & _START_OFF) != 0)
		{
			PF_Configstring(CS_LIGHTS + self.style, "a");
		}
		else
		{
			PF_Configstring(CS_LIGHTS + self.style, "m");
		}
	}
}