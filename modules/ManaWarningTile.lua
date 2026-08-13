local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Defaults for Mana Warning tile
local DEFAULT_FONT = "Fonts\\FRIZQT__.ttf"
local DEFAULT_SIZE = 28
local DEFAULT_OUTLINE = "OUTLINE"   -- "", "OUTLINE", "THICKOUTLINE"
local DEFAULT_COLOR = { r = 0.25, g = 0.5, b = 1, a = 1 }  -- Blue
local DEFAULT_THRESHOLD = 0.20  -- 20% mana threshold
local WARNING_TEXT = "Low mana"
local GROUP_HEALER_TEXT = "Healer low mana"

local function Clamp(v, lo, hi)
  if not v then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function ReadCfg(cfg)
  cfg = cfg or {}
  local fontFile = (type(cfg.font) == "string" and cfg.font ~= "" and cfg.font) or DEFAULT_FONT
  local size = Clamp(tonumber(cfg.size) or tonumber(cfg.fontSize) or DEFAULT_SIZE, 6, 128)
  local outline = cfg.outline
  if outline == nil then outline = DEFAULT_OUTLINE end
  if outline == "NONE" then outline = "" end
  local color = cfg.color or DEFAULT_COLOR

  -- Threshold: support both fraction (0-1) and percentage (1-100)
  local threshold = tonumber(cfg.threshold) or DEFAULT_THRESHOLD
  if threshold > 1 then
    threshold = threshold / 100
  end
  threshold = Clamp(threshold, 0, 1)

  return fontFile, size, outline, color, threshold
end

local function SetFontSmart(fs, file, size, flags)
  local tries = {}
  if type(file) == "string" and file ~= "" then
    table.insert(tries, file)
    -- Try case variations (WoW fonts are inconsistent with case)
    local lowerExt = file:gsub("%.TTF$", ".ttf"):gsub("%.Ttf$", ".ttf")
    if lowerExt ~= file then table.insert(tries, lowerExt) end
    local upperExt = file:gsub("%.ttf$", ".TTF")
    if upperExt ~= file then table.insert(tries, upperExt) end
  end
  table.insert(tries, DEFAULT_FONT)
  if STANDARD_TEXT_FONT then table.insert(tries, STANDARD_TEXT_FONT) end
  -- Known built-in fonts (actual filenames from Fonts directory)
  table.insert(tries, "Fonts\\FRIZQT__.ttf")
  table.insert(tries, "Fonts\\ARIALN.ttf")
  table.insert(tries, "Fonts\\MORPHEUS.ttf")
  table.insert(tries, "Fonts\\skurri.ttf")  -- lowercase!
  table.insert(tries, "Fonts\\theboldfont.ttf")
  for _, path in ipairs(tries) do
    if fs:SetFont(path, size or DEFAULT_SIZE, flags or "") then
      return true, path
    end
  end
  return false, nil
end

local function ApplyTextStyle(fs, fontFile, size, outline, color)
  if not fs then return end

  -- SetFontSmart handles font fallback and sets the font+size+outline
  local success, usedFont = SetFontSmart(fs, fontFile or DEFAULT_FONT, size or DEFAULT_SIZE, outline or "")

  -- Apply color
  if fs.SetTextColor and color then
    fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1, (color.a ~= nil) and color.a or 1)
  end

  -- Apply shadow (consistent with UI.Outline behavior)
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)

  -- Note: We don't call UI.Outline here because it would overwrite the font we just set
  -- SetFontSmart already handles the outline parameter correctly
end

local function GetPlayerRole()
  local spec = GetSpecialization and GetSpecialization()
  if not spec then return nil end
  return GetSpecializationRole and GetSpecializationRole(spec) or nil  -- "TANK"/"HEALER"/"DAMAGER"
end

local function GetUnitManaPct(unit)
  -- Returns a 0-1 fraction, or nil if unreadable / no mana pool.
  -- WoW 12.0: UnitPowerMax/UnitPower can return "secret" values on tainted paths;
  -- comparisons AND arithmetic on secret values throw, so guard EVERYTHING in one pcall.
  local manaType = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
  local ok, pct = pcall(function()
    local maximum = UnitPowerMax(unit, manaType)
    if type(maximum) ~= "number" or maximum <= 0 then return nil end
    local current = UnitPower(unit, manaType)
    if type(current) ~= "number" then return nil end
    return current / maximum
  end)
  if not ok or type(pct) ~= "number" then
    return nil
  end
  return pct
end

local function AnyPartyHealerLowMana(threshold)
  -- Only 5-man parties (not raids). Checks each party member (excludes player).
  if not (IsInGroup and IsInGroup()) then return false end
  if IsInRaid and IsInRaid() then return false end
  local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
  -- party units are party1 .. party(n-1); player is not a partyN unit
  for i = 1, n - 1 do
    local unit = "party" .. i
    if UnitExists(unit) and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) then
      local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
      if role == "HEALER" then
        local pct = GetUnitManaPct(unit)
        if pct and pct < threshold then
          return true
        end
      end
    end
  end
  return false
end

-- Text to show given the player's role (used for preview and live warning selection).
local function RoleWarningText()
  local role = GetPlayerRole()
  if role == "TANK" then return GROUP_HEALER_TEXT end
  if role == "HEALER" then return WARNING_TEXT end
  return nil
end

local function ApplyPreviewOrClear(frame)
  -- Safe to call from tainted paths (Rebuild/UpdateAll/OnShow): does NOT read mana.
  if not frame or not frame.text then return end
  if frame._preview then
    frame.text:SetText(RoleWarningText() or WARNING_TEXT)
  else
    frame.text:SetText("")
  end
end

local function RefreshWarning(frame)
  if not frame or not frame.text then return end

  -- Preview mode: always show role-appropriate text so the tile can be positioned.
  if frame._preview then
    frame.text:SetText(RoleWarningText() or WARNING_TEXT)
    return
  end

  local role = GetPlayerRole()
  local threshold = frame._threshold or DEFAULT_THRESHOLD

  if role == "HEALER" then
    local pct = GetUnitManaPct("player")
    if pct and pct < threshold then
      frame.text:SetText(WARNING_TEXT)
    else
      frame.text:SetText("")
    end
  elseif role == "TANK" then
    if AnyPartyHealerLowMana(threshold) then
      frame.text:SetText(GROUP_HEALER_TEXT)
    else
      frame.text:SetText("")
    end
  else
    frame.text:SetText("")
  end
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)

  -- Text
  f.text = f:CreateFontString(nil, "OVERLAY")
  f.text:SetPoint("CENTER")
  f.text:SetJustifyH("CENTER")
  f.text:SetJustifyV("MIDDLE")

  -- Style + initial sizing
  local fontFile, size, outline, color, threshold = ReadCfg(cfg)
  f._threshold = threshold
  f._preview = (cfg and cfg.preview) and true or false
  ApplyTextStyle(f.text, fontFile, size, outline, color)

  -- Frame size based on text width for "Low mana" + padding
  local w = math.max(32, size * 6)  -- rough width for "Low mana"
  local h = math.max(16, size + 8)
  f:SetSize(w, h)

  -- Throttled rescan: coalesce bursts of power events. Scheduled from untainted
  -- engine events, so the mana read inside RefreshWarning runs untainted.
  local function ScheduleScan(self)
    if self._scanPending then return end
    self._scanPending = true
    if C_Timer and C_Timer.After then
      C_Timer.After(0.2, function()
        self._scanPending = false
        RefreshWarning(self)
      end)
    else
      self._scanPending = false
      RefreshWarning(self)
    end
  end

  local function OnEvent(self, event, unit)
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
      -- Only care about the player or a party member's power.
      if unit ~= "player" and not (type(unit) == "string" and unit:match("^party%d")) then
        return
      end
      ScheduleScan(self)
      return
    end
    -- Roster/role/spec/world events are infrequent; refresh immediately.
    RefreshWarning(self)
  end

  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
  -- Unfiltered power events so we also catch party members' mana (party units).
  f:RegisterEvent("UNIT_POWER_UPDATE")
  f:RegisterEvent("UNIT_MAXPOWER")
  f:RegisterEvent("UNIT_DISPLAYPOWER")

  f:SetScript("OnEvent", OnEvent)

  -- Refresh when shown
  f:SetScript("OnShow", function(self) ApplyPreviewOrClear(self) end)

  -- Ensure layers sit under major UI
  f:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")

  -- Initial update
  ApplyPreviewOrClear(f)

  function f:Destroy()
    if self.UnregisterAllEvents then
      self:UnregisterAllEvents()
    end
    if self.SetScript then
      self:SetScript("OnEvent", nil)
      self:SetScript("OnShow", nil)
    end
  end

  return f
end

function API.update(frame, cfg)
  if not frame then return end

  local fontFile, size, outline, color, threshold = ReadCfg(cfg)
  frame._threshold = threshold
  frame._preview = (cfg and cfg.preview) and true or false

  -- Check if font actually changed (only recreate when necessary)
  local needsRecreate = false
  if frame._lastFont ~= fontFile or frame._lastSize ~= size or frame._lastOutline ~= outline then
    needsRecreate = true
    frame._lastFont = fontFile
    frame._lastSize = size
    frame._lastOutline = outline
  end

  if needsRecreate and frame.text then
    -- Font changed - recreate fontstring to force visual update
    local oldText = frame.text
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
    oldText:Hide()
    oldText:SetParent(nil)
    ApplyTextStyle(frame.text, fontFile, size, outline, color)
  elseif not frame.text then
    -- First time - create fontstring
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
    ApplyTextStyle(frame.text, fontFile, size, outline, color)
  else
    -- Just update color without recreating (color can change frequently)
    ApplyTextStyle(frame.text, fontFile, size, outline, color)
  end

  -- Resize after size change
  frame:SetSize(math.max(32, size * 6), math.max(16, size + 8))

  -- Refresh warning state
  ApplyPreviewOrClear(frame)
end

SkyInfoTiles.RegisterTileType("manawarning", API)
