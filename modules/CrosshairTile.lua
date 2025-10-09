local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Defaults
local DEFAULT_SIZE = 32 -- total line length in pixels (for each line)
local DEFAULT_THICKNESS = 2
local DEFAULT_COLOR = { r = 1, g = 0, b = 0, a = 0.9 } -- red

local function Clamp(v, lo, hi)
  if not v then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function ReadCfg(cfg)
  cfg = cfg or {}
  local size = Clamp(tonumber(cfg.size) or DEFAULT_SIZE, 4, 512)
  local thick = Clamp(tonumber(cfg.thickness) or DEFAULT_THICKNESS, 1, 64)
  local c = cfg.color or DEFAULT_COLOR
  local r = (c.r ~= nil) and c.r or DEFAULT_COLOR.r
  local g = (c.g ~= nil) and c.g or DEFAULT_COLOR.g
  local b = (c.b ~= nil) and c.b or DEFAULT_COLOR.b
  local a = (c.a ~= nil) and c.a or DEFAULT_COLOR.a
  return size, thick, r, g, b, a
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)
  local size = (cfg and cfg.size) or DEFAULT_SIZE
  local box = Clamp(size + 16, 32, 528)
  f:SetSize(box, box)

  local size0, thick0, r0, g0, b0, a0 = ReadCfg(cfg)

  -- Horizontal line
  f.hLine = f:CreateTexture(nil, "ARTWORK")
  if f.hLine.SetColorTexture then
    f.hLine:SetColorTexture(r0, g0, b0, a0)
  else
    f.hLine:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.hLine:SetVertexColor(r0, g0, b0, 1)
    f.hLine:SetAlpha(a0)
  end
  f.hLine:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.hLine:SetSize(size0, thick0)

  -- Vertical line
  f.vLine = f:CreateTexture(nil, "ARTWORK")
  if f.vLine.SetColorTexture then
    f.vLine:SetColorTexture(r0, g0, b0, a0)
  else
    f.vLine:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.vLine:SetVertexColor(r0, g0, b0, 1)
    f.vLine:SetAlpha(a0)
  end
  f.vLine:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.vLine:SetSize(thick0, size0)

  -- Right-click refresh
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then API.update(self, cfg) end
  end)

  -- First paint
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)
  API.update(f, cfg)

  function f:Destroy() end
  return f
end

function API.update(frame, cfg)
  local size, thick, r, g, b, a = ReadCfg(cfg)

  -- Resize lines
  if frame.hLine then frame.hLine:SetSize(size, thick) end
  if frame.vLine then frame.vLine:SetSize(thick, size) end

  -- Apply color
  if frame.hLine then
    if frame.hLine.SetColorTexture then
      frame.hLine:SetColorTexture(r, g, b, a)
    else
      frame.hLine:SetTexture("Interface\\Buttons\\WHITE8x8")
      frame.hLine:SetVertexColor(r, g, b, 1)
      frame.hLine:SetAlpha(a)
    end
  end
  if frame.vLine then
    if frame.vLine.SetColorTexture then
      frame.vLine:SetColorTexture(r, g, b, a)
    else
      frame.vLine:SetTexture("Interface\\Buttons\\WHITE8x8")
      frame.vLine:SetVertexColor(r, g, b, 1)
      frame.vLine:SetAlpha(a)
    end
  end

  -- Expand frame hitbox slightly around lines for easier dragging
  local box = Clamp(size + 16, 32, 528)
  if frame.SetSize then frame:SetSize(box, box) end

  -- Draggable base frame when unlocked (same pattern as other tiles)
  local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
  if frame.EnableMouse and frame.SetMovable then
    frame:EnableMouse(not locked)
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
end

SkyInfoTiles.RegisterTileType("crosshair", API)
