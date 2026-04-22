local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles and SkyInfoTiles.UI

local API = {}

-- Defaults
local DEFAULT_SIZE = 32 -- total line length in pixels (for each line)
local DEFAULT_THICKNESS = 2
local DEFAULT_COLOR = { r = 1, g = 0, b = 0, a = 0.9 } -- red
local DEFAULT_OUTLINE_THICKNESS = 0 -- 0 = no outline
local DEFAULT_OUTLINE_COLOR = { r = 0, g = 0, b = 0, a = 1 } -- black
local CENTER_GAP = 8 -- Gap in pixels at the center where lines don't meet

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

  -- Outline settings
  local outlineThick = Clamp(tonumber(cfg.outlineThickness) or DEFAULT_OUTLINE_THICKNESS, 0, 32)
  local oc = cfg.outlineColor or DEFAULT_OUTLINE_COLOR
  local or_ = (oc.r ~= nil) and oc.r or DEFAULT_OUTLINE_COLOR.r
  local og = (oc.g ~= nil) and oc.g or DEFAULT_OUTLINE_COLOR.g
  local ob = (oc.b ~= nil) and oc.b or DEFAULT_OUTLINE_COLOR.b
  local oa = (oc.a ~= nil) and oc.a or DEFAULT_OUTLINE_COLOR.a

  return size, thick, r, g, b, a, outlineThick, or_, og, ob, oa
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)
  local size = (cfg and cfg.size) or DEFAULT_SIZE
  local box = Clamp(size + 16, 32, 528)
  f:SetSize(box, box)
  -- Crosshair should never be draggable
  f._noDrag = true

  local size0, thick0, r0, g0, b0, a0, outlineThick0, or0, og0, ob0, oa0 = ReadCfg(cfg)

  -- Calculate segment length (each arm of the cross)
  local segmentLength = (size0 - CENTER_GAP) / 2
  local segmentOffset = CENTER_GAP / 2

  -- Outline (background layer) - 4 segments with gap
  if outlineThick0 > 0 then
    local outlineSegmentLength = segmentLength + outlineThick0

    -- Left outline
    f.hOutlineLeft = f:CreateTexture(nil, "BACKGROUND")
    if f.hOutlineLeft.SetColorTexture then
      f.hOutlineLeft:SetColorTexture(or0, og0, ob0, oa0)
    else
      f.hOutlineLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
      f.hOutlineLeft:SetVertexColor(or0, og0, ob0, 1)
      f.hOutlineLeft:SetAlpha(oa0)
    end
    f.hOutlineLeft:SetPoint("RIGHT", f, "CENTER", -(segmentOffset + outlineThick0), 0)
    f.hOutlineLeft:SetSize(outlineSegmentLength, thick0 + outlineThick0 * 2)

    -- Right outline
    f.hOutlineRight = f:CreateTexture(nil, "BACKGROUND")
    if f.hOutlineRight.SetColorTexture then
      f.hOutlineRight:SetColorTexture(or0, og0, ob0, oa0)
    else
      f.hOutlineRight:SetTexture("Interface\\Buttons\\WHITE8x8")
      f.hOutlineRight:SetVertexColor(or0, og0, ob0, 1)
      f.hOutlineRight:SetAlpha(oa0)
    end
    f.hOutlineRight:SetPoint("LEFT", f, "CENTER", (segmentOffset + outlineThick0), 0)
    f.hOutlineRight:SetSize(outlineSegmentLength, thick0 + outlineThick0 * 2)

    -- Top outline
    f.vOutlineTop = f:CreateTexture(nil, "BACKGROUND")
    if f.vOutlineTop.SetColorTexture then
      f.vOutlineTop:SetColorTexture(or0, og0, ob0, oa0)
    else
      f.vOutlineTop:SetTexture("Interface\\Buttons\\WHITE8x8")
      f.vOutlineTop:SetVertexColor(or0, og0, ob0, 1)
      f.vOutlineTop:SetAlpha(oa0)
    end
    f.vOutlineTop:SetPoint("BOTTOM", f, "CENTER", 0, (segmentOffset + outlineThick0))
    f.vOutlineTop:SetSize(thick0 + outlineThick0 * 2, outlineSegmentLength)

    -- Bottom outline
    f.vOutlineBottom = f:CreateTexture(nil, "BACKGROUND")
    if f.vOutlineBottom.SetColorTexture then
      f.vOutlineBottom:SetColorTexture(or0, og0, ob0, oa0)
    else
      f.vOutlineBottom:SetTexture("Interface\\Buttons\\WHITE8x8")
      f.vOutlineBottom:SetVertexColor(or0, og0, ob0, 1)
      f.vOutlineBottom:SetAlpha(oa0)
    end
    f.vOutlineBottom:SetPoint("TOP", f, "CENTER", 0, -(segmentOffset + outlineThick0))
    f.vOutlineBottom:SetSize(thick0 + outlineThick0 * 2, outlineSegmentLength)
  end

  -- Main lines - 4 segments with gap
  -- Left line
  f.hLineLeft = f:CreateTexture(nil, "ARTWORK")
  if f.hLineLeft.SetColorTexture then
    f.hLineLeft:SetColorTexture(r0, g0, b0, a0)
  else
    f.hLineLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.hLineLeft:SetVertexColor(r0, g0, b0, 1)
    f.hLineLeft:SetAlpha(a0)
  end
  f.hLineLeft:SetPoint("RIGHT", f, "CENTER", -segmentOffset, 0)
  f.hLineLeft:SetSize(segmentLength, thick0)

  -- Right line
  f.hLineRight = f:CreateTexture(nil, "ARTWORK")
  if f.hLineRight.SetColorTexture then
    f.hLineRight:SetColorTexture(r0, g0, b0, a0)
  else
    f.hLineRight:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.hLineRight:SetVertexColor(r0, g0, b0, 1)
    f.hLineRight:SetAlpha(a0)
  end
  f.hLineRight:SetPoint("LEFT", f, "CENTER", segmentOffset, 0)
  f.hLineRight:SetSize(segmentLength, thick0)

  -- Top line
  f.vLineTop = f:CreateTexture(nil, "ARTWORK")
  if f.vLineTop.SetColorTexture then
    f.vLineTop:SetColorTexture(r0, g0, b0, a0)
  else
    f.vLineTop:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.vLineTop:SetVertexColor(r0, g0, b0, 1)
    f.vLineTop:SetAlpha(a0)
  end
  f.vLineTop:SetPoint("BOTTOM", f, "CENTER", 0, segmentOffset)
  f.vLineTop:SetSize(thick0, segmentLength)

  -- Bottom line
  f.vLineBottom = f:CreateTexture(nil, "ARTWORK")
  if f.vLineBottom.SetColorTexture then
    f.vLineBottom:SetColorTexture(r0, g0, b0, a0)
  else
    f.vLineBottom:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.vLineBottom:SetVertexColor(r0, g0, b0, 1)
    f.vLineBottom:SetAlpha(a0)
  end
  f.vLineBottom:SetPoint("TOP", f, "CENTER", 0, -segmentOffset)
  f.vLineBottom:SetSize(thick0, segmentLength)

  -- Right-click refresh
  f:EnableMouse(true)
  f:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then API.update(self, cfg) end
  end)

  -- First paint
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)
  API.update(f, cfg)

  function f:Destroy()
    if self.SetScript then
      self:SetScript("OnMouseUp", nil)
      self:SetScript("OnShow", nil)
      self:SetScript("OnDragStart", nil)
      self:SetScript("OnDragStop", nil)
    end
  end
  return f
end

function API.update(frame, cfg)
  local size, thick, r, g, b, a, outlineThick, or_, og, ob, oa = ReadCfg(cfg)

  -- Calculate segment length (each arm of the cross)
  local segmentLength = (size - CENTER_GAP) / 2
  local segmentOffset = CENTER_GAP / 2

  -- Update or create outline textures (4 segments with gap)
  if outlineThick > 0 then
    local outlineSegmentLength = segmentLength + outlineThick

    -- Create outlines if they don't exist
    if not frame.hOutlineLeft then
      frame.hOutlineLeft = frame:CreateTexture(nil, "BACKGROUND")
    end
    if not frame.hOutlineRight then
      frame.hOutlineRight = frame:CreateTexture(nil, "BACKGROUND")
    end
    if not frame.vOutlineTop then
      frame.vOutlineTop = frame:CreateTexture(nil, "BACKGROUND")
    end
    if not frame.vOutlineBottom then
      frame.vOutlineBottom = frame:CreateTexture(nil, "BACKGROUND")
    end

    -- Update all 4 outline segments
    local outlines = {
      { tex = frame.hOutlineLeft, point = "RIGHT", x = -(segmentOffset + outlineThick), y = 0, w = outlineSegmentLength, h = thick + outlineThick * 2 },
      { tex = frame.hOutlineRight, point = "LEFT", x = (segmentOffset + outlineThick), y = 0, w = outlineSegmentLength, h = thick + outlineThick * 2 },
      { tex = frame.vOutlineTop, point = "BOTTOM", x = 0, y = (segmentOffset + outlineThick), w = thick + outlineThick * 2, h = outlineSegmentLength },
      { tex = frame.vOutlineBottom, point = "TOP", x = 0, y = -(segmentOffset + outlineThick), w = thick + outlineThick * 2, h = outlineSegmentLength },
    }

    for _, o in ipairs(outlines) do
      if o.tex then
        if o.tex.SetColorTexture then
          o.tex:SetColorTexture(or_, og, ob, oa)
        else
          o.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
          o.tex:SetVertexColor(or_, og, ob, 1)
          o.tex:SetAlpha(oa)
        end
        o.tex:ClearAllPoints()
        o.tex:SetPoint(o.point, frame, "CENTER", o.x, o.y)
        o.tex:SetSize(o.w, o.h)
        o.tex:Show()
      end
    end
  else
    -- Hide outlines if thickness is 0
    if frame.hOutlineLeft then frame.hOutlineLeft:Hide() end
    if frame.hOutlineRight then frame.hOutlineRight:Hide() end
    if frame.vOutlineTop then frame.vOutlineTop:Hide() end
    if frame.vOutlineBottom then frame.vOutlineBottom:Hide() end
  end

  -- Update all 4 main line segments
  local lines = {
    { tex = frame.hLineLeft, point = "RIGHT", x = -segmentOffset, y = 0, w = segmentLength, h = thick },
    { tex = frame.hLineRight, point = "LEFT", x = segmentOffset, y = 0, w = segmentLength, h = thick },
    { tex = frame.vLineTop, point = "BOTTOM", x = 0, y = segmentOffset, w = thick, h = segmentLength },
    { tex = frame.vLineBottom, point = "TOP", x = 0, y = -segmentOffset, w = thick, h = segmentLength },
  }

  for _, line in ipairs(lines) do
    if line.tex then
      if line.tex.SetColorTexture then
        line.tex:SetColorTexture(r, g, b, a)
      else
        line.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        line.tex:SetVertexColor(r, g, b, 1)
        line.tex:SetAlpha(a)
      end
      line.tex:ClearAllPoints()
      line.tex:SetPoint(line.point, frame, "CENTER", line.x, line.y)
      line.tex:SetSize(line.w, line.h)
    end
  end

  -- Expand frame hitbox slightly around lines for hover/right-click; not draggable
  local box = Clamp(size + 16, 32, 528)
  if frame.SetSize then frame:SetSize(box, box) end

  -- Always immovable (ignore Locked toggle)
  if frame.EnableMouse then frame:EnableMouse(true) end -- keep right-click refresh
  if frame.SetMovable then frame:SetMovable(false) end
  if frame.RegisterForDrag then
    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
  end
  -- Force centered position defensively
  if frame.ClearAllPoints and frame.SetPoint then
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

SkyInfoTiles.RegisterTileType("crosshair", API)
