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
 * This file implements the input handling like mouse events and
 * keyboard strokes.
 *
 * =======================================================================
 */
import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cmdparser.dart';
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/frame.dart' show curtime;
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/shared/writebuf.dart';
import 'client.dart';
import 'input.dart';
import 'cl_main.dart';
import 'cl_keyboard.dart' show anykeydown;

cvar_t cl_nodelta;

int frame_msec = 0;
int old_sys_frame_time = 0;

/*
 * KEY BUTTONS
 *
 * Continuous button event tracking is complicated by the fact that two different
 * input sources (say, mouse button 1 and the control key) can both press the
 * same button, but the button should only be released when both of the
 * pressing key have been released.
 *
 * When a key event issues a button command (+forward, +attack, etc), it appends
 * its key number as a parameter to the command so it can be matched up with
 * the release.
 *
 * state bit 0 is the current state of the key
 * state bit 1 is edge triggered on the up to down transition
 * state bit 2 is edge triggered on the down to up transition
 *
 *
 * Key_Event (int key, qboolean down, unsigned time);
 *
 *   +mlook src time
 */

class kbutton_t {
	List<int>	down = [0,0]; /* key nums holding it down */
	int	downtime = 0; /* msec timestamp */
	int	msec = 0; /* msec down this frame */
	int	state = 0;
}


kbutton_t in_klook = kbutton_t();
kbutton_t in_left = kbutton_t(), in_right = kbutton_t(), in_forward = kbutton_t(), in_back = kbutton_t();
kbutton_t in_lookup = kbutton_t(), in_lookdown = kbutton_t(), in_moveleft = kbutton_t(), in_moveright = kbutton_t();
kbutton_t in_strafe = kbutton_t(), in_speed = kbutton_t(), in_use = kbutton_t(), in_attack = kbutton_t();
kbutton_t in_up = kbutton_t(), in_down = kbutton_t();

int in_impulse = 0;

KeyDown(kbutton_t b, List<String> args) {

	var c = args[1];
  int k = -1;
	if (c.isNotEmpty) {
		k = int.parse(c);
	}

	if ((k == b.down[0]) || (k == b.down[1])) {
		return; /* repeating key */
	}

	if (b.down[0] == 0) {
		b.down[0] = k;
	} else if (b.down[1] == 0) {
		b.down[1] = k;
	} else {
		Com_Printf("Three keys down for a button!\n");
		return;
	}

	if ((b.state & 1) != 0) {
		return; /* still down */
	}

	/* save timestamp */
	c = args[2];
	b.downtime = int.parse(c);
	if (b.downtime == 0) {
		b.downtime = sys_frame_time - 100;
	}

	b.state |= 1 + 2; /* down + impulse down */
}

KeyUp(kbutton_t b, List<String> args) {

	var c = args[1];
  int k = 0;
	if (c.isEmpty) {
		k = int.parse(c);
	} else {
		/* typed manually at the console, assume for unsticking, so clear all */
		b.down[0] = b.down[1] = 0;
		b.state = 4; /* impulse up */
		return;
	}

	if (b.down[0] == k) {
		b.down[0] = 0;
	} else if (b.down[1] == k) {
		b.down[1] = 0;
	} else {
		return; /* key up without coresponding down (menu pass through) */
	}

	if (b.down[0] != 0 || b.down[1] != 0) {
		return; /* some other key is still holding it down */
	}

	if ((b.state & 1) == 0) {
		return; /* still up (this should not happen) */
	}

	/* save timestamp */
	c = args[2];
	var uptime = int.parse(c);
	if (uptime != 0) {
		b.msec += uptime - b.downtime;
	} else {
		b.msec += 10;
	}

	b.state &= ~1; /* now up */
	b.state |= 4; /* impulse up */
}


/*
 * Returns the fraction of the
 * frame that the key was down
 */
double CL_KeyState(kbutton_t key) {

	key.state &= 1; /* clear impulses */

	int msec = key.msec;
	key.msec = 0;

	if (key.state != 0) {
		/* still down */
		msec += sys_frame_time - key.downtime;
		key.downtime = sys_frame_time;
	}

	var val = msec / frame_msec;
	if (val < 0)
	{
		val = 0;
	}

	if (val > 1)
	{
		val = 1;
	}

	return val;
}

IN_LeftDown(List<String> args) => KeyDown(in_left, args);
IN_LeftUp(List<String> args) => KeyUp(in_left, args);
IN_RightDown(List<String> args) => KeyDown(in_right, args);
IN_RightUp(List<String> args) => KeyUp(in_right, args);
IN_ForwardDown(List<String> args) => KeyDown(in_forward, args);
IN_ForwardUp(List<String> args) => KeyUp(in_forward, args);
IN_BackDown(List<String> args) => KeyDown(in_back, args);
IN_BackUp(List<String> args) => KeyUp(in_back, args);
IN_SpeedDown(List<String> args) => KeyDown(in_speed, args);
IN_SpeedUp(List<String> args) => KeyUp(in_speed, args);
IN_AttackDown(List<String> args) => KeyDown(in_attack, args);
IN_AttackUp(List<String> args) => KeyUp(in_attack, args);
IN_UseDown(List<String> args) => KeyDown(in_use, args);
IN_UseUp(List<String> args) => KeyUp(in_use, args);

IN_Impulse(List<String> args) {
	in_impulse = int.parse(args[1]);
}


cvar_t cl_upspeed;
cvar_t cl_forwardspeed;
cvar_t cl_sidespeed;
cvar_t cl_yawspeed;
cvar_t cl_pitchspeed;
cvar_t cl_run;
cvar_t cl_anglespeedkey;
/*
 * Moves the local angle positions
 */
CL_AdjustAngles() {

  double speed;
	if ((in_speed.state & 1) != 0) {
		speed = cls.nframetime * cl_anglespeedkey.value;
	} else {
		speed = cls.nframetime;
	}

	if ((in_strafe.state & 1) == 0) {
		cl.viewangles[YAW] -= speed * cl_yawspeed.value * CL_KeyState(in_right);
		cl.viewangles[YAW] += speed * cl_yawspeed.value * CL_KeyState(in_left);
	}

	if ((in_klook.state & 1) != 0) {
		cl.viewangles[PITCH] -= speed * cl_pitchspeed.value * CL_KeyState(in_forward);
		cl.viewangles[PITCH] += speed * cl_pitchspeed.value * CL_KeyState(in_back);
	}

	double up = CL_KeyState(in_lookup);
	double down = CL_KeyState(in_lookdown);

	cl.viewangles[PITCH] -= speed * cl_pitchspeed.value * up;
	cl.viewangles[PITCH] += speed * cl_pitchspeed.value * down;
}
/*
 * Send the intended movement message to the server
 */
CL_BaseMove(usercmd_t cmd) {
	CL_AdjustAngles();

	cmd.clear();

  for (int i = 0; i < 3; i++) {
    cmd.angles[i] = cl.viewangles[i].toInt();
  }

	if ((in_strafe.state & 1) != 0) {
		cmd.sidemove += (cl_sidespeed.value * CL_KeyState(in_right)).toInt();
		cmd.sidemove -= (cl_sidespeed.value * CL_KeyState(in_left)).toInt();
	}

	cmd.sidemove += (cl_sidespeed.value * CL_KeyState(in_moveright)).toInt();
	cmd.sidemove -= (cl_sidespeed.value * CL_KeyState(in_moveleft)).toInt();

	cmd.upmove += (cl_upspeed.value * CL_KeyState(in_up)).toInt();
	cmd.upmove -= (cl_upspeed.value * CL_KeyState(in_down)).toInt();

	if ((in_klook.state & 1) == 0) {
		cmd.forwardmove += (cl_forwardspeed.value * CL_KeyState(in_forward)).toInt();
		cmd.forwardmove -= (cl_forwardspeed.value * CL_KeyState(in_back)).toInt();
	}

	/* adjust for speed key / running */
	if (((in_speed.state & 1) ^ cl_run.integer) != 0) {
		cmd.forwardmove *= 2;
		cmd.sidemove *= 2;
		cmd.upmove *= 2;
	}
}

CL_ClampPitch() {

  if (cl.frame == null) {
    return;
  }

	double pitch = SHORT2ANGLE(cl.frame.playerstate.pmove.delta_angles[PITCH]);

	if (pitch > 180)
	{
		pitch -= 360;
	}

	if (cl.viewangles[PITCH] + pitch < -360)
	{
		cl.viewangles[PITCH] += 360; /* wrapped */
	}

	if (cl.viewangles[PITCH] + pitch > 360)
	{
		cl.viewangles[PITCH] -= 360; /* wrapped */
	}

	if (cl.viewangles[PITCH] + pitch > 89)
	{
		cl.viewangles[PITCH] = 89 - pitch;
	}

	if (cl.viewangles[PITCH] + pitch < -89)
	{
		cl.viewangles[PITCH] = -89 - pitch;
	}
}

CL_InitInput() {
	// Cmd_AddCommand("centerview", IN_CenterView);
	// Cmd_AddCommand("force_centerview", IN_ForceCenterView);

	// Cmd_AddCommand("+moveup", IN_UpDown);
	// Cmd_AddCommand("-moveup", IN_UpUp);
	// Cmd_AddCommand("+movedown", IN_DownDown);
	// Cmd_AddCommand("-movedown", IN_DownUp);
	Cmd_AddCommand("+left", IN_LeftDown);
	Cmd_AddCommand("-left", IN_LeftUp);
	Cmd_AddCommand("+right", IN_RightDown);
	Cmd_AddCommand("-right", IN_RightUp);
	Cmd_AddCommand("+forward", IN_ForwardDown);
	Cmd_AddCommand("-forward", IN_ForwardUp);
	Cmd_AddCommand("+back", IN_BackDown);
	Cmd_AddCommand("-back", IN_BackUp);
	// Cmd_AddCommand("+lookup", IN_LookupDown);
	// Cmd_AddCommand("-lookup", IN_LookupUp);
	// Cmd_AddCommand("+lookdown", IN_LookdownDown);
	// Cmd_AddCommand("-lookdown", IN_LookdownUp);
	// Cmd_AddCommand("+strafe", IN_StrafeDown);
	// Cmd_AddCommand("-strafe", IN_StrafeUp);
	// Cmd_AddCommand("+moveleft", IN_MoveleftDown);
	// Cmd_AddCommand("-moveleft", IN_MoveleftUp);
	// Cmd_AddCommand("+moveright", IN_MoverightDown);
	// Cmd_AddCommand("-moveright", IN_MoverightUp);
	Cmd_AddCommand("+speed", IN_SpeedDown);
	Cmd_AddCommand("-speed", IN_SpeedUp);
	Cmd_AddCommand("+attack", IN_AttackDown);
	Cmd_AddCommand("-attack", IN_AttackUp);
	Cmd_AddCommand("+use", IN_UseDown);
	Cmd_AddCommand("-use", IN_UseUp);
	Cmd_AddCommand("impulse", IN_Impulse);
	// Cmd_AddCommand("+klook", IN_KLookDown);
	// Cmd_AddCommand("-klook", IN_KLookUp);

	cl_nodelta = Cvar_Get("cl_nodelta", "0", 0);
}


CL_RefreshCmd() {

	// CMD to fill
	final cmd = cl.cmds[cls.netchan.outgoing_sequence & (CMD_BACKUP - 1)];

	// Calculate delta
	frame_msec = sys_frame_time - old_sys_frame_time;

	// Check bounds
	if (frame_msec < 1) {
		return;
	} else if (frame_msec > 200) {
		frame_msec = 200;
	}

	// Add movement
	CL_BaseMove(cmd);
	// IN_Move(cmd);

	// Clamp angels for prediction
	CL_ClampPitch();

	cmd.angles[0] = ANGLE2SHORT(cl.viewangles[0]);
	cmd.angles[1] = ANGLE2SHORT(cl.viewangles[1]);
	cmd.angles[2] = ANGLE2SHORT(cl.viewangles[2]);

	// Update time for prediction
	int ms = (cls.nframetime * 1000.0).toInt();

	if (ms > 250) {
		ms = 100;
	}

	cmd.msec = ms;

	// Update frame time for the next call
	old_sys_frame_time = sys_frame_time;

	// Important events are send immediately
	if (((in_attack.state & 2) != 0) || (in_use.state & 2) != 0) {
		cls.forcePacket = true;
	}
}

CL_RefreshMove() {

	// CMD to fill
	final cmd = cl.cmds[cls.netchan.outgoing_sequence & (CMD_BACKUP - 1)];

	// Calculate delta
	frame_msec = sys_frame_time - old_sys_frame_time;

	// Check bounds
	if (frame_msec < 1)
	{
		return;
	}
	else if (frame_msec > 200)
	{
		frame_msec = 200;
	}

	// Add movement
	CL_BaseMove(cmd);
	// IN_Move(cmd);

	old_sys_frame_time = sys_frame_time;
}

CL_FinalizeCmd() {

	// CMD to fill
	final cmd = cl.cmds[cls.netchan.outgoing_sequence & (CMD_BACKUP - 1)];

	// Mouse button events
	if ((in_attack.state & 3) != 0) {
		cmd.buttons |= BUTTON_ATTACK;
	}

	in_attack.state &= ~2;

	if ((in_use.state & 3) != 0) {
		cmd.buttons |= BUTTON_USE;
	}

	in_use.state &= ~2;

	// Keyboard events
	if (anykeydown != 0 && cls.key_dest == keydest_t.key_game) {
		cmd.buttons |= BUTTON_ANY;
	}

	cmd.impulse = in_impulse;
	in_impulse = 0;

	// Set light level for muzzle flash
	cmd.lightlevel = cl_lightlevel.integer & 0xFF;
}


CL_SendCmd() {
	// sizebuf_t buf;
	// byte data[128];
	// int i;
	// usercmd_t *cmd, *oldcmd;
	// usercmd_t nullcmd;
	// int checksumIndex;

	// memset(&buf, 0, sizeof(buf));

	/* save this command off for prediction */
	var i = cls.netchan.outgoing_sequence & (CMD_BACKUP - 1);
	var cmd = cl.cmds[i];
	cl.cmd_time[i] = cls.realtime; /* for netgraph ping calculation */

	CL_FinalizeCmd();

	cl.cmd.copy(cmd);

	if ((cls.state == connstate_t.ca_disconnected) || (cls.state == connstate_t.ca_connecting)) {
		return;
	}

	if (cls.state == connstate_t.ca_connected) {
		if (cls.netchan.message.cursize != 0 ||
			(curtime - cls.netchan.last_sent > 1000)) {
			cls.netchan.Transmit(null);
		}
		return;
	}

	/* send a userinfo update if needed */
	// if (userinfo_modified)
	// {
	// 	CL_FixUpGender();
	// 	userinfo_modified = false;
	// 	MSG_WriteByte(&cls.netchan.message, clc_userinfo);
	// 	MSG_WriteString(&cls.netchan.message, Cvar_Userinfo());
	// }

  Writebuf buf = Writebuf.size(128);

	// if (cmd->buttons && (cl.cinematictime > 0) && !cl.attractloop &&
	// 	(cls.realtime - cl.cinematictime > 1000))
	// {
	// 	/* skip the rest of the cinematic */
	// 	SCR_FinishCinematic();
	// }

	/* begin a client move command */
	buf.WriteByte(clc_ops_e.clc_move.index);

	// /* save the position for a checksum byte */
	// checksumIndex = buf.cursize;
	buf.WriteByte(0);

	/* let the server know what the last frame we
	   got was, so the next message can be delta
	   compressed */
	if (cl_nodelta.boolean || !cl.frame.valid /* || cls.demowaiting*/) {
		buf.WriteLong(-1); /* no compression */
	} else {
		buf.WriteLong(cl.frame.serverframe);
	}

	/* send this and the previous cmds in the message, so
	   if the last packet was dropped, it can be recovered */
	i = (cls.netchan.outgoing_sequence - 2) & (CMD_BACKUP - 1);
	cmd = cl.cmds[i];
	buf.WriteDeltaUsercmd(usercmd_t(), cmd);
	var oldcmd = cmd;

	i = (cls.netchan.outgoing_sequence - 1) & (CMD_BACKUP - 1);
	cmd = cl.cmds[i];
	buf.WriteDeltaUsercmd(oldcmd, cmd);
	oldcmd = cmd;

	i = (cls.netchan.outgoing_sequence) & (CMD_BACKUP - 1);
	cmd = cl.cmds[i];
	buf.WriteDeltaUsercmd(oldcmd, cmd);

	// /* calculate a checksum over the move commands */
	// buf.data[checksumIndex] = COM_BlockSequenceCRCByte(
	// 		buf.data + checksumIndex + 1, buf.cursize - checksumIndex - 1,
	// 		cls.netchan.outgoing_sequence);

	/* deliver the message */
	cls.netchan.Transmit(buf.Data());

	/* Reinit the current cmd buffer */
	cl.cmds[cls.netchan.outgoing_sequence & (CMD_BACKUP - 1)].clear();
}
