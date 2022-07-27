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
		LogError( COLOR_RED + "Internal ERROR: BuildLeaderboard: leaderboard array has invalid length = " + leaderboard.len().tostring(), filename );
		return [-9, -9, -9];
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

		local output_leaderboard = CalculateLeaderboard( leaderboard, map_rating, map_precision, mode );
		if ( output_leaderboard == null )
			return [ -1, -1, -1 ];

		WriteFile( filename, output_leaderboard, "|", 3, "" );
		
		// just in case always write points to all players
		for ( local i = 0; i < output_leaderboard.len(); i += 3 )
			WritePlayersPoints( output_leaderboard[i], mode, map_name, output_leaderboard[i+2], !!!caller_steamid );

		if ( caller_steamid )
		{	
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
function CalculateLeaderboard( leaderboard, map_rating, map_precision, mode )
{
	local precision_list = CleanList( split( FileToString( "r_precision_list" ), "|" ) );

	if ( precision_list.len() != 15 )
	{
		LogError( COLOR_RED + "Internal ERROR: CalculateLeaderboard: precision list is wrong length = " + precision_list.len().tostring() );
		return null;
	}

	local reltime_overload = precision_list[11].tofloat();
	local lb_points = [];
	local lb_positions = [];
	local output = [];
	local lb_length = leaderboard.len();
	// want the map_rating_advanced to grow slower on harder maps, not on hardcore though
	local map_rating_advanced = 0;
	if ( mode == "hs" )
		map_rating_advanced = map_rating * pow( lb_length / 2, precision_list[13].tofloat() );
	else
		map_rating_advanced = map_rating * pow( ( precision_list[14].tofloat() / map_rating ) * lb_length / 2, precision_list[12].tofloat() );
		
	local precision_multiplier = precision_list[ map_precision ].tofloat();
	local pos_reltime_relevance = 1.0 / pow( 1.0 / ( 1.0 - precision_multiplier ), 0.1 );
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
		reltime = pow( reltime, pos_reltime_relevance );

		// dont get too crazy now
		if ( reltime > reltime_overload )
			reltime = reltime_overload;

		points = map_rating_advanced * pow( reltime, pos_reltime_relevance ) * pow( precision_multiplier, pow( lb_positions[i/2] - 1, pos_reltime_relevance ) );
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

function WritePlayersPoints( steamid, mode, map_name, points, bAdminCommand = false )
{
	local profile_points = CleanList( split( FileToString( "r_" + mode + "_profile_" + steamid + "_points" ), "|" ) );
	local profile_length = profile_points.len();
	
	if ( !ValidArray( profile_points, 2 ) )
	{
		LogError( COLOR_RED + "Internal ERROR: WritePlayersPoints: profile_points array for player " + steamid + " is invalid length = " + profile_length.tostring() );
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

	CalculatePlayersGeneralPoints( steamid, mode, bAdminCommand );
}

// calculates general points WITHOUT the bonus points for nohit/nf+ngl
function CalculatePlayersGeneralPoints( steamid, mode, bAdminCommand = false )
{
	local profile_points = CleanList( split( FileToString( "r_" + mode + "_profile_" + steamid + "_points" ), "|" ) );
	local profile_length = profile_points.len();
	if ( profile_length == 0 )
	{
		LogError( "MINOR Internal ERROR: CalculatePlayersGeneralPoints: player " + steamid + " doesnt have a points profile" );
		return;
	}

	if ( !ValidArray( profile_points, 2 ) )
	{
		LogError( "MINOR Internal ERROR: CalculatePlayersGeneralPoints: profile_points array for player " + steamid + " is invalid length = " + profile_length.tostring() );
		return;
	}

	local increment = 20;
	local points = 0.0;
	for ( local i = 0; i < ( profile_length - 1 ) / increment + 1; ++i )
		for ( local j = increment * i, maps_count = 1; j < profile_length && maps_count <= increment / 2; j += 2, ++maps_count )
			points += profile_points[j + 1].tofloat() / ( increment * ( pow( 2, i ) ) );

	local points_challenges = CalculatePlayersChallengePoints( steamid, mode );
	points += points_challenges;

	if ( steamid == GetPlayerSteamID() )
	{	// points will be written to general profile in UpdatePlayerData function, send the points without challenges added there
		g_bPointsChanged <- true;
		g_stat_new_points <- points - points_challenges;
	}
	else
	{
		local player_general_profile = CleanList( split( FileToString( "r_" + mode + "_profile_" + steamid + "_general" ), "|" ) );
		if ( player_general_profile.len() == 0 )
		{
			LogError( "MINOR Internal ERROR: CalculatePlayersGeneralPoints: player " + steamid + " doesnt have a general profile" );	
			return;
		}

		player_general_profile[ Stats.points ] = points;

		WriteFile( "r_" + mode + "_profile_" + steamid + "_general", player_general_profile, "|", 1, "" );
	}

	UpdatePointsLeaderboard( steamid, mode, points );
}

// note: doesnt get called when a player doesnt improve their time, but we also need to call this when beating a unique map with nohit or nf+ngl, so in that case we call it from R_main_shared.nut
function UpdatePointsLeaderboard( steamid, mode, points )
{
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

function CalculatePlayersChallengePoints( steamid, mode )
{
	local maps_nohit = CleanList( split( FileToString( "r_" + mode + "_profile_" + steamid + "_nohit" ), "|" ) );
	local maps_nfngl = CleanList( split( FileToString( "r_" + mode + "_profile_" + steamid + "_nf+ngl" ), "|" ) );

	return g_bonus_points_per_challenge * ( maps_nohit.len() + maps_nfngl.len() );
}
