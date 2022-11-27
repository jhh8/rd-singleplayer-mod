IncludeScript( "R_useful_funcs.nut" );

g_tActivePlayersList <- [];  // list of player names which are currently on the server
const MAP_CHANGE_PLAYER_JOIN_TIME = 10.0;
const THINK_TIME = 0.1;
const LOG_ACTIVITY = 0;

function SetupEventListener()
{   
    Event_new_map();
    
    local hWorld = Entities.FindByClassname( null, "worldspawn" );
	hWorld.ValidateScriptScope();
	local scWorld = hWorld.GetScriptScope();
	scWorld.ListenForEvents <- function()
    {   
        //if ( !Entities.FindByClassname( null, "player" ) )
        //{
        //    WriteFile( "r_activeplayerlist" + g_strServerNumber, [], "|", 1, "" );
        //    return 2.0;
        //}
        
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
    
    if ( LOG_ACTIVITY )
       LogActivity( hPlayer.GetPlayerName() + " joined the server." );

    WriteFile( "r_activeplayerlist" + g_strServerNumber, g_tActivePlayersList, "|", g_tActivePlayersList.len(), "" );
}

function Event_player_left( nPlayer )
{
    BroadcastMessage( COLOR_RED + g_tActivePlayersList[ nPlayer ] + " left the server.", false, true );
    
    if ( LOG_ACTIVITY )
      LogActivity( g_tActivePlayersList[ nPlayer ] + " left the server." );

    g_tActivePlayersList.remove( nPlayer );
    WriteFile( "r_activeplayerlist" + g_strServerNumber, g_tActivePlayersList, "|", g_tActivePlayersList.len(), "" );
}

function Event_new_map()
{
    if ( !Entities.FindByClassname( null, "player" ) )
        return;
    
    if ( LOG_ACTIVITY )
        LogActivity( "Map changed to " + g_strCurMap );

    BroadcastMessage( COLOR_YELLOW + "Map changed to " + g_strCurMap, false, true );
}