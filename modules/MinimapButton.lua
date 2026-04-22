local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]

-- LibDBIcon integration for minimap button
local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

if not LDB or not LDBIcon then
  return -- Libraries not loaded
end

-- Create LibDataBroker object
local dataObj = LDB:NewDataObject("SkyInfoTiles", {
  type = "launcher",
  icon = "Interface\\Icons\\INV_Misc_Map_01",
  OnClick = function(self, button)
    if button == "LeftButton" then
      -- Open options window
      if SkyInfoTiles.ToggleOptionsWindow then
        SkyInfoTiles.ToggleOptionsWindow()
      end
    elseif button == "RightButton" then
      -- Toggle lock
      SkyInfoTiles.ToggleLock()
    end
  end,
  OnTooltipShow = function(tooltip)
    if not tooltip or not tooltip.AddLine then return end
    tooltip:SetText("SkyInfoTiles")
    tooltip:AddLine(" ", 1, 1, 1)
    tooltip:AddLine("|cFFFFFFFFLeft-click:|r Open Options", 0.2, 1, 0.2)
    tooltip:AddLine("|cFFFFFFFFRight-click:|r Toggle Lock", 0.2, 1, 0.2)
    tooltip:Show()
  end,
})

-- Initialize minimap button
local function InitMinimapButton()
  -- Ensure DB structure
  if not SkyInfoTilesDB then
    SkyInfoTilesDB = {}
  end
  if not SkyInfoTilesDB.minimap then
    SkyInfoTilesDB.minimap = { hide = false }
  end

  -- Register with LibDBIcon
  LDBIcon:Register("SkyInfoTiles", dataObj, SkyInfoTilesDB.minimap)
end

-- Initialize on load
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    InitMinimapButton()
  end
end)

-- Export functions
SkyInfoTiles.ShowMinimapButton = function()
  if SkyInfoTilesDB and SkyInfoTilesDB.minimap then
    SkyInfoTilesDB.minimap.hide = false
    LDBIcon:Show("SkyInfoTiles")
  end
end

SkyInfoTiles.HideMinimapButton = function()
  if SkyInfoTilesDB and SkyInfoTilesDB.minimap then
    SkyInfoTilesDB.minimap.hide = true
    LDBIcon:Hide("SkyInfoTiles")
  end
end
