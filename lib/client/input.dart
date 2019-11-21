/*
 * Copyright (C) 2010 Yamagi Burmeister
 * Copyright (C) 1997-2005 Id Software, Inc.
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
 * Joystick threshold code is partially based on http://ioquake3.org code.
 *
 * =======================================================================
 *
 * This is the Quake II input system backend, implemented with SDL.
 *
 * =======================================================================
 */
import 'dart:html';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'cl_keyboard.dart';

class QKeyEvent {
  int code;
  bool pressed;

  QKeyEvent(this.code, this.pressed);
}

// The last time input events were processed.
// Used throughout the client.
int sys_frame_time = 0;

List<QKeyEvent> keyEvent = [];

int IN_ConvertKey(int code) {
  switch (code) {
    case 8: return K_BACKSPACE;
    case 9: return K_TAB;
    case 13: return K_ENTER;
    case 16: return K_SHIFT;
    case 17: return K_CTRL;
    case 18: return K_ALT;
    case 20: return K_CAPSLOCK;
    case 37: return K_LEFTARROW;
    case 38: return K_UPARROW;
    case 39: return K_RIGHTARROW;
    case 40: return K_DOWNARROW;
    // case 91: return ; // Meta
    // case 187: return ; // =
    // case 188: return ; // ,
    // case 189: return ; // -
    // case 190: return ; // .
    // case 191: return ; // /
    // case 192: return ; // ` 
    // case 219: return ; // [
    // case 220: return ; // \
    // case 221: return ; // ]
    // case 222: return ; // '
  }
  return -1;
}

/* ------------------------------------------------------------------ */

/*
 * Updates the input queue state. Called every
 * frame by the client and does nearly all the
 * input magic.
 */
IN_Update() async {

  while (keyEvent.isNotEmpty) {
    final event = keyEvent.first;
    keyEvent.removeAt(0);

    if (((event.code >= 48) && (event.code <= 57)) || // Numeric keys
        ((event.code >= 65) && (event.code <= 90))) {
      await Key_Event(event.code, event.pressed, false);
    } else if ((event.code >= 112) && (event.code <= 124)) { // Function keys F1 - F12
      await Key_Event(event.code - 112 + K_F1, event.pressed, true);
    } else {
      await Key_Event(IN_ConvertKey(event.code), event.pressed, true);
    }
  }

	// We need to save the frame time so other subsystems
	// know the exact time of the last input events.
	sys_frame_time = Sys_Milliseconds();
}

/*
 * Initializes the backend
 */
IN_Init() {
	Com_Printf("------- input initialization -------\n");

  window.onKeyUp.listen((KeyboardEvent e) {
    e.stopPropagation();
    keyEvent.add(QKeyEvent(e.keyCode, false));
  });

  window.onKeyDown.listen((KeyboardEvent e) {
    e.stopPropagation();
    keyEvent.add(QKeyEvent(e.keyCode, true));
  });

	Com_Printf("------------------------------------\n\n");
}