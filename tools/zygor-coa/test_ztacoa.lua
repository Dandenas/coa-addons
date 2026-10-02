-- Regression for ZygorTalentAdvisorCOA: spec detection, rank tracking, next picks, and a panel smoke test.
-- Usage: lua test_ztacoa.lua <addon directory>
local root = arg[1]
local dir = root .. "/ZygorTalentAdvisorCOA/"
local realPrint = print

-- A no-op stand-in for any WoW frame/widget: every method exists and returns the widget.
local function Widget()
	local w = { shown = false, scripts = {}, points = {} }
	return setmetatable(w, { __index = function(t, k)
		if type(k) ~= "string" or k:match("^ZTAC") or k:match("^%l") then return nil end -- data fields, not methods
		if k == "IsShown" then return function(self) return self.shown end end
		if k == "Show" then return function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
		if k == "Hide" then return function(self) self.shown = false end end
		if k == "SetScript" or k == "HookScript" then return function(self, name, fn) self.scripts[name] = fn end end
		if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
		if k == "GetName" then return function() return "ZygorTalentAdvisorCOAPopout" end end
		if k:match("^Create") then return function() return Widget() end end
		return function(self) return self end
	end })
end

local function Load(classToken, opts)
	opts = opts or {}
	_G.ZygorTalentAdvisorCOA, _G.ZygorTalentAdvisorCOA_Data = nil, nil
	_G.ZygorGuidesViewer = { db = { char = {} } }
	_G.UnitClass = function() return "X", classToken end
	_G.UnitLevel = function() return opts.level or 30 end
	_G.CreateFrame = function() return Widget() end
	_G.UIParent, _G.UISpecialFrames, _G.SlashCmdList = Widget(), {}, {}
	_G.tinsert = table.insert
	_G.GetSpellInfo = function(id) return "Spell" .. id, nil, "icon" .. id end
	_G.UIDropDownMenu_SetWidth = function() end
	_G.UIDropDownMenu_Initialize = function() end
	_G.UIDropDownMenu_SetText = function(_, t) _G.lastDropText = t end
	_G.UIDropDownMenu_CreateInfo = function() return {} end
	_G.UIDropDownMenu_AddButton = function() end
	_G.GameTooltip = Widget()
	_G.hooksecurefunc = function(t, name, fn) local orig = t[name]; t[name] = function(...) local r = orig(...); fn(...); return r end end
	_G.CoATalentFrame = opts.talentFrame
	_G.print = function() end
	local known = opts.known or {}
	_G.C_CharacterAdvancement = {
		IsKnownSpellID = function(id) return known[id] == true end,
		GetTalentRankBySpellID = function() return 0 end,
		GetEntryBySpellID = function(id) return { ID = id + 1000000 } end,
		GetPendingRankByEntryID = function(id) return (opts.pending or {})[id - 1000000] or 0 end,
		GetActiveChrSpec = function() return opts.specID end,
	}
	if opts.noCA then _G.C_CharacterAdvancement = nil end
	_G.C_ClassInfo = { GetSpecInfoByID = function(id) return opts.specInfo end }
	dofile(dir .. "Data.lua")
	dofile(dir .. "ZygorTalentAdvisorCOA.lua")
	dofile(dir .. "Popout.lua")
	dofile(dir .. "Overlay.lua")
	return _G.ZygorTalentAdvisorCOA, _G.ZygorTalentAdvisorCOA_Data
end

-- 1. Stock class: stays inactive.
local Z = Load("MAGE")
assert(not Z:IsActive(), "must be inactive for a stock WotLK class")
assert(Z:Evaluate() == nil, "no build for a stock class")
-- No native API: inactive even for a CoA class.
Z = Load("CHRONOMANCER", { noCA = true })
assert(not Z:IsActive(), "must be inactive without C_CharacterAdvancement")

-- 2. Spec detection through the alias table. Chronomancer's internal "Time" is the Artificer
--    spec, while "Time" is also a display name - the file name must win.
Z = Load("CHRONOMANCER", { specID = 1, specInfo = { Spec = "Time", Name = "Artificer", Class = "Chronomancer" } })
assert(Z:IsActive(), "Chronomancer should be active")
assert(Z:DetectSpec() == "Artificer", "internal 'Time' must map to Artificer, got " .. tostring(Z:DetectSpec()))
Z = Load("CHRONOMANCER", { specID = 1, specInfo = { Spec = "Duality", Name = "Infinite" } })
assert(Z:DetectSpec() == "Infinite", "Duality -> Infinite")
Z = Load("CHRONOMANCER", { specID = 1, specInfo = { Spec = "Unknown", Name = "time" } })
assert(Z:DetectSpec() == "Time", "display-name match is case-insensitive")
Z = Load("CHRONOMANCER", {}) -- no spec chosen in game yet
assert(Z:DetectSpec() == nil and Z:GetSelectedSpec() == "Artificer", "falls back to the first spec alphabetically")

-- 3. Manual choice overrides detection; nil returns to automatic.
Z = Load("CHRONOMANCER", { specID = 1, specInfo = { Spec = "Duality", Name = "Infinite" } })
Z:SetSelectedSpec("Time")
assert(Z:GetSelectedSpec() == "Time", "manual choice")
Z:SetSelectedSpec(nil)
local spec, auto = Z:GetSelectedSpec()
assert(spec == "Infinite" and auto, "back to automatic")

-- 4. Statuses: learned, pending, auto, locked, next (first three open picks), open.
local _, DATA = Load("CHRONOMANCER")
local path = DATA.classes.CHRONOMANCER.specs.Infinite.specPath
local firstOpen
for _, p in ipairs(path) do if not p.auto and (p.lvl or p.rl or 1) <= 30 then firstOpen = p break end end
local known = { [firstOpen.spells[1]] = true }
Z = Load("CHRONOMANCER", { level = 30, known = known, specID = 1, specInfo = { Spec = "Duality", Name = "Infinite" } })
local state = Z:Evaluate()
assert(state.spec == "Infinite" and state.autoSpec, "evaluates the detected spec")
local counts, nextCount, sawLearned = {}, 0, false
local function same(a, b) return a.node == b.node and (a.rank or 1) == (b.rank or 1) end
for _, row in ipairs(state.spec_.rows) do
	counts[row.status] = (counts[row.status] or 0) + 1
	if same(row.pick, firstOpen) then assert(row.status == "done", "learned pick should be done"); sawLearned = true end
	if row.status == "locked" then assert((row.pick.lvl or row.pick.rl) > 30, "locked only above the level") end
	if row.pick.auto then assert(row.status == "auto" or row.status == "done", "auto picks") end
end
assert(sawLearned, "the learned pick was not found in the evaluated rows")
assert((counts.next or 0) == 3, "exactly three next picks, got " .. tostring(counts.next))
assert(state.spec_.done >= 1 and state.spec_.total > state.spec_.done, "progress counts")
-- Multi-rank: rank 2 needs the second spell.
local multi
for _, cls in pairs(DATA.classes) do for _, b in pairs(cls.specs) do for _, p in ipairs(b.specPath) do
	if p.rank == 2 and #p.spells >= 2 and not multi then multi = p end end end end
assert(multi, "data should contain a rank-2 pick with per-rank spells")
Z = Load("CHRONOMANCER", { known = { [multi.spells[1]] = true } })
assert(Z:GetKnownRank(multi.spells) == 1, "only rank 1 known")
Z = Load("CHRONOMANCER", { known = { [multi.spells[1]] = true, [multi.spells[2]] = true } })
assert(Z:GetKnownRank(multi.spells) == 2, "rank 2 known")
-- Pending (chosen in the talent window, not applied).
Z = Load("CHRONOMANCER", { pending = { [firstOpen.spells[1]] = 1 }, specID = 1, specInfo = { Spec = "Duality" } })
local pendingSeen
for _, row in ipairs(Z:Evaluate().spec_.rows) do if same(row.pick, firstOpen) then pendingSeen = row.status end end
assert(pendingSeen == "pending", "pending pick should show as pending, got " .. tostring(pendingSeen))

-- 5. Every class and spec evaluates, and the panel draws without errors.
for token, cls in pairs(DATA.classes) do
	for specName in pairs(cls.specs) do
		Z = Load(token, { level = 60 })
		Z:SetSelectedSpec(specName)
		local s = Z:Evaluate()
		assert(s and s.spec == specName, token .. " " .. specName .. " did not evaluate")
		local f = Z:GetPopout()
		f:Show()
		assert(f:IsShown(), "panel did not show")
	end
end
assert(_G.lastDropText, "panel set the build label")

-- 6. Overlay: numbers on the talent tree's node buttons.
do
	local _, DATA = Load("CHRONOMANCER")
	local spec = DATA.classes.CHRONOMANCER.specs.Infinite
	-- Stand-in tree: one button per distinct node of the spec path, matched three different ways.
	local function Button(entry)
		local b = Widget(); b.entry = entry; b.GetFrameLevel = function() return 5 end
		local created
		b.CreateFontString = nil
		return b
	end
	local buttons, seen, ways = {}, {}, { "node", "spell", "name" }
	for i, p in ipairs(spec.specPath) do
		if not p.auto and not seen[p.node] then
			seen[p.node] = true
			local way = ways[(#buttons % 3) + 1]
			local entry = way == "node" and { ID = p.node, Name = p.n }
				or way == "spell" and { ID = 900000 + i, Spells = { p.spells[1] }, Name = "x" .. i }
				or { ID = 800000 + i, Name = p.n }
			buttons[#buttons + 1] = Button(entry)
		end
	end
	buttons[#buttons + 1] = Button({ ID = 1, Name = "Not In The Build" })
	local function Tree(list)
		local t = Widget()
		t.EnumerateNodes = function() local i = 0 return function() i = i + 1 return list[i] end end
		t.BuildTree = function() end
		t.RefreshTree = function() end
		return t
	end
	local specTree, classTree = Tree(buttons), Tree({})
	local frame = Widget(); frame.TreeView = { ClassTree = classTree, SpecTree = specTree }
	-- learn the first open pick so it shows green
	local firstOpen
	for _, p in ipairs(spec.specPath) do if not p.auto and (p.lvl or p.rl or 1) <= 30 then firstOpen = p break end end
	local Z = Load("CHRONOMANCER", { level = 30, talentFrame = frame, known = { [firstOpen.spells[1]] = true },
		specID = 1, specInfo = { Spec = "Duality", Name = "Infinite" } })
	-- badges need real font strings: give the stand-in widgets text/colour storage
	local texts = {}
	local origWidget = Widget
	Z:HookTreeOverlay()
	local stats = Z.lastOverlayStats
	assert(stats.nodes == #buttons, "all tree buttons visited")
	assert(stats.matched == #buttons - 1, ("all build nodes numbered (%d of %d)"):format(stats.matched, #buttons - 1))
	assert((stats.by.node or 0) > 0 and (stats.by.spell or 0) > 0 and (stats.by.name or 0) > 0, "matched by node, spell and name")
	assert(not buttons[#buttons].ZTACBadge, "a node outside the build gets no number")
	-- Hooks: rebuilding the tree repaints.
	Z.lastOverlayStats = nil
	specTree:BuildTree()
	assert(Z.lastOverlayStats, "BuildTree hook repaints")
	-- Turning numbers off hides every badge.
	Z:SetOverlayEnabled(false)
	assert(Z.lastOverlayStats.matched == 0, "numbers off: nothing numbered")
	Z:SetOverlayEnabled(true)
	assert(Z.lastOverlayStats.matched == #buttons - 1, "numbers back on")
	assert(Z:DescribeOverlay():find("numbered"), "debug description")
end

-- 7. Points mode (default): each talent shows how many points the build puts in it.
do
	local _, DATA = Load("CHRONOMANCER")
	-- find a spec with a multi-rank node in its spec path, and that node's highest rank
	local token, specName, multiNode, maxRank
	for tk, cls in pairs(DATA.classes) do
		for sn, b in pairs(cls.specs) do
			local ranks = {}
			for _, p in ipairs(b.specPath) do if not p.auto then ranks[p.node] = math.max(ranks[p.node] or 0, p.rank or 1) end end
			for node, r in pairs(ranks) do if r >= 2 and not multiNode then token, specName, multiNode, maxRank = tk, sn, node, r end end
		end
	end
	assert(multiNode, "data should have a multi-rank spec node")
	local b = DATA.classes[token].specs[specName]
	local singleNode, multiPicks
	for _, p in ipairs(b.specPath) do
		if not p.auto and p.node ~= multiNode and not singleNode then
			local count = 0
			for _, q in ipairs(b.specPath) do if q.node == p.node then count = count + 1 end end
			if count == 1 then singleNode = p.node end
		end
	end
	local multiSpells
	for _, p in ipairs(b.specPath) do if p.node == multiNode then multiSpells = p.spells end end
	local function Run(known, mode)
		local buttons = {}
		for _, node in ipairs({ multiNode, singleNode }) do
			local btn = Widget(); btn.entry = { ID = node }; btn.GetFrameLevel = function() return 5 end
			buttons[#buttons + 1] = btn
		end
		local tree = Widget()
		tree.EnumerateNodes = function() local i = 0 return function() i = i + 1 return buttons[i] end end
		local frame = Widget(); frame.TreeView = { ClassTree = Widget(), SpecTree = tree }
		frame.TreeView.ClassTree.EnumerateNodes = function() return function() return nil end end
		local Z = Load(token, { level = 60, talentFrame = frame, known = known })
		Z:SetSelectedSpec(specName)
		if mode then Z:SetOverlayMode(mode) end
		Z:UpdateOverlay()
		return Z, Z.lastOverlayStats.labels
	end
	local Z, labels = Run({})
	assert(Z:GetOverlayMode() == "points", "points is the default mode")
	assert(labels[multiNode].label == maxRank, ("multi-rank talent should show %d, got %s"):format(maxRank, tostring(labels[multiNode].label)))
	assert(labels[singleNode].label == 1, "single-point talent should show 1")
	-- rank 1 of the multi-rank talent learned: still not done, target unchanged
	Z, labels = Run({ [multiSpells[1]] = true })
	assert(labels[multiNode].label == maxRank and labels[multiNode].status ~= "done", "half-learned talent is not done")
	-- every rank learned: done
	local all = {}
	for i = 1, maxRank do if multiSpells[i] then all[multiSpells[i]] = true end end
	if #multiSpells >= maxRank then
		Z, labels = Run(all)
		assert(labels[multiNode].status == "done", "fully learned talent is done")
	end
	-- order mode: step numbers instead
	Z, labels = Run({}, "order")
	assert(Z:GetOverlayMode() == "order", "order mode set")
	assert(labels[singleNode].label ~= nil and type(labels[singleNode].label) == "number", "order mode shows step numbers")
end

-- 8. Collapsible tree sections in the panel.
do
	local Z = Load("CHRONOMANCER", { level = 30, specID = 1, specInfo = { Spec = "Duality", Name = "Infinite" } })
	local f = Z:GetPopout()
	f:Show()
	local function Visible()
		local n, headers = 0, {}
		for _, row in ipairs(f.rows) do
			if row.shown then n = n + 1; if row.sectionKey then headers[row.sectionKey] = row end end
		end
		return n, headers
	end
	local full, headers = Visible()
	local state = Z:Evaluate()
	assert(full == 2 + #state.class.rows + #state.spec_.rows, "expanded: headers plus every pick")
	assert(headers.class and headers.spec, "both trees have clickable headings")
	headers.class.scripts.OnClick(headers.class)        -- collapse the class tree
	local afterClass = Visible()
	assert(afterClass == 2 + #state.spec_.rows, "class tree collapsed")
	assert(Z:GetSettings().collapsed.class, "collapse is remembered")
	local _, h2 = Visible()
	h2.spec.scripts.OnClick(h2.spec)                    -- collapse the spec tree too
	assert(Visible() == 2, "both collapsed: only the headings remain")
	local _, h3 = Visible()
	h3.class.scripts.OnClick(h3.class)                  -- expand the class tree again
	assert(Visible() == 2 + #state.class.rows, "class tree expanded again")
	assert(not Z:GetSettings().collapsed.class and Z:GetSettings().collapsed.spec, "state saved per section")
end

-- 9. Mode button cycles points -> order -> off -> points; panel closes with the talent window.
do
	local talent = Widget(); talent.TreeView = { ClassTree = Widget(), SpecTree = Widget() }
	for _, t in pairs(talent.TreeView) do t.EnumerateNodes = function() return function() return nil end end end
	local Z = Load("CHRONOMANCER", { level = 30, talentFrame = talent, specID = 1, specInfo = { Spec = "Duality", Name = "Infinite" } })
	local labels = {}
	local f = Z:GetPopout()
	f.modeButton.SetText = function(_, t) labels[#labels + 1] = t end
	f:Show()
	local click = f.modeButton.scripts.OnClick
	assert(Z:IsOverlayEnabled() and Z:GetOverlayMode() == "points", "starts on points")
	click(); assert(Z:IsOverlayEnabled() and Z:GetOverlayMode() == "order", "points -> order")
	click(); assert(not Z:IsOverlayEnabled(), "order -> off")
	click(); assert(Z:IsOverlayEnabled() and Z:GetOverlayMode() == "points", "off -> points")
	assert(labels[#labels] == "Tree numbers: Points", "button shows the current mode, got " .. tostring(labels[#labels]))
	-- a slash-command change updates the button label too
	Z:SetOverlayMode("order")
	assert(labels[#labels] == "Tree numbers: Order", "label follows /ztacoa order")
	-- talent window hooks: closes with it even after being dragged
	Z:HookTalentFrame()
	talent:Show()
	assert(f:IsShown(), "opens with the talent window")
	f.userMoved = true
	talent.scripts.OnHide(talent)
	assert(not f:IsShown(), "closes with the talent window even when moved")
end

realPrint("ZygorTalentAdvisorCOA regression passed")
