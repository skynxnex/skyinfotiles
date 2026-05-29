-- SkyInfoTiles - core (catalog + enable/disable + migration/clean)
local ADDON_NAME = ...
local SkyInfoTiles = {}
_G[ADDON_NAME] = SkyInfoTiles

-- ===== SavedVariables (migrate from old name) =====
SkyInfoTilesDB = SkyInfoTilesDB or _G.InfoTilesDB or {}
_G.InfoTilesDB = nil -- clean up legacy global if it existed

-- ===== Catalog: predefined tiles (add more over time) =====
local CATALOG = {
  { key = "currencies", type = "currencies", label = "Currencies", defaultEnabled = true },
  { key = "keystone",   type = "keystone",   label = "Mythic Keystone",     defaultEnabled = true },
  { key = "charstats",  type = "charstats",  label = "Character Stats",     defaultEnabled = true },
  { key = "crosshair",  type = "crosshair",  label = "Crosshair",           defaultEnabled = false },
  { key = "clock",      type = "clock",      label = "24h Clock",           defaultEnabled = false },
  { key = "dungeonports", type = "dungeonports", label = "Dungeon Teleports", defaultEnabled = false },
}
SkyInfoTiles.CATALOG = CATALOG -- used by Options.lua

-- ===== Defaults =====
local DEFAULTS = {
  locked      = false,
  scope       = "char",  -- "char" or "warband" (some tiles care about this)
  tiles       = {},      -- legacy; migrated into profiles.Default.tiles
  fontOutline = "OUTLINE",
  profiles    = { Default = { tiles = {} } },
  characterProfiles = {}, -- map ["CharName-Realm"] = "ProfileName"
}

-- === UI helpers (global) ===
SkyInfoTiles.UI = SkyInfoTiles.UI or {}

-- opts: { weight="OUTLINE"|"THICKOUTLINE"|"" , size=number , shadow=true/false }
function SkyInfoTiles.UI.Outline(fs, opts)
  if not fs or not fs.GetFont then return end
  local font, size, flags = fs:GetFont()
  opts = opts or {}
  local weight = opts.weight

  -- global default if not explicitly provided
  if not weight and SkyInfoTilesDB and SkyInfoTilesDB.fontOutline ~= nil then
    weight = SkyInfoTilesDB.fontOutline
  end
  if weight == nil then weight = "OUTLINE" end
  if weight == "NONE" or weight == false then weight = "" end

  size = opts.size or size or 14
  fs:SetFont(font, size, weight)

  if opts.shadow ~= false then
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
  end
end

-- convenient alias
SkyInfoTiles.Outline = SkyInfoTiles.UI.Outline

-- CVar helpers and global UI scale controls
local function SafeSetCVar(name, value)
  if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, tostring(value))
  elseif SetCVar then pcall(SetCVar, name, tostring(value)) end
end

local function SafeGetCVar(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name)
  elseif GetCVar then return GetCVar(name) end
  return nil
end

local function SafeGetCVarBool(name)
  if C_CVar and C_CVar.GetCVarBool then return C_CVar.GetCVarBool(name)
  elseif GetCVarBool then return GetCVarBool(name) end
  return false
end

-- === Shared Utils (string normalization for teleport/dungeon matching) ===
SkyInfoTiles.Utils = SkyInfoTiles.Utils or {}

local STOP_WORDS = { ["the"]=true, ["of"]=true, ["and"]=true, ["de"]=true, ["la"]=true, ["das"]=true, ["der"]=true, ["di"]=true }

-- Remove all spaces, punctuation, make lowercase
function SkyInfoTiles.Utils.NormKey(s)
  return (s or ""):lower():gsub("[%s:,'''%-%.%(%)]", "")
end

-- Normalize whitespace, trim, lowercase
function SkyInfoTiles.Utils.Norm(s)
  return (s or ""):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Extract tokens (words), removing stop words, return tokens + normalized key
function SkyInfoTiles.Utils.TokensFromName(s)
  s = (s or ""):lower()
  s = s:gsub("[:,'''%-%.%(%)]", " "):gsub("%s+", " ")
  local tokens = {}
  for tk in s:gmatch("%S+") do
    if not STOP_WORDS[tk] then tokens[#tokens + 1] = tk end
  end
  return tokens, SkyInfoTiles.Utils.NormKey(s)
end

-- === Shared Theme Constants ===
SkyInfoTiles.Theme = {
  ROW_HEIGHT = 22,
  ICON_SIZE_SMALL = 18,
  ICON_SIZE_MEDIUM = 36,
  PAD_X = 8,
  PAD_Y = 6,
  BORDER_WIDTH = 2,
}

SkyInfoTiles._pendingUiScale = SkyInfoTiles._pendingUiScale or nil
SkyInfoTiles._pendingUseUiScale = SkyInfoTiles._pendingUseUiScale or nil

function SkyInfoTiles.SetUseUiScale(on)
  -- disabled (no-op)
end

function SkyInfoTiles.SetUiScale(scale)
  -- disabled (no-op)
end

function SkyInfoTiles.ApplyUiScale(scale)
  -- disabled (no-op)
end

-- ===== Utils =====
local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do out[k] = deepcopy(val) end
  return out
end

local function applyDefaults(db, defs)
  for k, v in pairs(defs) do
    if db[k] == nil then
      db[k] = deepcopy(v)
    elseif type(v) == "table" and type(db[k]) == "table" then
      applyDefaults(db[k], v)
    end
  end
end

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r " .. tostring(msg))
  end
end

local function Trim(s)
  if type(s) ~= "string" then return "" end
  if type(_G.strtrim) == "function" then return _G.strtrim(s) end
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

-- ===== Tile registry =====
local TILE_TYPES = {}
function SkyInfoTiles.RegisterTileType(name, api) TILE_TYPES[name] = api end

-- ===== Profiles & Active tiles helpers =====
local function GetCharacterKey()
  local name = UnitName("player")
  local realm = GetRealmName()
  return name .. "-" .. realm
end

function SkyInfoTiles.GetActiveProfileName()
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.characterProfiles = SkyInfoTilesDB.characterProfiles or {}

  local charKey = GetCharacterKey()
  local profileName = SkyInfoTilesDB.characterProfiles[charKey]

  -- Om ingen profil vald eller profilen inte finns, använd Default
  if not profileName or not SkyInfoTilesDB.profiles or not SkyInfoTilesDB.profiles[profileName] then
    profileName = "Default"
  end

  return profileName
end

local function GetOrCreateProfile(name)
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or {}
  if not SkyInfoTilesDB.profiles[name] then
    SkyInfoTilesDB.profiles[name] = { tiles = {} }
  end
  if type(SkyInfoTilesDB.profiles[name].tiles) ~= "table" then
    SkyInfoTilesDB.profiles[name].tiles = {}
  end
  return SkyInfoTilesDB.profiles[name]
end

local function GetActiveProfile()
  local name = SkyInfoTiles.GetActiveProfileName()
  return GetOrCreateProfile(name)
end

function SkyInfoTiles.GetActiveTiles()
  local prof = GetActiveProfile()
  if not prof or type(prof.tiles) ~= "table" then
    -- Defensive: return empty table if profile is corrupt
    return {}
  end
  return prof.tiles
end

function SkyInfoTiles.GetOrCreateTileCfg(key)
  local cat = nil
  for _, c in ipairs(SkyInfoTiles.CATALOG or {}) do if c.key == key then cat = c; break end end
  if not cat then return nil end
  local cfg = nil
  local tiles = SkyInfoTiles.GetActiveTiles()
  for _, t in ipairs(tiles) do if t.key == key then cfg = t; break end end
  if not cfg then
    cfg = { key = cat.key, type = cat.type, label = cat.label, enabled = (cat.defaultEnabled ~= false), point = "TOPLEFT", x = 0, y = 0, strata = "MEDIUM" }
    table.insert(tiles, cfg)
  end
  return cfg
end

-- ===== Profile-scoped tile accessors (for editing non-active profiles) =====
function SkyInfoTiles.GetTilesForProfile(profileName)
  local name = profileName or (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  local prof = GetOrCreateProfile(name)
  return prof.tiles
end

local function FindTileByKeyInTiles(tiles, key)
  if type(tiles) ~= "table" then return nil, nil end
  for i, cfg in ipairs(tiles) do
    if cfg.key == key then return cfg, i end
  end
  return nil, nil
end

local function EnsureTileExistsForCatInTiles(tiles, cat)
  local cfg = select(1, FindTileByKeyInTiles(tiles, cat.key))
  if cfg then return cfg end
  cfg = {
    key = cat.key, type = cat.type, label = cat.label,
    enabled = (cat.defaultEnabled ~= false),
    point = "TOPLEFT", x = 0, y = 0, strata = "MEDIUM",
  }
  table.insert(tiles, cfg)
  return cfg
end

function SkyInfoTiles.GetOrCreateTileCfgForProfile(profileName, key)
  local tiles = SkyInfoTiles.GetTilesForProfile(profileName)
  -- Avoid forward reference to a local defined later: scan catalog directly
  local cat = nil
  for _, c in ipairs(SkyInfoTiles.CATALOG or {}) do
    if c.key == key then cat = c; break end
  end
  if not cat then return nil end
  local cfg = select(1, FindTileByKeyInTiles(tiles, key))
  if not cfg then
    cfg = EnsureTileExistsForCatInTiles(tiles, cat)
  end
  return cfg
end

function SkyInfoTiles.GetTileEnabledByKeyForProfile(profileName, key)
  local cfg = SkyInfoTiles.GetOrCreateTileCfgForProfile(profileName, key)
  return (cfg and cfg.enabled ~= false) or false
end

function SkyInfoTiles.SetTileEnabledByKeyForProfile(profileName, key, enabled)
  local cfg = SkyInfoTiles.GetOrCreateTileCfgForProfile(profileName, key)
  if not cfg then return end
  local base = profileName or (SkyInfoTilesDB and SkyInfoTilesDB.profile) or "Default"
  cfg.enabled = not not enabled
  if Print then Print(("Profile %s: [%s] enabled=%s"):format(tostring(base), tostring(key), tostring(cfg.enabled))) end
  local active = SkyInfoTiles.GetActiveProfileName()
  if active == base then
    SkyInfoTiles.Rebuild()
    SkyInfoTiles.UpdateAll()
    if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  end
  -- If editing a non-active profile, do not refresh/rebuild the options panel immediately;
  -- this prevents the checkbox from being reset by a mid-click refresh.
end

-- ===== Profile Management Functions =====

function SkyInfoTiles.SetActiveProfile(profileName)
  local charKey = GetCharacterKey()

  -- Validera att profilen finns
  if not SkyInfoTilesDB.profiles[profileName] then
    return false, "Profile does not exist"
  end

  -- Spara per-karaktär val
  SkyInfoTilesDB.characterProfiles[charKey] = profileName

  -- Rebuild tiles
  SkyInfoTiles.Rebuild()
  SkyInfoTiles.UpdateAll()
  if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end

  return true
end

function SkyInfoTiles.CreateProfile(name, copyFrom)
  if not name or name == "" then
    return false, "Profile name cannot be empty"
  end

  if SkyInfoTilesDB.profiles[name] then
    return false, "Profile already exists"
  end

  -- If no copyFrom specified, copy from current active profile
  if not copyFrom then
    copyFrom = SkyInfoTiles.GetActiveProfileName()
  end

  if copyFrom and SkyInfoTilesDB.profiles[copyFrom] then
    -- Kopiera tiles från befintlig profil
    SkyInfoTilesDB.profiles[name] = { tiles = deepcopy(SkyInfoTilesDB.profiles[copyFrom].tiles) }
  else
    -- Fallback: skapa tom profil
    SkyInfoTilesDB.profiles[name] = { tiles = {} }
  end

  if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  return true
end

function SkyInfoTiles.RenameProfile(oldName, newName)
  if oldName == "Default" then
    return false, "Cannot rename Default profile"
  end

  if not newName or newName == "" then
    return false, "New profile name cannot be empty"
  end

  if not SkyInfoTilesDB.profiles[oldName] then
    return false, "Profile does not exist"
  end

  if SkyInfoTilesDB.profiles[newName] then
    return false, "A profile with that name already exists"
  end

  -- Kopiera profil till nytt namn
  SkyInfoTilesDB.profiles[newName] = SkyInfoTilesDB.profiles[oldName]
  SkyInfoTilesDB.profiles[oldName] = nil

  -- Uppdatera alla karaktärer som använde gamla namnet
  for charKey, profName in pairs(SkyInfoTilesDB.characterProfiles) do
    if profName == oldName then
      SkyInfoTilesDB.characterProfiles[charKey] = newName
    end
  end

  if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  return true
end

function SkyInfoTiles.DeleteProfile(name)
  if name == "Default" then
    return false, "Cannot delete Default profile"
  end

  if not SkyInfoTilesDB.profiles[name] then
    return false, "Profile does not exist"
  end

  -- Sätt alla karaktärer som använder denna profil till Default
  for charKey, profName in pairs(SkyInfoTilesDB.characterProfiles) do
    if profName == name then
      SkyInfoTilesDB.characterProfiles[charKey] = "Default"
    end
  end

  SkyInfoTilesDB.profiles[name] = nil

  -- Om nuvarande karaktär använde denna profil, rebuild
  local currentProfile = SkyInfoTiles.GetActiveProfileName()
  if currentProfile == "Default" then
    SkyInfoTiles.Rebuild()
    SkyInfoTiles.UpdateAll()
  end

  if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  return true
end

function SkyInfoTiles.ListProfiles()
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or {}

  -- Ensure Default profile exists
  if not SkyInfoTilesDB.profiles.Default then
    SkyInfoTilesDB.profiles.Default = { tiles = {} }
  end

  local list = {}
  for name, _ in pairs(SkyInfoTilesDB.profiles) do
    table.insert(list, name)
  end
  table.sort(list)
  return list
end

-- ===== DB helpers (by key) =====
local function FindCatByType(t)
  for _, cat in ipairs(CATALOG) do if cat.type == t then return cat end end
end

local function FindCatByKey(k)
  for _, cat in ipairs(CATALOG) do if cat.key == k then return cat end end
end

local function FindTileByKey(key)
  local tiles = SkyInfoTiles.GetActiveTiles()
  for i, cfg in ipairs(tiles) do
    if cfg.key == key then return cfg, i end
  end
  return nil, nil
end

local function EnsureTileExistsForCat(cat)
  local cfg = FindTileByKey(cat.key)
  if cfg then return cfg end
  cfg = {
    key = cat.key, type = cat.type, label = cat.label,
    enabled = (cat.defaultEnabled ~= false),
    point = "TOPLEFT", x = 0, y = 0,
  }
  local tiles = SkyInfoTiles.GetActiveTiles()
  table.insert(tiles, cfg)
  return cfg
end

-- ===== Migration: normalize legacy entries & remove duplicates =====
local function MigrateLegacy(tiles)
  tiles = tiles or SkyInfoTiles.GetActiveTiles()
  local assigned, removed = 0, 0

  if type(tiles) ~= "table" then
    return 0, 0
  end

  -- 1) Assign missing keys from catalog by type
  local usedKey = {}
  for _, cfg in ipairs(tiles) do if cfg.key then usedKey[cfg.key] = true end end
  for _, cfg in ipairs(tiles) do
    if not cfg.key and cfg.type then
      local cat = FindCatByType(cfg.type)
      if cat and not usedKey[cat.key] then
        cfg.key   = cat.key
        cfg.label = cfg.label or cat.label
        usedKey[cat.key] = true
        assigned = assigned + 1
      end
    end
  end

  -- 2) Remove duplicates (by key, keep first)
  local seen = {}
  for i = #tiles, 1, -1 do
    local k = tiles[i].key
    if k then
      if seen[k] then
        table.remove(tiles, i)
        removed = removed + 1
      else
        seen[k] = true
      end
    end
  end

  -- 3) Remove unkeyed entries when a keyed one of same type exists
  local typeHasKeyed = {}
  for _, cfg in ipairs(tiles) do
    if cfg.key then
      local cat = FindCatByKey(cfg.key)
      if cat then typeHasKeyed[cat.type] = true end
    end
  end
  for i = #tiles, 1, -1 do
    local cfg = tiles[i]
    if not cfg.key and cfg.type and typeHasKeyed[cfg.type] then
      table.remove(tiles, i)
      removed = removed + 1
    end
  end

  return assigned, removed
end

-- ===== Seed from catalog (create missing keyed entries) =====
local function SeedCatalog()
  for _, cat in ipairs(CATALOG) do
    EnsureTileExistsForCat(cat)
  end
end

-- ===== Exposed toggles for Options =====
function SkyInfoTiles.SetLocked(v)
  SkyInfoTilesDB.locked = not not v
  SkyInfoTiles.Rebuild()
  SkyInfoTiles.UpdateAll()
end

function SkyInfoTiles.GetTileEnabledByKey(key)
  local cfg = FindTileByKey(key)
  return (cfg and cfg.enabled ~= false) or false
end

function SkyInfoTiles.SetTileEnabledByKey(key, enabled)
  local cat = FindCatByKey(key)
  if not cat then return end
  local cfg = FindTileByKey(key) or EnsureTileExistsForCat(cat)
  cfg.enabled = not not enabled
  SkyInfoTiles.Rebuild()
  SkyInfoTiles.UpdateAll()
  if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
end

-- ===== Frames lifecycle =====
local tilesFrames = {}

local function InLockdown()
  return InCombatLockdown and InCombatLockdown()
end

SkyInfoTiles._pendingRebuild = SkyInfoTiles._pendingRebuild or false

local function DeferRebuild()
  SkyInfoTiles._pendingRebuild = true
end

local function SetMovable(f)
  if f and f._noDrag then
    if f.EnableMouse then pcall(f.EnableMouse, f, false) end
    if f.SetMovable then pcall(f.SetMovable, f, false) end
    if f.RegisterForDrag then pcall(f.RegisterForDrag, f) end
    if f.SetScript then
      pcall(f.SetScript, f, "OnDragStart", nil)
      pcall(f.SetScript, f, "OnDragStop", nil)
    end
    -- Hide unlock indicator for non-draggable frames
    if f._unlockIndicator then
      f._unlockIndicator:Hide()
    end
    return
  end
  local unlocked = not SkyInfoTilesDB.locked

  -- Visual feedback: show backdrop when unlocked
  if unlocked then
    if not f._unlockIndicator then
      -- Create backdrop frame
      f._unlockIndicator = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
      f._unlockIndicator:SetAllPoints(f)
      f._unlockIndicator:SetFrameLevel(f:GetFrameLevel() - 1)

      -- Backdrop with semi-transparent background and green border
      local backdropInfo = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
      }

      if f._unlockIndicator.SetBackdrop then
        f._unlockIndicator:SetBackdrop(backdropInfo)
        f._unlockIndicator:SetBackdropColor(0, 1, 0, 0.1)  -- Green tint, very transparent
        f._unlockIndicator:SetBackdropBorderColor(0, 1, 0, 0.6)  -- Green border, semi-transparent
      end
    end
    f._unlockIndicator:Show()
  else
    -- Hide backdrop when locked
    if f._unlockIndicator then
      f._unlockIndicator:Hide()
    end
  end

  if not (InCombatLockdown and InCombatLockdown()) then
    if f.EnableMouse then pcall(f.EnableMouse, f, unlocked) end
    if f.SetMovable then pcall(f.SetMovable, f, unlocked) end
    if unlocked and f.RegisterForDrag then
      pcall(f.RegisterForDrag, f, "LeftButton")
      f:SetScript("OnDragStart", function(self)
        if self.StartMoving then self:StartMoving() end
      end)
      local function StopDragging(self)
        if self.StopMovingOrSizing then self:StopMovingOrSizing() end
        if self._cfg then
          -- Convert to TOPLEFT-based coordinates for all tiles except crosshair
          if self._cfg.key ~= "crosshair" and self._cfg.type ~= "crosshair" then
            local frameLeft = self:GetLeft()
            local frameTop = self:GetTop()
            if frameLeft and frameTop and UIParent then
              local uiParentTop = UIParent:GetTop()
              if uiParentTop then
                self._cfg.point = "TOPLEFT"
                self._cfg.x = math.floor(frameLeft + 0.5)
                self._cfg.y = math.floor((frameTop - uiParentTop) + 0.5)
              end
            end
          else
            -- For crosshair, keep fixed at screen center
            self._cfg.point = "CENTER"
            self._cfg.x = 0
            self._cfg.y = 0
          end
          -- Update options window if it's open
          if SkyInfoTiles._OptionsRefresh then
            SkyInfoTiles._OptionsRefresh()
          end
        end
      end
      pcall(f.SetScript, f, "OnDragStop", StopDragging)
      if f.SetScript then
        pcall(f.SetScript, f, "OnMouseUp", StopDragging)
        pcall(f.SetScript, f, "OnHide", function(self)
          if self.StopMovingOrSizing then self:StopMovingOrSizing() end
        end)
      end
    elseif f.RegisterForDrag then
      pcall(f.RegisterForDrag, f)
      if f.SetScript then
        pcall(f.SetScript, f, "OnDragStart", nil)
        pcall(f.SetScript, f, "OnDragStop", nil)
        pcall(f.SetScript, f, "OnMouseUp", nil)
        pcall(f.SetScript, f, "OnHide", nil)
      end
    end
  end
end

function SkyInfoTiles.Rebuild()
  if InLockdown() then
    DeferRebuild()
    return
  end
  for i, f in ipairs(tilesFrames) do
    if f and f.Destroy then pcall(f.Destroy, f) end
    if f and f.Hide and not InLockdown() then pcall(f.Hide, f) end
    tilesFrames[i] = nil
  end
  tilesFrames = {}

  local tiles = SkyInfoTiles.GetActiveTiles()
  for _, cfg in ipairs(tiles) do
    if cfg.enabled ~= false then
      local ttype = TILE_TYPES[cfg.type]
      if ttype and ttype.create then
        local frame = ttype.create(UIParent, cfg)
        frame._cfg = cfg

        -- Apply frame strata
        if cfg.strata and frame.SetFrameStrata then
          local validStrata = { BACKGROUND=true, LOW=true, MEDIUM=true, HIGH=true, DIALOG=true, FULLSCREEN=true, FULLSCREEN_DIALOG=true, TOOLTIP=true }
          if validStrata[cfg.strata] then
            frame:SetFrameStrata(cfg.strata)
          end
        end

        frame:ClearAllPoints()
        local p = cfg.point or "TOPLEFT"
        local x = cfg.x or 0
        local y = cfg.y or 0
        if cfg.type == "crosshair" or cfg.key == "crosshair" then
          p, x, y = "CENTER", 0, 0
          frame._noDrag = true
        end
        frame:SetPoint(p, UIParent, p, x, y)
        SetMovable(frame)
        table.insert(tilesFrames, frame)
      end
    end
  end
end

function SkyInfoTiles.UpdateAll()
  if InLockdown() then
    DeferRebuild()
    return
  end
  local tiles = SkyInfoTiles.GetActiveTiles()
  for _, cfg in ipairs(tiles) do
    if cfg.enabled ~= false then
      local ttype = TILE_TYPES[cfg.type]
      if ttype and ttype.update then
        for _, f in ipairs(tilesFrames) do
          if f._cfg == cfg then
            if cfg.type == "crosshair" or cfg.key == "crosshair" then
              if f.ClearAllPoints and f.SetPoint then
                f:ClearAllPoints()
                f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
              end
              f._noDrag = true
            end
            ttype.update(f, cfg)
            break
          end
        end
      end
    end
  end
end

-- ===== Reset to catalog defaults =====
local function ResetToCatalogDefaults()
  local tiles = SkyInfoTiles.GetActiveTiles()
  for i = #tiles, 1, -1 do table.remove(tiles, i) end
  for _, cat in ipairs(CATALOG) do
    table.insert(tiles, {
      key = cat.key, type = cat.type, label = cat.label,
      enabled = (cat.defaultEnabled ~= false),
      point = "TOPLEFT", x = 0, y = 0, strata = "MEDIUM",
    })
  end
  SkyInfoTiles.Rebuild()
  SkyInfoTiles.UpdateAll()
  if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  Print("Reset: restored catalog defaults for active profile.")
end

-- ===== Helper functions for OptionsWindow and MinimapButton =====
function SkyInfoTiles.GetCurrencyList()
  -- Return currency list from CurrencyTile module
  -- This will be set by CurrencyTile.lua when it loads
  return SkyInfoTiles._currencyList or {}
end

function SkyInfoTiles.RefreshCurrencyTile()
  -- Find and update the currency tile
  for _, f in ipairs(tilesFrames) do
    if f and f._cfg and (f._cfg.key == "currencies" or f._cfg.type == "currencies") then
      local ttype = TILE_TYPES[f._cfg.type]
      if ttype and ttype.update then
        ttype.update(f, f._cfg)
      end
      break
    end
  end
end

function SkyInfoTiles.ToggleLock()
  SkyInfoTilesDB.locked = not SkyInfoTilesDB.locked
  SkyInfoTiles.ApplyLockState()
  Print(SkyInfoTilesDB.locked and "Locked" or "Unlocked")
  -- Update options window if open
  if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
end

function SkyInfoTiles.ApplyLockState()
  SkyInfoTiles.SetLocked(SkyInfoTilesDB.locked)
end

function SkyInfoTiles.ResetProfile()
  ResetToCatalogDefaults()
end

function SkyInfoTiles.CleanProfile()
  local a, r = MigrateLegacy()
  SeedCatalog()
  SkyInfoTiles.Rebuild()
  SkyInfoTiles.UpdateAll()
  if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  return a, r
end

-- ===== Slash commands =====
SLASH_SKYINFOTILES1 = "/skytiles"
SLASH_SKYINFOTILES2 = "/skyinfotiles"
SLASH_SKYINFOTILES3 = "/infotiles" -- backward compatibility

SlashCmdList["SKYINFOTILES"] = function(msg)
  msg = Trim(msg or "")
  local cmd, rest = msg:match("^(%S+)%s*(.*)$")
  if not cmd or cmd == "" then
    Print("Commands: lock, unlock, enable <key>, disable <key>, list, reset, clean, options, scope <char|warband>, outline <none|outline|thick>, layout <key> <horizontal|vertical>, preview <key> <on|off>, scale <key> <0.5-2.0>")
    Print("Keys: currencies, keystone, charstats, crosshair, clock, dungeonports")
    return
  end
  cmd = cmd:lower()

  if cmd == "lock"   then SkyInfoTiles.SetLocked(true);  Print("Locked."); return end
  if cmd == "unlock" then SkyInfoTiles.SetLocked(false); Print("Unlocked."); return end

  if cmd == "enable"  then SkyInfoTiles.SetTileEnabledByKey(rest:lower(), true);  return end
  if cmd == "disable" then SkyInfoTiles.SetTileEnabledByKey(rest:lower(), false); return end

  if cmd == "list" then
    for _, cat in ipairs(CATALOG) do
      local cfg = FindTileByKey(cat.key)
      local on  = cfg and (cfg.enabled ~= false)
      local pos = cfg and (("%s (%.1f, %.1f)"):format(cfg.point or "TOPLEFT", cfg.x or 0, cfg.y or 0)) or "n/a"
      Print(string.format("[%s] %s  (%s)  pos=%s", cat.key, cat.label, on and "enabled" or "disabled", pos))
    end
    return
  end

  if cmd == "reset" then ResetToCatalogDefaults(); return end

  if cmd == "clean" then
    local a, r = MigrateLegacy()
    SeedCatalog()
    SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll()
    if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
    Print(("Clean done. Assigned keys: %d, removed dupes: %d."):format(a, r))
    return
  end

  if cmd == "options" then
    if SkyInfoTiles.OpenOptions then SkyInfoTiles.OpenOptions() else Print("Open Interface -> AddOns -> SkyInfoTiles.") end
    return
  end



  if cmd == "scope" then
    local v = (rest or ""):lower()
    if v ~= "char" and v ~= "warband" then Print("Usage: /skytiles scope <char|warband>"); return end
    SkyInfoTilesDB.scope = v; SkyInfoTiles.UpdateAll(); Print("Scope set to "..v.."."); return
  end

  if cmd == "outline" then
    local v = (rest or ""):upper()
    if v == "NONE" or v == "OFF" or v == "" then
      SkyInfoTilesDB.fontOutline = ""
    elseif v == "THICK" or v == "THICKOUTLINE" then
      SkyInfoTilesDB.fontOutline = "THICKOUTLINE"
    else
      SkyInfoTilesDB.fontOutline = "OUTLINE"
    end
    Print("Outline set to " .. (SkyInfoTilesDB.fontOutline == "" and "NONE" or SkyInfoTilesDB.fontOutline) .. ".")
    SkyInfoTiles.UpdateAll()
    return
  end

  if cmd == "layout" then
    local key, orient = rest:match("^(%S+)%s+(%S+)$")
    if not key or not orient then Print("Usage: /skytiles layout <key> <horizontal|vertical>"); return end
    orient = orient:lower()
    if orient ~= "horizontal" and orient ~= "vertical" then
      Print("Usage: /skytiles layout <key> <horizontal|vertical>"); return
    end
    local cat = FindCatByKey(key)
    if not cat then Print("Unknown key: " .. tostring(key)); return end
    local cfg = FindTileByKey(key) or EnsureTileExistsForCat(cat)
    cfg.orientation = orient
    SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll()
    Print(string.format("Layout for [%s] set to %s.", key, orient))
    return
  end

  if cmd == "preview" then
    local key, state = rest:match("^(%S+)%s+(%S+)$")
    if not key or not state then Print("Usage: /skytiles preview <key> <on|off>"); return end
    state = state:lower()
    if state ~= "on" and state ~= "off" and state ~= "true" and state ~= "false" then
      Print("Usage: /skytiles preview <key> <on|off>"); return
    end
    local cat = FindCatByKey(key)
    if not cat then Print("Unknown key: " .. tostring(key)); return end
    local cfg = FindTileByKey(key) or EnsureTileExistsForCat(cat)
    cfg.preview = (state == "on" or state == "true")
    SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll()
    Print(string.format("Preview for [%s] set to %s.", key, cfg.preview and "ON" or "OFF"))
    return
  end

  if cmd == "scale" then
    local key, sval = rest:match("^(%S+)%s+(%S+)$")
    if not key or not sval then Print("Usage: /skytiles scale <key> <0.5-2.0>"); return end
    local v = tonumber(sval)
    if not v then Print("Usage: /skytiles scale <key> <0.5-2.0>"); return end
    if v < 0.5 then v = 0.5 elseif v > 2.0 then v = 2.0 end
    local cat = FindCatByKey(key)
    if not cat then Print("Unknown key: " .. tostring(key)); return end
    local cfg = FindTileByKey(key) or EnsureTileExistsForCat(cat)
    cfg.scale = v
    SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll()
    Print(string.format("Scale for [%s] set to %.2f.", key, v))
    return
  end

  if cmd == "strata" then
    local key, strataVal = rest:match("^(%S+)%s+(%S+)$")
    if not key or not strataVal then
      Print("Usage: /skytiles strata <key> <BACKGROUND|LOW|MEDIUM|HIGH|DIALOG|FULLSCREEN|FULLSCREEN_DIALOG|TOOLTIP>")
      return
    end

    -- Validate strata
    local validStrata = { BACKGROUND=true, LOW=true, MEDIUM=true, HIGH=true, DIALOG=true, FULLSCREEN=true, FULLSCREEN_DIALOG=true, TOOLTIP=true }
    strataVal = strataVal:upper()
    if not validStrata[strataVal] then
      Print("Invalid strata. Valid values: BACKGROUND, LOW, MEDIUM, HIGH, DIALOG, FULLSCREEN, FULLSCREEN_DIALOG, TOOLTIP")
      return
    end

    local cat = FindCatByKey(key)
    if not cat then Print("Unknown key: " .. tostring(key)); return end
    local cfg = FindTileByKey(key) or EnsureTileExistsForCat(cat)
    cfg.strata = strataVal
    SkyInfoTiles.Rebuild(); SkyInfoTiles.UpdateAll()
    Print(string.format("Strata for [%s] set to %s.", key, strataVal))
    return
  end

  if cmd == "uiscale" then
    Print("UI scale control is disabled.")
    return
  end

  if cmd == "profile" then
    local sub, args = rest:match("^(%S+)%s*(.*)$")
    sub = (sub or ""):lower()

    local function ListProfilesCmd()
      local active = SkyInfoTiles.GetActiveProfileName()
      local charKey = GetCharacterKey()
      Print("Profiles:")
      Print(string.format("Current character: %s", charKey))
      Print(string.format("Active profile: %s", active))
      Print("")
      Print("Available profiles:")
      for name, prof in pairs(SkyInfoTilesDB.profiles or {}) do
        local mark = (name == active) and "*" or ""
        local defMark = (name == "Default") and "(Default)" or ""
        Print(string.format(" %s %s %s (tiles=%d)", mark, name, defMark, type(prof.tiles)=="table" and #prof.tiles or 0))
      end
    end

    if sub == "list" or sub == "" then
      ListProfilesCmd(); return
    elseif sub == "set" then
      local name = args ~= "" and args or "Default"
      local success, err = SkyInfoTiles.SetActiveProfile(name)
      if success then
        Print("Profile set to "..name..".")
      else
        Print("Error: "..tostring(err))
      end
      return
    elseif sub == "new" then
      local name, copy = args:match("^(%S+)%s*(.*)$")
      if not name or name == "" then Print("Usage: /skytiles profile new <name> [copyFrom]"); return end
      local copyFrom = (copy and copy ~= "") and copy or nil
      local success, err = SkyInfoTiles.CreateProfile(name, copyFrom)
      if success then
        Print("Profile created: "..name)
      else
        Print("Error: "..tostring(err))
      end
      return
    elseif sub == "rename" then
      local oldName, newName = args:match("^(%S+)%s+(%S+)$")
      if not oldName or not newName then Print("Usage: /skytiles profile rename <oldName> <newName>"); return end
      local success, err = SkyInfoTiles.RenameProfile(oldName, newName)
      if success then
        Print(string.format("Renamed profile '%s' to '%s'.", oldName, newName))
      else
        Print("Error: "..tostring(err))
      end
      return
    elseif sub == "delete" then
      local name = args ~= "" and args or nil
      if not name then Print("Usage: /skytiles profile delete <name>"); return end
      local success, err = SkyInfoTiles.DeleteProfile(name)
      if success then
        Print("Deleted profile: "..name)
      else
        Print("Error: "..tostring(err))
      end
      return
    else
      Print("Usage: /skytiles profile <list|set|new|rename|delete>")
      return
    end
  end

  Print("Unknown command.")
end

-- ===== Events =====
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    SkyInfoTilesDB = SkyInfoTilesDB or {}
    applyDefaults(SkyInfoTilesDB, DEFAULTS)

    -- Migration v2: New profile system (per-character profile selection)
    if not SkyInfoTilesDB._migrated_profiles_v2 then

      -- 1. Migrera gamla root-profil till characterProfiles
      if SkyInfoTilesDB.profile then
        local charKey = GetCharacterKey()
        SkyInfoTilesDB.characterProfiles = SkyInfoTilesDB.characterProfiles or {}
        -- Sätt nuvarande karaktärs profil-val
        SkyInfoTilesDB.characterProfiles[charKey] = SkyInfoTilesDB.profile
        SkyInfoTilesDB.profile = nil  -- Ta bort gamla globala fältet
      end

      -- 2. Ta bort spec-profil systemet helt
      SkyInfoTilesDB.enableSpecProfiles = nil
      SkyInfoTilesDB.specProfiles = nil

      -- 3. Migrera legacy tiles till Default-profil om de finns
      if SkyInfoTilesDB.tiles and type(SkyInfoTilesDB.tiles) == "table" and #SkyInfoTilesDB.tiles > 0 then
        SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or {}
        if not SkyInfoTilesDB.profiles.Default then
          SkyInfoTilesDB.profiles.Default = { tiles = SkyInfoTilesDB.tiles }
        elseif type(SkyInfoTilesDB.profiles.Default.tiles) ~= "table" or #SkyInfoTilesDB.profiles.Default.tiles == 0 then
          SkyInfoTilesDB.profiles.Default.tiles = SkyInfoTilesDB.tiles
        end
        SkyInfoTilesDB.tiles = nil
      end

      -- 4. Säkerställ att Default-profil finns
      SkyInfoTilesDB.profiles = SkyInfoTilesDB.profiles or {}
      if not SkyInfoTilesDB.profiles.Default then
        SkyInfoTilesDB.profiles.Default = { tiles = {} }
      end

      -- 5. Initiera characterProfiles om den inte finns
      SkyInfoTilesDB.characterProfiles = SkyInfoTilesDB.characterProfiles or {}

      -- Markera migration som klar
      SkyInfoTilesDB._migrated_profiles_v2 = true
    end

    -- Migration v2.4: Convert all tiles from CENTER anchor to TOPLEFT anchor
    if not SkyInfoTilesDB._migrated_anchor_topleft then
      if type(SkyInfoTilesDB.profiles) == "table" then
        for _, prof in pairs(SkyInfoTilesDB.profiles) do
          if type(prof) == "table" and type(prof.tiles) == "table" then
            for _, tile in ipairs(prof.tiles) do
              if tile and tile.point == "CENTER" then
                -- Skip crosshair - it stays at CENTER
                if tile.key == "crosshair" or tile.type == "crosshair" then
                  -- Keep crosshair at CENTER (0, 0)
                  tile.point = "CENTER"
                  tile.x = 0
                  tile.y = 0
                else
                  -- Convert CENTER coordinates to TOPLEFT coordinates
                  -- CENTER (0,0) is screen center, TOPLEFT (0,0) is top-left corner
                  -- TOPLEFT_x = CENTER_x + screenWidth/2
                  -- TOPLEFT_y = CENTER_y - screenHeight/2
                  local screenWidth = math.floor((GetScreenWidth and GetScreenWidth() or 1920) + 0.5)
                  local screenHeight = math.floor((GetScreenHeight and GetScreenHeight() or 1080) + 0.5)

                  local centerX = tile.x or 0
                  local centerY = tile.y or 0

                  tile.point = "TOPLEFT"
                  tile.x = centerX + screenWidth / 2
                  tile.y = centerY - screenHeight / 2
                end
              end
            end
          end
        end
      end
      SkyInfoTilesDB._migrated_anchor_topleft = true
    end

    -- Vid varje login: säkerställ att nuvarande karaktär har en profil vald
    local charKey = GetCharacterKey()
    if not SkyInfoTilesDB.characterProfiles[charKey] then
      SkyInfoTilesDB.characterProfiles[charKey] = "Default"
    end

    -- Remove deprecated tiles from all profiles (1.7.1 cleanup)
    if not SkyInfoTilesDB._migrated_171_removeDeprecatedTiles then
      local remove = { healthbox = true, petbox = true, targetbox = true, groupbuffs = true }
      if type(SkyInfoTilesDB.profiles) == "table" then
        for _, prof in pairs(SkyInfoTilesDB.profiles) do
          if type(prof) == "table" and type(prof.tiles) == "table" then
            for i = #prof.tiles, 1, -1 do
              local k = prof.tiles[i] and prof.tiles[i].key
              if k and remove[k] then
                table.remove(prof.tiles, i)
              end
            end
          end
        end
      end
      SkyInfoTilesDB._migrated_171_removeDeprecatedTiles = true
    end

    -- Migrate legacy "season3" tile to "currencies" (1.8.2+)
    -- IMPORTANT: Must run BEFORE MigrateLegacy() to avoid creating duplicates
    if not SkyInfoTilesDB._migrated_182_season3ToCurrencies then
      if type(SkyInfoTilesDB.profiles) == "table" then
        for _, prof in pairs(SkyInfoTilesDB.profiles) do
          if type(prof) == "table" and type(prof.tiles) == "table" then
            for _, t in ipairs(prof.tiles) do
              if t and (t.key == "season3" or t.type == "season3") then
                t.key = "currencies"
                t.type = "currencies"
                t.label = "Currencies"
              end
            end
          end
        end
      end
      SkyInfoTilesDB._migrated_182_season3ToCurrencies = true
    end

    local a, r = MigrateLegacy()
    SeedCatalog()
    SkyInfoTiles.Rebuild()
    SkyInfoTiles.UpdateAll()
    if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end

    -- Start background font discovery (prevents UI freeze on first dropdown open)
    if SkyInfoTiles.StartFontDiscovery then
      SkyInfoTiles.StartFontDiscovery()
    end

    if not SkyInfoTilesDB._helloShown then
      Print("Open Interface -> AddOns -> SkyInfoTiles to toggle tiles. Tip: /skytiles clean if you see duplicates.")
      SkyInfoTilesDB._helloShown = true
    end
    if (a > 0 or r > 0) then
      Print(("Migrated legacy: assigned=%d, removed=%d."):format(a, r))
    end
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    SkyInfoTiles.UpdateAll()
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    SkyInfoTiles.Rebuild()
    SkyInfoTiles.UpdateAll()
    if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if SkyInfoTiles._pendingRebuild then
      SkyInfoTiles._pendingRebuild = false
      SkyInfoTiles.Rebuild()
      SkyInfoTiles.UpdateAll()
      if SkyInfoTiles._OptionsRefresh then SkyInfoTiles._OptionsRefresh() end
    end
  end
end)
