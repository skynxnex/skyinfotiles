-- Tab creator functions to reduce local variable count in CreateOptionsWindow
local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]

local TabCreators = {}

-- Forward declarations of helper functions that tabs need
local CreatePositionSliders

-- === TAB 1: GENERAL ===
function TabCreators.CreateGeneralTab(contentArea, tabContent)
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
  cleanBtn:SetText("Clean Database")
  cleanBtn:SetScript("OnClick", function()
    if SkyInfoTiles.CleanProfile then
      SkyInfoTiles.CleanProfile()
      print("|cff66ccffSkyInfoTiles:|r Cleaned inactive data from profile")
    end
  end)

  return generalTab
end

-- Set helper function reference
function TabCreators.SetHelpers(posSliderFunc)
  CreatePositionSliders = posSliderFunc
end

return TabCreators
