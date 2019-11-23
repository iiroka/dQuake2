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

int jacket_armor_index = 0;
int combat_armor_index = 0;
int body_armor_index = 0;
int _power_screen_index = 0;
int _power_shield_index = 0;

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
	// ent.touch = Touch_Item;

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
		// ent.use = Use_Item;
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
	// 	ammo = FindItem(it->ammo);

	// 	if (ammo != it)
	// 	{
	// 		PrecacheItem(ammo);
	// 	}
	}

	/* parse the space seperated precache string for other items */
	String s = it.precaches;

	if (s == null || s.isEmpty) {
		return;
	}
  int index = 0;
	while (index < s.length) {
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
	}
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
		// Pickup_Armor,
		// null,
		// null,
		// null,
		// "misc/ar1_pkup.wav",
		"models/items/armor/body/tris.md2", EF_ROTATE,
		null,
		"i_bodyarmor",
		"Body Armor",
		// 3,
		// 0,
		// null,
		// IT_ARMOR,
		// 0,
		// &bodyarmor_info,
		// ARMOR_BODY,
		// ""
	),

	/* QUAKED item_armor_combat (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_armor_combat",
		// Pickup_Armor,
		// NULL,
		// NULL,
		// NULL,
		// "misc/ar1_pkup.wav",
		"models/items/armor/combat/tris.md2", EF_ROTATE,
		null,
		"i_combatarmor",
		"Combat Armor",
		// 3,
		// 0,
		// NULL,
		// IT_ARMOR,
		// 0,
		// &combatarmor_info,
		// ARMOR_COMBAT,
		// ""
  ),

	/* QUAKED item_armor_jacket (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_armor_jacket",
		// Pickup_Armor,
		// NULL,
		// NULL,
		// NULL,
		// "misc/ar1_pkup.wav",
		"models/items/armor/jacket/tris.md2", EF_ROTATE,
		null,
		"i_jacketarmor",
		"Jacket Armor",
		// 3,
		// 0,
		// NULL,
		// IT_ARMOR,
		// 0,
		// &jacketarmor_info,
		// ARMOR_JACKET,
		// ""
  ),

	/* QUAKED item_armor_shard (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_armor_shard",
		// Pickup_Armor,
		// NULL,
		// NULL,
		// NULL,
		// "misc/ar2_pkup.wav",
		"models/items/armor/shard/tris.md2", EF_ROTATE,
		null,
		"i_jacketarmor",
		"Armor Shard",
		// 3,
		// 0,
		// NULL,
		// IT_ARMOR,
		// 0,
		// NULL,
		// ARMOR_SHARD,
		// ""
  ),

	/* QUAKED item_power_screen (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_power_screen",
		// Pickup_PowerArmor,
		// Use_PowerArmor,
		// Drop_PowerArmor,
		// NULL,
		// "misc/ar3_pkup.wav",
		"models/items/armor/screen/tris.md2", EF_ROTATE,
		null,
		"i_powerscreen",
		"Power Screen",
		// 0,
		// 60,
		// NULL,
		// IT_ARMOR,
		// 0,
		// NULL,
		// 0,
		// ""
  ),

	/* QUAKED item_power_shield (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"item_power_shield",
		// Pickup_PowerArmor,
		// Use_PowerArmor,
		// Drop_PowerArmor,
		// NULL,
		// "misc/ar3_pkup.wav",
		"models/items/armor/shield/tris.md2", EF_ROTATE,
		null,
		"i_powershield",
		"Power Shield",
		// 0,
		// 60,
		// NULL,
		// IT_ARMOR,
		// 0,
		// NULL,
		// 0,
		// "misc/power2.wav misc/power1.wav"
  ),

	/* weapon_blaster (.3 .3 1) (-16 -16 -16) (16 16 16)
	   always owned, never in the world */
	glistitem_t(
		"weapon_blaster",
		// NULL,
		// Use_Weapon,
		// NULL,
		// Weapon_Blaster,
		// "misc/w_pkup.wav",
		null, 0,
		"models/weapons/v_blast/tris.md2",
		"w_blaster",
		"Blaster",
		// 0,
		// 0,
		// NULL,
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_BLASTER,
		// NULL,
		// 0,
		// "weapons/blastf1a.wav misc/lasfly.wav"
  ),

	/* QUAKED weapon_shotgun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_shotgun",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_Shotgun,
		// "misc/w_pkup.wav",
		"models/weapons/g_shotg/tris.md2", EF_ROTATE,
		"models/weapons/v_shotg/tris.md2",
		"w_shotgun",
		"Shotgun",
		// 0,
		// 1,
		// "Shells",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_SHOTGUN,
		// NULL,
		// 0,
		// "weapons/shotgf1b.wav weapons/shotgr1b.wav"
  ),

	/* QUAKED weapon_supershotgun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_supershotgun",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_SuperShotgun,
		// "misc/w_pkup.wav",
		"models/weapons/g_shotg2/tris.md2", EF_ROTATE,
		"models/weapons/v_shotg2/tris.md2",
		"w_sshotgun",
		"Super Shotgun",
		// 0,
		// 2,
		// "Shells",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_SUPERSHOTGUN,
		// NULL,
		// 0,
		// "weapons/sshotf1b.wav"
  ),

	/* QUAKED weapon_machinegun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_machinegun",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_Machinegun,
		// "misc/w_pkup.wav",
		"models/weapons/g_machn/tris.md2", EF_ROTATE,
		"models/weapons/v_machn/tris.md2",
		"w_machinegun",
		"Machinegun",
		// 0,
		// 1,
		// "Bullets",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_MACHINEGUN,
		// NULL,
		// 0,
		// "weapons/machgf1b.wav weapons/machgf2b.wav weapons/machgf3b.wav weapons/machgf4b.wav weapons/machgf5b.wav"
  ),

	/* QUAKED weapon_chaingun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_chaingun",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_Chaingun,
		// "misc/w_pkup.wav",
		"models/weapons/g_chain/tris.md2", EF_ROTATE,
		"models/weapons/v_chain/tris.md2",
		"w_chaingun",
		"Chaingun",
		// 0,
		// 1,
		// "Bullets",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_CHAINGUN,
		// NULL,
		// 0,
		// "weapons/chngnu1a.wav weapons/chngnl1a.wav weapons/machgf3b.wav` weapons/chngnd1a.wav"
  ),

	/* QUAKED ammo_grenades (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"ammo_grenades",
		// Pickup_Ammo,
		// Use_Weapon,
		// Drop_Ammo,
		// Weapon_Grenade,
		// "misc/am_pkup.wav",
		"models/items/ammo/grenades/medium/tris.md2", 0,
		"models/weapons/v_handgr/tris.md2",
		"a_grenades",
		"Grenades",
		// 3,
		// 5,
		// "grenades",
		// IT_AMMO | IT_WEAPON,
		// WEAP_GRENADES,
		// NULL,
		// AMMO_GRENADES,
		// "weapons/hgrent1a.wav weapons/hgrena1b.wav weapons/hgrenc1b.wav weapons/hgrenb1a.wav weapons/hgrenb2a.wav "
  ),

	/* QUAKED weapon_grenadelauncher (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_grenadelauncher",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_GrenadeLauncher,
		// "misc/w_pkup.wav",
		"models/weapons/g_launch/tris.md2", EF_ROTATE,
		"models/weapons/v_launch/tris.md2",
		"w_glauncher",
		"Grenade Launcher",
		// 0,
		// 1,
		// "Grenades",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_GRENADELAUNCHER,
		// NULL,
		// 0,
		// "models/objects/grenade/tris.md2 weapons/grenlf1a.wav weapons/grenlr1b.wav weapons/grenlb1b.wav"
  ),

	/* QUAKED weapon_rocketlauncher (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_rocketlauncher",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_RocketLauncher,
		// "misc/w_pkup.wav",
		"models/weapons/g_rocket/tris.md2", EF_ROTATE,
		"models/weapons/v_rocket/tris.md2",
		"w_rlauncher",
		"Rocket Launcher",
		// 0,
		// 1,
		// "Rockets",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_ROCKETLAUNCHER,
		// NULL,
		// 0,
		// "models/objects/rocket/tris.md2 weapons/rockfly.wav weapons/rocklf1a.wav weapons/rocklr1b.wav models/objects/debris2/tris.md2"
  ),

	/* QUAKED weapon_hyperblaster (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_hyperblaster",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_HyperBlaster,
		// "misc/w_pkup.wav",
		"models/weapons/g_hyperb/tris.md2", EF_ROTATE,
		"models/weapons/v_hyperb/tris.md2",
		"w_hyperblaster",
		"HyperBlaster",
		// 0,
		// 1,
		// "Cells",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_HYPERBLASTER,
		// NULL,
		// 0,
		// "weapons/hyprbu1a.wav weapons/hyprbl1a.wav weapons/hyprbf1a.wav weapons/hyprbd1a.wav misc/lasfly.wav"
  ),

	/* QUAKED weapon_railgun (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_railgun",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_Railgun,
		// "misc/w_pkup.wav",
		"models/weapons/g_rail/tris.md2", EF_ROTATE,
		"models/weapons/v_rail/tris.md2",
		"w_railgun",
		"Railgun",
		// 0,
		// 1,
		// "Slugs",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_RAILGUN,
		// NULL,
		// 0,
		// "weapons/rg_hum.wav"
  ),

	/* QUAKED weapon_bfg (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"weapon_bfg",
		// Pickup_Weapon,
		// Use_Weapon,
		// Drop_Weapon,
		// Weapon_BFG,
		// "misc/w_pkup.wav",
		"models/weapons/g_bfg/tris.md2", EF_ROTATE,
		"models/weapons/v_bfg/tris.md2",
		"w_bfg",
		"BFG10K",
		// 0,
		// 50,
		// "Cells",
		// IT_WEAPON | IT_STAY_COOP,
		// WEAP_BFG,
		// NULL,
		// 0,
		// "sprites/s_bfg1.sp2 sprites/s_bfg2.sp2 sprites/s_bfg3.sp2 weapons/bfg__f1y.wav weapons/bfg__l1a.wav weapons/bfg__x1b.wav weapons/bfg_hum.wav"
  ),

	/* QUAKED ammo_shells (.3 .3 1) (-16 -16 -16) (16 16 16) */
	glistitem_t(
		"ammo_shells",
		// Pickup_Ammo,
		// NULL,
		// Drop_Ammo,
		// NULL,
		// "misc/am_pkup.wav",
		"models/items/ammo/shells/medium/tris.md2", 0,
		null,
		"a_shells",
		"Shells",
		// 3,
		// 10,
		// NULL,
		// IT_AMMO,
		// 0,
		// NULL,
		// AMMO_SHELLS,
		// ""
  ),

	/* QUAKED ammo_bullets (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"ammo_bullets",
	// 	Pickup_Ammo,
	// 	NULL,
	// 	Drop_Ammo,
	// 	NULL,
	// 	"misc/am_pkup.wav",
	// 	"models/items/ammo/bullets/medium/tris.md2", 0,
	// 	NULL,
	// 	"a_bullets",
		// "Bullets",
	// 	3,
	// 	50,
	// 	NULL,
	// 	IT_AMMO,
	// 	0,
	// 	NULL,
	// 	AMMO_BULLETS,
	// 	""
	// },

	// /* QUAKED ammo_cells (.3 .3 1) (-16 -16 -16) (16 16 16) */
	// {
	// 	"ammo_cells",
	// 	Pickup_Ammo,
	// 	NULL,
	// 	Drop_Ammo,
	// 	NULL,
	// 	"misc/am_pkup.wav",
	// 	"models/items/ammo/cells/medium/tris.md2", 0,
	// 	NULL,
	// 	"a_cells",
	// 	"Cells",
	// 	3,
	// 	50,
	// 	NULL,
	// 	IT_AMMO,
	// 	0,
	// 	NULL,
	// 	AMMO_CELLS,
	// 	""
	// },

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

	// {
	// 	NULL,
	// 	Pickup_Health,
	// 	NULL,
	// 	NULL,
	// 	NULL,
	// 	"items/pkup.wav",
	// 	NULL, 0,
	// 	NULL,
	// 	"i_health",
	// 	"Health",
	// 	3,
	// 	0,
	// 	NULL,
	// 	0,
	// 	0,
	// 	NULL,
	// 	0,
	// 	"items/s_health.wav items/n_health.wav items/l_health.wav items/m_health.wav"
	// },    
];

List<gitem_t> itemlist;

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