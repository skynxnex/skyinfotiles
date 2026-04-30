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
  local ok, a, b = pcall(_G.GetAverageItemLevel)
  if not ok then return 0 end
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
-- Tertiary stats
local LEECH_TOKEN        = _G.CR_LIFESTEAL or 36
local AVOIDANCE_TOKEN    = _G.CR_AVOIDANCE or 37
local SPEED_TOKEN        = _G.CR_SPEED or 38

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

  local critPct = 0
  local hastePct = 0
  local mastPct = 0

  if type(_G.GetCritChance) == "function" then
    local ok, val = pcall(_G.GetCritChance)
    critPct = (ok and tonumber(val)) or 0
  end

  if type(_G.GetHaste) == "function" then
    local ok, val = pcall(_G.GetHaste)
    hastePct = (ok and tonumber(val)) or 0
  end

  if type(_G.GetMasteryEffect) == "function" then
    local ok, val = pcall(_G.GetMasteryEffect)
    mastPct = (ok and tonumber(val)) or 0
  end

  local versInc, versRed = Safe_GetVersatilityBonuses(versRating)

  -- Tertiary stats
  local leechRating = Safe_GetCombatRating(LEECH_TOKEN)
  local leechPct = Safe_GetCombatRatingBonus(LEECH_TOKEN)
  local avoidRating = Safe_GetCombatRating(AVOIDANCE_TOKEN)
  local avoidPct = Safe_GetCombatRatingBonus(AVOIDANCE_TOKEN)
  local speedRating = Safe_GetCombatRating(SPEED_TOKEN)
  local speedPct = Safe_GetCombatRatingBonus(SPEED_TOKEN)

  return {
    ilvl = ilvl,
    primaryName = primaryName,
    primaryVal  = primaryVal,
    crit  = { rating = math.floor(critRating  + 0.5), pct = critPct  },
    haste = { rating = math.floor(hasteRating + 0.5), pct = hastePct },
    mast  = { rating = math.floor(mastRating  + 0.5), pct = mastPct  },
    vers  = { rating = math.floor(versRating  + 0.5), inc = versInc, red = versRed },
    leech = { rating = math.floor(leechRating + 0.5), pct = leechPct },
    avoid = { rating = math.floor(avoidRating + 0.5), pct = avoidPct },
    speed = { rating = math.floor(speedRating + 0.5), pct = speedPct },
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
  local showTertiary = cfg.showTertiary
  if showTertiary == nil then showTertiary = false end

  local rows = 6  -- base stats
  if showTertiary then rows = rows + 4 end  -- +3 tertiary stats + 1 for divider spacing
  if not hideTitle then rows = rows + 1 end  -- +1 for title
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

  -- Divider (horizontal line separator)
  f.divider = f:CreateTexture(nil, "OVERLAY")
  f.divider:SetTexture("Interface\\Buttons\\WHITE8x8")
  f.divider:SetColorTexture(0.4, 0.4, 0.4, 0.5)
  f.divider:SetHeight(1)
  f.divider:SetPoint("TOPLEFT", f.line6, "BOTTOMLEFT", 0, -8)
  f.divider:SetPoint("TOPRIGHT", f.line6, "BOTTOMRIGHT", 0, -8)
  if not showTertiary then
    f.divider:Hide()
  end

  -- Tertiary stats (hidden by default)
  f.line7 = makeLine(f.divider, -6)     -- Leech
  f.line8 = makeLine(f.line7)           -- Avoidance
  f.line9 = makeLine(f.line8)           -- Speed
  if not showTertiary then
    f.line7:Hide()
    f.line8:Hide()
    f.line9:Hide()
  end

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
    f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Combat ended - refresh stats
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
  local showTertiary = cfg.showTertiary
  if showTertiary == nil then showTertiary = false end

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
  local lineFrames = { frame.line1, frame.line2, frame.line3, frame.line4, frame.line5, frame.line6, frame.line7, frame.line8, frame.line9 }
  for _, fs in ipairs(lineFrames) do
    if fs then
      UI.Outline(fs, { size = lineSize })
    end
  end

  -- Show/hide tertiary stats and divider
  if frame.divider then
    if showTertiary then
      frame.divider:Show()
    else
      frame.divider:Hide()
    end
  end

  if frame.line7 then
    if showTertiary then frame.line7:Show() else frame.line7:Hide() end
  end
  if frame.line8 then
    if showTertiary then frame.line8:Show() else frame.line8:Hide() end
  end
  if frame.line9 then
    if showTertiary then frame.line9:Show() else frame.line9:Hide() end
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

  -- Update frame height based on title and tertiary visibility
  local rows = 6  -- base stats
  if showTertiary then rows = rows + 4 end  -- +3 tertiary stats + 1 for divider spacing
  if not hideTitle then rows = rows + 1 end  -- +1 for title
  local newHeight = PAD_Y * 2 + rows * ROW_HEIGHT + 6

  -- Adjust position to keep top in same place when showTertiary setting changes
  if frame._cfg then
    -- Check if showTertiary state changed (not just height)
    local lastShowTertiary = frame._cfg._lastShowTertiary
    if lastShowTertiary ~= showTertiary then
      -- Convert to CENTER coordinates if not already
      if not frame._cfg.point or frame._cfg.point ~= "CENTER" then
        local frameCenterX, frameCenterY = frame:GetCenter()
        if frameCenterX and frameCenterY then
          local screenCenterX, screenCenterY = UIParent:GetCenter()
          if screenCenterX and screenCenterY then
            frame._cfg.x = math.floor(frameCenterX - screenCenterX + 0.5)
            frame._cfg.y = math.floor(frameCenterY - screenCenterY + 0.5)
            frame._cfg.point = "CENTER"
          end
        end
      end

      -- Calculate old and new heights based on showTertiary setting
      local oldRows = 6
      if lastShowTertiary then oldRows = oldRows + 4 end
      if not hideTitle then oldRows = oldRows + 1 end
      local oldHeight = PAD_Y * 2 + oldRows * ROW_HEIGHT + 6

      if lastShowTertiary ~= nil then  -- Skip on first run
        local currentCenterY = frame._cfg.y or 0
        -- Calculate where the top currently is (based on OLD height)
        local currentTopY = currentCenterY + (oldHeight / 2)
        -- Calculate new center Y to keep top at the same position
        local newCenterY = currentTopY - (newHeight / 2)
        frame._cfg.y = math.floor(newCenterY + 0.5)

        -- Update actual position
        if not (InCombatLockdown and InCombatLockdown()) then
          frame:ClearAllPoints()
          frame:SetPoint("CENTER", UIParent, "CENTER", frame._cfg.x or 0, frame._cfg.y)
        end
      end

      -- Remember current state
      frame._cfg._lastShowTertiary = showTertiary
    end
  end

  frame:SetSize(360, newHeight)

  -- Try to gather current stats
  local ok, S_or_err = pcall(GatherStats)
  local S = nil

  -- Validate if stats are reasonable (ilvl > 0 means we got real data)
  local function isValidStats(stats)
    return stats and stats.ilvl and stats.ilvl > 0
  end

  if ok and isValidStats(S_or_err) then
    -- Success with valid data - cache and use it
    S = S_or_err
    frame._cachedStats = S
  elseif frame._cachedStats and isValidStats(frame._cachedStats) then
    -- Failed or invalid data, but we have valid cached data - use cache
    S = frame._cachedStats
  else
    -- No valid cached data - initialize with current attempt or empty defaults
    if ok and S_or_err then
      S = S_or_err
    else
      S = {
        ilvl = 0,
        primaryName = "Primary",
        primaryVal = 0,
        crit = { rating = 0, pct = 0 },
        haste = { rating = 0, pct = 0 },
        mast = { rating = 0, pct = 0 },
        vers = { rating = 0, inc = 0, red = 0 },
        leech = { rating = 0, pct = 0 },
        avoid = { rating = 0, pct = 0 },
        speed = { rating = 0, pct = 0 },
      }
    end
  end

  -- Determine desired order (saved in cfg.order) with sane defaults and validation
  local DEFAULT_ORDER_BASE = { "ilvl", "primary", "crit", "haste", "mastery", "versatility" }
  local DEFAULT_ORDER_TERTIARY = { "leech", "avoidance", "speed" }
  local DEFAULT_ORDER = {}
  for _, k in ipairs(DEFAULT_ORDER_BASE) do table.insert(DEFAULT_ORDER, k) end
  if showTertiary then
    for _, k in ipairs(DEFAULT_ORDER_TERTIARY) do table.insert(DEFAULT_ORDER, k) end
  end

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
    leech        = ("Leech: %s - %d"):format(       pctComma(S.leech.pct), S.leech.rating),
    avoidance    = ("Avoidance: %s - %d"):format(   pctComma(S.avoid.pct), S.avoid.rating),
    speed        = ("Speed: %s - %d"):format(       pctComma(S.speed.pct), S.speed.rating),
  }
  local colorsByKey = {
    ilvl        = { 1.0, 1.0, 1.0 },
    primary     = { 0.40, 0.80, 1.00 }, -- primary stat always light blue
    haste       = { 0.20, 1.00, 0.20 },
    crit        = { 1.00, 0.20, 0.20 },
    versatility = { 0.20, 0.60, 1.00 },
    mastery     = { 1.00, 0.82, 0.00 },
    leech       = { 0.80, 0.20, 0.80 }, -- purple
    avoidance   = { 1.00, 0.60, 0.20 }, -- orange
    speed       = { 0.40, 1.00, 0.80 }, -- cyan/teal
  }

  -- Assign lines according to order (and apply per-line colors)
  local lines = { frame.line1, frame.line2, frame.line3, frame.line4, frame.line5, frame.line6, frame.line7, frame.line8, frame.line9 }
  for i = 1, #lines do
    local key = order[i] or DEFAULT_ORDER[i]
    local fs = lines[i]
    fs:SetText(textsByKey[key] or "")
    local col = colorsByKey[key] or colorsByKey.ilvl
    fs:SetTextColor(col[1], col[2], col[3], 1)
  end
end

SkyInfoTiles.RegisterTileType("charstats", API)
