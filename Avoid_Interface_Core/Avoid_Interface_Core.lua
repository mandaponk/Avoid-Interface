-- Avoid_Interface_Core.lua
-- Zentrale Verwaltung, SavedVariables, Modul-Registry, Refresh-Logik

AI_Config = AI_Config or {}

-------------------------------------------------
-- Defaults & Kompatibilität sicherstellen
-------------------------------------------------
local function AI_EnsureModuleDefaults()
    AI_Config.modules = AI_Config.modules or {}

    local defaults = {
        player = true,
        target = false,
        tot    = false,
        focus  = false,
        party  = false,
    }

    for key, defEnabled in pairs(defaults) do
        local v = AI_Config.modules[key]

        if type(v) == "boolean" then
            -- Alte Form: modules.player = true/false
            AI_Config.modules[key] = { enabled = v }
        elseif type(v) == "table" then
            if v.enabled == nil then
                v.enabled = defEnabled
            end
        else
            -- Neu oder kaputt: neu aufbauen
            AI_Config.modules[key] = { enabled = defEnabled }
        end
    end
end

AI_EnsureModuleDefaults()

-------------------------------------------------
-- Globale Tabelle für Avoid Interface
-------------------------------------------------
AI = AI or {}
AI.modules = AI.modules or {}

-- NEU: Config-UI Registry
AI.ConfigUI = AI.ConfigUI or {}
AI.ConfigUI.pages = AI.ConfigUI.pages or {}

function AI.ConfigUI.RegisterPage(key, label, order, buildFunc)
    if not key or type(buildFunc) ~= "function" then return end
    AI.ConfigUI.pages[key] = {
        key       = key,
        label     = label or key,
        order     = order or 100,
        buildFunc = buildFunc,
    }
end


-------------------------------------------------
-- Modul-Registrierung
-------------------------------------------------
function AI.RegisterFrameType(key, moduleTable)
    if not key or type(moduleTable) ~= "table" then return end
    AI.modules[key] = moduleTable

    -- Wenn Config schon existiert, direkt Status anwenden
    C_Timer.After(0, function()
        AI.RefreshModule(key)
    end)
end

-------------------------------------------------
-- Modul-Refresh
-------------------------------------------------
function AI.RefreshModule(key)
    local m = AI.modules[key]
    if not m then return end

    AI_EnsureModuleDefaults()
    local entry = AI_Config.modules[key]
    local enabled

    if type(entry) == "table" then
        enabled = not not entry.enabled
    elseif type(entry) == "boolean" then
        enabled = entry
    else
        enabled = false
    end

    if enabled then
        if m.Enable then
            m.Enable()
        elseif m.Refresh then
            m.Refresh()
        end
    else
        if m.Disable then
            m.Disable()
        elseif m.Hide then
            m.Hide()
        end
    end
end

function AI.RefreshAllModules()
    AI_EnsureModuleDefaults()
    for key, _ in pairs(AI.modules) do
        AI.RefreshModule(key)
    end
end

-------------------------------------------------
-- Slash Command
-------------------------------------------------
SLASH_AVOIDINTERFACE1 = "/ai"
SlashCmdList["AVOIDINTERFACE"] = function(msg)
    if AvoidInterfaceConfigFrame and AvoidInterfaceConfigFrame:IsShown() then
        AvoidInterfaceConfigFrame:Hide()
    elseif AvoidInterfaceConfigFrame then
        AvoidInterfaceConfigFrame:Show()
    else
        print("|cffff5555Avoid Interface Core:|r Config-UI ist nicht geladen.")
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------
local coreEvents = CreateFrame("Frame")
coreEvents:RegisterEvent("ADDON_LOADED")
coreEvents:RegisterEvent("PLAYER_LOGIN")

coreEvents:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Avoid_Interface_Core" then
        -- Sicherstellen, dass Module-Defaults passen
        AI_EnsureModuleDefaults()
    elseif event == "PLAYER_LOGIN" then
        -- Nach Login alle Module in korrekten Status bringen
        C_Timer.After(0.1, function()
            AI.RefreshAllModules()
        end)
    end
end)
