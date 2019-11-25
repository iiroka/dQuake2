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

  print("blaster_touch ${other.takedamage}");
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
