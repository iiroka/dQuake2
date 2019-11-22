/*
 * Copyright (C) 1997-2001 Id Software, Inc.
 * Copyright (C) 2019      Iiro Kaihlaniemi
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
 * API between the client and renderers.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/client/refresh/webgl/webgl_main.dart' show WebGLExports;
import 'ref.dart';
import '../client.dart';

// Hold the video state.
class viddef_t {
	int height = 0;
	int	width = 0;
}

// --------

// Renderer load, restart and shutdown
// -----------------------------------

// Global console variables.
cvar_t vid_gamma;
cvar_t vid_fullscreen;
cvar_t vid_renderer;

// Global video state, used throughout the client.
viddef_t viddef = viddef_t();

refexport_t re;

/*
 * Loads and initializes a renderer.
 */
Future<bool> VID_LoadRenderer() async {
	// If the refresher is already active we need
	// to shut it down before loading a new one
	// VID_ShutdownRenderer();

	// Log what we're doing.
	Com_Printf("----- refresher initialization -----\n");
  if (vid_renderer.string == "webgl") {
    re = WebGLExports();
  } else {
	  Com_Printf("Unsupported renderer ${vid_renderer.string}\n");
  	Com_Printf("------------------------------------\n\n");
    return false;
  }

  if (!await re.Init()) {
		// VID_ShutdownRenderer();

		Com_Printf("ERROR: Loading ${vid_renderer.string} as rendering backend failed!\n");
		Com_Printf("------------------------------------\n\n");

		return false;

  }

	Com_Printf("Successfully loaded ${vid_renderer.string} as rendering backend\n");
	Com_Printf("------------------------------------\n\n");

	return true;
}

/*
 * Checks if a renderer changes was requested and executes it.
 * Inclusive fallback through all renderers. :)
 */
VID_CheckChanges() async {
	// FIXME: Not with vid_fullscreen, should be a dedicated variable.
	// Sounds easy but this vid_fullscreen hack is really messy and
	// interacts with several critical places in both the client and
	// the renderers...
	if (vid_fullscreen.modified) {
		// Stop sound, because the clients blocks while
		// we're reloading the renderer. The sound system
		// would screw up it's internal timings.
		// S_StopAllSounds();

		// Reset the client side of the renderer state.
		cl.refresh_prepped = false;
		// cl.cinematicpalette_active = false;

		// More or less blocks the client.
		cls.disable_screen = 1.0;

		// Mkay, let's try our luck.
		while (!await VID_LoadRenderer()) {
			// We try: gl3 -> gl1 -> soft.
			if (vid_renderer.string == "webgl") {
				Com_Printf("Retrying with soft...\n");
				Cvar_Set("vid_renderer", "soft");
			} else if (vid_renderer.string == "soft") {
				// Sorry, no usable renderer found.
				Com_Error(ERR_FATAL, "No usable renderer found!\n");
			} else {
				// User forced something stupid.
				Com_Printf("Retrying with webgl...\n");
				Cvar_Set("vid_renderer", "webgl");
			}
		}

		// Unblock the client.
		cls.disable_screen = 0.0;
	}
}
/*
 * Initializes the video stuff.
 */
VID_Init() async {
	// Console variables
	vid_gamma = Cvar_Get("vid_gamma", "1.0", CVAR_ARCHIVE);
	vid_fullscreen = Cvar_Get("vid_fullscreen", "0", CVAR_ARCHIVE);
	vid_renderer = Cvar_Get("vid_renderer", "webgl", CVAR_ARCHIVE);

	// Commands
	// Cmd_AddCommand("vid_restart", VID_Restart_f);
	// Cmd_AddCommand("vid_listmodes", VID_ListModes_f);

	// Initializes the video backend. This is NOT the renderer
	// itself, just the client side support stuff!
	// if (!GLimp_Init()) {
		// Com_Error(ERR_FATAL, "Couldn't initialize the graphics subsystem!\n");
	// }

	// Load the renderer and get things going.
	await VID_CheckChanges();
}

// --------

// Video mode array
// ----------------

class vidmode_t {
	final String description;
	final int width, height;
	final int mode;

  const vidmode_t(this.description, this.width, this.height, this.mode);
}

// This must be the same as VID_MenuInit()->resolutions[] in videomenu.c!
const vid_modes = [
	vidmode_t("Mode  0:  320x240", 320, 240, 0),
	vidmode_t("Mode  1:  400x300", 400, 300, 1),
	vidmode_t("Mode  2:  512x384", 512, 384, 2),
	vidmode_t("Mode  3:  640x400", 640, 400, 3),
	vidmode_t("Mode  4:  640x480", 640, 480, 4),
	vidmode_t("Mode  5:  800x500", 800, 500, 5),
	vidmode_t("Mode  6:  800x600", 800, 600, 6),
	vidmode_t("Mode  7:  960x720", 960, 720, 7),
	vidmode_t("Mode  8: 1024x480", 1024, 480, 8),
	vidmode_t("Mode  9: 1024x640", 1024, 640, 9),
	vidmode_t("Mode 10: 1024x768", 1024, 768, 10),
	vidmode_t("Mode 11: 1152x768", 1152, 768, 11),
	vidmode_t("Mode 12: 1152x864", 1152, 864, 12),
	vidmode_t("Mode 13: 1280x800", 1280, 800, 13),
	vidmode_t("Mode 14: 1280x720", 1280, 720, 14),
	vidmode_t("Mode 15: 1280x960", 1280, 960, 15),
	vidmode_t("Mode 16: 1280x1024", 1280, 1024, 16),
	vidmode_t("Mode 17: 1366x768", 1366, 768, 17),
	vidmode_t("Mode 18: 1440x900", 1440, 900, 18),
	vidmode_t("Mode 19: 1600x1200", 1600, 1200, 19),
	vidmode_t("Mode 20: 1680x1050", 1680, 1050, 20),
	vidmode_t("Mode 21: 1920x1080", 1920, 1080, 21),
	vidmode_t("Mode 22: 1920x1200", 1920, 1200, 22),
	vidmode_t("Mode 23: 2048x1536", 2048, 1536, 23),
	vidmode_t("Mode 24: 2560x1080", 2560, 1080, 24),
	vidmode_t("Mode 25: 2560x1440", 2560, 1440, 25),
	vidmode_t("Mode 26: 2560x1600", 2560, 1600, 26),
	vidmode_t("Mode 27: 3440x1440", 3440, 1440, 27),
	vidmode_t("Mode 28: 3840x1600", 3840, 1600, 28),
	vidmode_t("Mode 29: 3840x2160", 3840, 2160, 29),
	vidmode_t("Mode 30: 4096x2160", 4096, 2160, 30),
	vidmode_t("Mode 31: 5120x2880", 5120, 2880, 31),
];

/*
 * Callback function for the 'vid_listmodes' cmd.
 */
// void
// VID_ListModes_f(void)
// {
// 	int i;

// 	Com_Printf("Supported video modes (r_mode):\n");

// 	for (i = 0; i < VID_NUM_MODES; ++i)
// 	{
// 		Com_Printf("  %s\n", vid_modes[i].description);
// 	}
// 	Com_Printf("  Mode -1: r_customwidth x r_customheight\n");
// }

/*
 * Returns informations about the given mode.
 */
vidmode_t VID_GetModeInfo(int mode) {
	if ((mode < 0) || (mode >= vid_modes.length)) {
		return null;
	}

	return vid_modes[mode];
}
