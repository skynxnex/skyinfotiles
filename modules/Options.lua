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
  -- Try modern template first, fallback to legacy, then manual creation
  local cb = nil
  local templates = {
    "InterfaceOptionsCheckButtonTemplate",
    "OptionsCheckButtonTemplate",
    "UICheckButtonTemplate"
  }

  for _, template in ipairs(templates) do
    local ok, result = pcall(CreateFrame, "CheckButton", nil, panel, template)
    if ok and result then
      cb = result
      break
    end
  end

  -- Manual creation if all templates fail
  if not cb then
    cb = CreateFrame("CheckButton", nil, panel)
    cb:SetSize(26, 26)

    -- Create check texture
    local check = cb:CreateTexture(nil, "ARTWORK")
    check:SetSize(24, 24)
    check:SetPoint("CENTER")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb.CheckedTexture = check
    cb:SetCheckedTexture(check)

    -- Create background
    local bg = cb:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(26, 26)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetNormalTexture(bg)

    -- Create pushed texture
    local pushed = cb:CreateTexture(nil, "ARTWORK")
    pushed:SetSize(26, 26)
    pushed:SetPoint("CENTER")
    pushed:SetTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetPushedTexture(pushed)

    -- Create highlight
    local hl = cb:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(26, 26)
    hl:SetPoint("CENTER")
    hl:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    hl:SetBlendMode("ADD")
    cb:SetHighlightTexture(hl)
  end

  -- Create or find Text label
  if not cb.Text then
    cb.Text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  end

  cb.Text:SetText(label or "")

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
  scrollFrame:Show()  -- Ensure visible

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(400, height)  -- Start with reasonable size, will be resized as children are added
  content:Show()  -- Ensure visible
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

-- Main scrollable area for all settings
local mainHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
mainHeader:SetPoint("TOPLEFT", btnRow, "BOTTOMLEFT", 0, -10)
mainHeader:SetText("Settings")

local scrollFrame, content = CreateScrollArea(panel, mainHeader, 450)

local tileChecks = {}

-- Tiles section header (inside scroll area)
local listHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
listHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -5)
listHeader:SetText("Tile Toggles")

local listDivider = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
listDivider:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -2)
listDivider:SetText("Enable or disable individual tiles")

-- Tile checkboxes will be added dynamically below listDivider

-- DungeonPorts settings (inside scroll area)
local dpHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
dpHeader:SetText("Dungeon Teleports")

local dpHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
dpHint:SetPoint("TOPLEFT", dpHeader, "BOTTOMLEFT", 0, -4)
dpHint:SetText("Layout and scale apply to the 'Dungeon Teleports' tile.")

local dpH = CreateCheck(content, "Horizontal")
dpH:SetPoint("TOPLEFT", dpHint, "BOTTOMLEFT", -2, -6)
local dpV = CreateCheck(content, "Vertical")
dpV:SetPoint("LEFT", dpH, "RIGHT", 140, 0)

local dpScale = CreateFrame("Slider", "SkyInfoTiles_DungeonPortsScale", content, "OptionsSliderTemplate")
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

local dpScaleValue = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
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

-- ============================================================
-- ClockTile Settings (inside scroll area)
-- ============================================================
local clockHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
clockHeader:SetText("24h Clock")

local clockHint = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
clockHint:SetPoint("TOPLEFT", clockHeader, "BOTTOMLEFT", 0, -4)
clockHint:SetText("Font, size, and outline apply to the '24h Clock' tile.")

local clockTip = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
clockTip:SetPoint("TOPLEFT", clockHint, "BOTTOMLEFT", 0, -2)
clockTip:SetText("|cffff9900Tip:|r Set Outline to 'None' to see font differences clearly!")
clockTip:SetTextColor(1, 0.8, 0, 1)

-- Font dropdown
local clockFontLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
clockFontLabel:SetPoint("TOPLEFT", clockTip, "BOTTOMLEFT", 0, -8)
clockFontLabel:SetText("Font:")

-- Dynamic font discovery
local FONT_LIST = nil  -- Will be populated dynamically

local function DiscoverFonts()
  local fonts = {}
  local seen = {}  -- Track duplicates by lowercase filename

  -- Helper to add font if valid
  local function TryAddFont(path, displayName)
    if not path or path == "" then return end

    -- Extract filename for duplicate check
    local filename = path:match("\\([^\\]+)$") or path
    local filenameLower = filename:lower()

    -- Skip duplicates
    if seen[filenameLower] then return end

    -- Test if font loads
    local testFrame = CreateFrame("Frame", nil, UIParent)
    local testFont = testFrame:CreateFontString(nil, "OVERLAY")
    local success = pcall(testFont.SetFont, testFont, path, 12, "")

    if success then
      seen[filenameLower] = true
      table.insert(fonts, { name = displayName or filename, path = path })
    end

    -- Cleanup
    testFont:SetParent(nil)
    testFrame:Hide()
    testFrame:SetParent(nil)
  end

  -- 1. WoW Built-in Fonts
  TryAddFont("Fonts\\FRIZQT__.ttf", "Friz Quadrata (Default)")
  TryAddFont("Fonts\\ARIALN.ttf", "Arial")
  TryAddFont("Fonts\\skurri.ttf", "Skurri (Runic)")
  TryAddFont("Fonts\\MORPHEUS.ttf", "Morpheus (Decorative)")
  TryAddFont("Fonts\\theboldfont.ttf", "Bold Font")
  TryAddFont("Fonts\\FRIZQT___CYR.ttf", "Cyrillic")

  -- 2. Scan common addon font locations
  local addonPaths = {
    "Interface\\AddOns\\SharedMedia\\fonts\\",
    "Interface\\AddOns\\SharedMedia_ClassicalFonts\\Fonts\\",
    "Interface\\AddOns\\SharedMedia_MyMedia\\font\\",
    "Interface\\AddOns\\Cell\\Media\\Fonts\\",
    "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Fonts\\",
    "Interface\\AddOns\\WarpDeplete\\Media\\Fonts\\",
    "Interface\\AddOns\\ElvUI_WindTools\\Media\\Fonts\\",
    "Interface\\AddOns\\AstralKeys\\Media\\Font\\",
    "Interface\\AddOns\\Prat-3.0\\fonts\\",
    "Interface\\AddOns\\MRT\\media\\",
  }

  -- Known good fonts from addons (manually curated for best variety)
  local knownFonts = {
    { path = "Interface\\AddOns\\SharedMedia_ClassicalFonts\\Fonts\\King Arthur Legend.ttf", name = "King Arthur (Medieval)" },
    { path = "Interface\\AddOns\\SharedMedia_ClassicalFonts\\Fonts\\OldeEnglish.ttf", name = "Olde English" },
    { path = "Interface\\AddOns\\SharedMedia\\fonts\\adventure\\Adventure.ttf", name = "Adventure" },
    { path = "Interface\\AddOns\\SharedMedia\\fonts\\black_chancery\\BlackChancery.ttf", name = "Black Chancery" },
    { path = "Interface\\AddOns\\WarpDeplete\\Media\\Fonts\\Expressway.ttf", name = "Expressway" },
    { path = "Interface\\AddOns\\ElvUI_WindTools\\Media\\Fonts\\Roadway.ttf", name = "Roadway" },
    { path = "Interface\\AddOns\\Cell\\Media\\Fonts\\visitor.ttf", name = "Visitor (Retro)" },
    { path = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Fonts\\Jedi.ttf", name = "Jedi" },
    { path = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Fonts\\Walt.ttf", name = "Walt Disney" },
    { path = "Interface\\AddOns\\SharedMedia\\fonts\\sf_movie_poster\\SFMoviePoster-Bold.ttf", name = "Movie Poster" },
    { path = "Interface\\AddOns\\AstralKeys\\Media\\Font\\Inter-UI-Bold.ttf", name = "Inter UI Bold" },
    { path = "Interface\\AddOns\\Prat-3.0\\fonts\\DejaVuSansMono.ttf", name = "DejaVu Sans Mono" },
    { path = "Interface\\AddOns\\MRT\\media\\FiraSansMedium.ttf", name = "Fira Sans" },
  }

  for _, font in ipairs(knownFonts) do
    TryAddFont(font.path, font.name)
  end

  -- Sort by name for better UX
  table.sort(fonts, function(a, b) return a.name < b.name end)

  -- Always ensure default font is first
  for i = #fonts, 1, -1 do
    if fonts[i].name:find("Default") then
      local default = table.remove(fonts, i)
      table.insert(fonts, 1, default)
      break
    end
  end

  return fonts
end

local clockFontDropdown = CreateFrame("Frame", "SkyInfoTiles_ClockFontDropdown", content, "UIDropDownMenuTemplate")
clockFontDropdown:SetPoint("LEFT", clockFontLabel, "RIGHT", -10, -2)
UIDropDownMenu_SetWidth(clockFontDropdown, 180)

local function GetClockCfg()
  if SkyInfoTiles.GetOrCreateTileCfg then
    return SkyInfoTiles.GetOrCreateTileCfg("clock")
  end
  return nil
end

local function ApplyClockCfg(cfg)
  if not cfg then return end
  if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
    SkyInfoTiles.Rebuild()
    SkyInfoTiles.UpdateAll()
  end
  if SkyInfoTiles._OptionsRefresh then
    SkyInfoTiles._OptionsRefresh()
  end
end

UIDropDownMenu_Initialize(clockFontDropdown, function(self, level)
  -- Discover fonts on first open
  if not FONT_LIST then
    FONT_LIST = DiscoverFonts()
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00SkyInfoTiles:|r Discovered %d fonts!", #FONT_LIST))
    end
  end

  local cfg = GetClockCfg()
  local currentFont = cfg and cfg.font or "Fonts\\FRIZQT__.ttf"

  for i, font in ipairs(FONT_LIST) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = font.name
    info.value = font.path
    info.checked = (currentFont == font.path)
    info.func = function()
      local cfg = GetClockCfg()
      if cfg then
        cfg.font = font.path
        UIDropDownMenu_SetText(clockFontDropdown, font.name)
        ApplyClockCfg(cfg)
      end
    end
    UIDropDownMenu_AddButton(info)
  end
end)

-- Size slider
local clockSize = CreateFrame("Slider", "SkyInfoTiles_ClockSize", content, "OptionsSliderTemplate")
clockSize:SetPoint("TOPLEFT", clockFontLabel, "BOTTOMLEFT", 6, -36)
clockSize:SetWidth(260)
clockSize:SetHeight(16)
clockSize:SetMinMaxValues(6, 128)
clockSize:SetValueStep(1)
if clockSize.SetObeyStepOnDrag then clockSize:SetObeyStepOnDrag(true) end
clockSize:SetValue(24)

do
  local low  = _G[clockSize:GetName() .. "Low"]
  local high = _G[clockSize:GetName() .. "High"]
  local text = _G[clockSize:GetName() .. "Text"]
  if low  then low:SetText("6") end
  if high then high:SetText("128") end
  if text then text:SetText("Size") end
end

local clockSizeValue = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
clockSizeValue:SetPoint("LEFT", clockSize, "RIGHT", 10, 0)
clockSizeValue:SetText("24")

local _suppressClockApply = false

clockSize:SetScript("OnValueChanged", function(self, value)
  if _suppressClockApply then return end
  value = math.floor(tonumber(value) or 24)
  clockSizeValue:SetText(tostring(value))
  local cfg = GetClockCfg()
  if not cfg then return end
  cfg.size = value
  ApplyClockCfg(cfg)
end)

-- Outline dropdown
local clockOutlineLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
clockOutlineLabel:SetPoint("TOPLEFT", clockSize, "BOTTOMLEFT", -6, -24)
clockOutlineLabel:SetText("Outline:")

local clockOutlineDropdown = CreateFrame("Frame", "SkyInfoTiles_ClockOutlineDropdown", content, "UIDropDownMenuTemplate")
clockOutlineDropdown:SetPoint("LEFT", clockOutlineLabel, "RIGHT", -10, -2)
UIDropDownMenu_SetWidth(clockOutlineDropdown, 180)

local OUTLINE_LIST = {
  { name = "None", value = "" },
  { name = "Outline", value = "OUTLINE" },
  { name = "Thick Outline", value = "THICKOUTLINE" },
}

UIDropDownMenu_Initialize(clockOutlineDropdown, function(self, level)
  local cfg = GetClockCfg()
  local currentOutline = cfg and cfg.outline or "OUTLINE"
  if currentOutline == "NONE" then currentOutline = "" end

  for i, outline in ipairs(OUTLINE_LIST) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = outline.name
    info.value = outline.value
    info.checked = (currentOutline == outline.value)
    info.func = function()
      local cfg = GetClockCfg()
      if cfg then
        cfg.outline = outline.value
        UIDropDownMenu_SetText(clockOutlineDropdown, outline.name)
        ApplyClockCfg(cfg)
      end
    end
    UIDropDownMenu_AddButton(info)
  end
end)

local function BuildTileList()
  -- Clear existing checkboxes
  for _, cb in ipairs(tileChecks) do
    if cb and cb.Hide then pcall(cb.Hide, cb) end
    if cb and cb.SetParent then pcall(cb.SetParent, cb, nil) end
  end
  wipe(tileChecks)

  local cats = SkyInfoTiles.CATALOG or {}

  -- Debug: verify catalog exists
  if not cats or #cats == 0 then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff0000SkyInfoTiles Options:|r CATALOG is empty or missing!")
    end
    return
  end

  -- Position checkboxes below listDivider
  local lastAnchor = listDivider
  local yOffset = -8
  local maxW = 1

  for i, cat in ipairs(cats) do
    local cb = CreateCheck(content, cat.label or cat.key)
    if cb then
      cb:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, yOffset)
      cb:Show()
      yOffset = -4  -- After first one, use smaller spacing
      lastAnchor = cb
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
      maxW = math.max(maxW, 360)
    end
  end

  -- Position DungeonPorts settings below checkboxes
  dpHeader:ClearAllPoints()
  dpHeader:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -20)

  -- Position ClockTile settings below DungeonPorts (dpScale is lowest element)
  clockHeader:ClearAllPoints()
  clockHeader:SetPoint("TOPLEFT", dpScale, "BOTTOMLEFT", -6, -25)

  -- Calculate total content height
  -- Start from top, add each section's height
  local totalHeight = 30  -- listHeader + listDivider
  totalHeight = totalHeight + (#tileChecks * 26)  -- Tile checkboxes
  totalHeight = totalHeight + 120  -- DungeonPorts section
  totalHeight = totalHeight + 220  -- ClockTile section (increased for tip + more fonts)
  totalHeight = totalHeight + 50   -- Bottom padding

  content:SetSize(maxW, math.max(500, totalHeight))

  -- Debug confirmation
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SkyInfoTiles Options:|r Built " .. #tileChecks .. " tile checkboxes")
  end
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

  -- ClockTile settings
  local clockCfg = GetClockCfg() or {}

  -- Font
  local currentFont = clockCfg.font or "Fonts\\FRIZQT__.ttf"
  local fontName = "Friz Quadrata (Default)"

  -- Discover fonts if not done yet
  if not FONT_LIST then
    FONT_LIST = DiscoverFonts()
  end

  if FONT_LIST then
    for i, font in ipairs(FONT_LIST) do
      if font.path == currentFont then
        fontName = font.name
        break
      end
    end
  end
  UIDropDownMenu_SetText(clockFontDropdown, fontName)

  -- Size
  local clockSz = tonumber(clockCfg.size) or 24
  if clockSz < 6 then clockSz = 6 elseif clockSz > 128 then clockSz = 128 end
  _suppressClockApply = true
  clockSize:SetValue(clockSz)
  _suppressClockApply = false
  clockSizeValue:SetText(tostring(math.floor(clockSz)))

  -- Outline
  local currentOutline = clockCfg.outline or "OUTLINE"
  if currentOutline == "NONE" then currentOutline = "" end
  local outlineName = "Outline"
  for i, outline in ipairs(OUTLINE_LIST) do
    if outline.value == currentOutline then
      outlineName = outline.name
      break
    end
  end
  UIDropDownMenu_SetText(clockOutlineDropdown, outlineName)
end

lockCB:SetScript("OnClick", function(self)
  if SkyInfoTiles.SetLocked then
    SkyInfoTiles.SetLocked(self:GetChecked() and true or false)
  end
end)

panel:SetScript("OnShow", function()
  -- Always rebuild tile list on show (ensures it's current)
  BuildTileList()
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
        local ok, result = pcall(settingsCategory.GetID, settingsCategory)
        if ok then id = result end
      elseif settingsCategory.ID then
        id = settingsCategory.ID
      end
      if id then
        pcall(_G.Settings.OpenToCategory, id)
      else
        -- Some builds accept the category object directly
        pcall(_G.Settings.OpenToCategory, settingsCategory)
      end
    else
      pcall(_G.Settings.OpenToCategory, panel.name)
    end
  elseif _G.InterfaceOptionsFrame_OpenToCategory then
    pcall(_G.InterfaceOptionsFrame_OpenToCategory, panel)
    pcall(_G.InterfaceOptionsFrame_OpenToCategory, panel) -- called twice to work around Blizzard bug
  end
end

-- Register with game options UI
do
  local api = GetPanelAPI()
  if api == "settings" and _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
    local ok, cat = pcall(_G.Settings.RegisterCanvasLayoutCategory, panel, panel.name)
    if ok and cat then
      settingsCategory = cat
      pcall(_G.Settings.RegisterAddOnCategory, settingsCategory)
    end
  elseif _G.InterfaceOptions_AddCategory then
    pcall(_G.InterfaceOptions_AddCategory, panel)
  end
end







