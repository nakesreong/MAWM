# 🐾 MAWM — Most Accurate World Map

> **Purr-fectly Realigned Azeroth Geography for World of Warcraft (`12.0.1` / `11.x`)**
> *Built from genuine 4K Blizzard CASC map tiles (`UiMapArtID 970 / 1792`) & custom Cartographer Parchment art.*

---

## 🌍 What Does `MAWM` Fix?

For 20 years, Blizzard has added expansion continents onto the Azeroth World Map (`UiMapID = 947`) wherever empty pixels happened to exist, breaking **climate zones**, **Pre-Sundering Night Elf / Titan / Black Empire borders**, and **Warcraft III naval routes**.

**`MAWM` (Most Accurate World Map)** replaces the Azeroth World Map (`mapID = 947`) with a lore-accurate, tectonically realigned map while preserving **full interactive continent navigation** and **Blizzard's native golden coastline hover highlights (`HighlightFileDataID`)** at the new continent coordinates!

| # | Continent / Feature | Stock Blizzard Map Problem | `MAWM` Realigned Fix & Lore Proof |
|---|---|---|---|
| **1** | **Planetary Ocean Margins** (*The Veiled Sea & The Forbidding Sea*) | Kalimdor and the Eastern Kingdoms are crammed flat against the left and right edges of the frame. | Continents are shifted inward, restoring **wide Pacific-scale oceans** on both sides so Azeroth reads as a true planetary projection. |
| **2** | **Broken Isles** (`619`) | Dropped in the middle of the central ocean east of the Maelstrom. | Moved **northeast of Kalimdor** (off the coast of **Azshara** and SW of **Northrend**): **Azsuna** aligns with the Highborne ruins of Azshara, snowy **Highmountain** faces **Borean Tundra**, and **Suramar / Broken Shore** face the **Maelstrom**. |
| **3** | **Khaz Algar — Isle of Dorn** (`2274`) | Drawn as an oversized southern blob west of Pandaria. | Sized accurately as the **tiny surface Isle of Dorn** (~Teldrassil scale, since 75%+ of Khaz Algar is underground: *Ringing Deeps, Hallowfall, Azj-Kahet*) and placed **east of Northrend** along the **Ulduar / Storm Peaks** Titan forge belt. |
| **4 & 5** | **Kul Tiras** (`876`) & **Admiral Daelin Proudmoore's Fleet Route** | Stuffed into a tight gap where Daelin Proudmoore's WC3 fleet would have had to sail straight through the Maelstrom vortex. | Placed **east of the Maelstrom** in the central sea. In *Warcraft III: The Frozen Throne* (*Founding of Durotar*), Admiral Proudmoore sails **southwest from Kul Tiras to Theramore and Durotar** through open southern waters without ever crossing the Maelstrom! |
| **6** | **Dragon Isles** (`1978`) | Floating in the far northeast corner with inverted climate zones. | Moved **southeast of the Eastern Kingdoms** into the **Southern Hemisphere**: its internal climate finally makes sense — the volcanic **Waking Shores** are in the **north** (closer to the Equator & **Blackrock Mountain**), while the snowy tundra of **The Azure Span** is in the **south** (closer to the South Pole!), and **Amirdrassil** aligns opposite **Duskwood**'s Emerald Dream portal. |
| **7 & 8** | **Zandalar** (`875`) & **Pandaria** (`424`) | Stacked tightly in the central-south sea. | **Zandalar** sits southwest of the Maelstrom as Azeroth's South American continent; **Pandaria** is pushed deep into the southern polar sea (where snowy **Kun-Lai Summit** is in the north, and the continent avoids freezing over thanks to the Titan/Mogu geothermal & arcane heat source at its center — the **Vale of Eternal Blossoms**). |

---

## ✨ Key In-Game Features

* **Two High-Resolution (`3072×2048` / `3×2` `1024×1024` Lossless RLE TGA) Map Styles:**
  1. **Official 4K Blizzard CASC Realigned (`blizz` — Default):** Exact continent stencils extracted from Blizzard's official `UiMapArtID = 970 / 1792` 4K CASC map tiles on a clean, warm golden-amber cartographer's parchment ocean with engraved sea monsters and compass rose.
  2. **Cartographer's Illustrated Parchment (`carto`):** Unified warm antique parchment aesthetic matching zoomed-in continent maps.
* **Native Blizzard Golden Coastline Highlights (`1:1` DB2 Accuracy):** Hovering over any realigned continent displays Blizzard's built-in golden coastline glow (`HighlightFileDataID` from `UiMapAssignment.db2`) at the continent's exact new coordinates.
* **Automatic Multi-Language Map Typography (All 11 Official WoW Client Locales):** Automatically detects your WoW client language (`GetLocale()`) and renders authentic engraved continent & sea labels in **English (`enUS`/`enGB`)**, **Russian (`ruRU`)**, **German (`deDE`)**, **French (`frFR`)**, **Spanish (`esES`/`esMX`)**, **Italian (`itIT`)**, **Portuguese (`ptBR`)**, **Korean (`koKR`)**, **Simplified Chinese (`zhCN`)**, and **Traditional Chinese (`zhTW`)** (`Alt-Click` the map button or use `/mawm lang` to switch anytime).
* **Full Interactive Click-to-Navigate:**
  * **Left-Click** any continent on the realigned Azeroth map to zoom directly into that continent (`Kalimdor`, `Eastern Kingdoms`, `Northrend`, `Pandaria`, `Broken Isles`, `Zandalar`, `Kul Tiras`, `Dragon Isles`, `Khaz Algar`, `The Maelstrom`).
  * **Right-Click** anywhere on the Azeroth map to zoom out to the Cosmic Map (`946`).
  * **Mouse Wheel** zooms in and out smoothly.
* **Interactive Lore & Naval Fleet Route Overlay (`[Lore]` mode):**
  * Toggleable visual overlay displaying **Admiral Daelin Proudmoore's WC3 Fleet Trajectory**, **Tectonic & Climate Vectors**, and **Interactive Geodesy Pins (`#1`–`#8`)** with full bilingual (**English & Russian**) tooltips.

---

## 🛠️ Roadmap & Known Limitations (`v1.3.1`)

* **World Map Pins & Addon Markers on Top-Level Azeroth (`UiMapID = 947`):**
  * Currently, stock game pins and third-party addon markers on the top-level **Azeroth World Map (`947`)** are hidden while `MAWM` is active (so old stock pins don't float in the middle of the ocean). **Dynamic coordinate remapping for addon pins & waypoints on `947` is currently in development for an upcoming update!**
  * *(Note: Inside all zoomed-in **Continent** and **Zone** maps, all game pins, waypoints, and map addons work 100% normally!)*

---

## 🎮 Controls & Slash Commands

Use the **`MAWM` button** at the top-right of the World Map canvas:
* **Left-Click:** Toggle `MAWM` Realigned Map **ON / OFF** (or jump to the Azeroth World Map if viewing a zone/continent).
* **Right-Click:** Switch Map Style (**Official 4K Blizzard CASC** $\leftrightarrow$ **Cartographer's Parchment**).
* **Alt-Click:** Switch Map Labels Language (**English `[EN]`** $\leftrightarrow$ **Russian `[RU]`**).
* **Shift-Click / Middle-Click:** Toggle the **Lore & Naval Fleet Route Overlay**.

### Slash Commands (`/mawm` or `/meow`)
* `/mawm` (or `/meow`) — Toggle the Realigned World Map ON / OFF.
* `/mawm style` — Switch between **Official 4K Blizzard CASC** and **Cartographer's Parchment**.
* `/mawm lang` — Switch map labels between **English (`EN`)** and **Russian (`RU`)**.
* `/mawm lore` — Toggle **Daelin Proudmoore's Fleet Route & Geodesy Notes**.
* `/mawm open` — Open the World Map directly to **Azeroth (`947`)**.
* `/mawm help` — Show command list.
