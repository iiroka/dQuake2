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
 * Lightmap handling
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'dart:web_gl';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/client/vid/ref.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'webgl_model.dart';
import 'webgl_image.dart';
import 'webgl_light.dart';
import 'local.dart';

const _TEXNUM_LIGHTMAPS = 1024;

WebGL_LM_InitBlock() {
	webgl_lms.allocated.fillRange(0, BLOCK_WIDTH, 0);
}

WebGL_LM_UploadBlock() {

	// NOTE: we don't use the dynamic lightmap anymore - all lightmaps are loaded at level load
	//       and not changed after that. they're blended dynamically depending on light styles
	//       though, and dynamic lights are (will be) applied in shader, hopefully per fragment.

	WebGL_BindLightmap(webgl_lms.current_lightmap_texture);

	// upload all 4 lightmaps
	for(int map=0; map < MAX_LIGHTMAPS_PER_SURFACE; ++map) {
		WebGL_SelectTMU(WebGL.TEXTURE1+map); // this relies on GL_TEXTURE2 being GL_TEXTURE1+1 etc
		gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, WebGL.LINEAR);
		gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, WebGL.LINEAR);

		webgl_lms.internal_format = WebGL.RGBA;
		gl.texImage2D(WebGL.TEXTURE_2D, 0, webgl_lms.internal_format,
		             BLOCK_WIDTH, BLOCK_HEIGHT, 0, WebGL.RGBA,
		             WebGL.UNSIGNED_BYTE, webgl_lms.lightmap_buffers[map]);
	}

	if (++webgl_lms.current_lightmap_texture == MAX_LIGHTMAPS) {
		Com_Error(ERR_DROP, "LM_UploadBlock() - MAX_LIGHTMAPS exceeded\n");
	}
}

/*
 * returns a texture number and the position inside it
 */
List<int> WebGL_LM_AllocBlock(int w, int h) {

	int best = BLOCK_HEIGHT;
  int x, y;

	for (int i = 0; i < BLOCK_WIDTH - w; i++) {
		int best2 = 0;
    int j;

		for (j = 0; j < w; j++)
		{
			if (webgl_lms.allocated[i + j] >= best) {
				break;
			}

			if (webgl_lms.allocated[i + j] > best2) {
				best2 = webgl_lms.allocated[i + j];
			}
		}

		if (j == w) {
			/* this is a valid spot */
			x = i;
			y = best = best2;
		}
	}

	if (best + h > BLOCK_HEIGHT) {
		return null;
	}

	for (int i = 0; i < w; i++) {
		webgl_lms.allocated[x + i] = best + h;
	}

	return [x, y];
}

WebGL_LM_BuildPolygonFromSurface(msurface_t fa) {

	/* reconstruct the polygon */
  final model = (currentmodel as webglbrushmodel_t);
	List<medge_t> pedges = model.edges;
	int lnumverts = fa.numedges;

  List<double> total = [0,0,0];

	/* draw texture */
  glpoly_t poly = glpoly_t();
	poly.next = fa.polys;
	poly.flags = fa.flags;
	fa.polys = poly;
	poly.numverts = lnumverts;

  List<double> normal = List.generate(3, (i) => fa.plane.normal[i]);

	if ((fa.flags & SURF_PLANEBACK) != 0) {
		// if for some reason the normal sticks to the back of the plane, invert it
		// so it's usable for the shader
		for (int i=0; i<3; ++i) {
      normal[i] = -normal[i];
    }
	}

  List<double> data = [];
	for (int i = 0; i < lnumverts; i++) {
    gl3_3D_vtx_t vert = gl3_3D_vtx_t();

		int lindex = model.surfedges[fa.firstedge + i];

    List<double> vec;
		if (lindex > 0) {
			final r_pedge = pedges[lindex];
			vec = model.vertexes[r_pedge.v[0]].position;
		} else {
			final r_pedge = pedges[-lindex];
			vec = model.vertexes[r_pedge.v[1]].position;
		}

		double s = DotProduct(vec, fa.texinfo.vecs[0]) + fa.texinfo.vecs[0][3];
		s /= fa.texinfo.image.width;

		double t = DotProduct(vec, fa.texinfo.vecs[1]) + fa.texinfo.vecs[1][3];
		t /= fa.texinfo.image.height;

		VectorAdd(total, vec, total);
    vert.pos = Float32List.fromList(vec);
    vert.texCoord = Float32List.fromList([s, t]);

		/* lightmap texture coordinates */
		s = DotProduct(vec, fa.texinfo.vecs[0]) + fa.texinfo.vecs[0][3];
		s -= fa.texturemins[0];
		s += fa.light_s * 16;
		s += 8;
		s /= BLOCK_WIDTH * 16; /* fa->texinfo->texture->width; */

		t = DotProduct(vec, fa.texinfo.vecs[1]) + fa.texinfo.vecs[1][3];
		t -= fa.texturemins[1];
		t += fa.light_t * 16;
		t += 8;
		t /= BLOCK_HEIGHT * 16; /* fa->texinfo->texture->height; */

    vert.lmTexCoord = Float32List.fromList([s, t]);

    vert.normal = Float32List.fromList(normal);
		vert.lightFlags = 0;

    data.addAll(vert.data);
	}

	poly.numverts = lnumverts;
  poly.data = Float32List.fromList(data);
}

WebGL_LM_CreateSurfaceLightmap(msurface_t surf) {

	if ((surf.flags & (SURF_DRAWSKY | SURF_DRAWTURB)) != 0) {
		return;
	}

	int smax = (surf.extents[0] >> 4) + 1;
	int tmax = (surf.extents[1] >> 4) + 1;

  var r = WebGL_LM_AllocBlock(smax, tmax);
	if (r == null) {
		WebGL_LM_UploadBlock();
		WebGL_LM_InitBlock();

    r = WebGL_LM_AllocBlock(smax, tmax);
		if (r == null) {
			Com_Error(ERR_FATAL, "Consecutive calls to LM_AllocBlock($smax,$tmax) failed\n");
		}
  }
  surf.light_s = r[0];
  surf.light_t = r[1];

	surf.lightmaptexturenum = webgl_lms.current_lightmap_texture;

	WebGL_BuildLightMap(surf, (surf.light_t * BLOCK_WIDTH + surf.light_s) * LIGHTMAP_BYTES, BLOCK_WIDTH * LIGHTMAP_BYTES);
}

WebGL_LM_BeginBuildingLightmaps(webglmodel_t m) {

	webgl_lms.allocated.fillRange(0, BLOCK_WIDTH, 0);

	webgl_framecount = 1; /* no dlightcache */

	/* setup the base lightstyles so the lightmaps
	   won't have to be regenerated the first time
	   they're seen */
  final lightstyles = List.generate(MAX_LIGHTSTYLES, (i) => lightstyle_t());
	for (int i = 0; i < MAX_LIGHTSTYLES; i++) {
		lightstyles[i].rgb[0] = 1;
		lightstyles[i].rgb[1] = 1;
		lightstyles[i].rgb[2] = 1;
		lightstyles[i].white = 3;
	}

	webgl_newrefdef.lightstyles = lightstyles;

	webgl_lms.current_lightmap_texture = 0;
	webgl_lms.internal_format = WebGL.RGBA;

	// Note: the dynamic lightmap used to be initialized here, we don't use that anymore.
}

WebGL_LM_EndBuildingLightmaps() => WebGL_LM_UploadBlock();
