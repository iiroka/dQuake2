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
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_world.dart' show SV_LinkEdict;

import 'game.dart';
import 'g_utils.dart';

int debristhisframe = 0;
int gibsthisframe = 0;

/* ===================================================== */

VelocityForDamage(int damage, List<double> v) {
	v[0] = 100.0 * crandk();
	v[1] = 100.0 * crandk();
	v[2] = 200.0 + 100.0 * frandk();

	if (damage < 50)
	{
		VectorScale(v, 0.7, v);
	}
	else
	{
		VectorScale(v, 1.2, v);
	}
}

ClipGibVelocity(edict_t ent) {
	if (ent == null)
	{
		return;
	}

	if (ent.velocity[0] < -300)
	{
		ent.velocity[0] = -300;
	}
	else if (ent.velocity[0] > 300)
	{
		ent.velocity[0] = 300;
	}

	if (ent.velocity[1] < -300)
	{
		ent.velocity[1] = -300;
	}
	else if (ent.velocity[1] > 300)
	{
		ent.velocity[1] = 300;
	}

	if (ent.velocity[2] < 200)
	{
		ent.velocity[2] = 200; /* always some upwards */
	}
	else if (ent.velocity[2] > 500)
	{
		ent.velocity[2] = 500;
	}
}

/* ===================================================== */

_gib_think(edict_t self) {
	if (self == null) {
		return;
	}

	self.s.frame++;
	self.nextthink = level.time + FRAMETIME;

	if (self.s.frame == 10)
	{
		self.think = G_FreeEdict;
		self.nextthink = level.time + 8 + frandk() * 10;
	}
}

_gib_touch(edict_t self, edict_t other /* unused */, cplane_t plane, csurface_t surf /* unused */)
{
	if (self == null || plane == null) {
		return;
	}

	if (self.groundentity == null) {
		return;
	}

	self.touch = null;

	if (plane != null) {
		// gi.sound(self, CHAN_VOICE, gi.soundindex(
		// 				"misc/fhit3.wav"), 1, ATTN_NORM, 0);

    List<double> normal_angles = [0,0,0];
		vectoangles(plane.normal, normal_angles);
    List<double> right = [0,0,0];
		AngleVectors(normal_angles, null, right, null);
		vectoangles(right, self.s.angles);

		if (self.s.modelindex == sm_meat_index) {
			self.s.frame++;
			self.think = _gib_think;
			self.nextthink = level.time + FRAMETIME;
		}
	}
}

_gib_die(edict_t self, edict_t inflictor /* unused */, edict_t attacker /* unused */,
		int damage /* unused */, List<double> point /* unused */) {
	if (self == null) {
		return;
	}
	G_FreeEdict(self);
}

ThrowGib(edict_t self, String gibname, int damage, int type) {

	if (self == null || gibname == null) {
		return;
	}

	gibsthisframe++;

	if (gibsthisframe > MAX_GIBS) {
		return;
	}

	final gib = G_Spawn();

  List<double> size = [0,0,0];
	VectorScale(self.size, 0.5, size);
  List<double> origin = [0,0,0];
	VectorAdd(self.absmin, size, origin);
	gib.s.origin[0] = origin[0] + crandk() * size[0];
	gib.s.origin[1] = origin[1] + crandk() * size[1];
	gib.s.origin[2] = origin[2] + crandk() * size[2];

	PF_setmodel(gib, gibname);
	gib.solid = solid_t.SOLID_BBOX;
	gib.s.effects |= EF_GIB;
	gib.flags |= FL_NO_KNOCKBACK;
	gib.takedamage = damage_t.DAMAGE_YES.index;
	gib.die = _gib_die;
	gib.health = 250;

  double vscale;
	if (type == GIB_ORGANIC)
	{
		gib.movetype = movetype_t.MOVETYPE_TOSS;
		gib.touch = _gib_touch;
		vscale = 0.5;
	}
	else
	{
		gib.movetype = movetype_t.MOVETYPE_BOUNCE;
		vscale = 1.0;
	}

  List<double> vd = [0,0,0];
	VelocityForDamage(damage, vd);
	VectorMA(self.velocity, vscale, vd, gib.velocity);
	ClipGibVelocity(gib);
	gib.avelocity[0] = frandk() * 600;
	gib.avelocity[1] = frandk() * 600;
	gib.avelocity[2] = frandk() * 600;

	gib.think = G_FreeEdict;
	gib.nextthink = level.time + 10 + frandk() * 10;

	SV_LinkEdict(gib);
}

ThrowHead(edict_t self, String gibname, int damage, int type) {

	if (self == null || gibname == null) {
		return;
	}

	self.s.skinnum = 0;
	self.s.frame = 0;
	self.mins.fillRange(0, 3, 0);
	self.maxs.fillRange(0, 3, 0);

	self.s.modelindex2 = 0;
	PF_setmodel(self, gibname);
	self.solid = solid_t.SOLID_BBOX;
	self.s.effects |= EF_GIB;
	self.s.effects &= ~EF_FLIES;
	self.s.sound = 0;
	self.flags |= FL_NO_KNOCKBACK;
	self.svflags &= ~SVF_MONSTER;
	self.takedamage = damage_t.DAMAGE_YES.index;
	self.targetname = null;
	self.die = _gib_die;

  double vscale;
	if (type == GIB_ORGANIC) {
		self.movetype = movetype_t.MOVETYPE_TOSS;
		self.touch = _gib_touch;
		vscale = 0.5;
	}
	else
	{
		self.movetype = movetype_t.MOVETYPE_BOUNCE;
		vscale = 1.0;
	}

  List<double> vd = [0,0,0];
	VelocityForDamage(damage, vd);
	VectorMA(self.velocity, vscale, vd, self.velocity);
	ClipGibVelocity(self);

	self.avelocity[YAW] = crandk() * 600;

	self.think = G_FreeEdict;
	self.nextthink = level.time + 10 + frandk() * 10;

	SV_LinkEdict(self);
}

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

/* ===================================================== */

/*
 * QUAKED point_combat (0.5 0.3 0) (-8 -8 -8) (8 8 8) Hold
 *
 * Makes this the target of a monster and it will head here
 * when first activated before going after the activator.  If
 * hold is selected, it will stay here.
 */
_point_combat_touch(edict_t self, edict_t other, cplane_t plane /* unused */,
		csurface_t surf /* unused */) {

	if (self == null || other == null) {
		return;
	}

	if (other.movetarget != self) {
		return;
	}

	if (self.target != null)
	{
		other.target = self.target;
		other.goalentity = other.movetarget = G_PickTarget(other.target);

		if (other.goalentity == null)
		{
			Com_Printf("${self.classname} at ${self.s.origin} target ${self.target} does not exist\n");
			other.movetarget = self;
		}

		self.target = null;
	}
	else if ((self.spawnflags & 1) != 0 && (other.flags & (FL_SWIM | FL_FLY)) == 0)
	{
		other.monsterinfo.pausetime = level.time + 100000000;
		other.monsterinfo.aiflags |= AI_STAND_GROUND;
		other.monsterinfo.stand(other);
	}

	if (other.movetarget == self)
	{
		other.target = null;
		other.movetarget = null;
		other.goalentity = other.enemy;
		other.monsterinfo.aiflags &= ~AI_COMBAT_POINT;
	}

	if (self.pathtarget != null)
	{
		final savetarget = self.target;
		self.target = self.pathtarget;

    edict_t activator;
		if (other.enemy != null && other.enemy.client != null) {
			activator = other.enemy;
		} else if (other.oldenemy != null && other.oldenemy.client != null) {
			activator = other.oldenemy;
		} else if (other.activator != null && other.activator.client != null) {
			activator = other.activator;
		} else {
			activator = other;
		}

		G_UseTargets(self, activator);
		self.target = savetarget;
	}
}

SP_point_combat(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean) {
		G_FreeEdict(self);
		return;
	}

	self.solid = solid_t.SOLID_TRIGGER;
	self.touch = _point_combat_touch;
	self.mins = [ -8, -8, -16 ];
	self.maxs = [ 8, 8, 16 ];
	self.svflags = SVF_NOCLIENT;
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

/* ===================================================== */

/*
 * QUAKED func_wall (0 .5 .8) ? TRIGGER_SPAWN TOGGLE START_ON ANIMATED ANIMATED_FAST
 * This is just a solid wall if not inhibited
 *
 * TRIGGER_SPAWN	the wall will not be present until triggered
 *                  it will then blink in to existance; it will
 *                  kill anything that was in it's way
 *
 * TOGGLE			only valid for TRIGGER_SPAWN walls
 *                  this allows the wall to be turned on and off
 *
 * START_ON		only valid for TRIGGER_SPAWN walls
 *              the wall will initially be present
 */
_func_wall_use(edict_t self, edict_t other /* unused */, edict_t activator /* unused */) {
	if (self == null) {
		return;
	}

	if (self.solid == solid_t.SOLID_NOT)
	{
		self.solid = solid_t.SOLID_BSP;
		self.svflags &= ~SVF_NOCLIENT;
		KillBox(self);
	}
	else
	{
		self.solid = solid_t.SOLID_NOT;
		self.svflags |= SVF_NOCLIENT;
	}

	SV_LinkEdict(self);

	if ((self.spawnflags & 2) == 0) {
		self.use = null;
	}
}

SP_func_wall(edict_t self) {
	if (self == null) {
		return;
	}

	self.movetype = movetype_t.MOVETYPE_PUSH;
	PF_setmodel(self, self.model);

	if ((self.spawnflags & 8) != 0)
	{
		self.s.effects |= EF_ANIM_ALL;
	}

	if ((self.spawnflags & 16) != 0)
	{
		self.s.effects |= EF_ANIM_ALLFAST;
	}

	/* just a wall */
	if ((self.spawnflags & 7) == 0)
	{
		self.solid = solid_t.SOLID_BSP;
		SV_LinkEdict(self);
		return;
	}

	/* it must be TRIGGER_SPAWN */
	if ((self.spawnflags & 1) == 0)
	{
		self.spawnflags |= 1;
	}

	/* yell if the spawnflags are odd */
	if ((self.spawnflags & 4) != 0)
	{
		if ((self.spawnflags & 2) == 0)
		{
			Com_Printf("func_wall START_ON without TOGGLE\n");
			self.spawnflags |= 2;
		}
	}

	self.use = _func_wall_use;

	if ((self.spawnflags & 4) != 0)
	{
		self.solid = solid_t.SOLID_BSP;
	}
	else
	{
		self.solid = solid_t.SOLID_NOT;
		self.svflags |= SVF_NOCLIENT;
	}

	SV_LinkEdict(self);
}

/* ===================================================== */

/*
 * QUAKED misc_deadsoldier (1 .5 0) (-16 -16 0) (16 16 16) ON_BACK ON_STOMACH BACK_DECAP FETAL_POS SIT_DECAP IMPALED
 * This is the dead player model. Comes in 6 exciting different poses!
 */
_misc_deadsoldier_die(edict_t self, edict_t inflictor /* unused */, edict_t attacker /* unused */,
		int damage, List<double> point /* unused */) {

	if (self == null) {
		return;
	}

	if (self.health > -80) {
		return;
	}

	// gi.sound(self, CHAN_BODY, gi.soundindex("misc/udeath.wav"), 1, ATTN_NORM, 0);

	for (int n = 0; n < 4; n++)
	{
		ThrowGib(self,
				"models/objects/gibs/sm_meat/tris.md2",
				damage,
				GIB_ORGANIC);
	}

	ThrowHead(self, "models/objects/gibs/head2/tris.md2", damage, GIB_ORGANIC);
}

SP_misc_deadsoldier(edict_t ent) {
	if (ent == null) {
		return;
	}

	if (deathmatch.boolean) {
		/* auto-remove for deathmatch */
		G_FreeEdict(ent);
		return;
	}

	ent.movetype = movetype_t.MOVETYPE_NONE;
	ent.solid = solid_t.SOLID_BBOX;
	ent.s.modelindex = SV_ModelIndex("models/deadbods/dude/tris.md2");

	/* Defaults to frame 0 */
	if ((ent.spawnflags & 2) != 0)
	{
		ent.s.frame = 1;
	}
	else if ((ent.spawnflags & 4) != 0)
	{
		ent.s.frame = 2;
	}
	else if ((ent.spawnflags & 8) != 0)
	{
		ent.s.frame = 3;
	}
	else if ((ent.spawnflags & 16) != 0)
	{
		ent.s.frame = 4;
	}
	else if ((ent.spawnflags & 32) != 0)
	{
		ent.s.frame = 5;
	}
	else
	{
		ent.s.frame = 0;
	}

	ent.mins = [ -16, -16, 0 ];
	ent.maxs = [ 16, 16, 16 ];
	ent.deadflag = DEAD_DEAD;
	ent.takedamage = damage_t.DAMAGE_YES.index;
	ent.svflags |= SVF_MONSTER | SVF_DEADMONSTER;
	ent.die = _misc_deadsoldier_die;
	ent.monsterinfo.aiflags |= AI_GOOD_GUY;

	SV_LinkEdict(ent);
}