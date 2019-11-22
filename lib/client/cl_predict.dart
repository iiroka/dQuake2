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
 * This file implements interpolation between two frames. This is used
 * to smooth down network play
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/collision.dart';
import 'package:dQuakeWeb/common/pmove.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'cl_main.dart';
import 'client.dart';

CL_CheckPredictionError() {

	if (!cl_predict.boolean ||
		((cl.frame.playerstate.pmove.pm_flags & PMF_NO_PREDICTION) != 0)) {
		return;
	}

	/* calculate the last usercmd_t we sent that the server has processed */
	int frame = cls.netchan.incoming_acknowledged;
	frame &= (CMD_BACKUP - 1);

	/* compare what the server returned with what we had predicted it to be */
  List<int> delta = List(3);
	VectorSubtractI(cl.frame.playerstate.pmove.origin, cl.predicted_origins[frame], delta);

	/* save the prediction error for interpolation */
	var len  = delta[0].abs() + delta[1].abs() + delta[2].abs();

	/* 80 world units */
	if (len > 640) {
		/* a teleport or something */
		cl.prediction_error.fillRange(0, 3, 0);
	}
	else
	{
		if (cl_showmiss.boolean && (delta[0] != 0 || delta[1] != 0 || delta[2] != 0)) {
			Com_Printf("prediction miss on ${cl.frame.serverframe}: ${delta[0] + delta[1] + delta[2]}\n");
		}

    cl.predicted_origins[frame].setRange(0, 3, cl.frame.playerstate.pmove.origin);

		/* save for error itnerpolation */
		for (int i = 0; i < 3; i++) {
			cl.prediction_error[i] = delta[i] * 0.125;
		}
	}
}

_CL_ClipMoveToEntities(List<double> start, List<double> mins, List<double> maxs,
		List<double> end, trace_t tr) {

	for (int i = 0; i < cl.frame.num_entities; i++) {
		int anum = (cl.frame.parse_entities + i) & (MAX_PARSE_ENTITIES - 1);
		var ent = cl_parse_entities[anum];

		if (ent.solid == 0) {
			continue;
		}

		if (ent.number == cl.playernum + 1) {
			continue;
		}

    int headnode;
    List<double> angles;

		if (ent.solid == 31) {
			/* special value for bmodel */
			var cmodel = cl.model_clip[ent.modelindex];
			if (cmodel == null) {
				continue;
			}

			headnode = cmodel.headnode;
			angles = ent.angles;
		} else {
			/* encoded bbox */
			int x = 8 * (ent.solid & 31);
			int zd = 8 * ((ent.solid >> 5) & 31);
			int zu = 8 * ((ent.solid >> 10) & 63) - 32;

      List<double> bmins = [(-x).toDouble(), (-x).toDouble(), (-zd).toDouble()];
      List<double> bmaxs = [x.toDouble(), x.toDouble(), zu.toDouble()];

			headnode = CM_HeadnodeForBox(bmins, bmaxs);
			angles = [0,0,0]; /* boxes don't rotate */
		}

		if (tr.allsolid) {
			return;
		}

		final trace = CM_TransformedBoxTrace(start, end, mins, maxs, headnode, MASK_PLAYERSOLID, ent.origin, angles);

		if (trace.allsolid || trace.startsolid ||
			(trace.fraction < tr.fraction)) {
			trace.ent = ent;

			if (tr.startsolid) {
				tr.copy(trace);
				tr.startsolid = true;
			} else {
				tr.copy(trace);
			}
		}
		else if (trace.startsolid)
		{
			tr.startsolid = true;
		}
	}
}

trace_t _CL_PMTrace(List<double> start, List<double> mins, List<double> maxs, List<double> end) {

	/* check against world */
	var t = CM_BoxTrace(start, end, mins, maxs, 0, MASK_PLAYERSOLID);

	if (t.fraction < 1.0) {
		t.ent = 1;
	}

	/* check all other solid models */
	_CL_ClipMoveToEntities(start, mins, maxs, end, t);

	return t;
}

int _CL_PMpointcontents(List<double> point) {

	int contents = CM_PointContents(point, 0);

	for (int i = 0; i < cl.frame.num_entities; i++) {
		int anum = (cl.frame.parse_entities + i) & (MAX_PARSE_ENTITIES - 1);
		var ent = cl_parse_entities[anum];

		if (ent.solid != 31) { /* special value for bmodel */
			continue;
		}

		var cmodel = cl.model_clip[ent.modelindex];
		if (cmodel == null) {
			continue;
		}

		contents |= CM_TransformedPointContents(point, cmodel.headnode, ent.origin, ent.angles);
	}

	return contents;
}

/*
 * Sets cl.predicted_origin and cl.predicted_angles
 */
CL_PredictMovement() {

	if (cls.state != connstate_t.ca_active) {
		return;
	}

	if (cl_paused.boolean) {
		return;
	}

	if (!cl_predict.boolean ||
		((cl.frame.playerstate.pmove.pm_flags & PMF_NO_PREDICTION) != 0)) {
		/* just set angles */
		for (int i = 0; i < 3; i++) {
			cl.predicted_angles[i] = cl.viewangles[i] + SHORT2ANGLE(
					cl.frame.playerstate.pmove.delta_angles[i]);
		}

		return;
	}

	int ack = cls.netchan.incoming_acknowledged;
	int current = cls.netchan.outgoing_sequence;

	/* if we are too far out of date, just freeze */
	if (current - ack >= CMD_BACKUP) {
		if (cl_showmiss.boolean) {
			Com_Printf("exceeded CMD_BACKUP\n");
		}

		return;
	}

	/* copy current state to pmove */
  final pm = pmove_t();
	pm.trace = _CL_PMTrace;
	pm.pointcontents = _CL_PMpointcontents;
	pm_airaccelerate = double.tryParse(cl.configstrings[CS_AIRACCEL]) ?? 0;
	pm.s.copy(cl.frame.playerstate.pmove);

	/* run frames */
	while (++ack <= current) {
		int frame = ack & (CMD_BACKUP - 1);
		final cmd = cl.cmds[frame];

		// Ignore null entries
		if (cmd.msec == 0) {
			continue;
		}

		pm.cmd.copy(cmd);
		Pmove(pm);

		/* save for debug checking */
    cl.predicted_origins[frame].setRange(0, 3, pm.s.origin);
	}

	int step = pm.s.origin[2] - (cl.predicted_origin[2] * 8).toInt();

	if (((step > 126 && step < 130))
		&& (pm.s.velocity[0] != 0 || pm.s.velocity[1] != 0 || pm.s.velocity[2] != 0)
		&& ((pm.s.pm_flags & PMF_ON_GROUND) != 0))
	{
		cl.predicted_step = step * 0.125;
		cl.predicted_step_time = cls.realtime - (cls.nframetime * 500).toInt();
	}

	/* copy results out for rendering */
	cl.predicted_origin[0] = pm.s.origin[0] * 0.125;
	cl.predicted_origin[1] = pm.s.origin[1] * 0.125;
	cl.predicted_origin[2] = pm.s.origin[2] * 0.125;

  cl.predicted_angles.setRange(0, 3, pm.viewangles);
}

