IncludeScript( "R_chatcolors.nut" );
IncludeScript( "R_player_say.nut" );
IncludeScript( "R_leaderboard_logic.nut" );

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
g_tPlayerList <- {};	// player list table. index is steamid, value is player's name
g_fTotalMapCount <- 0;
g_bSoloModEnabled <- false;

local player_list = CleanList( split( FileToString( FILENAME_PLAYERLIST ), "|" ) );
if ( player_list.len() != 0 )
{
	for ( local i = 0; i < player_list.len(); i += 2 )
	{
		g_tPlayerList[ player_list[i] ] <- player_list[i+1];
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

function PrintToChat( str_message )
{
	ClientPrint( null, 3, str_message );
}

function GetPlayerSteamID()
{
	return 0;
}
