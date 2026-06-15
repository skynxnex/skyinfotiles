local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]

local API = {}

-- Defaults
local DEFAULT_FONT = "Fonts\\FRIZQT__.ttf"
local DEFAULT_SIZE = 14
local DEFAULT_OUTLINE = "OUTLINE"
local DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_BG_COLOR = { r = 0, g = 0, b = 0, a = 0.7 }
local DEFAULT_BORDER_COLOR = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
local PAD_X = 8
local PAD_Y = 6
local SECTION_SPACING = 8  -- Space between sections

local function ReadCfg(cfg)
  cfg = cfg or {}
  local fontFile = (type(cfg.font) == "string" and cfg.font ~= "" and cfg.font) or DEFAULT_FONT
  local size = math.max(6, math.min(128, tonumber(cfg.size) or tonumber(cfg.fontSize) or DEFAULT_SIZE))
  local outline = cfg.outline
  if outline == nil then outline = DEFAULT_OUTLINE end
  if outline == "NONE" then outline = "" end
  local color = cfg.color or DEFAULT_COLOR
  local bgColor = cfg.bgColor or DEFAULT_BG_COLOR
  local borderColor = cfg.borderColor or DEFAULT_BORDER_COLOR
  return fontFile, size, outline, color, bgColor, borderColor
end

local function SetFontSmart(fs, file, size, flags)
  local tries = {}
  if type(file) == "string" and file ~= "" then
    table.insert(tries, file)
    local lowerExt = file:gsub("%.TTF$", ".ttf"):gsub("%.Ttf$", ".ttf")
    if lowerExt ~= file then table.insert(tries, lowerExt) end
    local upperExt = file:gsub("%.ttf$", ".TTF")
    if upperExt ~= file then table.insert(tries, upperExt) end
  end
  table.insert(tries, DEFAULT_FONT)
  if STANDARD_TEXT_FONT then table.insert(tries, STANDARD_TEXT_FONT) end
  table.insert(tries, "Fonts\\FRIZQT__.ttf")
  table.insert(tries, "Fonts\\ARIALN.ttf")

  for _, path in ipairs(tries) do
    if fs:SetFont(path, size or DEFAULT_SIZE, flags or "") then
      return true, path
    end
  end
  return false, nil
end

local function ApplyTextStyle(fs, fontFile, size, outline, color)
  if not fs then return end
  SetFontSmart(fs, fontFile or DEFAULT_FONT, size or DEFAULT_SIZE, outline or "")
  if fs.SetTextColor and color then
    fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1, (color.a ~= nil) and color.a or 1)
  end
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
end

-- Get guild online info
local function GetGuildOnlineInfo()
  if not IsInGuild() then
    return nil, 0, 0
  end

  local totalMembers = GetNumGuildMembers()
  local onlineCount = 0
  local members = {}

  for i = 1, totalMembers do
    local name, rank, _, level, class, zone, _, _, online, status, classFileName = GetGuildRosterInfo(i)
    if online and name then
      onlineCount = onlineCount + 1
      table.insert(members, {
        name = name,
        level = level,
        class = classFileName or class,
        zone = zone or "",
        status = status or 0,
        rank = rank or ""
      })
    end
  end

  table.sort(members, function(a, b)
    if a.level ~= b.level then
      return a.level > b.level
    end
    return a.name < b.name
  end)

  return members, onlineCount, totalMembers
end

-- Convert localized class name to class token
local classTokenCache = {}
local function GetClassToken(localizedClassName)
  if not localizedClassName then return nil end

  if classTokenCache[localizedClassName] then
    return classTokenCache[localizedClassName]
  end

  if not next(classTokenCache) then
    for i = 1, GetNumClasses() do
      local localizedName, classToken = GetClassInfo(i)
      if localizedName and classToken then
        classTokenCache[localizedName] = classToken
      end
    end
  end

  return classTokenCache[localizedClassName]
end

-- Get friends online info
local function GetFriendsOnlineInfo()
  local friends = {}
  local onlineCount = 0
  local totalFriends = 0

  if C_FriendList and C_FriendList.GetNumFriends then
    local numWoWFriends = C_FriendList.GetNumFriends() or 0
    local numWoWOnline = C_FriendList.GetNumOnlineFriends() or 0

    totalFriends = numWoWFriends
    onlineCount = numWoWOnline

    for i = 1, numWoWFriends do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      if info and info.connected then
        local classToken = GetClassToken(info.className)
        table.insert(friends, {
          name = info.name,
          level = info.level or 0,
          class = classToken,
          area = info.area or "",
          status = (info.afk and 1) or (info.dnd and 2) or 0,
          isBNet = false
        })
      end
    end
  end

  if BNGetNumFriends then
    local totalBNet = BNGetNumFriends()

    for i = 1, totalBNet do
      local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
      if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
        local gameInfo = accountInfo.gameAccountInfo

        -- Only show friends in WoW Retail (wowProjectID: 1=Mainline, 2=Classic, 11=Wrath)
        if gameInfo.clientProgram == BNET_CLIENT_WOW and gameInfo.wowProjectID == 1 then
          local characterName = gameInfo.characterName or accountInfo.accountName
          local battleTag = accountInfo.battleTag
          local displayName = characterName
          if battleTag and battleTag ~= "" then
            displayName = string.format("%s (%s)", characterName, battleTag)
          end

          local level = gameInfo.characterLevel or 0
          local className = gameInfo.className
          local classToken = GetClassToken(className)
          local zoneName = gameInfo.areaName or ""

          onlineCount = onlineCount + 1
          totalFriends = totalFriends + 1

          table.insert(friends, {
            name = displayName,
            level = level,
            class = classToken,
            area = zoneName,
            status = (accountInfo.isAFK and 1) or (accountInfo.isDND and 2) or 0,
            isBNet = true
          })
        end
      end
    end
  end

  table.sort(friends, function(a, b)
    if a.level ~= b.level then
      return a.level > b.level
    end
    return a.name < b.name
  end)

  return friends, onlineCount, totalFriends
end

-- Get player gold
local function GetPlayerGold()
  return GetMoney() or 0
end

-- Format gold with thousand separators (spaces)
local function FormatGold(copper)
  local gold = math.floor(copper / 10000)

  -- Add spaces as thousand separators
  local formatted = tostring(gold)
  local k
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
    if k == 0 then break end
  end

  return formatted
end

-- Get lowest durability percentage
local function GetLowestDurability()
  local minDur = 100
  local hasItems = false
  local lowestSlot = nil

  for slot = 1, 18 do
    local durCur, durMax = GetInventoryItemDurability(slot)
    if durCur and durMax and durMax > 0 then
      hasItems = true
      local pct = (durCur / durMax) * 100
      if pct < minDur then
        minDur = pct
        lowestSlot = slot
      end
    end
  end

  return hasItems and minDur or nil, lowestSlot
end

-- Get loot specialization info
local function GetLootSpecInfo()
  local lootSpecID = GetLootSpecialization()

  if lootSpecID == 0 then
    -- 0 means "current spec"
    local currentSpecIndex = GetSpecialization()
    if currentSpecIndex then
      local _, specName, _, icon = GetSpecializationInfo(currentSpecIndex)
      return specName, icon
    end
  else
    -- lootSpecID is a SpecID, get name and icon directly
    local _, specName, _, icon = GetSpecializationInfoByID(lootSpecID)
    return specName, icon
  end

  return nil
end

-- Create custom tooltip frame with square edges
local customTooltip = nil

local function GetCustomTooltip()
  if customTooltip then
    return customTooltip
  end

  -- Create our own tooltip frame
  customTooltip = CreateFrame("Frame", "SkyInfoBarTooltip", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  customTooltip:SetFrameStrata("TOOLTIP")
  customTooltip:Hide()

  -- Enable mouse so tooltip doesn't disappear when mouse moves over it
  customTooltip:EnableMouse(true)  -- Need to enable to receive OnEnter/OnLeave

  -- Set backdrop with square edges
  customTooltip:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true,
    tileSize = 16,
    edgeSize = 1,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  customTooltip:SetBackdropColor(0, 0, 0, 0.9)
  customTooltip:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

  -- Create font strings storage
  customTooltip.lines = {}

  -- Keep tooltip visible when mouse is over it
  customTooltip:SetScript("OnEnter", function(self)
    self:Show()
  end)

  customTooltip:SetScript("OnLeave", function(self)
    self:Hide()
  end)

  return customTooltip
end

-- Helper to setup and show custom tooltip
local function ShowCustomTooltip(owner, anchor)
  local tooltip = GetCustomTooltip()

  -- Clear old lines
  for i = 1, #tooltip.lines do
    local line = tooltip.lines[i]
    if type(line) == "table" and line.left then
      -- Double line
      line.left:Hide()
      line.right:Hide()
    elseif line.Hide then
      -- Single line (FontString)
      line:Hide()
    end
  end

  -- Set initial size so FontStrings can calculate properly
  tooltip:SetSize(200, 50)

  -- Position relative to owner
  tooltip:ClearAllPoints()
  if anchor == "ANCHOR_TOP" then
    tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 2)
  else
    tooltip:SetPoint("TOP", owner, "BOTTOM", 0, -2)
  end

  tooltip.currentLine = 0
  tooltip:Show()

  return tooltip
end

-- Helper to hide custom tooltip
local function HideCustomTooltip()
  if customTooltip then
    customTooltip:Hide()
  end
end

-- Helper to add line to custom tooltip
local function AddTooltipLine(tooltip, text, r, g, b, r2, g2, b2)
  tooltip.currentLine = tooltip.currentLine + 1
  local lineIndex = tooltip.currentLine

  -- Check if we need to create a new FontString or if it's the wrong type
  if not tooltip.lines[lineIndex] or type(tooltip.lines[lineIndex]) == "table" then
    tooltip.lines[lineIndex] = tooltip:CreateFontString(nil, "OVERLAY")
    tooltip.lines[lineIndex]:SetFont("Fonts\\FRIZQT__.ttf", 12, "OUTLINE")
    if lineIndex == 1 then
      tooltip.lines[lineIndex]:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 8, -8)
    else
      local prevLine = tooltip.lines[lineIndex - 1]
      if type(prevLine) == "table" and prevLine.left then
        tooltip.lines[lineIndex]:SetPoint("TOPLEFT", prevLine.left, "BOTTOMLEFT", 0, -2)
      else
        tooltip.lines[lineIndex]:SetPoint("TOPLEFT", prevLine, "BOTTOMLEFT", 0, -2)
      end
    end
  end

  local line = tooltip.lines[lineIndex]
  line:SetText(text)
  line:SetTextColor(r or 1, g or 1, b or 1, 1)  -- Always set alpha to 1
  line:Show()
end

-- Helper to add double line to custom tooltip
local function AddTooltipDoubleLine(tooltip, leftText, rightText, lr, lg, lb, rr, rg, rb)
  tooltip.currentLine = tooltip.currentLine + 1
  local lineIndex = tooltip.currentLine

  -- Check if we need to create new FontStrings or if it's the wrong type (single line)
  if not tooltip.lines[lineIndex] or type(tooltip.lines[lineIndex]) ~= "table" or not tooltip.lines[lineIndex].left then
    tooltip.lines[lineIndex] = {}
    tooltip.lines[lineIndex].left = tooltip:CreateFontString(nil, "OVERLAY")
    tooltip.lines[lineIndex].right = tooltip:CreateFontString(nil, "OVERLAY")

    -- Set fonts
    tooltip.lines[lineIndex].left:SetFont("Fonts\\FRIZQT__.ttf", 12, "OUTLINE")
    tooltip.lines[lineIndex].right:SetFont("Fonts\\FRIZQT__.ttf", 12, "OUTLINE")

    -- Position left side
    if lineIndex == 1 then
      tooltip.lines[lineIndex].left:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 8, -8)
    else
      local prevLine = tooltip.lines[lineIndex - 1]
      if type(prevLine) == "table" and prevLine.left then
        -- Previous was double line
        tooltip.lines[lineIndex].left:SetPoint("TOPLEFT", prevLine.left, "BOTTOMLEFT", 0, -2)
      else
        -- Previous was single line
        tooltip.lines[lineIndex].left:SetPoint("TOPLEFT", prevLine, "BOTTOMLEFT", 0, -2)
      end
    end

    -- Position right side - anchor to parent frame's right edge
    tooltip.lines[lineIndex].right:SetPoint("RIGHT", tooltip, "RIGHT", -8, 0)
    tooltip.lines[lineIndex].right:SetPoint("TOP", tooltip.lines[lineIndex].left, "TOP", 0, 0)
    tooltip.lines[lineIndex].right:SetJustifyH("RIGHT")
  end

  local line = tooltip.lines[lineIndex]
  line.left:SetText(leftText)
  line.left:SetTextColor(lr or 1, lg or 1, lb or 1, 1)  -- Always set alpha to 1
  line.left:Show()

  line.right:SetText(rightText)
  line.right:SetTextColor(rr or 1, rg or 1, rb or 1, 1)  -- Always set alpha to 1
  line.right:Show()
end

-- Helper to finalize and size custom tooltip
local function FinalizeTooltip(tooltip)
  if tooltip.currentLine == 0 then
    tooltip:Hide()
    return
  end

  local maxWidth = 0
  local totalHeight = 16  -- Top and bottom padding

  for i = 1, tooltip.currentLine do
    local line = tooltip.lines[i]
    if type(line) == "table" and line.left then
      -- Double line
      local leftWidth = line.left:GetStringWidth()
      local rightWidth = line.right:GetStringWidth()
      local lineWidth = leftWidth + rightWidth + 20  -- spacing between left and right
      if lineWidth > maxWidth then
        maxWidth = lineWidth
      end
      totalHeight = totalHeight + math.max(line.left:GetStringHeight(), 14) + 2
    elseif line and line.GetStringWidth then
      -- Single line
      local lineWidth = line:GetStringWidth()
      if lineWidth > maxWidth then
        maxWidth = lineWidth
      end
      totalHeight = totalHeight + math.max(line:GetStringHeight(), 14) + 2
    end
  end

  -- Ensure minimum size
  maxWidth = math.max(maxWidth, 100)
  totalHeight = math.max(totalHeight, 30)

  tooltip:SetSize(maxWidth + 16, totalHeight)
end

function API.create(parent, cfg)
  local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)

  -- Track previous online count for sound notification
  f._lastOnlineCount = 0

  -- Backdrop
  local showBorder = (cfg and cfg.showBorder ~= false)
  local backdropInfo = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = showBorder and "Interface\\Buttons\\WHITE8X8" or nil,
    tile = true,
    tileSize = 16,
    edgeSize = showBorder and 1 or 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  }

  if f.SetBackdrop then
    f:SetBackdrop(backdropInfo)
  end

  local fontFile, size, outline, color, bgColor, borderColor = ReadCfg(cfg)

  if f.SetBackdropColor then
    f:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
  end
  if f.SetBackdropBorderColor then
    f:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
  end

  -- Initial size
  f:SetSize(150, size + PAD_Y * 2)

  -- Enable mouse for tooltip
  f._alwaysMouse = true
  f:EnableMouse(true)

  -- Storage for sections
  f.sections = {}

  -- Helper function to create a section (text + button for hover)
  local function CreateSection(key, clickFunc, tooltipFunc)
    local section = {}

    -- Create text
    section.text = f:CreateFontString(nil, "OVERLAY")
    section.text:SetJustifyH("LEFT")
    ApplyTextStyle(section.text, fontFile, size, outline, color)

    -- Create button for hover/click
    section.button = CreateFrame("Button", nil, f)
    section.button:SetHeight(size + PAD_Y * 2)
    if clickFunc then
      section.button:RegisterForClicks("LeftButtonUp")
      section.button:SetScript("OnClick", clickFunc)
    end

    -- Tooltip
    if tooltipFunc then
      section.button:SetScript("OnEnter", tooltipFunc)
      section.button:SetScript("OnLeave", HideCustomTooltip)
    end

    section.key = key
    f.sections[key] = section
    return section
  end

  -- Create sections in order: Guild, Friends, Durability, Gold, LootSpec

  -- Guild section
  local guildSection = CreateSection("guild",
    function(self, button)
      if button == "LeftButton" then
        if CommunitiesFrame and CommunitiesFrame:IsShown() then
          CommunitiesFrame:Hide()
        elseif CommunitiesFrame then
          CommunitiesFrame:Show()
        end
      end
    end,
    function(self)
      local anchor = "ANCHOR_BOTTOM"
      local screenHeight = GetScreenHeight()
      local frameTop = self:GetTop()
      if frameTop and screenHeight and frameTop < screenHeight / 2 then
        anchor = "ANCHOR_TOP"
      end

      local tooltip = ShowCustomTooltip(self, anchor)

      local hasContent = false

      -- Guild section
      if not cfg or cfg.showGuild ~= false then
        local members, guildOnlineCount, totalMembers = GetGuildOnlineInfo()
        if guildOnlineCount and guildOnlineCount > 0 then
          hasContent = true
          AddTooltipLine(tooltip, string.format("Guild: %d/%d", guildOnlineCount, totalMembers), 1, 1, 1)

          local motd = GetGuildRosterMOTD()
          if motd and motd ~= "" then
            AddTooltipLine(tooltip, "Guild MOTD - " .. motd, 0.5, 1, 0.5)
          end

          AddTooltipLine(tooltip, " ")

          for i, member in ipairs(members) do
            if i <= 20 then
              local classColor = RAID_CLASS_COLORS[member.class]
              local displayName = member.name
              if not (cfg and cfg.showServerName) then
                displayName = displayName:match("([^-]+)") or displayName
              end

              local rankText = ""
              if member.rank and member.rank ~= "" then
                rankText = " (" .. member.rank .. ")"
              end

              local statusText = ""
              if member.status == 1 then
                statusText = " <AFK>"
              elseif member.status == 2 then
                statusText = " <DND>"
              end

              local leftText = string.format("%d %s%s%s", member.level, displayName, rankText, statusText)
              local rightText = member.zone or ""

              if classColor then
                AddTooltipDoubleLine(tooltip, leftText, rightText,
                  classColor.r, classColor.g, classColor.b, 0.7, 0.7, 0.7)
              else
                AddTooltipDoubleLine(tooltip, leftText, rightText, 1, 1, 1, 0.7, 0.7, 0.7)
              end
            end
          end

          if guildOnlineCount > 20 then
            AddTooltipLine(tooltip, string.format("... and %d more", guildOnlineCount - 20), 0.5, 0.5, 0.5)
          end
        end
      end

      if hasContent then
        FinalizeTooltip(tooltip)
      else
        tooltip:Hide()
      end
    end
  )

  -- Friends section
  local friendsSection = CreateSection("friends",
    function(self, button)
      if button == "LeftButton" then
        ToggleFriendsFrame()
      end
    end,
    function(self)
      local anchor = "ANCHOR_BOTTOM"
      local screenHeight = GetScreenHeight()
      local frameTop = self:GetTop()
      if frameTop and screenHeight and frameTop < screenHeight / 2 then
        anchor = "ANCHOR_TOP"
      end

      local tooltip = ShowCustomTooltip(self, anchor)

      local friends, friendsOnlineCount, totalFriends = GetFriendsOnlineInfo()

      if friendsOnlineCount == 0 then
        AddTooltipLine(tooltip, "No friends online", 0.7, 0.7, 0.7)
      else
        AddTooltipLine(tooltip, string.format("Friends: %d/%d", friendsOnlineCount, totalFriends), 1, 1, 1)
        AddTooltipLine(tooltip, " ")

        for i, friend in ipairs(friends) do
          if i <= 20 then
            local classColor = friend.class and RAID_CLASS_COLORS[friend.class]

            local statusText = ""
            if friend.status == 1 then
              statusText = " <AFK>"
            elseif friend.status == 2 then
              statusText = " <DND>"
            end

            local leftText = string.format("%d %s%s", friend.level, friend.name, statusText)
            local rightText = friend.area or ""

            if classColor then
              AddTooltipDoubleLine(tooltip, leftText, rightText,
                classColor.r, classColor.g, classColor.b, 0.7, 0.7, 0.7)
            else
              AddTooltipDoubleLine(tooltip, leftText, rightText, 1, 1, 1, 0.7, 0.7, 0.7)
            end
          end
        end

        if friendsOnlineCount > 20 then
          AddTooltipLine(tooltip, string.format("... and %d more", friendsOnlineCount - 20), 0.5, 0.5, 0.5)
        end
      end

      FinalizeTooltip(tooltip)
    end
  )

  -- Durability section
  local durabilitySection = CreateSection("durability", nil,
    function(self)
      local durability, lowestSlot = GetLowestDurability()
      if not durability then return end

      local anchor = "ANCHOR_BOTTOM"
      local screenHeight = GetScreenHeight()
      local frameTop = self:GetTop()
      if frameTop and screenHeight and frameTop < screenHeight / 2 then
        anchor = "ANCHOR_TOP"
      end

      local tooltip = ShowCustomTooltip(self, anchor)
      AddTooltipLine(tooltip, "Durability", 1, 1, 1)
      AddTooltipLine(tooltip, " ")

      -- Slot names
      local slotNames = {
        [1] = "Head",
        [2] = "Neck",
        [3] = "Shoulder",
        [5] = "Chest",
        [6] = "Waist",
        [7] = "Legs",
        [8] = "Feet",
        [9] = "Wrist",
        [10] = "Hands",
        [11] = "Finger 1",
        [12] = "Finger 2",
        [13] = "Trinket 1",
        [14] = "Trinket 2",
        [15] = "Back",
        [16] = "Main Hand",
        [17] = "Off Hand",
        [18] = "Ranged"
      }

      -- Collect all items with durability
      local items = {}
      for slot = 1, 18 do
        local durCur, durMax = GetInventoryItemDurability(slot)
        if durCur and durMax and durMax > 0 then
          local pct = (durCur / durMax) * 100
          local itemLink = GetInventoryItemLink("player", slot)
          local itemName = slotNames[slot] or ("Slot " .. slot)

          table.insert(items, {
            slot = slot,
            name = itemName,
            link = itemLink,
            current = durCur,
            max = durMax,
            percent = pct
          })
        end
      end

      -- Sort by percent (lowest first)
      table.sort(items, function(a, b) return a.percent < b.percent end)

      -- Display all items
      for i, item in ipairs(items) do
        local r, g, b = 1, 1, 1
        if item.percent < 25 then
          r, g, b = 1, 0, 0  -- Red
        elseif item.percent < 50 then
          r, g, b = 1, 0.5, 0  -- Orange
        elseif item.percent < 75 then
          r, g, b = 1, 1, 0  -- Yellow
        end

        local displayText = string.format("%s: %.0f%%", item.name, item.percent)

        if item.link then
          -- Use item link for proper coloring
          AddTooltipDoubleLine(tooltip, item.link, string.format("%.0f%%", item.percent), 1, 1, 1, r, g, b)
        else
          AddTooltipDoubleLine(tooltip, displayText, "", r, g, b, r, g, b)
        end
      end

      FinalizeTooltip(tooltip)
    end
  )

  -- Gold section
  local goldSection = CreateSection("gold", nil,
    function(self)
      local anchor = "ANCHOR_BOTTOM"
      local screenHeight = GetScreenHeight()
      local frameTop = self:GetTop()
      if frameTop and screenHeight and frameTop < screenHeight / 2 then
        anchor = "ANCHOR_TOP"
      end

      local tooltip = ShowCustomTooltip(self, anchor)
      AddTooltipLine(tooltip, "Gold", 1, 1, 1)
      AddTooltipLine(tooltip, " ")

      local copper = GetPlayerGold()
      local gold = math.floor(copper / 10000)
      local silver = math.floor((copper % 10000) / 100)
      local copperRem = copper % 100

      -- Helper function to format numbers with spaces
      local function FormatNumber(num)
        local formatted = tostring(num)
        local k
        while true do
          formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
          if k == 0 then break end
        end
        return formatted
      end

      -- Gold (yellow/gold color)
      if gold > 0 then
        AddTooltipDoubleLine(tooltip, "Gold:", FormatNumber(gold), 1, 1, 1, 1, 0.82, 0)
      end

      -- Silver (silver/gray color)
      if silver > 0 then
        AddTooltipDoubleLine(tooltip, "Silver:", FormatNumber(silver), 1, 1, 1, 0.75, 0.75, 0.75)
      end

      -- Copper (bronze/brown color)
      if copperRem > 0 then
        AddTooltipDoubleLine(tooltip, "Copper:", FormatNumber(copperRem), 1, 1, 1, 0.8, 0.5, 0.2)
      end

      FinalizeTooltip(tooltip)
    end
  )

  -- Loot Spec section
  local lootSpecSection = CreateSection("lootSpec", nil,
    function(self)
      local lootSpec, icon = GetLootSpecInfo()
      if not lootSpec then return end

      local anchor = "ANCHOR_BOTTOM"
      local screenHeight = GetScreenHeight()
      local frameTop = self:GetTop()
      if frameTop and screenHeight and frameTop < screenHeight / 2 then
        anchor = "ANCHOR_TOP"
      end

      local tooltip = ShowCustomTooltip(self, anchor)
      AddTooltipLine(tooltip, "Loot Specialization", 1, 1, 1)
      AddTooltipLine(tooltip, lootSpec, 0.5, 1, 0.5)
      FinalizeTooltip(tooltip)
    end
  )

  -- Add icon texture to loot spec section
  lootSpecSection.icon = f:CreateTexture(nil, "ARTWORK")
  lootSpecSection.icon:SetSize(size, size)
  lootSpecSection.icon:Hide()

  -- Update function to rebuild sections
  local function RefreshData()
    -- Hide all sections first
    for _, section in pairs(f.sections) do
      section.text:Hide()
      section.button:Hide()
      if section.icon then
        section.icon:Hide()
      end
      if section.specName then
        section.specName:Hide()
      end
    end

    local xOffset = PAD_X
    local visibleSections = {}

    -- Guild
    if not cfg or cfg.showGuild ~= false then
      local _, onlineCount = GetGuildOnlineInfo()
      if onlineCount then
        -- Play sound if someone came online
        if f._lastOnlineCount > 0 and onlineCount > f._lastOnlineCount then
          local soundChoice = (cfg and cfg.onlineSound) or "AUCTION_WINDOW_OPEN"
          local soundChannel = (cfg and cfg.onlineSoundChannel) or "Master"
          local customSound = cfg and cfg.customOnlineSound

          local sounds = {
            FRIENDS_ONLINE = 567,
            LEVEL_UP = SOUNDKIT.LEVEL_UP,
            READY_CHECK = SOUNDKIT.READY_CHECK,
            RAID_WARNING = SOUNDKIT.RAID_WARNING,
            PVP_ENTER_QUEUE = SOUNDKIT.PVP_ENTER_QUEUE,
            TELL_MESSAGE = SOUNDKIT.TELL_MESSAGE,
            AUCTION_WINDOW_OPEN = SOUNDKIT.AUCTION_WINDOW_OPEN,
            LOOT_WINDOW_COIN_SOUND = SOUNDKIT.LOOT_WINDOW_COIN_SOUND,
            QUEST_COMPLETE = SOUNDKIT.IG_QUEST_LIST_COMPLETE,
            ACHIEVEMENT_MENU_OPEN = SOUNDKIT.ACHIEVEMENT_MENU_OPEN,
            UI_LEGENDARY_FORGE = SOUNDKIT.UI_LEGENDARY_FORGE,
            UI_PROFESSION_DING = SOUNDKIT.UI_PROFESSION_DING,
            ALARM_CLOCK_WARNING_1 = SOUNDKIT.ALARM_CLOCK_WARNING_1,
            ALARM_CLOCK_WARNING_2 = SOUNDKIT.ALARM_CLOCK_WARNING_2,
            ALARM_CLOCK_WARNING_3 = SOUNDKIT.ALARM_CLOCK_WARNING_3,
            CUSTOM = nil
          }

          if soundChoice == "CUSTOM" and customSound and customSound ~= "" then
            PlaySoundFile(customSound, soundChannel)
          elseif soundChoice == "WOW_LOGIN" then
            PlaySoundFile("Sound\\Interface\\gsLogin.ogg", soundChannel)
          else
            local soundID = sounds[soundChoice]
            if soundID then
              PlaySound(soundID, soundChannel)
            end
          end
        end
        f._lastOnlineCount = onlineCount

        -- Get player's class color
        local _, className = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[className]
        local colorCode = ""
        if classColor then
          colorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        end

        guildSection.text:SetText(string.format("Guild: %s%d|r", colorCode, onlineCount))
        guildSection.text:Show()
        guildSection.text:SetPoint("LEFT", xOffset, 0)

        local textWidth = guildSection.text:GetStringWidth()
        guildSection.button:SetPoint("LEFT", xOffset, 0)
        guildSection.button:SetWidth(textWidth)
        guildSection.button:Show()

        xOffset = xOffset + textWidth + SECTION_SPACING
        table.insert(visibleSections, "guild")
      end
    end

    -- Friends
    if cfg and cfg.showFriends then
      local _, friendsOnline = GetFriendsOnlineInfo()

      -- Get player's class color
      local _, className = UnitClass("player")
      local classColor = RAID_CLASS_COLORS[className]
      local colorCode = ""
      if classColor then
        colorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
      end

      friendsSection.text:SetText(string.format("Friends: %s%d|r", colorCode, friendsOnline))
      friendsSection.text:Show()
      friendsSection.text:SetPoint("LEFT", xOffset, 0)

      local textWidth = friendsSection.text:GetStringWidth()
      friendsSection.button:SetPoint("LEFT", xOffset, 0)
      friendsSection.button:SetWidth(textWidth)
      friendsSection.button:Show()

      xOffset = xOffset + textWidth + SECTION_SPACING
      table.insert(visibleSections, "friends")
    end

    -- Durability
    if cfg and cfg.showDurability then
      local durability = GetLowestDurability()
      if durability then
        durabilitySection.text:SetText(string.format("Dur: %.0f%%", durability))
        durabilitySection.text:Show()
        durabilitySection.text:SetPoint("LEFT", xOffset, 0)

        local textWidth = durabilitySection.text:GetStringWidth()
        durabilitySection.button:SetPoint("LEFT", xOffset, 0)
        durabilitySection.button:SetWidth(textWidth)
        durabilitySection.button:Show()

        xOffset = xOffset + textWidth + SECTION_SPACING
        table.insert(visibleSections, "durability")
      end
    end

    -- Gold
    if cfg and cfg.showGold then
      local gold = FormatGold(GetPlayerGold())
      -- Color the gold amount in gold color (|cffFFD100)
      goldSection.text:SetText(string.format("Gold: |cffFFD100%s|r", gold))
      goldSection.text:Show()
      goldSection.text:SetPoint("LEFT", xOffset, 0)

      local textWidth = goldSection.text:GetStringWidth()
      goldSection.button:SetPoint("LEFT", xOffset, 0)
      goldSection.button:SetWidth(textWidth)
      goldSection.button:Show()

      xOffset = xOffset + textWidth + SECTION_SPACING
      table.insert(visibleSections, "gold")
    end

    -- Loot Spec
    if not cfg or cfg.showLootSpec ~= false then
      local lootSpec, icon = GetLootSpecInfo()
      if lootSpec then
        -- Show "Loot: " text first
        lootSpecSection.text:SetText("Loot: ")
        lootSpecSection.text:Show()
        lootSpecSection.text:SetPoint("LEFT", xOffset, 0)

        local labelWidth = lootSpecSection.text:GetStringWidth()
        xOffset = xOffset + labelWidth

        -- Show icon after "Loot: "
        if icon then
          lootSpecSection.icon:SetTexture(icon)
          lootSpecSection.icon:SetPoint("LEFT", xOffset, 0)
          lootSpecSection.icon:Show()
          xOffset = xOffset + size + 2  -- Icon width + small spacing
        end

        -- Create a second FontString for the spec name (after icon)
        if not lootSpecSection.specName then
          lootSpecSection.specName = f:CreateFontString(nil, "OVERLAY")
          lootSpecSection.specName:SetJustifyH("LEFT")
          ApplyTextStyle(lootSpecSection.specName, fontFile, size, outline, color)
        end

        lootSpecSection.specName:SetText(lootSpec)
        lootSpecSection.specName:SetPoint("LEFT", xOffset, 0)
        lootSpecSection.specName:Show()

        local nameWidth = lootSpecSection.specName:GetStringWidth()
        local totalWidth = labelWidth + (icon and (size + 2) or 0) + nameWidth

        lootSpecSection.button:SetPoint("LEFT", xOffset - totalWidth, 0)
        lootSpecSection.button:SetWidth(totalWidth)
        lootSpecSection.button:Show()

        xOffset = xOffset + nameWidth + SECTION_SPACING
        table.insert(visibleSections, "lootSpec")
      end
    end

    -- Set frame width
    if #visibleSections == 0 then
      f:SetWidth(100)
    else
      f:SetWidth(math.max(100, xOffset - SECTION_SPACING + PAD_X))
    end
  end

  -- Register events
  f:RegisterEvent("GUILD_ROSTER_UPDATE")
  f:RegisterEvent("PLAYER_GUILD_UPDATE")
  f:RegisterEvent("FRIENDLIST_UPDATE")
  f:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
  f:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
  f:RegisterEvent("BN_FRIEND_INFO_CHANGED")
  f:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
  f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  f:RegisterEvent("PLAYER_MONEY")
  f:RegisterEvent("UPDATE_INVENTORY_DURABILITY")

  f:SetScript("OnEvent", function(self, event)
    if event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" or
       event == "FRIENDLIST_UPDATE" or event == "BN_FRIEND_ACCOUNT_ONLINE" or
       event == "BN_FRIEND_ACCOUNT_OFFLINE" or event == "BN_FRIEND_INFO_CHANGED" or
       event == "PLAYER_LOOT_SPEC_UPDATED" or event == "PLAYER_SPECIALIZATION_CHANGED" or
       event == "PLAYER_MONEY" or event == "UPDATE_INVENTORY_DURABILITY" then
      RefreshData()
    end
  end)

  -- Update ticker as backup
  if C_Timer and C_Timer.NewTicker then
    f._ticker = C_Timer.NewTicker(60, RefreshData)
  end

  RefreshData()

  -- Request guild roster and friends update on show
  f:SetScript("OnShow", function()
    if IsInGuild() then
      C_GuildInfo.GuildRoster()
    end
    RefreshData()
  end)

  -- Initial data load with delay
  C_Timer.After(1, function()
    RefreshData()
  end)

  function f:Destroy()
    if f._ticker and f._ticker.Cancel then
      f._ticker:Cancel()
      f._ticker = nil
    end
    if self.SetScript then
      self:SetScript("OnUpdate", nil)
      self:SetScript("OnShow", nil)
      self:SetScript("OnEnter", nil)
      self:SetScript("OnLeave", nil)
    end
  end

  return f
end

function API.update(frame, cfg)
  if not frame then return end

  local fontFile, size, outline, color, bgColor, borderColor = ReadCfg(cfg)

  -- Update font for all sections
  if frame.sections then
    for _, section in pairs(frame.sections) do
      if section.text then
        ApplyTextStyle(section.text, fontFile, size, outline, color)
      end
    end
  end

  -- Update backdrop colors
  if frame.SetBackdropColor then
    frame:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
  end
  if frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
  end

  -- Update size
  frame:SetHeight(size + PAD_Y * 2)
end

SkyInfoTiles.RegisterTileType("infobar", API)
