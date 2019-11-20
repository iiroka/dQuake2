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
import 'package:dQuakeWeb/common/cvar.dart';
import 'package:dQuakeWeb/common/frame.dart' show curtime;
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'package:dQuakeWeb/shared/writebuf.dart';
import 'client.dart';
import 'input.dart';
import 'cl_main.dart';

cvar_t cl_nodelta;

int frame_msec = 0;
int old_sys_frame_time = 0;

CL_InitInput() {
	// Cmd_AddCommand("centerview", IN_CenterView);
	// Cmd_AddCommand("force_centerview", IN_ForceCenterView);

	// Cmd_AddCommand("+moveup", IN_UpDown);
	// Cmd_AddCommand("-moveup", IN_UpUp);
	// Cmd_AddCommand("+movedown", IN_DownDown);
	// Cmd_AddCommand("-movedown", IN_DownUp);
	// Cmd_AddCommand("+left", IN_LeftDown);
	// Cmd_AddCommand("-left", IN_LeftUp);
	// Cmd_AddCommand("+right", IN_RightDown);
	// Cmd_AddCommand("-right", IN_RightUp);
	// Cmd_AddCommand("+forward", IN_ForwardDown);
	// Cmd_AddCommand("-forward", IN_ForwardUp);
	// Cmd_AddCommand("+back", IN_BackDown);
	// Cmd_AddCommand("-back", IN_BackUp);
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
	// Cmd_AddCommand("+speed", IN_SpeedDown);
	// Cmd_AddCommand("-speed", IN_SpeedUp);
	// Cmd_AddCommand("+attack", IN_AttackDown);
	// Cmd_AddCommand("-attack", IN_AttackUp);
	// Cmd_AddCommand("+use", IN_UseDown);
	// Cmd_AddCommand("-use", IN_UseUp);
	// Cmd_AddCommand("impulse", IN_Impulse);
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
	// CL_BaseMove(cmd);
	// IN_Move(cmd);

	// Clamp angels for prediction
	// CL_ClampPitch();

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
	// if (((in_attack.state & 2)) || (in_use.state & 2)) {
	// 	cls.forcePacket = true;
	// }
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
	// CL_BaseMove(cmd);
	// IN_Move(cmd);

	old_sys_frame_time = sys_frame_time;
}

CL_FinalizeCmd() {

	// CMD to fill
	final cmd = cl.cmds[cls.netchan.outgoing_sequence & (CMD_BACKUP - 1)];

	// Mouse button events
	// if (in_attack.state & 3)
	// {
	// 	cmd->buttons |= BUTTON_ATTACK;
	// }

	// in_attack.state &= ~2;

	// if (in_use.state & 3)
	// {
	// 	cmd->buttons |= BUTTON_USE;
	// }

	// in_use.state &= ~2;

	// // Keyboard events
	// if (anykeydown && cls.key_dest == key_game)
	// {
	// 	cmd->buttons |= BUTTON_ANY;
	// }

	// cmd->impulse = in_impulse;
	// in_impulse = 0;

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
	// i = (cls.netchan.outgoing_sequence - 2) & (CMD_BACKUP - 1);
	cmd = cl.cmds[i];
	// memset(&nullcmd, 0, sizeof(nullcmd));
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
