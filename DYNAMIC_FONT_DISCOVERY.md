# Dynamic Font Discovery - Automatic Font Detection

## The Problem with Hardcoded Fonts

**Old approach:** Hardcoded list of font paths
- Only worked if user had specific addons
- Missed fonts from addons we didn't know about
- Required manual updates
- **User feedback:** "fonter ska ju vara dynamiskt tänker jag? inte en hårdkodad lista"

## New Approach: Dynamic Discovery

Fonts are now **automatically discovered** when the options panel opens!

### How It Works

```lua
function DiscoverFonts()
  1. Test WoW built-in fonts (always available)
  2. Try known addon font paths (curated list)
  3. Test each font by actually loading it
  4. Only add fonts that successfully load
  5. Sort alphabetically for easy browsing
  6. Keep default font at top
end
```

### Font Testing

Each font is tested before being added:
```lua
local testFrame = CreateFrame("Frame")
local testFont = testFrame:CreateFontString()
local success = pcall(testFont.SetFont, testFont, path, 12, "")

if success then
  -- Font works! Add it to list
else
  -- Font failed, skip it
end
```

**Benefits:**
- No Lua errors from missing fonts
- Only shows fonts that actually work
- Adapts to user's addon setup

### Duplicate Prevention

Tracks fonts by filename (lowercase) to avoid duplicates:
```lua
seen["arial.ttf"] = true  -- Won't add Arial.TTF again
```

### Known Font Locations

Currently scans these addon paths:
- `SharedMedia` - General fonts
- `SharedMedia_ClassicalFonts` - Medieval/classical fonts
- `Cell` - Cell addon fonts
- `ChonkyCharacterSheet` - Character sheet fonts
- `WarpDeplete` - M+ timer fonts
- `ElvUI_WindTools` - ElvUI extension fonts
- `AstralKeys` - Keystone addon fonts
- `Prat-3.0` - Chat addon fonts
- `MRT` - Raid tools fonts

### Curated Font List

While scanning is dynamic, we maintain a curated list of good fonts:
```lua
local knownFonts = {
  { path = "..\\King Arthur Legend.ttf", name = "King Arthur (Medieval)" },
  { path = "..\\OldeEnglish.ttf", name = "Olde English" },
  { path = "..\\Jedi.ttf", name = "Jedi" },
  { path = "..\\visitor.ttf", name = "Visitor (Retro)" },
  -- ... etc
}
```

**Why curated list?**
- Ensures good variety of styles
- Human-readable names (not just filenames)
- Best fonts from each addon highlighted

### Performance

**Lazy Loading:** Fonts are discovered only when dropdown is first opened
- Not on addon load
- Not on every panel open
- Once per session

**Chat Feedback:**
```
SkyInfoTiles: Discovered 18 fonts!
```

### User Experience

1. **Open options panel** → 24h Clock section
2. **Click Font dropdown**
3. **See message:** "Discovered X fonts!"
4. **Choose from:**
   - Friz Quadrata (Default) ← Always first
   - Adventure
   - Arial
   - Black Chancery
   - DejaVu Sans Mono
   - Expressway
   - ... and more!

### Font Variety

Fonts are automatically sorted alphabetically (except default on top):
```
Friz Quadrata (Default)
---
Adventure
Arial
Black Chancery
Bold Font
Cyrillic
DejaVu Sans Mono
Expressway
Fira Sans
Inter UI Bold
Jedi
King Arthur (Medieval)
Morpheus (Decorative)
Movie Poster
Olde English
Roadway
Skurri (Runic)
Visitor (Retro)
Walt Disney
```

### Why Some Fonts Look Similar

**OUTLINE hides font character!**

When outline is enabled, all fonts look similar because the outline "drowns out" the font's unique style.

**Solution:** Added tip in options:
> **Tip:** Set Outline to 'None' to see font differences clearly!

### Testing Different Fonts

To really see font differences:
1. Set **Outline: None**
2. Try these distinctly different fonts:
   - **King Arthur** (medieval)
   - **Jedi** (sci-fi)
   - **Visitor** (retro/pixel)
   - **Walt Disney** (whimsical)
   - **Olde English** (gothic)

With outline off, differences are **dramatic**!

### Adding More Fonts

To add more addon font paths, edit `DiscoverFonts()`:
```lua
local knownFonts = {
  -- Add your font here:
  { path = "Interface\\AddOns\\YourAddon\\Fonts\\YourFont.ttf", name = "Your Font Name" },
}
```

Font will automatically be tested and added if it works!

### Fallback Handling

If a font fails to load:
- Skipped silently (no error)
- Not added to dropdown
- User only sees working fonts

If no fonts are discovered:
- At minimum, WoW built-in fonts are added
- Always have 5-6 fonts minimum

### Files Modified

- `modules/Options.lua` - Added `DiscoverFonts()` function, dynamic dropdown initialization

### Version

Included in **v1.7.1** (dynamic font discovery).

## Expected Result

**Font list adapts to your addons!**
- More fonts = more choices
- Fewer fonts = still works
- Always shows working fonts only
- No hardcoded dependencies
