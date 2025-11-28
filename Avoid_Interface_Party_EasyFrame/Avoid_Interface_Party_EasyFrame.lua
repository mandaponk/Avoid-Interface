-- Avoid_Interface_Party_EasyFrame.lua
-- EasyFrame für Party-Mitglieder (party1-4), an den Player-EasyFrame angelehnt

local addonName, ns = ...

AI        = AI or {}
AI.modules = AI.modules or {}
AI_Config = AI_Config or {}

local M = {}
AI.modules.party = M

-------------------------------------------------
-- Konstanten / Tabellen
-------------------------------------------------

local PARTY_UNITS = { "party1", "party2", "party3", "party4" }
local PARTY_UNIT_LOOKUP = {
    party1 = true,
    party2 = true,
    party3 = true,
    party4 = true,
}

local BAR_TEXTURES = {
    DEFAULT = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    RAID    = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    FLAT    = "Interface\\Buttons\\WHITE8x8",

    -- neue Keys müssen zu texItems.value passen:
    SMOOTH  = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill",
    GLASS   = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",

    -- NEU: Absorb-Overlay (weißer Balken)
    ABSORB  = "Interface\\Buttons\\WHITE8x8",
}

local PARTY_PRESETS = {
    ["Default"] = {
        width       = 220,
        height      = 60,
        hpRatio     = 0.66,
        alpha       = 1.0,
        manaEnabled = true,

        frameBgMode = "OFF",    -- OFF, CLASS, CLASSPOWER

        hpColorMode     = "CLASS",    -- CLASS oder DEFAULT
        hpTexture       = "DEFAULT",
        mpTexture       = "DEFAULT",
        hpTextMode      = "BOTH",     -- BOTH oder PERCENT
        mpTextMode      = "BOTH",

        borderEnabled   = true,
        borderStyle     = "PIXEL",    -- PIXEL, THIN, THICK, TOOLTIP, DIALOG
        borderSize      = 1,
    },

    ["Compact"] = {
        width       = 180,
        height      = 44,
        hpRatio     = 0.6,
        alpha       = 1.0,
        manaEnabled = true,

        frameBgMode = "CLASS",

        hpColorMode     = "CLASS",
        hpTexture       = "RAID",
        mpTexture       = "FLAT",
        hpTextMode      = "PERCENT",
        mpTextMode      = "PERCENT",

        borderEnabled   = true,
        borderStyle     = "TOOLTIP",
        borderSize      = 1,
    },

    ["Healer"] = {
        width       = 240,
        height      = 52,
        hpRatio     = 0.7,
        alpha       = 1.0,
        manaEnabled = true,

        frameBgMode = "CLASSPOWER",

        hpColorMode     = "CLASS",
        hpTexture       = "SMOOTH",
        mpTexture       = "SMOOTH",
        hpTextMode      = "BOTH",
        mpTextMode      = "BOTH",

        borderEnabled   = true,
        borderStyle     = "PIXEL",
        borderSize      = 1,
    },
}

-------------------------------------------------
-- SavedVariables / Config
-------------------------------------------------

local function GetPartyConfig()
    AI_Config = AI_Config or {}
    AI_Config.modules = AI_Config.modules or {}

    local cfg = AI_Config.modules.party
    if type(cfg) ~= "table" then
        cfg = {}
        AI_Config.modules.party = cfg
    end

    if cfg.enabled == nil then
        cfg.enabled = true
    end

    -- Grundgröße / Layout
    cfg.width       = cfg.width       or 220
    cfg.height      = cfg.height      or 60
    cfg.hpRatio     = cfg.hpRatio     or 0.66
    cfg.alpha       = cfg.alpha       or 1.0
    cfg.manaEnabled = (cfg.manaEnabled ~= false)

    -- Frame-Hintergrund
    if cfg.frameBgMode ~= "OFF" and cfg.frameBgMode ~= "CLASS" and cfg.frameBgMode ~= "CLASSPOWER" then
        cfg.frameBgMode = "OFF"
    end

    -- Bar-Farben / Texturen
    cfg.hpColorMode = cfg.hpColorMode or "CLASS"   -- CLASS oder DEFAULT
    cfg.hpTexture   = cfg.hpTexture   or "DEFAULT"
    cfg.mpTexture   = cfg.mpTexture   or "DEFAULT"

    if cfg.hpTextMode ~= "PERCENT" and cfg.hpTextMode ~= "BOTH" then
        cfg.hpTextMode = "BOTH"
    end
    if cfg.mpTextMode ~= "PERCENT" and cfg.mpTextMode ~= "BOTH" then
        cfg.mpTextMode = "BOTH"
    end

    if cfg.hpUseCustomColor == nil then cfg.hpUseCustomColor = false end
    cfg.hpCustomColor = cfg.hpCustomColor or { r = 0, g = 1, b = 0 }

    if cfg.mpUseCustomColor == nil then cfg.mpUseCustomColor = false end
    cfg.mpCustomColor = cfg.mpCustomColor or { r = 0, g = 0, b = 1 }

    -- Textfarben
    cfg.nameTextColor  = cfg.nameTextColor  or { r = 1, g = 1, b = 1 }
    cfg.hpTextColor    = cfg.hpTextColor    or { r = 1, g = 1, b = 1 }
    cfg.mpTextColor    = cfg.mpTextColor    or { r = 1, g = 1, b = 1 }
    cfg.levelTextColor = cfg.levelTextColor or { r = 1, g = 1, b = 1 }

    cfg.nameTextUseClassColor  = cfg.nameTextUseClassColor  or false
    cfg.hpTextUseClassColor    = cfg.hpTextUseClassColor    or false
    cfg.mpTextUseClassColor    = cfg.mpTextUseClassColor    or false
    cfg.levelTextUseClassColor = cfg.levelTextUseClassColor or false

    -- Textsichtbarkeit / Größe / Anker
    cfg.showName      = (cfg.showName      ~= false)
    cfg.showHPText    = (cfg.showHPText    ~= false)
    cfg.showMPText    = (cfg.showMPText    ~= false)
    cfg.showLevelText = (cfg.showLevelText ~= false)

    cfg.nameSize      = cfg.nameSize      or 14
    cfg.hpTextSize    = cfg.hpTextSize    or 12
    cfg.mpTextSize    = cfg.mpTextSize    or 12
    cfg.levelTextSize = cfg.levelTextSize or 12

    cfg.nameAnchor   = cfg.nameAnchor   or "TOPLEFT"
    cfg.hpTextAnchor = cfg.hpTextAnchor or "BOTTOMRIGHT"
    cfg.mpTextAnchor = cfg.mpTextAnchor or "BOTTOMRIGHT"
    cfg.levelAnchor  = cfg.levelAnchor  or "BOTTOMLEFT"

    cfg.nameXOffset   = cfg.nameXOffset   or 0
    cfg.nameYOffset   = cfg.nameYOffset   or 0
    cfg.hpTextXOffset = cfg.hpTextXOffset or 0
    cfg.hpTextYOffset = cfg.hpTextYOffset or 0
    cfg.mpTextXOffset = cfg.mpTextXOffset or 0
    cfg.mpTextYOffset = cfg.mpTextYOffset or 0
    cfg.levelXOffset  = cfg.levelXOffset  or 0
    cfg.levelYOffset  = cfg.levelYOffset  or 0

    cfg.nameBold      = cfg.nameBold      or false
    if cfg.nameShadow == nil then cfg.nameShadow = true end
    cfg.hpTextBold    = cfg.hpTextBold    or false
    if cfg.hpTextShadow == nil then cfg.hpTextShadow = true end
    cfg.mpTextBold    = cfg.mpTextBold    or false
    if cfg.mpTextShadow == nil then cfg.mpTextShadow = true end
    cfg.levelBold     = cfg.levelBold     or false
    if cfg.levelShadow == nil then cfg.levelShadow = true end

    -- Border
    if cfg.borderEnabled == nil then cfg.borderEnabled = false end
    cfg.borderSize = cfg.borderSize or 1
    
    -- Rahmenfarbe (für Pixel / generell)
    cfg.borderColor = cfg.borderColor or { r = 0, g = 0, b = 0 }

    local validBorderStyles = {
        PIXEL   = true,
        TOOLTIP = true,
        DIALOG  = true,
        THIN    = true,
        THICK   = true,
    }
    if not validBorderStyles[cfg.borderStyle] then
        cfg.borderStyle = "PIXEL"
    end

    -- Position der Party-Gruppe (Anker für party1)
    cfg.anchorPoint = cfg.anchorPoint or "CENTER"
    if cfg.anchorX == nil then cfg.anchorX = -250 end
    if cfg.anchorY == nil then cfg.anchorY = 150 end

    -- Layout-Richtung & Abstand zwischen Frames
    if cfg.layoutOrientation ~= "HORIZONTAL" and cfg.layoutOrientation ~= "VERTICAL" then
        cfg.layoutOrientation = "VERTICAL"  -- Standard: untereinander
    end

    if type(cfg.spacing) ~= "number" then
        cfg.spacing = 4
    elseif cfg.spacing < 0 then
        cfg.spacing = 0
    end

    -- Out-of-Range Transparenz (1.0 = normal, 0.6 = etwas ausgegraut)
    cfg.rangeAlpha = cfg.rangeAlpha or 0.6

    -- Buff-/Debuff-Config (muss zu deiner ConfigUI passen)
    cfg.buffs   = cfg.buffs   or {}
    cfg.debuffs = cfg.debuffs or {}

    cfg.buffs.enabled = (cfg.buffs.enabled ~= false)
    cfg.buffs.anchor  = cfg.buffs.anchor or "TOPLEFT"
    cfg.buffs.x       = cfg.buffs.x or 0
    cfg.buffs.y       = cfg.buffs.y or 10
    cfg.buffs.size    = cfg.buffs.size or 24
    cfg.buffs.grow    = cfg.buffs.grow or "RIGHT"
    cfg.buffs.max     = cfg.buffs.max or 12
    cfg.buffs.perRow  = cfg.buffs.perRow or 8
    cfg.buffs.onlyOwn = (cfg.buffs.onlyOwn == true)

    cfg.debuffs.enabled        = (cfg.debuffs.enabled ~= false)
    cfg.debuffs.anchor         = cfg.debuffs.anchor or "TOPLEFT"
    cfg.debuffs.x              = cfg.debuffs.x or 0
    cfg.debuffs.y              = cfg.debuffs.y or -26
    cfg.debuffs.size           = cfg.debuffs.size or 24
    cfg.debuffs.grow           = cfg.debuffs.grow or "RIGHT"
    cfg.debuffs.max            = cfg.debuffs.max or 12
    cfg.debuffs.perRow         = cfg.debuffs.perRow or 8
    cfg.debuffs.onlyDispellable = (cfg.debuffs.onlyDispellable == true)

    -- Role-Icon
    if cfg.roleIconEnabled == nil then
        cfg.roleIconEnabled = true
    end
    cfg.roleIconSize    = cfg.roleIconSize    or 16
    cfg.roleIconAnchor  = cfg.roleIconAnchor  or "BOTTOMLEFT"
    cfg.roleIconXOffset = cfg.roleIconXOffset or 4
    cfg.roleIconYOffset = cfg.roleIconYOffset or 4

    -- Ready-Check-Icon
    if cfg.readyIconEnabled == nil then
        cfg.readyIconEnabled = true
    end
    cfg.readyIconSize    = cfg.readyIconSize    or 20
    cfg.readyIconAnchor  = cfg.readyIconAnchor  or "CENTER"
    cfg.readyIconXOffset = cfg.readyIconXOffset or 0
    cfg.readyIconYOffset = cfg.readyIconYOffset or 0

    return cfg
end

-- Für Debugging zugreifbar machen
AI.GetPartyConfig = GetPartyConfig

-------------------------------------------------
-- Presets-API für das Config-UI
-------------------------------------------------

local function ApplyPresetToConfig(cfg, preset)
    if not preset then return end
    for k, v in pairs(preset) do
        cfg[k] = v
    end
end

function M.GetPresets()
    return PARTY_PRESETS
end

function M.ApplyPreset(key)
    local preset = PARTY_PRESETS[key]
    if not preset then return end

    local cfg = GetPartyConfig()
    ApplyPresetToConfig(cfg, preset)

    if AI and AI.RefreshModule then
        AI.RefreshModule("party")
    else
        if M.ApplyLayout then
            M.ApplyLayout()
        end
        if M.UpdateAll then
            M.UpdateAll()
        end
    end
end

-------------------------------------------------
-- Blizzard-Partyframes verstecken / wiederherstellen
-------------------------------------------------

local function HideAndRemember(frame)
    if not frame or frame.__AI_PartyHidden then
        return
    end

    frame.__AI_PartyHidden    = true
    frame.__AI_PartyPrevAlpha = frame:GetAlpha()
    frame.__AI_PartyPrevShown = frame:IsShown()
    frame.__AI_PartyPrevMouse = frame:IsMouseEnabled()

    frame:SetAlpha(0)
    frame:Hide()
    frame:EnableMouse(false)

    frame:HookScript("OnShow", function(self)
        if AI and AI.modules and AI.modules.party
           and AI.modules.party.IsEnabled
           and AI.modules.party.IsEnabled()
        then
            self:SetAlpha(0)
            self:EnableMouse(false)
            self:Hide()
        end
    end)
end

-- local function HideBlizzardParty()
--     for i = 1, 4 do
--         HideAndRemember(_G["PartyMemberFrame"..i])
--     end

--     HideAndRemember(_G["PartyFrame"])
--     HideAndRemember(_G["CompactPartyFrame"])

--     if not IsInRaid() then
--         HideAndRemember(_G["CompactRaidFrameManager"])
--         HideAndRemember(_G["CompactRaidFrameContainer"])
--     end
-- end
local function HideBlizzardParty()
    -- Klassische PartyFrames + dazugehörige PetFrames
    for i = 1, 4 do
        HideAndRemember(_G["PartyMemberFrame"..i])
        HideAndRemember(_G["PartyMemberFrame"..i.."PetFrame"])
    end

    -- Neue Container / Raid-Style PartyFrames
    HideAndRemember(_G["PartyFrame"])
    HideAndRemember(_G["CompactPartyFrame"])

    -- Raid-Style Party über CompactRaidFrameContainer:
    -- nur im 5er/Party-Bereich verstecken, nicht in echten Raids
    if not IsInRaid() then
        HideAndRemember(_G["CompactRaidFrameManager"])
        HideAndRemember(_G["CompactRaidFrameContainer"])
    end
end

local function RestoreOne(frame)
    if not frame or not frame.__AI_PartyHidden then
        return
    end

    frame:SetAlpha(frame.__AI_PartyPrevAlpha or 1)

    if frame.__AI_PartyPrevMouse ~= nil then
        frame:EnableMouse(frame.__AI_PartyPrevMouse)
    end
    if frame.__AI_PartyPrevShown then
        frame:Show()
    end

    frame.__AI_PartyHidden    = nil
    frame.__AI_PartyPrevAlpha = nil
    frame.__AI_PartyPrevShown = nil
    frame.__AI_PartyPrevMouse = nil
end

local function RestoreBlizzardParty()
    for i = 1, 4 do
        RestoreOne(_G["PartyMemberFrame"..i])
    end

    RestoreOne(_G["PartyFrame"])
    RestoreOne(_G["CompactPartyFrame"])
    RestoreOne(_G["CompactRaidFrameManager"])
    RestoreOne(_G["CompactRaidFrameContainer"])
end

-------------------------------------------------
-- Hilfsfunktionen (Farben / Fonts)
-------------------------------------------------

local function GetClassColor(unit)
    local _, class = UnitClass(unit or "player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

local function GetPowerColor(unit)
    local powerType, powerToken

    -- Midnight kann zickig sein: UnitPowerType in pcall kapseln
    if UnitPowerType then
        local ok, pt, token = pcall(UnitPowerType, unit)
        if ok then
            powerType, powerToken = pt, token
        end
    end

    if powerToken and PowerBarColor and PowerBarColor[powerToken] then
        local c = PowerBarColor[powerToken]
        return c.r, c.g, c.b
    end
    if powerType and PowerBarColor and PowerBarColor[powerType] then
        local c = PowerBarColor[powerType]
        return c.r, c.g, c.b
    end
    return 0, 0.4, 1
end


local function GetTextColorFromConfig(cfgColor, useClassColor, unit)
    if useClassColor then
        return GetClassColor(unit)
    end
    if cfgColor then
        return cfgColor.r or 1, cfgColor.g or 1, cfgColor.b or 1
    end
    return 1, 1, 1
end

local function SetFontStyle(fs, size, bold, shadow)
    if not fs then return end

    size   = size or 12
    bold   = bold and true or false
    shadow = (shadow ~= false)

    local font, _, outline = GameFontNormal:GetFont()
    if bold then
        outline = "OUTLINE"
    else
        outline = ""
    end

    fs:SetFont(font, size, outline)

    if shadow then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

-------------------------------------------------
-- HP / Mana Textformatierung
-------------------------------------------------

local function FormatHPText(unit, mode)
    if not UnitExists(unit) then
        return ""
    end

    local hp    = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)

    if AbbreviateLargeNumbers then
        hpStr  = AbbreviateLargeNumbers(hp)
        maxStr = AbbreviateLargeNumbers(maxHP)
    end

    if not maxHP or maxHP <= 0 then
        return ""
    end

    -- Midnight: Prozentwert direkt holen (wie bei UnitPowerPercent)
    local pct = UnitHealthPercent and UnitHealthPercent(unit, false, true) or nil

    if mode == "PERCENT" then
        if pct ~= nil then
            return string.format("%d%%", pct)
        end
        return ""
    elseif mode == "BOTH" then

        return string.format("%s / %s", hpStr, maxStr)
    end

    --return BreakUpLargeNumbers(hp)
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

    return string.format("%s / %s", pStr, maxStr)
end

-------------------------------------------------
-- Frames / globale Variablen
-------------------------------------------------

local frames = {}
local eventFrame
local movingMode = false
local rangeFrame      -- kleines OnUpdate-Frame für Range-Checks

-- NEU: globaler Zustand, ob gerade ein Readycheck läuft
local readyCheckActive = false

local function ForEachPartyFrame(func)
    for _, unit in ipairs(PARTY_UNITS) do
        local f = frames[unit]
        if f then
            func(f, unit)
        end
    end
end

local function SetBarTexture(bar, texKey)
    if not bar then return end
    local tex = BAR_TEXTURES[texKey or "DEFAULT"] or BAR_TEXTURES.DEFAULT
    bar:SetStatusBarTexture(tex)
end

-------------------------------------------------
-- Out-of-Range Visuals
-------------------------------------------------
local function UpdateRangeVisual(frame)
    if not frame or not frame.unit then return end

    local cfg  = GetPartyConfig()
    local unit = frame.unit

    -- Basisalpha aus Config
    local baseAlpha = cfg.alpha or 1
    local fadeAlpha = (cfg.rangeAlpha or 0.6)

    -- Wenn Unit nicht existiert oder offline → leicht ausgegraut
    if type(unit) ~= "string" or not UnitExists(unit) or not UnitIsConnected(unit) then
        frame:SetAlpha(baseAlpha * fadeAlpha)
        return
    end

    -- KEIN UnitInRange (Midnight secret values)
    -- → immer normale Alpha für "lebende, verbundene" Party-Mitglieder
    frame:SetAlpha(baseAlpha)
end



local function UpdateAllRanges()
    ForEachPartyFrame(function(f)
        if f:IsShown() then
            UpdateRangeVisual(f)
        end
    end)
end

local function ApplyTextLayout(frame, fs, show, size, anchor, xOff, yOff, bold, shadow, cfgColor, useClassColor)
    if not frame or not fs then return end

    if not show then
        fs:Hide()
        return
    end

    SetFontStyle(fs, size, bold, shadow)

    local r, g, b = GetTextColorFromConfig(cfgColor, useClassColor, frame.unit)
    fs:SetTextColor(r, g, b, 1)

    fs:ClearAllPoints()
    anchor = anchor or "CENTER"
    xOff   = xOff or 0
    yOff   = yOff or 0

    local anchorFrame = frame.textLayer or frame
    fs:SetPoint(anchor, anchorFrame, anchor, xOff, yOff)

    fs:SetDrawLayer("OVERLAY", 5)
    fs:Show()
end

-------------------------------------------------
-- Border
-------------------------------------------------
local function ApplyBorderLayout(frame, cfg)
    if not frame then return end

    if not cfg.borderEnabled then
        if frame.border then
            frame.border:Hide()
        end
        return
    end

    if not frame.border then
        frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    end

    local style    = cfg.borderStyle or "PIXEL"
    local size     = cfg.borderSize or 1
    local edgeFile
    local edgeSize
    local insetLeft, insetRight, insetTop, insetBottom = 0, 0, 0, 0

    if style == "PIXEL" then
        edgeFile = "Interface\\Buttons\\WHITE8x8"
        edgeSize = size
        insetLeft, insetRight, insetTop, insetBottom = -size, -size, -size, -size
    elseif style == "THIN" then
        edgeFile = "Interface\\Buttons\\WHITE8x8"
        edgeSize = 1
        insetLeft, insetRight, insetTop, insetBottom = -1, -1, -1, -1
    elseif style == "THICK" then
        edgeFile = "Interface\\Buttons\\WHITE8x8"
        edgeSize = 2
        insetLeft, insetRight, insetTop, insetBottom = -2, -2, -2, -2
    elseif style == "TOOLTIP" then
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"
        edgeSize = 16
        insetLeft, insetRight, insetTop, insetBottom = 3, 3, 3, 3
    elseif style == "DIALOG" then
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"
        edgeSize = 16
        insetLeft, insetRight, insetTop, insetBottom = 3, 3, 3, 3
    else
        edgeFile = "Interface\\Buttons\\WHITE8x8"
        edgeSize = size
        insetLeft, insetRight, insetTop, insetBottom = -size, -size, -size, -size
    end

    frame.border:SetBackdrop({
        edgeFile = edgeFile,
        edgeSize = edgeSize,
        insets   = {
            left   = insetLeft,
            right  = insetRight,
            top    = insetTop,
            bottom = insetBottom,
        },
    })

    -- Nur PIXEL / THIN / THICK einfärben (Colorcircle / cfg.borderColor)
    if style == "PIXEL" or style == "THIN" or style == "THICK" then
        local r, g, b, a = 0, 0, 0, 1
        if cfg.borderColor then
            r = cfg.borderColor.r or r
            g = cfg.borderColor.g or g
            b = cfg.borderColor.b or b
        end
        frame.border:SetBackdropBorderColor(r, g, b, a)
    end
    -- TOOLTIP / DIALOG: KEIN SetBackdropBorderColor → Blizzard-Färbung bleibt

    -- Innenfläche bleibt transparent
    frame.border:SetBackdropColor(0, 0, 0, 0)

    frame.border:ClearAllPoints()
    frame.border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local baseLevel = frame:GetFrameLevel() or 1
    frame.border:SetFrameLevel(baseLevel + 2)
    frame.border:Show()
end



-------------------------------------------------
-- Icons aktualisieren (Combat / Resting / Leader / Raidtarget)
-------------------------------------------------

local function UpdateIcons(frame)
    if not frame or not frame.unit then return end

    local unit = frame.unit
    if not UnitExists(unit) then
        if frame.combatIcon then frame.combatIcon:Hide() end
        if frame.restingIcon then frame.restingIcon:Hide() end
        if frame.leaderIcon then frame.leaderIcon:Hide() end
        if frame.raidIcon   then frame.raidIcon:Hide()   end
        return
    end

    local cfg = GetPartyConfig()
    local anchorFrame = frame.iconLayer or frame

    -- Combat-Icon
    if frame.combatIcon then
        local enabled = (cfg.combatIconEnabled ~= false)
        if enabled and UnitAffectingCombat(unit) then
            local size   = cfg.combatIconSize   or 24
            local anchor = cfg.combatIconAnchor or "TOPLEFT"
            local xOff   = cfg.combatIconXOffset or -4
            local yOff   = cfg.combatIconYOffset or 4

            frame.combatIcon:ClearAllPoints()
            frame.combatIcon:SetSize(size, size)
            frame.combatIcon:SetPoint(anchor, anchorFrame, anchor, xOff, yOff)
            frame.combatIcon:Show()
        else
            frame.combatIcon:Hide()
        end
    end

    -- Resting-Icon:
    -- Im Partyframe nie anzeigen (Resting ist eigentlich nur für den eigenen Player sinnvoll
    -- und der hat sein eigenes Modul). Wichtig: kein UnitIsUnit() wegen Midnight secret values.
    if frame.restingIcon then
        frame.restingIcon:Hide()
    end

    -- Leader-Icon
    if frame.leaderIcon then
        local enabled = (cfg.leaderIconEnabled ~= false)
        if enabled and UnitIsGroupLeader(unit) then
            local size   = cfg.leaderIconSize   or 18
            local anchor = cfg.leaderIconAnchor or "TOPRIGHT"
            local xOff   = cfg.leaderIconXOffset or 4
            local yOff   = cfg.leaderIconYOffset or 4

            frame.leaderIcon:ClearAllPoints()
            frame.leaderIcon:SetSize(size, size)
            frame.leaderIcon:SetPoint(anchor, anchorFrame, anchor, xOff, yOff)
            frame.leaderIcon:Show()
        else
            frame.leaderIcon:Hide()
        end
    end

    -- Raidtarget-Icon
    if frame.raidIcon then
        local enabled = (cfg.raidIconEnabled ~= false)
        local index   = GetRaidTargetIndex(unit)

        if enabled and index then
            local size   = cfg.raidIconSize   or 20
            local anchor = cfg.raidIconAnchor or "TOP"
            local xOff   = cfg.raidIconXOffset or 0
            local yOff   = cfg.raidIconYOffset or 10

            frame.raidIcon:ClearAllPoints()
            frame.raidIcon:SetSize(size, size)
            frame.raidIcon:SetPoint(anchor, frame, anchor, xOff, yOff)

            -- nur aufrufen, wenn die Textur wirklich existiert
            if frame.raidIcon.SetTexCoord then
                SetRaidTargetIconTexture(frame.raidIcon, index)
            end

            frame.raidIcon:Show()
        else
            frame.raidIcon:Hide()
        end
    end
    
    -- Role-Icon (Tank / Healer / Damager)
    if frame.roleIcon then
        local enabled = (cfg.roleIconEnabled ~= false)

        if enabled and UnitGroupRolesAssigned then
            local role = UnitGroupRolesAssigned(unit)

            if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
                local size   = cfg.roleIconSize    or 16
                local anchor = cfg.roleIconAnchor  or "BOTTOMLEFT"
                local xOff   = cfg.roleIconXOffset or 4
                local yOff   = cfg.roleIconYOffset or 4

                frame.roleIcon:ClearAllPoints()
                frame.roleIcon:SetSize(size, size)
                frame.roleIcon:SetPoint(anchor, anchorFrame, anchor, xOff, yOff)
                frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")

                -- TexCoords je nach Rolle setzen
                if role == "TANK" then
                    -- Tank-Symbol
                    frame.roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
                elseif role == "HEALER" then
                    -- Heiler-Symbol
                    frame.roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
                elseif role == "DAMAGER" then
                    -- DPS-Symbol
                    frame.roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64)
                end

                frame.roleIcon:Show()
            else
                frame.roleIcon:Hide()
            end
        else
            frame.roleIcon:Hide()
        end
    end

        -- Ready-Check-Icon
    if frame.readyIcon then
        local enabled = (cfg.readyIconEnabled ~= false)

        if enabled and readyCheckActive and GetReadyCheckStatus then
            local status = GetReadyCheckStatus(unit)

            local tex
            if status == "ready" then
                tex = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
            elseif status == "notready" then
                tex = "Interface\\RAIDFRAME\\ReadyCheck-NotReady"
            elseif status == "waiting" or status == nil then
                tex = "Interface\\RAIDFRAME\\ReadyCheck-Waiting"
            else
                -- Irgendein anderer Status → Icon verstecken
                frame.readyIcon:Hide()
                return
            end

            local size   = cfg.readyIconSize    or 20
            local anchor = cfg.readyIconAnchor  or "CENTER"
            local xOff   = cfg.readyIconXOffset or 0
            local yOff   = cfg.readyIconYOffset or 0

            frame.readyIcon:ClearAllPoints()
            frame.readyIcon:SetSize(size, size)
            frame.readyIcon:SetPoint(anchor, anchorFrame, anchor, xOff, yOff)
            frame.readyIcon:SetTexture(tex)
            frame.readyIcon:Show()
        else
            -- Kein aktiver Readycheck oder Option aus → Icon weg
            frame.readyIcon:Hide()
        end
    end
end

-------------------------------------------------
-- Buffs / Debuffs
-------------------------------------------------

local AURA_SPACING = 2

local function EnsureAuraButtons(frame, kind, maxCount)
    local key = (kind == "DEBUFF") and "debuffButtons" or "buffButtons"
    frame[key] = frame[key] or {}
    local list = frame[key]

    local baseLevel = (frame.textLayer and frame.textLayer:GetFrameLevel() or frame:GetFrameLevel()) + 1

    for i = #list + 1, maxCount do
        local btn = CreateFrame("Button", nil, frame)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()

        btn:SetFrameLevel(baseLevel)
        btn:Hide()

        list[i] = btn
    end

    return list
end

local function LayoutAuraButtons(frame, buttons, cfg)
    if not buttons or not cfg then return end

    local anchorPoint = cfg.anchor or "TOPLEFT"
    local grow        = cfg.grow or "RIGHT"
    local size        = cfg.size or 24
    local perRow      = cfg.perRow or 8
    local xBase       = cfg.x or 0
    local yBase       = cfg.y or 0

    local anchorFrame = frame

    local col, row = 0, 0

    for _, btn in ipairs(buttons) do
        if btn:IsShown() then
            btn:SetSize(size, size)
            btn:ClearAllPoints()

            local x = xBase
            local y = yBase

            if grow == "RIGHT" then
                x = x + col * (size + AURA_SPACING)
                y = y - row * (size + AURA_SPACING)
            elseif grow == "LEFT" then
                x = x - col * (size + AURA_SPACING)
                y = y - row * (size + AURA_SPACING)
            elseif grow == "UP" then
                x = x + col * (size + AURA_SPACING)
                y = y + row * (size + AURA_SPACING)
            elseif grow == "DOWN" then
                x = x + col * (size + AURA_SPACING)
                y = y - row * (size + AURA_SPACING)
            else
                x = x + col * (size + AURA_SPACING)
                y = y - row * (size + AURA_SPACING)
            end

            btn:SetPoint(anchorPoint, anchorFrame, anchorPoint, x, y)

            col = col + 1
            if col >= perRow then
                col = 0
                row = row + 1
            end
        end
    end
end

local function UpdateAuras(frame)
    if not frame or not frame.unit or not UnitExists(frame.unit) then
        if frame.buffButtons then
            for _, b in ipairs(frame.buffButtons) do b:Hide() end
        end
        if frame.debuffButtons then
            for _, b in ipairs(frame.debuffButtons) do b:Hide() end
        end
        return
    end

    local cfg      = GetPartyConfig()
    local buffsCfg = cfg.buffs or {}
    local debuffsCfg = cfg.debuffs or {}
    local unit     = frame.unit

-------------------------------------------------
-- BUFFS
-------------------------------------------------
if buffsCfg.enabled and AuraUtil and AuraUtil.ForEachAura then
    local maxBuffs = buffsCfg.max or 12
    local buttons  = EnsureAuraButtons(frame, "BUFF", maxBuffs)

    -- alles ausblenden
    for _, b in ipairs(buttons) do b:Hide() end

    local count = 0

    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
        if not aura or not aura.icon then
            return false
        end

        -- WICHTIG:
        -- KEIN Filter mehr nach "onlyOwn"
        -- KEIN aura.sourceUnit
        -- KEIN aura.isFromPlayerOrPlayerPet
        -- KEIN UnitIsUnit(...) -> alles Secret-Value-gefährlich

        count = count + 1
        if count > maxBuffs then
            return true  -- stoppt die Schleife
        end

        local btn = buttons[count]
        btn.icon:SetTexture(aura.icon)
        btn:Show()

        return false
    end, true)

    LayoutAuraButtons(frame, buttons, buffsCfg)
else
    if frame.buffButtons then
        for _, b in ipairs(frame.buffButtons) do b:Hide() end
    end
end




    -------------------------------------------------
    -- DEBUFFS
    -------------------------------------------------
    if debuffsCfg.enabled and AuraUtil and AuraUtil.ForEachAura then
        local maxDebuffs = debuffsCfg.max or 12
        local buttons    = EnsureAuraButtons(frame, "DEBUFF", maxDebuffs)

        for _, b in ipairs(buttons) do b:Hide() end

        local count = 0

        AuraUtil.ForEachAura(unit, "HARMFUL", nil, function(aura)
            if not aura or not aura.icon then
                return false
            end

            if debuffsCfg.onlyDispellable then
                -- Packed Aura: isDispellable / dispelName sind sicher
                if not aura.isDispellable and not aura.dispelName then
                    return false
                end
            end

            count = count + 1
            if count > maxDebuffs then
                return true
            end

            local btn = buttons[count]
            btn.icon:SetTexture(aura.icon)
            btn:Show()

            return false
        end, true)

        LayoutAuraButtons(frame, buttons, debuffsCfg)
    else
        if frame.debuffButtons then
            for _, b in ipairs(frame.debuffButtons) do b:Hide() end
        end
    end
end

-- Schneidet lange Namen auf eine maximale Pixelbreite und hängt "..." an
local function SetTruncatedName(frame, fullName, maxWidth)
    if not frame or not frame.nameText or not fullName then return end
    if maxWidth <= 0 then
        frame.nameText:SetText("")
        return
    end

    local fs = frame.nameText

    -- Erst mal im vollen Text messen
    fs:SetWidth(0)         -- keine künstliche Begrenzung
    fs:SetText(fullName)
    local fullWidth = fs:GetStringWidth() or 0

    -- Passt eh → nichts tun
    if fullWidth <= maxWidth then
        return
    end

    local ellipsis = "..."
    fs:SetText(ellipsis)
    local ellipsisWidth = fs:GetStringWidth() or 0
    if ellipsisWidth > maxWidth then
        -- So schmal, dass nicht mal "..." reinpasst
        fs:SetText("")
        return
    end

    -- Binäre Suche nach der maximalen Länge, die inkl. "..." noch reinpasst
    local nameLen = #fullName
    local left, right = 1, nameLen
    local best = ellipsis

    while left <= right do
        local mid = math.floor((left + right) / 2)
        local candidate = string.sub(fullName, 1, mid) .. ellipsis

        fs:SetText(candidate)
        local w = fs:GetStringWidth() or 0

        if w <= maxWidth then
            best = candidate
            left = mid + 1
        else
            right = mid - 1
        end
    end

    fs:SetText(best)
    -- Optional: tatsächliche Breite begrenzen, damit nichts drüberzeichnet
    fs:SetWidth(maxWidth)
end

-- Berechnet max. Breite für den Namen relativ zu Frame-Breite, Offsets, Fontgröße
local function UpdateNameText(frame, cfg)
    if not frame or not frame.nameText then return end

    local unit = frame.unit
    if not unit or not UnitExists(unit) then
        frame.nameText:SetText("")
        return
    end

    local name = UnitName(unit) or ""
    if name == "" then
        frame.nameText:SetText("")
        return
    end

    -- Framebreite nehmen und ein wenig Padding abziehen
    local frameWidth = frame:GetWidth() or 0

    -- Links: etwas Luft + dein X-Offset, rechts: etwas Luft
    local padLeft  = 6 + math.abs(cfg.nameXOffset or 0)
    local padRight = 6

    local maxWidth = frameWidth - padLeft - padRight
    if maxWidth < 0 then maxWidth = 0 end

    SetTruncatedName(frame, name, maxWidth)
end


-------------------------------------------------
-- Frame-Layout
-------------------------------------------------
local function ApplyFrameLayout(frame, cfg)
    if not frame then return end

    local unit = frame.unit
    -- Sicherheit: nur weitermachen, wenn wir ein gültiges Unit-Token haben
    if type(unit) ~= "string" then
        return
    end
    -- Sicherstellen, dass iconLayer existiert (falls alte Frames ohne Layer rumfliegen)
    if not frame.iconLayer then
        frame.iconLayer = CreateFrame("Frame", nil, frame)
        frame.iconLayer:SetAllPoints(frame)
    end
    local width  = cfg.width or 220
    local height = cfg.height or 60

    -------------------------------------------------
    -- Innenbereich bestimmen (wegen Rahmen)
    -------------------------------------------------
    local innerInset = 1
    if cfg.borderEnabled and (cfg.borderStyle == "TOOLTIP" or cfg.borderStyle == "DIALOG") then
        innerInset = 4      -- Tooltip-/Dialog-Rahmen sind optisch breiter
    end

    -- Inhaltshöhe = Framehöhe minus Rahmen oben/unten
    local contentHeight = height - innerInset * 2
    if contentHeight < 1 then
        contentHeight = 1
    end

    -------------------------------------------------
    -- HP / MP Höhen wie im Playerframe, aber im Inhalt
    -------------------------------------------------
    local ratio = tonumber(cfg.hpRatio) or 0.66
    if ratio < 0.1 then ratio = 0.1 end
    if ratio > 0.9 then ratio = 0.9 end

    local hpHeight, mpHeight
    if cfg.manaEnabled then
        hpHeight = math.floor(contentHeight * ratio + 0.5)
        mpHeight = contentHeight - hpHeight

        -- Sicherheitsnetz, damit beide Bars immer > 0 bleiben
        if hpHeight < 1 then hpHeight = 1 end
        if mpHeight < 1 then
            mpHeight = 1
            hpHeight = contentHeight - mpHeight
            if hpHeight < 1 then hpHeight = 1 end
        end
    else
        -- Keine Manabar: HP füllt den kompletten Inhalt
        hpHeight = contentHeight
        mpHeight = 0
    end

    frame:SetSize(width, height)
    frame:SetAlpha(cfg.alpha or 1)

    -------------------------------------------------
    -- Power – Midnight/secret values absichern
    -------------------------------------------------
    local pType = 0
    if UnitPowerType then
        local ok, pt = pcall(UnitPowerType, unit)
        if ok and type(pt) == "number" then
            pType = pt
        end
    end

    local power, powerMax = 0, 0
    if UnitPower and UnitPowerMax then
        local ok1, v1 = pcall(UnitPower, unit, pType)
        if ok1 and type(v1) == "number" then
            power = v1
        end

        local ok2, v2 = pcall(UnitPowerMax, unit, pType)
        if ok2 and type(v2) == "number" then
            powerMax = v2
        end
    end

    -------------------------------------------------
    -- Position des Frames (Block-Layout)
    -------------------------------------------------
    local idx     = tonumber(string.match(unit or "", "(%d+)")) or 1
    local spacing = cfg.spacing or 4

    frame:ClearAllPoints()

    if idx == 1 then
        frame:SetPoint(
            cfg.anchorPoint or "CENTER",
            UIParent,
            cfg.anchorPoint or "CENTER",
            (cfg.anchorX or 0),
            (cfg.anchorY or 0)
        )
    else
        local prevUnit  = "party"..(idx - 1)
        local prevFrame = frames[prevUnit]

        if prevFrame and prevFrame:IsShown() then
            if cfg.layoutOrientation == "HORIZONTAL" then
                frame:SetPoint("LEFT", prevFrame, "RIGHT", spacing, 0)
            else
                frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -spacing)
            end
        else
            if cfg.layoutOrientation == "HORIZONTAL" then
                frame:SetPoint(
                    cfg.anchorPoint or "CENTER",
                    UIParent,
                    cfg.anchorPoint or "CENTER",
                    (cfg.anchorX or 0) + (idx - 1) * (width + spacing),
                    (cfg.anchorY or 0)
                )
            else
                frame:SetPoint(
                    cfg.anchorPoint or "CENTER",
                    UIParent,
                    cfg.anchorPoint or "CENTER",
                    (cfg.anchorX or 0),
                    (cfg.anchorY or 0) - (idx - 1) * (height + spacing)
                )
            end
        end
    end

    -------------------------------------------------
    -- Hintergrund im Innenbereich
    -------------------------------------------------
    if not frame.bg then
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    end

    frame.bg:ClearAllPoints()
    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", innerInset, -innerInset)
    frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -innerInset, innerInset)

    local bgR, bgG, bgB, bgA = 0, 0, 0, 0.6
    if cfg.frameBgMode == "CLASS" then
        bgR, bgG, bgB = GetClassColor(unit)
        bgA = 0.35
    elseif cfg.frameBgMode == "CLASSPOWER" then
        local r1, g1, b1 = GetClassColor(unit)
        local r2, g2, b2 = GetPowerColor(unit)
        bgR = (r1 + r2) / 2
        bgG = (g1 + g2) / 2
        bgB = (b1 + b2) / 2
        bgA = 0.45
    end
    frame.bg:SetColorTexture(bgR, bgG, bgB, bgA)

    -------------------------------------------------
    -- FrameLevel / Layering
    -------------------------------------------------
    local baseLevel = frame:GetFrameLevel() or 1
    frame.healthBar:SetFrameLevel(baseLevel + 1)
    frame.powerBar:SetFrameLevel(baseLevel + 1)
    if frame.border then
        frame.border:SetFrameLevel(baseLevel + 2)
    end
    if frame.textLayer then
        frame.textLayer:SetFrameLevel(baseLevel + 3)
    end
    if frame.iconLayer then
        frame.iconLayer:SetFrameLevel(baseLevel + 4)
    end

    -------------------------------------------------
    -- HealthBar + PowerBar Layout im Innenbereich
    -------------------------------------------------
    frame.healthBar:ClearAllPoints()

    if cfg.manaEnabled and mpHeight > 0 then
        -- HP oben, fester Anteil, aber innerhalb des Rahmens
        frame.healthBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  innerInset, -innerInset)
        frame.healthBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -innerInset, -innerInset)
        frame.healthBar:SetHeight(hpHeight)
    else
        -- Keine Mana-Bar: HP füllt den kompletten Innenbereich
        frame.healthBar:SetPoint("TOPLEFT",     frame, "TOPLEFT",     innerInset, -innerInset)
        frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -innerInset, innerInset)
    end

    SetBarTexture(frame.healthBar, cfg.hpTexture)

    -- Absorb-Bar immer exakt über der HealthBar halten
    if frame.absorbBar then
        frame.absorbBar:ClearAllPoints()
        frame.absorbBar:SetAllPoints(frame.healthBar)
        frame.absorbBar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 1)
    end

    -- HP-Farbe wie gehabt
    local hr, hg, hb
    if cfg.hpUseCustomColor then
        hr = cfg.hpCustomColor.r or 0
        hg = cfg.hpCustomColor.g or 1
        hb = cfg.hpCustomColor.b or 0
    elseif cfg.hpColorMode == "CLASS" then
        hr, hg, hb = GetClassColor(unit)
    else
        hr, hg, hb = 0, 1, 0
    end
    frame.healthBar:SetStatusBarColor(hr, hg, hb, 1)

    if not frame.healthBar.bg then
        frame.healthBar.bg = frame.healthBar:CreateTexture(nil, "BACKGROUND")
    end
    frame.healthBar.bg:ClearAllPoints()
    frame.healthBar.bg:SetAllPoints(frame.healthBar)
    frame.healthBar.bg:SetColorTexture(0, 0, 0, 0.6)

    -- PowerBar direkt unter der HP-Bar, auch im Innenbereich
    if cfg.manaEnabled and mpHeight > 0 then
        frame.powerBar:Show()
        frame.powerBar:ClearAllPoints()
        frame.powerBar:SetPoint("TOPLEFT",  frame.healthBar, "BOTTOMLEFT",  0, 0)
        frame.powerBar:SetPoint("TOPRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, 0)
        frame.powerBar:SetHeight(mpHeight)

        SetBarTexture(frame.powerBar, cfg.mpTexture)

        local pr, pg, pb
        if cfg.mpUseCustomColor then
            pr = cfg.mpCustomColor.r or 0
            pg = cfg.mpCustomColor.g or 0
            pb = cfg.mpCustomColor.b or 1
        else
            pr, pg, pb = GetPowerColor(unit)
        end
        frame.powerBar:SetStatusBarColor(pr, pg, pb, 1)

        if not frame.powerBar.bg then
            frame.powerBar.bg = frame.powerBar:CreateTexture(nil, "BACKGROUND")
        end
        frame.powerBar.bg:ClearAllPoints()
        frame.powerBar.bg:SetAllPoints(frame.powerBar)
        frame.powerBar.bg:SetColorTexture(0, 0, 0, 0.6)
    else
        frame.powerBar:Hide()
        if frame.powerBar.bg then
            frame.powerBar.bg:Hide()
        end
    end

    -------------------------------------------------
    -- Border oben drauf
    -------------------------------------------------
    ApplyBorderLayout(frame, cfg)

    -------------------------------------------------
    -- Texte wie gehabt
    -------------------------------------------------
    local name = UnitName(unit) or ""
    frame.nameText:SetText(name)

    local lvl = UnitLevel(unit) or 0
    local levelText = ""
    if lvl > 0 then
        levelText = tostring(lvl)
    end
    frame.levelText:SetText(levelText)

    frame.hpText:SetText(FormatHPText(unit, cfg.hpTextMode))
    frame.mpText:SetText(cfg.manaEnabled and FormatPowerText(unit, cfg.mpTextMode or "BOTH", pType, power or 0, powerMax) or "")

    ApplyTextLayout(
        frame,
        frame.nameText,
        cfg.showName,
        cfg.nameSize,
        cfg.nameAnchor,
        cfg.nameXOffset,
        cfg.nameYOffset,
        cfg.nameBold,
        cfg.nameShadow,
        cfg.nameTextColor,
        cfg.nameTextUseClassColor
    )
    -- Ganz am Ende von ApplyFrameLayout (oder direkt nach dem ApplyTextLayout-Block):
    UpdateNameText(frame, cfg)

    ApplyTextLayout(
        frame,
        frame.hpText,
        cfg.showHPText,
        cfg.hpTextSize,
        cfg.hpTextAnchor,
        cfg.hpTextXOffset,
        cfg.hpTextYOffset,
        cfg.hpTextBold,
        cfg.hpTextShadow,
        cfg.hpTextColor,
        cfg.hpTextUseClassColor
    )

    ApplyTextLayout(
        frame,
        frame.mpText,
        cfg.manaEnabled and cfg.showMPText,
        cfg.mpTextSize,
        cfg.mpTextAnchor,
        cfg.mpTextXOffset,
        cfg.mpTextYOffset,
        cfg.mpTextBold,
        cfg.mpTextShadow,
        cfg.mpTextColor,
        cfg.mpTextUseClassColor
    )

    ApplyTextLayout(
        frame,
        frame.levelText,
        cfg.showLevelText,
        cfg.levelTextSize,
        cfg.levelAnchor,
        cfg.levelXOffset,
        cfg.levelYOffset,
        cfg.levelBold,
        cfg.levelShadow,
        cfg.levelTextColor,
        cfg.levelTextUseClassColor
    )
end

-- local function ApplyFrameLayout(frame, cfg)
--     if not frame then return end

--     local unit = frame.unit
--     -- Sicherheit: nur weitermachen, wenn wir ein gültiges Unit-Token haben
--     if type(unit) ~= "string" then
--         return
--     end

--     local width  = cfg.width or 220
--     local height = cfg.height or 60


--     -- wie im Playerframe: ratio clampen, alles inline
--     local ratio = tonumber(cfg.hpRatio) or 0.66
--     if ratio < 0.1 then ratio = 0.1 end
--     if ratio > 0.9 then ratio = 0.9 end

--     local hpHeight, mpHeight
--     if cfg.manaEnabled then
--         hpHeight = math.floor(height * ratio + 0.5)
--         mpHeight = height - hpHeight

--         -- Sicherheitsnetz, damit beide Bars immer > 0 bleiben
--         if hpHeight < 1 then hpHeight = 1 end
--         if mpHeight < 1 then
--             mpHeight = 1
--             hpHeight = height - mpHeight
--             if hpHeight < 1 then hpHeight = 1 end
--         end
--     else
--         -- Keine Manabar: HP füllt alles
--         hpHeight = height
--         mpHeight = 0
--     end


--     frame:SetSize(width, height)
--     frame:SetAlpha(cfg.alpha or 1)

--     -- Power – Midnight/secret values absichern
--     local pType = 0
--     if UnitPowerType then
--         local ok, pt = pcall(UnitPowerType, unit)
--         if ok and type(pt) == "number" then
--             pType = pt
--         end
--     end

--     local power, powerMax = 0, 0
--     if UnitPower and UnitPowerMax then
--         local ok1, v1 = pcall(UnitPower, unit, pType)
--         if ok1 and type(v1) == "number" then
--             power = v1
--         end

--         local ok2, v2 = pcall(UnitPowerMax, unit, pType)
--         if ok2 and type(v2) == "number" then
--             powerMax = v2
--         end
--     end

--     -- Position basierend auf party-Index + Orientierung/Abstand
--     local idx     = tonumber(string.match(unit or "", "(%d+)")) or 1
--     local spacing = cfg.spacing or 4

--     frame:ClearAllPoints()

--     if idx == 1 then
--         frame:SetPoint(
--             cfg.anchorPoint or "CENTER",
--             UIParent,
--             cfg.anchorPoint or "CENTER",
--             (cfg.anchorX or 0),
--             (cfg.anchorY or 0)
--         )
--     else
--         local prevUnit  = "party"..(idx - 1)
--         local prevFrame = frames[prevUnit]

--         if prevFrame and prevFrame:IsShown() then
--             if cfg.layoutOrientation == "HORIZONTAL" then
--                 frame:SetPoint("LEFT", prevFrame, "RIGHT", spacing, 0)
--             else
--                 frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -spacing)
--             end
--         else
--             if cfg.layoutOrientation == "HORIZONTAL" then
--                 frame:SetPoint(
--                     cfg.anchorPoint or "CENTER",
--                     UIParent,
--                     cfg.anchorPoint or "CENTER",
--                     (cfg.anchorX or 0) + (idx - 1) * (width + spacing),
--                     (cfg.anchorY or 0)
--                 )
--             else
--                 frame:SetPoint(
--                     cfg.anchorPoint or "CENTER",
--                     UIParent,
--                     cfg.anchorPoint or "CENTER",
--                     (cfg.anchorX or 0),
--                     (cfg.anchorY or 0) - (idx - 1) * (height + spacing)
--                 )
--             end
--         end
--     end

--     -- Hintergrund (etwas innerhalb des Rahmens, damit nichts „durchscheint“)
--     local innerInset = 1
--     if cfg.borderEnabled and (cfg.borderStyle == "TOOLTIP" or cfg.borderStyle == "DIALOG") then
--         innerInset = 4      -- Tooltip-/Dialog-Rahmen sind optisch breiter
--     end

--     if not frame.bg then
--         frame.bg = frame:CreateTexture(nil, "BACKGROUND")
--     end

--     frame.bg:ClearAllPoints()
--     frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", innerInset, -innerInset)
--     frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -innerInset, innerInset)

--     local bgR, bgG, bgB, bgA = 0, 0, 0, 0.6
--     if cfg.frameBgMode == "CLASS" then
--         bgR, bgG, bgB = GetClassColor(unit)
--         bgA = 0.35
--     elseif cfg.frameBgMode == "CLASSPOWER" then
--         local r1, g1, b1 = GetClassColor(unit)
--         local r2, g2, b2 = GetPowerColor(unit)
--         bgR = (r1 + r2) / 2
--         bgG = (g1 + g2) / 2
--         bgB = (b1 + b2) / 2
--         bgA = 0.45
--     end
--     frame.bg:SetColorTexture(bgR, bgG, bgB, bgA)


--     -- FrameLevel / Layering
--     local baseLevel = frame:GetFrameLevel() or 1
--     frame.healthBar:SetFrameLevel(baseLevel + 1)
--     frame.powerBar:SetFrameLevel(baseLevel + 1)
--     if frame.border then
--         frame.border:SetFrameLevel(baseLevel + 2)
--     end
--     if frame.textLayer then
--         frame.textLayer:SetFrameLevel(baseLevel + 3)
--     end

--     -------------------------------------------------
--     -- HealthBar + PowerBar Layout (wie Playerframe)
--     -------------------------------------------------
--     frame.healthBar:ClearAllPoints()

--     if cfg.manaEnabled and mpHeight > 0 then
--         -- HP oben, fester Anteil
--         frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
--         frame.healthBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
--         frame.healthBar:SetHeight(hpHeight)
--     else
--         -- Keine Mana-Bar: HP füllt den kompletten Frame
--         frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
--         frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
--     end

--     SetBarTexture(frame.healthBar, cfg.hpTexture)

--     -- HP-Farbe wie gehabt
--     local hr, hg, hb
--     if cfg.hpUseCustomColor then
--         hr = cfg.hpCustomColor.r or 0
--         hg = cfg.hpCustomColor.g or 1
--         hb = cfg.hpCustomColor.b or 0
--     elseif cfg.hpColorMode == "CLASS" then
--         hr, hg, hb = GetClassColor(unit)
--     else
--         hr, hg, hb = 0, 1, 0
--     end
--     frame.healthBar:SetStatusBarColor(hr, hg, hb, 1)

--     if not frame.healthBar.bg then
--         frame.healthBar.bg = frame.healthBar:CreateTexture(nil, "BACKGROUND")
--         frame.healthBar.bg:SetAllPoints()
--     end
--     frame.healthBar.bg:SetColorTexture(0, 0, 0, 0.6)

--     -- PowerBar Layout: direkt unter der HP-Bar, NICHT unten am Frame
--     if cfg.manaEnabled and mpHeight > 0 then
--         frame.powerBar:Show()
--         frame.powerBar:ClearAllPoints()
--         frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, 0)
--         frame.powerBar:SetPoint("TOPRIGHT", frame.healthBar, "BOTTOMRIGHT", 0, 0)
--         frame.powerBar:SetHeight(mpHeight)

--         SetBarTexture(frame.powerBar, cfg.mpTexture)

--         local pr, pg, pb
--         if cfg.mpUseCustomColor then
--             pr = cfg.mpCustomColor.r or 0
--             pg = cfg.mpCustomColor.g or 0
--             pb = cfg.mpCustomColor.b or 1
--         else
--             pr, pg, pb = GetPowerColor(unit)
--         end
--         frame.powerBar:SetStatusBarColor(pr, pg, pb, 1)

--         if not frame.powerBar.bg then
--             frame.powerBar.bg = frame.powerBar:CreateTexture(nil, "BACKGROUND")
--             frame.powerBar.bg:SetAllPoints()
--         end
--         frame.powerBar.bg:SetColorTexture(0, 0, 0, 0.6)
--     else
--         frame.powerBar:Hide()
--         if frame.powerBar.bg then
--             frame.powerBar.bg:Hide()
--         end
--     end

--     -- Border oben drauf
--     ApplyBorderLayout(frame, cfg)

--     -- Texte
--     local name = UnitName(unit) or ""
--     frame.nameText:SetText(name)

--     local lvl = UnitLevel(unit) or 0
--     local levelText = ""
--     if lvl > 0 then
--         levelText = tostring(lvl)
--     end
--     frame.levelText:SetText(levelText)

--     frame.hpText:SetText(FormatHPText(unit, cfg.hpTextMode))
--     frame.mpText:SetText(cfg.manaEnabled and FormatPowerText(unit, cfg.mpTextMode or "BOTH", pType, power or 0, powerMax) or "")

--     ApplyTextLayout(
--         frame,
--         frame.nameText,
--         cfg.showName,
--         cfg.nameSize,
--         cfg.nameAnchor,
--         cfg.nameXOffset,
--         cfg.nameYOffset,
--         cfg.nameBold,
--         cfg.nameShadow,
--         cfg.nameTextColor,
--         cfg.nameTextUseClassColor
--     )

--     ApplyTextLayout(
--         frame,
--         frame.hpText,
--         cfg.showHPText,
--         cfg.hpTextSize,
--         cfg.hpTextAnchor,
--         cfg.hpTextXOffset,
--         cfg.hpTextYOffset,
--         cfg.hpTextBold,
--         cfg.hpTextShadow,
--         cfg.hpTextColor,
--         cfg.hpTextUseClassColor
--     )

--     ApplyTextLayout(
--         frame,
--         frame.mpText,
--         cfg.manaEnabled and cfg.showMPText,
--         cfg.mpTextSize,
--         cfg.mpTextAnchor,
--         cfg.mpTextXOffset,
--         cfg.mpTextYOffset,
--         cfg.mpTextBold,
--         cfg.mpTextShadow,
--         cfg.mpTextColor,
--         cfg.mpTextUseClassColor
--     )

--     ApplyTextLayout(
--         frame,
--         frame.levelText,
--         cfg.showLevelText,
--         cfg.levelTextSize,
--         cfg.levelAnchor,
--         cfg.levelXOffset,
--         cfg.levelYOffset,
--         cfg.levelBold,
--         cfg.levelShadow,
--         cfg.levelTextColor,
--         cfg.levelTextUseClassColor
--     )
-- end

-------------------------------------------------
-- Position speichern
-------------------------------------------------

local function StoreCurrentPosition(frame)
    if not frame or frame.unit ~= "party1" then return end
    local cfg = GetPartyConfig()

    local point, _, _, xOfs, yOfs = frame:GetPoint(1)
    cfg.anchorPoint = point or "CENTER"
    cfg.anchorX     = xOfs or 0
    cfg.anchorY     = yOfs or 0
end

-------------------------------------------------
-- Health / Power + Auren / Icons
-------------------------------------------------

local function UpdateHealthAndPower(frame)
    if not frame then return end

    local unit = frame.unit
    -- nur echte, existierende Party-Units
    if type(unit) ~= "string" or not UnitExists(unit) then
        frame:Hide()
        return
    end

    local cfg = GetPartyConfig()

    -------------------------------------------------
    -- Power (Midnight-safe via pcall)
    -------------------------------------------------
    local pType = 0
    if UnitPowerType then
        local ok, pt = pcall(UnitPowerType, unit)
        if ok and type(pt) == "number" then
            pType = pt
        end
    end

    local power, powerMax = 0, 0
    if UnitPower and UnitPowerMax then
        local ok1, v1 = pcall(UnitPower, unit, pType)
        if ok1 and type(v1) == "number" then
            power = v1
        end

        local ok2, v2 = pcall(UnitPowerMax, unit, pType)
        if ok2 and type(v2) == "number" then
            powerMax = v2
        end
    end

    frame:Show()

    -------------------------------------------------
    -- HP / MP Werte & Texte
    -------------------------------------------------
    local hp    = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)
    if maxHP and maxHP > 0 then
        frame.healthBar:SetMinMaxValues(0, maxHP)
        frame.healthBar:SetValue(hp)
    end

    frame.hpText:SetText(FormatHPText(unit, cfg.hpTextMode))

    if cfg.manaEnabled then
        local cur  = power or 0
        local maxP = powerMax or 0

        if maxP and maxP > 0 then
            frame.powerBar:SetMinMaxValues(0, maxP)
            frame.powerBar:SetValue(cur)
        end

        frame.mpText:SetText(FormatPowerText(unit, cfg.mpTextMode or "BOTH", pType, power or 0, powerMax))
    else
        frame.mpText:SetText("")
    end

    -------------------------------------------------
    -- Absorb-Overlay (UnitGetTotalAbsorbs) – keine Arithmetik / Vergleiche
    -------------------------------------------------
    if frame.absorbBar and UnitGetTotalAbsorbs then
        local absorb = 0
        local ok, val = pcall(UnitGetTotalAbsorbs, unit)
        if ok and type(val) == "number" then
            absorb = val
        end

        local maxForBar = maxHP or 1
        frame.absorbBar:SetMinMaxValues(0, maxForBar)
        frame.absorbBar:SetValue(absorb or 0)
        -- immer zeigen, Breite 0 bedeutet praktisch unsichtbar
        frame.absorbBar:Show()
    end

    -------------------------------------------------
    -- Name / Level Texte
    -------------------------------------------------
    local cfg = GetPartyConfig()
    UpdateNameText(frame, cfg)


    local lvl = UnitLevel(unit) or 0
    local levelText = ""
    if lvl > 0 then
        levelText = tostring(lvl)
    end
    frame.levelText:SetText(levelText)

    -------------------------------------------------
    -- DC / Offline erkennen (UnitIsConnected) + Grau-Modus
    -------------------------------------------------
    local isConnected = true

    if UnitIsConnected then
        local ok, val = pcall(UnitIsConnected, unit)
        if ok and type(val) == "boolean" then
            isConnected = val
        end
    end

    -- Secret-Schutz: erst prüfen, ob wir den Wert benutzen dürfen
    local canUse = true
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, isConnected)
        if ok then
            canUse = allowed
        end
    end

    if canUse and (isConnected == false) then
        -------------------------------------------------
        -- OFFLINE / DC → Frame komplett grau
        -------------------------------------------------
        frame.__AI_isDC = true

        frame:SetAlpha((cfg.dcAlpha and cfg.dcAlpha > 0 and cfg.dcAlpha <= 1) and cfg.dcAlpha or 0.6)

        local grayBar = 0.3
        local grayBg  = 0.10
        local grayTxt = 0.6

        -- Healthbar grau
        frame.healthBar:SetStatusBarColor(grayBar, grayBar, grayBar, 1)
        if frame.healthBar.bg then
            frame.healthBar.bg:SetColorTexture(0, 0, 0, 0.8)
        end

        -- Powerbar grau (falls aktiv)
        if cfg.manaEnabled and frame.powerBar then
            frame.powerBar:SetStatusBarColor(grayBar, grayBar, grayBar, 1)
            if frame.powerBar.bg then
                frame.powerBar.bg:SetColorTexture(0, 0, 0, 0.8)
            end
        end

        -- Absorb-Bar in grau/transparent
        if frame.absorbBar then
            frame.absorbBar:SetStatusBarColor(grayBar, grayBar, grayBar, 0.4)
        end

        -- Hintergrund leicht grau
        if frame.bg then
            frame.bg:SetColorTexture(grayBg, grayBg, grayBg, 0.9)
        end

        -- Texte grau
        if frame.nameText  then frame.nameText:SetTextColor(grayTxt, grayTxt, grayTxt, 1) end
        if frame.hpText    then frame.hpText:SetTextColor(grayTxt, grayTxt, grayTxt, 1) end
        if frame.mpText    then frame.mpText:SetTextColor(grayTxt, grayTxt, grayTxt, 1) end
        if frame.levelText then frame.levelText:SetTextColor(grayTxt, grayTxt, grayTxt, 1) end
    else
        -------------------------------------------------
        -- Wieder online: Layout & Farben normalisieren
        -------------------------------------------------
        if frame.__AI_isDC then
            frame.__AI_isDC = false
            frame:SetAlpha(cfg.alpha or 1)

            -- Layout & Farben resetten (inkl. Absorb-Bar-Position/Farbe)
            ApplyFrameLayout(frame, cfg)

            -- HP/MP/Absorb-Werte haben wir oben frisch gesetzt, das beißt sich nicht.
        end
    end

    -------------------------------------------------
    -- Icons & Auren wie gehabt
    -------------------------------------------------
    UpdateIcons(frame)
    UpdateAuras(frame)
end



-------------------------------------------------
-- Frame-Erzeugung
-------------------------------------------------

local function CreatePartyFrame(unit)
    if frames[unit] then return frames[unit] end

    -- Safety: nur party1–party4
    if not PARTY_UNIT_LOOKUP[unit] then
        return
    end
    local cfg = GetPartyConfig()

    local f = CreateFrame("Button", "AvoidInterface_PartyFrame_"..unit, UIParent, "SecureUnitButtonTemplate")
    f.unit = unit

    local base = f:GetFrameLevel() or 1
    f:SetSize(cfg.width, cfg.height)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    -- Klicks: Links = Target, Rechts = Kontextmenü (Blizzard UnitPopup-Menü)
    f:RegisterForClicks("AnyUp")
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")  -- NEU: öffnet das Unit-Kontextmenü
    f:SetAttribute("unit", unit)


    -- Hintergrund
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.6)

    -- HealthBar
    f.healthBar = CreateFrame("StatusBar", nil, f)
    f.healthBar:SetMinMaxValues(0, 1)
    f.healthBar:SetValue(1)
    f.healthBar:SetFrameLevel(base + 1)
    SetBarTexture(f.healthBar, cfg.hpTexture)
    f.healthBar.bg = f.healthBar:CreateTexture(nil, "BACKGROUND")
    f.healthBar.bg:SetAllPoints()
    f.healthBar.bg:SetColorTexture(0, 0, 0, 0.6)

    -- Absorb-Bar (Overlay auf der HealthBar)
    f.absorbBar = CreateFrame("StatusBar", nil, f.healthBar)
    f.absorbBar:SetMinMaxValues(0, 1)
    f.absorbBar:SetValue(0)
    f.absorbBar:SetFrameLevel(f.healthBar:GetFrameLevel() + 1)
    f.absorbBar:SetAllPoints(f.healthBar)

    SetBarTexture(f.absorbBar, "ABSORB")
    f.absorbBar:SetStatusBarColor(1, 1, 1, 0.35)  -- halbtransparentes Weiß
    f.absorbBar:Hide()

    -- PowerBar
    f.powerBar = CreateFrame("StatusBar", nil, f)
    f.powerBar:SetMinMaxValues(0, 1)
    f.powerBar:SetValue(1)
    f.powerBar:SetFrameLevel(base + 1)
    SetBarTexture(f.powerBar, cfg.mpTexture)

    f.powerBar.bg = f.powerBar:CreateTexture(nil, "BACKGROUND")
    f.powerBar.bg:SetAllPoints()
    f.powerBar.bg:SetColorTexture(0, 0, 0, 0.6)

    -- Separater Text-Layer über Bars & Border
    f.textLayer = CreateFrame("Frame", nil, f)
    f.textLayer:SetAllPoints(f)
    f.textLayer:SetFrameLevel(base + 3)

    -- NEU: Icon-Layer über dem Text-Layer
    f.iconLayer = CreateFrame("Frame", nil, f)
    f.iconLayer:SetAllPoints(f)
    f.iconLayer:SetFrameLevel(base + 4)

    -- Texte auf textLayer
    f.nameText  = f.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.hpText    = f.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.mpText    = f.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.levelText = f.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    -- Icons jetzt auf iconLayer, damit sie über allem Text liegen
    f.combatIcon = f.iconLayer:CreateTexture(nil, "OVERLAY")
    f.combatIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    f.combatIcon:SetTexCoord(0.0, 0.5, 0.5, 1.0)
    f.combatIcon:Hide()

    f.restingIcon = f.iconLayer:CreateTexture(nil, "OVERLAY")
    f.restingIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    f.restingIcon:SetTexCoord(0.5, 1.0, 0.0, 0.5)
    f.restingIcon:Hide()

    f.leaderIcon = f.iconLayer:CreateTexture(nil, "OVERLAY")
    f.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    f.leaderIcon:Hide()

    f.raidIcon = f.iconLayer:CreateTexture(nil, "OVERLAY")
    f.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.raidIcon:Hide()

    -- Role-Icon (Tank/Heiler/DD)
    f.roleIcon = f.iconLayer:CreateTexture(nil, "OVERLAY")
    f.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
    f.roleIcon:Hide()

    -- Ready-Check-Icon (ready / notready / waiting)
    f.readyIcon = f.iconLayer:CreateTexture(nil, "OVERLAY")
    f.readyIcon:Hide()


    -- Auren-Buttons (werden dynamisch erzeugt)
    f.buffButtons   = {}
    f.debuffButtons = {}

    -- Mouse/Drag nur mit party1 (ganzer Block)
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and movingMode and self.unit == "party1" then
            self:StartMoving()
        end
    end)

    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and movingMode and self.unit == "party1" then
            self:StopMovingOrSizing()
            StoreCurrentPosition(self)
        end
    end)

    frames[unit] = f

    ApplyFrameLayout(f, cfg)
    UpdateHealthAndPower(f)

    return f
end

-------------------------------------------------
-- EnsureFrames
-------------------------------------------------

local function EnsureFrames()
    local cfg = GetPartyConfig()

    if cfg.enabled then
        HideBlizzardParty()
    end

    for _, unit in ipairs(PARTY_UNITS) do
        local exists = UnitExists(unit)
        local frame  = frames[unit]

        if cfg.enabled and exists then
            if not frame then
                frame = CreatePartyFrame(unit)
            end
            frame:Show()
        elseif frame then
            frame:Hide()
        end
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------

-- local function OnEvent(self, event, arg1)
--     if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
--         EnsureFrames()
--         M.ApplyLayout()
--         M.UpdateAll()
--         return
--     end

--     if event == "RAID_TARGET_UPDATE" then
--         ForEachPartyFrame(function(frame)
--             UpdateIcons(frame)
--         end)
--         return
--     end


--     local unit = arg1
--     if not unit or type(unit) ~= "string" then
--         return
--     end

--     -- Nur echte Party-Units, KEINE partypets etc.
--     if not PARTY_UNIT_LOOKUP[unit] then
--         return
--     end

--     local frame = frames[unit]
--     if not frame then
--         frame = CreatePartyFrame(unit)
--         end

--     -- NEU: Readycheck-Handling
--     if event == "READY_CHECK" then
--         -- Readycheck startet
--         readyCheckActive = true
--         M.UpdateAll()   -- aktualisiert Icons + Texte für alle Partyframes
--         return
--     end

--     if event == "READY_CHECK_CONFIRM" then
--         -- Jemand klickt Ready/NotReady
--         if readyCheckActive then
--             M.UpdateAll()
--         end
--         return
--     end

--     if event == "READY_CHECK_FINISHED" then
--         -- Readycheck vorbei → Flag aus & Icons weg
--         readyCheckActive = false
--         ForEachPartyFrame(function(frame)
--             if frame.readyIcon then
--                 frame.readyIcon:Hide()
--             end
--         end)
--         return
--     end

--     if event == "UNIT_HEALTH" or
--        event == "UNIT_MAXHEALTH" or
--        event == "UNIT_POWER_FREQUENT" or
--        event == "UNIT_MAXPOWER" or
--        event == "UNIT_DISPLAYPOWER" or
--        event == "UNIT_AURA" or
--        event == "UNIT_NAME_UPDATE" or
--        event == "UNIT_LEVEL"
--     then
--         UpdateHealthAndPower(frame)
--     end
-- end
local function OnEvent(self, event, arg1)
    -- Zonenwechsel / Gruppenänderung → Frames neu aufbauen
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        EnsureFrames()
        M.ApplyLayout()
        M.UpdateAll()
        return
    end

    -- Raidtarget-Icons
    if event == "RAID_TARGET_UPDATE" then
        ForEachPartyFrame(function(frame)
            UpdateIcons(frame)
        end)
        return
    end

    -------------------------------------------------
    -- Readycheck-Events (WICHTIG: VOR unit-Filter!)
    -------------------------------------------------
    if event == "READY_CHECK" then
        -- Readycheck startet
        readyCheckActive = true
        M.UpdateAll()   -- aktualisiert Icons + Texte für alle Partyframes
        return
    end

    if event == "READY_CHECK_CONFIRM" then
        -- Jemand klickt Ready/NotReady
        if readyCheckActive then
            M.UpdateAll()
        end
        return
    end

    if event == "READY_CHECK_FINISHED" then
        -- Readycheck vorbei → Flag aus & Icons weg
        readyCheckActive = false
        ForEachPartyFrame(function(frame)
            if frame.readyIcon then
                frame.readyIcon:Hide()
            end
        end)
        return
    end

    -------------------------------------------------
    -- Ab hier nur noch unit-basierte Events
    -------------------------------------------------
    local unit = arg1
    if not unit or type(unit) ~= "string" then
        return
    end

    -- Nur echte Party-Units, KEINE partypets etc.
    if not PARTY_UNIT_LOOKUP[unit] then
        return
    end

    local frame = frames[unit]
    if not frame then
        frame = CreatePartyFrame(unit)
    end

    if event == "UNIT_HEALTH" or
       event == "UNIT_MAXHEALTH" or
       event == "UNIT_POWER_FREQUENT" or
       event == "UNIT_MAXPOWER" or
       event == "UNIT_DISPLAYPOWER" or
       event == "UNIT_AURA" or
       event == "UNIT_NAME_UPDATE" or
       event == "UNIT_LEVEL"
    then
        UpdateHealthAndPower(frame)
    end
end

-------------------------------------------------
-- Modul-API
-------------------------------------------------

function M.ApplyLayout()
    local cfg = GetPartyConfig()

    if not cfg.enabled then
        ForEachPartyFrame(function(frame)
            frame:Hide()
        end)
        return
    end

    EnsureFrames()

    local layoutCfg = GetPartyConfig()
    ForEachPartyFrame(function(frame)
        ApplyFrameLayout(frame, layoutCfg)
        UpdateHealthAndPower(frame)
    end)
end

function M.UpdateAll()
    EnsureFrames()
    ForEachPartyFrame(function(frame)
        UpdateHealthAndPower(frame)
    end)
end

function M.StartMovingMode()
    movingMode = true
    EnsureFrames()
end

function M.StopMovingMode()
    movingMode = false
    ForEachPartyFrame(function(frame)
        frame:StopMovingOrSizing()
    end)
end

function M.ResetPosition()
    local cfg = GetPartyConfig()
    cfg.anchorPoint = "CENTER"
    cfg.anchorX     = 0
    cfg.anchorY     = 0

    M.ApplyLayout()
    M.UpdateAll()
end

function M.StoreCurrentPosition(frame)
    StoreCurrentPosition(frame)
end

function M.Enable()
    local cfg = GetPartyConfig()
    cfg.enabled = true

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", OnEvent)
    end

    if not rangeFrame then
        rangeFrame = CreateFrame("Frame")
        rangeFrame:SetScript("OnUpdate", function(self, elapsed)
            self.t = (self.t or 0) + elapsed
            if self.t < 0.2 then return end   -- alle 0.2s reicht
            self.t = 0
            UpdateAllRanges()
        end)
    end
    rangeFrame:Show()

    if SetCVar then
        pcall(SetCVar, "showPartyPets", 0)
    end

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_MAXHEALTH")
    eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
    eventFrame:RegisterEvent("UNIT_LEVEL")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("RAID_TARGET_UPDATE")

    -- NEU: Readycheck-Events
    eventFrame:RegisterEvent("READY_CHECK")
    eventFrame:RegisterEvent("READY_CHECK_CONFIRM")
    eventFrame:RegisterEvent("READY_CHECK_FINISHED")

    HideBlizzardParty()
    M.ApplyLayout()
    M.UpdateAll()
end


function M.Disable()
    local cfg = GetPartyConfig()
    cfg.enabled = false

    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end

    if rangeFrame then
        rangeFrame:Hide()
    end

    ForEachPartyFrame(function(frame)
        frame:Hide()
    end)

    RestoreBlizzardParty()
end




function M.IsEnabled()
    local cfg = GetPartyConfig()
    return cfg.enabled and true or false
end

-------------------------------------------------
-- Ende der Datei
-------------------------------------------------
