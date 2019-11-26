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
 * Surface generation and drawing
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'dart:web_gl';
import 'package:dQuakeWeb/client/vid/ref.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'webgl_image.dart';
import 'webgl_model.dart';
import 'webgl_main.dart';
import 'webgl_shaders.dart';
import 'webgl_light.dart';
import 'webgl_warp.dart' show WebGL_ClearSkyBox, WebGL_AddSkySurface, WebGL_DrawSkyBox, WebGL_EmitWaterPolys;
import 'local.dart';

List<double> _modelorg = [0,0,0];
msurface_t _webgl_alpha_surfaces;

const _BACKFACE_EPSILON = 0.01;

WebGL_SurfInit() {
	// init the VAO and VBO for the standard vertexdata: 10 floats and 1 uint
	// (X, Y, Z), (S, T), (LMS, LMT), (normX, normY, normZ) ; lightFlags - last two groups for lightmap/dynlights

  glstate.vao3D = gl.createVertexArray();
	WebGL_BindVAO(glstate.vao3D);

  glstate.vbo3D = gl.createBuffer();
	WebGL_BindVBO(glstate.vbo3D);

	// if(glconfig.useBigVBO) {
	// 	gl3state.vbo3Dsize = 5*1024*1024; // a 5MB buffer seems to work well?
	// 	gl3state.vbo3DcurOffset = 0;
	// 	glBufferData(GL_ARRAY_BUFFER, gl3state.vbo3Dsize, NULL, GL_STREAM_DRAW); // allocate/reserve that data
	// }

	gl.enableVertexAttribArray(WEBGL_ATTRIB_POSITION);
	gl.vertexAttribPointer(WEBGL_ATTRIB_POSITION, 3, WebGL.FLOAT, false, 11 * 4, 0);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_TEXCOORD);
	gl.vertexAttribPointer(WEBGL_ATTRIB_TEXCOORD, 2, WebGL.FLOAT, false, 11 * 4, 3 * 4);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_LMTEXCOORD);
	gl.vertexAttribPointer(WEBGL_ATTRIB_LMTEXCOORD, 2, WebGL.FLOAT, false, 11 * 4, 5 * 4);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_NORMAL);
	gl.vertexAttribPointer(WEBGL_ATTRIB_NORMAL, 3, WebGL.FLOAT, false, 11 * 4, 7 * 4);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_LIGHTFLAGS);
	gl.vertexAttribIPointer(WEBGL_ATTRIB_LIGHTFLAGS, 1, WebGL.UNSIGNED_INT, 11 * 4, 10 * 4);

	// init VAO and VBO for model vertexdata: 9 floats
	// (X,Y,Z), (S,T), (R,G,B,A)

  glstate.vaoAlias = gl.createVertexArray();
	WebGL_BindVAO(glstate.vaoAlias);

  glstate.vboAlias = gl.createBuffer();
	WebGL_BindVBO(glstate.vboAlias);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_POSITION);
	gl.vertexAttribPointer(WEBGL_ATTRIB_POSITION, 3, WebGL.FLOAT, false, 9*4, 0);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_TEXCOORD);
	gl.vertexAttribPointer(WEBGL_ATTRIB_TEXCOORD, 2, WebGL.FLOAT, false, 9*4, 3*4);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_COLOR);
	gl.vertexAttribPointer(WEBGL_ATTRIB_COLOR, 4, WebGL.FLOAT, false, 9*4, 5*4);

  glstate.eboAlias = gl.createBuffer();

	// init VAO and VBO for particle vertexdata: 9 floats
	// (X,Y,Z), (point_size,distace_to_camera), (R,G,B,A)

  glstate.vaoParticle = gl.createVertexArray();
	WebGL_BindVAO(glstate.vaoParticle);

  glstate.vboParticle = gl.createBuffer();
	WebGL_BindVBO(glstate.vboParticle);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_POSITION);
	gl.vertexAttribPointer(WEBGL_ATTRIB_POSITION, 3, WebGL.FLOAT, false, 9*4, 0);

	// TODO: maybe move point size and camera origin to UBO and calculate distance in vertex shader
	gl.enableVertexAttribArray(WEBGL_ATTRIB_TEXCOORD); // it's abused for (point_size, distance) here..
	gl.vertexAttribPointer(WEBGL_ATTRIB_TEXCOORD, 2, WebGL.FLOAT, false, 9*4, 3*4);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_COLOR);
	gl.vertexAttribPointer(WEBGL_ATTRIB_COLOR, 4, WebGL.FLOAT, false, 9*4, 5*4);
}

void WebGL_SurfShutdown() {
  gl.deleteBuffer(glstate.vbo3D);
	glstate.vbo3D = null;
	gl.deleteVertexArray(glstate.vao3D);
	glstate.vao3D = null;

	gl.deleteBuffer(glstate.eboAlias);
	glstate.eboAlias = null;
	gl.deleteBuffer(glstate.vboAlias);
	glstate.vboAlias = null;
	gl.deleteVertexArray(glstate.vaoAlias);
	glstate.vaoAlias = null;
}


/*
 * Returns true if the box is completely outside the frustom
 */
bool _CullBox(List<double> mins, List<double> maxs) {

	if (!gl_cull.boolean) {
		return false;
	}

	for (int i = 0; i < 4; i++) {
		if (BoxOnPlaneSide(mins, maxs, frustum[i]) == 2) {
			return true;
		}
	}

	return false;
}

/*
 * Returns the proper texture for a given time and base texture
 */
webglimage_t _TextureAnimation(mtexinfo_t tex) {

	if (tex.next == null) {
		return tex.image;
	}

	int c = currententity.frame % tex.numframes;

	while (c > 0) {
		tex = tex.next;
		c--;
	}

	return tex.image;
}

_SetLightFlags(msurface_t surf) {
	var lightFlags = 0;
	if (surf.dlightframe == webgl_framecount) {
		lightFlags = surf.dlightbits;
	}

	var verts = surf.polys.data.buffer.asByteData();

	int numVerts = surf.polys.numverts;
	for(int i=0; i<numVerts; ++i) {
    verts.setUint32((i * gl3_3D_vtx_size + gl3_3D_vtx_lightFlags_offset) * 4, lightFlags);
	}
}

_SetAllLightFlags(msurface_t surf) {

	var lightFlags = 0xffffffff;

	var verts = surf.polys.data.buffer.asByteData();
	int numVerts = surf.polys.numverts;
	for(int i=0; i<numVerts; ++i) {
    verts.setUint32((i * gl3_3D_vtx_size + gl3_3D_vtx_lightFlags_offset) * 4, lightFlags);
	}
}

WebGL_DrawGLPoly(msurface_t fa) {
	glpoly_t p = fa.polys;

	WebGL_BindVAO(glstate.vao3D);
	WebGL_BindVBO(glstate.vbo3D);

	WebGL_BufferAndDraw3D(p.data, p.numverts, WebGL.TRIANGLE_FAN);
}

WebGL_DrawGLFlowingPoly(msurface_t fa) {

	var p = fa.polys;

	double scroll = -64.0 * ((webgl_newrefdef.time / 40.0) - (webgl_newrefdef.time ~/ 40.0));

	if (scroll == 0.0) {
		scroll = -64.0;
	}

	if(glstate.uni3DData.scroll != scroll) {
		glstate.uni3DData.scroll = scroll;
		WebGL_UpdateUBO3D();
	}

	WebGL_BindVAO(glstate.vao3D);
	WebGL_BindVBO(glstate.vbo3D);

	WebGL_BufferAndDraw3D(p.data, p.numverts, WebGL.TRIANGLE_FAN);
}

_UpdateLMscales(List<List<double>> lmScales, gl3ShaderInfo_t si) {
	var hasChanged = false;

	for(int i=0; i<MAX_LIGHTMAPS_PER_SURFACE; ++i)
	{
		if(hasChanged) {
			si.lmScales.setRange(4 * i, 4 * (i + 1), lmScales[i]);
		} else if( si.lmScales[i * 4 + 0] != lmScales[i][0]
		        || si.lmScales[i * 4 + 1] != lmScales[i][1]
		        || si.lmScales[i * 4 + 2] != lmScales[i][2]
		        || si.lmScales[i * 4 + 3] != lmScales[i][3] )
		{
			si.lmScales.setRange(4 * i, 4 * (i + 1), lmScales[i]);
			hasChanged = true;
		}
	}

	if (hasChanged) {
		gl.uniform4fv(si.uniLmScales, si.lmScales);
	}
}

_RenderBrushPoly(msurface_t fa) {

	c_brush_polys++;

	var image = _TextureAnimation(fa.texinfo);

	if ((fa.flags & SURF_DRAWTURB) != 0) {
		WebGL_Bind(image.texture);
		WebGL_EmitWaterPolys(fa);
		return;
	} else {
		WebGL_Bind(image.texture);
	}

	List<List<double>> lmScales = List.generate(MAX_LIGHTMAPS_PER_SURFACE, (i) => [0,0,0,0]);
	lmScales[0] = [1.0, 1.0, 1.0, 1.0];

	WebGL_BindLightmap(fa.lightmaptexturenum);

	// Any dynamic lights on this surface?
	for (int map = 0; map < MAX_LIGHTMAPS_PER_SURFACE && fa.styles[map] != 255; map++) {
		lmScales[map][0] = webgl_newrefdef.lightstyles[fa.styles[map]].rgb[0];
		lmScales[map][1] = webgl_newrefdef.lightstyles[fa.styles[map]].rgb[1];
		lmScales[map][2] = webgl_newrefdef.lightstyles[fa.styles[map]].rgb[2];
		lmScales[map][3] = 1.0;
	}

	if ((fa.texinfo.flags & SURF_FLOWING) != 0) {
		WebGL_UseProgram(glstate.si3DlmFlow.shaderProgram);
		_UpdateLMscales(lmScales, glstate.si3DlmFlow);
		WebGL_DrawGLFlowingPoly(fa);
	} else {
		WebGL_UseProgram(glstate.si3Dlm.shaderProgram);
		_UpdateLMscales(lmScales, glstate.si3Dlm);
		WebGL_DrawGLPoly(fa);
	}

	// Note: lightmap chains are gone, lightmaps are rendered together with normal texture in one pass
}

/*
 * Draw water surfaces and windows.
 * The BSP tree is waled front to back, so unwinding the chain
 * of alpha_surfaces will draw back to front, giving proper ordering.
 */
WebGL_DrawAlphaSurfaces() {

	/* go back to the world matrix */
	glstate.uni3DData.transModelMat4 = webgl_identityMat4;
	WebGL_UpdateUBO3D();

	gl.enable(WebGL.BLEND);

	for (var s = _webgl_alpha_surfaces; s != null; s = s.texturechain) {
		WebGL_Bind(s.texinfo.image.texture);
		c_brush_polys++;
		var alpha = 1.0;
		if ((s.texinfo.flags & SURF_TRANS33) != 0) {
			alpha = 0.333;
		}
		else if ((s.texinfo.flags & SURF_TRANS66) != 0) {
			alpha = 0.666;
		}
		if(alpha != glstate.uni3DData.alpha) {
			glstate.uni3DData.alpha = alpha;
			WebGL_UpdateUBO3D();
		}

		if ((s.flags & SURF_DRAWTURB) != 0) {
			WebGL_EmitWaterPolys(s);
		}
		else if ((s.texinfo.flags & SURF_FLOWING) != 0) {
			WebGL_UseProgram(glstate.si3DtransFlow.shaderProgram);
			WebGL_DrawGLFlowingPoly(s);
		}
		else
		{
			WebGL_UseProgram(glstate.si3Dtrans.shaderProgram);
			WebGL_DrawGLPoly(s);
		}
	}

	glstate.uni3DData.alpha = 1.0;
	WebGL_UpdateUBO3D();

	gl.disable(WebGL.BLEND);

	_webgl_alpha_surfaces = null;
}


_DrawTextureChains() {

	c_visible_textures = 0;

	for (webglimage_t image in gltextures) {

    if (image == null) {
      continue;
    }

		if (image.registration_sequence == 0) {
			continue;
		}

		var s = image.texturechain;
		if (s == null) {
			continue;
		}

		c_visible_textures++;

    int depth = 0;
		for ( ; s != null; s = s.texturechain) {
			_SetLightFlags(s);
			_RenderBrushPoly(s);
      if (++depth > 200) {
        print("Breaking texture chain");
        break;
      }
		}

		image.texturechain = null;
	}

	// TODO: maybe one loop for normal faces and one for SURF_DRAWTURB ???
}

_RenderLightmappedPoly(msurface_t surf) {

	var image = _TextureAnimation(surf.texinfo);

	List<List<double>> lmScales = List.generate(MAX_LIGHTMAPS_PER_SURFACE, (i) => [0,0,0,0]);
	lmScales[0] = [1.0, 1.0, 1.0, 1.0];

	// assert((surf->texinfo->flags & (SURF_SKY | SURF_TRANS33 | SURF_TRANS66 | SURF_WARP)) == 0
	// 		&& "RenderLightMappedPoly mustn't be called with transparent, sky or warping surfaces!");

	// Any dynamic lights on this surface?
	for (int map = 0; map < MAX_LIGHTMAPS_PER_SURFACE && surf.styles[map] != 255; map++) {
		lmScales[map][0] = webgl_newrefdef.lightstyles[surf.styles[map]].rgb[0];
		lmScales[map][1] = webgl_newrefdef.lightstyles[surf.styles[map]].rgb[1];
		lmScales[map][2] = webgl_newrefdef.lightstyles[surf.styles[map]].rgb[2];
		lmScales[map][3] = 1.0;
	}

	c_brush_polys++;

	WebGL_Bind(image.texture);
	WebGL_BindLightmap(surf.lightmaptexturenum);

	if ((surf.texinfo.flags & SURF_FLOWING) != 0) {
		WebGL_UseProgram(glstate.si3DlmFlow.shaderProgram);
		_UpdateLMscales(lmScales, glstate.si3DlmFlow);
		WebGL_DrawGLFlowingPoly(surf);
	}
	else
	{
		WebGL_UseProgram(glstate.si3Dlm.shaderProgram);
		_UpdateLMscales(lmScales, glstate.si3Dlm);
		WebGL_DrawGLPoly(surf);
	}
}

_DrawInlineBModel() {
  final model = currentmodel as webglbrushmodel_t;

	/* calculate dynamic lighting for bmodel */
	for (int k = 0; k < webgl_newrefdef.dlights.length; k++) {
		WebGL_MarkLights(webgl_newrefdef.dlights[k], 1 << k, model.nodes[model.firstnode]);
	}


	if ((currententity.flags & RF_TRANSLUCENT) != 0) {
		gl.enable(WebGL.BLEND);
		/* TODO: should I care about the 0.25 part? we'll just set alpha to 0.33 or 0.66 depending on surface flag..
		glColor4f(1, 1, 1, 0.25);
		R_TexEnv(GL_MODULATE);
		*/
	}

	/* draw texture */
	for (int i = 0; i < model.nummodelsurfaces; i++) {
	  var psurf = model.surfaces[model.firstmodelsurface + i];

		/* find which side of the node we are on */
		var pplane = psurf.plane;

		var dot = DotProduct(_modelorg, pplane.normal) - pplane.dist;

		/* draw the polygon */
		if (((psurf.flags & SURF_PLANEBACK) != 0 && (dot < -_BACKFACE_EPSILON)) ||
			((psurf.flags & SURF_PLANEBACK) == 0 && (dot > _BACKFACE_EPSILON))) {
			if ((psurf.texinfo.flags & (SURF_TRANS33 | SURF_TRANS66)) != 0) {
				/* add to the translucent chain */
				psurf.texturechain = _webgl_alpha_surfaces;
				_webgl_alpha_surfaces = psurf;
			} else if ((psurf.flags & SURF_DRAWTURB) == 0) {
				_SetAllLightFlags(psurf);
				_RenderLightmappedPoly(psurf);
			} else {
				_RenderBrushPoly(psurf);
			}
		}
	}

	if ((currententity.flags & RF_TRANSLUCENT) != 0) {
		gl.disable(WebGL.BLEND);
	}
}

WebGL_DrawBrushModel(entity_t e) {

  final model = currentmodel as webglbrushmodel_t;

	if (model.nummodelsurfaces == 0) {
		return;
	}

	currententity = e;
	glstate.currenttexture = null;
  bool rotated;
  List<double> mins = [0,0,0];
  List<double> maxs = [0,0,0];

	if (e.angles[0] != 0 || e.angles[1] != 0 || e.angles[2] != 0) {
		rotated = true;

		for (int i = 0; i < 3; i++) {
			mins[i] = e.origin[i] - model.radius;
			maxs[i] = e.origin[i] + model.radius;
		}
	}
	else
	{
		rotated = false;
		VectorAdd(e.origin, currentmodel.mins, mins);
		VectorAdd(e.origin, currentmodel.maxs, maxs);
	}

	if (_CullBox(mins, maxs)) {
		return;
	}

	if (gl_zfix.boolean) {
		gl.enable(WebGL.POLYGON_OFFSET_FILL);
	}

	VectorSubtract(webgl_newrefdef.vieworg, e.origin, _modelorg);

	if (rotated) {
		List<double> temp = List.generate(3, (i) => _modelorg[i]);
    List<double> forward = [0,0,0];
    List<double> right = [0,0,0];
    List<double> up = [0,0,0];

		AngleVectors(e.angles, forward, right, up);
		_modelorg[0] = DotProduct(temp, forward);
		_modelorg[1] = -DotProduct(temp, right);
		_modelorg[2] = DotProduct(temp, up);
	}

	//glPushMatrix();
	var oldMat = glstate.uni3DData.transModelMat4;

	e.angles[0] = -e.angles[0];
	e.angles[2] = -e.angles[2];
	WebGL_RotateForEntity(e);
	e.angles[0] = -e.angles[0];
	e.angles[2] = -e.angles[2];

	_DrawInlineBModel();

	// glPopMatrix();
	glstate.uni3DData.transModelMat4 = oldMat;
	WebGL_UpdateUBO3D();

	if (gl_zfix.boolean) {
		gl.disable(WebGL.POLYGON_OFFSET_FILL);
	}
}

_RecursiveWorldNode(webglbrushmodel_t model, mleafornode_t anode) {
  
	if (anode.contents == CONTENTS_SOLID) {
		return; /* solid */
	}

	if (anode.visframe != webgl_visframecount) {
		return;
	}

	if (_CullBox(anode.minmaxs, anode.minmaxs.sublist(3))) {
		return;
	}

	/* if a leaf node, draw stuff */
	if (anode.contents != -1) {
		mleaf_t pleaf = anode as mleaf_t;

		/* check for door connected areas */
		if (webgl_newrefdef.areabits != null) {
			if ((webgl_newrefdef.areabits[pleaf.area >> 3] & (1 << (pleaf.area & 7))) == 0) {
				return; /* not visible */
			}
		}

		int mark = pleaf.firstmarksurface;
		int c = pleaf.nummarksurfaces;

		if (c > 0)
		{
			do
			{
        int o = model.marksurfaces[mark];
				model.surfaces[o].visframe = webgl_framecount;
				mark++;
			}
			while (--c > 0);
		}

		return;
	}

  mnode_t node = anode as mnode_t;
	/* node is just a decision point, so go down the apropriate
	   sides find which side of the node we are on */
	var plane = node.plane;


  double dot;
	switch (plane.type)
	{
		case PLANE_X:
			dot = _modelorg[0] - plane.dist;
			break;
		case PLANE_Y:
			dot = _modelorg[1] - plane.dist;
			break;
		case PLANE_Z:
			dot = _modelorg[2] - plane.dist;
			break;
		default:
			dot = DotProduct(_modelorg, plane.normal) - plane.dist;
			break;
	}

  int side, sidebit;
	if (dot >= 0) {
		side = 0;
		sidebit = 0;
	} else {
		side = 1;
		sidebit = SURF_PLANEBACK;
	}

	/* recurse down the children, front side first */
	_RecursiveWorldNode(model, node.children[side]);

	/* draw stuff */
	for (int c = 0; c < node.numsurfaces; c++) {
		var surf = webgl_worldmodel.surfaces[node.firstsurface + c];
		if (surf.visframe != webgl_framecount) {
			continue;
		}

		if ((surf.flags & SURF_PLANEBACK) != sidebit) {
			continue; /* wrong side */
		}

    _nodecounter2++;
		if ((surf.texinfo.flags & SURF_SKY) != 0) {
			/* just adds to visible sky bounds */
			WebGL_AddSkySurface(surf);
		}
		else if ((surf.texinfo.flags & (SURF_TRANS33 | SURF_TRANS66)) != 0) {
			/* add to the translucent chain */
			surf.texturechain = _webgl_alpha_surfaces;
			_webgl_alpha_surfaces = surf;
			_webgl_alpha_surfaces.texinfo.image = _TextureAnimation(surf.texinfo);
		} else {
			// calling RenderLightmappedPoly() here probably isn't optimal, rendering everything
			// through texturechains should be faster, because far less glBindTexture() is needed
			// (and it might allow batching the drawcalls of surfaces with the same texture)
      /* the polygon is visible, so add it to the texture sorted chain */
      var image = _TextureAnimation(surf.texinfo);
      surf.texturechain = image.texturechain;
      image.texturechain = surf;
		}
	}

	/* recurse down the back side */
	_RecursiveWorldNode(model, node.children[side ^ 1]);
}

int _nodecounter;
int _nodecounter2;

WebGL_DrawWorld() {

	if (!r_drawworld.boolean) {
		return;
	}

	if ((webgl_newrefdef.rdflags & RDF_NOWORLDMODEL) != 0) {
		return;
	}

	currentmodel = webgl_worldmodel;

  _modelorg.setAll(0, webgl_newrefdef.vieworg);

	/* auto cycle the world frame for texture animation */
  final ent = entity_t();
	ent.frame = (webgl_newrefdef.time * 2).toInt();
	currententity = ent;

	glstate.currenttexture = null;

  _nodecounter = 0;
  _nodecounter2 = 0;

	WebGL_ClearSkyBox();
	_RecursiveWorldNode(webgl_worldmodel, webgl_worldmodel.nodes[0]);
	_DrawTextureChains();
	WebGL_DrawSkyBox();
	// DrawTriangleOutlines();

	currententity = null;
}


/*
 * Mark the leaves and nodes that are
 * in the PVS for the current cluster
 */
WebGL_MarkLeaves() {

	if ((webgl_oldviewcluster == webgl_viewcluster) &&
		  (webgl_oldviewcluster2 == webgl_viewcluster2) &&
		  !r_novis.boolean &&
		  (webgl_viewcluster != -1)) {
		return;
	}

	/* development aid to let you run around
	   and see exactly where the pvs ends */
	if (r_lockpvs.boolean) {
		return;
	}

	webgl_visframecount++;
	webgl_oldviewcluster = webgl_viewcluster;
	webgl_oldviewcluster2 = webgl_viewcluster2;

	if (r_novis.boolean || (webgl_viewcluster == -1) || webgl_worldmodel.vis == null) {
		/* mark everything */
		for (int i = 0; i < webgl_worldmodel.numleafs; i++) {
			webgl_worldmodel.leafs[i].visframe = webgl_visframecount;
		}

		for (int i = 0; i < webgl_worldmodel.nodes.length; i++) {
			webgl_worldmodel.nodes[i].visframe = webgl_visframecount;
		}

		return;
	}

	var vis = WebGL_Mod_ClusterPVS(webgl_viewcluster, webgl_worldmodel);

	/* may have to combine two clusters because of solid water boundaries */
	if (webgl_viewcluster2 != webgl_viewcluster) {
    Uint8List fatvis = Uint8List(MAX_MAP_LEAFS ~/ 8);
    fatvis.setAll(0, vis);
		vis = WebGL_Mod_ClusterPVS(webgl_viewcluster2, webgl_worldmodel);
		int c = (webgl_worldmodel.numleafs + 7) ~/ 8;

		for (int i = 0; i < c; i++) {
			fatvis[i] |= vis[i];
		}
		vis = fatvis;
	}

	for (int i = 0; i < webgl_worldmodel.numleafs; i++) {
    var leaf = webgl_worldmodel.leafs[i];
		var cluster = leaf.cluster;

		if (cluster == -1) {
			continue;
		}

		if ((vis[cluster >> 3] & (1 << (cluster & 7))) != 0) {
			mleafornode_t node = leaf;

			do
			{
				if (node.visframe == webgl_visframecount) {
					break;
				}

				node.visframe = webgl_visframecount;
				node = node.parent;
			} while (node != null);
		}
	}
}
