--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO PLOT & FARM ENGINE)
	Module: modules/anime_dice/auto_plot.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AutoPlot = {}
AutoPlot.__index = AutoPlot

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local plotRE = network and network:FindFirstChild("PlotService") and network.PlotService:FindFirstChild("RE")
local collectRE = plotRE and plotRE:FindFirstChild("CollectBalance")
local equipBestRE = plotRE and plotRE:FindFirstChild("EquipBest")
local levelUpSlotRE = plotRE and plotRE:FindFirstChild("LevelUpSlot")

AutoPlot.IsRunning = false
AutoPlot.CollectCash = true
AutoPlot.CollectInterval = 30
AutoPlot.EquipBest = true
AutoPlot.UpgradeSlots = false

local loopThread = nil

local function getRemotes()
    if not collectRE or not equipBestRE or not levelUpSlotRE then
        local net = ReplicatedStorage:FindFirstChild("Network")
        if net and net:FindFirstChild("PlotService") and net.PlotService:FindFirstChild("RE") then
            collectRE = net.PlotService.RE:FindFirstChild("CollectBalance") or collectRE
            equipBestRE = net.PlotService.RE:FindFirstChild("EquipBest") or equipBestRE
            levelUpSlotRE = net.PlotService.RE:FindFirstChild("LevelUpSlot") or levelUpSlotRE
        end
    end
end

local function playCollectSound()
    pcall(function()
        local sound = ReplicatedStorage:FindFirstChild("Assets")
            and ReplicatedStorage.Assets:FindFirstChild("Sounds")
            and ReplicatedStorage.Assets.Sounds:FindFirstChild("Collect")
        if sound then
            local s = sound:Clone()
            s.Parent = workspace
            s:Play()
            game:GetService("Debris"):AddItem(s, 1.2)
        end
    end)
end

function AutoPlot.CollectBalanceOnce(slotIndex)
    getRemotes()
    if collectRE then
        local collectedAny = false
        pcall(function()
            local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
            if DataController and DataController.Slots then
                if slotIndex then
                    local sData = DataController.Slots[tostring(slotIndex)] and DataController.Slots[tostring(slotIndex)]()
                    if sData and sData.balance and sData.balance > 0 then
                        collectedAny = true
                    end
                else
                    for slot = 1, 8 do
                        local sData = DataController.Slots[tostring(slot)] and DataController.Slots[tostring(slot)]()
                        if sData and sData.balance and sData.balance > 0 then
                            collectedAny = true
                            break
                        end
                    end
                end
            end
        end)

        if slotIndex then
            pcall(function() collectRE:FireServer(slotIndex) end)
        else
            for slot = 1, 8 do
                pcall(function() collectRE:FireServer(slot) end)
            end
        end

        if collectedAny then
            playCollectSound()
        end
        return true
    end
    return false
end

function AutoPlot.EquipBestOnce()
    getRemotes()
    if equipBestRE then
        return pcall(function() equipBestRE:FireServer() end)
    end
    return false
end

function AutoPlot.UpgradeSlot(slotIndex)
    getRemotes()
    if levelUpSlotRE then
        return pcall(function() levelUpSlotRE:FireServer(slotIndex) end)
    end
    return false
end

function AutoPlot.UpgradeAllSlotsOnce()
    local successCount = 0
    for i = 1, 8 do
        local ok = AutoPlot.UpgradeSlot(i)
        if ok then successCount = successCount + 1 end
        task.wait(0.05)
    end
    return successCount
end

function AutoPlot.Start()
    if AutoPlot.IsRunning then return end
    AutoPlot.IsRunning = true

    loopThread = task.spawn(function()
        local tickCollect = 0
        local tickEquip = 0
        local tickUpgrade = 0

        while AutoPlot.IsRunning do
            local now = tick()
            local cfg = _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig

            -- Prioritas: AutoPlot.CollectCash property atau Config
            local shouldCollect = AutoPlot.CollectCash
            if cfg and cfg.AutoCollectCash ~= nil then
                shouldCollect = cfg.AutoCollectCash
            end

            -- Auto Collect Cash (cooldown default 30 detik)
            local interval = AutoPlot.CollectInterval or 30
            if cfg and cfg.CollectCashInterval then
                interval = tonumber(cfg.CollectCashInterval) or interval
            end
            if shouldCollect and (now - tickCollect) >= interval then
                tickCollect = now
                AutoPlot.CollectBalanceOnce()
            end

            -- Auto Equip Best (setiap 3.5 detik)
            local shouldEquip = AutoPlot.EquipBest
            if cfg and cfg.AutoEquipBest ~= nil then
                shouldEquip = cfg.AutoEquipBest
            end
            if shouldEquip and (now - tickEquip) >= 3.5 then
                tickEquip = now
                AutoPlot.EquipBestOnce()
            end

            -- Auto Upgrade Slots (setiap 2.5 detik)
            local shouldUpgrade = AutoPlot.UpgradeSlots
            if cfg and cfg.AutoUpgradeSlots ~= nil then
                shouldUpgrade = cfg.AutoUpgradeSlots
            end
            if shouldUpgrade and (now - tickUpgrade) >= 2.5 then
                tickUpgrade = now
                for i = 1, 8 do
                    if not AutoPlot.IsRunning then break end
                    AutoPlot.UpgradeSlot(i)
                    task.wait(0.05)
                end
            end

            task.wait(0.5)
        end
    end)
end

function AutoPlot.Stop()
    AutoPlot.IsRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

function AutoPlot.StopAll()
    AutoPlot.Stop()
end

_G.AnimeDiceAutoPlot = AutoPlot
return AutoPlot
