--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (MERCHANTS & STORES ENGINE V2.0)
	Module: modules/fish_an_anime/auto_merchants.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🌟 FEATURES:
	- 🌙 Secret Merchant: Selene (Dark / Void Shop)
	- 👼 Secret Merchant: Angelia (Heavenly Gate Store)
	- 🏪 Boosts Store: NPC Valora (Event-Driven Smart Sniping)
	- 🎣 Fishing Rods & Carry Capacity Upgrades
	- 🛡️ 100% Dedicated & Isolated Threading (Zero Interference)
	===============================================================
]]

local AutoMerchants = {}
AutoMerchants.__index = AutoMerchants

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- State Flags
AutoMerchants.AutoBuySeleneEnabled = false
AutoMerchants.AutoBuyAngeliaEnabled = false
AutoMerchants.AutoBuyBoostsEnabled = false
AutoMerchants.AutoBuyFishingRodsEnabled = false
AutoMerchants.AutoBuyCarryEnabled = false

-- Selections & Settings
AutoMerchants.AutoBuySeleneSelected = {}
AutoMerchants.AutoBuyAngeliaSelected = {}
AutoMerchants.AutoBuyBoostsSelected = {}
AutoMerchants.AutoBuyBoostsCurrency = "Cash" -- "Cash" or "Gems"

-- Threads & Connections
local seleneThread = nil
local seleneUpdatedConn = nil

local angeliaThread = nil
local angeliaUpdatedConn = nil

local boostsThread = nil
local boostsUpdatedConn = nil

local rodsThread = nil
local carryThread = nil

-- =================================================================
-- 🌙 1. SECRET MERCHANT: SELENE
-- =================================================================
function AutoMerchants.BuySelectedSeleneOnce(customState)
    if not Remotes or not Remotes:FindFirstChild("SecretStorePurchase") then return end
    local state = customState
    if not state and Remotes:FindFirstChild("SecretStoreGetState") then
        local success, res = pcall(function() return Remotes.SecretStoreGetState:InvokeServer() end)
        if success and typeof(res) == "table" then state = res end
    end
    if not state or typeof(state) ~= "table" or not state.offers then return end

    for offerId, isSelected in pairs(AutoMerchants.AutoBuySeleneSelected) do
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

function AutoMerchants.StartAutoBuySelene(interval)
    if AutoMerchants.AutoBuySeleneEnabled then return end
    AutoMerchants.AutoBuySeleneEnabled = true
    interval = interval or 5

    task.spawn(function()
        AutoMerchants.BuySelectedSeleneOnce()
    end)

    if Remotes and Remotes:FindFirstChild("SecretStoreUpdated") then
        if seleneUpdatedConn then seleneUpdatedConn:Disconnect() end
        seleneUpdatedConn = Remotes.SecretStoreUpdated.OnClientEvent:Connect(function(updatedState)
            if not AutoMerchants.AutoBuySeleneEnabled then return end
            AutoMerchants.BuySelectedSeleneOnce(updatedState)
        end)
    end

    if seleneThread then task.cancel(seleneThread) end
    seleneThread = task.spawn(function()
        while AutoMerchants.AutoBuySeleneEnabled do
            AutoMerchants.BuySelectedSeleneOnce()
            task.wait(interval)
        end
    end)
end

function AutoMerchants.StopAutoBuySelene()
    AutoMerchants.AutoBuySeleneEnabled = false
    if seleneUpdatedConn then
        pcall(function() seleneUpdatedConn:Disconnect() end)
        seleneUpdatedConn = nil
    end
    if seleneThread then
        pcall(function() task.cancel(seleneThread) end)
        seleneThread = nil
    end
end

-- =================================================================
-- 👼 2. SECRET MERCHANT: ANGELIA (HEAVENS GATE)
-- =================================================================
function AutoMerchants.BuySelectedAngeliaOnce(customState)
    if not Remotes or not Remotes:FindFirstChild("SecretStore2Purchase") then return end
    local state = customState
    if not state and Remotes:FindFirstChild("SecretStore2GetState") then
        local success, res = pcall(function() return Remotes.SecretStore2GetState:InvokeServer() end)
        if success and typeof(res) == "table" then state = res end
    end
    if not state or typeof(state) ~= "table" or not state.offers then return end

    for offerId, isSelected in pairs(AutoMerchants.AutoBuyAngeliaSelected) do
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

function AutoMerchants.StartAutoBuyAngelia(interval)
    if AutoMerchants.AutoBuyAngeliaEnabled then return end
    AutoMerchants.AutoBuyAngeliaEnabled = true
    interval = interval or 5

    task.spawn(function()
        AutoMerchants.BuySelectedAngeliaOnce()
    end)

    if Remotes and Remotes:FindFirstChild("SecretStore2Updated") then
        if angeliaUpdatedConn then angeliaUpdatedConn:Disconnect() end
        angeliaUpdatedConn = Remotes.SecretStore2Updated.OnClientEvent:Connect(function(updatedState)
            if not AutoMerchants.AutoBuyAngeliaEnabled then return end
            AutoMerchants.BuySelectedAngeliaOnce(updatedState)
        end)
    end

    if angeliaThread then task.cancel(angeliaThread) end
    angeliaThread = task.spawn(function()
        while AutoMerchants.AutoBuyAngeliaEnabled do
            AutoMerchants.BuySelectedAngeliaOnce()
            task.wait(interval)
        end
    end)
end

function AutoMerchants.StopAutoBuyAngelia()
    AutoMerchants.AutoBuyAngeliaEnabled = false
    if angeliaUpdatedConn then
        pcall(function() angeliaUpdatedConn:Disconnect() end)
        angeliaUpdatedConn = nil
    end
    if angeliaThread then
        pcall(function() task.cancel(angeliaThread) end)
        angeliaThread = nil
    end
end

-- =================================================================
-- 🏪 3. BOOSTS STORE (NPC VALORA)
-- =================================================================
function AutoMerchants.BuySelectedBoostsOnce(customState)
    if not Remotes or not Remotes:FindFirstChild("BoostsStorePurchase") then return end
    
    local state = customState
    if not state and Remotes:FindFirstChild("BoostsStoreGetState") then
        local success, res = pcall(function() return Remotes.BoostsStoreGetState:InvokeServer() end)
        if success and typeof(res) == "table" then state = res end
    end
    if not state or typeof(state) ~= "table" or not state.stock then return end

    local currency = AutoMerchants.AutoBuyBoostsCurrency or "Cash"

    for offerId, count in pairs(state.stock) do
        local stockAmount = tonumber(count) or 0
        if stockAmount > 0 and AutoMerchants.AutoBuyBoostsSelected[offerId] == true then
            for _ = 1, stockAmount do
                pcall(function()
                    Remotes.BoostsStorePurchase:InvokeServer(offerId, currency)
                end)
                task.wait(0.06)
            end
        end
    end
end

function AutoMerchants.StartAutoBuyBoosts()
    if AutoMerchants.AutoBuyBoostsEnabled then return end
    AutoMerchants.AutoBuyBoostsEnabled = true

    task.spawn(function()
        AutoMerchants.BuySelectedBoostsOnce()
    end)

    if Remotes and Remotes:FindFirstChild("BoostsStoreUpdated") then
        if boostsUpdatedConn then boostsUpdatedConn:Disconnect() end
        boostsUpdatedConn = Remotes.BoostsStoreUpdated.OnClientEvent:Connect(function(updatedState)
            if not AutoMerchants.AutoBuyBoostsEnabled then return end
            AutoMerchants.BuySelectedBoostsOnce(updatedState)
        end)
    end

    if boostsThread then task.cancel(boostsThread) end
    boostsThread = task.spawn(function()
        while AutoMerchants.AutoBuyBoostsEnabled do
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
            if not AutoMerchants.AutoBuyBoostsEnabled then break end
            AutoMerchants.BuySelectedBoostsOnce()
        end
    end)
end

function AutoMerchants.StopAutoBuyBoosts()
    AutoMerchants.AutoBuyBoostsEnabled = false
    if boostsUpdatedConn then
        pcall(function() boostsUpdatedConn:Disconnect() end)
        boostsUpdatedConn = nil
    end
    if boostsThread then
        pcall(function() task.cancel(boostsThread) end)
        boostsThread = nil
    end
end

-- =================================================================
-- 🎣 4. FISHING RODS & CARRY CAPACITY
-- =================================================================
function AutoMerchants.BuyAvailableFishingRodsOnce()
    if not Remotes or not Remotes:FindFirstChild("PolesPurchase") then return end
    local rods = {
        "WoodRod", "FiberglassRod", "GoldenRod", "AmethystRod", 
        "RubyRod", "EmeraldRod", "DiamondRod", "InfernalRod", "CelestialRod",
        "VoidRod", "GodlyRod", "OmniscientRod"
    }
    for _, rod in ipairs(rods) do
        pcall(function()
            Remotes.PolesPurchase:InvokeServer(rod)
        end)
        task.wait(0.06)
    end
end

function AutoMerchants.StartAutoBuyFishingRods(interval)
    AutoMerchants.AutoBuyFishingRodsEnabled = true
    interval = interval or 10

    if rodsThread then task.cancel(rodsThread) end
    rodsThread = task.spawn(function()
        while AutoMerchants.AutoBuyFishingRodsEnabled do
            AutoMerchants.BuyAvailableFishingRodsOnce()
            task.wait(interval)
        end
    end)
end

function AutoMerchants.StopAutoBuyFishingRods()
    AutoMerchants.AutoBuyFishingRodsEnabled = false
    if rodsThread then
        pcall(function() task.cancel(rodsThread) end)
        rodsThread = nil
    end
end

function AutoMerchants.BuyCarryOnce()
    if not Remotes or not Remotes:FindFirstChild("CarryUpgrade") then return end
    pcall(function()
        Remotes.CarryUpgrade:InvokeServer()
    end)
end

function AutoMerchants.StartAutoBuyCarry(interval)
    AutoMerchants.AutoBuyCarryEnabled = true
    interval = interval or 10

    if carryThread then task.cancel(carryThread) end
    carryThread = task.spawn(function()
        while AutoMerchants.AutoBuyCarryEnabled do
            AutoMerchants.BuyCarryOnce()
            task.wait(interval)
        end
    end)
end

function AutoMerchants.StopAutoBuyCarry()
    AutoMerchants.AutoBuyCarryEnabled = false
    if carryThread then
        pcall(function() task.cancel(carryThread) end)
        carryThread = nil
    end
end

-- =================================================================
-- 🛑 STOP ALL MERCHANTS
-- =================================================================
function AutoMerchants.StopAll()
    AutoMerchants.StopAutoBuySelene()
    AutoMerchants.StopAutoBuyAngelia()
    AutoMerchants.StopAutoBuyBoosts()
    AutoMerchants.StopAutoBuyFishingRods()
    AutoMerchants.StopAutoBuyCarry()
end

_G.FishAnAnimeAutoMerchants = AutoMerchants
return AutoMerchants
