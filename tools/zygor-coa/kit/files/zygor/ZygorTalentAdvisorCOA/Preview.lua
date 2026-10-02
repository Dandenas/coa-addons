-- Preview: when the panel follows a build picked for a spec other than the active one, the CoA
-- talent window shows that spec's tree, so the build's numbers can be read on it. Display only:
-- it uses the window's own CoATreeViewMixin:SetSpecID, learns nothing, and clicks on the
-- previewed tree are ignored. The window goes back to the active spec when the panel does (Auto,
-- or picking the active spec). /ztacoa preview turns this off.

local ZTAC = ZygorTalentAdvisorCOA
if not ZTAC then return end

local BANNER_TEXT = "PREVIEW - not your active spec"
local BLOCKED_TEXT = "Preview only - choose Auto in the Zygor advisor to edit your talents."
local BLOCKED_COLOR = { 1, 1, 0.55 } -- pale yellow: readable over the bright tree art

function ZTAC:IsPreviewEnabled()
	return self:GetSettings().preview ~= false
end

function ZTAC:SetPreviewEnabled(on)
	self:GetSettings().preview = on and true or false
	self:Refresh()
end

-- The client spec ID for one of the data's spec names (DetectSpec's matching, in reverse).
function ZTAC:GetSpecIDFor(spec)
	local _, token = UnitClass("player")
	local info = C_ClassInfo
	if not (spec and token and info and info.GetAllSpecs and info.GetSpecInfo) then return nil end
	local ok, specs = pcall(info.GetAllSpecs, token)
	if not ok or type(specs) ~= "table" then return nil end
	for _, file in ipairs(specs) do
		local found, specInfo = pcall(info.GetSpecInfo, token, file)
		if found and type(specInfo) == "table" and specInfo.ID and self:MatchSpecInfo(specInfo) == spec then
			return specInfo.ID
		end
	end
end

-- The spec ID to preview, or nil: only for a build picked by hand that isn't the active spec, and
-- only once the character has an active spec (before that the window shows its spec picker).
function ZTAC:GetPreviewSpecID()
	if not (self:IsActive() and self:IsPreviewEnabled()) then return nil end
	local spec, auto = self:GetSelectedSpec()
	if auto or not spec then return nil end
	local detected = self:DetectSpec()
	if not detected or detected == spec then return nil end
	return self:GetSpecIDFor(spec)
end

local function GetBanner(tree)
	local banner = tree.ZTACPreviewBanner
	if banner then return banner end
	banner = CreateFrame("Frame", nil, tree)
	banner:SetAllPoints(tree)
	banner:SetFrameLevel(tree:GetFrameLevel() + 30)
	banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	-- just above the spec tree's title
	if tree.Label then
		banner.text:SetPoint("BOTTOM", tree.Label, "TOP", 0, 2)
	else
		banner.text:SetPoint("TOP", tree, "TOP", 0, 90)
	end
	banner.text:SetTextColor(1, 0.5, 0.1)
	banner.text:SetText(BANNER_TEXT)
	tree.ZTACPreviewBanner = banner
	return banner
end

-- Shows the previewed spec's tree, or returns the window to the active spec after a preview.
function ZTAC:UpdatePreview()
	local frame = _G.CoATalentFrame
	local view = frame and frame.TreeView
	if not (view and type(view.SetSpecID) == "function") then return end
	local want = self:GetPreviewSpecID()
	if want then
		if view.specID ~= want then view:SetSpecID(want) end
	elseif self.previewSpecID then
		local api = C_CharacterAdvancement
		local ok, active = pcall(api and api.GetActiveChrSpec)
		if ok and active and view.specID ~= active then view:SetSpecID(active) end
	end
	self.previewSpecID = want
	if view.SpecTree then
		local banner = GetBanner(view.SpecTree)
		if want then banner:Show() else banner:Hide() end
	end
	self:GuardPreviewClicks()
end

-- A click on a previewed tree would try to learn another spec's talent: ignore it while
-- previewing (shift-click still links the spell in chat). Each node button is wrapped once.
function ZTAC:GuardPreviewClicks()
	local view = _G.CoATalentFrame and _G.CoATalentFrame.TreeView
	local tree = view and view.SpecTree
	if not (tree and tree.EnumerateNodes) then return end
	for button in tree:EnumerateNodes() do
		if not button.ZTACGuarded and button.GetScript then
			local original = button:GetScript("OnClick")
			if original then
				button.ZTACGuarded = true
				button:SetScript("OnClick", function(btn, ...)
					if ZTAC.previewSpecID and not IsModifiedClick("CHATLINK") then
						UIErrorsFrame:AddMessage(BLOCKED_TEXT, BLOCKED_COLOR[1], BLOCKED_COLOR[2], BLOCKED_COLOR[3])
						return
					end
					return original(btn, ...)
				end)
			end
		end
	end
end

-- The window resets itself to the active spec when it opens and when the spec changes; the
-- preview is re-applied after that, and new tree buttons are guarded as the tree rebuilds.
function ZTAC:HookPreview()
	local frame = _G.CoATalentFrame
	if not frame or frame.ZTACPreviewHooked then return end
	frame.ZTACPreviewHooked = true
	if type(frame.UpdateActiveSpec) == "function" then
		hooksecurefunc(frame, "UpdateActiveSpec", function() ZTAC:UpdatePreview() end)
	end
	local tree = frame.TreeView and frame.TreeView.SpecTree
	if tree and type(tree.BuildTree) == "function" then
		hooksecurefunc(tree, "BuildTree", function() ZTAC:GuardPreviewClicks() end)
	end
	self:UpdatePreview()
end
