# SkyInfoTiles - Code Analysis & Issues

**Datum:** 2026-03-05
**Analyzed:** Complete addon codebase

## Sammanfattning

Addonen är generellt välskriven med bra combat lockdown-hantering och modern WoW API-användning. Det finns dock **6 kategorier av problem** som bör åtgärdas för att förhindra memory leaks, Lua-errors och potentiell taint.

---

## 🔴 Kritiska Problem

### 1. **Event Cleanup Saknas (Memory Leak)**

**Filer:** `CharStatsTile.lua`, `Season3Tile.lua`

**Problem:** Events registreras men avregistreras aldrig i `Destroy()`. Detta orsakar memory leaks när tiles byggs om (profil-byte, /reload, etc).

**CharStatsTile.lua** (rad 172-182):
```lua
-- Events registrerade:
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("COMBAT_RATING_UPDATE")
f:RegisterEvent("MASTERY_UPDATE")
f:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
f:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("UNIT_STATS")

-- Men Destroy() är tom:
function f:Destroy() end  -- ❌ Ingen cleanup
```

**Season3Tile.lua** (rad 189-194, 199):
```lua
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEVEL_UP")
-- ...
function f:Destroy() end  -- ❌ Ingen cleanup
```

**Konsekvens:**
- Varje gång en tile byggs om (spec-switch, profile-switch) läcker den gamla framen
- Events fortsätter att trigga på döda frames
- Memory-användning växer över tid

**Fix:**
```lua
function f:Destroy()
  if self.UnregisterAllEvents then
    self:UnregisterAllEvents()
  end
end
```

---

### 2. **C_Timer Används Utan Existenskontroll**

**Fil:** `ClockTile.lua` (rad 101)

**Problem:**
```lua
f._ticker = C_Timer.NewTicker(1, RefreshText)  -- ❌ Ingen check om C_Timer finns
```

**Konsekvens:**
- Lua error om C_Timer av någon anledning inte är tillgängligt
- Addon-load failure

**Fix:**
```lua
if C_Timer and C_Timer.NewTicker then
  f._ticker = C_Timer.NewTicker(1, RefreshText)
else
  -- Fallback: OnUpdate-baserad ticker
  f:SetScript("OnUpdate", function(self, elapsed)
    self._elapsed = (self._elapsed or 0) + elapsed
    if self._elapsed >= 1 then
      self._elapsed = 0
      RefreshText()
    end
  end)
end
```

**Destroy() saknar också OnUpdate-cleanup:**
```lua
function f:Destroy()
  if f._ticker and f._ticker.Cancel then
    f._ticker:Cancel()
    f._ticker = nil
  end
  -- ❌ Saknas: OnUpdate cleanup
  if self.SetScript then
    self:SetScript("OnUpdate", nil)
  end
end
```

---

### 3. **Saknade pcall() Runt Känsliga API-Anrop**

**Fil:** `Options.lua`, `SkyInfoTiles.lua`

**Options.lua** (rad 281-302):
```lua
function SkyInfoTiles.OpenOptions()
  local api = GetPanelAPI()
  if api == "settings" and _G.Settings and _G.Settings.OpenToCategory then
    if settingsCategory then
      local id = nil
      if type(settingsCategory.GetID) == "function" then
        id = settingsCategory:GetID()  -- ❌ Ingen pcall
      elseif settingsCategory.ID then
        id = settingsCategory.ID
      end
      if id then
        _G.Settings.OpenToCategory(id)  -- ❌ Ingen pcall (kan tainta)
      else
        pcall(_G.Settings.OpenToCategory, settingsCategory)
      end
    end
  elseif _G.InterfaceOptionsFrame_OpenToCategory then
    _G.InterfaceOptionsFrame_OpenToCategory(panel)  -- ❌ Ingen pcall
    _G.InterfaceOptionsFrame_OpenToCategory(panel)
  end
end
```

**SkyInfoTiles.lua** (rad 395-424):
```lua
function SetMovable(f)
  -- ...
  if f.EnableMouse then f:EnableMouse(unlocked) end  -- ❌ Ingen pcall
  if f.SetMovable then f:SetMovable(unlocked) end    -- ❌ Ingen pcall
  if unlocked and f.RegisterForDrag then
    f:RegisterForDrag("LeftButton")  -- ❌ Ingen pcall
```

**Konsekvens:**
- Protected frame operations kan orsaka Lua errors
- Taint kan sprida sig till Blizzard UI
- Addon kan krascha på vissa clients/builds

**Fix:**
```lua
if f.EnableMouse then pcall(f.EnableMouse, f, unlocked) end
if f.SetMovable then pcall(f.SetMovable, f, unlocked) end
```

---

## 🟡 Varningar (Bör Fixas)

### 4. **Frame.Destroy() Anropas Utan Existenskontroll**

**Fil:** `SkyInfoTiles.lua` (rad 433)

```lua
function SkyInfoTiles.Rebuild()
  -- ...
  for i, f in ipairs(tilesFrames) do
    if f and f.Destroy then pcall(f.Destroy, f) end  -- ✅ Bra, men...
    if f and f.Hide and not InLockdown() then f:Hide() end  -- ❌ Hide inte protected
    tilesFrames[i] = nil
  end
```

**Problem:** `f:Hide()` kan misslyckas om framen är protected under combat.

**Fix:**
```lua
if f and f.Hide and not InLockdown() then
  pcall(f.Hide, f)
end
```

---

### 5. **teleportCache Kan Växa Obegränsat**

**Fil:** `KeystoneTile.lua` (rad 244-273, 523-524)

**Problem:**
```lua
f:RegisterEvent("SPELLS_CHANGED")
f:SetScript("OnEvent", function(self, event)
  if event == "SPELLS_CHANGED" then
    teleportCache = nil  -- ✅ Cachad rensas
  end
  -- ...
end)
```

**Men:**
- `SPELLS_CHANGED` triggas vid varje addon-load/talent-swap
- `BuildTeleportCache()` skannar **hela spellboken** varje gång
- Kan spamma vid många addons som laddar samtidigt

**Konsekvens:**
- Onödig CPU-användning vid addon-heavy environments
- Potentiell frame drop vid login

**Fix:** Throttle cache-rebuild med timer:
```lua
local cacheRebuildPending = false
local function ScheduleCacheRebuild()
  if cacheRebuildPending then return end
  cacheRebuildPending = true
  C_Timer.After(1, function()
    cacheRebuildPending = false
    teleportCache = nil
  end)
end

f:SetScript("OnEvent", function(self, event)
  if event == "SPELLS_CHANGED" then
    ScheduleCacheRebuild()
  end
  -- ...
end)
```

---

### 6. **Potentiell Taint från Settings API**

**Fil:** `Options.lua` (rad 308-313)

```lua
do
  local api = GetPanelAPI()
  if api == "settings" and _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
    settingsCategory = _G.Settings.RegisterCanvasLayoutCategory(panel, panel.name)  -- ❌
    _G.Settings.RegisterAddOnCategory(settingsCategory)  -- ❌
  elseif _G.InterfaceOptions_AddCategory then
    _G.InterfaceOptions_AddCategory(panel)  -- ❌
  end
end
```

**Problem:** Settings API kan tainta om den anropas vid fel tidpunkt.

**Fix:**
```lua
do
  local api = GetPanelAPI()
  if api == "settings" and _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
    local ok1, cat = pcall(_G.Settings.RegisterCanvasLayoutCategory, panel, panel.name)
    if ok1 and cat then
      settingsCategory = cat
      pcall(_G.Settings.RegisterAddOnCategory, settingsCategory)
    end
  elseif _G.InterfaceOptions_AddCategory then
    pcall(_G.InterfaceOptions_AddCategory, panel)
  end
end
```

---

## 🟢 Mindre Problem (Nice to Have)

### 7. **DungeonPortsTile: Redundant Event-Registrering**

**Fil:** `DungeonPortsTile.lua`

Registrerar många events som triggar samma update-funktion. Kan optimeras med throttling.

### 8. **Global Namespace Pollution**

**Fil:** `KeystoneTile.lua` (rad 477)

```lua
local btn = CreateFrame("Button", "SkyInfoTiles_KeystoneCast", f, "SecureActionButtonTemplate")
```

Skapar en globalt namngiven frame. Bättre: använd `nil` som namn och spara referensen lokalt (redan gjort, men namnet kan tas bort).

---

## 📋 Åtgärdsplan

### ✅ Prioritet 1: Memory Leaks (FIXAD 2026-03-05)
- [x] **CharStatsTile.lua:** Lägg till `UnregisterAllEvents()` i `Destroy()`
- [x] **Season3Tile.lua:** Lägg till `UnregisterAllEvents()` i `Destroy()`
- [x] **ClockTile.lua:** Lägg till OnUpdate cleanup i `Destroy()`

### ✅ Prioritet 2: Crash Prevention (FIXAD 2026-03-05)
- [x] **ClockTile.lua:** Lägg till C_Timer existence check + OnUpdate fallback
- [x] **SkyInfoTiles.lua:** Wrap `SetMovable`/`EnableMouse`/`RegisterForDrag` i pcall
- [x] **Options.lua:** Wrap Settings API-anrop i pcall

### ✅ Prioritet 3: Performance (FIXAD 2026-03-05)
- [x] **KeystoneTile.lua:** Throttle `SPELLS_CHANGED` cache rebuild (1 sec delay)
- [x] **DungeonPortsTile.lua:** Throttle update calls (max 10/sec for spammy events)
- [x] **CrosshairTile.lua:** Lägg till script cleanup i Destroy()

### Prioritet 4: Polish (Frivilligt)
- [ ] Ta bort globalt frame-namn från KeystoneTile
- [ ] Lägg till debug-logging för taint-tracking

---

## Testplan

Efter fixes, testa:
1. **Memory leak test:**
   - `/skytiles profile new Test1`
   - `/skytiles profile set Test1`
   - `/skytiles profile set Default`
   - Repetera 10 gånger
   - Kör `/dump collectgarbage("count")` före/efter

2. **Combat lockdown:**
   - Aktivera tiles
   - Gå in i combat
   - Kör `/reload` under combat
   - Verifiera inga Lua errors

3. **Spec switch:**
   - Aktivera per-spec profiles
   - Byt spec 5 gånger snabbt
   - Verifiera inga errors, inga memory leaks

4. **Settings panel:**
   - Öppna options
   - Toggle alla checkboxes
   - Kör `/reload`
   - Verifiera settings sparades

---

## Sammanfattning

**Status:** Addonen fungerar, men har **memory leaks** och **crash-risker**.

**Rekommendation:** Fixa Prioritet 1 och 2 innan distribution. De flesta fixes är 1-3 rader kod.

**Estimerad tid:** 30-45 minuter för alla P1+P2 fixes.
