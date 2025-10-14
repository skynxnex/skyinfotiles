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

-- Header
panel.listHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
panel.listHeader:SetParent(panel.content)
panel.listHeader:SetPoint("TOPLEFT", panel.lockCB, "BOTTOMLEFT", 0, -16)
panel.listHeader:SetText("Tiles (enable/disable):")

-- One checkbox per catalog entry
panel.tileCheckboxes = {}

-- DungeonPorts orientation controls
local function SetDungeonPortsOrientation(orient)
  local cfg = SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg and SkyInfoTiles.GetOrCreateTileCfg("dungeonports")
  if not cfg then return end
  cfg.orientation = orient
  if SkyInfoTiles and SkyInfoTiles.Rebuild then SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll() end
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
  if SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg then
    return SkyInfoTiles.GetOrCreateTileCfg("charstats")
  end
  return nil
end

local function EnsureCrosshairCfg()
  if SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg then
    return SkyInfoTiles.GetOrCreateTileCfg("crosshair")
  end
  return nil
end

local function EnsureHealthBoxCfg()
  if SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg then
    return SkyInfoTiles.GetOrCreateTileCfg("healthbox")
  end
  return nil
end

local function EnsureTargetBoxCfg()
  if SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg then
    return SkyInfoTiles.GetOrCreateTileCfg("targetbox")
  end
  return nil
end

local function EnsurePetBoxCfg()
  if SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg then
    return SkyInfoTiles.GetOrCreateTileCfg("petbox")
  end
  return nil
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
    if i == 1 then
      cb:SetPoint("TOPLEFT", panel.listHeader, "BOTTOMLEFT", 0, -8)
    else
      cb:SetPoint("TOPLEFT", panel.tileCheckboxes[i - 1], "BOTTOMLEFT", 0, -6)
    end
    panel.tileCheckboxes[i] = cb
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
  panel.specHeader:ClearAllPoints()
  panel.specHeader:SetPoint("TOPLEFT", panel.profButtonsRow, "BOTTOMLEFT", 0, -12)
  panel.specHeader:Show()
  panel.specToggle:ClearAllPoints()
  panel.specToggle:SetPoint("LEFT", panel.specHeader, "RIGHT", 8, 0)
  panel.specToggle:SetText(panel._specExpanded and "Hide" or "Show")
  panel.specToggle:Show()
  panel.specToggle:SetScript("OnClick", function()
    panel._specExpanded = not panel._specExpanded
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)


  local lastFrame = panel.specHeader
  local count = 0
  if panel._specExpanded and type(GetNumSpecializations)=="function" and type(GetSpecializationInfo)=="function" then
    local n = GetNumSpecializations() or 0
    for i = 1, n do
      local id, specName = GetSpecializationInfo(i)
      if id then
        count = count + 1
        local row = EnsureSpecRow(count)
        row.frame = row.frame or CreateFrame("Frame", nil, panel.content)
        row.frame:SetSize(640, 24)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, (lastFrame == panel.specHeader) and -8 or -6)
        row.frame:Show()

        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row.frame, "LEFT", COL1_X, 0)
        row.label:SetText(specName or ("Spec " .. i))
        row.label:Show()

        row.drop:ClearAllPoints()
        row.drop:SetPoint("LEFT", row.frame, "LEFT", COL2_X, 0)
        row.drop:Show()
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

        lastFrame = row.frame
      end
    end
  end

  if not panel._specExpanded then
    -- collapse: hide all rows
    for i = 1, #panel.specRows do
      local row = panel.specRows[i]
      if row then
        if row.label then row.label:Hide() end
        if row.drop then row.drop:Hide() end
        if row.frame then row.frame:Hide() end
      end
    end
    count = 0
    lastFrame = panel.specHeader
  end

  for i = count + 1, #panel.specRows do
    local row = panel.specRows[i]
    if row then
      if row.label then row.label:Hide() end
      if row.drop then row.drop:Hide() end
    end
  end

  -- Move the tiles list header below the profiles/spec section
  panel.listHeader:ClearAllPoints()
  panel.listHeader:SetPoint("TOPLEFT", (panel._specExpanded and (lastFrame or panel.profLabel) or panel.specHeader), "BOTTOMLEFT", 0, -16)

  -- Catalog entries
  local catalog = SkyInfoTiles.CATALOG or {}
  for i, cat in ipairs(catalog) do
    local cb = EnsureTileCheckbox(i)
    local label = string.format("[%s] %s", cat.key, cat.label or cat.type)
    local text = cb.Text or cb.text or cb._labelFS
    text:SetText(label)
    cb:SetChecked(SkyInfoTiles.GetTileEnabledByKey(cat.key))
    cb._tileKey = cat.key
    cb:SetScript("OnClick", function(self)
      SkyInfoTiles.SetTileEnabledByKey(self._tileKey, self:GetChecked())
    end)
  end

  -- Position Dungeon Teleports layout controls after the list
  local anchor = panel.listHeader
  if #catalog > 0 then
    anchor = panel.tileCheckboxes[#catalog]
  end
  panel.dpHeader:ClearAllPoints()
  panel.dpHeader:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
  panel.dpRadioH:ClearAllPoints()
  panel.dpRadioH:SetPoint("TOPLEFT", panel.dpHeader, "BOTTOMLEFT", 0, -8)
  panel.dpRadioV:ClearAllPoints()
  panel.dpRadioV:SetPoint("LEFT", panel.dpRadioH, "RIGHT", 60, 0)

  -- Reflect current orientation (default horizontal), using active profile
  local orient = "horizontal"
  local dpCfg = SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg and SkyInfoTiles.GetOrCreateTileCfg("dungeonports")
  if dpCfg and dpCfg.orientation then orient = dpCfg.orientation end
  panel.dpRadioH:SetChecked(orient ~= "vertical")
  panel.dpRadioV:SetChecked(orient == "vertical")
  panel.dpHeader:Show(); panel.dpRadioH:Show(); panel.dpRadioV:Show()

  -- Character Stats order UI
  local csCfg = EnsureCharStatsCfg()
  local order = {}
  local valid = {}
  for _, k in ipairs(CS_DEFAULT_ORDER) do valid[k] = true end
  if csCfg and type(csCfg.order) == "table" then
    for _, k in ipairs(csCfg.order) do
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

  -- Position header under Dungeon Ports controls
  panel.csHeader:ClearAllPoints()
  panel.csHeader:SetPoint("TOPLEFT", panel.dpRadioH, "BOTTOMLEFT", 0, -16)
  panel.csHeader:Show()

  -- Build rows
  local prevLabel = nil
  for i = 1, #CS_DEFAULT_ORDER do
    local row = EnsureCSRow(i)
    local key = order[i]
    local labelText = CS_FRIENDLY_NAMES[key] or tostring(key)

    row.label:ClearAllPoints()
    if i == 1 then
      row.label:SetPoint("TOPLEFT", panel.csHeader, "BOTTOMLEFT", 0, -8)
    else
      row.label:SetPoint("TOPLEFT", prevLabel, "BOTTOMLEFT", 0, -6)
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
    row.up:SetScript("OnClick", function()
      if i <= 1 then return end
      order[i], order[i-1] = order[i-1], order[i]
      local new = {}
      for j, k in ipairs(order) do new[j] = k end
      if csCfg then csCfg.order = new end
      if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
      if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
    end)
    row.down:SetScript("OnClick", function()
      if i >= #CS_DEFAULT_ORDER then return end
      order[i], order[i+1] = order[i+1], order[i]
      local new = {}
      for j, k in ipairs(order) do new[j] = k end
      if csCfg then csCfg.order = new end
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
    if csCfg then csCfg.order = nil end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
    if SkyInfoTiles and SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end)
  panel.csResetBtn:Show()

  -- Crosshair options layout and bindings
  local chCfg = EnsureCrosshairCfg()
  local size = (chCfg and tonumber(chCfg.size)) or 32
  local thick = (chCfg and tonumber(chCfg.thickness)) or 2
  local col = (chCfg and chCfg.color) or { r = 1, g = 0, b = 0, a = 0.9 }

  panel.chHeader:ClearAllPoints()
  panel.chHeader:SetPoint("TOPLEFT", panel.csResetBtn, "BOTTOMLEFT", 0, -16)
  panel.chHeader:Show()

  panel.chSizeLabel:ClearAllPoints()
  panel.chSizeLabel:SetPoint("TOPLEFT", panel.chHeader, "BOTTOMLEFT", 0, -8)
  panel.chSizeLabel:Show()

  panel.chSize:ClearAllPoints()
  panel.chSize:SetPoint("LEFT", panel.chSizeLabel, "RIGHT", 8, 0)
  panel.chSize:SetMinMaxValues(4, 512)
  panel.chSize:SetValueStep(1)
  panel.chSize:SetObeyStepOnDrag(true)
  panel.chSize:SetValue(size)
  panel.chSize:Show()

  panel.chSizeVal:ClearAllPoints()
  panel.chSizeVal:SetPoint("LEFT", panel.chSize, "RIGHT", 12, 0)
  panel.chSizeVal:SetText(string.format("%d px", size))
  panel.chSizeVal:Show()

  panel.chSize:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 32)
    if chCfg then chCfg.size = val end
    panel.chSizeVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Thickness controls
  panel.chThickLabel:ClearAllPoints()
  panel.chThickLabel:SetPoint("TOPLEFT", panel.chSizeLabel, "BOTTOMLEFT", 0, -12)
  panel.chThickLabel:Show()

  panel.chThick:ClearAllPoints()
  panel.chThick:SetPoint("LEFT", panel.chThickLabel, "RIGHT", 8, 0)
  panel.chThick:SetMinMaxValues(1, 64)
  panel.chThick:SetValueStep(1)
  panel.chThick:SetObeyStepOnDrag(true)
  panel.chThick:SetValue(thick)
  panel.chThick:Show()

  panel.chThickVal:ClearAllPoints()
  panel.chThickVal:SetPoint("LEFT", panel.chThick, "RIGHT", 12, 0)
  panel.chThickVal:SetText(string.format("%d px", thick))
  panel.chThickVal:Show()

  panel.chThick:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 2)
    if chCfg then chCfg.thickness = val end
    panel.chThickVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  panel.chColorLabel:ClearAllPoints()
  panel.chColorLabel:SetPoint("TOPLEFT", panel.chThickLabel, "BOTTOMLEFT", 0, -12)
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
      if chCfg then chCfg.color = col end
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
  local hbCfg = EnsureHealthBoxCfg()
  local hbW = (hbCfg and tonumber(hbCfg.width)) or 220
  local hbH = (hbCfg and tonumber(hbCfg.height)) or 22
  local hbMode = (hbCfg and hbCfg.infoMode) or "currentMaxPercent"
  local hbCH = (hbCfg and hbCfg.colorHealth) or { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
  local hbCM = (hbCfg and hbCfg.colorMissing) or { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }

  -- Section header under Crosshair section
  panel.hbHeader:ClearAllPoints()
  panel.hbHeader:SetPoint("TOPLEFT", panel.chColorLabel, "BOTTOMLEFT", 0, -20)
  panel.hbHeader:Show()

  -- Width
  panel.hbWidthLabel:ClearAllPoints()
  panel.hbWidthLabel:SetPoint("TOPLEFT", panel.hbHeader, "BOTTOMLEFT", 0, -8)
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
    if hbCfg then hbCfg.width = val end
    panel.hbWidthVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Height
  panel.hbHeightLabel:ClearAllPoints()
  panel.hbHeightLabel:SetPoint("TOPLEFT", panel.hbWidthLabel, "BOTTOMLEFT", 0, -12)
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
    if hbCfg then hbCfg.height = val end
    panel.hbHeightVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Info mode dropdown
  panel.hbInfoLabel:ClearAllPoints()
  panel.hbInfoLabel:SetPoint("TOPLEFT", panel.hbHeightLabel, "BOTTOMLEFT", 0, -12)
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
          if hbCfg then hbCfg.infoMode = hbMode end
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
  panel.hbHealthColorLabel:SetPoint("TOPLEFT", panel.hbInfoLabel, "BOTTOMLEFT", 0, -12)
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
      if hbCfg then hbCfg.colorHealth = hbCH end
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
  panel.hbMissingColorLabel:SetPoint("TOPLEFT", panel.hbHealthColorLabel, "BOTTOMLEFT", 0, -12)
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
      if hbCfg then hbCfg.colorMissing = hbCM end
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
  panel.hbUseClassCB:SetPoint("TOPLEFT", panel.hbMissingColorLabel, "BOTTOMLEFT", 0, -12)
  panel.hbUseClassCB:SetChecked(useClass)
  panel.hbUseClassCB:Show()
  panel.hbUseClassCB:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if hbCfg then hbCfg.useClassColor = v end
    -- Optionally disable custom health color controls when using class color
    if panel.hbHealthColorBtn and panel.hbHealthColorBtn.Enable then panel.hbHealthColorBtn:SetEnabled(not v) end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)
  -- reflect current enabled state for color button
  if panel.hbHealthColorBtn and panel.hbHealthColorBtn.Enable then panel.hbHealthColorBtn:SetEnabled(not useClass) end

  -- Health Box: Font dropdown
  panel.hbFontLabel:ClearAllPoints()
  panel.hbFontLabel:SetPoint("TOPLEFT", panel.hbUseClassCB, "BOTTOMLEFT", 0, -12)
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
          if hbCfg then hbCfg.font = currentFont end
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
  panel.hbFontSizeLabel:SetPoint("TOPLEFT", panel.hbFontLabel, "BOTTOMLEFT", 0, -12)
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
    if hbCfg then hbCfg.fontSize = val end
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
  panel.hbBorderLabel:SetPoint("TOPLEFT", panel.hbFontSizeLabel, "BOTTOMLEFT", 0, -12)
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
    if hbCfg then hbCfg.borderSize = val end
    panel.hbBorderVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Target Box options layout and bindings
  local tbCfg = EnsureTargetBoxCfg()
  local tbW = (tbCfg and tonumber(tbCfg.width)) or 220
  local tbH = (tbCfg and tonumber(tbCfg.height)) or 22
  local tbMode = (tbCfg and tbCfg.infoMode) or "currentMaxPercent"
  local tbCH = (tbCfg and tbCfg.colorHealth) or { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
  local tbCM = (tbCfg and tbCfg.colorMissing) or { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }
  local tbUseClass = (tbCfg and tbCfg.useClassColor) or false
  local tbFont = (tbCfg and tbCfg.font) or "Fonts\\FRIZQT__.TTF"
  local tbFontSize = (tbCfg and tonumber(tbCfg.fontSize)) or math.max(6, tbH - 4)

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
  panel.tbHeader:ClearAllPoints()
  panel.tbHeader:SetPoint("TOPLEFT", panel.hbFontSizeLabel or panel.hbHealthColorLabel, "BOTTOMLEFT", 0, -24)
  panel.tbHeader:Show()

  -- Width
  panel.tbWidthLabel:ClearAllPoints()
  panel.tbWidthLabel:SetPoint("TOPLEFT", panel.tbHeader, "BOTTOMLEFT", 0, -8)
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
    if tbCfg then tbCfg.width = val end
    panel.tbWidthVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Height
  panel.tbHeightLabel:ClearAllPoints()
  panel.tbHeightLabel:SetPoint("TOPLEFT", panel.tbWidthLabel, "BOTTOMLEFT", 0, -12)
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
    if tbCfg then tbCfg.height = val end
    panel.tbHeightVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Info mode
  panel.tbInfoLabel:ClearAllPoints()
  panel.tbInfoLabel:SetPoint("TOPLEFT", panel.tbHeightLabel, "BOTTOMLEFT", 0, -12)
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
          if tbCfg then tbCfg.infoMode = tbMode end
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
  panel.tbHealthColorLabel:SetPoint("TOPLEFT", panel.tbInfoLabel, "BOTTOMLEFT", 0, -12)
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
      if tbCfg then tbCfg.colorHealth = tbCH end
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
  panel.tbMissingColorLabel:SetPoint("TOPLEFT", panel.tbHealthColorLabel, "BOTTOMLEFT", 0, -12)
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
      if tbCfg then tbCfg.colorMissing = tbCM end
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
  panel.tbUseClassCB:SetPoint("TOPLEFT", panel.tbMissingColorLabel, "BOTTOMLEFT", 0, -12)
  panel.tbUseClassCB:SetChecked(tbUseClass)
  panel.tbUseClassCB:Show()
  panel.tbUseClassCB:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if tbCfg then tbCfg.useClassColor = v end
    if panel.tbHealthColorBtn and panel.tbHealthColorBtn.Enable then panel.tbHealthColorBtn:SetEnabled(not v) end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)
  if panel.tbHealthColorBtn and panel.tbHealthColorBtn.Enable then panel.tbHealthColorBtn:SetEnabled(not tbUseClass) end

  -- Font dropdown
  panel.tbFontLabel:ClearAllPoints()
  panel.tbFontLabel:SetPoint("TOPLEFT", panel.tbUseClassCB, "BOTTOMLEFT", 0, -12)
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
          if tbCfg then tbCfg.font = tbCurrentFont end
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
  panel.tbFontSizeLabel:SetPoint("TOPLEFT", panel.tbFontLabel, "BOTTOMLEFT", 0, -12)
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
    if tbCfg then tbCfg.fontSize = val end
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
  panel.tbBorderLabel:SetPoint("TOPLEFT", panel.tbFontSizeLabel, "BOTTOMLEFT", 0, -12)
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
    if tbCfg then tbCfg.borderSize = val end
    panel.tbBorderVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Pet Box options layout and bindings
  local pbCfg = EnsurePetBoxCfg()
  local pbW = (pbCfg and tonumber(pbCfg.width)) or 220
  local pbH = (pbCfg and tonumber(pbCfg.height)) or 22
  local pbMode = (pbCfg and pbCfg.infoMode) or "currentMaxPercent"
  local pbCH = (pbCfg and pbCfg.colorHealth) or { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
  local pbCM = (pbCfg and pbCfg.colorMissing) or { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }
  local pbUseClass = (pbCfg and pbCfg.useClassColor) or false
  local pbFont = (pbCfg and pbCfg.font) or "Fonts\\FRIZQT__.TTF"
  local pbFontSize = (pbCfg and tonumber(pbCfg.fontSize)) or math.max(6, pbH - 4)

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
  panel.pbHeader:ClearAllPoints()
  panel.pbHeader:SetPoint("TOPLEFT", panel.tbBorderLabel or panel.tbFontSizeLabel or panel.hbBorderLabel or panel.hbFontSizeLabel, "BOTTOMLEFT", 0, -24)
  panel.pbHeader:Show()

  -- Width
  panel.pbWidthLabel:ClearAllPoints()
  panel.pbWidthLabel:SetPoint("TOPLEFT", panel.pbHeader, "BOTTOMLEFT", 0, -8)
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
    if pbCfg then pbCfg.width = val end
    panel.pbWidthVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Height
  panel.pbHeightLabel:ClearAllPoints()
  panel.pbHeightLabel:SetPoint("TOPLEFT", panel.pbWidthLabel, "BOTTOMLEFT", 0, -12)
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
    if pbCfg then pbCfg.height = val end
    panel.pbHeightVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Info mode
  panel.pbInfoLabel:ClearAllPoints()
  panel.pbInfoLabel:SetPoint("TOPLEFT", panel.pbHeightLabel, "BOTTOMLEFT", 0, -12)
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
          if pbCfg then pbCfg.infoMode = pbMode end
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
  panel.pbHealthColorLabel:SetPoint("TOPLEFT", panel.pbInfoLabel, "BOTTOMLEFT", 0, -12)
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
      if pbCfg then pbCfg.colorHealth = pbCH end
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
  panel.pbMissingColorLabel:SetPoint("TOPLEFT", panel.pbHealthColorLabel, "BOTTOMLEFT", 0, -12)
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
      if pbCfg then pbCfg.colorMissing = pbCM end
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
  panel.pbUseClassCB:SetPoint("TOPLEFT", panel.pbMissingColorLabel, "BOTTOMLEFT", 0, -12)
  panel.pbUseClassCB:SetChecked(pbUseClass)
  panel.pbUseClassCB:Show()
  panel.pbUseClassCB:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if pbCfg then pbCfg.useClassColor = v end
    if panel.pbHealthColorBtn and panel.pbHealthColorBtn.Enable then panel.pbHealthColorBtn:SetEnabled(not v) end
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)
  if panel.pbHealthColorBtn and panel.pbHealthColorBtn.Enable then panel.pbHealthColorBtn:SetEnabled(not pbUseClass) end

  -- Font dropdown
  panel.pbFontLabel:ClearAllPoints()
  panel.pbFontLabel:SetPoint("TOPLEFT", panel.pbUseClassCB, "BOTTOMLEFT", 0, -12)
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
          if pbCfg then pbCfg.font = pbCurrentFont end
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
  panel.pbFontSizeLabel:SetPoint("TOPLEFT", panel.pbFontLabel, "BOTTOMLEFT", 0, -12)
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
    if pbCfg then pbCfg.fontSize = val end
    panel.pbFontSizeVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Border size
  panel.pbBorderLabel:ClearAllPoints()
  panel.pbBorderLabel:SetPoint("TOPLEFT", panel.pbFontSizeLabel, "BOTTOMLEFT", 0, -12)
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
    if pbCfg then pbCfg.borderSize = val end
    panel.pbBorderVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Clock options layout and bindings
  local ckCfg = SkyInfoTiles and SkyInfoTiles.GetOrCreateTileCfg and SkyInfoTiles.GetOrCreateTileCfg("clock")
  local ckFont = (ckCfg and ckCfg.font) or "Fonts\\FRIZQT__.TTF"
  local ckSize = (ckCfg and tonumber(ckCfg.size or ckCfg.fontSize)) or 24
  local ckOutline = (ckCfg and ckCfg.outline) or (SkyInfoTilesDB and SkyInfoTilesDB.fontOutline) or "OUTLINE"
  local ckColor = (ckCfg and ckCfg.color) or { r = 1, g = 1, b = 1, a = 1 }

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
  panel.ckHeader:ClearAllPoints()
  panel.ckHeader:SetPoint("TOPLEFT", panel.pbBorderLabel or panel.tbBorderLabel or panel.hbBorderLabel, "BOTTOMLEFT", 0, -24)
  panel.ckHeader:Show()

  -- Size
  panel.ckSizeLabel:ClearAllPoints()
  panel.ckSizeLabel:SetPoint("TOPLEFT", panel.ckHeader, "BOTTOMLEFT", 0, -8)
  panel.ckSizeLabel:Show()

  panel.ckSize:ClearAllPoints()
  panel.ckSize:SetPoint("LEFT", panel.ckSizeLabel, "RIGHT", 8, 0)
  panel.ckSize:SetValue(ckSize)
  panel.ckSize:Show()

  panel.ckSizeVal:ClearAllPoints()
  panel.ckSizeVal:SetPoint("LEFT", panel.ckSize, "RIGHT", 12, 0)
  panel.ckSizeVal:SetText(string.format("%d px", ckSize))
  panel.ckSizeVal:Show()

  panel.ckSize:SetScript("OnValueChanged", function(self, val)
    val = math.floor(tonumber(val) or 24)
    if ckCfg then ckCfg.size = val; ckCfg.fontSize = val end
    panel.ckSizeVal:SetText(string.format("%d px", val))
    if SkyInfoTiles and SkyInfoTiles.UpdateAll then SkyInfoTiles.UpdateAll() end
  end)

  -- Font dropdown
  panel.ckFontLabel:ClearAllPoints()
  panel.ckFontLabel:SetPoint("TOPLEFT", panel.ckSizeLabel, "BOTTOMLEFT", 0, -12)
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
          if ckCfg then ckCfg.font = ckFont end
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
  panel.ckOutlineLabel:SetPoint("TOPLEFT", panel.ckFontLabel, "BOTTOMLEFT", 0, -12)
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
          if ckCfg then ckCfg.outline = currentOutline end
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
  panel.ckColorLabel:SetPoint("TOPLEFT", panel.ckOutlineLabel, "BOTTOMLEFT", 0, -12)
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
      if ckCfg then ckCfg.color = ckColor end
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

  -- Hide any extra checkboxes if catalog shrank
  for i = #catalog + 1, #panel.tileCheckboxes do
    panel.tileCheckboxes[i]:Hide()
  end

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
