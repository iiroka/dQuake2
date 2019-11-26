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
 * Interface between the server and the game module.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/collision.dart' show CM_InlineModel;
import 'package:dQuakeWeb/game/g_main.dart' show Quake2Game;
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'server.dart';
import 'sv_init.dart' show SV_ModelIndex;
import 'sv_main.dart';
import 'sv_send.dart';
import 'sv_world.dart';

game_export_t ge;

/*
 * Sends the contents of the mutlicast buffer to a single client
 */
PF_Unicast(edict_s ent, bool reliable) {

	if (ent == null) {
		return;
	}

	final p = ent.index;

	if ((p < 1) || (p > maxclients.integer)) {
		return;
	}

	final client = svs.clients[p - 1];

	if (reliable) {
		sv.multicast.Write(sv.multicast.Data());
	} else {
		sv.multicast.Write(sv.multicast.Data());
	}

	sv.multicast.Clear();
}

/*
 * Print to a single client
 */
PF_cprintf(edict_s ent, int level, String msg) {

	if (ent != null) {
		if ((ent.index < 1) || (ent.index > maxclients.integer)) {
			Com_Error(ERR_DROP, "cprintf to a non-client");
		}
	}

	if (ent != null) {
		SV_ClientPrintf(svs.clients[ent.index - 1], level, msg);
	} else {
		Com_Printf(msg);
	}
}

PF_Configstring(int index, String val) {
	if ((index < 0) || (index >= MAX_CONFIGSTRINGS)) {
		Com_Error(ERR_DROP, "configstring: bad index $index\n");
	}

	if (val == null) {
		val = "";
	}

	/* change the string in sv */
	sv.configstrings[index] = val;

	if (sv.state != server_state_t.ss_loading) {
		/* send the update to everyone */
		sv.multicast.Clear();
		sv.multicast.WriteChar(svc_ops_e.svc_configstring.index);
		sv.multicast.WriteShort(index);
		sv.multicast.WriteString(val);

		SV_Multicast([0,0,0], multicast_t.MULTICAST_ALL_R);
	}
}

PF_WriteChar(int c) => sv.multicast.WriteChar(c);
PF_WriteByte(int c) => sv.multicast.WriteByte(c);
PF_WriteShort(int c) => sv.multicast.WriteShort(c);
PF_WriteLong(int c) => sv.multicast.WriteLong(c);
PF_WriteFloat(double c) => sv.multicast.WriteFloat(c);
PF_WriteString(String s) => sv.multicast.WriteString(s);
PF_WritePos(List<double> pos) => sv.multicast.WritePos(pos);
PF_WriteDir(List<double> dir) => sv.multicast.WriteDir(dir);
PF_WriteAngle(double c) => sv.multicast.WriteAngle(c);


/*
 * Also sets mins and maxs for inline bmodels
 */
PF_setmodel(edict_s ent, String name) {

	if (name == null) {
		Com_Error(ERR_DROP, "PF_setmodel: NULL");
	}

	int i = SV_ModelIndex(name);

	ent.s.modelindex = i;

	/* if it is an inline model, get
	   the size information for it */
	if (name[0] == '*') {
		final mod = CM_InlineModel(name);
    ent.mins.setAll(0, mod.mins);
    ent.maxs.setAll(0, mod.maxs);
		SV_LinkEdict(ent);
	}
}


/*
 * Init the game subsystem for a new map
 */
SV_InitGameProgs() {
	// game_import_t import;

	/* unload anything we have now */
	if (ge != null) {
		// SV_ShutdownGameProgs();
	}

	Com_Printf("-------- game initialization -------\n");

	/* load a new game dll */
// 	import.multicast = SV_Multicast;
// 	import.unicast = PF_Unicast;
// 	import.bprintf = SV_BroadcastPrintf;
// 	import.dprintf = PF_dprintf;
// 	import.cprintf = PF_cprintf;
// 	import.centerprintf = PF_centerprintf;
// 	import.error = PF_error;

// 	import.linkentity = SV_LinkEdict;
// 	import.unlinkentity = SV_UnlinkEdict;
// 	import.BoxEdicts = SV_AreaEdicts;
// 	import.trace = SV_Trace;
// 	import.pointcontents = SV_PointContents;
// 	import.setmodel = PF_setmodel;
// 	import.inPVS = PF_inPVS;
// 	import.inPHS = PF_inPHS;
// 	import.Pmove = Pmove;

// 	import.modelindex = SV_ModelIndex;
// 	import.soundindex = SV_SoundIndex;
// 	import.imageindex = SV_ImageIndex;

// 	import.configstring = PF_Configstring;
// 	import.sound = PF_StartSound;
// 	import.positioned_sound = SV_StartSound;

// 	import.WriteChar = PF_WriteChar;
// 	import.WriteByte = PF_WriteByte;
// 	import.WriteShort = PF_WriteShort;
// 	import.WriteLong = PF_WriteLong;
// 	import.WriteFloat = PF_WriteFloat;
// 	import.WriteString = PF_WriteString;
// 	import.WritePosition = PF_WritePos;
// 	import.WriteDir = PF_WriteDir;
// 	import.WriteAngle = PF_WriteAngle;

// 	import.TagMalloc = Z_TagMalloc;
// 	import.TagFree = Z_Free;
// 	import.FreeTags = Z_FreeTags;

// 	import.cvar = Cvar_Get;
// 	import.cvar_set = Cvar_Set;
// 	import.cvar_forceset = Cvar_ForceSet;

// 	import.argc = Cmd_Argc;
// 	import.argv = Cmd_Argv;
// 	import.args = Cmd_Args;
// 	import.AddCommandString = Cbuf_AddText;

// #ifndef DEDICATED_ONLY
// 	import.DebugGraph = SCR_DebugGraph;
// #endif

// 	import.SetAreaPortalState = CM_SetAreaPortalState;
// 	import.AreasConnected = CM_AreasConnected;

  ge = Quake2Game();
	// ge = (game_export_t *)Sys_GetGameAPI(&import);

	// if (ge == null) {
	// 	Com_Error(ERR_DROP, "failed to load game DLL");
	// }

	// if (ge->apiversion != GAME_API_VERSION)
	// {
	// 	Com_Error(ERR_DROP, "game is version %i, not %i", ge->apiversion,
	// 			GAME_API_VERSION);
	// }

	ge.Init();

	Com_Printf("------------------------------------\n\n");
}
