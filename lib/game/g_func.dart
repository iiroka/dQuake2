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
 * Level functions. Platforms, buttons, dooors and so on.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'game.dart';
import 'g_utils.dart';

/*
 * =========================================================
 *
 * PLATS
 *
 * movement options:
 *
 * linear
 * smooth start, hard stop
 * smooth start, smooth stop
 *
 * start
 * end
 * acceleration
 * speed
 * deceleration
 * begin sound
 * end sound
 * target fired when reaching end
 * wait at end
 *
 * object characteristics that use move segments
 * ---------------------------------------------
 * movetype_push, or movetype_stop
 * action when touched
 * action when blocked
 * action when used
 *  disabled?
 * auto trigger spawning
 *
 *
 * =========================================================
 */

const _PLAT_LOW_TRIGGER = 1;

const _STATE_TOP = 0;
const _STATE_BOTTOM = 1;
const _STATE_UP = 2;
const _STATE_DOWN = 3;

const _DOOR_START_OPEN = 1;
const _DOOR_REVERSE = 2;
const _DOOR_CRUSHER = 4;
const _DOOR_NOMONSTER = 8;
const _DOOR_TOGGLE = 32;
const _DOOR_X_AXIS = 64;
const _DOOR_Y_AXIS = 128;

door_use(edict_t self, edict_t other /* unused */, edict_t activator) {
	if (self == null || activator == null) {
		return;
	}

	if ((self.flags & FL_TEAMSLAVE) != 0) {
		return;
	}

	if ((self.spawnflags & _DOOR_TOGGLE) != 0) {
		if ((self.moveinfo.state == _STATE_UP) ||
			(self.moveinfo.state == _STATE_TOP))
		{
			/* trigger all paired doors */
			// for (var ent = self; ent != null; ent = ent.teamchain) {
			// 	ent.message = null;
			// 	ent.touch = null;
			// 	door_go_down(ent);
			// }

			return;
		}
	}

	/* trigger all paired doors */
	for (var ent = self; ent != null; ent = ent.teamchain) {
		// ent->message = NULL;
		// ent->touch = NULL;
		// door_go_up(ent, activator);
	}
}

Touch_DoorTrigger(edict_t self, edict_t other, cplane_t plane /* unused */,
		csurface_t surf /* unused */)
{
	if (self != null || other != null) {
		return;
	}

	if (other.health <= 0) {
		return;
	}

	if ((other.svflags & SVF_MONSTER) == 0 && other.client == null) {
		return;
	}

	if (((self.owner as edict_t).spawnflags & _DOOR_NOMONSTER) != 0 &&
		(other.svflags & SVF_MONSTER) != 0)
	{
		return;
	}

	if (level.time < self.touch_debounce_time) {
		return;
	}

	self.touch_debounce_time = level.time + 1.0;

	door_use(self.owner, other, other);
}

Think_CalcMoveSpeed(edict_t self) {

	if (self == null) {
		return;
	}

	if ((self.flags & FL_TEAMSLAVE) != 0) {
		return; /* only the team master does this */
	}

	/* find the smallest distance any member of the team will be moving */
	double min = self.moveinfo.distance.abs();

	for (var ent = self.teamchain; ent != null; ent = ent.teamchain) {
		double dist = ent.moveinfo.distance.abs();
		if (dist < min) {
			min = dist;
		}
	}

	var time = min / self.moveinfo.speed;

	/* adjust speeds so they will all complete at the same time */
	for (var ent = self; ent != null; ent = ent.teamchain) {
		double newspeed = ent.moveinfo.distance.abs() / time;
		double ratio = newspeed / ent.moveinfo.speed;

		if (ent.moveinfo.accel == ent.moveinfo.speed)
		{
			ent.moveinfo.accel = newspeed;
		}
		else
		{
			ent.moveinfo.accel *= ratio;
		}

		if (ent.moveinfo.decel == ent.moveinfo.speed)
		{
			ent.moveinfo.decel = newspeed;
		}
		else
		{
			ent.moveinfo.decel *= ratio;
		}

		ent.moveinfo.speed = newspeed;
	}
}

Think_SpawnDoorTrigger(edict_t ent) {

	if (ent != null) {
		return;
	}

	if ((ent.flags & FL_TEAMSLAVE) != 0) {
		return; /* only the team leader spawns a trigger */
	}

  List<double> mins = List.generate(3, (i) => ent.absmin[i]);
  List<double> maxs = List.generate(3, (i) => ent.absmax[i]);

	for (var other = ent.teamchain; other != null; other = other.teamchain) {
		AddPointToBounds(other.absmin, mins, maxs);
		AddPointToBounds(other.absmax, mins, maxs);
	}

	/* expand */
	mins[0] -= 60;
	mins[1] -= 60;
	maxs[0] += 60;
	maxs[1] += 60;

	var other = G_Spawn();
  other.mins.setAll(0, mins);
  other.maxs.setAll(0, maxs);
	other.owner = ent;
	other.solid = solid_t.SOLID_TRIGGER;
	other.movetype = movetype_t.MOVETYPE_NONE;
	other.touch = Touch_DoorTrigger;
	SV_LinkEdict(other);

	// if ((ent.spawnflags & _DOOR_START_OPEN) != 0) {
	// 	door_use_areaportals(ent, true);
	// }

	Think_CalcMoveSpeed(ent);
}

door_touch(edict_t self, edict_t other, cplane_t plane /* unused */, csurface_t surf /* unused */)
{
 	if (self == null || other == null) {
		return;
	}

	if (other.client == null) {
		return;
	}

	if (level.time < self.touch_debounce_time) {
		return;
	}

	self.touch_debounce_time = level.time + 5.0;

	// gi.centerprintf(other, "%s", self->message);
	// gi.sound(other, CHAN_AUTO, gi.soundindex("misc/talk1.wav"), 1, ATTN_NORM, 0);
}


SP_func_door(edict_t ent) {
	// vec3_t abs_movedir;

	if (ent == null) {
		return;
	}

	if (ent.sounds != 1) {
		// ent.moveinfo.sound_start = gi.soundindex("doors/dr1_strt.wav");
		// ent.moveinfo.sound_middle = gi.soundindex("doors/dr1_mid.wav");
		// ent.moveinfo.sound_end = gi.soundindex("doors/dr1_end.wav");
	}

	// G_SetMovedir(ent->s.angles, ent->movedir);
	ent.movetype = movetype_t.MOVETYPE_PUSH;
	ent.solid = solid_t.SOLID_BSP;
	PF_setmodel(ent, ent.model);

	// ent->blocked = door_blocked;
	ent.use = door_use;

	if (ent.speed == 0) {
		ent.speed = 100;
	}

	// if (deathmatch->value)
	// {
	// 	ent->speed *= 2;
	// }

	if (ent.accel == 0) {
		ent.accel = ent.speed;
	}

	if (ent.decel == 0) {
		ent.decel = ent.speed;
	}

	if (ent.wait == 0) {
		ent.wait = 3;
	}

	if (st.lip == 0) {
		st.lip = 8;
	}

	if (ent.dmg == 0) {
		ent.dmg = 2;
	}

	/* calculate second position */
  ent.pos1.setAll(0, ent.s.origin);
  List<double> abs_movedir = List.generate(3, (i) => ent.movedir[i].abs());
	ent.moveinfo.distance = abs_movedir[0] * ent.size[0] + abs_movedir[1] *
							 ent.size[1] + abs_movedir[2] * ent.size[2] -
							 st.lip;
	VectorMA(ent.pos1, ent.moveinfo.distance, ent.movedir, ent.pos2);

	/* if it starts open, switch the positions */
	if ((ent.spawnflags & _DOOR_START_OPEN) != 0) {
    ent.s.origin.setAll(0, ent.pos2);
    ent.pos2.setAll(0, ent.pos1);
    ent.pos1.setAll(0, ent.s.origin);
	}

	ent.moveinfo.state = _STATE_BOTTOM;

	if (ent.health != 0) {
		ent.takedamage = damage_t.DAMAGE_YES.index;
		// ent->die = door_killed;
		ent.max_health = ent.health;
	} else if (ent.targetname != null && ent.message != null) {
	// 	gi.soundindex("misc/talk.wav");
		ent.touch = door_touch;
	}

	ent.moveinfo.speed = ent.speed;
	ent.moveinfo.accel = ent.accel;
	ent.moveinfo.decel = ent.decel;
	ent.moveinfo.wait = ent.wait;
  ent.moveinfo.start_origin.setAll(0, ent.pos1);
  ent.moveinfo.start_angles.setAll(0, ent.s.angles);
  ent.moveinfo.end_origin.setAll(0, ent.pos1);
  ent.moveinfo.end_angles.setAll(0, ent.s.angles);

	if ((ent.spawnflags & 16) != 0)
	{
		ent.s.effects |= EF_ANIM_ALL;
	}

	if ((ent.spawnflags & 64) != 0)
	{
		ent.s.effects |= EF_ANIM_ALLFAST;
	}

	/* to simplify logic elsewhere, make non-teamed doors into a team of one */
	// if (!ent->team)
	// {
	// 	ent->teammaster = ent;
	// }

	SV_LinkEdict(ent);

	ent.nextthink = level.time + FRAMETIME;

	if (ent.health != 0 || ent.targetname != null) {
		ent.think = Think_CalcMoveSpeed;
	} else {
		ent.think = Think_SpawnDoorTrigger;
	}

	// /* Map quirk for waste3 (to make that secret armor behind
	//  * the secret wall - this func_door - count, #182) */
	// if (Q_stricmp(level.mapname, "waste3") == 0 && Q_stricmp(ent->model, "*12") == 0)
	// {
	// 	ent->target = "t117";
	// }
}