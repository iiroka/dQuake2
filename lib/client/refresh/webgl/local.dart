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
 * Local header for the WebGL2 refresher.
 *
 * =======================================================================
 */
import 'dart:html';
import 'dart:typed_data';
import 'dart:web_gl';
import 'package:dQuakeWeb/client/refresh/webgl/webgl_model.dart';
import 'package:dQuakeWeb/client/vid/ref.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/shared/shared.dart';

// attribute locations for vertex shaders
const WEBGL_ATTRIB_POSITION   = 0;
const WEBGL_ATTRIB_TEXCOORD   = 1; // for normal texture
const WEBGL_ATTRIB_LMTEXCOORD = 2; // for lightmap
const WEBGL_ATTRIB_COLOR      = 3; // per-vertex color
const WEBGL_ATTRIB_NORMAL     = 4; // vertex normal
const WEBGL_ATTRIB_LIGHTFLAGS = 5; // uint, each set bit means "dyn light i affects this surface"

class webglconfig_t {
	String renderer_string;
	String vendor_string;
	String version_string;
	String glsl_version_string;

	// int major_version;
	// int minor_version;

	// ----

	bool anisotropic = false; // is GL_EXT_texture_filter_anisotropic supported?
	// qboolean debug_output; // is GL_ARB_debug_output supported?
	bool stencil = false; // Do we have a stencil buffer?

	// qboolean useBigVBO; // workaround for AMDs windows driver for fewer calls to glBufferData()

	// ----

	int max_anisotropy = 0;
}

class gl3ShaderInfo_t {
	Program shaderProgram;
	UniformLocation uniLmScales;
  List<double> lmScales = List(MAX_LIGHTMAPS_PER_SURFACE * 4);
}

class gl3UniCommon_t {
  set gamma(double value) { 
      this.data[0] = value; 
   }   
   double get gamma { 
      return this.data[0]; 
   }   
   set intensity(double value) { 
      this.data[1] = value; 
   }   
   double get intensity { 
      return this.data[1]; 
   }   
   set intensity2D(double value) { 
      this.data[2] = value; 
   }   
   double get intensity2D { 
      return this.data[2]; 
   }   

  // entries of std140 UBOs are aligned to multiples of their own size
  // so we'll need to pad accordingly for following vec4
  // GLfloat _padding;

   set color(List<double> value) { 
      this.data[4] = value[0];
      this.data[5] = value[1];
      this.data[6] = value[2];
      this.data[7] = value[3];
   }   

  Float32List data = Float32List(8);
}

class gl3Uni2D_t {
	set transMat4 (Float32List val)  {
    assert(val.length == 16);
    this.data.setAll(0, val);
  }
  Float32List data = Float32List(16);
}

class gl3Uni3D_t {
	set transProjMat4 (Float32List val)  {
    assert(val.length == 16);
    this.data.setAll(0, val);
  }
  Float32List get transProjMat4 {
    return this.data.sublist(0, 16);
  }

	set transViewMat4 (Float32List val)  {
    assert(val.length == 16);
    this.data.setAll(16, val);
  }
  Float32List get transViewMat4 {
    return this.data.sublist(16, 2*16);
  }

	set transModelMat4 (Float32List val)  {
    assert(val.length == 16);
    this.data.setAll(32, val);
  }
  Float32List get transModelMat4 {
    return this.data.sublist(2*16, 3*16);
  }

   set scroll(double value) {  // for SURF_FLOWING
      this.data[3 * 16] = value; 
   }
   double get scroll {
      return this.data[3 * 16]; 
   }

   set time(double value) {  // for warping surfaces like water & possibly other things
      this.data[3 * 16 + 1] = value; 
   }
   double get time {
      return this.data[3 * 16 + 1]; 
   }

   set alpha(double value) {  // for translucent surfaces (water, glass, ..)
      this.data[3 * 16 + 2] = value; 
   }
   double get alpha {
      return this.data[3 * 16 + 2]; 
   }

   set overbrightbits(double value) {  // gl3_overbrightbits, applied to lightmaps (and elsewhere to models)
      this.data[3 * 16 + 3] = value; 
   }
   set particleFadeFactor(double value) {  // gl3_particle_fade_factor, higher => less fading out towards edges
      this.data[3 * 16 + 4] = value; 
   }

	// 	GLfloat _padding[3]; // again, some padding to ensure this has right size

  Float32List data = Float32List(16 * 3 + 8);
}

class gl3UniDynLight {
	set origin (List<double> val)  {
    assert(val.length == 3);
    this.data.setAll(0, val);
  }
  // GLfloat _padding;
	set color (List<double> val)  {
    assert(val.length == 3);
    this.data.setAll(4, val);
  }
  set intensity(double value) {
    this.data[7] = value; 
  }   
  double get intensity {
    return this.data[7]; 
  }   

  Float32List data = Float32List(gl3UniDynLightSize);
}
const gl3UniDynLightSize = 8;

class gl3UniLights_t {
	// gl3UniDynLight dynLights[MAX_DLIGHTS];
	// GLuint numDynLights;
	// GLfloat _padding[3];
  set numDynLights(int value) {
    this.data.buffer.asByteData(MAX_DLIGHTS * gl3UniDynLightSize).setInt32(0, value);
  }

  setDynLight(int index, gl3UniDynLight dl) {
    this.data.setRange(index * gl3UniDynLightSize, (index + 1) * gl3UniDynLightSize, dl.data);
  }

  Float32List data = Float32List(MAX_DLIGHTS * gl3UniDynLightSize + 4);
}

const BLOCK_WIDTH = 1024;
const BLOCK_HEIGHT = 512;
const LIGHTMAP_BYTES = 4;
const MAX_LIGHTMAPS = 4;
const MAX_LIGHTMAPS_PER_SURFACE = MAX_LIGHTMAPS; // 4

class webglstate_t {
	// TODO: what of this do we need?
	bool fullscreen;

	int prev_mode;

	// unsigned char *d_16to8table;

	// each lightmap consists of 4 sub-lightmaps allowing changing shadows on the same surface
	// used for switching on/off light and stuff like that.
	// most surfaces only have one really and the remaining for are filled with dummy data
	// GLuint lightmap_textureIDs[MAX_LIGHTMAPS][MAX_LIGHTMAPS_PER_SURFACE]; // instead of lightmap_textures+i use lightmap_textureIDs[i]
  List<List<Texture>> lightmap_textureIDs;

	Texture currenttexture; // bound to GL_TEXTURE0
	int currentlightmap = 0; // lightmap_textureIDs[currentlightmap] bound to GL_TEXTURE1
	int currenttmu; // GL_TEXTURE0 or GL_TEXTURE1

	//float camera_separation;
	//enum stereo_modes stereo_mode;

	VertexArrayObject currentVAO;
	Buffer currentVBO;
	Buffer currentEBO;
	Program currentShaderProgram;
	Buffer currentUBO;

	// NOTE: make sure si2D is always the first shaderInfo (or adapt GL3_ShutdownShaders())
	gl3ShaderInfo_t si2D = gl3ShaderInfo_t();      // shader for rendering 2D with textures
	gl3ShaderInfo_t si2Dcolor = gl3ShaderInfo_t(); // shader for rendering 2D with flat colors
	gl3ShaderInfo_t si3Dlm = gl3ShaderInfo_t();        // a regular opaque face (e.g. from brush) with lightmap
	// TODO: lm-only variants for gl_lightmap 1
	gl3ShaderInfo_t si3Dtrans = gl3ShaderInfo_t();     // transparent is always w/o lightmap
	gl3ShaderInfo_t si3DcolorOnly = gl3ShaderInfo_t(); // used for beams - no lightmaps
	gl3ShaderInfo_t si3Dturb = gl3ShaderInfo_t();      // for water etc - always without lightmap
	gl3ShaderInfo_t si3DlmFlow = gl3ShaderInfo_t();    // for flowing/scrolling things with lightmap (conveyor, ..?)
	gl3ShaderInfo_t si3DtransFlow = gl3ShaderInfo_t(); // for transparent flowing/scrolling things (=> no lightmap)
	gl3ShaderInfo_t si3Dsky = gl3ShaderInfo_t();       // guess what..
	gl3ShaderInfo_t si3Dsprite = gl3ShaderInfo_t();    // for sprites
	gl3ShaderInfo_t si3DspriteAlpha = gl3ShaderInfo_t(); // for sprites with alpha-testing

	gl3ShaderInfo_t si3Dalias = gl3ShaderInfo_t();      // for models
	gl3ShaderInfo_t si3DaliasColor = gl3ShaderInfo_t(); // for models w/ flat colors

	// NOTE: make sure siParticle is always the last shaderInfo (or adapt GL3_ShutdownShaders())
	gl3ShaderInfo_t siParticle = gl3ShaderInfo_t(); // for particles. surprising, right?

  // for brushes etc, using 10 floats and one uint as vertex input (x,y,z, s,t, lms,lmt, normX,normY,normZ ; lightFlags)
  VertexArrayObject vao3D;
  Buffer vbo3D;

	// the next two are for gl3config.useBigVBO == true
	// int vbo3Dsize;
	// int vbo3DcurOffset;

  // for models, using 9 floats as (x,y,z, s,t, r,g,b,a)
  VertexArrayObject vaoAlias;
  Buffer vboAlias, eboAlias;
  // for particles, using 9 floats (x,y,z, size,distance, r,g,b,a)
  VertexArrayObject vaoParticle;
  Buffer vboParticle;

	// UBOs and their data
	gl3UniCommon_t uniCommonData = gl3UniCommon_t();
	gl3Uni2D_t uni2DData = gl3Uni2D_t();
	gl3Uni3D_t uni3DData = gl3Uni3D_t();
	gl3UniLights_t uniLightsData = gl3UniLights_t();
	Buffer uniCommonUBO;
	Buffer uni2DUBO;
	Buffer uni3DUBO;
	Buffer uniLightsUBO;

  Sync glsync;
}

enum imagetype_t {
	it_skin,
	it_sprite,
	it_wall,
	it_pic,
	it_sky
}

/* NOTE: struct image_s* is what re.RegisterSkin() etc return so no gl3image_s!
 *       (I think the client only passes the pointer around and doesn't know the
 *        definition of this struct, so this being different from struct image_s
 *        in ref_gl should be ok)
 */
class webglimage_t {
	final String name;               /* game path, including extension */
	final imagetype_t type;
	final int width, height;                  /* source image */
	//int upload_width, upload_height;    /* after power of two and picmip */
	int registration_sequence;          /* 0 = free */
	msurface_t texturechain;    /* for sort-by-texture world drawing */
	Texture texture;                      /* gl texture binding */
	double sl, tl, sh, th;               /* 0,0 - 1,1 unless part of the scrap */
	// qboolean scrap; // currently unused
	// bool has_alpha;

  webglimage_t(this.name, this.type, this.width, this.height);
}

const MAX_WEBGLTEXTURES = 1024;

class webgllightmapstate_t {
	int internal_format;
	int current_lightmap_texture; // index into gl3state.lightmap_textureIDs[]

	//msurface_t *lightmap_surfaces[MAX_LIGHTMAPS]; - no more lightmap chains, lightmaps are rendered multitextured

	List<int> allocated = List.generate(BLOCK_WIDTH, (i) => 0);

	/* the lightmap texture data needs to be kept in
	   main memory so texsubimage can update properly */
  List<Uint8List> lightmap_buffers = List.generate(MAX_LIGHTMAPS_PER_SURFACE, (i) => Uint8List(4 * BLOCK_WIDTH * BLOCK_HEIGHT));
}

void WebGL_UseProgram(Program shaderProgram) {
	if(shaderProgram != glstate.currentShaderProgram) {
		glstate.currentShaderProgram = shaderProgram;
		gl.useProgram(shaderProgram);
	}
}

void WebGL_BindVAO(VertexArrayObject vao)
{
	if (vao != glstate.currentVAO) {
		glstate.currentVAO = vao; 
		gl.bindVertexArray(vao);
	}
}

void WebGL_BindVBO(Buffer vbo)
{
	if (vbo != glstate.currentVBO) {
		glstate.currentVBO = vbo; 
		gl.bindBuffer(WebGL.ARRAY_BUFFER, vbo);
	}
}

void WebGL_BindEBO(Buffer ebo)
{
	if (ebo != glstate.currentEBO) {
		glstate.currentEBO = ebo; 
		gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, ebo);
	}
}

void WebGL_SelectTMU(int tmu) {
	if(glstate.currenttmu != tmu) {
		gl.activeTexture(tmu);
		glstate.currenttmu = tmu;
	}
}

CanvasElement canvas;
RenderingContext2 gl;

webglconfig_t glconfig = webglconfig_t();
webglstate_t glstate = webglstate_t();
entity_t currententity;
webglmodel_t currentmodel;

double webgldepthmin=0.0, webgldepthmax=1.0;

refdef_t webgl_newrefdef = refdef_t();

List<cplane_t> frustum = [cplane_t(), cplane_t(), cplane_t(), cplane_t()];

/* view origin */
List<double> vup = [0,0,0];
List<double> vpn = [0,0,0];
List<double> vright = [0,0,0];
List<double> webgl_origin = [0,0,0];

int webgl_visframecount = 0; /* bumped when going to a new PVS */
int webgl_framecount = 0; /* used for dlight push checking */

int c_brush_polys = 0, c_alias_polys = 0;
int c_visible_textures = 0, c_visible_lightmaps = 0;

int webgl_viewcluster = 0, webgl_viewcluster2 = 0, webgl_oldviewcluster = 0, webgl_oldviewcluster2 = 0;

List<double> v_blend = [0,0,0,0];

Float32List webgl_identityMat4 = Float32List.fromList([
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
]);

webgllightmapstate_t webgl_lms = webgllightmapstate_t();

cvar_t r_vsync;
cvar_t gl_retexturing;
cvar_t vid_fullscreen;
cvar_t r_mode;
cvar_t r_customwidth;
cvar_t r_customheight;
cvar_t vid_gamma;
cvar_t gl_anisotropic;
cvar_t gl_texturemode;
cvar_t gl_drawbuffer;
cvar_t r_clear;
cvar_t gl3_particle_size;
cvar_t gl3_particle_fade_factor;
cvar_t gl3_particle_square;

cvar_t gl_lefthand;
cvar_t r_gunfov;
cvar_t r_farsee;

cvar_t gl3_intensity;
cvar_t gl3_intensity_2D;
cvar_t r_lightlevel;
cvar_t gl3_overbrightbits;

cvar_t r_norefresh;
cvar_t r_drawentities;
cvar_t r_drawworld;
cvar_t gl_nolerp_list;
cvar_t gl_nobind;
cvar_t r_lockpvs;
cvar_t r_novis;
cvar_t r_speeds;
cvar_t gl_finish;

cvar_t gl_cull;
cvar_t gl_zfix;
cvar_t r_fullbright;
cvar_t r_modulate;
cvar_t gl_lightmap;
cvar_t gl_shadows;
cvar_t gl3_debugcontext;
cvar_t gl3_usebigvbo;

Uint8List colorMap;
