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
 * This is the clients main loop as well as some miscelangelous utility
 * and support functions
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'package:dQuakeWeb/client/cl_parse.dart';
import 'package:dQuakeWeb/client/cl_tempentities.dart';
import 'package:dQuakeWeb/client/sound/sound.dart';

import '../common/cvar.dart';
import '../common/cmdparser.dart';
import '../common/clientserver.dart';
import '../common/frame.dart' show curtime;
import '../common/collision.dart';
import '../shared/shared.dart';
import './vid/vid.dart';
import 'client.dart';
import 'cl_screen.dart';
import 'cl_console.dart' show Con_Init;
import 'cl_network.dart';
import 'cl_input.dart' show CL_SendCmd, CL_RefreshCmd, CL_RefreshMove, CL_InitInput;
import 'cl_view.dart';
import 'cl_effects.dart';
import 'cl_lights.dart' show CL_RunLightStyles, CL_RunDLights;
import 'input.dart' show IN_Update, IN_Init;
import 'cl_predict.dart' show CL_PredictMovement;
import 'cl_download.dart' show CL_RequestNextDownload;
import 'menu/menu.dart';
import 'cl_input.dart';

cvar_t freelook;

cvar_t rcon_client_password;
cvar_t rcon_address;

cvar_t cl_noskins;
cvar_t cl_footsteps;
cvar_t cl_timeout;
cvar_t cl_predict;
cvar_t cl_showfps;
cvar_t cl_gun;
cvar_t cl_add_particles;
cvar_t cl_add_lights;
cvar_t cl_add_entities;
cvar_t cl_add_blend;

cvar_t cl_shownet;
cvar_t cl_showmiss;
cvar_t cl_showclamp;

cvar_t cl_paused;
cvar_t cl_loadpaused;

cvar_t lookstrafe;
cvar_t sensitivity;

cvar_t m_pitch;
cvar_t m_yaw;
cvar_t m_forward;
cvar_t m_side;

cvar_t cl_lightlevel;

/* userinfo */
cvar_t name;
cvar_t skin;
cvar_t rate;
cvar_t fov;
cvar_t horplus;
cvar_t windowed_mouse;
cvar_t msg;
cvar_t hand;
cvar_t gender;
cvar_t gender_auto;

cvar_t cl_vwep;

CL_ClearState() {
	// S_StopAllSounds();
	CL_ClearEffects();
  CL_ClearTEnts();

	/* wipe the entire cl structure */
	cl = client_state_t();
  for (int i = 0; i < cl_entities.length; i++) {
    cl_entities[i] = centity_t();
  }
  for (int i = 0; i < cl_parse_entities.length; i++) {
    cl_parse_entities[i] = entity_state_t();
  }

	cls.netchan.message.Clear();
}

int precache_check = 0;
int precache_spawncount = 0;
int precache_tex = 0;
int precache_model_skin = 0;
ByteBuffer precache_model = null;


/*
 * The server will send this command right
 * before allowing the client into the server
 */
CL_Precache_f(List<String> args) async {
	/* Yet another hack to let old demos work */
	if (args.length < 2) {
		List<int> map_checksum = [0];    /* for detecting cheater maps */

		await CM_LoadMap(cl.configstrings[CS_MODELS + 1], true, map_checksum);
		await CL_RegisterSounds();
		await CL_PrepRefresh();
		return;
	}

	precache_check = CS_MODELS;

	precache_spawncount = int.parse(args[1]) & 0xFFFFFFFF;
	precache_model = null;
	precache_model_skin = 0;

	await CL_RequestNextDownload();
}

void CL_InitLocal() {
	cls.state = connstate_t.ca_disconnected;
	cls.realtime = Sys_Milliseconds();

	CL_InitInput();

	/* register our variables */
	// cin_force43 = Cvar_Get("cin_force43", "1", 0);

	cl_add_blend = Cvar_Get("cl_blend", "1", 0);
	cl_add_lights = Cvar_Get("cl_lights", "1", 0);
	cl_add_particles = Cvar_Get("cl_particles", "1", 0);
	cl_add_entities = Cvar_Get("cl_entities", "1", 0);
	cl_gun = Cvar_Get("cl_gun", "2", CVAR_ARCHIVE);
	cl_footsteps = Cvar_Get("cl_footsteps", "1", 0);
	cl_noskins = Cvar_Get("cl_noskins", "0", 0);
	cl_predict = Cvar_Get("cl_predict", "1", 0);
	cl_showfps = Cvar_Get("cl_showfps", "0", CVAR_ARCHIVE);

	cl_upspeed = Cvar_Get("cl_upspeed", "200", 0);
	cl_forwardspeed = Cvar_Get("cl_forwardspeed", "200", 0);
	cl_sidespeed = Cvar_Get("cl_sidespeed", "200", 0);
	cl_yawspeed = Cvar_Get("cl_yawspeed", "140", 0);
	cl_pitchspeed = Cvar_Get("cl_pitchspeed", "150", 0);
	cl_anglespeedkey = Cvar_Get("cl_anglespeedkey", "1.5", 0);

	cl_run = Cvar_Get("cl_run", "0", CVAR_ARCHIVE);
	freelook = Cvar_Get("freelook", "1", CVAR_ARCHIVE);
	lookstrafe = Cvar_Get("lookstrafe", "0", CVAR_ARCHIVE);
	sensitivity = Cvar_Get("sensitivity", "3", CVAR_ARCHIVE);

	m_pitch = Cvar_Get("m_pitch", "0.022", CVAR_ARCHIVE);
	m_yaw = Cvar_Get("m_yaw", "0.022", 0);
	m_forward = Cvar_Get("m_forward", "1", 0);
	m_side = Cvar_Get("m_side", "1", 0);

	cl_shownet = Cvar_Get("cl_shownet", "0", 0);
	cl_showmiss = Cvar_Get("cl_showmiss", "0", 0);
	cl_showclamp = Cvar_Get("showclamp", "0", 0);
	cl_timeout = Cvar_Get("cl_timeout", "120", 0);
	cl_paused = Cvar_Get("paused", "0", 0);
	cl_loadpaused = Cvar_Get("cl_loadpaused", "1", CVAR_ARCHIVE);

	// gl1_stereo = Cvar_Get( "gl1_stereo", "0", CVAR_ARCHIVE );
	// gl1_stereo_separation = Cvar_Get( "gl1_stereo_separation", "1", CVAR_ARCHIVE );
	// gl1_stereo_convergence = Cvar_Get( "gl1_stereo_convergence", "1.4", CVAR_ARCHIVE );

	rcon_client_password = Cvar_Get("rcon_password", "", 0);
	rcon_address = Cvar_Get("rcon_address", "", 0);

	cl_lightlevel = Cvar_Get("r_lightlevel", "0", 0);

	/* userinfo */
	name = Cvar_Get("name", "unnamed", CVAR_USERINFO | CVAR_ARCHIVE);
	skin = Cvar_Get("skin", "male/grunt", CVAR_USERINFO | CVAR_ARCHIVE);
	rate = Cvar_Get("rate", "8000", CVAR_USERINFO | CVAR_ARCHIVE);
	msg = Cvar_Get("msg", "1", CVAR_USERINFO | CVAR_ARCHIVE);
	hand = Cvar_Get("hand", "0", CVAR_USERINFO | CVAR_ARCHIVE);
	fov = Cvar_Get("fov", "90", CVAR_USERINFO | CVAR_ARCHIVE);
	horplus = Cvar_Get("horplus", "1", CVAR_ARCHIVE);
	windowed_mouse = Cvar_Get("windowed_mouse", "1", CVAR_USERINFO | CVAR_ARCHIVE);
	gender = Cvar_Get("gender", "male", CVAR_USERINFO | CVAR_ARCHIVE);
	gender_auto = Cvar_Get("gender_auto", "1", CVAR_ARCHIVE);
	gender.modified = false;

	// USERINFO cvars are special, they just need to be registered
	Cvar_Get("password", "", CVAR_USERINFO);
	Cvar_Get("spectator", "0", CVAR_USERINFO);

	cl_vwep = Cvar_Get("cl_vwep", "1", CVAR_ARCHIVE);

// #ifdef USE_CURL
// 	cl_http_proxy = Cvar_Get("cl_http_proxy", "", 0);
// 	cl_http_filelists = Cvar_Get("cl_http_filelists", "1", 0);
// 	cl_http_downloads = Cvar_Get("cl_http_downloads", "1", CVAR_ARCHIVE);
// 	cl_http_max_connections = Cvar_Get("cl_http_max_connections", "4", 0);
// #endif

	/* register our commands */
	Cmd_AddCommand("cmd", CL_ForwardToServer_f);
	// Cmd_AddCommand("pause", CL_Pause_f);
	// Cmd_AddCommand("pingservers", CL_PingServers_f);
	// Cmd_AddCommand("skins", CL_Skins_f);

	// Cmd_AddCommand("userinfo", CL_Userinfo_f);
	// Cmd_AddCommand("snd_restart", CL_Snd_Restart_f);

	Cmd_AddCommand("changing", CL_Changing_f);
	// Cmd_AddCommand("disconnect", CL_Disconnect_f);
	// Cmd_AddCommand("record", CL_Record_f);
	// Cmd_AddCommand("stop", CL_Stop_f);

	// Cmd_AddCommand("quit", CL_Quit_f);

	// Cmd_AddCommand("connect", CL_Connect_f);
	Cmd_AddCommand("reconnect", CL_Reconnect_f);

	// Cmd_AddCommand("rcon", CL_Rcon_f);

	// Cmd_AddCommand("setenv", CL_Setenv_f);

	Cmd_AddCommand("precache", CL_Precache_f);

	// Cmd_AddCommand("download", CL_Download_f);

	// Cmd_AddCommand("currentmap", CL_CurrentMap_f);

	/* forward to server commands
	 * the only thing this does is allow command completion
	 * to work -- all unknown commands are automatically
	 * forwarded to the server */
	Cmd_AddCommand("wave",  null);
	Cmd_AddCommand("inven",  null);
	Cmd_AddCommand("kill",  null);
	Cmd_AddCommand("use",  null);
	Cmd_AddCommand("drop",  null);
	Cmd_AddCommand("say",  null);
	Cmd_AddCommand("say_team",  null);
	Cmd_AddCommand("info",  null);
	Cmd_AddCommand("prog",  null);
	Cmd_AddCommand("give",  null);
	Cmd_AddCommand("god",  null);
	Cmd_AddCommand("notarget",  null);
	Cmd_AddCommand("noclip",  null);
	Cmd_AddCommand("invuse",  null);
	Cmd_AddCommand("invprev",  null);
	Cmd_AddCommand("invnext",  null);
	Cmd_AddCommand("invdrop",  null);
	Cmd_AddCommand("weapnext",  null);
	Cmd_AddCommand("weapprev",  null);
	Cmd_AddCommand("listentities",  null);
	Cmd_AddCommand("teleport",  null);
	Cmd_AddCommand("cycleweap",  null);
}

void CL_Frame(int packetdelta, int renderdelta, int timedelta, bool packetframe, bool renderframe) async
{
	// static int lasttimecalled;

	// Dedicated?
	// if (dedicated->value) {
	// 	return;
	// }

	// Calculate simulation time.
	cls.nframetime = packetdelta / 1000;
	cls.rframetime = renderdelta / 1000;
	cls.realtime = curtime;
	cl.time += timedelta;

	// Don't extrapolate too far ahead.
	if (cls.nframetime > 0.5) {
		cls.nframetime = 0.5;
	}

	if (cls.rframetime > 0.5) {
		cls.rframetime = 0.5;
	}

  cl_framecounter++;

	// if in the debugger last frame, don't timeout.
	if (timedelta > 5000000) {
		cls.netchan.last_received = Sys_Milliseconds();
	}

	// Reset power shield / power screen sound counter.
// 	num_power_sounds = 0;

// 	if (!cl_timedemo->value)
// 	{
// 		// Don't throttle too much when connecting / loading.
// 		if ((cls.state == ca_connected) && (packetdelta > 100000))
// 		{
// 			packetframe = true;
// 		}
// 	}

// 	// Run HTTP downloads more often while connecting.
// #ifdef USE_CURL
// 	if (cls.state == ca_connected)
// 	{
// 		CL_RunHTTPDownloads();
// 	}
// #endif

	// Update input stuff.
	if (packetframe || renderframe) {
		await CL_ReadPackets();
// 		CL_UpdateWindowedMouse();
		await IN_Update();
		await Cbuf_Execute();
// 		CL_FixCvarCheats();

		if (cls.state.index > connstate_t.ca_connecting.index)
		{
			CL_RefreshCmd();
		}
		else
		{
			CL_RefreshMove();
		}
	}

	if (cls.forcePacket || userinfo_modified) {
		packetframe = true;
		cls.forcePacket = false;
	}

	if (packetframe) {
		CL_SendCmd();
		CL_CheckForResend();

// 		// Run HTTP downloads during game.
// #ifdef USE_CURL
// 		CL_RunHTTPDownloads();
// #endif
	}

	if (renderframe) {
		await VID_CheckChanges();
		CL_PredictMovement();

		if (!cl.refresh_prepped && (cls.state == connstate_t.ca_active)) {
			await CL_PrepRefresh();
		}

// 		/* update the screen */
// 		if (host_speeds->value)
// 		{
// 			time_before_ref = Sys_Milliseconds();
// 		}

		await SCR_UpdateScreen();

// 		if (host_speeds->value)
// 		{
// 			time_after_ref = Sys_Milliseconds();
// 		}

// 		/* update audio */
// 		S_Update(cl.refdef.vieworg, cl.v_forward, cl.v_right, cl.v_up);

// 		/* advance local effects for next frame */
		CL_RunDLights();
		CL_RunLightStyles();
// 		SCR_RunCinematic();
// 		SCR_RunConsole();

		/* Update framecounter */
		cls.framecount++;

// 		if (log_stats->value)
// 		{
// 			if (cls.state == ca_active)
// 			{
// 				if (!lasttimecalled)
// 				{
// 					lasttimecalled = Sys_Milliseconds();

// 					if (log_stats_file)
// 					{
// 						fprintf(log_stats_file, "0\n");
// 					}
// 				}

// 				else
// 				{
// 					int now = Sys_Milliseconds();

// 					if (log_stats_file)
// 					{
// 						fprintf(log_stats_file, "%d\n", now - lasttimecalled);
// 					}

// 					lasttimecalled = now;
// 				}
// 			}
// 		}
	}
}

void CL_Init() async {
// 	if (dedicated->value) {
// 		return; /* nothing running on the client */
// 	}
  cl_framecounter = 0;

	/* all archived variables will now be loaded */
	Con_Init();

	S_Init();

	SCR_Init();

	await VID_Init();

	IN_Init();

	V_Init();

// 	net_message.data = net_message_buffer;

// 	net_message.maxsize = sizeof(net_message_buffer);

	M_Init();

// #ifdef USE_CURL
// 	CL_InitHTTPDownloads();
// #endif

	cls.disable_screen = 1.0; /* don't draw yet */

	CL_InitLocal();

	await Cbuf_Execute();

// 	Key_ReadConsoleHistory();
  await SCR_UpdateScreen();
}
