/*
	left to do:
- admin commands and admin database
- leaderboards and points calculator

*/

/*
	player general profile looks like this:
	
	0: last version on which the player played
	1: alien kill count
	2: alien kill count by melee
	3: deci-miliseconds spent in the mission
	4: decimeters ran in total
	5: fast reload fails
	6: number of top1's
	7: number of top2's
	8: number of top3's
*/

IncludeScript( "R_chatcolors.nut" );
IncludeScript( "R_player_say.nut" );
IncludeScript( "R_leaderboard_logic.nut" );

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
g_bCheckedMap <- false;		// make sure nothing breaks when map is completed in less than 0.5 seconds
g_bNFNGLRun <- true;
g_bNOHITRun <- true;
g_bMissionComplete <- false;

const g_Version = "1";
g_stat_killcount <- 0;
g_stat_meleekills <- 0;
g_stat_missiondecims <- 0;
g_stat_distancetravelled <- 0;
g_stat_reloadfail <- 0;

g_fTimeStart <- 0;
g_vecPrevCoordinates <- Vector();

const FILENAME_PLAYERLIST = "r_playerlist";
FILENAME_PLAYERPROFILE <- "";
FILENAME_MAPSINFO <- "";
FILENAME_SPLITS <- "";
g_tPlayerList <- {};	// player list table. index is steamid, value is player's name
g_fTotalMapCount <- 0;

function OnMissionStart()
{
	local player_list = CleanList( split( FileToString( FILENAME_PLAYERLIST ), "|" ) );

	if ( !ValidArray( player_list, 2 ) )
	{
		PrintToChat( COLOR_RED + "FATAL Internal ERROR: asw_challenge_thinker: player_list array has invalid length = " + player_list.len().tostring() );
		this["self"].Destroy();
		return;
	}

	if ( player_list.len() != 0 )
	{
		for ( local i = 0; i < player_list.len(); i += 2 )
		{
			g_tPlayerList[ player_list[i] ] <- player_list[i+1];
		}
	}
	
	g_strPrefix <- Convars.GetStr( "rd_challenge" ) == "R_RS" ? "rs" : "hs";
	
	g_fTimeStart <- Time();

	FILENAME_MAPSINFO <- "r_" + g_strPrefix + "_mapratings";
	
	GetCurrentMapInfo();
}

function OnGameplayStart()
{		
	g_hMarine <- Entities.FindByClassname( null, "asw_marine" );
	g_hPlayer <- g_hMarine.GetCommander();
	g_steam_id <- g_hPlayer.GetNetworkIDString().slice( 10 );
	
	FILENAME_PLAYERPROFILE <- "r_" + g_strPrefix + "_profile_" + g_steam_id;

	if ( g_strCurMap == "" )
	{
		PrintToChat( COLOR_RED + "Current map is not rated. This run will not count any stats" );
		g_bInvalidRun <- true;
		Update = null;
	}
	else
	{
		FILENAME_SPLITS <- "r_" + g_strPrefix + "_splits_" + g_strCurMap;

		InitializeSplits();
	}

	g_bCheckedMap <- true;

	/*// testing
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "108718913", "47.166" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "2", "47.25" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "3", "47.583" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "4", "47.816" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "5", "48.683" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "6", "48.733" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "7", "49.966" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "8", "50.1" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "9", "50.616" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "10", "51.883" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "11", "52.000" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "12", "53.566" ] );
	BuildLeaderboard( "rs", "para1", 600, 10, true, [ "13", "57.216" ] );
	*/
}

function GetCurrentMapInfo()
{
	local maps_info = CleanList( split( FileToString( FILENAME_MAPSINFO ), "|" ) );

	if ( maps_info.len() == 0 )
		return;

	maps_info.remove( 0 );	// remove the comment

	if ( !ValidArray( maps_info, 4 ) )
	{
		PrintToChat( COLOR_RED + "Internal ERROR: asw_challenge_thinker: maps_info array has invalid length = " + maps_info.len().tostring() );
		return;
	}

	g_fTotalMapCount <- maps_info.len() / 4;

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
				
				self.DisconnectOutput( "OnObjectiveComplete", "CallParentFunc" );
			}

			hObjective.ConnectOutput( "OnObjectiveComplete", "CallParentFunc" );
		}
	}

	// extract splits
	local splits_list = CleanList( split( FileToString( FILENAME_SPLITS ), "|" ) );

	if ( !ValidArray( splits_list, 2 ) )
	{
		PrintToChat( COLOR_RED + "Internal ERROR: InitializeSplits: splits_list array has invalid length = " + splits_list.tostring() );
		return;
	}

	if ( splits_list.len() == 0 )
	{
		g_bWRExists <- false;
	}
	else
	{	
		for ( local i = 0; i < splits_list.len(); i += 2  )
		{	
			g_tWRObjectiveTimes[ splits_list[i] ] <- splits_list[i+1];
		}

		g_fWRTime <- TruncateFloat( g_tWRObjectiveTimes["finish"].tofloat(), 3 );
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

	local color = COLOR_GREEN;
	local time_difference = g_tCurObjectiveTimes[ strObjectiveName ] - g_tWRObjectiveTimes[ strObjectiveName ].tofloat();

	if ( time_difference > 0 )
		color = COLOR_RED;
	if ( time_difference < 0.01 && time_difference > -0.01 )
		color = COLOR_YELLOW;

	PrintToChat( COLOR_BLUE + "Pace to WR: " + color + TimeToString( time_difference, false ) );
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
		PrintToChat( COLOR_RED + "Run is invalid! Initial player stopped playing. This run will not count any stats" );
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

function OnTakeDamage_Alive_Any( victim, inflictor, attacker, weapon, damage, damageType, ammoName )
{
	if ( !victim || !g_bNOHITRun )
		return damage;

	if ( victim.GetClassname() == "asw_marine" )
		g_bNOHITRun <- false;

	return damage;
}

function OnGameEvent_weapon_fire( params )
{
	if ( !g_bNFNGLRun )
		return;
	
	local hWeapon = EntIndexToHScript( params[ "weapon" ] );
	
	if ( !hWeapon )
		return;

	local weapon_class = hWeapon.GetClassname();

	if ( weapon_class == "asw_weapon_grenade_launcher" || weapon_class == "asw_weapon_flamer"  )
		g_bNFNGLRun <- false; 
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

	if ( g_bInvalidRun || !g_bCheckedMap )
		return;
	
	local completion_time = TruncateFloat( Time() - g_fTimeStart, 3 );
	local placements = BuildLeaderboard( g_strPrefix, g_strCurMap, g_iMapRating, g_iMapPrecision, false, [ g_steam_id, completion_time.tostring() ] );

	UpdatePlayerData( 1, placements[1] );

	PrintToChat( COLOR_YELLOW + "map " + COLOR_GREEN + g_strCurMap + COLOR_YELLOW + ", mode " + ( g_strPrefix == "hs" ? ( COLOR_RED + "hardcore:" ) : ( COLOR_GREEN + "relaxed:" ) ) );

	if ( placements[0] != -1 )
	{
		if ( placements[0] <= 0 )
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has placed " + COLOR_GREEN + placements[1].tostring() + COLOR_BLUE + " on their first run!" );
		else if ( placements[1] < placements[0] )
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " improved by " + COLOR_GREEN + placements[2].tostring() + COLOR_BLUE + " seconds and placed from " + COLOR_GREEN + placements[0].tostring() + COLOR_BLUE + " to " + COLOR_GREEN + placements[1].tostring() + COLOR_BLUE + "!" );
	}
	else
	{
		if ( placements[2] != -1 )
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " improved their record by " + COLOR_GREEN + placements[2].tostring() + COLOR_BLUE + " seconds!" );
	}

	if ( completion_time < g_fWRTime )
	{
		if ( g_fWRTime > 900000 )
		{
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " is the first person to " + COLOR_GREEN+ "beat" + COLOR_BLUE + " this map!" );	
		}
		else
		{
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has " + COLOR_GREEN + "beat" + COLOR_BLUE + " the world record by " + COLOR_GREEN + TruncateFloat( ( g_fWRTime - Time() + g_fTimeStart ), 2 ).tostring() + COLOR_BLUE + " seconds!" );
		}

		WriteSplits();
	}
	else if ( completion_time == g_fWRTime )
	{
		PrintToChat( COLOR_YELLOW + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has " + COLOR_YELLOW + "equalled" + COLOR_BLUE + " the world record!" );
	}
	else if ( completion_time - 5.0 < g_fWRTime )
	{
		PrintToChat( COLOR_RED + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has " + COLOR_RED + "missed" + COLOR_BLUE + " the world record by " + COLOR_RED + TruncateFloat( ( Time() - g_fTimeStart - g_fWRTime ), 2 ).tostring() + COLOR_BLUE + " seconds!" );
	}
	
	if ( g_bNOHITRun )
		PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has beat the map " + COLOR_GREEN + "without getting hit" + COLOR_BLUE + "!" );
	
	if ( g_bNFNGLRun )
		PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has beat the map " + COLOR_GREEN + "without flamer and grenade launcher" + COLOR_BLUE + "!" );
}

function OnGameEvent_mission_failed( params )
{
	Update = null;
	
	if ( g_bInvalidRun || !g_bCheckedMap )
		return;
	
	UpdatePlayerData( 0, 0 );
}

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

// writes r_playerlist and player's profile
function UpdatePlayerData( iMissionComplete, new_placement )
{
	if ( g_bInvalidRun )
		return;

	local player_list = CleanList( split( FileToString( FILENAME_PLAYERLIST ), "|" ) );
	
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
	
	local player_profile = CleanList( split( FileToString( FILENAME_PLAYERPROFILE + "_general" ), "|" ) );
	g_stat_missiondecims <- ( ( Time() - g_fTimeStart ) * 10 ).tointeger();

	if ( player_profile.len() == 0 )
	{
		player_profile.push( g_Version );
		
		for ( local i = 1; i < g_fStatCount; ++i )
		{
			player_profile.push( "0" );
		}
	}

	if ( player_profile[0].tointeger() != g_Version.tointeger() )
	{
		// change the mod version when adding more stats or changing something in the way its stored, which would require the information to be interpreted or written differently
		// here we can identify when a player's profile has to undercome changes and do a stat fixup
	}

	player_profile[ Stats.version ] = g_Version;
	player_profile[ Stats.killcount ] = ( player_profile[ Stats.killcount ].tointeger() + g_stat_killcount ).tostring();
	player_profile[ Stats.meleekills ] = ( player_profile[ Stats.meleekills ].tointeger() + g_stat_meleekills ).tostring();
	player_profile[ Stats.missiondecims ] = ( player_profile[ Stats.missiondecims ].tointeger() + g_stat_missiondecims ).tostring();
	player_profile[ Stats.distancetravelled ] = ( player_profile[ Stats.distancetravelled ].tointeger() + UnitsToDecimeters( g_stat_distancetravelled ) ).tostring();
	player_profile[ Stats.reloadfail ] = ( player_profile[ Stats.reloadfail ].tointeger() + g_stat_reloadfail ).tostring();
	
	if ( new_placement == 1 ) player_profile[ Stats.top1 ] = ( player_profile[ Stats.top1 ].tointeger() + 1 ).tostring();
	if ( new_placement == 2 ) player_profile[ Stats.top2 ] = ( player_profile[ Stats.top2 ].tointeger() + 1 ).tostring();
	if ( new_placement == 3 ) player_profile[ Stats.top3 ] = ( player_profile[ Stats.top3 ].tointeger() + 1 ).tostring();

	WriteFile( FILENAME_PLAYERPROFILE + "_general", player_profile, "|", 1, "" );

	if ( iMissionComplete )
	{
		if ( g_bNFNGLRun )
			ManageMapStats( FILENAME_PLAYERPROFILE + "_nf+ngl", g_strCurMap );

		if ( g_bNOHITRun )
			ManageMapStats( FILENAME_PLAYERPROFILE + "_nohit", g_strCurMap );
	}
}

function ManageMapStats( filename, mapname )
{
	local player_profile = CleanList( split( FileToString( filename ), "|" ) );
	local bNewMap = true;
	
	if ( player_profile.len() > 0 )
	{		
		if ( IsNewMapInList( player_profile, mapname, 0, player_profile.len() ) )
		{
			player_profile.push( mapname );
		}
		else
		{
			bNewMap = false;
		}
	}
	else
	{
		player_profile.push( mapname );
	}

	// sort the list and write
	if ( bNewMap )
	{
		for ( local i = 0; i < player_profile.len() - 1; ++i )	// nubic selection sort
		{
			local mapname = player_profile[i];
			
			for ( local j = i + 1; j < player_profile.len(); ++j )
			{
				if ( mapname > player_profile[j] )
				{
					player_profile[i] = player_profile[j];
					player_profile[j] = mapname;
					mapname = player_profile[i];
				}
			}
		}

		WriteFile( filename, player_profile, "|", 1, "" );
	}
}

function IsNewMapInList( list, mapname, read_beginning, read_end )
{
	for ( local i = read_beginning; i < read_end; ++i )
	{
		if ( mapname == list[i] )
			return false;
	}

	return true;
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

function TruncateFloat( value, precision )
{
	if ( precision < 0 || precision > 5 || typeof( value ) != "float" )	// sanity check
		return value;
	
	return ( value * pow( 10, precision ) ).tointeger().tofloat() / pow( 10, precision );
}

function PrintToChat( str_message )
{
	ClientPrint( null, 3, str_message );
}

function GetPlayerSteamID()
{
	return g_steam_id;
}
