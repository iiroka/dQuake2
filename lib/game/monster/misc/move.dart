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
 * Monster movement support functions.
 *
 * =======================================================================
 */
import 'dart:math';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import '../../game.dart';
import '../../g_utils.dart';

const _STEPSIZE = 18;
const _DI_NODIR = -1;

/*
 * Called by monster program code.
 * The move will be adjusted for slopes
 * and stairs, but if the move isn't
 * possible, no move is done, false is
 * returned, and pr_global_struct->trace_normal
 * is set to the normal of the blocking wall
 */
bool SV_movestep(edict_t ent, List<double> move, bool relink) {
	// float dz;
	// vec3_t oldorg, neworg, end;
	// trace_t trace;
	// int i;
	// float stepsize;
	// vec3_t test;
	// int contents;

	if (ent == null) {
		return false;
	}

	/* try the move */
  List<double> oldorg = List.generate(3, (i) => ent.s.origin[i]);
  List<double> neworg = [0,0,0];
	VectorAdd(ent.s.origin, move, neworg);

	/* flying monsters don't step up */
	if ((ent.flags & (FL_SWIM | FL_FLY)) != 0) {
    print("flying monster");
		/* try one move with vertical motion, then one without */
	// 	for (i = 0; i < 2; i++)
	// 	{
	// 		VectorAdd(ent->s.origin, move, neworg);

	// 		if ((i == 0) && ent->enemy)
	// 		{
	// 			if (!ent->goalentity)
	// 			{
	// 				ent->goalentity = ent->enemy;
	// 			}

	// 			dz = ent->s.origin[2] - ent->goalentity->s.origin[2];

	// 			if (ent->goalentity->client)
	// 			{
	// 				if (dz > 40)
	// 				{
	// 					neworg[2] -= 8;
	// 				}

	// 				if (!((ent->flags & FL_SWIM) && (ent->waterlevel < 2)))
	// 				{
	// 					if (dz < 30)
	// 					{
	// 						neworg[2] += 8;
	// 					}
	// 				}
	// 			}
	// 			else
	// 			{
	// 				if (dz > 8)
	// 				{
	// 					neworg[2] -= 8;
	// 				}
	// 				else if (dz > 0)
	// 				{
	// 					neworg[2] -= dz;
	// 				}
	// 				else if (dz < -8)
	// 				{
	// 					neworg[2] += 8;
	// 				}
	// 				else
	// 				{
	// 					neworg[2] += dz;
	// 				}
	// 			}
	// 		}

	// 		trace = gi.trace(ent->s.origin, ent->mins, ent->maxs,
	// 				neworg, ent, MASK_MONSTERSOLID);

	// 		/* fly monsters don't enter water voluntarily */
	// 		if (ent->flags & FL_FLY)
	// 		{
	// 			if (!ent->waterlevel)
	// 			{
	// 				test[0] = trace.endpos[0];
	// 				test[1] = trace.endpos[1];
	// 				test[2] = trace.endpos[2] + ent->mins[2] + 1;
	// 				contents = gi.pointcontents(test);

	// 				if (contents & MASK_WATER)
	// 				{
	// 					return false;
	// 				}
	// 			}
	// 		}

	// 		/* swim monsters don't exit water voluntarily */
	// 		if (ent->flags & FL_SWIM)
	// 		{
	// 			if (ent->waterlevel < 2)
	// 			{
	// 				test[0] = trace.endpos[0];
	// 				test[1] = trace.endpos[1];
	// 				test[2] = trace.endpos[2] + ent->mins[2] + 1;
	// 				contents = gi.pointcontents(test);

	// 				if (!(contents & MASK_WATER))
	// 				{
	// 					return false;
	// 				}
	// 			}
	// 		}

	// 		if (trace.fraction == 1)
	// 		{
	// 			VectorCopy(trace.endpos, ent->s.origin);

	// 			if (relink)
	// 			{
	// 				gi.linkentity(ent);
	// 				G_TouchTriggers(ent);
	// 			}

	// 			return true;
	// 		}

	// 		if (!ent->enemy)
	// 		{
	// 			break;
	// 		}
	// 	}

		return false;
	}

	/* push down from a step height above the wished position */
  double stepsize = 1;
	if ((ent.monsterinfo.aiflags & AI_NOSTEP) == 0) {
		stepsize = _STEPSIZE.toDouble();
	}

	neworg[2] += stepsize;
  List<double> end = List.generate(3, (i) => neworg[i]);
	end[2] -= stepsize * 2;

	var trace = SV_Trace(neworg, ent.mins, ent.maxs, end, ent, MASK_MONSTERSOLID);
	if (trace.allsolid) {
		return false;
	}

	if (trace.startsolid) {
		neworg[2] -= stepsize;
		trace = SV_Trace(neworg, ent.mins, ent.maxs, end, ent, MASK_MONSTERSOLID);

		if (trace.allsolid || trace.startsolid)
		{
			return false;
		}
	}

	/* don't go in to water */
	if (ent.waterlevel == 0) {
    List<double> test = [trace.endpos[0], trace.endpos[1], trace.endpos[2] + ent.mins[2] + 1];
		final contents = SV_PointContents(test);
		if ((contents & MASK_WATER) != 0) {
			return false;
		}
	}

	if (trace.fraction == 1) {
		/* if monster had the ground pulled out, go ahead and fall */
		if ((ent.flags & FL_PARTIALGROUND) != 0) {
			VectorAdd(ent.s.origin, move, ent.s.origin);

			if (relink)  {
				SV_LinkEdict(ent);
				G_TouchTriggers(ent);
			}

			ent.groundentity = null;
			return true;
		}

		return false; /* walked off an edge */
	}

	/* check point traces down for dangling corners */
  ent.s.origin.setAll(0, trace.endpos);

	// if (!M_CheckBottom(ent))
	// {
	// 	if (ent->flags & FL_PARTIALGROUND)
	// 	{   /* entity had floor mostly pulled out
	// 		   from underneath it and is trying to
	// 		   correct */
	// 		if (relink)
	// 		{
	// 			gi.linkentity(ent);
	// 			G_TouchTriggers(ent);
	// 		}

	// 		return true;
	// 	}

	// 	VectorCopy(oldorg, ent->s.origin);
	// 	return false;
	// }

	if ((ent.flags & FL_PARTIALGROUND) != 0) {
		ent.flags &= ~FL_PARTIALGROUND;
	}

	ent.groundentity = trace.ent;
	ent.groundentity_linkcount = trace.ent.linkcount;

	/* the move is ok */
	if (relink) {
		SV_LinkEdict(ent);
		G_TouchTriggers(ent);
	}

	return true;
}

/* ============================================================================ */

M_ChangeYaw(edict_t ent) {

	if (ent == null) {
		return;
	}

	double current = anglemod(ent.s.angles[YAW]);
	double ideal = ent.ideal_yaw;

	if (current == ideal) {
		return;
	}

	double move = ideal - current;
	double speed = ent.yaw_speed;

	if (ideal > current)
	{
		if (move >= 180)
		{
			move = move - 360;
		}
	}
	else
	{
		if (move <= -180)
		{
			move = move + 360;
		}
	}

	if (move > 0)
	{
		if (move > speed)
		{
			move = speed;
		}
	}
	else
	{
		if (move < -speed)
		{
			move = -speed;
		}
	}

	ent.s.angles[YAW] = anglemod(current + move);
}

/*
 * Turns to the movement direction, and
 * walks the current distance if facing it.
 */
bool SV_StepDirection(edict_t ent, double yaw, double dist) {

	if (ent == null) {
		return false;
	}

	ent.ideal_yaw = yaw;
	M_ChangeYaw(ent);

	yaw = yaw * pi * 2 / 360;
	List<double> move = [cos(yaw) * dist, sin(yaw) * dist, 0];

  List<double> oldorigin = List.generate(3, (i) => ent.s.origin[i]);

	if (SV_movestep(ent, move, false)) {
		double delta = ent.s.angles[YAW] - ent.ideal_yaw;

		if ((delta > 45) && (delta < 315)) {
			/* not turned far enough, so don't take the step */
			ent.s.origin.setAll(0, oldorigin);
		}

		SV_LinkEdict(ent);
		G_TouchTriggers(ent);
		return true;
	}

	SV_LinkEdict(ent);
	G_TouchTriggers(ent);
	return false;
}

/* ============================================================================ */

SV_NewChaseDir(edict_t actor, edict_t enemy, double dist) {
	// float deltax, deltay;
	// float d[3];
	// float tdir, olddir, turnaround;

	if (actor == null || enemy == null) {
		return;
	}

	double olddir = anglemod(((actor.ideal_yaw ~/ 45) * 45).toDouble());
	double turnaround = anglemod(olddir - 180);

	double deltax = enemy.s.origin[0] - actor.s.origin[0];
	double deltay = enemy.s.origin[1] - actor.s.origin[1];

  List<double> d = [0,0,0];
	if (deltax > 10) {
		d[1] = 0;
	} else if (deltax < -10) {
		d[1] = 180;
	} else {
		d[1] = _DI_NODIR.toDouble();
	}

	if (deltay < -10) {
		d[2] = 270;
	} else if (deltay > 10) {
		d[2] = 90;
	} else {
		d[2] = _DI_NODIR.toDouble();
	}

	/* try direct route */
	if ((d[1] != _DI_NODIR) && (d[2] != _DI_NODIR)) {
    double tdir;
		if (d[1] == 0) {
			tdir = d[2] == 90 ? 45 : 315;
		} else {
			tdir = d[2] == 90 ? 135 : 215;
		}

		if ((tdir != turnaround) && SV_StepDirection(actor, tdir, dist)) {
			return;
		}
	}

	/* try other directions */
	if (((randk() & 3) & 1) != 0 || (deltay.abs() > deltax.abs())) {
		double tdir = d[1];
		d[1] = d[2];
		d[2] = tdir;
	}

	if ((d[1] != _DI_NODIR) && (d[1] != turnaround) &&
		SV_StepDirection(actor, d[1], dist))
	{
		return;
	}

	if ((d[2] != _DI_NODIR) && (d[2] != turnaround) &&
		SV_StepDirection(actor, d[2], dist))
	{
		return;
	}

	/* there is no direct path to the player, so pick another direction */
	if ((olddir != _DI_NODIR) && SV_StepDirection(actor, olddir, dist))
	{
		return;
	}

	if ((randk() & 1) != 0) /* randomly determine direction of search */
	{
		for (double tdir = 0; tdir <= 315; tdir += 45)
		{
			if ((tdir != turnaround) && SV_StepDirection(actor, tdir, dist))
			{
				return;
			}
		}
	}
	else
	{
		for (double tdir = 315; tdir >= 0; tdir -= 45)
		{
			if ((tdir != turnaround) && SV_StepDirection(actor, tdir, dist))
			{
				return;
			}
		}
	}

	if ((turnaround != _DI_NODIR) && SV_StepDirection(actor, turnaround, dist)) {
		return;
	}

	actor.ideal_yaw = olddir; /* can't move */

	/* if a bridge was pulled out from underneath
	   a monster, it may not have a valid standing
	   position at all */
	// if (!M_CheckBottom(actor)) {
	// 	SV_FixCheckBottom(actor);
	// }
}

M_MoveToGoal(edict_t ent, double dist) {

	if (ent == null) {
		return;
	}

	var goal = ent.goalentity;

	if (ent.groundentity == null && (ent.flags & (FL_FLY | FL_SWIM)) == 0) {
		return;
	}

	/* if the next step hits the enemy, return immediately */
	// if (ent.enemy != null && SV_CloseEnough(ent, ent->enemy, dist)) {
	// 	return;
	// }

	// /* bump around... */
	if (((randk() & 3) == 1) || !SV_StepDirection(ent, ent.ideal_yaw, dist)) {
		if (ent.inuse) {
			SV_NewChaseDir(ent, goal, dist);
		}
	}
}

bool M_walkmove(edict_t ent, double yaw, double dist) {

	if (ent == null) {
		return false;
	}

	if (ent.groundentity == null && (ent.flags & (FL_FLY | FL_SWIM)) == 0) {
		return false;
	}

	yaw = yaw * pi * 2 / 360;

	List<double> move = [cos(yaw) * dist, sin(yaw) * dist, 0];

	return SV_movestep(ent, move, true);
}