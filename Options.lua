---------------------------------------------------------------------------------------
--  MAWM/Options.lua — SpArc / ElvUI-Style Modular Control Center UI
--  Authors: Gemini (Tiger) & Anya (5cr3am1ng5oul)
---------------------------------------------------------------------------------------
local ADDON_NAME, MAWM = ...

local CreateFrame = _G.CreateFrame
local UIParent    = _G.UIParent
local math        = _G.math
local string      = _G.string
local ipairs      = _G.ipairs
local pairs       = _G.pairs
local tostring    = _G.tostring

local TEX_DIR = "Interface\\AddOns\\MAWM\\Textures\\"
local controlFrame = nil
local isRefreshingUI = false
local currentTabIdx = 1

local function L(en, ru)
    if MAWM and MAWM.L then
        return MAWM.L(en, ru)
    end
    return en
end

local function ApplyFont(fs, size)
    if not fs then return end
    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fs:SetFont(fontPath, size or 12, "")
end

---------------------------------------------------------------------------------------
--  ELVUI / SPARC-STYLE UI COMPONENT BUILDERS
---------------------------------------------------------------------------------------
local function SetBackdropFlat(frame, bgR, bgG, bgB, bgA, brR, brG, brB, brA)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(bgR or 0.06, bgG or 0.06, bgB or 0.08, bgA or 0.95)
    frame:SetBackdropBorderColor(brR or 0.20, brG or 0.20, brB or 0.26, brA or 1.0)
end

local function CreateElvButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    SetBackdropFlat(btn, 0.12, 0.12, 0.16, 0.96, 0.26, 0.26, 0.34, 1.0)

    local accent = btn:CreateTexture(nil, "OVERLAY")
    accent:SetSize(3, height - 2)
    accent:SetPoint("LEFT", btn, "LEFT", 1, 0)
    accent:SetColorTexture(0.95, 0.78, 0.25, 0)
    btn.accent = accent

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyFont(fs, 12)
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fs:SetTextColor(0.92, 0.92, 0.96, 1)
    fs:SetText(text or "")
    btn.fs = fs

    function btn:SetText(str)
        self.fs:SetText(str or "")
    end

    function btn:SetSelected(isSelected)
        self._isSelected = isSelected and true or false
        if self._isSelected then
            SetBackdropFlat(self, 0.16, 0.32, 0.54, 0.98, 0.32, 0.65, 0.98, 1.0)
            self.fs:SetTextColor(1.0, 0.95, 0.70, 1)
            self.accent:SetColorTexture(0.35, 0.78, 1.0, 1)
        else
            SetBackdropFlat(self, 0.12, 0.12, 0.16, 0.96, 0.26, 0.26, 0.34, 1.0)
            self.fs:SetTextColor(0.90, 0.90, 0.95, 1)
            self.accent:SetColorTexture(0.25, 0.65, 1.0, 0)
        end
    end

    btn:SetScript("OnEnter", function(self)
        if not self._isSelected then
            SetBackdropFlat(self, 0.18, 0.22, 0.32, 0.98, 0.38, 0.62, 0.95, 1.0)
            self.fs:SetTextColor(1, 1, 1, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetSelected(self._isSelected)
    end)

    return btn
end

local function CreateElvGroupBox(parent, titleEN, titleRU, x, y, w, h)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    container:SetSize(w, h)

    local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyFont(header, 13)
    header:SetPoint("TOPLEFT", container, "TOPLEFT", 2, 0)
    header:SetTextColor(1.0, 0.82, 0.18, 1)
    header:SetText(L(titleEN, titleRU))
    container.header  = header
    container.titleEN = titleEN
    container.titleRU = titleRU

    local box = CreateFrame("Frame", nil, container, "BackdropTemplate")
    box:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -20)
    box:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    SetBackdropFlat(box, 0.08, 0.08, 0.11, 0.92, 0.20, 0.20, 0.27, 1.0)
    container.box = box

    return container, box
end

---------------------------------------------------------------------------------------
--  BUILD SPARC-STYLE CONTROL CENTER WINDOW
---------------------------------------------------------------------------------------
local function EnsureControlCenter()
    if controlFrame then
        return controlFrame
    end

    controlFrame = CreateFrame("Frame", "MAWMControlCenter", UIParent, "BackdropTemplate")
    controlFrame:SetSize(840, 560)
    controlFrame:SetPoint("CENTER")
    controlFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    controlFrame:SetFrameLevel(200)
    controlFrame:SetMovable(true)
    controlFrame:EnableMouse(true)
    controlFrame:RegisterForDrag("LeftButton")
    controlFrame:SetScript("OnDragStart", controlFrame.StartMoving)
    controlFrame:SetScript("OnDragStop", controlFrame.StopMovingOrSizing)
    SetBackdropFlat(controlFrame, 0.05, 0.05, 0.07, 0.97, 0.24, 0.24, 0.32, 1.0)
    controlFrame:Hide()

    local ui = {
        groupBoxes  = {},
        checks      = {},
        scaleSliders = {},
        layoutBtns  = {},
        styleBtns   = {},
        langBtns    = {},
        routeRows   = {},
    }
    controlFrame.ui = ui

    -- 1. Top Header Bar
    local topBar = CreateFrame("Frame", nil, controlFrame, "BackdropTemplate")
    topBar:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", 1, -1)
    topBar:SetPoint("TOPRIGHT", controlFrame, "TOPRIGHT", -1, -1)
    topBar:SetHeight(50)
    SetBackdropFlat(topBar, 0.07, 0.07, 0.10, 0.98, 0.18, 0.18, 0.24, 1.0)

    local headerIcon = topBar:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(32, 32)
    headerIcon:SetPoint("LEFT", topBar, "LEFT", 14, 0)
    headerIcon:SetTexture(TEX_DIR .. "Logo")

    local logoTitle = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyFont(logoTitle, 18)
    logoTitle:SetPoint("LEFT", headerIcon, "RIGHT", 10, 5)
    logoTitle:SetText("|cffffd100MAWM|r")

    local verText = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyFont(verText, 11)
    verText:SetPoint("TOPLEFT", logoTitle, "BOTTOMLEFT", 0, -1)
    verText:SetTextColor(0.55, 0.80, 1.0, 1)
    verText:SetText("v" .. tostring(MAWM.VERSION or "1.4.0"))

    local subTitle = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyFont(subTitle, 12)
    subTitle:SetPoint("LEFT", topBar, "LEFT", 160, 0)
    subTitle:SetTextColor(0.80, 0.80, 0.88, 1)
    ui.subTitle = subTitle

    local closeBtn = CreateElvButton(topBar, 28, 26, "X")
    closeBtn:SetPoint("RIGHT", topBar, "RIGHT", -10, 0)
    closeBtn:SetScript("OnClick", function() controlFrame:Hide() end)

    local langTopBtn = CreateElvButton(topBar, 96, 26, "")
    langTopBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    langTopBtn:SetScript("OnClick", function()
        local cur = MAWM.GetActiveLang()
        MAWM_DB.lang = (cur == "ru") and "en" or "ru"
        MAWM:RefreshMap()
        controlFrame:RefreshUI()
    end)
    ui.langTopBtn = langTopBtn

    local openMapBtn = CreateElvButton(topBar, 145, 26, "")
    openMapBtn:SetPoint("RIGHT", langTopBtn, "LEFT", -6, 0)
    openMapBtn:SetScript("OnClick", function()
        if not WorldMapFrame:IsShown() then
            ToggleWorldMap()
        end
        WorldMapFrame:SetMapID(MAWM.AZEROTH_MAP_ID or 947)
        MAWM_DB.enabled = true
        MAWM:RefreshMap()
        controlFrame:RefreshUI()
    end)
    ui.openMapBtn = openMapBtn

    subTitle:SetPoint("RIGHT", openMapBtn, "LEFT", -10, 0)
    subTitle:SetJustifyH("LEFT")
    subTitle:SetWordWrap(false)

    -- 2. Left Sidebar (Navigation Column)
    local sidebar = CreateFrame("Frame", nil, controlFrame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", 1, -50)
    sidebar:SetPoint("BOTTOMLEFT", controlFrame, "BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(204)
    SetBackdropFlat(sidebar, 0.04, 0.04, 0.06, 0.98, 0.18, 0.18, 0.24, 1.0)

    local navDefs = {
        { en = "1. Map & Layout",     ru = "1. Карта и Раскладка" },
        { en = "2. Continent Scales", ru = "2. Размеры материков" },
        { en = "3. Ships & Zeppelins",ru = "3. Корабли и Дирижабли" },
    }
    local navButtons = {}
    local pages = {}
    ui.navButtons = navButtons
    ui.pages = pages

    local function SelectTab(idx)
        currentTabIdx = idx or 1
        for i = 1, #navButtons do
            if i == currentTabIdx then
                pages[i]:Show()
                navButtons[i]:SetSelected(true)
            else
                pages[i]:Hide()
                navButtons[i]:SetSelected(false)
            end
        end
        if controlFrame.RefreshUI then
            controlFrame:RefreshUI()
        end
    end
    controlFrame.SelectTab = SelectTab

    for i, def in ipairs(navDefs) do
        local yPos = -14 - (i - 1) * 36
        local btn = CreateElvButton(sidebar, 184, 30, L(def.en, def.ru))
        btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, yPos)
        btn.fs:ClearAllPoints()
        btn.fs:SetPoint("LEFT", btn, "LEFT", 12, 0)
        btn.fs:SetJustifyH("LEFT")
        btn.def = def
        btn:SetScript("OnClick", function() SelectTab(i) end)
        navButtons[i] = btn

        local page = CreateFrame("Frame", nil, controlFrame)
        page:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", 220, -64)
        page:SetPoint("BOTTOMRIGHT", controlFrame, "BOTTOMRIGHT", -16, 16)
        page:Hide()
        pages[i] = page
    end

    -- Sidebar Footer Tip
    local sideDiv = sidebar:CreateTexture(nil, "ARTWORK")
    sideDiv:SetHeight(1)
    sideDiv:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 12, 82)
    sideDiv:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -12, 82)
    sideDiv:SetColorTexture(0.22, 0.22, 0.30, 1)

    local sideTip = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ApplyFont(sideTip, 11)
    sideTip:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 12, 14)
    sideTip:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -12, 14)
    sideTip:SetJustifyH("LEFT")
    sideTip:SetTextColor(0.68, 0.72, 0.80, 1)
    ui.sideTip = sideTip

    local function RegisterGroupBox(parent, titleEN, titleRU, x, y, w, h)
        local c, b = CreateElvGroupBox(parent, titleEN, titleRU, x, y, w, h)
        ui.groupBoxes[#ui.groupBoxes + 1] = c
        return b
    end

    local function CreateElvCheck(parent, labelEN, labelRU, dbKey, x, y, isMasterEnable, customColor)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(560, 24)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

        local box = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        box:SetSize(18, 18)
        box:SetPoint("LEFT", btn, "LEFT", 0, 0)
        SetBackdropFlat(box, 0.04, 0.04, 0.06, 1.0, 0.32, 0.32, 0.42, 1.0)

        local fill = box:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
        fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
        if customColor then
            fill:SetColorTexture(customColor[1], customColor[2], customColor[3], 1.0)
        elseif isMasterEnable then
            fill:SetColorTexture(0.18, 0.86, 0.32, 1.0)
        else
            fill:SetColorTexture(0.24, 0.58, 0.96, 1.0)
        end
        btn.fill = fill

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ApplyFont(txt, isMasterEnable and 13 or 12)
        txt:SetPoint("LEFT", box, "RIGHT", 8, 0)
        txt:SetJustifyH("LEFT")
        btn.txt = txt

        btn.labelEN = labelEN
        btn.labelRU = labelRU
        btn.dbKey   = dbKey
        btn.isMasterEnable = isMasterEnable

        function btn:UpdateVisual(checked)
            self._checked = checked and true or false
            self.txt:SetText(L(self.labelEN, self.labelRU))
            if self._checked then
                self.fill:Show()
                if self.isMasterEnable then
                    self.txt:SetTextColor(0.22, 0.95, 0.38, 1)
                else
                    self.txt:SetTextColor(0.94, 0.94, 0.98, 1)
                end
            else
                self.fill:Hide()
                if self.isMasterEnable then
                    self.txt:SetTextColor(0.95, 0.32, 0.32, 1)
                else
                    self.txt:SetTextColor(0.62, 0.62, 0.70, 1)
                end
            end
        end

        btn:SetScript("OnClick", function(self)
            local newVal = not self._checked
            MAWM_DB[self.dbKey] = newVal
            if self.dbKey == "showLore" and newVal then
                MAWM_DB.layout = "mawm"
            end
            self:UpdateVisual(newVal)
            MAWM:RefreshMap()
            controlFrame:RefreshUI()
        end)

        ui.checks[#ui.checks + 1] = btn
        return btn
    end

    local function CreateScaleSlider(parent, contKey, nameEN, nameRU, minV, maxV, stepV, x, y, width, isRouteAlpha)
        local sWidth = width or 270
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetSize(sWidth, 56)
        holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

        local title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ApplyFont(title, 12)
        title:SetPoint("TOP", holder, "TOP", 0, 0)
        title:SetTextColor(1.0, 0.82, 0.18, 1)
        holder.title = title
        holder.nameEN = nameEN
        holder.nameRU = nameRU
        holder.contKey = contKey
        holder.isRouteAlpha = isRouteAlpha

        local slider = CreateFrame("Slider", nil, holder, "BackdropTemplate")
        slider:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -18)
        slider:SetSize(sWidth, 12)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(minV, maxV)
        slider:SetValueStep(stepV)
        slider:SetObeyStepOnDrag(true)
        SetBackdropFlat(slider, 0.04, 0.04, 0.06, 1.0, 0.26, 0.26, 0.34, 1.0)

        local fillBar = slider:CreateTexture(nil, "ARTWORK")
        fillBar:SetPoint("TOPLEFT", slider, "TOPLEFT", 1, -1)
        fillBar:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 1, 1)
        fillBar:SetWidth(1)
        fillBar:SetColorTexture(0.20, 0.48, 0.82, 0.85)
        slider.fillBar = fillBar

        local thumb = slider:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(10, 16)
        thumb:SetColorTexture(0.45, 0.78, 1.0, 1.0)
        slider:SetThumbTexture(thumb)

        local minTxt = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ApplyFont(minTxt, 10)
        minTxt:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -4)
        minTxt:SetTextColor(0.65, 0.65, 0.72, 1)
        minTxt:SetText(string.format("%.2fx", minV))

        local maxTxt = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ApplyFont(maxTxt, 10)
        maxTxt:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -4)
        maxTxt:SetTextColor(0.65, 0.65, 0.72, 1)
        maxTxt:SetText(string.format("%.2fx", maxV))

        local valBox = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        valBox:SetSize(68, 18)
        valBox:SetPoint("TOP", slider, "BOTTOM", 0, -2)
        SetBackdropFlat(valBox, 0.04, 0.04, 0.06, 1.0, 0.24, 0.24, 0.32, 1.0)

        local valTxt = valBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ApplyFont(valTxt, 11)
        valTxt:SetPoint("CENTER", valBox, "CENTER", 0, 0)
        valTxt:SetTextColor(0.95, 0.95, 1.0, 1)
        holder.valTxt = valTxt

        local function UpdateFill(v)
            local pct = (v - minV) / math.max(0.0001, (maxV - minV))
            pct = math.max(0, math.min(1, pct))
            fillBar:SetWidth(math.max(1, (sWidth - 2) * pct))
        end

        slider:SetScript("OnValueChanged", function(_, val)
            local rounded = math.floor((val / stepV) + 0.5) * stepV
            valTxt:SetText(isRouteAlpha and string.format("%d%%", math.floor(rounded * 100 + 0.5)) or string.format("%.2fx", rounded))
            UpdateFill(rounded)
            if isRefreshingUI then return end
            if isRouteAlpha then
                MAWM_DB.routeAlpha = rounded
            else
                MAWM_DB.scales = MAWM_DB.scales or {}
                MAWM_DB.scales[contKey] = rounded
                if MAWM.RebuildLayoutBoxes then MAWM:RebuildLayoutBoxes() end
            end
            MAWM:RefreshMap()
        end)

        holder.slider = slider
        holder.UpdateFill = UpdateFill
        ui.scaleSliders[#ui.scaleSliders + 1] = holder
        return holder
    end

    -----------------------------------------------------------------------------------
    -- TAB 1: MAP & LAYOUT
    -----------------------------------------------------------------------------------
    do
        local p1 = pages[1]
        local bGen = RegisterGroupBox(p1, "General Map Settings", "Основные параметры карты", 0, 0, 596, 152)
        CreateElvCheck(bGen, "Enable Realigned Azeroth World Map (MAWM)", "Включить обновлённую карту Азерота (MAWM)", "enabled", 14, -12, true)
        CreateElvCheck(bGen, "Show Continent & Ocean Name Labels", "Показывать подписи континентов и океанов", "showLabels", 14, -38, false)
        CreateElvCheck(bGen, "Show Intercontinental Ship & Zeppelin Routes", "Показывать маршруты кораблей и дирижаблей", "showRoutes", 14, -64, false)
        CreateElvCheck(bGen, "Show Lore Geodesy Pins (#1-#8) & Daelin Proudmoore's Fleet Route", "Показывать лор-пины геодезии (№1-№8) и маршрут флота Праудмура", "showLore", 14, -90, false)
        CreateElvCheck(bGen, "Show Bottom-Left Version & Mode Status Line", "Показывать строку статуса и версии в левом нижнем углу", "showBadge", 14, -116, false)

        local bLay = RegisterGroupBox(p1, "Geodesy Layout Mode (3 Selectable Modes)", "Режим геодезической раскладки (3 варианта)", 0, -162, 596, 140)
        local laySpecs = {
            {
                key = "mawm",
                en  = "1. MAWM Full Geodesy — Khaz Algar North • Dragon Isles SE • Zandalar SW • Broken Isles NW",
                ru  = "1. Полная геодезия MAWM — Каз Алгар С • Драконьи о-ва ЮВ • Зандалар ЮЗ • Расколотые СЗ",
            },
            {
                key = "hybrid",
                en  = "2. Hybrid Mode — Broken Isles & Zandalar Lore-Shifted • Khaz Algar & Dragon Isles at Stock Spots",
                ru  = "2. Гибрид — Расколотые и Зандалар сдвинуты по лору • Каз Алгар и Драконьи как у Близзард",
            },
            {
                key = "blizz",
                en  = "3. Blizzard Positions — All 10 Continents at Blizzard Spots with Restored 4K Art & Proportions",
                ru  = "3. Раскладка Близзард — Все 10 континентов на местах Близзард с нашей 4K-графикой и масштабом",
            },
        }
        for idx, spec in ipairs(laySpecs) do
            local btn = CreateElvButton(bLay, 568, 30, "")
            btn:SetPoint("TOPLEFT", bLay, "TOPLEFT", 14, -10 - (idx - 1) * 35)
            btn.fs:ClearAllPoints()
            btn.fs:SetPoint("LEFT", btn, "LEFT", 14, 0)
            btn.fs:SetJustifyH("LEFT")
            btn.spec = spec
            btn:SetScript("OnClick", function()
                MAWM_DB.layout = spec.key
                MAWM_DB.enabled = true
                MAWM:RefreshMap()
                controlFrame:RefreshUI()
            end)
            ui.layoutBtns[#ui.layoutBtns + 1] = btn
        end

        local bStyle = RegisterGroupBox(p1, "Ocean Backdrop Style & Map Typography Language", "Стиль океанской подложки и язык подписей на карте", 0, -312, 596, 156)
        local styleSpecs = {
            { key = "blizz", en = "4K Coastal Sea Chart (Default)", ru = "4K Морская лазурь (По умолчанию)" },
            { key = "carto", en = "Cartographer's Warm Parchment",  ru = "Тёплый пергамент Картографа" },
        }
        for idx, spec in ipairs(styleSpecs) do
            local btn = CreateElvButton(bStyle, 278, 28, "")
            btn:SetPoint("TOPLEFT", bStyle, "TOPLEFT", 14 + (idx - 1) * 290, -12)
            btn.spec = spec
            btn:SetScript("OnClick", function()
                MAWM_DB.style = spec.key
                MAWM_DB.enabled = true
                MAWM:RefreshMap()
                controlFrame:RefreshUI()
            end)
            ui.styleBtns[#ui.styleBtns + 1] = btn
        end

        local langTitle = bStyle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        ApplyFont(langTitle, 12)
        langTitle:SetPoint("TOPLEFT", bStyle, "TOPLEFT", 14, -52)
        langTitle:SetTextColor(0.85, 0.85, 0.92, 1)
        ui.langTitle = langTitle

        local langList = {
            { key = "auto", label = "Auto" },
            { key = "en",   label = "EN" },
            { key = "ru",   label = "RU" },
            { key = "de",   label = "DE" },
            { key = "fr",   label = "FR" },
            { key = "es",   label = "ES" },
            { key = "it",   label = "IT" },
            { key = "pt",   label = "PT" },
            { key = "ko",   label = "KO" },
            { key = "zhcn", label = "ZH-CN" },
            { key = "zhtw", label = "ZH-TW" },
        }
        for idx, lSpec in ipairs(langList) do
            local col = (idx - 1) % 6
            local row = math.floor((idx - 1) / 6)
            local btn = CreateElvButton(bStyle, 88, 26, lSpec.label)
            btn:SetPoint("TOPLEFT", bStyle, "TOPLEFT", 14 + col * 95, -74 - row * 32)
            btn.lSpec = lSpec
            btn:SetScript("OnClick", function()
                MAWM_DB.lang = lSpec.key
                MAWM_DB.enabled = true
                MAWM:RefreshMap()
                controlFrame:RefreshUI()
            end)
            ui.langBtns[#ui.langBtns + 1] = btn
        end
    end

    -----------------------------------------------------------------------------------
    -- TAB 2: CONTINENT SCALES (10 LIVE SLIDERS)
    -----------------------------------------------------------------------------------
    do
        local p2 = pages[2]
        local bScales = RegisterGroupBox(p2, "Individual Continent Scale Multipliers (0.60x - 2.40x)", "Индивидуальные мультипликаторы размеров материков (0.60x - 2.40x)", 0, 0, 596, 468)

        local sliderDefs = {
            { key = "Kalimdor",        en = "Kalimdor (Default: 1.30x)",         ru = "Калимдор (Стандарт: 1.30x)" },
            { key = "EasternKingdoms", en = "Eastern Kingdoms (Default: 1.20x)", ru = "Восточные королевства (1.20x)" },
            { key = "Northrend",       en = "Northrend (Default: 1.40x)",        ru = "Нордскол (Стандарт: 1.40x)" },
            { key = "Pandaria",        en = "Pandaria (Default: 1.50x)",         ru = "Пандария (Стандарт: 1.50x)" },
            { key = "DragonIsles",     en = "Dragon Isles (Default: 1.40x)",     ru = "Драконьи острова (1.40x)" },
            { key = "BrokenIsles",     en = "Broken Isles (Default: 1.50x)",     ru = "Расколотые острова (1.50x)" },
            { key = "Zandalar",        en = "Zandalar (Default: 1.50x)",         ru = "Зандалар (Стандарт: 1.50x)" },
            { key = "KulTiras",        en = "Kul Tiras (Default: 1.55x)",        ru = "Кул-Тирас (Стандарт: 1.55x)" },
            { key = "KhazAlgar",       en = "Khaz Algar / Dorn (Default: 1.60x)",ru = "Каз Алгар / Дорн (1.60x)" },
            { key = "Maelstrom",       en = "The Maelstrom (Default: 1.50x)",    ru = "Водоворот + Кезан (1.50x)" },
        }

        for idx, sDef in ipairs(sliderDefs) do
            local col = (idx - 1) % 2
            local row = math.floor((idx - 1) / 2)
            CreateScaleSlider(bScales, sDef.key, sDef.en, sDef.ru, 0.60, 2.40, 0.05, 18 + col * 290, -16 - row * 72, 268, false)
        end

        local resetScalesBtn = CreateElvButton(bScales, 280, 30, "")
        resetScalesBtn:SetPoint("BOTTOM", bScales, "BOTTOM", 0, 14)
        resetScalesBtn:SetScript("OnClick", function()
            MAWM_DB.scales = nil
            if MAWM.RebuildLayoutBoxes then MAWM:RebuildLayoutBoxes() end
            MAWM:RefreshMap()
            controlFrame:RefreshUI()
        end)
        ui.resetScalesBtn = resetScalesBtn
    end

    -----------------------------------------------------------------------------------
    -- TAB 3: SHIPS & ZEPPELINS TRANSIT ROUTES
    -----------------------------------------------------------------------------------
    do
        local p3 = pages[3]
        local bRouteCfg = RegisterGroupBox(p3, "Intercontinental Ship & Zeppelin Routes (Layout-Adaptive!)", "Межконтинентальные маршруты кораблей и дирижаблей", 0, 0, 596, 168)

        CreateElvCheck(bRouteCfg, "Show Dashed Transit Routes & Harbor Nodes on Azeroth Map", "Показывать пунктирные маршруты и порты на карте Азерота", "showRoutes", 14, -12, true)
        CreateElvCheck(bRouteCfg, "|cff4499ffAlliance Routes (Blue):|r Ships from Stormwind to Boralus, Northrend & Dragon Isles", "|cff4499ffМаршруты Альянса (Синий пунктир):|r Корабли из Штормграда в Боралус, Нордскол и Драконьи о-ва", "showRoutesAlliance", 14, -40, false, { 0.22, 0.62, 1.00 })
        CreateElvCheck(bRouteCfg, "|cffff3b30Horde Routes (Red):|r Zeppelins & Ships from Orgrimmar / Echo Isles", "|cffff3b30Маршруты Орды (Красный пунктир):|r Дирижабли и корабли из Оргриммара и Островов Эха", "showRoutesHorde", 14, -66, false, { 0.96, 0.22, 0.20 })
        CreateElvCheck(bRouteCfg, "|cffe8d282Neutral Routes (Black):|r Ratchet (Barrens) <-> Booty Bay (Stranglethorn)", "|cffe8d282Нейтральные маршруты (Чёрный пунктир):|r Кабестан (Степи) <-> Пиратская Бухта", "showRoutesNeutral", 14, -92, false, { 0.88, 0.78, 0.42 })

        CreateScaleSlider(bRouteCfg, "routeAlpha", "Route Line Opacity", "Яркость линий маршрутов", 0.30, 1.00, 0.05, 310, -88, 260, true)

        local bRouteList = RegisterGroupBox(p3, "Active Route Directory (Hover any line or dock on the map for full tooltip!)", "Справочник маршрутов (Наведи мышку на линию или порт на карте для тултипа!)", 0, -178, 596, 290)

        if MAWM.TRANSIT_ROUTES then
            for idx, r in ipairs(MAWM.TRANSIT_ROUTES) do
                local rowTxt = bRouteList:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                ApplyFont(rowTxt, 11)
                rowTxt:SetPoint("TOPLEFT", bRouteList, "TOPLEFT", 14, -12 - (idx - 1) * 27)
                rowTxt:SetPoint("RIGHT", bRouteList, "RIGHT", -14, 0)
                rowTxt:SetJustifyH("LEFT")
                rowTxt:SetWordWrap(false)
                rowTxt.route = r
                ui.routeRows[#ui.routeRows + 1] = rowTxt
            end
        end
    end

    -----------------------------------------------------------------------------------
    -- REFRESH UI STATE
    -----------------------------------------------------------------------------------
    function controlFrame:RefreshUI()
        if not MAWM_DB then return end
        isRefreshingUI = true

        ui.subTitle:SetText(L(
            "Cartography, Continent Proportions & Live Ship/Zeppelin Routes",
            "Картография, пропорции материков и маршруты кораблей/дирижаблей"
        ))
        ui.langTopBtn:SetText(L("Lang: EN", "Язык: RU"))
        ui.openMapBtn:SetText(L("Open Azeroth Map", "Открыть Азерот"))
        ui.sideTip:SetText(L(
            "|cffffd100Tip:|r Drag this window aside to watch the map update live as you move sliders!",
            "|cffffd100Совет:|r Отодвинь окошко в сторону, чтобы видеть живую карту во время настройки ползунков!"
        ))

        for _, btn in ipairs(ui.navButtons) do
            btn:SetText(L(btn.def.en, btn.def.ru))
        end

        for _, gb in ipairs(ui.groupBoxes) do
            gb.header:SetText(L(gb.titleEN, gb.titleRU))
        end

        for _, ck in ipairs(ui.checks) do
            local val = MAWM_DB[ck.dbKey]
            if val == nil and MAWM.DEFAULTS then
                val = MAWM.DEFAULTS[ck.dbKey]
            end
            ck:UpdateVisual(val)
        end

        local curLay = MAWM.GetActiveLayoutKey()
        for _, btn in ipairs(ui.layoutBtns) do
            btn:SetText(L(btn.spec.en, btn.spec.ru))
            btn:SetSelected(curLay == btn.spec.key)
        end

        local curStyle = MAWM_DB.style or "blizz"
        for _, btn in ipairs(ui.styleBtns) do
            btn:SetText(L(btn.spec.en, btn.spec.ru))
            btn:SetSelected(curStyle == btn.spec.key)
        end

        ui.langTitle:SetText(L("Select Map Labels Language:", "Выберите язык подписей на карте:"))
        local curLangSetting = MAWM_DB.lang or "auto"
        for _, btn in ipairs(ui.langBtns) do
            if btn.lSpec.key == "auto" then
                btn:SetText(L("Auto", "Авто"))
            end
            btn:SetSelected(curLangSetting == btn.lSpec.key)
        end

        for _, sl in ipairs(ui.scaleSliders) do
            sl.title:SetText(L(sl.nameEN, sl.nameRU))
            local v
            if sl.isRouteAlpha then
                v = MAWM_DB.routeAlpha or 0.92
            else
                v = (MAWM_DB.scales and MAWM_DB.scales[sl.contKey])
                    or (MAWM.CONTINENT_SCALES and MAWM.CONTINENT_SCALES[sl.contKey])
                    or 1.0
            end
            sl.slider:SetValue(v)
            sl.valTxt:SetText(sl.isRouteAlpha and string.format("%d%%", math.floor(v * 100 + 0.5)) or string.format("%.2fx", v))
            sl.UpdateFill(v)
        end

        if ui.resetScalesBtn then
            ui.resetScalesBtn:SetText(L("Reset All Continent Scales to Defaults", "Сбросить все размеры к стандарту Data.lua"))
        end

        for _, rowTxt in ipairs(ui.routeRows) do
            local r = rowTxt.route
            local hex = (r.faction == "ALLIANCE" and "|cff4499ff[Alliance]|r ")
                or (r.faction == "HORDE" and "|cffff3b30[Horde]|r ")
                or "|cffe8d282[Neutral]|r "
            if MAWM.GetActiveLang() == "ru" then
                hex = (r.faction == "ALLIANCE" and "|cff4499ff[Альянс]|r ")
                    or (r.faction == "HORDE" and "|cffff3b30[Орда]|r ")
                    or "|cffe8d282[Нейтр.]|r "
            end
            rowTxt:SetText(hex .. "|cffffd100" .. L(r.titleEN, r.titleRU) .. "|r — |cffb8bcc8" .. L(r.vesselEN, r.vesselRU) .. "|r")
        end

        isRefreshingUI = false
    end

    SelectTab(1)
    return controlFrame
end

function MAWM:ToggleConfigWindow(tabIdx)
    local f = EnsureControlCenter()
    if f:IsShown() and not tabIdx then
        f:Hide()
    else
        if tabIdx then
            f.SelectTab(tabIdx)
        end
        f:RefreshUI()
        f:Show()
    end
end

function MAWM:RefreshConfigUI()
    if controlFrame and controlFrame:IsShown() and controlFrame.RefreshUI then
        controlFrame:RefreshUI()
    end
end
