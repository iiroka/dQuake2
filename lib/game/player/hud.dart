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
 * HUD, deathmatch scoreboard, help computer and intermission stuff.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/game/g_items.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import '../game.dart';

InventoryMessage(edict_t ent) {

  if (ent == null) {
    return;
  }

  PF_WriteByte(svc_ops_e.svc_inventory.index);

  for (int i = 0; i < MAX_ITEMS; i++) {
    PF_WriteShort((ent.client as gclient_t).pers.inventory[i]);
  }
}

/* ======================================================================= */

G_SetStats(edict_t ent) {
	// gitem_t *item;
	// int index, cells = 0;
	// int power_armor_type;

	if (ent == null) {
		return;
	}

  final client = ent.client as gclient_t;

	/* health */
	client.ps.stats[STAT_HEALTH_ICON] = level.pic_health;
	client.ps.stats[STAT_HEALTH] = ent.health;

	/* ammo */
	if (client.ammo_index == 0) {
		client.ps.stats[STAT_AMMO_ICON] = 0;
		client.ps.stats[STAT_AMMO] = 0;
	} else {
		final item = itemlist[client.ammo_index];
		client.ps.stats[STAT_AMMO_ICON] = SV_ImageIndex(item.icon);
		client.ps.stats[STAT_AMMO] = client.pers.inventory[client.ammo_index];
	}

	/* armor */
  int power_armor_type = 0;
  int cells = 0;
	// power_armor_type = PowerArmorType(ent);

	// if (power_armor_type) {
	// 	cells = ent->client->pers.inventory[ITEM_INDEX(FindItem("cells"))];

	// 	if (cells == 0)
	// 	{
	// 		/* ran out of cells for power armor */
	// 		ent->flags &= ~FL_POWER_ARMOR;
	// 		gi.sound(ent, CHAN_ITEM, gi.soundindex(
	// 						"misc/power2.wav"), 1, ATTN_NORM, 0);
	// 		power_armor_type = 0;
	// 	}
	// }

	int index = ArmorIndex(ent);

	if (power_armor_type != 0 && (index == 0 || (level.framenum & 8) != 0)) {
		/* flash between power armor and other armor icon */
		client.ps.stats[STAT_ARMOR_ICON] = SV_ImageIndex("i_powershield");
		client.ps.stats[STAT_ARMOR] = cells;
	} else if (index != 0) {
		final item = GetItemByIndex(index);
		client.ps.stats[STAT_ARMOR_ICON] = SV_ImageIndex(item.icon);
		client.ps.stats[STAT_ARMOR] = client.pers.inventory[index];
	} else {
		client.ps.stats[STAT_ARMOR_ICON] = 0;
		client.ps.stats[STAT_ARMOR] = 0;
	}

	/* pickup message */
	// if (level.time > ent->client->pickup_msg_time)
	// {
	// 	ent->client->ps.stats[STAT_PICKUP_ICON] = 0;
	// 	ent->client->ps.stats[STAT_PICKUP_STRING] = 0;
	// }

	// /* timers */
	// if (ent->client->quad_framenum > level.framenum)
	// {
	// 	ent->client->ps.stats[STAT_TIMER_ICON] = gi.imageindex("p_quad");
	// 	ent->client->ps.stats[STAT_TIMER] =
	// 		(ent->client->quad_framenum - level.framenum) / 10;
	// }
	// else if (ent->client->invincible_framenum > level.framenum)
	// {
	// 	ent->client->ps.stats[STAT_TIMER_ICON] = gi.imageindex(
	// 			"p_invulnerability");
	// 	ent->client->ps.stats[STAT_TIMER] =
	// 		(ent->client->invincible_framenum - level.framenum) / 10;
	// }
	// else if (ent->client->enviro_framenum > level.framenum)
	// {
	// 	ent->client->ps.stats[STAT_TIMER_ICON] = gi.imageindex("p_envirosuit");
	// 	ent->client->ps.stats[STAT_TIMER] =
	// 		(ent->client->enviro_framenum - level.framenum) / 10;
	// }
	// else if (ent->client->breather_framenum > level.framenum)
	// {
	// 	ent->client->ps.stats[STAT_TIMER_ICON] = gi.imageindex("p_rebreather");
	// 	ent->client->ps.stats[STAT_TIMER] =
	// 		(ent->client->breather_framenum - level.framenum) / 10;
	// }
	// else
	// {
		client.ps.stats[STAT_TIMER_ICON] = 0;
		client.ps.stats[STAT_TIMER] = 0;
	// }

	/* selected item */
	if (client.pers.selected_item == -1) {
		client.ps.stats[STAT_SELECTED_ICON] = 0;
	} else {
		client.ps.stats[STAT_SELECTED_ICON] =
			SV_ImageIndex(itemlist[client.pers.selected_item].icon);
	}

	client.ps.stats[STAT_SELECTED_ITEM] = client.pers.selected_item;

	/* layouts */
	client.ps.stats[STAT_LAYOUTS] = 0;

	// if (deathmatch->value)
	// {
	// 	if ((ent->client->pers.health <= 0) || level.intermissiontime ||
	// 		ent->client->showscores)
	// 	{
	// 		ent->client->ps.stats[STAT_LAYOUTS] |= 1;
	// 	}

	// 	if (ent->client->showinventory && (ent->client->pers.health > 0))
	// 	{
	// 		ent->client->ps.stats[STAT_LAYOUTS] |= 2;
	// 	}
	// }
	// else
	// {
	// 	if (ent->client->showscores || ent->client->showhelp)
	// 	{
	// 		ent->client->ps.stats[STAT_LAYOUTS] |= 1;
	// 	}

	// 	if (ent->client->showinventory && (ent->client->pers.health > 0))
	// 	{
	// 		ent->client->ps.stats[STAT_LAYOUTS] |= 2;
	// 	}
	// }

	/* frags */
	client.ps.stats[STAT_FRAGS] = client.resp.score;

	/* help icon / current weapon if not shown */
	// if (ent->client->pers.helpchanged && (level.framenum & 8))
	// {
	// 	ent->client->ps.stats[STAT_HELPICON] = gi.imageindex("i_help");
	// }
	// else if (((ent->client->pers.hand == CENTER_HANDED) ||
	// 		  (ent->client->ps.fov > 91)) &&
	// 		 ent->client->pers.weapon)
	// {
	// 	cvar_t *gun;
	// 	gun = gi.cvar("cl_gun", "2", 0);

	// 	if (gun->value != 2)
	// 	{
	// 		ent->client->ps.stats[STAT_HELPICON] = gi.imageindex(
	// 				ent->client->pers.weapon->icon);
	// 	}
	// 	else
	// 	{
	// 		ent->client->ps.stats[STAT_HELPICON] = 0;
	// 	}
	// }
	// else
	// {
    client.ps.stats[STAT_HELPICON] = 0;
	// }

	client.ps.stats[STAT_SPECTATOR] = 0;
}

