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
 * Infantry.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/game/g_misc.dart';
import 'package:dQuakeWeb/game/g_monster.dart';
import 'package:dQuakeWeb/game/g_weapon.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/flash.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import '../../game.dart';
import '../../g_ai.dart';
import '../../g_utils.dart';

int _sound_pain1;
int _sound_pain2;
int _sound_die1;
int _sound_die2;

int _sound_gunshot;
int _sound_weapon_cock;
int _sound_punch_swing;
int _sound_punch_hit;
int _sound_sight;
int _sound_search;
int _sound_idle;

final infantry_frames_stand = [
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null)
];

final infantry_move_stand = mmove_t(
	_FRAME_stand50,
	_FRAME_stand71,
  infantry_frames_stand,
  null
);

_infantry_stand(edict_t self) {
	if (self == null) {
		return;
	}

	self.monsterinfo.currentmove = infantry_move_stand;
}

final infantry_frames_fidget = [
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, 3, null),
	mframe_t(ai_stand, 6, null),
	mframe_t(ai_stand, 3, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, -1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, -2, null),
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, -1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, -1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, -1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, -1, null),
	mframe_t(ai_stand, -1, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, -3, null),
	mframe_t(ai_stand, -2, null),
	mframe_t(ai_stand, -3, null),
	mframe_t(ai_stand, -3, null),
	mframe_t(ai_stand, -2, null)
];

final infantry_move_fidget = mmove_t(
	_FRAME_stand01,
	_FRAME_stand49,
	infantry_frames_fidget,
	_infantry_stand
);

_infantry_fidget(edict_t self) {
	if (self == null) {
		return;
	}

	self.monsterinfo.currentmove = infantry_move_fidget;
	// gi.sound(self, CHAN_VOICE, sound_idle, 1, ATTN_IDLE, 0);
}

final infantry_frames_walk = [
	mframe_t(ai_walk, 5, null),
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 5, null),
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 5, null),
	mframe_t(ai_walk, 6, null),
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 5, null)
];

final infantry_move_walk = mmove_t(
	_FRAME_walk03,
	_FRAME_walk14,
	infantry_frames_walk,
  null
);

_infantry_walk(edict_t self) {
	if (self == null) {
		return;
	}

	self.monsterinfo.currentmove = infantry_move_walk;
}

final infantry_frames_run = [
	mframe_t(ai_run, 10, null),
	mframe_t(ai_run, 20, null),
	mframe_t(ai_run, 5, null),
	mframe_t(ai_run, 7, null),
	mframe_t(ai_run, 30, null),
	mframe_t(ai_run, 35, null),
	mframe_t(ai_run, 2, null),
	mframe_t(ai_run, 6, null)
];

final infantry_move_run = mmove_t(
	_FRAME_run01,
	_FRAME_run08,
	infantry_frames_run,
  null
);

_infantry_run(edict_t self)
{
	if ((self.monsterinfo.aiflags & AI_STAND_GROUND) != 0)
	{
		self.monsterinfo.currentmove = infantry_move_stand;
	}
	else
	{
		self.monsterinfo.currentmove = infantry_move_run;
	}
}

final infantry_frames_pain1 = [
	mframe_t(ai_move, -3, null),
	mframe_t(ai_move, -2, null),
	mframe_t(ai_move, -1, null),
	mframe_t(ai_move, -2, null),
	mframe_t(ai_move, -1, null),
	mframe_t(ai_move, 1, null),
	mframe_t(ai_move, -1, null),
	mframe_t(ai_move, 1, null),
	mframe_t(ai_move, 6, null),
	mframe_t(ai_move, 2, null)
];

final infantry_move_pain1 = mmove_t(
	_FRAME_pain101,
   	_FRAME_pain110,
   	infantry_frames_pain1,
   	_infantry_run
);

final infantry_frames_pain2 = [
	mframe_t(ai_move, -3, null),
	mframe_t(ai_move, -3, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, -1, null),
	mframe_t(ai_move, -2, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 2, null),
	mframe_t(ai_move, 5, null),
	mframe_t(ai_move, 2, null)
];

final infantry_move_pain2 = mmove_t(
	_FRAME_pain201,
	_FRAME_pain210,
	infantry_frames_pain2,
	_infantry_run
);

_infantry_pain(edict_t self, edict_t other /* unused */,
	   	double kick /* unused */, int damage) {

	if (self == null) {
		return;
	}

	if (self.health < (self.max_health / 2))
	{
		self.s.skinnum = 1;
	}

	if (level.time < self.pain_debounce_time)
	{
		return;
	}

	self.pain_debounce_time = level.time + 3;

	if (skill.integer == 3)
	{
		return; /* no pain anims in nightmare */
	}

	int n = randk() % 2;

	if (n == 0)
	{
		self.monsterinfo.currentmove = infantry_move_pain1;
		// gi.sound(self, CHAN_VOICE, sound_pain1, 1, ATTN_NORM, 0);
	}
	else
	{
		self.monsterinfo.currentmove = infantry_move_pain2;
		// gi.sound(self, CHAN_VOICE, sound_pain2, 1, ATTN_NORM, 0);
	}
}

final List<List<double>> aimangles = [
	[0.0, 5.0, 0.0],
	[10.0, 15.0, 0.0],
	[20.0, 25.0, 0.0],
	[25.0, 35.0, 0.0],
	[30.0, 40.0, 0.0],
	[30.0, 45.0, 0.0],
	[25.0, 50.0, 0.0],
	[20.0, 40.0, 0.0],
	[15.0, 35.0, 0.0],
	[40.0, 35.0, 0.0],
	[70.0, 35.0, 0.0],
	[90.0, 35.0, 0.0]
];

InfantryMachineGun(edict_t self) {
	// vec3_t start, target;
	// vec3_t forward, right;
	// vec3_t vec;
	int flash_number;
  List<double> start = [0,0,0];
  List<double> forward = [0,0,0];

	if (self == null) {
		return;
	}

	if (self.s.frame == _FRAME_attak111)
	{
		flash_number = MZ2_INFANTRY_MACHINEGUN_1;
    List<double> right = [0,0,0];
		AngleVectors(self.s.angles, forward, right, null);
		G_ProjectSource(self.s.origin, monster_flash_offset[flash_number],
				forward, right, start);

		if (self.enemy != null)
		{
      List<double> target = [0,0,0];
			VectorMA(self.enemy.s.origin, -0.2, self.enemy.velocity, target);
			target[2] += self.enemy.viewheight;
			VectorSubtract(target, start, forward);
			VectorNormalize(forward);
		}
		else
		{
			AngleVectors(self.s.angles, forward, right, null);
		}
	}
	else
	{
		flash_number = MZ2_INFANTRY_MACHINEGUN_2 +
					   (self.s.frame - _FRAME_death211);

    List<double> right = [0,0,0];
		AngleVectors(self.s.angles, forward, right, null);
		G_ProjectSource(self.s.origin, monster_flash_offset[flash_number],
				forward, right, start);

    List<double> vec = [0,0,0];
		VectorSubtract(self.s.angles, aimangles[flash_number - MZ2_INFANTRY_MACHINEGUN_2], vec);
		AngleVectors(vec, forward, null, null);
	}

	monster_fire_bullet(self, start, forward, 3, 4,
			DEFAULT_BULLET_HSPREAD, DEFAULT_BULLET_VSPREAD,
			flash_number);
}

_infantry_sight(edict_t self, edict_t other /* unused */)
{
	if (self == null) {
		return;
	}

	// gi.sound(self, CHAN_BODY, sound_sight, 1, ATTN_NORM, 0);
}

_infantry_dead(edict_t self)
{
	if (self == null) {
		return;
	}

	self.mins = [ -16, -16, -24 ];
	self.maxs = [ 16, 16, -8 ];
	self.movetype = movetype_t.MOVETYPE_TOSS;
	self.svflags |= SVF_DEADMONSTER;
	SV_LinkEdict(self);

	// M_FlyCheck(self);
}

final infantry_frames_death1 = [
	mframe_t(ai_move, -4, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, -1, null),
	mframe_t(ai_move, -4, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, -1, null),
	mframe_t(ai_move, 3, null),
	mframe_t(ai_move, 1, null),
	mframe_t(ai_move, 1, null),
	mframe_t(ai_move, -2, null),
	mframe_t(ai_move, 2, null),
	mframe_t(ai_move, 2, null),
	mframe_t(ai_move, 9, null),
	mframe_t(ai_move, 9, null),
	mframe_t(ai_move, 5, null),
	mframe_t(ai_move, -3, null),
	mframe_t(ai_move, -3, null)
];

final infantry_move_death1 = mmove_t(
	_FRAME_death101,
	_FRAME_death120,
	infantry_frames_death1,
	_infantry_dead
);

/* Off with his head */
final infantry_frames_death2 = [
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 1, null),
	mframe_t(ai_move, 5, null),
	mframe_t(ai_move, -1, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 1, null),
	mframe_t(ai_move, 1, null),
	mframe_t(ai_move, 4, null),
	mframe_t(ai_move, 3, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, -2, InfantryMachineGun),
	mframe_t(ai_move, -2, InfantryMachineGun),
	mframe_t(ai_move, -3, InfantryMachineGun),
	mframe_t(ai_move, -1, InfantryMachineGun),
	mframe_t(ai_move, -2, InfantryMachineGun),
	mframe_t(ai_move, 0, InfantryMachineGun),
	mframe_t(ai_move, 2, InfantryMachineGun),
	mframe_t(ai_move, 2, InfantryMachineGun),
	mframe_t(ai_move, 3, InfantryMachineGun),
	mframe_t(ai_move, -10, InfantryMachineGun),
	mframe_t(ai_move, -7, InfantryMachineGun),
	mframe_t(ai_move, -8, InfantryMachineGun),
	mframe_t(ai_move, -6, null),
	mframe_t(ai_move, 4, null),
	mframe_t(ai_move, 0, null)
];

final infantry_move_death2 = mmove_t(
	_FRAME_death201,
	_FRAME_death225,
   	infantry_frames_death2,
   	_infantry_dead
);

final infantry_frames_death3 = [
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, -6, null),
	mframe_t(ai_move, -11, null),
	mframe_t(ai_move, -3, null),
	mframe_t(ai_move, -11, null),
	mframe_t(ai_move, 0, null),
	mframe_t(ai_move, 0, null)
];

final infantry_move_death3 = mmove_t(
	_FRAME_death301,
   	_FRAME_death309,
   	infantry_frames_death3,
   	_infantry_dead
);

_infantry_die(edict_t self, edict_t inflictor /* unused */,
		edict_t attacker /* unused */, int damage,
		List<double> point /* unused */)
{
	int n;

	if (self == null) {
		return;
	}

	/* check for gib */
	if (self.health <= self.gib_health)
	{
		// gi.sound(self, CHAN_VOICE, gi.soundindex( "misc/udeath.wav"), 1, ATTN_NORM, 0);

		for (n = 0; n < 2; n++)
		{
			ThrowGib(self, "models/objects/gibs/bone/tris.md2",
					damage, GIB_ORGANIC);
		}

		for (n = 0; n < 4; n++)
		{
			ThrowGib(self, "models/objects/gibs/sm_meat/tris.md2",
					damage, GIB_ORGANIC);
		}

		ThrowHead(self, "models/objects/gibs/head2/tris.md2",
				damage, GIB_ORGANIC);
		self.deadflag = DEAD_DEAD;
		return;
	}

	if (self.deadflag == DEAD_DEAD)
	{
		return;
	}

	/* regular death */
	self.deadflag = DEAD_DEAD;
	self.takedamage = damage_t.DAMAGE_YES.index;
	self.s.skinnum = 1; /* switch to bloody skin */

	n = randk() % 3;

	if (n == 0)
	{
		self.monsterinfo.currentmove = infantry_move_death1;
		// gi.sound(self, CHAN_VOICE, sound_die2, 1, ATTN_NORM, 0);
	}
	else if (n == 1)
	{
		self.monsterinfo.currentmove = infantry_move_death2;
		// gi.sound(self, CHAN_VOICE, sound_die1, 1, ATTN_NORM, 0);
	}
	else
	{
		self.monsterinfo.currentmove = infantry_move_death3;
		// gi.sound(self, CHAN_VOICE, sound_die2, 1, ATTN_NORM, 0);
	}
}

_infantry_duck_down(edict_t self)
{
	if (self == null) {
		return;
	}

	if ((self.monsterinfo.aiflags & AI_DUCKED) != 0) {
		return;
	}

	self.monsterinfo.aiflags |= AI_DUCKED;
	self.maxs[2] -= 32;
	self.takedamage = damage_t.DAMAGE_YES.index;
	self.monsterinfo.pausetime = level.time + 1;
	SV_LinkEdict(self);
}

_infantry_duck_hold(edict_t self) {
	if (self == null) {
		return;
	}

	if (level.time >= self.monsterinfo.pausetime)
	{
		self.monsterinfo.aiflags &= ~AI_HOLD_FRAME;
	}
	else
	{
		self.monsterinfo.aiflags |= AI_HOLD_FRAME;
	}
}

_infantry_duck_up(edict_t self) {
	if (self == null) {
		return;
	}

	self.monsterinfo.aiflags &= ~AI_DUCKED;
	self.maxs[2] += 32;
	self.takedamage = damage_t.DAMAGE_AIM.index;
	SV_LinkEdict(self);
}

final infantry_frames_duck = [
	mframe_t(ai_move, -2, _infantry_duck_down),
	mframe_t(ai_move, -5, _infantry_duck_hold),
	mframe_t(ai_move, 3, null),
	mframe_t(ai_move, 4, _infantry_duck_up),
	mframe_t(ai_move, 0, null)
];

final infantry_move_duck = mmove_t(
	_FRAME_duck01,
	_FRAME_duck05,
	infantry_frames_duck,
	_infantry_run
);

_infantry_dodge(edict_t self, edict_t attacker, double eta /* unused */)
{
	if (self == null || attacker == null) {
		return;
	}

	if (frandk() > 0.25) {
		return;
	}

	if (self.enemy == null)
	{
		self.enemy = attacker;
		FoundTarget(self);
	}

	self.monsterinfo.currentmove = infantry_move_duck;
}

_infantry_cock_gun(edict_t self)
{
	int n;

	if (self == null) {
		return;
	}

	// gi.sound(self, CHAN_WEAPON, sound_weapon_cock, 1, ATTN_NORM, 0);
	n = (randk() & 15) + 3 + 7;
	self.monsterinfo.pausetime = level.time + n * FRAMETIME;
}

_infantry_fire(edict_t self)
{
	if (self == null) {
		return;
	}

	InfantryMachineGun(self);

	if (level.time >= self.monsterinfo.pausetime)
	{
		self.monsterinfo.aiflags &= ~AI_HOLD_FRAME;
	}
	else
	{
		self.monsterinfo.aiflags |= AI_HOLD_FRAME;
	}
}

final infantry_frames_attack1 = [
	mframe_t(ai_charge, 4, null),
	mframe_t(ai_charge, -1, null),
	mframe_t(ai_charge, -1, null),
	mframe_t(ai_charge, 0, _infantry_cock_gun),
	mframe_t(ai_charge, -1, null),
	mframe_t(ai_charge, 1, null),
	mframe_t(ai_charge, 1, null),
	mframe_t(ai_charge, 2, null),
	mframe_t(ai_charge, -2, null),
	mframe_t(ai_charge, -3, null),
	mframe_t(ai_charge, 1, _infantry_fire),
	mframe_t(ai_charge, 5, null),
	mframe_t(ai_charge, -1, null),
	mframe_t(ai_charge, -2, null),
	mframe_t(ai_charge, -3, null)
];

final infantry_move_attack1 = mmove_t(
	_FRAME_attak101,
   	_FRAME_attak115,
	infantry_frames_attack1,
  _infantry_run
);

_infantry_swing(edict_t self) {
	if (self == null) {
		return;
	}

	// gi.sound(self, CHAN_WEAPON, sound_punch_swing, 1, ATTN_NORM, 0);
}

_infantry_smack(edict_t self) {

	if (self == null) {
		return;
	}

	List<double> aim = [ MELEE_DISTANCE.toDouble(), 0, 0 ];

	if (fire_hit(self, aim, (5 + (randk() % 5)), 50)) {
	// 	gi.sound(self, CHAN_WEAPON, sound_punch_hit, 1, ATTN_NORM, 0);
	}
}

final infantry_frames_attack2 = [
	mframe_t(ai_charge, 3, null),
	mframe_t(ai_charge, 6, null),
	mframe_t(ai_charge, 0, _infantry_swing),
	mframe_t(ai_charge, 8, null),
	mframe_t(ai_charge, 5, null),
	mframe_t(ai_charge, 8, _infantry_smack),
	mframe_t(ai_charge, 6, null),
	mframe_t(ai_charge, 3, null),
];

final infantry_move_attack2 = mmove_t(
	_FRAME_attak201,
  _FRAME_attak208,
	infantry_frames_attack2,
	_infantry_run
);

_infantry_attack(edict_t self) {
	if (self == null) {
		return;
	}

	if (range(self, self.enemy) == RANGE_MELEE)
	{
		self.monsterinfo.currentmove = infantry_move_attack2;
	}
	else
	{
		self.monsterinfo.currentmove = infantry_move_attack1;
	}
}

/*
 * QUAKED monster_infantry (1 .5 0) (-16 -16 -24) (16 16 32) Ambush Trigger_Spawn Sight
 */
SP_monster_infantry(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean) {
		G_FreeEdict(self);
		return;
	}

	_sound_pain1 = SV_SoundIndex("infantry/infpain1.wav");
	_sound_pain2 = SV_SoundIndex("infantry/infpain2.wav");
	_sound_die1 = SV_SoundIndex("infantry/infdeth1.wav");
	_sound_die2 = SV_SoundIndex("infantry/infdeth2.wav");

	_sound_gunshot = SV_SoundIndex("infantry/infatck1.wav");
	_sound_weapon_cock = SV_SoundIndex("infantry/infatck3.wav");
	_sound_punch_swing = SV_SoundIndex("infantry/infatck2.wav");
	_sound_punch_hit = SV_SoundIndex("infantry/melee2.wav");

	_sound_sight = SV_SoundIndex("infantry/infsght1.wav");
	_sound_search = SV_SoundIndex("infantry/infsrch1.wav");
	_sound_idle = SV_SoundIndex("infantry/infidle1.wav");

	self.movetype = movetype_t.MOVETYPE_STEP;
	self.solid = solid_t.SOLID_BBOX;
	self.s.modelindex = SV_ModelIndex("models/monsters/infantry/tris.md2");
	self.mins = [ -16, -16, -24 ];
	self.maxs = [ 16, 16, 32 ];

	self.health = 100;
	self.gib_health = -40;
	self.mass = 200;

	self.pain = _infantry_pain;
	self.die = _infantry_die;

	self.monsterinfo.stand = _infantry_stand;
	self.monsterinfo.walk = _infantry_walk;
	self.monsterinfo.run = _infantry_run;
	// self.monsterinfo.dodge = infantry_dodge;
	self.monsterinfo.attack = _infantry_attack;
	self.monsterinfo.melee = null;
	self.monsterinfo.sight = _infantry_sight;
	self.monsterinfo.idle = _infantry_fidget;

	SV_LinkEdict(self);

	self.monsterinfo.currentmove = infantry_move_stand;
	self.monsterinfo.scale = _MODEL_SCALE;

	walkmonster_start(self);
}

const _FRAME_gun02 = 0;
const _FRAME_stand01 = 1;
const _FRAME_stand02 = 2;
const _FRAME_stand03 = 3;
const _FRAME_stand04 = 4;
const _FRAME_stand05 = 5;
const _FRAME_stand06 = 6;
const _FRAME_stand07 = 7;
const _FRAME_stand08 = 8;
const _FRAME_stand09 = 9;
const _FRAME_stand10 = 10;
const _FRAME_stand11 = 11;
const _FRAME_stand12 = 12;
const _FRAME_stand13 = 13;
const _FRAME_stand14 = 14;
const _FRAME_stand15 = 15;
const _FRAME_stand16 = 16;
const _FRAME_stand17 = 17;
const _FRAME_stand18 = 18;
const _FRAME_stand19 = 19;
const _FRAME_stand20 = 20;
const _FRAME_stand21 = 21;
const _FRAME_stand22 = 22;
const _FRAME_stand23 = 23;
const _FRAME_stand24 = 24;
const _FRAME_stand25 = 25;
const _FRAME_stand26 = 26;
const _FRAME_stand27 = 27;
const _FRAME_stand28 = 28;
const _FRAME_stand29 = 29;
const _FRAME_stand30 = 30;
const _FRAME_stand31 = 31;
const _FRAME_stand32 = 32;
const _FRAME_stand33 = 33;
const _FRAME_stand34 = 34;
const _FRAME_stand35 = 35;
const _FRAME_stand36 = 36;
const _FRAME_stand37 = 37;
const _FRAME_stand38 = 38;
const _FRAME_stand39 = 39;
const _FRAME_stand40 = 40;
const _FRAME_stand41 = 41;
const _FRAME_stand42 = 42;
const _FRAME_stand43 = 43;
const _FRAME_stand44 = 44;
const _FRAME_stand45 = 45;
const _FRAME_stand46 = 46;
const _FRAME_stand47 = 47;
const _FRAME_stand48 = 48;
const _FRAME_stand49 = 49;
const _FRAME_stand50 = 50;
const _FRAME_stand51 = 51;
const _FRAME_stand52 = 52;
const _FRAME_stand53 = 53;
const _FRAME_stand54 = 54;
const _FRAME_stand55 = 55;
const _FRAME_stand56 = 56;
const _FRAME_stand57 = 57;
const _FRAME_stand58 = 58;
const _FRAME_stand59 = 59;
const _FRAME_stand60 = 60;
const _FRAME_stand61 = 61;
const _FRAME_stand62 = 62;
const _FRAME_stand63 = 63;
const _FRAME_stand64 = 64;
const _FRAME_stand65 = 65;
const _FRAME_stand66 = 66;
const _FRAME_stand67 = 67;
const _FRAME_stand68 = 68;
const _FRAME_stand69 = 69;
const _FRAME_stand70 = 70;
const _FRAME_stand71 = 71;
const _FRAME_walk01 = 72;
const _FRAME_walk02 = 73;
const _FRAME_walk03 = 74;
const _FRAME_walk04 = 75;
const _FRAME_walk05 = 76;
const _FRAME_walk06 = 77;
const _FRAME_walk07 = 78;
const _FRAME_walk08 = 79;
const _FRAME_walk09 = 80;
const _FRAME_walk10 = 81;
const _FRAME_walk11 = 82;
const _FRAME_walk12 = 83;
const _FRAME_walk13 = 84;
const _FRAME_walk14 = 85;
const _FRAME_walk15 = 86;
const _FRAME_walk16 = 87;
const _FRAME_walk17 = 88;
const _FRAME_walk18 = 89;
const _FRAME_walk19 = 90;
const _FRAME_walk20 = 91;
const _FRAME_run01 = 92;
const _FRAME_run02 = 93;
const _FRAME_run03 = 94;
const _FRAME_run04 = 95;
const _FRAME_run05 = 96;
const _FRAME_run06 = 97;
const _FRAME_run07 = 98;
const _FRAME_run08 = 99;
const _FRAME_pain101 = 100;
const _FRAME_pain102 = 101;
const _FRAME_pain103 = 102;
const _FRAME_pain104 = 103;
const _FRAME_pain105 = 104;
const _FRAME_pain106 = 105;
const _FRAME_pain107 = 106;
const _FRAME_pain108 = 107;
const _FRAME_pain109 = 108;
const _FRAME_pain110 = 109;
const _FRAME_pain201 = 110;
const _FRAME_pain202 = 111;
const _FRAME_pain203 = 112;
const _FRAME_pain204 = 113;
const _FRAME_pain205 = 114;
const _FRAME_pain206 = 115;
const _FRAME_pain207 = 116;
const _FRAME_pain208 = 117;
const _FRAME_pain209 = 118;
const _FRAME_pain210 = 119;
const _FRAME_duck01 = 120;
const _FRAME_duck02 = 121;
const _FRAME_duck03 = 122;
const _FRAME_duck04 = 123;
const _FRAME_duck05 = 124;
const _FRAME_death101 = 125;
const _FRAME_death102 = 126;
const _FRAME_death103 = 127;
const _FRAME_death104 = 128;
const _FRAME_death105 = 129;
const _FRAME_death106 = 130;
const _FRAME_death107 = 131;
const _FRAME_death108 = 132;
const _FRAME_death109 = 133;
const _FRAME_death110 = 134;
const _FRAME_death111 = 135;
const _FRAME_death112 = 136;
const _FRAME_death113 = 137;
const _FRAME_death114 = 138;
const _FRAME_death115 = 139;
const _FRAME_death116 = 140;
const _FRAME_death117 = 141;
const _FRAME_death118 = 142;
const _FRAME_death119 = 143;
const _FRAME_death120 = 144;
const _FRAME_death201 = 145;
const _FRAME_death202 = 146;
const _FRAME_death203 = 147;
const _FRAME_death204 = 148;
const _FRAME_death205 = 149;
const _FRAME_death206 = 150;
const _FRAME_death207 = 151;
const _FRAME_death208 = 152;
const _FRAME_death209 = 153;
const _FRAME_death210 = 154;
const _FRAME_death211 = 155;
const _FRAME_death212 = 156;
const _FRAME_death213 = 157;
const _FRAME_death214 = 158;
const _FRAME_death215 = 159;
const _FRAME_death216 = 160;
const _FRAME_death217 = 161;
const _FRAME_death218 = 162;
const _FRAME_death219 = 163;
const _FRAME_death220 = 164;
const _FRAME_death221 = 165;
const _FRAME_death222 = 166;
const _FRAME_death223 = 167;
const _FRAME_death224 = 168;
const _FRAME_death225 = 169;
const _FRAME_death301 = 170;
const _FRAME_death302 = 171;
const _FRAME_death303 = 172;
const _FRAME_death304 = 173;
const _FRAME_death305 = 174;
const _FRAME_death306 = 175;
const _FRAME_death307 = 176;
const _FRAME_death308 = 177;
const _FRAME_death309 = 178;
const _FRAME_block01 = 179;
const _FRAME_block02 = 180;
const _FRAME_block03 = 181;
const _FRAME_block04 = 182;
const _FRAME_block05 = 183;
const _FRAME_attak101 = 184;
const _FRAME_attak102 = 185;
const _FRAME_attak103 = 186;
const _FRAME_attak104 = 187;
const _FRAME_attak105 = 188;
const _FRAME_attak106 = 189;
const _FRAME_attak107 = 190;
const _FRAME_attak108 = 191;
const _FRAME_attak109 = 192;
const _FRAME_attak110 = 193;
const _FRAME_attak111 = 194;
const _FRAME_attak112 = 195;
const _FRAME_attak113 = 196;
const _FRAME_attak114 = 197;
const _FRAME_attak115 = 198;
const _FRAME_attak201 = 199;
const _FRAME_attak202 = 200;
const _FRAME_attak203 = 201;
const _FRAME_attak204 = 202;
const _FRAME_attak205 = 203;
const _FRAME_attak206 = 204;
const _FRAME_attak207 = 205;
const _FRAME_attak208 = 206;

const _MODEL_SCALE = 1.000000;
