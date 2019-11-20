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
 * This file implements the .cin video codec and the corresponding .pcx
 * bitmap decoder. .cin files are just a bunch of .pcx images.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/filesystem.dart';
import 'package:dQuakeWeb/shared/common.dart';

import 'client.dart';
import 'cl_screen.dart' show SCR_EndLoadingPlaque;

SCR_FinishCinematic() {
	/* tell the server to advance to the next map / cinematic */
	cls.netchan.message.WriteByte(clc_ops_e.clc_stringcmd.index);
	cls.netchan.message.Print("nextserver ${cl.servercount}\n");
}

SCR_PlayCinematic(String arg) async {
	// int width, height;
	// byte *palette;
	// char name[MAX_OSPATH], *dot;

	// In_FlushQueue();

	// /* make sure background music is not playing */
	// OGG_Stop();

	cl.cinematicframe = 0;
	var dot = arg.indexOf(".");

	/* static pcx image */
	if (dot >= 0 && arg.substring(dot) == ".pcx") {
		final name = "pics/" + arg;
		// SCR_LoadPCX(name, &cin.pic, &palette, &cin.width, &cin.height);
		cl.cinematicframe = -1;
		cl.cinematictime = 1;
		SCR_EndLoadingPlaque();
		cls.state = connstate_t.ca_active;

	// 	if (!cin.pic)
	// 	{
	// 		Com_Printf("%s not found.\n", name);
	// 		cl.cinematictime = 0;
	// 	}
	// 	else
	// 	{
	// 		memcpy(cl.cinematicpalette, palette, sizeof(cl.cinematicpalette));
	// 		Z_Free(palette);
	// 	}

		return;
	}

	final name = "video/" + arg;
  cl.cinematicBuffer = await FS_LoadFile(name);
  cl.cinematicOffset = 0;

	if (cl.cinematicBuffer == null) {
		SCR_FinishCinematic();
		cl.cinematictime = 0; /* done */
		return;
	}

	SCR_EndLoadingPlaque();

	cls.state = connstate_t.ca_active;

	// FS_Read(&width, 4, cl.cinematic_file);
	// FS_Read(&height, 4, cl.cinematic_file);
	// cin.width = LittleLong(width);
	// cin.height = LittleLong(height);

	// FS_Read(&cin.s_rate, 4, cl.cinematic_file);
	// cin.s_rate = LittleLong(cin.s_rate);
	// FS_Read(&cin.s_width, 4, cl.cinematic_file);
	// cin.s_width = LittleLong(cin.s_width);
	// FS_Read(&cin.s_channels, 4, cl.cinematic_file);
	// cin.s_channels = LittleLong(cin.s_channels);

	// Huff1TableInit();

	cl.cinematicframe = 0;
	// cin.pic = SCR_ReadNextFrame();
	// cl.cinematictime = Sys_Milliseconds();
}
