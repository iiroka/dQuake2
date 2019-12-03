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
 * The player trail, used by monsters to locate the player.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/game/g_ai.dart';

import '../game.dart';
import '../g_utils.dart';

const _TRAIL_LENGTH = 8;

List<edict_t> trail = List(_TRAIL_LENGTH);
int trail_head = 0;
bool trail_active = false;

int _NEXT(int n) => (((n) + 1) & (_TRAIL_LENGTH - 1));
int _PREV(int n) => (((n) - 1) & (_TRAIL_LENGTH - 1));

PlayerTrail_Init() {
	
	if (deathmatch.boolean) {
		return;
	}

	for (int n = 0; n < _TRAIL_LENGTH; n++) {
		trail[n] = G_Spawn();
		trail[n].classname = "player_trail";
	}

	trail_head = 0;
	trail_active = true;
}


edict_t PlayerTrail_PickFirst(edict_t self) {

	if (self == null) {
		return null;
	}

	if (trail_active == null) {
		return null;
	}

  int marker = trail_head;
	for (int n = _TRAIL_LENGTH; n > 0; n--) {
		if (trail[marker].timestamp <= self.monsterinfo.trail_time) {
			marker = _NEXT(marker);
		} else {
			break;
		}
	}

	if (visible(self, trail[marker])) {
		return trail[marker];
	}

	if (visible(self, trail[_PREV(marker)])) {
		return trail[_PREV(marker)];
	}

	return trail[marker];
}

edict_t PlayerTrail_PickNext(edict_t self) {

	if (self == null) {
		return null;
	}

	if (!trail_active) {
		return null;
	}

  int marker = trail_head;
	for (int n = _TRAIL_LENGTH; n > 0; n--) {
		if (trail[marker].timestamp <= self.monsterinfo.trail_time) {
			marker = _NEXT(marker);
		}
		else
		{
			break;
		}
	}

	return trail[marker];
}

edict_t PlayerTrail_LastSpot() {
	return trail[_PREV(trail_head)];
}
