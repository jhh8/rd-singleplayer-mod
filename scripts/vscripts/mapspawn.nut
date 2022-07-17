IncludeScript( "R_useful_funcs.nut" );
IncludeScript( "R_chatcolors.nut" );
IncludeScript( "R_player_say.nut" );

const FILENAME_PLAYERLIST = "r_playerlist";
g_tPlayerList <- {};	// player list table. index is steamid, value is player's name
g_fTotalMapCount <- 0;
g_bSoloModEnabled <- false;
g_bFatalError <- false;

g_strCurMap <- "";
g_iMapRating <- -1;
g_iMapPrecision <- -1;

BuildPlayerList();

GetCurrentMapInfo();

function OnMissionStart()
{
	g_bSoloModEnabled <- ( Convars.GetStr( "rd_challenge" ) == "R_RS" || Convars.GetStr( "rd_challenge" ) == "R_HS" ) ? true : false;
	g_bSoloModEnabled <- g_bFatalError ? false : g_bSoloModEnabled;
	
	if ( g_bSoloModEnabled )
		Entities.FindByClassname( null, "asw_challenge_thinker" ).GetScriptScope().OnGameEvent_player_say = null;
	
	local notwelcome_list = CleanList( split( FileToString( "r_notwelcome" ), "|" ) );

	local hPlayer = null;
	while ( hPlayer = Entities.FindByClassname( hPlayer, "player" ) )
	{
		local bNotWelcome = false;

		foreach( _player in notwelcome_list )
		{
			if ( _player == hPlayer.GetNetworkIDString().slice( 10 ) )
			{
				bNotWelcome = true;
				break;
			}
		}

		if ( !bNotWelcome )
		{
			ClientPrint( hPlayer, 3, COLOR_PURPLE + "Welcome to singleplayer mod!" );
			ClientPrint( hPlayer, 3, COLOR_BLUE + "Play the challenges called " + COLOR_GREEN + "Ranked Relaxed Solo" + COLOR_BLUE + " or " + COLOR_GREEN + "Ranked Hardcore Solo" + COLOR_BLUE + " to gain points and compete with other players!" );
			ClientPrint( hPlayer, 3, COLOR_BLUE + "Type " + COLOR_GREEN + "/r help" + COLOR_BLUE + " for some useful chat commands" );
			ClientPrint( hPlayer, 3, COLOR_PURPLE + "More information on https://github.com/jhh8/rd-singleplayer-mod" );
		}
	}
}

function GetPlayerSteamID()
{
	return 0;
}
