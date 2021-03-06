// =========================================================
//  Server side networked commands code, reworked by Samual
//  Last updated: December 28th, 2011
// =========================================================

float SV_ParseClientCommand_floodcheck()
{
	if (!timeout_status) // not while paused
	{
		if(time <= (self.cmd_floodtime + autocvar_sv_clientcommand_antispam_time))
		{
			self.cmd_floodcount += 1;
			if(self.cmd_floodcount > autocvar_sv_clientcommand_antispam_count) { return FALSE; } // too much spam, halt
		}
		else
		{
			self.cmd_floodtime = time;
			self.cmd_floodcount = 1;
		}
	}
	return TRUE; // continue, as we're not flooding yet
}


// =======================
//  Command Sub-Functions
// =======================

void ClientCommand_autoswitch(float request, float argc)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) != "")
			{
				self.autoswitch = InterpretBoolean(argv(1));
				sprint(self, strcat("^1autoswitch is currently turned ", (self.autoswitch ? "on" : "off"), ".\n"));
				return;
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2autoswitch^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd autoswitch selection\n");
			sprint(self, "  Where 'selection' controls if autoswitch is on or off.\n");
			return;
		}
	}
}

void ClientCommand_checkfail(float request, string command) // internal command, used only by code
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			printf("CHECKFAIL: %s (%s) epically failed check %s\n", self.netname, self.netaddress, substring(command, argv_start_index(1), argv_end_index(-1) - argv_start_index(1)));
			self.checkfail = 1;
			return; // never fall through to usage
		}

		default:
			sprint(self, "Incorrect parameters for ^2checkfail^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd checkfail <message>\n");
			sprint(self, "  Where 'message' is the message reported by client about the fail.\n");
			return;
		}
	}
}

void ClientCommand_clientversion(float request, float argc) // internal command, used only by code
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) != "")
			{
				if(IS_CLIENT(self))
				{
					self.version = ((argv(1) == "$gameversion") ? 1 : stof(argv(1)));

					if(self.version < autocvar_gameversion_min || self.version > autocvar_gameversion_max)
					{
						self.version_mismatch = 1;
						ClientKill_TeamChange(-2); // observe
					}
					else if(autocvar_g_campaign || autocvar_g_balance_teams)
					{
						//JoinBestTeam(self, FALSE, TRUE);
					}
					else if(teamplay && !autocvar_sv_spectate && !(self.team_forced > 0))
					{
						self.classname = "observer"; // really?
						stuffcmd(self, "menu_showteamselect\n");
					}
				}

				return;
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2clientversion^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd clientversion version\n");
			sprint(self, "  Where 'version' is the game version reported by self.\n");
			return;
		}
	}
}

void ClientCommand_mv_getpicture(float request, float argc) // internal command, used only by code
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) != "")
			{
				if(intermission_running)
					MapVote_SendPicture(stof(argv(1)));

				return;
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2mv_getpicture^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd mv_getpicture mapid\n");
			sprint(self, "  Where 'mapid' is the id number of the map to request an image of on the map vote selection menu.\n");
			return;
		}
	}
}

void ClientCommand_join(float request)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(IS_CLIENT(self))
			{
				if(!IS_PLAYER(self) && !lockteams && !gameover)
				{
					if(self.caplayer)
						return;
					if(nJoinAllowed(self))
					{
						if(autocvar_g_campaign) { campaign_bots_may_start = 1; }

						self.classname = "player";
						nades_RemoveBonus(self);
						PlayerScore_Clear(self);
						Kill_Notification(NOTIF_ONE_ONLY, self, MSG_CENTER_CPID, CPID_PREVENT_JOIN);
						Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_JOIN_PLAY, self.netname);
						PutClientInServer();
					}
					else
					{
						//player may not join because of g_maxplayers is set
						Send_Notification(NOTIF_ONE_ONLY, self, MSG_CENTER, CENTER_JOIN_PREVENT);
					}
				}
			}
			return; // never fall through to usage
		}

		default:
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd join\n");
			sprint(self, "  No arguments required.\n");
			return;
		}
	}
}

void ClientCommand_physics(float request, float argc)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			string command = strtolower(argv(1));

			if(command == "list" || command == "help")
			{
				sprint(self, strcat("Available physics sets: \n\n", autocvar_g_physics_clientselect_options, " default\n"));
				if(!autocvar_g_physics_clientselect)
					sprint(self, "These are unusable currently, as client physics selection is disabled\n");
				return;
			}

			if(Physics_Valid(command) || command == "default")
			{
				stuffcmd(self, strcat("\nseta cl_physics ", command, "\nsendcvar cl_physics\n"));

				if(!autocvar_g_physics_clientselect)
					sprint(self, strcat("Physics set to ^3", command, "^7, but will not be used since client physics selection is disabled\n"));
				else
					sprint(self, strcat("^2Physics set successfully changed to ^3", command, "\n"));
				return;
			}

			if(!autocvar_g_physics_clientselect)
			{
				sprint(self, "Client physics selection is currently disabled.\n");
				return;
			}


		}
	
		default:
			sprint(self, strcat("Current physics set: ^3", self.cvar_cl_physics, "\n"));
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd physics <physics>\n");
			sprint(self, "  See 'cmd physics list' for available physics sets.\n");
			sprint(self, "  Argument 'default' resets to standard physics.\n");
			return;
		}
	}
}

void ClientCommand_ready(float request) // todo: anti-spam for toggling readyness
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(IS_CLIENT(self))
			{
				if(warmup_stage || autocvar_sv_ready_restart || g_race_qualifying == 2)
				{
					if(!readyrestart_happened || autocvar_sv_ready_restart_repeatable)
					{
						if(time < game_starttime) // game is already restarting
							return;
						if (self.ready) // toggle
						{
							self.ready = FALSE;
							bprint(self.netname, "^2 is ^1NOT^2 ready\n");
						}
						else
						{
							self.ready = TRUE;
							bprint(self.netname, "^2 is ready\n");
						}

						// cannot reset the game while a timeout is active!
						if (!timeout_status)
							ReadyCount();
					} else {
						sprint(self, "^1Game has already been restarted\n");
					}
				}
			}
			return; // never fall through to usage
		}

		default:
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd ready\n");
			sprint(self, "  No arguments required.\n");
			return;
		}
	}
}

void ClientCommand_report(float request, float argc) 
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) == "fps")
			if(sv_showfps)
			if(IS_PLAYER(self))
			if(self.scorekeeper)
				PlayerScore_Set(self, SP_FPS, stof(argv(2)));

			if(argv(1) == "fov")
			{
				self.clientfov = stof(argv(2));
				ClientData_Touch(self);
			}

			return; // never fall through to usage
		}

		default:
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd report [fps fov]\n");
			sprint(self, "  Where 'fps' is your scoreboard frames per second.\n");
			sprint(self, "  Where 'fov' is your current field of view.\n");
			return;
		}
	}
}

void ClientCommand_say(float request, float argc, string command)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argc >= 2) { Say(self, FALSE, world, substring(command, argv_start_index(1), argv_end_index(-1) - argv_start_index(1)), 1); }
			return; // never fall through to usage
		}

		default:
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd say <message>\n");
			sprint(self, "  Where 'message' is the string of text to say.\n");
			return;
		}
	}
}

void ClientCommand_say_team(float request, float argc, string command)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argc >= 2) { Say(self, TRUE, world, substring(command, argv_start_index(1), argv_end_index(-1) - argv_start_index(1)), 1); }
			return; // never fall through to usage
		}

		default:
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd say_team <message>\n");
			sprint(self, "  Where 'message' is the string of text to say.\n");
			return;
		}
	}
}

void ClientCommand_selectteam(float request, float argc)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) != "")
			{
				if(IS_CLIENT(self))
				{
					if(teamplay)
						if(self.team_forced <= 0)
							if (!lockteams)
							{
								float selection;

								switch(argv(1))
								{
									case "red": selection = NUM_TEAM_1; break;
									case "blue": selection = NUM_TEAM_2; break;
									case "yellow": selection = NUM_TEAM_3; break;
									case "pink": selection = NUM_TEAM_4; break;
									case "auto": selection = (-1); break;

									default: selection = 0; break;
								}

								if(selection)
								{
									if(self.team == selection && self.deadflag == DEAD_NO)
										sprint(self, "^7You already are on that team.\n");
									else if(self.wasplayer && autocvar_g_changeteam_banned)
										sprint(self, "^1You cannot change team, forbidden by the server.\n");
									else
									{
										if(autocvar_g_balance_teams && autocvar_g_balance_teams_prevent_imbalance)
										{
											CheckAllowedTeams(self);
											GetTeamCounts(self);
											if(!TeamSmallerEqThanTeam(Team_TeamToNumber(selection), Team_TeamToNumber(self.team), self))
											{
												Send_Notification(NOTIF_ONE, self, MSG_INFO, INFO_TEAMCHANGE_LARGERTEAM);
												return;
											}
										}
										ClientKill_TeamChange(selection);
									}
								}
							}
							else
								sprint(self, "^7The game has already begun, you must wait until the next map to be able to join a team.\n");
						else
							sprint(self, "^7selectteam can not be used as your team is forced\n");
					else
						sprint(self, "^7selectteam can only be used in teamgames\n");
				}
				return;
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2selectteam^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd selectteam team\n");
			sprint(self, "  Where 'team' is the prefered team to try and join.\n");
			sprint(self, "  Full list of options here: \"red, blue, yellow, pink, auto\"\n");
			return;
		}
	}
}

void ClientCommand_selfstuff(float request, string command)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) != "")
			{
				stuffcmd(self, substring(command, argv_start_index(1), argv_end_index(-1) - argv_start_index(1)));
				return;
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2selectteam^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd selfstuff <command>\n");
			sprint(self, "  Where 'command' is the string to be stuffed to your client.\n");
			return;
		}
	}
}

void ClientCommand_sentcvar(float request, float argc, string command)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) != "")
			{
				//float tokens;
				string s;

				if(argc == 2) // undefined cvar: use the default value on the server then
				{
					s = strcat(substring(command, argv_start_index(0), argv_end_index(1) - argv_start_index(0)), " \"", cvar_defstring(argv(1)), "\"");
					tokenize_console(s);
				}

				GetCvars(1);

				return;
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2sentcvar^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd sentcvar <cvar>\n");
			sprint(self, "  Where 'cvar' is the cvar plus arguments to send to the server.\n");
			return;
		}
	}
}

void ClientCommand_spectate(float request)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(IS_CLIENT(self))
			{
				if(g_lms)
				{
					if(self.lms_spectate_warning)
					{
						// for the forfeit message...
						self.lms_spectate_warning = 2;
						// mark player as spectator
						PlayerScore_Add(self, SP_LMS_RANK, 666 - PlayerScore_Add(self, SP_LMS_RANK, 0));
					}
					else
					{
						self.lms_spectate_warning = 1;
						sprint(self, "WARNING: you won't be able to enter the game again after spectating in LMS. Use the same command again to spectate anyway.\n");
						return;
					}
				}

				if((IS_PLAYER(self) || self.caplayer) && autocvar_sv_spectate == 1)
				{
					if(self.caplayer && (IS_SPEC(self) || IS_OBSERVER(self)))
						Send_Notification(NOTIF_ONE_ONLY, self, MSG_INFO, INFO_CA_LEAVE);
					ClientKill_TeamChange(-2); // observe
				}
			}
			return; // never fall through to usage
		}

		default:
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd spectate\n");
			sprint(self, "  No arguments required.\n");
			return;
		}
	}
}

void ClientCommand_suggestmap(float request, float argc)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) != "")
			{
				sprint(self, strcat(MapVote_Suggest(argv(1)), "\n"));
				return;
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2suggestmap^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd suggestmap map\n");
			sprint(self, "  Where 'map' is the name of the map to suggest.\n");
			return;
		}
	}
}

void ClientCommand_tell(float request, float argc, string command)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argc >= 3)
			{
				entity tell_to = GetIndexedEntity(argc, 1);
				float tell_accepted = VerifyClientEntity(tell_to, TRUE, FALSE);

				if(tell_accepted > 0) // the target is a real client
				{
					if(tell_to != self) // and we're allowed to send to them :D
					{
						Say(self, FALSE, tell_to, substring(command, argv_start_index(next_token), argv_end_index(-1) - argv_start_index(next_token)), TRUE);
						return;
					}
					else { print_to(self, "You can't ^2tell^7 a message to yourself."); return; }
				}
				else if(argv(1) == "#0")
				{
					trigger_magicear_processmessage_forallears(self, -1, world, substring(command, argv_start_index(next_token), argv_end_index(-1) - argv_start_index(next_token)));
					return;
				}
				else { print_to(self, strcat("tell: ", GetClientErrorString(tell_accepted, argv(1)), ".")); return; }
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2tell^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd tell client <message>\n");
			sprint(self, "  Where 'client' is the entity number or name of the player to send 'message' to.\n");
			return;
		}
	}
}

void ClientCommand_voice(float request, float argc, string command)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			if(argv(1) != "")
			{
				if(argc >= 3)
					VoiceMessage(argv(1), substring(command, argv_start_index(2), argv_end_index(-1) - argv_start_index(2)));
				else
					VoiceMessage(argv(1), "");

				return;
			}
		}

		default:
			sprint(self, "Incorrect parameters for ^2voice^7\n");
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd voice messagetype <soundname>\n");
			sprint(self, "  'messagetype' is the type of broadcast to do, like team only or such,\n");
			sprint(self, "  and 'soundname' is the string/filename of the sound/voice message to play.\n");
			return;
		}
	}
}

/* use this when creating a new command, making sure to place it in alphabetical order... also,
** ADD ALL NEW COMMANDS TO commands.cfg WITH PROPER ALIASES IN THE SAME FASHION!
void ClientCommand_(float request)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{

			return; // never fall through to usage
		}

		default:
		case CMD_REQUEST_USAGE:
		{
			sprint(self, "\nUsage:^3 cmd \n");
			sprint(self, "  No arguments required.\n");
			return;
		}
	}
}
*/


// =====================================
//  Macro system for networked commands
// =====================================

// Do not hard code aliases for these, instead create them in commands.cfg... also: keep in alphabetical order, please ;)
#define CLIENT_COMMANDS(request,arguments,command) \
	CLIENT_COMMAND("autoswitch", ClientCommand_autoswitch(request, arguments), "Whether or not to switch automatically when getting a better weapon") \
	CLIENT_COMMAND("checkfail", ClientCommand_checkfail(request, command), "Report if a client-side check failed") \
	CLIENT_COMMAND("clientversion", ClientCommand_clientversion(request, arguments), "Release version of the game") \
	CLIENT_COMMAND("mv_getpicture", ClientCommand_mv_getpicture(request, arguments), "Retrieve mapshot picture from the server") \
	CLIENT_COMMAND("join", ClientCommand_join(request), "Become a player in the game") \
	CLIENT_COMMAND("physics", ClientCommand_physics(request, arguments), "Change physics set") \
	CLIENT_COMMAND("ready", ClientCommand_ready(request), "Qualify as ready to end warmup stage (or restart server if allowed)") \
	CLIENT_COMMAND("report", ClientCommand_report(request, arguments), "Retrieve values from the client") \
	CLIENT_COMMAND("say", ClientCommand_say(request, arguments, command), "Print a message to chat to all players") \
	CLIENT_COMMAND("say_team", ClientCommand_say_team(request, arguments, command), "Print a message to chat to all team mates") \
	CLIENT_COMMAND("selectteam", ClientCommand_selectteam(request, arguments), "Attempt to choose a team to join into") \
	CLIENT_COMMAND("selfstuff", ClientCommand_selfstuff(request, command), "Stuffcmd a command to your own client") \
	CLIENT_COMMAND("sentcvar", ClientCommand_sentcvar(request, arguments, command), "New system for sending a client cvar to the server") \
	CLIENT_COMMAND("spectate", ClientCommand_spectate(request), "Become an observer") \
	CLIENT_COMMAND("suggestmap", ClientCommand_suggestmap(request, arguments), "Suggest a map to the mapvote at match end") \
	CLIENT_COMMAND("tell", ClientCommand_tell(request, arguments, command), "Send a message directly to a player") \
	CLIENT_COMMAND("voice", ClientCommand_voice(request, arguments, command), "Send voice message via sound") \
	CLIENT_COMMAND("minigame", ClientCommand_minigame(request, arguments, command), "Start a minigame") \
	/* nothing */

void ClientCommand_macro_help()
{
	#define CLIENT_COMMAND(name,function,description) \
		{ sprint(self, "  ^2", name, "^7: ", description, "\n"); }

	CLIENT_COMMANDS(0, 0, "")
	#undef CLIENT_COMMAND

	return;
}

float ClientCommand_macro_command(float argc, string command)
{
	#define CLIENT_COMMAND(name,function,description) \
		{ if(name == strtolower(argv(0))) { function; return TRUE; } }

	CLIENT_COMMANDS(CMD_REQUEST_COMMAND, argc, command)
	#undef CLIENT_COMMAND

	return FALSE;
}

float ClientCommand_macro_usage(float argc)
{
	#define CLIENT_COMMAND(name,function,description) \
		{ if(name == strtolower(argv(1))) { function; return TRUE; } }

	CLIENT_COMMANDS(CMD_REQUEST_USAGE, argc, "")
	#undef CLIENT_COMMAND

	return FALSE;
}

void ClientCommand_macro_write_aliases(float fh)
{
	#define CLIENT_COMMAND(name,function,description) \
		{ CMD_Write_Alias("qc_cmd_cmd", name, description); }

	CLIENT_COMMANDS(0, 0, "")
	#undef CLIENT_COMMAND

	return;
}

// ======================================
//  Main Function Called By Engine (cmd)
// ======================================
// If this function exists, server game code parses clientcommand before the engine code gets it.

void SV_ParseClientCommand(string command)
{
	// if we're banned, don't even parse the command
	if(Ban_MaybeEnforceBanOnce(self))
		return;

	float argc = tokenize_console(command);

	// for the mutator hook system
	cmd_name = strtolower(argv(0));
	cmd_argc = argc;
	cmd_string = command;

	// Guide for working with argc arguments by example:
	// argc:   1    - 2      - 3     - 4
	// argv:   0    - 1      - 2     - 3
	// cmd     vote - master - login - password

	// for floodcheck
	switch(strtolower(argv(0)))
	{
		// exempt commands which are not subject to floodcheck
		case "begin": break; // handled by engine in host_cmd.c
		case "download": break; // handled by engine in cl_parse.c
		case "mv_getpicture": break; // handled by server in this file
		case "pause": break; // handled by engine in host_cmd.c
		case "prespawn": break; // handled by engine in host_cmd.c
		case "sentcvar": break; // handled by server in this file
		case "spawn": break; // handled by engine in host_cmd.c

		default:
			if(SV_ParseClientCommand_floodcheck())
				break; // "TRUE": continue, as we're not flooding yet
			else
				return; // "FALSE": not allowed to continue, halt // print("^1ERROR: ^7ANTISPAM CAUGHT: ", command, ".\n");
	}

	/* NOTE: should this be disabled? It can be spammy perhaps, but hopefully it's okay for now */
	if(argv(0) == "help")
	{
		if(argc == 1)
		{
			sprint(self, "\nClient networked commands:\n");
			ClientCommand_macro_help();

			sprint(self, "\nCommon networked commands:\n");
			CommonCommand_macro_help(self);

			sprint(self, "\nUsage:^3 cmd COMMAND...^7, where possible commands are listed above.\n");
			sprint(self, "For help about a specific command, type cmd help COMMAND\n");
			return;
		}
		else if(CommonCommand_macro_usage(argc, self)) // Instead of trying to call a command, we're going to see detailed information about it
		{
			return;
		}
		else if(ClientCommand_macro_usage(argc)) // same, but for normal commands now
		{
			return;
		}
	}
	else if(MUTATOR_CALLHOOK(SV_ParseClientCommand))
	{
		return; // handled by a mutator
	}
	else if(CheatCommand(argc))
	{
		return; // handled by server/cheats.qc
	}
	else if(CommonCommand_macro_command(argc, self, command))
	{
		return; // handled by server/command/common.qc
	}
	else if(ClientCommand_macro_command(argc, command)) // continue as usual and scan for normal commands
	{
		return; // handled by one of the above ClientCommand_* functions
	}
	else
		clientcommand(self, command);
}
