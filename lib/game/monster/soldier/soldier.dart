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
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_world.dart';

import '../../game.dart';
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

	// self->pain = soldier_pain;
	// self->die = soldier_die;

	// self->monsterinfo.stand = soldier_stand;
	// self->monsterinfo.walk = soldier_walk;
	// self->monsterinfo.run = soldier_run;
	// self->monsterinfo.dodge = soldier_dodge;
	// self->monsterinfo.attack = soldier_attack;
	// self->monsterinfo.melee = NULL;
	// self->monsterinfo.sight = soldier_sight;

	SV_LinkEdict(self);

	// self->monsterinfo.stand(self);

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
