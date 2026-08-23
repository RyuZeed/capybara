--[[
	===============================================================
	⚡ RITOD HUB - GROW A CHICKEN FIGHTER (AUTO EGG & INCUBATOR)
	Module: modules/chicken_fighter/auto_egg.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AutoEgg = {}
AutoEgg.__index = AutoEgg

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer or (function()
    local t = tick()
    while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end
    return Players.LocalPlayer
end)()

-- State
AutoEgg.IsCollectingEggs = false
AutoEgg.IsClaimingIncubator = false
AutoEgg.EggInterval = 0.8
AutoEgg.IncubatorInterval = 2.0
AutoEgg.MaxIncubatorSlots = 7

-- Stats
AutoEgg.Stats = {
    EggsCollected = 0,
    IncubatorsClaimed = 0,
    LastEggTime = 0,
    LastIncubatorTime = 0
}

-- Threads & Connections
local eggThread = nil
local incubatorThread = nil

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 2))
end

local function getRemotes()
    return ReplicatedStorage:FindFirstChild("Remotes")
end

function AutoEgg.IsMyEgg(eggInstance)
    if not eggInstance or not eggInstance.Parent then return false end
    local owner = eggInstance:GetAttribute("owner")
    return owner and tostring(owner) == tostring(LocalPlayer.UserId)
end

function AutoEgg.CollectSingleEggSafe(eggInstance)
    if not eggInstance or not eggInstance.Parent or not AutoEgg.IsMyEgg(eggInstance) then return false end
    local eggId = eggInstance:GetAttribute("eggId")
    local hrp = getHRP()
    if not hrp then return false end

    local eggPos = eggInstance:IsA("BasePart") and eggInstance.Position or eggInstance:GetPivot().Position
    local dist = (hrp.Position - eggPos).Magnitude
    local oldPos = hrp.CFrame

    -- Pindahkan karakter dekat telur sejenak agar lolos verifikasi jarak BAC
    if dist > 12 then
        hrp.CFrame = CFrame.new(eggPos + Vector3.new(0, 2.5, 0))
        task.wait(0.08)
    end

    local remotes = getRemotes()
    local hatchRemote = remotes and remotes:FindFirstChild("HatchEgg")
    if eggId and hatchRemote then
        pcall(function()
            hatchRemote:InvokeServer(eggId)
        end)
    end

    if typeof(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(eggInstance, hrp, 0)
            task.wait(0.02)
            firetouchinterest(eggInstance, hrp, 1)
        end)
    end

    if dist > 12 then
        task.wait(0.05)
        hrp.CFrame = oldPos
    end

    AutoEgg.Stats.EggsCollected = AutoEgg.Stats.EggsCollected + 1
    AutoEgg.Stats.LastEggTime = tick()
    return true
end

function AutoEgg.CollectAllEggsOnce()
    local nestFolder = workspace:FindFirstChild("NestEggs")
    if not nestFolder then return 0 end
    
    local count = 0
    for _, egg in ipairs(nestFolder:GetChildren()) do
        if AutoEgg.IsMyEgg(egg) and AutoEgg.CollectSingleEggSafe(egg) then
            count = count + 1
            task.wait(0.2)
        end
    end
    return count
end

function AutoEgg.StartAutoCollectEgg(interval)
    if AutoEgg.IsCollectingEggs then return end
    AutoEgg.IsCollectingEggs = true
    if interval and tonumber(interval) then
        AutoEgg.EggInterval = tonumber(interval)
    end

    eggThread = task.spawn(function()
        while AutoEgg.IsCollectingEggs do
            pcall(function()
                local nest = workspace:FindFirstChild("NestEggs")
                if nest then
                    for _, egg in ipairs(nest:GetChildren()) do
                        if not AutoEgg.IsCollectingEggs then break end
                        if AutoEgg.IsMyEgg(egg) then
                            AutoEgg.CollectSingleEggSafe(egg)
                            task.wait(AutoEgg.EggInterval or 0.8)
                        end
                    end
                end
            end)
            task.wait(1.0)
        end
    end)
end

function AutoEgg.StopAutoCollectEgg()
    AutoEgg.IsCollectingEggs = false
    if eggThread then
        pcall(function() task.cancel(eggThread) end)
        eggThread = nil
    end
end

function AutoEgg.ClaimSingleIncubator(slotIndex)
    local remotes = getRemotes()
    local claimRemote = remotes and remotes:FindFirstChild("IncubatorClaim")
    if not claimRemote then return false end
    
    local success, result = pcall(function()
        return claimRemote:InvokeServer(slotIndex)
    end)
    if success and result then
        AutoEgg.Stats.IncubatorsClaimed = AutoEgg.Stats.IncubatorsClaimed + 1
        AutoEgg.Stats.LastIncubatorTime = tick()
        return true, result
    end
    return false, nil
end

function AutoEgg.ClaimAllIncubatorsOnce(maxSlots)
    maxSlots = maxSlots or AutoEgg.MaxIncubatorSlots or 7
    local claimed = 0
    for i = 1, maxSlots do
        if AutoEgg.ClaimSingleIncubator(i) then claimed = claimed + 1 end
        task.wait(0.3)
    end
    return claimed
end

function AutoEgg.StartAutoClaimIncubator(interval, maxSlots)
    if AutoEgg.IsClaimingIncubator then return end
    AutoEgg.IsClaimingIncubator = true
    if interval and tonumber(interval) then
        AutoEgg.IncubatorInterval = tonumber(interval)
    end
    if maxSlots and tonumber(maxSlots) then
        AutoEgg.MaxIncubatorSlots = tonumber(maxSlots)
    end

    incubatorThread = task.spawn(function()
        while AutoEgg.IsClaimingIncubator do
            pcall(function()
                local limit = AutoEgg.MaxIncubatorSlots or 7
                for i = 1, limit do
                    if not AutoEgg.IsClaimingIncubator then break end
                    AutoEgg.ClaimSingleIncubator(i)
                    task.wait(0.4)
                end
            end)
            task.wait(AutoEgg.IncubatorInterval or 2.0)
        end
    end)
end

function AutoEgg.StopAutoClaimIncubator()
    AutoEgg.IsClaimingIncubator = false
    if incubatorThread then
        pcall(function() task.cancel(incubatorThread) end)
        incubatorThread = nil
    end
end

function AutoEgg.StopAll()
    AutoEgg.StopAutoCollectEgg()
    AutoEgg.StopAutoClaimIncubator()
end

_G.ChickenFighterAutoEgg = AutoEgg
return AutoEgg
