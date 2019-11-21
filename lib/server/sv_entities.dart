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
 * Server entity handling. Just encodes the entties of a client side
 * frame into network / local communication packages and sends them to
 * the appropriate clients.
 *
 * =======================================================================
 */
import 'dart:typed_data';

import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/collision.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/shared/writebuf.dart';
import 'server.dart';
import 'sv_game.dart' show ge;
import 'sv_main.dart' show maxclients;

Uint8List _fatpvs = Uint8List(65536 ~/ 8);

/*
 * Writes a delta update of an entity_state_t list to the message.
 */
SV_EmitPacketEntities(client_frame_t from, client_frame_t to, Writebuf msg) {

	msg.WriteByte(svc_ops_e.svc_packetentities.index);

  int from_num_entities;
	if (from == null) {
		from_num_entities = 0;
	} else {
		from_num_entities = from.num_entities;
	}

	int newindex = 0;
	int oldindex = 0;
	entity_state_t newent;
	entity_state_t oldent;

	while (newindex < to.num_entities || oldindex < from_num_entities) {
		if (msg.cursize > MAX_MSGLEN - 150) {
			break;
		}

    int newnum, oldnum;
		if (newindex >= to.num_entities) {
			newnum = 9999;
		} else {
			newent = svs.client_entities[(to.first_entity + newindex) % svs.num_client_entities];
			newnum = newent.number;
		}

		if (oldindex >= from_num_entities) {
			oldnum = 9999;
		} else {
			oldent = svs.client_entities[(from.first_entity + oldindex) % svs.num_client_entities];
			oldnum = oldent.number;
		}

		if (newnum == oldnum) {
			/* delta update from old position. because the force 
			   parm is false, this will not result in any bytes
			   being emited if the entity has not changed at all
			   note that players are always 'newentities', this
			   updates their oldorigin always and prevents warping */
			msg.WriteDeltaEntity(oldent, newent, false, newent.number <= maxclients.integer);
			oldindex++;
			newindex++;
			continue;
		}

		if (newnum < oldnum) {
			/* this is a new entity, send it from the baseline */
			msg.WriteDeltaEntity(sv.baselines[newnum], newent, true, true);
			newindex++;
			continue;
		}

		if (newnum > oldnum) {
			/* the old entity isn't present in the new message */
			var bits = U_REMOVE;

			if (oldnum >= 256) {
				bits |= U_NUMBER16 | U_MOREBITS1;
			}

			msg.WriteByte(bits & 255);
			if ((bits & 0x0000ff00) != 0) {
				msg.WriteByte((bits >> 8) & 255);
			}

			if ((bits & U_NUMBER16) != 0) {
				msg.WriteShort(oldnum);
			} else {
				msg.WriteByte(oldnum);
			}

			oldindex++;
			continue;
		}
	}

	msg.WriteShort(0);
}

SV_WritePlayerstateToClient(client_frame_t from, client_frame_t to, Writebuf msg) {

	var ps = to.ps;
  player_state_t ops;

	if (from == null) {
		ops = player_state_t();
	} else {
		ops = from.ps;
	}

	/* determine what needs to be sent */
	int pflags = 0;

	if (ps.pmove.pm_type != ops.pmove.pm_type) {
		pflags |= PS_M_TYPE;
	}

	if ((ps.pmove.origin[0] != ops.pmove.origin[0]) ||
		(ps.pmove.origin[1] != ops.pmove.origin[1]) ||
		(ps.pmove.origin[2] != ops.pmove.origin[2])) {
		pflags |= PS_M_ORIGIN;
	}

	if ((ps.pmove.velocity[0] != ops.pmove.velocity[0]) ||
		(ps.pmove.velocity[1] != ops.pmove.velocity[1]) ||
		(ps.pmove.velocity[2] != ops.pmove.velocity[2])) {
		pflags |= PS_M_VELOCITY;
	}

	if (ps.pmove.pm_time != ops.pmove.pm_time) {
		pflags |= PS_M_TIME;
	}

	if (ps.pmove.pm_flags != ops.pmove.pm_flags) {
		pflags |= PS_M_FLAGS;
	}

	if (ps.pmove.gravity != ops.pmove.gravity) {
		pflags |= PS_M_GRAVITY;
	}

	if ((ps.pmove.delta_angles[0] != ops.pmove.delta_angles[0]) ||
		(ps.pmove.delta_angles[1] != ops.pmove.delta_angles[1]) ||
		(ps.pmove.delta_angles[2] != ops.pmove.delta_angles[2]))
	{
		pflags |= PS_M_DELTA_ANGLES;
	}

	if ((ps.viewoffset[0] != ops.viewoffset[0]) ||
		(ps.viewoffset[1] != ops.viewoffset[1]) ||
		(ps.viewoffset[2] != ops.viewoffset[2]))
	{
		pflags |= PS_VIEWOFFSET;
	}

	if ((ps.viewangles[0] != ops.viewangles[0]) ||
		(ps.viewangles[1] != ops.viewangles[1]) ||
		(ps.viewangles[2] != ops.viewangles[2]))
	{
		pflags |= PS_VIEWANGLES;
	}

	if ((ps.kick_angles[0] != ops.kick_angles[0]) ||
		(ps.kick_angles[1] != ops.kick_angles[1]) ||
		(ps.kick_angles[2] != ops.kick_angles[2]))
	{
		pflags |= PS_KICKANGLES;
	}

	if ((ps.blend[0] != ops.blend[0]) ||
		(ps.blend[1] != ops.blend[1]) ||
		(ps.blend[2] != ops.blend[2]) ||
		(ps.blend[3] != ops.blend[3]))
	{
		pflags |= PS_BLEND;
	}

	if (ps.fov != ops.fov)
	{
		pflags |= PS_FOV;
	}

	if (ps.rdflags != ops.rdflags)
	{
		pflags |= PS_RDFLAGS;
	}

	if (ps.gunframe != ops.gunframe)
	{
		pflags |= PS_WEAPONFRAME;
	}

	pflags |= PS_WEAPONINDEX;

	/* write it */
	msg.WriteByte(svc_ops_e.svc_playerinfo.index);
	msg.WriteShort(pflags);

	/* write the pmove_state_t */
	if ((pflags & PS_M_TYPE) != 0)
	{
		msg.WriteByte(ps.pmove.pm_type.index);
	}

	if ((pflags & PS_M_ORIGIN) != 0)
	{
		msg.WriteShort(ps.pmove.origin[0]);
		msg.WriteShort(ps.pmove.origin[1]);
		msg.WriteShort(ps.pmove.origin[2]);
	}

	if ((pflags & PS_M_VELOCITY) != 0)
	{
		msg.WriteShort(ps.pmove.velocity[0]);
		msg.WriteShort(ps.pmove.velocity[1]);
		msg.WriteShort(ps.pmove.velocity[2]);
	}

	if ((pflags & PS_M_TIME) != 0)
	{
		msg.WriteByte(ps.pmove.pm_time);
	}

	if ((pflags & PS_M_FLAGS) != 0)
	{
		msg.WriteByte(ps.pmove.pm_flags);
	}

	if ((pflags & PS_M_GRAVITY) != 0)
	{
		msg.WriteShort(ps.pmove.gravity);
	}

	if ((pflags & PS_M_DELTA_ANGLES) != 0)
	{
		msg.WriteShort(ps.pmove.delta_angles[0]);
		msg.WriteShort(ps.pmove.delta_angles[1]);
		msg.WriteShort(ps.pmove.delta_angles[2]);
	}

	/* write the rest of the player_state_t */
	if ((pflags & PS_VIEWOFFSET) != 0)
	{
		msg.WriteChar((ps.viewoffset[0] * 4).toInt());
		msg.WriteChar((ps.viewoffset[1] * 4).toInt());
		msg.WriteChar((ps.viewoffset[2] * 4).toInt());
	}

	if ((pflags & PS_VIEWANGLES) != 0)
	{
		msg.WriteAngle16(ps.viewangles[0]);
		msg.WriteAngle16(ps.viewangles[1]);
		msg.WriteAngle16(ps.viewangles[2]);
	}

	if ((pflags & PS_KICKANGLES) != 0)
	{
		msg.WriteChar((ps.kick_angles[0] * 4).toInt());
		msg.WriteChar((ps.kick_angles[1] * 4).toInt());
		msg.WriteChar((ps.kick_angles[2] * 4).toInt());
	}

	if ((pflags & PS_WEAPONINDEX) != 0)
	{
		msg.WriteByte(ps.gunindex);
	}

	if ((pflags & PS_WEAPONFRAME) != 0)
	{
		msg.WriteByte(ps.gunframe);
		msg.WriteChar((ps.gunoffset[0] * 4).toInt());
		msg.WriteChar((ps.gunoffset[1] * 4).toInt());
		msg.WriteChar((ps.gunoffset[2] * 4).toInt());
		msg.WriteChar((ps.gunangles[0] * 4).toInt());
		msg.WriteChar((ps.gunangles[1] * 4).toInt());
		msg.WriteChar((ps.gunangles[2] * 4).toInt());
	}

	if ((pflags & PS_BLEND) != 0)
	{
		msg.WriteByte((ps.blend[0] * 255).toInt());
		msg.WriteByte((ps.blend[1] * 255).toInt());
		msg.WriteByte((ps.blend[2] * 255).toInt());
		msg.WriteByte((ps.blend[3] * 255).toInt());
	}

	if ((pflags & PS_FOV) != 0) {
		msg.WriteByte(ps.fov.toInt());
	}

	if ((pflags & PS_RDFLAGS) != 0)
	{
		msg.WriteByte(ps.rdflags);
	}

	/* send stats */
	int statbits = 0;

	for (int i = 0; i < MAX_STATS; i++) {
		if (ps.stats[i] != ops.stats[i]) {
			statbits |= 1 << i;
		}
	}

	msg.WriteLong(statbits);

	for (int i = 0; i < MAX_STATS; i++) {
		if ((statbits & (1 << i)) != 0) {
			msg.WriteShort(ps.stats[i]);
		}
	}
}


SV_WriteFrameToClient(client_t client, Writebuf msg) {

	/* this is the frame we are creating */
	final frame = client.frames[sv.framenum & UPDATE_MASK];
  client_frame_t oldframe;

  int lastframe;
	if (client.lastframe <= 0) {
		/* client is asking for a retransmit */
		oldframe = null;
		lastframe = -1;
	} else if (sv.framenum - client.lastframe >= (UPDATE_BACKUP - 3)) {
		/* client hasn't gotten a good message through in a long time */
		oldframe = null;
		lastframe = -1;
	} else {
		/* we have a valid message to delta from */
		oldframe = client.frames[client.lastframe & UPDATE_MASK];
		lastframe = client.lastframe;
	}

	msg.WriteByte(svc_ops_e.svc_frame.index);
	msg.WriteLong(sv.framenum);
	msg.WriteLong(lastframe); /* what we are delta'ing from */
	msg.WriteByte(client.surpressCount); /* rate dropped packets */
	client.surpressCount = 0;

	/* send over the areabits */
	msg.WriteByte(frame.areabytes);
  msg.Write(frame.areabits.sublist(0, frame.areabytes));

	/* delta encode the playerstate */
	SV_WritePlayerstateToClient(oldframe, frame, msg);

	/* delta encode the entities */
	SV_EmitPacketEntities(oldframe, frame, msg);
}

/*
 * The client will interpolate the view position,
 * so we can't use a single PVS point
 */
_SV_FatPVS(List<double> org) {

  List<double> mins = List.generate(3, (i) => org[i] - 8);
  List<double> maxs = List.generate(3, (i) => org[i] + 8);

  List<int> leafs = List.generate(64, (i) => 0);
	final count = CM_BoxLeafnums(mins, maxs, leafs, null);
	if (count < 1) {
		Com_Error(ERR_FATAL, "SV_FatPVS: count < 1");
	}

	/* convert leafs to clusters */
	for (int i = 0; i < count; i++) {
		leafs[i] = CM_LeafCluster(leafs[i]);
	}

  _fatpvs.setAll(0, CM_ClusterPVS(leafs[0]));

	/* or in all the other leaf bits */
	for (int i = 1; i < count; i++) {
    int j;
		for (j = 0; j < i; j++) {
			if (leafs[i] == leafs[j]) {
				break;
			}
		}

		if (j != i) {
			continue; /* already have the cluster we want */
		}

		final src = CM_ClusterPVS(leafs[i]);
		for (j = 0; j < src.length; j++) {
			_fatpvs[j] |= src[j];
		}
	}
}


/*
 * Decides which entities are going to be visible to the client, and
 * copies off the playerstat and areabits.
 */
SV_BuildClientFrame(client_t client) {

	var clent = client.edict;

	if (clent.client == null) {
		return; /* not in game yet */
	}

	/* this is the frame we are creating */
	var frame = client.frames[sv.framenum & UPDATE_MASK];

	frame.senttime = svs.realtime; /* save it for ping calc later */

	/* find the client's PVS */
	List<double> org = List.generate(3, (i) => clent.client.ps.pmove.origin[i] * 0.125 +
				 clent.client.ps.viewoffset[i]);

	int leafnum = CM_PointLeafnum(org);
	int clientarea = CM_LeafArea(leafnum);
	int clientcluster = CM_LeafCluster(leafnum);

	/* calculate the visible areas */
	frame.areabytes = CM_WriteAreaBits(frame.areabits, clientarea);

	/* grab the current player_state_t */
	frame.ps.copy(clent.client.ps);

	_SV_FatPVS(org);
	Uint8List clientphs = CM_ClusterPHS(clientcluster);

	/* build up the list of visible entities */
	frame.num_entities = 0;
	frame.first_entity = svs.next_client_entities;

	// c_fullsend = 0;

	for (int e = 1; e < ge.num_edicts; e++) {
		var ent = ge.edicts[e];

		/* ignore ents without visible models */
		if ((ent.svflags & SVF_NOCLIENT) != 0) {
			continue;
		}

		/* ignore ents without visible models unless they have an effect */
		if (ent.s.modelindex == 0 && ent.s.effects == 0 && 
			ent.s.sound == 0 && ent.s.event == 0) {
			continue;
		}

		/* ignore if not touching a PV leaf */
		if (ent != clent) {
			/* check area */
			if (!CM_AreasConnected(clientarea, ent.areanum)) {
				/* doors can legally straddle two areas,
				   so we may need to check another one */
				if (ent.areanum2 == 0 ||
					!CM_AreasConnected(clientarea, ent.areanum2))
				{
					continue; /* blocked by a door */
				}
			}

			/* beams just check one point for PHS */
			if ((ent.s.renderfx & RF_BEAM) != 0) {
				int l = ent.clusternums[0];

				if ((clientphs[l >> 3] & (1 << (l & 7))) == 0) {
					continue;
				}
			} else {
				var bitvector = _fatpvs;

				if (ent.num_clusters == -1) {
					/* too many leafs for individual check, go by headnode */
					if (!CM_HeadnodeVisible(ent.headnode, bitvector)) {
						continue;
					}

	// 				c_fullsend++;
				} else {
					/* check individual leafs */
          int i;
					for (i = 0; i < ent.num_clusters; i++) {
						int l = ent.clusternums[i];

						if ((bitvector[l >> 3] & (1 << (l & 7))) != 0) {
							break;
						}
					}

					if (i == ent.num_clusters) {
						continue; /* not visible */
					}
				}

				if (ent.s.modelindex == 0) {
					/* don't send sounds if they 
					   will be attenuated away */
          List<double> delta = [0,0,0];
					VectorSubtract(org, ent.s.origin, delta);
					double len = VectorLength(delta);
					if (len > 400) {
						continue;
					}
				}
      }
    }

		/* add it to the circular client_entities array */
		var state = svs.client_entities[svs.next_client_entities % svs.num_client_entities];

		if (ent.s.number != e) {
			Com_DPrintf("FIXING ENT->S.NUMBER!!!\n");
			ent.s.number = e;
		}

	  state.copy(ent.s);

		/* don't mark players missiles as solid */
		if (ent.owner == client.edict) {
			state.solid = 0;
		}

		svs.next_client_entities++;
		frame.num_entities++;
	}
}
