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
 * Interface to the world model. Clipping and stuff like that...
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/collision.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'server.dart';
import 'sv_game.dart' show ge;

const _AREA_DEPTH = 4;
const _AREA_NODES = 32;
const _MAX_TOTAL_ENT_LEAFS = 128;


class areanode_t {
	int axis = 0; /* -1 = leaf node */
	double dist = 0;
	List<areanode_t> children = [null, null];
	link_t trigger_edicts = link_t();
	link_t solid_edicts = link_t();
}

List<areanode_t> sv_areanodes = [];

ClearLink(link_t l) {
	l.prev = l.next = l;
}

RemoveLink(link_t l) {
	l.next.prev = l.prev;
	l.prev.next = l.next;
}

InsertLinkBefore(link_t l, link_t before) {
	l.next = before;
	l.prev = before.prev;
	l.prev.next = l;
	l.next.prev = l;
}


/*
 * Builds a uniformly subdivided tree for the given world size
 */
areanode_t SV_CreateAreaNode(int depth, List<double> mins, List<double> maxs) {

	var anode = areanode_t();
  sv_areanodes.add(anode);

	ClearLink(anode.trigger_edicts);
	ClearLink(anode.solid_edicts);

	if (depth == _AREA_DEPTH) {
		anode.axis = -1;
		anode.children[0] = anode.children[1] = null;
		return anode;
	}

  List<double> size = [0,0,0];
	VectorSubtract(maxs, mins, size);

	if (size[0] > size[1]) {
		anode.axis = 0;
	} else {
		anode.axis = 1;
	}

	anode.dist = 0.5 * (maxs[anode.axis] + mins[anode.axis]);
  List<double> mins1 = List.generate(3, (i) => mins[i]);
  List<double> mins2 = List.generate(3, (i) => mins[i]);
  List<double> maxs1 = List.generate(3, (i) => maxs[i]);
  List<double> maxs2 = List.generate(3, (i) => maxs[i]);

	maxs1[anode.axis] = mins2[anode.axis] = anode.dist;

	anode.children[0] = SV_CreateAreaNode(depth + 1, mins2, maxs2);
	anode.children[1] = SV_CreateAreaNode(depth + 1, mins1, maxs1);

	return anode;
}

SV_ClearWorld() {
	sv_areanodes = [];
	SV_CreateAreaNode(0, sv.models[1].mins, sv.models[1].maxs);
}

SV_UnlinkEdict(edict_s ent) {
	if (ent.prev == null) {
		return; /* not linked in anywhere */
	}

	RemoveLink(ent);
	ent.prev = ent.next = null;
}


SV_LinkEdict(edict_s ent) {

	if (ent.prev != null) {
		SV_UnlinkEdict(ent); /* unlink from old position */
	}

	if (ent == ge.edicts[0]) {
		return; /* don't add the world */
	}

	if (!ent.inuse) {
		return;
	}

	/* set the size */
	VectorSubtract(ent.maxs, ent.mins, ent.size);

	/* encode the size into the entity_state for client prediction */
	if ((ent.solid == solid_t.SOLID_BBOX) && (ent.svflags & SVF_DEADMONSTER) == 0) {
		/* assume that x/y are equal and symetric */
		int i = ent.maxs[0] ~/ 8;
		if (i < 1) {
			i = 1;
		}

		if (i > 31) {
			i = 31;
		}

		/* z is not symetric */
		int j = (-ent.mins[2]) ~/ 8;
		if (j < 1) {
			j = 1;
		}

		if (j > 31) {
			j = 31;
		}

		/* and z maxs can be negative... */
		int k = (ent.maxs[2] + 32) ~/ 8;
		if (k < 1) {
			k = 1;
		}

		if (k > 63) {
			k = 63;
		}

		ent.s.solid = (k << 10) | (j << 5) | i;
	}
	else if (ent.solid == solid_t.SOLID_BSP)
	{
		ent.s.solid = 31; /* a solid_bbox will never create this value */
	}
	else
	{
		ent.s.solid = 0;
	}

	/* set the abs box */
	if ((ent.solid == solid_t.SOLID_BSP) &&
		(ent.s.angles[0] != 0 || ent.s.angles[1] != 0 ||
		 ent.s.angles[2] != 0)) {
		/* expand for rotation */
		double max = 0;

		for (int i = 0; i < 3; i++) {
			double v = ent.mins[i].abs();
			if (v > max) {
				max = v;
			}

			v = ent.maxs[i].abs();
			if (v > max) {
				max = v;
			}
		}

		for (int i = 0; i < 3; i++) {
			ent.absmin[i] = ent.s.origin[i] - max;
			ent.absmax[i] = ent.s.origin[i] + max;
		}
	} else {
		/* normal */
		VectorAdd(ent.s.origin, ent.mins, ent.absmin);
		VectorAdd(ent.s.origin, ent.maxs, ent.absmax);
	}

	/* because movement is clipped an epsilon away from an actual edge,
	   we must fully check even when bounding boxes don't quite touch */
	ent.absmin[0] -= 1;
	ent.absmin[1] -= 1;
	ent.absmin[2] -= 1;
	ent.absmax[0] += 1;
	ent.absmax[1] += 1;
	ent.absmax[2] += 1;

	/* link to PVS leafs */
	ent.num_clusters = 0;
	ent.areanum = 0;
	ent.areanum2 = 0;

	/* get all leafs, including solids */
  List<int> topnode = [0];
  List<int> leafs = List(_MAX_TOTAL_ENT_LEAFS);
	int num_leafs = CM_BoxLeafnums(ent.absmin, ent.absmax,
			leafs, topnode);

	List<int> clusters = List(_MAX_TOTAL_ENT_LEAFS);

	/* set areas */
	for (int i = 0; i < num_leafs; i++) {
		clusters[i] = CM_LeafCluster(leafs[i]);
		int area = CM_LeafArea(leafs[i]);

		if (area != 0) {
			/* doors may legally straggle two areas,
			   but nothing should evern need more than that */
			if (ent.areanum != 0 && (ent.areanum != area)) {
				if (ent.areanum2 != 0 && (ent.areanum2 != area) &&
					(sv.state == server_state_t.ss_loading)) {
					Com_DPrintf("Object touching 3 areas at ${ent.absmin[0]} ${ent.absmin[1]} ${ent.absmin[2]}\n");
				}

				ent.areanum2 = area;
			}
			else
			{
				ent.areanum = area;
			}
		}
	}

	if (num_leafs >= _MAX_TOTAL_ENT_LEAFS) {
		/* assume we missed some leafs, and mark by headnode */
		ent.num_clusters = -1;
		ent.headnode = topnode[0];
	} else {
		ent.num_clusters = 0;

		for (int i = 0; i < num_leafs; i++) {
			if (clusters[i] == -1) {
				continue; /* not a visible leaf */
			}

      int j;
			for (j = 0; j < i; j++) {
				if (clusters[j] == clusters[i]) {
					break;
				}
			}

			if (j == i) {
				if (ent.num_clusters == MAX_ENT_CLUSTERS) {
					/* assume we missed some leafs, and mark by headnode */
					ent.num_clusters = -1;
					ent.headnode = topnode[0];
					break;
				}

				ent.clusternums[ent.num_clusters++] = clusters[i];
			}
		}
	}

	/* if first time, make sure old_origin is valid */
	if (ent.linkcount == 0) {
    ent.s.old_origin.setAll(0, ent.s.origin);
	}

	ent.linkcount++;

	if (ent.solid == solid_t.SOLID_NOT) {
		return;
	}

	/* find the first node that the ent's box crosses */
	var node = sv_areanodes[0];

	while (true) {
		if (node.axis == -1) {
			break;
		}

		if (ent.absmin[node.axis] > node.dist) {
			node = node.children[0];
		} else if (ent.absmax[node.axis] < node.dist) {
			node = node.children[1];
		} else {
			break; /* crosses the node */
		}
	}

	/* link it in */
	if (ent.solid == solid_t.SOLID_TRIGGER) {
		InsertLinkBefore(ent, node.trigger_edicts);
	} else {
		InsertLinkBefore(ent, node.solid_edicts);
	}
}

List<edict_s> _area_list;
List<double> _area_mins;
List<double> _area_maxs;
int _area_type;

SV_AreaEdicts_r(areanode_t node) {

	/* touch linked edicts */
  link_t start;
	if (_area_type == AREA_SOLID) {
		start = node.solid_edicts;
	} else {
		start = node.trigger_edicts;
	}

  link_t next;
	for (var l = start.next; l != start; l = next)
	{
		next = l.next;
		var check = l as edict_s;

		if (check.solid == solid_t.SOLID_NOT)
		{
			continue; /* deactivated */
		}

		if ((check.absmin[0] > _area_maxs[0]) ||
			(check.absmin[1] > _area_maxs[1]) ||
			(check.absmin[2] > _area_maxs[2]) ||
			(check.absmax[0] < _area_mins[0]) ||
			(check.absmax[1] < _area_mins[1]) ||
			(check.absmax[2] < _area_mins[2])) {
			continue; /* not touching */
		}

		_area_list.add(check);
	}

	if (node.axis == -1) {
		return; /* terminal node */
	}

	/* recurse down both sides */
	if (_area_maxs[node.axis] > node.dist) {
		SV_AreaEdicts_r(node.children[0]);
	}

	if (_area_mins[node.axis] < node.dist) {
		SV_AreaEdicts_r(node.children[1]);
	}
}

List<edict_s> SV_AreaEdicts(List<double> mins, List<double> maxs, int areatype) {
	_area_mins = mins;
	_area_maxs = maxs;
	_area_list = [];
	_area_type = areatype;

	SV_AreaEdicts_r(sv_areanodes[0]);

	_area_mins = null;
	_area_maxs = null;
	_area_type = 0;

	return _area_list;
}

class _moveclip_t {
	List<double> boxmins = [0,0,0], boxmaxs = [0,0,0]; /* enclose the test object along entire move */
	List<double> mins, maxs; /* size of the moving object */
	List<double> mins2 = [0,0,0], maxs2 = [0,0,0]; /* size when clipping against mosnters */
	List<double> start, end;
	trace_t trace = trace_t();
	edict_s passedict;
	int contentmask = 0;
}

/*
 * Returns a headnode that can be used for testing or clipping an
 * object of mins/maxs size. Offset is filled in to contain the
 * adjustment that must be added to the testing object's origin
 * to get a point to use with the returned hull.
 */
int SV_HullForEntity(edict_s ent) {
	/* decide which clipping hull to use, based on the size */
	if (ent.solid == solid_t.SOLID_BSP) {

		/* explicit hulls in the BSP model */
		final model = sv.models[ent.s.modelindex];
		if (model == null) {
			Com_Error(ERR_FATAL, "MOVETYPE_PUSH with a non bsp model");
		}

		return model.headnode;
	}

	/* create a temp hull from bounding box sizes */
	return CM_HeadnodeForBox(ent.mins, ent.maxs);
}


SV_ClipMoveToEntities(_moveclip_t clip) {
	// int i, num;
	// edict_t *touchlist[MAX_EDICTS], *touch;
	// trace_t trace;
	// int headnode;
	// float *angles;

	final touchlist = SV_AreaEdicts(clip.boxmins, clip.boxmaxs, AREA_SOLID);

	/* be careful, it is possible to have an entity in this
	   list removed before we get to it (killtriggered) */
	for (var touch in touchlist) {

		if (touch.solid == solid_t.SOLID_NOT) {
			continue;
		}

		if (touch == clip.passedict) {
			continue;
		}

		if (clip.trace.allsolid) {
			return;
		}

		if (clip.passedict != null) {
			if (touch.owner == clip.passedict) {
				continue; /* don't clip against own missiles */
			}

			if (clip.passedict.owner == touch) {
				continue; /* don't clip against owner */
			}
		}

		if ((clip.contentmask & CONTENTS_DEADMONSTER) == 0 &&
			(touch.svflags & SVF_DEADMONSTER) != 0) {
			continue;
		}

		/* might intersect, so do an exact clip */
		final headnode = SV_HullForEntity(touch);
		var angles = touch.s.angles;

		if (touch.solid != solid_t.SOLID_BSP) {
			angles = [0,0,0]; /* boxes don't rotate */
		}

    trace_t trace;
		if ((touch.svflags & SVF_MONSTER) != 0) {
			trace = CM_TransformedBoxTrace(clip.start, clip.end,
					clip.mins2, clip.maxs2, headnode, clip.contentmask,
					touch.s.origin, angles);
		} else {
			trace = CM_TransformedBoxTrace(clip.start, clip.end,
					clip.mins, clip.maxs, headnode, clip.contentmask,
					touch.s.origin, angles);
		}

		if (trace.allsolid || trace.startsolid ||
			(trace.fraction < clip.trace.fraction)) {
			trace.ent = touch;

			if (clip.trace.startsolid) {
				clip.trace = trace;
				clip.trace.startsolid = true;
			} else {
				clip.trace = trace;
			}
		}
		else if (trace.startsolid)
		{
			clip.trace.startsolid = true;
		}
	}
}

SV_TraceBounds(List<double> start, List<double> mins, List<double> maxs,
		List<double> end, List<double> boxmins, List<double> boxmaxs) {

	for (int i = 0; i < 3; i++) {
		if (end[i] > start[i]) {
			boxmins[i] = start[i] + mins[i] - 1;
			boxmaxs[i] = end[i] + maxs[i] + 1;
		} else {
			boxmins[i] = end[i] + mins[i] - 1;
			boxmaxs[i] = start[i] + maxs[i] + 1;
		}
	}
}

/*
 * Moves the given mins/maxs volume through the world from start to end.
 * Passedict and edicts owned by passedict are explicitly not checked.
 */
trace_t SV_Trace(List<double> start, List<double> mins, List<double> maxs, List<double> end,
		edict_s passedict, int contentmask) {

	if (mins == null) {
		mins = [0,0,0];
	}

	if (maxs == null) {
		maxs = [0,0,0];
	}

	_moveclip_t clip = _moveclip_t();

	/* clip to world */
	clip.trace = CM_BoxTrace(start, end, mins, maxs, 0, contentmask);
	clip.trace.ent = ge.edicts[0];

	if (clip.trace.fraction == 0) {
		return clip.trace; /* blocked by the world */
	}

	clip.contentmask = contentmask;
	clip.start = start;
	clip.end = end;
	clip.mins = mins;
	clip.maxs = maxs;
	clip.passedict = passedict;

  clip.mins2.setAll(0, mins);
  clip.maxs2.setAll(0, maxs);

	/* create the bounding box of the entire move */
	SV_TraceBounds(start, clip.mins2, clip.maxs2, end, clip.boxmins, clip.boxmaxs);

	/* clip to other solid entities */
	SV_ClipMoveToEntities(clip);

	return clip.trace;
}
