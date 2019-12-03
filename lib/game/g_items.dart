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
 * Item handling and item definitions.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'game.dart';
import 'g_utils.dart';
import 'player/weapon.dart' show Weapon_Blaster, Use_Weapon;

const _HEALTH_IGNORE_MAX = 1;
const _HEALTH_TIMED = 2;

int jacket_armor_index = 0;
int combat_armor_index = 0;
int body_armor_index = 0;
int _power_screen_index = 0;
int _power_shield_index = 0;

const jacketarmor_info = gitem_armor_t(25, 50, .30, .00, ARMOR_JACKET);
const combatarmor_info = gitem_armor_t(50, 100, .60, .30, ARMOR_COMBAT);
const bodyarmor_info = gitem_armor_t(100, 200, .80, .60, ARMOR_BODY);

/* ====================================================================== */

gitem_t GetItemByIndex(int index) {
	if ((index == 0) || (index >= itemlist.length)) {
		return null;
	}

	return itemlist[index];
}

gitem_t FindItemByClassname(String classname) {

	if (classname == null) {
		return null;
	}

	for (var it in itemlist) {
		if (it.classname == null) {
			continue;
		}

		if (it.classname == classname) {
			return it;
		}
	}

	return null;
}

gitem_t FindItem(String pickup_name) {

	if (pickup_name == null) {
		return null;
	}

	for (var it in itemlist) {
		if (it.pickup_name == null) {
			continue;
		}

		if (it.pickup_name == pickup_name) {
			return it;
		}
	}

	return null;
}

/* ====================================================================== */

DoRespawn(edict_t ent) {
	if (ent == null) {
		return;
	}

	if (ent.team != null) {
	// 	edict_t *master;
		// int count;
	// 	int choice;

		// var master = ent.teammaster;

		// for (count = 0, ent = master; ent != null; ent = ent.chain, count++) { }

		// int choice = (count != 0) ? randk() % count : 0;

		// for (count = 0, ent = master; count < choice; ent = ent.chain, count++) { }
	}

	ent.svflags &= ~SVF_NOCLIENT;
	ent.solid = solid_t.SOLID_TRIGGER;
	SV_LinkEdict(ent);

	/* send an effect */
	ent.s.event = entity_event_t.EV_ITEM_RESPAWN.index;
}

SetRespawn(edict_t ent, double delay) {
	if (ent == null) {
		return;
	}

	ent.flags |= FL_RESPAWN;
	ent.svflags |= SVF_NOCLIENT;
	ent.solid = solid_t.SOLID_NOT;
	ent.nextthink = level.time + delay;
	ent.think = DoRespawn;
	SV_LinkEdict(ent);
}

/* ====================================================================== */

bool Add_Ammo(edict_t ent, gitem_t item, int count) {

	if (ent == null || item == null) {
		return false;
	}

	if (ent.client == null) {
		return false;
	}

  final client = ent.client as gclient_t;

  int max;
	if (item.tag == ammo_t.AMMO_BULLETS.index)
	{
		max = client.pers.max_bullets;
	}
	else if (item.tag == ammo_t.AMMO_SHELLS.index)
	{
		max = client.pers.max_shells;
	}
	else if (item.tag == ammo_t.AMMO_ROCKETS.index)
	{
		max = client.pers.max_rockets;
	}
	else if (item.tag == ammo_t.AMMO_GRENADES.index)
	{
		max = client.pers.max_grenades;
	}
	else if (item.tag == ammo_t.AMMO_CELLS.index)
	{
		max = client.pers.max_cells;
	}
	else if (item.tag == ammo_t.AMMO_SLUGS.index)
	{
		max = client.pers.max_slugs;
	}
	else
	{
		return false;
	}

	final index = item.index;

	if (client.pers.inventory[index] == max)
	{
		return false;
	}

	client.pers.inventory[index] += count;

	if (client.pers.inventory[index] > max)
	{
		client.pers.inventory[index] = max;
	}

	return true;
}

bool Pickup_Ammo(edict_t ent, edict_t other) {
	int oldcount;
	int count;

	if (ent == null || other == null) {
		return false;
	}

	bool weapon = (ent.item.flags & IT_WEAPON) != 0;

	if ((weapon) && (dmflags.integer & DF_INFINITE_AMMO) != 0)
	{
		count = 1000;
	}
	else if (ent.count != 0)
	{
		count = ent.count;
	}
	else
	{
		count = ent.item.quantity;
	}

	oldcount = (other.client as gclient_t).pers.inventory[ent.item.index];

	if (!Add_Ammo(other, ent.item, count))
	{
		return false;
	}

	if (weapon && oldcount == 0)
	{
		if (((other.client as gclient_t).pers.weapon != ent.item) &&
			(!deathmatch.boolean ||
			 ((other.client as gclient_t).pers.weapon == FindItem("blaster"))))
		{
			(other.client as gclient_t).newweapon = ent.item;
		}
	}

	if ((ent.spawnflags & (DROPPED_ITEM | DROPPED_PLAYER_ITEM)) == 0 &&
		(deathmatch.boolean))
	{
		SetRespawn(ent, 30);
	}

	return true;
}


/* ====================================================================== */

MegaHealth_think(edict_t self) {
	if (self == null) {
		return;
	}

	if ((self.owner as edict_t).health > (self.owner as edict_t).max_health) {
		self.nextthink = level.time + 1;
		(self.owner as edict_t).health -= 1;
		return;
	}

	if ((self.spawnflags & DROPPED_ITEM) == 0 && (deathmatch.boolean)) {
		SetRespawn(self, 20);
	} else {
		G_FreeEdict(self);
	}
}

bool Pickup_Health(edict_t ent, edict_t other) {

	if (ent == null || other == null) {
		return false;
	}

	if ((ent.style & _HEALTH_IGNORE_MAX) == 0) {
		if (other.health >= other.max_health) {
			return false;
		}
	}

	other.health += ent.count;

	if ((ent.style & _HEALTH_IGNORE_MAX) == 0) {
		if (other.health > other.max_health)
		{
			other.health = other.max_health;
		}
	}

	if ((ent.style & _HEALTH_TIMED) != 0) {
		ent.think = MegaHealth_think;
		ent.nextthink = level.time + 5;
		ent.owner = other;
		ent.flags |= FL_RESPAWN;
		ent.svflags |= SVF_NOCLIENT;
		ent.solid = solid_t.SOLID_NOT;
	}
	else
	{
		if ((ent.spawnflags & DROPPED_ITEM) == 0 && (deathmatch.boolean)) {
			SetRespawn(ent, 30);
		}
	}

	return true;
}

/* ====================================================================== */

int ArmorIndex(edict_t ent) {
	if (ent == null) {
		return 0;
	}

	if (ent.client == null) {
		return 0;
	}

  final client = ent.client as gclient_t;

	if (client.pers.inventory[jacket_armor_index] > 0)
	{
		return jacket_armor_index;
	}

	if (client.pers.inventory[combat_armor_index] > 0)
	{
		return combat_armor_index;
	}

	if (client.pers.inventory[body_armor_index] > 0)
	{
		return body_armor_index;
	}

	return 0;
}

bool Pickup_Armor(edict_t ent, edict_t other) {
	// int old_armor_index;
	// gitem_armor_t *oldinfo;
	// gitem_armor_t *newinfo;
	// int newcount;
	// float salvage;
	// int salvagecount;

	if (ent == null || other == null) {
		return false;
	}

	/* get info on new armor */
	// newinfo = (gitem_armor_t *)ent->item->info;

	// old_armor_index = ArmorIndex(other);

	// /* handle armor shards specially */
	// if (ent->item->tag == ARMOR_SHARD)
	// {
	// 	if (!old_armor_index)
	// 	{
	// 		other->client->pers.inventory[jacket_armor_index] = 2;
	// 	}
	// 	else
	// 	{
	// 		other->client->pers.inventory[old_armor_index] += 2;
	// 	}
	// }
	// else if (!old_armor_index) /* if player has no armor, just use it */
	// {
	// 	other->client->pers.inventory[ITEM_INDEX(ent->item)] =
	// 		newinfo->base_count;
	// }
	// else /* use the better armor */
	// {
	// 	/* get info on old armor */
	// 	if (old_armor_index == jacket_armor_index)
	// 	{
	// 		oldinfo = &jacketarmor_info;
	// 	}
	// 	else if (old_armor_index == combat_armor_index)
	// 	{
	// 		oldinfo = &combatarmor_info;
	// 	}
	// 	else
	// 	{
	// 		oldinfo = &bodyarmor_info;
	// 	}

	// 	if (newinfo->normal_protection > oldinfo->normal_protection)
	// 	{
	// 		/* calc new armor values */
	// 		salvage = oldinfo->normal_protection / newinfo->normal_protection;
	// 		salvagecount = salvage *
	// 					   other->client->pers.inventory[old_armor_index];
	// 		newcount = newinfo->base_count + salvagecount;

	// 		if (newcount > newinfo->max_count)
	// 		{
	// 			newcount = newinfo->max_count;
	// 		}

	// 		/* zero count of old armor so it goes away */
	// 		other->client->pers.inventory[old_armor_index] = 0;

	// 		/* change armor to new item with computed value */
	// 		other->client->pers.inventory[ITEM_INDEX(ent->item)] = newcount;
	// 	}
	// 	else
	// 	{
	// 		/* calc new armor values */
	// 		salvage = newinfo->normal_protection / oldinfo->normal_protection;
	// 		salvagecount = salvage * newinfo->base_count;
	// 		newcount = other->client->pers.inventory[old_armor_index] +
	// 				   salvagecount;

	// 		if (newcount > oldinfo->max_count)
	// 		{
	// 			newcount = oldinfo->max_count;
	// 		}

	// 		/* if we're already maxed out then we don't need the new armor */
	// 		if (other->client->pers.inventory[old_armor_index] >= newcount)
	// 		{
	// 			return false;
	// 		}

	// 		/* update current armor value */
	// 		other->client->pers.inventory[old_armor_index] = newcount;
	// 	}
	// }

	// if (!(ent->spawnflags & DROPPED_ITEM) && (deathmatch->value))
	// {
	// 	SetRespawn(ent, 20);
	// }

	return true;
}

/* ====================================================================== */

Touch_Item(edict_t ent, edict_t other, cplane_t plane /* unused */, csurface_t surf /* unused */)
{

	if (ent == null || other == null) {
		return;
	}

	if (other.client == null) {
		return;
	}

	if (other.health < 1) {
		return; /* dead people can't pickup */
	}

	if (ent.item.pickup == null) {
		return; /* not a grabbable item? */
	}

	bool taken = ent.item.pickup(ent, other);

  final oclient = other.client as gclient_t;

	if (taken)
	{
		/* flash the screen */
		oclient.bonus_alpha = 0.25;

		/* show icon and name on status bar */
		oclient.ps.stats[STAT_PICKUP_ICON] = SV_ImageIndex( ent.item.icon);
		oclient.ps.stats[STAT_PICKUP_STRING] = CS_ITEMS + ent.item.index;
		oclient.pickup_msg_time = level.time + 3.0;

		/* change selected item */
		if (ent.item.use != null)
		{
			oclient.pers.selected_item =
				oclient.ps.stats[STAT_SELECTED_ITEM] =
			   	ent.item.index;
		}

		// if (ent->item->pickup == Pickup_Health)
		// {
		// 	if (ent->count == 2)
		// 	{
		// 		gi.sound(other, CHAN_ITEM, gi.soundindex(
		// 						"items/s_health.wav"), 1, ATTN_NORM, 0);
		// 	}
		// 	else if (ent->count == 10)
		// 	{
		// 		gi.sound(other, CHAN_ITEM, gi.soundindex(
		// 						"items/n_health.wav"), 1, ATTN_NORM, 0);
		// 	}
		// 	else if (ent->count == 25)
		// 	{
		// 		gi.sound(other, CHAN_ITEM, gi.soundindex(
		// 						"items/l_health.wav"), 1, ATTN_NORM, 0);
		// 	}
		// 	else /* (ent->count == 100) */
		// 	{
		// 		gi.sound(other, CHAN_ITEM, gi.soundindex(
		// 						"items/m_health.wav"), 1, ATTN_NORM, 0);
		// 	}
		// }
		// else if (ent->item->pickup_sound)
		// {
		// 	gi.sound(other, CHAN_ITEM, gi.soundindex(
		// 					ent->item->pickup_sound), 1, ATTN_NORM, 0);
		// }
	}

	if ((ent.spawnflags & ITEM_TARGETS_USED) == 0) {
		G_UseTargets(ent, other);
		ent.spawnflags |= ITEM_TARGETS_USED;
	}

	if (!taken) {
		return;
	}

	if (!((coop.boolean) &&
		  (ent.item.flags & IT_STAY_COOP) != 0) ||
		(ent.spawnflags & (DROPPED_ITEM | DROPPED_PLAYER_ITEM)) != 0)
	{
		if ((ent.flags & FL_RESPAWN) != 0)
		{
			ent.flags &= ~FL_RESPAWN;
		}
		else
		{
			G_FreeEdict(ent);
		}
	}
}

Use_Item(edict_t ent, edict_t other /* unused */, edict_t activator /* unused */)
{
	if (ent == null) {
		return;
	}

	ent.svflags &= ~SVF_NOCLIENT;
	ent.use = null;

	if ((ent.spawnflags & ITEM_NO_TOUCH) != 0)
	{
		ent.solid = solid_t.SOLID_BBOX;
		ent.touch = null;
	}
	else
	{
		ent.solid = solid_t.SOLID_TRIGGER;
		ent.touch = Touch_Item;
	}

	SV_LinkEdict(ent);
}

/* ====================================================================== */

droptofloor(edict_t ent) {

	if (ent == null) {
		return;
	}

  ent.mins.setAll(0, [-15, -15, -15]);
  ent.maxs.setAll(0, [15, 15, 15]);

	if (ent.model != null) {
		PF_setmodel(ent, ent.model);
	} else {
		PF_setmodel(ent, ent.item.world_model);
	}

	ent.solid = solid_t.SOLID_TRIGGER;
	ent.movetype = movetype_t.MOVETYPE_TOSS;
	ent.touch = Touch_Item;

  List<double> dest = [0,0,0];
	VectorAdd(ent.s.origin, [0, 0, -128], dest);

	final tr = SV_Trace(ent.s.origin, ent.mins, ent.maxs, dest, ent, MASK_SOLID);

	if (tr.startsolid) {
		Com_Printf("droptofloor: ${ent.classname} startsolid at ${ent.s.origin}\n");
		G_FreeEdict(ent);
		return;
	}

  ent.s.origin.setAll(0, tr.endpos);

	if (ent.team != null) {
		// ent->flags &= ~FL_TEAMSLAVE;
		// ent->chain = ent->teamchain;
		// ent->teamchain = NULL;

		// ent->svflags |= SVF_NOCLIENT;
		// ent->solid = SOLID_NOT;

		// if (ent == ent->teammaster) {
		// 	ent->nextthink = level.time + FRAMETIME;
		// 	ent->think = DoRespawn;
		// }
	}

	if ((ent.spawnflags & ITEM_NO_TOUCH) != 0) {
		ent.solid = solid_t.SOLID_BBOX;
		ent.touch = null;
		ent.s.effects &= ~EF_ROTATE;
		ent.s.renderfx &= ~RF_GLOW;
	}

	if ((ent.spawnflags & ITEM_TRIGGER_SPAWN) != 0) {
		ent.svflags |= SVF_NOCLIENT;
		ent.solid = solid_t.SOLID_NOT;
		ent.use = Use_Item;
	}

	SV_LinkEdict(ent);
}


/*
 * Precaches all data needed for a given item.
 * This will be called for each item spawned in a level,
 * and for each item in each client's inventory.
 */
PrecacheItem(gitem_t it) {
	// char *s, *start;
	// char data[MAX_QPATH];
	// int len;
	// gitem_t *ammo;

	if (it == null) {
		return;
	}

	if (it.pickup_sound != null) {
	  SV_SoundIndex(it.pickup_sound);
	}

	if (it.world_model != null) {
	  SV_ModelIndex(it.world_model);
	}

	if (it.view_model != null) {
	  SV_ModelIndex(it.view_model);
	}

	if (it.icon != null) {
		SV_ImageIndex(it.icon);
	}

	/* parse everything for its ammo */
	if (it.ammo != null && it.ammo.isNotEmpty) {
		final ammo = FindItem(it.ammo);
		if (ammo != it) {
			PrecacheItem(ammo);
		}
	}

	/* parse the space seperated precache string for other items */
	String s = it.precaches;

	if (s == null || s.isEmpty) {
		return;
	}
  // int index = 0;
	// while (index < s.length) {
	// 	start = s;

	// 	while (*s && *s != ' ')
	// 	{
	// 		s++;
	// 	}

	// 	len = s - start;

	// 	if ((len >= MAX_QPATH) || (len < 5))
	// 	{
	// 		gi.error("PrecacheItem: %s has bad precache string", it->classname);
	// 	}

	// 	memcpy(data, start, len);
	// 	data[len] = 0;

	// 	if (*s)
	// 	{
	// 		s++;
	// 	}

		/* determine type based on extension */
	// 	if (!strcmp(data + len - 3, "md2"))
	// 	{
	// 		gi.modelindex(data);
	// 	}
	// 	else if (!strcmp(data + len - 3, "sp2"))
	// 	{
	// 		gi.modelindex(data);
	// 	}
	// 	else if (!strcmp(data + len - 3, "wav"))
	// 	{
	// 		gi.soundindex(data);
	// 	}

	// 	if (!strcmp(data + len - 3, "pcx"))
	// 	{
	// 		gi.imageindex(data);
	// 	}
	// }
}

/*
 * ============
 * Sets the clipping size and
 * plants the object on the floor.
 *
 * Items can't be immediately dropped
 * to floor, because they might be on
 * an entity that hasn't spawned yet.
 * ============
 */
SpawnItem(edict_t ent, gitem_t item) {
	if (ent == null || item == null) {
		return;
	}

	PrecacheItem(item);

	if (ent.spawnflags != 0) {
		if (ent.classname != "key_power_cube") {
			ent.spawnflags = 0;
			Com_Printf("${ent.classname} at ${ent.s.origin} has invalid spawnflags set\n");
		}
	}

	/* some items will be prevented in deathmatch */
	if (deathmatch.boolean) {
		if ((dmflags.integer & DF_NO_ARMOR) != 0) {
			// if ((item.pickup == Pickup_Armor) ||
			// 	(item.pickup == Pickup_PowerArmor)) {
			// 	G_FreeEdict(ent);
			// 	return;
			// }
		}

		if ((dmflags.integer & DF_NO_ITEMS) != 0) {
			// if (item->pickup == Pickup_Powerup) {
			// 	G_FreeEdict(ent);
			// 	return;
			// }
		}

		if ((dmflags.integer & DF_NO_HEALTH) != 0) {
			// if ((item->pickup == Pickup_Health) ||
			// 	(item->pickup == Pickup_Adrenaline) ||
			// 	(item->pickup == Pickup_AncientHead)) {
			// 	G_FreeEdict(ent);
			// 	return;
			// }
		}

		if ((dmflags.integer & DF_INFINITE_AMMO) != 0) {
			// if ((item->flags == IT_AMMO) ||
			// 	(strcmp(ent->classname, "weapon_bfg") == 0))
			// {
			// 	G_FreeEdict(ent);
			// 	return;
			// }
		}
	}

	if (coop.boolean && (ent.classname == "key_power_cube")) {
		ent.spawnflags |= (1 << (8 + level.power_cubes));
		level.power_cubes++;
	}

	/* don't let them drop items that stay in a coop game */
	// if ((coop.boolean) && ((item.flags & IT_STAY_COOP) != 0)) {
	// 	item.drop = null;
	// }

	ent.item = item;
	ent.nextthink = level.time + 2 * FRAMETIME; /* items start after other solids */
	ent.think = droptofloor;
	ent.s.effects = item.world_model_flags;
	ent.s.renderfx = RF_GLOW;

	if (ent.model != null) {
		SV_ModelIndex(ent.model);
	}
}

/* ====================================================================== */

final gameitemlist = [
	glistitem_t.empty(), /* leave index 0 alone */

	/* QUAKED item_armor_body (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_armor_body",
		Pickup_Armor,
		null,
		null,
		null,
		"misc/ar1_pkup.wav",
		"models/items/armor/body/tris.md2", EF_ROTATE,
		null,
		"i_bodyarmor",
		"Body Armor",
		3,
		0,
		null,
		IT_ARMOR,
		0,
		bodyarmor_info,
		ARMOR_BODY,
		""
	),

	/* QUAKED item_armor_combat (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_armor_combat",
		Pickup_Armor,
		null,
		null,
		null,
		"misc/ar1_pkup.wav",
		"models/items/armor/combat/tris.md2", EF_ROTATE,
		null,
		"i_combatarmor",
		"Combat Armor",
		3,
		0,
		null,
		IT_ARMOR,
		0,
		combatarmor_info,
		ARMOR_COMBAT,
		""
  ),

	/* QUAKED item_armor_jacket (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_armor_jacket",
		Pickup_Armor,
		null,
		null,
		null,
		"misc/ar1_pkup.wav",
		"models/items/armor/jacket/tris.md2", EF_ROTATE,
		null,
		"i_jacketarmor",
		"Jacket Armor",
		3,
		0,
		null,
		IT_ARMOR,
		0,
		jacketarmor_info,
		ARMOR_JACKET,
		""
  ),

	/* QUAKED item_armor_shard (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_armor_shard",
		Pickup_Armor,
		null,
		null,
		null,
		"misc/ar2_pkup.wav",
		"models/items/armor/shard/tris.md2", EF_ROTATE,
		null,
		"i_jacketarmor",
		"Armor Shard",
		3,
		0,
		null,
		IT_ARMOR,
		0,
		null,
		ARMOR_SHARD,
		""
  ),

	/* QUAKED item_power_screen (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_power_screen",
		null, // Pickup_PowerArmor,
		null, // Use_PowerArmor,
		null, // Drop_PowerArmor,
		null,
		"misc/ar3_pkup.wav",
		"models/items/armor/screen/tris.md2", EF_ROTATE,
		null,
		"i_powerscreen",
		"Power Screen",
		0,
		60,
		null,
		IT_ARMOR,
		0,
		null,
		0,
		""
  ),

	/* QUAKED item_power_shield (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_power_shield",
		null, // Pickup_PowerArmor,
		null, // Use_PowerArmor,
		null, // Drop_PowerArmor,
		null,
		"misc/ar3_pkup.wav",
		"models/items/armor/shield/tris.md2", EF_ROTATE,
		null,
		"i_powershield",
		"Power Shield",
		0,
		60,
		null, 
		IT_ARMOR,
		0,
		null,
		0,
		"misc/power2.wav misc/power1.wav"
  ),

	/* weapon_blaster (.3 .3 1) (-16 -16 -16) (16 16 16)
	   always owned, never in the world */
	glistitem_t(
		"weapon_blaster",
		null,
		Use_Weapon,
		null,
		Weapon_Blaster,
		"misc/w_pkup.wav",
		null, 0,
		"models/weapons/v_blast/tris.md2",
		"w_blaster",
		"Blaster",
		0,
		0,
		null, 
		IT_WEAPON | IT_STAY_COOP,
		WEAP_BLASTER,
		null,
		0,
		"weapons/blastf1a.wav misc/lasfly.wav"
  ),

	/* QUAKED weapon_shotgun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_shotgun",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_Shotgun,
		"misc/w_pkup.wav",
		"models/weapons/g_shotg/tris.md2", EF_ROTATE,
		"models/weapons/v_shotg/tris.md2",
		"w_shotgun",
		"Shotgun",
		0,
		1,
		"Shells",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_SHOTGUN,
		null,
		0,
		"weapons/shotgf1b.wav weapons/shotgr1b.wav"
  ),

	/* QUAKED weapon_supershotgun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_supershotgun",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_SuperShotgun,
		"misc/w_pkup.wav",
		"models/weapons/g_shotg2/tris.md2", EF_ROTATE,
		"models/weapons/v_shotg2/tris.md2",
		"w_sshotgun",
		"Super Shotgun",
		0,
		2,
		"Shells",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_SUPERSHOTGUN,
		null,
		0,
		"weapons/sshotf1b.wav"
  ),

	/* QUAKED weapon_machinegun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_machinegun",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_Machinegun,
		"misc/w_pkup.wav",
		"models/weapons/g_machn/tris.md2", EF_ROTATE,
		"models/weapons/v_machn/tris.md2",
		"w_machinegun",
		"Machinegun",
		0,
		1,
		"Bullets",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_MACHINEGUN,
		null,
		0,
		"weapons/machgf1b.wav weapons/machgf2b.wav weapons/machgf3b.wav weapons/machgf4b.wav weapons/machgf5b.wav"
  ),

	/* QUAKED weapon_chaingun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_chaingun",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_Chaingun,
		"misc/w_pkup.wav",
		"models/weapons/g_chain/tris.md2", EF_ROTATE,
		"models/weapons/v_chain/tris.md2",
		"w_chaingun",
		"Chaingun",
		0,
		1,
		"Bullets",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_CHAINGUN,
		null,
		0,
		"weapons/chngnu1a.wav weapons/chngnl1a.wav weapons/machgf3b.wav` weapons/chngnd1a.wav"
  ),

	/* QUAKED ammo_grenades (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"ammo_grenades",
		Pickup_Ammo,
		Use_Weapon,
		null, // Drop_Ammo,
		null, // Weapon_Grenade,
		"misc/am_pkup.wav",
		"models/items/ammo/grenades/medium/tris.md2", 0,
		"models/weapons/v_handgr/tris.md2",
		"a_grenades",
		"Grenades",
		3,
		5,
		"grenades",
		IT_AMMO | IT_WEAPON,
		WEAP_GRENADES,
		null,
		ammo_t.AMMO_GRENADES.index,
		"weapons/hgrent1a.wav weapons/hgrena1b.wav weapons/hgrenc1b.wav weapons/hgrenb1a.wav weapons/hgrenb2a.wav "
  ),

	/* QUAKED weapon_grenadelauncher (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_grenadelauncher",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_GrenadeLauncher,
		"misc/w_pkup.wav",
		"models/weapons/g_launch/tris.md2", EF_ROTATE,
		"models/weapons/v_launch/tris.md2",
		"w_glauncher",
		"Grenade Launcher",
		0,
		1,
		"Grenades",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_GRENADELAUNCHER,
		null,
		0,
		"models/objects/grenade/tris.md2 weapons/grenlf1a.wav weapons/grenlr1b.wav weapons/grenlb1b.wav"
  ),

	/* QUAKED weapon_rocketlauncher (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_rocketlauncher",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_RocketLauncher,
		"misc/w_pkup.wav",
		"models/weapons/g_rocket/tris.md2", EF_ROTATE,
		"models/weapons/v_rocket/tris.md2",
		"w_rlauncher",
		"Rocket Launcher",
		0,
		1,
		"Rockets",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_ROCKETLAUNCHER,
		null,
		0,
		"models/objects/rocket/tris.md2 weapons/rockfly.wav weapons/rocklf1a.wav weapons/rocklr1b.wav models/objects/debris2/tris.md2"
  ),

	/* QUAKED weapon_hyperblaster (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_hyperblaster",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_HyperBlaster,
		"misc/w_pkup.wav",
		"models/weapons/g_hyperb/tris.md2", EF_ROTATE,
		"models/weapons/v_hyperb/tris.md2",
		"w_hyperblaster",
		"HyperBlaster",
		0,
		1,
		"Cells",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_HYPERBLASTER,
		null,
		0,
		"weapons/hyprbu1a.wav weapons/hyprbl1a.wav weapons/hyprbf1a.wav weapons/hyprbd1a.wav misc/lasfly.wav"
  ),

	/* QUAKED weapon_railgun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_railgun",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_Railgun,
		"misc/w_pkup.wav",
		"models/weapons/g_rail/tris.md2", EF_ROTATE,
		"models/weapons/v_rail/tris.md2",
		"w_railgun",
		"Railgun",
		0,
		1,
		"Slugs",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_RAILGUN,
		null,
		0,
		"weapons/rg_hum.wav"
  ),

	/* QUAKED weapon_bfg (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_bfg",
		null, // Pickup_Weapon,
		Use_Weapon,
		null, // Drop_Weapon,
		null, // Weapon_BFG,
		"misc/w_pkup.wav",
		"models/weapons/g_bfg/tris.md2", EF_ROTATE,
		"models/weapons/v_bfg/tris.md2",
		"w_bfg",
		"BFG10K",
		0,
		50,
		"Cells",
		IT_WEAPON | IT_STAY_COOP,
		WEAP_BFG,
		null,
		0,
		"sprites/s_bfg1.sp2 sprites/s_bfg2.sp2 sprites/s_bfg3.sp2 weapons/bfg__f1y.wav weapons/bfg__l1a.wav weapons/bfg__x1b.wav weapons/bfg_hum.wav"
  ),

	/* QUAKED ammo_shells (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"ammo_shells",
		Pickup_Ammo,
		null,
		null, // Drop_Ammo,
		null,
		"misc/am_pkup.wav",
		"models/items/ammo/shells/medium/tris.md2", 0,
		null,
		"a_shells",
		"Shells",
		3,
		10,
		null,
		IT_AMMO,
		0,
		null,
		ammo_t.AMMO_SHELLS.index,
		""
  ),

	/* QUAKED ammo_bullets (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"ammo_bullets",
		Pickup_Ammo,
		null,
		null, // Drop_Ammo,
		null,
		"misc/am_pkup.wav",
		"models/items/ammo/bullets/medium/tris.md2", 0,
		null,
		"a_bullets",
		"Bullets",
		3,
		50,
		null,
		IT_AMMO,
		0,
		null,
		ammo_t.AMMO_BULLETS.index,
		""
  ),

	// /* QUAKED ammo_cells (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"ammo_cells",
		Pickup_Ammo,
		null,
		null, // Drop_Ammo,
		null,
		"misc/am_pkup.wav",
		"models/items/ammo/cells/medium/tris.md2", 0,
		null,
		"a_cells",
		"Cells",
		3,
		50,
		null,
		IT_AMMO,
		0,
		null,
		ammo_t.AMMO_CELLS.index,
		""
  ),

	// /* QUAKED ammo_rockets (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"ammo_rockets",
	// 	Pickup_Ammo,
	// 	NULL,
	// 	Drop_Ammo,
	// 	NULL,
	// 	"misc/am_pkup.wav",
	// 	"models/items/ammo/rockets/medium/tris.md2", 0,
	// 	NULL,
	// 	"a_rockets",
	// 	"Rockets",
	// 	3,
	// 	5,
	// 	NULL,
	// 	IT_AMMO,
	// 	0,
	// 	NULL,
	// 	AMMO_ROCKETS,
	// 	""
	// },

	// /* QUAKED ammo_slugs (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"ammo_slugs",
	// 	Pickup_Ammo,
	// 	NULL,
	// 	Drop_Ammo,
	// 	NULL,
	// 	"misc/am_pkup.wav",
	// 	"models/items/ammo/slugs/medium/tris.md2", 0,
	// 	NULL,
	// 	"a_slugs",
	// 	"Slugs",
	// 	3,
	// 	10,
	// 	NULL,
	// 	IT_AMMO,
	// 	0,
	// 	NULL,
	// 	AMMO_SLUGS,
	// 	""
	// },

	// /* QUAKED item_quad (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"item_quad",
	// 	Pickup_Powerup,
	// 	Use_Quad,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/quaddama/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"p_quad",
	// 	"Quad Damage",
	// 	2,
	// 	60,
	// 	NULL,
	// 	IT_POWERUP,
	// 	0,
	// 	NULL,
	// 	0,
	// 	"items/damage.wav items/damage2.wav items/damage3.wav"
	// },

	// /* QUAKED item_invulnerability (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"item_invulnerability",
	// 	Pickup_Powerup,
	// 	Use_Invulnerability,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/invulner/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"p_invulnerability",
	// 	"Invulnerability",
	// 	2,
	// 	300,
	// 	NULL,
	// 	IT_POWERUP,
	// 	0,
	// 	NULL,
	// 	0,
	// 	"items/protect.wav items/protect2.wav items/protect4.wav"
	// },

	// /* QUAKED item_silencer (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"item_silencer",
	// 	Pickup_Powerup,
	// 	Use_Silencer,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/silencer/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"p_silencer",
	// 	"Silencer",
	// 	2,
	// 	60,
	// 	NULL,
	// 	IT_POWERUP,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED item_breather (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"item_breather",
	// 	Pickup_Powerup,
	// 	Use_Breather,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/breather/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"p_rebreather",
	// 	"Rebreather",
	// 	2,
	// 	60,
	// 	NULL,
	// 	IT_STAY_COOP | IT_POWERUP,
	// 	0,
	// 	NULL,
	// 	0,
	// 	"items/airout.wav"
	// },

	// /* QUAKED item_enviro (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"item_enviro",
	// 	Pickup_Powerup,
	// 	Use_Envirosuit,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/enviro/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"p_envirosuit",
	// 	"Environment Suit",
	// 	2,
	// 	60,
	// 	NULL,
	// 	IT_STAY_COOP | IT_POWERUP,
	// 	0,
	// 	NULL,
	// 	0,
	// 	"items/airout.wav"
	// },

	// /* QUAKED item_ancient_head (.3 .3 1) (-16 -16 -16) (16 16 16)
	//    Special item that gives +2 to maximum health */
	// {
	// 	"item_ancient_head",
	// 	Pickup_AncientHead,
	// 	NULL,
	// 	NULL,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/c_head/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"i_fixme",
	// 	"Ancient Head",
	// 	2,
	// 	60,
	// 	NULL,
	// 	0,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED item_adrenaline (.3 .3 1) (-16 -16 -16) (16 16 16)
	//    gives +1 to maximum health */
	// {
	// 	"item_adrenaline",
	// 	Pickup_Adrenaline,
	// 	NULL,
	// 	NULL,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/adrenal/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"p_adrenaline",
	// 	"Adrenaline",
	// 	2,
	// 	60,
	// 	NULL,
	// 	0,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED item_bandolier (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"item_bandolier",
	// 	Pickup_Bandolier,
	// 	NULL,
	// 	NULL,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/band/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"p_bandolier",
	// 	"Bandolier",
	// 	2,
	// 	60,
	// 	NULL,
	// 	0,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED item_pack (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"item_pack",
	// 	Pickup_Pack,
	// 	NULL,
	// 	NULL,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/pack/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"i_pack",
	// 	"Ammo Pack",
	// 	2,
	// 	180,
	// 	NULL,
	// 	0,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_data_cd (0 .5 .8) (-16 -16 -16) (16 16 16)
	//    key for computer centers */
	// {
	// 	"key_data_cd",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/keys/data_cd/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"k_datacd",
	// 	"Data CD",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_power_cube (0 .5 .8) (-16 -16 -16) (16 16 16) TRIGGER_SPAWN NO_TOUCH
	//    warehouse circuits */
	// {
	// 	"key_power_cube",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/keys/power/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"k_powercube",
	// 	"Power Cube",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_pyramid (0 .5 .8) (-16 -16 -16) (16 16 16)
	//    key for the entrance of jail3 */
	// {
	// 	"key_pyramid",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/keys/pyramid/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"k_pyramid",
	// 	"Pyramid Key",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_data_spinner (0 .5 .8) (-16 -16 -16) (16 16 16)
	//    key for the city computer */
	// {
	// 	"key_data_spinner",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/keys/spinner/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"k_dataspin",
	// 	"Data Spinner",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_pass (0 .5 .8) (-16 -16 -16) (16 16 16)
	//    security pass for the security level */
	// {
	// 	"key_pass",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/keys/pass/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"k_security",
	// 	"Security Pass",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_blue_key (0 .5 .8) (-16 -16 -16) (16 16 16)
	//    normal door key - blue */
	// {
	// 	"key_blue_key",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/keys/key/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"k_bluekey",
	// 	"Blue Key",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_red_key (0 .5 .8) (-16 -16 -16) (16 16 16)
	//    normal door key - red */
	// {
	// 	"key_red_key",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/keys/red_key/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"k_redkey",
	// 	"Red Key",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_commander_head (0 .5 .8) (-16 -16 -16) (16 16 16)
	//    tank commander's head */
	// {
	// 	"key_commander_head",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/monsters/commandr/head/tris.md2", EF_GIB,
	// 	NULL,
	// 	"k_comhead",
	// 	"Commander's Head",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	// /* QUAKED key_airstrike_target (0 .5 .8) (-16 -16 -16) (16 16 16) */
	// {
	// 	"key_airstrike_target",
	// 	Pickup_Key,
	// 	NULL,
	// 	Drop_General,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	"models/items/keys/target/tris.md2", EF_ROTATE,
	// 	NULL,
	// 	"i_airstrike",
	// 	"Airstrike Marker",
	// 	2,
	// 	0,
	// 	NULL,
	// 	IT_STAY_COOP | IT_KEY,
	// 	0,
	// 	NULL,
	// 	0,
	// 	""
	// },

	glistitem_t(
	  null,
	  Pickup_Health,
	  null,
	  null,
	  null,
		"items/pkup.wav",
		null, 0,
		null,
		"i_health",
		"Health",
		3,
		0,
		null,
		0,
		0,
		null,
		0,
		"items/s_health.wav items/n_health.wav items/l_health.wav items/m_health.wav"
	),    
];

List<gitem_t> itemlist;

/*
 * QUAKED item_health (.3 .3 1) (-16 -16 -16) (16 16 16)
 */
SP_item_health(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean && (dmflags.integer & DF_NO_HEALTH) != 0) {
		G_FreeEdict(self);
		return;
	}

	self.model = "models/items/healing/medium/tris.md2";
	self.count = 10;
	SpawnItem(self, FindItem("Health"));
	SV_SoundIndex("items/n_health.wav");
}

/*
 * QUAKED item_health_small (.3 .3 1) (-16 -16 -16) (16 16 16)
 */
SP_item_health_small(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean && (dmflags.integer & DF_NO_HEALTH) != 0) {
		G_FreeEdict(self);
		return;
	}

	self.model = "models/items/healing/stimpack/tris.md2";
	self.count = 2;
	SpawnItem(self, FindItem("Health"));
	self.style = _HEALTH_IGNORE_MAX;
	SV_SoundIndex("items/s_health.wav");
}

/*
 * QUAKED item_health_large (.3 .3 1) (-16 -16 -16) (16 16 16)
 */
SP_item_health_large(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean && (dmflags.integer & DF_NO_HEALTH) != 0) {
		G_FreeEdict(self);
		return;
	}

	self.model = "models/items/healing/large/tris.md2";
	self.count = 25;
	SpawnItem(self, FindItem("Health"));
	SV_SoundIndex("items/l_health.wav");
}

/*
 * QUAKED item_health_mega (.3 .3 1) (-16 -16 -16) (16 16 16)
 */
SP_item_health_mega(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean && (dmflags.integer & DF_NO_HEALTH) != 0) {
		G_FreeEdict(self);
		return;
	}

	self.model = "models/items/mega_h/tris.md2";
	self.count = 100;
	SpawnItem(self, FindItem("Health"));
	SV_SoundIndex("items/m_health.wav");
	self.style = _HEALTH_IGNORE_MAX | _HEALTH_TIMED;
}


InitItems() {
	itemlist = List.generate(gameitemlist.length, (i) => gitem_t(i, gameitemlist[i]));
}

/*
 * Called by worldspawn
 */
SetItemNames() {

	for (int i = 0; i < game.num_items; i++) {
		PF_Configstring(CS_ITEMS + i, itemlist[i].pickup_name);
	}

	jacket_armor_index = FindItem("Jacket Armor").index;
	combat_armor_index = FindItem("Combat Armor").index;
	body_armor_index = FindItem("Body Armor").index;
	_power_screen_index = FindItem("Power Screen").index;
	_power_shield_index = FindItem("Power Shield").index;
}