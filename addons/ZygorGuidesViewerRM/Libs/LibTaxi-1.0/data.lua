local _, addon = ...

local data = {}
addon.LibTaxiData = data

data.taxipoints = {
	[2] = {
		["Eastern Plaguelands"] = {
			{name="Light's Hope Chapel", faction="A", npcid=12617, x=75.85, y=53.41, taxinodeID=67, taxicosts={[83]=0, [82]=166, [383]=120}},
			{name="Light's Hope Chapel", faction="H", npcid=12636, x=75.81, y=53.29, taxinodeID=68, taxicosts={[83]=128, [11]=262, [383]=101}},
		},
		["Eversong Woods"] = {
			{name="Fairbreeze Village", faction="H", npcid=44036, x=43.94, y=69.98, taxinodeID=625, taxicosts={[82]=31, [83]=53}},
			{name="Silvermoon City", faction="H", npcid=16192, x=54.37, y=50.73, taxinodeID=82, taxicosts={[83]=65, [625]=31, [631]=24}},
			{name="Falconwing Square", faction="H", npcid=44244, x=46.25, y=46.79, taxinodeID=631, taxicosts={[82]=19}},
		},
		["Ghostlands"] = {
			{name="Tranquillien", faction="H", npcid=16189, x=45.42, y=30.52, taxinodeID=83, taxicosts={[68]=128, [82]=74, [625]=53}},
		},
		["Tirisfal Glades"] = {
			{name="Undercity", faction="H", npcid=4551, x=63.26, y=48.55, taxinodeID=11, taxicosts={[68]=262, [383]=157}},
		},
	},
	[4] = {
		["Borean Tundra"] = {
			{name="Fizzcrank Airstrip", faction="A", npcid=26602, x=56.57, y=20.06, taxinodeID=246, taxicosts={[245]=70, [247]=133, [289]=44, [296]=64, [308]=63, [309]=76}},
			{name="Valiance Keep", faction="A", npcid=26879, x=58.96, y=68.29, taxinodeID=245, taxicosts={[246]=70, [247]=132, [251]=65, [310]=261}},
			{name="Warsong Hold", faction="H", npcid=25288, x=40.36, y=51.40, taxinodeID=257, taxicosts={[258]=87, [259]=72, [289]=41, [310]=270}},
			{name="Bor'gorok Outpost", faction="H", npcid=26848, x=49.65, y=11.05, taxinodeID=259, taxicosts={[257]=72, [258]=77, [289]=58, [308]=56, [309]=47}},
			{name="Taunka'le Village", faction="H", npcid=26847, x=77.76, y=37.77, taxinodeID=258, taxicosts={[257]=87, [259]=77, [289]=71, [256]=113}},
			{name="Transitus Shield", faction="B", npcid=27046, x=33.13, y=34.44, taxinodeID=226, taxicosts={[289]=37}},
			{name="Amber Ledge", faction="B", npcid=24795, x=45.32, y=34.49, taxinodeID=289, taxicosts={[226]=37, [245]=66, [246]=35, [257]=41, [258]=71, [259]=34}},
			{name="Unu'pe", faction="B", npcid=28195, x=78.54, y=51.53, taxinodeID=296, taxicosts={[246]=64, [247]=100, [294]=132}},
		},
		["Crystalsong Forest"] = {
			{name="Windrunner's Overlook", faction="A", npcid=30271, x=72.17, y=80.97, taxinodeID=336, taxicosts={[305]=33, [310]=52, [320]=53}},
			{name="Sunreaver's Command", faction="H", npcid=30269, x=78.54, y=50.41, taxinodeID=337, taxicosts={[305]=26, [310]=55, [320]=33}},
		},
		["Dalaran"] = {
			{name="Dalaran", faction="B", npcid=28674, x=72.18, y=45.77, taxinodeID=310, taxicosts={[245]=261, [251]=100, [252]=122, [257]=270, [260]=73, [294]=159, [305]=67, [308]=212, [320]=54, [334]=32, [335]=39, [336]=52, [337]=55, [340]=123}},
		},
		["Dragonblight"] = {
			{name="Stars' Rest", faction="A", npcid=26881, x=29.18, y=55.32, taxinodeID=247, taxicosts={[244]=123, [245]=132, [246]=129, [251]=80, [252]=89, [294]=70, [296]=100}},
			{name="Fordragon Hold", faction="A", npcid=26877, x=39.52, y=25.91, taxinodeID=251, taxicosts={[244]=86, [247]=73, [252]=65, [305]=118, [310]=65}},
			{name="Wintergarde Keep", faction="A", npcid=26878, x=77.00, y=49.79, taxinodeID=244, taxicosts={[247]=123, [251]=86, [252]=61, [253]=81, [306]=83}},
			{name="Agmar's Hammer", faction="H", npcid=26566, x=37.51, y=45.76, taxinodeID=256, taxicosts={[252]=51, [254]=88, [258]=113, [260]=65, [294]=63}},
			{name="Kor'kron Vanguard", faction="H", npcid=26850, x=43.85, y=16.94, taxinodeID=260, taxicosts={[252]=67, [254]=90, [256]=52, [305]=106, [310]=56}},
			{name="Venomspite", faction="H", npcid=26845, x=76.48, y=62.21, taxinodeID=254, taxicosts={[248]=117, [250]=87, [256]=88, [260]=90, [306]=121}},
			{name="Wyrmrest Temple", faction="B", npcid=26851, x=60.32, y=51.55, taxinodeID=252, taxicosts={[244]=61, [247]=89, [251]=65, [256]=51, [260]=67, [294]=48, [305]=91, [310]=122}},
			{name="Moa'ki", faction="B", npcid=28196, x=48.51, y=74.39, taxinodeID=294, taxicosts={[247]=54, [252]=48, [256]=64, [295]=184, [296]=132, [310]=122}},
		},
		["Grizzly Hills"] = {
			{name="Amberpine Lodge", faction="A", npcid=26880, x=31.31, y=59.11, taxinodeID=253, taxicosts={[184]=116, [185]=83, [244]=81, [255]=83, [306]=66}},
			{name="Westfall Brigade", faction="A", npcid=26876, x=59.89, y=26.68, taxinodeID=255, taxicosts={[185]=80, [253]=83, [306]=92}},
			{name="Conquest Hold", faction="H", npcid=26852, x=21.99, y=64.43, taxinodeID=250, taxicosts={[192]=85, [248]=57, [249]=102, [254]=87, [306]=79}},
			{name="Camp Oneqwah", faction="H", npcid=26853, x=64.96, y=46.93, taxinodeID=249, taxicosts={[191]=105, [192]=49, [250]=97, [304]=99, [306]=92, [307]=92}},
		},
		["Howling Fjord"] = {
			{name="Fort Wildervar", faction="A", npcid=24061, x=60.06, y=16.11, taxinodeID=184, taxicosts={[183]=73, [185]=80, [253]=96, [255]=97}},
			{name="Valgarde Port", faction="A", npcid=23736, x=59.79, y=63.24, taxinodeID=183, taxicosts={[184]=73, [185]=80, [295]=80, [310]=281}},
			{name="Westguard Keep", faction="A", npcid=23859, x=31.26, y=43.98, taxinodeID=185, taxicosts={[183]=80, [184]=80, [253]=83, [255]=80, [295]=36}},
			{name="Camp Winterhoof", faction="H", npcid=24032, x=49.56, y=11.59, taxinodeID=192, taxicosts={[190]=79, [191]=73, [248]=57, [249]=58, [250]=93}},
			{name="Vengeance Landing", faction="H", npcid=27344, x=79.04, y=29.71, taxinodeID=191, taxicosts={[190]=80, [192]=73, [249]=105, [310]=303}},
			{name="New Agamand", faction="H", npcid=24155, x=52.01, y=67.38, taxinodeID=190, taxicosts={[191]=80, [192]=80, [248]=103, [254]=191, [295]=76}},
			{name="Apothecary Camp", faction="H", npcid=26844, x=25.98, y=25.07, taxinodeID=248, taxicosts={[190]=92, [192]=60, [250]=47, [254]=117, [295]=54}},
			{name="Kamagua", faction="B", npcid=28197, x=24.66, y=57.77, taxinodeID=295, taxicosts={[183]=80, [185]=36, [190]=63, [248]=55, [294]=194}},
		},
		["Icecrown"] = {
			{name="The Shadow Vault", faction="A", npcid=30314, x=43.74, y=24.38, taxinodeID=333, taxicosts={[325]=93, [327]=112, [335]=123, [340]=89}},
			{name="The Shadow Vault", faction="H", npcid=30314, x=43.74, y=24.38, taxinodeID=333, taxicosts={[325]=93, [327]=112, [335]=123, [340]=89}},
			{name="Argent Tournament Grounds", faction="B", npcid=33849, x=72.59, y=22.61, taxinodeID=340, taxicosts={[310]=140, [327]=52, [333]=89, [335]=73}},
			{name="Death's Rise", faction="B", npcid=31078, x=19.34, y=47.78, taxinodeID=325, taxicosts={[308]=116, [309]=117, [332]=114, [333]=93, [335]=175}},
			{name="Crusaders' Pinnacle", faction="B", npcid=31069, x=79.41, y=72.36, taxinodeID=335, taxicosts={[310]=70, [325]=168, [333]=123, [334]=32, [340]=97}},
			{name="The Argent Vanguard", faction="B", npcid=30433, x=87.80, y=78.07, taxinodeID=334, taxicosts={[310]=32, [335]=32}},
		},
		["Sholazar Basin"] = {
			{name="River's Heart", faction="B", npcid=28574, x=50.13, y=61.36, taxinodeID=308, taxicosts={[246]=69, [259]=61, [309]=42, [310]=301, [325]=93, [332]=86}},
			{name="Nesingwary Base Camp", faction="B", npcid=28037, x=25.27, y=58.44, taxinodeID=309, taxicosts={[246]=77, [259]=60, [308]=51, [325]=91}},
		},
		["The Storm Peaks"] = {
			{name="Frosthold", faction="A", npcid=29750, x=29.50, y=74.33, taxinodeID=321, taxicosts={[320]=48, [326]=97, [327]=65, [334]=33}},
			{name="Grom'arsh Crash-Site", faction="H", npcid=29757, x=36.19, y=49.39, taxinodeID=323, taxicosts={[320]=87, [324]=96, [326]=51, [327]=37, [334]=79}},
			{name="Camp Tunka'lo", faction="H", npcid=29762, x=65.41, y=50.60, taxinodeID=324, taxicosts={[307]=98, [320]=114, [322]=45, [323]=101, [326]=73}},
			{name="K3", faction="B", npcid=29721, x=40.75, y=84.55, taxinodeID=320, taxicosts={[305]=43, [310]=72, [321]=43, [322]=100, [323]=75, [324]=90, [336]=53, [337]=37}},
			{name="Dun Niffelem", faction="B", npcid=32571, x=62.63, y=60.93, taxinodeID=322, taxicosts={[307]=88, [320]=87, [324]=32, [326]=84}},
			{name="Ulduar", faction="B", npcid=29951, x=44.49, y=28.19, taxinodeID=326, taxicosts={[320]=73, [322]=84, [323]=51, [324]=73, [327]=44}},
			{name="Bouldercrag's Refuge", faction="B", npcid=29950, x=30.65, y=36.32, taxinodeID=327, taxicosts={[321]=78, [323]=40, [326]=44, [333]=112, [340]=61}},
		},
		["Wintergrasp"] = {
			{name="Valiance Landing Camp", faction="A", npcid=30869, x=71.98, y=30.95, taxinodeID=303, taxicosts={[308]=150, [310]=116}},
			{name="Warsong Camp", faction="H", npcid=30870, x=21.62, y=34.95, taxinodeID=332, taxicosts={[308]=86, [325]=114, [335]=159}},
		},
		["Zul'Drak"] = {
			{name="Light's Breach", faction="B", npcid=28618, x=32.18, y=74.39, taxinodeID=306, taxicosts={[244]=83, [249]=105, [250]=74, [253]=83, [254]=121, [304]=43, [305]=39}},
			{name="Ebon Watch", faction="B", npcid=28615, x=14.01, y=73.58, taxinodeID=305, taxicosts={[244]=61, [251]=111, [252]=91, [254]=98, [260]=108, [304]=63, [306]=44, [310]=67, [320]=40, [336]=33, [337]=26}},
			{name="The Argent Stand", faction="B", npcid=28623, x=41.55, y=64.43, taxinodeID=304, taxicosts={[249]=99, [305]=63, [306]=43, [307]=55}},
			{name="Zim'Torga", faction="B", npcid=28624, x=60.04, y=56.71, taxinodeID=307, taxicosts={[249]=92, [304]=55, [322]=88, [324]=98, [331]=55}},
			{name="Gundrak", faction="B", npcid=30569, x=70.46, y=23.28, taxinodeID=331, taxicosts={[307]=55}},
		},
	},
}
