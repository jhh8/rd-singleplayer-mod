IncludeScript( "R_difficulty_fixup.nut" );
IncludeScript( "R_main_shared.nut" );

// 4 player brutal lobby
SetDifficulty( 13 );

Convars.SetValue( "asw_alien_speed_scale_easy", 1.9 );
Convars.SetValue( "asw_marine_speed_scale_easy", 1.048 );
Convars.SetValue( "asw_alien_speed_scale_normal", 1.9 );
Convars.SetValue( "asw_marine_speed_scale_normal", 1.048 );
Convars.SetValue( "asw_alien_speed_scale_hard", 1.9 );
Convars.SetValue( "asw_marine_speed_scale_hard", 1.048 );
Convars.SetValue( "asw_alien_speed_scale_insane", 1.9 );
Convars.SetValue( "asw_marine_speed_scale_insane", 1.048 );