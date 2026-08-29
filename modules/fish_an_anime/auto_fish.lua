--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (AUTO FISHING & BACKPACK ENGINE)
	Module: modules/fish_an_anime/auto_fish.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎣 FEATURES:
	- Event-Driven Instant Auto Fishing Loop (Zero Delay Reel)
	- Smart Pond & Water Detection / Area Targeting
	- State Recovery & Desync Watchdog
	- Auto Equip Best Character
	- Auto Pick Up All Drops
	- Auto Sell All / Selective Auto Sell by Rarity
	===============================================================
]]

local AutoFish = {}
AutoFish.__index = AutoFish

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- State Flags
AutoFish.IsFishing = false
AutoFish.FastClick = true
AutoFish.SelectedPond = "Auto"

AutoFish.AutoEquipBestEnabled = false
AutoFish.AutoPickUpAllEnabled = false
AutoFish.AutoSellAllEnabled = false
AutoFish.AutoSellRarities = {}

-- Internal Variables
local fishingStateConn = nil
local fishingLoopThread = nil
local equipBestLoopThread = nil
local pickUpLoopThread = nil
local autoSellLoopThread = nil
local lastStateTime = tick()
local isCastPending = false

-- ── 🌊 Pond & Water Resolver ──
function AutoFish.GetPonds()
    local ponds = {}
    pcall(function()
        local pondAreas = Workspace:FindFirstChild("Scripted") and Workspace.Scripted:FindFirstChild("PondAreas")
        if pondAreas then
            for _, p in ipairs(pondAreas:GetChildren()) do
                if p:IsA("BasePart") then
                    table.insert(ponds, p)
                end
            end
        end
    end)

    if #ponds == 0 then
        pcall(function()
            local waterMid = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Water")
            if waterMid then
                for _, p in ipairs(waterMid:GetChildren()) do
                    if p:IsA("BasePart") then
                        table.insert(ponds, p)
                    end
                end
            end
        end)
    end
    return ponds
end

function AutoFish.GetBestPond()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local pos = root and root.Position or Vector3.zero

    local ponds = AutoFish.GetPonds()
    local bestPond = nil
    local bestDist = math.huge

    for _, pond in ipairs(ponds) do
        if pond:IsA("BasePart") then
            local dist = (pond.Position - pos).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestPond = pond
            end
        end
    end

    if not bestPond and Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Water") then
        local w = Workspace.Map.Water:FindFirstChild("WaterMIDCIRC") or Workspace.Map.Water:FindFirstChild("WaterMIDDLE")
        if w and w:IsA("BasePart") then
            bestPond = w
        end
    end

    return bestPond
end

-- ── 🎣 Core Fishing Action ──
function AutoFish.CastRod()
    if not Remotes or not Remotes:FindFirstChild("FishingRequestStart") then return false end
    local pond = AutoFish.GetBestPond()
    if not pond then return false end

    local targetPos = pond.Position + Vector3.new(
        math.random(-5, 5),
        0,
        math.random(-5, 5)
    )

    isCastPending = true
    lastStateTime = tick()
    Remotes.FishingRequestStart:FireServer(pond, targetPos)
    return true
end

function AutoFish.DoClick()
    if Remotes and Remotes:FindFirstChild("FishingClick") then
        Remotes.FishingClick:FireServer()
    end
end

function AutoFish.CancelFishing()
    if Remotes and Remotes:FindFirstChild("FishingCancel") then
        Remotes.FishingCancel:FireServer()
    end
    isCastPending = false
end

-- ── 🎣 Auto Fishing Controller ──
function AutoFish.StartFishing()
    if AutoFish.IsFishing then return end
    AutoFish.IsFishing = true
    lastStateTime = tick()

    -- 1. Event listener
    if Remotes and Remotes:FindFirstChild("FishingState") then
        if fishingStateConn then fishingStateConn:Disconnect() end
        fishingStateConn = Remotes.FishingState.OnClientEvent:Connect(function(data)
            if not AutoFish.IsFishing then return end
            lastStateTime = tick()

            if typeof(data) == "table" then
                local kind = data.kind
                if kind == "Hooked" then
                    isCastPending = false
                    -- Ikan menyambar! Klik otomatis
                    if AutoFish.FastClick then
                        AutoFish.DoClick()
                    else
                        task.wait(0.05)
                        AutoFish.DoClick()
                    end
                elseif kind == "Completed" then
                    isCastPending = false
                    task.wait(0.1)
                    if AutoFish.IsFishing then
                        AutoFish.CastRod()
                    end
                elseif kind == "Started" then
                    isCastPending = false
                end
            end
        end)
    end

    -- 2. Initial Cast & Watchdog Loop
    if fishingLoopThread then task.cancel(fishingLoopThread) end
    fishingLoopThread = task.spawn(function()
        AutoFish.CastRod()
        while AutoFish.IsFishing do
            task.wait(1.5)
            if not AutoFish.IsFishing then break end

            -- Watchdog: jika tidak ada event > 5 detik saat memancing atau cast macet
            if tick() - lastStateTime > 5.0 then
                AutoFish.CancelFishing()
                task.wait(0.3)
                if AutoFish.IsFishing then
                    AutoFish.CastRod()
                end
            end
        end
    end)
end

function AutoFish.StopFishing()
    AutoFish.IsFishing = false
    if fishingStateConn then
        pcall(function() fishingStateConn:Disconnect() end)
        fishingStateConn = nil
    end
    if fishingLoopThread then
        pcall(function() task.cancel(fishingLoopThread) end)
        fishingLoopThread = nil
    end
    AutoFish.CancelFishing()
end

-- ── 🎒 Auto Equip Best ──
function AutoFish.StartAutoEquipBest(interval)
    AutoFish.AutoEquipBestEnabled = true
    interval = interval or 5
    if equipBestLoopThread then task.cancel(equipBestLoopThread) end
    equipBestLoopThread = task.spawn(function()
        while AutoFish.AutoEquipBestEnabled do
            if Remotes and Remotes:FindFirstChild("BackpackEquipBest") then
                pcall(function() Remotes.BackpackEquipBest:FireServer() end)
            end
            task.wait(interval)
        end
    end)
end

function AutoFish.StopAutoEquipBest()
    AutoFish.AutoEquipBestEnabled = false
    if equipBestLoopThread then
        pcall(function() task.cancel(equipBestLoopThread) end)
        equipBestLoopThread = nil
    end
end

function AutoFish.EquipBestOnce()
    if Remotes and Remotes:FindFirstChild("BackpackEquipBest") then
        pcall(function() Remotes.BackpackEquipBest:FireServer() end)
        return true
    end
    return false
end

-- ── 🎒 Auto Pick Up All ──
function AutoFish.StartAutoPickUpAll(interval)
    AutoFish.AutoPickUpAllEnabled = true
    interval = interval or 3
    if pickUpLoopThread then task.cancel(pickUpLoopThread) end
    pickUpLoopThread = task.spawn(function()
        while AutoFish.AutoPickUpAllEnabled do
            if Remotes and Remotes:FindFirstChild("BackpackPickUpAll") then
                pcall(function() Remotes.BackpackPickUpAll:FireServer() end)
            end
            task.wait(interval)
        end
    end)
end

function AutoFish.StopAutoPickUpAll()
    AutoFish.AutoPickUpAllEnabled = false
    if pickUpLoopThread then
        pcall(function() task.cancel(pickUpLoopThread) end)
        pickUpLoopThread = nil
    end
end

function AutoFish.PickUpAllOnce()
    if Remotes and Remotes:FindFirstChild("BackpackPickUpAll") then
        pcall(function() Remotes.BackpackPickUpAll:FireServer() end)
        return true
    end
    return false
end

-- ── 💰 Auto Sell All & By Rarity ──
function AutoFish.StartAutoSellAll(interval)
    AutoFish.AutoSellAllEnabled = true
    interval = interval or 10
    if autoSellLoopThread then task.cancel(autoSellLoopThread) end
    autoSellLoopThread = task.spawn(function()
        while AutoFish.AutoSellAllEnabled do
            if Remotes and Remotes:FindFirstChild("BackpackSellAllRequest") then
                pcall(function() Remotes.BackpackSellAllRequest:InvokeServer() end)
            end
            task.wait(interval)
        end
    end)
end

function AutoFish.StopAutoSellAll()
    AutoFish.AutoSellAllEnabled = false
    if autoSellLoopThread then
        pcall(function() task.cancel(autoSellLoopThread) end)
        autoSellLoopThread = nil
    end
end

function AutoFish.SellAllOnce()
    if Remotes and Remotes:FindFirstChild("BackpackSellAllRequest") then
        local success, res = pcall(function() return Remotes.BackpackSellAllRequest:InvokeServer() end)
        return success and res
    end
    return false
end

function AutoFish.SellRarityOnce(rarity)
    if Remotes and Remotes:FindFirstChild("BackpackSellRarityRequest") then
        local success, res = pcall(function() return Remotes.BackpackSellRarityRequest:InvokeServer(rarity) end)
        return success and res
    end
    return false
end

function AutoFish.StopAll()
    AutoFish.StopFishing()
    AutoFish.StopAutoEquipBest()
    AutoFish.StopAutoPickUpAll()
    AutoFish.StopAutoSellAll()
end

_G.FishAnAnimeAutoFish = AutoFish
return AutoFish
