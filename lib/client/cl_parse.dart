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
 * This file implements the entity and network protocol parsing
 *
 * =======================================================================
 */

import 'package:dQuakeWeb/common/clientserver.dart';
import 'package:dQuakeWeb/common/cmdparser.dart';
import 'package:dQuakeWeb/shared/common.dart';
import 'package:dQuakeWeb/shared/readbuf.dart';
import 'package:dQuakeWeb/shared/shared.dart';
import 'client.dart';
import 'cl_main.dart';
import 'vid/vid.dart' show re;
import 'cl_view.dart' show cl_weaponmodels;
import 'cl_lights.dart' show CL_SetLightstyle;
import 'cl_tempentities.dart' show CL_ParseTEnt;
import 'cl_effects.dart' show CL_AddMuzzleFlash, CL_AddMuzzleFlash2;
import 'cl_predict.dart' show CL_CheckPredictionError;
import 'cl_console.dart' show con;
import 'cl_screen.dart' show SCR_EndLoadingPlaque;
import 'cl_cin.dart' show SCR_PlayCinematic;

const svc_strings = [
	"svc_bad",

	"svc_muzzleflash",
	"svc_muzzlflash2",
	"svc_temp_entity",
	"svc_layout",
	"svc_inventory",

	"svc_nop",
	"svc_disconnect",
	"svc_reconnect",
	"svc_sound",
	"svc_print",
	"svc_stufftext",
	"svc_serverdata",
	"svc_configstring",
	"svc_spawnbaseline",
	"svc_centerprint",
	"svc_download",
	"svc_playerinfo",
	"svc_packetentities",
	"svc_deltapacketentities",
	"svc_frame"
];

/*
 * Returns the entity number and the header bits
 */
List<int> CL_ParseEntityBits(Readbuf msg) {

	var total = msg.ReadByte();

	if ((total & U_MOREBITS1) != 0) {
		final b = msg.ReadByte();
		total |= b << 8;
	}

	if ((total & U_MOREBITS2) != 0) {
		final b = msg.ReadByte();
		total |= b << 16;
	}

	if ((total & U_MOREBITS3) != 0) {
		final b = msg.ReadByte();
		total |= b << 24;
	}

  int number;
	if ((total & U_NUMBER16) != 0) {
		number = msg.ReadShort();
	} else {
		number = msg.ReadByte();
	}

	return [number, total];
}

/*
 * Can go from either a baseline or a previous packet_entity
 */
CL_ParseDelta(Readbuf msg, entity_state_t from, entity_state_t to, int number, int bits) {
	/* set everything to the state we are delta'ing from */
	to.copy(from);

  to.old_origin.setAll(0, from.origin);
	to.number = number;

	if ((bits & U_MODEL) != 0) {
		to.modelindex = msg.ReadByte();
	}

	if ((bits & U_MODEL2) != 0) {
		to.modelindex2 = msg.ReadByte();
	}

	if ((bits & U_MODEL3) != 0) {
		to.modelindex3 = msg.ReadByte();
	}

	if ((bits & U_MODEL4) != 0) {
		to.modelindex4 = msg.ReadByte();
	}

	if ((bits & U_FRAME8) != 0) {
		to.frame = msg.ReadByte();
	}

	if ((bits & U_FRAME16) != 0) {
		to.frame = msg.ReadShort();
	}

	/* used for laser colors */
	if ((bits & U_SKIN8) != 0 && (bits & U_SKIN16) != 0) {
		to.skinnum = msg.ReadLong();
	} else if ((bits & U_SKIN8) != 0) {
		to.skinnum = msg.ReadByte();
	} else if ((bits & U_SKIN16) != 0) {
		to.skinnum = msg.ReadShort();
	}

	if ((bits & (U_EFFECTS8 | U_EFFECTS16)) == (U_EFFECTS8 | U_EFFECTS16)) {
		to.effects = msg.ReadLong();
	} else if ((bits & U_EFFECTS8) != 0) {
		to.effects = msg.ReadByte();
	} else if ((bits & U_EFFECTS16) != 0) {
		to.effects = msg.ReadShort();
	}

	if ((bits & (U_RENDERFX8 | U_RENDERFX16)) == (U_RENDERFX8 | U_RENDERFX16)) {
		to.renderfx = msg.ReadLong();
	} else if ((bits & U_RENDERFX8) != 0) {
		to.renderfx = msg.ReadByte();
	} else if ((bits & U_RENDERFX16) != 0) {
		to.renderfx = msg.ReadShort();
	}

	if ((bits & U_ORIGIN1) != 0) {
		to.origin[0] = msg.ReadCoord();
	}

	if ((bits & U_ORIGIN2) != 0) {
		to.origin[1] = msg.ReadCoord();
	}

	if ((bits & U_ORIGIN3) != 0) {
		to.origin[2] = msg.ReadCoord();
	}

	if ((bits & U_ANGLE1) != 0) {
		to.angles[0] = msg.ReadAngle();
	}

	if ((bits & U_ANGLE2) != 0) {
		to.angles[1] = msg.ReadAngle();
	}

	if ((bits & U_ANGLE3) != 0) {
		to.angles[2] = msg.ReadAngle();
	}

	if ((bits & U_OLDORIGIN) != 0) {
		to.old_origin = msg.ReadPos();
	}

	if ((bits & U_SOUND) != 0) {
		to.sound = msg.ReadByte();
	}

	if ((bits & U_EVENT) != 0) {
		to.event = msg.ReadByte();
	} else {
		to.event = 0;
	}

	if ((bits & U_SOLID) != 0) {
		to.solid = msg.ReadShort();
	}
}

/*
 * Parses deltas from the given base and adds the resulting entity to
 * the current frame
 */
CL_DeltaEntity(Readbuf msg, frame_t frame, int newnum, entity_state_t old, int bits) {

	var ent = cl_entities[newnum];

	var state = cl_parse_entities[cl.parse_entities & (MAX_PARSE_ENTITIES - 1)];
	cl.parse_entities++;
	frame.num_entities++;

	CL_ParseDelta(msg, old, state, newnum, bits);

	/* some data changes will force no lerping */
	if ((state.modelindex != ent.current.modelindex) ||
		(state.modelindex2 != ent.current.modelindex2) ||
		(state.modelindex3 != ent.current.modelindex3) ||
		(state.modelindex4 != ent.current.modelindex4) ||
		(state.event == entity_event_t.EV_PLAYER_TELEPORT.index) ||
		(state.event == entity_event_t.EV_OTHER_TELEPORT.index) ||
		(((state.origin[0] - ent.current.origin[0]).toInt()).abs() > 512) ||
		(((state.origin[1] - ent.current.origin[1]).toInt()).abs() > 512) ||
		(((state.origin[2] - ent.current.origin[2]).toInt()).abs() > 512)
		)
	{
		ent.serverframe = -99;
	}

	/* wasn't in last update, so initialize some things */
	if (ent.serverframe != cl.frame.serverframe - 1)
	{
		ent.trailcount = 1024; /* for diminishing rocket / grenade trails */

		/* duplicate the current state so
		   lerping doesn't hurt anything */
		ent.prev.copy(state);

		if (state.event == entity_event_t.EV_OTHER_TELEPORT.index)
		{
      ent.prev.origin.setAll(0, state.origin);
      ent.lerp_origin.setAll(0, state.origin);
		}
		else
		{
      ent.prev.origin.setAll(0, state.old_origin);
      ent.lerp_origin.setAll(0, state.old_origin);
		}
	}
	else
	{
		/* shuffle the last state to previous */
		ent.prev.copy(ent.current);
	}

	ent.serverframe = cl.frame.serverframe;
	ent.current.copy(state);
}

/*
 * An svc_packetentities has just been
 * parsed, deal with the rest of the
 * data stream.
 */
CL_ParsePacketEntities(Readbuf msg, frame_t oldframe, frame_t newframe) {

	newframe.parse_entities = cl.parse_entities;
	newframe.num_entities = 0;

	/* delta from the entities present in oldframe */
	int oldindex = 0;
  int oldnum;
  entity_state_t oldstate;

	if (oldframe == null) {
		oldnum = 99999;
	} else {
		if (oldindex >= oldframe.num_entities) {
			oldnum = 99999;
		} else {
			oldstate = cl_parse_entities[(oldframe.parse_entities +
									oldindex) & (MAX_PARSE_ENTITIES - 1)];
			oldnum = oldstate.number;
		}
	}

	while (true)
	{
    final res = CL_ParseEntityBits(msg);
		int newnum = res[0];
		int bits = res[1];

		if (newnum >= MAX_EDICTS) {
			Com_Error(ERR_DROP, "CL_ParsePacketEntities: bad number:$newnum");
		}

		if (msg.readcount > msg.data.lengthInBytes) {
			Com_Error(ERR_DROP, "CL_ParsePacketEntities: end of message");
		}

		if (newnum == 0) {
			break;
		}

		while (oldnum < newnum) {
			/* one or more entities from the old packet are unchanged */
			if (cl_shownet.integer == 3) {
				Com_Printf("   unchanged: $oldnum\n");
			}

			CL_DeltaEntity(msg, newframe, oldnum, oldstate, 0);

			oldindex++;

			if (oldindex >= oldframe.num_entities) {
				oldnum = 99999;
			} else {
				oldstate = cl_parse_entities[(oldframe.parse_entities +
										oldindex) & (MAX_PARSE_ENTITIES - 1)];
				oldnum = oldstate.number;
			}
		}

		if ((bits & U_REMOVE) != 0) {
			/* the entity present in oldframe is not in the current frame */
			if (cl_shownet.integer == 3)
			{
				Com_Printf("   remove: $newnum\n");
			}

			if (oldnum != newnum)
			{
				Com_Printf("U_REMOVE: oldnum != newnum\n");
			}

			oldindex++;

			if (oldindex >= oldframe.num_entities)
			{
				oldnum = 99999;
			}

			else
			{
				oldstate = cl_parse_entities[(oldframe.parse_entities +
										oldindex) & (MAX_PARSE_ENTITIES - 1)];
				oldnum = oldstate.number;
			}

			continue;
		}

		if (oldnum == newnum) {
      
			/* delta from previous state */
			if (cl_shownet.integer == 3) {
				Com_Printf("   delta: $newnum\n");
			}

			CL_DeltaEntity(msg, newframe, newnum, oldstate, bits);

			oldindex++;

			if (oldindex >= oldframe.num_entities)
			{
				oldnum = 99999;
			}

			else
			{
				oldstate = cl_parse_entities[(oldframe.parse_entities +
										oldindex) & (MAX_PARSE_ENTITIES - 1)];
				oldnum = oldstate.number;
			}

			continue;
		}

		if (oldnum > newnum)
		{
			/* delta from baseline */
			if (cl_shownet.integer == 3)
			{
				Com_Printf("   baseline: $newnum\n");
			}

			CL_DeltaEntity(msg, newframe, newnum,
					cl_entities[newnum].baseline,
					bits);
			continue;
		}
	}

	/* any remaining entities in the old frame are copied over */
	while (oldnum != 99999)
	{
		/* one or more entities from the old packet are unchanged */
		if (cl_shownet.integer == 3)
		{
			Com_Printf("   unchanged: $oldnum\n");
		}

		CL_DeltaEntity(msg, newframe, oldnum, oldstate, 0);

		oldindex++;

		if (oldindex >= oldframe.num_entities)
		{
			oldnum = 99999;
		}

		else
		{
			oldstate = cl_parse_entities[(oldframe.parse_entities +
									oldindex) & (MAX_PARSE_ENTITIES - 1)];
			oldnum = oldstate.number;
		}
	}
}


CL_ParsePlayerstate(Readbuf msg, frame_t oldframe, frame_t newframe) {

	player_state_t state = newframe.playerstate;

	/* clear to old value before delta parsing */
	if (oldframe != null) {
		state.copy(oldframe.playerstate);
	} else {
		state.copy(player_state_t());
	}

	final flags = msg.ReadShort();

	/* parse the pmove_state_t */
	if ((flags & PS_M_TYPE) != 0) {
		state.pmove.pm_type = pmtype_t.values[msg.ReadByte()];
	}

	if ((flags & PS_M_ORIGIN) != 0) {
		state.pmove.origin[0] = msg.ReadShort();
		state.pmove.origin[1] = msg.ReadShort();
		state.pmove.origin[2] = msg.ReadShort();
	}

	if ((flags & PS_M_VELOCITY) != 0) {
		state.pmove.velocity[0] = msg.ReadShort();
		state.pmove.velocity[1] = msg.ReadShort();
		state.pmove.velocity[2] = msg.ReadShort();
	}

	if ((flags & PS_M_TIME) != 0) {
		state.pmove.pm_time = msg.ReadByte();
	}

	if ((flags & PS_M_FLAGS) != 0) {
		state.pmove.pm_flags = msg.ReadByte();
	}

	if ((flags & PS_M_GRAVITY) != 0) {
		state.pmove.gravity = msg.ReadShort();
	}

	if ((flags & PS_M_DELTA_ANGLES) != 0) {
		state.pmove.delta_angles[0] = msg.ReadShort();
		state.pmove.delta_angles[1] = msg.ReadShort();
		state.pmove.delta_angles[2] = msg.ReadShort();
	}

	if (cl.attractloop)
	{
		state.pmove.pm_type = pmtype_t.PM_FREEZE; /* demo playback */
	}

	/* parse the rest of the player_state_t */
	if ((flags & PS_VIEWOFFSET) != 0) {
		state.viewoffset[0] = msg.ReadChar() * 0.25;
		state.viewoffset[1] = msg.ReadChar() * 0.25;
		state.viewoffset[2] = msg.ReadChar() * 0.25;
	}

	if ((flags & PS_VIEWANGLES) != 0) {
		state.viewangles[0] = msg.ReadAngle16();
		state.viewangles[1] = msg.ReadAngle16();
		state.viewangles[2] = msg.ReadAngle16();
	}

	if ((flags & PS_KICKANGLES) != 0) {
		state.kick_angles[0] = msg.ReadChar() * 0.25;
		state.kick_angles[1] = msg.ReadChar() * 0.25;
		state.kick_angles[2] = msg.ReadChar() * 0.25;
	}

	if ((flags & PS_WEAPONINDEX) != 0) {
		state.gunindex = msg.ReadByte();
	}

	if ((flags & PS_WEAPONFRAME) != 0) {
		state.gunframe = msg.ReadByte();
		state.gunoffset[0] = msg.ReadChar() * 0.25;
		state.gunoffset[1] = msg.ReadChar() * 0.25;
		state.gunoffset[2] = msg.ReadChar() * 0.25;
		state.gunangles[0] = msg.ReadChar() * 0.25;
		state.gunangles[1] = msg.ReadChar() * 0.25;
		state.gunangles[2] = msg.ReadChar() * 0.25;
	}

	if ((flags & PS_BLEND) != 0) {
		state.blend[0] = msg.ReadByte() / 255.0;
		state.blend[1] = msg.ReadByte() / 255.0;
		state.blend[2] = msg.ReadByte() / 255.0;
		state.blend[3] = msg.ReadByte() / 255.0;
	}

	if ((flags & PS_FOV) != 0) {
		state.fov = msg.ReadByte().toDouble();
	}

	if ((flags & PS_RDFLAGS) != 0) {
		state.rdflags = msg.ReadByte();
	}

	/* parse stats */
	final statbits = msg.ReadLong();

	for (int i = 0; i < MAX_STATS; i++) {
		if ((statbits & (1 << i)) != 0) {
			state.stats[i] = msg.ReadShort();
		}
	}
}


CL_ParseFrame(Readbuf msg) {

	cl.frame = frame_t();

	cl.frame.serverframe = msg.ReadLong();
	cl.frame.deltaframe =  msg.ReadLong();
	cl.frame.servertime = cl.frame.serverframe * 100;

	/* BIG HACK to let old demos continue to work */
	if (cls.serverProtocol != 26) {
		cl.surpressCount = msg.ReadByte();
	}

	if (cl_shownet.integer == 3) {
		Com_Printf("   frame:${cl.frame.serverframe}  delta:${cl.frame.deltaframe}\n");
	}

	/* If the frame is delta compressed from data that we
	   no longer have available, we must suck up the rest of
	   the frame, but not use it, then ask for a non-compressed
	   message */
  frame_t old;
	if (cl.frame.deltaframe <= 0)
	{
		cl.frame.valid = true; /* uncompressed frame */
		old = null;
		// cls.demowaiting = false; /* we can start recording now */
	}
	else
	{
		old = cl.frames[cl.frame.deltaframe & UPDATE_MASK];

		if (old == null) {
			/* should never happen */
			Com_Printf("Delta from null frame (not supposed to happen!).\n");
    }

		if (!old.valid)
		{
			/* should never happen */
			Com_Printf("Delta from invalid frame (not supposed to happen!).\n");
		}

		if (old.serverframe != cl.frame.deltaframe)
		{
			/* The frame that the server did the delta from
			   is too old, so we can't reconstruct it properly. */
			Com_Printf("Delta frame too old.\n");
		}
		else if (cl.parse_entities - old.parse_entities > MAX_PARSE_ENTITIES - 128)
		{
			Com_Printf("Delta parse_entities too old.\n");
		}
		else
		{
			cl.frame.valid = true; /* valid delta parse */
		}
	}

	/* clamp time */
	if (cl.time > cl.frame.servertime)
	{
		cl.time = cl.frame.servertime;
	}

	else if (cl.time < cl.frame.servertime - 100)
	{
		cl.time = cl.frame.servertime - 100;
	}

	/* read areabits */
	final len = msg.ReadByte();
	cl.frame.areabits = msg.ReadData(len);

	/* read playerinfo */
	var cmd = msg.ReadByte();
	SHOWNET(svc_strings[cmd], msg);

	if (cmd != svc_ops_e.svc_playerinfo.index) {
		Com_Error(ERR_DROP, "CL_ParseFrame: 0x${cmd.toRadixString(16)} not playerinfo");
	}

	CL_ParsePlayerstate(msg, old, cl.frame);

	/* read packet entities */
	cmd = msg.ReadByte();
	SHOWNET(svc_strings[cmd], msg);

	if (cmd != svc_ops_e.svc_packetentities.index) {
		Com_Error(ERR_DROP, "CL_ParseFrame: 0x${cmd.toRadixString(16)} not packetentities");
	}

	CL_ParsePacketEntities(msg, old, cl.frame);

	/* save the frame off in the backup array for later delta comparisons */
	cl.frames[cl.frame.serverframe & UPDATE_MASK] = cl.frame;

	if (cl.frame.valid) {
		/* getting a valid frame message ends the connection process */
		if (cls.state != connstate_t.ca_active) {
			cls.state = connstate_t.ca_active;
			cl.force_refdef = true;
			cl.predicted_origin[0] = cl.frame.playerstate.pmove.origin[0] * 0.125;
			cl.predicted_origin[1] = cl.frame.playerstate.pmove.origin[1] * 0.125;
			cl.predicted_origin[2] = cl.frame.playerstate.pmove.origin[2] * 0.125;
      cl.predicted_angles.setAll(0, cl.frame.playerstate.viewangles);

			if ((cls.disable_servercount != cl.servercount) && cl.refresh_prepped) {
				SCR_EndLoadingPlaque();  /* get rid of loading plaque */
			}

			cl.sound_prepped = true;

			// if (paused_at_load)
			// {
			// 	if (cl_loadpaused->value == 1)
			// 	{
			// 		Cvar_Set("paused", "0");
			// 	}

			// 	paused_at_load = false;
			// }
		}

		/* fire entity events */
		// CL_FireEntityEvents(&cl.frame);

		if (!(!cl_predict.boolean ||
			  (cl.frame.playerstate.pmove.pm_flags & PMF_NO_PREDICTION) != 0)) {
			CL_CheckPredictionError();
		}
	}
}

CL_ParseServerData(Readbuf msg) async {

	Com_DPrintf("Serverdata packet received.\n");

	/* wipe the client_state_t struct */
	CL_ClearState();
	cls.state = connstate_t.ca_connected;

	/* parse protocol version number */
	cls.serverProtocol = msg.ReadLong();

	/* another demo hack */
	if (Com_ServerState() != 0 && (PROTOCOL_VERSION == 34)) {
	} else if (cls.serverProtocol != PROTOCOL_VERSION) {
		Com_Error(ERR_DROP, "Server returned version ${cls.serverProtocol}, not $PROTOCOL_VERSION");
	}

	cl.servercount = msg.ReadLong();
	cl.attractloop = msg.ReadByte() != 0;

	/* game directory */
	cl.gamedir = msg.ReadString();

	/* set gamedir */
	// if ((*str && (!fs_gamedirvar->string || !*fs_gamedirvar->string ||
	// 	  strcmp(fs_gamedirvar->string, str))) ||
	// 	(!*str && (fs_gamedirvar->string || *fs_gamedirvar->string)))
	// {
	// 	Cvar_Set("game", str);
	// }

	/* parse player entity number */
	cl.playernum = msg.ReadShort();

	/* get the full level name */
	final str = msg.ReadString();

	if (cl.playernum == -1) {
		/* playing a cinematic or showing a pic, not a level */
		await SCR_PlayCinematic(str);
	} else {
		/* seperate the printfs so the server
		 * message can have a color */
		// Com_Printf("\n\n\35\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\36\37\n\n");
		// Com_Printf("%c%s\n", 2, str);
    Com_Printf("$str\n");

		/* need to prep refresh at next oportunity */
		cl.refresh_prepped = false;
	}
}

CL_ParseBaseline(Readbuf msg) {
  final res = CL_ParseEntityBits(msg);
  final newnum = res[0];
  final bits = res[1];
	final es = cl_entities[newnum].baseline;
	CL_ParseDelta(msg, entity_state_t(), es, newnum, bits);
}

CL_LoadClientinfo(clientinfo_t ci, String s) async {

	ci.cinfo = s;

	/* isolate the player's name */
	// Q_strlcpy(ci->name, s, sizeof(ci->name));
  var t = s.indexOf('\\');
	if (t >= 0) {
		ci.name = s.substring(0, t);
	  s = s.substring(t + 1);
	} else {
    ci.name = s;
    s = "";
  }

	if (cl_noskins.boolean || s.isEmpty) {
	  ci.iconname = "/players/male/grunt_i.pcx";
		ci.model = await re.RegisterModel("players/male/tris.md2");
    ci.weaponmodel = [ await re.RegisterModel("players/male/weapon.md2") ];
		ci.skin = re.RegisterSkin("players/male/grunt.pcx");
		ci.icon = re.DrawFindPic(ci.iconname);
	} else {
		/* isolate the model and skin names */
		t = s.indexOf("/");
		if (t < 0) {
		t = s.indexOf("\\");
    }

    String model_name, skin_name;
		if (t < 0) {
			model_name = "";
      skin_name = s;
		} else {
			model_name = s.substring(0, t);
      skin_name = s.substring(t + 1);
    }


		/* model file */
	  var model_filename = "players/$model_name/tris.md2";
		ci.model = await re.RegisterModel(model_filename);

		if (ci.model == null) {
			model_name = "male";
	    model_filename = "players/male/tris.md2";
  		ci.model = await re.RegisterModel(model_filename);
		}

		/* skin file */
	  var skin_filename = "players/$model_name/$skin_name.pcx";
		ci.skin = await re.RegisterSkin(skin_filename);

		/* if we don't have the skin and the model wasn't male,
		 * see if the male has it (this is for CTF's skins) */
		if (ci.skin == null && model_name != "male") {
			/* change model to male */
			model_name = "male";
      model_filename = "players/male/tris.md2";
			ci.model = await re.RegisterModel(model_filename);

			/* see if the skin exists for the male model */
  	  skin_filename = "players/$model_name/$skin_name.pcx";
	  	ci.skin = await re.RegisterSkin(skin_filename);
		}

		/* if we still don't have a skin, it means that the male model didn't have
		 * it, so default to grunt */
		if (ci.skin == null) {
			/* see if the skin exists for the male model */
  	  skin_filename = "players/$model_name/grunt.pcx";
	  	ci.skin = await re.RegisterSkin(skin_filename);
		}

		/* weapon file */
    ci.weaponmodel = List(cl_weaponmodels.length);
		for (int i = 0; i < cl_weaponmodels.length; i++) {
      var weapon_filename = "players/$model_name/${cl_weaponmodels[i]}";
			ci.weaponmodel[i] = await re.RegisterModel(weapon_filename);

			if (ci.weaponmodel[i] == null && model_name == "cyborg") {
				/* try male */
				weapon_filename = "players/male/" + cl_weaponmodels[i];
  			ci.weaponmodel[i] = await re.RegisterModel(weapon_filename);
			}

			if (!cl_vwep.boolean) {
				break; /* only one when vwep is off */
			}
		}

		/* icon file */
	  ci.iconname = "/players/$model_name/${skin_name}_i.pcx";
		ci.icon = re.DrawFindPic(ci.iconname);
	}

	// /* must have loaded all data types to be valid */
	// if (!ci->skin || !ci->icon || !ci->model || !ci->weaponmodel[0])
	// {
	// 	ci->skin = NULL;
	// 	ci->icon = NULL;
	// 	ci->model = NULL;
	// 	ci->weaponmodel[0] = NULL;
	// 	return;
	// }
}

/*
 * Load the skin, icon, and model for a client
 */
CL_ParseClientinfo(int player) async {
	final s = cl.configstrings[player + CS_PLAYERSKINS];
	final ci = cl.clientinfo[player];
	CL_LoadClientinfo(ci, s);
}


CL_ParseConfigString(Readbuf msg) async {

	final i = msg.ReadShort();
	if ((i < 0) || (i >= MAX_CONFIGSTRINGS)) {
		Com_Error(ERR_DROP, "configstring > MAX_CONFIGSTRINGS $i ${i.toRadixString(16)}");
	}

	final s = msg.ReadString();
	// Q_strlcpy(olds, cl.configstrings[i], sizeof(olds));

	// length = strlen(s);
	// if (length > sizeof(cl.configstrings) - sizeof(cl.configstrings[0])*i - 1)
	// {
	// 	Com_Error(ERR_DROP, "CL_ParseConfigString: oversize configstring");
	// }

	cl.configstrings[i] = s;

	/* do something apropriate */
	if ((i >= CS_LIGHTS) && (i < CS_LIGHTS + MAX_LIGHTSTYLES)) {
		CL_SetLightstyle(i - CS_LIGHTS);
	}
	// else if (i == CS_CDTRACK)
	// {
	// 	if (cl.refresh_prepped)
	// 	{
	// 		OGG_PlayTrack((int)strtol(cl.configstrings[CS_CDTRACK], (char **)NULL, 10));
	// 	}
	// }
	else if ((i >= CS_MODELS) && (i < CS_MODELS + MAX_MODELS)) {
		if (cl.refresh_prepped) {
			cl.model_draw[i - CS_MODELS] = await re.RegisterModel(cl.configstrings[i]);

	// 		if (cl.configstrings[i][0] == '*')
	// 		{
	// 			cl.model_clip[i - CS_MODELS] = CM_InlineModel(cl.configstrings[i]);
	// 		}

	// 		else
	// 		{
	// 			cl.model_clip[i - CS_MODELS] = NULL;
	// 		}
		}
	}
	// else if ((i >= CS_SOUNDS) && (i < CS_SOUNDS + MAX_MODELS))
	// {
	// 	if (cl.refresh_prepped)
	// 	{
	// 		cl.sound_precache[i - CS_SOUNDS] =
	// 			S_RegisterSound(cl.configstrings[i]);
	// 	}
	// }
	// else if ((i >= CS_IMAGES) && (i < CS_IMAGES + MAX_MODELS))
	// {
	// 	if (cl.refresh_prepped)
	// 	{
	// 		cl.image_precache[i - CS_IMAGES] = Draw_FindPic(cl.configstrings[i]);
	// 	}
	// }
	// else if ((i >= CS_PLAYERSKINS) && (i < CS_PLAYERSKINS + MAX_CLIENTS))
	// {
	// 	if (cl.refresh_prepped && strcmp(olds, s))
	// 	{
	// 		CL_ParseClientinfo(i - CS_PLAYERSKINS);
	// 	}
	// }
}

CL_ParseStartSoundPacket(Readbuf msg) {

	final flags = msg.ReadByte();
	final sound_num = msg.ReadByte();

  double volume = DEFAULT_SOUND_PACKET_VOLUME;
	if ((flags & SND_VOLUME) != 0) {
		volume = msg.ReadByte() / 255.0;
	}

  double attenuation = DEFAULT_SOUND_PACKET_ATTENUATION;
	if ((flags & SND_ATTENUATION) != 0) {
		attenuation = msg.ReadByte() / 64.0;
	}

  double ofs = 0;
	if ((flags & SND_OFFSET) != 0) {
		ofs = msg.ReadByte() / 1000.0;
	}

  int channel = 0;
  int ent = 0;
	if ((flags & SND_ENT) != 0) {
		/* entity reletive */
		channel = msg.ReadShort();
		ent = channel >> 3;

		if (ent > MAX_EDICTS) {
			Com_Error(ERR_DROP, "CL_ParseStartSoundPacket: ent = $ent");
		}

		channel &= 7;
	}

  List<double> pos;
	if ((flags & SND_POS) != 0)
	{
		/* positioned in space */
		pos = msg.ReadPos();
	}

	// if (!cl.sound_precache[sound_num])
	// {
	// 	return;
	// }

	// S_StartSound(pos, ent, channel, cl.sound_precache[sound_num],
	// 		volume, attenuation, ofs);
}

SHOWNET(String s, Readbuf msg)
{
	if (cl_shownet.integer >= 2) {
		Com_Printf("${msg.readcount - 1}:$s\n");
	}
}

CL_ParseServerMessage(Readbuf msg) async {

	/* if recording demos, copy the message out */
	if (cl_shownet.integer == 1) {
		Com_Printf("${msg.data.lengthInBytes} ");
	}

	else if (cl_shownet.integer >= 2)
	{
		Com_Printf("------------------\n");
	}

	/* parse the message */
	while (true)
	{
		if (msg.readcount > msg.data.lengthInBytes) {
			Com_Error(ERR_DROP, "CL_ParseServerMessage: Bad server message");
			break;
		}

		final cmd = msg.ReadByte();

		if (cmd == -1)
		{
			SHOWNET("END OF MESSAGE", msg);
			break;
		}

		if (cl_shownet.integer >= 2)
		{
			if (cmd < 0 || cmd >= svc_strings.length) {
				Com_Printf("${msg.readcount - 1}:BAD CMD $cmd\n");
			} else {
				SHOWNET(svc_strings[cmd], msg);
			}
		}

		/* other commands */
		switch (svc_ops_e.values[cmd]) {
			case svc_ops_e.svc_nop:
				break;

			case svc_ops_e.svc_disconnect:
				Com_Error(ERR_DISCONNECT, "Server disconnected\n");
				break;

			// case svc_reconnect:
			// 	Com_Printf("Server disconnected, reconnecting\n");

			// 	if (cls.download)
			// 	{
			// 		/* close download */
			// 		fclose(cls.download);
			// 		cls.download = NULL;
			// 	}

			// 	cls.state = ca_connecting;
			// 	cls.connect_time = -99999; /* CL_CheckForResend() will fire immediately */
			// 	break;

			case svc_ops_e.svc_print:
				final i = msg.ReadByte();
				if (i == PRINT_CHAT) {
					// S_StartLocalSound("misc/talk.wav");
					con.ormask = 128;
				}

				Com_Printf(msg.ReadString());
				con.ormask = 0;
				break;

			// case svc_centerprint:
			// 	SCR_CenterPrint(MSG_ReadString(&net_message));
			// 	break;

			case svc_ops_e.svc_stufftext:
				final s = msg.ReadString();
				Com_DPrintf("stufftext: $s\n");
				Cbuf_AddText(s);
				break;

			case svc_ops_e.svc_serverdata:
				await Cbuf_Execute();  /* make sure any stuffed commands are done */
				await CL_ParseServerData(msg);
				break;

			case svc_ops_e.svc_configstring:
				await CL_ParseConfigString(msg);
				break;

			case svc_ops_e.svc_sound:
				CL_ParseStartSoundPacket(msg);
				break;

			case svc_ops_e.svc_spawnbaseline:
				CL_ParseBaseline(msg);
				break;

			case svc_ops_e.svc_temp_entity:
				CL_ParseTEnt(msg);
				break;

			case svc_ops_e.svc_muzzleflash:
				CL_AddMuzzleFlash(msg);
				break;

			case svc_ops_e.svc_muzzleflash2:
				CL_AddMuzzleFlash2(msg);
				break;

			// case svc_download:
			// 	CL_ParseDownload();
			// 	break;

			case svc_ops_e.svc_frame:
				CL_ParseFrame(msg);
				break;

			// case svc_inventory:
			// 	CL_ParseInventory();
			// 	break;

			case svc_ops_e.svc_layout:
				cl.layout = msg.ReadString();
				break;

			case svc_ops_e.svc_playerinfo:
			case svc_ops_e.svc_packetentities:
			case svc_ops_e.svc_deltapacketentities:
				Com_Error(ERR_DROP, "Out of place frame data");
				break;

			default:
				Com_Error(ERR_DROP, "CL_ParseServerMessage: Illegible server message\n");
				break;

		}
	}

	// CL_AddNetgraph();

	/* we don't know if it is ok to save a demo message
	   until after we have parsed the frame */
	// if (cls.demorecording && !cls.demowaiting)
	// {
	// 	CL_WriteDemoMessage();
	// }
}

