/*
 * Copyright (C) 1997-2001 Id Software, Inc.
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
 * This is the refresher dependend video menu. If you add a new
 * refresher this menu must be altered.
 *
 * =======================================================================
 */
import 'dart:math';
import 'package:dQuakeWeb/common/cvar.dart';

import 'qmenu.dart';
import 'menu.dart' show Key_GetMenuKey;
import '../cl_screen.dart' show SCR_GetMenuScale;
import '../cl_keyboard.dart';
import '../vid/vid.dart' show viddef, re;

cvar_t _r_mode;
cvar_t _gl_anisotropic;

menuframework_s _s_webgl_menu = menuframework_s();
menulist_s _s_mode_list = menulist_s("video mode");
menulist_s _s_af_list = menulist_s("aniso filtering");
menuaction_s _s_defaults_action = menuaction_s("reset to default");
menuaction_s _s_apply_action = menuaction_s("apply");


VID_MenuInit() {
	int y = 0;

	// static const char *renderers[] = {
	// 		"[OpenGL 1.4]",
	// 		"[OpenGL 3.2]",
	// 		"[Software  ]",
	// 		CUSTOM_MODE_NAME,
	// 		0
	// };

	// must be kept in sync with vid_modes[] in vid.c
	const resolutions = [
		"[320 240   ]",
		"[400 300   ]",
		"[512 384   ]",
		"[640 400   ]",
		"[640 480   ]",
		"[800 500   ]",
		"[800 600   ]",
		"[960 720   ]",
		"[1024 480  ]",
		"[1024 640  ]",
		"[1024 768  ]",
		"[1152 768  ]",
		"[1152 864  ]",
		"[1280 800  ]",
		"[1280 720  ]",
		"[1280 960  ]",
		"[1280 1024 ]",
		"[1366 768  ]",
		"[1440 900  ]",
		"[1600 1200 ]",
		"[1680 1050 ]",
		"[1920 1080 ]",
		"[1920 1200 ]",
		"[2048 1536 ]",
		"[2560 1080 ]",
		"[2560 1440 ]",
		"[2560 1600 ]",
		"[3440 1440 ]",
		"[3840 1600 ]",
		"[3840 2160 ]",
		"[4096 2160 ]",
		"[5120 2880 ]",
		// AUTO_MODE_NAME,
		// CUSTOM_MODE_NAME,
		// 0
	];

	// static const char *uiscale_names[] = {
	// 	"auto",
	// 	"1x",
	// 	"2x",
	// 	"3x",
	// 	"4x",
	// 	"5x",
	// 	"6x",
	// 	"custom",
	// 	0
	// };

	// static const char *yesno_names[] = {
	// 	"no",
	// 	"yes",
	// 	0
	// };

	// static const char *fullscreen_names[] = {
	// 		"no",
	// 		"keep resolution",
	// 		"switch resolution",
	// 		0
	// };

	const pow2_names = [
		"off",
		"2x",
		"4x",
		"8x",
		"16x"
	];

	if (_r_mode == null) {
		_r_mode = Cvar_Get("r_mode", "4", 0);
	}

	// if (!vid_displayindex)
	// {
	// 	vid_displayindex = Cvar_Get("vid_displayindex", "0", CVAR_ARCHIVE);
	// }

	// if (!r_hudscale)
	// {
	// 	r_hudscale = Cvar_Get("r_hudscale", "-1", CVAR_ARCHIVE);
	// }

	// if (!r_consolescale)
	// {
	// 	r_consolescale = Cvar_Get("r_consolescale", "-1", CVAR_ARCHIVE);
	// }

	// if (!r_menuscale)
	// {
	// 	r_menuscale = Cvar_Get("r_menuscale", "-1", CVAR_ARCHIVE);
	// }

	// if (!crosshair_scale)
	// {
	// 	crosshair_scale = Cvar_Get("crosshair_scale", "-1", CVAR_ARCHIVE);
	// }

	// if (!fov)
	// {
	// 	fov = Cvar_Get("fov", "90",  CVAR_USERINFO | CVAR_ARCHIVE);
	// }

	// if (!vid_gamma)
	// {
	// 	vid_gamma = Cvar_Get("vid_gamma", "1.2", CVAR_ARCHIVE);
	// }

	// if (!vid_renderer)
	// {
	// 	vid_renderer = Cvar_Get("vid_renderer", "gl1", CVAR_ARCHIVE);
	// }

	// if (!r_vsync)
	// {
	// 	r_vsync = Cvar_Get("r_vsync", "1", CVAR_ARCHIVE);
	// }

	if (_gl_anisotropic == null) {
		_gl_anisotropic = Cvar_Get("gl_anisotropic", "0", CVAR_ARCHIVE);
	}

	_s_webgl_menu.x = viddef.width ~/ 2;
	// s_opengl_menu.nitems = 0;

	// s_renderer_list.generic.type = MTYPE_SPINCONTROL;
	// s_renderer_list.generic.name = "renderer";
	// s_renderer_list.generic.x = 0;
	// s_renderer_list.generic.y = (y = 0);
	// s_renderer_list.itemnames = renderers;
	// s_renderer_list.curvalue = GetRenderer();

	_s_mode_list.x = 0;
	_s_mode_list.y = (y += 10);
	_s_mode_list.itemnames = resolutions;

	if (_r_mode.integer >= 0) {
		_s_mode_list.curvalue = _r_mode.integer;
	}
	// else if (r_mode->value == -2)
	// {
	// 	// 'auto' is before 'custom'
	// 	s_mode_list.curvalue = GetCustomValue(&s_mode_list) - 1;
	// }
	// else
	// {
	// 	// 'custom'
	// 	s_mode_list.curvalue = GetCustomValue(&s_mode_list);
	// }

	// if (GLimp_GetNumVideoDisplays() > 1)
	// {
	// 	s_display_list.generic.type = MTYPE_SPINCONTROL;
	// 	s_display_list.generic.name = "display index";
	// 	s_display_list.generic.x = 0;
	// 	s_display_list.generic.y = (y += 10);
	// 	s_display_list.itemnames = GLimp_GetDisplayIndices();
	// 	s_display_list.curvalue = GLimp_GetWindowDisplayIndex();
	// }

	// s_brightness_slider.generic.type = MTYPE_SLIDER;
	// s_brightness_slider.generic.name = "brightness";
	// s_brightness_slider.generic.x = 0;
	// s_brightness_slider.generic.y = (y += 20);
	// s_brightness_slider.generic.callback = BrightnessCallback;
	// s_brightness_slider.minvalue = 1;
	// s_brightness_slider.maxvalue = 20;
	// s_brightness_slider.curvalue = vid_gamma->value * 10;

	// s_fov_slider.generic.type = MTYPE_SLIDER;
	// s_fov_slider.generic.x = 0;
	// s_fov_slider.generic.y = (y += 10);
	// s_fov_slider.generic.name = "field of view";
	// s_fov_slider.generic.callback = FOVCallback;
	// s_fov_slider.minvalue = 60;
	// s_fov_slider.maxvalue = 120;
	// s_fov_slider.curvalue = fov->value;

	// s_uiscale_list.generic.type = MTYPE_SPINCONTROL;
	// s_uiscale_list.generic.name = "ui scale";
	// s_uiscale_list.generic.x = 0;
	// s_uiscale_list.generic.y = (y += 10);
	// s_uiscale_list.itemnames = uiscale_names;
	// if (r_hudscale->value != r_consolescale->value ||
	// 	r_hudscale->value != r_menuscale->value ||
	// 	r_hudscale->value != crosshair_scale->value)
	// {
	// 	s_uiscale_list.curvalue = GetCustomValue(&s_uiscale_list);
	// }
	// else if (r_hudscale->value < 0)
	// {
	// 	s_uiscale_list.curvalue = 0;
	// }
	// else if (r_hudscale->value > 0 &&
	// 		r_hudscale->value < GetCustomValue(&s_uiscale_list) &&
	// 		r_hudscale->value == (int)r_hudscale->value)
	// {
	// 	s_uiscale_list.curvalue = r_hudscale->value;
	// }
	// else
	// {
	// 	s_uiscale_list.curvalue = GetCustomValue(&s_uiscale_list);
	// }

	// s_fs_box.generic.type = MTYPE_SPINCONTROL;
	// s_fs_box.generic.name = "fullscreen";
	// s_fs_box.generic.x = 0;
	// s_fs_box.generic.y = (y += 10);
	// s_fs_box.itemnames = fullscreen_names;
	// s_fs_box.curvalue = (int)vid_fullscreen->value;

	// s_vsync_list.generic.type = MTYPE_SPINCONTROL;
	// s_vsync_list.generic.name = "vertical sync";
	// s_vsync_list.generic.x = 0;
	// s_vsync_list.generic.y = (y += 10);
	// s_vsync_list.itemnames = yesno_names;
	// s_vsync_list.curvalue = (r_vsync->value != 0);

	_s_af_list.x = 0;
	_s_af_list.y = (y += 10);
	// _s_af_list.generic.callback = AnisotropicCallback;
	_s_af_list.itemnames = pow2_names;
	_s_af_list.curvalue = 0;
	if (_gl_anisotropic.integer != 0) {
		do {
			_s_af_list.curvalue++;
		} while (_s_af_list.curvalue < pow2_names.length &&
				pow(2, _s_af_list.curvalue) <= _gl_anisotropic.integer);
		_s_af_list.curvalue--;
	}

	_s_defaults_action.x = 0;
	_s_defaults_action.y = (y += 20);
	// s_defaults_action.generic.callback = ResetDefaults;

	_s_apply_action.x = 0;
	_s_apply_action.y = (y += 10);
	// s_apply_action.generic.callback = ApplyChanges;

	// Menu_AddItem(&s_opengl_menu, (void *)&s_renderer_list);
	_s_webgl_menu.AddItem(_s_mode_list);

	// // only show this option if we have multiple displays
	// if (GLimp_GetNumVideoDisplays() > 1)
	// {
	// 	Menu_AddItem(&s_opengl_menu, (void *)&s_display_list);
	// }

	// Menu_AddItem(&s_opengl_menu, (void *)&s_brightness_slider);
	// Menu_AddItem(&s_opengl_menu, (void *)&s_fov_slider);
	// Menu_AddItem(&s_opengl_menu, (void *)&s_uiscale_list);
	// Menu_AddItem(&s_opengl_menu, (void *)&s_fs_box);
	// Menu_AddItem(&s_opengl_menu, (void *)&s_vsync_list);
	_s_webgl_menu.AddItem(_s_af_list);
	_s_webgl_menu.AddItem(_s_defaults_action);
	_s_webgl_menu.AddItem(_s_apply_action);

	_s_webgl_menu.Center();
	_s_webgl_menu.x -= 8;
}

Future<void> VID_MenuDraw() async {
	final scale = SCR_GetMenuScale();

	/* draw the banner */
	final size = await re.DrawGetPicSize("m_banner_video");
	await re.DrawPicScaled(viddef.width ~/ 2 - (size[0] * scale) ~/ 2, viddef.height ~/ 2 - (110 * scale).toInt(),
			"m_banner_video", scale);

	/* move cursor to a reasonable starting position */
	_s_webgl_menu.AdjustCursor(1);

	/* draw the menu */
	await _s_webgl_menu.Draw();
}

Future<String> VID_MenuKey(int key) async {
	// extern void M_PopMenu(void);

	// menuframework_s *m = &s_opengl_menu;
	var sound = "misc/menu1.wav";
	final menu_key = Key_GetMenuKey(key);

	switch (menu_key) {
	// 	case K_ESCAPE:
	// 		M_PopMenu();
	// 		return NULL;
		case K_UPARROW:
			_s_webgl_menu.cursor--;
			_s_webgl_menu.AdjustCursor(-1);
			break;
		case K_DOWNARROW:
			_s_webgl_menu.cursor++;
			_s_webgl_menu.AdjustCursor(1);
			break;
		case K_LEFTARROW:
			await _s_webgl_menu.SlideItem(-1);
			break;
		case K_RIGHTARROW:
			await _s_webgl_menu.SlideItem(1);
			break;
		case K_ENTER:
			await _s_webgl_menu.SelectItem();
			break;
	}

	return sound;
}