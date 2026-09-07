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
local LocalPlayer = Players.LocalPlayer or (function()
    local t = tick()
    while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end
    return Players.LocalPlayer
end)()

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

function Teleports.TeleportToPlot()
    -- 1. Try via PlotController in game framework
    local ok, pc = pcall(function()
        return require(ReplicatedStorage.Framework.Features.Plot.PlotController)
    end)
    if ok and pc and pc.plot and pc.plot:FindFirstChild("Spawn") then
        local spawnPart = pc.plot.Spawn
        return Teleports.TeleportTo(spawnPart.Position + Vector3.new(0, 3, 0))
    end

    -- 2. Search in Claimed plots for local player's plot
    local plots = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild("Claimed")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local ownerVal = plot:FindFirstChild("Owner") or plot:FindFirstChild("Player")
            if ownerVal and (ownerVal.Value == LocalPlayer or ownerVal.Value == LocalPlayer.Name or ownerVal.Value == LocalPlayer.UserId) then
                local spawnPart = plot:FindFirstChild("Spawn")
                if spawnPart then
                    return Teleports.TeleportTo(spawnPart.Position + Vector3.new(0, 3, 0))
                end
            end
        end

        -- Fallback: first available spawn in claimed
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
