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
 * Local defines for the sound system.
 *
 * =======================================================================
 */
import 'dart:web_audio';
const MAX_CHANNELS = 32;
const MAX_RAW_SAMPLES = 8192;

/*
 * Holds a cached SFX and
 * it's meta data
 */
class sfxcache_t {
	int length;
	int loopstart;
	int speed;
	int width;
// #if USE_OPENAL
// 	int size;
// 	int bufnum;
// #endif
	bool stereo;
  AudioBuffer buffer;
	// byte data[1];
}

/*
 * Holds a SFX
 */
class sfx_t {
	String name;
	int registration_sequence = 0;
	sfxcache_t cache;
	String truename = null;

  sfx_t(this.name);
}

/*
 * Interface to pass data and metadata
 * between the frontend and the backends.
 * Mainly used by the SDL backend, since
 * the OpenAL backend has it's own AL
 * based magic.
 */
class sound_t {
	int channels = 0;
	int samples = 0;          /* mono samples in buffer */
	int submission_chunk = 0; /* don't mix less than this */
	int samplepos = 0;        /* in mono samples */
	int samplebits = 0;
	int speed = 0;
	// unsigned char *buffer;
}

/*
 * Information read from
 * wave file header.
 */
class wavinfo_t {
	int rate = 0;
	int width = 0;
	int channels = 0;
	int loopstart = 0;
	int samples = 0;
	int dataofs = 0; /* chunk starts this many bytes from file start */
}