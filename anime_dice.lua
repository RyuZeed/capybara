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
    if _G.AnimeDiceAutoPotion and typeof(_G.AnimeDiceAutoPotion.StopAll) == "function" then
        _G.AnimeDiceAutoPotion.StopAll()
    end
    if _G.AnimeDiceAutoUpgrades and typeof(_G.AnimeDiceAutoUpgrades.StopAll) == "function" then
        _G.AnimeDiceAutoUpgrades.StopAll()
    end
    if _G.AnimeDiceAutoDice and typeof(_G.AnimeDiceAutoDice.StopAll) == "function" then
        _G.AnimeDiceAutoDice.StopAll()
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
-- 🌐 3. MODULAR LOADER (GITHUB RAW WITH COMMIT-SHA CACHE-BYPASS)
-- =================================================================
local HttpService = game:GetService("HttpService")
local REPO_COMMIT = "main"
pcall(function()
    local apiRes = game:HttpGet("https://api.github.com/repos/RyuZeed/capybara/commits/main")
    if apiRes and #apiRes > 10 then
        local data = HttpService:JSONDecode(apiRes)
        if data and data.sha then
            REPO_COMMIT = tostring(data.sha)
        end
    end
end)

local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/" .. REPO_COMMIT .. "/modules/anime_dice/"
local SHARED_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/" .. REPO_COMMIT .. "/modules/shared/"

local function loadModule(name, isShared)
    -- 1. Primary: Fresh GitHub Raw pinned to latest commit SHA
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

    -- 2. Fallback: Local file if offline
    local localPath = (isShared and "modules/shared/" or "modules/anime_dice/") .. name .. ".lua"
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(localPath) then
        local content = readfile(localPath)
        if content and #content > 10 then
            local fn = loadstring(content)
            if fn then return fn() end
        end
    end

    return nil
end

local RitodUI = loadModule("ritod_ui", true) or _G.RitodUI
local ConfigManager = loadModule("config_manager", false) or _G.AnimeDiceConfigManager
local AutoRoll = loadModule("auto_roll", false) or _G.AnimeDiceAutoRoll
local AutoPlot = loadModule("auto_plot", false) or _G.AnimeDiceAutoPlot
local AutoRewards = loadModule("auto_rewards", false) or _G.AnimeDiceAutoRewards
local AutoPotion = loadModule("auto_potion", false) or _G.AnimeDiceAutoPotion
local AutoUpgrades = loadModule("auto_upgrades", false) or _G.AnimeDiceAutoUpgrades
local AutoDice = loadModule("auto_dice", false) or _G.AnimeDiceAutoDice
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
    AntiAFK = true,
    AutoPotion = false,
    AutoPotionLuck = true,
    AutoPotionIncome = false,
    AutoPotionDamage = false,
    AutoPotionNormal = true,
    AutoPotionPirate = true,
    AutoPotionCursed = true,
    AutoPotionDragon = true,
    AutoPotionTier1 = true,
    AutoPotionTier2 = true,
    AutoPotionTier3 = true,
    AutoUpgrades = false,
    AutoBuyDice = false,
    AutoEquipBestDice = true,
    SlotUpgradeTargetSlot = 0,
    SlotUpgradeTargetTimes = 5
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
        if AutoPotion then AutoPotion.StopAll() end
        if AutoUpgrades then AutoUpgrades.StopAll() end
        if AutoDice then AutoDice.StopAll() end
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

FarmTab:AddSlider("Collect Cooldown (Detik)", 5, 60, CurrentConfig.CollectCashInterval or 30, function(val)
    CurrentConfig.CollectCashInterval = val
    if AutoPlot then AutoPlot.CollectInterval = val end
    if ConfigManager then ConfigManager.Save() end
end)

FarmTab:AddToggle("Auto Equip Best Units", CurrentConfig.AutoEquipBest ~= false, function(state)
    CurrentConfig.AutoEquipBest = state
    if AutoPlot then AutoPlot.EquipBest = state end
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Equip Best", state and "Auto Equip Best aktif" or "Auto Equip Best mati", 1.8)
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

-- ─── SLOT UNITS & REALTIME UPGRADE ENGINE ─────────────────────
FarmTab:AddSection("⚡ Slot Units & Upgrade Engine (Realtime)")

local function formatCash(n)
    if not n or type(n) ~= "number" then return "0" end
    if n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.2fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local selectedSlotIdx = tonumber(CurrentConfig.SlotUpgradeTargetSlot) or 0
local selectedUpgradeTimes = tonumber(CurrentConfig.SlotUpgradeTargetTimes) or 5

if AutoPlot then
    AutoPlot.TargetSlot = selectedSlotIdx
    AutoPlot.UpgradeTimes = selectedUpgradeTimes
end

local slotInfoCard = FarmTab:AddParagraph(
    "📊 Memuat Data Slot Unit...",
    "Mengambil informasi unit, level, dan harga upgrade dari server..."
)

local autoUpgradeToggle

local function updateSlotDisplay()
    if not AutoPlot or not AutoPlot.GetSlotUnitInfo then return end
    local isUpgrading = AutoPlot.UpgradeSlots

    if selectedSlotIdx == 0 then
        local allSlots = AutoPlot.GetAllSlotsInfo()
        local activeCount = 0
        local lines = {}
        for _, s in ipairs(allSlots) do
            if s.hasUnit then
                activeCount = activeCount + 1
                table.insert(lines, string.format("S%d: %s (Lv.%d)", s.slot, s.unitName, s.level))
            end
        end
        local summaryStr = (#lines > 0) and table.concat(lines, " | ") or "Semua slot kosong."
        local statusNote = isUpgrading and string.format("\n⏳ Status: Auto Upgrade Berjalan (Target: %dx)", selectedUpgradeTimes) or ""
        slotInfoCard:Set(
            string.format("🌟 Semua Slot Unit (%d/8 Terpasang)", activeCount),
            string.format("Target: Semua Slot (1-8)\n%s%s", summaryStr, statusNote)
        )
    else
        local s = AutoPlot.GetSlotUnitInfo(selectedSlotIdx)
        if s.hasUnit then
            local statusStr = s.canAfford and "✅ Koin Cukup" or "❌ Koin Kurang"
            local remQuota = (AutoPlot.GetRemainingQuota and AutoPlot.GetRemainingQuota(selectedSlotIdx)) or 0
            local statusNote = isUpgrading and string.format(" | ⏳ Sisa: %dx", remQuota) or ""
            slotInfoCard:Set(
                string.format("⭐ [Slot %d] %s (%s)", s.slot, s.unitName, s.rarity),
                string.format("Level: %d | Grade: %s | Trait: %s | Mutasi: %s\nBiaya Upgrade: $%s (%s%s)",
                    s.level, s.grade, s.trait, s.mutation, formatCash(s.price), statusStr, statusNote)
            )
        else
            slotInfoCard:Set(
                string.format("⚪ [Slot %d] Slot Kosong", selectedSlotIdx),
                "Tidak ada unit yang ditempatkan pada slot ini.\nGunakan 'Pasang Unit Terbaik Sekarang' untuk mengisi slot."
            )
        end
    end
end

local slotOptions = {
    "Semua Slot (1-8)",
    "Slot 1", "Slot 2", "Slot 3", "Slot 4",
    "Slot 5", "Slot 6", "Slot 7", "Slot 8"
}
local currentSlotName = (selectedSlotIdx == 0) and "Semua Slot (1-8)" or ("Slot " .. selectedSlotIdx)

FarmTab:AddDropdown("Pilih Slot Unit", slotOptions, currentSlotName, function(choice)
    if choice == "Semua Slot (1-8)" then
        selectedSlotIdx = 0
    else
        local num = choice:match("%d+")
        selectedSlotIdx = tonumber(num) or 0
    end
    CurrentConfig.SlotUpgradeTargetSlot = selectedSlotIdx
    if AutoPlot then
        AutoPlot.TargetSlot = selectedSlotIdx
        if AutoPlot.UpgradeSlots then
            AutoPlot.StartAutoUpgradeSession(selectedUpgradeTimes, selectedSlotIdx)
        end
    end
    if ConfigManager then ConfigManager.Save() end
    updateSlotDisplay()
end)

FarmTab:AddSlider("Berapa Kali Upgrade (1 - 50x)", 1, 50, selectedUpgradeTimes, function(val)
    selectedUpgradeTimes = val
    CurrentConfig.SlotUpgradeTargetTimes = val
    if AutoPlot then
        AutoPlot.UpgradeTimes = val
        if AutoPlot.UpgradeSlots then
            AutoPlot.StartAutoUpgradeSession(val, selectedSlotIdx)
        end
    end
    if ConfigManager then ConfigManager.Save() end
    updateSlotDisplay()
end)

autoUpgradeToggle = FarmTab:AddToggle("Auto Upgrade Unit di Slot", false, function(state)
    CurrentConfig.AutoUpgradeSlots = state
    if AutoPlot then
        if state then
            AutoPlot.StartAutoUpgradeSession(selectedUpgradeTimes, selectedSlotIdx)
            local targetName = (selectedSlotIdx > 0) and ("Slot " .. selectedSlotIdx) or "Semua Slot"
            Window.Notify("Auto Upgrade", string.format("Auto Upgrade dimulai! Target %dx untuk %s.", selectedUpgradeTimes, targetName), 2.5)
        else
            AutoPlot.StopAutoUpgradeSession()
            Window.Notify("Auto Upgrade", "Auto Upgrade dimatikan.", 1.8)
        end
    end
    if ConfigManager then ConfigManager.Save() end
    updateSlotDisplay()
end)

if AutoPlot then
    AutoPlot.OnUpgradeCompleted = function(times, targetSlot)
        CurrentConfig.AutoUpgradeSlots = false
        if autoUpgradeToggle and typeof(autoUpgradeToggle.Set) == "function" then
            autoUpgradeToggle:Set(false, false)
        end
        local targetName = (targetSlot and targetSlot > 0) and ("Slot " .. targetSlot) or "Semua Slot"
        Window.Notify("Upgrade Selesai", string.format("Target %dx upgrade untuk %s telah selesai!", times, targetName), 3.0)
        updateSlotDisplay()
    end
end

FarmTab:AddButton("⬆️ Upgrade Unit Sekarang (Sesuai Pilihan X Kali)", function()
    if AutoPlot then
        local count = 0
        if selectedSlotIdx > 0 then
            count = AutoPlot.UpgradeSlotTimes(selectedSlotIdx, selectedUpgradeTimes)
            Window.Notify("Upgrade Slot", string.format("Slot %d berhasil di-upgrade %d/%d kali!", selectedSlotIdx, count, selectedUpgradeTimes), 2.5)
        else
            count = AutoPlot.UpgradeAllSlotsTimes(selectedUpgradeTimes)
            Window.Notify("Upgrade Slot", string.format("Semua slot di-upgrade total %d kali!", count), 2.5)
        end
        updateSlotDisplay()
    end
end)

task.spawn(function()
    while true do
        task.wait(1.2)
        pcall(updateSlotDisplay)
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

-- ─── TAB 3: 🧪 AUTO POTIONS ─────────────────────────────────────
local PotionsTab = Window:CreateTab("Potions", "🧪")

PotionsTab:AddSection("⚡ Master Control")

PotionsTab:AddToggle("Auto Use Potion (Active Buff Keepalive)", CurrentConfig.AutoPotion or false, function(state)
    CurrentConfig.AutoPotion = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoPotion then AutoPotion.Start() end
        Window.Notify("Auto Potion", "Auto Use Potion diaktifkan!", 2.0)
    else
        if AutoPotion then AutoPotion.Stop() end
        Window.Notify("Auto Potion", "Auto Use Potion dinonaktifkan.", 2.0)
    end
end)

PotionsTab:AddSection("🍀 Filter Berdasarkan Efek (Stat)")

PotionsTab:AddToggle("Auto Use Luck Potions (🍀)", CurrentConfig.AutoPotionLuck ~= false, function(state)
    CurrentConfig.AutoPotionLuck = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Filter Potion", state and "Auto Luck: Aktif" or "Auto Luck: Mati", 1.5)
end)

PotionsTab:AddToggle("Auto Use Income Potions (💰)", CurrentConfig.AutoPotionIncome or false, function(state)
    CurrentConfig.AutoPotionIncome = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Filter Potion", state and "Auto Income: Aktif" or "Auto Income: Mati", 1.5)
end)

PotionsTab:AddToggle("Auto Use Damage Potions (⚔️)", CurrentConfig.AutoPotionDamage or false, function(state)
    CurrentConfig.AutoPotionDamage = state
    if ConfigManager then ConfigManager.Save() end
    Window.Notify("Filter Potion", state and "Auto Damage: Aktif" or "Auto Damage: Mati", 1.5)
end)

PotionsTab:AddSection("🌍 Filter Berdasarkan Dunia / Seri")

PotionsTab:AddToggle("🌟 Normal Potions", CurrentConfig.AutoPotionNormal ~= false, function(state)
    CurrentConfig.AutoPotionNormal = state
    if ConfigManager then ConfigManager.Save() end
end)

PotionsTab:AddToggle("🏴‍☠️ Pirate Potions", CurrentConfig.AutoPotionPirate ~= false, function(state)
    CurrentConfig.AutoPotionPirate = state
    if ConfigManager then ConfigManager.Save() end
end)

PotionsTab:AddToggle("🔮 Cursed Potions", CurrentConfig.AutoPotionCursed ~= false, function(state)
    CurrentConfig.AutoPotionCursed = state
    if ConfigManager then ConfigManager.Save() end
end)

PotionsTab:AddToggle("🐉 Dragon Potions", CurrentConfig.AutoPotionDragon ~= false, function(state)
    CurrentConfig.AutoPotionDragon = state
    if ConfigManager then ConfigManager.Save() end
end)

PotionsTab:AddSection("⭐ Filter Tier")

PotionsTab:AddToggle("Tier I Potions", CurrentConfig.AutoPotionTier1 ~= false, function(state)
    CurrentConfig.AutoPotionTier1 = state
    if ConfigManager then ConfigManager.Save() end
end)

PotionsTab:AddToggle("Tier II Potions", CurrentConfig.AutoPotionTier2 ~= false, function(state)
    CurrentConfig.AutoPotionTier2 = state
    if ConfigManager then ConfigManager.Save() end
end)

PotionsTab:AddToggle("Tier III Potions", CurrentConfig.AutoPotionTier3 ~= false, function(state)
    CurrentConfig.AutoPotionTier3 = state
    if ConfigManager then ConfigManager.Save() end
end)

PotionsTab:AddSection("🚀 Tindakan Instan (Manual)")

PotionsTab:AddButton("🍀 Gunakan Semua Potion Luck (Sekali)", function()
    if AutoPotion then
        local count = AutoPotion.UseAllCategoryOnce("Luck")
        Window.Notify("Potion Luck", string.format("%d Potion Luck berhasil digunakan!", count), 2.0)
    end
end)

PotionsTab:AddButton("💰 Gunakan Semua Potion Income (Sekali)", function()
    if AutoPotion then
        local count = AutoPotion.UseAllCategoryOnce("Income")
        Window.Notify("Potion Income", string.format("%d Potion Income berhasil digunakan!", count), 2.0)
    end
end)

PotionsTab:AddButton("⚔️ Gunakan Semua Potion Damage (Sekali)", function()
    if AutoPotion then
        local count = AutoPotion.UseAllCategoryOnce("Damage")
        Window.Notify("Potion Damage", string.format("%d Potion Damage berhasil digunakan!", count), 2.0)
    end
end)

PotionsTab:AddButton("📊 Cek Potion yang Dimiliki (Console)", function()
    if AutoPotion then
        local owned = AutoPotion.GetOwnedPotions()
        local lines = {}
        for _, p in ipairs(owned) do
            table.insert(lines, string.format("[%s] %s (Tier %d): %d buah", p.stat, p.fullName, p.tier, p.amount))
        end
        local summary = #lines > 0 and table.concat(lines, "\n") or "Tidak ada potion di inventory."
        print("===============================================================")
        print("🎒 DAFTAR POTION DI INVENTORY:")
        print(summary)
        print("===============================================================")
        Window.Notify("Daftar Potion", string.format("Memiliki %d jenis potion. Rincian ada di F9 Console!", #owned), 3.0)
    end
end)

-- ─── TAB 4: 🛒 SHOP & UPGRADES ─────────────────────────────────
local ShopTab = Window:CreateTab("Shop & Upgrades", "🛒")

ShopTab:AddSection("🌳 Tree Upgrades (Urutan Sesuai)")

ShopTab:AddToggle("Auto Buy Upgrades (Tree Order)", CurrentConfig.AutoUpgrades or false, function(state)
    CurrentConfig.AutoUpgrades = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoUpgrades then AutoUpgrades.Start() end
        Window.Notify("Auto Upgrades", "Auto Buy Upgrades diaktifkan!", 2.0)
    else
        if AutoUpgrades then AutoUpgrades.Stop() end
        Window.Notify("Auto Upgrades", "Auto Buy Upgrades dimatikan.", 2.0)
    end
end)

ShopTab:AddButton("⬆️ Beli Semua Upgrade yang Mampu (Sekali)", function()
    if AutoUpgrades then
        local count = AutoUpgrades.BuyAvailableOnce()
        Window.Notify("Upgrades", string.format("%d Upgrade berhasil dibeli!", count), 2.0)
    end
end)

ShopTab:AddButton("📊 Cek Upgrade Tersedia Berikutnya", function()
    if AutoUpgrades then
        local list = AutoUpgrades.GetAvailableUpgrades()
        print("===============================================================")
        print("🌳 DAFTAR UPGRADE TERSEDIA BERIKUTNYA:")
        for _, u in ipairs(list) do
            print(string.format("-> %s | Harga: $%s | Mampu: %s", u.name, tostring(u.price), tostring(u.canAfford)))
        end
        print("===============================================================")
        local top = list[1]
        if top then
            Window.Notify("Next Upgrade", string.format("%s ($%s) - Mampu: %s", top.name, tostring(top.price), tostring(top.canAfford)), 3.0)
        else
            Window.Notify("Upgrades", "Semua upgrade saat ini sudah dimiliki!", 2.0)
        end
    end
end)

ShopTab:AddSection("🎲 Dice Shop (Urutan Progresi)")

ShopTab:AddToggle("Auto Buy Next Dice (Progression Order)", CurrentConfig.AutoBuyDice or false, function(state)
    CurrentConfig.AutoBuyDice = state
    if ConfigManager then ConfigManager.Save() end
    if state then
        if AutoDice then AutoDice.Start() end
        Window.Notify("Auto Buy Dice", "Auto Buy Dice diaktifkan!", 2.0)
    else
        if AutoDice then AutoDice.Stop() end
        Window.Notify("Auto Buy Dice", "Auto Buy Dice dimatikan.", 2.0)
    end
end)

ShopTab:AddToggle("Auto Equip Best Dice (Highest Luck)", CurrentConfig.AutoEquipBestDice ~= false, function(state)
    CurrentConfig.AutoEquipBestDice = state
    if ConfigManager then ConfigManager.Save() end
    if state and AutoDice then
        AutoDice.EquipBestDiceOnce()
    end
end)

ShopTab:AddButton("🎲 Beli Dadu Berikutnya Sekarang", function()
    if AutoDice then
        local ok, nameOrErr = AutoDice.BuyNextDiceOnce()
        if ok then
            Window.Notify("Dice Bought", string.format("Berhasil membeli dadu: %s!", nameOrErr), 2.5)
        else
            Window.Notify("Dice Shop", nameOrErr or "Gagal membeli dadu.", 2.5)
        end
    end
end)

ShopTab:AddButton("✨ Pasang Dadu Terbaik Milikmu", function()
    if AutoDice then
        local ok, res = AutoDice.EquipBestDiceOnce()
        if ok then
            Window.Notify("Equip Dice", string.format("Berhasil memasang dadu terbaik: %s!", res), 2.0)
        else
            Window.Notify("Equip Dice", res or "Dadu terbaik sudah terpasang.", 2.0)
        end
    end
end)

ShopTab:AddButton("📊 Cek Dadu Berikutnya & Harga", function()
    if AutoDice then
        local nextD = AutoDice.GetNextUnownedDice()
        if nextD then
            print(string.format("=== NEXT DICE: %s | Luck: %sx | Harga: $%s | Mampu: %s ===", nextD.name, tostring(nextD.luck), tostring(nextD.price), tostring(nextD.canAfford)))
            Window.Notify("Next Dice", string.format("%s (Luck %sx) - $%s", nextD.name, tostring(nextD.luck), tostring(nextD.price)), 3.5)
        else
            Window.Notify("Dice Shop", "Semua dadu dalam game sudah kamu miliki!", 2.5)
        end
    end
end)

-- ─── TAB 5: 📍 PLOT & TELEPORT ───────────────────────────────────
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
        if AutoPotion then
            if CurrentConfig.AutoPotion then AutoPotion.Start() else AutoPotion.Stop() end
        end
        if AutoUpgrades then
            if CurrentConfig.AutoUpgrades then AutoUpgrades.Start() else AutoUpgrades.Stop() end
        end
        if AutoDice then
            if CurrentConfig.AutoBuyDice or CurrentConfig.AutoEquipBestDice then AutoDice.Start() else AutoDice.Stop() end
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
    if AutoPotion then AutoPotion.StopAll() end
    if AutoUpgrades then AutoUpgrades.StopAll() end
    if AutoDice then AutoDice.StopAll() end
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
    AutoPlot.CollectInterval = CurrentConfig.CollectCashInterval or 30
    AutoPlot.EquipBest = (CurrentConfig.AutoEquipBest ~= false)
    AutoPlot.UpgradeSlots = (CurrentConfig.AutoUpgradeSlots == true)
    AutoPlot.Start()
end
if AutoRewards then AutoRewards.Start() end
if AutoPotion and CurrentConfig.AutoPotion then AutoPotion.Start() end
if AutoUpgrades and CurrentConfig.AutoUpgrades then AutoUpgrades.Start() end
if AutoDice and (CurrentConfig.AutoBuyDice or CurrentConfig.AutoEquipBestDice) then AutoDice.Start() end
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
