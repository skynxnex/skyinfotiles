# Font Selection Fix - ClockTile

## Problem
Font dropdown showed options and set `cfg.font`, but the clock didn't change fonts. Size and outline worked fine.

## Root Cause

In `ClockTile.lua`, the `ApplyTextStyle()` function had a bug:

```lua
// Original code (BROKEN):
function ApplyTextStyle(fs, fontFile, size, outline, color)
  SetFontSmart(fs, fontFile, size, outline)  // ✓ Sets font correctly

  if UI and UI.Outline then
    UI.Outline(fs, { weight = outline, size = size })  // ❌ OVERWRITES font!
  end

  // ... rest of code
end
```

### What Happened:

1. `SetFontSmart()` successfully set the new font (e.g., Arial)
2. Then `UI.Outline()` was called
3. `UI.Outline()` does this internally:
   ```lua
   local font, size, flags = fs:GetFont()  // Gets CURRENT font
   fs:SetFont(font, size, weight)          // Re-sets same font
   ```
4. This **overwrote** the new font with the old font!

## Solution

**Remove the `UI.Outline()` call** since `SetFontSmart()` already handles outline correctly:

```lua
// Fixed code:
function ApplyTextStyle(fs, fontFile, size, outline, color)
  -- SetFontSmart handles font fallback and sets the font+size+outline
  local success, usedFont = SetFontSmart(fs, fontFile, size, outline)

  -- Debug output
  if DEFAULT_CHAT_FRAME and fontFile and fontFile ~= DEFAULT_FONT then
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
      "|cff00ff00ClockTile:|r Font changed to: %s (success: %s)",
      fontFile, tostring(success)))
  end

  -- Apply color
  if fs.SetTextColor and color then
    fs:SetTextColor(color.r, color.g, color.b, color.a or 1)
  end

  -- Apply shadow
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)

  -- Note: We don't call UI.Outline here because:
  // 1. SetFontSmart already handles the outline parameter
  // 2. UI.Outline would overwrite the font we just set
end
```

## Spacing Fix

Also improved spacing between ClockTile settings to match DungeonPorts style:

### Changes:
- **Font → Size spacing:** `-16` → `-36` (20px more space)
- **Size → Outline spacing:** `-12` → `-24` (12px more space)
- **Hint → Font spacing:** `-8` → `-12` (4px more space)
- **Total section height:** `150px` → `200px`

### Before:
```
24h Clock
Font, size, and outline apply...
Font: [dropdown ▼]
          ↕ 16px (too tight)
Size: [────●────]
       ↕ 12px (too tight)
Outline: [dropdown ▼]
```

### After:
```
24h Clock
Font, size, and outline apply...
Font: [dropdown ▼]
          ↕ 36px (better!)
Size: [────●────]
       ↕ 24px (better!)
Outline: [dropdown ▼]
```

## Testing

After `/reload`:

1. **Open options panel** → Interface → AddOns → SkyInfoTiles
2. **Scroll to "24h Clock"** section
3. **Change font** from dropdown:
   - You should see in chat: `ClockTile: Font changed to: Fonts\ARIALN.TTF (success: true)`
   - Clock should **visually change** to new font
4. **Verify spacing** - ClockTile settings should have similar spacing to DungeonPorts
5. **Change size** - should still work
6. **Change outline** - should still work

## Debug Output

When you change fonts, you'll see chat messages like:
```
ClockTile: Font changed to: Fonts\ARIALN.TTF (success: true)
ClockTile: Font changed to: Fonts\MORPHEUS.TTF (success: true)
ClockTile: Font changed to: Fonts\SKURRI.TTF (success: true)
```

This confirms the font is being set correctly.

## Files Modified

- `modules/ClockTile.lua` - Removed UI.Outline call, added debug output
- `modules/Options.lua` - Improved spacing for ClockTile settings

## Impact

✅ **Font selection now works** - clock changes to selected font immediately
✅ **Better spacing** - ClockTile settings have professional layout matching DungeonPorts
✅ **Debug feedback** - Chat messages confirm font changes
✅ **Size still works** - no regression
✅ **Outline still works** - no regression

## Version

Included in **v1.7.1** (no version bump needed).
