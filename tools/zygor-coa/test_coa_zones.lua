-- Regression for CoAZones.lua: CoA sub-map zones fold into the zone the guides use, and
-- LibRover gets the player's position in its own map IDs (not CoA's native C_Map IDs).
-- Usage: lua test_coa_zones.lua <addon directory> <sunstrider fixture> <human fixture>
local root, sunFile, humanFile = arg[1], arg[2], arg[3]
local function slurp(p) local f = assert(io.open(p, "rb"), p) local s = f:read("*a") f:close() return s end
local astroSrc = slurp(root.."/Libs/Astrolabe/Astrolabe.lua")
local function block(first, last)
	local a = assert(astroSrc:find(first, 1, true), first)
	local b = assert(astroSrc:find(last, a, true), last)
	return astroSrc:sub(a, b - 1)
end

-- LibRover's real zone -> map ID table.
local addon = {}
assert(loadfile(root.."/Libs/LibRover-1.0/data.lua"))("ZygorGuidesViewerRM", addon)
local MapIDsByName = assert(addon.LibRoverData.MapIDsByName)

-- Set up a client from a probe fixture, with the player standing at one of its samples.
local function Client(fixture, sampleIndex, withCoAData)
	CoAMapProbeDB = nil
	dofile(fixture)
	local probe = CoAMapProbeDB
	local names, files = {}, {}
	for c, cont in ipairs(probe.continents) do
		names[c], files[c] = {}, {}
		for z, r in ipairs(cont.zones) do names[c][z], files[c][z] = r.name, r.mapInfo[1] end
	end
	GetMapZones = function(c) return unpack(names[c] or {}) end
	ChatFrame1 = { AddMessage = function() end }
	ZygorAstrolabeCoAZoneData, ZygorCoAZoneParents = nil, nil
	if withCoAData then dofile(root.."/Libs/Astrolabe/AstrolabeCoAData.lua") end
	Astrolabe = { ContinentList = {} }
	for c = 1, #names do Astrolabe.ContinentList[c] = files[c] end
	Astrolabe.ContinentList[5] = { "ScarletEnclave" }
	assert(loadstring("local sqrt=math.sqrt\n"..
		block("local function getContPosition", "--*****************************************************************************")..
		block("WorldMapSize = {", "-- register this library with AstrolabeMapMonitor")))()
	local sample = probe.samples[sampleIndex]
	function Astrolabe:GetCurrentPlayerPosition()
		local cur = sample.current
		return cur.continent, cur.zone, cur.pos[1], cur.pos[2]
	end
	GetRealZoneText = function() return sample.realZone end
	DongleStub = function(name) assert(name == "Astrolabe-0.4-Zygor") return Astrolabe end
	LibRover = { data = { MapIDsByName = MapIDsByName } }
	ZygorGuidesViewer = {}
	dofile(root.."/CoAZones.lua")
	return ZygorGuidesViewer, sample
end

local function near(a, b) return math.abs(a - b) < 0.003 end

-- Sunstrider Isle (Blood Elf start): folds into Eversong Woods, LibRover map 1941.
local ZGV, s = Client(sunFile, 1, true)
assert(ZGV.IsCoAClient(), "CoA client not detected")
assert(ZGV.GetCoAParentZone("Sunstrider Isle") == "Eversong Woods", "Sunstrider Isle parent")
assert(ZGV.GetCoAParentZone("Northshire Valley") == "Elwynn Forest", "Northshire Valley parent")
assert(ZGV.GetCoAParentZone("Coldridge Valley") == "Dun Morogh", "Coldridge Valley parent")
assert(ZGV.GetCoAParentZone("Fargodeep Mine") == "Elwynn Forest", "Fargodeep Mine parent")
assert(ZGV.GetCoAParentZone("Elwynn Forest") == nil, "real zones have no parent")
assert(ZGV.GetCoAParentZone("Dun Kazad") == nil, "CoA-only zones stay their own zone")
assert(ZGV.GetPlayerZoneText() == "Eversong Woods", "player zone should read Eversong Woods")
local map, x, y = ZGV.GetCoAPlayerMapPosition()
local ev = s.onMaps[1]
assert(map == 1941, "LibRover map for Sunstrider Isle should be Eversong Woods (1941), got "..tostring(map))
assert(near(x, ev.x) and near(y, ev.y), ("position %.4f,%.4f vs Eversong reading %.4f,%.4f"):format(x, y, ev.x, ev.y))

-- Northshire (Human start) and Stormwind: LibRover maps 1429 (Elwynn) and Stormwind's own.
ZGV, s = Client(humanFile, 1, true)
assert(ZGV.GetPlayerZoneText() == "Elwynn Forest", "Northshire should read Elwynn Forest")
map, x, y = ZGV.GetCoAPlayerMapPosition()
local elwynn
for _, on in ipairs(s.onMaps) do if on.mapInfo[1] == "Elwynn" then elwynn = on end end
assert(map == 1429 and near(x, elwynn.x) and near(y, elwynn.y), "Northshire position not placed in Elwynn Forest")
ZGV, s = Client(humanFile, 4, true)
assert(ZGV.GetPlayerZoneText() == "Stormwind City", "Stormwind is a zone of its own")
map = ZGV.GetCoAPlayerMapPosition()
assert(map == MapIDsByName["Stormwind City"][0], "Stormwind map ID")

-- Without the CoA data (a stock client) nothing changes.
ZGV = Client(humanFile, 1, false)
assert(not ZGV.IsCoAClient(), "stock client flagged as CoA")
assert(ZGV.GetCoAPlayerMapPosition() == nil, "stock client must keep using C_Map")
assert(ZGV.GetPlayerZoneText() == "Northshire Valley", "stock client zone text must pass through")

-- The guide-engine files read zone names through the fold.
for _, f in ipairs({ "Waypoints.lua", "Goal.lua", "Pointer.lua", "MapSpotSet.lua", "Parser.lua" }) do
	local src = slurp(root.."/"..f):gsub("%-%-[^\n]*", "") -- comments may mention the name
	local shadow = src:find("local GetRealZoneText = function() return ZGV.GetPlayerZoneText", 1, true)
	local firstUse = src:find("GetRealZoneText()", 1, true)
	assert(shadow and shadow < firstUse, f.." does not read zones through ZGV.GetPlayerZoneText")
end

-- Waypoints handed to TomTom use TomTom's zone numbering (area IDs on Ascension/CoA).
do
	local src = slurp(root.."/Waypoints.lua"):gsub("\r\n", "\n")
	local a = assert(src:find("function me:CreateTomTomWaypointCZXY", 1, true), "CreateTomTomWaypointCZXY")
	local b = assert(src:find("\nend\n", a, true))
	local env = setmetatable({}, { __index = _G })
	local got
	env.TomTom = {
		ZoneID = function(self, c, z) return (c == 2 and z == 42) and 1241 or z end,
		AddZWaypoint = function(self, c, z) got = { c, z } return "uid" end,
	}
	env.me = { TomTomWaypoints = {}, CurrentStep = { title = "t" }, Debug = function() end }
	local f = assert(loadstring(src:sub(a, b + 4))) setfenv(f, env) f()
	env.me:CreateTomTomWaypointCZXY(2, 42, 63.5, 45.0, "Sunstrider target")
	assert(got and got[1] == 2 and got[2] == 1241, "Zygor must hand TomTom the area ID, got zone "..tostring(got and got[2]))
	env.TomTom.ZoneID = nil -- an older TomTom without the helper still gets the index
	env.me:CreateTomTomWaypointCZXY(2, 42, 63.5, 45.0, "x")
	assert(got[2] == 42, "without TomTom:ZoneID the index must pass through")
	local live = src:gsub("%-%-%[%[.-%]%]", "")
	local _, calls = live:gsub("TomTom:AddZWaypoint%(", "")
	local _, conversions = live:gsub("TomTom:ZoneID%(contid, zoneid%)", "")
	assert(calls == conversions, ("%d live TomTom:AddZWaypoint calls but %d zone conversions"):format(calls, conversions))
end

print("CoA zone folding regression passed")
