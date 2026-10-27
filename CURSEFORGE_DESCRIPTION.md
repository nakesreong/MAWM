# MAWM — Most Accurate World Map

**MAWM (Most Accurate World Map)** overhauls the Azeroth World Map (`UiMapID = 947`) to fix 20 years of expansion continent cramming, distorted island scales, inverted climate zones, broken Pre-Sundering borders, and impossible naval routes — while keeping **100% interactive click-to-zoom continent navigation**, **3 selectable geodesy layout modes (`MAWM`, `Hybrid`, `Blizzard`)**, **soft feathered inner coastline hover highlights**, and **automatic curved coastline typography for all 11 official World of Warcraft client locales**.

---

## What's New in v1.4.0

* **4K Hand-Restored Continents & Gameplay-Enhanced Proportions:**
  * All 10 continents (`Kalimdor`, `Eastern Kingdoms`, `Northrend`, `Pandaria`, `Dragon Isles`, `Broken Isles`, `Kul Tiras`, `Zandalar`, `Khaz Algar / Isle of Dorn`, and `The Maelstrom + Kezan + Lost Isles`) have been individually restored in 4K from clean map art — removing baked-in zone names, city icons, and dark coastal double-borders — and scaled up **1.2x to 1.6x** for effortless clickability while preserving true supercontinent hierarchy (`Kalimdor` largest at `1.3x`, `Eastern Kingdoms` slightly more compact at `1.2x`, `Northrend` & `Pandaria` at `1.45x-1.5x`, and island kingdoms/archipelagos at `1.5x-1.6x`).
* **3 Selectable Geodesy Layout Modes (`Right-Click` or `/mawm layout`):**
  * **1. `MAWM` (Full Geodesy — Default):** *Broken Isles* NE of Kalimdor, *Zandalar* SW ("South America" of Azeroth), *Khaz Algar (Isle of Dorn)* in the northern Titan belt, and *Dragon Isles* in the Southern Hemisphere SE of the Eastern Kingdoms.
  * **2. `Hybrid`:** *Broken Isles* and *Zandalar* at their lore-corrected positions, while *Khaz Algar* (SW) and *Dragon Isles* (NE) remain at Blizzard's stock positions.
  * **3. `Blizzard`:** All 10 continents placed at Blizzard's stock positions, rendered with our 4K restored continent sprites and true supercontinent-to-island scale hierarchy.
* **Screen-Normalized Soft Feathered Inner Hover Glow:**
  * Hovering any continent illuminates its interior with a warm sunlit golden glow that feathers smoothly inward from the coastline — replacing thick external outlines and matching softness across both massive supercontinents and smaller archipelagos.
* **Coastal-Water Ocean Background & Enlarged Curved Coastline Labels:**
  * New sea-chart ocean backdrop color-matched to the coastal waters of the continents so shallow shelves blend naturally into the sea, with compact corner sea-monster engravings and radial navigation rhumb lines centered on the Maelstrom.
  * Enlarged, high-contrast localized typography in all 11 official WoW locales: `Kalimdor` and `Eastern Kingdoms` sit across their landmasses, while all other continents and islands feature arched labels curving cleanly along their adjacent coastlines so no terrain detail is covered.

---

## Why Azeroth Needed a Cartographic Realignment

1. **True Planetary Ocean Margins (*The Veiled Sea & The Forbidding Sea*) & Continent Hierarchy:**
   * Kalimdor and the Eastern Kingdoms are shifted inward from the frame edges so Azeroth reads as a true planetary projection with wide oceans rather than continents squeezed against a picture frame, while restoring the true size difference between primary supercontinents and island archipelagos.
2. **Broken Isles (`619`) Under Western Northrend & Off the Coast of Azshara:**
   * **Azsuna's** Highborne ruins now connect directly across the bay to **Azshara**.
   * **Highmountain's** snowy peaks sit directly south of **Borean Tundra** in Northrend.
   * **Suramar & the Broken Shore** face directly into **The Maelstrom**.
3. **Khaz Algar (`2274`) — Surface Isle of Dorn (~Teldrassil Scale):**
   * On the surface world map, Khaz Algar is **only the Isle of Dorn** (since over 75% of Khaz Algar — *The Ringing Deeps, Hallowfall, Azj-Kahet* — is a vertical subterranean network).
   * Scaled to authentic island proportions and placed along the northern Titan forge belt in `MAWM` layout (or SW in `Hybrid` / `Blizzard` layouts).
4. **Kul Tiras (`876`) & Admiral Daelin Proudmoore's Fleet Route:**
   * Placed in the central sea east of the Maelstrom across from Gilneas.
   * Restores **Admiral Daelin Proudmoore's Warcraft III: The Frozen Throne (*Founding of Durotar*) naval route**: sailing southwest from **Kul Tiras to Theramore and Durotar** through open southern waters without ever crossing the Maelstrom.
5. **Dragon Isles (`1978`) in the Southern Hemisphere (Southeast of the Eastern Kingdoms):**
   * Placed southeast of **Burning Steppes, Badlands, and Twilight Highlands** in `MAWM` layout (or NE in `Hybrid` / `Blizzard` layouts).
   * **Southern Hemisphere Climate Proof:** On Blizzard's stock map (where Dragon Isles is in the far north), its internal climate is completely upside-down. In the **Southern Hemisphere**, it makes 100% physical sense: the volcanic **Waking Shores** are in the **north** (closer to the Equator & **Blackrock Mountain**), while the snowy tundra of **The Azure Span** is in the **south** (facing the Southern Pole), and **Amirdrassil** on the west coast aligns near **Duskwood's** Emerald Dream portal.
6. **Zandalar (`875`) as South America & Deep Southern Pandaria (`424`):**
   * **Zandalar** sits southeast of Southern Kalimdor (*Tanaris / Un'Goro*) as Azeroth's South American continent, forming a tropical Goblin Caribbean basin around **Kezan** and the **Lost Isles**.
   * **Pandaria** sits deep in the southern ocean: its snowy **Kun-Lai Summit** is in the north, and the continent avoids freezing over at its southern latitude thanks to the Titan/Mogu geothermal and arcane heat source at its center — the **Vale of Eternal Blossoms** (waters of the Well of Eternity).

---

## Features

* **3 Selectable Geodesy Layout Modes (`mawm`, `hybrid`, `blizz`):**
  * Switch layouts on the fly with **Right-Click / Ctrl-Click** on the map header button or `/mawm layout [mawm|hybrid|blizz]`.
* **Automatic Multi-Language Curved Map Typography (All 11 Official WoW Client Locales):**
  * Automatically detects your WoW client language (`GetLocale()`) and renders enlarged, curved coastline-hugging continent and sea labels in **English (`enUS`/`enGB`)**, **Russian (`ruRU`)**, **German (`deDE`)**, **French (`frFR`)**, **Spanish (`esES`/`esMX`)**, **Italian (`itIT`)**, **Portuguese (`ptBR`)**, **Korean (`koKR`)**, **Simplified Chinese (`zhCN`)**, and **Traditional Chinese (`zhTW`)**.
* **2 Bundled High-Res (`3072x2048`) Map Styles:**
  * **Official 4K Blizzard CASC Realigned (`blizz` — Default):** 4K restored continent sprites on a coastal-water sea chart with compact corner sea monsters and radial Maelstrom navigation rhumb lines.
  * **Cartographer's Illustrated Parchment (`carto`):** Warm antique parchment ocean tone (`/mawm style`).
* **Screen-Normalized Soft Feathered Inner Coastline Highlights:**
  * Smooth golden inner glow (`BlendMode = "ADD"`) aligned 1:1 to every continent and island across all 3 layout modes on mouse hover.
* **Toggleable Lore & Naval Fleet Route Overlay (`[L]`):**
  * Displays Admiral Daelin Proudmoore's fleet path, tectonic & climate vectors, and interactive `#1-#8` geodesy pins with full **English & Russian** tooltips in `MAWM` layout mode.
* **One-Click Map Button & `/mawm` (`/meow`) Commands:**
  * **Left-Click:** Toggle Realigned vs. Stock Map (or jump directly to Azeroth from any zone map)
  * **Right-Click / Ctrl-Click:** Cycle Geodesy Layout (`MAWM` -> `Hybrid` -> `Blizzard`)
  * **Alt-Click:** Toggle Map Language (`Client Auto` / `EN` / `RU`, or `/mawm lang <code>`)
  * **Shift-Click / Middle-Click:** Toggle Lore & Naval Routes Overlay
  * **`/mawm style`:** Switch between `4K Blizz` and `Cartographer's Parchment`

---

## Roadmap & Known Limitations (`v1.4.0`)

* **World Map Pins & Addon Markers on Top-Level Azeroth (`UiMapID = 947`):**
  * Currently, stock game pins and third-party addon markers on the top-level **Azeroth World Map (`947`)** are hidden while `MAWM` is active so misplaced stock pins don't float in the ocean. **Dynamic coordinate remapping for addon pins & waypoints on `947` is in active development for a future update.**
  * *(Inside all zoomed-in **Continent** and **Zone** maps, all game pins, waypoints, and map addons work 100% normally.)*
