const g_fStatCount = 12;				// when adding more stats change this constant
enum Stats {
	version,
	points,
	killcount,
	meleekills,
	missiondecims,
	distancetravelled,
	reloadfail,
	top1,
	top2,
	top3,
	wrequals,
	points_nohit_nfngl
}

function OnGameEvent_player_say( params )
{	
	local text = params["text"];
	local argv = split( text, " " );
	local argc = argv.len();

	if ( !argc )
		return;

	if ( argv[0].tolower() != "/r" && argv[0].tolower() != "/r_admin" )
	{
		if ( !g_bIsMapspawn )
			return;

		local file_messagelog = CleanList( split( FileToString( "r_messagelog" ), "|" ) );

		if ( GetPlayerFromUserID( params["userid"] ) )
			file_messagelog.push( FilterName( GetPlayerFromUserID( params["userid"] ).GetPlayerName() ) );
		else // was a console message
			file_messagelog.push( "Console" );
		
		file_messagelog.push( FilterName( text ) );

		WriteFile( "r_messagelog", file_messagelog, "|", 2, "" );
		
		return;
	}

	if ( !GetPlayerFromUserID( params["userid"] ) )
	{
		printl( "\nJust in case i made it that console cant run chat commands.. :(\n" );
		return;
	}
	
	local caller_steam_id = GetPlayerFromUserID( params["userid"] ).GetNetworkIDString().slice( 10 );
	
	if ( argv[0].tolower() == "/r_admin" )
	{
		local bIsAdmin = false;

		local admin_list = CleanList( split( FileToString( "r_adminlist" ), "|" ) );
		for ( local i = 0; i < admin_list.len(); ++i )
			if ( admin_list[i] == caller_steam_id )
				bIsAdmin = true;
		
		if ( !bIsAdmin )
		{
			PrintToChat( "Admin command tried being executed by non-admin" );
			return;
		}

		if ( argc == 3 )
		{
			switch ( argv[1].tolower() )
			{
				case "rebuild_all_leaderboards":
				{
					if ( argv[2].tolower() == "relaxed" )
					{
						maps_info <- CleanList( split( FileToString( "r_rs_mapratings" ), "|" ) );

						if ( maps_info.len() == 0 )
							return;

						maps_info.remove( 0 );	// remove the comment

						if ( !ValidArray( maps_info, 4 ) )
						{
							LogError( COLOR_RED + "Internal ERROR: MapSpawn: maps_info array has invalid length = " + maps_info.len().tostring(), argv[2] );
							return;
						}
						
						local delay_per_map = 0.02;	// bypass SQQuerySuspend
						PrintToChat( "Process will take " + ( maps_info.len() * delay_per_map / 4.0 ).tostring() + " seconds, please do not interrupt the process." );
						for ( local i = 0; i < maps_info.len(); i += 4 )
							DelayCodeExecution( "::BuildLeaderboard( \"rs\", maps_info[" + i.tostring() + "], maps_info[" + i.tostring() + "+2].tointeger(), maps_info[" + i.tostring() + "+3].tointeger() )", ( delay_per_map * i / 4.0 ), "worldspawn" );

						// we cant really figure out if the process was successfull or not
						DelayCodeExecution( "::PrintToChat( COLOR_GREEN + \"Process ended.\" )", ( maps_info.len() * delay_per_map / 4.0 ), "worldspawn" );
					}
					else if ( argv[2].tolower() == "hardcore" )
					{
						maps_info <- CleanList( split( FileToString( "r_hs_mapratings" ), "|" ) );

						if ( maps_info.len() == 0 )
							return;

						maps_info.remove( 0 );	// remove the comment

						if ( !ValidArray( maps_info, 4 ) )
						{
							LogError( COLOR_RED + "Internal ERROR: MapSpawn: maps_info array has invalid length = " + maps_info.len().tostring(), argv[2] );
							return;
						}

						local delay_per_map = 0.02;	// bypass SQQuerySuspend
						PrintToChat( "Process will take " + ( maps_info.len() * delay_per_map / 4.0 ).tostring() + " seconds, please do not interrupt the process." );
						for ( local i = 0; i < maps_info.len(); i += 4 )
							DelayCodeExecution( "::BuildLeaderboard( \"hs\", maps_info[" + i.tostring() + "], maps_info[" + i.tostring() + "+2].tointeger(), maps_info[" + i.tostring() + "+3].tointeger() )", ( delay_per_map * i / 4.0 ), "worldspawn" );

						// we cant really figure out if the process was successfull or not
						DelayCodeExecution( "::PrintToChat( COLOR_GREEN + \"Process ended.\" )", ( maps_info.len() * delay_per_map / 4.0 ), "worldspawn" );
					}
					else 
					{
						PrintToChat( "Expected argument 2 to be relaxed or hardcore" );
					}

					return;
				}
				case "read":
				{
					switch ( argv[2].tolower() )
					{
						case "feedback":
						{
							local feedback_list = CleanList( split( FileToString( "r_feedback" ), "|" ) );
							local feedback_count = feedback_list.len();

							if ( feedback_count == 0 )
							{
								PrintToChat( "No feedback." );
								return;
							}

							for ( local i = 0; i < feedback_count; ++i )
								PrintToChat( feedback_list[i] );

							break;
						}
						case "errorlog":
						{
							local error_list = CleanList( split( FileToString( "r_errorlog" ), "|" ) );
							local error_count = error_list.len();

							if ( error_count == 0 )
							{
								PrintToChat( "No errors." );
								return;
							}

							for ( local i = 0; i < error_count; ++i )
								PrintToChat( error_list[i] );

							break;
						}
					}

					return;
				}
				case "clear":
				{
					switch ( argv[2].tolower() )
					{
						case "feedback":
						{
							WriteFile( "r_feedback", [], "|", 1, "" );
							PrintToChat( COLOR_GREEN + "Feedback cleared." );
							break;
						}
						case "errorlog":
						{
							WriteFile( "r_errorlog", [], "|", 1, "" );
							PrintToChat( COLOR_GREEN + "Error log cleared." );
							break;
						}
					}

					return;
				}
				case "dumprawfile":
				{
					local file_array = split( FileToString( argv[2] ), (10).tochar() );
					local file_length = file_array.len();

					if ( file_length == 0 )
						PrintToChat( COLOR_YELLOW + "No such file: " + COLOR_RED + argv[2] );

					for ( local i = 0; i < file_length; ++i )
					{
						PrintToChat( COLOR_BLUE + i.tostring() + ": " + COLOR_LIGHTBLUE + file_array[i] );
					}

					return;
				}
			}
		}

		if ( argv[1].tolower() == "setdates" )
		{
			if ( argv[2].tolower() == "relaxed" )
			{
				maps_info <- CleanList( split( FileToString( "r_rs_mapratings" ), "|" ) );

				if ( maps_info.len() == 0 )
					return;

				maps_info.remove( 0 );	// remove the comment

				if ( !ValidArray( maps_info, 4 ) )
				{
					LogError( COLOR_RED + "Internal ERROR: MapSpawn: maps_info array has invalid length = " + maps_info.len().tostring(), argv[2] );
					return;
				}
				
				local delay_per_map = 0.02;	// bypass SQQuerySuspend
				PrintToChat( "Process will take " + ( maps_info.len() * delay_per_map / 4.0 ).tostring() + " seconds, please do not interrupt the process." );
				for ( local i = 0; i < maps_info.len(); i += 4 )
					DelayCodeExecution( "::AddDate( \"rs\", maps_info[" + i.tostring() + "], \"20220727\")", ( delay_per_map * i / 4.0 ), "worldspawn" );

				// we cant really figure out if the process was successfull or not
				DelayCodeExecution( "::PrintToChat( COLOR_GREEN + \"Process ended.\" )", ( maps_info.len() * delay_per_map / 4.0 ), "worldspawn" );
			}
			else if ( argv[2].tolower() == "hardcore" )
			{
				maps_info <- CleanList( split( FileToString( "r_hs_mapratings" ), "|" ) );

				if ( maps_info.len() == 0 )
					return;

				maps_info.remove( 0 );	// remove the comment

				if ( !ValidArray( maps_info, 4 ) )
				{
					LogError( COLOR_RED + "Internal ERROR: MapSpawn: maps_info array has invalid length = " + maps_info.len().tostring(), argv[2] );
					return;
				}

				local delay_per_map = 0.02;	// bypass SQQuerySuspend
				PrintToChat( "Process will take " + ( maps_info.len() * delay_per_map / 4.0 ).tostring() + " seconds, please do not interrupt the process." );
				for ( local i = 0; i < maps_info.len(); i += 4 )
					DelayCodeExecution( "::AddDate( \"hs\", maps_info[" + i.tostring() + "], \"20220727\")", ( delay_per_map * i / 4.0 ), "worldspawn" );

				// we cant really figure out if the process was successfull or not
				DelayCodeExecution( "::PrintToChat( COLOR_GREEN + \"Process ended.\" )", ( maps_info.len() * delay_per_map / 4.0 ), "worldspawn" );
			}
		}

		if ( argv[1].tolower() == "run_code" )
		{
			local command = "";
			
			for ( local i = 2; i < argc; ++i )
				command += argv[i] + " ";
				
			DoEntFire( "worldspawn", "runscriptcode", command, 0, null, null );
			PrintToChat( "Ran command - " + command );
			return;
		}

		if ( argv[1].tolower() == "edit_file_line" || argv[1].tolower() == "efl" )
		{
			if ( argc < 5 )
				PrintToChat( "Not enough arguments." );

			local file_array = split( FileToString( argv[2] ), (10).tochar() );
			local file_length = file_array.len();
			local line_number = argv[4].tointeger();
			local _string = "";

			if ( file_length == 0 )
			{
				PrintToChat( COLOR_YELLOW + "No such file: " + COLOR_RED + argv[2] );
				return;
			}

			file_array.pop();	// pop eof 
			file_length--;

			for ( local i = 5; i < argc; ++i )
				_string += argv[i] + " ";

			switch ( argv[3].tolower() )
			{
				case "remove":
				{
					if ( line_number >= file_length )
					{
						PrintToChat( "Removing the last line." );

						local _file_array = [];

						for ( local i = 0; i < file_length - 1; ++i )
							_file_array.push( file_array[i] );

						file_array = _file_array;
					}
					else
					{
						// remove method doesnt remove it correctly, just leaves the value in that index as blank
						//file_array.remove( line_number );

						// remove it correctly by making a new array
						local _file_array = [];

						for ( local i = 0; i < file_length - 1; ++i )
						{
							if ( i >= line_number )
								_file_array.push( file_array[i + 1] );
							else
								_file_array.push( file_array[i] );
						}

						file_array = _file_array;
					}

					break;
				}
				case "insert":
				{
					if ( line_number > file_length )
					{
						PrintToChat( "Specified line number is bigger than number of lines in the file. Inserting the string as the last line." );
						file_array.push( _string );
						break;
					}

					file_array.insert( line_number, _string );

					break;
				}
				case "edit":
				{
					if ( line_number > file_length )
					{
						PrintToChat( COLOR_RED + "UNABLE TO EDIT: " + COLOR_YELLOW + "Specified line number is bigger than number of lines in the file." );
						return;
					}

					file_array[ line_number ] = _string;

					break;
				}
			}

			file_array = CleanList( file_array, false );
			WriteFile( argv[2], file_array, "", 1, "" );
			PrintToChat( COLOR_GREEN + "Edited file successfully." );

			return;
		}

		PrintToChat( "Unrecognised admin command" );
		return;
	}

	if ( argc == 2 )
	{
		switch( argv[1].tolower() )
		{
			case "help":
			{
				PrintToChat( COLOR_BLUE + "List of commands:" );
				PrintToChat( COLOR_GREEN + "- /r profile " + COLOR_YELLOW + "[name/steamid]" + COLOR_RED + " [relaxed/hardcore]" + COLOR_YELLOW + " [general/points/nf+ngl/nohit]" );
				PrintToChat( COLOR_GREEN + "- /r leaderboard" + COLOR_RED + " [relaxed/hardcore]" + COLOR_YELLOW + " [mapname/nf+ngl/nohit/points]" + COLOR_RED + " [close/top/full]" );
				PrintToChat( COLOR_GREEN + "- /r feedback " + COLOR_YELLOW + "[message]" + COLOR_BLUE + " - writes feedback for admins to read" );
				PrintToChat( COLOR_GREEN + "- /r maplist" + COLOR_BLUE + " - prints a list of all supported maps" );
				PrintToChat( COLOR_GREEN + "- /r leaderboard" + COLOR_BLUE + " - prints current map's and challenge's leaderboard" );
				PrintToChat( COLOR_GREEN + "- /r leaderboard_statistic" + COLOR_YELLOW + "[1-10]" );
				PrintToChat( COLOR_GREEN + "- /r points" + COLOR_BLUE + " - prints current challenge's points leaderboard" );
				PrintToChat( COLOR_GREEN + "- /r profile" + COLOR_BLUE + " - prints your current challenge's general profile" );
				PrintToChat( COLOR_GREEN + "- /r welcome " + COLOR_YELLOW + "[yes/no]" + COLOR_BLUE + " - disable/enable welcome message for yourself" );
				return;
			}
			case "adminhelp":
			{
				PrintToChat( COLOR_BLUE + "List of " + COLOR_RED + "ADMIN" + COLOR_BLUE + " commands:" );
				PrintToChat( COLOR_GREEN + "- /r_admin dumprawfile " + COLOR_YELLOW + "|file name|" );
				PrintToChat( COLOR_GREEN + "- /r_admin edit_file_line " + COLOR_YELLOW + "|file name|" + COLOR_RED + " [insert/remove/edit] " + COLOR_YELLOW + "|line number|" + " |string|" + COLOR_BLUE + " - USE CAREFULLY" );
				PrintToChat( COLOR_GREEN + "- /r_admin rebuild_all_leaderboards " + COLOR_YELLOW + "[relaxed/hardcore]" + COLOR_BLUE + " - USE CAREFULLY" );
				PrintToChat( COLOR_GREEN + "- /r_admin " + COLOR_YELLOW + "[read/clear]" + COLOR_RED + " [feedback/errorlog]" );
				return;
			}
			case "maplist":
			{
				local map_list = CleanList( split( FileToString( "r_maplist" ), "|" ) );

				if ( map_list.len() == 0 || !ValidArray( map_list, 2 ) )
				{
					LogError( "Internal ERROR: map_list has invalid length = " + map_list.len() );
					return;
				}

				PrintToChat( "Full list of supported maps:" );
				for ( local i = 0; i < map_list.len(); i += 2 )
				{
					local color1 = COLOR_GREEN;
					local color2 = COLOR_BLUE;
					local spaces = "";

					if ( map_list[i] == "=" )
					{
						color1 = COLOR_YELLOW;
						color2 = COLOR_YELLOW;
						spaces = " ";
					}
					else
					{
						for ( local j = 0; j < 7 - map_list[i].len(); ++j )
							spaces += " ";
					}

					PrintToChat( color1 + map_list[i] + spaces + color2 + "= " + map_list[i+1] );
				}
				return;
			}
			case "points":
			{
				local mode = "";
				if ( Convars.GetStr( "rd_challenge" ) == "R_RS" ) mode = "RELAXED";
				else if ( Convars.GetStr( "rd_challenge" ) == "R_HS" ) mode = "HARDCORE";
				else return;
				
				argv.push( "" );
				argv.push( "" );
				argv.push( "" );

				argv[1] = "leaderboard";
				argv[2] = mode;
				argv[3] = "points";
				argv[4] = "full";

				argc = 5;
				break;
			}
			case "profile":
			{
				local mode = "";
				if ( Convars.GetStr( "rd_challenge" ) == "R_RS" ) mode = "RELAXED";
				else if ( Convars.GetStr( "rd_challenge" ) == "R_HS" ) mode = "HARDCORE";
				else return;
				
				argv.push( "" );
				argv.push( "" );
				argv.push( "" );

				argv[1] = "profile";
				argv[2] = caller_steam_id;
				argv[3] = mode;
				argv[4] = "general";

				argc = 5;
				break;
			}
			case "leaderboard":
			{
				if ( Convars.GetStr( "rd_challenge" ) == "R_RS" ) argv.push( "RELAXED" );
				else if ( Convars.GetStr( "rd_challenge" ) == "R_HS" ) argv.push( "HARDCORE" );
				else return;
				
				argv.push( g_strCurMap );
				argv.push( "full" );
				
				argc = 5;
				break;
			}
		}
	}

	if ( argc == 3 )
	{
		switch ( argv[1].tolower() )
		{
			case "leaderboard_statistic":
			{
				local number = argv[2].tofloat();
				local prefix_short = "";
				if ( Convars.GetStr( "rd_challenge" ) == "R_RS" ) prefix_short = "rs";
				else if ( Convars.GetStr( "rd_challenge" ) == "R_HS" ) prefix_short = "hs";
				else return;

				if ( number < 1 || number > 10 )	// sanity check
				{
					PrintToChat( "Expected argument 2 to be a number between 1-10" );
					return;
				}

				local str_names = ["Total Points", "Points from nohit/nf+ngl maps", "Alien kills", "Alien kills by melee", "Hours spent in mission", "Total kilometers ran",
									"Average meters ran per minute", "Fast reload fails", "Total times got 1st, 2nd, 3rd", "Number of Pace to WR 00:00.00"];

				PrintToChat( COLOR_GREEN + str_names[ number - 1 ] + COLOR_YELLOW + " leaderboard on " + ( prefix_short == "hs" ? ( COLOR_RED + "HARDCORE" ) : ( COLOR_GREEN + "RELAXED" ) ) + COLOR_YELLOW + ":" );

				if ( number == 2 ) number = 11;
				else if ( number > 2 && number < 7 ) number -= 1;
				else if ( number == 7 ) number = 0;
				else if ( number == 8 ) number = 6;

				local leaderboard = [];
				foreach( steamid, playername in g_tPlayerList )
				{
					local profile = CleanList( split( FileToString( "r_" + prefix_short + "_profile_" + steamid + "_general" ), "|" ) );
					if ( profile.len() == 0 )
						continue;

					if ( ( number == 11 || number == 10 ) && profile[0].tointeger() <3 )
						continue;

					leaderboard.push( playername );

					local output = profile[ number ].tofloat();
					if ( number == 4 ) output = TruncateFloat( ( output / 36000.0 ), 2 );
					if ( number == 5 ) output = output / 10000.0;
					if ( number == 0 ) output = TruncateFloat( ( 60 * ( ( 1.0 * profile[ Stats.distancetravelled ].tointeger() ) / ( 1.0 * profile[ Stats.missiondecims ].tointeger() ) ) ), 2 );
					if ( number == 9 ) output = profile[ Stats.top1 ].tointeger() * 1280 * 1280 + profile[ Stats.top2 ].tointeger() * 1280 + profile[ Stats.top3 ].tointeger(); 

					leaderboard.push( output );
				}

				SortArray2( leaderboard );

				if ( number == 9 )
					for ( local i = 0; i < leaderboard.len(); i += 2 )
						leaderboard[i + 1] = ( leaderboard[i + 1] / 1280 / 1280 ).tointeger().tostring() + ", " + ( leaderboard[i + 1] / 1280 % 1280 ).tointeger().tostring() + ", " + ( leaderboard[i + 1] % 1280 ).tointeger().tostring();

				local end_index = leaderboard.len() / 2 < 10 ? leaderboard.len() : 20;

				for ( local i = 0; i < end_index; i += 2 )
				{
					local spaces = "";
					for ( local j = 0; j < 15 - leaderboard[i].len(); ++j )
						spaces += " ";
					
					if ( caller_steam_id == GetKeyFromValue( g_tPlayerList, leaderboard[i] ) )
						PrintToChat( COLOR_BLUE + (i / 2 + 1).tostring() + ": " + ( ( i / 2 + 1 ) == 10 ? "" : " " ) + COLOR_GREEN + leaderboard[i] + COLOR_BLUE + spaces + " - " + COLOR_GREEN + leaderboard[i+1].tostring() );
					else
						PrintToChat( COLOR_BLUE + (i / 2 + 1).tostring() + ": " + ( ( i / 2 + 1 ) == 10 ? "" : " " ) + leaderboard[i] + spaces + " - " + COLOR_GREEN + leaderboard[i+1].tostring() );
				}
			}
		}

		return;
	}

	if ( argv[1].tolower() == "feedback" )
	{
		local message = "";
	
		for ( local i = 2; i < argc; ++i )
			message += argv[i] + " ";

		message = FilterName( COLOR_PURPLE + GetPlayerFromUserID( params["userid"] ).GetPlayerName() + COLOR_YELLOW + ": " + message );

		local feedback_list = CleanList( split( FileToString( "r_feedback" ), "|" ) );
		feedback_list.push( message );

		WriteFile( "r_feedback", feedback_list, "|", 1, "" );

		PrintToChat( COLOR_GREEN + "Feedback sent." );

		return;
	}

	if ( argc == 4 && argv[1] == "leaderboard" )
	{
		argv.push( "full" );
		argc = 5;
	}

	if ( argv[1] == "welcome" )
	{
		if ( argc == 2 )
		{
			PrintToChat( "Expected a yes or no." );
			return;
		}

		if ( argv[2] == "no" )
		{
			local notwelcome_list = CleanList( split( FileToString( "r_notwelcome" ), "|" ) );
			
			// if already not welcome, dont add to list
			foreach( index, _player in notwelcome_list )
			{
				if ( _player == caller_steam_id )
				{
					PrintToChat( COLOR_PURPLE + "Welcome message was already " + COLOR_RED + "disabled" + COLOR_PURPLE + "." );
					return;
				}
			}
			
			notwelcome_list.push( caller_steam_id );
			WriteFile( "r_notwelcome", notwelcome_list, "|", 1, "" );
			PrintToChat( COLOR_PURPLE + "Welcome message " + COLOR_RED + "disabled" + COLOR_PURPLE + "." );
			return;
		}

		if ( argv[2] == "yes" )
		{
			local notwelcome_list = CleanList( split( FileToString( "r_notwelcome" ), "|" ) );
			
			foreach( index, _player in notwelcome_list )
			{
				if ( _player == caller_steam_id )
				{
					notwelcome_list.remove( index );
					break;
				}
			}

			WriteFile( "r_notwelcome", notwelcome_list, "|", 1, "" );
			PrintToChat( COLOR_PURPLE + "Welcome message " + COLOR_GREEN + "enabled" + COLOR_PURPLE + "." );
			return;
		}

		PrintToChat( "Expected a yes or no." );
		return;
	}
	
	BuildPlayerList();

	if ( argc == 5 )
	{
		switch( argv[1].tolower() )
		{
			case "profile":
			{
				local prefix = argv[3].toupper();
				local prefix_short = "";
				local id = argv[2];
				local type = argv[4];

				if ( prefix == "RELAXED" ) prefix_short = "rs";
				if ( prefix == "HARDCORE" ) prefix_short = "hs";

				if ( prefix_short == "" )
				{
					PrintToChat( "Expected argument 3 to either be \"relaxed\" or \"hardcore\"" );
					return;
				}
				
				local player_profile = CleanList( split( FileToString( "r_" + prefix_short + "_profile_" + id + "_" + type ), "|" ) );
				local profile_length = player_profile.len();

				if ( profile_length == 0 )
				{	
					if ( GetKeyFromValue( g_tPlayerList, id ) )	// GetKeyFromValue( g_tPlayerList, "jhheight" ) == "108718913"
					{
						player_profile = CleanList( split( FileToString( "r_" + prefix_short + "_profile_" + GetKeyFromValue( g_tPlayerList, id ) + "_" + type ), "|" ) );
						profile_length = player_profile.len();

						if ( profile_length == 0 )
						{
							PrintToChat( "No such profile found - player exists but profile doesnt" );
							return;
						}
					}
					else
					{
						PrintToChat( "No such profile found - player doesnt exist" );
						return;
					}
				}
				// yay we found a profile
				if ( type == "general" )
				{
					// fixup for version 1 of profile
					if ( player_profile[ Stats.version ].tointeger() == 1 )
					{
						player_profile.push( "0" );
						player_profile.push( CalculatePlayersChallengePoints( ( g_tPlayerList.rawin( id ) ? id : GetKeyFromValue( g_tPlayerList, id ) ), prefix_short ) );
						profile_length += 2;
					}
					
					if ( player_profile[ Stats.version ].tointeger() == 2 )
					{
						player_profile.push( CalculatePlayersChallengePoints( ( g_tPlayerList.rawin( id ) ? id : GetKeyFromValue( g_tPlayerList, id ) ), prefix_short ) );
						profile_length++;
					}

					if ( profile_length == g_fStatCount )
					{
						PrintToChat( COLOR_GREEN + ( g_tPlayerList.rawin( id ) ? g_tPlayerList[id] : id ) + COLOR_YELLOW + "'s general stats on " + ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + ":" );
						PrintToChat( COLOR_PURPLE + "Total Points                  = " + COLOR_GREEN + TruncateFloat( player_profile[ Stats.points ].tofloat(), 1 ).tostring() );
						PrintToChat( COLOR_BLUE + "Points from nohit/nf+ngl maps = " + COLOR_GREEN + player_profile[ Stats.points_nohit_nfngl ] );
						PrintToChat( COLOR_BLUE + "Alien kills                   = " + COLOR_GREEN + player_profile[ Stats.killcount ] );
						PrintToChat( COLOR_BLUE + "Alien kills by melee          = " + COLOR_GREEN + player_profile[ Stats.meleekills ] );
						PrintToChat( COLOR_BLUE + "Hours spent in mission        = " + COLOR_GREEN + TruncateFloat( ( player_profile[ Stats.missiondecims ].tointeger() / 36000.0 ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Total kilometers ran          = " + COLOR_GREEN + TruncateFloat( ( player_profile[ Stats.distancetravelled ].tointeger() / 10000.0 ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Average meters ran per minute = " + COLOR_GREEN + TruncateFloat( ( 60 * ( ( 1.0 * player_profile[ Stats.distancetravelled ].tointeger() ) / ( 1.0 * player_profile[ Stats.missiondecims ].tointeger() ) ) ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Fast reload fails             = " + COLOR_GREEN + player_profile[ Stats.reloadfail ] );
						PrintToChat( COLOR_BLUE + "Total times got 1st, 2nd, 3rd = " + COLOR_GREEN + player_profile[ Stats.top1 ] + COLOR_BLUE + ", " + COLOR_GREEN + player_profile[ Stats.top2 ] + COLOR_BLUE + ", " + COLOR_GREEN + player_profile[ Stats.top3 ] );
						PrintToChat( COLOR_BLUE + "Number of Pace to WR 00:00.00 = " + COLOR_GREEN + player_profile[ Stats.wrequals ] );
					}
					else
					{
						LogError( COLOR_RED + "Internal ERROR: player_profile.len() != g_fStatCount (" + profile_length + " != " + g_fStatCount + " )", "r_" + prefix_short + "_profile_" + id + "_" + type );
					}
				}
				else if ( type == "points" )
				{
					PrintToChat( COLOR_GREEN + ( profile_length / 2 ).tostring() + "/" + g_fTotalMapCount.tostring() + COLOR_YELLOW + " maps completed on " + ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + ":" );

					if ( !ValidArray( player_profile, 2 ) )
					{
						LogError( COLOR_RED + "Internal ERROR: that player's points profile is invalid length = " + profile_length.tostring(), "r_" + prefix_short + "_profile_" + id + "_" + type );
						return;
					}

					for ( local i = 0; i < profile_length; i += 2 )
					{
						local spaces = "";
						for ( local j = 0; j < 7 - player_profile[i].len(); ++j )
							spaces += " ";

						PrintToChat( COLOR_BLUE + player_profile[i] + spaces + "= " + COLOR_GREEN + player_profile[i+1] + COLOR_BLUE + " points" );
					}
				}
				else
				{
					local strText = "";
					if ( type == "nf+ngl" ) strText = COLOR_GREEN + profile_length.tostring() + COLOR_YELLOW + "/" + COLOR_GREEN + GetTotalMapCount( prefix ).tostring() + " " + ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + " maps completed " + COLOR_GREEN + "without flamer and grenade launcher:";
					if ( type == "nohit" ) 	strText = COLOR_GREEN + profile_length.tostring() + COLOR_YELLOW + "/" + COLOR_GREEN + GetTotalMapCount( prefix ).tostring() + " " + ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + " maps completed " + COLOR_GREEN + "without getting hit:";

					PrintToChat( strText );

					for ( local i = 0; i < profile_length; ++i )
					{
						PrintToChat( COLOR_BLUE + player_profile[i] );
					}
				}

				return;
			}
			case "leaderboard":
			{
				local prefix = argv[2].toupper();
				local prefix_short = "";
				local type = argv[3];
				local range = argv[4];
				
				if ( prefix == "RELAXED" ) prefix_short = "rs";
				if ( prefix == "HARDCORE" ) prefix_short = "hs";

				if ( prefix_short == "" )
				{
					PrintToChat( "Expected argument 2 to either be \"relaxed\" or \"hardcore\"" );
					return;
				}
				
				if ( range != "close" && range != "top" && range != "full" )
				{
					PrintToChat( "Expected argument 4 to either be \"close\", \"top\" or \"full\"" );
					return;
				}
				
				if ( type == "nf+ngl" || type == "nohit" || type == "points" )
				{
					local array_leaderboard = type == "points" ? CleanList( split( FileToString( "r_" + prefix_short + "_leaderboard_points" ), "|" ) ) : [];
					local leaderboard_length = array_leaderboard.len();
					local score_type = type == "points" ? " points" : " maps";

					if ( type != "points" )
					{
						foreach( steamid, name in g_tPlayerList )
						{
							local player_profile = CleanList( split( FileToString( "r_" + prefix_short + "_profile_" + steamid + "_" + type ), "|" ) );
							local maps_completed = player_profile.len();

							if ( maps_completed != 0 )
							{
								local i = 1;
								for ( ; i < array_leaderboard.len(); i += 2 )
								{	
									if ( maps_completed > array_leaderboard[i] )
										break;
								}
								
								array_leaderboard.insert( i - 1, name );
								array_leaderboard.insert( i, maps_completed );
							}
						}
						
						leaderboard_length = array_leaderboard.len();
					}
					else
					{
						for ( local i = 0; i < leaderboard_length; i += 2 )
						{
							array_leaderboard[i] = g_tPlayerList[ array_leaderboard[i] ];
							array_leaderboard[i+1] = TruncateFloat( array_leaderboard[i+1].tofloat(), 1 ).tostring();
						}
					}
					
					if ( leaderboard_length == 0 )
					{
						PrintToChat( "No such leaderboard yet" );
						return;
					}
					
					if ( type != "points" ) PrintToChat( COLOR_YELLOW + "Most " + COLOR_GREEN + type + COLOR_YELLOW + " maps completed on " + ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + ":" );
					else PrintToChat( ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + " points leaderboard:" );
					
					if ( leaderboard_length / 2 <= 5 )
						range = "full";
						
					switch ( range )
					{
						case "full":
						{
							for ( local i = 0; i < leaderboard_length; i += 2 )
							{
								local color = GetKeyFromValue( g_tPlayerList, array_leaderboard[i] ) == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
								local spaces = "";
								for ( local j = 0; j < 13 - array_leaderboard[i].len(); ++j )
									spaces += " ";
								
								PrintToChat( COLOR_BLUE + (i/2+1).tostring() + ": " + color + array_leaderboard[i] + spaces + COLOR_BLUE + " - " + COLOR_GREEN + array_leaderboard[i + 1].tostring() + COLOR_BLUE + score_type );
							}
							
							return;
						}
						case "top":
						{
							for ( local i = 0; i < 10; i += 2 )
							{
								local color = GetKeyFromValue( g_tPlayerList, array_leaderboard[i] ) == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
								local spaces = "";
								for ( local j = 0; j < 13 - array_leaderboard[i].len(); ++j )
									spaces += " ";
								
								PrintToChat( COLOR_BLUE + (i/2+1).tostring() + ": " + color + array_leaderboard[i] + spaces + COLOR_BLUE + " - " + COLOR_GREEN + array_leaderboard[i + 1].tostring() + COLOR_BLUE + score_type );
							}
							
							return;
						}
						case "close":
						{	
							local caller_index = -1;
							local start_index = -1;
							local end_index = -1;
							local last_index = leaderboard_length - 2;
							
							for ( local i = 0; i < leaderboard_length; i += 2 )
							{
								if ( GetKeyFromValue( g_tPlayerList, array_leaderboard[i] ) == caller_steam_id )
								{
									caller_index = i;
									start_index = i - 4;
									end_index = i + 4;
									break;
								}
							}
							
							if ( caller_index == -1 )
							{
								// print the "top" range
								for ( local i = 0; i < 10; i += 2 )
								{
									local spaces = "";
									for ( local j = 0; j < 13 - array_leaderboard[i].len(); ++j )
										spaces += " ";
									
									PrintToChat( COLOR_BLUE + (i/2+1).tostring() + ": " + array_leaderboard[i] + spaces + " - " + COLOR_GREEN + array_leaderboard[i + 1].tostring() + COLOR_BLUE + score_type );
								}
								
								return;
							}
							else
							{
								if ( start_index < 0 )
								{
									// print the "top" range
									for ( local i = 0; i < 10; i += 2 )
									{
										local color = GetKeyFromValue( g_tPlayerList, array_leaderboard[i] ) == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local spaces = "";
										for ( local j = 0; j < 13 - array_leaderboard[i].len(); ++j )
											spaces += " ";
										
										PrintToChat( COLOR_BLUE + (i/2+1).tostring() + ": " + color + array_leaderboard[i] + spaces + COLOR_BLUE + " - " + COLOR_GREEN + array_leaderboard[i + 1].tostring() + COLOR_BLUE + score_type );
									}
									
									return;
								}
								
								if ( end_index > last_index )
								{	
									for ( local i = start_index - end_index + last_index; i < last_index + 1; i += 2 )
									{
										local color = GetKeyFromValue( g_tPlayerList, array_leaderboard[i] ) == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local spaces = "";
										for ( local j = 0; j < 13 - array_leaderboard[i].len(); ++j )
											spaces += " ";
										
										PrintToChat( COLOR_BLUE + (i/2+1).tostring() + ": " + color + array_leaderboard[i] + spaces + COLOR_BLUE + " - " + COLOR_GREEN + array_leaderboard[i + 1].tostring() + COLOR_BLUE + score_type );
									}
									
									return;
								}
								else
								{
									for ( local i = start_index; i < end_index + 1; i += 2 )
									{
										local color = GetKeyFromValue( g_tPlayerList, array_leaderboard[i] ) == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local spaces = "";
										for ( local j = 0; j < 13 - array_leaderboard[i].len(); ++j )
											spaces += " ";
										
										PrintToChat( COLOR_BLUE + (i/2+1).tostring() + ": " + color + array_leaderboard[i] + spaces + COLOR_BLUE + " - " + COLOR_GREEN + array_leaderboard[i + 1].tostring() + COLOR_BLUE + score_type );
									}
									
									return;
								}
							}
						}
					}
				}
				else	// map leaderboard
				{
					local leaderboard = CleanList( split( FileToString( "r_" + prefix_short + "_leaderboard_"  + type ), "|" ) );
					local lb_length = leaderboard.len();

					if ( lb_length == 0 )
					{
						PrintToChat( COLOR_YELLOW + "Leaderboard for map " + COLOR_RED + type + COLOR_YELLOW + " does not exist." );
						return;
					}

					PrintToChat( COLOR_YELLOW + "Leaderboard for map " + COLOR_GREEN + type + COLOR_YELLOW + " on " + ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix.toupper() + COLOR_YELLOW + ":" );
					
					if ( lb_length / 4 <= 5 )
						range = "full";

					switch ( range )
					{
						case "full":
						{
							for ( local i = 0; i < lb_length; i += 4 )
							{
								local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
								local name = g_tPlayerList[ leaderboard[i] ];
								local time = TimeToString( leaderboard[i + 1].tofloat(), true );
								local date = ReinterpretDate( leaderboard[i + 2] );

								local spaces_name = "";
								for ( local j = 0; j < 13 - name.len(); ++j )
									spaces_name += " ";
								
								PrintToChat( COLOR_BLUE + (i/4+1).tostring() + ( (i/4+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 3] + COLOR_BLUE + " points - " + color + date );
							}
							
							return;
						}
						case "top":
						{
							for ( local i = 0; i < 20; i += 4 )
							{
								local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
								local name = g_tPlayerList[ leaderboard[i] ];
								local time = TimeToString( leaderboard[i + 1].tofloat(), true );
								local date = ReinterpretDate( leaderboard[i + 2] );

								local spaces_name = "";
								for ( local j = 0; j < 13 - name.len(); ++j )
									spaces_name += " ";
								
								PrintToChat( COLOR_BLUE + (i/4+1).tostring() + ( (i/4+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 3] + COLOR_BLUE + " points - " + color + date );
							}
							
							return;
						}
						case "close":
						{	
							local caller_index = -1;
							local start_index = -1;
							local end_index = -1;
							local last_index = lb_length - 4;
							
							for ( local i = 0; i < lb_length; i += 4 )
							{
								if ( leaderboard[i] == caller_steam_id )
								{
									caller_index = i;
									start_index = i - 8;
									end_index = i + 8;
									break;
								}
							}
							
							if ( caller_index == -1 )
							{
								// print the "top" range
								for ( local i = 0; i < 20; i += 4 )
								{
									local name = g_tPlayerList[ leaderboard[i] ];
									local time = TimeToString( leaderboard[i + 1].tofloat(), true );
									local date = ReinterpretDate( leaderboard[i + 2] );

									local spaces_name = "";
									for ( local j = 0; j < 13 - name.len(); ++j )
										spaces_name += " ";
									
									PrintToChat( COLOR_BLUE + (i/4+1).tostring() + ( (i/4+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 3] + COLOR_BLUE + " points - " + color + date );
								}
								
								return;
							}
							else
							{
								if ( start_index < 0 )
								{
									// print the "top" range
									for ( local i = 0; i < 20; i += 4 )
									{
										local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local name = g_tPlayerList[ leaderboard[i] ];
										local time = TimeToString( leaderboard[i + 1].tofloat(), true );
										local date = ReinterpretDate( leaderboard[i + 2] );

										local spaces_name = "";
										for ( local j = 0; j < 13 - name.len(); ++j )
											spaces_name += " ";
										
										PrintToChat( COLOR_BLUE + (i/4+1).tostring() + ( (i/4+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 3] + COLOR_BLUE + " points - " + color + date );
									}
									
									return;
								}
								
								if ( end_index > last_index )
								{	
									for ( local i = start_index - end_index + last_index; i < last_index + 1; i += 4 )
									{
										local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local name = g_tPlayerList[ leaderboard[i] ];
										local time = TimeToString( leaderboard[i + 1].tofloat(), true );
										local date = ReinterpretDate( leaderboard[i + 2] );

										local spaces_name = "";
										for ( local j = 0; j < 13 - name.len(); ++j )
											spaces_name += " ";
										
										PrintToChat( COLOR_BLUE + (i/4+1).tostring() + ( (i/4+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 3] + COLOR_BLUE + " points - " + color + date );
									}
									
									return;
								}
								else
								{
									for ( local i = start_index; i < end_index + 1; i += 4 )
									{
										local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local name = g_tPlayerList[ leaderboard[i] ];
										local time = TimeToString( leaderboard[i + 1].tofloat(), true );
										local date = ReinterpretDate( leaderboard[i + 2] );

										local spaces_name = "";
										for ( local j = 0; j < 13 - name.len(); ++j )
											spaces_name += " ";
										
										PrintToChat( COLOR_BLUE + (i/4+1).tostring() + ( (i/4+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 3] + COLOR_BLUE + " points - " + color + date );
									}
									
									return;
								}
							}
						}
					}
				}

				return;
			}
		}
	}

	PrintToChat( "Command unrecognised" );
}