-- Regression for HealBot 3.3.5.4 with Conquest of Azeroth classes: the class-keyed lookups HealBot
-- makes for the player and for party members must not fail for a CoA class (Chronomancer = "CHRO").
-- Loads HealBot's own files with stand-ins for the game API.
-- Usage: lua test_healbot_coa.lua <HealBot addon directory>
local dir = arg[1] .. "/"
local realPrint = print

-- Any game global HealBot touches while loading is a harmless stand-in: callable, indexable, and
-- returning stand-ins.
local Stub = setmetatable({}, {})
getmetatable(Stub).__index = function() return Stub end
getmetatable(Stub).__call = function() return Stub end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
	getmetatable(Stub)[op] = function() return 0 end
end
getmetatable(Stub).__concat = function(a, b) return (a == Stub and "" or tostring(a)) .. (b == Stub and "" or tostring(b)) end
setmetatable(_G, { __index = function(_, k) return Stub end })

-- WoW's aliases for the standard library
strsub, strlen, strlower, strupper, strfind, strmatch, strrep = string.sub, string.len, string.lower, string.upper, string.find, string.match, string.rep
format, gsub, tinsert, tremove, getn, floor, ceil = string.format, string.gsub, table.insert, table.remove, table.getn, math.floor, math.ceil
GetLocale = function() return "enUS" end
GetScreenHeight, GetScreenWidth = function() return 768 end, function() return 1024 end
GetCVar = function() return "1" end
local classes = {}
UnitClass = function(unit) local c = classes[unit] if c then return c[1], c[2] end end
RAID_CLASS_COLORS = { CHRONOMANCER = { r = 0.2, g = 0.6, b = 0.5 } }
print = function() end

dofile(dir .. "Locale/HealBot_Localization.en.lua")
dofile(dir .. "HealBot_Data.lua")
dofile(dir .. "HealBot.lua")
dofile(dir .. "HealBot_Action.lua")
dofile(dir .. "HealBot_Options.lua")

local function Copy(t, seen)
	if type(t) ~= "table" or t == Stub then return t end
	seen = seen or {}
	if seen[t] then return seen[t] end
	local c = {}
	seen[t] = c
	for k, v in pairs(t) do c[k] = Copy(v, seen) end
	return c
end
local function Keys(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- 1-2. HoT watch: a CoA player gets the Warrior's defaults; configuring them doesn't fail.
HealBot_Globals = Copy(HealBot_GlobalsDefaults)
assert(HealBot_GlobalsDefaults.WatchHoT.CHRO == nil, "no CoA defaults before")
HealBot_configClassHoT("CHRO", "Hum")
local def, warr = HealBot_GlobalsDefaults.WatchHoT.CHRO, HealBot_GlobalsDefaults.WatchHoT.WARR
assert(def and Keys(def) == Keys(warr) and Keys(def) > 0, "Chronomancer gets the Warrior's HoT-watch defaults")
for name, v in pairs(warr) do assert(def[name] == v, "same value for " .. tostring(name)) end
assert(type(HealBot_Globals.WatchHoT.CHRO) == "table", "saved HoT-watch table created")
-- the login loop that failed (HealBot_Update_Skins): fill the saved settings from the defaults
HealBot_CoA_EnsureClassHoTwatch("CHRO")
for name, x in pairs(HealBot_GlobalsDefaults.WatchHoT.CHRO) do
	if not HealBot_Globals.WatchHoT.CHRO[name] then HealBot_Globals.WatchHoT.CHRO[name] = x end
end
assert(Keys(HealBot_Globals.WatchHoT.CHRO) == Keys(warr), "saved settings filled")
HealBot_configClassHoT("CHRO", "Hum") -- again, with settings present
-- stock classes untouched
HealBot_configClassHoT("PRIE", "Hum")
assert(HealBot_GlobalsDefaults.WatchHoT.PRIE ~= def, "priest keeps its own defaults")

-- 5. Class colours for party members: the client's colour for CoA classes, HealBot's own for
--    stock classes, white for a class with no colour anywhere.
classes.party1 = { "Chronomancer", "CHRONOMANCER" }
classes.party2 = { "Druid", "DRUID" }
classes.party3 = { "Something", "SOMETHINGNEW" }
local r, g, b = HealBot_Action_ClassColour(nil, "party1")
assert(r == 0.2 and g == 0.6 and b == 0.5, "Chronomancer colour from RAID_CLASS_COLORS")
r, g, b = HealBot_Action_ClassColour(nil, "party2")
assert(r == 1.0 and g == 0.49 and b == 0.04, "druid colour from HealBot's table")
r, g, b = HealBot_Action_ClassColour(nil, "party3")
assert(r == 1 and g == 1 and b == 1, "unknown class: white")
r, g, b = HealBot_Action_ClassColour(nil, "nobody")
assert(r == 0.78 and g == 0.61 and b == 0.43, "no unit: warrior colour as before")

-- 3. Class buff list for a CoA player: empty, no error.
HealBot_PlayerClassEN = "CHRONOMANCER"
HealBot_Options_InitBuffClassList()
-- 4. Cure spells: none for a CoA class; stock lists unchanged.
assert(#HealBot_Options_GetDebuffSpells_List("CHRO") == 0, "no cure spells for a CoA class")
assert(#HealBot_Options_GetDebuffSpells_List("PALA") > 0, "paladin cure spells unchanged")

-- 6. Ignored class debuffs: a CoA party member's class falls back to an empty list (inside the
--    debuff scan, which needs a running client; checked in the source).
local src = io.open(dir .. "HealBot.lua", "rb"):read("*a")
assert(src:find("HealBot_Ignore_Class_Debuffs%[strsub%(DebuffClass,1,4%)%] or HealBot_CoA_NoIgnoredDebuffs"), "ignored-debuff lookup has its fallback")

realPrint("HealBot CoA class regression passed")
