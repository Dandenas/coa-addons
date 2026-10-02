-- Numbers drawn on the CoA talent tree itself (CoATalentFrame's class and spec trees), like the
-- ones newer Zygor versions show on retail talent trees. Two modes:
--   points  how many points the build puts into each talent (default)
--   order   the step at which the build takes it

local ZTAC = ZygorTalentAdvisorCOA
if not ZTAC then return end

local COLORS = {
	done    = { 0.30, 1.00, 0.30 },
	pending = { 1.00, 0.90, 0.10 },
	next    = { 1.00, 0.90, 0.10 },
	open    = { 1.00, 1.00, 1.00 },
	locked  = { 0.78, 0.78, 0.78 },
}
local BADGE_FONT_SIZE = 17

function ZTAC:IsOverlayEnabled()
	return self:GetSettings().overlay ~= false
end

function ZTAC:GetOverlayMode()
	return self:GetSettings().overlayMode == "order" and "order" or "points"
end

function ZTAC:SetOverlayMode(mode)
	self:GetSettings().overlayMode = mode
	self:GetSettings().overlay = true
	self:Refresh() -- repaints the tree and the panel's mode button
end

function ZTAC:SetOverlayEnabled(on)
	self:GetSettings().overlay = on and true or false
	self:Refresh()
end

-- Step number, status and target points for every node in one path. A node listed more than
-- once (one pick per rank) gets its first step still to take (or its last step when done) and a
-- target of how many of its picks the build makes.
local function BuildIndex(rows)
	local byNode, bySpell, byName = {}, {}, {}
	local step = 0
	for _, row in ipairs(rows or {}) do
		local pick = row.pick
		if not pick.auto then
			step = step + 1
			local cur = byNode[pick.node]
			local target = math.max(pick.rank or 1, cur and cur.target or 0)
			if cur then cur.target = target end
			if not cur or (cur.status == "done" and row.status ~= "done") then
				local info = { step = step, status = row.status, target = target }
				byNode[pick.node] = info
				for _, spell in ipairs(pick.spells or {}) do bySpell[spell] = info end
				byName[pick.n] = info
			elseif cur.status == "done" and row.status == "done" then
				cur.step = step
			end
		end
	end
	return { node = byNode, spell = bySpell, name = byName }
end

-- The tree button's entry, matched against the build by node ID, then spell, then name.
local function Lookup(index, entry)
	if type(entry) ~= "table" then return nil end
	local hit = entry.ID and index.node[entry.ID]
	if hit then return hit, "node" end
	local spells = entry.Spells or entry.spells
	if type(spells) == "table" then
		for _, s in ipairs(spells) do if index.spell[s] then return index.spell[s], "spell" end end
	end
	local spell = entry.SpellID or entry.Spell or entry.spellID
	if spell and index.spell[spell] then return index.spell[spell], "spell" end
	if entry.Name and index.name[entry.Name] then return index.name[entry.Name], "name" end
end

local function GetBadge(button)
	local badge = button.ZTACBadge
	if badge then return badge end
	badge = CreateFrame("Frame", nil, button)
	badge:SetAllPoints(button)
	badge:SetFrameLevel(button:GetFrameLevel() + 10)
	badge.text = badge:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	-- larger, thick-outlined digits so the numbers read clearly over the talent art
	local font = NumberFontNormal and NumberFontNormal:GetFont()
	if font then badge.text:SetFont(font, BADGE_FONT_SIZE, "THICKOUTLINE") end
	badge.text:SetPoint("TOPLEFT", button, "TOPLEFT", -4, 4)
	badge.text:SetShadowColor(0, 0, 0, 1)
	badge.text:SetShadowOffset(1, -1)
	button.ZTACBadge = badge
	return badge
end

local function Trees()
	local view = _G.CoATalentFrame and _G.CoATalentFrame.TreeView
	return view and view.ClassTree, view and view.SpecTree
end

function ZTAC:UpdateOverlay()
	local classTree, specTree = Trees()
	if not classTree and not specTree then return end
	local state = self:IsOverlayEnabled() and self:IsActive() and self:Evaluate()
	local stats = { matched = 0, nodes = 0, by = {}, labels = {} }
	local pointsMode = self:GetOverlayMode() == "points"
	local function Paint(tree, section)
		if not tree or not tree.EnumerateNodes then return end
		local index = state and BuildIndex(section.rows)
		for button in tree:EnumerateNodes() do
			stats.nodes = stats.nodes + 1
			local info, how
			if index then info, how = Lookup(index, button.entry) end
			if info then
				local badge = GetBadge(button)
				local c = COLORS[info.status] or COLORS.open
				local label = pointsMode and info.target or info.step
				badge.text:SetText(label)
				if button.entry and button.entry.ID then stats.labels[button.entry.ID] = { label = label, status = info.status } end
				badge.text:SetTextColor(c[1], c[2], c[3])
				badge:Show()
				stats.matched = stats.matched + 1
				stats.by[how] = (stats.by[how] or 0) + 1
			elseif button.ZTACBadge then
				button.ZTACBadge:Hide()
			end
		end
	end
	Paint(classTree, state and state.class)
	Paint(specTree, state and state.spec_)
	self.lastOverlayStats = stats
end

-- Redraw after the trees build or refresh their nodes.
function ZTAC:HookTreeOverlay()
	local classTree, specTree = Trees()
	for _, tree in ipairs({ classTree, specTree }) do
		if tree and not tree.ZTACHooked then
			tree.ZTACHooked = true
			for _, method in ipairs({ "BuildTree", "RefreshTree", "InvalidateCache" }) do
				if type(tree[method]) == "function" then
					hooksecurefunc(tree, method, function() ZTAC:UpdateOverlay() end)
				end
			end
		end
	end
	self:UpdateOverlay()
end

-- Describes what the overlay matched, for troubleshooting (/ztacoa debug).
function ZTAC:DescribeOverlay()
	self:UpdateOverlay()
	local s = self.lastOverlayStats
	if not s then return "talent window not loaded yet - open it first" end
	local parts = {}
	for how, n in pairs(s.by) do parts[#parts + 1] = how .. " " .. n end
	local sample
	local classTree = Trees()
	if classTree and classTree.EnumerateNodes then
		for button in classTree:EnumerateNodes() do
			local e = button.entry
			if type(e) == "table" then
				local keys = {}
				for k, v in pairs(e) do if type(v) ~= "table" and type(v) ~= "function" then keys[#keys + 1] = k .. "=" .. tostring(v) end end
				table.sort(keys)
				sample = table.concat(keys, " ", 1, math.min(#keys, 8))
				break
			end
		end
	end
	return ("%d of %d tree nodes numbered (%s). Sample node: %s"):format(
		s.matched, s.nodes, #parts > 0 and table.concat(parts, ", ") or "none", sample or "none")
end
