local ADDON_NAME, MAWM = ...

local TEX_DIR = "Interface\\AddOns\\MAWM\\Textures\\"
local AZEROTH_MAP_ID = MAWM.AZEROTH_MAP_ID or 947
local COSMIC_MAP_ID  = 946

local DEFAULTS = {
    enabled            = true,
    layout             = "mawm",  -- "mawm" (Full Geodesy), "hybrid" (BI+Zandalar shifted, KA+DI stock), or "blizz" (Blizzard spots + True Proportions)
    style              = "blizz", -- "blizz" (Official 4K CASC Realigned) or "carto" (Cartographer's Parchment)
    showLore           = false,   -- Toggleable Daelin's Fleet Route & Geodesy Notes overlay
    showLabels         = true,    -- Show continent & sea typography labels
    showBadge          = true,    -- Show bottom-left version/mode watermark
    showRoutes         = false,   -- Toggleable Ships & Zeppelins dashed transit routes
    showRoutesAlliance = true,    -- Blue Alliance ship routes
    showRoutesHorde    = true,    -- Red Horde zeppelin & ship routes
    showRoutesNeutral  = true,    -- Black Neutral ship routes (Ratchet <-> Booty Bay)
    routeAlpha         = 0.92,    -- Opacity of transit routes (0.30 .. 1.00)
    lang               = "auto",  -- "auto" (detect from WoW client GetLocale()) or explicit: en/ru/de/fr/es/it/pt/ko/zhcn/zhtw
}
MAWM.DEFAULTS = DEFAULTS

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
MAWM.VALID_LANGS = VALID_LANGS

local function GetClientLang()
    local loc = (GetLocale and GetLocale()) or "enUS"
    return CLIENT_LOCALE_TO_LANG[loc] or "en"
end
MAWM.GetClientLang = GetClientLang

local function GetActiveLang()
    if MAWM_DB and MAWM_DB.lang and VALID_LANGS[MAWM_DB.lang] then
        return MAWM_DB.lang
    end
    return GetClientLang()
end
MAWM.GetActiveLang = GetActiveLang

local function GetActiveLayoutKey()
    local k = MAWM_DB and MAWM_DB.layout or "mawm"
    if MAWM.LAYOUTS and MAWM.LAYOUTS[k] then
        return k
    end
    return "mawm"
end
MAWM.GetActiveLayoutKey = GetActiveLayoutKey

local function GetActiveLayout()
    local k = GetActiveLayoutKey()
    return MAWM.LAYOUTS[k], k
end
MAWM.GetActiveLayout = GetActiveLayout

local function CycleLayoutMode()
    local cur = GetActiveLayoutKey()
    local order = MAWM.LAYOUT_ORDER or { "mawm", "hybrid", "blizz" }
    for i, k in ipairs(order) do
        if k == cur then
            local nextIdx = (i % #order) + 1
            MAWM_DB.layout = order[nextIdx]
            return MAWM_DB.layout
        end
    end
    MAWM_DB.layout = "mawm"
    return MAWM_DB.layout
end
MAWM.CycleLayoutMode = CycleLayoutMode

local function IsRU()
    return GetActiveLang() == "ru" or GetClientLang() == "ru"
end
MAWM.IsRU = IsRU

local function L(en, ru)
    return (GetActiveLang() == "ru") and ru or en
end
MAWM.L = L

-- ============================================================================
-- Dynamic Port Coordinates & Transit Route Curve Helpers
-- ============================================================================
local function GetContinentBoxByKey(contKey)
    local layout = GetActiveLayout()
    if layout and layout.continents and layout.continents[contKey] and layout.continents[contKey].box then
        return layout.continents[contKey].box
    end
    if MAWM.CONTINENTS then
        for _, c in ipairs(MAWM.CONTINENTS) do
            if c.key == contKey then
                return c.box
            end
        end
    end
    return nil
end

function MAWM:GetPortNormalizedPos(portKey)
    local port = self.PORTS and self.PORTS[portKey]
    if not port then return nil, nil end
    local b = GetContinentBoxByKey(port.cont)
    if not b then return nil, nil end
    local nx = b[1] + port.u * (b[3] - b[1])
    local ny = b[2] + port.v * (b[4] - b[2])
    return nx, ny
end

local function IsRouteEnabled(route)
    if not (MAWM_DB and MAWM_DB.showRoutes) then
        return false
    end
    if route.faction == "ALLIANCE" then
        return MAWM_DB.showRoutesAlliance ~= false
    elseif route.faction == "HORDE" then
        return MAWM_DB.showRoutesHorde ~= false
    elseif route.faction == "NEUTRAL" then
        return MAWM_DB.showRoutesNeutral ~= false
    end
    return true
end
MAWM.IsRouteEnabled = IsRouteEnabled

local function GetRouteBezierPointsNormalized(route)
    local nx1, ny1 = MAWM:GetPortNormalizedPos(route.from)
    local nx2, ny2 = MAWM:GetPortNormalizedPos(route.to)
    if not (nx1 and ny1 and nx2 and ny2) then return nil end

    local mx = (nx1 + nx2) * 0.5
    local my = (ny1 + ny2) * 0.5
    local dx = nx2 - nx1
    local dy = ny2 - ny1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.001 then return nil end

    -- Perpendicular unit vector (adjusted slightly for 3:2 aspect ratio)
    local px = -dy / dist
    local py = dx / dist
    local curve = route.curve or 0.05
    local cx = mx + px * curve * dist
    local cy = my + py * curve * dist * 1.35

    return nx1, ny1, cx, cy, nx2, ny2
end

local function EvalQuadraticBezier(t, x1, y1, cx, cy, x2, y2)
    local u = 1.0 - t
    local bx = u * u * x1 + 2.0 * u * t * cx + t * t * x2
    local by = u * u * y1 + 2.0 * u * t * cy + t * t * y2
    local tx = 2.0 * u * (cx - x1) + 2.0 * t * (x2 - cx)
    local ty = 2.0 * u * (cy - y1) + 2.0 * t * (y2 - cy)
    return bx, by, tx, ty
end

-- ============================================================================
-- Hit-Testing on Normalized [0..1] Azeroth Canvas (Layout-Aware!)
-- ============================================================================
local function GetHoveredLoreBadge(nx, ny)
    if not (MAWM_DB and MAWM_DB.showLore and GetActiveLayoutKey() == "mawm") then
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

local function GetHoveredTransitRoute(nx, ny)
    if not (MAWM_DB and MAWM_DB.showRoutes and MAWM.TRANSIT_ROUTES) then
        return nil
    end
    local bestRoute = nil
    local bestDistSq = 0.011 * 0.011

    for _, route in ipairs(MAWM.TRANSIT_ROUTES) do
        if IsRouteEnabled(route) then
            local x1, y1, cx, cy, x2, y2 = GetRouteBezierPointsNormalized(route)
            if x1 then
                for i = 0, 24 do
                    local t = i / 24.0
                    local bx, by = EvalQuadraticBezier(t, x1, y1, cx, cy, x2, y2)
                    local dx = (nx - bx) * 1.5
                    local dy = (ny - by)
                    local d2 = dx * dx + dy * dy
                    -- Slightly larger hit radius right at the departure/arrival harbors
                    local thresh = (i == 0 or i == 24) and (0.014 * 0.014) or bestDistSq
                    if d2 < thresh then
                        bestDistSq = d2
                        bestRoute = route
                    end
                end
            end
        end
    end
    return bestRoute
end

local function GetContinentBoxInActiveLayout(cont)
    local layout = GetActiveLayout()
    if layout and layout.continents and layout.continents[cont.key] then
        return layout.continents[cont.key].box
    end
    return cont.box
end

local function GetHoveredContinent(nx, ny)
    for _, cont in ipairs(MAWM.CONTINENTS) do
        local b = GetContinentBoxInActiveLayout(cont)
        if b and nx >= b[1] and nx <= b[3] and ny >= b[2] and ny <= b[4] then
            return cont, b
        end
    end
    return nil, nil
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
-- Build Canvas Overlay:
--   - 3x2 Power-of-Two Ocean Background Tile Grid (BACKGROUND sublevel 1)
--   - 10 Modular Continent Sprites (ARTWORK sublevel 2)
--   - Pulsing Golden Coastline Highlight (ARTWORK sublevel 4)
--   - Dynamic Dashed Ships & Zeppelins Transit Routes (OVERLAY sublevel 5)
--   - Lore & Naval Fleet Route Overlay (ARTWORK sublevel 6)
--   - 12-Cell Localized Label Atlas Sprites (OVERLAY sublevel 7)
-- ============================================================================
local ATLAS_CELL_W_NORM = 704.0 / 3072.0
local ATLAS_CELL_H_NORM = 231.0 / 2048.0

local function SetAtlasCellTexCoord(tex, cellIdx)
    local col = cellIdx % 2
    local row = math.floor(cellIdx / 2)
    local u1 = col * 0.5
    local u2 = (col + 1) * 0.5
    local v1 = (row * 168.0) / 1024.0
    local v2 = ((row + 1) * 168.0) / 1024.0
    tex:SetTexCoord(u1, u2, v1, v2)
end

local FACTION_COLORS = {
    ALLIANCE = { r = 0.22, g = 0.62, b = 1.00, bgR = 0.02, bgG = 0.08, bgB = 0.20, hex = "|cff4499ff" },
    HORDE    = { r = 0.96, g = 0.22, b = 0.20, bgR = 0.20, bgG = 0.02, bgB = 0.02, hex = "|cffff3b30" },
    NEUTRAL  = { r = 0.08, g = 0.08, b = 0.10, bgR = 0.94, bgG = 0.84, bgB = 0.52, hex = "|cffe8d282" },
}

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
    f:SetFrameLevel(math.min(9500, child:GetFrameLevel() + 2500))
    f:EnableMouse(true)
    f:EnableMouseWheel(true)

    -- 1. 3x2 grid of 1024x1024 lossless RLE TGA ocean background tiles (= 3072x2048, exact 3:2 aspect ratio)
    f.tiles = {}
    for row = 0, 1 do
        f.tiles[row] = {}
        for col = 0, 2 do
            local tex = f:CreateTexture(nil, "BACKGROUND", nil, 1)
            tex:SetTexCoord(0, 1, 0, 1)
            f.tiles[row][col] = tex
        end
    end

    -- 2. 10 Modular Continent Sprites (positioned dynamically according to active Layout Mode & Scale!)
    f.contSprites = {}
    f.labelSprites = {}
    for _, cont in ipairs(MAWM.CONTINENTS) do
        local cTex = f:CreateTexture(nil, "ARTWORK", nil, 2)
        cTex:SetTexCoord(0, 1, 0, 1)
        f.contSprites[cont.key] = cTex

        local lTex = f:CreateTexture(nil, "OVERLAY", nil, 7)
        SetAtlasCellTexCoord(lTex, cont.atlasCell)
        f.labelSprites[cont.key] = lTex
    end

    -- Sea Labels (The Veiled Sea & The Forbidding Sea)
    f.seaLabelSprites = {}
    for i, sea in ipairs(MAWM.SEA_LABELS) do
        local sTex = f:CreateTexture(nil, "OVERLAY", nil, 7)
        SetAtlasCellTexCoord(sTex, sea.atlasCell)
        f.seaLabelSprites[i] = sTex
    end

    -- 3. Pixel-Locked Inner Golden Coastline Highlight Texture (hl_<key>.tga, 1:1 bbox with continent sprite)
    local hlTex = f:CreateTexture(nil, "ARTWORK", nil, 4)
    hlTex:SetBlendMode("ADD")
    hlTex:SetTexCoord(0, 1, 0, 1)
    hlTex:Hide()
    f.HighlightTex = hlTex

    -- 4. Toggleable Transparent Lore & Naval Fleet Route Overlay (2048x1024 TGA)
    local loreTex = f:CreateTexture(nil, "ARTWORK", nil, 6)
    loreTex:SetAllPoints(f)
    loreTex:SetTexture(TEX_DIR .. "lore_overlay")
    loreTex:Hide()
    f.LoreTex = loreTex

    -- 5. Dynamic Pool for Dashed Ships & Zeppelins Transit Routes (OVERLAY sublevel 4 & 5)
    f.routeDashPool = {}
    f.routeNodePool = {}

    local function AcquireDashPair(idx)
        local pair = f.routeDashPool[idx]
        if not pair then
            local bg = f:CreateTexture(nil, "OVERLAY", nil, 4)
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            local fg = f:CreateTexture(nil, "OVERLAY", nil, 5)
            fg:SetTexture("Interface\\Buttons\\WHITE8X8")
            pair = { bg = bg, fg = fg }
            f.routeDashPool[idx] = pair
        end
        return pair
    end

    local function AcquirePortNode(idx)
        local node = f.routeNodePool[idx]
        if not node then
            local bg = f:CreateTexture(nil, "OVERLAY", nil, 5)
            bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            local fg = f:CreateTexture(nil, "OVERLAY", nil, 6)
            fg:SetTexture("Interface\\Buttons\\WHITE8X8")
            node = { bg = bg, fg = fg }
            f.routeNodePool[idx] = node
        end
        return node
    end

    function f:UpdateTransitRoutes(hoveredRouteId)
        local w, h = self:GetWidth(), self:GetHeight()
        if not w or w <= 0 or not h or h <= 0 then
            w, h = child:GetWidth(), child:GetHeight()
        end
        if not w or w <= 0 then return end

        local dashIdx = 0
        local nodeIdx = 0

        if MAWM_DB and MAWM_DB.showRoutes and MAWM.TRANSIT_ROUTES then
            local baseAlpha = MAWM_DB.routeAlpha or 0.92
            local drawnPorts = {}

            for _, route in ipairs(MAWM.TRANSIT_ROUTES) do
                if IsRouteEnabled(route) then
                    local nx1, ny1, ncx, ncy, nx2, ny2 = GetRouteBezierPointsNormalized(route)
                    if nx1 then
                        local x1, y1 = nx1 * w, ny1 * h
                        local cx, cy = ncx * w, ncy * h
                        local x2, y2 = nx2 * w, ny2 * h

                        local isHovered = (hoveredRouteId == route.id)
                        local col = FACTION_COLORS[route.faction] or FACTION_COLORS.NEUTRAL
                        local alpha = isHovered and 1.0 or baseAlpha

                        local chord = math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
                        local numDashes = math.max(10, math.min(48, math.floor(chord / 15.0)))
                        local dashLen = math.max(5.5, math.min(11.0, (chord / numDashes) * 0.56))
                        local dashThick = isHovered and 4.2 or 2.8

                        for i = 1, numDashes - 1 do
                            local t = i / numDashes
                            local bx, by, tx, ty = EvalQuadraticBezier(t, x1, y1, cx, cy, x2, y2)
                            local ang = math.atan2(-ty, tx)

                            dashIdx = dashIdx + 1
                            local pair = AcquireDashPair(dashIdx)
                            pair.bg:ClearAllPoints()
                            pair.bg:SetPoint("CENTER", self, "TOPLEFT", bx, -by)
                            pair.bg:SetSize(dashLen + 2.2, dashThick + 2.0)
                            pair.bg:SetVertexColor(col.bgR, col.bgG, col.bgB, alpha * 0.90)
                            if pair.bg.SetRotation then pair.bg:SetRotation(ang) end
                            pair.bg:Show()

                            pair.fg:ClearAllPoints()
                            pair.fg:SetPoint("CENTER", self, "TOPLEFT", bx, -by)
                            pair.fg:SetSize(dashLen, dashThick)
                            if isHovered then
                                pair.fg:SetVertexColor(math.min(1, col.r + 0.22), math.min(1, col.g + 0.22), math.min(1, col.b + 0.22), 1.0)
                            else
                                pair.fg:SetVertexColor(col.r, col.g, col.b, alpha)
                            end
                            if pair.fg.SetRotation then pair.fg:SetRotation(ang) end
                            pair.fg:Show()
                        end

                        -- Draw Port Anchor Nodes at both endpoints
                        for _, pKey in ipairs({ route.from, route.to }) do
                            local pTag = pKey .. "_" .. route.faction
                            if not drawnPorts[pTag] or isHovered then
                                drawnPorts[pTag] = true
                                local pnx, pny = MAWM:GetPortNormalizedPos(pKey)
                                if pnx and pny then
                                    nodeIdx = nodeIdx + 1
                                    local node = AcquirePortNode(nodeIdx)
                                    local nSize = isHovered and 8.5 or 6.5
                                    node.bg:ClearAllPoints()
                                    node.bg:SetPoint("CENTER", self, "TOPLEFT", pnx * w, -(pny * h))
                                    node.bg:SetSize(nSize + 3.0, nSize + 3.0)
                                    node.bg:SetVertexColor(col.bgR, col.bgG, col.bgB, alpha)
                                    if node.bg.SetRotation then node.bg:SetRotation(math.rad(45)) end
                                    node.bg:Show()

                                    node.fg:ClearAllPoints()
                                    node.fg:SetPoint("CENTER", self, "TOPLEFT", pnx * w, -(pny * h))
                                    node.fg:SetSize(nSize, nSize)
                                    node.fg:SetVertexColor(col.r, col.g, col.b, alpha)
                                    if node.fg.SetRotation then node.fg:SetRotation(math.rad(45)) end
                                    node.fg:Show()
                                end
                            end
                        end
                    end
                end
            end
        end

        for i = dashIdx + 1, #f.routeDashPool do
            f.routeDashPool[i].bg:Hide()
            f.routeDashPool[i].fg:Hide()
        end
        for i = nodeIdx + 1, #f.routeNodePool do
            f.routeNodePool[i].bg:Hide()
            f.routeNodePool[i].fg:Hide()
        end
    end

    -- 6. Subtle bottom-left watermark badge on the map
    local badgeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgeText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 12)
    badgeText:SetTextColor(0.92, 0.80, 0.48, 0.85)
    f.BadgeText = badgeText

    -- Layout update when Child changes size or user switches Layout / Style / Language / Scale
    function f:UpdateTileLayout()
        local w, h = self:GetWidth(), self:GetHeight()
        if not w or w <= 0 or not h or h <= 0 then
            w, h = child:GetWidth(), child:GetHeight()
        end
        if not w or w <= 0 then return end

        local tileW = w / 3.0
        local tileH = h / 2.0
        local isCarto = (MAWM_DB and MAWM_DB.style == "carto")
        local prefix = isCarto and "carto" or "blizz"
        local spPrefix = isCarto and "sp_carto_" or "sp_"

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
        local langAtlasPath = TEX_DIR .. "labels_" .. activeLang

        if MAWM.RebuildLayoutBoxes then MAWM:RebuildLayoutBoxes() end
        local layout, layoutKey = GetActiveLayout()
        local cellW = w * ATLAS_CELL_W_NORM
        local cellH = h * ATLAS_CELL_H_NORM
        local showLabels = (not MAWM_DB) or (MAWM_DB.showLabels ~= false)

        for _, cont in ipairs(MAWM.CONTINENTS) do
            local cSpec = (layout and layout.continents and layout.continents[cont.key]) or cont
            local b = cSpec.box or cont.box
            local lp = cSpec.label or { (b[1] + b[3]) * 0.5, (b[2] + b[4]) * 0.5 }

            local cTex = self.contSprites[cont.key]
            if cTex and b then
                cTex:ClearAllPoints()
                cTex:SetPoint("TOPLEFT", self, "TOPLEFT", b[1] * w, -(b[2] * h))
                cTex:SetSize((b[3] - b[1]) * w, (b[4] - b[2]) * h)
                cTex:SetTexture(TEX_DIR .. spPrefix .. cont.key)
                cTex:Show()
            end

            local lTex = self.labelSprites[cont.key]
            if lTex and lp then
                if showLabels then
                    lTex:ClearAllPoints()
                    lTex:SetPoint("CENTER", self, "TOPLEFT", lp[1] * w, -(lp[2] * h))
                    lTex:SetSize(cellW, cellH)
                    lTex:SetTexture(langAtlasPath)
                    lTex:Show()
                else
                    lTex:Hide()
                end
            end
        end

        for i, sea in ipairs(MAWM.SEA_LABELS) do
            local sTex = self.seaLabelSprites[i]
            if sTex then
                if showLabels then
                    sTex:ClearAllPoints()
                    sTex:SetPoint("CENTER", self, "TOPLEFT", sea.x * w, -(sea.y * h))
                    sTex:SetSize(cellW, cellH)
                    sTex:SetTexture(langAtlasPath)
                    sTex:Show()
                else
                    sTex:Hide()
                end
            end
        end

        if MAWM_DB and MAWM_DB.showLore and layoutKey == "mawm" then
            self.LoreTex:Show()
        else
            self.LoreTex:Hide()
        end

        self:UpdateTransitRoutes(self._hoveredRouteId)

        if (not MAWM_DB) or (MAWM_DB.showBadge ~= false) then
            local layoutLabel = layout and L(layout.nameEN, layout.nameRU) or "MAWM"
            local styleLabel = isCarto
                and L("Parchment", "Пергамент")
                or  L("4K Blizz", "4K Близз")
            local langTag = " [" .. langInfo.tag .. "]"
            local loreSuffix = (MAWM_DB and MAWM_DB.showLore and layoutKey == "mawm")
                and L(" • [Lore & Fleet ON]", " • [Лор и Флот ВКЛ]")
                or ""
            local routeSuffix = (MAWM_DB and MAWM_DB.showRoutes)
                and L(" • [Routes ON]", " • [Маршруты ВКЛ]")
                or ""
            self.BadgeText:SetText("|cffffd100MAWM v" .. MAWM.VERSION .. "|r — " .. layoutLabel .. " • " .. styleLabel .. langTag .. loreSuffix .. routeSuffix)
            self.BadgeText:Show()
        else
            self.BadgeText:Hide()
        end
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
            if self._hoveredRouteId then
                self._hoveredRouteId = nil
                self:UpdateTransitRoutes(nil)
            end
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

        -- 1. Check if hovering a Lore Badge first (when Lore Overlay is active in MAWM layout)
        local badge = GetHoveredLoreBadge(nx, ny)
        if badge then
            self.HighlightTex:Hide()
            if self._hoveredRouteId then
                self._hoveredRouteId = nil
                self:UpdateTransitRoutes(nil)
            end
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 16, -12)
            GameTooltip:ClearLines()
            GameTooltip:AddLine(L(badge.titleEN, badge.titleRU), 1.0, 0.84, 0.25, true)
            GameTooltip:AddLine(L(badge.descEN, badge.descRU), 0.92, 0.90, 0.82, true)
            GameTooltip:Show()
            return
        end

        -- 2. Check if hovering a Ships / Zeppelins Transit Route (or Harbor Node)
        local route = GetHoveredTransitRoute(nx, ny)
        if route then
            if self._hoveredRouteId ~= route.id then
                self._hoveredRouteId = route.id
                self:UpdateTransitRoutes(route.id)
            end
            self.HighlightTex:Hide()
            local col = FACTION_COLORS[route.faction] or FACTION_COLORS.NEUTRAL
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 16, -12)
            GameTooltip:ClearLines()
            GameTooltip:AddLine(col.hex .. L(route.titleEN, route.titleRU) .. "|r")
            GameTooltip:AddLine(L(route.vesselEN, route.vesselRU), 0.80, 0.82, 0.88, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffd100" .. L("Where to board (Point A):", "Где сесть (Точка А):") .. "|r")
            GameTooltip:AddLine("  " .. L(route.boardEN, route.boardRU), 0.95, 0.95, 0.95, true)
            GameTooltip:AddLine("|cffffd100" .. L("Destination (Point B):", "Прибытие (Точка Б):") .. "|r")
            GameTooltip:AddLine("  " .. L(route.arriveEN, route.arriveRU), 0.95, 0.95, 0.95, true)
            GameTooltip:Show()
            return
        elseif self._hoveredRouteId then
            self._hoveredRouteId = nil
            self:UpdateTransitRoutes(nil)
        end

        -- 3. Check if hovering a Continent in the active Layout Mode (Inner Golden Coastline Highlight ONLY)
        local cont, b = GetHoveredContinent(nx, ny)
        if cont and b then
            local w, h = self:GetWidth(), self:GetHeight()
            if w and w > 0 and h and h > 0 and cont.hlTex then
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
        self._hoveredRouteId = nil
        SetStockHighlightSuppressed(false)
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)

    self.CanvasFrame = f
    return f
end

-- ============================================================================
-- Build Top-Right World Map Header Control Button + Settings Gear Button
-- ============================================================================
function MAWM:EnsureToggleButton()
    if self.ToggleButton then
        return self.ToggleButton
    end
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer) then
        return nil
    end

    -- 1. Settings Gear Button (anchored at TOPRIGHT -44, -10)
    local gearBtn = CreateFrame("Button", "MAWM_WorldMapGearButton", WorldMapFrame.ScrollContainer, "BackdropTemplate")
    gearBtn:SetSize(28, 28)
    gearBtn:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -44, -10)
    gearBtn:SetFrameStrata("HIGH")
    gearBtn:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 51)
    gearBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    gearBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    gearBtn:SetBackdropColor(0.07, 0.05, 0.03, 0.90)
    gearBtn:SetBackdropBorderColor(0.85, 0.68, 0.28, 0.95)

    local gearIcon = gearBtn:CreateTexture(nil, "ARTWORK")
    gearIcon:SetSize(16, 16)
    gearIcon:SetPoint("CENTER", gearBtn, "CENTER", 0, 0)
    gearIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gearBtn.Icon = gearIcon

    gearBtn:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION or 852)
        end
        if MAWM.ToggleConfigWindow then
            MAWM:ToggleConfigWindow()
        end
    end)
    gearBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.14, 0.08, 0.96)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, -4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cffffd100" .. L("MAWM Control Center", "Панель настроек MAWM") .. "|r")
        GameTooltip:AddLine(L("Click to open the settings window (layouts, continent scale sliders, ship & zeppelin routes).", "Нажмите, чтобы открыть окно настроек (раскладки, ползунки размеров материков, маршруты кораблей и дирижаблей)."), 0.88, 0.85, 0.76, true)
        GameTooltip:Show()
    end)
    gearBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.07, 0.05, 0.03, 0.90)
        GameTooltip:Hide()
    end)
    self.GearButton = gearBtn

    -- 2. Main Status & Quick-Toggle Button (anchored to the left of the Gear Button)
    local btn = CreateFrame("Button", "MAWM_WorldMapToggleButton", WorldMapFrame.ScrollContainer, "BackdropTemplate")
    btn:SetSize(236, 28)
    btn:SetPoint("RIGHT", gearBtn, "LEFT", -4, 0)
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
            local layout = GetActiveLayout()
            local layShort = layout and L(layout.shortEN, layout.shortRU) or "MAWM"
            local st = (MAWM_DB.style == "carto")
                and L("Parch", "Перг")
                or  L("4K", "4K")
            local activeLang = GetActiveLang()
            local langInfo = VALID_LANGS[activeLang] or VALID_LANGS.en
            local langBadge = " |cffffd100[" .. langInfo.tag .. "]|r"
            local loreTag = (MAWM_DB.showLore and GetActiveLayoutKey() == "mawm") and " |cff55ddff[L]|r" or ""
            local routeTag = (MAWM_DB.showRoutes) and " |cff66ff99[R]|r" or ""
            self.Label:SetText("|cffffd100MAWM:|r |cff55ff55" .. layShort .. " • " .. st .. "|r" .. langBadge .. loreTag .. routeTag)
        end
    end

    btn:SetScript("OnClick", function(self, button)
        if not MAWM_DB then return end
        if IsControlKeyDown() then
            CycleLayoutMode()
            if not MAWM_DB.enabled then
                MAWM_DB.enabled = true
            end
        elseif IsAltKeyDown() then
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
        elseif IsShiftKeyDown() then
            MAWM_DB.showRoutes = not MAWM_DB.showRoutes
            if not MAWM_DB.enabled then
                MAWM_DB.enabled = true
            end
        elseif button == "MiddleButton" then
            if MAWM.ToggleConfigWindow then
                MAWM:ToggleConfigWindow()
            end
            return
        elseif button == "RightButton" then
            CycleLayoutMode()
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
        if MAWM.RefreshConfigUI then
            MAWM:RefreshConfigUI()
        end
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
            "Lore-accurate continent proportions, 3 geodesy layouts & live ship/zeppelin routes",
            "Истинные пропорции материков, 3 режима раскладки и маршруты кораблей/дирижаблей"
        ), 0.85, 0.82, 0.72, true)
        GameTooltip:AddLine(" ")

        local statusStr = MAWM_DB.enabled
            and L("|cff55ff55ENABLED|r", "|cff55ff55ВКЛЮЧЕНА|r")
            or  L("|cffff6666DISABLED (Stock Blizzard Map)|r", "|cffff6666ВЫКЛЮЧЕНА (Стандартная карта)|r")
        local layout = GetActiveLayout()
        local layoutStr = "|cff55ff55" .. (layout and L(layout.nameEN, layout.nameRU) or "MAWM") .. "|r"
        local styleStr = (MAWM_DB.style == "carto")
            and L("Cartographer's Illustrated Parchment", "Иллюстрированный пергамент Картографа")
            or  L("Official 4K Blizzard CASC", "Официальная 4K Blizzard CASC")
        local activeLang = GetActiveLang()
        local langInfo = VALID_LANGS[activeLang] or VALID_LANGS.en
        local isAuto = (not MAWM_DB.lang or MAWM_DB.lang == "auto")
        local langStr = "|cffffd100" .. langInfo.name .. (isAuto and " (Client Auto)" or "") .. "|r"
        local routeStr = MAWM_DB.showRoutes
            and L("|cff55ff55ON (Ships & Zeppelins)|r", "|cff55ff55ВКЛ (Корабли и дирижабли)|r")
            or  L("|cff888888OFF|r", "|cff888888ВЫКЛ|r")

        GameTooltip:AddDoubleLine(L("Status:", "Статус:"), statusStr, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L("Layout Mode:", "Режим раскладки:"), layoutStr, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L("Map Style:", "Стиль карты:"), styleStr, 1, 0.82, 0, 0.9, 0.9, 0.9)
        GameTooltip:AddDoubleLine(L("Map Language:", "Язык подписей:"), langStr, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L("Transit Routes:", "Маршруты транспорта:"), routeStr, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddLine(" ")
        if WorldMapFrame:GetMapID() == AZEROTH_MAP_ID then
            GameTooltip:AddLine(L("|cff55ff55Left-Click:|r Toggle Realigned vs Stock Map", "|cff55ff55ЛКМ:|r Переключить исправленную / стандартную карту"), 0.9, 0.9, 0.9)
        else
            GameTooltip:AddLine(L("|cff55ff55Left-Click:|r Jump to Azeroth World Map", "|cff55ff55ЛКМ:|r Открыть глобальную карту Азерота"), 0.9, 0.9, 0.9)
        end
        GameTooltip:AddLine(L("|cff55ff55Right-Click / Ctrl-Click:|r Cycle Layout (MAWM -> Hybrid -> Blizzard)", "|cff55ff55ПКМ / Ctrl+Клик:|r Сменить раскладку (MAWM -> Гибрид -> Blizzard)"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(L("|cff55ff55Shift-Click:|r Toggle Ship & Zeppelin Routes", "|cff55ff55Shift+Клик:|r Вкл/выкл маршруты кораблей и дирижаблей"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(L("|cff55ff55Alt-Click:|r Toggle Client Language / EN", "|cff55ff55Alt+Клик:|r Сменить язык карты (Клиент / EN)"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(L("|cff55ff55Gear Button / Middle-Click:|r Open Settings Window", "|cff55ff55Шестерёнка / СКМ:|r Открыть окно настроек MAWM"), 0.9, 0.9, 0.9)
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
    if self.GearButton then
        self.GearButton:Show()
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
    if cmd == "config" or cmd == "options" or cmd == "settings" or cmd == "gui" or cmd == "menu" then
        if MAWM.ToggleConfigWindow then
            MAWM:ToggleConfigWindow()
        end
        return
    elseif cmd == "layout" or cmd == "mode" or cmd == "mawm" or cmd == "hybrid" or cmd == "blizz" or cmd == "blizzard" or cmd:match("^layout%s+") then
        local arg = cmd:match("^layout%s+(%S+)") or cmd
        if arg == "mawm" then
            MAWM_DB.layout = "mawm"
        elseif arg == "hybrid" then
            MAWM_DB.layout = "hybrid"
        elseif arg == "blizz" or arg == "blizzard" then
            MAWM_DB.layout = "blizz"
        else
            CycleLayoutMode()
        end
        MAWM_DB.enabled = true
    elseif cmd == "style" or cmd == "theme" then
        MAWM_DB.style = (MAWM_DB.style == "carto") and "blizz" or "carto"
        MAWM_DB.enabled = true
    elseif cmd == "routes" or cmd == "ships" or cmd == "zeppelins" then
        MAWM_DB.showRoutes = not MAWM_DB.showRoutes
        MAWM_DB.enabled = true
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
    elseif cmd == "lore" or cmd == "route" or cmd == "fleet" then
        MAWM_DB.showLore = not MAWM_DB.showLore
        if MAWM_DB.showLore then
            MAWM_DB.layout = "mawm"
        end
        MAWM_DB.enabled = true
    elseif cmd == "scale" or cmd:match("^scale%s+") then
        local rest = strtrim((msg or ""):gsub("^[sS][cC][aA][lL][eE]%s*", ""))
        if rest == "" or rest:lower() == "list" then
            print("|cffffd100[MAWM]|r " .. L("Current continent scale multipliers:", "Текущие множители размера континентов:"))
            for _, cont in ipairs(MAWM.CONTINENTS) do
                local k = cont.key
                local val = (MAWM_DB.scales and MAWM_DB.scales[k]) or (MAWM.CONTINENT_SCALES and MAWM.CONTINENT_SCALES[k]) or 1.0
                print(string.format("  |cff55ff55%-15s|r = |cffffd100%.2fx|r", k, val))
            end
            return
        elseif rest:lower() == "reset" then
            MAWM_DB.scales = nil
            if MAWM.RebuildLayoutBoxes then MAWM:RebuildLayoutBoxes() end
        else
            local targetKey, numStr = rest:match("^(%S+)%s+([%d%.]+)$")
            local numVal = tonumber(numStr)
            local matchedKey = nil
            if targetKey and MAWM.CONTINENT_SCALES then
                for k in pairs(MAWM.CONTINENT_SCALES) do
                    if k:lower() == targetKey:lower() then
                        matchedKey = k
                        break
                    end
                end
            end
            if matchedKey and numVal and numVal >= 0.4 and numVal <= 3.0 then
                MAWM_DB.scales = MAWM_DB.scales or {}
                MAWM_DB.scales[matchedKey] = numVal
                if MAWM.RebuildLayoutBoxes then MAWM:RebuildLayoutBoxes() end
            else
                print("|cffffd100[MAWM]|r " .. L("Invalid syntax. Example: |cff55ff55/mawm scale KulTiras 1.8|r", "Неверный формат. Пример: |cff55ff55/mawm scale KulTiras 1.8|r"))
                return
            end
        end
    elseif cmd == "open" or cmd == "map" then
        if not WorldMapFrame:IsShown() then
            ToggleWorldMap()
        end
        WorldMapFrame:SetMapID(AZEROTH_MAP_ID)
        MAWM_DB.enabled = true
    elseif cmd == "help" then
        if MAWM.ToggleConfigWindow then
            MAWM:ToggleConfigWindow()
        end
        return
    else
        if MAWM.ToggleConfigWindow then
            MAWM:ToggleConfigWindow()
        end
        return
    end
    MAWM:RefreshMap()
    if MAWM.RefreshConfigUI then
        MAWM:RefreshConfigUI()
    end
end

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


---------------------------------------------------------------------------------------
--                  MINIMAP BUTTON & ICON (MAWMMinimapButton)                        --
---------------------------------------------------------------------------------------
local minimapBtn = nil

local function UpdateMinimapButtonPosition()
    if not minimapBtn or not _G.Minimap then return end
    local parent = minimapBtn:GetParent()
    if (parent and parent ~= _G.Minimap) or minimapBtn.isSkinned or minimapBtn.original then
        return
    end
    local angle = math.rad(tonumber(MAWM_DB and MAWM_DB.minimapAngle) or 225)
    local okW, rawW = pcall(_G.Minimap.GetWidth, _G.Minimap)
    local mmW = (okW and type(rawW) == "number" and rawW > 0) and rawW or 140
    local radius = (mmW / 2) + 8
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", _G.Minimap, "CENTER", x, y)
end

function MAWM:UpdateMinimapButtonVisibility()
    if not minimapBtn then return end
    if MAWM_DB and MAWM_DB.showMinimapButton == false then
        minimapBtn:Hide()
    else
        minimapBtn:Show()
    end
end

local function CreateMAWMMinimapButton()
    if minimapBtn or not _G.Minimap then return end
    local btn = CreateFrame("Button", "MAWMMinimapButton", _G.Minimap)
    minimapBtn = btn
    btn:SetSize(28, 28)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local frameDecor = CreateFrame("Frame", nil, btn)
    frameDecor:SetAllPoints(btn)
    frameDecor:SetFrameLevel(math.max(1, btn:GetFrameLevel() - 1))

    local bg = frameDecor:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frameDecor)
    bg:SetColorTexture(0.06, 0.05, 0.03, 0.95)

    local border = frameDecor:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", frameDecor, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", frameDecor, "BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.85, 0.68, 0.24, 0.90)
    btn.border = border

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    icon:SetTexture(TEX_DIR .. "Logo")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local label = btn:CreateFontString(nil, "OVERLAY")
    ApplyFont(label, 8)
    label:SetPoint("BOTTOM", btn, "BOTTOM", 0, 1)
    label:SetTextColor(1, 0.85, 0.25, 1)
    label:SetText("MAWM")

    btn:SetScript("OnEnter", function(self)
        if self.border then self.border:SetColorTexture(1.0, 0.86, 0.30, 1.0) end
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            _G.GameTooltip:AddLine("|cffffd100MAWM v" .. tostring(MAWM.VERSION) .. "|r — Most Accurate World Map")
            _G.GameTooltip:AddLine(L("|cff55ff55Left-Click:|r Open MAWM Control Center", "|cff55ff55ЛКМ:|r Открыть окно настроек MAWM"), 0.9, 0.9, 0.9)
            _G.GameTooltip:AddLine(L("|cff55ff55Right-Click:|r Continent Scale Sliders", "|cff55ff55ПКМ:|r Ползунки размеров материков"), 0.9, 0.9, 0.9)
            _G.GameTooltip:AddLine(L("|cff55ff55Shift-Click:|r Toggle Ship & Zeppelin Routes", "|cff55ff55Shift+Клик:|r Вкл/выкл маршруты кораблей и дирижаблей"), 0.9, 0.9, 0.9)
            _G.GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.border then self.border:SetColorTexture(0.85, 0.68, 0.24, 0.90) end
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    btn:SetScript("OnDragStart", function(self)
        if (self:GetParent() and self:GetParent() ~= _G.Minimap) or self.isSkinned then return end
        self:SetScript("OnUpdate", function()
            if not _G.Minimap or not _G.GetCursorPosition then return end
            local okC, mx, my = pcall(_G.Minimap.GetCenter, _G.Minimap)
            local okP, cx, cy = pcall(_G.GetCursorPosition)
            local okS, scale = pcall(_G.Minimap.GetEffectiveScale, _G.Minimap)
            if not okC or not okP or not okS or not scale or scale <= 0 then return end
            cx, cy = cx / scale, cy / scale
            MAWM_DB = MAWM_DB or {}
            MAWM_DB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            UpdateMinimapButtonPosition()
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(_, mouseBtn)
        if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
            MAWM_DB.showRoutes = not MAWM_DB.showRoutes
            MAWM:RefreshMap()
            MAWM:RefreshConfigUI()
            return
        end
        if mouseBtn == "RightButton" then
            MAWM:ToggleConfigWindow(2)
        else
            MAWM:ToggleConfigWindow()
        end
    end)

    UpdateMinimapButtonPosition()
    MAWM:UpdateMinimapButtonVisibility()
end

---------------------------------------------------------------------------------------
--         BLIZZARD ADDON SETTINGS PANEL (ESC -> ПАРАМЕТРЫ -> МОДИФИКАЦИИ)           --
---------------------------------------------------------------------------------------
local blizzardSettingsRegistered = false
local function RegisterMAWMBlizzardSettings()
    if blizzardSettingsRegistered then return end
    if not (_G.Settings and _G.Settings.RegisterCanvasLayoutCategory and _G.Settings.RegisterAddOnCategory) then
        return
    end
    blizzardSettingsRegistered = true

    local panel = CreateFrame("Frame", "MAWMBlizzardSettingsPanel", UIParent)
    panel.name = "MAWM"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ApplyFont(title, 18)
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cffffd100MAWM v" .. tostring(MAWM.VERSION) .. "|r — Most Accurate World Map")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ApplyFont(desc, 13)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    desc:SetWidth(580)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(4)
    desc:SetText("Авторы: |cffffd100Gemini (Tiger) & Anya (5cr3am1ng5oul)|r\n\nЛорно-точная 4K карта мира Азерота: 3 режима раскладки (MAWM, Гибрид, Близзард), ползунки масштаба всех 10 материков, интерактивные маршруты кораблей и дирижаблей и 11 локалей клиента.")

    local function CreateQuickBtn(text, x, y, tabIdx)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(260, 32)
        b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        b:SetText(text)
        b:SetScript("OnClick", function()
            if not (_G.InCombatLockdown and _G.InCombatLockdown()) and _G.HideUIPanel and _G.SettingsPanel and _G.SettingsPanel:IsShown() then
                pcall(_G.HideUIPanel, _G.SettingsPanel)
            end
            MAWM:ToggleConfigWindow(tabIdx or 1)
        end)
        return b
    end

    CreateQuickBtn("1. Карта и Раскладка (/mawm)", 16, -115, 1)
    CreateQuickBtn("2. Размеры материков (Ползунки)", 290, -115, 2)
    CreateQuickBtn("3. Корабли и Дирижабли (Маршруты)", 16, -157, 3)

    local okCat, category = pcall(_G.Settings.RegisterCanvasLayoutCategory, panel, "MAWM")
    if okCat and category then
        pcall(_G.Settings.RegisterAddOnCategory, category)
        MAWM.settingsCategoryID = category.GetID and category:GetID() or nil
    end
end

CreateMAWMMinimapButton()
RegisterMAWMBlizzardSettings()
if _G.C_Timer and _G.C_Timer.After then
    _G.C_Timer.After(1.0, function()
        CreateMAWMMinimapButton()
        RegisterMAWMBlizzardSettings()
        UpdateMinimapButtonPosition()
        MAWM:UpdateMinimapButtonVisibility()
    end)
end
