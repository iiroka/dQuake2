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
 * Combat code like damage, death and so on.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/game/g_ai.dart';
import 'package:dQuakeWeb/game/g_items.dart';
import 'package:dQuakeWeb/game/g_utils.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_send.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'game.dart';

/*
 * Returns true if the inflictor can
 * directly damage the target.  Used for
 * explosions and melee attacks.
 */
bool CanDamage(edict_t targ, edict_t inflictor) {
	// vec3_t dest;
	// trace_t trace;

	if (targ == null || inflictor == null) {
		return false;
	}

  List<double> dest = [0,0,0];

	/* bmodels need special checking because their origin is 0,0,0 */
	if (targ.movetype == movetype_t.MOVETYPE_PUSH) {
		VectorAdd(targ.absmin, targ.absmax, dest);
		VectorScale(dest, 0.5, dest);
		final trace = SV_Trace(inflictor.s.origin, [0,0,0], [0,0,0],
				dest, inflictor, MASK_SOLID);

		if (trace.fraction == 1.0)
		{
			return true;
		}

		if (trace.ent == targ)
		{
			return true;
		}

		return false;
	}

	var trace = SV_Trace(inflictor.s.origin, [0,0,0], [0,0,0],
			targ.s.origin, inflictor, MASK_SOLID);

	if (trace.fraction == 1.0)
	{
		return true;
	}

  dest.setAll(0, targ.s.origin);
	dest[0] += 15.0;
	dest[1] += 15.0;
  trace = SV_Trace(inflictor.s.origin, [0,0,0], [0,0,0],
			dest, inflictor, MASK_SOLID);

	if (trace.fraction == 1.0)
	{
		return true;
	}

  dest.setAll(0, targ.s.origin);
	dest[0] += 15.0;
	dest[1] -= 15.0;
	trace = SV_Trace(inflictor.s.origin, [0,0,0], [0,0,0],
			dest, inflictor, MASK_SOLID);

	if (trace.fraction == 1.0)
	{
		return true;
	}

  dest.setAll(0, targ.s.origin);
	dest[0] -= 15.0;
	dest[1] += 15.0;
	trace = SV_Trace(inflictor.s.origin, [0,0,0], [0,0,0],
			dest, inflictor, MASK_SOLID);

	if (trace.fraction == 1.0)
	{
		return true;
	}

  dest.setAll(0, targ.s.origin);
	dest[0] -= 15.0;
	dest[1] -= 15.0;
	trace = SV_Trace(inflictor.s.origin, [0,0,0], [0,0,0],
			dest, inflictor, MASK_SOLID);

	if (trace.fraction == 1.0)
	{
		return true;
	}

	return false;
}

Killed(edict_t targ, edict_t inflictor, edict_t attacker,
		int damage, List<double> point)
{
	if (targ == null || inflictor == null || attacker == null) {
		return;
	}

	if (targ.health < -999) {
		targ.health = -999;
	}

	targ.enemy = attacker;

	if ((targ.svflags & SVF_MONSTER) != 0 && (targ.deadflag != DEAD_DEAD) != 0) {
		if ((targ.monsterinfo.aiflags & AI_GOOD_GUY) == 0) {
			level.killed_monsters++;

	// 		if (coop->value && attacker->client) {
	// 			attacker->client->resp.score++;
	// 		}

	// 		/* medics won't heal monsters that they kill themselves */
	// 		if (attacker && attacker->classname && strcmp(attacker->classname, "monster_medic") == 0)
	// 		{
	// 			targ->owner = attacker;
	// 		}
		}
	}

	if ((targ.movetype == movetype_t.MOVETYPE_PUSH) ||
		(targ.movetype == movetype_t.MOVETYPE_STOP) ||
		(targ.movetype == movetype_t.MOVETYPE_NONE))
	{
		/* doors, triggers, etc */
		targ.die(targ, inflictor, attacker, damage, point);
		return;
	}

	if ((targ.svflags & SVF_MONSTER) != 0 && (targ.deadflag != DEAD_DEAD)) {
		targ.touch = null;
    print("monster_death_use ${targ.target} ${targ.deathtarget}");
		// monster_death_use(targ);
	}

  print("Die ${targ.classname}");
	targ.die(targ, inflictor, attacker, damage, point);
}

SpawnDamage(int type, List<double> origin, List<double> normal)
{
	PF_WriteByte(svc_ops_e.svc_temp_entity.index);
	PF_WriteByte(type);
	PF_WritePos(origin);
	PF_WriteDir(normal);
	SV_Multicast(origin, multicast_t.MULTICAST_PVS);
}

int CheckArmor(edict_t ent, List<double> point, List<double> normal, int damage,
		int te_sparks, int dflags) {

	if (ent == null) {
		return 0;
	}

	if (damage == 0) {
		return 0;
	}

	final client = ent.client as gclient_t;

	if (client == null) {
		return 0;
	}

	if ((dflags & DAMAGE_NO_ARMOR) != 0) {
		return 0;
	}

	int index = ArmorIndex(ent);
	if (index == 0) {
		return 0;
	}

	final armor = GetItemByIndex(index);

  int save;
	if ((dflags & DAMAGE_ENERGY) != 0) {
		save = ((armor.info as gitem_armor_t).energy_protection * damage).ceil();
	} else {
		save = ((armor.info as gitem_armor_t).normal_protection * damage).ceil();
	}

	if (save >= client.pers.inventory[index]) {
		save = client.pers.inventory[index];
	}

	if (save == 0) {
		return 0;
	}

	client.pers.inventory[index] -= save;
	SpawnDamage(te_sparks, point, normal);

	return save;
}

M_ReactToDamage(edict_t targ, edict_t attacker) {
	if (targ == null || attacker == null) {
		return;
	}

	if (targ.health <= 0) {
		return;
	}

	if ((attacker.client == null) && (attacker.svflags & SVF_MONSTER) == 0) {
		return;
	}

	if ((attacker == targ) || (attacker == targ.enemy)) {
		return;
	}

	/* if we are a good guy monster and our attacker is a player
	   or another good guy, do not get mad at them */
	if ((targ.monsterinfo.aiflags & AI_GOOD_GUY) != 0) {
		if (attacker.client != null || (attacker.monsterinfo.aiflags & AI_GOOD_GUY) != 0) {
			return;
		}
	}

	/* if attacker is a client, get mad at
	   them because he's good and we're not */
	if (attacker.client != null) {
		targ.monsterinfo.aiflags &= ~AI_SOUND_TARGET;

		/* this can only happen in coop (both new and old
		   enemies are clients)  only switch if can't see
		   the current enemy */
		if (targ.enemy != null && targ.enemy.client != null) {
			if (visible(targ, targ.enemy)) {
				targ.oldenemy = attacker;
				return;
			}

			targ.oldenemy = targ.enemy;
		}

		targ.enemy = attacker;

		if ((targ.monsterinfo.aiflags & AI_DUCKED) == 0) {
			FoundTarget(targ);
		}

		return;
	}

	/* it's the same base (walk/swim/fly) type and a
	   different classname and it's not a tank
	   (they spray too much), get mad at them */
	if (((targ.flags & (FL_FLY | FL_SWIM)) ==
		 (attacker.flags & (FL_FLY | FL_SWIM))) &&
		(targ.classname != attacker.classname) &&
		(attacker.classname != "monster_tank") &&
		(attacker.classname != "monster_supertank") &&
		(attacker.classname != "monster_makron") &&
		(attacker.classname != "monster_jorg"))
	{
		if (targ.enemy != null && targ.enemy.client != null)
		{
			targ.oldenemy = targ.enemy;
		}

		targ.enemy = attacker;

		if ((targ.monsterinfo.aiflags & AI_DUCKED) == 0) {
			FoundTarget(targ);
		}
	}
	/* if they *meant* to shoot us, then shoot back */
	else if (attacker.enemy == targ)
	{
		if (targ.enemy != null && targ.enemy.client != null)
		{
			targ.oldenemy = targ.enemy;
		}

		targ.enemy = attacker;

		if ((targ.monsterinfo.aiflags & AI_DUCKED) == 0)
		{
			FoundTarget(targ);
		}
	}
	/* otherwise get mad at whoever they are mad
	   at (help our buddy) unless it is us! */
	else if (attacker.enemy != null && (attacker.enemy != targ))
	{
		if (targ.enemy != null && targ.enemy.client != null)
		{
			targ.oldenemy = targ.enemy;
		}

		targ.enemy = attacker.enemy;

		if ((targ.monsterinfo.aiflags & AI_DUCKED) == 0)
		{
			FoundTarget(targ);
		}
	}
}

T_Damage(edict_t targ, edict_t inflictor, edict_t attacker,
		List<double> dir, List<double> point, List<double> normal, int damage,
		int knockback, int dflags, int mod) {

	if (targ == null || inflictor == null || attacker == null) {
		return;
	}

	if (targ.takedamage == 0) {
		return;
	}

	/* friendly fire avoidance if enabled you
	   can't hurt teammates (but you can hurt
	   yourself) knockback still occurs */
	if ((targ != attacker) && ((deathmatch.boolean &&
		  (dmflags.integer & (DF_MODELTEAMS | DF_SKINTEAMS)) != 0) ||
		 coop.boolean)) {
	// 	if (OnSameTeam(targ, attacker))
	// 	{
	// 		if ((int)(dmflags->value) & DF_NO_FRIENDLY_FIRE)
	// 		{
	// 			damage = 0;
	// 		}
	// 		else
	// 		{
	// 			mod |= MOD_FRIENDLY_FIRE;
	// 		}
	// 	}
	}

	meansOfDeath = mod;

	/* easy mode takes half damage */
	if ((skill.integer == 0) && !deathmatch.boolean && targ.client != null) {
		damage = damage ~/ 2;

		if (damage == 0) {
			damage = 1;
		}
	}

	var client = targ.client as gclient_t;
  int te_sparks;
	if ((dflags & DAMAGE_BULLET) != 0) {
		te_sparks = temp_event_t.TE_BULLET_SPARKS.index;
	} else {
		te_sparks = temp_event_t.TE_SPARKS.index;
	}

	VectorNormalize(dir);

	/* bonus damage for suprising a monster */
	// if (!(dflags & DAMAGE_RADIUS) && (targ->svflags & SVF_MONSTER) &&
	// 	(attacker->client) && (!targ->enemy) && (targ->health > 0))
	// {
	// 	damage *= 2;
	// }

	if ((targ.flags & FL_NO_KNOCKBACK) != 0) {
		knockback = 0;
	}

	/* figure momentum add */
	if ((dflags & DAMAGE_NO_KNOCKBACK) == 0) {
	// 	if ((knockback) && (targ->movetype != MOVETYPE_NONE) &&
	// 		(targ->movetype != MOVETYPE_BOUNCE) &&
	// 		(targ->movetype != MOVETYPE_PUSH) &&
	// 		(targ->movetype != MOVETYPE_STOP))
	// 	{
	// 		vec3_t kvel;
	// 		float mass;

	// 		if (targ->mass < 50)
	// 		{
	// 			mass = 50;
	// 		}
	// 		else
	// 		{
	// 			mass = targ->mass;
	// 		}

	// 		if (targ->client && (attacker == targ))
	// 		{
	// 			/* This allows rocket jumps */
	// 			VectorScale(dir, 1600.0 * (float)knockback / mass, kvel);
	// 		}
	// 		else
	// 		{
	// 			VectorScale(dir, 500.0 * (float)knockback / mass, kvel);
	// 		}

	// 		VectorAdd(targ->velocity, kvel, targ->velocity);
	// 	}
	}

	int take = damage;
	int save = 0;

	// /* check for godmode */
	// if ((targ->flags & FL_GODMODE) && !(dflags & DAMAGE_NO_PROTECTION))
	// {
	// 	take = 0;
	// 	save = damage;
	// 	SpawnDamage(te_sparks, point, normal);
	// }

	// /* check for invincibility */
	// if ((client && (client->invincible_framenum > level.framenum)) &&
	// 	!(dflags & DAMAGE_NO_PROTECTION))
	// {
	// 	if (targ->pain_debounce_time < level.time)
	// 	{
	// 		gi.sound(targ, CHAN_ITEM, gi.soundindex(
	// 					"items/protect4.wav"), 1, ATTN_NORM, 0);
	// 		targ->pain_debounce_time = level.time + 2;
	// 	}

	// 	take = 0;
	// 	save = damage;
	// }

	// psave = CheckPowerArmor(targ, point, normal, take, dflags);
	// take -= psave;

	var asave = CheckArmor(targ, point, normal, take, te_sparks, dflags);
	take -= asave;

	/* treat cheat/powerup savings the same as armor */
	asave += save;

	/* team damage avoidance */
	// if (!(dflags & DAMAGE_NO_PROTECTION) && false)
	// {
	// 	return;
	// }

	/* do the damage */
	if (take != 0) {
		if ((targ.svflags & SVF_MONSTER) != 0 || client != null)
		{
			SpawnDamage(temp_event_t.TE_BLOOD.index, point, normal);
		}
		else
		{
			SpawnDamage(te_sparks, point, normal);
		}

		targ.health = targ.health - take;

		if (targ.health <= 0) {
			if ((targ.svflags & SVF_MONSTER) != 0 || (client != null)) {
				targ.flags |= FL_NO_KNOCKBACK;
			}
			Killed(targ, inflictor, attacker, take, point);
			return;
		}
	}

	if ((targ.svflags & SVF_MONSTER) != 0) {
		M_ReactToDamage(targ, attacker);

		if ((targ.monsterinfo.aiflags & AI_DUCKED) == 0 && (take != 0)) {
			targ.pain(targ, attacker, knockback.toDouble(), take);

			/* nightmare mode monsters don't go into pain frames often */
			if (skill.integer == 3) {
				targ.pain_debounce_time = level.time + 5;
			}
		}
	} else if (client != null) {
		if ((targ.flags & FL_GODMODE) == 0 && take != 0) {
			targ.pain(targ, attacker, knockback.toDouble(), take);
		}
	} else if (take != 0) {
		if (targ.pain != null) {
			targ.pain(targ, attacker, knockback.toDouble(), take);
		}
	}

	/* add to the damage inflicted on a player this frame
	   the total will be turned into screen blends and view
	   angle kicks at the end of the frame */
	if (client != null) {
	// 	client->damage_parmor += psave;
		client.damage_armor += asave;
		client.damage_blood += take;
		client.damage_knockback += knockback;
    client.damage_from.setAll(0, point);
	}
}

T_RadiusDamage(edict_t inflictor, edict_t attacker, double damage,
		edict_t ignore, double radius, int mod)
{

	if (inflictor == null || attacker == null) {
		return;
	}

  edict_t ent;
	while ((ent = findradius(ent, inflictor.s.origin, radius)) != null) {
		if (ent == ignore) {
			continue;
		}

		if (ent.takedamage == 0) {
			continue;
		}

    List<double> v = [0,0,0];
		VectorAdd(ent.mins, ent.maxs, v);
		VectorMA(ent.s.origin, 0.5, v, v);
		VectorSubtract(inflictor.s.origin, v, v);
		double points = damage - 0.5 * VectorLength(v);

		if (ent == attacker)
		{
			points = points * 0.5;
		}

		if (points > 0)
		{
			if (CanDamage(ent, inflictor))
			{
        List<double> dir = [0,0,0];
				VectorSubtract(ent.s.origin, inflictor.s.origin, dir);
				T_Damage(ent, inflictor, attacker, dir, inflictor.s.origin,
						[0,0,0], points.toInt(), points.toInt(), DAMAGE_RADIUS,
						mod);
			}
		}
	}
}
