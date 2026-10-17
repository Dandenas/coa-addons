-------------------------------------------------------------------------------------------------------------
--
-- AzerothAdmin quality-of-life additions (CoA addons, https://github.com/Dandenas)
--
-- * The main window and the popup window can be dragged by their top bars (or anywhere not covered by a
--   control), keep their position between sessions and can be locked (Misc page). "Reset position" centres them.
-- * A window scale slider (Misc page).
-- * Color presets for the background / frame / button colors, plus a "My colors" slot that saves your own
--   (Misc page). A preset fills the color swatches; "Update Changes" applies them, as with hand-picked colors.
--
-- Everything is set up after AzerothAdmin builds its frames (hook on AzerothAdmin:CreateFrames), so the
-- addon's own files stay unchanged apart from this file's line in AzerothAdmin.toc.
-- License: GPLv3+, like AzerothAdmin.
--
-------------------------------------------------------------------------------------------------------------

local QoL = {}
AzerothAdmin.CoAQoL = QoL

local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.5, 1.5, 0.05

-- Colors as AzerothAdmin stores them (its own defaults use 0-255 values, which the textures clamp).
QoL.PRESETS = {
  { name = "Default", backgrounds = { 0, 0, 0 }, frames = { 102, 102, 102 }, buttons = { 33, 164, 210 } },
  { name = "Zygor", backgrounds = { 0.07, 0.07, 0.08 }, frames = { 0.13, 0.13, 0.14 }, buttons = { 1.0, 0.38, 0.0 } },
  { name = "Midnight", backgrounds = { 0.02, 0.03, 0.08 }, frames = { 0.08, 0.12, 0.22 }, buttons = { 0.2, 0.45, 0.85 } },
  { name = "Horde", backgrounds = { 0.1, 0.02, 0.02 }, frames = { 0.3, 0.06, 0.06 }, buttons = { 0.75, 0.12, 0.1 } },
  { name = "Alliance", backgrounds = { 0.02, 0.04, 0.12 }, frames = { 0.08, 0.15, 0.35 }, buttons = { 0.85, 0.7, 0.25 } },
  { name = "Ascension", backgrounds = { 0.06, 0.02, 0.1 }, frames = { 0.2, 0.1, 0.32 }, buttons = { 0.55, 0.3, 0.85 } },
  { name = "Forest", backgrounds = { 0.02, 0.06, 0.03 }, frames = { 0.1, 0.22, 0.12 }, buttons = { 0.25, 0.65, 0.3 } },
  { name = "Slate", backgrounds = { 0.25, 0.25, 0.27 }, frames = { 0.45, 0.45, 0.47 }, buttons = { 0.75, 0.75, 0.78 } },
}
local CUSTOM = "My colors"
-- color keys in the db, and the Misc page swatch that shows each one
local SWATCHES = { backgrounds = "ma_bgcolorshowbutton_texture", frames = "ma_frmcolorshowbutton_texture",
                   buttons = "ma_btncolorshowbutton_texture" }

local function Style()
  return AzerothAdmin.db.profile.style
end

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff21a4d2AzerothAdmin:|r " .. msg)
end

---------------------------------------------------------------------------
-- Window position, lock and scale
---------------------------------------------------------------------------

-- Positions are stored as the window centre's offset from the screen centre, in UIParent units, so they
-- survive scale changes.
function QoL:SavePosition(frame)
  local cx, cy = frame:GetCenter()
  if not cx then return end
  local s = frame:GetScale()
  local style = Style()
  style.coaPositions = style.coaPositions or {}
  local pos = { x = cx * s - UIParent:GetWidth() / 2, y = cy * s - UIParent:GetHeight() / 2 }
  style.coaPositions[frame:GetName()] = pos
  self:ApplyPosition(frame)
end

function QoL:ApplyPosition(frame)
  local pos = Style().coaPositions and Style().coaPositions[frame:GetName()]
  local s = frame:GetScale()
  frame:ClearAllPoints()
  if pos then
    frame:SetPoint("CENTER", UIParent, "CENTER", pos.x / s, pos.y / s)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

function QoL:IsLocked()
  return Style().coaLockWindows and true or false
end

-- frame: the window; handles: frames that start a drag of it (the window itself and its top bar)
function QoL:MakeMovable(frame, handles)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  for _, handle in ipairs(handles) do
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
      if not QoL:IsLocked() then frame:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
      frame:StopMovingOrSizing()
      frame:SetUserPlaced(false)   -- the saved variables keep the position, not the client's layout cache
      QoL:SavePosition(frame)
    end)
  end
  self:ApplyPosition(frame)
end

function QoL:ClampScale(value)
  value = tonumber(value) or 1
  value = math.floor(value / SCALE_STEP + 0.5) * SCALE_STEP
  value = math.floor(value * 100 + 0.5) / 100   -- 20 * 0.05 is 1.0000000000000002
  if value < MIN_SCALE then value = MIN_SCALE end
  if value > MAX_SCALE then value = MAX_SCALE end
  return value
end

function QoL:SetScale(value)
  value = self:ClampScale(value)
  Style().coaScale = value
  for _, frame in ipairs(self.windows or {}) do
    frame:SetScale(value)
    self:ApplyPosition(frame)
  end
end

function QoL:ResetPositions()
  Style().coaPositions = nil
  for _, frame in ipairs(self.windows or {}) do
    self:ApplyPosition(frame)
  end
  Print("window position reset.")
end

---------------------------------------------------------------------------
-- Color presets
---------------------------------------------------------------------------

local function CopyColor(c)
  if not c then return nil end
  return { r = c.r or c[1], g = c.g or c[2], b = c.b or c[3] }
end

-- the colors as currently chosen on the Misc page: picked but not yet applied (buffer), else applied
function QoL:CurrentColors()
  local color = Style().color
  local current = {}
  for key in pairs(SWATCHES) do
    current[key] = CopyColor((color.buffer and color.buffer[key]) or color[key])
  end
  return current
end

function QoL:GetPreset(name)
  if name == CUSTOM then
    return Style().color.coaCustom
  end
  for _, preset in ipairs(self.PRESETS) do
    if preset.name == name then return preset end
  end
end

-- fills the buffer (what "Update Changes" applies) and the swatches
function QoL:ApplyPreset(name)
  local preset = self:GetPreset(name)
  if not preset then return false end
  local color = Style().color
  color.buffer = color.buffer or {}
  for key, swatch in pairs(SWATCHES) do
    local c = CopyColor(preset[key])
    if c then
      color.buffer[key] = c
      if _G[swatch] then _G[swatch]:SetTexture(c.r, c.g, c.b) end
    end
  end
  Print(("preset '%s' selected. Click Update Changes to apply it."):format(name))
  return true
end

function QoL:SaveCustom()
  Style().color.coaCustom = self:CurrentColors()
  Print("your current colors are saved as 'My colors'.")
end

---------------------------------------------------------------------------
-- Misc page controls
---------------------------------------------------------------------------

function QoL:CreateMiscControls()
  local style = Style()
  local btnColor = style.color.buttons
  local btnAlpha = style.transparency.buttons

  -- Lock window (under "Instant teleport")
  FrameLib:BuildButton({
    type = "CheckButton",
    name = "ma_coalockwindowbutton",
    group = "misc",
    parent = ma_midframe,
    size = { width = 22, height = 22 },
    setpoint = { pos = "TOPLEFT", offX = 160, offY = -144 },
    text = "Lock window positions",
    inherits = "OptionsCheckButtonTemplate"
  })
  ma_coalockwindowbutton:SetChecked(self:IsLocked())
  ma_coalockwindowbutton:SetScript("OnClick", function(cb)
    Style().coaLockWindows = cb:GetChecked() and true or false
  end)

  FrameLib:BuildButton({
    name = "ma_coaresetpositionbutton",
    group = "misc",
    parent = ma_midframe,
    texture = { name = "ma_coaresetpositionbutton_texture", color = { btnColor.r, btnColor.g, btnColor.b, btnAlpha } },
    size = { width = 110, height = 20 },
    setpoint = { pos = "TOPLEFT", offX = 166, offY = -170 },
    text = "Reset position"
  })
  ma_coaresetpositionbutton:SetScript("OnClick", function() QoL:ResetPositions() end)

  -- Window scale
  FrameLib:BuildFrame({
    type = "Slider",
    name = "ma_coascaleslider",
    group = "misc",
    parent = ma_midframe,
    size = { width = 130 },
    setpoint = { pos = "TOPLEFT", offX = 160, offY = -210 },
    inherits = "OptionsSliderTemplate"
  })
  ma_coascaleslider:SetMinMaxValues(MIN_SCALE, MAX_SCALE)
  ma_coascaleslider:SetValueStep(SCALE_STEP)
  ma_coascaleslider:SetValue(self:ClampScale(style.coaScale or 1))
  _G["ma_coascaleslider" .. "Low"]:SetText(("%d%%"):format(MIN_SCALE * 100))
  _G["ma_coascaleslider" .. "High"]:SetText(("%d%%"):format(MAX_SCALE * 100))
  local function ScaleLabel(v) _G["ma_coascaleslider" .. "Text"]:SetText(("Window Scale: %d%%"):format(v * 100 + 0.5)) end
  ScaleLabel(self:ClampScale(style.coaScale or 1))
  -- The slider sits inside the window it scales: scaling while the thumb is dragged moves the slider under the
  -- cursor, which changes the value again and runs it to 50% or 150%. So while dragging only the label follows;
  -- the scale is applied on release (a click on the track applies straight away).
  ma_coascaleslider:SetScript("OnMouseDown", function(slider) slider.coaDragging = true end)
  ma_coascaleslider:SetScript("OnMouseUp", function(slider)
    slider.coaDragging = nil
    QoL:SetScale(slider:GetValue())
  end)
  ma_coascaleslider:SetScript("OnValueChanged", function(slider, v)
    v = QoL:ClampScale(v)
    ScaleLabel(v)
    if not slider.coaDragging and v ~= Style().coaScale then QoL:SetScale(v) end
  end)

  -- Color presets (right side, under the weather controls)
  FrameLib:BuildFontString({
    name = "ma_coapresetlabel",
    group = "misc",
    parent = ma_midframe,
    text = "Color presets",
    setpoint = { pos = "TOPRIGHT", offX = -165, offY = -46 }
  })
  FrameLib:BuildFrame({
    name = "ma_coapresetdropdown",
    group = "misc",
    parent = ma_midframe,
    size = { width = 110, height = 20 },
    setpoint = { pos = "TOPRIGHT", offX = -135, offY = -58 },
    inherits = "UIDropDownMenuTemplate"
  })
  local function Initialize()
    local info = UIDropDownMenu_CreateInfo()
    local names = {}
    for _, preset in ipairs(QoL.PRESETS) do names[#names + 1] = preset.name end
    if Style().color.coaCustom then names[#names + 1] = CUSTOM end
    for _, name in ipairs(names) do
      info.text = name
      info.value = name
      info.checked = (UIDropDownMenu_GetSelectedValue(ma_coapresetdropdown) == name)
      info.func = function(button)
        UIDropDownMenu_SetSelectedValue(ma_coapresetdropdown, button.value)
        QoL:ApplyPreset(button.value)
      end
      UIDropDownMenu_AddButton(info, 1)
    end
  end
  UIDropDownMenu_Initialize(ma_coapresetdropdown, Initialize)
  UIDropDownMenu_SetWidth(ma_coapresetdropdown, 100)
  UIDropDownMenu_SetButtonWidth(ma_coapresetdropdown, 20)
  UIDropDownMenu_SetText(ma_coapresetdropdown, "Choose...")

  FrameLib:BuildButton({
    name = "ma_coasavecolorsbutton",
    group = "misc",
    parent = ma_midframe,
    texture = { name = "ma_coasavecolorsbutton_texture", color = { btnColor.r, btnColor.g, btnColor.b, btnAlpha } },
    size = { width = 110, height = 20 },
    setpoint = { pos = "TOPRIGHT", offX = -10, offY = -61 },
    text = "Save my colors"
  })
  ma_coasavecolorsbutton:SetScript("OnClick", function() QoL:SaveCustom() end)

  FrameLib:BuildFontString({
    name = "ma_coapresethint",
    group = "misc",
    parent = ma_midframe,
    object = "GameFontHighlightSmall",
    text = "Pick a preset, then click Update Changes.",
    setpoint = { pos = "TOPRIGHT", offX = -12, offY = -90 }
  })
end

---------------------------------------------------------------------------
-- Setup, after AzerothAdmin has built (and hidden) its frames
---------------------------------------------------------------------------

-- The mini menu (the side bar) moved only while Left Ctrl was held. Plain drag now, unless the windows are
-- locked; its own OnDragStop keeps saving its position (edge snap or free placement, as set on the Misc page).
-- Its logo button also toggles the menu on click, so the click that ends a drag on it is ignored.
function QoL:FreeMiniMenuDrag()
  if not ma_minibgframe then return end
  for _, handle in ipairs({ ma_minibgframe, ma_mm_logoframe }) do
    if handle then
      handle:SetScript("OnDragStart", function()
        if not QoL:IsLocked() then ma_minibgframe:StartMoving() end
      end)
      handle:HookScript("OnDragStop", function(h) h.coaDragEnded = GetTime() end)
      -- only buttons have OnClick; asking a plain frame (ma_minibgframe) for it raises an error
      local onClick = handle:HasScript("OnClick") and handle:GetScript("OnClick")
      if onClick then
        handle:SetScript("OnClick", function(h, ...)
          if h.coaDragEnded and GetTime() - h.coaDragEnded < 0.3 then return end   -- the release of a drag
          return onClick(h, ...)
        end)
      end
    end
  end
end

-- Each part runs on its own: an error is reported through the normal error handler and the other parts
-- still get set up (one failing part used to leave the whole Misc page without its new controls).
local function Try(label, fn)
  local ok, err = pcall(fn)
  if not ok then
    geterrorhandler()(("AzerothAdmin CoA additions (%s): %s"):format(label, tostring(err)))
  end
end

function QoL:Setup()
  self.windows = {}
  Try("main window", function()
    if ma_bgframe then
      self.windows[#self.windows + 1] = ma_bgframe
      -- ma_menubgframe is the tab strip above the window's own area; it took no mouse input, so clicks on it fell through
      self:MakeMovable(ma_bgframe, { ma_bgframe, ma_topframe, ma_menubgframe })
    end
  end)
  Try("mini menu", function() self:FreeMiniMenuDrag() end)
  Try("popup window", function()
    if ma_popupframe then
      self.windows[#self.windows + 1] = ma_popupframe
      self:MakeMovable(ma_popupframe, { ma_popupframe, ma_popuptopframe })
    end
  end)
  Try("window scale", function()
    local scale = self:ClampScale(Style().coaScale or 1)
    for _, frame in ipairs(self.windows) do
      frame:SetScale(scale)
      self:ApplyPosition(frame)
    end
  end)
  Try("Misc page", function()
    if ma_midframe then
      self:CreateMiscControls()
    end
  end)
  FrameLib:HandleGroup("misc", function(frame) frame:Hide() end)   -- like the rest of the Misc page until shown
end

hooksecurefunc(AzerothAdmin, "CreateFrames", function() QoL:Setup() end)
