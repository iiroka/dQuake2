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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 * USA.
 *
 * =======================================================================
 *
 * This file implements the non generic part of the menu system, e.g.
 * the menu shown to the player. Beware! This code is very fragile and
 * should only be touched with great care and exessive testing.
 * Otherwise strange things and hard to track down bugs can occure. In a
 * better world someone would rewrite this file to something more like
 * Quake III Team Arena.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cmdparser.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import '../vid/vid.dart' show re, viddef;
import '../client.dart';
import '../cl_screen.dart' show SCR_DirtyScreen, SCR_GetMenuScale;
import '../cl_keyboard.dart';
import '../cl_network.dart' show CL_Disconnect;
import 'qmenu.dart';

typedef MenuDrawFunction = Future<void> Function();
typedef MenuKeyFunction = Future<String> Function(int);

int m_main_cursor = 0;

/* Number of the frames of the spinning quake logo */
const NUM_CURSOR_FRAMES = 15;

const menu_in_sound = "misc/menu1.wav";
const menu_move_sound = "misc/menu2.wav";
const menu_out_sound = "misc/menu3.wav";

MenuDrawFunction m_drawfunc;
MenuKeyFunction m_keyfunc;

/* Maximal number of submenus */
const MAX_MENU_DEPTH = 8;

class menulayer_t {
    MenuDrawFunction draw;
    MenuKeyFunction key;

    menulayer_t(this.draw, this.key);
}

List<menulayer_t> m_layers = [];

M_Banner(String name) async {
	final scale = SCR_GetMenuScale();
  final size = await re.DrawGetPicSize(name);
  await re.DrawPicScaled(viddef.width ~/ 2 - (size[0] * scale) ~/ 2, viddef.height ~/ 2 - (110 * scale).toInt(), name, scale);
}


M_ForceMenuOff() {
    m_drawfunc = null;
    m_keyfunc = null;
    cls.key_dest = keydest_t.key_game;
    m_layers = [];
	  // Key_MarkAllUp();
    Cvar_Set("paused", "0");
}


M_PopMenu() {
    // S_StartLocalSound(menu_out_sound);

    if (m_layers.isEmpty) {
        Com_Error(ERR_FATAL, "M_PopMenu: depth < 1");
    }

    m_layers.removeLast();
    if (m_layers.isNotEmpty) {
      final layer = m_layers.last;
      m_drawfunc = layer.draw;
      m_keyfunc = layer.key;
    } else {
      M_ForceMenuOff();
    }

}

/*
 * This crappy function maintaines a stack of opened menus.
 * The steps in this horrible mess are:
 *
 * 1. But the game into pause if a menu is opened
 *
 * 2. If the requested menu is already open, close it.
 *
 * 3. If the requested menu is already open but not
 *    on top, close all menus above it and the menu
 *    itself. This is necessary since an instance of
 *    the reqeuested menu is in flight and will be
 *    displayed.
 *
 * 4. Save the previous menu on top (which was in flight)
 *    to the stack and make the requested menu the menu in
 *    flight.
 */
M_PushMenu(MenuDrawFunction draw, MenuKeyFunction key) {
    
    if ((Cvar_VariableInt("maxclients") == 1) &&
            Com_ServerState() != 0) {
        Cvar_Set("paused", "1");
    }

    // if (cl.cinematic_file && sound_started == SS_OAL)
    // {
    //     AL_UnqueueRawSamples();
    // }

    /* if this menu is already open (and on top),
       close it => toggling behaviour */
    if ((m_drawfunc == draw) && (m_keyfunc == key)) {
        M_PopMenu();
        return;
    }

    /* if this menu is already present, drop back to
       that level to avoid stacking menus by hotkeys */
    bool alreadyPresent = false;
    int i;
    for (i = 0; i < m_layers.length; i++) {
        if ((m_layers[i].draw == draw) &&
            (m_layers[i].key == key)) {
            alreadyPresent = true;
            break;
        }
    }

    /* menu was already opened further down the stack */
    while (alreadyPresent && i <= m_layers.length) {
        M_PopMenu(); /* decrements m_menudepth */
    }

    if (m_layers.length >= MAX_MENU_DEPTH) {
        Com_Printf("Too many open menus!\n");
        return;
    }

    m_layers.add(menulayer_t(draw, key));

    m_drawfunc = draw;
    m_keyfunc = key;

    // m_entersound = true;

    cls.key_dest = keydest_t.key_menu;
}

/*
 * Draws one solid graphics character cx and cy are in 320*240
 * coordinates, and will be centered on higher res screens.
 */
_M_DrawCharacter(int cx, int cy, int num) {
	final scale = SCR_GetMenuScale();
	re.DrawCharScaled(cx + ((viddef.width - 320 * scale).toInt() >> 1), cy + ((viddef.height - 240 * scale).toInt() >> 1), num, scale);
}

_M_Print(int x, int y, String str) {
	final scale = SCR_GetMenuScale();

  int cx = x;
  int cy = y;
  int index = 0;
  while (index < str.length) {
      if (str[index] == '\n') {
          cx = x;
          cy += 8;
      } else {
          _M_DrawCharacter((cx * scale).toInt(), (cy * scale).toInt(), str.codeUnitAt(index) + 128);
          cx += 8;
      }
      index++;
  }
}
/*
 * Draws an animating cursor with the point at
 * x,y. The pic will extend to the left of x,
 * and both above and below y.
 */
bool _mcurors_cached = false;
_M_DrawCursor(int x, int y, int f) async {
	  final scale = SCR_GetMenuScale();

    if (!_mcurors_cached) {

        for (int i = 0; i < NUM_CURSOR_FRAMES; i++) {
            await re.DrawFindPic("m_cursor$i");
        }

        _mcurors_cached = true;
    }

    await re.DrawPicScaled((x * scale).toInt(), (y * scale).toInt(), "m_cursor$f", scale);
}

_M_DrawTextBox(int x, int y, int width, int lines) {
	final scale = SCR_GetMenuScale();

  /* draw left side */
  int cx = x;
  int cy = y;
  _M_DrawCharacter((cx * scale).toInt(), (cy * scale).toInt(), 1);

  for (int n = 0; n < lines; n++) {
      cy += 8;
      _M_DrawCharacter((cx * scale).toInt(), (cy * scale).toInt(), 4);
  }

  _M_DrawCharacter((cx * scale).toInt(), (cy * scale + 8 * scale).toInt(), 7);

  /* draw middle */
  cx += 8;

  while (width > 0) {
      cy = y;
      _M_DrawCharacter((cx * scale).toInt(), (cy * scale).toInt(), 2);

      for (int n = 0; n < lines; n++) {
          cy += 8;
          _M_DrawCharacter((cx * scale).toInt(), (cy * scale).toInt(), 5);
      }

      _M_DrawCharacter((cx * scale).toInt(), (cy *scale + 8 * scale).toInt(), 8);
      width -= 1;
      cx += 8;
  }

  /* draw right side */
  cy = y;
  _M_DrawCharacter((cx * scale).toInt(), (cy * scale).toInt(), 3);

  for (int n = 0; n < lines; n++) {
      cy += 8;
      _M_DrawCharacter((cx * scale).toInt(), (cy * scale).toInt(), 6);
  }

  _M_DrawCharacter((cx * scale).toInt(), (cy * scale + 8 * scale).toInt(), 9);
}

String _m_popup_string;
int _m_popup_endtime = 0;

_M_Popup() {

    if (_m_popup_string == null) {
        return;
    }

    if (_m_popup_endtime != 0 && _m_popup_endtime < cls.realtime) {
        _m_popup_string = null;
        return;
    }

    int width = 0;
    int lines = 0;
    int n = 0;
    for (int index = 0; index < _m_popup_string.length; index++) {
        if (_m_popup_string[index] == '\n') {
            lines++;
            n = 0;
        } else {
            n++;
            if (n > width) {
                width = n;
            }
        }
    }
    if (n != 0) {
        lines++;
    }

    if (width != 0) {
        width += 2;

        int x = (320 - (width + 2) * 8) ~/ 2;
        int y = (240 - (lines + 2) * 8) ~/ 3;

        _M_DrawTextBox(x, y, width, lines);
        _M_Print(x + 16, y + 8, _m_popup_string);
    }
}


int Key_GetMenuKey(int key) {
	switch (key) {
		case K_KP_UPARROW:
		case K_UPARROW:
		case K_HAT_UP:
			return K_UPARROW;

		case K_TAB:
		case K_KP_DOWNARROW:
		case K_DOWNARROW:
		case K_HAT_DOWN:
			return K_DOWNARROW;

		case K_KP_LEFTARROW:
		case K_LEFTARROW:
		case K_HAT_LEFT:
		case K_TRIG_LEFT:
			return K_LEFTARROW;

		case K_KP_RIGHTARROW:
		case K_RIGHTARROW:
		case K_HAT_RIGHT:
		case K_TRIG_RIGHT:
			return K_RIGHTARROW;

		case K_MOUSE1:
		case K_MOUSE2:
		case K_MOUSE3:
		case K_MOUSE4:
		case K_MOUSE5:

		case K_JOY1:
		case K_JOY2:
		case K_JOY3:
		case K_JOY4:
		case K_JOY5:
		case K_JOY6:
		case K_JOY7:
		case K_JOY8:
		case K_JOY9:
		case K_JOY10:
		case K_JOY11:
		case K_JOY12:
		case K_JOY13:
		case K_JOY14:
		case K_JOY15:
		case K_JOY16:
		case K_JOY17:
		case K_JOY18:
		case K_JOY19:
		case K_JOY20:
		case K_JOY21:
		case K_JOY22:
		case K_JOY23:
		case K_JOY24:
		case K_JOY25:
		case K_JOY26:
		case K_JOY27:
		case K_JOY28:
		case K_JOY29:
		case K_JOY30:
		case K_JOY31:

		case K_AUX1:
		case K_AUX2:
		case K_AUX3:
		case K_AUX4:
		case K_AUX5:
		case K_AUX6:
		case K_AUX7:
		case K_AUX8:
		case K_AUX9:
		case K_AUX10:
		case K_AUX11:
		case K_AUX12:
		case K_AUX13:
		case K_AUX14:
		case K_AUX15:
		case K_AUX16:
		case K_AUX17:
		case K_AUX18:
		case K_AUX19:
		case K_AUX20:
		case K_AUX21:
		case K_AUX22:
		case K_AUX23:
		case K_AUX24:
		case K_AUX25:
		case K_AUX26:
		case K_AUX27:
		case K_AUX28:
		case K_AUX29:
		case K_AUX30:
		case K_AUX31:
		case K_AUX32:

		case K_KP_ENTER:
		case K_ENTER:
			return K_ENTER;

		case K_ESCAPE:
		case K_JOY_BACK:
			return K_ESCAPE;
	}

	return key;
}

Future<String> Default_MenuKey(menuframework_s m, int key) async {
    String sound;
    int menu_key = Key_GetMenuKey(key);

    if (m != null) {
        final item = m.ItemAtCursor();
        if (item != null) {
            if (item.type == MTYPE_FIELD) {
                // if (Field_Key((menufield_s *)item, key)) {
                //     return NULL;
                // }
            }
        }
    }

    switch (menu_key)
    {
    case K_ESCAPE:
        M_PopMenu();
        return menu_out_sound;

    case K_UPARROW:
        if (m != null) {
            m.cursor--;
            m.AdjustCursor(-1);
            sound = menu_move_sound;
        }
        break;

    case K_DOWNARROW:
        if (m != null) {
            m.cursor++;
            m.AdjustCursor(1);
            sound = menu_move_sound;
        }
        break;

    case K_LEFTARROW:
        if (m != null) {
            await m.SlideItem(-1);
            sound = menu_move_sound;
        }
        break;

    case K_RIGHTARROW:
        if (m != null) {
            await m.SlideItem(1);
            sound = menu_move_sound;
        }
        break;

    case K_ENTER:
        if (m != null) {
            await m.SelectItem();
        }
        sound = menu_move_sound;
        break;
    }

    return sound;
}

/*
 * MAIN MENU
 */

const MAIN_ITEMS = 5;

Future<void> _M_Main_Draw() async {
  final scale = SCR_GetMenuScale();
  final names =[
      "m_main_game",
      "m_main_multiplayer",
      "m_main_options",
      "m_main_video",
      "m_main_quit"
  ];

  int widest = -1;
  int totalheight = 0;
  for (final name in names) {
      final size = await re.DrawGetPicSize(name);
      if (size[0] > widest) {
          widest = size[0];
      }

      totalheight += (size[1] + 12);
  }

  int ystart = (viddef.height ~/ (2 * scale) - 110);
  int xoffset = (viddef.width / scale - widest + 70) ~/ 2;

  for (int i = 0; i < names.length; i++) {
      if (i != m_main_cursor) {
          await re.DrawPicScaled((xoffset * scale).toInt(), ((ystart + i * 40 + 13) * scale).toInt(), names[i], scale);
      }
  }

  await re.DrawPicScaled((xoffset * scale).toInt(), ((ystart + m_main_cursor * 40 + 13) * scale).toInt(), names[m_main_cursor] + "_sel", scale);

  await _M_DrawCursor(xoffset - 25, ystart + m_main_cursor * 40 + 11,
                (cls.realtime ~/ 100) % NUM_CURSOR_FRAMES);

  final size = await re.DrawGetPicSize("m_main_plaque");
  await re.DrawPicScaled(((xoffset - 30 - size[0]) * scale).toInt(), (ystart * scale).toInt(), "m_main_plaque", scale);

  await re.DrawPicScaled(((xoffset - 30 - size[0]) * scale).toInt(), ((ystart + size[1] + 5) * scale).toInt(), "m_main_logo", scale);
}

Future<String> _M_Main_Key(int key) async  {
	String sound = menu_move_sound;
	final menu_key = Key_GetMenuKey(key);

    switch (menu_key) {
    case K_ESCAPE:
        M_PopMenu();
        break;

    case K_DOWNARROW:
        if (++m_main_cursor >= MAIN_ITEMS) {
            m_main_cursor = 0;
        }
        return sound;

    case K_UPARROW:
        if (--m_main_cursor < 0) {
            m_main_cursor = MAIN_ITEMS - 1;
        }
        return sound;

    case K_ENTER:
  //       m_entersound = true;

        switch (m_main_cursor) {
        case 0:
            await M_Menu_Game_f([]);
            break;

  //       case 1:
  //           M_Menu_Multiplayer_f();
  //           break;

        case 2:
            await M_Menu_Options_f([]);
            break;

  //       case 3:
  //           M_Menu_Video_f();
  //           break;

  //       case 4:
  //           M_Menu_Quit_f();
  //           break;
        }
    }

    return null;
}


M_Menu_Main_f(List<String> args) async {
    await M_PushMenu(_M_Main_Draw, _M_Main_Key);
}

/*
 * CONTROLS MENU
 */

menuframework_s _s_options_menu = menuframework_s();
menuaction_s _s_options_defaults_action = menuaction_s("reset defaults");
menuslider_s _s_options_sfxvolume_slider = menuslider_s("effects volume");

_ControlsSetMenuItemValues() {
    _s_options_sfxvolume_slider.curvalue = Cvar_VariableValue("s_volume") * 10;
    // s_options_oggshuffle_box.curvalue = (Cvar_VariableValue("ogg_shuffle") != 0);
    // s_options_oggvolume_slider.curvalue = Cvar_VariableValue("ogg_volume") * 10;
    // s_options_oggenable_box.curvalue = (Cvar_VariableValue("ogg_enable") != 0);
    // s_options_quality_list.curvalue = (Cvar_VariableValue("s_loadas8bit") == 0);
    // s_options_sensitivity_slider.curvalue = sensitivity->value * 2;
    // s_options_alwaysrun_box.curvalue = (cl_run->value != 0);
    // s_options_invertmouse_box.curvalue = (m_pitch->value < 0);
    // s_options_lookstrafe_box.curvalue = (lookstrafe->value != 0);
    // s_options_freelook_box.curvalue = (freelook->value != 0);
    // s_options_crosshair_box.curvalue = ClampCvar(0, 3, crosshair->value);
    // s_options_haptic_slider.curvalue = Cvar_VariableValue("joy_haptic_magnitude") * 10.0F;
}

Future<void> _ControlsResetDefaultsFunc(menucommon_s) async {
    Cbuf_AddText("exec default.cfg\n");
    Cbuf_AddText("exec yq2.cfg\n");
    await Cbuf_Execute();
    _ControlsSetMenuItemValues();
}

Future<void> _UpdateVolumeFunc(menucommon_s) async {
    Cvar_Set("s_volume", (_s_options_sfxvolume_slider.curvalue / 10).toString());
}

_Options_MenuInit() {
    // static const char *ogg_music_items[] =
    // {
    //     "disabled",
    //     "enabled",
    //     0
    // };

    // static const char *ogg_shuffle[] =
    // {
    //     "disabled",
    //     "enabled",
    //     0
    // };

    // static const char *quality_items[] =
    // {
    //     "normal", "high", 0
    // };

    // static const char *yesno_names[] =
    // {
    //     "no",
    //     "yes",
    //     0
    // };

    // static const char *crosshair_names[] =
    // {
    //     "none",
    //     "cross",
    //     "dot",
    //     "angle",
    //     0
    // };

    final scale = SCR_GetMenuScale();
    // extern qboolean show_haptic;

    /* configure controls menu and menu items */
    _s_options_menu.x = viddef.width ~/ 2;
    _s_options_menu.y = viddef.height ~/ (2 * scale) - 58;
    // s_options_menu.nitems = 0;

    _s_options_sfxvolume_slider.x = 0;
    _s_options_sfxvolume_slider.y = 0;
    _s_options_sfxvolume_slider.callback = _UpdateVolumeFunc;
    _s_options_sfxvolume_slider.minvalue = 0;
    _s_options_sfxvolume_slider.maxvalue = 10;

    // s_options_oggvolume_slider.generic.type = MTYPE_SLIDER;
    // s_options_oggvolume_slider.generic.x = 0;
    // s_options_oggvolume_slider.generic.y = 10;
    // s_options_oggvolume_slider.generic.name = "OGG volume";
    // s_options_oggvolume_slider.generic.callback = UpdateOggVolumeFunc;
    // s_options_oggvolume_slider.minvalue = 0;
    // s_options_oggvolume_slider.maxvalue = 10;

    // s_options_oggenable_box.generic.type = MTYPE_SPINCONTROL;
    // s_options_oggenable_box.generic.x = 0;
    // s_options_oggenable_box.generic.y = 20;
    // s_options_oggenable_box.generic.name = "OGG music";
    // s_options_oggenable_box.generic.callback = EnableOGGMusic;
    // s_options_oggenable_box.itemnames = ogg_music_items;

    // s_options_oggshuffle_box.generic.type = MTYPE_SPINCONTROL;
    // s_options_oggshuffle_box.generic.x = 0;
    // s_options_oggshuffle_box.generic.y = 30;
    // s_options_oggshuffle_box.generic.name = "Shuffle";
    // s_options_oggshuffle_box.generic.callback = OGGShuffleFunc;
    // s_options_oggshuffle_box.itemnames = ogg_shuffle;

    // s_options_quality_list.generic.type = MTYPE_SPINCONTROL;
    // s_options_quality_list.generic.x = 0;
    // s_options_quality_list.generic.y = 40;
    // s_options_quality_list.generic.name = "sound quality";
    // s_options_quality_list.generic.callback = UpdateSoundQualityFunc;
    // s_options_quality_list.itemnames = quality_items;

    // s_options_sensitivity_slider.generic.type = MTYPE_SLIDER;
    // s_options_sensitivity_slider.generic.x = 0;
    // s_options_sensitivity_slider.generic.y = 60;
    // s_options_sensitivity_slider.generic.name = "mouse speed";
    // s_options_sensitivity_slider.generic.callback = MouseSpeedFunc;
    // s_options_sensitivity_slider.minvalue = 2;
    // s_options_sensitivity_slider.maxvalue = 22;

    // s_options_alwaysrun_box.generic.type = MTYPE_SPINCONTROL;
    // s_options_alwaysrun_box.generic.x = 0;
    // s_options_alwaysrun_box.generic.y = 70;
    // s_options_alwaysrun_box.generic.name = "always run";
    // s_options_alwaysrun_box.generic.callback = AlwaysRunFunc;
    // s_options_alwaysrun_box.itemnames = yesno_names;

    // s_options_invertmouse_box.generic.type = MTYPE_SPINCONTROL;
    // s_options_invertmouse_box.generic.x = 0;
    // s_options_invertmouse_box.generic.y = 80;
    // s_options_invertmouse_box.generic.name = "invert mouse";
    // s_options_invertmouse_box.generic.callback = InvertMouseFunc;
    // s_options_invertmouse_box.itemnames = yesno_names;

    // s_options_lookstrafe_box.generic.type = MTYPE_SPINCONTROL;
    // s_options_lookstrafe_box.generic.x = 0;
    // s_options_lookstrafe_box.generic.y = 90;
    // s_options_lookstrafe_box.generic.name = "lookstrafe";
    // s_options_lookstrafe_box.generic.callback = LookstrafeFunc;
    // s_options_lookstrafe_box.itemnames = yesno_names;

    // s_options_freelook_box.generic.type = MTYPE_SPINCONTROL;
    // s_options_freelook_box.generic.x = 0;
    // s_options_freelook_box.generic.y = 100;
    // s_options_freelook_box.generic.name = "free look";
    // s_options_freelook_box.generic.callback = FreeLookFunc;
    // s_options_freelook_box.itemnames = yesno_names;

    // s_options_crosshair_box.generic.type = MTYPE_SPINCONTROL;
    // s_options_crosshair_box.generic.x = 0;
    // s_options_crosshair_box.generic.y = 110;
    // s_options_crosshair_box.generic.name = "crosshair";
    // s_options_crosshair_box.generic.callback = CrosshairFunc;
    // s_options_crosshair_box.itemnames = crosshair_names;

    // s_options_haptic_slider.generic.type = MTYPE_SLIDER;
    // s_options_haptic_slider.generic.x = 0;
    // s_options_haptic_slider.generic.y = 120;
    // s_options_haptic_slider.generic.name = "haptic magnitude";
    // s_options_haptic_slider.generic.callback = HapticMagnitudeFunc;
    // s_options_haptic_slider.minvalue = 0;
    // s_options_haptic_slider.maxvalue = 22;

    // s_options_customize_options_action.generic.type = MTYPE_ACTION;
    // s_options_customize_options_action.generic.x = 0;
    // s_options_customize_options_action.generic.y = 140;
    // s_options_customize_options_action.generic.name = "customize controls";
    // s_options_customize_options_action.generic.callback = CustomizeControlsFunc;

    _s_options_defaults_action.x = 0;
    _s_options_defaults_action.y = 150;
    _s_options_defaults_action.callback = _ControlsResetDefaultsFunc;

    // s_options_console_action.generic.type = MTYPE_ACTION;
    // s_options_console_action.generic.x = 0;
    // s_options_console_action.generic.y = 160;
    // s_options_console_action.generic.name = "go to console";
    // s_options_console_action.generic.callback = ConsoleFunc;

    // ControlsSetMenuItemValues();

    _s_options_menu.AddItem(_s_options_sfxvolume_slider);

    // Menu_AddItem(&s_options_menu, (void *)&s_options_oggvolume_slider);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_oggenable_box);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_oggshuffle_box);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_quality_list);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_sensitivity_slider);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_alwaysrun_box);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_invertmouse_box);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_lookstrafe_box);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_freelook_box);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_crosshair_box);

    // if (show_haptic)
    //     Menu_AddItem(&s_options_menu, (void *)&s_options_haptic_slider);

    // Menu_AddItem(&s_options_menu, (void *)&s_options_customize_options_action);
    _s_options_menu.AddItem(_s_options_defaults_action);
    // Menu_AddItem(&s_options_menu, (void *)&s_options_console_action);
}

Future<void> _Options_MenuDraw() async {
    await M_Banner("m_banner_options");
    _s_options_menu.AdjustCursor(1);
    await _s_options_menu.Draw();
    _M_Popup();
}

Future<String> _Options_MenuKey(int key) async  {
    if (_m_popup_string != null) {
        _m_popup_string = null;
        return null;
    }
    return Default_MenuKey(_s_options_menu, key);
}

M_Menu_Options_f(List<String> args) async {
    _Options_MenuInit();
    M_PushMenu(_Options_MenuDraw, _Options_MenuKey);
}

/*
 * GAME MENU
 */

int _m_game_cursor = 0;

menuframework_s _s_game_menu = menuframework_s();
menuaction_s _s_easy_game_action = menuaction_s("easy");
menuaction_s _s_medium_game_action = menuaction_s("medium");
menuaction_s _s_hard_game_action = menuaction_s("hard");
menuaction_s _s_hardp_game_action = menuaction_s("nightmare");
// static menuaction_s s_load_game_action;
// static menuaction_s s_save_game_action;
// static menuaction_s s_credits_action;
// static menuseparator_s s_blankline;

_StartGame() {
	if (cls.state != connstate_t.ca_disconnected && cls.state != connstate_t.ca_uninitialized) {
		CL_Disconnect();
	}

    /* disable updates and start the cinematic going */
    cl.servercount = -1;
    M_ForceMenuOff();
    Cvar_Set("deathmatch", "0");
    Cvar_Set("coop", "0");

    Cbuf_AddText("loading ; killserver ; wait ; newgame\n");
    cls.key_dest = keydest_t.key_game;
}

Future<void> _EasyGameFunc(menucommon_s) async {
    Cvar_ForceSet("skill", "0");
    _StartGame();
}

Future<void> _MediumGameFunc(menucommon_s) async {
    Cvar_ForceSet("skill", "1");
    _StartGame();
}

// static void
// HardGameFunc(void *data)
// {
//     Cvar_ForceSet("skill", "2");
//     StartGame();
// }

// static void
// HardpGameFunc(void *data)
// {
//     Cvar_ForceSet("skill", "3");
//     StartGame();
// }

// static void
// LoadGameFunc(void *unused)
// {
//     M_Menu_LoadGame_f();
// }

// static void
// SaveGameFunc(void *unused)
// {
//     M_Menu_SaveGame_f();
// }

// static void
// CreditsFunc(void *unused)
// {
//     M_Menu_Credits_f();
// }

Game_MenuInit() {
    _s_game_menu.x = (viddef.width * 0.50).toInt();

    _s_easy_game_action.flags = QMF_LEFT_JUSTIFY;
    _s_easy_game_action.x = 0;
    _s_easy_game_action.y = 0;
    _s_easy_game_action.callback = _EasyGameFunc;

    _s_medium_game_action.flags = QMF_LEFT_JUSTIFY;
    _s_medium_game_action.x = 0;
    _s_medium_game_action.y = 10;
    _s_easy_game_action.callback = _MediumGameFunc;

    _s_hard_game_action.flags = QMF_LEFT_JUSTIFY;
    _s_hard_game_action.x = 0;
    _s_hard_game_action.y = 20;
//     s_hard_game_action.generic.callback = HardGameFunc;

    _s_hardp_game_action.flags = QMF_LEFT_JUSTIFY;
    _s_hardp_game_action.x = 0;
    _s_hardp_game_action.y = 30;
//     s_hardp_game_action.generic.callback = HardpGameFunc;

//     s_blankline.generic.type = MTYPE_SEPARATOR;

//     s_load_game_action.generic.type = MTYPE_ACTION;
//     s_load_game_action.generic.flags = QMF_LEFT_JUSTIFY;
//     s_load_game_action.generic.x = 0;
//     s_load_game_action.generic.y = 50;
//     s_load_game_action.generic.name = "load game";
//     s_load_game_action.generic.callback = LoadGameFunc;

//     s_save_game_action.generic.type = MTYPE_ACTION;
//     s_save_game_action.generic.flags = QMF_LEFT_JUSTIFY;
//     s_save_game_action.generic.x = 0;
//     s_save_game_action.generic.y = 60;
//     s_save_game_action.generic.name = "save game";
//     s_save_game_action.generic.callback = SaveGameFunc;

//     s_credits_action.generic.type = MTYPE_ACTION;
//     s_credits_action.generic.flags = QMF_LEFT_JUSTIFY;
//     s_credits_action.generic.x = 0;
//     s_credits_action.generic.y = 70;
//     s_credits_action.generic.name = "credits";
//     s_credits_action.generic.callback = CreditsFunc;

  _s_game_menu.AddItem(_s_easy_game_action);
  _s_game_menu.AddItem(_s_medium_game_action);
  _s_game_menu.AddItem(_s_hard_game_action);
  _s_game_menu.AddItem(_s_hardp_game_action);
//     Menu_AddItem(&s_game_menu, (void *)&s_blankline);
//     Menu_AddItem(&s_game_menu, (void *)&s_load_game_action);
//     Menu_AddItem(&s_game_menu, (void *)&s_save_game_action);
//     Menu_AddItem(&s_game_menu, (void *)&s_blankline);
//     Menu_AddItem(&s_game_menu, (void *)&s_credits_action);

    _s_game_menu.Center();
}

Future<void> _Game_MenuDraw() async {
    await M_Banner("m_banner_game");
    _s_game_menu.AdjustCursor(1);
    await _s_game_menu.Draw();
}

Future<String> _Game_MenuKey(int key) async  {
  return await Default_MenuKey(_s_game_menu, key);
}

M_Menu_Game_f(List<String> args) async {
    Game_MenuInit();
    M_PushMenu(_Game_MenuDraw, _Game_MenuKey);
    _m_game_cursor = 1;
}

M_Init() {
    Cmd_AddCommand("menu_main", M_Menu_Main_f);
    Cmd_AddCommand("menu_game", M_Menu_Game_f);
    // Cmd_AddCommand("menu_loadgame", M_Menu_LoadGame_f);
    // Cmd_AddCommand("menu_savegame", M_Menu_SaveGame_f);
    // Cmd_AddCommand("menu_joinserver", M_Menu_JoinServer_f);
    // Cmd_AddCommand("menu_addressbook", M_Menu_AddressBook_f);
    // Cmd_AddCommand("menu_startserver", M_Menu_StartServer_f);
    // Cmd_AddCommand("menu_dmoptions", M_Menu_DMOptions_f);
    // Cmd_AddCommand("menu_playerconfig", M_Menu_PlayerConfig_f);
    // Cmd_AddCommand("menu_downloadoptions", M_Menu_DownloadOptions_f);
    // Cmd_AddCommand("menu_credits", M_Menu_Credits_f);
    // Cmd_AddCommand("menu_multiplayer", M_Menu_Multiplayer_f);
    // Cmd_AddCommand("menu_video", M_Menu_Video_f);
    Cmd_AddCommand("menu_options", M_Menu_Options_f);
    // Cmd_AddCommand("menu_keys", M_Menu_Keys_f);
    // Cmd_AddCommand("menu_quit", M_Menu_Quit_f);

    /* initialize the server address book cvars (adr0, adr1, ...)
     * so the entries are not lost if you don't open the address book */
    // for (int index = 0; index < NUM_ADDRESSBOOK_ENTRIES; index++) {
    //     char buffer[20];
    //     Com_sprintf(buffer, sizeof(buffer), "adr%d", index);
    //     Cvar_Get(buffer, "", CVAR_ARCHIVE);
    // }
}

M_Draw() async {
    if (cls.key_dest != keydest_t.key_menu) {
        return;
    }

    /* repaint everything next frame */
    SCR_DirtyScreen();

    /* dim everything behind it down */
    // if (cl.cinematictime > 0) {
    //     Draw_Fill(0, 0, viddef.width, viddef.height, 0);
    // } else {
    //     Draw_FadeScreen();
    // }

    await m_drawfunc();

    /* delay playing the enter sound until after the
       menu has been drawn, to avoid delay while
       caching images */
    // if (m_entersound) {
    //     S_StartLocalSound(menu_in_sound);
    //     m_entersound = false;
    // }
}

M_Keydown(int key) async {
  print("M_Keydown $key");
  if (m_keyfunc != null) {
      final s = await m_keyfunc(key);
      if (s != null) {
  //         S_StartLocalSound((char *)s);
      }
  }
}
