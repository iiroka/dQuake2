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
 * Main header for the client
 *
 * =======================================================================
 */
import 'dart:typed_data';

import 'package:dQuakeWeb/common/netchan.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'vid/ref.dart';

const MAX_CLIENTWEAPONMODELS = 20;
const	CMD_BACKUP = 256; /* allow a lot of command backups for very fast systems */

/* the cl_parse_entities must be large enough to hold UPDATE_BACKUP frames of
   entities, so that when a delta compressed message arives from the server
   it can be un-deltad from the original */
const	MAX_PARSE_ENTITIES	= 1024;

const	PARTICLE_GRAVITY = 40;
const INSTANT_PARTICLE = -10000.0;

class frame_t {
	bool		  valid = false; /* cleared if delta parsing was invalid */
	int				serverframe = 0;
	int				servertime = 0; /* server time the message is valid for (in msec) */
	int				deltaframe = 0;
	Uint8List		areabits; /* portalarea visibility bits */
	player_state_t	playerstate = player_state_t();
	int				num_entities = 0;
	int				parse_entities = 0; /* non-masked index into cl_parse_entities array */
}

class centity_t {
	entity_state_t	baseline = entity_state_t(); /* delta from this if not from a previous frame */
	entity_state_t	current = entity_state_t();
	entity_state_t	prev = entity_state_t(); /* will always be valid, but might just be a copy of current */

	int			serverframe = 0; /* if not current, this ent isn't in the frame */

	int			trailcount = 0;	 /* for diminishing grenade trails */
	List<double>		lerp_origin = [0,0,0]; /* for trails (variable hz) */

	int			fly_stoptime = 0;
}

class clientinfo_t {
	String	name;
	String	cinfo;

	Object skin;

	Object icon;
	String iconname;

	Object model;

	List<Object> weaponmodel;
}

class client_state_t {
  int   timeoutcount = 0;

	int			timedemo_frames = 0;
	int			timedemo_start = 0;

	bool	refresh_prepped = false; /* false if on new level or new ref dll */
	bool	sound_prepped = false; /* ambient sounds can start */
	bool	force_refdef = false; /* vid has changed, so we can't use a paused refdef */

	int			parse_entities = 0; /* index (not anded off) into cl_parse_entities[] */

	usercmd_t	cmd = usercmd_t();
	List<usercmd_t>	cmds = List.generate(CMD_BACKUP, (i) => usercmd_t()); /* each mesage will send several old cmds */
	List<int> cmd_time = List(CMD_BACKUP); /* time sent, for calculating pings */
	List<List<int>>	predicted_origins = List.generate(CMD_BACKUP, (i) => [0,0,0]); /* for debug comparing against server */

	double		predicted_step = 0; /* for stair up smoothing */
	int	predicted_step_time = 0;

	List<double>		predicted_origin = [0,0,0]; /* generated by CL_PredictMovement */
	List<double>		predicted_angles = [0,0,0];
	List<double>		prediction_error = [0,0,0];

	frame_t		frame; /* received from server */
	int			surpressCount = 0; /* number of messages rate supressed */
	List<frame_t>		frames = List(UPDATE_BACKUP);

	/* the client maintains its own idea of view angles, which are
	   sent to the server each frame.  It is cleared to 0 upon entering each level.
	   the server sends a delta each frame which is added to the locally
	   tracked view angles to account for standing on rotating objects,
	   and teleport direction changes */
	List<double>		viewangles = [0,0,0];

	int			time = 0; /* this is the time value that the client is rendering at. always <= cls.realtime */
	double		lerpfrac = 0.0; /* between oldframe and frame */

	refdef_t	refdef = refdef_t();

	List<double>		v_forward = [0,0,0], v_right = [0,0,0], v_up = [0,0,0]; /* set when refdef.angles is set */

	/* transient data from server */
	String layout = ""; /* general 2D overlay */
	// int			inventory[MAX_ITEMS];

	// /* non-gameserver infornamtion */
	// fileHandle_t cinematic_file;
  ByteBuffer cinematicBuffer;
  int     cinematicOffset = 0;
	int			cinematictime = 0; /* cls.realtime for first cinematic frame */
	int			cinematicframe = 0;
	// unsigned char	cinematicpalette[768];
	bool	cinematicpalette_active;

	/* server state information */
	bool	attractloop = false; /* running the attract loop, any key will menu */
	int			servercount = 0; /* server identification for prespawns */
	String gamedir = "";
	int			playernum = 0;

  List<String> configstrings = List(MAX_CONFIGSTRINGS);

	/* locally derived information from server state */
	List<Object> model_draw = List(MAX_MODELS);
	List<cmodel_t> model_clip = List(MAX_MODELS);
	List<Object> sound_precache = List(MAX_SOUNDS);
	List<Object> image_precache = List(MAX_IMAGES);

	List<clientinfo_t>	clientinfo = List(MAX_CLIENTS);
	clientinfo_t baseclientinfo = clientinfo_t(); 

  client_state_t() {
    for (int i = 0; i < MAX_CONFIGSTRINGS; i++) {
      configstrings[i] = "";
    }
    for (int i = 0; i < MAX_CLIENTS; i++) {
      clientinfo[i] = clientinfo_t();
    }
  }
}

client_state_t cl = client_state_t();

/* the client_static_t structure is persistant through
   an arbitrary number of server connections */
enum connstate_t {
	ca_uninitialized,
	ca_disconnected,  /* not talking to a server */
	ca_connecting, /* sending request packets to the server */
	ca_connected, /* netchan_t established, waiting for svc_serverdata */
	ca_active /* game views should be displayed */
}

enum keydest_t {key_game, key_console, key_message, key_menu}

class client_static_t {
	connstate_t	state = connstate_t.ca_uninitialized;
	keydest_t	key_dest = keydest_t.key_game;

	int			framecount = 0;
	int			realtime = 0; /* always increasing, no clamping, etc */
	double		rframetime = 0; /* seconds since last render frame */
	double		nframetime = 0; /* network frame time */

	/* screen rendering information */
	double		disable_screen = 0; /* showing loading plaque between levels */
								/* or changing rendering dlls */

	/* if time gets > 30 seconds ahead, break it */
	int			disable_servercount = 0; /* when we receive a frame and cl.servercount */
									 /* > cls.disable_servercount, clear disable_screen */

	/* connection information */
	String servername = ""; /* name of server from original connect */
	double		connect_time = 0; /* for connection retransmits */

	int			quakePort = 0; /* a 16 bit value that allows quake servers */
						   /* to work around address translating routers */
	netchan_t	netchan = netchan_t();
	int			serverProtocol = 0; /* in case we are doing some kind of version hack */

	int			challenge = 0; /* from the server to use for connecting */

	bool	forcePacket = false; /* Forces a package to be send at the next frame. */

// 	FILE		*download; /* file transfer from server */
// 	char		downloadtempname[MAX_OSPATH];
// 	char		downloadname[MAX_OSPATH];
	int			downloadnumber = 0;
// 	dltype_t	downloadtype;
// 	size_t		downloadposition;
	int			downloadpercent = 0;

	/* demo recording info must be here, so it isn't cleared on level change */
// 	qboolean	demorecording;
// 	qboolean	demowaiting; /* don't record until a non-delta message is received */
// 	FILE		*demofile;

// #ifdef USE_CURL
// 	/* http downloading */
// 	dlqueue_t  downloadQueue; /* queues with files to download. */
// 	dlhandle_t HTTPHandles[MAX_HTTP_HANDLES]; /* download handles. */
// 	char	   downloadServer[512]; /* URL prefix to dowload from .*/
// 	char	   downloadServerRetry[512]; /* retry count. */
// 	char	   downloadReferer[32]; /* referer string. */
// #endif
}

class cparticle_t {

	cparticle_t next;

	double		time;

	List<double>		org = [0,0,0];
	List<double>		vel = [0,0,0];
	List<double>		accel = [0,0,0];
	double		color;
	double		colorvel;
	double		alpha;
	double		alphavel;
}


client_static_t	cls = client_static_t();

List<centity_t> cl_entities = List(MAX_EDICTS);
List<entity_state_t> cl_parse_entities = List(MAX_PARSE_ENTITIES);
