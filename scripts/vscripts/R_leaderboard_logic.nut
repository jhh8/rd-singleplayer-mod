// mode is "rs" or "hs", data is one player's steamid and time (data len == 2), bForceBuild == false when the function is called by completing a mission
// returns an array of three numbers. first one is previous placement, second one is new placement, third one is time improvement.
// returns 0 if that person doesnt have an entry on the leaderboard, returns -1 if that person does have an entry but didnt improve his placement
function BuildLeaderboard( mode, map_name, map_rating, map_precision, bForceBuild = true, data = [] )
{
	local filename = "r_" + mode + "_leaderboard_" + map_name;
	local leaderboard = CleanList( split( FileToString( filename ), "|" ) );
	local caller_steamid = bForceBuild ? 0 : GetPlayerSteamID();
	local previous_time = -1;
	local time_improvement = -1;
	local prev_placement = 0;
	local new_placement = 0;

	if ( !ValidArray( leaderboard, 3 ) )
	{
		PrintToChat( COLOR_RED + "Internal ERROR: BuildLeaderboard: leaderboard array has invalid length = " + leaderboard.len().tostring() );
		return;
	}

	if ( leaderboard.len() != 0 )
	{
		for ( local i = leaderboard.len() - 1; i > 1; i -= 3 )
		{
			leaderboard[i-1] = leaderboard[i-1].tofloat();
			leaderboard.remove( i );
		}

		if ( caller_steamid )
		{
			for ( local i = 0; i < leaderboard.len(); i += 2 )
			{
				if ( leaderboard[i] == caller_steamid )
				{
					previous_time = leaderboard[i+1];
					prev_placement = i / 2 + 1;

					// remove previous time
					leaderboard.remove(i);
					leaderboard.remove(i);

					// i -= 2;

					break;
				}
			}
		}
	}

	if ( data.len() != 0 )
	{
		data[1] = data[1].tofloat();
		
		leaderboard.push( data[0] );
		leaderboard.push( data[1] );
	}

	local lb_length = leaderboard.len();
	if ( lb_length != 0 )
	{
		SortArray2( leaderboard, false );

		// case 1: first entry - write leaderboard
		// case 2: not first entry, time not improved, placement not improved too then - dont write leaderboard
		// case 3: not first entry, time improved, placement not improved - write leaderboard
		// case 4: not first entry, time improved, placement improved - write leaderboard
		if ( caller_steamid )
		{
			for ( local i = 0; i < leaderboard.len(); i += 2 )
			{
				if ( leaderboard[i] == caller_steamid )
				{
					new_placement = i / 2 + 1;
					break;
				}
			}

			// case 2, player has not improved his time
			if ( previous_time != -1 && data[1] > previous_time )
				return [ -1, -1, -1 ];
		}

		local output_leaderboard = CalculateLeaderboard( leaderboard, map_rating, map_precision );
		if ( output_leaderboard == null )
			return [ -1, -1, -1 ];

		WriteFile( filename, output_leaderboard, "|", 3, "" );

		if ( caller_steamid )
		{
			// player just got or improved his WR, write the points changed to everybody's profile in that leaderboard
			if ( output_leaderboard[0] == caller_steamid )
			{
				for ( local i = 0; i < output_leaderboard.len(); i += 3 )
					WritePlayersPoints( output_leaderboard[i], mode, map_name, output_leaderboard[i+2] );
			}
			else if ( output_leaderboard[3] == caller_steamid )
			{	// the player improved or got their second place, which means the first player's points could have changed, output_leaderboard[0] = first player's steam id
				WritePlayersPoints( output_leaderboard[0], mode, map_name, output_leaderboard[2] );
				WritePlayersPoints( caller_steamid, mode, map_name, output_leaderboard[5] );
			}
			else
			{	
				if ( prev_placement == 0 )
				{	// player got his first entry, everybody's points will change
					for ( local i = 0; i < output_leaderboard.len(); i += 3 )
						WritePlayersPoints( output_leaderboard[i], mode, map_name, output_leaderboard[i+2] );
				}
				else	// player improved time and/or got a new placement which is top3 or worse, this will only affect their points
				{
					WritePlayersPoints( caller_steamid, mode, map_name, output_leaderboard[ new_placement * 3 - 1 ] );
				}
			}
			
			if ( prev_placement != 0 && new_placement >= prev_placement )
				return [ -1, -1, previous_time - data[1] ];

			return [ prev_placement, new_placement, previous_time - data[1] ];
		}
	}

	return [ 0, 0, -1 ];
}

//			   		    0,     1,     2,     3,     4,     5,     6,     7,     8,     9,    10
//g_arrPrecision <- [ 0.995, 0.993, 0.991, 0.988, 0.985, 0.982, 0.977, 0.970, 0.960, 0.950, 0.940 ];

// we recieve a sorted leaderboard array which contains steamid+time
function CalculateLeaderboard( leaderboard, map_rating, map_precision )
{
	local precision_list = CleanList( split( FileToString( "r_precision_list" ), "|" ) );

	if ( precision_list.len() != 12 )
	{
		PrintToChat( COLOR_RED + "Internal ERROR: CalculateLeaderboard: precision list is wrong length = " + precision_list.len().tostring() );
		return null;
	}

	local reltime_overload = precision_list[11].tofloat();
	local lb_points = [];
	local lb_positions = [];
	local output = [];
	local lb_length = leaderboard.len();
	local map_rating_advanced = map_rating * pow( lb_length / 2, 0.2 );
	local precision_multiplier = precision_list[ map_precision ].tofloat();
	local time_WR = 0;

	if ( lb_length != 0 )
		time_WR = leaderboard[1];

	// make sure people with same time are counted as having the same position
	for ( local i = 1, cur_pos = 1; i < lb_length; i += 2, ++cur_pos )
	{
		if ( i == 1 )
		{
			lb_positions.push( 1 );
			continue;
		}

		if ( leaderboard[i] == leaderboard[i - 2] )
			--cur_pos;

		lb_positions.push( cur_pos );
	}
	
	for ( local i = 0; i < lb_length; i += 2 )
	{
		local points = 0;
		local reltime = !i && lb_length > 2 ? leaderboard[3] / time_WR : time_WR / leaderboard[i+1];

		// dont get too crazy now
		if ( reltime > reltime_overload )
			reltime = reltime_overload;

		// xonotic defrag world championship system is - SCORE = 1000 * (time_of_the_fastest_competitor/your_time) * 0.988 ^ (pos - 1)
		// my system is - SCORE = <map_rating> * (<player_count> ^ 0.2) * (time_of_the_fastest_competitor/your_time) * <precision_multiplier> ^ (pos - 1)
		points = map_rating_advanced * reltime * pow( precision_multiplier, pow( lb_positions[i/2] - 1, 1.0 ) );
		if ( points < map_rating )
			points = map_rating;

		lb_points.push( points );
	}

	for ( local i = 0, j = 0; i < lb_length; i += 2, ++j )
	{
		output.push( leaderboard[i] );
		output.push( leaderboard[i+1] );
		output.push( lb_points[j] );
	}

	return output;
}

function WritePlayersPoints( steamid, mode, map_name, points )
{
	local profile_points = CleanList( split( FileToString( "r_" + mode + "_profile_" + steamid + "_points" ), "|" ) );
	local profile_length = profile_points.len();
	
	if ( !ValidArray( profile_points, 2 ) )
	{
		PrintToChat( COLOR_RED + "Internal ERROR: WritePlayersPoints: profile_points array for player " + steamid + " is invalid length = " + profile_length.tostring() );
		return;
	}

	if ( profile_length == 0 )
	{
		profile_points.push( map_name );
		profile_points.push( points );
	}
	else
	{
		local _bNewMap = true;

		for ( local i = 0; i < profile_length; i += 2 )
		{
			if ( profile_points[i] == map_name )
			{
				profile_points[i+1] = points;
				_bNewMap = false;
			}
		}

		if ( _bNewMap )
		{
			profile_points.push( map_name );
			profile_points.push( points );
		}
	}

	SortArray2( profile_points );

	WriteFile( "r_" + mode + "_profile_" + steamid + "_points", profile_points, "|", 2, "" );

	CalculatePlayersGeneralPoints( steamid, mode );
}

function CalculatePlayersGeneralPoints( steamid, mode )
{
	local profile_points = CleanList( split( FileToString( "r_" + mode + "_profile_" + steamid + "_points" ), "|" ) );
	local profile_length = profile_points.len();
	if ( profile_length == 0 )
	{
		PrintToChat( "MINOR Internal ERROR: CalculatePlayersGeneralPoints: player " + steamid + " doesnt have a points profile" );
		return;
	}

	if ( !ValidArray( profile_points, 2 ) )
	{
		PrintToChat( "MINOR Internal ERROR: CalculatePlayersGeneralPoints: profile_points array for player " + steamid + " is invalid length = " + profile_length.tostring() );
		return;
	}

	local increment = 20;
	local points = 0.0;
	for ( local i = 0; i < ( profile_length - 1 ) / increment + 1; ++i )
		for ( local j = increment * i, maps_count = 1; j < profile_length && maps_count <= increment / 2; j += 2, ++maps_count )
			points += profile_points[j + 1].tofloat() / ( increment * ( pow( 2, i ) ) );

	if ( steamid == g_steam_id )
	{	// points will be written to general profile in UpdatePlayerData function
		g_bPointsChanged <- true;
		g_stat_new_points <- points;
	}
	else
	{
		local player_general_profile = CleanList( split( FileToString( "r_" + mode + "_profile_" + steamid + "_general" ), "|" ) );
		if ( player_general_profile.len() == 0 )
		{
			PrintToChat( "MINOR Internal ERROR: CalculatePlayersGeneralPoints: player " + steamid + " doesnt have a general profile" );	
			return;
		}

		if ( mode == "rs" ) player_general_profile[ Stats.points_relaxed ] = points;
		if ( mode == "hs" ) player_general_profile[ Stats.points_hardcore ] = points;

		WriteFile( "r_" + mode + "_profile_" + steamid + "_general", player_general_profile, "|", 1, "" );
	}

	local leaderboard_points = CleanList( split( FileToString( "r_" + mode + "_leaderboard_points" ), "|" ) );
	local lb_length = leaderboard_points.len();
	local bPlayerFound = false;

	for ( local i = 0; i < lb_length; i += 2 )
	{
		if ( leaderboard_points[i] == steamid )
		{
			leaderboard_points[i+1] = points.tostring();
			bPlayerFound = true;
			break;
		}
	}

	if ( !bPlayerFound )
	{
		leaderboard_points.push( steamid );
		leaderboard_points.push( points.tostring() );
	}

	SortArray2( leaderboard_points );

	WriteFile( "r_" + mode + "_leaderboard_points", leaderboard_points, "|", 2, "" );
}
