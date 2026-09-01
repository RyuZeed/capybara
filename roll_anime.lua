--[[
	===============================================================
	⚡ RITOD HUB - ROLL ANIME FOR FIGHT (MODULAR EDITION)
	Game: Roll Anime For Fight / Anime Auto Roll
	UI Library: modules/shared/ritod_ui.lua (RitodUI Universal Engine)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🧩 MODULE DIRECTORY: modules/roll_anime/
	  - anti_afk.lua
	  - config_manager.lua
	  - catalog.lua
	  - auto_roll.lua
	  - auto_claim.lua
	  - auto_merchant.lua
	  - graphics.lua
	  - private_server.lua
	- 📁 SHARED UI: modules/shared/ritod_ui.lua & modern_settings.lua
	- 📁 PERSISTENT CONFIG: RitodHub/RollAnimeForFight/<Username>.json
	- 🛡️ BULLETPROOF ANTI-AFK: 3-Layer Hardware Keypulse & Idled Interception
	- 🔄 AUTO-RESUME: Otomatis lanjut roll jika sesi sebelumnya aktif
	- 🌟 STRICT CATALOG: 13 Secret & 14 God Unit Asli
	- 🖥️ ULTRA HD GUI (700x460) with Shared RitodUI
	===============================================================
]]

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.2)

-- 🔒 GLOBAL MUTEX LOCK: Cegah double execution
if _G.RitodHubInitLock and (tick() - _G.RitodHubInitLock) < 3 then
	return
end
_G.RitodHubInitLock = tick()

-- 🔇 SILENT MODE: Matikan seluruh text/log terminal
local print = function(...) end
local warn = function(...) end

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

-- =================================================================
-- 🛡️ ANTI DOUBLE-EXECUTE & FULL CLEANUP HANDLER
-- =================================================================
pcall(function()
    if typeof(_G.RitodHubCleanup) == "function" then
        _G.RitodHubCleanup()
    end

    if _G.AutoRollModule and typeof(_G.AutoRollModule.Stop) == "function" then
        pcall(function() _G.AutoRollModule.Stop() end)
        if typeof(_G.AutoRollModule.StopAutoSniper) == "function" then
            pcall(function() _G.AutoRollModule.StopAutoSniper() end)
        end
    end
    if _G.AutoClaimModule and typeof(_G.AutoClaimModule.Stop) == "function" then
        pcall(function() _G.AutoClaimModule.Stop() end)
    end
    if _G.AutoMerchantModule and typeof(_G.AutoMerchantModule.Stop) == "function" then
        pcall(function() _G.AutoMerchantModule.Stop() end)
    end
    if _G.GraphicsModule and typeof(_G.GraphicsModule.SetFarmMode) == "function" then
        pcall(function() _G.GraphicsModule.SetFarmMode(false) end)
    end
    if _G.AutoSaveDaemonThread then
        pcall(function() task.cancel(_G.AutoSaveDaemonThread) end)
        _G.AutoSaveDaemonThread = nil
    end
    if _G.AutoPrivateServerThread then
        pcall(function() task.cancel(_G.AutoPrivateServerThread) end)
        _G.AutoPrivateServerThread = nil
    end

    _G.AutoRollModule = nil
    _G.CatalogModule = nil
    _G.AutoClaimModule = nil
    _G.AutoMerchantModule = nil
    _G.GraphicsModule = nil
    _G.PrivateServerModule = nil

    if _G.RitodHubRollAnime and typeof(_G.RitodHubRollAnime) == "Instance" then
        pcall(function() _G.RitodHubRollAnime:Destroy() end)
    end
    local targets = {}
    if typeof(gethui) == "function" then pcall(function() table.insert(targets, gethui()) end) end
    if CoreGui then table.insert(targets, CoreGui) end
    if player and player:FindFirstChild("PlayerGui") then table.insert(targets, player.PlayerGui) end
    
    for _, parent in ipairs(targets) do
        for _, child in ipairs(parent:GetChildren()) do
            local cName = tostring(child.Name)
            if cName == "RitodHubUltra" or cName == "RitodHubLite" or cName == "RollAnimeHub" or cName == "RitodRollAnime" or cName:find("RitodHub") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end)

-- =================================================================
-- 🌐 ROLL ANIME MODULAR LOADER (LOCAL & GITHUB CLOUD SUPPORT)
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/roll_anime/"
local SHARED_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/"

local function loadModule(name)
    -- 1. Prioritaskan GitHub Cloud langsung (Timestamped cache bypass)
    local cacheBust = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    local targetUrl = (name == "modern_settings" or name == "ritod_ui") and (SHARED_URL .. name .. ".lua?_cb=" .. cacheBust) or (BASE_URL .. name .. ".lua?_cb=" .. cacheBust)
    local success, result = pcall(function()
        local src = game:HttpGet(targetUrl)
        if src and #src > 10 and not src:find("404: Not Found") then
            local fn = loadstring(src)
            if fn then return fn() end
        end
        return nil
    end)
    if success and result then
        return result
    end

    -- 2. Fallback: Cek memory global _G
    if name == "ritod_ui" and _G.RitodUI and typeof(_G.RitodUI.CreateWindow) == "function" then return _G.RitodUI end
    if name == "auto_merchant" and _G.AutoMerchantModule then return _G.AutoMerchantModule end
    if name == "graphics" and _G.GraphicsModule then return _G.GraphicsModule end
    if name == "auto_roll" and _G.AutoRollModule then return _G.AutoRollModule end
    if name == "auto_claim" and _G.AutoClaimModule then return _G.AutoClaimModule end
    if name == "catalog" and _G.CatalogModule then return _G.CatalogModule end
    if name == "anti_afk" and _G.AFKModule then return _G.AFKModule end
    if name == "config_manager" and _G.ConfigManager then return _G.ConfigManager end
    if name == "modern_settings" and _G.ModernSettings and typeof(_G.ModernSettings.CreateProfileManager) == "function" then
        return _G.ModernSettings
    end

    -- 3. Fallback: File lokal di workspace jika koneksi gagal
    local localPaths = {
        "modules/roll_anime/" .. name .. ".lua",
        name .. ".lua",
        "RitodHub/modules/roll_anime/" .. name .. ".lua",
        "lucid-shannon/modules/roll_anime/" .. name .. ".lua",
        "modules/shared/" .. name .. ".lua",
        "RitodHub/modules/shared/" .. name .. ".lua",
        "lucid-shannon/modules/shared/" .. name .. ".lua",
        "shared/" .. name .. ".lua"
    }
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        for _, path in ipairs(localPaths) do
            if isfile(path) then
                local lSuccess, lResult = pcall(function()
                    local src = readfile(path)
                    local fn = loadstring(src)
                    if fn then return fn() end
                end)
                if lSuccess and lResult then
                    return lResult
                end
            end
        end
    end

    return nil
end

local RitodUI         = loadModule("ritod_ui")
local AFKModule       = loadModule("anti_afk")
local ConfigManager   = loadModule("config_manager")
local CatalogModule   = loadModule("catalog")
local AutoRollModule  = loadModule("auto_roll")
local AutoClaimModule = loadModule("auto_claim")
local AutoMerchantModule = loadModule("auto_merchant")
local GraphicsModule  = loadModule("graphics")
local ModernSettings      = loadModule("modern_settings")
local PrivateServerModule = loadModule("private_server")

-- Auto-start Anti-AFK 24/7 Engine
pcall(function()
    if AFKModule and typeof(AFKModule.Enable) == "function" then
        AFKModule.Enable()
    elseif _G.AFKModule and typeof(_G.AFKModule.Enable) == "function" then
        _G.AFKModule.Enable()
    end
end)

-- Muat config tersimpan
local savedConfig = ConfigManager and ConfigManager.Load() or {}
if savedConfig.AutoPrivateServer == nil then
    savedConfig.AutoPrivateServer = true
end

-- Auto-start Auto-Claim Engine
if AutoClaimModule then
    pcall(function()
        AutoClaimModule.Start({
            DailyQuest    = savedConfig.AutoClaimQuests ~= false,
            WeeklyQuest   = savedConfig.AutoClaimQuests ~= false,
            Battlepass    = savedConfig.AutoClaimRewards ~= false,
            FreeRewards   = savedConfig.AutoClaimRewards ~= false,
            VIPAndGroup   = savedConfig.AutoClaimRewards ~= false,
            AutoSpinWheel = savedConfig.AutoSpinWheel ~= false,
        })
    end)
end

-- Auto-start Auto-Merchant Engine
if AutoMerchantModule and savedConfig.AutoBuyMerchant ~= false then
    pcall(function()
        AutoMerchantModule.Start({
            Enabled         = true,
            BuyAllStock     = savedConfig.MerchantBuyAll or false,
            BuyPotions      = savedConfig.MerchantBuyPotions ~= false,
            BuyEssences     = savedConfig.MerchantBuyEssences ~= false,
            BuyCapsules     = savedConfig.MerchantBuyCapsules ~= false,
            BuyTickets      = savedConfig.MerchantBuyTickets ~= false,
            BuyMaterials    = savedConfig.MerchantBuyMaterials ~= false,
            SelectedItems   = savedConfig.MerchantSelectedItems or {},
            MinGoldReserve  = savedConfig.MerchantMinGold or 0,
        })
    end)
end

-- Auto-start Private Server Engine
if PrivateServerModule and savedConfig.AutoPrivateServer then
    pcall(function()
        PrivateServerModule.Start()
    end)
end

-- Auto-apply In-Game Settings Preset (Screenshot Setup)
if GraphicsModule and savedConfig.AutoApplyGameSettings ~= false then
    pcall(function()
        GraphicsModule.ApplyGameSettingsPreset()
        GraphicsModule.StartGameSettingsWatchdog(10)
    end)
end

-- ⚙️ getgenv().RitodConfig / getgenv().UserConfig Override Support
local userGenConfig = (getgenv and (getgenv().RitodConfig or getgenv().UserConfig)) or {}
if userGenConfig["Potato Graphics"] ~= nil then savedConfig.PotatoGraphics = userGenConfig["Potato Graphics"] end
if userGenConfig["PotatoGraphics"] ~= nil then savedConfig.PotatoGraphics = userGenConfig["PotatoGraphics"] end
if userGenConfig["Low Graphics"] ~= nil then savedConfig.PotatoGraphics = userGenConfig["Low Graphics"] end
if userGenConfig["Anti Lag"] ~= nil then savedConfig.AntiLag = userGenConfig["Anti Lag"] end
if userGenConfig["AntiLag"] ~= nil then savedConfig.AntiLag = userGenConfig["AntiLag"] end
if userGenConfig["Farm Mode"] ~= nil then savedConfig.FarmMode = userGenConfig["Farm Mode"] end
if userGenConfig["FarmMode"] ~= nil then savedConfig.FarmMode = userGenConfig["FarmMode"] end
if userGenConfig["Auto Roll"] ~= nil then savedConfig.AutoHuntEnabled = userGenConfig["Auto Roll"] end
if userGenConfig["Auto Hunt"] ~= nil then savedConfig.AutoHuntEnabled = userGenConfig["Auto Hunt"] end
if userGenConfig["AutoHunt"] ~= nil then savedConfig.AutoHuntEnabled = userGenConfig["AutoHunt"] end
if userGenConfig["Roll Delay"] ~= nil then savedConfig.RollInterval = userGenConfig["Roll Delay"] end
if userGenConfig["FPS Cap"] ~= nil and GraphicsModule then GraphicsModule.ApplyFpsCap(userGenConfig["FPS Cap"]) end

-- =================================================================
-- 🎨 STATE & VARIABLES
-- =================================================================
local selectedUnits = savedConfig.SelectedUnits or {}
local rollInterval = savedConfig.RollInterval or 2.5
local totalAcquiredCount = 0
local unitCheckUpdaterCallbacks = {}

-- Player Humanoid modifiers
local function applyPlayerWalkSpeed(spd)
	pcall(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = tonumber(spd) or 16 end
	end)
end

local function applyPlayerJumpPower(jp)
	pcall(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = tonumber(jp) or 50
		end
	end)
end

local function doUnload()
	if typeof(_G.RitodHubCleanup) == "function" then
		_G.RitodHubCleanup()
	end
	if AutoRollModule then AutoRollModule.Stop() end
	if AutoClaimModule then AutoClaimModule.Stop() end
	if AutoMerchantModule then AutoMerchantModule.Stop() end
	if GraphicsModule then
		GraphicsModule.DisableUltraPotato()
		GraphicsModule.SetFarmMode(false)
		GraphicsModule.StopGameSettingsWatchdog()
	end
	if AFKModule and typeof(AFKModule.Disable) == "function" then AFKModule.Disable() end
	if _G.AutoSaveDaemonThread then task.cancel(_G.AutoSaveDaemonThread) _G.AutoSaveDaemonThread = nil end
	if _G.AutoPrivateServerThread then task.cancel(_G.AutoPrivateServerThread) _G.AutoPrivateServerThread = nil end
end

-- =================================================================
-- 🖥️ INITIALIZE RITOD UI WINDOW
-- =================================================================
local Window = RitodUI:CreateWindow({
	Title = "⚡RITOD HUB⚡",
	GameName = "Roll Anime for Fight",
	Size = Vector2.new(700, 460),
	OnUnload = doUnload
})

local Notify = Window.Notify
_G.RitodHubRollAnime = Window.ScreenGui

-- =================================================================
-- 1. TAB 🎰 AUTO ROLL (MASTER CONTROLS)
-- =================================================================
local RollTab = Window:CreateTab("Auto Roll", "🎯")

RollTab:AddSection("Live Roll Controller")

-- 📊 Live Status Card Helper
local function createStatusCard(parent)
	local card = Instance.new("Frame")
	card.Name = "StatusCard"
	card.Size = UDim2.new(1, 0, 0, 70)
	card.BackgroundColor3 = Color3.fromRGB(22, 16, 30)
	card.BorderSizePixel = 0
	card.ZIndex = 14
	card.Parent = parent

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 10)
	cCorner.Parent = card

	local cStroke = Instance.new("UIStroke")
	cStroke.Thickness = 1.2
	cStroke.Color = Color3.fromRGB(85, 60, 110)
	cStroke.Parent = card

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(1, -24, 0, 24)
	statusLbl.Position = UDim2.new(0, 12, 0, 10)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "Status: ⚪ OFF (Idle)"
	statusLbl.TextColor3 = Color3.fromRGB(180, 165, 205)
	statusLbl.TextSize = 13
	statusLbl.Font = Enum.Font.GothamBold
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.ZIndex = 15
	statusLbl.Parent = card

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, -24, 0, 20)
	subLbl.Position = UDim2.new(0, 12, 0, 38)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = "Siap mencari target unit di pedestal / conveyor..."
	subLbl.TextColor3 = Color3.fromRGB(145, 130, 165)
	subLbl.TextSize = 11
	subLbl.Font = Enum.Font.GothamMedium
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.ZIndex = 15
	subLbl.Parent = card

	return {
		SetStatus = function(self, text, color)
			statusLbl.Text = text
			if color then statusLbl.TextColor3 = color end
		end,
		SetSub = function(self, text, color)
			subLbl.Text = text
			if color then subLbl.TextColor3 = color end
		end
	}
end

local statusCard = createStatusCard(RollTab.Page)
local huntToggleRef = nil

local function startHunt()
	if not AutoRollModule or AutoRollModule.IsRunning() then return end
	if ConfigManager then ConfigManager.Save({ AutoHuntEnabled = true }) end

	statusCard:SetStatus("Status: 🟢 Auto Hunt ON (Mencari target...)", Color3.fromRGB(0, 255, 180))
	statusCard:SetSub("Memonitor slot roll & pedestal...", Color3.fromRGB(180, 160, 210))
	Notify("Auto Hunt", "Auto Roll & Sniper AKTIF!", 2.5)

	AutoRollModule.Start({
		AutoSecretGod = savedConfig.AutoSecretGod or false,
		GetAutoSecretGod = function() return savedConfig.AutoSecretGod or false end,
		GetQuestRollMode = function() return savedConfig.AutoQuestRollMode or false end,
		SelectedUnits = selectedUnits,
		AllUnitsMap = CatalogModule and CatalogModule.AllUnitsMap or {},
		GetInterval = function() return rollInterval end,
		OnStatus = function(msg, state, extra)
			if state == "rolling" then
				statusCard:SetStatus(msg, Color3.fromRGB(190, 120, 255))
			elseif state == "quest_done" then
				statusCard:SetStatus(msg, Color3.fromRGB(70, 255, 140))
			elseif state == "found" then
				statusCard:SetStatus(msg, Color3.fromRGB(255, 215, 0))
				Notify("Target Ditemukan!", string.format("Membeli %d target unit di pedestal...", extra), 2.5)
			elseif state == "buying" then
				statusCard:SetStatus(msg, Color3.fromRGB(255, 215, 0))
			elseif state == "waiting_gold" then
				statusCard:SetStatus(msg, Color3.fromRGB(255, 170, 0))
			elseif state == "waiting" or state == "waiting_plot" or state == "waiting_prompt" or state == "reacquiring" then
				statusCard:SetStatus(msg, Color3.fromRGB(255, 200, 80))
			elseif state == "resuming" then
				statusCard:SetStatus(msg, Color3.fromRGB(0, 255, 200))
			else
				statusCard:SetStatus(msg, Color3.fromRGB(180, 165, 205))
			end
		end,
		OnBought = function(unit)
			totalAcquiredCount = totalAcquiredCount + 1
			statusCard:SetSub(string.format("Terbeli: [%s] %s (Total: %d)", unit.rarity or "Unit", unit.name or "Unit", totalAcquiredCount), Color3.fromRGB(70, 255, 140))
			Notify("Unit Terbeli!", string.format("[%s] %s berhasil dibeli!", unit.rarity, unit.name), 3)
		end,
		OnError = function(err)
			statusCard:SetStatus("Status: ❌ " .. err, Color3.fromRGB(255, 80, 80))
			Notify("Auto Hunt Error", err, 3)
			if huntToggleRef then huntToggleRef:Set(false, false) end
		end
	})
end

local function stopHunt()
	if AutoRollModule then AutoRollModule.Stop() end
	if ConfigManager then ConfigManager.Save({ AutoHuntEnabled = false }) end
	statusCard:SetStatus("Status: ⚪ OFF (Idle)", Color3.fromRGB(180, 165, 205))
	statusCard:SetSub("Siap mencari target unit di pedestal / conveyor...", Color3.fromRGB(145, 130, 165))
	Notify("Auto Hunt", "Auto Roll dihentikan.", 2)
end

local autoSniperToggleRef = nil
local autoQuestRollToggleRef = nil

local function startAutoSniper()
	if not AutoRollModule then return end
	AutoRollModule.StartAutoSniper({
		SelectedUnits = selectedUnits,
		AllUnitsMap = CatalogModule and CatalogModule.AllUnitsMap or {},
		GetAutoSecretGod = function() return savedConfig.AutoSecretGod or false end,
		OnStatus = function(text, stateType)
			statusCard:SetStatus(text, Color3.fromRGB(80, 220, 255))
		end,
		OnBought = function(unit)
			totalAcquiredCount = totalAcquiredCount + 1
			statusCard:SetSub(string.format("Snipe: [%s] %s (Total: %d)", unit.rarity or "Unit", unit.name or "Unit", totalAcquiredCount), Color3.fromRGB(70, 255, 140))
			Notify("🎯 Unit Ter-Snipe!", string.format("[%s] %s berhasil dibeli dari conveyor!", unit.rarity, unit.name), 3)
		end
	})
	if ConfigManager then ConfigManager.Save({ AutoSniperOnly = true }) end
	Notify("Auto Sniper", "Auto Buy Standalone aktif! Memantau conveyor...", 2)
end

local function stopAutoSniper()
	if AutoRollModule then AutoRollModule.StopAutoSniper() end
	if ConfigManager then ConfigManager.Save({ AutoSniperOnly = false }) end
	statusCard:SetStatus("Status: ⚪ OFF (Idle)", Color3.fromRGB(180, 165, 205))
	Notify("Auto Sniper", "Auto Buy Standalone dinonaktifkan.", 2)
end

local autoSecretGodToggleRef = nil
local rollDelaySliderRef = nil
local walkSpeedSliderRef = nil
local jumpPowerSliderRef = nil
local infJumpToggleRef = nil
local questToggleRef = nil
local rewardsToggleRef = nil
local farmModeToggleRef = nil
local potatoToggleRef = nil
local antiLagToggleRef = nil
local autoPrivateServerToggleRef = nil
local merchantToggleRef = nil
local merchantBuyAllToggleRef = nil
local merchantPotionsToggleRef = nil
local merchantEssencesToggleRef = nil
local merchantCapsulesToggleRef = nil
local merchantTicketsToggleRef = nil
local merchantMaterialsToggleRef = nil
local hideOtherPlayersToggleRef = nil
local freezeNPCsToggleRef = nil
local disableVFXToggleRef = nil
local fpsCapSliderRef = nil
local autoGameSettingsToggleRef = nil

huntToggleRef = RollTab:AddToggle("Auto Hunt (Continuous Roll & Sniper)", savedConfig.AutoHuntEnabled or false, function(state)
	if state then startHunt() else stopHunt() end
end)

autoQuestRollToggleRef = RollTab:AddToggle("🎯 Auto Roll Daily (250x) & Weekly (5000x) Quests", savedConfig.AutoQuestRollMode or false, function(state)
	savedConfig.AutoQuestRollMode = state
	if ConfigManager then ConfigManager.Save({ AutoQuestRollMode = state }) end
	if state then
		if huntToggleRef then huntToggleRef:Set(true, false) end
		startHunt()
		Notify("Quest Roll Mode", "🎯 Auto Roll Quest Aktif! Memulai roll target 250x & 5000x...", 2.5)
	else
		Notify("Quest Roll Mode", "Mode Quest Roll dinonaktifkan (kembali ke roll biasa).", 2)
	end
end)

autoSniperToggleRef = RollTab:AddToggle("🎯 Auto Buy / Sniper (Hanya Beli Tanpa Roll)", savedConfig.AutoSniperOnly or false, function(state)
	if state then startAutoSniper() else stopAutoSniper() end
end)

autoSecretGodToggleRef = RollTab:AddToggle("👑 Auto Buy Supreme/God/Secret/Limited (Tanpa List)", savedConfig.AutoSecretGod or false, function(state)
	savedConfig.AutoSecretGod = state
	if ConfigManager then ConfigManager.Save({ AutoSecretGod = state }) end
	Notify("Auto Supreme/God", state and "Mode Auto Supreme & God AKTIF!" or "Mode Auto Supreme & God NONAKTIF", 2)
end)

rollDelaySliderRef = RollTab:AddSlider("Roll Delay (Detik)", 1, 5, math.floor(rollInterval), function(val)
	rollInterval = val
	if ConfigManager then ConfigManager.Save({ RollInterval = val }) end
end)

-- =================================================================
-- 2. TAB 📋 DAFTAR UNIT & FILTER
-- =================================================================
local UnitTab = Window:CreateTab("Daftar Unit", "📋")

UnitTab:AddSection("Pencarian & Aksi Cepat")

local searchFilterText = ""
local activeRarityFilter = "ALL"
local unitListHolder = nil

local function refreshUnitCardsVisibility()
	if not unitListHolder then return end
	for _, cardObj in ipairs(unitCheckUpdaterCallbacks) do
		local u = cardObj.unit
		local card = cardObj.card
		local matchSearch = (searchFilterText == "")
			or string.find(u.name:lower(), searchFilterText:lower())
			or string.find(u.displayName:lower(), searchFilterText:lower())
			or string.find(u.rarity:lower(), searchFilterText:lower())

		local matchRarity = (activeRarityFilter == "ALL")
			or (u.rarity:upper() == activeRarityFilter:upper())
			or (activeRarityFilter == "SECRET/GOD" and (u.rarity == "Secret" or u.rarity == "God" or u.rarity == "Supreme" or u.rarity == "Limited"))

		card.Visible = (matchSearch and matchRarity)
	end
end

UnitTab:AddInput("🔍 Cari nama unit atau rarity...", function(text)
	searchFilterText = text or ""
	refreshUnitCardsVisibility()
end)

local filterRow = Instance.new("Frame")
filterRow.Size = UDim2.new(1, 0, 0, 36)
filterRow.BackgroundTransparency = 1
filterRow.ZIndex = 14
filterRow.Parent = UnitTab.Page

local fLayout = Instance.new("UIListLayout")
fLayout.FillDirection = Enum.FillDirection.Horizontal
fLayout.Padding = UDim.new(0, 8)
fLayout.Parent = filterRow

local function createMiniBtn(text, parent, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.315, 0, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(32, 24, 42)
	b.AutoButtonColor = false
	b.Text = text
	b.TextColor3 = Color3.fromRGB(235, 220, 250)
	b.TextSize = 11
	b.Font = Enum.Font.GothamBold
	b.ZIndex = 15
	b.Parent = parent

	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 6)
	cr.Parent = b

	local st = Instance.new("UIStroke")
	st.Thickness = 1
	st.Color = Color3.fromRGB(70, 50, 85)
	st.Parent = b

	b.Activated:Connect(cb)
	return b
end

createMiniBtn("✓ Pilih Semua", filterRow, function()
	local allUnits = CatalogModule and CatalogModule.AllUnits or {}
	for _, u in ipairs(allUnits) do
		selectedUnits[u.name:lower()] = true
		selectedUnits[u.displayName:lower()] = true
	end
	for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	Notify("Unit Target", "Seluruh unit berhasil dipilih!", 2)
end)

createMiniBtn("✗ Hapus Semua", filterRow, function()
	for k in pairs(selectedUnits) do selectedUnits[k] = nil end
	for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	Notify("Unit Target", "Seluruh target unit dibersihkan.", 2)
end)

createMiniBtn("👑 Secret & God Only", filterRow, function()
	for k in pairs(selectedUnits) do selectedUnits[k] = nil end
	local allUnits = CatalogModule and CatalogModule.AllUnits or {}
	for _, u in ipairs(allUnits) do
		if u.rarity == "Secret" or u.rarity == "God" or u.rarity == "Supreme" or u.rarity == "Limited" then
			selectedUnits[u.name:lower()] = true
			selectedUnits[u.displayName:lower()] = true
		end
	end
	for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	Notify("Unit Target", "Hanya Secret & God yang dipilih!", 2.5)
end)

UnitTab:AddSection("Daftar Unit Resmi (Anime Auto Roll)")

unitListHolder = Instance.new("Frame")
unitListHolder.Name = "UnitListHolder"
unitListHolder.Size = UDim2.new(1, 0, 0, 0)
unitListHolder.AutomaticSize = Enum.AutomaticSize.Y
unitListHolder.BackgroundTransparency = 1
unitListHolder.ZIndex = 13
unitListHolder.Parent = UnitTab.Page

local uListLayout = Instance.new("UIListLayout")
uListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uListLayout.Padding = UDim.new(0, 6)
uListLayout.Parent = unitListHolder

local function addUnitCard(unit)
	local card = Instance.new("Frame")
	card.Name = unit.name
	card.Size = UDim2.new(1, 0, 0, 48)
	card.BackgroundColor3 = Color3.fromRGB(24, 18, 32)
	card.BorderSizePixel = 0
	card.ZIndex = 14
	card.Parent = unitListHolder

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = card

	local cStroke = Instance.new("UIStroke")
	cStroke.Thickness = 1
	cStroke.Color = Color3.fromRGB(65, 48, 80)
	cStroke.Parent = card

	local checkBtn = Instance.new("TextLabel")
	checkBtn.Size = UDim2.new(0, 24, 0, 24)
	checkBtn.Position = UDim2.new(0, 10, 0.5, -12)
	local isSelected = selectedUnits[unit.name:lower()] or selectedUnits[unit.displayName:lower()]
	checkBtn.BackgroundColor3 = isSelected and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
	checkBtn.BorderSizePixel = 0
	checkBtn.Text = isSelected and "✓" or ""
	checkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	checkBtn.TextSize = 14
	checkBtn.Font = Enum.Font.GothamBold
	checkBtn.ZIndex = 15
	checkBtn.Parent = card

	local chkCorner = Instance.new("UICorner")
	chkCorner.CornerRadius = UDim.new(0, 6)
	chkCorner.Parent = checkBtn

	local rBadge = Instance.new("Frame")
	rBadge.Size = UDim2.new(0, 75, 0, 22)
	rBadge.Position = UDim2.new(0, 42, 0.5, -11)
	local colorMap = {
		Common = Color3.fromRGB(150, 150, 160),
		Rare = Color3.fromRGB(60, 160, 255),
		Epic = Color3.fromRGB(180, 80, 255),
		Legendary = Color3.fromRGB(255, 170, 40),
		Mythical = Color3.fromRGB(255, 70, 140),
		Secret = Color3.fromRGB(255, 215, 0),
		God = Color3.fromRGB(0, 240, 255),
		Supreme = Color3.fromRGB(255, 120, 0),
		Limited = Color3.fromRGB(255, 90, 200),
	}
	rBadge.BackgroundColor3 = colorMap[unit.rarity] or Color3.fromRGB(140, 140, 150)
	rBadge.BorderSizePixel = 0
	rBadge.ZIndex = 15
	rBadge.Parent = card

	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 4)
	rCorner.Parent = rBadge

	local rText = Instance.new("TextLabel")
	rText.Size = UDim2.new(1, 0, 1, 0)
	rText.BackgroundTransparency = 1
	rText.Text = unit.rarity
	rText.TextColor3 = Color3.fromRGB(255, 255, 255)
	rText.TextSize = 10
	rText.Font = Enum.Font.GothamBold
	rText.ZIndex = 16
	rText.Parent = rBadge

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.5, -130, 1, 0)
	nameLabel.Position = UDim2.new(0, 125, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = unit.displayName or unit.name
	nameLabel.TextColor3 = Color3.fromRGB(240, 230, 250)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 15
	nameLabel.Parent = card

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(0.3, 0, 1, 0)
	priceLabel.Position = UDim2.new(0.7, -12, 0, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = (unit.price and unit.price > 0) and ("💰 " .. tostring(unit.price)) or ""
	priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	priceLabel.TextSize = 11
	priceLabel.Font = Enum.Font.GothamMedium
	priceLabel.TextXAlignment = Enum.TextXAlignment.Right
	priceLabel.ZIndex = 15
	priceLabel.Parent = card

	local lastUnitClick = 0
	local function toggle()
		local now = tick()
		if now - lastUnitClick < 0.15 then return end
		lastUnitClick = now
		local newState = not (selectedUnits[unit.name:lower()] or selectedUnits[unit.displayName:lower()])
		selectedUnits[unit.name:lower()] = newState and true or nil
		selectedUnits[unit.displayName:lower()] = newState and true or nil
		
		checkBtn.BackgroundColor3 = newState and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
		checkBtn.Text = newState and "✓" or ""
		
		if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	end

	local fullClick = Instance.new("TextButton")
	fullClick.Size = UDim2.new(1, 0, 1, 0)
	fullClick.BackgroundTransparency = 1
	fullClick.Text = ""
	fullClick.ZIndex = 20
	fullClick.Active = true
	fullClick.Parent = card
	
	fullClick.Activated:Connect(toggle)
	fullClick.MouseButton1Click:Connect(toggle)

	local function syncUI()
		local state = selectedUnits[unit.name:lower()] or selectedUnits[unit.displayName:lower()]
		checkBtn.BackgroundColor3 = state and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
		checkBtn.Text = state and "✓" or ""
	end

	table.insert(unitCheckUpdaterCallbacks, {
		unit = unit,
		card = card,
		sync = syncUI
	})
end

local allUnits = CatalogModule and CatalogModule.AllUnits or {}
for _, u in ipairs(allUnits) do
	addUnitCard(u)
end

-- =================================================================
-- 3. TAB 🏃 PLAYER (SPEED & JUMP)
-- =================================================================
local PlayerTab = Window:CreateTab("Player", "🏃")

PlayerTab:AddSection("Pergerakan Karakter")

walkSpeedSliderRef = PlayerTab:AddSlider("WalkSpeed (Kecepatan Jalan)", 16, 250, savedConfig.WalkSpeed or 16, function(val)
	savedConfig.WalkSpeed = val
	applyPlayerWalkSpeed(val)
	if ConfigManager then ConfigManager.Save({ WalkSpeed = val }) end
end)

jumpPowerSliderRef = PlayerTab:AddSlider("JumpPower (Kekuatan Lompat)", 50, 300, savedConfig.JumpPower or 50, function(val)
	savedConfig.JumpPower = val
	applyPlayerJumpPower(val)
	if ConfigManager then ConfigManager.Save({ JumpPower = val }) end
end)

infJumpToggleRef = PlayerTab:AddToggle("Infinite Jump (Lompat Tanpa Batas)", savedConfig.InfJump or false, function(state)
	savedConfig.InfJump = state
	_G.InfJump = state
	if ConfigManager then ConfigManager.Save({ InfJump = state }) end
end)

UserInputService.JumpRequest:Connect(function()
	if _G.InfJump then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

PlayerTab:AddSection("Anti-AFK & Server Koneksi")
PlayerTab:AddToggle("Anti-AFK 24/7 (Bypass Idle Disconnect)", true, function(state)
	if state then
		if AFKModule and typeof(AFKModule.Enable) == "function" then AFKModule.Enable() end
		Notify("Anti-AFK", "Anti-AFK diaktifkan.", 2)
	else
		if AFKModule and typeof(AFKModule.Disable) == "function" then AFKModule.Disable() end
		Notify("Anti-AFK", "Anti-AFK dinonaktifkan.", 2)
	end
end)
PlayerTab:AddButton("🏝️ Teleport ke Private Server (Solo Island)", function()
	if PrivateServerModule then
		PrivateServerModule.JoinPrivateServer(Notify)
	end
end)

-- =================================================================
-- 4. TAB 🎁 QUESTS & HADIAH
-- =================================================================
local QuestsTab = Window:CreateTab("Quests & Hadiah", "🎁")

QuestsTab:AddSection("Klaim Hadiah Otomatis 24/7")

questToggleRef = QuestsTab:AddToggle("Auto Claim Quests (Daily & Weekly)", savedConfig.AutoClaimQuests ~= false, function(state)
	savedConfig.AutoClaimQuests = state
	if ConfigManager then ConfigManager.Save({ AutoClaimQuests = state }) end
	if AutoClaimModule then
		AutoClaimModule.Config.DailyQuest = state
		AutoClaimModule.Config.WeeklyQuest = state
	end
	Notify("Auto Quests", state and "Auto Claim Quests AKTIF!" or "Auto Claim Quests NONAKTIF", 2)
end)

rewardsToggleRef = QuestsTab:AddToggle("Auto Claim Free Rewards & Battlepass", savedConfig.AutoClaimRewards ~= false, function(state)
	savedConfig.AutoClaimRewards = state
	if ConfigManager then ConfigManager.Save({ AutoClaimRewards = state }) end
	if AutoClaimModule then
		AutoClaimModule.Config.Battlepass = state
		AutoClaimModule.Config.FreeRewards = state
		AutoClaimModule.Config.VIPAndGroup = state
	end
	Notify("Auto Rewards", state and "Auto Claim Rewards AKTIF!" or "Auto Claim Rewards NONAKTIF", 2)
end)

autoSpinWheelToggleRef = QuestsTab:AddToggle("Auto Spin Wheel (Free & Earned Spins)", savedConfig.AutoSpinWheel ~= false, function(state)
	savedConfig.AutoSpinWheel = state
	if ConfigManager then ConfigManager.Save({ AutoSpinWheel = state }) end
	if AutoClaimModule then
		AutoClaimModule.Config.AutoSpinWheel = state
	end
	Notify("Spin Wheel", state and "Auto Spin Wheel AKTIF!" or "Auto Spin Wheel NONAKTIF", 2)
end)

QuestsTab:AddButton("🎡 Putar Spin Wheel Sekarang (1x)", function()
	if AutoClaimModule then
		local didSpin = AutoClaimModule.PerformSpinWheel()
		Notify("Spin Wheel", didSpin and "Berhasil memutar Spin Wheel!" or "Tidak ada tiket spin gratis/tersedia.", 2.5)
	end
end)

QuestsTab:AddButton("🎁 Klaim Semua Hadiah & Spin Sekarang (1x)", function()
	if AutoClaimModule then
		local count = AutoClaimModule.ClaimAllNow()
		Notify("Klaim Hadiah", "Seluruh hadiah quests, battlepass & spin wheel diproses!", 3)
	end
end)

-- =================================================================
-- 5. TAB 🛒 MERCHANT
-- =================================================================
local MerchantTab = Window:CreateTab("Merchant", "🛒")

MerchantTab:AddSection("Auto Buy Traveling Merchant")

merchantToggleRef = MerchantTab:AddToggle("Auto Buy Merchant (Traveling Trader)", savedConfig.AutoBuyMerchant ~= false, function(state)
	savedConfig.AutoBuyMerchant = state
	if ConfigManager then ConfigManager.Save({ AutoBuyMerchant = state }) end
	if AutoMerchantModule then
		if state then
			AutoMerchantModule.Start({
				Enabled         = true,
				BuyAllStock     = savedConfig.MerchantBuyAll or false,
				BuyPotions      = savedConfig.MerchantBuyPotions ~= false,
				BuyEssences     = savedConfig.MerchantBuyEssences ~= false,
				BuyCapsules     = savedConfig.MerchantBuyCapsules ~= false,
				BuyTickets      = savedConfig.MerchantBuyTickets ~= false,
				BuyMaterials    = savedConfig.MerchantBuyMaterials ~= false,
				SelectedItems   = savedConfig.MerchantSelectedItems or {},
				MinGoldReserve  = savedConfig.MerchantMinGold or 0,
			})
		else
			AutoMerchantModule.Stop()
		end
	end
	Notify("Auto Merchant", state and "Auto Buy Merchant AKTIF!" or "Auto Buy Merchant NONAKTIF", 2)
end)

merchantBuyAllToggleRef = MerchantTab:AddToggle("Beli Seluruh Stok (Buy All Stock)", savedConfig.MerchantBuyAll or false, function(state)
	savedConfig.MerchantBuyAll = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyAll = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyAllStock = state end
end)

merchantPotionsToggleRef = MerchantTab:AddToggle("Beli Potions & Elixirs", savedConfig.MerchantBuyPotions ~= false, function(state)
	savedConfig.MerchantBuyPotions = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyPotions = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyPotions = state end
end)

merchantEssencesToggleRef = MerchantTab:AddToggle("Beli Essences", savedConfig.MerchantBuyEssences ~= false, function(state)
	savedConfig.MerchantBuyEssences = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyEssences = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyEssences = state end
end)

merchantCapsulesToggleRef = MerchantTab:AddToggle("Beli Capsules & Orbs", savedConfig.MerchantBuyCapsules ~= false, function(state)
	savedConfig.MerchantBuyCapsules = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyCapsules = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyCapsules = state end
end)

merchantTicketsToggleRef = MerchantTab:AddToggle("Beli Tickets & Passes", savedConfig.MerchantBuyTickets ~= false, function(state)
	savedConfig.MerchantBuyTickets = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyTickets = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyTickets = state end
end)

merchantMaterialsToggleRef = MerchantTab:AddToggle("Beli Crafting Materials", savedConfig.MerchantBuyMaterials ~= false, function(state)
	savedConfig.MerchantBuyMaterials = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyMaterials = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyMaterials = state end
end)

MerchantTab:AddButton("🛒 Beli Semua Stok Merchant Sekarang", function()
	if AutoMerchantModule then
		local bought = AutoMerchantModule.BuyAllNow()
		Notify("Merchant", string.format("Berhasil membeli %d item dari Merchant!", bought), 3)
	end
end)

-- =================================================================
-- 6. TAB ⚡ OPTIMASI & GRAFIS
-- =================================================================
local MiscTab = Window:CreateTab("Optimasi", "⚡")

MiscTab:AddSection("Grafis & Anti-Lag Engine")

potatoToggleRef = MiscTab:AddToggle("🥔 Potato Graphics (SmoothPlastic & Anti-Lag)", savedConfig.PotatoGraphics or false, function(state)
	savedConfig.PotatoGraphics = state
	if ConfigManager then ConfigManager.Save({ PotatoGraphics = state }) end
	if GraphicsModule then
		if state then GraphicsModule.EnablePotatoGraphics() else GraphicsModule.DisablePotatoGraphics() end
	end
end)

hideOtherPlayersToggleRef = MiscTab:AddToggle("👻 Sembunyikan Player & Plot Lain (Ghost Mode)", savedConfig.HideOtherPlayers or false, function(state)
	savedConfig.HideOtherPlayers = state
	if ConfigManager then ConfigManager.Save({ HideOtherPlayers = state }) end
	if GraphicsModule then
		if state then GraphicsModule.HideOtherPlayers() else GraphicsModule.ShowOtherPlayers() end
	end
end)

freezeNPCsToggleRef = MiscTab:AddToggle("🤖 Pause Animasi Musuh & NPC (Max CPU Saver)", savedConfig.FreezeNPCs or false, function(state)
	savedConfig.FreezeNPCs = state
	if ConfigManager then ConfigManager.Save({ FreezeNPCs = state }) end
	if GraphicsModule then
		if state then GraphicsModule.FreezeAllNPCsAndAnimations() else GraphicsModule.UnfreezeNPCs() end
	end
end)

disableVFXToggleRef = MiscTab:AddToggle("💀 Matikan Semua VFX & Partikel Skill", savedConfig.DisableVFX or false, function(state)
	savedConfig.DisableVFX = state
	if ConfigManager then ConfigManager.Save({ DisableVFX = state }) end
	if GraphicsModule then
		if state then GraphicsModule.DisableAllVFX() else GraphicsModule.RestoreVFX() end
	end
end)

antiLagToggleRef = MiscTab:AddToggle("❄️ Anti-Lag AFK (FPS Cap 10)", savedConfig.AntiLag or false, function(state)
	savedConfig.AntiLag = state
	if ConfigManager then ConfigManager.Save({ AntiLag = state }) end
	if GraphicsModule then GraphicsModule.SetAntiLag(state) end
end)

fpsCapSliderRef = MiscTab:AddSlider("🎯 Batas FPS (FPS Cap)", 5, 240, savedConfig.TargetFPS or 60, function(val)
	savedConfig.TargetFPS = val
	if ConfigManager then ConfigManager.Save({ TargetFPS = val }) end
	if GraphicsModule then GraphicsModule.ApplyFpsCap(val) end
end)

farmModeToggleRef = MiscTab:AddToggle("🌑 AMOLED Screen Off / Farm Mode (Engine 3D Off)", savedConfig.FarmMode or false, function(state)
	savedConfig.FarmMode = state
	if ConfigManager then ConfigManager.Save({ FarmMode = state }) end
	if GraphicsModule then
		GraphicsModule.SetFarmMode(state, function(newState)
			if farmModeToggleRef then farmModeToggleRef:Set(newState, false) end
		end)
	end
end)

MiscTab:AddButton("⚡ Aktifkan Semua Optimasi (One-Click Max FPS)", function()
	if GraphicsModule then
		GraphicsModule.EnableUltraPotato()
		if potatoToggleRef then potatoToggleRef:Set(true, false) end
		if hideOtherPlayersToggleRef then hideOtherPlayersToggleRef:Set(true, false) end
		if freezeNPCsToggleRef then freezeNPCsToggleRef:Set(true, false) end
		if disableVFXToggleRef then disableVFXToggleRef:Set(true, false) end
		savedConfig.PotatoGraphics = true
		savedConfig.HideOtherPlayers = true
		savedConfig.FreezeNPCs = true
		savedConfig.DisableVFX = true
		if ConfigManager then ConfigManager.Save(savedConfig) end
		Notify("⚡ Ultra FPS", "Seluruh optimasi grafis & CPU berhasil diaktifkan!", 3)
	end
end)

MiscTab:AddButton("🧹 Bersihkan Memori RAM (Purge GC)", function()
	pcall(function()
		collectgarbage("collect")
		if typeof(gcinfo) == "function" then gcinfo() end
	end)
	Notify("🧹 RAM Cleanup", "Memori Lua & aset yang tidak terpakai telah dibersihkan!", 2.5)
end)

MiscTab:AddSection("In-Game Settings (Screenshot Setup)")

autoGameSettingsToggleRef = MiscTab:AddToggle("🎮 Auto Apply Game Settings (FPS Boost, No SFX, Hide Animes)", savedConfig.AutoApplyGameSettings ~= false, function(state)
	savedConfig.AutoApplyGameSettings = state
	if ConfigManager then ConfigManager.Save({ AutoApplyGameSettings = state }) end
	if GraphicsModule then
		if state then
			GraphicsModule.ApplyGameSettingsPreset()
			GraphicsModule.StartGameSettingsWatchdog(10)
		else
			GraphicsModule.StopGameSettingsWatchdog()
		end
	end
end)

MiscTab:AddButton("⚡ Terapkan Settingan Game Sekarang (Screenshot Preset)", function()
	if GraphicsModule then
		GraphicsModule.ApplyGameSettingsPreset()
		Notify("🎮 Game Settings", "Settingan in-game (FPS Boost ON, Effects OFF, Hide Animes ON, SFX OFF) diterapkan!", 3)
	end
end)

MiscTab:AddSection("🏝️ Private Server & Solo Island")

autoPrivateServerToggleRef = MiscTab:AddToggle("Auto Private Server (Solo Island 24/7)", savedConfig.AutoPrivateServer or false, function(state)
	savedConfig.AutoPrivateServer = state
	if ConfigManager then ConfigManager.Save({ AutoPrivateServer = state }) end
	if PrivateServerModule then
		if state then PrivateServerModule.Start(Notify) else PrivateServerModule.Stop() end
	end
	Notify("Solo Island", state and "Auto Private Server AKTIF!" or "Auto Private Server NONAKTIF", 2)
end)

MiscTab:AddButton("🏝️ Teleport ke Private Server (Solo Island) Sekarang", function()
	if PrivateServerModule then
		PrivateServerModule.JoinPrivateServer(Notify)
	end
end)

-- =================================================================
-- 🔧 CONFIG APPLICATOR & SETTINGS TAB
-- =================================================================
local function applyRollAnimeConfig(loaded)
	if not loaded or type(loaded) ~= "table" then return end
	for k, v in pairs(loaded) do savedConfig[k] = v end

	if huntToggleRef and loaded.AutoHuntEnabled ~= nil then
		huntToggleRef:Set(loaded.AutoHuntEnabled, false)
		if loaded.AutoHuntEnabled then task.spawn(startHunt) else task.spawn(stopHunt) end
	end

	if autoSniperToggleRef and loaded.AutoSniperOnly ~= nil then
		autoSniperToggleRef:Set(loaded.AutoSniperOnly, false)
		if loaded.AutoSniperOnly then task.spawn(startAutoSniper) else task.spawn(stopAutoSniper) end
	end

	if autoSecretGodToggleRef and loaded.AutoSecretGod ~= nil then
		autoSecretGodToggleRef:Set(loaded.AutoSecretGod, false)
		savedConfig.AutoSecretGod = loaded.AutoSecretGod
	end

	if autoQuestRollToggleRef and loaded.AutoQuestRollMode ~= nil then
		autoQuestRollToggleRef:Set(loaded.AutoQuestRollMode, false)
		savedConfig.AutoQuestRollMode = loaded.AutoQuestRollMode
	end

	if rollDelaySliderRef and loaded.RollInterval then
		rollDelaySliderRef:Set(loaded.RollInterval, false)
		rollInterval = loaded.RollInterval
	end

	if walkSpeedSliderRef and loaded.WalkSpeed then
		walkSpeedSliderRef:Set(loaded.WalkSpeed, false)
		applyPlayerWalkSpeed(loaded.WalkSpeed)
	end

	if jumpPowerSliderRef and loaded.JumpPower then
		jumpPowerSliderRef:Set(loaded.JumpPower, false)
		applyPlayerJumpPower(loaded.JumpPower)
	end

	if infJumpToggleRef and loaded.InfJump ~= nil then
		infJumpToggleRef:Set(loaded.InfJump, false)
		_G.InfJump = loaded.InfJump
	end

	if autoPrivateServerToggleRef and loaded.AutoPrivateServer ~= nil then
		autoPrivateServerToggleRef:Set(loaded.AutoPrivateServer, false)
		savedConfig.AutoPrivateServer = loaded.AutoPrivateServer
	end

	if questToggleRef and loaded.AutoClaimQuests ~= nil then
		questToggleRef:Set(loaded.AutoClaimQuests, false)
		savedConfig.AutoClaimQuests = loaded.AutoClaimQuests
		if AutoClaimModule then
			AutoClaimModule.Config.DailyQuest = loaded.AutoClaimQuests
			AutoClaimModule.Config.WeeklyQuest = loaded.AutoClaimQuests
		end
	end

	if rewardsToggleRef and loaded.AutoClaimRewards ~= nil then
		rewardsToggleRef:Set(loaded.AutoClaimRewards, false)
		savedConfig.AutoClaimRewards = loaded.AutoClaimRewards
		if AutoClaimModule then
			AutoClaimModule.Config.Battlepass = loaded.AutoClaimRewards
			AutoClaimModule.Config.FreeRewards = loaded.AutoClaimRewards
			AutoClaimModule.Config.VIPAndGroup = loaded.AutoClaimRewards
		end
	end

	if merchantToggleRef and loaded.AutoBuyMerchant ~= nil then
		merchantToggleRef:Set(loaded.AutoBuyMerchant, false)
		savedConfig.AutoBuyMerchant = loaded.AutoBuyMerchant
		if AutoMerchantModule then
			if loaded.AutoBuyMerchant then
				AutoMerchantModule.Start({
					Enabled         = true,
					BuyAllStock     = loaded.MerchantBuyAll or false,
					BuyPotions      = loaded.MerchantBuyPotions ~= false,
					BuyEssences     = loaded.MerchantBuyEssences ~= false,
					BuyCapsules     = loaded.MerchantBuyCapsules ~= false,
					BuyTickets      = loaded.MerchantBuyTickets ~= false,
					BuyMaterials    = loaded.MerchantBuyMaterials ~= false,
					SelectedItems   = loaded.MerchantSelectedItems or {},
					MinGoldReserve  = loaded.MerchantMinGold or 0,
				})
			else
				AutoMerchantModule.Stop()
			end
		end
	end

	if merchantBuyAllToggleRef and loaded.MerchantBuyAll ~= nil then
		merchantBuyAllToggleRef:Set(loaded.MerchantBuyAll, false)
		savedConfig.MerchantBuyAll = loaded.MerchantBuyAll
		if AutoMerchantModule then AutoMerchantModule.Config.BuyAllStock = loaded.MerchantBuyAll end
	end

	if merchantPotionsToggleRef and loaded.MerchantBuyPotions ~= nil then
		merchantPotionsToggleRef:Set(loaded.MerchantBuyPotions, false)
		savedConfig.MerchantBuyPotions = loaded.MerchantBuyPotions
		if AutoMerchantModule then AutoMerchantModule.Config.BuyPotions = loaded.MerchantBuyPotions end
	end

	if merchantEssencesToggleRef and loaded.MerchantBuyEssences ~= nil then
		merchantEssencesToggleRef:Set(loaded.MerchantBuyEssences, false)
		savedConfig.MerchantBuyEssences = loaded.MerchantBuyEssences
		if AutoMerchantModule then AutoMerchantModule.Config.BuyEssences = loaded.MerchantBuyEssences end
	end

	if merchantCapsulesToggleRef and loaded.MerchantBuyCapsules ~= nil then
		merchantCapsulesToggleRef:Set(loaded.MerchantBuyCapsules, false)
		savedConfig.MerchantBuyCapsules = loaded.MerchantBuyCapsules
		if AutoMerchantModule then AutoMerchantModule.Config.BuyCapsules = loaded.MerchantBuyCapsules end
	end

	if merchantTicketsToggleRef and loaded.MerchantBuyTickets ~= nil then
		merchantTicketsToggleRef:Set(loaded.MerchantBuyTickets, false)
		savedConfig.MerchantBuyTickets = loaded.MerchantBuyTickets
		if AutoMerchantModule then AutoMerchantModule.Config.BuyTickets = loaded.MerchantBuyTickets end
	end

	if merchantMaterialsToggleRef and loaded.MerchantBuyMaterials ~= nil then
		merchantMaterialsToggleRef:Set(loaded.MerchantBuyMaterials, false)
		savedConfig.MerchantBuyMaterials = loaded.MerchantBuyMaterials
		if AutoMerchantModule then AutoMerchantModule.Config.BuyMaterials = loaded.MerchantBuyMaterials end
	end

	if potatoToggleRef and loaded.PotatoGraphics ~= nil then
		potatoToggleRef:Set(loaded.PotatoGraphics, false)
		savedConfig.PotatoGraphics = loaded.PotatoGraphics
		if GraphicsModule then
			if loaded.PotatoGraphics then GraphicsModule.EnablePotatoGraphics() else GraphicsModule.DisablePotatoGraphics() end
		end
	end

	if hideOtherPlayersToggleRef and loaded.HideOtherPlayers ~= nil then
		hideOtherPlayersToggleRef:Set(loaded.HideOtherPlayers, false)
		savedConfig.HideOtherPlayers = loaded.HideOtherPlayers
		if GraphicsModule then
			if loaded.HideOtherPlayers then GraphicsModule.HideOtherPlayers() else GraphicsModule.ShowOtherPlayers() end
		end
	end

	if freezeNPCsToggleRef and loaded.FreezeNPCs ~= nil then
		freezeNPCsToggleRef:Set(loaded.FreezeNPCs, false)
		savedConfig.FreezeNPCs = loaded.FreezeNPCs
		if GraphicsModule then
			if loaded.FreezeNPCs then GraphicsModule.FreezeAllNPCsAndAnimations() else GraphicsModule.UnfreezeNPCs() end
		end
	end

	if disableVFXToggleRef and loaded.DisableVFX ~= nil then
		disableVFXToggleRef:Set(loaded.DisableVFX, false)
		savedConfig.DisableVFX = loaded.DisableVFX
		if GraphicsModule then
			if loaded.DisableVFX then GraphicsModule.DisableAllVFX() else GraphicsModule.RestoreVFX() end
		end
	end

	if antiLagToggleRef and loaded.AntiLag ~= nil then
		antiLagToggleRef:Set(loaded.AntiLag, false)
		savedConfig.AntiLag = loaded.AntiLag
		if GraphicsModule then GraphicsModule.SetAntiLag(loaded.AntiLag) end
	end

	if fpsCapSliderRef and loaded.TargetFPS then
		fpsCapSliderRef:Set(loaded.TargetFPS, false)
		savedConfig.TargetFPS = loaded.TargetFPS
		if GraphicsModule then GraphicsModule.ApplyFpsCap(loaded.TargetFPS) end
	end

	if farmModeToggleRef and loaded.FarmMode ~= nil then
		farmModeToggleRef:Set(loaded.FarmMode, false)
		savedConfig.FarmMode = loaded.FarmMode
		if GraphicsModule then GraphicsModule.SetFarmMode(loaded.FarmMode) end
	end

	if autoGameSettingsToggleRef and loaded.AutoApplyGameSettings ~= nil then
		autoGameSettingsToggleRef:Set(loaded.AutoApplyGameSettings, false)
		savedConfig.AutoApplyGameSettings = loaded.AutoApplyGameSettings
		if GraphicsModule then
			if loaded.AutoApplyGameSettings then
				GraphicsModule.ApplyGameSettingsPreset()
				GraphicsModule.StartGameSettingsWatchdog(10)
			else
				GraphicsModule.StopGameSettingsWatchdog()
			end
		end
	end

	if loaded.SelectedUnits and type(loaded.SelectedUnits) == "table" then
		for k in pairs(selectedUnits) do selectedUnits[k] = nil end
		for name, val in pairs(loaded.SelectedUnits) do
			if val then selectedUnits[tostring(name):lower()] = true end
		end
		for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	end
end

local function getCurrentConfigTable()
	return {
		AutoHuntEnabled       = (AutoRollModule and AutoRollModule.IsRunning()) or savedConfig.AutoHuntEnabled or false,
		AutoSniperOnly        = (AutoRollModule and AutoRollModule.IsSniperRunning()) or savedConfig.AutoSniperOnly or false,
		AutoSecretGod         = savedConfig.AutoSecretGod or false,
		AutoPrivateServer     = savedConfig.AutoPrivateServer ~= false,
		AutoClaimQuests       = savedConfig.AutoClaimQuests ~= false,
		AutoClaimRewards      = savedConfig.AutoClaimRewards ~= false,
		AutoBuyMerchant       = savedConfig.AutoBuyMerchant ~= false,
		MerchantBuyAll        = savedConfig.MerchantBuyAll or false,
		MerchantBuyPotions    = savedConfig.MerchantBuyPotions ~= false,
		MerchantBuyEssences   = savedConfig.MerchantBuyEssences ~= false,
		MerchantBuyCapsules   = savedConfig.MerchantBuyCapsules ~= false,
		MerchantBuyTickets    = savedConfig.MerchantBuyTickets ~= false,
		MerchantBuyMaterials  = savedConfig.MerchantBuyMaterials ~= false,
		MerchantSelectedItems = savedConfig.MerchantSelectedItems or {},
		MerchantMinGold       = savedConfig.MerchantMinGold or 0,
		RollInterval          = rollInterval or 2.5,
		SelectedUnits         = selectedUnits,
		WalkSpeed             = savedConfig.WalkSpeed or 16,
		JumpPower             = savedConfig.JumpPower or 50,
		InfJump               = savedConfig.InfJump or false,
		PotatoGraphics        = savedConfig.PotatoGraphics or false,
		FarmMode              = savedConfig.FarmMode or false,
		AntiLag               = savedConfig.AntiLag or false,
		HideOtherPlayers      = savedConfig.HideOtherPlayers or false,
		FreezeNPCs            = savedConfig.FreezeNPCs or false,
		DisableVFX            = savedConfig.DisableVFX or false,
		AutoApplyGameSettings = savedConfig.AutoApplyGameSettings ~= false,
		TargetFPS             = savedConfig.TargetFPS or 60
	}
end

Window:CreateSettingsTab({
	GameFolder = "RitodHub/RollAnimeForFight",
	DefaultConfig = ConfigManager and ConfigManager.DefaultConfig or {},
	GetCurrentConfig = getCurrentConfigTable,
	ApplyConfig = applyRollAnimeConfig,
	ScriptUrl = "https://raw.githubusercontent.com/RyuZeed/capybara/refs/heads/main/roll_anime.lua"
})

-- Auto-Save Daemon
_G.AutoSaveDaemonThread = task.spawn(function()
	while true do
		task.wait(60)
		if ConfigManager then
			pcall(function() ConfigManager.Save(getCurrentConfigTable()) end)
		end
	end
end)

-- Auto-Resume on Startup
if savedConfig.AutoHuntEnabled then
	task.spawn(function()
		task.wait(0.5)
		startHunt()
	end)
elseif savedConfig.AutoSniperOnly then
	task.spawn(function()
		task.wait(0.5)
		startAutoSniper()
	end)
end

Notify("⚡ RITOD Hub", "Roll Anime for Fight (Shared RitodUI) berhasil dimuat!", 3)
