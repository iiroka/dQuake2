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
import '../game.dart';

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
		// ChangeWeapon(ent);
	}

	/* call active weapon think routine */
	// if (client.pers.weapon != null && client.pers.weapon.weaponthink != null) {
	// 	is_quad = (ent->client->quad_framenum > level.framenum);

	// 	if (ent->client->silencer_shots) {
	// 		is_silenced = MZ_SILENCED;
	// 	} else {
	// 		is_silenced = 0;
	// 	}

	// 	ent->client->pers.weapon->weaponthink(ent);
	// }
}