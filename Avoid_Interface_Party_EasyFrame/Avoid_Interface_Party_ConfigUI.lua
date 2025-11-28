-- Avoid_Interface_Party_ConfigUI.lua
-- Baut die "party"-Seite im gemeinsamen Avoid Interface Config-Fenster
AI        = AI or {}
AI.ConfigUI = AI.ConfigUI or {}
AI_Config = AI_Config or {}

-- Stellt sicher, dass AI_Config.modules[moduleKey] existiert
local function GetTargetEntry(moduleKey)
    AI_Config = AI_Config or {}
    AI_Config.modules = AI_Config.modules or {}
    AI_Config.modules[moduleKey] = AI_Config.modules[moduleKey] or {}

    return AI_Config.modules[moduleKey]
end

local function GetPartyModule()
    if AI and AI.modules and type(AI.modules.party) == "table" then
        return AI.modules.party
    end
end

-- Hilfsfunktion: wendet das Layout des party-Frames neu an
local function ApplyPartyLayout()
    -- Versuchen, direkt das party-Modul zu erwischen
    if AI and AI.modules and type(AI.modules.party) == "table" then
        local m = AI.modules.party

        if m.ApplyLayout then
            -- Sauberer Weg: bestehendes ApplyLayout aus dem party-Modul nutzen
            m.ApplyLayout()
            return
        end
    end

    -- Fallback: komplettes Modul refreshen, falls das Modul-Objekt (noch) nicht greifbar ist
    if AI and AI.RefreshModule then
        AI.RefreshModule("party")
    end
end

local function BuildPartyConfigPage(page, moduleKey, labelText, helpers)

    
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
        local m = GetPartyModule()
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
            "AI_Party_PresetDD",   -- Name (STRING!)
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
            local m = GetPartyModule()
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
    -- Move- und Reset-Buttons (nur party-Frame)
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
        local m = GetPartyModule()
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
        local m = GetPartyModule()
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
            AI.RefreshModule("party")
        end
    end)

    -- Wenn die Seite geschlossen wird, Move-Modus sauber beenden
    local oldOnHide = page:GetScript("OnHide")
    page:SetScript("OnHide", function(self, ...)
        if oldOnHide then
            oldOnHide(self, ...)
        end

        local m = GetPartyModule()
        if m and m.StopMovingMode then
            m.StopMovingMode()
        end
        self.__isMoving = false
        if moveButton then
            moveButton:SetText("Frame bewegen")
        end
    end)


    -- party-spezifische Controls
    local widthSlider, heightSlider, ratioSlider, alphaSlider
    local orientationDD, spacingSlider
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
    local borderColorSwatch

    -- NEU: Custom-Farb-Controls
    local hpColorCustomCheck, hpColorSwatch
    local mpColorCustomCheck, mpColorSwatch

    local combatIconCheck, combatIconSizeSlider, combatIconAnchorDD, combatIconXSlider, combatIconYSlider
    local restingIconCheck, restingIconSizeSlider, restingIconAnchorDD, restingIconXSlider, restingIconYSlider
    local leaderIconCheck,  leaderIconSizeSlider,  leaderIconAnchorDD,  leaderIconXSlider,  leaderIconYSlider
    local raidIconCheck,    raidIconSizeSlider,    raidIconAnchorDD,    raidIconXSlider,    raidIconYSlider
    -- NEU: Rollen-Icon + Ready-Check-Icon
    local roleIconCheck,   roleIconSizeSlider,   roleIconAnchorDD,   roleIconXSlider,   roleIconYSlider
    local readyIconCheck,  readyIconSizeSlider,  readyIconAnchorDD,  readyIconXSlider,  readyIconYSlider

    -- Auren-Controls
    local buffsEnableCheck,  buffsSizeSlider,  buffsMaxSlider,  buffsPerRowSlider,  buffsAnchorDD,  buffsXSlider,  buffsYSlider,  buffsGrowDD
    local debuffsEnableCheck, debuffsSizeSlider, debuffsMaxSlider, debuffsPerRowSlider, debuffsAnchorDD, debuffsXSlider, debuffsYSlider, debuffsGrowDD

    -- NEU:
    local buffsOnlyOwnCheck
    local debuffsOnlyDispellableCheck

        local growItems = {
            { value = "RIGHT", text = "Nach rechts" },
            { value = "LEFT",  text = "Nach links" },
            { value = "UP",    text = "Nach oben" },
            { value = "DOWN",  text = "Nach unten" },
        }

        local orientationItems = {
            { value = "VERTICAL",   text = "Vertikal (untereinander)" },
            { value = "HORIZONTAL", text = "Horizontal (nebeneinander)" },
        }

    
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
            "AI_Party_WidthSlider",
            page,
            "Frame-Breite",
            10, 600, 1,
            sizeheader,
            -24
        )

        heightSlider = CreateSliderWithInput(
            "AI_Party_HeightSlider",
            page,
            "Frame-Höhe",
            10, 600, 1,
            widthSlider,
            -24
        )

        ratioSlider = CreateSliderWithInput(
            "AI_Party_HPRatioSlider",
            page,
            "HP-Anteil (vom Frame) in %",
            10, 90, 1,
            heightSlider,
            -24
        )

        alphaSlider = CreateSliderWithInput(
            "AI_Party_AlphaSlider",
            page,
            "Frame-Alpha in %",
            10, 100, 1,
            ratioSlider,
            -24
        )

        -- NEU: Ausrichtung und Abstand des Party-Blocks
        orientationDD = CreateSimpleDropdown(
            "AI_Party_OrientationDD",
            page,
            "Ausrichtung der Partyframes",
            orientationItems,
            alphaSlider,
            -24
        )

        spacingSlider = CreateSliderWithInput(
            "AI_Party_SpacingSlider",
            page,
            "Abstand zwischen Frames",
            0, 100, 1,
            orientationDD,
            -24
        )

        frameBgModeDD = CreateSimpleDropdown(
            "AI_Party_FrameBgModeDD",
            page,
            "Frame-Hintergrund einfärben",
            frameBgModeItems,
            spacingSlider,
            -24
        )

        -- Rahmen
        borderCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        borderCheck:SetPoint("TOPLEFT", frameBgModeDD, "BOTTOMLEFT", 0, -16)
        borderCheck.text = borderCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        borderCheck.text:SetPoint("LEFT", borderCheck, "RIGHT", 4, 0)
        borderCheck.text:SetText("Rahmen anzeigen")

        borderStyleDD = CreateSimpleDropdown(
            "AI_Party_BorderStyleDD",
            page,
            "Rahmen-Stil",
            borderStyleItems,
            borderCheck,
            -12
        )
                
        borderColorSwatch = CreateFrame("Button", nil, page)
        borderColorSwatch:SetSize(26, 16)
        borderColorSwatch:SetPoint("LEFT", borderStyleDD, "RIGHT", 16, 0)

        borderColorSwatch.bg = borderColorSwatch:CreateTexture(nil, "BACKGROUND")
        borderColorSwatch.bg:SetAllPoints()
        borderColorSwatch.bg:SetColorTexture(0, 0, 0, 1)

        borderColorSwatch.tex = borderColorSwatch:CreateTexture(nil, "ARTWORK")
        borderColorSwatch.tex:SetPoint("TOPLEFT", 1, -1)
        borderColorSwatch.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        borderColorSwatch.tex:SetColorTexture(0, 0, 0, 1)

        local borderColorLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        borderColorLabel:SetPoint("LEFT", borderColorSwatch, "RIGHT", 4, 0)
        borderColorLabel:SetText("Rahmenfarbe")

        borderSizeSlider = CreateSliderWithInput(
            "AI_Party_BorderSizeSlider",
            page,
            "Rahmen-Dicke",
            1, 16, 1,
            borderStyleDD,
            -24
        )

        -- >>> NEU: BorderSize je nach Stil aktiv/deaktivieren
        local function UpdateBorderSizeSliderEnabled(style)
            local cfg = GetTargetEntry(moduleKey)  -- "party"
            style = style or cfg.borderStyle or "PIXEL"

            local fixed =
                (style == "THIN") or
                (style == "THICK") or
                (style == "DIALOG")or
                (style == "TOOLTIP")

            if fixed then
                borderSizeSlider:Disable()
                if borderSizeSlider.input    then borderSizeSlider.input:Disable()    end
                if borderSizeSlider.valueBox then borderSizeSlider.valueBox:Disable() end
            else
                borderSizeSlider:Enable()
                if borderSizeSlider.input    then borderSizeSlider.input:Enable()    end
                if borderSizeSlider.valueBox then borderSizeSlider.valueBox:Enable() end
            end
        end

        -- >>> NEU: Border-Farbkreis je nach Stil aktiv/deaktivieren
        local function UpdateBorderColorSwatchEnabled(style)
            local cfg = GetTargetEntry(moduleKey)
            style = style or (cfg.borderStyle or "PIXEL")

            -- Nur PIXEL / THIN / THICK dürfen färbbar sein
            local allowColor =
                (style == "PIXEL") or
                (style == "THIN") or
                (style == "THICK")

            if borderColorSwatch then
                if allowColor then
                    borderColorSwatch:Enable()
                    borderColorSwatch:SetAlpha(1)
                else
                    borderColorSwatch:Disable()
                    borderColorSwatch:SetAlpha(0.4)
                end
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
            "AI_Party_HPTexDD",
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
            "AI_Party_MPTexDD",
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
            "AI_Party_NameXOffsetSlider",
            page,
            "X-Offset Spielername",
            -200, 200, 1,
            nameShow,
            -24
        )

        nameYSlider = CreateSliderWithInput(
            "AI_Party_NameYOffsetSlider",
            page,
            "Y-Offset Spielername",
            -200, 200, 1,
            nameXSlider,
            -24
        )

        nameSizeSlider = CreateSliderWithInput(
            "AI_Party_NameSizeSlider",
            page,
            "Schriftgröße Spielername",
            6, 32, 1,
            nameYSlider,
            -24
        )

        nameAnchorDD = CreateSimpleDropdown(
            "AI_Party_NameAnchorDD",
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
            "AI_Party_HPModeDD",
            page,
            "HP-Text Anzeige",
            hpMpModeItems,
            hpShow,
            -12
        )
        hpXSlider = CreateSliderWithInput(
            "AI_Party_HPXOffsetSlider",
            page,
            "X-Offset HP-Text",
            -200, 200, 1,
            hpModeDD,
            -24
        )

        hpYSlider = CreateSliderWithInput(
            "AI_Party_HPYOffsetSlider",
            page,
            "Y-Offset HP-Text",
            -200, 200, 1,
            hpXSlider,
            -24
        )

        hpSizeSlider = CreateSliderWithInput(
            "AI_Party_HPSizeSlider",
            page,
            "Schriftgröße HP-Text",
            6, 32, 1,
            hpYSlider,
            -24
        )

        hpAnchorDD = CreateSimpleDropdown(
            "AI_Party_HPAnchorDD",
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
            "AI_Party_MPModeDD",
            page,
            "Mana-Text Anzeige",
            hpMpModeItems,
            mpShow,
            -12
        )

        mpXSlider = CreateSliderWithInput(
            "AI_Party_MPXOffsetSlider",
            page,
            "X-Offset Mana-Text",
            -200, 200, 1,
            mpModeDD,
            -24
        )

        mpYSlider = CreateSliderWithInput(
            "AI_Party_MPYOffsetSlider",
            page,
            "Y-Offset Mana-Text",
            -200, 200, 1,
            mpXSlider,
            -24
        )
        mpSizeSlider = CreateSliderWithInput(
            "AI_Party_MPSizeSlider",
            page,
            "Schriftgröße Mana-Text",
            6, 32, 1,
            mpYSlider,
            -24
        )

        mpAnchorDD = CreateSimpleDropdown(
            "AI_Party_MPAnchorDD",
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
            "AI_Party_LvlXOffsetSlider",
            page,
            "X-Offset Level-Text",
            -200, 200, 1,
            lvlShow,
            -24
        )

        lvlYSlider = CreateSliderWithInput(
            "AI_Party_LvlYOffsetSlider",
            page,
            "Y-Offset Level-Text",
            -200, 200, 1,
            lvlXSlider,
            -24
        )
        lvlSizeSlider = CreateSliderWithInput(
            "AI_Party_LvlSizeSlider",
            page,
            "Schriftgröße Level-Text",
            6, 32, 1,
            lvlYSlider,
            -24
        )

        lvlAnchorDD = CreateSimpleDropdown(
            "AI_Party_LvlAnchorDD",
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
            "AI_Party_CombatIconSizeSlider",
            page,
            "Combat-Icon Größe",
            8, 64, 1,
            combatIconCheck,
            -24
        )

        combatIconXSlider = CreateSliderWithInput(
            "AI_Party_CombatIconXOffsetSlider",
            page,
            "Combat-Icon X-Offset",
            -200, 200, 1,
            combatIconSizeSlider,
            -24
        )

        combatIconYSlider = CreateSliderWithInput(
            "AI_Party_CombatIconYOffsetSlider",
            page,
            "Combat-Icon Y-Offset",
            -200, 200, 1,
            combatIconXSlider,
            -24
        )

        combatIconAnchorDD = CreateSimpleDropdown(
            "AI_Party_CombatIconAnchorDD",
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
            "AI_Party_RestingIconSizeSlider",
            page,
            "Resting-Icon Größe",
            8, 64, 1,
            restingIconCheck,
            -24
        )

        restingIconXSlider = CreateSliderWithInput(
            "AI_Party_RestingIconXOffsetSlider",
            page,
            "Resting-Icon X-Offset",
            -200, 200, 1,
            restingIconSizeSlider,
            -24
        )

        restingIconYSlider = CreateSliderWithInput(
            "AI_Party_RestingIconYOffsetSlider",
            page,
            "Resting-Icon Y-Offset",
            -200, 200, 1,
            restingIconXSlider,
            -24
        )

        restingIconAnchorDD = CreateSimpleDropdown(
            "AI_Party_RestingIconAnchorDD",
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
        leaderIconCheck.text:SetText("party-Leader-Icon anzeigen")

        leaderIconSizeSlider = CreateSliderWithInput(
            "AI_Party_LeaderIconSizeSlider",
            page,
            "Leader-Icon Größe",
            8, 64, 1,
            leaderIconCheck,
            -24
        )

        leaderIconXSlider = CreateSliderWithInput(
            "AI_Party_LeaderIconXOffsetSlider",
            page,
            "Leader-Icon X-Offset",
            -200, 200, 1,
            leaderIconSizeSlider,
            -24
        )

        leaderIconYSlider = CreateSliderWithInput(
            "AI_Party_LeaderIconYOffsetSlider",
            page,
            "Leader-Icon Y-Offset",
            -200, 200, 1,
            leaderIconXSlider,
            -24
        )

        leaderIconAnchorDD = CreateSimpleDropdown(
            "AI_Party_LeaderIconAnchorDD",
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
            "AI_Party_RaidIconSizeSlider",
            page,
            "Raidtarget-Icon Größe",
            8, 64, 1,
            raidIconCheck,
            -24
        )

        raidIconXSlider = CreateSliderWithInput(
            "AI_Party_RaidIconXOffsetSlider",
            page,
            "Raidtarget-Icon X-Offset",
            -200, 200, 1,
            raidIconSizeSlider,
            -24
        )

        raidIconYSlider = CreateSliderWithInput(
            "AI_Party_RaidIconYOffsetSlider",
            page,
            "Raidtarget-Icon Y-Offset",
            -200, 200, 1,
            raidIconXSlider,
            -24
        )

        raidIconAnchorDD = CreateSimpleDropdown(
            "AI_Party_RaidIconAnchorDD",
            page,
            "Raidtarget-Icon Anker",
            anchorItems,
            raidIconYSlider,
            -24
        )        -- Rollen-Icon (Tank/Heiler/DD)
        roleIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        roleIconCheck:SetPoint("TOPLEFT", raidIconAnchorDD, "BOTTOMLEFT", 0, -32)
        roleIconCheck.text = roleIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        roleIconCheck.text:SetPoint("LEFT", roleIconCheck, "RIGHT", 4, 0)
        roleIconCheck.text:SetText("Rollen-Icon anzeigen (Tank/Heiler/DD)")

        roleIconSizeSlider = CreateSliderWithInput(
            "AI_Party_RoleIconSizeSlider",
            page,
            "Rollen-Icon Größe",
            8, 64, 1,
            roleIconCheck,
            -24
        )

        roleIconXSlider = CreateSliderWithInput(
            "AI_Party_RoleIconXOffsetSlider",
            page,
            "Rollen-Icon X-Offset",
            -200, 200, 1,
            roleIconSizeSlider,
            -24
        )

        roleIconYSlider = CreateSliderWithInput(
            "AI_Party_RoleIconYOffsetSlider",
            page,
            "Rollen-Icon Y-Offset",
            -200, 200, 1,
            roleIconXSlider,
            -24
        )

        roleIconAnchorDD = CreateSimpleDropdown(
            "AI_Party_RoleIconAnchorDD",
            page,
            "Rollen-Icon Anker",
            anchorItems,
            roleIconYSlider,
            -24
        )

        -- Ready-Check-Icon
        readyIconCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        readyIconCheck:SetPoint("TOPLEFT", roleIconAnchorDD, "BOTTOMLEFT", 0, -32)
        readyIconCheck.text = readyIconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        readyIconCheck.text:SetPoint("LEFT", readyIconCheck, "RIGHT", 4, 0)
        readyIconCheck.text:SetText("Ready-Check-Icon anzeigen")

        readyIconSizeSlider = CreateSliderWithInput(
            "AI_Party_ReadyIconSizeSlider",
            page,
            "Ready-Icon Größe",
            8, 64, 1,
            readyIconCheck,
            -24
        )

        readyIconXSlider = CreateSliderWithInput(
            "AI_Party_ReadyIconXOffsetSlider",
            page,
            "Ready-Icon X-Offset",
            -200, 200, 1,
            readyIconSizeSlider,
            -24
        )

        readyIconYSlider = CreateSliderWithInput(
            "AI_Party_ReadyIconYOffsetSlider",
            page,
            "Ready-Icon Y-Offset",
            -200, 200, 1,
            readyIconXSlider,
            -24
        )

        readyIconAnchorDD = CreateSimpleDropdown(
            "AI_Party_ReadyIconAnchorDD",
            page,
            "Ready-Icon Anker",
            anchorItems,
            readyIconYSlider,
            -24
        )

        
        -------------------------------------------------
        -- Buffs / Debuffs
        -------------------------------------------------
        local aurasHeader = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        aurasHeader:SetPoint("TOPLEFT", readyIconAnchorDD, "BOTTOMLEFT", 0, -64)
        aurasHeader:SetText("Buffs / Debuffs")

        -- Buffs
        buffsEnableCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        buffsEnableCheck:SetPoint("TOPLEFT", aurasHeader, "BOTTOMLEFT", 0, -8)
        buffsEnableCheck.text = buffsEnableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        buffsEnableCheck.text:SetPoint("LEFT", buffsEnableCheck, "RIGHT", 4, 0)
        buffsEnableCheck.text:SetText("Buffs anzeigen")

        -- NEU: Nur eigene Buffs
        buffsOnlyOwnCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        buffsOnlyOwnCheck:SetPoint("LEFT", buffsEnableCheck.text, "RIGHT", 16, 0)
        buffsOnlyOwnCheck.text = buffsOnlyOwnCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        buffsOnlyOwnCheck.text:SetPoint("LEFT", buffsOnlyOwnCheck, "RIGHT", 4, 0)
        buffsOnlyOwnCheck.text:SetText("Nur eigene Buffs")

        buffsSizeSlider = CreateSliderWithInput(
            "AI_Party_BuffsSizeSlider",
            page,
            "Buff-Icon Größe",
            8, 64, 1,
            buffsEnableCheck,
            -24
        )

        buffsMaxSlider = CreateSliderWithInput(
            "AI_Party_BuffsMaxSlider",
            page,
            "Max. Buffs",
            1, 40, 1,
            buffsSizeSlider,
            -24
        )
        
        buffsPerRowSlider = CreateSliderWithInput(
            "AI_Party_BuffsPerRowSlider",
            page,
            "Buffs pro Reihe",
            1, 40, 1,
            buffsMaxSlider,
            -24
        )

        buffsAnchorDD = CreateSimpleDropdown(
            "AI_Party_BuffsAnchorDD",
            page,
            "Buff-Anker am Frame",
            anchorItems,
            buffsPerRowSlider,
            -24
        )

        buffsXSlider = CreateSliderWithInput(
            "AI_Party_BuffsXOffsetSlider",
            page,
            "Buff X-Offset",
            -400, 400, 1,
            buffsAnchorDD,
            -24
        )

        buffsYSlider = CreateSliderWithInput(
            "AI_Party_BuffsYOffsetSlider",
            page,
            "Buff Y-Offset",
            -400, 400, 1,
            buffsXSlider,
            -24
        )

        buffsGrowDD = CreateSimpleDropdown(
            "AI_Party_BuffsGrowDD",
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

        debuffsOnlyDispellableCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        debuffsOnlyDispellableCheck:SetPoint("LEFT", debuffsEnableCheck.text, "RIGHT", 16, 0)
        debuffsOnlyDispellableCheck.text = debuffsOnlyDispellableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        debuffsOnlyDispellableCheck.text:SetPoint("LEFT", debuffsOnlyDispellableCheck, "RIGHT", 4, 0)
        debuffsOnlyDispellableCheck.text:SetText("Nur dispellbare Debuffs")

        debuffsSizeSlider = CreateSliderWithInput(
            "AI_Party_DebuffsSizeSlider",
            page,
            "Debuff-Icon Größe",
            8, 64, 1,
            debuffsEnableCheck,
            -24
        )

        debuffsMaxSlider = CreateSliderWithInput(
            "AI_Party_DebuffsMaxSlider",
            page,
            "Max. Debuffs",
            1, 40, 1,
            debuffsSizeSlider,
            -24
        )
        
        debuffsPerRowSlider = CreateSliderWithInput(
            "AI_Party_DebuffsPerRowSlider",
            page,
            "Debuffs pro Reihe",
            1, 40, 1,
            debuffsMaxSlider,
            -24
        )

        debuffsAnchorDD = CreateSimpleDropdown(
            "AI_Party_DebuffsAnchorDD",
            page,
            "Debuff-Anker am Frame",
            anchorItems,
            debuffsPerRowSlider,
            -24
        )

        debuffsXSlider = CreateSliderWithInput(
            "AI_Party_DebuffsXOffsetSlider",
            page,
            "Debuff X-Offset",
            -400, 400, 1,
            debuffsAnchorDD,
            -24
        )

        debuffsYSlider = CreateSliderWithInput(
            "AI_Party_DebuffsYOffsetSlider",
            page,
            "Debuff Y-Offset",
            -400, 400, 1,
            debuffsXSlider,
            -24
        )

        debuffsGrowDD = CreateSimpleDropdown(
            "AI_Party_DebuffsGrowDD",
            page,
            "Debuff Wachstumsrichtung",
            growItems,
            debuffsYSlider,
            -24
        )


        -------------------------------------------------
        -- party-Controls am Page-Objekt speichern
        -------------------------------------------------
        page.widthSlider      = widthSlider
        page.heightSlider     = heightSlider
        page.ratioSlider      = ratioSlider
        page.alphaSlider      = alphaSlider
        page.orientationDD    = orientationDD
        page.spacingSlider    = spacingSlider

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
        page.borderColorSwatch = borderColorSwatch


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

        -- NEU: Rollen-Icon & Ready-Icon
        page.roleIconCheck          = roleIconCheck
        page.roleIconSizeSlider     = roleIconSizeSlider
        page.roleIconAnchorDD       = roleIconAnchorDD
        page.roleIconXSlider        = roleIconXSlider
        page.roleIconYSlider        = roleIconYSlider

        page.readyIconCheck         = readyIconCheck
        page.readyIconSizeSlider    = readyIconSizeSlider
        page.readyIconAnchorDD      = readyIconAnchorDD
        page.readyIconXSlider       = readyIconXSlider
        page.readyIconYSlider       = readyIconYSlider

        -- Buff-/Debuff-Controls auf der Page merken
        page.buffsEnableCheck   = buffsEnableCheck
        page.buffsSizeSlider    = buffsSizeSlider
        page.buffsMaxSlider     = buffsMaxSlider
        page.buffsAnchorDD      = buffsAnchorDD
        page.buffsXSlider       = buffsXSlider
        page.buffsYSlider       = buffsYSlider
        page.buffsGrowDD        = buffsGrowDD
        page.buffsOnlyOwnCheck  = buffsOnlyOwnCheck

        page.debuffsEnableCheck = debuffsEnableCheck
        page.debuffsSizeSlider  = debuffsSizeSlider
        page.debuffsMaxSlider   = debuffsMaxSlider
        page.debuffsAnchorDD    = debuffsAnchorDD
        page.debuffsXSlider     = debuffsXSlider
        page.debuffsYSlider     = debuffsYSlider
        page.debuffsGrowDD      = debuffsGrowDD
        page.buffsPerRowSlider  = buffsPerRowSlider
        page.debuffsPerRowSlider = debuffsPerRowSlider
        page.debuffsOnlyDispellableCheck = debuffsOnlyDispellableCheck

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
            entry = { enabled = (moduleKey == "party") }
            AI_Config.modules[moduleKey] = entry
        elseif entry.enabled == nil then
            entry.enabled = (moduleKey == "party")
        end

        check:SetChecked(entry.enabled and true or false)

            -- Defaults wie im party-Modul
            entry.width       = entry.width       or 260
            entry.height      = entry.height      or 60
            entry.hpRatio     = entry.hpRatio     or 0.66
            entry.alpha       = entry.alpha       or 1
            entry.manaEnabled = (entry.manaEnabled ~= false)

            -- NEU: Ausrichtung + Abstand
            if entry.layoutOrientation ~= "VERTICAL" and entry.layoutOrientation ~= "HORIZONTAL" then
                entry.layoutOrientation = "VERTICAL"
            end

            if type(entry.spacing) ~= "number" then
                entry.spacing = 4
            elseif entry.spacing < 0 then
                entry.spacing = 0
            end

            -- Referenz auf Controls am Page-Objekt
            -- (das sind lokale Variablen von page.Init, keine Upvalues)
            local widthSlider      = page.widthSlider
            local heightSlider     = page.heightSlider
            local ratioSlider      = page.ratioSlider
            local alphaSlider      = page.alphaSlider
            local orientationDD    = page.orientationDD
            local spacingSlider    = page.spacingSlider


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

            -- NEU: Rollen-Icon & Ready-Icon
            local roleIconCheck         = page.roleIconCheck
            local roleIconSizeSlider    = page.roleIconSizeSlider
            local roleIconAnchorDD      = page.roleIconAnchorDD
            local roleIconXSlider       = page.roleIconXSlider
            local roleIconYSlider       = page.roleIconYSlider

            local readyIconCheck        = page.readyIconCheck
            local readyIconSizeSlider   = page.readyIconSizeSlider
            local readyIconAnchorDD     = page.readyIconAnchorDD
            local readyIconXSlider      = page.readyIconXSlider
            local readyIconYSlider      = page.readyIconYSlider

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
            entry.debuffs = entry.debuffs or {}   -- <– zuerst sicherstellen, dass die Tabelle existiert

            entry.buffs.onlyOwn = (entry.buffs.onlyOwn == true)
            entry.debuffs.onlyDispellable = (entry.debuffs.onlyDispellable == true)

            entry.buffs.enabled = (entry.buffs.enabled ~= false)
            entry.buffs.anchor  = entry.buffs.anchor or "TOPLEFT"
            entry.buffs.x       = entry.buffs.x or 0
            entry.buffs.y       = entry.buffs.y or 10
            entry.buffs.size    = entry.buffs.size or 24
            entry.buffs.grow    = entry.buffs.grow or "RIGHT"
            entry.buffs.max     = entry.buffs.max or 12
            entry.buffs.perRow  = entry.buffs.perRow or 8

            entry.debuffs.enabled = (entry.debuffs.enabled ~= false)
            entry.debuffs.anchor  = entry.debuffs.anchor or "TOPLEFT"
            entry.debuffs.x       = entry.debuffs.x or 0
            entry.debuffs.y       = entry.debuffs.y or -26
            entry.debuffs.size    = entry.debuffs.size or 24
            entry.debuffs.grow    = entry.debuffs.grow or "RIGHT"
            entry.debuffs.max     = entry.debuffs.max or 12
            entry.debuffs.perRow  = entry.debuffs.perRow or 8

            entry.buffs.onlyOwn = (entry.buffs.onlyOwn == true)
            entry.debuffs.onlyDispellable = (entry.debuffs.onlyDispellable == true)

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

            -- Rahmenfarbe (Pixel / allgemein)
            entry.borderColor = entry.borderColor or { r = 0, g = 0, b = 0 }

            if borderColorSwatch and borderColorSwatch.tex then
                borderColorSwatch.tex:SetColorTexture(
                    entry.borderColor.r or 0,
                    entry.borderColor.g or 0,
                    entry.borderColor.b or 0,
                    1
                )
            end


            if entry.lowHPHighlightEnabled == nil then
                entry.lowHPHighlightEnabled = false
            end

            -- Icon-Defaults (nur für Config-UI, eigentliche Logik ist im party-Modul)
            if entry.combatIconEnabled == nil then entry.combatIconEnabled = true end
            if entry.restingIconEnabled == nil then entry.restingIconEnabled = true end
            if entry.leaderIconEnabled  == nil then entry.leaderIconEnabled  = true end
            if entry.raidIconEnabled    == nil then entry.raidIconEnabled    = true end

            entry.combatIconSize   = entry.combatIconSize   or 24
            entry.restingIconSize  = entry.restingIconSize  or 24
            entry.leaderIconSize   = entry.leaderIconSize   or 18
            entry.raidIconSize     = entry.raidIconSize     or 20

            -- NEU: Rollen-Icon & Ready-Icon Defaults
            if entry.roleIconEnabled == nil then entry.roleIconEnabled = true end
            if entry.readyIconEnabled == nil then entry.readyIconEnabled = true end

            entry.roleIconSize  = entry.roleIconSize  or 18
            entry.readyIconSize = entry.readyIconSize or 20

            entry.combatIconAnchor  = entry.combatIconAnchor  or "TOPLEFT"
            entry.restingIconAnchor = entry.restingIconAnchor or "TOPLEFT"
            entry.leaderIconAnchor  = entry.leaderIconAnchor  or "TOPRIGHT"
            entry.raidIconAnchor    = entry.raidIconAnchor    or "TOP"
            entry.roleIconAnchor   = entry.roleIconAnchor   or "TOPRIGHT"
            entry.readyIconAnchor  = entry.readyIconAnchor  or "CENTER"

            entry.combatIconXOffset  = entry.combatIconXOffset  or -4
            entry.combatIconYOffset  = entry.combatIconYOffset  or 4
            entry.restingIconXOffset = entry.restingIconXOffset or -4
            entry.restingIconYOffset = entry.restingIconYOffset or 4
            entry.leaderIconXOffset  = entry.leaderIconXOffset  or 4
            entry.leaderIconYOffset  = entry.leaderIconYOffset  or 4
            entry.raidIconXOffset    = entry.raidIconXOffset    or 0
            entry.raidIconYOffset    = entry.raidIconYOffset    or 10
            entry.roleIconXOffset   = entry.roleIconXOffset   or 4
            entry.roleIconYOffset   = entry.roleIconYOffset   or -10
            entry.readyIconXOffset  = entry.readyIconXOffset  or 0
            entry.readyIconYOffset  = entry.readyIconYOffset  or 0

            -- Slider & Checks setzen
            widthSlider:SetValue(entry.width);        widthSlider:SetTextSync(entry.width)
            heightSlider:SetValue(entry.height);      heightSlider:SetTextSync(entry.height)
            
            if orientationDD then
                orientationDD:SetSelected(entry.layoutOrientation)
            end
            if spacingSlider then
                spacingSlider:SetValue(entry.spacing)
                spacingSlider:SetTextSync(entry.spacing)
            end

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
                    ApplyPartyLayout()
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
            -- NEU: Border-Farbkreis passend zum aktuellen Stil aktiv/deaktivieren
            UpdateBorderColorSwatchEnabled(entry.borderStyle)



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
            
            -- NEU: Rollen-Icon
            roleIconCheck:SetChecked(entry.roleIconEnabled)
            roleIconSizeSlider:SetValue(entry.roleIconSize); roleIconSizeSlider:SetTextSync(entry.roleIconSize)
            roleIconAnchorDD:SetSelected(entry.roleIconAnchor)
            roleIconXSlider:SetValue(entry.roleIconXOffset); roleIconXSlider:SetTextSync(entry.roleIconXOffset)
            roleIconYSlider:SetValue(entry.roleIconYOffset); roleIconYSlider:SetTextSync(entry.roleIconYOffset)

            -- NEU: Ready-Icon
            readyIconCheck:SetChecked(entry.readyIconEnabled)
            readyIconSizeSlider:SetValue(entry.readyIconSize); readyIconSizeSlider:SetTextSync(entry.readyIconSize)
            readyIconAnchorDD:SetSelected(entry.readyIconAnchor)
            readyIconXSlider:SetValue(entry.readyIconXOffset); readyIconXSlider:SetTextSync(entry.readyIconXOffset)
            readyIconYSlider:SetValue(entry.readyIconYOffset); readyIconYSlider:SetTextSync(entry.readyIconYOffset)

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
                if buffsOnlyOwnCheck then
                    buffsOnlyOwnCheck:SetChecked(entry.buffs.onlyOwn)
                end
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
                if debuffsOnlyDispellableCheck then
                    debuffsOnlyDispellableCheck:SetChecked(entry.debuffs.onlyDispellable)
                end
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

        local function GetPartyCfg()
            AI_Config = AI_Config or {}
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.party = AI_Config.modules.party or {}
            return AI_Config.modules.party
        end

        local function markDirtyAndApply()
            page.SetDirty(true)
            ApplyPartyLayout()
        end

        widthSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.width = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        heightSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.height = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        ratioSlider:HookScript("OnValueChanged", function(self, value)
            local cfg   = GetPartyCfg()
            local ratio = value / 100
            if ratio < 0.1 then ratio = 0.1 end
            if ratio > 0.9 then ratio = 0.9 end
            cfg.hpRatio = ratio
            markDirtyAndApply()
        end)

        alphaSlider:HookScript("OnValueChanged", function(self, value)
            local cfg   = GetPartyCfg()
            local alpha = value / 100
            if alpha < 0.1 then alpha = 0.1 end
            if alpha > 1.0 then alpha = 1.0 end
            cfg.alpha   = alpha
            markDirtyAndApply()
        end)

        -- NEU: Ausrichtung (vertikal/horizontal)
        function orientationDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            if value ~= "HORIZONTAL" then
                cfg.layoutOrientation = "VERTICAL"
            else
                cfg.layoutOrientation = "HORIZONTAL"
            end
            markDirtyAndApply()
        end

        -- NEU: Abstand zwischen den Partyframes
        spacingSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            local v = math.floor(value + 0.5)
            if v < 0 then v = 0 end
            cfg.spacing = v
            markDirtyAndApply()
        end)

        manaCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.manaEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)


        hpClassCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()

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
            local cfg = GetPartyCfg()
            cfg.hpUseCustomColor = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        mpColorCustomCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.mpUseCustomColor = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        -- ColorPicker für HP-Farbe (neues API)
        hpColorSwatch:SetScript("OnClick", function()
            local cfg = GetPartyCfg()

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
            local cfg = GetPartyCfg()

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
        local cfg = GetPartyCfg()
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
            local cfg = GetPartyCfg()
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
            local cfg = GetPartyCfg()
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
            local cfg = GetPartyCfg()
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
        
        -- ColorPicker für Rahmenfarbe (Pixel-Border)
        borderColorSwatch:SetScript("OnClick", function()
            local cfg = GetPartyCfg()
            cfg.borderColor = cfg.borderColor or { r = 0, g = 0, b = 0 }

            local prevR = cfg.borderColor.r or 0
            local prevG = cfg.borderColor.g or 0
            local prevB = cfg.borderColor.b or 0

            local function applyColor(r, g, b)
                cfg.borderColor.r = r
                cfg.borderColor.g = g
                cfg.borderColor.b = b

                if borderColorSwatch.tex then
                    borderColorSwatch.tex:SetColorTexture(r, g, b, 1)
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
            local cfg = GetPartyCfg()
            cfg.borderStyle = value

            -- Slider und Farbrad je nach Stil updaten
            UpdateBorderSizeSliderEnabled(value)
            UpdateBorderColorSwatchEnabled(value)

            markDirtyAndApply()
        end

        function hpTexDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.hpTexture = value
            markDirtyAndApply()
        end

        function mpTexDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.mpTexture = value
            markDirtyAndApply()
        end

        function frameBgModeDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.frameBgMode = value
            markDirtyAndApply()
        end

        function hpModeDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.hpTextMode = value
            markDirtyAndApply()
        end

        function mpModeDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.mpTextMode = value
            markDirtyAndApply()
        end

        -- Textsichtbarkeit
        nameShow:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.showName = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        hpShow:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.showHPText = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        mpShow:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.showMPText = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        lvlShow:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.showLevelText = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        -- Schriftgrößen
        nameSizeSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.nameSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        hpSizeSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.hpTextSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        mpSizeSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.mpTextSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        lvlSizeSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.levelTextSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        -- Anchor Dropdowns
        function nameAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.nameAnchor = value
            markDirtyAndApply()
        end
        function hpAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.hpTextAnchor = value
            markDirtyAndApply()
        end
        function mpAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.mpTextAnchor = value
            markDirtyAndApply()
        end
        function lvlAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.levelAnchor = value
            markDirtyAndApply()
        end

        -- Offsets
        nameXSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.nameXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        nameYSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.nameYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        hpXSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.hpTextXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        hpYSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.hpTextYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        mpXSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.mpTextXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        mpYSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.mpTextYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        lvlXSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.levelXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)
        lvlYSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.levelYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        -- Bold / Shadow
        nameBoldCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.nameBold = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        nameShadowCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.nameShadow = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        hpBoldCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.hpTextBold = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        hpShadowCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.hpTextShadow = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        mpBoldCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.mpTextBold = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        mpShadowCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.mpTextShadow = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        lvlBoldCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.levelBold = self:GetChecked() and true or false
            markDirtyAndApply()
        end)
        lvlShadowCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.levelShadow = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        -- Rahmen
        borderCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.borderEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        borderSizeSlider:HookScript("OnValueChanged", function(self, value)
            local cfg = GetPartyCfg()
            cfg.borderSize = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        -- -- Low-HP-Highlight
        -- lowHPCheck:SetScript("OnClick", function(self)
        --     local cfg = GetPartyCfg()
        -- cfg.lowHPHighlightEnabled = self:GetChecked() and true or false
        --     markDirtyAndApply()
        -- end)

        -- Combat Icon
        combatIconCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.combatIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        combatIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.combatIconSize = value
            markDirtyAndApply()
        end)

        function combatIconAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.combatIconAnchor = value
            markDirtyAndApply()
        end

        combatIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.combatIconXOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        combatIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.combatIconYOffset = math.floor(value + 0.5)
            markDirtyAndApply()
        end)

        -- Resting Icon
        restingIconCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.restingIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        restingIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.restingIconSize = value
            markDirtyAndApply()
        end)

        function restingIconAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.restingIconAnchor = value
            markDirtyAndApply()
        end

        restingIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.restingIconXOffset = value
            markDirtyAndApply()
        end)

        restingIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.restingIconYOffset = value
            markDirtyAndApply()
        end)

        -- Leader Icon
        leaderIconCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.leaderIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        leaderIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.leaderIconSize = value
            markDirtyAndApply()
        end)

        function leaderIconAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.leaderIconAnchor = value
            markDirtyAndApply()
        end

        leaderIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.leaderIconXOffset = value
            markDirtyAndApply()
        end)

        leaderIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.leaderIconYOffset = value
            markDirtyAndApply()
        end)

        -- Raid Icon
        raidIconCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.raidIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        raidIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.raidIconSize = value
            markDirtyAndApply()
        end)

        function raidIconAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.raidIconAnchor = value
            markDirtyAndApply()
        end

        raidIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.raidIconXOffset = value
            markDirtyAndApply()
        end)

        raidIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.raidIconYOffset = value
            markDirtyAndApply()
        end)
        
        -- Rollen-Icon
        roleIconCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.roleIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        roleIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.roleIconSize = value
            markDirtyAndApply()
        end)

        function roleIconAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.roleIconAnchor = value
            markDirtyAndApply()
        end

        roleIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.roleIconXOffset = value
            markDirtyAndApply()
        end)

        roleIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.roleIconYOffset = value
            markDirtyAndApply()
        end)

        -- Ready-Check-Icon
        readyIconCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.readyIconEnabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        readyIconSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.readyIconSize = value
            markDirtyAndApply()
        end)

        function readyIconAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.readyIconAnchor = value
            markDirtyAndApply()
        end

        readyIconXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.readyIconXOffset = value
            markDirtyAndApply()
        end)

        readyIconYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.readyIconYOffset = value
            markDirtyAndApply()
        end)

        -- Buff-Options
        buffsEnableCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.buffs.enabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        debuffsEnableCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.debuffs.enabled = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        buffsOnlyOwnCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.buffs.onlyOwn = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        debuffsOnlyDispellableCheck:SetScript("OnClick", function(self)
            local cfg = GetPartyCfg()
            cfg.debuffs.onlyDispellable = self:GetChecked() and true or false
            markDirtyAndApply()
        end)

        buffsSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.buffs.size = value
            markDirtyAndApply()
        end)

        buffsMaxSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.buffs.max = value
            markDirtyAndApply()
        end)

        function buffsAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.buffs.anchor = value
            markDirtyAndApply()
        end

        buffsXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.buffs.x = value
            markDirtyAndApply()
        end)

        buffsYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.buffs.y = value
            markDirtyAndApply()
        end)

        function buffsGrowDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.buffs.grow = value
            markDirtyAndApply()
        end

        debuffsSizeSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.debuffs.size = value
            markDirtyAndApply()
        end)

        debuffsMaxSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.debuffs.max = value
            markDirtyAndApply()
        end)

        function debuffsAnchorDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.debuffs.anchor = value
            markDirtyAndApply()
        end

        debuffsXSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.debuffs.x = value
            markDirtyAndApply()
        end)

        debuffsYSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.debuffs.y = value
            markDirtyAndApply()
        end)

        function debuffsGrowDD:OnValueChanged(value)
            local cfg = GetPartyCfg()
            cfg.debuffs.grow = value
            markDirtyAndApply()
        end
        
        buffsPerRowSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.buffs.perRow = value
            markDirtyAndApply()
        end)

        debuffsPerRowSlider:HookScript("OnValueChanged", function(self, value)
            value = math.floor(value + 0.5)
            local cfg = GetPartyCfg()
            cfg.debuffs.perRow = value
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
                if AI and AI.modules and AI.modules.party and AI.modules.party.StartMovingMode then
                    AI.modules.party.StartMovingMode()
                end
            else
                self:SetText("Frame bewegen")
                if AI and AI.modules and AI.modules.party and AI.modules.party.StopMovingMode then
                    AI.modules.party.StopMovingMode()
                end
            end

            page.SetDirty(true)
        end)
    end
    
    if resetPosButton then
        resetPosButton:SetScript("OnClick", function(self)
            AI_Config.modules = AI_Config.modules or {}
            AI_Config.modules.party = AI_Config.modules.party or {}
            local cfg = AI_Config.modules.party

            -- Frame-Position im Modul auf Default zurücksetzen
            if AI and AI.modules and AI.modules.party and AI.modules.party.ResetPosition then
                AI.modules.party.ResetPosition()
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

            -- UI neu initialisieren (setzt die Defaults aus GetPartyConfig/page.Init)
            if page.Init then
                page.Init()
            end

            -- Layout auf dem echten Frame neu anwenden
            ApplyPartyLayout()

            -- Änderungen markieren
            page.SetDirty(true)
        end)
    end
end

-- Bei der Registry anmelden (Reihenfolge 10 = links als erstes Tab)
if AI.ConfigUI and AI.ConfigUI.RegisterPage then
    AI.ConfigUI.RegisterPage("party", "party", 50, BuildPartyConfigPage)
end