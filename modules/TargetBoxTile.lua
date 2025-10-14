local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Debug build signature for taint tracing
local TARGETBOX_BUILD = "TargetBoxTile/2025-10-12-r1"
local function TB_Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles(TargetBox):|r " .. tostring(msg))
  end
end

local TB_DEBUG = true -- instrumentation; set to false after validation

-- Defaults (mirrors HealthBoxTile)
local DEFAULT_W = 220
local DEFAULT_H = 22
local DEFAULT_INFO_MODE = "currentMaxPercent" -- "percent","current","currentMax","currentMaxPercent"
local DEFAULT_COLOR_HEALTH = { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
local DEFAULT_COLOR_MISSING = { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }
local DEFAULT_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 0.95 }
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local UNIT_TOKEN = "target"

local function Clamp(v, lo, hi)
  if not v then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function ReadCfg(cfg)
  cfg = cfg or {}
  local w = Clamp(tonumber(cfg.width) or DEFAULT_W, 50, 600)
  local h = Clamp(tonumber(cfg.height) or DEFAULT_H, 6, 64)
  local infoMode = cfg.infoMode or DEFAULT_INFO_MODE
  local ch = cfg.colorHealth or DEFAULT_COLOR_HEALTH
  local cm = cfg.colorMissing or DEFAULT_COLOR_MISSING
  local bc = cfg.borderColor or DEFAULT_BORDER_COLOR
  local fontFile = (type(cfg.font) == "string" and cfg.font ~= "" and cfg.font) or DEFAULT_FONT
  local useClass = not not cfg.useClassColor
  local fontSize = tonumber(cfg.fontSize) or nil
  local borderSize = Clamp(tonumber(cfg.borderSize) or 1, 0, 32)
  return w, h, infoMode, ch, cm, bc, fontFile, useClass, fontSize, borderSize
end

local function BuildText(cur, maxv, mode)
  cur = tonumber(cur) or 0
  maxv = tonumber(maxv) or 1
  if maxv <= 0 then maxv = 1 end
  local pct = math.floor(cur / maxv * 100 + 0.5)
  if mode == "percent" then
    return string.format("%d%%", pct)
  elseif mode == "current" then
    return tostring(cur)
  elseif mode == "currentMax" then
    return string.format("%d/%d", cur, maxv)
  else
    return string.format("%d/%d (%d%%)", cur, maxv, pct)
  end
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", "SkyInfoTiles_TargetBox", parent)
  -- Ensure visible by default; we avoid Show/Hide during frequent events elsewhere
  if f.SetAlpha then f:SetAlpha(1) end
  if f.Show then f:Show() end

  -- Removed method overrides to avoid tainting Frame methods; sizing is only applied out-of-combat via ApplyInitialSize()

  -- Debug-only instrumentation to trace any SetSize/SetWidth/SetHeight callers and block during combat
  if TB_DEBUG and f.SetSize and not f._dbg_origSetSize then
    f._dbg_origSetSize = f.SetSize
    f.SetSize = function(self, w, h)
      local inCombat = InCombatLockdown and InCombatLockdown()
      local stack = debugstack and debugstack(2, 8, 8) or "(no stack)"
      TB_Print(string.format("SetSize(%s,%s) inCombat=%s", tostring(w), tostring(h), tostring(inCombat)))
      if type(stack) == "string" then TB_Print(stack) end
      if inCombat then
        TB_Print("Blocked SetSize during combat.")
        return
      end
      return self:_dbg_origSetSize(w, h)
    end
  end
  if TB_DEBUG and f.SetWidth and not f._dbg_origSetWidth then
    f._dbg_origSetWidth = f.SetWidth
    f.SetWidth = function(self, w)
      local inCombat = InCombatLockdown and InCombatLockdown()
      TB_Print(string.format("SetWidth(%s) inCombat=%s", tostring(w), tostring(inCombat)))
      if inCombat then TB_Print("Blocked SetWidth during combat."); return end
      return self:_dbg_origSetWidth(w)
    end
  end
  if TB_DEBUG and f.SetHeight and not f._dbg_origSetHeight then
    f._dbg_origSetHeight = f.SetHeight
    f.SetHeight = function(self, h)
      local inCombat = InCombatLockdown and InCombatLockdown()
      TB_Print(string.format("SetHeight(%s) inCombat=%s", tostring(h), tostring(inCombat)))
      if inCombat then TB_Print("Blocked SetHeight during combat."); return end
      return self:_dbg_origSetHeight(h)
    end
  end

  -- Apply initial frame size only out of combat (safe path)
  local function ApplyInitialSize()
    local w0, h0 = ReadCfg(cfg)
    if not (InCombatLockdown and InCombatLockdown()) then
      if f.SetSize then f:SetSize(w0, h0) end
    end
  end

  -- No base textures (pure text-only tile to avoid any combat-size interactions)

  -- Border handled by custom overlay edges; no BackdropTemplate/SetBackdrop to avoid taint

  -- Text
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
  do
    local _, h, _, _, _, _, fontFile, _, fontSize = ReadCfg(cfg)
    local _, _, flags = f.text:GetFont()
    local size = math.max(6, fontSize or (h - 4))
    local ok = f.text:SetFont(fontFile or DEFAULT_FONT, size, flags or "")
    if not ok then
      if STANDARD_TEXT_FONT then
        f.text:SetFont(STANDARD_TEXT_FONT, size, flags or "")
      else
        f.text:SetFont(DEFAULT_FONT, size, flags or "")
      end
    end
  end
  UI.Outline(f.text, { weight = "THICKOUTLINE" })

  -- No initial SetSize to avoid protected calls; size is implicitly driven by child textures

  -- Disable Blizzard UnitFrame tooltip/handlers to avoid any secure path on this host frame
  f.unit = UNIT_TOKEN
  f:SetScript("OnEnter", nil)
  f:SetScript("OnLeave", nil)

  -- Secure unit button overlay for click-casting + unit menu when Locked
  -- Parent to UIParent and anchor on safe events to avoid restricted size changes on the host frame during combat
  f.secureBtn = nil
  if false then
  f.secureBtn:RegisterForClicks("AnyUp", "AnyDown")
  f.secureBtn:SetAttribute("unit", UNIT_TOKEN)
  f.secureBtn:SetAttribute("type1", "target")
  f.secureBtn:SetAttribute("type2", "togglemenu")
  f.secureBtn:SetAttribute("shift-type2", "togglemenu")
  f.secureBtn:SetAttribute("ctrl-type2", "togglemenu")
  f.secureBtn:SetAttribute("alt-type2", "togglemenu")
  if GetCVarBool then
    local onKeyDown = GetCVarBool("ActionButtonUseKeyDown")
    f.secureBtn:SetAttribute("clickcast_onkeydown", onKeyDown and true or false)
  end
  f.secureBtn:SetAttribute("clickcast_unit", UNIT_TOKEN)
  f.secureBtn.unit = UNIT_TOKEN
  if SecureUnitButton_OnLoad then
    pcall(SecureUnitButton_OnLoad, f.secureBtn, UNIT_TOKEN)
  end

  -- Anchor secure overlay: disabled (no secure overlay for Target Box)
  local function ApplySecureOverlay() end

  -- Keep the secure button in the same strata as the tile so it stays under major UI (e.g. Talents)
  f.secureBtn:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")
  f.secureBtn:SetToplevel(false)
  f.secureBtn:SetFrameLevel((f:GetFrameLevel() or 0) + 50)
  f.secureBtn.unit = UNIT_TOKEN
  -- Avoid UnitFrame_OnEnter/OnLeave on secure overlay; prevent any highlight/backdrop logic in combat
  f.secureBtn:SetScript("OnEnter", nil)
  f.secureBtn:SetScript("OnLeave", nil)
  if ClickCastFrames then ClickCastFrames[f.secureBtn] = true end
  if C_ClickBindings and C_ClickBindings.RegisterFrame then pcall(C_ClickBindings.RegisterFrame, f.secureBtn) end
  if ClickCastFrame_RegisterFrame then pcall(ClickCastFrame_RegisterFrame, f.secureBtn) end
  end

  -- Read-only display: no mouse interactivity (prevents any drag/resize paths)
  f:EnableMouse(false)
  f:SetScript("OnMouseUp", nil)
  f:SetScript("OnMouseDown", nil)

  -- Events (target changes; avoid health events to prevent restricted paths)
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
      TB_Print("Loaded " .. TARGETBOX_BUILD)
      ApplyInitialSize()
    elseif event == "PLAYER_REGEN_ENABLED" then
      ApplyInitialSize()
    end
    API.update(self, cfg, event)
  end)

  -- Throttled OnUpdate to refresh out of combat (no structural changes in combat)
  f._accum = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    self._accum = (self._accum or 0) + (elapsed or 0)
    if self._accum < 0.2 then return end
    self._accum = 0
    -- Allow text/alpha updates even during combat; we avoid structural ops in API.update
    API.update(self, cfg, "ONUPDATE")
  end)

  -- Keep Blizzard TargetFrame unchanged (do not manipulate secure visibility here)
  -- This avoids any chance of secure state changes causing implicit layout or size work during combat.
  -- If you want the default TargetFrame hidden, toggle it in another addon or via a user action out of combat.

  -- First paint
  f:SetScript("OnShow", function(self)
    API.update(self, cfg, "ONSHOW_INIT")
  end)
  API.update(f, cfg, "ONSHOW_INIT")

  function f:Destroy()
    -- Unregister click-cast
    if ClickCastFrames and self.secureBtn then ClickCastFrames[self.secureBtn] = nil end
    if C_ClickBindings and C_ClickBindings.UnregisterFrame and self.secureBtn then
      pcall(C_ClickBindings.UnregisterFrame, self.secureBtn)
    end
    if ClickCastFrame_UnregisterFrame and self.secureBtn then
      pcall(ClickCastFrame_UnregisterFrame, self.secureBtn)
    end
    -- Restore Blizzard TargetFrame
    if TargetFrame and TargetFrame.Show then
      if SkyInfoTiles then SkyInfoTiles._TargetBoxActive = nil end
      pcall(UnregisterStateDriver, TargetFrame, "visibility")
      TargetFrame:Show()
    end
  end

  return f
end


function API.update(frame, cfg, ev)
  local w, h, infoMode, colH, colM, borderC, fontFile, useClass, fontSize, borderSize = ReadCfg(cfg)

  -- Debug: detect unexpected unit events reaching TargetBox
  if ev == "UNIT_HEALTH" or ev == "UNIT_MAXHEALTH" then
    TB_Print("Unexpected unit event reached update: " .. tostring(ev))
  end

  -- No structural work occurs in combat, but we still update text/alpha safely


  local function SafeStructUpdateAllowed(evName)
    return false
  end

  -- Font
  if frame.text and frame.text.SetFont then
    local _, _, flags = frame.text:GetFont()
    local size = math.max(6, fontSize or (h - 4))
    local ok = frame.text:SetFont(fontFile or DEFAULT_FONT, size, flags or "")
    if not ok then
      if STANDARD_TEXT_FONT then
        frame.text:SetFont(STANDARD_TEXT_FONT, size, flags or "")
      else
        frame.text:SetFont(DEFAULT_FONT, size, flags or "")
      end
    end
  end

  -- Sizing moved to API.safeResize and is only applied on safe events (PLAYER_ENTERING_WORLD/PLAYER_REGEN_ENABLED).
  -- During frequent/secure events we never call frame:SetSize().

  -- Colors/foreground disabled (text-only tile)
  -- Optionally use class color of target for text tint in future, but skip structural/texture updates for safety.

  -- Border overlay disabled to remove any structural updates that could trigger restricted SetSize paths

  -- Health values for target; handle no target
  local hasTarget = UnitExists and UnitExists(UNIT_TOKEN)
  local isUnitEvent = (ev == "UNIT_HEALTH" or ev == "UNIT_MAXHEALTH")
  -- Keep the tile visible even with no target; just show placeholder text
  if not hasTarget then
    if frame.text then frame.text:SetText("No target") end
    if not isUnitEvent then
      frame:SetAlpha(1)
    end
  else
    if not isUnitEvent then
      frame:SetAlpha(1)
    end
  end
  local cur = UnitHealth and UnitHealth(UNIT_TOKEN) or 0
  local maxv = hasTarget and UnitHealthMax and UnitHealthMax(UNIT_TOKEN) or 1
  if not maxv or maxv < 1 then maxv = 1 end
  if not cur or cur < 0 then cur = 0 end
  if cur > maxv then cur = maxv end

  -- Foreground width removed (no textures used)

  -- Text
  if frame.text then
    if hasTarget then
      frame.text:SetText(BuildText(cur, maxv, infoMode))
    else
      frame.text:SetText("No target")
    end
  end

  if isUnitEvent then
    return
  end

  -- Drag/lock behavior + secure overlay mouse (skip entirely on frequent unit events)
  local isUnitEvent = (ev == "UNIT_HEALTH" or ev == "UNIT_MAXHEALTH")
  if not isUnitEvent then
    local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
    if frame.EnableMouse and frame.SetMovable then
      if not (InCombatLockdown and InCombatLockdown()) then
        frame:EnableMouse(false)
        frame:SetMovable(false)
        if frame.RegisterForDrag then
          frame:RegisterForDrag()
          frame:SetScript("OnDragStart", nil)
          frame:SetScript("OnDragStop", nil)
        end
      end
    end

    if frame.secureBtn then
      if locked then
        -- Use z-order to make the secure button interactive; avoid Show/Hide in combat
        if not (InCombatLockdown and InCombatLockdown()) then
          frame.secureBtn:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
          frame.secureBtn:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
        end
        if not InCombatLockdown or not InCombatLockdown() then
          if ClickCastFrames then ClickCastFrames[frame.secureBtn] = true end
          if C_ClickBindings and C_ClickBindings.RegisterFrame then pcall(C_ClickBindings.RegisterFrame, frame.secureBtn) end
          if ClickCastFrame_RegisterFrame then pcall(ClickCastFrame_RegisterFrame, frame.secureBtn) end
          if GetCVarBool then
            local onKeyDown = GetCVarBool("ActionButtonUseKeyDown")
            frame.secureBtn:SetAttribute("clickcast_onkeydown", onKeyDown and true or false)
          end
          frame.secureBtn:SetAttribute("clickcast_unit", UNIT_TOKEN)
          frame.secureBtn:SetAttribute("shift-type2", "togglemenu")
          frame.secureBtn:SetAttribute("ctrl-type2", "togglemenu")
          frame.secureBtn:SetAttribute("alt-type2", "togglemenu")
        end
      else
        -- Push behind when unlocked so it doesn't intercept clicks
        if not (InCombatLockdown and InCombatLockdown()) then
          frame.secureBtn:SetFrameStrata("BACKGROUND")
          frame.secureBtn:SetFrameLevel(1)
        end
      end
    end
  end
end

SkyInfoTiles.RegisterTileType("targetbox", API)
