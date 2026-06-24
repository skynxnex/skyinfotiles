local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]

local API = {}

-- Tracker type defaults (all sizes are fixed)
local TRACKER_DEFAULTS = {
  buffs = {
    iconSize = 40,
  },
  trinkets = {
    iconSize = 40,
  },
  potions = {
    iconSize = 40,
  }
}

-- Trinket slot constants
local TRINKET_SLOT_1 = 13
local TRINKET_SLOT_2 = 14

-- Tracked potions and healthstones
local TRACKED_POTIONS = {
  { itemID = 241304, spellID = 1234768, name = "Silvermoon Health Potion" },
  { itemID = 241308, spellID = 1236616, name = "Light's Potential" },
  { itemID = 5512,   spellID = 6262,    name = "Healthstone" },
  { itemID = 224464, spellID = 452930,  name = "Demonic Healthstone" },
}

-- Known player frame names from popular unit frame addons
local PLAYER_FRAME_CANDIDATES = {
  "ElvUF_Player",           -- ElvUI
  "SUFUnitplayer",          -- Shadowed Unit Frames
  "UUF_Player",             -- Luna Unit Frames
  "EllesmereUIUnitFrames_Player",  -- Ellesmere UI
  "MSUF_player",            -- Mercenary Simple Unit Frames
  "EQOLUFPlayerFrame",      -- EQOL Unit Frames
  "oUF_Player",             -- oUF (generic)
  "GwPlayerUnitFrame",      -- GW2 UI
  "PitBull4_Frames_player", -- Pitbull4
  "XPerl_Player",           -- X-Perl
  "sArenaUnitFramesplayer", -- sArena (in case it affects player frame)
}

-- Defaults
local DEFAULT_FONT = "Fonts\\FRIZQT__.ttf"
local DEFAULT_FONT_SIZE = 14
local DEFAULT_OUTLINE = "OUTLINE"
local DEFAULT_SPACING = 1

-- Helper to get saved buff list per character
local function GetCharacterKey()
  local name = UnitName("player")
  local realm = GetRealmName()
  return name .. "-" .. realm
end

local function GetBuffList(cfg)
  -- Try cfg.buffIDs first (legacy single tile config)
  if cfg and cfg.buffIDs and type(cfg.buffIDs) == "table" and #cfg.buffIDs > 0 then
    return cfg.buffIDs
  end

  -- Fall back to global per-character list
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.buffTrackerLists = SkyInfoTilesDB.buffTrackerLists or {}

  local charKey = GetCharacterKey()
  local list = SkyInfoTilesDB.buffTrackerLists[charKey]

  if not list or type(list) ~= "table" then
    -- Start with empty list
    list = {}
    SkyInfoTilesDB.buffTrackerLists[charKey] = list
  end

  return list
end

local function SaveBuffList(list)
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.buffTrackerLists = SkyInfoTilesDB.buffTrackerLists or {}

  local charKey = GetCharacterKey()
  SkyInfoTilesDB.buffTrackerLists[charKey] = list
end

-- Export for OptionsWindow
SkyInfoTiles.GetBuffTrackerList = GetBuffList
SkyInfoTiles.SaveBuffTrackerList = SaveBuffList

local function GetBuffInfo(buffID)
  -- Try C_UnitAuras (modern API)
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID)
    if auraData then
      local timeLeft = 0
      if auraData.expirationTime and auraData.expirationTime > 0 then
        timeLeft = auraData.expirationTime - GetTime()
      end
      return {
        icon = auraData.icon,
        timeLeft = timeLeft,
        duration = auraData.duration or 0,
        active = true
      }
    end
  end

  -- Fallback to UnitAura (older API)
  if UnitAura then
    for i = 1, 40 do
      local name, icon, count, dispelType, duration, expirationTime, source, isStealable,
            nameplateShowPersonal, spellId = UnitAura("player", i, "HELPFUL")
      if not name then break end
      if spellId == buffID then
        local timeLeft = 0
        if expirationTime and expirationTime > 0 then
          timeLeft = expirationTime - GetTime()
        end
        return {
          icon = icon,
          timeLeft = timeLeft,
          duration = duration or 0,
          active = true
        }
      end
    end
  end

  -- Buff not active - get icon from spell info
  local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(buffID)
  if spellInfo and spellInfo.iconID then
    return {
      icon = spellInfo.iconID,
      timeLeft = 0,
      duration = 0,
      active = false
    }
  end

  -- Fallback to old GetSpellTexture
  local icon = GetSpellTexture and GetSpellTexture(buffID)
  return {
    icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
    timeLeft = 0,
    duration = 0,
    active = false
  }
end

local function GetTrinketSlots()
  return { TRINKET_SLOT_1, TRINKET_SLOT_2 }
end

local function GetTrinketInfo(slotID)
  local itemID = GetInventoryItemID("player", slotID)

  if not itemID then
    return {
      icon = "Interface\\Icons\\INV_Misc_QuestionMark",
      timeLeft = 0,
      duration = 0,
      active = false,
      hasOnUse = false,
      itemID = nil,
      slotID = slotID
    }
  end

  -- Check if trinket has an on-use ability
  local hasOnUse = false
  if C_Item and C_Item.GetItemSpell then
    local spellName = C_Item.GetItemSpell(itemID)
    hasOnUse = spellName ~= nil
  end

  -- Get cooldown info
  local start, duration = GetInventoryItemCooldown("player", slotID)
  local timeLeft = 0
  local active = false

  if start and start > 0 and duration and duration > 0 then
    timeLeft = start + duration - GetTime()
    if timeLeft > 0 then
      active = true
    end
  end

  -- Get icon
  local icon = GetInventoryItemTexture("player", slotID) or "Interface\\Icons\\INV_Misc_QuestionMark"

  return {
    icon = icon,
    timeLeft = timeLeft,
    duration = duration or 0,
    active = active,
    hasOnUse = hasOnUse,
    itemID = itemID,
    slotID = slotID
  }
end

local function GetPotionList()
  local potionList = {}

  for _, potion in ipairs(TRACKED_POTIONS) do
    local count = C_Item.GetItemCount(potion.itemID)
    if count and count > 0 then
      table.insert(potionList, potion.itemID)
    end
  end

  return potionList
end

local function GetPotionInfo(itemID)
  -- Find potion data
  local potionData = nil
  for _, potion in ipairs(TRACKED_POTIONS) do
    if potion.itemID == itemID then
      potionData = potion
      break
    end
  end

  if not potionData then
    return {
      icon = "Interface\\Icons\\INV_Misc_QuestionMark",
      timeLeft = 0,
      duration = 0,
      active = false,
      count = 0,
      itemID = itemID
    }
  end

  -- Get item count
  local count = C_Item.GetItemCount(itemID) or 0

  -- Get cooldown info using GetItemCooldown (global function)
  local start, duration = GetItemCooldown(itemID)
  local timeLeft = 0
  local active = false

  if start and start > 0 and duration and duration > 0 then
    timeLeft = start + duration - GetTime()
    if timeLeft > 0 then
      active = true
    end
  end

  -- Get icon
  local icon = C_Item.GetItemIconByID(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"

  return {
    icon = icon,
    timeLeft = timeLeft,
    duration = duration or 0,
    active = active,
    count = count,
    itemID = itemID
  }
end

-- Tracker types registry
local TRACKER_TYPES = {
  buffs = {
    getItems = GetBuffList,
    getItemInfo = GetBuffInfo,
  },
  trinkets = {
    getItems = GetTrinketSlots,
    getItemInfo = GetTrinketInfo,
  },
  potions = {
    getItems = GetPotionList,
    getItemInfo = GetPotionInfo,
  }
}

-- Get settings object for current tracker type
local function GetTrackerSettings(cfg, trackerType)
  cfg = cfg or {}
  trackerType = trackerType or cfg.trackerType or "buffs"

  local settingsKey = trackerType .. "Settings"

  if not cfg[settingsKey] then
    cfg[settingsKey] = {}
  end

  return cfg[settingsKey], trackerType
end

-- Merge tracker-specific settings with base config
local function GetEffectiveConfig(cfg)
  local trackerType = cfg.trackerType or "buffs"
  local settings, _ = GetTrackerSettings(cfg, trackerType)

  -- Create merged config (tracker-specific settings override base config)
  local effective = {}
  for k, v in pairs(cfg) do
    effective[k] = v
  end
  for k, v in pairs(settings) do
    effective[k] = v
  end

  return effective
end

local function FormatTime(seconds)
  if seconds <= 0 then return "" end

  if seconds >= 60 then
    local minutes = math.floor(seconds / 60)
    return string.format("%dm", minutes)
  else
    return string.format("%ds", math.floor(seconds))
  end
end

-- Detects which player frame is actually visible
-- Checks addon frames first, falls back to Blizzard PlayerFrame
local function ResolvePlayerFrame()
  -- Try addon frames first (in priority order)
  for _, frameName in ipairs(PLAYER_FRAME_CANDIDATES) do
    local frame = _G[frameName]
    if frame and frame.IsShown and frame:IsShown() then
      return frame
    end
  end

  -- Fallback to Blizzard's PlayerFrame
  local blizzFrame = _G["PlayerFrame"]
  if blizzFrame and blizzFrame.IsShown and blizzFrame:IsShown() then
    return blizzFrame
  end

  -- No player frame found
  return nil
end

local function UpdateFrameAnchor(frame, cfg)
  if not frame then return end

  cfg = GetEffectiveConfig(cfg or {})
  local anchorPoint = cfg.anchorPoint or "TOPLEFT"

  -- If anchor is NONE, hide the tracker
  if anchorPoint == "NONE" then
    frame:Hide()
    return
  end

  -- Make sure frame is visible if anchor is not NONE
  frame:Show()

  local playerFrame = ResolvePlayerFrame()
  if not playerFrame then
    -- Fallback to center if no player frame
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    return
  end

  frame:ClearAllPoints()

  -- Position OUTSIDE player frame based on anchor point
  if anchorPoint == "TOPLEFT" then
    -- Above player frame, left aligned, grows up and right
    frame:SetPoint("BOTTOMLEFT", playerFrame, "TOPLEFT", 0, 0)
  elseif anchorPoint == "TOPRIGHT" then
    -- Above player frame, right aligned, grows up and left
    frame:SetPoint("BOTTOMRIGHT", playerFrame, "TOPRIGHT", 0, 0)
  elseif anchorPoint == "BOTTOMLEFT" then
    -- Below player frame, left aligned, grows down and right
    frame:SetPoint("TOPLEFT", playerFrame, "BOTTOMLEFT", 0, 0)
  elseif anchorPoint == "BOTTOMRIGHT" then
    -- Below player frame, right aligned, grows down and left
    frame:SetPoint("TOPRIGHT", playerFrame, "BOTTOMRIGHT", 0, 0)
  elseif anchorPoint == "TOP" then
    -- Above player frame, centered, grows up
    frame:SetPoint("BOTTOM", playerFrame, "TOP", 0, 0)
  elseif anchorPoint == "BOTTOM" then
    -- Below player frame, centered, grows down
    frame:SetPoint("TOP", playerFrame, "BOTTOM", 0, 0)
  else
    -- Default to TOPLEFT
    frame:SetPoint("BOTTOMLEFT", playerFrame, "TOPLEFT", 0, 0)
  end
end

local function ReadCfg(cfg)
  cfg = GetEffectiveConfig(cfg or {})

  -- Get tracker type and its defaults
  local trackerType = cfg.trackerType or "buffs"
  local defaults = TRACKER_DEFAULTS[trackerType] or TRACKER_DEFAULTS.buffs

  -- Icon size is always fixed per tracker type
  local iconSize = defaults.iconSize

  local spacing = tonumber(cfg.spacing) or DEFAULT_SPACING
  local fontSize = tonumber(cfg.fontSize) or DEFAULT_FONT_SIZE
  local fontFile = cfg.font or DEFAULT_FONT
  local outline = cfg.outline or DEFAULT_OUTLINE
  if outline == "NONE" then outline = "" end
  local anchorPoint = cfg.anchorPoint or "TOPLEFT"
  local countFontSize = tonumber(cfg.countFontSize) or 12

  -- Text offsets
  local timerOffsetX = tonumber(cfg.timerOffsetX) or 0
  local timerOffsetY = tonumber(cfg.timerOffsetY) or 4
  local countOffsetX = tonumber(cfg.countOffsetX) or -2
  local countOffsetY = tonumber(cfg.countOffsetY) or 2

  return iconSize, spacing, fontSize, fontFile, outline, anchorPoint, countFontSize, timerOffsetX, timerOffsetY, countOffsetX, countOffsetY
end

local function SafeReleaseRegion(r)
  if not r then return end
  if r.SetText then pcall(r.SetText, r, "") end
  if r.SetTexture then pcall(r.SetTexture, r, nil) end
  if r.Hide then pcall(r.Hide, r) end
  if r.ClearAllPoints then pcall(r.ClearAllPoints, r) end
  if r.SetParent then pcall(r.SetParent, r, nil) end
  if r.SetScript then
    pcall(r.SetScript, r, "OnEnter", nil)
    pcall(r.SetScript, r, "OnLeave", nil)
  end
end

local function RebuildBuffs(f, cfg)
  if not f then return end

  cfg = cfg or {}

  -- Clear old
  for _, frame in ipairs(f._buffFrames or {}) do
    SafeReleaseRegion(frame.icon)
    SafeReleaseRegion(frame.time)
    SafeReleaseRegion(frame.count)
    SafeReleaseRegion(frame)
  end
  f._buffFrames = {}

  local iconSize, spacing, fontSize, fontFile, outline, anchorPoint, countFontSize,
        timerOffsetX, timerOffsetY, countOffsetX, countOffsetY = ReadCfg(cfg)

  -- Get tracker type and registry
  local trackerType = cfg.trackerType or "buffs"
  local tracker = TRACKER_TYPES[trackerType]

  if not tracker then
    trackerType = "buffs"
    tracker = TRACKER_TYPES.buffs
  end

  local itemList = tracker.getItems(cfg)

  -- Store settings in frame for UpdateBuffDisplay
  f._iconSize = iconSize
  f._spacing = spacing
  f._anchorPoint = anchorPoint
  f._trackerType = trackerType
  f._tracker = tracker

  -- Update frame anchor
  UpdateFrameAnchor(f, cfg)

  -- Show placeholder when empty
  if #itemList == 0 then
    local bf = CreateFrame("Frame", nil, f)
    bf:SetSize(iconSize, iconSize)
    bf:SetPoint("CENTER", f, "CENTER", 0, 0)

    bf.icon = bf:CreateTexture(nil, "ARTWORK")
    bf.icon:SetAllPoints(bf)
    bf.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    bf.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    bf.time = bf:CreateFontString(nil, "OVERLAY")
    bf.time:SetPoint("CENTER", bf, "CENTER", 0, 0)
    bf.time:SetFont(fontFile, fontSize, outline)
    bf.time:SetTextColor(1, 1, 1, 1)
    bf.time:SetShadowColor(0, 0, 0, 1)
    bf.time:SetShadowOffset(1, -1)
    bf.time:SetText("Empty")

    -- Tooltip with drag propagation to parent
    bf:EnableMouse(true)
    bf:RegisterForDrag("LeftButton")
    bf:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local tooltipText = "BuffTracker\n\nTracker type: " .. trackerType
      if trackerType == "buffs" then
        tooltipText = tooltipText .. "\nAdd buff IDs in options (/sit)"
      end
      GameTooltip:SetText(tooltipText)
      GameTooltip:Show()
    end)
    bf:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
    -- No dragging in new system
    bf:SetScript("OnDragStart", nil)
    bf:SetScript("OnDragStop", nil)

    table.insert(f._buffFrames, bf)
    f:SetSize(iconSize, iconSize)
    return
  end

  -- Create item frames
  for _, itemID in ipairs(itemList) do
    local bf = CreateFrame("Frame", nil, f)
    bf:SetSize(iconSize, iconSize)

    -- Icon texture
    bf.icon = bf:CreateTexture(nil, "ARTWORK")
    bf.icon:SetAllPoints(bf)
    bf.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Crop borders

    -- Timer text (center of icon with configurable offset)
    bf.time = bf:CreateFontString(nil, "OVERLAY")
    bf.time:SetPoint("CENTER", bf, "CENTER", timerOffsetX, timerOffsetY)
    bf.time:SetFont(fontFile, fontSize, outline)
    bf.time:SetTextColor(1, 1, 1, 1)
    bf.time:SetShadowColor(0, 0, 0, 1)
    bf.time:SetShadowOffset(1, -1)

    -- Count text (bottom right corner with configurable offset)
    bf.count = bf:CreateFontString(nil, "OVERLAY")
    bf.count:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", countOffsetX, countOffsetY)
    bf.count:SetFont(fontFile, countFontSize, outline)
    bf.count:SetTextColor(1, 1, 1, 1)
    bf.count:SetShadowColor(0, 0, 0, 1)
    bf.count:SetShadowOffset(1, -1)

    -- Tooltip with drag propagation to parent
    bf:EnableMouse(true)
    bf:RegisterForDrag("LeftButton")
    bf:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

      if trackerType == "buffs" and self.itemID then
        GameTooltip:SetSpellByID(self.itemID)
      elseif trackerType == "trinkets" and self.itemID then
        GameTooltip:SetInventoryItem("player", self.slotID or 0)
      elseif trackerType == "potions" and self.itemID then
        GameTooltip:SetItemByID(self.itemID)
      end

      GameTooltip:Show()
    end)
    bf:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
    -- No dragging in new system
    bf:SetScript("OnDragStart", nil)
    bf:SetScript("OnDragStop", nil)

    bf.itemID = itemID
    if trackerType == "trinkets" then
      bf.slotID = itemID  -- For trinkets, itemID is actually slotID
    end
    table.insert(f._buffFrames, bf)
  end

  -- Position icons within container
  for i, bf in ipairs(f._buffFrames) do
    bf:ClearAllPoints()

    if i == 1 then
      -- First icon anchors to container edge based on anchor point
      if anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
        -- Right-aligned: anchor to container's TOPRIGHT
        bf:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
      else
        -- Left-aligned or centered: anchor to container's TOPLEFT
        bf:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
      end
    else
      local prev = f._buffFrames[i-1]

      -- Growth direction based on anchor point
      if anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
        -- Grows to the left
        bf:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
      else
        -- Grows to the right
        bf:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
      end
    end
  end

  -- Calculate and set container size to fit all icons
  local count = #f._buffFrames
  if count > 0 then
    local totalWidth = (iconSize * count) + (spacing * (count - 1))
    f:SetSize(totalWidth, iconSize)
  else
    f:SetSize(1, 1)
  end
end

local function UpdateBuffDisplay(f)
  if not f or not f._buffFrames then return end

  local spacing = f._spacing or 1
  local anchorPoint = f._anchorPoint or "TOPLEFT"
  local trackerType = f._trackerType or "buffs"
  local tracker = f._tracker or TRACKER_TYPES.buffs
  local visibleFrames = {}

  -- Update each item and collect visible ones
  for _, bf in ipairs(f._buffFrames) do
    if bf.itemID then
      local info = tracker.getItemInfo(bf.itemID)
      local shouldShow = false

      if trackerType == "buffs" then
        shouldShow = info.active
      elseif trackerType == "trinkets" then
        -- Show if has on-use ability (or if showPassiveTrinkets is enabled)
        shouldShow = info.hasOnUse or (f._cfg and f._cfg.showPassiveTrinkets)
      elseif trackerType == "potions" then
        -- Show if player has the potion
        shouldShow = info.count and info.count > 0
      end

      if shouldShow then
        bf:Show()
        table.insert(visibleFrames, bf)

        -- Update icon
        if bf.icon then
          bf.icon:SetTexture(info.icon)

          -- Desaturate if not on cooldown (for trinkets/potions)
          if trackerType ~= "buffs" then
            if info.active then
              bf.icon:SetDesaturated(false)
              bf.icon:SetAlpha(1.0)
            else
              bf.icon:SetDesaturated(true)
              bf.icon:SetAlpha(0.7)
            end
          else
            bf.icon:SetDesaturated(false)
            bf.icon:SetAlpha(1.0)
          end
        end

        -- Update time text
        if bf.time then
          local timeText = FormatTime(info.timeLeft)
          bf.time:SetText(timeText)
        end

        -- Update count text
        if bf.count then
          if trackerType == "potions" and info.count then
            bf.count:SetText(tostring(info.count))
            bf.count:Show()
          elseif trackerType == "trinkets" then
            -- Could show charges here if needed
            bf.count:SetText("")
            bf.count:Hide()
          else
            bf.count:SetText("")
            bf.count:Hide()
          end
        end
      else
        bf:Hide()
      end
    end
  end

  -- Reposition visible frames
  for i, bf in ipairs(visibleFrames) do
    bf:ClearAllPoints()

    if i == 1 then
      if anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
        bf:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
      else
        bf:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
      end
    else
      local prev = visibleFrames[i-1]
      if anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
        bf:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
      else
        bf:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
      end
    end
  end

  -- Resize container based on visible buffs
  local count = #visibleFrames
  local iconSize = f._iconSize or 32
  if count == 0 then
    f:Hide()
    f:SetSize(1, 1)
  else
    f:Show()
    local totalWidth = (iconSize * count) + (spacing * (count - 1))
    f:SetSize(totalWidth, iconSize)
  end
end

function API.create(parent, cfg)
  cfg = cfg or {}

  -- Create a container frame that holds all three tracker type frames
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(1, 1)  -- Will be resized based on children
  container._cfg = cfg
  container._trackerFrames = {}

  -- Create a frame for each tracker type
  local trackerTypes = {"buffs", "trinkets", "potions"}

  for _, trackerType in ipairs(trackerTypes) do
    -- Get tracker-specific settings
    local settings, _ = GetTrackerSettings(cfg, trackerType)

    -- Apply defaults for this tracker type
    if trackerType == "trinkets" and not settings._defaultsApplied then
      if settings.anchorPoint == nil then
        settings.anchorPoint = "TOPLEFT"
      end
      settings._defaultsApplied = true
    end

    if trackerType == "potions" and not settings._defaultsApplied then
      if settings.anchorPoint == nil then
        settings.anchorPoint = "BOTTOMLEFT"
      end
      settings._defaultsApplied = true
    end

    if trackerType == "buffs" and not settings._defaultsApplied then
      if settings.anchorPoint == nil then
        settings.anchorPoint = "TOP"
      end
      settings._defaultsApplied = true
    end

    -- Create effective config for this tracker type
    local trackerCfg = {}
    for k, v in pairs(cfg) do
      trackerCfg[k] = v
    end
    trackerCfg.trackerType = trackerType

    local effectiveCfg = GetEffectiveConfig(trackerCfg)

    -- Create frame for this tracker type
    local f = CreateFrame("Frame", nil, parent)
    f._cfg = trackerCfg
    f._trackerType = trackerType
    f._buffFrames = {}

    -- Register events based on tracker type
    if trackerType == "buffs" then
      f:RegisterEvent("UNIT_AURA")
      f:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif trackerType == "trinkets" then
      f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
      f:RegisterEvent("BAG_UPDATE_DELAYED")
      f:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif trackerType == "potions" then
      f:RegisterEvent("BAG_UPDATE_DELAYED")
      f:RegisterEvent("PLAYER_ENTERING_WORLD")
      f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end

    -- Event handler for this frame
    f:SetScript("OnEvent", function(self, event, unit, ...)
      local effectiveCfg = GetEffectiveConfig(self._cfg)
      if event == "PLAYER_ENTERING_WORLD" then
        UpdateBuffDisplay(self)
      elseif event == "UNIT_AURA" and self._trackerType == "buffs" then
        if unit == "player" or not unit then
          UpdateBuffDisplay(self)
        end
      elseif event == "PLAYER_EQUIPMENT_CHANGED" and self._trackerType == "trinkets" then
        local slotID = unit
        if slotID == TRINKET_SLOT_1 or slotID == TRINKET_SLOT_2 then
          RebuildBuffs(self, effectiveCfg)
          UpdateBuffDisplay(self)
        end
      elseif event == "BAG_UPDATE_DELAYED" then
        if self._trackerType == "trinkets" or self._trackerType == "potions" then
          UpdateBuffDisplay(self)
        end
      elseif event == "UNIT_SPELLCAST_SUCCEEDED" and self._trackerType == "potions" then
        if unit == "player" then
          C_Timer.After(0.1, function() UpdateBuffDisplay(self) end)
        end
      end
    end)

    -- Ticker for time updates
    if C_Timer and C_Timer.NewTicker then
      f._ticker = C_Timer.NewTicker(1, function()
        UpdateBuffDisplay(f)
      end)
    end

    -- Build initial buffs
    RebuildBuffs(f, effectiveCfg)
    UpdateBuffDisplay(f)

    f:EnableMouse(true)
    f:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")

    -- Store in container
    container._trackerFrames[trackerType] = f
  end

  -- Destruction handler for container
  function container:Destroy()
    for _, f in pairs(self._trackerFrames or {}) do
      if f._ticker and f._ticker.Cancel then
        f._ticker:Cancel()
        f._ticker = nil
      end
      f:UnregisterAllEvents()
      for _, bf in ipairs(f._buffFrames or {}) do
        SafeReleaseRegion(bf.icon)
        SafeReleaseRegion(bf.time)
        SafeReleaseRegion(bf.count)
        SafeReleaseRegion(bf)
      end
      f._buffFrames = {}
      if f.SetScript then
        f:SetScript("OnUpdate", nil)
        f:SetScript("OnEvent", nil)
      end
    end
    self._trackerFrames = {}
  end

  return container
end

function API.update(frame, cfg)
  if not frame or not frame._trackerFrames then return end

  frame._cfg = cfg

  -- Update each tracker type frame
  for trackerType, f in pairs(frame._trackerFrames) do
    if f then
      -- Update this frame's config
      local trackerCfg = {}
      for k, v in pairs(cfg) do
        trackerCfg[k] = v
      end
      trackerCfg.trackerType = trackerType
      f._cfg = trackerCfg

      local effectiveCfg = GetEffectiveConfig(trackerCfg)

      UpdateFrameAnchor(f, effectiveCfg)
      RebuildBuffs(f, effectiveCfg)
      UpdateBuffDisplay(f)
    end
  end
end

SkyInfoTiles.RegisterTileType("bufftracker", API)
