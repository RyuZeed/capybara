--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (AUTO FARM ENGINE V3.0)
	Module: modules/fish_an_anime/auto_farm.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🌟 FEATURES:
	- Auto Claim All Quests (Realtime interval checking)
	- Auto Claim All Index Unlocks & Rewards
	- Smart Auto Upgrades (Iterative tier buying)
	- Auto Rebirth (Automatic prestige progression)
	- Auto Potion Booster (Buff uptime maintainer)
	===============================================================
	NOTE: Merchant functionality (Selene, Angelia, Valora, Rods, Carry)
	has been moved to auto_merchants.lua for clean separation.
	===============================================================
]]

local AutoFarm = {}
AutoFarm.__index = AutoFarm

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- State Flags
AutoFarm.AutoQuestsEnabled = false
AutoFarm.AutoIndexEnabled = false
AutoFarm.AutoUpgradesEnabled = false
AutoFarm.AutoRebirthEnabled = false
AutoFarm.AutoPotionsEnabled = false
AutoFarm.SelectedPotions = {}

-- Threads
local questThread = nil
local indexThread = nil
local upgradesThread = nil
local rebirthThread = nil
local potionsThread = nil

-- Upgrades Tiers list
local UPGRADE_IDS = {
    "T1O1", "T1O2",
    "T2O1", "T2O2", "T2O3",
    "T3O1", "T3O2", "T3O3",
    "T4O1", "T4O2", "T4O3",
    "T5O1", "T5O2"
}

-- ── 📜 1. Auto Claim Quests ──
function AutoFarm.ClaimAllQuestsOnce()
    if not Remotes then return false end
    local claimed = false
    if Remotes:FindFirstChild("QuestClaimAll") then
        local success, res = pcall(function()
            return Remotes.QuestClaimAll:InvokeServer()
        end)
        if success and res then claimed = true end
    end
    return claimed
end

function AutoFarm.StartAutoQuests(interval)
    AutoFarm.AutoQuestsEnabled = true
    interval = interval or 5
    if questThread then task.cancel(questThread) end
    questThread = task.spawn(function()
        while AutoFarm.AutoQuestsEnabled do
            AutoFarm.ClaimAllQuestsOnce()
            task.wait(interval)
        end
    end)
end

function AutoFarm.StopAutoQuests()
    AutoFarm.AutoQuestsEnabled = false
    if questThread then
        pcall(function() task.cancel(questThread) end)
        questThread = nil
    end
end

-- ── 📖 2. Auto Claim Index & Free Rewards ──
function AutoFarm.ClaimAllIndexOnce()
    if not Remotes then return false end
    local claimed = false
    if Remotes:FindFirstChild("IndexClaimAllRewards") then
        local success, res = pcall(function()
            return Remotes.IndexClaimAllRewards:InvokeServer()
        end)
        if success and res then claimed = true end
    end
    return claimed
end

function AutoFarm.ClaimAllFreeRewardsOnce()
    if not Remotes then return end
    if Remotes:FindFirstChild("IndexClaimAllRewards") then
        pcall(function() Remotes.IndexClaimAllRewards:InvokeServer() end)
    end
    if Remotes:FindFirstChild("QuestClaimAll") then
        pcall(function() Remotes.QuestClaimAll:InvokeServer() end)
    end
    if Remotes:FindFirstChild("MedalQuestClaim") then
        pcall(function() Remotes.MedalQuestClaim:InvokeServer() end)
    end
    if Remotes:FindFirstChild("AlphaClaimRequest") then
        pcall(function() Remotes.AlphaClaimRequest:InvokeServer() end)
    end
    if Remotes:FindFirstChild("LeaveOfferClaim") then
        pcall(function() Remotes.LeaveOfferClaim:InvokeServer() end)
    end
end

function AutoFarm.StartAutoIndex(interval)
    AutoFarm.AutoIndexEnabled = true
    interval = interval or 10
    if indexThread then task.cancel(indexThread) end
    indexThread = task.spawn(function()
        while AutoFarm.AutoIndexEnabled do
            AutoFarm.ClaimAllFreeRewardsOnce()
            task.wait(interval)
        end
    end)
end

function AutoFarm.StopAutoIndex()
    AutoFarm.AutoIndexEnabled = false
    if indexThread then
        pcall(function() task.cancel(indexThread) end)
        indexThread = nil
    end
end

-- ── ⚡ 3. Specific Auto Upgrades ──
AutoFarm.AutoUpgradesSelected = {
    T1O1 = true,
    T1O2 = true,
    T2O1 = true,
    T2O2 = true,
    T2O3 = true,
    T3O1 = true,
    T3O2 = true,
    T3O3 = true,
    T4O1 = true,
    T4O2 = true,
    T4O3 = true,
    T5O1 = true,
    T5O2 = true
}

function AutoFarm.BuySelectedUpgradesOnce()
    if not Remotes or not Remotes:FindFirstChild("UpgradesStorePurchase") then return end
    for _, id in ipairs(UPGRADE_IDS) do
        if AutoFarm.AutoUpgradesSelected[id] == true then
            pcall(function()
                Remotes.UpgradesStorePurchase:InvokeServer(id)
            end)
            task.wait(0.04)
        end
    end
end

function AutoFarm.StartAutoUpgrades(interval)
    AutoFarm.AutoUpgradesEnabled = true
    interval = interval or 3
    if upgradesThread then task.cancel(upgradesThread) end
    upgradesThread = task.spawn(function()
        while AutoFarm.AutoUpgradesEnabled do
            AutoFarm.BuySelectedUpgradesOnce()
            task.wait(interval)
        end
    end)
end

function AutoFarm.StopAutoUpgrades()
    AutoFarm.AutoUpgradesEnabled = false
    if upgradesThread then
        pcall(function() task.cancel(upgradesThread) end)
        upgradesThread = nil
    end
end

-- ── 🔄 4. Auto Rebirth ──
function AutoFarm.RebirthOnce()
    if not Remotes or not Remotes:FindFirstChild("RebirthPurchase") then return false end
    local success, res = pcall(function()
        return Remotes.RebirthPurchase:InvokeServer()
    end)
    return success and res
end

function AutoFarm.StartAutoRebirth(interval)
    AutoFarm.AutoRebirthEnabled = true
    interval = interval or 3
    if rebirthThread then task.cancel(rebirthThread) end
    rebirthThread = task.spawn(function()
        while AutoFarm.AutoRebirthEnabled do
            AutoFarm.RebirthOnce()
            task.wait(interval)
        end
    end)
end

function AutoFarm.StopAutoRebirth()
    AutoFarm.AutoRebirthEnabled = false
    if rebirthThread then
        pcall(function() task.cancel(rebirthThread) end)
        rebirthThread = nil
    end
end

-- ── 🧪 5. Auto Potions (Uptime Booster) ──
local function findPotionTools()
    local tools = {}
    local lp = Players.LocalPlayer
    if not lp then return tools end

    local containers = {
        lp:FindFirstChildOfClass("Backpack"),
        lp.Character,
        lp:FindFirstChild("StoredTools")
    }

    for _, container in ipairs(containers) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") and child:GetAttribute("IsPotion") == true then
                    table.insert(tools, child)
                end
            end
        end
    end
    return tools
end

function AutoFarm.UseSelectedPotionsOnce(forceUse)
    if not Remotes or not Remotes:FindFirstChild("PotionUse") then return end

    local state = {}
    if Remotes:FindFirstChild("PotionGetState") then
        local success, res = pcall(function()
            return Remotes.PotionGetState:InvokeServer()
        end)
        if success and typeof(res) == "table" then
            state = res
        end
    end

    local serverTime = state.serverTime or os.time()
    local activePotions = state.potions or {}

    -- Map active potion keys & types with their endTimes
    local activeKeys = {}
    for _, active in pairs(activePotions) do
        if typeof(active) == "table" then
            local key = active.key or active.type
            local endTime = tonumber(active.endTime) or 0
            if key and endTime > (serverTime + 3) then
                activeKeys[key] = endTime
                if active.type then activeKeys[active.type] = endTime end
            end
        end
    end

    local potionTools = findPotionTools()
    local usedNames = {}

    -- Check if user selected at least one specific potion
    local hasAnySelection = false
    for _, val in pairs(AutoFarm.SelectedPotions) do
        if val == true then
            hasAnySelection = true
            break
        end
    end

    for _, tool in ipairs(potionTools) do
        local toolName = tool.Name
        local potionKey = tool:GetAttribute("PotionKey")

        -- If user has specific selection, respect it. If none selected, default to maintaining all owned potions!
        local isSelected = (not hasAnySelection) or (AutoFarm.SelectedPotions[toolName] == true) or (potionKey and AutoFarm.SelectedPotions[potionKey] == true)

        if isSelected and not usedNames[toolName] then
            local isActive = (activeKeys[toolName] ~= nil) or (potionKey and activeKeys[potionKey] ~= nil)

            if forceUse or not isActive then
                pcall(function()
                    Remotes.PotionUse:InvokeServer(tool)
                end)
                usedNames[toolName] = true
                task.wait(0.2)
            end
        end
    end
end

function AutoFarm.StartAutoPotions(interval)
    AutoFarm.AutoPotionsEnabled = true
    interval = interval or 5
    if potionsThread then task.cancel(potionsThread) end
    potionsThread = task.spawn(function()
        -- Trigger immediately on start
        AutoFarm.UseSelectedPotionsOnce(false)
        while AutoFarm.AutoPotionsEnabled do
            task.wait(interval)
            AutoFarm.UseSelectedPotionsOnce(false)
        end
    end)
end

function AutoFarm.StopAutoPotions()
    AutoFarm.AutoPotionsEnabled = false
    if potionsThread then
        pcall(function() task.cancel(potionsThread) end)
        potionsThread = nil
    end
end

if Remotes and Remotes:FindFirstChild("PotionState") then
    Remotes.PotionState.OnClientEvent:Connect(function()
        if AutoFarm.AutoPotionsEnabled then
            task.delay(0.5, function()
                AutoFarm.UseSelectedPotionsOnce(false)
            end)
        end
    end)
end

-- ── 🛑 Stop All Farm ──
function AutoFarm.StopAll()
    AutoFarm.StopAutoQuests()
    AutoFarm.StopAutoIndex()
    AutoFarm.StopAutoUpgrades()
    AutoFarm.StopAutoRebirth()
    AutoFarm.StopAutoPotions()
end

_G.FishAnAnimeAutoFarm = AutoFarm
return AutoFarm
