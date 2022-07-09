// note: problems on map lana3, that map decides the hacks by random spawns
DoEntFire( "asw_spawner", "AddOutput", "MinSkillLevel 0", 0, null, null );
DoEntFire( "asw_spawner", "AddOutput", "MaxSkillLevel 5", 0, null, null );

g_strAlienClassnames <- [
	"asw_drone",
	"asw_drone_jumper",
	"asw_parasite_defanged",
	"asw_parasite",
	"asw_buzzer",
	"asw_drone_uber",
	"asw_shieldbug",
	"asw_harvester",
	"asw_boomer",
	"asw_mortarbug",
	"asw_ranger",
	"asw_shaman",
	"npc_antlionguard",
	"npc_antlionguard_cavern"
];

hGamerules <- Entities.FindByClassname( null, "asw_gamerules" );

function GetAlienHealth( classname, difficulty = -1 )
{
	if ( difficulty == -1 )
		difficulty = NetProps.GetPropInt( hGamerules, "m_iMissionDifficulty" );
	
	switch ( classname )
	{
		case "asw_drone":
		{
			if ( difficulty <= 3 )
				return 25;
			
			return 8 * difficulty;
		}
		case "asw_drone_jumper":
		{
			if ( difficulty <= 3 )
				return 25;
			
			return 8 * difficulty;
		}
		case "asw_drone_uber":			
			return 100 * difficulty;
		case "asw_ranger":
			return ( 20.2 * difficulty ).tointeger();
		case "asw_shieldbug":	
			return 200 * difficulty;
		case "asw_buzzer":	
			return 6 * difficulty;
		case "asw_boomer":	
			return 160 * difficulty;
		case "asw_parasite":
			return 5 * difficulty;
		case "asw_harvester":	
			return 40 * difficulty;
		case "asw_parasite_defanged":	
			return 2 * difficulty;
		case "asw_mortarbug":
			return 70 * difficulty;
		case "asw_shaman":	
			return ( 11.8 * difficulty ).tointeger();
		case "npc_antlionguard":			
			return 100 * difficulty;
		case "npc_antlionguard_cavern":			
			return 100 * difficulty;
		default:
			return -1;
	}
	
	return -1;
}

function SetDifficulty( value )
{
	NetProps.SetPropInt( hGamerules, "m_iMissionDifficulty", value );

	foreach( classname in g_strAlienClassnames )
	{
		local health = GetAlienHealth( classname );
		
		if ( health != -1 )
		{
			local hAlien = null;
			while ( hAlien = Entities.FindByClassname( hAlien, classname ) )
			{
				hAlien.SetMaxHealth( health );
				hAlien.SetHealth( health );
			}
		}
	}
}