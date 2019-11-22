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
 * Player movement code. This is the core of Quake IIs legendary physics
 * engine
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/client/client.dart';
import 'package:dQuakeWeb/shared/shared.dart';

const _STEPSIZE = 18;

/* all of the locals will be zeroed before each
 * pmove, just to make damn sure we don't have
 * any differences when running on client or server */

class _pml_t {
	List<double> origin = [0,0,0]; /* full float precision */
	List<double> velocity = [0,0,0]; /* full float precision */

	List<double> forward = [0,0,0], right = [0,0,0], up = [0,0,0];
	double frametime = 0;

	csurface_t groundsurface;
	cplane_t groundplane = cplane_t();
	int groundcontents = 0;

	List<double> previous_origin = [0,0,0];
	bool ladder = false;
}

pmove_t _pm;
_pml_t _pml = _pml_t();


/* movement parameters */
double pm_stopspeed = 100;
double pm_maxspeed = 300;
double pm_duckspeed = 100;
double pm_accelerate = 10;
double pm_airaccelerate = 0;
double pm_wateraccelerate = 10;
double pm_friction = 6;
double pm_waterfriction = 1;
double pm_waterspeed = 400;

_PM_CatagorizePosition() {

	/* if the player hull point one unit down
	   is solid, the player is on ground */

	/* see if standing on something solid */
	List<double> point = [_pml.origin[0], _pml.origin[1], _pml.origin[2] - 0.25];

	if (_pml.velocity[2] > 180) {
		_pm.s.pm_flags &= ~PMF_ON_GROUND;
		_pm.groundentity = null;
	} else {
		final trace = _pm.trace(_pml.origin, _pm.mins, _pm.maxs, point);
		_pml.groundplane = trace.plane;
		_pml.groundsurface = trace.surface;
		_pml.groundcontents = trace.contents;

		if (trace.ent == null || ((trace.plane.normal[2] < 0.7) && !trace.startsolid)) {
			_pm.groundentity = null;
			_pm.s.pm_flags &= ~PMF_ON_GROUND;
		} else {
			_pm.groundentity = trace.ent;

			/* hitting solid ground will end a waterjump */
			if ((_pm.s.pm_flags & PMF_TIME_WATERJUMP) != 0) {
				_pm.s.pm_flags &=
					~(PMF_TIME_WATERJUMP | PMF_TIME_LAND | PMF_TIME_TELEPORT);
				_pm.s.pm_time = 0;
			}

			if ((_pm.s.pm_flags & PMF_ON_GROUND) == 0) {
				/* just hit the ground */
				_pm.s.pm_flags |= PMF_ON_GROUND;

				/* don't do landing time if we were just going down a slope */
				if (_pml.velocity[2] < -200) {
					_pm.s.pm_flags |= PMF_TIME_LAND;

					/* don't allow another jump for a little while */
					if (_pml.velocity[2] < -400) {
						_pm.s.pm_time = 25;
					} else {
						_pm.s.pm_time = 18;
					}
				}
			}
		}

		if ((_pm.numtouch < MAXTOUCH) && trace.ent != null) {
			_pm.touchents[_pm.numtouch] = trace.ent;
			_pm.numtouch++;
		}
	}

	/* get waterlevel, accounting for ducking */
	_pm.waterlevel = 0;
	_pm.watertype = 0;

	double sample2 = _pm.viewheight - _pm.mins[2];
	double sample1 = sample2 / 2;

	point[2] = _pml.origin[2] + _pm.mins[2] + 1;
	int cont = _pm.pointcontents(point);

	if ((cont & MASK_WATER) != 0) {
		_pm.watertype = cont;
		_pm.waterlevel = 1;
		point[2] = _pml.origin[2] + _pm.mins[2] + sample1;
		cont = _pm.pointcontents(point);

		if ((cont & MASK_WATER) != 0) {
			_pm.waterlevel = 2;
			point[2] = _pml.origin[2] + _pm.mins[2] + sample2;
			cont = _pm.pointcontents(point);

			if ((cont & MASK_WATER) != 0) {
				_pm.waterlevel = 3;
			}
		}
	}
}

/*
 * Sets mins, maxs, and pm->viewheight
 */
_PM_CheckDuck() {
	trace_t trace;

	_pm.mins[0] = -16;
	_pm.mins[1] = -16;

	_pm.maxs[0] = 16;
	_pm.maxs[1] = 16;

	if (_pm.s.pm_type == pmtype_t.PM_GIB) {
		_pm.mins[2] = 0;
		_pm.maxs[2] = 16;
		_pm.viewheight = 8;
		return;
	}

	_pm.mins[2] = -24;

	if (_pm.s.pm_type == pmtype_t.PM_DEAD)
	{
		_pm.s.pm_flags |= PMF_DUCKED;
	}
	else if ((_pm.cmd.upmove < 0) && (_pm.s.pm_flags & PMF_ON_GROUND) != 0)
	{
		/* duck */
		_pm.s.pm_flags |= PMF_DUCKED;
	}
	else
	{
		/* stand up if possible */
		if ((_pm.s.pm_flags & PMF_DUCKED) != 0)
		{
			/* try to stand up */
			_pm.maxs[2] = 32;
			trace = _pm.trace(_pml.origin, _pm.mins, _pm.maxs, _pml.origin);

			if (!trace.allsolid)
			{
				_pm.s.pm_flags &= ~PMF_DUCKED;
			}
		}
	}

	if ((_pm.s.pm_flags & PMF_DUCKED) != 0) {
		_pm.maxs[2] = 4;
		_pm.viewheight = -2;
	} else {
		_pm.maxs[2] = 32;
		_pm.viewheight = 22;
	}
}

_PM_DeadMove() {

	if (_pm.groundentity == null) {
		return;
	}

	/* extra friction */
	double forward = VectorLength(_pml.velocity);
	forward -= 20;

	if (forward <= 0) {
		_pml.velocity = [0,0,0];
	} else {
		VectorNormalize(_pml.velocity);
		VectorScale(_pml.velocity, forward, _pml.velocity);
	}
}

bool _PM_GoodPosition() {

	if (_pm.s.pm_type == pmtype_t.PM_SPECTATOR) {
		return true;
	}

  List<double> origin = List.generate(3, (i) => _pm.s.origin[i] * 0.125);
  List<double> end = List.generate(3, (i) => _pm.s.origin[i] * 0.125);

	final trace = _pm.trace(origin, _pm.mins, _pm.maxs, end);
	return !trace.allsolid;
}

_PM_InitialSnapPosition() {
	List<int> offset = [0, -1, 1];
  List<int> base = List.generate(3, (i) => _pm.s.origin[i]);

	for (int z = 0; z < 3; z++) {
		_pm.s.origin[2] = base[2] + offset[z];

		for (int y = 0; y < 3; y++) {
			_pm.s.origin[1] = base[1] + offset[y];

			for (int x = 0; x < 3; x++) {
				_pm.s.origin[0] = base[0] + offset[x];

				if (_PM_GoodPosition()) {
					_pml.origin[0] = _pm.s.origin[0] * 0.125;
					_pml.origin[1] = _pm.s.origin[1] * 0.125;
					_pml.origin[2] = _pm.s.origin[2] * 0.125;
          _pml.previous_origin[0] = _pm.s.origin[0].toDouble();
          _pml.previous_origin[1] = _pm.s.origin[1].toDouble();
          _pml.previous_origin[2] = _pm.s.origin[2].toDouble();
					return;
				}
			}
		}
	}

	Com_DPrintf("Bad InitialSnapPosition\n");
}

_PM_ClampAngles() {

	if ((_pm.s.pm_flags & PMF_TIME_TELEPORT) != 0) {
		_pm.viewangles[YAW] = SHORT2ANGLE(
				_pm.cmd.angles[YAW] + _pm.s.delta_angles[YAW]);
		_pm.viewangles[PITCH] = 0;
		_pm.viewangles[ROLL] = 0;
	} else {
		/* circularly clamp the angles with deltas */
		for (int i = 0; i < 3; i++) {
			int temp = _pm.cmd.angles[i] + _pm.s.delta_angles[i];
			_pm.viewangles[i] = SHORT2ANGLE(temp);
		}

		/* don't let the player look up or down more than 90 degrees */
		if ((_pm.viewangles[PITCH] > 89) && (_pm.viewangles[PITCH] < 180)) {
			_pm.viewangles[PITCH] = 89;
		} else if ((_pm.viewangles[PITCH] < 271) && (_pm.viewangles[PITCH] >= 180)) {
			_pm.viewangles[PITCH] = 271;
		}
	}

	AngleVectors(_pm.viewangles, _pml.forward, _pml.right, _pml.up);
}

_PM_CalculateViewHeightForDemo() {
	if (_pm.s.pm_type == pmtype_t.PM_GIB)
		_pm.viewheight = 8;
	else {
		if ((_pm.s.pm_flags & PMF_DUCKED) != 0)
			_pm.viewheight = -2;
		else
			_pm.viewheight = 22;
	}
}

_PM_CalculateWaterLevelForDemo() {

	List<double> point = [_pml.origin[0], _pml.origin[1], _pml.origin[2] +  _pm.viewheight];

	_pm.waterlevel = 0;
	_pm.watertype = 0;

	int cont = _pm.pointcontents(point);

	if ((cont & MASK_WATER) != 0) {
		_pm.waterlevel = 3;
		_pm.watertype = cont;
	}
}

/*
 * Can be called by either the server or the client
 */
Pmove(pmove_t pmove) {
	_pm = pmove;

	/* clear results */
	_pm.numtouch = 0;
	_pm.viewangles = [0,0,0];
	_pm.viewheight = 0;
	_pm.groundentity = null;
	_pm.watertype = 0;
	_pm.waterlevel = 0;

	/* clear all pmove local vars */
	_pml = _pml_t();

	/* convert origin and velocity to float values */
	_pml.origin[0] = _pm.s.origin[0] * 0.125;
	_pml.origin[1] = _pm.s.origin[1] * 0.125;
	_pml.origin[2] = _pm.s.origin[2] * 0.125;

	_pml.velocity[0] = _pm.s.velocity[0] * 0.125;
	_pml.velocity[1] = _pm.s.velocity[1] * 0.125;
	_pml.velocity[2] = _pm.s.velocity[2] * 0.125;

	/* save old org in case we get stuck */
  for (int i = 0; i < 3; i++) {
    _pml.previous_origin[i] = _pm.s.origin[i].toDouble();
  }

	_pml.frametime = _pm.cmd.msec * 0.001;

	_PM_ClampAngles();

	if (_pm.s.pm_type == pmtype_t.PM_SPECTATOR) {
// 		PM_FlyMove(false);
// 		PM_SnapPosition();
		return;
	}

	if (_pm.s.pm_type.index >= pmtype_t.PM_DEAD.index) {
		_pm.cmd.forwardmove = 0;
		_pm.cmd.sidemove = 0;
		_pm.cmd.upmove = 0;
	}

	if (_pm.s.pm_type == pmtype_t.PM_FREEZE) {
		if (cl.attractloop) {
			_PM_CalculateViewHeightForDemo();
			_PM_CalculateWaterLevelForDemo();
// 			PM_UpdateUnderwaterSfx();
		}

		return; /* no movement at all */
	}

	/* set mins, maxs, and viewheight */
	_PM_CheckDuck();

	if (_pm.snapinitial) {
		_PM_InitialSnapPosition();
	}

	/* set groundentity, watertype, and waterlevel */
	_PM_CatagorizePosition();

	if (_pm.s.pm_type == pmtype_t.PM_DEAD) {
		_PM_DeadMove();
	}

// 	PM_CheckSpecialMovement();

	/* drop timing counter */
	if (_pm.s.pm_time != 0) {

		int msec = _pm.cmd.msec >> 3;

		if (msec == 0) {
			msec = 1;
		}

		if (msec >= _pm.s.pm_time) {
			_pm.s.pm_flags &= ~(PMF_TIME_WATERJUMP | PMF_TIME_LAND | PMF_TIME_TELEPORT);
			_pm.s.pm_time = 0;
		} else {
			_pm.s.pm_time -= msec;
		}
	}

	if ((_pm.s.pm_flags & PMF_TIME_TELEPORT) != 0) {
		/* teleport pause stays exactly in place */
	} else if ((_pm.s.pm_flags & PMF_TIME_WATERJUMP) != 0) {
		/* waterjump has no control, but falls */
		_pml.velocity[2] -= _pm.s.gravity * _pml.frametime;

		if (_pml.velocity[2] < 0) {
			/* cancel as soon as we are falling down again */
			_pm.s.pm_flags &= ~(PMF_TIME_WATERJUMP | PMF_TIME_LAND | PMF_TIME_TELEPORT);
			_pm.s.pm_time = 0;
		}

// 		PM_StepSlideMove();
	} else {
// 		PM_CheckJump();

// 		PM_Friction();

// 		if (pm->waterlevel >= 2)
// 		{
// 			PM_WaterMove();
// 		}
// 		else
// 		{
// 			vec3_t angles;

// 			VectorCopy(pm->viewangles, angles);

// 			if (angles[PITCH] > 180)
// 			{
// 				angles[PITCH] = angles[PITCH] - 360;
// 			}

// 			angles[PITCH] /= 3;

// 			AngleVectors(angles, pml.forward, pml.right, pml.up);

// 			PM_AirMove();
// 		}
	}

	/* set groundentity, watertype, and waterlevel for final spot */
// 	PM_CatagorizePosition();

//     PM_UpdateUnderwaterSfx();

// 	PM_SnapPosition();
}

