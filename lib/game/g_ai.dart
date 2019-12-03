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
import 'package:dQuakeWeb/game/g_monster.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'game.dart';
import 'g_utils.dart';
import 'player/trail.dart';
import 'monster/misc/move.dart';

bool enemy_vis = false;
bool enemy_infront = false;
int enemy_range = 0;
double enemy_yaw = 0;

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

			if ((self.s.angles[YAW] != self.ideal_yaw) &&
				(self.monsterinfo.aiflags & AI_TEMP_STAND_GROUND) != 0)
			{
				self.monsterinfo.aiflags &=
					~(AI_STAND_GROUND | AI_TEMP_STAND_GROUND);
				self.monsterinfo.run(self);
			}

			M_ChangeYaw(self);
			ai_checkattack(self);
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

	if ((self.spawnflags & 1) == 0 && (self.monsterinfo.idle != null) &&
		(level.time > self.monsterinfo.idle_time)) {
		if (self.monsterinfo.idle_time != 0) {
			self.monsterinfo.idle(self);
			self.monsterinfo.idle_time = level.time + 15 + frandk() * 15;
		} else {
			self.monsterinfo.idle_time = level.time + frandk() * 15;
		}
	}
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

/*
 * Turns towards target and advances
 * Use this call with a distance of 0
 * to replace ai_face
 */
ai_charge(edict_t self, double dist) {

	if (self == null) {
		return;
	}

	List<double> v = [0,0,0];
	if(self.enemy != null) {
		VectorSubtract(self.enemy.s.origin, self.s.origin, v);
	}

	self.ideal_yaw = vectoyaw(v);
	M_ChangeYaw(self);

	if (dist != 0)
	{
		M_walkmove(self, self.s.angles[YAW], dist);
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

/* ============================================================================ */

HuntTarget(edict_t self) {

	if (self == null) {
		return;
	}

	self.goalentity = self.enemy;

	if ((self.monsterinfo.aiflags & AI_STAND_GROUND) != 0) {
		self.monsterinfo.stand(self);
	} else {
		self.monsterinfo.run(self);
	}

	List<double> vec = [0,0,0];

	if(visible(self, self.enemy)) {
		VectorSubtract(self.enemy.s.origin, self.s.origin, vec);
	}

	self.ideal_yaw = vectoyaw(vec);

	/* wait a while before first attack */
	if ((self.monsterinfo.aiflags & AI_STAND_GROUND) == 0) {
		AttackFinished(self, 1);
	}
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
		HuntTarget(self);
		return;
	}

	self.goalentity = self.movetarget = G_PickTarget(self.combattarget);
	if (self.movetarget == null) {
		self.goalentity = self.movetarget = self.enemy;
		HuntTarget(self);
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

		if (self.enemy.classname != "player_noise") {
			self.monsterinfo.aiflags &= ~AI_SOUND_TARGET;

			if (self.enemy.client == null) {
				self.enemy = self.enemy.enemy;

				if (self.enemy.client == null) {
					self.enemy = null;
					return false;
				}
			}
		}
	} else { /* heardit */

		if ((self.spawnflags & 1) != 0) {
			if (!visible(self, client)) {
				return false;
			}
		} else {
      if (!PF_inPHS(self.s.origin, client.s.origin)) {
				return false;
			}
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

	if ((self.monsterinfo.aiflags & AI_SOUND_TARGET) == 0 &&
		(self.monsterinfo.sight != null)) {
		self.monsterinfo.sight(self, self.enemy);
	}

	return true;
}

/* ============================================================================= */

bool FacingIdeal(edict_t self) {

	if (self == null) {
		return false;
	}

	double delta = anglemod(self.s.angles[YAW] - self.ideal_yaw);
	if ((delta > 45) && (delta < 315))
	{
		return false;
	}

	return true;
}

/* ============================================================================= */

bool M_CheckAttack(edict_t self) {

	if (self == null || self.enemy == null || !self.enemy.inuse) {
		return false;
	}

	if (self.enemy.health > 0) {
		/* see if any entities are in the way of the shot */
    List<double> spot1 = List.generate(3, (i) => self.s.origin[i]);
		spot1[2] += self.viewheight;
    List<double> spot2 = List.generate(3, (i) => self.enemy.s.origin[i]);
		spot2[2] += self.enemy.viewheight;

		final tr = SV_Trace(spot1, null, null, spot2, self,
				CONTENTS_SOLID | CONTENTS_MONSTER | CONTENTS_SLIME |
				CONTENTS_LAVA | CONTENTS_WINDOW);

		/* do we have a clear shot? */
		if (tr.ent != self.enemy) {
			return false;
		}
	}

	/* melee attack */
	if (enemy_range == RANGE_MELEE) {
		/* don't always melee in easy mode */
		if ((skill.integer == 0) && (randk() & 3) != 0) {
			return false;
		}

		if (self.monsterinfo.melee != null) {
			self.monsterinfo.attack_state = AS_MELEE;
		} else {
			self.monsterinfo.attack_state = AS_MISSILE;
		}

		return true;
	}

	/* missile attack */
	if (self.monsterinfo.attack == null) {
		return false;
	}

	if (level.time < self.monsterinfo.attack_finished) {
		return false;
	}

	if (enemy_range == RANGE_FAR) {
		return false;
	}

  double chance;
	if ((self.monsterinfo.aiflags & AI_STAND_GROUND) != 0) {
		chance = 0.4;
	}
	else if (enemy_range == RANGE_MELEE)
	{
		chance = 0.2;
	}
	else if (enemy_range == RANGE_NEAR)
	{
		chance = 0.1;
	}
	else if (enemy_range == RANGE_MID)
	{
		chance = 0.02;
	}
	else
	{
		return false;
	}

	if (skill.integer == 0)
	{
		chance *= 0.5;
	}
	else if (skill.integer >= 2)
	{
		chance *= 2;
	}

	if (frandk() < chance)
	{
		self.monsterinfo.attack_state = AS_MISSILE;
		self.monsterinfo.attack_finished = level.time + 2 * frandk();
		return true;
	}

	if ((self.flags & FL_FLY) != 0)
	{
		if (frandk() < 0.3)
		{
			self.monsterinfo.attack_state = AS_SLIDING;
		}
		else
		{
			self.monsterinfo.attack_state = AS_STRAIGHT;
		}
	}

	return false;
}

/*
 * Turn and close until within an
 * angle to launch a melee attack
 */
ai_run_melee(edict_t self) {
	if (self == null) {
		return;
	}

	self.ideal_yaw = enemy_yaw;
	M_ChangeYaw(self);

	if (FacingIdeal(self)) {
		if (self.monsterinfo.melee != null) {
			self.monsterinfo.melee(self);
			self.monsterinfo.attack_state = AS_STRAIGHT;
		}
	}
}

/*
 * Turn in place until within an
 * angle to launch a missile attack
 */
ai_run_missile(edict_t self) {
	if (self == null) {
		return;
	}

	self.ideal_yaw = enemy_yaw;
	M_ChangeYaw(self);

	if (FacingIdeal(self)) {
		if (self.monsterinfo.attack != null) {
			self.monsterinfo.attack(self);
			self.monsterinfo.attack_state = AS_STRAIGHT;
		}
	}
}


/*
 * Decides if we're going to attack
 * or do something else used by
 * ai_run and ai_stand
 */
bool ai_checkattack(edict_t self) {

	if (self == null) {
		enemy_vis = false;
		return false;
	}

	/* this causes monsters to run blindly
	   to the combat point w/o firing */
	if (self.goalentity != null) {

		if ((self.monsterinfo.aiflags & AI_COMBAT_POINT) != 0) {
			return false;
		}

		if ((self.monsterinfo.aiflags & AI_SOUND_TARGET) != 0 && !visible(self, self.goalentity)) {
			if ((level.time - self.enemy.last_sound_time) > 5.0)
			{
				if (self.goalentity == self.enemy)
				{
					if (self.movetarget != null)
					{
						self.goalentity = self.movetarget;
					}
					else
					{
						self.goalentity = null;
					}
				}

				self.monsterinfo.aiflags &= ~AI_SOUND_TARGET;

				if ((self.monsterinfo.aiflags & AI_TEMP_STAND_GROUND) != 0)
				{
					self.monsterinfo.aiflags &=
							~(AI_STAND_GROUND | AI_TEMP_STAND_GROUND);
				}
			}
			else
			{
				self.show_hostile = level.time.toInt() + 1;
				return false;
			}
		}
	}

	enemy_vis = false;

	/* see if the enemy is dead */
	bool hesDeadJim = false;

	if ((self.enemy == null) || (!self.enemy.inuse)) {
		hesDeadJim = true;
	}
	else if ((self.monsterinfo.aiflags & AI_MEDIC) != 0)
	{
		if (self.enemy.health > 0)
		{
			hesDeadJim = true;
			self.monsterinfo.aiflags &= ~AI_MEDIC;
		}
	}
	else
	{
		if ((self.monsterinfo.aiflags & AI_BRUTAL) != 0)
		{
			if (self.enemy.health <= -80)
			{
				hesDeadJim = true;
			}
		}
		else
		{
			if (self.enemy.health <= 0)
			{
				hesDeadJim = true;
			}
		}
	}

	if (hesDeadJim)
	{
		self.enemy = null;

		if (self.oldenemy != null && (self.oldenemy.health > 0))
		{
			self.enemy = self.oldenemy;
			self.oldenemy = null;
			HuntTarget(self);
		}
		else
		{
			if (self.movetarget != null)
			{
				self.goalentity = self.movetarget;
				self.monsterinfo.walk(self);
			}
			else
			{
				/* we need the pausetime otherwise the stand code
				   will just revert to walking with no target and
				   the monsters will wonder around aimlessly trying
				   to hunt the world entity */
				self.monsterinfo.pausetime = level.time + 100000000;
				self.monsterinfo.stand(self);
			}

			return true;
		}
	}

	/* wake up other monsters */
	self.show_hostile = level.time.toInt() + 1;

	/* check knowledge of enemy */
	enemy_vis = visible(self, self.enemy);

	if (enemy_vis)
	{
		self.monsterinfo.search_time = level.time + 5;
    self.monsterinfo.last_sighting.setAll(0, self.enemy.s.origin);
	}

	/* look for other coop players here */
	if (coop.boolean && (self.monsterinfo.search_time < level.time))
	{
		if (FindTarget(self))
		{
			return true;
		}
	}

	if (self.enemy != null)
	{
		enemy_infront = infront(self, self.enemy);
		enemy_range = range(self, self.enemy);
    List<double> temp = [0,0,0];
		VectorSubtract(self.enemy.s.origin, self.s.origin, temp);
		enemy_yaw = vectoyaw(temp);
	}

	if (self.monsterinfo.attack_state == AS_MISSILE)
	{
		ai_run_missile(self);
		return true;
	}

	if (self.monsterinfo.attack_state == AS_MELEE)
	{
		ai_run_melee(self);
		return true;
	}

	/* if enemy is not currently visible,
	   we will never attack */
	if (!enemy_vis)
	{
		return false;
	}

	return self.monsterinfo.checkattack(self);
}

/*
 * The monster has an enemy
 * it is trying to kill
 */
ai_run(edict_t self, double dist) {

	if (self == null) {
		return;
	}

	/* if we're going to a combat point, just proceed */
	if ((self.monsterinfo.aiflags & AI_COMBAT_POINT) != 0) {
		M_MoveToGoal(self, dist);
		return;
	}

  List<double> v = [0,0,0];

	if ((self.monsterinfo.aiflags & AI_SOUND_TARGET) != 0) {
		VectorSubtract(self.s.origin, self.enemy.s.origin, v);

		if (VectorLength(v) < 64) {
			self.monsterinfo.aiflags |= (AI_STAND_GROUND | AI_TEMP_STAND_GROUND);
			self.monsterinfo.stand(self);
			return;
		}

		M_MoveToGoal(self, dist);

		if (!FindTarget(self)){
			return;
		}
	}

	if (ai_checkattack(self)) {
		return;
	}

	if (self.monsterinfo.attack_state == AS_SLIDING) {
	// 	ai_run_slide(self, dist);
		return;
	}

	if (enemy_vis) {
		M_MoveToGoal(self, dist);
		self.monsterinfo.aiflags &= ~AI_LOST_SIGHT;
    self.monsterinfo.last_sighting.setAll(0, self.enemy.s.origin);
		self.monsterinfo.trail_time = level.time;
		return;
	}

	if ((self.monsterinfo.search_time != 0) &&
		(level.time > (self.monsterinfo.search_time + 20)))
	{
		M_MoveToGoal(self, dist);
		self.monsterinfo.search_time = 0;
		return;
	}

	var save = self.goalentity;
	var tempgoal = G_Spawn();
	self.goalentity = tempgoal;

	var isNew = false;

	if ((self.monsterinfo.aiflags & AI_LOST_SIGHT) == 0) {
		/* just lost sight of the player, decide where to go first */
		self.monsterinfo.aiflags |= (AI_LOST_SIGHT | AI_PURSUIT_LAST_SEEN);
		self.monsterinfo.aiflags &= ~(AI_PURSUE_NEXT | AI_PURSUE_TEMP);
		isNew = true;
	}

	if ((self.monsterinfo.aiflags & AI_PURSUE_NEXT) != 0) {
		self.monsterinfo.aiflags &= ~AI_PURSUE_NEXT;

		/* give ourself more time since we got this far */
		self.monsterinfo.search_time = level.time + 5;

    edict_t marker;
		if ((self.monsterinfo.aiflags & AI_PURSUE_TEMP) != 0) {
			self.monsterinfo.aiflags &= ~AI_PURSUE_TEMP;
			marker = null;
      self.monsterinfo.last_sighting.setAll(0, self.monsterinfo.saved_goal);
			isNew = true;
		} else if ((self.monsterinfo.aiflags & AI_PURSUIT_LAST_SEEN) != 0) {
		  self.monsterinfo.aiflags &= ~AI_PURSUIT_LAST_SEEN;
			marker = PlayerTrail_PickFirst(self);
		} else {
			marker = PlayerTrail_PickNext(self);
		}

		if (marker != null) {
      self.monsterinfo.last_sighting.setAll(0, marker.s.origin);
			self.monsterinfo.trail_time = marker.timestamp;
			self.s.angles[YAW] = self.ideal_yaw = marker.s.angles[YAW];
			isNew = true;
		}
	}

	VectorSubtract(self.s.origin, self.monsterinfo.last_sighting, v);
	double d1 = VectorLength(v);

	if (d1 <= dist) {
		self.monsterinfo.aiflags |= AI_PURSUE_NEXT;
		dist = d1;
	}

  self.goalentity.s.origin.setAll(0, self.monsterinfo.last_sighting);

	if (isNew) {
		var tr = SV_Trace(self.s.origin, self.mins, self.maxs,
				self.monsterinfo.last_sighting, self,
				MASK_PLAYERSOLID);

		if (tr.fraction < 1) {
			VectorSubtract(self.goalentity.s.origin, self.s.origin, v);
			d1 = VectorLength(v);
			double center = tr.fraction;
			double d2 = d1 * ((center + 1) / 2);
			self.s.angles[YAW] = self.ideal_yaw = vectoyaw(v);
      List<double> v_forward = [0,0,0];
      List<double> v_right = [0,0,0];
			AngleVectors(self.s.angles, v_forward, v_right, null);

			v =  [d2, -16, 0];
      List<double> left_target = [0,0,0];
			G_ProjectSource(self.s.origin, v, v_forward, v_right, left_target);
			tr = SV_Trace(self.s.origin, self.mins, self.maxs, left_target,
					self, MASK_PLAYERSOLID);
			final left = tr.fraction;

			v = [ d2, 16, 0 ];
      List<double> right_target = [0,0,0];
			G_ProjectSource(self.s.origin, v, v_forward, v_right, right_target);
			tr = SV_Trace(self.s.origin, self.mins, self.maxs, right_target,
					self, MASK_PLAYERSOLID);
			final right = tr.fraction;

			center = (d1 * center) / d2;

			if ((left >= center) && (left > right)) {
				if (left < 1) {
					v = [ d2 * left * 0.5, -16, 0 ];
					G_ProjectSource(self.s.origin, v, v_forward,
							v_right, left_target);
				}

        self.monsterinfo.saved_goal.setAll(0, self.monsterinfo.last_sighting);
				self.monsterinfo.aiflags |= AI_PURSUE_TEMP;
				self.monsterinfo.aiflags |= AI_PURSUE_TEMP;
        self.monsterinfo.last_sighting.setAll(0, left_target);
				VectorSubtract(self.goalentity.s.origin, self.s.origin, v);
				self.s.angles[YAW] = self.ideal_yaw = vectoyaw(v);
			} else if ((right >= center) && (right > left)) {
				if (right < 1) {
					v = [ d2 * right * 0.5, 16, 0 ];
					G_ProjectSource(self.s.origin, v, v_forward, v_right,
							right_target);
				}

        self.monsterinfo.saved_goal.setAll(0, self.monsterinfo.last_sighting);
				self.monsterinfo.aiflags |= AI_PURSUE_TEMP;
        self.goalentity.s.origin.setAll(0, right_target);
        self.monsterinfo.last_sighting.setAll(0, right_target);
				VectorSubtract(self.goalentity.s.origin, self.s.origin, v);
				self.s.angles[YAW] = self.ideal_yaw = vectoyaw(v);
			}
		}
	}

	M_MoveToGoal(self, dist);

	G_FreeEdict(tempgoal);

	if (self != null) {
		self.goalentity = save;
	}
}
