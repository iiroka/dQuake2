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
 * Player movement code. This is the core of Quake IIs legendary physics
 * engine
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/client/client.dart';

const STEPSIZE = 18;

/* all of the locals will be zeroed before each
 * pmove, just to make damn sure we don't have
 * any differences when running on client or server */

class pml_t {
	List<double> origin = [0,0,0]; /* full float precision */
	List<double> velocity = [0,0,0]; /* full float precision */

	List<double> forward = [0,0,0], right = [0,0,0], up = [0,0,0];
	double frametime = 0;

	// csurface_t groundsurface;
	cplane_t groundplane = cplane_t();
	int groundcontents = 0;

	List<double> previous_origin = [0,0,0];
	bool ladder = false;
}

pmove_t pm;
pml_t pml = pml_t();

/*
 * Can be called by either the server or the client
 */
Pmove(pmove_t pmove) {
	pm = pmove;

	/* clear results */
	pm.numtouch = 0;
	pm.viewangles = [0,0,0];
	pm.viewheight = 0;
	pm.groundentity = null;
	pm.watertype = 0;
	pm.waterlevel = 0;

	/* clear all pmove local vars */
	pml = pml_t();

	/* convert origin and velocity to float values */
	pml.origin[0] = pm.s.origin[0] * 0.125;
	pml.origin[1] = pm.s.origin[1] * 0.125;
	pml.origin[2] = pm.s.origin[2] * 0.125;

	pml.velocity[0] = pm.s.velocity[0] * 0.125;
	pml.velocity[1] = pm.s.velocity[1] * 0.125;
	pml.velocity[2] = pm.s.velocity[2] * 0.125;

	/* save old org in case we get stuck */
  for (int i = 0; i < 3; i++) {
    pml.previous_origin[i] = pm.s.origin[i].toDouble();
  }

	pml.frametime = pm.cmd.msec * 0.001;

// 	PM_ClampAngles();

// 	if (pm->s.pm_type == PM_SPECTATOR)
// 	{
// 		PM_FlyMove(false);
// 		PM_SnapPosition();
// 		return;
// 	}

	if (pm.s.pm_type.index >= pmtype_t.PM_DEAD.index) {
		pm.cmd.forwardmove = 0;
		pm.cmd.sidemove = 0;
		pm.cmd.upmove = 0;
	}

	if (pm.s.pm_type == pmtype_t.PM_FREEZE) {
		if (cl.attractloop) {
// 			PM_CalculateViewHeightForDemo();
// 			PM_CalculateWaterLevelForDemo();
// 			PM_UpdateUnderwaterSfx();
		}

		return; /* no movement at all */
	}

	/* set mins, maxs, and viewheight */
// 	PM_CheckDuck();

// 	if (pm->snapinitial)
// 	{
// 		PM_InitialSnapPosition();
// 	}

// 	/* set groundentity, watertype, and waterlevel */
// 	PM_CatagorizePosition();

// 	if (pm->s.pm_type == PM_DEAD)
// 	{
// 		PM_DeadMove();
// 	}

// 	PM_CheckSpecialMovement();

// 	/* drop timing counter */
// 	if (pm->s.pm_time)
// 	{
// 		int msec;

// 		msec = pm->cmd.msec >> 3;

// 		if (!msec)
// 		{
// 			msec = 1;
// 		}

// 		if (msec >= pm->s.pm_time)
// 		{
// 			pm->s.pm_flags &= ~(PMF_TIME_WATERJUMP | PMF_TIME_LAND | PMF_TIME_TELEPORT);
// 			pm->s.pm_time = 0;
// 		}
// 		else
// 		{
// 			pm->s.pm_time -= msec;
// 		}
// 	}

// 	if (pm->s.pm_flags & PMF_TIME_TELEPORT)
// 	{
// 		/* teleport pause stays exactly in place */
// 	}
// 	else if (pm->s.pm_flags & PMF_TIME_WATERJUMP)
// 	{
// 		/* waterjump has no control, but falls */
// 		pml.velocity[2] -= pm->s.gravity * pml.frametime;

// 		if (pml.velocity[2] < 0)
// 		{
// 			/* cancel as soon as we are falling down again */
// 			pm->s.pm_flags &= ~(PMF_TIME_WATERJUMP | PMF_TIME_LAND | PMF_TIME_TELEPORT);
// 			pm->s.pm_time = 0;
// 		}

// 		PM_StepSlideMove();
// 	}
// 	else
// 	{
// 		PM_CheckJump();

// 		PM_Friction();

// 		if (pm->waterlevel >= 2)
// 		{
// 			PM_WaterMove();
// 		}
// 		else
// 		{
// 			vec3_t angles;

// 			VectorCopy(pm->viewangles, angles);

// 			if (angles[PITCH] > 180)
// 			{
// 				angles[PITCH] = angles[PITCH] - 360;
// 			}

// 			angles[PITCH] /= 3;

// 			AngleVectors(angles, pml.forward, pml.right, pml.up);

// 			PM_AirMove();
// 		}
// 	}

// 	/* set groundentity, watertype, and waterlevel for final spot */
// 	PM_CatagorizePosition();

// #if !defined(DEDICATED_ONLY)
//     PM_UpdateUnderwaterSfx();
// #endif

// 	PM_SnapPosition();
}

