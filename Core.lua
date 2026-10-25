local ADDON_NAME, MAWM = ...

local TEX_DIR = "Interface\\AddOns\\MAWM\\Textures\\"
local AZEROTH_MAP_ID = MAWM.AZEROTH_MAP_ID or 947
local COSMIC_MAP_ID  = 946

local DEFAULTS = {
    enabled  = true,
    style    = "blizz", -- "blizz" (Official 4K CASC Realigned) or "carto" (Cartographer's Parchment)
    showLore = false,   -- Toggleable Daelin's Fleet Route & Geodesy Notes overlay
    lang     = "auto",  -- "auto" (detect from WoW client GetLocale()) or explicit: en/ru/de/fr/es/it/pt/ko/zhcn/zhtw
}

-- ============================================================================
-- Helper: Automatic Client Locale Detection (All 11 Official WoW Locales)
-- ============================================================================
local CLIENT_LOCALE_TO_LANG = {
    enUS = "en",
    enGB = "en",
    ruRU = "ru",
    deDE = "de",
    frFR = "fr",
    esES = "es",
    esMX = "es",
    itIT = "it",
    ptBR = "pt",
    koKR = "ko",
    zhCN = "zhcn",
    zhTW = "zhtw",
}

local VALID_LANGS = {
    en   = { tag = "EN",    name = "English (Friz Quadrata)" },
    ru   = { tag = "RU",    name = "Русский (Friz Quadrata)" },
    de   = { tag = "DE",    name = "Deutsch (Friz Quadrata)" },
    fr   = { tag = "FR",    name = "Français (Friz Quadrata)" },
    es   = { tag = "ES",    name = "Español (Friz Quadrata)" },
    it   = { tag = "IT",    name = "Italiano (Friz Quadrata)" },
    pt   = { tag = "PT",    name = "Português (Friz Quadrata)" },
    ko   = { tag = "KO",    name = "한국어 (Malgun Gothic)" },
    zhcn = { tag = "ZH-CN", name = "简体中文 (Microsoft YaHei)" },
    zhtw = { tag = "ZH-TW", name = "繁體中文 (Microsoft JhengHei)" },
}

local function GetClientLang()
    local loc = (GetLocale and GetLocale()) or "enUS"
    return CLIENT_LOCALE_TO_LANG[loc] or "en"
end

local function GetActiveLang()
    if MAWM_DB and MAWM_DB.lang and VALID_LANGS[MAWM_DB.lang] then
        return MAWM_DB.lang
    end
    return GetClientLang()
end

local function IsRU()
    return GetActiveLang() == "ru"
end

local function L(en, ru)
    return IsRU() and ru or en
end

local function GetContinentDisplayName(cont)
    if cont and cont.uiMapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(cont.uiMapID)
        if info and info.name and info.name ~= "" then
            return info.name
        end
    end
    return L(cont.fallbackNameEN, cont.fallbackNameRU)
end

-- ============================================================================
-- Hit-Testing on Normalized [0..1] Azeroth Canvas
-- ============================================================================
local function GetHoveredLoreBadge(nx, ny)
    if not (MAWM_DB and MAWM_DB.showLore) then
        return nil
    end
    for _, badge in ipairs(MAWM.LORE_BADGES) do
        local dx = (nx - badge.x) * 1.5 -- compensate for 3:2 aspect ratio
        local dy = (ny - badge.y)
        if (dx * dx + dy * dy) <= (badge.r * badge.r * 1.35) then
            return badge
        end
    end
    return nil
end

local function GetHoveredContinent(nx, ny)
    for _, cont in ipairs(MAWM.CONTINENTS) do
        local h = cont.hit
        if nx >= h[1] and nx <= h[3] and ny >= h[2] and ny <= h[4] then
            return cont
        end
    end
    return nil
end

-- ============================================================================
-- Suppress / Restore All Stock Blizzard & Addon Pins on 947
-- ============================================================================
local function SetStockHighlightSuppressed(suppress)
    if not WorldMapFrame then
        return
    end
    if WorldMapFrame.EnumeratePinsByTemplate then
        for pin in WorldMapFrame:EnumeratePinsByTemplate("MapHighlightPinTemplate") do
            pin:SetAlpha(suppress and 0 or 1)
            if pin.HighlightTexture then
                pin.HighlightTexture:SetAlpha(suppress and 0 or 1)
            end
        end
    end
    if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        local child = WorldMapFrame.ScrollContainer.Child
        for _, frame in ipairs({ child:GetChildren() }) do
            if frame ~= MAWM.CanvasFrame then
                if suppress then
                    if frame._mawmOrigAlpha == nil then
                        frame._mawmOrigAlpha = frame:GetAlpha()
                    end
                    frame:SetAlpha(0)
                    if frame._mawmOrigLevel then
                        frame:SetFrameLevel(frame._mawmOrigLevel)
                        frame._mawmOrigLevel = nil
                    end
                else
                    if frame._mawmOrigAlpha ~= nil then
                        frame:SetAlpha(frame._mawmOrigAlpha)
                        frame._mawmOrigAlpha = nil
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- Build Canvas Overlay & 3x2 Power-of-Two Tile Grid
-- ============================================================================
function MAWM:EnsureCanvasOverlay()
    if self.CanvasFrame then
        return self.CanvasFrame
    end
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child) then
        return nil
    end

    local child = WorldMapFrame.ScrollContainer.Child
    local f = CreateFrame("Frame", "MAWM_CanvasOverlayFrame", child)
    f:SetAllPoints(child)
    f:SetFrameStrata(child:GetFrameStrata())
    -- Elevate frame level on mapID 947 so stock highlight pins and misplaced continent summary pins stay underneath
    f:SetFrameLevel(math.min(9500, child:GetFrameLevel() + 2500))
    f:EnableMouse(true)
    f:EnableMouseWheel(true)

    -- 3x2 grid of 1024x1024 lossless RLE TGA tiles (= 3072x2048, exact 3:2 aspect ratio)
    f.tiles = {}
    for row = 0, 1 do
        f.tiles[row] = {}
        for col = 0, 2 do
            local tex = f:CreateTexture(nil, "BACKGROUND", nil, 1)
            tex:SetTexCoord(0, 1, 0, 1)
            f.tiles[row][col] = tex
        end
    end

    -- Authentic Blizzard Friz Quadrata Typography Overlay (labels_ru.tga / labels_en.tga)
    -- Placed on the very top layer (OVERLAY sublevel 7) so labels always render above continents and highlights!
    local labelsTex = f:CreateTexture(nil, "OVERLAY", nil, 7)
    labelsTex:SetAllPoints(f)
    labelsTex:SetTexCoord(0, 1, 0, 1)
    f.LabelsTex = labelsTex

    -- Pixel-Locked Golden Coastline Highlight Texture (hl_<key>.tga, 1:1 bbox with continent sprite)
    local hlTex = f:CreateTexture(nil, "ARTWORK", nil, 4)
    hlTex:SetBlendMode("ADD")
    hlTex:SetTexCoord(0, 1, 0, 1)
    hlTex:Hide()
    f.HighlightTex = hlTex

    -- Toggleable Transparent Lore & Naval Fleet Route Overlay (2048x1024 TGA)
    local loreTex = f:CreateTexture(nil, "ARTWORK", nil, 6)
    loreTex:SetAllPoints(f)
    loreTex:SetTexture(TEX_DIR .. "lore_overlay")
    loreTex:Hide()
    f.LoreTex = loreTex

    -- Subtle bottom-left watermark badge on the map
    local badgeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgeText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 12)
    badgeText:SetTextColor(0.92, 0.80, 0.48, 0.85)
    f.BadgeText = badgeText

    -- Layout update when Child changes size
    function f:UpdateTileLayout()
        local w, h = self:GetWidth(), self:GetHeight()
        if not w or w <= 0 or not h or h <= 0 then
            w, h = child:GetWidth(), child:GetHeight()
        end
        if not w or w <= 0 then return end

        local tileW = w / 3.0
        local tileH = h / 2.0
        local prefix = (MAWM_DB and MAWM_DB.style == "carto") and "carto" or "blizz"

        for row = 0, 1 do
            for col = 0, 2 do
                local tex = self.tiles[row][col]
                tex:ClearAllPoints()
                tex:SetPoint("TOPLEFT", self, "TOPLEFT", col * tileW, -(row * tileH))
                tex:SetSize(tileW + 0.5, tileH + 0.5)
                tex:SetTexture(string.format("%s%s_%d_%d", TEX_DIR, prefix, row, col))
            end
        end

        local activeLang = GetActiveLang()
        local langInfo = VALID_LANGS[activeLang] or VALID_LANGS.en
        local langFile = "labels_" .. activeLang
        self.LabelsTex:SetTexture(TEX_DIR .. langFile)
        self.LabelsTex:Show()

        if MAWM_DB and MAWM_DB.showLore then
            self.LoreTex:Show()
        else
            self.LoreTex:Hide()
        end

        local styleLabel = (prefix == "carto")
            and L("Cartographer's Parchment", "Пергамент Картографа")
            or  L("Official 4K CASC Realigned", "Офиц. 4K CASC Геодезия")
        local langTag = " [" .. langInfo.tag .. "]"
        local loreSuffix = (MAWM_DB and MAWM_DB.showLore)
            and L(" • [Lore & Fleet Routes ON]", " • [Лор и Маршруты ВКЛ]")
            or ""
        self.BadgeText:SetText("|cffffd100MAWM v" .. MAWM.VERSION .. "|r — " .. styleLabel .. langTag .. loreSuffix)
    end

    f:SetScript("OnSizeChanged", function(self)
        self:UpdateTileLayout()
    end)

    -- Forward MouseWheel so zooming in/out on Azeroth works natively
    f:SetScript("OnMouseWheel", function(_, delta)
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.OnMouseWheel then
            WorldMapFrame.ScrollContainer:OnMouseWheel(delta)
        end
    end)

    -- Mouse Click & Pan forwarding
    local downX, downY = 0, 0
    f:SetScript("OnMouseDown", function(_, button)
        downX, downY = GetCursorPosition()
        if button == "LeftButton" and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.IsZoomedIn then
            if WorldMapFrame.ScrollContainer:IsZoomedIn() and WorldMapFrame.ScrollContainer.OnMouseDown then
                WorldMapFrame.ScrollContainer:OnMouseDown(button)
            end
        end
    end)

    f:SetScript("OnMouseUp", function(self, button)
        local upX, upY = GetCursorPosition()
        if button == "LeftButton" and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.OnMouseUp then
            WorldMapFrame.ScrollContainer:OnMouseUp(button)
        end
        local dx = (upX or 0) - (downX or 0)
        local dy = (upY or 0) - (downY or 0)
        local moved = math.sqrt(dx * dx + dy * dy)
        if moved > 10 then
            return -- User was panning the zoomed map
        end

        if button == "RightButton" then
            if PlaySound and SOUNDKIT then
                PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE or 845)
            end
            self.HighlightTex:Hide()
            GameTooltip:Hide()
            WorldMapFrame:SetMapID(COSMIC_MAP_ID)
            return
        end

        if button == "LeftButton" and WorldMapFrame.ScrollContainer then
            local nx, ny = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
            if nx and ny then
                local cont = GetHoveredContinent(nx, ny)
                if cont and cont.uiMapID then
                    if PlaySound and SOUNDKIT then
                        PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN or 844)
                    end
                    self.HighlightTex:Hide()
                    GameTooltip:Hide()
                    WorldMapFrame:SetMapID(cont.uiMapID)
                end
            end
        end
    end)

    -- Hover Highlight & Tooltip loop (throttled to ~40 FPS while Azeroth map is open)
    local elapsedAcc = 0
    local pulseTime = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        elapsedAcc = elapsedAcc + elapsed
        pulseTime  = pulseTime + elapsed
        if elapsedAcc < 0.025 then
            return
        end
        elapsedAcc = 0

        if not (WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == AZEROTH_MAP_ID and MAWM_DB and MAWM_DB.enabled) then
            self.HighlightTex:Hide()
            return
        end

        -- Keep stock misplaced Blizzard highlight suppressed on 947
        SetStockHighlightSuppressed(true)

        if not self:IsMouseOver() or not WorldMapFrame.ScrollContainer then
            self.HighlightTex:Hide()
            if GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
            return
        end

        local nx, ny = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        if not nx or not ny then
            self.HighlightTex:Hide()
            return
        end

        -- 1. Check if hovering a Lore Badge first (when Lore Overlay is active)
        local badge = GetHoveredLoreBadge(nx, ny)
        if badge then
            self.HighlightTex:Hide()
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 16, -12)
            GameTooltip:ClearLines()
            GameTooltip:AddLine(L(badge.titleEN, badge.titleRU), 1.0, 0.84, 0.25, true)
            GameTooltip:AddLine(L(badge.descEN, badge.descRU), 0.92, 0.90, 0.82, true)
            GameTooltip:Show()
            return
        end

        -- 2. Check if hovering a Realigned Continent (Golden Coastline Highlight ONLY, no tooltip!)
        local cont = GetHoveredContinent(nx, ny)
        if cont then
            local w, h = self:GetWidth(), self:GetHeight()
            local b = cont.box
            if w and w > 0 and h and h > 0 and b and cont.hlTex then
                self.HighlightTex:ClearAllPoints()
                self.HighlightTex:SetPoint("TOPLEFT", self, "TOPLEFT", b[1] * w, -(b[2] * h))
                self.HighlightTex:SetSize((b[3] - b[1]) * w, (b[4] - b[2]) * h)
                self.HighlightTex:SetTexture(TEX_DIR .. cont.hlTex)
                local pulse = 0.88 + 0.12 * math.sin(pulseTime * 4.0)
                self.HighlightTex:SetAlpha(pulse)
                self.HighlightTex:Show()
            else
                self.HighlightTex:Hide()
            end
            if GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        else
            self.HighlightTex:Hide()
            if GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end
    end)

    f:SetScript("OnHide", function(self)
        self.HighlightTex:Hide()
        SetStockHighlightSuppressed(false)
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)

    self.CanvasFrame = f
    return f
end

-- ============================================================================
-- Build Top-Right World Map Header Control Button
-- ============================================================================
function MAWM:EnsureToggleButton()
    if self.ToggleButton then
        return self.ToggleButton
    end
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer) then
        return nil
    end

    local btn = CreateFrame("Button", "MAWM_WorldMapToggleButton", WorldMapFrame.ScrollContainer, "BackdropTemplate")
    btn:SetSize(206, 28)
    -- Anchored at TOPRIGHT (-48, -10) so it never overlaps top-left zone widgets (e.g. DecorVendor)
    btn:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -48, -10)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 50)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    btn:SetBackdropColor(0.07, 0.05, 0.03, 0.90)
    btn:SetBackdropBorderColor(0.85, 0.68, 0.28, 0.95)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", btn, "LEFT", 6, 0)
    icon:SetTexture(TEX_DIR .. "Logo")
    btn.Icon = icon

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    label:SetJustifyH("LEFT")
    btn.Label = label

    function btn:UpdateAppearance()
        if not MAWM_DB then return end
        if not MAWM_DB.enabled then
            self:SetBackdropBorderColor(0.50, 0.50, 0.50, 0.85)
            self.Label:SetText("|cffaaaaaaMAWM: " .. L("OFF (Stock)", "ВЫКЛ (Сток)") .. "|r")
        else
            self:SetBackdropBorderColor(0.92, 0.74, 0.28, 1.0)
            local st = (MAWM_DB.style == "carto")
                and L("Parchment", "Пергамент")
                or  L("4K Blizz", "4K Близз")
            local activeLang = GetActiveLang()
            local langInfo = VALID_LANGS[activeLang] or VALID_LANGS.en
            local langBadge = " |cffffd100[" .. langInfo.tag .. "]|r"
            local loreTag = MAWM_DB.showLore and " |cff55ddff[Lore]|r" or ""
            self.Label:SetText("|cffffd100MAWM:|r |cff55ff55" .. st .. "|r" .. langBadge .. loreTag)
        end
    end

    btn:SetScript("OnClick", function(self, button)
        if not MAWM_DB then return end
        if IsAltKeyDown() then
            local clientLang = GetClientLang()
            local curLang = GetActiveLang()
            if clientLang ~= "en" then
                MAWM_DB.lang = (curLang == clientLang) and "en" or "auto"
            else
                MAWM_DB.lang = (curLang == "en") and "ru" or "auto"
            end
            if not MAWM_DB.enabled then
                MAWM_DB.enabled = true
            end
        elseif IsShiftKeyDown() or button == "MiddleButton" then
            MAWM_DB.showLore = not MAWM_DB.showLore
            if not MAWM_DB.enabled then
                MAWM_DB.enabled = true
            end
        elseif button == "RightButton" then
            MAWM_DB.style = (MAWM_DB.style == "carto") and "blizz" or "carto"
            if not MAWM_DB.enabled then
                MAWM_DB.enabled = true
            end
        else
            if WorldMapFrame:GetMapID() ~= AZEROTH_MAP_ID then
                WorldMapFrame:SetMapID(AZEROTH_MAP_ID)
                MAWM_DB.enabled = true
            else
                MAWM_DB.enabled = not MAWM_DB.enabled
            end
        end
        if PlaySound and SOUNDKIT then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        end
        MAWM:RefreshMap()
        if GameTooltip:GetOwner() == self then
            self:GetScript("OnEnter")(self)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.16, 0.12, 0.07, 0.96)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, -4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cffffd100MAWM — Most Accurate World Map|r v" .. MAWM.VERSION)
        GameTooltip:AddLine(L(
            "Lore-accurate, tectonically realigned Azeroth World Map",
            "Лорно-точная геодезическая карта мира Азерота"
        ), 0.85, 0.82, 0.72, true)
        GameTooltip:AddLine(" ")

        local statusStr = MAWM_DB.enabled
            and L("|cff55ff55ENABLED (Realigned Azeroth)|r", "|cff55ff55ВКЛЮЧЕНА (Исправленный Азерот)|r")
            or  L("|cffff6666DISABLED (Stock Blizzard Map)|r", "|cffff6666ВЫКЛЮЧЕНА (Стандартная карта)|r")
        local styleStr = (MAWM_DB.style == "carto")
            and L("Cartographer's Illustrated Parchment", "Иллюстрированный пергамент Картографа")
            or  L("Official 4K Blizzard CASC Realigned", "Официальная 4K Blizzard CASC")
        local activeLang = GetActiveLang()
        local langInfo = VALID_LANGS[activeLang] or VALID_LANGS.en
        local isAuto = (not MAWM_DB.lang or MAWM_DB.lang == "auto")
        local langStr = "|cffffd100" .. langInfo.name .. (isAuto and " (Client Auto)" or "") .. "|r"
        local loreStr = MAWM_DB.showLore
            and L("|cff55ddffON (Daelin's Fleet & #1-#8 Geodesy Pins)|r", "|cff55ddffВКЛ (Флот Праудмура и пины геодезии №1-№8)|r")
            or  L("|cff888888OFF|r", "|cff888888ВЫКЛ|r")

        GameTooltip:AddDoubleLine(L("Status:", "Статус:"), statusStr, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L("Map Style:", "Стиль карты:"), styleStr, 1, 0.82, 0, 0.9, 0.9, 0.9)
        GameTooltip:AddDoubleLine(L("Map Language:", "Язык подписей:"), langStr, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L("Lore & Fleet Overlay:", "Лор-маршруты и флот:"), loreStr, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddLine(" ")
        if WorldMapFrame:GetMapID() == AZEROTH_MAP_ID then
            GameTooltip:AddLine(L("|cff55ff55Left-Click:|r Toggle Realigned vs Stock Map", "|cff55ff55ЛКМ:|r Переключить исправленную / стандартную карту"), 0.9, 0.9, 0.9)
        else
            GameTooltip:AddLine(L("|cff55ff55Left-Click:|r Jump to Azeroth World Map", "|cff55ff55ЛКМ:|r Открыть глобальную карту Азерота"), 0.9, 0.9, 0.9)
        end
        GameTooltip:AddLine(L("|cff55ff55Right-Click:|r Switch Style (4K Blizz / Parchment)", "|cff55ff55ПКМ:|r Сменить стиль (4K Близз / Пергамент)"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(L("|cff55ff55Alt-Click:|r Toggle Client Language / EN", "|cff55ff55Alt+Клик:|r Сменить язык карты (Клиент / EN)"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(L("|cff55ff55Shift-Click / Middle-Click:|r Toggle Lore & Naval Routes", "|cff55ff55Shift+Клик / СКМ:|r Вкл/выкл маршрут флота и лор-заметки"), 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.07, 0.05, 0.03, 0.90)
        GameTooltip:Hide()
    end)

    self.ToggleButton = btn
    return btn
end

-- ============================================================================
-- Refresh State on Map Change / Show / Toggle
-- ============================================================================
function MAWM:RefreshMap()
    if not WorldMapFrame then return end

    local btn = self:EnsureToggleButton()
    if btn then
        btn:UpdateAppearance()
        btn:Show()
    end

    local canvas = self:EnsureCanvasOverlay()
    if not canvas then return end

    local mapID = WorldMapFrame:GetMapID()
    if mapID == AZEROTH_MAP_ID and MAWM_DB and MAWM_DB.enabled then
        canvas:UpdateTileLayout()
        canvas:Show()
        SetStockHighlightSuppressed(true)
    else
        canvas:Hide()
        SetStockHighlightSuppressed(false)
    end
end

-- ============================================================================
-- Initialization & Slash Commands (/mawm, /meow)
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if type(MAWM_DB) ~= "table" then
            MAWM_DB = {}
        end
        for k, v in pairs(DEFAULTS) do
            if MAWM_DB[k] == nil then
                MAWM_DB[k] = v
            end
        end
    elseif event == "PLAYER_LOGIN" then
        if WorldMapFrame then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
                MAWM:RefreshMap()
            end)
            WorldMapFrame:HookScript("OnShow", function()
                MAWM:RefreshMap()
            end)
            MAWM:RefreshMap()
        end
    end
end)

SLASH_MAWM1 = "/mawm"
SLASH_MAWM2 = "/meow"
SlashCmdList["MAWM"] = function(msg)
    local cmd = string.lower(strtrim(msg or ""))
    if cmd == "style" or cmd == "theme" then
        MAWM_DB.style = (MAWM_DB.style == "carto") and "blizz" or "carto"
        MAWM_DB.enabled = true
        print(string.format("|cffffd100[MAWM]|r %s: |cff55ff55%s|r",
            L("Map style switched to", "Стиль карты переключён на"),
            (MAWM_DB.style == "carto") and L("Cartographer's Parchment", "Пергамент Картографа") or L("Official 4K Blizzard CASC", "Официальная 4K Blizzard CASC")))
    elseif cmd == "lang" or cmd == "auto" or VALID_LANGS[cmd] or cmd:match("^lang%s+") then
        local argLang = cmd:match("^lang%s+(%S+)") or cmd
        if argLang == "auto" then
            MAWM_DB.lang = "auto"
        elseif VALID_LANGS[argLang] then
            MAWM_DB.lang = argLang
        else
            local clientLang = GetClientLang()
            local curLang = GetActiveLang()
            if clientLang ~= "en" then
                MAWM_DB.lang = (curLang == clientLang) and "en" or "auto"
            else
                MAWM_DB.lang = (curLang == "en") and "ru" or "auto"
            end
        end
        MAWM_DB.enabled = true
        local active = GetActiveLang()
        local info = VALID_LANGS[active] or VALID_LANGS.en
        print(string.format("|cffffd100[MAWM]|r %s: |cff55ff55%s [%s]|r",
            L("Map language switched to", "Язык карты переключён на"),
            info.name, info.tag))
    elseif cmd == "lore" or cmd == "route" or cmd == "fleet" then
        MAWM_DB.showLore = not MAWM_DB.showLore
        MAWM_DB.enabled = true
        print(string.format("|cffffd100[MAWM]|r %s: %s",
            L("Lore & Naval Fleet Overlay", "Лор-оверлей и маршрут флота"),
            MAWM_DB.showLore and "|cff55ff55ON|r" or "|cffff6666OFF|r"))
    elseif cmd == "open" or cmd == "map" then
        if not WorldMapFrame:IsShown() then
            ToggleWorldMap()
        end
        WorldMapFrame:SetMapID(AZEROTH_MAP_ID)
        MAWM_DB.enabled = true
    elseif cmd == "help" then
        print("|cffffd100[MAWM — Most Accurate World Map]|r " .. L("Commands:", "Команды:"))
        print("  |cff55ff55/mawm|r (or |cff55ff55/meow|r) — " .. L("Toggle Realigned Map ON/OFF", "Вкл/выкл исправленную карту Азерота"))
        print("  |cff55ff55/mawm style|r — " .. L("Switch between Official 4K Blizzard & Cartographer's Parchment", "Сменить стиль (4K Близз / Пергамент)"))
        print("  |cff55ff55/mawm lang|r [auto|en|ru|de|fr|es|it|pt|ko|zhcn|zhtw] — " .. L("Switch map labels language (auto-detected from client by default)", "Переключить язык подписей на карте (по умолчанию определяется по клиенту)"))
        print("  |cff55ff55/mawm lore|r — " .. L("Toggle Daelin Proudmoore's Fleet Route & Geodesy Notes", "Вкл/выкл маршрут флота Праудмура и заметки геодезии"))
        print("  |cff55ff55/mawm open|r — " .. L("Open World Map directly to Azeroth (947)", "Открыть карту мира сразу на Азероте"))
        return
    else
        MAWM_DB.enabled = not MAWM_DB.enabled
        print(string.format("|cffffd100[MAWM]|r %s: %s |cffaaaaaa(/mawm help)|r",
            L("Most Accurate World Map", "Точная карта мира Азерота"),
            MAWM_DB.enabled and "|cff55ff55ENABLED (Meow!)|r" or "|cffff6666DISABLED (Stock)|r"))
    end
    MAWM:RefreshMap()
end
