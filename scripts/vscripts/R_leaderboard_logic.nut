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

					// TODO: Remove the slower time from leaderboard

					break;
				}
			}

			if ( previous_time != -1 && data[1] > previous_time )
				return [ -1, -1, -1 ];
		}

		local output_leaderboard = CalculateLeaderboard( leaderboard, map_rating, map_precision );
		WriteFile( filename, output_leaderboard, "|", 3, "" );

		if ( caller_steamid )
			return [ prev_placement, new_placement, previous_time - data[1] ];
	}

	return [ 0, 0, -1 ];
}

// we recieve a sorted leaderboard array which contains steamid+time
function CalculateLeaderboard( leaderboard, map_rating, map_precision )
{
	local lb_points = [];
	local output = [];
	local lb_length = leaderboard.len();
	local time_WR = 0;

	if ( lb_length != 0 )
	{
		time_WR = leaderboard[1];
	}
	
	for ( local i = 0; i < lb_length; i += 2 )
	{
		local points = 0;
		local reltime = leaderboard[i+1] / time_WR;

		// very mathematics here
		points = ( 1 / reltime ) * map_rating;

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