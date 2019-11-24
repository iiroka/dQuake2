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
 * Soldier aka "Guard". This is the most complex enemy in Quake 2, since
 * it uses all AI features (dodging, sight, crouching, etc) and comes
 * in a myriad of variants.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_world.dart';

import '../../game.dart';
import '../../g_ai.dart';
import '../../g_monster.dart';
import '../../g_utils.dart';

int _sound_idle = 0;
int _sound_sight1 = 0;
int _sound_sight2 = 0;
int _sound_pain_light = 0;
int _sound_pain = 0;
int _sound_pain_ss = 0;
int _sound_death_light = 0;
int _sound_death = 0;
int _sound_death_ss = 0;
int _sound_cock = 0;

soldier_idle(edict_t self) {
	if (self == null) {
		return;
	}

	// if (frandk() > 0.8) {
	// 	gi.sound(self, CHAN_VOICE, sound_idle, 1, ATTN_IDLE, 0);
	// }
}

soldier_cock(edict_t self) {
	if (self != null) {
		return;
	}

	// if (self.s.frame == FRAME_stand322) {
	// 	gi.sound(self, CHAN_WEAPON, sound_cock, 1, ATTN_IDLE, 0);
	// } else {
	// 	gi.sound(self, CHAN_WEAPON, sound_cock, 1, ATTN_NORM, 0);
	// }
}

List<mframe_t> soldier_frames_stand1 = [
	mframe_t(ai_stand, 0, soldier_idle),
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
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null),
	mframe_t(ai_stand, 0, null)
];

mmove_t soldier_move_stand1 = mmove_t(
	FRAME_stand101,
  FRAME_stand130,
	soldier_frames_stand1,
	soldier_stand
);

List<mframe_t> soldier_frames_stand3 = [
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
	mframe_t(ai_stand, 0, soldier_cock),
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

final soldier_move_stand3 = mmove_t(
	FRAME_stand301,
  FRAME_stand339,
  soldier_frames_stand3,
  soldier_stand
);


soldier_stand(edict_t self) {
	if (self == null) {
		return;
	}

	if ((self.monsterinfo.currentmove == soldier_move_stand3) ||
		(frandk() < 0.8)) {
		self.monsterinfo.currentmove = soldier_move_stand1;
	} else {
		self.monsterinfo.currentmove = soldier_move_stand3;
	}
}

soldier_walk1_random(edict_t self) {
	if (self == null) {
		return;
	}

	if (frandk() > 0.1) {
		self.monsterinfo.nextframe = FRAME_walk101;
	}
}

final soldier_frames_walk1 = [
	mframe_t(ai_walk, 3, null),
	mframe_t(ai_walk, 6, null),
	mframe_t(ai_walk, 2, null),
	mframe_t(ai_walk, 2, null),
	mframe_t(ai_walk, 2, null),
	mframe_t(ai_walk, 1, null),
	mframe_t(ai_walk, 6, null),
	mframe_t(ai_walk, 5, null),
	mframe_t(ai_walk, 3, null),
	mframe_t(ai_walk, -1, soldier_walk1_random),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null),
	mframe_t(ai_walk, 0, null)
];

final soldier_move_walk1 = mmove_t(
	FRAME_walk101,
  FRAME_walk133,
  soldier_frames_walk1,
  null
);

final soldier_frames_walk2 = [
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 4, null),
	mframe_t(ai_walk, 9, null),
	mframe_t(ai_walk, 8, null),
	mframe_t(ai_walk, 5, null),
	mframe_t(ai_walk, 1, null),
	mframe_t(ai_walk, 3, null),
	mframe_t(ai_walk, 7, null),
	mframe_t(ai_walk, 6, null),
	mframe_t(ai_walk, 7, null)
];

final soldier_move_walk2 = mmove_t(
	FRAME_walk209,
   	FRAME_walk218,
	soldier_frames_walk2,
   	null
);

soldier_walk(edict_t self) {
	if (self == null) {
		return;
	}

	if (frandk() < 0.5) {
		self.monsterinfo.currentmove = soldier_move_walk1;
	} else {
		self.monsterinfo.currentmove = soldier_move_walk2;
	}
}

_SP_monster_soldier_x(edict_t self) {
	if (self == null) {
		return;
	}

	self.s.modelindex = SV_ModelIndex("models/monsters/soldier/tris.md2");
	// self.monsterinfo.scale = MODEL_SCALE;
  self.mins.setAll(0, [-16, -16, -24]);
  self.maxs.setAll(0, [16, 16, 32]);
	self.movetype = movetype_t.MOVETYPE_STEP;
	self.solid = solid_t.SOLID_BBOX;

	_sound_idle = SV_SoundIndex("soldier/solidle1.wav");
	_sound_sight1 = SV_SoundIndex("soldier/solsght1.wav");
	_sound_sight2 = SV_SoundIndex("soldier/solsrch1.wav");
	_sound_cock = SV_SoundIndex("infantry/infatck3.wav");

	self.mass = 100;

	// self.pain = soldier_pain;
	// self.die = soldier_die;

	self.monsterinfo.stand = soldier_stand;
	self.monsterinfo.walk = soldier_walk;
	// self.monsterinfo.run = soldier_run;
	// self.monsterinfo.dodge = soldier_dodge;
	// self.monsterinfo.attack = soldier_attack;
	self.monsterinfo.melee = null;
	// self.monsterinfo.sight = soldier_sight;

	SV_LinkEdict(self);

	self.monsterinfo.stand(self);

	walkmonster_start(self);
}

/*
 * QUAKED monster_soldier_light (1 .5 0) (-16 -16 -24) (16 16 32) Ambush Trigger_Spawn Sight
 */
SP_monster_soldier_light(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean) {
		G_FreeEdict(self);
		return;
	}

	_SP_monster_soldier_x(self);

	_sound_pain_light = SV_SoundIndex("soldier/solpain2.wav");
	_sound_death_light = SV_SoundIndex("soldier/soldeth2.wav");
	SV_ModelIndex("models/objects/laser/tris.md2");
	SV_SoundIndex("misc/lasfly.wav");
	SV_SoundIndex("soldier/solatck2.wav");

	self.s.skinnum = 0;
	self.health = 20;
	self.gib_health = -30;
}


/*
 * QUAKED monster_soldier (1 .5 0) (-16 -16 -24) (16 16 32) Ambush Trigger_Spawn Sight
 */
SP_monster_soldier(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean) {
		G_FreeEdict(self);
		return;
	}

	_SP_monster_soldier_x(self);

	_sound_pain = SV_SoundIndex("soldier/solpain1.wav");
	_sound_death = SV_SoundIndex("soldier/soldeth1.wav");
	SV_SoundIndex("soldier/solatck1.wav");

	self.s.skinnum = 2;
	self.health = 30;
	self.gib_health = -30;
}

/*
 * QUAKED monster_soldier_ss (1 .5 0) (-16 -16 -24) (16 16 32) Ambush Trigger_Spawn Sight
 */
SP_monster_soldier_ss(edict_t self) {
	if (self == null) {
		return;
	}

	if (deathmatch.boolean) {
		G_FreeEdict(self);
		return;
	}

	_SP_monster_soldier_x(self);

	_sound_pain_ss = SV_SoundIndex("soldier/solpain3.wav");
	_sound_death_ss = SV_SoundIndex("soldier/soldeth3.wav");
	SV_SoundIndex("soldier/solatck3.wav");

	self.s.skinnum = 4;
	self.health = 40;
	self.gib_health = -30;
}


const FRAME_attak101 = 0;
const FRAME_attak102 = 1;
const FRAME_attak103 = 2;
const FRAME_attak104 = 3;
const FRAME_attak105 = 4;
const FRAME_attak106 = 5;
const FRAME_attak107 = 6;
const FRAME_attak108 = 7;
const FRAME_attak109 = 8;
const FRAME_attak110 = 9;
const FRAME_attak111 = 10;
const FRAME_attak112 = 11;
const FRAME_attak201 = 12;
const FRAME_attak202 = 13;
const FRAME_attak203 = 14;
const FRAME_attak204 = 15;
const FRAME_attak205 = 16;
const FRAME_attak206 = 17;
const FRAME_attak207 = 18;
const FRAME_attak208 = 19;
const FRAME_attak209 = 20;
const FRAME_attak210 = 21;
const FRAME_attak211 = 22;
const FRAME_attak212 = 23;
const FRAME_attak213 = 24;
const FRAME_attak214 = 25;
const FRAME_attak215 = 26;
const FRAME_attak216 = 27;
const FRAME_attak217 = 28;
const FRAME_attak218 = 29;
const FRAME_attak301 = 30;
const FRAME_attak302 = 31;
const FRAME_attak303 = 32;
const FRAME_attak304 = 33;
const FRAME_attak305 = 34;
const FRAME_attak306 = 35;
const FRAME_attak307 = 36;
const FRAME_attak308 = 37;
const FRAME_attak309 = 38;
const FRAME_attak401 = 39;
const FRAME_attak402 = 40;
const FRAME_attak403 = 41;
const FRAME_attak404 = 42;
const FRAME_attak405 = 43;
const FRAME_attak406 = 44;
const FRAME_duck01 = 45;
const FRAME_duck02 = 46;
const FRAME_duck03 = 47;
const FRAME_duck04 = 48;
const FRAME_duck05 = 49;
const FRAME_pain101 = 50;
const FRAME_pain102 = 51;
const FRAME_pain103 = 52;
const FRAME_pain104 = 53;
const FRAME_pain105 = 54;
const FRAME_pain201 = 55;
const FRAME_pain202 = 56;
const FRAME_pain203 = 57;
const FRAME_pain204 = 58;
const FRAME_pain205 = 59;
const FRAME_pain206 = 60;
const FRAME_pain207 = 61;
const FRAME_pain301 = 62;
const FRAME_pain302 = 63;
const FRAME_pain303 = 64;
const FRAME_pain304 = 65;
const FRAME_pain305 = 66;
const FRAME_pain306 = 67;
const FRAME_pain307 = 68;
const FRAME_pain308 = 69;
const FRAME_pain309 = 70;
const FRAME_pain310 = 71;
const FRAME_pain311 = 72;
const FRAME_pain312 = 73;
const FRAME_pain313 = 74;
const FRAME_pain314 = 75;
const FRAME_pain315 = 76;
const FRAME_pain316 = 77;
const FRAME_pain317 = 78;
const FRAME_pain318 = 79;
const FRAME_pain401 = 80;
const FRAME_pain402 = 81;
const FRAME_pain403 = 82;
const FRAME_pain404 = 83;
const FRAME_pain405 = 84;
const FRAME_pain406 = 85;
const FRAME_pain407 = 86;
const FRAME_pain408 = 87;
const FRAME_pain409 = 88;
const FRAME_pain410 = 89;
const FRAME_pain411 = 90;
const FRAME_pain412 = 91;
const FRAME_pain413 = 92;
const FRAME_pain414 = 93;
const FRAME_pain415 = 94;
const FRAME_pain416 = 95;
const FRAME_pain417 = 96;
const FRAME_run01 = 97;
const FRAME_run02 = 98;
const FRAME_run03 = 99;
const FRAME_run04 = 100;
const FRAME_run05 = 101;
const FRAME_run06 = 102;
const FRAME_run07 = 103;
const FRAME_run08 = 104;
const FRAME_run09 = 105;
const FRAME_run10 = 106;
const FRAME_run11 = 107;
const FRAME_run12 = 108;
const FRAME_runs01 = 109;
const FRAME_runs02 = 110;
const FRAME_runs03 = 111;
const FRAME_runs04 = 112;
const FRAME_runs05 = 113;
const FRAME_runs06 = 114;
const FRAME_runs07 = 115;
const FRAME_runs08 = 116;
const FRAME_runs09 = 117;
const FRAME_runs10 = 118;
const FRAME_runs11 = 119;
const FRAME_runs12 = 120;
const FRAME_runs13 = 121;
const FRAME_runs14 = 122;
const FRAME_runs15 = 123;
const FRAME_runs16 = 124;
const FRAME_runs17 = 125;
const FRAME_runs18 = 126;
const FRAME_runt01 = 127;
const FRAME_runt02 = 128;
const FRAME_runt03 = 129;
const FRAME_runt04 = 130;
const FRAME_runt05 = 131;
const FRAME_runt06 = 132;
const FRAME_runt07 = 133;
const FRAME_runt08 = 134;
const FRAME_runt09 = 135;
const FRAME_runt10 = 136;
const FRAME_runt11 = 137;
const FRAME_runt12 = 138;
const FRAME_runt13 = 139;
const FRAME_runt14 = 140;
const FRAME_runt15 = 141;
const FRAME_runt16 = 142;
const FRAME_runt17 = 143;
const FRAME_runt18 = 144;
const FRAME_runt19 = 145;
const FRAME_stand101 = 146;
const FRAME_stand102 = 147;
const FRAME_stand103 = 148;
const FRAME_stand104 = 149;
const FRAME_stand105 = 150;
const FRAME_stand106 = 151;
const FRAME_stand107 = 152;
const FRAME_stand108 = 153;
const FRAME_stand109 = 154;
const FRAME_stand110 = 155;
const FRAME_stand111 = 156;
const FRAME_stand112 = 157;
const FRAME_stand113 = 158;
const FRAME_stand114 = 159;
const FRAME_stand115 = 160;
const FRAME_stand116 = 161;
const FRAME_stand117 = 162;
const FRAME_stand118 = 163;
const FRAME_stand119 = 164;
const FRAME_stand120 = 165;
const FRAME_stand121 = 166;
const FRAME_stand122 = 167;
const FRAME_stand123 = 168;
const FRAME_stand124 = 169;
const FRAME_stand125 = 170;
const FRAME_stand126 = 171;
const FRAME_stand127 = 172;
const FRAME_stand128 = 173;
const FRAME_stand129 = 174;
const FRAME_stand130 = 175;
const FRAME_stand301 = 176;
const FRAME_stand302 = 177;
const FRAME_stand303 = 178;
const FRAME_stand304 = 179;
const FRAME_stand305 = 180;
const FRAME_stand306 = 181;
const FRAME_stand307 = 182;
const FRAME_stand308 = 183;
const FRAME_stand309 = 184;
const FRAME_stand310 = 185;
const FRAME_stand311 = 186;
const FRAME_stand312 = 187;
const FRAME_stand313 = 188;
const FRAME_stand314 = 189;
const FRAME_stand315 = 190;
const FRAME_stand316 = 191;
const FRAME_stand317 = 192;
const FRAME_stand318 = 193;
const FRAME_stand319 = 194;
const FRAME_stand320 = 195;
const FRAME_stand321 = 196;
const FRAME_stand322 = 197;
const FRAME_stand323 = 198;
const FRAME_stand324 = 199;
const FRAME_stand325 = 200;
const FRAME_stand326 = 201;
const FRAME_stand327 = 202;
const FRAME_stand328 = 203;
const FRAME_stand329 = 204;
const FRAME_stand330 = 205;
const FRAME_stand331 = 206;
const FRAME_stand332 = 207;
const FRAME_stand333 = 208;
const FRAME_stand334 = 209;
const FRAME_stand335 = 210;
const FRAME_stand336 = 211;
const FRAME_stand337 = 212;
const FRAME_stand338 = 213;
const FRAME_stand339 = 214;
const FRAME_walk101 = 215;
const FRAME_walk102 = 216;
const FRAME_walk103 = 217;
const FRAME_walk104 = 218;
const FRAME_walk105 = 219;
const FRAME_walk106 = 220;
const FRAME_walk107 = 221;
const FRAME_walk108 = 222;
const FRAME_walk109 = 223;
const FRAME_walk110 = 224;
const FRAME_walk111 = 225;
const FRAME_walk112 = 226;
const FRAME_walk113 = 227;
const FRAME_walk114 = 228;
const FRAME_walk115 = 229;
const FRAME_walk116 = 230;
const FRAME_walk117 = 231;
const FRAME_walk118 = 232;
const FRAME_walk119 = 233;
const FRAME_walk120 = 234;
const FRAME_walk121 = 235;
const FRAME_walk122 = 236;
const FRAME_walk123 = 237;
const FRAME_walk124 = 238;
const FRAME_walk125 = 239;
const FRAME_walk126 = 240;
const FRAME_walk127 = 241;
const FRAME_walk128 = 242;
const FRAME_walk129 = 243;
const FRAME_walk130 = 244;
const FRAME_walk131 = 245;
const FRAME_walk132 = 246;
const FRAME_walk133 = 247;
const FRAME_walk201 = 248;
const FRAME_walk202 = 249;
const FRAME_walk203 = 250;
const FRAME_walk204 = 251;
const FRAME_walk205 = 252;
const FRAME_walk206 = 253;
const FRAME_walk207 = 254;
const FRAME_walk208 = 255;
const FRAME_walk209 = 256;
const FRAME_walk210 = 257;
const FRAME_walk211 = 258;
const FRAME_walk212 = 259;
const FRAME_walk213 = 260;
const FRAME_walk214 = 261;
const FRAME_walk215 = 262;
const FRAME_walk216 = 263;
const FRAME_walk217 = 264;
const FRAME_walk218 = 265;
const FRAME_walk219 = 266;
const FRAME_walk220 = 267;
const FRAME_walk221 = 268;
const FRAME_walk222 = 269;
const FRAME_walk223 = 270;
const FRAME_walk224 = 271;
const FRAME_death101 = 272;
const FRAME_death102 = 273;
const FRAME_death103 = 274;
const FRAME_death104 = 275;
const FRAME_death105 = 276;
const FRAME_death106 = 277;
const FRAME_death107 = 278;
const FRAME_death108 = 279;
const FRAME_death109 = 280;
const FRAME_death110 = 281;
const FRAME_death111 = 282;
const FRAME_death112 = 283;
const FRAME_death113 = 284;
const FRAME_death114 = 285;
const FRAME_death115 = 286;
const FRAME_death116 = 287;
const FRAME_death117 = 288;
const FRAME_death118 = 289;
const FRAME_death119 = 290;
const FRAME_death120 = 291;
const FRAME_death121 = 292;
const FRAME_death122 = 293;
const FRAME_death123 = 294;
const FRAME_death124 = 295;
const FRAME_death125 = 296;
const FRAME_death126 = 297;
const FRAME_death127 = 298;
const FRAME_death128 = 299;
const FRAME_death129 = 300;
const FRAME_death130 = 301;
const FRAME_death131 = 302;
const FRAME_death132 = 303;
const FRAME_death133 = 304;
const FRAME_death134 = 305;
const FRAME_death135 = 306;
const FRAME_death136 = 307;
const FRAME_death201 = 308;
const FRAME_death202 = 309;
const FRAME_death203 = 310;
const FRAME_death204 = 311;
const FRAME_death205 = 312;
const FRAME_death206 = 313;
const FRAME_death207 = 314;
const FRAME_death208 = 315;
const FRAME_death209 = 316;
const FRAME_death210 = 317;
const FRAME_death211 = 318;
const FRAME_death212 = 319;
const FRAME_death213 = 320;
const FRAME_death214 = 321;
const FRAME_death215 = 322;
const FRAME_death216 = 323;
const FRAME_death217 = 324;
const FRAME_death218 = 325;
const FRAME_death219 = 326;
const FRAME_death220 = 327;
const FRAME_death221 = 328;
const FRAME_death222 = 329;
const FRAME_death223 = 330;
const FRAME_death224 = 331;
const FRAME_death225 = 332;
const FRAME_death226 = 333;
const FRAME_death227 = 334;
const FRAME_death228 = 335;
const FRAME_death229 = 336;
const FRAME_death230 = 337;
const FRAME_death231 = 338;
const FRAME_death232 = 339;
const FRAME_death233 = 340;
const FRAME_death234 = 341;
const FRAME_death235 = 342;
const FRAME_death301 = 343;
const FRAME_death302 = 344;
const FRAME_death303 = 345;
const FRAME_death304 = 346;
const FRAME_death305 = 347;
const FRAME_death306 = 348;
const FRAME_death307 = 349;
const FRAME_death308 = 350;
const FRAME_death309 = 351;
const FRAME_death310 = 352;
const FRAME_death311 = 353;
const FRAME_death312 = 354;
const FRAME_death313 = 355;
const FRAME_death314 = 356;
const FRAME_death315 = 357;
const FRAME_death316 = 358;
const FRAME_death317 = 359;
const FRAME_death318 = 360;
const FRAME_death319 = 361;
const FRAME_death320 = 362;
const FRAME_death321 = 363;
const FRAME_death322 = 364;
const FRAME_death323 = 365;
const FRAME_death324 = 366;
const FRAME_death325 = 367;
const FRAME_death326 = 368;
const FRAME_death327 = 369;
const FRAME_death328 = 370;
const FRAME_death329 = 371;
const FRAME_death330 = 372;
const FRAME_death331 = 373;
const FRAME_death332 = 374;
const FRAME_death333 = 375;
const FRAME_death334 = 376;
const FRAME_death335 = 377;
const FRAME_death336 = 378;
const FRAME_death337 = 379;
const FRAME_death338 = 380;
const FRAME_death339 = 381;
const FRAME_death340 = 382;
const FRAME_death341 = 383;
const FRAME_death342 = 384;
const FRAME_death343 = 385;
const FRAME_death344 = 386;
const FRAME_death345 = 387;
const FRAME_death401 = 388;
const FRAME_death402 = 389;
const FRAME_death403 = 390;
const FRAME_death404 = 391;
const FRAME_death405 = 392;
const FRAME_death406 = 393;
const FRAME_death407 = 394;
const FRAME_death408 = 395;
const FRAME_death409 = 396;
const FRAME_death410 = 397;
const FRAME_death411 = 398;
const FRAME_death412 = 399;
const FRAME_death413 = 400;
const FRAME_death414 = 401;
const FRAME_death415 = 402;
const FRAME_death416 = 403;
const FRAME_death417 = 404;
const FRAME_death418 = 405;
const FRAME_death419 = 406;
const FRAME_death420 = 407;
const FRAME_death421 = 408;
const FRAME_death422 = 409;
const FRAME_death423 = 410;
const FRAME_death424 = 411;
const FRAME_death425 = 412;
const FRAME_death426 = 413;
const FRAME_death427 = 414;
const FRAME_death428 = 415;
const FRAME_death429 = 416;
const FRAME_death430 = 417;
const FRAME_death431 = 418;
const FRAME_death432 = 419;
const FRAME_death433 = 420;
const FRAME_death434 = 421;
const FRAME_death435 = 422;
const FRAME_death436 = 423;
const FRAME_death437 = 424;
const FRAME_death438 = 425;
const FRAME_death439 = 426;
const FRAME_death440 = 427;
const FRAME_death441 = 428;
const FRAME_death442 = 429;
const FRAME_death443 = 430;
const FRAME_death444 = 431;
const FRAME_death445 = 432;
const FRAME_death446 = 433;
const FRAME_death447 = 434;
const FRAME_death448 = 435;
const FRAME_death449 = 436;
const FRAME_death450 = 437;
const FRAME_death451 = 438;
const FRAME_death452 = 439;
const FRAME_death453 = 440;
const FRAME_death501 = 441;
const FRAME_death502 = 442;
const FRAME_death503 = 443;
const FRAME_death504 = 444;
const FRAME_death505 = 445;
const FRAME_death506 = 446;
const FRAME_death507 = 447;
const FRAME_death508 = 448;
const FRAME_death509 = 449;
const FRAME_death510 = 450;
const FRAME_death511 = 451;
const FRAME_death512 = 452;
const FRAME_death513 = 453;
const FRAME_death514 = 454;
const FRAME_death515 = 455;
const FRAME_death516 = 456;
const FRAME_death517 = 457;
const FRAME_death518 = 458;
const FRAME_death519 = 459;
const FRAME_death520 = 460;
const FRAME_death521 = 461;
const FRAME_death522 = 462;
const FRAME_death523 = 463;
const FRAME_death524 = 464;
const FRAME_death601 = 465;
const FRAME_death602 = 466;
const FRAME_death603 = 467;
const FRAME_death604 = 468;
const FRAME_death605 = 469;
const FRAME_death606 = 470;
const FRAME_death607 = 471;
const FRAME_death608 = 472;
const FRAME_death609 = 473;
const FRAME_death610 = 474;

const MODEL_SCALE = 1.200000;