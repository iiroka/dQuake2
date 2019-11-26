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
 * Drawing of all images that are not textures
 *
 * =======================================================================
 */
import 'dart:web_gl';
import 'dart:typed_data';
import 'package:dQuakeWeb/common/filesystem.dart';

import 'local.dart';
import 'webgl_image.dart';
import 'webgl_shaders.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/shared.dart';

webglimage_t draw_chars;

VertexArrayObject vao2D, vao2Dcolor;
Buffer vbo2D;

WebGL_Draw_InitLocal() async {
	/* load console characters */
	draw_chars = await WebGL_FindImage("pics/conchars.pcx", imagetype_t.it_pic);
	if (draw_chars == null) {
	  Com_Error(ERR_FATAL, "Couldn't load pics/conchars.pcx");
	}

	// set up attribute layout for 2D textured rendering
  vao2D = gl.createVertexArray();
	gl.bindVertexArray(vao2D);

  vbo2D = gl.createBuffer();
	WebGL_BindVBO(vbo2D);

	WebGL_UseProgram(glstate.si2D.shaderProgram);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_POSITION);
	// Note: the glVertexAttribPointer() configuration is stored in the VAO, not the shader or sth
	//       (that's why I use one VAO per 2D shader)
	gl.vertexAttribPointer(WEBGL_ATTRIB_POSITION, 2, WebGL.FLOAT, false, 4*4, 0);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_TEXCOORD);
	gl.vertexAttribPointer(WEBGL_ATTRIB_TEXCOORD, 2, WebGL.FLOAT, false, 4*4, 2*4);

	// set up attribute layout for 2D flat color rendering

  vao2Dcolor = gl.createVertexArray();
	gl.bindVertexArray(vao2Dcolor);

	WebGL_BindVBO(vbo2D); // yes, both VAOs share the same VBO

	WebGL_UseProgram(glstate.si2Dcolor.shaderProgram);

	gl.enableVertexAttribArray(WEBGL_ATTRIB_POSITION);
	gl.vertexAttribPointer(WEBGL_ATTRIB_POSITION, 2, WebGL.FLOAT, false, 2*4, 0);

	WebGL_BindVAO(null);
}

WebGL_Draw_ShutdownLocal() {
	gl.deleteBuffer(vbo2D);
	vbo2D = null;
	gl.deleteVertexArray(vao2D);
	vao2D = null;
	gl.deleteVertexArray(vao2Dcolor);
	vao2Dcolor = null;
}

// bind the texture before calling this
drawTexturedRectangle(double x, double y, double w, double h,
                      double sl, double tl, double sh, double th)
{
	/*
	 *  x,y+h      x+w,y+h
	 * sl,th--------sh,th
	 *  |             |
	 *  |             |
	 *  |             |
	 * sl,tl--------sh,tl
	 *  x,y        x+w,y
	 */

	final vBuf = Float32List.fromList([
	//  X,   Y,   S,  T
		x,   y+h, sl, th,
		x,   y,   sl, tl,
		x+w, y+h, sh, th,
		x+w, y,   sh, tl
	]);

	WebGL_BindVAO(vao2D);

	// Note: while vao2D "remembers" its vbo for drawing, binding the vao does *not*
	//       implicitly bind the vbo, so I need to explicitly bind it before glBufferData()
	WebGL_BindVBO(vbo2D);
	gl.bufferData(WebGL.ARRAY_BUFFER, vBuf, WebGL.STREAM_DRAW);

	gl.drawArrays(WebGL.TRIANGLE_STRIP, 0, 4);

	//glMultiDrawArrays(mode, first, count, drawcount) ??
}

/*
 * Draws one 8*8 graphics character with 0 being transparent.
 * It can be clipped to the top of the screen to allow the console to be
 * smoothly scrolled off.
 */
WebGL_Draw_CharScaled(int x, int y, int num, double scale) {
	// int row, col;
	// float frow, fcol, size, scaledSize;
	num &= 255;

	if ((num & 127) == 32) {
		return; /* space */
	}

	if (y <= -8) {
		return; /* totally off screen */
	}

	int row = num >> 4;
	int col = num & 15;

	double frow = row * 0.0625;
	double fcol = col * 0.0625;
	double size = 0.0625;

	double scaledSize = 8*scale;

	// TODO: batchen?

	WebGL_UseProgram(glstate.si2D.shaderProgram);
	WebGL_Bind(draw_chars.texture);
	drawTexturedRectangle(x.toDouble(), y.toDouble(), scaledSize, scaledSize, fcol, frow, fcol+size, frow+size);
}

Future<webglimage_t> WebGL_Draw_FindPic(String name) async  {

	if ((name[0] != '/') && (name[0] != '\\')) {
		final fullname = "pics/$name.pcx";
		return WebGL_FindImage(fullname, imagetype_t.it_pic);
	} else {
		return WebGL_FindImage(name.substring(1), imagetype_t.it_pic);
	}
}

Future<List<int>> WebGL_Draw_GetPicSize(String pic) async {
	webglimage_t img = await WebGL_Draw_FindPic(pic);
	if (img == null) {
		return [-1, -1];
	}

	return [img.width, img.height];
}

Future<void> WebGL_Draw_StretchPic(int x, int y, int w, int h, String pic) async {
	webglimage_t img = await WebGL_Draw_FindPic(pic);
	if (img == null) {
		Com_Printf("Can't find pic: $pic\n");
		return;
	}

	WebGL_UseProgram(glstate.si2D.shaderProgram);
	WebGL_Bind(img.texture);

	drawTexturedRectangle(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble(), img.sl, img.tl, img.sh, img.th);
}

Future<void> WebGL_Draw_PicScaled(int x, int y, String pic, double factor) async {
	webglimage_t img = await WebGL_Draw_FindPic(pic);
	if (img == null) {
		Com_Printf("Can't find pic: $pic\n");
		return;
	}

	WebGL_UseProgram(glstate.si2D.shaderProgram);
	WebGL_Bind(img.texture);

	drawTexturedRectangle(x.toDouble(), y.toDouble(), img.width*factor, img.height*factor, img.sl, img.tl, img.sh, img.th);
}


/*
 * This repeats a 64*64 tile graphic to fill
 * the screen around a sized down
 * refresh window.
 */
WebGL_Draw_TileClear(int x, int y, int w, int h, String pic) async {
	webglimage_t img = await WebGL_Draw_FindPic(pic);
	if (img == null) {
		Com_Printf("Can't find pic: $pic\n");
		return;
	}

	WebGL_UseProgram(glstate.si2D.shaderProgram);
	WebGL_Bind(img.texture);

	drawTexturedRectangle(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble(), x/64.0, y/64.0, (x+w)/64.0, (y+h)/64.0);
}
/*
 * Fills a box of pixels with a single color
 */
WebGL_Draw_Fill(int x, int y, int w, int h, int c) {

	if (c < 0 || c > 255) {
		Com_Error(ERR_FATAL, "Draw_Fill: bad color");
	}

	List<double> vBuf = [
	//  X,   Y
		x.toDouble(),   (y+h).toDouble(),
		x.toDouble(),   y.toDouble(),
		(x+w).toDouble(), (y+h).toDouble(),
		(x+w).toDouble(), y.toDouble()
  ];

  List<double> color = [0,0,0,1];
	for(int i=0; i<3; ++i) {
		color[i] = colorMap[(3 * c) + i] / 255.0;
	}
  glstate.uniCommonData.color = color;

	WebGL_UpdateUBOCommon();

	WebGL_UseProgram(glstate.si2Dcolor.shaderProgram);
	WebGL_BindVAO(vao2Dcolor);

	WebGL_BindVBO(vbo2D);
	gl.bufferData(WebGL.ARRAY_BUFFER, Float32List.fromList(vBuf), WebGL.STREAM_DRAW);

	gl.drawArrays(WebGL.TRIANGLE_STRIP, 0, 4);
}


WebGL_Draw_GetPalette() async {
  final data = await FS_LoadFile("pics/colormap.bin");
  if (data == null) {
    Com_Error(ERR_FATAL, "Couldn't load pics/colormap.bin");
  }
  if (data.lengthInBytes != 768) {
    Com_Error(ERR_FATAL, "Wrong size pics/colormap.bin ${data.lengthInBytes}");
  }
  colorMap = data.asUint8List();
}
