--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO UPGRADES ENGINE)
	Module: modules/anime_dice/auto_upgrades.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🌳 Tree-Based Progression:
	  - Traverses TreeStructure starting from "Start".
	  - Identifies available unowned upgrades whose prerequisites are met.
	  - Sorts candidates by price ascending (cheapest available first).
	  - Purchases via ReplicatedStorage.Network.RE.BuyUpgrade.
	===============================================================
]]

local AutoUpgrades = {}
AutoUpgrades.__index = AutoUpgrades

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local netRE = network and network:FindFirstChild("RE")
local buyUpgradeRE = netRE and netRE:FindFirstChild("BuyUpgrade")

AutoUpgrades.IsRunning = false
AutoUpgrades.CheckInterval = 3.0 -- Cek setiap 3 detik

local loopThread = nil

local function getRemote()
    if not buyUpgradeRE then
        local net = ReplicatedStorage:FindFirstChild("Network")
        if net and net:FindFirstChild("RE") then
            buyUpgradeRE = net.RE:FindFirstChild("BuyUpgrade") or buyUpgradeRE
        end
    end
end

-- =================================================================
-- 🌳 HELPER: GET AVAILABLE UPGRADES
-- =================================================================
function AutoUpgrades.GetAvailableUpgrades()
    local available = {}
    pcall(function()
        local TreeStructure = require(ReplicatedStorage.Framework.Features.Upgrades.TreeStructure)
        local Upgrades = require(ReplicatedStorage.Framework.Features.Upgrades.Upgrades)
        local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)

        local myMoney = DataController.Money and DataController.Money() or 0

        local function checkNode(nodeName)
            local children = TreeStructure.GetChildren(nodeName)
            if not children then return end

            for _, child in ipairs(children) do
                local isOwned = DataController.Upgrades[child] and DataController.Upgrades[child]() == true
                if isOwned then
                    -- Lanjutkan telusuri cabang anak jika sudah dimiliki
                    checkNode(child)
                else
                    -- Node ini belum dimiliki, cek apakah bisa dibeli
                    local info = Upgrades[child]
                    local price = info and info.price or 0
                    table.insert(available, {
                        name = child,
                        price = price,
                        canAfford = (myMoney >= price),
                        image = info and info.image,
                        buffs = info and info.buffs
                    })
                end
            end
        end

        checkNode("Start")
    end)

    -- Urutkan berdasarkan harga termurah ke termahal
    table.sort(available, function(a, b)
        return a.price < b.price
    end)

    return available
end

-- =================================================================
-- 🛒 BUY SINGLE UPGRADE
-- =================================================================
function AutoUpgrades.BuyUpgrade(upgradeName)
    getRemote()
    if buyUpgradeRE then
        local success = pcall(function()
            buyUpgradeRE:FireServer(upgradeName)
        end)
        return success
    end
    return false
end

-- =================================================================
-- ⚡ BUY ALL AFFORDABLE UPGRADES ONCE
-- =================================================================
function AutoUpgrades.BuyAvailableOnce()
    local available = AutoUpgrades.GetAvailableUpgrades()
    local boughtCount = 0

    for _, u in ipairs(available) do
        if u.canAfford then
            local ok = AutoUpgrades.BuyUpgrade(u.name)
            if ok then
                boughtCount = boughtCount + 1
                print(string.format("[⬆️ Auto Upgrades] Membeli upgrade: %s ($%s)", u.name, tostring(u.price)))
                task.wait(0.25) -- Jeda aman antar transaksi
            end
        end
    end

    return boughtCount
end

-- =================================================================
-- 🔄 MAIN AUTO UPGRADE ROUTINE
-- =================================================================
function AutoUpgrades.RunCheck()
    local ConfigManager = _G.AnimeDiceConfigManager
    local cfg = ConfigManager and ConfigManager.CurrentConfig
    if not cfg or not cfg.AutoUpgrades then return end

    AutoUpgrades.BuyAvailableOnce()
end

-- =================================================================
-- 🔄 LIFECYCLE MANAGEMENT
-- =================================================================
function AutoUpgrades.Start()
    if AutoUpgrades.IsRunning then return end
    AutoUpgrades.IsRunning = true

    if loopThread then task.cancel(loopThread) end
    loopThread = task.spawn(function()
        while AutoUpgrades.IsRunning do
            pcall(function()
                AutoUpgrades.RunCheck()
            end)
            task.wait(AutoUpgrades.CheckInterval)
        end
    end)
end

function AutoUpgrades.Stop()
    AutoUpgrades.IsRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

function AutoUpgrades.StopAll()
    AutoUpgrades.Stop()
end

_G.AnimeDiceAutoUpgrades = AutoUpgrades
return AutoUpgrades
