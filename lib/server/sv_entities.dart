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

Uint8List _fatpvs = Uint8List(65536 ~/ 8);

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

	// /* delta encode the playerstate */
	// SV_WritePlayerstateToClient(oldframe, frame, msg);

	// /* delta encode the entities */
	// SV_EmitPacketEntities(oldframe, frame, msg);
}

/*
 * The client will interpolate the view position,
 * so we can't use a single PVS point
 */
_SV_FatPVS(List<double> org) {
	// int leafs[64];
	// int i, j, count;
	// int longs;
	// byte *src;
	// vec3_t mins, maxs;

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
	// int e, i;
	// vec3_t org;
	// edict_t *ent;
	// edict_t *clent;
	// client_frame_t *frame;
	// entity_state_t *state;
	// int l;
	// int clientarea, clientcluster;
	// int leafnum;
	// int c_fullsend;
	// byte *clientphs;
	// byte *bitvector;

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
	// 			l = ent->clusternums[0];

	// 			if (!(clientphs[l >> 3] & (1 << (l & 7))))
	// 			{
	// 				continue;
	// 			}
			} else {
	// 			bitvector = fatpvs;

				if (ent.num_clusters == -1) {
					/* too many leafs for individual check, go by headnode */
	// 				if (!CM_HeadnodeVisible(ent->headnode, bitvector))
	// 				{
	// 					continue;
	// 				}

	// 				c_fullsend++;
				} else {
					/* check individual leafs */
					// for (i = 0; i < ent->num_clusters; i++)
	// 				{
	// 					l = ent->clusternums[i];

	// 					if (bitvector[l >> 3] & (1 << (l & 7)))
	// 					{
	// 						break;
	// 					}
	// 				}

	// 				if (i == ent->num_clusters)
	// 				{
	// 					continue; /* not visible */
	// 				}
				}

				if (ent.s.modelindex == 0) {
					/* don't send sounds if they 
					   will be attenuated away */
	// 				vec3_t delta;
	// 				float len;

	// 				VectorSubtract(org, ent->s.origin, delta);
	// 				len = VectorLength(delta);

	// 				if (len > 400)
	// 				{
	// 					continue;
	// 				}
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
