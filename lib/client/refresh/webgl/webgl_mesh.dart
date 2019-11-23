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
 * Mesh handling
 *
 * =======================================================================
 */
import 'dart:math';
import 'dart:web_gl';
import 'dart:typed_data';
import 'package:dQuakeWeb/client/refresh/webgl/webgl_model.dart';
import 'package:dQuakeWeb/client/vid/ref.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'local.dart';
import 'webgl_main.dart';
import 'webgl_image.dart';
import 'webgl_light.dart';
import 'webgl_misc.dart';
import 'webgl_shaders.dart';

const _SHADEDOT_QUANT = 16;

List<List<double>> _s_lerped = List.generate(MAX_VERTS, (i) => [0,0,0,0]);

_LerpVerts(bool powerUpEffect, int nverts, List<dtrivertx_t> v, List<dtrivertx_t> ov,
		List<dtrivertx_t> verts, List<List<double>> lerp, List<double> move,
		List<double> frontv, List<double> backv)
{
	if (powerUpEffect) {
		for (int i = 0; i < nverts; i++) {
			final normal = r_avertexnormals[verts[i].lightnormalindex];
			lerp[i][0] = move[0] + ov[i].v[0] * backv[0] + v[i].v[0] * frontv[0] + normal[0] * POWERSUIT_SCALE;
			lerp[i][1] = move[1] + ov[i].v[1] * backv[1] + v[i].v[1] * frontv[1] + normal[1] * POWERSUIT_SCALE;
			lerp[i][2] = move[2] + ov[i].v[2] * backv[2] + v[i].v[2] * frontv[2] + normal[2] * POWERSUIT_SCALE;
		}
	} else {
		for (int i = 0; i < nverts; i++) {
			lerp[i][0] = move[0] + ov[i].v[0] * backv[0] + v[i].v[0] * frontv[0];
			lerp[i][1] = move[1] + ov[i].v[1] * backv[1] + v[i].v[1] * frontv[1];
			lerp[i][2] = move[2] + ov[i].v[2] * backv[2] + v[i].v[2] * frontv[2];
		}
	}
}


/*
 * Interpolates between two frames and origins
 */
_DrawAliasFrameLerp(webglaliasmodel_t model, entity_t entity, List<double> shadelight) {
	final backlerp = entity.backlerp;
	final frontlerp = 1.0 - backlerp;

	// draw without texture? used for quad damage effect etc, I think
	final colorOnly = 0 != (entity.flags &
			(RF_SHELL_RED | RF_SHELL_GREEN | RF_SHELL_BLUE | RF_SHELL_DOUBLE |
			 RF_SHELL_HALF_DAM));

	// TODO: maybe we could somehow store the non-rotated normal and do the dot in shader?
	final shadedots = r_avertexnormal_dots[(entity.angles[1] * (_SHADEDOT_QUANT / 360.0)).toInt() & (_SHADEDOT_QUANT - 1)];

	final frame = model.frames[entity.frame];
	final verts = frame.verts;

	final oldframe = model.frames[entity.oldframe];
	final ov = oldframe.verts;

	// order = (int *)((byte *)paliashdr + paliashdr->ofs_glcmds);
  double alpha = 1;
	if ((entity.flags & RF_TRANSLUCENT) != 0) {
		alpha = entity.alpha * 0.666;
	}

	if (colorOnly) {
		WebGL_UseProgram(glstate.si3DaliasColor.shaderProgram);
	} else {
		WebGL_UseProgram(glstate.si3Dalias.shaderProgram);
	}

	/* move should be the delta back to the previous frame * backlerp */
  List<double> delta = [0,0,0];
	VectorSubtract(entity.oldorigin, entity.origin, delta);
  List<List<double>> vectors = List.generate(3, (i) => [0,0,0]);
	AngleVectors(entity.angles, vectors[0], vectors[1], vectors[2]);

  List<double> move = [0,0,0];
	move[0] = DotProduct(delta, vectors[0]); /* forward */
	move[1] = -DotProduct(delta, vectors[1]); /* left */
	move[2] = DotProduct(delta, vectors[2]); /* up */

	VectorAdd(move, oldframe.translate, move);

  List<double> frontv = [0,0,0];
  List<double> backv = [0,0,0];
	for (int i = 0; i < 3; i++) {
		move[i] = backlerp * move[i] + frontlerp * frame.translate[i];

		frontv[i] = frontlerp * frame.scale[i];
		backv[i] = backlerp * oldframe.scale[i];
	}

	// lerp = s_lerped[0];

	_LerpVerts(colorOnly, model.header.num_xyz, verts, ov, verts, _s_lerped, move, frontv, backv);

	// assert(sizeof(gl3_alias_vtx_t) == 9*sizeof(GLfloat));

	// all the triangle fans and triangle strips of this model will be converted to
	// just triangles: the vertices stay the same and are batched in vtxBuf,
	// but idxBuf will contain indices to draw them all as GL_TRIANGLE
	// this way there's only one draw call (and two glBufferData() calls)
	// instead of (at least) dozens. *greatly* improves performance.

	// so first clear out the data from last call to this function
	// (the buffers are static global so we don't have malloc()/free() for each rendered model)
  List<double> vtxBuf = [];
  List<int> idxBuf = [];

  int order = 0;
	while (true)
	{
		// GLushort nextVtxIdx = da_count(vtxBuf);
    int nextVtxIdx = vtxBuf.length ~/ 9;

		/* get the vertex count and primitive type */
		int count = model.cmds.getInt32(order, Endian.little);
    order += 4;
		if (count == 0) {
			break; /* done */
		}

    var type = WebGL.TRIANGLE_STRIP;
		if (count < 0) {
			count = -count;
			type = WebGL.TRIANGLE_FAN;
		}

		// gl3_alias_vtx_t* buf = da_addn_uninit(vtxBuf, count);

		if (colorOnly) {

			for(int i=0; i<count; ++i) {
				int index_xyz = model.cmds.getInt32(order + 2 * 4, Endian.little);
				order += 3 * 4;
        gl3_alias_vtx_t cur = gl3_alias_vtx_t();

        cur.pos = Float32List.fromList(_s_lerped[index_xyz]);
        List<double> color = [0,0,0,0];
				for(int j=0; j<3; ++j) {
					color[j] = shadelight[j];
				}
				color[3] = alpha;
        cur.color = Float32List.fromList(color);
        vtxBuf.addAll(cur.data);
			}

		} else {

			for(int i=0; i<count; ++i) {
        gl3_alias_vtx_t cur = gl3_alias_vtx_t();
				/* texture coordinates come from the draw list */
				cur.texCoord = Float32List.fromList([ 
          model.cmds.getFloat32(order + 0 * 4, Endian.little),
          model.cmds.getFloat32(order + 1 * 4, Endian.little) ]);
				int index_xyz = model.cmds.getInt32(order + 2 * 4, Endian.little);
				order += 3 * 4;

				/* normals and vertexes come from the frame list */
				// shadedots is set above according to rotation (around Z axis I think)
				// to one of 16 (SHADEDOT_QUANT) presets in r_avertexnormal_dots
				final l = shadedots[verts[index_xyz].lightnormalindex];

        cur.pos = Float32List.fromList(_s_lerped[index_xyz]);
        List<double> color = [0,0,0,0];
				for(int j=0; j<3; ++j) {
					color[j] = l * shadelight[j];
				}
				color[3] = alpha;
        cur.color = Float32List.fromList(color);
        vtxBuf.addAll(cur.data);
			}
		}

		// translate triangle fan/strip to just triangle indices
		if(type == WebGL.TRIANGLE_FAN) {
			for(int i=1; i < count-1; ++i) {
				idxBuf.add(nextVtxIdx);
				idxBuf.add(nextVtxIdx+i);
				idxBuf.add(nextVtxIdx+i+1);
			}
		}
		else // triangle strip
		{
      int i;
			for(i=1; i < count-2; i+=2) {
				// add two triangles at once, because the vertex order is different
				// for odd vs even triangles
				idxBuf.add(nextVtxIdx + i-1);
				idxBuf.add(nextVtxIdx + i);
				idxBuf.add(nextVtxIdx + i+1);

				idxBuf.add(nextVtxIdx + i);
				idxBuf.add(nextVtxIdx + i+2);
				idxBuf.add(nextVtxIdx + i+1);
			}
			// add remaining triangle, if any
			if(i < count-1) {
				idxBuf.add(nextVtxIdx + i-1);
				idxBuf.add(nextVtxIdx + i);
				idxBuf.add(nextVtxIdx + i+1);
			}
		}
	}

	WebGL_BindVAO(glstate.vaoAlias);
	WebGL_BindVBO(glstate.vboAlias);

	gl.bufferData(WebGL.ARRAY_BUFFER, Float32List.fromList(vtxBuf), WebGL.STREAM_DRAW);
	WebGL_BindEBO(glstate.eboAlias);
	gl.bufferData(WebGL.ELEMENT_ARRAY_BUFFER, Int16List.fromList(idxBuf), WebGL.STREAM_DRAW);
	gl.drawElements(WebGL.TRIANGLES, idxBuf.length, WebGL.UNSIGNED_SHORT, null);
}

bool _CullAliasModel(List<List<double>> bbox, entity_t e) {

	final model = e.model as webglaliasmodel_t;

	final paliashdr = model.header;

	if ((e.frame >= paliashdr.num_frames) || (e.frame < 0)) {
		Com_DPrintf( "R_CullAliasModel ${model.name}: no such frame ${e.frame}\n");
		e.frame = 0;
	}

	if ((e.oldframe >= paliashdr.num_frames) || (e.oldframe < 0)) {
		Com_DPrintf( "R_CullAliasModel ${model.name}: no such oldframe ${e.oldframe}\n");
		e.oldframe = 0;
	}

	final pframe = model.frames[e.frame];
	final poldframe = model.frames[e.oldframe];

	/* compute axially aligned mins and maxs */
  List<double> mins = [0,0,0];
  List<double> maxs = [0,0,0];
	if (pframe == poldframe) {
		for (int i = 0; i < 3; i++) {
			mins[i] = pframe.translate[i];
			maxs[i] = mins[i] + pframe.scale[i] * 255;
		}
	}
	else
	{
    List<double> thismins = [0,0,0];
    List<double> thismaxs = [0,0,0];
    List<double> oldmins = [0,0,0];
    List<double> oldmaxs = [0,0,0];

		for (int i = 0; i < 3; i++) {
			thismins[i] = pframe.translate[i];
			thismaxs[i] = thismins[i] + pframe.scale[i] * 255;

			oldmins[i] = poldframe.translate[i];
			oldmaxs[i] = oldmins[i] + poldframe.scale[i] * 255;

			if (thismins[i] < oldmins[i]) {
				mins[i] = thismins[i];
			}
			else
			{
				mins[i] = oldmins[i];
			}

			if (thismaxs[i] > oldmaxs[i]) {
				maxs[i] = thismaxs[i];
			}
			else
			{
				maxs[i] = oldmaxs[i];
			}
		}
	}

	/* compute a full bounding box */
	for (int i = 0; i < 8; i++) {
    List<double> tmp = [0,0,0];

		if ((i & 1) != 0)
		{
			tmp[0] = mins[0];
		}
		else
		{
			tmp[0] = maxs[0];
		}

		if ((i & 2) != 0)
		{
			tmp[1] = mins[1];
		}
		else
		{
			tmp[1] = maxs[1];
		}

		if ((i & 4) != 0)
		{
			tmp[2] = mins[2];
		}
		else
		{
			tmp[2] = maxs[2];
		}

    bbox[i].setAll(0, tmp);
	}

	/* rotate the bounding box */
  List<double> angles = List.generate(3, (i) => e.angles[i]);
	angles[YAW] = -angles[YAW];
  List<List<double>> vectors = List.generate(3, (i) => [0,0,0]);
	AngleVectors(angles, vectors[0], vectors[1], vectors[2]);

	for (int i = 0; i < 8; i++) {
    List<double> tmp = [0,0,0];

    tmp.setAll(0, bbox[i]);

		bbox[i][0] = DotProduct(vectors[0], tmp);
		bbox[i][1] = -DotProduct(vectors[1], tmp);
		bbox[i][2] = DotProduct(vectors[2], tmp);

		VectorAdd(e.origin, bbox[i], bbox[i]);
	}

	int p, f, aggregatemask = ~0;

	for (p = 0; p < 8; p++)
	{
		int mask = 0;

		for (f = 0; f < 4; f++) {
			double dp = DotProduct(frustum[f].normal, bbox[p]);

			if ((dp - frustum[f].dist) < 0)
			{
				mask |= (1 << f);
			}
		}

		aggregatemask &= mask;
	}

	if (aggregatemask != 0)
	{
		return true;
	}

	return false;
}

WebGL_DrawAliasModel(entity_t entity) {

  List<List<double>> bbox = List.generate(8, (i) => [0,0,0]);

	if ((entity.flags & RF_WEAPONMODEL) == 0) {
		if (_CullAliasModel(bbox, entity)) {
			return;
		}
	}

	if ((entity.flags & RF_WEAPONMODEL) != 0) {
		if (gl_lefthand.integer == 2) {
			return;
		}
	}

	var model = entity.model as webglaliasmodel_t;
	final paliashdr = model.header;
  List<double> shadelight = [0,0,0];

	/* get lighting information */
	if ((entity.flags &
		(RF_SHELL_HALF_DAM | RF_SHELL_GREEN | RF_SHELL_RED |
		 RF_SHELL_BLUE | RF_SHELL_DOUBLE)) != 0) {

		if ((entity.flags & RF_SHELL_HALF_DAM) != 0) {
			shadelight[0] = 0.56;
			shadelight[1] = 0.59;
			shadelight[2] = 0.45;
		}

		if ((entity.flags & RF_SHELL_DOUBLE) != 0) {
			shadelight[0] = 0.9;
			shadelight[1] = 0.7;
		}

		if ((entity.flags & RF_SHELL_RED) != 0) {
			shadelight[0] = 1.0;
		}

		if ((entity.flags & RF_SHELL_GREEN) != 0) {
			shadelight[1] = 1.0;
		}

		if ((entity.flags & RF_SHELL_BLUE) != 0) {
			shadelight[2] = 1.0;
		}
	}
	else if ((entity.flags & RF_FULLBRIGHT) != 0) {
		for (int i = 0; i < 3; i++) {
			shadelight[i] = 1.0;
		}
	}
	else
	{
		WebGL_LightPoint(entity.origin, shadelight);

		/* player lighting hack for communication back to server */
		if ((entity.flags & RF_WEAPONMODEL) != 0) {
			/* pick the greatest component, which should be
			   the same as the mono value returned by software */
			if (shadelight[0] > shadelight[1]) {
				if (shadelight[0] > shadelight[2]) {
					r_lightlevel.string = (150 * shadelight[0]).toString();
				} else {
					r_lightlevel.string = (150 * shadelight[2]).toString();
				}
			} else {
				if (shadelight[1] > shadelight[2]) {
					r_lightlevel.string = (150 * shadelight[1]).toString();
				} else {
					r_lightlevel.string = (150 * shadelight[2]).toString();
				}
			}
		}
	}

	if ((entity.flags & RF_MINLIGHT) != 0) {
    int i;
		for (i = 0; i < 3; i++) {
			if (shadelight[i] > 0.1) {
				break;
			}
		}

		if (i == 3) {
			shadelight[0] = 0.1;
			shadelight[1] = 0.1;
			shadelight[2] = 0.1;
		}
	}

	if ((entity.flags & RF_GLOW) != 0) {
		/* bonus items will pulse with time */

		var scale = 0.1 * sin(webgl_newrefdef.time * 7);

		for (int i = 0; i < 3; i++)
		{
			var min = shadelight[i] * 0.8;
			shadelight[i] += scale;

			if (shadelight[i] < min)
			{
				shadelight[i] = min;
			}
		}
	}

	// Note: gl_overbrightbits are now applied in shader.

	/* ir goggles color override */
	if ((webgl_newrefdef.rdflags & RDF_IRGOGGLES) != 0 && (entity.flags & RF_IR_VISIBLE) != 0) {
		shadelight[0] = 1.0;
		shadelight[1] = 0.0;
		shadelight[2] = 0.0;
	}

  List<double> shadevector = [0,0,0];
	var an = entity.angles[1] / 180 * pi;
	shadevector[0] = cos(-an);
	shadevector[1] = sin(-an);
	shadevector[2] = 1;
	VectorNormalize(shadevector);

	/* locate the proper data */
	c_alias_polys += paliashdr.num_tris;

	/* draw all the triangles */
	if ((entity.flags & RF_DEPTHHACK) != 0) {
		/* hack the depth range to prevent view model from poking into walls */
		gl.depthRange(webgldepthmin, webgldepthmin + 0.3 * (webgldepthmax - webgldepthmin));
	}

  Float32List origProjMat;
	if ((entity.flags & RF_WEAPONMODEL) != 0) {
		// extern hmm_mat4 GL3_MYgluPerspective(GLdouble fovy, GLdouble aspect, GLdouble zNear, GLdouble zFar);

		origProjMat = glstate.uni3DData.transProjMat4;

		// render weapon with a different FOV (r_gunfov) so it's not distorted at high view FOV
		double screenaspect = webgl_newrefdef.width / webgl_newrefdef.height;
		double dist = (r_farsee.value == 0) ? 4096.0 : 8192.0;
		glstate.uni3DData.transProjMat4 = WebGL_MYgluPerspective(r_gunfov.value, screenaspect, 4, dist);

		if(gl_lefthand.value == 1.0)
		{
			// to mirror gun so it's rendered left-handed, just invert X-axis column
			// of projection matrix

      final mat = glstate.uni3DData.transProjMat4;
			for(int i=0; i<4; ++i) {
				mat[i] = -mat[i];
			}
      glstate.uni3DData.transProjMat4 = mat;
			//GL3_UpdateUBO3D(); Note: GL3_RotateForEntity() will call this,no need to do it twice before drawing

			gl.cullFace(WebGL.BACK);
		}
	}

	//glPushMatrix();
	var origModelMat = glstate.uni3DData.transModelMat4;

	entity.angles[PITCH] = -entity.angles[PITCH];
	WebGL_RotateForEntity(entity);
	entity.angles[PITCH] = -entity.angles[PITCH];

	/* select skin */
  webglimage_t skin;
	if (entity.skin != null) {
		skin = entity.skin; /* custom player skin */
	} else {
		if (entity.skinnum >= MAX_MD2SKINS) {
			skin = model.skins[0];
		} else {
			skin = model.skins[entity.skinnum];

			if (skin == null) {
				skin = model.skins[0];
			}
		}
	}

	if (skin == null) {
		skin = webgl_notexture; /* fallback... */
	}

	WebGL_Bind(skin.texture);

	if ((entity.flags & RF_TRANSLUCENT) != 0) {
		gl.enable(WebGL.BLEND);
	}


	if ((entity.frame >= paliashdr.num_frames) ||
		(entity.frame < 0)) {
		Com_DPrintf("R_DrawAliasModel ${model.name}: no such frame ${entity.frame}\n");
		entity.frame = 0;
		entity.oldframe = 0;
	}

	if ((entity.oldframe >= paliashdr.num_frames) ||
		(entity.oldframe < 0))
	{
		Com_DPrintf("R_DrawAliasModel ${model.name}: no such oldframe ${entity.oldframe}\n");
		entity.frame = 0;
		entity.oldframe = 0;
	}

	_DrawAliasFrameLerp(model, entity, shadelight);

	//glPopMatrix();
	glstate.uni3DData.transModelMat4 = origModelMat;
	WebGL_UpdateUBO3D();

	if ((entity.flags & RF_WEAPONMODEL) != 0) {
		glstate.uni3DData.transProjMat4 = origProjMat;
		WebGL_UpdateUBO3D();
		if(gl_lefthand.value == 1.0)
			gl.cullFace(WebGL.FRONT);
	}

	if ((entity.flags & RF_TRANSLUCENT) != 0) {
		gl.disable(WebGL.BLEND);
	}

	if ((entity.flags & RF_DEPTHHACK) != 0) {
		gl.depthRange(webgldepthmin, webgldepthmax);
	}

	// if (gl_shadows.boolean && glconfig.stencil && (entity.flags & (RF_TRANSLUCENT | RF_WEAPONMODEL | RF_NOSHADOW)) == 0) {
	// 	gl3_shadowinfo_t si = {0};
	// 	VectorCopy(lightspot, si.lightspot);
	// 	VectorCopy(shadevector, si.shadevector);
	// 	si.paliashdr = paliashdr;
	// 	si.entity = entity;

	// 	da_push(shadowModels, si);
	// }
}

const r_avertexnormals = [
[ -0.525731, 0.000000, 0.850651 ],
[ -0.442863, 0.238856, 0.864188 ],
[ -0.295242, 0.000000, 0.955423 ],
[ -0.309017, 0.500000, 0.809017 ],
[ -0.162460, 0.262866, 0.951056 ],
[ 0.000000, 0.000000, 1.000000 ],
[ 0.000000, 0.850651, 0.525731 ],
[ -0.147621, 0.716567, 0.681718 ],
[ 0.147621, 0.716567, 0.681718 ],
[ 0.000000, 0.525731, 0.850651 ],
[ 0.309017, 0.500000, 0.809017 ],
[ 0.525731, 0.000000, 0.850651 ],
[ 0.295242, 0.000000, 0.955423 ],
[ 0.442863, 0.238856, 0.864188 ],
[ 0.162460, 0.262866, 0.951056 ],
[ -0.681718, 0.147621, 0.716567 ],
[ -0.809017, 0.309017, 0.500000 ],
[ -0.587785, 0.425325, 0.688191 ],
[ -0.850651, 0.525731, 0.000000 ],
[ -0.864188, 0.442863, 0.238856 ],
[ -0.716567, 0.681718, 0.147621 ],
[ -0.688191, 0.587785, 0.425325 ],
[ -0.500000, 0.809017, 0.309017 ],
[ -0.238856, 0.864188, 0.442863 ],
[ -0.425325, 0.688191, 0.587785 ],
[ -0.716567, 0.681718, -0.147621 ],
[ -0.500000, 0.809017, -0.309017 ],
[ -0.525731, 0.850651, 0.000000 ],
[ 0.000000, 0.850651, -0.525731 ],
[ -0.238856, 0.864188, -0.442863 ],
[ 0.000000, 0.955423, -0.295242 ],
[ -0.262866, 0.951056, -0.162460 ],
[ 0.000000, 1.000000, 0.000000 ],
[ 0.000000, 0.955423, 0.295242 ],
[ -0.262866, 0.951056, 0.162460 ],
[ 0.238856, 0.864188, 0.442863 ],
[ 0.262866, 0.951056, 0.162460 ],
[ 0.500000, 0.809017, 0.309017 ],
[ 0.238856, 0.864188, -0.442863 ],
[ 0.262866, 0.951056, -0.162460 ],
[ 0.500000, 0.809017, -0.309017 ],
[ 0.850651, 0.525731, 0.000000 ],
[ 0.716567, 0.681718, 0.147621 ],
[ 0.716567, 0.681718, -0.147621 ],
[ 0.525731, 0.850651, 0.000000 ],
[ 0.425325, 0.688191, 0.587785 ],
[ 0.864188, 0.442863, 0.238856 ],
[ 0.688191, 0.587785, 0.425325 ],
[ 0.809017, 0.309017, 0.500000 ],
[ 0.681718, 0.147621, 0.716567 ],
[ 0.587785, 0.425325, 0.688191 ],
[ 0.955423, 0.295242, 0.000000 ],
[ 1.000000, 0.000000, 0.000000 ],
[ 0.951056, 0.162460, 0.262866 ],
[ 0.850651, -0.525731, 0.000000 ],
[ 0.955423, -0.295242, 0.000000 ],
[ 0.864188, -0.442863, 0.238856 ],
[ 0.951056, -0.162460, 0.262866 ],
[ 0.809017, -0.309017, 0.500000 ],
[ 0.681718, -0.147621, 0.716567 ],
[ 0.850651, 0.000000, 0.525731 ],
[ 0.864188, 0.442863, -0.238856 ],
[ 0.809017, 0.309017, -0.500000 ],
[ 0.951056, 0.162460, -0.262866 ],
[ 0.525731, 0.000000, -0.850651 ],
[ 0.681718, 0.147621, -0.716567 ],
[ 0.681718, -0.147621, -0.716567 ],
[ 0.850651, 0.000000, -0.525731 ],
[ 0.809017, -0.309017, -0.500000 ],
[ 0.864188, -0.442863, -0.238856 ],
[ 0.951056, -0.162460, -0.262866 ],
[ 0.147621, 0.716567, -0.681718 ],
[ 0.309017, 0.500000, -0.809017 ],
[ 0.425325, 0.688191, -0.587785 ],
[ 0.442863, 0.238856, -0.864188 ],
[ 0.587785, 0.425325, -0.688191 ],
[ 0.688191, 0.587785, -0.425325 ],
[ -0.147621, 0.716567, -0.681718 ],
[ -0.309017, 0.500000, -0.809017 ],
[ 0.000000, 0.525731, -0.850651 ],
[ -0.525731, 0.000000, -0.850651 ],
[ -0.442863, 0.238856, -0.864188 ],
[ -0.295242, 0.000000, -0.955423 ],
[ -0.162460, 0.262866, -0.951056 ],
[ 0.000000, 0.000000, -1.000000 ],
[ 0.295242, 0.000000, -0.955423 ],
[ 0.162460, 0.262866, -0.951056 ],
[ -0.442863, -0.238856, -0.864188 ],
[ -0.309017, -0.500000, -0.809017 ],
[ -0.162460, -0.262866, -0.951056 ],
[ 0.000000, -0.850651, -0.525731 ],
[ -0.147621, -0.716567, -0.681718 ],
[ 0.147621, -0.716567, -0.681718 ],
[ 0.000000, -0.525731, -0.850651 ],
[ 0.309017, -0.500000, -0.809017 ],
[ 0.442863, -0.238856, -0.864188 ],
[ 0.162460, -0.262866, -0.951056 ],
[ 0.238856, -0.864188, -0.442863 ],
[ 0.500000, -0.809017, -0.309017 ],
[ 0.425325, -0.688191, -0.587785 ],
[ 0.716567, -0.681718, -0.147621 ],
[ 0.688191, -0.587785, -0.425325 ],
[ 0.587785, -0.425325, -0.688191 ],
[ 0.000000, -0.955423, -0.295242 ],
[ 0.000000, -1.000000, 0.000000 ],
[ 0.262866, -0.951056, -0.162460 ],
[ 0.000000, -0.850651, 0.525731 ],
[ 0.000000, -0.955423, 0.295242 ],
[ 0.238856, -0.864188, 0.442863 ],
[ 0.262866, -0.951056, 0.162460 ],
[ 0.500000, -0.809017, 0.309017 ],
[ 0.716567, -0.681718, 0.147621 ],
[ 0.525731, -0.850651, 0.000000 ],
[ -0.238856, -0.864188, -0.442863 ],
[ -0.500000, -0.809017, -0.309017 ],
[ -0.262866, -0.951056, -0.162460 ],
[ -0.850651, -0.525731, 0.000000 ],
[ -0.716567, -0.681718, -0.147621 ],
[ -0.716567, -0.681718, 0.147621 ],
[ -0.525731, -0.850651, 0.000000 ],
[ -0.500000, -0.809017, 0.309017 ],
[ -0.238856, -0.864188, 0.442863 ],
[ -0.262866, -0.951056, 0.162460 ],
[ -0.864188, -0.442863, 0.238856 ],
[ -0.809017, -0.309017, 0.500000 ],
[ -0.688191, -0.587785, 0.425325 ],
[ -0.681718, -0.147621, 0.716567 ],
[ -0.442863, -0.238856, 0.864188 ],
[ -0.587785, -0.425325, 0.688191 ],
[ -0.309017, -0.500000, 0.809017 ],
[ -0.147621, -0.716567, 0.681718 ],
[ -0.425325, -0.688191, 0.587785 ],
[ -0.162460, -0.262866, 0.951056 ],
[ 0.442863, -0.238856, 0.864188 ],
[ 0.162460, -0.262866, 0.951056 ],
[ 0.309017, -0.500000, 0.809017 ],
[ 0.147621, -0.716567, 0.681718 ],
[ 0.000000, -0.525731, 0.850651 ],
[ 0.425325, -0.688191, 0.587785 ],
[ 0.587785, -0.425325, 0.688191 ],
[ 0.688191, -0.587785, 0.425325 ],
[ -0.955423, 0.295242, 0.000000 ],
[ -0.951056, 0.162460, 0.262866 ],
[ -1.000000, 0.000000, 0.000000 ],
[ -0.850651, 0.000000, 0.525731 ],
[ -0.955423, -0.295242, 0.000000 ],
[ -0.951056, -0.162460, 0.262866 ],
[ -0.864188, 0.442863, -0.238856 ],
[ -0.951056, 0.162460, -0.262866 ],
[ -0.809017, 0.309017, -0.500000 ],
[ -0.864188, -0.442863, -0.238856 ],
[ -0.951056, -0.162460, -0.262866 ],
[ -0.809017, -0.309017, -0.500000 ],
[ -0.681718, 0.147621, -0.716567 ],
[ -0.681718, -0.147621, -0.716567 ],
[ -0.850651, 0.000000, -0.525731 ],
[ -0.688191, 0.587785, -0.425325 ],
[ -0.587785, 0.425325, -0.688191 ],
[ -0.425325, 0.688191, -0.587785 ],
[ -0.425325, -0.688191, -0.587785 ],
[ -0.587785, -0.425325, -0.688191 ],
[ -0.688191, -0.587785, -0.425325 ]
];

/* precalculated dot products for quantized angles */
const r_avertexnormal_dots = [
	[ 1.23, 1.30, 1.47, 1.35, 1.56, 1.71, 1.37, 1.38, 1.59, 1.60, 1.79, 1.97, 1.88, 1.92, 1.79, 1.02, 0.93, 1.07, 0.82, 0.87,
	  0.88, 0.94, 0.96, 1.14, 1.11, 0.82, 0.83, 0.89, 0.89, 0.86, 0.94, 0.91, 1.00, 1.21, 0.98, 1.48, 1.30, 1.57, 0.96, 1.07,
	  1.14, 1.60, 1.61, 1.40, 1.37, 1.72, 1.78, 1.79, 1.93, 1.99, 1.90, 1.68, 1.71, 1.86, 1.60, 1.68, 1.78, 1.86, 1.93, 1.99,
	  1.97, 1.44, 1.22, 1.49, 0.93, 0.99, 0.99, 1.23, 1.22, 1.44, 1.49, 0.89, 0.89, 0.97, 0.91, 0.98, 1.19, 0.82, 0.76, 0.82,
	  0.71, 0.72, 0.73, 0.76, 0.79, 0.86, 0.83, 0.72, 0.76, 0.76, 0.89, 0.82, 0.89, 0.82, 0.89, 0.91, 0.83, 0.96, 1.14, 0.97,
	  1.40, 1.19, 0.98, 0.94, 1.00, 1.07, 1.37, 1.21, 1.48, 1.30, 1.57, 1.61, 1.37, 0.86, 0.83, 0.91, 0.82, 0.82, 0.88, 0.89,
	  0.96, 1.14, 0.98, 0.87, 0.93, 0.94, 1.02, 1.30, 1.07, 1.35, 1.38, 1.11, 1.56, 1.92, 1.79, 1.79, 1.59, 1.60, 1.72, 1.90,
	  1.79, 0.80, 0.85, 0.79, 0.93, 0.80, 0.85, 0.77, 0.74, 0.72, 0.77, 0.74, 0.72, 0.70, 0.70, 0.71, 0.76, 0.73, 0.79, 0.79,
	  0.73, 0.76, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.26, 1.26, 1.48, 1.23, 1.50, 1.71, 1.14, 1.19, 1.38, 1.46, 1.64, 1.94, 1.87, 1.84, 1.71, 1.02, 0.92, 1.00, 0.79, 0.85,
	  0.84, 0.91, 0.90, 0.98, 0.99, 0.77, 0.77, 0.83, 0.82, 0.79, 0.86, 0.84, 0.92, 0.99, 0.91, 1.24, 1.03, 1.33, 0.88, 0.94,
	  0.97, 1.41, 1.39, 1.18, 1.11, 1.51, 1.61, 1.59, 1.80, 1.91, 1.76, 1.54, 1.65, 1.76, 1.70, 1.70, 1.85, 1.85, 1.97, 1.99,
	  1.93, 1.28, 1.09, 1.39, 0.92, 0.97, 0.99, 1.18, 1.26, 1.52, 1.48, 0.83, 0.85, 0.90, 0.88, 0.93, 1.00, 0.77, 0.73, 0.78,
	  0.72, 0.71, 0.74, 0.75, 0.79, 0.86, 0.81, 0.75, 0.81, 0.79, 0.96, 0.88, 0.94, 0.86, 0.93, 0.92, 0.85, 1.08, 1.33, 1.05,
	  1.55, 1.31, 1.01, 1.05, 1.27, 1.31, 1.60, 1.47, 1.70, 1.54, 1.76, 1.76, 1.57, 0.93, 0.90, 0.99, 0.88, 0.88, 0.95, 0.97,
	  1.11, 1.39, 1.20, 0.92, 0.97, 1.01, 1.10, 1.39, 1.22, 1.51, 1.58, 1.32, 1.64, 1.97, 1.85, 1.91, 1.77, 1.74, 1.88, 1.99,
	  1.91, 0.79, 0.86, 0.80, 0.94, 0.84, 0.88, 0.74, 0.74, 0.71, 0.82, 0.77, 0.76, 0.70, 0.73, 0.72, 0.73, 0.70, 0.74, 0.85,
	  0.77, 0.82, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.34, 1.27, 1.53, 1.17, 1.46, 1.71, 0.98, 1.05, 1.20, 1.34, 1.48, 1.86, 1.82, 1.71, 1.62, 1.09, 0.94, 0.99, 0.79, 0.85,
	  0.82, 0.90, 0.87, 0.93, 0.96, 0.76, 0.74, 0.79, 0.76, 0.74, 0.79, 0.78, 0.85, 0.92, 0.85, 1.00, 0.93, 1.06, 0.81, 0.86,
	  0.89, 1.16, 1.12, 0.97, 0.95, 1.28, 1.38, 1.35, 1.60, 1.77, 1.57, 1.33, 1.50, 1.58, 1.69, 1.63, 1.82, 1.74, 1.91, 1.92,
	  1.80, 1.04, 0.97, 1.21, 0.90, 0.93, 0.97, 1.05, 1.21, 1.48, 1.37, 0.77, 0.80, 0.84, 0.85, 0.88, 0.92, 0.73, 0.71, 0.74,
	  0.74, 0.71, 0.75, 0.73, 0.79, 0.84, 0.78, 0.79, 0.86, 0.81, 1.05, 0.94, 0.99, 0.90, 0.95, 0.92, 0.86, 1.24, 1.44, 1.14,
	  1.59, 1.34, 1.02, 1.27, 1.50, 1.49, 1.80, 1.69, 1.86, 1.72, 1.87, 1.80, 1.69, 1.00, 0.98, 1.23, 0.95, 0.96, 1.09, 1.16,
	  1.37, 1.63, 1.46, 0.99, 1.10, 1.25, 1.24, 1.51, 1.41, 1.67, 1.77, 1.55, 1.72, 1.95, 1.89, 1.98, 1.91, 1.86, 1.97, 1.99,
	  1.94, 0.81, 0.89, 0.85, 0.98, 0.90, 0.94, 0.75, 0.78, 0.73, 0.89, 0.83, 0.82, 0.72, 0.77, 0.76, 0.72, 0.70, 0.71, 0.91,
	  0.83, 0.89, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.46, 1.34, 1.60, 1.16, 1.46, 1.71, 0.94, 0.99, 1.05, 1.26, 1.33, 1.74, 1.76, 1.57, 1.54, 1.23, 0.98, 1.05, 0.83, 0.89,
	  0.84, 0.92, 0.87, 0.91, 0.96, 0.78, 0.74, 0.79, 0.72, 0.72, 0.75, 0.76, 0.80, 0.88, 0.83, 0.94, 0.87, 0.95, 0.76, 0.80,
	  0.82, 0.97, 0.96, 0.89, 0.88, 1.08, 1.11, 1.10, 1.37, 1.59, 1.37, 1.07, 1.27, 1.34, 1.57, 1.45, 1.69, 1.55, 1.77, 1.79,
	  1.60, 0.93, 0.90, 0.99, 0.86, 0.87, 0.93, 0.96, 1.07, 1.35, 1.18, 0.73, 0.76, 0.77, 0.81, 0.82, 0.85, 0.70, 0.71, 0.72,
	  0.78, 0.73, 0.77, 0.73, 0.79, 0.82, 0.76, 0.83, 0.90, 0.84, 1.18, 0.98, 1.03, 0.92, 0.95, 0.90, 0.86, 1.32, 1.45, 1.15,
	  1.53, 1.27, 0.99, 1.42, 1.65, 1.58, 1.93, 1.83, 1.94, 1.81, 1.88, 1.74, 1.70, 1.19, 1.17, 1.44, 1.11, 1.15, 1.36, 1.41,
	  1.61, 1.81, 1.67, 1.22, 1.34, 1.50, 1.42, 1.65, 1.61, 1.82, 1.91, 1.75, 1.80, 1.89, 1.89, 1.98, 1.99, 1.94, 1.98, 1.92,
	  1.87, 0.86, 0.95, 0.92, 1.14, 0.98, 1.03, 0.79, 0.84, 0.77, 0.97, 0.90, 0.89, 0.76, 0.82, 0.82, 0.74, 0.72, 0.71, 0.98,
	  0.89, 0.97, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.60, 1.44, 1.68, 1.22, 1.49, 1.71, 0.93, 0.99, 0.99, 1.23, 1.22, 1.60, 1.68, 1.44, 1.49, 1.40, 1.14, 1.19, 0.89, 0.96,
	  0.89, 0.97, 0.89, 0.91, 0.98, 0.82, 0.76, 0.82, 0.71, 0.72, 0.73, 0.76, 0.79, 0.86, 0.83, 0.91, 0.83, 0.89, 0.72, 0.76,
	  0.76, 0.89, 0.89, 0.82, 0.82, 0.98, 0.96, 0.97, 1.14, 1.40, 1.19, 0.94, 1.00, 1.07, 1.37, 1.21, 1.48, 1.30, 1.57, 1.61,
	  1.37, 0.86, 0.83, 0.91, 0.82, 0.82, 0.88, 0.89, 0.96, 1.14, 0.98, 0.70, 0.72, 0.73, 0.77, 0.76, 0.79, 0.70, 0.72, 0.71,
	  0.82, 0.77, 0.80, 0.74, 0.79, 0.80, 0.74, 0.87, 0.93, 0.85, 1.23, 1.02, 1.02, 0.93, 0.93, 0.87, 0.85, 1.30, 1.35, 1.07,
	  1.38, 1.11, 0.94, 1.47, 1.71, 1.56, 1.97, 1.88, 1.92, 1.79, 1.79, 1.59, 1.60, 1.30, 1.35, 1.56, 1.37, 1.38, 1.59, 1.60,
	  1.79, 1.92, 1.79, 1.48, 1.57, 1.72, 1.61, 1.78, 1.79, 1.93, 1.99, 1.90, 1.86, 1.78, 1.86, 1.93, 1.99, 1.97, 1.90, 1.79,
	  1.72, 0.94, 1.07, 1.00, 1.37, 1.21, 1.30, 0.86, 0.91, 0.83, 1.14, 0.98, 0.96, 0.82, 0.88, 0.89, 0.79, 0.76, 0.73, 1.07,
	  0.94, 1.11, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.74, 1.57, 1.76, 1.33, 1.54, 1.71, 0.94, 1.05, 0.99, 1.26, 1.16, 1.46, 1.60, 1.34, 1.46, 1.59, 1.37, 1.37, 0.97, 1.11,
	  0.96, 1.10, 0.95, 0.94, 1.08, 0.89, 0.82, 0.88, 0.72, 0.76, 0.75, 0.80, 0.80, 0.88, 0.87, 0.91, 0.83, 0.87, 0.72, 0.76,
	  0.74, 0.83, 0.84, 0.78, 0.79, 0.96, 0.89, 0.92, 0.98, 1.23, 1.05, 0.86, 0.92, 0.95, 1.11, 0.98, 1.22, 1.03, 1.34, 1.42,
	  1.14, 0.79, 0.77, 0.84, 0.78, 0.76, 0.82, 0.82, 0.89, 0.97, 0.90, 0.70, 0.71, 0.71, 0.73, 0.72, 0.74, 0.73, 0.76, 0.72,
	  0.86, 0.81, 0.82, 0.76, 0.79, 0.77, 0.73, 0.90, 0.95, 0.86, 1.18, 1.03, 0.98, 0.92, 0.90, 0.83, 0.84, 1.19, 1.17, 0.98,
	  1.15, 0.97, 0.89, 1.42, 1.65, 1.44, 1.93, 1.83, 1.81, 1.67, 1.61, 1.36, 1.41, 1.32, 1.45, 1.58, 1.57, 1.53, 1.74, 1.70,
	  1.88, 1.94, 1.81, 1.69, 1.77, 1.87, 1.79, 1.89, 1.92, 1.98, 1.99, 1.98, 1.89, 1.65, 1.80, 1.82, 1.91, 1.94, 1.75, 1.61,
	  1.50, 1.07, 1.34, 1.27, 1.60, 1.45, 1.55, 0.93, 0.99, 0.90, 1.35, 1.18, 1.07, 0.87, 0.93, 0.96, 0.85, 0.82, 0.77, 1.15,
	  0.99, 1.27, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.86, 1.71, 1.82, 1.48, 1.62, 1.71, 0.98, 1.20, 1.05, 1.34, 1.17, 1.34, 1.53, 1.27, 1.46, 1.77, 1.60, 1.57, 1.16, 1.38,
	  1.12, 1.35, 1.06, 1.00, 1.28, 0.97, 0.89, 0.95, 0.76, 0.81, 0.79, 0.86, 0.85, 0.92, 0.93, 0.93, 0.85, 0.87, 0.74, 0.78,
	  0.74, 0.79, 0.82, 0.76, 0.79, 0.96, 0.85, 0.90, 0.94, 1.09, 0.99, 0.81, 0.85, 0.89, 0.95, 0.90, 0.99, 0.94, 1.10, 1.24,
	  0.98, 0.75, 0.73, 0.78, 0.74, 0.72, 0.77, 0.76, 0.82, 0.89, 0.83, 0.73, 0.71, 0.71, 0.71, 0.70, 0.72, 0.77, 0.80, 0.74,
	  0.90, 0.85, 0.84, 0.78, 0.79, 0.75, 0.73, 0.92, 0.95, 0.86, 1.05, 0.99, 0.94, 0.90, 0.86, 0.79, 0.81, 1.00, 0.98, 0.91,
	  0.96, 0.89, 0.83, 1.27, 1.50, 1.23, 1.80, 1.69, 1.63, 1.46, 1.37, 1.09, 1.16, 1.24, 1.44, 1.49, 1.69, 1.59, 1.80, 1.69,
	  1.87, 1.86, 1.72, 1.82, 1.91, 1.94, 1.92, 1.95, 1.99, 1.98, 1.91, 1.97, 1.89, 1.51, 1.72, 1.67, 1.77, 1.86, 1.55, 1.41,
	  1.25, 1.33, 1.58, 1.50, 1.80, 1.63, 1.74, 1.04, 1.21, 0.97, 1.48, 1.37, 1.21, 0.93, 0.97, 1.05, 0.92, 0.88, 0.84, 1.14,
	  1.02, 1.34, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.94, 1.84, 1.87, 1.64, 1.71, 1.71, 1.14, 1.38, 1.19, 1.46, 1.23, 1.26, 1.48, 1.26, 1.50, 1.91, 1.80, 1.76, 1.41, 1.61,
	  1.39, 1.59, 1.33, 1.24, 1.51, 1.18, 0.97, 1.11, 0.82, 0.88, 0.86, 0.94, 0.92, 0.99, 1.03, 0.98, 0.91, 0.90, 0.79, 0.84,
	  0.77, 0.79, 0.84, 0.77, 0.83, 0.99, 0.85, 0.91, 0.92, 1.02, 1.00, 0.79, 0.80, 0.86, 0.88, 0.84, 0.92, 0.88, 0.97, 1.10,
	  0.94, 0.74, 0.71, 0.74, 0.72, 0.70, 0.73, 0.72, 0.76, 0.82, 0.77, 0.77, 0.73, 0.74, 0.71, 0.70, 0.73, 0.83, 0.85, 0.78,
	  0.92, 0.88, 0.86, 0.81, 0.79, 0.74, 0.75, 0.92, 0.93, 0.85, 0.96, 0.94, 0.88, 0.86, 0.81, 0.75, 0.79, 0.93, 0.90, 0.85,
	  0.88, 0.82, 0.77, 1.05, 1.27, 0.99, 1.60, 1.47, 1.39, 1.20, 1.11, 0.95, 0.97, 1.08, 1.33, 1.31, 1.70, 1.55, 1.76, 1.57,
	  1.76, 1.70, 1.54, 1.85, 1.97, 1.91, 1.99, 1.97, 1.99, 1.91, 1.77, 1.88, 1.85, 1.39, 1.64, 1.51, 1.58, 1.74, 1.32, 1.22,
	  1.01, 1.54, 1.76, 1.65, 1.93, 1.70, 1.85, 1.28, 1.39, 1.09, 1.52, 1.48, 1.26, 0.97, 0.99, 1.18, 1.00, 0.93, 0.90, 1.05,
	  1.01, 1.31, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.97, 1.92, 1.88, 1.79, 1.79, 1.71, 1.37, 1.59, 1.38, 1.60, 1.35, 1.23, 1.47, 1.30, 1.56, 1.99, 1.93, 1.90, 1.60, 1.78,
	  1.61, 1.79, 1.57, 1.48, 1.72, 1.40, 1.14, 1.37, 0.89, 0.96, 0.94, 1.07, 1.00, 1.21, 1.30, 1.14, 0.98, 0.96, 0.86, 0.91,
	  0.83, 0.82, 0.88, 0.82, 0.89, 1.11, 0.87, 0.94, 0.93, 1.02, 1.07, 0.80, 0.79, 0.85, 0.82, 0.80, 0.87, 0.85, 0.93, 1.02,
	  0.93, 0.77, 0.72, 0.74, 0.71, 0.70, 0.70, 0.71, 0.72, 0.77, 0.74, 0.82, 0.76, 0.79, 0.72, 0.73, 0.76, 0.89, 0.89, 0.82,
	  0.93, 0.91, 0.86, 0.83, 0.79, 0.73, 0.76, 0.91, 0.89, 0.83, 0.89, 0.89, 0.82, 0.82, 0.76, 0.72, 0.76, 0.86, 0.83, 0.79,
	  0.82, 0.76, 0.73, 0.94, 1.00, 0.91, 1.37, 1.21, 1.14, 0.98, 0.96, 0.88, 0.89, 0.96, 1.14, 1.07, 1.60, 1.40, 1.61, 1.37,
	  1.57, 1.48, 1.30, 1.78, 1.93, 1.79, 1.99, 1.92, 1.90, 1.79, 1.59, 1.72, 1.79, 1.30, 1.56, 1.35, 1.38, 1.60, 1.11, 1.07,
	  0.94, 1.68, 1.86, 1.71, 1.97, 1.68, 1.86, 1.44, 1.49, 1.22, 1.44, 1.49, 1.22, 0.99, 0.99, 1.23, 1.19, 0.98, 0.97, 0.97,
	  0.98, 1.19, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.94, 1.97, 1.87, 1.91, 1.85, 1.71, 1.60, 1.77, 1.58, 1.74, 1.51, 1.26, 1.48, 1.39, 1.64, 1.99, 1.97, 1.99, 1.70, 1.85,
	  1.76, 1.91, 1.76, 1.70, 1.88, 1.55, 1.33, 1.57, 0.96, 1.08, 1.05, 1.31, 1.27, 1.47, 1.54, 1.39, 1.20, 1.11, 0.93, 0.99,
	  0.90, 0.88, 0.95, 0.88, 0.97, 1.32, 0.92, 1.01, 0.97, 1.10, 1.22, 0.84, 0.80, 0.88, 0.79, 0.79, 0.85, 0.86, 0.92, 1.02,
	  0.94, 0.82, 0.76, 0.77, 0.72, 0.73, 0.70, 0.72, 0.71, 0.74, 0.74, 0.88, 0.81, 0.85, 0.75, 0.77, 0.82, 0.94, 0.93, 0.86,
	  0.92, 0.92, 0.86, 0.85, 0.79, 0.74, 0.79, 0.88, 0.85, 0.81, 0.82, 0.83, 0.77, 0.78, 0.73, 0.71, 0.75, 0.79, 0.77, 0.74,
	  0.77, 0.73, 0.70, 0.86, 0.92, 0.84, 1.14, 0.99, 0.98, 0.91, 0.90, 0.84, 0.83, 0.88, 0.97, 0.94, 1.41, 1.18, 1.39, 1.11,
	  1.33, 1.24, 1.03, 1.61, 1.80, 1.59, 1.91, 1.84, 1.76, 1.64, 1.38, 1.51, 1.71, 1.26, 1.50, 1.23, 1.19, 1.46, 0.99, 1.00,
	  0.91, 1.70, 1.85, 1.65, 1.93, 1.54, 1.76, 1.52, 1.48, 1.26, 1.28, 1.39, 1.09, 0.99, 0.97, 1.18, 1.31, 1.01, 1.05, 0.90,
	  0.93, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.86, 1.95, 1.82, 1.98, 1.89, 1.71, 1.80, 1.91, 1.77, 1.86, 1.67, 1.34, 1.53, 1.51, 1.72, 1.92, 1.91, 1.99, 1.69, 1.82,
	  1.80, 1.94, 1.87, 1.86, 1.97, 1.59, 1.44, 1.69, 1.05, 1.24, 1.27, 1.49, 1.50, 1.69, 1.72, 1.63, 1.46, 1.37, 1.00, 1.23,
	  0.98, 0.95, 1.09, 0.96, 1.16, 1.55, 0.99, 1.25, 1.10, 1.24, 1.41, 0.90, 0.85, 0.94, 0.79, 0.81, 0.85, 0.89, 0.94, 1.09,
	  0.98, 0.89, 0.82, 0.83, 0.74, 0.77, 0.72, 0.76, 0.73, 0.75, 0.78, 0.94, 0.86, 0.91, 0.79, 0.83, 0.89, 0.99, 0.95, 0.90,
	  0.90, 0.92, 0.84, 0.86, 0.79, 0.75, 0.81, 0.85, 0.80, 0.78, 0.76, 0.77, 0.73, 0.74, 0.71, 0.71, 0.73, 0.74, 0.74, 0.71,
	  0.76, 0.72, 0.70, 0.79, 0.85, 0.78, 0.98, 0.92, 0.93, 0.85, 0.87, 0.82, 0.79, 0.81, 0.89, 0.86, 1.16, 0.97, 1.12, 0.95,
	  1.06, 1.00, 0.93, 1.38, 1.60, 1.35, 1.77, 1.71, 1.57, 1.48, 1.20, 1.28, 1.62, 1.27, 1.46, 1.17, 1.05, 1.34, 0.96, 0.99,
	  0.90, 1.63, 1.74, 1.50, 1.80, 1.33, 1.58, 1.48, 1.37, 1.21, 1.04, 1.21, 0.97, 0.97, 0.93, 1.05, 1.34, 1.02, 1.14, 0.84,
	  0.88, 0.92, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.74, 1.89, 1.76, 1.98, 1.89, 1.71, 1.93, 1.99, 1.91, 1.94, 1.82, 1.46, 1.60, 1.65, 1.80, 1.79, 1.77, 1.92, 1.57, 1.69,
	  1.74, 1.87, 1.88, 1.94, 1.98, 1.53, 1.45, 1.70, 1.18, 1.32, 1.42, 1.58, 1.65, 1.83, 1.81, 1.81, 1.67, 1.61, 1.19, 1.44,
	  1.17, 1.11, 1.36, 1.15, 1.41, 1.75, 1.22, 1.50, 1.34, 1.42, 1.61, 0.98, 0.92, 1.03, 0.83, 0.86, 0.89, 0.95, 0.98, 1.23,
	  1.14, 0.97, 0.89, 0.90, 0.78, 0.82, 0.76, 0.82, 0.77, 0.79, 0.84, 0.98, 0.90, 0.98, 0.83, 0.89, 0.97, 1.03, 0.95, 0.92,
	  0.86, 0.90, 0.82, 0.86, 0.79, 0.77, 0.84, 0.81, 0.76, 0.76, 0.72, 0.73, 0.70, 0.72, 0.71, 0.73, 0.73, 0.72, 0.74, 0.71,
	  0.78, 0.74, 0.72, 0.75, 0.80, 0.76, 0.94, 0.88, 0.91, 0.83, 0.87, 0.84, 0.79, 0.76, 0.82, 0.80, 0.97, 0.89, 0.96, 0.88,
	  0.95, 0.94, 0.87, 1.11, 1.37, 1.10, 1.59, 1.57, 1.37, 1.33, 1.05, 1.08, 1.54, 1.34, 1.46, 1.16, 0.99, 1.26, 0.96, 1.05,
	  0.92, 1.45, 1.55, 1.27, 1.60, 1.07, 1.34, 1.35, 1.18, 1.07, 0.93, 0.99, 0.90, 0.93, 0.87, 0.96, 1.27, 0.99, 1.15, 0.77,
	  0.82, 0.85, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.60, 1.78, 1.68, 1.93, 1.86, 1.71, 1.97, 1.99, 1.99, 1.97, 1.93, 1.60, 1.68, 1.78, 1.86, 1.61, 1.57, 1.79, 1.37, 1.48,
	  1.59, 1.72, 1.79, 1.92, 1.90, 1.38, 1.35, 1.60, 1.23, 1.30, 1.47, 1.56, 1.71, 1.88, 1.79, 1.92, 1.79, 1.79, 1.30, 1.56,
	  1.35, 1.37, 1.59, 1.38, 1.60, 1.90, 1.48, 1.72, 1.57, 1.61, 1.79, 1.21, 1.00, 1.30, 0.89, 0.94, 0.96, 1.07, 1.14, 1.40,
	  1.37, 1.14, 0.96, 0.98, 0.82, 0.88, 0.82, 0.89, 0.83, 0.86, 0.91, 1.02, 0.93, 1.07, 0.87, 0.94, 1.11, 1.02, 0.93, 0.93,
	  0.82, 0.87, 0.80, 0.85, 0.79, 0.80, 0.85, 0.77, 0.72, 0.74, 0.71, 0.70, 0.70, 0.71, 0.72, 0.77, 0.74, 0.72, 0.76, 0.73,
	  0.82, 0.79, 0.76, 0.73, 0.79, 0.76, 0.93, 0.86, 0.91, 0.83, 0.89, 0.89, 0.82, 0.72, 0.76, 0.76, 0.89, 0.82, 0.89, 0.82,
	  0.89, 0.91, 0.83, 0.96, 1.14, 0.97, 1.40, 1.44, 1.19, 1.22, 0.99, 0.98, 1.49, 1.44, 1.49, 1.22, 0.99, 1.23, 0.98, 1.19,
	  0.97, 1.21, 1.30, 1.00, 1.37, 0.94, 1.07, 1.14, 0.98, 0.96, 0.86, 0.91, 0.83, 0.88, 0.82, 0.89, 1.11, 0.94, 1.07, 0.73,
	  0.76, 0.79, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.46, 1.65, 1.60, 1.82, 1.80, 1.71, 1.93, 1.91, 1.99, 1.94, 1.98, 1.74, 1.76, 1.89, 1.89, 1.42, 1.34, 1.61, 1.11, 1.22,
	  1.36, 1.50, 1.61, 1.81, 1.75, 1.15, 1.17, 1.41, 1.18, 1.19, 1.42, 1.44, 1.65, 1.83, 1.67, 1.94, 1.81, 1.88, 1.32, 1.58,
	  1.45, 1.57, 1.74, 1.53, 1.70, 1.98, 1.69, 1.87, 1.77, 1.79, 1.92, 1.45, 1.27, 1.55, 0.97, 1.07, 1.11, 1.34, 1.37, 1.59,
	  1.60, 1.35, 1.07, 1.18, 0.86, 0.93, 0.87, 0.96, 0.90, 0.93, 0.99, 1.03, 0.95, 1.15, 0.90, 0.99, 1.27, 0.98, 0.90, 0.92,
	  0.78, 0.83, 0.77, 0.84, 0.79, 0.82, 0.86, 0.73, 0.71, 0.73, 0.72, 0.70, 0.73, 0.72, 0.76, 0.81, 0.76, 0.76, 0.82, 0.77,
	  0.89, 0.85, 0.82, 0.75, 0.80, 0.80, 0.94, 0.88, 0.94, 0.87, 0.95, 0.96, 0.88, 0.72, 0.74, 0.76, 0.83, 0.78, 0.84, 0.79,
	  0.87, 0.91, 0.83, 0.89, 0.98, 0.92, 1.23, 1.34, 1.05, 1.16, 0.99, 0.96, 1.46, 1.57, 1.54, 1.33, 1.05, 1.26, 1.08, 1.37,
	  1.10, 0.98, 1.03, 0.92, 1.14, 0.86, 0.95, 0.97, 0.90, 0.89, 0.79, 0.84, 0.77, 0.82, 0.76, 0.82, 0.97, 0.89, 0.98, 0.71,
	  0.72, 0.74, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.34, 1.51, 1.53, 1.67, 1.72, 1.71, 1.80, 1.77, 1.91, 1.86, 1.98, 1.86, 1.82, 1.95, 1.89, 1.24, 1.10, 1.41, 0.95, 0.99,
	  1.09, 1.25, 1.37, 1.63, 1.55, 0.96, 0.98, 1.16, 1.05, 1.00, 1.27, 1.23, 1.50, 1.69, 1.46, 1.86, 1.72, 1.87, 1.24, 1.49,
	  1.44, 1.69, 1.80, 1.59, 1.69, 1.97, 1.82, 1.94, 1.91, 1.92, 1.99, 1.63, 1.50, 1.74, 1.16, 1.33, 1.38, 1.58, 1.60, 1.77,
	  1.80, 1.48, 1.21, 1.37, 0.90, 0.97, 0.93, 1.05, 0.97, 1.04, 1.21, 0.99, 0.95, 1.14, 0.92, 1.02, 1.34, 0.94, 0.86, 0.90,
	  0.74, 0.79, 0.75, 0.81, 0.79, 0.84, 0.86, 0.71, 0.71, 0.73, 0.76, 0.73, 0.77, 0.74, 0.80, 0.85, 0.78, 0.81, 0.89, 0.84,
	  0.97, 0.92, 0.88, 0.79, 0.85, 0.86, 0.98, 0.92, 1.00, 0.93, 1.06, 1.12, 0.95, 0.74, 0.74, 0.78, 0.79, 0.76, 0.82, 0.79,
	  0.87, 0.93, 0.85, 0.85, 0.94, 0.90, 1.09, 1.27, 0.99, 1.17, 1.05, 0.96, 1.46, 1.71, 1.62, 1.48, 1.20, 1.34, 1.28, 1.57,
	  1.35, 0.90, 0.94, 0.85, 0.98, 0.81, 0.89, 0.89, 0.83, 0.82, 0.75, 0.78, 0.73, 0.77, 0.72, 0.76, 0.89, 0.83, 0.91, 0.71,
	  0.70, 0.72, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ],
	[ 1.26, 1.39, 1.48, 1.51, 1.64, 1.71, 1.60, 1.58, 1.77, 1.74, 1.91, 1.94, 1.87, 1.97, 1.85, 1.10, 0.97, 1.22, 0.88, 0.92,
	  0.95, 1.01, 1.11, 1.39, 1.32, 0.88, 0.90, 0.97, 0.96, 0.93, 1.05, 0.99, 1.27, 1.47, 1.20, 1.70, 1.54, 1.76, 1.08, 1.31,
	  1.33, 1.70, 1.76, 1.55, 1.57, 1.88, 1.85, 1.91, 1.97, 1.99, 1.99, 1.70, 1.65, 1.85, 1.41, 1.54, 1.61, 1.76, 1.80, 1.91,
	  1.93, 1.52, 1.26, 1.48, 0.92, 0.99, 0.97, 1.18, 1.09, 1.28, 1.39, 0.94, 0.93, 1.05, 0.92, 1.01, 1.31, 0.88, 0.81, 0.86,
	  0.72, 0.75, 0.74, 0.79, 0.79, 0.86, 0.85, 0.71, 0.73, 0.75, 0.82, 0.77, 0.83, 0.78, 0.85, 0.88, 0.81, 0.88, 0.97, 0.90,
	  1.18, 1.00, 0.93, 0.86, 0.92, 0.94, 1.14, 0.99, 1.24, 1.03, 1.33, 1.39, 1.11, 0.79, 0.77, 0.84, 0.79, 0.77, 0.84, 0.83,
	  0.90, 0.98, 0.91, 0.85, 0.92, 0.91, 1.02, 1.26, 1.00, 1.23, 1.19, 0.99, 1.50, 1.84, 1.71, 1.64, 1.38, 1.46, 1.51, 1.76,
	  1.59, 0.84, 0.88, 0.80, 0.94, 0.79, 0.86, 0.82, 0.77, 0.76, 0.74, 0.74, 0.71, 0.73, 0.70, 0.72, 0.82, 0.77, 0.85, 0.74,
	  0.70, 0.73, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00,
	  1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00 ]
];
