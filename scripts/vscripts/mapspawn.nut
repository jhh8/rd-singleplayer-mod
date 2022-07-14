IncludeScript( "R_useful_funcs.nut" );
IncludeScript( "R_chatcolors.nut" );
IncludeScript( "R_player_say.nut" );

const FILENAME_PLAYERLIST = "r_playerlist";
const FILENAME_MAPSINFO_MAPSPAWN = "r_rs_mapratings";	
g_tPlayerList <- {};	// player list table. index is steamid, value is player's name
g_fTotalMapCount <- 0;
g_bSoloModEnabled <- false;
g_bFatalError <- false;

g_strCurMap <- "";
g_iMapRating <- -1;
g_iMapPrecision <- -1;

BuildPlayerList();

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

GetCurrentMapInfo();

function OnMissionStart()	// can this be done in OnMissionStart?
{
	g_bSoloModEnabled <- ( Convars.GetStr( "rd_challenge" ) == "R_RS" || Convars.GetStr( "rd_challenge" ) == "R_HS" ) ? true : false;
	g_bSoloModEnabled <- g_bFatalError ? false : g_bSoloModEnabled;
	
	if ( g_bSoloModEnabled )
		Entities.FindByClassname( null, "asw_challenge_thinker" ).GetScriptScope().OnGameEvent_player_say = null;
		
	PrintToChat( "Welcome to singleplayer mod! Play the challenges called \"Ranked Relaxed Solo\" or \"Ranked Hardcore Solo\" to gain points and compete with other players!" );
}

function GetPlayerSteamID()
{
	return 0;
}
