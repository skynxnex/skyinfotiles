local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI

-- Simple dark backdrop
local BACKDROP = {
  bgFile   = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  edgeSize = 1,
  insets   = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function colorTex(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a or 1) end

-- Format a single currency line
local function fmtCurrencyLine(info, overrideLabel)
  if not info then return (overrideLabel and (overrideLabel .. ": N/A")) or "N/A" end

  local name = overrideLabel or info.name or ("ID " .. (info.currencyTypesID or "?"))
  local qty  = tonumber(info.quantity) or 0

  local parts = { string.format("%s: %d", name, qty) }

  -- Hard cap
  if info.maxQuantity and info.maxQuantity > 0 then
    table.insert(parts, string.format("/ %d max", info.maxQuantity))
  end

  -- Weekly progress (prefer quantityEarnedThisWeek if available)
  if info.canEarnPerWeek and info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0 then
    local earned = tonumber(info.quantityEarnedThisWeek) or 0
    table.insert(parts, string.format(" | Weekly: %d/%d", earned, info.maxWeeklyQuantity))
  end

  return table.concat(parts, " ")
end

-- Merge warband vs character per global scope
local function getScopedCurrencyInfo(id)
  local char = C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
  local wb   = C_CurrencyInfo.GetWarbandCurrencyInfo and C_CurrencyInfo.GetWarbandCurrencyInfo(id)
  local scope = (SkyInfoTilesDB and SkyInfoTilesDB.scope) or "char"

  local src = (scope == "warband" and wb) or char or wb
  if not src then return nil end

  -- Normalize to fields used by fmtCurrencyLine
  return {
    name                   = src.name,
    quantity               = src.quantity,
    maxQuantity            = src.maxQuantity,
    canEarnPerWeek         = src.canEarnPerWeek,
    maxWeeklyQuantity      = src.maxWeeklyQuantity,
    quantityEarnedThisWeek = src.quantityEarnedThisWeek, -- preferred weekly source
    currencyTypesID        = id,
  }
end

local API = {}

function API.create(parent, cfg)
  local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
  f:SetSize(220, 40)
  f:SetBackdrop(BACKDROP)
  f:SetBackdropBorderColor(0, 0, 0, 1)

  -- background
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  colorTex(bg, 0, 0, 0, 0.35)

  -- label text
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  UI.Outline(f.text)
  f.text:SetPoint("LEFT", 10, 0)
  f.text:SetJustifyH("LEFT")
  f.text:SetText("Currency")

  -- drag hint (only when unlocked)
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  UI.Outline(f.hint)
  f.hint:SetPoint("BOTTOMRIGHT", -6, 4)
  f.hint:SetText("drag")
  f.hint:Hide()

  -- right-click to refresh
  f:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then
      API.update(self, cfg)
    end
  end)

  -- first paint when shown
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)

  function f:Destroy() end
  return f
end

function API.update(frame, cfg)
  local id    = cfg.id
  local label = cfg.label

  local info = getScopedCurrencyInfo(id)
  local line = fmtCurrencyLine(info, label)

  frame.text:SetText(line)
  if SkyInfoTilesDB and not SkyInfoTilesDB.locked then frame.hint:Show() else frame.hint:Hide() end
end

SkyInfoTiles.RegisterTileType("currency", API)
