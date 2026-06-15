# SkyInfoTiles Architecture

## Options Window Structure

### Local Variable Limit
Lua 5.1 (used by WoW) has a **hard limit of 200 local variables per function**. To avoid hitting this limit, the options window is split into multiple functions.

### Current Structure
- `CreateOptionsWindow()` - Main frame setup + Tabs 1-7
- `CreateOptionsWindow_Part2()` - Tabs 8-10

### Adding New Tabs

When adding a new tab, follow these guidelines:

#### 1. Check Current Variable Count
Before adding a new tab, estimate how many local variables it will add:
- Each `CreateFrame()` call = 1 variable
- Each label, slider, checkbox, button = 1 variable
- Each callback closure may reference several variables

#### 2. If Approaching 200 Variables
If the current function is approaching ~180 variables, create a new part:

```lua
-- In CreateOptionsWindow or CreateOptionsWindow_PartN:
  -- Call next part
  CreateOptionsWindow_Part3(contentArea, tabContent, f)
  return f
end

-- New function:
local function CreateOptionsWindow_Part3(contentArea, tabContent, f)
  -- Continue with new tabs...
end
```

#### 3. Best Practice: One Function Per Complex Tab
For very complex tabs (100+ lines), consider extracting to a dedicated function:

```lua
-- At top of file with other helpers:
local function CreateKeystoneTab(contentArea, tabContent)
  local tab = CreateFrame("Frame", nil, contentArea)
  tab:SetAllPoints()
  tab:Hide()
  tabContent[3] = tab
  
  -- All keystone-specific code here...
  
  return tab
end

-- In CreateOptionsWindow:
  -- === TAB 3: KEYSTONE ===
  local keystoneTab = CreateKeystoneTab(contentArea, tabContent)
```

#### 4. Variable Reuse Pattern
For simple UI elements that don't need to be saved, reuse a temp variable:

```lua
local temp  -- Declare once at function start

-- Later, reuse for transient elements:
temp = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
temp:SetPoint("TOPLEFT", 10, yOffset)
temp:SetText("Some Label")
-- Don't save temp to tab, just use it for positioning
```

#### 5. Monitoring
To check variable count, search for `local ` in the function:
```bash
grep -c "^  local " OptionsWindow.lua
```

### Tab Complexity Guidelines
- **Simple tab** (< 50 lines): Keep inline
- **Medium tab** (50-200 lines): Keep inline or extract if approaching limit
- **Complex tab** (200+ lines): Extract to dedicated function

### Current Tab Sizes (reference)
- Tab 1 (General): 44 lines ✓
- Tab 2 (Currencies): 275 lines ⚠️
- Tab 3 (Keystone): 715 lines ❌ Should extract
- Tab 4 (Char Stats): 349 lines ⚠️
- Tab 5 (Crosshair): 441 lines ⚠️
- Tab 6 (Clock): 182 lines ✓
- Tab 7 (Dungeon Ports): 120 lines ✓
- Tab 8 (BuffTracker): 566 lines ❌ Should extract
- Tab 9 (InfoBar): 451 lines ⚠️
- Tab 10 (Profiles): varies ✓

✓ = Good size
⚠️ = Consider extracting
❌ = Should be extracted

### Future Improvement (Optional)
Consider creating `modules/OptionsWindowTabs/` folder with one file per tab:
```
modules/OptionsWindowTabs/
  ├── General.lua
  ├── Currencies.lua
  ├── Keystone.lua
  ├── CharStats.lua
  └── ...
```

Each file exports a `CreateTab(contentArea, tabContent)` function that `OptionsWindow.lua` imports and calls.
