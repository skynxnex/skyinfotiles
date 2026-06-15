local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local W = SkyInfoTiles.StyledWidgets  -- Import styled widgets

-- Custom standalone options window
local optionsFrame = nil

-- StaticPopup dialogs for profile management
StaticPopupDialogs["SKYINFOTILES_NEW_PROFILE"] = {
  text = "Enter a name for the new profile:",
  button1 = "Create",
  button2 = "Cancel",
  hasEditBox = true,
  OnShow = function(self)
    self.EditBox:SetText("")
    self.EditBox:SetFocus()
  end,
  OnAccept = function(self)
    local name = self.EditBox:GetText()
    if name and name ~= "" then
      local success, err = SkyInfoTiles.CreateProfile(name)
      if success then
        print("|cff66ccffSkyInfoTiles:|r Profile created: " .. name)
        -- Automatically switch to the new profile
        SkyInfoTiles.SetActiveProfile(name)
      else
        print("|cff66ccffSkyInfoTiles:|r " .. tostring(err))
      end
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["SKYINFOTILES_RENAME_PROFILE"] = {
  text = "Rename profile '%s' to:",
  button1 = "Rename",
  button2 = "Cancel",
  hasEditBox = true,
  OnShow = function(self)
    self.EditBox:SetText("")
    self.EditBox:SetFocus()
  end,
  OnAccept = function(self)
    local oldName = self.data
    local newName = self.EditBox:GetText()
    if newName and newName ~= "" then
      local success, err = SkyInfoTiles.RenameProfile(oldName, newName)
      if success then
        print("|cff66ccffSkyInfoTiles:|r Profile renamed to: " .. newName)
      else
        print("|cff66ccffSkyInfoTiles:|r " .. tostring(err))
      end
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["SKYINFOTILES_DELETE_PROFILE"] = {
  text = "Delete profile '%s'?\n\nAny characters using this profile will be switched to Default.",
  button1 = "Delete",
  button2 = "Cancel",
  OnAccept = function(self)
    local profileName = self.data
    local success, err = SkyInfoTiles.DeleteProfile(profileName)
    if success then
      print("|cff66ccffSkyInfoTiles:|r Profile deleted: " .. profileName)
    else
      print("|cff66ccffSkyInfoTiles:|r " .. tostring(err))
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- Forward declarations
local CreatePositionSliders

-- Helper to create standard tab with background and enable toggle
local function CreateStandardTab(contentArea, tabContent, tabIndex, tileKey, tileName, tooltipText)
  local tab = CreateFrame("Frame", nil, contentArea)
  tab:SetAllPoints()
  tab:Hide()
  tabContent[tabIndex] = tab

  local W = SkyInfoTiles.StyledWidgets
  if not W then return tab end

  -- Background (transparent - let main frame background show through)
  local bg = tab:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0)

  -- Enable toggle
  local enableRow, height = W:CreateToggle(tab, -10, "Enable " .. tileName,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileKey or tile.type == tileKey then
            return tile.enabled
          end
        end
      end
      return false
    end,
    function(enabled)
      if SkyInfoTiles.SetTileEnabledByKey then
        SkyInfoTiles.SetTileEnabledByKey(tileKey, enabled)
      end
    end,
    tooltipText or ("Toggle the " .. tileName .. " on/off")
  )
  tab.enableRow = enableRow

  return tab, -10 - height
end

-- Helper function to create X/Y position sliders for a tile
-- Helper function to create InfoBar tab (extracted to reduce local variable count)
local function CreateInfoBarTab(contentArea, tabContent)
  local infobarTab = CreateFrame("Frame", nil, contentArea)
  infobarTab:SetAllPoints()
  infobarTab:Hide()
  tabContent[9] = infobarTab

  print("CreateInfoBarTab called!")
  print("SkyInfoTiles.StyledWidgets = ", SkyInfoTiles.StyledWidgets)

  local W = SkyInfoTiles.StyledWidgets
  if not W then
    print("SkyInfoTiles: StyledWidgets not loaded!")
    return
  end

  print("Using StyledWidgets!")

  -- Background (transparent - let main frame background show through)
  local bg = infobarTab:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0)

  -- Enable toggle at the top
  local yOffset = -10
  local enableRow, height = W:CreateToggle(infobarTab, yOffset, "Enable Info Bar",
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "infobar" or tile.type == "infobar" then
            return tile.enabled
          end
        end
      end
      return false
    end,
    function(enabled)
      if SkyInfoTiles.SetTileEnabledByKey then
        SkyInfoTiles.SetTileEnabledByKey("infobar", enabled)
      end
    end,
    "Toggle the Info Bar on/off"
  )
  yOffset = yOffset - height
  infobarTab.enableRow = enableRow

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, infobarTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, yOffset)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 800)
  scrollFrame:SetScrollChild(scrollChild)

  infobarTab.scrollFrame = scrollFrame
  infobarTab.scrollChild = scrollChild

  local yOffset = -10

  -- Position sliders
  local infobarPosSliders = CreatePositionSliders(scrollChild, "infobar", "infobar", yOffset)
  infobarTab.xPosSlider = infobarPosSliders.xPosSlider
  infobarTab.yPosSlider = infobarPosSliders.yPosSlider
  yOffset = infobarPosSliders.newYOffset

  -- Strata dropdown
  local strataValues = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP"
  }
  local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

  local strataRow, strataHeight, strataDropdown = W:CreateDropdown(scrollChild, yOffset, "Frame Strata (Layer)",
    strataValues, strataOrder,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "infobar" or tile.type == "infobar" then
            return tile.strata or "MEDIUM"
          end
        end
      end
      return "MEDIUM"
    end,
    function(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "infobar" or tile.type == "infobar" then
            tile.strata = value
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Set the frame strata (layer) for the info bar"
  )
  infobarTab.strataDropdown = strataDropdown
  yOffset = yOffset - strataHeight - 10

  -- Section header: Display Options
  local _, headerHeight = W:CreateSectionHeader(scrollChild, yOffset, "Display Options")
  yOffset = yOffset - headerHeight - 10

  -- Helper function to get/set tile config
  local function GetTileConfig(key)
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "infobar" or tile.type == "infobar" then
          return tile[key]
        end
      end
    end
    return key == "showGuild" or key == "showLootSpec"  -- defaults
  end

  local function SetTileConfig(key, value)
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "infobar" or tile.type == "infobar" then
          tile[key] = value
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end

  -- Show Guild toggle
  local showGuildRow, h = W:CreateToggle(scrollChild, yOffset, "Show Guild",
    function() return GetTileConfig("showGuild") end,
    function(val) SetTileConfig("showGuild", val) end,
    "Display guild online count in the info bar"
  )
  yOffset = yOffset - h
  infobarTab.showGuildRow = showGuildRow

  -- Show Loot Spec toggle
  local showLootSpecRow, h2 = W:CreateToggle(scrollChild, yOffset, "Show Loot Spec",
    function() return GetTileConfig("showLootSpec") end,
    function(val) SetTileConfig("showLootSpec", val) end,
    "Display your current loot specialization"
  )
  yOffset = yOffset - h2
  infobarTab.showLootSpecRow = showLootSpecRow

  -- Show Gold toggle
  local showGoldRow, h3 = W:CreateToggle(scrollChild, yOffset, "Show Gold",
    function() return GetTileConfig("showGold") end,
    function(val) SetTileConfig("showGold", val) end,
    "Display your total gold"
  )
  yOffset = yOffset - h3
  infobarTab.showGoldRow = showGoldRow

  -- Show Durability toggle
  local showDurabilityRow, h4 = W:CreateToggle(scrollChild, yOffset, "Show Durability",
    function() return GetTileConfig("showDurability") end,
    function(val) SetTileConfig("showDurability", val) end,
    "Display lowest equipment durability percentage"
  )
  yOffset = yOffset - h4
  infobarTab.showDurabilityRow = showDurabilityRow

  -- Show Friends toggle
  local showFriendsRow, h5 = W:CreateToggle(scrollChild, yOffset, "Show Friends",
    function() return GetTileConfig("showFriends") end,
    function(val) SetTileConfig("showFriends", val) end,
    "Display online friends count (Retail WoW only)"
  )
  yOffset = yOffset - h5
  infobarTab.showFriendsRow = showFriendsRow

  -- Separator line
  local separator1 = scrollChild:CreateTexture(nil, "ARTWORK")
  separator1:SetColorTexture(0.5, 0.5, 0.5, 0.5)
  separator1:SetSize(550, 1)
  separator1:SetPoint("TOPLEFT", 10, yOffset - 5)
  yOffset = yOffset - 20

  -- Section header: Notification Settings
  local _, notifHeaderHeight = W:CreateSectionHeader(scrollChild, yOffset, "Friend/Guild Online Notification")
  yOffset = yOffset - notifHeaderHeight - 10

  -- Sound selection dropdown
  local soundValues = {
    FRIENDS_ONLINE = "Friend Online (Recommended)",
    WOW_LOGIN = "WoW Login Sound",
    LEVEL_UP = "Level Up",
    READY_CHECK = "Ready Check",
    RAID_WARNING = "Raid Warning",
    PVP_ENTER_QUEUE = "PvP Queue Pop (Loud)",
    TELL_MESSAGE = "Whisper",
    AUCTION_WINDOW_OPEN = "Pleasant Pling",
    LOOT_WINDOW_COIN_SOUND = "Coin Drop",
    QUEST_COMPLETE = "Quest Complete",
    ACHIEVEMENT_MENU_OPEN = "Achievement",
    UI_LEGENDARY_FORGE = "Legendary Item",
    UI_PROFESSION_DING = "Profession Ding",
    ALARM_CLOCK_WARNING_1 = "Alarm Bell 1 (Loud)",
    ALARM_CLOCK_WARNING_2 = "Alarm Bell 2 (Loud)",
    ALARM_CLOCK_WARNING_3 = "Alarm Bell 3 (Loud)",
    CUSTOM = "Custom Sound File",
    NONE = "No Sound"
  }
  local soundOrder = {
    "FRIENDS_ONLINE", "WOW_LOGIN", "LEVEL_UP", "READY_CHECK", "RAID_WARNING",
    "PVP_ENTER_QUEUE", "TELL_MESSAGE", "AUCTION_WINDOW_OPEN", "LOOT_WINDOW_COIN_SOUND",
    "QUEST_COMPLETE", "ACHIEVEMENT_MENU_OPEN", "UI_LEGENDARY_FORGE", "UI_PROFESSION_DING",
    "ALARM_CLOCK_WARNING_1", "ALARM_CLOCK_WARNING_2", "ALARM_CLOCK_WARNING_3",
    "CUSTOM", "NONE"
  }

  local soundRow, soundHeight, soundDropdown = W:CreateDropdown(scrollChild, yOffset, "Notification Sound",
    soundValues, soundOrder,
    function()
      return GetTileConfig("onlineSound") or "AUCTION_WINDOW_OPEN"
    end,
    function(value)
      SetTileConfig("onlineSound", value)
    end,
    "Choose which sound plays when friends/guildmates come online"
  )
  infobarTab.soundDropdown = soundDropdown
  yOffset = yOffset - soundHeight - 10

  -- Sound channel dropdown
  local channelValues = {
    Master = "Master",
    SFX = "Sound Effects",
    Music = "Music",
    Ambience = "Ambience",
    Dialog = "Dialog"
  }
  local channelOrder = { "Master", "SFX", "Music", "Ambience", "Dialog" }

  local channelRow, channelHeight, channelDropdown = W:CreateDropdown(scrollChild, yOffset, "Sound Channel",
    channelValues, channelOrder,
    function()
      return GetTileConfig("onlineSoundChannel") or "Master"
    end,
    function(value)
      SetTileConfig("onlineSoundChannel", value)
    end,
    "Choose which audio channel to play the notification sound on"
  )
  infobarTab.channelDropdown = channelDropdown
  yOffset = yOffset - channelHeight - 10

  -- Adjust scrollChild height to fit all content
  scrollChild:SetHeight(math.abs(yOffset) + 50)

  return infobarTab
end

CreatePositionSliders = function(parent, tileKey, tileType, yOffset)
  local scrollChild = parent

  -- ========== POSITION (X coordinate) ==========
  local _, xHeightUsed, xPosSlider = W:CreateSlider(scrollChild, yOffset, "X Position", -3000, 5000, 1,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileKey or tile.type == tileType then
            return tile.x or 0
          end
        end
      end
      return 0
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileKey or tile.type == tileType then
            tile.point = "TOPLEFT"
            tile.x = val
            if SkyInfoTiles.Rebuild then
              SkyInfoTiles.Rebuild()
            end
            break
          end
        end
      end
    end,
    "Horizontal position (-3000 to 5000)"
  )
  yOffset = yOffset - xHeightUsed - 10

  -- ========== POSITION (Y coordinate) ==========
  local _, yHeightUsed, yPosSlider = W:CreateSlider(scrollChild, yOffset, "Y Position", -3000, 3000, 1,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileKey or tile.type == tileType then
            return tile.y or 0
          end
        end
      end
      return 0
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileKey or tile.type == tileType then
            tile.point = "TOPLEFT"
            tile.y = val
            if SkyInfoTiles.Rebuild then
              SkyInfoTiles.Rebuild()
            end
            break
          end
        end
      end
    end,
    "Vertical position (-3000 to 3000)"
  )
  yOffset = yOffset - yHeightUsed - 10

  -- Reset Position button (centers tile on screen)
  local resetBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 25)
  resetBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetBtn:SetText("Reset Position")
  resetBtn:SetScript("OnClick", function()
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == tileKey or tile.type == tileType then
          -- Center on screen with TOPLEFT anchor
          local screenWidth = math.floor((GetScreenWidth and GetScreenWidth() or 1920) + 0.5)
          local screenHeight = math.floor((GetScreenHeight and GetScreenHeight() or 1080) + 0.5)

          tile.x = screenWidth / 2
          tile.y = -screenHeight / 2

          -- Update sliders via refresh
          if xPosSlider and xPosSlider.Refresh then
            xPosSlider:Refresh()
          end
          if yPosSlider and yPosSlider.Refresh then
            yPosSlider:Refresh()
          end
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          break
        end
      end
    end
  end)

  yOffset = yOffset - 35

  return {
    xPosSlider = xPosSlider,
    yPosSlider = yPosSlider,
    resetBtn = resetBtn,
    newYOffset = yOffset
  }
end

-- Forward declaration for Part2 to avoid local variable limit issues
local CreateOptionsWindow_Part2

local function CreateOptionsWindow()
  if optionsFrame then return optionsFrame end

  -- Reusable temp variable to reduce local variable count
  local temp

  -- Main frame (fixed size - not resizable to prevent UI elements from going off-screen)
  local f = CreateFrame("Frame", "SkyInfoTilesOptionsFrame", UIParent, "BackdropTemplate")

  -- Background texture directly on main frame
  local bgTexture = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  bgTexture:SetTexture("Interface\\AddOns\\SkyInfoTiles\\media\\bg-sky.png")
  bgTexture:SetAllPoints(f)
  bgTexture:SetTexCoord(0.05, 0.955, 0.055, 0.92)  -- Right edge: 0.5% less crop, 5.5% top crop
  bgTexture:SetVertexColor(0.6, 0.85, 1.0)  -- Sky blue tint
  bgTexture:SetAlpha(1.0)

  -- Gradient overlay
  local bgGradient = f:CreateTexture(nil, "BACKGROUND", nil, -7)
  bgGradient:SetAllPoints(f)
  bgGradient:SetGradient("VERTICAL",
    CreateColor(0.4, 0.8, 1.0, 0.08),
    CreateColor(0, 0, 0, 0))
  bgGradient:SetBlendMode("ADD")

  -- Larger to better fit blue content area
  f:SetSize(1100, 850)  -- Restore original height
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")

  -- Add pixel-perfect scaling (Ellesmere approach)
  local physW = GetPhysicalScreenSize()
  local baseScale = GetScreenWidth() / physW
  f:SetScale(baseScale)  -- Make 1 WoW unit = 1 screen pixel

  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetResizable(false)  -- Disabled resizing
  f:SetClampedToScreen(true)
  f:Hide()

  -- Register with UISpecialFrames to allow ESC key to close the window
  table.insert(UISpecialFrames, "SkyInfoTilesOptionsFrame")

  -- Track if we were open before combat
  f._wasOpenBeforeCombat = false

  -- Hide options window when entering combat, reopen when leaving
  f:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Entering combat
  f:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leaving combat
  f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
      -- Entering combat - close if open
      if self:IsShown() then
        self._wasOpenBeforeCombat = true
        self:Hide()
        if DEFAULT_CHAT_FRAME then
          DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r Options closed (entering combat)")
        end
      end
    elseif event == "PLAYER_REGEN_ENABLED" then
      -- Leaving combat - reopen if it was open before
      if self._wasOpenBeforeCombat then
        self._wasOpenBeforeCombat = false
        self:Show()
        if DEFAULT_CHAT_FRAME then
          DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSkyInfoTiles:|r Options reopened")
        end
      end
    end
  end)

  -- No backdrop at all - let bgFrame textures show
  f:SetBackdrop({
    bgFile = nil,
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
  })
  f:SetBackdropBorderColor(1, 1, 1, 0.08)

  -- Background textures already created above with bgFrame

  print("SkyInfoTiles: Background texture loaded on bgFrame (theme with sky blue tint)")

  -- Enable dragging directly on main frame
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  -- Invisible close button positioned over the X icon in bg2.png (top right)
  local closeBtn = CreateFrame("Button", nil, f)
  closeBtn:SetSize(40, 40)
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, -15)
  closeBtn:SetScript("OnClick", function() f:Hide() end)
  closeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Close")
    GameTooltip:Show()
  end)
  closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Title text (no background bar, just text on the frame)
  local title = f:CreateFontString(nil, "OVERLAY", "SystemFont_Huge1")
  title:SetPoint("TOP", f, "TOP", 0, -40)  -- Further down from -15
  title:SetText("SkyInfoTiles")
  title:SetFont(title:GetFont(), 36, "THICKOUTLINE")  -- Larger from 28
  title:SetTextColor(1, 1, 1, 1)  -- Pure white
  title:SetShadowColor(0, 0, 0, 0.8)
  title:SetShadowOffset(2, -2)

  -- No resize grip (window is fixed size)

  -- Sidebar frame (left navigation)
  local sidebar = CreateFrame("Frame", nil, f)
  sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -50)  -- Below title
  sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  sidebar:SetWidth(210)

  local sidebarButtons = {}
  local tabContent = {}
  local SelectSidebarButton  -- Forward declaration

  -- Create sidebar button
  local function CreateSidebarButton(name, index, yOffset)
    local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
    btn:SetSize(200, 40)
    btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 5, yOffset)
    btn.index = index

    -- Transparent background
    btn:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = nil
    })
    btn:SetBackdropColor(0, 0, 0, 0)

    -- Left indicator line (sky blue, hidden by default)
    local indicator = btn:CreateTexture(nil, "ARTWORK")
    indicator:SetColorTexture(0.4, 0.8, 1.0, 0.9)
    indicator:SetSize(3, 40)
    indicator:SetPoint("LEFT", btn, "LEFT", 0, 0)
    indicator:Hide()
    btn.indicator = indicator

    -- Text label (left-aligned)
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", btn, "LEFT", 10, 0)
    text:SetText(name)
    text:SetTextColor(0.7, 0.7, 0.7, 1)
    btn.text = text

    -- Hover glow
    local hoverGlow = btn:CreateTexture(nil, "BACKGROUND")
    hoverGlow:SetColorTexture(0.1, 0.1, 0.15, 0.3)
    hoverGlow:SetAllPoints(btn)
    hoverGlow:Hide()
    btn.hoverGlow = hoverGlow

    -- Hover handlers
    btn:SetScript("OnEnter", function(self)
      if not self.selected then
        self.hoverGlow:Show()
        self.text:SetTextColor(1, 1, 1, 0.85)
      end
    end)

    btn:SetScript("OnLeave", function(self)
      if not self.selected then
        self.hoverGlow:Hide()
        self.text:SetTextColor(0.7, 0.7, 0.7, 1)
      end
    end)

    return btn
  end

  -- Selection logic
  SelectSidebarButton = function(index)
    -- Deselect all
    for i, btn in ipairs(sidebarButtons) do
      btn.selected = false
      btn.indicator:Hide()
      btn.text:SetTextColor(0.7, 0.7, 0.7, 1)
    end

    -- Select clicked button
    local btn = sidebarButtons[index]
    if btn then
      btn.selected = true
      btn.indicator:Show()
      btn.text:SetTextColor(1, 1, 1, 1)

      -- Show corresponding content
      for i, content in ipairs(tabContent) do
        content:Hide()
      end
      if tabContent[index] then
        tabContent[index]:Show()
      end
    end
  end

  -- Create all sidebar buttons
  local tabNames = {"General", "Currencies", "Keystone", "Char Stats", "Crosshair", "Clock", "Portals", "BuffTracker", "InfoBar", "Profiles"}
  local yOffset = -120  -- Further down below horizontal line
  for i, name in ipairs(tabNames) do
    local btn = CreateSidebarButton(name, i, yOffset)
    btn:SetScript("OnClick", function(self)
      SelectSidebarButton(self.index)
    end)
    table.insert(sidebarButtons, btn)
    yOffset = yOffset - 45
  end

  -- Mark first button (General) as selected by default
  if sidebarButtons[1] then
    sidebarButtons[1].selected = true
    sidebarButtons[1].indicator:Show()
    sidebarButtons[1].text:SetTextColor(1, 1, 1, 1)
  end

  -- Content area (no backdrop template - fully transparent)
  local contentArea = CreateFrame("Frame", nil, f)
  contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 50, -120)  -- More right, further down
  contentArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 80)  -- End higher up (80 instead of 10)

  -- === TAB 1: GENERAL ===
  local generalTab = CreateFrame("Frame", nil, contentArea)
  generalTab:SetAllPoints()
  generalTab:Hide()
  tabContent[1] = generalTab

  local W = SkyInfoTiles.StyledWidgets

  -- Background (transparent - let main frame background show through)
  local bg = generalTab:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0)

  local yOffset = -10

  -- Lock toggle
  local lockRow, h1 = W:CreateToggle(generalTab, yOffset, "Lock Tiles",
    function() return SkyInfoTilesDB.locked end,
    function(val)
      SkyInfoTilesDB.locked = val
      SkyInfoTiles.ApplyLockState()
    end,
    "Prevent tiles from being dragged and repositioned"
  )
  generalTab.lockRow = lockRow
  yOffset = yOffset - h1 - 10

  -- Section header
  local _, headerHeight = W:CreateSectionHeader(generalTab, yOffset, "Maintenance")
  yOffset = yOffset - headerHeight - 10

  -- Reset button
  local resetBtn, h2 = W:CreateButton(generalTab, yOffset, "Reset All Settings", 200,
    function()
      if SkyInfoTiles.ResetProfile then
        SkyInfoTiles.ResetProfile()
        print("|cff66ccffSkyInfoTiles:|r Settings reset to defaults")
      end
    end,
    "Reset all tiles and settings to default values"
  )
  yOffset = yOffset - h2

  -- Clean button
  local cleanBtn, h3 = W:CreateButton(generalTab, yOffset, "Clean Database", 200,
    function()
      if SkyInfoTiles.CleanProfile then
        SkyInfoTiles.CleanProfile()
        print("|cff66ccffSkyInfoTiles:|r Database cleaned")
      end
    end,
    "Remove duplicate tiles and clean up the database"
  )
  yOffset = yOffset - h3

  -- === TAB 2: CURRENCIES ===
  local currencyTab = CreateFrame("Frame", nil, contentArea)
  currencyTab:SetAllPoints()
  currencyTab:Hide()
  tabContent[2] = currencyTab

  -- Background (transparent - let main frame background show through)
  local currencyBg = currencyTab:CreateTexture(nil, "BACKGROUND")
  currencyBg:SetAllPoints()
  currencyBg:SetColorTexture(0, 0, 0, 0)

  -- Enable Currency Tile toggle
  local enableCurrencyRow, currencyH1 = W:CreateToggle(currencyTab, -10, "Enable Currency Tile",
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "currencies" or tile.type == "currencies" then
            return tile.enabled
          end
        end
      end
      return false
    end,
    function(enabled)
      if SkyInfoTiles.SetTileEnabledByKey then
        SkyInfoTiles.SetTileEnabledByKey("currencies", enabled)
      end
    end,
    "Toggle the Currency Tile on/off"
  )
  currencyTab.enableRow = enableCurrencyRow

  -- Scroll frame for currencies
  local scrollFrame = CreateFrame("ScrollFrame", nil, currencyTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, -40)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 45) -- 45px space for buttons at bottom

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 1) -- Height set dynamically
  scrollFrame:SetScrollChild(scrollChild)

  currencyTab.scrollFrame = scrollFrame
  currencyTab.scrollChild = scrollChild

  local yOffsetCurr = -10

  -- Hide Labels toggle
  local hideLabelRow, h = W:CreateToggle(scrollChild, yOffsetCurr, "Hide Labels",
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "currencies" or tile.type == "currencies" then
            return tile.hideLabel
          end
        end
      end
      return false
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "currencies" or tile.type == "currencies" then
            tile.hideLabel = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Show only numbers without currency names"
  )
  currencyTab.hideLabelRow = hideLabelRow
  yOffsetCurr = yOffsetCurr - h

  -- Position sliders (X and Y) - inside scroll
  local currencyPosSliders = CreatePositionSliders(scrollChild, "currencies", "currencies", yOffsetCurr)
  currencyTab.xPosSlider = currencyPosSliders.xPosSlider
  currencyTab.xPosEditBox = currencyPosSliders.xPosEditBox
  currencyTab.yPosSlider = currencyPosSliders.yPosSlider
  currencyTab.yPosEditBox = currencyPosSliders.yPosEditBox
  yOffsetCurr = currencyPosSliders.newYOffset

  yOffsetCurr = yOffsetCurr - 20

  -- Strata dropdown
  local strataValues = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP"
  }
  local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

  local strataRow, strataHeight, strataDropdown = W:CreateDropdown(scrollChild, yOffsetCurr, "Frame Strata (Layer)",
    strataValues, strataOrder,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "currencies" or tile.type == "currencies" then
            return tile.strata or "MEDIUM"
          end
        end
      end
      return "MEDIUM"
    end,
    function(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "currencies" or tile.type == "currencies" then
            tile.strata = value
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Set the frame strata (layer) for currencies"
  )
  currencyTab.strataDropdown = strataDropdown
  yOffsetCurr = yOffsetCurr - strataHeight - 10
  currencyTab._currencyListStartY = yOffsetCurr  -- Save for PopulateCurrencies

  -- Function to populate currency checkboxes
  local function PopulateCurrencies()
    -- Clear existing currency checkboxes (but keep hideLabelCheck and position sliders)
    for _, child in ipairs({scrollChild:GetChildren()}) do
      if child._isCurrencyCheck then
        child:Hide()
        child:SetParent(nil)
      end
    end

    if not SkyInfoTilesDB.currencySettings then
      SkyInfoTilesDB.currencySettings = {}
    end

    local CURRENCIES = SkyInfoTiles.GetCurrencyList and SkyInfoTiles.GetCurrencyList() or {}

    local y = currencyTab._currencyListStartY or -10
    local function CreateCurrencyCheck(entry, index)
      if entry.separator then
        -- Separator line with section header
        if entry.label then
          local _, headerH = W:CreateSectionHeader(scrollChild, y, entry.label)
          y = y - headerH - 5
        else
          local line = scrollChild:CreateTexture(nil, "ARTWORK")
          line:SetColorTexture(0.5, 0.5, 0.5, 0.6)
          line:SetSize(550, 2)
          line:SetPoint("TOPLEFT", 10, y - 10)
          line._isCurrencyCheck = true
          y = y - 25
        end
        return
      end

      local key = entry.id or entry.itemID

      -- Load saved state (default = true for all)
      if not SkyInfoTilesDB.currencySettings then
        SkyInfoTilesDB.currencySettings = {}
      end
      local enabled = SkyInfoTilesDB.currencySettings[key]
      if enabled == nil then
        enabled = true
        SkyInfoTilesDB.currencySettings[key] = true
      end

      -- Create toggle
      local row, h = W:CreateToggle(scrollChild, y, entry.label or ("Currency " .. tostring(key)),
        function()
          return SkyInfoTilesDB.currencySettings[key]
        end,
        function(val)
          SkyInfoTilesDB.currencySettings[key] = val
          if SkyInfoTiles.RefreshCurrencyTile then
            SkyInfoTiles.RefreshCurrencyTile()
          end
        end,
        entry.tooltip or ("Toggle " .. (entry.label or "currency"))
      )
      row._isCurrencyCheck = true

      y = y - h
    end

    for i, entry in ipairs(CURRENCIES) do
      CreateCurrencyCheck(entry, i)
    end

    scrollChild:SetHeight(math.abs(y) + 20)
  end

  currencyTab.Populate = PopulateCurrencies

  -- Select All / Deselect All buttons
  local selectAllBtn = CreateFrame("Button", nil, currencyTab, "UIPanelButtonTemplate")
  selectAllBtn:SetSize(120, 25)
  selectAllBtn:SetPoint("BOTTOMLEFT", 10, 10)
  selectAllBtn:SetText("Select All")
  selectAllBtn:SetScript("OnClick", function()
    -- Initialize if needed
    SkyInfoTilesDB.currencySettings = SkyInfoTilesDB.currencySettings or {}

    local CURRENCIES = SkyInfoTiles.GetCurrencyList and SkyInfoTiles.GetCurrencyList() or {}
    for _, entry in ipairs(CURRENCIES) do
      if not entry.separator then
        SkyInfoTilesDB.currencySettings[entry.id] = true
      end
    end
    PopulateCurrencies()
    -- Force full rebuild
    if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
      SkyInfoTiles.Rebuild()
      SkyInfoTiles.UpdateAll()
    end
  end)

  local deselectAllBtn = CreateFrame("Button", nil, currencyTab, "UIPanelButtonTemplate")
  deselectAllBtn:SetSize(120, 25)
  deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 20, 0)
  deselectAllBtn:SetText("Deselect All")
  deselectAllBtn:SetScript("OnClick", function()
    -- Initialize if needed
    SkyInfoTilesDB.currencySettings = SkyInfoTilesDB.currencySettings or {}

    local CURRENCIES = SkyInfoTiles.GetCurrencyList and SkyInfoTiles.GetCurrencyList() or {}
    for _, entry in ipairs(CURRENCIES) do
      if not entry.separator then
        SkyInfoTilesDB.currencySettings[entry.id] = false
      end
    end
    PopulateCurrencies()
    -- Force full rebuild
    if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
      SkyInfoTiles.Rebuild()
      SkyInfoTiles.UpdateAll()
    end
  end)

  -- Initial populate (only happens once when tab is created)
  PopulateCurrencies()

  -- === TAB 3: KEYSTONE (with full settings) ===
  local keystoneTab, keystoneYOffset = CreateStandardTab(contentArea, tabContent, 3, "keystone", "Mythic Keystone", "Display your active Mythic+ keystone")

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, keystoneTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, keystoneYOffset)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 800)
  scrollFrame:SetScrollChild(scrollChild)

  keystoneTab.scrollFrame = scrollFrame
  keystoneTab.scrollChild = scrollChild

  local yOffset = -10

  -- ========== SCALE ==========
  local scaleRow, scaleH = W:CreateSlider(scrollChild, yOffset, "Tile Scale", 0.5, 2.0, 0.01,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            return tile.scale or 1.0
          end
        end
      end
      return 1.0
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.scale = val
            if SkyInfoTiles.UpdateAll then
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Adjust the size of the keystone tile (0.5 = 50%, 2.0 = 200%)"
  )
  keystoneTab.scaleRow = scaleRow
  yOffset = yOffset - scaleH

  -- Dummy to keep old reference

  -- ========== POSITION (X coordinate) ==========
  local xPosRow, heightUsed, xPosSlider = W:CreateSlider(scrollChild, yOffset, "X Position:", -3000, 5000, 1,
    function() -- getValue
      local xPos = 0
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            xPos = tile.x or 0
            break
          end
        end
      end
      return xPos
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.point = "TOPLEFT"
            tile.x = val
            if SkyInfoTiles.Rebuild then
              SkyInfoTiles.Rebuild()
            end
            break
          end
        end
      end
    end,
    "Adjust the horizontal position of the keystone tile"
  )
  keystoneTab.xPosSlider = xPosSlider
  yOffset = yOffset - heightUsed - 10

  -- ========== POSITION (Y coordinate) ==========
  local yPosRow, yHeightUsed, yPosSlider = W:CreateSlider(scrollChild, yOffset, "Y Position:", -3000, 3000, 1,
    function() -- getValue
      local yPos = 0
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            yPos = tile.y or 0
            break
          end
        end
      end
      return yPos
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.point = "TOPLEFT"
            tile.y = val
            if SkyInfoTiles.Rebuild then
              SkyInfoTiles.Rebuild()
            end
            break
          end
        end
      end
    end,
    "Adjust the vertical position of the keystone tile"
  )
  keystoneTab.yPosSlider = yPosSlider
  yOffset = yOffset - yHeightUsed - 10

  -- Reset Position button
  local resetPosBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  resetPosBtn:SetSize(120, 25)
  resetPosBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetPosBtn:SetText("Reset Position")
  resetPosBtn:SetScript("OnClick", function()
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          -- Center on screen with TOPLEFT anchor
          local screenWidth = math.floor((GetScreenWidth and GetScreenWidth() or 1920) + 0.5)
          local screenHeight = math.floor((GetScreenHeight and GetScreenHeight() or 1080) + 0.5)

          tile.x = screenWidth / 2
          tile.y = -screenHeight / 2

          -- Update sliders
          xPosSlider:SetValue(tile.x)
          xPosEditBox:SetText(tostring(math.floor(tile.x)))
          yPosSlider:SetValue(tile.y)
          yPosEditBox:SetText(tostring(math.floor(tile.y)))
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          break
        end
      end
    end
  end)

  yOffset = yOffset - 35

  -- ========== STRATA ==========
  local strataValues = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP"
  }
  local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

  local strataRow, strataHeight, strataDropdown = W:CreateDropdown(scrollChild, yOffset, "Frame Strata",
    strataValues, strataOrder,
    function()
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          return tile.strata or "MEDIUM"
        end
      end
      return "MEDIUM"
    end,
    function(value)
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          tile.strata = value
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end,
    "Set the frame strata (layer) for the keystone tile"
  )
  keystoneTab.strataDropdown = strataDropdown
  yOffset = yOffset - strataHeight - 10

  -- ========== BACKGROUND ==========
  local _, bgHeaderH = W:CreateSectionHeader(scrollChild, yOffset, "Background")
  yOffset = yOffset - bgHeaderH - 10

  -- Show Background toggle
  local bgEnableRow, bgH1 = W:CreateToggle(scrollChild, yOffset, "Show Background",
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            return tile.showBackground
          end
        end
      end
      return false
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.showBackground = val
            if SkyInfoTiles.UpdateAll then
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Display a background behind the keystone"
  )
  keystoneTab.bgEnableRow = bgEnableRow
  yOffset = yOffset - bgH1

  -- Use Class Color toggle
  local useClassColorRow, bgH2 = W:CreateToggle(scrollChild, yOffset, "Use Class Color",
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            return tile.useClassColor
          end
        end
      end
      return false
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.useClassColor = val
            if SkyInfoTiles.UpdateAll then
              SkyInfoTiles.UpdateAll()
            end
            -- Update UI state
            if keystoneTab.bgColorButton then
              if val then
                keystoneTab.bgColorButton:Disable()
                if keystoneTab.bgColorLabel then
                  keystoneTab.bgColorLabel:SetTextColor(0.5, 0.5, 0.5, 1)
                end
              else
                keystoneTab.bgColorButton:Enable()
                if keystoneTab.bgColorLabel then
                  keystoneTab.bgColorLabel:SetTextColor(1, 1, 1, 1)
                end
              end
            end
            break
          end
        end
      end
    end,
    "Use your class color for background"
  )
  keystoneTab.useClassColorRow = useClassColorRow
  yOffset = yOffset - bgH2

  -- Background color picker
  yOffset = yOffset - 10
  local bgColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bgColorLabel:SetPoint("TOPLEFT", 10, yOffset)
  bgColorLabel:SetText("Background Color:")

  local bgColorButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  bgColorButton:SetSize(120, 25)
  bgColorButton:SetPoint("TOPLEFT", bgColorLabel, "BOTTOMLEFT", 0, -5)
  bgColorButton:SetText("Choose Color")

  local bgColorSwatch = bgColorButton:CreateTexture(nil, "OVERLAY")
  bgColorSwatch:SetSize(16, 16)
  bgColorSwatch:SetPoint("LEFT", bgColorButton, "RIGHT", 5, 0)
  bgColorSwatch:SetColorTexture(0, 0, 0, 0.8)
  keystoneTab.bgColorSwatch = bgColorSwatch

  keystoneTab.bgColorLabel = bgColorLabel
  keystoneTab.bgColorButton = bgColorButton

  bgColorButton:SetScript("OnClick", function(self)
    local currentColor = { r = 0, g = 0, b = 0, a = 0.8 }
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          if tile.backgroundColor then
            currentColor = tile.backgroundColor
          end
          break
        end
      end
    end

    local lastUpdateTime = 0
    local function OnColorChanged()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = 1
      if ColorPickerFrame.GetColorAlpha then
        a = ColorPickerFrame:GetColorAlpha()
      end

      bgColorSwatch:SetColorTexture(r, g, b, a)

      -- Throttle updates to max 10 per second
      local now = GetTime and GetTime() or 0
      if (now - lastUpdateTime) < 0.1 then
        return
      end
      lastUpdateTime = now

      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.backgroundColor = { r = r, g = g, b = b, a = a }
            if SkyInfoTiles.UpdateAll then
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
      local info = {
        r = currentColor.r,
        g = currentColor.g,
        b = currentColor.b,
        opacity = currentColor.a,
        hasOpacity = true,
        swatchFunc = OnColorChanged,
        opacityFunc = OnColorChanged,
        cancelFunc = function()
          bgColorSwatch:SetColorTexture(currentColor.r, currentColor.g, currentColor.b, currentColor.a)
          if SkyInfoTiles.GetActiveTiles then
            local tiles = SkyInfoTiles.GetActiveTiles()
            for _, tile in ipairs(tiles) do
              if tile.key == "keystone" or tile.type == "keystone" then
                tile.backgroundColor = currentColor
                if SkyInfoTiles.UpdateAll then
                  SkyInfoTiles.UpdateAll()
                end
                break
              end
            end
          end
        end,
      }
      ColorPickerFrame:SetupColorPickerAndShow(info)
    else
      if ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(currentColor.r, currentColor.g, currentColor.b)
      end
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnColorChanged
      ColorPickerFrame.hasOpacity = true
      ColorPickerFrame.opacity = currentColor.a
      ColorPickerFrame.previousValues = { currentColor.r, currentColor.g, currentColor.b, currentColor.a }
      ColorPickerFrame.cancelFunc = function(prev)
        local r, g, b, a = prev[1], prev[2], prev[3], prev[4]
        bgColorSwatch:SetColorTexture(r, g, b, a)
        if SkyInfoTiles.GetActiveTiles then
          local tiles = SkyInfoTiles.GetActiveTiles()
          for _, tile in ipairs(tiles) do
            if tile.key == "keystone" or tile.type == "keystone" then
              tile.backgroundColor = { r = r, g = g, b = b, a = a }
              if SkyInfoTiles.UpdateAll then
                SkyInfoTiles.UpdateAll()
              end
              break
            end
          end
        end
      end
      ColorPickerFrame:Show()
    end
  end)

  yOffset = yOffset - 170

  -- ========== BORDER ==========
  local _, borderHeaderH = W:CreateSectionHeader(scrollChild, yOffset, "Border")
  yOffset = yOffset - borderHeaderH - 10

  -- Show Border toggle
  local borderEnableRow, borderH1 = W:CreateToggle(scrollChild, yOffset, "Show Border",
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            return tile.showBorder
          end
        end
      end
      return false
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.showBorder = val
            if SkyInfoTiles.UpdateAll then
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Display a border around the keystone"
  )
  keystoneTab.borderEnableRow = borderEnableRow
  yOffset = yOffset - borderH1 - 10

  -- Border color picker
  local borderColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  borderColorLabel:SetPoint("TOPLEFT", 10, yOffset)
  borderColorLabel:SetText("Border Color:")

  local borderColorButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  borderColorButton:SetSize(120, 25)
  borderColorButton:SetPoint("TOPLEFT", borderColorLabel, "BOTTOMLEFT", 0, -5)
  borderColorButton:SetText("Choose Color")

  local borderColorSwatch = borderColorButton:CreateTexture(nil, "OVERLAY")
  borderColorSwatch:SetSize(16, 16)
  borderColorSwatch:SetPoint("LEFT", borderColorButton, "RIGHT", 5, 0)
  borderColorSwatch:SetColorTexture(1, 1, 1, 1)
  keystoneTab.borderColorSwatch = borderColorSwatch

  borderColorButton:SetScript("OnClick", function(self)
    local currentColor = { r = 1, g = 1, b = 1, a = 1 }
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          if tile.borderColor then
            currentColor = tile.borderColor
          end
          break
        end
      end
    end

    local lastBorderUpdateTime = 0
    local function OnColorChanged()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = 1
      if ColorPickerFrame.GetColorAlpha then
        a = ColorPickerFrame:GetColorAlpha()
      end

      borderColorSwatch:SetColorTexture(r, g, b, a)

      -- Throttle updates to max 10 per second
      local now = GetTime and GetTime() or 0
      if (now - lastBorderUpdateTime) < 0.1 then
        return
      end
      lastBorderUpdateTime = now

      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.borderColor = { r = r, g = g, b = b, a = a }
            if SkyInfoTiles.UpdateAll then
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
      local info = {
        r = currentColor.r,
        g = currentColor.g,
        b = currentColor.b,
        opacity = currentColor.a,
        hasOpacity = true,
        swatchFunc = OnColorChanged,
        opacityFunc = OnColorChanged,
        cancelFunc = function()
          borderColorSwatch:SetColorTexture(currentColor.r, currentColor.g, currentColor.b, currentColor.a)
          if SkyInfoTiles.GetActiveTiles then
            local tiles = SkyInfoTiles.GetActiveTiles()
            for _, tile in ipairs(tiles) do
              if tile.key == "keystone" or tile.type == "keystone" then
                tile.borderColor = currentColor
                if SkyInfoTiles.UpdateAll then
                  SkyInfoTiles.UpdateAll()
                end
                break
              end
            end
          end
        end,
      }
      ColorPickerFrame:SetupColorPickerAndShow(info)
    else
      if ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(currentColor.r, currentColor.g, currentColor.b)
      end
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnColorChanged
      ColorPickerFrame.hasOpacity = true
      ColorPickerFrame.opacity = currentColor.a
      ColorPickerFrame.previousValues = { currentColor.r, currentColor.g, currentColor.b, currentColor.a }
      ColorPickerFrame.cancelFunc = function(prev)
        local r, g, b, a = prev[1], prev[2], prev[3], prev[4]
        borderColorSwatch:SetColorTexture(r, g, b, a)
        if SkyInfoTiles.GetActiveTiles then
          local tiles = SkyInfoTiles.GetActiveTiles()
          for _, tile in ipairs(tiles) do
            if tile.key == "keystone" or tile.type == "keystone" then
              tile.borderColor = { r = r, g = g, b = b, a = a }
              if SkyInfoTiles.UpdateAll then
                SkyInfoTiles.UpdateAll()
              end
              break
            end
          end
        end
      end
      ColorPickerFrame:Show()
    end
  end)

  -- Border thickness slider (using W:CreateSlider)
  yOffset = yOffset - 170
  local borderThicknessRow, borderThicknessH, borderThicknessSlider = W:CreateSlider(scrollChild, yOffset, "Border Thickness", 1, 10, 1,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            return tile.borderThickness or 2
          end
        end
      end
      return 2
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.borderThickness = val
            if SkyInfoTiles.UpdateAll then
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Border thickness for keystone (1-10)"
  )
  keystoneTab.borderThicknessSlider = borderThicknessSlider
  yOffset = yOffset - borderThicknessH - 10

  -- === TAB 4: CHAR STATS (with stat order customization) ===
  local charStatsTab, charStatsYOffset = CreateStandardTab(contentArea, tabContent, 4, "charstats", "Character Stats", "Display your character's stats (item level, stats, etc.)")

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, charStatsTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, charStatsYOffset)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 900) -- Height will accommodate all controls
  scrollFrame:SetScrollChild(scrollChild)

  charStatsTab.scrollFrame = scrollFrame
  charStatsTab.scrollChild = scrollChild

  local yOffsetChar = -10

  -- Position sliders (X and Y) - inside scroll
  local charStatsPosSliders = CreatePositionSliders(scrollChild, "charstats", "charstats", yOffsetChar)
  charStatsTab.xPosSlider = charStatsPosSliders.xPosSlider
  charStatsTab.xPosEditBox = charStatsPosSliders.xPosEditBox
  charStatsTab.yPosSlider = charStatsPosSliders.yPosSlider
  charStatsTab.yPosEditBox = charStatsPosSliders.yPosEditBox
  yOffsetChar = charStatsPosSliders.newYOffset

  -- ========== STRATA ==========
  local strataValues = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP"
  }
  local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

  local strataRow, strataHeight, strataDropdown = W:CreateDropdown(scrollChild, yOffsetChar, "Frame Strata",
    strataValues, strataOrder,
    function()
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "charstats" or tile.type == "charstats" then
          return tile.strata or "MEDIUM"
        end
      end
      return "MEDIUM"
    end,
    function(value)
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "charstats" or tile.type == "charstats" then
          tile.strata = value
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end,
    "Set the frame strata (layer) for character stats"
  )
  charStatsTab.strataDropdown = strataDropdown
  yOffsetChar = yOffsetChar - strataHeight - 10

  -- Description
  local desc = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  desc:SetPoint("TOPLEFT", 10, yOffsetChar)
  desc:SetTextColor(0.7, 0.7, 0.7, 1)
  desc:SetText("Customize the order of stats displayed:")

  yOffsetChar = yOffsetChar - 25
  charStatsTab._statListStartY = yOffsetChar  -- Save for RebuildStatList

  -- Stat order list
  local STAT_LABELS = {
    ilvl = "Item Level",
    primary = "Primary Stat",
    crit = "Critical Strike",
    haste = "Haste",
    mastery = "Mastery",
    versatility = "Versatility",
  }

  local statRows = {}

  local function GetCurrentOrder()
    local order = { "ilvl", "primary", "crit", "haste", "mastery", "versatility" } -- Default
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "charstats" or tile.type == "charstats" then
          if tile.order and type(tile.order) == "table" and #tile.order == 6 then
            order = tile.order
          end
          break
        end
      end
    end
    return order
  end

  local function SaveOrder(newOrder)
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "charstats" or tile.type == "charstats" then
          tile.order = newOrder
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end

  local function RebuildStatList()
    -- Clear old rows
    for _, row in ipairs(statRows) do
      row:Hide()
      row:SetParent(nil)
    end
    statRows = {}

    local order = GetCurrentOrder()
    local yOffset = charStatsTab._statListStartY or -40

    for i, statKey in ipairs(order) do
      local row = CreateFrame("Frame", nil, scrollChild)
      row:SetSize(500, 30)
      row:SetPoint("TOPLEFT", 10, yOffset)

      -- Stat label
      local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      label:SetPoint("LEFT", 10, 0)
      label:SetText((i) .. ". " .. (STAT_LABELS[statKey] or statKey))
      label:SetTextColor(1, 1, 1, 1)

      -- Up button
      local upBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      upBtn:SetSize(40, 25)
      upBtn:SetPoint("RIGHT", -50, 0)
      upBtn:SetText("Up")
      upBtn:SetEnabled(i > 1) -- Can't move first item up
      upBtn:SetScript("OnClick", function()
        local currentOrder = GetCurrentOrder()
        -- Swap with previous
        currentOrder[i], currentOrder[i-1] = currentOrder[i-1], currentOrder[i]
        SaveOrder(currentOrder)
        RebuildStatList()
      end)

      -- Down button
      local downBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      downBtn:SetSize(50, 25)
      downBtn:SetPoint("RIGHT", -5, 0)
      downBtn:SetText("Down")
      downBtn:SetEnabled(i < #order) -- Can't move last item down
      downBtn:SetScript("OnClick", function()
        local currentOrder = GetCurrentOrder()
        -- Swap with next
        currentOrder[i], currentOrder[i+1] = currentOrder[i+1], currentOrder[i]
        SaveOrder(currentOrder)
        RebuildStatList()
      end)

      row.label = label
      row.upBtn = upBtn
      row.downBtn = downBtn
      table.insert(statRows, row)

      yOffset = yOffset - 35
    end

    -- Reset to default button
    if not scrollChild.resetBtn then
      local resetBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
      resetBtn:SetSize(150, 25)
      resetBtn:SetPoint("TOPLEFT", 10, yOffset - 10)
      resetBtn:SetText("Reset to Default")
      resetBtn:SetScript("OnClick", function()
        local defaultOrder = { "ilvl", "primary", "crit", "haste", "mastery", "versatility" }
        SaveOrder(defaultOrder)
        RebuildStatList()
      end)
      scrollChild.resetBtn = resetBtn
    else
      scrollChild.resetBtn:ClearAllPoints()
      scrollChild.resetBtn:SetPoint("TOPLEFT", 10, yOffset - 10)
    end

    -- Save end position for font controls
    charStatsTab._fontControlsY = yOffset - 50
  end

  charStatsTab.RebuildStatList = RebuildStatList
  RebuildStatList()

  -- Font size controls (positioned below reset button)
  local fontControlsY = charStatsTab._fontControlsY or -330

  -- Display options section
  local _, displayHeaderH = W:CreateSectionHeader(scrollChild, fontControlsY, "Display Options")
  fontControlsY = fontControlsY - displayHeaderH - 10

  -- Hide title toggle
  local hideTitleRow, titleH = W:CreateToggle(scrollChild, fontControlsY, "Hide Title",
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            return tile.hideTitle
          end
        end
      end
      return false
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            tile.hideTitle = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Hide the 'Character Stats' title"
  )
  charStatsTab.hideTitleRow = hideTitleRow
  fontControlsY = fontControlsY - titleH

  -- Show Tertiary Stats toggle
  local showTertiaryRow, tertiaryH = W:CreateToggle(scrollChild, fontControlsY, "Show Tertiary Stats",
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            return tile.showTertiary
          end
        end
      end
      return false
    end,
    function(val)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            tile.showTertiary = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Display tertiary stats (Avoidance, Leech, Speed)"
  )
  charStatsTab.showTertiaryRow = showTertiaryRow
  fontControlsY = fontControlsY - tertiaryH - 10

  -- Title size slider (using W:CreateSlider)
  local titleSizeRow, titleSizeH, titleSizeSlider = W:CreateSlider(scrollChild, fontControlsY, "Title Size", 8, 32, 1,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            return tile.titleSize or 14
          end
        end
      end
      return 14
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            tile.titleSize = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Title font size (8-32)"
  )
  charStatsTab.titleSizeSlider = titleSizeSlider
  fontControlsY = fontControlsY - titleSizeH - 10

  -- Line size slider (using W:CreateSlider)
  local lineSizeRow, lineSizeH, lineSizeSlider = W:CreateSlider(scrollChild, fontControlsY, "Line Size", 6, 24, 1,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            return tile.lineSize or 12
          end
        end
      end
      return 12
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            tile.lineSize = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Line font size (6-24)"
  )
  charStatsTab.lineSizeSlider = lineSizeSlider
  fontControlsY = fontControlsY - lineSizeH - 10

  -- === TAB 5: CROSSHAIR (with size and color options) ===
  local crosshairTab, crosshairYOffset = CreateStandardTab(contentArea, tabContent, 5, "crosshair", "Crosshair", "Display a customizable screen crosshair")

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, crosshairTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, crosshairYOffset) -- Start below checkbox
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 600) -- Height will accommodate all controls
  scrollFrame:SetScrollChild(scrollChild)

  crosshairTab.scrollFrame = scrollFrame
  crosshairTab.scrollChild = scrollChild

  local yOffset = -10

  -- Size slider (using W:CreateSlider)
  local sizeRow, sizeH, sizeSlider = W:CreateSlider(scrollChild, yOffset, "Size", 5, 100, 1,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            return tile.size or 50
          end
        end
      end
      return 50
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            tile.size = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Crosshair size (5-100)"
  )
  crosshairTab.sizeSlider = sizeSlider
  yOffset = yOffset - sizeH - 10

  -- Thickness slider (using W:CreateSlider)
  local thicknessRow, thicknessHeightUsed, thicknessSlider = W:CreateSlider(scrollChild, yOffset, "Thickness", 1, 10, 1,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            return tile.thickness or 5
          end
        end
      end
      return 5
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            tile.thickness = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Line thickness of crosshair (1-10)"
  )
  crosshairTab.thicknessSlider = thicknessSlider
  yOffset = yOffset - thicknessHeightUsed - 10

  -- Color picker label
  local colorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", 10, yOffset)
  colorLabel:SetText("Color:")
  colorLabel:SetTextColor(1, 0.82, 0, 1)

  -- Color picker button
  local colorButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  colorButton:SetSize(120, 25)
  colorButton:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -10)
  colorButton:SetText("Choose Color")

  -- Color preview swatch
  local colorSwatch = colorButton:CreateTexture(nil, "OVERLAY")
  colorSwatch:SetSize(16, 16)
  colorSwatch:SetPoint("LEFT", colorButton, "RIGHT", 5, 0)

  -- Initialize with saved color
  local initColor = { r = 1, g = 0, b = 0, a = 1 }  -- Default red
  if SkyInfoTiles.GetActiveTiles then
    local tiles = SkyInfoTiles.GetActiveTiles()
    for _, tile in ipairs(tiles) do
      if tile.key == "crosshair" or tile.type == "crosshair" then
        if tile.color then
          initColor = tile.color
        end
        break
      end
    end
  end
  colorSwatch:SetColorTexture(initColor.r, initColor.g, initColor.b, initColor.a or 1)
  crosshairTab.colorSwatch = colorSwatch

  colorButton:SetScript("OnClick", function(self)
    -- Get current color
    local currentColor = { r = 1, g = 0, b = 0, a = 0.9 } -- Default
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "crosshair" or tile.type == "crosshair" then
          if tile.color then
            currentColor = tile.color
          end
          break
        end
      end
    end

    -- Callback when color changes
    local function OnColorChanged()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = 1
      if ColorPickerFrame.GetColorAlpha then
        a = ColorPickerFrame:GetColorAlpha()
      end

      -- Update swatch
      colorSwatch:SetColorTexture(r, g, b, a)

      -- Update tile
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            tile.color = { r = r, g = g, b = b, a = a }
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end

    -- Open color picker
    if ColorPickerFrame.SetupColorPickerAndShow then
      -- Modern API (11.0+)
      local info = {
        r = currentColor.r,
        g = currentColor.g,
        b = currentColor.b,
        opacity = currentColor.a,
        hasOpacity = true,
        swatchFunc = OnColorChanged,
        opacityFunc = OnColorChanged,
        cancelFunc = function()
          -- Restore original color on cancel
          colorSwatch:SetColorTexture(currentColor.r, currentColor.g, currentColor.b, currentColor.a)
          if SkyInfoTiles.GetActiveTiles then
            local tiles = SkyInfoTiles.GetActiveTiles()
            for _, tile in ipairs(tiles) do
              if tile.key == "crosshair" or tile.type == "crosshair" then
                tile.color = currentColor
                if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
                  SkyInfoTiles.Rebuild()
                  SkyInfoTiles.UpdateAll()
                end
                break
              end
            end
          end
        end,
      }
      ColorPickerFrame:SetupColorPickerAndShow(info)
    else
      -- Legacy API
      if ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(currentColor.r, currentColor.g, currentColor.b)
      end
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnColorChanged
      ColorPickerFrame.hasOpacity = true
      ColorPickerFrame.opacity = currentColor.a
      ColorPickerFrame.previousValues = { currentColor.r, currentColor.g, currentColor.b, currentColor.a }
      ColorPickerFrame.cancelFunc = function(prev)
        local r, g, b, a = prev[1], prev[2], prev[3], prev[4]
        colorSwatch:SetColorTexture(r, g, b, a)
        if SkyInfoTiles.GetActiveTiles then
          local tiles = SkyInfoTiles.GetActiveTiles()
          for _, tile in ipairs(tiles) do
            if tile.key == "crosshair" or tile.type == "crosshair" then
              tile.color = { r = r, g = g, b = b, a = a }
              if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
                SkyInfoTiles.Rebuild()
                SkyInfoTiles.UpdateAll()
              end
              break
            end
          end
        end
      end
      ColorPickerFrame:Show()
    end
  end)

  yOffset = yOffset - 170

  -- Outline Thickness slider (styled)
  local outlineThicknessRow, outlineThicknessH, outlineThicknessSlider = W:CreateSlider(scrollChild, yOffset, "Outline Thickness", 0, 5, 1,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            return tile.outlineThickness or 2
          end
        end
      end
      return 2
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            tile.outlineThickness = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Outline thickness for crosshair (0=off, 1-5)"
  )
  crosshairTab.outlineThicknessSlider = outlineThicknessSlider
  yOffset = yOffset - outlineThicknessH - 10

  -- Outline color picker label
  local outlineColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  outlineColorLabel:SetPoint("TOPLEFT", 10, yOffset)
  outlineColorLabel:SetText("Outline Color:")
  outlineColorLabel:SetTextColor(1, 0.82, 0, 1)

  -- Outline color picker button
  local outlineColorButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  outlineColorButton:SetSize(120, 25)
  outlineColorButton:SetPoint("TOPLEFT", outlineColorLabel, "BOTTOMLEFT", 0, -10)
  outlineColorButton:SetText("Choose Color")

  -- Outline color preview swatch
  local outlineColorSwatch = outlineColorButton:CreateTexture(nil, "OVERLAY")
  outlineColorSwatch:SetSize(16, 16)
  outlineColorSwatch:SetPoint("LEFT", outlineColorButton, "RIGHT", 5, 0)
  outlineColorSwatch:SetColorTexture(0, 0, 0, 1) -- Default black
  crosshairTab.outlineColorSwatch = outlineColorSwatch

  outlineColorButton:SetScript("OnClick", function(self)
    -- Get current outline color
    local currentColor = { r = 0, g = 0, b = 0, a = 1 } -- Default black
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "crosshair" or tile.type == "crosshair" then
          if tile.outlineColor then
            currentColor = tile.outlineColor
          end
          break
        end
      end
    end

    -- Callback when color changes
    local function OnColorChanged()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = 1
      if ColorPickerFrame.GetColorAlpha then
        a = ColorPickerFrame:GetColorAlpha()
      end

      -- Update swatch
      outlineColorSwatch:SetColorTexture(r, g, b, a)

      -- Update tile
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            tile.outlineColor = { r = r, g = g, b = b, a = a }
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end

    -- Open color picker
    if ColorPickerFrame.SetupColorPickerAndShow then
      -- Modern API (11.0+)
      local info = {
        r = currentColor.r,
        g = currentColor.g,
        b = currentColor.b,
        opacity = currentColor.a,
        hasOpacity = true,
        swatchFunc = OnColorChanged,
        opacityFunc = OnColorChanged,
        cancelFunc = function()
          -- Restore original color on cancel
          outlineColorSwatch:SetColorTexture(currentColor.r, currentColor.g, currentColor.b, currentColor.a)
          if SkyInfoTiles.GetActiveTiles then
            local tiles = SkyInfoTiles.GetActiveTiles()
            for _, tile in ipairs(tiles) do
              if tile.key == "crosshair" or tile.type == "crosshair" then
                tile.outlineColor = currentColor
                if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
                  SkyInfoTiles.Rebuild()
                  SkyInfoTiles.UpdateAll()
                end
                break
              end
            end
          end
        end,
      }
      ColorPickerFrame:SetupColorPickerAndShow(info)
    else
      -- Legacy API
      if ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(currentColor.r, currentColor.g, currentColor.b)
      end
      ColorPickerFrame.func = OnColorChanged
      ColorPickerFrame.opacityFunc = OnColorChanged
      ColorPickerFrame.hasOpacity = true
      ColorPickerFrame.opacity = currentColor.a
      ColorPickerFrame.previousValues = { currentColor.r, currentColor.g, currentColor.b, currentColor.a }
      ColorPickerFrame.cancelFunc = function(prev)
        local r, g, b, a = prev[1], prev[2], prev[3], prev[4]
        outlineColorSwatch:SetColorTexture(r, g, b, a)
        if SkyInfoTiles.GetActiveTiles then
          local tiles = SkyInfoTiles.GetActiveTiles()
          for _, tile in ipairs(tiles) do
            if tile.key == "crosshair" or tile.type == "crosshair" then
              tile.outlineColor = { r = r, g = g, b = b, a = a }
              if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
                SkyInfoTiles.Rebuild()
                SkyInfoTiles.UpdateAll()
              end
              break
            end
          end
        end
      end
      ColorPickerFrame:Show()
    end
  end)

  yOffset = yOffset - 120  -- Account for outline color label + button + spacing

  -- ========== STRATA ==========
  local strataValues = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP"
  }
  local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

  local strataRow, strataHeight, strataDropdown = W:CreateDropdown(scrollChild, yOffset, "Frame Strata",
    strataValues, strataOrder,
    function()
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "crosshair" or tile.type == "crosshair" then
          return tile.strata or "MEDIUM"
        end
      end
      return "MEDIUM"
    end,
    function(value)
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "crosshair" or tile.type == "crosshair" then
          tile.strata = value
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end,
    "Set the frame strata (layer) for the crosshair"
  )
  crosshairTab.strataDropdown = strataDropdown
  yOffset = yOffset - strataHeight - 10

  -- === TAB 6: CLOCK (with font and size options) ===
  local clockTab, clockYOffset = CreateStandardTab(contentArea, tabContent, 6, "clock", "24h Clock", "Display a 24-hour clock")

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, clockTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, clockYOffset)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 800)
  scrollFrame:SetScrollChild(scrollChild)

  clockTab.scrollFrame = scrollFrame
  clockTab.scrollChild = scrollChild

  -- Position sliders (X and Y)
  local yOffsetClock = -10
  local clockPosSliders = CreatePositionSliders(scrollChild, "clock", "clock", yOffsetClock)
  clockTab.xPosSlider = clockPosSliders.xPosSlider
  clockTab.xPosEditBox = clockPosSliders.xPosEditBox
  clockTab.yPosSlider = clockPosSliders.yPosSlider
  clockTab.yPosEditBox = clockPosSliders.yPosEditBox
  yOffsetClock = clockPosSliders.newYOffset

  -- ========== STRATA ==========
  local strataValues = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP"
  }
  local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

  local strataRow, strataHeight, strataDropdown = W:CreateDropdown(scrollChild, yOffsetClock, "Frame Strata",
    strataValues, strataOrder,
    function()
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "clock" or tile.type == "clock" then
          return tile.strata or "MEDIUM"
        end
      end
      return "MEDIUM"
    end,
    function(value)
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "clock" or tile.type == "clock" then
          tile.strata = value
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end,
    "Set the frame strata (layer) for the clock"
  )
  clockTab.strataDropdown = strataDropdown
  yOffsetClock = yOffsetClock - strataHeight - 10

  -- Font dropdown
  -- Use global font discovery
  local function DiscoverFonts()
    if SkyInfoTiles.Utils and SkyInfoTiles.Utils.DiscoverFonts then
      return SkyInfoTiles.Utils.DiscoverFonts()
    end
    -- Fallback to basic fonts
    return {
      { path = "Fonts\\FRIZQT__.ttf", name = "Friz Quadrata (Default)" },
      { path = "Fonts\\ARIALN.ttf", name = "Arial Narrow" },
      { path = "Fonts\\MORPHEUS.ttf", name = "Morpheus" },
      { path = "Fonts\\skurri.ttf", name = "Skurri" },
      { path = "Fonts\\theboldfont.ttf", name = "Bold Font" },
    }
  end

  local fonts = DiscoverFonts()
  local fontValues = {}
  local fontOrder = {}
  for _, fontInfo in ipairs(fonts) do
    fontValues[fontInfo.path] = fontInfo.name
    table.insert(fontOrder, fontInfo.path)
  end

  local fontRow, fontHeight, fontDropdown = W:CreateDropdown(scrollChild, yOffsetClock, "Font",
    fontValues, fontOrder,
    function()
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "clock" or tile.type == "clock" then
          return tile.font or "Fonts\\FRIZQT__.ttf"
        end
      end
      return "Fonts\\FRIZQT__.ttf"
    end,
    function(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "clock" or tile.type == "clock" then
            tile.font = value
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Choose the font for the clock display"
  )
  clockTab.fontDropdown = fontDropdown
  clockTab.GetFontOptions = DiscoverFonts -- Store reference for refresh
  yOffsetClock = yOffsetClock - fontHeight - 10

  local sliderRow, heightUsed, sliderRef = W:CreateSlider(scrollChild, yOffsetClock, "Font Size", 8, 48, 1,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "clock" or tile.type == "clock" then
            return tile.fontSize or 28
          end
        end
      end
      return 28
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "clock" or tile.type == "clock" then
            tile.fontSize = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Font size for clock display (8-48)"
  )
  yOffsetClock = yOffsetClock - heightUsed - 10
  clockTab.sizeSlider = sliderRef

  -- === TAB 7: DUNGEON PORTS (with orientation option) ===
  local dungeonTab, dungeonYOffset = CreateStandardTab(contentArea, tabContent, 7, "dungeonports", "Dungeon Teleports", "Quick access to dungeon teleports")

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, dungeonTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, dungeonYOffset)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 800)
  scrollFrame:SetScrollChild(scrollChild)

  dungeonTab.scrollFrame = scrollFrame
  dungeonTab.scrollChild = scrollChild

  -- Position sliders (X and Y)
  local yOffsetDungeon = -10
  local dungeonPosSliders = CreatePositionSliders(scrollChild, "dungeonports", "dungeonports", yOffsetDungeon)
  dungeonTab.xPosSlider = dungeonPosSliders.xPosSlider
  dungeonTab.xPosEditBox = dungeonPosSliders.xPosEditBox
  dungeonTab.yPosSlider = dungeonPosSliders.yPosSlider
  dungeonTab.yPosEditBox = dungeonPosSliders.yPosEditBox
  yOffsetDungeon = dungeonPosSliders.newYOffset

  -- Orientation dropdown (horizontal/vertical)
  local orientationValues = {
    horizontal = "Horizontal",
    vertical = "Vertical"
  }
  local orientationOrder = { "horizontal", "vertical" }

  local orientRow, orientHeight, orientDropdown = W:CreateDropdown(scrollChild, yOffsetDungeon, "Layout Orientation",
    orientationValues, orientationOrder,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "dungeonports" or tile.type == "dungeonports" then
            return tile.orientation or "horizontal"
          end
        end
      end
      return "horizontal"
    end,
    function(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "dungeonports" or tile.type == "dungeonports" then
            tile.orientation = value
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Choose horizontal or vertical layout for dungeon teleports"
  )
  dungeonTab.orientDropdown = orientDropdown
  yOffsetDungeon = yOffsetDungeon - orientHeight - 10

  -- ========== STRATA ==========
  local strataValues = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP"
  }
  local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

  local strataRow, strataHeight, strataDropdown = W:CreateDropdown(scrollChild, yOffsetDungeon, "Frame Strata",
    strataValues, strataOrder,
    function()
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "dungeonports" or tile.type == "dungeonports" then
          return tile.strata or "MEDIUM"
        end
      end
      return "MEDIUM"
    end,
    function(value)
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "dungeonports" or tile.type == "dungeonports" then
          tile.strata = value
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end,
    "Set the frame strata (layer) for dungeon teleports"
  )
  dungeonTab.strataDropdown = strataDropdown
  yOffsetDungeon = yOffsetDungeon - strataHeight - 10

  -- Call continuation function to avoid 200 local variable limit
  CreateOptionsWindow_Part2(contentArea, tabContent, f, tabs)

  return f
end

-- Continuation of CreateOptionsWindow (to avoid 200 local variable limit)
CreateOptionsWindow_Part2 = function(contentArea, tabContent, f, tabs)
  -- === TAB 8: BUFFTRACKER ===
  local buffTrackerTab, buffTrackerYOffset = CreateStandardTab(contentArea, tabContent, 8, "bufftracker", "Buff Tracker", "Track important buffs and debuffs")

  -- Scroll frame for buff list
  local scrollFrame = CreateFrame("ScrollFrame", nil, buffTrackerTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, buffTrackerYOffset)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 45)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 1)
  scrollFrame:SetScrollChild(scrollChild)

  buffTrackerTab.scrollFrame = scrollFrame
  buffTrackerTab.scrollChild = scrollChild

  local yOffsetBuff = -10

  -- Position sliders
  local buffPosSliders = CreatePositionSliders(scrollChild, "bufftracker", "bufftracker", yOffsetBuff)
  buffTrackerTab.xPosSlider = buffPosSliders.xPosSlider
  buffTrackerTab.xPosEditBox = buffPosSliders.xPosEditBox
  buffTrackerTab.yPosSlider = buffPosSliders.yPosSlider
  buffTrackerTab.yPosEditBox = buffPosSliders.yPosEditBox
  yOffsetBuff = buffPosSliders.newYOffset

  yOffsetBuff = yOffsetBuff - 20

  -- Strata dropdown
  local strataValues = {
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP"
  }
  local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

  local strataRow, strataHeight, strataDropdown = W:CreateDropdown(scrollChild, yOffsetBuff, "Frame Strata (Layer)",
    strataValues, strataOrder,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            return tile.strata or "MEDIUM"
          end
        end
      end
      return "MEDIUM"
    end,
    function(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            tile.strata = value
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Set the frame strata (layer) for buff tracker"
  )
  buffTrackerTab.strataDropdown = strataDropdown
  yOffsetBuff = yOffsetBuff - strataHeight - 10

  -- Preview icon (shows what the tile looks like) - positioned first
  local previewFrame = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
  previewFrame:SetSize(80, 80)
  previewFrame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -30, yOffsetBuff + 10)
  previewFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  previewFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
  previewFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

  local previewIcon = previewFrame:CreateTexture(nil, "ARTWORK")
  previewIcon:SetPoint("CENTER")
  previewIcon:SetSize(32, 32)
  previewIcon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
  previewIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local previewText = previewFrame:CreateFontString(nil, "OVERLAY")
  previewText:SetPoint("BOTTOM", previewIcon, "BOTTOM", 0, 2)
  previewText:SetFont("Fonts\\FRIZQT__.ttf", 10, "OUTLINE")
  previewText:SetText("45m")
  previewText:SetTextColor(1, 1, 1, 1)
  previewText:SetShadowColor(0, 0, 0, 1)
  previewText:SetShadowOffset(1, -1)

  -- Icon Size slider
  -- Icon Size slider (styled)
  local iconSizeRow, iconSizeH, iconSizeSlider = W:CreateSlider(scrollChild, yOffsetBuff, "Icon Size", 16, 64, 2,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            return tile.iconSize or 32
          end
        end
      end
      return 32
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            tile.iconSize = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            if buffTrackerTab.UpdatePreview then
              buffTrackerTab.UpdatePreview()
            end
            break
          end
        end
      end
    end,
    "Size of buff icons (16-64)"
  )
  buffTrackerTab.iconSizeSlider = iconSizeSlider
  yOffsetBuff = yOffsetBuff - iconSizeH - 10

  -- Font Size slider (styled)
  local fontSizeRow, fontSizeH = W:CreateSlider(scrollChild, yOffsetBuff, "Time Font Size", 8, 32, 1,
    function() -- getValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            return tile.fontSize or 14
          end
        end
      end
      return 14
    end,
    function(val) -- setValue
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            tile.fontSize = val
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            if buffTrackerTab.UpdatePreview then
              buffTrackerTab.UpdatePreview()
            end
            break
          end
        end
      end
    end,
    "Font size for buff timer text (8-32)"
  )
  yOffsetBuff = yOffsetBuff - fontSizeH - 10

  -- Font dropdown
  local function DiscoverFonts()
    if SkyInfoTiles.Utils and SkyInfoTiles.Utils.DiscoverFonts then
      return SkyInfoTiles.Utils.DiscoverFonts()
    end
    -- Fallback to basic fonts
    return {
      { path = "Fonts\\FRIZQT__.ttf", name = "Friz Quadrata (Default)" },
      { path = "Fonts\\ARIALN.ttf", name = "Arial Narrow" },
      { path = "Fonts\\MORPHEUS.ttf", name = "Morpheus" },
      { path = "Fonts\\skurri.ttf", name = "Skurri" },
      { path = "Fonts\\theboldfont.ttf", name = "Bold Font" },
    }
  end

  local fonts = DiscoverFonts()
  local fontValues = {}
  local fontOrder = {}
  for _, fontInfo in ipairs(fonts) do
    fontValues[fontInfo.path] = fontInfo.name
    table.insert(fontOrder, fontInfo.path)
  end

  local fontRow, fontHeight, fontDropdown = W:CreateDropdown(scrollChild, yOffsetBuff, "Time Font",
    fontValues, fontOrder,
    function()
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "bufftracker" or tile.type == "bufftracker" then
          return tile.font or "Fonts\\FRIZQT__.ttf"
        end
      end
      return "Fonts\\FRIZQT__.ttf"
    end,
    function(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            tile.font = value
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            if buffTrackerTab.UpdatePreview then
              buffTrackerTab.UpdatePreview()
            end
            break
          end
        end
      end
    end,
    "Choose the font for buff timer text"
  )
  buffTrackerTab.fontDropdown = fontDropdown
  yOffsetBuff = yOffsetBuff - fontHeight - 10

  -- Direction dropdown
  local directionValues = {
    right = "right",
    left = "left",
    down = "down",
    up = "up"
  }
  local directionOrder = { "right", "left", "down", "up" }

  local directionRow, directionHeight, directionDropdown = W:CreateDropdown(scrollChild, yOffsetBuff, "Icon Direction",
    directionValues, directionOrder,
    function()
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            return tile.direction or "right"
          end
        end
      end
      return "right"
    end,
    function(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "bufftracker" or tile.type == "bufftracker" then
            tile.direction = value
            if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
              SkyInfoTiles.Rebuild()
              SkyInfoTiles.UpdateAll()
            end
            break
          end
        end
      end
    end,
    "Choose which direction icons expand in"
  )
  buffTrackerTab.directionDropdown = directionDropdown
  yOffsetBuff = yOffsetBuff - directionHeight - 10

  -- Function to update preview based on current settings
  local function UpdatePreview()
    local iconSize = 32
    local fontSize = 10
    local font = "Fonts\\FRIZQT__.ttf"

    -- Get current settings from tile config
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "bufftracker" or tile.type == "bufftracker" then
          fontSize = tile.fontSize or 14
          font = tile.font or "Fonts\\FRIZQT__.ttf"
          iconSize = tile.iconSize or 32
          break
        end
      end
    end

    -- Update preview frame size to fit icon + padding
    local frameSize = math.min(80, iconSize + 16)
    previewFrame:SetSize(frameSize, frameSize)

    -- Update preview icon size (cap at 64 to fit in frame)
    local displayIconSize = math.min(64, iconSize)
    previewIcon:SetSize(displayIconSize, displayIconSize)

    -- Update preview text font
    pcall(previewText.SetFont, previewText, font, fontSize, "OUTLINE")
  end

  buffTrackerTab.UpdatePreview = UpdatePreview

  -- Buff list header
  local buffListLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  buffListLabel:SetPoint("TOPLEFT", 10, yOffsetBuff)
  buffListLabel:SetText("Tracked Buffs (Spell IDs):")
  buffListLabel:SetTextColor(1, 0.82, 0, 1)
  yOffsetBuff = yOffsetBuff - 30

  -- Add buff button and editbox
  local addBuffLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  addBuffLabel:SetPoint("TOPLEFT", 10, yOffsetBuff)
  addBuffLabel:SetText("Add Buff ID:")
  addBuffLabel:SetTextColor(1, 1, 1, 1)

  local addBuffEditBox = CreateFrame("EditBox", nil, scrollChild)
  addBuffEditBox:SetSize(100, 24)
  addBuffEditBox:SetPoint("LEFT", addBuffLabel, "RIGHT", 10, 0)
  addBuffEditBox:SetAutoFocus(false)
  addBuffEditBox:SetNumeric(true)
  addBuffEditBox:SetFont("Fonts\\FRIZQT__.ttf", 11, "OUTLINE")
  addBuffEditBox:SetTextColor(1, 1, 1)
  addBuffEditBox:SetJustifyH("CENTER")

  -- EditBox background (ultra-dark, matching StyledWidgets)
  local editBg = addBuffEditBox:CreateTexture(nil, "BACKGROUND")
  editBg:SetColorTexture(0.02, 0.03, 0.04, 0.95)
  editBg:SetAllPoints()

  -- EditBox border (subtle white, matching StyledWidgets)
  local editBorder = CreateFrame("Frame", nil, addBuffEditBox)
  editBorder:SetAllPoints()
  local borderTop = editBorder:CreateTexture(nil, "ARTWORK")
  borderTop:SetColorTexture(1, 1, 1, 0.08)
  borderTop:SetPoint("TOPLEFT", 0, 0)
  borderTop:SetPoint("TOPRIGHT", 0, 0)
  borderTop:SetHeight(1)

  local borderBottom = editBorder:CreateTexture(nil, "ARTWORK")
  borderBottom:SetColorTexture(1, 1, 1, 0.08)
  borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
  borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
  borderBottom:SetHeight(1)

  -- Handle text input
  addBuffEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  addBuffEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  local addBuffButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  addBuffButton:SetSize(60, 22)
  addBuffButton:SetPoint("LEFT", addBuffEditBox, "RIGHT", 10, 0)
  addBuffButton:SetText("Add")
  addBuffButton:SetScript("OnClick", function()
    local buffID = tonumber(addBuffEditBox:GetText())
    if buffID and buffID > 0 then
      local list = SkyInfoTiles.GetBuffTrackerList and SkyInfoTiles.GetBuffTrackerList() or {}
      -- Check if already exists
      local exists = false
      for _, id in ipairs(list) do
        if id == buffID then
          exists = true
          break
        end
      end
      if not exists then
        table.insert(list, buffID)
        if SkyInfoTiles.SaveBuffTrackerList then
          SkyInfoTiles.SaveBuffTrackerList(list)
        end
        if buffTrackerTab.RebuildBuffList then
          buffTrackerTab.RebuildBuffList()
        end
        if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
          SkyInfoTiles.Rebuild()
          SkyInfoTiles.UpdateAll()
        end
      end
      addBuffEditBox:SetText("")
    end
  end)

  yOffsetBuff = yOffsetBuff - 40

  -- Buff list container
  buffTrackerTab._buffListStartY = yOffsetBuff
  buffTrackerTab._buffEntries = {}  -- Store all created entries for cleanup

  -- Function to rebuild buff list
  function buffTrackerTab.RebuildBuffList()
    -- Clear existing buff entries properly
    if buffTrackerTab._buffEntries then
      for _, entry in ipairs(buffTrackerTab._buffEntries) do
        if entry.iconFrame then
          entry.iconFrame:Hide()
          entry.iconFrame:SetParent(nil)
        end
        if entry.label then
          entry.label:Hide()
          entry.label:SetText("")
        end
        if entry.upBtn then
          entry.upBtn:Hide()
          entry.upBtn:SetParent(nil)
        end
        if entry.downBtn then
          entry.downBtn:Hide()
          entry.downBtn:SetParent(nil)
        end
        if entry.removeBtn then
          entry.removeBtn:Hide()
          entry.removeBtn:SetParent(nil)
        end
      end
    end
    buffTrackerTab._buffEntries = {}

    local list = SkyInfoTiles.GetBuffTrackerList and SkyInfoTiles.GetBuffTrackerList() or {}
    local y = buffTrackerTab._buffListStartY or -10

    for index, buffID in ipairs(list) do
      local currentIndex = index  -- Capture index for closure
      local entry = {}

      -- Spell icon
      local iconFrame = CreateFrame("Frame", nil, scrollChild)
      iconFrame:SetSize(20, 20)
      iconFrame:SetPoint("TOPLEFT", 20, y)

      local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
      iconTexture:SetAllPoints(iconFrame)
      iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)  -- Crop borders

      -- Get spell info (name and icon)
      local spellName = "Unknown"
      local spellIcon = "Interface\\Icons\\INV_Misc_QuestionMark"

      if C_Spell and C_Spell.GetSpellTexture then
        local icon = C_Spell.GetSpellTexture(buffID)
        if icon then
          spellIcon = icon
        end
      elseif GetSpellTexture then
        local icon = GetSpellTexture(buffID)
        if icon then
          spellIcon = icon
        end
      end

      if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(buffID)
        if name then
          spellName = name
        end
      elseif GetSpellInfo then
        local name = GetSpellInfo(buffID)
        if name then
          spellName = name
        end
      end

      iconTexture:SetTexture(spellIcon)
      entry.iconFrame = iconFrame

      -- Buff ID label with spell name (positioned after icon)
      local buffLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      buffLabel:SetPoint("LEFT", iconFrame, "RIGHT", 5, 0)
      buffLabel:SetText(spellName .. " (" .. tostring(buffID) .. ")")
      entry.label = buffLabel

      -- Up button
      local upBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
      upBtn:SetSize(30, 22)
      upBtn:SetPoint("LEFT", buffLabel, "RIGHT", 10, 0)
      upBtn:SetText("Up")
      upBtn:SetScript("OnClick", function()
        local freshList = SkyInfoTiles.GetBuffTrackerList and SkyInfoTiles.GetBuffTrackerList() or {}
        if currentIndex > 1 and currentIndex <= #freshList then
          freshList[currentIndex], freshList[currentIndex-1] = freshList[currentIndex-1], freshList[currentIndex]
          if SkyInfoTiles.SaveBuffTrackerList then
            SkyInfoTiles.SaveBuffTrackerList(freshList)
          end
          buffTrackerTab.RebuildBuffList()
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
        end
      end)
      if currentIndex == 1 then upBtn:Disable() end
      entry.upBtn = upBtn

      -- Down button
      local downBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
      downBtn:SetSize(40, 22)
      downBtn:SetPoint("LEFT", upBtn, "RIGHT", 5, 0)
      downBtn:SetText("Down")
      downBtn:SetScript("OnClick", function()
        local freshList = SkyInfoTiles.GetBuffTrackerList and SkyInfoTiles.GetBuffTrackerList() or {}
        if currentIndex < #freshList and currentIndex > 0 then
          freshList[currentIndex], freshList[currentIndex+1] = freshList[currentIndex+1], freshList[currentIndex]
          if SkyInfoTiles.SaveBuffTrackerList then
            SkyInfoTiles.SaveBuffTrackerList(freshList)
          end
          buffTrackerTab.RebuildBuffList()
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
        end
      end)
      if currentIndex == #list then downBtn:Disable() end
      entry.downBtn = downBtn

      -- Remove button
      local removeBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
      removeBtn:SetSize(60, 22)
      removeBtn:SetPoint("LEFT", downBtn, "RIGHT", 5, 0)
      removeBtn:SetText("Remove")
      removeBtn:SetScript("OnClick", function()
        local freshList = SkyInfoTiles.GetBuffTrackerList and SkyInfoTiles.GetBuffTrackerList() or {}
        if currentIndex > 0 and currentIndex <= #freshList then
          table.remove(freshList, currentIndex)
          if SkyInfoTiles.SaveBuffTrackerList then
            SkyInfoTiles.SaveBuffTrackerList(freshList)
          end
          buffTrackerTab.RebuildBuffList()
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
        end
      end)
      entry.removeBtn = removeBtn

      table.insert(buffTrackerTab._buffEntries, entry)
      y = y - 30
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.abs(y) + 100)
  end

  -- Initial build
  buffTrackerTab.RebuildBuffList()

  -- === TAB 9: INFOBAR ===
  CreateInfoBarTab(contentArea, tabContent)
  local profilesTab = CreateFrame("Frame", nil, contentArea)
  profilesTab:SetAllPoints()
  profilesTab:Hide()
  tabContent[10] = profilesTab

  -- Background (transparent - let main frame background show through)
  local profilesBg = profilesTab:CreateTexture(nil, "BACKGROUND")
  profilesBg:SetAllPoints()
  profilesBg:SetColorTexture(0, 0, 0, 0)

  -- Add scrollFrame for consistent width
  local scrollFrame = CreateFrame("ScrollFrame", nil, profilesTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 800)
  scrollFrame:SetScrollChild(scrollChild)

  profilesTab.scrollFrame = scrollFrame
  profilesTab.scrollChild = scrollChild

  local yOffset = -10

  -- Character info label
  local charName = UnitName("player") or "Unknown"
  local realmName = GetRealmName() or "Unknown"
  local charKey = charName .. "-" .. realmName

  local charLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  charLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
  charLabel:SetText("Profile for " .. charKey .. ":")
  charLabel:SetTextColor(1, 0.82, 0, 1)
  yOffset = yOffset - 30

  -- Profile selection dropdown (styled)
  -- Build values and order from profile list
  local function GetProfileValues()
    local profiles = SkyInfoTiles.ListProfiles and SkyInfoTiles.ListProfiles() or {"Default"}
    local values = {}
    local order = {}
    for _, name in ipairs(profiles) do
      local displayText = name == "Default" and name .. " (Default)" or name
      values[name] = displayText
      table.insert(order, name)
    end
    return values, order
  end

  local profileValues, profileOrder = GetProfileValues()
  local profileRow, profileHeight, profileDropdown = W:CreateDropdown(scrollChild, yOffset, "Active Profile",
    profileValues, profileOrder,
    function()
      return SkyInfoTiles.GetActiveProfileName and SkyInfoTiles.GetActiveProfileName() or "Default"
    end,
    function(value)
      local success, err = SkyInfoTiles.SetActiveProfile(value)
      if success then
        -- Refresh dropdown to show new profile list (in case it changed)
        local newValues, newOrder = GetProfileValues()
        profileDropdown._values = newValues
        profileDropdown._order = newOrder
        if profileDropdown.Refresh then
          profileDropdown:Refresh()
        end
        if SkyInfoTiles._OptionsRefresh then
          SkyInfoTiles._OptionsRefresh()
        end
      else
        print("|cff66ccffSkyInfoTiles:|r " .. tostring(err))
      end
    end,
    "Select the active profile for this character"
  )

  profilesTab.profileDropdown = profileDropdown
  yOffset = yOffset - profileHeight - 10

  -- Separator
  local sep1 = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sep1:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
  sep1:SetText("-----------------------------------")
  sep1:SetTextColor(0.5, 0.5, 0.5, 1)
  yOffset = yOffset - 30

  -- Manage profiles label
  local manageLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  manageLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
  manageLabel:SetText("Manage Global Profiles:")
  manageLabel:SetTextColor(1, 0.82, 0, 1)
  yOffset = yOffset - 30

  -- Profile list label
  local listLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
  listLabel:SetText("Available Profiles:")
  yOffset = yOffset - 25

  -- Profile list (simple text list)
  local profileListText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  profileListText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
  profileListText:SetJustifyH("LEFT")
  profileListText:SetWidth(300)
  profileListText:SetText("Loading...")
  profilesTab.profileListText = profileListText
  yOffset = yOffset - 100

  -- Profile management buttons
  local buttonY = yOffset

  -- New Profile button
  local newBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  newBtn:SetSize(100, 25)
  newBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, buttonY)
  newBtn:SetText("New")
  newBtn:SetScript("OnClick", function()
    -- Open dialog for new profile
    StaticPopup_Show("SKYINFOTILES_NEW_PROFILE")
  end)

  -- Rename Profile button
  local renameBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  renameBtn:SetSize(100, 25)
  renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 10, 0)
  renameBtn:SetText("Rename")
  renameBtn:SetScript("OnClick", function()
    local activeProfile = SkyInfoTiles.GetActiveProfileName()
    if activeProfile == "Default" then
      print("|cff66ccffSkyInfoTiles:|r Cannot rename Default profile")
      return
    end
    StaticPopup_Show("SKYINFOTILES_RENAME_PROFILE", activeProfile, nil, activeProfile)
  end)

  -- Delete Profile button
  local deleteBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
  deleteBtn:SetSize(100, 25)
  deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 10, 0)
  deleteBtn:SetText("Delete")
  deleteBtn:SetScript("OnClick", function()
    local activeProfile = SkyInfoTiles.GetActiveProfileName()
    if activeProfile == "Default" then
      print("|cff66ccffSkyInfoTiles:|r Cannot delete Default profile")
      return
    end
    StaticPopup_Show("SKYINFOTILES_DELETE_PROFILE", activeProfile, nil, activeProfile)
  end)

  profilesTab.renameBtn = renameBtn
  profilesTab.deleteBtn = deleteBtn

  -- Show first tab by default and layout tabs
  -- Select first button (General) by default
  if SelectSidebarButton then
    SelectSidebarButton(1)
  else
    print("ERROR: SelectSidebarButton is nil!")
    -- Fallback: show first tab content manually
    if tabContent[1] then
      for i, content in ipairs(tabContent) do
        content:Hide()
      end
      tabContent[1]:Show()
    end
  end

  -- Save frame
  optionsFrame = f
  f.sidebarButtons = sidebarButtons
  f.tabContent = tabContent
end

-- Refresh function (called when settings change externally)
local function RefreshOptionsWindow()
  local f = optionsFrame
  if not f then return end

  -- Refresh general tab checkboxes
  if f.tabContent and f.tabContent[1] and f.tabContent[1].lockCheck then
    f.tabContent[1].lockCheck:SetChecked(SkyInfoTilesDB.locked or false)
  end

  -- Refresh hide label checkbox for currencies (skip Populate to avoid triggering tile refresh)
  if f.tabContent and f.tabContent[2] and f.tabContent[2].hideLabelCheck then
    local hideLabel = false
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "currencies" or tile.type == "currencies" then
          hideLabel = tile.hideLabel or false
          break
        end
      end
    end
    f.tabContent[2].hideLabelCheck._programmaticChange = true
    f.tabContent[2].hideLabelCheck:SetChecked(hideLabel)
    f.tabContent[2].hideLabelCheck._programmaticChange = false
  end

  -- Refresh all tile enable checkboxes
  local tileKeys = {
    [2] = "currencies",
    [3] = "keystone",
    [4] = "charstats",
    [5] = "crosshair",
    [6] = "clock",
    [7] = "dungeonports",
    [8] = "bufftracker",
    [9] = "infobar"
  }

  for tabIndex, tileKey in pairs(tileKeys) do
    if f.tabContent and f.tabContent[tabIndex] and f.tabContent[tabIndex].enableCheck then
      local enabled = true -- Default
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileKey or tile.type == tileKey then
            enabled = (tile.enabled ~= false)
            break
          end
        end
      end
      local checkbox = f.tabContent[tabIndex].enableCheck
      checkbox._programmaticChange = true
      checkbox:SetChecked(enabled)
      checkbox._programmaticChange = false
    end
  end

  -- Refresh char stats
  if f.tabContent and f.tabContent[4] and f.tabContent[4].RebuildStatList then
    f.tabContent[4].RebuildStatList()
  end

  -- Refresh keystone settings
  if f.tabContent and f.tabContent[3] then
    local keystoneTab = f.tabContent[3]
    local scale = 1.0
    local showBackground = false
    local useClassColor = false
    local backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    local showBorder = false
    local borderColor = { r = 1, g = 1, b = 1, a = 1 }
    local borderThickness = 2

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          scale = tile.scale or 1.0
          showBackground = tile.showBackground or false
          useClassColor = tile.useClassColor or false
          backgroundColor = tile.backgroundColor or backgroundColor
          showBorder = tile.showBorder or false
          borderColor = tile.borderColor or borderColor
          borderThickness = tile.borderThickness or 2
          break
        end
      end
    end

    if keystoneTab.scaleSlider then
      keystoneTab.scaleSlider:SetValue(scale)
      _G[keystoneTab.scaleSlider:GetName() .. "Text"]:SetText(string.format("%.0f%%", scale * 100))
    end
    if keystoneTab.scaleEditBox then
      keystoneTab.scaleEditBox:SetText(tostring(math.floor(scale * 100)))
    end
    if keystoneTab.xPosSlider and keystoneTab.xPosSlider.Refresh then
      keystoneTab.xPosSlider.Refresh()  -- Use styled slider's Refresh method
    end
    if keystoneTab.yPosSlider and keystoneTab.yPosSlider.Refresh then
      keystoneTab.yPosSlider.Refresh()  -- Use styled slider's Refresh method
    end
    if keystoneTab.bgEnableCheck then
      keystoneTab.bgEnableCheck:SetChecked(showBackground)
    end
    if keystoneTab.useClassColorCheck then
      keystoneTab.useClassColorCheck:SetChecked(useClassColor)
    end
    if keystoneTab.bgColorSwatch then
      keystoneTab.bgColorSwatch:SetColorTexture(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a)
    end
    -- Enable/disable color picker based on useClassColor
    if keystoneTab.bgColorButton then
      if useClassColor then
        keystoneTab.bgColorButton:Disable()
      else
        keystoneTab.bgColorButton:Enable()
      end
    end
    if keystoneTab.bgColorLabel then
      if useClassColor then
        keystoneTab.bgColorLabel:SetTextColor(0.5, 0.5, 0.5, 1)
      else
        keystoneTab.bgColorLabel:SetTextColor(1, 1, 1, 1)
      end
    end
    if keystoneTab.borderEnableCheck then
      keystoneTab.borderEnableCheck:SetChecked(showBorder)
    end
    if keystoneTab.borderColorSwatch then
      keystoneTab.borderColorSwatch:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    end
    if keystoneTab.borderThicknessSlider then
      keystoneTab.borderThicknessSlider:SetValue(borderThickness)
      _G[keystoneTab.borderThicknessSlider:GetName() .. "Text"]:SetText(tostring(borderThickness))
    end
  end

  -- Refresh position sliders for all tiles
  local tilesWithPosition = {
    {index = 2, key = "currencies"},
    {index = 4, key = "charstats"},
    {index = 6, key = "clock"},
    {index = 7, key = "dungeonports"},
    {index = 9, key = "infobar"}
  }

  for _, tileInfo in ipairs(tilesWithPosition) do
    if f.tabContent and f.tabContent[tileInfo.index] then
      local tab = f.tabContent[tileInfo.index]
      local xPos = 0
      local yPos = 0

      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileInfo.key or tile.type == tileInfo.key then
            xPos = tile.x or 0
            yPos = tile.y or 0
            break
          end
        end
      end

      if tab.xPosSlider then
        tab.xPosSlider._programmaticChange = true
        tab.xPosSlider:SetValue(xPos)
        tab.xPosSlider._programmaticChange = false
        _G[tab.xPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(xPos)))
      end
      if tab.xPosEditBox then
        tab.xPosEditBox:SetText(tostring(math.floor(xPos)))
      end
      if tab.yPosSlider then
        tab.yPosSlider._programmaticChange = true
        tab.yPosSlider:SetValue(yPos)
        tab.yPosSlider._programmaticChange = false
        _G[tab.yPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(yPos)))
      end
      if tab.yPosEditBox then
        tab.yPosEditBox:SetText(tostring(math.floor(yPos)))
      end
    end
  end

  -- Refresh strata dropdowns for all tiles
  local tilesWithStrata = {
    {index = 2, key = "currencies"},
    {index = 3, key = "keystone"},
    {index = 4, key = "charstats"},
    {index = 5, key = "crosshair"},
    {index = 6, key = "clock"},
    {index = 7, key = "dungeonports"},
    {index = 9, key = "infobar"}
  }

  for _, tileInfo in ipairs(tilesWithStrata) do
    if f.tabContent and f.tabContent[tileInfo.index] and f.tabContent[tileInfo.index].strataDropdown then
      local dropdown = f.tabContent[tileInfo.index].strataDropdown
      if dropdown.Refresh then
        dropdown:Refresh()
      end
    end
  end

  -- Refresh BuffTracker settings
  if f.tabContent and f.tabContent[8] then
    local buffTrackerTab = f.tabContent[8]
    local xPos = 800
    local yPos = -400
    local iconSize = 32
    local fontSize = 14
    local direction = "right"

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "bufftracker" or tile.type == "bufftracker" then
          xPos = tile.x or 800
          yPos = tile.y or -400
          iconSize = tile.iconSize or 32
          fontSize = tile.fontSize or 14
          direction = tile.direction or "right"
          break
        end
      end
    end

    if buffTrackerTab.xPosSlider then
      buffTrackerTab.xPosSlider._programmaticChange = true
      buffTrackerTab.xPosSlider:SetValue(xPos)
      buffTrackerTab.xPosSlider._programmaticChange = false
      _G[buffTrackerTab.xPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(xPos)))
    end
    if buffTrackerTab.xPosEditBox then
      buffTrackerTab.xPosEditBox:SetText(tostring(math.floor(xPos)))
    end
    if buffTrackerTab.yPosSlider then
      buffTrackerTab.yPosSlider._programmaticChange = true
      buffTrackerTab.yPosSlider:SetValue(yPos)
      buffTrackerTab.yPosSlider._programmaticChange = false
      _G[buffTrackerTab.yPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(yPos)))
    end
    if buffTrackerTab.yPosEditBox then
      buffTrackerTab.yPosEditBox:SetText(tostring(math.floor(yPos)))
    end
    if buffTrackerTab.iconSizeSlider then
      buffTrackerTab.iconSizeSlider._programmaticChange = true
      buffTrackerTab.iconSizeSlider:SetValue(iconSize)
      buffTrackerTab.iconSizeSlider._programmaticChange = false
      _G[buffTrackerTab.iconSizeSlider:GetName() .. "Text"]:SetText(tostring(math.floor(iconSize)))
    end
    if buffTrackerTab.fontSizeSlider then
      buffTrackerTab.fontSizeSlider._programmaticChange = true
      buffTrackerTab.fontSizeSlider:SetValue(fontSize)
      buffTrackerTab.fontSizeSlider._programmaticChange = false
      _G[buffTrackerTab.fontSizeSlider:GetName() .. "Text"]:SetText(tostring(math.floor(fontSize)))
    end
    if buffTrackerTab.UpdatePreview then
      buffTrackerTab.UpdatePreview()
    end
  end

  -- Refresh InfoBar settings (tab 9)
  if f.tabContent and f.tabContent[9] then
    local infobarTab = f.tabContent[9]
    local showGuild = true
    local showLootSpec = true
    local showGold = false
    local showDurability = false
    local showFriends = false
    local showServerName = false
    local showBorder = true
    local onlineSound = "AUCTION_WINDOW_OPEN"
    local soundChannel = "Master"
    local customSound = ""

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "infobar" or tile.type == "infobar" then
          showGuild = (tile.showGuild ~= false)  -- Default: true
          showLootSpec = (tile.showLootSpec ~= false)  -- Default: true
          showGold = (tile.showGold == true)  -- Default: false
          showDurability = (tile.showDurability == true)  -- Default: false
          showFriends = (tile.showFriends == true)  -- Default: false
          showServerName = tile.showServerName or false
          showBorder = (tile.showBorder ~= false)  -- Default: true
          onlineSound = tile.onlineSound or "AUCTION_WINDOW_OPEN"
          soundChannel = tile.onlineSoundChannel or "Master"
          customSound = tile.customOnlineSound or ""
          break
        end
      end
    end

    if infobarTab.showGuildCheck then
      infobarTab.showGuildCheck._programmaticChange = true
      infobarTab.showGuildCheck:SetChecked(showGuild)
      infobarTab.showGuildCheck._programmaticChange = false
    end

    if infobarTab.showLootSpecCheck then
      infobarTab.showLootSpecCheck._programmaticChange = true
      infobarTab.showLootSpecCheck:SetChecked(showLootSpec)
      infobarTab.showLootSpecCheck._programmaticChange = false
    end

    if infobarTab.showGoldCheck then
      infobarTab.showGoldCheck._programmaticChange = true
      infobarTab.showGoldCheck:SetChecked(showGold)
      infobarTab.showGoldCheck._programmaticChange = false
    end

    if infobarTab.showDurabilityCheck then
      infobarTab.showDurabilityCheck._programmaticChange = true
      infobarTab.showDurabilityCheck:SetChecked(showDurability)
      infobarTab.showDurabilityCheck._programmaticChange = false
    end

    if infobarTab.showFriendsCheck then
      infobarTab.showFriendsCheck._programmaticChange = true
      infobarTab.showFriendsCheck:SetChecked(showFriends)
      infobarTab.showFriendsCheck._programmaticChange = false
    end

    if infobarTab.showServerCheck then
      infobarTab.showServerCheck._programmaticChange = true
      infobarTab.showServerCheck:SetChecked(showServerName)
      infobarTab.showServerCheck._programmaticChange = false
    end

    if infobarTab.showBorderCheck then
      infobarTab.showBorderCheck._programmaticChange = true
      infobarTab.showBorderCheck:SetChecked(showBorder)
      infobarTab.showBorderCheck._programmaticChange = false
    end

    -- Refresh sound dropdown
    if infobarTab.soundDropdown and infobarTab.soundDropdown.Refresh then
      infobarTab.soundDropdown:Refresh()
    end

    -- Refresh channel dropdown
    if infobarTab.channelDropdown and infobarTab.channelDropdown.Refresh then
      infobarTab.channelDropdown:Refresh()
    end

    if infobarTab.customSoundEditBox then
      infobarTab.customSoundEditBox:SetText(customSound)
    end
  end

  -- Refresh Profiles tab (tab 10)
  if f.tabContent and f.tabContent[10] then
    local profilesTab = f.tabContent[10]

    -- Update profile dropdown using Refresh method
    if profilesTab.profileDropdown and profilesTab.profileDropdown.Refresh then
      profilesTab.profileDropdown:Refresh()
    end

    -- Update profile list
    if profilesTab.profileListText and SkyInfoTiles.ListProfiles then
      local profiles = SkyInfoTiles.ListProfiles()
      local activeProfile = SkyInfoTiles.GetActiveProfileName()
      local listText = ""
      for _, name in ipairs(profiles) do
        local marker = (name == activeProfile) and "* " or "  "
        local suffix = (name == "Default") and " (Default)" or ""
        listText = listText .. marker .. name .. suffix .. "\n"
      end
      profilesTab.profileListText:SetText(listText)
    end

    -- Enable/disable Rename and Delete buttons based on active profile
    if profilesTab.renameBtn and profilesTab.deleteBtn and SkyInfoTiles.GetActiveProfileName then
      local activeProfile = SkyInfoTiles.GetActiveProfileName()
      local isDefault = (activeProfile == "Default")
      if isDefault then
        profilesTab.renameBtn:Disable()
        profilesTab.deleteBtn:Disable()
      else
        profilesTab.renameBtn:Enable()
        profilesTab.deleteBtn:Enable()
      end
    end
  end
end

-- Export refresh function
SkyInfoTiles._OptionsRefresh = RefreshOptionsWindow

-- Toggle function
function SkyInfoTiles.ToggleOptionsWindow()
  local f = CreateOptionsWindow()
  if f:IsShown() then
    f:Hide()
  else
    -- Refresh all UI elements
    RefreshOptionsWindow()
    f:Show()
  end
end

-- Slash command to open window
SLASH_SKYINFOTILES1 = "/skyinfotiles"
SLASH_SKYINFOTILES2 = "/sit"
SlashCmdList["SKYINFOTILES"] = function()
  SkyInfoTiles.ToggleOptionsWindow()
end
