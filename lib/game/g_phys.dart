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
 * Quake IIs legendary physic engine.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_world.dart';

import 'game.dart';
import 'g_main.dart';
import 'g_monster.dart';
import 'g_utils.dart';

const _STOP_EPSILON = 0.1;
const _STOPSPEED = 100;
const _FRICTION = 6;
const _WATERFRICTION = 1;

/*
 * pushmove objects do not obey gravity, and do not interact
 * with each other or trigger fields, but block normal movement
 * and push normal objects when they move.
 *
 * onground is set for toss objects when they come to a complete
 * rest. It is set for steping or walking objects.
 *
 * doors, plats, etc are SOLID_BSP, and MOVETYPE_PUSH
 * bonus items are SOLID_TRIGGER touch, and MOVETYPE_TOSS
 * corpses are SOLID_NOT and MOVETYPE_TOSS
 * crates are SOLID_BBOX and MOVETYPE_TOSS
 * walking monsters are SOLID_SLIDEBOX and MOVETYPE_STEP
 * flying/floating monsters are SOLID_SLIDEBOX and MOVETYPE_FLY
 *
 * solid_edge items only clip against bsp models.
 */

edict_t SV_TestEntityPosition(edict_t ent) {
	if (ent == null) {
		return null;
	}

	int mask;
	if (ent.clipmask != 0) {
		mask = ent.clipmask;
	} else {
		mask = MASK_SOLID;
	}

	var trace = SV_Trace(ent.s.origin, ent.mins, ent.maxs,
			ent.s.origin, ent, mask);

	if (trace.startsolid)
	{
    if ((ent.svflags & SVF_DEADMONSTER) != 0 && (trace.ent.client || (trace.ent.svflags & SVF_MONSTER) != 0)) {
			return null;
		}

		return g_edicts[0];
	}

	return null;
}


SV_CheckVelocity(edict_t ent) {
	if (ent == null) {
		return;
	}

	if (VectorLength(ent.velocity) > sv_maxvelocity.value) {
		VectorNormalize(ent.velocity);
		VectorScale(ent.velocity, sv_maxvelocity.value, ent.velocity);
	}
}
/*
 * Runs thinking code for
 * this frame if necessary
 */
bool SV_RunThink(edict_t ent) {
	if (ent == null) {
		return false;
	}

	final thinktime = ent.nextthink;
	if (thinktime <= 0) {
		return true;
	}

	if (thinktime > level.time + 0.001) {
		return true;
	}

	ent.nextthink = 0;

	if (ent.think == null) {
	  Com_Error(ERR_DROP, "Game Error: NULL ent->think");
	}

	ent.think(ent);
	return false;
}

/*
 * Two entities have touched, so
 * run their touch functions
 */
SV_Impact(edict_t e1, trace_t trace) {

	if (e1 == null || trace == null) {
		return;
	}

	final e2 = trace.ent;

	if (e1.touch != null && (e1.solid != solid_t.SOLID_NOT))
	{
		e1.touch(e1, e2, trace.plane, trace.surface);
	}

	if (e2.touch != null && (e2.solid != solid_t.SOLID_NOT))
	{
		e2.touch(e2, e1, null, null);
	}
}

/*
 * Slide off of the impacting object
 * returns the blocked flags (1 = floor,
 * 2 = step / wall)
 */
int ClipVelocity(List<double> ind, List<double> normal, List<double> out, double overbounce) {

	int blocked = 0;

	if (normal[2] > 0) {
		blocked |= 1; /* floor */
	}

	if (normal[2] == 0) {
		blocked |= 2; /* step */
	}

	double backoff = DotProduct(ind, normal) * overbounce;

	for (int i = 0; i < 3; i++) {
		double change = normal[i] * backoff;
		out[i] = ind[i] - change;

		if ((out[i] > -_STOP_EPSILON) && (out[i] < _STOP_EPSILON))
		{
			out[i] = 0;
		}
	}

	return blocked;
}


/*
 * The basic solid body movement clip
 * that slides along multiple planes
 * Returns the clipflags if the velocity
 * was modified (hit something solid)
 *
 * 1 = floor
 * 2 = wall / step
 * 4 = dead stop
 */
int SV_FlyMove(edict_t ent, double time, int mask) {

	if (ent == null) {
		return 0;
	}

	int numbumps = 4;

	int blocked = 0;
  List<double> original_velocity = List.generate(3, (i) => ent.velocity[i]);
  List<double> primal_velocity = List.generate(3, (i) => ent.velocity[i]);

	double time_left = time;

	ent.groundentity = null;

  List<List<double>> planes = [];

	for (int bumpcount = 0; bumpcount < numbumps; bumpcount++) {
    List<double> end = List.generate(3, (i) => ent.s.origin[i] + time_left * ent.velocity[i]);

		final trace = SV_Trace(ent.s.origin, ent.mins, ent.maxs, end, ent, mask);

		if (trace.allsolid) {
			/* entity is trapped in another solid */
      ent.velocity.fillRange(0, 3, 0);
			return 3;
		}

		if (trace.fraction > 0) {
			/* actually covered some distance */
      ent.s.origin.setAll(0, trace.endpos);
      original_velocity.setAll(0, ent.velocity);
			planes = [];
		}

		if (trace.fraction == 1) {
			break; /* moved the entire distance */
		}

		var hit = trace.ent;

		if (trace.plane.normal[2] > 0.7) {
			blocked |= 1; /* floor */

			if (hit.solid == solid_t.SOLID_BSP) {
				ent.groundentity = hit;
				ent.groundentity_linkcount = hit.linkcount;
			}
		}

		if (trace.plane.normal[2] == 0) {
			blocked |= 2; /* step */
		}

		/* run the impact function */
		SV_Impact(ent, trace);

		if (!ent.inuse) {
			break; /* removed by the impact function */
		}

		time_left -= time_left * trace.fraction;

		/* cliped to another plane */
		// if (numplanes >= MAX_CLIP_PLANES) {
		// 	/* this shouldn't really happen */
    //   ent.velocity.fillRange(0, 3, 0);
		// 	return 3;
		// }

    planes.add(trace.plane.normal);

		/* modify original_velocity so it
		   parallels all of the clip planes */
    int i;
    List<double> new_velocity = [0,0,0];
		for (i = 0; i < planes.length; i++) {
			ClipVelocity(original_velocity, planes[i], new_velocity, 1);

      int j;
			for (j = 0; j < planes.length; j++) {
				if ((j != i) && (planes[i][0] != planes[j][0] || planes[i][1] != planes[j][1] || planes[i][2] != planes[j][2])) {
					if (DotProduct(new_velocity, planes[j]) < 0) {
						break; /* not ok */
					}
				}
			}

			if (j == planes.length) {
				break;
			}
		}

		if (i != planes.length) {
			/* go along this plane */
      ent.velocity.setAll(0, new_velocity);
		}
		else
		{
			/* go along the crease */
			if (planes.length != 2) {
        ent.velocity.fillRange(0, 3, 0);
				return 7;
			}

      List<double> dir = [0,0,0];
			CrossProduct(planes[0], planes[1], dir);
			double d = DotProduct(dir, ent.velocity);
			VectorScale(dir, d, ent.velocity);
		}

		/* if original velocity is against the original
		   velocity, stop dead to avoid tiny occilations
		   in sloping corners */
		if (DotProduct(ent.velocity, primal_velocity) <= 0)
		{
			ent.velocity.fillRange(0, 3, 0);
			return blocked;
		}
	}

	return blocked;
}

SV_AddGravity(edict_t ent) {
	if (ent == null) {
		return;
	}

	ent.velocity[2] -= ent.gravity * sv_gravity.value * FRAMETIME;
}


/*
 * Returns the actual bounding box of a bmodel.
 * This is a big improvement over what q2 normally
 * does with rotating bmodels - q2 sets absmin,
 * absmax to a cube that will completely contain
 * the bmodel at *any* rotation on *any* axis, whether
 * the bmodel can actually rotate to that angle or not.
 * This leads to a lot of false block tests in SV_Push
 * if another bmodel is in the vicinity.
 */
RealBoundingBox(edict_t ent, List<double> mins, List<double> maxs) {

  List<List<double>> p = List.generate(8, (i) => [0,0,0]);

	for (int k = 0; k < 2; k++) {
		int k4 = k * 4;

		if (k != 0) {
			p[k4][2] = ent.maxs[2];
		} else {
			p[k4][2] = ent.mins[2];
		}

		p[k4 + 1][2] = p[k4][2];
		p[k4 + 2][2] = p[k4][2];
		p[k4 + 3][2] = p[k4][2];

		for (int j = 0; j < 2; j++) {
			int j2 = j * 2;

			if (j != 0) {
				p[j2 + k4][1] = ent.maxs[1];
			} else {
				p[j2 + k4][1] = ent.mins[1];
			}

			p[j2 + k4 + 1][1] = p[j2 + k4][1];

			for (int i = 0; i < 2; i++) {
				if (i != 0) {
					p[i + j2 + k4][0] = ent.maxs[0];
				} else {
					p[i + j2 + k4][0] = ent.mins[0];
				}
			}
		}
	}

  List<double> forward = [0,0,0];
  List<double> left = [0,0,0];
  List<double> up = [0,0,0];
	AngleVectors(ent.s.angles, forward, left, up);

  List<double> f1 = [0,0,0];
  List<double> l1 = [0,0,0];
  List<double> u1 = [0,0,0];
	for (int i = 0; i < 8; i++) {
		VectorScale(forward, p[i][0], f1);
		VectorScale(left, -p[i][1], l1);
		VectorScale(up, p[i][2], u1);
		VectorAdd(ent.s.origin, f1, p[i]);
		VectorAdd(p[i], l1, p[i]);
		VectorAdd(p[i], u1, p[i]);
	}

  mins.setAll(0, p[0]);
  maxs.setAll(0, p[0]);

	for (int i = 1; i < 8; i++) {
		if (mins[0] > p[i][0]) {
			mins[0] = p[i][0];
		}

		if (mins[1] > p[i][1]) {
			mins[1] = p[i][1];
		}

		if (mins[2] > p[i][2]) {
			mins[2] = p[i][2];
		}

		if (maxs[0] < p[i][0]) {
			maxs[0] = p[i][0];
		}

 		if (maxs[1] < p[i][1]) {
			maxs[1] = p[i][1];
		}

		if (maxs[2] < p[i][2]) {
			maxs[2] = p[i][2];
		}
	}
}

/* ================================================================== */

/* PUSHMOVE */

/*
 * Does not change the entities velocity at all
 */
trace_t SV_PushEntity(edict_t ent, List<double> push) {
// 	trace_t trace;
// 	vec3_t start;
// 	vec3_t end;
// 	int mask;

  List<double> start = List.generate(3, (i) => ent.s.origin[i]);
  List<double> end = [0,0,0];
  VectorAdd(start, push, end);

  int mask;
  trace_t trace;
  bool retry = false;
  do {
// retry:
    if (ent.clipmask != 0) {
      mask = ent.clipmask;
    } else {
      mask = MASK_SOLID;
    }

    trace = SV_Trace(start, ent.mins, ent.maxs, end, ent, mask);
    if (trace.startsolid || trace.allsolid) {
      mask ^= CONTENTS_DEADMONSTER;
      trace =SV_Trace (start, ent.mins, ent.maxs, end, ent, mask);
    }

    ent.s.origin.setAll(0, trace.endpos);
    SV_LinkEdict(ent);

    /* Push slightly away from non-horizontal surfaces,
      prevent origin stuck in the plane which causes
      the entity to be rendered in full black. */
    if (trace.plane.type != 2) {
      VectorAdd(ent.s.origin, trace.plane.normal, ent.s.origin);
    }

    if (trace.fraction != 1.0) {
      SV_Impact(ent, trace);

      /* if the pushed entity went away
        and the pusher is still there */
      if (!trace.ent.inuse && ent.inuse) {
        /* move the pusher back and try again */
        ent.s.origin.setAll(0, start);
  			SV_LinkEdict(ent);
        retry = true;
      }
    }
  } while (retry);

	if (ent.inuse) {
		G_TouchTriggers(ent);
	}

	return trace;
}

class pushed_t {
	edict_t ent;
	List<double> origin = [0,0,0];
	List<double> angles = [0,0,0];
	double deltayaw = 0;
}

// pushed_t pushed[MAX_EDICTS], *pushed_p;
List<pushed_t> pushed = List.generate(MAX_EDICTS, (i) => pushed_t());
int pushed_i;
edict_t obstacle;

/*
 * Objects need to be moved back on a failed push,
 * otherwise riders would continue to slide.
 */
bool SV_Push(edict_t pusher, List<double> move, List<double> amove) {
	// int i, e;
	// edict_t *check, *block;
	// pushed_t *p;
	// vec3_t org, org2, move2, forward, right, up;
	// vec3_t realmins, realmaxs;

	if (pusher == null) {
		return false;
	}

	/* clamp the move to 1/8 units, so the position will
	   be accurate for client side prediction */
	for (int i = 0; i < 3; i++) {
		double temp = move[i] * 8.0;

		if (temp > 0.0) {
			temp += 0.5;
		} else {
			temp -= 0.5;
		}

		move[i] = 0.125 * temp.toInt();
	}

	/* we need this for pushing things later */
  List<double> org = List.generate(3, (i) => -amove[i]);
  List<double> forward = [0,0,0];
  List<double> right = [0,0,0];
  List<double> up = [0,0,0];
	AngleVectors(org, forward, right, up);

	/* save the pusher's original position */
	pushed[pushed_i].ent = pusher;
  pushed[pushed_i].origin.setAll(0, pusher.s.origin);
  pushed[pushed_i].angles.setAll(0, pusher.s.angles);

	if (pusher.client != null) {
		pushed[pushed_i].deltayaw = pusher.client.ps.pmove.delta_angles[YAW].toDouble();
	}

	pushed_i++;

	/* move the pusher to it's final position */
	VectorAdd(pusher.s.origin, move, pusher.s.origin);
	VectorAdd(pusher.s.angles, amove, pusher.s.angles);
	SV_LinkEdict(pusher);

	/* Create a real bounding box for
	   rotating brush models. */
  List<double> realmins = [0,0,0];
  List<double> realmaxs = [0,0,0];
	RealBoundingBox(pusher,realmins,realmaxs);

	/* see if any solid entities
	   are inside the final position */

	for (int e = 1; e < globals.num_edicts; e++) {
	  final check = g_edicts[e + 1];
		if (!check.inuse) {
			continue;
		}

		if ((check.movetype == movetype_t.MOVETYPE_PUSH) ||
			(check.movetype == movetype_t.MOVETYPE_STOP) ||
			(check.movetype == movetype_t.MOVETYPE_NONE) ||
			(check.movetype == movetype_t.MOVETYPE_NOCLIP)) {
			continue;
		}

		if (check.prev == null) {
			continue; /* not linked in anywhere */
		}

		/* if the entity is standing on the pusher,
		   it will definitely be moved */
		if (check.groundentity != pusher) {
			/* see if the ent needs to be tested */
			if ((check.absmin[0] >= realmaxs[0]) ||
				(check.absmin[1] >= realmaxs[1]) ||
				(check.absmin[2] >= realmaxs[2]) ||
				(check.absmax[0] <= realmins[0]) ||
				(check.absmax[1] <= realmins[1]) ||
				(check.absmax[2] <= realmins[2])) {
				continue;
			}

			/* see if the ent's bbox is inside
			   the pusher's final position */
			if (SV_TestEntityPosition(check) == null) {
				continue;
			}
		}

		if ((pusher.movetype == movetype_t.MOVETYPE_PUSH) ||
			(check.groundentity == pusher)) {
			/* move this entity */
			pushed[pushed_i].ent = check;
      pushed[pushed_i].origin.setAll(0, check.s.origin);
      pushed[pushed_i].angles.setAll(0, check.s.angles);
			pushed_i++;

			/* try moving the contacted entity */
			VectorAdd(check.s.origin, move, check.s.origin);

			if (check.client != null) {
				check.client.ps.pmove.delta_angles[YAW] += amove[YAW].toInt();
			}

			/* figure movement due to the pusher's amove */
			VectorSubtract(check.s.origin, pusher.s.origin, org);
      List<double> org2 = [
			    DotProduct(org, forward),
          -DotProduct(org, right),
			    DotProduct(org, up)];
      List<double> move2 = [0,0,0];
			VectorSubtract(org2, org, move2);
			VectorAdd(check.s.origin, move2, check.s.origin);

			/* may have pushed them off an edge */
			if (check.groundentity != pusher) {
				check.groundentity = null;
			}

			var block = SV_TestEntityPosition(check);
			if (block == null)

			{   /* pushed ok */
				SV_LinkEdict(check);
				continue;
			}

			/* if it is ok to leave in the old position, do it
			   this is only relevent for riding entities, not
			   pushed */
			VectorSubtract(check.s.origin, move, check.s.origin);
			block = SV_TestEntityPosition(check);

			if (block == null)
			{
				pushed_i--;
				continue;
			}
		}

		/* save off the obstacle so we can
		   call the block function */
		obstacle = check;

		/* move back any entities we already moved
		   go backwards, so if the same entity was pushed
		   twice, it goes back to the original position */
		for (int p_i = pushed_i - 1; p_i >= 0; p_i--) {
      final p = pushed[p_i];
      p.ent.s.origin.setAll(0, p.origin);
      p.ent.s.angles.setAll(0, p.angles);

			if (p.ent.client != null) {
				p.ent.client.ps.pmove.delta_angles[YAW] = p.deltayaw.toInt();
			}

			SV_LinkEdict(p.ent);
		}

		return false;
	}

	/* see if anything we moved has touched a trigger */
	for (int p = pushed_i - 1; p >= 0; p--) {
		G_TouchTriggers(pushed[p].ent);
	}

	return true;
}

/*
 * Bmodel objects don't interact with each
 * other, but push all box objects
 */
SV_Physics_Pusher(edict_t ent) {

	if (ent == null) {
		return;
	}

	/* if not a team captain, so movement
	   will be handled elsewhere */
	if ((ent.flags & FL_TEAMSLAVE) != 0) {
		return;
	}

	/* make sure all team slaves can move before commiting
	   any moves or calling any think functions if the move
	   is blocked, all moved objects will be backed out */
	pushed_i = 0;

  edict_t part;
  List<double> move = [0,0,0];
  List<double> amove = [0,0,0];
	for (part = ent; part != null; part = part.teamchain) {
		if (part.velocity[0] != 0 || part.velocity[1] != 0 || part.velocity[2] != 0 ||
			  part.avelocity[0] != 0 || part.avelocity[1] != 0 || part.avelocity[2] != 0) {
			/* object is moving */
			VectorScale(part.velocity, FRAMETIME, move);
			VectorScale(part.avelocity, FRAMETIME, amove);

			if (!SV_Push(part, move, amove)) {
				break; /* move was blocked */
			}
		}
	}

	// if (pushed_p > &pushed[MAX_EDICTS -1 ])
	// {
	// 	gi.error("pushed_p > &pushed[MAX_EDICTS - 1], memory corrupted");
	// }

	if (part != null) {
		/* the move failed, bump all nextthink
		   times and back out moves */
		// for (mv = ent; mv; mv = mv->teamchain) {
	// 		if (mv->nextthink > 0)
	// 		{
	// 			mv->nextthink += FRAMETIME;
	// 		}
	// 	}

		/* if the pusher has a "blocked" function, call it
		   otherwise, just stay in place until the obstacle
		   is gone */
		if (part.blocked != null) {
			part.blocked(part, obstacle);
		}
	} else {
		/* the move succeeded, so call all think functions */
		for (part = ent; part != null; part = part.teamchain) {
			SV_RunThink(part);
		}
	}
}

/* ================================================================== */

/*
 * Non moving objects can only think
 */
SV_Physics_None(edict_t ent) {
	if (ent == null) {
		return;
	}

	/* regular thinking */
	SV_RunThink(ent);
}

/* ================================================================== */

/* TOSS / BOUNCE */

/*
 * Toss, bounce, and fly movement.
 * When onground, do nothing.
 */
SV_Physics_Toss(edict_t ent) {
	// trace_t trace;
	// vec3_t move;
	// float backoff;
	// edict_t *slave;
	// qboolean wasinwater;
	// qboolean isinwater;
	// vec3_t old_origin;

	if (ent == null) {
		return;
	}

	/* regular thinking */
	SV_RunThink(ent);

	/* if not a team captain, so movement
	   will be handled elsewhere */
	if ((ent.flags & FL_TEAMSLAVE) != 0) {
		return;
	}

	if (ent.velocity[2] > 0) {
		ent.groundentity = null;
	}

	/* check for the groundentity going away */
	if (ent.groundentity != null) {
		if (!ent.groundentity.inuse) {
			ent.groundentity = null;
		}
	}

	/* if onground, return without moving */
	if (ent.groundentity != null) {
		return;
	}

	// VectorCopy(ent->s.origin, old_origin);

	SV_CheckVelocity(ent);

	/* add gravity */
	if ((ent.movetype != movetype_t.MOVETYPE_FLY) &&
		(ent.movetype != movetype_t.MOVETYPE_FLYMISSILE)) {
		SV_AddGravity(ent);
	}

	/* move angles */
	VectorMA(ent.s.angles, FRAMETIME, ent.avelocity, ent.s.angles);

	/* move origin */
  List<double> move = [0,0,0];
	VectorScale(ent.velocity, FRAMETIME, move);
	final trace = SV_PushEntity(ent, move);

	if (!ent.inuse) {
		return;
	}

	if (trace.fraction < 1) {
    double backoff;
		if (ent.movetype == movetype_t.MOVETYPE_BOUNCE) {
			backoff = 1.5;
		} else {
			backoff = 1;
		}

		ClipVelocity(ent.velocity, trace.plane.normal, ent.velocity, backoff);

		/* stop if on ground */
		if (trace.plane.normal[2] > 0.7)
		{
			if ((ent.velocity[2] < 60) || (ent.movetype != movetype_t.MOVETYPE_BOUNCE)) {
				ent.groundentity = trace.ent;
				ent.groundentity_linkcount = trace.ent.linkcount;
        ent.velocity = [0,0,0];
        ent.avelocity = [0,0,0];
			}
		}
	}

	/* check for water transition */
	final wasinwater = (ent.watertype & MASK_WATER) != 0;
	ent.watertype = SV_PointContents(ent.s.origin);
	final isinwater = (ent.watertype & MASK_WATER) != 0;

	if (isinwater) {
		ent.waterlevel = 1;
	} else {
		ent.waterlevel = 0;
	}

	if (!wasinwater && isinwater) {
	// 	gi.positioned_sound(old_origin, g_edicts, CHAN_AUTO,
	// 			gi.soundindex("misc/h2ohit1.wav"), 1, 1, 0);
	} else if (wasinwater && !isinwater) {
	// 	gi.positioned_sound(ent->s.origin, g_edicts, CHAN_AUTO,
	// 			gi.soundindex("misc/h2ohit1.wav"), 1, 1, 0);
	}

	/* move teamslaves */
	// for (slave = ent->teamchain; slave; slave = slave->teamchain)
	// {
	// 	VectorCopy(ent->s.origin, slave->s.origin);
	// 	gi.linkentity(slave);
	// }
}

SV_Physics_Step(edict_t ent) {

	if (ent == null) {
		return;
	}

	/* airborn monsters should always check for ground */
	if (ent.groundentity == null) {
		M_CheckGround(ent);
	}

	var groundentity = ent.groundentity;

	SV_CheckVelocity(ent);

	bool wasonground = groundentity != null;

	if (ent.avelocity[0] != 0 || ent.avelocity[1] != 0 || ent.avelocity[2] != 0) {
       print("ROTATING");
		// SV_AddRotationalFriction(ent);
	}

	/* add gravity except:
	     flying monsters
	     swimming monsters who are in the water */
	if (!wasonground) {
		if ((ent.flags & FL_FLY) == 0) {
			if (!((ent.flags & FL_SWIM) != 0 && (ent.waterlevel > 2))) {
				// if (ent.velocity[2] < sv_gravity.value * -0.1) {
				// 	hitsound = true;
				// }

				if (ent.waterlevel == 0) {
					SV_AddGravity(ent);
				}
			}
		}
	}

	/* friction for flying monsters that have been given vertical velocity */
	if ((ent.flags & FL_FLY) != 0 && (ent.velocity[2] != 0)) {
	 	final speed = ent.velocity[2].abs();
		final control = speed < _STOPSPEED ? _STOPSPEED : speed;
		final friction = _FRICTION / 3;
		double newspeed = speed - (FRAMETIME * control * friction);
		if (newspeed < 0) {
			newspeed = 0;
		}

		newspeed /= speed;
		ent.velocity[2] *= newspeed;
	}

	/* friction for flying monsters that have been given vertical velocity */
	if ((ent.flags & FL_SWIM) != 0 && (ent.velocity[2] != 0)) {
	 	final speed = ent.velocity[2].abs();
		final control = speed < _STOPSPEED ? _STOPSPEED : speed;
		double newspeed = speed - (FRAMETIME * control * _WATERFRICTION * ent.waterlevel);
		if (newspeed < 0) {
			newspeed = 0;
		}

		newspeed /= speed;
		ent.velocity[2] *= newspeed;
	}

	if (ent.velocity[2] != 0 || ent.velocity[1] != 0 || ent.velocity[0] != 0) {
		/* apply friction: let dead monsters who
		   aren't completely onground slide */
    print("MOVING");
	// 	if ((wasonground) || (ent.flags & (FL_SWIM | FL_FLY)) != 0)
	// 	{
	// 		if (!((ent->health <= 0.0) && !M_CheckBottom(ent)))
	// 		{
	// 			vel = ent->velocity;
	// 			speed = sqrt(vel[0] * vel[0] + vel[1] * vel[1]);

	// 			if (speed)
	// 			{
	// 				friction = FRICTION;

	// 				control = speed < STOPSPEED ? STOPSPEED : speed;
	// 				newspeed = speed - FRAMETIME * control * friction;

	// 				if (newspeed < 0)
	// 				{
	// 					newspeed = 0;
	// 				}

	// 				newspeed /= speed;

	// 				vel[0] *= newspeed;
	// 				vel[1] *= newspeed;
	// 			}
	// 		}
	// 	}

    int mask;
		if ((ent.svflags & SVF_MONSTER) != 0) {
			mask = MASK_MONSTERSOLID;
		} else {
			mask = MASK_SOLID;
		}

	// 	VectorCopy(ent->s.origin, oldorig);
		SV_FlyMove(ent, FRAMETIME, mask);

		/* Evil hack to work around dead parasites (and maybe other monster)
		   falling through the worldmodel into the void. We copy the current
		   origin (see above) and after the SV_FlyMove() was performend we
		   checl if we're stuck in the world model. If yes we're undoing the
		   move. */
	// 	if (!VectorCompare(ent->s.origin, oldorig))
	// 	{
	// 		tr = gi.trace(ent->s.origin, ent->mins, ent->maxs, ent->s.origin, ent, mask);

	// 		if (tr.startsolid)
	// 		{
	// 			VectorCopy(oldorig, ent->s.origin);
	// 		}
	// 	}

	  SV_LinkEdict(ent);
		G_TouchTriggers(ent);

		if (!ent.inuse) {
			return;
		}

	// 	if (ent->groundentity)
	// 	{
	// 		if (!wasonground)
	// 		{
	// 			if (hitsound)
	// 			{
	// 				gi.sound(ent, 0, gi.soundindex("world/land.wav"), 1, 1, 0);
	// 			}
	// 		}
	// 	}
	}

	/* regular thinking */
	SV_RunThink(ent);
}

/* ================================================================== */

G_RunEntity(edict_t ent) async {
	if (ent == null) {
		return;
	}

	// if (ent.prethink != null) {
	// 	ent->prethink(ent);
	// }
  // print("${ent.classname} -> ${ent.movetype}");

	switch (ent.movetype) {
		case movetype_t.MOVETYPE_PUSH:
		case movetype_t.MOVETYPE_STOP:
			SV_Physics_Pusher(ent);
			break;
		case movetype_t.MOVETYPE_NONE:
			SV_Physics_None(ent);
			break;
		case movetype_t.MOVETYPE_NOCLIP:
      print("NOCLIP");
			// SV_Physics_Noclip(ent);
			break;
		case movetype_t.MOVETYPE_STEP:
			SV_Physics_Step(ent);
			break;
		case movetype_t.MOVETYPE_TOSS:
		case movetype_t.MOVETYPE_BOUNCE:
		case movetype_t.MOVETYPE_FLY:
		case movetype_t.MOVETYPE_FLYMISSILE:
			SV_Physics_Toss(ent);
			break;
		default:
			Com_Error(ERR_DROP, "Game Error: SV_Physics: bad movetype ${ent.movetype}");
	}
}
