# Options Panel Layout Fix - Scrolling & Font Issues

## Problems Fixed

### 1. Font Dropdown Not Working ❌ → ✅
**Problem:** Selecting a font from dropdown did nothing - clock didn't change.

**Root Cause:**
- `UIDropDownMenu_SetText()` was called AFTER `ApplyClockCfg()`
- `info.checked` was not set, so dropdown showed no selection

**Fix:**
```lua
// Before:
info.func = function()
  local cfg = GetClockCfg()
  if cfg then
    cfg.font = font.path
    ApplyClockCfg(cfg)  // Rebuilds tile
  end
  UIDropDownMenu_SetText(clockFontDropdown, font.name)  // Too late!
end

// After:
info.checked = (currentFont == font.path)  // Show current selection
info.func = function()
  local cfg = GetClockCfg()
  if cfg then
    cfg.font = font.path
    UIDropDownMenu_SetText(clockFontDropdown, font.name)  // Set text FIRST
    ApplyClockCfg(cfg)  // Then rebuild
  end
end
```

**Impact:** Font changes now work immediately and show checkmark on current font.

---

### 2. Too Few Fonts ❌ → ✅
**Problem:** Only 4 fonts available.

**Fix:** Added 3 more fonts (total 7):
```lua
{ name = "Friz Quadrata (Default)", path = "Fonts\\FRIZQT__.TTF" },
{ name = "Arial", path = "Fonts\\ARIALN.TTF" },
{ name = "Skurri", path = "Fonts\\SKURRI.TTF" },
{ name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
{ name = "Friends", path = "Fonts\\FRIENDS.TTF" },         // NEW
{ name = "Fancy", path = "Interface\\AddOns\\Blizzard_ChatFrameBase\\Fonts\\FRIZQT___CYR.TTF" },  // NEW
{ name = "Number (Bold)", path = "Fonts\\NIM_____.ttf" },  // NEW
```

**Impact:** More font variety for clock customization.

---

### 3. Options Panel Too Tall ❌ → ✅
**Problem:** Panel grew outside visible area, scrollbars visible but not usable.

**Root Cause:**
- DungeonPorts and ClockTile settings were anchored to `panel` (outside scroll area)
- ScrollFrame was only 220px tall
- Settings didn't scroll

**Fix:**
1. **Increased scrollFrame height:** 220px → 450px
2. **Moved ALL settings inside scrollFrame content:**
   - Tile checkboxes (was already inside)
   - DungeonPorts settings (moved from `panel` to `content`)
   - ClockTile settings (moved from `panel` to `content`)

**Before:**
```
Panel (fixed height)
├─ Title, buttons, etc.
├─ ScrollFrame (220px)
│  └─ Tile checkboxes ← only this scrolled
├─ DungeonPorts settings ← OUTSIDE scroll area
└─ ClockTile settings    ← OUTSIDE scroll area, went off-screen
```

**After:**
```
Panel (fixed height)
├─ Title, buttons, etc.
└─ ScrollFrame (450px) ← BIGGER
   └─ Content (scrollable)
      ├─ Tile checkboxes
      ├─ DungeonPorts settings ← NOW INSIDE
      └─ ClockTile settings    ← NOW INSIDE
```

**Impact:**
- All settings now scrollable
- No content cut off
- Scrollbars actually work

---

### 4. Layout Improvements ✅
**Added:**
- Section headers for clarity ("Tile Toggles", "Dungeon Teleports", "24h Clock")
- Better spacing between sections
- Dynamic positioning (elements positioned relative to previous element)
- Auto-calculated content height based on number of tiles

**Layout Flow:**
```
Settings (main header)
└─ ScrollFrame
   └─ Content
      ├─ Tile Toggles (header)
      ├─ [description]
      ├─ ☑ Season 1 Currencies
      ├─ ☑ Mythic Keystone
      ├─ ☑ Character Stats
      ├─ ☑ Crosshair
      ├─ ☑ 24h Clock
      ├─ ☑ Dungeon Teleports
      ├─ ────────────────────
      ├─ Dungeon Teleports (header)
      ├─ ☐ Horizontal ☑ Vertical
      ├─ Scale: [slider]
      ├─ ────────────────────
      ├─ 24h Clock (header)
      ├─ Font: [dropdown ▼]
      ├─ Size: [slider]
      └─ Outline: [dropdown ▼]
```

---

## Code Changes

### Parent Changes
All ClockTile and DungeonPorts widgets changed from `panel` to `content`:

```lua
// Before:
local dpHeader = panel:CreateFontString(...)
local clockHeader = panel:CreateFontString(...)
local clockFontDropdown = CreateFrame(..., panel, ...)

// After:
local dpHeader = content:CreateFontString(...)
local clockHeader = content:CreateFontString(...)
local clockFontDropdown = CreateFrame(..., content, ...)
```

### BuildTileList() Refactored
- Checkboxes now positioned relative to `listDivider` (not content TOPLEFT)
- DungeonPorts header positioned relative to last checkbox
- ClockTile header positioned relative to dpScale
- Content height calculated dynamically

---

## Testing

After `/reload`, verify:
1. ✅ Open options panel
2. ✅ Scroll down - all settings visible
3. ✅ Change font from dropdown → clock updates
4. ✅ Font dropdown shows checkmark on current font
5. ✅ Change size → clock updates
6. ✅ Change outline → clock updates
7. ✅ All settings scroll smoothly
8. ✅ No content cut off at bottom

---

## Before/After Comparison

| Issue | Before | After |
|-------|--------|-------|
| Font dropdown working | ❌ No change | ✅ Changes immediately |
| Font selection shown | ❌ No checkmark | ✅ Checkmark on current |
| Number of fonts | 4 | 7 |
| Settings visible | ❌ Cut off | ✅ All scrollable |
| Scrollbars functional | ❌ Didn't scroll settings | ✅ Scroll everything |
| Content height | 220px (too small) | 450px (fits all) |

---

## Files Modified

- `modules/Options.lua` - Major refactor of layout and dropdown logic

---

## Version

Included in **v1.7.1** (no version bump needed).
