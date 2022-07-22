const g_fStatCount = 10;				// when adding more stats change this constant
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
	top3
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
		file_messagelog.push( FilterName( GetPlayerFromUserID( params["userid"] ).GetPlayerName() ) );
		file_messagelog.push( FilterName( text ) );

		WriteFile( "r_messagelog", file_messagelog, "|", 2, "" );
		
		return;
	}
	
	local caller_steam_id = GetPlayerFromUserID( params["userid"] ).GetNetworkIDString().slice( 10 );
	
	if ( argv[0].tolower() == "/r_admin" )
	{
		if ( argc == 3 )
		{
			local admin_list = CleanList( split( FileToString( "r_adminlist" ), "|" ) );
			for ( local i = 0; i < admin_list.len(); ++i )
			{
				if ( admin_list[i] == caller_steam_id )
				{
					// admin typed this
					switch ( argv[1].tolower() )
					{
						case "rebuild_all_leaderboards":		// warning: SQQuerySuspend is a bitch, use carefully. it might rebuild only a small percentage of leaderboards when theres a lot. todo: figure out a bypass or an optimization...
						{
							if ( argv[2].tolower() == "relaxed" )
							{
								local maps_info = CleanList( split( FileToString( "r_rs_mapratings" ), "|" ) );

								if ( maps_info.len() == 0 )
									return;

								maps_info.remove( 0 );	// remove the comment

								if ( !ValidArray( maps_info, 4 ) )
								{
									PrintToChat( COLOR_RED + "Internal ERROR: MapSpawn: maps_info array has invalid length = " + maps_info.len().tostring() );
									return;
								}

								for ( local i = 0; i < maps_info.len(); i += 4 )
									if ( BuildLeaderboard( "rs", maps_info[i], maps_info[i+2].tointeger(), maps_info[i+3].tointeger() )[0] == -9 )
										return; 

								PrintToChat( COLOR_GREEN + "Succesfully rebuilt all leaderboards for relaxed mode." );
							}
							else if ( argv[2].tolower() == "hardcore" )
							{
								local maps_info = CleanList( split( FileToString( "r_hs_mapratings" ), "|" ) );

								if ( maps_info.len() == 0 )
									return;

								maps_info.remove( 0 );	// remove the comment

								if ( !ValidArray( maps_info, 4 ) )
								{
									PrintToChat( COLOR_RED + "Internal ERROR: MapSpawn: maps_info array has invalid length = " + maps_info.len().tostring() );
									return;
								}

								for ( local i = 0; i < maps_info.len(); i += 4 )
									if ( BuildLeaderboard( "hs", maps_info[i], maps_info[i+2].tointeger(), maps_info[i+3].tointeger() )[0] == -9 )
										return; 

								PrintToChat( COLOR_GREEN + "Succesfully rebuilt all leaderboards for hardcore mode." );
							}
							else 
							{
								PrintToChat( "Expected argument 2 to be relaxed or hardcore" );
							}
						}
					}

					return;
				}
			}

			PrintToChat( "Admin command tried being executed by non-admin" );
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
				PrintToChat( COLOR_GREEN + "- /r maplist" + COLOR_BLUE + " - prints a list of all supported maps" );
				PrintToChat( COLOR_GREEN + "- /r leaderboard" + COLOR_BLUE + " - prints current map's and challenge's leaderboard" );
				PrintToChat( COLOR_GREEN + "- /r points" + COLOR_BLUE + " - prints current challenge's points leaderboard" );
				PrintToChat( COLOR_GREEN + "- /r profile" + COLOR_BLUE + " - prints your current challenge's general profile" );
				PrintToChat( COLOR_GREEN + "- /r welcome " + COLOR_YELLOW + "[yes/no]" + COLOR_BLUE + " - disable/enable welcome message for yourself" );
				return;
			}
			case "maplist":
			{
				local map_list = CleanList( split( FileToString( "r_maplist" ), "|" ) );

				if ( map_list.len() == 0 || !ValidArray( map_list, 2 ) )
				{
					PrintToChat( "Internal ERROR: map_list has invalid length = " + map_list.len() );
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

	//if ( argv[1].tolower() == "run_code" )
	//{
	//	local command = "";
	//
	//	for ( local i = 2; i < argc; ++i )
	//	{
	//		command += argv[i] + " ";
	//	}
	//
	//	DoEntFire( "worldspawn", "runscriptcode", command, 0, null, null );
	//	return;
	//}

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
					if ( profile_length == g_fStatCount )
					{
						PrintToChat( COLOR_GREEN + ( g_tPlayerList.rawin( id ) ? g_tPlayerList[id] : id ) + COLOR_YELLOW + "'s general stats on " + ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + ":" );
						PrintToChat( COLOR_PURPLE + "Points                        = " + COLOR_GREEN + TruncateFloat( player_profile[ Stats.points ].tofloat(), 1 ).tostring() );
						PrintToChat( COLOR_BLUE + "Alien kills                   = " + COLOR_GREEN + player_profile[ Stats.killcount ] );
						PrintToChat( COLOR_BLUE + "Alien kills by melee          = " + COLOR_GREEN + player_profile[ Stats.meleekills ] );
						PrintToChat( COLOR_BLUE + "Hours spent in mission        = " + COLOR_GREEN + TruncateFloat( ( player_profile[ Stats.missiondecims ].tointeger() / 36000.0 ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Total kilometers ran          = " + COLOR_GREEN + TruncateFloat( ( player_profile[ Stats.distancetravelled ].tointeger() / 10000.0 ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Average meters ran per minute = " + COLOR_GREEN + TruncateFloat( ( 60 * ( ( 1.0 * player_profile[ Stats.distancetravelled ].tointeger() ) / ( 1.0 * player_profile[ Stats.missiondecims ].tointeger() ) ) ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Fast reload fails             = " + COLOR_GREEN + player_profile[ Stats.reloadfail ] );
						PrintToChat( COLOR_BLUE + "Total times got 1st, 2nd, 3rd = " + COLOR_GREEN + player_profile[ Stats.top1 ] + COLOR_BLUE + ", " + COLOR_GREEN + player_profile[ Stats.top2 ] + COLOR_BLUE + ", " + COLOR_GREEN + player_profile[ Stats.top3 ] );
					}
					else
					{
						PrintToChat( COLOR_RED + "Internal ERROR: player_profile.len() != g_fStatCount (" + profile_length + " != " + g_fStatCount + " )" );
					}
				}
				else if ( type == "points" )
				{
					PrintToChat( COLOR_GREEN + ( profile_length / 2 ).tostring() + "/" + g_fTotalMapCount.tostring() + COLOR_YELLOW + " maps completed on " + ( prefix == "RELAXED" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + ":" );

					if ( !ValidArray( player_profile, 2 ) )
					{
						PrintToChat( COLOR_RED + "Internal ERROR: that player's points profile is invalid length = " + profile_length.tostring() );
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
					
					if ( lb_length / 3 <= 5 )
						range = "full";

					switch ( range )
					{
						case "full":
						{
							for ( local i = 0; i < lb_length; i += 3 )
							{
								local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
								local name = g_tPlayerList[ leaderboard[i] ];
								local time = TimeToString( leaderboard[i + 1].tofloat(), true );

								local spaces_name = "";
								for ( local j = 0; j < 13 - name.len(); ++j )
									spaces_name += " ";
								
								PrintToChat( COLOR_BLUE + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
							}
							
							return;
						}
						case "top":
						{
							for ( local i = 0; i < 15; i += 3 )
							{
								local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
								local name = g_tPlayerList[ leaderboard[i] ];
								local time = TimeToString( leaderboard[i + 1].tofloat(), true );

								local spaces_name = "";
								for ( local j = 0; j < 13 - name.len(); ++j )
									spaces_name += " ";
								
								PrintToChat( COLOR_BLUE + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
							}
							
							return;
						}
						case "close":
						{	
							local caller_index = -1;
							local start_index = -1;
							local end_index = -1;
							local last_index = lb_length - 3;
							
							for ( local i = 0; i < lb_length; i += 3 )
							{
								if ( leaderboard[i] == caller_steam_id )
								{
									caller_index = i;
									start_index = i - 6;
									end_index = i + 6;
									break;
								}
							}
							
							if ( caller_index == -1 )
							{
								// print the "top" range
								for ( local i = 0; i < 15; i += 3 )
								{
									local name = g_tPlayerList[ leaderboard[i] ];
									local time = TimeToString( leaderboard[i + 1].tofloat(), true );

									local spaces_name = "";
									for ( local j = 0; j < 13 - name.len(); ++j )
										spaces_name += " ";
									
									PrintToChat( COLOR_BLUE + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
								}
								
								return;
							}
							else
							{
								if ( start_index < 0 )
								{
									// print the "top" range
									for ( local i = 0; i < 15; i += 3 )
									{
										local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local name = g_tPlayerList[ leaderboard[i] ];
										local time = TimeToString( leaderboard[i + 1].tofloat(), true );

										local spaces_name = "";
										for ( local j = 0; j < 13 - name.len(); ++j )
											spaces_name += " ";
										
										PrintToChat( COLOR_BLUE + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
									}
									
									return;
								}
								
								if ( end_index > last_index )
								{	
									for ( local i = start_index - end_index + last_index; i < last_index + 1; i += 3 )
									{
										local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local name = g_tPlayerList[ leaderboard[i] ];
										local time = TimeToString( leaderboard[i + 1].tofloat(), true );

										local spaces_name = "";
										for ( local j = 0; j < 13 - name.len(); ++j )
											spaces_name += " ";
										
										PrintToChat( COLOR_BLUE + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
									}
									
									return;
								}
								else
								{
									for ( local i = start_index; i < end_index + 1; i += 3 )
									{
										local color = leaderboard[i] == caller_steam_id ? COLOR_GREEN : COLOR_BLUE;
										local name = g_tPlayerList[ leaderboard[i] ];
										local time = TimeToString( leaderboard[i + 1].tofloat(), true );

										local spaces_name = "";
										for ( local j = 0; j < 13 - name.len(); ++j )
											spaces_name += " ";
										
										PrintToChat( COLOR_BLUE + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + color + name + spaces_name + COLOR_BLUE + " - " + color + time + COLOR_BLUE + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
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