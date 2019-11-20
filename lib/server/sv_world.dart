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
import 'package:dQuakeWeb/shared/game.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'server.dart';

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