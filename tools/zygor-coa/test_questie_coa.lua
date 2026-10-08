-- Regression for Questie-X on Conquest of Azeroth: Questie-X and its Ascension plugin recognised Ascension
-- only by realm name, so CoA realms with other names (Nozdormu, Felstorm, ...) got neither the Ascension
-- data nor its zone handling. The Ascension client's own API (C_CharacterAdvancement) now counts too.
-- Loads the addons' real files, each in a fresh environment with stand-ins for the game API.
-- Usage: lua test_questie_coa.lua <Questie-X addon directory> <Questie-X-AscensionDB addon directory>
local core, db = arg[1] .. "/", arg[2] .. "/"

-- A fresh global environment: the game API stand-ins plus whatever the case sets.
local function Env(realm, ascensionClient)
	local env = { GetRealmName = function() return realm end, GetCVar = function() return nil end }
	if ascensionClient then env.C_CharacterAdvancement = {} end
	env._G = env
	return setmetatable(env, { __index = _G })
end

local function Load(path, env, ...)
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	return chunk(...)
end

-- Modules/QuestieServer.lua: decides Questie.IsAscension.
local function IsAscension(realm, ascensionClient)
	local env = Env(realm, ascensionClient)
	env.Questie = { Debug = function() end }
	env.QuestieLoader = { CreateModule = function() return {} end }
	Load(core .. "Modules/QuestieServer.lua", env)
	return env.Questie.IsAscension
end
assert(IsAscension("Nozdormu", true) == true, "a CoA realm on the Ascension client is Ascension")
assert(IsAscension("Felstorm", true) == true, "any realm name works on the Ascension client")
assert(IsAscension("Nozdormu", false) == false, "a stock 3.3.5 client is unchanged")
assert(IsAscension("Bronzebeard", false) == true, "Ascension's own realm names still work")

-- Zones/AscensionZoneTables.lua and Zones/AscensionUiMapData.lua: skip themselves unless on Ascension.
local function ZoneTables(realm, ascensionClient)
	local env = Env(realm, ascensionClient)
	Load(db .. "Zones/AscensionZoneTables.lua", env)
	return env.AscensionZoneTables
end
local zt = ZoneTables("Nozdormu", true)
assert(zt and zt.uiMapIdToAreaId and zt.uiMapIdToAreaId[1238] == 12, "zone tables load on CoA (Northshire Valley -> Elwynn)")
assert(ZoneTables("Nozdormu", false) == nil, "zone tables stay off on a stock client")

local function UiMapData(realm, ascensionClient)
	local env = Env(realm, ascensionClient)
	env.print = function() end
	Load(db .. "Zones/AscensionUiMapData.lua", env)
	return env.AscensionUiMapData
end
local um = UiMapData("Nozdormu", true)
assert(um and um.uiMapData and um.uiMapData[2031], "map data loads on CoA (Moonlit Ossuary)")
assert(UiMapData("Nozdormu", false) == nil, "map data stays off on a stock client")

-- Zones/CoAExtraZones.lua: adds map sizes for CoA's own sub-maps (map id = WorldMapArea.ID + 1) on top of the
-- plugin's, and must NOT hand over the plugin's sub-zone folding (that would move whole zones' pins).
do
	local env = Env("Nozdormu", true)
	env.print = function() end
	Load(db .. "Zones/AscensionZoneTables.lua", env)
	Load(db .. "Zones/AscensionUiMapData.lua", env)
	local addonTable = {}
	Load(db .. "Zones/CoAExtraZones.lua", env, "Questie-X-AscensionDB", addonTable)
	local maps = addonTable.uiMapData
	assert(maps and maps[2031] and maps[2031].name == "Moonlit Ossuary", "the plugin's own maps are kept")
	assert(maps[1237] and maps[1237].name == "Jangolode Mine" and maps[1237].instance == 0, "CoA sub-maps are added")
	for i = 1, 4 do assert(type(maps[1237][i]) == "number", "map bounds are numbers") end
	assert(maps[1237][1] > 0 and maps[1237][2] > 0, "width and height are positive")
	assert(addonTable.uiMapIdToAreaId == nil and addonTable.zoneSort == nil, "no sub-zone folding is handed over")
end

-- AscensionLoader.lua: registers the plugin at PLAYER_LOGIN only on Ascension.
local function Registers(realm, ascensionClient)
	local env = Env(realm, ascensionClient)
	env.print = function() end
	local onEvent, registered
	env.CreateFrame = function()
		return { RegisterEvent = function() end, UnregisterEvent = function() end,
		         SetScript = function(self, _, f) onEvent = f end }
	end
	local plugin = setmetatable({}, { __index = function() return function() end end })
	local api = { RegisterPlugin = function(_, name) registered = name; return plugin end }
	env.QuestieLoader = { ImportModule = function(_, name) if name == "QuestiePluginAPI" then return api end end }
	Load(db .. "AscensionLoader.lua", env, "Questie-X-AscensionDB", {})
	assert(onEvent, "the loader waits for PLAYER_LOGIN")
	onEvent({ UnregisterEvent = function() end }, "PLAYER_LOGIN")
	return registered
end
assert(Registers("Nozdormu", true) == "Ascension", "the Ascension plugin registers on CoA")
assert(Registers("Nozdormu", false) == nil, "the Ascension plugin stays off on a stock client")

print("Questie-X CoA detection regression passed")
