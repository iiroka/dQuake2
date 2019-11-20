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
 * Client / Server interactions
 *
 * =======================================================================
 */
import '../shared/shared.dart';
import './frame.dart' show developer, startTime;
import 'package:dQuakeWeb/client/cl_console.dart' show Con_Print;
import 'package:dQuakeWeb/client/cl_network.dart' show CL_Drop;
import 'package:dQuakeWeb/server/sv_main.dart' show SV_Shutdown;

class AbortFrame extends Error {
  AbortFrame();
  String toString() {
    return "AbortFrame";
  }
}

class SysError extends Error {
  String msg;
  SysError(String msg) {
    this.msg = msg;
  }
  String toString() {
    return msg;
  }
}

/*
 * Both client and server can use this, and it will output
 * to the apropriate place.
 */
Com_VPrintf(int print_level, String msg)
{
	if((print_level == PRINT_DEVELOPER) && (developer == null || !developer.boolean))
	{
		return; /* don't confuse non-developers with techie stuff... */
	}
	else
	{
	// 	int i;
	// 	char msg[MAXPRINTMSG];

	// 	int msgLen = vsnprintf(msg, MAXPRINTMSG, fmt, argptr);
	// 	if (msgLen >= MAXPRINTMSG || msgLen < 0) {
	// 		msgLen = MAXPRINTMSG-1;
	// 		msg[msgLen] = '\0';
	// 	}

	// 	if (rd_target)
	// 	{
	// 		if ((msgLen + strlen(rd_buffer)) > (rd_buffersize - 1))
	// 		{
	// 			rd_flush(rd_target, rd_buffer);
	// 			*rd_buffer = 0;
	// 		}

	// 		strcat(rd_buffer, msg);
	// 		return;
	// 	}

		Con_Print(msg);

		// remove unprintable characters
		// for(i=0; i<msgLen; ++i)
		// {
		// 	char c = msg[i];
		// 	if(c < ' ' && (c < '\t' || c > '\r'))
		// 	{
		// 		switch(c)
		// 		{
		// 			// no idea if the following two are ever sent here, but in conchars.pcx they look like this
		// 			// so do the replacements.. won't hurt I guess..
		// 			case 0x10:
		// 				msg[i] = '[';
		// 				break;
		// 			case 0x11:
		// 				msg[i] = ']';
		// 				break;
		// 			// horizontal line chars
		// 			case 0x1D:
		// 			case 0x1F:
		// 				msg[i] = '-';
		// 				break;
		// 			case 0x1E:
		// 				msg[i] = '=';
		// 				break;
		// 			default: // just replace all other unprintable chars with space, should be good enough
		// 				msg[i] = ' ';
		// 		}
		// 	}
		// }

		/* also echo to debugging console */
    print(msg);

		/* logfile */
		// if (logfile_active && logfile_active->value)
		// {
		// 	char name[MAX_OSPATH];

		// 	if (!logfile)
		// 	{
		// 		Com_sprintf(name, sizeof(name), "%s/qconsole.log", FS_Gamedir());

		// 		if (logfile_active->value > 2)
		// 		{
		// 			logfile = Q_fopen(name, "a");
		// 		}

		// 		else
		// 		{
		// 			logfile = Q_fopen(name, "w");
		// 		}
		// 	}

		// 	if (logfile)
		// 	{
		// 		fprintf(logfile, "%s", msg);
		// 	}

		// 	if (logfile_active->value > 1)
		// 	{
		// 		fflush(logfile);  /* force it to save every time */
		// 	}
		// }
	}
}


/*
 * Both client and server can use this, and it will output
 * to the apropriate place.
 */
Com_Printf(String msg) {
  Com_VPrintf(PRINT_ALL, msg);
}

/*
 * A Com_Printf that only shows up if the "developer" cvar is set
 */
Com_DPrintf(String msg) {
  Com_VPrintf(PRINT_DEVELOPER, msg);
}


/*
 * Both client and server can use this, and it will
 * do the apropriate things.
 */
Com_Error(int code, String msg) {
// 	va_list argptr;
// 	static char msg[MAXPRINTMSG];
// 	static qboolean recursive;

// 	if (recursive)
// 	{
// 		Sys_Error("recursive error after: %s", msg);
// 	}

// 	recursive = true;

// 	va_start(argptr, fmt);
// 	vsnprintf(msg, MAXPRINTMSG, fmt, argptr);
// 	va_end(argptr);

	if (code == ERR_DISCONNECT) {
		CL_Drop();
    throw AbortFrame();
	} else if (code == ERR_DROP) {
		Com_Printf("********************\nERROR: $msg\n********************\n");
		SV_Shutdown("Server crashed: $msg\n", false);
		CL_Drop();
    throw AbortFrame();
	} else {
		SV_Shutdown("Server fatal crashed: $msg\n", false);
// #ifndef DEDICATED_ONLY
// 		CL_Shutdown();
// #endif
	}

// 	if (logfile)
// 	{
// 		fclose(logfile);
// 		logfile = NULL;
// 	}

// 	Sys_Error("%s", msg);
// 	recursive = false;
  throw SysError(msg);
}

int server_state = 0;
Com_SetServerState(int state) {
  server_state = state;
}

int Com_ServerState() {
  return server_state;
}

int Sys_Milliseconds() {
    return DateTime.now().millisecondsSinceEpoch - startTime;
}