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
 *  =======================================================================
 *
 * This file implements the camera, e.g the player's view
 *
 * =======================================================================
 */
import 'dart:math';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/collision.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'client.dart';
import 'cl_screen.dart';
import 'cl_main.dart' show cl_paused;
import 'vid/ref.dart' as Ref;
import 'vid/vid.dart' show re, viddef;
import 'cl_entities.dart' show CL_AddEntities;
import 'cl_parse.dart' show CL_ParseClientinfo, CL_LoadClientinfo;
import 'cl_tempentities.dart' show CL_RegisterTEntModels;
import 'input.dart' show IN_Update;

/* development tools for weapons */
int gun_frame = 0;
Object gun_model;

List<Ref.entity_t> r_entities;
List<Ref.particle_t> r_particles;
List<Ref.dlight_t>	r_dlights;

List<String> cl_weaponmodels;
List<Ref.lightstyle_t> r_lightstyles = List(MAX_LIGHTSTYLES);

/*
 * Specifies the model that will be used as the world
 */
V_ClearScene() {
  r_entities = [];
  r_particles = [];
  r_dlights = [];
  for (int i = 0; i < r_lightstyles.length; i++) {
    r_lightstyles[i] = Ref.lightstyle_t();
  }
}

V_AddEntity(Ref.entity_t ent) {
	if (r_entities.length >= Ref.MAX_ENTITIES) {
		return;
	}
	r_entities.add(ent.clone());
}

V_AddParticle(List<double> org, int color, double alpha)
{
	final p = Ref.particle_t();
	if (r_particles.length >= Ref.MAX_PARTICLES) {
		return;
	}

  p.origin = List.generate(3, (i) => org[i]);
	p.color = color;
	p.alpha = alpha;
  r_particles.add(p);
}

V_AddLight(List<double> org, double intensity, double r, double g, double b) {

	// if (r_numdlights >= MAX_DLIGHTS) {
	// 	return;
	// }

	final dl = Ref.dlight_t();
  dl.origin.setAll(0, org);
	dl.intensity = intensity;
	dl.color[0] = r;
	dl.color[1] = g;
	dl.color[2] = b;
  r_dlights.add(dl);
}

V_AddLightStyle(int style, double r, double g, double b) {

	if ((style < 0) || (style > MAX_LIGHTSTYLES)) {
		Com_Error(ERR_DROP, "Bad light style $style");
	}

	final ls = r_lightstyles[style];
	ls.white = r + g + b;
	ls.rgb[0] = r;
	ls.rgb[1] = g;
	ls.rgb[2] = b;
}

/*
 * Call before entering a new level, or after changing dlls
 */
CL_PrepRefresh() async {

	if (cl.configstrings[CS_MODELS + 1].isEmpty) {
		return;
	}

	SCR_AddDirtyPoint(0, 0);
	SCR_AddDirtyPoint(viddef.width - 1, viddef.height - 1);

	/* let the refresher load the map */
	var mapname = cl.configstrings[CS_MODELS + 1].substring(5); /* skip "maps/" */
  mapname = mapname.substring(0, mapname.length - 4); /* cut off ".bsp" */

	/* register models, pics, and skins */
	Com_Printf("Map: $mapname\r");
	await SCR_UpdateScreen();
	await re.BeginRegistration (mapname);
	Com_Printf("                                     \r");

	/* precache status bar pics */
	Com_Printf("pics\r");
	await SCR_UpdateScreen();
	await SCR_TouchPics();
	Com_Printf("                                     \r");

	await CL_RegisterTEntModels();

  cl_weaponmodels = [ "weapon.md2" ];

	for (int i = 1; i < MAX_MODELS && cl.configstrings[CS_MODELS + i] != null && cl.configstrings[CS_MODELS + i].isNotEmpty; i++) {
    final name = cl.configstrings[CS_MODELS + i];

		if (name[0] != '*') {
			Com_Printf("$name\r");
		}

		await SCR_UpdateScreen();
		await IN_Update();

		if (name[0] == '#') {
			/* special player weapon model */
			if (cl_weaponmodels.length < MAX_CLIENTWEAPONMODELS) {
				cl_weaponmodels.add(name.substring(1));
				// num_cl_weaponmodels++;
			}
		} else {
			cl.model_draw[i] = await re.RegisterModel(cl.configstrings[CS_MODELS + i]);

			if (name[0] == '*') {
				cl.model_clip[i] = CM_InlineModel(cl.configstrings[CS_MODELS + i]);
			} else {
				cl.model_clip[i] = null;
			}
		}

		if (name[0] != '*') {
			Com_Printf("                                     \r");
		}
	}

	Com_Printf("images\r");
	await SCR_UpdateScreen();

	for (int i = 1; i < MAX_IMAGES && cl.configstrings[CS_IMAGES + i] != null && cl.configstrings[CS_IMAGES + i].isNotEmpty; i++) {
		cl.image_precache[i] = await re.DrawFindPic(cl.configstrings[CS_IMAGES + i]);
		await IN_Update();
	}

	Com_Printf("                                     \r");

	for (int i  = 0; i < MAX_CLIENTS; i++) {
		if (cl.configstrings[CS_PLAYERSKINS + i] == null || cl.configstrings[CS_PLAYERSKINS + i].isEmpty) {
			continue;
		}

		Com_Printf("client $i\r");
		await SCR_UpdateScreen();
		await IN_Update();
		await CL_ParseClientinfo(i);
		Com_Printf("                                     \r");
	}

	await CL_LoadClientinfo(cl.baseclientinfo, "unnamed\\male/grunt");

	/* set sky textures and speed */
	Com_Printf("sky\r");
	await SCR_UpdateScreen();
	final rotate = double.tryParse(cl.configstrings[CS_SKYROTATE]);
  final split = cl.configstrings[CS_SKYAXIS].split(" ");
  List<double> axis = List.generate(3, (i) => split.length > i ? double.tryParse(split[i]) : 0);
	await re.SetSky(cl.configstrings[CS_SKY], rotate, axis);
	Com_Printf("                                     \r");

	/* the renderer can now free unneeded stuff */
	re.EndRegistration();

	// /* clear any lines of console text */
	// Con_ClearNotify();

	await SCR_UpdateScreen();
	cl.refresh_prepped = true;
	cl.force_refdef = true; /* make sure we have a valid refdef */

	// /* start the cd track */
	// int track = (int)strtol(cl.configstrings[CS_CDTRACK], (char **)NULL, 10);

	// if (Cvar_VariableValue("ogg_shuffle"))
	// {
	// 	OGG_PlayTrack(track);
	// }
	// else
	// {
	// 	OGG_PlayTrack(track);
	// }
}

double CalcFov(double fov_x, double width, double height) {

	if ((fov_x < 1) || (fov_x > 179)) {
		Com_Error(ERR_DROP, "Bad fov: $fov_x");
	}

	final x = width / tan(fov_x / 360 * pi);

	final a = atan(height / x);

	return a * 360 / pi;
}


V_RenderView() async {
	if (cls.state != connstate_t.ca_active) {
		return;
	}

	if (!cl.refresh_prepped) {
		return;
	}

	// if (cl_timedemo->value)
	// {
	// 	if (!cl.timedemo_start)
	// 	{
	// 		cl.timedemo_start = Sys_Milliseconds();
	// 	}

	// 	cl.timedemo_frames++;
	// }

	/* an invalid frame will just use the exact previous refdef
	   we can't use the old frame if the video mode has changed, though... */
	if (cl.frame.valid && (cl.force_refdef || !cl_paused.boolean)) {
		cl.force_refdef = false;

		V_ClearScene();

		/* build a refresh entity list and calc cl.sim*
		   this also calls CL_CalcViewValues which loads
		   v_forward, etc. */
		CL_AddEntities();

		// before changing viewport we should trace the crosshair position
	// 	V_Render3dCrosshair();

	// 	if (cl_testparticles->value)
	// 	{
	// 		V_TestParticles();
	// 	}

	// 	if (cl_testentities->value)
	// 	{
	// 		V_TestEntities();
	// 	}

	// 	if (cl_testlights->value)
	// 	{
	// 		V_TestLights();
	// 	}

	// 	if (cl_testblend->value)
	// 	{
	// 		cl.refdef.blend[0] = 1;
	// 		cl.refdef.blend[1] = 0.5;
	// 		cl.refdef.blend[2] = 0.25;
	// 		cl.refdef.blend[3] = 0.5;
	// 	}

		/* offset vieworg appropriately if
		   we're doing stereo separation */

	// 	if (stereo_separation != 0)
	// 	{
	// 		vec3_t tmp;

	// 		VectorScale(cl.v_right, stereo_separation, tmp);
	// 		VectorAdd(cl.refdef.vieworg, tmp, cl.refdef.vieworg);
	// 	}

		/* never let it sit exactly on a node line, because a water plane can
		   dissapear when viewed with the eye exactly on it. the server protocol
		   only specifies to 1/8 pixel, so add 1/16 in each axis */
		cl.refdef.vieworg[0] += 1.0 / 16;
		cl.refdef.vieworg[1] += 1.0 / 16;
		cl.refdef.vieworg[2] += 1.0 / 16;

		cl.refdef.time = cl.time * 0.001;

		cl.refdef.areabits = cl.frame.areabits;

	// 	if (!cl_add_entities->value)
	// 	{
	// 		r_numentities = 0;
	// 	}

	// 	if (!cl_add_particles->value)
	// 	{
	// 		r_numparticles = 0;
	// 	}

	// 	if (!cl_add_lights->value)
	// 	{
	// 		r_numdlights = 0;
	// 	}

	// 	if (!cl_add_blend->value)
	// 	{
	// 		VectorClear(cl.refdef.blend);
	// 	}

		cl.refdef.entities = r_entities;
		cl.refdef.particles = r_particles;
		cl.refdef.dlights = r_dlights;
		cl.refdef.lightstyles = r_lightstyles;

		cl.refdef.rdflags = cl.frame.playerstate.rdflags;

	// 	/* sort entities for better cache locality */
	// 	qsort(cl.refdef.entities, cl.refdef.num_entities,
	// 			sizeof(cl.refdef.entities[0]), (int (*)(const void *, const void *))
	// 			entitycmpfnc);
	}

	cl.refdef.x = scr_vrect.x;
	cl.refdef.y = scr_vrect.y;
	cl.refdef.width = scr_vrect.width;
	cl.refdef.height = scr_vrect.height;
	cl.refdef.fov_y = CalcFov(cl.refdef.fov_x, cl.refdef.width.toDouble(),
				cl.refdef.height.toDouble());

	await re.RenderFrame(cl.refdef);

	// if (cl_stats->value)
	// {
	// 	Com_Printf("ent:%i  lt:%i  part:%i\n", r_numentities,
	// 			r_numdlights, r_numparticles);
	// }

	// if (log_stats->value && (log_stats_file != 0))
	// {
	// 	fprintf(log_stats_file, "%i,%i,%i,", r_numentities,
	// 			r_numdlights, r_numparticles);
	// }

	SCR_AddDirtyPoint(scr_vrect.x, scr_vrect.y);
	SCR_AddDirtyPoint(scr_vrect.x + scr_vrect.width - 1,
			scr_vrect.y + scr_vrect.height - 1);

	// SCR_DrawCrosshair();
}
