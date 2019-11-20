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
 * This file implements the generic part of the menu
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import '../cl_screen.dart' show SCR_GetMenuScale;
import '../vid/vid.dart' show viddef, re;

const MAXMENUITEMS = 64;

const MTYPE_SLIDER = 0;
const MTYPE_LIST = 1;
const MTYPE_ACTION = 2;
const MTYPE_SPINCONTROL = 3;
const MTYPE_SEPARATOR = 4;
const MTYPE_FIELD = 5;

const QMF_LEFT_JUSTIFY = 0x00000001;
const QMF_GRAYED = 0x00000002;
const QMF_NUMBERSONLY = 0x00000004;

const RCOLUMN_OFFSET = 16;
const LCOLUMN_OFFSET = -16;



class menuframework_s {
	int x = 0, y = 0;
	int cursor = 0;

	int nslots = 0;
  List<menucommon_s> items = [];

	String statusbar;

	// void ( = 0*cursordraw)(struct _tag_menuframework *m);

  AddItem(menucommon_s item) {
	  if (this.items.isEmpty) {
		  this.nslots = 0;
	  }

	  if (this.items.length < MAXMENUITEMS) {
      item.parent = this;
		  this.items.add(item);
	  }

	  this.nslots = this._TallySlots();
  }

  /*
  * This function takes the given menu, the direction, and attempts
  * to adjust the menu's cursor so that it's at the next available
  * slot.
  */
  AdjustCursor(int dir) {

    /* see if it's in a valid spot */
    if ((this.cursor >= 0) && (this.cursor < this.items.length)) {
      final citem = this.ItemAtCursor();
      if (citem != null) {
        if (citem.type != MTYPE_SEPARATOR) {
          return;
        }
      }
    }

    /* it's not in a valid spot, so crawl in the direction
      indicated until we find a valid spot */
    if (dir == 1) {
      while (true) {
        final citem = this.ItemAtCursor();
        if (citem != null) {
          if (citem.type != MTYPE_SEPARATOR) {
            break;
          }
        }

        this.cursor += dir;
        if (this.cursor >= this.items.length) {
          this.cursor = 0;
        }
      }
    } else {
      while (true) {
        final citem = this.ItemAtCursor();
        if (citem != null) {
          if (citem.type != MTYPE_SEPARATOR) {
            break;
          }
        }

        this.cursor += dir;

        if (this.cursor < 0) {
          this.cursor = this.items.length - 1;
        }
      }
    }
  }

  Center() {
    final scale = SCR_GetMenuScale();

    int height = this.items.last.y;
    height += 10;

    this.y = (viddef.height / scale - height) ~/ 2;
  }

  Draw() async {
    final scale = SCR_GetMenuScale();

    /* draw contents */
    for (final item in  this.items) {
      await item.draw();
      // switch (((menucommon_s *)menu->items[i])->type)
      // {
      //   case MTYPE_FIELD:
      //     Field_Draw((menufield_s *)menu->items[i]);
      //     break;
      //   case MTYPE_SLIDER:
      //     Slider_Draw((menuslider_s *)menu->items[i]);
      //     break;
      //   case MTYPE_LIST:
      //     MenuList_Draw((menulist_s *)menu->items[i]);
      //     break;
      //   case MTYPE_SPINCONTROL:
      //     SpinControl_Draw((menulist_s *)menu->items[i]);
      //     break;
      //   case MTYPE_ACTION:
      //     Action_Draw((menuaction_s *)menu->items[i]);
      //     break;
      //   case MTYPE_SEPARATOR:
      //     Separator_Draw((menuseparator_s *)menu->items[i]);
      //     break;
      // }
    }

    var item = this.ItemAtCursor();
    // if (item != null && item->cursordraw) {
    //   item->cursordraw(item);
    // } else if (menu->cursordraw) {
    //   menu->cursordraw(menu);
    // } else 
    if (item != null && (item.type != MTYPE_FIELD)) {
      if ((item.flags & QMF_LEFT_JUSTIFY) != 0) {
        re.DrawCharScaled(this.x + ((item.x / scale - 24 + item.cursor_offset) * scale).toInt(),
            ((this.y + item.y) * scale).toInt(),
            12 + ((Sys_Milliseconds() ~/ 250) & 1), scale);
      } else {
        re.DrawCharScaled(this.x + ((item.cursor_offset) * scale).toInt(),
            ((this.y + item.y) * scale).toInt(),
            12 + ((Sys_Milliseconds() ~/ 250) & 1), scale);
      }
    }

    if (item != null) {
    //   if (item->statusbarfunc) {
    //     item->statusbarfunc((void *)item);
    //   } else 
      if (item.statusbar != null) {
        Menu_DrawStatusBar(item.statusbar);
      } else {
        Menu_DrawStatusBar(this.statusbar);
      }
    } else {
      Menu_DrawStatusBar(this.statusbar);
    }
  }

  Future<bool> SelectItem() async {
	  final item = this.ItemAtCursor();
	  if (item != null) {
      return await item.DoEnter();
    }

    return false;
  }

  int _TallySlots() {
    int total = 0;

    for (final item in this.items) {
      if (item.type == MTYPE_LIST) {
        // int nitems = 0;
        // const char **n = ((menulist_s *)menu->items[i])->itemnames;

        // while (*n)
        // {
        //   nitems++, n++;
        // }

        // total += nitems;
      } else {
        total++;
      }
    }

    return total;
  }

  menucommon_s ItemAtCursor() {
    if ((this.cursor < 0) || (this.cursor >= this.items.length)) {
      return null;
    }

    return this.items[this.cursor];
  }

}

abstract class menucommon_s {
	int type;
	String name;
	int x = 0, y = 0;
	menuframework_s parent;
	int cursor_offset = 0;
	// int localdata[4];
	int flags = 0;

	String statusbar;

  Future<void> Function(menucommon_s) callback;
	// void (*statusbarfunc)(void *self);
	// void (*ownerdraw)(void *self);
	// void (*cursordraw)(void *self);

  menucommon_s(String name, int type) {
    this.name = name;
    this.type = type;
  }

  Future<void> draw();
  Future<bool> DoEnter() async { return false; }
}

class menuaction_s extends menucommon_s {
  menuaction_s(String name) : super(name, MTYPE_ACTION);

  Future<void> draw() async {
    final scale = SCR_GetMenuScale();

    if ((this.flags & QMF_LEFT_JUSTIFY) != 0) {
      if ((this.flags & QMF_GRAYED) != 0) {
        Menu_DrawStringDark(this.x + this.parent.x + (LCOLUMN_OFFSET * scale).toInt(),
            this.y + this.parent.y, this.name);
      } else {
        Menu_DrawString(this.x + this.parent.x + (LCOLUMN_OFFSET * scale).toInt(),
            this.y + this.parent.y, this.name);
      }
    } else {
      if ((this.flags & QMF_GRAYED) != 0) {
        Menu_DrawStringR2LDark(this.x + this.parent.x + (LCOLUMN_OFFSET * scale).toInt(),
            this.y + this.parent.y, this.name);
      } else {
        Menu_DrawStringR2L(this.x + this.parent.x + (LCOLUMN_OFFSET * scale).toInt(),
            this.y + this.parent.y, this.name);
      }
    }

    // if (this.ownerdraw) {
    //   this.ownerdraw();
    // }
  }

  @override
  Future<bool> DoEnter() async { 
    if (this.callback != null) {
      await this.callback(this);
    }
    return true;
    }
}

Menu_DrawStatusBar(String string) {
	final scale = SCR_GetMenuScale();

	if (string != null) {
		int l = string.length;
		final col = (viddef.width / 2) - (l*8 / 2) * scale;

		re.DrawFill(0, (viddef.height - 8 * scale).toInt(), viddef.width, (8 * scale).toInt(), 4);
		Menu_DrawString(col.toInt(), viddef.height ~/ scale - 8, string);
	} else {
		re.DrawFill(0, (viddef.height - 8 * scale).toInt(), viddef.width, (8 * scale).toInt(), 0);
	}
}

Menu_DrawString(int x, int y, String string) {
	final scale = SCR_GetMenuScale();

	for (int i = 0; i < string.length; i++) {
		re.DrawCharScaled((x + i * 8 * scale).toInt(), (y * scale).toInt(), string.codeUnitAt(i), scale);
	}
}

Menu_DrawStringDark(int x, int y, String string) {
	final scale = SCR_GetMenuScale();

	for (int i = 0; i < string.length; i++) {
		re.DrawCharScaled((x + i * 8 * scale).toInt(), (y * scale).toInt(), string.codeUnitAt(i) + 128, scale);
	}
}

Menu_DrawStringR2L(int x, int y, String string) {
	final scale = SCR_GetMenuScale();

	for (int i = 0; i < string.length; i++) {
		re.DrawCharScaled((x - i * 8 * scale).toInt(), (y * scale).toInt(), string.codeUnitAt(string.length - i - 1), scale);
	}
}

Menu_DrawStringR2LDark(int x, int y, String string) {
	final scale = SCR_GetMenuScale();

	for (int i = 0; i < string.length; i++) {
		re.DrawCharScaled((x - i * 8 * scale).toInt(), (y * scale).toInt(), string.codeUnitAt(string.length - i - 1) + 128, scale);
	}
}
