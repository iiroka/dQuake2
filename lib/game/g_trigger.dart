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
import 'game.dart';
import 'g_utils.dart';

/*
 * QUAKED trigger_relay (.5 .5 .5) (-8 -8 -8) (8 8 8)
 * This fixed size trigger cannot be touched,
 * it can only be fired by other events.
 */
trigger_relay_use(edict_t self, edict_t other /* unused */,
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

	self.use = trigger_relay_use;
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