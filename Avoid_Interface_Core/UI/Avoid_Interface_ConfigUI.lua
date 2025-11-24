-- Avoid_Interface_ConfigUI.lua
-- Einfaches Config-Fenster mit Tabs für jedes Modul (Player, Target, ToT, Focus, Party)

local CONFIG_WIDTH  = 600
local CONFIG_HEIGHT = 800
local LEFT_MARGIN   = 16

-------------------------------------------------
-- Hauptfenster
-------------------------------------------------
local f = CreateFrame("Frame", "AvoidInterfaceConfigFrame", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(CONFIG_WIDTH, CONFIG_HEIGHT)
f:SetPoint("CENTER")
f:Hide()

f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", 0, -6)
f.title:SetText("Avoid Interface - EasyFrames")

-------------------------------------------------
-- Tabs
-------------------------------------------------
local moduleOrder = {
    { key = "player", label = "Player" },
    { key = "target", label = "Target" },
    { key = "tot",    label = "ToT"    },
    { key = "focus",  label = "Focus"  },
    { key = "party",  label = "Party"  },
}

local tabs         = {}
local scrollFrames = {}
local pages        = {}
local currentIndex = 1

local function ShowTab(index)
    currentIndex = index

    for i, sf in ipairs(scrollFrames) do
        if i == index then
            sf:Show()
        else
            sf:Hide()
        end
    end

    for i, tab in ipairs(tabs) do
        if i == index then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end
end

for i, info in ipairs(moduleOrder) do
    local tab = CreateFrame("Button", "AI_Tab_"..info.key, f, "UIPanelButtonTemplate")
    tab:SetSize(80, 22)
    tab:SetText(info.label)

    if i == 1 then
        tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 10, 5)
    else
        tab:SetPoint("LEFT", tabs[i-1], "RIGHT", 4, 0)
    end

    tab:SetScript("OnClick", function()
        ShowTab(i)
    end)

    tabs[i] = tab

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -40)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    scroll:Hide()
    scrollFrames[i] = scroll

    local page = CreateFrame("Frame", nil, scroll)
    page:SetSize(CONFIG_WIDTH - 60, 1900)
    scroll:SetScrollChild(page)
    pages[i] = page
end

-------------------------------------------------
-- Slider + Input Helper
-------------------------------------------------
local function CreateSliderWithInput(name, parent, label, minVal, maxVal, step, anchor, offsetY)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    if anchor then
        slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -32)
    else
        slider:SetPoint("TOPLEFT", parent, "TOPLEFT", LEFT_MARGIN, -90)
    end

    _G[name.."Low"]:SetText(tostring(minVal))
    _G[name.."High"]:SetText(tostring(maxVal))
    _G[name.."Text"]:SetText(label)

    slider.valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)

    local box = CreateFrame("EditBox", name.."Input", parent, "InputBoxTemplate")
    box:SetSize(50, 20)
    box:SetPoint("LEFT", slider.valueText, "RIGHT", 6, 0)
    box:SetAutoFocus(false)

    slider.inputBox = box

    local function SyncTexts(value)
        value = math.floor(value + 0.5)
        slider.valueText:SetText(value)
        slider.inputBox:SetText(tostring(value))
    end

    function slider:SetTextSync(value)
        SyncTexts(value)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        SyncTexts(value)
    end)

    box:SetScript("OnEnterPressed", function(self)
        local num = tonumber(self:GetText())
        if not num then
            SyncTexts(slider:GetValue())
            self:ClearFocus()
            return
        end
        local minV, maxV = slider:GetMinMaxValues()
        if num < minV then num = minV end
        if num > maxV then num = maxV end
        slider:SetValue(num)
        self:ClearFocus()
    end)

    box:SetScript("OnEscapePressed", function(self)
        SyncTexts(slider:GetValue())
        self:ClearFocus()
    end)

    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    return slider
end

-------------------------------------------------
-- Dropdown Helper (Label als Referenz)
-------------------------------------------------
local function CreateSimpleDropdown(name, parent, labelText, items, anchor, offsetY, belowDropdown)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")

    -- Label an die "Slider-Spalte"
    dd.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    if anchor then
        dd.label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -24)
    else
        dd.label:SetPoint("TOPLEFT", parent, "TOPLEFT", LEFT_MARGIN, -150)
    end

    dd.label:SetText(labelText or "")

    -- Dropdown direkt unter das Label, leicht nach links wegen Template-Padding
    -- if belowDropdown then
        dd:SetPoint("TOPLEFT", dd.label, "BOTTOMLEFT", 0, 0)
    -- else
    --     dd:SetPoint("TOPLEFT", dd.label, "BOTTOMLEFT", -16, -3)
    -- end

    dd.items = items
    dd.currentValue = nil

    UIDropDownMenu_SetWidth(dd, 200)
    UIDropDownMenu_Initialize(dd, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, item in ipairs(items) do
            info.text  = item.text
            info.value = item.value
            info.func  = function()
                UIDropDownMenu_SetSelectedValue(dd, item.value)
                dd.currentValue = item.value
                if dd.OnValueChanged then
                    dd:OnValueChanged(item.value)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    function dd:SetSelected(value)
        dd.currentValue = value

        -- interner Blizzard-Mechanismus
        UIDropDownMenu_SetSelectedValue(dd, value)

        -- Falls das (z.B. beim Init) keinen Eintrag findet,
        -- setzen wir den sichtbaren Text selbst.
        if value ~= nil and dd.items then
            for _, item in ipairs(dd.items) do
                if item.value == value then
                    UIDropDownMenu_SetText(dd, item.text)
                    break
                end
            end
        end
    end


    return dd
end

-------------------------------------------------
-- Player Layout direkt anwenden
-------------------------------------------------
local function ApplyPlayerLayout()
    if AI and AI.modules and AI.modules.player and AI.modules.player.ApplyLayout then
        AI.modules.player.ApplyLayout()
    end
end

-------------------------------------------------
-- Inhalt pro Tab
-------------------------------------------------
local function CreateModulePage(page, moduleKey, labelText)
    -- Speichern-Button
    local saveButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    saveButton:SetSize(90, 22)
    saveButton:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_MARGIN, -4)
    saveButton:SetText("Speichern")
    saveButton:Disable()

    function page.SetDirty(flag)
        page.dirty = flag and true or false
        if page.dirty then
            saveButton:Enable()
        else
            saveButton:Disable()
        end
    end

    -- Move-Button nur im Player-Tab
    local moveButton
    if moduleKey == "player" then
        moveButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        moveButton:SetSize(110, 22)
        moveButton:SetPoint("TOPLEFT", saveButton, "TOPRIGHT", 8, 0)
        moveButton:SetText("Frame bewegen")
    end

    local header = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_MARGIN, -36)
    header:SetText(labelText .. " EasyFrame")

    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -16)
    check.text:SetText("EasyFrame aktivieren (Blizzardframe deaktivieren)")
    check.text:SetFontObject(GameFontNormal)

    -- Player-spezifische Controls
    local widthSlider, heightSlider, ratioSlider, alphaSlider
    local manaCheck, hpClassCheck
    local hpTexDD, mpTexDD, frameBgModeDD
    local hpModeDD, mpModeDD

    local nameShow, nameSizeSlider, nameAnchorDD, nameXSlider, nameYSlider
    local hpShow,   hpSizeSlider,   hpAnchorDD,   hpXSlider,   hpYSlider
    local mpShow,   mpSizeSlider,   mpAnchorDD,   mpXSlider,   mpYSlider
    local lvlShow,  lvlSizeSlider,  lvlAnchorDD,  lvlXSlider,  lvlYSlider

    local nameBoldCheck, nameShadowCheck
    local hpBoldCheck,   hpShadowCheck
    local mpBoldCheck,   mpShadowCheck
    local lvlBoldCheck,  lvlShadowCheck

    local borderCheck, borderSizeSlider
    local lowHPCheck

    local combatIconCheck, combatIconSizeSlider, combatIconAnchorDD, combatIconXSlider, combatIconYSlider
    local restingIconCheck, restingIconSizeSlider, restingIconAnchorDD, restingIconXSlider, restingIconYSlider
    local leaderIconCheck,  leaderIconSizeSlider,  leaderIconAnchorDD,  leaderIconXSlider,  leaderIconYSlider
    local raidIconCheck,    raidIconSizeSlider,    raidIconAnchorDD,    raidIconXSlider,    raidIconYSlider


    if moduleKey == "player" then
        local texItems = {
            { value = "DEFAULT", text = "Blizzard Default" },
            { value = "RAID",    text = "Raid Bar" },
            { value = "FLAT",    text = "Flat (weiß)" },
        }

        local hpMpModeItems = {
            { value = "BOTH",    text = "Aktuell + Max" },
            { value = "PERCENT", text = "Prozent"       },
        }

        local frameBgModeItems = {
            { value = "OFF",        text = "Neutral (Standard)" },
            { value = "CLASS",      text = "Klassenfarbe (Rahmen)" },
            { value = "CLASSPOWER", text = "Klasse + Power (HP/MP-Bereich)" },
        }


        local anchorItems = {
            { value = "TOPLEFT",     text = "Oben links"     },
            { value = "TOP",         text = "Oben Mitte"     },
            { value = "TOPRIGHT",    text = "Oben rechts"    },
            { value = "LEFT",        text = "Mitte links"    },
            { value = "CENTER",      text = "Zentriert"      },
            { value = "RIGHT",       text = "Mitte rechts"   },
            { value = "BOTTOMLEFT",  text = "Unten links"    },
            { value = "BOTTOM",      text = "Unten Mitte"    },
            { value = "BOTTOMRIGHT", text = "Unten rechts"   },
        }

        -------------------------------------------------
        -- Grund-Frame / Bars
        -------------------------------------------------
        
        local sizeheader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        sizeheader:SetPoint("TOPLEFT", check, "TOPLEFT", LEFT_MARGIN, -64)
        sizeheader:SetText("EasyFrame Size")

        widthSlider = CreateSliderWithInput(
            "AI_Player_WidthSlider",
            page,
            "Frame-Breite",
            10, 600, 1,
            sizeheader,
            -32
        )

        heightSlider = CreateSliderWithInput(
            "AI_Player_HeightSlider",
            page,
            "Frame-Höhe",
            10, 600, 1,
            widthSlider,
            -32
        )

        ratioSlider = CreateSliderWithInput(
            "AI_Player_HPRatioSlider",
            page,
            "HP-Anteil (vom Frame) in %",
            10, 90, 1,
            heightSlider,
            -32
        )

        alphaSlider = CreateSliderWithInput(
            "AI_Player_AlphaSlider",
            page,
            "Frame-Alpha in %",
            10, 100, 1,
            ratioSlider,
            -32
        )

        hpClassCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpClassCheck:SetPoint("TOPLEFT", alphaSlider, "BOTTOMLEFT", 6, -48)
        hpClassCheck.text:SetText("HP Klassenfarbe verwenden")
        hpClassCheck.text:SetFontObject(GameFontNormal)

        hpTexDD = CreateSimpleDropdown(
            "AI_Player_HPTexDD",
            page,
            "HP-Bar Textur",
            texItems,
            hpClassCheck,
            -16
        )

        hpModeDD = CreateSimpleDropdown(
            "AI_Player_HPModeDD",
            page,
            "HP-Text Anzeige",
            hpMpModeItems,
            hpTexDD,
            -16
        )

        frameBgModeDD = CreateSimpleDropdown(
            "AI_Player_FrameBgModeDD",
            page,
            "Frame-Hintergrund einfärben",
            frameBgModeItems,
            hpModeDD,
            -16
        )

        manaCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        manaCheck:SetPoint("TOPLEFT", frameBgModeDD, "BOTTOMLEFT", 0, -48)
        manaCheck.text:SetText("Manabar anzeigen")
        manaCheck.text:SetFontObject(GameFontNormal)

        mpTexDD = CreateSimpleDropdown(
            "AI_Player_MPTexDD",
            page,
            "Mana-Bar Textur",
            texItems,
            manaCheck,
            -16
        )

        mpModeDD = CreateSimpleDropdown(
            "AI_Player_MPModeDD",
            page,
            "Mana-Text Anzeige",
            hpMpModeItems,
            mpTexDD,
            -32
        )

        -- Spielername
        nameShow = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        nameShow:SetPoint("TOPLEFT", mpModeDD, "BOTTOMLEFT", 0, -48)
        nameShow.text:SetText("Spielername anzeigen")
        nameShow.text:SetFontObject(GameFontNormal)

        nameAnchorDD = CreateSimpleDropdown(
            "AI_Player_NameAnchorDD",
            page,
            "Anker Spielername",
            anchorItems,
            nameShow,
            -16
        )

        nameXSlider = CreateSliderWithInput(
            "AI_Player_NameXOffsetSlider",
            page,
            "X-Offset Spielername",
            -200, 200, 1,
            nameAnchorDD,
            -32
        )

        nameYSlider = CreateSliderWithInput(
            "AI_Player_NameYOffsetSlider",
            page,
            "Y-Offset Spielername",
            -200, 200, 1,
            nameXSlider,
            -32
        )

        nameSizeSlider = CreateSliderWithInput(
            "AI_Player_NameSizeSlider",
            page,
            "Schriftgröße Spielername",
            6, 32, 1,
            nameYSlider,
            -32
        )

        nameBoldCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        nameBoldCheck:SetPoint("TOPLEFT", nameSizeSlider, "BOTTOMLEFT", 0, -24)
        nameBoldCheck.text:SetText("Fett")
        nameBoldCheck.text:SetFontObject(GameFontNormal)

        nameShadowCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        nameShadowCheck:SetPoint("LEFT", nameBoldCheck, "RIGHT", 80, 0)
        nameShadowCheck.text:SetText("Schattiert")
        nameShadowCheck.text:SetFontObject(GameFontNormal)

        

        -- HP-Text
        hpShow = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpShow:SetPoint("TOPLEFT", nameBoldCheck, "BOTTOMLEFT", 0, -48)
        hpShow.text:SetText("HP-Text anzeigen")
        hpShow.text:SetFontObject(GameFontNormal)

        hpAnchorDD = CreateSimpleDropdown(
            "AI_Player_HPAnchorDD",
            page,
            "Anker HP-Text",
            anchorItems,
            hpShow,
            -16
        )

        hpXSlider = CreateSliderWithInput(
            "AI_Player_HPXOffsetSlider",
            page,
            "X-Offset HP-Text",
            -200, 200, 1,
            hpAnchorDD,
            -32
        )

        hpYSlider = CreateSliderWithInput(
            "AI_Player_HPYOffsetSlider",
            page,
            "Y-Offset HP-Text",
            -200, 200, 1,
            hpXSlider,
            -32
        )

        hpSizeSlider = CreateSliderWithInput(
            "AI_Player_HPSizeSlider",
            page,
            "Schriftgröße HP-Text",
            6, 32, 1,
            hpYSlider,
            -32
        )

        hpBoldCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpBoldCheck:SetPoint("TOPLEFT", hpSizeSlider, "BOTTOMLEFT", 0, -24)
        hpBoldCheck.text:SetText("Fett")
        hpBoldCheck.text:SetFontObject(GameFontNormal)

        hpShadowCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpShadowCheck:SetPoint("LEFT", hpBoldCheck, "RIGHT", 80, 0)
        hpShadowCheck.text:SetText("Schattiert")
        hpShadowCheck.text:SetFontObject(GameFontNormal)


        -- Mana-Text
        mpShow = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        mpShow:SetPoint("TOPLEFT", hpBoldCheck, "BOTTOMLEFT", 0, -48)
        mpShow.text:SetText("Mana-Text anzeigen")
        mpShow.text:SetFontObject(GameFontNormal)

        mpAnchorDD = CreateSimpleDropdown(
            "AI_Player_MPAnchorDD",
            page,
            "Anker Mana-Text",
            anchorItems,
            mpShow,
            -16
        )

        mpXSlider = CreateSliderWithInput(
            "AI_Player_MPXOffsetSlider",
            page,
            "X-Offset Mana-Text",
            -200, 200, 1,
            mpAnchorDD,
            -32
        )

        mpYSlider = CreateSliderWithInput(
            "AI_Player_MPYOffsetSlider",
            page,
            "Y-Offset Mana-Text",
            -200, 200, 1,
            mpXSlider,
            -32
        )
        mpSizeSlider = CreateSliderWithInput(
            "AI_Player_MPSizeSlider",
            page,
            "Schriftgröße Mana-Text",
            6, 32, 1,
            mpYSlider,
            -32
        )

        mpBoldCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        mpBoldCheck:SetPoint("TOPLEFT", mpSizeSlider, "BOTTOMLEFT", 0, -24)
        mpBoldCheck.text:SetText("Fett")
        mpBoldCheck.text:SetFontObject(GameFontNormal)

        mpShadowCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        mpShadowCheck:SetPoint("LEFT", mpBoldCheck, "RIGHT", 80, 0)
        mpShadowCheck.text:SetText("Schattiert")
        mpShadowCheck.text:SetFontObject(GameFontNormal)


        -- Level-Text
        lvlShow = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        lvlShow:SetPoint("TOPLEFT", mpBoldCheck, "BOTTOMLEFT", 0, -48)
        lvlShow.text:SetText("Level-Text anzeigen")
        lvlShow.text:SetFontObject(GameFontNormal)

        lvlAnchorDD = CreateSimpleDropdown(
            "AI_Player_LvlAnchorDD",
            page,
            "Anker Level-Text",
            anchorItems,
            lvlShow,
            -16
        )

        lvlXSlider = CreateSliderWithInput(
            "AI_Player_LvlXOffsetSlider",
            page,
            "X-Offset Level-Text",
            -200, 200, 1,
            lvlAnchorDD,
            -32
        )

        lvlYSlider = CreateSliderWithInput(
            "AI_Player_LvlYOffsetSlider",
            page,
            "Y-Offset Level-Text",
            -200, 200, 1,
            lvlXSlider,
            -32
        )
        lvlSizeSlider = CreateSliderWithInput(
            "AI_Player_LvlSizeSlider",
            page,
            "Schriftgröße Level-Text",
            6, 32, 1,
            lvlYSlider,
            -32
        )

        lvlBoldCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        lvlBoldCheck:SetPoint("TOPLEFT", lvlSizeSlider, "BOTTOMLEFT", 0, -24)
        lvlBoldCheck.text:SetText("Fett")
        lvlBoldCheck.text:SetFontObject(GameFontNormal)

        lvlShadowCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        lvlShadowCheck:SetPoint("LEFT", lvlBoldCheck, "RIGHT", 80, 0)
        lvlShadowCheck.text:SetText("Schattiert")
        lvlShadowCheck.text:SetFontObject(GameFontNormal)


        -- Rahmen
        borderCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        borderCheck:SetPoint("TOPLEFT", lvlBoldCheck, "BOTTOMLEFT", 0, -48)
        borderCheck.text = borderCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        borderCheck.text:SetPoint("LEFT", borderCheck, "RIGHT", 4, 0)
        borderCheck.text:SetText("Rahmen anzeigen")

        borderSizeSlider = CreateSliderWithInput(
            "AI_Player_BorderSizeSlider",
            page,
            "Rahmen-Dicke",
            1, 16, 1,
            borderCheck,
            -16
        )

        -- Low-HP-Highlight
        lowHPCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        lowHPCheck:SetPoint("TOPLEFT", borderSizeSlider, "BOTTOMLEFT", 0, -32)
        lowHPCheck.text = lowHPCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lowHPCheck.text:SetPoint("LEFT", lowHPCheck, "RIGHT", 4, 0)
        lowHPCheck.text:SetText("Low-HP-Highlight aktivieren (< 30%)")

        -------------------------------------------------
        -- Icons
        -------------------------------------------------
        local iconHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconHeader:SetPoint("TOPLEFT", lowHPCheck, "BOTTOMLEFT", LEFT_MARGIN, -32)
        iconHeader:SetText("Icons")

        -- Combat-Icon
        combatIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        combatIconCheck:SetPoint("TOPLEFT", iconHeader, "BOTTOMLEFT", 0, -8)
        combatIconCheck.text = combatIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        combatIconCheck.text:SetPoint("LEFT", combatIconCheck, "RIGHT", 4, 0)
        combatIconCheck.text:SetText("Combat-Icon anzeigen")

        combatIconSizeSlider = CreateSliderWithInput(
            "AI_Player_CombatIconSizeSlider",
            page,
            "Combat-Icon Größe",
            8, 64, 1,
            combatIconCheck,
            -28
        )

        combatIconAnchorDD = CreateSimpleDropdown(
            "AI_Player_CombatIconAnchorDD",
            page,
            "Combat-Icon Anker",
            anchorItems,
            combatIconSizeSlider,
            -24
        )

        combatIconXSlider = CreateSliderWithInput(
            "AI_Player_CombatIconXOffsetSlider",
            page,
            "Combat-Icon X-Offset",
            -200, 200, 1,
            combatIconAnchorDD,
            -28
        )

        combatIconYSlider = CreateSliderWithInput(
            "AI_Player_CombatIconYOffsetSlider",
            page,
            "Combat-Icon Y-Offset",
            -200, 200, 1,
            combatIconXSlider,
            -28
        )

        -- Resting-Icon
        restingIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        restingIconCheck:SetPoint("TOPLEFT", combatIconYSlider, "BOTTOMLEFT", 0, -32)
        restingIconCheck.text = restingIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        restingIconCheck.text:SetPoint("LEFT", restingIconCheck, "RIGHT", 4, 0)
        restingIconCheck.text:SetText("Resting-Icon anzeigen")

        restingIconSizeSlider = CreateSliderWithInput(
            "AI_Player_RestingIconSizeSlider",
            page,
            "Resting-Icon Größe",
            8, 64, 1,
            restingIconCheck,
            -28
        )

        restingIconAnchorDD = CreateSimpleDropdown(
            "AI_Player_RestingIconAnchorDD",
            page,
            "Resting-Icon Anker",
            anchorItems,
            restingIconSizeSlider,
            -24
        )

        restingIconXSlider = CreateSliderWithInput(
            "AI_Player_RestingIconXOffsetSlider",
            page,
            "Resting-Icon X-Offset",
            -200, 200, 1,
            restingIconAnchorDD,
            -28
        )

        restingIconYSlider = CreateSliderWithInput(
            "AI_Player_RestingIconYOffsetSlider",
            page,
            "Resting-Icon Y-Offset",
            -200, 200, 1,
            restingIconXSlider,
            -28
        )

        -- Leader-Icon
        leaderIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        leaderIconCheck:SetPoint("TOPLEFT", restingIconYSlider, "BOTTOMLEFT", 0, -32)
        leaderIconCheck.text = leaderIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leaderIconCheck.text:SetPoint("LEFT", leaderIconCheck, "RIGHT", 4, 0)
        leaderIconCheck.text:SetText("Party-Leader-Icon anzeigen")

        leaderIconSizeSlider = CreateSliderWithInput(
            "AI_Player_LeaderIconSizeSlider",
            page,
            "Leader-Icon Größe",
            8, 64, 1,
            leaderIconCheck,
            -28
        )

        leaderIconAnchorDD = CreateSimpleDropdown(
            "AI_Player_LeaderIconAnchorDD",
            page,
            "Leader-Icon Anker",
            anchorItems,
            leaderIconSizeSlider,
            -24
        )

        leaderIconXSlider = CreateSliderWithInput(
            "AI_Player_LeaderIconXOffsetSlider",
            page,
            "Leader-Icon X-Offset",
            -200, 200, 1,
            leaderIconAnchorDD,
            -28
        )

        leaderIconYSlider = CreateSliderWithInput(
            "AI_Player_LeaderIconYOffsetSlider",
            page,
            "Leader-Icon Y-Offset",
            -200, 200, 1,
            leaderIconXSlider,
            -28
        )

        -- RaidTarget-Icon
        raidIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        raidIconCheck:SetPoint("TOPLEFT", leaderIconYSlider, "BOTTOMLEFT", 0, -32)
        raidIconCheck.text = raidIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        raidIconCheck.text:SetPoint("LEFT", raidIconCheck, "RIGHT", 4, 0)
        raidIconCheck.text:SetText("Raidtarget-Icon anzeigen")

        raidIconSizeSlider = CreateSliderWithInput(
            "AI_Player_RaidIconSizeSlider",
            page,
            "Raidtarget-Icon Größe",
            8, 64, 1,
            raidIconCheck,
            -28
        )

        raidIconAnchorDD = CreateSimpleDropdown(
            "AI_Player_RaidIconAnchorDD",
            page,
            "Raidtarget-Icon Anker",
            anchorItems,
            raidIconSizeSlider,
            -24
        )

        raidIconXSlider = CreateSliderWithInput(
            "AI_Player_RaidIconXOffsetSlider",
            page,
            "Raidtarget-Icon X-Offset",
            -200, 200, 1,
            raidIconAnchorDD,
            -28
        )

        raidIconYSlider = CreateSliderWithInput(
            "AI_Player_RaidIconYOffsetSlider",
            page,
            "Raidtarget-Icon Y-Offset",
            -200, 200, 1,
            raidIconXSlider,
            -28
        )

        -------------------------------------------------
        -- Player-Controls am Page-Objekt speichern
        -------------------------------------------------
        page.widthSlider      = widthSlider
        page.heightSlider     = heightSlider
        page.ratioSlider      = ratioSlider
        page.alphaSlider      = alphaSlider

        page.manaCheck        = manaCheck
        page.hpClassCheck     = hpClassCheck
        page.hpTexDD          = hpTexDD
        page.mpTexDD          = mpTexDD
        page.hpModeDD         = hpModeDD
        page.mpModeDD         = mpModeDD
        page.frameBgModeDD    = frameBgModeDD

        page.nameShow         = nameShow
        page.nameSizeSlider   = nameSizeSlider
        page.nameAnchorDD     = nameAnchorDD
        page.nameXSlider      = nameXSlider
        page.nameYSlider      = nameYSlider

        page.hpShow           = hpShow
        page.hpSizeSlider     = hpSizeSlider
        page.hpAnchorDD       = hpAnchorDD
        page.hpXSlider        = hpXSlider
        page.hpYSlider        = hpYSlider

        page.mpShow           = mpShow
        page.mpSizeSlider     = mpSizeSlider
        page.mpAnchorDD       = mpAnchorDD
        page.mpXSlider        = mpXSlider
        page.mpYSlider        = mpYSlider

        page.lvlShow          = lvlShow
        page.lvlSizeSlider    = lvlSizeSlider
        page.lvlAnchorDD      = lvlAnchorDD
        page.lvlXSlider       = lvlXSlider
        page.lvlYSlider       = lvlYSlider

        page.nameBoldCheck    = nameBoldCheck
        page.nameShadowCheck  = nameShadowCheck
        page.hpBoldCheck      = hpBoldCheck
        page.hpShadowCheck    = hpShadowCheck
        page.mpBoldCheck      = mpBoldCheck
        page.mpShadowCheck    = mpShadowCheck
        page.lvlBoldCheck     = lvlBoldCheck
        page.lvlShadowCheck   = lvlShadowCheck

        page.borderCheck      = borderCheck
        page.borderSizeSlider = borderSizeSlider

        page.lowHPCheck       = lowHPCheck

        page.combatIconCheck        = combatIconCheck
        page.combatIconSizeSlider   = combatIconSizeSlider
        page.combatIconAnchorDD     = combatIconAnchorDD
        page.combatIconXSlider      = combatIconXSlider
        page.combatIconYSlider      = combatIconYSlider

        page.restingIconCheck       = restingIconCheck
        page.restingIconSizeSlider  = restingIconSizeSlider
        page.restingIconAnchorDD    = restingIconAnchorDD
        page.restingIconXSlider     = restingIconXSlider
        page.restingIconYSlider     = restingIconYSlider

        page.leaderIconCheck        = leaderIconCheck
        page.leaderIconSizeSlider   = leaderIconSizeSlider
        page.leaderIconAnchorDD     = leaderIconAnchorDD
        page.leaderIconXSlider      = leaderIconXSlider
        page.leaderIconYSlider      = leaderIconYSlider

        page.raidIconCheck          = raidIconCheck
        page.raidIconSizeSlider     = raidIconSizeSlider
        page.raidIconAnchorDD       = raidIconAnchorDD
        page.raidIconXSlider        = raidIconXSlider
        page.raidIconYSlider        = raidIconYSlider
    end

    -------------------------------------------------
    -- Init
    -------------------------------------------------
    page.Init = function()
        AI_Config = AI_Config or {}
        AI_Config.modules = AI_Config.modules or {}
        local entry = AI_Config.modules[moduleKey]

        if type(entry) == "boolean" then
            entry = { enabled = entry }
            AI_Config.modules[moduleKey] = entry
        elseif type(entry) ~= "table" then
            entry = { enabled = (moduleKey == "player") }
            AI_Config.modules[moduleKey] = entry
        elseif entry.enabled == nil then
            entry.enabled = (moduleKey == "player")
        end

        check:SetChecked(entry.enabled and true or false)

            if moduleKey == "player" then
        -- Defaults wie im Player-Modul
        entry.width       = entry.width       or 260
        entry.height      = entry.height      or 60
        entry.hpRatio     = entry.hpRatio     or 0.66
        entry.alpha       = entry.alpha       or 1
        entry.manaEnabled = (entry.manaEnabled ~= false)

        -- Referenz auf Controls am Page-Objekt
        -- (das sind lokale Variablen von page.Init, keine Upvalues)
        local widthSlider      = page.widthSlider
        local heightSlider     = page.heightSlider
        local ratioSlider      = page.ratioSlider
        local alphaSlider      = page.alphaSlider

        local manaCheck        = page.manaCheck
        local hpClassCheck     = page.hpClassCheck
        local hpTexDD          = page.hpTexDD
        local mpTexDD          = page.mpTexDD
        local hpModeDD         = page.hpModeDD
        local mpModeDD         = page.mpModeDD
        local frameBgModeDD    = page.frameBgModeDD

        local nameShow         = page.nameShow
        local nameSizeSlider   = page.nameSizeSlider
        local nameAnchorDD     = page.nameAnchorDD
        local nameXSlider      = page.nameXSlider
        local nameYSlider      = page.nameYSlider

        local hpShow           = page.hpShow
        local hpSizeSlider     = page.hpSizeSlider
        local hpAnchorDD       = page.hpAnchorDD
        local hpXSlider        = page.hpXSlider
        local hpYSlider        = page.hpYSlider

        local mpShow           = page.mpShow
        local mpSizeSlider     = page.mpSizeSlider
        local mpAnchorDD       = page.mpAnchorDD
        local mpXSlider        = page.mpXSlider
        local mpYSlider        = page.mpYSlider

        local lvlShow          = page.lvlShow
        local lvlSizeSlider    = page.lvlSizeSlider
        local lvlAnchorDD      = page.lvlAnchorDD
        local lvlXSlider       = page.lvlXSlider
        local lvlYSlider       = page.lvlYSlider

        local nameBoldCheck    = page.nameBoldCheck
        local nameShadowCheck  = page.nameShadowCheck
        local hpBoldCheck      = page.hpBoldCheck
        local hpShadowCheck    = page.hpShadowCheck
        local mpBoldCheck      = page.mpBoldCheck
        local mpShadowCheck    = page.mpShadowCheck
        local lvlBoldCheck     = page.lvlBoldCheck
        local lvlShadowCheck   = page.lvlShadowCheck

        local borderCheck      = page.borderCheck
        local borderSizeSlider = page.borderSizeSlider
        local lowHPCheck       = page.lowHPCheck

        local combatIconCheck       = page.combatIconCheck
        local combatIconSizeSlider  = page.combatIconSizeSlider
        local combatIconAnchorDD    = page.combatIconAnchorDD
        local combatIconXSlider     = page.combatIconXSlider
        local combatIconYSlider     = page.combatIconYSlider

        local restingIconCheck      = page.restingIconCheck
        local restingIconSizeSlider = page.restingIconSizeSlider
        local restingIconAnchorDD   = page.restingIconAnchorDD
        local restingIconXSlider    = page.restingIconXSlider
        local restingIconYSlider    = page.restingIconYSlider

        local leaderIconCheck       = page.leaderIconCheck
        local leaderIconSizeSlider  = page.leaderIconSizeSlider
        local leaderIconAnchorDD    = page.leaderIconAnchorDD
        local leaderIconXSlider     = page.leaderIconXSlider
        local leaderIconYSlider     = page.leaderIconYSlider

        local raidIconCheck         = page.raidIconCheck
        local raidIconSizeSlider    = page.raidIconSizeSlider
        local raidIconAnchorDD      = page.raidIconAnchorDD
        local raidIconXSlider       = page.raidIconXSlider
        local raidIconYSlider       = page.raidIconYSlider

        -- Defaults für Text / Farben / Icons
        if entry.hpColorMode ~= "CLASS" and entry.hpColorMode ~= "DEFAULT" then
            entry.hpColorMode = "CLASS"
        end

        entry.hpTexture = entry.hpTexture or "DEFAULT"
        entry.mpTexture = entry.mpTexture or "DEFAULT"

        if entry.frameBgMode ~= "OFF" and entry.frameBgMode ~= "CLASS" and entry.frameBgMode ~= "CLASSPOWER" then
            entry.frameBgMode = "OFF"
        end

        if entry.hpTextMode ~= "PERCENT" and entry.hpTextMode ~= "BOTH" then
            entry.hpTextMode = "BOTH"
        end
        if entry.mpTextMode ~= "PERCENT" and entry.mpTextMode ~= "BOTH" then
            entry.mpTextMode = "BOTH"
        end

        entry.showName      = (entry.showName      ~= false)
        entry.showHPText    = (entry.showHPText    ~= false)
        entry.showMPText    = (entry.showMPText    ~= false)
        entry.showLevelText = (entry.showLevelText ~= false)

        entry.nameSize      = entry.nameSize      or 14
        entry.hpTextSize    = entry.hpTextSize    or 12
        entry.mpTextSize    = entry.mpTextSize    or 12
        entry.levelTextSize = entry.levelTextSize or 12

        entry.nameAnchor   = entry.nameAnchor   or "TOPLEFT"
        entry.hpTextAnchor = entry.hpTextAnchor or "BOTTOMRIGHT"
        entry.mpTextAnchor = entry.mpTextAnchor or "BOTTOMRIGHT"
        entry.levelAnchor  = entry.levelAnchor  or "BOTTOMLEFT"

        entry.nameXOffset   = entry.nameXOffset   or 0
        entry.nameYOffset   = entry.nameYOffset   or 0
        entry.hpTextXOffset = entry.hpTextXOffset or 0
        entry.hpTextYOffset = entry.hpTextYOffset or 0
        entry.mpTextXOffset = entry.mpTextXOffset or 0
        entry.mpTextYOffset = entry.mpTextYOffset or 0
        entry.levelXOffset  = entry.levelXOffset  or 0
        entry.levelYOffset  = entry.levelYOffset  or 0

        if entry.nameBold   == nil then entry.nameBold   = false end
        if entry.nameShadow == nil then entry.nameShadow = true  end
        if entry.hpTextBold   == nil then entry.hpTextBold   = false end
        if entry.hpTextShadow == nil then entry.hpTextShadow = true  end
        if entry.mpTextBold   == nil then entry.mpTextBold   = false end
        if entry.mpTextShadow == nil then entry.mpTextShadow = true  end
        if entry.levelBold   == nil then entry.levelBold   = false end
        if entry.levelShadow == nil then entry.levelShadow = true  end

        if entry.borderEnabled == nil then entry.borderEnabled = false end
        entry.borderSize = entry.borderSize or 1

        if entry.lowHPHighlightEnabled == nil then
            entry.lowHPHighlightEnabled = false
        end

        -- Icon-Defaults (nur für Config-UI, eigentliche Logik ist im Player-Modul)
        if entry.combatIconEnabled == nil then entry.combatIconEnabled = true end
        if entry.restingIconEnabled == nil then entry.restingIconEnabled = true end
        if entry.leaderIconEnabled  == nil then entry.leaderIconEnabled  = true end
        if entry.raidIconEnabled    == nil then entry.raidIconEnabled    = true end

        entry.combatIconSize   = entry.combatIconSize   or 24
        entry.restingIconSize  = entry.restingIconSize  or 24
        entry.leaderIconSize   = entry.leaderIconSize   or 18
        entry.raidIconSize     = entry.raidIconSize     or 20

        entry.combatIconAnchor  = entry.combatIconAnchor  or "TOPLEFT"
        entry.restingIconAnchor = entry.restingIconAnchor or "TOPLEFT"
        entry.leaderIconAnchor  = entry.leaderIconAnchor  or "TOPRIGHT"
        entry.raidIconAnchor    = entry.raidIconAnchor    or "TOP"

        entry.combatIconXOffset  = entry.combatIconXOffset  or -4
        entry.combatIconYOffset  = entry.combatIconYOffset  or 4
        entry.restingIconXOffset = entry.restingIconXOffset or -4
        entry.restingIconYOffset = entry.restingIconYOffset or 4
        entry.leaderIconXOffset  = entry.leaderIconXOffset  or 4
        entry.leaderIconYOffset  = entry.leaderIconYOffset  or 4
        entry.raidIconXOffset    = entry.raidIconXOffset    or 0
        entry.raidIconYOffset    = entry.raidIconYOffset    or 10

        -- Slider & Checks setzen
        widthSlider:SetValue(entry.width);        widthSlider:SetTextSync(entry.width)
        heightSlider:SetValue(entry.height);      heightSlider:SetTextSync(entry.height)

        local ratioPercent = math.floor((entry.hpRatio or 0.66) * 100 + 0.5)
        ratioSlider:SetValue(ratioPercent);       ratioSlider:SetTextSync(ratioPercent)

        local alphaPercent = math.floor((entry.alpha or 1) * 100 + 0.5)
        alphaSlider:SetValue(alphaPercent);       alphaSlider:SetTextSync(alphaPercent)

        manaCheck:SetChecked(entry.manaEnabled)
        hpClassCheck:SetChecked(entry.hpColorMode == "CLASS")

        hpTexDD:SetSelected(entry.hpTexture)
        mpTexDD:SetSelected(entry.mpTexture)
        frameBgModeDD:SetSelected(entry.frameBgMode)

        hpModeDD:SetSelected(entry.hpTextMode)
        mpModeDD:SetSelected(entry.mpTextMode)

        nameShow:SetChecked(entry.showName)
        hpShow:SetChecked(entry.showHPText)
        mpShow:SetChecked(entry.showMPText)
        lvlShow:SetChecked(entry.showLevelText)

        nameSizeSlider:SetValue(entry.nameSize);     nameSizeSlider:SetTextSync(entry.nameSize)
        hpSizeSlider:SetValue(entry.hpTextSize);     hpSizeSlider:SetTextSync(entry.hpTextSize)
        mpSizeSlider:SetValue(entry.mpTextSize);     mpSizeSlider:SetTextSync(entry.mpTextSize)
        lvlSizeSlider:SetValue(entry.levelTextSize); lvlSizeSlider:SetTextSync(entry.levelTextSize)

        nameAnchorDD:SetSelected(entry.nameAnchor)
        hpAnchorDD:SetSelected(entry.hpTextAnchor)
        mpAnchorDD:SetSelected(entry.mpTextAnchor)
        lvlAnchorDD:SetSelected(entry.levelAnchor)

        nameXSlider:SetValue(entry.nameXOffset);   nameXSlider:SetTextSync(entry.nameXOffset)
        nameYSlider:SetValue(entry.nameYOffset);   nameYSlider:SetTextSync(entry.nameYOffset)
        hpXSlider:SetValue(entry.hpTextXOffset);   hpXSlider:SetTextSync(entry.hpTextXOffset)
        hpYSlider:SetValue(entry.hpTextYOffset);   hpYSlider:SetTextSync(entry.hpTextYOffset)
        mpXSlider:SetValue(entry.mpTextXOffset);   mpXSlider:SetTextSync(entry.mpTextXOffset)
        mpYSlider:SetValue(entry.mpTextYOffset);   mpYSlider:SetTextSync(entry.mpTextYOffset)
        lvlXSlider:SetValue(entry.levelXOffset);   lvlXSlider:SetTextSync(entry.levelXOffset)
        lvlYSlider:SetValue(entry.levelYOffset);   lvlYSlider:SetTextSync(entry.levelYOffset)

        nameBoldCheck:SetChecked(entry.nameBold)
        nameShadowCheck:SetChecked(entry.nameShadow)
        hpBoldCheck:SetChecked(entry.hpTextBold)
        hpShadowCheck:SetChecked(entry.hpTextShadow)
        mpBoldCheck:SetChecked(entry.mpTextBold)
        mpShadowCheck:SetChecked(entry.mpTextShadow)
        lvlBoldCheck:SetChecked(entry.levelBold)
        lvlShadowCheck:SetChecked(entry.levelShadow)

        borderCheck:SetChecked(entry.borderEnabled)
        borderSizeSlider:SetValue(entry.borderSize); borderSizeSlider:SetTextSync(entry.borderSize)

        lowHPCheck:SetChecked(entry.lowHPHighlightEnabled)

        combatIconCheck:SetChecked(entry.combatIconEnabled)
        combatIconSizeSlider:SetValue(entry.combatIconSize); combatIconSizeSlider:SetTextSync(entry.combatIconSize)
        combatIconAnchorDD:SetSelected(entry.combatIconAnchor)
        combatIconXSlider:SetValue(entry.combatIconXOffset); combatIconXSlider:SetTextSync(entry.combatIconXOffset)
        combatIconYSlider:SetValue(entry.combatIconYOffset); combatIconYSlider:SetTextSync(entry.combatIconYOffset)

        restingIconCheck:SetChecked(entry.restingIconEnabled)
        restingIconSizeSlider:SetValue(entry.restingIconSize); restingIconSizeSlider:SetTextSync(entry.restingIconSize)
        restingIconAnchorDD:SetSelected(entry.restingIconAnchor)
        restingIconXSlider:SetValue(entry.restingIconXOffset); restingIconXSlider:SetTextSync(entry.restingIconXOffset)
        restingIconYSlider:SetValue(entry.restingIconYOffset); restingIconYSlider:SetTextSync(entry.restingIconYOffset)

        leaderIconCheck:SetChecked(entry.leaderIconEnabled)
        leaderIconSizeSlider:SetValue(entry.leaderIconSize); leaderIconSizeSlider:SetTextSync(entry.leaderIconSize)
        leaderIconAnchorDD:SetSelected(entry.leaderIconAnchor)
        leaderIconXSlider:SetValue(entry.leaderIconXOffset); leaderIconXSlider:SetTextSync(entry.leaderIconXOffset)
        leaderIconYSlider:SetValue(entry.leaderIconYOffset); leaderIconYSlider:SetTextSync(entry.leaderIconYOffset)

        raidIconCheck:SetChecked(entry.raidIconEnabled)
        raidIconSizeSlider:SetValue(entry.raidIconSize); raidIconSizeSlider:SetTextSync(entry.raidIconSize)
        raidIconAnchorDD:SetSelected(entry.raidIconAnchor)
        raidIconXSlider:SetValue(entry.raidIconXOffset); raidIconXSlider:SetTextSync(entry.raidIconXOffset)
        raidIconYSlider:SetValue(entry.raidIconYOffset); raidIconYSlider:SetTextSync(entry.raidIconYOffset)
    end


        page.SetDirty(false)
    end

    -------------------------------------------------
    -- Hooks / Logik
    -------------------------------------------------
    check:SetScript("OnClick", function(self)
        AI_Config.modules = AI_Config.modules or {}
        AI_Config.modules[moduleKey] = AI_Config.modules[moduleKey] or {}
        AI_Config.modules[moduleKey].enabled = self:GetChecked() and true or false

        if AI and AI.RefreshModule then
            AI.RefreshModule(moduleKey)
        end

        page.SetDirty(true)
    end)

    if moduleKey == "player" then
        local function markDirtyAndApply()
            page.SetDirty(true)
            ApplyPlayerLayout()
        end

        widthSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.width = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        heightSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.height = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        ratioSlider:HookScript("OnValueChanged", function(self, value)
            local ratio = value / 100
            if ratio < 0.1 then ratio = 0.1 end
            if ratio > 0.9 then ratio = 0.9 end
            AI_Config.modules.player.hpRatio = ratio
            markDirtyAndApply()
        end)

        alphaSlider:HookScript("OnValueChanged", function(self, value)
            local alpha = value / 100
            if alpha < 0.1 then alpha = 0.1 end
            if alpha > 1.0 then alpha = 1.0 end
            AI_Config.modules.player.alpha = alpha
            markDirtyAndApply()
        end)

        manaCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.manaEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        hpClassCheck:SetScript("OnClick", function(self)
            if self:GetChecked() then
                AI_Config.modules.player.hpColorMode = "CLASS"
            else
                AI_Config.modules.player.hpColorMode = "DEFAULT"
            end
            markDirtyAndApply()
        end)

        function hpTexDD:OnValueChanged(value)
            AI_Config.modules.player.hpTexture = value
            markDirtyAndApply()
        end

        function mpTexDD:OnValueChanged(value)
            AI_Config.modules.player.mpTexture = value
            markDirtyAndApply()
        end

        function frameBgModeDD:OnValueChanged(value)
            AI_Config.modules.player.frameBgMode = value
            markDirtyAndApply()
        end

        function hpModeDD:OnValueChanged(value)
            AI_Config.modules.player.hpTextMode = value
            markDirtyAndApply()
        end

        function mpModeDD:OnValueChanged(value)
            AI_Config.modules.player.mpTextMode = value
            markDirtyAndApply()
        end


        -- Textsichtbarkeit
        nameShow:SetScript("OnClick", function(self)
            AI_Config.modules.player.showName = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        hpShow:SetScript("OnClick", function(self)
            AI_Config.modules.player.showHPText = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        mpShow:SetScript("OnClick", function(self)
            AI_Config.modules.player.showMPText = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        lvlShow:SetScript("OnClick", function(self)
            AI_Config.modules.player.showLevelText = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        -- Schriftgrößen
        nameSizeSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.nameSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        hpSizeSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.hpTextSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        mpSizeSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.mpTextSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        lvlSizeSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.levelTextSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        -- Anchor Dropdowns
        function nameAnchorDD:OnValueChanged(value)
            AI_Config.modules.player.nameAnchor = value
            markDirtyAndApply()
        end
        function hpAnchorDD:OnValueChanged(value)
            AI_Config.modules.player.hpTextAnchor = value
            markDirtyAndApply()
        end
        function mpAnchorDD:OnValueChanged(value)
            AI_Config.modules.player.mpTextAnchor = value
            markDirtyAndApply()
        end
        function lvlAnchorDD:OnValueChanged(value)
            AI_Config.modules.player.levelAnchor = value
            markDirtyAndApply()
        end

        -- Offsets
        nameXSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.nameXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        nameYSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.nameYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        hpXSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.hpTextXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        hpYSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.hpTextYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        mpXSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.mpTextXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        mpYSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.mpTextYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        lvlXSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.levelXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        lvlYSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.levelYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        -- Bold / Shadow
        nameBoldCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.nameBold = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        nameShadowCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.nameShadow = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        hpBoldCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.hpTextBold = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        hpShadowCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.hpTextShadow = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        mpBoldCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.mpTextBold = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        mpShadowCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.mpTextShadow = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        lvlBoldCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.levelBold = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        lvlShadowCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.levelShadow = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        -- Rahmen
        borderCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.borderEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        borderSizeSlider:HookScript("OnValueChanged", function(self, value)
            AI_Config.modules.player.borderSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        -- Low-HP-Highlight
        lowHPCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.lowHPHighlightEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        -- Combat Icon
        combatIconCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.combatIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        combatIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.combatIconSize = value
            markDirtyAndApply()
        end)

        function combatIconAnchorDD:OnValueChanged(value)
            AI_Config.modules.player.combatIconAnchor = value
            markDirtyAndApply()
        end

        combatIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.combatIconXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        combatIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.combatIconYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        -- Resting Icon
        restingIconCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.restingIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        restingIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.restingIconSize = value
            markDirtyAndApply()
        end)

        function restingIconAnchorDD:OnValueChanged(value)
            AI_Config.modules.player.restingIconAnchor = value
            markDirtyAndApply()
        end

        restingIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.restingIconXOffset = value
            markDirtyAndApply()
        end)

        restingIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.restingIconYOffset = value
            markDirtyAndApply()
        end)

        -- Leader Icon
        leaderIconCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.leaderIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        leaderIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.leaderIconSize = value
            markDirtyAndApply()
        end)

        function leaderIconAnchorDD:OnValueChanged(value)
            AI_Config.modules.player.leaderIconAnchor = value
            markDirtyAndApply()
        end

        leaderIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.leaderIconXOffset = value
            markDirtyAndApply()
        end)

        leaderIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.leaderIconYOffset = value
            markDirtyAndApply()
        end)

        -- Raid Icon
        raidIconCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.raidIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        raidIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.raidIconSize = value
            markDirtyAndApply()
        end)

        function raidIconAnchorDD:OnValueChanged(value)
            AI_Config.modules.player.raidIconAnchor = value
            markDirtyAndApply()
        end

        raidIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.raidIconXOffset = value
            markDirtyAndApply()
        end)

        raidIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules.player.raidIconYOffset = value
            markDirtyAndApply()
        end)

    end

    -------------------------------------------------
    -- Move-Button
    -------------------------------------------------
    if moveButton then
        moveButton:SetScript("OnClick", function(self)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules[moduleKey] = AI_Config.modules[moduleKey] or {}
            local cfg = AI_Config.modules[moduleKey]

            cfg.movable = not cfg.movable

            if cfg.movable then
                self:SetText("Beenden")
                if AI and AI.modules and AI.modules.player and AI.modules.player.StartMovingMode then
                    AI.modules.player.StartMovingMode()
                end
            else
                self:SetText("Frame bewegen")
                if AI and AI.modules and AI.modules.player and AI.modules.player.StopMovingMode then
                    AI.modules.player.StopMovingMode()
                end
            end

            page.SetDirty(true)
        end)
    end

    -------------------------------------------------
    -- Speichern
    -------------------------------------------------
    saveButton:SetScript("OnClick", function()
        AI_Config.modules = AI_Config.modules or {}
        AI_Config.modules[moduleKey] = AI_Config.modules[moduleKey] or {}
        local entry = AI_Config.modules[moduleKey]

        entry.enabled = check:GetChecked() and true or false

        if AI and AI.RefreshModule then
            AI.RefreshModule(moduleKey)
        end

        if moduleKey == "player"
            and AI and AI.modules and AI.modules.player
            and AI.modules.player.StoreCurrentPosition
        then
            AI.modules.player.StoreCurrentPosition()
        end

        page.SetDirty(false)
    end)

end

for i, info in ipairs(moduleOrder) do
    CreateModulePage(pages[i], info.key, info.label)
end

f:SetScript("OnShow", function()
    for i, info in ipairs(moduleOrder) do
        if pages[i].Init then
            pages[i].Init()
        end
    end
    ShowTab(currentIndex or 1)
end)
