# 🐾 MAWM — Most Accurate World Map

**MAWM (Most Accurate World Map)** overhauls the Azeroth World Map (`UiMapID = 947`) to fix 20 years of expansion continent cramming, broken biome seams, and impossible naval routes — while keeping **100% interactive click-to-zoom continent navigation** and **Blizzard's native golden coastline highlights**!

---

## 🧭 Why Azeroth Needed a Cartographic Realignment

1. **True Planetary Ocean Margins (*The Veiled Sea & The Forbidding Sea*):** Kalimdor and the Eastern Kingdoms are shifted inward from the frame edges so Azeroth looks like a real planetary projection instead of continents squeezed against a box.
2. **Broken Isles (`619`) Off the Coast of Azshara:**
   * **Azsuna's** Highborne ruins now connect directly to **Azshara**.
   * **Highmountain's** snowy peaks face **Borean Tundra** in Northrend.
   * **Suramar & the Broken Shore** face directly into **The Maelstrom**.
3. **Khaz Algar (`2274`) — Tiny Surface Isle of Dorn East of Northrend:**
   * On the surface world map, Khaz Algar is **only the Isle of Dorn** (~Teldrassil / Azuremyst scale), because over 75% of Khaz Algar (*The Ringing Deeps, Hallowfall, Azj-Kahet*) is subterranean!
   * Placed east of **Northrend** along the **Ulduar / Storm Peaks** Titan forge belt.
4. **Kul Tiras (`876`) & Admiral Daelin Proudmoore's Fleet Route:**
   * Placed in the central sea east of the Maelstrom.
   * Restores **Admiral Daelin Proudmoore's Warcraft III: The Frozen Throne (*Founding of Durotar*) naval route**: sailing southwest from **Kul Tiras to Theramore and Durotar** through open southern waters without ever crossing the Maelstrom!
5. **Dragon Isles (`1978`) Southeast of the Eastern Kingdoms:**
   * Moved southeast of **Burning Steppes, Badlands, and Twilight Highlands**, connecting Neltharion's volcanic **Obsidian Citadel** to **Blackrock Mountain**.
6. **Zandalar (`875`) & Deep Southern Pandaria (`424`):**
   * **Zandalar** anchors the tropical equator south of the Maelstrom, while **Pandaria** sits deep in the southern ocean.

---

## ✨ Features

* **2 Bundled High-Res (`3072×2048`) Map Styles:**
  * **Official 4K Blizzard CASC Realigned (Default):** Built directly from genuine Blizzard `UiMapArtID 970 / 1792` 4K tiles.
  * **Cartographer's Illustrated Parchment:** Custom hand-painted antique parchment map.
* **Native Golden Coastline Highlights:** Uses Blizzard's built-in `HighlightFileDataID` textures aligned to each continent's new coordinates on hover.
* **Toggleable Lore & Naval Fleet Route Overlay (`[Lore]`):** Displays Daelin Proudmoore's fleet path, tectonic connectors, and interactive `#1–#8` geodesy pins with full **English & Russian** tooltips.
* **One-Click Map Button & `/mawm` (`/meow`) Commands:**
  * **Left-Click:** Toggle Realigned vs. Stock Map
  * **Right-Click:** Switch Style (`4K Blizz` / `Parchment`)
  * **Shift-Click / Middle-Click:** Toggle Lore & Naval Routes Overlay
