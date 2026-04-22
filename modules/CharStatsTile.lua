local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI

-- ===== Layout =====
local ROW_HEIGHT = 20
local PAD_X      = 8
local PAD_Y      = 6
local FONT_LINE  = "GameFontNormal"
local FONT_HEAD  = "GameFontNormalLarge"

-- ===== Helpers =====
local function pctComma(x)
  x = tonumber(x) or 0
  return string.format("%.2f%%", x)
end

local function ilvlComma(x)
  x = tonumber(x) or 0
  return string.format("%.2f", x)
end

local function Safe_GetAverageItemLevel()
  if type(_G.GetAverageItemLevel) ~= "function" then return 0 end
  local a, b = _G.GetAverageItemLevel()
  local overall  = tonumber(a) or 0
  local equipped = tonumber(b) or nil
  return equipped or overall
end

local function Safe_UnitStat(statIndex)
  if type(_G.UnitStat) ~= "function" then return 0 end
  local _, effective = _G.UnitStat("player", statIndex) -- base, effective, pos, neg
  return tonumber(effective) or 0
end

local function GetPrimaryStat()
  local str   = Safe_UnitStat(1)
  local agi   = Safe_UnitStat(2)
  local intel = Safe_UnitStat(4)
  local name, val = "Strength", str
  if agi >= str and agi >= intel then name, val = "Agility", agi end
  if intel >= str and intel >= agi then name, val = "Intellect", intel end
  return name, math.floor(val + 0.5)
end

-- ===== Rating tokens =====
local CRIT_RATING_TOKEN  = _G.CR_CRIT_MELEE or _G.CR_CRIT_SPELL or _G.CR_CRIT_RANGED
local HASTE_RATING_TOKEN = _G.CR_HASTE_MELEE or _G.CR_HASTE_SPELL or _G.CR_HASTE_RANGED
local MASTERY_TOKEN      = _G.CR_MASTERY
local VERS_INC_TOKEN     = _G.CR_VERSATILITY_DAMAGE_DONE or _G.CR_VERSATILITY
local VERS_RED_TOKEN     = _G.CR_VERSATILITY_DAMAGE_TAKEN

local function Safe_GetCombatRating(token)
  if token and type(_G.GetCombatRating) == "function" then
    return tonumber(_G.GetCombatRating(token)) or 0
  end
  return 0
end

local function Safe_GetCombatRatingBonus(token)
  if token and type(_G.GetCombatRatingBonus) == "function" then
    return tonumber(_G.GetCombatRatingBonus(token)) or 0
  end
  return 0
end

-- Versatility (inc = dmg/heal increase, red = dmg taken reduction)
local function Safe_GetVersatilityBonuses(versRating)
  versRating = tonumber(versRating) or 0
  local inc, red = 0, 0

  if type(_G.GetVersatilityBonus) == "function" then
    -- Modern signature: GetVersatilityBonus(combatRating)
    local ok1, v1, v2 = pcall(_G.GetVersatilityBonus, versRating)
    if ok1 and type(v1) == "number" then
      inc, red = v1 or 0, v2 or 0
    else
      -- Older signature: GetVersatilityBonus()
      local ok2, w1, w2 = pcall(_G.GetVersatilityBonus)
      if ok2 and type(w1) == "number" then
        inc, red = w1 or 0, w2 or 0
      end
    end
  end

  -- Fallbacks
  if inc == 0 then
    inc = Safe_GetCombatRatingBonus(VERS_INC_TOKEN)
  end
  if red == 0 then
    red = VERS_RED_TOKEN and Safe_GetCombatRatingBonus(VERS_RED_TOKEN) or 0
    if red == 0 and inc > 0 then red = inc / 2 end
  end

  return inc, red
end

local function GatherStats()
  local ilvl = Safe_GetAverageItemLevel()

  local primaryName, primaryVal = GetPrimaryStat()

  local critRating  = Safe_GetCombatRating(CRIT_RATING_TOKEN)
  local hasteRating = Safe_GetCombatRating(HASTE_RATING_TOKEN)
  local mastRating  = Safe_GetCombatRating(MASTERY_TOKEN)
  local versRating  = Safe_GetCombatRating(VERS_INC_TOKEN)

  local critPct  = (type(_G.GetCritChance)    == "function" and (_G.GetCritChance() or 0)) or 0
  local hastePct = (type(_G.GetHaste)         == "function" and (_G.GetHaste() or 0)) or 0
  local mastPct  = (type(_G.GetMasteryEffect) == "function" and (_G.GetMasteryEffect() or 0)) or 0

  local versInc, versRed = Safe_GetVersatilityBonuses(versRating)

  return {
    ilvl = ilvl,
    primaryName = primaryName,
    primaryVal  = primaryVal,
    crit  = { rating = math.floor(critRating  + 0.5), pct = critPct  },
    haste = { rating = math.floor(hasteRating + 0.5), pct = hastePct },
    mast  = { rating = math.floor(mastRating  + 0.5), pct = mastPct  },
    vers  = { rating = math.floor(versRating  + 0.5), inc = versInc, red = versRed },
  }
end

-- ===== Tile =====
local API = {}

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)

  -- Read config for font sizes and visibility
  local titleSize = tonumber(cfg.titleSize) or 14
  local lineSize = tonumber(cfg.lineSize) or 12
  local hideTitle = cfg.hideTitle or false

  local rows   = hideTitle and 6 or 7  -- 6 lines, or 1 title + 6 lines
  local height = PAD_Y * 2 + rows * ROW_HEIGHT + 6
  local width  = 360
  f:SetSize(width, height)

  -- Title
  f.title = f:CreateFontString(nil, "OVERLAY", FONT_HEAD)
  UI.Outline(f.title)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_X, -PAD_Y)
  f.title:SetTextColor(1, 1, 1, 1)
  f.title:SetText(cfg.label or "Character Stats")

  -- Apply title font size using UI.Outline for consistency
  UI.Outline(f.title, { size = titleSize })

  -- Hide title if configured
  if hideTitle then
    f.title:Hide()
  end

  -- Lines
  local function makeLine(anchor, yOff)
    local fs = f:CreateFontString(nil, "OVERLAY", FONT_LINE)
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -4)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetText("...")
    UI.Outline(fs, { size = lineSize })
    return fs
  end

  local firstAnchor = hideTitle and f or f.title
  local firstYOff = hideTitle and -PAD_Y or -6

  f.line1 = makeLine(firstAnchor, firstYOff) -- iLvl
  f.line2 = makeLine(f.line1)     -- Primary
  f.line3 = makeLine(f.line2)     -- Crit
  f.line4 = makeLine(f.line3)     -- Haste
  f.line5 = makeLine(f.line4)     -- Mastery
  f.line6 = makeLine(f.line5)     -- Versatility

  -- Right-click refresh
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then
      API.update(self, cfg)
    end
  end)

  -- Update on relevant game events (gear/stat changes, spec swaps, ilvl updates)
  if f.RegisterEvent then
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("UNIT_INVENTORY_CHANGED")
    f:RegisterEvent("COMBAT_RATING_UPDATE")
    f:RegisterEvent("MASTERY_UPDATE")
    f:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
    f:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("UNIT_STATS")
    f:SetScript("OnEvent", function(self) API.update(self, cfg) end)
  end

  -- First paint
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, function() if f and f:IsShown() then API.update(f, cfg) end end)
  end
  API.update(f, cfg)

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
  -- Update font sizes and visibility
  local titleSize = tonumber(cfg.titleSize) or 14
  local lineSize = tonumber(cfg.lineSize) or 12
  local hideTitle = cfg.hideTitle or false

  -- Apply title size and visibility
  if frame.title then
    UI.Outline(frame.title, { size = titleSize })
    if hideTitle then
      frame.title:Hide()
    else
      frame.title:Show()
    end
  end

  -- Apply line size
  local lineFrames = { frame.line1, frame.line2, frame.line3, frame.line4, frame.line5, frame.line6 }
  for _, fs in ipairs(lineFrames) do
    if fs then
      UI.Outline(fs, { size = lineSize })
    end
  end

  -- Reposition first line based on title visibility
  if frame.line1 then
    frame.line1:ClearAllPoints()
    if hideTitle then
      frame.line1:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -PAD_Y)
    else
      frame.line1:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
    end
  end

  -- Update frame height based on title visibility
  local rows = hideTitle and 6 or 7
  local height = PAD_Y * 2 + rows * ROW_HEIGHT + 6
  frame:SetSize(360, height)

  local ok, S_or_err = pcall(GatherStats)
  if not ok or not S_or_err then
    frame.line1:SetText("ilvl: –")
    frame.line2:SetText("Primary: –")
    frame.line3:SetText("Critical Strike: –")
    frame.line4:SetText("Haste: –")
    frame.line5:SetText("Mastery: –")
    frame.line6:SetText("Versatility: –")
    return
  end
  local S = S_or_err

  -- Determine desired order (saved in cfg.order) with sane defaults and validation
  local DEFAULT_ORDER = { "ilvl", "primary", "crit", "haste", "mastery", "versatility" }
  local VALID = {}
  for _, k in ipairs(DEFAULT_ORDER) do VALID[k] = true end
  local function contains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end

  local order = {}
  if cfg and type(cfg.order) == "table" then
    for _, k in ipairs(cfg.order) do
      if VALID[k] and not contains(order, k) then table.insert(order, k) end
    end
  end
  -- append any missing keys to make sure we have all lines
  for _, k in ipairs(DEFAULT_ORDER) do
    if not contains(order, k) then table.insert(order, k) end
  end

  -- Prepare texts by key (format and colors to match requested style)
  local textsByKey = {
    ilvl         = ("iLvL: %s"):format(ilvlComma(S.ilvl)),
    primary      = ("%s: %d"):format(S.primaryName, S.primaryVal or 0),
    haste        = ("Haste: %s - %d"):format(       pctComma(S.haste.pct), S.haste.rating),
    crit         = ("Crit: %s - %d"):format(        pctComma(S.crit.pct),  S.crit.rating),
    versatility  = ("Vers: %s - %d"):format(        pctComma(S.vers.inc),  S.vers.rating),
    mastery      = ("Mastery: %s - %d"):format(     pctComma(S.mast.pct),  S.mast.rating),
  }
  local colorsByKey = {
    ilvl        = { 1.0, 1.0, 1.0 },
    primary     = { 0.40, 0.80, 1.00 }, -- primary stat always light blue
    haste       = { 0.20, 1.00, 0.20 },
    crit        = { 1.00, 0.20, 0.20 },
    versatility = { 0.20, 0.60, 1.00 },
    mastery     = { 1.00, 0.82, 0.00 },
  }

  -- Assign lines according to order (and apply per-line colors)
  local lines = { frame.line1, frame.line2, frame.line3, frame.line4, frame.line5, frame.line6 }
  for i = 1, #lines do
    local key = order[i] or DEFAULT_ORDER[i]
    local fs = lines[i]
    fs:SetText(textsByKey[key] or "")
    local col = colorsByKey[key] or colorsByKey.ilvl
    fs:SetTextColor(col[1], col[2], col[3], 1)
  end
end

SkyInfoTiles.RegisterTileType("charstats", API)
