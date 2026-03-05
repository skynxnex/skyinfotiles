local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Defaults for Clock tile
local DEFAULT_FONT = "Fonts\\FRIZQT__.ttf"
local DEFAULT_SIZE = 24
local DEFAULT_OUTLINE = "OUTLINE"   -- "", "OUTLINE", "THICKOUTLINE"
local DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }

local function Clamp(v, lo, hi)
  if not v then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function ReadCfg(cfg)
  cfg = cfg or {}
  local fontFile = (type(cfg.font) == "string" and cfg.font ~= "" and cfg.font) or DEFAULT_FONT
  local size = Clamp(tonumber(cfg.size) or tonumber(cfg.fontSize) or DEFAULT_SIZE, 6, 128)
  local outline = cfg.outline
  if outline == nil then outline = DEFAULT_OUTLINE end
  if outline == "NONE" then outline = "" end
  local color = cfg.color or DEFAULT_COLOR
  return fontFile, size, outline, color
end

local function SetFontSmart(fs, file, size, flags)
  local tries = {}
  if type(file) == "string" and file ~= "" then
    table.insert(tries, file)
    -- Try case variations (WoW fonts are inconsistent with case)
    local lowerExt = file:gsub("%.TTF$", ".ttf"):gsub("%.Ttf$", ".ttf")
    if lowerExt ~= file then table.insert(tries, lowerExt) end
    local upperExt = file:gsub("%.ttf$", ".TTF")
    if upperExt ~= file then table.insert(tries, upperExt) end
  end
  table.insert(tries, DEFAULT_FONT)
  if STANDARD_TEXT_FONT then table.insert(tries, STANDARD_TEXT_FONT) end
  -- Known built-in fonts (actual filenames from Fonts directory)
  table.insert(tries, "Fonts\\FRIZQT__.ttf")
  table.insert(tries, "Fonts\\ARIALN.ttf")
  table.insert(tries, "Fonts\\MORPHEUS.ttf")
  table.insert(tries, "Fonts\\skurri.ttf")  -- lowercase!
  table.insert(tries, "Fonts\\theboldfont.ttf")
  for _, path in ipairs(tries) do
    if fs:SetFont(path, size or DEFAULT_SIZE, flags or "") then
      return true, path
    end
  end
  return false, nil
end

local function ApplyTextStyle(fs, fontFile, size, outline, color)
  if not fs then return end

  -- SetFontSmart handles font fallback and sets the font+size+outline
  local success, usedFont = SetFontSmart(fs, fontFile or DEFAULT_FONT, size or DEFAULT_SIZE, outline or "")

  -- Apply color
  if fs.SetTextColor and color then
    fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1, (color.a ~= nil) and color.a or 1)
  end

  -- Apply shadow (consistent with UI.Outline behavior)
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)

  -- Note: We don't call UI.Outline here because it would overwrite the font we just set
  -- SetFontSmart already handles the outline parameter correctly
end

local function GetTimeText()
  -- 24-hour HH:MM
  -- Using Lua date() API (local time).
  return date("%H:%M")
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)

  -- Text
  f.text = f:CreateFontString(nil, "OVERLAY")
  f.text:SetPoint("CENTER")
  f.text:SetJustifyH("CENTER")
  f.text:SetJustifyV("MIDDLE")

  -- Style + initial sizing
  local fontFile, size, outline, color = ReadCfg(cfg)
  ApplyTextStyle(f.text, fontFile, size, outline, color)

  -- Frame size based on text height + some padding
  local function ResizeToText()
    local w = math.max(32, size * 3)  -- rough width for "HH:MM"
    local h = math.max(16, size + 8)
    f:SetSize(w, h)
  end
  ResizeToText()

  -- Update function
  local function RefreshText()
    if not f.text then return end
    f.text:SetText(GetTimeText())
  end

  -- Ticker (every second to keep minutes smooth)
  if C_Timer and C_Timer.NewTicker then
    f._ticker = C_Timer.NewTicker(1, RefreshText)
  else
    -- Fallback: OnUpdate-based ticker
    f:SetScript("OnUpdate", function(self, elapsed)
      self._elapsed = (self._elapsed or 0) + elapsed
      if self._elapsed >= 1 then
        self._elapsed = 0
        RefreshText()
      end
    end)
  end
  RefreshText()

  -- Drag behavior is managed by core via SetMovable wrapper

  -- Events: repaint when shown
  f:SetScript("OnShow", function() RefreshText() end)

  -- Ensure layers sit under major UI
  f:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")

  function f:Destroy()
    if f._ticker and f._ticker.Cancel then
      f._ticker:Cancel()
      f._ticker = nil
    end
    if self.SetScript then
      self:SetScript("OnUpdate", nil)
      self:SetScript("OnShow", nil)
    end
  end

  return f
end

function API.update(frame, cfg)
  if not frame then return end

  local fontFile, size, outline, color = ReadCfg(cfg)

  -- DRASTIC FIX: Recreate fontstring to force font change
  -- This is necessary because SetFont() doesn't always trigger visual update
  if frame.text then
    -- Store old fontstring
    local oldText = frame.text
    -- Create new fontstring
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
    -- Hide and remove old one
    oldText:Hide()
    oldText:SetParent(nil)
    oldText = nil
  else
    -- First time - create fontstring
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
  end

  -- Apply style to NEW fontstring
  ApplyTextStyle(frame.text, fontFile, size, outline, color)

  -- Set text
  frame.text:SetText(GetTimeText())

  -- Resize after size change
  frame:SetSize(math.max(32, size * 3), math.max(16, size + 8))
end

SkyInfoTiles.RegisterTileType("clock", API)
