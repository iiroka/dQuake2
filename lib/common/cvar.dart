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
 * The Quake II CVAR subsystem. Implements dynamic variable handling.
 *
 * =======================================================================
 */
import './clientserver.dart';
import './cmdparser.dart';

const CVAR_ARCHIVE = 1;     /* set to cause it to be saved to vars.rc */
const CVAR_USERINFO = 2;    /* added to userinfo  when changed */
const CVAR_SERVERINFO = 4;  /* added to serverinfo when changed */
const CVAR_NOSET = 8;       /* don't allow change from console at all, */
							/* but can be set from the command line */
const CVAR_LATCH = 16;      /* save changes until server restart */

/* nothing outside the Cvar_*() functions should modify these fields! */
class cvar_t {
	String name;
	String string;
	String latched_string; /* for CVAR_LATCH vars */
	int flags;
	bool modified; /* set each time the cvar is changed */
	/* Added by YQ2. Must be at the end to preserve ABI. */
	String default_string;

  cvar_t(String name, String value, int flags) {
    this.name = name;
    this.string = value;
    this.flags = flags;
    this.modified = true;
    this.default_string = value;
    this.latched_string = null;
  }

  bool get boolean {
    try {
      final val = double.parse(this.string);
      return val != 0.0;
    } catch (e) {
      return false;
    }
  }

  double get value {
    try {
      return double.parse(this.string);
    } catch (e) {
      return 0.0;
    }
  }

  int get integer {
    try {
      final val = double.parse(this.string);
      return val.toInt();
    } catch (e) {
      return 0;
    }
  }
}

var cvar_vars = Map<String, cvar_t>();
var userinfo_modified = false;

bool Cvar_InfoValidate(String s) {
	if (s.contains("\\")) {
		return false;
	}

	if (s.contains("\""))
	{
		return false;
	}

	if (s.contains(";"))
	{
		return false;
	}

	return true;
}

cvar_t Cvar_FindVar(String var_name) {
	// cvar_t *var;
	// int i;

	/* An ugly hack to rewrite changed CVARs */
	// for (i = 0; i < sizeof(replacements) / sizeof(replacement_t); i++)
	// {
	// 	if (!strcmp(var_name, replacements[i].old))
	// 	{
	// 		Com_Printf("cvar %s ist deprecated, use %s instead\n", replacements[i].old, replacements[i].new);

	// 		var_name = replacements[i].new;
	// 	}
	// }

	// for (var = cvar_vars; var; var = var->next)
	// {
	// 	if (!strcmp(var_name, var->name))
	// 	{
	// 		return var;
	// 	}
	// }

	return cvar_vars[var_name];
}

double Cvar_VariableValue(String var_name) {
	final cvar = Cvar_FindVar(var_name);
	if (cvar == null) {
		return 0;
	}
	return cvar.value;
}

bool Cvar_VariableBool(String var_name) {
	final cvar = Cvar_FindVar(var_name);
	if (cvar == null) {
		return false;
	}
	return cvar.boolean;
}

int Cvar_VariableInt(String var_name) {
	final cvar = Cvar_FindVar(var_name);
	if (cvar == null) {
		return 0;
	}
	return cvar.integer;
}

String Cvar_VariableString(String var_name) {
	final cvar = Cvar_FindVar(var_name);
	if (cvar == null) {
		return "";
	}
	return cvar.string;
}


/*
 * If the variable already exists, the value will not be set
 * The flags will be or'ed in if the variable exists.
 */
cvar_t Cvar_Get(String var_name, String var_value, int flags) {
	// cvar_t *var;
	// cvar_t **pos;

	if ((flags & (CVAR_USERINFO | CVAR_SERVERINFO)) != 0)
	{
		if (!Cvar_InfoValidate(var_name)) {
			Com_Printf("invalid info cvar name\n");
			return null;
		}
	}

	var cvar = Cvar_FindVar(var_name);
	if (cvar != null) {
		cvar.flags |= flags;
		cvar.default_string = var_value;
		return cvar;
	}

	if (var_value == null)
	{
		return null;
	}

	if ((flags & (CVAR_USERINFO | CVAR_SERVERINFO)) != 0)
	{
		if (!Cvar_InfoValidate(var_value))
		{
			Com_Printf("invalid info cvar value\n");
			return null;
		}
	}

	// if $game is the default one ("baseq2"), then use "" instead because
	// other code assumes this behavior (e.g. FS_BuildGameSpecificSearchPath())
	// if(strcmp(var_name, "game") == 0 && strcmp(var_value, BASEDIRNAME) == 0)
	// {
	// 	var_value = "";
	// }

	cvar = cvar_t(var_name, var_value, flags);
  cvar_vars[var_name] = cvar;
	return cvar;
}

cvar_t Cvar_Set2(String var_name, String value, bool force) {

	var cvar = Cvar_FindVar(var_name);

	if (cvar == null) {
		return Cvar_Get(var_name, value, 0);
	}

	if ((cvar.flags & (CVAR_USERINFO | CVAR_SERVERINFO)) != 0) {
		if (!Cvar_InfoValidate(value)) {
			Com_Printf("invalid info cvar value\n");
			return cvar;
		}
	}

	// if $game is the default one ("baseq2"), then use "" instead because
	// other code assumes this behavior (e.g. FS_BuildGameSpecificSearchPath())
	// if(strcmp(var_name, "game") == 0 && strcmp(value, BASEDIRNAME) == 0)
	// {
	// 	value = "";
	// }

	if (!force) {
		if ((cvar.flags & CVAR_NOSET) != 0) {
			Com_Printf("$var_name is write protected.\n");
			return cvar;
		}

		if ((cvar.flags & CVAR_LATCH) != 0) {
			if (cvar.latched_string != null)
			{
				if (value == cvar.latched_string) {
					return cvar;
				}

				cvar.latched_string = null;
			}
			else
			{
				if (value == cvar.string) {
					return cvar;
				}
			}

			// if (Com_ServerState()) {
			// 	Com_Printf("$var_name will be changed for next game.\n");
			// 	cvar.latched_string = CopyString(value);
			// }
			// else
			{
				cvar.string = value;
				// cvar.value = (float)strtod(var->string, (char **)NULL);

				// if (!strcmp(var->name, "game"))
				// {
				// 	FS_BuildGameSpecificSearchPath(var->string);
				// }
			}

			return cvar;
		}
	}
	else
	{
    cvar.latched_string = null;
	}

	if (value == cvar.string) {
		return cvar;
	}

	cvar.modified = true;

	if ((cvar.flags & CVAR_USERINFO) != 0) {
		userinfo_modified = true;
	}

	cvar.string = value;

	return cvar;
}

cvar_t Cvar_ForceSet(String var_name, String value) => Cvar_Set2(var_name, value, true);

cvar_t Cvar_Set(String var_name, String value) =>Cvar_Set2(var_name, value, false);

cvar_t Cvar_FullSet(String var_name, String value, int flags) {

	var cvar = Cvar_FindVar(var_name);

	if (cvar == null) {
		return Cvar_Get(var_name, value, flags);
	}

	cvar.modified = true;

	if ((cvar.flags & CVAR_USERINFO) != 0) {
		userinfo_modified = true;
	}

	// if $game is the default one ("baseq2"), then use "" instead because
	// other code assumes this behavior (e.g. FS_BuildGameSpecificSearchPath())
	// if(strcmp(var_name, "game") == 0 && strcmp(value, BASEDIRNAME) == 0)
	// {
	// 	value = "";
	// }

	// Z_Free(var->string);

	cvar.string = value;
	// var->value = (float)strtod(var->string, (char **)NULL);

	cvar.flags = flags;

	return cvar;
}

/*
 * Handles variable inspection and changing from the console
 */
bool Cvar_Command(List<String> args) {

	/* check variables */
	var v = Cvar_FindVar(args[0]);
	if (v == null) {
		return false;
	}

	/* perform a variable print or set */
	if (args.length == 1) {
		Com_Printf("\"${v.name}\" is \"${v.string}\"\n");
		return true;
	}

	/* Another evil hack: The user has just changed 'game' trough
	   the console. We reset userGivenGame to that value, otherwise
	   we would revert to the initialy given game at disconnect. */
	// if (strcmp(v->name, "game") == 0)
	// {
	// 	Q_strlcpy(userGivenGame, Cmd_Argv(1), sizeof(userGivenGame));
	// }

	Cvar_Set(v.name, args[1]);
	return true;
}

/*
 * Allows setting and defining of arbitrary cvars from console
 */
void Cvar_Set_f(List<String> args) async  {
	// char *firstarg;
	// int c, flags, i;

	// c = Cmd_Argc();

	if ((args.length != 3) && (args.length != 4)) {
		Com_Printf("usage: set <variable> <value> [u / s]\n");
		return;
	}

	var firstarg = args[1];

	/* An ugly hack to rewrite changed CVARs */
	// for (i = 0; i < sizeof(replacements) / sizeof(replacement_t); i++)
	// {
	// 	if (!strcmp(firstarg, replacements[i].old))
	// 	{
	// 		firstarg = replacements[i].new;
	// 	}
	// }

	if (args.length == 4) {
    int flags;
		if (args[3] == "u") {
			flags = CVAR_USERINFO;
		}

		else if (args[3] == "s") {
			flags = CVAR_SERVERINFO;
		}

		else {
			Com_Printf("flags can only be 'u' or 's'\n");
			return;
		}

		Cvar_FullSet(firstarg, args[2], flags);
	}
	else
	{
		Cvar_Set(firstarg, args[2]);
	}
}

String Cvar_BitInfo(int bit) {
  var info = "";

  cvar_vars.forEach((key, cvar) => {
		if ((cvar.flags & bit) != 0) {
      info += "\\" + key + "\\" + cvar.string
		}
  });
	return info;
}

String Cvar_Userinfo() => Cvar_BitInfo(CVAR_USERINFO);

/*
 * Reads in all archived cvars
 */
Cvar_Init() {
	// Cmd_AddCommand("cvarlist", Cvar_List_f);
	// Cmd_AddCommand("dec", Cvar_Inc_f);
	// Cmd_AddCommand("inc", Cvar_Inc_f);
	// Cmd_AddCommand("reset", Cvar_Reset_f);
	// Cmd_AddCommand("resetall", Cvar_ResetAll_f);
	Cmd_AddCommand("set", Cvar_Set_f);
	// Cmd_AddCommand("toggle", Cvar_Toggle_f);
}
