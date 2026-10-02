-- Regression for CoA map support in Zygor's Astrolabe: CoA sub-maps (starting areas,
-- caves, custom zones) must resolve to real zone data, and a player position read on a
-- sub-map must land where the same moment's parent-zone reading does.
-- Usage: lua test_astrolabe_coa_maps.lua <addon directory> <CoAMapProbe.lua saved variables> [Astrolabe directory]
-- The optional third argument tests another addon's Astrolabe copy (e.g. TomTom\libs\Astrolabe).
local root = arg[1] or "ZygorGuidesViewerRM"
local probeFile = arg[2]

local function slurp(path)
	local f = assert(io.open(path, "rb"), "cannot open "..path)
	local s = f:read("*a") f:close() return s
end
local astroDir = arg[3] or (root.."/Libs/Astrolabe")
local astro = slurp(astroDir.."/Astrolabe.lua")

-- Probe data: the client's real continent/zone/map-file list and position samples.
dofile(probeFile)
local probe = assert(CoAMapProbeDB, "probe file has no CoAMapProbeDB")

-- Minimal WoW API backed by the probe's map list.
local names, files = {}, {}
for c, cont in ipairs(probe.continents) do
	names[c], files[c] = {}, {}
	for z, rec in ipairs(cont.zones) do names[c][z], files[c][z] = rec.name, rec.mapInfo[1] end
end
function GetMapZones(c) return unpack(names[c] or {}) end
local printed = {}
ChatFrame1 = { AddMessage = function(_, msg) printed[#printed+1] = msg end }

-- Load the generated data and the pieces of Astrolabe.lua the test needs.
dofile(astroDir.."/AstrolabeCoAData.lua")
local function block(first, last)
	local a = assert(astro:find(first, 1, true), "missing "..first)
	local b = assert(astro:find(last, a, true), "missing "..last)
	return astro:sub(a, b - 1)
end
Astrolabe = { ContinentList = {} }
for c = 1, #names do Astrolabe.ContinentList[c] = files[c] end
Astrolabe.ContinentList[5] = { "ScarletEnclave" }
local sqrt = math.sqrt
local env = setmetatable({ sqrt = sqrt }, { __index = _G })
local chunk = assert(loadstring(
	"local sqrt = math.sqrt\n"..
	block("local function getContPosition", "function Astrolabe:TranslateWorldMapPosition")..
	block("WorldMapSize = {", "-- register this library with AstrolabeMapMonitor")..
	"\nreturn WorldMapSize"))
setfenv(chunk, env)
local WorldMapSize = chunk()
local Astro = env.Astrolabe or Astrolabe

local function zoneIndex(c, file)
	for z, f in ipairs(files[c]) do if f == file then return z end end
	error("map file "..file.." not listed on continent "..c)
end

-- 1. No chat spam, and only maps that cannot sit on a continent stay unresolved.
assert(#printed == 0, "Astrolabe still prints missing-data lines: "..tostring(printed[1]))
local allowed = { ["Xorthal's Lair"] = true, ["Dawnrise Island"] = true, ["Glorious Azzar Faire"] = true }
for _, name in ipairs(Astrolabe.MissingZoneData) do
	assert(allowed[name], "unexpected map without zone data: "..name)
end

-- 2. Every listed map on continents 1-4 other than those has real dimensions.
for c = 1, 4 do
	for z, file in ipairs(files[c]) do
		local d = WorldMapSize[c][z]
		if not allowed[names[c][z]] then
			assert(d and d.width > 0 and d.height > 0, ("no size for %s (%s)"):format(names[c][z], file))
		end
	end
end

-- 3. Probe samples: the sub-map reading and the parent-zone reading are the same place.
local checked = 0
for _, sample in ipairs(probe.samples) do
	local sub = sample.current
	for _, on in ipairs(sample.onMaps) do
		if on.zone > 0 and on.continent == sub.continent and on.zone ~= sub.zone then
			local d = Astro:ComputeDistance(sub.continent, sub.zone, sub.pos[1], sub.pos[2],
				on.continent, on.zone, on.x, on.y)
			assert(d and d < 5, ("sample %s: %s vs %s differ by %s yards"):format(
				sample.time, tostring(sub.mapInfo[1]), tostring(on.mapInfo[1]), tostring(d)))
			checked = checked + 1
		end
	end
end
assert(checked >= 2, "expected at least two sub-map/parent comparisons, got "..checked)

-- 4. The Blood Elf guide's first target (Eversong Woods 38.0,21.0) is a short walk
--    from the first sample, which was taken beside Magistrix Erona.
local note = ""
if probe.samples[1].realZone == "Sunstrider Isle" then
	local s1 = probe.samples[1].current
	local ev = zoneIndex(2, "EversongWoods")
	local d = Astro:ComputeDistance(s1.continent, s1.zone, s1.pos[1], s1.pos[2], 2, ev, 0.380, 0.210)
	assert(d and d < 80, "guide target distance from the quest giver is "..tostring(d).." yards")
	note = (", guide target %.0f yards away"):format(d)
end

if astro:find("function Astrolabe:GetCurrentMapCZ()", 1, true) then
	local f = assert(loadstring(block("function Astrolabe:GetCurrentMapCZ()", "--*****")))
	setfenv(f, env) f()
	local A = env.Astrolabe or Astrolabe
	local sun = zoneIndex(2, "sunstriderislestart")
	env.GetCurrentMapContinent = function() return 2 end
	env.GetCurrentMapZone = function() return 1241 end
	env.GetMapInfo = function() return "sunstriderislestart" end
	local c, z = A:GetCurrentMapCZ()
	assert(c == 2 and z == sun, "map ID 1241 not translated to the Sunstrider Isle zone index")
	env.GetCurrentMapZone = function() return sun end
	assert(select(2, A:GetCurrentMapCZ()) == sun, "a valid zone index must pass through")
	note = note..", 1241 -> zone "..sun
end
-- Zygor's copy does the same translation in its global GetCurrentMapContinentAndZone().
if astro:find("function GetCurrentMapContinentAndZone()", 1, true) and astro:find("Conquest of Azeroth clients can report a map ID", 1, true) then
	local f = assert(loadstring(block("function GetCurrentMapContinentAndZone()", "\nend\n").."\nend\n"))
	setfenv(f, env) f()
	local sun = zoneIndex(2, "sunstriderislestart")
	env.GetCurrentMapContinent = function() return 2 end
	env.GetCurrentMapZone = function() return 1241 end
	env.GetMapInfo = function() return "sunstriderislestart" end
	local c, z = env.GetCurrentMapContinentAndZone()
	assert(c == 2 and z == sun, "map ID 1241 not translated by GetCurrentMapContinentAndZone")
	env.GetCurrentMapZone = function() return sun end
	assert(select(2, env.GetCurrentMapContinentAndZone()) == sun, "a valid zone index must pass through")
	note = note..", 1241 -> zone "..sun
end
print(("CoA Astrolabe map regression passed (%d sample checks%s) [%s]"):format(checked, note, astroDir))
