local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Defaults (mirrors Health/Target Box)
local DEFAULT_W = 220
local DEFAULT_H = 22
local DEFAULT_INFO_MODE = "currentMaxPercent" -- "percent","current","currentMax","currentMaxPercent"
local DEFAULT_COLOR_HEALTH = { r = 0.12, g = 0.82, b = 0.26, a = 1.0 }
local DEFAULT_COLOR_MISSING = { r = 0.15, g = 0.15, b = 0.15, a = 0.85 }
local DEFAULT_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 0.95 }
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local UNIT_TOKEN = "pet"

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
  local useClass = not not cfg.useClassColor -- usually false for pets; kept for parity
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
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")

  -- Base textures
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetPoint("TOPLEFT")
  f.bg:SetPoint("BOTTOMRIGHT")

  f.fg = f:CreateTexture(nil, "ARTWORK")
  f.fg:SetPoint("TOPLEFT")
  f.fg:SetPoint("BOTTOMLEFT")

  -- Border backdrop (1px; custom overlay will handle thickness)
  f.border = f
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

  -- Blizzard internal tooltip
  f.unit = UNIT_TOKEN
  f:SetScript("OnEnter", UnitFrame_OnEnter)
  f:SetScript("OnLeave", UnitFrame_OnLeave)

  -- Secure unit button overlay for pet (target and menu)
  f.secureBtn = CreateFrame("Button", nil, f, "SecureUnitButtonTemplate")
  f.secureBtn:SetAllPoints(f)
  f.secureBtn:RegisterForClicks("AnyUp", "AnyDown")
  f.secureBtn:SetAttribute("unit", UNIT_TOKEN)
  f.secureBtn:SetAttribute("type1", "target")
  f.secureBtn:SetAttribute("type2", "togglemenu")
  f.secureBtn:SetAttribute("shift-type2", "togglemenu")
  f.secureBtn:SetAttribute("ctrl-type2", "togglemenu")
  f.secureBtn:SetAttribute("alt-type2", "togglemenu")
  do
    local onKeyDown = nil
    if C_CVar and C_CVar.GetCVarBool then
      onKeyDown = C_CVar.GetCVarBool("ActionButtonUseKeyDown")
    elseif GetCVarBool then
      onKeyDown = GetCVarBool("ActionButtonUseKeyDown")
    end
    if onKeyDown ~= nil then
      f.secureBtn:SetAttribute("clickcast_onkeydown", onKeyDown and true or false)
    end
  end
  f.secureBtn:SetAttribute("clickcast_unit", UNIT_TOKEN)
  f.secureBtn.unit = UNIT_TOKEN
  if SecureUnitButton_OnLoad then
    pcall(SecureUnitButton_OnLoad, f.secureBtn, UNIT_TOKEN)
  end
  -- Keep overlays under major UI
  f.secureBtn:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")
  f.secureBtn:SetToplevel(false)
  f.secureBtn:SetFrameLevel((f:GetFrameLevel() or 0) + 50)
  f.secureBtn:Hide()
  f.secureBtn:SetScript("OnEnter", UnitFrame_OnEnter)
  f.secureBtn:SetScript("OnLeave", UnitFrame_OnLeave)
  if ClickCastFrames then ClickCastFrames[f.secureBtn] = true end
  if C_ClickBindings and C_ClickBindings.RegisterFrame then pcall(C_ClickBindings.RegisterFrame, f.secureBtn) end
  if ClickCastFrame_RegisterFrame then pcall(ClickCastFrame_RegisterFrame, f.secureBtn) end

  -- Drag/refresh
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
    if locked then return end
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

  -- Events (pet existence + health)
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("UNIT_PET")         -- arg1 == "player"
  f:RegisterEvent("UNIT_HEALTH")
  f:RegisterEvent("UNIT_MAXHEALTH")
  f:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
      if arg1 ~= UNIT_TOKEN then return end
    elseif event == "UNIT_PET" then
      if arg1 ~= "player" then return end
    end
    API.update(self, cfg)
  end)

  -- Hide Blizzard PetFrame using secure visibility driver (combat-safe)
  if PetFrame then
    SkyInfoTiles._PetBoxActive = true
    local function ApplyPetFrameDriver()
      if InCombatLockdown and InCombatLockdown() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
          self:UnregisterEvent("PLAYER_REGEN_ENABLED")
          if PetFrame then
            pcall(UnregisterStateDriver, PetFrame, "visibility")
            pcall(RegisterStateDriver, PetFrame, "visibility", "hide")
          end
        end)
      else
        pcall(UnregisterStateDriver, PetFrame, "visibility")
        pcall(RegisterStateDriver, PetFrame, "visibility", "hide")
      end
    end
    ApplyPetFrameDriver()
  end

  -- Initial paint
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)
  API.update(f, cfg)

  function f:Destroy()
    -- Click cast cleanup
    if ClickCastFrames and self.secureBtn then ClickCastFrames[self.secureBtn] = nil end
    if C_ClickBindings and C_ClickBindings.UnregisterFrame and self.secureBtn then
      pcall(C_ClickBindings.UnregisterFrame, self.secureBtn)
    end
    if ClickCastFrame_UnregisterFrame and self.secureBtn then
      pcall(ClickCastFrame_UnregisterFrame, self.secureBtn)
    end
    -- Restore Blizzard PetFrame
    if PetFrame and PetFrame.Show then
      if SkyInfoTiles then SkyInfoTiles._PetBoxActive = nil end
      pcall(UnregisterStateDriver, PetFrame, "visibility")
      PetFrame:Show()
    end
  end

  return f
end

function API.update(frame, cfg)
  local w, h, infoMode, colH, colM, borderC, fontFile, useClass, fontSize, borderSize = ReadCfg(cfg)

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

  -- Sizing
  frame:SetSize(w, h)

  -- Colors (no class color for pet by default; but honor useClass if enabled and pet is a player-like unit)
  if useClass and UnitExists and UnitExists(UNIT_TOKEN) and UnitIsPlayer and UnitIsPlayer(UNIT_TOKEN) then
    local class = select(2, UnitClass(UNIT_TOKEN))
    local tbl = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local c = (tbl and class) and tbl[class] or nil
    if c then
      colH = { r = c.r, g = c.g, b = c.b, a = (colH and colH.a) or 1 }
    end
  end

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

  -- Thick border overlay (same strata as parent, above bar, below major UI)
  frame._edgeF = frame._edgeF or CreateFrame("Frame", nil, frame)
  frame._edgeF:SetAllPoints(frame)
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

  -- Pet existence + health
  local hasPet = UnitExists and UnitExists(UNIT_TOKEN)
  if not hasPet then
    if InCombatLockdown and InCombatLockdown() then
      frame:SetAlpha(0)
    else
      frame:Hide()
    end
    return
  else
    if InCombatLockdown and InCombatLockdown() then
      frame:SetAlpha(1)
    else
      frame:Show()
    end
  end

  local cur = UnitHealth and UnitHealth(UNIT_TOKEN) or 0
  local maxv = UnitHealthMax and UnitHealthMax(UNIT_TOKEN) or 1
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

  -- Drag/lock
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

  -- Secure button interactivity via z-order only (avoid Show/Hide to prevent taint)
  if frame.secureBtn then
    if locked then
      -- Bring overlay above the tile to receive clicks
      if not (InCombatLockdown and InCombatLockdown()) then
        frame.secureBtn:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
        frame.secureBtn:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
      end
      if not InCombatLockdown or not InCombatLockdown() then
        if ClickCastFrames then ClickCastFrames[frame.secureBtn] = true end
        if C_ClickBindings and C_ClickBindings.RegisterFrame then pcall(C_ClickBindings.RegisterFrame, frame.secureBtn) end
        if ClickCastFrame_RegisterFrame then pcall(ClickCastFrame_RegisterFrame, frame.secureBtn) end
        do
          local onKeyDown = nil
          if C_CVar and C_CVar.GetCVarBool then
            onKeyDown = C_CVar.GetCVarBool("ActionButtonUseKeyDown")
          elseif GetCVarBool then
            onKeyDown = GetCVarBool("ActionButtonUseKeyDown")
          end
          if onKeyDown ~= nil then
            frame.secureBtn:SetAttribute("clickcast_onkeydown", onKeyDown and true or false)
          end
        end
        frame.secureBtn:SetAttribute("clickcast_unit", UNIT_TOKEN)
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

SkyInfoTiles.RegisterTileType("petbox", API)
