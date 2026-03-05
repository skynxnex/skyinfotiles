# ClockTile Settings - Added to Options Panel

## What Was Added

User-requested settings for the 24h Clock tile are now available in the options panel.

---

## Settings Available

### 1. Font Selection
**Dropdown with 4 built-in WoW fonts:**
- Friz Quadrata (Default) - `Fonts\FRIZQT__.TTF`
- Arial Narrow - `Fonts\ARIALN.TTF`
- Morpheus - `Fonts\MORPHEUS.ttf`
- Skurri - `Fonts\SKURRI.ttf`

**Storage:** `cfg.font` (string, full path to font file)

---

### 2. Size Slider
**Range:** 6 - 128 pixels
**Default:** 24
**Step:** 1 pixel

**Storage:** `cfg.size` (number)

---

### 3. Outline Style
**Dropdown with 3 options:**
- None - No outline
- Outline - Standard outline
- Thick Outline - Thicker outline for better readability

**Storage:** `cfg.outline` (string: `""`, `"OUTLINE"`, `"THICKOUTLINE"`)

---

## How to Use

1. Open **Interface → AddOns → SkyInfoTiles**
2. Scroll down to **"24h Clock"** section (below Dungeon Teleports)
3. Adjust settings:
   - Select font from dropdown
   - Drag size slider (6-128)
   - Select outline style from dropdown
4. Changes apply immediately to the clock tile

---

## Technical Implementation

### UI Elements Created

```lua
-- Header
clockHeader = "24h Clock" (GameFontNormal)
clockHint = "Font, size, and outline apply to the '24h Clock' tile."

-- Font Dropdown
clockFontDropdown (UIDropDownMenuTemplate)
  - 4 font options with full paths
  - OnClick: updates cfg.font and rebuilds tile

// Size Slider
clockSize (OptionsSliderTemplate)
  - Range: 6-128
  - OnValueChanged: updates cfg.size and rebuilds tile

// Outline Dropdown
clockOutlineDropdown (UIDropDownMenuTemplate)
  - 3 outline options
  - OnClick: updates cfg.outline and rebuilds tile
```

### Helper Functions

```lua
local function GetClockCfg()
  return SkyInfoTiles.GetOrCreateTileCfg("clock")
end

local function ApplyClockCfg(cfg)
  -- Rebuilds and updates all tiles
  SkyInfoTiles.Rebuild()
  SkyInfoTiles.UpdateAll()
  SkyInfoTiles._OptionsRefresh()
end
```

### Refresh Logic

Added to `Refresh()` function to load current settings when panel opens:

```lua
-- ClockTile settings
local clockCfg = GetClockCfg() or {}

-- Font
local currentFont = clockCfg.font or "Fonts\\FRIZQT__.TTF"
-- ... find and set dropdown text

-- Size
local clockSz = tonumber(clockCfg.size) or 24
clockSize:SetValue(clockSz)
clockSizeValue:SetText(tostring(math.floor(clockSz)))

-- Outline
local currentOutline = clockCfg.outline or "OUTLINE"
// ... find and set dropdown text
```

---

## Saved Variables

Settings are saved in `SkyInfoTilesDB.profiles[profileName].tiles` under the clock tile entry:

```lua
{
  key = "clock",
  type = "clock",
  enabled = true,
  font = "Fonts\\FRIZQT__.TTF",      -- Font path
  size = 24,                          -- Font size (6-128)
  outline = "OUTLINE",                -- Outline style
  -- ... position data (point, x, y)
}
```

---

## Default Values

If no settings are saved, ClockTile uses these defaults (defined in `ClockTile.lua`):

```lua
DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
DEFAULT_SIZE = 24
DEFAULT_OUTLINE = "OUTLINE"
DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }  -- White
```

---

## Future Enhancements (Not Implemented Yet)

### Color Picker
Could add a color picker button:
```lua
-- Color button
local clockColorBtn = CreateFrame("Button", nil, panel)
clockColorBtn:SetSize(24, 24)
-- ... color picker logic with ColorPickerFrame
```

This would set `cfg.color = { r, g, b, a }`.

---

## Testing

After `/reload`, test:
1. ✅ Open options panel
2. ✅ Change font → clock updates immediately
3. ✅ Change size → clock updates immediately
4. ✅ Change outline → clock updates immediately
5. ✅ `/reload` → settings persist

---

## Compatibility

- **WoW Version:** 12.0.1+
- **Backward Compatible:** Yes (existing clock tiles keep their settings)
- **Profile Support:** Yes (each profile has independent clock settings)

---

## Known Limitations

1. **Font List is Hardcoded**
   - Only 4 built-in WoW fonts available
   - Custom fonts not supported (would require file path input)

2. **No Color Picker**
   - Color is fixed to white (DEFAULT_COLOR)
   - Can be added in future update if requested

3. **No Preview**
   - Changes apply to actual tile (no separate preview)
   - Tile must be enabled to see changes

---

## Files Modified

- `modules/Options.lua` - Added ClockTile settings UI and logic

---

## Version

Added in **v1.7.1** (no version bump needed, included in current release).
