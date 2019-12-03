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
 * The upper layer of the Quake II sound system. This is merely more
 * than an interface between the client and a backend. Currently only
 * two backends are supported:
 * - OpenAL, renders sound with OpenAL.
 * - SDL, has the same features than the original sound system.
 *
 * =======================================================================
 */
import 'dart:typed_data';
import 'dart:web_audio';
import 'package:dQuakeWeb/client/sound/wave.dart';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/filesystem.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'local.dart';

/* During registration it is possible to have more sounds
   than could actually be referenced during gameplay,
   because we don't want to free anything until we are
   sure we won't need it. */
const _MAX_SFX = (MAX_SOUNDS * 2);
const _MAX_PLAYSOUNDS = 128;

cvar_t s_volume;
cvar_t s_testsound;
cvar_t s_loadas8bit;
cvar_t s_khz;
cvar_t s_mixahead;
cvar_t s_show;
cvar_t s_ambient;
cvar_t s_underwater;
cvar_t s_underwater_gain_hf;
cvar_t s_doppler;

final sound = sound_t();

List<sfx_t> known_sfx = [];

int s_registration_sequence = 0;
bool _s_registering = false;

AudioContext _context;

/* ----------------------------------------------------------------- */

/*
 * Loads one sample into memory
 */
Future<sfxcache_t> S_LoadSound(sfx_t s) async {
	// char namebuffer[MAX_QPATH];
	// byte *data;
	// wavinfo_t info;
	// sfxcache_t *sc;
	// int size;
	// char *name;

	if (s.name[0] == '*') {
		return null;
	}

	/* see if still in memory */
	var sc = s.cache;
	if (sc != null) {
		return sc;
	}

	/* load it */
  String name;
	if (s.truename != null) {
		name = s.truename;
	} else {
		name = s.name;
	}

  String namebuffer;
	if (name[0] == '#') {
		namebuffer = name.substring(1);
	} else {
		namebuffer = "sound/" + name;
	}

	final data = await FS_LoadFile(namebuffer);
	if (data == null) {
		s.cache = null;
		Com_DPrintf("Couldn't load $namebuffer\n");
    return null;
	}

	final info = GetWavinfo(s.name, data);
	if (info.channels != 1) {
		Com_Printf("${s.name} is a stereo sample\n");
    return null;
	}

  final src = data.asByteData(info.dataofs);
  AudioBuffer audioBuffer = _context.createBuffer(info.channels, info.samples, info.rate);
  Float32List buf = audioBuffer.getChannelData(0);
  for (int i = 0; i < info.samples; i++) {

    if (info.width == 2) {
      final sample = src.getInt16(i * 2, Endian.little);
      buf[i] = sample / 0x7FFF;
    } else {
      print("----- Width ${info.width} ------");
    }
  }

  sc = new sfxcache_t();
  s.cache = sc;
  sc.buffer = audioBuffer;
  sc.length = info.samples;
  sc.loopstart = info.loopstart;
  sc.speed = info.rate;
  sc.stereo = false;
  sc.width = info.width;

// #if USE_OPENAL
// 	if (sound_started == SS_OAL)
// 	{
// 		sc = AL_UploadSfx(s, &info, data + info.dataofs);
// 	}
// 	else
// #endif
// 	{
// 		if (sound_started == SS_SDL)
// 		{
// 			if (!SDL_Cache(s, &info, data + info.dataofs))
// 			{
// 				Com_Printf("Pansen!\n");
// 				FS_FreeFile(data);
// 				return NULL;
// 			}
// 		}
// 	}

// 	FS_FreeFile(data);
	return sc;
}


/*
 * Returns the name of a sound
 */
sfx_t S_FindName(String name, bool create) {

	if (name == null) {
		Com_Error(ERR_FATAL, "S_FindName: NULL\n");
	}

	if (name.isEmpty) {
		Com_Error(ERR_FATAL, "S_FindName: empty name\n");
	}

	// if (strlen(name) >= MAX_QPATH)
	// {
	// 	Com_Error(ERR_FATAL, "Sound name too long: %s", name);
	// }

	/* see if already loaded */
	for (var sfx in known_sfx) {
		if (sfx != null && sfx.name == name) {
			return sfx;
		}
	}

	if (!create) {
		return null;
	}

	/* find a free sfx */
  int index = -1;
	for (int i  = 0; i < known_sfx.length; i++) {
		if (known_sfx[i] == null) {
      index = i;
			break;
		}
	}

	if (index < 0) {
		if (known_sfx.length == _MAX_SFX) {
			Com_Error(ERR_FATAL, "S_FindName: out of sfx_t");
		}
	}

	final sfx = sfx_t(name);
	sfx.registration_sequence = s_registration_sequence;

  if (index >= 0) {
    known_sfx[index] = sfx;
  } else {
    known_sfx.add(sfx);
  }

	return sfx;
}

/*
 * Called before registering
 * of sound starts
 */
S_BeginRegistration() {
	s_registration_sequence++;
	_s_registering = true;
}

/*
 * Registers a sound
 */
Future<sfx_t> S_RegisterSound(String name) async {
	// sfx_t *sfx;

	// if (sound_started == SS_NOT)
	// {
	// 	return NULL;
	// }

	final sfx = S_FindName(name, true);
	sfx.registration_sequence = s_registration_sequence;

	if (!_s_registering) {
		await S_LoadSound(sfx);
	}
	return sfx;
}

/*
 * Called after registering of
 * sound has ended
 */
S_EndRegistration() async {
	// int i;
	// sfx_t *sfx;

	/* free any sounds not from this registration sequence */
	for (var i = 0; i < known_sfx.length; i++) {
		if (known_sfx[i] == null) {
			continue;
		}

		if (known_sfx[i].registration_sequence != s_registration_sequence) {
			/* it is possible to have a leftover */
			// if (sfx->cache)
			// {
			// 	Z_Free(sfx->cache); /* from a server that didn't finish loading */
			// }

			// if (sfx->truename)
			// {
			// 	Z_Free(sfx->truename);
			// }

			// sfx->cache = NULL;
      known_sfx[i].cache = null;
      known_sfx[i] = null;
		}
	}

	/* load everything in */
	for (var sfx in known_sfx) {
		if (sfx == null) {
			continue;
		}

		await S_LoadSound(sfx);
	}

	_s_registering = false;
}

/*
 * Initializes the sound system
 * and it's requested backend
 */

S_Init() {

	Com_Printf("\n------- sound initialization -------\n");

  _context = AudioContext();

	final cv = Cvar_Get("s_initsound", "1", 0);
	if (!cv.boolean) {
		Com_Printf("Not initializing.\n");
		Com_Printf("------------------------------------\n\n");
		return;
	}

	s_volume = Cvar_Get("s_volume", "0.7", CVAR_ARCHIVE);
	s_khz = Cvar_Get("s_khz", "44", CVAR_ARCHIVE);
	s_loadas8bit = Cvar_Get("s_loadas8bit", "0", CVAR_ARCHIVE);
	s_mixahead = Cvar_Get("s_mixahead", "0.14", CVAR_ARCHIVE);
	s_show = Cvar_Get("s_show", "0", 0);
	s_testsound = Cvar_Get("s_testsound", "0", 0);
	s_ambient = Cvar_Get("s_ambient", "1", 0);
  s_underwater = Cvar_Get("s_underwater", "1", CVAR_ARCHIVE);
  s_underwater_gain_hf = Cvar_Get("s_underwater_gain_hf", "0.25", CVAR_ARCHIVE);
	s_doppler = Cvar_Get("s_doppler", "1", CVAR_ARCHIVE);

// 	Cmd_AddCommand("play", S_Play);
// 	Cmd_AddCommand("stopsound", S_StopAllSounds);
// 	Cmd_AddCommand("soundlist", S_SoundList);
// 	Cmd_AddCommand("soundinfo", S_SoundInfo_f);

// #if USE_OPENAL
// 	cv = Cvar_Get("s_openal", "1", CVAR_ARCHIVE);

// 	if (cv->value && AL_Init())
// 	{
// 		sound_started = SS_OAL;
// 	}
// 	else
// #endif
// 	{
// 		if (SDL_BackendInit())
// 		{
// 			sound_started = SS_SDL;
// 		}
// 		else
// 		{
// 			sound_started = SS_NOT;
// 			return;
// 		}
// 	}

sound.speed = _context.sampleRate;
sound.channels = _context.destination.channelCount;

// 	num_sfx = 0;
// 	paintedtime = 0;

// 	OGG_Init();

	Com_Printf("Sound sampling rate: ${sound.speed}\n");
  print("state ${_context.state}");
  print("maxChannels ${_context.destination.maxChannelCount}");
  print("channels ${_context.destination.channelCount}");
  print("outputs ${_context.destination.numberOfOutputs}");
// 	S_StopAllSounds();

	Com_Printf("------------------------------------\n\n");
}


/*
 * Validates the parms and queues the sound up.
 * If pos is NULL, the sound will be dynamically
 * sourced from the entity. Entchannel 0 will never
 * override a playing sound.
 */
S_StartSound(List<double> origin, int entnum, int entchannel, sfx_t sfx,
		double fvol, double attenuation, double timeofs) async {
// 	sfxcache_t *sc;
// 	playsound_t *ps, *sort;

// 	if (sound_started == SS_NOT)
// 	{
// 		return;
// 	}

	if (sfx == null) {
		return;
	}

	if (sfx.name[0] == '*') {
// 		sfx = S_RegisterSexedSound(&cl_entities[entnum].current, sfx->name);

// 		if (!sfx)
// 		{
// 			return;
// 		}
	}

	/* make sure the sound is loaded */
	final sc = await S_LoadSound(sfx);

	if (sc == null) {
		/* couldn't load the sound's data */
		return;
	}

  if (_context.state != "running") {
    _context.resume();
  }

  AudioBufferSourceNode source = _context.createBufferSource();
  source.buffer = sc.buffer;
  source.connectNode(_context.destination);
  source.start(_context.currentTime);
	/* make the playsound_t */
// 	ps = S_AllocPlaysound();

// 	if (!ps)
// 	{
// 		return;
// 	}

// 	if (origin)
// 	{
// 		VectorCopy(origin, ps->origin);
// 		ps->fixed_origin = true;
// 	}
// 	else
// 	{
// 		ps->fixed_origin = false;
// 	}

// 	if (sfx->name[0])
// 	{
// 		vec3_t orientation, direction;
// 		vec_t distance_direction;
// 		int dir_x, dir_y, dir_z;

// 		VectorSubtract(listener_forward, listener_up, orientation);

// 		// with !fixed we have all sounds related directly to player,
// 		// e.g. players fire, pain, menu
// 		if (!ps->fixed_origin)
// 		{
// 			VectorCopy(orientation, direction);
// 			distance_direction = 0;
// 		}
// 		else
// 		{
// 			VectorSubtract(listener_origin, ps->origin, direction);
// 			distance_direction = VectorLength(direction);
// 		}

// 		VectorNormalize(direction);
// 		VectorNormalize(orientation);

// 		dir_x = 16 * orientation[0] * direction[0];
// 		dir_y = 16 * orientation[1] * direction[1];
// 		dir_z = 16 * orientation[2] * direction[2];

// 		Haptic_Feedback(sfx->name, 16 - distance_direction / 32, dir_x, dir_y, dir_z);
// 	}

// 	ps->entnum = entnum;
// 	ps->entchannel = entchannel;
// 	ps->attenuation = attenuation;
// 	ps->sfx = sfx;

// #if USE_OPENAL
// 	if (sound_started == SS_OAL)
// 	{
// 		ps->begin = paintedtime + timeofs * 1000;
// 		ps->volume = fvol;
// 	}
// 	else
// #endif
// 	{
// 		if (sound_started == SS_SDL)
// 		{
// 			ps->begin = SDL_DriftBeginofs(timeofs);
// 			ps->volume = fvol * 255;
// 		}
// 	}

// 	/* sort into the pending sound list */
// 	for (sort = s_pendingplays.next;
// 		 sort != &s_pendingplays && sort->begin <= ps->begin;
// 		 sort = sort->next)
// 	{
// 	}

// 	ps->next = sort;
// 	ps->prev = sort->prev;

// 	ps->next->prev = ps;
// 	ps->prev->next = ps;
}