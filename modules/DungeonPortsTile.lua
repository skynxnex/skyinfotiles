-- SkyInfoTiles - Dungeon Teleports tile (row of icons; hover shows name/cooldown; left-click casts teleport)
local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI

local API = {}

-- Visual/layout
local ICON_SIZE   = 36
local GAP_X       = 6
local PAD_X       = 8
local PAD_Y       = 8
local BORDER_PX   = 2

-- Max level gate
local function IsAtMaxLevel()
  local cur = (UnitLevel and UnitLevel("player")) or nil
  local mx = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or (MAX_PLAYER_LEVEL) or nil
  if cur and mx then return cur >= mx end
  return true
end

-- Current-season dungeon teleports (keys must be NormKey(name)); include ID where possible for locale safety
local DUNGEONS = {
  { key = "prioryofthesacredflame", name = "Priory of the Sacred Flame", spellID = 445444, spellName = "Path of the Light's Reverence", mapID = 499 },
  { key = "tazaveshstreetsofwonder", name = "Tazavesh: Streets of Wonder", altNames = {"Tazavesh: So'leah's Gambit"}, spellID = nil,     spellName = "Path of the Streetwise Merchant", mapID = nil },
  { key = "operationfloodgate",      name = "Operation: Floodgate",       spellID = 1216786, spellName = nil, mapID = 525 },
  { key = "ecodomealdani",           name = "Eco-Dome Al'dani",           spellID = 1237215, spellName = "Path of the Eco-Dome", mapID = 542 },
  { key = "thedawnbreaker",          name = "The Dawnbreaker",            spellID = 445414,  spellName = "Path of the Arathi Flagship", mapID = nil },
  { key = "arakaracityofechoes",     name = "Ara-Kara, City of Echoes",   spellID = 445417,  spellName = "Path of the Ruined City", mapID = nil },
  { key = "hallsofatonement",        name = "Halls of Atonement",         spellID = 354465,  spellName = "Path of the Sinful Soul", mapID = nil },
}

-- Utils
local function Chat(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r "..tostring(msg))
  end
end

local function TryGetMapIcon(mapID)
  if not mapID then return nil end
  if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local n, _, _, tex = C_ChallengeMode.GetMapUIInfo(mapID)
    if not tex then
      local v = C_ChallengeMode.GetMapUIInfo(mapID)
      if type(v) == "table" then tex = v.texture or v.icon or v.iconFileID end
    end
    if tex then return tex end
  end
  if C_ChallengeMode and C_ChallengeMode.GetMapInfo then
    local t = C_ChallengeMode.GetMapInfo(mapID)
    if type(t) == "table" then
      local tex = t.texture or t.icon or t.iconFileID
      if tex then return tex end
    end
  end
  return nil
end

local function GetTeleportNameFromID(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellInfo then
    local si = C_Spell.GetSpellInfo(id)
    return si and si.name or nil
  end
  if GetSpellInfo then
    return GetSpellInfo(id)
  end
  return nil
end

local function GetSpellTextureSafe(idOrName)
  if not idOrName then return nil end
  if C_Spell and C_Spell.GetSpellTexture then
    local tex = C_Spell.GetSpellTexture(idOrName)
    if tex then return tex end
  end
  if GetSpellTexture then
    return GetSpellTexture(idOrName)
  end
  return nil
end

-- Resolve/caching helpers
local function ResolveSpellKey(d)
  if not d then return nil end
  if d.spellID then return d.spellID end
  if d._resolvedSpellID ~= nil then return d._resolvedSpellID end
  local sid = nil
  if d.spellName and type(GetSpellInfo) == "function" then
    local _, _, _, _, _, _, id = GetSpellInfo(d.spellName)
    sid = id
  end
  d._resolvedSpellID = sid
  return sid
end

-- Helpers for known/availability
local function GetSpellIDFromName(name)
  if not name then return nil end
  if C_Spell and C_Spell.GetSpellInfo then
    local si = C_Spell.GetSpellInfo(name)
    return si and si.spellID or nil
  end
  if GetSpellInfo then
    local _, _, _, _, _, _, sid = GetSpellInfo(name)
    return sid
  end
  return nil
end

local function IsTeleportKnown(d)
  if not d then return false, nil end
  local id = ResolveSpellKey(d) or GetSpellIDFromName(d.spellName)
  local known = false
  if id then
    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id) then
      known = true
    elseif IsPlayerSpell and IsPlayerSpell(id) then
      known = true
    elseif IsSpellKnown and IsSpellKnown(id) then
      known = true
    end
  end
  -- Fallback: if the client says it's usable, treat as known
  if not known then
    local key = id or d.spellName
    if key and IsUsableSpell then
      local usable = IsUsableSpell(key)
      if usable then known = true end
    end
  end
  return known, id
end

-- Frame builder
function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(600, ICON_SIZE + 2*PAD_Y)

  -- Data per dungeon: build icon textures, borders, cooldown + secure buttons
  f.cells = {}
  local vertical = (cfg and cfg.orientation == "vertical")
  for i, d in ipairs(DUNGEONS) do
    local cell = {}

    -- Icon texture
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    local offX = vertical and PAD_X or (PAD_X + (i-1) * (ICON_SIZE + GAP_X))
    local offY = vertical and (-PAD_Y - (i-1) * (ICON_SIZE + GAP_X)) or (-PAD_Y)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", offX, offY)
    local mapIcon = TryGetMapIcon(d.mapID)
    local spellKey = d.spellID or d.spellName
    local spellTex = GetSpellTextureSafe(spellKey)
    icon:SetTexture(mapIcon or spellTex or (GetItemIcon and GetItemIcon(180653)) or 525134)
    cell.icon = icon

    -- Border
    local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    border:SetPoint("TOPLEFT",     icon, -BORDER_PX,  BORDER_PX)
    border:SetPoint("BOTTOMRIGHT", icon,  BORDER_PX, -BORDER_PX)
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = BORDER_PX })
    border:SetBackdropBorderColor(0, 0, 0, 0.95)
    border:EnableMouse(false)
    cell.border = border

    -- Cooldown frame (standard cooldown spiral)
    -- Parent to the frame (not the texture) and anchor to the icon for proper layering
    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    if cd.SetFrameStrata then cd:SetFrameStrata("HIGH") end
    if cd.SetFrameLevel then cd:SetFrameLevel((f:GetFrameLevel() or 0) + 50) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end -- show numeric timer like spellbook/OmniCC
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
    if cd.SetUseCircularEdge then cd:SetUseCircularEdge(true) end
    if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.75) end
    if cd.SetReverse then cd:SetReverse(false) end
    if cd.EnableMouse then cd:EnableMouse(false) end
    if cd.SetMouseMotionEnabled then cd:SetMouseMotionEnabled(false) end
    cd:Hide()
    cell.cooldown = cd

    -- Secure click overlay (created only out of combat)
    local btn = nil
    local function CreateSecure()
      if btn then return end
      if InCombatLockdown and InCombatLockdown() then
        cell._pendingCreate = true
        return
      end
      btn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
      btn:SetPoint("TOPLEFT", f, "TOPLEFT", offX, offY)
      btn:SetSize(ICON_SIZE, ICON_SIZE)
      btn:RegisterForClicks("AnyDown", "AnyUp")
      -- Avoid calling EnableMouse on secure buttons to prevent taint; use Show/Hide control instead
      btn:SetFrameStrata("HIGH")
      btn:SetToplevel(true)
      btn:SetFrameLevel((f:GetFrameLevel() or 0) + 100)
      btn._dungeon = d
      -- Tooltip
      btn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(d.name, 1, 0.82, 0)
        if d.altNames then
          for _, an in ipairs(d.altNames) do
            GameTooltip:AddLine("Also: " .. an, 1, 1, 1)
          end
        end
        local known = IsTeleportKnown(d)
        if known then
          GameTooltip:AddLine("Left-click: Teleport", 0, 1, 0)
          -- Cooldown hint
          local sid = d.spellID or d.spellName
          local start, dur, en = GetSpellCooldown and GetSpellCooldown(sid)
          if start and dur and dur > 1.5 then
            local remain = math.max(0, (start + dur) - GetTime())
            local mins = math.floor(remain / 60)
            local secs = math.floor(remain % 60)
            GameTooltip:AddLine(string.format("Cooldown: %dm %ds", mins, secs), 1, 0.4, 0.4)
          end
        else
          GameTooltip:AddLine("Teleport unavailable.", 1, 0.3, 0.3)
        end
        GameTooltip:Show()
      end)
      btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      cell.button = btn
    end
    CreateSecure()

    -- Store
    f.cells[i] = cell
  end

  -- Size width to content
  if vertical then
    f:SetSize(ICON_SIZE + 2*PAD_X, PAD_Y + (ICON_SIZE + GAP_X) * #DUNGEONS - GAP_X + PAD_Y)
  else
    f:SetSize(PAD_X + (ICON_SIZE + GAP_X) * #DUNGEONS - GAP_X + PAD_X, ICON_SIZE + 2*PAD_Y)
  end

  -- Events
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:RegisterEvent("SPELLS_CHANGED")
  f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
      -- Create any pending secure buttons and (re)bind
      for _, cell in ipairs(self.cells or {}) do
        if cell._pendingCreate then
          local d = cell.button and cell.button._dungeon or nil
          cell._pendingCreate = nil
          -- Recreate at the same anchor by invoking CreateSecure again
          -- Simple inline recreation:
          if not cell.button then
            local idx = _
            local v = (cfg and cfg.orientation == "vertical")
            local offX = v and PAD_X or (PAD_X + (idx-1) * (ICON_SIZE + GAP_X))
            local offY = v and (-PAD_Y - (idx-1) * (ICON_SIZE + GAP_X)) or (-PAD_Y)
            local btn = CreateFrame("Button", nil, self, "SecureActionButtonTemplate")
            btn:SetPoint("TOPLEFT", self, "TOPLEFT", offX, offY)
            btn:SetSize(ICON_SIZE, ICON_SIZE)
            btn:RegisterForClicks("AnyDown", "AnyUp")
            -- Avoid calling EnableMouse on secure buttons to prevent taint; use Show/Hide control instead
            btn:SetFrameStrata("HIGH")
            btn:SetToplevel(true)
            btn:SetFrameLevel((self:GetFrameLevel() or 0) + 100)
            btn._dungeon = DUNGEONS[idx]
            btn:SetScript("OnEnter", function(b)
              if not GameTooltip then return end
              GameTooltip:SetOwner(b, "ANCHOR_TOP")
              local d2 = DUNGEONS[idx]
              GameTooltip:AddLine(d2.name, 1, 0.82, 0)
              if d2.altNames then
                for _, an in ipairs(d2.altNames) do
                  GameTooltip:AddLine("Also: " .. an, 1, 1, 1)
                end
              end
              local known = IsTeleportKnown(d2)
              if known then
                GameTooltip:AddLine("Left-click: Teleport", 0, 1, 0)
                local sid = d2.spellID or d2.spellName
                local start, dur, en = GetSpellCooldown and GetSpellCooldown(sid)
                if start and dur and dur > 1.5 then
                  local remain = math.max(0, (start + dur) - GetTime())
                  local mins = math.floor(remain / 60)
                  local secs = math.floor(remain % 60)
                  GameTooltip:AddLine(string.format("Cooldown: %dm %ds", mins, secs), 1, 0.4, 0.4)
                end
              else
                GameTooltip:AddLine("Teleport unavailable.", 1, 0.3, 0.3)
              end
              GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            cell.button = btn
          end
        end
      end
    end
    API.update(self, cfg)
  end)

  -- Right-click refresh; drag handling in update() based on locked state (like Keystone tile)
  if f.SetPropagateMouseClicks then f:SetPropagateMouseClicks(false) end
  f:SetScript("OnMouseDown", function(self, btn)
    if not (SkyInfoTilesDB and SkyInfoTilesDB.locked) and btn == "LeftButton" then
      if self.StartMoving then self:StartMoving() end
    end
  end)
  f:SetScript("OnMouseUp", function(self, btn)
    if not (SkyInfoTilesDB and SkyInfoTilesDB.locked) and btn == "LeftButton" then
      if self.StopMovingOrSizing then self:StopMovingOrSizing() end
      local point, _, _, X, Y = self:GetPoint()
      if self._cfg then self._cfg.point, self._cfg.x, self._cfg.y = point, X, Y end
      return
    end
    if btn == "RightButton" then
      API.update(self, cfg)
    end
  end)

  -- Initial paint
  f:SetScript("OnShow", function(self) API.update(self, cfg) end)
  API.update(f, cfg)

  function f:Destroy() end
  return f
end

-- Binding + cooldown visuals
local function BindSpellToButton(btn, d)
  if not btn or not d then return end
  local spellID = ResolveSpellKey(d)
  local spellKey = spellID or (d.spellName or GetTeleportNameFromID(d.spellID))
  if InCombatLockdown and InCombatLockdown() then
    btn._pendingSpellName = spellKey or false
    return
  end
  if spellKey then
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("type1", "spell")
    btn:SetAttribute("spell", spellKey)
    btn:SetAttribute("spell1", spellKey)
    btn._teleName = d.spellName or GetTeleportNameFromID(d.spellID) or tostring(spellKey)
  else
    btn:SetAttribute("type", nil)
    btn:SetAttribute("type1", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("spell1", nil)
    btn._teleName = nil
  end
end

local function UpdateCooldown(cell, d)
  if not cell or not cell.cooldown then return end
  local sid = ResolveSpellKey(d) or d.spellName
  if not sid then cell.cooldown:Hide(); return end

  local start, dur, enable = 0, 0, 0
  if type(GetSpellCooldown) == "function" then
    start, dur, enable = GetSpellCooldown(sid)
  end
  -- Fallback to C_Spell API if available and primary returned no duration
  if (not dur or dur == 0) and C_Spell and C_Spell.GetSpellCooldown then
    local cdInfo = C_Spell.GetSpellCooldown(sid)
    if type(cdInfo) == "table" and cdInfo.startTime and cdInfo.duration then
      start = cdInfo.startTime
      dur   = cdInfo.duration
      enable = 1
    end
  end

  if start and dur and dur > 1.5 then
    if cell.cooldown.SetDrawEdge then cell.cooldown:SetDrawEdge(false) end
    if cell.cooldown.SetCooldown then
      cell.cooldown:SetCooldown(start, dur)
    else
      if CooldownFrame_Set then CooldownFrame_Set(cell.cooldown, start, dur, enable) end
    end
    cell.cooldown:Show()
  else
    cell.cooldown:Hide()
  end
end

function API.update(frame, cfg)
  -- Max level gating
  if not IsAtMaxLevel() then
    if not (InCombatLockdown and InCombatLockdown()) then
      if frame.Hide then frame:Hide() end
    end
    return
  else
    if not (InCombatLockdown and InCombatLockdown()) then
      if frame.Show then frame:Show() end
    end
  end
  -- Update icons, bind spells, update cooldowns, lock/unlock behavior
  local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false

  for i, cell in ipairs(frame.cells or {}) do
    local d = DUNGEONS[i]
    -- Re-bind if pending
    if cell.button and cell.button._pendingSpellName ~= nil then
      local nm = cell.button._pendingSpellName; cell.button._pendingSpellName = nil
      BindSpellToButton(cell.button, d)
    elseif cell.button then
      BindSpellToButton(cell.button, d)
    end

    -- Known state visuals and mouse
    local known = IsTeleportKnown(d)
    if cell.icon then
      if cell.icon.SetDesaturated then cell.icon:SetDesaturated(not known) end
      if known then
        cell.icon:SetVertexColor(1,1,1,1)
      else
        cell.icon:SetVertexColor(0.4,0.4,0.4,1)
      end
    end
    if cell.border then
      if known then
        cell.border:SetBackdropBorderColor(0, 0, 0, 0.95)
      else
        cell.border:SetBackdropBorderColor(0.6, 0, 0, 0.9)
      end
    end

    -- Interactivity via z-order only (avoid protected calls during combat)
    if cell.button then
      if not (InCombatLockdown and InCombatLockdown()) then
        if locked and known then
          -- Bring overlay above the tile to receive clicks
          cell.button:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
          cell.button:SetFrameLevel((frame:GetFrameLevel() or 0) + 100)
        else
          -- Push overlay behind so base frame receives clicks; appears inert/hidden to mouse
          cell.button:SetFrameStrata("BACKGROUND")
          cell.button:SetFrameLevel(1)
        end
      end
    end

    -- Cooldown (always evaluate; some teleports may report cooldown even if not considered 'known' by older APIs)
    UpdateCooldown(cell, d)
  end

  -- Draggable base frame when unlocked (same pattern as Keystone)
  -- Avoid protected mouse changes during combat (taint-safe)
  if frame.EnableMouse and frame.SetMovable then
    if not (InCombatLockdown and InCombatLockdown()) then
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
end

SkyInfoTiles.RegisterTileType("dungeonports", API)
