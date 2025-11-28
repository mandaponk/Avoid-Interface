-- Avoid_Interface_Player_ConfigUI.lua
-- Baut die "Player"-Seite im gemeinsamen Avoid Interface Config-Fenster
AI       = AI or {}
AI.ConfigUI = AI.ConfigUI or {}

-- Stellt sicher, dass AI_Config.modules[moduleKey] existiert
local function GetTargetEntry(moduleKey)
    AI_Config = AI_Config or {}
    AI_Config.modules = AI_Config.modules or {}
    AI_Config.modules[moduleKey] = AI_Config.modules[moduleKey] or {}

    return AI_Config.modules[moduleKey]
end

local function GetPlayerModule()
    if AI and AI.modules and type(AI.modules.player) == "table" then
        return AI.modules.player
    end
end

-- Hilfsfunktion: wendet das Layout des Player-Frames neu an
local function ApplyPlayerLayout()
    -- Versuchen, direkt das Player-Modul zu erwischen
    if AI and AI.modules and type(AI.modules.player) == "table" then
        local m = AI.modules.player

        if m.ApplyLayout then
            -- Sauberer Weg: bestehendes ApplyLayout aus dem Player-Modul nutzen
            m.ApplyLayout()
            return
        end
    end

    -- Fallback: komplettes Modul refreshen, falls das Modul-Objekt (noch) nicht greifbar ist
    if AI and AI.RefreshModule then
        AI.RefreshModule("player")
    end
end

local function BuildPlayerConfigPage(page, moduleKey, labelText, helpers)

    
    local header = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")-- Kurz auf die Helper zugreifen:
    
    local CreateSliderWithInput = helpers.CreateSliderWithInput
    local CreateSimpleDropdown  = helpers.CreateSimpleDropdown
    local LEFT_MARGIN           = helpers.LEFT_MARGIN

    header:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT_MARGIN, -36)
    header:SetText(labelText .. " EasyFrame")

        -------------------------------------------------
    -- Preset-Auswahl (Dropdown + „Anwenden“-Button)
    -------------------------------------------------
    local presetDropdown
    local presetApplyButton

    do
        local m = GetPlayerModule()
        local presetItems = {}
        local presetKeys  = {}

        if m and m.GetPresets then
            local presets = m.GetPresets()
            for key in pairs(presets) do
                table.insert(presetKeys, key)
            end
            table.sort(presetKeys)

            for _, key in ipairs(presetKeys) do
                table.insert(presetItems, {
                    value = key,
                    text  = key,
                })
            end
        end

        local selectedPresetKey = presetKeys[1]

        -- Hier jetzt die korrekte Signatur:
        -- name (String), parent, labelText, items, anchor, offsetY
        presetDropdown = CreateSimpleDropdown(
            "AI_Player_PresetDD",   -- Name (STRING!)
            page,                   -- Parent
            "Preset",               -- Label
            presetItems,            -- Items
            header,                 -- Anker unter dem Header
            -32                      -- Y-Offset
        )

        -- Startwert anzeigen
        if selectedPresetKey then
            presetDropdown:SetSelected(selectedPresetKey)
        end

        -- Dropdown-Änderung merken
        function presetDropdown:OnValueChanged(newValue)
            selectedPresetKey = newValue
        end

        -- Button „Anwenden“
        presetApplyButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        presetApplyButton:SetSize(90, 22)
        presetApplyButton:SetPoint("LEFT", presetDropdown, "RIGHT", 8, 0)
        presetApplyButton:SetText("Anwenden")

        presetApplyButton:SetScript("OnClick", function()
            local m = GetPlayerModule()
            if not (m and m.ApplyPreset and selectedPresetKey) then
                return
            end

            -- Preset ins Config schreiben + Layout neu aufbauen
            m.ApplyPreset(selectedPresetKey)

            -- UI-Slider/Farben neu einlesen
            if page.Init then
                page.Init()
            end

            -- nix „unsaved“, Preset ist direkt live
            page.SetDirty(false)
        end)
    end

    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", presetDropdown, "BOTTOMLEFT", 0, -32)
    check.text:SetText("EasyFrame aktivieren (Blizzardframe deaktivieren)")
    check.text:SetFontObject(GameFontNormal)

    -------------------------------------------------
    -- Move- und Reset-Buttons (nur Player-Frame)
    -------------------------------------------------
    local moveButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    moveButton:SetSize(120, 22)
    moveButton:SetPoint("LEFT", header, "RIGHT", 16, 0)
    moveButton:SetText("Frame bewegen")

    local resetPosButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    resetPosButton:SetSize(80, 22)
    resetPosButton:SetPoint("LEFT", moveButton, "RIGHT", 8, 0)
    resetPosButton:SetText("Reset")

    -- interner Zustand: sind wir gerade im Move-Modus?
    page.__isMoving = false

    moveButton:SetScript("OnClick", function(self)
        local m = GetPlayerModule()
        if not m then return end

        if page.__isMoving then
            -- Move-Modus beenden und Position speichern
            if m.StopMovingMode then m.StopMovingMode() end
            self:SetText("Frame bewegen")
            page.__isMoving = false
        else
            -- Move-Modus starten: Frame mit linker Maustaste ziehen
            if m.StartMovingMode then m.StartMovingMode() end
            self:SetText("Bewegung beenden")
            page.__isMoving = true
        end
    end)

    resetPosButton:SetScript("OnClick", function()
        local m = GetPlayerModule()
        if not m then return end

        -- Zur Sicherheit Move-Modus aus
        if m.StopMovingMode then m.StopMovingMode() end
        page.__isMoving = false
        moveButton:SetText("Frame bewegen")

        -- Position auf Default zurücksetzen
        if m.ResetPosition then m.ResetPosition() end

        -- Falls vorhanden: Layout neu anwenden
        if m.ApplyLayout then
            m.ApplyLayout()
        elseif AI and AI.RefreshModule then
            AI.RefreshModule("player")
        end
    end)

    -- Wenn die Seite geschlossen wird, Move-Modus sauber beenden
    local oldOnHide = page:GetScript("OnHide")
    page:SetScript("OnHide", function(self, ...)
        if oldOnHide then
            oldOnHide(self, ...)
        end

        local m = GetPlayerModule()
        if m and m.StopMovingMode then
            m.StopMovingMode()
        end
        self.__isMoving = false
        if moveButton then
            moveButton:SetText("Frame bewegen")
        end
    end)


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

    local borderCheck, borderSizeSlider, borderStyleDD
    local lowHPCheck

    -- NEU: Custom-Farb-Controls
    local hpColorCustomCheck, hpColorSwatch
    local mpColorCustomCheck, mpColorSwatch

    local combatIconCheck, combatIconSizeSlider, combatIconAnchorDD, combatIconXSlider, combatIconYSlider
    local restingIconCheck, restingIconSizeSlider, restingIconAnchorDD, restingIconXSlider, restingIconYSlider
    local leaderIconCheck,  leaderIconSizeSlider,  leaderIconAnchorDD,  leaderIconXSlider,  leaderIconYSlider
    local raidIconCheck,    raidIconSizeSlider,    raidIconAnchorDD,    raidIconXSlider,    raidIconYSlider

    -- Auren-Controls
    local buffsEnableCheck,  buffsSizeSlider,  buffsMaxSlider,  buffsPerRowSlider,  buffsAnchorDD,  buffsXSlider,  buffsYSlider,  buffsGrowDD
    local debuffsEnableCheck, debuffsSizeSlider, debuffsMaxSlider, debuffsPerRowSlider, debuffsAnchorDD, debuffsXSlider, debuffsYSlider, debuffsGrowDD


    
        local texItems = {
            { value = "DEFAULT", text = "Blizzard Default" },
            { value = "RAID",    text = "Raid Bar" },
            { value = "FLAT",    text = "Flat (weiß)" },

            -- deine neuen:
            { value = "SMOOTH",  text = "Smooth" },
            { value = "GLASS",   text = "Glass"  },
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

        local borderStyleItems = {
            { value = "PIXEL",   text = "Pixel (Standard)" },
            { value = "THIN",    text = "Pixel (dünn)" },
            { value = "THICK",   text = "Pixel (dick)" },
            { value = "TOOLTIP", text = "Tooltip (runde Ecken)" },
            { value = "DIALOG",  text = "Dialog-Rahmen" },
        }


        local growItems = {
            { value = "RIGHT", text = "Nach rechts" },
            { value = "LEFT",  text = "Nach links" },
            { value = "UP",    text = "Nach oben" },
            { value = "DOWN",  text = "Nach unten" },
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
            -24
        )

        heightSlider = CreateSliderWithInput(
            "AI_Player_HeightSlider",
            page,
            "Frame-Höhe",
            10, 600, 1,
            widthSlider,
            -24
        )

        ratioSlider = CreateSliderWithInput(
            "AI_Player_HPRatioSlider",
            page,
            "HP-Anteil (vom Frame) in %",
            10, 90, 1,
            heightSlider,
            -24
        )

        alphaSlider = CreateSliderWithInput(
            "AI_Player_AlphaSlider",
            page,
            "Frame-Alpha in %",
            10, 100, 1,
            ratioSlider,
            -24
        )

        frameBgModeDD = CreateSimpleDropdown(
            "AI_Player_FrameBgModeDD",
            page,
            "Frame-Hintergrund einfärben",
            frameBgModeItems,
            alphaSlider,
            -24
        )

        -- Rahmen
        borderCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        borderCheck:SetPoint("TOPLEFT", frameBgModeDD, "BOTTOMLEFT", 0, -16)
        borderCheck.text = borderCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        borderCheck.text:SetPoint("LEFT", borderCheck, "RIGHT", 4, 0)
        borderCheck.text:SetText("Rahmen anzeigen")

        borderStyleDD = CreateSimpleDropdown(
            "AI_Player_BorderStyleDD",
            page,
            "Rahmen-Stil",
            borderStyleItems,
            borderCheck,
            -12
        )

        borderSizeSlider = CreateSliderWithInput(
            "AI_Player_BorderSizeSlider",
            page,
            "Rahmen-Dicke",
            1, 16, 1,
            borderStyleDD,
            -24
        )

        -- >>> NEU: BorderSize je nach Stil aktiv/deaktivieren
        local function UpdateBorderSizeSliderEnabled(style)
            AI_Config = AI_Config or {}
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}

            style = style or AI_Config.modules.player.borderStyle or "PIXEL"

            -- Für diese Styles ist die Dicke fest -> Slider aus
            local fixed =
                (style == "THIN") or      -- Rahmen Dünn
                (style == "THICK") or     -- Rahmen Dick
                (style == "DIALOG")       -- Dialog-Rahmen

            if fixed then
                borderSizeSlider:Disable()
                if borderSizeSlider.input then borderSizeSlider.input:Disable() end
                if borderSizeSlider.valueBox then borderSizeSlider.valueBox:Disable() end
            else
                borderSizeSlider:Enable()
                if borderSizeSlider.input then borderSizeSlider.input:Enable() end
                if borderSizeSlider.valueBox then borderSizeSlider.valueBox:Enable() end
            end
        end

        -------------------------------------------------
        -- HP Bar Options
        -------------------------------------------------
        
        local hpHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        hpHeader:SetPoint("TOPLEFT", borderSizeSlider, "TOPLEFT", 0, -64)
        hpHeader:SetText("HP Bar Options")

        hpClassCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpClassCheck:SetPoint("TOPLEFT", hpHeader, "BOTTOMLEFT", 0, -16)
        hpClassCheck.text:SetText("HP Klassenfarbe verwenden")
        hpClassCheck.text:SetFontObject(GameFontNormal)
        
        -- Eigene HP-Farbe
        hpColorCustomCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpColorCustomCheck:SetPoint("LEFT", hpClassCheck, "RIGHT", 160, 0)
        hpColorCustomCheck.text = hpColorCustomCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hpColorCustomCheck.text:SetPoint("LEFT", hpColorCustomCheck, "RIGHT", 4, 0)
        hpColorCustomCheck.text:SetText("Eigene HP-Farbe verwenden")

        hpColorSwatch = CreateFrame("Button", nil, page)
        hpColorSwatch:SetSize(26, 16)
        hpColorSwatch:SetPoint("LEFT", hpColorCustomCheck.text, "RIGHT", 8, 0)

        hpColorSwatch.bg = hpColorSwatch:CreateTexture(nil, "BACKGROUND")
        hpColorSwatch.bg:SetAllPoints()
        hpColorSwatch.bg:SetColorTexture(0, 0, 0, 1)

        hpColorSwatch.tex = hpColorSwatch:CreateTexture(nil, "ARTWORK")
        hpColorSwatch.tex:SetPoint("TOPLEFT", 1, -1)
        hpColorSwatch.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        hpColorSwatch.tex:SetColorTexture(0, 1, 0, 1)

        hpTexDD = CreateSimpleDropdown(
            "AI_Player_HPTexDD",
            page,
            "HP-Bar Textur",
            texItems,
            hpClassCheck,
            -12
        )

        -------------------------------------------------
        -- Mana Bar Options
        -------------------------------------------------
        
        local manaHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        manaHeader:SetPoint("TOPLEFT", hpTexDD, "TOPLEFT", 0, -64)
        manaHeader:SetText("Mana Bar Options")

        -- Mana-Controls
        manaCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        manaCheck:SetPoint("TOPLEFT", manaHeader, "BOTTOMLEFT", 0, -16)
        manaCheck.text:SetText("Manabar anzeigen")
        manaCheck.text:SetFontObject(GameFontNormal)

        -- Eigene Mana-Farbe
        mpColorCustomCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        mpColorCustomCheck:SetPoint("LEFT", manaCheck, "RIGHT", 160, 0)
        mpColorCustomCheck.text = mpColorCustomCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        mpColorCustomCheck.text:SetPoint("LEFT", mpColorCustomCheck, "RIGHT", 4, 0)
        mpColorCustomCheck.text:SetText("Eigene Mana-Farbe verwenden")

        mpColorSwatch = CreateFrame("Button", nil, page)
        mpColorSwatch:SetSize(26, 16)
        mpColorSwatch:SetPoint("LEFT", mpColorCustomCheck.text, "RIGHT", 8, 0)

        mpColorSwatch.bg = mpColorSwatch:CreateTexture(nil, "BACKGROUND")
        mpColorSwatch.bg:SetAllPoints()
        mpColorSwatch.bg:SetColorTexture(0, 0, 0, 1)

        mpColorSwatch.tex = mpColorSwatch:CreateTexture(nil, "ARTWORK")
        mpColorSwatch.tex:SetPoint("TOPLEFT", 1, -1)
        mpColorSwatch.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        mpColorSwatch.tex:SetColorTexture(0, 0, 1, 1)

        mpTexDD = CreateSimpleDropdown(
            "AI_Player_MPTexDD",
            page,
            "Mana-Bar Textur",
            texItems,
            manaCheck,
            -12
        )

        -------------------------------------------------
        -- Text Options
        -------------------------------------------------
        
        local textHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        textHeader:SetPoint("TOPLEFT", mpTexDD, "TOPLEFT", 0, -64)
        textHeader:SetText("Text Options")

        -- Spielername
        nameShow = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        nameShow:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -16)
        nameShow.text:SetText("Spielername anzeigen")
        nameShow.text:SetFontObject(GameFontNormal)

        nameBoldCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        nameBoldCheck:SetPoint("LEFT", nameShow, "RIGHT", 160, 0)
        nameBoldCheck.text:SetText("Fett")
        nameBoldCheck.text:SetFontObject(GameFontNormal)

        nameShadowCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        nameShadowCheck:SetPoint("LEFT", nameBoldCheck, "RIGHT", 80, 0)
        nameShadowCheck.text:SetText("Schattiert")
        nameShadowCheck.text:SetFontObject(GameFontNormal)

        nameXSlider = CreateSliderWithInput(
            "AI_Player_NameXOffsetSlider",
            page,
            "X-Offset Spielername",
            -200, 200, 1,
            nameShow,
            -24
        )

        nameYSlider = CreateSliderWithInput(
            "AI_Player_NameYOffsetSlider",
            page,
            "Y-Offset Spielername",
            -200, 200, 1,
            nameXSlider,
            -24
        )

        nameSizeSlider = CreateSliderWithInput(
            "AI_Player_NameSizeSlider",
            page,
            "Schriftgröße Spielername",
            6, 32, 1,
            nameYSlider,
            -24
        )

        nameAnchorDD = CreateSimpleDropdown(
            "AI_Player_NameAnchorDD",
            page,
            "Anker Spielername",
            anchorItems,
            nameSizeSlider,
            -24
        )
        
        -- Name-Textfarbe (eigener Colorcircle)
        local nameTextColorSwatch = CreateFrame("Button", nil, page)
        nameTextColorSwatch:SetSize(26, 16)
        nameTextColorSwatch:SetPoint("LEFT", nameAnchorDD, "RIGHT", 16, 0)

        nameTextColorSwatch.bg = nameTextColorSwatch:CreateTexture(nil, "BACKGROUND")
        nameTextColorSwatch.bg:SetAllPoints()
        nameTextColorSwatch.bg:SetColorTexture(0, 0, 0, 1)

        nameTextColorSwatch.tex = nameTextColorSwatch:CreateTexture(nil, "ARTWORK")
        nameTextColorSwatch.tex:SetPoint("TOPLEFT", 1, -1)
        nameTextColorSwatch.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        nameTextColorSwatch.tex:SetColorTexture(1, 1, 1, 1)

        -- NEU: Label „Custom Color“
        local nameColorLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameColorLabel:SetPoint("LEFT", nameTextColorSwatch, "RIGHT", 4, 0)
        nameColorLabel:SetText("Custom Color")

        -- NEU: Classcolor-Checkbox für Name
        nameClassColorCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        nameClassColorCheck:SetPoint("LEFT", nameColorLabel, "RIGHT", 8, 0)
        nameClassColorCheck.text:SetText("Classcolor")
        nameClassColorCheck.text:SetFontObject(GameFontNormal)
        
        -- HP-Text
        hpShow = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpShow:SetPoint("TOPLEFT", nameAnchorDD, "BOTTOMLEFT", 0, -64)
        hpShow.text:SetText("HP-Text anzeigen")
        hpShow.text:SetFontObject(GameFontNormal)

        hpBoldCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpBoldCheck:SetPoint("LEFT", hpShow, "RIGHT", 160, 0)
        hpBoldCheck.text:SetText("Fett")
        hpBoldCheck.text:SetFontObject(GameFontNormal)

        hpShadowCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpShadowCheck:SetPoint("LEFT", hpBoldCheck, "RIGHT", 80, 0)
        hpShadowCheck.text:SetText("Schattiert")
        hpShadowCheck.text:SetFontObject(GameFontNormal)

        hpModeDD = CreateSimpleDropdown(
            "AI_Player_HPModeDD",
            page,
            "HP-Text Anzeige",
            hpMpModeItems,
            hpShow,
            -12
        )
        hpXSlider = CreateSliderWithInput(
            "AI_Player_HPXOffsetSlider",
            page,
            "X-Offset HP-Text",
            -200, 200, 1,
            hpModeDD,
            -24
        )

        hpYSlider = CreateSliderWithInput(
            "AI_Player_HPYOffsetSlider",
            page,
            "Y-Offset HP-Text",
            -200, 200, 1,
            hpXSlider,
            -24
        )

        hpSizeSlider = CreateSliderWithInput(
            "AI_Player_HPSizeSlider",
            page,
            "Schriftgröße HP-Text",
            6, 32, 1,
            hpYSlider,
            -24
        )

        hpAnchorDD = CreateSimpleDropdown(
            "AI_Player_HPAnchorDD",
            page,
            "Anker HP-Text",
            anchorItems,
            hpSizeSlider,
            -24
        )

        -- HP-Textfarbe (eigener Colorcircle)
        local hpTextColorSwatch = CreateFrame("Button", nil, page)
        hpTextColorSwatch:SetSize(26, 16)
        hpTextColorSwatch:SetPoint("LEFT", hpAnchorDD, "RIGHT", 16, 0)

        hpTextColorSwatch.bg = hpTextColorSwatch:CreateTexture(nil, "BACKGROUND")
        hpTextColorSwatch.bg:SetAllPoints()
        hpTextColorSwatch.bg:SetColorTexture(0, 0, 0, 1)

        hpTextColorSwatch.tex = hpTextColorSwatch:CreateTexture(nil, "ARTWORK")
        hpTextColorSwatch.tex:SetPoint("TOPLEFT", 1, -1)
        hpTextColorSwatch.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        hpTextColorSwatch.tex:SetColorTexture(1, 1, 1, 1)

        -- NEU: Label „Custom Color“
        local hpTextColorLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hpTextColorLabel:SetPoint("LEFT", hpTextColorSwatch, "RIGHT", 4, 0)
        hpTextColorLabel:SetText("Custom Color")

        -- NEU: Classcolor-Checkbox für HP-Text
        hpTextClassColorCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        hpTextClassColorCheck:SetPoint("LEFT", hpTextColorLabel, "RIGHT", 8, 0)
        hpTextClassColorCheck.text:SetText("Classcolor")
        hpTextClassColorCheck.text:SetFontObject(GameFontNormal)

        -- Mana-Text
        mpShow = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        mpShow:SetPoint("TOPLEFT", hpAnchorDD, "BOTTOMLEFT", 0, -64)
        mpShow.text:SetText("Mana-Text anzeigen")
        mpShow.text:SetFontObject(GameFontNormal)

        mpBoldCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        mpBoldCheck:SetPoint("LEFT", mpShow, "RIGHT", 160, 0)
        mpBoldCheck.text:SetText("Fett")
        mpBoldCheck.text:SetFontObject(GameFontNormal)

        mpShadowCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        mpShadowCheck:SetPoint("LEFT", mpBoldCheck, "RIGHT", 80, 0)
        mpShadowCheck.text:SetText("Schattiert")
        mpShadowCheck.text:SetFontObject(GameFontNormal)

        mpModeDD = CreateSimpleDropdown(
            "AI_Player_MPModeDD",
            page,
            "Mana-Text Anzeige",
            hpMpModeItems,
            mpShow,
            -12
        )

        mpXSlider = CreateSliderWithInput(
            "AI_Player_MPXOffsetSlider",
            page,
            "X-Offset Mana-Text",
            -200, 200, 1,
            mpModeDD,
            -24
        )

        mpYSlider = CreateSliderWithInput(
            "AI_Player_MPYOffsetSlider",
            page,
            "Y-Offset Mana-Text",
            -200, 200, 1,
            mpXSlider,
            -24
        )
        mpSizeSlider = CreateSliderWithInput(
            "AI_Player_MPSizeSlider",
            page,
            "Schriftgröße Mana-Text",
            6, 32, 1,
            mpYSlider,
            -24
        )

        mpAnchorDD = CreateSimpleDropdown(
            "AI_Player_MPAnchorDD",
            page,
            "Anker Mana-Text",
            anchorItems,
            mpSizeSlider,
            -24
        )

-- Mana-Textfarbe (eigener Colorcircle)
        local mpTextColorSwatch = CreateFrame("Button", nil, page)
        mpTextColorSwatch:SetSize(26, 16)
        mpTextColorSwatch:SetPoint("LEFT", mpAnchorDD, "RIGHT", 16, 0)

        mpTextColorSwatch.bg = mpTextColorSwatch:CreateTexture(nil, "BACKGROUND")
        mpTextColorSwatch.bg:SetAllPoints()
        mpTextColorSwatch.bg:SetColorTexture(0, 0, 0, 1)

        mpTextColorSwatch.tex = mpTextColorSwatch:CreateTexture(nil, "ARTWORK")
        mpTextColorSwatch.tex:SetPoint("TOPLEFT", 1, -1)
        mpTextColorSwatch.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        mpTextColorSwatch.tex:SetColorTexture(1, 1, 1, 1)

        -- NEU: Label „Custom Color“
        local mpTextColorLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        mpTextColorLabel:SetPoint("LEFT", mpTextColorSwatch, "RIGHT", 4, 0)
        mpTextColorLabel:SetText("Custom Color")

        -- NEU: Classcolor-Checkbox für Mana-Text
        mpTextClassColorCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        mpTextClassColorCheck:SetPoint("LEFT", mpTextColorLabel, "RIGHT", 8, 0)
        mpTextClassColorCheck.text:SetText("Classcolor")
        mpTextClassColorCheck.text:SetFontObject(GameFontNormal)

        -- Level-Text
        lvlShow = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        lvlShow:SetPoint("TOPLEFT", mpAnchorDD, "BOTTOMLEFT", 0, -48)
        lvlShow.text:SetText("Level-Text anzeigen")
        lvlShow.text:SetFontObject(GameFontNormal)

        lvlBoldCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        lvlBoldCheck:SetPoint("LEFT", lvlShow, "RIGHT", 160, 0)
        lvlBoldCheck.text:SetText("Fett")
        lvlBoldCheck.text:SetFontObject(GameFontNormal)

        lvlShadowCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        lvlShadowCheck:SetPoint("LEFT", lvlBoldCheck, "RIGHT", 80, 0)
        lvlShadowCheck.text:SetText("Schattiert")
        lvlShadowCheck.text:SetFontObject(GameFontNormal)

        lvlXSlider = CreateSliderWithInput(
            "AI_Player_LvlXOffsetSlider",
            page,
            "X-Offset Level-Text",
            -200, 200, 1,
            lvlShow,
            -24
        )

        lvlYSlider = CreateSliderWithInput(
            "AI_Player_LvlYOffsetSlider",
            page,
            "Y-Offset Level-Text",
            -200, 200, 1,
            lvlXSlider,
            -24
        )
        lvlSizeSlider = CreateSliderWithInput(
            "AI_Player_LvlSizeSlider",
            page,
            "Schriftgröße Level-Text",
            6, 32, 1,
            lvlYSlider,
            -24
        )

        lvlAnchorDD = CreateSimpleDropdown(
            "AI_Player_LvlAnchorDD",
            page,
            "Anker Level-Text",
            anchorItems,
            lvlSizeSlider,
            -24
        )

        

        -- Level-Textfarbe (eigener Colorcircle)
        local levelTextColorSwatch = CreateFrame("Button", nil, page)
        levelTextColorSwatch:SetSize(26, 16)
        levelTextColorSwatch:SetPoint("LEFT", lvlAnchorDD, "RIGHT", 16, 0)

        levelTextColorSwatch.bg = levelTextColorSwatch:CreateTexture(nil, "BACKGROUND")
        levelTextColorSwatch.bg:SetAllPoints()
        levelTextColorSwatch.bg:SetColorTexture(0, 0, 0, 1)

        levelTextColorSwatch.tex = levelTextColorSwatch:CreateTexture(nil, "ARTWORK")
        levelTextColorSwatch.tex:SetPoint("TOPLEFT", 1, -1)
        levelTextColorSwatch.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        levelTextColorSwatch.tex:SetColorTexture(1, 1, 1, 1)

        -- NEU: Label „Custom Color“
        local lvlTextColorLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lvlTextColorLabel:SetPoint("LEFT", levelTextColorSwatch, "RIGHT", 4, 0)
        lvlTextColorLabel:SetText("Custom Color")

        -- NEU: Classcolor-Checkbox für Level-Text
        lvlTextClassColorCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        lvlTextClassColorCheck:SetPoint("LEFT", lvlTextColorLabel, "RIGHT", 8, 0)
        lvlTextClassColorCheck.text:SetText("Classcolor")
        lvlTextClassColorCheck.text:SetFontObject(GameFontNormal)

        -------------------------------------------------
        -- Icons
        -------------------------------------------------
        local iconHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconHeader:SetPoint("TOPLEFT", lvlAnchorDD, "BOTTOMLEFT", 0, -64)
        iconHeader:SetText("Icon Options")

        -- Combat-Icon
        combatIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        combatIconCheck:SetPoint("TOPLEFT", iconHeader, "BOTTOMLEFT", 0, -16)
        combatIconCheck.text = combatIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        combatIconCheck.text:SetPoint("LEFT", combatIconCheck, "RIGHT", 4, 0)
        combatIconCheck.text:SetText("Combat-Icon anzeigen")

        combatIconSizeSlider = CreateSliderWithInput(
            "AI_Player_CombatIconSizeSlider",
            page,
            "Combat-Icon Größe",
            8, 64, 1,
            combatIconCheck,
            -24
        )

        combatIconXSlider = CreateSliderWithInput(
            "AI_Player_CombatIconXOffsetSlider",
            page,
            "Combat-Icon X-Offset",
            -200, 200, 1,
            combatIconSizeSlider,
            -24
        )

        combatIconYSlider = CreateSliderWithInput(
            "AI_Player_CombatIconYOffsetSlider",
            page,
            "Combat-Icon Y-Offset",
            -200, 200, 1,
            combatIconXSlider,
            -24
        )

        combatIconAnchorDD = CreateSimpleDropdown(
            "AI_Player_CombatIconAnchorDD",
            page,
            "Combat-Icon Anker",
            anchorItems,
            combatIconYSlider,
            -24
        )

        -- Resting-Icon
        restingIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        restingIconCheck:SetPoint("TOPLEFT", combatIconAnchorDD, "BOTTOMLEFT", 0, -32)
        restingIconCheck.text = restingIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        restingIconCheck.text:SetPoint("LEFT", restingIconCheck, "RIGHT", 4, 0)
        restingIconCheck.text:SetText("Resting-Icon anzeigen")

        restingIconSizeSlider = CreateSliderWithInput(
            "AI_Player_RestingIconSizeSlider",
            page,
            "Resting-Icon Größe",
            8, 64, 1,
            restingIconCheck,
            -24
        )

        restingIconXSlider = CreateSliderWithInput(
            "AI_Player_RestingIconXOffsetSlider",
            page,
            "Resting-Icon X-Offset",
            -200, 200, 1,
            restingIconSizeSlider,
            -24
        )

        restingIconYSlider = CreateSliderWithInput(
            "AI_Player_RestingIconYOffsetSlider",
            page,
            "Resting-Icon Y-Offset",
            -200, 200, 1,
            restingIconXSlider,
            -24
        )

        restingIconAnchorDD = CreateSimpleDropdown(
            "AI_Player_RestingIconAnchorDD",
            page,
            "Resting-Icon Anker",
            anchorItems,
            restingIconYSlider,
            -24
        )

        -- Leader-Icon
        leaderIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        leaderIconCheck:SetPoint("TOPLEFT", restingIconAnchorDD, "BOTTOMLEFT", 0, -32)
        leaderIconCheck.text = leaderIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leaderIconCheck.text:SetPoint("LEFT", leaderIconCheck, "RIGHT", 4, 0)
        leaderIconCheck.text:SetText("Party-Leader-Icon anzeigen")

        leaderIconSizeSlider = CreateSliderWithInput(
            "AI_Player_LeaderIconSizeSlider",
            page,
            "Leader-Icon Größe",
            8, 64, 1,
            leaderIconCheck,
            -24
        )

        leaderIconXSlider = CreateSliderWithInput(
            "AI_Player_LeaderIconXOffsetSlider",
            page,
            "Leader-Icon X-Offset",
            -200, 200, 1,
            leaderIconSizeSlider,
            -24
        )

        leaderIconYSlider = CreateSliderWithInput(
            "AI_Player_LeaderIconYOffsetSlider",
            page,
            "Leader-Icon Y-Offset",
            -200, 200, 1,
            leaderIconXSlider,
            -24
        )

        leaderIconAnchorDD = CreateSimpleDropdown(
            "AI_Player_LeaderIconAnchorDD",
            page,
            "Leader-Icon Anker",
            anchorItems,
            leaderIconYSlider,
            -24
        )

        -- RaidTarget-Icon
        raidIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        raidIconCheck:SetPoint("TOPLEFT", leaderIconAnchorDD, "BOTTOMLEFT", 0, -32)
        raidIconCheck.text = raidIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        raidIconCheck.text:SetPoint("LEFT", raidIconCheck, "RIGHT", 4, 0)
        raidIconCheck.text:SetText("Raidtarget-Icon anzeigen")

        raidIconSizeSlider = CreateSliderWithInput(
            "AI_Player_RaidIconSizeSlider",
            page,
            "Raidtarget-Icon Größe",
            8, 64, 1,
            raidIconCheck,
            -24
        )

        raidIconXSlider = CreateSliderWithInput(
            "AI_Player_RaidIconXOffsetSlider",
            page,
            "Raidtarget-Icon X-Offset",
            -200, 200, 1,
            raidIconSizeSlider,
            -24
        )

        raidIconYSlider = CreateSliderWithInput(
            "AI_Player_RaidIconYOffsetSlider",
            page,
            "Raidtarget-Icon Y-Offset",
            -200, 200, 1,
            raidIconXSlider,
            -24
        )

        raidIconAnchorDD = CreateSimpleDropdown(
            "AI_Player_RaidIconAnchorDD",
            page,
            "Raidtarget-Icon Anker",
            anchorItems,
            raidIconYSlider,
            -24
        )
        
        -------------------------------------------------
        -- Buffs / Debuffs
        -------------------------------------------------
        local aurasHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        aurasHeader:SetPoint("TOPLEFT", raidIconAnchorDD, "BOTTOMLEFT", 0, -64)
        aurasHeader:SetText("Buffs / Debuffs")

        -- Buffs
        buffsEnableCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        buffsEnableCheck:SetPoint("TOPLEFT", aurasHeader, "BOTTOMLEFT", 0, -8)
        buffsEnableCheck.text = buffsEnableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        buffsEnableCheck.text:SetPoint("LEFT", buffsEnableCheck, "RIGHT", 4, 0)
        buffsEnableCheck.text:SetText("Buffs anzeigen")

        buffsSizeSlider = CreateSliderWithInput(
            "AI_Player_BuffsSizeSlider",
            page,
            "Buff-Icon Größe",
            8, 64, 1,
            buffsEnableCheck,
            -24
        )

        buffsMaxSlider = CreateSliderWithInput(
            "AI_Player_BuffsMaxSlider",
            page,
            "Max. Buffs",
            1, 40, 1,
            buffsSizeSlider,
            -24
        )
        
        buffsPerRowSlider = CreateSliderWithInput(
            "AI_Player_BuffsPerRowSlider",
            page,
            "Buffs pro Reihe",
            1, 40, 1,
            buffsMaxSlider,
            -24
        )

        buffsAnchorDD = CreateSimpleDropdown(
            "AI_Player_BuffsAnchorDD",
            page,
            "Buff-Anker am Frame",
            anchorItems,
            buffsPerRowSlider,
            -24
        )

        buffsXSlider = CreateSliderWithInput(
            "AI_Player_BuffsXOffsetSlider",
            page,
            "Buff X-Offset",
            -400, 400, 1,
            buffsAnchorDD,
            -24
        )

        buffsYSlider = CreateSliderWithInput(
            "AI_Player_BuffsYOffsetSlider",
            page,
            "Buff Y-Offset",
            -400, 400, 1,
            buffsXSlider,
            -24
        )

        buffsGrowDD = CreateSimpleDropdown(
            "AI_Player_BuffsGrowDD",
            page,
            "Buff Wachstumsrichtung",
            growItems,
            buffsYSlider,
            -24
        )

        -- Debuffs
        debuffsEnableCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        debuffsEnableCheck:SetPoint("TOPLEFT", buffsGrowDD, "BOTTOMLEFT", 0, -24)
        debuffsEnableCheck.text = debuffsEnableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        debuffsEnableCheck.text:SetPoint("LEFT", debuffsEnableCheck, "RIGHT", 4, 0)
        debuffsEnableCheck.text:SetText("Debuffs anzeigen")

        debuffsSizeSlider = CreateSliderWithInput(
            "AI_Player_DebuffsSizeSlider",
            page,
            "Debuff-Icon Größe",
            8, 64, 1,
            debuffsEnableCheck,
            -24
        )

        debuffsMaxSlider = CreateSliderWithInput(
            "AI_Player_DebuffsMaxSlider",
            page,
            "Max. Debuffs",
            1, 40, 1,
            debuffsSizeSlider,
            -24
        )
        
        debuffsPerRowSlider = CreateSliderWithInput(
            "AI_Player_DebuffsPerRowSlider",
            page,
            "Debuffs pro Reihe",
            1, 40, 1,
            debuffsMaxSlider,
            -24
        )

        debuffsAnchorDD = CreateSimpleDropdown(
            "AI_Player_DebuffsAnchorDD",
            page,
            "Debuff-Anker am Frame",
            anchorItems,
            debuffsPerRowSlider,
            -24
        )

        debuffsXSlider = CreateSliderWithInput(
            "AI_Player_DebuffsXOffsetSlider",
            page,
            "Debuff X-Offset",
            -400, 400, 1,
            debuffsAnchorDD,
            -24
        )

        debuffsYSlider = CreateSliderWithInput(
            "AI_Player_DebuffsYOffsetSlider",
            page,
            "Debuff Y-Offset",
            -400, 400, 1,
            debuffsXSlider,
            -24
        )

        debuffsGrowDD = CreateSimpleDropdown(
            "AI_Player_DebuffsGrowDD",
            page,
            "Debuff Wachstumsrichtung",
            growItems,
            debuffsYSlider,
            -24
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

        page.hpColorCustomCheck = hpColorCustomCheck
        page.hpColorSwatch      = hpColorSwatch
        page.mpColorCustomCheck = mpColorCustomCheck
        page.mpColorSwatch      = mpColorSwatch

        page.nameShow         = nameShow
        page.nameSizeSlider   = nameSizeSlider
        page.nameAnchorDD     = nameAnchorDD
        page.nameXSlider      = nameXSlider
        page.nameYSlider      = nameYSlider
        page.nameTextColorSwatch  = nameTextColorSwatch

        page.hpShow           = hpShow
        page.hpSizeSlider     = hpSizeSlider
        page.hpAnchorDD       = hpAnchorDD
        page.hpXSlider        = hpXSlider
        page.hpYSlider        = hpYSlider
        page.hpTextColorSwatch = hpTextColorSwatch

        page.mpShow           = mpShow
        page.mpSizeSlider     = mpSizeSlider
        page.mpAnchorDD       = mpAnchorDD
        page.mpXSlider        = mpXSlider
        page.mpYSlider        = mpYSlider
        page.mpTextColorSwatch = mpTextColorSwatch

        page.lvlShow          = lvlShow
        page.lvlSizeSlider    = lvlSizeSlider
        page.lvlAnchorDD      = lvlAnchorDD
        page.lvlXSlider       = lvlXSlider
        page.lvlYSlider       = lvlYSlider
        page.levelTextColorSwatch = levelTextColorSwatch

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
        page.borderStyleDD    = borderStyleDD

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

        -- Buff-/Debuff-Controls auf der Page merken
        page.buffsEnableCheck   = buffsEnableCheck
        page.buffsSizeSlider    = buffsSizeSlider
        page.buffsMaxSlider     = buffsMaxSlider
        page.buffsAnchorDD      = buffsAnchorDD
        page.buffsXSlider       = buffsXSlider
        page.buffsYSlider       = buffsYSlider
        page.buffsGrowDD        = buffsGrowDD

        page.debuffsEnableCheck = debuffsEnableCheck
        page.debuffsSizeSlider  = debuffsSizeSlider
        page.debuffsMaxSlider   = debuffsMaxSlider
        page.debuffsAnchorDD    = debuffsAnchorDD
        page.debuffsXSlider     = debuffsXSlider
        page.debuffsYSlider     = debuffsYSlider
        page.debuffsGrowDD      = debuffsGrowDD
        page.buffsPerRowSlider  = buffsPerRowSlider
        page.debuffsPerRowSlider = debuffsPerRowSlider



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

            local hpColorCustomCheck = page.hpColorCustomCheck
            local hpColorSwatch      = page.hpColorSwatch
            local mpColorCustomCheck = page.mpColorCustomCheck
            local mpColorSwatch      = page.mpColorSwatch

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
            local borderStyleDD    = page.borderStyleDD
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

            if entry.hpUseCustomColor == nil then entry.hpUseCustomColor = false end
            entry.hpCustomColor = entry.hpCustomColor or { r = 0, g = 1, b = 0 }

            if entry.mpUseCustomColor == nil then entry.mpUseCustomColor = false end
            entry.mpCustomColor = entry.mpCustomColor or { r = 0, g = 0, b = 1 }

            -- Eigene Textfarben (unabhängig von den Barfarben)
            entry.nameTextColor  = entry.nameTextColor  or { r = 1, g = 1, b = 1 }
            entry.hpTextColor    = entry.hpTextColor    or { r = 1, g = 1, b = 1 }
            entry.mpTextColor    = entry.mpTextColor    or { r = 1, g = 1, b = 1 }
            entry.levelTextColor = entry.levelTextColor or { r = 1, g = 1, b = 1 }

            -- Buff-/Debuff-Defaults für das Config-UI
            entry.buffs = entry.buffs or {}
            entry.buffs.enabled = (entry.buffs.enabled ~= false)
            entry.buffs.anchor  = entry.buffs.anchor or "TOPLEFT"
            entry.buffs.x       = entry.buffs.x or 0
            entry.buffs.y       = entry.buffs.y or 10
            entry.buffs.size    = entry.buffs.size or 24
            entry.buffs.grow    = entry.buffs.grow or "RIGHT"
            entry.buffs.max     = entry.buffs.max or 12
            entry.buffs.perRow   = entry.buffs.perRow   or 8
            entry.debuffs.perRow = entry.debuffs.perRow or 8
            entry.debuffs = entry.debuffs or {}
            entry.debuffs.enabled = (entry.debuffs.enabled ~= false)
            entry.debuffs.anchor  = entry.debuffs.anchor or "TOPLEFT"
            entry.debuffs.x       = entry.debuffs.x or 0
            entry.debuffs.y       = entry.debuffs.y or -26
            entry.debuffs.size    = entry.debuffs.size or 24
            entry.debuffs.grow    = entry.debuffs.grow or "RIGHT"
            entry.debuffs.max     = entry.debuffs.max or 12

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


            -- HP Custom-Farbe: Checkbox + Swatch
            hpColorCustomCheck:SetChecked(entry.hpUseCustomColor)
            if hpColorSwatch and hpColorSwatch.tex and entry.hpCustomColor then
                hpColorSwatch.tex:SetColorTexture(
                    entry.hpCustomColor.r or 0,
                    entry.hpCustomColor.g or 1,
                    entry.hpCustomColor.b or 0,
                    1
                )
            end

            -- Wenn Klassenfarbe aktiv ist: Custom-HP sperren + ausschalten
            if entry.hpColorMode == "CLASS" then
                hpColorCustomCheck:SetChecked(false)
                hpColorCustomCheck:Disable()
                if hpColorSwatch then
                    hpColorSwatch:Disable()
                end
            else
                hpColorCustomCheck:Enable()
                if hpColorSwatch then
                    hpColorSwatch:Enable()
                end
            end


            mpColorCustomCheck:SetChecked(entry.mpUseCustomColor)
            if mpColorSwatch and mpColorSwatch.tex and entry.mpCustomColor then
                mpColorSwatch.tex:SetColorTexture(
                    entry.mpCustomColor.r or 0,
                    entry.mpCustomColor.g or 0,
                    entry.mpCustomColor.b or 1,
                    1
                )
            end

            if hpTextColorSwatch and hpTextColorSwatch.tex and entry.hpTextColor then
                hpTextColorSwatch.tex:SetColorTexture(
                    entry.hpTextColor.r or 1,
                    entry.hpTextColor.g or 1,
                    entry.hpTextColor.b or 1,
                    1
                )
            end

            if mpTextColorSwatch and mpTextColorSwatch.tex and entry.mpTextColor then
                mpTextColorSwatch.tex:SetColorTexture(
                    entry.mpTextColor.r or 1,
                    entry.mpTextColor.g or 1,
                    entry.mpTextColor.b or 1,
                    1
                )
            end

            if nameTextColorSwatch and nameTextColorSwatch.tex and entry.nameTextColor then
                nameTextColorSwatch.tex:SetColorTexture(
                    entry.nameTextColor.r or 1,
                    entry.nameTextColor.g or 1,
                    entry.nameTextColor.b or 1,
                    1
                )
            end

            if levelTextColorSwatch and levelTextColorSwatch.tex and entry.levelTextColor then
                levelTextColorSwatch.tex:SetColorTexture(
                    entry.levelTextColor.r or 1,
                    entry.levelTextColor.g or 1,
                    entry.levelTextColor.b or 1,
                    1
                )
            end
            -- NEU: Classcolor-Checkboxen setzen
            if nameClassColorCheck then
                nameClassColorCheck:SetChecked(entry.nameTextUseClassColor)
            end
            if hpTextClassColorCheck then
                hpTextClassColorCheck:SetChecked(entry.hpTextUseClassColor)
            end
            if mpTextClassColorCheck then
                mpTextClassColorCheck:SetChecked(entry.mpTextUseClassColor)
            end
            if lvlTextClassColorCheck then
                lvlTextClassColorCheck:SetChecked(entry.levelTextUseClassColor)
            end

            -- NEU: Swatches deaktivieren, wenn Classcolor aktiv
            local function UpdateTextColorSwatchEnabled(swatch, useClass)
                if not swatch then return end
                if useClass then
                    swatch:Disable()
                    swatch:SetAlpha(0.4)
                else
                    swatch:Enable()
                    swatch:SetAlpha(1)
                end
            end

            UpdateTextColorSwatchEnabled(nameTextColorSwatch,  entry.nameTextUseClassColor)
            UpdateTextColorSwatchEnabled(hpTextColorSwatch,    entry.hpTextUseClassColor)
            UpdateTextColorSwatchEnabled(mpTextColorSwatch,    entry.mpTextUseClassColor)
            UpdateTextColorSwatchEnabled(levelTextColorSwatch, entry.levelTextUseClassColor)
            
            -- NEU: OnClick-Logik für Text-Classcolor
            local function ToggleTextClassColor(flagKey, check, swatch)
                if not check or not swatch then return end
                check:SetScript("OnClick", function(self)
                    local cfg = GetTargetEntry(moduleKey)
                    cfg[flagKey] = self:GetChecked() and true or false

                    if cfg[flagKey] then
                        swatch:Disable()
                        swatch:SetAlpha(0.4)
                    else
                        swatch:Enable()
                        swatch:SetAlpha(1)
                    end

                    page.SetDirty(true)
                    ApplyPlayerLayout()
                end)
            end

            ToggleTextClassColor("nameTextUseClassColor",  nameClassColorCheck,  nameTextColorSwatch)
            ToggleTextClassColor("hpTextUseClassColor",    hpTextClassColorCheck, hpTextColorSwatch)
            ToggleTextClassColor("mpTextUseClassColor",    mpTextClassColorCheck, mpTextColorSwatch)
            ToggleTextClassColor("levelTextUseClassColor", lvlTextClassColorCheck, levelTextColorSwatch)

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
            borderStyleDD:SetSelected(entry.borderStyle)
            borderSizeSlider:SetValue(entry.borderSize); borderSizeSlider:SetTextSync(entry.borderSize)
            -- Slider-Status passend zum aktuellen Stil setzen
            UpdateBorderSizeSliderEnabled(entry.borderStyle)


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
        
            -- Buff-UI-Werte setzen
            if buffsEnableCheck then
                buffsEnableCheck:SetChecked(entry.buffs.enabled)
                buffsSizeSlider:SetValue(entry.buffs.size);  buffsSizeSlider:SetTextSync(entry.buffs.size)
                buffsMaxSlider:SetValue(entry.buffs.max);    buffsMaxSlider:SetTextSync(entry.buffs.max)
                buffsAnchorDD:SetSelected(entry.buffs.anchor)
                buffsXSlider:SetValue(entry.buffs.x);        buffsXSlider:SetTextSync(entry.buffs.x)
                buffsYSlider:SetValue(entry.buffs.y);        buffsYSlider:SetTextSync(entry.buffs.y)
                buffsGrowDD:SetSelected(entry.buffs.grow)
                buffsPerRowSlider:SetValue(entry.buffs.perRow); buffsPerRowSlider:SetTextSync(entry.buffs.perRow)

            end

            -- Debuff-UI-Werte setzen
            if debuffsEnableCheck then
                debuffsEnableCheck:SetChecked(entry.debuffs.enabled)
                debuffsSizeSlider:SetValue(entry.debuffs.size);  debuffsSizeSlider:SetTextSync(entry.debuffs.size)
                debuffsMaxSlider:SetValue(entry.debuffs.max);    debuffsMaxSlider:SetTextSync(entry.debuffs.max)
                debuffsAnchorDD:SetSelected(entry.debuffs.anchor)
                debuffsXSlider:SetValue(entry.debuffs.x);        debuffsXSlider:SetTextSync(entry.debuffs.x)
                debuffsYSlider:SetValue(entry.debuffs.y);        debuffsYSlider:SetTextSync(entry.debuffs.y)
                debuffsGrowDD:SetSelected(entry.debuffs.grow)
                debuffsPerRowSlider:SetValue(entry.debuffs.perRow); debuffsPerRowSlider:SetTextSync(entry.debuffs.perRow)

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
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            local cfg = AI_Config.modules.player

            if self:GetChecked() then
                cfg.hpColorMode = "CLASS"

                -- Custom HP-Farbe ausschalten und sperren
                cfg.hpUseCustomColor = false
                if hpColorCustomCheck then
                    hpColorCustomCheck:SetChecked(false)
                    hpColorCustomCheck:Disable()
                end
                if hpColorSwatch then
                    hpColorSwatch:Disable()
                end
            else
                cfg.hpColorMode = "DEFAULT"

                -- Custom HP-Farbe wieder erlauben (aber nicht automatisch einschalten)
                if hpColorCustomCheck then
                    hpColorCustomCheck:Enable()
                end
                if hpColorSwatch then
                    hpColorSwatch:Enable()
                end
            end

            markDirtyAndApply()
        end)


        hpColorCustomCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.hpUseCustomColor = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        mpColorCustomCheck:SetScript("OnClick", function(self)
            AI_Config.modules.player.mpUseCustomColor = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        -- ColorPicker für HP-Farbe (neues API)
        hpColorSwatch:SetScript("OnClick", function()
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            local cfg = AI_Config.modules.player

            cfg.hpCustomColor = cfg.hpCustomColor or { r = 0, g = 1, b = 0 }

            local prevR = cfg.hpCustomColor.r or 0
            local prevG = cfg.hpCustomColor.g or 1
            local prevB = cfg.hpCustomColor.b or 0

            local function applyColor(r, g, b)
                cfg.hpCustomColor.r = r
                cfg.hpCustomColor.g = g
                cfg.hpCustomColor.b = b

                if hpColorSwatch.tex then
                    hpColorSwatch.tex:SetColorTexture(r, g, b, 1)
                end

                markDirtyAndApply()
            end

            -- Modernes ColorPicker-API (Dragonflight / Midnight)
            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = prevR,
                    g = prevG,
                    b = prevB,
                    hasOpacity = false,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        applyColor(r, g, b)
                    end,
                    cancelFunc = function()
                        -- auf alte Farbe zurück
                        applyColor(prevR, prevG, prevB)
                    end,
                })
            end
        end)

        -- ColorPicker für Mana-Farbe (neues API)
        mpColorSwatch:SetScript("OnClick", function()
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            local cfg = AI_Config.modules.player

            cfg.mpCustomColor = cfg.mpCustomColor or { r = 0, g = 0, b = 1 }

            local prevR = cfg.mpCustomColor.r or 0
            local prevG = cfg.mpCustomColor.g or 0
            local prevB = cfg.mpCustomColor.b or 1

            local function applyColor(r, g, b)
                cfg.mpCustomColor.r = r
                cfg.mpCustomColor.g = g
                cfg.mpCustomColor.b = b

                if mpColorSwatch.tex then
                    mpColorSwatch.tex:SetColorTexture(r, g, b, 1)
                end

                markDirtyAndApply()
            end

            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = prevR,
                    g = prevG,
                    b = prevB,
                    hasOpacity = false,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        applyColor(r, g, b)
                    end,
                    cancelFunc = function()
                        applyColor(prevR, prevG, prevB)
                    end,
                })
            end
        end)

        
        -- ColorPicker für HP-Textfarbe
        hpTextColorSwatch:SetScript("OnClick", function()
        local cfg = GetTargetEntry(moduleKey)
        cfg.hpTextColor = cfg.hpTextColor or { r = 1, g = 1, b = 1 }

        local prevR = cfg.hpTextColor.r or 1
        local prevG = cfg.hpTextColor.g or 1
        local prevB = cfg.hpTextColor.b or 1

        local function applyColor(r, g, b)
            cfg.hpTextColor.r = r
            cfg.hpTextColor.g = g
            cfg.hpTextColor.b = b

            if hpTextColorSwatch.tex then
                hpTextColorSwatch.tex:SetColorTexture(r, g, b, 1)
            end

            markDirtyAndApply()
        end

        if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = prevR,
                g = prevG,
                b = prevB,
                hasOpacity = false,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    applyColor(r, g, b)
                end,
                cancelFunc = function()
                    applyColor(prevR, prevG, prevB)
                end,
            })
        end
    end)


        -- ColorPicker für Mana-Textfarbe
        mpTextColorSwatch:SetScript("OnClick", function()
            local cfg = GetTargetEntry(moduleKey)
            cfg.mpTextColor = cfg.mpTextColor or { r = 1, g = 1, b = 1 }

            local prevR = cfg.mpTextColor.r or 1
            local prevG = cfg.mpTextColor.g or 1
            local prevB = cfg.mpTextColor.b or 1

            local function applyColor(r, g, b)
                cfg.mpTextColor.r = r
                cfg.mpTextColor.g = g
                cfg.mpTextColor.b = b

                if mpTextColorSwatch.tex then
                    mpTextColorSwatch.tex:SetColorTexture(r, g, b, 1)
                end

                markDirtyAndApply()
            end

            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = prevR,
                    g = prevG,
                    b = prevB,
                    hasOpacity = false,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        applyColor(r, g, b)
                    end,
                    cancelFunc = function()
                        applyColor(prevR, prevG, prevB)
                    end,
                })
            end
        end)

        -- ColorPicker für Name-Textfarbe
        nameTextColorSwatch:SetScript("OnClick", function()
            local cfg = GetTargetEntry(moduleKey)
            cfg.nameTextColor = cfg.nameTextColor or { r = 1, g = 1, b = 1 }

            local prevR = cfg.nameTextColor.r or 1
            local prevG = cfg.nameTextColor.g or 1
            local prevB = cfg.nameTextColor.b or 1

            local function applyColor(r, g, b)
                cfg.nameTextColor.r = r
                cfg.nameTextColor.g = g
                cfg.nameTextColor.b = b

                if nameTextColorSwatch.tex then
                    nameTextColorSwatch.tex:SetColorTexture(r, g, b, 1)
                end

                markDirtyAndApply()
            end

            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = prevR,
                    g = prevG,
                    b = prevB,
                    hasOpacity = false,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        applyColor(r, g, b)
                    end,
                    cancelFunc = function()
                        applyColor(prevR, prevG, prevB)
                    end,
                })
            end
        end)
        
        -- ColorPicker für Level-Textfarbe
        levelTextColorSwatch:SetScript("OnClick", function()
            local cfg = GetTargetEntry(moduleKey)
            cfg.levelTextColor = cfg.levelTextColor or { r = 1, g = 1, b = 1 }

            local prevR = cfg.levelTextColor.r or 1
            local prevG = cfg.levelTextColor.g or 1
            local prevB = cfg.levelTextColor.b or 1

            local function applyColor(r, g, b)
                cfg.levelTextColor.r = r
                cfg.levelTextColor.g = g
                cfg.levelTextColor.b = b

                if levelTextColorSwatch.tex then
                    levelTextColorSwatch.tex:SetColorTexture(r, g, b, 1)
                end

                markDirtyAndApply()
            end

            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = prevR,
                    g = prevG,
                    b = prevB,
                    hasOpacity = false,
                    swatchFunc = function()
                        local r, g, b = ColorPickerFrame:GetColorRGB()
                        applyColor(r, g, b)
                    end,
                    cancelFunc = function()
                        applyColor(prevR, prevG, prevB)
                    end,
                })
            end
        end)

                function borderStyleDD:OnValueChanged(value)
            local cfg = GetTargetEntry(moduleKey)
            cfg.borderStyle = value

            UpdateBorderSizeSliderEnabled(value)
            markDirtyAndApply()
        end

        function hpTexDD:OnValueChanged(value)
            local cfg = GetTargetEntry(moduleKey)
            cfg.hpTexture = value
            markDirtyAndApply()
        end

        function mpTexDD:OnValueChanged(value)
            local cfg = GetTargetEntry(moduleKey)
            cfg.mpTexture = value
            markDirtyAndApply()
        end

        function frameBgModeDD:OnValueChanged(value)
            local cfg = GetTargetEntry(moduleKey)
            cfg.frameBgMode = value
            markDirtyAndApply()
        end

        function hpModeDD:OnValueChanged(value)
            local cfg = GetTargetEntry(moduleKey)
            cfg.hpTextMode = value
            markDirtyAndApply()
        end

        function mpModeDD:OnValueChanged(value)
            local cfg = GetTargetEntry(moduleKey)
            cfg.mpTextMode = value
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

        -- -- Low-HP-Highlight
        -- lowHPCheck:SetScript("OnClick", function(self)
        --     AI_Config.modules.player.lowHPHighlightEnabled = self:GetChecked() and true or false
        --     markDirtyAndApply()
        -- end)

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

                -- Buff-Options
        buffsEnableCheck:SetScript("OnClick", function(self)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.buffs = AI_Config.modules.player.buffs or {}

            AI_Config.modules.player.buffs.enabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        debuffsEnableCheck:SetScript("OnClick", function(self)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.debuffs = AI_Config.modules.player.debuffs or {}

            AI_Config.modules.player.debuffs.enabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        buffsSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.buffs = AI_Config.modules.player.buffs or {}

            AI_Config.modules.player.buffs.size = value
            markDirtyAndApply()
        end)

        buffsMaxSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.buffs = AI_Config.modules.player.buffs or {}

            AI_Config.modules.player.buffs.max = value
            markDirtyAndApply()
        end)

        function buffsAnchorDD:OnValueChanged(value)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.buffs = AI_Config.modules.player.buffs or {}

            AI_Config.modules.player.buffs.anchor = value
            markDirtyAndApply()
        end

        buffsXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.buffs = AI_Config.modules.player.buffs or {}

            AI_Config.modules.player.buffs.x = value
            markDirtyAndApply()
        end)

        buffsYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.buffs = AI_Config.modules.player.buffs or {}

            AI_Config.modules.player.buffs.y = value
            markDirtyAndApply()
        end)

        function buffsGrowDD:OnValueChanged(value)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.buffs = AI_Config.modules.player.buffs or {}

            AI_Config.modules.player.buffs.grow = value
            markDirtyAndApply()
        end

        debuffsSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.debuffs = AI_Config.modules.player.debuffs or {}

            AI_Config.modules.player.debuffs.size = value
            markDirtyAndApply()
        end)

        debuffsMaxSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.debuffs = AI_Config.modules.player.debuffs or {}

            AI_Config.modules.player.debuffs.max = value
            markDirtyAndApply()
        end)

        function debuffsAnchorDD:OnValueChanged(value)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.debuffs = AI_Config.modules.player.debuffs or {}

            AI_Config.modules.player.debuffs.anchor = value
            markDirtyAndApply()
        end

        debuffsXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.debuffs = AI_Config.modules.player.debuffs or {}

            AI_Config.modules.player.debuffs.x = value
            markDirtyAndApply()
        end)

        debuffsYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.debuffs = AI_Config.modules.player.debuffs or {}

            AI_Config.modules.player.debuffs.y = value
            markDirtyAndApply()
        end)

        function debuffsGrowDD:OnValueChanged(value)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.debuffs = AI_Config.modules.player.debuffs or {}

            AI_Config.modules.player.debuffs.grow = value
            markDirtyAndApply()
        end
        
        buffsPerRowSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.buffs = AI_Config.modules.player.buffs or {}

            AI_Config.modules.player.buffs.perRow = value
            markDirtyAndApply()
        end)

        debuffsPerRowSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            AI_Config.modules.player.debuffs = AI_Config.modules.player.debuffs or {}

            AI_Config.modules.player.debuffs.perRow = value
            markDirtyAndApply()
        end)


    

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
    
    if resetPosButton then
        resetPosButton:SetScript("OnClick", function(self)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.player = AI_Config.modules.player or {}
            local cfg = AI_Config.modules.player

            -- Frame-Position im Modul auf Default zurücksetzen
            if AI and AI.modules and AI.modules.player and AI.modules.player.ResetPosition then
                AI.modules.player.ResetPosition()
            else
                -- Fallback, falls das Modul noch nicht registriert ist
                cfg.x = -300
                cfg.y = -200
            end

            -- Text-Anker & Offsets zurücksetzen
            cfg.nameAnchor   = "TOPLEFT"
            cfg.hpTextAnchor = "TOPRIGHT"
            cfg.mpTextAnchor = "BOTTOMRIGHT"
            cfg.levelAnchor  = "BOTTOMLEFT"

            cfg.nameXOffset   = 10
            cfg.nameYOffset   = -5
            cfg.hpTextXOffset = -10
            cfg.hpTextYOffset = -5
            cfg.mpTextXOffset = -5
            cfg.mpTextYOffset = 5
            cfg.levelXOffset  = 10
            cfg.levelYOffset  = 5

            -- Icon-Anker & Offsets zurücksetzen
            cfg.combatIconAnchor   = nil
            cfg.combatIconXOffset  = nil
            cfg.combatIconYOffset  = nil
            cfg.restingIconAnchor  = nil
            cfg.restingIconXOffset = nil
            cfg.restingIconYOffset = nil
            cfg.leaderIconAnchor   = nil
            cfg.leaderIconXOffset  = nil
            cfg.leaderIconYOffset  = nil
            cfg.raidIconAnchor     = nil
            cfg.raidIconXOffset    = nil
            cfg.raidIconYOffset    = nil

            cfg.height = 100
            cfg.width = 200
            cfg.hpRatio = 0.7

            -- UI neu initialisieren (setzt die Defaults aus GetPlayerConfig/page.Init)
            if page.Init then
                page.Init()
            end

            -- Layout auf dem echten Frame neu anwenden
            ApplyPlayerLayout()

            -- Änderungen markieren
            page.SetDirty(true)
        end)
    end
end

-- Bei der Registry anmelden (Reihenfolge 10 = links als erstes Tab)
if AI.ConfigUI and AI.ConfigUI.RegisterPage then
    AI.ConfigUI.RegisterPage("player", "Player", 10, BuildPlayerConfigPage)
end