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
 * Quake IIs legendary physic engine.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'game.dart';

/* ================================================================== */

G_RunEntity(edict_t ent) async {
	if (ent == null) {
		return;
	}

	// if (ent.prethink != null) {
	// 	ent->prethink(ent);
	// }

	switch (ent.movetype) {
		case movetype_t.MOVETYPE_PUSH:
		case movetype_t.MOVETYPE_STOP:
			// SV_Physics_Pusher(ent);
			break;
		case movetype_t.MOVETYPE_NONE:
			// SV_Physics_None(ent);
			break;
		case movetype_t.MOVETYPE_NOCLIP:
			// SV_Physics_Noclip(ent);
			break;
		case movetype_t.MOVETYPE_STEP:
			// SV_Physics_Step(ent);
			break;
		case movetype_t.MOVETYPE_TOSS:
		case movetype_t.MOVETYPE_BOUNCE:
		case movetype_t.MOVETYPE_FLY:
		case movetype_t.MOVETYPE_FLYMISSILE:
			// SV_Physics_Toss(ent);
			break;
		default:
			Com_Error(ERR_DROP, "Game Error: SV_Physics: bad movetype ${ent.movetype}");
	}
}
