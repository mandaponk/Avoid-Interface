-- Avoid_Interface_targettarget_EasyFrame.lua
-- EasyFrame für "targettarget" – ersetzt den Blizzard targettargetFrame optisch

local M    = {}
local unit = "targettarget"

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


-- Vorgefertigte Layout-Presets für den targettarget-Frame
local targettarget_PRESETS = {
    ["Standard"] = {
        width  = 260,
        height = 52,

        showName      = true,
        showHPText    = true,
        showMPText    = true,
        showLevelText = true,

        hpTextMode = "BOTH",
        mpTextMode = "BOTH",

        nameSize      = 14,
        hpTextSize    = 12,
        mpTextSize    = 12,
        levelTextSize = 12,

        nameAnchor   = "TOPLEFT",
        nameXOffset  = 4,
        nameYOffset  = -4,

        hpTextAnchor  = "CENTER",
        hpTextXOffset = 0,
        hpTextYOffset = 0,

        mpTextAnchor  = "CENTER",
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

        nameSize   = 12,
        hpTextSize = 11,

        nameAnchor   = "TOPLEFT",
        nameXOffset  = 4,
        nameYOffset  = -2,

        hpTextAnchor  = "BOTTOMRIGHT",
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
    return targettarget_PRESETS
end

-------------------------------------------------
-- CONFIG
-------------------------------------------------
local function GettargettargetConfig()
    AI_Config = AI_Config or {}
    AI_Config.modules = AI_Config.modules or {}

    local entry = AI_Config.modules.targettarget
    if type(entry) == "boolean" then
        entry = { enabled = entry }
        AI_Config.modules.targettarget = entry
    elseif type(entry) ~= "table" then
        entry = { enabled = false }
        AI_Config.modules.targettarget = entry
    end

    if entry.enabled == nil then entry.enabled = false end

    local playerEntry = AI_Config.modules.player

    -- Abmessungen / Position / Ratio / Alpha
    if type(playerEntry) == "table" then
        entry.width  = entry.width  or playerEntry.width  or 260
        entry.height = entry.height or playerEntry.height or 52

        entry.scale = entry.scale or playerEntry.scale or 1

        entry.point = entry.point or playerEntry.point or "TOPLEFT"
        entry.x     = entry.x     or (playerEntry.x or 300)
        entry.y     = entry.y     or (playerEntry.y or -200)

        entry.hpRatio = entry.hpRatio or playerEntry.hpRatio or 0.66
        entry.alpha   = entry.alpha   or playerEntry.alpha   or 1
    else
        entry.width  = entry.width  or 260
        entry.height = entry.height or 52
        entry.scale  = entry.scale  or 1

        entry.point = entry.point or "TOPLEFT"
        entry.x     = entry.x     or 400
        entry.y     = entry.y     or -200

        entry.hpRatio = entry.hpRatio or 0.66
        entry.alpha   = entry.alpha   or 1
    end

    -- HP/Mana aktiv
    if entry.manaEnabled == nil then entry.manaEnabled = true end

    -- Text-Flags
    if type(playerEntry) == "table" then
        -- Nur NUR dann Default setzen, wenn der Wert NIL ist.
        if entry.showName == nil then
            if playerEntry.showName ~= nil then
                entry.showName = playerEntry.showName
            else
                entry.showName = true
            end
        end

        if entry.showHPText == nil then
            if playerEntry.showHPText ~= nil then
                entry.showHPText = playerEntry.showHPText
            else
                entry.showHPText = true
            end
        end

        if entry.showMPText == nil then
            if playerEntry.showMPText ~= nil then
                entry.showMPText = playerEntry.showMPText
            else
                entry.showMPText = true
            end
        end

        if entry.showLevelText == nil then
            if playerEntry.showLevelText ~= nil then
                entry.showLevelText = playerEntry.showLevelText
            else
                entry.showLevelText = true
            end
        end

        entry.nameSize      = entry.nameSize      or playerEntry.nameSize      or 14
        entry.hpTextSize    = entry.hpTextSize    or playerEntry.hpTextSize    or 12
        entry.mpTextSize    = entry.mpTextSize    or playerEntry.mpTextSize    or 12
        entry.levelTextSize = entry.levelTextSize or playerEntry.levelTextSize or 12

        entry.nameAnchor    = entry.nameAnchor    or playerEntry.nameAnchor    or "TOPLEFT"
        entry.hpTextAnchor  = entry.hpTextAnchor  or playerEntry.hpTextAnchor  or "CENTER"
        entry.mpTextAnchor  = entry.mpTextAnchor  or playerEntry.mpTextAnchor  or "CENTER"
        entry.levelAnchor   = entry.levelAnchor   or playerEntry.levelAnchor   or "TOPRIGHT"

    else
        -- Ohne Player-Entry: einfache Defaults, aber FALSE respektieren
        if entry.showName == nil then
            entry.showName = true
        end
        if entry.showHPText == nil then
            entry.showHPText = true
        end
        if entry.showMPText == nil then
            entry.showMPText = true
        end
        if entry.showLevelText == nil then
            entry.showLevelText = true
        end

        entry.nameSize      = entry.nameSize      or 14
        entry.hpTextSize    = entry.hpTextSize    or 12
        entry.mpTextSize    = entry.mpTextSize    or 12
        entry.levelTextSize = entry.levelTextSize or 12

        entry.nameAnchor    = entry.nameAnchor    or "TOPLEFT"
        entry.hpTextAnchor  = entry.hpTextAnchor  or "CENTER"
        entry.mpTextAnchor  = entry.mpTextAnchor  or "CENTER"
        entry.levelAnchor   = entry.levelAnchor   or "TOPRIGHT"
    end


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

    -- HP / Mana Text Mode
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
    if type(playerEntry) == "table" then
        entry.nameTextColor  = entry.nameTextColor  or playerEntry.nameTextColor  or { r = 1, g = 1, b = 1 }
        entry.hpTextColor    = entry.hpTextColor    or playerEntry.hpTextColor    or { r = 1, g = 1, b = 1 }
        entry.mpTextColor    = entry.mpTextColor    or playerEntry.mpTextColor    or { r = 1, g = 1, b = 1 }
        entry.levelTextColor = entry.levelTextColor or playerEntry.levelTextColor or { r = 1, g = 1, b = 1 }
    else
        entry.nameTextColor  = entry.nameTextColor  or { r = 1, g = 1, b = 1 }
        entry.hpTextColor    = entry.hpTextColor    or { r = 1, g = 1, b = 1 }
        entry.mpTextColor    = entry.mpTextColor    or { r = 1, g = 1, b = 1 }
        entry.levelTextColor = entry.levelTextColor or { r = 1, g = 1, b = 1 }
    end
    -- Icon-Defaults (Combat / Rest / Leader / Raid)
    if entry.leaderIconEnabled  == nil then entry.leaderIconEnabled  = true  end
    if entry.raidIconEnabled    == nil then entry.raidIconEnabled    = true  end

    entry.leaderIconSize  = entry.leaderIconSize  or 18
    entry.raidIconSize    = entry.raidIconSize    or 20

    entry.leaderIconAnchor  = entry.leaderIconAnchor  or "TOPRIGHT"
    entry.raidIconAnchor    = entry.raidIconAnchor    or "TOP"

    entry.leaderIconXOffset  = entry.leaderIconXOffset  or  4
    entry.leaderIconYOffset  = entry.leaderIconYOffset  or  4
    entry.raidIconXOffset    = entry.raidIconXOffset    or  0
    entry.raidIconYOffset    = entry.raidIconYOffset    or 10

    -- Bar-Texturen / HP-Farbmodus / Custom-Farben
    if type(playerEntry) == "table" then
        entry.hpBarTextureMode = entry.hpBarTextureMode or playerEntry.hpBarTextureMode or "DEFAULT"
        entry.mpBarTextureMode = entry.mpBarTextureMode or playerEntry.mpBarTextureMode or "DEFAULT"
    end
    entry.hpBarTextureMode = entry.hpBarTextureMode or "DEFAULT"
    entry.mpBarTextureMode = entry.mpBarTextureMode or "DEFAULT"

    -- Mapping von Config-Feldern (targettarget_ConfigUI)
    if entry.hpTexture then entry.hpBarTextureMode = entry.hpTexture end
    if entry.mpTexture then entry.mpBarTextureMode = entry.mpTexture end

    if entry.hpColorMode ~= "CLASS" and entry.hpColorMode ~= "DEFAULT" then
        entry.hpColorMode = "DEFAULT"
    end

    if entry.hpUseCustomColor == nil then entry.hpUseCustomColor = false end
    entry.hpCustomColor = entry.hpCustomColor or { r = 0, g = 1, b = 0 }

    if entry.mpUseCustomColor == nil then entry.mpUseCustomColor = false end
    entry.mpCustomColor = entry.mpCustomColor or { r = 0, g = 0, b = 1 }

    -- Raidtargettarget
    if entry.raidIconEnabled == nil then entry.raidIconEnabled = true end

    -- Buff-Defaults (targettarget)
    entry.buffs = entry.buffs or {}
    local b = entry.buffs
    if b.enabled == nil then b.enabled = true end
    b.anchor = b.anchor or "TOPLEFT"
    b.x      = b.x      or 0
    b.y      = b.y      or 10
    b.size   = b.size   or 24
    b.grow   = b.grow   or "RIGHT"
    b.max    = b.max    or 12
    b.perRow = b.perRow or 8

    -- Debuff-Defaults (targettarget)
    entry.debuffs = entry.debuffs or {}
    local d = entry.debuffs
    if d.enabled == nil then d.enabled = true end
    d.anchor = d.anchor or "TOPLEFT"
    d.x      = d.x      or 0
    d.y      = d.y      or -26
    d.size   = d.size   or 24
    d.grow   = d.grow   or "RIGHT"
    d.max    = d.max    or 12
    d.perRow = d.perRow or 8
    -- Rahmen-Defaults
    if entry.borderEnabled == nil then
        entry.borderEnabled = false
    end

    entry.borderSize = entry.borderSize or 1

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


-- global verfügbar für Config
_G.GettargettargetConfig = GettargettargetConfig

function M.ApplyPreset(presetKey)
    local preset = targettarget_PRESETS[presetKey]
    if not preset then return end

    local cfg = GettargettargetConfig()
    ApplyPresetToConfig(cfg, preset)

    if M.ApplyLayout then
        M.ApplyLayout()
    end
end

-------------------------------------------------
-- BLIZZARD targettargetFRAME AN / AUS
-------------------------------------------------
-- local function MakeBlizzardtargettargetInvisible()
--     if not targettargetFrame then return end

--     targettargetFrame:UnregisterAllEvents()
--     targettargetFrame:Hide()
--     targettargetFrame:SetAlpha(0)
--     targettargetFrame:EnableMouse(false)

--     if targettargetFrameTextureFrame then targettargetFrameTextureFrame:Hide() end
--     if targettargetFrame.healthbar then targettargetFrame.healthbar:Hide() end
--     if targettargetFrame.manabar then targettargetFrame.manabar:Hide() end
-- end

-- local function RestoreBlizzardtargettarget()
--     if not targettargetFrame then return end

--     targettargetFrame:SetAlpha(1)
--     targettargetFrame:Show()
--     targettargetFrame:EnableMouse(true)

--     if targettargetFrame.healthbar and targettargetFrame.healthbar.TextString then
--         targettargetFrame.healthbar.TextString:Show()
--     end
--     if targettargetFrame.manabar and targettargetFrame.manabar.TextString then
--         targettargetFrame.manabar.TextString:Show()
--     end
-- end

local function MakeBlizzardtargettargetInvisible()
    if not targettargetFrame then return end

    -- Events NICHT anfassen, nur optisch „unsichtbar“ machen
    targettargetFrame:SetAlpha(0)
    targettargetFrame:EnableMouse(false)
    targettargetFrame:Hide()

    if targettargetFrameTextureFrame then
        targettargetFrameTextureFrame:Hide()
    end
    if targettargetFrame.healthbar then
        targettargetFrame.healthbar:Hide()
        if targettargetFrame.healthbar.TextString then
            targettargetFrame.healthbar.TextString:Hide()
        end
    end
    if targettargetFrame.manabar then
        targettargetFrame.manabar:Hide()
        if targettargetFrame.manabar.TextString then
            targettargetFrame.manabar.TextString:Hide()
        end
    end
end

local function RestoreBlizzardtargettarget()
    if not targettargetFrame then return end

    targettargetFrame:Show()
    targettargetFrame:SetAlpha(1)
    targettargetFrame:EnableMouse(true)

    if targettargetFrameTextureFrame then
        targettargetFrameTextureFrame:Show()
    end

    if targettargetFrame.healthbar then
        targettargetFrame.healthbar:Show()
        if targettargetFrame.healthbar.TextString then
            targettargetFrame.healthbar.TextString:Show()
        end
    end

    if targettargetFrame.manabar then
        targettargetFrame.manabar:Show()
        if targettargetFrame.manabar.TextString then
            targettargetFrame.manabar.TextString:Show()
        end
    end
end

-------------------------------------------------
-- TEXTLAYOUT
-------------------------------------------------
local function ApplyTextLayout(fs, show, size, anchor, xOff, yOff, bold, shadow, color)
    if not fs then return end

    local baseFont = STANDARD_TEXT_FONT
        or (GameFontNormal and select(1, GameFontNormal:GetFont()))
        or "Fonts\\FRIZQT__.TTF"

    local flags = bold and "OUTLINE" or ""

    fs:SetFont(baseFont, size or 12, flags)

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

    if not show then
        fs:SetText("")
        fs:Hide()
        return
    end

    fs:Show()
    fs:ClearAllPoints()

    anchor = anchor or "CENTER"
    fs:SetPoint(anchor, frame, anchor, xOff or 0, yOff or 0)
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

    local cfg = GettargettargetConfig()

    frame:ClearAllPoints()
    frame:SetScale(cfg.scale or 1)
    frame:SetPoint(cfg.point or "TOPLEFT", UIParent, cfg.point or "TOPLEFT", cfg.x or 400, cfg.y or -200)
    frame:SetSize(cfg.width or 260, cfg.height or 52)
    frame:SetAlpha(cfg.alpha or 1)

    local w = cfg.width  or 260
    local h = cfg.height or 52

    local hpRatio = cfg.hpRatio or 0.66
    if hpRatio < 0.1 then hpRatio = 0.1 end
    if hpRatio > 0.9 then hpRatio = 0.9 end

    local margin  = 2      -- oben/unten
    local spacing = cfg.manaEnabled and 2 or 0
    local innerH  = math.max(1, h - 2 * margin)

    local hpH, manaH
    if cfg.manaEnabled then
        hpH   = math.floor(innerH * hpRatio + 0.5)
        manaH = math.max(1, innerH - hpH - spacing)
    else
        hpH   = innerH
        manaH = 0
    end

    -- optional in Config zurückschreiben
    cfg.hpBarHeight   = hpH
    cfg.manaBarHeight = manaH

    -- Hintergrund-Frame
    if not frame.bg then
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    end
    frame.bg:ClearAllPoints()
    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.bg:SetColorTexture(0, 0, 0, 0.7)

    -- HP-Bar
    if not frame.healthBar then
        frame.healthBar = CreateFrame("StatusBar", nil, frame)
    end
    frame.healthBar:ClearAllPoints()
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", margin, -margin)
    frame.healthBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -margin, -margin)
    frame.healthBar:SetHeight(hpH)

    -- Mana-Bar
    if not frame.powerBar then
        frame.powerBar = CreateFrame("StatusBar", nil, frame)
    end
    frame.powerBar:ClearAllPoints()
    frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, cfg.manaEnabled and -spacing or 0)
    frame.powerBar:SetPoint("TOPRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, cfg.manaEnabled and -spacing or 0)
    frame.powerBar:SetHeight(math.max(1, manaH))

    -- BG-Bars
    if not frame.healthBarBG then
        frame.healthBarBG = frame:CreateTexture(nil, "BACKGROUND")
    end
    frame.healthBarBG:ClearAllPoints()
    frame.healthBarBG:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 0, 0)
    frame.healthBarBG:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, 0)

    if not frame.powerBarBG then
        frame.powerBarBG = frame:CreateTexture(nil, "BACKGROUND")
    end
    frame.powerBarBG:ClearAllPoints()
    frame.powerBarBG:SetPoint("TOPLEFT", frame.powerBar, "TOPLEFT", 0, 0)
    frame.powerBarBG:SetPoint("BOTTOMRIGHT", frame.powerBar, "BOTTOMRIGHT", 0, 0)

    -- Text-Frame
    if not frame.textFrame then
        frame.textFrame = CreateFrame("Frame", nil, frame)
    end
    frame.textFrame:SetAllPoints(frame)

    if not frame.nameText then
        frame.nameText = frame.textFrame:CreateFontString(nil, "OVERLAY")
    end
    if not frame.healthText then
        frame.healthText = frame.textFrame:CreateFontString(nil, "OVERLAY")
    end
    if not frame.powerText then
        frame.powerText = frame.textFrame:CreateFontString(nil, "OVERLAY")
    end
    if not frame.levelText then
        frame.levelText = frame.textFrame:CreateFontString(nil, "OVERLAY")
    end
    -- Border-Frame einmalig erzeugen
    if not frame.border then
        frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.border:SetAllPoints()
    end

    -- Layering
    local baseLevel = frame:GetFrameLevel() or 1

    frame.healthBar:SetFrameLevel(baseLevel + 1)
    frame.powerBar:SetFrameLevel(baseLevel + 1)

    if frame.bg then
        frame.bg:SetDrawLayer("BACKGROUND", 0)
    end

    if frame.border then
        frame.border:SetFrameLevel(baseLevel + 2)
    end

    if frame.textFrame then
        frame.textFrame:SetFrameLevel(baseLevel + 3)
    end

    -- Rahmen anwenden (Pixel vs Tooltip)
    if frame.border then
        if cfg.borderEnabled and cfg.borderSize and cfg.borderSize > 0 then
            local size = cfg.borderSize
            if size < 1  then size = 1  end
            if size > 16 then size = 16 end

            local style = cfg.borderStyle or "PIXEL"

            -- frisches Backdrop bauen
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
                    -- Pixelframe: fast bis an den Rand
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

     local e = cfg

    -- endgültige Textfarben je nach Classcolor-Flag bestimmen
    local nameColor  = GetTextColorForElement(e.nameTextColor,  e.nameTextUseClassColor)
    local hpColor    = GetTextColorForElement(e.hpTextColor,    e.hpTextUseClassColor)
    local mpColor    = GetTextColorForElement(e.mpTextColor,    e.mpTextUseClassColor)
    local levelColor = GetTextColorForElement(e.levelTextColor, e.levelTextUseClassColor)

    -- Name
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

    -- HP-Text
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

    -- Mana-Text
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

    -- Level-Text
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

-------------------------------------------------
-- ICON-LAYOUT
-------------------------------------------------
local function ApplyIconLayout()
    if not frame then return end

    local cfg = GettargettargetConfig()
    if not cfg then return end

    if not frame.iconFrame then
        frame.iconFrame = CreateFrame("Frame", nil, frame)
        frame.iconFrame:SetAllPoints(frame)
    end

    -- Icons über den Texten
    local baseLevel = frame:GetFrameLevel() or 1
    local textLevel = frame.textFrame and frame.textFrame:GetFrameLevel() or (baseLevel + 3)
    frame.iconFrame:SetFrameLevel(textLevel + 1)

    local function placeIcon(icon, enabled, size, anchor, x, y)
        if not icon then return end

        icon:ClearAllPoints()

        if not enabled then
            icon:Hide()
            return
        end

        size   = size   or 24
        anchor = anchor or "TOP"
        x      = x      or 0
        y      = y      or 0

        icon:SetSize(size, size)
        icon:SetPoint(anchor, frame, anchor, x, y)
    end

    placeIcon(
        frame.leaderIcon,
        cfg.leaderIconEnabled,
        cfg.leaderIconSize,
        cfg.leaderIconAnchor,
        cfg.leaderIconXOffset,
        cfg.leaderIconYOffset
    )

    placeIcon(
        frame.raidIcon,
        cfg.raidIconEnabled,
        cfg.raidIconSize,
        cfg.raidIconAnchor,
        cfg.raidIconXOffset,
        cfg.raidIconYOffset
    )
end

-------------------------------------------------
-- BAR-STYLE
-------------------------------------------------
local function ApplyBarStyle()
    if not frame then return end

    local cfg = GettargettargetConfig()

    local hpTexKey = cfg.hpBarTextureMode or cfg.barTextureMode or "DEFAULT"
    local mpTexKey = cfg.mpBarTextureMode or cfg.barTextureMode or "DEFAULT"

    local hpTexPath = BAR_TEXTURES[hpTexKey] or BAR_TEXTURES.DEFAULT
    local mpTexPath = BAR_TEXTURES[mpTexKey] or BAR_TEXTURES.DEFAULT

    frame.healthBar:SetStatusBarTexture(hpTexPath)
    frame.powerBar:SetStatusBarTexture(mpTexPath)

    -- HP-Farbe: Klassenfarbe / Custom / Friend/Foe
    local hr, hg, hb = 0, 0.8, 0

    if cfg.hpColorMode == "CLASS" and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            hr, hg, hb = c.r, c.g, c.b
        end
    elseif cfg.hpUseCustomColor and cfg.hpCustomColor then
        hr = cfg.hpCustomColor.r or 0
        hg = cfg.hpCustomColor.g or 1
        hb = cfg.hpCustomColor.b or 0
    else
        -- Friend/Foe-Farbe
        if UnitIsDead(unit) or UnitIsGhost(unit) then
            hr, hg, hb = 0.5, 0.5, 0.5
        else
            if UnitIsFriend("player", unit) then
                hr, hg, hb = 0, 0.9, 0
            elseif UnitIsEnemy("player", unit) then
                hr, hg, hb = 0.9, 0.1, 0.1
            else
                hr, hg, hb = 0.8, 0.8, 0.1
            end
        end
    end

    frame.healthBar:SetStatusBarColor(hr, hg, hb, 1)

    -- Power-Farbe via PowerBarColor oder Custom
    local pType = UnitPowerType(unit)
    local pr, pg, pb

    if cfg.mpUseCustomColor and cfg.mpCustomColor then
        pr = cfg.mpCustomColor.r or 0
        pg = cfg.mpCustomColor.g or 0
        pb = cfg.mpCustomColor.b or 1
    else
        local info = PowerBarColor and PowerBarColor[pType] or PowerBarColor and PowerBarColor["MANA"]
        pr, pg, pb = 0, 0, 1
        if info then
            pr, pg, pb = info.r, info.g, info.b
        end
    end

    frame.powerBar:SetStatusBarColor(pr, pg, pb, 1)

    -- BG-Farben abhängig vom Frame-Hintergrundmodus
    local mode  = cfg.frameBgMode or "OFF"
    local alpha = cfg.alpha or 1

    if mode == "CLASS" then
        -- Rahmen / Gesamt-Background in Klassen-/HP-Farbe, Bars innen neutral
        if frame.bg then
            -- etwas abgedunkelte HP-Farbe für den Rahmen-Hintergrund
            frame.bg:SetColorTexture(hr * 0.35, hg * 0.35, hb * 0.35, 0.9 * alpha)
        end

        if frame.healthBarBG then
            frame.healthBarBG:SetColorTexture(0, 0, 0, 0.6)
        end
        if frame.powerBarBG then
            frame.powerBarBG:SetColorTexture(0, 0, 0, 0.6)
        end

    elseif mode == "CLASSPOWER" then
        -- Neutraler Rahmen, HP/MP-Bereich eingefärbt nach HP- bzw. Power-Farbe
        if frame.bg then
            frame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.8 * alpha)
        end

        if frame.healthBarBG then
            frame.healthBarBG:SetColorTexture(hr * 0.2, hg * 0.2, hb * 0.2, 0.8)
        end
        if frame.powerBarBG then
            frame.powerBarBG:SetColorTexture(pr * 0.2, pg * 0.2, pb * 0.2, 0.8)
        end

    else
        -- "OFF" / neutral: alles dezent dunkel
        if frame.bg then
            frame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.8 * alpha)
        end

        if frame.healthBarBG then
            frame.healthBarBG:SetColorTexture(0, 0, 0, 0.6)
        end
        if frame.powerBarBG then
            frame.powerBarBG:SetColorTexture(0, 0, 0, 0.6)
        end
    end
end

-------------------------------------------------
-- TEXTFORMAT HP / MANA
-------------------------------------------------
local function FormatHPText(unit, mode, hp, hpMax)
    -- Midnight: hpMax kann ein "secret value" sein.
    -- Wir prüfen nur auf nil, NICHT auf <= 0 o.ä.
    if not hp or not hpMax then
        return ""
    end

    local cfg = GettargettargetConfig()
    local effectiveMode = (cfg and cfg.hpTextMode) or mode or "BOTH"

    if effectiveMode ~= "PERCENT" and effectiveMode ~= "BOTH" then
        effectiveMode = "BOTH"
    end

    local hpStr  = tostring(hp)
    local maxStr = tostring(hpMax)
    if AbbreviateLargeNumbers then
        hpStr  = AbbreviateLargeNumbers(hp)
        maxStr = AbbreviateLargeNumbers(hpMax)
    end

    local pct = UnitHealthPercent and UnitHealthPercent(unit, false, true)

    if effectiveMode == "PERCENT" then
        if pct ~= nil then
            return string.format("%d%%", pct)
        else
            return hpStr
        end
    end

    return string.format("%s / %s", hpStr, maxStr)
end


local function FormatPowerText(unit, mode, pType, p, pMax)
    -- pMax kann ebenfalls "secret" sein → nur nil prüfen
    if not p or not pMax then
        return ""
    end

    local cfg = GettargettargetConfig()
    local effectiveMode = (cfg and cfg.mpTextMode) or mode or "BOTH"

    if effectiveMode ~= "PERCENT" and effectiveMode ~= "BOTH" then
        effectiveMode = "BOTH"
    end

    local pStr   = tostring(p)
    local maxStr = tostring(pMax)
    if AbbreviateLargeNumbers then
        pStr   = AbbreviateLargeNumbers(p)
        maxStr = AbbreviateLargeNumbers(pMax)
    end

    if effectiveMode == "PERCENT" then
        local pct = UnitPowerPercent and UnitPowerPercent(unit, pType, false, true)
        if pct ~= nil then
            return string.format("%d%%", pct)
        else
            return pStr
        end
    end

    return string.format("%s / %s", pStr, maxStr)
end


-------------------------------------------------
-- ICON-STATUS (Leader / Combat / Rest / Raid)
-------------------------------------------------
local function UpdateStateIcons()
    if not frame then return end

    local cfg = GettargettargetConfig()
    if not cfg or not UnitExists(unit) then
        if frame.leaderIcon  then frame.leaderIcon:Hide()  end
        if frame.raidIcon    then frame.raidIcon:Hide()    end
        return
    end

    -- Party/Raid-Leader-Icon
    if frame.leaderIcon then
        local isLeader = UnitIsGroupLeader and UnitIsGroupLeader(unit)
        if cfg.leaderIconEnabled and isLeader then
            frame.leaderIcon:Show()
        else
            frame.leaderIcon:Hide()
        end
    end

    -- Raidtargettarget-Icon
    if frame.raidIcon then
        if cfg.raidIconEnabled and GetRaidTargetIndex and SetRaidTargetIconTexture then
            local index = GetRaidTargetIndex(unit)
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

local function UpdateHealthAndPower()
    if not frame then return end

    if not UnitExists(unit) then
        -- Sichtbarkeit macht jetzt RegisterUnitWatch
        return
    end

    local cfg = GettargettargetConfig()

    -- HP (Midnight: hpMax kann "secret value" sein → nur auf nil prüfen)
    local hp    = UnitHealth(unit)
    local hpMax = UnitHealthMax(unit)

    if hpMax then
        frame.healthBar:SetMinMaxValues(0, hpMax)
    else
        frame.healthBar:SetMinMaxValues(0, 1)
    end

    frame.healthBar:SetValue(hp or 0)

    -- Power
    local pType    = UnitPowerType(unit)
    local power    = UnitPower(unit, pType)
    local powerMax = UnitPowerMax(unit, pType)

    if cfg.manaEnabled and powerMax then
        frame.powerBar:SetMinMaxValues(0, powerMax)
        frame.powerBar:SetValue(power or 0)
        frame.powerBar:Show()
        if frame.powerBarBG then frame.powerBarBG:Show() end
    else
        frame.powerBar:SetMinMaxValues(0, 1)
        frame.powerBar:SetValue(0)
        frame.powerBar:Hide()
        if frame.powerBarBG then frame.powerBarBG:Hide() end
    end

    -- Name
    if cfg.showName and frame.nameText then
        frame.nameText:SetText(UnitName(unit) or "")
    end

    -- HP-Text
    if cfg.showHPText and frame.healthText then
        local hpText = FormatHPText(unit, cfg.hpTextMode, hp, hpMax)
        frame.healthText:SetText(hpText or "")
    end

    -- Mana-Text
    if cfg.showMPText and frame.powerText then
        local powerText = FormatPowerText(unit, cfg.mpTextMode, pType, power, powerMax)
        frame.powerText:SetText(powerText or "")
    end

    -- Level
    if cfg.showLevelText and frame.levelText then
        local level = UnitLevel(unit) or ""
        frame.levelText:SetText(level ~= "" and level or "")
    end
end


-------------------------------------------------
-- BUFFS / DEBUFFS (targettarget)
-------------------------------------------------
local function UpdateAuras()
    if not frame then return end
    if not UnitExists(unit) then return end

    local cfg = GettargettargetConfig()
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


local function UpdateAll()
    if not frame then return end
    ApplyFrameLayout()
    ApplyBarStyle()
    UpdateHealthAndPower()
    UpdateStateIcons()
    UpdateAuras()
end

-------------------------------------------------
-- FRAME ERZEUGEN
-------------------------------------------------
local function CreatetargettargetEasyFrame()
    if frame then return end

    local cfg = GettargettargetConfig()

    frame = CreateFrame("Button", "AI_targettarget_EasyFrame", UIParent, "SecureUnitButtonTemplate")
    frame:SetFrameStrata("MEDIUM")

    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "targettarget")
    frame:SetAttribute("*type2", "togglemenu")

    frame:SetMovable(false)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetHitRectInsets(0, 0, 0, 0)

    -- Startposition
    if targettargetFrame then
        frame:SetPoint("TOPLEFT", targettargetFrame, "TOPLEFT", 0, 0)
    else
        frame:SetPoint(cfg.point or "TOPLEFT", UIParent, cfg.point or "TOPLEFT", cfg.x or 400, cfg.y or -200)
    end

    -- Icon-Container
    frame.iconFrame = CreateFrame("Frame", nil, frame)
    frame.iconFrame:SetAllPoints(frame)

    -- Leader-Icon
    frame.leaderIcon = frame.iconFrame:CreateTexture(nil, "OVERLAY")
    frame.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    frame.leaderIcon:Hide()

    -- RaidTarget-Icon
    frame.raidIcon = frame.iconFrame:CreateTexture(nil, "OVERLAY")
    frame.raidIcon:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
    frame.raidIcon:Hide()


    -- Buff-Container
    frame.buffFrame = CreateFrame("Frame", "AI_targettarget_BuffFrame", frame)
    frame.buffFrame:SetSize(1, 1)
    frame.buffFrame.icons = {}

    -- Debuff-Container
    frame.debuffFrame = CreateFrame("Frame", "AI_targettarget_DebuffFrame", frame)
    frame.debuffFrame:SetSize(1, 1)
    frame.debuffFrame.icons = {}

    ApplyFrameLayout()
    ApplyBarStyle()
    ApplyIconLayout()
    UpdateHealthAndPower()
    UpdateStateIcons()
    UpdateAuras()

end


-------------------------------------------------
-- MOVE-MODUS API (für Config-UI)
-------------------------------------------------
function M.StartMovingMode()
    if InCombatLockdown and InCombatLockdown() then
        -- in Combat: nicht verschieben
        return
    end

    if not frame then
        CreatetargettargetEasyFrame()
    end
    if not frame then return end

    local cfg = GettargettargetConfig()

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        cfg.point = p
        cfg.x     = x
        cfg.y     = y
    end)

    -- Safety: Sichtbarkeit 1x pro Frame prüfen
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not UnitExists(unit) then
            self:Hide()
        else
            self:Show()
        end
    end)
end

function M.StopMovingMode()
    if not frame then return end

    frame:StopMovingOrSizing()
    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetMovable(false)
end

function M.ResetPosition()
    local cfg = GettargettargetConfig()

    -- Standard-Position (kannst du nach Wunsch anpassen)
    cfg.point = "TOPLEFT"
    cfg.x     = 400
    cfg.y     = -200

    if frame then
        ApplyFrameLayout()
        UpdateAll()
    end
end

-------------------------------------------------
-- VISIBILITY HELPER
-------------------------------------------------
local function UpdateVisibility()
    if not frame then return end

    if UnitExists(unit) then
        frame:Show()
    else
        frame:Hide()
    end
end

-------------------------------------------------
-- EVENTS
-------------------------------------------------
local function OnEvent(self, event, arg1)
    local cfg = GettargettargetConfig()
    if not cfg.enabled then
        if frame then frame:Hide() end
        RestoreBlizzardtargettarget()
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CreatetargettargetEasyFrame()
        MakeBlizzardtargettargetInvisible()

        -- Sichtbarkeit anhand aktuellen Targets setzen
        UpdateVisibility()

        -- Wenn schon ein Target existiert (z.B. nach ReloadUI), alles updaten
        if UnitExists(unit) then
            UpdateAll()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
    if UnitExists(unit) then
        if not frame then
            CreatetargettargetEasyFrame()
        end
        UpdateAll()
    end
    -- Kein eigenes Show/Hide mehr.
    -- RegisterUnitWatch regelt die Sichtbarkeit (auch im Kampf, bei Tod usw.)


    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if arg1 == unit then
            UpdateHealthAndPower()
        end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        if arg1 == unit then
            UpdateHealthAndPower()
        end

    elseif event == "UNIT_AURA" then
        if arg1 == unit then
            UpdateAuras()
        end

    elseif event == "RAID_TARGET_UPDATE" then
        UpdateStateIcons()

    elseif event == "UNIT_FLAGS" then
        if arg1 == unit and UnitExists(unit) then
            UpdateStateIcons()
        end
    end
end


local function EnsureEventFrame()
    if eventFrame then return end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterUnitEvent("UNIT_FLAGS", unit)

    eventFrame:RegisterUnitEvent("UNIT_HEALTH",        unit)
    eventFrame:RegisterUnitEvent("UNIT_MAXHEALTH",     unit)
    eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE",  unit)
    eventFrame:RegisterUnitEvent("UNIT_MAXPOWER",      unit)
    eventFrame:RegisterUnitEvent("UNIT_AURA",          unit)

    eventFrame:SetScript("OnEvent", OnEvent)
end

-------------------------------------------------
-- API
-------------------------------------------------
function M.Enable()
    EnsureEventFrame()
    CreatetargettargetEasyFrame()
    MakeBlizzardtargettargetInvisible()

    if not frame then return end

    -- WICHTIG: jedes Mal, wenn das Modul aktiviert wird,
    -- wieder beim UnitWatch anmelden
    if RegisterUnitWatch then
        RegisterUnitWatch(frame)
    end

    if UnitExists(unit) then
        -- Es gibt bereits ein Target → sofort anzeigen + updaten
        frame:Show()
        UpdateAll()
    else
        -- Kein Target → Frame verstecken, wartet auf PLAYER_TARGET_CHANGED
        frame:Hide()
    end
end


function M.Disable()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
        eventFrame = nil
    end

    if frame then
        if UnregisterUnitWatch then
            UnregisterUnitWatch(frame)
        end
        frame:Hide()
    end

    RestoreBlizzardtargettarget()
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
    AI.RegisterFrameType("targettarget", M)
else
    local temp = CreateFrame("Frame")
    temp:RegisterEvent("ADDON_LOADED")
    temp:SetScript("OnEvent", function(self, event, addon)
        if addon == "Avoid_Interface_Core" and AI and AI.RegisterFrameType then
            AI.RegisterFrameType("targettarget", M)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end
