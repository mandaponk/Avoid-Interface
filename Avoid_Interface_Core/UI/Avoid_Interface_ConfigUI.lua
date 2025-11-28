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

-- >>> NEU: immer schön vor die anderen Frames <<<
f:SetFrameStrata("DIALOG")              -- oder "TOOLTIP", wenn du es *ganz* oben willst
f:SetToplevel(true)
f:SetFrameLevel(100)                    -- etwas höher als Standard

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
local moduleOrder = {}

local function RebuildModuleOrder()
    wipe(moduleOrder)

    if AI and AI.ConfigUI and AI.ConfigUI.pages then
        for key, info in pairs(AI.ConfigUI.pages) do
            table.insert(moduleOrder, info)
        end

        table.sort(moduleOrder, function(a, b)
            return (a.order or 100) < (b.order or 100)
        end)
    end
end


local tabs         = {}
local scrollFrames = {}
local pages        = {}
local currentIndex = 1

-- Baut Tabs + ScrollFrames nur einmal, wenn das Fenster wirklich angezeigt wird
local function BuildTabs()
    -- Wenn schon gebaut, nichts mehr tun
    if #tabs > 0 then
        return
    end

    -- Reihenfolge der Module aus der Registry holen
    RebuildModuleOrder()

    -- Wenn immer noch nix da ist, abbrechen
    if #moduleOrder == 0 then
        return
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
end

-------------------------------------------------
-- Tabs umschalten
-------------------------------------------------
local function ShowTab(index)
    if not index or index < 1 then
        index = 1
    end
    if #tabs == 0 then
        return
    end

    currentIndex = index

    -- ScrollFrames ein-/ausblenden
    for i, scroll in ipairs(scrollFrames) do
        if scroll then
            if i == index then
                scroll:Show()
            else
                scroll:Hide()
            end
        end
    end

    -- Tabs optisch markieren ohne PanelTemplates
    for i, tab in ipairs(tabs) do
        if tab then
            if i == index then
                -- aktiv
                tab:LockHighlight()
                tab:SetNormalFontObject(GameFontHighlight)
            else
                -- inaktiv
                tab:UnlockHighlight()
                tab:SetNormalFontObject(GameFontNormal)
            end
        end
    end
end

_G.ShowTab = ShowTab   -- Kannst du lassen, falls anderswo global aufgerufen wird




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
-- Content Helper
-------------------------------------------------
local function BuildModuleContent(page, moduleKey, labelText)
    if not AI or not AI.ConfigUI or not AI.ConfigUI.pages then return end
    local info = AI.ConfigUI.pages[moduleKey]
    if not info or type(info.buildFunc) ~= "function" then return end

    -- Helper-Tabelle, die wir an das Modul geben
    local helpers = {
        CreateSliderWithInput = CreateSliderWithInput,
        CreateSimpleDropdown  = CreateSimpleDropdown,
        LEFT_MARGIN           = LEFT_MARGIN,  -- falls benötigt
    }

    info.buildFunc(page, moduleKey, labelText, helpers)
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

    BuildModuleContent(page, moduleKey, labelText)

    -------------------------------------------------
    -- Speichern
    -------------------------------------------------
    saveButton:SetScript("OnClick", function()
    -- Wenn die Modul-Seite einen eigenen Save-Handler hat, hier aufrufen
    if page.OnSave then
        page:OnSave()
    end

    -- Änderungen sind „übernommen“ → Dirty-Flag löschen
    page.SetDirty(false)
end)


end

f:SetScript("OnShow", function()
    -- Tabs + ScrollFrames bauen (inkl. moduleOrder aus Registry)
    BuildTabs()

    -- Falls nun Module vorhanden sind, für jede Seite den Inhalt bauen (einmalig)
    for i, info in ipairs(moduleOrder) do
        local page = pages[i]
        if page and not page.contentBuilt then
            CreateModulePage(page, info.key, info.label)
            page.contentBuilt = true
        end

        if page and page.Init then
            page.Init()
        end
    end

    if #tabs > 0 then
        ShowTab(currentIndex or 1)
    end
end)

