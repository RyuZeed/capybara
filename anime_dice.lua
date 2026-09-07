--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (SMART MODULAR EDITION)
	Game: [🎉UPD 3] Anime Dice
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🧩 MODULE DIRECTORY: modules/anime_dice/
	  - auto_roll.lua (Instant Server Roll & Native Auto Roll Toggle)
	  - auto_plot.lua (Collect Cash, Equip Best, Upgrade Slots 1-8)
	  - auto_dice.lua (Dynamic Dice List, Auto Buy & Equip)
	  - auto_rewards.lua (Daily, Group, Quests, Offline & Rebirth)
	  - auto_sell.lua (Auto Sell Inventory & Threshold Setter)
	  - teleports.lua (Plot Spawn & All 10 Game Zones)
	  - anti_afk.lua (Bulletproof 24/7 Keepalive & Reconnect Daemon)
	  - config_manager.lua (Persistent Profile Config JSON)
	- 🛡️ 100% SMART & SILENT OPERATION
	- 🖥️ MODERN RITOD UI (700x470) with Minimize Floating Widget
	===============================================================
]]

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.3)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- =================================================================
-- 🛡️ 1. CLIENT ANTI-KICK HOOK (METATABLE BYPASS)
-- =================================================================
pcall(function()
    if typeof(hookmetamethod) == "function" and not _G.RitodAntiKickHooked then
        _G.RitodAntiKickHooked = true
        local oldKick
        oldKick = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if (method == "Kick" or method == "kick") and self == LocalPlayer then
                warn("🛡️ [Ritod Anti-Kick] Memblokir upaya Kick dari Game Anti-Cheat: ", args[1] or "Unknown")
                return nil
            end
            return oldKick(self, ...)
        end)
    end
end)

-- =================================================================
-- 🛡️ 2. CLEANUP PREVIOUS SESSIONS
-- =================================================================
pcall(function()
    if typeof(_G.RitodHubCleanup) == "function" then _G.RitodHubCleanup() end
    if _G.AnimeDiceAutoRoll and typeof(_G.AnimeDiceAutoRoll.StopAll) == "function" then
        _G.AnimeDiceAutoRoll.StopAll()
    end
    if _G.AnimeDiceAutoPlot and typeof(_G.AnimeDiceAutoPlot.StopAll) == "function" then
        _G.AnimeDiceAutoPlot.StopAll()
    end
    if _G.AnimeDiceAutoDice and typeof(_G.AnimeDiceAutoDice.StopAll) == "function" then
        _G.AnimeDiceAutoDice.StopAll()
    end
    if _G.AnimeDiceAutoRewards and typeof(_G.AnimeDiceAutoRewards.StopAll) == "function" then
        _G.AnimeDiceAutoRewards.StopAll()
    end
    if _G.AnimeDiceAutoSell and typeof(_G.AnimeDiceAutoSell.StopAll) == "function" then
        _G.AnimeDiceAutoSell.StopAll()
    end
    if _G.AnimeDiceAntiAFK and typeof(_G.AnimeDiceAntiAFK.Stop) == "function" then
        _G.AnimeDiceAntiAFK.Stop()
    end
    if _G.RitodHubAnimeDice and typeof(_G.RitodHubAnimeDice) == "Instance" then
        pcall(function() _G.RitodHubAnimeDice:Destroy() end)
    end
end)

-- =================================================================
-- 🌐 3. MODULAR LOADER (LOCAL FILE & GITHUB FALLBACK)
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/anime_dice/"
local SHARED_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/"

local function loadModule(name, isShared)
    -- 1. Try local file first (instant development)
    local localPath = (isShared and "modules/shared/" or "modules/anime_dice/") .. name .. ".lua"
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(localPath) then
        local content = readfile(localPath)
        if content and #content > 10 then
            local fn = loadstring(content)
            if fn then return fn() end
        end
    end

    -- 2. Fallback to GitHub raw
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

    return nil
end

local RitodUI = loadModule("ritod_ui", true)
local ConfigManager = loadModule("config_manager", false)
local AutoRoll = loadModule("auto_roll", false)
local AutoPlot = loadModule("auto_plot", false)
local AutoDice = loadModule("auto_dice", false)
local AutoRewards = loadModule("auto_rewards", false)
local AutoSell = loadModule("auto_sell", false)
local Teleports = loadModule("teleports", false)
local AntiAFK = loadModule("anti_afk", false)

-- Fallback to global singletons if loaded previously
if not ConfigManager and _G.AnimeDiceConfigManager then ConfigManager = _G.AnimeDiceConfigManager end
if not AutoRoll and _G.AnimeDiceAutoRoll then AutoRoll = _G.AnimeDiceAutoRoll end
if not AutoPlot and _G.AnimeDiceAutoPlot then AutoPlot = _G.AnimeDiceAutoPlot end
if not AutoDice and _G.AnimeDiceAutoDice then AutoDice = _G.AnimeDiceAutoDice end
if not AutoRewards and _G.AnimeDiceAutoRewards then AutoRewards = _G.AnimeDiceAutoRewards end
if not AutoSell and _G.AnimeDiceAutoSell then AutoSell = _G.AnimeDiceAutoSell end
if not Teleports and _G.AnimeDiceTeleports then Teleports = _G.AnimeDiceTeleports end
if not AntiAFK and _G.AnimeDiceAntiAFK then AntiAFK = _G.AnimeDiceAntiAFK end

local CurrentConfig = ConfigManager and ConfigManager.CurrentConfig or {}

-- =================================================================
-- 🖥️ 4. GUI INTERFACE (RitodUI)
-- =================================================================
local Window = RitodUI:CreateWindow({
    Title = "⚡RITOD HUB⚡",
    GameName = "Anime Dice",
    Size = Vector2.new(700, 470),
    OnUnload = function()
        if AutoRoll and AutoRoll.StopAll then AutoRoll.StopAll() end
        if AutoPlot and AutoPlot.StopAll then AutoPlot.StopAll() end
        if AutoDice and AutoDice.StopAll then AutoDice.StopAll() end
        if AutoRewards and AutoRewards.StopAll then AutoRewards.StopAll() end
        if AutoSell and AutoSell.StopAll then AutoSell.StopAll() end
        if AntiAFK and AntiAFK.Stop then AntiAFK.Stop() end
    end
})

-- ── Tab 1: 🎲 Roll & Dice ──
local RollTab = Window:CreateTab("Roll & Dice", "🎲")

RollTab:AddSection("🎲 Fast Server Auto Roll")

RollTab:AddToggle("Auto Roll Dice (Fast Loop)", CurrentConfig.AutoRoll or false, function(state)
    CurrentConfig.AutoRoll = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoRoll.Start(CurrentConfig.RollDelay or 0.1)
        Window.Notify("Auto Roll", "Status: AKTIF (Fast Server Loop)", 2.5)
    else
        AutoRoll.Stop()
        Window.Notify("Auto Roll", "Status: NONAKTIF", 2.0)
    end
end)

RollTab:AddSlider("Roll Delay", 0.05, 1.0, CurrentConfig.RollDelay or 0.1, function(val)
    CurrentConfig.RollDelay = val
    if ConfigManager then ConfigManager.Save() end
end)

RollTab:AddButton("⚡ Roll Dice Once (Instant 1x)", function()
    local ok, err = AutoRoll.RollOnce()
    if ok then
        Window.Notify("Roll Dice", "Berhasil melempar dadu!", 2.0)
    else
        Window.Notify("Roll Dice", "Gagal: " .. tostring(err), 2.5)
    end
end)

RollTab:AddSection("🎮 Game Native Auto Roll")

RollTab:AddToggle("In-Game Native Auto Roll", CurrentConfig.InGameAutoRoll or false, function(state)
    CurrentConfig.InGameAutoRoll = state
    if ConfigManager then ConfigManager.Save() end
    AutoRoll.SetInGameAutoRoll(state)
    Window.Notify("In-Game Auto Roll", state and "Diaktifkan" or "Dinonaktifkan", 2.0)
end)

RollTab:AddSection("🛒 Dice Shop & Equip")

local diceList = (AutoDice and AutoDice.DiceList) or {
    "Basic", "Normal", "Fire", "Water", "Nature", "Lightning", "Ice", "Magma",
    "Storm", "Shadow", "Light", "Blood Moon", "Void", "Solar", "Lunar", "Galaxy",
    "Black Hole", "Dragon", "Royal", "Prismatic", "Arcane", "Corrupted", "Titan", "Chrono"
}

RollTab:AddDropdown("Select Target Dice", diceList, CurrentConfig.SelectedDice or "Lightning", function(selected)
    CurrentConfig.SelectedDice = selected
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Dice Dipilih", selected, 2.0)
end)

RollTab:AddToggle("Auto Equip Selected Dice", CurrentConfig.AutoEquipSelectedDice or false, function(state)
    CurrentConfig.AutoEquipSelectedDice = state
    if ConfigManager then ConfigManager.Save() end
    if state and AutoDice then AutoDice.Start() end
    Window.Notify("Auto Equip Dice", state and "Aktif" or "Nonaktif", 2.0)
end)

RollTab:AddToggle("Auto Buy Selected Dice", CurrentConfig.AutoBuySelectedDice or false, function(state)
    CurrentConfig.AutoBuySelectedDice = state
    if ConfigManager then ConfigManager.Save() end
    if state and AutoDice then AutoDice.Start() end
    Window.Notify("Auto Buy Dice", state and "Aktif" or "Nonaktif", 2.0)
end)

RollTab:AddButton("Equip Selected Dice Now", function()
    local target = CurrentConfig.SelectedDice or "Lightning"
    if AutoDice then
        AutoDice.EquipDice(target)
        Window.Notify("Equip Dice", "Mencoba equip: " .. target, 2.0)
    end
end)

RollTab:AddButton("Buy Selected Dice Now", function()
    local target = CurrentConfig.SelectedDice or "Lightning"
    if AutoDice then
        AutoDice.BuyDice(target)
        Window.Notify("Buy Dice", "Mencoba membeli: " .. target, 2.0)
    end
end)

-- ── Tab 2: 🏰 Plot & Farm ──
local PlotTab = Window:CreateTab("Plot & Farm", "🏰")

PlotTab:AddSection("💰 Passive Plot Income")

PlotTab:AddToggle("Auto Collect Cash / Balance", CurrentConfig.AutoCollectCash ~= false, function(state)
    CurrentConfig.AutoCollectCash = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Auto Collect Cash", state and "Aktif" or "Nonaktif", 2.0)
end)

PlotTab:AddButton("⚡ Collect Cash Once", function()
    if AutoPlot then
        AutoPlot.CollectBalanceOnce()
        Window.Notify("Collect Cash", "Berhasil mengambil passive cash!", 2.0)
    end
end)

PlotTab:AddSection("⚔️ Best Units & Slot Upgrades")

PlotTab:AddToggle("Auto Equip Best Units", CurrentConfig.AutoEquipBest ~= false, function(state)
    CurrentConfig.AutoEquipBest = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Auto Equip Best", state and "Aktif" or "Nonaktif", 2.0)
end)

PlotTab:AddButton("⚡ Equip Best Units Once", function()
    if AutoPlot then
        AutoPlot.EquipBestOnce()
        Window.Notify("Equip Best", "Equipped best units ke plot!", 2.0)
    end
end)

PlotTab:AddToggle("Auto Upgrade All Slots (1-8)", CurrentConfig.AutoUpgradeSlots or false, function(state)
    CurrentConfig.AutoUpgradeSlots = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Auto Upgrade Slots", state and "Aktif" or "Nonaktif", 2.0)
end)

PlotTab:AddButton("⚡ Upgrade All Slots Once (1-8)", function()
    if AutoPlot then
        local count = AutoPlot.UpgradeAllSlotsOnce()
        Window.Notify("Upgrade Slots", string.format("Diproses %d slot!", count), 2.5)
    end
end)

PlotTab:AddSection("🗑️ Auto Sell")

PlotTab:AddToggle("Auto Sell Inventory", CurrentConfig.AutoSellInventory or false, function(state)
    CurrentConfig.AutoSellInventory = state
    if ConfigManager then ConfigManager.Save() end
    if state and AutoSell then AutoSell.Start() elseif AutoSell then AutoSell.Stop() end
    Window.Notify("Auto Sell Inventory", state and "Aktif (Tiap 5s)" or "Nonaktif", 2.0)
end)

PlotTab:AddButton("⚡ Sell Inventory Once", function()
    if AutoSell then
        local ok, count = AutoSell.SellInventoryOnce()
        Window.Notify("Sell Inventory", ok and ("Berhasil menjual: " .. tostring(count)) or "Gagal menjual", 2.0)
    end
end)

-- ── Tab 3: 🎁 Rewards & Rebirth ──
local RewardsTab = Window:CreateTab("Rewards", "🎁")

RewardsTab:AddSection("🎁 Automatic Rewards Claimer")

RewardsTab:AddToggle("Auto Claim Daily Rewards", CurrentConfig.AutoClaimDaily ~= false, function(state)
    CurrentConfig.AutoClaimDaily = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Daily Rewards", state and "Aktif" or "Nonaktif", 2.0)
end)

RewardsTab:AddToggle("Auto Claim Group Rewards", CurrentConfig.AutoClaimGroup ~= false, function(state)
    CurrentConfig.AutoClaimGroup = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Group Rewards", state and "Aktif" or "Nonaktif", 2.0)
end)

RewardsTab:AddToggle("Auto Claim Quests", CurrentConfig.AutoClaimQuests ~= false, function(state)
    CurrentConfig.AutoClaimQuests = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Auto Claim Quests", state and "Aktif" or "Nonaktif", 2.0)
end)

RewardsTab:AddToggle("Auto Claim Offline Earnings", CurrentConfig.AutoClaimOffline ~= false, function(state)
    CurrentConfig.AutoClaimOffline = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Offline Earnings", state and "Aktif" or "Nonaktif", 2.0)
end)

RewardsTab:AddButton("⚡ Claim All Rewards & Quests Once", function()
    if AutoRewards then
        AutoRewards.ClaimAllOnce()
        Window.Notify("Rewards", "Mengklaim semua reward & quest!", 2.5)
    end
end)

RewardsTab:AddSection("🔄 Rebirth System")

RewardsTab:AddToggle("Auto Rebirth (When Ready)", CurrentConfig.AutoRebirth or false, function(state)
    CurrentConfig.AutoRebirth = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Auto Rebirth", state and "Aktif" or "Nonaktif", 2.0)
end)

RewardsTab:AddButton("⚡ Rebirth Now (1x)", function()
    if AutoRewards then
        AutoRewards.RebirthOnce()
        Window.Notify("Rebirth", "Mencoba Rebirth!", 2.0)
    end
end)

-- ── Tab 4: 🚀 Teleport ──
local TeleportTab = Window:CreateTab("Teleport", "🚀")

TeleportTab:AddSection("🏠 Base Teleport")

TeleportTab:AddButton("🏠 Teleport to My Plot Spawn", function()
    if Teleports then
        local ok, err = Teleports.TeleportToPlot()
        if ok then
            Window.Notify("Teleport", "Berhasil teleport ke Plot!", 2.0)
        else
            Window.Notify("Teleport Gagal", tostring(err), 2.5)
        end
    end
end)

TeleportTab:AddSection("🗺️ Map Zones")

local zoneButtons = {
    {"Dice Shop", "🎲 Teleport to Dice Shop"},
    {"Selling", "💰 Teleport to Selling Zone"},
    {"Towers", "🗼 Teleport to Towers"},
    {"Quests", "📜 Teleport to Quests"},
    {"Traits", "✨ Teleport to Traits"},
    {"Grades", "⭐ Teleport to Grades"},
    {"Shop", "🛒 Teleport to Shop"},
    {"Trade", "🤝 Teleport to Trade"},
    {"Hub Area", "🌟 Teleport to Hub Area"}
}

for _, item in ipairs(zoneButtons) do
    local zoneKey = item[1]
    local btnLabel = item[2]
    TeleportTab:AddButton(btnLabel, function()
        if Teleports then
            local ok, err = Teleports.TeleportToZone(zoneKey)
            if ok then
                Window.Notify("Teleport", "Menuju ke " .. zoneKey, 2.0)
            else
                Window.Notify("Teleport Gagal", tostring(err), 2.5)
            end
        end
    end)
end

-- ── Tab 5: ⚙️ Settings ──
local SettingsTab = Window:CreateTab("Settings", "⚙️")

SettingsTab:AddSection("🛡️ Protection & Anti-AFK")

SettingsTab:AddToggle("Anti-AFK (24/7 Keep Alive)", CurrentConfig.AntiAFK ~= false, function(state)
    CurrentConfig.AntiAFK = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AntiAFK then AntiAFK.Start() end
        Window.Notify("Anti-AFK", "Anti-AFK 24/7 diaktifkan!", 2.0)
    else
        if AntiAFK then AntiAFK.Stop() end
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
        if AutoRoll then
            if CurrentConfig.AutoRoll then AutoRoll.Start(CurrentConfig.RollDelay or 0.1) else AutoRoll.Stop() end
        end
        if AutoSell then
            if CurrentConfig.AutoSellInventory then AutoSell.Start() else AutoSell.Stop() end
        end
        if AntiAFK then
            if CurrentConfig.AntiAFK ~= false then AntiAFK.Start() else AntiAFK.Stop() end
        end
    end
    Window.Notify("Config Loaded", "Konfigurasi berhasil dimuat ulang!", 2.5)
end)

SettingsTab:AddButton("🗑️ Reset to Default Settings", function()
    if ConfigManager then ConfigManager.Reset() end
    if AutoRoll then AutoRoll.StopAll() end
    if AutoPlot then AutoPlot.StopAll() end
    if AutoDice then AutoDice.StopAll() end
    if AutoRewards then AutoRewards.StopAll() end
    if AutoSell then AutoSell.StopAll() end
    Window.Notify("Config Reset", "Pengaturan dikembalikan ke default!", 2.5)
end)

SettingsTab:AddSection("🚪 Utilities")

SettingsTab:AddButton("🔄 Rejoin Server", function()
    local ts = game:GetService("TeleportService")
    ts:Teleport(game.PlaceId, LocalPlayer)
end)

-- =================================================================
-- 🚀 AUTO START WORKERS BASED ON SAVED CONFIG
-- =================================================================
if AutoPlot then AutoPlot.Start() end
if AutoRewards then AutoRewards.Start() end
if AutoDice and (CurrentConfig.AutoBuySelectedDice or CurrentConfig.AutoEquipSelectedDice) then
    AutoDice.Start()
end
if CurrentConfig.AutoRoll and AutoRoll then
    AutoRoll.Start(CurrentConfig.RollDelay or 0.1)
end
if CurrentConfig.InGameAutoRoll and AutoRoll then
    AutoRoll.SetInGameAutoRoll(true)
end
if CurrentConfig.AutoSellInventory and AutoSell then
    AutoSell.Start()
end
if CurrentConfig.AntiAFK ~= false and AntiAFK then
    AntiAFK.Start()
end

-- Register globals and cleanup hook
_G.RitodHubAnimeDice = Window.ScreenGui
_G.RitodHubCleanup = function()
    pcall(function()
        if AutoRoll then AutoRoll.StopAll() end
        if AutoPlot then AutoPlot.StopAll() end
        if AutoDice then AutoDice.StopAll() end
        if AutoRewards then AutoRewards.StopAll() end
        if AutoSell then AutoSell.StopAll() end
        if AntiAFK then AntiAFK.Stop() end
        if Window.ScreenGui and Window.ScreenGui.Parent then
            Window.ScreenGui:Destroy()
        end
    end)
end

Window.Notify("⚡RITOD HUB⚡", "Anime Dice Smart Modular Edition Loaded!", 3.5)
return Window
