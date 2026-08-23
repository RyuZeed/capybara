--[[
	===============================================================
	⚡ RITOD HUB - GROW A CHICKEN FIGHTER (MODULAR EDITION)
	Game: Grow a Chicken Fighter
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🧩 MODULE DIRECTORY: modules/chicken_fighter/
	  - auto_egg.lua
	  - anti_afk.lua
	  - config_manager.lua
	- 📁 PERSISTENT CONFIG: RitodHub/GrowAChickenFighter/config.json
	- 🛡️ BULLETPROOF ANTI-AFK & BAC-8511 BYPASS
	- 🖥️ MODERN RITOD UI (680x440) with Minimize Floating Widget
	===============================================================
]]

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.3)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- =================================================================
-- 🛡️ 1. CLIENT ANTI-KICK HOOK (BAC-8511 BYPASS)
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
    if _G.ChickenFighterAutoEgg and typeof(_G.ChickenFighterAutoEgg.StopAll) == "function" then
        _G.ChickenFighterAutoEgg.StopAll()
    end
    if _G.ChickenFighterAntiAFK and typeof(_G.ChickenFighterAntiAFK.Stop) == "function" then
        _G.ChickenFighterAntiAFK.Stop()
    end
    if _G.RitodHubChickenFighter and typeof(_G.RitodHubChickenFighter) == "Instance" then
        pcall(function() _G.RitodHubChickenFighter:Destroy() end)
    end
end)

-- =================================================================
-- 🌐 3. MODULAR LOADER (LOCAL & GITHUB SUPPORT)
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/chicken_fighter/"
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

    -- Fallback lokal jika ada file di executor
    local localPath = (isShared and "modules/shared/" or "modules/chicken_fighter/") .. name .. ".lua"
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(localPath) then
        local fn = loadstring(readfile(localPath))
        if fn then return fn() end
    end
    return nil
end

local RitodUI = loadModule("ritod_ui", true)
local AutoEgg = loadModule("auto_egg", false)
local AntiAFK = loadModule("anti_afk", false)
local ConfigManager = loadModule("config_manager", false)

-- Safety fallback jika koneksi github belum siap
if not AutoEgg and _G.ChickenFighterAutoEgg then AutoEgg = _G.ChickenFighterAutoEgg end
if not AntiAFK and _G.ChickenFighterAntiAFK then AntiAFK = _G.ChickenFighterAntiAFK end
if not ConfigManager and _G.ChickenFighterConfigManager then ConfigManager = _G.ChickenFighterConfigManager end

local CurrentConfig = ConfigManager and ConfigManager.CurrentConfig or {}

-- =================================================================
-- 🖥️ 4. GUI INTERFACE (RitodUI)
-- =================================================================
local Window = RitodUI:CreateWindow({
    Title = "⚡RITOD HUB⚡",
    GameName = "Grow a Chicken Fighter",
    Size = Vector2.new(680, 440),
    OnUnload = function()
        if AutoEgg and AutoEgg.StopAll then AutoEgg.StopAll() end
        if AntiAFK and AntiAFK.Stop then AntiAFK.Stop() end
    end
})

-- ── Tab 1: 🥚 Egg & Incubator ──
local MainTab = Window:CreateTab("Egg & Incubator", "🥚")

MainTab:AddSection("🥚 Auto Collect Eggs (Anti-BAC)")

MainTab:AddToggle("Auto Collect Eggs", CurrentConfig.AutoCollectEgg or false, function(state)
    CurrentConfig.AutoCollectEgg = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoEgg.StartAutoCollectEgg(CurrentConfig.EggInterval)
        Window.Notify("Auto Collect Egg", "Status: AKTIF (Safe Proximity Mode)", 2.5)
    else
        AutoEgg.StopAutoCollectEgg()
        Window.Notify("Auto Collect Egg", "Status: NONAKTIF", 2.0)
    end
end)

MainTab:AddSlider("Collect Delay (Detik)", 0.5, 3.0, CurrentConfig.EggInterval or 0.8, function(val)
    CurrentConfig.EggInterval = tonumber(string.format("%.1f", val))
    AutoEgg.EggInterval = CurrentConfig.EggInterval
    if ConfigManager then ConfigManager.Save() end
end)

MainTab:AddButton("⚡ Collect All Eggs Once (Instant 1x)", function()
    local count = AutoEgg.CollectAllEggsOnce()
    Window.Notify("Collect Telur", string.format("Berhasil mengambil %d telur!", count), 2.5)
end)

MainTab:AddSection("🐣 Auto Claim Incubator")

MainTab:AddToggle("Auto Claim Incubators (Slots 1-7)", CurrentConfig.AutoClaimIncubator or false, function(state)
    CurrentConfig.AutoClaimIncubator = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        AutoEgg.StartAutoClaimIncubator(CurrentConfig.IncubatorInterval, CurrentConfig.MaxIncubatorSlots)
        Window.Notify("Auto Incubator", "Status: AKTIF (Safe Interval)", 2.5)
    else
        AutoEgg.StopAutoClaimIncubator()
        Window.Notify("Auto Incubator", "Status: NONAKTIF", 2.0)
    end
end)

MainTab:AddSlider("Cycle Delay (Detik)", 1.0, 5.0, CurrentConfig.IncubatorInterval or 2.0, function(val)
    CurrentConfig.IncubatorInterval = tonumber(string.format("%.1f", val))
    AutoEgg.IncubatorInterval = CurrentConfig.IncubatorInterval
    if ConfigManager then ConfigManager.Save() end
end)

MainTab:AddSlider("Max Incubator Slots", 1, 10, CurrentConfig.MaxIncubatorSlots or 7, function(val)
    CurrentConfig.MaxIncubatorSlots = math.floor(val)
    AutoEgg.MaxIncubatorSlots = CurrentConfig.MaxIncubatorSlots
    if ConfigManager then ConfigManager.Save() end
end)

MainTab:AddButton("⚡ Claim All Incubators Once (Instant 1x)", function()
    local count = AutoEgg.ClaimAllIncubatorsOnce(CurrentConfig.MaxIncubatorSlots)
    Window.Notify("Claim Incubator", string.format("Claim dikirim ke %d slot!", count), 2.5)
end)

-- ── Tab 2: ⚙️ Settings (Config Manager & Anti-AFK) ──
local SettingsTab = Window:CreateTab("Settings", "⚙️")

SettingsTab:AddSection("🛡️ Protection & Anti-AFK")

SettingsTab:AddToggle("Anti-AFK (Keep Alive)", CurrentConfig.AntiAFK ~= false, function(state)
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
        if CurrentConfig.AutoCollectEgg then AutoEgg.StartAutoCollectEgg() else AutoEgg.StopAutoCollectEgg() end
        if CurrentConfig.AutoClaimIncubator then AutoEgg.StartAutoClaimIncubator() else AutoEgg.StopAutoClaimIncubator() end
        if CurrentConfig.AntiAFK then AntiAFK.Start() else AntiAFK.Stop() end
    end
    Window.Notify("Config Loaded", "Konfigurasi berhasil dimuat ulang!", 2.5)
end)

SettingsTab:AddButton("🗑️ Reset to Default Settings", function()
    if ConfigManager then ConfigManager.Reset() end
    AutoEgg.StopAll()
    Window.Notify("Config Reset", "Pengaturan dikembalikan ke default!", 2.5)
end)

SettingsTab:AddSection("🚪 Utilities")

SettingsTab:AddButton("🔄 Rejoin Server", function()
    local ts = game:GetService("TeleportService")
    ts:Teleport(game.PlaceId, LocalPlayer)
end)

-- Auto start dari saved config jika sebelumnya aktif
if CurrentConfig.AutoCollectEgg then AutoEgg.StartAutoCollectEgg() end
if CurrentConfig.AutoClaimIncubator then AutoEgg.StartAutoClaimIncubator() end
if CurrentConfig.AntiAFK ~= false then AntiAFK.Start() end

-- Destructor
_G.RitodHubChickenFighter = Window.ScreenGui
_G.RitodHubCleanup = function()
    pcall(function()
        AutoEgg.StopAll()
        AntiAFK.Stop()
        if Window.ScreenGui and Window.ScreenGui.Parent then Window.ScreenGui:Destroy() end
    end)
end

Window.Notify("⚡RITOD HUB⚡", "Grow a Chicken Fighter Ready!", 3.5)
return Window
