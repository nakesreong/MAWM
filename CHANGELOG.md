# Changelog — MAWM (Most Accurate World Map)

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
