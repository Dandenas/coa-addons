-- Regression for Button Forge 0.9.4 on Conquest of Azeroth: Ascension's collections hold companions
-- without a name, and Util.CacheCompanions must still complete (otherwise Button Forge never sets up
-- ButtonForgeSave), while still waiting for a retry when the companion data hasn't loaded yet.
-- Loads Button Forge's own Util.lua with stand-ins for the game API.
-- Usage: lua test_buttonforge_coa.lua <ButtonForge addon directory>
local dir = arg[1] .. "/"

-- Any game global Util.lua touches while loading is a harmless, callable, indexable stand-in.
local Stub = setmetatable({}, {})
getmetatable(Stub).__index = function() return Stub end
getmetatable(Stub).__call = function() return Stub end
setmetatable(_G, { __index = function() return Stub end })

GetLocale = function() return "enUS" end
BFUtil, BFConst, BFLocales = {}, {}, { enUS = {} }
BFEventFrames = { Full = Stub }

local companions = {}
GetNumCompanions = function(t) return #(companions[t] or {}) end
GetCompanionInfo = function(t, i) local name = companions[t][i]; return i, name ~= false and name or nil end

dofile(dir .. "Util.lua")
local Util = BFUtil

local function Run(critters, mounts)
	companions.CRITTER, companions.MOUNT = critters, mounts
	Util.CompanionsCached = nil
	Util.CacheCompanions()
	return Util.CompanionsCached
end
local function List(n, missing, prefix)
	local t = {}
	for i = 1, n do
		if i <= missing then t[i] = false else t[i] = prefix .. i end   -- false = no name
	end
	return t
end

-- All names present: cached, every companion indexed.
assert(Run(List(5, 0, "Pet"), List(8, 0, "Mount")), "complete data caches")
assert(Util.Mounts.Mount8 == 8 and Util.Critters.Pet5 == 5, "indexes recorded")

-- As in game: 21 of 861 mounts nameless, all 411 pets fine. The cache completes and skips them.
assert(Run(List(411, 0, "Pet"), List(861, 21, "Mount")), "a few nameless mounts no longer block start-up")
local count = 0
for _ in pairs(Util.Mounts) do count = count + 1 end
assert(count == 840, "the 840 named mounts are indexed, got " .. count)

-- Data not loaded yet (most names missing): still waits for the retry, as the original intended.
assert(not Run(List(411, 0, "Pet"), List(861, 700, "Mount")), "mostly nameless = not loaded yet: retry later")
assert(not Run(List(411, 411, "Pet"), List(861, 0, "Mount")), "nameless pets also wait")

-- No companions at all: nothing to wait for.
assert(Run({}, {}), "an empty collection caches")

print("ButtonForge CoA companion-cache regression passed")
