local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]

-- Styled Widgets Library for SkyInfoTiles
-- Inspired by EllesmereUI widget system

if not SkyInfoTiles then
  print("ERROR: SkyInfoTiles not found in StyledWidgets.lua!")
  return
end

local Widgets = {}
SkyInfoTiles.StyledWidgets = Widgets

print("SkyInfoTiles: StyledWidgets loaded successfully!")

-------------------------------------------------------------------------------
-- Visual Constants
-------------------------------------------------------------------------------
local ACCENT_COLOR = { r = 0.4, g = 0.8, b = 1.0 }  -- Sky blue accent
local DARK_BG = { r = 0.1, g = 0.1, b = 0.12, a = 0.95 }
local BORDER_COLOR = { r = 0.3, g = 0.3, b = 0.35, a = 1.0 }
local TEXT_WHITE = { r = 1, g = 1, b = 1 }
local TEXT_DIM = { r = 0.7, g = 0.7, b = 0.7 }
local ROW_BG_EVEN = { r = 0.15, g = 0.15, b = 0.18, a = 0.3 }
local ROW_BG_ODD = { r = 0.12, g = 0.12, b = 0.14, a = 0.3 }

-- Toggle colors
local TOGGLE_OFF = { track = {r=0.2, g=0.2, b=0.22, a=0.8}, knob = {r=0.5, g=0.5, b=0.5, a=0.9} }
local TOGGLE_ON = { track = {r=ACCENT_COLOR.r, g=ACCENT_COLOR.g, b=ACCENT_COLOR.b, a=0.8}, knob = {r=1, g=1, b=1, a=1} }

-- Font
local FONT = "Fonts\\FRIZQT__.ttf"

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------
local function CreateSolidTexture(parent, layer, r, g, b, a)
  local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
  tex:SetColorTexture(r, g, b, a or 1)
  return tex
end

-------------------------------------------------------------------------------
-- Row Background
-- Creates alternating row backgrounds for better readability
-------------------------------------------------------------------------------
function Widgets:CreateRowBackground(parent, yOffset, height, index)
  local bg = CreateFrame("Frame", nil, parent)
  bg:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
  bg:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
  bg:SetHeight(height or 40)

  local color = (index % 2 == 0) and ROW_BG_EVEN or ROW_BG_ODD
  local tex = CreateSolidTexture(bg, "BACKGROUND", color.r, color.g, color.b, color.a)
  tex:SetAllPoints()

  return bg
end

-------------------------------------------------------------------------------
-- Section Header
-- Creates a styled section header with accent color
-------------------------------------------------------------------------------
function Widgets:CreateSectionHeader(parent, yOffset, text)
  local header = parent:CreateFontString(nil, "OVERLAY")
  header:SetFont(FONT, 14, "OUTLINE")
  header:SetTextColor(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b)
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
  header:SetText(text)

  -- Divider line
  local line = CreateSolidTexture(parent, "ARTWORK", BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.5)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
  line:SetPoint("RIGHT", parent, "RIGHT", -10, 0)

  return header, 24  -- Return header and height consumed
end

-------------------------------------------------------------------------------
-- Spacer
-- Creates vertical spacing
-------------------------------------------------------------------------------
function Widgets:CreateSpacer(parent, yOffset, height)
  return height or 10
end

-------------------------------------------------------------------------------
-- Toggle Switch
-- Creates an animated toggle switch (similar to iOS style)
-------------------------------------------------------------------------------
function Widgets:CreateToggle(parent, yOffset, labelText, getValue, setValue, tooltipText)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
  row:SetSize(parent:GetWidth() - 20, 30)

  -- Label
  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetFont(FONT, 12, "OUTLINE")
  label:SetTextColor(TEXT_WHITE.r, TEXT_WHITE.g, TEXT_WHITE.b)
  label:SetPoint("LEFT", row, "LEFT", 0, 0)
  label:SetText(labelText)

  -- Toggle button
  local TOGGLE_W, TOGGLE_H = 40, 20
  local KNOB_PAD = 2

  local toggle = CreateFrame("Button", nil, row)
  toggle:SetSize(TOGGLE_W, TOGGLE_H)
  toggle:SetPoint("RIGHT", row, "RIGHT", 0, 0)

  -- Track background
  local track = CreateSolidTexture(toggle, "BACKGROUND",
    TOGGLE_OFF.track.r, TOGGLE_OFF.track.g, TOGGLE_OFF.track.b, TOGGLE_OFF.track.a)
  track:SetAllPoints()

  -- Knob
  local knob = CreateSolidTexture(toggle, "ARTWORK",
    TOGGLE_OFF.knob.r, TOGGLE_OFF.knob.g, TOGGLE_OFF.knob.b, TOGGLE_OFF.knob.a)
  knob:SetSize(TOGGLE_H - KNOB_PAD * 2, TOGGLE_H - KNOB_PAD * 2)

  -- Animation state
  local isOn = false
  local animProgress = 0

  local function UpdateVisual(instant)
    isOn = getValue()
    local targetProgress = isOn and 1 or 0

    if instant then
      animProgress = targetProgress
    else
      -- Simple lerp animation
      animProgress = animProgress * 0.7 + targetProgress * 0.3
    end

    -- Lerp colors
    local function lerp(a, b, t)
      return a + (b - a) * t
    end

    local trackR = lerp(TOGGLE_OFF.track.r, TOGGLE_ON.track.r, animProgress)
    local trackG = lerp(TOGGLE_OFF.track.g, TOGGLE_ON.track.g, animProgress)
    local trackB = lerp(TOGGLE_OFF.track.b, TOGGLE_ON.track.b, animProgress)
    track:SetColorTexture(trackR, trackG, trackB, TOGGLE_OFF.track.a)

    local knobR = lerp(TOGGLE_OFF.knob.r, TOGGLE_ON.knob.r, animProgress)
    local knobG = lerp(TOGGLE_OFF.knob.g, TOGGLE_ON.knob.g, animProgress)
    local knobB = lerp(TOGGLE_OFF.knob.b, TOGGLE_ON.knob.b, animProgress)
    knob:SetColorTexture(knobR, knobG, knobB, TOGGLE_ON.knob.a)

    -- Position knob
    local knobX = KNOB_PAD + (TOGGLE_W - (TOGGLE_H - KNOB_PAD * 2) - KNOB_PAD * 2) * animProgress
    knob:ClearAllPoints()
    knob:SetPoint("LEFT", toggle, "LEFT", knobX, 0)
  end

  -- Click handler
  toggle:SetScript("OnClick", function()
    setValue(not isOn)
    UpdateVisual(false)

    -- Start animation
    if not toggle.animTimer then
      toggle.animTimer = C_Timer.NewTicker(0.02, function()
        if math.abs(animProgress - (isOn and 1 or 0)) < 0.01 then
          toggle.animTimer:Cancel()
          toggle.animTimer = nil
        end
        UpdateVisual(false)
      end)
    end
  end)

  -- Hover effects
  toggle:SetScript("OnEnter", function()
    if tooltipText then
      GameTooltip:SetOwner(toggle, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, 1, 1, 1)
      GameTooltip:Show()
    end
  end)
  toggle:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Initial state
  UpdateVisual(true)

  -- Store refresh function
  toggle.Refresh = function()
    UpdateVisual(true)
  end

  return row, 35  -- Return row and height consumed
end

-------------------------------------------------------------------------------
-- Checkbox (simple styled checkbox)
-------------------------------------------------------------------------------
function Widgets:CreateCheckbox(parent, yOffset, labelText, getValue, setValue, tooltipText)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
  row:SetSize(parent:GetWidth() - 20, 25)

  -- Checkbox
  local check = CreateFrame("CheckButton", nil, row)
  check:SetSize(20, 20)
  check:SetPoint("LEFT", row, "LEFT", 0, 0)

  -- Custom checkbox visuals
  local bg = CreateSolidTexture(check, "BACKGROUND", 0.2, 0.2, 0.22, 0.8)
  bg:SetAllPoints()

  local border = CreateFrame("Frame", nil, check)
  border:SetAllPoints()
  local borderTex = CreateSolidTexture(border, "ARTWORK", BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.6)
  borderTex:SetAllPoints()
  borderTex:SetDrawLayer("ARTWORK", -1)

  local checkMark = check:CreateTexture(nil, "OVERLAY")
  checkMark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  checkMark:SetSize(18, 18)
  checkMark:SetPoint("CENTER")
  checkMark:SetVertexColor(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b)

  -- Label
  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetFont(FONT, 12, "OUTLINE")
  label:SetTextColor(TEXT_WHITE.r, TEXT_WHITE.g, TEXT_WHITE.b)
  label:SetPoint("LEFT", check, "RIGHT", 8, 0)
  label:SetText(labelText)

  -- Update visual
  local function UpdateVisual()
    checkMark:SetShown(getValue())
  end

  check:SetScript("OnClick", function()
    setValue(not getValue())
    UpdateVisual()
  end)

  -- Tooltip
  if tooltipText then
    check:SetScript("OnEnter", function()
      GameTooltip:SetOwner(check, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, 1, 1, 1)
      GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end

  UpdateVisual()

  check.Refresh = UpdateVisual

  return row, 30
end

-------------------------------------------------------------------------------
-- Button (styled button)
-------------------------------------------------------------------------------
function Widgets:CreateButton(parent, yOffset, text, width, onClick, tooltipText)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(width or 150, 30)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)

  -- Background
  local bg = CreateSolidTexture(btn, "BACKGROUND", 0.2, 0.2, 0.25, 0.9)
  bg:SetAllPoints()

  -- Border
  local border = CreateSolidTexture(btn, "ARTWORK", ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.5)
  border:SetPoint("TOPLEFT", 0, 0)
  border:SetPoint("TOPRIGHT", 0, 0)
  border:SetHeight(1)

  local border2 = CreateSolidTexture(btn, "ARTWORK", ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.5)
  border2:SetPoint("BOTTOMLEFT", 0, 0)
  border2:SetPoint("BOTTOMRIGHT", 0, 0)
  border2:SetHeight(1)

  -- Text
  local label = btn:CreateFontString(nil, "OVERLAY")
  label:SetFont(FONT, 12, "OUTLINE")
  label:SetTextColor(TEXT_WHITE.r, TEXT_WHITE.g, TEXT_WHITE.b)
  label:SetPoint("CENTER")
  label:SetText(text)

  -- Hover effect
  btn:SetScript("OnEnter", function()
    bg:SetColorTexture(0.25, 0.25, 0.3, 0.9)
    if tooltipText then
      GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, 1, 1, 1)
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function()
    bg:SetColorTexture(0.2, 0.2, 0.25, 0.9)
    GameTooltip:Hide()
  end)

  btn:SetScript("OnClick", onClick)

  return btn, 35
end

-------------------------------------------------------------------------------
-- Slider (styled horizontal slider with number box)
-------------------------------------------------------------------------------
function Widgets:CreateSlider(parent, yOffset, labelText, min, max, step, getValue, setValue, tooltipText)
  -- Smart defaults for min/max/step
  min = min or -5000
  max = max or 5000
  step = step or 1

  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
  row:SetSize(parent:GetWidth() - 20, 50)

  -- Label
  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetFont(FONT, 12, "OUTLINE")
  label:SetTextColor(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b)
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  label:SetText(labelText)

  -- Slider (use OptionsSliderTemplate as base)
  local SLIDER_W = 250
  local sliderName = "SkyInfoTilesSlider" .. tostring(math.random(100000, 999999))
  local slider = CreateFrame("Slider", sliderName, row, "OptionsSliderTemplate")
  slider:SetSize(SLIDER_W, 16)
  slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
  slider:SetMinMaxValues(min, max)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)

  -- Hide default texts
  _G[sliderName .. "Low"]:Hide()
  _G[sliderName .. "High"]:Hide()
  _G[sliderName .. "Text"]:Hide()

  -- COMPLETELY hide the default slider thumb (it's yellow/gold colored from OptionsSliderTemplate)
  local defaultThumb = slider:GetThumbTexture()
  if defaultThumb then
    defaultThumb:SetTexture(nil)
    defaultThumb:SetAlpha(0)
    defaultThumb:SetSize(1, 1)  -- Shrink to 1x1 pixel
    defaultThumb:Hide()
    defaultThumb:SetVertexColor(0, 0, 0, 0)  -- Make it transparent
    -- Move it far off-screen
    defaultThumb:ClearAllPoints()
    defaultThumb:SetPoint("TOPLEFT", slider, "TOPLEFT", -1000, -1000)
  end

  -- Hide any yellow/gold textures from the OptionsSliderTemplate
  for i = 1, slider:GetNumRegions() do
    local region = select(i, slider:GetRegions())
    if region and region:GetObjectType() == "Texture" then
      local r, g, b = region:GetVertexColor()
      -- If it's yellowish/gold colored (like the default thumb), hide it
      if r and g and (r > 0.5 and g > 0.5 and b < 0.3) then
        region:SetAlpha(0)
        region:Hide()
        region:SetTexture(nil)
      end
    end
  end

  -- EXACTLY like Ellesmere: simple textures, NO backdrops
  local trackH = 4

  -- Track background (BACKGROUND layer, like Ellesmere)
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.2, 0.2, 0.22, 0.8)
  track:SetHeight(trackH)
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)

  -- Fill (BORDER layer - above background, like Ellesmere)
  local fill = slider:CreateTexture(nil, "BORDER")
  fill:SetColorTexture(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.8)
  fill:SetHeight(trackH)
  fill:SetPoint("LEFT", track, "LEFT", 0, 0)
  fill:SetWidth(10)  -- Will be updated

  -- Make slider track clickable to jump to position
  slider:EnableMouse(true)
  slider:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      local x = GetCursorPosition() / slider:GetEffectiveScale()
      local left = slider:GetLeft()
      if not left then return end

      local cursorX = x - left
      local ratio = math.max(0, math.min(1, cursorX / SLIDER_W))
      local value = min + ratio * (max - min)
      value = math.floor(value / step + 0.5) * step
      value = math.max(min, math.min(max, value))

      slider:SetValue(value)
      setValue(value)
    end
  end)

  -- Thumb (EXACTLY like Ellesmere - anchored to fill's RIGHT with blocker)
  local THUMB_SIZE = 14
  local thumb = CreateFrame("Button", nil, slider)
  thumb:SetSize(THUMB_SIZE, THUMB_SIZE)
  thumb:SetFrameLevel(slider:GetFrameLevel() + 2)
  thumb:EnableMouse(true)
  thumb:SetPoint("CENTER", fill, "RIGHT", 0, 0)  -- CENTER on fill's RIGHT edge!

  -- Blocker behind thumb to hide fill's rounded end (EXACTLY like Ellesmere)
  local thumbBlockerFrame = CreateFrame("Frame", nil, thumb)
  thumbBlockerFrame:SetAllPoints()
  thumbBlockerFrame:SetFrameLevel(thumb:GetFrameLevel())
  thumbBlockerFrame:SetIgnoreParentAlpha(true)
  local thumbBlocker = thumbBlockerFrame:CreateTexture(nil, "BACKGROUND")
  thumbBlocker:SetAllPoints()
  thumbBlocker:SetColorTexture(0.1, 0.1, 0.12, 1)  -- Match our dark background

  local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
  thumbTex:SetColorTexture(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 1)
  thumbTex:SetAllPoints()

  -- Make custom thumb directly draggable
  thumb:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
  thumb:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      self:SetScript("OnUpdate", function()
        local x = GetCursorPosition() / thumb:GetEffectiveScale()
        local left = track:GetLeft()
        if not left then return end

        local cursorX = x - left
        local ratio = math.max(0, math.min(1, cursorX / SLIDER_W))
        local value = min + ratio * (max - min)
        value = math.floor(value / step + 0.5) * step
        value = math.max(min, math.min(max, value))

        slider:SetValue(value)
        setValue(value)
      end)
    end
  end)

  thumb:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      self:SetScript("OnUpdate", nil)
    end
  end)

  -- Number box (editable)
  local editBox = CreateFrame("EditBox", nil, row)
  editBox:SetSize(60, 24)
  editBox:SetPoint("LEFT", slider, "RIGHT", 10, 0)
  editBox:SetAutoFocus(false)
  editBox:SetFont(FONT, 11, "OUTLINE")
  editBox:SetTextColor(TEXT_WHITE.r, TEXT_WHITE.g, TEXT_WHITE.b)
  editBox:SetJustifyH("CENTER")

  -- EditBox background
  local editBg = CreateSolidTexture(editBox, "BACKGROUND", 0.15, 0.15, 0.18, 0.9)
  editBg:SetAllPoints()

  -- EditBox border
  local editBorder = CreateFrame("Frame", nil, editBox)
  editBorder:SetAllPoints()
  local borderTex = CreateSolidTexture(editBorder, "ARTWORK", BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.6)
  borderTex:SetPoint("TOPLEFT", 0, 0)
  borderTex:SetPoint("TOPRIGHT", 0, 0)
  borderTex:SetHeight(1)

  local borderTex2 = CreateSolidTexture(editBorder, "ARTWORK", BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.6)
  borderTex2:SetPoint("BOTTOMLEFT", 0, 0)
  borderTex2:SetPoint("BOTTOMRIGHT", 0, 0)
  borderTex2:SetHeight(1)

  -- Update fill width based on slider value (EXACTLY like Ellesmere)
  local function UpdateFill()
    local value = slider:GetValue()
    local ratio = math.max(0, math.min(1, (value - min) / (max - min)))
    -- Fill width - thumb follows automatically since it's anchored to fill's RIGHT
    fill:SetWidth(math.max(1, math.floor(SLIDER_W * ratio + 0.5)))
  end

  -- Update from value
  local function UpdateVisual()
    local value = getValue()
    slider:SetValue(value)
    editBox:SetText(string.format("%.1f", value))
    UpdateFill()
  end

  -- Slider OnValueChanged
  slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value / step + 0.5) * step  -- Snap to step
    editBox:SetText(string.format("%.1f", value))
    setValue(value)
    UpdateFill()
  end)

  -- Force update fill on mouse release to ensure correctness
  slider:SetScript("OnMouseUp", function(self)
    C_Timer.After(0.01, UpdateFill)
  end)

  -- EditBox OnEnterPressed
  editBox:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
      value = math.max(min, math.min(max, value))
      value = math.floor(value / step + 0.5) * step
      slider:SetValue(value)
      setValue(value)
    end
    self:ClearFocus()
  end)

  editBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    UpdateVisual()
  end)

  -- Tooltip
  if tooltipText then
    slider:SetScript("OnEnter", function()
      GameTooltip:SetOwner(slider, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, 1, 1, 1)
      GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end

  -- Initial update
  UpdateVisual()
  -- Ensure defaultThumb is positioned correctly from the start
  C_Timer.After(0, UpdateFill)

  slider.Refresh = UpdateVisual
  row.slider = slider  -- Store slider reference for refresh

  return row, 55, slider
end

-------------------------------------------------------------------------------
-- Dropdown (styled dropdown menu)
-------------------------------------------------------------------------------
function Widgets:CreateDropdown(parent, yOffset, labelText, values, order, getValue, setValue, tooltipText)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
  row:SetSize(parent:GetWidth() - 20, 30)

  -- Label
  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetFont(FONT, 12, "OUTLINE")
  label:SetTextColor(TEXT_WHITE.r, TEXT_WHITE.g, TEXT_WHITE.b)
  label:SetPoint("LEFT", row, "LEFT", 0, 0)
  label:SetText(labelText)

  -- Dropdown button (fixed width like Ellesmere)
  local BUTTON_W, BUTTON_H = 200, 30
  local dropdown = CreateFrame("Button", nil, row)
  dropdown:SetSize(BUTTON_W, BUTTON_H)
  dropdown:SetPoint("RIGHT", row, "RIGHT", 0, 0)

  -- Background
  local bg = CreateSolidTexture(dropdown, "BACKGROUND", 0.15, 0.15, 0.18, 0.9)
  bg:SetAllPoints()

  -- Border
  local border = CreateSolidTexture(dropdown, "ARTWORK", BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.6)
  border:SetPoint("TOPLEFT", 0, 0)
  border:SetPoint("TOPRIGHT", 0, 0)
  border:SetHeight(1)

  local border2 = CreateSolidTexture(dropdown, "ARTWORK", BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.6)
  border2:SetPoint("BOTTOMLEFT", 0, 0)
  border2:SetPoint("BOTTOMRIGHT", 0, 0)
  border2:SetHeight(1)

  -- Arrow (using Blizzard's built-in ChatFrameExpandArrow)
  local arrow = dropdown:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetSize(16, 16)
  arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
  arrow:SetVertexColor(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b)

  -- Helper function to flip arrow direction
  arrow.SetDirection = function(self, direction)
    if direction == "up" then
      -- Rotate 90° counterclockwise (pointing up)
      self:SetRotation(math.rad(-90))
    else
      -- Rotate 90° clockwise (pointing down)
      self:SetRotation(math.rad(90))
    end
  end

  -- Set initial direction to down
  arrow:SetDirection("down")

  -- Selected text
  local selectedText = dropdown:CreateFontString(nil, "OVERLAY")
  selectedText:SetFont(FONT, 11, "OUTLINE")
  selectedText:SetTextColor(TEXT_WHITE.r, TEXT_WHITE.g, TEXT_WHITE.b)
  selectedText:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
  selectedText:SetPoint("RIGHT", arrow, "LEFT", -4, 0)
  selectedText:SetJustifyH("LEFT")
  selectedText:SetWordWrap(false)

  -- Menu frame
  local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetFrameLevel(dropdown:GetFrameLevel() + 10)
  menu:Hide()

  menu:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
  })
  menu:SetBackdropColor(0.15, 0.15, 0.18, 0.98)
  menu:SetBackdropBorderColor(BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.8)

  -- Menu scroll frame
  local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 2, -2)
  scrollFrame:SetPoint("BOTTOMRIGHT", -2, 2)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollFrame:SetScrollChild(scrollChild)

  local menuItems = {}

  local function CloseMenu()
    menu:Hide()
    arrow:SetDirection("down")
  end

  local function OpenMenu()
    -- Position menu below button
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(BUTTON_W)

    -- Calculate menu height (max 200px)
    local itemHeight = 25
    local maxHeight = 200
    local totalHeight = #order * itemHeight
    local menuHeight = math.min(totalHeight, maxHeight)
    menu:SetHeight(menuHeight)
    scrollChild:SetSize(BUTTON_W - 4, totalHeight)

    -- Clear old items
    for _, item in ipairs(menuItems) do
      item:Hide()
      item:SetParent(nil)
    end
    menuItems = {}

    -- Create menu items
    local currentValue = getValue()
    for i, key in ipairs(order) do
      local item = CreateFrame("Button", nil, scrollChild)
      item:SetSize(BUTTON_W - 4, itemHeight)
      item:SetPoint("TOPLEFT", 0, -(i - 1) * itemHeight)

      -- Background
      local itemBg = CreateSolidTexture(item, "BACKGROUND", 0.15, 0.15, 0.18, 0)
      itemBg:SetAllPoints()
      item.bg = itemBg

      -- Text
      local itemText = item:CreateFontString(nil, "OVERLAY")
      itemText:SetFont(FONT, 11, "OUTLINE")
      itemText:SetTextColor(TEXT_WHITE.r, TEXT_WHITE.g, TEXT_WHITE.b)
      itemText:SetPoint("LEFT", item, "LEFT", 8, 0)
      itemText:SetText(values[key] or key)

      -- Highlight selected item
      if currentValue == key then
        itemText:SetTextColor(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b)
      end

      -- Hover effect
      item:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(ACCENT_COLOR.r, ACCENT_COLOR.g, ACCENT_COLOR.b, 0.3)
      end)
      item:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.18, 0)
      end)

      -- Click handler
      item:SetScript("OnClick", function()
        setValue(key)
        selectedText:SetText(values[key] or key)
        CloseMenu()
      end)

      table.insert(menuItems, item)
    end

    menu:Show()
    arrow:SetDirection("up")
  end

  -- Toggle menu on click
  dropdown:SetScript("OnClick", function()
    if menu:IsShown() then
      CloseMenu()
    else
      OpenMenu()
    end
  end)

  menu:EnableMouse(true)
  menu:SetScript("OnMouseDown", function(self, button)
    -- Prevent clicks on menu from closing it
  end)

  -- Close menu when clicking outside (Ellesmere pattern)
  menu:SetScript("OnShow", function(self)
    arrow:SetDirection("up")
    self:SetScript("OnUpdate", function(m)
      if not m:IsMouseOver() and not dropdown:IsMouseOver() and IsMouseButtonDown("LeftButton") then
        CloseMenu()
      end
    end)
  end)

  menu:SetScript("OnHide", function(self)
    arrow:SetDirection("down")
    self:SetScript("OnUpdate", nil)
  end)

  -- Hover effect on button
  dropdown:SetScript("OnEnter", function()
    bg:SetColorTexture(0.18, 0.18, 0.21, 0.9)
    if tooltipText then
      GameTooltip:SetOwner(dropdown, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, 1, 1, 1)
      GameTooltip:Show()
    end
  end)
  dropdown:SetScript("OnLeave", function()
    bg:SetColorTexture(0.15, 0.15, 0.18, 0.9)
    GameTooltip:Hide()
  end)

  -- Update visual
  local function UpdateVisual()
    local value = getValue()
    selectedText:SetText(values[value] or value or "")
  end

  -- Initial update
  UpdateVisual()

  -- Store refresh function
  dropdown.Refresh = UpdateVisual

  return row, 35, dropdown
end
