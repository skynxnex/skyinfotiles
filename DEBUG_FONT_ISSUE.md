# Font Selection Debug - No Visual Change

## Issue
User selects different fonts from dropdown and sees success message in chat:
```
ClockTile: Font changed to: Fonts\FRIENDS.TTF (success: true)
```

But no visual change is observed on the clock.

## Hypothesis

### 1. Font Similarity
Some WoW fonts look very similar, especially with outline enabled:
- FRIZQT__.TTF (default)
- FRIENDS.TTF
- ARIALN.TTF

May be hard to distinguish visually.

### 2. SetFont Success but Not Applied
`SetFontSmart()` returns `true` (font loaded successfully) but the visual update doesn't happen.

## Enhanced Debug Output

### Added to ClockTile.lua:
```lua
// BEFORE SetFont:
DEFAULT_CHAT_FRAME:AddMessage("ClockTile BEFORE: Current=<font>, Trying=<new_font>")

// AFTER SetFont:
local newFont, newSize, newFlags = fs:GetFont()
DEFAULT_CHAT_FRAME:AddMessage("ClockTile AFTER: Font=<actual_font>, Size=<size>, Flags=<flags>")
```

### Added to Options.lua:
```lua
// Dropdown selection:
"Options: Font dropdown selected: <name> (<path>)"
"Options: Calling ApplyClockCfg to rebuild tile..."
"Options: ApplyClockCfg complete. Tile should be rebuilt."
```

## Testing Steps

1. `/reload` in WoW
2. Enable ClockTile if not already enabled
3. Open Interface → AddOns → SkyInfoTiles
4. Change font to **Morpheus (Decorative)** - this is VERY different visually
5. Check chat for messages:
   ```
   Options: Font dropdown selected: Morpheus (Decorative) (Fonts\MORPHEUS.TTF)
   Options: Calling ApplyClockCfg to rebuild tile...
   ClockTile BEFORE: Current=Fonts\FRIZQT__.TTF, Trying=Fonts\MORPHEUS.TTF
   ClockTile AFTER: Font=Fonts\MORPHEUS.TTF, Size=24, Flags=OUTLINE
   Options: ApplyClockCfg complete. Tile should be rebuilt.
   ```

6. **Look at clock** - if Morpheus, should be decorative/fancy style

## Expected Results

### If font DOES change visually:
- Problem was font similarity
- Solution: Use more distinct fonts (Morpheus, Skurri)

### If font does NOT change visually:
- Check "AFTER" message - what font is actually set?
- If AFTER shows correct font but visual doesn't match:
  - Problem: fontstring not being rendered/updated
  - Solution: Force a re-render after SetFont

## Potential Fixes

### Fix 1: Force Text Update After Font Change
```lua
function API.update(frame, cfg)
  local fontFile, size, outline, color = ReadCfg(cfg)
  ApplyTextStyle(frame.text, fontFile, size, outline, color)

  -- Force text update to trigger re-render
  frame.text:SetText("")
  frame.text:SetText(GetTimeText())

  frame:SetSize(math.max(32, size * 3), math.max(16, size + 8))
end
```

### Fix 2: Recreate FontString
```lua
function API.update(frame, cfg)
  -- Destroy and recreate fontstring to force font change
  if frame.oldText then
    frame.oldText:Hide()
    frame.oldText:SetParent(nil)
  end

  frame.oldText = frame.text
  frame.text = frame:CreateFontString(nil, "OVERLAY")
  frame.text:SetPoint("CENTER")

  local fontFile, size, outline, color = ReadCfg(cfg)
  ApplyTextStyle(frame.text, fontFile, size, outline, color)
  frame.text:SetText(GetTimeText())
end
```

### Fix 3: Use Different Font Loading Method
```lua
// Try C_Font API if available (WoW 12.0+)
if C_Font and C_Font.SetFont then
  C_Font.SetFont(fs, fontFile, size, outline)
end
```

## Current Font List (Updated)

Reduced to 6 most distinct fonts:
1. Friz Quadrata (Default) - Standard WoW font
2. Arial - Clean sans-serif
3. Skurri - Runic style
4. **Morpheus (Decorative)** - VERY different (fancy/decorative)
5. Friends - Friendly style
6. Number (Bold) - Bold numbers

## Next Steps

1. User tests with Morpheus font (most distinct)
2. User reports back exact chat messages
3. User reports if visual changed
4. Based on results, apply appropriate fix

## Files Modified

- `modules/ClockTile.lua` - Enhanced debug output (BEFORE/AFTER)
- `modules/Options.lua` - Enhanced debug output (dropdown selection) + reduced font list to 6
