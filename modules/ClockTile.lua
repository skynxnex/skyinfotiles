local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Defaults for Clock tile
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
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
    local upperExt = file:gsub("%.ttf$", ".TTF")
    if upperExt ~= file then table.insert(tries, upperExt) end
  end
  table.insert(tries, DEFAULT_FONT)
  if STANDARD_TEXT_FONT then table.insert(tries, STANDARD_TEXT_FONT) end
  -- Known built-in fonts
  table.insert(tries, "Fonts\\FRIZQT__.TTF")
  table.insert(tries, "Fonts\\ARIALN.TTF")
  table.insert(tries, "Fonts\\MORPHEUS.ttf")
  table.insert(tries, "Fonts\\SKURRI.ttf")
  for _, path in ipairs(tries) do
    if fs:SetFont(path, size or DEFAULT_SIZE, flags or "") then
      return true, path
    end
  end
  return false, nil
end

local function ApplyTextStyle(fs, fontFile, size, outline, color)
  if not fs then return end
  SetFontSmart(fs, fontFile or DEFAULT_FONT, size or DEFAULT_SIZE, outline or "")
  if UI and UI.Outline then
    -- Re-apply outline weight to ensure shadow/outline behavior is consistent with addon
    UI.Outline(fs, { weight = outline, size = size })
  end
  if fs.SetTextColor and color then
    fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1, (color.a ~= nil) and color.a or 1)
  end
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
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
  f._ticker = C_Timer.NewTicker(1, RefreshText)
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
  end

  return f
end

function API.update(frame, cfg)
  if not frame or not frame.text then return end
  local fontFile, size, outline, color = ReadCfg(cfg)
  ApplyTextStyle(frame.text, fontFile, size, outline, color)
  frame.text:SetText(GetTimeText())
  -- Resize after size change
  frame:SetSize(math.max(32, size * 3), math.max(16, size + 8))
end

SkyInfoTiles.RegisterTileType("clock", API)
