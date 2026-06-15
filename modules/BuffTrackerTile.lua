local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Defaults
local DEFAULT_ICON_SIZE = 32
local DEFAULT_SPACING = 4
local DEFAULT_FONT = "Fonts\\FRIZQT__.ttf"
local DEFAULT_FONT_SIZE = 14
local DEFAULT_OUTLINE = "OUTLINE"
local DEFAULT_DIRECTION = "right"  -- "right", "left", "up", "down"

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

local function FormatTime(seconds)
  if seconds <= 0 then return "" end

  local minutes = math.floor(seconds / 60)
  if minutes > 0 then
    return string.format("%dm", minutes)
  else
    return string.format("%ds", math.floor(seconds))
  end
end

local function ReadCfg(cfg)
  cfg = cfg or {}
  local iconSize = tonumber(cfg.iconSize) or DEFAULT_ICON_SIZE
  local spacing = tonumber(cfg.spacing) or DEFAULT_SPACING
  local direction = cfg.direction or DEFAULT_DIRECTION
  local fontSize = tonumber(cfg.fontSize) or DEFAULT_FONT_SIZE
  local fontFile = cfg.font or DEFAULT_FONT
  local outline = cfg.outline or DEFAULT_OUTLINE
  if outline == "NONE" then outline = "" end

  return iconSize, spacing, direction, fontSize, fontFile, outline
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

  -- Clear old
  for i, frame in ipairs(f._buffFrames or {}) do
    SafeReleaseRegion(frame.icon)
    SafeReleaseRegion(frame.time)
    SafeReleaseRegion(frame)
  end
  f._buffFrames = {}

  local iconSize, spacing, direction, fontSize, fontFile, outline = ReadCfg(cfg)
  local buffList = GetBuffList(cfg)

  -- Store settings in frame for UpdateBuffDisplay
  f._iconSize = iconSize
  f._spacing = spacing
  f._direction = direction

  -- Show placeholder when empty
  if #buffList == 0 then
    local bf = CreateFrame("Frame", nil, f)
    bf:SetSize(iconSize, iconSize)
    bf:SetPoint("CENTER", f, "CENTER", 0, 0)

    bf.icon = bf:CreateTexture(nil, "ARTWORK")
    bf.icon:SetAllPoints(bf)
    bf.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    bf.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    bf.time = bf:CreateFontString(nil, "OVERLAY")
    bf.time:SetPoint("BOTTOM", bf, "BOTTOM", 0, 2)
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
      GameTooltip:SetText("BuffTracker\n\nAdd buff IDs in options (/sit)")
      GameTooltip:Show()
    end)
    bf:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
    bf:SetScript("OnDragStart", function(self)
      local parent = self:GetParent()
      if parent and parent:IsMovable() and parent.StartMoving then
        parent:StartMoving()
      end
    end)
    bf:SetScript("OnDragStop", function(self)
      local parent = self:GetParent()
      if parent then
        if parent.StopMovingOrSizing then
          parent:StopMovingOrSizing()
        end
        -- Trigger parent's OnDragStop to save position
        local parentOnDragStop = parent:GetScript("OnDragStop")
        if parentOnDragStop then
          parentOnDragStop(parent)
        end
      end
    end)

    table.insert(f._buffFrames, bf)
    f:SetSize(iconSize, iconSize)
    return
  end

  -- Create buff frames
  for i, buffID in ipairs(buffList) do
    local bf = CreateFrame("Frame", nil, f)
    bf:SetSize(iconSize, iconSize)

    -- Icon texture
    bf.icon = bf:CreateTexture(nil, "ARTWORK")
    bf.icon:SetAllPoints(bf)
    bf.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Crop borders

    -- Time text
    bf.time = bf:CreateFontString(nil, "OVERLAY")
    bf.time:SetPoint("BOTTOM", bf, "BOTTOM", 0, 2)
    bf.time:SetFont(fontFile, fontSize, outline)
    bf.time:SetTextColor(1, 1, 1, 1)
    bf.time:SetShadowColor(0, 0, 0, 1)
    bf.time:SetShadowOffset(1, -1)

    -- Tooltip with drag propagation to parent
    bf:EnableMouse(true)
    bf:RegisterForDrag("LeftButton")
    bf:SetScript("OnEnter", function(self)
      if not self.buffID then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(self.buffID)
      GameTooltip:Show()
    end)
    bf:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
    end)
    bf:SetScript("OnDragStart", function(self)
      local parent = self:GetParent()
      if parent and parent:IsMovable() and parent.StartMoving then
        parent:StartMoving()
      end
    end)
    bf:SetScript("OnDragStop", function(self)
      local parent = self:GetParent()
      if parent then
        if parent.StopMovingOrSizing then
          parent:StopMovingOrSizing()
        end
        -- Trigger parent's OnDragStop to save position
        local parentOnDragStop = parent:GetScript("OnDragStop")
        if parentOnDragStop then
          parentOnDragStop(parent)
        end
      end
    end)

    bf.buffID = buffID
    table.insert(f._buffFrames, bf)
  end

  -- Position buffs
  for i, bf in ipairs(f._buffFrames) do
    bf:ClearAllPoints()

    if i == 1 then
      bf:SetPoint("CENTER", f, "CENTER", 0, 0)
    else
      local prev = f._buffFrames[i-1]
      if direction == "right" then
        bf:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
      elseif direction == "left" then
        bf:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
      elseif direction == "down" then
        bf:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
      elseif direction == "up" then
        bf:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
      end
    end
  end

  -- Calculate frame size
  local count = #f._buffFrames
  local width, height

  if direction == "right" or direction == "left" then
    width = (iconSize * count) + (spacing * (count - 1))
    height = iconSize
  else -- up or down
    width = iconSize
    height = (iconSize * count) + (spacing * (count - 1))
  end

  f:SetSize(width, height)
end

local function UpdateBuffDisplay(f)
  if not f or not f._buffFrames then return end

  local iconSize, spacing, direction = f._iconSize or 32, f._spacing or 4, f._direction or "right"
  local visibleFrames = {}

  -- Update each buff and collect visible ones
  for _, bf in ipairs(f._buffFrames) do
    if bf.buffID then
      local info = GetBuffInfo(bf.buffID)

      -- Hide if not active, show if active
      if info.active then
        bf:Show()
        table.insert(visibleFrames, bf)

        -- Update icon
        if bf.icon then
          bf.icon:SetTexture(info.icon)
          bf.icon:SetDesaturated(false)
          bf.icon:SetAlpha(1.0)
        end

        -- Update time text
        if bf.time then
          local timeText = FormatTime(info.timeLeft)
          bf.time:SetText(timeText)
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
      bf:SetPoint("CENTER", f, "CENTER", 0, 0)
    else
      local prev = visibleFrames[i-1]
      if direction == "right" then
        bf:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
      elseif direction == "left" then
        bf:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
      elseif direction == "down" then
        bf:SetPoint("TOP", prev, "BOTTOM", 0, -spacing)
      elseif direction == "up" then
        bf:SetPoint("BOTTOM", prev, "TOP", 0, spacing)
      end
    end
  end

  -- Resize parent frame based on visible buffs
  local count = #visibleFrames
  local width, height

  if count == 0 then
    -- No buffs active, minimal size
    width, height = 1, 1
    f:Hide()
  else
    f:Show()
    if direction == "right" or direction == "left" then
      width = (iconSize * count) + (spacing * (count - 1))
      height = iconSize
    else -- up or down
      width = iconSize
      height = (iconSize * count) + (spacing * (count - 1))
    end
  end

  f:SetSize(width, height)
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)
  f:RegisterEvent("UNIT_AURA")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")

  f._buffFrames = {}

  -- Build initial layout
  RebuildBuffs(f, cfg)

  -- Event handler
  f:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
      UpdateBuffDisplay(self)
    elseif event == "UNIT_AURA" and (unit == "player" or not unit) then
      UpdateBuffDisplay(self)
    end
  end)

  -- Ticker for time updates (every second)
  if C_Timer and C_Timer.NewTicker then
    f._ticker = C_Timer.NewTicker(1, function()
      UpdateBuffDisplay(f)
    end)
  else
    f:SetScript("OnUpdate", function(self, elapsed)
      self._elapsed = (self._elapsed or 0) + elapsed
      if self._elapsed >= 1 then
        self._elapsed = 0
        UpdateBuffDisplay(self)
      end
    end)
  end

  UpdateBuffDisplay(f)

  -- Enable mouse on parent for dragging (core handles drag scripts)
  f:EnableMouse(true)

  f:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")

  function f:Destroy()
    if f._ticker and f._ticker.Cancel then
      f._ticker:Cancel()
      f._ticker = nil
    end
    self:UnregisterAllEvents()
    for _, bf in ipairs(self._buffFrames or {}) do
      SafeReleaseRegion(bf.icon)
      SafeReleaseRegion(bf.time)
      SafeReleaseRegion(bf)
    end
    self._buffFrames = {}
    if self.SetScript then
      self:SetScript("OnUpdate", nil)
      self:SetScript("OnEvent", nil)
    end
  end

  return f
end

function API.update(frame, cfg)
  if not frame then return end

  -- Rebuild layout if config changed
  RebuildBuffs(frame, cfg)
  UpdateBuffDisplay(frame)
end

SkyInfoTiles.RegisterTileType("bufftracker", API)
