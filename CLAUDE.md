# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

SkyInfoTiles is a World of Warcraft addon that provides modular, draggable info tiles for displaying currencies, character stats, keystones, and other game information. The addon is designed for WoW Retail 12.0+ (The War Within / Midnight).

## Architecture

### Core System (SkyInfoTiles.lua)

The main addon file provides:

- **Catalog System**: Central registry (`CATALOG`) defining available tiles with keys, types, labels, and default states
- **Profile System**: Multi-profile support with optional per-specialization profile mapping
- **Tile Registry**: `RegisterTileType(name, api)` allows modules to register tile implementations with `create(parent, cfg)` and `update(frame, cfg)` functions
- **Combat Lockdown Handling**: Deferred rebuild system (`_pendingRebuild`) to avoid protected frame operations during combat
- **SavedVariables**: `SkyInfoTilesDB` stores all settings, tiles configuration, and profiles
- **Migration System**: Automatic legacy data migration and duplicate cleanup on login

### Tile Module Pattern

Each tile module (in `modules/`) follows this pattern:

```lua
local ADDON_NAME = ...
local SkyInfoTiles = _G[ADDON_NAME]
local UI = SkyInfoTiles.UI

local API = {}

function API.create(parent, cfg)
  -- Create frame, register events, set up UI elements
  -- Return the main frame with _cfg property set
  local frame = CreateFrame("Frame", nil, parent)
  -- ... setup code ...
  return frame
end

function API.update(frame, cfg)
  -- Update frame content based on current game state
  -- Called on relevant events or manual refresh
end

function API.Destroy(frame)
  -- Optional: cleanup when tile is removed
  if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
end

SkyInfoTiles.RegisterTileType("tiletype", API)
```

### Current Tiles

- **CurrencyTile** (`currencies`): Current season currencies display with ID-based lookups
- **KeystoneTile** (`keystone`): M+ keystone display with teleport integration
- **CharStatsTile** (`charstats`): Item level and character stats with reorderable lines
- **DungeonPortsTile** (`dungeonports`): Dungeon teleport icons with cooldown tracking
- **CrosshairTile** (`crosshair`): Configurable screen crosshair overlay
- **ClockTile** (`clock`): 24-hour clock display

### Options UI (modules/Options.lua)

- Uses compatibility layer for both old (`InterfaceOptions`) and new (`Settings`) API
- Provides tile enable/disable toggles, lock control, and reset/clean utilities
- Tile-specific settings (e.g., DungeonPorts layout/scale) in same panel
- Refresh hook: `SkyInfoTiles._OptionsRefresh()` called when programmatic changes occur

## Development Workflow

### Testing in WoW

1. Edit Lua files directly in the addon directory
2. Use `/reload` in-game to reload the UI and test changes
3. Check for Lua errors in the default UI or with an error display addon (e.g., BugSack)
4. Use `/skytiles` slash commands for quick testing of tile states

### Key Slash Commands

```
/skytiles                              # Show all commands
/skytiles lock | unlock                # Toggle tile dragging
/skytiles enable <key> | disable <key> # Toggle specific tiles
/skytiles list                         # List all tiles with states
/skytiles clean                        # Fix duplicates and migrate legacy data
/skytiles reset                        # Reset active profile to catalog defaults
/skytiles scale <key> <0.5-2.0>        # Set tile scale (if supported)
/skytiles layout <key> <h|v>           # Set orientation (if supported)
/skytiles outline <none|outline|thick> # Global text outline
/skytiles profile <list|set|new|delete|assign|clear> # Profile management
```

### Adding a New Tile

1. Create `modules/YourTile.lua` with the standard module pattern
2. Implement `API.create(parent, cfg)` and `API.update(frame, cfg)`
3. Register with `SkyInfoTiles.RegisterTileType("yourtype", API)`
4. Add entry to `CATALOG` in `SkyInfoTiles.lua`:
   ```lua
   { key = "yourtile", type = "yourtype", label = "Your Tile Name", defaultEnabled = false }
   ```
5. Add file to `SkyInfoTiles.toc` load order
6. Test with `/reload` and `/skytiles enable yourtile`

### Combat Lockdown Considerations

- Frame creation/destruction/movement must NOT occur during combat
- Use `InCombatLockdown()` checks before protected operations
- Deferred rebuild system automatically handles combat state transitions
- Crosshair tile sets `_noDrag = true` to prevent drag operations

### Font Outline System

Use `SkyInfoTiles.UI.Outline(fontString, opts)` or `SkyInfoTiles.Outline(...)` for consistent text rendering:

```lua
SkyInfoTiles.Outline(myFontString, {
  weight = "OUTLINE",  -- or "THICKOUTLINE", "NONE", or nil (uses global setting)
  size = 14,
  shadow = true        -- default true
})
```

This respects the global `SkyInfoTilesDB.fontOutline` setting while allowing per-tile overrides.

## WoW API Compatibility

### Modern API Usage (12.0+)

- **Currency**: `C_CurrencyInfo.GetCurrencyInfo(id)` for reliable, ID-based lookups
- **Mythic+**: `C_MythicPlus.GetOwnedKeystoneLevel/Link/MapID()`
- **Containers**: `C_Container.GetContainerNumSlots/ItemID/ItemInfo(bag, slot)`
- **CVar**: `C_CVar.SetCVar/GetCVar/GetCVarBool(name)` with pcall wrappers
- **Settings**: `Settings.RegisterCanvasLayoutCategory` for options (with fallback)

### Settings API Compatibility

Options panel uses dual-path registration:
- New API: `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`
- Old API: `InterfaceOptions_AddCategory` (pre-10.0)
- Opening: `Settings.OpenToCategory(id)` or `InterfaceOptionsFrame_OpenToCategory(panel)`

### Protected Frames

Avoid SetPoint, Show, Hide, EnableMouse, SetMovable on combat-protected frames during combat. The core Rebuild/UpdateAll functions already handle this with lockdown checks.

## Profile System

Profiles are stored per-character in `SkyInfoTilesDB.profiles[name]`. Each profile contains:
- `tiles`: Array of tile configurations (key, type, label, enabled, point, x, y, + tile-specific settings)

Per-spec profile mapping allows automatic profile switching on specialization change:
- `SkyInfoTilesDB.enableSpecProfiles`: Master toggle
- `SkyInfoTilesDB.specProfiles[specID]`: Map of specID → profile name
- Active profile determined by `SkyInfoTiles.GetActiveProfileName()`

## Common Development Patterns

### Event Registration

Tiles should register only the events they need and use event arguments efficiently:

```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    -- init
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    API.update(self, self._cfg)
  end
end)
```

### Tooltip Integration

For interactive tiles with tooltips:

```lua
frame:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText("Title")
  GameTooltip:AddLine("Details", 1, 1, 1)
  GameTooltip:Show()
end)
frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
```

### Cleanup Pattern

Always implement cleanup for tiles with event registrations:

```lua
function API.Destroy(frame)
  if frame.UnregisterAllEvents then
    frame:UnregisterAllEvents()
  end
  -- Release any created child frames/textures as needed
end
```

## Known Issues & Quirks

- **InterfaceOptionsFrame_OpenToCategory**: Must be called twice on classic API due to Blizzard bug (already handled in Options.lua)
- **Currency Discovery**: Some currencies don't appear in `C_CurrencyInfo.GetCurrencyInfo()` until discovered; CurrencyTile shows 0 for undiscovered IDs
- **Keystone Teleport Mapping**: DungeonPortsTile uses preset maps + learned spell detection; mismatches may occur with renamed dungeons
- **Crosshair Positioning**: Crosshair tile always anchored to CENTER (0,0) and cannot be dragged

## File Structure

```
SkyInfoTiles/
├── SkyInfoTiles.lua         # Core: catalog, profiles, tile lifecycle
├── SkyInfoTiles.toc         # Addon manifest (load order matters)
├── DESCRIPTION.md           # User-facing documentation
└── modules/
    ├── Options.lua          # Settings panel (dual API support)
    ├── CurrencyTile.lua     # Current season currency display
    ├── KeystoneTile.lua     # M+ keystone tracker
    ├── CharStatsTile.lua    # Character stats
    ├── DungeonPortsTile.lua # Dungeon teleport buttons
    ├── CrosshairTile.lua    # Screen crosshair
    └── ClockTile.lua        # 24h clock
```

## Migration & Versioning

- **1.7.0**: Introduced profiles system, migrated legacy `SkyInfoTilesDB.tiles` → `profiles.Default.tiles`
- **1.7.1**: Removed deprecated tiles (healthbox, petbox, targetbox, groupbuffs) with automatic cleanup
- **1.8.2**: Renamed "season3" tile to "currencies" for season-agnostic naming
- Migration flags: `_migrated_171_removeDeprecatedTiles`, `_migrated_182_season3ToCurrencies`, `_helloShown`

Always run migrations in `PLAYER_LOGIN` event handler before `Rebuild()`.
