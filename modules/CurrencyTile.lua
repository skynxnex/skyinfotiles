local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI

-- Current season currencies
-- Hardcoded list of active season currencies (by ID). Update this list each season.
local CURRENCIES = {
  -- Warband transferable
  { id = 3379, label = "Brimming Arcana" },
  { id = 3385, label = "Luminous Dust" },
  { id = 3316, label = "Voidlight Marl" },
  { id = 2803, label = "Undercoin" },

  -- Separator
  { separator = true },

  -- Character-bound
  { id = 3212, label = "Radiant Spark Dust" },
  { id = 3377, label = "Unalloyed Abundance" },
  { id = 3310, label = "Coffer Key Shards" },
  { id = 3028, label = "Restored Coffer Key" },
  { id = 3378, label = "Dawnlight Manaflux" },
  { id = 3376, label = "Shard of Dundun" },
  { id = 3400, label = "Uncontaminated Void Sample" },
  { id = 3356, label = "Untainted Mana-Crystals" },

  -- Separator
  { separator = true },

  -- Dawncrest PvP/Rating currencies (lowest to highest)
  { id = 3347, label = "Myth Dawncrest" },
  { id = 3345, label = "Hero Dawncrest" },
  { id = 3343, label = "Champion Dawncrest" },
  { id = 3341, label = "Veteran Dawncrest" },
  { id = 3383, label = "Adventurer Dawncrest" },
}

local function GetActiveCurrencyEntries() return CURRENCIES end

local function SafeReleaseRegion(r)
  if not r then return end
  if r.Hide then pcall(r.Hide, r) end
  if r.SetParent then pcall(r.SetParent, r, nil) end
end

-- Layout
local ROW_HEIGHT = 22
local ICON_SIZE  = 18
local PAD_X      = 8
local PAD_Y      = 6
local FONT       = "GameFontNormal"

-- Max level gate
local function IsAtMaxLevel()
  local cur = (UnitLevel and UnitLevel("player")) or nil
  local mx = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or (MAX_PLAYER_LEVEL) or nil
  if cur and mx then return cur >= mx end
  return true
end

-- Read additional details (caps, total earned) by currencyID.
local function ReadDetails(currencyID)
  if not currencyID then return nil end
  local ci = C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
  if not ci then return nil end
  return {
    name                   = ci.name,
    quantity               = ci.quantity,
    maxQuantity            = ci.maxQuantity,
    totalEarned            = ci.totalEarned,
    canEarnPerWeek         = ci.canEarnPerWeek,
    maxWeeklyQuantity      = ci.maxWeeklyQuantity,
    quantityEarnedThisWeek = ci.quantityEarnedThisWeek,
    iconFileID             = ci.iconFileID,
    currencyTypesID        = currencyID,
  }
end

local function BuildLine(entry, cfg)
  -- Handle separator lines
  if entry.separator then
    return nil, nil, true  -- return nil text, nil icon, isSeparator=true
  end

  local qty, iconID, cid, label

  -- Prefer ID-based read when provided (more robust across seasons/locales)
  if entry.id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local ci = C_CurrencyInfo.GetCurrencyInfo(entry.id)
    if ci then
      qty = ci.quantity or 0
      iconID = ci.iconFileID
      cid = entry.id
      label = entry.label or ci.name
    end
  end

  -- If we have an ID but GetCurrencyInfo() returned nil (not discovered / not in list yet), still show the row.
  if entry.id and not cid then
    cid = entry.id
    qty = 0
    label = entry.label or ("ID " .. tostring(entry.id))
  end

  -- No name-based fallback: this tile is current-season only and should be ID-driven.
  if not cid then
    return (entry.label or "Currency") .. ": 0", nil, false
  end

  -- Read details for caps/weekly if we have a currencyID
  local det = cid and ReadDetails(cid) or nil

  -- Compose text: XX [YY/ZZ] format
  -- [YY/ZZ] shows either season cap (maxQuantity) or weekly cap (maxWeeklyQuantity)
  local text
  if cfg and cfg.hideLabel then
    -- Just show quantity (and progress if available)
    text = string.format("%d", qty or 0)
  else
    -- Full text with label: "Name: XX"
    text = string.format("%s: %d", label or (entry.label or "Currency"), qty or 0)
  end

  -- Show progress bracket [earned/cap]
  -- Show both weekly and season caps if both exist
  -- Color red if capped
  local hasWeeklyCap = det and det.maxWeeklyQuantity and det.maxWeeklyQuantity > 0
  local hasSeasonCap = det and det.maxQuantity and det.maxQuantity > 0

  if hasWeeklyCap then
    -- Show weekly cap: quantityEarnedThisWeek/maxWeeklyQuantity
    local earned = det.quantityEarnedThisWeek or 0
    local isCapped = earned >= det.maxWeeklyQuantity
    local color = isCapped and "|cffff0000" or ""
    local reset = isCapped and "|r" or ""
    text = text .. string.format(" %s[%d/%d]%s", color, earned, det.maxWeeklyQuantity, reset)
  end

  if hasSeasonCap then
    -- Show season cap: totalEarned/maxQuantity
    local progress = (det.totalEarned and det.totalEarned > 0) and det.totalEarned or (det.quantity or qty or 0)
    local isCapped = progress >= det.maxQuantity
    local color = isCapped and "|cffff0000" or ""
    local reset = isCapped and "|r" or ""
    text = text .. string.format(" %s[%d/%d]%s", color, progress, det.maxQuantity, reset)
  end

  -- Prefer detailed icon if list icon missing
  if (not iconID) and det and det.iconFileID then
    iconID = det.iconFileID
  end

  return text, iconID, false
end

local function ScopeTag()
  local scope = (SkyInfoTilesDB and SkyInfoTilesDB.scope) or "char"
  return (scope == "warband") and " (WB)" or ""
end

local API = {}

local function RebuildRows(f, cfg)
  if not f then return end

  -- Clear old
  for i, icon in ipairs(f._icons or {}) do SafeReleaseRegion(icon) end
  for i, lbl in ipairs(f._labels or {}) do SafeReleaseRegion(lbl) end
  for i, row in ipairs(f._rowFrames or {}) do
    if row and row.SetScript then
      row:SetScript("OnEnter", nil)
      row:SetScript("OnLeave", nil)
    end
    SafeReleaseRegion(row)
  end
  if f._separators then
    for i, sep in ipairs(f._separators) do SafeReleaseRegion(sep) end
  end
  f._icons, f._labels, f._separators, f._rowFrames = {}, {}, {}, {}

  f._entries = GetActiveCurrencyEntries()

  local rows = #(f._entries or {})
  local height = PAD_Y * 2 + rows * ROW_HEIGHT + 24
  local width  = 320
  f:SetSize(width, height)

  -- Rows
  local y = -6
  for i, entry in ipairs(f._entries or {}) do
    if entry.separator then
      -- Create separator line
      local line = f:CreateTexture(nil, "ARTWORK")
      line:SetColorTexture(0.5, 0.5, 0.5, 0.6)
      line:SetHeight(1)
      line:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, y - (i - 1) * ROW_HEIGHT - ROW_HEIGHT/2)
      line:SetPoint("TOPRIGHT", f.title, "BOTTOMRIGHT", 0, y - (i - 1) * ROW_HEIGHT - ROW_HEIGHT/2)
      f._separators[#f._separators + 1] = line
      f._icons[i] = nil
      f._labels[i] = nil
      f._rowFrames[i] = nil
    else
      -- Regular currency row - create invisible frame for tooltip
      local rowFrame = CreateFrame("Frame", nil, f)
      rowFrame:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, y - (i - 1) * ROW_HEIGHT)
      rowFrame:SetSize(width - PAD_X * 2, ROW_HEIGHT)
      rowFrame:EnableMouse(true)
      rowFrame._entry = entry

      -- Tooltip on hover
      rowFrame:SetScript("OnEnter", function(self)
        if not self._entry then return end
        local currencyID = self._entry.id
        if not currencyID then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetCurrencyByID(currencyID)
        GameTooltip:Show()
      end)

      rowFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
      end)

      local icon = f:CreateTexture(nil, "ARTWORK")
      icon:SetSize(ICON_SIZE, ICON_SIZE)
      icon:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, y - (i - 1) * ROW_HEIGHT)

      local fs = f:CreateFontString(nil, "OVERLAY", FONT)
      fs:SetPoint("LEFT", icon, "RIGHT", 6, 0)
      fs:SetTextColor(1, 1, 1, 1)
      fs:SetShadowColor(0, 0, 0, 1)
      fs:SetShadowOffset(1, -1)
      fs:SetJustifyH("LEFT")
      fs:SetText("...")
      UI.Outline(fs)

      f._icons[i]  = icon
      f._labels[i] = fs
      f._rowFrames[i] = rowFrame
    end
  end
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)
  f._entries = {}
  f._icons, f._labels = {}, {}

  -- Title
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_X, -PAD_Y)
  f.title:SetTextColor(1, 1, 1, 1)
  f.title:SetText((cfg.label or "Currencies") .. ScopeTag())
  UI.Outline(f.title)

  RebuildRows(f, cfg)

  -- Right-click => refresh
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then API.update(self, cfg) end
  end)

  -- Events for level gating and currency updates
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

  -- Throttle update calls (CURRENCY_DISPLAY_UPDATE can spam)
  f._updateThrottle = -1  -- Initialize to -1 to allow first update
  f:SetScript("OnEvent", function(self, event)
    if event == "CURRENCY_DISPLAY_UPDATE" then
      local now = GetTime and GetTime() or 0
      if self._updateThrottle > 0 and (now - self._updateThrottle) < 0.1 then
        return  -- Throttle only after first update
      end
      self._updateThrottle = now
    end
    API.update(self, cfg)
  end)

  -- First paint when shown
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)

  function f:Destroy()
    if self.UnregisterAllEvents then
      self:UnregisterAllEvents()
    end
    if self.SetScript then
      self:SetScript("OnEvent", nil)
      self:SetScript("OnShow", nil)
      self:SetScript("OnMouseUp", nil)
    end
  end
  return f
end

function API.update(frame, cfg)
  -- Max level gating
  if not IsAtMaxLevel() then
    if not (InCombatLockdown and InCombatLockdown()) then
      if frame.Hide then frame:Hide() end
    end
    return
  else
    if not (InCombatLockdown and InCombatLockdown()) then
      if frame.Show then frame:Show() end
    end
  end
  -- Title
  frame.title:SetText(((cfg and cfg.label) or "Currencies") .. ScopeTag())

  -- Ensure rows are built (check if entry count changed)
  local currentEntries = GetActiveCurrencyEntries()
  if #(frame._entries or {}) ~= #currentEntries then
    RebuildRows(frame, cfg)
  end

  -- Rows
  for i, entry in ipairs(frame._entries or {}) do
    if not entry.separator then
      local text, iconID, isSeparator = BuildLine(entry, cfg)
      if frame._labels[i] then frame._labels[i]:SetText(text or entry.label or "?") end
      if frame._icons[i] and iconID then frame._icons[i]:SetTexture(iconID) end
    end
  end
end

SkyInfoTiles.RegisterTileType("currencies", API)

-- Debug command to check currency data
SLASH_SKYCURRENCYDEBUG1 = "/skycurrencydebug"
SlashCmdList["SKYCURRENCYDEBUG"] = function()
  if not DEFAULT_CHAT_FRAME then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles Currency Debug:|r")
  for _, entry in ipairs(CURRENCIES) do
    if not entry.separator and entry.id then
      local ci = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(entry.id)
      if ci then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%d] %s: %d (discovered)", entry.id, entry.label, ci.quantity or 0))
      else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%d] %s: NOT DISCOVERED", entry.id, entry.label))
      end
    end
  end
end
