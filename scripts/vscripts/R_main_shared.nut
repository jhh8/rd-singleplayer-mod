IncludeScript( "R_useful_funcs.nut" );
IncludeScript( "R_chatcolors.nut" );
IncludeScript( "R_player_say.nut" );
IncludeScript( "R_leaderboard_logic.nut" );

const g_bonus_points_per_challenge = 7.5;

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

const g_Version = "3";
g_bPointsChanged <- false;
g_stat_prev_points <- 0;
g_stat_new_points <- 0;
g_stat_killcount <- 0;
g_stat_meleekills <- 0;
g_stat_missiondecims <- 0;
g_stat_distancetravelled <- 0;
g_stat_reloadfail <- 0;
g_stat_wrequals <- 0;

g_bIsMapspawn <- false;

g_fTimeStart <- 0;
g_vecPrevCoordinates <- Vector();

const FILENAME_PLAYERLIST = "r_playerlist";
FILENAME_PLAYERPROFILE <- "";
FILENAME_SPLITS <- "";
g_tPlayerList <- {};	// player list table. index is steamid, value is player's name
g_fTotalMapCount <- 0;

function OnMissionStart()
{
	local player_list = CleanList( split( FileToString( FILENAME_PLAYERLIST ), "|" ) );

	if ( !ValidArray( player_list, 2 ) )
	{
		LogError( COLOR_RED + "FATAL Internal ERROR: asw_challenge_thinker: player_list array has invalid length = " + player_list.len().tostring() );
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
	
	g_strPrefix <- IsHardcore() ? "hs" : "rs";
	
	g_fTimeStart <- Time();
	
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
}

function InitializeSplits()
{
	local strArrayObjectiveName 	= 	["asw_objective_triggered", "asw_objective_escape", "asw_objective_destroy_goo", "asw_objective_kill_eggs", 
										"asw_objective_countdown", "asw_objective_kill_aliens", "asw_objective_survive", "asw_objective_dummy"];
	foreach ( str_classname in strArrayObjectiveName )
		CreateSplitPoints( str_classname, [], "OnObjectiveComplete" );

	// crystal destroyter and de_swarm split areas
	CreateSplitPoints( "trigger_teleport", ["room 1", "room 2", "room 3", "room 4", "room 5", "room 5 exit", "Portal 1 entrance trig", "Portal 2 entrance trig"], "OnStartTouch" );
	// split areas:                            landing bay
	CreateSplitPoints( "trigger_asw_chance", ["RandomSpawn5"], "OnTrigger" );
	// split areas:                         cargo elevator
	CreateSplitPoints( "trigger_once", ["ElevatorShaftTrigger"], "OnTrigger" );
	// split areas:                                      deima
	CreateSplitPoints( "trigger_asw_button_area", ["openBridgeButton2"], "OnButtonHackCompleted" );
	// split areas:                                      rydberg             rydberg              residential
	CreateSplitPoints( "trigger_asw_button_area", ["reactor_button2", "exit_door_button_area", "ElevatorButtons"], "OnButtonActivated" );
	// split areas:                          sewer
	CreateSplitPoints( "asw_spawner", ["exit_mortar_spawner"], "OnSpawned" );
	// split areas:                         sewer
	CreateSplitPoints( "math_counter", ["BeamCounter"], "OnHitMax" );
	// split areas:                            timor
	CreateSplitPoints( "func_door_rotating", ["Bridge"], "OnOpen" );

	// extract splits
	local splits_list = CleanList( split( FileToString( FILENAME_SPLITS ), "|" ) );

	if ( !ValidArray( splits_list, 2 ) )
	{
		LogError( COLOR_RED + "Internal ERROR: InitializeSplits: splits_list array has invalid length = " + splits_list.tostring(), FILENAME_SPLITS );
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

// connects split points in specified entities. if valid names array length is 0, any entity name is valid
function CreateSplitPoints( string_entityclassname, array_validnames, string_outputname )
{
	local hEntity = null;
	while( hEntity = Entities.FindByClassname( hEntity, string_entityclassname ) ) 
	{
		local bValidEntity = array_validnames.len() == 0 ? true : false;
		
		foreach( str_name in array_validnames )
		{
			if ( str_name == hEntity.GetName() )
			{
				bValidEntity = true;
				break;
			}
		}
		
		if ( !bValidEntity )
			continue;

		hEntity.ValidateScriptScope();

		local Scope = hEntity.GetScriptScope();
		Scope.string_outputname <- string_outputname;
		Scope.CallParentFunc <- function()
		{	
			local Scope_ChallengeThinker = Entities.FindByClassname( null, "asw_challenge_thinker" ).GetScriptScope();
			Scope_ChallengeThinker.OnSplitReached( self );
				
			self.DisconnectOutput( string_outputname, "CallParentFunc" );
		}

		hEntity.ConnectOutput( string_outputname, "CallParentFunc" );
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

function OnSplitReached( hEntity )
{	
	if ( g_bMissionComplete )
		return;
	
	local strObjectiveName = hEntity.GetName() == "" ? hEntity.GetClassname() : hEntity.GetName();
	
	g_tCurObjectiveTimes[ strObjectiveName ] <- Time() - g_fTimeStart;

	if ( !g_bWRExists )
		return;

	if ( !g_tWRObjectiveTimes.rawin( strObjectiveName ) )
	{
		//PrintToChat( "ERROR: Current WR does not have this objective completed! wut" );
		return;
	}

	local color = COLOR_GREEN;
	local time_difference = g_tCurObjectiveTimes[ strObjectiveName ] - g_tWRObjectiveTimes[ strObjectiveName ].tofloat();

	if ( time_difference > 0 )
	{
		color = COLOR_RED;
	}
	if ( time_difference < 0.01 && time_difference > -0.01 )
	{
		color = COLOR_YELLOW;
		g_stat_wrequals++;
	}

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

	// UpdatePlayerData( 1, placements[1] )
	DelayCodeExecution( "UpdatePlayerData( 1, " + placements[1].tostring() + " )", 0.05 );	// have to delay this because g_stat_prev_points gets calculated correctly with atleast 0.01 delay 

	PrintToChat( COLOR_YELLOW + "MAP " + COLOR_GREEN + g_strCurMap + COLOR_YELLOW + ", MODE " + ( g_strPrefix == "hs" ? ( COLOR_RED + "HARDCORE:" ) : ( COLOR_GREEN + "RELAXED:" ) ) );

	if ( placements[0] != -1 )
	{
		if ( placements[0] <= 0 )
		{
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has placed " + COLOR_GREEN + placements[1].tostring() + COLOR_BLUE + " on their first run!" );
			BroadcastMessage( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " has placed " + COLOR_GREEN + placements[1].tostring() + COLOR_BLUE + " on their first run!", true );
		}
		else if ( placements[1] < placements[0] )
		{
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " improved by " + COLOR_GREEN + TruncateFloat( placements[2], 2 ).tostring() + COLOR_BLUE + " seconds and placed from " + COLOR_GREEN + placements[0].tostring() + COLOR_BLUE + " to " + COLOR_GREEN + placements[1].tostring() + COLOR_BLUE + "!" );
			BroadcastMessage( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " improved by " + COLOR_GREEN + TruncateFloat( placements[2], 2 ).tostring() + COLOR_BLUE + " seconds and placed from " + COLOR_GREEN + placements[0].tostring() + COLOR_BLUE + " to " + COLOR_GREEN + placements[1].tostring() + COLOR_BLUE + "!", true );
		}
	}
	else
	{
		if ( placements[2] != -1 )
		{
			PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " improved their record by " + COLOR_GREEN + TruncateFloat( placements[2], 2 ).tostring() + COLOR_BLUE + " seconds!" );
			BroadcastMessage( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + " improved their record by " + COLOR_GREEN + TruncateFloat( placements[2], 2 ).tostring() + COLOR_BLUE + " seconds!", true );
		}
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
			
			if ( FilterName( g_hPlayer.GetPlayerName() ) != player_list[i+1] )
			{
				// the player has changed his name recently
				player_list[i+1] = FilterName( g_hPlayer.GetPlayerName() );
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
		player_list.push( FilterName( g_hPlayer.GetPlayerName() ) );
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

	g_stat_prev_points <- player_profile[ Stats.points ].tofloat();

	if ( iMissionComplete )
	{
		if ( g_stat_new_points == 0 )
			g_stat_new_points <- g_stat_prev_points;
		else
			g_stat_new_points <- g_stat_new_points + CalculatePlayersChallengePoints( g_steam_id, g_strPrefix );

		if ( g_bNFNGLRun )
			ManageMapStats( FILENAME_PLAYERPROFILE + "_nf+ngl", g_strCurMap );

		if ( g_bNOHITRun )
			ManageMapStats( FILENAME_PLAYERPROFILE + "_nohit", g_strCurMap );

		UpdatePointsLeaderboard( g_steam_id, g_strPrefix, g_stat_new_points );
	}

	// change the mod version when adding more stats or changing something in the way its stored, which would require the information to be interpreted or written differently
	// here we can identify when a player's profile has to undercome changes and do a stat fixup
	if ( player_profile[ Stats.version ].tointeger() == 1 )
	{
		player_profile.push("0");
		player_profile[ Stats.version ] = "2";
	}

	if ( player_profile[ Stats.version ].tointeger() == 2 )
	{
		player_profile.push("0");
	}

	player_profile[ Stats.version ] = g_Version;

	if ( g_bPointsChanged )
	{
		if ( g_stat_prev_points - 0.01 > g_stat_new_points )
		{
			//DelayCodeExecution( "LogError( \"ERROR: Player has lost points after completing the map somehow (\" + g_stat_prev_points.tostring() + \" -> \" + g_stat_new_points + \") not changing points.\", g_steam_id );", 0.02 );
			LogError( "", "Player " + g_steam_id + " points were calculated wrong somewhere, " + g_stat_prev_points.tostring() + " -> " + g_stat_new_points.tostring() );
			player_profile[ Stats.points ] = g_stat_new_points.tostring();
		}
		else if ( g_stat_prev_points + 0.001 < g_stat_new_points )
		{
			player_profile[ Stats.points ] = g_stat_new_points.tostring();
			DelayCodeExecution( "PrintToChat( COLOR_GREEN + g_hPlayer.GetPlayerName() + COLOR_BLUE + \" points have changed from \" + COLOR_GREEN + g_stat_prev_points.tostring() + COLOR_BLUE + \" to \" + COLOR_GREEN + g_stat_new_points.tostring() + COLOR_GREEN + \" (+\" + TruncateFloat( ( g_stat_new_points - g_stat_prev_points ), 2 ).tostring() + \")\" + COLOR_BLUE + \"!\" );", 0.02 );
		}
	}

	local hours_played = ( player_profile[ Stats.missiondecims ].tointeger() + g_stat_missiondecims ) / 36000.0;

	if ( hours_played >= 0.5 )
	{
		local notwelcome_list = CleanList( split( FileToString( "r_notwelcome" ), "|" ) );
		local bIsWelcome = true;

		// if already not welcome, dont add to list
		foreach( index, _player in notwelcome_list )
			if ( _player == g_steam_id )
				bIsWelcome = false;

		// they have over 0.5 hours played, theyre not welcome
		if ( bIsWelcome )
		{
			notwelcome_list.push( g_steam_id );
			WriteFile( "r_notwelcome", notwelcome_list, "|", 1, "" );
			ClientPrint( g_hPlayer, 3, "You have over 0.5 hours played, disabling the welcome message." );
		}
	}

	player_profile[ Stats.killcount ] = ( player_profile[ Stats.killcount ].tointeger() + g_stat_killcount ).tostring();
	player_profile[ Stats.meleekills ] = ( player_profile[ Stats.meleekills ].tointeger() + g_stat_meleekills ).tostring();
	player_profile[ Stats.missiondecims ] = ( player_profile[ Stats.missiondecims ].tointeger() + g_stat_missiondecims ).tostring();
	player_profile[ Stats.distancetravelled ] = ( player_profile[ Stats.distancetravelled ].tointeger() + UnitsToDecimeters( g_stat_distancetravelled ) ).tostring();
	player_profile[ Stats.reloadfail ] = ( player_profile[ Stats.reloadfail ].tointeger() + g_stat_reloadfail ).tostring();
	player_profile[ Stats.wrequals ] = ( player_profile[ Stats.wrequals ].tointeger() + g_stat_wrequals ).tostring();
	player_profile[ Stats.points_nohit_nfngl ] = CalculatePlayersChallengePoints( g_steam_id, g_strPrefix ).tostring();
	
	if ( new_placement == 1 ) player_profile[ Stats.top1 ] = ( player_profile[ Stats.top1 ].tointeger() + 1 ).tostring();
	if ( new_placement == 2 ) player_profile[ Stats.top2 ] = ( player_profile[ Stats.top2 ].tointeger() + 1 ).tostring();
	if ( new_placement == 3 ) player_profile[ Stats.top3 ] = ( player_profile[ Stats.top3 ].tointeger() + 1 ).tostring();

	WriteFile( FILENAME_PLAYERPROFILE + "_general", player_profile, "|", 1, "" );
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
		g_stat_new_points <- g_stat_new_points + g_bonus_points_per_challenge;
		g_bPointsChanged <- true;
		
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

function GetPlayerSteamID()
{
	return g_steam_id;
}