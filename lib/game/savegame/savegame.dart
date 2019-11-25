/*
 * Copyright (C) 1997-2001 Id Software, Inc.
 * Copyright (C) 2011 Knightmare
 * Copyright (C) 2011 Yamagi Burmeister
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
 * The savegame system.
 *
 * =======================================================================
 */

/*
 * This is the Quake 2 savegame system, fixed by Yamagi
 * based on an idea by Knightmare of kmquake2. This major
 * rewrite of the original g_save.c is much more robust
 * and portable since it doesn't use any function pointers.
 *
 * Inner workings:
 * When the game is saved all function pointers are
 * translated into human readable function definition strings.
 * The same way all mmove_t pointers are translated. This
 * human readable strings are then written into the file.
 * At game load the human readable strings are retranslated
 * into the actual function pointers and struct pointers. The
 * pointers are generated at each compilation / start of the
 * client, thus the pointers are always correct.
 *
 * Limitations:
 * While savegames survive recompilations of the game source
 * and bigger changes in the source, there are some limitation
 * which a nearly impossible to fix without a object orientated
 * rewrite of the game.
 *  - If functions or mmove_t structs that a referencenced
 *    inside savegames are added or removed (e.g. the files
 *    in tables/ are altered) the load functions cannot
 *    reconnect all pointers and thus not restore the game.
 *  - If the operating system is changed internal structures
 *    may change in an unrepairable way.
 *  - If the architecture is changed pointer length and
 *    other internal datastructures change in an
 *    incompatible way.
 *  - If the edict_t struct is changed, savegames
 *    will break.
 * This is not so bad as it looks since functions and
 * struct won't be added and edict_t won't be changed
 * if no big, sweeping changes are done. The operating
 * system and architecture are in the hands of the user.
 */
import '../game.dart';

/*
 * Fields to be saved
 */
List<field_t> fields = [
  field_t("classname", fieldtype_t.F_LSTRING),
  field_t("model", fieldtype_t.F_LSTRING),
  field_t("spawnflags", fieldtype_t.F_INT),
  field_t("speed", fieldtype_t.F_FLOAT),
  field_t("accel", fieldtype_t.F_FLOAT),
  field_t("decel", fieldtype_t.F_FLOAT),
  field_t("target", fieldtype_t.F_LSTRING),
  field_t("targetname", fieldtype_t.F_LSTRING),
  field_t("pathtarget", fieldtype_t.F_LSTRING),
  field_t("deathtarget", fieldtype_t.F_LSTRING),
  field_t("killtarget", fieldtype_t.F_LSTRING),
  field_t("combattarget", fieldtype_t.F_LSTRING),
  field_t("message", fieldtype_t.F_LSTRING),
  field_t("team", fieldtype_t.F_LSTRING),
  field_t("wait", fieldtype_t.F_FLOAT),
  field_t("delay", fieldtype_t.F_FLOAT),
  field_t("random", fieldtype_t.F_FLOAT),
  field_t("move_origin", fieldtype_t.F_VECTOR),
  field_t("move_angles", fieldtype_t.F_VECTOR),
  field_t("style", fieldtype_t.F_INT),
  field_t("count", fieldtype_t.F_INT),
  field_t("health", fieldtype_t.F_INT),
  field_t("sounds", fieldtype_t.F_INT),
  field_t("light", fieldtype_t.F_IGNORE),
  field_t("dmg", fieldtype_t.F_INT),
  field_t("mass", fieldtype_t.F_INT),
  field_t("volume", fieldtype_t.F_FLOAT),
  field_t("attenuation", fieldtype_t.F_FLOAT),
  field_t("map", fieldtype_t.F_LSTRING),
  field_t("origin", fieldtype_t.F_VECTOR, flags: FFL_ENTS),
  field_t("angles", fieldtype_t.F_VECTOR, flags: FFL_ENTS),
  field_t("angle", fieldtype_t.F_ANGLEHACK, flags: FFL_ENTS, fname: "angles"),
  field_t("goalentity", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("movetarget", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("enemy", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("oldenemy", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("activator", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("groundentity", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("teamchain", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("teammaster", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("owner", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("mynoise", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("mynoise2", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("target_ent", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("chain", fieldtype_t.F_EDICT, flags: FFL_NOSPAWN),
  field_t("prethink", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("think", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("blocked", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("touch", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("use", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("pain", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("die", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("stand", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("idle", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("search", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  field_t("walk", fieldtype_t.F_FUNCTION, flags: FFL_NOSPAWN),
  // field_t("run", FOFS(monsterinfo.run), F_FUNCTION, FFL_NOSPAWN),
  // field_t("dodge", FOFS(monsterinfo.dodge), F_FUNCTION, FFL_NOSPAWN),
  // field_t("attack", FOFS(monsterinfo.attack), F_FUNCTION, FFL_NOSPAWN),
  // field_t("melee", FOFS(monsterinfo.melee), F_FUNCTION, FFL_NOSPAWN),
  // field_t("sight", FOFS(monsterinfo.sight), F_FUNCTION, FFL_NOSPAWN),
  // field_t("checkattack", FOFS(monsterinfo.checkattack), F_FUNCTION, FFL_NOSPAWN),
  // field_t("currentmove", FOFS(monsterinfo.currentmove), F_MMOVE, FFL_NOSPAWN),
  // field_t("endfunc", FOFS(moveinfo.endfunc), F_FUNCTION, FFL_NOSPAWN),
  field_t("lip", fieldtype_t.F_INT, flags: FFL_SPAWNTEMP),
  field_t("distance", fieldtype_t.F_INT, flags: FFL_SPAWNTEMP),
  field_t("height", fieldtype_t.F_INT, flags: FFL_SPAWNTEMP),
  field_t("noise", fieldtype_t.F_LSTRING, flags: FFL_SPAWNTEMP),
  field_t("pausetime", fieldtype_t.F_FLOAT, flags: FFL_SPAWNTEMP),
  field_t("item", fieldtype_t.F_LSTRING, flags: FFL_SPAWNTEMP),
  // field_t("item", FOFS(item), F_ITEM),
  field_t("gravity", fieldtype_t.F_LSTRING, flags: FFL_SPAWNTEMP),
  field_t("sky", fieldtype_t.F_LSTRING, flags: FFL_SPAWNTEMP),
  field_t("skyrotate", fieldtype_t.F_FLOAT, flags: FFL_SPAWNTEMP),
  field_t("skyaxis", fieldtype_t.F_VECTOR, flags: FFL_SPAWNTEMP),
  field_t("minyaw", fieldtype_t.F_FLOAT, flags: FFL_SPAWNTEMP),
  field_t("maxyaw", fieldtype_t.F_FLOAT, flags: FFL_SPAWNTEMP),
  field_t("minpitch", fieldtype_t.F_FLOAT, flags: FFL_SPAWNTEMP),
  field_t("maxpitch", fieldtype_t.F_FLOAT, flags: FFL_SPAWNTEMP),
  field_t("nextmap", fieldtype_t.F_LSTRING, flags: FFL_SPAWNTEMP),
];
