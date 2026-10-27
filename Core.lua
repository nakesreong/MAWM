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
