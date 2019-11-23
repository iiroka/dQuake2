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
 * Misc WebGL2 refresher functions
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'dart:web_gl';
import 'local.dart';
import 'webgl_image.dart';

webglimage_t webgl_notexture; /* use for bad textures */
webglimage_t webgl_particletexture; /* little dot for particles */

WebGL_SetDefaultState() {
	gl.clearColor(1, 0, 0.5, 0.5);
	// gl.disable(WebGL.MULTISAMPLE);
	gl.cullFace(WebGL.FRONT);

	gl.disable(WebGL.DEPTH_TEST);
	gl.disable(WebGL.CULL_FACE);
	gl.disable(WebGL.BLEND);

	// gl.polygonMode(GL_FRONT_AND_BACK, GL_FILL);

	// TODO: gl_texturemode, gl1_texturealphamode?
	//GL3_TextureMode(gl_texturemode->string);
	//R_TextureAlphaMode(gl1_texturealphamode->string);
	//R_TextureSolidMode(gl1_texturesolidmode->string);

	gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, gl_filter_min);
	gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, gl_filter_max);

	gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_S, WebGL.REPEAT);
	gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_T, WebGL.REPEAT);

	gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA);
}

List<List<int>> dottexture = [
	[0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 1, 1, 0, 0, 0, 0],
	[0, 1, 1, 1, 1, 0, 0, 0],
	[0, 1, 1, 1, 1, 0, 0, 0],
	[0, 0, 1, 1, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0],
];

WebGL_InitParticleTexture() {
	Uint8List data = Uint8List(8 * 8 * 4);

	/* particle texture */
	for (int x = 0; x < 8; x++) {
		for (int y = 0; y < 8; y++) {
			data[((y*8)+x)*4+0] = 255;
			data[((y*8)+x)*4+1] = 255;
			data[((y*8)+x)*4+2] = 255;
			data[((y*8)+x)*4+3] = dottexture[x][y] * 255;
		}
	}

	webgl_particletexture = WebGL_LoadPic("***particle***", data,
	                                  8, 0, 8, 0, imagetype_t.it_sprite);

	/* also use this for bad textures, but without alpha */
	for (int x = 0; x < 8; x++) {
		for (int y = 0; y < 8; y++) {
			data[((y*8)+x)*4+0] = dottexture[x & 3][y & 3] * 255;
			data[((y*8)+x)*4+1] = 0;
			data[((y*8)+x)*4+2] = 0;
			data[((y*8)+x)*4+3] = 255;
		}
	}

	webgl_notexture = WebGL_LoadPic("***r_notexture***", data,
	                            8, 0, 8, 0, imagetype_t.it_wall);
}
