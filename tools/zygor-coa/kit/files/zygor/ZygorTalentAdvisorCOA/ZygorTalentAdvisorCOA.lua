-- Zygor Talent Advisor for Conquest of Azeroth.
--
-- CoA classes don't use WotLK talent trees, so the stock ZygorTalentAdvisor stays idle for
-- them. This module follows a leveling build for the character's CoA class and spec (data in
-- Data.lua, from Ascension Sidekick) and reports which picks are learned and what to take
-- next. It reads the native Character Advancement API and never learns anything itself.
-- On a non-CoA class, or a client without C_CharacterAdvancement, it does nothing.

local ZTAC = {}
ZygorTalentAdvisorCOA = ZTAC

local DATA = ZygorTalentAdvisorCOA_Data
local NEXT_COUNT = 3 -- picks per tree highlighted as "next"

local function CA() return C_CharacterAdvancement end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
end

-- Per-character settings, kept in Zygor's own saved variables.
function ZTAC:GetSettings()
	local zgv = ZygorGuidesViewer
	if zgv and zgv.db and zgv.db.char then
		zgv.db.char.ztacoa = zgv.db.char.ztacoa or {}
		return zgv.db.char.ztacoa
	end
	self.fallbackSettings = self.fallbackSettings or {}
	return self.fallbackSettings
end

function ZTAC:GetClassData()
	local _, token = UnitClass("player")
	return DATA and DATA.classes and token and DATA.classes[token], token
end

-- Active on CoA classes, on a client with the native Character Advancement API.
function ZTAC:IsActive()
	local api = CA()
	return self:GetClassData() ~= nil and api ~= nil and type(api.IsKnownSpellID) == "function"
end

local function Normalize(s) return (tostring(s or ""):lower():gsub("[%s'%-]", "")) end

-- The data's spec name for a client spec info table (C_ClassInfo). The client's internal spec
-- file names can differ from the display names the builds use (Chronomancer "Duality" =
-- Infinite), so file names go through the alias table first.
function ZTAC:MatchSpecInfo(info)
	local cls = self:GetClassData()
	if not cls or type(info) ~= "table" then return nil end
	local function byFile(name)
		if not name then return end
		local alias = cls.aliases and cls.aliases[name]
		if alias and cls.specs[alias] then return alias end
		if cls.specs[name] then return name end
	end
	local function byName(name)
		if not name then return end
		if cls.specs[name] then return name end
		local want = Normalize(name)
		for spec in pairs(cls.specs) do
			if Normalize(spec) == want then return spec end
		end
	end
	return byFile(info.Spec) or byName(info.Name)
end

-- The active spec, in the data's spec names.
function ZTAC:DetectSpec()
	local api = CA()
	if not (self:GetClassData() and api and C_ClassInfo) then return nil end
	local specID = Call(api.GetActiveChrSpec)
	if not specID then return nil end
	return self:MatchSpecInfo((Call(C_ClassInfo.GetSpecInfoByID, specID)))
end

function ZTAC:GetSpecNames()
	local cls = self:GetClassData()
	local names = {}
	if cls then for spec in pairs(cls.specs) do names[#names + 1] = spec end end
	table.sort(names)
	return names
end

-- The spec whose build is shown: the user's choice if any, else the detected one.
function ZTAC:GetSelectedSpec()
	local cls = self:GetClassData()
	if not cls then return nil end
	local chosen = self:GetSettings().spec
	if chosen and cls.specs[chosen] then return chosen, false end
	local detected = self:DetectSpec()
	if detected then return detected, true end
	return self:GetSpecNames()[1], false
end

function ZTAC:SetSelectedSpec(spec)
	self:GetSettings().spec = spec -- nil returns to automatic detection
	self:Refresh()
end

-- Highest learned rank of a node, from its spells (one per rank where the node has ranks).
function ZTAC:GetKnownRank(spells)
	local api = CA()
	if not api or not spells then return 0 end
	local rank = 0
	for i, spell in ipairs(spells) do
		if Call(api.IsKnownSpellID, spell) then rank = i end
	end
	if rank == 0 and spells[1] then
		local r = tonumber((Call(api.GetTalentRankBySpellID, spells[1])))
		if r and r > 0 then rank = r end
	end
	return rank
end

-- Rank chosen in the talent window but not yet applied.
function ZTAC:GetPendingRank(spells)
	local api = CA()
	if not api or not spells or not spells[1] then return 0 end
	local entry = Call(api.GetEntryBySpellID, spells[1])
	local id = type(entry) == "table" and (entry.ID or entry.Id or entry.id)
	if not id then return 0 end
	return tonumber((Call(api.GetPendingRankByEntryID, id))) or 0
end

-- Unspent talent points as the talent window shows them (unsaved choices already taken off): ae
-- for the class tree, te for the spec tree. nil when the client doesn't report them.
function ZTAC:GetPointBudget()
	local api = CA()
	if not api then return nil end
	local ae = tonumber((Call(api.GetPendingRemainingAE)))
	local te = tonumber((Call(api.GetPendingRemainingTE)))
	if not ae or not te then return nil end
	return { ae = ae, te = te }
end

-- The point pool a pick spends from and its cost; nil for talents that cost nothing.
local function Cost(pick)
	if pick.ae then return "ae", pick.ae end
	if pick.te then return "te", pick.te end
end

-- Status of every pick in one tree of the build:
--   done     learned (at least the rank this pick asks for)
--   pending  chosen in the talent window, not applied yet
--   auto     granted automatically (row.unlock: its unlock level, while above the character's)
--   next     one of the first picks still to take that the unspent points cover
--   open     also covered by the unspent points
--   locked   not yet: row.reason "points" (the unspent points run out before it, following the
--            build's order) or "level" (a talent that costs nothing and unlocks at a higher level,
--            row.unlock)
-- Ascension Sidekick's per-pick levels are not learning requirements for talents that cost points
-- (Time's spec root Ripple is marked 48 but is its first pick), so only the points limit those.
-- budget (GetPointBudget) is spent as picks are covered; without one nothing is locked by points.
function ZTAC:EvaluatePath(path, level, budget)
	local rows, nextLeft = {}, NEXT_COUNT
	local done, total = 0, 0
	for _, pick in ipairs(path or {}) do
		local need = pick.rank or 1
		local known = self:GetKnownRank(pick.spells)
		local pool, cost = Cost(pick)
		local status, reason, unlock
		if known >= need then
			status = "done"
		elseif self:GetPendingRank(pick.spells) >= need then
			status = "pending"
		elseif pick.auto then
			status = "auto"
			if (pick.rl or 1) > level then unlock = pick.rl end
		elseif not pool and (pick.lvl or 1) > level then
			status, reason, unlock = "locked", "level", pick.lvl
		elseif pool and budget and (budget[pool] or 0) < cost then
			status, reason = "locked", "points"
		else
			if pool and budget then budget[pool] = budget[pool] - cost end
			if nextLeft > 0 then
				status = "next"; nextLeft = nextLeft - 1
			else
				status = "open"
			end
		end
		if not pick.auto then
			total = total + 1
			if status == "done" then done = done + 1 end
		end
		rows[#rows + 1] = { pick = pick, status = status, reason = reason, unlock = unlock }
	end
	return rows, done, total
end

-- The full state the panel shows.
function ZTAC:Evaluate()
	local cls = self:GetClassData()
	local spec, auto = self:GetSelectedSpec()
	local build = cls and spec and cls.specs[spec]
	if not build then return nil end
	local level = UnitLevel("player") or 1
	local budget = self:GetPointBudget() -- shared: class picks spend ae, spec picks te
	local classRows, classDone, classTotal = self:EvaluatePath(build.classPath, level, budget)
	local specRows, specDone, specTotal = self:EvaluatePath(build.specPath, level, budget)
	return {
		className = cls.name, spec = spec, autoSpec = auto, detectedSpec = self:DetectSpec(),
		role = build.role, keystone = build.keystone, level = level,
		class = { rows = classRows, done = classDone, total = classTotal },
		spec_ = { rows = specRows, done = specDone, total = specTotal },
	}
end

function ZTAC:Refresh()
	if self.loading then return end -- Load.lua refreshes once when it's done
	if self.UpdatePreview then self:UpdatePreview() end -- first, so the panel and numbers follow it
	if self.Popout and self.Popout:IsShown() then self.Popout:Update() end
	if self.UpdateOverlay then self:UpdateOverlay() end
end

-- Events: anything that changes learned talents, the spec, or the level.
local events = CreateFrame("Frame")
ZTAC.eventFrame = events
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "ADDON_LOADED",
	"CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT", "CHARACTER_ADVANCEMENT_PENDING_BUILD_UPDATED",
	"ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED" }) do
	pcall(events.RegisterEvent, events, ev) -- client-specific events may not exist everywhere
end
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "Ascension_CoATalents" and ZTAC.HookTalentFrame then ZTAC:HookTalentFrame() end
		return
	end
	if event == "PLAYER_LOGIN" then
		if ZTAC.HookTalentFrame then ZTAC:HookTalentFrame() end
		return
	end
	ZTAC:Refresh()
end)

SLASH_ZYGORTALENTADVISORCOA1 = "/ztacoa"
SlashCmdList.ZYGORTALENTADVISORCOA = function(msg)
	msg = (msg or ""):lower()
	if not ZTAC:IsActive() then
		print("|cffffbb00Zygor CoA Talent Advisor:|r no Conquest of Azeroth build data for this character.")
		return
	end
	if msg == "numbers" then
		ZTAC:SetOverlayEnabled(not ZTAC:IsOverlayEnabled())
		print("|cffffbb00Zygor CoA Talent Advisor:|r build numbers on the talent tree " .. (ZTAC:IsOverlayEnabled() and "shown." or "hidden."))
		return
	end
	if msg == "points" or msg == "order" then
		ZTAC:SetOverlayMode(msg)
		print("|cffffbb00Zygor CoA Talent Advisor:|r talent tree shows " .. (msg == "points" and "how many points to put in each talent." or "the order to take talents in."))
		return
	end
	if msg == "debug" then
		print("|cffffbb00Zygor CoA Talent Advisor:|r " .. ZTAC:DescribeOverlay())
		if ZTAC.DescribeLastLoad then
			for _, line in ipairs(ZTAC:DescribeLastLoad()) do print("|cffffbb00Zygor CoA Talent Advisor:|r " .. line) end
		end
		return
	end
	if msg == "load" then
		ZTAC:ConfirmLoadBuild()
		return
	end
	if msg == "preview" then
		ZTAC:SetPreviewEnabled(not ZTAC:IsPreviewEnabled())
		print("|cffffbb00Zygor CoA Talent Advisor:|r picking another spec's build " .. (ZTAC:IsPreviewEnabled()
			and "shows its tree in the talent window." or "no longer changes the talent window."))
		return
	end
	if msg == "auto" then
		ZTAC:SetSelectedSpec(nil)
		print("|cffffbb00Zygor CoA Talent Advisor:|r following your active spec again.")
		return
	end
	if ZTAC.TogglePopout then ZTAC:TogglePopout() end
end
