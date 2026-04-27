-- SkyInfoTiles - Keystone tile (icon + level + dungeon, left-click on ICON to teleport, ALT+RightClick = debug)
local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI
local Utils = SkyInfoTiles.Utils  -- Shared string normalization utilities

local KEYSTONE_ITEM_ID = 180653
local API = {}

-- Visual
local ICON_SIZE  = 36
local BORDER_PX  = 2

-- Max level gate
local function IsAtMaxLevel()
  local cur = (UnitLevel and UnitLevel("player")) or nil
  local mx = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or (MAX_PLAYER_LEVEL) or nil
  if cur and mx then return cur >= mx end
  return true
end

-- ======================== Utils / DB / Chat ========================
local function Chat(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r "..tostring(msg))
  end
end

-- Use shared normalization functions from SkyInfoTiles.Utils
local NormKey = Utils.NormKey
local Norm = Utils.Norm
local TokensFromName = Utils.TokensFromName

local function EnsureDB()
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.teleportMap = SkyInfoTilesDB.teleportMap or {} -- [normDungeonKey] = { id=12345, name="..." }
end

local function SaveTeleportMap(dungeonName, spellID, spellName)
  EnsureDB()
  local key = NormKey(dungeonName or "")
  if key == "" then return end
  SkyInfoTilesDB.teleportMap[key] = { id = tonumber(spellID) or nil, name = spellName or nil }
end

local function LoadTeleportMap(dungeonName)
  EnsureDB()
  local key = NormKey(dungeonName or "")
  return SkyInfoTilesDB.teleportMap[key]
end

-- ======================== Preset mapping (non-1:1 names) ========================
-- Include ID for immediate binding (locale-independent)
local PRESET_TELEPORT_MAP = {
  -- Midnight Season 1 dungeons (verified spell IDs from MythicDungeonPortals addon)
  ["maisaracaverns"] = { id = 1254559, name = "Teleport: Maisara Caverns" },
  ["magistersterrace"] = { id = 1254572, name = "Teleport: Magisters' Terrace" },
  ["nexuspointxenas"] = { id = 1254563, name = "Teleport: Nexus-Point Xenas" },
  ["windrunnerspire"] = { id = 1254400, name = "Teleport: Windrunner Spire" },
  ["algetharacademy"] = { id = 393273, name = "Teleport: Algeth'ar Academy" },
  ["seatofthetriumvirate"] = { id = 1254551, name = "Teleport: Seat of the Triumvirate" },
  ["skyreach"] = { id = 159898, name = "Teleport: Skyreach" },
  ["pitofsaron"] = { id = 1254555, name = "Teleport: Pit of Saron" },

  -- Other dungeons
  ["prioryofthesacredflame"] = { id = 445444, name = "Path of the Light's Reverence" }, -- Priory
  ["tazaveshstreetsofwonder"] = { name = "Path of the Streetwise Merchant" },
  ["tazaveshsoleahsgambit"] = { name = "Path of the Streetwise Merchant" },
  ["operationfloodgate"] = { id = 1216786 },
  ["ecodomealdani"] = { id = 1237215, name = "Path of Eco-Dome" },
  ["thedawnbreaker"] = { id = 445414, name = "Path of the Arathi Flagship" },
  ["arakaracityofechoes"] = { id = 445417, name = "Path of the Ruined City" },
  ["hallsofatonement"] = { id = 354465, name = "Path of the Sinful Soul" },
}

-- Aliases for description matching (e.g., halves -> base name)
local DESC_ALIAS = {
  ["tazaveshstreetsofwonder"] = "tazavesh the veiled market",
  ["tazaveshsoleahsgambit"] = "tazavesh the veiled market",
  ["operationfloodgate"] = "floodgate",
}

-- ======================== Keystone parsing ========================
local function GetDisplayText(link)
  if not link then return nil end
  local disp = link:match("|h%[(.-)%]|h")
  if disp and disp ~= "" then return disp end
  if link:match("^%[.*%]$") then
    return (link:gsub("^%[",""):gsub("%]$",""))
  end
  return link
end

-- Parse "Keystone: <NAME> (<LEVEL>)"
local function ParseNameLevelFromDisplay(disp)
  if not disp or disp == "" then return nil, nil end
  local name, lvl = disp:match("^[^:]+:%s*(.-)%s*%((%d+)%)%s*$")
  if name and lvl then return name, tonumber(lvl) end
  local name2, tail = disp:match("^[^:]+:%s*(.-)%s*(%b())%s*$")
  if name2 and tail then
    local digits = tail:match("(%d+)")
    if digits then return name2, tonumber(digits) end
  end
  local after = disp:gsub("^[^:]*:%s*", "")
  local lvl3  = tonumber(after:match("%((%d+)%)%s*$"))
  local name3 = after:gsub("%s*%b()%s*$",""):gsub("%s+$","")
  if name3 ~= "" then return name3, lvl3 end
  return nil, lvl3
end

-- ======================== Keystone readers (API + bags) ========================
local SEARCH_BAG_IDS = {0,1,2,3,4,5}

local function OwnedKeyFromAPI()
  local level = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
  local link  = C_MythicPlus.GetOwnedKeystoneLink and C_MythicPlus.GetOwnedKeystoneLink()
  local mapID = C_MythicPlus.GetOwnedKeystoneMapID and C_MythicPlus.GetOwnedKeystoneMapID()
  local disp  = GetDisplayText(link)
  local nameL, lvlL = ParseNameLevelFromDisplay(disp)
  return {
    level = lvlL or level,
    name  = nameL,
    link  = link,
    disp  = disp,
    mapID = (mapID and mapID > 0) and mapID or nil,
  }
end

local function OwnedKeyFromBags()
  for _, bag in ipairs(SEARCH_BAG_IDS) do
    local slots = C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
    if slots and slots > 0 then
      for slot = 1, slots do
        local id = C_Container.GetContainerItemID(bag, slot)
        if id == KEYSTONE_ITEM_ID then
          local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
          local link = (info and info.hyperlink) or (GetContainerItemLink and GetContainerItemLink(bag, slot))
          local disp = GetDisplayText(link)
          local nameL, lvlL = ParseNameLevelFromDisplay(disp)
          if nameL or lvlL then
            return { level = lvlL, name = nameL, link = link, disp = disp, mapID = nil }
          end
        end
      end
    end
  end
  return nil
end

-- ======================== Map resolving (for icon) ========================
local MAP_ICON_CACHE = {}

local function TryGetMapIcon(mapID)
  if not mapID then return nil end
  if MAP_ICON_CACHE[mapID] then return MAP_ICON_CACHE[mapID] end
  if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local n, _, _, tex = C_ChallengeMode.GetMapUIInfo(mapID)
    if not tex then
      local v = C_ChallengeMode.GetMapUIInfo(mapID)
      if type(v) == "table" then tex = v.texture or v.icon or v.iconFileID end
    end
    if tex then MAP_ICON_CACHE[mapID] = tex; return tex end
  end
  if C_ChallengeMode and C_ChallengeMode.GetMapInfo then
    local t = C_ChallengeMode.GetMapInfo(mapID)
    if type(t) == "table" then
      local tex = t.texture or t.icon or t.iconFileID
      if tex then MAP_ICON_CACHE[mapID] = tex; return tex end
    end
  end
  return nil
end

local function FindMapIDByNameTokens(dungeonName)
  if not (C_ChallengeMode and C_ChallengeMode.GetMapTable) then return nil end
  local tokens = TokensFromName(dungeonName); tokens = tokens or {}
  local ids = C_ChallengeMode.GetMapTable()
  if type(ids) ~= "table" then return nil end
  for _, id in ipairs(ids) do
    local v = C_ChallengeMode.GetMapUIInfo(id)
    local nm = (type(v)=="string" and v) or (type(v)=="table" and v.name) or ""
    local nmNorm = Norm(nm)
    local ok = true
    for _, tk in ipairs(tokens) do
      if not nmNorm:find(tk, 1, true) then ok = false; break end
    end
    if ok then return id end
  end
  return nil
end

-- ======================== Gather (name/level/icon) ========================
local function Gather()
  local api = OwnedKeyFromAPI()
  local bag = OwnedKeyFromBags()
  local src = (bag and bag.disp and (bag.name or not (api and api.name)) and bag) or api or bag
  if not src or (not src.level and not src.name and not src.disp) then return nil end

  local name = src.name
  local mapID = src.mapID
  local disp = src.disp

  -- Derive name from mapID if missing
  if not name and mapID and C_ChallengeMode then
    if C_ChallengeMode.GetMapUIInfo then
      local v = C_ChallengeMode.GetMapUIInfo(mapID)
      local nm = (type(v) == "string" and v) or (type(v) == "table" and v.name) or nil
      if nm and nm ~= "" then name = nm end
    end
    if not name and C_ChallengeMode.GetMapInfo then
      local t = C_ChallengeMode.GetMapInfo(mapID)
      if type(t) == "table" and t.name and t.name ~= "" then name = t.name end
    end
  end

  -- Derive name from display text if still missing
  if not name and disp then
    local nameL = ParseNameLevelFromDisplay(disp)
    if type(nameL) == "string" and nameL ~= "" then
      name = nameL
    end
  end

  -- Fallback: resolve mapID via name if API didn't supply
  if not mapID and name then
    mapID = FindMapIDByNameTokens(name)
  end

  name = name or "Keystone"

  local mapIcon = TryGetMapIcon(mapID)
  local icon = mapIcon or (GetItemIcon and GetItemIcon(KEYSTONE_ITEM_ID)) or 525134

  return { level = src.level, name = name, icon = icon, mapID = mapID, disp = disp }
end

-- ======================== Teleport resolving (with description matching) ========================
local teleportCache -- { {id, nameNorm, descNorm, rawName} , ... }

local function BuildTeleportCache()
  teleportCache = {}
  if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo) then return end
  local tabs = GetNumSpellTabs() or 0
  for t = 1, tabs do
    local _, _, ofs, num = GetSpellTabInfo(t)
    ofs, num = ofs or 0, num or 0
    for slot = ofs + 1, ofs + num do
      local typ, spellID = GetSpellBookItemInfo(slot, "spell")
      if typ == "SPELL" and spellID then
        local si = (C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)) or nil
        local nm = si and si.name or nil
        if type(nm) == "string" and nm ~= "" then
          local desc = (C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID))
                    or (GetSpellDescription and GetSpellDescription(spellID))
                    or (si and si.description)
                    or ""
          table.insert(teleportCache, {
            id       = spellID,
            rawName  = nm,
            nameNorm = Norm(nm),
            descNorm = Norm(desc),
          })
        end
      end
    end
  end
end

local function ResolveTeleportForDungeon(dungeonName)
  if not dungeonName or dungeonName == "" then return nil, nil end

  -- 0) DB/preset
  local key = NormKey(dungeonName)
  local map = LoadTeleportMap(dungeonName) or PRESET_TELEPORT_MAP[key]
  if map then
    -- if ID present, verify known then use its localized name
    if map.id and (IsPlayerSpell and IsPlayerSpell(map.id) or IsSpellKnown and IsSpellKnown(map.id)) then
      local si = (C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(map.id))
      return map.id, (si and si.name) or map.name
    end
    if map.name and C_Spell and C_Spell.GetSpellInfo then
      local si = C_Spell.GetSpellInfo(map.name)
      if si and si.spellID and (IsPlayerSpell(si.spellID) or IsSpellKnown(si.spellID)) then
        return si.spellID, si.name
      end
    end
  end

  -- 1) Build cache and tokens
  if not teleportCache then BuildTeleportCache() end
  if not teleportCache or #teleportCache == 0 then return nil, nil end

  local nk = NormKey(dungeonName)
  local tokenSource = (DESC_ALIAS and DESC_ALIAS[nk]) or dungeonName
  local tokens = TokensFromName(tokenSource) or {}

  -- 2) Primary: description must contain all tokens
  for _, rec in ipairs(teleportCache) do
    local okAll = true
    for _, tk in ipairs(tokens) do
      if not rec.descNorm:find(tk, 1, true) then okAll = false; break end
    end
    if okAll then
      SaveTeleportMap(dungeonName, rec.id, rec.rawName)
      return rec.id, rec.rawName
    end
  end

  -- 3) Fallback: name contains at least one token (looser)
  local bestID, bestName, bestScore = nil, nil, 0
  for _, rec in ipairs(teleportCache) do
    local score = 0
    for _, tk in ipairs(tokens) do
      if rec.nameNorm:find(tk, 1, true) then score = score + 1 end
    end
    if score > bestScore then
      bestScore, bestID, bestName = score, rec.id, rec.rawName
    end
  end
  if bestScore > 0 then
    SaveTeleportMap(dungeonName, bestID, bestName)
    return bestID, bestName
  end

  -- 4) Last resort: description contains any token
  for _, rec in ipairs(teleportCache) do
    for _, tk in ipairs(tokens) do
      if rec.descNorm:find(tk, 1, true) then
        SaveTeleportMap(dungeonName, rec.id, rec.rawName)
        return rec.id, rec.rawName
      end
    end
  end

  return nil, nil
end

-- ======================== Public debug ========================
function SkyInfoTiles.DebugKeystoneTeleport()
  Chat("=== KeystoneTile Debug ===")
  local info = Gather()
  if not info then Chat("No keystone detected (API nor bags)."); return end
  Chat(("Keystone display: %s"):format(info.disp or "nil"))
  Chat(("Dungeon name: '%s'  level=%s"):format(tostring(info.name), tostring(info.level)))
  local tokens, nkey = TokensFromName(info.name or "")
  Chat(("Norm key: %s  Tokens: %s"):format(nkey or "nil", table.concat(tokens or {}, ", ")))

  local db = LoadTeleportMap(info.name)
  local ps = PRESET_TELEPORT_MAP[nkey or ""]
  if db then Chat(("DB mapping: id=%s name=%s"):format(tostring(db.id), tostring(db.name))) else Chat("DB mapping: <none>") end
  if ps then Chat(("Preset mapping: %s%s%s"):format(ps.id and ("id="..ps.id.." ") or "", ps.name and ("name="..ps.name) or "", "")) else Chat("Preset mapping: <none>") end

  teleportCache = nil; BuildTeleportCache()
  Chat(("Spell cache size: %d"):format(teleportCache and #teleportCache or 0))

  local shown = 0
  for _, rec in ipairs(teleportCache or {}) do
    local okAll = true
    for _, tk in ipairs(tokens or {}) do
      if not rec.descNorm:find(tk, 1, true) then okAll = false; break end
    end
    if okAll then
      Chat(("* match(desc): id=%d name=%s"):format(rec.id, rec.rawName))
      shown = shown + 1
      if shown >= 10 then break end
    end
  end
  if shown == 0 then Chat("No desc-matches for all tokens.") end

  local rid, rname = ResolveTeleportForDungeon(info.name)
  if rid then
    local rlocal = (C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(rid))
    Chat(("[RESOLVED] id=%d  name=%s (localized=%s) known=%s")
      :format(rid, rname or "", rlocal and rlocal.name or "?", tostring(IsPlayerSpell and IsPlayerSpell(rid))))
  else
    Chat("[RESOLVED] No teleport found.")
  end
end

function SkyInfoTiles.DebugKeystoneBackground()
  Chat("=== KeystoneTile Background Debug ===")
  if SkyInfoTiles.GetActiveTiles then
    local tiles = SkyInfoTiles.GetActiveTiles()
    for _, tile in ipairs(tiles) do
      if tile.key == "keystone" or tile.type == "keystone" then
        Chat(("showBackground: %s"):format(tostring(tile.showBackground)))
        if tile.backgroundColor then
          Chat(("backgroundColor: r=%.2f g=%.2f b=%.2f a=%.2f"):format(
            tile.backgroundColor.r or 0,
            tile.backgroundColor.g or 0,
            tile.backgroundColor.b or 0,
            tile.backgroundColor.a or 0
          ))
        else
          Chat("backgroundColor: nil (using default: black)")
        end
        Chat(("showBorder: %s"):format(tostring(tile.showBorder)))
        if tile.borderColor then
          Chat(("borderColor: r=%.2f g=%.2f b=%.2f a=%.2f"):format(
            tile.borderColor.r or 0,
            tile.borderColor.g or 0,
            tile.borderColor.b or 0,
            tile.borderColor.a or 0
          ))
        else
          Chat("borderColor: nil (using default: white)")
        end
        return
      end
    end
    Chat("Keystone tile not found in active tiles!")
  else
    Chat("SkyInfoTiles.GetActiveTiles not available!")
  end
end

-- ======================== Bind to ICON (secure) ========================
local function BindTeleportToButton(btn, dungeonName)
  local spellID, spellName = ResolveTeleportForDungeon(dungeonName)

  -- lookup localized name if only ID known
  if (not spellName) and spellID then
    if C_Spell and C_Spell.GetSpellInfo then
      local si = C_Spell.GetSpellInfo(spellID)
      spellName = si and si.name or spellName
    end
    if (not spellName) and GetSpellInfo then
      spellName = (GetSpellInfo(spellID))
    end
  end

  if InCombatLockdown and InCombatLockdown() then
    btn._pendingSpellName = spellName or false
    return
  end

  if spellName then
    -- Pure secure spell casting on left click (set both generic and button-1 specific attrs)
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("type1", "spell")
    btn:SetAttribute("spell", spellName)     -- localized spell name required
    btn:SetAttribute("spell1", spellName)
    btn._teleName = spellName
  else
    btn:SetAttribute("type", nil)
    btn:SetAttribute("type1", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("spell1", nil)
    btn._teleName = nil
  end
end

-- ======================== Tile ========================
function API.create(parent, cfg)
  -- Create wrapper frame (doesn't scale, only holds position)
  local f = CreateFrame("Frame", nil, parent)
  -- Height: 8px top padding + 36px icon + 8px bottom padding = 52px (was 64px)
  f:SetSize(300, 52)
  f._cfg = cfg

  -- Create content frame with BackdropTemplate (this is what scales, includes backdrop directly)
  f.content = CreateFrame("Frame", nil, f, "BackdropTemplate")
  f.content:SetSize(300, 52)
  f.content:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

  -- Set initial backdrop (will be updated later)
  f.content:SetBackdrop({
    bgFile = nil,
    edgeFile = nil,
    tile = false,
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
  })
  f.content:SetBackdropColor(0, 0, 0, 0)
  f.content:SetBackdropBorderColor(0, 0, 0, 0)

  -- Keep reference to backdrop for code compatibility
  f.backdrop = f.content

  -- Icon (created on content frame)
  f.icon = f.content:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(ICON_SIZE, ICON_SIZE)
  f.icon:SetPoint("TOPLEFT", f.content, "TOPLEFT", 8, -8)
  f.icon:SetTexture((GetItemIcon and GetItemIcon(KEYSTONE_ITEM_ID)) or 525134)

  -- Dark border (non-mouse)
  f.iconBorder = CreateFrame("Frame", nil, f.content, "BackdropTemplate")
  f.iconBorder:SetPoint("TOPLEFT",     f.icon, -BORDER_PX,  BORDER_PX)
  f.iconBorder:SetPoint("BOTTOMRIGHT", f.icon,  BORDER_PX, -BORDER_PX)
  f.iconBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = BORDER_PX })
  f.iconBorder:SetBackdropBorderColor(0, 0, 0, 0.95)
  f.iconBorder:EnableMouse(false)

  -- Level
  f.level = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  UI.Outline(f.level, { weight = "THICKOUTLINE" })
  f.level:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
  f.level:SetTextColor(1.00, 0.82, 0.00, 1)
  f.level:SetShadowColor(0,0,0,1)
  f.level:SetShadowOffset(1,-1)
  do local font, _, flags = f.level:GetFont(); f.level:SetFont(font, ICON_SIZE, flags or "OUTLINE") end
  f.level:SetText("--")

  -- Dungeon name (with word wrap enabled)
  f.name = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  UI.Outline(f.name)
  f.name:SetPoint("LEFT", f.level, "RIGHT", 12, -2)
  f.name:SetPoint("RIGHT", f.content, "RIGHT", -8, 0)
  f.name:SetTextColor(1.00, 0.60, 0.00, 1)
  f.name:SetShadowColor(0,0,0,1); f.name:SetShadowOffset(1,-1)
  f.name:SetJustifyH("LEFT")
  f.name:SetJustifyV("TOP")
  if f.name.SetWordWrap     then f.name:SetWordWrap(true) end
  if f.name.SetNonSpaceWrap then f.name:SetNonSpaceWrap(false) end
  if f.name.SetMaxLines     then f.name:SetMaxLines(2) end
  do local font, _, flags = f.name:GetFont(); f.name:SetFont(font, 18, flags or "OUTLINE") end
  f.name:SetText("No keystone")

  -- Subtitle removed per request
  f.subtitle = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.subtitle:Hide()

  -- Secure click-to-cast overlay ONLY ON ICON (create only when safe)
  f.cast = nil
  local function CreateCast()
    if f.cast then return end
    if InCombatLockdown and InCombatLockdown() then
      f._pendingCastCreate = true
      return
    end
    local btn = CreateFrame("Button", "SkyInfoTiles_KeystoneCast", f.content, "SecureActionButtonTemplate")
    btn:SetPoint("TOPLEFT", f.content, "TOPLEFT", 8, -8)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:RegisterForClicks("AnyDown", "AnyUp")      -- left/right on down/up (covers keydown cvar)
    -- Avoid toggling EnableMouse on secure buttons to prevent taint; use Show/Hide only
    btn:SetAttribute("type", nil)
    btn:SetFrameStrata("HIGH")
    btn:SetToplevel(true)
    btn:SetFrameLevel((f.content:GetFrameLevel() or 0) + 100)  -- ensure overlay is well above
    btn:SetScript("OnEnter", function(self)
      if not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      if self._teleName and self:IsMouseEnabled() then
        GameTooltip:AddLine("Left-click: Teleport", 0, 1, 0)
        GameTooltip:AddLine(self._teleName, 1, 0.82, 0)
      else
        GameTooltip:AddLine("Teleport unavailable.", 1, 0.3, 0.3)
      end
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f.cast = btn
    -- Initial bind and mouse-enable state (in case update already ran)
    local info = Gather()
    if info and info.name then
      BindTeleportToButton(btn, info.name)
    end
    local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
  end
  -- Create immediately if safe, or defer until out of combat
  if InCombatLockdown and InCombatLockdown() then
    f._pendingCastCreate = true
  else
    CreateCast()
  end

  -- Events
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:RegisterEvent("BAG_UPDATE_DELAYED")
  f:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
  f:RegisterEvent("CHALLENGE_MODE_START")
  f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
  f:RegisterEvent("SPELLS_CHANGED")        -- rebuild cache on changes
  f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- apply deferred secure attrs / creation

  -- Throttle cache rebuild (SPELLS_CHANGED can spam during addon loads)
  f._cacheRebuildPending = false
  local function ScheduleCacheRebuild()
    if f._cacheRebuildPending then return end
    f._cacheRebuildPending = true
    if C_Timer and C_Timer.After then
      C_Timer.After(1, function()
        f._cacheRebuildPending = false
        teleportCache = nil
      end)
    else
      -- Fallback: clear immediately if no timer API
      teleportCache = nil
      f._cacheRebuildPending = false
    end
  end

  f:SetScript("OnEvent", function(self, event)
    if event == "SPELLS_CHANGED" then
      ScheduleCacheRebuild()
    elseif event == "PLAYER_REGEN_ENABLED" then
      if f._pendingCastCreate and not (InCombatLockdown and InCombatLockdown()) then
        f._pendingCastCreate = nil
        CreateCast()
      end
      if f.cast and f.cast._pendingSpellName ~= nil then
        local spellName = f.cast._pendingSpellName; f.cast._pendingSpellName = nil
        BindTeleportToButton(f.cast, spellName or nil)
      end
      if f._pendingScale and f.content and f.content.SetScale then
        local sc = f._pendingScale
        f.content:SetScale(sc)
        f._appliedScale = sc
        f._pendingScale = nil
      end
    end
    API.update(self, cfg)
  end)

  -- Right-click anywhere on the tile = refresh; ALT+Right = debug
  if f.SetPropagateMouseClicks then f:SetPropagateMouseClicks(false) end
  f:SetScript("OnMouseDown", function(self, btn)
    if not (SkyInfoTilesDB and SkyInfoTilesDB.locked) and btn == "LeftButton" then
      if self.StartMoving then self:StartMoving() end
    end
  end)
  f:SetScript("OnMouseUp", function(self, btn)
    if not (SkyInfoTilesDB and SkyInfoTilesDB.locked) and btn == "LeftButton" then
      if self.StopMovingOrSizing then self:StopMovingOrSizing() end
      if self._cfg then
        -- Always convert position to CENTER-based coordinates for consistency with sliders
        local frameCenterX, frameCenterY = self:GetCenter()
        if frameCenterX and frameCenterY and UIParent then
          local screenCenterX, screenCenterY = UIParent:GetCenter()
          if screenCenterX and screenCenterY then
            local offsetX = frameCenterX - screenCenterX
            local offsetY = frameCenterY - screenCenterY
            self._cfg.point = "CENTER"
            self._cfg.x = math.floor(offsetX + 0.5)
            self._cfg.y = math.floor(offsetY + 0.5)
            -- Update options window if it's open
            if SkyInfoTiles._OptionsRefresh then
              SkyInfoTiles._OptionsRefresh()
            end
          end
        end
      end
      return
    end
    if btn == "RightButton" then
      if IsAltKeyDown() and SkyInfoTiles.DebugKeystoneTeleport then
        SkyInfoTiles.DebugKeystoneTeleport()
      else
        API.update(self, cfg)
      end
    end
  end)

  -- First paint
  f:SetScript("OnShow", function(self)
    API.update(self, cfg)
  end)

  -- Ensure initial paint immediately (in case OnShow hasn't fired yet)
  API.update(f, cfg)


  function f:Destroy()
    -- Defer cleanup while in combat; core will call rebuild again after lockdown
    if InCombatLockdown and InCombatLockdown() then return end

    -- Stop reacting to events and clear handlers
    if self.UnregisterAllEvents then self:UnregisterAllEvents() end
    if self.SetScript then
      self:SetScript("OnEvent", nil)
      self:SetScript("OnShow", nil)
      self:SetScript("OnMouseDown", nil)
      self:SetScript("OnMouseUp", nil)
    end

    -- Secure cast button overlay
    if self.cast then
      if self.cast.UnregisterAllEvents then self.cast:UnregisterAllEvents() end
      if self.cast.SetScript then
        self.cast:SetScript("OnEnter", nil)
        self.cast:SetScript("OnLeave", nil)
      end
      if self.cast.Hide then self.cast:Hide() end
      if self.cast.SetParent then self.cast:SetParent(nil) end
      self.cast = nil
    end

    -- Borders / textures
    if self.iconBorder then
      if self.iconBorder.Hide then self.iconBorder:Hide() end
      if self.iconBorder.SetParent then self.iconBorder:SetParent(nil) end
      self.iconBorder = nil
    end
    if self.icon then
      if self.icon.SetTexture then self.icon:SetTexture(nil) end
      if self.icon.Hide then self.icon:Hide() end
      if self.icon.SetParent then self.icon:SetParent(nil) end
      self.icon = nil
    end

    -- FontStrings
    local fields = { "level", "name", "subtitle" }
    for _, k in ipairs(fields) do
      local fs = self[k]
      if fs then
        if fs.SetText then fs:SetText("") end
        if fs.Hide then fs:Hide() end
        if fs.SetParent then fs:SetParent(nil) end
        self[k] = nil
      end
    end

    -- Finalize
    if self.Hide then self:Hide() end
    if self.SetParent then self:SetParent(nil) end
  end
  return f
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

  -- Apply scale (0.5 - 2.0) to content frame only (keeps wrapper position stable)
  local sc = (cfg and tonumber(cfg.scale)) or 1
  if sc < 0.5 then sc = 0.5 elseif sc > 2.0 then sc = 2.0 end
  if frame.content and frame.content.SetScale then
    if InCombatLockdown and InCombatLockdown() then
      frame._pendingScale = sc
    else
      if frame._appliedScale ~= sc then
        frame.content:SetScale(sc)
        frame._appliedScale = sc
        frame._pendingScale = nil
      end
    end
  end

  -- Apply background and border
  local showBg = cfg and cfg.showBackground
  local showBorder = cfg and cfg.showBorder
  local useClassColor = cfg and cfg.useClassColor
  local bg = (cfg and cfg.backgroundColor) or { r = 0, g = 0, b = 0, a = 0.8 }

  -- Override with class color if enabled
  if useClassColor then
    local _, class = UnitClass("player")
    if class then
      local classColor = nil
      -- Try modern API first (Retail 10.0+)
      if C_ClassColor and C_ClassColor.GetClassColor then
        classColor = C_ClassColor.GetClassColor(class)
      end
      -- Fallback to legacy globals
      if not classColor then
        classColor = (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]) or (_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[class])
      end
      if classColor then
        -- Keep alpha from saved settings, use RGB from class color
        bg = { r = classColor.r, g = classColor.g, b = classColor.b, a = bg.a }
      end
    end
  end

  local border = (cfg and cfg.borderColor) or { r = 1, g = 1, b = 1, a = 1 }
  local thickness = (cfg and cfg.borderThickness) or 2
  if thickness < 1 then thickness = 1 elseif thickness > 10 then thickness = 10 end

  -- Ensure backdrop frame exists and has correct stacking
  if frame.backdrop then
    -- Make sure backdrop is visible and behind other elements
    frame.backdrop:Show()

    -- ALWAYS use bgFile (never nil) - control visibility with alpha instead
    -- IMPORTANT: Use WHITE8x8 (pure white texture) so SetBackdropColor works correctly
    -- UI-Tooltip-Background is dark gray, which makes all colors look black
    local backdropInfo = {
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = showBorder and "Interface\\Buttons\\WHITE8x8" or nil,
      tile = false,
      tileEdge = false,
      edgeSize = showBorder and thickness or 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
    }

    frame.backdrop:SetBackdrop(backdropInfo)

    -- CRITICAL: Set colors IMMEDIATELY after SetBackdrop
    -- WoW requires this order for colors to apply correctly
    if showBg then
      -- Force color application - must be called every update
      frame.backdrop:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

      -- Debug output (remove after testing)
      if not frame._lastColorDebug or
         (frame._lastColorDebug.r ~= bg.r or frame._lastColorDebug.g ~= bg.g or
          frame._lastColorDebug.b ~= bg.b or frame._lastColorDebug.a ~= bg.a) then
        frame._lastColorDebug = {r=bg.r, g=bg.g, b=bg.b, a=bg.a}
        if DEFAULT_CHAT_FRAME and false then -- Set to true to enable debug
          DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff66ccffKeystone BG:|r r=%.2f g=%.2f b=%.2f a=%.2f",
            bg.r, bg.g, bg.b, bg.a))
        end
      end
    else
      frame.backdrop:SetBackdropColor(0, 0, 0, 0)
    end

    if showBorder then
      frame.backdrop:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
    else
      frame.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
    end
  end

  local info = Gather()
  if info then
    frame.icon:SetTexture(info.icon)
    frame.level:SetText(tostring(info.level or "--"))
    frame.name:SetText(info.name or "Unknown dungeon")
    if frame.cast then BindTeleportToButton(frame.cast, info.name) end
  else
    frame.icon:SetTexture((GetItemIcon and GetItemIcon(KEYSTONE_ITEM_ID)) or 525134)
    frame.level:SetText("--")
    frame.name:SetText("No keystone found")
    if frame.cast then BindTeleportToButton(frame.cast, nil) end
  end
  -- Enable teleport click only when Locked (so Unlocked can drag the tile)
  local locked = (SkyInfoTilesDB and SkyInfoTilesDB.locked) and true or false
  if frame.cast then
    -- Use z-order to control interactivity; avoid Show/Hide to prevent taint
    if locked then
      if not (InCombatLockdown and InCombatLockdown()) then
        frame.cast:SetFrameStrata(frame.content:GetFrameStrata() or "MEDIUM")
        frame.cast:SetFrameLevel((frame.content:GetFrameLevel() or 0) + 100)
      end
    else
      if not (InCombatLockdown and InCombatLockdown()) then
        frame.cast:SetFrameStrata("BACKGROUND")
        frame.cast:SetFrameLevel(1)
      end
    end
  end
  -- Ensure the base frame is draggable when unlocked (avoid protected mouse changes during combat)
  if frame.EnableMouse and frame.SetMovable then
    if not (InCombatLockdown and InCombatLockdown()) then
      frame:EnableMouse(not locked)
      frame:SetMovable(not locked)
      if not locked and frame.RegisterForDrag then
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", function(self)
          self:StopMovingOrSizing()
          local point, _, _, x, y = self:GetPoint()
          if self._cfg then self._cfg.point, self._cfg.x, self._cfg.y = point, x, y end
        end)
      elseif frame.RegisterForDrag then
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
      end
    end
  end

end

-- Chat commands for debug
SLASH_SKYKEYDEBUG1 = "/skykeydebug"
SlashCmdList["SKYKEYDEBUG"] = function(arg)
  arg = arg and arg:lower():trim() or ""
  if arg == "bg" or arg == "background" then
    if SkyInfoTiles and SkyInfoTiles.DebugKeystoneBackground then
      SkyInfoTiles.DebugKeystoneBackground()
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r Debug function not found.")
    end
  else
    if SkyInfoTiles and SkyInfoTiles.DebugKeystoneTeleport then
      SkyInfoTiles.DebugKeystoneTeleport()
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r Debug function not found.")
    end
  end
end


SkyInfoTiles.RegisterTileType("keystone", API)
