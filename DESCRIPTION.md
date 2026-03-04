# SkyInfoTiles

Small, lightweight info tiles you can place anywhere on your screen. Each tile is focused, readable, and performance‑friendly—ideal for getting key data at a glance without bulky UI.

## What’s included (current)

- Seasonal Currencies
  - Shows current amounts and hard caps for the season’s currencies (plus weekly progress when available).
  - Warband/Character scope respected where the game supports it.
- Mythic Keystone
  - Detects the keystone in your bags: big level number and the dungeon name, with a dungeon icon when available.
  - When the corresponding teleport spell is known, left‑clicking the icon will cast it.
- Character Stats
  - Equipped item level, your primary stat (Strength/Agility/Intellect), and secondary stats with both rating and percent (Crit, Haste, Mastery, Versatility).
  - Versatility shows both damage/heal increase and damage reduction.
- Dungeon Teleports
  - Clickable icons for seasonal dungeon teleports (shows cooldown and tooltip on hover).
  - Layout can be horizontal/vertical; per‑tile scale supported.
- Crosshair
  - A configurable overlay crosshair (size, thickness, color).
- 24h Clock
  - Clean, always‑readable 24‑hour time display.

## Drag & Lock

- Drag tiles to position them.
- Lock when you’re done to prevent accidental moves.

## Sharp Text

- Global outline option (via slash command) for improved readability on any background.

## Commands

- `/skytiles` — show commands
- `/skytiles lock`  /  `/skytiles unlock` — toggle drag
- `/skytiles enable <key>` / `/skytiles disable <key>` — enable/disable tiles

  Keys (current): `season3`, `keystone`, `charstats`, `crosshair`, `clock`, `dungeonports`

- `/skytiles layout <key> <horizontal|vertical>` — per‑tile layout (primarily for `dungeonports`)
- `/skytiles scale <key> <0.5-2.0>` — per‑tile scale (supported by tiles that implement it, e.g. `keystone`, `dungeonports`)
- `/skytiles outline <none|outline|thick>` — global text outline weight

## Settings (Interface → AddOns → SkyInfoTiles)

- Enable/disable predefined tiles (only the currently supported tiles are listed)
- Profiles (create/copy/rename/delete, optional per‑spec profile mapping)
- Dungeon Teleports
  - Layout (horizontal/vertical)
  - Scale (0.5–2.0)
- Character Stats
  - Reorder the lines (Item Level, Primary, Crit, Haste, Mastery, Versatility)
- Crosshair
  - Size, thickness, color
- 24h Clock
  - Size, font, outline, and color

Note: Health Box, Target Box, Pet Box, and Group Buffs tiles have been removed.

## Scope

- Default scope is Character.
- Warband scope can be respected by currency tiles when active (where supported by the client API).

## Requirements

- World of Warcraft (Retail) 12.0+

## Performance

- Tiles update on relevant in‑game events and via right‑click refresh.
- No heavy polling loops; designed to remain lightweight.

## Localization

- UI strings are English.
- Currency names are matched against the in‑game Currency panel for reliability; ID‑based reads are preferred where possible.

## Troubleshooting

- Seeing duplicate tiles or odd entries? Run `/skytiles clean` or use Reset in the options to restore catalog defaults.
- Currency totals look off? Ensure the in‑game Currency panel shows the same entries (this tile mirrors Blizzard’s list where needed).

## Credits & License

- Addon code © 2026 SkyInfoTiles authors.
- Suggested license: MIT (replace with your preferred license as needed).
