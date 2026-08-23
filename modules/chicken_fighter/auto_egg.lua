--[[
	===============================================================
	⚡ RITOD HUB - GROW A CHICKEN FIGHTER (SMART AUTO EGG & INCUBATOR)
	Module: modules/chicken_fighter/auto_egg.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FITUR UTAMA (100% SMART & SILENT):
	  1. 🧲 Smart Egg Magnet (Event-Driven ChildAdded, Zero-Movement)
	  2. 🐣 Smart Incubator Claim (Hanya Klaim Saat Server Timestamp Ready)
	  3. 🤫 Silent Operation (Zero Spam Output / Zero Lag)
	  4. ⚡ Instant 1x Trigger Buttons
	  5. 📊 Live Statistics & Safe Cleanup
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

-- Stats
AutoEgg.Stats = {
    EggsCollected = 0,
    IncubatorsClaimed = 0,
    LastEggTime = 0,
    LastIncubatorTime = 0
}

-- Threads & Connections
local incubatorThread = nil
local nestEggConn = nil

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 2))
end

local function getRemotes()
    return ReplicatedStorage:FindFirstChild("Remotes")
end

local function getServerTime()
    local ok, serverTime = pcall(function()
        return workspace:GetServerTimeNow()
    end)
    if ok and serverTime then
        return serverTime
    end
    return os.time()
end

function AutoEgg.IsMyEgg(eggInstance)
    if not eggInstance or not eggInstance.Parent then return false end
    local owner = eggInstance:GetAttribute("owner")
    return owner and tostring(owner) == tostring(LocalPlayer.UserId)
end

-- =================================================================
-- 🧲 SMART EGG MAGNET & CLAIM (EVENT-DRIVEN)
-- =================================================================
function AutoEgg.CollectSingleEgg(eggInstance)
    if not eggInstance or not eggInstance.Parent or not AutoEgg.IsMyEgg(eggInstance) then return false end
    local eggId = eggInstance:GetAttribute("eggId")
    local hrp = getHRP()
    if not hrp then return false end

    -- 1. Tarik part telur ke posisi karakter di client (Magnet)
    pcall(function()
        if eggInstance:IsA("BasePart") then
            eggInstance.CFrame = hrp.CFrame
        elseif eggInstance:IsA("Model") then
            eggInstance:PivotTo(hrp.CFrame)
        end
    end)

    -- 2. Trigger Remote HatchEgg langsung dari jarak 0
    local remotes = getRemotes()
    local hatchRemote = remotes and remotes:FindFirstChild("HatchEgg")
    if eggId and hatchRemote then
        pcall(function()
            hatchRemote:InvokeServer(eggId)
        end)
    end

    -- 3. Touch Interest backup
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
            task.wait(0.15)
        end
    end
    return count
end

function AutoEgg.StartAutoCollectEgg()
    if AutoEgg.IsCollectingEggs then return end
    AutoEgg.IsCollectingEggs = true

    -- 1. Sapu telur yang sudah ada saat awal aktif
    task.spawn(function()
        AutoEgg.CollectAllEggsOnce()
    end)

    -- 2. Event-Driven: Hanya bereaksi saat ada telur baru spawn
    local nestFolder = workspace:FindFirstChild("NestEggs")
    if nestFolder then
        if nestEggConn then nestEggConn:Disconnect() end
        nestEggConn = nestFolder.ChildAdded:Connect(function(child)
            if AutoEgg.IsCollectingEggs then
                task.spawn(function()
                    local waited = 0
                    while waited < 1 do
                        if child:GetAttribute("owner") and child:GetAttribute("eggId") then break end
                        task.wait(0.05)
                        waited = waited + 0.05
                    end
                    if AutoEgg.IsCollectingEggs and AutoEgg.IsMyEgg(child) then
                        AutoEgg.CollectSingleEgg(child)
                    end
                end)
            end
        end)
    end
end

function AutoEgg.StopAutoCollectEgg()
    AutoEgg.IsCollectingEggs = false
    if nestEggConn then
        pcall(function() nestEggConn:Disconnect() end)
        nestEggConn = nil
    end
end

-- =================================================================
-- 🐣 SMART INCUBATOR CLAIM (HANYA KLAIM SAAT READY)
-- =================================================================
function AutoEgg.GetReadyIncubators()
    local readySlots = {}
    local incubators = workspace:FindFirstChild("Incubators")
    if not incubators then return readySlots end

    local now = getServerTime()

    for _, inc in ipairs(incubators:GetChildren()) do
        local slotNum = tonumber(string.match(inc.Name, "%d+"))
        if slotNum then
            local isUnlocked = inc:GetAttribute("Unlocked")
            local nextHatchAt = inc:GetAttribute("NextHatchAt")
            
            -- Jika unlocked dan waktu sekarang sudah melewati NextHatchAt (> 0)
            if isUnlocked and nextHatchAt and tonumber(nextHatchAt) and tonumber(nextHatchAt) > 0 then
                if now >= tonumber(nextHatchAt) then
                    table.insert(readySlots, slotNum)
                end
            end
        end
    end

    return readySlots
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

function AutoEgg.ClaimAllIncubatorsOnce()
    local readySlots = AutoEgg.GetReadyIncubators()
    local claimed = 0
    for _, slotIndex in ipairs(readySlots) do
        if AutoEgg.ClaimSingleIncubator(slotIndex) then
            claimed = claimed + 1
            task.wait(0.3)
        end
    end
    return claimed
end

function AutoEgg.StartAutoClaimIncubator()
    if AutoEgg.IsClaimingIncubator then return end
    AutoEgg.IsClaimingIncubator = true

    incubatorThread = task.spawn(function()
        while AutoEgg.IsClaimingIncubator do
            pcall(function()
                -- Cek slot incubator mana saja yang statusnya SUDAH READY
                local readySlots = AutoEgg.GetReadyIncubators()
                for _, slotIndex in ipairs(readySlots) do
                    if not AutoEgg.IsClaimingIncubator then break end
                    AutoEgg.ClaimSingleIncubator(slotIndex)
                    task.wait(0.35)
                end
            end)
            task.wait(1.0) -- Poller santai setiap 1 detik mengecek timer
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

-- =================================================================
-- 🛑 DESTRUCTOR / CLEANUP
-- =================================================================
function AutoEgg.StopAll()
    AutoEgg.StopAutoCollectEgg()
    AutoEgg.StopAutoClaimIncubator()
end

_G.ChickenFighterAutoEgg = AutoEgg
return AutoEgg
