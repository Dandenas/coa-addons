-- Regression for the CoA quality-of-life additions to AzerothAdmin (Modules/CoAQoL.lua): the windows are dragged
-- by their top bars, keep their position (also across scale changes) and can be locked; a window scale slider;
-- color presets and a "My colors" slot on the Misc page.
-- Usage: lua test_azerothadmin_coa.lua <AzerothAdmin addon directory>
local root = arg[1] or "AzerothAdmin"

-- the module is loaded by the .toc, after the frames it hooks
local toc = assert(io.open(root .. "/AzerothAdmin.toc")):read("*a")
local frames = toc:find("Frames\\Frames.lua", 1, true)
local qol = toc:find("Modules\\CoAQoL.lua", 1, true)
assert(qol, "AzerothAdmin.toc loads Modules\\CoAQoL.lua")
assert(frames and qol > frames, "Modules\\CoAQoL.lua loads after Frames\\Frames.lua")

-- stand-in frames: remember what the module does to them
local env
-- Like WoW, a widget only has the script handlers of its type: asking a plain Frame for "OnClick" is an error.
local TYPE_SCRIPTS = { OnClick = { Button = true, CheckButton = true }, OnValueChanged = { Slider = true } }
local function Frame(name, kind)
	local f = { name = name, kind = kind or "Frame", scripts = {}, scale = 1, cx = 960, cy = 540, shown = true }
	local function Check(self, k)
		local only = TYPE_SCRIPTS[k]
		if only and not only[self.kind] then error(("%s %s doesn't have a %q script"):format(self.kind, tostring(self.name), k), 3) end
	end
	function f:HasScript(k) local only = TYPE_SCRIPTS[k]; return not only or only[self.kind] or false end
	function f:GetName() return self.name end
	function f:SetScript(k, fn) Check(self, k); self.scripts[k] = fn end
	function f:GetScript(k) Check(self, k); return self.scripts[k] end
	function f:HookScript(k, fn)
		Check(self, k)
		local old = self.scripts[k]
		self.scripts[k] = function(...) if old then old(...) end fn(...) end
	end
	function f:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
	function f:GetValue() return self.value end
	function f:StartMoving() self.moving = true end
	function f:StopMovingOrSizing() self.moving = false end
	function f:GetCenter() return self.cx, self.cy end
	function f:SetScale(s) self.scale = s end
	function f:GetScale() return self.scale end
	function f:ClearAllPoints() self.point = nil end
	function f:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
	function f:SetChecked(v) self.checked = v end
	function f:GetChecked() return self.checked end
	function f:SetTexture(r, g, b) self.color = { r, g, b } end
	function f:SetText(t) self.text = t end
	function f:Hide() self.shown = false end
	function f:Show() self.shown = true end
	-- unknown methods (Capitalised) do nothing; unknown fields are nil, as on real frames
	setmetatable(f, { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end })
	if name then env[name] = f end
	return f
end

env = setmetatable({}, { __index = _G })
env._G = env
local style = {
	transparency = { buttons = 1 },
	color = { buffer = {}, backgrounds = { r = 0, g = 0, b = 0 }, frames = { r = 102, g = 102, b = 102 },
	          buttons = { r = 33, g = 164, b = 210 } },
}
env.AzerothAdmin = { db = { profile = { style = style } } }
env.UIParent = setmetatable({ GetWidth = function() return 1920 end, GetHeight = function() return 1080 end },
	{ __index = function() return function() end end })
env.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
local built, groups = {}, {}
local function Build(def, kind)
	local f = Frame(def.name, def.type or kind)
	built[def.name] = def
	groups[def.group] = groups[def.group] or {}
	table.insert(groups[def.group], f)
	if def.type == "Slider" then Frame(def.name .. "Low"); Frame(def.name .. "High"); Frame(def.name .. "Text") end
	if def.texture and def.texture.name then Frame(def.texture.name) end
	return f
end
env.FrameLib = { BuildFrame = function(_, d) return Build(d, "Frame") end, BuildButton = function(_, d) return Build(d, "Button") end,
                 BuildFontString = function(_, d) return Build(d, "FontString") end,
                 HandleGroup = function(_, g, fn) for _, f in ipairs(groups[g] or {}) do fn(f) end end }
local dropdownInit, added = nil, {}
env.UIDropDownMenu_Initialize = function(_, fn) dropdownInit = fn end
env.UIDropDownMenu_CreateInfo = function() return {} end
env.UIDropDownMenu_AddButton = function(info) added[#added + 1] = info.text end
env.UIDropDownMenu_GetSelectedValue = function() end
env.UIDropDownMenu_SetSelectedValue = function() end
env.UIDropDownMenu_SetWidth, env.UIDropDownMenu_SetButtonWidth, env.UIDropDownMenu_SetText = function() end, function() end, function() end
local hooked
env.hooksecurefunc = function(t, name, fn) assert(t == env.AzerothAdmin and name == "CreateFrames"); hooked = fn end
for _, n in ipairs({ "ma_bgframe", "ma_topframe", "ma_menubgframe", "ma_popupframe", "ma_popuptopframe", "ma_midframe",
                     "ma_minibgframe",
                     "ma_bgcolorshowbutton_texture", "ma_frmcolorshowbutton_texture", "ma_btncolorshowbutton_texture" }) do
	Frame(n)
end
Frame("ma_mm_logoframe", "Button")
-- an error the module reports (its setup steps run protected) fails the test instead of passing unnoticed
env.geterrorhandler = function() return function(msg) error(msg, 0) end end
-- the mini menu as AzerothAdmin builds it: Ctrl-only drag, its own position saving, and a logo that toggles on click
local now, ctrl, miniSaved, logoClicks = 100, false, 0, 0
env.GetTime = function() return now end
env.ma_minibgframe:SetScript("OnDragStart", function(self) if ctrl then self:StartMoving() end end)
env.ma_minibgframe:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); miniSaved = miniSaved + 1 end)
env.ma_mm_logoframe:SetScript("OnDragStart", function() if ctrl then env.ma_minibgframe:StartMoving() end end)
env.ma_mm_logoframe:SetScript("OnDragStop", function() env.ma_minibgframe:StopMovingOrSizing(); miniSaved = miniSaved + 1 end)
env.ma_mm_logoframe:SetScript("OnClick", function() logoClicks = logoClicks + 1 end)

local chunk = assert(loadfile(root .. "/Modules/CoAQoL.lua"))
setfenv(chunk, env)
chunk()
assert(hooked, "the module hooks AzerothAdmin:CreateFrames")
hooked()
local QoL = env.AzerothAdmin.CoAQoL
local main, top = env.ma_bgframe, env.ma_topframe

-- drag by the top bar; the position is saved as an offset from the screen centre
top.scripts.OnDragStart()
assert(main.moving, "dragging the top bar moves the main window")
main.cx, main.cy = 1100, 600
top.scripts.OnDragStop()
local pos = style.coaPositions and style.coaPositions.ma_bgframe
assert(pos and pos.x == 140 and pos.y == 60, "the window position is saved")
assert(main.point[1] == "CENTER" and main.point[4] == 140 and main.point[5] == 60, "the window stays where it was dropped")
assert(env.ma_popuptopframe.scripts.OnDragStart, "the popup window is movable by its top bar too")
main.moving = false
env.ma_menubgframe.scripts.OnDragStart()
assert(main.moving, "the tab strip above the window is a drag handle too")
env.ma_menubgframe.scripts.OnDragStop()

-- the mini menu drags without Ctrl and still saves its own position; the click ending a drag on its logo is ignored
local mini, logo = env.ma_minibgframe, env.ma_mm_logoframe
mini.scripts.OnDragStart(mini)
assert(mini.moving, "the mini menu moves without holding Ctrl")
mini.scripts.OnDragStop(mini)
assert(miniSaved == 1 and not mini.moving, "the mini menu still saves its position")
logo.scripts.OnDragStart(logo)
assert(mini.moving, "dragging the mini menu's logo moves the mini menu")
logo.scripts.OnDragStop(logo)
logo.scripts.OnClick(logo)
assert(logoClicks == 0, "releasing a drag on the logo doesn't toggle the mini menu")
now = now + 1
logo.scripts.OnClick(logo)
assert(logoClicks == 1, "a normal click on the logo still toggles the mini menu")

-- scale: clamped to 5% steps, applied to both windows, position kept on screen
QoL:SetScale(1.23)
assert(style.coaScale == 1.25 and main.scale == 1.25 and env.ma_popupframe.scale == 1.25, "the scale is applied to both windows")
assert(math.abs(main.point[4] - 140 / 1.25) < 1e-9, "the window keeps its screen position when scaled")
assert(QoL:ClampScale(9) == 1.5 and QoL:ClampScale(0.1) == 0.5, "the scale stays within 50-150%")

-- the slider: while its thumb is dragged only the label follows (scaling the window under the cursor ran the value
-- to 50% or 150%); the scale is applied on release, and a click on the track applies straight away
local slider = env.ma_coascaleslider
slider.scripts.OnMouseDown(slider)
slider:SetValue(0.8)
slider:SetValue(0.9)
assert(style.coaScale == 1.25 and main.scale == 1.25, "the window isn't rescaled while the slider is dragged")
assert(env.ma_coascalesliderText.text == "Window Scale: 90%", "the label follows the slider while dragging")
slider.scripts.OnMouseUp(slider)
assert(style.coaScale == 0.9 and main.scale == 0.9, "the scale is applied on release")
slider:SetValue(1.0)
assert(style.coaScale == 1.0, "a value change without dragging applies straight away")

-- lock
style.coaLockWindows = true
main.moving = false
top.scripts.OnDragStart()
assert(not main.moving, "a locked window does not move")
env.ma_coalockwindowbutton.checked = false
env.ma_coalockwindowbutton.scripts.OnClick(env.ma_coalockwindowbutton)
assert(style.coaLockWindows == false, "the Lock checkbox unlocks")

-- reset
env.ma_coaresetpositionbutton.scripts.OnClick()
assert(style.coaPositions == nil and main.point[4] == 0 and main.point[5] == 0, "Reset position centres the window")

-- presets fill the buffer (applied by Update Changes) and the swatches
assert(QoL:ApplyPreset("Zygor"), "the Zygor preset exists")
assert(style.color.buffer.buttons.r == 1.0 and style.color.buffer.buttons.g == 0.38, "a preset fills the buffer")
assert(env.ma_btncolorshowbutton_texture.color[1] == 1.0, "a preset updates the swatch")
assert(style.color.buttons.r == 33, "the applied colors only change on Update Changes")
dropdownInit()
assert(#added == #QoL.PRESETS, "the dropdown lists the presets")

-- My colors
QoL:SaveCustom()
assert(style.color.coaCustom and style.color.coaCustom.buttons.r == 1.0, "Save my colors stores the current choice")
style.color.buffer = {}
assert(QoL:ApplyPreset("My colors") and style.color.buffer.buttons.g == 0.38, "My colors can be applied again")
added = {}
dropdownInit()
assert(added[#added] == "My colors", "the dropdown offers My colors once saved")

-- the new Misc controls start hidden, like the rest of the Misc page
assert(env.ma_coascaleslider.shown == false and env.ma_coapresetdropdown.shown == false, "the Misc controls start hidden")

print("AzerothAdmin CoA regression passed (movable windows, lock, scale, color presets)")
