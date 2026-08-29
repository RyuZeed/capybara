--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (SMART MODULAR SUITE V3.0)
	Game: Fish an Anime RNG 🎲 (PlaceId: 74729868188364)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🧩 MODULE DIRECTORY: modules/fish_an_anime/
	  - auto_fish.lua (Event-Driven Auto Fishing & Backpack)
	  - auto_merchants.lua (Selene, Angelia, Valora Boosts Store, Rods & Carry)
	  - auto_farm.lua (Specific Upgrades, Quests, All Rewards Claim & Rebirth)
	  - base_units.lua (Realtime Base Units Scanner, Focus Rarity & Level Up)
	  - graphics.lua (Potato Graphics, GPU Saver Black Screen & FPS Limiter)
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
-- 🛡️ 1. CLEANUP PREVIOUS SESSIONS & PURGE LEAKED THREADS
-- =================================================================
pcall(function()
    if typeof(_G.RitodHubCleanup) == "function" then _G.RitodHubCleanup() end
    if _G.FishAnAnimeAutoFish and typeof(_G.FishAnAnimeAutoFish.StopAll) == "function" then
        _G.FishAnAnimeAutoFish.StopAll()
    end
    if _G.FishAnAnimeAutoFarm and typeof(_G.FishAnAnimeAutoFarm.StopAll) == "function" then
        _G.FishAnAnimeAutoFarm.StopAll()
    end
    if _G.FishAnAnimeAutoMerchants and typeof(_G.FishAnAnimeAutoMerchants.StopAll) == "function" then
        _G.FishAnAnimeAutoMerchants.StopAll()
    end
    if _G.FishAnAnimeBaseUnits and typeof(_G.FishAnAnimeBaseUnits.StopAutoLevelUp) == "function" then
        _G.FishAnAnimeBaseUnits.StopAutoLevelUp()
    end
    if _G.FishAnAnimeGraphics and typeof(_G.FishAnAnimeGraphics.Unload) == "function" then
        _G.FishAnAnimeGraphics.Unload()
    end
    if _G.FishAnAnimeAntiAFK and typeof(_G.FishAnAnimeAntiAFK.Stop) == "function" then
        _G.FishAnAnimeAntiAFK.Stop()
    end
    if _G.RitodHubFishAnAnime and typeof(_G.RitodHubFishAnAnime) == "Instance" then
        pcall(function() _G.RitodHubFishAnAnime:Destroy() end)
    end
end)
-- Aggressive GC to reclaim leaked threads from previous sessions
pcall(function()
    if typeof(collectgarbage) == "function" then pcall(collectgarbage, "collect") end
    if typeof(gcinfo) == "function" then gcinfo() end
end)

-- =================================================================
-- 🌐 3. MODULAR LOADER (LOCAL & GITHUB SUPPORT)
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/fish_an_anime/"
local SHARED_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/"

local function loadModule(name, isShared)
    local targetUrl = (isShared and SHARED_URL or BASE_URL) .. name .. ".lua?t=" .. tostring(os.time())
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
local AutoMerchants = loadModule("auto_merchants", false)
local BaseUnits = loadModule("base_units", false)
local Graphics = loadModule("graphics", false)
local AntiAFK = loadModule("anti_afk", false)
local ConfigManager = loadModule("config_manager", false)

if not AutoFish and _G.FishAnAnimeAutoFish then AutoFish = _G.FishAnAnimeAutoFish end
if not AutoFarm and _G.FishAnAnimeAutoFarm then AutoFarm = _G.FishAnAnimeAutoFarm end
if not AutoMerchants and _G.FishAnAnimeAutoMerchants then AutoMerchants = _G.FishAnAnimeAutoMerchants end
if not BaseUnits and _G.FishAnAnimeBaseUnits then BaseUnits = _G.FishAnAnimeBaseUnits end
if not Graphics and _G.FishAnAnimeGraphics then Graphics = _G.FishAnAnimeGraphics end
if not AntiAFK and _G.FishAnAnimeAntiAFK then AntiAFK = _G.FishAnAnimeAntiAFK end
if not ConfigManager and _G.FishAnAnimeConfigManager then ConfigManager = _G.FishAnAnimeConfigManager end

local CurrentConfig = ConfigManager and ConfigManager.CurrentConfig or {}

-- Sinkronisasi konfigurasi ke module farm & merchants & base units
if AutoFarm then
    if CurrentConfig.SelectedPotions then AutoFarm.SelectedPotions = CurrentConfig.SelectedPotions end
    if CurrentConfig.AutoUpgradesSelected then AutoFarm.AutoUpgradesSelected = CurrentConfig.AutoUpgradesSelected end
end
if AutoMerchants then
    if CurrentConfig.AutoBuyBoostsSelected then AutoMerchants.AutoBuyBoostsSelected = CurrentConfig.AutoBuyBoostsSelected end
    if CurrentConfig.AutoBuyBoostsCurrency then AutoMerchants.AutoBuyBoostsCurrency = CurrentConfig.AutoBuyBoostsCurrency end
    if CurrentConfig.AutoBuySeleneSelected then AutoMerchants.AutoBuySeleneSelected = CurrentConfig.AutoBuySeleneSelected end
    if CurrentConfig.AutoBuyAngeliaSelected then AutoMerchants.AutoBuyAngeliaSelected = CurrentConfig.AutoBuyAngeliaSelected end
end
if BaseUnits then
    BaseUnits.FilterByRarity = CurrentConfig.FilterLevelUpByRarity or false
    if CurrentConfig.LevelUpSelectedRarities then
        BaseUnits.SelectedRarities = CurrentConfig.LevelUpSelectedRarities
    end
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
        if AutoMerchants and AutoMerchants.StopAll then AutoMerchants.StopAll() end
        if BaseUnits and BaseUnits.StopAutoLevelUp then BaseUnits.StopAutoLevelUp() end
        if Graphics and Graphics.DisableScreenOff then Graphics.DisableScreenOff() end
        if AntiAFK and AntiAFK.Stop then AntiAFK.Stop() end
    end
})

-- ═════════════════════════════════════════════════════════════════
-- ── 🏠 Tab 1: Main (Fishing & Base Units) ──
-- ═════════════════════════════════════════════════════════════════
local MainTab = Window:CreateTab("Main", "🏠")

MainTab:AddSection("🎣 Auto Fishing Controller")

MainTab:AddToggle("Auto Fish (Event-Driven Instant Reel)", CurrentConfig.AutoFish or false, function(state)
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

MainTab:AddToggle("Instant Hook Catch (Fast Reel)", CurrentConfig.FastClick ~= false, function(state)
    CurrentConfig.FastClick = state
    if AutoFish then AutoFish.FastClick = state end
    if ConfigManager then ConfigManager.Save() end
end)

MainTab:AddButton("🎣 Cast Rod Now (Instant 1x)", function()
    local success = AutoFish and AutoFish.CastRod()
    if success then
        Window.Notify("Cast Rod", "Umpan berhasil dilempar!", 2.0)
    else
        Window.Notify("Cast Rod", "Gagal melempar rod / Pond tidak ditemukan", 2.0)
    end
end)

MainTab:AddButton("🛑 Cancel Fishing (Instant 1x)", function()
    if AutoFish then AutoFish.CancelFishing() end
    Window.Notify("Fishing", "Aktivitas memancing dibatalkan.", 2.0)
end)

MainTab:AddSection("🏰 Base Units Level Up Controller")

MainTab:AddToggle("Auto Level Up Base Units (Max Level)", CurrentConfig.AutoLevelUpBaseUnits or false, function(state)
    CurrentConfig.AutoLevelUpBaseUnits = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if BaseUnits then BaseUnits.StartAutoLevelUp(CurrentConfig.BaseUnitsInterval or 10) end
        Window.Notify("Base Units", "Auto Level Up Units diaktifkan!", 2.5)
    else
        if BaseUnits then BaseUnits.StopAutoLevelUp() end
        Window.Notify("Base Units", "Auto Level Up Units dinonaktifkan!", 2.0)
    end
end)

MainTab:AddButton("🌟 Max Level Up All Units Now (1x)", function()
    if BaseUnits then
        local count = BaseUnits.LevelUpAllUnitsOnce()
        Window.Notify("Base Units", string.format("Berhasil menaikkan level %d unit ke Max Level!", count), 3.0)
    end
end)

MainTab:AddSection("🎯 Focus Level Up by Rarity")

MainTab:AddToggle("Filter Level Up by Rarity (Focus Mode)", CurrentConfig.FilterLevelUpByRarity or false, function(state)
    CurrentConfig.FilterLevelUpByRarity = state
    if BaseUnits then BaseUnits.FilterByRarity = state end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Rarity Focus", state and "Focus Rarity Mode: AKTIF" or "Focus Rarity Mode: NONAKTIF (Semua Rarity)", 2.0)
end)

local officialRarities = {
    { name = "Common", icon = "⚪" },
    { name = "Uncommon", icon = "💚" },
    { name = "Rare", icon = "💙" },
    { name = "Epic", icon = "💜" },
    { name = "Legendary", icon = "⚔️" },
    { name = "Mythical", icon = "🔮" },
    { name = "Cosmic", icon = "🪐" },
    { name = "Secret", icon = "🗝️" },
    { name = "Rainbow", icon = "🌈" },
    { name = "Ascended", icon = "🔺" },
    { name = "Divine", icon = "⚡" },
    { name = "Supreme", icon = "🌟" },
    { name = "Celestial", icon = "🌌" },
    { name = "Ancient", icon = "👑" },
    { name = "God", icon = "🔱" },
    { name = "Omniscient", icon = "👁️" },
    { name = "Exclusive", icon = "💎" }
}

for _, r in ipairs(officialRarities) do
    local isChecked = (CurrentConfig.LevelUpSelectedRarities and CurrentConfig.LevelUpSelectedRarities[r.name]) or false
    MainTab:AddToggle(string.format("%s %s", r.icon, r.name), isChecked, function(state)
        CurrentConfig.LevelUpSelectedRarities[r.name] = state
        if BaseUnits then BaseUnits.SelectedRarities[r.name] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

MainTab:AddSection("🔍 Realtime Base Units Scanner")

local rarityIcons = {
    Common = "⚪", Uncommon = "💚", Rare = "💙", Epic = "💜",
    Legendary = "⚔️", Mythical = "🔮", Cosmic = "🪐", Secret = "🗝️",
    Rainbow = "🌈", Ascended = "🔺", Divine = "⚡", Supreme = "🌟",
    Celestial = "🌌", Ancient = "👑", God = "🔱", Omniscient = "👁️",
    Exclusive = "💎"
}

MainTab:AddButton("🔄 Scan & List Base Units", function()
    if not BaseUnits then return end
    local units = BaseUnits.ScanUnits()
    local plot = BaseUnits.GetPlayerPlot()
    local plotName = plot and plot.Name or "Unknown"
    local lines = {}
    for _, u in ipairs(units) do
        local icon = rarityIcons[u.Rarity] or "⭐"
        table.insert(lines, string.format("%s %s [%s] (Stand %s) Lvl %d", icon, u.Name, u.Rarity, u.StandId, u.Level))
    end
    Window.Notify("Scanner", string.format("%d unit di %s:\n%s", #units, plotName, table.concat(lines, "\n")), 5.0)
end)

-- ═════════════════════════════════════════════════════════════════
-- ── 🏪 Tab 2: Shop & Boosts (Merchants, Boost Store & Potions) ──
-- ═════════════════════════════════════════════════════════════════
local ShopTab = Window:CreateTab("Shop & Boosts", "🏪")

ShopTab:AddSection("🌙 Secret Merchant: Selene (Dark / Void)")

ShopTab:AddToggle("Auto Buy Selene Items", CurrentConfig.AutoBuySelene or false, function(state)
    CurrentConfig.AutoBuySelene = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoMerchants then AutoMerchants.StartAutoBuySelene(5) end
        Window.Notify("Selene Auto Buy", "Auto Buy Selene diaktifkan!", 2.0)
    else
        if AutoMerchants then AutoMerchants.StopAutoBuySelene() end
        Window.Notify("Selene Auto Buy", "Auto Buy Selene dinonaktifkan!", 2.0)
    end
end)

ShopTab:AddButton("⚡ Buy Selected Selene Items Now (1x)", function()
    if AutoMerchants then AutoMerchants.BuySelectedSeleneOnce() end
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
    ShopTab:AddToggle(string.format("[%s] %s (%s)", item.id, item.name, item.price), isChecked, function(state)
        CurrentConfig.AutoBuySeleneSelected[item.id] = state
        if AutoMerchants then AutoMerchants.AutoBuySeleneSelected[item.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

ShopTab:AddSection("👼 Secret Merchant: Angelia (Heavenly Gate)")

ShopTab:AddToggle("Auto Buy Angelia Items", CurrentConfig.AutoBuyAngelia or false, function(state)
    CurrentConfig.AutoBuyAngelia = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoMerchants then AutoMerchants.StartAutoBuyAngelia(5) end
        Window.Notify("Angelia Auto Buy", "Auto Buy Angelia diaktifkan!", 2.0)
    else
        if AutoMerchants then AutoMerchants.StopAutoBuyAngelia() end
        Window.Notify("Angelia Auto Buy", "Auto Buy Angelia dinonaktifkan!", 2.0)
    end
end)

ShopTab:AddButton("⚡ Buy Selected Angelia Items Now (1x)", function()
    if AutoMerchants then AutoMerchants.BuySelectedAngeliaOnce() end
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
    ShopTab:AddToggle(string.format("[%s] %s (%s)", item.id, item.name, item.price), isChecked, function(state)
        CurrentConfig.AutoBuyAngeliaSelected[item.id] = state
        if AutoMerchants then AutoMerchants.AutoBuyAngeliaSelected[item.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

ShopTab:AddSection("🏪 Boosts Store (NPC Valora - Auto Restock)")

ShopTab:AddToggle("Auto Buy Boosts Store Items", CurrentConfig.AutoBuyBoosts or false, function(state)
    CurrentConfig.AutoBuyBoosts = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoMerchants then AutoMerchants.StartAutoBuyBoosts() end
        Window.Notify("Boosts Store", "Auto Buy Boosts Store diaktifkan (Auto Restock Watcher)!", 2.0)
    else
        if AutoMerchants then AutoMerchants.StopAutoBuyBoosts() end
        Window.Notify("Boosts Store", "Auto Buy Boosts Store dinonaktifkan!", 2.0)
    end
end)

ShopTab:AddToggle("Pay with Cash (OFF = Pay with Gems)", CurrentConfig.AutoBuyBoostsCurrency ~= "Gems", function(state)
    local cur = state and "Cash" or "Gems"
    CurrentConfig.AutoBuyBoostsCurrency = cur
    if AutoMerchants then AutoMerchants.AutoBuyBoostsCurrency = cur end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Currency", "Metode bayar Boosts Store: " .. cur, 2.0)
end)

ShopTab:AddButton("⚡ Buy Selected Boosts Now (1x)", function()
    if AutoMerchants then AutoMerchants.BuySelectedBoostsOnce() end
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
    ShopTab:AddToggle(string.format("[%s] %s ($%s / %s 💎)", item.id, item.name, item.cash, item.gems), isChecked, function(state)
        CurrentConfig.AutoBuyBoostsSelected[item.id] = state
        if AutoMerchants then AutoMerchants.AutoBuyBoostsSelected[item.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

ShopTab:AddSection("🧪 Potions Uptime Buff (24/7 Buff)")

ShopTab:AddToggle("Auto Maintain Active Potions (24/7 Buff)", CurrentConfig.AutoPotions or false, function(state)
    CurrentConfig.AutoPotions = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoPotions(CurrentConfig.PotionInterval or 5)
        Window.Notify("Auto Potions", "Auto Potions Uptime diaktifkan (24/7 Buff)!", 2.5)
    else
        AutoFarm.StopAutoPotions()
        Window.Notify("Auto Potions", "Auto Potions Uptime dinonaktifkan!", 2.0)
    end
end)

ShopTab:AddButton("⚡ Use Selected Potions Now (1x)", function()
    if AutoFarm then AutoFarm.UseSelectedPotionsOnce(true) end
    Window.Notify("Potions", "Berhasil menggunakan ramuan yang dipilih dari tas!", 2.5)
end)

local commonPotions = {
    "Luck Potion Lvl. 1", "Luck Potion Lvl. 2", "Luck Potion Lvl. 3",
    "Fast Catch Potion Lvl. 1", "Fast Catch Potion Lvl. 2", "Mutation Potion Lvl. 1",
    "Gems Potion Lvl. 1", "Gems Potion Lvl. 2", "Gems Potion Lvl. 3",
    "Cash Potion Lvl. 1", "Cash Potion Lvl. 2", "Cash Potion Lvl. 3",
    "Heaven's Collide Potion", "Sinister Potion", "Meteorite Potion",
    "Honey Potion", "Party Potion", "Dreamer Potion", "Cybernetic Glitch Potion"
}

ShopTab:AddButton("✅ Enable All Potions (Centang Semua)", function()
    for _, pot in ipairs(commonPotions) do
        CurrentConfig.SelectedPotions[pot] = true
        if AutoFarm then AutoFarm.SelectedPotions[pot] = true end
    end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Potions", "Semua jenis ramuan dicentang!", 2.0)
end)

ShopTab:AddButton("❌ Disable All Potions (Hapus Centang)", function()
    for _, pot in ipairs(commonPotions) do
        CurrentConfig.SelectedPotions[pot] = false
        if AutoFarm then AutoFarm.SelectedPotions[pot] = false end
    end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Potions", "Semua centang ramuan dinonaktifkan!", 2.0)
end)

for _, pot in ipairs(commonPotions) do
    local isChecked = (CurrentConfig.SelectedPotions and CurrentConfig.SelectedPotions[pot]) or false
    ShopTab:AddToggle(pot, isChecked, function(state)
        CurrentConfig.SelectedPotions[pot] = state
        if AutoFarm then AutoFarm.SelectedPotions[pot] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

ShopTab:AddSection("🎣 Fishing Rods & Carry Capacity")

ShopTab:AddToggle("Auto Buy Available Fishing Rods", CurrentConfig.AutoBuyFishingRods or false, function(state)
    CurrentConfig.AutoBuyFishingRods = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoMerchants then AutoMerchants.StartAutoBuyFishingRods(10) end
        Window.Notify("Rods Auto Buy", "Auto Buy Fishing Rods diaktifkan!", 2.0)
    else
        if AutoMerchants then AutoMerchants.StopAutoBuyFishingRods() end
        Window.Notify("Rods Auto Buy", "Auto Buy Fishing Rods dinonaktifkan!", 2.0)
    end
end)

ShopTab:AddButton("⚡ Buy Available Rods Now (1x)", function()
    if AutoMerchants then AutoMerchants.BuyAvailableFishingRodsOnce() end
    Window.Notify("Fishing Rods", "Membeli pancingan yang memenuhi syarat!", 2.0)
end)

ShopTab:AddToggle("Auto Buy Carry Capacity (+1)", CurrentConfig.AutoBuyCarry or false, function(state)
    CurrentConfig.AutoBuyCarry = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoMerchants then AutoMerchants.StartAutoBuyCarry(10) end
        Window.Notify("Carry Auto Buy", "Auto Buy Carry Capacity diaktifkan!", 2.0)
    else
        if AutoMerchants then AutoMerchants.StopAutoBuyCarry() end
        Window.Notify("Carry Auto Buy", "Auto Buy Carry Capacity dinonaktifkan!", 2.0)
    end
end)

-- ═════════════════════════════════════════════════════════════════
-- ── 🎒 Tab 3: Backpack & Sell ──
-- ═════════════════════════════════════════════════════════════════
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

BackpackTab:AddSection("💎 Sell by Rarity (All 17 Rarities)")

for _, r in ipairs(officialRarities) do
    BackpackTab:AddButton(string.format("%s Sell All %s (1x)", r.icon, r.name), function()
        if AutoFish then AutoFish.SellRarityOnce(r.name) end
        Window.Notify("Sell Rarity", string.format("Berhasil menjual item rarity: %s %s!", r.icon, r.name), 2.0)
    end)
end

-- ═════════════════════════════════════════════════════════════════
-- ── ⚡ Tab 4: Upgrades (Specific Tiers) ──
-- ═════════════════════════════════════════════════════════════════
local UpgradesTab = Window:CreateTab("Upgrades", "⚡")

UpgradesTab:AddSection("⚡ Auto Upgrades Controller")

UpgradesTab:AddToggle("Auto Buy Selected Upgrades", CurrentConfig.AutoUpgrades or false, function(state)
    CurrentConfig.AutoUpgrades = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoUpgrades(CurrentConfig.UpgradesInterval or 3)
        Window.Notify("Auto Upgrades", "Auto Buy Selected Upgrades diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoUpgrades()
        Window.Notify("Auto Upgrades", "Auto Buy Upgrades dinonaktifkan!", 2.0)
    end
end)

UpgradesTab:AddButton("⚡ Buy Selected Affordable Upgrades (1x)", function()
    if AutoFarm then AutoFarm.BuySelectedUpgradesOnce() end
    Window.Notify("Upgrades", "Membeli seluruh upgrade yang dipilih & terjangkau!", 2.0)
end)

UpgradesTab:AddSection("🟢 Tier 1 Upgrades")

local tier1Upgrades = {
    { id = "T1O1", name = "More Cash", stat = "+5% Cash" },
    { id = "T1O2", name = "Extra Luck", stat = "+2.5% Luck" }
}
for _, upg in ipairs(tier1Upgrades) do
    local isChecked = (CurrentConfig.AutoUpgradesSelected and CurrentConfig.AutoUpgradesSelected[upg.id] ~= false)
    UpgradesTab:AddToggle(string.format("[%s] %s (%s)", upg.id, upg.name, upg.stat), isChecked, function(state)
        CurrentConfig.AutoUpgradesSelected[upg.id] = state
        if AutoFarm then AutoFarm.AutoUpgradesSelected[upg.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

UpgradesTab:AddSection("🔵 Tier 2 Upgrades")

local tier2Upgrades = {
    { id = "T2O1", name = "Mutation Chance", stat = "+6.7% Mutations" },
    { id = "T2O2", name = "Better Mutations", stat = "+1% Mutations" },
    { id = "T2O3", name = "Level Discount", stat = "+1% Discount" }
}
for _, upg in ipairs(tier2Upgrades) do
    local isChecked = (CurrentConfig.AutoUpgradesSelected and CurrentConfig.AutoUpgradesSelected[upg.id] ~= false)
    UpgradesTab:AddToggle(string.format("[%s] %s (%s)", upg.id, upg.name, upg.stat), isChecked, function(state)
        CurrentConfig.AutoUpgradesSelected[upg.id] = state
        if AutoFarm then AutoFarm.AutoUpgradesSelected[upg.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

UpgradesTab:AddSection("🟣 Tier 3 Upgrades")

local tier3Upgrades = {
    { id = "T3O1", name = "Offline Earnings", stat = "+1% Earnings" },
    { id = "T3O2", name = "Potion Time", stat = "+1% Time" },
    { id = "T3O3", name = "Faster Catch", stat = "+1.25% Speed" }
}
for _, upg in ipairs(tier3Upgrades) do
    local isChecked = (CurrentConfig.AutoUpgradesSelected and CurrentConfig.AutoUpgradesSelected[upg.id] ~= false)
    UpgradesTab:AddToggle(string.format("[%s] %s (%s)", upg.id, upg.name, upg.stat), isChecked, function(state)
        CurrentConfig.AutoUpgradesSelected[upg.id] = state
        if AutoFarm then AutoFarm.AutoUpgradesSelected[upg.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

UpgradesTab:AddSection("🟡 Tier 4 Upgrades")

local tier4Upgrades = {
    { id = "T4O1", name = "Secret Catch Rate", stat = "+10% Secret Chance" },
    { id = "T4O2", name = "Rainbow Catch Rate", stat = "+10% Rainbow Chance" },
    { id = "T4O3", name = "Ancient Catch Rate", stat = "+5% Ancient Chance" }
}
for _, upg in ipairs(tier4Upgrades) do
    local isChecked = (CurrentConfig.AutoUpgradesSelected and CurrentConfig.AutoUpgradesSelected[upg.id] ~= false)
    UpgradesTab:AddToggle(string.format("[%s] %s (%s)", upg.id, upg.name, upg.stat), isChecked, function(state)
        CurrentConfig.AutoUpgradesSelected[upg.id] = state
        if AutoFarm then AutoFarm.AutoUpgradesSelected[upg.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

UpgradesTab:AddSection("🔴 Tier 5 Upgrades (Godly)")

local tier5Upgrades = {
    { id = "T5O1", name = "God Catch Rate", stat = "+100% God Chance" },
    { id = "T5O2", name = "Omniscient Catch Rate", stat = "+4.75% Omniscient Chance" }
}
for _, upg in ipairs(tier5Upgrades) do
    local isChecked = (CurrentConfig.AutoUpgradesSelected and CurrentConfig.AutoUpgradesSelected[upg.id] ~= false)
    UpgradesTab:AddToggle(string.format("[%s] %s (%s)", upg.id, upg.name, upg.stat), isChecked, function(state)
        CurrentConfig.AutoUpgradesSelected[upg.id] = state
        if AutoFarm then AutoFarm.AutoUpgradesSelected[upg.id] = state end
        if ConfigManager then ConfigManager.Save() end
    end)
end

-- ═════════════════════════════════════════════════════════════════
-- ── 📜 Tab 5: Quests & Rewards ──
-- ═════════════════════════════════════════════════════════════════
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

QuestTab:AddSection("📖 Auto Index Collection Rewards")

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

QuestTab:AddSection("🎁 Free Gifts, Medals & Leave Offers")

QuestTab:AddButton("⚡ Claim All Free Rewards & Medals (1x)", function()
    if AutoFarm then AutoFarm.ClaimAllFreeRewardsOnce() end
    Window.Notify("Free Rewards", "Berhasil men-claim semua reward gratis yang tersedia!", 2.5)
end)

-- ═════════════════════════════════════════════════════════════════
-- ── 🔄 Tab 6: Rebirth (Separated) ──
-- ═════════════════════════════════════════════════════════════════
local RebirthTab = Window:CreateTab("Rebirth", "🔄")

RebirthTab:AddSection("🔄 Auto Rebirth Progression")

RebirthTab:AddToggle("Auto Rebirth (Continuous Progression)", CurrentConfig.AutoRebirth or false, function(state)
    CurrentConfig.AutoRebirth = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoFarm.StartAutoRebirth(CurrentConfig.RebirthInterval or 3)
        Window.Notify("Auto Rebirth", "Auto Rebirth diaktifkan!", 2.0)
    else
        AutoFarm.StopAutoRebirth()
        Window.Notify("Auto Rebirth", "Auto Rebirth dinonaktifkan!", 2.0)
    end
end)

RebirthTab:AddButton("⚡ Rebirth Now (Instant 1x)", function()
    local res = AutoFarm and AutoFarm.RebirthOnce()
    if res then
        Window.Notify("Rebirth", "Berhasil melakukan Rebirth!", 2.5)
    else
        Window.Notify("Rebirth", "Syarat Rebirth belum terpenuhi!", 2.0)
    end
end)

-- ═════════════════════════════════════════════════════════════════
-- ── ⚡ Tab 7: Graphics & FPS Booster ──
-- ═════════════════════════════════════════════════════════════════
local GraphicsTab = Window:CreateTab("Graphics", "⚡")

GraphicsTab:AddSection("🚀 Ultra Performance Mode (All-In-One)")

GraphicsTab:AddToggle("🚀 Ultra Mode (Potato + Hide All + Freeze NPC + Kill VFX)", CurrentConfig.UltraMode or false, function(state)
    CurrentConfig.UltraMode = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if Graphics then Graphics.EnableUltraMode() end
        Window.Notify("Ultra Mode", "Ultra Performance Mode AKTIF!\nPotato + Hide Players + Freeze NPC + Kill VFX", 3.0)
    else
        if Graphics then Graphics.DisableUltraMode() end
        Window.Notify("Ultra Mode", "Ultra Mode dinonaktifkan!", 2.0)
    end
end)

GraphicsTab:AddSection("🥔 Potato Graphics (Material & Shadow Strip)")

GraphicsTab:AddToggle("Potato Graphics (Low Poly + No Shadow)", CurrentConfig.PotatoGraphics or false, function(state)
    CurrentConfig.PotatoGraphics = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if Graphics then Graphics.EnablePotatoGraphics() end
        Window.Notify("Graphics", "Potato Graphics diaktifkan!", 2.5)
    else
        if Graphics then Graphics.DisablePotatoGraphics() end
        Window.Notify("Graphics", "Potato Graphics dinonaktifkan!", 2.0)
    end
end)

GraphicsTab:AddSection("👻 Player & NPC Optimizer")

GraphicsTab:AddToggle("Hide Other Players (Invisible + No Animation)", CurrentConfig.HideOtherPlayers or false, function(state)
    CurrentConfig.HideOtherPlayers = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if Graphics then Graphics.HideOtherPlayers() end
        Window.Notify("Players", "Karakter pemain lain disembunyikan!", 2.5)
    else
        if Graphics then Graphics.ShowOtherPlayers() end
        Window.Notify("Players", "Karakter pemain lain ditampilkan kembali!", 2.0)
    end
end)

GraphicsTab:AddToggle("Freeze NPC & All Animations (CPU Saver)", CurrentConfig.FreezeNPCs or false, function(state)
    CurrentConfig.FreezeNPCs = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if Graphics then Graphics.FreezeAllNPCsAndAnimations() end
        Window.Notify("NPC Freeze", "Semua animasi NPC dibekukan (CPU hemat ~60%)!", 2.5)
    else
        if Graphics then Graphics.UnfreezeNPCs() end
        Window.Notify("NPC Freeze", "NPC Freeze dinonaktifkan!", 2.0)
    end
end)

GraphicsTab:AddToggle("Kill All VFX (Particles, Trails, Beams, Lights)", CurrentConfig.DisableVFX or false, function(state)
    CurrentConfig.DisableVFX = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if Graphics then Graphics.DisableAllVFX() end
        Window.Notify("VFX Kill", "Semua efek visual dinonaktifkan!", 2.5)
    else
        if Graphics then Graphics.EnableAllVFX() end
        Window.Notify("VFX Kill", "Efek visual dikembalikan!", 2.0)
    end
end)

GraphicsTab:AddSection("🖥️ GPU Saver (Black Screen AFK)")

GraphicsTab:AddToggle("3D Rendering Off (Black Screen AFK)", CurrentConfig.BlackScreenAFK or false, function(state)
    CurrentConfig.BlackScreenAFK = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if Graphics then Graphics.EnableScreenOff() end
    else
        if Graphics then Graphics.DisableScreenOff() end
    end
end)

GraphicsTab:AddSection("🎯 FPS Cap Limiter")

local fpsOptions = { 15, 30, 60, 120, 144, 240 }
for _, fps in ipairs(fpsOptions) do
    GraphicsTab:AddButton(string.format("⚡ Set FPS Cap: %d FPS", fps), function()
        CurrentConfig.TargetFPS = fps
        if Graphics then Graphics.SetFPSCap(fps) end
        if ConfigManager then ConfigManager.Save() end
        Window.Notify("FPS Cap", string.format("FPS dibatasi ke: %d FPS", fps), 2.0)
    end)
end

GraphicsTab:AddButton("🚀 Unlock FPS (Unlimited)", function()
    CurrentConfig.TargetFPS = 999
    if Graphics then Graphics.SetFPSCap(999) end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("FPS Cap", "FPS Unlock / Unlimited diaktifkan!", 2.0)
end)

GraphicsTab:AddSection("🧹 RAM & Memory Cleaner")

GraphicsTab:AddButton("🧹 Clean RAM / Memory Now (1x)", function()
    pcall(function()
        if typeof(collectgarbage) == "function" then pcall(collectgarbage, "collect") end
        if typeof(gcinfo) == "function" then gcinfo() end
    end)
    Window.Notify("RAM Cleaner", "Garbage collection selesai!", 2.5)
end)

-- ═════════════════════════════════════════════════════════════════
-- ── ⚙️ Tab 8: Settings (Config Manager & Anti-AFK) ──
-- ═════════════════════════════════════════════════════════════════
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
        if AutoMerchants then
            if CurrentConfig.AutoBuyBoosts then AutoMerchants.StartAutoBuyBoosts() else AutoMerchants.StopAutoBuyBoosts() end
            if CurrentConfig.AutoBuySelene then AutoMerchants.StartAutoBuySelene() else AutoMerchants.StopAutoBuySelene() end
            if CurrentConfig.AutoBuyAngelia then AutoMerchants.StartAutoBuyAngelia() else AutoMerchants.StopAutoBuyAngelia() end
            if CurrentConfig.AutoBuyFishingRods then AutoMerchants.StartAutoBuyFishingRods() else AutoMerchants.StopAutoBuyFishingRods() end
            if CurrentConfig.AutoBuyCarry then AutoMerchants.StartAutoBuyCarry() else AutoMerchants.StopAutoBuyCarry() end
        end
        if CurrentConfig.AutoLevelUpBaseUnits and BaseUnits then BaseUnits.StartAutoLevelUp() else if BaseUnits then BaseUnits.StopAutoLevelUp() end end
        if CurrentConfig.AntiAFK ~= false then AntiAFK.Start() else AntiAFK.Stop() end
    end
    Window.Notify("Config Loaded", "Konfigurasi berhasil dimuat ulang!", 2.5)
end)

SettingsTab:AddButton("🗑️ Reset to Default Settings", function()
    if ConfigManager then ConfigManager.Reset() end
    if AutoFish then AutoFish.StopAll() end
    if AutoFarm then AutoFarm.StopAll() end
    if AutoMerchants then AutoMerchants.StopAll() end
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
if AutoMerchants then
    if CurrentConfig.AutoBuyBoosts then AutoMerchants.StartAutoBuyBoosts() end
    if CurrentConfig.AutoBuySelene then AutoMerchants.StartAutoBuySelene() end
    if CurrentConfig.AutoBuyAngelia then AutoMerchants.StartAutoBuyAngelia() end
    if CurrentConfig.AutoBuyFishingRods then AutoMerchants.StartAutoBuyFishingRods() end
    if CurrentConfig.AutoBuyCarry then AutoMerchants.StartAutoBuyCarry() end
end
if CurrentConfig.AutoLevelUpBaseUnits and BaseUnits then BaseUnits.StartAutoLevelUp() end
if CurrentConfig.AntiAFK ~= false then AntiAFK.Start() end

-- Auto start graphics features
if Graphics then
    if CurrentConfig.UltraMode then
        Graphics.EnableUltraMode()
    else
        if CurrentConfig.PotatoGraphics then Graphics.EnablePotatoGraphics() end
        if CurrentConfig.HideOtherPlayers then Graphics.HideOtherPlayers() end
        if CurrentConfig.FreezeNPCs then Graphics.FreezeAllNPCsAndAnimations() end
        if CurrentConfig.DisableVFX then Graphics.DisableAllVFX() end
    end
    if CurrentConfig.BlackScreenAFK then Graphics.EnableScreenOff() end
    if CurrentConfig.TargetFPS then Graphics.SetFPSCap(CurrentConfig.TargetFPS) end
end

-- Destructor
_G.RitodHubFishAnAnime = Window.ScreenGui
_G.RitodHubCleanup = function()
    pcall(function()
        if AutoFish and AutoFish.StopAll then AutoFish.StopAll() end
        if AutoFarm and AutoFarm.StopAll then AutoFarm.StopAll() end
        if AutoMerchants and AutoMerchants.StopAll then AutoMerchants.StopAll() end
        if BaseUnits and BaseUnits.StopAutoLevelUp then BaseUnits.StopAutoLevelUp() end
        if Graphics and Graphics.Unload then Graphics.Unload() end
        if AntiAFK and AntiAFK.Stop then AntiAFK.Stop() end
        if Window.ScreenGui and Window.ScreenGui.Parent then Window.ScreenGui:Destroy() end
    end)
end

Window.Notify("⚡RITOD HUB⚡", "Fish an Anime RNG Loaded Successfully!", 3.5)
return Window
