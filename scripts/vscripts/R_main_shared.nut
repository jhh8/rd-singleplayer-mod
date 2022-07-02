/*
	left to do:
- kabla proposed interesting idea about  a stat - how many times you had top1, top2, top3
- unique maps completed nf+ngl (no flamer + no grenadelauncher) and a leaderboard for it
- unique maps completed nohit and a leaderboard for it
- remove adren from relaxed
- make difficulties harder on hardcore
- admin commands and admin database
- leaderboards and points calculator
- factor in mission difficulty for stats and stuff

*/

g_hMarine <- null;
g_hPlayer <- null;
g_steam_id <- "";

g_strPrefix <- "";
g_strCurMap <- "";

g_bInvalidRun <- false;

g_fStatCount <- 6;
g_stat_killcount <- 0;
g_stat_reloadfail <- 0;
g_stat_meleekills <- 0;
g_stat_missiondecims <- 0;
g_stat_distancetravelled <- 0;

g_fTimeStart <- 0;
g_vecPrevCoordinates <- Vector();

const FILENAME_PLAYERLIST = "r_playerlist";
FILENAME_MAPSINFO <- "";

function OnGameplayStart()
{
	g_strPrefix <- Convars.GetStr( "rd_challenge" ) == "R_RS" ? "rs" : "hs";
	FILENAME_MAPSINFO <- "r_" + g_strPrefix + "_mapratings";

	g_hMarine <- Entities.FindByClassname( null, "asw_marine" );
	g_hPlayer <- g_hMarine.GetCommander();
	g_steam_id <- g_hPlayer.GetNetworkIDString().slice( 10 );
	
	g_strCurMap <- GetCurrentMap();
	if ( g_strCurMap == "" )
	{
		PrintToChat( "Current map is not rated. This run will not count any stats" );
		g_bInvalidRun <- true;
		Update = null;
	}

	g_fTimeStart <- Time() - 0.5;
}

function GetCurrentMap()
{
	local maps_info = split( FileToString( FILENAME_MAPSINFO ), "|" );

	if ( maps_info.len() == 0 )
		return "";

	maps_info.remove( 0 );	// remove the comment
	maps_info.remove( maps_info.len() - 1 );

	local cur_map = GetMapName().tolower();

	for ( local i = 0; i < maps_info.len(); i += 4 )
	{
		if ( cur_map == strip( maps_info[i + 1] ) )
			return strip( maps_info[i] );
	}

	return "";
}

function Update()
{		
	if ( g_bInvalidRun )
		return 9999.0;
	
	if ( !g_hMarine )
		return 0.5;

	if ( !g_hMarine.IsValid() )
		return 0.5;
	
	if ( !g_hPlayer || g_hPlayer != g_hMarine.GetCommander() )
	{
		PrintToChat( "Run is invalid! Initial player stopped playing. This run will not count any stats" );
		g_bInvalidRun <- true;

		Update = null;

		return 9999.0;
	}

	if ( g_vecPrevCoordinates.Length() )
	{
		local vecOrigin = g_hMarine.GetOrigin();
		local fDistance = sqrt( (vecOrigin.x - g_vecPrevCoordinates.x) * (vecOrigin.x - g_vecPrevCoordinates.x) + (vecOrigin.y - g_vecPrevCoordinates.y) * (vecOrigin.y - g_vecPrevCoordinates.y) );

		if ( fDistance > 120.0 )
			fDistance = 120.0;

		g_stat_distancetravelled += fDistance;
	}
	
	g_vecPrevCoordinates <- g_hMarine.GetOrigin();

	return 0.2;
}

function OnGameEvent_fast_reload_fail( params )
{
	if ( g_bInvalidRun )
		return;

	++g_stat_reloadfail;
}

function OnGameEvent_alien_died( params )
{
	if ( g_bInvalidRun || !params["marine"] )
		return;
	
	if ( params["weapon"] == 40 )
		++g_stat_meleekills;
		
	++g_stat_killcount;
}

function OnGameEvent_mission_success( params )
{	
	Update = null;
	
	if ( g_bInvalidRun )
		return;
	
	UpdatePlayerData( 1 );
}

function OnGameEvent_mission_failed( params )	// add mission success checks here too
{
	Update = null;
	
	if ( g_bInvalidRun )
		return;
	
	UpdatePlayerData( 0 );
}

// writes r_playerlist and player's profile
function UpdatePlayerData( iMissionComplete )
{
	if ( g_bInvalidRun )
		return;
	
	local player_list = split( FileToString( FILENAME_PLAYERLIST ), "|" );
	
	if ( player_list.len() != 0 )
	{
		player_list.remove( player_list.len() - 1 );
		
		for ( local i = 0; i < player_list.len(); i += 2 )
		{
			player_list[i] = strip( player_list[i] );
		}
	}
	
	local bFoundPlayer = false;
	local bWasPlayerListChange = true;
	
	for ( local i = 0; i < player_list.len(); i += 2 )
	{
		if ( g_steam_id == player_list[i] )
		{
			bFoundPlayer = true;
			
			if ( g_hPlayer.GetPlayerName() != player_list[i+1] )
			{
				// the player has changed his name recently
				player_list[i+1] = g_hPlayer.GetPlayerName();
			}
			else
			{
				// player already played this mod and did not change his name
				bWasPlayerListChange = false;
			}
		}
	}
	
	if ( !bFoundPlayer )
	{
		// player played our mod for the first time, add him into player list file
		player_list.push( g_steam_id );
		player_list.push( g_hPlayer.GetPlayerName() );
	}
	
	if ( bWasPlayerListChange )
	{	
		WriteFile( FILENAME_PLAYERLIST, player_list, "|", 2 );
	}
	
	//---------------------------------------------------------------------------------------------------------------
	
	local player_profile = split( FileToString( "r_" + g_strPrefix + "_profile_" + g_steam_id ), "|" );
	g_stat_missiondecims <- ( ( Time() - g_fTimeStart ) * 10 ).tointeger();
	
	if ( player_profile.len() == 0 )
	{
		for ( local i = 0; i < g_fStatCount; ++i )
		{
			player_profile.push( "0" );
		}
	}
	else
	{
		player_profile.remove( player_profile.len() - 1 );

		for ( local i = 0; i < g_fStatCount + player_profile[g_fStatCount - 1].tointeger(); ++i )
		{
			player_profile[i] = strip( player_profile[i] );
		}
	}


	player_profile[0] = ( player_profile[0].tointeger() + g_stat_killcount ).tostring();
	player_profile[1] = ( player_profile[1].tointeger() + g_stat_meleekills ).tostring();
	player_profile[2] = ( player_profile[2].tointeger() + g_stat_missiondecims ).tostring();
	player_profile[3] = ( player_profile[3].tointeger() + UnitsToDecimeters( g_stat_distancetravelled ) ).tostring();
	player_profile[4] = ( player_profile[4].tointeger() + g_stat_reloadfail ).tostring();

	//printl( "avg meters per minute = " + ( 60 * ( ( 1.0 * player_profile[3].tointeger() ) / ( 1.0 * player_profile[2].tointeger() ) ) ).tostring() )
	
	if ( iMissionComplete )
	{
		local bNewMap = true;
		for ( local i = g_fStatCount; i < g_fStatCount + player_profile[g_fStatCount - 1].tointeger(); ++i )
		{
			if ( g_strCurMap == player_profile[i] )
			{
				bNewMap = false;
				break;
			}
		}
		
		if ( bNewMap )
		{
			player_profile[g_fStatCount - 1] = ( player_profile[g_fStatCount - 1].tointeger() + 1 ).tostring();
			player_profile.push( g_strCurMap );
		}
	}

	WriteFile( "r_" + g_strPrefix + "_profile_" + g_steam_id, player_profile, "|", 1 );
}

function WriteFile( file_name, data, str_delimiter, data_per_line )
{
	local compiled_string = "";
	
	for ( local i = 0; i < data.len(); i += data_per_line )
	{
		for ( local j = i; j < i + data_per_line; ++j )
		{
			compiled_string += data[j] + str_delimiter;
			
			if ( j + 1 == i + data_per_line )	// last piece of data on a line
			{
				compiled_string += "\n";
			}
		}
	}
	
	StringToFile( file_name, compiled_string );
}	

function UnitsToDecimeters( value )
{
	return ( value * 0.1905 ).tointeger();
}

function DelayCodeExecution( string_code, delay )
{
	DoEntFire( "worldspawn", "RunScriptCode", string_code, delay, null, null );
}

function PrintToChat( str_message )
{
	ClientPrint( null, 3, str_message );
}
