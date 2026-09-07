--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO BUY & EQUIP DICE ENGINE)
	Module: modules/anime_dice/auto_dice.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🎲 Sequential Progression:
	  - Evaluates all dice in strict progression order (Luck/Price ascending).
	  - Detects next unowned dice and automatically purchases it when affordable.
	  - Optional Auto Equip Best Dice to automatically equip the highest luck dice owned.
	===============================================================
]]

local AutoDice = {}
AutoDice.__index = AutoDice

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local diceShopRE = network and network:FindFirstChild("DiceShopService") and network.DiceShopService:FindFirstChild("RE")
local buyDiceRE = diceShopRE and diceShopRE:FindFirstChild("BuyDice")
local equipDiceRE = diceShopRE and diceShopRE:FindFirstChild("EquipDice")

AutoDice.IsRunning = false
AutoDice.CheckInterval = 3.0
AutoDice.AutoEquipBest = true

local loopThread = nil

local function getRemotes()
    if not buyDiceRE or not equipDiceRE then
        local net = ReplicatedStorage:FindFirstChild("Network")
        if net and net:FindFirstChild("DiceShopService") and net.DiceShopService:FindFirstChild("RE") then
            buyDiceRE = net.DiceShopService.RE:FindFirstChild("BuyDice") or buyDiceRE
            equipDiceRE = net.DiceShopService.RE:FindFirstChild("EquipDice") or equipDiceRE
        end
    end
end

-- =================================================================
-- 📋 HELPER: GET ALL DICE IN PROGRESSION ORDER
-- =================================================================
function AutoDice.GetAllDiceInOrder()
    local list = {}
    pcall(function()
        local Dice = require(ReplicatedStorage.Framework.Features.Rolling.Dice)
        for name, data in pairs(Dice.GetAll()) do
            if data.price then
                table.insert(list, {
                    name = name,
                    data = data,
                    luck = data.luck or 1,
                    price = data.price or 0,
                    rarity = data.rarity or "Common"
                })
            end
        end
    end)

    table.sort(list, function(a, b)
        if a.luck == b.luck then
            return a.price < b.price
        end
        return a.luck < b.luck
    end)

    return list
end

-- =================================================================
-- 🔍 HELPER: GET NEXT UNOWNED DICE
-- =================================================================
function AutoDice.GetNextUnownedDice()
    local nextDice = nil
    pcall(function()
        local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
        local allDice = AutoDice.GetAllDiceInOrder()
        local myMoney = DataController.Money and DataController.Money() or 0

        for _, d in ipairs(allDice) do
            local isOwned = DataController.OwnedDice[d.name] and DataController.OwnedDice[d.name]() == true
            if not isOwned then
                nextDice = {
                    name = d.name,
                    luck = d.luck,
                    price = d.price,
                    rarity = d.rarity,
                    canAfford = (myMoney >= d.price)
                }
                break
            end
        end
    end)
    return nextDice
end

-- =================================================================
-- 👑 HELPER: GET BEST OWNED DICE
-- =================================================================
function AutoDice.GetBestOwnedDice()
    local best = nil
    pcall(function()
        local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
        local allDice = AutoDice.GetAllDiceInOrder()

        -- Telusuri dari yang terkuat (luck tertinggi)
        for i = #allDice, 1, -1 do
            local d = allDice[i]
            local isOwned = DataController.OwnedDice[d.name] and DataController.OwnedDice[d.name]() == true
            if isOwned then
                best = d.name
                break
            end
        end
    end)
    return best or "Basic"
end

-- =================================================================
-- 🛒 BUY NEXT DICE
-- =================================================================
function AutoDice.BuyNextDiceOnce()
    getRemotes()
    local nextDice = AutoDice.GetNextUnownedDice()
    if not nextDice then return false, "Semua dadu sudah dimiliki!" end

    if not nextDice.canAfford then
        return false, string.format("Uang belum cukup untuk %s ($%s)", nextDice.name, tostring(nextDice.price))
    end

    if buyDiceRE then
        local success = pcall(function()
            buyDiceRE:FireServer(nextDice.name)
        end)
        if success then
            print(string.format("[🎲 Auto Buy Dice] Berhasil membeli dadu: %s ($%s)", nextDice.name, tostring(nextDice.price)))
            task.wait(0.3)
            -- Auto equip if configured
            local ConfigManager = _G.AnimeDiceConfigManager
            local cfg = ConfigManager and ConfigManager.CurrentConfig
            if not cfg or cfg.AutoEquipBestDice ~= false then
                AutoDice.EquipBestDiceOnce()
            end
            return true, nextDice.name
        end
    end

    return false, "Gagal memanggil remote BuyDice"
end

-- =================================================================
-- ✨ EQUIP BEST OWNED DICE
-- =================================================================
function AutoDice.EquipBestDiceOnce()
    getRemotes()
    local best = AutoDice.GetBestOwnedDice()
    if not best then return false end

    local currentEquipped = nil
    pcall(function()
        local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
        currentEquipped = DataController.Dice and DataController.Dice()
    end)

    if currentEquipped ~= best and equipDiceRE then
        local success = pcall(function()
            equipDiceRE:FireServer(best)
        end)
        if success then
            print(string.format("[🎲 Auto Dice] Otomatis memasang dadu terbaik: %s", best))
            return true, best
        end
    end

    return false, "Dadu terbaik sudah terpasang"
end

-- =================================================================
-- 🔄 MAIN AUTO DICE ROUTINE
-- =================================================================
function AutoDice.RunCheck()
    local ConfigManager = _G.AnimeDiceConfigManager
    local cfg = ConfigManager and ConfigManager.CurrentConfig
    if not cfg then return end

    if cfg.AutoBuyDice then
        AutoDice.BuyNextDiceOnce()
    end

    if cfg.AutoEquipBestDice ~= false then
        AutoDice.EquipBestDiceOnce()
    end
end

-- =================================================================
-- 🔄 LIFECYCLE MANAGEMENT
-- =================================================================
function AutoDice.Start()
    if AutoDice.IsRunning then return end
    AutoDice.IsRunning = true

    if loopThread then task.cancel(loopThread) end
    loopThread = task.spawn(function()
        while AutoDice.IsRunning do
            pcall(function()
                AutoDice.RunCheck()
            end)
            task.wait(AutoDice.CheckInterval)
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
