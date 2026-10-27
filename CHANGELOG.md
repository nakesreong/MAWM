# Changelog — MAWM (Most Accurate World Map)

## [1.5.0] - 2026-10-27
### Added
- **MAWM Control Center Settings Window (`/mawm`, Minimap Button, World Map `[Settings]` Button, and `ESC -> Options -> AddOns -> MAWM`):**
  - Modular dark ElvUI/SpArc-style Control Center with 3 dedicated tabs:
    1. **Map & Layout:** Master toggles, 3 geodesy layout selectors (*MAWM Full Geodesy*, *Hybrid*, *Blizzard Positions*), 2 ocean backdrop themes (*4K Coastal Sea Chart*, *Cartographer's Parchment*), and 1-click language switcher across all 11 official WoW locales.
    2. **Continent Scales:** 10 live scale multiplier sliders (`0.60x – 2.40x`) for every continent and island kingdom with real-time map preview and one-click reset.
    3. **Ships & Zeppelins:** Toggleable intercontinental transit routes with faction filters (*Alliance Blue*, *Horde Red*, *Neutral Black*) and line opacity control.
- **Layout-Adaptive Intercontinental Ship & Zeppelin Transit Routes (`MAWM.TRANSIT_ROUTES`):**
  - Renders curved dashed maritime and zeppelin routes with diamond harbor nodes across the Azeroth World Map (`UiMapID = 947`).
  - Harbor anchors (`MAWM.PORTS`) are bound to each continent's normalized coastline coordinates, so all routes automatically recalculate when switching between *MAWM*, *Hybrid*, and *Blizzard* layouts or resizing continents.
  - Hovering any route or harbor node highlights the path and displays a bilingual (*EN/RU*) tooltip with vessel type, faction, **where to board (Point A)**, and **destination (Point B)**.

### Fixed
- **Centered Maelstrom Typography (All 11 Locales):** Adjusted the horizontal label offset (`dx = +0.048` relative to the asymmetrical *Maelstrom + Kezan + Lost Isles* sprite bounds) so *THE MAELSTROM / ВОДОВОРОТ* sits dead-center beneath the whirlpool eye (`x = 0.5023`).
- **Coastline-Relative Dynamic Label Scaling:** Refactored continent bounding-box and label placement (`MAWM:ComputeContinentBoxAndLabel`) so continent titles automatically track coastline edges when scaling continents up or down.

## [1.4.0] - 2026-10-26
### Added
- **3 Selectable Geodesy Layout Modes (`Right-Click` / `Ctrl-Click` or `/mawm layout`):**
  1. **`MAWM` (Full Geodesy):** *Broken Isles* NE of *Kalimdor*, *Zandalar* SW (*"South America"*), *Khaz Algar (Isle of Dorn)* North/NE, and *Dragon Isles* SE (*Southern Hemisphere*).
  2. **`Hybrid`:** *Broken Isles* NE of *Kalimdor* & *Zandalar* SW (*"South America"*), while *Khaz Algar* (SW) & *Dragon Isles* (NE) stay at Blizzard's stock positions.
  3. **`Blizzard` (Stock Positions + Enhanced Proportions):** All 10 continents at Blizzard's familiar positions, scaled to true gameplay-enhanced proportions.
- **4K Hand-Restored Modular Continent Sprites (All 10 Continents):**
  - Restored all 10 continents (*Kalimdor*, *Eastern Kingdoms*, *Northrend*, *Pandaria*, *Dragon Isles*, *Broken Isles*, *Kul Tiras*, *Zandalar*, *Khaz Algar / Isle of Dorn*, and a volumetric 3D *Maelstrom* vortex with *Kezan* & *The Lost Isles*) with crisp hand-drawn relief, glaciers, forests, and zero baked-in icons or text.
- **Gameplay-Enhanced Continent Proportions (`1.2x–1.6x`) & Coastal-Water Ocean Parchment:**
  - Enlarged continents so fine 4K geographic details on *Northrend*, *Pandaria*, and island kingdoms are clearly visible while maintaining true supercontinent hierarchy (*Kalimdor* & *Eastern Kingdoms*).
  - Restyled the ocean background using the cool slate-aqua coastal water tones of the continents so coastlines, bays, and *Vashj'ir* blend seamlessly into the sea chart, with compact corner engravings and layout-aware navigation rhumb lines.
- **Screen-Normalized Soft Feathered INNER Hover Glow (`hl_<Continent>.tga`):**
  - Replaced outer coastline outlines with a soft, screen-normalized inward-feathered golden glow that illuminates every continent and island uniformly without spilling outside the dark ink coastline.
- **Enlarged Coastline-Curved Typography (All 11 Official WoW Locales):**
  - Enlarged all localized map labels and curved island/polar continent titles along their coastlines (*Pandaria* arched above northern *Pandaria*, *Northrend* curved beneath *Dragonblight*'s bay, *Kul Tiras*, *Broken Isles*, *Dragon Isles*, *Zandalar*, *Khaz Algar*, and *The Maelstrom* curved cleanly along their shores so zero continent detail is covered).

## [1.3.1] - 2026-10-25
### Added
- **Full 11-Locale Client Auto-Detection (`GetLocale()`):** Added engraved map label overlays for all official World of Warcraft locales: **English (`enUS`/`enGB`)**, **Russian (`ruRU`)**, **German (`deDE`)**, **French (`frFR`)**, **Spanish (`esES`/`esMX`)**, **Italian (`itIT`)**, **Portuguese (`ptBR`)**, **Korean (`koKR`)**, **Simplified Chinese (`zhCN`)**, and **Traditional Chinese (`zhTW`)**.
- **Warm Golden-Amber Warcraft Parchment Grading:** Matched the ocean parchment color temperature to Blizzard's zoomed-in continent maps while preserving crisp vector-sharp sea monsters, compass rose, and rhumb lines with zero compression artifacts.
- **Southern Hemisphere Climate Proof (`#6 Dragon Isles` & `#8 Pandaria`):** Updated interactive lore pins with the southern hemisphere climate gradient.

### Fixed
- **1:1 Pixel-Locked DB2 Highlights:** Extracted exact continent stencils and `HighlightFileDataID` masks using native `UiMapAssignment.db2` coordinates.
- **Clean Top-Level Canvas (`UiMapID = 947`):** Suppressed misplaced stock pins and the floating Khaz Algar cloud overlay while `MAWM` is active on `947`.
