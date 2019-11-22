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
 * Lightmaps and dynamic lighting
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/client/vid/ref.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'local.dart';
import 'webgl_model.dart';
import 'webgl_shaders.dart';

const _DLIGHT_CUTOFF = 64;
int _r_dlightframecount = 0;
List<double> _pointcolor = [0,0,0];
cplane_t _lightplane = null;
List<double> lightspot = [0,0,0];

// bit: 1 << i for light number i, will be or'ed into msurface_t::dlightbits if surface is affected by this light
WebGL_MarkLights(dlight_t light, int bit, mleafornode_t anode) {

	if (anode.contents != -1) {
		return;
	}

  var node = anode as mnode_t;
	var splitplane = node.plane;
	double dist = DotProduct(light.origin, splitplane.normal) - splitplane.dist;

	if (dist > light.intensity - _DLIGHT_CUTOFF) {
		WebGL_MarkLights(light, bit, node.children[0]);
		return;
	}

	if (dist < -light.intensity + _DLIGHT_CUTOFF) {
		WebGL_MarkLights(light, bit, node.children[1]);
		return;
	}

	/* mark the polygons */

	for (int i = 0; i < node.numsurfaces; i++)
	{
	  var surf = webgl_worldmodel.surfaces[node.firstsurface = i];
		if (surf.dlightframe != _r_dlightframecount) {
			surf.dlightbits = 0;
			surf.dlightframe = _r_dlightframecount;
		}

		dist = DotProduct(light.origin, surf.plane.normal) - surf.plane.dist;

    int sidebit;
		if (dist >= 0) {
			sidebit = 0;
		} else {
			sidebit = SURF_PLANEBACK;
		}

		if ((surf.flags & SURF_PLANEBACK) != sidebit) {
			continue;
		}

		surf.dlightbits |= bit;
	}

	WebGL_MarkLights(light, bit, node.children[0]);
	WebGL_MarkLights(light, bit, node.children[1]);
}

WebGL_PushDlights() {

	/* because the count hasn't advanced yet for this frame */
	_r_dlightframecount = webgl_framecount + 1;


	glstate.uniLightsData.numDynLights = webgl_newrefdef.dlights.length;

  int i;
	for (i = 0; i < webgl_newrefdef.dlights.length; i++) {
	  var l = webgl_newrefdef.dlights[i];
    gl3UniDynLight udl = gl3UniDynLight();
		// gl3UniDynLight* udl = &glstate.uniLightsData.dynLights[i];
		WebGL_MarkLights(l, 1 << i, webgl_worldmodel.nodes[0]);

    udl.origin = l.origin;
    udl.color = l.color;
    udl.intensity = l.intensity;
    glstate.uniLightsData.setDynLight(i, udl);
	}

	// assert(MAX_DLIGHTS == 32 && "If MAX_DLIGHTS changes, remember to adjust the uniform buffer definition in the shader!");

  gl3UniDynLight udl = gl3UniDynLight();
	if(i < MAX_DLIGHTS) {
    glstate.uniLightsData.setDynLight(i, udl);
	}

	WebGL_UpdateUBOLights();
}

int _RecursiveLightPoint(mleafornode_t anode, List<double> start, List<double> end) {

	if (anode.contents != -1) {
		return -1;     /* didn't hit anything */
	}

  final node = anode as mnode_t;
	/* calculate mid point */
	var plane = node.plane;
	double front = DotProduct(start, plane.normal) - plane.dist;
	double back = DotProduct(end, plane.normal) - plane.dist;
	int side = (front < 0) ? 1 : 0;

	if ((back < 0) == (front < 0)) {
		return _RecursiveLightPoint(node.children[side], start, end);
	}

	double frac = front / (front - back);
  List<double> mid = List.generate(3, (i) => start[i] + (end[i] - start[i]) * frac);

	/* go down front side */
	int r = _RecursiveLightPoint(node.children[side], start, mid);
	if (r >= 0) {
		return r;     /* hit something */
	}

	if ((back < 0) == side)
	{
		return -1;     /* didn't hit anuthing */
	}

	/* check for impact on this node */
  lightspot.setAll(0, mid);
	_lightplane = plane;


	for (int i = 0; i < node.numsurfaces; i++) {
  	var surf = webgl_worldmodel.surfaces[node.firstsurface + i];
		if ((surf.flags & (SURF_DRAWTURB | SURF_DRAWSKY)) != 0) {
			continue; /* no lightmaps */
		}

		var tex = surf.texinfo;

		int s = (DotProduct(mid, tex.vecs[0]) + tex.vecs[0][3]).toInt();
		int t = (DotProduct(mid, tex.vecs[1]) + tex.vecs[1][3]).toInt();

		if ((s < surf.texturemins[0]) ||
			(t < surf.texturemins[1]))
		{
			continue;
		}

		int ds = s - surf.texturemins[0];
		int dt = t - surf.texturemins[1];

		if ((ds > surf.extents[0]) || (dt > surf.extents[1])) {
			continue;
		}

		if (surf.samples == null) {
			return 0;
		}

		ds >>= 4;
		dt >>= 4;

		var lightmap = surf.samples;
    var lightmap_i = 0;
    _pointcolor.setAll(0, [0,0,0]);

		if (lightmap != null) {
			List<double> scale = [0,0,0];

			lightmap_i += 3 * (dt * ((surf.extents[0] >> 4) + 1) + ds);

			for (int maps = 0; maps < MAX_LIGHTMAPS_PER_SURFACE && surf.styles[maps] != 255; maps++) {
				for (int j = 0; j < 3; j++) {
					scale[j] = r_modulate.value *
							   webgl_newrefdef.lightstyles[surf.styles[maps]].rgb[j];
				}

				_pointcolor[0] += lightmap[lightmap_i + 0] * scale[0] * (1.0 / 255);
				_pointcolor[1] += lightmap[lightmap_i + 1] * scale[1] * (1.0 / 255);
				_pointcolor[2] += lightmap[lightmap_i + 2] * scale[2] * (1.0 / 255);
				lightmap_i += 3 * ((surf.extents[0] >> 4) + 1) * ((surf.extents[1] >> 4) + 1);
			}
		}

		return 1;
	}

	/* go down back side */
	return _RecursiveLightPoint(node.children[side ^ 1], mid, end);
}


WebGL_LightPoint(List<double> p, List<double> color) {

	if (webgl_worldmodel.lightdata == null || currententity == null) {
		color[0] = color[1] = color[2] = 1.0;
		return;
	}

  List<double> end = [p[0], p[1], p[2] - 2048];

	// TODO: don't just aggregate the color, but also save position of brightest+nearest light
	//       for shadow position and maybe lighting on model?

	int r = _RecursiveLightPoint(webgl_worldmodel.nodes[0], p, end);
	if (r == -1) {
    color.setAll(0, [0,0,0]);
	} else {
    color.setAll(0, _pointcolor);
	}

	/* add dynamic lights */
  List<double> dist = [0,0,0];
	for (var dl in webgl_newrefdef.dlights) {
	  VectorSubtract(currententity.origin, dl.origin, dist);
		double add = dl.intensity - VectorLength(dist);
		add *= (1.0 / 256.0);

		if (add > 0) {
			VectorMA(color, add, dl.color, color);
		}
	}

	VectorScale(color, r_modulate.value, color);
}


/*
 * Combine and scale multiple lightmaps into the floating format in blocklights
 */
WebGL_BuildLightMap(msurface_t surf, int offsetInLMbuf, int stride) {

	if ((surf.texinfo.flags &
		(SURF_SKY | SURF_TRANS33 | SURF_TRANS66 | SURF_WARP)) != 0) {
		Com_Error(ERR_DROP, "GL3_BuildLightMap called for non-lit surface");
	}

	int smax = (surf.extents[0] >> 4) + 1;
	int tmax = (surf.extents[1] >> 4) + 1;
	int size = smax * tmax;

	stride -= (smax << 2);

	if (size > 34*34*3) {
		Com_Error(ERR_DROP, "Bad s_blocklights size");
	}

	// count number of lightmaps surf actually has
  int numMaps;
	for (numMaps = 0; numMaps < MAX_LIGHTMAPS_PER_SURFACE && surf.styles[numMaps] != 255; ++numMaps)
	{}

	if (surf.samples == null) {
		// no lightmap samples? set at least one lightmap to fullbright, rest to 0 as normal

		if (numMaps == 0)  numMaps = 1; // make sure at least one lightmap is set to fullbright

		for (int map = 0; map < MAX_LIGHTMAPS_PER_SURFACE; ++map) {
			// we always create 4 (MAX_LIGHTMAPS_PER_SURFACE) lightmaps.
			// if surf has less (numMaps < 4), the remaining ones are zeroed out.
			// this makes sure that all 4 lightmap textures in gl3state.lightmap_textureIDs[i] have the same layout
			// and the shader can use the same texture coordinates for all of them

			int c = (map < numMaps) ? 255 : 0;
      int dest = offsetInLMbuf;
			for (int i = 0; i < tmax; i++, dest += stride) {
        webgl_lms.lightmap_buffers[map].fillRange(dest, dest + 4 * smax, c);
				dest += 4*smax;
			}
		}

		return;
	}

	/* add all the lightmaps */

	// Note: dynamic lights aren't handled here anymore, they're handled in the shader

	// as we don't apply scale here anymore, nor blend the numMaps lightmaps together,
	// the code has gotten a lot easier and we can copy directly from surf->samples to dest
	// without converting to float first etc

	Uint8List lightmap = surf.samples;
  int max = 0;
  int map;

	for(map=0; map<numMaps; ++map) {
    int idxInLightmap = 0;
    int dest = offsetInLMbuf;
		for (int i = 0; i < tmax; i++, dest += stride) {
			for (int j = 0; j < smax; j++) {
				int r = lightmap[idxInLightmap * 3 + 0];
				int g = lightmap[idxInLightmap * 3 + 1];
				int b = lightmap[idxInLightmap * 3 + 2];

				/* determine the brightest of the three color components */
				if (r > g)  {
          max = r;
        } else {
          max = g;
        }

				if (b > max) {
          max = b;
        }

				/* alpha is ONLY used for the mono lightmap case. For this
				   reason we set it to the brightest of the color components
				   so that things don't get too dim. */
				int a = max;

				webgl_lms.lightmap_buffers[map][dest + 0] = r;
				webgl_lms.lightmap_buffers[map][dest + 1] = g;
				webgl_lms.lightmap_buffers[map][dest + 2] = b;
				webgl_lms.lightmap_buffers[map][dest + 3] = a;

				dest += 4;
				++idxInLightmap;
			}
		}

		idxInLightmap += size * 3; /* skip to next lightmap */
	}

	for ( ; map < MAX_LIGHTMAPS_PER_SURFACE; ++map)
	{
		// like above, fill up remaining lightmaps with 0
    int dest = offsetInLMbuf;
		for (int i = 0; i < tmax; i++, dest += stride) {
        webgl_lms.lightmap_buffers[map].fillRange(dest, dest + 4 * smax, 0);
				dest += 4*smax;
		}
	}
}

