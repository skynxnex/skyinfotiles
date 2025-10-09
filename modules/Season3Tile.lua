local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI

-- Season 3 currencies (uiName must match the in-game Currency panel line)
local CURRENCIES = {
  { uiName = "Valorstones",              label = "Valorstones" },
  { uiName = "Weathered Ethereal Crest", label = "Weathered Ethereal Crest" },
  { uiName = "Carved Ethereal Crest",    label = "Carved Ethereal Crest" },
  { uiName = "Runed Ethereal Crest",     label = "Runed Ethereal Crest" },
  { uiName = "Gilded Ethereal Crest",    label = "Gilded Ethereal Crest" },
  { uiName = "Restored Coffer Key",      label = "Restored Coffer Key" },
  { uiName = "Undercoin",                label = "Undercoin" },
  { uiName = "Starlight Spark Dust",     label = "Starlight Spark Dust" },
}

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

-- Look up exactly what the in-game Currency UI shows.
-- Returns: quantity, iconFileID, currencyID (or nils if not found)
local function FindInCurrencyListByName(targetName)
  local size = C_CurrencyInfo.GetCurrencyListSize and C_CurrencyInfo.GetCurrencyListSize()
  if not size or size <= 0 then return nil, nil, nil end

  for i = 1, size do
    local info = C_CurrencyInfo.GetCurrencyListInfo(i)
    if type(info) == "table" then
      if not info.isHeader and info.name == targetName then
        return info.quantity or 0, info.iconFileID, info.currencyTypesID
      end
    else
      -- Legacy tuple fallback
      local name, isHeader, _, _, _, count, icon, currencyID = C_CurrencyInfo.GetCurrencyListInfo(i)
      if not isHeader and name == targetName then
        return count or 0, icon, currencyID
      end
    end
  end
  return nil, nil, nil
end

-- Read additional details (caps, weekly progress) by currencyID.
local function ReadDetails(currencyID)
  if not currencyID then return nil end
  local ci = C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
  if not ci then return nil end
  return {
    name                 = ci.name,
    maxQuantity          = ci.maxQuantity,
    canEarnPerWeek       = ci.canEarnPerWeek,
    maxWeeklyQuantity    = ci.maxWeeklyQuantity,
    quantityEarnedThisWeek = ci.quantityEarnedThisWeek,
    iconFileID           = ci.iconFileID,
  }
end

local function BuildLine(entry)
  -- 1) Quantity/icon as shown by the Currency UI list
  local qty, iconID, cid = FindInCurrencyListByName(entry.uiName)

  -- 2) Details (season cap, weekly progress)
  local det = ReadDetails(cid)

  -- Compose text
  local text = string.format("%s: %d", entry.label, qty or 0)

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

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)
  local rows   = #CURRENCIES
  local height = PAD_Y * 2 + rows * ROW_HEIGHT + 24
  local width  = 320
  f:SetSize(width, height)

  -- Title
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_X, -PAD_Y)
  f.title:SetTextColor(1, 1, 1, 1)
  f.title:SetText((cfg.label or "Season 3 Currencies") .. ScopeTag())
  UI.Outline(f.title)

  f._labels, f._icons = {}, {}

  -- Rows
  local y = -6
  for i, entry in ipairs(CURRENCIES) do
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
  frame.title:SetText(((cfg and cfg.label) or "Season 3 Currencies") .. ScopeTag())

  -- Rows
  for i, entry in ipairs(CURRENCIES) do
    local text, iconID = BuildLine(entry)
    if frame._labels[i] then frame._labels[i]:SetText(text or entry.label or "?") end
    if frame._icons[i] and iconID then frame._icons[i]:SetTexture(iconID) end
  end

  -- Drag hint visibility
  if SkyInfoTilesDB and not SkyInfoTilesDB.locked then frame.hint:Show() else frame.hint:Hide() end
end

SkyInfoTiles.RegisterTileType("season3", API)
