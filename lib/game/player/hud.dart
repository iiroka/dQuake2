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
import 'package:dQuakeWeb/server/sv_game.dart';
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
