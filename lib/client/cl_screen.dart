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
 * This file implements the 2D stuff. For example the HUD and the
 * networkgraph.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/frame.dart' show developer;
import 'package:dQuakeWeb/shared/shared.dart';
import 'vid/vid.dart';
import 'cl_console.dart' show con, Con_CheckResize, Con_DrawConsole, DrawStringScaled;
import 'client.dart';
import 'cl_view.dart' show V_RenderView;
import 'menu/menu.dart' show M_Draw;

double scr_con_current = 0.0; /* aproaches scr_conlines at scr_conspeed */
double scr_conlines = 0.0; /* 0.0 to 1.0 lines of console to display */

bool scr_initialized = false; /* ready to draw */

int scr_draw_loading = 0;

class vrect_t {
	int x = 0,y = 0, width = 0,height = 0;
}

vrect_t scr_vrect = vrect_t(); /* position of render window on screen */

cvar_t scr_viewsize;
cvar_t scr_conspeed;
cvar_t scr_centertime;
cvar_t scr_showturtle;
cvar_t scr_showpause;

cvar_t scr_netgraph;
cvar_t scr_timegraph;
cvar_t scr_debuggraph;
cvar_t scr_graphheight;
cvar_t scr_graphscale;
cvar_t scr_graphshift;
cvar_t scr_drawall;

cvar_t r_hudscale; /* named for consistency with R1Q2 */
cvar_t r_consolescale;
cvar_t r_menuscale;

class dirty_t {
	int x1 = 0, y1 = 0, x2 = 0, y2 = 0;

  copy(dirty_t other) {
    this.x1 = other.x1;
    this.y1 = other.y1;
    this.x2 = other.x2;
    this.y2 = other.y2;
  }
}

dirty_t scr_dirty = dirty_t();
List<dirty_t> scr_old_dirty = [dirty_t(), dirty_t()];

SCR_BeginLoadingPlaque() async {
	// S_StopAllSounds();
	cl.sound_prepped = false; /* don't play ambients */

	// OGG_Stop();

	if (cls.disable_screen != 0) {
		return;
	}

	if (developer.boolean) {
		return;
	}

	if (cls.state == connstate_t.ca_disconnected) {
		/* if at console, don't bring up the plaque */
		return;
	}

	if (cls.key_dest == keydest_t.key_console) {
		return;
	}

	if (cl.cinematictime > 0) {
		scr_draw_loading = 2; /* clear to balack first */
	} else {
		scr_draw_loading = 1;
	}

	await SCR_UpdateScreen();

	scr_draw_loading = 0;

	// SCR_StopCinematic();
	cls.disable_screen = Sys_Milliseconds().toDouble();
	cls.disable_servercount = cl.servercount;
}

SCR_EndLoadingPlaque() {
	cls.disable_screen = 0;
	// Con_ClearNotify();
}


SCR_AddDirtyPoint(int x, int y) {
	if (x < scr_dirty.x1)
	{
		scr_dirty.x1 = x;
	}

	if (x > scr_dirty.x2)
	{
		scr_dirty.x2 = x;
	}

	if (y < scr_dirty.y1)
	{
		scr_dirty.y1 = y;
	}

	if (y > scr_dirty.y2)
	{
		scr_dirty.y2 = y;
	}
}

SCR_DirtyScreen() {
	SCR_AddDirtyPoint(0, 0);
	SCR_AddDirtyPoint(viddef.width - 1, viddef.height - 1);
}

/*
 * Clear any parts of the tiled background that were drawn on last frame
 */
SCR_TileClear() async {

	if (scr_con_current == 1.0) {
		return; /* full screen console */
	}

	if (scr_viewsize.integer == 100) {
		return; /* full screen rendering */
	}

	// if (cl.cinematictime > 0)
	// {
	// 	return; /* full screen cinematic */
	// }

	/* erase rect will be the union of the past three
	   frames so tripple buffering works properly */
  dirty_t clear = dirty_t();
	clear.copy(scr_dirty);

	for (int i = 0; i < 2; i++)
	{
		if (scr_old_dirty[i].x1 < clear.x1)
		{
			clear.x1 = scr_old_dirty[i].x1;
		}

		if (scr_old_dirty[i].x2 > clear.x2)
		{
			clear.x2 = scr_old_dirty[i].x2;
		}

		if (scr_old_dirty[i].y1 < clear.y1)
		{
			clear.y1 = scr_old_dirty[i].y1;
		}

		if (scr_old_dirty[i].y2 > clear.y2)
		{
			clear.y2 = scr_old_dirty[i].y2;
		}
	}

	scr_old_dirty[1] = scr_old_dirty[0];
	scr_old_dirty[0] = scr_dirty;

	scr_dirty.x1 = 9999;
	scr_dirty.x2 = -9999;
	scr_dirty.y1 = 9999;
	scr_dirty.y2 = -9999;

	/* don't bother with anything convered by the console */
	int top = (scr_con_current * viddef.height).toInt();

	if (top >= clear.y1) {
		clear.y1 = top;
	}

	if (clear.y2 <= clear.y1)
	{
		return; /* nothing disturbed */
	}

	top = scr_vrect.y;
	int bottom = top + scr_vrect.height - 1;
	int left = scr_vrect.x;
	int right = left + scr_vrect.width - 1;

	if (clear.y1 < top) {
		/* clear above view screen */
		int i = clear.y2 < top - 1 ? clear.y2 : top - 1;
		await re.DrawTileClear(clear.x1, clear.y1,
				clear.x2 - clear.x1 + 1, i - clear.y1 + 1, "backtile");
		clear.y1 = top;
	}

	if (clear.y2 > bottom)
	{
		/* clear below view screen */
		int i = clear.y1 > bottom + 1 ? clear.y1 : bottom + 1;
		await re.DrawTileClear(clear.x1, i,
				clear.x2 - clear.x1 + 1, clear.y2 - i + 1, "backtile");
		clear.y2 = bottom;
	}

	if (clear.x1 < left)
	{
		/* clear left of view screen */
		int i = clear.x2 < left - 1 ? clear.x2 : left - 1;
		await re.DrawTileClear(clear.x1, clear.y1,
				i - clear.x1 + 1, clear.y2 - clear.y1 + 1, "backtile");
		clear.x1 = left;
	}

	if (clear.x2 > right)
	{
		/* clear left of view screen */
		int i = clear.x1 > right + 1 ? clear.x1 : right + 1;
		await re.DrawTileClear(i, clear.y1,
				clear.x2 - i + 1, clear.y2 - clear.y1 + 1, "backtile");
		clear.x2 = right;
	}
}

String scr_centerstring = "";
double scr_centertime_start = 0; /* for slow victory printing */
double scr_centertime_off = 0;
int scr_center_lines = 0;
int scr_erase_center = 0;

SCR_DrawCenterString() {
	int l;
	int j;
	int x, y;
  const int char_unscaled_width  = 8;
  const int char_unscaled_height = 8;

	/* the finale prints the characters one at a time */
	int remaining = 9999;

	scr_erase_center = 0;
	int start = 0;
	final double scale = SCR_GetConsoleScale();

	if (scr_center_lines <= 4) {
		y = (viddef.height * 0.35) ~/ scale;
	}

	else
	{
		y = 48 ~/ scale;
	}

	do
	{
		/* scan the width of the line */
		for (l = 0; l < 40; l++) {
			if ((start+l) > scr_centerstring.length || (scr_centerstring[start+l] == '\n')) {
				break;
			}
		}

		x = ((viddef.width ~/ scale) - (l * char_unscaled_width)) ~/ 2;
		SCR_AddDirtyPoint(x, y);

		for (j = 0; j < l; j++, x += char_unscaled_width) {
			re.DrawCharScaled((x * scale).toInt(), (y * scale).toInt(), scr_centerstring.codeUnitAt(start+j), scale);

			if (remaining-- == 0) {
				return;
			}
		}

		SCR_AddDirtyPoint(x, y + char_unscaled_height);

		y += char_unscaled_height;

		while (start < scr_centerstring.length && scr_centerstring[start] != '\n') {
			start++;
		}

		if (start >= scr_centerstring.length) {
			break;
		}

		start++; /* skip the \n */
	} while (true);
}


SCR_CheckDrawCenterString() {
	scr_centertime_off -= cls.rframetime;

	if (scr_centertime_off <= 0) {
		return;
	}

	SCR_DrawCenterString();
}


/*
 * Sets scr_vrect, the coordinates of the rendered window
 */
SCR_CalcVrect() {

	/* bound viewsize */
	if (scr_viewsize.integer < 40) {
		Cvar_Set("viewsize", "40");
	}

	if (scr_viewsize.integer > 100) {
		Cvar_Set("viewsize", "100");
	}

	int size = scr_viewsize.integer;

	scr_vrect.width = viddef.width * size ~/ 100;
	scr_vrect.height = viddef.height * size ~/ 100;

	scr_vrect.x = (viddef.width - scr_vrect.width) ~/ 2;
	scr_vrect.y = (viddef.height - scr_vrect.height) ~/ 2;
}

SCR_Init() {
	scr_viewsize = Cvar_Get("viewsize", "100", CVAR_ARCHIVE);
	scr_conspeed = Cvar_Get("scr_conspeed", "3", 0);
	scr_centertime = Cvar_Get("scr_centertime", "2.5", 0);
	scr_showturtle = Cvar_Get("scr_showturtle", "0", 0);
	scr_showpause = Cvar_Get("scr_showpause", "1", 0);
	scr_netgraph = Cvar_Get("netgraph", "0", 0);
	scr_timegraph = Cvar_Get("timegraph", "0", 0);
	scr_debuggraph = Cvar_Get("debuggraph", "0", 0);
	scr_graphheight = Cvar_Get("graphheight", "32", 0);
	scr_graphscale = Cvar_Get("graphscale", "1", 0);
	scr_graphshift = Cvar_Get("graphshift", "0", 0);
	scr_drawall = Cvar_Get("scr_drawall", "0", 0);
	r_hudscale = Cvar_Get("r_hudscale", "-1", CVAR_ARCHIVE);
	r_consolescale = Cvar_Get("r_consolescale", "-1", CVAR_ARCHIVE);
	r_menuscale = Cvar_Get("r_menuscale", "-1", CVAR_ARCHIVE);

	/* register our commands */
	// Cmd_AddCommand("timerefresh", SCR_TimeRefresh_f);
	// Cmd_AddCommand("loading", SCR_Loading_f);
	// Cmd_AddCommand("sizeup", SCR_SizeUp_f);
	// Cmd_AddCommand("sizedown", SCR_SizeDown_f);
	// Cmd_AddCommand("sky", SCR_Sky_f);

	scr_initialized = true;
}

SCR_DrawConsole() async
{
	Con_CheckResize();

	if ((cls.state == connstate_t.ca_disconnected) || (cls.state == connstate_t.ca_connecting))
	{
		/* forced full screen console */
		await Con_DrawConsole(1.0);
		return;
	}

	if ((cls.state != connstate_t.ca_active) || !cl.refresh_prepped)
	{
		/* connected, but can't render */
		await Con_DrawConsole(0.5);
		re.DrawFill(0, viddef.height ~/ 2, viddef.width, viddef.height ~/ 2, 0);
		return;
	}

	if (scr_con_current != 0)
	{
		await Con_DrawConsole(scr_con_current);
	}
	else
	{
		// if ((cls.key_dest == key_game) || (cls.key_dest == key_message))
		// {
		// 	Con_DrawNotify(); /* only draw notify in game */
		// }
	}
}

const STAT_MINUS = 10;
List<List<String>> sb_nums = [
	[
		"num_0", "num_1", "num_2", "num_3", "num_4", "num_5",
		"num_6", "num_7", "num_8", "num_9", "num_minus"
  ],
	[
		"anum_0", "anum_1", "anum_2", "anum_3", "anum_4", "anum_5",
		"anum_6", "anum_7", "anum_8", "anum_9", "anum_minus"
  ]
];

const ICON_WIDTH = 24;
const ICON_HEIGHT = 24;
const CHAR_WIDTH = 16;
const ICON_SPACE = 8;


SCR_DrawFieldScaled(int x, int y, int color, int width, int value, double factor) async {

	if (width < 1) {
		return;
	}

	/* draw number string */
	if (width > 5) {
		width = 5;
	}

	SCR_AddDirtyPoint(x, y);
	SCR_AddDirtyPoint(x + ((width * CHAR_WIDTH + 2)*factor).toInt(), y + (factor*24).toInt());

	final num = value.toString();
	var l = num.length;

	if (l > width) {
		l = width;
	}

	x += ((2 + CHAR_WIDTH * (width - l)) * factor).toInt();

  final zero = '0'.codeUnitAt(0);
	for (int i = 0; i < l; i++) {
    int frame;
		if (num[i] == '-') {
			frame = STAT_MINUS;
		} else {
			frame = num.codeUnitAt(i) - zero;
		}

		await re.DrawPicScaled(x, y, sb_nums[color][frame], factor);
		x += (CHAR_WIDTH*factor).toInt();
	}
}

SCR_DrawField(int x, int y, int color, int width, int value) async => await SCR_DrawFieldScaled(x, y, color, width, value, 1.0);

/*
 * Allows rendering code to cache all needed sbar graphics
 */
SCR_TouchPics() async {

	for (int i = 0; i < 2; i++) {
		for (int j = 0; j < 11; j++) {
			await re.DrawFindPic(sb_nums[i][j]);
		}
	}

	// if (crosshair.boolean) {
	// 	if ((crosshair->value > 3) || (crosshair->value < 0))
	// 	{
	// 		crosshair->value = 3;
	// 	}

	// 	Com_sprintf(crosshair_pic, sizeof(crosshair_pic), "ch%i",
	// 			(int)(crosshair->value));
	// 	Draw_GetPicSize(&crosshair_width, &crosshair_height, crosshair_pic);

	// 	if (!crosshair_width)
	// 	{
	// 		crosshair_pic[0] = 0;
	// 	}
	// }
}


SCR_ExecuteLayoutString(String s) async {

	final scale = SCR_GetHUDScale();

	if ((cls.state != connstate_t.ca_active) || !cl.refresh_prepped) {
		return;
	}

	if (s == null || s.isEmpty) {
		return;
	}

	int x = 0;
	int y = 0;
  int index = 0;
	while (index >= 0 && index < s.length) {
		var res = COM_Parse(s, index);
    if (res == null) break;
    var token = res.token;
    index = res.index;

		if (token == "xl") {
			res = COM_Parse(s, index);
      if (res == null) break;
      token = res.token;
      index = res.index;
			x = (scale*int.parse(token)).toInt();
			continue;
		}

		if (token == "xr") {
			res = COM_Parse(s, index);
      if (res == null) break;
      token = res.token;
      index = res.index;
			x = viddef.width + (scale*int.parse(token)).toInt();
			continue;
		}

		if (token == "xv") {
			res = COM_Parse(s, index);
      if (res == null) break;
      token = res.token;
      index = res.index;
			x = viddef.width ~/ 2 - (scale*160).toInt() + (scale*int.parse(token)).toInt();
			continue;
		}

		if (token == "yt") {
			res = COM_Parse(s, index);
      if (res == null) break;
      token = res.token;
      index = res.index;
			y = (scale*int.parse(token)).toInt();
			continue;
		}

		if (token == "yb") {
			res = COM_Parse(s, index);
      if (res == null) break;
      token = res.token;
      index = res.index;
			y = viddef.height + (scale*int.parse(token)).toInt();
			continue;
		}

		if (token == "yv") {
			res = COM_Parse(s, index);
      if (res == null) break;
      token = res.token;
      index = res.index;
			y = viddef.height ~/ 2 - (scale*120).toInt() + (scale*int.parse(token)).toInt();
			continue;
		}

		if (token == "pic") {
			/* draw a pic from a stat number */
			res = COM_Parse(s, index);
      if (res == null) break;
      token = res.token;
      index = res.index;
			var idx = int.parse(token);
			if ((idx < 0) || (idx >= cl.frame.playerstate.stats.length)) {
				Com_Error(ERR_DROP, "bad stats index $idx (0x${idx.toRadixString(16)})");
			}

			int value = cl.frame.playerstate.stats[idx];

			if (value >= MAX_IMAGES) {
				Com_Error(ERR_DROP, "Pic >= MAX_IMAGES");
			}

			if (cl.configstrings[CS_IMAGES + value].isNotEmpty) {
				SCR_AddDirtyPoint(x, y);
				SCR_AddDirtyPoint(x + (23*scale).toInt(), y + (23*scale).toInt());
				await re.DrawPicScaled(x, y, cl.configstrings[CS_IMAGES + value], scale);
			}

			continue;
		}

		// if (!strcmp(token, "client"))
		// {
		// 	/* draw a deathmatch client block */
		// 	int score, ping, time;

		// 	token = COM_Parse(&s);
		// 	x = viddef.width / 2 - scale*160 + scale*(int)strtol(token, (char **)NULL, 10);
		// 	token = COM_Parse(&s);
		// 	y = viddef.height / 2 - scale*120 + scale*(int)strtol(token, (char **)NULL, 10);
		// 	SCR_AddDirtyPoint(x, y);
		// 	SCR_AddDirtyPoint(x + scale*159, y + scale*31);

		// 	token = COM_Parse(&s);
		// 	value = (int)strtol(token, (char **)NULL, 10);

		// 	if ((value >= MAX_CLIENTS) || (value < 0))
		// 	{
		// 		Com_Error(ERR_DROP, "client >= MAX_CLIENTS");
		// 	}

		// 	ci = &cl.clientinfo[value];

		// 	token = COM_Parse(&s);
		// 	score = (int)strtol(token, (char **)NULL, 10);

		// 	token = COM_Parse(&s);
		// 	ping = (int)strtol(token, (char **)NULL, 10);

		// 	token = COM_Parse(&s);
		// 	time = (int)strtol(token, (char **)NULL, 10);

		// 	DrawAltStringScaled(x + scale*32, y, ci->name, scale);
		// 	DrawAltStringScaled(x + scale*32, y + scale*8, "Score: ", scale);
		// 	DrawAltStringScaled(x + scale*(32 + 7 * 8), y + scale*8, va("%i", score), scale);
		// 	DrawStringScaled(x + scale*32, y + scale*16, va("Ping:  %i", ping), scale);
		// 	DrawStringScaled(x + scale*32, y + scale*24, va("Time:  %i", time), scale);

		// 	if (!ci->icon)
		// 	{
		// 		ci = &cl.baseclientinfo;
		// 	}

		// 	Draw_PicScaled(x, y, ci->iconname, scale);
		// 	continue;
		// }

		// if (!strcmp(token, "ctf"))
		// {
		// 	/* draw a ctf client block */
		// 	int score, ping;
		// 	char block[80];

		// 	token = COM_Parse(&s);
		// 	x = viddef.width / 2 - scale*160 + scale*(int)strtol(token, (char **)NULL, 10);
		// 	token = COM_Parse(&s);
		// 	y = viddef.height / 2 - scale*120 + scale*(int)strtol(token, (char **)NULL, 10);
		// 	SCR_AddDirtyPoint(x, y);
		// 	SCR_AddDirtyPoint(x + scale*159, y + scale*31);

		// 	token = COM_Parse(&s);
		// 	value = (int)strtol(token, (char **)NULL, 10);

		// 	if ((value >= MAX_CLIENTS) || (value < 0))
		// 	{
		// 		Com_Error(ERR_DROP, "client >= MAX_CLIENTS");
		// 	}

		// 	ci = &cl.clientinfo[value];

		// 	token = COM_Parse(&s);
		// 	score = (int)strtol(token, (char **)NULL, 10);

		// 	token = COM_Parse(&s);
		// 	ping = (int)strtol(token, (char **)NULL, 10);

		// 	if (ping > 999)
		// 	{
		// 		ping = 999;
		// 	}

		// 	sprintf(block, "%3d %3d %-12.12s", score, ping, ci->name);

		// 	if (value == cl.playernum)
		// 	{
		// 		DrawAltStringScaled(x, y, block, scale);
		// 	}

		// 	else
		// 	{
		// 		DrawStringScaled(x, y, block, scale);
		// 	}

		// 	continue;
		// }

		// if (!strcmp(token, "picn"))
		// {
		// 	/* draw a pic from a name */
		// 	token = COM_Parse(&s);
		// 	SCR_AddDirtyPoint(x, y);
		// 	SCR_AddDirtyPoint(x + scale*23, y + scale*23);
		// 	Draw_PicScaled(x, y, (char *)token, scale);
		// 	continue;
		// }

		// if (!strcmp(token, "num"))
		// {
		// 	/* draw a number */
		// 	token = COM_Parse(&s);
		// 	width = (int)strtol(token, (char **)NULL, 10);
		// 	token = COM_Parse(&s);
		// 	value = cl.frame.playerstate.stats[(int)strtol(token, (char **)NULL, 10)];
		// 	SCR_DrawFieldScaled(x, y, 0, width, value, scale);
		// 	continue;
		// }

		if (token == "hnum") {
			/* health number */
			int width = 3;
			int value = cl.frame.playerstate.stats[STAT_HEALTH];

      int color;
			if (value > 25) {
				color = 0;  /* green */
			} else if (value > 0) {
				color = (cl.frame.serverframe >> 2) & 1; /* flash */
			} else {
				color = 1;
			}

			if ((cl.frame.playerstate.stats[STAT_FLASHES] & 1) != 0) {
				await re.DrawPicScaled(x, y, "field_3", scale);
			}

			await SCR_DrawFieldScaled(x, y, color, width, value, scale);
			continue;
		}

		if (token == "anum") {
			/* ammo number */
			int color;

			int width = 3;
			int value = cl.frame.playerstate.stats[STAT_AMMO];

			if (value > 5) {
				color = 0; /* green */
			} else if (value >= 0) {
				color = (cl.frame.serverframe >> 2) & 1; /* flash */
			} else {
				continue; /* negative number = don't show */
			}

			if ((cl.frame.playerstate.stats[STAT_FLASHES] & 4) != 0) {
				await  re.DrawPicScaled(x, y, "field_3", scale);
			}

			await SCR_DrawFieldScaled(x, y, color, width, value, scale);
			continue;
		}

		if (token == "rnum") {
			/* armor number */
			int color;

			int width = 3;
			int value = cl.frame.playerstate.stats[STAT_ARMOR];

			if (value < 1)
			{
				continue;
			}

			color = 0; /* green */

			if ((cl.frame.playerstate.stats[STAT_FLASHES] & 2) != 0) {
				await re.DrawPicScaled(x, y, "field_3", scale);
			}

			await SCR_DrawFieldScaled(x, y, color, width, value, scale);
			continue;
		}

		if (token == "stat_string") {
			res = COM_Parse(s, index);
      if (res == null) break;
      token = res.token;
      index = res.index;
			var idx = int.parse(token);
			if ((idx < 0) || (idx >= MAX_CONFIGSTRINGS)) {
				Com_Error(ERR_DROP, "Bad stat_string index");
			}

			idx = cl.frame.playerstate.stats[idx];
			if ((idx < 0) || (idx >= MAX_CONFIGSTRINGS))
			{
				Com_Error(ERR_DROP, "Bad stat_string index");
			}

			DrawStringScaled(x, y, cl.configstrings[idx], scale);
			continue;
		}

		// if (!strcmp(token, "cstring"))
		// {
		// 	token = COM_Parse(&s);
		// 	DrawHUDStringScaled(token, x, y, 320, 0, scale); // FIXME: or scale 320 here?
		// 	continue;
		// }

		// if (!strcmp(token, "string"))
		// {
		// 	token = COM_Parse(&s);
		// 	DrawStringScaled(x, y, token, scale);
		// 	continue;
		// }

		// if (!strcmp(token, "cstring2"))
		// {
		// 	token = COM_Parse(&s);
		// 	DrawHUDStringScaled(token, x, y, 320, 0x80, scale); // FIXME: or scale 320 here?
		// 	continue;
		// }

		// if (!strcmp(token, "string2"))
		// {
		// 	token = COM_Parse(&s);
		// 	DrawAltStringScaled(x, y, token, scale);
		// 	continue;
		// }

		if (token == "endif") {
      continue;
    }

		if (token == "if") {
			/* draw a number */
			res = COM_Parse(s, index);
      token = res.token;
      index = res.index;
			final value = cl.frame.playerstate.stats[int.parse(token)];

			if (value == 0) {
				/* skip to endif */
				while (index >= 0 && index < s.length && token != "endif") {
          res = COM_Parse(s, index);
          if (res == null) {
            index = -1;
            break;
          }
          token = res.token;
          index = res.index;
				}
			}

			continue;
		}
    print("Unknown token $token");
	}
}


/*
 * The status bar is a small layout program that
 * is based on the stats array
 */
SCR_DrawStats() async => await SCR_ExecuteLayoutString(cl.configstrings[CS_STATUSBAR]);

const STAT_LAYOUTS = 13;

SCR_DrawLayout() async {
	if (cl.frame.playerstate.stats[STAT_LAYOUTS] == 0) {
		return;
	}
	await SCR_ExecuteLayoutString(cl.layout);
}

// ----
/*
 * This is called every frame, and can also be called
 * explicitly to flush text to the screen.
 */
SCR_UpdateScreen() async {
	final scale = SCR_GetMenuScale();

	/* if the screen is disabled (loading plaque is
	   up, or vid mode changing) do nothing at all */
	// if (cls.disable_screen != 0) {
	// 	if (Sys_Milliseconds() - cls.disable_screen > 120000) {
	// 		cls.disable_screen = 0;
	// 		Com_Printf("Loading plaque timed out.\n");
	// 	}
	// 	return;
	// }

	if (!scr_initialized || !con.initialized) {
		return; /* not initialized yet */
	}


  re.BeginFrame();

  if (scr_draw_loading == 2) {
		/* loading plaque over black screen */
// 		if(i == 0){
// 			R_SetPalette(NULL);
// 		}

		// if(i == numframes - 1){
			scr_draw_loading = 0;
		// }

		final size = await re.DrawGetPicSize("loading");
		await re.DrawPicScaled((viddef.width - size[0] * scale) ~/ 2, (viddef.height - size[1] * scale) ~/ 2, "loading", scale);
  }

	/* if a cinematic is supposed to be running,
	   handle menus and console specially */
	else if (cl.cinematictime > 0) {

		if (cls.key_dest == keydest_t.key_menu) {
			if (cl.cinematicpalette_active) {
// 				R_SetPalette(NULL);
				cl.cinematicpalette_active = false;
			}

			await M_Draw();
		} else if (cls.key_dest == keydest_t.key_console) {
			if (cl.cinematicpalette_active) {
// 				R_SetPalette(NULL);
				cl.cinematicpalette_active = false;
			}

			SCR_DrawConsole();
		} else {
// 			SCR_DrawCinematic();
		}

  } else {

		/* make sure the game palette is active */
		if (cl.cinematicpalette_active) {
// 			R_SetPalette(NULL);
			cl.cinematicpalette_active = false;
		}

    /* do 3D refresh drawing, and then update the screen */
    SCR_CalcVrect();

    /* clear any dirty part of the background */
		await SCR_TileClear();

		await V_RenderView();

		await SCR_DrawStats();

		if (cl.frame != null && (cl.frame.playerstate.stats[STAT_LAYOUTS] & 1) != 0) {
			await SCR_DrawLayout();
		}

		// if ((cl.frame.playerstate.stats[STAT_LAYOUTS] & 2) != 0) {
		// 	CL_DrawInventory();
		// }

// 		SCR_DrawNet();
		SCR_CheckDrawCenterString();

// 		if (scr_timegraph->value)
// 		{
// 			SCR_DebugGraph(cls.rframetime * 300, 0);
// 		}

// 		if (scr_debuggraph->value || scr_timegraph->value ||
// 			scr_netgraph->value)
// 		{
// 			SCR_DrawDebugGraph();
// 		}

// 		SCR_DrawPause();

    await SCR_DrawConsole();

		await M_Draw();

// 		SCR_DrawLoading();
  }

	// SCR_Framecounter();
	await re.EndFrame();
}

double SCR_ClampScale(double scale) {

	double f = viddef.width / 320.0;
	if (scale > f)
	{
		scale = f;
	}

	f = viddef.height / 240.0;
	if (scale > f)
	{
		scale = f;
	}

	if (scale < 1)
	{
		scale = 1;
	}

	return scale;
}

double SCR_GetDefaultScale() {
	int i = viddef.width ~/ 640;
	int j = viddef.height ~/ 240;

	if (i > j)
	{
		i = j;
	}
	if (i < 1)
	{
		i = 1;
	}

	return i.toDouble();
}

double SCR_GetHUDScale() {

	if (!scr_initialized) {
		return 1;
	} else if (r_hudscale.value < 0) {
		return SCR_GetDefaultScale();
	} else if (r_hudscale.value == 0) { /* HACK: allow scale 0 to hide the HUD */
		return 0;
	} else {
		return SCR_ClampScale(r_hudscale.value);
	}
}

double SCR_GetConsoleScale() {
	if (!scr_initialized) {
		return 1;
	} else if (r_consolescale.value < 0) {
		return SCR_GetDefaultScale();
	} else {
		return SCR_ClampScale(r_consolescale.value);
	}
}

double SCR_GetMenuScale() {
	if (!scr_initialized) {
		return 1;
	} else if (r_menuscale.value < 0) {
		return SCR_GetDefaultScale();
	} else {
		return SCR_ClampScale(r_menuscale.value);
	}
}