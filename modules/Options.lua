-- SkyInfoTiles - Blizzard Options Panel (redirects to custom options window)

local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
if not SkyInfoTiles then return end

local function GetPanelAPI()
  -- Retail 10.0+ uses the new Settings API. Older uses InterfaceOptions.
  local hasNew = _G.Settings and _G.Settings.RegisterCanvasLayoutCategory and _G.Settings.RegisterAddOnCategory
  return hasNew and "settings" or "interfaceoptions"
end

-- Create minimal panel with just a button to open custom options
local function BuildPanel()
  local panel = CreateFrame("Frame", "SkyInfoTilesOptionsPanel")
  panel.name = "SkyInfoTiles"

  -- Title
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("SkyInfoTiles")

  -- Description
  local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  desc:SetWidth(600)
  desc:SetJustifyH("LEFT")
  desc:SetText("Click the button below to open the SkyInfoTiles configuration window.")

  -- Big button to open custom options
  local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  openBtn:SetSize(200, 40)
  openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
  openBtn:SetText("Open SkyInfoTiles Options")
  openBtn:SetScript("OnClick", function()
    if SkyInfoTiles.ToggleOptionsWindow then
      SkyInfoTiles.ToggleOptionsWindow()
    end
  end)

  -- Slash command hint
  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  hint:SetPoint("TOPLEFT", openBtn, "BOTTOMLEFT", 0, -20)
  hint:SetTextColor(0.7, 0.7, 0.7, 1)
  hint:SetText("You can also use |cFFFFD700/skyinfotiles|r or |cFFFFD700/sit|r to open options.\nRight-click the minimap button to toggle lock.")

  return panel
end

-- Register panel with Blizzard UI
local function RegisterPanel()
  local panel = BuildPanel()
  local api = GetPanelAPI()

  if api == "settings" then
    -- Modern API (10.0+)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "SkyInfoTiles")
    category.ID = "SkyInfoTilesCategory"
    Settings.RegisterAddOnCategory(category)

    -- Store open function
    SkyInfoTiles.OpenOptions = function()
      Settings.OpenToCategory("SkyInfoTilesCategory")
      Settings.OpenToCategory("SkyInfoTiles")
    end
  else
    -- Legacy API
    InterfaceOptions_AddCategory(panel)

    -- Store open function
    SkyInfoTiles.OpenOptions = function()
      -- Call twice due to Blizzard bug
      InterfaceOptionsFrame_OpenToCategory(panel)
      InterfaceOptionsFrame_OpenToCategory(panel)
    end
  end
end

-- Initialize on load
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, addon)
  if addon == ADDON_NAME then
    RegisterPanel()
    self:UnregisterEvent("ADDON_LOADED")
  end
end)
