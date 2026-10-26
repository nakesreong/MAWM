# MAWM — Most Accurate World Map

**MAWM (Most Accurate World Map)** overhauls the Azeroth World Map (`UiMapID = 947`) to fix 20 years of expansion continent cramming, inverted climate zones, broken Pre-Sundering borders, and impossible naval routes — while keeping **100% interactive click-to-zoom continent navigation**, **1:1 pixel-locked Blizzard golden coastline highlights**, and **automatic map typography for all 11 official World of Warcraft client locales**.

---

## Why Azeroth Needed a Cartographic Realignment

1. **True Planetary Ocean Margins (*The Veiled Sea & The Forbidding Sea*):**
   * Kalimdor and the Eastern Kingdoms are shifted inward from the frame edges so Azeroth reads as a true planetary projection with wide oceans rather than continents squeezed against a picture frame, with **The Maelstrom** centered at the exact `(50%, 50%)` equator.
2. **Broken Isles (`619`) Off the Coast of Azshara:**
   * **Azsuna's** Highborne ruins now connect directly to **Azshara**.
   * **Highmountain's** snowy peaks face **Borean Tundra** in Northrend.
   * **Suramar & the Broken Shore** face directly into **The Maelstrom**.
3. **Khaz Algar (`2274`) — Surface Isle of Dorn East of Northrend:**
   * On the surface world map, Khaz Algar is **only the Isle of Dorn** (since over 75% of Khaz Algar — *The Ringing Deeps, Hallowfall, Azj-Kahet* — is subterranean).
   * Placed east of **Northrend** along the **Ulduar / Storm Peaks** Titan forge belt.
4. **Kul Tiras (`876`) & Admiral Daelin Proudmoore's Fleet Route:**
   * Placed in the central sea east of the Maelstrom.
   * Restores **Admiral Daelin Proudmoore's Warcraft III: The Frozen Throne (*Founding of Durotar*) naval route**: sailing southwest from **Kul Tiras to Theramore and Durotar** through open southern waters without ever crossing the Maelstrom.
5. **Dragon Isles (`1978`) in the Southern Hemisphere (Southeast of the Eastern Kingdoms):**
   * Placed southeast of **Burning Steppes, Badlands, and Twilight Highlands**.
   * **Southern Hemisphere Climate Proof:** On Blizzard's stock map (where Dragon Isles is in the far north), its internal climate is completely upside-down. In the **Southern Hemisphere**, it finally makes 100% physical sense: the volcanic **Waking Shores** are in the **north** (closer to the Equator & **Blackrock Mountain**), while the snowy tundra of **The Azure Span** is in the **south** (closer to the South Pole), and **Amirdrassil** on the west coast aligns near **Duskwood's** Emerald Dream portal.
6. **Zandalar (`875`) as South America & Deep Southern Pandaria (`424`):**
   * **Zandalar** sits southwest of the Maelstrom as Azeroth's South American continent.
   * **Pandaria** sits deep in the southern ocean: its snowy **Kun-Lai Summit** is in the north, and the continent avoids freezing over at its southern polar latitude thanks to the Titan/Mogu geothermal and arcane heat source at its center — the **Vale of Eternal Blossoms** (waters of the Well of Eternity).

---

## Features

* **Automatic Multi-Language Map Typography (All 11 Official WoW Client Locales):**
  * Automatically detects your WoW client language (`GetLocale()`) and renders authentic engraved continent & sea labels in **English (`enUS`/`enGB`)**, **Russian (`ruRU`)**, **German (`deDE`)**, **French (`frFR`)**, **Spanish (`esES`/`esMX`)**, **Italian (`itIT`)**, **Portuguese (`ptBR`)**, **Korean (`koKR`)**, **Simplified Chinese (`zhCN`)**, and **Traditional Chinese (`zhTW`)**.
* **2 Bundled High-Res (`3072x2048`) Map Styles:**
  * **Official 4K Blizzard CASC Realigned (`blizz` — Default):** Exact continent stencils extracted from genuine Blizzard `UiMapArtID 970 / 1792` 4K tiles on a warm golden-amber cartographer's parchment ocean with engraved sea serpents, leviathan, kraken, and compass rose.
  * **Cartographer's Illustrated Parchment (`carto`):** Unified warm antique parchment map style.
* **1:1 Pixel-Locked Golden Coastline Highlights:**
  * Uses Blizzard's native `HighlightFileDataID` continent masks from `UiMapAssignment.db2` aligned with zero pixel drift to each continent's realigned coordinates on hover.
* **Toggleable Lore & Naval Fleet Route Overlay (`[Lore]`):**
  * Displays Admiral Daelin Proudmoore's fleet path, tectonic & climate vectors, and interactive `#1-#8` geodesy pins with full **English & Russian** tooltips.
* **One-Click Map Button & `/mawm` (`/meow`) Commands:**
  * **Left-Click:** Toggle Realigned vs. Stock Map
  * **Right-Click:** Switch Style (`4K Blizz` / `Parchment`)
  * **Alt-Click:** Switch Map Language (`Client Auto` / `EN` / `RU`, or `/mawm lang <code>`)
  * **Shift-Click / Middle-Click:** Toggle Lore & Naval Routes Overlay

---

## Roadmap & Known Limitations (`v1.3.1`)

* **World Map Pins & Addon Markers on Top-Level Azeroth (`UiMapID = 947`):**
  * Currently, stock game pins and third-party addon markers on the top-level **Azeroth World Map (`947`)** are hidden while `MAWM` is active so misplaced stock pins don't float in the ocean. **Dynamic coordinate remapping for addon pins & waypoints on `947` is in active development for a future update.**
  * *(Inside all zoomed-in **Continent** and **Zone** maps, all game pins, waypoints, and map addons work 100% normally.)*
