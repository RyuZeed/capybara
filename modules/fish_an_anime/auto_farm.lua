--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (AUTO FARM & MERCHANTS ENGINE)
	Module: modules/fish_an_anime/auto_farm.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🌟 FEATURES:
	- Auto Claim All Quests (Realtime interval checking)
	- Auto Claim All Index Unlocks & Rewards
	- Smart Auto Upgrades (Iterative tier buying)
	- Auto Rebirth (Automatic prestige progression)
	- Auto Potion Booster (Buff uptime maintainer)
	- Auto Buy Boosts Store (Valora - Restock Sniping)
	- Auto Buy Secret Merchant (Selene)
	- Auto Buy Secret Merchant (Angelia / SecretStore2)
	- Auto Buy Fishing Rods & Carry Capacity
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

AutoFarm.AutoBuyBoostsEnabled = false
AutoFarm.AutoBuyBoostsCurrency = "Cash"
AutoFarm.AutoBuyBoostsSelected = {}

AutoFarm.AutoBuySeleneEnabled = false
AutoFarm.AutoBuySeleneSelected = {}

AutoFarm.AutoBuyAngeliaEnabled = false
AutoFarm.AutoBuyAngeliaSelected = {}

AutoFarm.AutoBuyFishingRodsEnabled = false
AutoFarm.AutoBuyCarryEnabled = false

AutoFarm.SelectedPotions = {}

-- Threads
local questThread = nil
local indexThread = nil
local upgradesThread = nil
local rebirthThread = nil
local potionsThread = nil
local boostsThread = nil
local seleneThread = nil
local angeliaThread = nil
local rodsThread = nil
local carryThread = nil

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

    for _, tool in ipairs(potionTools) do
        local toolName = tool.Name
        local potionKey = tool:GetAttribute("PotionKey")

        local isSelected = (AutoFarm.SelectedPotions[toolName] == true) or (potionKey and AutoFarm.SelectedPotions[potionKey] == true)

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
        while AutoFarm.AutoPotionsEnabled do
            AutoFarm.UseSelectedPotionsOnce(false)
            task.wait(interval)
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

-- ── 🛒 6. Auto Buy Boosts Store (Valora) ──
local boostsUpdatedConn = nil

function AutoFarm.BuySelectedBoostsOnce(customState)
    if not Remotes or not Remotes:FindFirstChild("BoostsStorePurchase") then return end
    
    local state = customState
    if not state and Remotes:FindFirstChild("BoostsStoreGetState") then
        local success, res = pcall(function() return Remotes.BoostsStoreGetState:InvokeServer() end)
        if success and typeof(res) == "table" then state = res end
    end
    if not state or typeof(state) ~= "table" or not state.stock then return end

    local currency = AutoFarm.AutoBuyBoostsCurrency or "Cash"

    for offerId, count in pairs(state.stock) do
        local stockAmount = tonumber(count) or 0
        if stockAmount > 0 and AutoFarm.AutoBuyBoostsSelected[offerId] == true then
            for _ = 1, stockAmount do
                pcall(function()
                    Remotes.BoostsStorePurchase:InvokeServer(offerId, currency)
                end)
                task.wait(0.06)
            end
        end
    end
end

function AutoFarm.StartAutoBuyBoosts()
    if AutoFarm.AutoBuyBoostsEnabled then return end
    AutoFarm.AutoBuyBoostsEnabled = true

    -- 1. Beli seluruh stok yang tersedia saat ini
    task.spawn(function()
        AutoFarm.BuySelectedBoostsOnce()
    end)

    -- 2. Event-Driven: Beli instan detik itu juga saat server melakukan Restock
    if Remotes and Remotes:FindFirstChild("BoostsStoreUpdated") then
        if boostsUpdatedConn then boostsUpdatedConn:Disconnect() end
        boostsUpdatedConn = Remotes.BoostsStoreUpdated.OnClientEvent:Connect(function(updatedState)
            if not AutoFarm.AutoBuyBoostsEnabled then return end
            AutoFarm.BuySelectedBoostsOnce(updatedState)
        end)
    end

    -- 3. Smart Timer Daemon: Tidur hingga tepat waktu restock berikutnya (Zero Spam)
    if boostsThread then task.cancel(boostsThread) end
    boostsThread = task.spawn(function()
        while AutoFarm.AutoBuyBoostsEnabled do
            local state = nil
            if Remotes:FindFirstChild("BoostsStoreGetState") then
                pcall(function() state = Remotes.BoostsStoreGetState:InvokeServer() end)
            end

            local waitTime = 15
            if state and state.restockEndTime and state.serverTime then
                local remaining = state.restockEndTime - state.serverTime
                if remaining > 0 then
                    waitTime = remaining + 0.2
                else
                    waitTime = 5
                end
            end

            task.wait(math.max(1, waitTime))
            if not AutoFarm.AutoBuyBoostsEnabled then break end
            AutoFarm.BuySelectedBoostsOnce()
        end
    end)
end

function AutoFarm.StopAutoBuyBoosts()
    AutoFarm.AutoBuyBoostsEnabled = false
    if boostsUpdatedConn then
        pcall(function() boostsUpdatedConn:Disconnect() end)
        boostsUpdatedConn = nil
    end
    if boostsThread then
        pcall(function() task.cancel(boostsThread) end)
        boostsThread = nil
    end
end

-- ── 🌙 7. Auto Buy Secret Merchant (Selene) ──
local seleneUpdatedConn = nil

function AutoFarm.BuySelectedSeleneOnce(customState)
    if not Remotes or not Remotes:FindFirstChild("SecretStorePurchase") then return end
    local state = customState
    if not state and Remotes:FindFirstChild("SecretStoreGetState") then
        local success, res = pcall(function() return Remotes.SecretStoreGetState:InvokeServer() end)
        if success and typeof(res) == "table" then state = res end
    end
    if not state or typeof(state) ~= "table" or not state.offers then return end

    for offerId, isSelected in pairs(AutoFarm.AutoBuySeleneSelected) do
        if isSelected and state.offers[offerId] ~= nil then
            local offerData = state.offers[offerId]
            if typeof(offerData) == "table" and offerData.visible ~= false then
                local currency = (offerData.cashCost ~= nil) and "Cash" or "Gems"
                local stock = tonumber(offerData.stock) or 1
                if stock > 0 then
                    for _ = 1, stock do
                        pcall(function()
                            Remotes.SecretStorePurchase:InvokeServer(offerId, currency)
                        end)
                        task.wait(0.06)
                    end
                end
            end
        end
    end
end

function AutoFarm.StartAutoBuySelene(interval)
    if AutoFarm.AutoBuySeleneEnabled then return end
    AutoFarm.AutoBuySeleneEnabled = true
    interval = interval or 5

    task.spawn(function()
        AutoFarm.BuySelectedSeleneOnce()
    end)

    if Remotes and Remotes:FindFirstChild("SecretStoreUpdated") then
        if seleneUpdatedConn then seleneUpdatedConn:Disconnect() end
        seleneUpdatedConn = Remotes.SecretStoreUpdated.OnClientEvent:Connect(function(updatedState)
            if not AutoFarm.AutoBuySeleneEnabled then return end
            AutoFarm.BuySelectedSeleneOnce(updatedState)
        end)
    end

    if seleneThread then task.cancel(seleneThread) end
    seleneThread = task.spawn(function()
        while AutoFarm.AutoBuySeleneEnabled do
            AutoFarm.BuySelectedSeleneOnce()
            task.wait(interval)
        end
    end)
end

function AutoFarm.StopAutoBuySelene()
    AutoFarm.AutoBuySeleneEnabled = false
    if seleneUpdatedConn then
        pcall(function() seleneUpdatedConn:Disconnect() end)
        seleneUpdatedConn = nil
    end
    if seleneThread then
        pcall(function() task.cancel(seleneThread) end)
        seleneThread = nil
    end
end

-- ── 👼 8. Auto Buy Secret Merchant (Angelia / SecretStore2) ──
local angeliaUpdatedConn = nil

function AutoFarm.BuySelectedAngeliaOnce(customState)
    if not Remotes or not Remotes:FindFirstChild("SecretStore2Purchase") then return end
    local state = customState
    if not state and Remotes:FindFirstChild("SecretStore2GetState") then
        local success, res = pcall(function() return Remotes.SecretStore2GetState:InvokeServer() end)
        if success and typeof(res) == "table" then state = res end
    end
    if not state or typeof(state) ~= "table" or not state.offers then return end

    for offerId, isSelected in pairs(AutoFarm.AutoBuyAngeliaSelected) do
        if isSelected and state.offers[offerId] ~= nil then
            local offerData = state.offers[offerId]
            if typeof(offerData) == "table" and offerData.visible ~= false then
                local currency = (offerData.cashCost ~= nil) and "Cash" or "Gems"
                local stock = tonumber(offerData.stock) or 1
                if stock > 0 then
                    for _ = 1, stock do
                        pcall(function()
                            Remotes.SecretStore2Purchase:InvokeServer(offerId, currency)
                        end)
                        task.wait(0.06)
                    end
                end
            end
        end
    end
end

function AutoFarm.StartAutoBuyAngelia(interval)
    AutoFarm.AutoBuyAngeliaEnabled = true
    interval = interval or 10

    task.spawn(function()
        AutoFarm.BuySelectedAngeliaOnce()
    end)

    if Remotes and Remotes:FindFirstChild("SecretStore2Updated") then
        if angeliaUpdatedConn then angeliaUpdatedConn:Disconnect() end
        angeliaUpdatedConn = Remotes.SecretStore2Updated.OnClientEvent:Connect(function(updatedState)
            if not AutoFarm.AutoBuyAngeliaEnabled then return end
            AutoFarm.BuySelectedAngeliaOnce(updatedState)
        end)
    end

    if angeliaThread then task.cancel(angeliaThread) end
    angeliaThread = task.spawn(function()
        while AutoFarm.AutoBuyAngeliaEnabled do
            AutoFarm.BuySelectedAngeliaOnce()
            task.wait(interval)
        end
    end)
end

function AutoFarm.StopAutoBuyAngelia()
    AutoFarm.AutoBuyAngeliaEnabled = false
    if angeliaUpdatedConn then
        pcall(function() angeliaUpdatedConn:Disconnect() end)
        angeliaUpdatedConn = nil
    end
    if angeliaThread then
        pcall(function() task.cancel(angeliaThread) end)
        angeliaThread = nil
    end
end

-- ── 🎣 9. Auto Buy Fishing Rods ──
function AutoFarm.BuyAvailableFishingRodsOnce()
    if not Remotes or not Remotes:FindFirstChild("FishingStoreGetState") or not Remotes:FindFirstChild("FishingStorePurchase") then return end
    local success, state = pcall(function() return Remotes.FishingStoreGetState:InvokeServer() end)
    if not success or typeof(state) ~= "table" then return end

    local owned = state.owned or {}
    local playerRebirths = state.rebirths or 0

    for offerId, data in pairs(state.offers or {}) do
        if typeof(data) == "table" then
            local rodName = data.RodName
            local reqRebirth = data.RebirthRequired or 0
            if rodName and not owned[rodName] and playerRebirths >= reqRebirth then
                pcall(function()
                    Remotes.FishingStorePurchase:InvokeServer(offerId, "Cash")
                end)
                task.wait(0.1)
            end
        end
    end
end

function AutoFarm.StartAutoBuyFishingRods(interval)
    AutoFarm.AutoBuyFishingRodsEnabled = true
    interval = interval or 10
    if rodsThread then task.cancel(rodsThread) end
    rodsThread = task.spawn(function()
        while AutoFarm.AutoBuyFishingRodsEnabled do
            AutoFarm.BuyAvailableFishingRodsOnce()
            task.wait(interval)
        end
    end)
end

function AutoFarm.StopAutoBuyFishingRods()
    AutoFarm.AutoBuyFishingRodsEnabled = false
    if rodsThread then
        pcall(function() task.cancel(rodsThread) end)
        rodsThread = nil
    end
end

-- ── 🎒 10. Auto Buy Carry Capacity ──
function AutoFarm.BuyCarryUpgradeOnce()
    if not Remotes or not Remotes:FindFirstChild("PurchaseCarry") then return end
    pcall(function()
        Remotes.PurchaseCarry:InvokeServer()
    end)
end

function AutoFarm.StartAutoBuyCarry(interval)
    AutoFarm.AutoBuyCarryEnabled = true
    interval = interval or 10
    if carryThread then task.cancel(carryThread) end
    carryThread = task.spawn(function()
        while AutoFarm.AutoBuyCarryEnabled do
            AutoFarm.BuyCarryUpgradeOnce()
            task.wait(interval)
        end
    end)
end

function AutoFarm.StopAutoBuyCarry()
    AutoFarm.AutoBuyCarryEnabled = false
    if carryThread then
        pcall(function() task.cancel(carryThread) end)
        carryThread = nil
    end
end

-- ── 🛑 Stop All Farm & Merchants ──
function AutoFarm.StopAll()
    AutoFarm.StopAutoQuests()
    AutoFarm.StopAutoIndex()
    AutoFarm.StopAutoUpgrades()
    AutoFarm.StopAutoRebirth()
    AutoFarm.StopAutoPotions()
    AutoFarm.StopAutoBuyBoosts()
    AutoFarm.StopAutoBuySelene()
    AutoFarm.StopAutoBuyAngelia()
    AutoFarm.StopAutoBuyFishingRods()
    AutoFarm.StopAutoBuyCarry()
end

_G.FishAnAnimeAutoFarm = AutoFarm
return AutoFarm
