local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI

-- Midnight - Season 1 currencies (WIP)
-- Dead-simple: hardcoded list of current season currencies (by ID). Show 0 if not obtained yet.
-- User-provided IDs so far:
-- Adventurer/Veteran/Champion/Hero/Myth Dawncrest.
local CURRENCIES = {
  { id = 3342, label = "Adventurer Dawncrest" },
  { id = 3343, label = "Veteran Dawncrest" },
  { id = 3344, label = "Champion Dawncrest" },
  { id = 3345, label = "Hero Dawncrest" },
  { id = 3346, label = "Myth Dawncrest" },

  -- Core Midnight currencies
  { id = 3316, label = "Voidlight Marl" },
  { id = 3350, label = "Hearthsteel" },
  { id = 3355, label = "Unalloyed Abundance" },

  -- Professions
  { id = 3106, label = "Artisan's Moxie" },
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

-- Read additional details (caps, weekly progress) by currencyID.
local function ReadDetails(currencyID)
  if not currencyID then return nil end
  local ci = C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
  if not ci then return nil end
  return {
    name                   = ci.name,
    quantity               = ci.quantity,
    maxQuantity            = ci.maxQuantity,
    canEarnPerWeek         = ci.canEarnPerWeek,
    maxWeeklyQuantity      = ci.maxWeeklyQuantity,
    quantityEarnedThisWeek = ci.quantityEarnedThisWeek,
    iconFileID             = ci.iconFileID,
    currencyTypesID        = currencyID,
  }
end

local function BuildLine(entry)
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
    return (entry.label or "Currency") .. ": 0", nil
  end

  -- Read details for caps/weekly if we have a currencyID
  local det = cid and ReadDetails(cid) or nil

  -- Compose text
  local text = string.format("%s: %d", label or (entry.label or "Currency"), qty or 0)

  -- Season cap (maxQuantity), if present
  if det and det.maxQuantity and det.maxQuantity > 0 then
    text = text .. string.format(" /%d", det.maxQuantity)
  end

  -- Weekly progress (use quantityEarnedThisWeek/maxWeeklyQuantity)
  if det and det.canEarnPerWeek and det.maxWeeklyQuantity and det.maxWeeklyQuantity > 0 then
    local earned = det.quantityEarnedThisWeek or 0
    text = text .. string.format("  [%d/%d wk]", earned, det.maxWeeklyQuantity)
  end

  -- Prefer detailed icon if list icon missing
  if (not iconID) and det and det.iconFileID then
    iconID = det.iconFileID
  end

  return text, iconID
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
  f._icons, f._labels = {}, {}

  f._entries = GetActiveCurrencyEntries()

  local rows = #(f._entries or {})
  local height = PAD_Y * 2 + rows * ROW_HEIGHT + 24
  local width  = 320
  f:SetSize(width, height)

  -- Rows
  local y = -6
  for i, entry in ipairs(f._entries or {}) do
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
  local n = #(GetActiveCurrencyEntries() or {})
  f.title:SetText((cfg.label or "Season 1 Currencies") .. ScopeTag() .. string.format(" (%d)", n))
  UI.Outline(f.title)

  RebuildRows(f, cfg)

  -- Right-click => refresh
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then API.update(self, cfg) end
  end)

  -- Drag hint (shown only when unlocked)
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
  f.hint:SetTextColor(1, 1, 1, 0.8)
  f.hint:SetShadowColor(0, 0, 0, 1)
  f.hint:SetShadowOffset(1, -1)
  f.hint:SetText("drag")
  f.hint:Hide()

  -- Events for level gating
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:SetScript("OnEvent", function(self, event)
    API.update(self, cfg)
  end)

  -- First paint when shown
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)

  function f:Destroy() end
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
  local n = #(GetActiveCurrencyEntries() or {})
  frame.title:SetText(((cfg and cfg.label) or "Season 1 Currencies") .. ScopeTag() .. string.format(" (%d)", n))

  -- Ensure rows are built
  if #(frame._entries or {}) ~= n then
    RebuildRows(frame, cfg)
  end

  -- Rows
  for i, entry in ipairs(frame._entries or {}) do
    local text, iconID = BuildLine(entry)
    if frame._labels[i] then frame._labels[i]:SetText(text or entry.label or "?") end
    if frame._icons[i] and iconID then frame._icons[i]:SetTexture(iconID) end
  end

  -- Drag hint visibility
  if SkyInfoTilesDB and not SkyInfoTilesDB.locked then frame.hint:Show() else frame.hint:Hide() end
end

SkyInfoTiles.RegisterTileType("season3", API)
