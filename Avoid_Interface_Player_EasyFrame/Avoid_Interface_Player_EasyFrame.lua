-- Avoid_Interface_Player_EasyFrame.lua
-- EasyFrame für "player" – ersetzt den Blizzard PlayerFrame optisch

local M    = {}
local unit = "player"

local frame
local eventFrame

local BAR_TEXTURES = {
    DEFAULT = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    RAID    = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    FLAT    = "Interface\\Buttons\\WHITE8x8",

    -- neue Keys müssen zu texItems.value passen:
    SMOOTH  = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill",
    GLASS   = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
}

-- Einfaches Aura-Icon (Buff/Debuff)
local function CreateAuraIcon(parent)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(20, 20)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()

    f.border = f:CreateTexture(nil, "OVERLAY")
    f.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    f.border:SetAllPoints()

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.count:SetPoint("BOTTOMRIGHT", -1, 1)

    return f
end

-- Wrapper für Buffs – arbeitet mit C_UnitAuras (Midnight) oder fällt auf UnitBuff zurück
local function GetBuffInfo(unit, index)
    if C_UnitAuras then
        local data

        -- neuere API-Varianten, je nach Client
        if C_UnitAuras.GetBuffDataByIndex then
            data = C_UnitAuras.GetBuffDataByIndex(unit, index)
        elseif C_UnitAuras.GetAuraDataByIndex then
            data = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
        end

        if data then
            -- name, icon, count zurückgeben (count = Stacks/Applications)
            return data.name, data.icon, data.applications or data.charges or data.stackCount
        end
    end

    -- Fallback für ältere Clients, wo UnitBuff noch existiert
    if UnitBuff then
        return UnitBuff(unit, index)
    end

    return nil
end

-- Wrapper für Debuffs – analog, aber HARMFUL
local function GetDebuffInfo(unit, index)
    if C_UnitAuras then
        local data

        if C_UnitAuras.GetDebuffDataByIndex then
            data = C_UnitAuras.GetDebuffDataByIndex(unit, index)
        elseif C_UnitAuras.GetAuraDataByIndex then
            data = C_UnitAuras.GetAuraDataByIndex(unit, index, "HARMFUL")
        end

        if data then
            return data.name, data.icon, data.applications or data.charges or data.stackCount
        end
    end

    if UnitDebuff then
        return UnitDebuff(unit, index)
    end

    return nil
end

-- Vorgefertigte Layout-Presets für den Playerframe
local PLAYER_PRESETS = {
    ["Standard"] = {
        width  = 260,
        height = 52,

        showName      = true,
        showHPText    = true,
        showMPText    = true,
        showLevelText = true,

        hpTextMode = "BOTH",   -- dein bisheriger Text-Mode
        mpTextMode = "BOTH",

        nameSize      = 14,
        hpTextSize    = 12,
        mpTextSize    = 12,
        levelTextSize = 12,

        -- Beispiel-Ausrichtungen (anpassen wie du magst)
        nameAnchor   = "TOPLEFT",
        nameXOffset  = 4,
        nameYOffset  = -4,

        hpTextAnchor = "CENTER",
        hpTextXOffset = 0,
        hpTextYOffset = 0,

        mpTextAnchor = "CENTER",
        mpTextXOffset = 0,
        mpTextYOffset = -14,

        levelAnchor   = "TOPRIGHT",
        levelXOffset  = -4,
        levelYOffset  = -4,
    },

    ["Kompakt"] = {
        width  = 220,
        height = 42,

        showName      = true,
        showHPText    = true,
        showMPText    = false,
        showLevelText = false,

        hpTextMode = "PERCENT",

        nameSize      = 12,
        hpTextSize    = 11,

        nameAnchor   = "TOPLEFT",
        nameXOffset  = 4,
        nameYOffset  = -2,

        hpTextAnchor = "BOTTOMRIGHT",
        hpTextXOffset = -4,
        hpTextYOffset = 4,
    },

    ["Groß & Deutlich"] = {
        width  = 320,
        height = 60,

        showName      = true,
        showHPText    = true,
        showMPText    = true,
        showLevelText = true,

        hpTextMode = "BOTH",
        mpTextMode = "BOTH",

        nameSize      = 16,
        hpTextSize    = 14,
        mpTextSize    = 14,
        levelTextSize = 14,
    },
}

local function ApplyPresetToConfig(cfg, preset)
    for key, value in pairs(preset) do
        if type(value) == "table" then
            -- einfache, flache Kopie reicht hier
            local t = {}
            for k, v in pairs(value) do
                t[k] = v
            end
            cfg[key] = t
        else
            cfg[key] = value
        end
    end
end

function M.GetPresets()
    return PLAYER_PRESETS
end

function M.ApplyPreset(presetKey)
    local preset = PLAYER_PRESETS[presetKey]
    if not preset then return end

    local cfg = GetPlayerConfig()
    ApplyPresetToConfig(cfg, preset)

    -- Layout neu anwenden
    if M.ApplyLayout then
        M.ApplyLayout()
    end
end

-------------------------------------------------
-- KONFIG / STATE
-------------------------------------------------
local function GetPlayerConfig()
    AI_Config = AI_Config or {}
    AI_Config.modules = AI_Config.modules or {}

    local entry = AI_Config.modules.player
    if type(entry) == "boolean" then
        entry = { enabled = entry }
        AI_Config.modules.player = entry
    elseif type(entry) ~= "table" then
        entry = { enabled = true }
        AI_Config.modules.player = entry
    end

    if entry.enabled == nil then entry.enabled = true end
    if entry.movable == nil then entry.movable = false end

    local playerEntry = AI_Config.modules.player

    entry.width   = entry.width   or 260
    entry.height  = entry.height  or 60
    entry.hpRatio = entry.hpRatio or 0.66
    entry.alpha   = entry.alpha   or 1

    entry.x = entry.x or -300
    entry.y = entry.y or -200

    entry.manaEnabled       = (entry.manaEnabled       ~= false)
    entry.absorbEnabled     = (entry.absorbEnabled     ~= false)
    entry.healAbsorbEnabled = (entry.healAbsorbEnabled ~= false)

    -- Bar-Texturen
    entry.hpTexture = entry.hpTexture or entry.barTexture or "DEFAULT"
    entry.mpTexture = entry.mpTexture or entry.barTexture or "DEFAULT"


    -- HP-Farbmodus
    if entry.hpColorMode ~= "CLASS" and entry.hpColorMode ~= "DEFAULT" then
        entry.hpColorMode = "CLASS"
    end

    -- Texte ein/aus
    entry.showName      = (entry.showName      ~= false)
    entry.showHPText    = (entry.showHPText    ~= false)
    entry.showMPText    = (entry.showMPText    ~= false)
    entry.showLevelText = (entry.showLevelText ~= false)

    -- Schriftgrößen
    -- Eigene Textfarben für Name / HP / Mana / Level
    entry.nameTextColor  = entry.nameTextColor  or { r = 1, g = 1, b = 1 }
    entry.hpTextColor    = entry.hpTextColor    or { r = 1, g = 1, b = 1 }
    entry.mpTextColor    = entry.mpTextColor    or { r = 1, g = 1, b = 1 }
    entry.levelTextColor = entry.levelTextColor or { r = 1, g = 1, b = 1 }


    -- Anker
    entry.nameAnchor   = entry.nameAnchor   or "TOPLEFT"
    entry.hpTextAnchor = entry.hpTextAnchor or "TOPRIGHT"
    entry.mpTextAnchor = entry.mpTextAnchor or "BOTTOMRIGHT"
    entry.levelAnchor  = entry.levelAnchor  or "BOTTOMLEFT"

    -- Offsets
    entry.nameXOffset   = entry.nameXOffset   or 0
    entry.nameYOffset   = entry.nameYOffset   or 0
    entry.hpTextXOffset = entry.hpTextXOffset or 0
    entry.hpTextYOffset = entry.hpTextYOffset or 0
    entry.mpTextXOffset = entry.mpTextXOffset or 0
    entry.mpTextYOffset = entry.mpTextYOffset or 0
    entry.levelXOffset  = entry.levelXOffset  or 0
    entry.levelYOffset  = entry.levelYOffset  or 0

    -- Bold / Shadow Flags
    if entry.nameBold   == nil then entry.nameBold   = false end
    if entry.nameShadow == nil then entry.nameShadow = true  end

    if entry.hpTextBold   == nil then entry.hpTextBold   = false end
    if entry.hpTextShadow == nil then entry.hpTextShadow = true  end

    if entry.mpTextBold   == nil then entry.mpTextBold   = false end
    if entry.mpTextShadow == nil then entry.mpTextShadow = true  end

    if entry.levelBold   == nil then entry.levelBold   = false end
    if entry.levelShadow == nil then entry.levelShadow = true  end

    -- HP / Mana Text Mode (nur "BOTH" oder "PERCENT")
    if entry.hpTextMode ~= "PERCENT" and entry.hpTextMode ~= "BOTH" then
        entry.hpTextMode = "BOTH"
    end
    if entry.mpTextMode ~= "PERCENT" and entry.mpTextMode ~= "BOTH" then
        entry.mpTextMode = "BOTH"
    end

    -- Hintergrund-Modus für den Frame
    if entry.frameBgMode ~= "OFF" and entry.frameBgMode ~= "CLASS" and entry.frameBgMode ~= "CLASSPOWER" then
        entry.frameBgMode = "OFF"
    end

    -- Textfarben (falls aus Config nicht gesetzt)

    entry.nameTextColor  = entry.nameTextColor  or { r = 1, g = 1, b = 1 }
    entry.hpTextColor    = entry.hpTextColor    or { r = 1, g = 1, b = 1 }
    entry.mpTextColor    = entry.mpTextColor    or { r = 1, g = 1, b = 1 }
    entry.levelTextColor = entry.levelTextColor or { r = 1, g = 1, b = 1 }

    -- Icons: Combat / Rest / Leader / RaidTarget
    if entry.combatIconEnabled == nil then entry.combatIconEnabled = true end
    if entry.restingIconEnabled == nil then entry.restingIconEnabled = true end
    if entry.leaderIconEnabled  == nil then entry.leaderIconEnabled  = true end
    if entry.raidIconEnabled    == nil then entry.raidIconEnabled    = true end

    entry.combatIconSize = entry.combatIconSize or 24
    entry.restingIconSize = entry.restingIconSize or 24
    entry.leaderIconSize  = entry.leaderIconSize  or 18
    entry.raidIconSize    = entry.raidIconSize    or 20

    entry.combatIconAnchor = entry.combatIconAnchor or "TOPLEFT"
    entry.restingIconAnchor = entry.restingIconAnchor or "TOPLEFT"
    entry.leaderIconAnchor  = entry.leaderIconAnchor  or "TOPRIGHT"
    entry.raidIconAnchor    = entry.raidIconAnchor    or "TOP"

    entry.combatIconXOffset = entry.combatIconXOffset or -4
    entry.combatIconYOffset = entry.combatIconYOffset or 4

    entry.restingIconXOffset = entry.restingIconXOffset or -4
    entry.restingIconYOffset = entry.restingIconYOffset or 4

    entry.leaderIconXOffset = entry.leaderIconXOffset or 4
    entry.leaderIconYOffset = entry.leaderIconYOffset or 4

    entry.raidIconXOffset = entry.raidIconXOffset or 0
    entry.raidIconYOffset = entry.raidIconYOffset or 10

    -- Rahmen
    if entry.borderEnabled == nil then entry.borderEnabled = false end
    entry.borderSize = entry.borderSize or 1

    -- -- Rahmen-Stil
    -- if entry.borderStyle ~= "PIXEL" and entry.borderStyle ~= "TOOLTIP" then
    --     entry.borderStyle = "PIXEL" -- Standard: alter Pixelrahmen
    -- end

    -- Buff-Defaults
    entry.buffs = entry.buffs or {}
    local b = entry.buffs
    if b.enabled == nil then b.enabled = true end
    b.anchor = b.anchor or "TOPLEFT"
    b.x      = b.x      or 0
    b.y      = b.y      or 10
    b.size   = b.size   or 24
    b.grow   = b.grow   or "RIGHT"  -- RIGHT / LEFT / UP / DOWN
    b.max    = b.max    or 12
    b.perRow = b.perRow or 8        -- NEU: Icons pro Reihe

    -- Debuff-Defaults
    entry.debuffs = entry.debuffs or {}
    local d = entry.debuffs
    if d.enabled == nil then d.enabled = true end
    d.anchor = d.anchor or "TOPLEFT"
    d.x      = d.x      or 0
    d.y      = d.y      or -26   -- etwas unter den Buffs
    d.size   = d.size   or 24
    d.grow   = d.grow   or "RIGHT"
    d.max    = d.max    or 12
    d.perRow = d.perRow or 8     -- NEU: Icons pro Reihe


    -- Custom Farben für HP / Mana
    if entry.hpUseCustomColor == nil then
        entry.hpUseCustomColor = false
    end
    if not entry.hpCustomColor then
        entry.hpCustomColor = { r = 0, g = 1, b = 0 }  -- Standard: grün
    end

    if entry.mpUseCustomColor == nil then
        entry.mpUseCustomColor = false
    end
    if not entry.mpCustomColor then
        entry.mpCustomColor = { r = 0, g = 0, b = 1 }  -- Standard: blau
    end

    -- Wenn Klassenfarbe aktiv ist, darf Custom HP-Farbe NICHT aktiv sein
    if entry.hpColorMode == "CLASS" then
        entry.hpUseCustomColor = false
    end

        local validBorderStyles = {
        PIXEL   = true,
        TOOLTIP = true,
        DIALOG  = true,
        THIN    = true,
        THICK   = true,
    }

    if not validBorderStyles[entry.borderStyle] then
        entry.borderStyle = "PIXEL"
    end

    -- Text-Classcolor-Flags (werden aus Config gesetzt, hier nur Defaults)
    if entry.nameTextUseClassColor == nil then
        entry.nameTextUseClassColor = false
    end
    if entry.hpTextUseClassColor == nil then
        entry.hpTextUseClassColor = false
    end
    if entry.mpTextUseClassColor == nil then
        entry.mpTextUseClassColor = false
    end
    if entry.levelTextUseClassColor == nil then
        entry.levelTextUseClassColor = false
    end

    return entry
end

-- ▼ NEU: lokale Funktion auch als globale verfügbar machen
_G.GetPlayerConfig = GetPlayerConfig

-------------------------------------------------
-- BLIZZARD PLAYERFRAME AN / AUS
-------------------------------------------------
local function MakeBlizzardPlayerInvisible()
    if not PlayerFrame then return end

    PlayerFrame:SetAlpha(0)
    PlayerFrame:EnableMouse(false)

    if PlayerFrame.healthbar and PlayerFrame.healthbar.TextString then
        PlayerFrame.healthbar.TextString:Hide()
    end
    if PlayerFrame.manabar and PlayerFrame.manabar.TextString then
        PlayerFrame.manabar.TextString:Hide()
    end
end

local function RestoreBlizzardPlayer()
    if not PlayerFrame then return end

    PlayerFrame:SetAlpha(1)
    PlayerFrame:EnableMouse(true)

    if PlayerFrame.healthbar and PlayerFrame.healthbar.TextString then
        PlayerFrame.healthbar.TextString:Show()
    end
    if PlayerFrame.manabar and PlayerFrame.manabar.TextString then
        PlayerFrame.manabar.TextString:Show()
    end
end

-------------------------------------------------
-- POSITION SPEICHERN
-------------------------------------------------
function M.StoreCurrentPosition()
    if not frame then return end
    local cfg = GetPlayerConfig()
    local x, y = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    cfg.x = x - ux
    cfg.y = y - uy
end

-- Frame auf Default-Position zurücksetzen
function M.ResetPosition()
    local cfg = GetPlayerConfig()

    -- „Werks“-Position festlegen
    cfg.x = -300
    cfg.y = -200

    if frame and UIParent then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
    end
end

-------------------------------------------------
-- TEXTLAYOUT
-------------------------------------------------
local function ApplyTextLayout(fs, show, size, anchor, xOff, yOff, bold, shadow, color)
    if not fs then return end

    -- Immer zuerst eine gültige Schrift setzen,
    -- damit SetText niemals auf einer "fontlosen" FontString läuft.
    local baseFont = STANDARD_TEXT_FONT or (GameFontNormal and select(1, GameFontNormal:GetFont()))
    baseFont = baseFont or "Fonts\\FRIZQT__.TTF"

    local flags = ""
    if bold then
        flags = "OUTLINE"
    end

    fs:SetFont(baseFont, size or 12, flags)

    if not show then
        fs:SetText("")
        fs:Hide()
        return
    end

    fs:Show()

    if shadow then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.9)
    else
        fs:SetShadowOffset(0, 0)
    end
    
    if color and color.r and color.g and color.b then
        fs:SetTextColor(color.r, color.g, color.b, 1)
    else
        fs:SetTextColor(1, 1, 1, 1)
    end


    fs:ClearAllPoints()
    anchor = anchor or "CENTER"
    fs:SetPoint(anchor, frame, anchor, xOff or 0, yOff or 0)
    fs:SetDrawLayer("OVERLAY", 7)
end

-- NEU: wählt zwischen Custom-Textfarbe und Klassenfarbe
local function GetTextColorForElement(cfgColor, useClassColor)
    -- keine Klassenfarbe -> nimm Config-Farbe oder Weiß
    if not useClassColor then
        return cfgColor or { r = 1, g = 1, b = 1 }
    end

    -- Nur für Spieler: echte Klassenfarbe
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            return { r = c.r, g = c.g, b = c.b }
        end
    end

    -- Fallback: Custom-Farbe (oder Weiß)
    return cfgColor or { r = 1, g = 1, b = 1 }
end

-------------------------------------------------
-- FRAMELAYOUT
-------------------------------------------------
local function ApplyFrameLayout()
    if not frame then return end
    local cfg = GetPlayerConfig()

    local w = cfg.width
    local h = cfg.height

    if w < 10 then w = 10 elseif w > 600 then w = 600 end
    if h < 10 then h = 10 elseif h > 600 then h = 600 end

    frame:SetSize(w, h)
    frame:SetAlpha(cfg.alpha or 1)

    local marginTop    = 2
    local marginBottom = 2
    local spacingBars  = 2
    local minBar       = 15

    local availableHeight = h - marginTop - marginBottom
    if availableHeight <= 0 then availableHeight = 1 end

    local hasMana = cfg.manaEnabled
    local hpHeight, mpHeight

    if hasMana then
        local hpRatio = cfg.hpRatio or 0.66
        if hpRatio < 0.1 then hpRatio = 0.1 end
        if hpRatio > 0.9 then hpRatio = 0.9 end

        local barsHeight = availableHeight - spacingBars
        if barsHeight <= 0 then barsHeight = 1 end

        local desiredHp = barsHeight * hpRatio
        hpHeight = math.floor(desiredHp + 0.5)
        mpHeight = barsHeight - hpHeight

        local minTotal = 2 * minBar
        if hpHeight < minBar or mpHeight < minBar then
            if barsHeight < minTotal then
                local each = math.max(1, math.floor(barsHeight / 2 + 0.5))
                hpHeight = each
                mpHeight = barsHeight - each
            else
                if hpHeight < minBar then
                    hpHeight = minBar
                    mpHeight = barsHeight - hpHeight
                end
                if mpHeight < minBar then
                    mpHeight = minBar
                    hpHeight = barsHeight - mpHeight
                    if hpHeight < minBar then
                        local each = math.max(1, math.floor(barsHeight / 2 + 0.5))
                        hpHeight = each
                        mpHeight = barsHeight - each
                    end
                end
            end
        end
    else
        hpHeight = availableHeight
        mpHeight = 0
    end

    frame.healthBar:ClearAllPoints()
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -marginTop)
    frame.healthBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -marginTop)
    frame.healthBar:SetHeight(hpHeight)

    if hasMana then
        frame.powerBar:ClearAllPoints()
        frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -spacingBars)
        frame.powerBar:SetPoint("TOPRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, -spacingBars)
        frame.powerBar:SetHeight(mpHeight)
        frame.powerBar:Show()
        if frame.powerBarBG then
            frame.powerBarBG:Show()
        end
    else
        frame.powerBar:Hide()
        if frame.powerBarBG then
            frame.powerBarBG:Hide()
        end
    end

    -- Layering
    local baseLevel = frame:GetFrameLevel() or 1
    frame.healthBar:SetFrameLevel(baseLevel + 1)
    frame.powerBar:SetFrameLevel(baseLevel + 1)
    frame.bg:SetDrawLayer("BACKGROUND", 0)

    if frame.border then
        frame.border:SetFrameLevel(baseLevel + 2)
    end

    frame.textFrame:SetFrameLevel(baseLevel + 3)

    if frame.iconFrame then
        frame.iconFrame:SetFrameLevel(baseLevel + 4)
    end

    -- Low-HP- und Dead-Overlay sauber layern
    if frame.lowHPOverlay then
        frame.lowHPOverlay:SetDrawLayer("OVERLAY", 1)
    end

    if frame.deadOverlay then
        frame.deadOverlay:SetDrawLayer("OVERLAY", 2) -- liegt über dem Low-HP-Overlay
    end


    -- Rahmen anwenden (Stil: Pixel vs Tooltip mit runden Ecken)
    if frame.border then
        if cfg.borderEnabled and cfg.borderSize and cfg.borderSize > 0 then
            local size = cfg.borderSize
            if size < 1  then size = 1  end
            if size > 16 then size = 16 end

            local style = cfg.borderStyle or "PIXEL"

            -- frisches Backdrop bauen, damit nichts vom alten Stil hängen bleibt
            local bd = {
                bgFile   = nil,
                edgeFile = nil,
                tile     = false,
                tileSize = 0,
                edgeSize = 0,
                insets   = { left = 0, right = 0, top = 0, bottom = 0 },
            }

            if style == "TOOLTIP" then
                local edgeSize = math.max(8, math.min(16, size * 2))

                bd.edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"
                bd.edgeSize = edgeSize
                bd.insets   = {
                    left   = edgeSize * 0.35,
                    right  = edgeSize * 0.35,
                    top    = edgeSize * 0.35,
                    bottom = edgeSize * 0.35,
                }
            elseif style == "DIALOG" then
                bd.edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"
                bd.edgeSize = 16
                bd.insets   = { left = 4, right = 4, top = 4, bottom = 4 }

            elseif style == "THIN" then
                bd.edgeFile = "Interface\\Buttons\\WHITE8x8"
                bd.edgeSize = 1
                bd.insets   = { left = 0, right = 0, top = 0, bottom = 0 }

            elseif style == "THICK" then
                bd.edgeFile = "Interface\\Buttons\\WHITE8x8"
                bd.edgeSize = math.max(2, math.min(8, size))
                bd.insets   = { left = 0, right = 0, top = 0, bottom = 0 }
            else
                -- Klassischer Pixelframe
                bd.edgeFile = "Interface\\Buttons\\WHITE8x8"
                bd.edgeSize = size
                bd.insets   = { left = 0, right = 0, top = 0, bottom = 0 }
            end

            frame.border:SetBackdrop(bd)
            frame.border:SetBackdropBorderColor(1, 1, 1, 1)
            frame.border:Show()

            -- Hintergrund passend zum Rahmen-Stil einrücken
            if frame.bg then
                frame.bg:ClearAllPoints()
                if style == "TOOLTIP" then
                    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
                    frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
                else
                    -- Pixelframe: Hintergrund fast bis an den Rand
                    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
                    frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
                end
            end
        else
            -- Rahmen aus → Border verstecken, Background vollflächig
            frame.border:Hide()
            if frame.bg then
                frame.bg:ClearAllPoints()
                frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            end
        end
    end

        -- Texte ausrichten
    local e = cfg

    -- endgültige Textfarben je nach Classcolor-Flag bestimmen
    local nameColor  = GetTextColorForElement(e.nameTextColor,  e.nameTextUseClassColor)
    local hpColor    = GetTextColorForElement(e.hpTextColor,    e.hpTextUseClassColor)
    local mpColor    = GetTextColorForElement(e.mpTextColor,    e.mpTextUseClassColor)
    local levelColor = GetTextColorForElement(e.levelTextColor, e.levelTextUseClassColor)

    ApplyTextLayout(
        frame.nameText,
        e.showName,
        e.nameSize,
        e.nameAnchor,
        e.nameXOffset,
        e.nameYOffset,
        e.nameBold,
        e.nameShadow,
        nameColor
    )

    ApplyTextLayout(
        frame.healthText,
        e.showHPText,
        e.hpTextSize,
        e.hpTextAnchor,
        e.hpTextXOffset,
        e.hpTextYOffset,
        e.hpTextBold,
        e.hpTextShadow,
        hpColor
    )

    ApplyTextLayout(
        frame.powerText,
        e.showMPText and e.manaEnabled,
        e.mpTextSize,
        e.mpTextAnchor,
        e.mpTextXOffset,
        e.mpTextYOffset,
        e.mpTextBold,
        e.mpTextShadow,
        mpColor
    )

    ApplyTextLayout(
        frame.levelText,
        e.showLevelText,
        e.levelTextSize,
        e.levelAnchor,
        e.levelXOffset,
        e.levelYOffset,
        e.levelBold,
        e.levelShadow,
        levelColor
    )


end

local function ApplyIconLayout()
    if not frame then return end
    local cfg = GetPlayerConfig()

    if not frame.iconFrame then return end

    local function layoutIcon(icon, enabled, size, anchor, xOfs, yOfs)
        if not icon then return end

        icon:ClearAllPoints()
        icon:SetSize(size or 24, size or 24)
        icon:SetPoint(anchor or "TOPLEFT", frame, anchor or "TOPLEFT", xOfs or 0, yOfs or 0)

        if not enabled then
            icon:Hide()
        end
        -- Sichtbarkeit im Detail wird in UpdateStateIcons geregelt
    end

    layoutIcon(
        frame.combatIcon,
        cfg.combatIconEnabled,
        cfg.combatIconSize,
        cfg.combatIconAnchor,
        cfg.combatIconXOffset,
        cfg.combatIconYOffset
    )

    layoutIcon(
        frame.restingIcon,
        cfg.restingIconEnabled,
        cfg.restingIconSize,
        cfg.restingIconAnchor,
        cfg.restingIconXOffset,
        cfg.restingIconYOffset
    )

    layoutIcon(
        frame.leaderIcon,
        cfg.leaderIconEnabled,
        cfg.leaderIconSize,
        cfg.leaderIconAnchor,
        cfg.leaderIconXOffset,
        cfg.leaderIconYOffset
    )

    layoutIcon(
        frame.raidIcon,
        cfg.raidIconEnabled,
        cfg.raidIconSize,
        cfg.raidIconAnchor,
        cfg.raidIconXOffset,
        cfg.raidIconYOffset
    )
end

-------------------------------------------------
-- BAR STYLE (TEXTURE + FARBEN + BG)
-------------------------------------------------
local function ApplyBarStyle()
    if not frame then return end
    local cfg = GetPlayerConfig()

    local hpTexPath = BAR_TEXTURES[cfg.hpTexture] or BAR_TEXTURES.DEFAULT
    local mpTexPath = BAR_TEXTURES[cfg.mpTexture] or BAR_TEXTURES.DEFAULT

    frame.healthBar:SetStatusBarTexture(hpTexPath)
    frame.powerBar:SetStatusBarTexture(mpTexPath)

        -- HP-Farbe (Balken)
    local hr, hg, hb = 0, 1, 0
    if cfg.hpColorMode == "CLASS" then
        local _, class = UnitClass(unit)
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local c = RAID_CLASS_COLORS[class]
            hr, hg, hb = c.r, c.g, c.b
        end
    end

    -- Custom-Farbe überschreibt Klassen-/Standardfarbe
    if cfg.hpUseCustomColor and cfg.hpCustomColor then
        hr = cfg.hpCustomColor.r or hr
        hg = cfg.hpCustomColor.g or hg
        hb = cfg.hpCustomColor.b or hb
    end

    frame.healthBar:SetStatusBarColor(hr, hg, hb, 1)

    -- Basisfarbe für spätere Highlights merken
    frame.hpBaseColor = frame.hpBaseColor or {}
    frame.hpBaseColor.r = hr
    frame.hpBaseColor.g = hg
    frame.hpBaseColor.b = hb


    -- Basisfarbe speichern, damit wir sie beim Low-HP-Highlight wiederherstellen können
    frame.hpBaseColor = frame.hpBaseColor or {}
    frame.hpBaseColor.r = hr
    frame.hpBaseColor.g = hg
    frame.hpBaseColor.b = hb

        -- Mana-Farbe (Balken) per PowerBarColor
    local pType = UnitPowerType(unit)
    local info  = PowerBarColor and PowerBarColor[pType] or PowerBarColor and PowerBarColor["MANA"]
    local pr, pg, pb = 0, 0, 1
    if info then
        pr, pg, pb = info.r, info.g, info.b
    end

    -- Custom-Farbe für Mana / Power
    if cfg.mpUseCustomColor and cfg.mpCustomColor then
        pr = cfg.mpCustomColor.r or pr
        pg = cfg.mpCustomColor.g or pg
        pb = cfg.mpCustomColor.b or pb
    end

    frame.powerBar:SetStatusBarColor(pr, pg, pb, 1)

    -- Hintergrundfarben (Frame + Bar-BGs)
    local frameR, frameG, frameB, frameA = 0.05, 0.05, 0.05, 0.8
    local hpMul, hpA = 0.2, 0.7
    local mpMul, mpA = 0.2, 0.7

    if cfg.frameBgMode == "CLASS" then
        -- kompletter Frame leicht in HP-/Klassenfarbe getönt
        frameR, frameG, frameB, frameA = hr * 0.15, hg * 0.15, hb * 0.15, 0.85
    elseif cfg.frameBgMode == "CLASSPOWER" then
        -- neutrale Grundfläche, dafür kräftigere HP-/MP-Bereiche
        frameR, frameG, frameB, frameA = 0, 0, 0, 0.8
        hpMul, hpA = 0.5, 0.9
        mpMul, mpA = 0.5, 0.9
    end

    if frame.bg then
        frame.bg:SetColorTexture(frameR, frameG, frameB, frameA)
    end

    if frame.healthBarBG then
        frame.healthBarBG:SetColorTexture(hr * hpMul, hg * hpMul, hb * hpMul, hpA)
    end
    if frame.powerBarBG then
        frame.powerBarBG:SetColorTexture(pr * mpMul, pg * mpMul, pb * mpMul, mpA)
    end
end


-------------------------------------------------
-- TEXTFORMAT FÜR HP / MANA
-------------------------------------------------
local function FormatHPText(unit, mode, hp, hpMax)
    if not hp or not hpMax or hpMax <= 0 then
        return ""
    end

    if mode ~= "PERCENT" and mode ~= "BOTH" then
        mode = "BOTH"
    end

    local hpStr  = tostring(hp)
    local maxStr = tostring(hpMax)
    if AbbreviateLargeNumbers then
        hpStr  = AbbreviateLargeNumbers(hp)
        maxStr = AbbreviateLargeNumbers(hpMax)
    end

    local pct = UnitHealthPercent and UnitHealthPercent(unit, false, true)

    if mode == "PERCENT" then
        if pct ~= nil then
            return string.format("%d%%", pct)
        else
            return hpStr
        end
    end

    -- BOTH
    return string.format("%s / %s", hpStr, maxStr)
end


local function FormatPowerText(unit, mode, pType, p, pMax)
    if not p or not pMax or pMax <= 0 then
        return ""
    end

    if mode ~= "PERCENT" and mode ~= "BOTH" then
        mode = "BOTH"
    end

    local pStr   = tostring(p)
    local maxStr = tostring(pMax)
    if AbbreviateLargeNumbers then
        pStr   = AbbreviateLargeNumbers(p)
        maxStr = AbbreviateLargeNumbers(pMax)
    end

    if mode == "PERCENT" then
        local pct = UnitPowerPercent and UnitPowerPercent(unit, pType, false, true)
        if pct ~= nil then
            return string.format("%d%%", pct)
        else
            return pStr
        end
    end

    -- BOTH
    return string.format("%s / %s", pStr, maxStr)
end

-------------------------------------------------
-- WERTE-UPDATE
-------------------------------------------------

-------------------------------------------------
-- LOW-HP OVERLAY
-- Midnight: HP/Prozent sind "secret values".
-- Wir dürfen NICHT vergleichen oder rechnen.
-- Deshalb kann hier KEINE echte Low-HP-Logik
-- implementiert werden. Stattdessen:
-- Wenn Option an -> Overlay an (reiner Style-Effekt).
-------------------------------------------------
local function UpdateLowHPOverlay()
    if not frame or not frame.lowHPOverlay then return end

    local cfg = GetPlayerConfig()
    if cfg.lowHPHighlightEnabled then
        frame.lowHPOverlay:Show()
    else
        frame.lowHPOverlay:Hide()
    end
end


-- Dead/Ghost Overlay aktualisieren (nutzt nur bool-APIs, kein Secret-Mathe)
local function UpdateDeadGhostOverlay()
    if not frame or not frame.deadOverlay then return end

    local isDead  = UnitIsDead(unit)
    local isGhost = UnitIsGhost(unit)

    if isDead or isGhost then
        frame.deadOverlay:Show()
    else
        frame.deadOverlay:Hide()
    end
end

-- Absorb / HealAbsorb Bars aktualisieren (Midnight-safe, keine Secret-Mathe)
local function UpdateAbsorbBars(hpMax)
    if not frame or not frame.healthBar then return end

    local cfg = GetPlayerConfig()

    -- gleiche Max wie die HP-Bar verwenden
    local maxValue = hpMax or UnitHealthMax(unit)
    if not maxValue then
        maxValue = 1 -- Fallback, kein Vergleich
    end

    -- Shields (Total Absorb)
    if frame.absorbBar then
        if cfg.absorbEnabled then
            frame.absorbBar:SetMinMaxValues(0, maxValue)

            local absorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)
            if not absorb then
                absorb = 0 -- nil → 0, 0 ist truthy, also kein Vergleich nötig
            end

            frame.absorbBar:SetValue(absorb)
            frame.absorbBar:Show()
        else
            frame.absorbBar:SetMinMaxValues(0, 1)
            frame.absorbBar:SetValue(0)
            frame.absorbBar:Hide()
        end
    end

    -- HealAbsorb (verhindert Heilung)
    if frame.healAbsorbBar then
        if cfg.healAbsorbEnabled then
            frame.healAbsorbBar:SetMinMaxValues(0, maxValue)

            local healAbsorb = UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs(unit)
            if not healAbsorb then
                healAbsorb = 0
            end

            frame.healAbsorbBar:SetValue(healAbsorb)
            frame.healAbsorbBar:Show()
        else
            frame.healAbsorbBar:SetMinMaxValues(0, 1)
            frame.healAbsorbBar:SetValue(0)
            frame.healAbsorbBar:Hide()
        end
    end
end

local function UpdateHealthAndPower()
    if not frame or not frame:IsShown() then return end
    if not UnitExists(unit) then
        frame:Hide()
        return
    end

    local cfg = GetPlayerConfig()

    -- HP direkt aus UnitHealth (Midnight-safe)
    local hp    = UnitHealth(unit)
    local hpMax = UnitHealthMax(unit)
    if not hp or not hpMax or hpMax <= 0 then
        frame.healthBar:SetMinMaxValues(0, 1)
        frame.healthBar:SetValue(0)
    else
        frame.healthBar:SetMinMaxValues(0, hpMax)
        frame.healthBar:SetValue(hp)
    end

    -- Absorb / HealAbsorb Bars an die aktuelle MaxHP anpassen
    UpdateAbsorbBars(hpMax)

    -- Power
    local pType    = UnitPowerType(unit)
    local power    = UnitPower(unit, pType)
    local powerMax = UnitPowerMax(unit, pType)

    if cfg.manaEnabled and powerMax and powerMax > 0 then
        frame.powerBar:SetMinMaxValues(0, powerMax)
        frame.powerBar:SetValue(power or 0)
        frame.powerBar:Show()
        if frame.powerBarBG then frame.powerBarBG:Show() end
    else
        frame.powerBar:SetMinMaxValues(0, 1)
        frame.powerBar:SetValue(0)
        if frame.powerBarBG then frame.powerBarBG:Hide() end
    end

    -- Name
    if cfg.showName then
        local name = UnitName(unit) or ""
        frame.nameText:SetText(name)
    else
        frame.nameText:SetText("")
    end

    -- HP-Text
    if cfg.showHPText and hp and hpMax and hpMax > 0 then
        frame.healthText:SetText(FormatHPText(unit, cfg.hpTextMode or "BOTH", hp, hpMax))
    else
        frame.healthText:SetText("")
    end

    -- Mana-/Power-Text
    if cfg.manaEnabled and cfg.showMPText and powerMax and powerMax > 0 then
        frame.powerText:SetText(FormatPowerText(unit, cfg.mpTextMode or "BOTH", pType, power or 0, powerMax))
    else
        frame.powerText:SetText("")
    end

    -- Level
    if cfg.showLevelText then
        local lvl = UnitLevel(unit)
        if not lvl or lvl <= 0 then
            frame.levelText:SetText("??")
        else
            frame.levelText:SetText(tostring(lvl))
        end
    else
        frame.levelText:SetText("")
    end

    -- Low-HP Overlay aktualisieren
    UpdateLowHPOverlay()
end

-------------------------------------------------
-- BUFFS / DEBUFFS
-------------------------------------------------
local function UpdateAuras()
    if not frame then return end
    if not UnitExists(unit) then return end

    local cfg = GetPlayerConfig()
    if not cfg then return end

    local spacing = 2

    -------------------------------------------------
    -- BUFFS
    -------------------------------------------------
    local b = cfg.buffs
    if frame.buffFrame and b and b.enabled then
        local container = frame.buffFrame
        container:Show()
        container:ClearAllPoints()
        container:SetPoint(b.anchor or "TOPLEFT", frame, b.anchor or "TOPLEFT", b.x or 0, b.y or 0)
        container.icons = container.icons or {}

        local maxBuffs = b.max or 0
        local perRow   = b.perRow or maxBuffs
        if perRow < 1 then perRow = 1 end
        if perRow > maxBuffs then perRow = maxBuffs end

        for i = 1, maxBuffs do
            local name, icon, count = GetBuffInfo(unit, i)
            local btn = container.icons[i]

            if name then
                if not btn then
                    btn = CreateAuraIcon(container)
                    container.icons[i] = btn
                end

                btn.icon:SetTexture(icon)
                btn.count:SetText("")

                local size = b.size or 24
                btn:SetSize(size, size)

                -- Positionierung mit Zeilen/Spalten
                local idx    = i - 1
                local col    = idx % perRow
                local row    = math.floor(idx / perRow)
                local grow   = b.grow or "RIGHT"
                local x, y   = 0, 0
                local step   = size + spacing

                if grow == "RIGHT" then
                    x = col * step
                    y = -row * step
                elseif grow == "LEFT" then
                    x = -col * step
                    y = -row * step
                elseif grow == "UP" then
                    x = col * step
                    y = row * step
                elseif grow == "DOWN" then
                    x = col * step
                    y = -row * step
                else
                    x = col * step
                    y = -row * step
                end

                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)

                btn:Show()
            elseif btn then
                btn:Hide()
            end
        end
    elseif frame.buffFrame then
        frame.buffFrame:Hide()
    end

    -------------------------------------------------
    -- DEBUFFS
    -------------------------------------------------
    local d = cfg.debuffs
    if frame.debuffFrame and d and d.enabled then
        local container = frame.debuffFrame
        container:Show()
        container:ClearAllPoints()
        container:SetPoint(d.anchor or "TOPLEFT", frame, d.anchor or "TOPLEFT", d.x or 0, d.y or 0)
        container.icons = container.icons or {}

        local maxDebuffs = d.max or 0
        local perRow     = d.perRow or maxDebuffs
        if perRow < 1 then perRow = 1 end
        if perRow > maxDebuffs then perRow = maxDebuffs end

        for i = 1, maxDebuffs do
            local name, icon, count = GetDebuffInfo(unit, i)
            local btn = container.icons[i]

            if name then
                if not btn then
                    btn = CreateAuraIcon(container)
                    container.icons[i] = btn
                end

                btn.icon:SetTexture(icon)
                btn.count:SetText("")

                local size = d.size or 24
                btn:SetSize(size, size)

                local idx    = i - 1
                local col    = idx % perRow
                local row    = math.floor(idx / perRow)
                local grow   = d.grow or "RIGHT"
                local x, y   = 0, 0
                local step   = size + spacing

                if grow == "RIGHT" then
                    x = col * step
                    y = -row * step
                elseif grow == "LEFT" then
                    x = -col * step
                    y = -row * step
                elseif grow == "UP" then
                    x = col * step
                    y = row * step
                elseif grow == "DOWN" then
                    x = col * step
                    y = -row * step
                else
                    x = col * step
                    y = -row * step
                end

                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)

                btn:Show()
            elseif btn then
                btn:Hide()
            end
        end
    elseif frame.debuffFrame then
        frame.debuffFrame:Hide()
    end
end


local function UpdateStateIcons()
    if not frame then return end
    local cfg = GetPlayerConfig()

    -- Combat / Rest: teilen sich typischerweise denselben Bereich
    if frame.combatIcon and frame.restingIcon then
        if not cfg.combatIconEnabled and not cfg.restingIconEnabled then
            frame.combatIcon:Hide()
            frame.restingIcon:Hide()
        else
            local inCombat = UnitAffectingCombat(unit)
            local resting = IsResting and IsResting()

            if inCombat and cfg.combatIconEnabled then
                frame.combatIcon:Show()
                frame.restingIcon:Hide()
            elseif (not inCombat) and resting and cfg.restingIconEnabled then
                frame.combatIcon:Hide()
                frame.restingIcon:Show()
            else
                frame.combatIcon:Hide()
                frame.restingIcon:Hide()
            end
        end
    end

    -- Party-Leader
    if frame.leaderIcon then
        if cfg.leaderIconEnabled and UnitIsGroupLeader(unit) then
            frame.leaderIcon:Show()
        else
            frame.leaderIcon:Hide()
        end
    end

        -- RaidTarget
    if frame.raidIcon then
        if cfg.raidIconEnabled and GetRaidTargetIndex then
            local index = GetRaidTargetIndex(unit)  -- kann secret sein

            -- Wichtig: KEIN "index > 0" oder "index ~= nil"
            if index then
                SetRaidTargetIconTexture(frame.raidIcon, index)
                frame.raidIcon:Show()
            else
                frame.raidIcon:Hide()
            end
        else
            frame.raidIcon:Hide()
        end
    end

end

-------------------------------------------------
-- FRAME-ERSTELLUNG
-------------------------------------------------
local function CreatePlayerEasyFrame()
    if frame then return end

    local cfg = GetPlayerConfig()

    frame = CreateFrame("Button", "AI_Player_EasyFrame", UIParent, "SecureUnitButtonTemplate")
    frame:SetFrameStrata("MEDIUM")

    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    
    -- NEU: Klicks überhaupt annehmen
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- optional, aber sinnvoll: kompletter Frame klickbar
    frame:SetHitRectInsets(0, 0, 0, 0)
    
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        local c = GetPlayerConfig()
        if c.movable then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        M.StoreCurrentPosition()
    end)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)
    frame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.8)
    
    -- Hintergrund etwas einrücken, damit er nicht hinter den runden Ecken „rausguckt“
    frame.bg:ClearAllPoints()
    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    
    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetAllPoints()

    -- neutrales Start-Backdrop, Stil wird in ApplyFrameLayout gesetzt
    frame.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8", -- einfacher Pixelrahmen als Basis
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame.border:SetBackdropBorderColor(1, 1, 1, 1)
    frame.border:Hide()

    -- frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    -- frame.border:SetAllPoints()

    -- frame.border:SetBackdrop({
    --     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    --     edgeSize = 12,  -- Startwert, wird später über Config überschrieben
    --     insets  = { left = 4, right = 4, top = 4, bottom = 4 },
    -- })
    -- frame.border:SetBackdropBorderColor(1, 1, 1, 1)

    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBarBG = frame.healthBar:CreateTexture(nil, "BACKGROUND")
    frame.healthBarBG:SetAllPoints()
    frame.healthBarBG:SetColorTexture(0, 0, 0, 0.7)

    -- Low-HP-Overlay (rote Tönung über der HP-Bar)
    frame.lowHPOverlay = frame.healthBar:CreateTexture(nil, "ARTWORK")
    frame.lowHPOverlay:SetAllPoints(frame.healthBar)
    frame.lowHPOverlay:SetColorTexture(1, 0, 0, 0.30)
    frame.lowHPOverlay:Hide()

    frame.powerBar = CreateFrame("StatusBar", nil, frame)


    -- Overlay für Dead/Ghost: dunkler Schleier über der HP-Bar
    frame.deadOverlay = frame.healthBar:CreateTexture(nil, "OVERLAY")
    frame.deadOverlay:SetAllPoints(frame.healthBar)
    frame.deadOverlay:SetColorTexture(0, 0, 0, 0.55) -- leicht abdunkeln
    frame.deadOverlay:Hide()

    -- Absorb-Bar (Shields) – dunkler Overlay von rechts nach links
    frame.absorbBar = CreateFrame("StatusBar", nil, frame.healthBar)
    frame.absorbBar:SetAllPoints(frame.healthBar)
    frame.absorbBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    frame.absorbBar:SetStatusBarColor(0, 0, 0, 0.6)
    frame.absorbBar:SetMinMaxValues(0, 1)
    frame.absorbBar:SetValue(0)
    frame.absorbBar:SetReverseFill(true)  -- von rechts nach links
    frame.absorbBar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 1)

    -- HealAbsorb-Bar – ebenfalls von rechts nach links, mit Textur
    frame.healAbsorbBar = CreateFrame("StatusBar", nil, frame.healthBar)
    frame.healAbsorbBar:SetAllPoints(frame.healthBar)
    frame.healAbsorbBar:SetStatusBarTexture("Interface\\RAIDFRAME\\Shield-Overlay")
    frame.healAbsorbBar:SetStatusBarColor(1, 0.8, 0.0, 0.8)
    frame.healAbsorbBar:SetMinMaxValues(0, 1)
    frame.healAbsorbBar:SetValue(0)
    frame.healAbsorbBar:SetReverseFill(true)  -- von rechts nach links
    frame.healAbsorbBar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 2)

    frame.powerBar = CreateFrame("StatusBar", nil, frame)
    frame.powerBarBG = frame.powerBar:CreateTexture(nil, "BACKGROUND")
    frame.powerBarBG:SetAllPoints()
    frame.powerBarBG:SetColorTexture(0, 0, 0, 0.7)

    frame.textFrame = CreateFrame("Frame", nil, frame)
    frame.textFrame:SetAllPoints()

    frame.nameText   = frame.textFrame:CreateFontString(nil, "OVERLAY")
    frame.healthText = frame.textFrame:CreateFontString(nil, "OVERLAY")
    frame.powerText  = frame.textFrame:CreateFontString(nil, "OVERLAY")
    frame.levelText  = frame.textFrame:CreateFontString(nil, "OVERLAY")

    frame.nameText:SetJustifyH("LEFT")
    frame.healthText:SetJustifyH("RIGHT")
    frame.powerText:SetJustifyH("RIGHT")
    frame.levelText:SetJustifyH("CENTER")

    -- Icon-Frame (damit wir Icons getrennt vom Text frameleveln können)
    frame.iconFrame = CreateFrame("Frame", nil, frame)
    frame.iconFrame:SetAllPoints()

    -- Combat-Icon (Benutzt UI-StateIcon – Standard WoW-Grafik)
    frame.combatIcon = frame.iconFrame:CreateTexture(nil, "OVERLAY")
    frame.combatIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    -- Combat-Quadrant: oben rechts
    frame.combatIcon:SetTexCoord(0.5, 1.0, 0.0, 0.5)
    frame.combatIcon:Hide()

    -- Resting-Icon (ebenfalls UI-StateIcon, anderer Quadrant)
    frame.restingIcon = frame.iconFrame:CreateTexture(nil, "OVERLAY")
    frame.restingIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    -- Resting-Quadrant: unten links
    frame.restingIcon:SetTexCoord(0.0, 0.5, 0.5, 1.0)
    frame.restingIcon:Hide()

    -- Party-Leader-Icon
    frame.leaderIcon = frame.iconFrame:CreateTexture(nil, "OVERLAY")
    frame.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    frame.leaderIcon:Hide()

    -- RaidTarget-Icon
    frame.raidIcon = frame.iconFrame:CreateTexture(nil, "OVERLAY")
    frame.raidIcon:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
    frame.raidIcon:Hide()

    -- Buff-Container
    frame.buffFrame = CreateFrame("Frame", "AI_Player_BuffFrame", frame)
    frame.buffFrame:SetSize(1, 1)
    frame.buffFrame.icons = {}

    -- Debuff-Container
    frame.debuffFrame = CreateFrame("Frame", "AI_Player_DebuffFrame", frame)
    frame.debuffFrame:SetSize(1, 1)
    frame.debuffFrame.icons = {}

    -- Startposition
    frame:SetPoint("CENTER", UIParent, "CENTER", cfg.x or -300, cfg.y or -200)

    ApplyFrameLayout()
    ApplyBarStyle()
    UpdateHealthAndPower()

    frame:Hide()
end

-------------------------------------------------
-- EVENTS
-------------------------------------------------
local function OnEvent(self, event, arg1)
    local cfg = GetPlayerConfig()
    if not cfg.enabled then
        if frame then frame:Hide() end
        RestoreBlizzardPlayer()
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CreatePlayerEasyFrame()
        MakeBlizzardPlayerInvisible()
        ApplyFrameLayout()
        ApplyBarStyle()
        UpdateHealthAndPower()
        if frame then frame:Show() end

    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and arg1 == unit then
        UpdateHealthAndPower()

    elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER") and arg1 == unit then
        UpdateHealthAndPower()

    elseif (event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED") and arg1 == unit then
        UpdateHealthAndPower()

    elseif (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED"
         or event == "PLAYER_UPDATE_RESTING"
         or event == "GROUP_ROSTER_UPDATE"
         or event == "PARTY_LEADER_CHANGED"
         or event == "RAID_TARGET_UPDATE") then
        UpdateStateIcons()
    elseif (event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST") then
        UpdateDeadGhostOverlay()
    elseif event == "UNIT_LEVEL" and arg1 == unit then
        UpdateHealthAndPower()
    elseif event == "UNIT_AURA" and arg1 == unit then
        UpdateAuras()
    end

end

local function EnsureEventFrame()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterUnitEvent("UNIT_HEALTH", unit)
    eventFrame:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    eventFrame:RegisterUnitEvent("UNIT_LEVEL", unit)
    eventFrame:RegisterUnitEvent("UNIT_AURA", unit)

    -- NEU: Absorb-Events
    eventFrame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)
    eventFrame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", unit)
    
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:RegisterEvent("PLAYER_ALIVE")
    eventFrame:RegisterEvent("PLAYER_UNGHOST")

    eventFrame:SetScript("OnEvent", OnEvent)

    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("RAID_TARGET_UPDATE")

end

-------------------------------------------------
-- MODUL-API
-------------------------------------------------
function M.Enable()
    local cfg = GetPlayerConfig()
    if not cfg.enabled then
        M.Disable()
        return
    end

    EnsureEventFrame()
    CreatePlayerEasyFrame()
    MakeBlizzardPlayerInvisible()
    ApplyFrameLayout()
    ApplyBarStyle()
    ApplyIconLayout()
    UpdateHealthAndPower()
    UpdateStateIcons()
    UpdateAuras()
    if frame then frame:Show() end
end

function M.Refresh()
    local cfg = GetPlayerConfig()
    if not cfg.enabled then
        M.Disable()
        return
    end

    EnsureEventFrame()
    CreatePlayerEasyFrame()
    MakeBlizzardPlayerInvisible()
    ApplyFrameLayout()
    ApplyBarStyle()
    ApplyIconLayout()
    UpdateHealthAndPower()
    UpdateStateIcons()
    UpdateAuras()
    if frame then frame:Show() end
end

function M.Disable()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
        eventFrame = nil
    end

    if frame then
        frame:Hide()
    end

    RestoreBlizzardPlayer()
end

function M.StartMovingMode()
    local cfg = GetPlayerConfig()
    cfg.movable = true
    if frame then
        frame:EnableMouse(true)
    end
end

function M.StopMovingMode()
    local cfg = GetPlayerConfig()
    cfg.movable = false
    if frame then
        frame:EnableMouse(true)
        M.StoreCurrentPosition()
    end
end

function M.ApplyLayout()
    if not frame then return end
    ApplyFrameLayout()
    ApplyBarStyle()
    ApplyIconLayout()
    UpdateHealthAndPower()
    UpdateStateIcons()
    UpdateAuras()
end

-------------------------------------------------
-- REGISTRIERUNG BEIM CORE
-------------------------------------------------
if AI and AI.RegisterFrameType then
    AI.RegisterFrameType("player", M)
else
    local temp = CreateFrame("Frame")
    temp:RegisterEvent("ADDON_LOADED")
    temp:SetScript("OnEvent", function(self, event, addon)
        if addon == "Avoid_Interface_Core" and AI and AI.RegisterFrameType then
            AI.RegisterFrameType("player", M)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end
