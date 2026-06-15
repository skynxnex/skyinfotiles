local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]

-- Tab creation functions to reduce local variable count in main function
local OptionsTabCreators = {}

-- Store tab content creators here
-- Each function receives (scrollChild, yOffset) and returns updated yOffset
-- This file will be expanded with individual tab creators

SkyInfoTiles.OptionsTabCreators = OptionsTabCreators

return OptionsTabCreators
