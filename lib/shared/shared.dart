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
 * Support functions, linked into client, server, renderer and game.
 *
 * =======================================================================
 */
import 'dart:math';
import 'game.dart' show edict_s;
import 'files.dart';

/* angle indexes */
const PITCH = 0;                     /* up / down */
const YAW = 1;                       /* left / right */
const ROLL = 2;                      /* fall over */


/* per-level limits */
const MAX_CLIENTS = 256;             /* absolute limit */
const MAX_EDICTS = 1024;             /* must change protocol to increase more */
const MAX_LIGHTSTYLES = 256;
const MAX_MODELS = 256;              /* these are sent over the net as bytes */
const MAX_SOUNDS = 256;              /* so they cannot be blindly increased */
const MAX_IMAGES = 256;
const MAX_ITEMS = 256;
const MAX_GENERAL = (MAX_CLIENTS * 2);       /* general config strings */

/* game print flags */
const PRINT_LOW = 0;                 /* pickup messages */
const PRINT_MEDIUM = 1;              /* death messages */
const PRINT_HIGH = 2;                /* critical messages */
const PRINT_CHAT = 3;                /* chat messages */

const ERR_FATAL = 0;                 /* exit the entire game with a popup window */
const ERR_DROP = 1;                  /* print to console and disconnect from game */
const ERR_DISCONNECT = 2;            /* don't kill server */

const PRINT_ALL = 0;
const PRINT_DEVELOPER = 1;           /* only print when "developer 1" */
const PRINT_ALERT = 2;

/* destination class for gi.multicast() */
enum multicast_t {
	MULTICAST_ALL,
	MULTICAST_PHS,
	MULTICAST_PVS,
	MULTICAST_ALL_R,
	MULTICAST_PHS_R,
	MULTICAST_PVS_R
}

/* content masks */
const MASK_ALL = -1;
const MASK_SOLID = CONTENTS_SOLID | CONTENTS_WINDOW;
const MASK_PLAYERSOLID =
	CONTENTS_SOLID | CONTENTS_PLAYERCLIP |
	 CONTENTS_WINDOW | CONTENTS_MONSTER;
const MASK_DEADSOLID  = CONTENTS_SOLID | CONTENTS_PLAYERCLIP | CONTENTS_WINDOW;
const MASK_MONSTERSOLID =
	(CONTENTS_SOLID | CONTENTS_MONSTERCLIP |
	 CONTENTS_WINDOW | CONTENTS_MONSTER);
const MASK_WATER = (CONTENTS_WATER | CONTENTS_LAVA | CONTENTS_SLIME);
const MASK_OPAQUE = (CONTENTS_SOLID | CONTENTS_SLIME | CONTENTS_LAVA);
const MASK_SHOT =
	(CONTENTS_SOLID | CONTENTS_MONSTER | CONTENTS_WINDOW |
	 CONTENTS_DEADMONSTER);
const MASK_CURRENT =
	(CONTENTS_CURRENT_0 | CONTENTS_CURRENT_90 |
	 CONTENTS_CURRENT_180 | CONTENTS_CURRENT_270 |
	 CONTENTS_CURRENT_UP |
	 CONTENTS_CURRENT_DOWN);

/* gi.BoxEdicts() can return a list of either solid or trigger entities */
const AREA_SOLID = 1;
const AREA_TRIGGERS = 2;

/* plane_t structure */
class cplane_t {
	List<double> normal = [0,0,0];
	double dist = 0;
	int type = 0; /* for fast side tests */
	int signbits = 0; /* signx + (signy<<1) + (signz<<2) */
	// byte pad[2];

  copy(cplane_t other) {
    this.normal.setAll(0, other.normal);
    this.dist = other.dist;
    this.type = other.type;
    this.signbits = other.signbits;
  }
}

/* structure offset for asm code */
const CPLANE_NORMAL_X = 0;
const CPLANE_NORMAL_Y = 4;
const CPLANE_NORMAL_Z = 8;
const CPLANE_DIST = 12;
const CPLANE_TYPE = 16;
const CPLANE_SIGNBITS = 17;
const CPLANE_PAD0 = 18;
const CPLANE_PAD1 = 19;

class cmodel_t {
	List<double> mins = [0,0,0], maxs = [0,0,0];
	List<double> origin = [0,0,0]; /* for sounds or lights */
	int headnode = 0;
}

class csurface_t {
	String name = "";
	int flags = 0; /* SURF_* */
	int value = 0; /* unused */
}

class mapsurface_t {  /* used internally due to name len probs */
	csurface_t c = csurface_t();
	String rname = "";
}

/* a trace is returned when a box is swept through the world */
class trace_t {
	bool allsolid = false;      /* if true, plane is not valid */
	bool startsolid = false;    /* if true, the initial point was in a solid area */
	double fraction = 0;         /* time completed, 1.0 = didn't hit anything */
	List<double> endpos = [0,0,0];          /* final position */
	cplane_t plane = cplane_t();         /* surface normal at impact */
	csurface_t surface;    /* surface hit */
	int contents = 0;           /* contents on other side of surface hit */
	dynamic ent;    /* not set by CM_*() functions */

  copy(trace_t other) {
    this.allsolid = other.allsolid;
    this.startsolid = other.startsolid;
    this.fraction = other.fraction;
    this.endpos.setAll(0, other.endpos);
    this.plane.copy(other.plane);
    this.surface = other.surface;
    this.contents = other.contents;
    this.ent = other.ent;
  }
}


/* pmove_state_t is the information necessary for client side movement */
/* prediction */
enum pmtype_t {
	/* can accelerate and turn */
	PM_NORMAL,
	PM_SPECTATOR,
	/* no acceleration or turning */
	PM_DEAD,
	PM_GIB, /* different bounding box */
	PM_FREEZE
}

/* pmove->pm_flags */
const PMF_DUCKED = 1;
const PMF_JUMP_HELD = 2;
const PMF_ON_GROUND = 4;
const PMF_TIME_WATERJUMP = 8;    /* pm_time is waterjump */
const PMF_TIME_LAND = 16;        /* pm_time is time before rejump */
const PMF_TIME_TELEPORT = 32;    /* pm_time is non-moving time */
const PMF_NO_PREDICTION = 64;    /* temporarily disables prediction (used for grappling hook) */

/* this structure needs to be communicated bit-accurate/
 * from the server to the client to guarantee that
 * prediction stays in sync, so no floats are used.
 * if any part of the game code modifies this struct, it
 * will result in a prediction error of some degree. */
class pmove_state_t {
	pmtype_t pm_type = pmtype_t.PM_NORMAL;

	List<int> origin = [0,0,0];            /* short 12.3 */
	List<int> velocity = [0,0,0];          /* short 12.3 */
	int pm_flags = 0;              /* byte ducked, jump_held, etc */
	int pm_time = 0;               /* byte each unit = 8 ms */
	int gravity = 0;              /* short */
	List<int> delta_angles = [0,0,0];      /* short add to command angles to get view direction
								 * changed by spawns, rotating objects, and teleporters */

  clear() {
    this.pm_type = pmtype_t.PM_NORMAL;
    this.origin.fillRange(0, 3, 0);
    this.velocity.fillRange(0, 3, 0);
    this.pm_flags = 0;
    this.pm_time = 0;
    this.gravity = 0;
    this.delta_angles.fillRange(0, 3, 0);
  }

  copy(pmove_state_t other) {
    this.pm_type = other.pm_type;
    this.origin.setAll(0, other.origin);
    this.velocity.setAll(0, other.velocity);
    this.pm_flags = other.pm_flags;
    this.pm_time = other.pm_time;
    this.gravity = other.gravity;
    this.delta_angles.setAll(0, other.delta_angles);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    final pmove_state_t typedOther = other;
    var diff = false;
    for (int i = 0; !diff && i < 3; i++) {
      diff = ((this.origin[i] != typedOther.origin[i]) ||
              (this.velocity[i] != typedOther.velocity[i]) ||
              (this.delta_angles[i] != typedOther.delta_angles[i]));
    }
    if (diff) {
      return false;
    }
    return (this.pm_type == typedOther.pm_type) &&
           (this.pm_flags == typedOther.pm_flags) &&
           (this.pm_time == typedOther.pm_time) &&
           (this.gravity == typedOther.gravity);
  }
}

/* button bits */
const BUTTON_ATTACK = 1;
const BUTTON_USE = 2;
const BUTTON_ANY = 128; /* any key whatsoever */

/* usercmd_t is sent to the server each client frame */
class usercmd_t {
	int msec = 0;
	int buttons = 0;
	List<int> angles= [0,0,0];
	int forwardmove = 0, sidemove = 0, upmove = 0;
	int impulse = 0;           /* remove? */
	int lightlevel = 0;        /* light level the player is standing on */

  clear() {
    this.msec = 0;
    this.buttons = 0;
    this.angles.fillRange(0, 3, 0);
    this.forwardmove = 0;
    this.sidemove = 0;
    this.upmove = 0;
    this.impulse = 0;
    this.lightlevel = 0;
  }

  copy(usercmd_t other) {
    this.msec = other.msec;
    this.buttons = other.buttons;
    this.angles.setAll(0, other.angles);
    this.forwardmove = other.forwardmove;
    this.sidemove = other.sidemove;
    this.upmove = other.upmove;
    this.impulse = other.impulse;
    this.lightlevel = other.lightlevel;
  }
}

const MAXTOUCH = 32;
class pmove_t {
	/* state (in / out) */
	pmove_state_t s = pmove_state_t();

	/* command (in) */
	usercmd_t cmd = usercmd_t();
	bool snapinitial = false;           /* if s has been changed outside pmove */

	/* results (out) */
	int numtouch = 0;
  List<edict_s> touchents = List(MAXTOUCH);

	List<double> viewangles = [0,0,0];              /* clamped */
	double viewheight;

	List<double> mins = [0,0,0], maxs = [0,0,0];              /* bounding box size */

	edict_s groundentity;
	int watertype = 0;
	int waterlevel = 0;

	/* callbacks to test the world */
	trace_t Function(List<double>, List<double>, List<double>, List<double>) trace;
	int Function(List<double>) pointcontents;
}

/* entity_state_t->effects
 * Effects are things handled on the client side (lights, particles,
 * frame animations)  that happen constantly on the given entity.
 * An entity that has effects will be sent to the client even if
 * it has a zero index model. */
const EF_ROTATE = 0x00000001;                /* rotate (bonus items) */
const EF_GIB = 0x00000002;                   /* leave a trail */
const EF_BLASTER = 0x00000008;               /* redlight + trail */
const EF_ROCKET = 0x00000010;                /* redlight + trail */
const EF_GRENADE = 0x00000020;
const EF_HYPERBLASTER = 0x00000040;
const EF_BFG = 0x00000080;
const EF_COLOR_SHELL = 0x00000100;
const EF_POWERSCREEN = 0x00000200;
const EF_ANIM01 = 0x00000400;                /* automatically cycle between frames 0 and 1 at 2 hz */
const EF_ANIM23 = 0x00000800;                /* automatically cycle between frames 2 and 3 at 2 hz */
const EF_ANIM_ALL = 0x00001000;              /* automatically cycle through all frames at 2hz */
const EF_ANIM_ALLFAST = 0x00002000;          /* automatically cycle through all frames at 10hz */
const EF_FLIES = 0x00004000;
const EF_QUAD = 0x00008000;
const EF_PENT = 0x00010000;
const EF_TELEPORTER = 0x00020000;            /* particle fountain */
const EF_FLAG1 = 0x00040000;
const EF_FLAG2 = 0x00080000;
const EF_IONRIPPER = 0x00100000;
const EF_GREENGIB = 0x00200000;
const EF_BLUEHYPERBLASTER = 0x00400000;
const EF_SPINNINGLIGHTS = 0x00800000;
const EF_PLASMA = 0x01000000;
const EF_TRAP = 0x02000000;
const EF_TRACKER = 0x04000000;
const EF_DOUBLE = 0x08000000;
const EF_SPHERETRANS = 0x10000000;
const EF_TAGTRAIL = 0x20000000;
const EF_HALF_DAMAGE = 0x40000000;
const EF_TRACKERTRAIL = 0x80000000;

/* entity_state_t->renderfx flags */
const RF_MINLIGHT = 1;               /* allways have some light (viewmodel) */
const RF_VIEWERMODEL = 2;            /* don't draw through eyes, only mirrors */
const RF_WEAPONMODEL = 4;            /* only draw through eyes */
const RF_FULLBRIGHT = 8;             /* allways draw full intensity */
const RF_DEPTHHACK = 16;             /* for view weapon Z crunching */
const RF_TRANSLUCENT = 32;
const RF_FRAMELERP = 64;
const RF_BEAM = 128;
const RF_CUSTOMSKIN = 256;           /* skin is an index in image_precache */
const RF_GLOW = 512;                 /* pulse lighting for bonus items */
const RF_SHELL_RED = 1024;
const RF_SHELL_GREEN = 2048;
const RF_SHELL_BLUE = 4096;
const RF_NOSHADOW = 8192;        /* don't draw a shadow */
const RF_IR_VISIBLE = 0x00008000;            /* = 32768 */
const RF_SHELL_DOUBLE = 0x00010000;          /* = 65536 */
const RF_SHELL_HALF_DAM = 0x00020000;
const RF_USE_DISGUISE = 0x00040000;

/* player_state_t->refdef flags */
const RDF_UNDERWATER = 1;            /* warp the screen as apropriate */
const RDF_NOWORLDMODEL = 2;          /* used for player configuration screen */
const RDF_IRGOGGLES = 4;
const RDF_UVGOGGLES = 8;

/* muzzle flashes / player effects */
const MZ_BLASTER = 0;
const MZ_MACHINEGUN = 1;
const MZ_SHOTGUN = 2;
const MZ_CHAINGUN1 = 3;
const MZ_CHAINGUN2 = 4;
const MZ_CHAINGUN3 = 5;
const MZ_RAILGUN = 6;
const MZ_ROCKET = 7;
const MZ_GRENADE = 8;
const MZ_LOGIN = 9;
const MZ_LOGOUT = 10;
const MZ_RESPAWN = 11;
const MZ_BFG = 12;
const MZ_SSHOTGUN = 13;
const MZ_HYPERBLASTER = 14;
const MZ_ITEMRESPAWN = 15;
const MZ_IONRIPPER = 16;
const MZ_BLUEHYPERBLASTER = 17;
const MZ_PHALANX = 18;
const MZ_SILENCED = 128;             /* bit flag ORed with one of the above numbers */
const MZ_ETF_RIFLE = 30;
const MZ_UNUSED = 31;
const MZ_SHOTGUN2 = 32;
const MZ_HEATBEAM = 33;
const MZ_BLASTER2 = 34;
const MZ_TRACKER = 35;
const MZ_NUKE1 = 36;
const MZ_NUKE2 = 37;
const MZ_NUKE4 = 38;
const MZ_NUKE8 = 39;

/* monster muzzle flashes */
const MZ2_TANK_BLASTER_1 = 1;
const MZ2_TANK_BLASTER_2 = 2;
const MZ2_TANK_BLASTER_3 = 3;
const MZ2_TANK_MACHINEGUN_1 = 4;
const MZ2_TANK_MACHINEGUN_2 = 5;
const MZ2_TANK_MACHINEGUN_3 = 6;
const MZ2_TANK_MACHINEGUN_4 = 7;
const MZ2_TANK_MACHINEGUN_5 = 8;
const MZ2_TANK_MACHINEGUN_6 = 9;
const MZ2_TANK_MACHINEGUN_7 = 10;
const MZ2_TANK_MACHINEGUN_8 = 11;
const MZ2_TANK_MACHINEGUN_9 = 12;
const MZ2_TANK_MACHINEGUN_10 = 13;
const MZ2_TANK_MACHINEGUN_11 = 14;
const MZ2_TANK_MACHINEGUN_12 = 15;
const MZ2_TANK_MACHINEGUN_13 = 16;
const MZ2_TANK_MACHINEGUN_14 = 17;
const MZ2_TANK_MACHINEGUN_15 = 18;
const MZ2_TANK_MACHINEGUN_16 = 19;
const MZ2_TANK_MACHINEGUN_17 = 20;
const MZ2_TANK_MACHINEGUN_18 = 21;
const MZ2_TANK_MACHINEGUN_19 = 22;
const MZ2_TANK_ROCKET_1 = 23;
const MZ2_TANK_ROCKET_2 = 24;
const MZ2_TANK_ROCKET_3 = 25;

const MZ2_INFANTRY_MACHINEGUN_1 = 26;
const MZ2_INFANTRY_MACHINEGUN_2 = 27;
const MZ2_INFANTRY_MACHINEGUN_3 = 28;
const MZ2_INFANTRY_MACHINEGUN_4 = 29;
const MZ2_INFANTRY_MACHINEGUN_5 = 30;
const MZ2_INFANTRY_MACHINEGUN_6 = 31;
const MZ2_INFANTRY_MACHINEGUN_7 = 32;
const MZ2_INFANTRY_MACHINEGUN_8 = 33;
const MZ2_INFANTRY_MACHINEGUN_9 = 34;
const MZ2_INFANTRY_MACHINEGUN_10 = 35;
const MZ2_INFANTRY_MACHINEGUN_11 = 36;
const MZ2_INFANTRY_MACHINEGUN_12 = 37;
const MZ2_INFANTRY_MACHINEGUN_13 = 38;

const MZ2_SOLDIER_BLASTER_1 = 39;
const MZ2_SOLDIER_BLASTER_2 = 40;
const MZ2_SOLDIER_SHOTGUN_1 = 41;
const MZ2_SOLDIER_SHOTGUN_2 = 42;
const MZ2_SOLDIER_MACHINEGUN_1 = 43;
const MZ2_SOLDIER_MACHINEGUN_2 = 44;

const MZ2_GUNNER_MACHINEGUN_1 = 45;
const MZ2_GUNNER_MACHINEGUN_2 = 46;
const MZ2_GUNNER_MACHINEGUN_3 = 47;
const MZ2_GUNNER_MACHINEGUN_4 = 48;
const MZ2_GUNNER_MACHINEGUN_5 = 49;
const MZ2_GUNNER_MACHINEGUN_6 = 50;
const MZ2_GUNNER_MACHINEGUN_7 = 51;
const MZ2_GUNNER_MACHINEGUN_8 = 52;
const MZ2_GUNNER_GRENADE_1 = 53;
const MZ2_GUNNER_GRENADE_2 = 54;
const MZ2_GUNNER_GRENADE_3 = 55;
const MZ2_GUNNER_GRENADE_4 = 56;

const MZ2_CHICK_ROCKET_1 = 57;

const MZ2_FLYER_BLASTER_1 = 58;
const MZ2_FLYER_BLASTER_2 = 59;

const MZ2_MEDIC_BLASTER_1 = 60;

const MZ2_GLADIATOR_RAILGUN_1 = 61;

const MZ2_HOVER_BLASTER_1 = 62;

const MZ2_ACTOR_MACHINEGUN_1 = 63;

const MZ2_SUPERTANK_MACHINEGUN_1 = 64;
const MZ2_SUPERTANK_MACHINEGUN_2 = 65;
const MZ2_SUPERTANK_MACHINEGUN_3 = 66;
const MZ2_SUPERTANK_MACHINEGUN_4 = 67;
const MZ2_SUPERTANK_MACHINEGUN_5 = 68;
const MZ2_SUPERTANK_MACHINEGUN_6 = 69;
const MZ2_SUPERTANK_ROCKET_1 = 70;
const MZ2_SUPERTANK_ROCKET_2 = 71;
const MZ2_SUPERTANK_ROCKET_3 = 72;

const MZ2_BOSS2_MACHINEGUN_L1 = 73;
const MZ2_BOSS2_MACHINEGUN_L2 = 74;
const MZ2_BOSS2_MACHINEGUN_L3 = 75;
const MZ2_BOSS2_MACHINEGUN_L4 = 76;
const MZ2_BOSS2_MACHINEGUN_L5 = 77;
const MZ2_BOSS2_ROCKET_1 = 78;
const MZ2_BOSS2_ROCKET_2 = 79;
const MZ2_BOSS2_ROCKET_3 = 80;
const MZ2_BOSS2_ROCKET_4 = 81;

const MZ2_FLOAT_BLASTER_1 = 82;

const MZ2_SOLDIER_BLASTER_3 = 83;
const MZ2_SOLDIER_SHOTGUN_3 = 84;
const MZ2_SOLDIER_MACHINEGUN_3 = 85;
const MZ2_SOLDIER_BLASTER_4 = 86;
const MZ2_SOLDIER_SHOTGUN_4 = 87;
const MZ2_SOLDIER_MACHINEGUN_4 = 88;
const MZ2_SOLDIER_BLASTER_5 = 89;
const MZ2_SOLDIER_SHOTGUN_5 = 90;
const MZ2_SOLDIER_MACHINEGUN_5 = 91;
const MZ2_SOLDIER_BLASTER_6 = 92;
const MZ2_SOLDIER_SHOTGUN_6 = 93;
const MZ2_SOLDIER_MACHINEGUN_6 = 94;
const MZ2_SOLDIER_BLASTER_7 = 95;
const MZ2_SOLDIER_SHOTGUN_7 = 96;
const MZ2_SOLDIER_MACHINEGUN_7 = 97;
const MZ2_SOLDIER_BLASTER_8 = 98;
const MZ2_SOLDIER_SHOTGUN_8 = 99;
const MZ2_SOLDIER_MACHINEGUN_8 = 100;

const MZ2_MAKRON_BFG = 101;
const MZ2_MAKRON_BLASTER_1 = 102;
const MZ2_MAKRON_BLASTER_2 = 103;
const MZ2_MAKRON_BLASTER_3 = 104;
const MZ2_MAKRON_BLASTER_4 = 105;
const MZ2_MAKRON_BLASTER_5 = 106;
const MZ2_MAKRON_BLASTER_6 = 107;
const MZ2_MAKRON_BLASTER_7 = 108;
const MZ2_MAKRON_BLASTER_8 = 109;
const MZ2_MAKRON_BLASTER_9 = 110;
const MZ2_MAKRON_BLASTER_10 = 111;
const MZ2_MAKRON_BLASTER_11 = 112;
const MZ2_MAKRON_BLASTER_12 = 113;
const MZ2_MAKRON_BLASTER_13 = 114;
const MZ2_MAKRON_BLASTER_14 = 115;
const MZ2_MAKRON_BLASTER_15 = 116;
const MZ2_MAKRON_BLASTER_16 = 117;
const MZ2_MAKRON_BLASTER_17 = 118;
const MZ2_MAKRON_RAILGUN_1 = 119;
const MZ2_JORG_MACHINEGUN_L1 = 120;
const MZ2_JORG_MACHINEGUN_L2 = 121;
const MZ2_JORG_MACHINEGUN_L3 = 122;
const MZ2_JORG_MACHINEGUN_L4 = 123;
const MZ2_JORG_MACHINEGUN_L5 = 124;
const MZ2_JORG_MACHINEGUN_L6 = 125;
const MZ2_JORG_MACHINEGUN_R1 = 126;
const MZ2_JORG_MACHINEGUN_R2 = 127;
const MZ2_JORG_MACHINEGUN_R3 = 128;
const MZ2_JORG_MACHINEGUN_R4 = 129;
const MZ2_JORG_MACHINEGUN_R5 = 130;
const MZ2_JORG_MACHINEGUN_R6 = 131;
const MZ2_JORG_BFG_1 = 132;
const MZ2_BOSS2_MACHINEGUN_R1 = 133;
const MZ2_BOSS2_MACHINEGUN_R2 = 134;
const MZ2_BOSS2_MACHINEGUN_R3 = 135;
const MZ2_BOSS2_MACHINEGUN_R4 = 136;
const MZ2_BOSS2_MACHINEGUN_R5 = 137;

const MZ2_CARRIER_MACHINEGUN_L1 = 138;
const MZ2_CARRIER_MACHINEGUN_R1 = 139;
const MZ2_CARRIER_GRENADE = 140;
const MZ2_TURRET_MACHINEGUN = 141;
const MZ2_TURRET_ROCKET = 142;
const MZ2_TURRET_BLASTER = 143;
const MZ2_STALKER_BLASTER = 144;
const MZ2_DAEDALUS_BLASTER = 145;
const MZ2_MEDIC_BLASTER_2 = 146;
const MZ2_CARRIER_RAILGUN = 147;
const MZ2_WIDOW_DISRUPTOR = 148;
const MZ2_WIDOW_BLASTER = 149;
const MZ2_WIDOW_RAIL = 150;
const MZ2_WIDOW_PLASMABEAM = 151;
const MZ2_CARRIER_MACHINEGUN_L2 = 152;
const MZ2_CARRIER_MACHINEGUN_R2 = 153;
const MZ2_WIDOW_RAIL_LEFT = 154;
const MZ2_WIDOW_RAIL_RIGHT = 155;
const MZ2_WIDOW_BLASTER_SWEEP1 = 156;
const MZ2_WIDOW_BLASTER_SWEEP2 = 157;
const MZ2_WIDOW_BLASTER_SWEEP3 = 158;
const MZ2_WIDOW_BLASTER_SWEEP4 = 159;
const MZ2_WIDOW_BLASTER_SWEEP5 = 160;
const MZ2_WIDOW_BLASTER_SWEEP6 = 161;
const MZ2_WIDOW_BLASTER_SWEEP7 = 162;
const MZ2_WIDOW_BLASTER_SWEEP8 = 163;
const MZ2_WIDOW_BLASTER_SWEEP9 = 164;
const MZ2_WIDOW_BLASTER_100 = 165;
const MZ2_WIDOW_BLASTER_90 = 166;
const MZ2_WIDOW_BLASTER_80 = 167;
const MZ2_WIDOW_BLASTER_70 = 168;
const MZ2_WIDOW_BLASTER_60 = 169;
const MZ2_WIDOW_BLASTER_50 = 170;
const MZ2_WIDOW_BLASTER_40 = 171;
const MZ2_WIDOW_BLASTER_30 = 172;
const MZ2_WIDOW_BLASTER_20 = 173;
const MZ2_WIDOW_BLASTER_10 = 174;
const MZ2_WIDOW_BLASTER_0 = 175;
const MZ2_WIDOW_BLASTER_10L = 176;
const MZ2_WIDOW_BLASTER_20L = 177;
const MZ2_WIDOW_BLASTER_30L = 178;
const MZ2_WIDOW_BLASTER_40L = 179;
const MZ2_WIDOW_BLASTER_50L = 180;
const MZ2_WIDOW_BLASTER_60L = 181;
const MZ2_WIDOW_BLASTER_70L = 182;
const MZ2_WIDOW_RUN_1 = 183;
const MZ2_WIDOW_RUN_2 = 184;
const MZ2_WIDOW_RUN_3 = 185;
const MZ2_WIDOW_RUN_4 = 186;
const MZ2_WIDOW_RUN_5 = 187;
const MZ2_WIDOW_RUN_6 = 188;
const MZ2_WIDOW_RUN_7 = 189;
const MZ2_WIDOW_RUN_8 = 190;
const MZ2_CARRIER_ROCKET_1 = 191;
const MZ2_CARRIER_ROCKET_2 = 192;
const MZ2_CARRIER_ROCKET_3 = 193;
const MZ2_CARRIER_ROCKET_4 = 194;
const MZ2_WIDOW2_BEAMER_1 = 195;
const MZ2_WIDOW2_BEAMER_2 = 196;
const MZ2_WIDOW2_BEAMER_3 = 197;
const MZ2_WIDOW2_BEAMER_4 = 198;
const MZ2_WIDOW2_BEAMER_5 = 199;
const MZ2_WIDOW2_BEAM_SWEEP_1 = 200;
const MZ2_WIDOW2_BEAM_SWEEP_2 = 201;
const MZ2_WIDOW2_BEAM_SWEEP_3 = 202;
const MZ2_WIDOW2_BEAM_SWEEP_4 = 203;
const MZ2_WIDOW2_BEAM_SWEEP_5 = 204;
const MZ2_WIDOW2_BEAM_SWEEP_6 = 205;
const MZ2_WIDOW2_BEAM_SWEEP_7 = 206;
const MZ2_WIDOW2_BEAM_SWEEP_8 = 207;
const MZ2_WIDOW2_BEAM_SWEEP_9 = 208;
const MZ2_WIDOW2_BEAM_SWEEP_10 = 209;
const MZ2_WIDOW2_BEAM_SWEEP_11 = 210;

/* Temp entity events are for things that happen
 * at a location seperate from any existing entity.
 * Temporary entity messages are explicitly constructed
 * and broadcast. */
enum temp_event_t {
	TE_GUNSHOT,
	TE_BLOOD,
	TE_BLASTER,
	TE_RAILTRAIL,
	TE_SHOTGUN,
	TE_EXPLOSION1,
	TE_EXPLOSION2,
	TE_ROCKET_EXPLOSION,
	TE_GRENADE_EXPLOSION,
	TE_SPARKS,
	TE_SPLASH,
	TE_BUBBLETRAIL,
	TE_SCREEN_SPARKS,
	TE_SHIELD_SPARKS,
	TE_BULLET_SPARKS,
	TE_LASER_SPARKS,
	TE_PARASITE_ATTACK,
	TE_ROCKET_EXPLOSION_WATER,
	TE_GRENADE_EXPLOSION_WATER,
	TE_MEDIC_CABLE_ATTACK,
	TE_BFG_EXPLOSION,
	TE_BFG_BIGEXPLOSION,
	TE_BOSSTPORT,           /* used as '22' in a map, so DON'T RENUMBER!!! */
	TE_BFG_LASER,
	TE_GRAPPLE_CABLE,
	TE_WELDING_SPARKS,
	TE_GREENBLOOD,
	TE_BLUEHYPERBLASTER,
	TE_PLASMA_EXPLOSION,
	TE_TUNNEL_SPARKS,
	TE_BLASTER2,
	TE_RAILTRAIL2,
	TE_FLAME,
	TE_LIGHTNING,
	TE_DEBUGTRAIL,
	TE_PLAIN_EXPLOSION,
	TE_FLASHLIGHT,
	TE_FORCEWALL,
	TE_HEATBEAM,
	TE_MONSTER_HEATBEAM,
	TE_STEAM,
	TE_BUBBLETRAIL2,
	TE_MOREBLOOD,
	TE_HEATBEAM_SPARKS,
	TE_HEATBEAM_STEAM,
	TE_CHAINFIST_SMOKE,
	TE_ELECTRIC_SPARKS,
	TE_TRACKER_EXPLOSION,
	TE_TELEPORT_EFFECT,
	TE_DBALL_GOAL,
	TE_WIDOWBEAMOUT,
	TE_NUKEBLAST,
	TE_WIDOWSPLASH,
	TE_EXPLOSION1_BIG,
	TE_EXPLOSION1_NP,
	TE_FLECHETTE
}

/* player_state->stats[] indexes */
const STAT_HEALTH_ICON = 0;
const STAT_HEALTH = 1;
const STAT_AMMO_ICON = 2;
const STAT_AMMO = 3;
const STAT_ARMOR_ICON = 4;
const STAT_ARMOR = 5;
const STAT_SELECTED_ICON = 6;
const STAT_PICKUP_ICON = 7;
const STAT_PICKUP_STRING = 8;
const STAT_TIMER_ICON = 9;
const STAT_TIMER = 10;
const STAT_HELPICON = 11;
const STAT_SELECTED_ITEM = 12;
const STAT_LAYOUTS = 13;
const STAT_FRAGS = 14;
const STAT_FLASHES = 15;                 /* cleared each frame, 1 = health, 2 = armor */
const STAT_CHASE = 16;
const STAT_SPECTATOR = 17;

const MAX_STATS = 32;

/* dmflags->value flags */
const DF_NO_HEALTH = 0x00000001;         /* 1 */
const DF_NO_ITEMS = 0x00000002;          /* 2 */
const DF_WEAPONS_STAY = 0x00000004;      /* 4 */
const DF_NO_FALLING = 0x00000008;        /* 8 */
const DF_INSTANT_ITEMS = 0x00000010;     /* 16 */
const DF_SAME_LEVEL = 0x00000020;        /* 32 */
const DF_SKINTEAMS = 0x00000040;         /* 64 */
const DF_MODELTEAMS = 0x00000080;        /* 128 */
const DF_NO_FRIENDLY_FIRE = 0x00000100;  /* 256 */
const DF_SPAWN_FARTHEST = 0x00000200;    /* 512 */
const DF_FORCE_RESPAWN = 0x00000400;     /* 1024 */
const DF_NO_ARMOR = 0x00000800;          /* 2048 */
const DF_ALLOW_EXIT = 0x00001000;        /* 4096 */
const DF_INFINITE_AMMO = 0x00002000;     /* 8192 */
const DF_QUAD_DROP = 0x00004000;         /* 16384 */
const DF_FIXED_FOV = 0x00008000;         /* 32768 */
const DF_QUADFIRE_DROP = 0x00010000;     /* 65536 */
const DF_NO_MINES = 0x00020000;
const DF_NO_STACK_DOUBLE = 0x00040000;
const DF_NO_NUKES = 0x00080000;
const DF_NO_SPHERES = 0x00100000;

/*
 * ==========================================================
 *
 * ELEMENTS COMMUNICATED ACROSS THE NET
 *
 * ==========================================================
 */

int ANGLE2SHORT(double x) => (((x) * 65536 ~/ 360) & 65535);
double SHORT2ANGLE(int x) => ((x) * (360.0 / 65536));

/* config strings are a general means of communication from
 * the server to all connected clients. Each config string
 * can be at most MAX_QPATH characters. */
const CS_NAME = 0;
const CS_CDTRACK = 1;
const CS_SKY = 2;
const CS_SKYAXIS = 3;                /* %f %f %f format */
const CS_SKYROTATE = 4;
const CS_STATUSBAR = 5;              /* display program string */

const CS_AIRACCEL = 29;              /* air acceleration control */
const CS_MAXCLIENTS = 30;
const CS_MAPCHECKSUM = 31;           /* for catching cheater maps */

const CS_MODELS = 32;
const CS_SOUNDS = (CS_MODELS + MAX_MODELS);
const CS_IMAGES = (CS_SOUNDS + MAX_SOUNDS);
const CS_LIGHTS = (CS_IMAGES + MAX_IMAGES);
const CS_ITEMS = (CS_LIGHTS + MAX_LIGHTSTYLES);
const CS_PLAYERSKINS = (CS_ITEMS + MAX_ITEMS);
const CS_GENERAL = (CS_PLAYERSKINS + MAX_CLIENTS);
const MAX_CONFIGSTRINGS = (CS_GENERAL + MAX_GENERAL);

/* ============================================== */

/* entity_state_t->event values
 * entity events are for effects that take place reletive
 * to an existing entities origin.  Very network efficient.
 * All muzzle flashes really should be converted to events... */
enum entity_event_t {
	EV_NONE,
	EV_ITEM_RESPAWN,
	EV_FOOTSTEP,
	EV_FALLSHORT,
	EV_FALL,
	EV_FALLFAR,
	EV_PLAYER_TELEPORT,
	EV_OTHER_TELEPORT
}

/* entity_state_t is the information conveyed from the server
 * in an update message about entities that the client will
 * need to render in some way */
class entity_state_t {
	int number = 0;             /* edict index */

	List<double> origin = [0,0,0];
	List<double> angles = [0,0,0];
	List<double> old_origin = [0,0,0];      /* for lerping */
	int modelindex = 0;
	int modelindex2 = 0, modelindex3 = 0, modelindex4 = 0;      /* weapons, CTF flags, etc */
	int frame = 0;
	int skinnum = 0;
	int effects = 0;
	int renderfx = 0;
	int solid = 0;              /* for client side prediction, 8*(bits 0-4) is x/y radius */
							/* 8*(bits 5-9) is z down distance, 8(bits10-15) is z up */
							/* gi.linkentity sets this properly */
	int sound = 0;              /* for looping sounds, to guarantee shutoff */
	int event = 0;              /* impulse events -- muzzle flashes, footsteps, etc */
							/* events only go out for a single frame, they */
							/* are automatically cleared each frame */

  clear() {
    this.number = 0;
    this.modelindex = 0;
    this.modelindex2 = 0;
    this.modelindex3 = 0;
    this.modelindex4 = 0;
    this.frame = 0;
    this.skinnum = 0;
    this.effects = 0;
    this.renderfx = 0;
    this.solid = 0;
    this.sound = 0;
    this.event = 0;
    this.origin.fillRange(0, 3, 0);
    this.angles.fillRange(0, 3, 0);
    this.old_origin.fillRange(0, 3, 0);
  }

  copy(entity_state_t other) {
    this.number = other.number;
    this.modelindex = other.modelindex;
    this.modelindex2 = other.modelindex2;
    this.modelindex3 = other.modelindex3;
    this.modelindex4 = other.modelindex4;
    this.frame = other.frame;
    this.skinnum = other.skinnum;
    this.effects = other.effects;
    this.renderfx = other.renderfx;
    this.solid = other.solid;
    this.sound = other.sound;
    this.event = other.event;
    this.origin.setAll(0, other.origin);
    this.angles.setAll(0, other.angles);
    this.old_origin.setAll(0, other.old_origin);
  }
}

/* ============================================== */

/* player_state_t is the information needed in addition to pmove_state_t
 * to rendered a view.  There will only be 10 player_state_t sent each second,
 * but the number of pmove_state_t changes will be reletive to client
 * frame rates */
class player_state_t {
	pmove_state_t pmove = pmove_state_t();        /* for prediction */

	List<double> viewangles = [0,0,0];          /* for fixed views */
	List<double> viewoffset = [0,0,0];          /* add to pmovestate->origin */
	List<double> kick_angles = [0,0,0];         /* add to view direction to get render angles */
								/* set by weapon kicks, pain effects, etc */

	List<double> gunangles = [0,0,0];
	List<double> gunoffset = [0,0,0];
	int gunindex = 0;
	int gunframe = 0;

	List<double> blend = [0,0,0,0];             /* rgba full screen effect */
	double fov = 0;                  /* horizontal field of view */
	int rdflags = 0;                /* refdef flags */

	List<int> stats = List.generate(MAX_STATS, (i) => 0);     /* fast status bar updates */

  clear() {
    this.pmove.clear();
    this.viewangles.fillRange(0, 3, 0);
    this.viewoffset.fillRange(0, 3, 0);
    this.kick_angles.fillRange(0, 3, 0);
    this.gunangles.fillRange(0, 3, 0);
    this.gunoffset.fillRange(0, 3, 0);
    this.gunindex = 0;
    this.gunframe = 0;
    this.blend.fillRange(0, 4, 0);
    this.fov = 0;
    this.rdflags = 0;
    this.stats.fillRange(0, MAX_STATS, 0);
 }

  copy(player_state_t other) {
    this.pmove.copy(other.pmove);
    this.viewangles.setAll(0, other.viewangles);
    this.viewoffset.setAll(0, other.viewoffset);
    this.kick_angles.setAll(0, other.kick_angles);
    this.gunangles.setAll(0, other.gunangles);
    this.gunoffset.setAll(0, other.gunoffset);
    this.gunindex = other.gunindex;
    this.gunframe = other.gunframe;
    this.blend.setAll(0, other.blend);
    this.fov = other.fov;
    this.rdflags = other.rdflags;
    this.stats.setAll(0, other.stats);
 }
}

final rand = Random();

/* 
 * Generate a pseudorandom 
 * integer >0. 
 */
int randk() {
  return rand.nextInt(0xffffffff);
}

/*
 * Generate a pseudorandom
 * signed float between 
 * 0 and 1.
 */
double frandk() {
  return rand.nextDouble();
}

/* Generate a pseudorandom
 * float between -1 and 1.
 */
double crandk() {
  return (2.0 * rand.nextDouble()) - 1.0;
}

double DEG2RAD(a) =>(a * pi) / 180.0;

/* ============================================================================ */

RotatePointAroundVector(List<double> dst, List<double> dir,
		List<double> point, double degrees) {
	// float m[3][3];
	// float im[3][3];
	// float zrot[3][3];
	// float tmpmat[3][3];
	// float rot[3][3];
	// int i;
	// vec3_t vr, vup, vf;

  final vf = List.generate(3, (i) => dir[i]);

  List<double> vr = [0,0,0];
	PerpendicularVector(vr, dir);
  List<double> vup = [0,0,0];
	CrossProduct(vr, vf, vup);

  List<List<double>> m = List.generate(3, (i) => [0,0,0]);
	m[0][0] = vr[0];
	m[1][0] = vr[1];
	m[2][0] = vr[2];

	m[0][1] = vup[0];
	m[1][1] = vup[1];
	m[2][1] = vup[2];

	m[0][2] = vf[0];
	m[1][2] = vf[1];
	m[2][2] = vf[2];

  List<List<double>> im = List.generate(3, (i) => List.generate(3, (j) => m[i][j]));

	im[0][1] = m[1][0];
	im[0][2] = m[2][0];
	im[1][0] = m[0][1];
	im[1][2] = m[2][1];
	im[2][0] = m[0][2];
	im[2][1] = m[1][2];

  List<List<double>> zrot = List.generate(3, (i) => [0,0,0]);
	zrot[0][0] = zrot[1][1] = zrot[2][2] = 1.0;

	zrot[0][0] = cos(DEG2RAD(degrees));
	zrot[0][1] = sin(DEG2RAD(degrees));
	zrot[1][0] = -sin(DEG2RAD(degrees));
	zrot[1][1] = cos(DEG2RAD(degrees));

  List<List<double>> tmpmat = List.generate(3, (i) => [0,0,0]);
	R_ConcatRotations(m, zrot, tmpmat);
  List<List<double>> rot = List.generate(3, (i) => [0,0,0]);
	R_ConcatRotations(tmpmat, im, rot);

	for (int i = 0; i < 3; i++) {
		dst[i] = rot[i][0] * point[0] + rot[i][1] * point[1] + rot[i][2] *
				 point[2];
	}
}

AngleVectors(List<double> angles, List<double> forward, List<double> right, List<double> up) {

	var angle = angles[YAW] * (pi * 2 / 360);
	final sy = sin(angle);
	final cy = cos(angle);
	angle = angles[PITCH] * (pi * 2 / 360);
	final sp = sin(angle);
	final cp = cos(angle);
	angle = angles[ROLL] * (pi * 2 / 360);
	final sr = sin(angle);
	final cr = cos(angle);

	if (forward != null) {
		forward[0] = cp * cy;
		forward[1] = cp * sy;
		forward[2] = -sp;
	}

	if (right != null) {
		right[0] = (-1 * sr * sp * cy + - 1 * cr * -sy);
		right[1] = (-1 * sr * sp * sy + - 1 * cr * cy);
		right[2] = -1 * sr * cp;
	}

	if (up != null) {
		up[0] = (cr * sp * cy + - sr * -sy);
		up[1] = (cr * sp * sy + - sr * cy);
		up[2] = cr * cp;
	}
}

void
ProjectPointOnPlane(List<double> dst, List<double> p, List<double> normal) {

	final inv_denom = 1.0 / DotProduct(normal, normal);

	final d = DotProduct(normal, p) * inv_denom;

  List<double> n = List.generate(3, (i) => normal[i] * inv_denom);

	dst[0] = p[0] - d * n[0];
	dst[1] = p[1] - d * n[1];
	dst[2] = p[2] - d * n[2];
}

/* assumes "src" is normalized */
PerpendicularVector(List<double> dst, List<double> src) {

	/* find the smallest magnitude axially aligned vector */
  int pos = 0;
  double minelem = 1.0;
	for (int i = 0; i < 3; i++) {
		if (src[i].abs() < minelem) {
			pos = i;
			minelem = src[i].abs();
		}
	}

	List<double> tempvec = [0,0,0];
	tempvec[pos] = 1.0;

	/* project the point onto the plane defined by src */
	ProjectPointOnPlane(dst, tempvec, src);

	/* normalize the result */
	VectorNormalize(dst);
}

R_ConcatRotations(List<List<double>> in1, List<List<double>> in2, List<List<double>> out) {
	out[0][0] = in1[0][0] * in2[0][0] + in1[0][1] * in2[1][0] +
				in1[0][2] * in2[2][0];
	out[0][1] = in1[0][0] * in2[0][1] + in1[0][1] * in2[1][1] +
				in1[0][2] * in2[2][1];
	out[0][2] = in1[0][0] * in2[0][2] + in1[0][1] * in2[1][2] +
				in1[0][2] * in2[2][2];
	out[1][0] = in1[1][0] * in2[0][0] + in1[1][1] * in2[1][0] +
				in1[1][2] * in2[2][0];
	out[1][1] = in1[1][0] * in2[0][1] + in1[1][1] * in2[1][1] +
				in1[1][2] * in2[2][1];
	out[1][2] = in1[1][0] * in2[0][2] + in1[1][1] * in2[1][2] +
				in1[1][2] * in2[2][2];
	out[2][0] = in1[2][0] * in2[0][0] + in1[2][1] * in2[1][0] +
				in1[2][2] * in2[2][0];
	out[2][1] = in1[2][0] * in2[0][1] + in1[2][1] * in2[1][1] +
				in1[2][2] * in2[2][1];
	out[2][2] = in1[2][0] * in2[0][2] + in1[2][1] * in2[1][2] +
				in1[2][2] * in2[2][2];
}

double LerpAngle(double a2, double a1, double frac) {
	if (a1 - a2 > 180)
	{
		a1 -= 360;
	}

	if (a1 - a2 < -180)
	{
		a1 += 360;
	}

	return a2 + frac * (a1 - a2);
}

double anglemod(double a) {
	return (360.0 / 65536) * ((a * (65536 / 360.0)).toInt() & 65535);
}

/*
 * Returns 1, 2, or 1 + 2
 */
int BoxOnPlaneSide(List<double> emins, List<double> emaxs, cplane_t p) {
	// float dist1, dist2;
	// int sides;

	/* fast axial cases */
	if (p.type < 3)
	{
		if (p.dist <= emins[p.type])
		{
			return 1;
		}

		if (p.dist >= emaxs[p.type])
		{
			return 2;
		}

		return 3;
	}

	/* general case */
  double dist1, dist2;
	switch (p.signbits)
	{
		case 0:
			dist1 = p.normal[0] * emaxs[0] + p.normal[1] * emaxs[1] +
					p.normal[2] * emaxs[2];
			dist2 = p.normal[0] * emins[0] + p.normal[1] * emins[1] +
					p.normal[2] * emins[2];
			break;
		case 1:
			dist1 = p.normal[0] * emins[0] + p.normal[1] * emaxs[1] +
					p.normal[2] * emaxs[2];
			dist2 = p.normal[0] * emaxs[0] + p.normal[1] * emins[1] +
					p.normal[2] * emins[2];
			break;
		case 2:
			dist1 = p.normal[0] * emaxs[0] + p.normal[1] * emins[1] +
					p.normal[2] * emaxs[2];
			dist2 = p.normal[0] * emins[0] + p.normal[1] * emaxs[1] +
					p.normal[2] * emins[2];
			break;
		case 3:
			dist1 = p.normal[0] * emins[0] + p.normal[1] * emins[1] +
					p.normal[2] * emaxs[2];
			dist2 = p.normal[0] * emaxs[0] + p.normal[1] * emaxs[1] +
					p.normal[2] * emins[2];
			break;
		case 4:
			dist1 = p.normal[0] * emaxs[0] + p.normal[1] * emaxs[1] +
					p.normal[2] * emins[2];
			dist2 = p.normal[0] * emins[0] + p.normal[1] * emins[1] +
					p.normal[2] * emaxs[2];
			break;
		case 5:
			dist1 = p.normal[0] * emins[0] + p.normal[1] * emaxs[1] +
					p.normal[2] * emins[2];
			dist2 = p.normal[0] * emaxs[0] + p.normal[1] * emins[1] +
					p.normal[2] * emaxs[2];
			break;
		case 6:
			dist1 = p.normal[0] * emaxs[0] + p.normal[1] * emins[1] +
					p.normal[2] * emins[2];
			dist2 = p.normal[0] * emins[0] + p.normal[1] * emaxs[1] +
					p.normal[2] * emaxs[2];
			break;
		case 7:
			dist1 = p.normal[0] * emins[0] + p.normal[1] * emins[1] +
					p.normal[2] * emins[2];
			dist2 = p.normal[0] * emaxs[0] + p.normal[1] * emaxs[1] +
					p.normal[2] * emaxs[2];
			break;
		default:
			dist1 = dist2 = 0;
			break;
	}

	int sides = 0;

	if (dist1 >= p.dist)
	{
		sides = 1;
	}

	if (dist2 < p.dist)
	{
		sides |= 2;
	}

	return sides;
}

double VectorNormalize(List<double> v) {

	double length = v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
	length = sqrt(length);

	if (length != 0) {
		final ilength = 1 / length;
		v[0] *= ilength;
		v[1] *= ilength;
		v[2] *= ilength;
	}

	return length;
}

VectorMA(List<double> veca, double scale, List<double> vecb, List<double> vecc) {
	vecc[0] = veca[0] + scale * vecb[0];
	vecc[1] = veca[1] + scale * vecb[1];
	vecc[2] = veca[2] + scale * vecb[2];
}


double DotProduct(List<double> v1, List<double> v2) {
	return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
}

CrossProduct(List<double> v1, List<double> v2, List<double> cross) {
	cross[0] = v1[1] * v2[2] - v1[2] * v2[1];
	cross[1] = v1[2] * v2[0] - v1[0] * v2[2];
	cross[2] = v1[0] * v2[1] - v1[1] * v2[0];
}

double VectorLength(List<double> src) {
  return sqrt(src[0] * src[0] + src[1] * src[1] + src[2] * src[2]);
}

VectorSubtract(List<double> veca, List<double> vecb, List<double> out) {
	out[0] = veca[0] - vecb[0];
	out[1] = veca[1] - vecb[1];
	out[2] = veca[2] - vecb[2];
}

VectorSubtractI(List<int> veca, List<int> vecb, List<int> out) {
	out[0] = veca[0] - vecb[0];
	out[1] = veca[1] - vecb[1];
	out[2] = veca[2] - vecb[2];
}

VectorAdd(List<double> veca, List<double> vecb, List<double> out) {
	out[0] = veca[0] + vecb[0];
	out[1] = veca[1] + vecb[1];
	out[2] = veca[2] + vecb[2];
}

VectorScale(List<double> ind, double scale, List<double> out) {
	out[0] = ind[0] * scale;
	out[1] = ind[1] * scale;
	out[2] = ind[2] * scale;
}

class ParseResult {
  String token;
  int index;

  ParseResult(this.token, this.index);
}

/*
 * Parse a token out of a string
 */
ParseResult COM_Parse(String data, int index) {

	if (data == null || index < 0 || index >= data.length) {
		return null;
	}

  var skipwhite = false;
  var token = StringBuffer();

  do {
    while (index < data.length && data.codeUnitAt(index) <= 32) {
      index++;
    }

    if (index >= data.length) {
      return null;
    }

    /* skip // comments */
    if ((data[index] == '/') && (data[index + 1] == '/')) {
      while (index < data.length && data[index] != '\n') {
        index++;
      }

      skipwhite = true;
    }
  } while (skipwhite);

	/* handle quoted strings specially */
	if (data[index] == '\"') {
		index++;

		while (index < data.length) {
			var c = data[index++];
			if (c == '\"') {
				return ParseResult(token.toString(), index);
			}

      token.write(c);
		}
    return ParseResult(token.toString(), index);
	}

	/* parse a regular word */
	do {
      token.write(data[index++]);
	} while (index < data.length && data.codeUnitAt(index) > 32);

	return ParseResult(token.toString(), index);
}

/*
 * Some characters are illegal in info strings
 * because they can mess up the server's parsing
 */
bool Info_Validate(String s) {
	if (s.contains("\"")) {
		return false;
	}

	if (s.contains(";")) {
		return false;
	}

	return true;
}

String Info_ValueForKey(String s, String key) {
  if (s == null || s.isEmpty) {
    return "";
  }

  final spl = s.split("\\");
  int first = 1;
  while (true) {
    var index = spl.indexOf(key, first);
    if (index < 0) {
      return "";
    }
    if ((index & 1) != 0) {
      return spl[index + 1];
    }
    first = index + 1;
  }
}