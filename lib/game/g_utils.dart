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
 * Misc. utility functions for the game logic.
 *
 * =======================================================================
 */
import 'dart:js_util';

import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'game.dart';
import 'g_main.dart';

/*
 * Searches all active entities for the next
 * one that holds the matching string at fieldofs
 * (use the FOFS() macro) in the structure.
 *
 * Searches beginning at the edict after from, or
 * the beginning. If NULL, NULL will be returned
 * if the end of the list is reached.
 */
edict_t G_Find(edict_t from, String field, String match) {

  int from_i = 0;
	if (from != null) {
		from_i = from.index + 1;
	}

	if (match == null || match.isEmpty) {
		return null;
	}

	for ( ; from_i < globals.num_edicts; from_i++) {
    from = g_edicts[from_i];
		if (!from.inuse) {
			continue;
		}

    final prob = getProperty(from, field);
		if (prob == null || !(prob is String)) {
			continue;
		}

		if (prob == match) {
			return from;
		}
	}

	return null;
}

G_InitEdict(edict_t e) {
	e.inuse = true;
	e.classname = "noclass";
	e.gravity = 1.0;
  e.s.number = e.index;
}

/*
 * Either finds a free edict, or allocates a
 * new one.  Try to avoid reusing an entity
 * that was recently freed, because it can
 * cause the client to think the entity
 * morphed into something else instead of
 * being removed and recreated, which can
 * cause interpolated angles and bad trails.
 */
edict_t G_Spawn() {

	var e = g_edicts[maxclients.integer + 1];

  int i;
	for (i = maxclients.integer + 1; i < globals.num_edicts; i++) {
	  e = g_edicts[i];
		/* the first couple seconds of
		   server time can involve a lot of
		   freeing and allocating, so relax
		   the replacement policy */
		if (!e.inuse && ((e.freetime < 2) || (level.time - e.freetime > 0.5))) {
			G_InitEdict(e);
			return e;
		}
	}

	if (i == game.maxentities) {
		Com_Error(ERR_DROP, "Game Error: ED_Alloc: no free edicts");
	}

	globals.num_edicts++;
	G_InitEdict(e);
	return e;
}

/*
 * Marks the edict as free
 */
G_FreeEdict(edict_t ed) {
	// gi.unlinkentity(ed); /* unlink from world */

	if (deathmatch.boolean || coop.boolean) {
		if (ed.index <= (maxclients.integer + BODY_QUEUE_SIZE)) {
			return;
		}
	} else {
		if (ed.index <= maxclients.integer) {
			return;
		}
	}

	ed.clear();
	ed.classname = "freed";
	ed.freetime = level.time;
	ed.inuse = false;
}