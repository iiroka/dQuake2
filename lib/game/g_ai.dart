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
 * The basic AI functions like enemy detection, attacking and so on.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/collision.dart' show CM_AreasConnected;
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'game.dart';
import 'g_utils.dart';
import 'monster/misc/move.dart';

/*
 * Called once each frame to set level.sight_client
 * to the player to be checked for in findtarget.
 * If all clients are either dead or in notarget,
 * sight_client will be null.
 * In coop games, sight_client will cycle
 * between the clients.
 */
AI_SetSightClient() {

  int start;
	if (level.sight_client == null) {
		start = 1;
	}
	else
	{
		start = level.sight_client.index;
	}

	int check = start;

	while (true) {
		check++;

		if (check > game.maxclients) {
			check = 1;
		}

		final ent = g_edicts[check];

		if (ent.inuse &&
			(ent.health > 0) &&
			(ent.flags & FL_NOTARGET) == 0) {
			level.sight_client = ent;
			return; /* got one */
		}

		if (check == start) {
			level.sight_client = null;
			return; /* nobody to see */
		}
	}
}

/*
 * Move the specified distance at current facing.
 */
ai_move(edict_t self, double dist) {
	if (self == null) {
		return;
	}

	M_walkmove(self, self.s.angles[YAW], dist);
}

/*
 *
 * Used for standing around and looking
 * for players Distance is for slight
 * position adjustments needed by the
 * animations
 */
ai_stand(edict_t self, double dist) {

	if (self == null) {
		return;
	}

	if (dist != 0) {
		M_walkmove(self, self.s.angles[YAW], dist);
	}

	if ((self.monsterinfo.aiflags & AI_STAND_GROUND) != 0) {
		if (self.enemy != null) {
      List<double> v = [0,0,0];
			VectorSubtract(self.enemy.s.origin, self.s.origin, v);
			self.ideal_yaw = vectoyaw(v);

	// 		if ((self->s.angles[YAW] != self->ideal_yaw) &&
	// 			self->monsterinfo.aiflags & AI_TEMP_STAND_GROUND)
	// 		{
	// 			self->monsterinfo.aiflags &=
	// 				~(AI_STAND_GROUND | AI_TEMP_STAND_GROUND);
	// 			self->monsterinfo.run(self);
	// 		}

			M_ChangeYaw(self);
	// 		ai_checkattack(self);
		} else {
			FindTarget(self);
		}

		return;
	}

	if (FindTarget(self)) {
		return;
	}

	if (level.time > self.monsterinfo.pausetime) {
		self.monsterinfo.walk(self);
		return;
	}

	// if (!(self->spawnflags & 1) && (self->monsterinfo.idle) &&
	// 	(level.time > self->monsterinfo.idle_time)) {
	// 	if (self->monsterinfo.idle_time) {
	// 		self->monsterinfo.idle(self);
	// 		self->monsterinfo.idle_time = level.time + 15 + random() * 15;
	// 	} else {
	// 		self->monsterinfo.idle_time = level.time + random() * 15;
	// 	}
	// }
}

/*
 * The monster is walking it's beat
 */
ai_walk(edict_t self, double dist) {
	if (self == null) {
		return;
	}

	M_MoveToGoal(self, dist);

	/* check for noticing a player */
	if (FindTarget(self)) {
		return;
	}

	if ((self.monsterinfo.search != null) && (level.time > self.monsterinfo.idle_time))
	{
		if (self.monsterinfo.idle_time != 0) {
			self.monsterinfo.search(self);
			self.monsterinfo.idle_time = level.time + 15 + frandk() * 15;
		}
		else
		{
			self.monsterinfo.idle_time = level.time + frandk() * 15;
		}
	}
}

/* ============================================================================ */

/*
 * .enemy
 * Will be world if not currently angry at anyone.
 *
 * .movetarget
 * The next path spot to walk toward.  If .enemy, ignore .movetarget.
 * When an enemy is killed, the monster will try to return to it's path.
 *
 * .hunt_time
 * Set to time + something when the player is in sight, but movement straight for
 * him is blocked.  This causes the monster to use wall following code for
 * movement direction instead of sighting on the player.
 *
 * .ideal_yaw
 * A yaw angle of the intended direction, which will be turned towards at up
 * to 45 deg / state.  If the enemy is in view and hunt_time is not active,
 * this will be the exact line towards the enemy.
 *
 * .pausetime
 * A monster will leave it's stand state and head towards it's .movetarget when
 * time > .pausetime.
 */

/* ============================================================================ */

/*
 * returns the range categorization of an entity relative to self
 * 0	melee range, will become hostile even if back is turned
 * 1	visibility and infront, or visibility and show hostile
 * 2	infront and show hostile
 * 3	only triggered by damage
 */
int range(edict_t self, edict_t other) {

 	if (self == null || other == null) {
		return 0;
	}

  List<double> v = [0,0,0];
	VectorSubtract(self.s.origin, other.s.origin, v);
	double len = VectorLength(v);

	if (len < MELEE_DISTANCE)
	{
		return RANGE_MELEE;
	}

	if (len < 500)
	{
		return RANGE_NEAR;
	}

	if (len < 1000)
	{
		return RANGE_MID;
	}

	return RANGE_FAR;
}

/*
 * returns 1 if the entity is visible
 * to self, even if not infront
 */
bool visible(edict_t self, edict_t other) {

	if (self == null || other == null) {
		return false;
	}

  List<double> spot1 = List.generate(3, (i) => self.s.origin[i]);
	spot1[2] += self.viewheight;
  List<double> spot2 = List.generate(3, (i) => other.s.origin[i]);
	spot2[2] += other.viewheight;
	final trace = SV_Trace(spot1, [0,0,0], [0,0,0], spot2, self, MASK_OPAQUE);
	if (trace.fraction == 1.0) {
		return true;
	}

	return false;
}

/*
 * returns 1 if the entity is in
 * front (in sight) of self
 */
bool infront(edict_t self, edict_t other) {

	if (self == null || other == null) {
		return false;
	}

  List<double> forward = [0,0,0];
	AngleVectors(self.s.angles, forward, null, null);

  List<double> vec = [0,0,0];
	VectorSubtract(other.s.origin, self.s.origin, vec);
	VectorNormalize(vec);
	double dot = DotProduct(vec, forward);
	if (dot > 0.3)
	{
		return true;
	}

	return false;
}

FoundTarget(edict_t self) {
	if (self == null || self.enemy == null || !self.enemy.inuse) {
		return;
	}

	/* let other monsters see this monster for a while */
	if (self.enemy.client != null) {
		level.sight_entity = self;
		level.sight_entity_framenum = level.framenum;
		level.sight_entity.light_level = 128;
	}

	self.show_hostile = level.time.toInt() + 1; /* wake up other monsters */

  self.monsterinfo.last_sighting.setAll(0, self.enemy.s.origin);
	self.monsterinfo.trail_time = level.time;

	if (self.combattarget == null) {
		// HuntTarget(self);
		return;
	}

	// self.goalentity = self.movetarget = G_PickTarget(self.combattarget);
	if (self.movetarget == null) {
		self.goalentity = self.movetarget = self.enemy;
		// HuntTarget(self);
		Com_Printf("${self.classname} at ${self.s.origin}, combattarget ${self.combattarget} not found\n");
		return;
	}

	/* clear out our combattarget, these are a one shot deal */
	self.combattarget = null;
	self.monsterinfo.aiflags |= AI_COMBAT_POINT;

	/* clear the targetname, that point is ours! */
	self.movetarget.targetname = null;
	self.monsterinfo.pausetime = 0;

	/* run for it */
	self.monsterinfo.run(self);
}


/*
 * Self is currently not attacking anything,
 * so try to find a target
 *
 * Returns TRUE if an enemy was sighted
 *
 * When a player fires a missile, the point
 * of impact becomes a fakeplayer so that
 * monsters that see the impact will respond
 * as if they had seen the player.
 *
 * To avoid spending too much time, only
 * a single client (or fakeclient) is
 * checked each frame. This means multi
 * player games will have slightly
 * slower noticing monsters.
 */
bool FindTarget(edict_t self) {

	if (self == null) {
		return false;
	}

	if ((self.monsterinfo.aiflags & AI_GOOD_GUY) != 0) {
		return false;
	}

	/* if we're going to a combat point, just proceed */
	if ((self.monsterinfo.aiflags & AI_COMBAT_POINT) != 0) {
		return false;
	}

	/* if the first spawnflag bit is set, the monster
	   will only wake up on really seeing the player,
	   not another monster getting angry or hearing
	   something */

	bool heardit = false;
  edict_t client;

	if ((level.sight_entity_framenum >= (level.framenum - 1)) &&
		(self.spawnflags & 1) == 0) {
		client = level.sight_entity;

		if (client.enemy == self.enemy) {
			return false;
		}
	} else if (level.sound_entity_framenum >= (level.framenum - 1)) {
		client = level.sound_entity;
		heardit = true;
	} else if (self.enemy == null &&
			 (level.sound2_entity_framenum >= (level.framenum - 1)) &&
			 (self.spawnflags & 1) == 0) {
		client = level.sound2_entity;
		heardit = true;
	} else {
		client = level.sight_client;

		if (client == null) {
			return false; /* no clients to get mad at */
		}
	}

	/* if the entity went away, forget it */
	if (!client.inuse) {
		return false;
	}

	if (client == self.enemy) {
		return true;
	}

	if (client.client != null) {
		if ((client.flags & FL_NOTARGET) != 0) {
			return false;
		}
	} else if ((client.svflags & SVF_MONSTER) != 0) {
		if (client.enemy == null) {
			return false;
		}

		if ((client.enemy.flags & FL_NOTARGET) != 0) {
			return false;
		}
	} else if (heardit) {
		if (((client.owner as edict_t).flags & FL_NOTARGET) != 0) {
			return false;
		}
	} else {
		return false;
	}

	if (!heardit) {
		int r = range(self, client);
		if (r == RANGE_FAR) {
			return false;
		}

		/* is client in an spot too dark to be seen? */
		if (client.light_level <= 5) {
			return false;
		}

		if (!visible(self, client)) {
			return false;
		}

		if (r == RANGE_NEAR) {
			if ((client.show_hostile < level.time.toInt()) && !infront(self, client)) {
				return false;
			}
		} else if (r == RANGE_MID) {
			if (!infront(self, client)) {
				return false;
			}
		}

		self.enemy = client;

	// 	if (strcmp(self->enemy->classname, "player_noise") != 0)
	// 	{
	// 		self->monsterinfo.aiflags &= ~AI_SOUND_TARGET;

	// 		if (!self->enemy->client)
	// 		{
	// 			self->enemy = self->enemy->enemy;

	// 			if (!self->enemy->client)
	// 			{
	// 				self->enemy = NULL;
	// 				return false;
	// 			}
	// 		}
	// 	}
	} else { /* heardit */
	// 	vec3_t temp;

		if ((self.spawnflags & 1) != 0) {
			if (!visible(self, client)) {
				return false;
			}
		} else {
	// 		if (!gi.inPHS(self->s.origin, client->s.origin))
	// 		{
	// 			return false;
	// 		}
		}

    List<double> temp = [0,0,0];
		VectorSubtract(client.s.origin, self.s.origin, temp);

		if (VectorLength(temp) > 1000) { /* too far to hear */
			return false;
		}

		/* check area portals - if they are different
		   and not connected then we can't hear it */
		if (client.areanum != self.areanum) {
			if (!CM_AreasConnected(self.areanum, client.areanum)) {
				return false;
			}
		}

		self.ideal_yaw = vectoyaw(temp);
		M_ChangeYaw(self);

		/* hunt the sound for a bit; hopefully find the real player */
		self.monsterinfo.aiflags |= AI_SOUND_TARGET;
		self.enemy = client;
	}

	FoundTarget(self);

	// if (!(self->monsterinfo.aiflags & AI_SOUND_TARGET) &&
	// 	(self->monsterinfo.sight))
	// {
	// 	self->monsterinfo.sight(self, self->enemy);
	// }

	return true;
}

/* ============================================================================= */