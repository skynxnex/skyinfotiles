local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI

-- ===== Layout =====
local ROW_HEIGHT = 20
local PAD_X      = 8
local PAD_Y      = 6
local FONT_LINE  = "GameFontNormal"
local FONT_HEAD  = "GameFontNormalLarge"

-- ===== Primary Stat Resolution =====
-- Determine primary stat INDEX (not value) from class/spec, so we never compare secret values.
-- Stat indices: 1=Strength, 2=Agility, 4=Intellect
local STAT_STRENGTH   = 1
local STAT_AGILITY    = 2
local STAT_INTELLECT  = 4

-- Primary stat names for display
local STAT_NAMES = {
  [STAT_STRENGTH]  = "Strength",
  [STAT_AGILITY]   = "Agility",
  [STAT_INTELLECT] = "Intellect",
}

-- Returns stat index and name for the player's current class/spec, never comparing live values.
-- Caches the result on the frame and re-resolves on spec change.
local function GetPrimaryStatIndex(frame)
  -- Check cache first
  if frame._primaryStatIndex and frame._primaryStatName then
    return frame._primaryStatIndex, frame._primaryStatName
  end

  local _, englishClass = UnitClass("player")
  -- GetSpecialization() is nil until spec data loads. Defaulting to 1 and caching
  -- that would pin e.g. a Retribution paladin to Holy's Intellect for the session,
  -- so an unresolved spec is recomputed next refresh instead of being cached.
  local rawSpec = GetSpecialization and GetSpecialization() or nil
  local specIndex = rawSpec or 1
  local statIndex = nil

  -- Classes with fixed primary stat (no spec dependency)
  if englishClass == "WARRIOR" or englishClass == "DEATHKNIGHT" then
    statIndex = STAT_STRENGTH
  elseif englishClass == "ROGUE" or englishClass == "HUNTER" or englishClass == "DEMONHUNTER" then
    statIndex = STAT_AGILITY
  elseif englishClass == "MAGE" or englishClass == "WARLOCK" or englishClass == "PRIEST" or englishClass == "EVOKER" then
    statIndex = STAT_INTELLECT
  -- Spec-dependent classes
  elseif englishClass == "PALADIN" then
    if specIndex == 1 then  -- Holy
      statIndex = STAT_INTELLECT
    else  -- Protection, Retribution
      statIndex = STAT_STRENGTH
    end
  elseif englishClass == "DRUID" then
    if specIndex == 1 or specIndex == 4 then  -- Balance, Restoration
      statIndex = STAT_INTELLECT
    else  -- Feral, Guardian
      statIndex = STAT_AGILITY
    end
  elseif englishClass == "MONK" then
    if specIndex == 2 then  -- Mistweaver
      statIndex = STAT_INTELLECT
    else  -- Brewmaster, Windwalker
      statIndex = STAT_AGILITY
    end
  elseif englishClass == "SHAMAN" then
    if specIndex == 2 then  -- Enhancement
      statIndex = STAT_AGILITY
    else  -- Elemental, Restoration
      statIndex = STAT_INTELLECT
    end
  else
    -- Fallback for unknown class (should never happen)
    statIndex = STAT_STRENGTH
  end

  local statName = STAT_NAMES[statIndex] or "Primary"

  -- Cache on frame, but only once the spec is actually known
  if rawSpec then
    frame._primaryStatIndex = statIndex
    frame._primaryStatName = statName
  end

  return statIndex, statName
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

-- Forward declaration
local RefreshValues

-- ===== Throttled Refresh =====
local function QueueRefresh(frame, cfg)
  if not frame then return end
  if frame._refreshQueued then return end

  frame._refreshQueued = true
  C_Timer.After(0.15, function()
    if frame then
      local ok = pcall(RefreshValues, frame, cfg)
      if not ok then
        -- Silent error; stats may be 0 during loading
      end
    end
    if frame then
      frame._refreshQueued = nil
    end
  end)
end

-- ===== Lightweight Stat Refresh (no layout changes) =====
-- NEVER INSPECT, ALWAYS RENDER: raw API values go straight to SetFormattedText.
-- In combat, stat APIs return secret values that break arithmetic/comparison but format fine.
-- Each line wrapped in individual pcall so one failure doesn't blank the tile.
RefreshValues = function(frame, cfg)
  local showTertiary = cfg.showTertiary
  if showTertiary == nil then showTertiary = false end

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

  -- Per-line colors (unchanged from original)
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

  -- Line FontStrings
  local lines = { frame.line1, frame.line2, frame.line3, frame.line4, frame.line5, frame.line6, frame.line7, frame.line8, frame.line9 }

  -- Render helper: pcall the render function, leave previous text on error
  local function RenderLine(lineIndex, key, renderFn)
    local fs = lines[lineIndex]
    if not fs then return end

    pcall(renderFn, fs)

    -- Apply color regardless of render success
    local col = colorsByKey[key] or colorsByKey.ilvl
    fs:SetTextColor(col[1], col[2], col[3], 1)
  end

  -- Render each line in order
  for i = 1, #lines do
    local key = order[i] or DEFAULT_ORDER[i]

    if key == "ilvl" then
      RenderLine(i, key, function(fs)
        local equipped, overall = 0, 0
        if type(_G.GetAverageItemLevel) == "function" then
          overall, equipped = _G.GetAverageItemLevel()
        end
        -- Use equipped if available, else overall; raw values passed straight through
        local ilvl = (equipped and equipped > 0) and equipped or (overall or 0)
        fs:SetFormattedText("iLvL: %.2f", ilvl)
      end)

    elseif key == "primary" then
      RenderLine(i, key, function(fs)
        local statIndex, statName = GetPrimaryStatIndex(frame)
        local base, effective = 0, 0
        if type(_G.UnitStat) == "function" then
          base, effective = _G.UnitStat("player", statIndex)
        end
        -- %d truncates float, replacing math.floor(x + 0.5)
        fs:SetFormattedText("%s: %d", statName, effective)
      end)

    elseif key == "haste" then
      RenderLine(i, key, function(fs)
        local pct = 0
        if type(_G.GetHaste) == "function" then
          pct = _G.GetHaste()
        end
        local rating = 0
        if HASTE_RATING_TOKEN and type(_G.GetCombatRating) == "function" then
          rating = _G.GetCombatRating(HASTE_RATING_TOKEN)
        end
        fs:SetFormattedText("Haste: %.2f%% - %d", pct, rating)
      end)

    elseif key == "crit" then
      RenderLine(i, key, function(fs)
        local pct = 0
        if type(_G.GetCritChance) == "function" then
          pct = _G.GetCritChance()
        end
        local rating = 0
        if CRIT_RATING_TOKEN and type(_G.GetCombatRating) == "function" then
          rating = _G.GetCombatRating(CRIT_RATING_TOKEN)
        end
        fs:SetFormattedText("Crit: %.2f%% - %d", pct, rating)
      end)

    elseif key == "mastery" then
      RenderLine(i, key, function(fs)
        local pct = 0
        if type(_G.GetMasteryEffect) == "function" then
          pct = _G.GetMasteryEffect()
        end
        local rating = 0
        if MASTERY_TOKEN and type(_G.GetCombatRating) == "function" then
          rating = _G.GetCombatRating(MASTERY_TOKEN)
        end
        fs:SetFormattedText("Mastery: %.2f%% - %d", pct, rating)
      end)

    elseif key == "versatility" then
      -- The odd one out. Every other stat has a single API that already carries
      -- its buffs, but the character sheet's versatility is a SUM: the bonus from
      -- rating plus the bonus from auras (flasks, raid buffs). Adding them is
      -- arithmetic, which is exactly what the client blocks on secret values, so
      -- this is the one line that cannot recompute during combat. Out of combat
      -- it is exact; in combat the add throws, RenderLine's pcall catches it and
      -- the line keeps its last correct total rather than showing a partial one.
      RenderLine(i, key, function(fs)
        local rating = 0
        if type(_G.GetCombatRating) == "function" and VERS_INC_TOKEN then
          rating = _G.GetCombatRating(VERS_INC_TOKEN)
        end
        local fromRating = 0
        if type(_G.GetCombatRatingBonus) == "function" and VERS_INC_TOKEN then
          fromRating = _G.GetCombatRatingBonus(VERS_INC_TOKEN)
        end
        local fromAuras = 0
        if type(_G.GetVersatilityBonus) == "function" and VERS_INC_TOKEN then
          fromAuras = _G.GetVersatilityBonus(VERS_INC_TOKEN)
        end
        -- Second figure is the damage-taken reduction, the same sum over the
        -- DAMAGE_TAKEN token. Matches the character sheet's "done / reduced" pair.
        local redRating, redAuras = 0, 0
        if VERS_RED_TOKEN then
          if type(_G.GetCombatRatingBonus) == "function" then
            redRating = _G.GetCombatRatingBonus(VERS_RED_TOKEN)
          end
          if type(_G.GetVersatilityBonus) == "function" then
            redAuras = _G.GetVersatilityBonus(VERS_RED_TOKEN)
          end
        end
        fs:SetFormattedText("Vers: %.2f%%/%.2f%% - %d",
          fromRating + fromAuras, redRating + redAuras, rating)
      end)

    elseif key == "leech" then
      RenderLine(i, key, function(fs)
        local pct = 0
        if type(_G.GetCombatRatingBonus) == "function" and LEECH_TOKEN then
          pct = _G.GetCombatRatingBonus(LEECH_TOKEN)
        end
        local rating = 0
        if type(_G.GetCombatRating) == "function" and LEECH_TOKEN then
          rating = _G.GetCombatRating(LEECH_TOKEN)
        end
        fs:SetFormattedText("Leech: %.2f%% - %d", pct, rating)
      end)

    elseif key == "avoidance" then
      RenderLine(i, key, function(fs)
        local pct = 0
        if type(_G.GetCombatRatingBonus) == "function" and AVOIDANCE_TOKEN then
          pct = _G.GetCombatRatingBonus(AVOIDANCE_TOKEN)
        end
        local rating = 0
        if type(_G.GetCombatRating) == "function" and AVOIDANCE_TOKEN then
          rating = _G.GetCombatRating(AVOIDANCE_TOKEN)
        end
        fs:SetFormattedText("Avoidance: %.2f%% - %d", pct, rating)
      end)

    elseif key == "speed" then
      RenderLine(i, key, function(fs)
        local pct = 0
        if type(_G.GetCombatRatingBonus) == "function" and SPEED_TOKEN then
          pct = _G.GetCombatRatingBonus(SPEED_TOKEN)
        end
        local rating = 0
        if type(_G.GetCombatRating) == "function" and SPEED_TOKEN then
          rating = _G.GetCombatRating(SPEED_TOKEN)
        end
        fs:SetFormattedText("Speed: %.2f%% - %d", pct, rating)
      end)
    end
  end
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

  -- Right-click refresh (immediate, no throttle)
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then
      API.update(self, cfg)
    end
  end)

  -- Always-on poll: refresh stats every ~0.25s while shown (OnUpdate stops on hidden frames)
  f._pollElapsed = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    self._pollElapsed = (self._pollElapsed or 0) + elapsed
    if self._pollElapsed >= 0.25 then
      self._pollElapsed = 0
      local ok = pcall(RefreshValues, self, cfg)
      if not ok then
        -- Silent error; stats may be 0 during loading
      end
    end
  end)

  -- Update on relevant game events (gear/stat changes, spec swaps, ilvl updates, buffs/procs)
  if f.RegisterEvent and f.RegisterUnitEvent then
    -- Non-unit events
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("UNIT_INVENTORY_CHANGED")
    f:RegisterEvent("COMBAT_RATING_UPDATE")
    f:RegisterEvent("MASTERY_UPDATE")
    f:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
    f:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Combat state events (non-unit)
    f:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Combat started
    f:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Combat ended

    -- Unit-filtered events for player only (buffs, stats, haste, etc.)
    -- Guard with pcall in case event doesn't exist in this client version
    local function SafeRegisterUnitEvent(evt)
      pcall(f.RegisterUnitEvent, f, evt, "player")
    end

    SafeRegisterUnitEvent("UNIT_AURA")
    SafeRegisterUnitEvent("UNIT_STATS")
    SafeRegisterUnitEvent("UNIT_SPELL_HASTE")
    SafeRegisterUnitEvent("UNIT_ATTACK_SPEED")
    SafeRegisterUnitEvent("UNIT_RANGEDDAMAGE")
    SafeRegisterUnitEvent("UNIT_RANGED_ATTACK_POWER")
    SafeRegisterUnitEvent("UNIT_ATTACK_POWER")
    SafeRegisterUnitEvent("UNIT_DAMAGE")
    SafeRegisterUnitEvent("UNIT_RESISTANCES")

    -- Event handler with throttling for high-frequency events
    f:SetScript("OnEvent", function(self, event, ...)
      if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Spec change invalidates primary stat cache
        self._primaryStatIndex = nil
        self._primaryStatName = nil
        -- Major state changes - full update (layout + stats)
        API.update(self, cfg)
      else
        -- All other events: throttled refresh
        QueueRefresh(self, cfg)
      end
    end)
  end

  -- First paint
  f:SetScript("OnShow", function(self)
    API.update(self, cfg)
  end)
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, function() if f and f:IsShown() then API.update(f, cfg) end end)
  end
  API.update(f, cfg)

  function f:Destroy()
    -- Clear throttle flag so pending callback no-ops
    self._refreshQueued = nil
    -- Unregister events
    if self.UnregisterAllEvents then
      self:UnregisterAllEvents()
    end
    -- Clear scripts
    if self.SetScript then
      self:SetScript("OnEvent", nil)
      self:SetScript("OnShow", nil)
      self:SetScript("OnMouseUp", nil)
      self:SetScript("OnUpdate", nil)
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

  -- Update stat values (lightweight refresh)
  RefreshValues(frame, cfg)
end

SkyInfoTiles.RegisterTileType("charstats", API)
