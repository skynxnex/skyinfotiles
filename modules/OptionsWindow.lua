local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]

-- Custom standalone options window
local optionsFrame = nil

-- Helper function to create X/Y position sliders for a tile
local function CreatePositionSliders(parent, tileKey, tileType, yOffset)
  local scrollChild = parent

  -- ========== POSITION (X coordinate) ==========
  local xPosLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  xPosLabel:SetPoint("TOPLEFT", 10, yOffset)
  xPosLabel:SetText("X Position:")
  xPosLabel:SetTextColor(1, 0.82, 0, 1)

  local xPosSlider = CreateFrame("Slider", "SkyInfoTiles" .. tileKey .. "XPosSlider", scrollChild, "OptionsSliderTemplate")
  xPosSlider:SetPoint("TOPLEFT", xPosLabel, "BOTTOMLEFT", 5, -20)
  xPosSlider:SetWidth(200)
  xPosSlider:SetMinMaxValues(-3000, 3000)
  xPosSlider:SetValueStep(1)
  xPosSlider:SetValue(0)
  xPosSlider:SetObeyStepOnDrag(true)

  _G[xPosSlider:GetName() .. "Low"]:SetText("-3000")
  _G[xPosSlider:GetName() .. "High"]:SetText("3000")
  _G[xPosSlider:GetName() .. "Text"]:SetText("0")

  -- X Position EditBox
  local xPosEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
  xPosEditBox:SetSize(60, 20)
  xPosEditBox:SetPoint("LEFT", xPosSlider, "RIGHT", 15, 0)
  xPosEditBox:SetAutoFocus(false)
  xPosEditBox:SetNumeric(false)
  xPosEditBox:SetText("0")
  xPosEditBox:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
      if value < -3000 then value = -3000 end
      if value > 3000 then value = 3000 end
      self:SetText(tostring(math.floor(value)))
      xPosSlider:SetValue(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileKey or tile.type == tileType then
            tile.point = "CENTER"
            tile.x = value
            if SkyInfoTiles.Rebuild then
              SkyInfoTiles.Rebuild()
            end
            break
          end
        end
      end
    end
    self:ClearFocus()
  end)
  xPosEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  xPosSlider._programmaticChange = false
  xPosSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value)
    _G[self:GetName() .. "Text"]:SetText(tostring(rounded))
    xPosEditBox:SetText(tostring(rounded))

    -- Don't rebuild if this is a programmatic change from RefreshOptionsWindow
    if self._programmaticChange then
      return
    end

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == tileKey or tile.type == tileType then
          tile.point = "CENTER"
          tile.x = rounded
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          break
        end
      end
    end
  end)

  yOffset = yOffset - 90

  -- ========== POSITION (Y coordinate) ==========
  local yPosLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  yPosLabel:SetPoint("TOPLEFT", 10, yOffset)
  yPosLabel:SetText("Y Position:")
  yPosLabel:SetTextColor(1, 0.82, 0, 1)

  local yPosSlider = CreateFrame("Slider", "SkyInfoTiles" .. tileKey .. "YPosSlider", scrollChild, "OptionsSliderTemplate")
  yPosSlider:SetPoint("TOPLEFT", yPosLabel, "BOTTOMLEFT", 5, -20)
  yPosSlider:SetWidth(200)
  yPosSlider:SetMinMaxValues(-3000, 3000)
  yPosSlider:SetValueStep(1)
  yPosSlider:SetValue(0)
  yPosSlider:SetObeyStepOnDrag(true)

  _G[yPosSlider:GetName() .. "Low"]:SetText("-3000")
  _G[yPosSlider:GetName() .. "High"]:SetText("3000")
  _G[yPosSlider:GetName() .. "Text"]:SetText("0")

  -- Y Position EditBox
  local yPosEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
  yPosEditBox:SetSize(60, 20)
  yPosEditBox:SetPoint("LEFT", yPosSlider, "RIGHT", 15, 0)
  yPosEditBox:SetAutoFocus(false)
  yPosEditBox:SetNumeric(false)
  yPosEditBox:SetText("0")
  yPosEditBox:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
      if value < -3000 then value = -3000 end
      if value > 3000 then value = 3000 end
      self:SetText(tostring(math.floor(value)))
      yPosSlider:SetValue(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == tileKey or tile.type == tileType then
            tile.point = "CENTER"
            tile.y = value
            if SkyInfoTiles.Rebuild then
              SkyInfoTiles.Rebuild()
            end
            break
          end
        end
      end
    end
    self:ClearFocus()
  end)
  yPosEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  yPosSlider._programmaticChange = false
  yPosSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value)
    _G[self:GetName() .. "Text"]:SetText(tostring(rounded))
    yPosEditBox:SetText(tostring(rounded))

    -- Don't rebuild if this is a programmatic change from RefreshOptionsWindow
    if self._programmaticChange then
      return
    end

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == tileKey or tile.type == tileType then
          tile.point = "CENTER"
          tile.y = rounded
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          break
        end
      end
    end
  end)

  yOffset = yOffset - 90

  return {
    xPosSlider = xPosSlider,
    xPosEditBox = xPosEditBox,
    yPosSlider = yPosSlider,
    yPosEditBox = yPosEditBox,
    newYOffset = yOffset
  }
end

local function CreateOptionsWindow()
  if optionsFrame then return optionsFrame end

  -- Main frame (resizable)
  local f = CreateFrame("Frame", "SkyInfoTilesOptionsFrame", UIParent, "BackdropTemplate")

  -- Load saved size or use defaults
  SkyInfoTilesDB = SkyInfoTilesDB or {}
  SkyInfoTilesDB.optionsWindowSize = SkyInfoTilesDB.optionsWindowSize or { width = 700, height = 600 }
  local savedWidth = SkyInfoTilesDB.optionsWindowSize.width or 700
  local savedHeight = SkyInfoTilesDB.optionsWindowSize.height or 600

  f:SetSize(savedWidth, savedHeight)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetResizable(true)
  f:SetResizeBounds(600, 500, 1200, 900)
  f:SetClampedToScreen(true)
  f:Hide()

  -- Modern dark backdrop
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  f:SetBackdropColor(0.15, 0.15, 0.15, 0.95)  -- Lighter background
  f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

  -- Title bar with gradient background
  local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
  titleBar:SetPoint("TOPLEFT", 2, -2)
  titleBar:SetPoint("TOPRIGHT", -2, -2)
  titleBar:SetHeight(40)
  titleBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = nil,
  })
  titleBar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)  -- Lighter title bar
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
  titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  titleBar:SetFrameLevel(f:GetFrameLevel() + 1)

  -- Title text (maximum brightness and contrast) - child of titleBar so it's always on top
  local title = titleBar:CreateFontString(nil, "OVERLAY", "SystemFont_Huge1")
  title:SetPoint("LEFT", titleBar, "LEFT", 15, 0)
  title:SetText("SkyInfoTiles")
  title:SetFont(title:GetFont(), 24, "THICKOUTLINE")
  title:SetTextColor(1, 1, 0, 1) -- Pure yellow (maximum brightness)
  title:SetShadowColor(0, 0, 0, 1)
  title:SetShadowOffset(2, -2)

  -- Close button
  local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
  closeBtn:SetScript("OnClick", function() f:Hide() end)

  -- Resize grip
  local resizeGrip = CreateFrame("Button", nil, f)
  resizeGrip:SetSize(16, 16)
  resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
  resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  resizeGrip:EnableMouse(true)
  resizeGrip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  resizeGrip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    if f.LayoutTabs then f.LayoutTabs() end
  end)

  -- Relayout tabs when window size changes and save size
  f:SetScript("OnSizeChanged", function(self, width, height)
    if self.LayoutTabs then self.LayoutTabs() end

    -- Save size to DB
    SkyInfoTilesDB = SkyInfoTilesDB or {}
    SkyInfoTilesDB.optionsWindowSize = SkyInfoTilesDB.optionsWindowSize or {}
    SkyInfoTilesDB.optionsWindowSize.width = width
    SkyInfoTilesDB.optionsWindowSize.height = height
  end)

  -- Tab buttons
  local tabs = {}
  local tabContent = {}

  -- Function to layout tabs dynamically based on window width
  local function LayoutTabs()
    if not tabs or #tabs == 0 then return end

    local windowWidth = f:GetWidth()
    local tabWidth = 110
    local tabHeight = 32
    local tabSpacing = 5
    local startX = 10
    local startY = -50
    local maxTabsPerRow = math.floor((windowWidth - startX * 2 + tabSpacing) / (tabWidth + tabSpacing))

    if maxTabsPerRow < 1 then maxTabsPerRow = 1 end

    for i, tab in ipairs(tabs) do
      local row = math.floor((i - 1) / maxTabsPerRow)
      local col = (i - 1) % maxTabsPerRow
      tab:ClearAllPoints()
      tab:SetPoint("TOPLEFT", f, "TOPLEFT", startX + col * (tabWidth + tabSpacing), startY - row * (tabHeight + tabSpacing))
    end

    -- Adjust content area based on number of rows
    local numRows = math.ceil(#tabs / maxTabsPerRow)
    local contentStartY = startY - numRows * (tabHeight + tabSpacing) - 10
    if contentArea then
      contentArea:ClearAllPoints()
      contentArea:SetPoint("TOPLEFT", 10, contentStartY)
      contentArea:SetPoint("BOTTOMRIGHT", -10, 10)
    end
  end

  f.LayoutTabs = LayoutTabs

  local function CreateTab(name, index)
    local tab = CreateFrame("Button", nil, f, "BackdropTemplate")
    tab:SetSize(110, 32)
    tab:SetPoint("TOPLEFT", 10, -50) -- Initial position, will be repositioned

    -- Background with border
    tab:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      tile = false,
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    tab:SetBackdropColor(0.25, 0.25, 0.25, 0.9)  -- Lighter tabs
    tab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Text
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetText(name)
    text:SetTextColor(0.7, 0.7, 0.7, 1)
    tab.text = text

    -- Highlight
    tab:SetScript("OnEnter", function(self)
      if not self.selected then
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)  -- Lighter hover
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        self.text:SetTextColor(0.9, 0.9, 0.9, 1)
      end
    end)
    tab:SetScript("OnLeave", function(self)
      if not self.selected then
        self:SetBackdropColor(0.25, 0.25, 0.25, 0.9)  -- Lighter normal
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        self.text:SetTextColor(0.7, 0.7, 0.7, 1)
      end
    end)

    -- Click handler
    tab:SetScript("OnClick", function(self)
      -- Deselect all tabs
      for _, t in ipairs(tabs) do
        t.selected = false
        t:SetBackdropColor(0.25, 0.25, 0.25, 0.9)  -- Lighter deselected
        t:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        t.text:SetTextColor(0.7, 0.7, 0.7, 1)
      end
      -- Select this tab
      self.selected = true
      self:SetBackdropColor(0.15, 0.15, 0.15, 1)  -- Lighter selected (darker than normal for contrast)
      self:SetBackdropBorderColor(1, 0.82, 0, 1) -- Gold border
      self.text:SetTextColor(1, 0.82, 0, 1) -- Gold text

      -- Show corresponding content
      for i, content in ipairs(tabContent) do
        content:SetShown(i == index)
      end
    end)

    tabs[index] = tab
    return tab
  end

  -- Create tabs (2 rows to fit all tiles)
  CreateTab("General", 1)
  CreateTab("Currencies", 2)
  CreateTab("Keystone", 3)
  CreateTab("Char Stats", 4)
  CreateTab("Crosshair", 5)
  CreateTab("Clock", 6)
  CreateTab("Portals", 7)

  -- Content area with subtle background (adjusted for 2 rows of tabs)
  local contentArea = CreateFrame("Frame", nil, f, "BackdropTemplate")
  contentArea:SetPoint("TOPLEFT", 10, -130) -- More space for 2 rows of tabs
  contentArea:SetPoint("BOTTOMRIGHT", -10, 10)
  contentArea:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = nil,
  })
  contentArea:SetBackdropColor(0.18, 0.18, 0.18, 0.5)  -- Lighter content area

  -- === TAB 1: GENERAL ===
  local generalTab = CreateFrame("Frame", nil, contentArea)
  generalTab:SetAllPoints()
  generalTab:Hide()
  tabContent[1] = generalTab

  local yOffset = -10

  -- Lock checkbox
  local lockCheck = CreateFrame("CheckButton", nil, generalTab, "UICheckButtonTemplate")
  lockCheck:SetPoint("TOPLEFT", 10, yOffset)
  lockCheck.Text:SetText("Lock tiles (prevent dragging)")
  lockCheck:SetScript("OnClick", function(self)
    SkyInfoTilesDB.locked = self:GetChecked()
    SkyInfoTiles.ApplyLockState()
  end)
  generalTab.lockCheck = lockCheck
  yOffset = yOffset - 30

  -- Reset button
  local resetBtn = CreateFrame("Button", nil, generalTab, "UIPanelButtonTemplate")
  resetBtn:SetSize(150, 25)
  resetBtn:SetPoint("TOPLEFT", 10, yOffset)
  resetBtn:SetText("Reset All Settings")
  resetBtn:SetScript("OnClick", function()
    if SkyInfoTiles.ResetProfile then
      SkyInfoTiles.ResetProfile()
      print("|cff66ccffSkyInfoTiles:|r Settings reset to defaults")
    end
  end)
  yOffset = yOffset - 35

  -- Clean button
  local cleanBtn = CreateFrame("Button", nil, generalTab, "UIPanelButtonTemplate")
  cleanBtn:SetSize(150, 25)
  cleanBtn:SetPoint("TOPLEFT", 10, yOffset)
  cleanBtn:SetText("Clean Duplicates")
  cleanBtn:SetScript("OnClick", function()
    if SkyInfoTiles.CleanProfile then
      SkyInfoTiles.CleanProfile()
      print("|cff66ccffSkyInfoTiles:|r Cleaned duplicate tiles")
    end
  end)

  -- === TAB 2: CURRENCIES ===
  local currencyTab = CreateFrame("Frame", nil, contentArea)
  currencyTab:SetAllPoints()
  currencyTab:Hide()
  tabContent[2] = currencyTab

  -- Enable Currency Tile checkbox
  local enableCurrencyCheck = CreateFrame("CheckButton", nil, currencyTab, "UICheckButtonTemplate")
  enableCurrencyCheck:SetPoint("TOPLEFT", 10, -10)
  enableCurrencyCheck.Text:SetText("Enable Currency Tile")
  enableCurrencyCheck.Text:SetTextColor(1, 0.82, 0, 1) -- Gold color
  enableCurrencyCheck._programmaticChange = false
  enableCurrencyCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then
      return
    end
    local enabled = self:GetChecked()
    if SkyInfoTiles.SetTileEnabledByKey then
      SkyInfoTiles.SetTileEnabledByKey("currencies", enabled)
    end
  end)
  currencyTab.enableCheck = enableCurrencyCheck

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

  -- Hide Labels checkbox - inside scroll
  local hideLabelCheck = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
  hideLabelCheck:SetPoint("TOPLEFT", 10, yOffsetCurr)
  hideLabelCheck.Text:SetText("Hide Labels (show only numbers)")
  hideLabelCheck.Text:SetTextColor(1, 0.82, 0, 1)
  hideLabelCheck._programmaticChange = false
  hideLabelCheck:SetScript("OnClick", function(self)
    -- Skip rebuild if this is a programmatic change
    if self._programmaticChange then
      return
    end

    local hideLabel = self:GetChecked()
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "currencies" or tile.type == "currencies" then
          tile.hideLabel = hideLabel
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)
  currencyTab.hideLabelCheck = hideLabelCheck
  yOffsetCurr = yOffsetCurr - 30

  -- Position sliders (X and Y) - inside scroll
  local currencyPosSliders = CreatePositionSliders(scrollChild, "currencies", "currencies", yOffsetCurr)
  currencyTab.xPosSlider = currencyPosSliders.xPosSlider
  currencyTab.xPosEditBox = currencyPosSliders.xPosEditBox
  currencyTab.yPosSlider = currencyPosSliders.yPosSlider
  currencyTab.yPosEditBox = currencyPosSliders.yPosEditBox
  yOffsetCurr = currencyPosSliders.newYOffset

  yOffsetCurr = yOffsetCurr - 20
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
        -- Separator line
        local line = scrollChild:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.5, 0.5, 0.5, 0.6)
        line:SetSize(550, 2)
        line:SetPoint("TOPLEFT", 10, y - 10)
        line._isCurrencyCheck = true
        y = y - 25
        return
      end

      local cb = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
      cb:SetPoint("TOPLEFT", 10, y)
      cb.Text:SetText(entry.label or ("Currency " .. entry.id))
      cb._isCurrencyCheck = true

      -- Load saved state (default = true for all)
      local enabled = SkyInfoTilesDB.currencySettings[entry.id]
      if enabled == nil then
        enabled = true
        SkyInfoTilesDB.currencySettings[entry.id] = true
      end

      -- Set checked state BEFORE adding OnClick to prevent triggering refresh
      cb:SetChecked(enabled)

      -- Add OnClick handler AFTER setting initial state
      cb:SetScript("OnClick", function(self)
        SkyInfoTilesDB.currencySettings[entry.id] = self:GetChecked()
        -- Refresh currency tile
        if SkyInfoTiles.RefreshCurrencyTile then
          SkyInfoTiles.RefreshCurrencyTile()
        end
      end)

      y = y - 25
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
  local keystoneTab = CreateFrame("Frame", nil, contentArea)
  keystoneTab:SetAllPoints()
  keystoneTab:Hide()
  tabContent[3] = keystoneTab

  -- Enable checkbox
  local keystoneEnableCheck = CreateFrame("CheckButton", nil, keystoneTab, "UICheckButtonTemplate")
  keystoneEnableCheck:SetPoint("TOPLEFT", 10, -10)
  keystoneEnableCheck.Text:SetText("Enable Mythic Keystone")
  keystoneEnableCheck.Text:SetTextColor(1, 0.82, 0, 1)
  keystoneEnableCheck._programmaticChange = false
  keystoneEnableCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then return end
    local enabled = self:GetChecked()
    if SkyInfoTiles.SetTileEnabledByKey then
      SkyInfoTiles.SetTileEnabledByKey("keystone", enabled)
    end
  end)
  keystoneTab.enableCheck = keystoneEnableCheck

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, keystoneTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, -40)
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 800)
  scrollFrame:SetScrollChild(scrollChild)

  keystoneTab.scrollFrame = scrollFrame
  keystoneTab.scrollChild = scrollChild

  local yOffset = -10

  -- ========== SCALE ==========
  local scaleLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  scaleLabel:SetPoint("TOPLEFT", 10, yOffset)
  scaleLabel:SetText("Tile Scale:")
  scaleLabel:SetTextColor(1, 0.82, 0, 1)

  local scaleSlider = CreateFrame("Slider", "SkyInfoTilesKeystoneScaleSlider", scrollChild, "OptionsSliderTemplate")
  scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 5, -20)
  scaleSlider:SetWidth(250)
  scaleSlider:SetMinMaxValues(0.5, 2.0)
  scaleSlider:SetValueStep(0.05)
  scaleSlider:SetValue(1.0)
  scaleSlider:SetObeyStepOnDrag(true)

  _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
  _G[scaleSlider:GetName() .. "High"]:SetText("200%")
  _G[scaleSlider:GetName() .. "Text"]:SetText("100%")

  scaleSlider:SetScript("OnValueChanged", function(self, value)
    _G[self:GetName() .. "Text"]:SetText(string.format("%.0f%%", value * 100))
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          tile.scale = value
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)

  keystoneTab.scaleSlider = scaleSlider
  yOffset = yOffset - 90

  -- ========== POSITION (X coordinate) ==========
  local xPosLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  xPosLabel:SetPoint("TOPLEFT", 10, yOffset)
  xPosLabel:SetText("X Position:")
  xPosLabel:SetTextColor(1, 0.82, 0, 1)

  local xPosSlider = CreateFrame("Slider", "SkyInfoTilesKeystoneXPosSlider", scrollChild, "OptionsSliderTemplate")
  xPosSlider:SetPoint("TOPLEFT", xPosLabel, "BOTTOMLEFT", 5, -20)
  xPosSlider:SetWidth(200)
  xPosSlider:SetMinMaxValues(-1000, 3000)
  xPosSlider:SetValueStep(1)
  xPosSlider:SetValue(0)
  xPosSlider:SetObeyStepOnDrag(true)

  _G[xPosSlider:GetName() .. "Low"]:SetText("-1000")
  _G[xPosSlider:GetName() .. "High"]:SetText("3000")
  _G[xPosSlider:GetName() .. "Text"]:SetText("0")

  -- X Position EditBox (manual input)
  local xPosEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
  xPosEditBox:SetSize(60, 20)
  xPosEditBox:SetPoint("LEFT", xPosSlider, "RIGHT", 15, 0)
  xPosEditBox:SetAutoFocus(false)
  xPosEditBox:SetNumeric(false) -- Allow negative numbers
  xPosEditBox:SetText("0")
  xPosEditBox:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
      if value < -3000 then value = -3000 end
      if value > 3000 then value = 3000 end
      self:SetText(tostring(math.floor(value)))
      xPosSlider:SetValue(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.point = "CENTER"  -- Always use CENTER for slider-based positioning
            tile.x = value
            if SkyInfoTiles.Rebuild then
              SkyInfoTiles.Rebuild()
            end
            break
          end
        end
      end
    end
    self:ClearFocus()
  end)
  xPosEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  xPosSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value)
    _G[self:GetName() .. "Text"]:SetText(tostring(rounded))
    xPosEditBox:SetText(tostring(rounded))
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          tile.point = "CENTER"  -- Always use CENTER for slider-based positioning
          tile.x = rounded
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          break
        end
      end
    end
  end)

  keystoneTab.xPosSlider = xPosSlider
  keystoneTab.xPosEditBox = xPosEditBox
  yOffset = yOffset - 90

  -- ========== POSITION (Y coordinate) ==========
  local yPosLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  yPosLabel:SetPoint("TOPLEFT", 10, yOffset)
  yPosLabel:SetText("Y Position:")
  yPosLabel:SetTextColor(1, 0.82, 0, 1)

  local yPosSlider = CreateFrame("Slider", "SkyInfoTilesKeystoneYPosSlider", scrollChild, "OptionsSliderTemplate")
  yPosSlider:SetPoint("TOPLEFT", yPosLabel, "BOTTOMLEFT", 5, -20)
  yPosSlider:SetWidth(200)
  yPosSlider:SetMinMaxValues(-1000, 3000)
  yPosSlider:SetValueStep(1)
  yPosSlider:SetValue(0)
  yPosSlider:SetObeyStepOnDrag(true)

  _G[yPosSlider:GetName() .. "Low"]:SetText("-1000")
  _G[yPosSlider:GetName() .. "High"]:SetText("3000")
  _G[yPosSlider:GetName() .. "Text"]:SetText("0")

  -- Y Position EditBox (manual input)
  local yPosEditBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
  yPosEditBox:SetSize(60, 20)
  yPosEditBox:SetPoint("LEFT", yPosSlider, "RIGHT", 15, 0)
  yPosEditBox:SetAutoFocus(false)
  yPosEditBox:SetNumeric(false) -- Allow negative numbers
  yPosEditBox:SetText("0")
  yPosEditBox:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value then
      if value < -3000 then value = -3000 end
      if value > 3000 then value = 3000 end
      self:SetText(tostring(math.floor(value)))
      yPosSlider:SetValue(value)
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "keystone" or tile.type == "keystone" then
            tile.point = "CENTER"  -- Always use CENTER for slider-based positioning
            tile.y = value
            if SkyInfoTiles.Rebuild then
              SkyInfoTiles.Rebuild()
            end
            break
          end
        end
      end
    end
    self:ClearFocus()
  end)
  yPosEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  yPosSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor(value)
    _G[self:GetName() .. "Text"]:SetText(tostring(rounded))
    yPosEditBox:SetText(tostring(rounded))
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          tile.point = "CENTER"  -- Always use CENTER for slider-based positioning
          tile.y = rounded
          if SkyInfoTiles.Rebuild then
            SkyInfoTiles.Rebuild()
          end
          break
        end
      end
    end
  end)

  keystoneTab.yPosSlider = yPosSlider
  keystoneTab.yPosEditBox = yPosEditBox
  yOffset = yOffset - 90

  -- ========== BACKGROUND ==========
  local bgLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bgLabel:SetPoint("TOPLEFT", 10, yOffset)
  bgLabel:SetText("Background:")
  bgLabel:SetTextColor(1, 0.82, 0, 1)

  local bgEnableCheck = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
  bgEnableCheck:SetPoint("TOPLEFT", bgLabel, "BOTTOMLEFT", 0, -10)
  bgEnableCheck.Text:SetText("Show Background")
  bgEnableCheck._programmaticChange = false
  bgEnableCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then return end
    local enabled = self:GetChecked()
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          tile.showBackground = enabled
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)
  keystoneTab.bgEnableCheck = bgEnableCheck

  -- Use Class Color checkbox
  local useClassColorCheck = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
  useClassColorCheck:SetPoint("TOPLEFT", bgEnableCheck, "BOTTOMLEFT", 20, -10)
  useClassColorCheck.Text:SetText("Use Class Color")
  useClassColorCheck._programmaticChange = false
  useClassColorCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then return end
    local enabled = self:GetChecked()
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          tile.useClassColor = enabled
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          -- Update UI state
          if keystoneTab.bgColorButton then
            if enabled then
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
  end)
  keystoneTab.useClassColorCheck = useClassColorCheck

  -- Background color picker
  local bgColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bgColorLabel:SetPoint("TOPLEFT", useClassColorCheck, "BOTTOMLEFT", 0, -10)
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

  yOffset = yOffset - 170  -- Increased to make room for "Use Class Color" checkbox and prevent overlap

  -- ========== BORDER ==========
  local borderLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  borderLabel:SetPoint("TOPLEFT", 10, yOffset)
  borderLabel:SetText("Border:")
  borderLabel:SetTextColor(1, 0.82, 0, 1)

  local borderEnableCheck = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
  borderEnableCheck:SetPoint("TOPLEFT", borderLabel, "BOTTOMLEFT", 0, -10)
  borderEnableCheck.Text:SetText("Show Border")
  borderEnableCheck._programmaticChange = false
  borderEnableCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then return end
    local enabled = self:GetChecked()
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          tile.showBorder = enabled
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)
  keystoneTab.borderEnableCheck = borderEnableCheck

  -- Border color picker
  local borderColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  borderColorLabel:SetPoint("TOPLEFT", borderEnableCheck, "BOTTOMLEFT", 20, -10)
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

  -- Border thickness slider
  local borderThicknessLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  borderThicknessLabel:SetPoint("TOPLEFT", borderColorLabel, "BOTTOMLEFT", -20, -40)
  borderThicknessLabel:SetText("Border Thickness:")

  local borderThicknessSlider = CreateFrame("Slider", "SkyInfoTilesKeystoneBorderThicknessSlider", scrollChild, "OptionsSliderTemplate")
  borderThicknessSlider:SetPoint("TOPLEFT", borderThicknessLabel, "BOTTOMLEFT", 5, -20)
  borderThicknessSlider:SetWidth(250)
  borderThicknessSlider:SetMinMaxValues(1, 10)
  borderThicknessSlider:SetValueStep(1)
  borderThicknessSlider:SetValue(2)
  borderThicknessSlider:SetObeyStepOnDrag(true)

  _G[borderThicknessSlider:GetName() .. "Low"]:SetText("1")
  _G[borderThicknessSlider:GetName() .. "High"]:SetText("10")
  _G[borderThicknessSlider:GetName() .. "Text"]:SetText("2")

  borderThicknessSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    _G[self:GetName() .. "Text"]:SetText(tostring(value))

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "keystone" or tile.type == "keystone" then
          tile.borderThickness = value
          if SkyInfoTiles.UpdateAll then
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)

  keystoneTab.borderThicknessSlider = borderThicknessSlider

  -- === TAB 4: CHAR STATS (with stat order customization) ===
  local charStatsTab = CreateFrame("Frame", nil, contentArea)
  charStatsTab:SetAllPoints()
  charStatsTab:Hide()
  tabContent[4] = charStatsTab

  -- Enable checkbox (fixed at top)
  local charStatsEnableCheck = CreateFrame("CheckButton", nil, charStatsTab, "UICheckButtonTemplate")
  charStatsEnableCheck:SetPoint("TOPLEFT", 10, -10)
  charStatsEnableCheck.Text:SetText("Enable Character Stats")
  charStatsEnableCheck.Text:SetTextColor(1, 0.82, 0, 1)
  charStatsEnableCheck._programmaticChange = false
  charStatsEnableCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then return end
    local enabled = self:GetChecked()
    if SkyInfoTiles.SetTileEnabledByKey then
      SkyInfoTiles.SetTileEnabledByKey("charstats", enabled)
    end
  end)
  charStatsTab.enableCheck = charStatsEnableCheck

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, charStatsTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, -40)
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

  yOffsetChar = yOffsetChar - 20

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

  -- Hide title checkbox
  local hideTitleCheck = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
  hideTitleCheck:SetPoint("TOPLEFT", 10, fontControlsY)
  hideTitleCheck.Text:SetText("Hide Title")
  hideTitleCheck.Text:SetTextColor(1, 0.82, 0, 1)
  hideTitleCheck:SetScript("OnClick", function(self)
    local hideTitle = self:GetChecked()
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "charstats" or tile.type == "charstats" then
          tile.hideTitle = hideTitle
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)
  charStatsTab.hideTitleCheck = hideTitleCheck

  -- Show Tertiary Stats checkbox
  local showTertiaryCheck = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
  showTertiaryCheck:SetPoint("TOPLEFT", hideTitleCheck, "BOTTOMLEFT", 0, -5)
  showTertiaryCheck.Text:SetText("Show Tertiary Stats (Leech, Avoidance, Speed)")
  showTertiaryCheck.Text:SetTextColor(1, 0.82, 0, 1)
  showTertiaryCheck:SetScript("OnClick", function(self)
    local showTertiary = self:GetChecked()
    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "charstats" or tile.type == "charstats" then
          tile.showTertiary = showTertiary
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)
  charStatsTab.showTertiaryCheck = showTertiaryCheck

  -- Title size slider label
  local titleSizeLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleSizeLabel:SetPoint("TOPLEFT", 10, fontControlsY - 90)
  titleSizeLabel:SetText("Title Size:")
  titleSizeLabel:SetTextColor(1, 0.82, 0, 1)

  -- Title size slider
  local titleSizeSlider = CreateFrame("Slider", "SkyInfoTilesCharStatsTitleSizeSlider", scrollChild, "OptionsSliderTemplate")
  titleSizeSlider:SetPoint("TOPLEFT", titleSizeLabel, "BOTTOMLEFT", 5, -20)
  titleSizeSlider:SetWidth(250)
  titleSizeSlider:SetMinMaxValues(8, 32)
  titleSizeSlider:SetValueStep(1)
  titleSizeSlider:SetValue(14)
  titleSizeSlider:SetObeyStepOnDrag(true)

  _G[titleSizeSlider:GetName() .. "Low"]:SetText("8")
  _G[titleSizeSlider:GetName() .. "High"]:SetText("32")
  _G[titleSizeSlider:GetName() .. "Text"]:SetText("14")

  titleSizeSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    _G[self:GetName() .. "Text"]:SetText(tostring(value))

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "charstats" or tile.type == "charstats" then
          tile.titleSize = value
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)

  charStatsTab.titleSizeSlider = titleSizeSlider

  -- Line size slider label
  local lineSizeLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  lineSizeLabel:SetPoint("TOPLEFT", titleSizeLabel, "BOTTOMLEFT", 0, -80)
  lineSizeLabel:SetText("Line Size:")
  lineSizeLabel:SetTextColor(1, 0.82, 0, 1)

  -- Line size slider
  local lineSizeSlider = CreateFrame("Slider", "SkyInfoTilesCharStatsLineSizeSlider", scrollChild, "OptionsSliderTemplate")
  lineSizeSlider:SetPoint("TOPLEFT", lineSizeLabel, "BOTTOMLEFT", 5, -20)
  lineSizeSlider:SetWidth(250)
  lineSizeSlider:SetMinMaxValues(6, 24)
  lineSizeSlider:SetValueStep(1)
  lineSizeSlider:SetValue(12)
  lineSizeSlider:SetObeyStepOnDrag(true)

  _G[lineSizeSlider:GetName() .. "Low"]:SetText("6")
  _G[lineSizeSlider:GetName() .. "High"]:SetText("24")
  _G[lineSizeSlider:GetName() .. "Text"]:SetText("12")

  lineSizeSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    _G[self:GetName() .. "Text"]:SetText(tostring(value))

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "charstats" or tile.type == "charstats" then
          tile.lineSize = value
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)

  charStatsTab.lineSizeSlider = lineSizeSlider

  -- === TAB 5: CROSSHAIR (with size and color options) ===
  local crosshairTab = CreateFrame("Frame", nil, contentArea)
  crosshairTab:SetAllPoints()
  crosshairTab:Hide()
  tabContent[5] = crosshairTab

  -- Enable checkbox (fixed at top)
  local crosshairEnableCheck = CreateFrame("CheckButton", nil, crosshairTab, "UICheckButtonTemplate")
  crosshairEnableCheck:SetPoint("TOPLEFT", 10, -10)
  crosshairEnableCheck.Text:SetText("Enable Crosshair")
  crosshairEnableCheck.Text:SetTextColor(1, 0.82, 0, 1)
  crosshairEnableCheck._programmaticChange = false
  crosshairEnableCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then return end
    local enabled = self:GetChecked()
    if SkyInfoTiles.SetTileEnabledByKey then
      SkyInfoTiles.SetTileEnabledByKey("crosshair", enabled)
    end
  end)
  crosshairTab.enableCheck = crosshairEnableCheck

  -- Scroll frame for settings
  local scrollFrame = CreateFrame("ScrollFrame", nil, crosshairTab, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 5, -40) -- Start below checkbox
  scrollFrame:SetPoint("BOTTOMRIGHT", -25, 10)

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(580, 600) -- Height will accommodate all controls
  scrollFrame:SetScrollChild(scrollChild)

  crosshairTab.scrollFrame = scrollFrame
  crosshairTab.scrollChild = scrollChild

  -- Size slider label
  local sizeLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sizeLabel:SetPoint("TOPLEFT", 10, -10)
  sizeLabel:SetText("Size:")
  sizeLabel:SetTextColor(1, 0.82, 0, 1)

  -- Size slider
  local sizeSlider = CreateFrame("Slider", "SkyInfoTilesCrosshairSizeSlider", scrollChild, "OptionsSliderTemplate")
  sizeSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 5, -20)
  sizeSlider:SetWidth(250)
  sizeSlider:SetMinMaxValues(4, 512)
  sizeSlider:SetValueStep(1)
  sizeSlider:SetValue(32)
  sizeSlider:SetObeyStepOnDrag(true)

  -- Slider labels
  _G[sizeSlider:GetName() .. "Low"]:SetText("4")
  _G[sizeSlider:GetName() .. "High"]:SetText("512")
  _G[sizeSlider:GetName() .. "Text"]:SetText("32")

  sizeSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    _G[self:GetName() .. "Text"]:SetText(tostring(value))

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "crosshair" or tile.type == "crosshair" then
          tile.size = value
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)

  crosshairTab.sizeSlider = sizeSlider

  -- Thickness slider label
  local thicknessLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  thicknessLabel:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -80)
  thicknessLabel:SetText("Thickness:")
  thicknessLabel:SetTextColor(1, 0.82, 0, 1)

  -- Thickness slider
  local thicknessSlider = CreateFrame("Slider", "SkyInfoTilesCrosshairThicknessSlider", scrollChild, "OptionsSliderTemplate")
  thicknessSlider:SetPoint("TOPLEFT", thicknessLabel, "BOTTOMLEFT", 5, -20)
  thicknessSlider:SetWidth(250)
  thicknessSlider:SetMinMaxValues(1, 64)
  thicknessSlider:SetValueStep(1)
  thicknessSlider:SetValue(2)
  thicknessSlider:SetObeyStepOnDrag(true)

  -- Slider labels
  _G[thicknessSlider:GetName() .. "Low"]:SetText("1")
  _G[thicknessSlider:GetName() .. "High"]:SetText("64")
  _G[thicknessSlider:GetName() .. "Text"]:SetText("2")

  thicknessSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    _G[self:GetName() .. "Text"]:SetText(tostring(value))

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "crosshair" or tile.type == "crosshair" then
          tile.thickness = value
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)

  crosshairTab.thicknessSlider = thicknessSlider

  -- Color picker label
  local colorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", thicknessLabel, "BOTTOMLEFT", 0, -80)
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
  colorSwatch:SetColorTexture(1, 0, 0, 1) -- Default red
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

  -- Outline thickness slider label
  local outlineThicknessLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  outlineThicknessLabel:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -80)
  outlineThicknessLabel:SetText("Outline Thickness:")
  outlineThicknessLabel:SetTextColor(1, 0.82, 0, 1)

  -- Outline thickness slider
  local outlineThicknessSlider = CreateFrame("Slider", "SkyInfoTilesCrosshairOutlineThicknessSlider", scrollChild, "OptionsSliderTemplate")
  outlineThicknessSlider:SetPoint("TOPLEFT", outlineThicknessLabel, "BOTTOMLEFT", 5, -20)
  outlineThicknessSlider:SetWidth(250)
  outlineThicknessSlider:SetMinMaxValues(0, 32)
  outlineThicknessSlider:SetValueStep(1)
  outlineThicknessSlider:SetValue(0)
  outlineThicknessSlider:SetObeyStepOnDrag(true)

  -- Slider labels
  _G[outlineThicknessSlider:GetName() .. "Low"]:SetText("0 (Off)")
  _G[outlineThicknessSlider:GetName() .. "High"]:SetText("32")
  _G[outlineThicknessSlider:GetName() .. "Text"]:SetText("0")

  outlineThicknessSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    _G[self:GetName() .. "Text"]:SetText(tostring(value))

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "crosshair" or tile.type == "crosshair" then
          tile.outlineThickness = value
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)

  crosshairTab.outlineThicknessSlider = outlineThicknessSlider

  -- Outline color picker label
  local outlineColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  outlineColorLabel:SetPoint("TOPLEFT", outlineThicknessLabel, "BOTTOMLEFT", 0, -80)
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

  -- === TAB 6: CLOCK (with font and size options) ===
  local clockTab = CreateFrame("Frame", nil, contentArea)
  clockTab:SetAllPoints()
  clockTab:Hide()
  tabContent[6] = clockTab

  -- Enable checkbox
  local clockEnableCheck = CreateFrame("CheckButton", nil, clockTab, "UICheckButtonTemplate")
  clockEnableCheck:SetPoint("TOPLEFT", 10, -10)
  clockEnableCheck.Text:SetText("Enable 24h Clock")
  clockEnableCheck.Text:SetTextColor(1, 0.82, 0, 1)
  clockEnableCheck._programmaticChange = false
  clockEnableCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then return end
    local enabled = self:GetChecked()
    if SkyInfoTiles.SetTileEnabledByKey then
      SkyInfoTiles.SetTileEnabledByKey("clock", enabled)
    end
  end)
  clockTab.enableCheck = clockEnableCheck

  -- Position sliders (X and Y)
  local yOffsetClock = -50
  local clockPosSliders = CreatePositionSliders(clockTab, "clock", "clock", yOffsetClock)
  clockTab.xPosSlider = clockPosSliders.xPosSlider
  clockTab.xPosEditBox = clockPosSliders.xPosEditBox
  clockTab.yPosSlider = clockPosSliders.yPosSlider
  clockTab.yPosEditBox = clockPosSliders.yPosEditBox
  yOffsetClock = clockPosSliders.newYOffset

  -- Font dropdown label
  local fontLabel = clockTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fontLabel:SetPoint("TOPLEFT", 10, yOffsetClock)
  fontLabel:SetText("Font:")
  fontLabel:SetTextColor(1, 0.82, 0, 1)

  -- Font dropdown
  local fontDropdown = CreateFrame("Frame", "SkyInfoTilesClockFontDropdown", clockTab, "UIDropDownMenuTemplate")
  fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -15, -5)
  UIDropDownMenu_SetWidth(fontDropdown, 200)

  -- Dynamic font discovery (lazy-loaded on first dropdown open)
  local FONT_OPTIONS = nil
  local fontsDiscovered = false

  local function DiscoverFonts()
    if fontsDiscovered then return FONT_OPTIONS end
    fontsDiscovered = true

    local fonts = {}
    local seen = {} -- Prevent duplicates by lowercase name

    -- Test if a font actually loads
    local testFrame = CreateFrame("Frame")
    local testFont = testFrame:CreateFontString()
    local function TestFont(path)
      local success = pcall(testFont.SetFont, testFont, path, 12, "")
      return success
    end

    -- Helper to add font
    local function AddFont(path, name)
      local key = name:lower()
      if not seen[key] then
        if TestFont(path) then
          seen[key] = true
          table.insert(fonts, { path = path, name = name })
        end
      end
    end

    -- 1. WoW built-in fonts (always available)
    AddFont("Fonts\\FRIZQT__.ttf", "Friz Quadrata (Default)")
    AddFont("Fonts\\ARIALN.ttf", "Arial Narrow")
    AddFont("Fonts\\MORPHEUS.ttf", "Morpheus (Decorative)")
    AddFont("Fonts\\skurri.ttf", "Skurri (Runic)")
    AddFont("Fonts\\theboldfont.ttf", "Bold Font")

    -- 2. Try LibSharedMedia-3.0 if available
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
      local lsmFonts = LSM:HashTable("font")
      if lsmFonts then
        for name, path in pairs(lsmFonts) do
          AddFont(path, name)
        end
      end
    end

    -- 3. Known addon fonts (fallback/additional fonts not in LSM)
    local knownFonts = {
      -- SharedMedia / SharedMedia_ClassicalFonts
      { path = "Interface\\AddOns\\SharedMedia\\fonts\\Adventure.ttf", name = "Adventure" },
      { path = "Interface\\AddOns\\SharedMedia\\fonts\\ARIAL.TTF", name = "Arial" },
      { path = "Interface\\AddOns\\SharedMedia\\fonts\\DejaVuSansMono.ttf", name = "DejaVu Sans Mono" },
      { path = "Interface\\AddOns\\SharedMedia\\fonts\\Expressway.ttf", name = "Expressway" },
      { path = "Interface\\AddOns\\SharedMedia\\fonts\\Roadway.ttf", name = "Roadway" },
      { path = "Interface\\AddOns\\SharedMedia_ClassicalFonts\\fonts\\King Arthur Legend.ttf", name = "King Arthur (Medieval)" },
      { path = "Interface\\AddOns\\SharedMedia_ClassicalFonts\\fonts\\OldeEnglish.ttf", name = "Olde English" },
      { path = "Interface\\AddOns\\SharedMedia_ClassicalFonts\\fonts\\MoviePoster.ttf", name = "Movie Poster" },
      { path = "Interface\\AddOns\\SharedMedia_ClassicalFonts\\fonts\\WaltDisney.ttf", name = "Walt Disney" },

      -- Cell addon
      { path = "Interface\\AddOns\\Cell\\Media\\Fonts\\Accidental Presidency.ttf", name = "Accidental Presidency" },

      -- ElvUI_WindTools
      { path = "Interface\\AddOns\\ElvUI_WindTools\\Media\\Fonts\\Roadway.ttf", name = "Roadway (WindTools)" },

      -- WarpDeplete
      { path = "Interface\\AddOns\\WarpDeplete\\Media\\Fonts\\BigNoodleTitling.ttf", name = "Big Noodle Titling" },

      -- AstralKeys
      { path = "Interface\\AddOns\\AstralKeys\\Media\\Fonts\\visitor1.ttf", name = "Visitor (Retro)" },

      -- Prat-3.0
      { path = "Interface\\AddOns\\Prat-3.0\\fonts\\Ubuntu-R.ttf", name = "Ubuntu" },

      -- ChonkyCharacterSheet
      { path = "Interface\\AddOns\\ChonkyCharacterSheet\\fonts\\Inter-UI-Bold.ttf", name = "Inter UI Bold" },

      -- MRT (Method Raid Tools)
      { path = "Interface\\AddOns\\MRT\\media\\skurri.ttf", name = "Skurri (MRT)" },
      { path = "Interface\\AddOns\\MRT\\media\\Cyrillic.ttf", name = "Cyrillic" },
    }

    for _, font in ipairs(knownFonts) do
      AddFont(font.path, font.name)
    end

    -- Sort alphabetically by name (except keep default first)
    table.sort(fonts, function(a, b)
      if a.name:find("Default") then return true end
      if b.name:find("Default") then return false end
      return a.name < b.name
    end)

    FONT_OPTIONS = fonts

    -- Chat feedback
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff66ccffSkyInfoTiles:|r Discovered %d fonts!", #fonts))
    end

    return fonts
  end

  local function OnFontSelect(self)
    local value = self.value
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
    -- Update dropdown text
    local opts = FONT_OPTIONS or {}
    for _, opt in ipairs(opts) do
      if opt.path == value then
        UIDropDownMenu_SetText(fontDropdown, opt.name)
        break
      end
    end
  end

  UIDropDownMenu_Initialize(fontDropdown, function(self, level)
    -- Lazy load fonts on first open
    local opts = DiscoverFonts()
    for _, opt in ipairs(opts) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = opt.name
      info.value = opt.path
      info.func = OnFontSelect
      info.checked = false
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  UIDropDownMenu_SetText(fontDropdown, "Friz Quadrata (Default)")
  clockTab.fontDropdown = fontDropdown
  clockTab.GetFontOptions = DiscoverFonts -- Store reference for refresh

  -- Tip text
  local tipText = clockTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  tipText:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 200, 5)
  tipText:SetTextColor(0.7, 0.7, 0.7, 1)
  tipText:SetText("Tip: Set outline to 'None' to see font differences clearly!")

  -- Font size slider label
  local sizeLabel = clockTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sizeLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 15, -60)
  sizeLabel:SetText("Font Size:")
  sizeLabel:SetTextColor(1, 0.82, 0, 1)

  -- Font size slider
  local sizeSlider = CreateFrame("Slider", "SkyInfoTilesClockSizeSlider", clockTab, "OptionsSliderTemplate")
  sizeSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 5, -20)
  sizeSlider:SetWidth(250)
  sizeSlider:SetMinMaxValues(6, 128)
  sizeSlider:SetValueStep(1)
  sizeSlider:SetValue(24)
  sizeSlider:SetObeyStepOnDrag(true)

  -- Slider labels
  _G[sizeSlider:GetName() .. "Low"]:SetText("6")
  _G[sizeSlider:GetName() .. "High"]:SetText("128")
  _G[sizeSlider:GetName() .. "Text"]:SetText("24")

  sizeSlider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    _G[self:GetName() .. "Text"]:SetText(tostring(value))

    if SkyInfoTiles.GetActiveTiles then
      local tiles = SkyInfoTiles.GetActiveTiles()
      for _, tile in ipairs(tiles) do
        if tile.key == "clock" or tile.type == "clock" then
          tile.fontSize = value
          if SkyInfoTiles.Rebuild and SkyInfoTiles.UpdateAll then
            SkyInfoTiles.Rebuild()
            SkyInfoTiles.UpdateAll()
          end
          break
        end
      end
    end
  end)

  clockTab.sizeSlider = sizeSlider

  -- === TAB 7: DUNGEON PORTS (with orientation option) ===
  local dungeonTab = CreateFrame("Frame", nil, contentArea)
  dungeonTab:SetAllPoints()
  dungeonTab:Hide()
  tabContent[7] = dungeonTab

  -- Enable checkbox
  local dungeonEnableCheck = CreateFrame("CheckButton", nil, dungeonTab, "UICheckButtonTemplate")
  dungeonEnableCheck:SetPoint("TOPLEFT", 10, -10)
  dungeonEnableCheck.Text:SetText("Enable Dungeon Teleports")
  dungeonEnableCheck.Text:SetTextColor(1, 0.82, 0, 1)
  dungeonEnableCheck._programmaticChange = false
  dungeonEnableCheck:SetScript("OnClick", function(self)
    if self._programmaticChange then return end
    local enabled = self:GetChecked()
    if SkyInfoTiles.SetTileEnabledByKey then
      SkyInfoTiles.SetTileEnabledByKey("dungeonports", enabled)
    end
  end)
  dungeonTab.enableCheck = dungeonEnableCheck

  -- Position sliders (X and Y)
  local yOffsetDungeon = -50
  local dungeonPosSliders = CreatePositionSliders(dungeonTab, "dungeonports", "dungeonports", yOffsetDungeon)
  dungeonTab.xPosSlider = dungeonPosSliders.xPosSlider
  dungeonTab.xPosEditBox = dungeonPosSliders.xPosEditBox
  dungeonTab.yPosSlider = dungeonPosSliders.yPosSlider
  dungeonTab.yPosEditBox = dungeonPosSliders.yPosEditBox
  yOffsetDungeon = dungeonPosSliders.newYOffset

  -- Orientation label
  local orientLabel = dungeonTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  orientLabel:SetPoint("TOPLEFT", 10, yOffsetDungeon)
  orientLabel:SetText("Layout Orientation:")
  orientLabel:SetTextColor(1, 0.82, 0, 1)

  -- Orientation dropdown (horizontal/vertical)
  local orientDropdown = CreateFrame("Frame", "SkyInfoTilesDungeonOrientDropdown", dungeonTab, "UIDropDownMenuTemplate")
  orientDropdown:SetPoint("TOPLEFT", orientLabel, "BOTTOMLEFT", -15, -5)
  UIDropDownMenu_SetWidth(orientDropdown, 150)

  local function OnOrientationSelect(self)
    local value = self.value
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
    UIDropDownMenu_SetText(orientDropdown, value == "horizontal" and "Horizontal" or "Vertical")
  end

  UIDropDownMenu_Initialize(orientDropdown, function(self, level)
    local info = UIDropDownMenu_CreateInfo()

    info.text = "Horizontal"
    info.value = "horizontal"
    info.func = OnOrientationSelect
    info.checked = false
    UIDropDownMenu_AddButton(info, level)

    info.text = "Vertical"
    info.value = "vertical"
    info.func = OnOrientationSelect
    info.checked = false
    UIDropDownMenu_AddButton(info, level)
  end)

  UIDropDownMenu_SetText(orientDropdown, "Horizontal")
  dungeonTab.orientDropdown = orientDropdown

  -- Show first tab by default and layout tabs
  tabs[1]:Click()
  if f.LayoutTabs then f.LayoutTabs() end

  -- Save frame
  optionsFrame = f
  f.tabs = tabs
  f.tabContent = tabContent

  return f
end

-- Refresh function (called when settings change externally)
local function RefreshOptionsWindow()
  local f = optionsFrame
  if not f or not f:IsShown() then return end

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
    [7] = "dungeonports"
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
    local xPos = 0
    local yPos = 0
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
          xPos = tile.x or 0
          yPos = tile.y or 0
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
    if keystoneTab.xPosSlider then
      keystoneTab.xPosSlider._programmaticChange = true
      keystoneTab.xPosSlider:SetValue(xPos)
      keystoneTab.xPosSlider._programmaticChange = false
      _G[keystoneTab.xPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(xPos)))
    end
    if keystoneTab.xPosEditBox then
      keystoneTab.xPosEditBox:SetText(tostring(math.floor(xPos)))
    end
    if keystoneTab.yPosSlider then
      keystoneTab.yPosSlider._programmaticChange = true
      keystoneTab.yPosSlider:SetValue(yPos)
      keystoneTab.yPosSlider._programmaticChange = false
      _G[keystoneTab.yPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(yPos)))
    end
    if keystoneTab.yPosEditBox then
      keystoneTab.yPosEditBox:SetText(tostring(math.floor(yPos)))
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
    {index = 7, key = "dungeonports"}
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
end

-- Export refresh function
SkyInfoTiles._OptionsRefresh = RefreshOptionsWindow

-- Toggle function
function SkyInfoTiles.ToggleOptionsWindow()
  local f = CreateOptionsWindow()
  if f:IsShown() then
    f:Hide()
  else
    -- Refresh hide label checkbox for currencies (but don't repopulate currency list)
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
    -- Refresh general tab checkboxes
    if f.tabContent and f.tabContent[1] and f.tabContent[1].lockCheck then
      f.tabContent[1].lockCheck:SetChecked(SkyInfoTilesDB.locked or false)
    end
    -- Refresh all tile enable checkboxes
    local tileKeys = {
      [2] = "currencies",
      [3] = "keystone",
      [4] = "charstats",
      [5] = "crosshair",
      [6] = "clock",
      [7] = "dungeonports"
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

    -- Refresh keystone settings
    if f.tabContent and f.tabContent[3] then
      local keystoneTab = f.tabContent[3]
      local scale = 1.0
      local xPos = 0
      local yPos = 0
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
            xPos = tile.x or 0
            yPos = tile.y or 0
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
      if keystoneTab.xPosSlider then
        keystoneTab.xPosSlider._programmaticChange = true
        keystoneTab.xPosSlider:SetValue(xPos)
        keystoneTab.xPosSlider._programmaticChange = false
        _G[keystoneTab.xPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(xPos)))
      end
      if keystoneTab.xPosEditBox then
        keystoneTab.xPosEditBox:SetText(tostring(math.floor(xPos)))
      end
      if keystoneTab.yPosSlider then
        keystoneTab.yPosSlider._programmaticChange = true
        keystoneTab.yPosSlider:SetValue(yPos)
        keystoneTab.yPosSlider._programmaticChange = false
        _G[keystoneTab.yPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(yPos)))
      end
      if keystoneTab.yPosEditBox then
        keystoneTab.yPosEditBox:SetText(tostring(math.floor(yPos)))
      end
      if keystoneTab.bgEnableCheck then
        keystoneTab.bgEnableCheck._programmaticChange = true
        keystoneTab.bgEnableCheck:SetChecked(showBackground)
        keystoneTab.bgEnableCheck._programmaticChange = false
      end
      if keystoneTab.useClassColorCheck then
        keystoneTab.useClassColorCheck._programmaticChange = true
        keystoneTab.useClassColorCheck:SetChecked(useClassColor)
        keystoneTab.useClassColorCheck._programmaticChange = false
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
        keystoneTab.borderEnableCheck._programmaticChange = true
        keystoneTab.borderEnableCheck:SetChecked(showBorder)
        keystoneTab.borderEnableCheck._programmaticChange = false
      end
      if keystoneTab.borderColorSwatch then
        keystoneTab.borderColorSwatch:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
      end
      if keystoneTab.borderThicknessSlider then
        keystoneTab.borderThicknessSlider:SetValue(borderThickness)
        _G[keystoneTab.borderThicknessSlider:GetName() .. "Text"]:SetText(tostring(borderThickness))
      end
    end

    -- Refresh clock font and size
    if f.tabContent and f.tabContent[6] then
      local clockFont = "Fonts\\FRIZQT__.ttf" -- Default
      local clockSize = 24 -- Default
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "clock" or tile.type == "clock" then
            clockFont = tile.font or "Fonts\\FRIZQT__.ttf"
            clockSize = tile.fontSize or tile.size or 24
            break
          end
        end
      end

      -- Update font dropdown
      if f.tabContent[6].fontDropdown then
        -- Try to get font name from discovered fonts
        local fontName = nil
        if f.tabContent[6].GetFontOptions then
          local opts = f.tabContent[6].GetFontOptions()
          for _, opt in ipairs(opts) do
            if opt.path == clockFont then
              fontName = opt.name
              break
            end
          end
        end

        -- Fallback: show path if font not found in list
        if not fontName then
          fontName = clockFont:match("([^\\]+)$") or clockFont
        end

        UIDropDownMenu_SetText(f.tabContent[6].fontDropdown, fontName)
      end

      -- Update size slider
      if f.tabContent[6].sizeSlider then
        f.tabContent[6].sizeSlider:SetValue(clockSize)
        _G[f.tabContent[6].sizeSlider:GetName() .. "Text"]:SetText(tostring(clockSize))
      end
    end

    -- Refresh crosshair size, thickness, color, outline thickness, and outline color
    if f.tabContent and f.tabContent[5] then
      local crosshairSize = 32 -- Default
      local crosshairThickness = 2 -- Default
      local crosshairColor = { r = 1, g = 0, b = 0, a = 0.9 } -- Default red
      local crosshairOutlineThickness = 0 -- Default
      local crosshairOutlineColor = { r = 0, g = 0, b = 0, a = 1 } -- Default black
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "crosshair" or tile.type == "crosshair" then
            crosshairSize = tile.size or 32
            crosshairThickness = tile.thickness or 2
            crosshairOutlineThickness = tile.outlineThickness or 0
            if tile.color then
              crosshairColor = tile.color
            end
            if tile.outlineColor then
              crosshairOutlineColor = tile.outlineColor
            end
            break
          end
        end
      end

      -- Update size slider
      if f.tabContent[5].sizeSlider then
        f.tabContent[5].sizeSlider:SetValue(crosshairSize)
        _G[f.tabContent[5].sizeSlider:GetName() .. "Text"]:SetText(tostring(crosshairSize))
      end

      -- Update thickness slider
      if f.tabContent[5].thicknessSlider then
        f.tabContent[5].thicknessSlider:SetValue(crosshairThickness)
        _G[f.tabContent[5].thicknessSlider:GetName() .. "Text"]:SetText(tostring(crosshairThickness))
      end

      -- Update color swatch
      if f.tabContent[5].colorSwatch then
        f.tabContent[5].colorSwatch:SetColorTexture(crosshairColor.r, crosshairColor.g, crosshairColor.b, crosshairColor.a)
      end

      -- Update outline thickness slider
      if f.tabContent[5].outlineThicknessSlider then
        f.tabContent[5].outlineThicknessSlider:SetValue(crosshairOutlineThickness)
        _G[f.tabContent[5].outlineThicknessSlider:GetName() .. "Text"]:SetText(tostring(crosshairOutlineThickness))
      end

      -- Update outline color swatch
      if f.tabContent[5].outlineColorSwatch then
        f.tabContent[5].outlineColorSwatch:SetColorTexture(crosshairOutlineColor.r, crosshairOutlineColor.g, crosshairOutlineColor.b, crosshairOutlineColor.a)
      end
    end

    -- Refresh char stats order list and font settings
    if f.tabContent and f.tabContent[4] then
      if f.tabContent[4].RebuildStatList then
        f.tabContent[4].RebuildStatList()
      end

      -- Refresh font settings
      local hideTitle = false
      local showTertiary = false
      local titleSize = 14
      local lineSize = 12
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "charstats" or tile.type == "charstats" then
            hideTitle = tile.hideTitle or false
            showTertiary = tile.showTertiary or false
            titleSize = tile.titleSize or 14
            lineSize = tile.lineSize or 12
            break
          end
        end
      end

      -- Update hide title checkbox
      if f.tabContent[4].hideTitleCheck then
        f.tabContent[4].hideTitleCheck:SetChecked(hideTitle)
      end

      -- Update show tertiary stats checkbox
      if f.tabContent[4].showTertiaryCheck then
        f.tabContent[4].showTertiaryCheck:SetChecked(showTertiary)
      end

      -- Update title size slider
      if f.tabContent[4].titleSizeSlider then
        f.tabContent[4].titleSizeSlider:SetValue(titleSize)
        _G[f.tabContent[4].titleSizeSlider:GetName() .. "Text"]:SetText(tostring(titleSize))
      end

      -- Update line size slider
      if f.tabContent[4].lineSizeSlider then
        f.tabContent[4].lineSizeSlider:SetValue(lineSize)
        _G[f.tabContent[4].lineSizeSlider:GetName() .. "Text"]:SetText(tostring(lineSize))
      end
    end

    -- Refresh dungeon ports orientation dropdown
    if f.tabContent and f.tabContent[7] and f.tabContent[7].orientDropdown then
      local orientation = "horizontal" -- Default
      if SkyInfoTiles.GetActiveTiles then
        local tiles = SkyInfoTiles.GetActiveTiles()
        for _, tile in ipairs(tiles) do
          if tile.key == "dungeonports" or tile.type == "dungeonports" then
            orientation = tile.orientation or "horizontal"
            break
          end
        end
      end
      UIDropDownMenu_SetText(f.tabContent[7].orientDropdown, orientation == "horizontal" and "Horizontal" or "Vertical")
    end

    -- Refresh position sliders for all tiles
    local tilesWithPosition = {
      {index = 2, key = "currencies"},
      {index = 4, key = "charstats"},
      {index = 6, key = "clock"},
      {index = 7, key = "dungeonports"}
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
          tab.xPosSlider:SetValue(xPos)
          _G[tab.xPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(xPos)))
        end
        if tab.xPosEditBox then
          tab.xPosEditBox:SetText(tostring(math.floor(xPos)))
        end
        if tab.yPosSlider then
          tab.yPosSlider:SetValue(yPos)
          _G[tab.yPosSlider:GetName() .. "Text"]:SetText(tostring(math.floor(yPos)))
        end
        if tab.yPosEditBox then
          tab.yPosEditBox:SetText(tostring(math.floor(yPos)))
        end
      end
    end

    f:Show()
  end
end

-- Slash command to open window
SLASH_SKYINFOTILES1 = "/skyinfotiles"
SLASH_SKYINFOTILES2 = "/sit"
SlashCmdList["SKYINFOTILES"] = function()
  SkyInfoTiles.ToggleOptionsWindow()
end
