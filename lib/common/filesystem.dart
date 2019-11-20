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
import 'dart:html';

Future<ByteBuffer> FS_LoadFile(String name) async {
  try {
    final request = await HttpRequest.request("baseq2/" + name.toLowerCase(), responseType: "arraybuffer");
    return request.response;
  } catch(e) {
    return null;
  }
}


Future<bool> FS_CheckFile(String name) async {
  try {
    final request = await HttpRequest.request("baseq2/" + name.toLowerCase(), method: "HEAD");
    return true;
  } catch(e) {
    return false;
  }
}