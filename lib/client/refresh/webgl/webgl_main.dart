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
 * Refresher setup and main part of the frame generation, for WebGL2
 *
 * =======================================================================
 */
import 'dart:html';
import 'dart:math';
import 'dart:typed_data';
import 'dart:web_gl';
import 'package:dQuakeWeb/client/vid/ref.dart';
import 'package:dQuakeWeb/client/vid/vid.dart' show viddef, VID_GetModeInfo;
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/shared/files.dart';
import 'local.dart';
import 'webgl_misc.dart';
import 'webgl_shaders.dart';
import 'webgl_draw.dart';
import 'HMM.dart';
import 'webgl_model.dart';
import 'webgl_image.dart';
import 'webgl_mesh.dart';
import 'webgl_surf.dart';
import 'webgl_light.dart';
import 'webgl_warp.dart' show WebGL_SetSky;

// Yaw-Pitch-Roll
// equivalent to R_z * R_y * R_x where R_x is the trans matrix for rotating around X axis for aroundXdeg
Float32List rotAroundAxisZYX(double aroundZdeg, double aroundYdeg, double aroundXdeg)
{
	// Naming of variables is consistent with http://planning.cs.uiuc.edu/node102.html
	// and https://de.wikipedia.org/wiki/Roll-Nick-Gier-Winkel#.E2.80.9EZY.E2.80.B2X.E2.80.B3-Konvention.E2.80.9C
	final alpha = HMM_ToRadians(aroundZdeg);
	final beta = HMM_ToRadians(aroundYdeg);
	final gamma = HMM_ToRadians(aroundXdeg);

	final sinA = sin(alpha);
	final cosA = cos(alpha);
	// TODO: or sincosf(alpha, &sinA, &cosA); ?? (not a standard function)
	final sinB = sin(beta);
	final cosB = cos(beta);
	final sinG = sin(gamma);
	final cosG = cos(gamma);

	return Float32List.fromList([
		cosA*cosB,                  sinA*cosB,                   -sinB,    0, // first *column*
		cosA*sinB*sinG - sinA*cosG, sinA*sinB*sinG + cosA*cosG, cosB*sinG, 0,
		cosA*sinB*cosG + sinA*sinG, sinA*sinB*cosG - cosA*sinG, cosB*cosG, 0,
		 0,                          0,                          0,        1
  ]);
}


WebGL_RotateForEntity(entity_t e) {
	// angles: pitch (around y), yaw (around z), roll (around x)
	// rot matrices to be multiplied in order Z, Y, X (yaw, pitch, roll)
	final transMat = rotAroundAxisZYX(e.angles[1], -e.angles[0], -e.angles[2]);

	for(int i=0; i<3; ++i) {
		transMat[3 * 4 + i] = e.origin[i]; // set translation
	}

	glstate.uni3DData.transModelMat4 = HMM_MultiplyMat4(glstate.uni3DData.transModelMat4, transMat);

	WebGL_UpdateUBO3D();
}


WebGL_Strings() {
  glconfig.stencil = gl.getParameter(WebGL.STENCIL_BITS) == 8;
	Com_Printf("GL_VENDOR: ${glconfig.vendor_string}\n");
	Com_Printf("GL_RENDERER: ${glconfig.renderer_string}\n");
	Com_Printf("GL_VERSION: ${glconfig.version_string}\n");
	Com_Printf("GL_SHADING_LANGUAGE_VERSION: ${glconfig.glsl_version_string}\n");
  Com_Printf("Stencil bits ${gl.getParameter(WebGL.STENCIL_BITS)}\n");

  final extensions = gl.getSupportedExtensions();
	
	Com_Printf("GL_EXTENSIONS:");
	for(String ext in extensions) {
	  Com_Printf(" $ext");
	}
	Com_Printf("\n");
}


WebGL_Register()
{
	gl_lefthand = Cvar_Get("hand", "0", CVAR_USERINFO | CVAR_ARCHIVE);
	r_gunfov = Cvar_Get("r_gunfov", "80", CVAR_ARCHIVE);
	r_farsee = Cvar_Get("r_farsee", "0", CVAR_LATCH | CVAR_ARCHIVE);

	gl_drawbuffer = Cvar_Get("gl_drawbuffer", "GL_BACK", 0);
	r_vsync = Cvar_Get("r_vsync", "1", CVAR_ARCHIVE);
	gl_retexturing = Cvar_Get("gl_retexturing", "1", CVAR_ARCHIVE);
	gl3_debugcontext = Cvar_Get("gl3_debugcontext", "0", 0);
	r_mode = Cvar_Get("r_mode", "4", CVAR_ARCHIVE);
	r_customwidth = Cvar_Get("r_customwidth", "1024", CVAR_ARCHIVE);
	r_customheight = Cvar_Get("r_customheight", "768", CVAR_ARCHIVE);
	gl3_particle_size = Cvar_Get("gl3_particle_size", "40", CVAR_ARCHIVE);
	gl3_particle_fade_factor = Cvar_Get("gl3_particle_fade_factor", "1.2", CVAR_ARCHIVE);
	gl3_particle_square = Cvar_Get("gl3_particle_square", "0", CVAR_ARCHIVE);

	//  0: use lots of calls to glBufferData()
	//  1: reduce calls to glBufferData() with one big VBO (see GL3_BufferAndDraw3D())
	// -1: auto (let yq2 choose to enable/disable this based on detected driver)
	gl3_usebigvbo = Cvar_Get("gl3_usebigvbo", "-1", CVAR_ARCHIVE);

	r_norefresh = Cvar_Get("r_norefresh", "0", 0);
	r_drawentities = Cvar_Get("r_drawentities", "1", 0);
	r_drawworld = Cvar_Get("r_drawworld", "1", 0);
	r_fullbright = Cvar_Get("r_fullbright", "0", 0);

	/* don't bilerp characters and crosshairs */
	gl_nolerp_list = Cvar_Get("gl_nolerp_list", "pics/conchars.pcx pics/ch1.pcx pics/ch2.pcx pics/ch3.pcx", 0);
	gl_nobind = Cvar_Get("gl_nobind", "0", 0);

	gl_texturemode = Cvar_Get("gl_texturemode", "GL_LINEAR_MIPMAP_NEAREST", CVAR_ARCHIVE);
	gl_anisotropic = Cvar_Get("gl_anisotropic", "0", CVAR_ARCHIVE);

	vid_fullscreen = Cvar_Get("vid_fullscreen", "0", CVAR_ARCHIVE);
	vid_gamma = Cvar_Get("vid_gamma", "1.2", CVAR_ARCHIVE);
	gl3_intensity = Cvar_Get("gl3_intensity", "1.5", CVAR_ARCHIVE);
	gl3_intensity_2D = Cvar_Get("gl3_intensity_2D", "1.5", CVAR_ARCHIVE);

	r_lightlevel = Cvar_Get("r_lightlevel", "0", 0);
	gl3_overbrightbits = Cvar_Get("gl3_overbrightbits", "1.3", CVAR_ARCHIVE);

	gl_lightmap = Cvar_Get("gl_lightmap", "0", 0);
	gl_shadows = Cvar_Get("gl_shadows", "0", CVAR_ARCHIVE);

	r_modulate = Cvar_Get("r_modulate", "1", CVAR_ARCHIVE);
	gl_zfix = Cvar_Get("gl_zfix", "0", 0);
	r_clear = Cvar_Get("r_clear", "0", 0);
	gl_cull = Cvar_Get("gl_cull", "1", 0);
	r_lockpvs = Cvar_Get("r_lockpvs", "0", 0);
	r_novis = Cvar_Get("r_novis", "0", 0);
	r_speeds = Cvar_Get("r_speeds", "0", 0);
	gl_finish = Cvar_Get("gl_finish", "0", CVAR_ARCHIVE);

	// ri.Cmd_AddCommand("imagelist", GL3_ImageList_f);
	// ri.Cmd_AddCommand("screenshot", GL3_ScreenShot);
	// ri.Cmd_AddCommand("modellist", GL3_Mod_Modellist_f);
	// ri.Cmd_AddCommand("gl_strings", GL3_Strings);
}

bool WebGL_SetMode() {
	Com_Printf( "setting mode ${r_mode.integer}:");
  final info = VID_GetModeInfo(r_mode.integer);
  if (info == null) {
    return false;
  }
  Com_Printf( " ${info.width} ${info.height}\n");
  vid_fullscreen.modified = false;
  r_mode.modified = false;
  viddef.width = info.width;
  viddef.height = info.height;
  canvas.height = info.height;
  canvas.width = info.width;
  return true;
}

// assumes gl3state.v[ab]o3D are bound
// buffers and draws gl3_3D_vtx_t vertices
// drawMode is something like GL_TRIANGLE_STRIP or GL_TRIANGLE_FAN or whatever
WebGL_BufferAndDraw3D(dynamic verts, int numVerts, int drawMode)
{
	// if(!gl3config.useBigVBO)
	// {
		gl.bufferData( WebGL.ARRAY_BUFFER, verts, WebGL.STREAM_DRAW );
		gl.drawArrays( drawMode, 0, numVerts );
	// }
	// else // gl3config.useBigVBO == true
	// {
		/*
		 * For some reason, AMD's Windows driver doesn't seem to like lots of
		 * calls to glBufferData() (some of them seem to take very long then).
		 * GL3_BufferAndDraw3D() is called a lot when drawing world geometry
		 * (once for each visible face I think?).
		 * The simple code above caused noticeable slowdowns - even a fast
		 * quadcore CPU and a Radeon RX580 weren't able to maintain 60fps..
		 * The workaround is to not call glBufferData() with small data all the time,
		 * but to allocate a big buffer and on each call to GL3_BufferAndDraw3D()
		 * to use a different region of that buffer, resulting in a lot less calls
		 * to glBufferData() (=> a lot less buffer allocations in the driver).
		 * Only when the buffer is full and at the end of a frame (=> GL3_EndFrame())
		 * we get a fresh buffer.
		 *
		 * BTW, we couldn't observe this kind of problem with any other driver:
		 * Neither nvidias driver, nor AMDs or Intels Open Source Linux drivers,
		 * not even Intels Windows driver seem to care that much about the
		 * glBufferData() calls.. However, at least nvidias driver doesn't like
		 * this workaround (with glMapBufferRange()), the framerate dropped
		 * significantly - that's why both methods are available and
		 * selectable at runtime.
		 */
// 		int curOffset = gl3state.vbo3DcurOffset;
// 		int neededSize = numVerts*sizeof(gl3_3D_vtx_t);
// 		if(curOffset+neededSize > gl3state.vbo3Dsize)
// 		{
// 			// buffer is full, need to start again from the beginning
// 			// => need to sync or get fresh buffer
// 			// (getting fresh buffer seems easier)
// 			glBufferData(GL_ARRAY_BUFFER, gl3state.vbo3Dsize, NULL, GL_STREAM_DRAW);
// 			curOffset = 0;
// 		}

// 		// as we make sure to use a previously unused part of the buffer,
// 		// doing it unsynchronized should be safe..
// 		GLbitfield accessBits = GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_RANGE_BIT | GL_MAP_UNSYNCHRONIZED_BIT;
// 		void* data = glMapBufferRange(GL_ARRAY_BUFFER, curOffset, neededSize, accessBits);
// 		memcpy(data, verts, neededSize);
// 		glUnmapBuffer(GL_ARRAY_BUFFER);

// 		glDrawArrays(drawMode, curOffset/sizeof(gl3_3D_vtx_t), numVerts);

// 		gl3state.vbo3DcurOffset = curOffset + neededSize; // TODO: padding or sth needed?
// 	}
}

class part_vtx {
	set pos (List<double> val)  {
    assert(val.length >= 3);
    this.data.setAll(0, val.sublist(0, 3));
  }
  set size(double val) {
    data[3] = val;
  }
  set dist(double val) {
    data[4] = val;
  }
	set color (List<double> val)  {
    assert(val.length >= 4);
    this.data.setAll(5, val.sublist(0, 4));
  }
  List<double> data = List(9);
}

_WebGL_DrawNullModel() {
	List<double> shadelight = [1, 1, 1];

	if ((currententity.flags & RF_FULLBRIGHT) == 0) {
		WebGL_LightPoint(currententity.origin, shadelight);
	}

	final origModelMat = glstate.uni3DData.transModelMat4;
	WebGL_RotateForEntity(currententity);

	glstate.uniCommonData.color = [ shadelight[0], shadelight[1], shadelight[2], 1 ];
	WebGL_UpdateUBOCommon();

	WebGL_UseProgram(glstate.si3DcolorOnly.shaderProgram);

	WebGL_BindVAO(glstate.vao3D);
	WebGL_BindVBO(glstate.vbo3D);

  // 11
	List<double> vtxA = [];
  var item = gl3_3D_vtx_t();
  item.pos = Float32List.fromList([0,0,-16]);
  item.lightFlags = 0;
  vtxA.addAll(item.data);

  var item1 = gl3_3D_vtx_t();
  item1.pos = Float32List.fromList([16 * cos( 0 * pi / 2),16 * sin( 0 * pi / 2 ),0]);
  item1.lightFlags = 0;
  vtxA.addAll(item1.data);

  var item2 = gl3_3D_vtx_t();
  item2.pos = Float32List.fromList([16 * cos( 1 * pi / 2),16 * sin( 1 * pi / 2 ),0]);
  item2.lightFlags = 0;
  vtxA.addAll(item2.data);

  var item3 = gl3_3D_vtx_t();
  item3.pos = Float32List.fromList([16 * cos( 2 * pi / 2),16 * sin( 2 * pi / 2 ),0]);
  item3.lightFlags = 0;
  vtxA.addAll(item3.data);

  var item4 = gl3_3D_vtx_t();
  item4.pos = Float32List.fromList([16 * cos( 3 * pi / 2),16 * sin( 3 * pi / 2 ),0]);
  item4.lightFlags = 0;
  vtxA.addAll(item4.data);

  var item5 = gl3_3D_vtx_t();
  item5.pos = Float32List.fromList([16 * cos( 4 * pi / 2),16 * sin( 4 * pi / 2 ),0]);
  item5.lightFlags = 0;
  vtxA.addAll(item5.data);

	WebGL_BufferAndDraw3D(Float32List.fromList(vtxA), 6, WebGL.TRIANGLE_FAN);

	List<double> vtxB = [];
  var itemx = gl3_3D_vtx_t();
  itemx.pos = Float32List.fromList([0,0,16]);
  itemx.lightFlags = 0;
  vtxB.addAll(item.data);
  vtxB.addAll(item5.data);
  vtxB.addAll(item4.data);
  vtxB.addAll(item3.data);
  vtxB.addAll(item2.data);
  vtxB.addAll(item1.data);

	WebGL_BufferAndDraw3D(Float32List.fromList(vtxB), 6, WebGL.TRIANGLE_FAN);

	glstate.uni3DData.transModelMat4 = origModelMat;
	WebGL_UpdateUBO3D();
}

WebGL_DrawParticles() {

  if (webgl_newrefdef.particles.isEmpty) {
    return;
  }

	// TODO: stereo
	//qboolean stereo_split_tb = ((gl_state.stereo_mode == STEREO_SPLIT_VERTICAL) && gl_state.camera_separation);
	//qboolean stereo_split_lr = ((gl_state.stereo_mode == STEREO_SPLIT_HORIZONTAL) && gl_state.camera_separation);

	//if (!(stereo_split_tb || stereo_split_lr))
	{
		int i;
		// int numParticles = webgl_newrefdef.num_particles;
		// unsigned char color[4];
		// const particle_t *p;
		// assume the size looks good with window height 480px and scale according to real resolution
		double pointSize = gl3_particle_size.value * webgl_newrefdef.height/480.0;

		// assert(sizeof(part_vtx)==9*sizeof(float)); // remember to update GL3_SurfInit() if this changes!

		// part_vtx buf[numParticles];
    List<double> buf = [];

		// // TODO: viewOrg could be in UBO
		// vec3_t viewOrg;
    List<double> viewOrg = List.generate(3, (i) => webgl_newrefdef.vieworg[i]);

		gl.depthMask(false);
		gl.enable(WebGL.BLEND);
		// // gl.enable(WebGL.PROGRAM_POINT_SIZE);

		WebGL_UseProgram(glstate.siParticle.shaderProgram);

		for ( var p in webgl_newrefdef.particles ) {
      var cur = part_vtx();
      final color = p.color & 0xFF;
		// 	*(int *) color = d_8to24table [ p->color & 0xFF ];
      List<double> offset = [0,0,0];
			VectorSubtract(viewOrg, p.origin, offset);

      cur.pos = p.origin;
			cur.size = pointSize;
			cur.dist = VectorLength(offset);
      List<double> col = [0,0,0,0];
			for(int j=0; j<3; ++j)  {
        col[j] = colorMap[(color * 3) + j] / 255.0;
      }
			col[3] = p.alpha;
      cur.color = col;
      buf.addAll(cur.data);
		}

		WebGL_BindVAO(glstate.vaoParticle);
		WebGL_BindVBO(glstate.vboParticle);
		gl.bufferData(WebGL.ARRAY_BUFFER, Float32List.fromList(buf), WebGL.STREAM_DRAW);
		gl.drawArrays(WebGL.POINTS, 0, webgl_newrefdef.particles.length);


		gl.disable(WebGL.BLEND);
		gl.depthMask(true);
		// gl.disable(WebGL.PROGRAM_POINT_SIZE);
	}
}

WebGL_DrawEntitiesOnList() {
	// int i;

	if (!r_drawentities.boolean) {
		return;
	}

	// GL3_ResetShadowAliasModels();

	/* draw non-transparent first */
	for (int i = 0; i < webgl_newrefdef.entities.length; i++) {
		currententity = webgl_newrefdef.entities[i];

		if ((currententity.flags & RF_TRANSLUCENT) != 0) {
			continue; /* solid */
		}

		if ((currententity.flags & RF_BEAM) != 0) {
	// 		GL3_DrawBeam(currententity);
		} else {
			currentmodel = currententity.model;

			if (currentmodel == null) {
				_WebGL_DrawNullModel();
				continue;
			}

			switch (currentmodel.type){
				case modtype_t.mod_alias:
					WebGL_DrawAliasModel(currententity);
					break;
				case modtype_t.mod_brush:
					WebGL_DrawBrushModel(currententity);
					break;
				// case modtype_t.mod_sprite:
	// 				GL3_DrawSpriteModel(currententity);
					// break;
				default:
					Com_Error(ERR_DROP, "Bad modeltype");
					break;
			}
		}
	}

	/* draw transparent entities
	   we could sort these if it ever
	   becomes a problem... */
	gl.depthMask(false);

	for (int i = 0; i < webgl_newrefdef.entities.length; i++) {
		currententity = webgl_newrefdef.entities[i];

		if ((currententity.flags & RF_TRANSLUCENT) == 0) {
			continue; /* solid */
		}

		if ((currententity.flags & RF_BEAM) != 0) {
	// 		GL3_DrawBeam(currententity);
		} else {
			currentmodel = currententity.model;

			if (currentmodel == null) {
				_WebGL_DrawNullModel();
				continue;
			}

			switch (currentmodel.type) {
				case modtype_t.mod_alias:
					WebGL_DrawAliasModel(currententity);
					break;
				case modtype_t.mod_brush:
					WebGL_DrawBrushModel(currententity);
					break;
				// case mod_sprite:
				// 	GL3_DrawSpriteModel(currententity);
				// 	break;
				default:
					Com_Error(ERR_DROP, "Bad modeltype");
					break;
			}
		}
	}

	// GL3_DrawAliasShadows();

	gl.depthMask(true); /* back to writing */

}

int SignbitsForPlane(cplane_t out) {

	/* for fast box on planeside test */
	int bits = 0;

	for (int j = 0; j < 3; j++) {
		if (out.normal[j] < 0) {
			bits |= 1 << j;
		}
	}
	return bits;
}

SetFrustum() {
	/* rotate VPN right by FOV_X/2 degrees */
	RotatePointAroundVector(frustum[0].normal, vup, vpn,
			-(90 - webgl_newrefdef.fov_x / 2));
	/* rotate VPN left by FOV_X/2 degrees */
	RotatePointAroundVector(frustum[1].normal,
			vup, vpn, 90 - webgl_newrefdef.fov_x / 2);
	/* rotate VPN up by FOV_X/2 degrees */
	RotatePointAroundVector(frustum[2].normal,
			vright, vpn, 90 - webgl_newrefdef.fov_y / 2);
	/* rotate VPN down by FOV_X/2 degrees */
	RotatePointAroundVector(frustum[3].normal, vright, vpn,
			-(90 - webgl_newrefdef.fov_y / 2));

	for (int i = 0; i < 4; i++) {
		frustum[i].type = PLANE_ANYZ;
		frustum[i].dist = DotProduct(webgl_origin, frustum[i].normal);
		frustum[i].signbits = SignbitsForPlane(frustum[i]);
	}
}


SetupFrame() {

	webgl_framecount++;

	/* build the transformation matrix for the given view angles */
  webgl_origin.setAll(0, webgl_newrefdef.vieworg);

	AngleVectors(webgl_newrefdef.viewangles, vpn, vright, vup);

	/* current viewcluster */
	if ((webgl_newrefdef.rdflags & RDF_NOWORLDMODEL) == 0) {
		webgl_oldviewcluster = webgl_viewcluster;
		webgl_oldviewcluster2 = webgl_viewcluster2;
		var leaf = WebGL_Mod_PointInLeaf(webgl_origin, webgl_worldmodel);
		webgl_viewcluster = webgl_viewcluster2 = leaf.cluster;

		/* check above and below so crossing solid water doesn't draw wrong */
		if (leaf.contents == 0) {
			/* look down a bit */
      List<double> temp = List.generate(3, (i) => webgl_origin[i]);
			temp[2] -= 16;
			leaf = WebGL_Mod_PointInLeaf(temp, webgl_worldmodel);

			if ((leaf.contents & CONTENTS_SOLID) == 0&&
				(leaf.cluster != webgl_viewcluster2)) {
				webgl_viewcluster2 = leaf.cluster;
			}
		} else {
			/* look up a bit */
      List<double> temp = List.generate(3, (i) => webgl_origin[i]);
			temp[2] += 16;
			leaf = WebGL_Mod_PointInLeaf(temp, webgl_worldmodel);

			if ((leaf.contents & CONTENTS_SOLID) == 0 &&
				(leaf.cluster != webgl_viewcluster2)) {
				webgl_viewcluster2 = leaf.cluster;
			}
		}
	}

	for (int i = 0; i < 4; i++) {
		v_blend[i] = webgl_newrefdef.blend[i];
	}

	c_brush_polys = 0;
	c_alias_polys = 0;

	/* clear out the portion of the screen that the NOWORLDMODEL defines */
	if ((webgl_newrefdef.rdflags & RDF_NOWORLDMODEL) != 0) {
		gl.enable(WebGL.SCISSOR_TEST);
		gl.clearColor(0.3, 0.3, 0.3, 1);
		gl.scissor(webgl_newrefdef.x,
				viddef.height - webgl_newrefdef.height - webgl_newrefdef.y,
				webgl_newrefdef.width, webgl_newrefdef.height);
		gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
		gl.clearColor(1, 0, 0.5, 0.5);
		gl.disable(WebGL.SCISSOR_TEST);
	}
}

WebGL_SetGL2D() {
	int x = 0;
	int w = viddef.width;
	int y = 0;
	int h = viddef.height;

	gl.viewport(x, y, w, h);

	final transMatr = HMM_Orthographic(0, viddef.width.toDouble(), viddef.height.toDouble(), 0, -99999, 99999);

	glstate.uni2DData.transMat4 = transMatr;

	WebGL_UpdateUBO2D();

	gl.disable(WebGL.DEPTH_TEST);
	gl.disable(WebGL.CULL_FACE);
	gl.disable(WebGL.BLEND);
}

// equivalent to R_x * R_y * R_z where R_x is the trans matrix for rotating around X axis for aroundXdeg
Float32List rotAroundAxisXYZ(double aroundXdeg, double aroundYdeg, double aroundZdeg) {
	final alpha = HMM_ToRadians(aroundXdeg);
	final beta = HMM_ToRadians(aroundYdeg);
	final gamma = HMM_ToRadians(aroundZdeg);

	final sinA = sin(alpha);
	final cosA = cos(alpha);
	final sinB = sin(beta);
	final cosB = cos(beta);
	final sinG = sin(gamma);
	final cosG = cos(gamma);

	return Float32List.fromList([
		cosB*cosG,  sinA*sinB*cosG + cosA*sinG, -cosA*sinB*cosG + sinA*sinG, 0, // first *column*
		-cosB*sinG, -sinA*sinB*sinG + cosA*cosG,  cosA*sinB*sinG + sinA*cosG, 0,
		sinB,      -sinA*cosB,                   cosA*cosB,                  0,
		 0,          0,                           0,                          1
  ]);
}


// equivalent to R_MYgluPerspective() but returning a matrix instead of setting internal OpenGL state
Float32List WebGL_MYgluPerspective(double fovy, double aspect, double zNear, double zFar)
{
	// calculation of left, right, bottom, top is from R_MYgluPerspective() of old gl backend
	// which seems to be slightly different from the real gluPerspective()
	// and thus also from HMM_Perspective()
	// GLdouble left, right, bottom, top;
	// float A, B, C, D;

	final top = zNear * tan(fovy * pi / 360.0);
	final bottom = -top;

	final left = bottom * aspect;
	final right = top * aspect;

	// TODO:  stereo stuff
	// left += - gl1_stereo_convergence->value * (2 * gl_state.camera_separation) / zNear;
	// right += - gl1_stereo_convergence->value * (2 * gl_state.camera_separation) / zNear;

	// the following emulates glFrustum(left, right, bottom, top, zNear, zFar)
	// see https://www.khronos.org/registry/OpenGL-Refpages/gl2.1/xhtml/glFrustum.xml
	final A = (right+left)/(right-left);
	final B = (top+bottom)/(top-bottom);
	final C = -(zFar+zNear)/(zFar-zNear);
	final D = -(2.0*zFar*zNear)/(zFar-zNear);

	return Float32List.fromList([
		(2.0*zNear)/(right-left), 0, 0, 0, // first *column*
		0, (2.0*zNear)/(top-bottom), 0, 0,
		A, B, C, -1.0,
		0, 0, D, 0
	]);
}

SetupGL() {

	/* set up viewport */
	final x = (webgl_newrefdef.x * viddef.width / viddef.width).floor();
	final x2 = ((webgl_newrefdef.x + webgl_newrefdef.width) * viddef.width / viddef.width).ceil();
	final y = (viddef.height - webgl_newrefdef.y * viddef.height / viddef.height).floor();
	final y2 = (viddef.height - (webgl_newrefdef.y + webgl_newrefdef.height) * viddef.height / viddef.height).ceil();

	final w = x2 - x;
	final h = y - y2;

	gl.viewport(x, y2, w, h);

	/* set up projection matrix (eye coordinates -> clip coordinates) */
	{
		final screenaspect = webgl_newrefdef.width / webgl_newrefdef.height;
		double dist = r_farsee.boolean ? 8192 : 4096;
		glstate.uni3DData.transProjMat4 = WebGL_MYgluPerspective(webgl_newrefdef.fov_y, screenaspect, 4, dist);
	}

	gl.cullFace(WebGL.FRONT);

	/* set up view matrix (world coordinates -> eye coordinates) */
	// {
		// first put Z axis going up
		var viewMat = Float32List.fromList([
			  0, 0, -1, 0, // first *column* (the matrix is colum-major)
			 -1, 0,  0, 0,
			  0, 1,  0, 0,
			  0, 0,  0, 1
    ]);

		// now rotate by view angles
		var rotMat = rotAroundAxisXYZ(-webgl_newrefdef.viewangles[2], -webgl_newrefdef.viewangles[0], -webgl_newrefdef.viewangles[1]);

		viewMat = HMM_MultiplyMat4( viewMat, rotMat );

		// .. and apply translation for current position
		Float32List trans = Float32List.fromList([-webgl_newrefdef.vieworg[0], -webgl_newrefdef.vieworg[1], -webgl_newrefdef.vieworg[2]]);
		viewMat = HMM_MultiplyMat4( viewMat, HMM_Translate(trans) );

		glstate.uni3DData.transViewMat4 = viewMat;
	// }

	glstate.uni3DData.transModelMat4 = webgl_identityMat4;

	glstate.uni3DData.time = webgl_newrefdef.time;

	WebGL_UpdateUBO3D();

	/* set drawing parms */
	if (gl_cull.boolean) {
		gl.enable(WebGL.CULL_FACE);
	} else {
		gl.disable(WebGL.CULL_FACE);
	}

	gl.enable(WebGL.DEPTH_TEST);
}


/*
 * gl3_newrefdef must be set before the first call
 */
WebGL_RenderView(refdef_t fd) {

	if (r_norefresh.boolean) {
		return;
	}

	webgl_newrefdef = fd;

	if (webgl_worldmodel == null && (webgl_newrefdef.rdflags & RDF_NOWORLDMODEL) == 0) {
		Com_Error(ERR_DROP, "R_RenderView: NULL worldmodel");
	}

	if (r_speeds.boolean) {
		c_brush_polys = 0;
		c_alias_polys = 0;
	}

	WebGL_PushDlights();

	if (gl_finish.boolean) {
		gl.finish();
	}

	SetupFrame();

	SetFrustum();

	SetupGL();

	WebGL_MarkLeaves(); /* done here so we know if we're in water */

	WebGL_DrawWorld();

	WebGL_DrawEntitiesOnList();

	// kick the silly gl1_flashblend poly lights
	// GL3_RenderDlights();

	WebGL_DrawParticles();

	WebGL_DrawAlphaSurfaces();

	// Note: R_Flash() is now GL3_Draw_Flash() and called from GL3_RenderFrame()

	if (r_speeds.boolean) {
	  Com_Printf( "$c_brush_polys wpoly $c_alias_polys epoly $c_visible_textures tex $c_visible_lightmaps lmaps\n");
	}
  assert(webgl_worldmodel.nodes[226].firstsurface != 0);

}

WebGL_Clear() {
	if (r_clear.boolean) {
		gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
	} else {
		gl.clear(WebGL.DEPTH_BUFFER_BIT);
	}

	webgldepthmin = 0;
	webgldepthmax = 1;
	gl.depthFunc(WebGL.LEQUAL);

	gl.depthRange(webgldepthmin, webgldepthmax);

	if (gl_zfix.boolean) {
		if (webgldepthmax > webgldepthmin) {
			gl.polygonOffset(0.05, 1);
		} else {
			gl.polygonOffset(-0.05, -1);
		}
	}

	/* stencilbuffer shadows */
	if (gl_shadows.boolean && glconfig.stencil) {
		gl.clearStencil(1);
		gl.clear(WebGL.STENCIL_BUFFER_BIT);
	}
}

WebGL_SetLightLevel() {

	if ((webgl_newrefdef.rdflags & RDF_NOWORLDMODEL) != 0) {
		return;
	}

	/* save off light value for server to look at */
  List<double> shadelight = [0,0,0];
	WebGL_LightPoint(webgl_newrefdef.vieworg, shadelight);

	/* pick the greatest component, which should be the
	 * same as the mono value returned by software */
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


class WebGLExports extends refexport_t {

  @override
  Future<bool> Init() async {

    canvas = querySelector("#quake2-canvas");
    gl = canvas.getContext("webgl2");

	  await WebGL_Draw_GetPalette();

	  WebGL_Register();

	  /* set our "safe" mode */
	  glstate.prev_mode = 4;
	  //gl_state.stereo_mode = gl1_stereo->value;

	  /* create the window and set up the context */
	  if (!WebGL_SetMode()) {
  	  Com_Printf("ref_gl3::R_Init() - could not R_SetMode()\n");
	  	return false;
	  }


    /* get our various GL strings */
    glconfig.vendor_string = gl.getParameter(WebGL.VENDOR);
    glconfig.renderer_string = gl.getParameter(WebGL.RENDERER);
    glconfig.version_string = gl.getParameter(WebGL.VERSION);
    glconfig.glsl_version_string = gl.getParameter(WebGL.SHADING_LANGUAGE_VERSION);

    Com_Printf( "\nOpenGL setting:\n");
    WebGL_Strings();

    Com_Printf("\n\nProbing for OpenGL extensions:\n");

    glconfig.anisotropic = (gl.getExtension('EXT_texture_filter_anisotropic') != null);
    glstate.glsync = gl.fenceSync(WebGL.SYNC_GPU_COMMANDS_COMPLETE, 0);

    /* Anisotropic */
    Com_Printf(" - Anisotropic Filtering: ");

    if(glconfig.anisotropic) {
      glconfig.max_anisotropy = gl.getParameter(ExtTextureFilterAnisotropic.MAX_TEXTURE_MAX_ANISOTROPY_EXT);
      Com_Printf("Max level: ${glconfig.max_anisotropy}x\n");
    } else {
      glconfig.max_anisotropy = 0;
      Com_Printf( "Not supported\n");
    }

    // if(gl3config.debug_output)
    // {
    //   R_Printf(PRINT_ALL, " - OpenGL Debug Output: Supported ");
    //   if(gl3_debugcontext->value == 0.0f)
    //   {
    //     R_Printf(PRINT_ALL, "(but disabled with gl3_debugcontext = 0)\n");
    //   }
    //   else
    //   {
    //     R_Printf(PRINT_ALL, "and enabled with gl3_debugcontext = %i\n", (int)gl3_debugcontext->value);
    //   }
    // }
    // else
    // {
    //   R_Printf(PRINT_ALL, " - OpenGL Debug Output: Not Supported\n");
    // }

    // gl3config.useBigVBO = false;
    // if(gl3_usebigvbo->value == 1.0f)
    // {
    //   R_Printf(PRINT_ALL, "Enabling useBigVBO workaround because gl3_usebigvbo = 1\n");
    //   gl3config.useBigVBO = true;
    // }
    // else if(gl3_usebigvbo->value == -1.0f)
    // {
    //   // enable for AMDs proprietary Windows and Linux drivers
    //   if(gl3config.vendor_string != NULL && strstr(gl3config.vendor_string, "Advanced Micro Devices, Inc.") != NULL)
    //   {
    //     R_Printf(PRINT_ALL, "Detected proprietary AMD GPU driver, enabling useBigVBO workaround\n");
    //     R_Printf(PRINT_ALL, "(consider using the open source RadeonSI drivers, they tend to work better overall)\n");
    //     gl3config.useBigVBO = true;
    //   }
    // }

    // generate texture handles for all possible lightmaps
    glstate.lightmap_textureIDs = List.generate(MAX_LIGHTMAPS, (j) =>
      List.generate(MAX_LIGHTMAPS_PER_SURFACE, (i) => gl.createTexture()));

    WebGL_SetDefaultState();

    if (WebGL_InitShaders()) {
      Com_Printf("Loading shaders succeeded!\n");
    } else {
      Com_Printf("Loading shaders failed!\n");
      return false;
    }

    registration_sequence = 1; // from R_InitImages() (everything else from there shouldn't be needed anymore)

    WebGL_Mod_Init();

    WebGL_InitParticleTexture();

    await WebGL_Draw_InitLocal();

    WebGL_SurfInit();

    Com_Printf("\n");
    return true;
  }

  BeginFrame() {
    /* change modes if necessary */
    if (r_mode.modified) {
      vid_fullscreen.modified = true;
    }

    if (vid_gamma.modified || gl3_intensity.modified || gl3_intensity_2D.modified) {
      vid_gamma.modified = false;
      gl3_intensity.modified = false;
      gl3_intensity_2D.modified = false;

      glstate.uniCommonData.gamma = 1.0/vid_gamma.value;
      glstate.uniCommonData.intensity = gl3_intensity.value;
      glstate.uniCommonData.intensity2D = gl3_intensity_2D.value;
      WebGL_UpdateUBOCommon();
    }

    // in GL3, overbrightbits can have any positive value
    if (gl3_overbrightbits.modified) {
      gl3_overbrightbits.modified = false;

      if(gl3_overbrightbits.value < 0.0) {
        Cvar_Set("gl3_overbrightbits", "0");
      }

      glstate.uni3DData.overbrightbits = (gl3_overbrightbits.value <= 0.0) ? 1.0 : gl3_overbrightbits.value;
      WebGL_UpdateUBO3D();
    }

    if(gl3_particle_fade_factor.modified) {
      gl3_particle_fade_factor.modified = false;
      glstate.uni3DData.particleFadeFactor = gl3_particle_fade_factor.value;
      WebGL_UpdateUBO3D();
    }

    if(gl3_particle_square.modified) {
      gl3_particle_square.modified = false;
      // GL3_RecreateShaders();
    }


    /* go into 2D mode */

    WebGL_SetGL2D();

    /* draw buffer stuff */
    if (gl_drawbuffer.modified) {
      gl_drawbuffer.modified = false;

      // TODO: stereo stuff
      //if ((gl3state.camera_separation == 0) || gl3state.stereo_mode != STEREO_MODE_OPENGL)
      // {
        // if (gl_drawbuffer.string == "GL_FRONT") {
        //   gl.drawBuffer(GL_FRONT);
        // } else {
        //   gl.drawBuffer(GL_BACK);
        // }
      // }
    }

    /* texturemode stuff */
    if (gl_texturemode.modified || (glconfig.anisotropic && gl_anisotropic.modified)) {
      WebGL_TextureMode(gl_texturemode.string);
      gl_texturemode.modified = false;
      gl_anisotropic.modified = false;
    }

    // if (r_vsync->modified)
    // {
    //   r_vsync->modified = false;
    //   GL3_SetVsync();
    // }

    /* clear screen if desired */
    WebGL_Clear();
  }

  @override
  Future<void> RenderFrame (refdef_t fd) async {
    WebGL_RenderView(fd);
	  WebGL_SetLightLevel();
	  WebGL_SetGL2D();

    // if(v_blend[3] != 0.0f) {
    //   int x = (vid.width - gl3_newrefdef.width)/2;
    //   int y = (vid.height - gl3_newrefdef.height)/2;

    //   GL3_Draw_Flash(v_blend, x, y, gl3_newrefdef.width, gl3_newrefdef.height);
    // }
  }

  @override
  Future<void> DrawStretchPic (int x, int y, int w, int h, String name) => WebGL_Draw_StretchPic(x, y, w, h, name);
  @override
  void DrawCharScaled(int x, int y, int num, double scale) => WebGL_Draw_CharScaled(x, y, num, scale);

  @override
  Future<void> EndFrame() async {
    gl.flush();
    await gl.waitSync(glstate.glsync, 0, WebGL.TIMEOUT_IGNORED);
  }

  @override
  void	Shutdown () {
    WebGL_Mod_FreeAll();
    WebGL_ShutdownImages();
    WebGL_SurfShutdown();
    WebGL_Draw_ShutdownLocal();
    WebGL_ShutdownShaders();
  }

  @override
  Future<void>	BeginRegistration (String map) => WebGL_BeginRegistration(map);
  @override
  Future<model_s> RegisterModel (String name) => WebGL_RegisterModel(name);
  @override
  Future<Object> RegisterSkin (String name) => WebGL_FindImage(name, imagetype_t.it_skin);
  @override
  Future<Object> DrawFindPic(String name) => WebGL_Draw_FindPic(name);
  @override
  void DrawFill (int x, int y, int w, int h, int c) => WebGL_Draw_Fill(x, y, w, h, c);
  @override
  Future<void> DrawTileClear (int x, int y, int w, int h, String name) => WebGL_Draw_TileClear(x, y, w, h, name);
  @override
  Future<void> DrawPicScaled (int x, int y, String pic, double factor) => WebGL_Draw_PicScaled(x, y, pic, factor);
  @override
  Future<List<int>> DrawGetPicSize (String name) => WebGL_Draw_GetPicSize(name);
  @override
  Future<void> SetSky (String name, double rotate, List<double> axis) => WebGL_SetSky(name, rotate, axis);
  @override
  void EndRegistration() => WebGL_EndRegistration();
}