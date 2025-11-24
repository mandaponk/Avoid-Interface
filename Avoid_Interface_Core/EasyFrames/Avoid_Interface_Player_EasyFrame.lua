local M = {}
local f
local unit = "player"

local function UpdateFrame()
    if not UnitExists(unit) then
        f:Hide()
        return
    end

    f:Show()
    -- Update values
end

function M.Init()
    if f then return end

    f = CreateFrame("Button", "AI_PlayerFrame", UIParent, "SecureUnitButtonTemplate")
    f:SetAttribute("unit", unit)
    f:SetSize(260, 42)
    f:SetPoint("CENTER", UIParent, "CENTER", -300, -200)
    f:Hide()

    -- TODO: Layout & Scripts
end

function M.Refresh()
    M.Init()
    UpdateFrame()
end

function M.Hide()
    if f then f:Hide() end
end

AI_RegisterFrameType("player", M)
