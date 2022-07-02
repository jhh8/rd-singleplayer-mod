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
g_iMapRating <- -1;
g_iMapPrecision <- -1;
g_tCurObjectiveTimes <- {};
g_tWRObjectiveTimes <- {};
g_bWRExists <- true;
g_fWRTime <- 999999.0;

g_bInvalidRun <- false;
g_bMissionComplete <- false;

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
FILENAME_SPLITS <- "";

function OnMissionStart()
{
	g_strPrefix <- Convars.GetStr( "rd_challenge" ) == "R_RS" ? "rs" : "hs";
	FILENAME_MAPSINFO <- "r_" + g_strPrefix + "_mapratings";
	
	GetCurrentMapInfo();
}

function OnGameplayStart()
{
	g_hMarine <- Entities.FindByClassname( null, "asw_marine" );
	g_hPlayer <- g_hMarine.GetCommander();
	g_steam_id <- g_hPlayer.GetNetworkIDString().slice( 10 );

	g_fTimeStart <- Time() - 0.5;
	
	if ( g_strCurMap == "" )
	{
		PrintToChat( "Current map is not rated. This run will not count any stats" );
		g_bInvalidRun <- true;
		Update = null;
	}
	else
	{
		FILENAME_SPLITS <- "r_" + g_strPrefix + "_splits_" + g_strCurMap;

		InitializeSplits();
	}
}

function GetCurrentMapInfo()
{
	local maps_info = split( FileToString( FILENAME_MAPSINFO ), "|" );

	if ( maps_info.len() == 0 )
		return;

	maps_info.remove( 0 );	// remove the comment
	maps_info.pop();

	for ( local i = 0; i < maps_info.len(); ++i )
	{
		maps_info[i] = strip( maps_info[i] );
	}

	local cur_map = GetMapName().tolower();

	for ( local i = 0; i < maps_info.len(); i += 4 )
	{
		if ( cur_map == maps_info[i + 1] )
		{
			g_strCurMap <- maps_info[i];
			g_iMapRating <- maps_info[i+2].tointeger();
			g_iMapPrecision <- maps_info[i+3].tointeger();

			return;
		}
	}
}

function InitializeSplits()
{
	// make every objective call OnObjectiveCompleted in challenge thinkers scope
	local strArrayObjectiveName 	= 	["asw_objective_triggered", "asw_objective_escape", "asw_objective_destroy_goo", "asw_objective_kill_eggs", 
										"asw_objective_countdown", "asw_objective_kill_aliens", "asw_objective_survive", "asw_objective_dummy"];
	foreach ( str_classname in strArrayObjectiveName )
	{
		local hObjective = null;
		while( hObjective = Entities.FindByClassname( hObjective, str_classname ) ) 
		{
			hObjective.ValidateScriptScope();

			local Scope = hObjective.GetScriptScope();
			Scope.CallParentFunc <- function()
			{
				local Scope_ChallengeThinker = Entities.FindByClassname( null, "asw_challenge_thinker" ).GetScriptScope();
				Scope_ChallengeThinker.OnObjectiveCompleted( self );

				// problems if two objectives get completed at same time
				//::g_hCurrentObjective <- self;
				//DoEntFire( "asw_challenge_thinker", "RunScriptCode", "OnObjectiveCompleted( g_hCurrentObjective )", 0, null, null );
			}

			hObjective.ConnectOutput( "OnObjectiveComplete", "CallParentFunc" );
		}
	}

	// extract splits
	local splits_list = split( FileToString( FILENAME_SPLITS ), "|" );

	if ( splits_list.len() == 0 )
	{
		g_bWRExists <- false;
	}
	else
	{	
		splits_list.pop();
		
		for ( local i = 0; i < splits_list.len(); i += 2  )
		{
			g_tWRObjectiveTimes[ strip( splits_list[i] ) ] <- strip( splits_list[i+1] );
		}

		g_fWRTime <- g_tWRObjectiveTimes["finish"].tofloat();
	}
}

function WriteSplits()
{
	local cursplits_list = [];	
	foreach( strObjectiveName, _time in g_tCurObjectiveTimes )
	{
		cursplits_list.append( strObjectiveName );
		cursplits_list.append( _time.tostring() );
	}

	cursplits_list.append( "finish" );
	cursplits_list.append( ( Time() - g_fTimeStart ).tostring() );

	WriteFile( FILENAME_SPLITS, cursplits_list, "|", 2, "" );
}

function OnObjectiveCompleted( hObjective )
{	
	if ( g_bMissionComplete )
		return;
	
	local strObjectiveName = hObjective.GetName() == "" ? hObjective.GetClassname() : hObjective.GetName();
	
	g_tCurObjectiveTimes[ strObjectiveName ] <- Time() - g_fTimeStart;

	if ( !g_bWRExists )
		return;

	if ( !g_tWRObjectiveTimes.rawin( strObjectiveName ) )
	{
		PrintToChat( "ERROR: Current WR does not have this objective completed! wut" );
		return;
	}

	local color = 4;	// 4 - green, 1 - yellow, 7 - red
	local time_difference = g_tCurObjectiveTimes[ strObjectiveName ] - g_tWRObjectiveTimes[ strObjectiveName ].tofloat();

	if ( time_difference > 0 )
		color = 7;
	if ( time_difference == 0 )
		color = 1;

	PrintToChat( (3).tochar() + "Pace to WR: " + color.tochar() + TimeToString( time_difference ) );
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
	g_bMissionComplete <- true;

	if ( g_bInvalidRun )
		return;
	
	UpdatePlayerData( 1 );

	if ( Time() - g_fTimeStart < g_fWRTime )
	{
		if ( g_fWRTime > 900000 )
		{
			PrintToChat( (4).tochar() + g_hPlayer.GetPlayerName() + (3).tochar() + " is the first person to " + (4).tochar() + "beat" + (3).tochar() + "this map!" );	
		}
		else
		{
			PrintToChat( (4).tochar() + g_hPlayer.GetPlayerName() + (3).tochar() + " has " + (4).tochar() + "beat" + (3).tochar() + " the world record by " + (4).tochar() + ( g_fWRTime - Time() + g_fTimeStart ).tostring() + (3).tochar() + " seconds!" );
		}

		WriteSplits();
	}
	else if ( Time() - g_fTimeStart - 5.0 < g_fWRTime )
	{
		PrintToChat( (7).tochar() + g_hPlayer.GetPlayerName() + (3).tochar() + " has " + (7).tochar() + "missed" + (3).tochar() + " the world record by " + (7).tochar() + ( Time() - g_fTimeStart - g_fWRTime ) + (3).tochar() + " seconds!" );
	}
}

function OnGameEvent_mission_failed( params )
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
		player_list.pop();
		
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
		WriteFile( FILENAME_PLAYERLIST, player_list, "|", 2, "" );
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
		player_profile.pop();

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

	WriteFile( "r_" + g_strPrefix + "_profile_" + g_steam_id, player_profile, "|", 1, "" );
}

function WriteFile( file_name, data, str_delimiter, data_per_line, compiled_string_initialize )
{
	local compiled_string = compiled_string_initialize;
	
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

function DelayFunctionCall( function_name, function_params, delay )
{
	if ( !this["self"] )
		return;
	
	// this[ function_name ]( function_params );
	EntFireByHandle( this["self"], "RunScriptCode", "this[\"" + function_name + "\"](" + function_params + ");", delay, null, null );
}

function TimeToString( _time )
{
	local compiled_string = "";

	if ( _time < 0 )
	{
		_time *= -1;
		compiled_string += "-";
	}
	else
	{
		compiled_string += "+";
	}
	
	local miliseconds = 100 * ( _time - _time.tointeger() );
	miliseconds = miliseconds.tointeger();
	_time = _time.tointeger();

	if ( _time >= 3600 )
	{
		compiled_string += str( _time / 3600 ) + ":";
		_time %= 3600;
	}

	compiled_string += str( ( _time / 60 ) / 10 ) + str( ( _time / 60 ) % 10 ) + ":";
	_time %= 60;
	compiled_string += str( _time / 10 ) + str( _time % 10 ) + "." + str( miliseconds / 10 ) + str( miliseconds % 10 );

	return compiled_string;
}

function str( parameter )
{
	return parameter.tostring();
}

function PrintToChat( str_message )
{
	ClientPrint( null, 3, str_message );
}
