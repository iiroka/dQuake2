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
 * Targets.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/game/g_combat.dart';
import 'package:dQuakeWeb/game/g_utils.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_send.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'game.dart';

/*
 * QUAKED target_temp_entity (1 0 0) (-8 -8 -8) (8 8 8)
 * Fire an origin based temp entity event to the clients.
 *
 *  "style"	type byte
 */
_Use_Target_Tent(edict_t ent, edict_t other /* unused */, edict_t activator /* unused */) {
	if (ent == null) {
		return;
	}

  PF_WriteByte(svc_ops_e.svc_temp_entity.index);
	PF_WriteByte(ent.style);
	PF_WritePos(ent.s.origin);
	SV_Multicast(ent.s.origin, multicast_t.MULTICAST_PVS);
}

SP_target_temp_entity(edict_t ent) {
	if (ent == null) {
		return;
	}

	ent.use = _Use_Target_Tent;
}

/* ========================================================== */

/*
 * QUAKED target_speaker (1 0 0) (-8 -8 -8) (8 8 8) looped-on looped-off reliable
 *
 * "noise" wav file to play
 *
 * "attenuation"
 *   -1 = none, send to whole level
 *    1 = normal fighting sounds
 *    2 = idle sound level
 *    3 = ambient sound level
 *
 * "volume"	0.0 to 1.0
 *
 * Normal sounds play each time the target is used.
 * The reliable flag can be set for crucial voiceovers.
 *
 * Looped sounds are always atten 3 / vol 1, and the use function toggles it on/off.
 * Multiple identical looping sounds will just increase volume without any speed cost.
 */
_Use_Target_Speaker(edict_t ent, edict_t other /* unused */, edict_t activator /* unused */) {

	if (ent == null) {
		return;
	}

	if ((ent.spawnflags & 3) != 0) {
		/* looping sound toggles */
		if (ent.s.sound != 0) {
			ent.s.sound = 0; /* turn it off */
		} else {
			ent.s.sound = ent.noise_index; /* start it */
		}
	}
	else
	{
		/* normal sound */
    // int chan;
		// if ((ent.spawnflags & 4) != 0) {
		// 	chan = CHAN_VOICE | CHAN_RELIABLE;
		// } else {
		// 	chan = CHAN_VOICE;
		// }

		// /* use a positioned_sound, because this entity won't
		//    normally be sent to any clients because it is invisible */
		// gi.positioned_sound(ent->s.origin, ent, chan, ent->noise_index,
		// 		ent->volume, ent->attenuation, 0);
	}
}

SP_target_speaker(edict_t ent) {
	// char buffer[MAX_QPATH];

	if (ent == null) {
		return;
	}

	if (st.noise == null) {
		Com_Printf("target_speaker with no noise set at ${ent.s.origin}\n");
		return;
	}

  String buffer;
  if (!st.noise.endsWith(".wav")) {
	  buffer = st.noise + ".wav";
	} else {
    buffer = st.noise;
	}

	ent.noise_index = SV_SoundIndex(buffer);

	if (ent.volume == 0) {
		ent.volume = 1.0;
	}

	if (ent.attenuation == 0) {
		ent.attenuation = 1.0;
	} else if (ent.attenuation == -1) { /* use -1 so 0 defaults to 1 */
		ent.attenuation = 0;
	}

	/* check for prestarted looping sound */
	if ((ent.spawnflags & 1) != 0) {
		ent.s.sound = ent.noise_index;
	}

	ent.use = _Use_Target_Speaker;

	/* must link the entity so we get areas and clusters so
	   the server can determine who to send updates to */
	SV_LinkEdict(ent);
}

/* ========================================================== */

/*
 * QUAKED target_secret (1 0 1) (-8 -8 -8) (8 8 8)
 * Counts a secret found. These are single use targets.
 */
_use_target_secret(edict_t ent, edict_t other /* unused */, edict_t activator /* acticator */) {
	if (ent == null) {
		return;
	}

	PF_StartSound(ent, CHAN_VOICE, ent.noise_index, 1, ATTN_NORM.toDouble(), 0);

	level.found_secrets++;

	G_UseTargets(ent, activator);
	G_FreeEdict(ent);
}

SP_target_secret(edict_t ent) {
	if (ent == null) {
		return;
	}

	if (deathmatch.boolean) {
		/* auto-remove for deathmatch */
		G_FreeEdict(ent);
		return;
	}

	ent.use = _use_target_secret;

	if (st.noise == null || st.noise.isEmpty) {
		st.noise = "misc/secret.wav";
	}

	ent.noise_index =  SV_SoundIndex(st.noise);
	ent.svflags = SVF_NOCLIENT;
	level.total_secrets++;

	/* Map quirk for mine3 */
	if ((level.mapname == "mine3") && (ent.s.origin[0] == 280) &&
		(ent.s.origin[1] == -2048) && (ent.s.origin[2] == -624)) {
		ent.message = "You have found a secret area.";
	}
}

/* ========================================================== */

/*
 * QUAKED target_splash (1 0 0) (-8 -8 -8) (8 8 8)
 * Creates a particle splash effect when used.
 *
 * Set "sounds" to one of the following:
 * 1) sparks
 * 2) blue water
 * 3) brown water
 * 4) slime
 * 5) lava
 * 6) blood
 *
 * "count"	how many pixels in the splash
 * "dmg"	if set, does a radius damage at this location when it splashes
 *          useful for lava/sparks
 */
_use_target_splash(edict_t self, edict_t other /* unused */, edict_t activator)
{
	if (self == null || activator == null) {
		return;
	}

	PF_WriteByte(svc_ops_e.svc_temp_entity.index);
	PF_WriteByte(temp_event_t.TE_SPLASH.index);
	PF_WriteByte(self.count);
	PF_WritePos(self.s.origin);
	PF_WriteDir(self.movedir);
	PF_WriteByte(self.sounds);
	SV_Multicast(self.s.origin, multicast_t.MULTICAST_PVS);

	if (self.dmg != 0)
	{
		T_RadiusDamage(self, activator, self.dmg.toDouble(), null,
				self.dmg.toDouble() + 40, MOD_SPLASH);
	}
}

SP_target_splash(edict_t self) {
	if (self == null) {
		return;
	}

	self.use = _use_target_splash;
	G_SetMovedir(self.s.angles, self.movedir);

	if (self.count == 0) {
		self.count = 32;
	}

	self.svflags = SVF_NOCLIENT;
}


/* ========================================================== */

/*
 * QUAKED target_explosion (1 0 0) (-8 -8 -8) (8 8 8)
 * Spawns an explosion temporary entity when used.
 *
 * "delay"		wait this long before going off
 * "dmg"		how much radius damage should be done, defaults to 0
 */
_target_explosion_explode(edict_t self) {

	if (self == null) {
		return;
	}

  PF_WriteByte(svc_ops_e.svc_temp_entity.index);
	PF_WriteByte(temp_event_t.TE_EXPLOSION1.index);
	PF_WritePos(self.s.origin);
	SV_Multicast(self.s.origin, multicast_t.MULTICAST_PHS);

	T_RadiusDamage(self, self.activator, self.dmg.toDouble(), null,
			(self.dmg + 40).toDouble(), MOD_EXPLOSIVE);

	final save = self.delay;
	self.delay = 0;
	G_UseTargets(self, self.activator);
	self.delay = save;
}

_use_target_explosion(edict_t self, edict_t other /* unused */, edict_t activator) {
	if (self == null) {
	    return;
	}
	self.activator = activator;
	if (activator == null) {
		return;
	}

	if (self.delay == 0) {
		_target_explosion_explode(self);
		return;
	}

	self.think = _target_explosion_explode;
	self.nextthink = level.time + self.delay;
}

SP_target_explosion(edict_t ent) {
	if (ent == null) {
		return;
	}

	ent.use = _use_target_explosion;
	ent.svflags = SVF_NOCLIENT;
}