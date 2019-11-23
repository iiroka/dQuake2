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
 * Warps. Used on water surfaces und for skybox rotation.
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'dart:web_gl';

import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'local.dart';
import 'webgl_main.dart';
import 'webgl_model.dart';
import 'webgl_image.dart';
import 'webgl_misc.dart';
import 'webgl_shaders.dart';
import 'HMM.dart';

_R_BoundPoly(int numverts, List<List<double>> verts, List<double> mins, List<double> maxs) {

  mins.fillRange(0, 3, 9999);
  maxs.fillRange(0, 3, -9999);

	for (int i = 0; i < numverts; i++) {
		for (int j = 0; j < 3; j++) {
			if (verts[i][j] < mins[j]) {
				mins[j] = verts[i][j];
			}

			if (verts[i][j] > maxs[j]) {
				maxs[j] = verts[i][j];
			}
		}
	}
}

const _SUBDIVIDE_SIZE = 64.0;

_R_SubdividePolygon(int numverts, List<List<double>> verts, msurface_t warpface) {

  List<double> normal = List.generate(3, (i) => warpface.plane.normal[i]);
	if (numverts > 60) {
		Com_Error(ERR_DROP, "numverts = $numverts");
	}
    
  List<double> mins = [0,0,0];
  List<double> maxs = [0,0,0];
	_R_BoundPoly(numverts, verts, mins, maxs);

  List<double> dist = List(64);
  List<List<double>> front = List.generate(64, (i) => [0,0,0]);
  List<List<double>> back = List.generate(64, (i) => [0,0,0]);

	for (int i = 0; i < 3; i++) {
		double m = (mins[i] + maxs[i]) * 0.5;
		m = _SUBDIVIDE_SIZE * (m / _SUBDIVIDE_SIZE + 0.5).floor();

		if (maxs[i] - m < 8) {
			continue;
		}

		if (m - mins[i] < 8) {
			continue;
		}

		/* cut it */
		// v = verts + i;
		for (int j = 0; j < numverts; j++) {
			dist[j] = verts[j][i] - m;
		}

		/* wrap cases */
		dist[numverts] = dist[0];
		// v -= i;
    verts[numverts].setAll(0, verts[0]);

		int f = 0;
    int b = 0;
		// v = verts;

		for (int j = 0; j < numverts; j++) {
			if (dist[j] >= 0) {
        front[f].setAll(0, verts[j]);
				f++;
			}

			if (dist[j] <= 0) {
        back[b].setAll(0, verts[j]);
				b++;
			}

			if ((dist[j] == 0) || (dist[j + 1] == 0)) {
				continue;
			}

			if ((dist[j] > 0) != (dist[j + 1] > 0)) {
				/* clip point */
				final frac = dist[j] / (dist[j] - dist[j + 1]);

				for (int k = 0; k < 3; k++) {
					front[f][k] = verts[j][k] + frac * (verts[j + 1][k] - verts[j][k]);
          back[b][k] = front[f][k];
				}

				f++;
				b++;
			}
		}

		_R_SubdividePolygon(f, front, warpface);
		_R_SubdividePolygon(b, back, warpface);
		return;
	}

	/* add a point in the center to help keep warp valid */
  final poly = glpoly_t();
	poly.next = warpface.polys;
	warpface.polys = poly;
	poly.numverts = numverts + 2;
  List<double> total = [0,0,0];
	double total_s = 0;
	double total_t = 0;

  List<double> polyData = [];
  gl3_3D_vtx_t v = gl3_3D_vtx_t();
  polyData.addAll(v.data);

	for (int i = 0; i < numverts; i++) {
    v = gl3_3D_vtx_t();
    v.pos = Float32List.fromList(verts[i]);
		double s = DotProduct(verts[i], warpface.texinfo.vecs[0]);
		double t = DotProduct(verts[i], warpface.texinfo.vecs[1]);

		total_s += s;
		total_t += t;
		VectorAdd(total, verts[i], total);

    v.texCoord = Float32List.fromList([s, t]);
    v.normal = Float32List.fromList(normal);
    v.lightFlags = 0;
    polyData.addAll(v.data);
	}

  v = gl3_3D_vtx_t();
  v.pos = Float32List.fromList([total[0] / numverts, total[1] / numverts, total[2] / numverts]);
  v.texCoord = Float32List.fromList([total_s / numverts, total_t / numverts]);
  v.normal = Float32List.fromList(normal);
  polyData.setAll(0, v.data);

	/* copy first vertex to last */
  polyData.addAll(polyData.sublist(gl3_3D_vtx_size, 2 * gl3_3D_vtx_size));

  assert((polyData.length / gl3_3D_vtx_size) == (numverts + 2));

  poly.data = Float32List.fromList(polyData);
}

/*
 * Breaks a polygon up along axial 64 unit
 * boundaries so that turbulent and sky warps
 * can be done reasonably.
 */
WebGL_SubdivideSurface(msurface_t fa, webglbrushmodel_t loadmodel) {

	/* convert edges back to a normal polygon */
	int numverts = 0;
  List<List<double>> verts = List.generate(64, (i) => [0,0,0]);

	for (int i = 0; i < fa.numedges; i++) {
		int lindex = loadmodel.surfedges[fa.firstedge + i];

    List<double> vec;
		if (lindex > 0) {
			vec = loadmodel.vertexes[loadmodel.edges[lindex].v[0]].position;
		} else {
			vec = loadmodel.vertexes[loadmodel.edges[-lindex].v[1]].position;
		}

    verts[numverts].setAll(0, vec);
		numverts++;
	}

	_R_SubdividePolygon(numverts, verts, fa);
}

/*
 * Does a water warp on the pre-fragmented glpoly_t chain
 */
WebGL_EmitWaterPolys(msurface_t fa) {
	double scroll = 0.0;

	if ((fa.texinfo.flags & SURF_FLOWING) != 0) {
		scroll = -64.0 * ((webgl_newrefdef.time * 0.5) - (webgl_newrefdef.time * 0.5).toInt());
		if (scroll == 0.0) // this is done in GL3_DrawGLFlowingPoly() TODO: keep?
		{
			scroll = -64.0;
		}
	}

	if(glstate.uni3DData.scroll != scroll) {
		glstate.uni3DData.scroll = scroll;
		WebGL_UpdateUBO3D();
	}

	WebGL_UseProgram(glstate.si3Dturb.shaderProgram);

	WebGL_BindVAO(glstate.vao3D);
	WebGL_BindVBO(glstate.vbo3D);

	for (var bp = fa.polys; bp != null; bp = bp.next) {
		WebGL_BufferAndDraw3D(bp.data, bp.numverts, WebGL.TRIANGLE_FAN);
	}
}

// ########### below: Sky-specific stuff ##########

const _ON_EPSILON = 0.1; /* point on plane side epsilon */
const _MAX_CLIP_VERTS = 64;


List<int> _skytexorder = [0, 2, 1, 3, 4, 5];

List<List<double>> _skymins = [[0,0,0,0,0,0],[0,0,0,0,0,0]], _skymaxs = [[0,0,0,0,0,0],[0,0,0,0,0,0]];
double _sky_min, _sky_max;

double _skyrotate;
List<double> _skyaxis = [0,0,0];
List<webglimage_t> _sky_images = List(6);

/* 3dstudio environment map names */
List<String> _suf = ["rt", "bk", "lf", "ft", "up", "dn"];

List<List<double>> skyclip = [
	[1, 1, 0],
	[1, -1, 0],
	[0, -1, 1],
	[0, 1, 1],
	[1, 0, 1],
	[-1, 0, 1]
];
int c_sky = 0;

List<List<int>> st_to_vec = [
	[3, -1, 2],
	[-3, 1, 2],

	[1, 3, 2],
	[-1, -3, 2],

	[-2, -1, 3], /* 0 degrees yaw, look straight up */
	[2, -1, -3] /* look straight down */
];

List<List<int>> vec_to_st = [
	[-2, 3, 1],
	[2, 3, -1],

	[1, 3, 2],
	[-1, 3, -2],

	[-2, -1, 3],
	[-2, 1, -3]
];


WebGL_SetSky(String name, double rotate, List<double> axis) async {

	var skyname = name;
	_skyrotate = rotate;
  _skyaxis.setAll(0, axis);

	for (int i = 0; i < 6; i++) {
		// NOTE: there might be a paletted .pcx version, which was only used
		//       if gl_config.palettedtexture so it *shouldn't* be relevant for he GL3 renderer
		final pathname = "env/$skyname${_suf[i]}.tga";

		_sky_images[i] = await WebGL_FindImage(pathname, imagetype_t.it_sky);
		if (_sky_images[i] == null) {
			_sky_images[i] = webgl_notexture;
		}

		_sky_min = 1.0 / 512;
		_sky_max = 511.0 / 512;
	}
}

_DrawSkyPolygon(int nump, List<List<double>> vecs) {

	c_sky++;

	/* decide which face it maps to */
  List<double> v = [0,0,0];

	for (int i = 0; i < nump; i++)
	{
		VectorAdd(vecs[i], v, v);
	}

  List<double> av = List.generate(3, (i) => v[i].abs());

  int axis;
	if ((av[0] > av[1]) && (av[0] > av[2])) {
		if (v[0] < 0) {
			axis = 1;
		} else {
			axis = 0;
		}
	} else if ((av[1] > av[2]) && (av[1] > av[0])) {
		if (v[1] < 0) {
			axis = 3;
		} else {
			axis = 2;
		}
	} else {
		if (v[2] < 0) {
			axis = 5;
		} else {
			axis = 4;
		}
	}

	/* project new texture coords */
	for (int i = 0; i < nump; i++) {
		int j = vec_to_st[axis][2];
    double dv;
		if (j > 0) {
			dv = vecs[i][j - 1];
		} else {
			dv = -vecs[i][-j - 1];
		}

		if (dv < 0.001) {
			continue; /* don't divide by zero */
		}

		j = vec_to_st[axis][0];
    double s;
		if (j < 0) {
			s = -vecs[i][-j - 1] / dv;
		} else {
			s = vecs[i][j - 1] / dv;
		}

		j = vec_to_st[axis][1];
    double t;
		if (j < 0) {
			t = -vecs[i][-j - 1] / dv;
		} else {
			t = vecs[i][j - 1] / dv;
		}

		if (s < _skymins[0][axis]) {
			_skymins[0][axis] = s;
		}

		if (t < _skymins[1][axis]) {
			_skymins[1][axis] = t;
		}

		if (s > _skymaxs[0][axis]) {
			_skymaxs[0][axis] = s;
		}

		if (t > _skymaxs[1][axis]) {
			_skymaxs[1][axis] = t;
		}
	}
}

_ClipSkyPolygon(int nump, List<List<double>> vecs, int stage) {

	if (nump > _MAX_CLIP_VERTS - 2) {
		Com_Error(ERR_DROP, "R_ClipSkyPolygon: MAX_CLIP_VERTS");
	}

	if (stage == 6) {
		/* fully clipped, so draw it */
		_DrawSkyPolygon(nump, vecs);
		return;
	}

	bool front = false, back = false;
	List<double> norm = skyclip[stage];
  List<int> sides = List(_MAX_CLIP_VERTS);
  List<double> dists = List(_MAX_CLIP_VERTS);

	for (int i = 0; i < nump; i++) {
		double d = DotProduct(vecs[i], norm);

		if (d > _ON_EPSILON) {
			front = true;
			sides[i] = SIDE_FRONT;
		}
		else if (d < -_ON_EPSILON)
		{
			back = true;
			sides[i] = SIDE_BACK;
		}
		else
		{
			sides[i] = SIDE_ON;
		}

		dists[i] = d;
	}

	if (!front || !back) {
		/* not clipped */
		_ClipSkyPolygon(nump, vecs, stage + 1);
		return;
	}

	/* clip it */
	sides[nump] = sides[0];
	dists[nump] = dists[0];
  vecs[nump].setAll(0, vecs[0]);

	List<int> newc = [0, 0];
	List<List<List<double>>> newv = List.generate(2, (k) => List.generate(_MAX_CLIP_VERTS, (j) => [0,0,0]));

	for (int i = 0; i < nump; i++) {
		switch (sides[i])
		{
			case SIDE_FRONT:
        newv[0][newc[0]].setAll(0, vecs[i]);
				newc[0]++;
				break;
			case SIDE_BACK:
        newv[1][newc[1]].setAll(0, vecs[i]);
				newc[1]++;
				break;
			case SIDE_ON:
        newv[0][newc[0]].setAll(0, vecs[i]);
				newc[0]++;
        newv[1][newc[1]].setAll(0, vecs[i]);
				newc[1]++;
				break;
		}

		if ((sides[i] == SIDE_ON) ||
			(sides[i + 1] == SIDE_ON) ||
			(sides[i + 1] == sides[i])) {
			continue;
		}

		double d = dists[i] / (dists[i] - dists[i + 1]);

		for (int j = 0; j < 3; j++) {
			double e = vecs[i][j] + d * (vecs[i + 1][j] - vecs[i][j]);
			newv[0][newc[0]][j] = e;
			newv[1][newc[1]][j] = e;
		}

		newc[0]++;
		newc[1]++;
	}

	/* continue */
	_ClipSkyPolygon(newc[0], newv[0], stage + 1);
	_ClipSkyPolygon(newc[1], newv[1], stage + 1);
}

WebGL_AddSkySurface(msurface_t fa) {

	List<List<double>> verts =List.generate(_MAX_CLIP_VERTS, (i) => [0,0,0]);

	/* calculate vertex values for sky box */
	for (var p = fa.polys; p != null; p = p.next) {
		for (int i = 0; i < p.numverts; i++) {
      VectorSubtract(p.data.sublist(i * gl3_3D_vtx_size, (i * gl3_3D_vtx_size) + 3), webgl_origin, verts[i]);
		}

		_ClipSkyPolygon(p.numverts, verts, 0);
	}
}


WebGL_ClearSkyBox() {
	for (int i = 0; i < 6; i++) {
		_skymins[0][i] = _skymins[1][i] = 9999;
		_skymaxs[0][i] = _skymaxs[1][i] = -9999;
	}
}

_MakeSkyVec(double s, double t, int axis, Float32List vert, int offset) {

	double dist = (!r_farsee.boolean) ? 2300.0 : 4096.0;

  List<double> b = [s * dist, t * dist, dist];
  List<double> v = [0,0,0];

	for (int j = 0; j < 3; j++) {
		int k = st_to_vec[axis][j];
		if (k < 0) {
			v[j] = -b[-k - 1];
		} else {
			v[j] = b[k - 1];
		}
	}

	/* avoid bilerp seam */
	s = (s + 1) * 0.5;
	t = (t + 1) * 0.5;

	if (s < _sky_min) {
		s = _sky_min;
	} else if (s > _sky_max) {
		s = _sky_max;
	}

	if (t < _sky_min) {
		t = _sky_min;
	} else if (t > _sky_max) {
		t = _sky_max;
	}

	t = 1.0 - t;


  vert.setAll(offset, v);
  vert[offset + gl3_3D_vtx_texCoord_offset] = s;
  vert[offset + gl3_3D_vtx_texCoord_offset + 1] = t;
  vert[offset + gl3_3D_vtx_lmTexCoord_offset] = 0;
  vert[offset + gl3_3D_vtx_lmTexCoord_offset + 1] = 0;
}

WebGL_DrawSkyBox() {
	if (_skyrotate != 0) {   /* check for no sky at all */
    int i;
		for (i = 0; i < 6; i++) {
			if ((_skymins[0][i] < _skymaxs[0][i]) &&
			    (_skymins[1][i] < _skymaxs[1][i])) {
				break;
			}
		}

		if (i == 6) {
			return; /* nothing visible */
		}
	}

	// glPushMatrix();
	final origModelMat = glstate.uni3DData.transModelMat4;

	// glTranslatef(gl3_origin[0], gl3_origin[1], gl3_origin[2]);
	final transl = Float32List.fromList(webgl_origin);
	var modMVmat = HMM_MultiplyMat4(origModelMat, HMM_Translate(transl));
	if (_skyrotate != 0.0) {
		// glRotatef(gl3_newrefdef.time * skyrotate, skyaxis[0], skyaxis[1], skyaxis[2]);
		final rotAxis = Float32List.fromList(_skyaxis);
		modMVmat = HMM_MultiplyMat4(modMVmat, HMM_Rotate(webgl_newrefdef.time * _skyrotate, rotAxis));
	}
	glstate.uni3DData.transModelMat4 = modMVmat;
	WebGL_UpdateUBO3D();

	WebGL_UseProgram(glstate.si3Dsky.shaderProgram);
	WebGL_BindVAO(glstate.vao3D);
	WebGL_BindVBO(glstate.vbo3D);

	// TODO: this could all be done in one drawcall.. but.. whatever, it's <= 6 drawcalls/frame

	// gl3_3D_vtx_t skyVertices[4];
  Float32List skyVertices = Float32List(4 * gl3_3D_vtx_size);

	for (int i = 0; i < 6; i++) {
		if (_skyrotate != 0.0) {
			_skymins[0][i] = -1;
			_skymins[1][i] = -1;
			_skymaxs[0][i] = 1;
			_skymaxs[1][i] = 1;
		}

		if ((_skymins[0][i] >= _skymaxs[0][i]) ||
		    (_skymins[1][i] >= _skymaxs[1][i])) {
			continue;
		}

		WebGL_Bind(_sky_images[_skytexorder[i]].texture);

		_MakeSkyVec( _skymins [ 0 ] [ i ], _skymins [ 1 ] [ i ], i, skyVertices, 0 * gl3_3D_vtx_size);
		_MakeSkyVec( _skymins [ 0 ] [ i ], _skymaxs [ 1 ] [ i ], i, skyVertices, 1 * gl3_3D_vtx_size);
		_MakeSkyVec( _skymaxs [ 0 ] [ i ], _skymaxs [ 1 ] [ i ], i, skyVertices, 2 * gl3_3D_vtx_size);
		_MakeSkyVec( _skymaxs [ 0 ] [ i ], _skymins [ 1 ] [ i ], i, skyVertices, 3 * gl3_3D_vtx_size);

		WebGL_BufferAndDraw3D(skyVertices, 4, WebGL.TRIANGLE_FAN);
	}

	// glPopMatrix();
	glstate.uni3DData.transModelMat4 = origModelMat;
	WebGL_UpdateUBO3D();
}
