const g_fStatCount = 11;				// when adding more stats change this constant
enum Stats {
	version,
	points_relaxed,
	points_hardcore,
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

	if ( argc < 2 )
		return;

	if ( argv[0].tolower() != "/r" )
		return;
	
	local caller_steam_id = GetPlayerFromUserID( params["userid"] ).GetNetworkIDString().slice( 10 );
	
	if ( argc == 2 )
	{
		switch( argv[1].tolower() )
		{
			case "help":
			{
				PrintToChat( COLOR_BLUE + "List of commands:" );
				PrintToChat( COLOR_GREEN + "- /r profile <name/steamid> <relaxed/hardcore> <general/points/nf+ngl/nohit>" );
				PrintToChat( COLOR_GREEN + "- /r leaderboard <relaxed/hardcore> <mapname/nf+ngl/nohit/points> <close/top/full>" );
			}
		}

		return;
	}

	if ( argc == 5 )
	{
		switch( argv[1].tolower() )
		{
			case "profile":
			{
				local prefix = argv[3];
				local prefix_short = "";
				local id = argv[2];
				local type = argv[4];

				if ( prefix == "relaxed" ) prefix_short = "rs";
				if ( prefix == "hardcore" ) prefix_short = "hs";

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
						PrintToChat( COLOR_BLUE + "Points on relaxed             = " + COLOR_GREEN + player_profile[ Stats.points_relaxed ].tointeger().tostring() );
						PrintToChat( COLOR_BLUE + "Points on hardcore            = " + COLOR_GREEN + player_profile[ Stats.points_hardcore ].tointeger().tostring() );
						PrintToChat( COLOR_BLUE + "Alien kills                   = " + COLOR_GREEN + player_profile[ Stats.killcount ] );
						PrintToChat( COLOR_BLUE + "Alien kills by melee          = " + COLOR_GREEN + player_profile[ Stats.meleekills ] );
						PrintToChat( COLOR_BLUE + "Hours spent in mission        = " + COLOR_GREEN + TruncateFloat( ( player_profile[ Stats.missiondecims ].tointeger() / 36000.0 ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Total kilometers ran          = " + COLOR_GREEN + TruncateFloat( ( player_profile[ Stats.distancetravelled ].tointeger() / 10000.0 ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Average meters ran per minute = " + COLOR_GREEN + TruncateFloat( ( 60 * ( ( 1.0 * player_profile[ Stats.distancetravelled ].tointeger() ) / ( 1.0 * player_profile[ Stats.missiondecims ].tointeger() ) ) ), 2 ).tostring() );
						PrintToChat( COLOR_BLUE + "Fast reload fails             = " + COLOR_GREEN + player_profile[ Stats.reloadfail ] );
						PrintToChat( COLOR_BLUE + "Total times got top1          = " + COLOR_GREEN + player_profile[ Stats.top1 ] );
						PrintToChat( COLOR_BLUE + "Total times got top2          = " + COLOR_GREEN + player_profile[ Stats.top2 ] );
						PrintToChat( COLOR_BLUE + "Total times got top3          = " + COLOR_GREEN + player_profile[ Stats.top3 ] );
					}
					else
					{
						PrintToChat( COLOR_RED + "Internal ERROR: player_profile.len() != g_fStatCount (" + profile_length + " != " + g_fStatCount + " )" );
					}
				}
				else if ( type == "points" )
				{
					PrintToChat( COLOR_GREEN + ( profile_length / 2 ).tostring() + "/" + g_fTotalMapCount.tostring() + COLOR_YELLOW + " maps completed on " + ( prefix == "relaxed" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + ":" );

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
					local strText = null;
					if ( type == "nf+ngl" ) strText = COLOR_YELLOW + profile_length.tostring() + "/" + g_fTotalMapCount.tostring() + " " + prefix + COLOR_BLUE + " maps completed " + COLOR_YELLOW + "without flamer and grenade launcher:";
					if ( type == "nohit" ) 	strText = COLOR_YELLOW + profile_length.tostring() + "/" + g_fTotalMapCount.tostring() + " " + prefix + COLOR_BLUE + " maps completed " + COLOR_YELLOW + "without getting hit:";

					PrintToChat( COLOR_BLUE + strText );

					for ( local i = 0; i < profile_length; ++i )
					{
						PrintToChat( COLOR_BLUE + player_profile[i] );
					}
				}

				return;
			}
			case "leaderboard":
			{
				local prefix = argv[2];
				local prefix_short = "";
				local type = argv[3];
				local range = argv[4];
				
				if ( prefix == "relaxed" ) prefix_short = "rs";
				if ( prefix == "hardcore" ) prefix_short = "hs";

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
					
					if ( type != "points" ) PrintToChat( COLOR_YELLOW + "Most " + COLOR_GREEN + type + COLOR_YELLOW + " maps completed on " + ( prefix == "relaxed" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + ":" );
					else PrintToChat( ( prefix == "relaxed" ? COLOR_GREEN : COLOR_RED ) + prefix + COLOR_YELLOW + " points leaderboard:" );
					
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

					PrintToChat( COLOR_YELLOW + "Leaderboard for map " + COLOR_GREEN + type + COLOR_YELLOW + ":" );
					
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
								
								PrintToChat( color + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + name + spaces_name + " - " + time + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
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
								
								PrintToChat( color + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + name + spaces_name + " - " + time + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
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
									
									PrintToChat( COLOR_BLUE + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + name + spaces_name + " - " + time + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
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
										
										PrintToChat( color + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + name + spaces_name + " - " + time + " - " + COLOR_GREEN + leaderboard[i + 2] + COLOR_BLUE + " points" );
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
										
										PrintToChat( color + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + name + spaces_name + " - " + time + " - " + leaderboard[i + 2] + " points" );
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
										
										PrintToChat( color + (i/3+1).tostring() + ( (i/3+1).tostring().len() > 1 ? ": " : ":  " ) + name + spaces_name + " - " + time + " - " + leaderboard[i + 2] + " points" );
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
