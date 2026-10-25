# Changelog — MAWM (Most Accurate World Map)

## [1.3.1] - 2026-10-25
### Added
- **Full 11-Locale Client Auto-Detection (`GetLocale()`):** Added engraved map label overlays for all official World of Warcraft locales: **English (`enUS`/`enGB`)**, **Russian (`ruRU`)**, **German (`deDE`)**, **French (`frFR`)**, **Spanish (`esES`/`esMX`)**, **Italian (`itIT`)**, **Portuguese (`ptBR`)**, **Korean (`koKR`)**, **Simplified Chinese (`zhCN`)**, and **Traditional Chinese (`zhTW`)**.
- **Warm Golden-Amber Warcraft Parchment Grading:** Matched the ocean parchment color temperature to Blizzard's zoomed-in continent maps while preserving crisp vector-sharp sea monsters, compass rose, and rhumb lines with zero compression artifacts.
- **Southern Hemisphere Climate Proof (`#6 Dragon Isles` & `#8 Pandaria`):** Updated interactive lore pins with the southern hemisphere climate gradient (volcanic *Waking Shores* in the north vs. snowy *Azure Span* in the south of the Dragon Isles; *Amirdrassil* opposite *Duskwood*; and *Vale of Eternal Blossoms* warming *Pandaria*).

### Fixed
- **1:1 Pixel-Locked DB2 Highlights:** Extracted exact continent stencils and `HighlightFileDataID` masks using native `UiMapAssignment.db2` coordinates so hover glows match every coastline with zero drift.
- **Clean Top-Level Canvas (`UiMapID = 947`):** Suppressed misplaced stock pins and the floating Khaz Algar cloud overlay while `MAWM` is active on `947`.
