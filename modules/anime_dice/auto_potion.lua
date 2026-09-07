--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO POTION / BOOST ENGINE)
	Module: modules/anime_dice/auto_potion.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🧪 Categorized Auto Use Potions:
	  - Stat Category: Luck, Income, Damage
	  - Theme Category: Normal, Pirate, Cursed, Dragon
	  - Tier Category: Tier I, Tier II, Tier III
	- 🛡️ Anti-Waste Protection:
	  - Checks DataController.ActiveEntries() to see remaining buff time.
	  - Only consumes a potion if the buff is expired or <= 5s left.
	===============================================================
]]

local AutoPotion = {}
AutoPotion.__index = AutoPotion

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local boostRE = network and network:FindFirstChild("BoostService") and network.BoostService:FindFirstChild("RE")
local useRE = boostRE and boostRE:FindFirstChild("Use")

AutoPotion.IsRunning = false
AutoPotion.CheckInterval = 1.5
AutoPotion.ReUseThreshold = 5 -- Untuk mode Keepalive
AutoPotion.Mode = "Spam All" -- "Spam All" (default: habiskan sampai 0) atau "Keepalive"

local loopThread = nil

local function getRemote()
    if not useRE then
        local net = ReplicatedStorage:FindFirstChild("Network")
        if net and net:FindFirstChild("BoostService") and net.BoostService:FindFirstChild("RE") then
            useRE = net.BoostService.RE:FindFirstChild("Use") or useRE
        end
    end
end

-- =================================================================
-- 🔍 HELPER: PARSE POTION ATTRIBUTES
-- =================================================================
function AutoPotion.ParsePotionInfo(name)
    local theme = "Normal"
    local stat = "Unknown"
    local tier = 1

    local cleanName = name

    if name:find("^Pirate ") then
        theme = "Pirate"
        cleanName = name:gsub("^Pirate ", "")
    elseif name:find("^Cursed ") then
        theme = "Cursed"
        cleanName = name:gsub("^Cursed ", "")
    elseif name:find("^Dragon ") then
        theme = "Dragon"
        cleanName = name:gsub("^Dragon ", "")
    end

    if cleanName:find(" III$") then
        tier = 3
    elseif cleanName:find(" II$") then
        tier = 2
    elseif cleanName:find(" I$") then
        tier = 1
    end

    if cleanName:find("Luck") then
        stat = "Luck"
    elseif cleanName:find("Income") then
        stat = "Income"
    elseif cleanName:find("Damage") then
        stat = "Damage"
    end

    return {
        fullName = name,
        theme = theme,
        stat = stat,
        tier = tier
    }
end

-- =================================================================
-- 🎒 HELPER: GET OWNED POTIONS
-- =================================================================
function AutoPotion.GetOwnedPotions()
    local owned = {}
    pcall(function()
        local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
        local EntryRegistry = require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry)
        local inv = DataController.Inventory and DataController.Inventory()
        if inv then
            for k, item in pairs(inv) do
                local cfg = EntryRegistry.getEntryConfig(item.name)
                if cfg and cfg.kind == "Boost" and typeof(item.amount) == "number" and item.amount > 0 then
                    local parsed = AutoPotion.ParsePotionInfo(item.name)
                    parsed.amount = item.amount
                    parsed.duration = cfg.duration or 180
                    table.insert(owned, parsed)
                end
            end
        end
    end)
    return owned
end

-- =================================================================
-- ⏳ HELPER: GET ACTIVE BUFF REMAINING TIME
-- =================================================================
function AutoPotion.GetActiveBuffs()
    local activeBuffs = {}
    pcall(function()
        local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
        local active = DataController.ActiveEntries and DataController.ActiveEntries()
        local serverNow = workspace:GetServerTimeNow()
        if active then
            for name, entry in pairs(active) do
                if typeof(entry.remaining) == "number" then
                    local left = 0
                    if typeof(entry.startedAt) == "number" and entry.startedAt > 0 then
                        left = math.max(0, math.ceil(entry.remaining - (serverNow - entry.startedAt)))
                    else
                        left = math.max(0, math.ceil(entry.remaining))
                    end
                    activeBuffs[name] = left
                end
            end
        end
    end)
    return activeBuffs
end

-- =================================================================
-- 🧪 USE POTION (SINGLE)
-- =================================================================
function AutoPotion.UsePotion(name)
    getRemote()
    if useRE then
        local success = pcall(function()
            useRE:FireServer(name)
        end)
        if success then
            pcall(function()
                local sound = ReplicatedStorage:FindFirstChild("Assets")
                    and ReplicatedStorage.Assets:FindFirstChild("Sounds")
                    and ReplicatedStorage.Assets.Sounds:FindFirstChild("UseItem")
                if sound then
                    local s = sound:Clone()
                    s.Parent = workspace
                    s:Play()
                    game:GetService("Debris"):AddItem(s, 1.5)
                end
            end)
            return true
        end
    end
    return false
end

-- =================================================================
-- 🔍 FILTER CHECKER
-- =================================================================
local function shouldAutoUse(potionInfo, cfg)
    if not cfg then return false end

    -- 1. Stat Check
    if potionInfo.stat == "Luck" and not cfg.AutoPotionLuck then return false end
    if potionInfo.stat == "Income" and not cfg.AutoPotionIncome then return false end
    if potionInfo.stat == "Damage" and not cfg.AutoPotionDamage then return false end

    -- 2. Theme Check
    if potionInfo.theme == "Normal" and not cfg.AutoPotionNormal then return false end
    if potionInfo.theme == "Pirate" and not cfg.AutoPotionPirate then return false end
    if potionInfo.theme == "Cursed" and not cfg.AutoPotionCursed then return false end
    if potionInfo.theme == "Dragon" and not cfg.AutoPotionDragon then return false end

    -- 3. Tier Check
    if potionInfo.tier == 1 and not cfg.AutoPotionTier1 then return false end
    if potionInfo.tier == 2 and not cfg.AutoPotionTier2 then return false end
    if potionInfo.tier == 3 and not cfg.AutoPotionTier3 then return false end

    return true
end

-- =================================================================
-- ⚡ MAIN AUTO POTION ROUTINE
-- =================================================================
-- =================================================================
-- ⚡ MAIN AUTO POTION ROUTINE
-- =================================================================
function AutoPotion.RunCheck()
    local ConfigManager = _G.AnimeDiceConfigManager
    local cfg = ConfigManager and ConfigManager.CurrentConfig
    if not cfg or not cfg.AutoPotion then return false end

    local mode = cfg.AutoPotionMode or AutoPotion.Mode or "Spam All"
    local owned = AutoPotion.GetOwnedPotions()
    if #owned == 0 then return false end

    local usedAny = false

    if mode == "Spam All" then
        -- 🌪️ MODE HABISKAN SEMUA: Terus minum potion yang cocok sampai habis (amount 0)
        for _, pot in ipairs(owned) do
            if not AutoPotion.IsRunning then break end
            if shouldAutoUse(pot, cfg) and pot.amount > 0 then
                local ok = AutoPotion.UsePotion(pot.fullName)
                if ok then
                    usedAny = true
                    print(string.format("[⚡ Auto Potion] Mengonsumsi %s (Tersisa di inventory: %d)", pot.fullName, pot.amount - 1))
                    task.wait(0.2) -- Jeda aman antar konsumsi
                end
            end
        end
    else
        -- 🛡️ MODE KEEPALIVE: Hanya minum saat durasi buff mau habis (<= 5s)
        local activeBuffs = AutoPotion.GetActiveBuffs()
        for _, pot in ipairs(owned) do
            if not AutoPotion.IsRunning then break end
            if shouldAutoUse(pot, cfg) and pot.amount > 0 then
                local remainingTime = activeBuffs[pot.fullName] or 0
                if remainingTime <= AutoPotion.ReUseThreshold then
                    local ok = AutoPotion.UsePotion(pot.fullName)
                    if ok then
                        usedAny = true
                        print(string.format("[⚡ Auto Potion] Memperbarui buff %s (Tersisa: %d)", pot.fullName, pot.amount - 1))
                        task.wait(0.25)
                        activeBuffs[pot.fullName] = pot.duration or 180
                    end
                end
            end
        end
    end

    return usedAny
end

-- =================================================================
-- 🚀 USE ALL IN CATEGORY (MANUAL INSTANT BUTTONS)
-- =================================================================
function AutoPotion.UseAllCategoryOnce(statType)
    local owned = AutoPotion.GetOwnedPotions()
    local usedCount = 0
    for _, pot in ipairs(owned) do
        if not statType or pot.stat == statType then
            if AutoPotion.UsePotion(pot.fullName) then
                usedCount = usedCount + 1
                task.wait(0.2)
            end
        end
    end
    return usedCount
end

-- =================================================================
-- 🔄 LIFECYCLE MANAGEMENT
-- =================================================================
function AutoPotion.Start()
    if AutoPotion.IsRunning then return end
    AutoPotion.IsRunning = true

    if loopThread then task.cancel(loopThread) end
    loopThread = task.spawn(function()
        while AutoPotion.IsRunning do
            local ConfigManager = _G.AnimeDiceConfigManager
            local cfg = ConfigManager and ConfigManager.CurrentConfig
            local isSpam = not cfg or (cfg.AutoPotionMode ~= "Keepalive")

            local success, usedAny = pcall(AutoPotion.RunCheck)
            if not success and usedAny then
                warn("[Auto Potion Error]", usedAny)
            end

            -- Jika sedang menghabiskan potion, beri jeda singkat untuk lanjut minum batch berikutnya
            -- Jika sudah habis semua di inventory, jeda 1.5 detik
            if isSpam and usedAny then
                task.wait(0.2)
            else
                task.wait(AutoPotion.CheckInterval or 1.5)
            end
        end
    end)
    print("🧪 [Auto Potion] Dimulai.")
end

function AutoPotion.Stop()
    AutoPotion.IsRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

function AutoPotion.StopAll()
    AutoPotion.Stop()
end

_G.AnimeDiceAutoPotion = AutoPotion
return AutoPotion
