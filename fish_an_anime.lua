--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (SMART MODULAR SUITE V2.1)
	Game: Fish an Anime RNG 🎲 (PlaceId: 74729868188364)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🧩 MODULE DIRECTORY: modules/fish_an_anime/
	  - auto_fish.lua (Event-Driven Auto Fishing & Backpack)
	  - auto_farm.lua (Auto Quests, Index, Upgrades, Rebirth & All Merchants)
	  - base_units.lua (Realtime Base Units Scanner & Smart Level Up)
	  - anti_afk.lua (Bulletproof Keepalive & Anti-AFK Daemon)
	  - config_manager.lua (Persistent Profile Config)
	- 🛡️ 100% SMART & SILENT OPERATION (BAC Safe / Anti-Kick Hook)
	- 🖥️ MODERN RITOD UI (680x440) with Minimize Floating Widget
	===============================================================
]]

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.3)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- =================================================================
-- 🛡️ 1. CLIENT ANTI-KICK HOOK (BAC BYPASS)
-- =================================================================
pcall(function()
    local hook
    hook = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if (method == "Kick" or method == "kick") and self == LocalPlayer then
            warn("🛡️ [Ritod Anti-Kick] Memblokir upaya Kick dari Game Anti-Cheat: ", args[1] or "Unknown")
            return nil
        end
        return hook(self, ...)
    end)
end)

-- =================================================================
-- 🛡️ 2. CLEANUP PREVIOUS SESSIONS
-- =================================================================
pcall(function()
    if typeof(_G.RitodHubCleanup) == "function" then _G.RitodHubCleanup() end
    if _G.FishAnAnimeAutoFish and typeof(_G.FishAnAnimeAutoFish.StopAll) == "function" then
        _G.FishAnAnimeAutoFish.StopAll()
    end
    if _G.FishAnAnimeAutoFarm and typeof(_G.FishAnAnimeAutoFarm.StopAll) == "function" then
        _G.FishAnAnimeAutoFarm.StopAll()
    end
    if _G.FishAnAnimeBaseUnits and typeof(_G.FishAnAnimeBaseUnits.StopAutoLevelUp) == "function" then
        _G.FishAnAnimeBaseUnits.StopAutoLevelUp()
    end
    if _G.FishAnAnimeAntiAFK and typeof(_G.FishAnAnimeAntiAFK.Stop) == "function" then
        _G.FishAnAnimeAntiAFK.Stop()
    end
    if _G.RitodHubFishAnAnime and typeof(_G.RitodHubFishAnAnime) == "Instance" then
        pcall(function() _G.RitodHubFishAnAnime:Destroy() end)
    end
end)

-- =================================================================
-- 🌐 3. MODULAR LOADER (LOCAL & GITHUB SUPPORT)
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/fish_an_anime/"
local SHARED_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/"

local function loadModule(name, isShared)
    local targetUrl = (isShared and SHARED_URL or BASE_URL) .. name .. ".lua"
    local success, result = pcall(function()
        local src = game:HttpGet(targetUrl)
        if src and #src > 10 and not src:find("404: Not Found") then
            local fn = loadstring(src)
            if fn then return fn() end
        end
        return nil
    end)
    if success and result then return result end

    local localPath = (isShared and "modules/shared/" or "modules/fish_an_anime/") .. name .. ".lua"
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(localPath) then
        local fn = loadstring(readfile(localPath))
        if fn then return fn() end
    end
    return nil
end

local RitodUI = loadModule("ritod_ui", true)
local AutoFish = loadModule("auto_fish", false)
local AutoFarm = loadModule("auto_farm", false)
local BaseUnits = loadModule("base_units", false)
local AntiAFK = loadModule("anti_afk", false)
local ConfigManager = loadModule("config_manager", false)

if not AutoFish and _G.FishAnAnimeAutoFish then AutoFish = _G.FishAnAnimeAutoFish end
if not AutoFarm and _G.FishAnAnimeAutoFarm then AutoFarm = _G.FishAnAnimeAutoFarm end
if not BaseUnits and _G.FishAnAnimeBaseUnits then BaseUnits = _G.FishAnAnimeBaseUnits end
if not AntiAFK and _G.FishAnAnimeAntiAFK then AntiAFK = _G.FishAnAnimeAntiAFK end
if not ConfigManager and _G.FishAnAnimeConfigManager then ConfigManager = _G.FishAnAnimeConfigManager end

local CurrentConfig = ConfigManager and ConfigManager.CurrentConfig or {}

-- Sinkronisasi konfigurasi ke module farm
if AutoFarm then
    if CurrentConfig.SelectedPotions then AutoFarm.SelectedPotions = CurrentConfig.SelectedPotions end
    if CurrentConfig.AutoBuyBoostsSelected then AutoFarm.AutoBuyBoostsSelected = CurrentConfig.AutoBuyBoostsSelected end
    if CurrentConfig.AutoBuyBoostsCurrency then AutoFarm.AutoBuyBoostsCurrency = CurrentConfig.AutoBuyBoostsCurrency end
    if CurrentConfig.AutoBuySeleneSelected then AutoFarm.AutoBuySeleneSelected = CurrentConfig.AutoBuySeleneSelected end
    if CurrentConfig.AutoBuyAngeliaSelected then AutoFarm.AutoBuyAngeliaSelected = CurrentConfig.AutoBuyAngeliaSelected end
end

local function formatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e15 then return string.format("%.2fQa", n / 1e15)
    elseif n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.2fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

-- =================================================================
-- 🖥️ 4. GUI INTERFACE (RitodUI)
-- =================================================================
local Window = RitodUI:CreateWindow({
    Title = "⚡RITOD HUB⚡",
    GameName = "Fish an Anime RNG 🎲",
    Size = Vector2.new(680, 440),
    OnUnload = function()
        if AutoFish and AutoFish.StopAll then AutoFish.StopAll() end
        if AutoFarm and AutoFarm.StopAll then AutoFarm.StopAll() end
        if BaseUnits and BaseUnits.StopAutoLevelUp then BaseUnits.StopAutoLevelUp() end
        if AntiAFK and AntiAFK.Stop then AntiAFK.Stop() end
    end
})

-- ── Tab 1: 🎣 Fishing ──
local FishingTab = Window:CreateTab("Fishing", "🎣")

FishingTab:AddSection("🎣 Auto Fishing Controller")

FishingTab:AddToggle("Auto Fish (Event-Driven Instant Reel)", CurrentConfig.AutoFish or false, function(state)
    CurrentConfig.AutoFish = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFish.FastClick = CurrentConfig.FastClick ~= false
        AutoFish.StartFishing()
        Window.Notify("Auto Fishing", "Status: AKTIF (Instant Event-Driven)", 2.5)
    else
        AutoFish.StopFishing()
        Window.Notify("Auto Fishing", "Status: NONAKTIF", 2.0)
    end
end)

FishingTab:AddToggle("Instant Hook Catch (Fast Reel)", CurrentConfig.FastClick ~= false, function(state)
    CurrentConfig.FastClick = state
    if AutoFish then AutoFish.FastClick = state end
    if ConfigManager then ConfigManager.Save() end
end)

FishingTab:AddSection("⚡ Manual / Instant Controls")

FishingTab:AddButton("🎣 Cast Rod (Instant 1x)", function()
    local success = AutoFish and AutoFish.CastRod()
    if success then
        Window.Notify("Cast Rod", "Umpan berhasil dilempar!", 2.0)
    else
        Window.Notify("Cast Rod", "Gagal melempar rod / Pond tidak ditemukan", 2.0)
    end
end)

FishingTab:AddButton("🛑 Cancel Fishing (Instant 1x)", function()
    if AutoFish then AutoFish.CancelFishing() end
    Window.Notify("Fishing", "Aktivitas memancing dibatalkan.", 2.0)
end)

-- ── Tab 2: 🏰 Base Units (Level Up & Realtime Scanner) ──
local BaseUnitsTab = Window:CreateTab("Base Units", "🏰")

BaseUnitsTab:AddSection("⚡ Base Units Level Up Controller")

BaseUnitsTab:AddToggle("Auto Level Up All Base Units (Max Level)", CurrentConfig.AutoLevelUpBaseUnits or false, function(state)
    CurrentConfig.AutoLevelUpBaseUnits = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if BaseUnits then BaseUnits.StartAutoLevelUp(CurrentConfig.BaseUnitsInterval or 10) end
        Window.Notify("Base Units", "Auto Level Up All Units diaktifkan!", 2.5)
    else
        if BaseUnits then BaseUnits.StopAutoLevelUp() end
        Window.Notify("Base Units", "Auto Level Up All Units dinonaktifkan!", 2.0)
    end
end)

BaseUnitsTab:AddButton("🌟 Max Level Up All Units Now (1x)", function()
    if BaseUnits then
        local count = BaseUnits.LevelUpAllUnitsOnce()
        Window.Notify("Base Units", string.format("Berhasil menaikkan level %d unit ke Max Level!", count), 3.0)
    end
end)

BaseUnitsTab:AddSection("🔍 Realtime Base Units Scanner")

local scannerSectionLabels = {}

local function refreshUnitsScanner()
    if not BaseUnits then return end
    local units = BaseUnits.ScanUnits()
    
    local plot = BaseUnits.GetPlayerPlot()
    local plotName = plot and plot.Name or "Unknown"

    Window.Notify("Scanner", string.format("Scan selesai: %d unit terpasang di %s!", #units, plotName), 2.5)
end

BaseUnitsTab:AddButton("🔄 Scan / Refresh Base Units", function()
    refreshUnitsScanner()
end)

-- Render unit list saat pertama kali dimuat
local initialUnits = BaseUnits and BaseUnits.ScanUnits() or {}
for _, u in ipairs(initialUnits) do
    local infoStr = string.format("[Stand %s] %s (%s) | Lvl %d | $%s/s | %s",
        u.StandId, u.Name, u.Rarity, u.Level, formatNumber(u.CPS), u.UpgradeCostText
    )
    BaseUnitsTab:AddButton(infoStr, function()
        if BaseUnits then
            local res = BaseUnits.LevelUpStand(u.StandId)
            if res then
                Window.Notify("Level Up", string.format("Max Level Up berhasil untuk Stand %s (%s)!", u.StandId, u.Name), 2.5)
            else
                Window.Notify("Level Up", string.format("Gagal menaikkan level Stand %s!", u.StandId), 2.0)
            end
        end
    end)
end

-- ── Tab 3: 🏪 Merchants & Secret Store ──
local MerchantTab = Window:CreateTab("Merchants", "🏪")

MerchantTab:AddSection("🌙 Secret Merchant: Selene (Dark / Void)")

MerchantTab:AddToggle("Auto Buy Selene Items", CurrentConfig.AutoBuySelene or false, function(state)
    CurrentConfig.AutoBuySelene = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoBuySelene(10)
        Window.Notify("Selene Auto Buy", "Auto Buy Selene diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoBuySelene()
        Window.Notify("Selene Auto Buy", "Auto Buy Selene dinonaktifkan!", 2.0)
    end
end)

MerchantTab:AddButton("⚡ Buy Selected Selene Items Now (1x)", function()
    if AutoFarm then AutoFarm.BuySelectedSeleneOnce() end
    Window.Notify("Selene", "Membeli item Selene yang dipilih!", 2.0)
end)

local seleneOffers = {
    { id = "Offer1", name = "Exclusive Character", price = "5,000 Gems" },
    { id = "Offer2", name = "Luck Potion Lvl. 3", price = "25,000 Gems" },
    { id = "Offer3", name = "Heaven's Collide Potion", price = "20,000 Gems" },
    { id = "Offer4", name = "Luck Potion Lvl. 2", price = "$2.5Qa Cash" },
    { id = "Offer5", name = "Meteorite Potion", price = "$11M Cash" },
    { id = "Offer6", name = "Honey Potion", price = "$2M Cash" },
    { id = "Offer7", name = "Sinister Potion", price = "$200M Cash" }
}

for _, item in ipairs(seleneOffers) do
    local isChecked = (CurrentConfig.AutoBuySeleneSelected and CurrentConfig.AutoBuySeleneSelected[item.id]) or false
    MerchantTab:AddToggle(string.format("[%s] %s (%s)", item.id, item.name, item.price), isChecked, function(state)
        CurrentConfig.AutoBuySeleneSelected[item.id] = state
        if AutoFarm then AutoFarm.AutoBuySeleneSelected[item.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

MerchantTab:AddSection("👼 Secret Merchant: Angelia (Heavens)")

MerchantTab:AddToggle("Auto Buy Angelia Items", CurrentConfig.AutoBuyAngelia or false, function(state)
    CurrentConfig.AutoBuyAngelia = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoBuyAngelia(10)
        Window.Notify("Angelia Auto Buy", "Auto Buy Angelia diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoBuyAngelia()
        Window.Notify("Angelia Auto Buy", "Auto Buy Angelia dinonaktifkan!", 2.0)
    end
end)

MerchantTab:AddButton("⚡ Buy Selected Angelia Items Now (1x)", function()
    if AutoFarm then AutoFarm.BuySelectedAngeliaOnce() end
    Window.Notify("Angelia", "Membeli item Angelia yang dipilih!", 2.0)
end)

local angeliaOffers = {
    { id = "Offer1", name = "Forgotten Potion", price = "5,000,000 Gems (Rebirth 75)" },
    { id = "Offer2", name = "Backpack Storage +500", price = "75,000 Gems" },
    { id = "Offer3", name = "Cybernetic Glitch Potion", price = "750,000 Gems" },
    { id = "Offer4", name = "Dreamer Potion", price = "200,000 Gems" },
    { id = "Offer5", name = "Party Potion", price = "50,000 Gems" },
    { id = "Offer6", name = "Fast Catch Potion Lvl. 2", price = "$100T Cash" },
    { id = "Offer7", name = "Luck Potion Lvl. 3", price = "25,000 Gems" },
    { id = "Offer8", name = "EXE Potion", price = "10,000 Gems" },
    { id = "Offer9", name = "Cosmic Case (Crate)", price = "$100B Cash" }
}

for _, item in ipairs(angeliaOffers) do
    local isChecked = (CurrentConfig.AutoBuyAngeliaSelected and CurrentConfig.AutoBuyAngeliaSelected[item.id]) or false
    MerchantTab:AddToggle(string.format("[%s] %s (%s)", item.id, item.name, item.price), isChecked, function(state)
        CurrentConfig.AutoBuyAngeliaSelected[item.id] = state
        if AutoFarm then AutoFarm.AutoBuyAngeliaSelected[item.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

MerchantTab:AddSection("🎣 Fishing Rods & Carry Capacity")

MerchantTab:AddToggle("Auto Buy Available Fishing Rods", CurrentConfig.AutoBuyFishingRods or false, function(state)
    CurrentConfig.AutoBuyFishingRods = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoBuyFishingRods(10)
        Window.Notify("Rods Auto Buy", "Auto Buy Fishing Rods diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoBuyFishingRods()
        Window.Notify("Rods Auto Buy", "Auto Buy Fishing Rods dinonaktifkan!", 2.0)
    end
end)

MerchantTab:AddButton("⚡ Buy Available Rods Now (1x)", function()
    if AutoFarm then AutoFarm.BuyAvailableFishingRodsOnce() end
    Window.Notify("Fishing Rods", "Membeli pancingan yang memenuhi syarat!", 2.0)
end)

MerchantTab:AddToggle("Auto Buy Carry Capacity (+1)", CurrentConfig.AutoBuyCarry or false, function(state)
    CurrentConfig.AutoBuyCarry = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoBuyCarry(10)
        Window.Notify("Carry Auto Buy", "Auto Buy Carry Capacity diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoBuyCarry()
        Window.Notify("Carry Auto Buy", "Auto Buy Carry Capacity dinonaktifkan!", 2.0)
    end
end)

-- ── Tab 4: 🧪 Boosts Store & Potions ──
local BoostTab = Window:CreateTab("Boosts", "🧪")

BoostTab:AddSection("🏪 Boosts Store (NPC Valora - Auto Restock)")

BoostTab:AddToggle("Auto Buy Boosts Store Items", CurrentConfig.AutoBuyBoosts or false, function(state)
    CurrentConfig.AutoBuyBoosts = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoBuyBoosts()
        Window.Notify("Boosts Store", "Auto Buy Boosts Store diaktifkan (Auto Restock Watcher)!", 2.0)
    else
        AutoFarm.StopAutoBuyBoosts()
        Window.Notify("Boosts Store", "Auto Buy Boosts Store dinonaktifkan!", 2.0)
    end
end)

BoostTab:AddToggle("Pay with Cash (OFF = Pay with Gems)", CurrentConfig.AutoBuyBoostsCurrency ~= "Gems", function(state)
    local cur = state and "Cash" or "Gems"
    CurrentConfig.AutoBuyBoostsCurrency = cur
    if AutoFarm then AutoFarm.AutoBuyBoostsCurrency = cur end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Currency", "Metode bayar Boosts Store: " .. cur, 2.0)
end)

BoostTab:AddButton("⚡ Buy Selected Boosts Now (1x)", function()
    if AutoFarm then AutoFarm.BuySelectedBoostsOnce() end
    Window.Notify("Boosts Store", "Membeli seluruh stock boosts yang dipilih!", 2.0)
end)

local boostsStoreOffers = {
    { id = "Offer1", name = "Cash 2x Potion", cash = "$7.5K", gems = "50" },
    { id = "Offer2", name = "Cash 4x Potion", cash = "$20B", gems = "2,000" },
    { id = "Offer3", name = "Cash 8x Potion", cash = "$10Qa", gems = "10,000" },
    { id = "Offer4", name = "Gems 2x Potion", cash = "$15M", gems = "150" },
    { id = "Offer5", name = "Gems 4x Potion", cash = "$30B", gems = "1,500" },
    { id = "Offer6", name = "Gems 8x Potion", cash = "$15Qa", gems = "7,500" },
    { id = "Offer7", name = "Mutation 2x Potion", cash = "$50T", gems = "500" },
    { id = "Offer8", name = "Fast Catch 2x Potion", cash = "$2.5M", gems = "100" },
    { id = "Offer9", name = "Luck 2x Potion", cash = "$10B", gems = "250" }
}

for _, item in ipairs(boostsStoreOffers) do
    local isChecked = (CurrentConfig.AutoBuyBoostsSelected and CurrentConfig.AutoBuyBoostsSelected[item.id]) or false
    BoostTab:AddToggle(string.format("[%s] %s ($%s / %s 💎)", item.id, item.name, item.cash, item.gems), isChecked, function(state)
        CurrentConfig.AutoBuyBoostsSelected[item.id] = state
        if AutoFarm then AutoFarm.AutoBuyBoostsSelected[item.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

BoostTab:AddSection("🧪 Potion Uptime (Auto Use when Expired)")

BoostTab:AddToggle("Auto Maintain Active Potions (24/7 Buff)", CurrentConfig.AutoPotions or false, function(state)
    CurrentConfig.AutoPotions = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoPotions(CurrentConfig.PotionInterval or 10)
        Window.Notify("Auto Potions", "Auto Potions Uptime diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoPotions()
        Window.Notify("Auto Potions", "Auto Potions Uptime dinonaktifkan!", 2.0)
    end
end)

BoostTab:AddButton("⚡ Use Selected Potions Now (1x)", function()
    if AutoFarm then AutoFarm.UseSelectedPotionsOnce() end
    Window.Notify("Potions", "Menggunakan ramuan yang dipilih dari tas!", 2.0)
end)

local commonPotions = {
    "Luck Potion Lvl. 1",
    "Luck Potion Lvl. 2",
    "Luck Potion Lvl. 3",
    "Fast Catch Potion Lvl. 1",
    "Fast Catch Potion Lvl. 2",
    "Mutation Potion Lvl. 1",
    "Gems Potion Lvl. 1",
    "Gems Potion Lvl. 2",
    "Gems Potion Lvl. 3",
    "Cash Potion Lvl. 1",
    "Cash Potion Lvl. 2",
    "Cash Potion Lvl. 3",
    "Heaven's Collide Potion",
    "Sinister Potion",
    "Meteorite Potion"
}

for _, pot in ipairs(commonPotions) do
    local isChecked = (CurrentConfig.SelectedPotions and CurrentConfig.SelectedPotions[pot]) or false
    BoostTab:AddToggle(pot, isChecked, function(state)
        CurrentConfig.SelectedPotions[pot] = state
        if AutoFarm then AutoFarm.SelectedPotions[pot] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

-- ── Tab 5: 🎒 Backpack & Sell ──
local BackpackTab = Window:CreateTab("Backpack", "🎒")

BackpackTab:AddSection("🎒 Auto Inventory Actions")

BackpackTab:AddToggle("Auto Equip Best Character", CurrentConfig.AutoEquipBest or false, function(state)
    CurrentConfig.AutoEquipBest = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFish.StartAutoEquipBest(5)
        Window.Notify("Equip Best", "Auto Equip Best diaktifkan!", 2.0)
    else
        AutoFish.StopAutoEquipBest()
        Window.Notify("Equip Best", "Auto Equip Best dinonaktifkan!", 2.0)
    end
end)

BackpackTab:AddToggle("Auto Pick Up All Drops", CurrentConfig.AutoPickUpAll or false, function(state)
    CurrentConfig.AutoPickUpAll = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFish.StartAutoPickUpAll(3)
        Window.Notify("Pick Up All", "Auto Pick Up All diaktifkan!", 2.0)
    else
        AutoFish.StopAutoPickUpAll()
        Window.Notify("Pick Up All", "Auto Pick Up All dinonaktifkan!", 2.0)
    end
end)

BackpackTab:AddToggle("Auto Sell All Items", CurrentConfig.AutoSellAll or false, function(state)
    CurrentConfig.AutoSellAll = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFish.StartAutoSellAll(CurrentConfig.AutoSellInterval or 10)
        Window.Notify("Auto Sell", "Auto Sell All diaktifkan!", 2.0)
    else
        AutoFish.StopAutoSellAll()
        Window.Notify("Auto Sell", "Auto Sell All dinonaktifkan!", 2.0)
    end
end)

BackpackTab:AddSection("⚡ Instant Backpack Actions")

BackpackTab:AddButton("⭐ Equip Best Now (1x)", function()
    if AutoFish then AutoFish.EquipBestOnce() end
    Window.Notify("Equip Best", "Berhasil mengequip character terbaik!", 2.0)
end)

BackpackTab:AddButton("📦 Pick Up All Drops (1x)", function()
    if AutoFish then AutoFish.PickUpAllOnce() end
    Window.Notify("Pick Up", "Berhasil mengambil seluruh item drop!", 2.0)
end)

BackpackTab:AddButton("💰 Sell All Items Now (1x)", function()
    if AutoFish then AutoFish.SellAllOnce() end
    Window.Notify("Sell All", "Berhasil menjual seluruh isi backpack!", 2.5)
end)

BackpackTab:AddSection("💎 Sell by Rarity (Instant 1x)")
local rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret"}
for _, r in ipairs(rarities) do
    BackpackTab:AddButton("💰 Sell All " .. r .. " (1x)", function()
        if AutoFish then AutoFish.SellRarityOnce(r) end
        Window.Notify("Sell Rarity", "Berhasil menjual item rarity: " .. r, 2.0)
    end)
end

-- ── Tab 6: 📜 Quests & Progression ──
local QuestTab = Window:CreateTab("Quests", "📜")

QuestTab:AddSection("📜 Auto Quests")

QuestTab:AddToggle("Auto Claim All Quests", CurrentConfig.AutoClaimQuests or false, function(state)
    CurrentConfig.AutoClaimQuests = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoQuests(CurrentConfig.QuestClaimInterval or 5)
        Window.Notify("Auto Quest", "Auto Claim Quests diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoQuests()
        Window.Notify("Auto Quest", "Auto Claim Quests dinonaktifkan!", 2.0)
    end
end)

QuestTab:AddButton("⚡ Claim All Quests Now (1x)", function()
    local res = AutoFarm and AutoFarm.ClaimAllQuestsOnce()
    Window.Notify("Claim Quests", "Semua quest yang selesai berhasil di-claim!", 2.5)
end)

QuestTab:AddSection("📖 Auto Index Rewards")

QuestTab:AddToggle("Auto Claim Index Rewards", CurrentConfig.AutoClaimIndex or false, function(state)
    CurrentConfig.AutoClaimIndex = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoIndex(10)
        Window.Notify("Auto Index", "Auto Claim Index diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoIndex()
        Window.Notify("Auto Index", "Auto Claim Index dinonaktifkan!", 2.0)
    end
end)

QuestTab:AddButton("⚡ Claim All Index Rewards Now (1x)", function()
    local res = AutoFarm and AutoFarm.ClaimAllIndexOnce()
    Window.Notify("Claim Index", "Semua reward index berhasil di-claim!", 2.5)
end)

QuestTab:AddSection("⚡ Upgrades & Rebirth")

QuestTab:AddToggle("Auto Upgrades (All Tiers)", CurrentConfig.AutoUpgrades or false, function(state)
    CurrentConfig.AutoUpgrades = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoUpgrades(CurrentConfig.UpgradesInterval or 3)
        Window.Notify("Auto Upgrades", "Auto Upgrades diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoUpgrades()
        Window.Notify("Auto Upgrades", "Auto Upgrades dinonaktifkan!", 2.0)
    end
end)

QuestTab:AddButton("⚡ Buy All Affordable Upgrades (1x)", function()
    if AutoFarm then AutoFarm.BuyAllUpgradesOnce() end
    Window.Notify("Upgrades", "Membeli seluruh upgrade yang terjangkau!", 2.0)
end)

QuestTab:AddToggle("Auto Rebirth", CurrentConfig.AutoRebirth or false, function(state)
    CurrentConfig.AutoRebirth = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoRebirth(3)
        Window.Notify("Auto Rebirth", "Auto Rebirth diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoRebirth()
        Window.Notify("Auto Rebirth", "Auto Rebirth dinonaktifkan!", 2.0)
    end
end)

QuestTab:AddButton("⚡ Rebirth Now (Instant 1x)", function()
    local res = AutoFarm and AutoFarm.RebirthOnce()
    Window.Notify("Rebirth", "Mencoba melakukan Rebirth!", 2.0)
end)

-- ── Tab 7: ⚙️ Settings (Config Manager & Anti-AFK) ──
local SettingsTab = Window:CreateTab("Settings", "⚙️")

SettingsTab:AddSection("🛡️ Protection & Anti-AFK")

SettingsTab:AddToggle("Anti-AFK (24/7 Keep Alive)", CurrentConfig.AntiAFK ~= false, function(state)
    CurrentConfig.AntiAFK = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AntiAFK.Start()
        Window.Notify("Anti-AFK", "Anti-AFK diaktifkan", 2.0)
    else
        AntiAFK.Stop()
        Window.Notify("Anti-AFK", "Anti-AFK dinonaktifkan", 2.0)
    end
end)

SettingsTab:AddSection("💾 Configuration Manager")

SettingsTab:AddButton("💾 Save Configuration Now", function()
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Config Saved", "Konfigurasi berhasil disimpan!", 2.5)
end)

SettingsTab:AddButton("🔄 Reload Configuration", function()
    if ConfigManager then
        ConfigManager.Load()
        if CurrentConfig.AutoFish then AutoFish.StartFishing() else AutoFish.StopFishing() end
        if CurrentConfig.AutoEquipBest then AutoFish.StartAutoEquipBest() else AutoFish.StopAutoEquipBest() end
        if CurrentConfig.AutoPickUpAll then AutoFish.StartAutoPickUpAll() else AutoFish.StopAutoPickUpAll() end
        if CurrentConfig.AutoSellAll then AutoFish.StartAutoSellAll() else AutoFish.StopAutoSellAll() end
        if CurrentConfig.AutoClaimQuests then AutoFarm.StartAutoQuests() else AutoFarm.StopAutoQuests() end
        if CurrentConfig.AutoClaimIndex then AutoFarm.StartAutoIndex() else AutoFarm.StopAutoIndex() end
        if CurrentConfig.AutoUpgrades then AutoFarm.StartAutoUpgrades() else AutoFarm.StopAutoUpgrades() end
        if CurrentConfig.AutoRebirth then AutoFarm.StartAutoRebirth() else AutoFarm.StopAutoRebirth() end
        if CurrentConfig.AutoPotions then AutoFarm.StartAutoPotions() else AutoFarm.StopAutoPotions() end
        if CurrentConfig.AutoBuyBoosts then AutoFarm.StartAutoBuyBoosts() else AutoFarm.StopAutoBuyBoosts() end
        if CurrentConfig.AutoBuySelene then AutoFarm.StartAutoBuySelene() else AutoFarm.StopAutoBuySelene() end
        if CurrentConfig.AutoBuyAngelia then AutoFarm.StartAutoBuyAngelia() else AutoFarm.StopAutoBuyAngelia() end
        if CurrentConfig.AutoBuyFishingRods then AutoFarm.StartAutoBuyFishingRods() else AutoFarm.StopAutoBuyFishingRods() end
        if CurrentConfig.AutoBuyCarry then AutoFarm.StartAutoBuyCarry() else AutoFarm.StopAutoBuyCarry() end
        if CurrentConfig.AutoLevelUpBaseUnits and BaseUnits then BaseUnits.StartAutoLevelUp() else if BaseUnits then BaseUnits.StopAutoLevelUp() end end
        if CurrentConfig.AntiAFK ~= false then AntiAFK.Start() else AntiAFK.Stop() end
    end
    Window.Notify("Config Loaded", "Konfigurasi berhasil dimuat ulang!", 2.5)
end)

SettingsTab:AddButton("🗑️ Reset to Default Settings", function()
    if ConfigManager then ConfigManager.Reset() end
    if AutoFish then AutoFish.StopAll() end
    if AutoFarm then AutoFarm.StopAll() end
    if BaseUnits then BaseUnits.StopAutoLevelUp() end
    Window.Notify("Config Reset", "Pengaturan dikembalikan ke default!", 2.5)
end)

SettingsTab:AddSection("🚪 Utilities")

SettingsTab:AddButton("🔄 Rejoin Server", function()
    local ts = game:GetService("TeleportService")
    ts:Teleport(game.PlaceId, LocalPlayer)
end)

-- ── Auto start dari saved config jika sebelumnya aktif ──
if CurrentConfig.AutoFish then AutoFish.StartFishing() end
if CurrentConfig.AutoEquipBest then AutoFish.StartAutoEquipBest() end
if CurrentConfig.AutoPickUpAll then AutoFish.StartAutoPickUpAll() end
if CurrentConfig.AutoSellAll then AutoFish.StartAutoSellAll() end
if CurrentConfig.AutoClaimQuests then AutoFarm.StartAutoQuests() end
if CurrentConfig.AutoClaimIndex then AutoFarm.StartAutoIndex() end
if CurrentConfig.AutoUpgrades then AutoFarm.StartAutoUpgrades() end
if CurrentConfig.AutoRebirth then AutoFarm.StartAutoRebirth() end
if CurrentConfig.AutoPotions then AutoFarm.StartAutoPotions() end
if CurrentConfig.AutoBuyBoosts then AutoFarm.StartAutoBuyBoosts() end
if CurrentConfig.AutoBuySelene then AutoFarm.StartAutoBuySelene() end
if CurrentConfig.AutoBuyAngelia then AutoFarm.StartAutoBuyAngelia() end
if CurrentConfig.AutoBuyFishingRods then AutoFarm.StartAutoBuyFishingRods() end
if CurrentConfig.AutoBuyCarry then AutoFarm.StartAutoBuyCarry() end
if CurrentConfig.AutoLevelUpBaseUnits and BaseUnits then BaseUnits.StartAutoLevelUp() end
if CurrentConfig.AntiAFK ~= false then AntiAFK.Start() end

-- Destructor
_G.RitodHubFishAnAnime = Window.ScreenGui
_G.RitodHubCleanup = function()
    pcall(function()
        if AutoFish and AutoFish.StopAll then AutoFish.StopAll() end
        if AutoFarm and AutoFarm.StopAll then AutoFarm.StopAll() end
        if BaseUnits and BaseUnits.StopAutoLevelUp then BaseUnits.StopAutoLevelUp() end
        if AntiAFK and AntiAFK.Stop then AntiAFK.Stop() end
        if Window.ScreenGui and Window.ScreenGui.Parent then Window.ScreenGui:Destroy() end
    end)
end

Window.Notify("⚡RITOD HUB⚡", "Fish an Anime RNG Loaded Successfully!", 3.5)
return Window
