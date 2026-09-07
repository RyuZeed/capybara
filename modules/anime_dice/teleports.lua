--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (TELEPORT ENGINE)
	Module: modules/anime_dice/teleports.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local Teleports = {}
Teleports.__index = Teleports

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

Teleports.Zones = {
    ["Traits"] = Vector3.new(325.5, 15.3, 82.2),
    ["Trade"] = Vector3.new(247.2, 15.3, 6.2),
    ["Grades"] = Vector3.new(245.9, 15.3, 84.7),
    ["Shop"] = Vector3.new(253.2, 13.9, -290.0),
    ["Quests"] = Vector3.new(324.6, 15.3, 4.7),
    ["Towers"] = Vector3.new(285.5, 24.9, 43.7),
    ["Hub Area"] = Vector3.new(285.5, 7.0, 136.9),
    ["Selling"] = Vector3.new(317.3, 14.0, -288.1),
    ["Dice Shop"] = Vector3.new(285.5, 14.0, -304.3),
    ["Shop Area"] = Vector3.new(285.5, 7.0, -272.6),
}

local function getHRP()
    local char = LocalPlayer and LocalPlayer.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp end
    end
    return nil
end

function Teleports.TeleportTo(target)
    local hrp = getHRP()
    if not hrp then return false, "HumanoidRootPart not found" end

    local targetCF
    if typeof(target) == "CFrame" then
        targetCF = target
    elseif typeof(target) == "Vector3" then
        targetCF = CFrame.new(target)
    else
        return false, "Invalid target type"
    end

    pcall(function()
        hrp.CFrame = targetCF
    end)
    return true
end

function Teleports.TeleportToZone(zoneName)
    -- Check static coordinates
    local pos = Teleports.Zones[zoneName]
    if pos then
        return Teleports.TeleportTo(pos)
    end

    -- Check workspace Zones model dynamically
    local zonesFolder = Workspace:FindFirstChild("Zones")
    if zonesFolder then
        local cleanName = zoneName:gsub("%s+", "")
        local zPart = zonesFolder:FindFirstChild(cleanName) or zonesFolder:FindFirstChild(zoneName)
        if zPart and zPart:IsA("BasePart") then
            return Teleports.TeleportTo(zPart.Position + Vector3.new(0, 3, 0))
        end
    end

    return false, "Zone not found: " .. tostring(zoneName)
end

function Teleports.TeleportToPlot()
    -- 1. Try via PlotController
    local ok, pc = pcall(function()
        return require(ReplicatedStorage.Framework.Features.Plot.PlotController)
    end)
    if ok and pc and pc.plot and pc.plot:FindFirstChild("Spawn") then
        local spawnPart = pc.plot.Spawn
        return Teleports.TeleportTo(spawnPart.Position + Vector3.new(0, 3, 0))
    end

    -- 2. Fallback search in Claimed plots
    local plots = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild("Claimed")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local spawnPart = plot:FindFirstChild("Spawn")
            if spawnPart then
                return Teleports.TeleportTo(spawnPart.Position + Vector3.new(0, 3, 0))
            end
        end
    end

    return false, "Plot spawn not found"
end

_G.AnimeDiceTeleports = Teleports
return Teleports
