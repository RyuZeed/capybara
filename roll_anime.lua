--[[
	===============================================================
	⚡ RITOD HUB - ROLL ANIME FOR FIGHT (MODULAR EDITION)
	Game: Roll Anime For Fight / Anime Auto Roll
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🧩 MODULE DIRECTORY: modules/roll_anime/
	  - anti_afk.lua
	  - config_manager.lua
	  - catalog.lua
	  - auto_roll.lua
	- 📁 PERSISTENT CONFIG: RitodHub/RollAnimeForFight/<Username>.json
	- 🛡️ BULLETPROOF ANTI-AFK: 3-Layer Hardware Keypulse & Idled Interception
	- 🔄 AUTO-RESUME: Otomatis lanjut roll jika sesi sebelumnya aktif
	- 🌟 STRICT CATALOG: 13 Secret & 14 God Unit Asli
	- 🖥️ ULTRA HD GUI (700x460) with Neon Floating Widget & Minimize
	===============================================================
]]

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.3)

-- 🔒 GLOBAL MUTEX LOCK: Cegah double execution (queue_on_teleport + autoexec race)
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
    -- 1. Panggil destructor sesi sebelumnya jika ada
    if typeof(_G.RitodHubCleanup) == "function" then
        _G.RitodHubCleanup()
    end

    -- 2. Hentikan seluruh modul dan thread background yang aktif
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

    -- 3. Hapus paksa seluruh ScreenGui UI lama (gethui, CoreGui & PlayerGui)
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
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/refs/heads/main/modules/roll_anime/"
local SHARED_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/refs/heads/main/modules/shared/"

local function loadModule(name)
    -- 0. Cek memory global _G
    if name == "modern_settings" and _G.ModernSettings and typeof(_G.ModernSettings.CreateProfileManager) == "function" then
        return _G.ModernSettings
    end

    -- 1. Prioritaskan GitHub Cloud langsung
    local targetUrl = (name == "modern_settings" or name == "ritod_ui") and (SHARED_URL .. name .. ".lua?t=" .. tostring(os.time())) or (BASE_URL .. name .. ".lua?t=" .. tostring(os.time()))
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

    -- 2. Fallback Shared URL
    local s2, r2 = pcall(function()
        local src = game:HttpGet(SHARED_URL .. name .. ".lua")
        if src and #src > 10 and not src:find("404: Not Found") then
            local fn = loadstring(src)
            if fn then return fn() end
        end
        return nil
    end)
    if s2 and r2 then
        return r2
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
            DailyQuest  = savedConfig.AutoClaimQuests ~= false,
            WeeklyQuest = savedConfig.AutoClaimQuests ~= false,
            Battlepass  = savedConfig.AutoClaimRewards ~= false,
            FreeRewards = savedConfig.AutoClaimRewards ~= false,
            VIPAndGroup = savedConfig.AutoClaimRewards ~= false,
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
-- 🎨 GUI INITIALIZATION (ULTRA HD 700x460)
-- =================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RitodHubUltra"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local playerGui = player and (player:FindFirstChild("PlayerGui") or player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5))

local ok = false
if playerGui then
	ok = pcall(function() screenGui.Parent = playerGui end)
end
if not ok or not screenGui.Parent then
	if typeof(gethui) == "function" then
		pcall(function() screenGui.Parent = gethui() end)
	end
end
if not screenGui.Parent and CoreGui then
	pcall(function() screenGui.Parent = CoreGui end)
end

_G.RitodHubRollAnime = screenGui
_G.RitodHubGui = screenGui

-- ===================== DRAGGABLE & CLICK HANDLER =====================
local function makeDraggable(frame, dragHandle, onClick)
	dragHandle = dragHandle or frame
	local dragging = false
	local dragInput, dragStart, startPos
	local hasMoved = false

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			hasMoved = false
			dragStart = input.Position
			startPos = frame.Position
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			if delta.Magnitude > 6 then
				hasMoved = true
			end
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not hasMoved and onClick then
				onClick()
			end
		end
	end)
end

-- ===================== NOTIFICATION SYSTEM =====================
local notifHolder = Instance.new("Frame")
notifHolder.Name = "NotifHolder"
notifHolder.AnchorPoint = Vector2.new(1, 1)
notifHolder.Position = UDim2.new(1, -24, 1, -24)
notifHolder.Size = UDim2.new(0, 300, 1, -48)
notifHolder.BackgroundTransparency = 1
notifHolder.ZIndex = 200
notifHolder.Parent = screenGui

local notifList = Instance.new("UIListLayout")
notifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifList.Padding = UDim.new(0, 10)
notifList.Parent = notifHolder

local function Notify(title, desc, duration)
	task.spawn(function()
		pcall(function()
			duration = duration or 3.5
			local n = Instance.new("Frame")
			n.Size = UDim2.new(1, 0, 0, 64)
			n.BackgroundColor3 = Color3.fromRGB(18, 14, 24)
			n.BackgroundTransparency = 0.1
			n.BorderSizePixel = 0
			n.Position = UDim2.new(1, 100, 0, 0)
			n.ZIndex = 201
			n.Parent = notifHolder

			local nCorner = Instance.new("UICorner")
			nCorner.CornerRadius = UDim.new(0, 12)
			nCorner.Parent = n

			local nStroke = Instance.new("UIStroke")
			nStroke.Thickness = 1.4
			nStroke.Color = Color3.fromRGB(185, 90, 255)
			nStroke.Parent = n

			local nGlow = Instance.new("Frame")
			nGlow.Size = UDim2.new(0, 4, 1, -16)
			nGlow.Position = UDim2.new(0, 8, 0, 8)
			nGlow.BackgroundColor3 = Color3.fromRGB(185, 90, 255)
			nGlow.BorderSizePixel = 0
			nGlow.ZIndex = 202
			nGlow.Parent = n

			local ngCorner = Instance.new("UICorner")
			ngCorner.CornerRadius = UDim.new(1, 0)
			ngCorner.Parent = nGlow

			local nTitle = Instance.new("TextLabel")
			nTitle.Position = UDim2.new(0, 22, 0, 10)
			nTitle.Size = UDim2.new(1, -30, 0, 18)
			nTitle.BackgroundTransparency = 1
			nTitle.Text = tostring(title)
			nTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
			nTitle.TextSize = 14
			nTitle.Font = Enum.Font.GothamBold
			nTitle.TextXAlignment = Enum.TextXAlignment.Left
			nTitle.ZIndex = 202
			nTitle.Parent = n

			local nDesc = Instance.new("TextLabel")
			nDesc.Position = UDim2.new(0, 22, 0, 30)
			nDesc.Size = UDim2.new(1, -30, 0, 22)
			nDesc.BackgroundTransparency = 1
			nDesc.Text = tostring(desc)
			nDesc.TextColor3 = Color3.fromRGB(180, 165, 205)
			nDesc.TextSize = 12
			nDesc.Font = Enum.Font.Gotham
			nDesc.TextXAlignment = Enum.TextXAlignment.Left
			nDesc.TextTruncate = Enum.TextTruncate.AtEnd
			nDesc.ZIndex = 202
			nDesc.Parent = n

			TweenService:Create(n, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, 0, 0, 0)
			}):Play()

			task.delay(duration, function()
				pcall(function()
					local outTween = TweenService:Create(n, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Position = UDim2.new(1, 100, 0, 0),
						BackgroundTransparency = 1
					})
					outTween:Play()
					outTween.Completed:Connect(function()
						pcall(function() n:Destroy() end)
					end)
				end)
			end)
		end)
	end)
end

-- ==============================================================================
-- 🖥️ MAIN HUB WINDOW (700x460)
-- ==============================================================================
local cam = workspace.CurrentCamera
local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
local targetW = math.clamp(vp.X - 30, 340, 700)
local targetH = math.clamp(vp.Y - 30, 260, 460)

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainHub"
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size = UDim2.new(0, targetW, 0, targetH)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 10
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 1.6
mainStroke.Color = Color3.fromRGB(165, 85, 255)
mainStroke.Transparency = 0.4
mainStroke.Parent = mainFrame

-- TopBar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 50)
topBar.BackgroundColor3 = Color3.fromRGB(22, 17, 30)
topBar.BorderSizePixel = 0
topBar.ZIndex = 11
topBar.Parent = mainFrame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 16)
topCorner.Parent = topBar

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 16)
topFix.Position = UDim2.new(0, 0, 1, -16)
topFix.BackgroundColor3 = Color3.fromRGB(22, 17, 30)
topFix.BorderSizePixel = 0
topFix.ZIndex = 11
topFix.Parent = topBar

makeDraggable(mainFrame, topBar)

local hubTitle = Instance.new("TextLabel")
hubTitle.Position = UDim2.new(0, 18, 0, 0)
hubTitle.Size = UDim2.new(0, 320, 1, 0)
hubTitle.BackgroundTransparency = 1
hubTitle.RichText = true
hubTitle.Text = "<b><font color=\"#C875FF\">RITOD</font> HUB</b>"
hubTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
hubTitle.TextSize = 16
hubTitle.Font = Enum.Font.GothamBlack
hubTitle.TextXAlignment = Enum.TextXAlignment.Left
hubTitle.ZIndex = 12
hubTitle.Parent = topBar

local statsLabel = Instance.new("TextLabel")
statsLabel.AnchorPoint = Vector2.new(1, 0.5)
statsLabel.Position = UDim2.new(1, -95, 0.5, 0)
statsLabel.Size = UDim2.new(0, 160, 0, 24)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "FPS: 60  |  PING: 35ms"
statsLabel.TextColor3 = Color3.fromRGB(160, 145, 175)
statsLabel.TextSize = 11
statsLabel.Font = Enum.Font.GothamMedium
statsLabel.TextXAlignment = Enum.TextXAlignment.Right
statsLabel.ZIndex = 12
statsLabel.Parent = topBar

task.spawn(function()
	local lastTime = tick()
	local frameCount = 0
	RunService.RenderStepped:Connect(function()
		frameCount = frameCount + 1
		local curTime = tick()
		if curTime - lastTime >= 1 then
			local fps = math.floor(frameCount / (curTime - lastTime))
			local ping = math.floor(player:GetNetworkPing() * 1000)
			statsLabel.Text = string.format("FPS: %d  |  PING: %dms", fps, ping)
			frameCount = 0
			lastTime = curTime
		end
	end)
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.BackgroundColor3 = Color3.fromRGB(48, 22, 34)
closeBtn.AutoButtonColor = false
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 110, 130)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.ZIndex = 25
closeBtn.Active = true
closeBtn.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

local minBtn = Instance.new("TextButton")
minBtn.Name = "MinBtn"
minBtn.AnchorPoint = Vector2.new(1, 0.5)
minBtn.Position = UDim2.new(1, -50, 0.5, 0)
minBtn.Size = UDim2.new(0, 32, 0, 32)
minBtn.BackgroundColor3 = Color3.fromRGB(32, 26, 42)
minBtn.AutoButtonColor = false
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(180, 160, 205)
minBtn.TextSize = 18
minBtn.Font = Enum.Font.GothamBlack
minBtn.ZIndex = 25
minBtn.Active = true
minBtn.Parent = topBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 8)
minCorner.Parent = minBtn

closeBtn.MouseEnter:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(235, 45, 75), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(48, 22, 34), TextColor3 = Color3.fromRGB(255, 110, 130)}):Play()
end)

minBtn.MouseEnter:Connect(function()
	TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(55, 42, 70), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
end)
minBtn.MouseLeave:Connect(function()
	TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(32, 26, 42), TextColor3 = Color3.fromRGB(180, 160, 205)}):Play()
end)

-- Unload Modal
local modalOverlay = Instance.new("Frame")
modalOverlay.Name = "ModalOverlay"
modalOverlay.Size = UDim2.new(1, 0, 1, 0)
modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
modalOverlay.BackgroundTransparency = 1
modalOverlay.Visible = false
modalOverlay.ZIndex = 150
modalOverlay.Parent = mainFrame

local modalBox = Instance.new("Frame")
modalBox.Name = "ModalBox"
modalBox.AnchorPoint = Vector2.new(0.5, 0.5)
modalBox.Position = UDim2.new(0.5, 0, 0.5, 0)
modalBox.Size = UDim2.new(0, 360, 0, 175)
modalBox.BackgroundColor3 = Color3.fromRGB(22, 17, 28)
modalBox.BorderSizePixel = 0
modalBox.ZIndex = 151
modalBox.Parent = modalOverlay

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 14)
modalCorner.Parent = modalBox

local modalStroke = Instance.new("UIStroke")
modalStroke.Thickness = 1.8
modalStroke.Color = Color3.fromRGB(255, 75, 100)
modalStroke.Parent = modalBox

local mTitle = Instance.new("TextLabel")
mTitle.Position = UDim2.new(0, 0, 0, 18)
mTitle.Size = UDim2.new(1, 0, 0, 24)
mTitle.BackgroundTransparency = 1
mTitle.Text = "⚠️ Unload RITOD Hub?"
mTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
mTitle.TextSize = 16
mTitle.Font = Enum.Font.GothamBold
mTitle.ZIndex = 152
mTitle.Parent = modalBox

local mDesc = Instance.new("TextLabel")
mDesc.Position = UDim2.new(0, 24, 0, 48)
mDesc.Size = UDim2.new(1, -48, 0, 40)
mDesc.BackgroundTransparency = 1
mDesc.Text = "Apakah kamu yakin ingin menutup dan menghentikan seluruh script Auto Roll?"
mDesc.TextColor3 = Color3.fromRGB(180, 165, 195)
mDesc.TextSize = 12
mDesc.Font = Enum.Font.GothamMedium
mDesc.TextWrapped = true
mDesc.ZIndex = 152
mDesc.Parent = modalBox

local yesBtn = Instance.new("TextButton")
yesBtn.AnchorPoint = Vector2.new(0, 1)
yesBtn.Position = UDim2.new(0, 24, 1, -18)
yesBtn.Size = UDim2.new(0, 145, 0, 38)
yesBtn.BackgroundColor3 = Color3.fromRGB(235, 45, 75)
yesBtn.AutoButtonColor = false
yesBtn.Text = "Yes, Unload"
yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
yesBtn.TextSize = 13
yesBtn.Font = Enum.Font.GothamBold
yesBtn.ZIndex = 153
yesBtn.Parent = modalBox

local yesCorner = Instance.new("UICorner")
yesCorner.CornerRadius = UDim.new(0, 8)
yesCorner.Parent = yesBtn

local cancelBtn = Instance.new("TextButton")
cancelBtn.AnchorPoint = Vector2.new(1, 1)
cancelBtn.Position = UDim2.new(1, -24, 1, -18)
cancelBtn.Size = UDim2.new(0, 145, 0, 38)
cancelBtn.BackgroundColor3 = Color3.fromRGB(40, 32, 48)
cancelBtn.AutoButtonColor = false
cancelBtn.Text = "Cancel"
cancelBtn.TextColor3 = Color3.fromRGB(200, 185, 215)
cancelBtn.TextSize = 13
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.ZIndex = 153
cancelBtn.Parent = modalBox

local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 8)
cancelCorner.Parent = cancelBtn

local function showUnloadModal()
	modalOverlay.Visible = true
	modalBox.Position = UDim2.new(0.5, 0, 0.55, 0)
	TweenService:Create(modalOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
	TweenService:Create(modalBox, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
end

local function hideUnloadModal()
	local t = TweenService:Create(modalOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 1})
	TweenService:Create(modalBox, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0.55, 0)}):Play()
	t:Play()
	t.Completed:Connect(function()
		modalOverlay.Visible = false
	end)
end

-- Floating Widget
local floatWidget = Instance.new("TextButton")
floatWidget.Name = "FloatWidget"
floatWidget.AnchorPoint = Vector2.new(0, 0.5)
floatWidget.Position = UDim2.new(0, 24, 0.5, 0)
floatWidget.Size = UDim2.new(0, 56, 0, 56)
floatWidget.BackgroundColor3 = Color3.fromRGB(20, 14, 28)
floatWidget.BorderSizePixel = 0
floatWidget.ZIndex = 100
floatWidget.AutoButtonColor = false
floatWidget.Text = ""
floatWidget.Active = true
floatWidget.Parent = screenGui

local floatCorner = Instance.new("UICorner")
floatCorner.CornerRadius = UDim.new(0, 18)
floatCorner.Parent = floatWidget

local floatStroke = Instance.new("UIStroke")
floatStroke.Thickness = 2.5
floatStroke.Color = Color3.fromRGB(190, 90, 255)
floatStroke.Transparency = 0.2
floatStroke.Parent = floatWidget

local strokeGrad = Instance.new("UIGradient")
strokeGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 160)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 210, 255)),
})
strokeGrad.Rotation = 45
strokeGrad.Parent = floatStroke

local floatBgGrad = Instance.new("UIGradient")
floatBgGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 20, 48)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 10, 24)),
})
floatBgGrad.Rotation = 90
floatBgGrad.Parent = floatWidget

local floatIcon = Instance.new("TextLabel")
floatIcon.Size = UDim2.new(1, 0, 1, 0)
floatIcon.BackgroundTransparency = 1
floatIcon.RichText = true
floatIcon.Text = "<b>R</b>"
floatIcon.TextColor3 = Color3.fromRGB(240, 200, 255)
floatIcon.TextSize = 24
floatIcon.Font = Enum.Font.GothamBlack
floatIcon.ZIndex = 101
floatIcon.Parent = floatWidget

local statusDot = Instance.new("Frame")
statusDot.AnchorPoint = Vector2.new(1, 0)
statusDot.Position = UDim2.new(1, -6, 0, 6)
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.BackgroundColor3 = Color3.fromRGB(70, 255, 140)
statusDot.BorderSizePixel = 0
statusDot.ZIndex = 102
statusDot.Parent = floatWidget

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(1, 0)
statusCorner.Parent = statusDot

local statusStroke = Instance.new("UIStroke")
statusStroke.Thickness = 2
statusStroke.Color = Color3.fromRGB(20, 14, 28)
statusStroke.Parent = statusDot

task.spawn(function()
	while floatWidget and floatWidget.Parent do
		pcall(function()
			if floatStroke and floatStroke.Parent and statusDot and statusDot.Parent then
				TweenService:Create(floatStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Thickness = 3.5, Transparency = 0}):Play()
				TweenService:Create(statusDot, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = Color3.fromRGB(120, 255, 180)}):Play()
			end
		end)
		task.wait(1.2)
		pcall(function()
			if floatStroke and floatStroke.Parent and statusDot and statusDot.Parent then
				TweenService:Create(floatStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Thickness = 2.0, Transparency = 0.4}):Play()
				TweenService:Create(statusDot, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = Color3.fromRGB(40, 200, 100)}):Play()
			end
		end)
		task.wait(1.2)
	end
end)

local isHubVisible = true
local lastSavedPosition = mainFrame.Position

local function toggleHub()
	isHubVisible = not isHubVisible
	if isHubVisible then
		mainFrame.Visible = true
		mainFrame.Position = UDim2.new(lastSavedPosition.X.Scale, lastSavedPosition.X.Offset, lastSavedPosition.Y.Scale, lastSavedPosition.Y.Offset + 30)
		TweenService:Create(mainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = lastSavedPosition
		}):Play()
	else
		lastSavedPosition = mainFrame.Position
		local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(lastSavedPosition.X.Scale, lastSavedPosition.X.Offset, lastSavedPosition.Y.Scale, lastSavedPosition.Y.Offset + 30)
		})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			if not isHubVisible then
				mainFrame.Visible = false
			end
		end)
	end
end

makeDraggable(floatWidget, floatWidget, function()
	toggleHub()
end)
floatWidget.Activated:Connect(function()
	toggleHub()
end)

closeBtn.Activated:Connect(function()
	showUnloadModal()
end)

minBtn.Activated:Connect(function()
	toggleHub()
end)

yesBtn.Activated:Connect(function()
	Notify("RITOD Hub", "Unloading script & stopping all tasks...", 2)
	
	if typeof(_G.RitodHubCleanup) == "function" then
		_G.RitodHubCleanup()
	end
	if AutoRollModule then
		pcall(function() AutoRollModule.Stop() end)
		pcall(function() AutoRollModule.StopAutoSniper() end)
	end
	if AutoClaimModule then
		pcall(function() AutoClaimModule.Stop() end)
	end
	if GraphicsModule and typeof(GraphicsModule.Unload) == "function" then
		pcall(function() GraphicsModule.Unload() end)
	end
	if AFKModule then
		pcall(function() AFKModule.Disable() end)
	end
	if _G.InfJumpConn then
		pcall(function() _G.InfJumpConn:Disconnect() end)
		_G.InfJumpConn = nil
	end
	_G.InfJump = false
	
	TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset, 1.2, 0)
	}):Play()
	TweenService:Create(floatWidget, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	
	task.wait(0.35)
	pcall(function() screenGui:Destroy() end)
	_G.RitodHubRollAnime = nil
end)

cancelBtn.Activated:Connect(function()
	hideUnloadModal()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
		toggleHub()
	end
end)

-- Sidebar
local sideBar = Instance.new("Frame")
sideBar.Name = "SideBar"
sideBar.Position = UDim2.new(0, 0, 0, 50)
sideBar.Size = UDim2.new(0, 165, 1, -50)
sideBar.BackgroundColor3 = Color3.fromRGB(18, 14, 25)
sideBar.BorderSizePixel = 0
sideBar.ZIndex = 11
sideBar.Parent = mainFrame

local tabList = Instance.new("UIListLayout")
tabList.Padding = UDim.new(0, 6)
tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabList.SortOrder = Enum.SortOrder.LayoutOrder
tabList.Parent = sideBar

local sidePadding = Instance.new("UIPadding")
sidePadding.PaddingTop = UDim.new(0, 14)
sidePadding.PaddingLeft = UDim.new(0, 10)
sidePadding.PaddingRight = UDim.new(0, 10)
sidePadding.Parent = sideBar

-- Content Area
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Position = UDim2.new(0, 165, 0, 50)
contentArea.Size = UDim2.new(1, -165, 1, -50)
contentArea.BackgroundTransparency = 1
contentArea.ZIndex = 11
contentArea.Parent = mainFrame

-- ==============================================================================
-- 🛠️ UI LIBRARY COMPONENT BUILDER
-- ==============================================================================
local RitodLib = {}
local tabs = {}
local activeTab = nil
local unitCheckUpdaterCallbacks = {}

local selectedUnits = savedConfig.SelectedUnits or {}
-- Default target if empty: Secret & God
if CatalogModule and next(selectedUnits) == nil then
    for _, u in ipairs(CatalogModule.UnitsByRarity["Secret"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
    for _, u in ipairs(CatalogModule.UnitsByRarity["God"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
end

local totalAcquiredCount = 0
local rollInterval = savedConfig.RollInterval or 2.5

function RitodLib:CreateTab(name, icon)
	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = name .. "Tab"
	tabBtn.Size = UDim2.new(1, 0, 0, 38)
	tabBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 40)
	tabBtn.BackgroundTransparency = 1
	tabBtn.AutoButtonColor = false
	tabBtn.RichText = true
	tabBtn.Text = name
	tabBtn.TextColor3 = Color3.fromRGB(160, 140, 175)
	tabBtn.TextSize = 13
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextXAlignment = Enum.TextXAlignment.Left
	tabBtn.ZIndex = 12
	tabBtn.Parent = sideBar

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 10)
	tabCorner.Parent = tabBtn

	local tPad = Instance.new("UIPadding")
	tPad.PaddingLeft = UDim.new(0, 12)
	tPad.Parent = tabBtn

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 4, 0, 20)
	indicator.AnchorPoint = Vector2.new(0, 0.5)
	indicator.Position = UDim2.new(0, -8, 0.5, 0)
	indicator.BackgroundColor3 = Color3.fromRGB(190, 90, 255)
	indicator.BackgroundTransparency = 1
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 13
	indicator.Parent = tabBtn

	local indCorner = Instance.new("UICorner")
	indCorner.CornerRadius = UDim.new(1, 0)
	indCorner.Parent = indicator

	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = Color3.fromRGB(180, 90, 255)
	page.Visible = false
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.ZIndex = 12
	page.Parent = contentArea

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Padding = UDim.new(0, 10)
	pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Parent = page

	local pagePad = Instance.new("UIPadding")
	pagePad.PaddingTop = UDim.new(0, 14)
	pagePad.PaddingLeft = UDim.new(0, 16)
	pagePad.PaddingRight = UDim.new(0, 16)
	pagePad.PaddingBottom = UDim.new(0, 16)
	pagePad.Parent = page

	local function selectTab()
		for _, t in pairs(tabs) do
			TweenService:Create(t.btn, TweenInfo.new(0.2), {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(160, 140, 175)}):Play()
			TweenService:Create(t.indicator, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
			t.page.Visible = false
		end
		activeTab = name
		TweenService:Create(tabBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = Color3.fromRGB(150, 65, 240)}):Play()
		TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
		page.Visible = true
	end

	tabBtn.Activated:Connect(selectTab)
	tabs[name] = {btn = tabBtn, page = page, indicator = indicator}

	if not activeTab then
		selectTab()
	end

	local elements = {}

	function elements:AddSection(title)
		local sec = Instance.new("Frame")
		sec.Size = UDim2.new(1, 0, 0, 26)
		sec.BackgroundTransparency = 1
		sec.ZIndex = 13
		sec.Parent = page

		local sLabel = Instance.new("TextLabel")
		sLabel.Size = UDim2.new(1, 0, 1, 0)
		sLabel.BackgroundTransparency = 1
		sLabel.Text = string.upper(title)
		sLabel.TextColor3 = Color3.fromRGB(180, 120, 255)
		sLabel.TextSize = 11
		sLabel.Font = Enum.Font.GothamBold
		sLabel.TextXAlignment = Enum.TextXAlignment.Left
		sLabel.ZIndex = 13
		sLabel.Parent = sec
	end

	function elements:AddButton(text, callback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 42)
		btn.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
		btn.AutoButtonColor = false
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(235, 225, 245)
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamBold
		btn.ZIndex = 14
		btn.Parent = page

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 10)
		bCorner.Parent = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Thickness = 1
		bStroke.Color = Color3.fromRGB(70, 50, 85)
		bStroke.Parent = btn

		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(48, 32, 65)}):Play()
			TweenService:Create(bStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(180, 90, 255)}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26, 20, 34)}):Play()
			TweenService:Create(bStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(70, 50, 85)}):Play()
		end)
		btn.Activated:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(0.98, 0, 0, 39)}):Play()
			task.wait(0.08)
			TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(1, 0, 0, 42)}):Play()
			if callback then callback() end
		end)
		return btn
	end

	function elements:AddToggle(text, default, callback)
		local state = default or false
		local toggleFrame = Instance.new("Frame")
		toggleFrame.Size = UDim2.new(1, 0, 0, 44)
		toggleFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
		toggleFrame.BorderSizePixel = 0
		toggleFrame.ZIndex = 14
		toggleFrame.Parent = page

		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 10)
		tCorner.Parent = toggleFrame

		local tLabel = Instance.new("TextLabel")
		tLabel.Position = UDim2.new(0, 14, 0, 0)
		tLabel.Size = UDim2.new(1, -80, 1, 0)
		tLabel.BackgroundTransparency = 1
		tLabel.Text = text
		tLabel.TextColor3 = Color3.fromRGB(235, 225, 245)
		tLabel.TextSize = 13
		tLabel.Font = Enum.Font.GothamMedium
		tLabel.TextXAlignment = Enum.TextXAlignment.Left
		tLabel.ZIndex = 15
		tLabel.Parent = toggleFrame

		local switch = Instance.new("Frame")
		switch.AnchorPoint = Vector2.new(1, 0.5)
		switch.Position = UDim2.new(1, -12, 0.5, 0)
		switch.Size = UDim2.new(0, 48, 0, 24)
		switch.BackgroundColor3 = state and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(50, 38, 60)
		switch.BorderSizePixel = 0
		switch.ZIndex = 15
		switch.Parent = toggleFrame

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(1, 0)
		sCorner.Parent = switch

		local knob = Instance.new("Frame")
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		knob.Size = UDim2.new(0, 18, 0, 18)
		knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		knob.BorderSizePixel = 0
		knob.ZIndex = 16
		knob.Parent = switch

		local kCorner = Instance.new("UICorner")
		kCorner.CornerRadius = UDim.new(1, 0)
		kCorner.Parent = knob

		local function updateToggle(fireCallback)
			if state then
				TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(175, 75, 255)}):Play()
				TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(1, -21, 0.5, 0)}):Play()
			else
				TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 38, 60)}):Play()
				TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.5, 0)}):Play()
			end
			if fireCallback and callback then callback(state) end
		end

		local fullClick = Instance.new("TextButton")
		fullClick.Size = UDim2.new(1, 0, 1, 0)
		fullClick.BackgroundTransparency = 1
		fullClick.Text = ""
		fullClick.ZIndex = 17
		fullClick.Parent = toggleFrame
		fullClick.Activated:Connect(function()
			state = not state
			updateToggle(true)
		end)

		return {
			Set = function(self, val, fireCallback)
				state = val
				updateToggle(fireCallback)
			end,
			Get = function(self)
				return state
			end
		}
	end

	function elements:AddSlider(text, min, max, default, callback)
		local val = default or min
		local sliderFrame = Instance.new("Frame")
		sliderFrame.Size = UDim2.new(1, 0, 0, 54)
		sliderFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
		sliderFrame.BorderSizePixel = 0
		sliderFrame.ZIndex = 14
		sliderFrame.Parent = page

		local sCorner = Instance.new("UICorner")
		sCorner.CornerRadius = UDim.new(0, 10)
		sCorner.Parent = sliderFrame

		local sLabel = Instance.new("TextLabel")
		sLabel.Position = UDim2.new(0, 14, 0, 10)
		sLabel.Size = UDim2.new(1, -90, 0, 16)
		sLabel.BackgroundTransparency = 1
		sLabel.Text = text
		sLabel.TextColor3 = Color3.fromRGB(235, 225, 245)
		sLabel.TextSize = 13
		sLabel.Font = Enum.Font.GothamMedium
		sLabel.TextXAlignment = Enum.TextXAlignment.Left
		sLabel.ZIndex = 15
		sLabel.Parent = sliderFrame

		local valLabel = Instance.new("TextLabel")
		valLabel.Position = UDim2.new(1, -70, 0, 10)
		valLabel.Size = UDim2.new(0, 56, 0, 16)
		valLabel.BackgroundTransparency = 1
		valLabel.Text = tostring(val)
		valLabel.TextColor3 = Color3.fromRGB(205, 140, 255)
		valLabel.TextSize = 13
		valLabel.Font = Enum.Font.GothamBold
		valLabel.TextXAlignment = Enum.TextXAlignment.Right
		valLabel.ZIndex = 15
		valLabel.Parent = sliderFrame

		local barBack = Instance.new("Frame")
		barBack.Position = UDim2.new(0, 14, 0, 34)
		barBack.Size = UDim2.new(1, -28, 0, 7)
		barBack.BackgroundColor3 = Color3.fromRGB(48, 38, 58)
		barBack.BorderSizePixel = 0
		barBack.ZIndex = 15
		barBack.Parent = sliderFrame

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = barBack

		local barFill = Instance.new("Frame")
		local initRatio = math.clamp((val - min) / (max - min), 0, 1)
		barFill.Size = UDim2.new(initRatio, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.fromRGB(180, 85, 255)
		barFill.BorderSizePixel = 0
		barFill.ZIndex = 16
		barFill.Parent = barBack

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = barFill

		local sliding = false
		local function setSlider(input)
			local pos = UDim2.new(math.clamp((input.Position.X - barBack.AbsolutePosition.X) / barBack.AbsoluteSize.X, 0, 1), 0, 1, 0)
			barFill.Size = pos
			local current = math.floor(min + ((max - min) * pos.X.Scale))
			valLabel.Text = tostring(current)
			if callback then callback(current) end
		end

		barBack.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				sliding = true
				setSlider(input)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				sliding = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setSlider(input)
			end
		end)

		return {
			Set = function(self, newVal, fireCallback)
				val = math.clamp(newVal, min, max)
				local ratio = (val - min) / math.max(max - min, 1)
				barFill.Size = UDim2.new(ratio, 0, 1, 0)
				valLabel.Text = tostring(val)
				if fireCallback and callback then callback(val) end
			end,
			Get = function(self)
				return val
			end
		}
	end

	function elements:AddInput(placeholder, callback)
		local inputFrame = Instance.new("Frame")
		inputFrame.Size = UDim2.new(1, 0, 0, 42)
		inputFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
		inputFrame.BorderSizePixel = 0
		inputFrame.ZIndex = 14
		inputFrame.Parent = page

		local inCorner = Instance.new("UICorner")
		inCorner.CornerRadius = UDim.new(0, 10)
		inCorner.Parent = inputFrame

		local textBox = Instance.new("TextBox")
		textBox.Size = UDim2.new(1, -24, 1, 0)
		textBox.Position = UDim2.new(0, 12, 0, 0)
		textBox.BackgroundTransparency = 1
		textBox.PlaceholderText = placeholder or "Type here..."
		textBox.PlaceholderColor3 = Color3.fromRGB(140, 120, 155)
		textBox.Text = ""
		textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		textBox.TextSize = 13
		textBox.Font = Enum.Font.GothamMedium
		textBox.TextXAlignment = Enum.TextXAlignment.Left
		textBox.ClearTextOnFocus = false
		textBox.ZIndex = 15
		textBox.Parent = inputFrame

		textBox:GetPropertyChangedSignal("Text"):Connect(function()
			if callback then callback(textBox.Text) end
		end)

		textBox.FocusLost:Connect(function(enterPressed)
			if callback then callback(textBox.Text) end
		end)
		
		return textBox
	end

	function elements:AddStatusCard()
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 68)
		card.BackgroundColor3 = Color3.fromRGB(24, 18, 32)
		card.BorderSizePixel = 0
		card.ZIndex = 14
		card.Parent = page

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 10)
		cCorner.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Thickness = 1
		cStroke.Color = Color3.fromRGB(140, 70, 220)
		cStroke.Transparency = 0.5
		cStroke.Parent = card

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Position = UDim2.new(0, 14, 0, 8)
		statusLbl.Size = UDim2.new(1, -28, 0, 24)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Text = "Status: ⚪ OFF (Idle)"
		statusLbl.TextColor3 = Color3.fromRGB(200, 185, 220)
		statusLbl.TextSize = 13
		statusLbl.Font = Enum.Font.GothamBold
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		statusLbl.ZIndex = 15
		statusLbl.Parent = card

		local subInfo = Instance.new("TextLabel")
		subInfo.Position = UDim2.new(0, 14, 0, 36)
		subInfo.Size = UDim2.new(0.55, 0, 0, 22)
		subInfo.BackgroundTransparency = 1
		subInfo.Text = "💰 Gold: $" .. tostring(AutoRollModule and AutoRollModule.GetGold() or 0)
		subInfo.TextColor3 = Color3.fromRGB(255, 215, 0)
		subInfo.TextSize = 12
		subInfo.Font = Enum.Font.GothamBold
		subInfo.TextXAlignment = Enum.TextXAlignment.Left
		subInfo.ZIndex = 15
		subInfo.Parent = card

		local unitsInfo = Instance.new("TextLabel")
		unitsInfo.Position = UDim2.new(0.55, 0, 0, 36)
		unitsInfo.Size = UDim2.new(0.45, -14, 0, 22)
		unitsInfo.BackgroundTransparency = 1
		unitsInfo.Text = "🎯 Terbeli: " .. totalAcquiredCount .. " unit"
		unitsInfo.TextColor3 = Color3.fromRGB(0, 255, 200)
		unitsInfo.TextSize = 12
		unitsInfo.Font = Enum.Font.GothamBold
		unitsInfo.TextXAlignment = Enum.TextXAlignment.Right
		unitsInfo.ZIndex = 15
		unitsInfo.Parent = card

		task.spawn(function()
			while card and card.Parent do
				subInfo.Text = "💰 Gold: $" .. tostring(AutoRollModule and AutoRollModule.GetGold() or 0)
				unitsInfo.Text = "🎯 Terbeli: " .. totalAcquiredCount .. " unit"
				task.wait(1)
			end
		end)

		return {
			SetStatus = function(self, text, color)
				statusLbl.Text = text
				if color then statusLbl.TextColor3 = color end
			end
		}
	end

	function elements:AddUnitCard(unit)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 38)
		card.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
		card.BorderSizePixel = 0
		card.ZIndex = 14
		card.Parent = page

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 8)
		cCorner.Parent = card

		local isChecked = selectedUnits[unit.name:lower()] or selectedUnits[unit.displayName:lower()]
		
		local checkBtn = Instance.new("TextButton")
		checkBtn.Size = UDim2.new(0, 22, 0, 22)
		checkBtn.Position = UDim2.new(0, 10, 0.5, -11)
		checkBtn.BackgroundColor3 = isChecked and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
		checkBtn.Text = isChecked and "✓" or ""
		checkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		checkBtn.Font = Enum.Font.GothamBold
		checkBtn.TextSize = 13
		checkBtn.ZIndex = 15
		checkBtn.Parent = card

		local chkCorner = Instance.new("UICorner")
		chkCorner.CornerRadius = UDim.new(0, 5)
		chkCorner.Parent = checkBtn

		local rColor = (CatalogModule and CatalogModule.RARITY_COLORS[unit.rarity]) or Color3.fromRGB(180, 180, 180)
		local badge = Instance.new("TextLabel")
		badge.Size = UDim2.new(0, 70, 0, 20)
		badge.Position = UDim2.new(0, 40, 0.5, -10)
		badge.BackgroundColor3 = rColor
		badge.BackgroundTransparency = 0.8
		badge.Text = unit.rarity
		badge.TextColor3 = rColor
		badge.Font = Enum.Font.GothamBold
		badge.TextSize = 10
		badge.ZIndex = 15
		badge.Parent = card

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 4)
		bCorner.Parent = badge

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -220, 1, 0)
		nameLabel.Position = UDim2.new(0, 118, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = unit.displayName
		nameLabel.TextColor3 = Color3.fromRGB(240, 235, 250)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.ZIndex = 15
		nameLabel.Parent = card

		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(0, 90, 1, 0)
		priceLabel.Position = UDim2.new(1, -100, 0, 0)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Text = "$" .. tostring(unit.price)
		priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		priceLabel.Font = Enum.Font.GothamMedium
		priceLabel.TextSize = 11
		priceLabel.TextXAlignment = Enum.TextXAlignment.Right
		priceLabel.ZIndex = 15
		priceLabel.Parent = card

		local function toggle()
			local newState = not (selectedUnits[unit.name:lower()] or selectedUnits[unit.displayName:lower()])
			selectedUnits[unit.name:lower()] = newState and true or nil
			selectedUnits[unit.displayName:lower()] = newState and true or nil
			
			checkBtn.BackgroundColor3 = newState and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
			checkBtn.Text = newState and "✓" or ""
			
			if ConfigManager then
				ConfigManager.Save({ SelectedUnits = selectedUnits })
			end
		end

		checkBtn.Activated:Connect(toggle)

		local fullClick = Instance.new("TextButton")
		fullClick.Size = UDim2.new(1, 0, 1, 0)
		fullClick.BackgroundTransparency = 1
		fullClick.Text = ""
		fullClick.ZIndex = 14
		fullClick.Parent = card
		fullClick.Activated:Connect(toggle)

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

	return elements
end

-- ==============================================================================
-- 🎮 KONTEN & FITUR RITOD HUB PRO
-- ==============================================================================

-- 1. TAB 🎰 AUTO ROLL (MASTER CONTROLS)
local RollTab = RitodLib:CreateTab("Auto Roll", "🎰")

RollTab:AddSection("Live Roll Controller")
local statusCard = RollTab:AddStatusCard()

local huntToggleRef = nil

local function startHunt()
	if not AutoRollModule or AutoRollModule.IsRunning() then return end
	if ConfigManager then
		ConfigManager.Save({ AutoHuntEnabled = true })
	end

	statusCard:SetStatus("Status: 🟢 Auto Hunt ON (Mencari target...)", Color3.fromRGB(0, 255, 180))
	Notify("Auto Hunt", "Auto Roll & Sniper AKTIF!", 2.5)

	AutoRollModule.Start({
		AutoSecretGod = savedConfig.AutoSecretGod or false,
		GetAutoSecretGod = function() return savedConfig.AutoSecretGod or false end,
		SelectedUnits = selectedUnits,
		AllUnitsMap = CatalogModule and CatalogModule.AllUnitsMap or {},
		GetInterval = function() return rollInterval end,
		OnStatus = function(msg, state, extra)
			if state == "rolling" then
				statusCard:SetStatus(msg, Color3.fromRGB(190, 120, 255))
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
			totalAcquiredCount += 1
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
	if AutoRollModule then
		AutoRollModule.Stop()
	end
	if ConfigManager then
		ConfigManager.Save({ AutoHuntEnabled = false })
	end
	statusCard:SetStatus("Status: ⚪ OFF (Idle)", Color3.fromRGB(180, 165, 205))
	Notify("Auto Hunt", "Auto Roll dihentikan.", 2)
end

local autoSniperToggleRef = nil

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
			totalAcquiredCount += 1
			Notify("🎯 Unit Ter-Snipe!", string.format("[%s] %s berhasil dibeli dari conveyor!", unit.rarity, unit.name), 3)
		end
	})
	if ConfigManager then
		ConfigManager.Save({ AutoSniperOnly = true })
	end
	Notify("Auto Sniper", "Auto Buy Standalone aktif! Memantau conveyor...", 2)
end

local function stopAutoSniper()
	if AutoRollModule then
		AutoRollModule.StopAutoSniper()
	end
	if ConfigManager then
		ConfigManager.Save({ AutoSniperOnly = false })
	end
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

huntToggleRef = RollTab:AddToggle("Auto Hunt (Continuous Roll & Sniper)", savedConfig.AutoHuntEnabled or false, function(state)
	if state then
		startHunt()
	else
		stopHunt()
	end
end)

autoSniperToggleRef = RollTab:AddToggle("🎯 Auto Buy / Sniper (Hanya Beli Tanpa Roll)", savedConfig.AutoSniperOnly or false, function(state)
	if state then
		startAutoSniper()
	else
		stopAutoSniper()
	end
end)

autoSecretGodToggleRef = RollTab:AddToggle("👑 Auto Buy Supreme/God/Secret/Limited (Tanpa List)", savedConfig.AutoSecretGod or false, function(state)
	savedConfig.AutoSecretGod = state
	if ConfigManager then
		ConfigManager.Save({ AutoSecretGod = state })
	end
	Notify("Auto Supreme/God", state and "Mode Auto Supreme & God AKTIF!" or "Mode Auto Supreme & God NONAKTIF", 2)
end)

rollDelaySliderRef = RollTab:AddSlider("Roll Delay (Detik)", 1, 5, math.floor(rollInterval), function(val)
	rollInterval = val
	if ConfigManager then
		ConfigManager.Save({ RollInterval = val })
	end
end)

RollTab:AddSection("Quick Rarity Select")

local supremeNum = CatalogModule and #(CatalogModule.UnitsByRarity["Supreme"] or {}) or 0
local godNum = CatalogModule and #(CatalogModule.UnitsByRarity["God"] or {}) or 22
local secretNum = CatalogModule and #(CatalogModule.UnitsByRarity["Secret"] or {}) or 16

RollTab:AddButton(string.format("🌟 Pilih Semua Supreme (%d) & God (%d)", supremeNum, godNum), function()
	for k in pairs(selectedUnits) do selectedUnits[k] = nil end
	if CatalogModule then
		for _, u in ipairs(CatalogModule.UnitsByRarity["Supreme"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
		for _, u in ipairs(CatalogModule.UnitsByRarity["God"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
	end
	for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	Notify("Preset Target", "Target diatur ke Supreme & God saja!", 2.5)
end)

RollTab:AddButton("🔥 Pilih Supreme, God, Secret, & Mythic", function()
	for k in pairs(selectedUnits) do selectedUnits[k] = nil end
	if CatalogModule then
		for _, u in ipairs(CatalogModule.UnitsByRarity["Supreme"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
		for _, u in ipairs(CatalogModule.UnitsByRarity["God"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
		for _, u in ipairs(CatalogModule.UnitsByRarity["Secret"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
		for _, u in ipairs(CatalogModule.UnitsByRarity["Mythic"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
	end
	for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	Notify("Preset Target", "Target ditambah Supreme, Secret & Mythic!", 2.5)
end)

RollTab:AddButton("🧹 Hapus Semua Pilihan (Deselect All)", function()
	for k in pairs(selectedUnits) do selectedUnits[k] = nil end
	for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	Notify("Preset Target", "Semua pilihan unit telah dikosongkan.", 2)
end)

-- 2. TAB 📋 DAFTAR UNIT (DETAIL CHECKBOX PER RARITY)
local UnitTab = RitodLib:CreateTab("Unit List", "📋")

UnitTab:AddSection("Cari & Filter Unit")
UnitTab:AddInput("🔍 Cari nama unit (contoh: Dio, Megumo, Saitomo)...", function(text)
	local query = text:lower():gsub("%s+", "")
	for _, item in ipairs(unitCheckUpdaterCallbacks) do
		local u = item.unit
		local matches = (query == "") or u.name:lower():find(query) or u.displayName:lower():find(query)
		item.card.Visible = matches
	end
end)

if CatalogModule then
	for _, r in ipairs(CatalogModule.RARITY_ORDER) do
		local list = CatalogModule.UnitsByRarity[r] or {}
		if #list > 0 then
			UnitTab:AddSection(string.format("%s (%d Unit)", r, #list))
			for _, u in ipairs(list) do
				UnitTab:AddUnitCard(u)
			end
		end
	end
end

-- 3. TAB 🏃 PLAYER & TELEPORT
local PlayerTab = RitodLib:CreateTab("Player", "🏃")

local function teleportToTargetObject(targetObject, machineName)
	if not targetObject then return false end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		Notify("Teleport Error", "Karakter belum siap!", 2)
		return false
	end

	local targetPart = targetObject:FindFirstChild("Part", true)
		or targetObject:FindFirstChildWhichIsA("BasePart", true)
		or (targetObject:IsA("BasePart") and targetObject)

	local targetCFrame = nil
	if targetObject:IsA("Model") and targetObject.PrimaryPart then
		targetCFrame = targetObject:GetPivot()
	elseif targetPart then
		targetCFrame = targetPart.CFrame
	elseif targetObject:IsA("Model") then
		targetCFrame = targetObject:GetPivot()
	end

	if targetCFrame then
		local pos = targetCFrame.Position
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 5), pos)
		Notify("Teleport Berhasil", "Teleported ke " .. machineName .. "!", 2.5)
		return true
	end
	return false
end

local function findTargetMachine(keywords)
	local ws = game:GetService("Workspace")
	local machines = ws:FindFirstChild("Machines") or ws:FindFirstChild("machines")
	if machines then
		for _, child in ipairs(machines:GetChildren()) do
			local cName = child.Name:lower()
			for _, kw in ipairs(keywords) do
				if cName:find(kw) then
					return child
				end
			end
		end
	end

	-- Fallback search across Workspace descendants
	for _, obj in ipairs(ws:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
			local oName = obj.Name:lower()
			for _, kw in ipairs(keywords) do
				if oName:find(kw) and (obj:FindFirstChildOfClass("ProximityPrompt", true) or oName:find("machine") or (machines and obj.Parent == machines)) then
					return obj
				end
			end
		end
	end
	return nil
end

PlayerTab:AddSection("📍 Teleport Fast Travel")

PlayerTab:AddButton("📍 Teleport ke Depan Stasiun Roll", function()
	if AutoRollModule then
		local myPlot = AutoRollModule.FindMyPlot()
		if myPlot then
			local _, rollBtn = AutoRollModule.GetRollPrompt(myPlot)
			if rollBtn then
				AutoRollModule.MoveToRollButton(rollBtn)
				Notify("Teleport", "Teleported tepat ke stasiun roll!", 2)
				return
			end
		end
	end
	Notify("Teleport", "Plot belum ditemukan!", 2)
end)

PlayerTab:AddButton("🧬 Teleport ke Clone Machine", function()
	local machine = findTargetMachine({"clone", "cloning", "dupe"})
	if not machine or not teleportToTargetObject(machine, "Clone Machine") then
		Notify("Teleport Error", "Clone Machine tidak ditemukan di map!", 2.5)
	end
end)

PlayerTab:AddButton("⚡ Teleport ke Evolution Machine", function()
	local machine = findTargetMachine({"evolution", "evolve", "evol"})
	if not machine or not teleportToTargetObject(machine, "Evolution Machine") then
		Notify("Teleport Error", "Evolution Machine tidak ditemukan di map!", 2.5)
	end
end)

PlayerTab:AddButton("🎲 Teleport ke Trait Machine", function()
	local machine = findTargetMachine({"trait", "reroll trait", "traits"})
	if not machine or not teleportToTargetObject(machine, "Trait Machine") then
		Notify("Teleport Error", "Trait Machine tidak ditemukan di map!", 2.5)
	end
end)

PlayerTab:AddSection("🏃 Character Movement & Physics")

local function applyPlayerWalkSpeed(val)
	savedConfig.WalkSpeed = val
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.WalkSpeed = val
	end
end

local function applyPlayerJumpPower(val)
	savedConfig.JumpPower = val
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.JumpPower = val
	end
end

walkSpeedSliderRef = PlayerTab:AddSlider("WalkSpeed", 16, 250, savedConfig.WalkSpeed or 16, function(val)
	applyPlayerWalkSpeed(val)
	if ConfigManager then ConfigManager.Save({ WalkSpeed = val }) end
end)

jumpPowerSliderRef = PlayerTab:AddSlider("JumpPower", 50, 350, savedConfig.JumpPower or 50, function(val)
	applyPlayerJumpPower(val)
	if ConfigManager then ConfigManager.Save({ JumpPower = val }) end
end)

infJumpToggleRef = PlayerTab:AddToggle("Infinite Jump", savedConfig.InfJump or false, function(state)
	savedConfig.InfJump = state
	if ConfigManager then ConfigManager.Save({ InfJump = state }) end
	_G.InfJump = state
	if state then
		if not _G.InfJumpConn then
			_G.InfJumpConn = UserInputService.JumpRequest:Connect(function()
				if _G.InfJump and player.Character and player.Character:FindFirstChild("Humanoid") then
					player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end)
		end
	else
		if _G.InfJumpConn then
			_G.InfJumpConn:Disconnect()
			_G.InfJumpConn = nil
		end
	end
end)

-- Auto re-apply movement on respawn
player.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		task.wait(0.5)
		if savedConfig.WalkSpeed and savedConfig.WalkSpeed ~= 16 then
			hum.WalkSpeed = savedConfig.WalkSpeed
		end
		if savedConfig.JumpPower and savedConfig.JumpPower ~= 50 then
			hum.JumpPower = savedConfig.JumpPower
		end
	end
end)

-- 4. TAB 🎁 QUESTS & REWARDS
local QuestTab = RitodLib:CreateTab("Quests", "🎁")

QuestTab:AddSection("Daily & Weekly Quests")

questToggleRef = QuestTab:AddToggle("📜 Auto Claim Daily & Weekly Quests", savedConfig.AutoClaimQuests ~= false, function(state)
	savedConfig.AutoClaimQuests = state
	if ConfigManager then ConfigManager.Save({ AutoClaimQuests = state }) end
	if AutoClaimModule then
		AutoClaimModule.Config.DailyQuest = state
		AutoClaimModule.Config.WeeklyQuest = state
		if state then
			task.spawn(function()
				AutoClaimModule.ClaimQuests()
				AutoClaimModule.ScanAndClaimUI()
			end)
			if not AutoClaimModule.IsRunning() then
				AutoClaimModule.Start()
			end
		end
	end
	Notify("Auto Quests", state and "Auto Claim Quests AKTIF!" or "Auto Claim Quests NONAKTIF", 2)
end)

QuestTab:AddSection("Battlepass & Free Gifts")

rewardsToggleRef = QuestTab:AddToggle("🏆 Auto Claim Battlepass Tier", savedConfig.AutoClaimRewards ~= false, function(state)
	savedConfig.AutoClaimRewards = state
	if ConfigManager then ConfigManager.Save({ AutoClaimRewards = state }) end
	if AutoClaimModule then
		AutoClaimModule.Config.Battlepass = state
		AutoClaimModule.Config.FreeRewards = state
		AutoClaimModule.Config.VIPAndGroup = state
		if state then
			task.spawn(function()
				AutoClaimModule.ClaimBattlepass()
				AutoClaimModule.ClaimFreeRewards()
				AutoClaimModule.ScanAndClaimUI()
			end)
			if not AutoClaimModule.IsRunning() then
				AutoClaimModule.Start()
			end
		end
	end
	Notify("Auto Rewards", state and "Auto Claim Battlepass & Hadiah AKTIF!" or "Auto Claim Hadiah NONAKTIF", 2)
end)

QuestTab:AddSection("Instant Actions")

QuestTab:AddButton("⚡ Klaim Semua Hadiah & Quest Sekarang", function()
	if AutoClaimModule then
		AutoClaimModule.ClaimQuests()
		AutoClaimModule.ClaimBattlepass()
		AutoClaimModule.ClaimFreeRewards()
		AutoClaimModule.ScanAndClaimUI()
		Notify("Claim All", "Semua Quest & Hadiah berhasil diproses klaim!", 2.5)
	else
		Notify("Claim Error", "Modul AutoClaim belum dimuat.", 2)
	end
end)

-- 5. TAB 🛒 MERCHANT & TRADER
local MerchantTab = RitodLib:CreateTab("Merchant", "🛒")

MerchantTab:AddSection("Auto Buy Merchant (Trader Event)")

merchantToggleRef = MerchantTab:AddToggle("🛒 Auto Buy Merchant (Trader Event)", savedConfig.AutoBuyMerchant ~= false, function(state)
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

merchantBuyAllToggleRef = MerchantTab:AddToggle("⚡ Beli Seluruh Stok Item (All Stock)", savedConfig.MerchantBuyAll or false, function(state)
	savedConfig.MerchantBuyAll = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyAll = state }) end
	if AutoMerchantModule then
		AutoMerchantModule.Config.BuyAllStock = state
	end
end)

MerchantTab:AddSection("Kategori Item yang Dibeli")

merchantPotionsToggleRef = MerchantTab:AddToggle("💊 Auto Buy Potions (Time, Gold, Luck)", savedConfig.MerchantBuyPotions ~= false, function(state)
	savedConfig.MerchantBuyPotions = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyPotions = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyPotions = state end
end)

merchantEssencesToggleRef = MerchantTab:AddToggle("✨ Auto Buy Essences (Supreme, God, Secret, dll.)", savedConfig.MerchantBuyEssences ~= false, function(state)
	savedConfig.MerchantBuyEssences = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyEssences = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyEssences = state end
end)

merchantCapsulesToggleRef = MerchantTab:AddToggle("📦 Auto Buy Capsules (God, Secret, Mythic)", savedConfig.MerchantBuyCapsules ~= false, function(state)
	savedConfig.MerchantBuyCapsules = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyCapsules = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyCapsules = state end
end)

merchantTicketsToggleRef = MerchantTab:AddToggle("📜 Auto Buy Tickets (Infinite, Trading)", savedConfig.MerchantBuyTickets ~= false, function(state)
	savedConfig.MerchantBuyTickets = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyTickets = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyTickets = state end
end)

merchantMaterialsToggleRef = MerchantTab:AddToggle("💎 Auto Buy Rare Materials (Six Eyes, Sukuna, Core, dll.)", savedConfig.MerchantBuyMaterials ~= false, function(state)
	savedConfig.MerchantBuyMaterials = state
	if ConfigManager then ConfigManager.Save({ MerchantBuyMaterials = state }) end
	if AutoMerchantModule then AutoMerchantModule.Config.BuyMaterials = state end
end)

MerchantTab:AddSection("Instant Actions & Status")

MerchantTab:AddButton("🛍️ Beli Semua Stok Merchant Sekarang", function()
	if AutoMerchantModule then
		AutoMerchantModule.ScanAndBuyAllStock()
		Notify("Merchant Buy", "Memproses pembelian seluruh stok item sekarang!", 2)
	else
		Notify("Merchant Error", "Modul AutoMerchant belum dimuat.", 2)
	end
end)

MerchantTab:AddButton("🔍 Cek Status Trader Event", function()
	if AutoMerchantModule then
		local active = AutoMerchantModule.IsMerchantActive()
		local rem = AutoMerchantModule.GetMerchantRemainingTime()
		if active then
			Notify("Trader Status", string.format("Trader AKTIF! Sisa Waktu: %d detik", rem), 3.5)
		else
			Notify("Trader Status", "Trader sedang TIDAK AKTIF / Belum Muncul.", 2.5)
		end
	else
		Notify("Trader Status", "Modul AutoMerchant belum dimuat.", 2)
	end
end)

-- 6. TAB ⚙️ SETTINGS & CONFIG
local MiscTab = RitodLib:CreateTab("Settings", "⚙️")

MiscTab:AddSection("Server & Private Server")

autoPrivateServerToggleRef = MiscTab:AddToggle("🔒 Auto Join Private Server (Saat Load/Execute)", savedConfig.AutoPrivateServer == true, function(state)
	savedConfig.AutoPrivateServer = state
	if ConfigManager then ConfigManager.Save({ AutoPrivateServer = state }) end
	if state and PrivateServerModule and not PrivateServerModule.IsPrivateServer() then
		Notify("Private Server", "Auto Join AKTIF! Menghubungkan ke Private Server sekarang...", 3.5)
		task.delay(0.8, function()
			if savedConfig.AutoPrivateServer and PrivateServerModule then
				PrivateServerModule.JoinPrivateServer(Notify)
			end
		end)
	else
		Notify("Private Server", state and "Auto Join Private Server AKTIF!" or "Auto Join Private Server NONAKTIF", 2)
	end
end)

MiscTab:AddButton("🏠 Masuk / Relog ke Private Server (Menu Game)", function()
	if PrivateServerModule then
		PrivateServerModule.JoinPrivateServer(Notify)
	else
		Notify("Private Server", "Modul Private Server belum dimuat.", 2)
	end
end)

MiscTab:AddSection("Graphics & Performance")

farmModeToggleRef = MiscTab:AddToggle("🚜 Farm Mode (3D Render Off / AMOLED Screen)", savedConfig.FarmMode or false, function(state)
	savedConfig.FarmMode = state
	if ConfigManager then ConfigManager.Save({ FarmMode = state }) end
	if GraphicsModule then
		GraphicsModule.SetFarmMode(state, function(newState)
			savedConfig.FarmMode = newState
			if ConfigManager then ConfigManager.Save({ FarmMode = newState }) end
			if farmModeToggleRef then farmModeToggleRef:Set(newState, false) end
		end)
	end
end)

potatoToggleRef = MiscTab:AddToggle("🥔 Potato Mode (Smooth Textures & Low Quality)", savedConfig.PotatoGraphics or false, function(state)
	savedConfig.PotatoGraphics = state
	if ConfigManager then ConfigManager.Save({ PotatoGraphics = state }) end
	if GraphicsModule then
		if state then
			GraphicsModule.EnablePotatoGraphics()
		else
			GraphicsModule.DisablePotatoGraphics()
		end
	end
end)

hideOtherPlayersToggleRef = MiscTab:AddToggle("👻 Sembunyikan Player & Plot Lain (Ghost Mode)", savedConfig.HideOtherPlayers or false, function(state)
	savedConfig.HideOtherPlayers = state
	if ConfigManager then ConfigManager.Save({ HideOtherPlayers = state }) end
	if GraphicsModule then
		if state then
			GraphicsModule.HideOtherPlayers()
		else
			GraphicsModule.ShowOtherPlayers()
		end
	end
end)

freezeNPCsToggleRef = MiscTab:AddToggle("🤖 Pause Animasi Musuh / NPC (CPU Saver)", savedConfig.FreezeNPCs or false, function(state)
	savedConfig.FreezeNPCs = state
	if ConfigManager then ConfigManager.Save({ FreezeNPCs = state }) end
	if GraphicsModule then
		if state then
			GraphicsModule.FreezeAllNPCsAndAnimations()
		else
			GraphicsModule.UnfreezeNPCs()
		end
	end
end)

disableVFXToggleRef = MiscTab:AddToggle("💀 Matikan Semua VFX & Partikel Skill", savedConfig.DisableVFX or false, function(state)
	savedConfig.DisableVFX = state
	if ConfigManager then ConfigManager.Save({ DisableVFX = state }) end
	if GraphicsModule then
		if state then
			GraphicsModule.DisableAllVFX()
		else
			GraphicsModule.RestoreVFX()
		end
	end
end)

antiLagToggleRef = MiscTab:AddToggle("❄️ Anti-Lag AFK (FPS Cap 10)", savedConfig.AntiLag or false, function(state)
	savedConfig.AntiLag = state
	if ConfigManager then ConfigManager.Save({ AntiLag = state }) end
	if GraphicsModule then
		GraphicsModule.SetAntiLag(state)
	end
end)

fpsCapSliderRef = MiscTab:AddSlider("🎯 Batas FPS (FPS Cap)", 5, 240, savedConfig.TargetFPS or 60, function(val)
	savedConfig.TargetFPS = val
	if ConfigManager then ConfigManager.Save({ TargetFPS = val }) end
	if GraphicsModule then
		GraphicsModule.ApplyFpsCap(val)
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

-- =================================================================
-- 🔧 CONFIG APPLICATOR (MUST be defined before any usage)
-- =================================================================
local function applyRollAnimeConfig(loaded)
	if not loaded or type(loaded) ~= "table" then return end
	for k, v in pairs(loaded) do
		savedConfig[k] = v
	end

	if huntToggleRef and loaded.AutoHuntEnabled ~= nil then
		huntToggleRef:Set(loaded.AutoHuntEnabled, false)
		if loaded.AutoHuntEnabled then
			task.spawn(startHunt)
		else
			task.spawn(stopHunt)
		end
	end

	if autoSniperToggleRef and loaded.AutoSniperOnly ~= nil then
		autoSniperToggleRef:Set(loaded.AutoSniperOnly, false)
		if loaded.AutoSniperOnly then
			task.spawn(startAutoSniper)
		else
			task.spawn(stopAutoSniper)
		end
	end

	if autoSecretGodToggleRef and loaded.AutoSecretGod ~= nil then
		autoSecretGodToggleRef:Set(loaded.AutoSecretGod, false)
		savedConfig.AutoSecretGod = loaded.AutoSecretGod
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

	if loaded.SelectedUnits and type(loaded.SelectedUnits) == "table" then
		for k in pairs(selectedUnits) do selectedUnits[k] = nil end
		for name, val in pairs(loaded.SelectedUnits) do
			if val then selectedUnits[tostring(name):lower()] = true end
		end
		for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	end
end

MiscTab:AddSection("💾 Config File Manager")

MiscTab:AddButton("💾 Simpan Config Sekarang (Save Config)", function()
	if ConfigManager then
		local currentData = {
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
			TargetFPS             = savedConfig.TargetFPS or 60
		}
		for k, v in pairs(currentData) do savedConfig[k] = v end
		local success = ConfigManager.Save(currentData)
		if success then
			local unitCount = 0
			for _, v in pairs(selectedUnits) do if v then unitCount = unitCount + 1 end end
			local targetUnits = math.floor(unitCount / 2) > 0 and math.floor(unitCount / 2) or unitCount
			local pathName = (ConfigManager and ConfigManager.ConfigPath) or "RitodHub_RollAnime_Config.json"
			Notify("💾 Config Saved", string.format("Berhasil disimpan ke %s (%d unit target)!", tostring(pathName), targetUnits), 3.5)
		else
			Notify("Config Error", "Gagal menyimpan file config!", 3)
		end
	else
		Notify("Config Error", "Modul ConfigManager tidak ditemukan!", 2)
	end
end)

MiscTab:AddButton("🔄 Muat Ulang Config (Reload Config)", function()
	if ConfigManager then
		local loaded = ConfigManager.Load()
		if loaded then
			applyRollAnimeConfig(loaded)
			Notify("🔄 Config Reloaded", "Pengaturan berhasil dimuat ulang dari file!", 3)
		end
	end
end)

MiscTab:AddButton("🗑️ Reset Config ke Default", function()
	if ConfigManager then
		local def = ConfigManager.Reset()
		applyRollAnimeConfig(def)
		Notify("🗑️ Config Reset", "Pengaturan telah direset ke nilai default!", 3)
	end
end)

-- (applyRollAnimeConfig telah dipindahkan ke atas, sebelum Config File Manager section)

if ModernSettings and typeof(ModernSettings.CreateProfileManager) == "function" then
	local ProfileManager = ModernSettings.CreateProfileManager(
		"RitodHub/RollAnimeForFight",
		{
			AutoHuntEnabled   = false,
			AutoSecretGod     = false,
			AutoPrivateServer = true,
			AutoClaimQuests   = true,
			AutoClaimRewards  = true,
			RollInterval      = 2.5,
			SelectedUnits     = selectedUnits,
			WalkSpeed         = 16,
			JumpPower         = 50,
			InfJump           = false,
			PotatoGraphics    = false,
			FarmMode          = false,
			AntiLag           = false
		},
		function()
			return {
				AutoHuntEnabled   = AutoRollModule and AutoRollModule.IsRunning() or false,
				AutoSecretGod     = savedConfig.AutoSecretGod or false,
				AutoPrivateServer = savedConfig.AutoPrivateServer ~= false,
				AutoClaimQuests   = savedConfig.AutoClaimQuests ~= false,
				AutoClaimRewards  = savedConfig.AutoClaimRewards ~= false,
				RollInterval      = rollInterval or 2.5,
				SelectedUnits     = selectedUnits,
				WalkSpeed         = (player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.WalkSpeed) or savedConfig.WalkSpeed or 16,
				JumpPower         = (player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.JumpPower) or savedConfig.JumpPower or 50,
				InfJump           = _G.InfJump or false,
				PotatoGraphics    = savedConfig.PotatoGraphics or false,
				FarmMode          = savedConfig.FarmMode or false,
				AntiLag           = savedConfig.AntiLag or false
			}
		end,
		applyRollAnimeConfig,
		Notify
	)
	ModernSettings.BuildUI(
		MiscTab.Page,
		ProfileManager,
		"https://raw.githubusercontent.com/RyuZeed/capybara/refs/heads/main/roll_anime.lua",
		Notify
	)
end

MiscTab:AddSection("Kontrol GUI")
MiscTab:AddButton("Copy Discord Link", function()
	if setclipboard then setclipboard("https://discord.gg/ritodhub") end
	Notify("Discord", "Link copied to clipboard!", 3)
end)

MiscTab:AddButton("Rejoin Server", function()
	game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
end)

MiscTab:AddButton("Unload Script", function()
	showUnloadModal()
end)

-- ==========================================
-- 🚀 AUTO-RESUME JIKA TERAKHIR KALI AUTO-HUNT / GRAPHICS / PRIVATE SERVER AKTIF
-- ==========================================
if savedConfig.PotatoGraphics and GraphicsModule then
	task.spawn(function()
		task.wait(0.5)
		GraphicsModule.EnablePotatoGraphics()
	end)
end

if savedConfig.HideOtherPlayers and GraphicsModule then
	task.spawn(function()
		task.wait(0.5)
		GraphicsModule.HideOtherPlayers()
	end)
end

if savedConfig.FreezeNPCs and GraphicsModule then
	task.spawn(function()
		task.wait(0.5)
		GraphicsModule.FreezeAllNPCsAndAnimations()
	end)
end

if savedConfig.DisableVFX and GraphicsModule then
	task.spawn(function()
		task.wait(0.5)
		GraphicsModule.DisableAllVFX()
	end)
end

if savedConfig.TargetFPS and GraphicsModule then
	task.spawn(function()
		task.wait(0.3)
		GraphicsModule.ApplyFpsCap(savedConfig.TargetFPS)
	end)
end

if savedConfig.AntiLag and GraphicsModule then
	task.spawn(function()
		task.wait(0.5)
		GraphicsModule.SetAntiLag(true)
	end)
end

if savedConfig.FarmMode and GraphicsModule then
	task.spawn(function()
		task.wait(1)
		GraphicsModule.SetFarmMode(true)
	end)
end

if savedConfig.AutoPrivateServer == true and PrivateServerModule then
	task.spawn(function()
		-- Pastikan game, player, dan gui sudah 100% loaded
		if not game:IsLoaded() then
			pcall(function() game.Loaded:Wait() end)
		end
		while not Players.LocalPlayer or not Players.LocalPlayer.Character do
			task.wait(0.2)
		end
		while not Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") do
			task.wait(0.2)
		end
		task.wait(3.5)

		-- Cek apakah sudah di private server
		if not PrivateServerModule.IsPrivateServer() and not _G.AutoPrivateServerDone then
			_G.AutoPrivateServerDone = true
			Notify("🔒 Auto Private Server", "Mendeteksi server publik, berpindah ke Private Server...", 3.5)
			task.wait(1)
			if not PrivateServerModule.IsPrivateServer() then
				PrivateServerModule.JoinPrivateServer(Notify)
			end
		else
			_G.AutoPrivateServerDone = true
		end
	end)
end

if savedConfig.AutoHuntEnabled then
	task.spawn(function()
		task.wait(2.5)
		Notify("Auto-Resume", "Melanjutkan Auto-Hunt dari sesi sebelumnya...", 3)
		if huntToggleRef then
			huntToggleRef:Set(true, true)
		else
			startHunt()
		end
	end)
end

-- =================================================================
-- 🔄 AUTO-APPLY SAVED CONFIG TO SYNC ALL TOGGLES, SLIDERS & CHECKBOXES
-- =================================================================
task.spawn(function()
	task.wait(0.1)
	if applyRollAnimeConfig and savedConfig then
		applyRollAnimeConfig(savedConfig)
	end
end)

-- =================================================================
-- 💾 AUTO-SAVE BACKGROUND DAEMON (Setiap 5 detik otomatis simpan setting)
-- =================================================================
_G.AutoSaveDaemonThread = task.spawn(function()
	while task.wait(5) do
		pcall(function()
			if ConfigManager and typeof(ConfigManager.Save) == "function" then
				ConfigManager.Save({
					AutoHuntEnabled       = (AutoRollModule and AutoRollModule.IsRunning()) or savedConfig.AutoHuntEnabled or false,
					AutoSniperOnly        = (AutoRollModule and AutoRollModule.IsSniperRunning()) or savedConfig.AutoSniperOnly or false,
					AutoSecretGod         = savedConfig.AutoSecretGod or false,
					AutoPrivateServer     = (autoPrivateServerToggleRef and autoPrivateServerToggleRef:Get() == true) or (savedConfig.AutoPrivateServer == true),
					AutoClaimQuests       = savedConfig.AutoClaimQuests ~= false,
					AutoClaimRewards      = savedConfig.AutoClaimRewards ~= false,
					AutoBuyMerchant       = savedConfig.AutoBuyMerchant or false,
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
					TargetFPS             = savedConfig.TargetFPS or 60
				})
			end
		end)
	end
end)

-- =================================================================
-- 🧹 GLOBAL CLEANUP DESTRUCTOR (DIPANGGIL SAAT RE-EXECUTE)
-- =================================================================
_G.RitodHubCleanup = function()
	pcall(function()
		if AutoRollModule then
			pcall(function() AutoRollModule.Stop() end)
			pcall(function() AutoRollModule.StopAutoSniper() end)
		end
		if AutoClaimModule then
			pcall(function() AutoClaimModule.Stop() end)
		end
		if GraphicsModule and typeof(GraphicsModule.Unload) == "function" then
			pcall(function() GraphicsModule.Unload() end)
		end
		if _G.AutoSaveDaemonThread then
			pcall(function() task.cancel(_G.AutoSaveDaemonThread) end)
			_G.AutoSaveDaemonThread = nil
		end
		if _G.AutoPrivateServerThread then
			pcall(function() task.cancel(_G.AutoPrivateServerThread) end)
			_G.AutoPrivateServerThread = nil
		end
		if _G.InfJumpConn then
			pcall(function() _G.InfJumpConn:Disconnect() end)
			_G.InfJumpConn = nil
		end
	end)
end

-- Pop up notifikasi awal
local activeCfgPath = (ConfigManager and ConfigManager.ConfigPath) or "RitodHub/RollAnimeForFight/config.json"
Notify("⚡RITOD HUB⚡", "Loaded! File Config: " .. activeCfgPath, 4)



