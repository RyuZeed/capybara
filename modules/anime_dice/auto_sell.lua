--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO SELL ENGINE)
	Module: modules/anime_dice/auto_sell.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AutoSell = {}
AutoSell.__index = AutoSell

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local sellRF = network and network:FindFirstChild("SellService") and network.SellService:FindFirstChild("RF") and network.SellService.RF:FindFirstChild("SellInventory")
local sellRE = network and network:FindFirstChild("SellService") and network.SellService:FindFirstChild("RE") and network.SellService.RE:FindFirstChild("UpdateAutoSell")

local function getRemotes()
    local net = ReplicatedStorage:FindFirstChild("Network")
    if not net then return end
    if not sellRF and net:FindFirstChild("SellService") and net.SellService:FindFirstChild("RF") then
        sellRF = net.SellService.RF:FindFirstChild("SellInventory")
    end
    if not sellRE and net:FindFirstChild("SellService") and net.SellService:FindFirstChild("RE") then
        sellRE = net.SellService.RE:FindFirstChild("UpdateAutoSell")
    end
end

function AutoSell.SellInventoryOnce()
    getRemotes()
    if sellRF then
        local ok, res = pcall(function()
            return sellRF:InvokeServer()
        end)
        return ok, res
    end
    return false, "SellInventory remote not found"
end

function AutoSell.SetAutoSellThreshold(threshold)
    getRemotes()
    if sellRE and threshold then
        return pcall(function()
            sellRE:FireServer(threshold)
        end)
    end
    return false
end

AutoSell.IsRunning = false
local loopThread = nil

function AutoSell.Start()
    if AutoSell.IsRunning then return end
    AutoSell.IsRunning = true

    loopThread = task.spawn(function()
        while AutoSell.IsRunning do
            local cfg = _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig or {}
            if cfg.AutoSellInventory then
                AutoSell.SellInventoryOnce()
            end
            task.wait(5.0)
        end
    end)
end

function AutoSell.Stop()
    AutoSell.IsRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

function AutoSell.StopAll()
    AutoSell.Stop()
end

_G.AnimeDiceAutoSell = AutoSell
return AutoSell
