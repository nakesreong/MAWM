# MAWM (Most Accurate World Map) — Complete Developer & Architecture Guide (`v1.5.0`)

**Repository & Workspace:** `c:\Users\ev3n7\.gemini\antigravity\scratch\Games\MAWM`  
**Live WoW AddOn Target:** `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\MAWM`  
**GitHub Repository:** `https://github.com/Nyarlatocat/MAWM`  
**CurseForge Project ID:** `1764505` (`## X-Curse-Project-ID: 1764505` in `MAWM.toc`)  
**Related Skill:** `C:\Users\ev3n7\.gemini\config\skills\mawm_continent_restoration\SKILL.md`  

---

## 1. Architectural Overview

`MAWM` overhauls the top-level **Azeroth World Map (`UiMapID = 947`)** without modifying or tainting any zoomed-in continent or zone map (`UiMapID ~= 947`). Instead of baking continents and text into static monolithic background tiles, `MAWM` uses a **100% modular, multi-layer runtime composition engine** mounted inside `WorldMapFrame.ScrollContainer.Child`:

### Layer Stack on `MAWM_CanvasOverlayFrame` (`Core.lua`)
1. **`BACKGROUND` (sublevel `1`) — `3x2` Power-of-Two Ocean Tile Grid (`3072x2048`, `3:2` aspect ratio):**
   - `Textures/blizz_0_0.tga` .. `blizz_1_2.tga` (`6 x 1024x1024` 24-bit RLE TGA tiles): Cool slate-aqua coastal water sea chart with subtle corner sea-monster engravings, compass rose, and rhumb lines.
   - `Textures/carto_0_0.tga` .. `carto_1_2.tga` (`6 x 1024x1024` 24-bit RLE TGA tiles): Warm antique cartographer's parchment ocean.
2. **`ARTWORK` (sublevel `2`) — 10 Modular 4K Continent Sprites (`1024x1024` 32-bit RGBA RLE TGA):**
   - `Textures/sp_<Continent>.tga` (for `blizz` style) and `Textures/sp_carto_<Continent>.tga` (for `carto` style).
   - Positioned and scaled dynamically at runtime from `MAWM.LAYOUTS[layoutKey].continents[contKey].box`.
3. **`ARTWORK` (sublevel `4`, `BlendMode = "ADD"`) — Screen-Normalized Soft Inner Coastline Hover Glow:**
   - `Textures/hl_<Continent>.tga` (`1024x1024` 32-bit RGBA RLE TGA).
   - Shares the exact `[x1, y1, x2, y2]` bounding box of its parent `sp_<Continent>.tga` sprite (`1:1` pixel lock).
   - Strictly **inner** glow (`alpha = 0` outside the continent's land mask) so hover highlights never spill over the dark ink coastline into the ocean.
4. **`OVERLAY` (sublevel `4–6`) — Dynamic Quadratic Bézier Ship & Zeppelin Transit Routes:**
   - Rendered dynamically in `f:UpdateTransitRoutes()` using pooled rotated `WHITE8X8` dash pairs (`bg` dark outline + `fg` faction color) and `45°` rotated diamond harbor nodes.
   - Automatically recalculates curve endpoints whenever the user switches layouts (`mawm`, `hybrid`, `blizz`) or drags continent scale sliders.
5. **`ARTWORK` (sublevel `6`) — Toggleable Lore & Fleet Route Overlay:**
   - `Textures/lore_overlay.tga` (`2048x1024` 32-bit RGBA RLE TGA) + interactive `#1–#8` geodesy pins (`MAWM.LORE_BADGES` in `Data.lua`).
6. **`OVERLAY` (sublevel `7`) — 12-Cell Localized Typography Atlas (`1024x1024` 32-bit RGBA RLE TGA):**
   - `Textures/labels_<lang>.tga` for all 11 official WoW locales (`en`, `ru`, `de`, `fr`, `es`, `it`, `pt`, `ko`, `zhcn`, `zhtw`).
   - Each `1024x1024` atlas contains a `2 columns x 6 rows` grid (`12` cells of `512x168 px` each: 10 continents + 2 oceans).

---

## 2. Dynamic Continent Scaling & Coastline-Relative Label Math (`Data.lua`)

### 2.1 Scale Multipliers (`MAWM.CONTINENT_SCALES`)
All 10 continents are scaled at runtime via explicit multipliers relative to their base `1.0x` normalized dimensions (`MAWM.CONTINENT_GEOMETRY` on the `3072x2048` canvas):

| Continent Key | `uiMapID` | Base `(w, h)` on `3072x2048` | Default Multiplier | Notes |
| :--- | :---: | :---: | :---: | :--- |
| `Kalimdor` | `12` | `(0.2610, 0.5670)` | `1.30x` | Western supercontinent |
| `EasternKingdoms` | `13` | `(0.2460, 0.5580)` | `1.20x` | Eastern supercontinent |
| `Northrend` | `113` | `(0.2050, 0.2140)` | `1.40x` | Northern polar continent |
| `Pandaria` | `424` | `(0.1780, 0.1780)` | `1.50x` | Southern continent |
| `DragonIsles` | `1978` | `(0.1500, 0.2050)` | `1.40x` | Southern Hemisphere (SE in `mawm`) |
| `BrokenIsles` | `619` | `(0.1300, 0.1780)` | `1.50x` | Off Azshara coast (NW in `mawm`/`hybrid`) |
| `Zandalar` | `875` | `(0.1160, 0.1440)` | `1.50x` | South America position (SW in `mawm`/`hybrid`) |
| `KulTiras` | `876` | `(0.1090, 0.1370)` | `1.55x` | Central sea east of Maelstrom |
| `KhazAlgar` | `2274` | `(0.0750, 0.0960)` | `1.60x` | Surface Isle of Dorn only |
| `Maelstrom` | `948` | `(0.1230, 0.1640)` | `1.50x` | Whirlpool + Lost Isles + Kezan |

User customizations from the Control Center sliders (`0.60x – 2.40x`) are stored in `MAWM_DB.scales[contKey]`. Calling `MAWM:RebuildLayoutBoxes()` recomputes `MAWM.LAYOUTS.mawm`, `MAWM.LAYOUTS.hybrid`, and `MAWM.LAYOUTS.blizz` in-place.

### 2.2 Coastline-Relative Label Positioning (`MAWM:ComputeContinentBoxAndLabel`)
Each continent in `MAWM.CONTINENT_GEOMETRY` defines its coastline mask bounds `mask = { u_min, v_min, u_max, v_max }` inside the `1024x1024` sprite and a `labelRule`:
- `anchor = "top"` (e.g. `Pandaria`, `KulTiras`, `BrokenIsles`, `DragonIsles`, `Zandalar`, `KhazAlgar`): places the curved title at a fixed screen-space gap `gap` above the top coastline edge `y1 + v_min * h`.
- `anchor = "bottom"` (e.g. `Northrend`, `Maelstrom`): places the curved title at a fixed screen-space gap `gap` below the bottom coastline edge `y1 + v_max * h`.
  - **Important Maelstrom Note:** In `sp_Maelstrom.tga`, the orange whirlpool eye is at `u = 0.5528` (shifted right of `0.500` because Kezan and the Lost Isles sit in the lower-left quadrant). Therefore `Maelstrom` uses `dx = +0.048` so `THE MAELSTROM / ВОДОВОРОТ` centers at `x = 0.5023` directly beneath the vortex eye.
- `anchor = "inside"` (`Kalimdor`, `EasternKingdoms`): places the label at normalized coordinates `(rx, ry)` inside the supercontinent landmass.

---

## 3. Layout-Adaptive Ship & Zeppelin Transit Routes (`Data.lua` & `Core.lua`)

### 3.1 Continent-Relative Harbor Anchors (`MAWM.PORTS`)
Every harbor or zeppelin tower is defined in `MAWM.PORTS` using normalized `(u, v)` coordinates (`0..1`) **relative to its parent continent's sprite box**:
```lua
nx = box[1] + port.u * (box[3] - box[1])
ny = box[2] + port.v * (box[4] - box[2])
```
All `(u, v)` coordinates were verified against the alpha channel of `Textures/sp_<Continent>.tga` so every harbor diamond sits directly on the visible coastline:
- **`EasternKingdoms`:** `StormwindHarbor (0.415, 0.655)`, `MenethilHarbor (0.485, 0.485)`, `TirisfalGlades (0.455, 0.255)`, `GromgolBaseCamp (0.419, 0.799)`, `BootyBay (0.419, 0.854)`
- **`Kalimdor`:** `OrgrimmarDocks (0.588, 0.455)`, `EchoIslesDocks (0.584, 0.556)`, `RatchetHarbor (0.559, 0.548)`
- **`Northrend`:** `BoreanWarsong (0.197, 0.650)`, `HowlingValgarde (0.838, 0.779)`
- **`KulTiras`:** `BoralusHarbor (0.635, 0.440)`
- **`Zandalar`:** `DazaralorPort (0.480, 0.722)`
- **`DragonIsles`:** `WakingShoresDock (0.371, 0.299)`

### 3.2 Adding New Routes
To add a new ship, zeppelin, or portal route, simply append an entry to `MAWM.TRANSIT_ROUTES` in `Data.lua`:
```lua
{
    id       = "unique_route_id",
    faction  = "ALLIANCE", -- "ALLIANCE" (Blue), "HORDE" (Red), or "NEUTRAL" (Black)
    kind     = "SHIP",     -- "SHIP" or "ZEPPELIN"
    from     = "PortKeyA",
    to       = "PortKeyB",
    curve    = 0.16,       -- Signed perpendicular curvature offset (-0.30 .. +0.30)
    titleEN  = "Route Title (EN)",
    titleRU  = "Название маршрута (RU)",
    vesselEN = "Alliance Ship (Two-Way)",
    vesselRU = "Корабль Альянса (туда и обратно)",
    boardEN  = "Where to board in Point A",
    boardRU  = "Где сесть в Точке А",
    arriveEN = "Where it arrives in Point B",
    arriveRU = "Куда прибывает в Точке Б",
}
```
The UI list in Tab 3 (`3. Ships & Zeppelins`), the quadratic Bézier dash renderer, and the hover hit-tester in `Core.lua` automatically pick up all entries in `MAWM.TRANSIT_ROUTES`.

---

## 4. Control Center UI, Minimap Button & Blizzard Settings (`Core.lua`)

- **Why everything is in `Core.lua`:** WoW's client caches the `.toc` file list at process startup (`Wow.exe`). Keeping the Control Center (`MAWMControlCenter`), Minimap Button (`MAWMMinimapButton`), and Blizzard Settings registration (`MAWMBlizzardSettingsPanel`) directly inside `Core.lua` guarantees that `/reload` always loads UI changes immediately during live development.
- **Entry Points:**
  1. **Minimap Button (`MAWMMinimapButton`):** Structured identically to `SpArcMinimapButton` (`frameDecor` child frame for background/border, only `btn.icon` as direct `ARTWORK` region) so `ElvUI_WindTools` MinimapButtons skins it cleanly without stretching solid backdrops.
  2. **World Map Top-Right Buttons (`MAWM_WorldMapToggleButton` + `MAWM_WorldMapGearButton`):** Anchored to `WorldMapFrame.ScrollContainer` (`TOPRIGHT`).
  3. **Game Menu (`ESC -> Options -> AddOns -> MAWM`):** Registered via `Settings.RegisterCanvasLayoutCategory`.
  4. **Slash Commands:** `/mawm` and `/meow` (opens `MAWMControlCenter`; also supports `/mawm layout`, `/mawm style`, `/mawm routes`, `/mawm scale`).

---

## 5. Asset Generation & Restoration Pipelines

All texture generation scripts and the 4K continent restoration pipeline are documented in detail in:
- **Skill:** `C:\Users\ev3n7\.gemini\config\skills\mawm_continent_restoration\SKILL.md`
- **Pins & Remaster Roadmap:** `c:\Users\ev3n7\.gemini\antigravity\scratch\Games\MAWM\ROADMAP_PINS_AND_4K_REMASTER.md`

### Quick Summary of Texture Specifications in `Textures/`
- All `.tga` files use **Truevision RLE compression** (`save_tga_rle` in Python) so the entire addon package stays compact (`~36 MB` zipped).
- `sp_<Continent>.tga` & `sp_carto_<Continent>.tga`: `1024x1024` 32-bit BGRA RLE TGA, premultiplied/clean dark-ink shoreline alpha mask (no outer parchment ring).
- `hl_<Continent>.tga`: `1024x1024` 32-bit BGRA RLE TGA, screen-normalized **inner** coastline glow (`14 px` screen-equivalent inward distance transform feathering, `alpha = 0` outside landmass).
- `labels_<lang>.tga`: `1024x1024` 32-bit BGRA RLE TGA (`2x6` grid of `512x168` cells), rendered at `2x` supersampling (`2048x2048 -> 1024x1024` Lanczos) with arched coastline baselines for island/polar continents.

---

## 6. Release & CurseForge Deployment Workflow

Per the `wow_addon_release_protocol` skill (`C:\Users\ev3n7\.gemini\config\skills\wow_addon_release_protocol\SKILL.md`):
1. **Develop & Test on a Feature Branch (`dev-vX.Y.Z`):**
   - Copy modified files to `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\MAWM\` and test via `/reload` in WoW.
   - Never push untested changes to `main` or create a release git tag before in-game verification.
2. **Release to GitHub & CurseForge (`main` + tag `vX.Y.Z`):**
   - Bump version in `MAWM.toc`, `Data.lua`, and `CHANGELOG.md`.
   - Merge into `main`, create annotated/lightweight tag `vX.Y.Z`, and push both `main` and `vX.Y.Z` to `origin`.
   - GitHub Actions (`.github/workflows/release.yml` using `BigWigsMods/packager@v2` and repository secret `CF_API_KEY`) automatically packages `MAWM` according to `.pkgmeta` and publishes the release to CurseForge (`Project ID: 1764505`) and GitHub Releases.

---

## 7. Next Priorities / Open Roadmap for the Next Session

1. **Dynamic Pin & Addon Marker Coordinate Remapping on `UiMapID = 947`:**
   - Currently, `SetStockHighlightSuppressed(true)` hides third-party pins on `947` while `MAWM` is active so stock pins don't float in the ocean.
   - Next goal: Hook `WorldMapFrame:EnumerateAllPins()` / DataProviders on `947`, map each pin's stock `(x, y)` from its source continent's stock Blizzard bounding box (`MAWM.LAYOUTS.blizz.continents[k].box`) into the active layout's bounding box (`MAWM.LAYOUTS[active].continents[k].box`), and reposition pins dynamically on top of `MAWM_CanvasOverlayFrame`!
2. **Expanded Transit Network:**
   - Add optional Darkmoon Faire portal/ship markers, Dalaran/Shattrath portal hubs, or subterranean Khaz Algar / Zaralek Cavern entry indicators.
