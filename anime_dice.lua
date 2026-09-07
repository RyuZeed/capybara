--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (VERIFIED CLEAN EDITION)
	Game: [🎉UPD 3] Anime Dice
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🧩 MODULES:
	  - auto_roll.lua (Native Auto Roll & Fast Server Roll)
	  - auto_plot.lua (Collect Cash, Equip Best, Upgrade Slots 1-8)
	  - auto_rewards.lua (Daily, Group, Offline Earnings, Rebirth)
	  - teleports.lua (Teleport to Player Plot)
	  - anti_afk.lua (Bulletproof 24/7 Keepalive & Shiftlock Guard)
	  - config_manager.lua (Persistent Profile Config JSON)
	- 🛡️ 100% VERIFIED IN-GAME FEATURES ONLY
	- 🖥️ MODERN RITOD UI (700x470)
	===============================================================
]]

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.3)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer or (function()
    local t = tick()
    while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end
    return Players.LocalPlayer
end)()

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
                warn("🛡️ [Ritod Anti-Kick] Memblokir upaya Kick: ", args[1] or "Unknown")
                return nil
            end
            return oldKick(self, ...)
        end)
    end
end)

-- =================================================================
-- 🛡️ 2. CLEANUP PREVIOUS SESSIONS & AUTORELEASE SHIFTLOCK
-- =================================================================
pcall(function()
    if typeof(_G.RitodHubCleanup) == "function" then _G.RitodHubCleanup() end
    if _G.AnimeDiceAutoRoll and typeof(_G.AnimeDiceAutoRoll.StopAll) == "function" then
        _G.AnimeDiceAutoRoll.StopAll()
    end
    if _G.AnimeDiceAutoPlot and typeof(_G.AnimeDiceAutoPlot.StopAll) == "function" then
        _G.AnimeDiceAutoPlot.StopAll()
    end
    if _G.AnimeDiceAutoRewards and typeof(_G.AnimeDiceAutoRewards.StopAll) == "function" then
        _G.AnimeDiceAutoRewards.StopAll()
    end
    if _G.AnimeDiceAntiAFK and typeof(_G.AnimeDiceAntiAFK.Stop) == "function" then
        _G.AnimeDiceAntiAFK.Stop()
    end
    if _G.RitodHubAnimeDice and typeof(_G.RitodHubAnimeDice) == "Instance" then
        pcall(function() _G.RitodHubAnimeDice:Destroy() end)
    end

    -- 🔓 Lepaskan Shift Lock game bawaan agar kursor bebas
    local rs = game:GetService("ReplicatedStorage")
    local slMod = rs:FindFirstChild("Framework")
        and rs.Framework:FindFirstChild("Features")
        and rs.Framework.Features:FindFirstChild("Player")
        and rs.Framework.Features.Player:FindFirstChild("ShiftlockController")
    if slMod then
        local sl = require(slMod)
        if sl and sl.Enabled then
            sl:ToggleShiftLock(false)
        end
    end
    game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default
end)

-- =================================================================
-- 🌐 3. MODULAR LOADER (LOCAL FILE & GITHUB FALLBACK)
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/anime_dice/"
local SHARED_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/"

local function loadModule(name, isShared)
    local localPath = (isShared and "modules/shared/" or "modules/anime_dice/") .. name .. ".lua"
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(localPath) then
        local content = readfile(localPath)
        if content and #content > 10 then
            local fn = loadstring(content)
            if fn then return fn() end
        end
    end

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

local RitodUI = loadModule("ritod_ui", true) or _G.RitodUI
local ConfigManager = loadModule("config_manager", false) or _G.AnimeDiceConfigManager
local AutoRoll = loadModule("auto_roll", false) or _G.AnimeDiceAutoRoll
local AutoPlot = loadModule("auto_plot", false) or _G.AnimeDiceAutoPlot
local AutoRewards = loadModule("auto_rewards", false) or _G.AnimeDiceAutoRewards
local Teleports = loadModule("teleports", false) or _G.AnimeDiceTeleports
local AntiAFK = loadModule("anti_afk", false) or _G.AnimeDiceAntiAFK

local CurrentConfig = ConfigManager and ConfigManager.CurrentConfig or {
    NativeAutoRoll = false,
    FastRoll = false,
    RollDelay = 0.1,
    AutoCollectCash = true,
    AutoEquipBest = true,
    AutoUpgradeSlots = false,
    AutoClaimDaily = true,
    AutoClaimGroup = true,
    AutoClaimOffline = true,
    AutoRebirth = false,
    AntiAFK = true
}

-- =================================================================
-- 🖥️ 4. BUILD MODERN RITOD UI (700 x 470)
-- =================================================================
local Window = RitodUI:CreateWindow({
    Title = "⚡RITOD HUB⚡",
    GameName = "Anime Dice [UPD 3]",
    Size = Vector2.new(700, 470),
    OnUnload = function()
        if AutoRoll then AutoRoll.StopAll() end
        if AutoPlot then AutoPlot.StopAll() end
        if AutoRewards then AutoRewards.StopAll() end
        if AntiAFK then AntiAFK.Stop() end
        print("[RITOD HUB] All Anime Dice routines terminated.")
    end
})

_G.RitodHubCleanup = function()
    if Window and typeof(Window.Destroy) == "function" then
        Window:Destroy()
    end
end

-- ─── TAB 1: 🎲 AUTO ROLL & FARM ──────────────────────────────────
local FarmTab = Window:CreateTab("Auto Farm", "🎲")

FarmTab:AddSection("🎲 Roll System (Official & Fast)")

FarmTab:AddToggle("In-Game Native Auto Roll", CurrentConfig.NativeAutoRoll or false, function(state)
    CurrentConfig.NativeAutoRoll = state
    if ConfigManager then ConfigManager.Save() end
    if AutoRoll then AutoRoll.SetNativeAutoRoll(state) end
    Window.Notify("Native Auto Roll", state and "Auto Roll resmi diaktifkan!" or "Auto Roll dimatikan.", 2.0)
end)

FarmTab:AddToggle("⚡ Fast Server Roll (Instant)", CurrentConfig.FastRoll or false, function(state)
    CurrentConfig.FastRoll = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoRoll then AutoRoll.Start(CurrentConfig.RollDelay or 0.1) end
        Window.Notify("Fast Roll", "Fast Server Roll dimulai!", 2.0)
    else
        if AutoRoll then AutoRoll.Stop() end
        Window.Notify("Fast Roll", "Fast Roll dimatikan.", 2.0)
    end
end)

FarmTab:AddSlider("Roll Delay (Detik)", 0.05, 1.0, CurrentConfig.RollDelay or 0.1, function(val)
    CurrentConfig.RollDelay = val
    if ConfigManager then ConfigManager.Save() end
    if AutoRoll and AutoRoll.IsRolling then
        AutoRoll.Stop()
        AutoRoll.Start(val)
    end
end)

FarmTab:AddButton("🎲 Roll Sekali (Manual)", function()
    if AutoRoll then
        local ok = AutoRoll.RollOnce()
        Window.Notify("Roll", ok and "Berhasil melempar dadu!" or "Gagal melempar dadu.", 1.5)
    end
end)

FarmTab:AddSection("🏰 Plot & Unit Automation")

FarmTab:AddToggle("Auto Collect Cash (Plot)", CurrentConfig.AutoCollectCash ~= false, function(state)
    CurrentConfig.AutoCollectCash = state
    if AutoPlot then AutoPlot.CollectCash = state end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Collect Cash", state and "Auto Collect Cash aktif" or "Auto Collect Cash mati", 1.8)
end)

FarmTab:AddToggle("Auto Equip Best Units", CurrentConfig.AutoEquipBest ~= false, function(state)
    CurrentConfig.AutoEquipBest = state
    if AutoPlot then AutoPlot.EquipBest = state end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Equip Best", state and "Auto Equip Best aktif" or "Auto Equip Best mati", 1.8)
end)

FarmTab:AddToggle("Auto Upgrade Slots (1-8)", CurrentConfig.AutoUpgradeSlots or false, function(state)
    CurrentConfig.AutoUpgradeSlots = state
    if AutoPlot then AutoPlot.UpgradeSlots = state end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Upgrade Slots", state and "Auto Upgrade Slots aktif" or "Auto Upgrade Slots mati", 1.8)
end)

FarmTab:AddButton("💰 Ambil Cash Sekarang", function()
    if AutoPlot then
        AutoPlot.CollectBalanceOnce()
        Window.Notify("Collect Cash", "Cash berhasil diambil dari plot!", 2.0)
    end
end)

FarmTab:AddButton("⚔️ Pasang Unit Terbaik Sekarang", function()
    if AutoPlot then
        AutoPlot.EquipBestOnce()
        Window.Notify("Equip Best", "Unit terbaik berhasil dipasang ke slot!", 2.0)
    end
end)

FarmTab:AddButton("⬆️ Upgrade Semua Slot Sekali", function()
    if AutoPlot then
        local count = AutoPlot.UpgradeAllSlotsOnce()
        Window.Notify("Upgrade Slots", string.format("Upgrade dicoba untuk %d slot!", count), 2.0)
    end
end)

-- ─── TAB 2: 🎁 REWARDS & REBIRTH ─────────────────────────────────
local RewardsTab = Window:CreateTab("Rewards", "🎁")

RewardsTab:AddSection("🎁 Free Rewards")

RewardsTab:AddToggle("Auto Claim Daily Reward", CurrentConfig.AutoClaimDaily ~= false, function(state)
    CurrentConfig.AutoClaimDaily = state
    if ConfigManager then ConfigManager.Save() end
end)

RewardsTab:AddToggle("Auto Claim Group Reward", CurrentConfig.AutoClaimGroup ~= false, function(state)
    CurrentConfig.AutoClaimGroup = state
    if ConfigManager then ConfigManager.Save() end
end)

RewardsTab:AddToggle("Auto Claim Offline Earnings", CurrentConfig.AutoClaimOffline ~= false, function(state)
    CurrentConfig.AutoClaimOffline = state
    if ConfigManager then ConfigManager.Save() end
end)

RewardsTab:AddButton("🎁 Klaim Semua Hadiah Sekarang", function()
    if AutoRewards then
        AutoRewards.ClaimAllOnce()
        Window.Notify("Rewards", "Semua hadiah berhasil diklaim!", 2.0)
    end
end)

RewardsTab:AddSection("🔄 Rebirth System")

RewardsTab:AddToggle("Auto Rebirth", CurrentConfig.AutoRebirth or false, function(state)
    CurrentConfig.AutoRebirth = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Rebirth", state and "Auto Rebirth diaktifkan!" or "Auto Rebirth dimatikan.", 2.0)
end)

RewardsTab:AddButton("🔄 Lakukan Rebirth Sekarang", function()
    if AutoRewards then
        local ok = AutoRewards.RebirthOnce()
        Window.Notify("Rebirth", ok and "Rebirth berhasil dikirim!" or "Gagal mengirim rebirth.", 2.0)
    end
end)

-- ─── TAB 3: 📍 PLOT & TELEPORT ───────────────────────────────────
local TeleportTab = Window:CreateTab("Teleport", "📍")

TeleportTab:AddSection("🏰 Player Plot")

TeleportTab:AddButton("📍 Teleport ke Plot Saya", function()
    if Teleports then
        local ok, err = Teleports.TeleportToPlot()
        if ok then
            Window.Notify("Teleport", "Berhasil teleport ke plot kamu!", 2.0)
        else
            Window.Notify("Teleport Gagal", err or "Plot tidak ditemukan.", 2.5)
        end
    end
end)

-- ─── TAB 4: ⚙️ SETTINGS & UTILITIES ──────────────────────────────
local SettingsTab = Window:CreateTab("Settings", "⚙️")

SettingsTab:AddSection("🛡️ Protection & Safety")

SettingsTab:AddToggle("Anti-AFK 24/7 (Safe Bypass)", CurrentConfig.AntiAFK ~= false, function(state)
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

SettingsTab:AddButton("🔓 Force Unlock Mouse / Shift Lock", function()
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local slMod = rs:FindFirstChild("Framework")
            and rs.Framework:FindFirstChild("Features")
            and rs.Framework.Features:FindFirstChild("Player")
            and rs.Framework.Features.Player:FindFirstChild("ShiftlockController")
        if slMod then
            local sl = require(slMod)
            sl:ToggleShiftLock(false)
        end
        game:GetService("UserInputService").MouseBehavior = Enum.MouseBehavior.Default
    end)
    Window.Notify("Mouse Unlocked", "Kursor mouse dan Shift Lock berhasil dilepaskan!", 2.5)
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
            if CurrentConfig.FastRoll then AutoRoll.Start(CurrentConfig.RollDelay or 0.1) else AutoRoll.Stop() end
            if CurrentConfig.NativeAutoRoll ~= nil then AutoRoll.SetNativeAutoRoll(CurrentConfig.NativeAutoRoll) end
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
    if AutoRewards then AutoRewards.StopAll() end
    Window.Notify("Config Reset", "Pengaturan dikembalikan ke default!", 2.5)
end)

SettingsTab:AddSection("🚪 Utilities")

SettingsTab:AddButton("🔄 Rejoin Server", function()
    local ts = game:GetService("TeleportService")
    ts:Teleport(game.PlaceId, LocalPlayer)
end)

-- =================================================================
-- 🚀 5. AUTO START WORKERS BASED ON SAVED CONFIG
-- =================================================================
if AutoPlot then
    AutoPlot.CollectCash = (CurrentConfig.AutoCollectCash ~= false)
    AutoPlot.EquipBest = (CurrentConfig.AutoEquipBest ~= false)
    AutoPlot.UpgradeSlots = (CurrentConfig.AutoUpgradeSlots == true)
    AutoPlot.Start()
end
if AutoRewards then AutoRewards.Start() end
if AntiAFK and (CurrentConfig.AntiAFK ~= false) then AntiAFK.Start() end
if CurrentConfig.FastRoll and AutoRoll then
    AutoRoll.Start(CurrentConfig.RollDelay or 0.1)
end
if CurrentConfig.NativeAutoRoll and AutoRoll then
    AutoRoll.SetNativeAutoRoll(true)
end

_G.AnimeDiceLoaded = true
_G.AnimeDiceUI = Window

print("===============================================================")
print("⚡ RITOD HUB - ANIME DICE LOADED SUCCESSFULLY!")
print("===============================================================")
return Window
