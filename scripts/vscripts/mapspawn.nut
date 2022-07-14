IncludeScript( "R_useful_funcs.nut" );
IncludeScript( "R_chatcolors.nut" );
IncludeScript( "R_player_say.nut" );

const FILENAME_PLAYERLIST = "r_playerlist";
const FILENAME_MAPSINFO_MAPSPAWN = "r_rs_mapratings";	
g_tPlayerList <- {};	// player list table. index is steamid, value is player's name
g_fTotalMapCount <- 0;
g_bSoloModEnabled <- false;
g_bFatalError <- false;

local player_list = CleanList( split( FileToString( FILENAME_PLAYERLIST ), "|" ) );
if ( player_list.len() != 0 )
{
	for ( local i = 0; i < player_list.len(); i += 2 )
	{
		g_tPlayerList[ player_list[i] ] <- player_list[i+1];
	}
}

if ( !ValidArray( player_list, 2 ) )
{
	PrintToChat( COLOR_RED + "FATAL Internal ERROR: MapSpawn: player_list array has invalid length = " + player_list.len().tostring() );
	g_bFatalError <- true;
}

function GetCurrentMapInfo()
{
	local maps_info = CleanList( split( FileToString( FILENAME_MAPSINFO_MAPSPAWN ), "|" ) );

	if ( maps_info.len() == 0 )
		return;

	maps_info.remove( 0 );	// remove the comment

	if ( !ValidArray( maps_info, 4 ) )
	{
		PrintToChat( COLOR_RED + "Internal ERROR: MapSpawn: maps_info array has invalid length = " + maps_info.len().tostring() );
		return;
	}

	g_fTotalMapCount <- maps_info.len() / 4;
}

GetCurrentMapInfo();

function OnMissionStart()	// can this be done in OnMissionStart?
{
	g_bSoloModEnabled <- ( Convars.GetStr( "rd_challenge" ) == "R_RS" || Convars.GetStr( "rd_challenge" ) == "R_HS" ) ? true : false;
	g_bSoloModEnabled <- g_bFatalError ? false : g_bSoloModEnabled;
	
	if ( g_bSoloModEnabled )
		Entities.FindByClassname( null, "asw_challenge_thinker" ).GetScriptScope().OnGameEvent_player_say = null;
}

function GetPlayerSteamID()
{
	return 0;
}
