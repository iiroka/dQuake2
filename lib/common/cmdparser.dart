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
 * This file implements the Quake II command processor. Every command
 * which is send via the command line at startup, via the console and
 * via rcon is processed here and send to the apropriate subsystem.
 *
 * =======================================================================
 */
import '../client/cl_network.dart' show Cmd_ForwardToServer;
import '../shared/shared.dart';
import 'clientserver.dart';
import 'cvar.dart';
import 'filesystem.dart';

const ALIAS_LOOP_COUNT = 16;

typedef xcommand_t = Function(List<String>);
class xcommandHolder {
  final xcommand_t func;
  xcommandHolder(this.func);
}

bool cmd_wait = false;
String cmd_text = "";
String defer_text_buf = "";
int alias_count = 0;
var cmd_functions = Map<String, xcommandHolder>();
var cmd_alias = Map<String, String>();

void Cmd_Wait_f(List<String> args) async {
  cmd_wait = true;
}


Cbuf_Init() {
	cmd_text = "";
}

/*
 * Adds command text at the end of the buffer
 */
Cbuf_AddText(String text) {
  cmd_text += text;
}

/*
 * Adds command text immediately after the current command
 * Adds a \n to the text
 */
Cbuf_InsertText(String text) {
  cmd_text = text + '\n' + cmd_text;
}

Cbuf_CopyToDefer() {
	defer_text_buf = cmd_text;
	cmd_text = "";
}

Cbuf_InsertFromDefer() {
	Cbuf_InsertText(defer_text_buf);
	defer_text_buf = "";
}

Cbuf_Execute() async {

	alias_count = 0; /* don't allow infinite alias loops */

	while (cmd_text.isNotEmpty) {
		/* find a \n or ; line break */
		int quotes = 0;
    int i;
		for (i = 0; i < cmd_text.length; i++) {
			if (cmd_text[i] == '"') {
				quotes++;
			}

			if ((quotes & 1) == 0 && (cmd_text[i] == ';')) {
				break; /* don't break if inside a quoted string */
			}

			if (cmd_text[i] == '\n') {
				break;
			}
		}

		/* delete the text from the command buffer and move remaining
		   commands down this is necessary because commands (exec,
		   alias) can insert data at the beginning of the text buffer */
    String line;
		if (i >= cmd_text.length) {
      line = cmd_text;
			cmd_text = "";
		} else {
      line = cmd_text.substring(0, i);
      cmd_text = cmd_text.substring(i + 1);
		}

		/* execute the command line */
		await Cmd_ExecuteString(line);

		if (cmd_wait) {
			/* skip out while text still remains in buffer,
			   leaving it for next frame */
			cmd_wait = false;
			break;
		}
	}
}

void Cmd_Exec_f(List<String> args) async {

	if (args.length != 2) {
		Com_Printf("exec <filename> : execute a script file\n");
		return;
	}

	var buf = await FS_LoadFile(args[1]);
	if (buf == null) {
		Com_Printf("couldn't exec ${args[1]}\n");
		return;
	}

	Com_Printf("execing ${args[1]}\n");
	Cbuf_InsertText(String.fromCharCodes(buf.asInt8List()));
}

/*
 * Just prints the rest of the line to the console
 */
void Cmd_Echo_f(List<String> args) async {

	for (int i = 1; i < args.length; i++) {
		Com_Printf("${args[i]} ");
	}

	Com_Printf("\n");
}

/*
 * Creates a new command that executes
 * a command string (possibly ; seperated)
 */
void Cmd_Alias_f(List<String> args) async {

	if (args.length == 1) {
		Com_Printf("Current alias commands:\n");
    cmd_alias.forEach((k, v) => Com_Printf("$k : $v\n"));
		return;
	}

	/* copy the rest of the command line */
	var cmd = StringBuffer(); /* start out with a null string */

	for (int i = 2; i < args.length; i++) {
		cmd.write(args[i]);

		if (i != (args.length - 1)) {
			cmd.write(" ");
		}
	}

	cmd.write("\n");

	cmd_alias[args[1].toLowerCase()] = cmd.toString();
}


/*
 * Parses the given string into command line tokens.
 * $Cvars will be expanded unless they are in a quoted token
 */
List<String> Cmd_TokenizeString(String text, bool macroExpand) {

	var cmd_args = List<String>();

	/* macro expand the text */
	// if (macroExpand) {
	// 	text = Cmd_MacroExpandString(text);
	// }

	if (text == null) {
		return cmd_args;
	}

  int index = 0;
	while (index < text.length) {
		/* skip whitespace up to a /n */
		while (index < text.length && text.codeUnitAt(index) <= 32 && text[index] != '\n') {
			index++;
		}

		if (index >= text.length || text[index] == '\n') {
			/* a newline seperates commands in the buffer */
			break;
		}

		/* set cmd_args to everything after the first arg */
		// if (cmd_argc == 1)
		// {
		// 	int l;

		// 	strcpy(cmd_args, text);

		// 	/* strip off any trailing whitespace */
		// 	l = strlen(cmd_args) - 1;

		// 	for ( ; l >= 0; l--)
		// 	{
		// 		if (cmd_args[l] <= ' ')
		// 		{
		// 			cmd_args[l] = 0;
		// 		}

		// 		else
		// 		{
		// 			break;
		// 		}
		// 	}
		// }

		var res = COM_Parse(text, index);
		if (res == null) {
			return cmd_args;
		}
    index = res.index;
    cmd_args.add(res.token);

	}
  return cmd_args;
}

Cmd_AddCommand(String cmd_name, xcommand_t function) {
	// cmd_function_t *cmd;
	// cmd_function_t **pos;

	/* fail if the command is a variable name */
	// if (Cvar_VariableString(cmd_name)[0])
	// {
	// 	Cmd_RemoveCommand(cmd_name);
	// }

	// /* fail if the command already exists */
	// for (cmd = cmd_functions; cmd; cmd = cmd->next)
	// {
	// 	if (!strcmp(cmd_name, cmd->name))
	// 	{
	// 		Com_Printf("Cmd_AddCommand: %s already defined\n", cmd_name);
	// 		return;
	// 	}
	// }

	// cmd = Z_Malloc(sizeof(cmd_function_t));
	// cmd->name = cmd_name;
	// cmd->function = function;

	/* link the command in */
  cmd_functions[cmd_name.toLowerCase()] = xcommandHolder(function);
}

/*
 * A complete command line has been parsed, so try to execute it
 */
Cmd_ExecuteString(String text) async {
// 	cmd_function_t *cmd;
// 	cmdalias_t *a;

	var args = Cmd_TokenizeString(text, true);

	/* execute the command line */
	if (args.isEmpty) {
		return; /* no tokens */
	}

// 	if(Cmd_Argc() > 1 && Q_strcasecmp(cmd_argv[0], "exec") == 0 && Q_strcasecmp(cmd_argv[1], "yq2.cfg") == 0)
// 	{
// 		/* exec yq2.cfg is done directly after exec default.cfg, see Qcommon_Init() */
// 		doneWithDefaultCfg = true;
// 	}

	/* check functions */
  var cmd = cmd_functions[args[0].toLowerCase()];
  if (cmd != null) {
    if (cmd.func == null) {
      /* forward to server command */
      await Cmd_ExecuteString("cmd $text");
    } else {
      await cmd.func(args);
    }
    return;
	}

	/* check alias */
  var a = cmd_alias[args[0].toLowerCase()];
  if (a != null) {
    if (++alias_count >= ALIAS_LOOP_COUNT) {
      Com_Printf("ALIAS_LOOP_COUNT\n");
      return;
    }
    Cbuf_InsertText(a);
    return;
  }


	/* check cvars */
	if (Cvar_Command(args)) {
		return;
	}

  print("Unknown command ${args[0]}");

	/* send it as a server command if we are connected */
	Cmd_ForwardToServer(args);
}

Cmd_Init()
{
	/* register our commands */
	// Cmd_AddCommand("cmdlist", Cmd_List_f);
	Cmd_AddCommand("exec", Cmd_Exec_f);
	Cmd_AddCommand("echo", Cmd_Echo_f);
	Cmd_AddCommand("alias", Cmd_Alias_f);
	Cmd_AddCommand("wait", Cmd_Wait_f);
}
