-- Regression for TomTom on Ascension/CoA clients, whose built-in Astrolabe-0.4 identifies
-- zones by map area ID: TomTom must name zones and build waypoints with area IDs there,
-- and keep using zone indexes with a stock Astrolabe.
-- Usage: lua test_tomtom_area_ids.lua <TomTom directory> <CoAMapProbe fixture>
local root, fixture = arg[1], arg[2]
local function slurp(p) local f = assert(io.open(p, "rb"), p) local s = f:read("*a") f:close() return s end
local src = slurp(root.."/TomTom.lua"):gsub("\r\n", "\n")
local first = assert(src:find("local continentMapFile = {", 1, true), "continentMapFile block")
local last = assert(src:find("-- Public functions for plugins to convert between coords", first, true))
local block = src:sub(first, last - 1)
local zlistFirst = assert(src:find("local zlist = {}", 1, true))
local zlistLast = assert(src:find("\nend\n", src:find("for cidx,c in ipairs{GetMapContinents()} do", zlistFirst, true), true))
local zlistBlock = src:sub(zlistFirst, zlistLast + 4).."\nreturn zlist"

dofile(fixture)
local probe = CoAMapProbeDB

local function Client(minor)
	local env = setmetatable({}, { __index = _G })
	local files, names, areas, contAreas = {}, {}, {}, {}
	for c, cont in ipairs(probe.continents) do
		files[c], names[c], areas[c] = {}, {}, {}
		contAreas[c] = cont.map.areaID
		for z, r in ipairs(cont.zones) do files[c][z], names[c][z], areas[c][z] = r.mapInfo[1], r.name, r.areaID end
	end
	local cc, cz = 0, 0
	env.WORLDMAP_COSMIC_ID = -1
	env.SetMapZoom = function(c, z) cc, cz = c, z or 0 end
	env.SetMapToCurrentZone = function() cc, cz = 2, 42 end
	env.GetCurrentMapContinent = function() return cc end
	env.GetCurrentMapZone = function() return cz end
	env.GetCurrentMapAreaID = function() return cz == 0 and contAreas[cc] or areas[cc][cz] end
	env.GetMapContinents = function() local t = {} for c = 1, #names do t[c] = probe.continents[c].name end return unpack(t) end
	env.GetMapZones = function(c) return unpack(names[c] or {}) end
	-- World positions: area ID * 1000 + map fraction * 1000, enough to tell points apart.
	env.C_WorldMap = { GetWorldPosition = function(area, x, y)
		if area == 9999 then return nil end
		return area * 1000 + x * 1000, area * 1000 + y * 1000
	end }
	env.Astrolabe = {
		ContinentList = files,
		GetVersion = function() return "Astrolabe-0.4", minor end,
		-- Ascension's ComputeDistance, including its bail-out on a zero delta.
		ComputeDistance = function(self, c1, z1, x1, y1, c2, z2, x2, y2)
			local ax, ay = env.C_WorldMap.GetWorldPosition(z1 or 0, x1, y1)
			local bx, by = env.C_WorldMap.GetWorldPosition(z2 or 0, x2, y2)
			if not (ax and ay and bx and by) then return nil end
			local dx, dy = bx - ax, by - ay
			if dx == 0 or dy == 0 then return nil end
			return math.sqrt(dx * dx + dy * dy), dx, dy
		end,
	}
	env.TomTom = {}
	local f = assert(loadstring(block)) setfenv(f, env) f()
	local z = assert(loadstring(zlistBlock)) setfenv(z, env)
	return env.TomTom, env, z()
end

-- Ascension's Astrolabe (infinite version): area IDs throughout.
local T, env, zlist = Client(math.huge)
local sunIndex, sunArea = 42, 1241
assert(T:ZoneID(2, sunIndex) == sunArea, "zone index 42 should translate to area 1241")
assert(T:GetMapFile(2, sunArea) == "sunstriderislestart", "area 1241 should name sunstriderislestart")
assert(T:GetMapFile(2, 463) == "EversongWoods", "area 463 should name EversongWoods")
local c, z = T:GetCZ("sunstriderislestart")
assert(c == 2 and z == sunArea, "GetCZ should give area IDs")
assert(select(2, T:GetCZ("Elwynn")) == 31, "Elwynn Forest is area 31")
assert(T:GetMapFile(2, 0) == "Azeroth", "continent maps keep zone 0")
env.SetMapZoom(2, sunIndex)
c, z = T:CurrentCZ()
assert(c == 2 and z == sunArea, "current map should report area 1241")
env.SetMapZoom(2, 0)
assert(select(2, T:CurrentCZ()) == 0, "a continent map should still report zone 0")
assert(zlist["sunstriderisle"][2] == sunArea and zlist["elwynnforest"][2] == 31, "/way zone list should hold area IDs")
-- A small area ID that is also a valid zone index must not be read as an index.
assert(T:GetMapFile(1, 44) == "Ashenvale", "area 44 is Ashenvale, not the 44th Kalimdor zone")

-- Movement along one axis must not lose the distance (Ascension's zero-delta bail-out
-- made its minimap update drop every icon, hiding the TomTom arrow while moving).
local A = env.Astrolabe
local d, dx, dy = A:ComputeDistance(2, 1241, 0.50, 0.40, 2, 1241, 0.50, 0.45)
assert(d and dx == 0 and math.abs(dy - 50) < 1e-6 and math.abs(d - 50) < 1e-6, "zero east-west delta lost its distance")
d, dx, dy = A:ComputeDistance(2, 1241, 0.50, 0.40, 2, 1241, 0.53, 0.44)
assert(math.abs(d - 50) < 1e-6 and math.abs(dx - 30) < 1e-6, "ordinary distances must pass through unchanged")
assert(A:ComputeDistance(2, 9999, 0.5, 0.5, 2, 1241, 0.5, 0.6) == nil, "an unplaceable position must still give no distance")

-- Stock Astrolabe: zone indexes, as before.
T, env, zlist = Client(107)
assert(env.Astrolabe.ComputeDistance(env.Astrolabe, 2, 1241, 0.5, 0.4, 2, 1241, 0.5, 0.45) == nil,
	"a stock Astrolabe must be left untouched")
assert(T:ZoneID(2, sunIndex) == sunIndex, "stock Astrolabe keeps zone indexes")
assert(T:GetMapFile(2, sunIndex) == "sunstriderislestart", "stock lookup by index")
assert(select(2, T:GetCZ("sunstriderislestart")) == sunIndex, "stock GetCZ gives indexes")
env.SetMapZoom(2, sunIndex)
assert(select(2, T:CurrentCZ()) == sunIndex, "stock current map reports the index")
assert(zlist["sunstriderisle"][2] == sunIndex, "stock /way zone list holds indexes")

-- Corpse and quest-POI waypoints go through the same helpers.
assert(slurp(root.."/TomTom_Corpse.lua"):find("z = TomTom:ZoneID(c, i)", 1, true), "corpse zone not translated")
assert(slurp(root.."/TomTom_Corpse.lua"):find("c, z = TomTom:CurrentCZ()", 1, true), "corpse death position not translated")
assert(slurp(root.."/TomTom_POIIntegration.lua"):find("TomTom:CurrentCZ()", 1, true), "quest POI zone not translated")

print("TomTom area-ID regression passed")
