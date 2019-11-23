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
 *  The prototypes for most file formats used by Quake II
 *
 * =======================================================================
 */
import 'dart:typed_data';

String readString(ByteData data, int offset, int maxLength) {
  var str = StringBuffer();
  for (int i = 0; i < maxLength && data.getUint8(offset + i) != 0; i++) {
    str.writeCharCode(data.getUint8(offset + i));
  }
  return str.toString();
}

/* .MD2 triangle model file format */

const IDALIASHEADER = 0x32504449; //(('2' << 24) + ('P' << 16) + ('D' << 8) + 'I')
const ALIAS_VERSION = 8;

const MAX_TRIANGLES = 4096;
const MAX_VERTS = 2048;
const MAX_FRAMES = 512;
const MAX_MD2SKINS = 32;
const MAX_SKINNAME = 64;

class dstvert_t {
	int s;
	int t;

  dstvert_t(ByteData data, int offset) {
    this.s = data.getInt16(offset, Endian.little);
    this.t = data.getInt16(offset + 2, Endian.little);
  }
}
const dstvertSize = 2 * 2;

class dtriangle_t {
	List<int> index_xyz;
	List<int> index_st;

  dtriangle_t(ByteData data, int offset) {
    this.index_xyz = List.generate(3, (i) => data.getInt16(offset + i * 2, Endian.little));
    this.index_st = List.generate(3, (i) => data.getInt16(offset + (i + 3) * 2, Endian.little));
  }
}
const dtriangleSize = 6 * 2;

class dtrivertx_t {
	List<int> v; /* scaled byte to fit in frame mins/maxs */
	int lightnormalindex;

  dtrivertx_t(ByteData data, int offset) {
    this.v = List.generate(3, (i) => data.getUint8(offset + i));
    this.lightnormalindex = data.getUint8(offset + 3);
  }
}
const dtrivertxSize = 4;

const DTRIVERTX_V0 = 0;
const DTRIVERTX_V1 = 1;
const DTRIVERTX_V2 = 2;
const DTRIVERTX_LNI = 3;
const DTRIVERTX_SIZE = 4;

class daliasframe_t {
	List<double> scale;       /* multiply byte verts by this */
	List<double> translate;   /* then add this */
	String name;        /* frame name from grabbing */
	List<dtrivertx_t> verts; /* variable sized */

  daliasframe_t(ByteData data, int offset, int size) {
    final count = (size - daliasframeSize) ~/ dtrivertxSize;
    assert(((size - daliasframeSize) % dtrivertxSize) == 0);
    this.scale = List.generate(3, (i) => data.getFloat32(offset + i * 4, Endian.little));
    this.translate = List.generate(3, (i) => data.getFloat32(offset + (i + 3) * 4, Endian.little));
    this.name = readString(data, offset + 6 * 4, 16);
    this.verts = List.generate(count, (i) => dtrivertx_t(data, offset + daliasframeSize + i * dtrivertxSize));
  }

}
const daliasframeSize = 16 + 6 * 4;

/* the glcmd format:
 * - a positive integer starts a tristrip command, followed by that many
 *   vertex structures.
 * - a negative integer starts a trifan command, followed by -x vertexes
 *   a zero indicates the end of the command list.
 * - a vertex consists of a floating point s, a floating point t,
 *   and an integer vertex index. */

class dmdl_t {
	int ident;
	int version;

	int skinwidth;
	int skinheight;
	int framesize;  /* byte size of each frame */

	int num_skins;
	int num_xyz;
	int num_st;     /* greater than num_xyz for seams */
	int num_tris;
	int num_glcmds; /* dwords in strip/fan command list */
	int num_frames;

	int ofs_skins;  /* each skin is a MAX_SKINNAME string */
	int ofs_st;     /* byte offset from start for stverts */
	int ofs_tris;   /* offset for dtriangles */
	int ofs_frames; /* offset for first frame */
	int ofs_glcmds;
	int ofs_end;    /* end of file */

  dmdl_t(ByteData data, int offset) {
    this.ident = data.getInt32(offset, Endian.little);
    this.version = data.getInt32(offset + 1 * 4, Endian.little);
    this.skinwidth = data.getInt32(offset + 2 * 4, Endian.little);
    this.skinheight = data.getInt32(offset + 3 * 4, Endian.little);
    this.framesize = data.getInt32(offset + 4 * 4, Endian.little);
    this.num_skins = data.getInt32(offset + 5 * 4, Endian.little);
    this.num_xyz = data.getInt32(offset + 6 * 4, Endian.little);
    this.num_st = data.getInt32(offset + 7 * 4, Endian.little);
    this.num_tris = data.getInt32(offset + 8 * 4, Endian.little);
    this.num_glcmds = data.getInt32(offset + 9 * 4, Endian.little);
    this.num_frames = data.getInt32(offset + 10 * 4, Endian.little);
    this.ofs_skins = data.getInt32(offset + 11 * 4, Endian.little);
    this.ofs_st = data.getInt32(offset + 12 * 4, Endian.little);
    this.ofs_tris = data.getInt32(offset + 13 * 4, Endian.little);
    this.ofs_frames = data.getInt32(offset + 14 * 4, Endian.little);
    this.ofs_glcmds = data.getInt32(offset + 15 * 4, Endian.little);
    this.ofs_end = data.getInt32(offset + 16 * 4, Endian.little);
  }
}
const dmdlSize = 17 * 4;

/* .SP2 sprite file format */

const IDSPRITEHEADER = 0x32534449; // (('2' << 24) + ('S' << 16) + ('D' << 8) + 'I') /* little-endian "IDS2" */
const SPRITE_VERSION = 2;

class dsprframe_t {
	int width, height;
	int origin_x, origin_y;  /* raster coordinates inside pic */
	String name; /* name of pcx file */

  dsprframe_t(ByteData data, int offset) {
    this.width = data.getInt32(offset, Endian.little);
    this.height = data.getInt32(offset + 1 * 4, Endian.little);
    this.origin_x = data.getInt32(offset + 2 * 4, Endian.little);
    this.origin_y = data.getInt32(offset + 3 * 4, Endian.little);
    this.name = readString(data, offset + 4 * 4, MAX_SKINNAME);
  }
}
const dsprframeSize = 4 * 4 + MAX_SKINNAME;

class dsprite_t {
	int ident;
	int version;
	int numframes;

  dsprite_t(ByteData data, int offset) {
    this.ident = data.getInt32(offset, Endian.little);
    this.version = data.getInt32(offset + 1 * 4, Endian.little);
    this.numframes = data.getInt32(offset + 2 * 4, Endian.little);
  }
}
const dspriteSize = 3 * 4;

/* .BSP file format */

const IDBSPHEADER = 0x50534249; // (('P' << 24) + ('S' << 16) + ('B' << 8) + 'I') /* little-endian "IBSP" */
const BSPVERSION = 38;

/* upper design bounds: leaffaces, leafbrushes, planes, and 
 * verts are still bounded by 16 bit short limits */
const MAX_MAP_MODELS = 1024;
const MAX_MAP_BRUSHES = 8192;
const MAX_MAP_ENTITIES = 2048;
const MAX_MAP_ENTSTRING = 0x40000;
const MAX_MAP_TEXINFO = 8192;

const MAX_MAP_AREAS = 256;
const MAX_MAP_AREAPORTALS = 1024;
const MAX_MAP_PLANES = 65536;
const MAX_MAP_NODES = 65536;
const MAX_MAP_BRUSHSIDES = 65536;
const MAX_MAP_LEAFS = 65536;
const MAX_MAP_VERTS = 65536;
const MAX_MAP_FACES = 65536;
const MAX_MAP_LEAFFACES = 65536;
const MAX_MAP_LEAFBRUSHES = 65536;
const MAX_MAP_PORTALS = 65536;
const MAX_MAP_EDGES = 128000;
const MAX_MAP_SURFEDGES = 256000;
const MAX_MAP_LIGHTING = 0x200000;
const MAX_MAP_VISIBILITY = 0x100000;

/* key / value pair sizes */

const MAX_KEY = 32;
const MAX_VALUE = 1024;

/* ================================================================== */

class lump_t {
	int fileofs, filelen;

  lump_t(ByteData data, int offset) {
    this.fileofs = data.getInt32(offset, Endian.little);
    this.filelen = data.getInt32(offset + 4, Endian.little);
  }
}

const lumpSize = 2 * 4;

const LUMP_ENTITIES = 0;
const LUMP_PLANES = 1;
const LUMP_VERTEXES = 2;
const LUMP_VISIBILITY = 3;
const LUMP_NODES = 4;
const LUMP_TEXINFO = 5;
const LUMP_FACES = 6;
const LUMP_LIGHTING = 7;
const LUMP_LEAFS = 8;
const LUMP_LEAFFACES = 9;
const LUMP_LEAFBRUSHES = 10;
const LUMP_EDGES = 11;
const LUMP_SURFEDGES = 12;
const LUMP_MODELS = 13;
const LUMP_BRUSHES = 14;
const LUMP_BRUSHSIDES = 15;
const LUMP_POP = 16;
const LUMP_AREAS = 17;
const LUMP_AREAPORTALS = 18;
const HEADER_LUMPS = 19;

class dheader_t {
	int ident;
	int version;
	List<lump_t> lumps;

  dheader_t(ByteData data, int offset) {
    this.ident = data.getUint32(offset, Endian.little);
    this.version = data.getInt32(offset + 4, Endian.little);
    this.lumps = List.generate(HEADER_LUMPS, (i) => lump_t(data, offset + 2 * 4 + i * lumpSize));
  }

}

const dheaderSize = 2 * 4 + HEADER_LUMPS * lumpSize;

class dmodel_t {
  List<double> mins;
  List<double> maxs;
  List<double> origin;     /* for sounds or lights */
	int headnode;
	int firstface, numfaces; /* submodels just draw faces without
							    walking the bsp tree */

  dmodel_t(ByteData data, int offset) {
    this.mins = List.generate(3, (i) => data.getFloat32(offset + i * 4, Endian.little));
    this.maxs = List.generate(3, (i) => data.getFloat32(offset + (i + 3) * 4, Endian.little));
    this.origin = List.generate(3, (i) => data.getFloat32(offset + (i + 6) * 4, Endian.little));
    this.headnode = data.getInt32(offset + 9 * 4, Endian.little);
    this.firstface = data.getInt32(offset + 10 * 4, Endian.little);
    this.numfaces = data.getInt32(offset + 11 * 4, Endian.little);
  }
}
const dmodelSize = 12 * 4;

class dvertex_t {
	List<double> point;

  dvertex_t(ByteData data, int offset) {
    this.point = List.generate(3, (i) => data.getFloat32(offset + i * 4, Endian.little));
  }
}
const dvertexSize = 3 * 4;

/* 0-2 are axial planes */
const PLANE_X = 0;
const PLANE_Y = 1;
const PLANE_Z = 2;

/* 3-5 are non-axial planes snapped to the nearest */
const PLANE_ANYX = 3;
const PLANE_ANYY = 4;
const PLANE_ANYZ = 5;

/* planes (x&~1) and (x&~1)+1 are always opposites */

class dplane_t {
	List<double> normal;
	double dist;
	int type; /* PLANE_X - PLANE_ANYZ */

  dplane_t(ByteData data, int offset) {
    this.normal = List.generate(3, (i) => data.getFloat32(offset + i * 4, Endian.little));
    this.dist = data.getFloat32(offset + 3 * 4, Endian.little);
    this.type = data.getInt32(offset + 4 * 4, Endian.little);
  }
}
const dplaneSize = 5 * 4;

/* contents flags are seperate bits
 * - given brush can contribute multiple content bits
 * - multiple brushes can be in a single leaf */

/* lower bits are stronger, and will eat weaker brushes completely */
const CONTENTS_SOLID = 1;  /* an eye is never valid in a solid */
const CONTENTS_WINDOW = 2; /* translucent, but not watery */
const CONTENTS_AUX = 4;
const CONTENTS_LAVA = 8;
const CONTENTS_SLIME = 16;
const CONTENTS_WATER = 32;
const CONTENTS_MIST = 64;
const LAST_VISIBLE_CONTENTS = 64;

/* remaining contents are non-visible, and don't eat brushes */
const CONTENTS_AREAPORTAL = 0x8000;

const CONTENTS_PLAYERCLIP = 0x10000;
const CONTENTS_MONSTERCLIP = 0x20000;

/* currents can be added to any other contents, and may be mixed */
const CONTENTS_CURRENT_0 = 0x40000;
const CONTENTS_CURRENT_90 = 0x80000;
const CONTENTS_CURRENT_180 = 0x100000;
const CONTENTS_CURRENT_270 = 0x200000;
const CONTENTS_CURRENT_UP = 0x400000;
const CONTENTS_CURRENT_DOWN = 0x800000;

const CONTENTS_ORIGIN = 0x1000000;       /* removed before bsping an entity */

const CONTENTS_MONSTER = 0x2000000;      /* should never be on a brush, only in game */
const CONTENTS_DEADMONSTER = 0x4000000;
const CONTENTS_DETAIL = 0x8000000;       /* brushes to be added after vis leafs */
const CONTENTS_TRANSLUCENT = 0x10000000; /* auto set if any surface has trans */
const CONTENTS_LADDER = 0x20000000;

const SURF_LIGHT = 0x1;    /* value will hold the light strength */

const SURF_SLICK = 0x2;    /* effects game physics */

const SURF_SKY = 0x4;      /* don't draw, but add to skybox */
const SURF_WARP = 0x8;     /* turbulent water warp */
const SURF_TRANS33 = 0x10;
const SURF_TRANS66 = 0x20;
const SURF_FLOWING = 0x40; /* scroll towards angle */
const SURF_NODRAW = 0x80;  /* don't bother referencing the texture */

class dnode_t {
	int planenum;
	List<int> children;         /* negative numbers are -(leafs+1), not nodes */
	List<int> mins;           /* for frustom culling */
	List<int> maxs;
	int firstface;
	int numfaces; /* counting both sides */

  dnode_t(ByteData data, int offset) {
    this.planenum = data.getInt32(offset, Endian.little);
    this.children = List.generate(2, (i) => data.getInt32(offset + (i + 1) * 4, Endian.little));
    this.mins = List.generate(3, (i) => data.getInt16(offset + i * 2 + 3 * 4, Endian.little));
    this.maxs = List.generate(3, (i) => data.getInt16(offset + (i + 3) * 2 + 3 * 4, Endian.little));
    this.firstface = data.getUint16(offset + 3 * 4 + 6 * 2, Endian.little);
    this.numfaces = data.getUint16(offset + 3 * 4 + 7 * 2, Endian.little);
  }
}
const dnodeSize = 3 * 4 + 8 * 2;

class texinfo_t {
	List<List<double>> vecs; // [2][4]; /* [s/t][xyz offset] */
	int flags;        /* miptex flags + overrides light emission, etc */
	int value;           
	String texture; /* texture name (textures*.wal) */
	int nexttexinfo;  /* for animations, -1 = end of chain */

  texinfo_t(ByteData data, int offset) {
    this.vecs = List.generate(2, (i) => 
      List.generate(4, (j) => data.getFloat32(offset + ((i * 4) + j) * 4, Endian.little)));
    this.flags = data.getInt32(offset + 8 * 4, Endian.little);
    this.value = data.getInt32(offset + 9 * 4, Endian.little);
    this.texture = readString(data, offset + 10 * 4, 32);
    this.nexttexinfo = data.getInt32(offset + 10 * 4 + 32, Endian.little);
  }
}
const texinfoSize = 11 * 4 + 32;

/* note that edge 0 is never used, because negative edge 
   nums are used for counterclockwise use of the edge in
   a face */
class dedge_t {
	List<int> v; /* vertex numbers */

  dedge_t(ByteData data, int offset) {
    this.v = List.generate(2, (i) => data.getUint16(offset + i * 2, Endian.little));
  }
}
const dedgeSize = 2 * 2;

const MAXLIGHTMAPS = 4;
class dface_t {
	int planenum;
	int side;

	int firstedge; /* we must support > 64k edges */
	int numedges;
	int texinfo;

	/* lighting info */
	Uint8List styles;
	int lightofs; /* start of [numstyles*surfsize] samples */

  dface_t(ByteData data, int offset) {
    this.planenum = data.getUint16(offset + 0, Endian.little);
    this.side = data.getInt16(offset + 2, Endian.little);
    this.firstedge = data.getInt32(offset + 2 * 2, Endian.little);
    this.numedges = data.getInt16(offset + 2 * 2 + 4, Endian.little);
    this.texinfo = data.getInt16(offset + 3 * 2 + 4, Endian.little);
    this.styles = Uint8List(MAXLIGHTMAPS);
    this.styles.setAll(0, data.buffer.asUint8List(offset + 4 * 2 + 4, MAXLIGHTMAPS));
    this.lightofs = data.getInt32(offset + 4 * 2 + 4 + MAXLIGHTMAPS, Endian.little);
  }
}
const dfaceSize = 4 * 2 + 2 * 4 + MAXLIGHTMAPS;

class dleaf_t {
	int contents; /* OR of all brushes (not needed?) */

	int cluster;
	int area;

	List<int> mins; /* for frustum culling */
	List<int> maxs;

	int firstleafface;
	int numleaffaces;

	int firstleafbrush;
	int numleafbrushes;

  dleaf_t(ByteData data, int offset) {
    this.contents = data.getInt32(offset + 0, Endian.little);
    this.cluster = data.getInt16(offset + 4, Endian.little);
    this.area = data.getInt16(offset + 4 + 2, Endian.little);
    this.mins = List.generate(3, (i) => data.getInt16(offset + (i + 2) * 2 + 4, Endian.little));
    this.maxs = List.generate(3, (i) => data.getInt16(offset + (i + 5) * 2 + 4, Endian.little));
    this.firstleafface = data.getUint16(offset + 4 + 8 * 2, Endian.little);
    this.numleaffaces = data.getUint16(offset + 4 + 9 * 2, Endian.little);
    this.firstleafbrush = data.getUint16(offset + 4 + 10 * 2, Endian.little);
    this.numleafbrushes = data.getUint16(offset + 4 + 11 * 2, Endian.little);
  }
}
const dleafSize = 4 + 12 * 2;

class dbrushside_t {
	int planenum; /* facing out of the leaf */
	int texinfo;

  dbrushside_t(ByteData data, int offset) {
    this.planenum = data.getUint16(offset, Endian.little);
    this.texinfo = data.getInt16(offset + 2, Endian.little);
  }
}
const dbrushsideSize = 2 * 2;

class dbrush_t {
	int firstside;
	int numsides;
	int contents;

  dbrush_t(ByteData data, int offset) {
    this.firstside = data.getInt32(offset, Endian.little);
    this.numsides = data.getInt32(offset + 4, Endian.little);
    this.contents = data.getInt32(offset + 2 * 4, Endian.little);
  }
}
const dbrushSize = 3 * 4;

const ANGLE_UP = -1;
const ANGLE_DOWN = -2;

/* the visibility lump consists of a header with a count, then 
 * byte offsets for the PVS and PHS of each cluster, then the raw 
 * compressed bit vectors */
const DVIS_PVS = 0;
const DVIS_PHS = 1;
class dvis_t {
	int numclusters;
	List<List<int>> bitofs; /* bitofs[numclusters][2] */

  dvis_t(ByteData data, int offset) {
    this.numclusters = data.getInt32(offset, Endian.little);
    this.bitofs = List.generate(this.numclusters, (i) => 
      [data.getInt32(offset + ((i * 2)  + 1) * 4, Endian.little), data.getInt32(offset + ((i * 2) + 2) * 4, Endian.little)]);
  }
}

/* each area has a list of portals that lead into other areas
 * when portals are closed, other areas may not be visible or
 * hearable even if the vis info says that it should be */
class dareaportal_t {
	int portalnum;
	int otherarea;

  dareaportal_t(ByteData data, int offset) {
    this.portalnum = data.getInt32(offset + 0, Endian.little);
    this.otherarea = data.getInt32(offset + 4, Endian.little);
  }
}
const dareaportalSize = 2 * 4;

class darea_t {
	int numareaportals;
	int firstareaportal;

  darea_t(ByteData data, int offset) {
    this.numareaportals = data.getInt32(offset + 0, Endian.little);
    this.firstareaportal = data.getInt32(offset + 4, Endian.little);
  }
}
const dareaSize = 2 * 4;
