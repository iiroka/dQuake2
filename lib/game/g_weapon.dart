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
 * Weapon support functions.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/game/g_combat.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_send.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'game.dart';
import 'g_utils.dart';
import 'player/weapon.dart' show PlayerNoise;

/*
 * Used for all impact (hit/punch/slash) attacks
 */
bool fire_hit(edict_t self, List<double> aim, int damage, int kick) {
	// trace_t tr;
	// vec3_t forward, right, up;
	// vec3_t v;
	// vec3_t point;

	if (self == null) {
		return false;
	}

	/* Lazarus: Paranoia check */
	if (self.enemy == null) {
		return false;
	}

	/* see if enemy is in range */
  List<double> dir = [0,0,0];
	VectorSubtract(self.enemy.s.origin, self.s.origin, dir);
	double range = VectorLength(dir);
	if (range > aim[0])
	{
		return false;
	}

	if ((aim[1] > self.mins[0]) && (aim[1] < self.maxs[0])) {
		/* the hit is straight on so back the
		   range up to the edge of their bbox */
		range -= self.enemy.maxs[0];
	}
	else
	{
		/* this is a side hit so adjust the "right"
		   value out to the edge of their bbox */
		if (aim[1] < 0)
		{
			aim[1] = self.enemy.mins[0];
		}
		else
		{
			aim[1] = self.enemy.maxs[0];
		}
	}

  List<double> point = [0,0,0];
	VectorMA(self.s.origin, range, dir, point);

	final tr = SV_Trace(self.s.origin, null, null, point, self, MASK_SHOT);

	if (tr.fraction < 1)
	{
		if (!tr.ent.takedamage)
		{
			return false;
		}

		/* if it will hit any client/monster
		   then hit the one we wanted to hit */
		if ((tr.ent.svflags & SVF_MONSTER) != 0 || (tr.ent.client != null))
		{
			tr.ent = self.enemy;
		}
	}

  List<double> forward = [0,0,0];
  List<double> right = [0,0,0];
  List<double> up = [0,0,0];
	AngleVectors(self.s.angles, forward, right, up);
	VectorMA(self.s.origin, range, forward, point);
	VectorMA(point, aim[1], right, point);
	VectorMA(point, aim[2], up, point);
	VectorSubtract(point, self.enemy.s.origin, dir);

	/* do the damage */
	T_Damage(tr.ent, self, self, dir, point, [0,0,0], damage,
			kick ~/ 2, DAMAGE_NO_KNOCKBACK, MOD_HIT);

	if ((tr.ent.svflags & SVF_MONSTER) == 0 && (tr.ent.client == null))
	{
		return false;
	}

	/* do our special form of knockback here */
  List<double> v = [0,0,0];
	VectorMA(self.enemy.absmin, 0.5, self.enemy.size, v);
	VectorSubtract(v, point, v);
	VectorNormalize(v);
	VectorMA(self.enemy.velocity, kick.toDouble(), v, self.enemy.velocity);

	if (self.enemy.velocity[2] > 0)
	{
		self.enemy.groundentity = null;
	}

	return true;
}

/*
 * This is an internal support routine
 * used for bullet/pellet based weapons.
 */
_fire_lead(edict_t self, List<double> start, List<double> aimdir, int damage, int kick,
		int te_impact, int hspread, int vspread, int mod) {
	// vec3_t dir;
	// vec3_t forward, right, up;
	// vec3_t end;
	// float r;
	// float u;
	// vec3_t water_start;
	bool water = false;
	int content_mask = MASK_SHOT | MASK_WATER;

	if (self == null) {
		return;
	}

  List<double> water_start = [0,0,0];
	var tr = SV_Trace(self.s.origin, null, null, start, self, MASK_SHOT);

	if (!(tr.fraction < 1.0)) {
    List<double> dir = [0,0,0];
		vectoangles(aimdir, dir);
    List<double> forward = [0,0,0];
    List<double> right = [0,0,0];
    List<double> up = [0,0,0];
		AngleVectors(dir, forward, right, up);

		double r = crandk() * hspread;
		double u = crandk() * vspread;
    List<double> end = [0,0,0];
		VectorMA(start, 8192, forward, end);
		VectorMA(end, r, right, end);
		VectorMA(end, u, up, end);

		if ((SV_PointContents(start) & MASK_WATER) != 0)
		{
			water = true;
      water_start.setAll(0, start);
			content_mask &= ~MASK_WATER;
		}

		tr = SV_Trace(start, null, null, end, self, content_mask);

		/* see if we hit water */
		if ((tr.contents & MASK_WATER) != 0)
		{
			int color;

			water = true;
      water_start.setAll(0, tr.endpos);

			if (start[0] != tr.endpos[0] || start[1] != tr.endpos[1] || start[2] != tr.endpos[2])
			{
				if ((tr.contents & CONTENTS_WATER) != 0)
				{
					if (tr.surface.name == "*brwater")
					{
						color = SPLASH_BROWN_WATER;
					}
					else
					{
						color = SPLASH_BLUE_WATER;
					}
				}
				else if ((tr.contents & CONTENTS_SLIME) != 0)
				{
					color = SPLASH_SLIME;
				}
				else if ((tr.contents & CONTENTS_LAVA) != 0)
				{
					color = SPLASH_LAVA;
				}
				else
				{
					color = SPLASH_UNKNOWN;
				}

				if (color != SPLASH_UNKNOWN)
				{
					PF_WriteByte(svc_ops_e.svc_temp_entity.index);
					PF_WriteByte(temp_event_t.TE_SPLASH.index);
					PF_WriteByte(8);
					PF_WritePos(tr.endpos);
					PF_WriteDir(tr.plane.normal);
					PF_WriteByte(color);
					SV_Multicast(tr.endpos, multicast_t.MULTICAST_PVS);
				}

				/* change bullet's course when it enters water */
				VectorSubtract(end, start, dir);
				vectoangles(dir, dir);
				AngleVectors(dir, forward, right, up);
				r = crandk() * hspread * 2;
				u = crandk() * vspread * 2;
				VectorMA(water_start, 8192, forward, end);
				VectorMA(end, r, right, end);
				VectorMA(end, u, up, end);
			}

			/* re-trace ignoring water this time */
			tr = SV_Trace(water_start, null, null, end, self, MASK_SHOT);
		}
	}

	/* send gun puff / flash */
	if (!((tr.surface != null) && (tr.surface.flags & SURF_SKY) != 0))
	{
		if (tr.fraction < 1.0)
		{
			if (tr.ent.takedamage != 0)
			{
				T_Damage(tr.ent, self, self, aimdir, tr.endpos, tr.plane.normal,
						damage, kick, DAMAGE_BULLET, mod);
			}
			else
			{
				if (!tr.surface.name.startsWith("sky"))
				{
					PF_WriteByte(svc_ops_e.svc_temp_entity.index);
					PF_WriteByte(te_impact);
					PF_WritePos(tr.endpos);
					PF_WriteDir(tr.plane.normal);
					SV_Multicast(tr.endpos, multicast_t.MULTICAST_PVS);

					if (self.client != null)
					{
						PlayerNoise(self, tr.endpos, PNOISE_IMPACT);
					}
				}
			}
		}
	}

	/* if went through water, determine
	   where the end and make a bubble trail */
	if (water)
	{
		List<double> pos = [0,0,0];
		List<double> dir = [0,0,0];

		VectorSubtract(tr.endpos, water_start, dir);
		VectorNormalize(dir);
		VectorMA(tr.endpos, -2, dir, pos);

		if ((SV_PointContents(pos) & MASK_WATER) != 0)
		{
			tr.endpos.setAll(0, pos);
		}
		else
		{
			tr = SV_Trace(pos, null, null, water_start, tr.ent, MASK_WATER);
		}

		VectorAdd(water_start, tr.endpos, pos);
		VectorScale(pos, 0.5, pos);

		PF_WriteByte(svc_ops_e.svc_temp_entity.index);
		PF_WriteByte(temp_event_t.TE_BUBBLETRAIL.index);
		PF_WritePos(water_start);
		PF_WritePos(tr.endpos);
		SV_Multicast(pos, multicast_t.MULTICAST_PVS);
	}
}

/*
 * Fires a single round.  Used for machinegun and
 * chaingun.  Would be fine for pistols, rifles, etc....
 */
fire_bullet(edict_t self, List<double> start, List<double> aimdir, int damage,
		int kick, int hspread, int vspread, int mod)
{
	if (self == null) {
		return;
	}

	_fire_lead(self, start, aimdir, damage, kick, temp_event_t.TE_GUNSHOT.index, hspread,
			vspread, mod);
}

/*
 * Shoots shotgun pellets. Used
 * by shotgun and super shotgun.
 */
fire_shotgun(edict_t self, List<double> start, List<double> aimdir, int damage,
		int kick, int hspread, int vspread, int count, int mod)
{
	if (self == null) {
		return;
	}

	for (int i = 0; i < count; i++) {
		_fire_lead(self, start, aimdir, damage, kick, temp_event_t.TE_SHOTGUN.index,
				hspread, vspread, mod);
	}
}

/*
 * Fires a single blaster bolt.
 * Used by the blaster and hyper blaster.
 */
blaster_touch(edict_t self, edict_t other, cplane_t plane, csurface_t surf) {
	int mod;

	if (self == null || other == null) /* plane and surf can be NULL */
	{
		G_FreeEdict(self);
		return;
	}

	if (other == self.owner)
	{
		return;
	}

	if (surf != null && (surf.flags & SURF_SKY) != 0)
	{
		G_FreeEdict(self);
		return;
	}

	if (self.owner != null && self.owner.client != null) {
		PlayerNoise(self.owner, self.s.origin, PNOISE_IMPACT);
	}

	if (other.takedamage != 0)
	{
		if ((self.spawnflags & 1) != 0)
		{
			mod = MOD_HYPERBLASTER;
		}
		else
		{
			mod = MOD_BLASTER;
		}

		if (plane != null)
		{
			T_Damage(other, self, self.owner, self.velocity, self.s.origin,
					plane.normal, self.dmg, 1, DAMAGE_ENERGY, mod);
		}
		else
		{
			T_Damage(other, self, self.owner, self.velocity, self.s.origin,
					[0,0,0], self.dmg, 1, DAMAGE_ENERGY, mod);
		}
	}
	else
	{
		PF_WriteByte(svc_ops_e.svc_temp_entity.index);
		PF_WriteByte(temp_event_t.TE_BLASTER.index);
		PF_WritePos(self.s.origin);

		if (plane == null) {
			PF_WriteDir([0,0,0]);
		} else {
			PF_WriteDir(plane.normal);
		}

    SV_Multicast(self.s.origin, multicast_t.MULTICAST_PVS);
	}

	G_FreeEdict(self);
}

fire_blaster(edict_t self, List<double> start, List<double> dir, int damage,
		int speed, int effect, bool hyper) {

	if (self == null) {
		return;
	}

	VectorNormalize(dir);

	var bolt = G_Spawn();
	bolt.svflags = SVF_DEADMONSTER;

	/* yes, I know it looks weird that projectiles are deadmonsters
	   what this means is that when prediction is used against the object
	   (blaster/hyperblaster shots), the player won't be solid clipped against
	   the object.  Right now trying to run into a firing hyperblaster
	   is very jerky since you are predicted 'against' the shots. */
  bolt.s.origin.setAll(0, start);
  bolt.s.old_origin.setAll(0, start);
	vectoangles(dir, bolt.s.angles);
	VectorScale(dir, speed.toDouble(), bolt.velocity);
	bolt.movetype = movetype_t.MOVETYPE_FLYMISSILE;
	bolt.clipmask = MASK_SHOT;
	bolt.solid = solid_t.SOLID_BBOX;
	bolt.s.effects |= effect;
	bolt.s.renderfx |= RF_NOSHADOW;
	bolt.mins = [0,0,0];
	bolt.maxs = [0,0,0];
	bolt.s.modelindex = SV_ModelIndex("models/objects/laser/tris.md2");
	bolt.s.sound = SV_SoundIndex("misc/lasfly.wav");
	bolt.owner = self;
	bolt.touch = blaster_touch;
	bolt.nextthink = level.time + 2;
	bolt.think = G_FreeEdict;
	bolt.dmg = damage;
	bolt.classname = "bolt";

	if (hyper) {
		bolt.spawnflags = 1;
	}

	SV_LinkEdict(bolt);

	// if (self.client != null) {
	// 	check_dodge(self, bolt.s.origin, dir, speed);
	// }

	var tr = SV_Trace(self.s.origin, null, null, bolt.s.origin, bolt, MASK_SHOT);
	if (tr.fraction < 1.0)
	{
		VectorMA(bolt.s.origin, -10, dir, bolt.s.origin);
		bolt.touch(bolt, tr.ent, null, null);
	}
}
