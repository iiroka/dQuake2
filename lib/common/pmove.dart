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
import 'dart:math';
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/client/client.dart';
import 'package:dQuakeWeb/shared/files.dart';
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

const _STOP_EPSILON = 0.1; /* Slide off of the impacting object returns the blocked flags (1 = floor, 2 = step / wall) */
const _MIN_STEP_NORMAL = 0.7; /* can't step up onto very steep slopes */
const _MAX_CLIP_PLANES = 5;  

_PM_ClipVelocity(List<double> ind, List<double> normal, List<double> out, double overbounce) {

	double backoff = DotProduct(ind, normal) * overbounce;

	for (int i = 0; i < 3; i++) {
		double change = normal[i] * backoff;
		out[i] = ind[i] - change;

		if ((out[i] > -_STOP_EPSILON) && (out[i] < _STOP_EPSILON)) {
			out[i] = 0;
		}
	}
}

/*
 * Each intersection will try to step over the obstruction instead of
 * sliding along it.
 *
 * Returns a new origin, velocity, and contact entity
 * Does not modify any world state?
 */
_PM_StepSlideMove_() {

  List<List<double>> planes = List.generate(_MAX_CLIP_PLANES, (i) => [0,0,0]);

	int numbumps = 4;

  List<double> primal_velocity = List.generate(3, (i) => _pml.velocity[i]);
	int numplanes = 0;

	double time_left = _pml.frametime;

	for (int bumpcount = 0; bumpcount < numbumps; bumpcount++) {
    List<double> end = List.generate(3, (i) => _pml.origin[i] + time_left * _pml.velocity[i]);

		var trace = _pm.trace(_pml.origin, _pm.mins, _pm.maxs, end);
		if (trace.allsolid) {
			/* entity is trapped in another solid */
			_pml.velocity[2] = 0; /* don't build up falling damage */
			return;
		}

		if (trace.fraction > 0) {
			/* actually covered some distance */
      _pml.origin.setAll(0, trace.endpos);
			numplanes = 0;
		}

		if (trace.fraction == 1) {
			break; /* moved the entire distance */
		}

		/* save entity for contact */
		if ((_pm.numtouch < MAXTOUCH) && trace.ent != null) {
			_pm.touchents[_pm.numtouch] = trace.ent;
			_pm.numtouch++;
		}

		time_left -= time_left * trace.fraction;

		/* slide along this plane */
		if (numplanes >= _MAX_CLIP_PLANES) {
			/* this shouldn't really happen */
      _pml.velocity.fillRange(0, 3, 0);
			break;
		}

    planes[numplanes].setAll(0, trace.plane.normal);
		numplanes++;

		/* modify original_velocity so it parallels all of the clip planes */
    int i;
		for (i = 0; i < numplanes; i++) {
			_PM_ClipVelocity(_pml.velocity, planes[i], _pml.velocity, 1.01);
      int j;
			for (j = 0; j < numplanes; j++) {
				if (j != i) {
					if (DotProduct(_pml.velocity, planes[j]) < 0) {
						break; /* not ok */
					}
				}
			}

			if (j == numplanes) {
				break;
			}
		}

		if (i != numplanes) {
			/* go along this plane */
		} else {
			/* go along the crease */
			if (numplanes != 2) {
        _pml.velocity.fillRange(0, 3, 0);
				break;
			}

      List<double> dir = [0,0,0];
			CrossProduct(planes[0], planes[1], dir);
			double d = DotProduct(dir, _pml.velocity);
			VectorScale(dir, d, _pml.velocity);
		}

		/* if velocity is against the original velocity, stop dead
		   to avoid tiny occilations in sloping corners */
		if (DotProduct(_pml.velocity, primal_velocity) <= 0) {
      _pml.velocity.fillRange(0, 3, 0);
			break;
		}
	}

	if (_pm.s.pm_time != 0) {
    _pml.velocity.setAll(0, primal_velocity);
	}
}

_PM_StepSlideMove() {
	// vec3_t start_o, start_v;
	// vec3_t down_o, down_v;
	// trace_t trace;
	// float down_dist, up_dist;
	// vec3_t up, down;

  List<double> start_o = List.generate(3, (i) => _pml.origin[i]);
  List<double> start_v = List.generate(3, (i) => _pml.velocity[i]);

	_PM_StepSlideMove_();

  List<double> down_o = List.generate(3, (i) => _pml.origin[i]);
  List<double> down_v = List.generate(3, (i) => _pml.velocity[i]);

  List<double> up = List.generate(3, (i) => start_o[i]);
	up[2] += _STEPSIZE;

	var trace = _pm.trace(up, _pm.mins, _pm.maxs, up);
	if (trace.allsolid) {
		return; /* can't step up */
	}

	/* try sliding above */
  _pml.origin.setAll(0, up);
  _pml.velocity.setAll(0, start_v);

	_PM_StepSlideMove_();

	/* push down the final amount */
  List<double> down = List.generate(3, (i) => _pml.origin[i]);
	down[2] -= _STEPSIZE;
	trace = _pm.trace(_pml.origin, _pm.mins, _pm.maxs, down);
	if (!trace.allsolid) {
    _pml.origin.setAll(0, trace.endpos);
	}

  up.setAll(0, _pml.origin);

	/* decide which one went farther */
	var down_dist = (down_o[0] - start_o[0]) * (down_o[0] - start_o[0])
				+ (down_o[1] - start_o[1]) * (down_o[1] - start_o[1]);
	var up_dist = (up[0] - start_o[0]) * (up[0] - start_o[0])
			  + (up[1] - start_o[1]) * (up[1] - start_o[1]);

	if ((down_dist > up_dist) || (trace.plane.normal[2] < _MIN_STEP_NORMAL)) {
    _pml.origin.setAll(0, down_o);
    _pml.velocity.setAll(0, down_v);
		return;
	}

	_pml.velocity[2] = down_v[2];
}

/*
 * Handles both ground friction and water friction
 */
_PM_Friction() {
	// float *vel;
	// float speed, newspeed, control;
	// float friction;
	// float drop;

	var vel = _pml.velocity;

	var speed = sqrt(vel[0] * vel[0] + vel[1] * vel[1] + vel[2] * vel[2]);

	if (speed < 1)
	{
		vel[0] = 0;
		vel[1] = 0;
		return;
	}

	double drop = 0;

	/* apply ground friction */
	if ((_pm.groundentity != 0 && _pml.groundsurface != null &&
		 (_pml.groundsurface.flags & SURF_SLICK) == 0) || (_pml.ladder)) {
		double friction = pm_friction;
		double control = speed < pm_stopspeed ? pm_stopspeed : speed;
		drop += control * friction * _pml.frametime;
	}

	/* apply water friction */
	if (_pm.waterlevel > 0 && !_pml.ladder) {
		drop += speed * pm_waterfriction * _pm.waterlevel * _pml.frametime;
	}

	/* scale the velocity */
	double newspeed = speed - drop;

	if (newspeed < 0) {
		newspeed = 0;
	}

	newspeed /= speed;

	vel[0] = vel[0] * newspeed;
	vel[1] = vel[1] * newspeed;
	vel[2] = vel[2] * newspeed;
}


/*
 * Handles user intended acceleration
 */
_PM_Accelerate(List<double> wishdir, double wishspeed, double accel) {

	double currentspeed = DotProduct(_pml.velocity, wishdir);
	double addspeed = wishspeed - currentspeed;

	if (addspeed <= 0) {
		return;
	}

	double accelspeed = accel * _pml.frametime * wishspeed;
	if (accelspeed > addspeed) {
		accelspeed = addspeed;
	}

	for (int i = 0; i < 3; i++) {
		_pml.velocity[i] += accelspeed * wishdir[i];
	}
}

_PM_AirAccelerate(List<double> wishdir, double wishspeed, double accel) {
  double wishspd = wishspeed;

	if (wishspd > 30) {
		wishspd = 30;
	}

	double currentspeed = DotProduct(_pml.velocity, wishdir);
	double addspeed = wishspd - currentspeed;

	if (addspeed <= 0) {
		return;
	}

	double accelspeed = accel * wishspeed * _pml.frametime;

	if (accelspeed > addspeed) {
		accelspeed = addspeed;
	}

	for (int i = 0; i < 3; i++) {
		_pml.velocity[i] += accelspeed * wishdir[i];
	}
}

_PM_AddCurrents(List<double> wishvel) {

	/* account for ladders */
	if (_pml.ladder && (_pml.velocity[2].abs() <= 200)) {
		if ((_pm.viewangles[PITCH] <= -15) && (_pm.cmd.forwardmove > 0)) {
			wishvel[2] = 200;
		} else if ((_pm.viewangles[PITCH] >= 15) && (_pm.cmd.forwardmove > 0)) {
			wishvel[2] = -200;
		} else if (_pm.cmd.upmove > 0) {
			wishvel[2] = 200;
		} else if (_pm.cmd.upmove < 0) {
			wishvel[2] = -200;
		} else {
			wishvel[2] = 0;
		}

		/* limit horizontal speed when on a ladder */
		if (wishvel[0] < -25) {
			wishvel[0] = -25;
		} else if (wishvel[0] > 25) {
			wishvel[0] = 25;
		}

		if (wishvel[1] < -25) {
			wishvel[1] = -25;
		} else if (wishvel[1] > 25) {
			wishvel[1] = 25;
		}
	}

	/* add water currents  */
	if ((_pm.watertype & MASK_CURRENT) != 0) {
		List<double> v = [0,0,0];

		if ((_pm.watertype & CONTENTS_CURRENT_0) != 0) {
			v[0] += 1;
		}

		if ((_pm.watertype & CONTENTS_CURRENT_90) != 0) {
			v[1] += 1;
		}

		if ((_pm.watertype & CONTENTS_CURRENT_180) != 0) {
			v[0] -= 1;
		}

		if ((_pm.watertype & CONTENTS_CURRENT_270) != 0) {
			v[1] -= 1;
		}

		if ((_pm.watertype & CONTENTS_CURRENT_UP) != 0) {
			v[2] += 1;
		}

		if ((_pm.watertype & CONTENTS_CURRENT_DOWN) != 0) {
			v[2] -= 1;
		}

		double s = pm_waterspeed;

		if ((_pm.waterlevel == 1) && (_pm.groundentity != null)) {
			s /= 2;
		}

		VectorMA(wishvel, s, v, wishvel);
	}

	/* add conveyor belt velocities */
	if (_pm.groundentity != null) {
		List<double> v = [0,0,0];

		if ((_pml.groundcontents & CONTENTS_CURRENT_0) != 0) {
			v[0] += 1;
		}

		if ((_pml.groundcontents & CONTENTS_CURRENT_90) != 0) {
			v[1] += 1;
		}

		if ((_pml.groundcontents & CONTENTS_CURRENT_180) != 0) {
			v[0] -= 1;
		}

		if ((_pml.groundcontents & CONTENTS_CURRENT_270) != 0) {
			v[1] -= 1;
		}

		if ((_pml.groundcontents & CONTENTS_CURRENT_UP) != 0) {
			v[2] += 1;
		}

		if ((_pml.groundcontents & CONTENTS_CURRENT_DOWN) != 0) {
			v[2] -= 1;
		}

		VectorMA(wishvel, 100, v, wishvel);
	}
}

_PM_AirMove() {

	double fmove = _pm.cmd.forwardmove.toDouble();
	double smove = _pm.cmd.sidemove.toDouble();

  List<double> wishvel = [0,0,0];
	for (int i = 0; i < 2; i++) {
		wishvel[i] = _pml.forward[i] * fmove + _pml.right[i] * smove;
	}

	wishvel[2] = 0;

	_PM_AddCurrents(wishvel);
  List<double> wishdir = List.generate(3, (i) => wishvel[i]);
	double wishspeed = VectorNormalize(wishdir);

	/* clamp to server defined max speed */
	double maxspeed = (_pm.s.pm_flags & PMF_DUCKED) != 0 ? pm_duckspeed : pm_maxspeed;

	if (wishspeed > maxspeed) {
		VectorScale(wishvel, maxspeed / wishspeed, wishvel);
		wishspeed = maxspeed;
	}

	if (_pml.ladder) {
		_PM_Accelerate(wishdir, wishspeed, pm_accelerate);

	// 	if (!wishvel[2])
	// 	{
	// 		if (pml.velocity[2] > 0)
	// 		{
	// 			pml.velocity[2] -= pm->s.gravity * pml.frametime;

	// 			if (pml.velocity[2] < 0)
	// 			{
	// 				pml.velocity[2] = 0;
	// 			}
	// 		}
	// 		else
	// 		{
	// 			pml.velocity[2] += pm->s.gravity * pml.frametime;

	// 			if (pml.velocity[2] > 0)
	// 			{
	// 				pml.velocity[2] = 0;
	// 			}
	// 		}
	// 	}

		_PM_StepSlideMove();
	} else if (_pm.groundentity != null) {
		/* walking on ground */
		_pml.velocity[2] = 0;
		_PM_Accelerate(wishdir, wishspeed, pm_accelerate);

		if (_pm.s.gravity > 0) {
			_pml.velocity[2] = 0;
		} else {
			_pml.velocity[2] -= _pm.s.gravity * _pml.frametime;
		}

		if (_pml.velocity[0] == 0 && _pml.velocity[1] == 0) {
			return;
		}

		_PM_StepSlideMove();
	} else {
		/* not on ground, so little effect on velocity */
		if (pm_airaccelerate != 0) {
			_PM_AirAccelerate(wishdir, wishspeed, pm_accelerate);
		} else {
			_PM_Accelerate(wishdir, wishspeed, 1);
		}

		/* add gravity */
		_pml.velocity[2] -= _pm.s.gravity * _pml.frametime;
		_PM_StepSlideMove();
	}
}

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

/*
 * On exit, the origin will have a value that is pre-quantized to the 0.125
 * precision of the network channel and in a valid position.
 */
final _jitterbits = [0, 4, 1, 2, 3, 5, 6, 7];
_PM_SnapPosition() {
	/* try all single bits first */

	/* snap velocity to eigths */
	for (int i = 0; i < 3; i++) {
		_pm.s.velocity[i] = (_pml.velocity[i] * 8).toInt();
	}

  List<int> sign = [0,0, 0];
	for (int i = 0; i < 3; i++) {
		if (_pml.origin[i] >= 0) {
			sign[i] = 1;
		} else {
			sign[i] = -1;
		}

		_pm.s.origin[i] = (_pml.origin[i] * 8).toInt();

		if (_pm.s.origin[i] * 0.125 == _pml.origin[i]) {
			sign[i] = 0;
		}
	}

  List<int> base = List.generate(3, (i) => _pm.s.origin[i]);

	/* try all combinations */
	for (int j = 0; j < 8; j++) {
		int bits = _jitterbits[j];
    _pm.s.origin.setAll(0, base);

		for (int i = 0; i < 3; i++) {
			if ((bits & (1 << i)) != 0) {
				_pm.s.origin[i] += sign[i];
			}
		}

		if (_PM_GoodPosition()) {
			return;
		}
	}

	/* go back to the last position */
  for (int i = 0; i < 3; i++) {
    _pm.s.origin[i] = _pml.previous_origin[i].toInt();
  }
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
		_PM_SnapPosition();
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

		_PM_StepSlideMove();
	} else {
// 		PM_CheckJump();

		_PM_Friction();

		if (_pm.waterlevel >= 2) {
// 			PM_WaterMove();
		} else {
			List<double> angles = List.generate(3, (i) => _pm.viewangles[i]);

			if (angles[PITCH] > 180) {
				angles[PITCH] = angles[PITCH] - 360;
			}

			angles[PITCH] /= 3;

			AngleVectors(angles, _pml.forward, _pml.right, _pml.up);

			_PM_AirMove();
		}
	}

	/* set groundentity, watertype, and waterlevel for final spot */
	_PM_CatagorizePosition();

//     PM_UpdateUnderwaterSfx();

	_PM_SnapPosition();
}

