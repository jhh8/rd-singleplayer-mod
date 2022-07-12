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
		for ( local i = 0; i < lb_length - 2; i += 2 )	// nubic selection sort
		{
			local _steamid = leaderboard[i];
			local _time = leaderboard[i+1];
			
			for ( local j = i + 2; j < lb_length; j += 2 )
			{
				if ( _time > leaderboard[j+1] )
				{
					leaderboard[i] = leaderboard[j];
					leaderboard[j] = _steamid;
					_steamid = leaderboard[i];

					leaderboard[i+1] = leaderboard[j+1];
					leaderboard[j+1] = _time;
					_time = leaderboard[i+1];
				}
			}
		}

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

			if ( previous_time != -1 && data[1] > previous_time )
				return [ -1, -1, -1 ];
		}

		local output_leaderboard = CalculateLeaderboard( leaderboard, map_rating, map_precision );
		WriteFile( filename, output_leaderboard, "|", 3, "" );

		if ( caller_steamid )
		{
			if ( prev_placement != 0 && new_placement >= prev_placement )
				return [ -1, -1, previous_time - data[1] ];
			
			return [ prev_placement, new_placement, previous_time - data[1] ];
		}
	}

	return [ 0, 0, -1 ];
}

//					  0,     1,     2,     3,     4,     5,     6,     7,     8,     9,    10
g_arrPrecision <- [ 0.995, 0.993, 0.991, 0.988, 0.985, 0.982, 0.977, 0.970, 0.960, 0.950, 0.940 ];

// we recieve a sorted leaderboard array which contains steamid+time
function CalculateLeaderboard( leaderboard, map_rating, map_precision )
{
	local lb_points = [];
	local lb_positions = [];
	local output = [];
	local lb_length = leaderboard.len();
	local map_rating_advanced = map_rating * pow( lb_length / 2, 0.2 );
	local precision_multiplier = g_arrPrecision[ map_precision ];
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
