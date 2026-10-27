local ADDON_NAME, MAWM = ...

MAWM.VERSION = "1.5.0"
MAWM.AZEROTH_MAP_ID = 947

local isRU = (GetLocale() == "ruRU")
MAWM.isRU = isRU

-- ============================================================================
-- 1. Individual Continent Scale Multipliers (Relative to Sturmbart 1.0x Base)
--    You can edit these multipliers directly here in Data.lua (then /reload),
--    or adjust them live in-game via:
--      /mawm scale <Continent> <Multiplier>   (e.g. /mawm scale KulTiras 1.8)
--      /mawm scale reset                      (reset all to Data.lua defaults)
-- ============================================================================
MAWM.CONTINENT_SCALES = {
    Kalimdor        = 1.30, -- Primary supercontinent (1.3x)
    EasternKingdoms = 1.20, -- Slightly smaller than Kalimdor (1.2x)
    Northrend       = 1.40, -- Polar continent (1.4x)
    Pandaria        = 1.50, -- Southern continent (1.5x)
    DragonIsles     = 1.40, -- Dragon Isles (1.4x)
    BrokenIsles     = 1.50, -- Broken Isles archipelago (1.5x)
    Zandalar        = 1.50, -- Zandalar empire island (1.5x)
    KulTiras        = 1.55, -- Kul Tiras kingdom island (1.55x)
    KhazAlgar       = 1.60, -- Isle of Dorn surface island (1.6x)
    Maelstrom       = 1.50, -- The Maelstrom + Lost Isles + Kezan (1.5x)
}

-- Base 1.0x normalized canvas dimensions (width, height on 3072x2048) & automatic
-- coastline-relative label anchor rules so labels move automatically when scaled!
--   mode = "inside" : lx = cx + dx * w, ly = cy + dy * h
--   mode = "below"  : lx = cx + dx * w, ly = (cy + 0.5 * h) + gapY
--   mode = "above"  : lx = cx + dx * w, ly = (cy - 0.5 * h) + gapY
MAWM.CONTINENT_GEOMETRY = {
    Kalimdor        = { baseW = 0.2180, baseH = 0.4292, labelRule = { mode = "inside", dx =  0.035, dy = 0.005 } },
    EasternKingdoms = { baseW = 0.2032, baseH = 0.4267, labelRule = { mode = "inside", dx = -0.012, dy = 0.142 } },
    Northrend       = { baseW = 0.1484, baseH = 0.1679, labelRule = { mode = "below",  dx =  0.000, gapY = -0.0115 } },
    Pandaria        = { baseW = 0.1031, baseH = 0.1253, labelRule = { mode = "above",  dx =  0.000, gapY = -0.0080 } },
    DragonIsles     = { baseW = 0.1110, baseH = 0.1586, labelRule = { mode = "below",  dx =  0.000, gapY =  0.0140 } },
    BrokenIsles     = { baseW = 0.0537, baseH = 0.0900, labelRule = { mode = "below",  dx =  0.000, gapY =  0.0145 } },
    KulTiras        = { baseW = 0.0468, baseH = 0.0697, labelRule = { mode = "below",  dx =  0.000, gapY =  0.0140 } },
    Zandalar        = { baseW = 0.0504, baseH = 0.0880, labelRule = { mode = "below",  dx =  0.000, gapY =  0.0140 } },
    KhazAlgar       = { baseW = 0.0522, baseH = 0.0525, labelRule = { mode = "below",  dx =  0.000, gapY =  0.0190 } },
    -- Inside sp_Maelstrom.tga, the fiery whirlpool eye is at nx = 0.548 (dx = +0.048 from sprite center),
    -- so dx = 0.048 centers "THE MAELSTROM / ВОДОВОРОТ" dead-center under the whirlpool eye!
    Maelstrom       = { baseW = 0.1020, baseH = 0.1500, labelRule = { mode = "inside", dx =  0.048, dy = 0.160 } },
}

-- Helper to compute dynamic { x1, y1, x2, y2 } box and { lx, ly } label position
-- from center (cx, cy) and active scale multiplier:
function MAWM:ComputeContinentBoxAndLabel(key, cx, cy, customScale)
    local geom = self.CONTINENT_GEOMETRY[key]
    if not geom then
        return { cx - 0.05, cy - 0.05, cx + 0.05, cy + 0.05 }, { cx, cy }
    end
    local mult = customScale
    if not mult then
        if MAWM_DB and MAWM_DB.scales and MAWM_DB.scales[key] then
            mult = MAWM_DB.scales[key]
        else
            mult = self.CONTINENT_SCALES[key] or 1.0
        end
    end
    local w = geom.baseW * mult
    local h = geom.baseH * mult
    local x1, y1, x2, y2 = cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy + h * 0.5

    local rule = geom.labelRule
    local lx = cx + (rule.dx or 0) * w
    local ly = cy
    if rule.mode == "inside" then
        ly = cy + (rule.dy or 0) * h
    elseif rule.mode == "below" then
        ly = y2 + (rule.gapY or 0.014)
    elseif rule.mode == "above" then
        ly = y1 + (rule.gapY or -0.008)
    end
    return { x1, y1, x2, y2 }, { lx, ly }
end

-- ============================================================================
-- 2. 3 Selectable Geodesy Layout Modes (Centers cx, cy per Continent)
--   1. "mawm"   : Broken Isles NE of Kalimdor, Zandalar SW ("South America"),
--                 Khaz Algar North/NE, Dragon Isles SE (Southern Hemisphere)
--   2. "hybrid" : Broken Isles NE of Kalimdor & Zandalar SW ("South America"),
--                 while Khaz Algar (SW) & Dragon Isles (NE) stay at Blizzard's spots
--   3. "blizz"  : All 10 continents at Blizzard's positions, scaled by
--                 MAWM.CONTINENT_SCALES
-- ============================================================================
MAWM.LAYOUT_ORDER = { "mawm", "hybrid", "blizz" }

MAWM.LAYOUTS = {
    mawm = {
        nameEN  = "MAWM Geodesy (Khaz Algar N • Dragon Isles SE)",
        nameRU  = "Геодезия MAWM (Каз Алгар С • Драконьи ЮВ)",
        shortEN = "MAWM",
        shortRU = "MAWM",
        continents = {
            Kalimdor        = { center = { 0.2680, 0.5050 } },
            Northrend       = { center = { 0.4950, 0.1820 } },
            BrokenIsles     = { center = { 0.4050, 0.3580 } },
            Maelstrom       = { center = { 0.4950, 0.5200 } },
            KulTiras        = { center = { 0.6250, 0.4680 } },
            KhazAlgar       = { center = { 0.6420, 0.2650 } },
            EasternKingdoms = { center = { 0.7650, 0.4850 } },
            DragonIsles     = { center = { 0.8750, 0.6050 } },
            Zandalar        = { center = { 0.4020, 0.6800 } },
            Pandaria        = { center = { 0.5220, 0.8320 } },
        },
    },
    hybrid = {
        nameEN  = "Hybrid (Broken Isles & Zandalar Shifted • KA & DI Stock)",
        nameRU  = "Гибрид (Расколотые и Зандалар сдвинуты • КА и ДО у Близз)",
        shortEN = "Hybrid",
        shortRU = "Гибрид",
        continents = {
            Kalimdor        = { center = { 0.2680, 0.5050 } },
            Northrend       = { center = { 0.4850, 0.1820 } },
            BrokenIsles     = { center = { 0.4050, 0.3580 } },
            Maelstrom       = { center = { 0.4950, 0.5200 } },
            KulTiras        = { center = { 0.6380, 0.4920 } },
            KhazAlgar       = { center = { 0.3550, 0.8050 } },
            EasternKingdoms = { center = { 0.7920, 0.5020 } },
            DragonIsles     = { center = { 0.6520, 0.1920 } },
            Zandalar        = { center = { 0.4050, 0.6800 } },
            Pandaria        = { center = { 0.5220, 0.8320 } },
        },
    },
    blizz = {
        nameEN  = "Blizzard Layout (True Sturmbart Proportions)",
        nameRU  = "Раскладка Blizzard (Пропорции Штурмбарта)",
        shortEN = "Blizzard",
        shortRU = "Близзард",
        continents = {
            Kalimdor        = { center = { 0.2620, 0.5050 } },
            Northrend       = { center = { 0.4800, 0.1820 } },
            BrokenIsles     = { center = { 0.5650, 0.3550 } },
            Maelstrom       = { center = { 0.4780, 0.5120 } },
            KulTiras        = { center = { 0.6400, 0.4950 } },
            KhazAlgar       = { center = { 0.3550, 0.8050 } },
            EasternKingdoms = { center = { 0.7980, 0.5020 } },
            DragonIsles     = { center = { 0.6550, 0.1920 } },
            Zandalar        = { center = { 0.5800, 0.6380 } },
            Pandaria        = { center = { 0.4820, 0.8340 } },
        },
    },
}

-- Populate initial .box and .label fields for backwards compatibility & fast lookup
function MAWM:RebuildLayoutBoxes()
    for _, lay in pairs(self.LAYOUTS) do
        if lay.continents then
            for key, cSpec in pairs(lay.continents) do
                if cSpec.center then
                    cSpec.box, cSpec.label = self:ComputeContinentBoxAndLabel(key, cSpec.center[1], cSpec.center[2])
                end
            end
        end
    end
    if self.CONTINENTS then
        local mawmConts = self.LAYOUTS.mawm.continents
        for _, cont in ipairs(self.CONTINENTS) do
            if mawmConts[cont.key] then
                cont.box = mawmConts[cont.key].box
            end
        end
    end
end

-- ============================================================================
-- Realigned Azeroth Continent Metadata & Label Atlas Cells (UiMapID = 947)
-- ============================================================================
MAWM.CONTINENTS = {
    {
        key = "KhazAlgar",
        uiMapID = 2274,
        atlasCell = 4,
        fallbackNameEN = "Khaz Algar (Isle of Dorn)",
        fallbackNameRU = "Каз Алгар (Остров Дорн)",
        hlTex = "hl_KhazAlgar",
        origBox = { 0.2448, 0.7520, 0.3490, 0.8562 },
        box = { 0.6002, 0.2230, 0.6838, 0.3070 },
    },
    {
        key = "BrokenIsles",
        uiMapID = 619,
        atlasCell = 2,
        fallbackNameEN = "Broken Isles",
        fallbackNameRU = "Расколотые острова",
        hlTex = "hl_BrokenIsles",
        origBox = { 0.5169, 0.3008, 0.6510, 0.5254 },
        box = { 0.3647, 0.2905, 0.4453, 0.4255 },
    },
    {
        key = "KulTiras",
        uiMapID = 876,
        atlasCell = 3,
        fallbackNameEN = "Kul Tiras",
        fallbackNameRU = "Кул-Тирас",
        hlTex = "hl_KulTiras",
        origBox = { 0.6536, 0.3887, 0.7800, 0.5762 },
        box = { 0.5887, 0.4140, 0.6613, 0.5220 },
    },
    {
        key = "Maelstrom",
        uiMapID = 948,
        atlasCell = 9,
        fallbackNameEN = "The Maelstrom",
        fallbackNameRU = "Водоворот",
        hlTex = "hl_Maelstrom",
        origBox = { 0.3932, 0.3750, 0.5260, 0.5703 },
        box = { 0.4185, 0.4075, 0.5715, 0.6325 },
    },
    {
        key = "Zandalar",
        uiMapID = 875,
        atlasCell = 7,
        fallbackNameEN = "Zandalar",
        fallbackNameRU = "Зандалар",
        hlTex = "hl_Zandalar",
        origBox = { 0.4896, 0.5332, 0.6016, 0.7285 },
        box = { 0.3642, 0.6140, 0.4398, 0.7460 },
    },
    {
        key = "DragonIsles",
        uiMapID = 1978,
        atlasCell = 6,
        fallbackNameEN = "Dragon Isles",
        fallbackNameRU = "Драконьи острова",
        hlTex = "hl_DragonIsles",
        origBox = { 0.6797, 0.0898, 0.8424, 0.3223 },
        box = { 0.7973, 0.4940, 0.9527, 0.7160 },
    },
    {
        key = "Northrend",
        uiMapID = 113,
        atlasCell = 1,
        fallbackNameEN = "Northrend",
        fallbackNameRU = "Нордскол",
        hlTex = "hl_Northrend",
        origBox = { 0.3776, 0.0215, 0.6042, 0.2773 },
        box = { 0.3911, 0.0645, 0.5989, 0.2995 },
    },
    {
        key = "Pandaria",
        uiMapID = 424,
        atlasCell = 8,
        fallbackNameEN = "Pandaria",
        fallbackNameRU = "Пандария",
        hlTex = "hl_Pandaria",
        origBox = { 0.3854, 0.6797, 0.5977, 0.9375 },
        box = { 0.4447, 0.7380, 0.5993, 0.9260 },
    },
    {
        key = "Kalimdor",
        uiMapID = 12,
        atlasCell = 0,
        fallbackNameEN = "Kalimdor",
        fallbackNameRU = "Калимдор",
        hlTex = "hl_Kalimdor",
        origBox = { 0.0469, 0.2930, 0.2969, 0.7852 },
        box = { 0.1263, 0.2260, 0.4097, 0.7840 },
    },
    {
        key = "EasternKingdoms",
        uiMapID = 13,
        atlasCell = 5,
        fallbackNameEN = "Eastern Kingdoms",
        fallbackNameRU = "Восточные королевства",
        hlTex = "hl_EasternKingdoms",
        origBox = { 0.7708, 0.2695, 0.9995, 0.7500 },
        box = { 0.6431, 0.2290, 0.8869, 0.7410 },
    },
}

MAWM:RebuildLayoutBoxes()

-- Sea Labels in the Label Atlas (cells 10 & 11)
MAWM.SEA_LABELS = {
    { atlasCell = 10, x = 0.0950, y = 0.4300 }, -- The Veiled Sea
    { atlasCell = 11, x = 0.9150, y = 0.4050 }, -- The Forbidding Sea
}

-- ============================================================================
-- Interactive Lore & Geodesy Badges (Shown when Lore Overlay is enabled)
-- ============================================================================
MAWM.LORE_BADGES = {
    {
        id = "1",
        x = 0.145, y = 0.515, r = 0.024,
        titleEN = "#1. True Planetary Ocean Margins & Continent Proportions",
        titleRU = "№1. Истинные пропорции материков и океанов (Сокрытое море)",
        descEN  = "Continents are scaled to their true lore proportions (inspired by Sturmbart's cartography): Kalimdor and the Eastern Kingdoms are massive primary supercontinents, while island kingdoms and archipelagos sit at authentic planetary scale.",
        descRU  = "Материки приведены к их истинным лорным пропорциям (по геодезии Штурмбарта): Калимдор и Восточные королевства — гигантские главные суперконтиненты, а архипелаги и островные королевства имеют естественный масштаб.",
    },
    {
        id = "2",
        x = 0.445, y = 0.235, r = 0.024,
        titleEN = "#2. Broken Isles: Under Western Northrend",
        titleRU = "№2. Расколотые острова: под западным Нордсколом",
        descEN  = "• Highmountain's snowy peaks sit directly south of Borean Tundra in Northrend.\n• Azsuna faces Azshara across the western bay.\n• Suramar & the Broken Shore look straight into the Maelstrom.",
        descRU  = "• Заснеженное Крутогорье лежит прямо к югу от Борейской тундры Нордскола.\n• Азсуна обращена к заливу Азшары.\n• Сурамар и Расколотый берег смотрят прямо в Водоворот.",
    },
    {
        id = "3",
        x = 0.608, y = 0.360, r = 0.024,
        titleEN = "#3. Kul Tiras & Admiral Proudmoore's Fleet Route",
        titleRU = "№3. Кул-Тирас и маршрут флота адмирала Праудмура",
        descEN  = "Placed east of the Maelstrom across from Gilneas. In WC3: The Frozen Throne, Admiral Daelin Proudmoore sailed from Kul Tiras to Theramore — now a clean, unobstructed southwest sea lane passing south of the Maelstrom!",
        descRU  = "Размещён к востоку от Водоворота напротив Гилнеаса. В WC3: The Frozen Throne адмирал Даэлин Праудмур привёл флот из Кул-Тираса в Терамор — теперь это прямой и чистый юго-западный морской путь в обход Водоворота!",
    },
    {
        id = "4",
        x = 0.665, y = 0.205, r = 0.024,
        titleEN = "#4. Khaz Algar: Tiny Surface Isle of Dorn (~Teldrassil Size)",
        titleRU = "№4. Каз Алгар: крошечный Остров Дорн (~размером с Тельдрассил)",
        descEN  = "On the surface world map, Khaz Algar is ONLY the Isle of Dorn. The rest of Khaz Algar is a massive vertical underground network! Placed north of Kul Tiras and northwest of Quel'Thalas in MAWM mode (or SW in Hybrid/Blizzard mode).",
        descRU  = "На поверхности мира Каз Алгар — это ТОЛЬКО Остров Дорн. Остальной Каз Алгар уходит глубоко под землю! Размещён к северу от Кул-Тираса в режиме MAWM (или на юго-западе в режимах Гибрид/Blizzard).",
    },
    {
        id = "5",
        x = 0.770, y = 0.435, r = 0.024,
        titleEN = "#5. Eastern Kingdoms: Full Supercontinent Scale",
        titleRU = "№5. Восточные королевства: масштаб суперконтинента",
        descEN  = "Restored to full supercontinent scale from Quel'Thalas in the north to Cape of Stranglethorn in the south, across the naval channel from Kul Tiras.",
        descRU  = "Восстановлены в масштабе огромного суперконтинента от Кель'Таласа на севере до Мыса Тернистой долины на юге, через пролив от Кул-Тираса.",
    },
    {
        id = "6",
        x = 0.885, y = 0.530, r = 0.024,
        titleEN = "#6. Dragon Isles: Southern Hemisphere Climate & Amirdrassil",
        titleRU = "№6. Драконьи острова: климат Южного полушария и Амирдрассил",
        descEN  = "• Climate proof: The volcanic Waking Shores are in the NORTH (closer to the Equator & Blackrock Mountain), while the snowy tundra of the Azure Span is in the SOUTH (facing the Southern Pole)!\n• Amirdrassil on the west coast aligns near Duskwood's Emerald Dream portal.",
        descRU  = "• Климатическое доказательство: вулканические Берега Пробуждения лежат на СЕВЕРЕ (ближе к экватору и Чёрной горе), а снежная тундра Лазурного Простора — на ЮГЕ (ближе к Южному полюсу)!\n• Амирдрассил на западе оказывается рядом с порталом Изумрудного Сна в Сумеречном лесу.",
    },
    {
        id = "7",
        x = 0.418, y = 0.605, r = 0.024,
        titleEN = "#7. Zandalar: 'South America' of Azeroth & Goblin Caribbean Basin",
        titleRU = "№7. Зандалар: «Южная Америка» Азерота и Карибский бассейн гоблинов",
        descEN  = "Positioned southeast of Southern Kalimdor (Tanaris / Un'Goro) like South America relative to North America, creating a warm tropical Caribbean sea for Kezan and the Goblin islands!",
        descRU  = "Расположен к юго-востоку от Южного Калимдора (Танариса и Ун'Горо) подобно Южной Америке относительно Северной, образуя тёплый тропический Карибский бассейн для Кезана и островов гоблинов!",
    },
    {
        id = "8",
        x = 0.625, y = 0.825, r = 0.024,
        titleEN = "#8. Pandaria: Southern Hemisphere Warmed by the Vale of Eternal Blossoms",
        titleRU = "№8. Pandaria: Южное полушарие и «обогреватель» Вечноцветущего дола",
        descEN  = "Positioned deep in the southern ocean; kept lush and unfrozen despite its southern latitude by the Titan engine and Well of Eternity waters of the Vale of Eternal Blossoms!",
        descRU  = "Расположена глубоко в южном океане: от оледенения на южной широте её спасает титанический источник вод Вечности в Вечноцветущем доле!",
    },
}

-- ============================================================================
-- Dynamic Continent-Relative Ports & Transit Routes (Ships & Zeppelins)
-- Each port is anchored by (u, v) inside its continent sprite box so routes
-- automatically adapt when switching Layouts (MAWM/Hybrid/Blizzard) or Scales!
-- ============================================================================
MAWM.PORTS = {
    Stormwind = {
        cont = "EasternKingdoms", u = 0.315, v = 0.655,
        nameEN = "Stormwind Harbor", nameRU = "Гавань Штормграда",
    },
    Boralus = {
        cont = "KulTiras", u = 0.685, v = 0.550,
        nameEN = "Boralus Harbor (Tiragarde Sound)", nameRU = "Гавань Боралуса (Тирагардское поморье)",
    },
    ValianceKeep = {
        cont = "Northrend", u = 0.180, v = 0.740,
        nameEN = "Valiance Keep (Borean Tundra)", nameRU = "Крепость Отваги (Борейская тундра)",
    },
    WakingShores = {
        cont = "DragonIsles", u = 0.480, v = 0.340,
        nameEN = "Dragonscale Basecamp (Waking Shores)", nameRU = "Берега Пробуждения (Драконьи острова)",
    },
    Orgrimmar = {
        cont = "Kalimdor", u = 0.725, v = 0.440,
        nameEN = "Orgrimmar Zeppelin Towers (Durotar)", nameRU = "Башни дирижаблей Оргриммара (Дуротар)",
    },
    EchoIsles = {
        cont = "Kalimdor", u = 0.740, v = 0.510,
        nameEN = "Echo Isles Dock (Durotar)", nameRU = "Пристань Островов Эха (Дуротар)",
    },
    Tirisfal = {
        cont = "EasternKingdoms", u = 0.525, v = 0.285,
        nameEN = "Tirisfal Glades / Brill (Undercity)", nameRU = "Тирисфальские леса / Брилл (Подгород)",
    },
    Gromgol = {
        cont = "EasternKingdoms", u = 0.310, v = 0.805,
        nameEN = "Grom'gol Base Camp (Stranglethorn)", nameRU = "Лагерь Гром'гол (Тернистая долина)",
    },
    WarsongHold = {
        cont = "Northrend", u = 0.140, v = 0.650,
        nameEN = "Warsong Hold (Borean Tundra)", nameRU = "Крепость Песни Войны (Борейская тундра)",
    },
    Dazaralor = {
        cont = "Zandalar", u = 0.585, v = 0.745,
        nameEN = "Port of Zandalar (Dazar'alor)", nameRU = "Порт Зандалара (Дазар'алор)",
    },
    Ratchet = {
        cont = "Kalimdor", u = 0.680, v = 0.545,
        nameEN = "Ratchet (Northern Barrens)", nameRU = "Кабестан (Северные Степи)",
    },
    BootyBay = {
        cont = "EasternKingdoms", u = 0.415, v = 0.885,
        nameEN = "Booty Bay (Cape of Stranglethorn)", nameRU = "Пиратская Бухта (Мыс Тернистой долины)",
    },
}

MAWM.TRANSIT_ROUTES = {
    -- ALLIANCE ROUTES (Blue)
    {
        id = "A_SW_BORALUS",
        faction = "ALLIANCE",
        vesselEN = "Alliance Ship",
        vesselRU = "Корабль Альянса",
        from = "Stormwind",
        to   = "Boralus",
        curve = -0.045,
        titleEN = "Stormwind <-> Boralus (Kul Tiras)",
        titleRU = "Штормград <-> Боралус (Кул-Тирас)",
        boardEN = "Stormwind Harbor — Southern-center dock (left pier)",
        boardRU = "Гавань Штормграда — центральный левый причал",
        arriveEN = "Boralus Harbor — Main Tradewinds Market dock (Tiragarde Sound)",
        arriveRU = "Гавань Боралуса — главный причал Рынка Семи Ветров",
    },
    {
        id = "A_SW_NORTHREND",
        faction = "ALLIANCE",
        vesselEN = "Alliance Icebreaker Ship",
        vesselRU = "Ледокол Альянса (Корабль)",
        from = "Stormwind",
        to   = "ValianceKeep",
        curve = 0.055,
        titleEN = "Stormwind <-> Valiance Keep (Northrend)",
        titleRU = "Штормград <-> Крепость Отваги (Нордскол)",
        boardEN = "Stormwind Harbor — Northernmost dock (far right pier)",
        boardRU = "Гавань Штормграда — самый северный (правый) причал",
        arriveEN = "Valiance Keep dock (Borean Tundra, Northrend)",
        arriveRU = "Причал Крепости Отваги (Борейская тундра, Нордскол)",
    },
    {
        id = "A_SW_DRAGONISLES",
        faction = "ALLIANCE",
        vesselEN = "Alliance Expedition Ship ('The Rugged Dragonscale')",
        vesselRU = "Корабль экспедиции Альянса",
        from = "Stormwind",
        to   = "WakingShores",
        curve = 0.040,
        titleEN = "Stormwind <-> Waking Shores (Dragon Isles)",
        titleRU = "Штормград <-> Берега Пробуждения (Драконьи о-ва)",
        boardEN = "Stormwind Harbor — Southernmost dock (leftmost pier)",
        boardRU = "Гавань Штормграда — самый южный (крайний левый) причал",
        arriveEN = "Wingrest Embassy coast (Waking Shores, Dragon Isles)",
        arriveRU = "Причал Посольства Крылатого Приюта (Берега Пробуждения)",
    },

    -- HORDE ROUTES (Red)
    {
        id = "H_ORG_TIRISFAL",
        faction = "HORDE",
        vesselEN = "Horde Zeppelin ('The Thundercaller')",
        vesselRU = "Дирижабль Орды («Призыватель Грома»)",
        from = "Orgrimmar",
        to   = "Tirisfal",
        curve = -0.110,
        titleEN = "Orgrimmar <-> Tirisfal Glades (Undercity / Brill)",
        titleRU = "Оргриммар <-> Тирисфальские леса (Подгород / Брилл)",
        boardEN = "Orgrimmar — Eastern Zeppelin Tower (above the Cleft of Shadow / Skyway)",
        boardRU = "Оргриммар — Восточная башня дирижаблей (или портал на башне у Брилла)",
        arriveEN = "Brill Zeppelin Tower (Tirisfal Glades, north of Undercity)",
        arriveRU = "Башня дирижаблей у Брилла (Тирисфальские леса, к северу от Подгорода)",
    },
    {
        id = "H_ORG_GROMGOL",
        faction = "HORDE",
        vesselEN = "Horde Zeppelin ('The Iron Eagle')",
        vesselRU = "Дирижабль Орды («Железный Орёл»)",
        from = "Orgrimmar",
        to   = "Gromgol",
        curve = 0.085,
        titleEN = "Orgrimmar <-> Grom'gol Base Camp (Stranglethorn)",
        titleRU = "Оргриммар <-> Лагерь Гром'гол (Тернистая долина)",
        boardEN = "Orgrimmar — Central Skyway Zeppelin Tower (southeast deck)",
        boardRU = "Оргриммар — башня дирижаблей на Верхней аллее (юго-восточная площадка)",
        arriveEN = "Grom'gol Base Camp Zeppelin Tower (Northern Stranglethorn)",
        arriveRU = "Башня дирижаблей Лагеря Гром'гол (Северная Тернистая долина)",
    },
    {
        id = "H_ORG_NORTHREND",
        faction = "HORDE",
        vesselEN = "Horde Armored Zeppelin ('The Mighty Wind')",
        vesselRU = "Бронированный дирижабль Орды («Могучий Ветер»)",
        from = "Orgrimmar",
        to   = "WarsongHold",
        curve = -0.055,
        titleEN = "Orgrimmar <-> Warsong Hold (Northrend)",
        titleRU = "Оргриммар <-> Крепость Песни Войны (Нордскол)",
        boardEN = "Orgrimmar — Western Skyway Zeppelin Tower (facing Mulgore)",
        boardRU = "Оргриммар — Западная башня дирижаблей на Верхней аллее",
        arriveEN = "Warsong Hold central tower (Borean Tundra, Northrend)",
        arriveRU = "Центральная башня Крепости Песни Войны (Борейская тундра, Нордскол)",
    },
    {
        id = "H_ORG_DRAGONISLES",
        faction = "HORDE",
        vesselEN = "Horde Expedition Zeppelin",
        vesselRU = "Дирижабль экспедиции Орды",
        from = "Orgrimmar",
        to   = "WakingShores",
        curve = 0.130,
        titleEN = "Orgrimmar <-> Waking Shores (Dragon Isles)",
        titleRU = "Оргриммар <-> Берега Пробуждения (Драконьи о-ва)",
        boardEN = "Durotar — Zeppelin Tower outside Orgrimmar main front gates",
        boardRU = "Дуротар — башня дирижаблей прямо перед главными воротами Оргриммара",
        arriveEN = "Wingrest Embassy Zeppelin Tower (Waking Shores, Dragon Isles)",
        arriveRU = "Башня дирижаблей у Посольства Крылатого Приюта (Берега Пробуждения)",
    },
    {
        id = "H_ECHO_ZANDALAR",
        faction = "HORDE",
        vesselEN = "Horde Zandalari Golden Ship",
        vesselRU = "Корабль Орды и Зандаларов",
        from = "EchoIsles",
        to   = "Dazaralor",
        curve = 0.045,
        titleEN = "Echo Isles (Durotar) <-> Port of Zandalar (Dazar'alor)",
        titleRU = "Острова Эха (Дуротар) <-> Порт Дазар'алора (Зандалар)",
        boardEN = "Echo Isles — Southern dock in Durotar",
        boardRU = "Острова Эха — южный причал на побережье Дуротара",
        arriveEN = "Port of Zandalar — Southern Grand Bazaar Harbor (Zuldazar)",
        arriveRU = "Порт Зандалара — южная гавань Великого базара (Зулдазар)",
    },

    -- NEUTRAL ROUTES (Black / Charcoal)
    {
        id = "N_RATCHET_BOOTYBAY",
        faction = "NEUTRAL",
        vesselEN = "Steamwheedle Cartel Neutral Ship ('The Maiden's Fancy')",
        vesselRU = "Нейтральный корабль Хитрой Шестерёнки («Девичий Каприз»)",
        from = "Ratchet",
        to   = "BootyBay",
        curve = 0.120,
        titleEN = "Ratchet (Barrens) <-> Booty Bay (Stranglethorn)",
        titleRU = "Кабестан (Степи) <-> Пиратская Бухта (Тернистая долина)",
        boardEN = "Ratchet Dock (Merchant Coast, Northern Barrens)",
        boardRU = "Причал Кабестана (Купеческое побережье, Северные Степи)",
        arriveEN = "Booty Bay Pier (Southern tip of Cape of Stranglethorn)",
        arriveRU = "Причал Пиратской Бухты (южная оконечность Мыса Тернистой долины)",
    },
}

