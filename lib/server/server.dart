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
 * Main header file for the client
 *
 * =======================================================================
 */
import 'dart:typed_data';

import 'package:dQuakeWeb/common/netchan.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/shared/writebuf.dart';

const LATENCY_COUNTS = 16;
const RATE_MESSAGES = 10;


/* MAX_CHALLENGES is made large to prevent a denial
   of service attack that could cycle all of them
   out before legitimate users connected */
const MAX_CHALLENGES = 1024;


enum server_state_t {
	ss_dead,            /* no map loaded */
	ss_loading,         /* spawning level edicts */
	ss_game,            /* actively running */
	ss_cinematic,
	ss_demo,
	ss_pic
}

class server_t {
	server_state_t state = server_state_t.ss_dead;           /* precache commands are only valid during load */

	bool attractloop = false;           /* running cinematics and demos for the local system only */
	bool loadgame = false;              /* client begins should reuse existing entity */

	int time = 0;                  /* always sv.framenum * 100 msec */
	int framenum = 0;

	String name = "";           /* map name, or cinematic name */
  List<cmodel_t> models = List(MAX_MODELS);

	List<String> configstrings = List.generate(MAX_CONFIGSTRINGS, (i) => "");
	List<entity_state_t> baselines = List.generate(MAX_EDICTS, (i) => entity_state_t());

	/* the multicast buffer is used to send a message to a set of clients
	   it is only used to marshall data until SV_Multicast is called */
  Writebuf multicast = Writebuf.size(MAX_MSGLEN);

	/* demo server information */
  ByteBuffer demobuffer;
  int demoOffset = 0;
	// qboolean timedemo; /* don't time sync */
}

enum client_state_t {
	cs_free,        /* can be reused for a new connection */
	cs_zombie,      /* client has been disconnected, but don't reuse 
					   connection for a couple seconds */
	cs_connected,   /* has been assigned to a client_t, but not in game yet */
	cs_spawned      /* client is fully in game */
}

class client_frame_t {
	int areabytes = 0;
	Uint8List areabits = Uint8List(MAX_MAP_AREAS ~/ 8);       /* portalarea visibility bits */
	player_state_t ps = player_state_t();
	int num_entities = 0;
	int first_entity = 0;                       /* into the circular sv_packet_entities[] */
	int senttime = 0;                           /* for ping calculations */

  clear() {
    this.areabytes = 0;
    this.ps.clear();
    this.num_entities = 0;
    this.first_entity = 0;
    this.senttime = 0;
  }
}

class client_t {
  int index;
	client_state_t state = client_state_t.cs_free;

	String userinfo = "";     /* name, etc */

	int lastframe = 0;                      /* for delta compression */
	usercmd_t lastcmd = usercmd_t();                  /* for filling in big drops */

	int commandMsec = 0;                    /* every seconds this is reset, if user */
										/* commands exhaust it, assume time cheating */

	List<int> frame_latency = List(LATENCY_COUNTS);
	int ping = 0;

	List<int> message_size = List(RATE_MESSAGES);    /* used to rate drop packets */
	int rate = 0;
	int surpressCount = 0;                  /* number of messages rate supressed */

	edict_s edict;                     /* EDICT_NUM(clientnum+1) */
	String name ="";                      /* extracted from userinfo, high bits masked */
	int messagelevel = 0;                   /* for filtering printed messages */

	/* The datagram is written to by sound calls, prints, 
	   temp ents, etc. It can be harmlessly overflowed. */
  Writebuf datagram = Writebuf.size(MAX_MSGLEN);

	List<client_frame_t> frames = List.generate(UPDATE_BACKUP, (i) => client_frame_t());     /* updates can be delta'd from here */

	// byte *download;                     /* file being downloaded */
	// int downloadsize;                   /* total bytes (can't use EOF because of paks) */
	// int downloadcount;                  /* bytes sent */

	int lastmessage = 0;                    /* sv.framenum when packet was last received */
	int lastconnect = 0;

	int challenge = 0;                      /* challenge of this user, randomly generated */

	netchan_t netchan = netchan_t();

  client_t(int index) {
    this.index = index;
  }

  clear() {
    this.state = client_state_t.cs_free;
    this.lastframe = 0;
	  this.lastcmd.clear();
	  this.commandMsec = 0;
    this.frame_latency.fillRange(0, this.frame_latency.length, 0);
	  this.ping = 0;
    this.message_size.fillRange(0, this.message_size.length, 0);
	  this.rate = 0;
	  this.surpressCount = 0;
	  this.edict = null;
	  this.name ="";
	  this.messagelevel = 0;
    for (var f in frames) {
      f.clear();
    }
	// byte *download;                     /* file being downloaded */
	// int downloadsize;                   /* total bytes (can't use EOF because of paks) */
	// int downloadcount;                  /* bytes sent */
	  this.lastmessage = 0;                    /* sv.framenum when packet was last received */
	  this.lastconnect = 0;
	  this.challenge = 0;
	// netchan_t netchan;
  }
}

class challenge_t {
	netadr_t adr;
	int challenge = 0;
	int time = 0;
}


class server_static_t {
	bool initialized = false;               /* sv_init has completed */
	int realtime = 0;                       /* always increasing, no clamping, etc */

	String mapcmd = "";       /* ie: *intro.cin+base */

	int spawncount = 0;                     /* incremented each server start */
										/* used to check late spawns */

	List<client_t> clients;                  /* [maxclients->value]; */
	int num_client_entities = 0;            /* maxclients->value*UPDATE_BACKUP*MAX_PACKET_ENTITIES */
	int next_client_entities = 0;           /* next client_entity to use */
	List<entity_state_t> client_entities;    /* [num_client_entities] */

	int last_heartbeat = 0;

	List<challenge_t> challenges = List.generate(MAX_CHALLENGES, (i) => challenge_t());    /* to prevent invalid IPs from connecting */

	// /* serverrecord values */
	// FILE *demofile;
	// sizebuf_t demo_multicast;
	// byte demo_multicast_buf[MAX_MSGLEN];
}

server_static_t svs = server_static_t();                 /* persistant server info */
server_t sv = server_t();                         /* local server */
client_t sv_client;
