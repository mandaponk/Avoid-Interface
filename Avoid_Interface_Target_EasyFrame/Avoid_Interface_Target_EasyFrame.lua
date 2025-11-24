-- Avoid_Interface_target_EasyFrame.lua
-- EasyFrame für "target" – ersetzt den Blizzard targetFrame optisch

local M    = {}
local unit = "target"

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
local function GettargetConfig()
    AI_Config = AI_Config or {}
    AI_Config.modules = AI_Config.modules or {}

    local entry = AI_Config.modules.target
    if type(entry) == "boolean" then
        entry = { enabled = entry }
        AI_Config.modules.target = entry
    elseif type(entry) ~= "table" then
        entry = { enabled = true }
        AI_Config.modules.target = entry
    end

    if entry.enabled == nil then entry.enabled = true end
    if entry.movable == nil then entry.movable = false end

    entry.width   = entry.width   or 260
    entry.height  = entry.height  or 60
    entry.hpRatio = entry.hpRatio or 0.66
    entry.alpha   = entry.alpha   or 1

    entry.x = entry.x or -300
    entry.y = entry.y or -200

    entry.manaEnabled = (entry.manaEnabled ~= false)

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

    -- Rahmen
    if entry.borderEnabled == nil then entry.borderEnabled = false end
    entry.borderSize = entry.borderSize or 1

    return entry
end

-------------------------------------------------
-- BLIZZARD targetFRAME AN / AUS
-------------------------------------------------
local function MakeBlizzardtargetInvisible()
    if not targetFrame then return end

    targetFrame:SetAlpha(0)
    targetFrame:EnableMouse(false)

    if targetFrame.healthbar and targetFrame.healthbar.TextString then
        targetFrame.healthbar.TextString:Hide()
    end
    if targetFrame.manabar and targetFrame.manabar.TextString then
        targetFrame.manabar.TextString:Hide()
    end
end

local function RestoreBlizzardtarget()
    if not targetFrame then return end

    targetFrame:SetAlpha(1)
    targetFrame:EnableMouse(true)

    if targetFrame.healthbar and targetFrame.healthbar.TextString then
        targetFrame.healthbar.TextString:Show()
    end
    if targetFrame.manabar and targetFrame.manabar.TextString then
        targetFrame.manabar.TextString:Show()
    end
end

-------------------------------------------------
-- POSITION SPEICHERN
-------------------------------------------------
function M.StoreCurrentPosition()
    if not frame then return end
    local cfg = GettargetConfig()
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
    local cfg = GettargetConfig()

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

-------------------------------------------------
-- BAR STYLE (TEXTURE + FARBEN + BG)
-------------------------------------------------
local function ApplyBarStyle()
    if not frame then return end
    local cfg = GettargetConfig()

    local hpTexPath = BAR_TEXTURES[cfg.hpTexture] or BAR_TEXTURES.DEFAULT
    local mpTexPath = BAR_TEXTURES[cfg.mpTexture] or BAR_TEXTURES.DEFAULT

    frame.healthBar:SetStatusBarTexture(hpTexPath)
    frame.powerBar:SetStatusBarTexture(mpTexPath)

    -- HP-Farbe
    local hr, hg, hb = 0, 1, 0
    if cfg.hpColorMode == "CLASS" then
        local _, class = UnitClass(unit)
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local c = RAID_CLASS_COLORS[class]
            hr, hg, hb = c.r, c.g, c.b
        end
    end
    frame.healthBar:SetStatusBarColor(hr, hg, hb, 1)

    if frame.healthBarBG then
        frame.healthBarBG:SetColorTexture(hr * 0.2, hg * 0.2, hb * 0.2, 0.7)
    end

    -- Mana-Farbe per PowerBarColor
    local pType = UnitPowerType(unit)
    local info  = PowerBarColor and PowerBarColor[pType] or PowerBarColor and PowerBarColor["MANA"]
    local pr, pg, pb = 0, 0, 1
    if info then
        pr, pg, pb = info.r, info.g, info.b
    end

    frame.powerBar:SetStatusBarColor(pr, pg, pb, 1)

    if frame.powerBarBG then
        frame.powerBarBG:SetColorTexture(pr * 0.2, pg * 0.2, pb * 0.2, 0.7)
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
local function UpdateHealthAndPower()
    if not frame or not frame:IsShown() then return end
    if not UnitExists(unit) then
        frame:Hide()
        return
    end

    local cfg = GettargetConfig()

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

-------------------------------------------------
-- FRAME-ERSTELLUNG
-------------------------------------------------
local function CreatetargetEasyFrame()
    if frame then return end

    local cfg = GettargetConfig()

    frame = CreateFrame("Button", "AI_target_EasyFrame", UIParent, "SecureUnitButtonTemplate")
    frame:SetFrameStrata("MEDIUM")

    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        local c = GettargetConfig()
        if c.movable then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        M.StoreCurrentPosition()
    end)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
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
    local cfg = GettargetConfig()
    if not cfg.enabled then
        if frame then frame:Hide() end
        RestoreBlizzardtarget()
        return
    end

    if event == "target_LOGIN" or event == "target_ENTERING_WORLD" then
        CreatetargetEasyFrame()
        MakeBlizzardtargetInvisible()
        ApplyFrameLayout()
        ApplyBarStyle()
        UpdateHealthAndPower()
        if frame then frame:Show() end

    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and arg1 == unit then
        UpdateHealthAndPower()

    elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER") and arg1 == unit then
        UpdateHealthAndPower()

    elseif event == "UNIT_LEVEL" and arg1 == unit then
        UpdateHealthAndPower()
    end
end

local function EnsureEventFrame()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("target_LOGIN")
    eventFrame:RegisterEvent("target_ENTERING_WORLD")
    eventFrame:RegisterUnitEvent("UNIT_HEALTH", unit)
    eventFrame:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    eventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    eventFrame:RegisterUnitEvent("UNIT_LEVEL", unit)
    eventFrame:SetScript("OnEvent", OnEvent)
end

-------------------------------------------------
-- MODUL-API
-------------------------------------------------
function M.Enable()
    local cfg = GettargetConfig()
    if not cfg.enabled then
        M.Disable()
        return
    end

    EnsureEventFrame()
    CreatetargetEasyFrame()
    MakeBlizzardtargetInvisible()
    ApplyFrameLayout()
    ApplyBarStyle()
    UpdateHealthAndPower()
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

    RestoreBlizzardtarget()
end

function M.Refresh()
    local cfg = GettargetConfig()
    if cfg.enabled then
        M.Enable()
    else
        M.Disable()
    end
end

function M.StartMovingMode()
    local cfg = GettargetConfig()
    cfg.movable = true
    if frame then
        frame:EnableMouse(true)
    end
end

function M.StopMovingMode()
    local cfg = GettargetConfig()
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
    UpdateHealthAndPower()
end

-------------------------------------------------
-- REGISTRIERUNG BEIM CORE
-------------------------------------------------
if AI and AI.RegisterFrameType then
    AI.RegisterFrameType("target", M)
else
    local temp = CreateFrame("Frame")
    temp:RegisterEvent("ADDON_LOADED")
    temp:SetScript("OnEvent", function(self, event, addon)
        if addon == "Avoid_Interface_Core" and AI and AI.RegisterFrameType then
            AI.RegisterFrameType("target", M)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end
