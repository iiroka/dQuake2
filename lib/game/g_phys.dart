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
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'game.dart';
import 'g_monster.dart';

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

	// if (ent.think == null) {
	// 	gi.error("NULL ent->think");
	// }

	// ent->think(ent);

	return false;
}

/*
 * Bmodel objects don't interact with each
 * other, but push all box objects
 */
SV_Physics_Pusher(edict_t ent) {
	// vec3_t move, amove;
	// edict_t *part, *mv;

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
	// pushed_p = pushed;

  edict_t part;
  List<double> move = [0,0,0];
  List<double> amove = [0,0,0];
	for (part = ent; part != null; part = part.teamchain) {
		if (part.velocity[0] != 0 || part.velocity[1] != 0 || part.velocity[2] != 0 ||
			  part.avelocity[0] != 0 || part.avelocity[1] != 0 || part.avelocity[2] != 0) {
			/* object is moving */
			VectorScale(part.velocity, FRAMETIME, move);
			VectorScale(part.avelocity, FRAMETIME, amove);

	// 		if (!SV_Push(part, move, amove))
	// 		{
	// 			break; /* move was blocked */
	// 		}
		}
	}

	// if (pushed_p > &pushed[MAX_EDICTS -1 ])
	// {
	// 	gi.error("pushed_p > &pushed[MAX_EDICTS - 1], memory corrupted");
	// }

	if (part != null) {
		/* the move failed, bump all nextthink
		   times and back out moves */
	// 	for (mv = ent; mv; mv = mv->teamchain)
	// 	{
	// 		if (mv->nextthink > 0)
	// 		{
	// 			mv->nextthink += FRAMETIME;
	// 		}
	// 	}

	// 	/* if the pusher has a "blocked" function, call it
	// 	   otherwise, just stay in place until the obstacle
	// 	   is gone */
	// 	if (part->blocked)
	// 	{
	// 		part->blocked(part, obstacle);
	// 	}
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

SV_Physics_Step(edict_t ent) {
	// qboolean wasonground;
	// qboolean hitsound = false;
	// float *vel;
	// float speed, newspeed, control;
	// float friction;
	// edict_t *groundentity;
	// int mask;
	// vec3_t oldorig;
	// trace_t tr;

	if (ent == null) {
		return;
	}

	/* airborn monsters should always check for ground */
	if (ent.groundentity == null) {
		M_CheckGround(ent);
	}

	var groundentity = ent.groundentity;

	// SV_CheckVelocity(ent);

	bool wasonground = groundentity != null;

	// if (ent->avelocity[0] || ent->avelocity[1] || ent->avelocity[2])
	// {
	// 	SV_AddRotationalFriction(ent);
	// }

	/* add gravity except:
	     flying monsters
	     swimming monsters who are in the water */
	if (!wasonground) {
	// 	if (!(ent->flags & FL_FLY))
	// 	{
	// 		if (!((ent->flags & FL_SWIM) && (ent->waterlevel > 2)))
	// 		{
	// 			if (ent->velocity[2] < sv_gravity->value * -0.1)
	// 			{
	// 				hitsound = true;
	// 			}

	// 			if (ent->waterlevel == 0)
	// 			{
	// 				SV_AddGravity(ent);
	// 			}
	// 		}
	// 	}
	}

	/* friction for flying monsters that have been given vertical velocity */
	// if ((ent->flags & FL_FLY) && (ent->velocity[2] != 0))
	// {
	// 	speed = fabs(ent->velocity[2]);
	// 	control = speed < STOPSPEED ? STOPSPEED : speed;
	// 	friction = FRICTION / 3;
	// 	newspeed = speed - (FRAMETIME * control * friction);

	// 	if (newspeed < 0)
	// 	{
	// 		newspeed = 0;
	// 	}

	// 	newspeed /= speed;
	// 	ent->velocity[2] *= newspeed;
	// }

	// /* friction for flying monsters that have been given vertical velocity */
	// if ((ent->flags & FL_SWIM) && (ent->velocity[2] != 0))
	// {
	// 	speed = fabs(ent->velocity[2]);
	// 	control = speed < STOPSPEED ? STOPSPEED : speed;
	// 	newspeed = speed - (FRAMETIME * control * WATERFRICTION * ent->waterlevel);

	// 	if (newspeed < 0)
	// 	{
	// 		newspeed = 0;
	// 	}

	// 	newspeed /= speed;
	// 	ent->velocity[2] *= newspeed;
	// }

	// if (ent->velocity[2] || ent->velocity[1] || ent->velocity[0])
	// {
	// 	/* apply friction: let dead monsters who
	// 	   aren't completely onground slide */
	// 	if ((wasonground) || (ent->flags & (FL_SWIM | FL_FLY)))
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

	// 	if (ent->svflags & SVF_MONSTER)
	// 	{
	// 		mask = MASK_MONSTERSOLID;
	// 	}
	// 	else
	// 	{
	// 		mask = MASK_SOLID;
	// 	}

	// 	VectorCopy(ent->s.origin, oldorig);
	// 	SV_FlyMove(ent, FRAMETIME, mask);

	// 	/* Evil hack to work around dead parasites (and maybe other monster)
	// 	   falling through the worldmodel into the void. We copy the current
	// 	   origin (see above) and after the SV_FlyMove() was performend we
	// 	   checl if we're stuck in the world model. If yes we're undoing the
	// 	   move. */
	// 	if (!VectorCompare(ent->s.origin, oldorig))
	// 	{
	// 		tr = gi.trace(ent->s.origin, ent->mins, ent->maxs, ent->s.origin, ent, mask);

	// 		if (tr.startsolid)
	// 		{
	// 			VectorCopy(oldorig, ent->s.origin);
	// 		}
	// 	}

	// 	gi.linkentity(ent);
	// 	G_TouchTriggers(ent);

	// 	if (!ent->inuse)
	// 	{
	// 		return;
	// 	}

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
	// }

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
      print("TOSS");
			// SV_Physics_Toss(ent);
			break;
		default:
			Com_Error(ERR_DROP, "Game Error: SV_Physics: bad movetype ${ent.movetype}");
	}
}
