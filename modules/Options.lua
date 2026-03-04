-- SkyInfoTiles - Options UI (Interface -> AddOns -> SkyInfoTiles)
-- Minimal, lightweight panel: lock toggle + enable/disable catalog tiles + reset/clean.
-- This file was re-created because it had become an empty (0-byte) placeholder.

local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
if not SkyInfoTiles then return end

local function GetPanelAPI()
  -- Retail 10.0+ uses the new Settings API. Older uses InterfaceOptions.
  local hasNew = _G.Settings and _G.Settings.RegisterCanvasLayoutCategory and _G.Settings.RegisterAddOnCategory
  return hasNew and "settings" or "interfaceoptions"
end

local function CreateTitle(panel, text)
  local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText(text)
  return t
end

local function CreateCheck(panel, label, tooltip)
  local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  cb.Text:SetText(label)
  if tooltip then
    cb.tooltipText = label
    cb.tooltipRequirement = tooltip
  end
  return cb
end

local function CreateButton(panel, text, width, height)
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetText(text)
  b:SetSize(width or 120, height or 22)
  return b
end

-- Build a scrollable list (keeps panel compact as tiles grow over time)
local function CreateScrollArea(panel, topAnchor, height)
  height = height or 260

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -36, 0)
  scrollFrame:SetHeight(height)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(1, 1) -- will be resized as children are added
  scrollFrame:SetScrollChild(content)

  return scrollFrame, content
end

-- ============================================================
-- Panel construction
-- ============================================================
local panel = CreateFrame("Frame", nil, UIParent)
panel.name = "SkyInfoTiles"

local settingsCategory = nil

local title = CreateTitle(panel, "SkyInfoTiles")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
subtitle:SetText("Toggle tiles, lock dragging, and manage profiles via /skytiles profile ...")

-- Lock toggle
local lockCB = CreateCheck(panel, "Lock tiles (disable dragging)")
lockCB:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -10)

-- Buttons
local btnRow = CreateFrame("Frame", nil, panel)
btnRow:SetPoint("TOPLEFT", lockCB, "BOTTOMLEFT", 0, -8)
btnRow:SetSize(500, 26)

local resetBtn = CreateButton(btnRow, "Reset layout")
resetBtn:SetPoint("LEFT", btnRow, "LEFT", 0, 0)
resetBtn:SetScript("OnClick", function()
  -- Use slash command implementation (keeps behavior in one place)
  if SlashCmdList and SlashCmdList["SKYINFOTILES"] then
    SlashCmdList["SKYINFOTILES"]("reset")
  elseif SkyInfoTiles.Rebuild then
    -- fallback: nuke active tiles and seed catalog
    SkyInfoTilesDB = SkyInfoTilesDB or {}
    SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or { Default = { tiles = {} } }
    local prof = SkyInfoTilesDB.profiles[SkyInfoTilesDB.profile or "Default"]
    if prof and type(prof.tiles) == "table" then
      for i = #prof.tiles, 1, -1 do table.remove(prof.tiles, i) end
    end
    for _, cat in ipairs(SkyInfoTiles.CATALOG or {}) do
      table.insert(prof.tiles, {
        key = cat.key, type = cat.type, label = cat.label,
        enabled = (cat.defaultEnabled ~= false),
        point = "CENTER", x = 0, y = 0,
      })
    end
    SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll()
  end
end)

local cleanBtn = CreateButton(btnRow, "Clean duplicates")
cleanBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
cleanBtn:SetScript("OnClick", function()
  if SlashCmdList and SlashCmdList["SKYINFOTILES"] then
    SlashCmdList["SKYINFOTILES"]("clean")
  end
end)

-- Tile toggles area
local listHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
listHeader:SetPoint("TOPLEFT", btnRow, "BOTTOMLEFT", 0, -10)
listHeader:SetText("Tiles")

local scrollFrame, content = CreateScrollArea(panel, listHeader, 220)

local tileChecks = {}

-- DungeonPorts settings (kept minimal; more can be added later)
local dpHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
dpHeader:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -12)
dpHeader:SetText("Dungeon Teleports")

local dpHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
dpHint:SetPoint("TOPLEFT", dpHeader, "BOTTOMLEFT", 0, -4)
dpHint:SetText("Layout and scale apply to the 'Dungeon Teleports' tile.")

local dpH = CreateCheck(panel, "Horizontal")
dpH:SetPoint("TOPLEFT", dpHint, "BOTTOMLEFT", -2, -6)
local dpV = CreateCheck(panel, "Vertical")
dpV:SetPoint("LEFT", dpH, "RIGHT", 140, 0)

local dpScale = CreateFrame("Slider", "SkyInfoTiles_DungeonPortsScale", panel, "OptionsSliderTemplate")
dpScale:SetPoint("TOPLEFT", dpH, "BOTTOMLEFT", 6, -16)
dpScale:SetWidth(260)
dpScale:SetHeight(16)
dpScale:SetMinMaxValues(0.5, 2.0)
dpScale:SetValueStep(0.05)
if dpScale.SetObeyStepOnDrag then dpScale:SetObeyStepOnDrag(true) end
dpScale:SetValue(1.0)

do
  local low  = _G[dpScale:GetName() .. "Low"]
  local high = _G[dpScale:GetName() .. "High"]
  local text = _G[dpScale:GetName() .. "Text"]
  if low  then low:SetText("0.5") end
  if high then high:SetText("2.0") end
  if text then text:SetText("Scale") end
end

local dpScaleValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
dpScaleValue:SetPoint("LEFT", dpScale, "RIGHT", 10, 0)
dpScaleValue:SetText("1.00")

local _suppressDungeonPortsApply = false

local function GetDungeonPortsCfg()
  if SkyInfoTiles.GetOrCreateTileCfg then
    return SkyInfoTiles.GetOrCreateTileCfg("dungeonports")
  end
  return nil
end

local function ApplyDungeonPortsCfg(cfg)
  if not cfg then return end
  if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
    SkyInfoTiles.Rebuild()
    SkyInfoTiles.UpdateAll()
  end
  if SkyInfoTiles._OptionsRefresh then
    SkyInfoTiles._OptionsRefresh()
  end
end

dpH:SetScript("OnClick", function(self)
  dpV:SetChecked(false)
  dpH:SetChecked(true)
  local cfg = GetDungeonPortsCfg()
  if not cfg then return end
  cfg.orientation = "horizontal"
  ApplyDungeonPortsCfg(cfg)
end)

dpV:SetScript("OnClick", function(self)
  dpH:SetChecked(false)
  dpV:SetChecked(true)
  local cfg = GetDungeonPortsCfg()
  if not cfg then return end
  cfg.orientation = "vertical"
  ApplyDungeonPortsCfg(cfg)
end)

dpScale:SetScript("OnValueChanged", function(self, value)
  if _suppressDungeonPortsApply then return end
  value = tonumber(value) or 1.0
  value = math.floor(value * 100 + 0.5) / 100
  dpScaleValue:SetText(string.format("%.2f", value))
  local cfg = GetDungeonPortsCfg()
  if not cfg then return end
  cfg.scale = value
  ApplyDungeonPortsCfg(cfg)
end)

local function BuildTileList()
  -- Clear existing checkboxes
  for _, cb in ipairs(tileChecks) do
    if cb and cb.Hide then cb:Hide() end
    if cb and cb.SetParent then cb:SetParent(nil) end
  end
  wipe(tileChecks)

  local cats = SkyInfoTiles.CATALOG or {}
  local y = -2
  local maxW = 1
  for i, cat in ipairs(cats) do
    local cb = CreateCheck(content, cat.label or cat.key)
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - 26
    cb._key = cat.key
    cb:SetScript("OnClick", function(self)
      local key = self._key
      if not key then return end
      local enabled = self:GetChecked() and true or false
      if SkyInfoTiles.SetTileEnabledByKey then
        SkyInfoTiles.SetTileEnabledByKey(key, enabled)
      end
    end)
    tileChecks[#tileChecks + 1] = cb
    -- crude width estimate (fontstring isn't created yet); enforce a minimum so scroll area is usable
    maxW = math.max(maxW, 360)
  end
  -- Resize scroll child so scrollbar behaves
  content:SetSize(maxW, math.max(1, -y + 10))
end

local function Refresh()
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  lockCB:SetChecked(SkyInfoTilesDB.locked and true or false)
  for _, cb in ipairs(tileChecks) do
    local key = cb._key
    if key and SkyInfoTiles.GetTileEnabledByKey then
      cb:SetChecked(SkyInfoTiles.GetTileEnabledByKey(key))
    end
  end

  -- DungeonPorts settings
  local cfg = GetDungeonPortsCfg() or {}
  local orient = (cfg.orientation == "vertical") and "vertical" or "horizontal"
  dpH:SetChecked(orient == "horizontal")
  dpV:SetChecked(orient == "vertical")
  local sc = tonumber(cfg.scale) or 1.0
  if sc < 0.5 then sc = 0.5 elseif sc > 2.0 then sc = 2.0 end
  _suppressDungeonPortsApply = true
  dpScale:SetValue(sc)
  _suppressDungeonPortsApply = false
  dpScaleValue:SetText(string.format("%.2f", sc))
end

lockCB:SetScript("OnClick", function(self)
  if SkyInfoTiles.SetLocked then
    SkyInfoTiles.SetLocked(self:GetChecked() and true or false)
  end
end)

panel:SetScript("OnShow", function()
  if #tileChecks == 0 then BuildTileList() end
  Refresh()
end)

-- Expose refresh hook used by core when values change programmatically
SkyInfoTiles._OptionsRefresh = function()
  if panel and panel:IsShown() then
    Refresh()
  end
end

-- Provide a helper used by /skytiles options
function SkyInfoTiles.OpenOptions()
  local api = GetPanelAPI()
  if api == "settings" and _G.Settings and _G.Settings.OpenToCategory then
    -- New Settings API: prefer opening by category ID/object if available.
    if settingsCategory then
      local id = nil
      if type(settingsCategory.GetID) == "function" then
        id = settingsCategory:GetID()
      elseif settingsCategory.ID then
        id = settingsCategory.ID
      end
      if id then
        _G.Settings.OpenToCategory(id)
      else
        -- Some builds accept the category object directly
        pcall(_G.Settings.OpenToCategory, settingsCategory)
      end
    else
      _G.Settings.OpenToCategory(panel.name)
    end
  elseif _G.InterfaceOptionsFrame_OpenToCategory then
    _G.InterfaceOptionsFrame_OpenToCategory(panel)
    _G.InterfaceOptionsFrame_OpenToCategory(panel) -- called twice to work around Blizzard bug
  end
end

-- Register with game options UI
do
  local api = GetPanelAPI()
  if api == "settings" and _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
    settingsCategory = _G.Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    _G.Settings.RegisterAddOnCategory(settingsCategory)
  elseif _G.InterfaceOptions_AddCategory then
    _G.InterfaceOptions_AddCategory(panel)
  end
end







