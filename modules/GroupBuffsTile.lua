local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

-- Fallback icon (question mark) if a spell texture is unavailable
local DEFAULT_ICON = 134400

local function Clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Track core raid buffs available in modern WoW
-- Using stable spellIDs for detection and localized spell names/icons for display
local TRACKED_BUFFS = {
  { spellId = 6673,  short = "Shout" }, -- Battle Shout (Warrior)
  { spellId = 21562, short = "Fort"  }, -- Power Word: Fortitude (Priest)
  { spellId = 1459,  short = "Int"   }, -- Arcane Intellect (Mage)
  { spellId = 1126,  short = "MotW"  }, -- Mark of the Wild (Druid)
  { spellId = 381748, short = "Bronze" }, -- Blessing of the Bronze (Evoker)
}
 
-- Presence-style detects (boolean ON/OFF shown; checks on player only)
local PRESENCE_TRACK = {
  { spellIds = { 465 }, label = "Devotion Aura" },           -- Paladin Devotion Aura (protection-style aura)
  { spellIds = { 327942, 8512 }, label = "Windfury Totem" }, -- Shaman Windfury Totem (buff id + classic cast id fallback)
}

-- Layout
local ROW_HEIGHT = 20
local ICON_SIZE  = 25
local PAD_X      = 8
local PAD_Y      = 6

local function IsPartyOrRaidInstance()
  if not IsInInstance then return false end
  local inInst, instType = IsInInstance()
  return inInst and (instType == "party" or instType == "raid")
end

local function BuildGroupUnits()
  local units = {}
  if IsInRaid and IsInRaid() then
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    for i = 1, n do
      local u = "raid" .. i
      if UnitExists and UnitExists(u) then
        table.insert(units, u)
      end
    end
  elseif IsInGroup and IsInGroup() then
    table.insert(units, "player")
    local n = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0
    for i = 1, n do
      local u = "party" .. i
      if UnitExists and UnitExists(u) then
        table.insert(units, u)
      end
    end
  else
    -- Solo (rare for dungeons/raids, but allow fallback so the tile doesn't error)
    table.insert(units, "player")
  end
  return units
end

local function IsEligibleUnit(unit)
  if not (UnitExists and UnitExists(unit)) then return false end
  if UnitIsConnected and not UnitIsConnected(unit) then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return false end
  return true
end

local function UnitHasBuffSpellId(unit, spellId)
  -- Prefer AuraUtil when available
  if AuraUtil and AuraUtil.ForEachAura then
    local found = false
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
      if aura and aura.spellId == spellId then
        found = true
        return true -- stop iteration
      end
      return false
    end)
    return found
  end
  -- Fallback to UnitBuff index scan
  local i = 1
  while true do
    local name, _, _, _, _, _, _, _, _, spellIdBuff = UnitBuff(unit, i)
    if not name then break end
    if spellIdBuff == spellId then return true end
    i = i + 1
  end
  return false
end

local function UnitHasAnyBuffSpellId(unit, ids)
  if type(ids) ~= "table" or #ids == 0 then return false end
  -- Prefer AuraUtil for efficiency
  if AuraUtil and AuraUtil.ForEachAura then
    local found = false
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
      if aura and aura.spellId then
        for _, id in ipairs(ids) do
          if aura.spellId == id then
            found = true
            return true -- stop
          end
        end
      end
      return false
    end)
    return found
  end
  -- Fallback linear scan
  local i = 1
  while true do
    local name, _, _, _, _, _, _, _, _, sid = UnitBuff(unit, i)
    if not name then break end
    for _, id in ipairs(ids) do
      if sid == id then return true end
    end
    i = i + 1
  end
  return false
end

local function ReadBuffDisplayData(entry)
  local name, _, iconSI = (GetSpellInfo and GetSpellInfo(entry.spellId)) or nil
  local iconGT = (GetSpellTexture and GetSpellTexture(entry.spellId)) or nil
  local icon = iconSI or iconGT
  return name or entry.short or ("Spell " .. tostring(entry.spellId)), (icon or DEFAULT_ICON)
end

-- Overlay helpers: color code by completion
local function SetOverlayCount(fs, have, total)
  if not fs then return end
  have = tonumber(have) or 0; total = tonumber(total) or 0
  fs:SetText(string.format("%d/%d", have, total))
  local r,g,b = 1,1,1
  if total > 0 then
    if have >= total then
      r,g,b = 0.15, 0.95, 0.2 -- green when complete
    elseif have <= 0 then
      r,g,b = 0.95, 0.15, 0.15 -- red when none
    else
      r,g,b = 1.0, 0.85, 0.2   -- amber when partial
    end
  end
  if fs.SetTextColor then fs:SetTextColor(r,g,b,1) end
end

local function SetOverlayPresence(fs, on)
  if not fs then return end
  local stateText = on and "ON" or "OFF"
  fs:SetText(stateText)
  local r,g,b = on and 0.15 or 0.95, on and 0.95 or 0.15, on and 0.2 or 0.15
  if fs.SetTextColor then fs:SetTextColor(r,g,b,1) end
end

local API = {}

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)
  local rows   = (#TRACKED_BUFFS) + (#PRESENCE_TRACK)
  local gap    = 2
  local width  = PAD_X * 2 + rows * (ICON_SIZE + gap) - gap
  local height = PAD_Y * 3 + ICON_SIZE + 18
  f:SetSize(width, height)

  -- Title
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_X, -PAD_Y)
  f.title:SetTextColor(1, 1, 1, 1)
  f.title:SetText((cfg and cfg.label) or "Group Buffs")
  if UI and UI.Outline then UI.Outline(f.title) end

  -- Rows (icon + label text)
  f._labels, f._icons, f._subs, f._borders = {}, {}, {}, {}
  local y = -6
  local gap = 2
  for i = 1, rows do
    local entry = (i <= #TRACKED_BUFFS) and TRACKED_BUFFS[i] or PRESENCE_TRACK[i - #TRACKED_BUFFS]
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", (i - 1) * (ICON_SIZE + gap), y)

    -- Decorative border around the icon (matches common button style)
    local br = f:CreateTexture(nil, "BORDER")
    br:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    br:SetPoint("CENTER", icon, "CENTER", 0, 0)
    br:SetSize(ICON_SIZE + 12, ICON_SIZE + 12)
    if br.SetDrawLayer then br:SetDrawLayer("BORDER", 1) end
    f._borders[i] = br

    -- Overlay count label centered on icon (e.g., 4/12 or ON/OFF)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER", icon, "CENTER", 0, 0)
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    local overlaySize = math.max(10, ICON_SIZE - 6)
    local _, _, flags = fs:GetFont()
    fs:SetFont((STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), overlaySize, flags or "")
    if UI and UI.Outline then UI.Outline(fs, { weight = "THICKOUTLINE", size = overlaySize }) end
    fs:SetText("")

    -- Sub-caption under icon (matches the requested "BUFF!" label style)
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOP", icon, "BOTTOM", 0, -2)
    sub:SetTextColor(1, 1, 1, 1)
    sub:SetShadowColor(0, 0, 0, 1)
    sub:SetShadowOffset(1, -1)
    sub:SetJustifyH("CENTER")
    sub:SetJustifyV("TOP")
    if UI and UI.Outline then UI.Outline(sub) end
    sub:SetText("BUFF!")

    f._subs[i] = sub

    -- Initialize icon texture
    local _, iconTex = ReadBuffDisplayData(entry)
    icon:SetTexture(iconTex or DEFAULT_ICON)
    if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

    f._icons[i]  = icon
    f._labels[i] = fs
  end

  -- Drag hint (shown only when unlocked)
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
  f.hint:SetTextColor(1, 1, 1, 0.8)
  f.hint:SetShadowColor(0, 0, 0, 1)
  f.hint:SetShadowOffset(1, -1)
  f.hint:SetText("drag")
  f.hint:Hide()

  -- Mouse for drag + right-click refresh
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then API.update(self, cfg) end
  end)

  -- Simple drag handling; actual drag enable/disable is also managed centrally by core's SetMovable
  f:SetScript("OnMouseDown", function(self, btn)
    local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
    if not locked and btn == "LeftButton" then
      if self.StartMoving then self:StartMoving() end
    end
  end)
  f:SetScript("OnMouseUp", function(self, btn)
    local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
    if not locked and btn == "LeftButton" then
      if self.StopMovingOrSizing then self:StopMovingOrSizing() end
      local point, _, _, x, y = self:GetPoint()
      if self._cfg then self._cfg.point, self._cfg.x, self._cfg.y = point, x, y end
    end
    if btn == "RightButton" then
      API.update(self, cfg)
    end
  end)

  -- Events for roster/auras/zone gating
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("UNIT_AURA")
  f:RegisterEvent("ZONE_CHANGED")
  f:RegisterEvent("ZONE_CHANGED_INDOORS")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
      if self._pendingScale and self.SetScale then
        local sc = self._pendingScale
        self._pendingScale = nil
        if self._appliedScale ~= sc then
          self:SetScale(sc)
          self._appliedScale = sc
        end
      end
    end
    -- For UNIT_AURA, we could filter arg1 to group units; the update is lightweight enough to refresh fully
    API.update(self, cfg)
  end)

  -- First paint when shown
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)

  function f:Destroy() end
  return f
end

local function CountBuff(tracked, units)
  -- Denominator: full roster size (party/raid), matching formats like 23/25
  local total = #units
  local have = 0
  for _, unit in ipairs(units) do
    if UnitHasBuffSpellId(unit, tracked.spellId) then
      have = have + 1
    end
  end
  return have, total
end

function API.update(frame, cfg)
  -- Instance gating with Preview override
  local inInst = IsPartyOrRaidInstance()
  local preview = (cfg and cfg.preview) and not inInst
  if not inInst and not preview then
    if not (InCombatLockdown and InCombatLockdown()) then
      if frame.Hide then frame:Hide() end
    end
    return
  end

  local units = BuildGroupUnits()

  -- Title
  if frame.title then
    frame.title:SetText(((cfg and cfg.label) or "Group Buffs"))
  end
  -- Apply scale (preview helps sizing out of instance)
  local sc = (cfg and tonumber(cfg.scale)) or 1
  if sc < 0.5 then sc = 0.5 elseif sc > 2.0 then sc = 2.0 end
  if frame.SetScale then
    if InCombatLockdown and InCombatLockdown() then
      frame._pendingScale = sc
    else
      if frame._appliedScale ~= sc then
        frame:SetScale(sc)
        frame._appliedScale = sc
        frame._pendingScale = nil
      end
    end
  end

  -- Apply configurable icon/text sizes and layout
  local rows = (#TRACKED_BUFFS) + (#PRESENCE_TRACK)
  local gap = 2
  local iconSize = Clamp((cfg and cfg.iconSize) or ICON_SIZE, 16, 64)
  local textSize = Clamp((cfg and cfg.textSize) or 12, 8, 48)
  local width = PAD_X * 2 + rows * (iconSize + gap) - gap
  local height = PAD_Y * 3 + iconSize + 18
  if frame.SetSize then frame:SetSize(width, height) end
  -- Reposition and resize icons/overlays
  for i = 1, rows do
    local icon = frame._icons and frame._icons[i]
    if icon and icon.SetSize then
      icon:SetSize(iconSize, iconSize)
      icon:ClearAllPoints()
      icon:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", (i - 1) * (iconSize + gap), -6)
    end
    local br = frame._borders and frame._borders[i]
    if br and br.SetSize then
      br:SetSize(iconSize + 12, iconSize + 12)
      br:ClearAllPoints()
      if icon then br:SetPoint("CENTER", icon, "CENTER", 0, 0) end
    end
    local fs = frame._labels and frame._labels[i]
    if fs and fs.SetFont then
      local _, _, flags = fs:GetFont()
      fs:SetFont((STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), textSize, flags or "")
    end
    local sub = frame._subs and frame._subs[i]
    if sub and sub.SetFont then
      local _, _, flags = sub:GetFont()
      local subSize = Clamp(math.floor(textSize * 0.55 + 0.5), 8, 24)
      sub:SetFont((STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), subSize, flags or "")
      sub:ClearAllPoints()
      if icon then sub:SetPoint("TOP", icon, "BOTTOM", 0, -2) end
    end
  end

  -- Preview rendering (outside instances when preview flag is set)
  if preview then
    local sampleTotal = 5
    local sampleHave = { 3, 4, 5, 4, 5 }
    -- Counted buffs (samples)
    for i, entry in ipairs(TRACKED_BUFFS) do
      local _, iconTex = ReadBuffDisplayData(entry)
      local have = sampleHave[i] or 3
      if frame._labels[i] then
        SetOverlayCount(frame._labels[i], have, sampleTotal)
      end
      if frame._subs and frame._subs[i] then
        frame._subs[i]:SetText("BUFF!")
      end
      if frame._icons[i] then
        frame._icons[i]:SetTexture(iconTex or DEFAULT_ICON)
        if frame._icons[i].SetTexCoord then frame._icons[i]:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
      end
    end
    -- Presence auras: show ON for first, OFF for second as a sample
    for j, entry in ipairs(PRESENCE_TRACK) do
      local idx = #TRACKED_BUFFS + j
      local dispLabel = entry.label
      local iconTex = nil
      if type(entry.spellIds) == "table" and #entry.spellIds > 0 then
        local nm, ic = ReadBuffDisplayData({ spellId = entry.spellIds[1] })
        iconTex = ic
        if not dispLabel then dispLabel = nm end
      end
      if frame._labels[idx] then
        SetOverlayPresence(frame._labels[idx], (j == 1))
      end
      if frame._subs and frame._subs[idx] then
        frame._subs[idx]:SetText("BUFF!")
      end
      if frame._icons[idx] then
        frame._icons[idx]:SetTexture(iconTex or DEFAULT_ICON)
        if frame._icons[idx].SetTexCoord then frame._icons[idx]:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
      end
    end
    if not (InCombatLockdown and InCombatLockdown()) then
      if frame.Show then frame:Show() end
    end
    -- Drag hint visibility handled below
    -- Skip real counting and hide-when-complete in preview mode
    -- (always show so users can position/scale)
    -- Note: counts here are mock values by design.
    -- Return to avoid executing real group logic.
    -- Drag hint visibility will still be applied after return in next update call.
    return
  end

  local allComplete = true

  -- Counted, per-member buffs
  for i, entry in ipairs(TRACKED_BUFFS) do
    local have, total = CountBuff(entry, units)
    if total < 1 then total = 1 end

    local label, iconTex = ReadBuffDisplayData(entry)
    if frame._labels[i] then
      SetOverlayCount(frame._labels[i], have or 0, total or 0)
    end
    if frame._subs and frame._subs[i] then
      frame._subs[i]:SetText("BUFF!")
    end
    if frame._icons[i] then
      frame._icons[i]:SetTexture(iconTex or DEFAULT_ICON)
      if frame._icons[i].SetTexCoord then frame._icons[i]:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end

    if have < total then
      allComplete = false
    end
  end

  -- Presence-only group auras (boolean ON/OFF against player's buffs)
  for j, entry in ipairs(PRESENCE_TRACK) do
    local idx = #TRACKED_BUFFS + j
    local present = UnitHasAnyBuffSpellId("player", entry.spellIds)
    local dispLabel = entry.label
    local iconTex = nil
    if type(entry.spellIds) == "table" and #entry.spellIds > 0 then
      local nm, ic = ReadBuffDisplayData({ spellId = entry.spellIds[1] })
      iconTex = ic
      if not dispLabel then dispLabel = nm end
    end
    if frame._labels[idx] then
      SetOverlayPresence(frame._labels[idx], present)
    end
    if frame._subs and frame._subs[idx] then
      frame._subs[idx]:SetText("BUFF!")
    end
    if frame._icons[idx] then
      frame._icons[idx]:SetTexture(iconTex or DEFAULT_ICON)
      if frame._icons[idx].SetTexCoord then frame._icons[idx]:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end
    if not present then
      allComplete = false
    end
  end

  -- Hide the entire tile if ALL tracked buffs are fully present on all eligible members
  if allComplete then
    if not (InCombatLockdown and InCombatLockdown()) then
      if frame.Hide then frame:Hide() end
    end
  else
    if not (InCombatLockdown and InCombatLockdown()) then
      if frame.Show then frame:Show() end
    end
  end

  -- Drag hint visibility
  if SkyInfoTilesDB and not SkyInfoTilesDB.locked then
    if frame.hint and frame.hint.Show then frame.hint:Show() end
  else
    if frame.hint and frame.hint.Hide then frame.hint:Hide() end
  end
end

SkyInfoTiles.RegisterTileType("groupbuffs", API)
