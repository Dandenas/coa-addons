-- Panel for the CoA Talent Advisor: shows the leveling build for the character's spec, what is
-- learned, and the next picks. Opens beside the CoA talent window (CoATalentFrame) and with /ztacoa.

local ZTAC = ZygorTalentAdvisorCOA
if not ZTAC then return end

local WIDTH, HEIGHT, ROW_HEIGHT = 310, 470, 18

local STATUS_STYLE = {
	done    = { color = "|cff5fb85f", tag = "learned" },
	pending = { color = "|cffffd100", tag = "chosen, not applied" },
	next    = { color = "|cffffffff", tag = "next" },
	open    = { color = "|cffc8c8c8", tag = "available" },
	locked  = { color = "|cff808080", tag = "needs a higher level" },
	auto    = { color = "|cff7f9fbf", tag = "granted automatically" },
}

local function SpellIcon(spells)
	local id = spells and spells[1]
	if not id then return nil end
	local _, _, icon = GetSpellInfo(id)
	return icon
end

local function CreatePopout()
	local f = CreateFrame("Frame", "ZygorTalentAdvisorCOAPopout", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		ZTAC:GetSettings().pos = { point, relPoint, x, y }
		self.userMoved = true
	end)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	f:Hide()
	tinsert(UISpecialFrames, f:GetName()) -- Escape closes it

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Zygor Talent Advisor |cff7f9fbf(CoA)|r")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	-- Build picker: Auto (follow the active spec) or a fixed spec.
	local drop = CreateFrame("Frame", "ZygorTalentAdvisorCOAPopoutSpec", f, "UIDropDownMenuTemplate")
	drop:SetPoint("TOPLEFT", 0, -34)
	UIDropDownMenu_SetWidth(drop, 150)
	UIDropDownMenu_Initialize(drop, function(_, level)
		local info = UIDropDownMenu_CreateInfo()
		info.text = "Auto (active spec)"
		info.checked = ZTAC:GetSettings().spec == nil
		info.func = function() ZTAC:SetSelectedSpec(nil) end
		UIDropDownMenu_AddButton(info, level)
		for _, spec in ipairs(ZTAC:GetSpecNames()) do
			info = UIDropDownMenu_CreateInfo()
			info.text = spec
			info.checked = ZTAC:GetSettings().spec == spec
			info.func = function() ZTAC:SetSelectedSpec(spec) end
			UIDropDownMenu_AddButton(info, level)
		end
	end)
	f.drop = drop

	local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", 18, -66)
	summary:SetPoint("RIGHT", -18, 0)
	summary:SetJustifyH("LEFT")
	f.summary = summary

	local scroll = CreateFrame("ScrollFrame", "ZygorTalentAdvisorCOAPopoutScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -104)
	scroll:SetPoint("BOTTOMRIGHT", -34, 48)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(WIDTH - 50, 10)
	scroll:SetScrollChild(child)
	f.scroll, f.child = scroll, child
	f.rows = {}

	local credit = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	credit:SetPoint("BOTTOMRIGHT", -16, 32)
	credit:SetText("Builds: Ascension Sidekick")

	-- Puts the build into the talent window as unsaved changes (Load.lua); asks first.
	local load = CreateFrame("Button", "ZygorTalentAdvisorCOAPopoutLoad", f, "UIPanelButtonTemplate")
	load:SetSize(110, 20)
	load:SetPoint("BOTTOMRIGHT", -14, 8)
	load:SetText("Load build")
	load:SetScript("OnClick", function() ZTAC:ConfirmLoadBuild() end)
	load:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:AddLine("Load build into the talent window", 1, 1, 1)
		GameTooltip:AddLine("Fills in this build, as far as your level allows, as unsaved changes. Review them, then press Save Changes or Undo in the talent window.", nil, nil, nil, true)
		GameTooltip:AddLine("A build for another spec switches the window to that spec first (also unsaved).", 0.5, 0.75, 1, true)
		GameTooltip:Show()
	end)
	load:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.loadButton = load

	-- Cycles the talent-tree numbers: points -> order -> off.
	local mode = CreateFrame("Button", "ZygorTalentAdvisorCOAPopoutMode", f, "UIPanelButtonTemplate")
	mode:SetSize(118, 20)
	mode:SetPoint("BOTTOMLEFT", 14, 8)
	mode:SetScript("OnClick", function()
		if not ZTAC:IsOverlayEnabled() then
			ZTAC:SetOverlayMode("points")
		elseif ZTAC:GetOverlayMode() == "points" then
			ZTAC:SetOverlayMode("order")
		else
			ZTAC:SetOverlayEnabled(false)
		end
		f:UpdateModeButton()
	end)
	mode:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:AddLine("Numbers on the talent tree", 1, 1, 1)
		GameTooltip:AddLine("Points: how many points to put in each talent.", nil, nil, nil, true)
		GameTooltip:AddLine("Order: the step at which the build takes it.", nil, nil, nil, true)
		GameTooltip:AddLine("Click to switch: Points, Order, Off.", 0.5, 0.75, 1, true)
		GameTooltip:Show()
	end)
	mode:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.modeButton = mode

	function f:UpdateModeButton()
		local label = not ZTAC:IsOverlayEnabled() and "Off" or (ZTAC:GetOverlayMode() == "order" and "Order" or "Points")
		self.modeButton:SetText("Tree numbers: " .. label)
	end

	function f:GetRow(i)
		local row = self.rows[i]
		if row then return row end
		row = CreateFrame("Button", nil, self.child)
		row:SetSize(WIDTH - 50, ROW_HEIGHT)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
		row.icon:SetPoint("LEFT", 2, 0)
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
		row.text:SetPoint("RIGHT", -2, 0)
		row.text:SetJustifyH("LEFT")
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row:SetScript("OnEnter", function(btn)
			local data = btn.data
			if not data or not data.pick then return end
			local pick = data.pick
			GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
			local spell = pick.spells and pick.spells[pick.rank or 1] or (pick.spells and pick.spells[1])
			if spell then GameTooltip:SetHyperlink("spell:" .. spell) else GameTooltip:AddLine(pick.n, 1, 1, 1) end
			local style = STATUS_STYLE[data.status]
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Build: " .. (style and style.tag or data.status), 0.5, 0.75, 1)
			if pick.why and pick.why ~= "" then GameTooltip:AddLine(pick.why, 1, 0.82, 0, true) end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row:SetScript("OnClick", function(btn)
			-- section headings collapse / expand their tree
			if not btn.sectionKey then return end
			local collapsed = ZTAC:GetSettings().collapsed or {}
			collapsed[btn.sectionKey] = not collapsed[btn.sectionKey] or nil
			ZTAC:GetSettings().collapsed = collapsed
			self:Update()
		end)
		self.rows[i] = row
		return row
	end

	function f:Update()
		self:UpdateModeButton()
		local state = ZTAC:Evaluate()
		for _, row in ipairs(self.rows) do row:Hide() end
		if not state then
			UIDropDownMenu_SetText(self.drop, "-")
			self.summary:SetText("No build data for this character.")
			return
		end
		UIDropDownMenu_SetText(self.drop, state.spec .. (state.autoSpec and " (auto)" or (ZTAC.previewSpecID and " (preview)" or "")))
		local detected = state.detectedSpec and ("Active spec: " .. state.detectedSpec) or "Active spec: not chosen yet"
		self.summary:SetText(("%s %s - %s\n%s   |cff7f9fbfClass %d/%d   Spec %d/%d|r"):format(
			state.className, state.spec, state.role or "", detected,
			state.class.done, state.class.total, state.spec_.done, state.spec_.total))

		local i, y, scrollTo = 0, 0, nil
		local collapsed = ZTAC:GetSettings().collapsed or {}
		-- Clickable heading: +/- button, tree name and progress.
		local function Header(key, text, section)
			i = i + 1
			local row = self:GetRow(i)
			row.data, row.sectionKey = nil, key
			row.icon:SetTexture(collapsed[key] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
			row.icon:SetDesaturated(false)
			row.text:SetText(("|cffffd100%s|r  |cff7f9fbf%d/%d|r"):format(text, section.done, section.total))
			row:SetPoint("TOPLEFT", 0, -y)
			row:Show()
			y = y + ROW_HEIGHT + 2
		end
		local function Rows(key, section)
			if collapsed[key] then return end
			for _, data in ipairs(section.rows) do
				i = i + 1
				local row = self:GetRow(i)
				local pick, style = data.pick, STATUS_STYLE[data.status] or STATUS_STYLE.open
				row.data, row.sectionKey = data, nil
				row.icon:SetTexture(SpellIcon(pick.spells) or "Interface\\Icons\\INV_Misc_QuestionMark")
				row.icon:SetDesaturated(data.status == "locked" or data.status == "done")
				local rank = (pick.rank and pick.rank > 1) and (" " .. pick.rank) or ""
				local gate = pick.lvl and (" |cff808080Lv" .. pick.lvl .. "|r") or (pick.rl and (" |cff808080auto " .. pick.rl .. "|r") or "")
				local marker = data.status == "next" and "|cffffd100> |r" or (data.status == "done" and "|cff5fb85f+ |r" or "  ")
				row.text:SetText(marker .. style.color .. pick.n .. rank .. "|r |cff7f9fbf[" .. (pick.kind or "T") .. "]|r" .. gate)
				row:SetPoint("TOPLEFT", 0, -y)
				row:Show()
				if data.status == "next" and not scrollTo then scrollTo = y end
				y = y + ROW_HEIGHT
			end
		end
		Header("class", "Class tree", state.class)
		Rows("class", state.class)
		y = y + 6
		Header("spec", "Spec tree - " .. state.spec, state.spec_)
		Rows("spec", state.spec_)
		self.child:SetHeight(math.max(y, 10))
		if scrollTo and not self.scrolledOnce then
			self.scroll:SetVerticalScroll(math.max(0, scrollTo - ROW_HEIGHT * 2))
			self.scrolledOnce = true
		end
	end

	f:SetScript("OnShow", function(self) self.scrolledOnce = nil; self:Update() end)
	return f
end

function ZTAC:GetPopout()
	if not self.Popout then self.Popout = CreatePopout() end
	return self.Popout
end

function ZTAC:PlacePopout()
	local f = self:GetPopout()
	local talent = _G.CoATalentFrame
	f:ClearAllPoints()
	if talent and talent:IsShown() and not f.userMoved then
		f:SetPoint("TOPLEFT", talent, "TOPRIGHT", 4, 0)
		return
	end
	local pos = self:GetSettings().pos
	if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", UIParent, "CENTER", 260, 0) end
end

function ZTAC:TogglePopout()
	local f = self:GetPopout()
	if f:IsShown() then f:Hide() else self:PlacePopout(); f:Show() end
end

-- Open beside the CoA talent window, close with it (unless the user turned that off).
function ZTAC:HookTalentFrame()
	local talent = _G.CoATalentFrame
	if not talent or self.talentHooked or not self:IsActive() then return end
	self.talentHooked = true
	if ZTAC.HookTreeOverlay then ZTAC:HookTreeOverlay() end
	if ZTAC.HookPreview then ZTAC:HookPreview() end
	talent:HookScript("OnShow", function()
		if ZTAC.UpdateOverlay then ZTAC:UpdateOverlay() end
		if ZTAC:GetSettings().autoShow == false then return end
		ZTAC:PlacePopout()
		ZTAC:GetPopout():Show()
	end)
	talent:HookScript("OnHide", function()
		local f = ZTAC.Popout
		if f and f:IsShown() then f:Hide() end
	end)
end
