# MAWM — Most Accurate World Map

**MAWM (Most Accurate World Map)** overhauls the Azeroth World Map (`UiMapID = 947`) to fix 20 years of expansion continent cramming, inverted climate zones, broken Pre-Sundering borders, and impossible naval routes — while keeping **100% interactive click-to-zoom continent navigation**, **soft inner golden coastline highlights**, **layout-adaptive Ship & Zeppelin transit routes**, **live continent scale sliders**, and **automatic map typography for all 11 official World of Warcraft client locales**.

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

## Features (`v1.5.0`)

* **3 Selectable Geodesy Layout Modes (`MAWM` / `Hybrid` / `Blizzard`):**
  * **1. MAWM Full Geodesy (Default):** All 10 continents placed according to lore geodesy, climate zones, and Pre-Sundering borders.
  * **2. Hybrid Mode:** *Broken Isles* and *Zandalar* shifted to their lore positions, while *Khaz Algar* and *Dragon Isles* remain at Blizzard's stock spots.
  * **3. Blizzard Positions + Restored 4K Proportions:** All 10 continents at Blizzard's familiar positions, rendered with MAWM's hand-restored 4K sprites and proportional scaling.
* **Modular Control Center UI & Live Continent Scale Sliders (`/mawm`):**
  * Accessible via the **Minimap Button (`MAWM`)**, the **`[Settings]` button** in the top-right corner of the World Map, **`ESC -> Options -> AddOns -> MAWM`**, or **`/mawm`** (`/meow`).
  * Includes **10 live continent scale sliders (`0.60x – 2.40x`)** allowing you to customize the size of every continent and island kingdom in real time.
* **Layout-Adaptive Ship & Zeppelin Transit Routes (`Ships & Zeppelins`):**
  * Optional dashed maritime and zeppelin routes (**Blue** for Alliance, **Red** for Horde, **Black** for Neutral) that automatically adapt to your active layout mode and continent scales.
  * Hover over any dashed route or harbor diamond to view a detailed tooltip showing the **vessel type**, **where to board (Point A)**, and **where it arrives (Point B)**.
* **Automatic Multi-Language Map Typography (All 11 Official WoW Client Locales):**
  * Automatically detects your WoW client language (`GetLocale()`) and renders coastline-curved continent and sea labels in **English (`enUS`/`enGB`)**, **Russian (`ruRU`)**, **German (`deDE`)**, **French (`frFR`)**, **Spanish (`esES`/`esMX`)**, **Italian (`itIT`)**, **Portuguese (`ptBR`)**, **Korean (`koKR`)**, **Simplified Chinese (`zhCN`)**, and **Traditional Chinese (`zhTW`)**.
* **2 Bundled High-Res (`3072x2048`) Map Styles:**
  * **4K Coastal Sea Chart (`blizz` — Default):** Hand-restored 4K continent sprites on a slate-aqua coastal parchment ocean with corner engravings and compass rose.
  * **Cartographer's Illustrated Parchment (`carto`):** Unified warm antique parchment map style.
* **Screen-Normalized Soft Inner Coastline Glow:**
  * Illuminates each continent's interior shoreline on hover without spilling outside the dark ink coast.

---

## Roadmap & Known Limitations (`v1.5.0`)

* **World Map Pins & Addon Markers on Top-Level Azeroth (`UiMapID = 947`):**
  * Currently, stock game pins and third-party addon markers on the top-level **Azeroth World Map (`947`)** are hidden while `MAWM` is active so misplaced stock pins don't float in the ocean. **Dynamic coordinate remapping for addon pins & waypoints on `947` is in active development for a future update.**
  * *(Inside all zoomed-in **Continent** and **Zone** maps, all game pins, waypoints, and map addons work 100% normally.)*
