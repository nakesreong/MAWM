# Changelog — MAWM (Most Accurate World Map)

## [1.0.0] - 2026-10-24
### Added
- **Initial Release (`v1.0.0`)** for World of Warcraft (`12.0.1` / `11.x`).
- **Two Selectable High-Resolution (`3072×2048`) Map Styles:**
  - **Official 4K Blizzard CASC Realigned (`blizz`):** Built from genuine Blizzard `UiMapArtID = 970 / 1792` 4K CASC map tiles with seamless ocean synthesis and authentic metallic corners.
  - **Cartographer's Illustrated Parchment (`carto`):** Custom hand-painted antique parchment world map.
- **Realigned Continent Geography & Interactive Navigation (`UiMapID = 947`):**
  - Wide Pacific-scale ocean margins (*The Veiled Sea* & *The Forbidding Sea*).
  - **Broken Isles (`619`)** aligned off the coast of Azshara and SW of Northrend.
  - **Khaz Algar (`2274`)** scaled accurately as the tiny surface **Isle of Dorn** (~Teldrassil scale) east of Northrend near Ulduar.
  - **Kul Tiras (`876`)** placed east of the Maelstrom in the central sea.
  - **Dragon Isles (`1978`)** placed southeast of the Eastern Kingdoms off Blackrock / Burning Steppes.
  - **Zandalar (`875`)** & **Pandaria (`424`)** aligned along the southern hemisphere axis.
- **Native Blizzard Golden Coastline Highlights:** Displays each continent's built-in `HighlightFileDataID` glow at its new realigned coordinates on mouse hover while suppressing the misplaced default highlight pin.
- **Interactive Lore & Naval Fleet Route Overlay (`[Lore]` mode):** Toggleable overlay featuring **Admiral Daelin Proudmoore's WC3 Fleet Route** (`Kul Tiras -> Theramore / Durotar`), tectonic biome connectors, and interactive tooltips in **English** and **Russian (`ruRU`)**.
- **World Map Header Button & `/mawm` (`/meow`) Slash Commands.**
