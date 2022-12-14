IncludeScript( "R_useful_funcs.nut" );

g_strActiveChallenge <- Convars.GetStr( "rd_challenge" );
g_tActivePlayersList <- [];  // list of player names which are currently on the server
const MAP_CHANGE_PLAYER_JOIN_TIME = 10.0;	// this must be lower than sv_hibernate_postgame_delay!!!
const MAP_CHANGE_CHALLENGE_CHANGE_TIME = 2.0;
const THINK_TIME = 0.1;
LOG_ACTIVITY <- 1;

function SetupEventListener()
{
    Event_new_map();
    
    local hWorld = Entities.FindByClassname( null, "worldspawn" );
	hWorld.ValidateScriptScope();
	local scWorld = hWorld.GetScriptScope();
	scWorld.ListenForEvents <- function()
    {        
        if ( Convars.GetStr( "rd_challenge" ) != g_strActiveChallenge )
        {
            g_strActiveChallenge <- Convars.GetStr( "rd_challenge" );
            Event_new_challenge();
        }
        
        g_tActivePlayersList <- CleanList( split( FileToString( "r_activeplayerlist" + g_strServerNumber ), "|" ) );

        if ( !g_tActivePlayersList.len() )
        {
            local hPlayer = null;
            while ( hPlayer = Entities.FindByClassname( hPlayer, "player" ) )
                Event_player_joined( hPlayer );

            return THINK_TIME;
        }

        local hPlayer = null;
        while ( hPlayer = Entities.FindByClassname( hPlayer, "player" ) )
            if ( !IsInsideArray( g_tActivePlayersList, hPlayer.GetPlayerName() ) )
                Event_player_joined( hPlayer );

        if ( Time() < MAP_CHANGE_PLAYER_JOIN_TIME )
            return THINK_TIME;

        for ( local i = 0; i < g_tActivePlayersList.len(); ++i )
        {   
            local bValidPlayer = false;

            local hPlayer = null;
            while ( hPlayer = Entities.FindByClassname( hPlayer, "player" ) )
                if ( hPlayer.GetPlayerName() == g_tActivePlayersList[i] )
                    bValidPlayer = true;

            if ( bValidPlayer )
                continue;

            Event_player_left( i );
            i -= 1;
        }

        return THINK_TIME;
    }
}

function Event_player_joined( hPlayer )
{
    g_tActivePlayersList.push( hPlayer.GetPlayerName() );
    BroadcastMessage( COLOR_GREEN + hPlayer.GetPlayerName() + " joined the server.", false, true );

    WriteFile( "r_activeplayerlist" + g_strServerNumber, g_tActivePlayersList, "|", g_tActivePlayersList.len(), "" );
    
    local bStopLogs = false;
    if ( LOG_ACTIVITY )
       bStopLogs = LogActivity( hPlayer.GetPlayerName() + " joined the server." );

    if ( bStopLogs )
    {
        LogActivity( "Stopping log activity. File size close to max" );
        LOG_ACTIVITY <- 0;
    }
}

function Event_player_left( nPlayer )
{
    BroadcastMessage( COLOR_RED + g_tActivePlayersList[ nPlayer ] + " left the server.", false, true, true );

    local bStopLogs = false;
    if ( LOG_ACTIVITY )
        bStopLogs = LogActivity( g_tActivePlayersList[ nPlayer ] + " left the server." );

    if ( bStopLogs )
    {
        LogActivity( "Stopping log activity. File size close to max" );
        LOG_ACTIVITY <- 0;
    }

    g_tActivePlayersList.remove( nPlayer );
    WriteFile( "r_activeplayerlist" + g_strServerNumber, g_tActivePlayersList, "|", g_tActivePlayersList.len(), "" );
}

function Event_new_map()
{
    local active_player_list = CleanList( split( FileToString( "r_activeplayerlist" + g_strServerNumber ), "|" ) );
	
	if ( !active_player_list.len() )
        return;
		
	if ( GetMapName() == "lobby" )	// server actually has no players but activeplayerlist is not empty. server crashed
	{
		BroadcastMessage( COLOR_RED + "Server crashed! :(", false, true );
		StringToFile( "r_activeplayerlist" + g_strServerNumber, "eof" );
		return;
	}

    BroadcastMessage( COLOR_YELLOW + "Map changed to " + COLOR_GREEN + ( g_strCurMap != "" ? g_strCurMap : "<unknown>" ), false, true );

    local bStopLogs = false;
    if ( LOG_ACTIVITY )
        bStopLogs = LogActivity( "Map changed to " + g_strCurMap );

    if ( bStopLogs )
    {
        LogActivity( "Stopping log activity. File size close to max" );
        LOG_ACTIVITY <- 0;
    }
}

function Event_new_challenge()
{    
    if ( Time() < MAP_CHANGE_CHALLENGE_CHANGE_TIME )
        return;
    
    if ( !CleanList( split( FileToString( "r_activeplayerlist" + g_strServerNumber ), "|" ) ).len() )
        return;

    local bStopLogs = false;
    if ( LOG_ACTIVITY )
        bStopLogs = LogActivity( "Challenge changed to " + g_strActiveChallenge );

    if ( bStopLogs )
    {
        LogActivity( "Stopping log activity. File size close to max" );
        LOG_ACTIVITY <- 0;
    }
}