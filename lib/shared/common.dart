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
 * Prototypes witch are shared between the client, the server and the
 * game. This is the main game API, changes here will most likely
 * requiere changes to the game ddl.
 *
 * =======================================================================
 */

const YQ2VERSION = "7.42pre";


const PROTOCOL_VERSION = 34;

/* ========================================= */

const PORT_MASTER = 27900;
const PORT_CLIENT = 27901;
const PORT_SERVER = 27910;

/* ========================================= */

const UPDATE_BACKUP = 16;    /* copies of entity_state_t to keep buffered */
const UPDATE_MASK = (UPDATE_BACKUP - 1);

/* server to client */
enum svc_ops_e {
	svc_bad,

	/* these ops are known to the game dll */
	svc_muzzleflash,
	svc_muzzleflash2,
	svc_temp_entity,
	svc_layout,
	svc_inventory,

	/* the rest are private to the client and server */
	svc_nop,
	svc_disconnect,
	svc_reconnect,
	svc_sound,                  /* <see code> */
	svc_print,                  /* [byte] id [string] null terminated string */
	svc_stufftext,              /* [string] stuffed into client's console buffer, should be \n terminated */
	svc_serverdata,             /* [long] protocol ... */
	svc_configstring,           /* [short] [string] */
	svc_spawnbaseline,
	svc_centerprint,            /* [string] to put in center of the screen */
	svc_download,               /* [short] size [size bytes] */
	svc_playerinfo,             /* variable */
	svc_packetentities,         /* [...] */
	svc_deltapacketentities,    /* [...] */
	svc_frame
}

/* ============================================== */

/* client to server */
enum clc_ops_e {
	clc_bad,
	clc_nop,
	clc_move,               /* [[usercmd_t] */
	clc_userinfo,           /* [[userinfo string] */
	clc_stringcmd           /* [string] message */
}

/* ============================================== */

/* plyer_state_t communication */
const PS_M_TYPE = (1 << 0);
const PS_M_ORIGIN = (1 << 1);
const PS_M_VELOCITY = (1 << 2);
const PS_M_TIME = (1 << 3);
const PS_M_FLAGS = (1 << 4);
const PS_M_GRAVITY = (1 << 5);
const PS_M_DELTA_ANGLES = (1 << 6);

const PS_VIEWOFFSET = (1 << 7);
const PS_VIEWANGLES = (1 << 8);
const PS_KICKANGLES = (1 << 9);
const PS_BLEND = (1 << 10);
const PS_FOV = (1 << 11);
const PS_WEAPONINDEX = (1 << 12);
const PS_WEAPONFRAME = (1 << 13);
const PS_RDFLAGS = (1 << 14);

/*============================================== */

/* user_cmd_t communication */

/* ms and light always sent, the others are optional */
const CM_ANGLE1 = (1 << 0);
const CM_ANGLE2 = (1 << 1);
const CM_ANGLE3 = (1 << 2);
const CM_FORWARD = (1 << 3);
const CM_SIDE = (1 << 4);
const CM_UP = (1 << 5);
const CM_BUTTONS = (1 << 6);
const CM_IMPULSE = (1 << 7);

/*============================================== */

/* a sound without an ent or pos will be a local only sound */
const SND_VOLUME = (1 << 0);         /* a byte */
const SND_ATTENUATION = (1 << 1);      /* a byte */
const SND_POS = (1 << 2);            /* three coordinates */
const SND_ENT = (1 << 3);            /* a short 0-2: channel, 3-12: entity */
const SND_OFFSET = (1 << 4);         /* a byte, msec offset from frame start */

const DEFAULT_SOUND_PACKET_VOLUME = 1.0;
const DEFAULT_SOUND_PACKET_ATTENUATION = 1.0;

/*============================================== */

/* entity_state_t communication */

/* try to pack the common update flags into the first byte */
const U_ORIGIN1 = (1 << 0);
const U_ORIGIN2 = (1 << 1);
const U_ANGLE2 = (1 << 2);
const U_ANGLE3 = (1 << 3);
const U_FRAME8 = (1 << 4);       /* frame is a byte */
const U_EVENT = (1 << 5);
const U_REMOVE = (1 << 6);       /* REMOVE this entity, don't add it */
const U_MOREBITS1 = (1 << 7);      /* read one additional byte */

/* second byte */
const U_NUMBER16 = (1 << 8);      /* NUMBER8 is implicit if not set */
const U_ORIGIN3 = (1 << 9);
const U_ANGLE1 = (1 << 10);
const U_MODEL = (1 << 11);
const U_RENDERFX8 = (1 << 12);     /* fullbright, etc */
const U_EFFECTS8 = (1 << 14);     /* autorotate, trails, etc */
const U_MOREBITS2 = (1 << 15);     /* read one additional byte */

/* third byte */
const U_SKIN8 = (1 << 16);
const U_FRAME16 = (1 << 17);     /* frame is a short */
const U_RENDERFX16 = (1 << 18);    /* 8 + 16 = 32 */
const U_EFFECTS16 = (1 << 19);     /* 8 + 16 = 32 */
const U_MODEL2 = (1 << 20);      /* weapons, flags, etc */
const U_MODEL3 = (1 << 21);
const U_MODEL4 = (1 << 22);
const U_MOREBITS3 = (1 << 23);     /* read one additional byte */

/* fourth byte */
const U_OLDORIGIN = (1 << 24);
const U_SKIN16 = (1 << 25);
const U_SOUND = (1 << 26);
const U_SOLID = (1 << 27);

const PORT_ANY = -1;
const MAX_MSGLEN = 1400;             /* max length of a message */
const PACKET_HEADER = 10;            /* two ints and a short */

enum netadrtype_t {
	NA_LOOPBACK,
	NA_BROADCAST,
	NA_IP,
	NA_IPX,
	NA_BROADCAST_IPX,
	NA_IP6,
	NA_MULTICAST6
}

enum netsrc_t { NS_CLIENT, NS_SERVER}

class netadr_t {
	netadrtype_t type = netadrtype_t.NA_LOOPBACK;
	// byte ip[16];
	// unsigned int scope_id;
	// byte ipx[10];
	int port = 0;

  static netadr_t fromString(String str) {
    netadr_t adr = netadr_t();
    if (str == "localhost") {
      adr.type = netadrtype_t.NA_LOOPBACK;
      return adr;
    }
    return null;
  }

  String toString() {
    if (this.type == netadrtype_t.NA_LOOPBACK) {
      return "localhost";
    } else {
      return "Unknown";
    }
  }

  bool IsLocalAddress() => this.type == netadrtype_t.NA_LOOPBACK;
}
