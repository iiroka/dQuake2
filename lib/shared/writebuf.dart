/*
 * Copyright (C) 1997-2001 Id Software, Inc.
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
 */
import 'dart:typed_data';
import 'dart:convert';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/shared.dart';

class Writebuf {
	bool allowoverflow = false;     /* if false, do a Com_Error */
	bool overflowed = false;        /* set to true if the buffer size failed */
	Int8List data;
	int cursize = 0;

  Writebuf(Int8List data) {
    this.data = data;
  }

  Writebuf.size(int size) {
    this.data = Int8List(size);
  }

  Init() {
    this.allowoverflow = false;
    this.overflowed = false;
    this.cursize = 0;
  }

  Clear() {
    this.overflowed = false;
    this.cursize = 0;
  }

  Int8List Data() {
    return this.data.sublist(0, this.cursize);
  }

  WriteChar(int value) {
    this.data.buffer.asByteData().setInt8(this.cursize, value);
    this.cursize += 1;
  }

  WriteByte(int value) {
    this.data.buffer.asByteData().setUint8(this.cursize, value);
    this.cursize += 1;
  }

  WriteShort(int value) {
    this.data.buffer.asByteData().setInt16(this.cursize, value, Endian.little);
    this.cursize += 2;
  }

  WriteLong(int value) {
    this.data.buffer.asByteData().setUint32(this.cursize, value, Endian.little);
    this.cursize += 4;
  }

  Write(List<int> value) {
    this.data.setAll(this.cursize, value);
    this.cursize += value.length;
  }

  WriteString(String value) {
    final v = Uint8List.fromList(Utf8Encoder().convert(value).toList());
    this.data.setAll(this.cursize, v);
    this.cursize += v.length;
    this.data.buffer.asByteData().setUint8(this.cursize, 0);
    this.cursize++;
  }

  Print(String str) {
    final v = Uint8List.fromList(Utf8Encoder().convert(str).toList());
    if (this.data[this.cursize-1] == 0) {
      this.data.setAll(this.cursize-1, v);
      this.cursize += v.length;
      this.data[this.cursize] = 0;
    } else {
      this.data.setAll(this.cursize, v);
      this.cursize += v.length;
      this.data[this.cursize] = 0;
      this.cursize++;
    }
  }

  WriteCoord(double f) => WriteShort((f * 8).toInt());

  WritePos(List<double> pos) {
	  WriteShort((pos[0] * 8).toInt());
	  WriteShort((pos[1] * 8).toInt());
	  WriteShort((pos[2] * 8).toInt());
  }

  WriteAngle(double f) => WriteByte(((f * 256) ~/ 360) & 255);
  WriteAngle16(double f) => WriteShort(ANGLE2SHORT(f));

  WriteDeltaUsercmd(usercmd_t from, usercmd_t cmd) {

    /* Movement messages */
    var bits = 0;

    if (cmd.angles[0] != from.angles[0])
    {
      bits |= CM_ANGLE1;
    }

    if (cmd.angles[1] != from.angles[1])
    {
      bits |= CM_ANGLE2;
    }

    if (cmd.angles[2] != from.angles[2])
    {
      bits |= CM_ANGLE3;
    }

    if (cmd.forwardmove != from.forwardmove)
    {
      bits |= CM_FORWARD;
    }

    if (cmd.sidemove != from.sidemove)
    {
      bits |= CM_SIDE;
    }

    if (cmd.upmove != from.upmove)
    {
      bits |= CM_UP;
    }

    if (cmd.buttons != from.buttons)
    {
      bits |= CM_BUTTONS;
    }

    if (cmd.impulse != from.impulse)
    {
      bits |= CM_IMPULSE;
    }

    this.WriteByte( bits);

    if ((bits & CM_ANGLE1) != 0)
    {
      this.WriteShort( cmd.angles[0]);
    }

    if ((bits & CM_ANGLE2) != 0)
    {
      this.WriteShort( cmd.angles[1]);
    }

    if ((bits & CM_ANGLE3) != 0)
    {
      this.WriteShort( cmd.angles[2]);
    }

    if ((bits & CM_FORWARD) != 0)
    {
      this.WriteShort( cmd.forwardmove);
    }

    if ((bits & CM_SIDE) != 0)
    {
      this.WriteShort( cmd.sidemove);
    }

    if ((bits & CM_UP) != 0)
    {
      this.WriteShort( cmd.upmove);
    }

    if ((bits & CM_BUTTONS) != 0)
    {
      this.WriteByte( cmd.buttons);
    }

    if ((bits & CM_IMPULSE) != 0)
    {
      this.WriteByte( cmd.impulse);
    }

    this.WriteByte( cmd.msec);
    this.WriteByte( cmd.lightlevel);
  }

  /*
  * Writes part of a packetentities message.
  * Can delta from either a baseline or a previous packet_entity
  */
  WriteDeltaEntity(entity_state_t from, entity_state_t to, bool force, bool newentity) {

    if (to.number == 0) {
      Com_Error(ERR_FATAL, "Unset entity number");
    }

    if (to.number >= MAX_EDICTS) {
      Com_Error(ERR_FATAL, "Entity number >= MAX_EDICTS");
    }

    /* send an update */
    int bits = 0;

    if (to.number >= 256) {
      bits |= U_NUMBER16; /* number8 is implicit otherwise */
    }

    if (to.origin[0] != from.origin[0])
    {
      bits |= U_ORIGIN1;
    }

    if (to.origin[1] != from.origin[1])
    {
      bits |= U_ORIGIN2;
    }

    if (to.origin[2] != from.origin[2])
    {
      bits |= U_ORIGIN3;
    }

    if (to.angles[0] != from.angles[0])
    {
      bits |= U_ANGLE1;
    }

    if (to.angles[1] != from.angles[1])
    {
      bits |= U_ANGLE2;
    }

    if (to.angles[2] != from.angles[2])
    {
      bits |= U_ANGLE3;
    }

    if (to.skinnum != from.skinnum)
    {
      if (to.skinnum >= 0 && to.skinnum < 256) {
        bits |= U_SKIN8;
      }

      else if (to.skinnum >= 0 && to.skinnum < 0x10000)
      {
        bits |= U_SKIN16;
      }

      else
      {
        bits |= (U_SKIN8 | U_SKIN16);
      }
    }

    if (to.frame != from.frame)
    {
      if (to.frame < 256)
      {
        bits |= U_FRAME8;
      }

      else
      {
        bits |= U_FRAME16;
      }
    }

    if (to.effects != from.effects)
    {
      if (to.effects < 256)
      {
        bits |= U_EFFECTS8;
      }

      else if (to.effects < 0x8000)
      {
        bits |= U_EFFECTS16;
      }

      else
      {
        bits |= U_EFFECTS8 | U_EFFECTS16;
      }
    }

    if (to.renderfx != from.renderfx)
    {
      if (to.renderfx < 256)
      {
        bits |= U_RENDERFX8;
      }

      else if (to.renderfx < 0x8000)
      {
        bits |= U_RENDERFX16;
      }

      else
      {
        bits |= U_RENDERFX8 | U_RENDERFX16;
      }
    }

    if (to.solid != from.solid)
    {
      bits |= U_SOLID;
    }

    /* event is not delta compressed, just 0 compressed */
    if (to.event != 0)
    {
      bits |= U_EVENT;
    }

    if (to.modelindex != from.modelindex)
    {
      bits |= U_MODEL;
    }

    if (to.modelindex2 != from.modelindex2)
    {
      bits |= U_MODEL2;
    }

    if (to.modelindex3 != from.modelindex3)
    {
      bits |= U_MODEL3;
    }

    if (to.modelindex4 != from.modelindex4)
    {
      bits |= U_MODEL4;
    }

    if (to.sound != from.sound)
    {
      bits |= U_SOUND;
    }

    if (newentity || (to.renderfx & RF_BEAM) != 0)
    {
      bits |= U_OLDORIGIN;
    }

    /* write the message */
    if (bits == 0 && !force)
    {
      return; /* nothing to send! */
    }

    if ((bits & 0xff000000) != 0)
    {
      bits |= U_MOREBITS3 | U_MOREBITS2 | U_MOREBITS1;
    }

    else if ((bits & 0x00ff0000) != 0)
    {
      bits |= U_MOREBITS2 | U_MOREBITS1;
    }

    else if ((bits & 0x0000ff00) != 0)
    {
      bits |= U_MOREBITS1;
    }

    this.WriteByte(bits & 255);

    if ((bits & 0xff000000) != 0)
    {
      this.WriteByte((bits >> 8) & 255);
      this.WriteByte((bits >> 16) & 255);
      this.WriteByte((bits >> 24) & 255);
    }

    else if ((bits & 0x00ff0000) != 0)
    {
      this.WriteByte((bits >> 8) & 255);
      this.WriteByte((bits >> 16) & 255);
    }

    else if ((bits & 0x0000ff00) != 0)
    {
      this.WriteByte((bits >> 8) & 255);
    }

    if ((bits & U_NUMBER16) != 0)
    {
      this.WriteShort(to.number);
    }

    else
    {
      this.WriteByte(to.number);
    }

    if ((bits & U_MODEL) != 0)
    {
      this.WriteByte(to.modelindex);
    }

    if ((bits & U_MODEL2) != 0)
    {
      this.WriteByte(to.modelindex2);
    }

    if ((bits & U_MODEL3) != 0)
    {
      this.WriteByte(to.modelindex3);
    }

    if ((bits & U_MODEL4) != 0)
    {
      this.WriteByte(to.modelindex4);
    }

    if ((bits & U_FRAME8) != 0)
    {
      this.WriteByte(to.frame);
    }

    if ((bits & U_FRAME16) != 0)
    {
      this.WriteShort(to.frame);
    }

    if ((bits & U_SKIN8) != 0 && (bits & U_SKIN16) != 0) /*used for laser colors */
    {
      this.WriteLong(to.skinnum);
    }

    else if ((bits & U_SKIN8) != 0)
    {
      this.WriteByte(to.skinnum);
    }

    else if ((bits & U_SKIN16) != 0)
    {
      this.WriteShort(to.skinnum);
    }

    if ((bits & (U_EFFECTS8 | U_EFFECTS16)) == (U_EFFECTS8 | U_EFFECTS16))
    {
      this.WriteLong(to.effects);
    }

    else if ((bits & U_EFFECTS8) != 0)
    {
      this.WriteByte(to.effects);
    }

    else if ((bits & U_EFFECTS16) != 0)
    {
      this.WriteShort(to.effects);
    }

    if ((bits & (U_RENDERFX8 | U_RENDERFX16)) == (U_RENDERFX8 | U_RENDERFX16))
    {
      this.WriteLong(to.renderfx);
    }

    else if ((bits & U_RENDERFX8) != 0)
    {
      this.WriteByte(to.renderfx);
    }

    else if ((bits & U_RENDERFX16) != 0)
    {
      this.WriteShort(to.renderfx);
    }

    if ((bits & U_ORIGIN1) != 0)
    {
      this.WriteCoord(to.origin[0]);
    }

    if ((bits & U_ORIGIN2) != 0)
    {
      this.WriteCoord(to.origin[1]);
    }

    if ((bits & U_ORIGIN3) != 0)
    {
      this.WriteCoord(to.origin[2]);
    }

    if ((bits & U_ANGLE1) != 0)
    {
      this.WriteAngle(to.angles[0]);
    }

    if ((bits & U_ANGLE2) != 0)
    {
      this.WriteAngle(to.angles[1]);
    }

    if ((bits & U_ANGLE3) != 0)
    {
      this.WriteAngle(to.angles[2]);
    }

    if ((bits & U_OLDORIGIN) != 0)
    {
      this.WriteCoord(to.old_origin[0]);
      this.WriteCoord(to.old_origin[1]);
      this.WriteCoord(to.old_origin[2]);
    }

    if ((bits & U_SOUND) != 0)
    {
      this.WriteByte(to.sound);
    }

    if ((bits & U_EVENT) != 0)
    {
      this.WriteByte(to.event);
    }

    if ((bits & U_SOLID) != 0)
    {
      this.WriteShort(to.solid);
    }
  }

}
