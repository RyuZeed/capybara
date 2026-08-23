--[[
	===============================================================
	⚡ RITOD HUB - GROW A CHICKEN FIGHTER (AUTO EGG & INCUBATOR)
	Module: modules/chicken_fighter/auto_egg.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FITUR UTAMA:
	  1. 🧲 Egg Magnet Instant Touch (Tanpa Teleport Karakter / BAC Safe)
	  2. 🥚 Smart Auto Hatch Owned Eggs (Remote HatchEgg)
	  3. 🐣 Auto Claim Incubators (Slots 1-7 Spacing Aman)
	  4. ⚡ Instant 1x Trigger Buttons
	  5. 📊 Live Statistics & Safe Destructor
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
AutoEgg.EggInterval = 0.5
AutoEgg.IncubatorInterval = 2.0
AutoEgg.MaxIncubatorSlots = 7

-- Stats
AutoEgg.Stats = {
    EggsCollected = 0,
    IncubatorsClaimed = 0,
    LastEggTime = 0,
    LastIncubatorTime = 0
}

-- Threads
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

-- =================================================================
-- 🧲 EGG MAGNET & CLAIM (TANPA TELEPORT KARAKTER)
-- =================================================================
function AutoEgg.CollectSingleEgg(eggInstance)
    if not eggInstance or not eggInstance.Parent or not AutoEgg.IsMyEgg(eggInstance) then return false end
    local eggId = eggInstance:GetAttribute("eggId")
    local hrp = getHRP()
    if not hrp then return false end

    -- 1. Tarik part telur ke posisi karakter (Magnet)
    pcall(function()
        if eggInstance:IsA("BasePart") then
            eggInstance.CFrame = hrp.CFrame
        elseif eggInstance:IsA("Model") then
            eggInstance:PivotTo(hrp.CFrame)
        end
    end)

    -- 2. Trigger Remote HatchEgg langsung
    local remotes = getRemotes()
    local hatchRemote = remotes and remotes:FindFirstChild("HatchEgg")
    if eggId and hatchRemote then
        pcall(function()
            hatchRemote:InvokeServer(eggId)
        end)
    end

    -- 3. Touch Interest bantuan
    if typeof(firetouchinterest) == "function" then
        pcall(function()
            local targetPart = eggInstance:IsA("BasePart") and eggInstance or eggInstance:FindFirstChildWhichIsA("BasePart", true)
            if targetPart then
                firetouchinterest(targetPart, hrp, 0)
                task.wait(0.01)
                firetouchinterest(targetPart, hrp, 1)
            end
        end)
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
        if AutoEgg.IsMyEgg(egg) and AutoEgg.CollectSingleEgg(egg) then
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
                            AutoEgg.CollectSingleEgg(egg)
                            task.wait(AutoEgg.EggInterval or 0.5)
                        end
                    end
                end
            end)
            task.wait(0.8)
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

-- =================================================================
-- 🐣 INCUBATOR CLAIM ENGINE
-- =================================================================
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
                    task.wait(0.4) -- Safe spacing antar slot
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
