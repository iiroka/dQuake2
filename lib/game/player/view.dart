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
import 'package:dQuakeWeb/shared/shared.dart';
import '../game.dart';

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
 * Called for each player at the end of
 * the server frame and right after spawning
 */
ClientEndServerFrame(edict_t ent) {
	// float bobtime;
	// int i;

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

	// /* burn from lava, etc */
	// P_WorldEffects();

	// /* set model angles from view angles so other things in
	//    the world can tell which direction you are looking */
	// if (ent->client->v_angle[PITCH] > 180)
	// {
	// 	ent->s.angles[PITCH] = (-360 + ent->client->v_angle[PITCH]) / 3;
	// }
	// else
	// {
	// 	ent->s.angles[PITCH] = ent->client->v_angle[PITCH] / 3;
	// }

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
	// P_FallingDamage(ent);

	/* apply all the damage taken this frame */
	// P_DamageFeedback(ent);

	/* determine the view offsets */
	// SV_CalcViewOffset(ent);

	/* determine the gun offsets */
	// SV_CalcGunOffset(ent);

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
	// 	G_SetStats(ent);
	// }

	// G_CheckChaseStats(ent);

	// G_SetClientEvent(ent);

	// G_SetClientEffects(ent);

	// G_SetClientSound(ent);

	// G_SetClientFrame(ent);

	// VectorCopy(ent->velocity, ent->client->oldvelocity);
	// VectorCopy(ent->client->ps.viewangles, ent->client->oldviewangles);

	/* clear weapon kicks */
	// VectorClear(ent->client->kick_origin);
	// VectorClear(ent->client->kick_angles);

	if ((level.framenum & 31) == 0) {
	// 	/* if the scoreboard is up, update it */
	// 	if (ent->client->showscores)
	// 	{
	// 		DeathmatchScoreboardMessage(ent, ent->enemy);
	// 		gi.unicast(ent, false);
	// 	}

	// 	/* if the help computer is up, update it */
	// 	if (ent->client->showhelp)
	// 	{
	// 		ent->client->pers.helpchanged = 0;
	// 		HelpComputerMessage(ent);
	// 		gi.unicast(ent, false);
	// 	}
	}

	// /* if the inventory is up, update it */
	// if (ent->client->showinventory)
	// {
	// 	InventoryMessage(ent);
	// 	gi.unicast(ent, false);
	// }
}