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

-- Modules/FramePool/QuestieFramePool.lua: a recycled pin frame must get its global name back. The unload
-- functions clear _G[name], and Questie finds a quest's pins through _G[name]; without the global a reused
-- frame could never be unloaded, so finished objectives and turned-in '?' markers stayed until /reload.
do
	local env = Env("Nozdormu", true)
	local modules = {}
	local function module(name)
		modules[name] = modules[name] or (name == "l10n" and setmetatable({}, { __call = function(_, s) return s end }) or {})
		return modules[name]
	end
	env.QuestieLoader = { CreateModule = function(_, n) return module(n) end, ImportModule = function(_, n) return module(n) end }
	env.QuestieCompat = { C_Timer = {}, WorldMapFrame = {}, HBDPins = {} }
	env.CreateFrame = function() return {} end
	env.Minimap = {}
	env.StaticPopupDialogs = {}
	env.tinsert, env.tremove = table.insert, table.remove
	Load(core .. "Modules/FramePool/QuestieFramePool.lua", env)
	local pool = modules.QuestieFramePool
	local count = 0
	pool.Qframe = { New = function(_, id)
		count = count + 1
		local name = "QuestieFrame" .. id
		local frame = { frameId = id, GetName = function() return name end, SetScript = function() end }
		env[name] = frame  -- CreateFrame with a name sets the global
		return frame
	end }
	local frame = pool:GetFrame()
	local name = frame:GetName()
	assert(env[name] == frame, "a new pin frame has its global")
	env[name] = nil              -- what UnloadQuestFramesForObjective / ByDataType / by icon type do
	pool:RecycleFrame(frame)
	local again = pool:GetFrame()
	assert(again == frame and count == 1, "the pool reuses the frame")
	assert(env[name] == frame, "a recycled pin frame gets its global name back (stale map pins otherwise)")
end

-- Modules/QuestieInit.lua LoadDatabase: base tables that a database plugin supplied as <key>Overrides must not
-- be flagged "missing" (that forced Runtime mode: Learner and its fallback positions drew duplicate pins).
do
	local Stub = setmetatable({}, {})
	getmetatable(Stub).__index = function() return Stub end
	getmetatable(Stub).__call = function() return Stub end
	local function LoadBase(overrides)
		local env = setmetatable({}, { __index = function(_, k) return _G[k] ~= nil and _G[k] or Stub end })
		env._G = env
		local QuestieDB = { npcDataOverrides = overrides and { [197] = {} } or {}, objectDataOverrides = overrides and { [1] = {} } or {},
		                    questDataOverrides = overrides and { [7] = {} } or {}, itemDataOverrides = overrides and { [1] = {} } or {} }
		local modules = { QuestieDB = QuestieDB }
		env.QuestieLoader = { CreateModule = function(_, n) modules[n] = modules[n] or { private = {} }; return modules[n] end,
		                      ImportModule = function(_, n) modules[n] = modules[n] or setmetatable({}, getmetatable(Stub)); return modules[n] end }
		env.Questie = setmetatable({ Debug = function() end, db = { profile = {} } }, { __index = function() return Stub end })
		Load(core .. "Modules/QuestieInit.lua", env)
		modules.QuestieInit:LoadBaseDB()
		return QuestieDB.baseDatabaseMissing, QuestieDB
	end
	local missing, db = LoadBase(true)
	assert(missing == false, "plugin-supplied tables are not 'missing' (no forced Learner mode)")
	assert(type(db.npcData) == "table", "the base tables still exist (empty)")
	assert(LoadBase(false) == true, "with no plugin data the base DB is still reported missing")
end

-- Compat/Compat.lua: turning in a quest whose same-named follow-up is already in the log must resolve to the
-- COMPLETE quest, not the follow-up (that one was marked turned in and its objectives froze until /reload).
do
	local Stub = setmetatable({}, {})
	getmetatable(Stub).__index = function() return Stub end
	getmetatable(Stub).__call = function() return Stub end
	local env = setmetatable({}, { __index = function(_, k) return _G[k] ~= nil and _G[k] or Stub end })
	env._G = env
	local modules = {}
	env.QuestieLoader = { CreateModule = function(_, n) modules[n] = modules[n] or { private = {} }; return modules[n] end,
	                      ImportModule = function(_, n) modules[n] = modules[n] or setmetatable({ private = {} }, getmetatable(Stub)); return modules[n] end }
	env.ERR_QUEST_COMPLETE_S, env.DAILY_QUESTS_REMAINING = "%s completed.", "You have completed %d daily quests today."
	env.QuestieCompat = {}   -- created by Modules/QuestieCompat.lua, which loads first
	-- the log: part 1 (complete, being turned in) and part 2 (just accepted, same title, not complete)
	local log = { { "The People's Militia", 12, 1 }, { "The People's Militia", 13, nil } }
	env.GetNumQuestLogEntries = function() return #log end
	env.GetQuestLogTitle = function(i)
		local e = log[i]; if not e then return end
		return e[1], 12, nil, nil, false, false, e[3], false, e[2]   -- title, level, tag, group, header, collapsed, complete, daily, id
	end
	env.GetNumQuestLeaderBoards = function() return 2 end
	env.GetQuestLogRequiredMoney = function() return 0 end
	local ok, err = pcall(Load, core .. "Compat/Compat.lua", env); if not ok then print("Compat load error: " .. tostring(err)) end
	local QC = rawget(env, "QuestieCompat")
	assert(QC and QC.GetCompletedQuestIDFromName, "Compat.lua defines GetCompletedQuestIDFromName")
	assert(QC.GetCompletedQuestIDFromName("The People's Militia") == 12, "the complete quest is the one turned in, not the follow-up")
	log = { { "The People's Militia", 13, nil } }   -- part 1 already gone, only the follow-up left
	assert(QC.GetCompletedQuestIDFromName("The People's Militia") == nil, "a fresh follow-up is never taken for the turned-in quest")
end

-- Modules/Quest/QuestieQuest.lua UpdateQuest: when Questie's quest cache hands out a NEW copy of a tracked quest,
-- the tracker must be re-linked to it (it stayed on the old copy, frozen at 0/15 until /reload), and the old
-- copy's pins removed first so the redraw doesn't duplicate them.
do
	local Stub = setmetatable({}, {})
	getmetatable(Stub).__index = function() return Stub end
	getmetatable(Stub).__call = function() return Stub end
	local env = setmetatable({}, { __index = function(_, k) return _G[k] ~= nil and _G[k] or Stub end })
	env._G = env
	local oldCopy = { Id = 14, LocalizedName = "The People's Militia", Objectives = { { isUpdated = true } } }
	local newCopy = { Id = 14, Objectives = { { isUpdated = true } } }
	local unloaded = {}
	local modules = {
		QuestieDB = { GetQuest = function() return newCopy end, IsComplete = function() return 0 end },
		QuestiePlayer = { currentQuestlog = { [14] = oldCopy } },
		QuestieMap = { UnloadQuestFrames = function(_, id) unloaded[#unloaded + 1] = id end },
	}
	env.QuestieLoader = { CreateModule = function(_, n) modules[n] = modules[n] or { private = {} }; return modules[n] end,
	                      ImportModule = function(_, n) modules[n] = modules[n] or setmetatable({ private = {} }, getmetatable(Stub)); return modules[n] end }
	env.Questie = setmetatable({ Debug = function() end, db = { char = { complete = {} }, profile = {} } }, { __index = function() return Stub end })
	env.QuestieCompat = setmetatable({}, getmetatable(Stub))
	local ok, err = pcall(Load, core .. "Modules/Quest/QuestieQuest.lua", env)
	assert(ok, "QuestieQuest.lua loads: " .. tostring(err))
	local QQ = modules.QuestieQuest
	QQ:SetObjectivesDirty(14)
	assert(oldCopy.Objectives[1].isUpdated == false, "the tracker's old copy is marked dirty too")
	pcall(QQ.UpdateQuest, QQ, 14)
	assert(modules.QuestiePlayer.currentQuestlog[14] == newCopy, "the tracker is re-linked to Questie's current copy")
	assert(newCopy.LocalizedName == "The People's Militia", "the display name carries over")
	assert(unloaded[1] == 14, "the old copy's map pins are removed before the redraw")
end

-- Database/QuestieDB.lua Initialize: building the DB handles yields. QuestieDB.QueryNPC used to hold the NPC
-- handle (a table) while the quest/object/item handles were built, so an NPC lookup from an event in that
-- window (the Learner's combat log) failed with "attempt to call field 'QueryNPC' (a table value)".
do
	local Stub = setmetatable({}, {})
	getmetatable(Stub).__index = function() return Stub end
	getmetatable(Stub).__call = function() return Stub end
	local env = setmetatable({}, { __index = function(_, k) return _G[k] ~= nil and _G[k] or Stub end })
	env._G = env
	local built = {}
	local compiler = {
		BuildSkipMap = function() return {} end,
		GetDBHandle = function()
			local handle = { Query = function() return "row" end, QuerySingle = function() end, pointers = {} }
			built[#built + 1] = handle
			coroutine.yield()   -- what safeYield does while the handle is decoded
			return handle
		end,
	}
	local modules = { DBCompiler = compiler }
	env.QuestieLoader = { CreateModule = function(_, n) modules[n] = modules[n] or { private = {} }; return modules[n] end,
	                      ImportModule = function(_, n) modules[n] = modules[n] or setmetatable({ private = {} }, getmetatable(Stub)); return modules[n] end }
	env.Questie = setmetatable({ Debug = function() end, IsSoD = false, db = { global = {}, char = {}, profile = {} } },
	                           { __index = function() return Stub end })
	env.StaticPopupDialogs = {}
	local ok, err = pcall(Load, core .. "Database/QuestieDB.lua", env)
	assert(ok, "QuestieDB.lua loads: " .. tostring(err))
	local QDB = modules.QuestieDB
	local init = coroutine.create(function() QDB:Initialize() end)
	local pauses = 0
	repeat
		local resumed, initErr = coroutine.resume(init)
		assert(resumed, "Initialize runs: " .. tostring(initErr))
		if coroutine.status(init) == "suspended" then
			pauses = pauses + 1
			for _, field in ipairs({ "QueryNPC", "QueryQuest", "QueryObject", "QueryItem" }) do
				assert(type(QDB[field]) == "function", "QuestieDB." .. field .. " stays callable while the DB is built")
			end
		end
	until coroutine.status(init) == "dead"
	assert(pauses == 4, "each handle build yielded once")
	assert(QDB.QueryNPC == built[1].Query and QDB.QueryItem == built[4].Query, "the built handles are published at the end")
end

-- Modules/QuestieLearner.lua OnQuestAccepted (and the kill-credit spawn lookup in QuestieQuestPrivates.lua): a
-- kill-credit IdList can hold nested id lists; comparing those entries with 0 raised "attempt to compare number
-- with table". Nested ids are used, non-numbers skipped.
do
	local Stub = setmetatable({}, {})
	getmetatable(Stub).__index = function() return Stub end
	getmetatable(Stub).__call = function() return Stub end
	local env = setmetatable({}, { __index = function(_, k) return _G[k] ~= nil and _G[k] or Stub end })
	env._G = env
	local objective = { Type = "killcredit", IdList = { { 257, 0 }, "text" }, Id = { 257 } }
	local modules = {
		QuestieDB = { GetQuest = function() return { ObjectiveData = { objective } } end,
		              GetNPC = function(_, id) return id == 257 and { name = "Kobold Vermin" } or nil end },
	}
	env.QuestieLoader = { CreateModule = function(_, n) modules[n] = modules[n] or { private = {} }; return modules[n] end,
	                      ImportModule = function(_, n) modules[n] = modules[n] or setmetatable({ private = {} }, getmetatable(Stub)); return modules[n] end }
	env.Questie = setmetatable({ Debug = function() end, db = { char = {}, profile = {}, global = {} } }, { __index = function() return Stub end })
	env.QuestieCompat = { GetQuestLogIndexByID = function() return 1 end,
	                      GetQuestLogTitle = function() return "Kobold Camp Cleanup", 7, nil, false, false, false, false, 7 end }
	env.GetNumQuestLogEntries = function() return 1 end
	env.GetRealZoneText = function() return "" end
	env.GetNumQuestLeaderBoards = function() return 1 end
	env.GetQuestLogLeaderBoard = function() return "Kobold Vermin slain: 0/10", "monster", false end
	env.UnitGUID, env.UnitName, env.UnitExists = function() end, function() end, function() return false end
	local ok, err = pcall(Load, core .. "Modules/QuestieLearner.lua", env)
	assert(ok, "QuestieLearner.lua loads: " .. tostring(err))
	local QL = modules.QuestieLearner
	local mapped
	QL.LearnQuest = function() end
	QL.GetNPCIdByName = function() end
	QL.LearnQuestObjectiveNPC = function(_, questId, npcId) mapped = npcId end
	local accepted, acceptErr = pcall(QL.OnQuestAccepted, QL, nil, 7)
	assert(accepted, "accepting a quest with a nested kill-credit IdList doesn't error: " .. tostring(acceptErr))
	assert(mapped == 257, "the nested NPC id is used for the objective")

	-- the kill-credit spawn lookup (QuestieQuestPrivates.lua killcredit) skips the nested entries instead of erroring
	local penv = setmetatable({}, { __index = function(_, k) return _G[k] ~= nil and _G[k] or Stub end })
	penv._G = penv
	local pmodules = {}
	penv.QuestieLoader = { CreateModule = function(_, n) pmodules[n] = pmodules[n] or { private = {} }; return pmodules[n] end,
	                       ImportModule = function(_, n) pmodules[n] = pmodules[n] or setmetatable({ private = {} }, getmetatable(Stub)); return pmodules[n] end }
	penv.Questie = setmetatable({ Debug = function() end, db = { char = {}, profile = {} } }, { __index = function() return Stub end })
	local pok, perr = pcall(Load, core .. "Modules/Quest/QuestieQuestPrivates.lua", penv)
	assert(pok, "QuestieQuestPrivates.lua loads: " .. tostring(perr))
	local privates = pmodules.QuestieQuest and pmodules.QuestieQuest.private
	local killcredit = privates and privates.objectiveSpawnListCallTable and privates.objectiveSpawnListCallTable.killcredit
	assert(killcredit, "QuestieQuestPrivates.lua exposes the killcredit spawn lookup")
	local lookedUp, lookupErr = pcall(killcredit, 257, { Description = "" }, { IdList = { { 257 }, 258 } })
	assert(lookedUp, "a nested kill-credit IdList doesn't error in the spawn lookup: " .. tostring(lookupErr))
end

-- Modules/Arrow/QuestieArrow.lua UpdateNearestTargets: the arrow re-scans every objective spawn each second. It
-- used to convert every spawn to world coordinates again and keep a table for each, then sort them all (~34 ms
-- a refresh, a stutter on big objectives). Spawn positions are now remembered and only the nearest few kept.
do
	local Stub = setmetatable({}, {})
	getmetatable(Stub).__index = function() return Stub end
	getmetatable(Stub).__call = function() return Stub end
	local env = setmetatable({}, { __index = function(_, k) return _G[k] ~= nil and _G[k] or Stub end })
	env._G = env
	local conversions = 0
	local hbd = {
		GetPlayerWorldPosition = function() return 0, 0, 0 end,
		GetWorldCoordinatesFromZone = function(_, x, y) conversions = conversions + 1; return x * 1000, y * 1000, 0 end,
		GetWorldDistance = function(_, _, oX, oY, dX, dY) return ((dX - oX) ^ 2 + (dY - oY) ^ 2) ^ 0.5 end,
	}
	env.QuestieCompat = { HBD = hbd }
	-- one tracked quest whose objective has 500 spawns; the nearest is spawn 137
	local spawns = {}
	for i = 1, 500 do spawns[i] = { 10 + (i * 7919 % 500) / 10, 50 } end
	local nearest = 1
	for i = 2, 500 do if spawns[i][1] < spawns[nearest][1] then nearest = i end end
	local quest = { Id = 26, name = "Lazy Peons", level = 4, isComplete = false, Objectives = {
		{ Completed = false, spawnList = { [3183] = { Spawns = { [14] = spawns } } } } } }
	local modules = {
		QuestiePlayer = { currentQuestlog = { [26] = quest }, GetCurrentZoneId = function() return 14 end,
		                  GetCurrentUiMapId = function() return 1411 end },
		ZoneDB = { GetUiMapIdByAreaId = function() return 1411 end },
		QuestieQuest = { ShouldHideObjective = function() return false end },
		QuestieDB = { IsComplete = function() return 0 end },
	}
	env.QuestieLoader = { CreateModule = function(_, n) modules[n] = modules[n] or { private = {} }; return modules[n] end,
	                      ImportModule = function(_, n) modules[n] = modules[n] or setmetatable({ private = {} }, getmetatable(Stub)); return modules[n] end }
	env.Questie = setmetatable({ Debug = function() end, db = { char = { TrackedQuests = {}, AutoUntrackedQuests = {} },
	                            profile = { autoTrackQuests = true, debugArrow = false } } }, { __index = function() return Stub end })
	local ok, err = pcall(Load, core .. "Modules/Arrow/QuestieArrow.lua", env)
	assert(ok, "QuestieArrow.lua loads: " .. tostring(err))
	local QA = modules.QuestieArrow
	QA:UpdateNearestTargets()
	local targets = QA:GetTargets()
	assert(#targets >= 1 and #targets <= 3, "only the nearest few targets are kept (got " .. #targets .. ")")
	assert(targets[1].x == spawns[nearest][1], "the nearest spawn is the arrow's target")
	for i = 2, #targets do assert(targets[i - 1].distance <= targets[i].distance, "targets stay in distance order") end
	local first = conversions
	QA:UpdateNearestTargets()
	assert(conversions == first, "spawn world positions are remembered between refreshes (" .. conversions - first .. " new conversions)")
	assert(QA:GetTargets()[1].x == spawns[nearest][1], "the second refresh picks the same target")
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

print("Questie-X CoA regression passed (detection, maps, pins, runtime mode, turn-ins, tracker re-link, DB init window, kill-credit ids, arrow targets)")
