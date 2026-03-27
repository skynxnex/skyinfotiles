# SkyInfoTiles

**Lightweight, modular info tiles for World of Warcraft**

Small, draggable info tiles that display key game information at a glance. Each tile is focused, readable, and performance-friendly—no bulky UI, just the data you need.

## Features

### 📊 Current Season Currencies
- Shows currency amounts with hard caps and weekly progress
- Respects Warband/Character scope
- Updates automatically when you earn or spend currencies

### 🗝️ Mythic Keystone
- Displays your current keystone level and dungeon
- Click the icon to teleport (when spell is learned)
- Auto-hides when you don't have a keystone

### ⚔️ Character Stats
- Equipped item level
- Primary stat (Strength/Agility/Intellect)
- Secondary stats with rating and percentages
- Reorderable stat lines via options panel

### 🚪 Dungeon Teleports
- Clickable icons for seasonal dungeon teleports
- Shows cooldowns and tooltips
- Horizontal or vertical layout
- Adjustable scale

### 🎯 Crosshair
- Configurable overlay crosshair
- Adjustable size, thickness, and color
- Perfect for aiming or screen centering

### 🕐 24h Clock
- Clean, always-readable time display
- Multiple font options
- Customizable size and color

## Installation

1. Download the latest release
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or `/reload`
4. Configure via **Interface → AddOns → SkyInfoTiles**

## Usage

### Positioning Tiles
```
/skytiles unlock    # Enable dragging
                    # Drag tiles to desired positions
/skytiles lock      # Lock tiles in place
```

### Enable/Disable Tiles
```
/skytiles enable currencies
/skytiles disable crosshair
/skytiles list      # Show all tiles and their states
```

### Per-Tile Settings
```
/skytiles scale dungeonports 1.5          # Scale to 150%
/skytiles layout dungeonports vertical    # Change layout
/skytiles outline thick                   # Global text outline
```

### Profiles
The addon supports multiple profiles with optional per-specialization mapping:

```
/skytiles profile list                    # List all profiles
/skytiles profile new Mythic+             # Create new profile
/skytiles profile set Mythic+             # Switch to profile
/skytiles profile assign Havoc Mythic+    # Auto-switch on spec change
```

## Slash Commands

| Command | Description |
|---------|-------------|
| `/skytiles` | Show all commands |
| `/skytiles lock` / `unlock` | Toggle tile dragging |
| `/skytiles enable <key>` | Enable a tile |
| `/skytiles disable <key>` | Disable a tile |
| `/skytiles list` | List all tiles |
| `/skytiles clean` | Fix duplicates and migrate data |
| `/skytiles reset` | Reset active profile to defaults |
| `/skytiles scale <key> <0.5-2.0>` | Set tile scale |
| `/skytiles layout <key> <h\|v>` | Set tile orientation |
| `/skytiles outline <none\|outline\|thick>` | Global text outline |
| `/skytiles profile <cmd>` | Profile management |

**Available tile keys:** `currencies`, `keystone`, `charstats`, `dungeonports`, `crosshair`, `clock`

## Requirements

- **World of Warcraft:** Retail (The War Within / Midnight) 12.0+
- **API Level:** 120001+

## Performance

- Event-driven updates (no heavy polling)
- Minimal memory footprint
- Combat lockdown handling
- Proper cleanup on tile removal

## Updating for New Seasons

When a new season launches, simply update the currency IDs in `modules/CurrencyTile.lua`:

```lua
local CURRENCIES = {
  { id = 2803, label = "Undercoin" },
  { id = 3310, label = "Coffer Key Shards" },
  -- Add new season currencies here
}
```

No need to rename files or update registration—the tile is season-agnostic.

## Troubleshooting

**Duplicate tiles appearing?**
```
/skytiles clean
```

**Currency amounts wrong?**
Check the in-game Currency panel (`Shift+C`) to verify. The addon mirrors Blizzard's data.

**Settings not saving?**
Make sure you're not in combat when changing settings. Some operations are deferred until combat ends.

## Development

See [CLAUDE.md](CLAUDE.md) for development guidelines, architecture details, and contribution instructions.

## License

MIT License - See LICENSE file for details

---

**Support:** Report issues on GitHub
**Version:** 1.8.2
