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
	for name, fn in pairs(opts.api or {}) do _G.C_CharacterAdvancement[name] = fn end
	if opts.noCA then _G.C_CharacterAdvancement = nil end
	_G.StaticPopupDialogs, _G.CANCEL = {}, "Cancel"
	_G.StaticPopup_Show = function(name, text) _G.lastPopup = { name = name, text = text } end
	-- opts.specs: the class's client specs, { { ID, Spec (file name), Name }, ... }
	local specs = opts.specs or {}
	_G.C_ClassInfo = {
		GetSpecInfoByID = function(id)
			if opts.specInfo then return opts.specInfo end
			for _, s in ipairs(specs) do if s.ID == id then return s end end
		end,
		GetAllSpecs = function() local files = {} for i, s in ipairs(specs) do files[i] = s.Spec end return files end,
		GetSpecInfo = function(_, file) for _, s in ipairs(specs) do if s.Spec == file then return s end end end,
	}
	_G.IsModifiedClick = function() return opts.modified == true end
	_G.UIErrorsFrame = { AddMessage = function(_, msg) _G.lastUIError = msg end }
	dofile(dir .. "Data.lua")
	dofile(dir .. "ZygorTalentAdvisorCOA.lua")
	dofile(dir .. "Popout.lua")
	dofile(dir .. "Overlay.lua")
	dofile(dir .. "Preview.lua")
	dofile(dir .. "Load.lua")
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

-- 10. Preview: a build picked for another spec shows that spec's tree in the talent window.
do
	-- Chronomancer's client spec files differ from the build names: Time = Artificer,
	-- Duality = Infinite, Displacement = Time.
	local SPECS = {
		{ ID = 101, Spec = "Time", Name = "Artificer" },
		{ ID = 102, Spec = "Duality", Name = "Infinite" },
		{ ID = 103, Spec = "Displacement", Name = "Time" },
	}
	local function Setup(opts)
		local clicks = 0
		local button = Widget(); button.entry = { ID = 1 }
		button.GetFrameLevel = function() return 5 end
		button.GetScript = function(self, name) return self.scripts[name] end
		button.scripts.OnClick = function() clicks = clicks + 1 end
		local specTree = Widget()
		specTree.Label = Widget()
		specTree.GetFrameLevel = function() return 5 end
		specTree.EnumerateNodes = function() local done return function() if not done then done = true return button end end end
		local classTree = Widget()
		classTree.EnumerateNodes = function() return function() return nil end end
		local view = { ClassTree = classTree, SpecTree = specTree, specID = opts.specID }
		function view:SetSpecID(id) self.specID = id end
		local talent = Widget(); talent.TreeView = view
		-- the window's own reset to the active spec (on open and on spec change)
		function talent:UpdateActiveSpec() if opts.specID then self.TreeView:SetSpecID(opts.specID) end end
		opts.level, opts.talentFrame, opts.specs = 60, talent, SPECS
		local Z = Load("CHRONOMANCER", opts)
		Z:HookTalentFrame()
		return Z, talent, view, function() button.scripts.OnClick(button, "LeftButton"); return clicks end
	end

	local Z, talent, view, click = Setup({ specID = 102 }) -- active spec: Infinite
	assert(Z:GetSpecIDFor("Artificer") == 101 and Z:GetSpecIDFor("Time") == 103, "spec names map to client spec IDs through the aliases")
	assert(view.specID == 102 and not Z.previewSpecID, "Auto: no preview")
	local f = Z:GetPopout(); f:Show()
	Z:SetSelectedSpec("Time")
	assert(view.specID == 103 and Z.previewSpecID == 103, "picking Time shows the Time tree")
	assert(view.SpecTree.ZTACPreviewBanner.shown, "preview banner shown")
	assert(_G.lastDropText == "Time (preview)", "panel says preview, got " .. tostring(_G.lastDropText))
	_G.lastUIError = nil
	assert(click() == 0 and _G.lastUIError, "clicks on the previewed tree are ignored, with a message")
	talent:UpdateActiveSpec() -- window reopened: it resets to the active spec, the preview comes back
	assert(view.specID == 103, "preview re-applied after the window resets itself")
	Z:SetSelectedSpec("Infinite") -- the active spec: no preview
	assert(view.specID == 102 and not Z.previewSpecID, "picking the active spec returns to it")
	assert(not view.SpecTree.ZTACPreviewBanner.shown, "banner hidden")
	assert(click() == 1, "clicks work again")
	Z:SetSelectedSpec("Time")
	Z:SetPreviewEnabled(false)
	assert(view.specID == 102 and not Z.previewSpecID, "/ztacoa preview off returns to the active spec")
	Z:SetPreviewEnabled(true)
	assert(view.specID == 103, "and back on")
	Z:SetSelectedSpec(nil)
	assert(view.specID == 102, "Auto returns to the active spec")

	-- Shift-click still links the spell while previewing.
	Z, talent, view, click = Setup({ specID = 102, modified = true })
	Z:SetSelectedSpec("Time")
	assert(view.specID == 103 and click() == 1, "chat-link clicks pass through")

	-- No active spec yet (the window shows its spec picker): never preview.
	Z, talent, view = Setup({})
	Z:SetSelectedSpec("Time")
	assert(view.specID == nil and not Z.previewSpecID, "no preview without an active spec")
end

-- 11. Load build: a CoA build link into the talent window as unsaved changes, trimmed to what
--     the character can take, switching spec first when needed. Never saves.
do
	local SPECS = {
		{ ID = 101, Spec = "Time", Name = "Artificer" },
		{ ID = 102, Spec = "Duality", Name = "Infinite" },
		{ ID = 103, Spec = "Displacement", Name = "Time" },
	}
	-- Chronomancer Time as Ascension Sidekick's site gives it (confirmed to import in game).
	local WEBSITE = ":6162t2:6183t2:6187t2:6190t1:6192t1:6196t1:6213t1:6214t1:6215t1:6226t1:6228t1:6652t1:6696t1:6697t1:6698t1:6699t1:6700t1:6702t1:7198t1:7226t1:7911t2:7912t1:7915t1:7916t1:7917t1:9198t1:11122t1:19978t1:19979t2:19980t1:29670t1:29681t1:30249t1:30260t1:30261t1:30267t1:30269t1:30276t1:30277t1:30280t1:30780t1:30901t1:30902t1:30903t1:30922t1:31182t1:"
	local _, DATA = Load("CHRONOMANCER")
	local TIME = DATA.classes.CHRONOMANCER.specs.Time
	local classNode, autoNode = {}, {}
	for _, p in ipairs(TIME.classPath) do classNode[p.node] = true end
	for _, path in ipairs({ TIME.classPath, TIME.specPath }) do
		for _, p in ipairs(path) do if p.auto then autoNode[p.node] = true end end
	end
	local function Tokens(link)
		local t = {}
		for node, rank in link:gmatch("(%d+)t(%d+)") do t[tonumber(node)] = tonumber(rank) end
		return t
	end
	-- What each Time build talent hangs from (ConnectedNodes in the client's CoA tree data); the
	-- roots - Accelerated Recovery, Clasp of Infinity, Ripple - hang from nothing.
	local CONNECTED = {
		[30277] = {}, [6697] = { 30277 }, [7911] = { 30249, 30277 }, [6228] = { 6697, 7911 },
		[7917] = { 6226, 7911, 30280 }, [6162] = { 6228, 7917, 30269 }, [30249] = {}, [30280] = { 30249 },
		[6226] = { 30249, 30855 }, [30269] = { 6226, 30251 }, [30260] = { 6228 }, [7198] = { 6162 },
		[9198] = { 30260 }, [30276] = { 30260 }, [6698] = { 7198, 32547 }, [11122] = { 9198, 30276 },
		[6214] = { 6698, 7226, 9198 }, [30267] = { 6214 }, [6696] = { 30269 }, [7226] = { 6696 },
		[6213] = { 6696 }, [6215] = { 6213, 7226 }, [7915] = { 6199, 9547, 30267 }, [7916] = { 7915 },
		[31182] = {}, [19979] = { 31182 }, [6700] = { 31182 }, [19980] = { 6700, 19979 }, [6183] = { 19980 },
		[6190] = { 19980 }, [6187] = { 19980 }, [29681] = { 6183 }, [6699] = { 6190 }, [6196] = { 6190 },
		[19978] = { 6187 }, [30901] = { 29681 }, [30903] = { 6699, 29681 }, [7912] = { 6196, 6699 },
		[30902] = { 30901, 30903 }, [30922] = { 30903 }, [30780] = { 7912, 30903 }, [6702] = { 7912, 29571 },
		[29670] = { 30780 }, [6652] = { 6702 }, [6192] = { 6184, 6652, 30905 }, [30261] = { 6192, 7826 },
	}

	-- opts: active (spec ID), level, classBudget/specBudget (points per tree), needAuto (after a
	-- switch the automatic talents must be in the link), refuse (refuse everything), pending, shown
	local function Setup(opts)
		local game = { active = opts.active, imports = {}, accepted = nil, applied = false, cancelled = false, switches = {} }
		local api = {
			GetActiveChrSpec = function() return game.active end,
			SwitchActiveChrSpec = function(id) game.active = id; game.switched = true end,
			IsPending = function() return opts.pending == true end,
			ApplyPendingBuild = function() game.applied = true end,
			CancelPendingBuild = function() game.cancelled = true end,
			GetEntryByInternalID = function(id) return { Name = "Node" .. id } end,
			ImportPendingBuild = function(link)
				game.imports[#game.imports + 1] = link
				if opts.refuse then return false, "CA_LEARN_NOT_IN_COMBAT", 6162, 1 end
				local class, spec, hasAuto = 0, 0, false
				for node, rank in pairs(Tokens(link)) do
					if autoNode[node] then hasAuto = true
					elseif classNode[node] then class = class + rank
					else spec = spec + rank end
				end
				if class > (opts.classBudget or 999) or spec > (opts.specBudget or 999) then
					return false, "CA_LEARN_MISSING_CONNECTED_ENTRIES", 6162, 2
				end
				if opts.needAuto and game.switched and not hasAuto then
					return false, "CA_LEARN_MISSING_CONNECTED_ENTRIES", 6162, 2
				end
				-- level 45 in game: Time's Aeon of Resilience (kept by the game) needs the class talent
				-- Accelerated Recovery, and builds without spec picks were refused as well
				if opts.needBoth and (spec == 0 or not Tokens(link)[30277]) then
					return false, "CA_LEARN_MISSING_REQUIRED_ID", 4032, 1
				end
				-- the trees' connections: every talent needs a talent it hangs from
				if opts.connected then
					local t = Tokens(link)
					for node in pairs(t) do
						local from = CONNECTED[node]
						if from and #from > 0 then
							local linked = false
							for _, parent in ipairs(from) do linked = linked or t[parent] ~= nil end
							if not linked then return false, "CA_LEARN_MISSING_CONNECTED_ENTRIES", node, t[node] end
						end
					end
				end
				game.accepted = link
				return true
			end,
		}
		local talent = Widget()
		talent.shown = opts.shown ~= false
		talent.TreeView = { ClassTree = Widget(), SpecTree = Widget(), SetSpecID = function(self, id) self.specID = id end }
		for _, t in pairs({ talent.TreeView.ClassTree, talent.TreeView.SpecTree }) do
			t.EnumerateNodes = function() return function() return nil end end
			t.GetFrameLevel = function() return 5 end
		end
		function talent:ChangeSpecID(id) game.switches[#game.switches + 1] = id; api.SwitchActiveChrSpec(id) end
		local Z = Load("CHRONOMANCER", { level = opts.level or 60, specs = SPECS, api = api, talentFrame = talent })
		game.messages = {}
		_G.print = function(m) game.messages[#game.messages + 1] = m end
		Z:SetSelectedSpec(opts.spec or "Time")
		return Z, game
	end
	-- Level 60, already Time: exactly the site's link, one import, nothing saved.
	local Z, game = Setup({ active = 103 })
	assert(Z:LoadBuild(), "loads at level 60")
	assert(#game.imports == 1 and game.imports[1] == WEBSITE, "link must match the site's build code, got " .. tostring(game.imports[1]))
	assert(#game.switches == 0, "no spec switch when the build is for the active spec")
	assert(not game.applied, "never saves")
	assert(game.messages[#game.messages]:find("Save Changes"), "tells the user to review and save")
	assert(not Z.loading, "loading flag cleared")

	-- Not enough points: each tree trimmed from its end to its own budget.
	Z, game = Setup({ active = 103, classBudget = 10, specBudget = 7 })
	local ok, count = Z:LoadBuild()
	assert(ok and count == 17, "trimmed to 10 class + 7 spec picks, got " .. tostring(count))
	local class, spec = 0, 0
	for node, rank in pairs(Tokens(game.accepted)) do
		if classNode[node] then class = class + rank else spec = spec + rank end
	end
	assert(class == 10 and spec == 7, ("final link uses the whole budget (%d/%d)"):format(class, spec))
	assert(game.messages[#game.messages]:find("need more talent points"), "says the rest needs more points")
	assert(not game.applied, "never saves")

	-- Level 45 as seen in game: too few points for every pick at the level, class-only builds
	-- refused. Trimming follows the leveling order of both trees, so it still loads.
	Z, game = Setup({ active = 103, level = 45, classBudget = 12, specBudget = 9, needBoth = true })
	ok, count = Z:LoadBuild()
	assert(ok and count == 21, "level 45 loads 12 class + 9 spec picks, got " .. tostring(count))
	local t = Tokens(game.accepted)
	assert(t[30277], "Accelerated Recovery is in the loaded build")
	assert(not game.applied, "never saves")
	local lines = Z:DescribeLastLoad()
	assert(lines[1]:find("Time at level 45") and lines[1]:find("12 class %+ 9 spec"), "debug summary: " .. lines[1])
	assert(lines[2] and lines[2]:find("first refused"), "debug shows the first refusal")

	-- Fresh level-20 character as in game: Ascension Sidekick marks the spec root Ripple "level 48"
	-- although it's the first spec pick. Its levels aren't requirements, so Ripple must be loaded
	-- with the talents that hang from it; only the points limit the build.
	Z, game = Setup({ active = 103, level = 20, classBudget = 8, specBudget = 6, connected = true })
	ok, count = Z:LoadBuild()
	assert(ok and count == 14, "level 20 loads 8 class + 6 spec picks, got " .. tostring(count))
	t = Tokens(game.accepted)
	assert(t[31182] and t[30277], "the tree roots Ripple and Accelerated Recovery are loaded")
	assert(not game.applied, "never saves")

	-- Automatic talents only up to their grant level: at 20, Aeon of Resilience (1) and Protection
	-- (15), not Renewal (30).
	Z, game = Setup({ active = 102, level = 20, needAuto = true })
	assert(Z:LoadBuild(), "loads after switching spec at level 20")
	t = Tokens(game.accepted)
	assert(t[4032] and t[9177] and not t[9181], "automatic talents limited to their grant level")

	-- Another spec active: the window switches to Time first; its automatic talents are added when
	-- the plain link is refused after the switch.
	Z, game = Setup({ active = 102, needAuto = true })
	assert(Z:LoadBuild(), "loads after switching spec")
	assert(game.switches[1] == 103 and game.active == 103, "switched the window to Time through its own ChangeSpecID")
	local withAuto = false
	for node in pairs(Tokens(game.accepted)) do if autoNode[node] then withAuto = true end end
	assert(withAuto, "automatic talents included after the switch")
	assert(not game.cancelled and not game.applied, "kept as unsaved changes")

	-- Nothing fits after a switch: the switch is undone and the game's reason shown.
	Z, game = Setup({ active = 102, refuse = true })
	assert(not Z:LoadBuild(), "refused build reports failure")
	assert(game.cancelled, "spec switch undone")
	assert(game.messages[#game.messages]:find("couldn't load") and game.messages[#game.messages]:find("Node6162"), "shows the reason with the talent's name")
	assert(not game.applied, "never saves")
	-- ...and without a switch nothing is undone (a refused import changes nothing).
	Z, game = Setup({ active = 103, refuse = true })
	assert(not Z:LoadBuild() and not game.cancelled, "no cancel without a switch")

	-- No points at all (level 1): every attempt refused, nothing changes, the reason is shown.
	Z, game = Setup({ active = 103, level = 1, classBudget = 0, specBudget = 0 })
	assert(not Z:LoadBuild() and not game.accepted and not game.cancelled, "nothing loaded, nothing to undo")
	assert(game.messages[#game.messages]:find("couldn't load"), "reports the failure")

	-- Confirmation: needs the talent window open, warns about replacing unsaved changes.
	Z, game = Setup({ active = 103, shown = false })
	_G.lastPopup = nil
	Z:ConfirmLoadBuild()
	assert(not _G.lastPopup and game.messages[#game.messages]:find("open the talent window"), "asks to open the talent window")
	Z, game = Setup({ active = 103, pending = true })
	Z:ConfirmLoadBuild()
	assert(_G.lastPopup and _G.lastPopup.text:find("Time") and _G.lastPopup.text:find("replaced"), "popup names the build and warns")
	assert(#game.imports == 0, "nothing loaded before confirming")
	_G.StaticPopupDialogs[_G.lastPopup.name].OnAccept()
	assert(#game.imports > 0 and not game.applied, "Load button in the popup loads, still unsaved")
	Z, game = Setup({ active = 103 })
	Z:ConfirmLoadBuild()
	assert(not _G.lastPopup.text:find("replaced"), "no warning without unsaved changes")
	-- the panel's button opens the same confirmation
	_G.lastPopup = nil
	local f = Z:GetPopout()
	f.loadButton.scripts.OnClick(f.loadButton)
	assert(_G.lastPopup, "panel button asks to confirm")
	_G.print = function() end
end

realPrint("ZygorTalentAdvisorCOA regression passed")
