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
 * The "camera" through which the player looks into the game.
 *
 * =======================================================================
 */
import 'dart:math';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'hud.dart' show InventoryMessage, G_SetStats;
import '../game.dart';
import '../g_combat.dart';
import '../monster/misc/player.dart';

edict_t _current_player;
gclient_t _current_client;

List<double> _forward = [0,0,0];
List<double> _right = [0,0,0];
List<double> _up = [0,0,0];
double xyspeed = 0;

double bobmove = 0;
int bobcycle = 0; /* odd cycles are right foot going forward */
double bobfracsin = 0; /* sin(bobfrac*M_PI) */

double SV_CalcRoll(List<double> angles, List<double> velocity) {

	double side = DotProduct(velocity, _right);
	double sign = side < 0 ? -1 : 1;
	side = side.abs();

	double value = sv_rollangle.value;

	if (side < sv_rollspeed.value) {
		side = side * value / sv_rollspeed.value;
	} else {
		side = value;
	}

	return side * sign;
}

/*
 * Handles color blends and view kicks
 */
int _feedback_i = 0;

P_DamageFeedback(edict_t player) {

	const List<double> _power_color = [0.0, 1.0, 0.0];
	const List<double> _acolor = [1.0, 1.0, 1.0];
	const List<double> _bcolor = [1.0, 0.0, 0.0];

	if (player == null) {
		return;
	}

	final client = player.client as gclient_t;

	/* flash the backgrounds behind the status numbers */
	client.ps.stats[STAT_FLASHES] = 0;

	if (client.damage_blood != 0) {
		client.ps.stats[STAT_FLASHES] |= 1;
	}

	if (client.damage_armor != 0 && (player.flags & FL_GODMODE) == 0 &&
		(client.invincible_framenum <= level.framenum))
	{
		client.ps.stats[STAT_FLASHES] |= 2;
	}

	/* total points of damage shot at the player this frame */
	double count = (client.damage_blood + client.damage_armor + client.damage_parmor).toDouble();
	if (count == 0) {
		return; /* didn't take any damage */
	}

	/* start a pain animation if still in the player model */
	if ((client.anim_priority < ANIM_PAIN) && (player.s.modelindex == 255)) {

		client.anim_priority = ANIM_PAIN;

		if ((client.ps.pmove.pm_flags & PMF_DUCKED) != 0)
		{
			player.s.frame = FRAME_crpain1 - 1;
			client.anim_end = FRAME_crpain4;
		}
		else
		{
			_feedback_i = (_feedback_i + 1) % 3;

			switch (_feedback_i)
			{
				case 0:
					player.s.frame = FRAME_pain101 - 1;
					client.anim_end = FRAME_pain104;
					break;
				case 1:
					player.s.frame = FRAME_pain201 - 1;
					client.anim_end = FRAME_pain204;
					break;
				case 2:
					player.s.frame = FRAME_pain301 - 1;
					client.anim_end = FRAME_pain304;
					break;
			}
		}
	}

	double realcount = count;
	if (count < 10) {
		count = 10; /* always make a visible effect */
	}

	/* play an apropriate pain sound */
	if ((level.time > player.pain_debounce_time) &&
		(player.flags & FL_GODMODE) == 0 &&
		(client.invincible_framenum <= level.framenum))
	{
		// r = 1 + (randk() & 1);
		// player.pain_debounce_time = level.time + 0.7;

		// if (player.health < 25)
		// {
		// 	l = 25;
		// }
		// else if (player.health < 50)
		// {
		// 	l = 50;
		// }
		// else if (player.health < 75)
		// {
		// 	l = 75;
		// }
		// else
		// {
		// 	l = 100;
		// }

		// gi.sound(player, CHAN_VOICE, gi.soundindex(va("*pain%i_%i.wav",
		// 						l, r)), 1, ATTN_NORM, 0);
	}

	/* the total alpha of the blend is always proportional to count */
	if (client.damage_alpha < 0) {
		client.damage_alpha = 0;
	}

	client.damage_alpha += count * 0.01;

	if (client.damage_alpha < 0.2)
	{
		client.damage_alpha = 0.2;
	}

	if (client.damage_alpha > 0.6)
	{
		client.damage_alpha = 0.6; /* don't go too saturated */
	}

	/* the color of the blend will vary based
	   on how much was absorbed by different armors */
	List<double> v = [0,0,0];

	if (client.damage_parmor != 0)
	{
		VectorMA(v, client.damage_parmor / realcount, _power_color, v);
	}

	if (client.damage_armor != 0)
	{
		VectorMA(v, client.damage_armor / realcount, _acolor, v);
	}

	if (client.damage_blood != 0)
	{
		VectorMA(v, client.damage_blood / realcount, _bcolor, v);
	}

  client.damage_blend.setAll(0, v);

	/* calculate view angle kicks */
	double kick = client.damage_knockback.abs().toDouble();

	if (kick != 0 && (player.health > 0)) /* kick of 0 means no view adjust at all */
	{
		kick = kick * 100 / player.health;

		if (kick < count * 0.5)
		{
			kick = count * 0.5;
		}

		if (kick > 50)
		{
			kick = 50;
		}

		VectorSubtract(client.damage_from, player.s.origin, v);
		VectorNormalize(v);

		double side = DotProduct(v, _right);
		client.v_dmg_roll = kick * side * 0.3;

		side = -DotProduct(v, _forward);
		client.v_dmg_pitch = kick * side * 0.3;

		client.v_dmg_time = level.time + DAMAGE_TIME;
	}

	/* clear totals */
	client.damage_blood = 0;
	client.damage_armor = 0;
	client.damage_parmor = 0;
	client.damage_knockback = 0;
}

/*
 * fall from 128: 400 = 160000
 * fall from 256: 580 = 336400
 * fall from 384: 720 = 518400
 * fall from 512: 800 = 640000
 * fall from 640: 960 =
 *
 * damage = deltavelocity*deltavelocity  * 0.0001
 */
SV_CalcViewOffset(edict_t ent) {

	/* base angles */
	var angles = ent.client.ps.kick_angles;

	/* if dead, fix the angle and don't add any kick */
	if (ent.deadflag != 0) {
    angles.fillRange(0, 3, 0);

		ent.client.ps.viewangles[ROLL] = 40;
		ent.client.ps.viewangles[PITCH] = -15;
		ent.client.ps.viewangles[YAW] = (ent.client as gclient_t).killer_yaw;
	} else {
		/* add angles based on weapon kick */
    angles.setAll(0, (ent.client as gclient_t).kick_angles);

		/* add angles based on damage kick */
		var ratio = ((ent.client as gclient_t).v_dmg_time - level.time) / DAMAGE_TIME;

		if (ratio < 0) {
			ratio = 0;
			(ent.client as gclient_t).v_dmg_pitch = 0;
			(ent.client as gclient_t).v_dmg_roll = 0;
		}

		angles[PITCH] += ratio * (ent.client as gclient_t).v_dmg_pitch;
		angles[ROLL] += ratio * (ent.client as gclient_t).v_dmg_roll;

		/* add pitch based on fall kick */
		ratio = ((ent.client as gclient_t).fall_time - level.time) / FALL_TIME;

		if (ratio < 0) {
			ratio = 0;
		}

		angles[PITCH] += ratio * (ent.client as gclient_t).fall_value;

		/* add angles based on velocity */
		var delta = DotProduct(ent.velocity, _forward);
		angles[PITCH] += delta * run_pitch.value;

		delta = DotProduct(ent.velocity, _right);
		angles[ROLL] += delta * run_roll.value;

		/* add angles based on bob */
		delta = bobfracsin * bob_pitch.value * xyspeed;

		if ((ent.client.ps.pmove.pm_flags & PMF_DUCKED) != 0) {
			delta *= 6; /* crouching */
		}

		angles[PITCH] += delta;
		delta = bobfracsin * bob_roll.value * xyspeed;

		if ((ent.client.ps.pmove.pm_flags & PMF_DUCKED) != 0) {
			delta *= 6; /* crouching */
		}

		if ((bobcycle & 1) != 0) {
			delta = -delta;
		}

		angles[ROLL] += delta;
	}

	/* base origin */
  List<double> v = [0,0,0];

	/* add view height */
	v[2] += ent.viewheight;

	/* add fall height */
	var ratio = ((ent.client as gclient_t).fall_time - level.time) / FALL_TIME;

	if (ratio < 0) {
		ratio = 0;
	}

	v[2] -= ratio * (ent.client as gclient_t).fall_value * 0.4;

	/* add bob height */
	var bob = bobfracsin * xyspeed * bob_up.value;

	if (bob > 6) {
		bob = 6;
	}

	v[2] += bob;

	/* add kick offset */
	VectorAdd(v, (ent.client as gclient_t).kick_origin, v);

	/* absolutely bound offsets
	   so the view can never be
	   outside the player box */
	if (v[0] < -14)
	{
		v[0] = -14;
	}
	else if (v[0] > 14)
	{
		v[0] = 14;
	}

	if (v[1] < -14)
	{
		v[1] = -14;
	}
	else if (v[1] > 14)
	{
		v[1] = 14;
	}

	if (v[2] < -22)
	{
		v[2] = -22;
	}
	else if (v[2] > 30)
	{
		v[2] = 30;
	}

  ent.client.ps.viewoffset.setAll(0, v);
}

SV_CalcGunOffset(edict_t ent) {

	if (ent == null) {
		return;
	}

	/* gun angles from bobbing */
	ent.client.ps.gunangles[ROLL] = xyspeed * bobfracsin * 0.005;
	ent.client.ps.gunangles[YAW] = xyspeed * bobfracsin * 0.01;

	if ((bobcycle & 1) != 0) {
		ent.client.ps.gunangles[ROLL] = -ent.client.ps.gunangles[ROLL];
		ent.client.ps.gunangles[YAW] = -ent.client.ps.gunangles[YAW];
	}

	ent.client.ps.gunangles[PITCH] = xyspeed * bobfracsin * 0.005;

	/* gun angles from delta movement */
	for (int i = 0; i < 3; i++) {
		double delta = (ent.client as gclient_t).oldviewangles[i] - ent.client.ps.viewangles[i];

		if (delta > 180)
		{
			delta -= 360;
		}

		if (delta < -180)
		{
			delta += 360;
		}

		if (delta > 45)
		{
			delta = 45;
		}

		if (delta < -45)
		{
			delta = -45;
		}

		if (i == YAW)
		{
			ent.client.ps.gunangles[ROLL] += 0.1 * delta;
		}

		ent.client.ps.gunangles[i] += 0.2 * delta;
	}

	/* gun height */
  ent.client.ps.gunoffset.fillRange(0, 3, 0);

	/* gun_x / gun_y / gun_z are development tools */
	for (int i = 0; i < 3; i++) {
		ent.client.ps.gunoffset[i] += _forward[i] * (gun_y.value);
		ent.client.ps.gunoffset[i] += _right[i] * gun_x.value;
		ent.client.ps.gunoffset[i] += _up[i] * (-gun_z.value);
	}
}

P_FallingDamage(edict_t ent) {
	// float delta;
	// int damage;
	// vec3_t dir;

	if (ent == null) {
		return;
	}

	if (ent.s.modelindex != 255) {
		return; /* not in the player model */
	}

	if (ent.movetype == movetype_t.MOVETYPE_NOCLIP) {
		return;
	}

  double delta;
	if (((ent.client as gclient_t).oldvelocity[2] < 0) &&
		(ent.velocity[2] > (ent.client as gclient_t).oldvelocity[2]) && (ent.groundentity == null)) {
		delta = (ent.client as gclient_t).oldvelocity[2];
	} else {
		if (ent.groundentity == null) {
			return;
		}

		delta = ent.velocity[2] - (ent.client as gclient_t).oldvelocity[2];
	}

	delta = delta * delta * 0.0001;

	/* never take falling damage if completely underwater */
	if (ent.waterlevel == 3) {
		return;
	}

	if (ent.waterlevel == 2) {
		delta *= 0.25;
	}

	if (ent.waterlevel == 1) {
		delta *= 0.5;
	}

	if (delta < 1) {
		return;
	}

	if (delta < 15) {
		ent.s.event = entity_event_t.EV_FOOTSTEP.index;
		return;
	}

	(ent.client as gclient_t).fall_value = delta * 0.5;

	if ((ent.client as gclient_t).fall_value > 40) {
		(ent.client as gclient_t).fall_value = 40;
	}

	(ent.client as gclient_t).fall_time = level.time + FALL_TIME;

	if (delta > 30) {
		if (ent.health > 0) {
			if (delta >= 55) {
				ent.s.event = entity_event_t.EV_FALLFAR.index;
			} else {
				ent.s.event = entity_event_t.EV_FALL.index;
			}
		}

		ent.pain_debounce_time = level.time; /* no normal pain sound */
		int damage = (delta - 30) ~/ 2;

		if (damage < 1) {
			damage = 1;
		}

		List<double> dir = [0, 0, 1];

		if (!deathmatch.boolean || (dmflags.integer & DF_NO_FALLING) == 0) {
			T_Damage(ent, g_edicts[0], g_edicts[0], dir, ent.s.origin,
					[0,0,0], damage, 0, 0, MOD_FALLING);
		}
	}
	else
	{
		ent.s.event = entity_event_t.EV_FALLSHORT.index;
		return;
	}
}

G_SetClientEvent(edict_t ent) {
	if (ent == null) {
		return;
	}

	if (ent.s.event != 0) {
		return;
	}

	if (ent.groundentity != 0 && (xyspeed > 225)) {
		if ((_current_client.bobtime + bobmove).toInt() != bobcycle) {
			ent.s.event = entity_event_t.EV_FOOTSTEP.index;
		}
	}
}

G_SetClientFrame(edict_t ent) {

	if (ent == null) {
		return;
	}

	if (ent.s.modelindex != 255) {
		return; /* not in the player model */
	}

	var client = ent.client as gclient_t;

  bool duck;
	if ((client.ps.pmove.pm_flags & PMF_DUCKED) != 0) {
		duck = true;
	} else {
		duck = false;
	}

  bool run;
	if (xyspeed != 0) {
		run = true;
	} else {
		run = false;
	}

	/* check for stand/duck and stop/go transitions */
	if ((duck != client.anim_duck) && (client.anim_priority < ANIM_DEATH)) {
	} else if ((run != client.anim_run) && (client.anim_priority == ANIM_BASIC)) {
	} else if (ent.groundentity == null && (client.anim_priority <= ANIM_WAVE)) {
	} else {

    if (client.anim_priority == ANIM_REVERSE) {
      if (ent.s.frame > client.anim_end) {
        ent.s.frame--;
        return;
      }
    } else if (ent.s.frame < client.anim_end) {
      /* continue an animation */
      ent.s.frame++;
      return;
    }

    if (client.anim_priority == ANIM_DEATH) {
      return; /* stay there */
    }

    if (client.anim_priority == ANIM_JUMP) {
      if (ent.groundentity == null) {
        return; /* stay there */
      }

      (ent.client as gclient_t).anim_priority = ANIM_WAVE;
      ent.s.frame = FRAME_jump3;
      (ent.client as gclient_t).anim_end = FRAME_jump6;
      return;
    }
  }

	/* return to either a running or standing frame */
	client.anim_priority = ANIM_BASIC;
	client.anim_duck = duck;
	client.anim_run = run;

	if (ent.groundentity == null) {
		client.anim_priority = ANIM_JUMP;

		if (ent.s.frame != FRAME_jump2) {
			ent.s.frame = FRAME_jump1;
		}

		client.anim_end = FRAME_jump2;
	} else if (run) {
		/* running */
		if (duck) {
			ent.s.frame = FRAME_crwalk1;
			client.anim_end = FRAME_crwalk6;
		} else {
			ent.s.frame = FRAME_run1;
			client.anim_end = FRAME_run6;
		}
	} else {
		/* standing */
		if (duck) {
			ent.s.frame = FRAME_crstnd01;
			client.anim_end = FRAME_crstnd19;
		} else {
			ent.s.frame = FRAME_stand01;
			client.anim_end = FRAME_stand40;
		}
	}
}

/*
 * Called for each player at the end of
 * the server frame and right after spawning
 */
ClientEndServerFrame(edict_t ent) {

	if (ent == null) {
		return;
	}

	_current_player = ent;
	_current_client = ent.client;

	/* If the origin or velocity have changed since ClientThink(),
	   update the pmove values. This will happen when the client
	   is pushed by a bmodel or kicked by an explosion.
	   If it wasn't updated here, the view position would lag a frame
	   behind the body position when pushed -- "sinking into plats" */
	for (int i = 0; i < 3; i++) {
		_current_client.ps.pmove.origin[i] = (ent.s.origin[i] * 8.0).toInt();
		_current_client.ps.pmove.velocity[i] = (ent.velocity[i] * 8.0).toInt();
	}

	/* If the end of unit layout is displayed, don't give
	   the player any normal movement attributes */
	// if (level.intermissiontime)
	// {
	// 	current_client->ps.blend[3] = 0;
	// 	current_client->ps.fov = 90;
	// 	G_SetStats(ent);
	// 	return;
	// }

	AngleVectors((ent.client as gclient_t).v_angle, _forward, _right, _up);

	/* burn from lava, etc */
	// P_WorldEffects();

	/* set model angles from view angles so other things in
	   the world can tell which direction you are looking */
	if ((ent.client as gclient_t).v_angle[PITCH] > 180)
	{
		ent.s.angles[PITCH] = (-360 + (ent.client as gclient_t).v_angle[PITCH]) / 3;
	}
	else
	{
		ent.s.angles[PITCH] = (ent.client as gclient_t).v_angle[PITCH] / 3;
	}

	ent.s.angles[YAW] = (ent.client as gclient_t).v_angle[YAW];
	ent.s.angles[ROLL] = 0;
	ent.s.angles[ROLL] = SV_CalcRoll(ent.s.angles, ent.velocity) * 4;

	/* calculate speed and cycle to be used for
	   all cyclic walking effects */
	xyspeed = sqrt(ent.velocity[0] * ent.velocity[0] + ent.velocity[1] * ent.velocity[1]);

	if (xyspeed < 5) {
		bobmove = 0;
		_current_client.bobtime = 0; /* start at beginning of cycle again */
	} else if (ent.groundentity != null) {
		/* so bobbing only cycles when on ground */
		if (xyspeed > 210) {
			bobmove = 0.25;
		} else if (xyspeed > 100) {
			bobmove = 0.125;
		} else {
			bobmove = 0.0625;
		}
	}

	double bobtime = (_current_client.bobtime += bobmove);

	if ((_current_client.ps.pmove.pm_flags & PMF_DUCKED) != 0) {
		bobtime *= 4;
	}

	bobcycle = bobtime.toInt();
	bobfracsin = (sin(bobtime * pi)).abs();

	/* detect hitting the floor */
	P_FallingDamage(ent);

	/* apply all the damage taken this frame */
	P_DamageFeedback(ent);

	/* determine the view offsets */
	SV_CalcViewOffset(ent);

	/* determine the gun offsets */
	SV_CalcGunOffset(ent);

	/* determine the full screen color blend
	   must be after viewoffset, so eye contents
	   can be accurately determined */
	// SV_CalcBlend(ent);

	/* chase cam stuff */
	// if (ent->client->resp.spectator)
	// {
	// 	G_SetSpectatorStats(ent);
	// }
	// else
	// {
		G_SetStats(ent);
	// }

	// G_CheckChaseStats(ent);

	G_SetClientEvent(ent);

	// G_SetClientEffects(ent);

	// G_SetClientSound(ent);

	G_SetClientFrame(ent);

  (ent.client as gclient_t).oldvelocity.setAll(0, ent.velocity);
  (ent.client as gclient_t).oldviewangles.setAll(0, ent.client.ps.viewangles);

	/* clear weapon kicks */
  (ent.client as gclient_t).kick_origin.fillRange(0, 3, 0);
  (ent.client as gclient_t).kick_angles.fillRange(0, 3, 0);

	if ((level.framenum & 31) == 0) {
		/* if the scoreboard is up, update it */
	// 	if (ent->client->showscores)
	// 	{
	// 		DeathmatchScoreboardMessage(ent, ent->enemy);
	// 		gi.unicast(ent, false);
	// 	}

		/* if the help computer is up, update it */
	// 	if (ent->client->showhelp)
	// 	{
	// 		ent->client->pers.helpchanged = 0;
	// 		HelpComputerMessage(ent);
	// 		gi.unicast(ent, false);
	// 	}
	}

	/* if the inventory is up, update it */
	if ((ent.client as gclient_t).showinventory) {
		InventoryMessage(ent);
    PF_Unicast(ent, false);
	}
}