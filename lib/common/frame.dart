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
 * Platform independent initialization, main loop and frame handling.
 *
 * =======================================================================
 */
import 'dart:html';

import 'clientserver.dart';
import 'cmdparser.dart';
import 'cvar.dart';
import '../client/cl_main.dart' show CL_Init, CL_Frame;
import '../client/cl_keyboard.dart' show Key_Init;
import '../server/sv_main.dart' show SV_Init, SV_Frame;
import 'netchan.dart' show Netchan_Init;

cvar_t developer;
cvar_t modder;
cvar_t timescale;
cvar_t fixedtime;
cvar_t cl_maxfps;
cvar_t dedicated;
cvar_t busywait;
cvar_t vid_maxfps;
cvar_t cl_timedemo;
cvar_t cl_async;

int curtime;
int startTime;

Qcommon_ExecConfigs(bool gameStartUp) async {
	Cbuf_AddText("exec default.cfg\n");
	Cbuf_AddText("exec yq2.cfg\n");
	Cbuf_AddText("exec config.cfg\n");
	if(gameStartUp) {
		// only when the game is first started we execute autoexec.cfg and set the cvars from commandline
		Cbuf_AddText("exec autoexec.cfg\n");
		// Cbuf_AddEarlyCommands(true);
	}
	await Cbuf_Execute();
}

void Qcommon_Init() async  {

  startTime = DateTime.now().millisecondsSinceEpoch;
	// Jump point used in emergency situations.
// 	if (setjmp(abortframe))
// 	{
// 		Sys_Error("Error during initialization");
// 	}

// 	if (checkForHelp(argc, argv))
// 	{
// 		// ok, --help or similar commandline option was given
// 		// and info was printed, exit the game now
// 		exit(1);
// 	}

	// Print the build and version string
// 	Qcommon_Buildstring();

	// Seed PRNG
// 	randk_seed();

	// Initialize zone malloc().
// 	z_chain.next = z_chain.prev = &z_chain;

	// Start early subsystems.
// 	COM_InitArgv(argc, argv);
// 	Swap_Init();
	Cbuf_Init();
	Cmd_Init();
	Cvar_Init();

	Key_Init();

	/* we need to add the early commands twice, because
	   a basedir or cddir needs to be set before execing
	   config files, but we want other parms to override
	   the settings of the config files */
// 	Cbuf_AddEarlyCommands(false);
	await Cbuf_Execute();

// 	// remember the initial game name that might have been set on commandline
// 	{
// 		cvar_t* gameCvar = Cvar_Get("game", "", CVAR_LATCH | CVAR_SERVERINFO);
// 		const char* game = "";

// 		if(gameCvar->string && gameCvar->string[0])
// 		{
// 			game = gameCvar->string;
// 		}

// 		Q_strlcpy(userGivenGame, game, sizeof(userGivenGame));
// 	}

	// The filesystems needs to be initialized after the cvars.
	// await FS_InitFilesystem();

	// Add and execute configuration files.
	await Qcommon_ExecConfigs(true);

// 	// Zone malloc statistics.
// 	Cmd_AddCommand("z_stats", Z_Stats_f);

	// cvars

	cl_maxfps = Cvar_Get("cl_maxfps", "60", CVAR_ARCHIVE);

	developer = Cvar_Get("developer", "1", 0);
	fixedtime = Cvar_Get("fixedtime", "0", 0);

	// logfile_active = Cvar_Get("logfile", "1", CVAR_ARCHIVE);
	modder = Cvar_Get("modder", "0", 0);
	timescale = Cvar_Get("timescale", "1", 0);

// 	char *s;
// 	s = va("%s %s %s %s", YQ2VERSION, YQ2ARCH, BUILD_DATE, YQ2OSTYPE);
// 	Cvar_Get("version", s, CVAR_SERVERINFO | CVAR_NOSET);
// 	busywait = Cvar_Get("busywait", "1", CVAR_ARCHIVE);

	cl_async = Cvar_Get("cl_async", "1", CVAR_ARCHIVE);
	cl_timedemo = Cvar_Get("timedemo", "0", 0);
	dedicated = Cvar_Get("dedicated", "0", CVAR_NOSET);
	vid_maxfps = Cvar_Get("vid_maxfps", "300", CVAR_ARCHIVE);
// 	host_speeds = Cvar_Get("host_speeds", "0", 0);
// 	log_stats = Cvar_Get("log_stats", "0", 0);
// 	showtrace = Cvar_Get("showtrace", "0", 0);

// 	// We can't use the clients "quit" command when running dedicated.
// 	if (dedicated->value)
// 	{
// 		Cmd_AddCommand("quit", Com_Quit);
// 	}

// 	// Start late subsystem.
// 	Sys_Init();
// 	NET_Init();
	Netchan_Init();
	SV_Init();
	await CL_Init();

// 	// Everythings up, let's add + cmds from command line.
// 	if (!Cbuf_AddLateCommands())
// 	{
// 		if (!dedicated->value)
// 		{
			// Start demo loop...
			Cbuf_AddText("d1\n");
// 		}
// 		else
// 		{
// 			// ...or dedicated server.
// 			Cbuf_AddText("dedicated_start\n");
// 		}

		await Cbuf_Execute();
// 	}
// 	else
// 	{
// 		/* the user asked for something explicit
// 		   so drop the loading plaque */
// 		SCR_EndLoadingPlaque();
// 	}

	Com_Printf("==== Yamagi Quake II Initialized ====\n\n");
	Com_Printf("*************************************\n\n");

	// Call the main loop
	Qcommon_Mainloop();
}

int _lastFrame;

Qcommon_Mainloop() {

  int now = DateTime.now().millisecondsSinceEpoch;
  if (_lastFrame == null) _lastFrame = now;
  int msec = now - _lastFrame;
  _lastFrame = now;

  Qcommon_Frame(msec).then((x) {
    window.requestAnimationFrame((x) => Qcommon_Mainloop());
  });
}

// Time since last packetframe in millisec.
int _packetdelta = 1000;

// Time since last renderframe in millisec.
int _renderdelta = 1000;

// Accumulated time since last client run.
int _clienttimedelta = 0;

// Accumulated time since last server run.
int _servertimedelta = 0;

Future<void> Qcommon_Frame(int msec) async {
	// Used for the dedicated server console.
	// char *s;

	// // Statistics.
	// int time_before = 0;
	// int time_between = 0;
	// int time_after;

	// // Target packetframerate.
	// int pfps;

	// //Target renderframerate.
	// int rfps;

  final now = DateTime.now().millisecondsSinceEpoch;
  curtime = now - startTime;

	/* A packetframe runs the server and the client,
	   but not the renderer. The minimal interval of
	   packetframes is about 10.000 microsec. If run
	   more often the movement prediction in pmove.c
	   breaks. That's the Q2 variant if the famous
	   125hz bug. */
	bool packetframe = true;

	/* A rendererframe runs the renderer, but not the
	   client or the server. The minimal interval is
	   about 1000 microseconds. */
	bool renderframe = true;


	// /* Tells the client to shutdown.
	//    Used by the signal handlers. */
	// if (quitnextframe)
	// {
	// 	Cbuf_AddText("quit");
	// }


	// /* In case of ERR_DROP we're jumping here. Don't know
	//    if that's really save but it seems to work. So leave
	//    it alone. */
	// if (setjmp(abortframe))
	// {
	// 	return;
	// }


	// if (log_stats->modified)
	// {
	// 	log_stats->modified = false;

	// 	if (log_stats->value)
	// 	{
	// 		if (log_stats_file)
	// 		{
	// 			fclose(log_stats_file);
	// 			log_stats_file = 0;
	// 		}

	// 		log_stats_file = Q_fopen("stats.log", "w");

	// 		if (log_stats_file)
	// 		{
	// 			fprintf(log_stats_file, "entities,dlights,parts,frame time\n");
	// 		}
	// 	}
	// 	else
	// 	{
	// 		if (log_stats_file)
	// 		{
	// 			fclose(log_stats_file);
	// 			log_stats_file = 0;
	// 		}
	// 	}
	// }


	// // Timing debug crap. Just for historical reasons.
	// if (fixedtime->value)
	// {
	// 	usec = (int)fixedtime->value;
	// }
	// else if (timescale->value)
	// {
	// 	usec *= timescale->value;
	// }


	// if (showtrace->value)
	// {
	// 	extern int c_traces, c_brush_traces;
	// 	extern int c_pointcontents;

	// 	Com_Printf("%4i traces  %4i points\n", c_traces, c_pointcontents);
	// 	c_traces = 0;
	// 	c_brush_traces = 0;
	// 	c_pointcontents = 0;
	// }


	// /* We can render 1000 frames at maximum, because the minimum
	//    frametime of the client is 1 millisecond. And of course we
	//    need to render something, the framerate can never be less
	//    then 1. Cap vid_maxfps between 1 and 999. */
	// if (vid_maxfps->value > 999 || vid_maxfps->value < 1)
	// {
	// 	Cvar_SetValue("vid_maxfps", 999);
	// }

	// if (cl_maxfps->value > 250)
	// {
	// 	Cvar_SetValue("cl_maxfps", 250);
	// }
	// else if (cl_maxfps->value < 1)
	// {
	// 	Cvar_SetValue("cl_maxfps", 60);
	// }


	// // Save global time for network- und input code.
	// curtime = Sys_Milliseconds();


	// Calculate target and renderframerate.
  int rfps;
	// if (R_IsVSyncActive())
	// {
	// 	rfps = GLimp_GetRefreshRate();

	// 	if (rfps > vid_maxfps->value)
	// 	{
	// 		rfps = (int)vid_maxfps->value;
	// 	}
	// }
	// else
	// {
		rfps = vid_maxfps.integer;
	// }

	/* The target render frame rate may be too high. The current
	   scene may be more complex then the previous one and SDL
	   may give us a 1 or 2 frames too low display refresh rate.
	   Add a security magin of 5%, e.g. 60fps * 0.95 = 57fps. */
	int pfps = (cl_maxfps.integer > (rfps * 0.95)) ? (rfps * 0.95).toInt() : cl_maxfps.integer;


	// Calculate timings.
	_packetdelta += msec;
	_renderdelta += msec;
	_clienttimedelta += msec;
	_servertimedelta += msec;

	if (!cl_timedemo.boolean) {
		if (cl_async.boolean) {
	// 		if (R_IsVSyncActive())
	// 		{
	// 			// Netwwork frames.
	// 			if (packetdelta < (0.8 * (1000000.0f / pfps)))
	// 			{
	// 				packetframe = false;
	// 			}

	// 			// Render frames.
	// 			if (renderdelta < (0.8 * (1000000.0f / rfps)))
	// 			{
	// 				renderframe = false;
	// 			}
	// 		}
	// 		else
	// 		{
				// Network frames.
				if (_packetdelta < (1000 / pfps))
				{
					packetframe = false;
				}

				// Render frames.
				if (_renderdelta < (1000 / rfps))
				{
					renderframe = false;
				}
			// }
		} else {
			// Cap frames at target framerate.
			if (_renderdelta < (1000 / rfps)) {
				renderframe = false;
				packetframe = false;
			}
		}
	} else if (_clienttimedelta < 1 || _servertimedelta < 1) {
		return;
	}


	// // Dedicated server terminal console.
	// do {
	// 	s = Sys_ConsoleInput();

	// 	if (s) {
	// 		Cbuf_AddText(va("%s\n", s));
	// 	}
	// } while (s);

	await Cbuf_Execute();


	// if (host_speeds->value)
	// {
	// 	time_before = Sys_Milliseconds();
	// }


	// // Run the serverframe.
	if (packetframe) {
		await SV_Frame(_servertimedelta);
		_servertimedelta = 0;
	}


	// if (host_speeds->value)
	// {
	// 	time_between = Sys_Milliseconds();
	// }


	// Run the client frame.
	if (packetframe || renderframe) {
		await CL_Frame(_packetdelta, _renderdelta, _clienttimedelta, packetframe, renderframe);
		_clienttimedelta = 0;
	}


	// if (host_speeds->value)
	// {
	// 	int all, sv, gm, cl, rf;

	// 	time_after = Sys_Milliseconds();
	// 	all = time_after - time_before;
	// 	sv = time_between - time_before;
	// 	cl = time_after - time_between;
	// 	gm = time_after_game - time_before_game;
	// 	rf = time_after_ref - time_before_ref;
	// 	sv -= gm;
	// 	cl -= rf;
	// 	Com_Printf("all:%3i sv:%3i gm:%3i cl:%3i rf:%3i\n", all, sv, gm, cl, rf);
	// }


	// Reset deltas and mark frame.
	if (packetframe) {
		_packetdelta = 0;
	}

	if (renderframe) {
		_renderdelta = 0;
	}
}