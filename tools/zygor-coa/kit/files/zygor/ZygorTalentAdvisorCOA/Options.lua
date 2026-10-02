-- The "CoA Talent Advisor" tab in Zygor's options. Zygor's Options.lua registers this table and
-- GuideBrowser.lua lists it beside Gear Advisor, on CoA characters only. The settings are kept
-- per character, like the advisor's other settings, and also have slash commands (/ztacoa).

local ZTAC = ZygorTalentAdvisorCOA
if not ZTAC then return end

ZTAC.OPTIONS_APP = "ZygorGuidesViewer-TalentAdvisorCOA"

-- Panel background opacity: 0 is the standard Zygor dialog background (other windows show
-- through it), 1 a solid background.
function ZTAC:GetPanelOpacity()
	local v = tonumber(self:GetSettings().opacity) or 0
	return math.max(0, math.min(1, v))
end

function ZTAC:SetPanelOpacity(v)
	self:GetSettings().opacity = math.max(0, math.min(1, tonumber(v) or 0))
	if self.ApplyPanelOpacity then self:ApplyPanelOpacity() end
end

function ZTAC:GetOptionsTable()
	if self.optionsTable then return self.optionsTable end
	self.optionsTable = {
		name = "CoA Talent Advisor",
		desc = "Talent advisor for Conquest of Azeroth classes.",
		type = "group",
		order = 4.3,
		args = {
			intro = {
				type = "description",
				order = 1,
				name = "Leveling builds for your Conquest of Azeroth class, shown in a panel beside the talent window and as numbers on its trees.\n",
			},
			opacity = {
				type = "range",
				order = 2,
				name = "Panel background opacity",
				desc = "How solid the advisor panel's background is. 0% is the standard Zygor background, which other windows can show through; 100% is solid.",
				min = 0, max = 1, step = 0.05,
				isPercent = true,
				width = "double",
				get = function() return ZTAC:GetPanelOpacity() end,
				set = function(_, v) ZTAC:SetPanelOpacity(v) end,
			},
			autoShow = {
				type = "toggle",
				order = 3,
				name = "Open with the talent window",
				desc = "Show the advisor panel beside the talent window whenever it opens. /ztacoa still opens it at any time.",
				width = "full",
				get = function() return ZTAC:GetSettings().autoShow ~= false end,
				set = function(_, v) ZTAC:GetSettings().autoShow = v and true or false end,
			},
			numbers = {
				type = "select",
				order = 4,
				name = "Numbers on the talent tree",
				desc = "Points: how many points the build puts in each talent. Order: the step at which the build takes it.",
				values = { points = "Points", order = "Order", off = "Off" },
				get = function() return ZTAC:IsOverlayEnabled() and ZTAC:GetOverlayMode() or "off" end,
				set = function(_, v)
					if v == "off" then ZTAC:SetOverlayEnabled(false) else ZTAC:SetOverlayMode(v) end
				end,
			},
			preview = {
				type = "toggle",
				order = 5,
				name = "Preview other specs on the talent tree",
				desc = "Picking another spec's build in the advisor shows that spec's tree in the talent window (display only - nothing is learned).",
				width = "full",
				get = function() return ZTAC:IsPreviewEnabled() end,
				set = function(_, v) ZTAC:SetPreviewEnabled(v) end,
			},
		},
	}
	return self.optionsTable
end
