# rd-singleplayer-mod
A singleplayer mod for the game Alien Swarm: Reactive Drop.

It is meant to be installed for dedicated servers.

- Note: the mod stores all the information in server's files, so the leaderboards and other stats are seperate for each server. You can transfer the data from server to server by transfering over the saved data from reactivedrop/save/vscripts on your server.

# Game Modes
- Ranked Relaxed Solo - difficulty is 1 player brutal, no tech requirement, any character completes the hack automatically.

- Ranked Hardcore Solo - difficulty is 4 player brutal, aliens speed is like on ASBI, no tech requirement, any character can hack but it's not automatic.

# Map Points
Completing a map puts the person into a leaderboard for that map and game mode.

The person gets points for that map, depending on the map difficulty, their place on the leaderboard and number of people on the leaderboard.

# Individual Points
Individual points are calculated based on the map points. Simply complete more different maps and get better times on them for more individual points.

Completing a map for a second time and getting a slower time will not grant points again, it is not a farming system.

Important note: players also get an additional 7.5 points for completing a map without getting hit or without using grenade launcher and flamethrower. (Max of 15 additional points per map).

# Maps
Each map has a map rating (higher rating for more difficult maps) and a map precision. Higher precision should be set for maps where times will be close to each other.

On higher precision maps, the differences between times will have a bigger impact on distributed points.

New supported maps can be added, map rating and map precision can be changed by the server owner in r_hs_mapratings and r_rs_mapratings files.

# Other Stats
The mod tracks some general stats for each player on each game mode. For example number of aliens killed, number of aliens killed by melee, number of reloads failed, number of kilometers ran etc.

There is also a seperate leaderboard for amount of maps completed without getting hit and without using a flamer and grenade launcher. Once a person completes a map without getting hit or using flamer and grenade launcher, they get notified in chat about that and get a bonus 7.5 individual points.

# Admins
There is a file called r_adminlist which contains steamid's of admins. What admins can do is execute commands with /r_admin prefix.

# Chat Commands
All that information about stats and leaderboards has to be accessed somehow, for that there are chat commands.

- /r profile <name/steamid> <relaxed/hardcore> <general/points/nf+ngl/nohit>
- /r leaderboard <relaxed/hardcore> <mapname/nf+ngl/nohit/points> <close/top/full>
- /r maplist - prints a list of all supported maps
- /r leaderboard - prints current map's and challenge's leaderboard
- /r points - prints current challenge's points leaderboard
- /r profile - prints your current challenge's general profile
