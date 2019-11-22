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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 * USA.
 *
 * =======================================================================
 *
 * This file implements the console
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cmdparser.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'vid/vid.dart' show viddef, re;
import 'menu/menu.dart';
import 'client.dart';
import 'cl_screen.dart' show SCR_GetConsoleScale, SCR_AddDirtyPoint, SCR_EndLoadingPlaque;

const	NUM_CON_TIMES = 4;
const	CON_TEXTSIZE	= 32768;

class console_t {
	bool	initialized = false;

	Uint8List text = Uint8List(CON_TEXTSIZE);
	int		current = 0; /* line where next message will be printed */
	int		x = 0; /* offset in current line for next print */
	int		display = 0; /* bottom of console displays this line */

	int		ormask = 0; /* high bit mask for colored characters */

	int 	linewidth = 0; /* characters across screen */
	int		totallines = 0; /* total lines in console scrollback */

	double	cursorspeed = 0.0;

	int		vislines = 0;

	// float	times[NUM_CON_TIMES]; /* cls.realtime time the line was generated */
}

console_t con = console_t();

DrawStringScaled(int x, int y, String s, double factor) {
	for (int i = 0; i < s.length; i++) {
		re.DrawCharScaled(x, y, s.codeUnitAt(i), factor);
		x += (8*factor).toInt();
	}
}

Con_ToggleConsole_f(List<String> args) async {
	SCR_EndLoadingPlaque(); /* get rid of loading plaque */

	if (cl.attractloop) {
		Cbuf_AddText("killserver\n");
		return;
	}

	if (cls.state == connstate_t.ca_disconnected) {
		/* start the demo loop again */
		Cbuf_AddText("d1\n");
		return;
	}

	// Key_ClearTyping();
	// Con_ClearNotify();

	// if (cl.cinematic_file)
	// {
	// 	AL_UnqueueRawSamples();
	// }

	if (cls.key_dest == keydest_t.key_console) {
		M_ForceMenuOff();
		Cvar_Set("paused", "0");
	} else {
		M_ForceMenuOff();
		cls.key_dest = keydest_t.key_console;

		if ((Cvar_VariableValue("maxclients") == 1) &&
			Com_ServerState() != 0) {
			Cvar_Set("paused", "1");
		}
	}
}

/*
 * If the line width has changed, reformat the buffer.
 */
Con_CheckResize() {
	// int i, j, width, oldwidth, oldtotallines, numlines, numchars;
	// char tbuf[CON_TEXTSIZE];
	final scale = SCR_GetConsoleScale();

	/* We need to clamp the line width to MAXCMDLINE - 2,
	   otherwise we may overflow the text buffer if the
	   vertical resultion / 8 (one char == 8 pixels) is
	   bigger then MAXCMDLINE.
	   MAXCMDLINE - 2 because 1 for the prompt and 1 for
	   the terminating \0. */
	var width = ((viddef.width / scale) ~/ 8) - 2;
	// width = width > MAXCMDLINE - 2 ? MAXCMDLINE - 2 : width;

	if (width == con.linewidth) {
		return;
	}

	/* video hasn't been initialized yet */
	if (width < 1)
	{
		width = 38;
		con.linewidth = width;
		con.totallines = CON_TEXTSIZE ~/ con.linewidth;
    con.text.fillRange(0, CON_TEXTSIZE, 32);
	}
	else
	{
		final oldwidth = con.linewidth;
		con.linewidth = width;
		final oldtotallines = con.totallines;
		con.totallines = CON_TEXTSIZE ~/ con.linewidth;
		var numlines = oldtotallines;

		if (con.totallines < numlines)
		{
			numlines = con.totallines;
		}

		var numchars = oldwidth;

		if (con.linewidth < numchars)
		{
			numchars = con.linewidth;
		}

    final tbuf = con.text.map((f) => f).toList();
    con.text.fillRange(0, CON_TEXTSIZE, 32);

		for (int i = 0; i < numlines; i++)
		{
			for (int j = 0; j < numchars; j++)
			{
				con.text[(con.totallines - 1 - i) * con.linewidth + j] =
					tbuf[((con.current - i + oldtotallines) %
						  oldtotallines) * oldwidth + j];
			}
		}

		// Con_ClearNotify();
	}

	con.current = con.totallines - 1;
	con.display = con.current;
}

Con_Init() {
	con.linewidth = -1;

	Con_CheckResize();

	Com_Printf("Console initialized.\n");

	/* register our commands */
	// con_notifytime = Cvar_Get("con_notifytime", "3", 0);

	Cmd_AddCommand("toggleconsole", Con_ToggleConsole_f);
	// Cmd_AddCommand("togglechat", Con_ToggleChat_f);
	// Cmd_AddCommand("messagemode", Con_MessageMode_f);
	// Cmd_AddCommand("messagemode2", Con_MessageMode2_f);
	// Cmd_AddCommand("clear", Con_Clear_f);
	// Cmd_AddCommand("condump", Con_Dump_f);
	con.initialized = true;
}

Con_Linefeed() {
	con.x = 0;

	if (con.display == con.current)
	{
		con.display++;
	}

	con.current++;
  final start = (con.current % con.totallines) * con.linewidth;
  con.text.fillRange(start, start + con.linewidth, 32);
}


/*
 * Handles cursor positioning, line wrapping, etc All console printing
 * must go through this in order to be logged to disk If no console is
 * visible, the text will appear at the top of the game window
 */
bool _cr = false;
Con_Print(String txt) {
	// int y;
	// int c, l;
	// static int cr;
	// int mask;

	if (!con.initialized) {
		return;
	}

  int mask = 0;
  int index = 0;
	if ((txt.codeUnitAt(0) == 1) || (txt.codeUnitAt(0) == 2)) {
		mask = 128; /* go to colored text */
		index++;
	}

	while (index < txt.length) {
		/* count word length */
    int l;
		for (l = 0; l < con.linewidth; l++) {
			if (index + l >= txt.length || txt.codeUnitAt(index + l) <= 32) {
				break;
			}
		}

		/* word wrap */
		if ((l != con.linewidth) && (con.x + l > con.linewidth)) {
			con.x = 0;
		}

    final c = txt.codeUnitAt(index++);

		if (_cr) {
			con.current--;
			_cr = false;
		}

		if (con.x == 0) {
			Con_Linefeed();

			/* mark time for transparent overlay */
			// if (con.current >= 0) {
				// con.times[con.current % NUM_CON_TIMES] = cls.realtime;
			// }
		}

		switch (c) {
			case 10:
				con.x = 0;
				break;

			case 13:
				con.x = 0;
				_cr = true;
				break;

			default: /* display character and advance */
				final y = con.current % con.totallines;
				con.text[y * con.linewidth + con.x] = c | mask | con.ormask;
				con.x++;

				if (con.x >= con.linewidth) {
					con.x = 0;
				}

				break;
		}
	}
}

/*
 * Draws the console with the solid background
 */
Con_DrawConsole(double frac) async {
// 	int i, j, x, y, n;
// 	int rows;
// 	int verLen;
// 	char *text;
// 	int row;
// 	int lines;
// 	float scale;
// 	char version[48];
// 	char dlbar[1024];
// 	char timebuf[48];
// 	char tmpbuf[48];

// 	time_t t;
// 	struct tm *today;

	final scale = SCR_GetConsoleScale();
	var lines = (viddef.height * frac).toInt();

	if (lines <= 0) {
		return;
	}

	if (lines > viddef.height) {
		lines = viddef.height;
	}

	/* draw the background */
	await re.DrawStretchPic(0, -viddef.height + lines, viddef.width,
			viddef.height, "conback");
	SCR_AddDirtyPoint(0, 0);
	SCR_AddDirtyPoint(viddef.width - 1, lines - 1);

// 	Com_sprintf(version, sizeof(version), "Yamagi Quake II v%s", YQ2VERSION);

// 	verLen = strlen(version);

// 	for (x = 0; x < verLen; x++)
// 	{
// 		Draw_CharScaled(viddef.width - ((verLen*8+5) * scale) + x * 8 * scale, lines - 35 * scale, 128 + version[x], scale);
// 	}

// 	t = time(NULL);
// 	today = localtime(&t);
// 	strftime(timebuf, sizeof(timebuf), "%H:%M:%S - %m/%d/%Y", today);

// 	Com_sprintf(tmpbuf, sizeof(tmpbuf), "%s", timebuf);

// 	for (x = 0; x < 21; x++)
// 	{
// 		Draw_CharScaled(viddef.width - (173 * scale) + x * 8 * scale, lines - 25 * scale, 128 + tmpbuf[x], scale);
// 	}

	/* draw the text */
	con.vislines = lines;

	var rows = (lines - 22) >> 3; /* rows of text to draw */
	var y = (lines - 30 * scale) ~/ scale;

	/* draw from the bottom up */
	if (con.display != con.current) {
		/* draw arrows to show the buffer is backscrolled */
		for (int x = 0; x < con.linewidth; x += 4) {
			re.DrawCharScaled((((x + 1) << 3) * scale).toInt(), (y * scale).toInt(), '^'.codeUnitAt(0), scale);
		}

		y -= 8;
		rows--;
	}

	var row = con.display;

	for (int i = 0; i < rows; i++, y -= 8, row--) {
		if (row < 0) {
			break;
		}

		if (con.current - row >= con.totallines) {
			break; /* past scrollback wrap point */
		}

		// text = con.text + (row % con.totallines) * con.linewidth;
    final text_i = (row % con.totallines) * con.linewidth;

		for (int x = 0; x < con.linewidth; x++) {
			re.DrawCharScaled((((x + 1) << 3) * scale).toInt(), (y * scale).toInt(), con.text[text_i + x], scale);
		}
	}

// 	/* draw the download bar, figure out width */
// #ifdef USE_CURL
// 	if (cls.downloadname[0] && (cls.download || cls.downloadposition))
// #else
// 	if (cls.download)
// #endif
// 	{
// 		if ((text = strrchr(cls.downloadname, '/')) != NULL)
// 		{
// 			text++;
// 		}

// 		else
// 		{
// 			text = cls.downloadname;
// 		}

// 		x = con.linewidth - ((con.linewidth * 7) / 40);
// 		y = x - strlen(text) - 8;
// 		i = con.linewidth / 3;

// 		if (strlen(text) > i)
// 		{
// 			y = x - i - 11;
// 			memcpy(dlbar, text, i);
// 			dlbar[i] = 0;
// 			strcat(dlbar, "...");
// 		}
// 		else
// 		{
// 			strcpy(dlbar, text);
// 		}

// 		strcat(dlbar, ": ");
// 		i = strlen(dlbar);
// 		dlbar[i++] = '\x80';

// 		/* where's the dot gone? */
// 		if (cls.downloadpercent == 0)
// 		{
// 			n = 0;
// 		}

// 		else
// 		{
// 			n = y * cls.downloadpercent / 100;
// 		}

// 		for (j = 0; j < y; j++)
// 		{
// 			if (j == n)
// 			{
// 				dlbar[i++] = '\x83';
// 			}

// 			else
// 			{
// 				dlbar[i++] = '\x81';
// 			}
// 		}

// 		dlbar[i++] = '\x82';
// 		dlbar[i] = 0;

// 		sprintf(dlbar + strlen(dlbar), " %02d%%", cls.downloadpercent);

// 		/* draw it */
// 		y = con.vislines - 12;

// 		for (i = 0; i < strlen(dlbar); i++)
// 		{
// 			Draw_CharScaled(((i + 1) << 3) * scale, y * scale, dlbar[i], scale);
// 		}
// 	}

// 	/* draw the input prompt, user text, and cursor if desired */
// 	Con_DrawInput();
}

