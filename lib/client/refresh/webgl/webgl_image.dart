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
 * Texture handling for WebGL
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'dart:web_gl';
import 'package:image/image.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/filesystem.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'local.dart';
import 'webgl_model.dart' show registration_sequence;

class glmode_t {
	final String name;
	final int minimize, maximize;

  const glmode_t(this.name, this.minimize, this.maximize);
}

List<webglimage_t> gltextures = List();

const modes = [
	glmode_t("GL_NEAREST", WebGL.NEAREST, WebGL.NEAREST),
	glmode_t("GL_LINEAR", WebGL.LINEAR, WebGL.LINEAR),
	glmode_t("GL_NEAREST_MIPMAP_NEAREST", WebGL.NEAREST_MIPMAP_NEAREST, WebGL.NEAREST),
	glmode_t("GL_LINEAR_MIPMAP_NEAREST", WebGL.LINEAR_MIPMAP_NEAREST, WebGL.LINEAR),
	glmode_t("GL_NEAREST_MIPMAP_LINEAR", WebGL.NEAREST_MIPMAP_LINEAR, WebGL.NEAREST),
	glmode_t("GL_LINEAR_MIPMAP_LINEAR", WebGL.LINEAR_MIPMAP_LINEAR, WebGL.LINEAR)
];

int gl_filter_min = WebGL.LINEAR_MIPMAP_NEAREST;
int gl_filter_max = WebGL.LINEAR;

WebGL_TextureMode(String string) {

	int i;
	for (i = 0; i < modes.length; i++) {
		if (modes[i].name == string.toUpperCase()) {
			break;
		}
	}

	if (i == modes.length)
	{
		Com_Printf("bad filter name\n");
		return;
	}

	gl_filter_min = modes[i].minimize;
	gl_filter_max = modes[i].maximize;

	/* clamp selected anisotropy */
	if (glconfig.anisotropic) {
		if (gl_anisotropic.integer > glconfig.max_anisotropy) {
			Cvar_Set("gl_anisotropic", glconfig.max_anisotropy.toString());
		}
		else if (gl_anisotropic.integer < 1) {
			Cvar_Set("gl_anisotropic", "1");
		}
	} else {
    Cvar_Set("gl_anisotropic", "0");
	}

	/* change all the existing mipmap texture objects */
	for (var glt in gltextures) {
		if ((glt.type != imagetype_t.it_pic) && (glt.type != imagetype_t.it_sky)) {
			WebGL_SelectTMU(WebGL.TEXTURE0);
			WebGL_Bind(glt.texture);
			gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, gl_filter_min);
			gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, gl_filter_max);

			/* Set anisotropic filter if supported and enabled */
			if (glconfig.anisotropic && gl_anisotropic.boolean) {
				gl.texParameteri(WebGL.TEXTURE_2D, ExtTextureFilterAnisotropic.TEXTURE_MAX_ANISOTROPY_EXT, gl_anisotropic.integer);
			}
		}
	}
}

WebGL_Bind(Texture texture) {
	// extern gl3image_t *draw_chars;

	// if (gl_nobind->value && draw_chars) /* performance evaluation option */
	// {
		// texnum = draw_chars->texnum;
	// }

	if (glstate.currenttexture == texture) {
		return;
	}

	glstate.currenttexture = texture;
	WebGL_SelectTMU(WebGL.TEXTURE0);
	gl.bindTexture(WebGL.TEXTURE_2D, texture);
}

WebGL_BindLightmap(int lightmapnum) {
	if(lightmapnum < 0 || lightmapnum >= MAX_LIGHTMAPS) {
		Com_Printf("WARNING: Invalid lightmapnum $lightmapnum used!\n");
		return;
	}

	if (glstate.currentlightmap == lightmapnum) {
		return;
	}

	glstate.currentlightmap = lightmapnum;
	for(int i=0; i<MAX_LIGHTMAPS_PER_SURFACE; ++i) {
		// this assumes that GL_TEXTURE<i+1> = GL_TEXTURE<i> + 1
		// at least for GL_TEXTURE0 .. GL_TEXTURE31 that's true
		WebGL_SelectTMU(WebGL.TEXTURE1+i);
		gl.bindTexture(WebGL.TEXTURE_2D, glstate.lightmap_textureIDs[lightmapnum][i]);
	}
}

/*
 * Returns has_alpha
 */
WebGL_Upload(Uint8List data, int width, int height, bool mipmap) {
	// qboolean res;

	// int samples;
	// int i, c;
	// byte *scan;
	// int comp;

	// c = width * height;
	// scan = ((byte *)data) + 3;
	// samples = gl3_solid_format;
	// comp = gl3_tex_solid_format;

	// for (i = 0; i < c; i++, scan += 4)
	// {
	// 	if (*scan != 255)
	// 	{
	// 		samples = gl3_alpha_format;
	// 		comp = gl3_tex_alpha_format;
	// 		break;
	// 	}
	// }

	gl.texImage2D(WebGL.TEXTURE_2D, 0, WebGL.RGBA, width, height,
	             0, WebGL.RGBA, WebGL.UNSIGNED_BYTE, data);

	// res = (samples == gl3_alpha_format);

	if (mipmap) {
		// TODO: some hardware may require mipmapping disabled for NPOT textures!
		gl.generateMipmap(WebGL.TEXTURE_2D);
		gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, gl_filter_min);
		gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, gl_filter_max);
	} else {
		gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, gl_filter_max);
		gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, gl_filter_max);
	}

	if (mipmap && glconfig.anisotropic && gl_anisotropic.boolean) {
		gl.texParameteri(WebGL.TEXTURE_2D, ExtTextureFilterAnisotropic.TEXTURE_MAX_ANISOTROPY_EXT, gl_anisotropic.integer);
	}

	// return res;
}



/*
 * This is also used as an entry point for the generated r_notexture
 */
webglimage_t WebGL_LoadPic(String name, Uint8List pic, int width, int realwidth,
            int height, int realheight, imagetype_t type) {

	var nolerp = false;

	if (gl_nolerp_list != null && gl_nolerp_list.string != null) {
		nolerp = gl_nolerp_list.string.contains(name);
	}

	/* find a free gl3image_t */
  int i;
	for (i = 0; i < gltextures.length; i++) {
    if (gltextures[i] == null || gltextures[i].texture == null) {
      break;
    }
	}

  webglimage_t image = webglimage_t(name);

	if (i >= gltextures.length) {
		if (gltextures.length == MAX_WEBGLTEXTURES) {
			Com_Error(ERR_DROP, "MAX_WEBGLTEXTURES");
		}

		gltextures.add(image);
	} else {
    gltextures[i] = image;
  }

	image.registration_sequence = registration_sequence;
  image.texturechain = null;

	image.width = width;
	image.height = height;
	image.type = type;

  image.texture = gl.createTexture();

	WebGL_SelectTMU(WebGL.TEXTURE0);
	WebGL_Bind(image.texture);

  WebGL_Upload(pic, width, height, (image.type != imagetype_t.it_pic && image.type != imagetype_t.it_sky));

	// if (realwidth && realheight)
	// {
	// 	if ((realwidth <= image->width) && (realheight <= image->height))
	// 	{
	// 		image->width = realwidth;
	// 		image->height = realheight;
	// 	}
	// 	else
	// 	{
	// 		R_Printf(PRINT_DEVELOPER,
	// 				"Warning, image '%s' has hi-res replacement smaller than the original! (%d x %d) < (%d x %d)\n",
	// 				name, image->width, image->height, realwidth, realheight);
	// 	}
	// }

	image.sl = 0;
	image.sh = 1;
	image.tl = 0;
	image.th = 1;

	if (nolerp) {
		gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, WebGL.NEAREST);
		gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, WebGL.NEAREST);
	}
	return image;
}


/*
 * Finds or loads the given image
 */
Future<webglimage_t> WebGL_FindImage(String name, imagetype_t type) async {

	if (name == null || name.isEmpty) {
		return null;
	}

  if (name.length < 5 || name[name.length - 4] != '.') {
		/* file has no extension */
		return null;
  }

	/* look for it */
	for (int i = 0; i < gltextures.length; i++) {
		if (gltextures[i] != null && gltextures[i].name == name) {
			gltextures[i].registration_sequence = registration_sequence;
			return gltextures[i];
		}
	}

  final pngname = name.substring(0, name.length - 4) + ".png";

  final buf = await FS_LoadFile(pngname);
  if (buf == null) {
    print("Cannot load $pngname");
    return null;
  }

  Image image = decodePng(buf.asUint8List());
  final bytes = image.getBytes();
  return WebGL_LoadPic(name, bytes, image.width, 0, image.height, 0, type);
}
