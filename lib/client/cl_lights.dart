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
 *
 * =======================================================================
 *
 * This file implements all client side lighting
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/shared/shared.dart';
import 'vid/ref.dart';
import 'client.dart';
import 'cl_view.dart' show V_AddLightStyle, V_AddLight;

class clightstyle_t {
	int length = 0;
	List<double> value = [0,0,0];
	List<double> map = List(64);
}

List<clightstyle_t> cl_lightstyle = List(MAX_LIGHTSTYLES);
int lastofs = 0;

CL_ClearLightStyles() {
  for (int i = 0; i < cl_lightstyle.length; i++) {
    cl_lightstyle[i] = clightstyle_t();
    cl_lightstyle[i].map.fillRange(0, 64);
  }
	lastofs = -1;
}

CL_RunLightStyles() {

	int ofs = cl.time ~/ 100;

	if (ofs == lastofs) {
		return;
	}

	lastofs = ofs;

	for (clightstyle_t ls in cl_lightstyle) {
    if (ls == null) continue;
    double value = 1.0;
		if (ls.length == 0)
		{
			value = 1.0;
		} else if (ls.length == 1) {
			value = ls.map[0];
		} else {
			value = ls.map[ofs % ls.length];
		}
    ls.value[0] = value;
    ls.value[1] = value;
    ls.value[2] = value;
	}
}

CL_SetLightstyle(int i) {

	final s = cl.configstrings[i + CS_LIGHTS];

	final j = s.length;
	cl_lightstyle[i].length = j;

  final a = 'a'.codeUnitAt(0);
  final m = 'm'.codeUnitAt(0);
	for (int k = 0; k < j; k++) {
		cl_lightstyle[i].map[k] = (s.codeUnitAt(k) - a) / (m - a);
	}
}

CL_AddLightStyles() {
	for (int i = 0; i < MAX_LIGHTSTYLES; i++) {
		V_AddLightStyle(i, cl_lightstyle[i].value[0], cl_lightstyle[i].value[1], cl_lightstyle[i].value[2]);
	}
}

class cdlight_t {
	int		key = 0; /* so entities can reuse same entry */
	List<double>	color = [0,0,0];
	List<double>	origin = [0,0,0];
	double	radius = 0;
	double	die = 0; /* stop lighting after this time */
	double	decay = 0; /* drop this each second */
	double	minlight = 0; /* don't add when contributing less */

  clear() {
    this.key = 0;
    this.color.fillRange(0, 3, 0);
    this.origin.fillRange(0, 3, 0);
    this.radius = 0;
    this.die = 0;
    this.decay = 0;
    this.minlight = 0;
  }
}


List<cdlight_t> cl_dlights = List.generate(MAX_DLIGHTS, (i) => cdlight_t());

CL_ClearDlights() {
	for (var dl in cl_dlights) {
    dl.clear();
  }
}

cdlight_t CL_AllocDlight(int key) {

	/* first look for an exact key match */
	if (key != 0) {
  	for (var dl in cl_dlights) {
			if (dl.key == key) {
				return dl;
			}
		}
	}

	/* then look for anything else */
  for (var dl in cl_dlights) {
		if (dl.die < cl.time) {
			dl.key = key;
			return dl;
		}
	}

	var dl = cl_dlights[0];
	dl.key = key;
	return dl;
}

CL_RunDLights() {

  for (var dl in cl_dlights) {
		if (dl.radius == 0) {
			continue;
		}

		if (dl.die < cl.time) {
			dl.radius = 0;
			continue;
		}

		dl.radius -= cls.rframetime * dl.decay;

		if (dl.radius < 0) {
			dl.radius = 0;
		}
	}
}

CL_AddDLights() {

  for (var dl in cl_dlights) {
		if (dl.radius == 0) {
			continue;
		}

		V_AddLight(dl.origin, dl.radius, dl.color[0], dl.color[1], dl.color[2]);
	}
}