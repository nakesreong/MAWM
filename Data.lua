local ADDON_NAME, MAWM = ...

MAWM.VERSION = "1.4.0"
MAWM.AZEROTH_MAP_ID = 947

local isRU = (GetLocale() == "ruRU")
MAWM.isRU = isRU

-- ============================================================================
-- 3 Selectable Geodesy Layout Modes (True Sturmbart Continent Proportions!)
--   1. "mawm"   : Broken Isles NE of Kalimdor, Zandalar SW ("South America"),
--                 Khaz Algar North/NE, Dragon Isles SE (Southern Hemisphere)
--   2. "hybrid" : Broken Isles NE of Kalimdor & Zandalar SW ("South America"),
--                 while Khaz Algar (SW) & Dragon Isles (NE) stay at Blizzard's spots
--   3. "blizz"  : All 10 continents at Blizzard's positions, scaled to true
--                 lore proportions (massive Kalimdor & EK, compact islands)
-- ============================================================================
MAWM.LAYOUT_ORDER = { "mawm", "hybrid", "blizz" }

MAWM.LAYOUTS = {
    mawm = {
        nameEN  = "MAWM Geodesy (Khaz Algar N • Dragon Isles SE)",
        nameRU  = "Геодезия MAWM (Каз Алгар С • Драконьи ЮВ)",
        shortEN = "MAWM",
        shortRU = "MAWM",
                                                                                continents = {
            Kalimdor        = { box = { 0.1263, 0.2260, 0.4097, 0.7840 }, label = { 0.2780, 0.5080 } },
            Northrend       = { box = { 0.3911, 0.0645, 0.5989, 0.2995 }, label = { 0.4950, 0.2880 } },
            BrokenIsles     = { box = { 0.3647, 0.2905, 0.4453, 0.4255 }, label = { 0.4050, 0.4400 } },
            Maelstrom       = { box = { 0.4185, 0.4075, 0.5715, 0.6325 }, label = { 0.5280, 0.5550 } },
            KulTiras        = { box = { 0.5887, 0.4140, 0.6613, 0.5220 }, label = { 0.6250, 0.5360 } },
            KhazAlgar       = { box = { 0.6002, 0.2230, 0.6838, 0.3070 }, label = { 0.6420, 0.3260 } },
            EasternKingdoms = { box = { 0.6431, 0.2290, 0.8869, 0.7410 }, label = { 0.7620, 0.5580 } },
            DragonIsles     = { box = { 0.7973, 0.4940, 0.9527, 0.7160 }, label = { 0.8750, 0.7300 } },
            Zandalar        = { box = { 0.3642, 0.6140, 0.4398, 0.7460 }, label = { 0.4020, 0.7600 } },
            Pandaria        = { box = { 0.4447, 0.7380, 0.5993, 0.9260 }, label = { 0.5220, 0.7300 } },
        },
    },
    hybrid = {
        nameEN  = "Hybrid (Broken Isles & Zandalar Shifted • KA & DI Stock)",
        nameRU  = "Гибрид (Расколотые и Зандалар сдвинуты • КА и ДО у Близз)",
        shortEN = "Hybrid",
        shortRU = "Гибрид",
                                                                                continents = {
            Kalimdor        = { box = { 0.1263, 0.2260, 0.4097, 0.7840 }, label = { 0.2780, 0.5080 } },
            Northrend       = { box = { 0.3811, 0.0645, 0.5889, 0.2995 }, label = { 0.4880, 0.2880 } },
            BrokenIsles     = { box = { 0.3647, 0.2905, 0.4453, 0.4255 }, label = { 0.4050, 0.4400 } },
            Maelstrom       = { box = { 0.4185, 0.4075, 0.5715, 0.6325 }, label = { 0.5280, 0.5550 } },
            KulTiras        = { box = { 0.6017, 0.4380, 0.6743, 0.5460 }, label = { 0.6380, 0.5600 } },
            KhazAlgar       = { box = { 0.3132, 0.7630, 0.3968, 0.8470 }, label = { 0.3550, 0.8660 } },
            EasternKingdoms = { box = { 0.6701, 0.2460, 0.9139, 0.7580 }, label = { 0.7880, 0.5750 } },
            DragonIsles     = { box = { 0.5743, 0.0810, 0.7297, 0.3030 }, label = { 0.6520, 0.3180 } },
            Zandalar        = { box = { 0.3672, 0.6140, 0.4428, 0.7460 }, label = { 0.4050, 0.7600 } },
            Pandaria        = { box = { 0.4447, 0.7380, 0.5993, 0.9260 }, label = { 0.5220, 0.7300 } },
        },
    },
    blizz = {
        nameEN  = "Blizzard Layout (True Sturmbart Proportions)",
        nameRU  = "Раскладка Blizzard (Пропорции Штурмбарта)",
        shortEN = "Blizzard",
        shortRU = "Близзард",
                                                                                continents = {
            Kalimdor        = { box = { 0.1203, 0.2260, 0.4037, 0.7840 }, label = { 0.2720, 0.5080 } },
            Northrend       = { box = { 0.3761, 0.0645, 0.5839, 0.2995 }, label = { 0.4800, 0.2880 } },
            BrokenIsles     = { box = { 0.5247, 0.2875, 0.6053, 0.4225 }, label = { 0.5650, 0.4340 } },
            Maelstrom       = { box = { 0.4015, 0.3995, 0.5545, 0.6245 }, label = { 0.5120, 0.5480 } },
            KulTiras        = { box = { 0.6037, 0.4410, 0.6763, 0.5490 }, label = { 0.6340, 0.5620 } },
            KhazAlgar       = { box = { 0.3132, 0.7630, 0.3968, 0.8470 }, label = { 0.3550, 0.8660 } },
            EasternKingdoms = { box = { 0.6761, 0.2460, 0.9199, 0.7580 }, label = { 0.7940, 0.5750 } },
            DragonIsles     = { box = { 0.5773, 0.0810, 0.7327, 0.3030 }, label = { 0.6550, 0.3180 } },
            Zandalar        = { box = { 0.5422, 0.5720, 0.6178, 0.7040 }, label = { 0.5920, 0.7140 } },
            Pandaria        = { box = { 0.4047, 0.7400, 0.5593, 0.9280 }, label = { 0.4720, 0.7320 } },
        },
    },
}

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
        titleRU = "№8. Пандария: Южное полушарие и «обогреватель» Вечноцветущего дола",
        descEN  = "Positioned deep in the southern ocean; kept lush and unfrozen despite its southern latitude by the Titan engine and Well of Eternity waters of the Vale of Eternal Blossoms!",
        descRU  = "Расположена глубоко в южном океане: от оледенения на южной широте её спасает титанический источник вод Вечности в Вечноцветущем доле!",
    },
}
