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

const DLIGHT_CUTOFF = 64;
int r_dlightframecount = 0;

// bit: 1 << i for light number i, will be or'ed into msurface_t::dlightbits if surface is affected by this light
WebGL_MarkLights(dlight_t light, int bit, mleadornode_t anode) {

	if (anode.contents != -1) {
		return;
	}

  var node = anode as mnode_t;
	var splitplane = node.plane;
	double dist = DotProduct(light.origin, splitplane.normal) - splitplane.dist;

	if (dist > light.intensity - DLIGHT_CUTOFF) {
		WebGL_MarkLights(light, bit, node.children[0]);
		return;
	}

	if (dist < -light.intensity + DLIGHT_CUTOFF) {
		WebGL_MarkLights(light, bit, node.children[1]);
		return;
	}

	/* mark the polygons */

	for (int i = 0; i < node.numsurfaces; i++)
	{
	  var surf = webgl_worldmodel.surfaces[node.firstsurface = i];
		if (surf.dlightframe != r_dlightframecount) {
			surf.dlightbits = 0;
			surf.dlightframe = r_dlightframecount;
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
	// int i;
	// dlight_t *l;

	/* because the count hasn't advanced yet for this frame */
	r_dlightframecount = webgl_framecount + 1;


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

