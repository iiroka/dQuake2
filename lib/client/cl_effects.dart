/*
 * Copyright (C) 1997-2001 Id Software, Inc.
 * Copyright (C) 2019      Iiro Kaihlaniemi
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
 * This file implements all specialized client side effects.  E.g.
 * weapon effects, enemy effects, flash, etc.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/flash.dart';
import 'package:dQuakeWeb/shared/readbuf.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'client.dart';
import 'cl_lights.dart';
import 'cl_particles.dart';
import 'cl_tempentities.dart' show CL_SmokeAndFlash;

CL_AddMuzzleFlash(Readbuf msg) {

	final i = msg.ReadShort();
	if ((i < 1) || (i >= MAX_EDICTS)) {
		Com_Error(ERR_DROP, "CL_AddMuzzleFlash: bad entity");
	}

	var weapon = msg.ReadByte();
	final silenced = (weapon & MZ_SILENCED) != 0;
	weapon &= ~MZ_SILENCED;

	final pl = cl_entities[i];

	var dl = CL_AllocDlight(i);
  dl.origin.setAll(0, pl.current.origin);
  List<double> fv = [0,0,0];
  List<double> rv = [0,0,0];
	AngleVectors(pl.current.angles, fv, rv, null);
	VectorMA(dl.origin, 18, fv, dl.origin);
	VectorMA(dl.origin, 16, rv, dl.origin);

	if (silenced) {
		dl.radius = 100.0 + (randk() & 31);
	} else {
		dl.radius = 200.0 + (randk() & 31);
	}

	dl.minlight = 32;
	dl.die = cl.time.toDouble();

  double volume = 1;
	if (silenced) {
		volume = 0.2;
	}

	switch (weapon) {
		case MZ_BLASTER:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/blastf1a.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_BLUEHYPERBLASTER:
			dl.color[0] = 0;
			dl.color[1] = 0;
			dl.color[2] = 1;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/hyprbf1a.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_HYPERBLASTER:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/hyprbf1a.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_MACHINEGUN:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		Com_sprintf(soundname, sizeof(soundname), "weapons/machgf%lub.wav",
	// 			(randk() % 5) + 1);
	// 		S_StartSound(NULL, i, CHAN_WEAPON, S_RegisterSound(
	// 					soundname), volume, ATTN_NORM, 0);
			break;
		case MZ_SHOTGUN:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/shotgf1b.wav"), volume, ATTN_NORM, 0);
	// 		S_StartSound(NULL, i, CHAN_AUTO,
	// 			S_RegisterSound("weapons/shotgr1b.wav"), volume, ATTN_NORM, 0.1f);
			break;
		case MZ_SSHOTGUN:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/sshotf1b.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_CHAINGUN1:
			dl.radius = 200.0 + (randk() & 31);
			dl.color[0] = 1;
			dl.color[1] = 0.25;
			dl.color[2] = 0;
	// 		Com_sprintf(soundname, sizeof(soundname), "weapons/machgf%lub.wav",
	// 			(randk() % 5) + 1);
	// 		S_StartSound(NULL, i, CHAN_WEAPON, S_RegisterSound(
	// 					soundname), volume, ATTN_NORM, 0);
			break;
		case MZ_CHAINGUN2:
			dl.radius = 225.0 + (randk() & 31);
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0;
			dl.die = cl.time + 0.1;  /* long delay */
	// 		Com_sprintf(soundname, sizeof(soundname), "weapons/machgf%lub.wav",
	// 			(randk() % 5) + 1);
	// 		S_StartSound(NULL, i, CHAN_WEAPON, S_RegisterSound(
	// 					soundname), volume, ATTN_NORM, 0);
	// 		Com_sprintf(soundname, sizeof(soundname), "weapons/machgf%lub.wav",
	// 			(randk() % 5) + 1);
	// 		S_StartSound(NULL, i, CHAN_WEAPON, S_RegisterSound(
	// 					soundname), volume, ATTN_NORM, 0.05);
			break;
		case MZ_CHAINGUN3:
			dl.radius = 250.0 + (randk() & 31);
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			dl.die = cl.time + 0.1;  /* long delay */
	// 		Com_sprintf(soundname, sizeof(soundname), "weapons/machgf%lub.wav",
	// 			(randk() % 5) + 1);
	// 		S_StartSound(NULL, i, CHAN_WEAPON, S_RegisterSound(
	// 					soundname), volume, ATTN_NORM, 0);
	// 		Com_sprintf(soundname, sizeof(soundname), "weapons/machgf%lub.wav",
	// 			(randk() % 5) + 1);
	// 		S_StartSound(NULL, i, CHAN_WEAPON, S_RegisterSound(
	// 					soundname), volume, ATTN_NORM, 0.033f);
	// 		Com_sprintf(soundname, sizeof(soundname), "weapons/machgf%lub.wav",
	// 			(randk() % 5) + 1);
	// 		S_StartSound(NULL, i, CHAN_WEAPON, S_RegisterSound(
	// 					soundname), volume, ATTN_NORM, 0.066f);
			break;
		case MZ_RAILGUN:
			dl.color[0] = 0.5;
			dl.color[1] = 0.5;
			dl.color[2] = 1.0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/railgf1a.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_ROCKET:
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0.2;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/rocklf1a.wav"), volume, ATTN_NORM, 0);
	// 		S_StartSound(NULL, i, CHAN_AUTO,
	// 			S_RegisterSound("weapons/rocklr1b.wav"), volume, ATTN_NORM, 0.1f);
			break;
		case MZ_GRENADE:
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/grenlf1a.wav"), volume, ATTN_NORM, 0);
	// 		S_StartSound(NULL, i, CHAN_AUTO,
	// 			S_RegisterSound("weapons/grenlr1b.wav"), volume, ATTN_NORM, 0.1f);
			break;
		case MZ_BFG:
			dl.color[0] = 0;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/bfg__f1y.wav"), volume, ATTN_NORM, 0);
			break;

		case MZ_LOGIN:
			dl.color[0] = 0;
			dl.color[1] = 1;
			dl.color[2] = 0;
			dl.die = cl.time + 1.0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/grenlf1a.wav"), 1, ATTN_NORM, 0);
	// 		CL_LogoutEffect(pl->current.origin, weapon);
			break;
		case MZ_LOGOUT:
			dl.color[0] = 1;
			dl.color[1] = 0;
			dl.color[2] = 0;
			dl.die = cl.time + 1.0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/grenlf1a.wav"), 1, ATTN_NORM, 0);
	// 		CL_LogoutEffect(pl->current.origin, weapon);
			break;
		case MZ_RESPAWN:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			dl.die = cl.time + 1.0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/grenlf1a.wav"), 1, ATTN_NORM, 0);
	// 		CL_LogoutEffect(pl->current.origin, weapon);
			break;
		case MZ_PHALANX:
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0.5;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/plasshot.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_IONRIPPER:
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0.5;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/rippfire.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_ETF_RIFLE:
			dl.color[0] = 0.9;
			dl.color[1] = 0.7;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/nail1.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_SHOTGUN2:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/shotg2.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_HEATBEAM:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			dl.die = cl.time + 100.0;
			break;
		case MZ_BLASTER2:
			dl.color[0] = 0;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/blastf1a.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_TRACKER:
			/* negative flashes handled the same in gl/soft until CL_AddDLights */
			dl.color[0] = -1;
			dl.color[1] = -1;
			dl.color[2] = -1;
	// 		S_StartSound(NULL, i, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/disint2.wav"), volume, ATTN_NORM, 0);
			break;
		case MZ_NUKE1:
			dl.color[0] = 1;
			dl.color[1] = 0;
			dl.color[2] = 0;
			dl.die = cl.time + 100.0;
			break;
		case MZ_NUKE2:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			dl.die = cl.time + 100.0;
			break;
		case MZ_NUKE4:
			dl.color[0] = 0;
			dl.color[1] = 0;
			dl.color[2] = 1;
			dl.die = cl.time + 100.0;
			break;
		case MZ_NUKE8:
			dl.color[0] = 0;
			dl.color[1] = 1;
			dl.color[2] = 1;
			dl.die = cl.time + 100.0;
			break;
	}
}

CL_AddMuzzleFlash2(Readbuf msg) {

	final ent = msg.ReadShort();
	if ((ent < 1) || (ent >= MAX_EDICTS)) {
		Com_Error(ERR_DROP, "CL_AddMuzzleFlash2: bad entity");
	}

	final flash_number = msg.ReadByte();
	if (flash_number > 210) {
		Com_DPrintf("CL_AddMuzzleFlash2: bad offset");
		return;
	}

	/* locate the origin */
  List<double> origin = [0,0,0];
  List<double> forward = [0,0,0];
  List<double> right = [0,0,0];
	AngleVectors(cl_entities[ent].current.angles, forward, right, null);
	origin[0] = cl_entities[ent].current.origin[0] + forward[0] *
				monster_flash_offset[flash_number][0] + right[0] *
				monster_flash_offset[flash_number][1];
	origin[1] = cl_entities[ent].current.origin[1] + forward[1] *
				monster_flash_offset[flash_number][0] + right[1] *
				monster_flash_offset[flash_number][1];
	origin[2] = cl_entities[ent].current.origin[2] + forward[2] *
				monster_flash_offset[flash_number][0] + right[2] *
				monster_flash_offset[flash_number][1] +
				monster_flash_offset[flash_number][2];

	var dl = CL_AllocDlight(ent);
  dl.origin.setAll(0, origin);
	dl.radius = 200.0 + (randk() & 31);
	dl.minlight = 32;
	dl.die = cl.time.toDouble();

	switch (flash_number)
	{
		case MZ2_INFANTRY_MACHINEGUN_1:
		case MZ2_INFANTRY_MACHINEGUN_2:
		case MZ2_INFANTRY_MACHINEGUN_3:
		case MZ2_INFANTRY_MACHINEGUN_4:
		case MZ2_INFANTRY_MACHINEGUN_5:
		case MZ2_INFANTRY_MACHINEGUN_6:
		case MZ2_INFANTRY_MACHINEGUN_7:
		case MZ2_INFANTRY_MACHINEGUN_8:
		case MZ2_INFANTRY_MACHINEGUN_9:
		case MZ2_INFANTRY_MACHINEGUN_10:
		case MZ2_INFANTRY_MACHINEGUN_11:
		case MZ2_INFANTRY_MACHINEGUN_12:
		case MZ2_INFANTRY_MACHINEGUN_13:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("infantry/infatck1.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_SOLDIER_MACHINEGUN_1:
		case MZ2_SOLDIER_MACHINEGUN_2:
		case MZ2_SOLDIER_MACHINEGUN_3:
		case MZ2_SOLDIER_MACHINEGUN_4:
		case MZ2_SOLDIER_MACHINEGUN_5:
		case MZ2_SOLDIER_MACHINEGUN_6:
		case MZ2_SOLDIER_MACHINEGUN_7:
		case MZ2_SOLDIER_MACHINEGUN_8:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("soldier/solatck3.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_GUNNER_MACHINEGUN_1:
		case MZ2_GUNNER_MACHINEGUN_2:
		case MZ2_GUNNER_MACHINEGUN_3:
		case MZ2_GUNNER_MACHINEGUN_4:
		case MZ2_GUNNER_MACHINEGUN_5:
		case MZ2_GUNNER_MACHINEGUN_6:
		case MZ2_GUNNER_MACHINEGUN_7:
		case MZ2_GUNNER_MACHINEGUN_8:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("gunner/gunatck2.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_ACTOR_MACHINEGUN_1:
		case MZ2_SUPERTANK_MACHINEGUN_1:
		case MZ2_SUPERTANK_MACHINEGUN_2:
		case MZ2_SUPERTANK_MACHINEGUN_3:
		case MZ2_SUPERTANK_MACHINEGUN_4:
		case MZ2_SUPERTANK_MACHINEGUN_5:
		case MZ2_SUPERTANK_MACHINEGUN_6:
		case MZ2_TURRET_MACHINEGUN:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;

			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("infantry/infatck1.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_BOSS2_MACHINEGUN_L1:
		case MZ2_BOSS2_MACHINEGUN_L2:
		case MZ2_BOSS2_MACHINEGUN_L3:
		case MZ2_BOSS2_MACHINEGUN_L4:
		case MZ2_BOSS2_MACHINEGUN_L5:
		case MZ2_CARRIER_MACHINEGUN_L1:
		case MZ2_CARRIER_MACHINEGUN_L2:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;

			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("infantry/infatck1.wav"), 1, ATTN_NONE, 0);
			break;

		case MZ2_SOLDIER_BLASTER_1:
		case MZ2_SOLDIER_BLASTER_2:
		case MZ2_SOLDIER_BLASTER_3:
		case MZ2_SOLDIER_BLASTER_4:
		case MZ2_SOLDIER_BLASTER_5:
		case MZ2_SOLDIER_BLASTER_6:
		case MZ2_SOLDIER_BLASTER_7:
		case MZ2_SOLDIER_BLASTER_8:
		case MZ2_TURRET_BLASTER:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("soldier/solatck2.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_FLYER_BLASTER_1:
		case MZ2_FLYER_BLASTER_2:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("flyer/flyatck3.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_MEDIC_BLASTER_1:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("medic/medatck1.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_HOVER_BLASTER_1:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("hover/hovatck1.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_FLOAT_BLASTER_1:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("floater/fltatck1.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_SOLDIER_SHOTGUN_1:
		case MZ2_SOLDIER_SHOTGUN_2:
		case MZ2_SOLDIER_SHOTGUN_3:
		case MZ2_SOLDIER_SHOTGUN_4:
		case MZ2_SOLDIER_SHOTGUN_5:
		case MZ2_SOLDIER_SHOTGUN_6:
		case MZ2_SOLDIER_SHOTGUN_7:
		case MZ2_SOLDIER_SHOTGUN_8:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			CL_SmokeAndFlash(origin);
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("soldier/solatck1.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_TANK_BLASTER_1:
		case MZ2_TANK_BLASTER_2:
		case MZ2_TANK_BLASTER_3:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("tank/tnkatck3.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_TANK_MACHINEGUN_1:
		case MZ2_TANK_MACHINEGUN_2:
		case MZ2_TANK_MACHINEGUN_3:
		case MZ2_TANK_MACHINEGUN_4:
		case MZ2_TANK_MACHINEGUN_5:
		case MZ2_TANK_MACHINEGUN_6:
		case MZ2_TANK_MACHINEGUN_7:
		case MZ2_TANK_MACHINEGUN_8:
		case MZ2_TANK_MACHINEGUN_9:
		case MZ2_TANK_MACHINEGUN_10:
		case MZ2_TANK_MACHINEGUN_11:
		case MZ2_TANK_MACHINEGUN_12:
		case MZ2_TANK_MACHINEGUN_13:
		case MZ2_TANK_MACHINEGUN_14:
		case MZ2_TANK_MACHINEGUN_15:
		case MZ2_TANK_MACHINEGUN_16:
		case MZ2_TANK_MACHINEGUN_17:
		case MZ2_TANK_MACHINEGUN_18:
		case MZ2_TANK_MACHINEGUN_19:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
	// 		Com_sprintf(soundname, sizeof(soundname), "tank/tnkatk2%c.wav",
	// 			'a' + (char)(randk() % 5));
	// 		S_StartSound(NULL, ent, CHAN_WEAPON, 
	// 			S_RegisterSound(soundname), 1, ATTN_NORM, 0);
			break;

		case MZ2_CHICK_ROCKET_1:
		case MZ2_TURRET_ROCKET:
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0.2;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("chick/chkatck2.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_TANK_ROCKET_1:
		case MZ2_TANK_ROCKET_2:
		case MZ2_TANK_ROCKET_3:
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0.2;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("tank/tnkatck1.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_SUPERTANK_ROCKET_1:
		case MZ2_SUPERTANK_ROCKET_2:
		case MZ2_SUPERTANK_ROCKET_3:
		case MZ2_BOSS2_ROCKET_1:
		case MZ2_BOSS2_ROCKET_2:
		case MZ2_BOSS2_ROCKET_3:
		case MZ2_BOSS2_ROCKET_4:
		case MZ2_CARRIER_ROCKET_1:
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0.2;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("tank/rocket.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_GUNNER_GRENADE_1:
		case MZ2_GUNNER_GRENADE_2:
		case MZ2_GUNNER_GRENADE_3:
		case MZ2_GUNNER_GRENADE_4:
			dl.color[0] = 1;
			dl.color[1] = 0.5;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("gunner/gunatck3.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_GLADIATOR_RAILGUN_1:
		case MZ2_CARRIER_RAILGUN:
		case MZ2_WIDOW_RAIL:
			dl.color[0] = 0.5;
			dl.color[1] = 0.5;
			dl.color[2] = 1.0;
			break;

		case MZ2_MAKRON_BFG:
			dl.color[0] = 0.5;
			dl.color[1] = 1;
			dl.color[2] = 0.5;
			break;

		case MZ2_MAKRON_BLASTER_1:
		case MZ2_MAKRON_BLASTER_2:
		case MZ2_MAKRON_BLASTER_3:
		case MZ2_MAKRON_BLASTER_4:
		case MZ2_MAKRON_BLASTER_5:
		case MZ2_MAKRON_BLASTER_6:
		case MZ2_MAKRON_BLASTER_7:
		case MZ2_MAKRON_BLASTER_8:
		case MZ2_MAKRON_BLASTER_9:
		case MZ2_MAKRON_BLASTER_10:
		case MZ2_MAKRON_BLASTER_11:
		case MZ2_MAKRON_BLASTER_12:
		case MZ2_MAKRON_BLASTER_13:
		case MZ2_MAKRON_BLASTER_14:
		case MZ2_MAKRON_BLASTER_15:
		case MZ2_MAKRON_BLASTER_16:
		case MZ2_MAKRON_BLASTER_17:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("makron/blaster.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_JORG_MACHINEGUN_L1:
		case MZ2_JORG_MACHINEGUN_L2:
		case MZ2_JORG_MACHINEGUN_L3:
		case MZ2_JORG_MACHINEGUN_L4:
		case MZ2_JORG_MACHINEGUN_L5:
		case MZ2_JORG_MACHINEGUN_L6:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("boss3/xfire.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_JORG_MACHINEGUN_R1:
		case MZ2_JORG_MACHINEGUN_R2:
		case MZ2_JORG_MACHINEGUN_R3:
		case MZ2_JORG_MACHINEGUN_R4:
		case MZ2_JORG_MACHINEGUN_R5:
		case MZ2_JORG_MACHINEGUN_R6:
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
			break;

		case MZ2_JORG_BFG_1:
			dl.color[0] = 0.5;
			dl.color[1] = 1;
			dl.color[2] = 0.5;
			break;

		case MZ2_BOSS2_MACHINEGUN_R1:
		case MZ2_BOSS2_MACHINEGUN_R2:
		case MZ2_BOSS2_MACHINEGUN_R3:
		case MZ2_BOSS2_MACHINEGUN_R4:
		case MZ2_BOSS2_MACHINEGUN_R5:
		case MZ2_CARRIER_MACHINEGUN_R1:
		case MZ2_CARRIER_MACHINEGUN_R2:

			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;

			CL_ParticleEffect(origin, [0,0,0], 0, 40);
			CL_SmokeAndFlash(origin);
			break;

		case MZ2_STALKER_BLASTER:
		case MZ2_DAEDALUS_BLASTER:
		case MZ2_MEDIC_BLASTER_2:
		case MZ2_WIDOW_BLASTER:
		case MZ2_WIDOW_BLASTER_SWEEP1:
		case MZ2_WIDOW_BLASTER_SWEEP2:
		case MZ2_WIDOW_BLASTER_SWEEP3:
		case MZ2_WIDOW_BLASTER_SWEEP4:
		case MZ2_WIDOW_BLASTER_SWEEP5:
		case MZ2_WIDOW_BLASTER_SWEEP6:
		case MZ2_WIDOW_BLASTER_SWEEP7:
		case MZ2_WIDOW_BLASTER_SWEEP8:
		case MZ2_WIDOW_BLASTER_SWEEP9:
		case MZ2_WIDOW_BLASTER_100:
		case MZ2_WIDOW_BLASTER_90:
		case MZ2_WIDOW_BLASTER_80:
		case MZ2_WIDOW_BLASTER_70:
		case MZ2_WIDOW_BLASTER_60:
		case MZ2_WIDOW_BLASTER_50:
		case MZ2_WIDOW_BLASTER_40:
		case MZ2_WIDOW_BLASTER_30:
		case MZ2_WIDOW_BLASTER_20:
		case MZ2_WIDOW_BLASTER_10:
		case MZ2_WIDOW_BLASTER_0:
		case MZ2_WIDOW_BLASTER_10L:
		case MZ2_WIDOW_BLASTER_20L:
		case MZ2_WIDOW_BLASTER_30L:
		case MZ2_WIDOW_BLASTER_40L:
		case MZ2_WIDOW_BLASTER_50L:
		case MZ2_WIDOW_BLASTER_60L:
		case MZ2_WIDOW_BLASTER_70L:
		case MZ2_WIDOW_RUN_1:
		case MZ2_WIDOW_RUN_2:
		case MZ2_WIDOW_RUN_3:
		case MZ2_WIDOW_RUN_4:
		case MZ2_WIDOW_RUN_5:
		case MZ2_WIDOW_RUN_6:
		case MZ2_WIDOW_RUN_7:
		case MZ2_WIDOW_RUN_8:
			dl.color[0] = 0;
			dl.color[1] = 1;
			dl.color[2] = 0;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("tank/tnkatck3.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_WIDOW_DISRUPTOR:
			dl.color[0] = -1;
			dl.color[1] = -1;
			dl.color[2] = -1;
	// 		S_StartSound(NULL, ent, CHAN_WEAPON,
	// 			S_RegisterSound("weapons/disint2.wav"), 1, ATTN_NORM, 0);
			break;

		case MZ2_WIDOW_PLASMABEAM:
		case MZ2_WIDOW2_BEAMER_1:
		case MZ2_WIDOW2_BEAMER_2:
		case MZ2_WIDOW2_BEAMER_3:
		case MZ2_WIDOW2_BEAMER_4:
		case MZ2_WIDOW2_BEAMER_5:
		case MZ2_WIDOW2_BEAM_SWEEP_1:
		case MZ2_WIDOW2_BEAM_SWEEP_2:
		case MZ2_WIDOW2_BEAM_SWEEP_3:
		case MZ2_WIDOW2_BEAM_SWEEP_4:
		case MZ2_WIDOW2_BEAM_SWEEP_5:
		case MZ2_WIDOW2_BEAM_SWEEP_6:
		case MZ2_WIDOW2_BEAM_SWEEP_7:
		case MZ2_WIDOW2_BEAM_SWEEP_8:
		case MZ2_WIDOW2_BEAM_SWEEP_9:
		case MZ2_WIDOW2_BEAM_SWEEP_10:
		case MZ2_WIDOW2_BEAM_SWEEP_11:
			dl.radius = 300.0 + (randk() & 100);
			dl.color[0] = 1;
			dl.color[1] = 1;
			dl.color[2] = 0;
			dl.die = cl.time + 200.0;
			break;
	}
}

CL_ExplosionParticles(List<double> org) {

	final time = cl.time.toDouble();

	for (int i = 0; i < 256; i++) {
		if (free_particles == null) {
			return;
		}

		final p = free_particles;
		free_particles = p.next;
		p.next = active_particles;
		active_particles = p;

		p.time = time;
		p.color = (0xe0 + (randk() & 7)).toDouble();

		for (int j = 0; j < 3; j++) {
			p.org[j] = org[j] + ((randk() % 32) - 16);
			p.vel[j] = ((randk() % 384) - 192).toDouble();
		}

		p.accel[0] = p.accel[1] = 0;
		p.accel[2] = (-PARTICLE_GRAVITY).toDouble();
		p.alpha = 1.0;

		p.alphavel = -0.8 / (0.5 + frandk() * 0.3);
	}
}


/*
 *  Wall impact puffs
 */
CL_BlasterParticles(List<double> org, List<double> dir) {

	double time = cl.time.toDouble();

	int count = 40;

	for (int i = 0; i < count; i++) {
		if (free_particles == null) {
			return;
		}

		var p = free_particles;
		free_particles = p.next;
		p.next = active_particles;
		active_particles = p;

		p.time = time;
		p.color = (0xe0 + (randk() & 7)).toDouble();
		double d = (randk() & 15).toDouble();

		for (int j = 0; j < 3; j++) {
			p.org[j] = org[j] + ((randk() & 7) - 4) + d * dir[j];
			p.vel[j] = dir[j] * 30 + crandk() * 40;
		}

		p.accel[0] = p.accel[1] = 0;
		p.accel[2] = (-PARTICLE_GRAVITY).toDouble();
		p.alpha = 1.0;

		p.alphavel = -1.0 / (0.5 + frandk() * 0.3);
	}
}

CL_BlasterTrail(List<double> start, List<double> end) {
	// vec3_t move;
	// vec3_t vec;
	// int len;
	// int j;
	// cparticle_t *p;
	// int dec;
	// float time;

	double time = cl.time.toDouble();

  List<double> move = List.generate(3, (i) => start[i]);
  List<double> vec = [0,0,0];
	VectorSubtract(end, start, vec);
	int len = VectorNormalize(vec).toInt();

	int dec = 5;
	VectorScale(vec, 5, vec);

	while (len > 0) {
		len -= dec;

		if (free_particles == null) {
			return;
		}

		var p = free_particles;
		free_particles = p.next;
		p.next = active_particles;
		active_particles = p;
		p.accel.fillRange(0, 3, 0);

		p.time = time;

		p.alpha = 1.0;
		p.alphavel = -1.0 / (0.3 + frandk() * 0.2);
		p.color = 0xe0;

		for (int j = 0; j < 3; j++) {
			p.org[j] = move[j] + crandk();
			p.vel[j] = crandk() * 5;
			p.accel[j] = 0;
		}

		VectorAdd(move, vec, move);
	}
}


CL_ClearEffects() {
	CL_ClearParticles();
	CL_ClearDlights();
	CL_ClearLightStyles();
}

/*
 * Green!
 */
CL_BlasterTrail2(List<double> start, List<double> end) {
	// vec3_t move;
	// vec3_t vec;
	// float len;
	// int j;
	// cparticle_t *p;
	// int dec;
	// float time;

	double time = cl.time.toDouble();

  List<double> move = List.generate(3, (i) => start[i]);
  List<double> vec = [0,0,0];
	VectorSubtract(end, start, vec);
	double len = VectorNormalize(vec);

	int dec = 5;
	VectorScale(vec, 5, vec);

	while (len > 0) {
		len -= dec;

		if (free_particles == null) {
			return;
		}

		var p = free_particles;
		free_particles = p.next;
		p.next = active_particles;
		active_particles = p;
		p.accel.fillRange(0, 3, 0);

		p.time = time;

		p.alpha = 1.0;
		p.alphavel = -1.0 / (0.3 + frandk() * 0.2);

		for (int j = 0; j < 3; j++) {
			p.org[j] = move[j] + crandk();
			p.vel[j] = crandk() * 5;
			p.accel[j] = 0;
		}

		VectorAdd(move, vec, move);
	}
}
