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
 * This file implements a subset of the WAVE audio file format.
 *
 * =======================================================================
 */
import 'dart:typed_data';

import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/shared/shared.dart';

import 'local.dart';

int _data_i;
int _iff_end;
int _last_chunk;
int _iff_data_i;
ByteData _iff_data;
int iff_chunk_len;

FindNextChunk(String name) {
	while (true) {
		_data_i = _last_chunk;

		if (_data_i >= _iff_end) {
			_data_i = -1;
			return;
		}

		iff_chunk_len = _iff_data.getInt32(_data_i + 4, Endian.little);
		if (iff_chunk_len < 0) {
			_data_i = -1;
			return;
		}

		_last_chunk = _data_i + 8 + iff_chunk_len;
    final str = String.fromCharCodes(_iff_data.buffer.asInt8List(_data_i, 4));
		if (name == str) {
			return;
		}
	}
}

FindChunk(String name) {
	_last_chunk = _iff_data_i;
	FindNextChunk(name);
}


wavinfo_t GetWavinfo(String name, ByteBuffer wav) {
	// wavinfo_t info;
	// int format;
	// int samples;

	final info = wavinfo_t();
	if (wav == null) {
		return info;
	}

	_iff_data = wav.asByteData();
  _iff_data_i = 0;
  _iff_end = wav.lengthInBytes;

	/* find "RIFF" chunk */
	FindChunk("RIFF");

	if (!(_data_i >= 0 && String.fromCharCodes(_iff_data.buffer.asInt8List(_data_i + 8, 4)) == "WAVE")) {
    Com_Printf("Missing RIFF/WAVE chunks\n");
    return info;
  }

	/* get "fmt " chunk */
	_iff_data_i = _data_i + 12;

	FindChunk("fmt ");
	if (_data_i < 0) {
		Com_Printf("Missing fmt chunk\n");
		return info;
	}

	_data_i += 8;
	final format = _iff_data.getInt16(_data_i, Endian.little);
  _data_i += 2;

	if (format != 1) {
		Com_Printf("Microsoft PCM format only\n");
		return info;
	}

	info.channels = _iff_data.getInt16(_data_i, Endian.little);
  _data_i += 2;
	info.rate = _iff_data.getInt32(_data_i, Endian.little);
  _data_i += 4 + 2 + 4;
	info.width = _iff_data.getInt16(_data_i, Endian.little) ~/ 8;
  _data_i += 2;

	/* get cue chunk */
	FindChunk("cue ");

	if (_data_i >= 0) {
		_data_i += 32;
		info.loopstart = _iff_data.getInt32(_data_i, Endian.little);
    _data_i += 4;

		/* if the next chunk is a LIST chunk,
		   look for a cue length marker */
		FindNextChunk("LIST");

		if (_data_i >= 0) {
	// 		if (((data_p - wav) + 32 <= wavlength) &&
	// 			!strncmp((const char *)data_p + 28, "mark", 4))
	// 		{
	// 			int i;

	// 			/* this is not a proper parse,
	// 			   but it works with cooledit... */
	// 			data_p += 24;
	// 			i = GetLittleLong(); /* samples in loop */
	// 			info.samples = info.loopstart + i;
	// 		}
		}
	} else {
		info.loopstart = -1;
	}

	/* find data chunk */
	FindChunk("data");

	if (_data_i < 0) {
		Com_Printf("Missing data chunk\n");
		return info;
	}

	_data_i += 4;
	final samples = _iff_data.getInt32(_data_i, Endian.little) ~/ info.width;
  _data_i += 4;

	if (info.samples != 0) {
		if (samples < info.samples) {
			Com_Error(ERR_DROP, "Sound $name has a bad loop length");
		}
	} else {
		info.samples = samples;
	}

  info.dataofs = _data_i;

	return info;
}

