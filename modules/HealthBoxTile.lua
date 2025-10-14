local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Defaults
local DEFAULT_W = 220
local DEFAULT_H = 22
local DEFAULT_INFO_MODE = "currentMaxPercent" -- options: "percent","current","currentMax","currentMaxPercent"
local DEFAULT_COLOR_HEALTH = { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
local DEFAULT_COLOR_MISSING = { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }
local DEFAULT_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 0.95 }
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

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
  else -- "currentMaxPercent"
    return string.format("%d/%d (%d%%)", cur, maxv, pct)
  end
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")

  -- Base textures
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetPoint("TOPLEFT")
  f.bg:SetPoint("BOTTOMRIGHT")

  f.fg = f:CreateTexture(nil, "ARTWORK")
  f.fg:SetPoint("TOPLEFT")
  f.fg:SetPoint("BOTTOMLEFT")
  -- width set in update()

  -- Border as a frame around the bar
  f.border = f -- backdrop on self
  f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })

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

  -- Status icons: resting (zzz) and combat (crossed swords)
  -- Use Blizzard UI-StateIcon texture. Draw above border overlays.
  f.statusRest = f:CreateTexture(nil, "OVERLAY")
  f.statusRest:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
  f.statusRest:SetTexCoord(0, 0.5, 0, 0.421875) -- resting glyph
  f.statusRest:SetSize(14, 14)
  f.statusRest:SetPoint("LEFT", f, "LEFT", 2, 0)
  if f.statusRest.SetDrawLayer then f.statusRest:SetDrawLayer("OVERLAY", 7) end
  f.statusRest:Hide()

  f.statusCombat = f:CreateTexture(nil, "OVERLAY")
  f.statusCombat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
  f.statusCombat:SetTexCoord(0.5, 1.0, 0, 0.421875) -- combat glyph
  f.statusCombat:SetSize(14, 14)
  f.statusCombat:SetPoint("LEFT", f, "LEFT", 2, 0)
  if f.statusCombat.SetDrawLayer then f.statusCombat:SetDrawLayer("OVERLAY", 7) end
  f.statusCombat:Hide()

  -- Party leader icon
  f.statusLeader = f:CreateTexture(nil, "OVERLAY")
  f.statusLeader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
  f.statusLeader:SetSize(14, 14)
  f.statusLeader:SetPoint("LEFT", f, "LEFT", 20, 0)
  if f.statusLeader.SetDrawLayer then f.statusLeader:SetDrawLayer("OVERLAY", 7) end
  f.statusLeader:Hide()

  -- Tooltip on hover (base frame and secure overlay)
  local function ShowHealthTooltip(self)
    if not GameTooltip then return end
    local cur = (UnitHealth and UnitHealth("player")) or 0
    local maxv = (UnitHealthMax and UnitHealthMax("player")) or 1
    if maxv < 1 then maxv = 1 end
    local pct = math.floor((cur / maxv) * 100 + 0.5)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Player Health", 1, 0.82, 0)
    GameTooltip:AddLine(string.format("%d/%d (%d%%)", cur, maxv, pct), 1, 1, 1)
    GameTooltip:Show()
  end
  f.unit = "player"
  f:SetScript("OnEnter", UnitFrame_OnEnter)
  f:SetScript("OnLeave", UnitFrame_OnLeave)

  -- Secure unit button overlay to emulate PlayerFrame behavior when locked
  f.secureBtn = CreateFrame("Button", nil, f, "SecureUnitButtonTemplate")
  f.secureBtn:SetAllPoints(f)
  f.secureBtn:RegisterForClicks("AnyUp", "AnyDown")
  f.secureBtn:SetAttribute("unit", "player")
  f.secureBtn:SetAttribute("type1", "target")
  -- Retail supports 'togglemenu' for right-click unit menu securely
  f.secureBtn:SetAttribute("type2", "togglemenu")
  f.secureBtn:SetAttribute("shift-type2", "togglemenu")
  f.secureBtn:SetAttribute("ctrl-type2", "togglemenu")
  f.secureBtn:SetAttribute("alt-type2", "togglemenu")
  -- Inform Click Casting about press behavior and explicit unit
  if GetCVarBool then
    local onKeyDown = GetCVarBool("ActionButtonUseKeyDown")
    f.secureBtn:SetAttribute("clickcast_onkeydown", onKeyDown and true or false)
  end
  f.secureBtn:SetAttribute("clickcast_unit", "player")
  -- Help older click-cast code paths that read .unit instead of the attribute
  f.secureBtn.unit = "player"
  -- Ensure Blizzard helper sets up full secure unit button defaults and registers with click-casting
  if SecureUnitButton_OnLoad then
    pcall(SecureUnitButton_OnLoad, f.secureBtn, "player")
  end

  -- Keep the secure button in the same strata as the tile so it stays under major UI (e.g. Talents)
  f.secureBtn:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")
  f.secureBtn:SetToplevel(false)
  f.secureBtn:SetFrameLevel((f:GetFrameLevel() or 0) + 50)
  f.secureBtn.unit = "player"
  f.secureBtn:SetScript("OnEnter", UnitFrame_OnEnter)
  f.secureBtn:SetScript("OnLeave", UnitFrame_OnLeave)
  -- Register with Blizzard Click Casting so bindings (e.g. shift+left) apply to this unit frame
  if ClickCastFrames then
    ClickCastFrames[f.secureBtn] = true
  end
  -- Retail API registration (if available)
  if C_ClickBindings and C_ClickBindings.RegisterFrame then
    pcall(C_ClickBindings.RegisterFrame, f.secureBtn)
  end
  -- Older API fallback (if present on client)
  if ClickCastFrame_RegisterFrame then
    pcall(ClickCastFrame_RegisterFrame, f.secureBtn)
  end

  -- Mouse for drag + refresh
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
    if locked then
      -- Secure overlay handles clicks while locked
      return
    end
    if btn == "LeftButton" then
      if self.StopMovingOrSizing then self:StopMovingOrSizing() end
      local point, _, _, x, y = self:GetPoint()
      if self._cfg then self._cfg.point, self._cfg.x, self._cfg.y = point, x, y end
      return
    end
    if btn == "RightButton" then
      API.update(self, cfg)
    end
  end)
  f:SetScript("OnMouseDown", function(self, btn)
    if not (SkyInfoTilesDB and SkyInfoTilesDB.locked) and btn == "LeftButton" then
      if self.StartMoving then self:StartMoving() end
    end
  end)

  -- Events to refresh on health changes
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_UPDATE_RESTING")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("PARTY_LEADER_CHANGED")
  f:RegisterEvent("UNIT_HEALTH")
  f:RegisterEvent("UNIT_MAXHEALTH")
  f:RegisterEvent("PLAYER_DEAD")
  f:RegisterEvent("PLAYER_ALIVE")
  f:RegisterEvent("PLAYER_UNGHOST")
  f:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
      if arg1 ~= "player" then return end
    end
    API.update(self, cfg)
  end)

  -- Hide Blizzard PlayerFrame using secure visibility driver (combat-safe)
  if PlayerFrame then
    SkyInfoTiles._HealthBoxActive = true
    local function ApplyPlayerFrameDriver()
      if InCombatLockdown and InCombatLockdown() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
          self:UnregisterEvent("PLAYER_REGEN_ENABLED")
          if PlayerFrame then
            pcall(UnregisterStateDriver, PlayerFrame, "visibility")
            pcall(RegisterStateDriver, PlayerFrame, "visibility", "hide")
          end
        end)
      else
        pcall(UnregisterStateDriver, PlayerFrame, "visibility")
        pcall(RegisterStateDriver, PlayerFrame, "visibility", "hide")
      end
    end
    ApplyPlayerFrameDriver()
  end

  -- Initial paint
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)
  API.update(f, cfg)

  function f:Destroy()
    -- Unregister from Click Casting
    if ClickCastFrames and self.secureBtn then
      ClickCastFrames[self.secureBtn] = nil
    end
    if C_ClickBindings and C_ClickBindings.UnregisterFrame and self.secureBtn then
      pcall(C_ClickBindings.UnregisterFrame, self.secureBtn)
    end
    if ClickCastFrame_UnregisterFrame and self.secureBtn then
      pcall(ClickCastFrame_UnregisterFrame, self.secureBtn)
    end
    -- Restore Blizzard PlayerFrame on destroy
    if PlayerFrame and PlayerFrame.Show then
      if SkyInfoTiles then SkyInfoTiles._HealthBoxActive = nil end
      pcall(UnregisterStateDriver, PlayerFrame, "visibility")
      PlayerFrame:Show()
    end
  end
  return f
end

function API.update(frame, cfg)
  local w, h, infoMode, colH, colM, borderC, fontFile, useClass, fontSize, borderSize = ReadCfg(cfg)

  -- Apply font (scale with height)
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

  -- Resolve class color if requested
  if useClass then
    local class = (UnitClass and select(2, UnitClass("player"))) or nil
    local tbl = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local c = (tbl and class) and tbl[class] or nil
    if c then
      colH = { r = c.r, g = c.g, b = c.b, a = (colH and colH.a) or 1 }
    end
  end

  -- Sizing
  frame:SetSize(w, h)

  -- Colors
  if frame.bg.SetColorTexture then
    frame.bg:SetColorTexture(colM.r or 0, colM.g or 0, colM.b or 0, colM.a or 1)
  else
    frame.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.bg:SetVertexColor(colM.r or 0, colM.g or 0, colM.b or 0, 1)
    frame.bg:SetAlpha((colM.a ~= nil) and colM.a or 1)
  end
  if frame.fg.SetColorTexture then
    frame.fg:SetColorTexture(colH.r or 0, colH.g or 1, colH.b or 0, colH.a or 1)
  else
    frame.fg:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.fg:SetVertexColor(colH.r or 0, colH.g or 1, colH.b or 0, 1)
    frame.fg:SetAlpha((colH.a ~= nil) and colH.a or 1)
  end
  if frame.SetBackdrop then
    frame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = borderSize or 1 })
  end
  if frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(borderC.r or 0, borderC.g or 0, borderC.b or 0, borderC.a or 1)
  end

  -- Ensure visible variable-thickness border across clients by drawing 4 edge textures
  -- Draw border above the secure button by using a dedicated overlay frame
  frame._edgeF = frame._edgeF or CreateFrame("Frame", nil, frame)
  frame._edgeF:SetAllPoints(frame)
  -- Draw border in the same strata as the tile so it doesn't overlay major UI
  frame._edgeF:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
  if frame.secureBtn and frame.secureBtn.GetFrameLevel then
    frame._edgeF:SetFrameLevel(frame.secureBtn:GetFrameLevel() + 1)
  else
    frame._edgeF:SetFrameLevel((frame:GetFrameLevel() or 0) + 200)
  end

  frame._edgeT = frame._edgeT or frame._edgeF:CreateTexture(nil, "OVERLAY")
  frame._edgeB = frame._edgeB or frame._edgeF:CreateTexture(nil, "OVERLAY")
  frame._edgeL = frame._edgeL or frame._edgeF:CreateTexture(nil, "OVERLAY")
  frame._edgeR = frame._edgeR or frame._edgeF:CreateTexture(nil, "OVERLAY")
  if frame._edgeT.SetDrawLayer then
    frame._edgeT:SetDrawLayer("OVERLAY", 7)
    frame._edgeB:SetDrawLayer("OVERLAY", 7)
    frame._edgeL:SetDrawLayer("OVERLAY", 7)
    frame._edgeR:SetDrawLayer("OVERLAY", 7)
  end

  local function ApplyEdgeStyle(tex)
    if not tex then return end
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    tex:SetVertexColor(borderC.r or 0, borderC.g or 0, borderC.b or 0, borderC.a or 1)
    if (borderSize or 0) <= 0 then tex:Hide() else tex:Show() end
  end
  ApplyEdgeStyle(frame._edgeT)
  ApplyEdgeStyle(frame._edgeB)
  ApplyEdgeStyle(frame._edgeL)
  ApplyEdgeStyle(frame._edgeR)

  if (borderSize or 0) > 0 then
    frame._edgeT:ClearAllPoints(); frame._edgeT:SetPoint("TOPLEFT");    frame._edgeT:SetPoint("TOPRIGHT");    frame._edgeT:SetHeight(borderSize)
    frame._edgeB:ClearAllPoints(); frame._edgeB:SetPoint("BOTTOMLEFT"); frame._edgeB:SetPoint("BOTTOMRIGHT"); frame._edgeB:SetHeight(borderSize)
    frame._edgeL:ClearAllPoints(); frame._edgeL:SetPoint("TOPLEFT");    frame._edgeL:SetPoint("BOTTOMLEFT");  frame._edgeL:SetWidth(borderSize)
    frame._edgeR:ClearAllPoints(); frame._edgeR:SetPoint("TOPRIGHT");   frame._edgeR:SetPoint("BOTTOMRIGHT"); frame._edgeR:SetWidth(borderSize)
  end

  -- Health values
  local cur = UnitHealth and UnitHealth("player") or 0
  local maxv = UnitHealthMax and UnitHealthMax("player") or 1
  if not maxv or maxv < 1 then maxv = 1 end
  if not cur or cur < 0 then cur = 0 end
  if cur > maxv then cur = maxv end

  local ratio = maxv > 0 and (cur / maxv) or 0
  local fgW = math.max(0, math.floor(w * ratio + 0.5))
  frame.fg:SetWidth(fgW)

  -- Text
  if frame.text then
    frame.text:SetText(BuildText(cur, maxv, infoMode))
  end

  -- Status icons visibility
  local inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or false
  local isResting = (IsResting and IsResting()) or false
  if frame.statusRest and frame.statusCombat then
    if inCombat then
      frame.statusCombat:Show()
      frame.statusRest:Hide()
    elseif isResting then
      frame.statusRest:Show()
      frame.statusCombat:Hide()
    else
      frame.statusRest:Hide()
      frame.statusCombat:Hide()
    end
  end

  -- Leader icon visibility
  if frame.statusLeader then
    local inGroup = (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) or false
    local isLeader = (UnitIsGroupLeader and UnitIsGroupLeader("player")) or false
    if inGroup and isLeader then
      frame.statusLeader:Show()
    else
      frame.statusLeader:Hide()
    end
  end

  -- Drag/lock behavior
  local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
  if frame.EnableMouse and frame.SetMovable then
    frame:EnableMouse(true)
    frame:SetMovable(not locked)
    if not locked and frame.RegisterForDrag then
      frame:RegisterForDrag("LeftButton")
      frame:SetScript("OnDragStart", frame.StartMoving)
      frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, X, Y = self:GetPoint()
        if self._cfg then self._cfg.point, self._cfg.x, self._cfg.y = point, X, Y end
      end)
    elseif frame.RegisterForDrag then
      frame:RegisterForDrag()
      frame:SetScript("OnDragStart", nil)
      frame:SetScript("OnDragStop", nil)
    end
  end

  -- Secure button overlay click handling when locked (z-order only; no Show/Hide to avoid taint)
  if frame.secureBtn then
    if locked then
      -- Bring overlay above the tile to receive clicks
      if not (InCombatLockdown and InCombatLockdown()) then
        frame.secureBtn:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
        frame.secureBtn:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
      end
      -- Re-register with Click Casting on lock (out of combat) to ensure latest bindings (incl. SHIFT modifiers) are applied
      if not InCombatLockdown or not InCombatLockdown() then
        if ClickCastFrames then ClickCastFrames[frame.secureBtn] = true end
        if C_ClickBindings and C_ClickBindings.RegisterFrame then pcall(C_ClickBindings.RegisterFrame, frame.secureBtn) end
        if ClickCastFrame_RegisterFrame then pcall(ClickCastFrame_RegisterFrame, frame.secureBtn) end
        if GetCVarBool then
          local onKeyDown = GetCVarBool("ActionButtonUseKeyDown")
          frame.secureBtn:SetAttribute("clickcast_onkeydown", onKeyDown and true or false)
        end
        frame.secureBtn:SetAttribute("clickcast_unit", "player")
        frame.secureBtn:SetAttribute("shift-type2", "togglemenu")
        frame.secureBtn:SetAttribute("ctrl-type2", "togglemenu")
        frame.secureBtn:SetAttribute("alt-type2", "togglemenu")
      end
    else
      -- Push overlay behind so base frame receives clicks; appears inert to mouse
      if not (InCombatLockdown and InCombatLockdown()) then
        frame.secureBtn:SetFrameStrata("BACKGROUND")
        frame.secureBtn:SetFrameLevel(1)
      end
    end
  end
end

SkyInfoTiles.RegisterTileType("healthbox", API)
