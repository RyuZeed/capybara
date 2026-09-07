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

function AutoPlot.CollectBalanceOnce(slotIndex)
    getRemotes()
    if collectRE then
        if slotIndex then
            return pcall(function() collectRE:FireServer(slotIndex) end)
        else
            for slot = 1, 8 do
                pcall(function() collectRE:FireServer(slot) end)
            end
            return true
        end
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
            local cfg = _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig or {}
            local now = tick()

            -- Auto Collect Cash (every 1.5s for all slots 1-8)
            if (cfg.AutoCollectCash ~= false) and (now - tickCollect) >= 1.5 then
                tickCollect = now
                AutoPlot.CollectBalanceOnce()
            end

            -- Auto Equip Best (every 3.5s)
            if cfg.AutoEquipBest and (now - tickEquip) >= 3.5 then
                tickEquip = now
                AutoPlot.EquipBestOnce()
            end

            -- Auto Upgrade Slots (every 2.5s)
            if cfg.AutoUpgradeSlots and (now - tickUpgrade) >= 2.5 then
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
