-- SkyInfoTiles - Dungeon Teleports tile (row of icons; hover shows name/cooldown; left-click casts teleport)
local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local Utils = SkyInfoTiles.Utils  -- Shared string normalization utilities

local API = {}

-- Forward declarations (used by closures in API.create)
local ToNumberSafe
local GetSpellCooldownSafe
local GetSpellIDFromName

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

-- Dungeons are discovered dynamically from the client (current Mythic+ season)
-- Prefer: C_MythicPlus.GetSeasonMaps(C_MythicPlus.GetCurrentSeason())
-- Fallback: C_ChallengeMode.GetMapTable()
-- This avoids hardcoding dungeon lists per season.

-- Override pool (used when client APIs still point at an older season).
-- Source: Keystone Hero teleport rewards (Midnight Season 1).
-- Verified spell IDs for all 8 dungeons.
local MIDNIGHT_S1_DUNGEONS = {
  { name = "Maisara Caverns",          spellName = "Teleport: Maisara Caverns",          spellID = 1283521 },
  { name = "Magisters' Terrace",       spellName = "Teleport: Magisters' Terrace",       spellID = 1283728 },
  { name = "Nexus-Point Xenas",        spellName = "Teleport: Nexus-Point Xenas",        spellID = 1284540 },
  { name = "Windrunner Spire",         spellName = "Teleport: Windrunner Spire",         spellID = 1290753 },
  { name = "Algeth'ar Academy",        spellName = "Teleport: Algeth'ar Academy",        spellID = 393222 },
  { name = "Seat of the Triumvirate",  spellName = "Teleport: Seat of the Triumvirate",  spellID = 445418 },
  { name = "Skyreach",                 spellName = "Teleport: Skyreach",                 spellID = 159901 },
  { name = "Pit of Saron",             spellName = "Teleport: Pit of Saron",             spellID = 464239 },
}

-- ======================== Help: print commands (easy copy) ========================
SLASH_SKYPORTSHELP1 = "/skyportshelp"
SlashCmdList["SKYPORTSHELP"] = function()
  if not DEFAULT_CHAT_FRAME then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r === SkyInfoTiles dungeon ports debug commands ===")
  DEFAULT_CHAT_FRAME:AddMessage("/skyportsdebug   - print current port entries + resolved spellIDs")
  DEFAULT_CHAT_FRAME:AddMessage("/skyportssearch <text> - scan spell names in likely ranges (substring match)")
  DEFAULT_CHAT_FRAME:AddMessage("/skyportsdesc <text>   - scan spell descriptions in likely ranges (substring match)")
  DEFAULT_CHAT_FRAME:AddMessage("/skyportsfind    - try to auto-match missing IDs (name-based; may not work)")
  DEFAULT_CHAT_FRAME:AddMessage("Examples:")
  DEFAULT_CHAT_FRAME:AddMessage("  /skyportssearch path of")
  DEFAULT_CHAT_FRAME:AddMessage("  /skyportsdesc skyreach")
  DEFAULT_CHAT_FRAME:AddMessage("  /skyportsdesc triumvirate")
end


-- ======================== Teleport resolving (shared logic w/ Keystone tile) ========================
-- Use shared normalization functions from SkyInfoTiles.Utils
local NormKey = Utils.NormKey
local Norm = Utils.Norm
local TokensFromName = Utils.TokensFromName

-- Spell info cache (session-level to avoid repeated C_Spell.GetSpellInfo calls)
local _spellInfoCache = {}
local function GetSpellInfoCached(spellID)
  if not spellID then return nil end
  if _spellInfoCache[spellID] then
    return _spellInfoCache[spellID]
  end

  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
  if info then
    _spellInfoCache[spellID] = info
  end
  return info
end

local function EnsureDB()
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.teleportMap = SkyInfoTilesDB.teleportMap or {}
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
        local si = GetSpellInfoCached(spellID)
        local nm = si and si.name or nil
        if type(nm) == "string" and nm ~= "" then
          local desc = (C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID))
                    or (GetSpellDescription and GetSpellDescription(spellID))
                    or (si and si.description)
                    or ""
          teleportCache[#teleportCache + 1] = {
            id       = spellID,
            rawName  = nm,
            nameNorm = Norm(nm),
            descNorm = Norm(desc),
          }
        end
      end
    end
  end
end

local function ResolveTeleportForDungeon(dungeonName)
  if not dungeonName or dungeonName == "" then return nil, nil end

  -- 0) DB map
  local db = LoadTeleportMap(dungeonName)
  if db then
    if db.id and (IsPlayerSpell and IsPlayerSpell(db.id) or IsSpellKnown and IsSpellKnown(db.id)) then
      local si = GetSpellInfoCached(db.id)
      return db.id, (si and si.name) or db.name
    end
    if db.name then
      local si = GetSpellInfoCached(db.name)
      if si and si.spellID and (IsPlayerSpell(si.spellID) or IsSpellKnown(si.spellID)) then
        return si.spellID, si.name
      end
    end
  end

  -- 1) Build cache and tokens
  if not teleportCache then BuildTeleportCache() end
  if not teleportCache or #teleportCache == 0 then return nil, nil end

  local tokens = TokensFromName(dungeonName) or {}

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

  return nil, nil
end

local function GetSeasonDungeons()
  local out = {}

  -- Only the current season is interesting: use the Midnight S1 list.
  -- (Client APIs can lag and still point at older seasons.)
  for _, rec in ipairs(MIDNIGHT_S1_DUNGEONS) do
    local spellID = rec.spellID
    local spellName = rec.spellName

    -- Resolve by name if missing *or* if the provided ID doesn't match the name.
    if spellName then
      local fromName = GetSpellIDFromName(spellName)
      if (not spellID) or (fromName and spellID and fromName ~= spellID) then
        spellID = fromName or spellID
      end
    end

    out[#out + 1] = {
      key = NormKey(rec.name),
      name = rec.name,
      mapID = nil,
      mapIcon = nil,
      spellID = spellID,
      spellName = spellName,
    }
  end
  return out
end

-- ======================== Debug: print resolved spellIDs ========================
-- This helps verify/collect correct portal IDs without relying on external sources.
function SkyInfoTiles.DebugDungeonPortIDs()
  if not DEFAULT_CHAT_FRAME then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r === DungeonPorts IDs (Midnight S1) ===")
  for _, rec in ipairs(MIDNIGHT_S1_DUNGEONS or {}) do
    local sid = rec.spellID
    local sidFromName = rec.spellName and GetSpellIDFromName(rec.spellName) or nil
    if sidFromName and sid and sidFromName ~= sid then
      DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff5555%s|r  spellName='%s'  providedID=%s  resolvedID=%s (mismatch)", tostring(rec.name), tostring(rec.spellName), tostring(sid), tostring(sidFromName)))
    else
      DEFAULT_CHAT_FRAME:AddMessage(string.format("%s  spellName='%s'  spellID=%s", tostring(rec.name), tostring(rec.spellName), tostring(sidFromName or sid)))
    end
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r Tip: copy the spellID values for any entries missing IDs.")
end

SLASH_SKYPORTSDEBUG1 = "/skyportsdebug"
SlashCmdList["SKYPORTSDEBUG"] = function()
  if SkyInfoTiles and SkyInfoTiles.DebugDungeonPortIDs then
    SkyInfoTiles.DebugDungeonPortIDs()
  end
end

-- ======================== Debug: brute-force find spellIDs by scanning ranges ========================
-- Why: C_Spell.GetSpellInfo(<spellName>) may return nil when the spell data isn't loaded.
-- But C_Spell.GetSpellInfo(<spellID>) can still return the localized name.
-- We scan a couple of likely ranges and match by name tokens.
local _portsFindTicker = nil

local function SpellNameMatchesTarget(foundName, targetName)
  if type(foundName) ~= "string" or foundName == "" or type(targetName) ~= "string" or targetName == "" then
    return false
  end
  if foundName == targetName then return true end
  local fn = Norm(foundName)
  local tn = Norm(targetName)
  if fn == tn then return true end
  local tokens = TokensFromName(targetName) or {}
  for _, tk in ipairs(tokens) do
    if not fn:find(tk, 1, true) then return false end
  end
  return true
end

function SkyInfoTiles.FindDungeonPortSpellIDs()
  if not (C_Spell and C_Spell.GetSpellInfo and C_Timer and C_Timer.NewTicker) then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportsfind unavailable (missing C_Spell/C_Timer APIs).")
    end
    return
  end

  if _portsFindTicker then
    _portsFindTicker:Cancel()
    _portsFindTicker = nil
  end

  -- Targets: entries with a spellName but missing spellID.
  local targets = {}
  for _, rec in ipairs(MIDNIGHT_S1_DUNGEONS or {}) do
    if rec and rec.spellName and not rec.spellID then
      targets[#targets + 1] = rec
    end
  end

  if #targets == 0 then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportsfind: nothing to find (all entries already have spellID).")
    end
    return
  end

  local ranges = {
    { from = 444000,  to = 446500 },   -- older Path/Teleport spells (observed ~445xxx)
    { from = 1240000, to = 1265000 },  -- newer spells (observed Pit of Saron ~1254xxx)
  }

  local rIdx = 1
  local cur = ranges[rIdx].from
  local foundCount = 0
  local total = #targets
  local batchSize = 250

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportsfind: scanning for missing Keystone Hero spellIDs...")
  end

  _portsFindTicker = C_Timer.NewTicker(0.01, function()
    local steps = 0
    while steps < batchSize do
      -- Advance range if needed
      local rr = ranges[rIdx]
      if not rr then
        if _portsFindTicker then _portsFindTicker:Cancel(); _portsFindTicker = nil end
        if DEFAULT_CHAT_FRAME then
          DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportsfind: done.")
          for _, rec in ipairs(targets) do
            if not rec.spellID then
              DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff5555NOT FOUND|r: %s (spellName='%s')", tostring(rec.name), tostring(rec.spellName)))
            end
          end
        end
        return
      end

      if cur > rr.to then
        rIdx = rIdx + 1
        if ranges[rIdx] then
          cur = ranges[rIdx].from
        end
        break
      end

      local si = GetSpellInfoCached(cur)
      local nm = si and si.name or nil
      if nm then
        for _, rec in ipairs(targets) do
          if rec and (not rec.spellID) and SpellNameMatchesTarget(nm, rec.spellName) then
            rec.spellID = cur
            rec._resolvedSpellID = nil
            foundCount = foundCount + 1
            if DEFAULT_CHAT_FRAME then
              DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffFOUND|r: %s  spellID=%d  (spellName='%s')", tostring(rec.name), cur, tostring(rec.spellName)))
            end
          end
        end
        if foundCount >= total then
          if _portsFindTicker then _portsFindTicker:Cancel(); _portsFindTicker = nil end
          if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportsfind: all missing IDs found.")
          end
          return
        end
      end

      cur = cur + 1
      steps = steps + 1
    end
  end)
end

SLASH_SKYPORTSFIND1 = "/skyportsfind"
SlashCmdList["SKYPORTSFIND"] = function()
  if SkyInfoTiles and SkyInfoTiles.FindDungeonPortSpellIDs then
    SkyInfoTiles.FindDungeonPortSpellIDs()
  end
end

-- ======================== Debug: search spellID ranges by substring ========================
-- Usage: /skyportssearch <text>
-- Example: /skyportssearch skyreach
-- Prints any spellIDs in our scan ranges whose spell name contains the substring.
local _portsSearchTicker = nil
local _portsSearchActiveQuery = nil
function SkyInfoTiles.SearchSpellIDsByNameSubstring(query)
  query = (query or "")
  query = query:gsub("^%s+", ""):gsub("%s+$", "")
  if query == "" then
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r Usage: /skyportssearch <text>") end
    return
  end
  query = Norm(query)

  if not (C_Spell and C_Spell.GetSpellInfo and C_Timer and C_Timer.NewTicker) then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportssearch unavailable (missing C_Spell/C_Timer APIs).")
    end
    return
  end

  if _portsSearchTicker then
    if _portsSearchActiveQuery == query then
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r /skyportssearch '%s' is already running. Please wait...", query))
      end
      return
    end
    _portsSearchTicker:Cancel(); _portsSearchTicker = nil
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportssearch: cancelled previous scan (new query).")
    end
  end

  _portsSearchActiveQuery = query

  local ranges = {
    { from = 444000,  to = 446500 },
    { from = 1240000, to = 1265000 },
  }
  local rIdx = 1
  local cur = ranges[rIdx].from
  local batchSize = 800
  local hits = 0
  local maxHits = 50

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r /skyportssearch: scanning for '%s'...", query))
  end

  _portsSearchTicker = C_Timer.NewTicker(0, function()
    local steps = 0
    while steps < batchSize do
      local rr = ranges[rIdx]
      if not rr then
        if _portsSearchTicker then _portsSearchTicker:Cancel(); _portsSearchTicker = nil end
        _portsSearchActiveQuery = nil
        if DEFAULT_CHAT_FRAME then
          DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r /skyportssearch done. hits=%d", hits))
        end
        return
      end

      if cur > rr.to then
        rIdx = rIdx + 1
        if ranges[rIdx] then cur = ranges[rIdx].from end
        break
      end

      local si = GetSpellInfoCached(cur)
      local nm = si and si.name or nil
      if nm then
        local nn = Norm(nm)
        if nn:find(query, 1, true) then
          hits = hits + 1
          if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("HIT: spellID=%d  name='%s'", cur, nm))
          end
          if hits >= maxHits then
            if _portsSearchTicker then _portsSearchTicker:Cancel(); _portsSearchTicker = nil end
            _portsSearchActiveQuery = nil
            if DEFAULT_CHAT_FRAME then
              DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r /skyportssearch: stopped at %d hits (max). Refine query.", hits))
            end
            return
          end
        end
      end

      cur = cur + 1
      steps = steps + 1
    end
  end)
end

SLASH_SKYPORTSSEARCH1 = "/skyportssearch"
SlashCmdList["SKYPORTSSEARCH"] = function(msg)
  if SkyInfoTiles and SkyInfoTiles.SearchSpellIDsByNameSubstring then
    SkyInfoTiles.SearchSpellIDsByNameSubstring(msg)
  end
end

-- ======================== Debug: search spellID ranges by DESCRIPTION substring ========================
-- Usage: /skyportsdesc <text>
-- Example: /skyportsdesc skyreach
-- This tends to work better for dungeon teleports where the spell name is generic (e.g. "Path of ...")
-- but the description mentions the destination dungeon.
local _portsDescTicker = nil
local _portsDescActiveQuery = nil
function SkyInfoTiles.SearchSpellIDsByDescriptionSubstring(query)
  query = (query or "")
  query = query:gsub("^%s+", ""):gsub("%s+$", "")
  if query == "" then
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r Usage: /skyportsdesc <text>") end
    return
  end
  query = Norm(query)

  if not (C_Spell and C_Spell.GetSpellInfo and C_Timer and C_Timer.NewTicker) then
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportsdesc unavailable (missing C_Spell/C_Timer APIs).")
    end
    return
  end

  if _portsDescTicker then
    if _portsDescActiveQuery == query then
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r /skyportsdesc '%s' is already running. Please wait...", query))
      end
      return
    end
    _portsDescTicker:Cancel(); _portsDescTicker = nil
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r /skyportsdesc: cancelled previous scan (new query).")
    end
  end
  _portsDescActiveQuery = query

  local ranges = {
    { from = 444000,  to = 446500 },
    { from = 1240000, to = 1265000 },
  }
  local rIdx = 1
  local cur = ranges[rIdx].from
  local batchSize = 300
  local hits = 0
  local maxHits = 30

  local function GetDesc(id)
    local desc = nil
    if C_Spell and C_Spell.GetSpellDescription then
      local ok, d = pcall(C_Spell.GetSpellDescription, id)
      if ok then desc = d end
    end
    if (not desc or desc == "") and GetSpellDescription then
      local ok, d = pcall(GetSpellDescription, id)
      if ok then desc = d end
    end
    return desc
  end

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r /skyportsdesc: scanning descriptions for '%s'...", query))
  end

  _portsDescTicker = C_Timer.NewTicker(0, function()
    local steps = 0
    while steps < batchSize do
      local rr = ranges[rIdx]
      if not rr then
        if _portsDescTicker then _portsDescTicker:Cancel(); _portsDescTicker = nil end
        _portsDescActiveQuery = nil
        if DEFAULT_CHAT_FRAME then
          DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r /skyportsdesc done. hits=%d", hits))
        end
        return
      end

      if cur > rr.to then
        rIdx = rIdx + 1
        if ranges[rIdx] then cur = ranges[rIdx].from end
        break
      end

      local si = GetSpellInfoCached(cur)
      local nm = si and si.name or nil
      if nm then
        local desc = GetDesc(cur)
        if desc and desc ~= "" then
          local dn = Norm(desc)
          if dn:find(query, 1, true) then
            hits = hits + 1
            local oneLine = desc:gsub("\r", " "):gsub("\n", " "):gsub("%s+", " ")
            if #oneLine > 120 then oneLine = oneLine:sub(1, 120) .. "..." end
            if DEFAULT_CHAT_FRAME then
              DEFAULT_CHAT_FRAME:AddMessage(string.format("DESC HIT: spellID=%d  name='%s'  desc='%s'", cur, nm, oneLine))
            end
            if hits >= maxHits then
              if _portsDescTicker then _portsDescTicker:Cancel(); _portsDescTicker = nil end
              _portsDescActiveQuery = nil
              if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r /skyportsdesc: stopped at %d hits (max). Refine query.", hits))
              end
              return
            end
          end
        end
      end

      cur = cur + 1
      steps = steps + 1
    end
  end)
end

SLASH_SKYPORTSDESC1 = "/skyportsdesc"
SlashCmdList["SKYPORTSDESC"] = function(msg)
  if SkyInfoTiles and SkyInfoTiles.SearchSpellIDsByDescriptionSubstring then
    SkyInfoTiles.SearchSpellIDsByDescriptionSubstring(msg)
  end
end

-- Utils

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
  -- Use cached spell info lookup
  local si = GetSpellInfoCached(id)
  if si and si.name then
    return si.name
  end
  -- Fallback to legacy API
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
  if d._resolvedSpellID ~= nil then
    return (d._resolvedSpellID ~= false) and d._resolvedSpellID or nil
  end

  -- 0) Prefer dynamic resolve from spellbook by dungeon name.
  -- This is robust even if our hardcoded spellName strings drift/are wrong.
  if d.name then
    local rid, rname = ResolveTeleportForDungeon(d.name)
    if rid then
      d._resolvedSpellID = rid
      d._resolvedSpellName = rname or false
      return rid
    end
  end

  -- Prefer resolving by name when available (more likely to be correct if an ID was guessed/incorrect).
  local sidFromName = nil
  if d.spellName then
    sidFromName = GetSpellIDFromName(d.spellName)
  end

  -- If both exist but disagree, prefer the ID resolved from name.
  if d.spellID and sidFromName and d.spellID ~= sidFromName then
    d._resolvedSpellID = sidFromName
    return sidFromName
  end

  -- Otherwise, keep provided ID if present.
  if d.spellID then
    d._resolvedSpellID = d.spellID
    return d.spellID
  end

  d._resolvedSpellID = sidFromName or false
  return sidFromName
end

-- Helpers for known/availability
GetSpellIDFromName = function(name)
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

local function RebuildCells(frame, cfg)
  if not frame then return end
  if InCombatLockdown and InCombatLockdown() then
    frame._pendingRebuild = true
    return
  end

  -- destroy existing cells
  for _, cell in ipairs(frame.cells or {}) do
    if cell.button then
      if cell.button.UnregisterAllEvents then cell.button:UnregisterAllEvents() end
      if cell.button.SetScript then
        cell.button:SetScript("OnEnter", nil)
        cell.button:SetScript("OnLeave", nil)
      end
      if cell.button.Hide then cell.button:Hide() end
      if cell.button.SetParent then cell.button:SetParent(nil) end
      cell.button = nil
    end
    if cell.cooldown then
      if cell.cooldown.Hide then cell.cooldown:Hide() end
      if cell.cooldown.SetParent then cell.cooldown:SetParent(nil) end
      cell.cooldown = nil
    end
    if cell.border then
      if cell.border.Hide then cell.border:Hide() end
      if cell.border.SetParent then cell.border:SetParent(nil) end
      cell.border = nil
    end
    if cell.icon then
      if cell.icon.SetTexture then cell.icon:SetTexture(nil) end
      if cell.icon.Hide then cell.icon:Hide() end
      if cell.icon.SetParent then cell.icon:SetParent(nil) end
      cell.icon = nil
    end
  end
  frame.cells = {}

  -- rebuild dungeon list
  frame._dungeons = GetSeasonDungeons()

  local vertical = (cfg and cfg.orientation == "vertical")
  for i, d in ipairs(frame._dungeons) do
    local cell = { index = i }
    local offX = vertical and PAD_X or (PAD_X + (i - 1) * (ICON_SIZE + GAP_X))
    local offY = vertical and (-PAD_Y - (i - 1) * (ICON_SIZE + GAP_X)) or (-PAD_Y)
    cell.offX, cell.offY = offX, offY

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", offX, offY)
    -- Prioritize spell texture (from verified spellID) for accurate dungeon icons
    local spellTex = GetSpellTextureSafe(d.spellID or d.spellName)
    local mapIcon = d.mapIcon or TryGetMapIcon(d.mapID)
    icon:SetTexture(spellTex or mapIcon or (GetItemIcon and GetItemIcon(180653)) or 525134)
    cell.icon = icon

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT",     icon, -BORDER_PX,  BORDER_PX)
    border:SetPoint("BOTTOMRIGHT", icon,  BORDER_PX, -BORDER_PX)
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = BORDER_PX })
    border:SetBackdropBorderColor(0, 0, 0, 0.95)
    border:EnableMouse(false)
    cell.border = border

    local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    if cd.SetFrameStrata then cd:SetFrameStrata("HIGH") end
    if cd.SetFrameLevel then cd:SetFrameLevel((frame:GetFrameLevel() or 0) + 50) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
    if cd.SetUseCircularEdge then cd:SetUseCircularEdge(true) end
    if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.75) end
    if cd.SetReverse then cd:SetReverse(false) end
    if cd.EnableMouse then cd:EnableMouse(false) end
    if cd.SetMouseMotionEnabled then cd:SetMouseMotionEnabled(false) end
    cd:Hide()
    cell.cooldown = cd

    local btn = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", offX, offY)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetFrameStrata("HIGH")
    btn:SetToplevel(true)
    btn:SetFrameLevel((frame:GetFrameLevel() or 0) + 100)
    btn._dungeonIndex = i
    btn:SetScript("OnEnter", function(self)
      if not GameTooltip then return end
      local dd = frame._dungeons and frame._dungeons[self._dungeonIndex]
      if not dd then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(dd.name, 1, 0.82, 0)
      local known = IsTeleportKnown(dd)
      if known then
        GameTooltip:AddLine("Left-click: Teleport", 0, 1, 0)
        local sid = dd.spellID or dd.spellName
        local start, dur = GetSpellCooldownSafe(sid)
        start = ToNumberSafe(start) or 0
        dur   = ToNumberSafe(dur) or 0
        if dur and dur > 1.5 and start and start > 0 then
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

    frame.cells[i] = cell
  end

  -- size to content
  if vertical then
    frame:SetSize(ICON_SIZE + 2 * PAD_X, PAD_Y + (ICON_SIZE + GAP_X) * #(frame._dungeons or {}) - GAP_X + PAD_Y)
  else
    frame:SetSize(PAD_X + (ICON_SIZE + GAP_X) * #(frame._dungeons or {}) - GAP_X + PAD_X, ICON_SIZE + 2 * PAD_Y)
  end
end

-- Frame builder
function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(600, ICON_SIZE + 2*PAD_Y)

  f._dungeons = GetSeasonDungeons()

  -- Data per dungeon: build icon textures, borders, cooldown + secure buttons
  f.cells = {}
  local vertical = (cfg and cfg.orientation == "vertical")
  for i, d in ipairs(f._dungeons) do
    local cell = { index = i }

    -- Icon texture
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    local offX = vertical and PAD_X or (PAD_X + (i-1) * (ICON_SIZE + GAP_X))
    local offY = vertical and (-PAD_Y - (i-1) * (ICON_SIZE + GAP_X)) or (-PAD_Y)
    cell.offX, cell.offY = offX, offY
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", offX, offY)
    -- Prioritize spell texture (from verified spellID) for accurate dungeon icons
    local spellTex = GetSpellTextureSafe(d.spellID or d.spellName)
    local mapIcon = d.mapIcon or TryGetMapIcon(d.mapID)
    icon:SetTexture(spellTex or mapIcon or (GetItemIcon and GetItemIcon(180653)) or 525134)
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
      btn:SetFrameStrata("HIGH")
      btn:SetToplevel(true)
      btn:SetFrameLevel((f:GetFrameLevel() or 0) + 100)
      btn._dungeonIndex = i
      btn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local dd = f._dungeons and f._dungeons[self._dungeonIndex]
        if not dd then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(dd.name, 1, 0.82, 0)
        local known = IsTeleportKnown(dd)
        if known then
          GameTooltip:AddLine("Left-click: Teleport", 0, 1, 0)
          local sid = dd.spellID or dd.spellName
          local start, dur = GetSpellCooldownSafe(sid)
          start = ToNumberSafe(start) or 0
          dur   = ToNumberSafe(dur) or 0
          if dur and dur > 1.5 and start and start > 0 then
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
    f:SetSize(ICON_SIZE + 2*PAD_X, PAD_Y + (ICON_SIZE + GAP_X) * #(f._dungeons or {}) - GAP_X + PAD_Y)
  else
    f:SetSize(PAD_X + (ICON_SIZE + GAP_X) * #(f._dungeons or {}) - GAP_X + PAD_X, ICON_SIZE + 2*PAD_Y)
  end

  -- Events
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
  f:RegisterEvent("SPELLS_CHANGED")
  f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

  -- Throttle update calls (SPELL_UPDATE_COOLDOWN can spam)
  f._updateThrottle = 0
  local function ThrottledUpdate()
    local now = GetTime and GetTime() or 0
    if (now - f._updateThrottle) < 0.1 then return end  -- Max 10 updates/sec
    f._updateThrottle = now
    API.update(f, cfg)
  end

  -- Throttle cache rebuild
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
      teleportCache = nil
      f._cacheRebuildPending = false
    end
  end

  f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
      if self._pendingRebuild then
        self._pendingRebuild = nil
        RebuildCells(self, cfg)
      end
      -- Apply any pending scale changes now that we're out of combat
      if self._pendingScale and self.SetScale then
        local sc = self._pendingScale
        self._pendingScale = nil
        if self._appliedScale ~= sc then
          self:SetScale(sc)
          self._appliedScale = sc
        end
      end
      -- Create any pending secure buttons
      for i, cell in ipairs(self.cells or {}) do
        if cell._pendingCreate and not cell.button then
          cell._pendingCreate = nil
          local btn = CreateFrame("Button", nil, self, "SecureActionButtonTemplate")
          btn:SetPoint("TOPLEFT", self, "TOPLEFT", cell.offX or PAD_X, cell.offY or -PAD_Y)
          btn:SetSize(ICON_SIZE, ICON_SIZE)
          btn:RegisterForClicks("AnyDown", "AnyUp")
          btn:SetFrameStrata("HIGH")
          btn:SetToplevel(true)
          btn:SetFrameLevel((self:GetFrameLevel() or 0) + 100)
          btn._dungeonIndex = i
          btn:SetScript("OnEnter", function(b)
            if not GameTooltip then return end
            local dd = self._dungeons and self._dungeons[b._dungeonIndex]
            if not dd then return end
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:AddLine(dd.name, 1, 0.82, 0)
            local known = IsTeleportKnown(dd)
            if known then
              GameTooltip:AddLine("Left-click: Teleport", 0, 1, 0)
            else
              GameTooltip:AddLine("Teleport unavailable.", 1, 0.3, 0.3)
            end
            GameTooltip:Show()
          end)
          btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
          cell.button = btn
        end
      end
    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
      RebuildCells(self, cfg)
      API.update(self, cfg)  -- Important: rebuild means immediate update
      return
    elseif event == "SPELLS_CHANGED" then
      ScheduleCacheRebuild()
    end

    -- Throttle updates for spammy events (SPELL_UPDATE_COOLDOWN, UNIT_SPELLCAST_SUCCEEDED)
    if event == "SPELL_UPDATE_COOLDOWN" or event == "UNIT_SPELLCAST_SUCCEEDED" then
      ThrottledUpdate()
    else
      -- Important events: update immediately
      API.update(self, cfg)
    end
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

  function f:Destroy()
    -- Avoid destroying during combat; core defers rebuilds in lockdown.
    if InCombatLockdown and InCombatLockdown() then return end

    -- Stop reacting to events and scripts
    if self.UnregisterAllEvents then self:UnregisterAllEvents() end
    if self.SetScript then
      self:SetScript("OnEvent", nil)
      self:SetScript("OnShow", nil)
      self:SetScript("OnMouseDown", nil)
      self:SetScript("OnMouseUp", nil)
    end

    -- Clean up child widgets to ensure no stray frames keep updating
    for _, cell in ipairs(self.cells or {}) do
      if cell.button then
        if cell.button.UnregisterAllEvents then cell.button:UnregisterAllEvents() end
        if cell.button.SetScript then
          cell.button:SetScript("OnEnter", nil)
          cell.button:SetScript("OnLeave", nil)
        end
        if cell.button.Hide then cell.button:Hide() end
        if cell.button.SetParent then cell.button:SetParent(nil) end
        cell.button = nil
      end
      if cell.cooldown then
        if cell.cooldown.Hide then cell.cooldown:Hide() end
        if cell.cooldown.SetParent then cell.cooldown:SetParent(nil) end
        cell.cooldown = nil
      end
      if cell.border then
        if cell.border.Hide then cell.border:Hide() end
        if cell.border.SetParent then cell.border:SetParent(nil) end
        cell.border = nil
      end
      if cell.icon then
        if cell.icon.SetTexture then cell.icon:SetTexture(nil) end
        if cell.icon.Hide then cell.icon:Hide() end
        if cell.icon.SetParent then cell.icon:SetParent(nil) end
        cell.icon = nil
      end
    end

    self.cells = nil
    if self.Hide then self:Hide() end
    if self.SetParent then self:SetParent(nil) end
  end
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
    local resolvedName = (d._resolvedSpellName ~= false and d._resolvedSpellName) or nil
    btn._teleName = resolvedName or d.spellName or GetTeleportNameFromID(d.spellID) or tostring(spellKey)
  else
    btn:SetAttribute("type", nil)
    btn:SetAttribute("type1", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("spell1", nil)
    btn._teleName = nil
  end
end

-- Cooldown helpers
-- Some modern WoW APIs may return protected/"secret" values for cooldown fields.
-- Any arithmetic/comparisons on those values can throw (e.g. "attempt to compare ... (a secret value)").
-- Always coerce to plain Lua numbers via protected calls.
ToNumberSafe = function(v)
  if v == nil then return nil end
  
  -- Even if `type(v) == "number"`, Retail may hand us a protected/secret number which
  -- throws on comparisons/arithmetic. So we *never* trust raw numbers here.
  local ok, n = pcall(function() return tonumber(v) end)
  if ok and type(n) == "number" then
    -- Force a real Lua number via a trivial arithmetic op (wrapped in pcall).
    local ok2, m = pcall(function() return n + 0 end)
    if ok2 and type(m) == "number" then
      return m
    end
  end

  -- Last resort: tostring -> tonumber (some protected values stringify safely)
  local ok3, s = pcall(function() return tostring(v) end)
  if ok3 and type(s) == "string" then
    local n2 = tonumber(s)
    if type(n2) == "number" then return n2 end
  end
  return nil
end

GetSpellCooldownSafe = function(spellIDOrName)
  local start, dur, enable

  -- Retail note (11.x): legacy GetSpellCooldown may now return a single table (SpellCooldownInfo)
  -- instead of 3 values. That table can also contain "secret values" for fields like isEnabled.
  -- We avoid *any* boolean test on isEnabled and only use it if it's trivially numeric.
  if type(GetSpellCooldown) == "function" then
    local ok, a, b, c = pcall(GetSpellCooldown, spellIDOrName)
    if ok then
      if type(a) == "table" then
        start = ToNumberSafe(a.startTime or a.start)
        dur   = ToNumberSafe(a.duration)
        -- Don't read/branch on a.isEnabled (may be a secret value). Default enabled.
        enable = 1
      else
        start = ToNumberSafe(a)
        dur   = ToNumberSafe(b)
        enable = ToNumberSafe(c)
      end
    end
  end

  -- Fallback to C_Spell API if available and legacy API returned no usable duration
  if (not dur or dur == 0) and C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
    local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, spellIDOrName)
    if ok and type(cdInfo) == "table" then
      start = ToNumberSafe(cdInfo.startTime)
      dur   = ToNumberSafe(cdInfo.duration)
      -- Never boolean-test cdInfo.isEnabled (can be a secret value). Default enabled.
      if enable == nil then enable = 1 end
    end
  end

  return start or 0, dur or 0, enable or 1
end

local function UpdateCooldown(cell, d)
  if not cell or not cell.cooldown then return end
  local sid = ResolveSpellKey(d) or d.spellName
  if not sid then cell.cooldown:Hide(); return end

  local start, dur, enable = GetSpellCooldownSafe(sid)

  -- Defensive: ensure values are *definitely* plain Lua numbers before comparing/arithmetic.
  start = ToNumberSafe(start) or 0
  dur   = ToNumberSafe(dur) or 0
  enable = ToNumberSafe(enable) or 1

  if dur and dur > 1.5 and start and start > 0 then
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

  -- Apply per-tile scale (0.5 - 2.0), consistent with /skytiles scale support
  local sc = (cfg and tonumber(cfg.scale)) or 1
  if sc < 0.5 then sc = 0.5 elseif sc > 2.0 then sc = 2.0 end
  if frame.SetScale then
    if InCombatLockdown and InCombatLockdown() then
      frame._pendingScale = sc
    else
      if frame._appliedScale ~= sc then
        frame:SetScale(sc)
        frame._appliedScale = sc
        frame._pendingScale = nil
      end
    end
  end

  for i, cell in ipairs(frame.cells or {}) do
    local d = frame._dungeons and frame._dungeons[i]
    if not d then break end
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
