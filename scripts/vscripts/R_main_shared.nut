/*
	left to do:
- kabla proposed interesting idea about  a stat - how many times you had top1, top2, top3
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

const g_fStatCount = 9;				// when adding more stats change this constant
const g_Version = "1";
g_stat_killcount <- 0;
g_stat_meleekills <- 0;
g_stat_missiondecims <- 0;
g_stat_distancetravelled <- 0;
g_stat_reloadfail <- 0;
g_stat_count_top1 <- 0;
g_stat_count_top2 <- 0;
g_stat_count_top3 <- 0;

g_fTimeStart <- 0;
g_vecPrevCoordinates <- Vector();

const FILENAME_PLAYERLIST = "r_playerlist";
FILENAME_PLAYERPROFILE <- "";
FILENAME_MAPSINFO <- "";
FILENAME_SPLITS <- "";
g_tPlayerList <- {};	// player list table. index is player's name, value is steamid
g_fTotalMapCount <- 0;

function OnMissionStart()
{
	local player_list = CleanList( split( FileToString( FILENAME_PLAYERLIST ), "|" ) );
	if ( player_list.len() != 0 )
	{
		for ( local i = 0; i < player_list.len(); i += 2 )
		{
			g_tPlayerList[ player_list[i+1] ] <- player_list[i];
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
		PrintToChat( "Current map is not rated. This run will not count any stats" );
		g_bInvalidRun <- true;
		Update = null;
	}
	else
	{
		FILENAME_SPLITS <- "r_" + g_strPrefix + "_splits_" + g_strCurMap;

		InitializeSplits();
	}

	g_bCheckedMap <- true;
}

function GetCurrentMapInfo()
{
	local maps_info = CleanList( split( FileToString( FILENAME_MAPSINFO ), "|" ) );

	if ( maps_info.len() == 0 )
		return;

	maps_info.remove( 0 );	// remove the comment

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

	local color = COLOR_GREEN;
	local time_difference = g_tCurObjectiveTimes[ strObjectiveName ] - g_tWRObjectiveTimes[ strObjectiveName ].tofloat();

	if ( time_difference > 0 )
		color = COLOR_RED;
	if ( time_difference < 0.01 && time_difference > -0.01 )
		color = COLOR_YELLOW;

	PrintToChat( COLOR_BLUE + "Pace to WR: " + color + TimeToString( time_difference ) );
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

	UpdatePlayerData( 1 );

	if ( Time() - g_fTimeStart < g_fWRTime )
	{
		if ( g_fWRTime > 900000 )
		{
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " is the first person to " + COLOR_GREEN+ "beat" + COLOR_BLUE + " this map!" );	
		}
		else
		{
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has " + COLOR_GREEN + "beat" + COLOR_BLUE + " the world record by " + COLOR_GREEN + ( g_fWRTime - Time() + g_fTimeStart ).tostring() + COLOR_BLUE + " seconds!" );
		}

		WriteSplits();
	}
	else if ( Time() - g_fTimeStart - 5.0 < g_fWRTime )
	{
		PrintToChat( COLOR_RED + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has " + COLOR_RED + "missed" + COLOR_BLUE + " the world record by " + COLOR_RED + ( Time() - g_fTimeStart - g_fWRTime ) + COLOR_BLUE + " seconds!" );
	}
}

function OnGameEvent_mission_failed( params )
{
	Update = null;
	
	if ( g_bInvalidRun || !g_bCheckedMap )
		return;
	
	UpdatePlayerData( 0 );
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
function UpdatePlayerData( iMissionComplete )
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

	player_profile[0] = g_Version;
	player_profile[1] = ( player_profile[1].tointeger() + g_stat_killcount ).tostring();
	player_profile[2] = ( player_profile[2].tointeger() + g_stat_meleekills ).tostring();
	player_profile[3] = ( player_profile[3].tointeger() + g_stat_missiondecims ).tostring();
	player_profile[4] = ( player_profile[4].tointeger() + UnitsToDecimeters( g_stat_distancetravelled ) ).tostring();
	player_profile[5] = ( player_profile[5].tointeger() + g_stat_reloadfail ).tostring();
	//player_profile[6] = ( player_profile[6].tointeger() + g_stat_count_top1 ).tostring();
	//player_profile[7] = ( player_profile[7].tointeger() + g_stat_count_top2 ).tostring();
	//player_profile[8] = ( player_profile[8].tointeger() + g_stat_count_top3 ).tostring();
	
	WriteFile( FILENAME_PLAYERPROFILE + "_general", player_profile, "|", 1, "" );

	if ( iMissionComplete )
	{
		ManageMapStats( FILENAME_PLAYERPROFILE + "_maps", g_strCurMap );

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
