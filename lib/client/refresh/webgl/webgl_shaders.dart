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
 * WebGL2 refresher: Handling shaders
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'dart:web_gl';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'local.dart';


Shader CompileShader(int shaderType, String shaderSrc, String shaderSrc2)
{
	Shader shader = gl.createShader(shaderType);

	String source = shaderSrc + (shaderSrc2 != null ? shaderSrc2 : "");

	gl.shaderSource(shader, source);
	gl.compileShader(shader);
  bool status = gl.getShaderParameter(shader, WebGL.COMPILE_STATUS);
	if (!status)
	{
		String shaderTypeStr = "";
		switch(shaderType)
		{
			case WebGL.VERTEX_SHADER:   shaderTypeStr = "Vertex"; break;
			case WebGL.FRAGMENT_SHADER: shaderTypeStr = "Fragment"; break;
			// case GL_GEOMETRY_SHADER: shaderTypeStr = "Geometry"; break;
			/* not supported in OpenGL3.2 and we're unlikely to need/use them anyway
			case GL_COMPUTE_SHADER:  shaderTypeStr = "Compute"; break;
			case GL_TESS_CONTROL_SHADER:    shaderTypeStr = "TessControl"; break;
			case GL_TESS_EVALUATION_SHADER: shaderTypeStr = "TessEvaluation"; break;
			*/
		}
		Com_Printf("ERROR: Compiling $shaderTypeStr Shader failed: ${gl.getShaderInfoLog(shader)}\n");
		gl.deleteShader(shader);
		return null;
	}

	return shader;
}

Program CreateShaderProgram(List<Shader> shaders) {
	Program shaderProgram = gl.createProgram();
	if (shaderProgram == null) {
		Com_Printf("ERROR: Couldn't create a new Shader Program!\n");
		return null;
	}

	for(Shader shader in shaders) {
		gl.attachShader(shaderProgram, shader);
	}

	// make sure all shaders use the same attribute locations for common attributes
	// (so the same VAO can easily be used with different shaders)
	gl.bindAttribLocation(shaderProgram, WEBGL_ATTRIB_POSITION, "position");
	gl.bindAttribLocation(shaderProgram, WEBGL_ATTRIB_TEXCOORD, "texCoord");
	gl.bindAttribLocation(shaderProgram, WEBGL_ATTRIB_LMTEXCOORD, "lmTexCoord");
	gl.bindAttribLocation(shaderProgram, WEBGL_ATTRIB_COLOR, "vertColor");
	gl.bindAttribLocation(shaderProgram, WEBGL_ATTRIB_NORMAL, "normal");
	gl.bindAttribLocation(shaderProgram, WEBGL_ATTRIB_LIGHTFLAGS, "lightFlags");

	// the following line is not necessary/implicit (as there's only one output)
	// glBindFragDataLocation(shaderProgram, 0, "outColor"); XXX would this even be here?

	gl.linkProgram(shaderProgram);

  bool status = gl.getProgramParameter(shaderProgram, WebGL.LINK_STATUS);
	if (!status)
	{
		Com_Printf("ERROR:  Linking shader program failed: ${gl.getProgramInfoLog(shaderProgram)}\n");
		gl.deleteProgram(shaderProgram);
		return null;
	}

	// for(i=0; i<numShaders; ++i) {
		// after linking, they don't need to be attached anymore.
		// no idea  why they even are, if they don't have to..
		// glDetachShader(shaderProgram, shaders[i]);
	// }

	return shaderProgram;
}

const WEBGL_BINDINGPOINT_UNICOMMON = 0;
const WEBGL_BINDINGPOINT_UNI2D = 1;
const WEBGL_BINDINGPOINT_UNI3D = 2;
const WEBGL_BINDINGPOINT_UNILIGHTS = 3;


bool initShader2D(gl3ShaderInfo_t shaderInfo, String vertSrc, String fragSrc)
{
	if(shaderInfo.shaderProgram != null)
	{
		Com_Printf("WARNING: calling initShader2D for gl3ShaderInfo_t that already has a shaderProgram!\n");
		gl.deleteProgram(shaderInfo.shaderProgram);
	}

	//shaderInfo->uniColor = shaderInfo->uniProjMatrix = shaderInfo->uniModelViewMatrix = -1;
	shaderInfo.shaderProgram = null;
  shaderInfo.uniLmScales = null;

  List<Shader> shaders2D = [null, null];
	shaders2D[0] = CompileShader(WebGL.VERTEX_SHADER, vertSrc, null);
	if(shaders2D[0] == null)  return false;

	shaders2D[1] = CompileShader(WebGL.FRAGMENT_SHADER, fragSrc, null);
	if(shaders2D[1] == null) {
		gl.deleteShader(shaders2D[0]);
		return false;
	}

	final prog = CreateShaderProgram(shaders2D);

	// I think the shaders aren't needed anymore once they're linked into the program
	// glDeleteShader(shaders2D[0]);
	// glDeleteShader(shaders2D[1]);

	if (prog == null) {
		return false;
	}

	shaderInfo.shaderProgram = prog;
	WebGL_UseProgram(prog);

	// Bind the buffer object to the uniform blocks
	int blockIndex = gl.getUniformBlockIndex(prog, "uniCommon");
	if (blockIndex != WebGL.INVALID_INDEX)
	{
    final blockSize = gl.getActiveUniformBlockParameter(prog, blockIndex, WebGL.UNIFORM_BLOCK_DATA_SIZE);
		if (blockSize != glstate.uniCommonData.data.lengthInBytes) {
			Com_Printf("WARNING: OpenGL driver disagrees with us about UBO size of 'uniCommon': $blockSize vs ${glstate.uniCommonData.data.lengthInBytes}\n");
      gl.deleteShader(shaders2D[0]);
      gl.deleteShader(shaders2D[0]);
      gl.deleteProgram(prog);
		  return false; 
		}

		gl.uniformBlockBinding(prog, blockIndex, WEBGL_BINDINGPOINT_UNICOMMON);
	}
	else
	{
		Com_Printf("WARNING: Couldn't find uniform block index 'uniCommon'\n");
    gl.deleteShader(shaders2D[0]);
    gl.deleteShader(shaders2D[0]);
    gl.deleteProgram(prog);
		return false;
	}

	blockIndex = gl.getUniformBlockIndex(prog, "uni2D");
	if (blockIndex != WebGL.INVALID_INDEX)
	{
    final blockSize = gl.getActiveUniformBlockParameter(prog, blockIndex, WebGL.UNIFORM_BLOCK_DATA_SIZE);
		if(blockSize != glstate.uni2DData.data.lengthInBytes) {
			Com_Printf("WARNING: OpenGL driver disagrees with us about UBO size of 'uni2D': $blockSize vs ${glstate.uni2DData.data.lengthInBytes}\n");
      gl.deleteShader(shaders2D[0]);
      gl.deleteShader(shaders2D[0]);
      gl.deleteProgram(prog);
  		return false;
		}

		gl.uniformBlockBinding(prog, blockIndex, WEBGL_BINDINGPOINT_UNI2D);
	}
	else
	{
		Com_Printf("WARNING: Couldn't find uniform block index 'uni2D'\n");
    gl.deleteShader(shaders2D[0]);
    gl.deleteShader(shaders2D[0]);
    gl.deleteProgram(prog);
		return false;
	}

	return true;
}

bool initShader3D(gl3ShaderInfo_t shaderInfo, String vertSrc, String fragSrc) {

	if(shaderInfo.shaderProgram != null) {
		Com_Printf("WARNING: calling initShader3D for gl3ShaderInfo_t that already has a shaderProgram!\n");
		gl.deleteProgram(shaderInfo.shaderProgram);
	}

	shaderInfo.shaderProgram = null;
	shaderInfo.uniLmScales = null;

  List<Shader> shaders3D = [null, null];
	shaders3D[0] = CompileShader(WebGL.VERTEX_SHADER, vertexCommon3D, vertSrc);
	if(shaders3D[0] == null)  return false;

	shaders3D[1] = CompileShader(WebGL.FRAGMENT_SHADER, fragmentCommon3D, fragSrc);
	if(shaders3D[1] == null)
	{
		gl.deleteShader(shaders3D[0]);
		return false;
	}

	final prog = CreateShaderProgram(shaders3D);
	if(prog == null) {
    gl.deleteShader(shaders3D[0]);
    gl.deleteShader(shaders3D[0]);
		return false;
	}

	WebGL_UseProgram(prog);

	// Bind the buffer object to the uniform blocks
	int blockIndex = gl.getUniformBlockIndex(prog, "uniCommon");
	if(blockIndex != WebGL.INVALID_INDEX) {
		final blockSize = gl.getActiveUniformBlockParameter(prog, blockIndex, WebGL.UNIFORM_BLOCK_DATA_SIZE);
		if(blockSize != glstate.uniCommonData.data.lengthInBytes) {
			Com_Printf("WARNING: OpenGL driver disagrees with us about UBO size of 'uniCommon'\n");
      gl.deleteShader(shaders3D[0]);
      gl.deleteShader(shaders3D[0]);
      gl.deleteProgram(prog);
      return false;
		}

		gl.uniformBlockBinding(prog, blockIndex, WEBGL_BINDINGPOINT_UNICOMMON);
	} else {
		Com_Printf("WARNING: Couldn't find uniform block index 'uniCommon'\n");
    gl.deleteShader(shaders3D[0]);
    gl.deleteShader(shaders3D[0]);
    gl.deleteProgram(prog);
    return false;
	}

	blockIndex = gl.getUniformBlockIndex(prog, "uni3D");
	if (blockIndex != WebGL.INVALID_INDEX) {
		final blockSize = gl.getActiveUniformBlockParameter(prog, blockIndex, WebGL.UNIFORM_BLOCK_DATA_SIZE);
		if(blockSize != glstate.uni3DData.data.lengthInBytes) {
			Com_Printf("WARNING: OpenGL driver disagrees with us about UBO size of 'uni3D'\n");
			Com_Printf("         driver says $blockSize, we expect ${glstate.uni3DData.data.lengthInBytes}\n");
      gl.deleteShader(shaders3D[0]);
      gl.deleteShader(shaders3D[0]);
      gl.deleteProgram(prog);
      return false;
		}

		gl.uniformBlockBinding(prog, blockIndex, WEBGL_BINDINGPOINT_UNI3D);
	}
	else
	{
		Com_Printf("WARNING: Couldn't find uniform block index 'uni3D'\n");
    gl.deleteShader(shaders3D[0]);
    gl.deleteShader(shaders3D[0]);
    gl.deleteProgram(prog);
    return false;
	}
	blockIndex = gl.getUniformBlockIndex(prog, "uniLights");
	if(blockIndex != WebGL.INVALID_INDEX) {
		final blockSize = gl.getActiveUniformBlockParameter(prog, blockIndex, WebGL.UNIFORM_BLOCK_DATA_SIZE);
		if(blockSize != glstate.uniLightsData.data.lengthInBytes) {
			Com_Printf("WARNING: OpenGL driver disagrees with us about UBO size of 'uniLights'\n");
			Com_Printf("         OpenGL says $blockSize, we say ${glstate.uniLightsData.data.lengthInBytes}\n");
      gl.deleteShader(shaders3D[0]);
      gl.deleteShader(shaders3D[0]);
      gl.deleteProgram(prog);
      return false;
		}

		gl.uniformBlockBinding(prog, blockIndex, WEBGL_BINDINGPOINT_UNILIGHTS);
	}
	// else: as uniLights is only used in the LM shaders, it's ok if it's missing

	// make sure texture is GL_TEXTURE0
	var texLoc = gl.getUniformLocation(prog, "tex");
	if(texLoc != null) {
		gl.uniform1i(texLoc, 0);
	}

	// // ..  and the 4 lightmap texture use GL_TEXTURE1..4
	// char lmName[10] = "lightmapX";
	for(int i=0; i<4; ++i) {
		final lmName = "lightmap$i";
		var lmLoc = gl.getUniformLocation(prog, lmName);
		if(lmLoc != null) {
			gl.uniform1i(lmLoc, i+1); // lightmap0 belongs to GL_TEXTURE1, lightmap1 to GL_TEXTURE2 etc
		}
	}

	UniformLocation lmScalesLoc = gl.getUniformLocation(prog, "lmScales");
	shaderInfo.uniLmScales = lmScalesLoc;
	if(lmScalesLoc != null) {
		shaderInfo.lmScales.fillRange(0, 4, 1);

		for(int i=1; i<4; ++i) {
      shaderInfo.lmScales.fillRange(i * 4, (i + 1) * 4, 0);
    }
		gl.uniform4fv(lmScalesLoc, shaderInfo.lmScales);
	}

	shaderInfo.shaderProgram = prog;

	// I think the shaders aren't needed anymore once they're linked into the program
	// glDeleteShader(shaders3D[0]);
	// glDeleteShader(shaders3D[1]);

	return true;
}

initUBOs()
{
	glstate.uniCommonData.gamma = 1.0/vid_gamma.value;
	glstate.uniCommonData.intensity = gl3_intensity.value;
	glstate.uniCommonData.intensity2D = gl3_intensity_2D.value;
	glstate.uniCommonData.color = [1, 1, 1, 1];

  glstate.uniCommonUBO = gl.createBuffer();
	gl.bindBuffer(WebGL.UNIFORM_BUFFER, glstate.uniCommonUBO);
	gl.bindBufferBase(WebGL.UNIFORM_BUFFER, WEBGL_BINDINGPOINT_UNICOMMON, glstate.uniCommonUBO);
	gl.bufferData(WebGL.UNIFORM_BUFFER, glstate.uniCommonData.data, WebGL.DYNAMIC_DRAW);

	// the matrix will be set to something more useful later, before being used
	// gl3state.uni2DData.transMat4 = HMM_Mat4();

  glstate.uni2DUBO = gl.createBuffer();
	gl.bindBuffer(WebGL.UNIFORM_BUFFER, glstate.uni2DUBO);
	gl.bindBufferBase(WebGL.UNIFORM_BUFFER, WEBGL_BINDINGPOINT_UNI2D, glstate.uni2DUBO);
	gl.bufferData(WebGL.UNIFORM_BUFFER, glstate.uni2DData.data, WebGL.DYNAMIC_DRAW);

	// // the matrices will be set to something more useful later, before being used
	glstate.uni3DData.transProjMat4 = Float32List(16);
	glstate.uni3DData.transViewMat4 = Float32List(16);
	glstate.uni3DData.transModelMat4 = webgl_identityMat4;
	glstate.uni3DData.scroll = 0.0;
	glstate.uni3DData.time = 0.0;
	glstate.uni3DData.alpha = 1.0;
	// gl3_overbrightbits 0 means "no scaling" which is equivalent to multiplying with 1
	glstate.uni3DData.overbrightbits = (gl3_overbrightbits.value <= 0.0) ? 1.0 : gl3_overbrightbits.value;
	glstate.uni3DData.particleFadeFactor = gl3_particle_fade_factor.value;

  glstate.uni3DUBO = gl.createBuffer();
	gl.bindBuffer(WebGL.UNIFORM_BUFFER, glstate.uni3DUBO);
	gl.bindBufferBase(WebGL.UNIFORM_BUFFER, WEBGL_BINDINGPOINT_UNI3D, glstate.uni3DUBO);
	gl.bufferData(WebGL.UNIFORM_BUFFER, glstate.uni3DData.data, WebGL.DYNAMIC_DRAW);

  glstate.uniLightsUBO = gl.createBuffer();
	gl.bindBuffer(WebGL.UNIFORM_BUFFER, glstate.uniLightsUBO);
	gl.bindBufferBase(WebGL.UNIFORM_BUFFER, WEBGL_BINDINGPOINT_UNILIGHTS, glstate.uniLightsUBO);
	gl.bufferData(WebGL.UNIFORM_BUFFER, glstate.uniLightsData.data, WebGL.DYNAMIC_DRAW);

	glstate.currentUBO = glstate.uniLightsUBO;
}


bool createShaders() {
	if(!initShader2D(glstate.si2D, vertexSrc2D, fragmentSrc2D))
	{
		Com_Printf("WARNING: Failed to create shader program for textured 2D rendering!\n");
		return false;
	}
	if(!initShader2D(glstate.si2Dcolor, vertexSrc2Dcolor, fragmentSrc2Dcolor))
	{
		Com_Printf("WARNING: Failed to create shader program for color-only 2D rendering!\n");
		return false;
	}
	if(!initShader3D(glstate.si3Dlm, vertexSrc3Dlm, fragmentSrc3Dlm))
	{
		Com_Printf("WARNING: Failed to create shader program for textured 3D rendering with lightmap!\n");
		return false;
	}
	if(!initShader3D(glstate.si3Dtrans, vertexSrc3D, fragmentSrc3D))
	{
		Com_Printf("WARNING: Failed to create shader program for rendering translucent 3D things!\n");
		return false;
	}
	if(!initShader3D(glstate.si3DcolorOnly, vertexSrc3D, fragmentSrc3Dcolor))
	{
		Com_Printf("WARNING: Failed to create shader program for flat-colored 3D rendering!\n");
		return false;
	}
	/*
	if(!initShader3D(glstate.si3Dlm, vertexSrc3Dlm, fragmentSrc3D))
	{
		Com_Printf("WARNING: Failed to create shader program for blending 3D lightmaps rendering!\n");
		return false;
	}
	*/
	if(!initShader3D(glstate.si3Dturb, vertexSrc3Dwater, fragmentSrc3Dwater))
	{
		Com_Printf("WARNING: Failed to create shader program for water rendering!\n");
		return false;
	}
	if(!initShader3D(glstate.si3DlmFlow, vertexSrc3DlmFlow, fragmentSrc3Dlm))
	{
		Com_Printf("WARNING: Failed to create shader program for scrolling textured 3D rendering with lightmap!\n");
		return false;
	}
	if(!initShader3D(glstate.si3DtransFlow, vertexSrc3Dflow, fragmentSrc3D))
	{
		Com_Printf("WARNING: Failed to create shader program for scrolling textured translucent 3D rendering!\n");
		return false;
	}
	if(!initShader3D(glstate.si3Dsky, vertexSrc3D, fragmentSrc3Dsky))
	{
		Com_Printf("WARNING: Failed to create shader program for sky rendering!\n");
		return false;
	}
	if(!initShader3D(glstate.si3Dsprite, vertexSrc3D, fragmentSrc3Dsprite))
	{
		Com_Printf("WARNING: Failed to create shader program for sprite rendering!\n");
		return false;
	}
	if(!initShader3D(glstate.si3DspriteAlpha, vertexSrc3D, fragmentSrc3DspriteAlpha))
	{
		Com_Printf("WARNING: Failed to create shader program for alpha-tested sprite rendering!\n");
		return false;
	}
	if(!initShader3D(glstate.si3Dalias, vertexSrcAlias, fragmentSrcAlias))
	{
		Com_Printf("WARNING: Failed to create shader program for rendering textured models!\n");
		return false;
	}
	if(!initShader3D(glstate.si3DaliasColor, vertexSrcAlias, fragmentSrcAliasColor))
	{
		Com_Printf("WARNING: Failed to create shader program for rendering flat-colored models!\n");
		return false;
	}

	var particleFrag = fragmentSrcParticles;
	if(gl3_particle_square.boolean)
	{
		particleFrag = fragmentSrcParticlesSquare;
	}

	if(!initShader3D(glstate.siParticle, vertexSrcParticles, particleFrag))
	{
		Com_Printf("WARNING: Failed to create shader program for rendering particles!\n");
		return false;
	}

	glstate.currentShaderProgram = null;

	return true;
}

bool WebGL_InitShaders() {
	initUBOs();
	return createShaders();
}

updateUBO(Buffer ubo, dynamic data) {
	if(glstate.currentUBO != ubo) {
		glstate.currentUBO = ubo;
		gl.bindBuffer(WebGL.UNIFORM_BUFFER, ubo);
	}

	// http://docs.gl/gl3/glBufferSubData says  "When replacing the entire data store,
	// consider using glBufferSubData rather than completely recreating the data store
	// with glBufferData. This avoids the cost of reallocating the data store."
	// no idea why glBufferData() doesn't just do that when size doesn't change, but whatever..
	// however, it also says glBufferSubData() might cause a stall so I DON'T KNOW!
	// on Linux/nvidia, by just looking at the fps, glBufferData() and glBufferSubData() make no difference
	// TODO: STREAM instead DYNAMIC?

	// this seems to be reasonably fast everywhere.. glMapBuffer() seems to be a bit faster on OSX though..
	gl.bufferData(WebGL.UNIFORM_BUFFER, data, WebGL.DYNAMIC_DRAW);
}

WebGL_UpdateUBOCommon() {
	updateUBO(glstate.uniCommonUBO, glstate.uniCommonData.data);
}

WebGL_UpdateUBO2D() {
	updateUBO(glstate.uni2DUBO, glstate.uni2DData.data);
}

WebGL_UpdateUBO3D() {
	updateUBO(glstate.uni3DUBO, glstate.uni3DData.data);
}

WebGL_UpdateUBOLights() {
	updateUBO(glstate.uniLightsUBO, glstate.uniLightsData.data);
}


// ############## shaders for 2D rendering (HUD, menus, console, videos, ..) #####################

const vertexSrc2D = """
#version 300 es

precision mediump float;

in vec2 position; // GL3_ATTRIB_POSITION
in vec2 texCoord; // GL3_ATTRIB_TEXCOORD

// for UBO shared between 2D shaders
layout (std140) uniform uni2D
{
  mat4 trans;
};

out vec2 passTexCoord;

void main()
{
  gl_Position = trans * vec4(position, 0.0, 1.0);
  passTexCoord = texCoord;
}
""";

const fragmentSrc2D = """
#version 300 es

precision mediump float;

in vec2 passTexCoord;

// for UBO shared between all shaders (incl. 2D)
layout (std140) uniform uniCommon
{
  float gamma;
  float intensity;
  float intensity2D; // for HUD, menu etc

  vec4 color;
};

uniform sampler2D tex;

out vec4 outColor;

void main()
{
  vec4 texel = texture(tex, passTexCoord);
  // the gl1 renderer used glAlphaFunc(GL_GREATER, 0.666);
  // and glEnable(GL_ALPHA_TEST); for 2D rendering
  // this should do the same
  if(texel.a <= 0.666)
    discard;

  // apply gamma correction and intensity
  texel.rgb *= intensity2D;
  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a; // I think alpha shouldn't be modified by gamma and intensity
}
""";

// 2D color only rendering, GL3_Draw_Fill(), GL3_Draw_FadeScreen()
const vertexSrc2Dcolor = """
#version 300 es

precision mediump float;

in vec2 position; // GL3_ATTRIB_POSITION

// for UBO shared between 2D shaders
layout (std140) uniform uni2D
{
  mat4 trans;
};

void main()
{
  gl_Position = trans * vec4(position, 0.0, 1.0);
}
""";

const fragmentSrc2Dcolor = """
#version 300 es

precision mediump float;

// for UBO shared between all shaders (incl. 2D)
layout (std140) uniform uniCommon
{
  float gamma;
  float intensity;
  float intensity2D; // for HUD, menus etc

  vec4 color;
};

out vec4 outColor;

void main()
{
  vec3 col = color.rgb * intensity2D;
  outColor.rgb = pow(col, vec3(gamma));
  outColor.a = color.a;
}
""";

// ############## shaders for 3D rendering #####################

const vertexCommon3D = """
#version 300 es

precision mediump float;

in vec3 position;   // GL3_ATTRIB_POSITION
in vec2 texCoord;   // GL3_ATTRIB_TEXCOORD
in vec2 lmTexCoord; // GL3_ATTRIB_LMTEXCOORD
in vec4 vertColor;  // GL3_ATTRIB_COLOR
in vec3 normal;     // GL3_ATTRIB_NORMAL
in uint lightFlags; // GL3_ATTRIB_LIGHTFLAGS

out vec2 passTexCoord;

// for UBO shared between all 3D shaders
layout (std140) uniform uni3D
{
  mat4 transProj;
  mat4 transView;
  mat4 transModel;

  float scroll; // for SURF_FLOWING
  float time;
  float alpha;
  float overbrightbits;
  float particleFadeFactor;
  float _pad_1; // AMDs legacy windows driver needs this, otherwise uni3D has wrong size
  float _pad_2;
  float _pad_3;
};
""";

const fragmentCommon3D = """
#version 300 es

precision mediump float;

in vec2 passTexCoord;

out vec4 outColor;

// for UBO shared between all shaders (incl. 2D)
layout (std140) uniform uniCommon
{
  float gamma; // this is 1.0/vid_gamma
  float intensity;
  float intensity2D; // for HUD, menus etc

  vec4 color; // really?

};
// for UBO shared between all 3D shaders
layout (std140) uniform uni3D
{
  mat4 transProj;
  mat4 transView;
  mat4 transModel;

  float scroll; // for SURF_FLOWING
  float time;
  float alpha;
  float overbrightbits;
  float particleFadeFactor;
  float _pad_1; // AMDs legacy windows driver needs this, otherwise uni3D has wrong size
  float _pad_2;
  float _pad_3;
};
""";

const vertexSrc3D = """

// it gets attributes and uniforms from vertexCommon3D

void main()
{
  passTexCoord = texCoord;
  gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
""";

const vertexSrc3Dflow = """

// it gets attributes and uniforms from vertexCommon3D

void main()
{
  passTexCoord = texCoord + vec2(scroll, 0);
  gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
""";

const vertexSrc3Dlm = """

// it gets attributes and uniforms from vertexCommon3D

out vec2 passLMcoord;
out vec3 passWorldCoord;
out vec3 passNormal;
flat out uint passLightFlags;

void main()
{
  passTexCoord = texCoord;
  passLMcoord = lmTexCoord;
  vec4 worldCoord = transModel * vec4(position, 1.0);
  passWorldCoord = worldCoord.xyz;
  vec4 worldNormal = transModel * vec4(normal, 0.0f);
  passNormal = normalize(worldNormal.xyz);
  passLightFlags = lightFlags;

  gl_Position = transProj * transView * worldCoord;
}
""";

const vertexSrc3DlmFlow = """

// it gets attributes and uniforms from vertexCommon3D

out vec2 passLMcoord;
out vec3 passWorldCoord;
out vec3 passNormal;
flat out uint passLightFlags;

void main()
{
  passTexCoord = texCoord + vec2(scroll, 0);
  passLMcoord = lmTexCoord;
  vec4 worldCoord = transModel * vec4(position, 1.0);
  passWorldCoord = worldCoord.xyz;
  vec4 worldNormal = transModel * vec4(normal, 0.0f);
  passNormal = normalize(worldNormal.xyz);
  passLightFlags = lightFlags;

  gl_Position = transProj * transView * worldCoord;
}
""";

const fragmentSrc3D = """

// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

void main()
{
  vec4 texel = texture(tex, passTexCoord);

  // apply intensity and gamma
  texel.rgb *= intensity;
  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const fragmentSrc3Dwater = """

// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

void main()
{
  vec4 texel = texture(tex, passTexCoord);

  // apply intensity and gamma
  texel.rgb *= intensity*0.5;
  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const fragmentSrc3Dlm = """

// it gets attributes and uniforms from fragmentCommon3D

struct DynLight { // gl3UniDynLight in C
  vec3 lightOrigin;
  float _pad;
  //vec3 lightColor;
  //float lightIntensity;
  vec4 lightColor; // .a is intensity; this way it also works on OSX...
  // (otherwise lightIntensity always contained 1 there)
};

layout (std140) uniform uniLights
{
  DynLight dynLights[32];
  uint numDynLights;
  uint _pad1; uint _pad2; uint _pad3; // FFS, AMD!
};

uniform sampler2D tex;

uniform sampler2D lightmap0;
uniform sampler2D lightmap1;
uniform sampler2D lightmap2;
uniform sampler2D lightmap3;

uniform vec4 lmScales[4];

in vec2 passLMcoord;
in vec3 passWorldCoord;
in vec3 passNormal;
flat in uint passLightFlags;

void main()
{
  vec4 texel = texture(tex, passTexCoord);

  // apply intensity
  texel.rgb *= intensity;

  // apply lightmap
  vec4 lmTex = texture(lightmap0, passLMcoord) * lmScales[0];
  lmTex     += texture(lightmap1, passLMcoord) * lmScales[1];
  lmTex     += texture(lightmap2, passLMcoord) * lmScales[2];
  lmTex     += texture(lightmap3, passLMcoord) * lmScales[3];

  if(passLightFlags != 0u)
  {
    // TODO: or is hardcoding 32 better?
    for(uint i=0u; i<numDynLights; ++i)
    {
      // I made the following up, it's probably not too cool..
      // it basically checks if the light is on the right side of the surface
      // and, if it is, sets intensity according to distance between light and pixel on surface

      // dyn light number i does not affect this plane, just skip it
      if((passLightFlags & (1u << i)) == 0u)  continue;

      float intens = dynLights[i].lightColor.a;

      vec3 lightToPos = dynLights[i].lightOrigin - passWorldCoord;
      float distLightToPos = length(lightToPos);
      float fact = max(0.0, intens - distLightToPos - 52.0);

      // move the light source a bit further above the surface
      // => helps if the lightsource is so close to the surface (e.g. grenades, rockets)
      //    that the dot product below would return 0
      // (light sources that are below the surface are filtered out by lightFlags)
      lightToPos += passNormal*32.0;

      // also factor in angle between light and point on surface
      fact *= max(0.0, dot(passNormal, normalize(lightToPos)));


      lmTex.rgb += dynLights[i].lightColor.rgb * fact * (1.0/256.0);
    }
  }

  lmTex.rgb *= overbrightbits;
  outColor = lmTex*texel;
  outColor.rgb = pow(outColor.rgb, vec3(gamma)); // apply gamma correction to result

  outColor.a = 1.0; // lightmaps aren't used with translucent surfaces
}
""";

const fragmentSrc3Dcolor = """

// it gets attributes and uniforms from fragmentCommon3D

void main()
{
  vec4 texel = color;

  // apply gamma correction and intensity
  // texel.rgb *= intensity; TODO: use intensity here? (this is used for beams)
  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const fragmentSrc3Dsky = """

// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

void main()
{
  vec4 texel = texture(tex, passTexCoord);

  // TODO: something about GL_BLEND vs GL_ALPHATEST etc

  // apply gamma correction
  // texel.rgb *= intensity; // TODO: really no intensity for sky?
  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const fragmentSrc3Dsprite = """

// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

void main()
{
  vec4 texel = texture(tex, passTexCoord);

  // apply gamma correction and intensity
  texel.rgb *= intensity;
  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const fragmentSrc3DspriteAlpha = """

// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

void main()
{
  vec4 texel = texture(tex, passTexCoord);

  if(texel.a <= 0.666)
    discard;

  // apply gamma correction and intensity
  texel.rgb *= intensity;
  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const vertexSrc3Dwater = """

// it gets attributes and uniforms from vertexCommon3D
void main()
{
  vec2 tc = texCoord;
  tc.s += sin( texCoord.t*0.125 + time ) * 4.0;
  tc.s += scroll;
  tc.t += sin( texCoord.s*0.125 + time ) * 4.0;
  tc *= 1.0/64.0; // do this last
  passTexCoord = tc;

  gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
""";

const vertexSrcAlias = """

// it gets attributes and uniforms from vertexCommon3D

out vec4 passColor;

void main()
{
  passColor = vertColor*overbrightbits;
  passTexCoord = texCoord;
  gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
""";

const fragmentSrcAlias = """

// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

in vec4 passColor;

void main()
{
  vec4 texel = texture(tex, passTexCoord);

  // apply gamma correction and intensity
  texel.rgb *= intensity;
  texel.a *= alpha; // is alpha even used here?
  texel *= min(vec4(1.5), passColor);

  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const fragmentSrcAliasColor = """

// it gets attributes and uniforms from fragmentCommon3D

in vec4 passColor;

void main()
{
  vec4 texel = passColor;

  // apply gamma correction and intensity
  // texel.rgb *= intensity; // TODO: color-only rendering probably shouldn't use intensity?
  texel.a *= alpha; // is alpha even used here?
  outColor.rgb = pow(texel.rgb, vec3(gamma));
  outColor.a = texel.a; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const vertexSrcParticles = """

// it gets attributes and uniforms from vertexCommon3D

out vec4 passColor;

void main()
{
  passColor = vertColor;
  gl_Position = transProj * transView * transModel * vec4(position, 1.0);

  // abusing texCoord for pointSize, pointDist for particles
  float pointDist = texCoord.y*0.1; // with factor 0.1 it looks good.

  gl_PointSize = texCoord.x/pointDist;
}
""";

const fragmentSrcParticles = """

// it gets attributes and uniforms from fragmentCommon3D

in vec4 passColor;

void main()
{
  vec2 offsetFromCenter = 2.0*(gl_PointCoord - vec2(0.5, 0.5)); // normalize so offset is between 0 and 1 instead 0 and 0.5
  float distSquared = dot(offsetFromCenter, offsetFromCenter);
  if(distSquared > 1.0) // this makes sure the particle is round
    discard;

  vec4 texel = passColor;

  // apply gamma correction and intensity
  //texel.rgb *= intensity; TODO: intensity? Probably not?
  outColor.rgb = pow(texel.rgb, vec3(gamma));

  // I want the particles to fade out towards the edge, the following seems to look nice
  texel.a *= min(1.0, particleFadeFactor*(1.0 - distSquared));

  outColor.a = texel.a; // I think alpha shouldn't be modified by gamma and intensity
}
""";

const fragmentSrcParticlesSquare = """

// it gets attributes and uniforms from fragmentCommon3D

in vec4 passColor;

void main()
{
  // outColor = passColor;
  // so far we didn't use gamma correction for square particles, but this way
  // uniCommon is referenced so hopefully Intels Ivy Bridge HD4000 GPU driver
  // for Windows stops shitting itself (see https://github.com/yquake2/yquake2/issues/391)
  outColor.rgb = pow(passColor.rgb, vec3(gamma));
  outColor.a = passColor.a;
}
""";
