IncludeScript( "R_useful_funcs.nut" );
IncludeScript( "R_chatcolors.nut" );
IncludeScript( "R_leaderboard_logic.nut" );
IncludeScript( "R_player_say.nut" );

const FILENAME_PLAYERLIST = "r_playerlist";
g_tPlayerList <- {};	// player list table. index is steamid, value is player's name
g_fTotalMapCount <- 0;
g_bSoloModEnabled <- false;
g_bFatalError <- false;

g_strCurMap <- "";
g_iMapRating <- -1;
g_iMapPrecision <- -1;

g_bIsMapspawn <- true;

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

g_strLastMessage <- "";
g_strLastPlayer <- "";
function SetWorldSpawnScope() 
{
	local hWorld = Entities.FindByClassname( null, "worldspawn" );
	hWorld.ValidateScriptScope();
	local scWorld = hWorld.GetScriptScope();
	scWorld.JH_Update <- function()
	{
		local file_messagelog = CleanList( split( FileToString( "r_messagelog" ), "|" ) );
		local file_len = file_messagelog.len();

		if ( file_len != 0 )
		{
			if ( file_messagelog[ file_len - 1 ] != g_strLastMessage || file_messagelog[ file_len - 2 ] != g_strLastPlayer )
			{
				g_strLastMessage <- file_messagelog[ file_len - 1 ];
				g_strLastPlayer <- file_messagelog[ file_len - 2 ];
				
				if ( g_strLastPlayer.len() > 16 )
				{
					if ( g_strLastPlayer.slice( 0, 17 ) == "MessageBroadcast_" )
					{
						// name already filtered
						local player_name = g_strLastPlayer.slice( 17 );

						local _hPlayer = null;
						while ( _hPlayer = Entities.FindByClassname( _hPlayer, "player" ) )
							if ( FilterName( _hPlayer.GetPlayerName() ) == player_name )
								return 0.1;

						PrintToChat( g_strLastMessage );
						return 0.1;
					}
				}

				local hPlayer = null;
				while ( hPlayer = Entities.FindByClassname( hPlayer, "player" ) )
					if ( FilterName( hPlayer.GetPlayerName() ) == g_strLastPlayer )
						return 0.1;

				PrintToChat( COLOR_PURPLE + g_strLastPlayer + COLOR_LIGHTBLUE + ": " + g_strLastMessage );
			}
		}

		return 0.1; 
	}

	scWorld.JH_Update();
	AddThinkToEnt( hWorld, "JH_Update" );
}

SetWorldSpawnScope();

function OnGameEvent_mission_failed( params )
{
	// clear message log
	WriteFile( "r_messagelog", [], "|", 2, "" );
}

function OnGameEvent_mission_success( params )
{
	// clear message log
	WriteFile( "r_messagelog", [], "|", 2, "" );
}
