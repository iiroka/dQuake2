/*
 * Copyright (C) 1997-2001 Id Software, Inc.
 * Copyright (C) 2016-2017 Daniel Gibson
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
 * Model loading and caching for WebGL. Includes the .bsp file format
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/filesystem.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'local.dart';
import 'webgl_image.dart';
import 'webgl_lightmap.dart';
import 'webgl_warp.dart';
import 'webgl_misc.dart' show webgl_notexture;

enum modtype_t {
	mod_bad,
	mod_brush,
	mod_sprite,
	mod_alias
}

const MAX_LBM_HEIGHT = 480;

const SIDE_FRONT = 0;
const SIDE_BACK = 1;
const SIDE_ON = 2;

const SURF_PLANEBACK = 2;
const SURF_DRAWSKY = 4;
const SURF_DRAWTURB = 0x10;
const SURF_DRAWBACKGROUND = 0x40;
const SURF_UNDERWATER = 0x80;

// used for vertex array elements when drawing brushes, sprites, sky and more
// (ok, it has the layout used for rendering brushes, but is not used there)
class gl3_3D_vtx_t {
	set pos (Float32List val)  {
    assert(val.length >= 3);
    this.data.setAll(0, val.sublist(0, 3));
  }
	set texCoord (Float32List val)  {
    assert(val.length >= 2);
    this.data.setAll(gl3_3D_vtx_texCoord_offset, val.sublist(0, 2));
  }
   // lightmap texture coordinate (sometimes unused)
	set lmTexCoord (Float32List val)  {
    assert(val.length >= 2);
    this.data.setAll(gl3_3D_vtx_lmTexCoord_offset, val.sublist(0, 2));
  }
	set normal (Float32List val)  {
    assert(val.length >= 3);
    this.data.setAll(7, val.sublist(0, 3));
  }
	set lightFlags (int val)  {
    this.data.buffer.asByteData().setUint32(gl3_3D_vtx_lightFlags_offset * 4, val);
  }

  Float32List data = Float32List(11);
}
const gl3_3D_vtx_size = 11;
const gl3_3D_vtx_texCoord_offset = 3;
const gl3_3D_vtx_lmTexCoord_offset = 5;
const gl3_3D_vtx_lightFlags_offset = 10;

// used for vertex array elements when drawing models
class gl3_alias_vtx_t {
	set pos (Float32List val)  {
    assert(val.length >= 3);
    this.data.setAll(0, val.sublist(0, 3));
  }
	set texCoord (Float32List val)  {
    assert(val.length >= 2);
    this.data.setAll(3, val.sublist(0, 2));
  }
	set color (Float32List val)  {
    assert(val.length >= 4);
    this.data.setAll(5, val.sublist(0, 4));
  }

  Float32List data = Float32List(9);
}

class glpoly_t {
	glpoly_t next;
	glpoly_t chain;
	int numverts = 0;
	int flags = 0; /* for SURF_UNDERWATER (not needed anymore?) */
  Float32List data;  /* variable sized */
}


/* Whole model */

// this, must be struct model_s, not gl3model_s,
// because struct model_s* is returned by re.RegisterModel()
class webglmodel_t {
	String name;

	int registration_sequence = 0;

	modtype_t type;
	int numframes = 0;

	int flags = 0;

	/* volume occupied by the model graphics */
	List<double> mins = [0,0,0], maxs = [0,0,0];
	double radius = 0;

	/* solid volume for clipping */
	bool clipbox = false;
	List<double> clipmins = [0,0,0], clipmaxs = [0,0,0];

  List<webglimage_t> skins;

  webglmodel_t(this.name, this.type);
}

/* in memory representation */
class mvertex_t {
	List<double> position;
}

class mmodel_t {
	List<double> mins, maxs;
	List<double> origin; /* for sounds or lights */
	double radius;
	int headnode;
	int visleafs; /* not including the solid leaf 0 */
	int firstface, numfaces;
}

class medge_t {
	List<int> v;
	int cachededgeoffset;
}

class mtexinfo_t {
	List<List<double>> vecs;
	int flags;
	int numframes;
	mtexinfo_t next; /* animation chain */
	webglimage_t image;
}

class msurface_t {
	int visframe = 0; /* should be drawn when node is crossed */

	cplane_t plane;
	int flags = 0;

	int firstedge = 0;          /* look up in model->surfedges[], negative numbers */
	int numedges = 0;           /* are backwards edges */

	List<int> texturemins = [0,0]; // short
	List<int> extents = [0,0]; // short

	int light_s = 0, light_t = 0;           /* gl lightmap coordinates */
	int dlight_s = 0, dlight_t = 0;         /* gl lightmap coordinates for dynamic lightmaps */

	glpoly_t polys;                /* multiple if warped */
	msurface_t texturechain = null;
	// struct  msurface_s *lightmapchain; not used/needed anymore

	mtexinfo_t texinfo;

	/* lighting info */
	int dlightframe = 0;
	int dlightbits = 0;

	int lightmaptexturenum;
	Uint8List styles; // MAXLIGHTMAPS = MAX_LIGHTMAPS_PER_SURFACE (defined in local.h)
	// I think cached_light is not used/needed anymore
	//float cached_light[MAXLIGHTMAPS];       /* values currently used in lightmap */
	Uint8List samples;                          /* [numstyles*surfsize] */
}

class mleadornode_t {
	int contents;               /* wil be a negative contents number */
	int visframe;               /* node needs to be traversed if current */

	List<double> minmaxs = List(6);           /* for bounding box culling */

	mnode_t parent;
}

class mnode_t extends mleadornode_t {
	cplane_t plane;
	List<mleadornode_t> children = [null, null];

	int firstsurface;
	int numsurfaces;
}

class mleaf_t extends mleadornode_t {
	/* leaf specific */
	int cluster = 0;
	int area = 0;

	// List<msurface_t> firstmarksurface;
  int firstmarksurface = 0;
	int nummarksurfaces = 0;
}


class webglbrushmodel_t extends webglmodel_t {

	int firstmodelsurface = 0, nummodelsurfaces = 0;
	int lightmap = 0; /* only for submodels */

  List<mmodel_t> submodels;
  List<mvertex_t> vertexes;
  List<medge_t> edges;
  List<int> surfedges;
  List<cplane_t> planes;
  Uint8List lightdata;
  List<mtexinfo_t> texinfo;
  List<msurface_t> surfaces;
  List<int> marksurfaces;
  dvis_t vis;
  Uint8List visData;
	int numleafs = 0; /* number of visible leafs, not counting 0 */
	List<mleaf_t> leafs;
	int firstnode = 0;
	List<mnode_t> nodes;

  webglbrushmodel_t(String name) : super(name, modtype_t.mod_brush);

  copy(webglbrushmodel_t other) {
    	this.name = other.name;
	    this.registration_sequence = other.registration_sequence;
	    this.type = other.type;
	    this.numframes = other.numframes;
	    this.flags = other.flags;
	    this.mins.setAll(0, other.mins);
      this.maxs.setAll(0, other.maxs);
      this.radius = other.radius;
      this.clipbox = other.clipbox;
      this.clipmins.setAll(0, other.clipmins);
      this.clipmaxs.setAll(0, other.clipmaxs);
      this.skins = other.skins;

      this.firstmodelsurface = other.firstmodelsurface;
      this.nummodelsurfaces = other.nummodelsurfaces;
      this.lightmap = other.lightmap;
      this.submodels = other.submodels;
      this.vertexes = other.vertexes;
      this.edges = other.edges;
      this.surfedges = other.surfedges;
      this.planes = other.planes;
      this.lightdata = other.lightdata;
      this.texinfo = other.texinfo;
      this.surfaces = other.surfaces;
      this.marksurfaces = other.marksurfaces;
      this.vis = other.vis;
      this.visData = other.visData;
      this.numleafs = other.numleafs;
      this.leafs = other.leafs;
      this.firstnode = other.firstnode;
      this.nodes = other.nodes;
  }

  LoadVertexes(lump_t l, ByteData buffer) {

    if ((l.filelen % dvertexSize) != 0) {
      Com_Error(ERR_DROP, "LoadVertexes: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ dvertexSize;

    this.vertexes = List(count);

    for (int i = 0; i < count; i++) {
      final src = dvertex_t(buffer, l.fileofs + i * dvertexSize);
      this.vertexes[i] = mvertex_t();
      this.vertexes[i].position = src.point;
    }
  }

  LoadEdges(lump_t l, ByteData buffer) {

    if ((l.filelen % dedgeSize) != 0) {
      Com_Error(ERR_DROP, "LoadEdges: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ dedgeSize;

    this.edges = List(count);

    for (int i = 0; i < count; i++) {
      final src = dedge_t(buffer, l.fileofs + i * dedgeSize);
      this.edges[i] = medge_t();
      this.edges[i].v = src.v;
    }
  }

  LoadSubmodels(lump_t l, ByteData buffer) {

    if ((l.filelen % dmodelSize) != 0) {
      Com_Error(ERR_DROP, "LoadSubmodels: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ dmodelSize;

    this.submodels = List(count);

    for (int i = 0; i < count; i++) {
      final src = dmodel_t(buffer, l.fileofs + i * dmodelSize);
      var out = mmodel_t();
      /* spread the mins / maxs by a pixel */
      out.mins = List.generate(3, (j) => src.mins[j] - 1);
      out.maxs = List.generate(3, (j) => src.mins[j] + 1);
      out.origin = List.generate(3, (j) => src.mins[j]);
      out.radius = Mod_RadiusFromBounds(out.mins, out.maxs);
      out.headnode = src.headnode;
      out.firstface = src.firstface;
      out.numfaces = src.numfaces;
      this.submodels[i] = out;
    }
  }

  LoadSurfedges(lump_t l, ByteData buffer) {

    if ((l.filelen % 4) != 0) {
      Com_Error(ERR_DROP, "LoadSurfedges: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ 4;

  	if ((count < 1) || (count >= MAX_MAP_SURFEDGES)) {
	  	Com_Error(ERR_DROP, "LoadSurfedges: bad surfedges count in ${this.name}: $count");
	  }

    this.surfedges = List(count);

    for (int i = 0; i < count; i++) {
      this.surfedges[i] = buffer.getInt32(l.fileofs + i * 4, Endian.little);
    }
  }


  LoadMarksurfaces(lump_t l, ByteData buffer) {

    if ((l.filelen % 2) != 0) {
      Com_Error(ERR_DROP, "LoadMarksurfaces: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ 2;

    this.marksurfaces = List(count);

    for (int i = 0; i < count; i++) {
		  int j = buffer.getInt16(l.fileofs + i * 2, Endian.little);
		  if ((j < 0) || (j >= this.surfaces.length)) {
			  Com_Error(ERR_DROP, "LoadMarksurfaces: bad surface number");
		  }

      this.marksurfaces[i] = j;
		  // this.marksurfaces[i] = this.surfaces[j];
    }
  }


  LoadLighting(lump_t l, ByteData buffer) {
    if (l.filelen == 0) {
      this.lightdata = null;
      return;
    }

    this.lightdata = Uint8List(l.filelen);
    this.lightdata.setAll(0, buffer.buffer.asUint8List(l.fileofs, l.filelen));
  }

  LoadPlanes(lump_t l, ByteData buffer) {

    if ((l.filelen % dplaneSize) != 0) {
      Com_Error(ERR_DROP, "LoadPlanes: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ dplaneSize;

    this.planes = List(count);

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
      this.planes[i] = out;
    }
  }


  LoadVisibility(lump_t l, ByteData buffer) {

    if (l.filelen == 0) {
      this.vis = null;
      this.visData = null;
      return;
    }

    this.vis = dvis_t(buffer, l.fileofs);
    this.visData = buffer.buffer.asUint8List(l.fileofs, l.filelen);
  }

  LoadTexinfo(lump_t l, ByteData buffer) async {

    if ((l.filelen % texinfoSize) != 0) {
      Com_Error(ERR_DROP, "LoadSubmodels: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ texinfoSize;

    this.texinfo = List.generate(count, (i) => mtexinfo_t());

    for (int i = 0; i < count; i++) {
      final src = texinfo_t(buffer, l.fileofs + i * texinfoSize);
      this.texinfo[i].vecs = src.vecs;
      this.texinfo[i].flags = src.flags;
      final next = src.nexttexinfo;

      if (next > 0) {
        this.texinfo[i].next = this.texinfo[next];
      } else {
        this.texinfo[i].next = null;
      }

      final name =  "textures/${src.texture}.wal";
      this.texinfo[i].image = await WebGL_FindImage(name, imagetype_t.it_wall);
      if (this.texinfo[i].image == null) {
        Com_Printf("Couldn't load $name\n");
        this.texinfo[i].image = webgl_notexture;
      }
    }

    /* count animation frames */
    for (int i = 0; i < count; i++) {
      final out = this.texinfo[i];
      out.numframes = 1;

      for (mtexinfo_t step = out.next; step != null && step != out; step = step.next) {
        out.numframes++;
      }
    }
  }

  /*
  * Fills in s->texturemins[] and s->extents[]
  */
  CalcSurfaceExtents(msurface_t s) {

    List<double> mins = [999999, 999999];
    List<double> maxs = [-99999, -99999];

    final tex = s.texinfo;

    for (int i = 0; i < s.numedges; i++) {
      final e = this.surfedges[s.firstedge + i];

      mvertex_t v;
      if (e >= 0)
      {
        v = this.vertexes[this.edges[e].v[0]];
      }
      else
      {
        v = this.vertexes[this.edges[-e].v[1]];
      }

      for (int j = 0; j < 2; j++) {
        double val = v.position[0] * tex.vecs[j][0] +
            v.position[1] * tex.vecs[j][1] +
            v.position[2] * tex.vecs[j][2] +
            tex.vecs[j][3];

        if (val < mins[j]) {
          mins[j] = val;
        }

        if (val > maxs[j]) {
          maxs[j] = val;
        }
      }
    }

    List<int> bmins = [0,0];
    List<int> bmaxs = [0,0];
    for (int i = 0; i < 2; i++) {
      bmins[i] = (mins[i] / 16).floor();
      bmaxs[i] = (maxs[i] / 16).ceil();

      s.texturemins[i] = bmins[i] * 16;
      s.extents[i] = (bmaxs[i] - bmins[i]) * 16;
    }
  }

  LoadFaces(lump_t l, ByteData buffer) async {

    final gl_fixsurfsky = Cvar_Get("gl_fixsurfsky", "0", CVAR_ARCHIVE);

    if ((l.filelen % dfaceSize) != 0) {
      Com_Error(ERR_DROP, "LoadFaces: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ dfaceSize;

    this.surfaces = List(count);

    currentmodel = this;

    WebGL_LM_BeginBuildingLightmaps(this);

    for (int surfnum = 0; surfnum < count; surfnum++) {
      final src = dface_t(buffer, l.fileofs + surfnum * dfaceSize);
      final out = msurface_t();
      out.firstedge = src.firstedge;
      out.numedges = src.numedges;
      out.flags = 0;
      out.polys = null;

      final planenum = src.planenum;
      final side = src.side;

      if (side != 0) {
        out.flags |= SURF_PLANEBACK;
      }

      out.plane = this.planes[planenum];

      final ti = src.texinfo;
      if ((ti < 0) || (ti >= this.texinfo.length)) {
        Com_Error(ERR_DROP, "LoadFaces: bad texinfo number");
      }

      out.texinfo = this.texinfo[ti];

      this.CalcSurfaceExtents(out);

      /* lighting info */
      out.styles = Uint8List(src.styles.length);
      out.styles.setAll(0, src.styles);

      var i = src.lightofs;
      if (i == -1) {
        out.samples = null;
      } else {
        out.samples = this.lightdata.sublist(i);
      }

      /* set the drawing flags */
      if ((out.texinfo.flags & SURF_WARP) != 0) {
        out.flags |= SURF_DRAWTURB;

        for (i = 0; i < 2; i++) {
          out.extents[i] = 16384;
          out.texturemins[i] = -8192;
        }

        WebGL_SubdivideSurface(out, this); /* cut up polygon for warps */
      }

      if (gl_fixsurfsky.boolean) {
        if ((out.texinfo.flags & SURF_SKY) != 0) { 
          out.flags |= SURF_DRAWSKY;
        }
      }

      /* create lightmaps and polygons */
      if ((out.texinfo.flags & (SURF_SKY | SURF_TRANS33 | SURF_TRANS66 | SURF_WARP)) == 0) {
        WebGL_LM_CreateSurfaceLightmap(out);
      }

      if ((out.texinfo.flags & SURF_WARP) == 0) {
        WebGL_LM_BuildPolygonFromSurface(out);
      }
      this.surfaces[surfnum] = out;
    }

    WebGL_LM_EndBuildingLightmaps();
  }

  static SetParent(mleadornode_t anode, mnode_t parent) {
    anode.parent = parent;

    if (anode.contents != -1) {
      return;
    }

    final node = anode as mnode_t;
    SetParent(node.children[0], node);
    SetParent(node.children[1], node);
  }

  LoadNodes(lump_t l, ByteData buffer) async {

    if ((l.filelen % dnodeSize) != 0) {
      Com_Error(ERR_DROP, "LoadNodes: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ dnodeSize;

    this.nodes = List.generate(count, (i) => mnode_t());

    for (int i = 0; i < count; i++) {
      final src = dnode_t(buffer, l.fileofs + i * dnodeSize);
      final out = this.nodes[i];
      for (int j = 0; j < 3; j++) {
        out.minmaxs[j] = src.mins[j].toDouble();
        out.minmaxs[3 + j] = src.maxs[j].toDouble();
      }

      out.plane = this.planes[src.planenum];

      out.firstsurface = src.firstface & 0xFFFF;
      out.numsurfaces = src.numfaces & 0xFFFF;
      out.contents = -1; /* differentiate from leafs */

      for (int j = 0; j < 2; j++) {
        int p = src.children[j];
        if (p >= 0) {
          out.children[j] = this.nodes[p];
        } else {
          out.children[j] = this.leafs[-1 - p];
        }
      }
    }

    SetParent(this.nodes[0], null); /* sets nodes and leafs */
  }

  LoadLeafs(lump_t l, ByteData buffer) async {

    if ((l.filelen % dleafSize) != 0) {
      Com_Error(ERR_DROP, "LoadLeafs: funny lump size in ${this.name}");
    }

    final count = l.filelen ~/ dleafSize;

    this.leafs = List(count);
    this.numleafs = count;

    for (int i = 0; i < count; i++) {
      final src = dleaf_t(buffer, l.fileofs + i * dleafSize);
      final out = mleaf_t();

      for (int j = 0; j < 3; j++) {
        out.minmaxs[j] = src.mins[j].toDouble();
        out.minmaxs[3 + j] = src.maxs[j].toDouble();
      }

      out.contents = src.contents;

      out.cluster = src.cluster;
      out.area = src.area;

      // make unsigned long from signed short
      int firstleafface = src.firstleafface & 0xFFFF;
      out.nummarksurfaces = src.numleaffaces & 0xFFFF;
      if ((firstleafface + out.nummarksurfaces) > this.marksurfaces.length) {
        Com_Error(ERR_DROP, "LoadLeafs: wrong marksurfaces position in ${this.name}");
      }
      out.firstmarksurface = firstleafface;
      // out.firstmarksurface = this.marksurfaces.sublist(firstleafface);
      this.leafs[i] = out;
    }
  }

}

class webglaliasmodel_t extends webglmodel_t {

  dmdl_t header;
  List<daliasframe_t> frames;
  ByteData cmds;
  List<String> skinNames;

  webglaliasmodel_t(String name) : super(name, modtype_t.mod_alias);

}

const MAX_MOD_KNOWN = 512;
List<webglmodel_t> mod_known = [];
int registration_sequence = 0;
webglbrushmodel_t webgl_worldmodel;
List<webglbrushmodel_t> mod_inline = List(MAX_MOD_KNOWN);
Uint8List mod_novis = Uint8List(MAX_MAP_LEAFS ~/ 8);

Future<webglaliasmodel_t> Mod_LoadAliasModel(String name, ByteData buffer, ByteBuffer buf) async {

  webglaliasmodel_t mod = webglaliasmodel_t(name);

	final pheader = dmdl_t(buffer, 0);
	if (pheader.version != ALIAS_VERSION) {
		Com_Error(ERR_DROP, "$name has wrong version number (${pheader.version} should be $ALIAS_VERSION)");
	}

	if (pheader.ofs_end < 0 || pheader.ofs_end > buffer.lengthInBytes) {
	  Com_Error(ERR_DROP, "model $name file size(${buffer.lengthInBytes}) too small, should be ${pheader.ofs_end}");
  }

	if (pheader.skinheight > MAX_LBM_HEIGHT) {
		Com_Error(ERR_DROP, "model $name has a skin taller than $MAX_LBM_HEIGHT");
	}

	if (pheader.num_xyz <= 0) {
		Com_Error(ERR_DROP, "model $name has no vertices");
	}

	if (pheader.num_xyz > MAX_VERTS) {
		Com_Error(ERR_DROP, "model $name has too many vertices");
	}

	if (pheader.num_st <= 0) {
		Com_Error(ERR_DROP, "model $name has no st vertices");
	}

	if (pheader.num_tris <= 0) {
		Com_Error(ERR_DROP, "model $name has no triangles");
	}

	if (pheader.num_frames <= 0) {
		Com_Error(ERR_DROP, "model $name has no frames");
	}

	/* load the frames */
  mod.frames = List<daliasframe_t>.generate(pheader.num_frames, (i) => daliasframe_t(buffer, pheader.ofs_frames + i * pheader.framesize, pheader.framesize));

	/* load the glcmds */
  mod.cmds = buf.asByteData(pheader.ofs_glcmds, pheader.num_glcmds * 4);

	/* register all skins */
  mod.skinNames = List<String>.generate(pheader.num_skins, (i) => readString(buffer, pheader.ofs_skins + i * MAX_SKINNAME, MAX_SKINNAME));
  mod.skins = List(pheader.num_skins);
  for (int i = 0; i < pheader.num_skins; i++) {
    mod.skins[i] = await WebGL_FindImage(mod.skinNames[i], imagetype_t.it_skin);
  }

  mod.header = pheader;

	mod.mins[0] = -32;
	mod.mins[1] = -32;
	mod.mins[2] = -32;
	mod.maxs[0] = 32;
	mod.maxs[1] = 32;
	mod.maxs[2] = 32;
  return mod;
}


Future<webglbrushmodel_t> Mod_LoadBrushModel(String name, ByteData buffer) async {

	if (mod_known.isNotEmpty && mod_known[0] != null) {
		Com_Error(ERR_DROP, "Loaded a brush model after the world");
	}

  webglbrushmodel_t mod = webglbrushmodel_t(name);

  final header = dheader_t(buffer, 0);
	if (header.version != BSPVERSION) {
		Com_Error(ERR_DROP, "Mod_LoadBrushModel: $name has wrong version number (${header.version} should be $BSPVERSION)");
	}

	/* load into heap */
	mod.LoadVertexes(header.lumps[LUMP_VERTEXES], buffer);
	mod.LoadEdges(header.lumps[LUMP_EDGES], buffer);
	mod.LoadSurfedges(header.lumps[LUMP_SURFEDGES], buffer);
	mod.LoadLighting(header.lumps[LUMP_LIGHTING], buffer);
	mod.LoadPlanes(header.lumps[LUMP_PLANES], buffer);
	await mod.LoadTexinfo(header.lumps[LUMP_TEXINFO], buffer);
	await mod.LoadFaces(header.lumps[LUMP_FACES], buffer);
	mod.LoadMarksurfaces(header.lumps[LUMP_LEAFFACES], buffer);
	mod.LoadVisibility(header.lumps[LUMP_VISIBILITY], buffer);
	mod.LoadLeafs(header.lumps[LUMP_LEAFS], buffer);
	mod.LoadNodes(header.lumps[LUMP_NODES], buffer);
	mod.LoadSubmodels(header.lumps[LUMP_MODELS], buffer);
	mod.numframes = 2; /* regular and alternate animation */

	/* set up the submodels */
	for (int i = 0; i < mod.submodels.length; i++) {
		webglbrushmodel_t starmod = webglbrushmodel_t(mod.name);

		final bm = mod.submodels[i];

		starmod.copy(mod);

		starmod.firstmodelsurface = bm.firstface;
		starmod.nummodelsurfaces = bm.numfaces;
		starmod.firstnode = bm.headnode;

		if (starmod.firstnode >= mod.nodes.length) {
			Com_Error(ERR_DROP, "Mod_LoadBrushModel: Inline model $i has bad firstnode ${starmod.firstnode} ${mod.nodes.length}");
		}

    starmod.mins.setAll(0, bm.mins);
    starmod.maxs.setAll(0, bm.maxs);
		starmod.radius = bm.radius;

		if (i == 0) {
			mod.copy(starmod);
		}

		starmod.numleafs = bm.visleafs;
	  mod_inline[i] = starmod;
	}
  return mod;
}

/*
 * Loads in a model for the given name
 */
Future<webglmodel_t> Mod_ForName(String name, bool crash) async {

	if (name == null || name.isEmpty) {
		Com_Error(ERR_DROP, "Mod_ForName: NULL name");
	}

	/* inline models are grabbed only from worldmodel */
	if (name[0] == '*') {
    final i = int.parse(name.substring(1));
		if ((i < 1) || webgl_worldmodel == null || (i >= webgl_worldmodel.submodels.length)) {
			Com_Error(ERR_DROP, "Mod_ForName: bad inline model number $i",);
		}

		return mod_inline[i];
	}

	/* search the currently loaded models */
	for (webglmodel_t mod in mod_known) {
		if (mod == null) {
			continue;
		}

		if (mod.name == name) {
			return mod;
		}
	}

	/* find a free model slot spot */
  int index = -1;
	for (int i = 0; i < mod_known.length; i++) {
		if (mod_known[i] == null) {
      index = i;
			break; /* free spot */
		}
	}

  if (index < 0 && mod_known.length >=  MAX_MOD_KNOWN) {
    Com_Error(ERR_DROP, "mod_numknown == MAX_MOD_KNOWN");
  }

	/* load the file */
  final buf = await FS_LoadFile(name);
	if (buf == null) {
		if (crash) {
			Com_Error(ERR_DROP, "Mod_ForName: $name not found");
		}
		return null;
	}

  webglmodel_t mod;

	/* call the apropriate loader */
  final view = buf.asByteData();
  final id = view.getUint32(0, Endian.little);
	switch (id) {
		case IDALIASHEADER:
			mod = await Mod_LoadAliasModel(name, view, buf);
			break;

	// 	case IDSPRITEHEADER:
	// 		GL3_LoadSP2(mod, buf, modfilelen);
	// 		break;

		case IDBSPHEADER:
			mod = await  Mod_LoadBrushModel(name, view);
			break;

		default:
			Com_Error(ERR_DROP, "Mod_ForName: unknown fileid for $name ${id.toRadixString(16)}");
			break;
	}

  if (mod != null) {
    if (index < 0) {
      mod_known.add(mod);
    } else {
      mod_known[index] = mod;
    }
  }

	return mod;
}


/*
 * Specifies the model that will be used as the world
 */
Future<void> WebGL_BeginRegistration(String model) async {
	registration_sequence++;
	webgl_oldviewcluster = -1; /* force markleafs */

	glstate.currentlightmap = -1;

	final fullname = "maps/$model.bsp";

	/* explicitly free the old map if different
	   this guarantees that mod_known[0] is the
	   world map */
	final flushmap = Cvar_Get("flushmap", "0", 0);

	if (mod_known.isNotEmpty && mod_known[0] != null && (mod_known[0].name != fullname || flushmap.boolean)) {
    mod_known[0] = null;
	}

  webgl_worldmodel = await Mod_ForName(fullname, true);

	webgl_viewcluster = -1;
}

Future<Object> WebGL_RegisterModel(String name) async {

	final mod = await Mod_ForName(name, false);

	if (mod != null) {
		mod.registration_sequence = registration_sequence;

		/* register any images used by the models */
		if (mod.type == modtype_t.mod_sprite) {
		// 	sprout = (dsprite_t *)mod->extradata;

		// 	for (i = 0; i < sprout->numframes; i++)
		// 	{
		// 		mod->skins[i] = GL3_FindImage(sprout->frames[i].name, it_sprite);
		// 	}
		} else if (mod.type == modtype_t.mod_alias) {
      final amod = mod as webglaliasmodel_t;

			for (int i = 0; i < amod.header.num_skins; i++) {
				mod.skins[i] = await WebGL_FindImage(amod.skinNames[i], imagetype_t.it_skin);
			}

			mod.numframes = amod.header.num_frames;
		} else if (mod.type == modtype_t.mod_brush) {
      final bmod = mod as webglbrushmodel_t;
			for (int i = 0; i < bmod.texinfo.length; i++) {
				bmod.texinfo[i].image.registration_sequence = registration_sequence;
			}
		}
	}

	return mod;
}

double Mod_RadiusFromBounds(List<double> mins, List<double> maxs) {

  final corner = List<double>.generate(3, (i) => mins[i].abs() > maxs[i].abs() ? mins[i].abs() : maxs[i].abs());
	return VectorLength(corner);
}

WebGL_Mod_Init() {
	mod_novis.fillRange(0, mod_novis.length, 0xff);
}

mleaf_t WebGL_Mod_PointInLeaf(List<double> p, webglbrushmodel_t model) {

	if (model == null || model.nodes == null) {
		Com_Error(ERR_DROP, "WebGL_Mod_PointInLeaf: bad model");
	}

	mleadornode_t anode = model.nodes[0];

	while (true) {
		if (anode.contents != -1) {
			return anode as mleaf_t;
		}

    var node = anode as mnode_t;
		var plane = node.plane;
		var d = DotProduct(p, plane.normal) - plane.dist;

		if (d > 0) {
			anode = node.children[0];
		} else {
			anode = node.children[1];
		}
	}
}

Uint8List WebGL_Mod_ClusterPVS(int cluster, webglbrushmodel_t model) {
	if ((cluster == -1) || model.vis == null) {
		return mod_novis;
	}

	return Mod_DecompressVis(model.visData.sublist(
			  model.vis.bitofs[cluster][DVIS_PVS]),
			(model.vis.numclusters + 7) >> 3);
}

/*
===================
Mod_DecompressVis
===================
*/
Uint8List Mod_DecompressVis(Uint8List ind, int row) {
	Uint8List decompressed = Uint8List(MAX_MAP_LEAFS ~/ 8);

  int out_i = 0;
	if (ind == null) {
		/* no vis info, so make all visible */
		while (row > 0) {
			decompressed[out_i++] = 0xff;
			row--;
		}
		return decompressed;
	}

  int in_i = 0;
	do {
		if (ind[in_i] != 0) {
      decompressed[out_i++] = ind[in_i++];
			continue;
		}

		int c = ind[in_i + 1];
		in_i += 2;

		while (c > 0) {
			decompressed[out_i++] = 0;
			c--;
		}
	}
	while (out_i < row);

	return decompressed;
}