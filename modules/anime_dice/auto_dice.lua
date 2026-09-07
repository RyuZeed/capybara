--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO DICE & SHOP ENGINE)
	Module: modules/anime_dice/auto_dice.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AutoDice = {}
AutoDice.__index = AutoDice

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local diceRE = network and network:FindFirstChild("DiceShopService") and network.DiceShopService:FindFirstChild("RE")
local buyDiceRE = diceRE and diceRE:FindFirstChild("BuyDice")
local equipDiceRE = diceRE and diceRE:FindFirstChild("EquipDice")

AutoDice.DiceList = {
    "Basic", "Normal", "Fire", "Water", "Nature", "Lightning", "Ice", "Magma",
    "Storm", "Shadow", "Light", "Blood Moon", "Void", "Solar", "Lunar", "Galaxy",
    "Black Hole", "Dragon", "Royal", "Prismatic", "Arcane", "Corrupted", "Titan", "Chrono"
}

-- Try to read dice dynamically from game's Dice module if available
pcall(function()
    local diceModule = ReplicatedStorage:FindFirstChild("Framework")
        and ReplicatedStorage.Framework:FindFirstChild("Features")
        and ReplicatedStorage.Framework.Features:FindFirstChild("Rolling")
        and ReplicatedStorage.Framework.Features.Rolling:FindFirstChild("Dice")
    if diceModule then
        local mod = require(diceModule)
        if mod and typeof(mod.GetAll) == "function" then
            local all = mod:GetAll()
            local list = {}
            for k, _ in pairs(all) do
                table.insert(list, tostring(k))
            end
            if #list > 0 then
                table.sort(list)
                AutoDice.DiceList = list
            end
        end
    end
end)

local function getRemotes()
    if not buyDiceRE or not equipDiceRE then
        local net = ReplicatedStorage:FindFirstChild("Network")
        if net and net:FindFirstChild("DiceShopService") and net.DiceShopService:FindFirstChild("RE") then
            buyDiceRE = net.DiceShopService.RE:FindFirstChild("BuyDice") or buyDiceRE
            equipDiceRE = net.DiceShopService.RE:FindFirstChild("EquipDice") or equipDiceRE
        end
    end
end

function AutoDice.BuyDice(diceName)
    getRemotes()
    if buyDiceRE and diceName then
        return pcall(function() buyDiceRE:FireServer(diceName) end)
    end
    return false
end

function AutoDice.EquipDice(diceName)
    getRemotes()
    if equipDiceRE and diceName then
        return pcall(function() equipDiceRE:FireServer(diceName) end)
    end
    return false
end

AutoDice.IsRunning = false
local loopThread = nil

function AutoDice.Start()
    if AutoDice.IsRunning then return end
    AutoDice.IsRunning = true

    loopThread = task.spawn(function()
        while AutoDice.IsRunning do
            local cfg = _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig or {}
            local target = cfg.SelectedDice

            if target and #target > 0 then
                if cfg.AutoBuySelectedDice then
                    AutoDice.BuyDice(target)
                end
                if cfg.AutoEquipSelectedDice then
                    AutoDice.EquipDice(target)
                end
            end

            task.wait(3.0)
        end
    end)
end

function AutoDice.Stop()
    AutoDice.IsRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

function AutoDice.StopAll()
    AutoDice.Stop()
end

_G.AnimeDiceAutoDice = AutoDice
return AutoDice
