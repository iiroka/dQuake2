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
 * Game command processing.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/game/g_items.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'game.dart';
import 'player/hud.dart' show InventoryMessage;

SelectNextItem(edict_t ent, int itflags) {
	// gclient_t *cl;
	// int i, index;
	// gitem_t *it;

	if (ent == null) {
		return;
	}

	final cl = ent.client as gclient_t;

	if (cl.chase_target != null) {
		// ChaseNext(ent);
		return;
	}

	/* scan  for the next valid one */
	for (int i = 1; i <= MAX_ITEMS; i++) {
		final index = (cl.pers.selected_item + i) % MAX_ITEMS;

		if (cl.pers.inventory[index] == 0) {
			continue;
		}

		final it = itemlist[index];
		if (it.use == null) {
			continue;
		}

		if ((it.flags & itflags) == 0) {
			continue;
		}

		cl.pers.selected_item = index;
		return;
	}

	cl.pers.selected_item = -1;
}

ValidateSelectedItem(edict_t ent) {

	if (ent == null) {
		return;
	}

	final cl = ent.client as gclient_t;

	if (cl.pers.inventory[cl.pers.selected_item] != 0) {
		return; /* valid */
	}

	SelectNextItem(ent, -1);
}

/*
 * Use an inventory item
 */
_Cmd_Use_f(edict_t ent, List<String> args) {
	// int index;
	// gitem_t *it;
	// char *s;

	if (ent == null) {
		return;
	}

  var str = StringBuffer();
  for (int i = 1; i < args.length; i++) {
    str.write(args[i]);
    if (i != (args.length - 1)) {
      str.write(" ");
    }
  }
  final s = str.toString();
	final it = FindItem(s);

	if (it == null) {
		PF_cprintf(ent, PRINT_HIGH, "unknown item: $s\n");
		return;
	}

	if (it.use == null) {
		PF_cprintf(ent, PRINT_HIGH, "Item is not usable.\n");
		return;
	}

	final index = it.index;

	if ((ent.client as gclient_t).pers.inventory[index] == 0) {
		PF_cprintf(ent, PRINT_HIGH, "Out of item: $s\n");
		return;
	}

	it.use(ent, it);
}

_Cmd_Inven_f(edict_t ent) {

	if (ent == null) {
		return;
	}

	final cl = ent.client as gclient_t;

	cl.showscores = false;
	cl.showhelp = false;

	if (cl.showinventory) {
		cl.showinventory = false;
		return;
	}

	cl.showinventory = true;

	InventoryMessage(ent);
	PF_Unicast(ent, true);
}

_Cmd_InvUse_f(edict_t ent) {

	if (ent == null) {
		return;
	}

	ValidateSelectedItem(ent);

	if ((ent.client as gclient_t).pers.selected_item == -1) {
		PF_cprintf(ent, PRINT_HIGH, "No item to use.\n");
		return;
	}

	final it = itemlist[(ent.client as gclient_t).pers.selected_item];

	if (it.use == null) {
		PF_cprintf(ent, PRINT_HIGH, "Item is not usable.\n");
		return;
	}

	it.use(ent, it);
}

G_ClientCommand(edict_t ent, List<String> args) {

	if (ent == null) {
		return;
	}

	if (ent.client == null) {
		return; /* not fully in game yet */
	}

// 	cmd = gi.argv(0);

// 	if (Q_stricmp(cmd, "players") == 0)
// 	{
// 		Cmd_Players_f(ent);
// 		return;
// 	}

// 	if (Q_stricmp(cmd, "say") == 0)
// 	{
// 		Cmd_Say_f(ent, false, false);
// 		return;
// 	}

// 	if (Q_stricmp(cmd, "say_team") == 0)
// 	{
// 		Cmd_Say_f(ent, true, false);
// 		return;
// 	}

// 	if (Q_stricmp(cmd, "score") == 0)
// 	{
// 		Cmd_Score_f(ent);
// 		return;
// 	}

// 	if (Q_stricmp(cmd, "help") == 0)
// 	{
// 		Cmd_Help_f(ent);
// 		return;
// 	}

	if (level.intermissiontime != 0) {
		return;
	}

  if (args[0] == "use") {
    _Cmd_Use_f(ent, args);
// 	}
// 	else if (Q_stricmp(cmd, "drop") == 0)
// 	{
// 		Cmd_Drop_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "give") == 0)
// 	{
// 		Cmd_Give_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "god") == 0)
// 	{
// 		Cmd_God_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "notarget") == 0)
// 	{
// 		Cmd_Notarget_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "noclip") == 0)
// 	{
// 		Cmd_Noclip_f(ent);
	} else if (args[0] == "inven") {
		_Cmd_Inven_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "invnext") == 0)
// 	{
// 		SelectNextItem(ent, -1);
// 	}
// 	else if (Q_stricmp(cmd, "invprev") == 0)
// 	{
// 		SelectPrevItem(ent, -1);
// 	}
// 	else if (Q_stricmp(cmd, "invnextw") == 0)
// 	{
// 		SelectNextItem(ent, IT_WEAPON);
// 	}
// 	else if (Q_stricmp(cmd, "invprevw") == 0)
// 	{
// 		SelectPrevItem(ent, IT_WEAPON);
// 	}
// 	else if (Q_stricmp(cmd, "invnextp") == 0)
// 	{
// 		SelectNextItem(ent, IT_POWERUP);
// 	}
// 	else if (Q_stricmp(cmd, "invprevp") == 0)
// 	{
// 		SelectPrevItem(ent, IT_POWERUP);
// 	}
  } else if (args[0] == "invuse") {
		_Cmd_InvUse_f(ent);
	}
// 	else if (Q_stricmp(cmd, "invdrop") == 0)
// 	{
// 		Cmd_InvDrop_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "weapprev") == 0)
// 	{
// 		Cmd_WeapPrev_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "weapnext") == 0)
// 	{
// 		Cmd_WeapNext_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "weaplast") == 0)
// 	{
// 		Cmd_WeapLast_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "kill") == 0)
// 	{
// 		Cmd_Kill_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "putaway") == 0)
// 	{
// 		Cmd_PutAway_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "wave") == 0)
// 	{
// 		Cmd_Wave_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "playerlist") == 0)
// 	{
// 		Cmd_PlayerList_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "teleport") == 0)
// 	{
// 		Cmd_Teleport_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "listentities") == 0)
// 	{
// 		Cmd_ListEntities_f(ent);
// 	}
// 	else if (Q_stricmp(cmd, "cycleweap") == 0)
// 	{
// 		Cmd_CycleWeap_f(ent);
// 	}
// 	else /* anything that doesn't match a command will be a chat */
// 	{
// 		Cmd_Say_f(ent, false, true);
// 	}
  else {
    print("Unknown user command ${args[0]}");
  }
}
