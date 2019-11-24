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
 * Monster utility functions.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'game.dart';
import 'g_utils.dart';
import 'monster/misc/move.dart';

M_CheckGround(edict_t ent) {

	if (ent == null) {
		return;
	}

	if ((ent.flags & (FL_SWIM | FL_FLY)) != 0) {
		return;
	}

	if (ent.velocity[2] > 100) {
		ent.groundentity = null;
		return;
	}

	/* if the hull point one-quarter unit down
	   is solid the entity is on ground */
	List<double> point = [ent.s.origin[0], ent.s.origin[1], ent.s.origin[2] - 0.25];

	final trace = SV_Trace(ent.s.origin, ent.mins, ent.maxs, point, ent, MASK_MONSTERSOLID);

	/* check steepness */
	if ((trace.plane.normal[2] < 0.7) && !trace.startsolid) {
		ent.groundentity = null;
		return;
	}

	if (!trace.startsolid && !trace.allsolid) {
    ent.s.origin.setAll(0, trace.endpos);
		ent.groundentity = trace.ent;
		ent.groundentity_linkcount = trace.ent.linkcount;
		ent.velocity[2] = 0;
	}
}

M_CatagorizePosition(edict_t ent) {

	if (ent == null) {
		return;
	}

	/* get waterlevel */
  List<double> point = [0,0,0];
	point[0] = (ent.absmax[0] + ent.absmin[0])/2;
	point[1] = (ent.absmax[1] + ent.absmin[1])/2;
	point[2] = ent.absmin[2] + 2;
	int cont = SV_PointContents(point);

	if ((cont & MASK_WATER) == 0) {
		ent.waterlevel = 0;
		ent.watertype = 0;
		return;
	}

	ent.watertype = cont;
	ent.waterlevel = 1;
	point[2] += 26;
	cont = SV_PointContents(point);

	if ((cont & MASK_WATER) == 0) {
		return;
	}

	ent.waterlevel = 2;
	point[2] += 22;
	cont = SV_PointContents(point);

	if ((cont & MASK_WATER) != 0) {
		ent.waterlevel = 3;
	}
}


M_droptofloor(edict_t ent) {

	if (ent == null) {
		return;
	}

	ent.s.origin[2] += 1;
  List<double> end = List.generate(3, (i) => ent.s.origin[i]);
	end[2] -= 256;

	final trace = SV_Trace(ent.s.origin, ent.mins, ent.maxs, end,
			ent, MASK_MONSTERSOLID);

	if ((trace.fraction == 1) || trace.allsolid) {
		return;
	}

  ent.s.origin.setAll(0, trace.endpos);

	SV_LinkEdict(ent);
	M_CheckGround(ent);
	M_CatagorizePosition(ent);
}

/* ================================================================== */

bool monster_start(edict_t self) {
	if (self == null) {
		return false;
	}

	if (deathmatch.boolean) {
		G_FreeEdict(self);
		return false;
	}

	if ((self.spawnflags & 4) != 0 && (self.monsterinfo.aiflags & AI_GOOD_GUY) == 0) {
		self.spawnflags &= ~4;
		self.spawnflags |= 1;
	}

	if ((self.monsterinfo.aiflags & AI_GOOD_GUY) == 0) {
		level.total_monsters++;
	}

	self.nextthink = level.time + FRAMETIME;
	self.svflags |= SVF_MONSTER;
	self.s.renderfx |= RF_FRAMELERP;
	self.takedamage = damage_t.DAMAGE_AIM.index;
	self.air_finished = level.time + 12;
	// self.use = monster_use;

	if(self.max_health == 0) {
		self.max_health = self.health;
	}

	self.clipmask = MASK_MONSTERSOLID;

	self.s.skinnum = 0;
	self.deadflag = DEAD_NO;
	self.svflags &= ~SVF_DEADMONSTER;

	// if (!self->monsterinfo.checkattack)
	// {
	// 	self->monsterinfo.checkattack = M_CheckAttack;
	// }

  self.s.old_origin.setAll(0, self.s.origin);

	// if (st.item)
	// {
	// 	self->item = FindItemByClassname(st.item);

	// 	if (!self->item)
	// 	{
	// 		gi.dprintf("%s at %s has bad item: %s\n", self->classname,
	// 				vtos(self->s.origin), st.item);
	// 	}
	// }

	// /* randomize what frame they start on */
	// if (self->monsterinfo.currentmove)
	// {
	// 	self->s.frame = self->monsterinfo.currentmove->firstframe +
	// 		(randk() % (self->monsterinfo.currentmove->lastframe -
	// 				   self->monsterinfo.currentmove->firstframe + 1));
	// }

	return true;
}

walkmonster_start_go(edict_t self) {
	if (self == null) {
		return;
	}

	if ((self.spawnflags & 2) == 0 && (level.time < 1)) {
		M_droptofloor(self);

		if (self.groundentity != null) {
			if (!M_walkmove(self, 0, 0)) {
				Com_Printf("${self.classname} in solid at ${self.s.origin}\n");
			}
		}
	}

	if (self.yaw_speed == 0) {
		self.yaw_speed = 20;
	}

	if (self.viewheight == 0) {
		self.viewheight = 25;
	}

	// if ((self->spawnflags & 2) != 0) {
	// 	monster_triggered_start(self);
	// } else {
	// 	monster_start_go(self);
	// }
}

walkmonster_start(edict_t self)
{
	if (self == null) {
		return;
	}

	self.think = walkmonster_start_go;
	monster_start(self);
}