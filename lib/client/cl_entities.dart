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
 * This file implements all static entities at client site.
 *
 * =======================================================================
 */
import 'dart:math';
import 'package:dQuakeWeb/client/vid/ref.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'client.dart';
import 'cl_main.dart';
import 'cl_view.dart' show V_AddEntity, V_AddLight, gun_frame, gun_model;
import 'cl_lights.dart' show CL_AddLightStyles;
import 'cl_particles.dart' show CL_AddParticles;
import 'cl_tempentities.dart' show CL_AddTEnts, cl_mod_powerscreen;
import 'cl_lights.dart' show CL_AddDLights;
import 'cl_effects.dart' show CL_BlasterTrail, CL_BlasterTrail2;

CL_AddPacketEntities(frame_t frame) {
  final ent = entity_t();

	/* To distinguish baseq2, xatrix and rogue. */
	// cvar_t *game = Cvar_Get("game",  "", CVAR_LATCH | CVAR_SERVERINFO);

	/* bonus items rotate at a fixed rate */
	final autorotate = anglemod(cl.time * 0.1);

	/* brush models can auto animate their frames */
	final autoanim = 2 * cl.time ~/ 1000;

	for (int pnum = 0; pnum < frame.num_entities; pnum++) {
		final s1 = cl_parse_entities[(frame.parse_entities + pnum) & (MAX_PARSE_ENTITIES - 1)];

		final cent = cl_entities[s1.number];

		var effects = s1.effects;
		var renderfx = s1.renderfx;

		/* set frame */
		if ((effects & EF_ANIM01) != 0) {
			ent.frame = autoanim & 1;
		}

		else if ((effects & EF_ANIM23) != 0) {
			ent.frame = 2 + (autoanim & 1);
		}

		else if ((effects & EF_ANIM_ALL) != 0) {
			ent.frame = autoanim;
		}

		else if ((effects & EF_ANIM_ALLFAST) != 0) {
			ent.frame = cl.time ~/ 100;
		}

		else
		{
			ent.frame = s1.frame;
		}

		/* quad and pent can do different things on client */
		if ((effects & EF_PENT) != 0) {
			effects &= ~EF_PENT;
			effects |= EF_COLOR_SHELL;
			renderfx |= RF_SHELL_RED;
		}

		if ((effects & EF_QUAD) != 0) {
			effects &= ~EF_QUAD;
			effects |= EF_COLOR_SHELL;
			renderfx |= RF_SHELL_BLUE;
		}

		if ((effects & EF_DOUBLE) != 0) {
			effects &= ~EF_DOUBLE;
			effects |= EF_COLOR_SHELL;
			renderfx |= RF_SHELL_DOUBLE;
		}

		if ((effects & EF_HALF_DAMAGE) != 0) {
			effects &= ~EF_HALF_DAMAGE;
			effects |= EF_COLOR_SHELL;
			renderfx |= RF_SHELL_HALF_DAM;
		}

		ent.oldframe = cent.prev.frame;
		ent.backlerp = 1.0 - cl.lerpfrac;

		if ((renderfx & (RF_FRAMELERP | RF_BEAM)) != 0) {
			/* step origin discretely, because the
			   frames do the animation properly */
         ent.origin.setAll(0, cent.current.origin);
         ent.oldorigin.setAll(0, cent.current.old_origin);
		} else{
			/* interpolate origin */
			for (int i = 0; i < 3; i++) {
				ent.origin[i] = cent.prev.origin[i] + cl.lerpfrac *
				   	(cent.current.origin[i] - cent.prev.origin[i]);
        ent.oldorigin[i] = ent.origin[i];
			}
		}

		/* tweak the color of beams */
		if ((renderfx & RF_BEAM) != 0) {
			/* the four beam colors are encoded in 32 bits of skinnum (hack) */
			ent.alpha = 0.30;
			ent.skinnum = (s1.skinnum >> ((randk() % 4) * 8)) & 0xff;
			ent.model = null;
		} else {
			/* set skin */
			if (s1.modelindex == 255) {
				/* use custom player skin */
				ent.skinnum = 0;
				final ci = cl.clientinfo[s1.skinnum & 0xff];
				ent.skin = ci.skin;
				ent.model = ci.model;

				if (ent.skin == null || ent.model == null)
				{
					ent.skin = cl.baseclientinfo.skin;
					ent.model = cl.baseclientinfo.model;
				}

	// 			if (renderfx & RF_USE_DISGUISE)
	// 			{
	// 				if (ent.skin != NULL)
	// 				{
	// 					if (!strncmp((char *)ent.skin, "players/male", 12))
	// 					{
	// 						ent.skin = R_RegisterSkin("players/male/disguise.pcx");
	// 						ent.model = R_RegisterModel("players/male/tris.md2");
	// 					}
	// 					else if (!strncmp((char *)ent.skin, "players/female", 14))
	// 					{
	// 						ent.skin = R_RegisterSkin("players/female/disguise.pcx");
	// 						ent.model = R_RegisterModel("players/female/tris.md2");
	// 					}
	// 					else if (!strncmp((char *)ent.skin, "players/cyborg", 14))
	// 					{
	// 						ent.skin = R_RegisterSkin("players/cyborg/disguise.pcx");
	// 						ent.model = R_RegisterModel("players/cyborg/tris.md2");
	// 					}
	// 				}
	// 			}
			} else {
				ent.skinnum = s1.skinnum;
				ent.skin = null;
				ent.model = cl.model_draw[s1.modelindex];
			}
		}

		/* only used for black hole model right now */
		if ((renderfx & RF_TRANSLUCENT) != 0 && (renderfx & RF_BEAM) == 0) {
			ent.alpha = 0.70;
		}

		/* render effects (fullbright, translucent, etc) */
		if ((effects & EF_COLOR_SHELL) != 0) {
			ent.flags = 0; /* renderfx go on color shell entity */
		} else {
			ent.flags = renderfx;
		}

		/* calculate angles */
		if ((effects & EF_ROTATE) != 0) {
			/* some bonus items auto-rotate */
			ent.angles[0] = 0;
			ent.angles[1] = autorotate;
			ent.angles[2] = 0;
		} else if ((effects & EF_SPINNINGLIGHTS) != 0) {
			ent.angles[0] = 0;
			ent.angles[1] = anglemod(cl.time / 2) + s1.angles[1];
			ent.angles[2] = 180;
      List<double> forward = [0,0,0];
      AngleVectors(ent.angles, forward, null, null);
      List<double> start = [0,0,0];
      VectorMA(ent.origin, 64, forward, start);
      V_AddLight(start, 100, 1, 0, 0);
		} else {
			/* interpolate angles */
			for (int i = 0; i < 3; i++) {
				final a1 = cent.current.angles[i];
				final a2 = cent.prev.angles[i];
				ent.angles[i] = LerpAngle(a2, a1, cl.lerpfrac);
			}
		}

		if (s1.number == cl.playernum + 1) {
			ent.flags |= RF_VIEWERMODEL;

			if ((effects & EF_FLAG1) != 0) {
				V_AddLight(ent.origin, 225, 1.0, 0.1, 0.1);
			}

			else if ((effects & EF_FLAG2) != 0) {
				V_AddLight(ent.origin, 225, 0.1, 0.1, 1.0);
			}

			else if ((effects & EF_TAGTRAIL) != 0) {
				V_AddLight(ent.origin, 225, 1.0, 1.0, 0.0);
			}

			else if ((effects & EF_TRACKERTRAIL) != 0) {
				V_AddLight(ent.origin, 225, -1.0, -1.0, -1.0);
			}

			continue;
		}

		/* if set to invisible, skip */
		if (s1.modelindex == 0) {
			continue;
		}

		if ((effects & EF_BFG) != 0) {
			ent.flags |= RF_TRANSLUCENT;
			ent.alpha = 0.30;
		}

		if ((effects & EF_PLASMA) != 0) {
			ent.flags |= RF_TRANSLUCENT;
			ent.alpha = 0.6;
		}

		if ((effects & EF_SPHERETRANS) != 0) {
			ent.flags |= RF_TRANSLUCENT;

			if ((effects & EF_TRACKERTRAIL) != 0) {
				ent.alpha = 0.6;
			} else {
				ent.alpha = 0.3;
			}
		}

		/* add to refresh list */
		V_AddEntity(ent);

		/* color shells generate a seperate entity for the main model */
		if ((effects & EF_COLOR_SHELL) != 0) {
			/* all of the solo colors are fine.  we need to catch any of
			   the combinations that look bad (double & half) and turn
			   them into the appropriate color, and make double/quad
			   something special */
			if ((renderfx & RF_SHELL_HALF_DAM) != 0) {
	// 			if (strcmp(game->string, "rogue") == 0)
	// 			{
	// 				/* ditch the half damage shell if any of red, blue, or double are on */
	// 				if (renderfx & (RF_SHELL_RED | RF_SHELL_BLUE | RF_SHELL_DOUBLE))
	// 				{
	// 					renderfx &= ~RF_SHELL_HALF_DAM;
	// 				}
	// 			}
			}

			if ((renderfx & RF_SHELL_DOUBLE) != 0) {
	// 			if (strcmp(game->string, "rogue") == 0)
	// 			{
	// 				/* lose the yellow shell if we have a red, blue, or green shell */
	// 				if (renderfx & (RF_SHELL_RED | RF_SHELL_BLUE | RF_SHELL_GREEN))
	// 				{
	// 					renderfx &= ~RF_SHELL_DOUBLE;
	// 				}

	// 				/* if we have a red shell, turn it to purple by adding blue */
	// 				if (renderfx & RF_SHELL_RED)
	// 				{
	// 					renderfx |= RF_SHELL_BLUE;
	// 				}

	// 				/* if we have a blue shell (and not a red shell),
	// 				   turn it to cyan by adding green */
	// 				else if (renderfx & RF_SHELL_BLUE)
	// 				{
	// 					/* go to green if it's on already,
	// 					   otherwise do cyan (flash green) */
	// 					if (renderfx & RF_SHELL_GREEN)
	// 					{
	// 						renderfx &= ~RF_SHELL_BLUE;
	// 					}

	// 					else
	// 					{
	// 						renderfx |= RF_SHELL_GREEN;
	// 					}
	// 				}
	// 			}
			}

			ent.flags = renderfx | RF_TRANSLUCENT;
			ent.alpha = 0.30;

			V_AddEntity(ent);
		}

		ent.skin = null; /* never use a custom skin on others */
		ent.skinnum = 0;
		ent.flags = 0;
		ent.alpha = 0;

		/* duplicate for linked models */
		if (s1.modelindex2 != 0) {
			if (s1.modelindex2 == 255) {
				/* custom weapon */
				final ci = cl.clientinfo[s1.skinnum & 0xff];
				var i = (s1.skinnum >> 8); /* 0 is default weapon model */

				if (!cl_vwep.boolean || (i >= ci.weaponmodel.length)) {
					i = 0;
				}

				ent.model = ci.weaponmodel[i];

				if (ent.model == null) {
					if (i != 0) {
						ent.model = ci.weaponmodel[0];
					}

					if (ent.model == null) {
						ent.model = cl.baseclientinfo.weaponmodel[0];
					}
				}
			}
			else
			{
				ent.model = cl.model_draw[s1.modelindex2];
			}

	// 		/* check for the defender sphere shell and make it translucent */
	// 		if (!Q_strcasecmp(cl.configstrings[CS_MODELS + (s1->modelindex2)],
	// 					"models/items/shell/tris.md2"))
	// 		{
	// 			ent.alpha = 0.32f;
	// 			ent.flags = RF_TRANSLUCENT;
	// 		}

			V_AddEntity(ent);

			ent.flags = 0;
			ent.alpha = 0;
		}

		if (s1.modelindex3 != 0)
		{
			ent.model = cl.model_draw[s1.modelindex3];
			V_AddEntity(ent);
		}

		if (s1.modelindex4 != 0)
		{
			ent.model = cl.model_draw[s1.modelindex4];
			V_AddEntity(ent);
		}

		if ((effects & EF_POWERSCREEN) != 0) {
			ent.model = cl_mod_powerscreen;
			ent.oldframe = 0;
			ent.frame = 0;
			ent.flags |= (RF_TRANSLUCENT | RF_SHELL_GREEN);
			ent.alpha = 0.30;
			V_AddEntity(ent);
		}

		/* add automatic particle trails */
		if ((effects & ~EF_ROTATE) != 0) {
	// 		if (effects & EF_ROCKET)
	// 		{
	// 			CL_RocketTrail(cent->lerp_origin, ent.origin, cent);
	// 			V_AddLight(ent.origin, 200, 1, 0.25f, 0);
	// 		}

			/* Do not reorder EF_BLASTER and EF_HYPERBLASTER.
			   EF_BLASTER | EF_TRACKER is a special case for
			   EF_BLASTER2 */
	// 		else 
  if ((effects & EF_BLASTER) != 0) {
				if ((effects & EF_TRACKER) != 0) {
					CL_BlasterTrail2(cent.lerp_origin, ent.origin);
					V_AddLight(ent.origin, 200, 0, 1, 0);
				} else {
					CL_BlasterTrail(cent.lerp_origin, ent.origin);
					V_AddLight(ent.origin, 200, 1, 1, 0);
				}
			} else if ((effects & EF_HYPERBLASTER) != 0) {

				if ((effects & EF_TRACKER) != 0) {
					V_AddLight(ent.origin, 200, 0, 1, 0);
				} else {
					V_AddLight(ent.origin, 200, 1, 1, 0);
				}
			}
	// 		else if ((effects & EF_GIB) != 0)
	// 		{
	// 			CL_DiminishingTrail(cent->lerp_origin, ent.origin,
	// 					cent, effects);
	// 		}
	// 		else if ((effects & EF_GRENADE) != 0)
	// 		{
	// 			CL_DiminishingTrail(cent->lerp_origin, ent.origin,
	// 					cent, effects);
	// 		}
	// 		else if ((effects & EF_FLIES) != 0)
	// 		{
	// 			CL_FlyEffect(cent, ent.origin);
	// 		}
	// 		else if ((effects & EF_BFG) != 0)
	// 		{
	// 			static int bfg_lightramp[6] = {300, 400, 600, 300, 150, 75};

	// 			if (effects & EF_ANIM_ALLFAST)
	// 			{
	// 				CL_BfgParticles(&ent);
	// 				i = 200;
	// 			}
	// 			else
	// 			{
	// 				i = bfg_lightramp[s1->frame];
	// 			}

	// 			V_AddLight(ent.origin, i, 0, 1, 0);
	// 		}
	// 		else if (effects & EF_TRAP)
	// 		{
	// 			ent.origin[2] += 32;
	// 			CL_TrapParticles(&ent);
	// 			i = (randk() % 100) + 100;
	// 			V_AddLight(ent.origin, i, 1, 0.8f, 0.1f);
	// 		}
	// 		else if (effects & EF_FLAG1)
	// 		{
	// 			CL_FlagTrail(cent->lerp_origin, ent.origin, 242);
	// 			V_AddLight(ent.origin, 225, 1, 0.1f, 0.1f);
	// 		}
	// 		else if (effects & EF_FLAG2)
	// 		{
	// 			CL_FlagTrail(cent->lerp_origin, ent.origin, 115);
	// 			V_AddLight(ent.origin, 225, 0.1f, 0.1f, 1);
	// 		}
	// 		else if (effects & EF_TAGTRAIL)
	// 		{
	// 			CL_TagTrail(cent->lerp_origin, ent.origin, 220);
	// 			V_AddLight(ent.origin, 225, 1.0, 1.0, 0.0);
	// 		}
	// 		else if (effects & EF_TRACKERTRAIL)
	// 		{
	// 			if (effects & EF_TRACKER)
	// 			{
	// 				float intensity;

	// 				intensity = 50 + (500 * ((float)sin(cl.time / 500.0f) + 1.0f));
	// 				V_AddLight(ent.origin, intensity, -1.0, -1.0, -1.0);
	// 			}
	// 			else
	// 			{
	// 				CL_Tracker_Shell(cent->lerp_origin);
	// 				V_AddLight(ent.origin, 155, -1.0, -1.0, -1.0);
	// 			}
	// 		}
	// 		else if (effects & EF_TRACKER)
	// 		{
	// 			CL_TrackerTrail(cent->lerp_origin, ent.origin, 0);
	// 			V_AddLight(ent.origin, 200, -1, -1, -1);
	// 		}
	// 		else if (effects & EF_IONRIPPER)
	// 		{
	// 			CL_IonripperTrail(cent->lerp_origin, ent.origin);
	// 			V_AddLight(ent.origin, 100, 1, 0.5, 0.5);
	// 		}
	// 		else if (effects & EF_BLUEHYPERBLASTER)
	// 		{
	// 			V_AddLight(ent.origin, 200, 0, 0, 1);
	// 		}
	// 		else if (effects & EF_PLASMA)
	// 		{
	// 			if (effects & EF_ANIM_ALLFAST)
	// 			{
	// 				CL_BlasterTrail(cent->lerp_origin, ent.origin);
	// 			}

	// 			V_AddLight(ent.origin, 130, 1, 0.5, 0.5);
	// 		}
		}

    cent.lerp_origin.setAll(0, ent.origin);
	}
}

CL_AddViewWeapon(player_state_t ps, player_state_t ops) {
	entity_t gun = entity_t(); /* view model */
	int i;

	/* allow the gun to be completely removed */
	if (!cl_gun.boolean) {
		return;
	}

	/* don't draw gun if in wide angle view and drawing not forced */
	if (ps.fov > 90) {
		if (cl_gun.integer < 2) {
			return;
		}
	}

	if (gun_model != null) {
		gun.model = gun_model;
	} else {
		gun.model = cl.model_draw[ps.gunindex];
	}

	if (gun.model == null) {
		return;
	}

	/* set up gun position */
	for (int i = 0; i < 3; i++)
	{
		gun.origin[i] = cl.refdef.vieworg[i] + ops.gunoffset[i] +
      cl.lerpfrac * (ps.gunoffset[i] - ops.gunoffset[i]);
		gun.angles[i] = cl.refdef.viewangles[i] + LerpAngle(ops.gunangles[i],
			ps.gunangles[i], cl.lerpfrac);
	}

	if (gun_frame != null) {
		gun.frame = gun_frame;
		gun.oldframe = gun_frame;
	} else {
		gun.frame = ps.gunframe;

		if (gun.frame == 0) {
			gun.oldframe = 0; /* just changed weapons, don't lerp from old */
		} else {
			gun.oldframe = ops.gunframe;
		}
	}

	gun.flags = RF_MINLIGHT | RF_DEPTHHACK | RF_WEAPONMODEL;
	gun.backlerp = 1.0 - cl.lerpfrac;
  gun.oldorigin.setAll(0, gun.origin); /* don't lerp at all */
	V_AddEntity(gun);
}

/*
 * Adapts a 4:3 aspect FOV to the current aspect (Hor+)
 */
double AdaptFov(double fov, double w, double h) {
	if (w <= 0 || h <= 0) {
		return fov;
  }

	/*
	 * Formula:
	 *
	 * fov = 2.0 * atan(width / height * 3.0 / 4.0 * tan(fov43 / 2.0))
	 *
	 * The code below is equivalent but precalculates a few values and
	 * converts between degrees and radians when needed.
	 */
	return (atan(tan(fov / 360.0 * pi) * (w / h * 0.75)) / pi * 360.0);
}
/*
 * Sets cl.refdef view values
 */
CL_CalcViewValues() {

	/* find the previous frame to interpolate from */
	final ps = cl.frame.playerstate;
	var i = (cl.frame.serverframe - 1) & UPDATE_MASK;
	var oldframe = cl.frames[i];

	if (oldframe == null || (oldframe.serverframe != cl.frame.serverframe - 1) || !oldframe.valid) {
		oldframe = cl.frame; /* previous frame was dropped or invalid */
	}

	var ops = oldframe.playerstate;

	/* see if the player entity was teleported this frame */
	if (((ops.pmove.origin[0] - ps.pmove.origin[0]).abs() > 256 * 8) ||
		((ops.pmove.origin[1] - ps.pmove.origin[1]).abs() > 256 * 8) ||
		((ops.pmove.origin[2] - ps.pmove.origin[2]).abs() > 256 * 8)) {
		ops = ps; /* don't interpolate */
	}

  double lerp = 1;
  if (!cl_paused.boolean) {
		lerp = cl.lerpfrac;
	}

	/* calculate the origin */
	if ((cl_predict.boolean) && (cl.frame.playerstate.pmove.pm_flags & PMF_NO_PREDICTION) == 0) {
		/* use predicted values */

		final backlerp = 1.0 - lerp;

		for (int i = 0; i < 3; i++) {
			cl.refdef.vieworg[i] = cl.predicted_origin[i] + ops.viewoffset[i]
				+ cl.lerpfrac * (ps.viewoffset[i] - ops.viewoffset[i])
				- backlerp * cl.prediction_error[i];
		}

		/* smooth out stair climbing */
		final delta = cls.realtime - cl.predicted_step_time;

		if (delta < 100) {
			cl.refdef.vieworg[2] -= cl.predicted_step * (100 - delta) * 0.01;
		}
	} else {
		/* just use interpolated values */
		for (int i = 0; i < 3; i++)
		{
			cl.refdef.vieworg[i] = ops.pmove.origin[i] * 0.125 +
				ops.viewoffset[i] + lerp * (ps.pmove.origin[i] * 0.125 +
						ps.viewoffset[i] - (ops.pmove.origin[i] * 0.125 +
							ops.viewoffset[i]));
		}
	}

	/* if not running a demo or on a locked frame, add the local angle movement */
	if (cl.frame.playerstate.pmove.pm_type.index < pmtype_t.PM_DEAD.index) {
		/* use predicted values */
		for (int i = 0; i < 3; i++) {
			cl.refdef.viewangles[i] = cl.predicted_angles[i];
		}
	} else {
		/* just use interpolated values */
		for (int i = 0; i < 3; i++) {
			cl.refdef.viewangles[i] = LerpAngle(ops.viewangles[i],
					ps.viewangles[i], lerp);
		}
	}

	for (int i = 0; i < 3; i++) {
		cl.refdef.viewangles[i] += LerpAngle(ops.kick_angles[i],
				ps.kick_angles[i], lerp);
	}

	AngleVectors(cl.refdef.viewangles, cl.v_forward, cl.v_right, cl.v_up);

	/* interpolate field of view */
	final ifov = ops.fov + lerp * (ps.fov - ops.fov);
	if (horplus.boolean) {
		cl.refdef.fov_x = AdaptFov(ifov, cl.refdef.width.toDouble(), cl.refdef.height.toDouble());
	} else {
		cl.refdef.fov_x = ifov;
	}

	/* don't interpolate blend color */
	for (int i = 0; i < 4; i++) {
		cl.refdef.blend[i] = ps.blend[i];
	}

	/* add the weapon */
	CL_AddViewWeapon(ps, ops);
}

/*
 * Emits all entities, particles, and lights to the refresh
 */
CL_AddEntities()
{
	if (cls.state != connstate_t.ca_active) {
		return;
	}

	if (cl.time > cl.frame.servertime)
	{
		if (cl_showclamp.boolean){
			Com_Printf("high clamp ${cl.time - cl.frame.servertime}\n");
		}

		cl.time = cl.frame.servertime;
		cl.lerpfrac = 1.0;
	}
	else if (cl.time < cl.frame.servertime - 100)
	{
		if (cl_showclamp.boolean) {
			Com_Printf("low clamp ${cl.frame.servertime - 100 - cl.time}\n");
		}

		cl.time = cl.frame.servertime - 100;
		cl.lerpfrac = 0;
	}
	else
	{
		cl.lerpfrac = 1.0 - (cl.frame.servertime - cl.time) * 0.01;
	}

	// if (cl_timedemo.boolean)
	// {
	// 	cl.lerpfrac = 1.0;
	// }

	CL_CalcViewValues();
	CL_AddPacketEntities(cl.frame);
	CL_AddTEnts();
	CL_AddParticles();
	CL_AddDLights();
	CL_AddLightStyles();
}