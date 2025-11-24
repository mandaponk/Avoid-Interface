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
}

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
    entry.nameSize      = entry.nameSize      or 14
    entry.hpTextSize    = entry.hpTextSize    or 12
    entry.mpTextSize    = entry.mpTextSize    or 12
    entry.levelTextSize = entry.levelTextSize or 12

    -- Anker
    entry.nameAnchor   = entry.nameAnchor   or "TOPLEFT"
    entry.hpTextAnchor = entry.hpTextAnchor or "BOTTOMRIGHT"
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

    -- Low-HP-Highlight
    if entry.lowHPHighlightEnabled == nil then
        entry.lowHPHighlightEnabled = false
    end

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

    return entry
end

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

-------------------------------------------------
-- TEXTLAYOUT
-------------------------------------------------
local function ApplyTextLayout(fs, show, size, anchor, xOff, yOff, bold, shadow)
    if not fs then return end

    if not show then
        fs:SetText("")
        fs:Hide()
        return
    end

    fs:Show()

    local baseFont = STANDARD_TEXT_FONT or (GameFontNormal and select(1, GameFontNormal:GetFont()))
    baseFont = baseFont or "Fonts\\FRIZQT__.TTF"

    local flags = ""
    if bold then
        flags = "OUTLINE"
    end

    fs:SetFont(baseFont, size or 12, flags)

    if shadow then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.9)
    else
        fs:SetShadowOffset(0, 0)
    end

    fs:ClearAllPoints()
    anchor = anchor or "CENTER"
    fs:SetPoint(anchor, frame, anchor, xOff or 0, yOff or 0)
    fs:SetDrawLayer("OVERLAY", 7)
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


    -- Rahmen anwenden
    if frame.border then
        if cfg.borderEnabled and cfg.borderSize and cfg.borderSize > 0 then
            local size = cfg.borderSize
            if size < 1 then size = 1 end
            if size > 16 then size = 16 end

            local bd = frame.border:GetBackdrop() or {}
            bd.edgeFile = "Interface\\Buttons\\WHITE8x8"
            bd.edgeSize = size
            frame.border:SetBackdrop(bd)
            frame.border:SetBackdropBorderColor(1, 1, 1, 1)
            frame.border:Show()
        else
            frame.border:Hide()
        end
    end

    -- Texte ausrichten
    local e = cfg

    ApplyTextLayout(
        frame.nameText,
        e.showName,
        e.nameSize,
        e.nameAnchor,
        e.nameXOffset,
        e.nameYOffset,
        e.nameBold,
        e.nameShadow
    )

    ApplyTextLayout(
        frame.healthText,
        e.showHPText,
        e.hpTextSize,
        e.hpTextAnchor,
        e.hpTextXOffset,
        e.hpTextYOffset,
        e.hpTextBold,
        e.hpTextShadow
    )

    ApplyTextLayout(
        frame.powerText,
        e.showMPText and e.manaEnabled,
        e.mpTextSize,
        e.mpTextAnchor,
        e.mpTextXOffset,
        e.mpTextYOffset,
        e.mpTextBold,
        e.mpTextShadow
    )

    ApplyTextLayout(
        frame.levelText,
        e.showLevelText,
        e.levelTextSize,
        e.levelAnchor,
        e.levelXOffset,
        e.levelYOffset,
        e.levelBold,
        e.levelShadow
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
    frame.healthBar:SetStatusBarColor(hr, hg, hb, 1)
    
    -- Basisfarbe für spätere Low-HP-Highlights merken
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

-- Low-HP-Highlight: nutzt UnitHealthPercent statt hp/hpMax (Midnight-safe)
-- Midnight: HP ist ein Secret Value → wir dürfen nicht rechnen oder vergleichen.
-- Deshalb ist Low-HP-Highlight aktuell deaktiviert.
local function UpdateHPHighlight(hp, hpMax)
    -- absichtlich leer
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


    -- Low-HP-Färbung anwenden (falls aktiviert)
    UpdateHPHighlight(hp, hpMax)


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


    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetAllPoints()
    frame.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame.border:SetBackdropBorderColor(1, 1, 1, 1)

        frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBarBG = frame.healthBar:CreateTexture(nil, "BACKGROUND")
    frame.healthBarBG:SetAllPoints()
    frame.healthBarBG:SetColorTexture(0, 0, 0, 0.7)

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

    elseif event == "UNIT_LEVEL" and arg1 == unit then
        UpdateHealthAndPower()
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

    -- NEU: Absorb-Events
    eventFrame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)
    eventFrame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", unit)

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
