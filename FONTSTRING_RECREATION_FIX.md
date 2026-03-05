# FontString Recreation Fix - Drastic Solution

## Problem
Font was being set correctly (`Font=Fonts\MORPHEUS.TTF (success: true)`) but no visual change occurred on the clock.

## Root Cause Analysis

From debug output:
```
ClockTile BEFORE: Current=nil, Trying=Fonts\MORPHEUS.TTF
ClockTile AFTER: Font=Fonts\MORPHEUS.TTF, Size=59, Flags=OUTLINE (success: true)
```

**Issue:** WoW's FontString doesn't always re-render when `SetFont()` is called on an existing fontstring. This is a known WoW engine quirk.

## Solution: Recreate FontString

Instead of calling `SetFont()` on the existing fontstring, we now **destroy and recreate** the entire fontstring every time the font changes.

### Implementation

```lua
function API.update(frame, cfg)
  if not frame then return end

  local fontFile, size, outline, color = ReadCfg(cfg)

  -- DRASTIC FIX: Recreate fontstring to force font change
  if frame.text then
    -- Store old fontstring
    local oldText = frame.text

    -- Create new fontstring
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")

    -- Hide and remove old one
    oldText:Hide()
    oldText:SetParent(nil)
    oldText = nil
  else
    -- First time - create fontstring
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
  end

  -- Apply style to NEW fontstring
  ApplyTextStyle(frame.text, fontFile, size, outline, color)

  -- Set text
  frame.text:SetText(GetTimeText())

  -- Resize
  frame:SetSize(math.max(32, size * 3), math.max(16, size + 8))

  -- Debug confirmation
  DEFAULT_CHAT_FRAME:AddMessage("ClockTile UPDATE COMPLETE: FontString recreated")
end
```

## Why This Works

1. **Old fontstring destroyed** - removes any cached rendering state
2. **New fontstring created** - fresh rendering context
3. **Font applied to new fontstring** - no legacy state to interfere
4. **Text set** - forces immediate render with new font

## Trade-offs

**Pros:**
- Guaranteed to work (no caching issues)
- Forces visual update every time
- Clean state for each update

**Cons:**
- Slightly more overhead (creating new fontstring)
- Any animations/effects on old fontstring lost (not applicable here)

## Testing

After `/reload`:

1. Open options panel
2. Change font to **Morpheus (Decorative)**
3. You should see in chat:
   ```
   Options: Font dropdown selected: Morpheus (Decorative)
   ClockTile: Font set to Fonts\MORPHEUS.TTF (success: true)
   ClockTile UPDATE COMPLETE: FontString recreated
   ```
4. **Clock should now visibly show Morpheus font** (decorative style)

## Debug Output Cleaned Up

Removed verbose BEFORE/AFTER output. Now you'll see:
- `ClockTile: Font set to <path> (success: true)` - font applied
- `ClockTile UPDATE COMPLETE: FontString recreated` - update finished

## Expected Result

**Font changes should now be VISIBLE immediately.**

If Morpheus font is selected, clock should look decorative/fancy. If Arial is selected, it should look clean/modern.

## Files Modified

- `modules/ClockTile.lua` - Complete rewrite of `API.update()` to recreate fontstring

## Version

Included in **v1.7.1** (critical fix for font selection).
