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
 * Player weapons.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_send.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import '../game.dart';
import '../g_items.dart';
import '../g_utils.dart';
import '../g_weapon.dart';
import '../monster/misc/player.dart';

bool _is_quad = false;
int _is_silenced = 0;

P_ProjectSource(gclient_t client, List<double> point, List<double> distance,
		List<double> forward, List<double> right, List<double> result)
{

	if (client == null) {
		return;
	}

  List<double> _distance = List.generate(3, (i) => distance[i]);

	if (client.pers.hand == LEFT_HANDED) {
		_distance[1] *= -1;
	}
	else if (client.pers.hand == CENTER_HANDED)
	{
		_distance[1] = 0;
	}

	G_ProjectSource(point, _distance, forward, right, result);
}

/*
 * Each player can have two noise objects associated with it:
 * a personal noise (jumping, pain, weapon firing), and a weapon
 * target noise (bullet wall impacts)
 *
 * Monsters that don't directly see the player can move
 * to a noise in hopes of seeing the player from there.
 */
PlayerNoise(edict_t who, List<double> where, int type) {

	if (who == null) {
		return;
	}

	if (type == PNOISE_WEAPON)
	{
		if ((who.client as gclient_t).silencer_shots > 0) {
			(who.client as gclient_t).silencer_shots--;
			return;
		}
	}

	if (deathmatch.boolean) {
		return;
	}

	if ((who.flags & FL_NOTARGET) != 0) {
		return;
	}

	if (who.mynoise == null) {
		var noise = G_Spawn();
		noise.classname = "player_noise";
		noise.mins = [ -8, -8, -8];
		noise.maxs = [ 8, 8, 8];
		noise.owner = who;
		noise.svflags = SVF_NOCLIENT;
		who.mynoise = noise;

		noise = G_Spawn();
		noise.classname = "player_noise";
		noise.mins = [ -8, -8, -8];
		noise.maxs = [ 8, 8, 8];
		noise.owner = who;
		noise.svflags = SVF_NOCLIENT;
		who.mynoise2 = noise;
	}

  edict_t noise;
	if ((type == PNOISE_SELF) || (type == PNOISE_WEAPON))
	{
		if (level.framenum <= (level.sound_entity_framenum + 3))
		{
			return;
		}

		noise = who.mynoise;
		level.sound_entity = noise;
		level.sound_entity_framenum = level.framenum;
	}
	else
	{
		if (level.framenum <= (level.sound2_entity_framenum + 3))
		{
			return;
		}

		noise = who.mynoise2;
		level.sound2_entity = noise;
		level.sound2_entity_framenum = level.framenum;
	}

  noise.s.origin.setAll(0, where);
	VectorSubtract(where, noise.maxs, noise.absmin);
	VectorAdd(where, noise.maxs, noise.absmax);
	noise.last_sound_time = level.time;
	SV_LinkEdict(noise);
}


/*
 * The old weapon has been dropped all
 * the way, so make the new one current
 */
ChangeWeapon(edict_t ent) {
	int i;

	if (ent == null) {
		return;
	}

  final client = ent.client as gclient_t;

	// if (client.grenade_time != 0)
	// {
	// 	client.grenade_time = level.time;
	// 	client.weapon_sound = 0;
	// 	weapon_grenade_fire(ent, false);
	// 	client.grenade_time = 0;
	// }

	client.pers.lastweapon = client.pers.weapon;
	client.pers.weapon = client.newweapon;
	client.newweapon = null;
  client.machinegun_shots = 0;

	/* set visible model */
	if (ent.s.modelindex == 255)
	{
		if (client.pers.weapon != null) {
			i = ((client.pers.weapon.weapmodel & 0xff) << 8);
		} else {
			i = 0;
		}

		ent.s.skinnum = (ent.index - 1) | i;
	}

	if (client.pers.weapon != null && client.pers.weapon.ammo != null)
	{
		client.ammo_index = FindItem(client.pers.weapon.ammo).index;
	}
	else
	{
		client.ammo_index = 0;
	}

	if (client.pers.weapon == null)
	{
		/* dead */
		client.ps.gunindex = 0;
		return;
	}

	client.weaponstate = weaponstate_t.WEAPON_ACTIVATING;
	client.ps.gunframe = 0;
	client.ps.gunindex = SV_ModelIndex(client.pers.weapon.view_model);

	client.anim_priority = ANIM_PAIN;

	if ((client.ps.pmove.pm_flags & PMF_DUCKED) != 0) {
		ent.s.frame = FRAME_crpain1;
		client.anim_end = FRAME_crpain4;
	}
	else
	{
		ent.s.frame = FRAME_pain301;
		client.anim_end = FRAME_pain304;
	}
}

/*
 * Called by ClientBeginServerFrame and ClientThink
 */
Think_Weapon(edict_t ent) {
	if (ent == null) {
		return;
	}

  final client = ent.client as gclient_t;

	/* if just died, put the weapon away */
	if (ent.health < 1) {
		client.newweapon = null;
		ChangeWeapon(ent);
	}

	/* call active weapon think routine */
	if (client.pers.weapon != null && client.pers.weapon.weaponthink != null) {
		_is_quad = (client.quad_framenum > level.framenum);

	// 	if (ent->client->silencer_shots) {
	// 		is_silenced = MZ_SILENCED;
	// 	} else {
			_is_silenced = 0;
	// 	}

		client.pers.weapon.weaponthink(ent);
	}
}

/*
 * Make the weapon ready if there is ammo
 */
Use_Weapon(edict_t ent, gitem_t item) {
	// int ammo_index;
	// gitem_t *ammo_item;

	if (ent == null || item == null) {
		return;
	}
  print("Use_Weapon");

  final client = ent.client as gclient_t;

	/* see if we're already using it */
	if (item == client.pers.weapon)
	{
		return;
	}

	if (item.ammo != null && !g_select_empty.boolean && (item.flags & IT_AMMO) == 0)
	{
		final ammo_item = FindItem(item.ammo);
		final ammo_index = ammo_item.index;

		if (client.pers.inventory[ammo_index] == 0) {
			PF_cprintf(ent, PRINT_HIGH, "No ${ammo_item.pickup_name} for ${item.pickup_name}.\n");
			return;
		}

		if (client.pers.inventory[ammo_index] < item.quantity) {
			PF_cprintf(ent, PRINT_HIGH, "Not enough ${ammo_item.pickup_name} for ${item.pickup_name}.\n");
			return;
		}
	}

	/* change to this weapon when down */
	client.newweapon = item;
  print("Use_Weapon - done");
}

/*
 * A generic function to handle
 * the basics of weapon thinking
 */
Weapon_Generic(edict_t ent, int FRAME_ACTIVATE_LAST, int FRAME_FIRE_LAST,
		int FRAME_IDLE_LAST, int FRAME_DEACTIVATE_LAST, List<int> pause_frames,
		List<int> fire_frames, void Function(edict_t) fire) {

  final FRAME_FIRE_FIRST = (FRAME_ACTIVATE_LAST + 1);
  final FRAME_IDLE_FIRST = (FRAME_FIRE_LAST + 1);
  final FRAME_DEACTIVATE_FIRST = (FRAME_IDLE_LAST + 1);

	if (ent == null || fire_frames == null || fire == null) {
		return;
	}

	if (ent.deadflag != 0 || (ent.s.modelindex != 255)) /* VWep animations screw up corpses */
	{
		return;
	}

  final client = ent.client as gclient_t;

	if (client.weaponstate == weaponstate_t.WEAPON_DROPPING)
	{
		if (client.ps.gunframe == FRAME_DEACTIVATE_LAST)
		{
			ChangeWeapon(ent);
			return;
		}
		else if ((FRAME_DEACTIVATE_LAST - client.ps.gunframe) == 4)
		{
			client.anim_priority = ANIM_REVERSE;

			if ((client.ps.pmove.pm_flags & PMF_DUCKED) != 0)
			{
				ent.s.frame = FRAME_crpain4 + 1;
				client.anim_end = FRAME_crpain1;
			}
			else
			{
				ent.s.frame = FRAME_pain304 + 1;
				client.anim_end = FRAME_pain301;
			}
		}

		client.ps.gunframe++;
		return;
	}

	if (client.weaponstate == weaponstate_t.WEAPON_ACTIVATING)
	{
		if (client.ps.gunframe == FRAME_ACTIVATE_LAST)
		{
			client.weaponstate = weaponstate_t.WEAPON_READY;
			client.ps.gunframe = FRAME_IDLE_FIRST;
			return;
		}

		client.ps.gunframe++;
		return;
	}

	if ((client.newweapon != null) && (client.weaponstate != weaponstate_t.WEAPON_FIRING))
	{
		client.weaponstate = weaponstate_t.WEAPON_DROPPING;
		client.ps.gunframe = FRAME_DEACTIVATE_FIRST;

		if ((FRAME_DEACTIVATE_LAST - FRAME_DEACTIVATE_FIRST) < 4)
		{
			client.anim_priority = ANIM_REVERSE;

			if ((client.ps.pmove.pm_flags & PMF_DUCKED) != 0)
			{
				ent.s.frame = FRAME_crpain4 + 1;
				client.anim_end = FRAME_crpain1;
			}
			else
			{
				ent.s.frame = FRAME_pain304 + 1;
				client.anim_end = FRAME_pain301;
			}
		}

		return;
	}

	if (client.weaponstate == weaponstate_t.WEAPON_READY)
	{
		if (((client.latched_buttons |
			  client.buttons) & BUTTON_ATTACK) != 0)
		{
			client.latched_buttons &= ~BUTTON_ATTACK;

			if ((client.ammo_index == 0) ||
				(client.pers.inventory[client.ammo_index] >=
				 client.pers.weapon.quantity))
			{
				client.ps.gunframe = FRAME_FIRE_FIRST;
				client.weaponstate = weaponstate_t.WEAPON_FIRING;

				/* start the animation */
				client.anim_priority = ANIM_ATTACK;

				if ((client.ps.pmove.pm_flags & PMF_DUCKED) != 0)
				{
					ent.s.frame = FRAME_crattak1 - 1;
					client.anim_end = FRAME_crattak9;
				}
				else
				{
					ent.s.frame = FRAME_attack1 - 1;
					client.anim_end = FRAME_attack8;
				}
			}
			else
			{
				if (level.time >= ent.pain_debounce_time)
				{
					// gi.sound(ent, CHAN_VOICE, gi.soundindex(
					// 			"weapons/noammo.wav"), 1, ATTN_NORM, 0);
					ent.pain_debounce_time = level.time + 1;
				}

				// NoAmmoWeaponChange(ent);
			}
		}
		else
		{
			if (client.ps.gunframe == FRAME_IDLE_LAST)
			{
				client.ps.gunframe = FRAME_IDLE_FIRST;
				return;
			}

			if (pause_frames != null)
			{
				for (int n = 0; n < pause_frames.length; n++)
				{
					if (client.ps.gunframe == pause_frames[n])
					{
						if ((randk() & 15) != 0)
						{
							return;
						}
					}
				}
			}

			client.ps.gunframe++;
			return;
		}
	}

	if (client.weaponstate == weaponstate_t.WEAPON_FIRING)
	{
    int n;
		for (n = 0; n < fire_frames.length; n++)
		{
			if (client.ps.gunframe == fire_frames[n])
			{
				// if (client.quad_framenum > level.framenum)
				// {
				// 	gi.sound(ent, CHAN_ITEM, gi.soundindex(
				// 				"items/damage3.wav"), 1, ATTN_NORM, 0);
				// }

				fire(ent);
				break;
			}
		}

		if (n >= fire_frames.length) {
			client.ps.gunframe++;
		}

		if (client.ps.gunframe == FRAME_IDLE_FIRST + 1)
		{
			client.weaponstate = weaponstate_t.WEAPON_READY;
		}
	}
}

/* ====================================================================== */

/* BLASTER / HYPERBLASTER */

Blaster_Fire(edict_t ent, List<double> g_offset, int damage,
		bool hyper, int effect) {
	// vec3_t forward, right;
	// vec3_t start;
	// vec3_t offset;

	if (ent == null) {
		return;
	}

	if (_is_quad) {
		damage *= 4;
	}
  final client = ent.client as gclient_t;

  List<double> forward = [0,0,0];
  List<double> right = [0,0,0];
  List<double> start = [0,0,0];
	AngleVectors(client.v_angle, forward, right, null);
	List<double> offset = [ 24, 8, (ent.viewheight - 8).toDouble() ];
	VectorAdd(offset, g_offset, offset);
	P_ProjectSource(client, ent.s.origin, offset, forward, right, start);

	VectorScale(forward, -2, client.kick_origin);
	client.kick_angles[0] = -1;

	fire_blaster(ent, start, forward, damage, 1000, effect, hyper);

	/* send muzzle flash */
	PF_WriteByte(svc_muzzleflash);
	PF_WriteShort(ent.index);

	if (hyper) {
		PF_WriteByte(MZ_HYPERBLASTER | _is_silenced);
	} else {
		PF_WriteByte(MZ_BLASTER | _is_silenced);
	}

	SV_Multicast(ent.s.origin, multicast_t.MULTICAST_PVS);

	PlayerNoise(ent, start, PNOISE_WEAPON);
}


Weapon_Blaster_Fire(edict_t ent) {
	int damage;

	if (ent == null) {
		return;
	}

	if (deathmatch.boolean) {
		damage = 15;
	} else {
		damage = 10;
	}

	Blaster_Fire(ent, [0,0,0], damage, false, EF_BLASTER);
	ent.client.ps.gunframe++;
}

Weapon_Blaster(edict_t ent) {
	const _pause_frames = [19, 32, 0];
	const _fire_frames = [5, 0];

	if (ent == null) {
		return;
	}

	Weapon_Generic(ent, 4, 8, 52, 55, _pause_frames,
			_fire_frames, Weapon_Blaster_Fire);
}