local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]

-- Dynamic font list using LibSharedMedia (if available)
local function BuildFontOptions()
  local opts = {}
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if LSM and LSM.List and LSM.Fetch then
    local names = LSM:List("font") or {}
    table.sort(names, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    for _, name in ipairs(names) do
      local file = LSM:Fetch("font", name)
      if type(file) == "string" and file ~= "" then
        table.insert(opts, { label = name, file = file })
      end
    end
  end
  if #opts == 0 then
    opts = {
      { label = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
      { label = "Arial Narrow",  file = "Fonts\\ARIALN.TTF"   },
      { label = "Morpheus",      file = "Fonts\\MORPHEUS.ttf" },
      { label = "Skurri",        file = "Fonts\\SKURRI.ttf"   },
    }
  end
  return opts
end

-- Simple checkbox helper
local function CreateCheckbox(parent, label)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  local text = cb.Text or cb.text
  if not text then
    text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  end
  text:SetText(label or "")
  cb._labelFS = text
  return cb
end

-- Header styling helper (absolute: compute from first-seen base, no cumulative growth)
local function BumpHeader(fs, delta)
  if not fs or not fs.GetFont then return end
  local font, size, flags = fs:GetFont()
  if not fs._baseFontFile then
    fs._baseFontFile = font
    fs._baseFontSize = tonumber(size) or 12
    fs._baseFontFlags = flags
  end
  local base = fs._baseFontSize or (tonumber(size) or 12)
  local target = base + (delta or 4)
  fs:SetFont(fs._baseFontFile or font, target, fs._baseFontFlags or flags)
end

-- Helper: set slider value without triggering its OnValueChanged write-back
local function SetSliderValueNoSignal(slider, v)
  if not slider then return end
  slider._setting = true
  slider:SetValue(v)
  slider._setting = false
end

local panel = CreateFrame("Frame")
panel:Hide()

-- Scroll container to avoid overflow
panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
panel.scroll:SetPoint("TOPLEFT", 0, -8)
panel.scroll:SetPoint("BOTTOMRIGHT", -28, 8) -- leave space for scrollbar
panel.content = CreateFrame("Frame", nil, panel.scroll)
panel.content:SetSize(900, 2000) -- ample height for scroll
panel.scroll:SetScrollChild(panel.content)
panel.scroll:EnableMouseWheel(true)
panel.scroll:SetScript("OnMouseWheel", function(self, delta)
  if self.UpdateScrollChildRect then self:UpdateScrollChildRect() end
  local step = 40
  local current = self:GetVerticalScroll() or 0
  local target = current - (delta * step)
  if target < 0 then target = 0 end
  local maxRange = self:GetVerticalScrollRange() or 0 -- API returns a single number
  if target > maxRange then target = maxRange end
  self:SetVerticalScroll(target)
  if self.ScrollBar and self.ScrollBar.SetValue then
    self.ScrollBar:SetValue(target)
  end
end)

panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
panel.title:SetParent(panel.content)
panel.title:SetPoint("TOPLEFT", 16, -16)
panel.title:SetText("SkyInfoTiles")
if BumpHeader then BumpHeader(panel.title, 4) end

panel.desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.desc:SetParent(panel.content)
panel.desc:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -6)
panel.desc:SetText("Enable or disable predefined tiles and toggle Locked.")

-- Global Locked
panel.lockCB = CreateCheckbox(panel.content, "Locked (disable dragging)")
panel.lockCB:SetPoint("TOPLEFT", panel.desc, "BOTTOMLEFT", 0, -12)
panel.lockCB:SetScript("OnClick", function(self)
  SkyInfoTiles.SetLocked(self:GetChecked())
end)

-- Global WoW UI Scale controls (use Blizzard CVars)
panel.uiScaleHeader = panel.uiScaleHeader or panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.uiScaleHeader:SetText("Global WoW UI Scale")

panel.uiScaleUseCB = panel.uiScaleUseCB or CreateCheckbox(panel.content, "Use custom UI scale")

panel.uiScaleLabel = panel.uiScaleLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.uiScaleLabel:SetText("Scale")

panel.uiScaleEdit = panel.uiScaleEdit or CreateFrame("EditBox", nil, panel.content, "InputBoxTemplate")
panel.uiScaleEdit:SetSize(60, 20)
panel.uiScaleEdit:SetAutoFocus(false)
panel.uiScaleEdit:SetNumeric(false)
panel.uiScaleEdit:SetMaxLetters(6)

panel.uiScaleHint = panel.uiScaleHint or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

-- Header
panel.listHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.listHeader:SetParent(panel.content)
panel.listHeader:SetPoint("TOPLEFT", panel.lockCB, "BOTTOMLEFT", 0, -16)
panel.listHeader:SetText("Tiles (enable/disable):")

-- One checkbox per catalog entry
panel.tileCheckboxes = {}

-- DungeonPorts orientation controls
local function SetDungeonPortsOrientation(orient)
  local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  local cfg
  if SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfgForProfile then
    cfg = SkyInfoTiles.GetOrCreateTileCfgForProfile(base, "dungeonports")
  elseif SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg then
    cfg = SkyInfoTiles.GetOrCreateTileCfg("dungeonports")
  end
  if not cfg then return end
  cfg.orientation = orient
  if SkyInfoTiles and SkyInfoTiles.GetActiveProfileName and SkyInfoTiles.GetActiveProfileName() == base and SkyInfoTiles.Rebuild then
    SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll()
  elseif SkyInfoTiles and SkyInfoTiles._OptionsRefresh then
    SkyInfoTiles._OptionsRefresh()
  end
end

panel.dpHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.dpHeader:SetParent(panel.content)
panel.dpHeader:SetText("Dungeon Teleports layout")

panel.dpRadioH = CreateFrame("CheckButton", nil, panel.content, "UIRadioButtonTemplate")
local hText = panel.dpRadioH.Text or panel.dpRadioH.text
if not hText then
  hText = panel.dpRadioH:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  hText:SetPoint("LEFT", panel.dpRadioH, "RIGHT", 4, 0)
end
hText:SetText("Horizontal")
panel.dpRadioH._labelFS = hText

panel.dpRadioV = CreateFrame("CheckButton", nil, panel.content, "UIRadioButtonTemplate")
local vText = panel.dpRadioV.Text or panel.dpRadioV.text
if not vText then
  vText = panel.dpRadioV:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  vText:SetPoint("LEFT", panel.dpRadioV, "RIGHT", 4, 0)
end
vText:SetText("Vertical")
panel.dpRadioV._labelFS = vText

panel.dpRadioH:SetScript("OnClick", function(self)
  panel.dpRadioH:SetChecked(true); panel.dpRadioV:SetChecked(false)
  SetDungeonPortsOrientation("horizontal")
end)
panel.dpRadioV:SetScript("OnClick", function(self)
  panel.dpRadioH:SetChecked(false); panel.dpRadioV:SetChecked(true)
  SetDungeonPortsOrientation("vertical")
end)

-- Crosshair options elements
panel.chHeader = panel.chHeader or panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.chHeader:SetText("Crosshair")

panel.chSizeLabel = panel.chSizeLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.chSizeLabel:SetText("Size")

panel.chSize = panel.chSize or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
panel.chSize:SetMinMaxValues(4, 512)
panel.chSize:SetValueStep(1)
panel.chSize:SetObeyStepOnDrag(true)

panel.chSizeVal = panel.chSizeVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

panel.chThickLabel = panel.chThickLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.chThickLabel:SetText("Thickness")

panel.chThick = panel.chThick or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
panel.chThick:SetMinMaxValues(1, 64)
panel.chThick:SetValueStep(1)
panel.chThick:SetObeyStepOnDrag(true)

panel.chThickVal = panel.chThickVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

panel.chColorLabel = panel.chColorLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.chColorLabel:SetText("Color")

panel.chColorBtn = panel.chColorBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.chColorBtn:SetText("Pick Color")
panel.chColorBtn:SetWidth(100)

panel.chColorSwatch = panel.chColorSwatch or panel.content:CreateTexture(nil, "ARTWORK")
panel.chColorSwatch:SetTexture("Interface\\Buttons\\WHITE8x8")
panel.chColorSwatch:SetSize(16, 16)

-- Health Box options elements
panel.hbHeader = panel.hbHeader or panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.hbHeader:SetText("Health Box")

panel.hbWidthLabel = panel.hbWidthLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.hbWidthLabel:SetText("Width")

panel.hbWidth = panel.hbWidth or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
panel.hbWidth:SetMinMaxValues(50, 600)
panel.hbWidth:SetValueStep(1)
panel.hbWidth:SetObeyStepOnDrag(true)

panel.hbWidthVal = panel.hbWidthVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

panel.hbHeightLabel = panel.hbHeightLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.hbHeightLabel:SetText("Height")

panel.hbHeight = panel.hbHeight or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
panel.hbHeight:SetMinMaxValues(6, 64)
panel.hbHeight:SetValueStep(1)
panel.hbHeight:SetObeyStepOnDrag(true)

panel.hbHeightVal = panel.hbHeightVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

panel.hbInfoLabel = panel.hbInfoLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.hbInfoLabel:SetText("Info Mode")

panel.hbInfoDrop = panel.hbInfoDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

panel.hbHealthColorLabel = panel.hbHealthColorLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.hbHealthColorLabel:SetText("Health Color")

panel.hbHealthColorBtn = panel.hbHealthColorBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.hbHealthColorBtn:SetText("Pick")
panel.hbHealthColorBtn:SetWidth(80)

panel.hbHealthColorSwatch = panel.hbHealthColorSwatch or panel.content:CreateTexture(nil, "ARTWORK")
panel.hbHealthColorSwatch:SetTexture("Interface\\Buttons\\WHITE8x8")
panel.hbHealthColorSwatch:SetSize(16, 16)

panel.hbMissingColorLabel = panel.hbMissingColorLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.hbMissingColorLabel:SetText("Missing Color")

panel.hbMissingColorBtn = panel.hbMissingColorBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.hbMissingColorBtn:SetText("Pick")
panel.hbMissingColorBtn:SetWidth(80)

panel.hbMissingColorSwatch = panel.hbMissingColorSwatch or panel.content:CreateTexture(nil, "ARTWORK")
panel.hbMissingColorSwatch:SetTexture("Interface\\Buttons\\WHITE8x8")
panel.hbMissingColorSwatch:SetSize(16, 16)

-- Health Box: Use class color checkbox
panel.hbUseClassCB = panel.hbUseClassCB or CreateCheckbox(panel.content, "Use class color for Health")

-- Health Box: Font picker
panel.hbFontLabel = panel.hbFontLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.hbFontLabel:SetText("Font")

panel.hbFontDrop = panel.hbFontDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

-- Health Box: Font size
panel.hbFontSizeLabel = panel.hbFontSizeLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.hbFontSizeLabel:SetText("Font Size")

panel.hbFontSize = panel.hbFontSize or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
panel.hbFontSize:SetMinMaxValues(6, 64)
panel.hbFontSize:SetValueStep(1)
panel.hbFontSize:SetObeyStepOnDrag(true)

panel.hbFontSizeVal = panel.hbFontSizeVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

-- Compact Profiles row controls (Profile:, dropdown, buttons + name + rename)
panel.profLabel = panel.profLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.profLabel:SetText("Profile:")

panel.profileDrop = panel.profileDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

panel.profNewBtn = panel.profNewBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.profNewBtn:SetText("New"); panel.profNewBtn:SetWidth(72)

panel.profCopyBtn = panel.profCopyBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.profCopyBtn:SetText("Copy"); panel.profCopyBtn:SetWidth(72)

panel.profNameEdit = panel.profNameEdit or CreateFrame("EditBox", nil, panel.content, "InputBoxTemplate")
panel.profNameEdit:SetSize(220, 22); panel.profNameEdit:SetAutoFocus(false)

panel.profRenameBtn = panel.profRenameBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.profRenameBtn:SetText("Rename"); panel.profRenameBtn:SetWidth(80)

-- Profiles UI helpers
local function GetProfileNames()
  local names = {}
  if SkyInfoTilesDB and SkyInfoTilesDB.profiles then
    for name, _ in pairs(SkyInfoTilesDB.profiles) do table.insert(names, name) end
  end
  table.sort(names)
  return names
end

local function DeepCopyTilesLocal(src)
  local out = {}
  if type(src) ~= "table" then return out end
  for i, t in ipairs(src) do
    local nt = {}
    for k, v in pairs(t) do
      if type(v) == "table" then
        local tv = {}
        for k2, v2 in pairs(v) do tv[k2] = v2 end
        nt[k] = tv
      else
        nt[k] = v
      end
    end
    table.insert(out, nt)
  end
  return out
end

-- Ensure a Default profile always exists
local function EnsureDefaultProfileExists()
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or {}
  if not SkyInfoTilesDB.profiles["Default"] then
    SkyInfoTilesDB.profiles["Default"] = { tiles = {} }
  end
end

-- Generate a unique profile name by adding numeric suffixes
local function UniqueProfileName(base)
  EnsureDefaultProfileExists()
  local names = {}
  for n, _ in pairs(SkyInfoTilesDB.profiles or {}) do names[n] = true end
  local candidate = base
  local i = 2
  while names[candidate] do
    candidate = string.format("%s (%d)", base, i)
    i = i + 1
  end
  return candidate
end

local function InitProfileDropdown(drop, values, selected, onSelect)
  if not drop or not UIDropDownMenu_Initialize then return end
  -- Track selected in the dropdown frame so actions (Copy/Delete/Rename) use the current choice
  drop._selected = selected or drop._selected
  UIDropDownMenu_Initialize(drop, function(self, level)
    for _, name in ipairs(values) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = name
      info.checked = (name == (drop._selected or selected))
      info.func = function()
        drop._selected = name
        UIDropDownMenu_SetText(drop, name)
        if onSelect then onSelect(name) end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  UIDropDownMenu_SetWidth(drop, 160)
  UIDropDownMenu_SetText(drop, drop._selected or selected or "")
end

panel.profHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.profHeader:SetParent(panel.content)
panel.profHeader:SetText("Profiles")

panel.baseLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.baseLabel:SetParent(panel.content)
panel.baseLabel:SetText("Base profile")

panel.baseDrop = CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

panel.newLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.newLabel:SetParent(panel.content)
panel.newLabel:SetText("New profile name")

panel.newEdit = CreateFrame("EditBox", nil, panel.content, "InputBoxTemplate")
panel.newEdit:SetSize(160, 20)
panel.newEdit:SetAutoFocus(false)

panel.copyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panel.copyLabel:SetParent(panel.content)
panel.copyLabel:SetText("Copy from")

panel.copyDrop = CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

panel.createBtn = CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.createBtn:SetText("Create")
panel.createBtn:SetWidth(80)

panel.deleteBtn = CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.deleteBtn:SetText("Delete")
panel.deleteBtn:SetWidth(80)

-- Layout constants for Profiles section (column x-offsets)
local COL1_X, COL2_X, COL3_X, COL4_X = 0, 180, 360, 540

-- Row containers for consistent horizontal alignment
panel.profBaseRow = panel.profBaseRow or CreateFrame("Frame", nil, panel.content)
panel.profBaseRow:SetSize(640, 24)
panel.profNewRow  = panel.profNewRow  or CreateFrame("Frame", nil, panel.content)
panel.profNewRow:SetSize(640, 24)

-- Buttons row for compact Profiles layout
panel.profButtonsRow = panel.profButtonsRow or CreateFrame("Frame", nil, panel.content)
panel.profButtonsRow:SetSize(900, 24)

panel.specHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.specHeader:SetParent(panel.content)
panel.specHeader:SetText("Per-spec profiles")
panel._specExpanded = panel._specExpanded or false
panel.specToggle = panel.specToggle or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")

panel.specRows = {}
local function EnsureSpecRow(i)
  local row = panel.specRows[i]
  if not row then
    row = {}
    row.label = panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.drop = CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")
    panel.specRows[i] = row
  end
  return row
end

-- Character Stats order UI helpers
local CS_DEFAULT_ORDER = { "ilvl", "primary", "crit", "haste", "mastery", "versatility" }
local CS_FRIENDLY_NAMES = {
  ilvl = "Item Level",
  primary = "Primary Stat",
  crit = "Critical Strike",
  haste = "Haste",
  mastery = "Mastery",
  versatility = "Versatility",
}

local function EnsureCharStatsCfg()
  local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  if SkyInfoTiles then
    if SkyInfoTiles.GetOrCreateTileCfgForProfile then
      return SkyInfoTiles.GetOrCreateTileCfgForProfile(base, "charstats")
    elseif SkyInfoTiles.GetOrCreateTileCfg then
      return SkyInfoTiles.GetOrCreateTileCfg("charstats")
    end
  end
  return nil
end

local function EnsureCrosshairCfg()
  local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  if SkyInfoTiles then
    if SkyInfoTiles.GetOrCreateTileCfgForProfile then
      return SkyInfoTiles.GetOrCreateTileCfgForProfile(base, "crosshair")
    elseif SkyInfoTiles.GetOrCreateTileCfg then
      return SkyInfoTiles.GetOrCreateTileCfg("crosshair")
    end
  end
  return nil
end

local function EnsureHealthBoxCfg()
  local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  if SkyInfoTiles then
    if SkyInfoTiles.GetOrCreateTileCfgForProfile then
      return SkyInfoTiles.GetOrCreateTileCfgForProfile(base, "healthbox")
    elseif SkyInfoTiles.GetOrCreateTileCfg then
      return SkyInfoTiles.GetOrCreateTileCfg("healthbox")
    end
  end
  return nil
end

local function EnsureTargetBoxCfg()
  local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  if SkyInfoTiles then
    if SkyInfoTiles.GetOrCreateTileCfgForProfile then
      return SkyInfoTiles.GetOrCreateTileCfgForProfile(base, "targetbox")
    elseif SkyInfoTiles.GetOrCreateTileCfg then
      return SkyInfoTiles.GetOrCreateTileCfg("targetbox")
    end
  end
  return nil
end

local function EnsurePetBoxCfg()
  local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  if SkyInfoTiles then
    if SkyInfoTiles.GetOrCreateTileCfgForProfile then
      return SkyInfoTiles.GetOrCreateTileCfgForProfile(base, "petbox")
    elseif SkyInfoTiles.GetOrCreateTileCfg then
      return SkyInfoTiles.GetOrCreateTileCfg("petbox")
    end
  end
  return nil
end

-- Helper: which profile's settings should be SHOWN in the UI
local function GetShownProfileName()
  -- Always show and edit the profile chosen in the dropdown
  local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  return base
end

-- Helpers to get cfg for a specific tile key and profile (read vs write)
local function EnsureTileCfgForProfile(tileKey, profileName)
  if SkyInfoTiles then
    if SkyInfoTiles.GetOrCreateTileCfgForProfile then
      return SkyInfoTiles.GetOrCreateTileCfgForProfile(profileName, tileKey)
    elseif SkyInfoTiles.GetOrCreateTileCfg then
      return SkyInfoTiles.GetOrCreateTileCfg(tileKey)
    end
  end
  return nil
end

local function EnsureCfgRead(key)
  return EnsureTileCfgForProfile(key, GetShownProfileName())
end

local function EnsureCfgWrite(key)
  local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  return EnsureTileCfgForProfile(key, base)
end

panel.csHeader = panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.csHeader:SetText("Character Stats order")

panel.csRows = {}
panel.csResetBtn = CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
panel.csResetBtn:SetText("Reset Order")
panel.csResetBtn:SetWidth(110)

local function EnsureCSRow(i)
  local row = panel.csRows[i]
  if not row then
    row = {}
    row.label = panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.up = CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
    row.up:SetText("Up")
    row.up:SetWidth(40)
    row.down = CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
    row.down:SetText("Down")
    row.down:SetWidth(52)
    panel.csRows[i] = row
  end
  return row
end

local function EnsureTileCheckbox(i)
  local cb = panel.tileCheckboxes[i]
  if not cb then
    cb = CreateCheckbox(panel.content, "")
    -- Make sure the checkbox is fully interactive
    if cb.Enable then cb:Enable() end
    if cb.SetEnabled then cb:SetEnabled(true) end
    if cb.EnableMouse then cb:EnableMouse(true) end
    if cb.RegisterForClicks then cb:RegisterForClicks("LeftButtonUp") end
    if cb.SetHitRectInsets then cb:SetHitRectInsets(-4, -200, -4, -4) end

    if i == 1 then
      cb:SetPoint("TOPLEFT", panel.listHeader, "BOTTOMLEFT", 0, -10)
    else
      cb:SetPoint("TOPLEFT", panel.tileCheckboxes[i - 1], "BOTTOMLEFT", 0, -10)
    end
    panel.tileCheckboxes[i] = cb
  else
    -- Reinforce interactivity on reused checkbox
    if cb.Enable then cb:Enable() end
    if cb.SetEnabled then cb:SetEnabled(true) end
    if cb.EnableMouse then cb:EnableMouse(true) end
    if cb.RegisterForClicks then cb:RegisterForClicks("LeftButtonUp") end
    if cb.SetHitRectInsets then cb:SetHitRectInsets(-4, -200, -4, -4) end
  end
  cb:Show()
  return cb
end

local function RefreshList()
  -- Ensure Default profile and valid base selection
  EnsureDefaultProfileExists()
  if not SkyInfoTilesDB.profile or not (SkyInfoTilesDB.profiles and SkyInfoTilesDB.profiles[SkyInfoTilesDB.profile]) then
    SkyInfoTilesDB.profile = "Default"
  end

  -- Locked state
  panel.lockCB:SetChecked(SkyInfoTilesDB and SkyInfoTilesDB.locked or false)

  -- Profiles section (compact row)
  local names = GetProfileNames()
  if #names == 0 then
    SkyInfoTilesDB = SkyInfoTilesDB or {}
    SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or {}
    SkyInfoTilesDB.profiles["Default"] = SkyInfoTilesDB.profiles["Default"] or { tiles = {} }
    names = GetProfileNames()
  end
  local baseName = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"

  -- Layout compact row
  panel.profLabel:ClearAllPoints()
  panel.profLabel:SetPoint("TOPLEFT", panel.lockCB, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.profLabel) end
  panel.profLabel:Show()

  panel.profileDrop:ClearAllPoints()
  panel.profileDrop:SetPoint("LEFT", panel.profLabel, "RIGHT", 8, 0)
  InitProfileDropdown(panel.profileDrop, names, baseName, function(sel)
    SkyInfoTilesDB.profile = sel or "Default"
    if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)

  panel.profButtonsRow:ClearAllPoints()
  panel.profButtonsRow:SetPoint("TOPLEFT", panel.profLabel, "BOTTOMLEFT", 0, -8)
  panel.profButtonsRow:Show()

  panel.profNewBtn:ClearAllPoints()
  panel.profNewBtn:SetPoint("LEFT", panel.profButtonsRow, "LEFT", 0, 0)
  panel.profNewBtn:Show()

  panel.profCopyBtn:ClearAllPoints()
  panel.profCopyBtn:SetPoint("LEFT", panel.profNewBtn, "RIGHT", 12, 0)
  panel.profCopyBtn:Show()

  panel.deleteBtn:ClearAllPoints()
  panel.deleteBtn:SetText("Delete")
  panel.deleteBtn:SetPoint("LEFT", panel.profCopyBtn, "RIGHT", 12, 0)
  panel.deleteBtn:Show()

  panel.profNameEdit:ClearAllPoints()
  panel.profNameEdit:SetPoint("LEFT", panel.deleteBtn, "RIGHT", 12, 0)
  panel.profNameEdit:SetText(baseName)
  panel.profNameEdit:Show()

  panel.profRenameBtn:ClearAllPoints()
  panel.profRenameBtn:SetPoint("LEFT", panel.profNameEdit, "RIGHT", 12, 0)
  panel.profRenameBtn:Show()

  -- Active profile indicator (shows effective profile; notes spec override)
  panel.activeProfLabel = panel.activeProfLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.activeProfLabel:ClearAllPoints()
  panel.activeProfLabel:SetPoint("LEFT", panel.profRenameBtn, "RIGHT", 12, 0)
  local activeName = (SkyInfoTiles and SkyInfoTiles.GetActiveProfileName and SkyInfoTiles.GetActiveProfileName()) or (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  local baseName2 = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  local overridden = (activeName ~= baseName2)
  local specOn = (SkyInfoTilesDB and SkyInfoTilesDB.enableSpecProfiles) or false
  local suffix = specOn and (overridden and " (per-spec ON, overridden)" or " (per-spec ON)") or " (per-spec OFF)"
  panel.activeProfLabel:SetText(string.format("Active: %s%s", tostring(activeName), suffix))
  panel.activeProfLabel:Show()

  -- Button to apply the selected base profile to the current spec (so switching takes effect immediately)
  panel.profApplyBtn = panel.profApplyBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
  panel.profApplyBtn:SetText("Use for current spec")
  panel.profApplyBtn:SetWidth(160)
  panel.profApplyBtn:ClearAllPoints()
  panel.profApplyBtn:SetPoint("LEFT", panel.activeProfLabel, "RIGHT", 12, 0)
  panel.profApplyBtn:Show()
  panel.profApplyBtn:SetScript("OnClick", function()
    local base = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
    local sid = nil
    if type(GetSpecialization)=="function" and type(GetSpecializationInfo)=="function" then
      local idx = GetSpecialization()
      if idx then
        sid = select(1, GetSpecializationInfo(idx))
      end
    end
    if sid then
      SkyInfoTilesDB.specProfiles = SkyInfoTilesDB.specProfiles or {}
      SkyInfoTilesDB.specProfiles[sid] = base
    end
    if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)

  -- Master toggle: Use per-spec profiles
  panel.specMasterCB = panel.specMasterCB or CreateCheckbox(panel.content, "Enable spec profiles")
  panel.specMasterCB:ClearAllPoints()
  panel.specMasterCB:SetPoint("TOPLEFT", panel.profButtonsRow, "BOTTOMLEFT", 0, -10)
  panel.specMasterCB:SetChecked((SkyInfoTilesDB and SkyInfoTilesDB.enableSpecProfiles) or false)
  panel.specMasterCB:Show()
  panel.specMasterCB:SetScript("OnClick", function(self)
    SkyInfoTilesDB.enableSpecProfiles = self:GetChecked() and true or false
    if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)

  -- Hide old multi-row controls
  if panel.profHeader then panel.profHeader:Hide() end
  if panel.baseLabel then panel.baseLabel:Hide() end
  if panel.baseDrop then panel.baseDrop:Hide() end
  if panel.profBaseRow then panel.profBaseRow:Hide() end
  if panel.newLabel then panel.newLabel:Hide() end
  if panel.newEdit then panel.newEdit:Hide() end
  if panel.copyLabel then panel.copyLabel:Hide() end
  if panel.copyDrop then panel.copyDrop:Hide() end
  if panel.createBtn then panel.createBtn:Hide() end
  if panel.profNewRow then panel.profNewRow:Hide() end

  -- Button scripts
  panel.profNewBtn:SetScript("OnClick", function()
    EnsureDefaultProfileExists()
    local name = (panel.profNameEdit:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
    if name == "" then
      name = UniqueProfileName("New")
    elseif SkyInfoTilesDB.profiles and SkyInfoTilesDB.profiles[name] then
      name = UniqueProfileName(name)
    end
    SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or {}
    if not SkyInfoTilesDB.profiles[name] then
      SkyInfoTilesDB.profiles[name] = { tiles = {} }
    end
    SkyInfoTilesDB.profile = name
    if panel.profileDrop then panel.profileDrop._selected = name end
    if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)

  panel.profCopyBtn:SetScript("OnClick", function()
    EnsureDefaultProfileExists()
    local fromName = panel.profileDrop and panel.profileDrop._selected or baseName or "Default"
    if not (SkyInfoTilesDB.profiles and SkyInfoTilesDB.profiles[fromName]) then
      fromName = "Default"
    end
    local typed = (panel.profNameEdit:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
    local toName
    if typed == "" then
      toName = UniqueProfileName(fromName .. " Copy")
    else
      toName = typed
      if SkyInfoTilesDB.profiles and SkyInfoTilesDB.profiles[toName] then
        toName = UniqueProfileName(toName)
      end
    end
    SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or {}
    local src = SkyInfoTilesDB.profiles[fromName] and SkyInfoTilesDB.profiles[fromName].tiles or {}
    local tiles = DeepCopyTilesLocal(src)
    SkyInfoTilesDB.profiles[toName] = { tiles = tiles }
    SkyInfoTilesDB.profile = toName
    if panel.profileDrop then panel.profileDrop._selected = toName end
    if panel.profNameEdit then panel.profNameEdit:SetText(toName) end
    if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)

  panel.deleteBtn:SetScript("OnClick", function()
    EnsureDefaultProfileExists()
    local current = panel.profileDrop and panel.profileDrop._selected or baseName or "Default"
    local active = (SkyInfoTiles and SkyInfoTiles.GetActiveProfileName and SkyInfoTiles.GetActiveProfileName()) or current
    if current == "Default" then return end -- never delete Default
    if current == active then
      -- Switch base to Default first so we can delete this profile
      SkyInfoTilesDB.profile = "Default"
      if panel.profileDrop then panel.profileDrop._selected = "Default" end
      if panel.profNameEdit then panel.profNameEdit:SetText("Default") end
      active = "Default"
    end
    if not (SkyInfoTilesDB and SkyInfoTilesDB.profiles and SkyInfoTilesDB.profiles[current]) then return end
    -- clear spec mappings pointing to deleted profile
    if type(SkyInfoTilesDB.specProfiles)=="table" then
      for k, v in pairs(SkyInfoTilesDB.specProfiles) do if v == current then SkyInfoTilesDB.specProfiles[k] = nil end end
    end
    SkyInfoTilesDB.profiles[current] = nil
    -- fallback to Default always
    EnsureDefaultProfileExists()
    SkyInfoTilesDB.profile = "Default"
    if panel.profileDrop then panel.profileDrop._selected = "Default" end
    if panel.profNameEdit then panel.profNameEdit:SetText("Default") end
    if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)

  panel.profRenameBtn:SetScript("OnClick", function()
    EnsureDefaultProfileExists()
    local old = panel.profileDrop and panel.profileDrop._selected or baseName or "Default"
    local newName = (panel.profNameEdit:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
    if newName == "" or newName == old then return end
    if old == "Default" then return end -- cannot rename Default
    if newName == "Default" then return end -- cannot rename something into Default
    if not (SkyInfoTilesDB and SkyInfoTilesDB.profiles and SkyInfoTilesDB.profiles[old]) then return end
    if SkyInfoTilesDB.profiles[newName] then
      newName = UniqueProfileName(newName)
    end
    SkyInfoTilesDB.profiles[newName] = SkyInfoTilesDB.profiles[old]
    SkyInfoTilesDB.profiles[old] = nil
    if SkyInfoTilesDB.profile == old then SkyInfoTilesDB.profile = newName end
    if type(SkyInfoTilesDB.specProfiles)=="table" then
      for k, v in pairs(SkyInfoTilesDB.specProfiles) do if v == old then SkyInfoTilesDB.specProfiles[k] = newName end end
    end
    if panel.profileDrop then panel.profileDrop._selected = newName end
    if panel.profNameEdit then panel.profNameEdit:SetText(newName) end
    if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)

  -- Spec mapping header below compact row
  -- Compact per-spec profiles row (always visible; horizontal blocks)
  -- Header help text under the master toggle
  panel.specHeader:ClearAllPoints()
  panel.specHeader:SetPoint("TOPLEFT", panel.specMasterCB, "BOTTOMLEFT", 0, -6)
  panel.specHeader:SetText("When enabled, your profile will be set to the specified profile when you change specialization.")
  panel.specHeader:SetFontObject(GameFontHighlightSmall)
  panel.specHeader:Show()

  -- Build horizontal blocks for each spec
  local n = (type(GetNumSpecializations)=="function" and GetNumSpecializations()) or 0
  local activeSpecId = nil
  if type(GetSpecialization)=="function" and type(GetSpecializationInfo)=="function" then
    local idx = GetSpecialization()
    if idx then activeSpecId = select(1, GetSpecializationInfo(idx)) end
  end

  local prevBlock = nil
  local spacingX = 2
  for i = 1, n do
    local id, specName = GetSpecializationInfo(i)
    if id then
      local row = EnsureSpecRow(i)
      row.frame = row.frame or CreateFrame("Frame", nil, panel.content)
      row.frame:SetSize(140, 44)
      row.frame:ClearAllPoints()
      if not prevBlock then
        row.frame:SetPoint("TOPLEFT", panel.specHeader, "BOTTOMLEFT", 0, -10)
      else
        row.frame:SetPoint("LEFT", prevBlock, "RIGHT", spacingX, 0)
      end
      row.frame:Show()

      row.label:ClearAllPoints()
      row.label:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
      local isActive = (activeSpecId == id)
      local labelText = specName or ("Spec " .. i)
      if isActive then labelText = labelText .. " - Active" end
      row.label:SetText(labelText)
      row.label:Show()

      row.drop:ClearAllPoints()
      row.drop:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
      row.drop:Show()

      -- Dropdown values
      local assigned = SkyInfoTilesDB and SkyInfoTilesDB.specProfiles and SkyInfoTilesDB.specProfiles[id] or nil
      local values = { "(not assigned)" }
      for _, nme in ipairs(names) do table.insert(values, nme) end
      local selectedText = assigned or "(not assigned)"
      InitProfileDropdown(row.drop, values, selectedText, function(sel)
        if sel == "(not assigned)" then
          if SkyInfoTilesDB and SkyInfoTilesDB.specProfiles then SkyInfoTilesDB.specProfiles[id] = nil end
        else
          SkyInfoTilesDB.specProfiles = SkyInfoTilesDB.specProfiles or {}
          SkyInfoTilesDB.specProfiles[id] = sel
        end
        if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
        if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
      end)
      if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(row.drop, 120) end
 
      prevBlock = row.frame
    end
  end

  -- Hide any extra created rows beyond number of specs
  for i = n + 1, #panel.specRows do
    local row = panel.specRows[i]
    if row then
      if row.label then row.label:Hide() end
      if row.drop then row.drop:Hide() end
      if row.frame then row.frame:Hide() end
    end
  end

  -- Move the tiles list header below the profiles/spec section (with a separator)
  panel.sepProfiles = panel.sepProfiles or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepProfiles:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepProfiles:SetVertexColor(1, 1, 1, 0.15)
  panel.sepProfiles:ClearAllPoints()
  local profAnchor = panel.specRows[1] and (panel.specRows[1].frame or panel.specHeader) or panel.specHeader
  panel.sepProfiles:SetPoint("TOPLEFT", profAnchor, "BOTTOMLEFT", 0, -10)
  panel.sepProfiles:SetPoint("TOPRIGHT", profAnchor, "BOTTOMRIGHT", -28, -10) -- leave space for scrollbar
  panel.sepProfiles:SetHeight(1)
panel.sepProfiles:Show()

-- Global UI Scale section (affects entire WoW UI via CVars)
panel.uiScaleHeader:ClearAllPoints()
panel.uiScaleHeader:SetPoint("TOPLEFT", panel.sepProfiles, "BOTTOMLEFT", 0, -16)
if BumpHeader then BumpHeader(panel.uiScaleHeader) end
panel.uiScaleHeader:Show()

panel.uiScaleUseCB:ClearAllPoints()
panel.uiScaleUseCB:SetPoint("TOPLEFT", panel.uiScaleHeader, "BOTTOMLEFT", 0, -10)
panel.uiScaleUseCB:Show()

panel.uiScaleLabel:ClearAllPoints()
panel.uiScaleLabel:SetPoint("TOPLEFT", panel.uiScaleUseCB, "BOTTOMLEFT", 0, -12)
panel.uiScaleLabel:Show()

panel.uiScaleEdit:ClearAllPoints()
panel.uiScaleEdit:SetPoint("LEFT", panel.uiScaleLabel, "RIGHT", 8, 0)
panel.uiScaleEdit:Show()

panel.uiScaleHint:ClearAllPoints()
panel.uiScaleHint:SetPoint("LEFT", panel.uiScaleEdit, "RIGHT", 12, 0)
panel.uiScaleHint:Show()

-- Read current CVar values
local use = (C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("useUiScale")) or (GetCVarBool and GetCVarBool("useUiScale")) or false
local curScale = (C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar("uiScale"))) or (GetCVar and tonumber(GetCVar("uiScale"))) or 0.5
panel.uiScaleUseCB:SetChecked(false)
if panel.uiScaleEdit and panel.uiScaleEdit.SetText then panel.uiScaleEdit:SetText(string.format("%.2f", curScale)) end
panel.uiScaleHint:SetText("(press Enter to apply; range 0.30–1.50)")

-- Toggle enabling of edit field based on checkbox
local function UpdateUiScaleEditEnabled()
  local enabled = panel.uiScaleUseCB:GetChecked() and true or false
  if panel.uiScaleEdit and panel.uiScaleEdit.Enable then panel.uiScaleEdit:Enable() end
  if panel.uiScaleEdit and panel.uiScaleEdit.SetEnabled then panel.uiScaleEdit:SetEnabled(enabled) end
  if not enabled and panel.uiScaleEdit and panel.uiScaleEdit.ClearFocus then panel.uiScaleEdit:ClearFocus() end
end
UpdateUiScaleEditEnabled()

panel.uiScaleUseCB:SetScript("OnClick", function(self)
  local enable = self:GetChecked() and true or false
  if SkyInfoTiles and SkyInfoTiles.SetUseUiScale then
    SkyInfoTiles.SetUseUiScale(enable)
  end
  -- When enabling, immediately apply the current edit value (default to 0.50)
  if enable then
    local txt = panel.uiScaleEdit and panel.uiScaleEdit:GetText() or ""
    local v = tonumber(txt) or 0.5
    if v < 0.3 then v = 0.3 elseif v > 1.5 then v = 1.5 end
    if panel.uiScaleEdit and panel.uiScaleEdit.SetText then
      panel.uiScaleEdit:SetText(string.format("%.2f", v))
    end
    if SkyInfoTiles and SkyInfoTiles.ApplyUiScale then
      SkyInfoTiles.ApplyUiScale(v)
    end
  end
  UpdateUiScaleEditEnabled()
end)

-- Apply only on Enter; do nothing if use custom is OFF
panel.uiScaleEdit:SetScript("OnEnterPressed", function(self)
  local txt = self:GetText() or ""
  local v = tonumber(txt)
  if not v then
    self:SetText(string.format("%.2f", curScale))
    return
  end
  if v < 0.3 then v = 0.3 elseif v > 1.5 then v = 1.5 end
  self:SetText(string.format("%.2f", v))
  if panel.uiScaleUseCB:GetChecked() and SkyInfoTiles and SkyInfoTiles.ApplyUiScale then
    SkyInfoTiles.ApplyUiScale(v)
  end
  self:ClearFocus()
end)
panel.uiScaleEdit:SetScript("OnEscapePressed", function(self)
  self:SetText(string.format("%.2f", curScale))
  self:ClearFocus()
end)

-- Separator below UI scale section
panel.sepUiScale = panel.sepUiScale or panel.content:CreateTexture(nil, "ARTWORK")
panel.sepUiScale:SetTexture("Interface\\Buttons\\WHITE8x8")
panel.sepUiScale:SetVertexColor(1, 1, 1, 0.15)
panel.sepUiScale:ClearAllPoints()
panel.sepUiScale:SetPoint("TOPLEFT", panel.uiScaleLabel, "BOTTOMLEFT", 0, -12)
panel.sepUiScale:SetPoint("TOPRIGHT", panel.uiScaleLabel, "BOTTOMRIGHT", -28, -12)
panel.sepUiScale:SetHeight(1)
panel.sepUiScale:Show()

-- Tiles list header now comes after the UI scale section
panel.listHeader:ClearAllPoints()
panel.listHeader:SetPoint("TOPLEFT", panel.sepProfiles, "BOTTOMLEFT", 0, -16)
if BumpHeader then BumpHeader(panel.listHeader) end

  -- Catalog entries (hide certain tiles from the list to avoid confusion)
  local HIDE_KEYS = { healthbox = true, targetbox = true, petbox = true, groupbuffs = true }
  local catalog = {}
  for _, cat in ipairs(SkyInfoTiles.CATALOG or {}) do
    if not HIDE_KEYS[cat.key] then
      table.insert(catalog, cat)
    end
  end
  for i, cat in ipairs(catalog) do
    local cb = EnsureTileCheckbox(i)
    local label = string.format("[%s] %s", cat.key, cat.label or cat.type)
    local text = cb.Text or cb.text or cb._labelFS
    text:SetText(label)
  local shownNameTiles = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  local baseNameTiles = shownNameTiles
    if SkyInfoTiles and SkyInfoTiles.GetTileEnabledByKeyForProfile then
      cb:SetChecked(SkyInfoTiles.GetTileEnabledByKeyForProfile(shownNameTiles, cat.key))
      cb._tileKey = cat.key
      cb:SetScript("OnClick", function(self)
        local baseNow = (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
        local shownNow = (GetShownProfileName and GetShownProfileName()) or baseNow
        local newVal = self:GetChecked() and true or false
        -- Debug: show we received the click (helps diagnose if handler isn't firing)
        if DEFAULT_CHAT_FRAME then
          DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r toggle [%s] in profile [%s] -> %s", tostring(self._tileKey), tostring(baseNow), tostring(newVal)))
        end
        -- Primary path: use core setter (writes to chosen profile)
        if SkyInfoTiles and SkyInfoTiles.SetTileEnabledByKeyForProfile then
          SkyInfoTiles.SetTileEnabledByKeyForProfile(baseNow, self._tileKey, newVal)
        end
        -- Hard fallback: directly set value in selected profile to guarantee persistence
        if SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfgForProfile then
          local cfg = SkyInfoTiles.GetOrCreateTileCfgForProfile(baseNow, self._tileKey)
          if cfg then cfg.enabled = newVal end
        end
        -- Immediate visual feedback mirrors chosen profile's state
        self:SetChecked(newVal)
        -- Refresh panel only if the shown profile matches the edited profile; otherwise keep the view as-is
        if shownNow == baseNow then
          if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then
            SkyInfoTiles._OptionsRefresh()
          end
        end
      end)
    else
      cb:SetChecked(SkyInfoTiles.GetTileEnabledByKey(cat.key))
      cb._tileKey = cat.key
      cb:SetScript("OnClick", function(self)
        SkyInfoTiles.SetTileEnabledByKey(self._tileKey, self:GetChecked())
      end)
    end
  end

  -- Position Dungeon Teleports layout controls after the list (with section separator)
  local anchor = panel.listHeader
  if #catalog > 0 then
    anchor = panel.tileCheckboxes[#catalog]
  end
  panel.sepTiles = panel.sepTiles or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepTiles:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepTiles:SetVertexColor(1, 1, 1, 0.15)
  panel.sepTiles:ClearAllPoints()
  panel.sepTiles:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  panel.sepTiles:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -28, -10)
  panel.sepTiles:SetHeight(1)
  panel.sepTiles:Show()

  panel.dpHeader:ClearAllPoints()
  panel.dpHeader:SetPoint("TOPLEFT", panel.sepTiles, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.dpHeader) end
  panel.dpRadioH:ClearAllPoints()
  panel.dpRadioH:SetPoint("TOPLEFT", panel.dpHeader, "BOTTOMLEFT", 0, -8)
  panel.dpRadioV:ClearAllPoints()
  panel.dpRadioV:SetPoint("LEFT", panel.dpRadioH, "RIGHT", 60, 0)

  -- Reflect current orientation (default horizontal), using shown profile when per-spec enabled
  local orient = "horizontal"
  local dpCfg
  local shownName3 = GetShownProfileName()
  if SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfgForProfile then
    dpCfg = SkyInfoTiles.GetOrCreateTileCfgForProfile(shownName3, "dungeonports")
  elseif SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg then
    dpCfg = SkyInfoTiles.GetOrCreateTileCfg("dungeonports")
  end
  if dpCfg and dpCfg.orientation then orient = dpCfg.orientation end
  panel.dpRadioH:SetChecked(orient ~= "vertical")
  panel.dpRadioV:SetChecked(orient == "vertical")
  panel.dpHeader:Show(); panel.dpRadioH:Show(); panel.dpRadioV:Show()

  -- Dungeon Teleports scale slider (0.5 - 2.0)
  panel.dpScaleLabel = panel.dpScaleLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.dpScaleLabel:SetText("Scale")
  panel.dpScale = panel.dpScale or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.dpScale:SetMinMaxValues(0.5, 2.0)
  panel.dpScale:SetValueStep(0.05)
  panel.dpScale:SetObeyStepOnDrag(true)
  panel.dpScaleVal = panel.dpScaleVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.dpScaleLabel:ClearAllPoints()
  panel.dpScaleLabel:SetPoint("TOPLEFT", panel.dpRadioH, "BOTTOMLEFT", 0, -12)
  panel.dpScaleLabel:Show()

  panel.dpScale:ClearAllPoints()
  panel.dpScale:SetPoint("LEFT", panel.dpScaleLabel, "RIGHT", 8, 0)
  local dpScale = (dpCfg and tonumber(dpCfg.scale)) or 1.0
  if SetSliderValueNoSignal then SetSliderValueNoSignal(panel.dpScale, dpScale) else panel.dpScale:SetValue(dpScale) end
  panel.dpScale:Show()

  panel.dpScaleVal:ClearAllPoints()
  panel.dpScaleVal:SetPoint("LEFT", panel.dpScale, "RIGHT", 12, 0)
  panel.dpScaleVal:SetText(string.format("%.2fx", dpScale))
  panel.dpScaleVal:Show()

  panel.dpScale:SetScript("OnValueChanged", function(self, val)
    if self._setting then return end
    val = tonumber(val) or 1.0
    if val < 0.5 then val = 0.5 elseif val > 2.0 then val = 2.0 end
    if dpCfg then dpCfg.scale = val end
    panel.dpScaleVal:SetText(string.format("%.2fx", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Character Stats order UI
  local csCfgRead = EnsureCfgRead("charstats")
  local csCfgWrite = EnsureCfgWrite("charstats")
  local order = {}
  local valid = {}
  for _, k in ipairs(CS_DEFAULT_ORDER) do valid[k] = true end
  if csCfgRead and type(csCfgRead.order) == "table" then
    for _, k in ipairs(csCfgRead.order) do
      if valid[k] then
        local dup = false
        for __, x in ipairs(order) do if x == k then dup = true; break end end
        if not dup then table.insert(order, k) end
      end
    end
  end
  for _, k in ipairs(CS_DEFAULT_ORDER) do
    local found = false
    for __, x in ipairs(order) do if x == k then found = true; break end end
    if not found then table.insert(order, k) end
  end

  -- Position header under Dungeon Ports controls (with separator)
  panel.sepDP = panel.sepDP or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepDP:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepDP:SetVertexColor(1, 1, 1, 0.15)
  panel.sepDP:ClearAllPoints()
  panel.sepDP:SetPoint("TOPLEFT", panel.dpScaleLabel, "BOTTOMLEFT", 0, -10)
  panel.sepDP:SetPoint("TOPRIGHT", panel.dpScaleLabel, "BOTTOMRIGHT", -28, -10)
  panel.sepDP:SetHeight(1)
  panel.sepDP:Show()

  panel.csHeader:ClearAllPoints()
  panel.csHeader:SetPoint("TOPLEFT", panel.sepDP, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.csHeader) end
  panel.csHeader:Show()

  -- Build rows
  local prevLabel = nil
  for i = 1, #CS_DEFAULT_ORDER do
    local row = EnsureCSRow(i)
    local key = order[i]
    local labelText = CS_FRIENDLY_NAMES[key] or tostring(key)

    row.label:ClearAllPoints()
    if i == 1 then
      row.label:SetPoint("TOPLEFT", panel.csHeader, "BOTTOMLEFT", 0, -14)
    else
      row.label:SetPoint("TOPLEFT", prevLabel, "BOTTOMLEFT", 0, -12)
    end
    row.label:SetText(string.format("%d. %s", i, labelText))
    row.label:Show()

    row.up:ClearAllPoints()
    row.up:SetPoint("LEFT", row.label, "RIGHT", 16, 0)
    row.up:SetEnabled(i > 1)
    row.up:Show()

    row.down:ClearAllPoints()
    row.down:SetPoint("LEFT", row.up, "RIGHT", 6, 0)
    row.down:SetEnabled(i < #CS_DEFAULT_ORDER)
    row.down:Show()

    -- Bind handlers to current index (rebound each refresh)
    local idx = i
    row.up:SetScript("OnClick", function()
      if idx <= 1 then return end
      order[idx], order[idx-1] = order[idx-1], order[idx]
      local new = {}
      for j, k in ipairs(order) do new[j] = k end
      if csCfgWrite then csCfgWrite.order = new end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
      if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
    end)
    row.down:SetScript("OnClick", function()
      if idx >= #CS_DEFAULT_ORDER then return end
      order[idx], order[idx+1] = order[idx+1], order[idx]
      local new = {}
      for j, k in ipairs(order) do new[j] = k end
      if csCfgWrite then csCfgWrite.order = new end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
      if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
    end)

    prevLabel = row.label
  end

  -- Hide any extra created rows beyond needed
  for i = #CS_DEFAULT_ORDER + 1, #panel.csRows do
    local row = panel.csRows[i]
    if row then
      if row.label then row.label:Hide() end
      if row.up then row.up:Hide() end
      if row.down then row.down:Hide() end
    end
  end

  -- Reset button
  panel.csResetBtn:ClearAllPoints()
  panel.csResetBtn:SetPoint("TOPLEFT", prevLabel or panel.csHeader, "BOTTOMLEFT", 0, -10)
  panel.csResetBtn:SetScript("OnClick", function()
    if csCfgWrite then csCfgWrite.order = nil end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)
  panel.csResetBtn:Show()

  -- Crosshair options layout and bindings
  local chCfgRead = EnsureCfgRead("crosshair")
  local chCfgWrite = EnsureCfgWrite("crosshair")
  local size = (chCfgRead and tonumber(chCfgRead.size)) or 32
  local thick = (chCfgRead and tonumber(chCfgRead.thickness)) or 2
  local col = (chCfgRead and chCfgRead.color) or { r = 1, g = 0, b = 0, a = 0.9 }

  -- Separator before Crosshair section
  panel.sepCS = panel.sepCS or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepCS:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepCS:SetVertexColor(1, 1, 1, 0.15)
  panel.sepCS:ClearAllPoints()
  panel.sepCS:SetPoint("TOPLEFT", panel.csResetBtn, "BOTTOMLEFT", 0, -10)
  panel.sepCS:SetPoint("TOPRIGHT", panel.csResetBtn, "BOTTOMRIGHT", -28, -10)
  panel.sepCS:SetHeight(1)
  panel.sepCS:Show()

  panel.chHeader:ClearAllPoints()
  panel.chHeader:SetPoint("TOPLEFT", panel.sepCS, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.chHeader) end
  panel.chHeader:Show()

  panel.chSizeLabel:ClearAllPoints()
  panel.chSizeLabel:SetPoint("TOPLEFT", panel.chHeader, "BOTTOMLEFT", 0, -16)
  panel.chSizeLabel:Show()

  panel.chSize:ClearAllPoints()
  panel.chSize:SetPoint("LEFT", panel.chSizeLabel, "RIGHT", 8, 0)
  panel.chSize:SetMinMaxValues(4, 512)
  panel.chSize:SetValueStep(1)
  panel.chSize:SetObeyStepOnDrag(true)
  SetSliderValueNoSignal(panel.chSize, size)
  panel.chSize:Show()

  panel.chSizeVal:ClearAllPoints()
  panel.chSizeVal:SetPoint("LEFT", panel.chSize, "RIGHT", 12, 0)
  panel.chSizeVal:SetText(string.format("%d px", size))
  panel.chSizeVal:Show()

  panel.chSize:SetScript("OnValueChanged", function(self, val)
    if self._setting then return end
    val = math.floor(tonumber(val) or 32)
    if chCfgWrite then chCfgWrite.size = val end
    panel.chSizeVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Thickness controls
  panel.chThickLabel:ClearAllPoints()
  panel.chThickLabel:SetPoint("TOPLEFT", panel.chSizeLabel, "BOTTOMLEFT", 0, -18)
  panel.chThickLabel:Show()

  panel.chThick:ClearAllPoints()
  panel.chThick:SetPoint("LEFT", panel.chThickLabel, "RIGHT", 8, 0)
  panel.chThick:SetMinMaxValues(1, 64)
  panel.chThick:SetValueStep(1)
  panel.chThick:SetObeyStepOnDrag(true)
  SetSliderValueNoSignal(panel.chThick, thick)
  panel.chThick:Show()

  panel.chThickVal:ClearAllPoints()
  panel.chThickVal:SetPoint("LEFT", panel.chThick, "RIGHT", 12, 0)
  panel.chThickVal:SetText(string.format("%d px", thick))
  panel.chThickVal:Show()

  panel.chThick:SetScript("OnValueChanged", function(self, val)
    if self._setting then return end
    val = math.floor(tonumber(val) or 2)
    if chCfgWrite then chCfgWrite.thickness = val end
    panel.chThickVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  panel.chColorLabel:ClearAllPoints()
  panel.chColorLabel:SetPoint("TOPLEFT", panel.chThickLabel, "BOTTOMLEFT", 0, -16)
  panel.chColorLabel:Show()

  panel.chColorBtn:ClearAllPoints()
  panel.chColorBtn:SetPoint("LEFT", panel.chColorLabel, "RIGHT", 8, 0)
  panel.chColorBtn:Show()

  panel.chColorSwatch:ClearAllPoints()
  panel.chColorSwatch:SetPoint("LEFT", panel.chColorBtn, "RIGHT", 8, 0)
  if panel.chColorSwatch.SetColorTexture then
    panel.chColorSwatch:SetColorTexture(col.r or 1, col.g or 1, col.b or 1, col.a or 1)
  else
    panel.chColorSwatch:SetVertexColor(col.r or 1, col.g or 1, col.b or 1, 1)
    panel.chColorSwatch:SetAlpha((col.a ~= nil) and col.a or 1)
  end
  panel.chColorSwatch:Show()

  -- Color picker hookups
  panel.chColorBtn:SetScript("OnClick", function()
    local r, g, b = col.r or 1, col.g or 1, col.b or 1
    local a = (col.a ~= nil) and col.a or 1

    local function ApplyColor(nr, ng, nb, na)
      col = { r = nr, g = ng, b = nb, a = na }
      if chCfgWrite then chCfgWrite.color = col end
      if panel.chColorSwatch.SetColorTexture then
        panel.chColorSwatch:SetColorTexture(nr, ng, nb, na)
      else
        panel.chColorSwatch:SetVertexColor(nr, ng, nb, 1)
        panel.chColorSwatch:SetAlpha(na)
      end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    end

    if LoadAddOn then pcall(LoadAddOn, "Blizzard_ColorPicker") end

    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = true,
        r = r, g = g, b = b,
        opacity = 1 - a,
        swatchFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          ApplyColor(nr, ng, nb, na)
        end,
        opacityFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          ApplyColor(nr, ng, nb, na)
        end,
        cancelFunc = function(previous)
          if previous then
            local na = (previous.opacity ~= nil) and (1 - previous.opacity) or a
            ApplyColor(previous.r or r, previous.g or g, previous.b or b, na)
          else
            ApplyColor(r, g, b, a)
          end
        end,
      })
    elseif ColorPickerFrame and type(ColorPickerFrame.SetColorRGB) == "function" then
      -- Fallback for older clients
      local function OnColorChanged()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
        local na = opacity or a
        ApplyColor(nr, ng, nb, na)
      end
      local function OnOpacityChanged()
        OnColorChanged()
      end
      local prev = { r = r, g = g, b = b, a = a }
      ColorPickerFrame.hasOpacity = true
      if ColorPickerFrame.SetColorAlpha then ColorPickerFrame:SetColorAlpha(a) end
      ColorPickerFrame:SetColorRGB(r, g, b)
      ColorPickerFrame.opacity = 1 - a
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnOpacityChanged
      ColorPickerFrame.cancelFunc = function()
        ApplyColor(prev.r, prev.g, prev.b, prev.a)
      end
      ColorPickerFrame:Show()
    else
      -- Color picker unavailable
    end
  end)

  -- Health Box options layout and bindings
  local hbCfgRead = EnsureCfgRead("healthbox")
  local hbCfgWrite = EnsureCfgWrite("healthbox")
  local hbW = (hbCfgRead and tonumber(hbCfgRead.width)) or 220
  local hbH = (hbCfgRead and tonumber(hbCfgRead.height)) or 22
  local hbMode = (hbCfgRead and hbCfgRead.infoMode) or "currentMaxPercent"
  local hbCH = (hbCfgRead and hbCfgRead.colorHealth) or { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
  local hbCM = (hbCfgRead and hbCfgRead.colorMissing) or { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }

  -- Section header under Crosshair section
  -- Separator before Health Box section
  panel.sepCH = panel.sepCH or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepCH:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepCH:SetVertexColor(1, 1, 1, 0.15)
  panel.sepCH:ClearAllPoints()
  panel.sepCH:SetPoint("TOPLEFT", panel.chColorLabel, "BOTTOMLEFT", 0, -12)
  panel.sepCH:SetPoint("TOPRIGHT", panel.chColorLabel, "BOTTOMRIGHT", -28, -12)
  panel.sepCH:SetHeight(1)
  panel.sepCH:Show()

  panel.hbHeader:ClearAllPoints()
  panel.hbHeader:SetPoint("TOPLEFT", panel.sepCH, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.hbHeader) end
  panel.hbHeader:Show()

  -- Width
  panel.hbWidthLabel:ClearAllPoints()
  panel.hbWidthLabel:SetPoint("TOPLEFT", panel.hbHeader, "BOTTOMLEFT", 0, -16)
  panel.hbWidthLabel:Show()

  panel.hbWidth:ClearAllPoints()
  panel.hbWidth:SetPoint("LEFT", panel.hbWidthLabel, "RIGHT", 8, 0)
  panel.hbWidth:SetMinMaxValues(50, 600)
  panel.hbWidth:SetValueStep(1)
  panel.hbWidth:SetObeyStepOnDrag(true)
  panel.hbWidth:SetValue(hbW)
  panel.hbWidth:Show()

  panel.hbWidthVal:ClearAllPoints()
  panel.hbWidthVal:SetPoint("LEFT", panel.hbWidth, "RIGHT", 12, 0)
  panel.hbWidthVal:SetText(string.format("%d px", hbW))
  panel.hbWidthVal:Show()

  panel.hbWidth:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 220)
    if hbCfgWrite then hbCfgWrite.width = val end
    panel.hbWidthVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Height
  panel.hbHeightLabel:ClearAllPoints()
  panel.hbHeightLabel:SetPoint("TOPLEFT", panel.hbWidthLabel, "BOTTOMLEFT", 0, -18)
  panel.hbHeightLabel:Show()

  panel.hbHeight:ClearAllPoints()
  panel.hbHeight:SetPoint("LEFT", panel.hbHeightLabel, "RIGHT", 8, 0)
  panel.hbHeight:SetMinMaxValues(6, 64)
  panel.hbHeight:SetValueStep(1)
  panel.hbHeight:SetObeyStepOnDrag(true)
  panel.hbHeight:SetValue(hbH)
  panel.hbHeight:Show()

  panel.hbHeightVal:ClearAllPoints()
  panel.hbHeightVal:SetPoint("LEFT", panel.hbHeight, "RIGHT", 12, 0)
  panel.hbHeightVal:SetText(string.format("%d px", hbH))
  panel.hbHeightVal:Show()

  panel.hbHeight:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 22)
    if hbCfgWrite then hbCfgWrite.height = val end
    panel.hbHeightVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Info mode dropdown
  panel.hbInfoLabel:ClearAllPoints()
  panel.hbInfoLabel:SetPoint("TOPLEFT", panel.hbHeightLabel, "BOTTOMLEFT", 0, -18)
  panel.hbInfoLabel:Show()

  panel.hbInfoDrop:ClearAllPoints()
  panel.hbInfoDrop:SetPoint("LEFT", panel.hbInfoLabel, "RIGHT", 8, 0)
  panel.hbInfoDrop:Show()
  local modes = {
    { key = "percent", label = "Percent (e.g. 75%)" },
    { key = "current", label = "Current (e.g. 12345)" },
    { key = "currentMax", label = "Current/Max (e.g. 12345/15000)" },
    { key = "currentMaxPercent", label = "Current/Max (%)" },
  }
  local selectedLabel = "Current/Max (%)"
  for _, m in ipairs(modes) do if m.key == hbMode then selectedLabel = m.label end end
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_Initialize(panel.hbInfoDrop, function(self, level)
      for _, m in ipairs(modes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = m.label
        info.checked = (m.key == hbMode)
        info.func = function()
          hbMode = m.key
          if hbCfgWrite then hbCfgWrite.infoMode = hbMode end
          UIDropDownMenu_SetText(panel.hbInfoDrop, m.label)
          if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetWidth(panel.hbInfoDrop, 200)
    UIDropDownMenu_SetText(panel.hbInfoDrop, selectedLabel)
  end

  -- Health color
  panel.hbHealthColorLabel:ClearAllPoints()
  panel.hbHealthColorLabel:SetPoint("TOPLEFT", panel.hbInfoLabel, "BOTTOMLEFT", 0, -16)
  panel.hbHealthColorLabel:Show()

  panel.hbHealthColorBtn:ClearAllPoints()
  panel.hbHealthColorBtn:SetPoint("LEFT", panel.hbHealthColorLabel, "RIGHT", 8, 0)
  panel.hbHealthColorBtn:Show()

  panel.hbHealthColorSwatch:ClearAllPoints()
  panel.hbHealthColorSwatch:SetPoint("LEFT", panel.hbHealthColorBtn, "RIGHT", 8, 0)
  if panel.hbHealthColorSwatch.SetColorTexture then
    panel.hbHealthColorSwatch:SetColorTexture(hbCH.r or 0.12, hbCH.g or 0.82, hbCH.b or 0.26, hbCH.a or 1)
  else
    panel.hbHealthColorSwatch:SetVertexColor(hbCH.r or 0.12, hbCH.g or 0.82, hbCH.b or 0.26, 1)
    panel.hbHealthColorSwatch:SetAlpha((hbCH.a ~= nil) and hbCH.a or 1)
  end
  panel.hbHealthColorSwatch:Show()

  panel.hbHealthColorBtn:SetScript("OnClick", function()
    local r, g, b = hbCH.r or 0.12, hbCH.g or 0.82, hbCH.b or 0.26
    local a = (hbCH.a ~= nil) and hbCH.a or 1
    local function Apply(nr, ng, nb, na)
      hbCH = { r = nr, g = ng, b = nb, a = na }
      if hbCfgWrite then hbCfgWrite.colorHealth = hbCH end
      if panel.hbHealthColorSwatch.SetColorTexture then
        panel.hbHealthColorSwatch:SetColorTexture(nr, ng, nb, na)
      else
        panel.hbHealthColorSwatch:SetVertexColor(nr, ng, nb, 1)
        panel.hbHealthColorSwatch:SetAlpha(na)
      end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    end
    if LoadAddOn then pcall(LoadAddOn, "Blizzard_ColorPicker") end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = true, r = r, g = g, b = b, opacity = 1 - a,
        swatchFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        opacityFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        cancelFunc = function(previous)
          if previous then
            local na = (previous.opacity ~= nil) and (1 - previous.opacity) or a
            Apply(previous.r or r, previous.g or g, previous.b or b, na)
          else
            Apply(r, g, b, a)
          end
        end,
      })
    elseif ColorPickerFrame and type(ColorPickerFrame.SetColorRGB) == "function" then
      local function OnColorChanged()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
        local na = opacity or a
        Apply(nr, ng, nb, na)
      end
      local function OnOpacityChanged() OnColorChanged() end
      local prev = { r = r, g = g, b = b, a = a }
      ColorPickerFrame.hasOpacity = true
      if ColorPickerFrame.SetColorAlpha then ColorPickerFrame:SetColorAlpha(a) end
      ColorPickerFrame:SetColorRGB(r, g, b)
      ColorPickerFrame.opacity = 1 - a
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnOpacityChanged
      ColorPickerFrame.cancelFunc = function() Apply(prev.r, prev.g, prev.b, prev.a) end
      ColorPickerFrame:Show()
    end
  end)

  -- Missing color
  panel.hbMissingColorLabel:ClearAllPoints()
  panel.hbMissingColorLabel:SetPoint("TOPLEFT", panel.hbHealthColorLabel, "BOTTOMLEFT", 0, -16)
  panel.hbMissingColorLabel:Show()

  panel.hbMissingColorBtn:ClearAllPoints()
  panel.hbMissingColorBtn:SetPoint("LEFT", panel.hbMissingColorLabel, "RIGHT", 8, 0)
  panel.hbMissingColorBtn:Show()

  panel.hbMissingColorSwatch:ClearAllPoints()
  panel.hbMissingColorSwatch:SetPoint("LEFT", panel.hbMissingColorBtn, "RIGHT", 8, 0)
  if panel.hbMissingColorSwatch.SetColorTexture then
    panel.hbMissingColorSwatch:SetColorTexture(hbCM.r or 0.15, hbCM.g or 0.15, hbCM.b or 0.15, hbCM.a or 0.85)
  else
    panel.hbMissingColorSwatch:SetVertexColor(hbCM.r or 0.15, hbCM.g or 0.15, hbCM.b or 0.15, 1)
    panel.hbMissingColorSwatch:SetAlpha((hbCM.a ~= nil) and hbCM.a or 0.85)
  end
  panel.hbMissingColorSwatch:Show()

  panel.hbMissingColorBtn:SetScript("OnClick", function()
    local r, g, b = hbCM.r or 0.15, hbCM.g or 0.15, hbCM.b or 0.15
    local a = (hbCM.a ~= nil) and hbCM.a or 0.85
    local function Apply(nr, ng, nb, na)
      hbCM = { r = nr, g = ng, b = nb, a = na }
      if hbCfgWrite then hbCfgWrite.colorMissing = hbCM end
      if panel.hbMissingColorSwatch.SetColorTexture then
        panel.hbMissingColorSwatch:SetColorTexture(nr, ng, nb, na)
      else
        panel.hbMissingColorSwatch:SetVertexColor(nr, ng, nb, 1)
        panel.hbMissingColorSwatch:SetAlpha(na)
      end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    end
    if LoadAddOn then pcall(LoadAddOn, "Blizzard_ColorPicker") end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = true, r = r, g = g, b = b, opacity = 1 - a,
        swatchFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        opacityFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        cancelFunc = function(previous)
          if previous then
            local na = (previous.opacity ~= nil) and (1 - previous.opacity) or a
            Apply(previous.r or r, previous.g or g, previous.b or b, na)
          else
            Apply(r, g, b, a)
          end
        end,
      })
    elseif ColorPickerFrame and type(ColorPickerFrame.SetColorRGB) == "function" then
      local function OnColorChanged()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
        local na = opacity or a
        Apply(nr, ng, nb, na)
      end
      local function OnOpacityChanged() OnColorChanged() end
      local prev = { r = r, g = g, b = b, a = a }
      ColorPickerFrame.hasOpacity = true
      if ColorPickerFrame.SetColorAlpha then ColorPickerFrame:SetColorAlpha(a) end
      ColorPickerFrame:SetColorRGB(r, g, b)
      ColorPickerFrame.opacity = 1 - a
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnOpacityChanged
      ColorPickerFrame.cancelFunc = function() Apply(prev.r, prev.g, prev.b, prev.a) end
      ColorPickerFrame:Show()
    end
  end)

  -- Health Box: Use class color layout and behavior
  local useClass = (hbCfg and hbCfg.useClassColor) or false
  panel.hbUseClassCB:ClearAllPoints()
  panel.hbUseClassCB:SetPoint("TOPLEFT", panel.hbMissingColorLabel, "BOTTOMLEFT", 0, -16)
  panel.hbUseClassCB:SetChecked(useClass)
  panel.hbUseClassCB:Show()
  panel.hbUseClassCB:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if hbCfgWrite then hbCfgWrite.useClassColor = v end
    -- Optionally disable custom health color controls when using class color
    if panel.hbHealthColorBtn and panel.hbHealthColorBtn.Enable then panel.hbHealthColorBtn:SetEnabled(not v) end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)
  -- reflect current enabled state for color button
  if panel.hbHealthColorBtn and panel.hbHealthColorBtn.Enable then panel.hbHealthColorBtn:SetEnabled(not useClass) end

  -- Health Box: Font dropdown
  panel.hbFontLabel:ClearAllPoints()
  panel.hbFontLabel:SetPoint("TOPLEFT", panel.hbUseClassCB, "BOTTOMLEFT", 0, -16)
  panel.hbFontLabel:Show()

  panel.hbFontDrop:ClearAllPoints()
  panel.hbFontDrop:SetPoint("LEFT", panel.hbFontLabel, "RIGHT", 8, 0)
  panel.hbFontDrop:Show()
  local fontOptions = BuildFontOptions()
  local currentFont = (hbCfg and hbCfg.font) or "Fonts\\FRIZQT__.TTF"
  local currentFontLabel = "Friz Quadrata"
  for _, it in ipairs(fontOptions) do if it.file == currentFont then currentFontLabel = it.label end end
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_Initialize(panel.hbFontDrop, function(self, level)
      for _, it in ipairs(fontOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = it.label
        info.checked = (it.file == currentFont)
        info.func = function()
          currentFont = it.file
          if hbCfgWrite then hbCfgWrite.font = currentFont end
          UIDropDownMenu_SetText(panel.hbFontDrop, it.label)
          if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetWidth(panel.hbFontDrop, 200)
    UIDropDownMenu_SetText(panel.hbFontDrop, currentFontLabel)
  end

  -- Font Size slider
  panel.hbFontSizeLabel:ClearAllPoints()
  panel.hbFontSizeLabel:SetPoint("TOPLEFT", panel.hbFontLabel, "BOTTOMLEFT", 0, -16)
  panel.hbFontSizeLabel:Show()

  panel.hbFontSize:ClearAllPoints()
  panel.hbFontSize:SetPoint("LEFT", panel.hbFontSizeLabel, "RIGHT", 8, 0)
  panel.hbFontSize:SetMinMaxValues(6, 64)
  panel.hbFontSize:SetValueStep(1)
  panel.hbFontSize:SetObeyStepOnDrag(true)
  local initialFontSize = (hbCfg and tonumber(hbCfg.fontSize)) or math.max(6, hbH - 4)
  panel.hbFontSize:SetValue(initialFontSize)
  panel.hbFontSize:Show()

  panel.hbFontSizeVal:ClearAllPoints()
  panel.hbFontSizeVal:SetPoint("LEFT", panel.hbFontSize, "RIGHT", 12, 0)
  panel.hbFontSizeVal:SetText(string.format("%d px", initialFontSize))
  panel.hbFontSizeVal:Show()

  panel.hbFontSize:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 12)
    if hbCfgWrite then hbCfgWrite.fontSize = val end
    panel.hbFontSizeVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Health Box: Border size
  panel.hbBorderLabel = panel.hbBorderLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.hbBorderLabel:SetText("Border Size")

  panel.hbBorder = panel.hbBorder or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.hbBorder:SetMinMaxValues(0, 32)
  panel.hbBorder:SetValueStep(1)
  panel.hbBorder:SetObeyStepOnDrag(true)

  panel.hbBorderVal = panel.hbBorderVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.hbBorderLabel:ClearAllPoints()
  panel.hbBorderLabel:SetPoint("TOPLEFT", panel.hbFontSizeLabel, "BOTTOMLEFT", 0, -16)
  panel.hbBorderLabel:Show()

  panel.hbBorder:ClearAllPoints()
  panel.hbBorder:SetPoint("LEFT", panel.hbBorderLabel, "RIGHT", 8, 0)
  local hbInitialBorder = (hbCfg and tonumber(hbCfg.borderSize)) or 1
  panel.hbBorder:SetValue(hbInitialBorder)
  panel.hbBorder:Show()

  panel.hbBorderVal:ClearAllPoints()
  panel.hbBorderVal:SetPoint("LEFT", panel.hbBorder, "RIGHT", 12, 0)
  panel.hbBorderVal:SetText(string.format("%d px", hbInitialBorder))
  panel.hbBorderVal:Show()

  panel.hbBorder:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 1)
    if hbCfgWrite then hbCfgWrite.borderSize = val end
    panel.hbBorderVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Target Box options layout and bindings
  local tbCfgRead = EnsureCfgRead("targetbox")
  local tbCfgWrite = EnsureCfgWrite("targetbox")
  local tbW = (tbCfgRead and tonumber(tbCfgRead.width)) or 220
  local tbH = (tbCfgRead and tonumber(tbCfgRead.height)) or 22
  local tbMode = (tbCfgRead and tbCfgRead.infoMode) or "currentMaxPercent"
  local tbCH = (tbCfgRead and tbCfgRead.colorHealth) or { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
  local tbCM = (tbCfgRead and tbCfgRead.colorMissing) or { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }
  local tbUseClass = (tbCfgRead and tbCfgRead.useClassColor) or false
  local tbFont = (tbCfgRead and tbCfgRead.font) or "Fonts\\FRIZQT__.TTF"
  local tbFontSize = (tbCfgRead and tonumber(tbCfgRead.fontSize)) or math.max(6, tbH - 4)

  -- Create Target Box UI elements once
  panel.tbHeader = panel.tbHeader or panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  panel.tbHeader:SetText("Target Box")

  panel.tbWidthLabel = panel.tbWidthLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.tbWidthLabel:SetText("Width")
  panel.tbWidth = panel.tbWidth or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.tbWidth:SetMinMaxValues(50, 600)
  panel.tbWidth:SetValueStep(1)
  panel.tbWidth:SetObeyStepOnDrag(true)
  panel.tbWidthVal = panel.tbWidthVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.tbHeightLabel = panel.tbHeightLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.tbHeightLabel:SetText("Height")
  panel.tbHeight = panel.tbHeight or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.tbHeight:SetMinMaxValues(6, 64)
  panel.tbHeight:SetValueStep(1)
  panel.tbHeight:SetObeyStepOnDrag(true)
  panel.tbHeightVal = panel.tbHeightVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.tbInfoLabel = panel.tbInfoLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.tbInfoLabel:SetText("Info Mode")
  panel.tbInfoDrop = panel.tbInfoDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

  panel.tbHealthColorLabel = panel.tbHealthColorLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.tbHealthColorLabel:SetText("Health Color")
  panel.tbHealthColorBtn = panel.tbHealthColorBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
  panel.tbHealthColorBtn:SetText("Pick"); panel.tbHealthColorBtn:SetWidth(80)
  panel.tbHealthColorSwatch = panel.tbHealthColorSwatch or panel.content:CreateTexture(nil, "ARTWORK")
  panel.tbHealthColorSwatch:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.tbHealthColorSwatch:SetSize(16, 16)

  panel.tbMissingColorLabel = panel.tbMissingColorLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.tbMissingColorLabel:SetText("Missing Color")
  panel.tbMissingColorBtn = panel.tbMissingColorBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
  panel.tbMissingColorBtn:SetText("Pick"); panel.tbMissingColorBtn:SetWidth(80)
  panel.tbMissingColorSwatch = panel.tbMissingColorSwatch or panel.content:CreateTexture(nil, "ARTWORK")
  panel.tbMissingColorSwatch:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.tbMissingColorSwatch:SetSize(16, 16)

  panel.tbUseClassCB = panel.tbUseClassCB or CreateCheckbox(panel.content, "Use class color for Health")

  panel.tbFontLabel = panel.tbFontLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.tbFontLabel:SetText("Font")
  panel.tbFontDrop = panel.tbFontDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

  panel.tbFontSizeLabel = panel.tbFontSizeLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.tbFontSizeLabel:SetText("Font Size")
  panel.tbFontSize = panel.tbFontSize or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.tbFontSize:SetMinMaxValues(6, 64)
  panel.tbFontSize:SetValueStep(1)
  panel.tbFontSize:SetObeyStepOnDrag(true)
  panel.tbFontSizeVal = panel.tbFontSizeVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  -- Layout under Health Box font size block
  -- Separator before Target Box section
  panel.sepHB = panel.sepHB or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepHB:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepHB:SetVertexColor(1, 1, 1, 0.15)
  panel.sepHB:ClearAllPoints()
  local hbAnchor = panel.hbBorderLabel or panel.hbFontSizeLabel or panel.hbHealthColorLabel
  panel.sepHB:SetPoint("TOPLEFT", hbAnchor, "BOTTOMLEFT", 0, -12)
  panel.sepHB:SetPoint("TOPRIGHT", hbAnchor, "BOTTOMRIGHT", -28, -12)
  panel.sepHB:SetHeight(1)
  panel.sepHB:Show()

  panel.tbHeader:ClearAllPoints()
  panel.tbHeader:SetPoint("TOPLEFT", panel.sepHB, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.tbHeader) end
  panel.tbHeader:Show()

  -- Width
  panel.tbWidthLabel:ClearAllPoints()
  panel.tbWidthLabel:SetPoint("TOPLEFT", panel.tbHeader, "BOTTOMLEFT", 0, -16)
  panel.tbWidthLabel:Show()

  panel.tbWidth:ClearAllPoints()
  panel.tbWidth:SetPoint("LEFT", panel.tbWidthLabel, "RIGHT", 8, 0)
  panel.tbWidth:SetValue(tbW)
  panel.tbWidth:Show()

  panel.tbWidthVal:ClearAllPoints()
  panel.tbWidthVal:SetPoint("LEFT", panel.tbWidth, "RIGHT", 12, 0)
  panel.tbWidthVal:SetText(string.format("%d px", tbW))
  panel.tbWidthVal:Show()

  panel.tbWidth:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 220)
    if tbCfgWrite then tbCfgWrite.width = val end
    panel.tbWidthVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Height
  panel.tbHeightLabel:ClearAllPoints()
  panel.tbHeightLabel:SetPoint("TOPLEFT", panel.tbWidthLabel, "BOTTOMLEFT", 0, -18)
  panel.tbHeightLabel:Show()

  panel.tbHeight:ClearAllPoints()
  panel.tbHeight:SetPoint("LEFT", panel.tbHeightLabel, "RIGHT", 8, 0)
  panel.tbHeight:SetValue(tbH)
  panel.tbHeight:Show()

  panel.tbHeightVal:ClearAllPoints()
  panel.tbHeightVal:SetPoint("LEFT", panel.tbHeight, "RIGHT", 12, 0)
  panel.tbHeightVal:SetText(string.format("%d px", tbH))
  panel.tbHeightVal:Show()

  panel.tbHeight:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 22)
    if tbCfgWrite then tbCfgWrite.height = val end
    panel.tbHeightVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Info mode
  panel.tbInfoLabel:ClearAllPoints()
  panel.tbInfoLabel:SetPoint("TOPLEFT", panel.tbHeightLabel, "BOTTOMLEFT", 0, -18)
  panel.tbInfoLabel:Show()

  panel.tbInfoDrop:ClearAllPoints()
  panel.tbInfoDrop:SetPoint("LEFT", panel.tbInfoLabel, "RIGHT", 8, 0)
  panel.tbInfoDrop:Show()
  local tbModes = {
    { key = "percent", label = "Percent (e.g. 75%)" },
    { key = "current", label = "Current (e.g. 12345)" },
    { key = "currentMax", label = "Current/Max (e.g. 12345/15000)" },
    { key = "currentMaxPercent", label = "Current/Max (%)" },
  }
  local tbSelectedLabel = "Current/Max (%)"
  for _, m in ipairs(tbModes) do if m.key == tbMode then tbSelectedLabel = m.label end end
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_Initialize(panel.tbInfoDrop, function(self, level)
      for _, m in ipairs(tbModes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = m.label
        info.checked = (m.key == tbMode)
        info.func = function()
          tbMode = m.key
          if tbCfgWrite then tbCfgWrite.infoMode = tbMode end
          UIDropDownMenu_SetText(panel.tbInfoDrop, m.label)
          if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetWidth(panel.tbInfoDrop, 200)
    UIDropDownMenu_SetText(panel.tbInfoDrop, tbSelectedLabel)
  end

  -- Health color
  panel.tbHealthColorLabel:ClearAllPoints()
  panel.tbHealthColorLabel:SetPoint("TOPLEFT", panel.tbInfoLabel, "BOTTOMLEFT", 0, -16)
  panel.tbHealthColorLabel:Show()

  panel.tbHealthColorBtn:ClearAllPoints()
  panel.tbHealthColorBtn:SetPoint("LEFT", panel.tbHealthColorLabel, "RIGHT", 8, 0)
  panel.tbHealthColorBtn:Show()

  panel.tbHealthColorSwatch:ClearAllPoints()
  panel.tbHealthColorSwatch:SetPoint("LEFT", panel.tbHealthColorBtn, "RIGHT", 8, 0)
  if panel.tbHealthColorSwatch.SetColorTexture then
    panel.tbHealthColorSwatch:SetColorTexture(tbCH.r or 0.12, tbCH.g or 0.82, tbCH.b or 0.26, tbCH.a or 1)
  else
    panel.tbHealthColorSwatch:SetVertexColor(tbCH.r or 0.12, tbCH.g or 0.82, tbCH.b or 0.26, 1)
    panel.tbHealthColorSwatch:SetAlpha((tbCH.a ~= nil) and tbCH.a or 1)
  end
  panel.tbHealthColorSwatch:Show()

  panel.tbHealthColorBtn:SetScript("OnClick", function()
    local r, g, b = tbCH.r or 0.12, tbCH.g or 0.82, tbCH.b or 0.26
    local a = (tbCH.a ~= nil) and tbCH.a or 1
    local function Apply(nr, ng, nb, na)
      tbCH = { r = nr, g = ng, b = nb, a = na }
      if tbCfgWrite then tbCfgWrite.colorHealth = tbCH end
      if panel.tbHealthColorSwatch.SetColorTexture then
        panel.tbHealthColorSwatch:SetColorTexture(nr, ng, nb, na)
      else
        panel.tbHealthColorSwatch:SetVertexColor(nr, ng, nb, 1)
        panel.tbHealthColorSwatch:SetAlpha(na)
      end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    end
    if LoadAddOn then pcall(LoadAddOn, "Blizzard_ColorPicker") end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = true, r = r, g = g, b = b, opacity = 1 - a,
        swatchFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        opacityFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        cancelFunc = function(previous)
          if previous then
            local na = (previous.opacity ~= nil) and (1 - previous.opacity) or a
            Apply(previous.r or r, previous.g or g, previous.b or b, na)
          else
            Apply(r, g, b, a)
          end
        end,
      })
    elseif ColorPickerFrame and type(ColorPickerFrame.SetColorRGB) == "function" then
      local function OnColorChanged()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
        local na = opacity or a
        Apply(nr, ng, nb, na)
      end
      local function OnOpacityChanged() OnColorChanged() end
      local prev = { r = r, g = g, b = b, a = a }
      ColorPickerFrame.hasOpacity = true
      if ColorPickerFrame.SetColorAlpha then ColorPickerFrame:SetColorAlpha(a) end
      ColorPickerFrame:SetColorRGB(r, g, b)
      ColorPickerFrame.opacity = 1 - a
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnOpacityChanged
      ColorPickerFrame.cancelFunc = function() Apply(prev.r, prev.g, prev.b, prev.a) end
      ColorPickerFrame:Show()
    end
  end)

  -- Missing color
  panel.tbMissingColorLabel:ClearAllPoints()
  panel.tbMissingColorLabel:SetPoint("TOPLEFT", panel.tbHealthColorLabel, "BOTTOMLEFT", 0, -16)
  panel.tbMissingColorLabel:Show()

  panel.tbMissingColorBtn:ClearAllPoints()
  panel.tbMissingColorBtn:SetPoint("LEFT", panel.tbMissingColorLabel, "RIGHT", 8, 0)
  panel.tbMissingColorBtn:Show()

  panel.tbMissingColorSwatch:ClearAllPoints()
  panel.tbMissingColorSwatch:SetPoint("LEFT", panel.tbMissingColorBtn, "RIGHT", 8, 0)
  if panel.tbMissingColorSwatch.SetColorTexture then
    panel.tbMissingColorSwatch:SetColorTexture(tbCM.r or 0.15, tbCM.g or 0.15, tbCM.b or 0.15, tbCM.a or 0.85)
  else
    panel.tbMissingColorSwatch:SetVertexColor(tbCM.r or 0.15, tbCM.g or 0.15, tbCM.b or 0.15, 1)
    panel.tbMissingColorSwatch:SetAlpha((tbCM.a ~= nil) and tbCM.a or 0.85)
  end
  panel.tbMissingColorSwatch:Show()

  panel.tbMissingColorBtn:SetScript("OnClick", function()
    local r, g, b = tbCM.r or 0.15, tbCM.g or 0.15, tbCM.b or 0.15
    local a = (tbCM.a ~= nil) and tbCM.a or 0.85
    local function Apply(nr, ng, nb, na)
      tbCM = { r = nr, g = ng, b = nb, a = na }
      if tbCfgWrite then tbCfgWrite.colorMissing = tbCM end
      if panel.tbMissingColorSwatch.SetColorTexture then
        panel.tbMissingColorSwatch:SetColorTexture(nr, ng, nb, na)
      else
        panel.tbMissingColorSwatch:SetVertexColor(nr, ng, nb, 1)
        panel.tbMissingColorSwatch:SetAlpha(na)
      end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    end
    if LoadAddOn then pcall(LoadAddOn, "Blizzard_ColorPicker") end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = true, r = r, g = g, b = b, opacity = 1 - a,
        swatchFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame.GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        opacityFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame.GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        cancelFunc = function(previous)
          if previous then
            local na = (previous.opacity ~= nil) and (1 - previous.opacity) or a
            Apply(previous.r or r, previous.g or g, previous.b or b, na)
          else
            Apply(r, g, b, a)
          end
        end,
      })
    elseif ColorPickerFrame and type(ColorPickerFrame.SetColorRGB) == "function" then
      local function OnColorChanged()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame.GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
        local na = opacity or a
        Apply(nr, ng, nb, na)
      end
      local function OnOpacityChanged() OnColorChanged() end
      local prev = { r = r, g = g, b = b, a = a }
      ColorPickerFrame.hasOpacity = true
      if ColorPickerFrame.SetColorAlpha then ColorPickerFrame:SetColorAlpha(a) end
      ColorPickerFrame:SetColorRGB(r, g, b)
      ColorPickerFrame.opacity = 1 - a
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnOpacityChanged
      ColorPickerFrame.cancelFunc = function() Apply(prev.r, prev.g, prev.b, prev.a) end
      ColorPickerFrame:Show()
    end
  end)

  -- Use class color
  panel.tbUseClassCB:ClearAllPoints()
  panel.tbUseClassCB:SetPoint("TOPLEFT", panel.tbMissingColorLabel, "BOTTOMLEFT", 0, -16)
  panel.tbUseClassCB:SetChecked(tbUseClass)
  panel.tbUseClassCB:Show()
  panel.tbUseClassCB:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if tbCfgWrite then tbCfgWrite.useClassColor = v end
    if panel.tbHealthColorBtn and panel.tbHealthColorBtn.Enable then panel.tbHealthColorBtn:SetEnabled(not v) end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)
  if panel.tbHealthColorBtn and panel.tbHealthColorBtn.Enable then panel.tbHealthColorBtn:SetEnabled(not tbUseClass) end

  -- Font dropdown
  panel.tbFontLabel:ClearAllPoints()
  panel.tbFontLabel:SetPoint("TOPLEFT", panel.tbUseClassCB, "BOTTOMLEFT", 0, -16)
  panel.tbFontLabel:Show()

  panel.tbFontDrop:ClearAllPoints()
  panel.tbFontDrop:SetPoint("LEFT", panel.tbFontLabel, "RIGHT", 8, 0)
  panel.tbFontDrop:Show()
  local tbFontOptions = BuildFontOptions()
  local tbCurrentFont = tbFont
  local tbCurrentFontLabel = "Friz Quadrata"
  for _, it in ipairs(tbFontOptions) do if it.file == tbCurrentFont then tbCurrentFontLabel = it.label end end
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_Initialize(panel.tbFontDrop, function(self, level)
      for _, it in ipairs(tbFontOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = it.label
        info.checked = (it.file == tbCurrentFont)
        info.func = function()
          tbCurrentFont = it.file
          if tbCfgWrite then tbCfgWrite.font = tbCurrentFont end
          UIDropDownMenu_SetText(panel.tbFontDrop, it.label)
          if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetWidth(panel.tbFontDrop, 200)
    UIDropDownMenu_SetText(panel.tbFontDrop, tbCurrentFontLabel)
  end

  -- Font size
  panel.tbFontSizeLabel:ClearAllPoints()
  panel.tbFontSizeLabel:SetPoint("TOPLEFT", panel.tbFontLabel, "BOTTOMLEFT", 0, -16)
  panel.tbFontSizeLabel:Show()

  panel.tbFontSize:ClearAllPoints()
  panel.tbFontSize:SetPoint("LEFT", panel.tbFontSizeLabel, "RIGHT", 8, 0)
  panel.tbFontSize:SetMinMaxValues(6, 64)
  panel.tbFontSize:SetValueStep(1)
  panel.tbFontSize:SetObeyStepOnDrag(true)
  panel.tbFontSize:SetValue(tbFontSize)
  panel.tbFontSize:Show()

  panel.tbFontSizeVal:ClearAllPoints()
  panel.tbFontSizeVal:SetPoint("LEFT", panel.tbFontSize, "RIGHT", 12, 0)
  panel.tbFontSizeVal:SetText(string.format("%d px", tbFontSize))
  panel.tbFontSizeVal:Show()

  panel.tbFontSize:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 12)
    if tbCfgWrite then tbCfgWrite.fontSize = val end
    panel.tbFontSizeVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Target Box: Border size
  panel.tbBorderLabel = panel.tbBorderLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.tbBorderLabel:SetText("Border Size")

  panel.tbBorder = panel.tbBorder or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.tbBorder:SetMinMaxValues(0, 32)
  panel.tbBorder:SetValueStep(1)
  panel.tbBorder:SetObeyStepOnDrag(true)

  panel.tbBorderVal = panel.tbBorderVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.tbBorderLabel:ClearAllPoints()
  panel.tbBorderLabel:SetPoint("TOPLEFT", panel.tbFontSizeLabel, "BOTTOMLEFT", 0, -16)
  panel.tbBorderLabel:Show()

  panel.tbBorder:ClearAllPoints()
  panel.tbBorder:SetPoint("LEFT", panel.tbBorderLabel, "RIGHT", 8, 0)
  local tbInitialBorder = (tbCfg and tonumber(tbCfg.borderSize)) or 1
  panel.tbBorder:SetValue(tbInitialBorder)
  panel.tbBorder:Show()

  panel.tbBorderVal:ClearAllPoints()
  panel.tbBorderVal:SetPoint("LEFT", panel.tbBorder, "RIGHT", 12, 0)
  panel.tbBorderVal:SetText(string.format("%d px", tbInitialBorder))
  panel.tbBorderVal:Show()

  panel.tbBorder:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 1)
    if tbCfgWrite then tbCfgWrite.borderSize = val end
    panel.tbBorderVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Pet Box options layout and bindings
  local pbCfgRead = EnsureCfgRead("petbox")
  local pbCfgWrite = EnsureCfgWrite("petbox")
  local pbW = (pbCfgRead and tonumber(pbCfgRead.width)) or 220
  local pbH = (pbCfgRead and tonumber(pbCfgRead.height)) or 22
  local pbMode = (pbCfgRead and pbCfgRead.infoMode) or "currentMaxPercent"
  local pbCH = (pbCfgRead and pbCfgRead.colorHealth) or { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
  local pbCM = (pbCfgRead and pbCfgRead.colorMissing) or { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }
  local pbUseClass = (pbCfgRead and pbCfgRead.useClassColor) or false
  local pbFont = (pbCfgRead and pbCfgRead.font) or "Fonts\\FRIZQT__.TTF"
  local pbFontSize = (pbCfgRead and tonumber(pbCfgRead.fontSize)) or math.max(6, pbH - 4)

  panel.pbHeader = panel.pbHeader or panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  panel.pbHeader:SetText("Pet Box")

  panel.pbWidthLabel = panel.pbWidthLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.pbWidthLabel:SetText("Width")
  panel.pbWidth = panel.pbWidth or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.pbWidth:SetMinMaxValues(50, 600)
  panel.pbWidth:SetValueStep(1)
  panel.pbWidth:SetObeyStepOnDrag(true)
  panel.pbWidthVal = panel.pbWidthVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.pbHeightLabel = panel.pbHeightLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.pbHeightLabel:SetText("Height")
  panel.pbHeight = panel.pbHeight or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.pbHeight:SetMinMaxValues(6, 64)
  panel.pbHeight:SetValueStep(1)
  panel.pbHeight:SetObeyStepOnDrag(true)
  panel.pbHeightVal = panel.pbHeightVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.pbInfoLabel = panel.pbInfoLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.pbInfoLabel:SetText("Info Mode")
  panel.pbInfoDrop = panel.pbInfoDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

  panel.pbHealthColorLabel = panel.pbHealthColorLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.pbHealthColorLabel:SetText("Health Color")
  panel.pbHealthColorBtn = panel.pbHealthColorBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
  panel.pbHealthColorBtn:SetText("Pick"); panel.pbHealthColorBtn:SetWidth(80)
  panel.pbHealthColorSwatch = panel.pbHealthColorSwatch or panel.content:CreateTexture(nil, "ARTWORK")
  panel.pbHealthColorSwatch:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.pbHealthColorSwatch:SetSize(16, 16)

  panel.pbMissingColorLabel = panel.pbMissingColorLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.pbMissingColorLabel:SetText("Missing Color")
  panel.pbMissingColorBtn = panel.pbMissingColorBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
  panel.pbMissingColorBtn:SetText("Pick"); panel.pbMissingColorBtn:SetWidth(80)
  panel.pbMissingColorSwatch = panel.pbMissingColorSwatch or panel.content:CreateTexture(nil, "ARTWORK")
  panel.pbMissingColorSwatch:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.pbMissingColorSwatch:SetSize(16, 16)

  panel.pbUseClassCB = panel.pbUseClassCB or CreateCheckbox(panel.content, "Use class color for Health")

  panel.pbFontLabel = panel.pbFontLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.pbFontLabel:SetText("Font")
  panel.pbFontDrop = panel.pbFontDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

  panel.pbFontSizeLabel = panel.pbFontSizeLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.pbFontSizeLabel:SetText("Font Size")
  panel.pbFontSize = panel.pbFontSize or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.pbFontSize:SetMinMaxValues(6, 64)
  panel.pbFontSize:SetValueStep(1)
  panel.pbFontSize:SetObeyStepOnDrag(true)
  panel.pbFontSizeVal = panel.pbFontSizeVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.pbBorderLabel = panel.pbBorderLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.pbBorderLabel:SetText("Border Size")
  panel.pbBorder = panel.pbBorder or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.pbBorder:SetMinMaxValues(0, 32)
  panel.pbBorder:SetValueStep(1)
  panel.pbBorder:SetObeyStepOnDrag(true)
  panel.pbBorderVal = panel.pbBorderVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  -- Layout under Target Box border size if available
  -- Separator before Pet Box section
  panel.sepTB = panel.sepTB or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepTB:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepTB:SetVertexColor(1, 1, 1, 0.15)
  panel.sepTB:ClearAllPoints()
  local tbAnchor = panel.tbBorderLabel or panel.tbFontSizeLabel or panel.hbBorderLabel or panel.hbFontSizeLabel
  panel.sepTB:SetPoint("TOPLEFT", tbAnchor, "BOTTOMLEFT", 0, -12)
  panel.sepTB:SetPoint("TOPRIGHT", tbAnchor, "BOTTOMRIGHT", -28, -12)
  panel.sepTB:SetHeight(1)
  panel.sepTB:Show()

  panel.pbHeader:ClearAllPoints()
  panel.pbHeader:SetPoint("TOPLEFT", panel.sepTB, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.pbHeader) end
  panel.pbHeader:Show()

  -- Width
  panel.pbWidthLabel:ClearAllPoints()
  panel.pbWidthLabel:SetPoint("TOPLEFT", panel.pbHeader, "BOTTOMLEFT", 0, -16)
  panel.pbWidthLabel:Show()

  panel.pbWidth:ClearAllPoints()
  panel.pbWidth:SetPoint("LEFT", panel.pbWidthLabel, "RIGHT", 8, 0)
  panel.pbWidth:SetValue(pbW)
  panel.pbWidth:Show()

  panel.pbWidthVal:ClearAllPoints()
  panel.pbWidthVal:SetPoint("LEFT", panel.pbWidth, "RIGHT", 12, 0)
  panel.pbWidthVal:SetText(string.format("%d px", pbW))
  panel.pbWidthVal:Show()

  panel.pbWidth:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 220)
    if pbCfgWrite then pbCfgWrite.width = val end
    panel.pbWidthVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Height
  panel.pbHeightLabel:ClearAllPoints()
  panel.pbHeightLabel:SetPoint("TOPLEFT", panel.pbWidthLabel, "BOTTOMLEFT", 0, -18)
  panel.pbHeightLabel:Show()

  panel.pbHeight:ClearAllPoints()
  panel.pbHeight:SetPoint("LEFT", panel.pbHeightLabel, "RIGHT", 8, 0)
  panel.pbHeight:SetValue(pbH)
  panel.pbHeight:Show()

  panel.pbHeightVal:ClearAllPoints()
  panel.pbHeightVal:SetPoint("LEFT", panel.pbHeight, "RIGHT", 12, 0)
  panel.pbHeightVal:SetText(string.format("%d px", pbH))
  panel.pbHeightVal:Show()

  panel.pbHeight:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 22)
    if pbCfgWrite then pbCfgWrite.height = val end
    panel.pbHeightVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Info mode
  panel.pbInfoLabel:ClearAllPoints()
  panel.pbInfoLabel:SetPoint("TOPLEFT", panel.pbHeightLabel, "BOTTOMLEFT", 0, -18)
  panel.pbInfoLabel:Show()

  panel.pbInfoDrop:ClearAllPoints()
  panel.pbInfoDrop:SetPoint("LEFT", panel.pbInfoLabel, "RIGHT", 8, 0)
  panel.pbInfoDrop:Show()
  local pbModes = {
    { key = "percent", label = "Percent (e.g. 75%)" },
    { key = "current", label = "Current (e.g. 12345)" },
    { key = "currentMax", label = "Current/Max (e.g. 12345/15000)" },
    { key = "currentMaxPercent", label = "Current/Max (%)" },
  }
  local pbSelectedLabel = "Current/Max (%)"
  for _, m in ipairs(pbModes) do if m.key == pbMode then pbSelectedLabel = m.label end end
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_Initialize(panel.pbInfoDrop, function(self, level)
      for _, m in ipairs(pbModes) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = m.label
        info.checked = (m.key == pbMode)
        info.func = function()
          pbMode = m.key
          if pbCfgWrite then pbCfgWrite.infoMode = pbMode end
          UIDropDownMenu_SetText(panel.pbInfoDrop, m.label)
          if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetWidth(panel.pbInfoDrop, 200)
    UIDropDownMenu_SetText(panel.pbInfoDrop, pbSelectedLabel)
  end

  -- Health color
  panel.pbHealthColorLabel:ClearAllPoints()
  panel.pbHealthColorLabel:SetPoint("TOPLEFT", panel.pbInfoLabel, "BOTTOMLEFT", 0, -16)
  panel.pbHealthColorLabel:Show()

  panel.pbHealthColorBtn:ClearAllPoints()
  panel.pbHealthColorBtn:SetPoint("LEFT", panel.pbHealthColorLabel, "RIGHT", 8, 0)
  panel.pbHealthColorBtn:Show()

  panel.pbHealthColorSwatch:ClearAllPoints()
  panel.pbHealthColorSwatch:SetPoint("LEFT", panel.pbHealthColorBtn, "RIGHT", 8, 0)
  if panel.pbHealthColorSwatch.SetColorTexture then
    panel.pbHealthColorSwatch:SetColorTexture(pbCH.r or 0.12, pbCH.g or 0.82, pbCH.b or 0.26, pbCH.a or 1)
  else
    panel.pbHealthColorSwatch:SetVertexColor(pbCH.r or 0.12, pbCH.g or 0.82, pbCH.b or 0.26, 1)
    panel.pbHealthColorSwatch:SetAlpha((pbCH.a ~= nil) and pbCH.a or 1)
  end
  panel.pbHealthColorSwatch:Show()

  panel.pbHealthColorBtn:SetScript("OnClick", function()
    local r, g, b = pbCH.r or 0.12, pbCH.g or 0.82, pbCH.b or 0.26
    local a = (pbCH.a ~= nil) and pbCH.a or 1
    local function Apply(nr, ng, nb, na)
      pbCH = { r = nr, g = ng, b = nb, a = na }
      if pbCfgWrite then pbCfgWrite.colorHealth = pbCH end
      if panel.pbHealthColorSwatch.SetColorTexture then
        panel.pbHealthColorSwatch:SetColorTexture(nr, ng, nb, na)
      else
        panel.pbHealthColorSwatch:SetVertexColor(nr, ng, nb, 1)
        panel.pbHealthColorSwatch:SetAlpha(na)
      end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    end
    if LoadAddOn then pcall(LoadAddOn, "Blizzard_ColorPicker") end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = true, r = r, g = g, b = b, opacity = 1 - a,
        swatchFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        opacityFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        cancelFunc = function(previous)
          if previous then
            local na = (previous.opacity ~= nil) and (1 - previous.opacity) or a
            Apply(previous.r or r, previous.g or g, previous.b or b, na)
          else
            Apply(r, g, b, a)
          end
        end,
      })
    end
  end)

  -- Missing color
  panel.pbMissingColorLabel:ClearAllPoints()
  panel.pbMissingColorLabel:SetPoint("TOPLEFT", panel.pbHealthColorLabel, "BOTTOMLEFT", 0, -16)
  panel.pbMissingColorLabel:Show()

  panel.pbMissingColorBtn:ClearAllPoints()
  panel.pbMissingColorBtn:SetPoint("LEFT", panel.pbMissingColorLabel, "RIGHT", 8, 0)
  panel.pbMissingColorBtn:Show()

  panel.pbMissingColorSwatch:ClearAllPoints()
  panel.pbMissingColorSwatch:SetPoint("LEFT", panel.pbMissingColorBtn, "RIGHT", 8, 0)
  if panel.pbMissingColorSwatch.SetColorTexture then
    panel.pbMissingColorSwatch:SetColorTexture(pbCM.r or 0.15, pbCM.g or 0.15, pbCM.b or 0.15, pbCM.a or 0.85)
  else
    panel.pbMissingColorSwatch:SetVertexColor(pbCM.r or 0.15, pbCM.g or 0.15, pbCM.b or 0.15, 1)
    panel.pbMissingColorSwatch:SetAlpha((pbCM.a ~= nil) and pbCM.a or 0.85)
  end
  panel.pbMissingColorSwatch:Show()

  panel.pbMissingColorBtn:SetScript("OnClick", function()
    local r, g, b = pbCM.r or 0.15, pbCM.g or 0.15, pbCM.b or 0.15
    local a = (pbCM.a ~= nil) and pbCM.a or 0.85
    local function Apply(nr, ng, nb, na)
      pbCM = { r = nr, g = ng, b = nb, a = na }
      if pbCfgWrite then pbCfgWrite.colorMissing = pbCM end
      if panel.pbMissingColorSwatch.SetColorTexture then
        panel.pbMissingColorSwatch:SetColorTexture(nr, ng, nb, na)
      else
        panel.pbMissingColorSwatch:SetVertexColor(nr, ng, nb, 1)
        panel.pbMissingColorSwatch:SetAlpha(na)
      end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    end
    if LoadAddOn then pcall(LoadAddOn, "Blizzard_ColorPicker") end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = true, r = r, g = g, b = b, opacity = 1 - a,
        swatchFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        opacityFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        cancelFunc = function(previous)
          if previous then
            local na = (previous.opacity ~= nil) and (1 - previous.opacity) or a
            Apply(previous.r or r, previous.g or g, previous.b or b, na)
          else
            Apply(r, g, b, a)
          end
        end,
      })
    end
  end)

  -- Use class color
  panel.pbUseClassCB:ClearAllPoints()
  panel.pbUseClassCB:SetPoint("TOPLEFT", panel.pbMissingColorLabel, "BOTTOMLEFT", 0, -16)
  panel.pbUseClassCB:SetChecked(pbUseClass)
  panel.pbUseClassCB:Show()
  panel.pbUseClassCB:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if pbCfgWrite then pbCfgWrite.useClassColor = v end
    if panel.pbHealthColorBtn and panel.pbHealthColorBtn.Enable then panel.pbHealthColorBtn:SetEnabled(not v) end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)
  if panel.pbHealthColorBtn and panel.pbHealthColorBtn.Enable then panel.pbHealthColorBtn:SetEnabled(not pbUseClass) end

  -- Font dropdown
  panel.pbFontLabel:ClearAllPoints()
  panel.pbFontLabel:SetPoint("TOPLEFT", panel.pbUseClassCB, "BOTTOMLEFT", 0, -16)
  panel.pbFontLabel:Show()

  panel.pbFontDrop:ClearAllPoints()
  panel.pbFontDrop:SetPoint("LEFT", panel.pbFontLabel, "RIGHT", 8, 0)
  panel.pbFontDrop:Show()
  local pbFontOptions = BuildFontOptions()
  local pbCurrentFont = pbFont
  local pbCurrentFontLabel = "Friz Quadrata"
  for _, it in ipairs(pbFontOptions) do if it.file == pbCurrentFont then pbCurrentFontLabel = it.label end end
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_Initialize(panel.pbFontDrop, function(self, level)
      for _, it in ipairs(pbFontOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = it.label
        info.checked = (it.file == pbCurrentFont)
        info.func = function()
          pbCurrentFont = it.file
          if pbCfgWrite then pbCfgWrite.font = pbCurrentFont end
          UIDropDownMenu_SetText(panel.pbFontDrop, it.label)
          if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetWidth(panel.pbFontDrop, 200)
    UIDropDownMenu_SetText(panel.pbFontDrop, pbCurrentFontLabel)
  end

  -- Font size
  panel.pbFontSizeLabel:ClearAllPoints()
  panel.pbFontSizeLabel:SetPoint("TOPLEFT", panel.pbFontLabel, "BOTTOMLEFT", 0, -16)
  panel.pbFontSizeLabel:Show()

  panel.pbFontSize:ClearAllPoints()
  panel.pbFontSize:SetPoint("LEFT", panel.pbFontSizeLabel, "RIGHT", 8, 0)
  panel.pbFontSize:SetMinMaxValues(6, 64)
  panel.pbFontSize:SetValueStep(1)
  panel.pbFontSize:SetObeyStepOnDrag(true)
  panel.pbFontSize:SetValue(pbFontSize)
  panel.pbFontSize:Show()

  panel.pbFontSizeVal:ClearAllPoints()
  panel.pbFontSizeVal:SetPoint("LEFT", panel.pbFontSize, "RIGHT", 12, 0)
  panel.pbFontSizeVal:SetText(string.format("%d px", pbFontSize))
  panel.pbFontSizeVal:Show()

  panel.pbFontSize:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 12)
    if pbCfgWrite then pbCfgWrite.fontSize = val end
    panel.pbFontSizeVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Border size
  panel.pbBorderLabel:ClearAllPoints()
  panel.pbBorderLabel:SetPoint("TOPLEFT", panel.pbFontSizeLabel, "BOTTOMLEFT", 0, -16)
  panel.pbBorderLabel:Show()

  panel.pbBorder:ClearAllPoints()
  panel.pbBorder:SetPoint("LEFT", panel.pbBorderLabel, "RIGHT", 8, 0)
  local pbInitialBorder = (pbCfg and tonumber(pbCfg.borderSize)) or 1
  panel.pbBorder:SetValue(pbInitialBorder)
  panel.pbBorder:Show()

  panel.pbBorderVal:ClearAllPoints()
  panel.pbBorderVal:SetPoint("LEFT", panel.pbBorder, "RIGHT", 12, 0)
  panel.pbBorderVal:SetText(string.format("%d px", pbInitialBorder))
  panel.pbBorderVal:Show()

  panel.pbBorder:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 1)
    if pbCfgWrite then pbCfgWrite.borderSize = val end
    panel.pbBorderVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Clock options layout and bindings
  local ckCfgRead = EnsureCfgRead("clock")
  local ckCfgWrite = EnsureCfgWrite("clock")
  local ckFont = (ckCfgRead and ckCfgRead.font) or "Fonts\\FRIZQT__.TTF"
  local ckSize = (ckCfgRead and tonumber(ckCfgRead.size or ckCfgRead.fontSize)) or 24
  local ckOutline = (ckCfgRead and ckCfgRead.outline) or (SkyInfoTilesDB and SkyInfoTilesDB.fontOutline) or "OUTLINE"
  local ckColor = (ckCfgRead and ckCfgRead.color) or { r = 1, g = 1, b = 1, a = 1 }

  panel.ckHeader = panel.ckHeader or panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  panel.ckHeader:SetText("24h Clock")

  panel.ckSizeLabel = panel.ckSizeLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.ckSizeLabel:SetText("Size")
  panel.ckSize = panel.ckSize or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.ckSize:SetMinMaxValues(6, 128)
  panel.ckSize:SetValueStep(1)
  panel.ckSize:SetObeyStepOnDrag(true)
  panel.ckSizeVal = panel.ckSizeVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

  panel.ckFontLabel = panel.ckFontLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.ckFontLabel:SetText("Font")
  panel.ckFontDrop = panel.ckFontDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

  panel.ckOutlineLabel = panel.ckOutlineLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.ckOutlineLabel:SetText("Outline")
  panel.ckOutlineDrop = panel.ckOutlineDrop or CreateFrame("Frame", nil, panel.content, "UIDropDownMenuTemplate")

  panel.ckColorLabel = panel.ckColorLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.ckColorLabel:SetText("Color")
  panel.ckColorBtn = panel.ckColorBtn or CreateFrame("Button", nil, panel.content, "UIPanelButtonTemplate")
  panel.ckColorBtn:SetText("Pick")
  panel.ckColorBtn:SetWidth(80)
  panel.ckColorSwatch = panel.ckColorSwatch or panel.content:CreateTexture(nil, "ARTWORK")
  panel.ckColorSwatch:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.ckColorSwatch:SetSize(16, 16)

  -- Layout: put Clock section below Pet Box
  -- Separator before Clock section
  panel.sepPB = panel.sepPB or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepPB:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepPB:SetVertexColor(1, 1, 1, 0.15)
  panel.sepPB:ClearAllPoints()
  local pbAnchor = panel.pbBorderLabel or panel.tbBorderLabel or panel.hbBorderLabel
  panel.sepPB:SetPoint("TOPLEFT", pbAnchor, "BOTTOMLEFT", 0, -12)
  panel.sepPB:SetPoint("TOPRIGHT", pbAnchor, "BOTTOMRIGHT", -28, -12)
  panel.sepPB:SetHeight(1)
  panel.sepPB:Show()

  panel.ckHeader:ClearAllPoints()
  panel.ckHeader:SetPoint("TOPLEFT", panel.sepPB, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.ckHeader) end
  panel.ckHeader:Show()

  -- Size
  panel.ckSizeLabel:ClearAllPoints()
  panel.ckSizeLabel:SetPoint("TOPLEFT", panel.ckHeader, "BOTTOMLEFT", 0, -16)
  panel.ckSizeLabel:Show()

  panel.ckSize:ClearAllPoints()
  panel.ckSize:SetPoint("LEFT", panel.ckSizeLabel, "RIGHT", 8, 0)
  SetSliderValueNoSignal(panel.ckSize, ckSize)
  panel.ckSize:Show()

  panel.ckSizeVal:ClearAllPoints()
  panel.ckSizeVal:SetPoint("LEFT", panel.ckSize, "RIGHT", 12, 0)
  panel.ckSizeVal:SetText(string.format("%d px", ckSize))
  panel.ckSizeVal:Show()

  panel.ckSize:SetScript("OnValueChanged", function(self, val)
    if self._setting then return end
    val = math.floor(tonumber(val) or 24)
    if ckCfgWrite then ckCfgWrite.size = val; ckCfgWrite.fontSize = val end
    panel.ckSizeVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Font dropdown
  panel.ckFontLabel:ClearAllPoints()
  panel.ckFontLabel:SetPoint("TOPLEFT", panel.ckSizeLabel, "BOTTOMLEFT", 0, -18)
  panel.ckFontLabel:Show()

  panel.ckFontDrop:ClearAllPoints()
  panel.ckFontDrop:SetPoint("LEFT", panel.ckFontLabel, "RIGHT", 8, 0)
  panel.ckFontDrop:Show()
  local ckFontOptions = BuildFontOptions()
  local ckFontLabel = "Friz Quadrata"
  for _, it in ipairs(ckFontOptions) do if it.file == ckFont then ckFontLabel = it.label end end
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_Initialize(panel.ckFontDrop, function(self, level)
      for _, it in ipairs(ckFontOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = it.label
        info.checked = (it.file == ckFont)
        info.func = function()
          ckFont = it.file
          if ckCfgWrite then ckCfgWrite.font = ckFont end
          UIDropDownMenu_SetText(panel.ckFontDrop, it.label)
          if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    UIDropDownMenu_SetWidth(panel.ckFontDrop, 200)
    UIDropDownMenu_SetText(panel.ckFontDrop, ckFontLabel)
  end

  -- Outline dropdown
  panel.ckOutlineLabel:ClearAllPoints()
  panel.ckOutlineLabel:SetPoint("TOPLEFT", panel.ckFontLabel, "BOTTOMLEFT", 0, -18)
  panel.ckOutlineLabel:Show()

  panel.ckOutlineDrop:ClearAllPoints()
  panel.ckOutlineDrop:SetPoint("LEFT", panel.ckOutlineLabel, "RIGHT", 8, 0)
  panel.ckOutlineDrop:Show()
  local outlineOptions = {
    { label = "None", value = "" },
    { label = "Outline", value = "OUTLINE" },
    { label = "Thick Outline", value = "THICKOUTLINE" },
  }
  local currentOutline = (ckOutline == "" or ckOutline == "NONE") and "" or ckOutline
  if UIDropDownMenu_Initialize then
    UIDropDownMenu_Initialize(panel.ckOutlineDrop, function(self, level)
      for _, it in ipairs(outlineOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = it.label
        info.checked = (it.value == currentOutline)
        info.func = function()
          currentOutline = it.value
          if ckCfgWrite then ckCfgWrite.outline = currentOutline end
          UIDropDownMenu_SetText(panel.ckOutlineDrop, it.label)
          if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
    local labelText = "Outline"
    for _, it in ipairs(outlineOptions) do if it.value == currentOutline then labelText = it.label end end
    UIDropDownMenu_SetWidth(panel.ckOutlineDrop, 160)
    UIDropDownMenu_SetText(panel.ckOutlineDrop, labelText)
  end

  -- Color picker
  panel.ckColorLabel:ClearAllPoints()
  panel.ckColorLabel:SetPoint("TOPLEFT", panel.ckOutlineLabel, "BOTTOMLEFT", 0, -18)
  panel.ckColorLabel:Show()

  panel.ckColorBtn:ClearAllPoints()
  panel.ckColorBtn:SetPoint("LEFT", panel.ckColorLabel, "RIGHT", 8, 0)
  panel.ckColorBtn:Show()

  panel.ckColorSwatch:ClearAllPoints()
  panel.ckColorSwatch:SetPoint("LEFT", panel.ckColorBtn, "RIGHT", 8, 0)
  if panel.ckColorSwatch.SetColorTexture then
    panel.ckColorSwatch:SetColorTexture(ckColor.r or 1, ckColor.g or 1, ckColor.b or 1, ckColor.a or 1)
  else
    panel.ckColorSwatch:SetVertexColor(ckColor.r or 1, ckColor.g or 1, ckColor.b or 1, 1)
    panel.ckColorSwatch:SetAlpha((ckColor.a ~= nil) and ckColor.a or 1)
  end
  panel.ckColorSwatch:Show()

  panel.ckColorBtn:SetScript("OnClick", function()
    local r, g, b = ckColor.r or 1, ckColor.g or 1, ckColor.b or 1
    local a = (ckColor.a ~= nil) and ckColor.a or 1
    local function Apply(nr, ng, nb, na)
      ckColor = { r = nr, g = ng, b = nb, a = na }
      if ckCfgWrite then ckCfgWrite.color = ckColor end
      if panel.ckColorSwatch.SetColorTexture then
        panel.ckColorSwatch:SetColorTexture(nr, ng, nb, na)
      else
        panel.ckColorSwatch:SetVertexColor(nr, ng, nb, 1)
        panel.ckColorSwatch:SetAlpha(na)
      end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    end
    if LoadAddOn then pcall(LoadAddOn, "Blizzard_ColorPicker") end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        hasOpacity = true, r = r, g = g, b = b, opacity = 1 - a,
        swatchFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        opacityFunc = function()
          local nr, ng, nb = ColorPickerFrame:GetColorRGB()
          local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
          local na = opacity or a
          Apply(nr, ng, nb, na)
        end,
        cancelFunc = function(previous)
          if previous then
            local na = (previous.opacity ~= nil) and (1 - previous.opacity) or a
            Apply(previous.r or r, previous.g or g, previous.b or b, na)
          else
            Apply(r, g, b, a)
          end
        end,
      })
    elseif ColorPickerFrame and type(ColorPickerFrame.SetColorRGB) == "function" then
      local function OnColorChanged()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local opacity = (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha()) or (1 - (ColorPickerFrame.opacity or 0))
        local na = opacity or a
        Apply(nr, ng, nb, na)
      end
      local function OnOpacityChanged() OnColorChanged() end
      local prev = { r = r, g = g, b = b, a = a }
      ColorPickerFrame.hasOpacity = true
      if ColorPickerFrame.SetColorAlpha then ColorPickerFrame:SetColorAlpha(a) end
      ColorPickerFrame:SetColorRGB(r, g, b)
      ColorPickerFrame.opacity = 1 - a
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnOpacityChanged
      ColorPickerFrame.cancelFunc = function() Apply(prev.r, prev.g, prev.b, prev.a) end
      ColorPickerFrame:Show()
    end
  end)

  -- Separator before Group Buffs section
  local gbCfgRead = EnsureCfgRead and EnsureCfgRead("groupbuffs") or nil
  local gbCfgWrite = EnsureCfgWrite and EnsureCfgWrite("groupbuffs") or nil
  local gbScale = (gbCfgRead and tonumber(gbCfgRead.scale)) or 1.0
  local gbPreview = (gbCfgRead and gbCfgRead.preview) and true or false
  local gbIcon = (gbCfgRead and tonumber(gbCfgRead.iconSize)) or 32
  local gbText = (gbCfgRead and tonumber(gbCfgRead.textSize)) or math.max(8, gbIcon - 6)

  panel.sepGB = panel.sepGB or panel.content:CreateTexture(nil, "ARTWORK")
  panel.sepGB:SetTexture("Interface\\Buttons\\WHITE8x8")
  panel.sepGB:SetVertexColor(1, 1, 1, 0.15)
  panel.sepGB:ClearAllPoints()
  panel.sepGB:SetPoint("TOPLEFT", panel.ckColorLabel or panel.ckHeader, "BOTTOMLEFT", 0, -12)
  panel.sepGB:SetPoint("TOPRIGHT", panel.ckColorLabel or panel.ckHeader, "BOTTOMRIGHT", -28, -12)
  panel.sepGB:SetHeight(1)
  panel.sepGB:Show()

  panel.gbHeader = panel.gbHeader or panel.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  panel.gbHeader:SetText("Group Buffs")
  panel.gbHeader:ClearAllPoints()
  panel.gbHeader:SetPoint("TOPLEFT", panel.sepGB, "BOTTOMLEFT", 0, -16)
  if BumpHeader then BumpHeader(panel.gbHeader) end
  panel.gbHeader:Show()

  -- Preview checkbox
  panel.gbPreviewCB = panel.gbPreviewCB or CreateCheckbox(panel.content, "Preview outside instances")
  panel.gbPreviewCB:ClearAllPoints()
  panel.gbPreviewCB:SetPoint("TOPLEFT", panel.gbHeader, "BOTTOMLEFT", 0, -12)
  panel.gbPreviewCB:SetChecked(gbPreview)
  panel.gbPreviewCB:Show()
  panel.gbPreviewCB:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if gbCfgWrite then gbCfgWrite.preview = v end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Scale slider (0.5 - 2.0)
  panel.gbScaleLabel = panel.gbScaleLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.gbScaleLabel:SetText("Scale")
  panel.gbScaleLabel:ClearAllPoints()
  panel.gbScaleLabel:SetPoint("TOPLEFT", panel.gbPreviewCB, "BOTTOMLEFT", 0, -16)
  panel.gbScaleLabel:Show()

  panel.gbScale = panel.gbScale or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.gbScale:SetMinMaxValues(0.5, 2.0)
  panel.gbScale:SetValueStep(0.05)
  panel.gbScale:SetObeyStepOnDrag(true)
  panel.gbScale:ClearAllPoints()
  panel.gbScale:SetPoint("LEFT", panel.gbScaleLabel, "RIGHT", 8, 0)
  if SetSliderValueNoSignal then
    SetSliderValueNoSignal(panel.gbScale, gbScale)
  else
    panel.gbScale:SetValue(gbScale)
  end
  panel.gbScale:Show()

  panel.gbScaleVal = panel.gbScaleVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  panel.gbScaleVal:ClearAllPoints()
  panel.gbScaleVal:SetPoint("LEFT", panel.gbScale, "RIGHT", 12, 0)
  panel.gbScaleVal:SetText(string.format("%.2fx", gbScale))
  panel.gbScaleVal:Show()

  panel.gbScale:SetScript("OnValueChanged", function(self, val)
    if self._setting then return end
    val = tonumber(val) or 1.0
    if val < 0.5 then val = 0.5 elseif val > 2.0 then val = 2.0 end
    if gbCfgWrite then gbCfgWrite.scale = val end
    panel.gbScaleVal:SetText(string.format("%.2fx", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Icon Size slider (16 - 64 px)
  panel.gbIconLabel = panel.gbIconLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.gbIconLabel:SetText("Icon Size")
  panel.gbIconLabel:ClearAllPoints()
  panel.gbIconLabel:SetPoint("TOPLEFT", panel.gbScaleLabel, "BOTTOMLEFT", 0, -16)
  panel.gbIconLabel:Show()

  panel.gbIcon = panel.gbIcon or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.gbIcon:SetMinMaxValues(16, 64)
  panel.gbIcon:SetValueStep(1)
  panel.gbIcon:SetObeyStepOnDrag(true)
  panel.gbIcon:ClearAllPoints()
  panel.gbIcon:SetPoint("LEFT", panel.gbIconLabel, "RIGHT", 8, 0)
  if SetSliderValueNoSignal then SetSliderValueNoSignal(panel.gbIcon, gbIcon) else panel.gbIcon:SetValue(gbIcon) end
  panel.gbIcon:Show()

  panel.gbIconVal = panel.gbIconVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  panel.gbIconVal:ClearAllPoints()
  panel.gbIconVal:SetPoint("LEFT", panel.gbIcon, "RIGHT", 12, 0)
  panel.gbIconVal:SetText(string.format("%d px", gbIcon))
  panel.gbIconVal:Show()

  panel.gbIcon:SetScript("OnValueChanged", function(self, val)
    if self._setting then return end
    val = math.floor(tonumber(val) or 32)
    if gbCfgWrite then gbCfgWrite.iconSize = val end
    panel.gbIconVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Overlay Text Size slider (8 - 48 px)
  panel.gbTextLabel = panel.gbTextLabel or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.gbTextLabel:SetText("Overlay Text Size")
  panel.gbTextLabel:ClearAllPoints()
  panel.gbTextLabel:SetPoint("TOPLEFT", panel.gbIconLabel, "BOTTOMLEFT", 0, -16)
  panel.gbTextLabel:Show()

  panel.gbText = panel.gbText or CreateFrame("Slider", nil, panel.content, "OptionsSliderTemplate")
  panel.gbText:SetMinMaxValues(8, 48)
  panel.gbText:SetValueStep(1)
  panel.gbText:SetObeyStepOnDrag(true)
  panel.gbText:ClearAllPoints()
  panel.gbText:SetPoint("LEFT", panel.gbTextLabel, "RIGHT", 8, 0)
  if SetSliderValueNoSignal then SetSliderValueNoSignal(panel.gbText, gbText) else panel.gbText:SetValue(gbText) end
  panel.gbText:Show()

  panel.gbTextVal = panel.gbTextVal or panel.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  panel.gbTextVal:ClearAllPoints()
  panel.gbTextVal:SetPoint("LEFT", panel.gbText, "RIGHT", 12, 0)
  panel.gbTextVal:SetText(string.format("%d px", gbText))
  panel.gbTextVal:Show()

  panel.gbText:SetScript("OnValueChanged", function(self, val)
    if self._setting then return end
    val = math.floor(tonumber(val) or 18)
    if gbCfgWrite then gbCfgWrite.textSize = val end
    panel.gbTextVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Hide any extra checkboxes if catalog shrank
  for i = #catalog + 1, #panel.tileCheckboxes do
    panel.tileCheckboxes[i]:Hide()
  end

  -- Hide UI scale and selected tile option sections to avoid confusion
  local function _Hide(o) if o and o.Hide then o:Hide() end end
  -- UI scale
  _Hide(panel.uiScaleHeader); _Hide(panel.uiScaleUseCB); _Hide(panel.uiScaleLabel); _Hide(panel.uiScaleEdit); _Hide(panel.uiScaleHint); _Hide(panel.sepUiScale)
  -- Health Box
  _Hide(panel.sepCH); _Hide(panel.hbHeader);
  _Hide(panel.hbWidthLabel); _Hide(panel.hbWidth); _Hide(panel.hbWidthVal);
  _Hide(panel.hbHeightLabel); _Hide(panel.hbHeight); _Hide(panel.hbHeightVal);
  _Hide(panel.hbInfoLabel); _Hide(panel.hbInfoDrop);
  _Hide(panel.hbHealthColorLabel); _Hide(panel.hbHealthColorBtn); _Hide(panel.hbHealthColorSwatch);
  _Hide(panel.hbMissingColorLabel); _Hide(panel.hbMissingColorBtn); _Hide(panel.hbMissingColorSwatch);
  _Hide(panel.hbUseClassCB);
  _Hide(panel.hbFontLabel); _Hide(panel.hbFontDrop);
  _Hide(panel.hbFontSizeLabel); _Hide(panel.hbFontSize); _Hide(panel.hbFontSizeVal);
  _Hide(panel.hbBorderLabel); _Hide(panel.hbBorder); _Hide(panel.hbBorderVal);
  -- Target Box
  _Hide(panel.sepHB); _Hide(panel.tbHeader);
  _Hide(panel.tbWidthLabel); _Hide(panel.tbWidth); _Hide(panel.tbWidthVal);
  _Hide(panel.tbHeightLabel); _Hide(panel.tbHeight); _Hide(panel.tbHeightVal);
  _Hide(panel.tbInfoLabel); _Hide(panel.tbInfoDrop);
  _Hide(panel.tbHealthColorLabel); _Hide(panel.tbHealthColorBtn); _Hide(panel.tbHealthColorSwatch);
  _Hide(panel.tbMissingColorLabel); _Hide(panel.tbMissingColorBtn); _Hide(panel.tbMissingColorSwatch);
  _Hide(panel.tbUseClassCB);
  _Hide(panel.tbFontLabel); _Hide(panel.tbFontDrop);
  _Hide(panel.tbFontSizeLabel); _Hide(panel.tbFontSize); _Hide(panel.tbFontSizeVal);
  _Hide(panel.tbBorderLabel); _Hide(panel.tbBorder); _Hide(panel.tbBorderVal);
  -- Pet Box
  _Hide(panel.sepTB); _Hide(panel.pbHeader);
  _Hide(panel.pbWidthLabel); _Hide(panel.pbWidth); _Hide(panel.pbWidthVal);
  _Hide(panel.pbHeightLabel); _Hide(panel.pbHeight); _Hide(panel.pbHeightVal);
  _Hide(panel.pbInfoLabel); _Hide(panel.pbInfoDrop);
  _Hide(panel.pbHealthColorLabel); _Hide(panel.pbHealthColorBtn); _Hide(panel.pbHealthColorSwatch);
  _Hide(panel.pbMissingColorLabel); _Hide(panel.pbMissingColorBtn); _Hide(panel.pbMissingColorSwatch);
  _Hide(panel.pbUseClassCB);
  _Hide(panel.pbFontLabel); _Hide(panel.pbFontDrop);
  _Hide(panel.pbFontSizeLabel); _Hide(panel.pbFontSize); _Hide(panel.pbFontSizeVal);
  _Hide(panel.pbBorderLabel); _Hide(panel.pbBorder); _Hide(panel.pbBorderVal);
  -- Group Buffs
  _Hide(panel.sepGB); _Hide(panel.gbHeader);
  _Hide(panel.gbPreviewCB);
  _Hide(panel.gbScaleLabel); _Hide(panel.gbScale); _Hide(panel.gbScaleVal);
  _Hide(panel.gbIconLabel); _Hide(panel.gbIcon); _Hide(panel.gbIconVal);
  _Hide(panel.gbTextLabel); _Hide(panel.gbText); _Hide(panel.gbTextVal);

  if panel.scroll and panel.scroll.UpdateScrollChildRect then
    panel.scroll:UpdateScrollChildRect()
  end
end

-- Allow core to call refresh after changes
SkyInfoTiles._OptionsRefresh = RefreshList

panel:SetScript("OnShow", function() RefreshList() end)

-- Register in Settings / Interface Options
do
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "SkyInfoTiles")
    category.ID = "SkyInfoTiles"
    Settings.RegisterAddOnCategory(category)
    SkyInfoTiles.OpenOptions = function()
      if Settings and Settings.OpenToCategory then Settings.OpenToCategory(category.ID) end
    end
  else
    panel.name = "SkyInfoTiles"
    if InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
    SkyInfoTiles.OpenOptions = function()
      if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel); InterfaceOptionsFrame_OpenToCategory(panel)
      end
    end
  end
end
