/*
 * Copyright (C) 1997-2001 Id Software, Inc.
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
 * Main header file for the game module.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/shared/game.dart';

/* protocol bytes that can be directly added to messages */
const svc_muzzleflash = 1;
const svc_muzzleflash2 = 2;
const svc_temp_entity = 3;
const svc_layout = 4;
const svc_inventory = 5;
const svc_stufftext = 11;

/* ================================================================== */

/* view pitching times */
const DAMAGE_TIME = 0.5;
const FALL_TIME = 0.3;

/* these are set with checkboxes on each entity in the map editor */
const SPAWNFLAG_NOT_EASY = 0x00000100;
const SPAWNFLAG_NOT_MEDIUM = 0x00000200;
const SPAWNFLAG_NOT_HARD = 0x00000400;
const SPAWNFLAG_NOT_DEATHMATCH = 0x00000800;
const SPAWNFLAG_NOT_COOP = 0x00001000;

const FL_FLY = 0x00000001;
const FL_SWIM = 0x00000002; /* implied immunity to drowining */
const FL_IMMUNE_LASER = 0x00000004;
const FL_INWATER = 0x00000008;
const FL_GODMODE = 0x00000010;
const FL_NOTARGET = 0x00000020;
const FL_IMMUNE_SLIME = 0x00000040;
const FL_IMMUNE_LAVA = 0x00000080;
const FL_PARTIALGROUND = 0x00000100; /* not all corners are valid */
const FL_WATERJUMP = 0x00000200; /* player jumping out of water */
const FL_TEAMSLAVE = 0x00000400; /* not the first on the team */
const FL_NO_KNOCKBACK = 0x00000800;
const FL_POWER_ARMOR = 0x00001000; /* power armor (if any) is active */
const FL_RESPAWN = 0x80000000; /* used for item respawning */

const FRAMETIME = 0.1;

const MELEE_DISTANCE = 80;
const BODY_QUEUE_SIZE = 8;

enum damage_t {
	DAMAGE_NO,
	DAMAGE_YES, /* will take damage if hit */
	DAMAGE_AIM /* auto targeting recognizes this */
}

enum weaponstate_t {
	WEAPON_READY,
	WEAPON_ACTIVATING,
	WEAPON_DROPPING,
	WEAPON_FIRING
}

enum ammo_t {
	AMMO_BULLETS,
	AMMO_SHELLS,
	AMMO_ROCKETS,
	AMMO_GRENADES,
	AMMO_CELLS,
	AMMO_SLUGS
}

/* edict->movetype values */
enum movetype_t {
	MOVETYPE_NONE, /* never moves */
	MOVETYPE_NOCLIP, /* origin and angles change with no interaction */
	MOVETYPE_PUSH, /* no clip to world, push on box contact */
	MOVETYPE_STOP, /* no clip to world, stops on box contact */

	MOVETYPE_WALK, /* gravity */
	MOVETYPE_STEP, /* gravity, special edge handling */
	MOVETYPE_FLY,
	MOVETYPE_TOSS, /* gravity */
	MOVETYPE_FLYMISSILE, /* extra size to monsters */
	MOVETYPE_BOUNCE
}



class glistitem_t {
	String classname; /* spawning name */
	// qboolean (*pickup)(struct edict_s *ent, struct edict_s *other);
	// void (*use)(struct edict_s *ent, struct gitem_s *item);
	// void (*drop)(struct edict_s *ent, struct gitem_s *item);
	// void (*weaponthink)(struct edict_s *ent);
	String pickup_sound;
	String world_model;
	int world_model_flags = 0;
	String view_model;

	/* client side info */
	String icon;
	String pickup_name; /* for printing on pickup */
	int count_width = 0; /* number of digits to display by icon */

	int quantity = 0; /* for ammo how much, for weapons how much is used per shot */
	String ammo; /* for weapons */
	int flags = 0; /* IT_* flags */

	int weapmodel = 0; /* weapon model index (for weapons) */

	Object info;
	int tag = 0;

	String precaches; /* string of all models, sounds, and images this item will use */

  glistitem_t.empty() : this(null, null);

  glistitem_t(this.classname, this.pickup_name);
}

class gitem_t extends glistitem_t {
  int index;

  gitem_t(this.index, glistitem_t other) : super(other.classname, other.pickup_name);

}

/* fields are needed for spawning from the entity
   string and saving / loading games */
const FFL_SPAWNTEMP = 1;
const FFL_NOSPAWN = 2;
const FFL_ENTS= 4;

enum fieldtype_t {
	F_INT,
	F_FLOAT,
	F_LSTRING, /* string on disk, pointer in memory, TAG_LEVEL */
	F_GSTRING, /* string on disk, pointer in memory, TAG_GAME */
	F_VECTOR,
	F_ANGLEHACK,
	F_EDICT, /* index on disk, pointer in memory */
	F_ITEM, /* index on disk, pointer in memory */
	F_CLIENT, /* index on disk, pointer in memory */
	F_FUNCTION,
	F_MMOVE,
	F_IGNORE
}

class field_t {
	String name;
	int ofs;
	fieldtype_t type;
	int flags;
	int save_ver;
  String fname;

  field_t(this.name, this.type, { this.flags = 0, this.fname });
}

/* this structure is left intact through an entire game
   it should be initialized at dll load time, and read/written to
   the server.ssv file for savegames */
class game_locals_t {
	String helpmessage1 = "";
	String helpmessage2 = "";
	int helpchanged = 0; /* flash F1 icon if non 0, play sound
					    and increment only if 1, 2, or 3 */

	List<gclient_t> clients; /* [maxclients] */

	/* can't store spawnpoint in level, because
	   it would get overwritten by the savegame
	   restore */
	String spawnpoint = ""; /* needed for coop respawns */

	/* store latched cvars here that we want to get at often */
	int maxclients = 0;
	int maxentities = 0;

	/* cross level triggers */
	int serverflags = 0;

	/* items */
	int num_items = 0;

	bool autosaved = false;
}

/* this structure is cleared as each map is entered
   it is read/written to the level.sav file for savegames */
class level_locals_t {
	int framenum = 0;
	double time = 0;

	String level_name = ""; /* the descriptive name (Outer Base, etc) */
	String mapname = ""; /* the server name (base1, etc) */
	String nextmap = ""; /* go here when fraglimit is hit */

	/* intermission state */
	double intermissiontime = 0; /* time the intermission was started */
	String changemap;
	int exitintermission = 0;
	List<double> intermission_origin = [0,0,0];
	List<double> intermission_angle = [0,0,0];

	edict_t sight_client; /* changed once each frame for coop games */

	edict_t sight_entity;
	int sight_entity_framenum = 0;
	edict_t sound_entity;
	int sound_entity_framenum = 0;
	edict_t sound2_entity;
	int sound2_entity_framenum = 0;

	int pic_health = 0;

	int total_secrets = 0;
	int found_secrets = 0;

	int total_goals = 0;
	int found_goals = 0;

	int total_monsters = 0;
	int killed_monsters = 0;

	edict_t current_entity; /* entity running from G_RunFrame */
	int body_que = 0; /* dead bodies */

	int power_cubes = 0; /* ugly necessity for coop */
}

/* spawn_temp_t is only used to hold entity field values that
   can be set from the editor, but aren't actualy present
   in edict_t during gameplay */
class spawn_temp_t {
	/* world vars */
	String sky;
	double skyrotate = 0;
	List<double> skyaxis = [0,0,0];
	String nextmap;

	int lip = 0;
	int distance = 0;
	int height = 0;
	String noise;
	double pausetime = 0;
	String item;
	String gravity;

	double minyaw = 0;
	double maxyaw = 0;
	double minpitch = 0;
	double maxpitch = 0;
}

/* client data that stays across multiple level loads */
class client_persistant_t {
	String userinfo = "";
	String netname = "";
	int hand = 0;

	bool connected = false; /* a loadgame will leave valid entities that
						   just don't have a connection yet */

	/* values saved and restored
	   from edicts when changing levels */
	int health = 0;
	int max_health = 0;
	int savedFlags = 0;

	int selected_item = 0;
	// int inventory[MAX_ITEMS];

	/* ammo capacities */
	int max_bullets = 0;
	int max_shells = 0;
	int max_rockets = 0;
	int max_grenades = 0;
	int max_cells = 0;
	int max_slugs = 0;

	gitem_t weapon;
	gitem_t lastweapon;

	int power_cubes = 0; /* used for tracking the cubes in coop games */
	int score = 0; /* for calculating total unit score in coop games */

	int game_helpchanged = 0;
	int helpchanged = 0;

	bool spectator = false; /* client is a spectator */

  clear() {
	  this.userinfo = "";
	  this.netname = "";
	  this.hand = 0;
	  this.connected = false;
	  this.health = 0;
	  this.max_health = 0;
	  this.savedFlags = 0;
	  this.selected_item = 0;
	// int inventory[MAX_ITEMS];
	  this.max_bullets = 0;
	  this.max_shells = 0;
	  this.max_rockets = 0;
	  this.max_grenades = 0;
	  this.max_cells = 0;
	  this.max_slugs = 0;
	  this.weapon = null;
	  this.lastweapon = null;
	  this.power_cubes = 0;
	  this.score = 0;
	  this.game_helpchanged = 0;
	  this.helpchanged = 0;
	  this.spectator = false;
  }
}

/* client data that stays across deathmatch respawns */
class client_respawn_t {
	client_persistant_t coop_respawn = client_persistant_t(); /* what to set client->pers to on a respawn */
	int enterframe = 0; /* level.framenum the client entered the game */
	int score = 0; /* frags, etc */
	List<double> cmd_angles = [0,0,0]; /* angles sent over in the last command */

	bool spectator = false; /* client is a spectator */

  clear() {
    this.coop_respawn.clear();
    this.enterframe = 0;
    this.score = 0;
    this.cmd_angles.fillRange(0, 3, 0);
    this.spectator = false;
  }
}

/* this structure is cleared on each PutClientInServer(),
   except for 'client->pers' */
class gclient_t extends gclient_s {

  int index;

	/* private to game */
	client_persistant_t pers = client_persistant_t();
	client_respawn_t resp = client_respawn_t();
	// pmove_state_t old_pmove; /* for detecting out-of-pmove changes */

	bool showscores = false; /* set layout stat */
	bool showinventory = false; /* set layout stat */
	bool showhelp = false;
	bool showhelpicon = false;

	int ammo_index = 0;

	int buttons = 0;
	int oldbuttons = 0;
	int latched_buttons = 0;

	bool weapon_thunk = false;

	gitem_t newweapon;

	/* sum up damage over an entire frame, so
	   shotgun blasts give a single big kick */
	int damage_armor = 0; /* damage absorbed by armor */
	int damage_parmor = 0; /* damage absorbed by power armor */
	int damage_blood = 0; /* damage taken out of health */
	int damage_knockback = 0; /* impact damage */
	// vec3_t damage_from; /* origin for vector calculation */

	double killer_yaw = 0; /* when dead, look at killer */

	weaponstate_t weaponstate = weaponstate_t.WEAPON_READY;
	// vec3_t kick_angles; /* weapon kicks */
	// vec3_t kick_origin;
	double v_dmg_roll = 0, v_dmg_pitch = 0, v_dmg_time = 0; /* damage kicks */
	double fall_time = 0, fall_value = 0; /* for view drop on fall */
	double damage_alpha = 0;
	double bonus_alpha = 0;
	// vec3_t damage_blend;
	// vec3_t v_angle; /* aiming direction */
	double bobtime = 0; /* so off-ground doesn't change it */
	// vec3_t oldviewangles;
	// vec3_t oldvelocity;

	double next_drown_time = 0;
	int old_waterlevel = 0;
	int breather_sound = 0;

	int machinegun_shots = 0; /* for weapon raising */

	/* animation vars */
	int anim_end = 0;
	int anim_priority = 0;
	// bool anim_duck;
	// bool anim_run;

	/* powerup timers */
	// double quad_framenum;
	// double invincible_framenum;
	// double breather_framenum;
	// double enviro_framenum;

	// qboolean grenade_blew_up;
	// double grenade_time;
	// int silencer_shots;
	// int weapon_sound;

	// double pickup_msg_time;

	// double flood_locktill; /* locked from talking */
	// double flood_when[10]; /* when messages were said */
	// int flood_whenhead; /* head pointer for when said */

	double respawn_time = 0; /* can respawn when time > this */

	// edict_t *chase_target; /* player we are chasing */
	// qboolean update_chase; /* need to update chase info? */

  gclient_t(this.index);

  clearTemp() {
	  this.ps.clear();
	  this.ping = 0;

	  this.resp.clear();
	// pmove_state_t old_pmove;
	  this.showscores = false;
	  this.showinventory = false;
	  this.showhelp = false;
	  this.showhelpicon = false;
	  this.ammo_index = 0;
	  this.buttons = 0;
	  this.oldbuttons = 0;
	  this.latched_buttons = 0;
	  this.weapon_thunk = false;
	  this.newweapon = null;
	// // vec3_t damage_from; /* origin for vector calculation */
	  this.killer_yaw = 0;
    this.weaponstate = weaponstate_t.WEAPON_READY;
	// // vec3_t kick_angles; /* weapon kicks */
	// // vec3_t kick_origin;
	  this.v_dmg_roll = 0;
    this.v_dmg_pitch = 0;
    this.v_dmg_time = 0;
	  this.fall_time = 0;
    this.fall_value = 0;
	  this.damage_alpha = 0;
	  this.bonus_alpha = 0;
	// // vec3_t damage_blend;
	// // vec3_t v_angle; /* aiming direction */
	  this.bobtime = 0;
	// // vec3_t oldviewangles;
	// // vec3_t oldvelocity;
	  this.next_drown_time = 0;
	  this.old_waterlevel = 0;
	  this.breather_sound = 0;
	  this.machinegun_shots = 0;
	  this.anim_end = 0;
	  this.anim_priority = 0;
	// // bool anim_duck;
	// // bool anim_run;
	// // double quad_framenum;
	// // double invincible_framenum;
	// // double breather_framenum;
	// // double enviro_framenum;
	// // qboolean grenade_blew_up;
	// // double grenade_time;
	// // int silencer_shots;
	// // int weapon_sound;
	// // double pickup_msg_time;
	// // double flood_locktill; /* locked from talking */
	// // double flood_when[10]; /* when messages were said */
	// // int flood_whenhead; /* head pointer for when said */
	  this.respawn_time = 0;
	// edict_t *chase_target; /* player we are chasing */
	// qboolean update_chase; /* need to update chase info? */    
  }
}

class edict_t extends edict_s {

  int index;

	movetype_t movetype = movetype_t.MOVETYPE_NONE;
	int flags = 0;

	String model;
	double freetime = 0; /* sv.time when the object was freed */

	/* only used locally in game, not by server */
	String message;
	String classname;
	int spawnflags = 0;

	double timestamp = 0;

	double angle = 0; /* set in qe3, -1 = up, -2 = down */
	String target;
	String targetname;
	String killtarget;
	String team;
	String pathtarget;
	String deathtarget;
	String combattarget;
	edict_t target_ent;

	double speed = 0, accel = 0, decel = 0;
	List<double> movedir = [0,0,0];
	List<double> pos1 = [0,0,0], pos2 = [0,0,0];

	List<double> velocity = [0,0,0];
	List<double> avelocity = [0,0,0];
	int mass = 0;
	double air_finished = 0;
	double gravity = 0; /* per entity gravity multiplier (1.0 is normal)
				      use for lowgrav artifact, flares */

	edict_t goalentity;
	edict_t movetarget;
	double yaw_speed = 0;
	double ideal_yaw = 0;

	double nextthink = 0;
	// void (*prethink)(edict_t *ent);
	// void (*think)(edict_t *self);
	// void (*blocked)(edict_t *self, edict_t *other);
	// void (*touch)(edict_t *self, edict_t *other, cplane_t *plane,
	// 		csurface_t *surf);
	// void (*use)(edict_t *self, edict_t *other, edict_t *activator);
	// void (*pain)(edict_t *self, edict_t *other, float kick, int damage);
	// void (*die)(edict_t *self, edict_t *inflictor, edict_t *attacker,
	// 		int damage, vec3_t point);

	// double touch_debounce_time = 0;
	// double pain_debounce_time = 0;
	// double damage_debounce_time = 0;
	// double fly_sound_debounce_time = 0;
	// double last_move_time = 0;

	int health = 0;
	int max_health = 0;
	int gib_health = 0;
	int deadflag = 0;
	int show_hostile = 0;

	double powerarmor_time = 0;

	String map; /* target_changelevel */

	int viewheight = 0; /* height above origin where eyesight is determined */
	int takedamage = 0;
	int dmg = 0;
	int radius_dmg = 0;
	double dmg_radius = 0;
	int sounds = 0; /* make this a spawntemp var? */
	int count = 0;

	edict_t chain;
	edict_t enemy;
	edict_t oldenemy;
	edict_t activator;
	edict_t groundentity;
	int groundentity_linkcount = 0;
	edict_t teamchain;
	edict_t teammaster;

	edict_t mynoise; /* can go in client only */
	edict_t mynoise2;

	int noise_index = 0;
	int noise_index2 = 0;
	double volume = 0;
	double attenuation = 0;

	/* timing variables */
	double wait = 0;
	double delay = 0; /* before firing targets */
	double random = 0;

	// double last_sound_time = 0;

	// int watertype = 0;
	// int waterlevel = 0;

	// vec3_t move_origin;
	// vec3_t move_angles;

	// /* move this to clientinfo? */
	// int light_level = 0;

	// int style = 0; /* also used as areaportal number */

	// gitem_t *item = null; /* for bonus items */

	// /* common data blocks */
	// moveinfo_t moveinfo;
	// monsterinfo_t monsterinfo;  

  edict_t(int index) {
    this.index = index;
  }

  clear() {
    this.s.clear();
	  this.client = null;
	  this.inuse = false;
	  this.linkcount = 0;
	  this.num_clusters = 0;
	// int clusternums[MAX_ENT_CLUSTERS];
	  this.headnode = 0;
	  this.areanum = 0;
    this.areanum2 = 0;
	  this.svflags = 0;
    this.mins.fillRange(0, 3, 0);
    this.maxs.fillRange(0, 3, 0);
    this.absmin.fillRange(0, 3, 0);
    this.absmax.fillRange(0, 3, 0);
    this.size.fillRange(0, 3, 0);
	  this.solid = solid_t.SOLID_NOT;
	  this.clipmask = 0;
	  this.owner = null;

    this.movetype = movetype_t.MOVETYPE_NONE;
    this.flags = 0;
    this.model = null;
    this.freetime = 0;
    this.message = null;
    this.classname = null;
    this.spawnflags = 0;
    this.timestamp = 0;
    this.angle = 0;
    this.target = null;
    this.targetname = null;
    this.killtarget = null;
    this.team = null;
    this.pathtarget = null;
    this.deathtarget = null;
    this.combattarget = null;
    this.target_ent = null;
    this.speed = 0;
    this.accel = 0;
    this.decel = 0;
    this.movedir.fillRange(0, 3, 0);
    this.pos1.fillRange(0, 3, 0);
    this.pos2.fillRange(0, 3, 0);
    this.velocity.fillRange(0, 3, 0);
    this.avelocity.fillRange(0, 3, 0);
    this.mass = 0;
    this.air_finished = 0;
    this.gravity = 0;
    this.goalentity = null;
    this.movetarget = null;
    this.yaw_speed = 0;
    this.ideal_yaw = 0;
    this.nextthink = 0;
    // void (*prethink)(edict_t *ent);
    // void (*think)(edict_t *self);
    // void (*blocked)(edict_t *self, edict_t *other);
    // void (*touch)(edict_t *self, edict_t *other, cplane_t *plane,
    // 		csurface_t *surf);
    // void (*use)(edict_t *self, edict_t *other, edict_t *activator);
    // void (*pain)(edict_t *self, edict_t *other, float kick, int damage);
    // void (*die)(edict_t *self, edict_t *inflictor, edict_t *attacker,
    // 		int damage, vec3_t point);
    // float touch_debounce_time = 0;
    // float pain_debounce_time = 0;
    // float damage_debounce_time = 0;
    // float fly_sound_debounce_time = 0;
    // float last_move_time = 0;
    this.health = 0;
    this.max_health = 0;
    this.gib_health = 0;
    this.deadflag = 0;
    this.show_hostile = 0;
    this.powerarmor_time = 0;
    this.map = null;
    this.viewheight = 0;
    this.takedamage = 0;
    this.dmg = 0;
    this.radius_dmg = 0;
    this.dmg_radius = 0;
    this.sounds = 0;
    this.count = 0;
    this.chain = null;
    this.enemy = null;
    this.oldenemy = null;
    this.activator = null;
    this.groundentity = null;
    this.groundentity_linkcount = 0;
    this.teamchain = null;
    this.teammaster = null;
    this.mynoise = null;
    this.mynoise2 = null;
    this.noise_index = 0;
    this.noise_index2 = 0;
    this.volume = 0;
    this.attenuation = 0;
    this.wait = 0;
    this.delay = 0;
    this.random = 0;
    // float last_sound_time = 0;
    // int watertype = 0;
    // int waterlevel = 0;
    // vec3_t move_origin;
    // vec3_t move_angles;
    // int light_level = 0;
    // int style = 0;
    // gitem_t *item = null;
    // moveinfo_t moveinfo;
    // monsterinfo_t monsterinfo;  
  }
}

game_locals_t game = game_locals_t();
level_locals_t level = level_locals_t();
spawn_temp_t st = spawn_temp_t();

List<edict_t> g_edicts;

cvar_t deathmatch;
cvar_t coop;
cvar_t dmflags;
cvar_t skill;
cvar_t fraglimit;
cvar_t timelimit;
cvar_t password;
cvar_t spectator_password;
cvar_t needpass;
cvar_t maxclients;
cvar_t maxspectators;
cvar_t maxentities;
cvar_t g_select_empty;
cvar_t dedicated;

cvar_t filterban;

cvar_t sv_maxvelocity;
cvar_t sv_gravity;

cvar_t sv_rollspeed;
cvar_t sv_rollangle;
cvar_t gun_x;
cvar_t gun_y;
cvar_t gun_z;

cvar_t run_pitch;
cvar_t run_roll;
cvar_t bob_up;
cvar_t bob_pitch;
cvar_t bob_roll;

cvar_t sv_cheats;

cvar_t flood_msgs;
cvar_t flood_persecond;
cvar_t flood_waitdelay;

cvar_t sv_maplist;

cvar_t gib_on;