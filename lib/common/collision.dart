/*
 * Copyright (C) 1997-2001 Id Software, Inc.
 * Copyright (C) 2019      Iiro Kaihlaniemi
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
 * The collision model. Slaps "boxes" through the world and checks if
 * they collide with the world model, entities or other boxes.
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'package:dQuakeWeb/client/menu/menu.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'clientserver.dart';
import 'cvar.dart';
import 'filesystem.dart';

class cnode_t {
	cplane_t	plane;
	List<int>	children = [0,0]; /* negative numbers are leafs */
}

class cbrushside_t {
	cplane_t	plane;
	mapsurface_t	surface;
}

class cleaf_t {
	int		contents = 0;
	int		cluster = 0;
	int		area = 0;
	int   firstleafbrush = 0;
	int   numleafbrushes = 0;
}

class cbrush_t {
	int			contents = 0;
	int			numsides = 0;
	int			firstbrushside = 0;
	int			checkcount = 0;	/* to avoid repeated testings */
}

class carea_t {
	int		numareaportals = 0;
	int		firstareaportal = 0;
	int		floodnum = 0; /* if two areas have equal floodnums, they are connected */
	int		floodvalid = 0;
}

String map_name = "";
String map_entitystring = "";
List<cmodel_t> map_cmodels = List.generate(MAX_MAP_MODELS, (i) => cmodel_t());
cvar_t map_noareas;
int numclusters = 1;
int numcmodels = 0;
int	emptyleaf = 0, solidleaf = 0;
List<carea_t> map_areas = [];
List<mapsurface_t> map_surfaces = [];
List<cleaf_t>	map_leafs = [];
List<cplane_t> map_planes = [];
List<cnode_t> map_nodes = [];
List<dareaportal_t> map_areaportals = [];
List<cbrush_t> map_brushes = [];
List<cbrushside_t> map_brushsides = [];
List<int> map_leafbrushes = [];
List<bool> portalopen = List.generate(MAX_MAP_AREAPORTALS, (i) => false);
dvis_t map_vis;
Uint8List map_visibility;
int box_headnode = 0;
int floodvalid = 0;
cbrush_t box_brush;
cleaf_t box_leaf;
mapsurface_t nullsurface = mapsurface_t();
List<double> _leaf_mins, _leaf_maxs;
int _leaf_count;
List<int> _leaf_list;
int _leaf_topnode;

_FloodArea_r(carea_t area, int floodnum) {

	if (area.floodvalid == floodvalid) {
		if (area.floodnum == floodnum) {
			return;
		}

		Com_Error(ERR_DROP, "FloodArea_r: reflooded");
	}

	area.floodnum = floodnum;
	area.floodvalid = floodvalid;
	
	for (int i = 0; i < area.numareaportals; i++) {
	  var p = map_areaportals[area.firstareaportal + i];
	  if (portalopen[p.portalnum]) {
			_FloodArea_r(map_areas[p.otherarea], floodnum);
		}
	}
}

_FloodAreaConnections() {

	/* all current floods are now invalid */
	floodvalid++;
	int floodnum = 0;

	/* area 0 is not used */
	for (int i = 1; i < map_areas.length; i++) {
		var area = map_areas[i];

		if (area.floodvalid == floodvalid) {
			continue; /* already flooded into */
		}

		floodnum++;
		_FloodArea_r(area, floodnum);
	}
}

bool CM_AreasConnected(int area1, int area2) {
	if (map_noareas.boolean) {
		return true;
	}

	if ((area1 > map_areas.length) || (area2 > map_areas.length)) {
		Com_Error(ERR_DROP, "area > numareas");
	}

	if (map_areas[area1].floodnum == map_areas[area2].floodnum) {
		return true;
	}

	return false;
}


/*
 * Writes a length byte followed by a bit vector of all the areas
 * that area in the same flood as the area parameter
 *
 * This is used by the client refreshes to cull visibility
 */
int CM_WriteAreaBits(Uint8List buffer, int area) {

	int bytes = (map_areas.length + 7) >> 3;

	if (map_noareas.boolean) {
		/* for debugging, send everything */
    buffer.fillRange(0, bytes, 255);
	} else {
    buffer.fillRange(0, bytes, 0);

		int floodnum = map_areas[area].floodnum;

		for (int i = 0; i < map_areas.length; i++) {
			if ((map_areas[i].floodnum == floodnum) || area == 0) {
				buffer[i >> 3] |= 1 << (i & 7);
			}
		}
	}

	return bytes;
}


/*
 * Set up the planes and nodes so that the six floats of a bounding box
 * can just be stored out and get a proper clipping hull structure.
 */
_CM_InitBoxHull() {

  final numleafs = map_leafs.length;
	box_headnode = map_nodes.length;
	// box_planes = &map_planes[numplanes];

	box_brush = cbrush_t();
	box_brush.numsides = 6;
	box_brush.firstbrushside = map_brushsides.length;
	box_brush.contents = CONTENTS_MONSTER;
  map_brushes.add(box_brush);

	box_leaf = cleaf_t();
	box_leaf.contents = CONTENTS_MONSTER;
	box_leaf.firstleafbrush = map_leafbrushes.length;
	box_leaf.numleafbrushes = 1;
  map_leafs.add(box_leaf);

	map_leafbrushes.add(map_brushes.length - 1);
  final numplanes = map_planes.length;

	for (int i = 0; i < 6; i++) {
		int side = i & 1;

		/* planes */
		var p1 = cplane_t();
		p1.type = i >> 1;
		p1.signbits = 0;
		p1.normal[i >> 1] = 1;

		var p2 = cplane_t();
		p2.type = 3 + (i >> 1);
		p2.signbits = 0;
		p2.normal[i >> 1] = -1;

    map_planes.add(p1);
    map_planes.add(p2);

		/* brush sides */
    var s = cbrushside_t();
		s.plane = side == 1 ? p2 : p1;
		s.surface = nullsurface;
    map_brushsides.add(s);

		/* nodes */
		var c = cnode_t();
		c.plane = p1;
		c.children[side] = -1 - emptyleaf;

		if (i != 5) {
			c.children[side ^ 1] = box_headnode + i + 1;
		} else {
			c.children[side ^ 1] = -1 - numleafs;
		}
    map_nodes.add(c);
	}
}

/*
 * Fills in a list of all the leafs touched
 */

_CM_BoxLeafnums_r(int nodenum) {

	while (true) {
		if (nodenum < 0) {
			if (_leaf_count >= _leaf_list.length) {
				return;
			}

			_leaf_list[_leaf_count++] = -1 - nodenum;
			return;
		}

		var node = map_nodes[nodenum];
		var plane = node.plane;
		var s = BoxOnPlaneSide(_leaf_mins, _leaf_maxs, plane);

		if (s == 1) {
			nodenum = node.children[0];
		} else if (s == 2) {
			nodenum = node.children[1];
		} else {
			/* go down both */
			if (_leaf_topnode == -1) {
				_leaf_topnode = nodenum;
			}

			_CM_BoxLeafnums_r(node.children[0]);
			nodenum = node.children[1];
		}
	}
}

int _CM_BoxLeafnums_headnode(List<double> mins, List<double> maxs, List<int> list,
		int headnode, List<int> topnode) {
	_leaf_list = list;
	_leaf_count = 0;
	_leaf_mins = mins;
	_leaf_maxs = maxs;

	_leaf_topnode = -1;

	_CM_BoxLeafnums_r(headnode);

	if (topnode != null) {
		topnode[0] = _leaf_topnode;
	}

	return _leaf_count;
}

int CM_BoxLeafnums(List<double> mins, List<double> maxs, List<int> list, List<int> topnode) {
	return _CM_BoxLeafnums_headnode(mins, maxs, list, map_cmodels[0].headnode, topnode);
}


int _CM_PointLeafnum_r(List<double> p, int anum) {

	while (anum >= 0) {
		var node = map_nodes[anum];
		var plane = node.plane;

    double d;
		if (plane.type < 3) {
			d = p[plane.type] - plane.dist;
		} else {
			d = DotProduct(plane.normal, p) - plane.dist;
		}

		if (d < 0) {
			anum = node.children[1];
		} else {
			anum = node.children[0];
		}
	}

// 	c_pointcontents++; /* optimize counter */

	return -1 - anum;
}


int CM_PointLeafnum(List<double> p) {
	if (map_planes.isEmpty) {
		return 0; /* sound may call this without map loaded */
	}
	return _CM_PointLeafnum_r(p, 0);
}


_CMod_LoadLeafs(lump_t l, ByteData buffer) {

	if ((l.filelen % dleafSize) != 0) {
		Com_Error(ERR_DROP, "CMod_LoadLeafs: funny lump size");
	}

	final count = l.filelen ~/ dleafSize;
	if (count < 1) {
		Com_Error(ERR_DROP, "Map with no leafs");
	}

	if (count > MAX_MAP_PLANES) {
		Com_Error(ERR_DROP, "Map has too many leafs");
	}

  numclusters = 0;
  map_leafs = [];

	for (int i = 0; i < count; i++) {
    final src = dleaf_t(buffer, l.fileofs + i * dleafSize);
		var out = cleaf_t();
		out.contents = src.contents;
		out.cluster = src.cluster;
		out.area = src.area;
		out.firstleafbrush = src.firstleafbrush & 0xFFFF;
		out.numleafbrushes = src.numleafbrushes & 0xFFFF;

		if (out.cluster >= numclusters) {
			numclusters = out.cluster + 1;
		}
    map_leafs.add(out);
	}

	if (map_leafs[0].contents != CONTENTS_SOLID) {
		Com_Error(ERR_DROP, "Map leaf 0 is not CONTENTS_SOLID");
	}

	solidleaf = 0;
	emptyleaf = -1;

	for (int i = 1; i < map_leafs.length; i++) {
		if (map_leafs[i].contents == 0) {
			emptyleaf = i;
			break;
		}
	}

	if (emptyleaf == -1) {
		Com_Error(ERR_DROP, "Map does not have an empty leaf");
	}
}

_CMod_LoadPlanes(lump_t l, ByteData buffer) {

	if ((l.filelen % dplaneSize) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadPlanes: funny lump size");
	}

	final count = l.filelen ~/ dplaneSize;
	if (count < 1) {
		Com_Error(ERR_DROP, "Map with no planes");
	}

	if (count > MAX_MAP_PLANES) {
		Com_Error(ERR_DROP, "Map has too many planes");
	}

  map_planes = [];

	for (int i = 0; i < count; i++) {
    final src = dplane_t(buffer, l.fileofs + i * dplaneSize);
		var out = cplane_t();
		int bits = 0;

		for (int j = 0; j < 3; j++) {
			out.normal[j] = src.normal[j];
			if (out.normal[j] < 0) {
				bits |= 1 << j;
			}
		}

		out.dist = src.dist;
		out.type = src.type;
		out.signbits = bits;
    map_planes.add(out);
	}
}

_CMod_LoadSubmodels(lump_t l, ByteData buffer) {

	if ((l.filelen % dmodelSize) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadSubmodels: funny lump size");
	}

	final count = l.filelen ~/ dmodelSize;
	if (count < 1) {
		Com_Error(ERR_DROP, "Map with no models");
	}

	if (count > MAX_MAP_MODELS) {
		Com_Error(ERR_DROP, "Map has too many models");
	}

  numcmodels = count;

	for (int i = 0; i < count; i++) {
    final src = dmodel_t(buffer, l.fileofs + i * dmodelSize);
		var out = map_cmodels[i];

		for (int j = 0; j < 3; j++) {
			/* spread the mins / maxs by a pixel */
			out.mins[j] = src.mins[j] - 1;
			out.maxs[j] = src.maxs[j] + 1;
			out.origin[j] = src.origin[j];
		}

		out.headnode = src.headnode;
	}
}

_CMod_LoadSurfaces(lump_t l, ByteData buffer) {

	if ((l.filelen % texinfoSize) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadSurfaces: funny lump size");
	}

	final count = l.filelen ~/ texinfoSize;
	if (count < 1) {
		Com_Error(ERR_DROP, "Map with no surfaces");
	}

	if (count > MAX_MAP_TEXINFO) {
		Com_Error(ERR_DROP, "Map has too many surfaces");
	}

  map_surfaces = List(count);

	for (int i = 0; i < count; i++) {
    final src = texinfo_t(buffer, l.fileofs + i * texinfoSize);
    map_surfaces[i] = mapsurface_t();
		map_surfaces[i].c.name = src.texture;
		map_surfaces[i].rname = src.texture;
		map_surfaces[i].c.flags = src.flags;
		map_surfaces[i].c.value = src.value;
	}
}

_CMod_LoadNodes(lump_t l, ByteData buffer) {

	if ((l.filelen % dnodeSize) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadNodes: funny lump size");
	}

	final count = l.filelen ~/ dnodeSize;
	if (count < 1) {
		Com_Error(ERR_DROP, "Map with no nodes");
	}

	if (count > MAX_MAP_NODES) {
		Com_Error(ERR_DROP, "Map has too many nodes");
	}

  map_nodes = [];

	for (int i = 0; i < count; i++) {
    final src = dnode_t(buffer, l.fileofs + i * dnodeSize);
    var out = cnode_t();
		out.plane = map_planes[src.planenum];
		for (int j = 0; j < 2; j++) {
			out.children[j] = src.children[j];
		}
    map_nodes.add(out);
	}
}

_CMod_LoadAreas(lump_t l, ByteData buffer) {

	if ((l.filelen % dareaSize) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadAreas: funny lump size");
	}

	final count = l.filelen ~/ dareaSize;

	if (count > MAX_MAP_AREAS) {
		Com_Error(ERR_DROP, "Map has too many areas");
	}

  map_areas = [];

	for (int i = 0; i < count; i++) {
    final src = darea_t(buffer, l.fileofs + i * dareaSize);
    var out = carea_t();
		out.numareaportals = src.numareaportals;
		out.firstareaportal = src.firstareaportal;
		out.floodvalid = 0;
		out.floodnum = 0;
    map_areas.add(out);
	}
}

_CMod_LoadBrushes(lump_t l, ByteData buffer) {

	if ((l.filelen % dbrushSize) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadBrushes: funny lump size");
	}

	final count = l.filelen ~/ dbrushSize;

	if (count > MAX_MAP_BRUSHES) {
		Com_Error(ERR_DROP, "Map has too many brushes");
	}

  map_brushes = [];

	for (int i = 0; i < count; i++) {
    final src = dbrush_t(buffer, l.fileofs + i * dbrushSize);
    var out = cbrush_t();
		out.firstbrushside = src.firstside;
		out.numsides = src.numsides;
		out.contents = src.contents;
    map_brushes.add(out);
	}
}


_CMod_LoadBrushSides(lump_t l, ByteData buffer) {

	if ((l.filelen % dbrushsideSize) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadBrushSides: funny lump size");
	}

	final count = l.filelen ~/ dbrushsideSize;

	if (count > MAX_MAP_BRUSHSIDES) {
		Com_Error(ERR_DROP, "Map has too many brush sides");
	}

  map_brushsides = [];

	for (int i = 0; i < count; i++) {
    final src = dbrushside_t(buffer, l.fileofs + i * dbrushsideSize);
    var out = cbrushside_t();
		out.plane = map_planes[src.planenum];
		int j = src.texinfo;
		if (j >= map_surfaces.length) {
			Com_Error(ERR_DROP, "Bad brushside texinfo $j");
		}
    if (j >= 0) {
		  out.surface = map_surfaces[j];
    } else {
      out.surface = nullsurface;
    }
    map_brushsides.add(out);
	}
}
_CMod_LoadAreaPortals(lump_t l, ByteData buffer) {

	if ((l.filelen % dareaportalSize) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadAreaPortals: funny lump size");
	}

	final count = l.filelen ~/ dareaportalSize;

	if (count > MAX_MAP_AREAS) {
		Com_Error(ERR_DROP, "Map has too many areas");
	}

  map_areaportals = [];

	for (int i = 0; i < count; i++) {
    map_areaportals.add(dareaportal_t(buffer, l.fileofs + i * dareaportalSize));
	}
}


_CMod_LoadLeafBrushes(lump_t l, ByteData buffer) {

	if ((l.filelen % 2) != 0) {
		Com_Error(ERR_DROP, "Mod_LoadLeafBrushes: funny lump size");
	}

	final count = l.filelen ~/ 2;
	if (count < 1) {
		Com_Error(ERR_DROP, "Map with no leafbrushes");
	}

	if (count > MAX_MAP_LEAFBRUSHES) {
		Com_Error(ERR_DROP, "Map has too many leafbrushes");
	}

  map_leafbrushes = [];

	for (int i = 0; i < count; i++) {
    map_leafbrushes.add(buffer.getInt16(l.fileofs + 2 * i, Endian.little));
	}
}

_CMod_LoadVisibility(lump_t l, ByteBuffer buffer) {

	if (l.filelen > MAX_MAP_VISIBILITY) {
		Com_Error(ERR_DROP, "Map has too large visibility lump");
	}

  map_visibility = buffer.asUint8List(l.fileofs, l.filelen);
	map_vis = dvis_t(buffer.asByteData(), l.fileofs);
}

_CMod_LoadEntityString(lump_t l, String name, ByteBuffer buffer) {
	// if (sv_entfile->value) {
	// 	char s[MAX_QPATH];
	// 	char *buffer = NULL;
	// 	int nameLen, bufLen;

	// 	nameLen = strlen(name);
	// 	strcpy(s, name);
	// 	s[nameLen-3] = 'e';	s[nameLen-2] = 'n';	s[nameLen-1] = 't';
	// 	bufLen = FS_LoadFile(s, (void **)&buffer);

	// 	if (buffer != NULL && bufLen > 1)
	// 	{
	// 		if (bufLen + 1 > sizeof(map_entitystring))
	// 		{
	// 			Com_Printf("CMod_LoadEntityString: .ent file %s too large: %i > %lu.\n", s, bufLen, (unsigned long)sizeof(map_entitystring));
	// 			FS_FreeFile(buffer);
	// 		}
	// 		else
	// 		{
	// 			Com_Printf ("CMod_LoadEntityString: .ent file %s loaded.\n", s);
	// 			numentitychars = bufLen;
	// 			memcpy(map_entitystring, buffer, bufLen);
	// 			map_entitystring[bufLen] = 0; /* jit entity bug - null terminate the entity string! */
	// 			FS_FreeFile(buffer);
	// 			return;
	// 		}
	// 	}
	// 	else if (bufLen != -1)
	// 	{
	// 		/* If the .ent file is too small, don't load. */
	// 		Com_Printf("CMod_LoadEntityString: .ent file %s too small.\n", s);
	// 		FS_FreeFile(buffer);
	// 	}
	// }

	// numentitychars = l->filelen;

	// if (l.filelen + 1 > sizeof(map_entitystring))
	// {
	// 	Com_Error(ERR_DROP, "Map has too large entity lump");
	// }

  map_entitystring = String.fromCharCodes(buffer.asInt8List(l.fileofs, l.filelen));
}


/*
 * Loads in the map and all submodels
 */
Future<cmodel_t> CM_LoadMap(String name, bool clientload, List<int> checksum) async {

	map_noareas = Cvar_Get("map_noareas", "0", 0);

	if ((map_name == name) && (clientload || !Cvar_VariableBool("flushmap"))) {
		// *checksum = last_checksum;

		if (!clientload) {
      portalopen.fillRange(0, portalopen.length, false);
			_FloodAreaConnections();
		}

      map_cmodels[0]; /* still have the right version */
	}

	/* free old stuff */
  map_planes = [];
  map_nodes = [];
  map_leafbrushes = [];
  map_areas = [];
  map_areaportals = [];
  map_leafs = [];
  map_brushes = [];
  map_brushsides = [];
	numcmodels = 0;
  map_vis = null;
  map_visibility = null;
	map_entitystring = "";
	map_name = "";

	if (name == null || name.isEmpty) {
    map_leafs.add(cleaf_t());
		numclusters = 1;
    map_areas.add(carea_t());
		// *checksum = 0;
		return map_cmodels[0]; /* cinematic servers won't have anything at all */
	}

	final buf = await FS_LoadFile(name);
	if (buf == null) {
		Com_Error(ERR_DROP, "Couldn't load $name");
	}

	// last_checksum = LittleLong(Com_BlockChecksum(buf, length));
	// *checksum = last_checksum;

  final data = buf.asByteData();
	final header = dheader_t(data, 0);

	if (header.version != BSPVERSION) {
		Com_Error(ERR_DROP,
				"CMod_LoadBrushModel: $name has wrong version number (${header.version} should be $BSPVERSION)");
	}

	// cmod_base = (byte *)buf;

	/* load into heap */
	_CMod_LoadSurfaces(header.lumps[LUMP_TEXINFO], data);
	_CMod_LoadLeafs(header.lumps[LUMP_LEAFS], data);
	_CMod_LoadLeafBrushes(header.lumps[LUMP_LEAFBRUSHES], data);
	_CMod_LoadPlanes(header.lumps[LUMP_PLANES], data);
	_CMod_LoadBrushes(header.lumps[LUMP_BRUSHES], data);
	_CMod_LoadBrushSides(header.lumps[LUMP_BRUSHSIDES], data);
	_CMod_LoadSubmodels(header.lumps[LUMP_MODELS], data);
	_CMod_LoadNodes(header.lumps[LUMP_NODES], data);
	_CMod_LoadAreas(header.lumps[LUMP_AREAS], data);
	_CMod_LoadAreaPortals(header.lumps[LUMP_AREAPORTALS], data);
	_CMod_LoadVisibility(header.lumps[LUMP_VISIBILITY], buf);
	/* From kmquake2: adding an extra parameter for .ent support. */
	_CMod_LoadEntityString(header.lumps[LUMP_ENTITIES], name, buf);

	// FS_FreeFile(buf);

  _CM_InitBoxHull();

  portalopen.fillRange(0, portalopen.length, false);
	_FloodAreaConnections();

	map_name = name;

	return map_cmodels[0];
}

cmodel_t CM_InlineModel(String name) {
	if (name == null || name.isEmpty || (name[0] != '*')) {
		Com_Error(ERR_DROP, "CM_InlineModel: bad name");
	}

	int num = int.parse(name.substring(1));
	if ((num < 1) || (num >= numcmodels)) {
		Com_Error(ERR_DROP, "CM_InlineModel: bad number");
	}

	return map_cmodels[num];
}

int CM_NumClusters() {
	return numclusters;
}

int CM_NumInlineModels() {
	return numcmodels;
}

String CM_EntityString() {
	return map_entitystring;
}

int CM_LeafContents(int leafnum) {
	if ((leafnum < 0) || (leafnum >= map_leafs.length)) {
		Com_Error(ERR_DROP, "CM_LeafContents: bad number");
	}
	return map_leafs[leafnum].contents;
}

int CM_LeafCluster(int leafnum) {
	if ((leafnum < 0) || (leafnum >= map_leafs.length)) {
		Com_Error(ERR_DROP, "CM_LeafCluster: bad number");
	}
	return map_leafs[leafnum].cluster;
}

int CM_LeafArea(int leafnum) {
	if ((leafnum < 0) || (leafnum >= map_leafs.length)) {
		Com_Error(ERR_DROP, "CM_LeafArea: bad number");
	}
	return map_leafs[leafnum].area;
}

_CM_DecompressVis(Uint8List ind, int ini, Uint8List out) {

	int row = (numclusters + 7) >> 3;
	int outi = 0;

	if (ind == null) {
		/* no vis info, so make all visible */
    out.fillRange(0, row, 0xFF);
		return;
	}

	do
	{
		if (ind[ini] != 0) {
			out[outi++] = ind[ini++];
			continue;
		}

		var c = ind[ini+1];
		ini += 2;

		if (outi + c > row) {
			c = row - outi;
			Com_DPrintf("warning: Vis decompression overrun\n");
		}

		while (c > 0) {
			out[outi++] = 0;
			c--;
		}
	} while (outi < row);
}


Uint8List CM_ClusterPVS(int cluster) {
  Uint8List pvsrow = Uint8List((numclusters + 7) >> 3);
	if (cluster >= 0) {
		_CM_DecompressVis(map_visibility, map_vis.bitofs[cluster][DVIS_PVS], pvsrow);
	}

	return pvsrow;
}

Uint8List CM_ClusterPHS(int cluster) {
  Uint8List phsrow = Uint8List((numclusters + 7) >> 3);
	if (cluster >= 0) {
		_CM_DecompressVis(map_visibility, map_vis.bitofs[cluster][DVIS_PHS], phsrow);
	}

	return phsrow;
}
