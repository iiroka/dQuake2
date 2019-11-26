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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 * USA.
 *
 * =======================================================================
 *
 * ABI between client and refresher
 *
 * =======================================================================
 */
import 'dart:typed_data';

const	MAX_DLIGHTS		= 32;
const	MAX_ENTITIES	= 128;
const	MAX_PARTICLES	= 4096;
// const	MAX_LIGHTSTYLES	= 256;

const POWERSUIT_SCALE		= 4.0;

class model_s {
  String name;

  model_s(this.name);
}

class dlight_t {
	List<double>	origin = [0,0,0];
	List<double>	color = [0,0,0];
	double	intensity = 0;
}

class particle_t {
	List<double>	origin = [0,0,0];
	int		color = 0;
	double	alpha = 0;
}

class lightstyle_t {
	List<double>	rgb = [0,0,0]; /* 0.0 - 2.0 */
	double		    white = 0; /* r+g+b */
}

class entity_t {
	model_s model; /* opaque type outside refresh */
	List<double>			angles = [0,0,0];

	/* most recent data */
	List<double>	origin = [0,0,0]; /* also used as RF_BEAM's "from" */
	int					frame = 0; /* also used as RF_BEAM's diameter */

	/* previous data for lerping */
	List<double>	oldorigin = [0,0,0]; /* also used as RF_BEAM's "to" */
	int					oldframe = 0;

	/* misc */
	double	backlerp = 0; /* 0.0 = current, 1.0 = old */
	int		skinnum = 0; /* also used as RF_BEAM's palette index */

	int		lightstyle = 0; /* for flashing entities */
	double	alpha = 0; /* ignore if RF_TRANSLUCENT isn't set */

	Object skin; /* NULL for inline skin */
	int		flags = 0;

  entity_t clone() {
    final e = entity_t();
    e.model = this.model;
    e.angles.setAll(0, this.angles);
    e.origin.setAll(0, this.origin);
    e.frame = this.frame;
    e.oldorigin.setAll(0, this.oldorigin);
    e.oldframe = this.oldframe;
    e.backlerp = this.backlerp;
    e.skinnum = this.skinnum;
    e.lightstyle = this.lightstyle;
    e.alpha = this.alpha;
    e.skin = this.skin;
    e.flags = this.flags;
    return e;
  }

  clear() {
    this.model = null;
    this.angles.fillRange(0, 3, 0);
    this.origin.fillRange(0, 3, 0);
    this.frame = 0;
    this.oldorigin.fillRange(0, 3, 0);
    this.oldframe = 0;
    this.backlerp = 0;
    this.skinnum = 0;
    this.lightstyle = 0;
    this.alpha = 0;
    this.skin = null;
    this.flags = 0;
  }
}

class refdef_t {
	int			x = 0, y = 0, width = 0, height = 0; /* in virtual screen coordinates */
	double		fov_x = 0, fov_y = 0;
	List<double>		vieworg = [0,0,0];
	List<double>		viewangles = [0,0,0];
	List<double>		blend = [0,0,0, 0]; /* rgba 0-1 full screen blend */
	double		time = 0; /* time is used to auto animate */
	int			rdflags = 0; /* RDF_UNDERWATER, etc */

	Uint8List areabits; /* if not NULL, only areas with set bits will be drawn */

  List<lightstyle_t> lightstyles;

	// int			num_entities;
	List<entity_t>	entities;

	// int			num_dlights; // <= 32 (MAX_DLIGHTS)
	List<dlight_t>	dlights;

	// int			num_particles;
	List<particle_t> particles;
}

//
// these are the functions exported by the refresh module
//
abstract class refexport_t {
	// if api_version is different, the dll cannot be used
	// int		api_version;

	// called when the library is loaded
	Future<bool> Init();

	// called before the library is unloaded
	void	Shutdown ();

	// // called by GLimp_InitGraphics() before creating window,
	// // returns flags for SDL window creation, returns -1 on error
	// int		(EXPORT *PrepareForWindow)(void);

	// // called by GLimp_InitGraphics() *after* creating window,
	// // passing the SDL_Window* (void* so we don't spill SDL.h here)
	// // (or SDL_Surface* for SDL1.2, another reason to use void*)
	// // returns true (1) on success
	// int		(EXPORT *InitContext)(void* sdl_window);

	// // shuts down rendering (OpenGL) context.
	// void	(EXPORT *ShutdownContext)(void);

	// // returns true if vsync is active, else false
	// qboolean (EXPORT *IsVSyncActive)(void);

	// All data that will be used in a level should be
	// registered before rendering any frames to prevent disk hits,
	// but they can still be registered at a later time
	// if necessary.
	//
	// EndRegistration will free any remaining data that wasn't registered.
	// Any model_s or skin_s pointers from before the BeginRegistration
	// are no longer valid after EndRegistration.
	//
	// Skins and images need to be differentiated, because skins
	// are flood filled to eliminate mip map edge errors, and pics have
	// an implicit "pics/" prepended to the name. (a pic name that starts with a
	// slash will not use the "pics/" prefix or the ".pcx" postfix)
	Future<void>	BeginRegistration (String map);
	Future<model_s> RegisterModel (String name);
	Future<Object> RegisterSkin (String name);

	Future<void> SetSky (String name, double rotate, List<double> axis);
	void	EndRegistration ();

	Future<void> RenderFrame (refdef_t fd);

	Future<Object> DrawFindPic(String name);

	Future<List<int>> DrawGetPicSize (String name);	// will return 0 0 if not found
	Future<void> DrawPicScaled (int x, int y, String pic, double factor);
	Future<void> DrawStretchPic (int x, int y, int w, int h, String name);
	void DrawCharScaled(int x, int y, int num, double scale);
	Future<void> DrawTileClear (int x, int y, int w, int h, String name);
	void DrawFill (int x, int y, int w, int h, int c);
	// void	(EXPORT *DrawFadeScreen) (void);

	// // Draw images for cinematic rendering (which can have a different palette). Note that calls
	// void	(EXPORT *DrawStretchRaw) (int x, int y, int w, int h, int cols, int rows, byte *data);

	/*
	** video mode and refresh state management entry points
	*/
	// void	(EXPORT *SetPalette)( const unsigned char *palette);	// NULL = game palette
	void BeginFrame();
	Future<void> EndFrame();

	//void	(EXPORT *AppActivate)( qboolean activate );
}