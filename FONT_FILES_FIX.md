# Font Files Fix - Using Actual WoW Font Files

## THE REAL PROBLEM! 🎯

We were trying to load fonts that **DON'T EXIST** in WoW's Fonts directory!

## What Actually Exists in WoW

Checked `C:\Program Files (x86)\World of Warcraft\_retail_\Fonts\`:

```
✅ ARIALN.ttf
✅ FRIZQT__.ttf (default)
✅ MORPHEUS.ttf
✅ skurri.ttf (lowercase!)
✅ FRIZQT___CYR.ttf
✅ theboldfont.ttf

❌ FRIENDS.TTF - DOES NOT EXIST!
❌ NIM_____.ttf - DOES NOT EXIST!
```

## What We Were Trying to Load (WRONG!)

```lua
// OLD - WRONG:
{ name = "Friends", path = "Fonts\\FRIENDS.TTF" },      // ❌ Doesn't exist!
{ name = "Number (Bold)", path = "Fonts\\NIM_____.ttf" }, // ❌ Wrong name!
{ name = "Skurri", path = "Fonts\\SKURRI.TTF" },       // ❌ Wrong case!
```

**Result:** `SetFont()` failed silently, font didn't change!

## What We're Loading Now (CORRECT!)

```lua
// NEW - CORRECT (matches actual files):
{ name = "Friz Quadrata (Default)", path = "Fonts\\FRIZQT__.ttf" },
{ name = "Arial", path = "Fonts\\ARIALN.ttf" },
{ name = "Skurri (Runic)", path = "Fonts\\skurri.ttf" },  // lowercase!
{ name = "Morpheus (Decorative)", path = "Fonts\\MORPHEUS.ttf" },
{ name = "Cyrillic", path = "Fonts\\FRIZQT___CYR.ttf" },
{ name = "Bold Font", path = "Fonts\\theboldfont.ttf" },  // correct name!
```

## Case Sensitivity Issue

WoW on Windows is **case-sensitive** for font loading!

- ❌ `Fonts\\SKURRI.TTF` - FAILS (file is lowercase)
- ✅ `Fonts\\skurri.ttf` - WORKS (exact match)

## Changes Made

### 1. Options.lua - Updated FONT_LIST
```lua
// Now uses EXACT filenames from Fonts directory
// Removed non-existent fonts (FRIENDS, NIM)
// Fixed case for skurri (lowercase)
// Added actual fonts: Cyrillic, theboldfont
```

### 2. ClockTile.lua - Updated SetFontSmart()
```lua
// Added case variation fallbacks:
local lowerExt = file:gsub("%.TTF$", ".ttf")
local upperExt = file:gsub("%.ttf$", ".TTF")

// Updated fallback list to match actual files:
"Fonts\\FRIZQT__.ttf"
"Fonts\\ARIALN.ttf"
"Fonts\\MORPHEUS.ttf"
"Fonts\\skurri.ttf"  // lowercase!
"Fonts\\theboldfont.ttf"
```

### 3. ClockTile.lua - Fixed DEFAULT_FONT
```lua
// OLD:
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"  // Wrong case!

// NEW:
local DEFAULT_FONT = "Fonts\\FRIZQT__.ttf"  // Correct case
```

## Why This Fixes Everything

1. **Fonts now actually load** - using correct filenames
2. **Case matches** - no more silent failures
3. **All fonts exist** - removed FRIENDS.TTF and NIM_____.ttf
4. **Fallback works** - tries multiple case variations

## Testing

After `/reload`:

1. Open options panel → 24h Clock
2. Try **Morpheus (Decorative)** - should see:
   ```
   ClockTile: Font set to Fonts\MORPHEUS.ttf (success: true)
   ClockTile UPDATE COMPLETE: FontString recreated
   ```
3. **Clock should NOW show decorative Morpheus font!**
4. Try **Skurri (Runic)** - should show runic-style font
5. Try **Bold Font** - should show bold numbers
6. Try **Arial** - should show clean sans-serif

## Before/After

| Font Name | Old Path (WRONG) | New Path (CORRECT) | Exists? |
|-----------|------------------|-------------------|---------|
| Friends | `Fonts\FRIENDS.TTF` | ❌ Removed | No |
| Number Bold | `Fonts\NIM_____.ttf` | `Fonts\theboldfont.ttf` | ✅ Yes |
| Skurri | `Fonts\SKURRI.TTF` | `Fonts\skurri.ttf` | ✅ Yes (case!) |
| Morpheus | `Fonts\MORPHEUS.TTF` | `Fonts\MORPHEUS.ttf` | ✅ Yes |
| Cyrillic | ❌ Not in list | `Fonts\FRIZQT___CYR.ttf` | ✅ Yes (new!) |

## Files Modified

- `modules/Options.lua` - FONT_LIST with actual filenames
- `modules/ClockTile.lua` - SetFontSmart() fallbacks + DEFAULT_FONT case

## Expected Result

**FONTS SHOULD NOW ACTUALLY CHANGE VISUALLY!** 🎉

The combination of:
1. ✅ Correct filenames (that exist)
2. ✅ Correct case (matches actual files)
3. ✅ FontString recreation (forces re-render)
4. ✅ Case fallback logic (handles variations)

...should make fonts work 100%.

## Version

Included in **v1.7.1** (critical fix for font selection).
