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
import 'dart:math';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/collision.dart';
import 'package:dQuakeWeb/game/g_combat.dart';
import 'package:dQuakeWeb/game/g_misc.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
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

/* Support routines for movement (changes in origin using velocity) */

Move_Done(edict_t ent) {
	if (ent == null) {
		return;
	}

	ent.velocity.fillRange(0, 3, 0);
	ent.moveinfo.endfunc(ent);
}

Move_Final(edict_t ent) {
	if (ent == null) {
		return;
	}

	if (ent.moveinfo.remaining_distance == 0) {
		Move_Done(ent);
		return;
	}

	VectorScale(ent.moveinfo.dir,
			ent.moveinfo.remaining_distance / FRAMETIME,
			ent.velocity);

	ent.think = Move_Done;
	ent.nextthink = level.time + FRAMETIME;
}

Move_Begin(edict_t ent) {

	if (ent == null) {
		return;
	}

	if ((ent.moveinfo.speed * FRAMETIME) >= ent.moveinfo.remaining_distance) {
		Move_Final(ent);
		return;
	}

	VectorScale(ent.moveinfo.dir, ent.moveinfo.speed, ent.velocity);
	double frames = ((
			(ent.moveinfo.remaining_distance /
			 ent.moveinfo.speed) / FRAMETIME).floor()).toDouble();
	ent.moveinfo.remaining_distance -= frames * ent.moveinfo.speed *
										FRAMETIME;
	ent.nextthink = level.time + (frames * FRAMETIME);
	ent.think = Move_Final;
}


Move_Calc(edict_t ent, List<double> dest, void Function(edict_t) func) {
 	if (ent == null || func == null) {
		return;
	}

	ent.velocity.fillRange(0, 3, 0);
	VectorSubtract(dest, ent.s.origin, ent.moveinfo.dir);
	ent.moveinfo.remaining_distance = VectorNormalize(ent.moveinfo.dir);
	ent.moveinfo.endfunc = func;

	if ((ent.moveinfo.speed == ent.moveinfo.accel) &&
		(ent.moveinfo.speed == ent.moveinfo.decel)) {
		if (level.current_entity ==
			((ent.flags & FL_TEAMSLAVE) != 0 ? ent.teammaster : ent))
		{
			Move_Begin(ent);
		}
		else
		{
			ent.nextthink = level.time + FRAMETIME;
			ent.think = Move_Begin;
		}
	}
	else
	{
		/* accelerative */
		ent.moveinfo.current_speed = 0;
		ent.think = Think_AccelMove;
		ent.nextthink = level.time + FRAMETIME;
	}
}

double _AccelerationDistance(double target, double rate) => (target * ((target / rate) + 1) / 2);

plat_CalcAcceleratedMove(moveinfo_t moveinfo) {

	if (moveinfo == null) {
		return;
	}

	moveinfo.move_speed = moveinfo.speed;

	if (moveinfo.remaining_distance < moveinfo.accel) {
		moveinfo.current_speed = moveinfo.remaining_distance;
		return;
	}

	double accel_dist = _AccelerationDistance(moveinfo.speed, moveinfo.accel);
	double decel_dist = _AccelerationDistance(moveinfo.speed, moveinfo.decel);

	if ((moveinfo.remaining_distance - accel_dist - decel_dist) < 0) {
		double f =
			(moveinfo.accel +
			 moveinfo.decel) / (moveinfo.accel * moveinfo.decel);
		moveinfo.move_speed =
			(-2 +
			 sqrt(4 - 4 * f * (-2 * moveinfo.remaining_distance))) / (2 * f);
		decel_dist = _AccelerationDistance(moveinfo.move_speed, moveinfo.decel);
	}

	moveinfo.decel_distance = decel_dist;
}

plat_Accelerate(moveinfo_t moveinfo) {
	if (moveinfo == null) {
		return;
	}

	/* are we decelerating? */
	if (moveinfo.remaining_distance <= moveinfo.decel_distance) {
		if (moveinfo.remaining_distance < moveinfo.decel_distance) {
			if (moveinfo.next_speed != 0) {
				moveinfo.current_speed = moveinfo.next_speed;
				moveinfo.next_speed = 0;
				return;
			}

			if (moveinfo.current_speed > moveinfo.decel) {
				moveinfo.current_speed -= moveinfo.decel;
			}
		}

		return;
	}

	/* are we at full speed and need to start decelerating during this move? */
	if (moveinfo.current_speed == moveinfo.move_speed) {
		if ((moveinfo.remaining_distance - moveinfo.current_speed) <
			moveinfo.decel_distance) {

			double p1_distance = moveinfo.remaining_distance -
						  moveinfo.decel_distance;
			double p2_distance = moveinfo.move_speed *
						  (1.0 - (p1_distance / moveinfo.move_speed));
			double distance = p1_distance + p2_distance;
			moveinfo.current_speed = moveinfo.move_speed;
			moveinfo.next_speed = moveinfo.move_speed - moveinfo.decel *
								   (p2_distance / distance);
			return;
		}
	}

	/* are we accelerating? */
	if (moveinfo.current_speed < moveinfo.speed) {

		double old_speed = moveinfo.current_speed;

		/* figure simple acceleration up to move_speed */
		moveinfo.current_speed += moveinfo.accel;

		if (moveinfo.current_speed > moveinfo.speed) {
			moveinfo.current_speed = moveinfo.speed;
		}

		/* are we accelerating throughout this entire move? */
		if ((moveinfo.remaining_distance - moveinfo.current_speed) >=
			moveinfo.decel_distance) {
			return;
		}

		/* during this move we will accelrate from current_speed to move_speed
		   and cross over the decel_distance; figure the average speed for the
		   entire move */
		double p1_distance = moveinfo.remaining_distance - moveinfo.decel_distance;
		double p1_speed = (old_speed + moveinfo.move_speed) / 2.0;
		double p2_distance = moveinfo.move_speed * (1.0 - (p1_distance / p1_speed));
		double distance = p1_distance + p2_distance;
		moveinfo.current_speed =
			(p1_speed *
			 (p1_distance /
		 distance)) + (moveinfo.move_speed * (p2_distance / distance));
		moveinfo.next_speed = moveinfo.move_speed - moveinfo.decel *
							   (p2_distance / distance);
		return;
	}

	/* we are at constant velocity (move_speed) */
	return;
}

/*
 * The team has completed a frame of movement,
 * so change the speed for the next frame
 */
Think_AccelMove(edict_t ent) {
	if (ent == null) {
		return;
	}

	ent.moveinfo.remaining_distance -= ent.moveinfo.current_speed;

	if (ent.moveinfo.current_speed == 0) /* starting or blocked */
	{
		plat_CalcAcceleratedMove(ent.moveinfo);
	}

	plat_Accelerate(ent.moveinfo);

	/* will the entire move complete on next frame? */
	if (ent.moveinfo.remaining_distance <= ent.moveinfo.current_speed) {
		Move_Final(ent);
		return;
	}

	VectorScale(ent.moveinfo.dir, ent.moveinfo.current_speed * 10,
			ent.velocity);
	ent.nextthink = level.time + FRAMETIME;
	ent.think = Think_AccelMove;
}


/* ==================================================================== */

/* BUTTONS */

/*
 * QUAKED func_button (0 .5 .8) ?
 *
 * When a button is touched, it moves some distance
 * in the direction of it's angle, triggers all of it's
 * targets, waits some time, then returns to it's original
 * position where it can be triggered again.
 *
 * "angle"		determines the opening direction
 * "target"	    all entities with a matching targetname will be used
 * "speed"		override the default 40 speed
 * "wait"		override the default 1 second wait (-1 = never return)
 * "lip"		override the default 4 pixel lip remaining at end of move
 * "health"	    if set, the button must be killed instead of touched
 * "sounds"
 *    1) silent
 *    2) steam metal
 *    3) wooden clunk
 *    4) metallic click
 *    5) in-out
 */
_button_done(edict_t self) {
	if (self == null) {
		return;
	}

	self.moveinfo.state = _STATE_BOTTOM;
	self.s.effects &= ~EF_ANIM23;
	self.s.effects |= EF_ANIM01;
}

_button_return(edict_t self) {
	if (self == null) {
		return;
	}

	self.moveinfo.state = _STATE_DOWN;

	Move_Calc(self, self.moveinfo.start_origin, _button_done);

	self.s.frame = 0;

	if (self.health != 0) {
		self.takedamage = damage_t.DAMAGE_YES.index;
	}
}

_button_wait(edict_t self) {
	if (self == null) {
		return;
	}

	self.moveinfo.state = _STATE_TOP;
	self.s.effects &= ~EF_ANIM01;
	self.s.effects |= EF_ANIM23;

	G_UseTargets(self, self.activator);
	self.s.frame = 1;

	if (self.moveinfo.wait >= 0) {
		self.nextthink = level.time + self.moveinfo.wait;
		self.think = _button_return;
	}
}

_button_fire(edict_t self) {
	if (self == null) {
		return;
	}

	if ((self.moveinfo.state == _STATE_UP) ||
		(self.moveinfo.state == _STATE_TOP)) {
		return;
	}

	self.moveinfo.state = _STATE_UP;

	if (self.moveinfo.sound_start != 0 && (self.flags & FL_TEAMSLAVE) == 0) {
		PF_StartSound(self, CHAN_NO_PHS_ADD + CHAN_VOICE,
				self.moveinfo.sound_start, 1, ATTN_STATIC.toDouble(),
				0);
	}

	Move_Calc(self, self.moveinfo.end_origin, _button_wait);
}

_button_use(edict_t self, edict_t other /* unused */, edict_t activator) {
	if (self == null || activator == null) {
		return;
	}

	self.activator = activator;
	_button_fire(self);
}

_button_touch(edict_t self, edict_t other, cplane_t plane /* unused */, csurface_t surf /* unused */) {
	if (self == null || other == null) {
		return;
	}

	if (other.client == null) {
		return;
	}

	if (other.health <= 0) {
		return;
	}

	self.activator = other;
	_button_fire(self);
}

_button_killed(edict_t self, edict_t inflictor /* unused */, edict_t attacker /* unsued */,
		int damage /* unused */, List<double> point /* unused */) {
	if (self == null) {
		return;
	}

	self.activator = attacker;
	self.health = self.max_health;
	self.takedamage = damage_t.DAMAGE_NO.index;
	_button_fire(self);
}

SP_func_button(edict_t ent) {

	if (ent == null) {
		return;
	}

	G_SetMovedir(ent.s.angles, ent.movedir);
	ent.movetype = movetype_t.MOVETYPE_STOP;
	ent.solid = solid_t.SOLID_BSP;
	PF_setmodel(ent, ent.model);

	if (ent.sounds != 1) {
		ent.moveinfo.sound_start = SV_SoundIndex("switches/butn2.wav");
	}

	if (ent.speed == 0) {
		ent.speed = 40;
	}

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
		st.lip = 4;
	}

  ent.pos1.setAll(0, ent.s.origin);
  List<double> abs_movedir = [ent.movedir[0].abs(), ent.movedir[1].abs(), ent.movedir[2].abs()];
	double dist = abs_movedir[0] * ent.size[0] + abs_movedir[1] * ent.size[1] +
		   abs_movedir[2] * ent.size[2] - st.lip;
	VectorMA(ent.pos1, dist, ent.movedir, ent.pos2);

	ent.use = _button_use;
	ent.s.effects |= EF_ANIM01;

	if (ent.health != 0)
	{
		ent.max_health = ent.health;
		ent.die = _button_killed;
		ent.takedamage = damage_t.DAMAGE_YES.index;
	}
	else if (ent.targetname == null)
	{
		ent.touch = _button_touch;
	}

	ent.moveinfo.state = _STATE_BOTTOM;

	ent.moveinfo.speed = ent.speed;
	ent.moveinfo.accel = ent.accel;
	ent.moveinfo.decel = ent.decel;
	ent.moveinfo.wait = ent.wait;
  ent.moveinfo.start_origin.setAll(0, ent.pos1);
  ent.moveinfo.start_angles.setAll(0, ent.s.angles);
  ent.moveinfo.end_origin.setAll(0, ent.pos2);
  ent.moveinfo.end_angles.setAll(0, ent.s.angles);

	SV_LinkEdict(ent);
}

/* ==================================================================== */

/*
 * DOORS
 *
 * spawn a trigger surrounding the entire team
 * unless it is already targeted by another
 */

/*
 * QUAKED func_door (0 .5 .8) ? START_OPEN x CRUSHER NOMONSTER ANIMATED TOGGLE ANIMATED_FAST
 *
 * TOGGLE		wait in both the start and end states for a trigger event.
 * START_OPEN	the door to moves to its destination when spawned, and operate in reverse.
 *              It is used to temporarily or permanently close off an area when triggered
 *              (not useful for touch or takedamage doors).
 * NOMONSTER	monsters will not trigger this door
 *
 * "message"	is printed when the door is touched if it is a trigger door and it hasn't been fired yet
 * "angle"		determines the opening direction
 * "targetname" if set, no touch field will be spawned and a remote button or trigger field activates the door.
 * "health"	    if set, door must be shot open
 * "speed"		movement speed (100 default)
 * "wait"		wait before returning (3 default, -1 = never return)
 * "lip"		lip remaining at end of move (8 default)
 * "dmg"		damage to inflict when blocked (2 default)
 * "sounds"
 *    1)	silent
 *    2)	light
 *    3)	medium
 *    4)	heavy
 */

_door_use_areaportals(edict_t self, bool open) {

	if (self == null) {
		return;
	}

	if (self.target == null) {
		return;
	}

  edict_t t;
	while ((t = G_Find(t, "targetname", self.target)) != null) {
		if (t.classname == "func_areaportal") {
			CM_SetAreaPortalState(t.style, open);
		}
	}
}

_door_hit_top(edict_t self)
{
	if (self == null) {
		return;
	}

	if ((self.flags & FL_TEAMSLAVE) == 0) {
		// if (self->moveinfo.sound_end)
		// {
		// 	gi.sound(self, CHAN_NO_PHS_ADD + CHAN_VOICE, self->moveinfo.sound_end,
		// 			1, ATTN_STATIC, 0);
		// }

		self.s.sound = 0;
	}

	self.moveinfo.state = _STATE_TOP;

	if ((self.spawnflags & _DOOR_TOGGLE) != 0) {
		return;
	}

	if (self.moveinfo.wait >= 0) {
		self.think = _door_go_down;
		self.nextthink = level.time + self.moveinfo.wait;
	}
}



_door_hit_bottom(edict_t self) {
	if (self == null) {
		return;
	}

	if ((self.flags & FL_TEAMSLAVE) == 0) {
		// if (self->moveinfo.sound_end) {
		// 	gi.sound(self, CHAN_NO_PHS_ADD + CHAN_VOICE,
		// 			self->moveinfo.sound_end, 1,
		// 			ATTN_STATIC, 0);
		// }

		self.s.sound = 0;
	}

	self.moveinfo.state = _STATE_BOTTOM;
	_door_use_areaportals(self, false);
}

_door_go_down(edict_t self) {
	if (self == null) {
		return;
	}

	// if (!(self->flags & FL_TEAMSLAVE))
	// {
	// 	if (self->moveinfo.sound_start)
	// 	{
	// 		gi.sound(self, CHAN_NO_PHS_ADD + CHAN_VOICE,
	// 				self->moveinfo.sound_start, 1,
	// 				ATTN_STATIC, 0);
	// 	}

	// 	self->s.sound = self->moveinfo.sound_middle;
	// }

	if (self.max_health != 0) {
		self.takedamage = damage_t.DAMAGE_YES.index;
		self.health = self.max_health;
	}

	self.moveinfo.state = _STATE_DOWN;

	if (self.classname == "func_door") {
		Move_Calc(self, self.moveinfo.start_origin, _door_hit_bottom);
	} else if (self.classname == "func_door_rotating") {
	// 	AngleMove_Calc(self, door_hit_bottom);
	}
}

_door_go_up(edict_t self, edict_t activator) {
	if (self == null || activator == null) {
		return;
	}

	if (self.moveinfo.state == _STATE_UP) {
		return; /* already going up */
	}

	if (self.moveinfo.state == _STATE_TOP) {
		/* reset top wait time */
		if (self.moveinfo.wait >= 0) {
			self.nextthink = level.time + self.moveinfo.wait;
		}

		return;
	}

	if ((self.flags & FL_TEAMSLAVE) == 0) {
		// if (self.moveinfo.sound_start)
		// {
		// 	gi.sound(self, CHAN_NO_PHS_ADD + CHAN_VOICE,
		// 			self->moveinfo.sound_start, 1,
		// 			ATTN_STATIC, 0);
		// }

		// self->s.sound = self->moveinfo.sound_middle;
	}

	self.moveinfo.state = _STATE_UP;

	if (self.classname == "func_door") {
		Move_Calc(self, self.moveinfo.end_origin, _door_hit_top);
	} else if (self.classname == "func_door_rotating") {
		// AngleMove_Calc(self, door_hit_top);
	}

	G_UseTargets(self, activator);
	_door_use_areaportals(self, true);
}

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
			for (var ent = self; ent != null; ent = ent.teamchain) {
				ent.message = null;
				ent.touch = null;
				_door_go_down(ent);
			}

			return;
		}
	}

	/* trigger all paired doors */
	for (var ent = self; ent != null; ent = ent.teamchain) {
		ent.message = null;
		ent.touch = null;
		_door_go_up(ent, activator);
	}
}

Touch_DoorTrigger(edict_t self, edict_t other, cplane_t plane /* unused */,
		csurface_t surf /* unused */) {

	if (self == null || other == null) {
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

	if (ent == null) {
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

	if ((ent.spawnflags & _DOOR_START_OPEN) != 0) {
		_door_use_areaportals(ent, true);
	}

	Think_CalcMoveSpeed(ent);
}

door_blocked(edict_t self, edict_t other) {
	// edict_t *ent;

	if (self == null || other == null) {
		return;
	}

  print("door_blocked");
	if ((other.svflags & SVF_MONSTER) == 0 && (other.client == null)) {
		/* give it a chance to go away on it's own terms (like gibs) */
		T_Damage(other, self, self, [0,0,0], other.s.origin,
				[0,0,0], 100000, 1, 0, MOD_CRUSH);

		/* if it's still there, nuke it */
		if (other != null) {
			/* Hack for entitiy without their origin near the model */
			VectorMA (other.absmin, 0.5, other.size, other.s.origin);
			BecomeExplosion1(other);
		}

		return;
	}

	T_Damage(other, self, self, [0,0,0], other.s.origin,
			[0,0,0], self.dmg, 1, 0, MOD_CRUSH);

	if ((self.spawnflags & _DOOR_CRUSHER) != 0) {
		return;
	}

	/* if a door has a negative wait, it would never come back if blocked,
	   so let it just squash the object to death real fast */
	if (self.moveinfo.wait >= 0) {
		if (self.moveinfo.state == _STATE_DOWN) {
			for (var ent = self.teammaster; ent != null; ent = ent.teamchain)
			{
				_door_go_up(ent, ent.activator);
			}
		}
		else
		{
			for (var ent = self.teammaster; ent != null; ent = ent.teamchain)
			{
				_door_go_down(ent);
			}
		}
	}
}


door_touch(edict_t self, edict_t other, cplane_t plane /* unused */, csurface_t surf /* unused */) {

 	if (self == null || other == null) {
		return;
	}

  print("door_touch");

	if (other.client == null) {
		return;
	}

	if (level.time < self.touch_debounce_time) {
		return;
	}

	self.touch_debounce_time = level.time + 5.0;

  PF_centerprintf(other, self.message);
  PF_StartSound(other, CHAN_AUTO, SV_SoundIndex("misc/talk1.wav"), 1, ATTN_NORM.toDouble(), 0);
}


SP_func_door(edict_t ent) {

	if (ent == null) {
		return;
	}

	if (ent.sounds != 1) {
		ent.moveinfo.sound_start = SV_SoundIndex("doors/dr1_strt.wav");
		ent.moveinfo.sound_middle = SV_SoundIndex("doors/dr1_mid.wav");
		ent.moveinfo.sound_end = SV_SoundIndex("doors/dr1_end.wav");
	}

	G_SetMovedir(ent.s.angles, ent.movedir);
	ent.movetype = movetype_t.MOVETYPE_PUSH;
	ent.solid = solid_t.SOLID_BSP;
	PF_setmodel(ent, ent.model);

	ent.blocked = door_blocked;
	ent.use = door_use;

	if (ent.speed == 0) {
		ent.speed = 100;
	}

	if (deathmatch.boolean) {
		ent.speed *= 2;
	}

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
    print("door health ${ent.health}");
		ent.takedamage = damage_t.DAMAGE_YES.index;
		// ent.die = door_killed;
		ent.max_health = ent.health;
	} else if (ent.targetname != null && ent.message != null) {
		SV_SoundIndex("misc/talk.wav");
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
	if (ent.team == null) {
		ent.teammaster = ent;
	}

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

/* ==================================================================== */

/*
 * QUAKED func_timer (0.3 0.1 0.6) (-8 -8 -8) (8 8 8) START_ON
 *
 * "wait"	base time between triggering all targets, default is 1
 * "random"	wait variance, default is 0
 *
 * so, the basic time between firing is a random time
 * between (wait - random) and (wait + random)
 *
 * "delay"			delay before first firing when turned on, default is 0
 * "pausetime"		additional delay used only the very first time
 *                  and only if spawned with START_ON
 *
 * These can used but not touched.
 */
func_timer_think(edict_t self) {
	if (self == null) {
		return;
	}

	G_UseTargets(self, self.activator);
	self.nextthink = level.time + self.wait + crandk() * self.random;
}

func_timer_use(edict_t self, edict_t other /* unused */, edict_t activator) {
	if (self == null || activator == null) {
		return;
	}

	self.activator = activator;

	/* if on, turn it off */
	if (self.nextthink != 0) {
		self.nextthink = 0;
		return;
	}

	/* turn it on */
	if (self.delay != 0) {
		self.nextthink = level.time + self.delay;
	} else {
		func_timer_think(self);
	}
}

SP_func_timer(edict_t self) {
	if (self == null) {
		return;
	}

	if (self.wait == 0) {
		self.wait = 1.0;
	}

	self.use = func_timer_use;
	self.think = func_timer_think;

	if (self.random >= self.wait) {
		self.random = self.wait - FRAMETIME;
		Com_Printf("func_timer at ${self.s.origin} has random >= wait\n");
	}

	if ((self.spawnflags & 1) != 0) {
		self.nextthink = level.time + 1.0 + st.pausetime + self.delay +
						  self.wait + crandk() * self.random;
		self.activator = self;
	}

	self.svflags = SVF_NOCLIENT;
}