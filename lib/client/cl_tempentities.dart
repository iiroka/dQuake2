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
 * This file implements all temporary (dynamic created) entities
 *
 * =======================================================================
 */
import 'dart:math';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/readbuf.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'vid/ref.dart';
import 'vid/vid.dart' show re;
import 'client.dart';
import 'cl_particles.dart';
import 'cl_effects.dart';
import 'cl_view.dart' show V_AddEntity, V_AddLight;

enum exptype_t {
	ex_free, ex_explosion, ex_misc, ex_flash, ex_mflash, ex_poly, ex_poly2
}

class explosion_t {
	exptype_t type = exptype_t.ex_free;
	entity_t ent = entity_t();

	int frames = 0;
	double light = 0;
	List<double> lightcolor = [0,0,0];
	double start = 0;
	int baseframe = 0;

  clear() {
    this.type = exptype_t.ex_free;
    this.ent.clear();
    this.frames = 0;
    this.light = 0;
    this.lightcolor.fillRange(0, 3, 0);
    this.start = 0;
    this.baseframe = 0;
  }
}

const MAX_EXPLOSIONS = 64;
// #define MAX_BEAMS 64
// #define MAX_LASERS 64

List<explosion_t> cl_explosions = List.generate(MAX_EXPLOSIONS, (i) => explosion_t());

Object cl_sfx_ric1;
Object cl_sfx_ric2;
Object cl_sfx_ric3;
Object cl_sfx_lashit;
Object cl_sfx_spark5;
Object cl_sfx_spark6;
Object cl_sfx_spark7;
Object cl_sfx_railg;
Object cl_sfx_rockexp;
Object cl_sfx_grenexp;
Object cl_sfx_watrexp;
Object cl_sfx_plasexp;
List<Object> cl_sfx_footsteps = [null, null, null, null];

Object cl_mod_explode;
Object cl_mod_smoke;
Object cl_mod_flash;
Object cl_mod_parasite_segment;
Object cl_mod_grapple_cable;
Object cl_mod_parasite_tip;
Object cl_mod_explo4;
Object cl_mod_bfg_explo;
Object cl_mod_powerscreen;
Object cl_mod_plasmaexplo;

Object cl_sfx_lightning;
Object cl_sfx_disrexp;
Object cl_mod_lightning;
Object cl_mod_heatbeam;
Object cl_mod_monster_heatbeam;
Object cl_mod_explo4_big;

CL_RegisterTEntModels() async {
	cl_mod_explode = await re.RegisterModel("models/objects/explode/tris.md2");
	cl_mod_smoke = await re.RegisterModel("models/objects/smoke/tris.md2");
	cl_mod_flash = await re.RegisterModel("models/objects/flash/tris.md2");
	cl_mod_parasite_segment = await re.RegisterModel("models/monsters/parasite/segment/tris.md2");
	cl_mod_grapple_cable = await re.RegisterModel("models/ctf/segment/tris.md2");
	cl_mod_parasite_tip = await re.RegisterModel("models/monsters/parasite/tip/tris.md2");
	cl_mod_explo4 = await re.RegisterModel("models/objects/r_explode/tris.md2");
	cl_mod_bfg_explo = await re.RegisterModel("sprites/s_bfg2.sp2");
	cl_mod_powerscreen = await re.RegisterModel("models/items/armor/effect/tris.md2");

	await re.RegisterModel("models/objects/laser/tris.md2");
	await re.RegisterModel("models/objects/grenade2/tris.md2");
	await re.RegisterModel("models/weapons/v_machn/tris.md2");
	await re.RegisterModel("models/weapons/v_handgr/tris.md2");
	await re.RegisterModel("models/weapons/v_shotg2/tris.md2");
	await re.RegisterModel("models/objects/gibs/bone/tris.md2");
	await re.RegisterModel("models/objects/gibs/sm_meat/tris.md2");
	await re.RegisterModel("models/objects/gibs/bone2/tris.md2");

	await re.DrawFindPic("w_machinegun");
	await re.DrawFindPic("a_bullets");
	await re.DrawFindPic("i_health");
	await re.DrawFindPic("a_grenades");

	cl_mod_explo4_big = await re.RegisterModel("models/objects/r_explode2/tris.md2");
	cl_mod_lightning = await re.RegisterModel("models/proj/lightning/tris.md2");
	cl_mod_heatbeam = await re.RegisterModel("models/proj/beam/tris.md2");
	cl_mod_monster_heatbeam = await re.RegisterModel("models/proj/widowbeam/tris.md2");
}

CL_ClearTEnts() {
	// memset(cl_beams, 0, sizeof(cl_beams));
  for (var ex in cl_explosions) {
    ex.clear();
  }
	// memset(cl_lasers, 0, sizeof(cl_lasers));

	// memset(cl_playerbeams, 0, sizeof(cl_playerbeams));
	// memset(cl_sustains, 0, sizeof(cl_sustains));
}

explosion_t CL_AllocExplosion() {

	for (int i = 0; i < cl_explosions.length; i++) {
		if (cl_explosions[i].type == exptype_t.ex_free) {
			cl_explosions[i].clear();
			return cl_explosions[i];
		}
	}

	/* find the oldest explosion */
	double time = cl.time.toDouble();
	int index = 0;

	for (int i = 0; i < cl_explosions.length; i++) {
		if (cl_explosions[i].start < time) {
			time = cl_explosions[i].start;
			index = i;
		}
	}

	cl_explosions[index].clear();
	return cl_explosions[index];
}

CL_SmokeAndFlash(List<double> origin) {
	var ex = CL_AllocExplosion();
  ex.ent.origin.setAll(0, origin);
	ex.type = exptype_t.ex_misc;
	ex.frames = 4;
	ex.ent.flags = RF_TRANSLUCENT;
	ex.start = cl.frame.servertime - 100.0;
	ex.ent.model = cl_mod_smoke;

	ex = CL_AllocExplosion();
  ex.ent.origin.setAll(0, origin);
	ex.type = exptype_t.ex_flash;
	ex.ent.flags = RF_FULLBRIGHT;
	ex.frames = 2;
	ex.start = cl.frame.servertime - 100.0;
	ex.ent.model = cl_mod_flash;
}

final splash_color = [0x00, 0xe0, 0xb0, 0x50, 0xd0, 0xe0, 0xe8];

CL_ParseTEnt(Readbuf msg) {

	final type = msg.ReadByte();

  List<double> pos, dir, pos2;
  int cnt, color, r;
	switch (temp_event_t.values[type])
	{
		case temp_event_t.TE_BLOOD: /* bullet hitting flesh */
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			CL_ParticleEffect(pos, dir, 0xe8, 60);
			break;

		case temp_event_t.TE_GUNSHOT: /* bullet hitting wall */
		case temp_event_t.TE_SPARKS:
		case temp_event_t.TE_BULLET_SPARKS:
			pos = msg.ReadPos();
			dir = msg.ReadDir();

			if (type == temp_event_t.TE_GUNSHOT.index) {
				CL_ParticleEffect(pos, dir, 0, 40);
			}

			else
			{
				CL_ParticleEffect(pos, dir, 0xe0, 6);
			}

			if (type != temp_event_t.TE_SPARKS) {
				CL_SmokeAndFlash(pos);
				/* impact sound */
			// 	cnt = randk() & 15;

			// 	if (cnt == 1)
			// 	{
			// 		S_StartSound(pos, 0, 0, cl_sfx_ric1, 1, ATTN_NORM, 0);
			// 	}

			// 	else if (cnt == 2)
			// 	{
			// 		S_StartSound(pos, 0, 0, cl_sfx_ric2, 1, ATTN_NORM, 0);
			// 	}

			// 	else if (cnt == 3)
			// 	{
			// 		S_StartSound(pos, 0, 0, cl_sfx_ric3, 1, ATTN_NORM, 0);
			// 	}
			}

			break;

		case temp_event_t.TE_SCREEN_SPARKS:
		case temp_event_t.TE_SHIELD_SPARKS:
			pos = msg.ReadPos();
			dir = msg.ReadDir();

			if (type == temp_event_t.TE_SCREEN_SPARKS.index)
			{
				CL_ParticleEffect(pos, dir, 0xd0, 40);
			}

			else
			{
				CL_ParticleEffect(pos, dir, 0xb0, 40);
			}

			// num_power_sounds++;

			// /* If too many of these sounds are started in one frame (for
			//  * example if the player shoots with the super shotgun into
			//  * the power screen of a Brain) things get too loud and OpenAL
			//  * is forced to scale the volume of several other sounds and
			//  * the background music down. That leads to a noticable and
			//  * annoying drop in the overall volume.
			//  *
			//  * Work around that by limiting the number of sounds started.
			//  * 16 was choosen by empirical testing.
			//  */
			// if (sound_started == SS_OAL && num_power_sounds < 16)
			// {
			// 	S_StartSound(pos, 0, 0, cl_sfx_lashit, 1, ATTN_NORM, 0);
			// }

			break;

		case temp_event_t.TE_SHOTGUN: /* bullet hitting wall */
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			CL_ParticleEffect(pos, dir, 0, 20);
			CL_SmokeAndFlash(pos);
			break;

		case temp_event_t.TE_SPLASH: /* bullet hitting water */
			cnt = msg.ReadByte();
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			r = msg.ReadByte();

			if (r > 6) {
				color = 0x00;
			} else {
				color = splash_color[r];
			}

			CL_ParticleEffect(pos, dir, color, cnt);

			// if (r == SPLASH_SPARKS)
			// {
			// 	r = randk() & 3;

			// 	if (r == 0)
			// 	{
			// 		S_StartSound(pos, 0, 0, cl_sfx_spark5, 1, ATTN_STATIC, 0);
			// 	}

			// 	else if (r == 1)
			// 	{
			// 		S_StartSound(pos, 0, 0, cl_sfx_spark6, 1, ATTN_STATIC, 0);
			// 	}

			// 	else
			// 	{
			// 		S_StartSound(pos, 0, 0, cl_sfx_spark7, 1, ATTN_STATIC, 0);
			// 	}
			// }

			break;

		case temp_event_t.TE_LASER_SPARKS:
			cnt = msg.ReadByte();
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			color = msg.ReadByte();
			CL_ParticleEffect2(pos, dir, color, cnt);
			break;

		case temp_event_t.TE_BLUEHYPERBLASTER:
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			CL_BlasterParticles(pos, dir);
			break;

		case temp_event_t.TE_BLASTER: /* blaster hitting wall */
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			CL_BlasterParticles(pos, dir);

			var ex = CL_AllocExplosion();
      ex.ent.origin.setAll(0, pos);
			ex.ent.angles[0] = acos(dir[2]) / pi * 180;

			if (dir[0] != 0) {
				ex.ent.angles[1] = atan2(dir[1], dir[0]) / pi * 180;
			}

			else if (dir[1] > 0)
			{
				ex.ent.angles[1] = 90;
			}

			else if (dir[1] < 0)
			{
				ex.ent.angles[1] = 270;
			}

			else
			{
				ex.ent.angles[1] = 0;
			}

			ex.type = exptype_t.ex_misc;
			ex.ent.flags = 0;
			ex.start = cl.frame.servertime - 100.0;
			ex.light = 150;
			ex.lightcolor[0] = 1;
			ex.lightcolor[1] = 1;
			ex.ent.model = cl_mod_explode;
			ex.frames = 4;
			// S_StartSound(pos, 0, 0, cl_sfx_lashit, 1, ATTN_NORM, 0);
			break;

		case temp_event_t.TE_RAILTRAIL: /* railgun effect */
			pos = msg.ReadPos();
			pos2 = msg.ReadPos();
			// CL_RailTrail(pos, pos2);
			// S_StartSound(pos2, 0, 0, cl_sfx_railg, 1, ATTN_NORM, 0);
			break;

		case temp_event_t.TE_EXPLOSION2:
		case temp_event_t.TE_GRENADE_EXPLOSION:
		case temp_event_t.TE_GRENADE_EXPLOSION_WATER:
			pos = msg.ReadPos();
			var ex = CL_AllocExplosion();
      ex.ent.origin.setAll(0, pos);
			ex.type = exptype_t.ex_poly;
			ex.ent.flags = RF_FULLBRIGHT | RF_NOSHADOW;
			ex.start = cl.frame.servertime - 100.0;
			ex.light = 350;
			ex.lightcolor[0] = 1.0;
			ex.lightcolor[1] = 0.5;
			ex.lightcolor[2] = 0.5;
			ex.ent.model = cl_mod_explo4;
			ex.frames = 19;
			ex.baseframe = 30;
			ex.ent.angles[1] = (randk() % 360).toDouble();
			CL_ExplosionParticles(pos);

			// if (type == TE_GRENADE_EXPLOSION_WATER)
			// {
			// 	S_StartSound(pos, 0, 0, cl_sfx_watrexp, 1, ATTN_NORM, 0);
			// }

			// else
			// {
			// 	S_StartSound(pos, 0, 0, cl_sfx_grenexp, 1, ATTN_NORM, 0);
			// }

			break;

		case temp_event_t.TE_PLASMA_EXPLOSION:
			pos = msg.ReadPos();
			var ex = CL_AllocExplosion();
      ex.ent.origin.setAll(0, pos);
			ex.type = exptype_t.ex_poly;
			ex.ent.flags = RF_FULLBRIGHT | RF_NOSHADOW;
			ex.start = cl.frame.servertime - 100.0;
			ex.light = 350;
			ex.lightcolor[0] = 1.0;
			ex.lightcolor[1] = 0.5;
			ex.lightcolor[2] = 0.5;
			ex.ent.angles[1] = (randk() % 360).toDouble();
			ex.ent.model = cl_mod_explo4;

			if (frandk() < 0.5) {
				ex.baseframe = 15;
			}

			ex.frames = 15;
			CL_ExplosionParticles(pos);
			// S_StartSound(pos, 0, 0, cl_sfx_rockexp, 1, ATTN_NORM, 0);
			break;

		case temp_event_t.TE_EXPLOSION1_BIG:
		case temp_event_t.TE_EXPLOSION1_NP:
		case temp_event_t.TE_EXPLOSION1:
		case temp_event_t.TE_ROCKET_EXPLOSION:
		case temp_event_t.TE_ROCKET_EXPLOSION_WATER:
			pos = msg.ReadPos();
			var ex = CL_AllocExplosion();
      ex.ent.origin.setAll(0, pos);
			ex.type = exptype_t.ex_poly;
			ex.ent.flags = RF_FULLBRIGHT | RF_NOSHADOW;
			ex.start = cl.frame.servertime - 100.0;
			ex.light = 350;
			ex.lightcolor[0] = 1.0;
			ex.lightcolor[1] = 0.5;
			ex.lightcolor[2] = 0.5;
			ex.ent.angles[1] = (randk() % 360).toDouble();

			if (type != temp_event_t.TE_EXPLOSION1_BIG) {
				ex.ent.model = cl_mod_explo4;
			} else {
				ex.ent.model = cl_mod_explo4_big;
			}

			if (frandk() < 0.5) {
				ex.baseframe = 15;
			}

			ex.frames = 15;

			if ((type != temp_event_t.TE_EXPLOSION1_BIG) && (type != temp_event_t.TE_EXPLOSION1_NP)) {
				CL_ExplosionParticles(pos);
			}

			// if (type == TE_ROCKET_EXPLOSION_WATER)
			// {
			// 	S_StartSound(pos, 0, 0, cl_sfx_watrexp, 1, ATTN_NORM, 0);
			// }

			// else
			// {
			// 	S_StartSound(pos, 0, 0, cl_sfx_rockexp, 1, ATTN_NORM, 0);
			// }

			break;

		case temp_event_t.TE_BFG_EXPLOSION:
			pos = msg.ReadPos();
			var ex = CL_AllocExplosion();
      ex.ent.origin.setAll(0, pos);
			ex.type = exptype_t.ex_poly;
			ex.ent.flags = RF_FULLBRIGHT | RF_NOSHADOW;
			ex.start = cl.frame.servertime - 100.0;
			ex.light = 350;
			ex.lightcolor[0] = 0.0;
			ex.lightcolor[1] = 1.0;
			ex.lightcolor[2] = 0.0;
			ex.ent.model = cl_mod_bfg_explo;
			ex.ent.flags |= RF_TRANSLUCENT;
			ex.ent.alpha = 0.30;
			ex.frames = 4;
			break;

		case temp_event_t.TE_BFG_BIGEXPLOSION:
			pos = msg.ReadPos();
		// 	CL_BFGExplosionParticles(pos);
			break;

		// case temp_event_t.TE_BFG_LASER:
		// 	CL_ParseLaser(0xd0d1d2d3);
		// 	break;

		case temp_event_t.TE_BUBBLETRAIL:
			pos = msg.ReadPos();
			pos2 = msg.ReadPos();
		// 	CL_BubbleTrail(pos, pos2);
			break;

		// case temp_event_t.TE_PARASITE_ATTACK:
		// case temp_event_t.TE_MEDIC_CABLE_ATTACK:
		// 	CL_ParseBeam(cl_mod_parasite_segment);
		// 	break;

		// case temp_event_t.TE_BOSSTPORT: /* boss teleporting to station */
		// 	msg.ReadPos(, pos);
		// 	CL_BigTeleportParticles(pos);
		// 	S_StartSound(pos, 0, 0, S_RegisterSound(
		// 				"misc/bigtele.wav"), 1, ATTN_NONE, 0);
		// 	break;

		// case temp_event_t.TE_GRAPPLE_CABLE:
		// 	CL_ParseBeam2(cl_mod_grapple_cable);
		// 	break;

		case temp_event_t.TE_WELDING_SPARKS:
			cnt = msg.ReadByte();
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			color = msg.ReadByte();
			CL_ParticleEffect2(pos, dir, color, cnt);

			final ex = CL_AllocExplosion();
      ex.ent.origin.setAll(0, pos);
			ex.type = exptype_t.ex_flash;
			ex.ent.flags = RF_BEAM;
			ex.start = cl.frame.servertime - 0.1;
			ex.light = 100 + (randk() % 75).toDouble();
			ex.lightcolor[0] = 1.0;
			ex.lightcolor[1] = 1.0;
			ex.lightcolor[2] = 0.3;
			ex.ent.model = cl_mod_flash;
			ex.frames = 2;
			break;

		case temp_event_t.TE_GREENBLOOD:
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			CL_ParticleEffect2(pos, dir, 0xdf, 30);
			break;

		// case temp_event_t.TE_TUNNEL_SPARKS:
		// 	cnt = msg.ReadByte();
		// 	pos = msg.ReadPos();
		// 	dir = msg.ReadDir();
		// 	color = msg.ReadByte();
		// 	CL_ParticleEffect3(pos, dir, color, cnt);
		// 	break;

		// case temp_event_t.TE_BLASTER2:
		// case temp_event_t.TE_FLECHETTE:
		// 	pos = msg.ReadPos();
		// 	dir = msg.ReadDir();

		// 	if (type == TE_BLASTER2)
		// 	{
		// 		CL_BlasterParticles2(pos, dir, 0xd0);
		// 	}

		// 	else
		// 	{
		// 		CL_BlasterParticles2(pos, dir, 0x6f);
		// 	}

		// 	ex = CL_AllocExplosion();
		// 	VectorCopy(pos, ex->ent.origin);
		// 	ex->ent.angles[0] = (float)acos(dir[2]) / M_PI * 180;

		// 	if (dir[0])
		// 	{
		// 		ex->ent.angles[1] = (float)atan2(dir[1], dir[0]) / M_PI * 180;
		// 	}

		// 	else if (dir[1] > 0)
		// 	{
		// 		ex->ent.angles[1] = 90;
		// 	}

		// 	else if (dir[1] < 0)
		// 	{
		// 		ex->ent.angles[1] = 270;
		// 	}

		// 	else
		// 	{
		// 		ex->ent.angles[1] = 0;
		// 	}

		// 	ex->type = ex_misc;
		// 	ex->ent.flags = RF_FULLBRIGHT | RF_TRANSLUCENT;

		// 	if (type == TE_BLASTER2)
		// 	{
		// 		ex->ent.skinnum = 1;
		// 	}

		// 	else /* flechette */
		// 	{
		// 		ex->ent.skinnum = 2;
		// 	}

		// 	ex->start = cl.frame.servertime - 100.0f;
		// 	ex->light = 150;

		// 	if (type == TE_BLASTER2)
		// 	{
		// 		ex->lightcolor[1] = 1;
		// 	}

		// 	else
		// 	{
		// 		/* flechette */
		// 		ex->lightcolor[0] = 0.19f;
		// 		ex->lightcolor[1] = 0.41f;
		// 		ex->lightcolor[2] = 0.75f;
		// 	}

		// 	ex->ent.model = cl_mod_explode;
		// 	ex->frames = 4;
		// 	S_StartSound(pos, 0, 0, cl_sfx_lashit, 1, ATTN_NORM, 0);
		// 	break;

		// case temp_event_t.TE_LIGHTNING:
		// 	ent = CL_ParseLightning(cl_mod_lightning);
		// 	S_StartSound(NULL, ent, CHAN_WEAPON, cl_sfx_lightning,
		// 		1, ATTN_NORM, 0);
		// 	break;

		// case temp_event_t.TE_DEBUGTRAIL:
		// 	pos = msg.ReadPos();
		// 	pos2 = msg.ReadPos();
		// 	CL_DebugTrail(pos, pos2);
		// 	break;

		case temp_event_t.TE_PLAIN_EXPLOSION:
			pos = msg.ReadPos();

			final ex = CL_AllocExplosion();
      ex.ent.origin.setAll(0, pos);
			ex.type = exptype_t.ex_poly;
			ex.ent.flags = RF_FULLBRIGHT | RF_NOSHADOW;
			ex.start = cl.frame.servertime - 100.0;
			ex.light = 350;
			ex.lightcolor[0] = 1.0;
			ex.lightcolor[1] = 0.5;
			ex.lightcolor[2] = 0.5;
			ex.ent.angles[1] = (randk() % 360).toDouble();
			ex.ent.model = cl_mod_explo4;

			if (frandk() < 0.5) {
				ex.baseframe = 15;
			}

			ex.frames = 15;

		// 	if (type == TE_ROCKET_EXPLOSION_WATER)
		// 	{
		// 		S_StartSound(pos, 0, 0, cl_sfx_watrexp, 1, ATTN_NORM, 0);
		// 	}

		// 	else
		// 	{
		// 		S_StartSound(pos, 0, 0, cl_sfx_rockexp, 1, ATTN_NORM, 0);
		// 	}

			break;

		// case temp_event_t.TE_FLASHLIGHT:
		// 	pos = msg.ReadPos();
		// 	ent = msg.ReadShort();
		// 	CL_Flashlight(ent, pos);
		// 	break;

		// case temp_event_t.TE_FORCEWALL:
		// 	pos = msg.ReadPos();
		// 	pos2 = msg.ReadPos();
		// 	color = msg.ReadByte();
		// 	CL_ForceWall(pos, pos2, color);
		// 	break;

		// case temp_event_t.TE_HEATBEAM:
		// 	CL_ParsePlayerBeam(cl_mod_heatbeam);
		// 	break;

		// case temp_event_t.TE_MONSTER_HEATBEAM:
		// 	CL_ParsePlayerBeam(cl_mod_monster_heatbeam);
		// 	break;

		// case temp_event_t.TE_HEATBEAM_SPARKS:
		// 	cnt = 50;
		// 	msg.ReadPos(, pos);
		// 	msg.ReadDir(, dir);
		// 	r = 8;
		// 	magnitude = 60;
		// 	color = r & 0xff;
		// 	CL_ParticleSteamEffect(pos, dir, color, cnt, magnitude);
		// 	S_StartSound(pos, 0, 0, cl_sfx_lashit, 1, ATTN_NORM, 0);
		// 	break;

		// case temp_event_t.TE_HEATBEAM_STEAM:
		// 	cnt = 20;
		// 	msg.ReadPos(, pos);
		// 	msg.ReadDir(, dir);
		// 	color = 0xe0;
		// 	magnitude = 60;
		// 	CL_ParticleSteamEffect(pos, dir, color, cnt, magnitude);
		// 	S_StartSound(pos, 0, 0, cl_sfx_lashit, 1, ATTN_NORM, 0);
		// 	break;

		// case temp_event_t.TE_STEAM:
		// 	CL_ParseSteam();
		// 	break;

		// case temp_event_t.TE_BUBBLETRAIL2:
		// 	msg.ReadPos(, pos);
		// 	msg.ReadPos(, pos2);
		// 	CL_BubbleTrail2(pos, pos2, 8);
		// 	S_StartSound(pos, 0, 0, cl_sfx_lashit, 1, ATTN_NORM, 0);
		// 	break;

		case temp_event_t.TE_MOREBLOOD:
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			CL_ParticleEffect(pos, dir, 0xe8, 250);
			break;

		// case temp_event_t.TE_CHAINFIST_SMOKE:
		// 	dir[0] = 0;
		// 	dir[1] = 0;
		// 	dir[2] = 1;
		// 	msg.ReadPos(, pos);
		// 	CL_ParticleSmokeEffect(pos, dir, 0, 20, 20);
		// 	break;

		case temp_event_t.TE_ELECTRIC_SPARKS:
			pos = msg.ReadPos();
			dir = msg.ReadDir();
			CL_ParticleEffect(pos, dir, 0x75, 40);
			// S_StartSound(pos, 0, 0, cl_sfx_lashit, 1, ATTN_NORM, 0);
			break;

		// case temp_event_t.TE_TRACKER_EXPLOSION:
		// 	msg.ReadPos(, pos);
		// 	CL_ColorFlash(pos, 0, 150, -1, -1, -1);
		// 	CL_ColorExplosionParticles(pos, 0, 1);
		// 	S_StartSound(pos, 0, 0, cl_sfx_disrexp, 1, ATTN_NORM, 0);
		// 	break;

		// case temp_event_t.TE_TELEPORT_EFFECT:
		// case temp_event_t.TE_DBALL_GOAL:
		// 	msg.ReadPos(, pos);
		// 	CL_TeleportParticles(pos);
		// 	break;

		// case temp_event_t.TE_WIDOWBEAMOUT:
		// 	CL_ParseWidow();
		// 	break;

		// case temp_event_t.TE_NUKEBLAST:
		// 	CL_ParseNuke();
		// 	break;

		// case temp_event_t.TE_WIDOWSPLASH:
		// 	msg.ReadPos(, pos);
		// 	CL_WidowSplash(pos);
		// 	break;

		default:
			Com_Error(ERR_DROP, "CL_ParseTEnt: bad type");
	}
}

CL_AddExplosions() {

	for (var ex in cl_explosions) {
		if (ex.type == exptype_t.ex_free)
		{
			continue;
		}

		double frac = (cl.time - ex.start) / 100.0;
		int f = frac.floor();

		var ent = ex.ent;

		switch (ex.type) {
			case exptype_t.ex_mflash:

				if (f >= ex.frames - 1) {
					ex.type = exptype_t.ex_free;
				}

				break;
			case exptype_t.ex_misc:

				if (f >= ex.frames - 1) {
					ex.type = exptype_t.ex_free;
					break;
				}

				ent.alpha = 1.0 - frac / (ex.frames - 1);
				break;
			case exptype_t.ex_flash:

				if (f >= 1) {
					ex.type = exptype_t.ex_free;
					break;
				}

				ent.alpha = 1.0;
				break;
			case exptype_t.ex_poly:

				if (f >= ex.frames - 1) {
					ex.type = exptype_t.ex_free;
					break;
				}

				ent.alpha = (16.0 - f.toDouble()) / 16.0;

				if (f < 10) {
					ent.skinnum = (f >> 1);

					if (ent.skinnum < 0) {
						ent.skinnum = 0;
					}
				}
				else
				{
					ent.flags |= RF_TRANSLUCENT;

					if (f < 13) {
						ent.skinnum = 5;
					}

					else
					{
						ent.skinnum = 6;
					}
				}

				break;
			case exptype_t.ex_poly2:

				if (f >= ex.frames - 1) {
					ex.type = exptype_t.ex_free;
					break;
				}

				ent.alpha = (5.0 - f.toDouble()) / 5.0;
				ent.skinnum = 0;
				ent.flags |= RF_TRANSLUCENT;
				break;
			default:
				break;
		}

		if (ex.type == exptype_t.ex_free) {
			continue;
		}

		if (ex.light != 0) {
			V_AddLight(ent.origin, ex.light * ent.alpha,
					ex.lightcolor[0], ex.lightcolor[1], ex.lightcolor[2]);
		}

    ent.oldorigin.setAll(0, ent.origin);

		if (f < 0) {
			f = 0;
		}

		ent.frame = ex.baseframe + f + 1;
		ent.oldframe = ex.baseframe + f;
		ent.backlerp = 1.0 - cl.lerpfrac;

  // if (ent.model != null  && ent.model.name == "models/objects/flash/tris.md2") {
  //     print(" expolsion ${cl_framecounter} ${ent.frame} ${ent.oldframe} $f ${ex.baseframe} ${ex.type}");
  // }

		V_AddEntity(ent);
	}
}

CL_AddTEnts() {
	// CL_AddBeams();
	// CL_AddPlayerBeams();
	CL_AddExplosions();
	// CL_AddLasers();
	// CL_ProcessSustain();
}

