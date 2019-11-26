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
 * Trigger.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/server/sv_game.dart';
import 'package:dQuakeWeb/server/sv_init.dart';
import 'package:dQuakeWeb/server/sv_world.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'game.dart';
import 'g_utils.dart';

InitTrigger(edict_t self) {
	if (self == null) {
		return;
	}

	if (self.s.angles[0] != 0 || self.s.angles[1] != 0 || self.s.angles[2] != 0) {
		G_SetMovedir(self.s.angles, self.movedir);
	}

	self.solid = solid_t.SOLID_TRIGGER;
	self.movetype = movetype_t.MOVETYPE_NONE;
	PF_setmodel(self, self.model);
	self.svflags = SVF_NOCLIENT;
}


/*
 * The wait time has passed, so
 * set back up for another activation
 */
multi_wait(edict_t ent) {
	if (ent == null) {
		return;
	}

	ent.nextthink = 0;
}

/*
 * The trigger was just activated
 * ent->activator should be set to
 * the activator so it can be held
 * through a delay so wait for the
 * delay time before firing
 */
multi_trigger(edict_t ent) {
	if (ent == null) { 
		return;
	}

	if (ent.nextthink != 0) {
		return; /* already been triggered */
	}

	G_UseTargets(ent, ent.activator);

	if (ent.wait > 0)
	{
		ent.think = multi_wait;
		ent.nextthink = level.time + ent.wait;
	}
	else
	{
		/* we can't just remove (self) here,
		   because this is a touch function
		   called while looping through area
		   links... */
		ent.touch = null;
		ent.nextthink = level.time + FRAMETIME;
		ent.think = G_FreeEdict;
	}
}

Use_Multi(edict_t ent, edict_t other /* unused */, edict_t activator) {
	if (ent == null || activator == null) {
		return;
	}

	ent.activator = activator;
	multi_trigger(ent);
}


Touch_Multi(edict_t self, edict_t other, cplane_t plane /* unused */,
	   	csurface_t surf /* unused */) {
	if (self == null || other == null) {
		return;
	}

	if (other.client != null)
	{
		if ((self.spawnflags & 2) != 0) {
			return;
		}
	}
	else if ((other.svflags & SVF_MONSTER) != 0)
	{
		if ((self.spawnflags & 1) == 0)
		{
			return;
		}
	}
	else
	{
		return;
	}

	if (self.movedir[0] != 0 || self.movedir[1] != 0 || self.movedir[2] != 0)
	{
		List<double> forward = [0,0,0];

		AngleVectors(other.s.angles, forward, null, null);

		if (DotProduct(forward, self.movedir) < 0)
		{
			return;
		}
	}

	self.activator = other;
	multi_trigger(self);
}

/*
 * QUAKED trigger_multiple (.5 .5 .5) ? MONSTER NOT_PLAYER TRIGGERED
 * Variable sized repeatable trigger.  Must be targeted at one or more
 * entities. If "delay" is set, the trigger waits some time after
 * activating before firing.
 *
 * "wait" : Seconds between triggerings. (.2 default)
 *
 * sounds
 * 1)	secret
 * 2)	beep beep
 * 3)	large switch
 * 4)
 *
 * set "message" to text string
 */
trigger_enable(edict_t self, edict_t other /* unused */,
	   	edict_t activator /* unused */)
{
	if (self == null) {
		return;
	}


	self.solid = solid_t.SOLID_TRIGGER;
	self.use = Use_Multi;
	SV_LinkEdict(self);
}

SP_trigger_multiple(edict_t ent) {
	if (ent == null) {
		return;
	}

	if (ent.sounds == 1) {
		ent.noise_index = SV_SoundIndex("misc/secret.wav");
	} else if (ent.sounds == 2) {
		ent.noise_index = SV_SoundIndex("misc/talk.wav");
	} else if (ent.sounds == 3) {
		ent.noise_index = SV_SoundIndex("misc/trigger1.wav");
	}

	if (ent.wait == 0) {
		ent.wait = 0.2;
	}

	ent.touch = Touch_Multi;
	ent.movetype = movetype_t.MOVETYPE_NONE;
	ent.svflags |= SVF_NOCLIENT;

	if ((ent.spawnflags & 4) != 0) {
		ent.solid = solid_t.SOLID_NOT;
		ent.use = trigger_enable;
	} else {
		ent.solid = solid_t.SOLID_TRIGGER;
		ent.use = Use_Multi;
	}

	if (ent.s.angles[0] != 0 || ent.s.angles[1] != 0 || ent.s.angles[2] != 0) {
		G_SetMovedir(ent.s.angles, ent.movedir);
	}

	PF_setmodel(ent, ent.model);
	SV_LinkEdict(ent);
}

/*
 * QUAKED trigger_once (.5 .5 .5) ? x x TRIGGERED
 * Triggers once, then removes itself.
 *
 * You must set the key "target" to the name of another
 * object in the level that has a matching "targetname".
 *
 * If TRIGGERED, this trigger must be triggered before it is live.
 *
 * sounds
 *  1) secret
 *  2) beep beep
 *  3) large switch
 *
 * "message" string to be displayed when triggered
 */

SP_trigger_once(edict_t ent) {
	if (ent == null) {
		return;
	}

	/* make old maps work because I
	   messed up on flag assignments here
	   triggered was on bit 1 when it
	   should have been on bit 4 */
	if ((ent.spawnflags & 1) != 0) {
		List<double> v = [0,0,0];
		VectorMA(ent.mins, 0.5, ent.size, v);
		ent.spawnflags &= ~1;
		ent.spawnflags |= 4;
		Com_Printf("fixed TRIGGERED flag on ${ent.classname} at $v\n");
	}

	ent.wait = -1;
	SP_trigger_multiple(ent);
}


/*
 * QUAKED trigger_relay (.5 .5 .5) (-8 -8 -8) (8 8 8)
 * This fixed size trigger cannot be touched,
 * it can only be fired by other events.
 */
_trigger_relay_use(edict_t self, edict_t other /* unused */,
	   	edict_t activator)
{
	if (self == null || activator == null) {
		return;
	}

	G_UseTargets(self, activator);
}

SP_trigger_relay(edict_t self) {
	if (self == null) {
		return;
	}

	self.use = _trigger_relay_use;
}

/*
 * QUAKED trigger_always (.5 .5 .5) (-8 -8 -8) (8 8 8)
 * This trigger will always fire. It is activated by the world.
 */
SP_trigger_always(edict_t ent) {
	if (ent == null) {
		return;
	}

	/* we must have some delay to make
	   sure our use targets are present */
	if (ent.delay < 0.2) {
		ent.delay = 0.2;
	}

	G_UseTargets(ent, ent);
}