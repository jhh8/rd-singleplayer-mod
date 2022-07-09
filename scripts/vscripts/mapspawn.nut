IncludeScript( "R_chatcolors.nut" );

function CleanList( list )
{
	if ( list.len() == 0 )
		return list;
	
	list.pop();	// pop the end of line
	
	for ( local i = 0; i < list.len(); ++i )
	{
		list[i] = strip( list[i] );
	}

	return list;
}

const FILENAME_PLAYERLIST = "r_playerlist";
const FILENAME_MAPSINFO_MAPSPAWN = "r_rs_mapratings";
const g_fStatCount = 9;	
g_tPlayerList <- {};	// player list table. index is player's name, value is steamid
g_fTotalMapCount <- 0;
g_bSoloModEnabled <- false;

local player_list = CleanList( split( FileToString( FILENAME_PLAYERLIST ), "|" ) );
if ( player_list.len() != 0 )
{
	for ( local i = 0; i < player_list.len(); i += 2 )
	{
		g_tPlayerList[ player_list[i+1] ] <- player_list[i];
	}
}

function GetCurrentMapInfo()
{
	local maps_info = CleanList( split( FileToString( FILENAME_MAPSINFO_MAPSPAWN ), "|" ) );

	if ( maps_info.len() == 0 )
		return;

	maps_info.remove( 0 );	// remove the comment

	g_fTotalMapCount <- maps_info.len() / 4;
}

GetCurrentMapInfo();

function OnMissionStart()	// can this be done in OnMissionStart?
{
	g_bSoloModEnabled <- ( Convars.GetStr( "rd_challenge" ) == "R_RS" || Convars.GetStr( "rd_challenge" ) == "R_HS" ) ? true : false;
	
	if ( g_bSoloModEnabled )
		Entities.FindByClassname( null, "asw_challenge_thinker" ).GetScriptScope().OnGameEvent_player_say = null;
}

function OnGameEvent_player_say( params )
{	
	local text = params["text"];
	local argv = split( text, " " );
	local argc = argv.len();

	if ( argc < 2 )
		return;

	if ( argv[0] != "/r" )
		return;

	if ( argc == 2 )
	{
		switch( argv[1] )
		{
			case "help":
			{
				PrintToChat( COLOR_BLUE + "List of commands:" );
				PrintToChat( COLOR_GREEN + "- /r profile <name/steamid> <relaxed/hardcore> <general/maps/nf+ngl/nohit>" );
				PrintToChat( COLOR_GREEN + "- /r leaderboard <relaxed/hardcore> <mapname/nf+ngl/nohit>" );
			}
		}

		return;
	}

	if ( argc == 4 )
	{
		switch( argv[1] )
		{
			case "leaderboard":
			{
				local prefix = argv[2];
				local prefix_short = "";
				local type = argv[3];
				
				if ( prefix == "relaxed" ) prefix_short = "rs_";
				if ( prefix == "hardcore" ) prefix_short = "hs_";

				if ( prefix_short == "" )
				{
					PrintToChat( "Expected argument 2 to either be \"relaxed\" or \"hardcore\"" );
					return;
				}

				if ( type == "nf+ngl" || type == "nohit" )
				{
					local array_leaderboard = [];
					foreach( name, steamid in g_tPlayerList )
					{
						local player_profile = CleanList( split( FileToString( "r_" + prefix_short + "profile_" + steamid + "_" + type ), "|" ) );
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

					if ( array_leaderboard.len() == 0 )
					{
						PrintToChat( COLOR_RED + "No such leaderboard yet" );
						return;
					}

					for ( local i = 0; i < array_leaderboard.len(); i += 2 )
					{
						PrintToChat( COLOR_GREEN + array_leaderboard[i] + COLOR_BLUE + " with " + COLOR_GREEN + array_leaderboard[i + 1].tostring() );
					}
				}
				else
				{
					// TODO: mapname leaderboards
				}

				return;
			}
		}

		return;
	}

	if ( argc == 5 )
	{
		switch( argv[1] )
		{
			case "profile":
			{
				local prefix = argv[3];
				local prefix_short = "";
				local steamid = argv[2];
				local type = argv[4];

				if ( prefix == "relaxed" ) prefix_short = "rs_";
				if ( prefix == "hardcore" ) prefix_short = "hs_";

				if ( prefix_short == "" )
				{
					PrintToChat( "Expected argument 3 to either be \"relaxed\" or \"hardcore\"" );
					return;
				}
				
				local player_profile = CleanList( split( FileToString( "r_" + prefix_short + "profile_" + steamid + "_" + type ), "|" ) );
				if ( player_profile.len() == 0 )
				{
					if ( g_tPlayerList.rawin( steamid ) )	// rawget( "jhheight" ) == 108718913
					{
						player_profile = CleanList( split( FileToString( "r_" + prefix_short + "profile_" + g_tPlayerList.rawget( steamid ) + "_" + type ), "|" ) );
						if ( player_profile.len() == 0 )
						{
							PrintToChat( COLOR_RED + "No such profile found" + COLOR_BLUE + "- player exists but profile doesnt" );
							return;
						}
					}
					else
					{
						PrintToChat( COLOR_RED + "No such profile found" + COLOR_BLUE + "- player doesnt exist" );
						return;
					}
				}
				// yay we found a profile
				if ( type == "general" )
				{
					if ( player_profile.len() == g_fStatCount )
					{
						PrintToChat( COLOR_BLUE + "Alien kills = " + COLOR_GREEN + player_profile[1] );
						PrintToChat( COLOR_BLUE + "Alien kills by melee = " + COLOR_GREEN + player_profile[2] );
						PrintToChat( COLOR_BLUE + "Hours spent in mission = " + COLOR_GREEN + ( player_profile[3].tointeger() / 36000.0 ).tostring() );
						PrintToChat( COLOR_BLUE + "Total kilometers ran = " + COLOR_GREEN + ( player_profile[4].tointeger() / 10000.0 ).tostring() );
						PrintToChat( COLOR_BLUE + "Average meters ran per minute = " + COLOR_GREEN + ( 60 * ( ( 1.0 * player_profile[4].tointeger() ) / ( 1.0 * player_profile[3].tointeger() ) ) ).tostring() );
						PrintToChat( COLOR_BLUE + "Fast reload fails = " + COLOR_GREEN + player_profile[5] );
						PrintToChat( COLOR_BLUE + "Total times got top1 = " + COLOR_GREEN + player_profile[6] );
						PrintToChat( COLOR_BLUE + "Total times got top2 = " + COLOR_GREEN + player_profile[7] );
						PrintToChat( COLOR_BLUE + "Total times got top3 = " + COLOR_GREEN + player_profile[8] );
					}
				}
				else 
				{
					local strText = null;
					if ( type == "maps" ) 	strText = player_profile.len().tostring() + "/" + g_fTotalMapCount.tostring() + " " + prefix + " maps completed:";
					if ( type == "nf+ngl" ) strText = player_profile.len().tostring() + "/" + g_fTotalMapCount.tostring() + " " + prefix + " maps completed without flamer and grenade launcher:";
					if ( type == "nohit" ) 	strText = player_profile.len().tostring() + "/" + g_fTotalMapCount.tostring() + " " + prefix + " maps completed without getting hit:";

					PrintToChat( COLOR_BLUE + strText );

					for ( local i = 0; i < player_profile.len(); ++i )
					{
						PrintToChat( COLOR_GREEN + player_profile[i] );
					}
				}

				return;
			}
		}
	}

	return;
}

function PrintToChat( str_message )
{
	ClientPrint( null, 3, str_message );
}
