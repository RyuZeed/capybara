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

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.5)

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

-- =================================================================
-- 🌐 ROLL ANIME MODULAR LOADER (LOCAL & GITHUB CLOUD SUPPORT)
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/roll_anime/"

local function loadModule(name)
    -- 1. Local path check
    local localPaths = {
        "modules/roll_anime/" .. name .. ".lua",
        name .. ".lua",
        "RitodHub/modules/roll_anime/" .. name .. ".lua"
    }
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        for _, path in ipairs(localPaths) do
            if isfile(path) then
                local success, result = pcall(function()
                    return loadstring(readfile(path))()
                end)
                if success and result then
                    print("📁 [Ritod Hub] Loaded local module: " .. path)
                    return result
                end
            end
        end
    end

    -- 2. Fallback load from GitHub Cloud
    local success, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. name .. ".lua"))()
    end)
    if success and result then
        print("🌐 [Ritod Hub] Loaded cloud module: " .. name)
        return result
    else
        warn("⚠️ [Ritod Hub] Gagal memuat modul: " .. name .. " -> " .. tostring(result))
        return nil
    end
end

local AFKModule       = loadModule("anti_afk")
local ConfigManager   = loadModule("config_manager")
local CatalogModule   = loadModule("catalog")
local AutoRollModule  = loadModule("auto_roll")
local GraphicsModule  = loadModule("graphics")
local ModernSettings  = loadModule("modern_settings")

-- Auto-start Anti-AFK
if AFKModule then
    AFKModule.Enable()
end

-- Muat config tersimpan
local savedConfig = ConfigManager and ConfigManager.Load() or {}

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
local parentGui
if typeof(gethui) == "function" then
	parentGui = gethui()
elseif run_secure_function or getexecutorname then
	parentGui = CoreGui
else
	parentGui = player:FindFirstChildOfClass("PlayerGui") or CoreGui
end

if parentGui:FindFirstChild("RitodHubUltra") then
	parentGui:FindFirstChild("RitodHubUltra"):Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RitodHubUltra"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = parentGui

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

			local endConn
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					endConn:Disconnect()
					if not hasMoved and onClick then
						onClick()
					end
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
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
	nTitle.Text = title
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
	nDesc.Text = desc
	nDesc.TextColor3 = Color3.fromRGB(190, 175, 205)
	nDesc.TextSize = 12
	nDesc.Font = Enum.Font.GothamMedium
	nDesc.TextXAlignment = Enum.TextXAlignment.Left
	nDesc.TextWrapped = true
	nDesc.ZIndex = 202
	nDesc.Parent = n

	TweenService:Create(n, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

	task.delay(duration, function()
		if n and n.Parent then
			local out = TweenService:Create(n, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 150, 0, 0)})
			out:Play()
			out.Completed:Connect(function() n:Destroy() end)
		end
	end)
end

-- ==============================================================================
-- 🖥️ MAIN HUB WINDOW (700x460)
-- ==============================================================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainHub"
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size = UDim2.new(0, 700, 0, 460)
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
hubTitle.Text = "⚡RITOD HUB⚡"
hubTitle.RichText = true
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
local floatWidget = Instance.new("Frame")
floatWidget.Name = "FloatWidget"
floatWidget.AnchorPoint = Vector2.new(0, 0.5)
floatWidget.Position = UDim2.new(0, 24, 0.5, 0)
floatWidget.Size = UDim2.new(0, 64, 0, 64)
floatWidget.BackgroundColor3 = Color3.fromRGB(20, 14, 28)
floatWidget.BorderSizePixel = 0
floatWidget.ZIndex = 100
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
floatIcon.Text = "⚡"
floatIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
floatIcon.TextSize = 26
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
		TweenService:Create(floatStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Thickness = 3.5, Transparency = 0}):Play()
		TweenService:Create(statusDot, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = Color3.fromRGB(120, 255, 180)}):Play()
		task.wait(1.2)
		TweenService:Create(floatStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Thickness = 2.0, Transparency = 0.4}):Play()
		TweenService:Create(statusDot, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = Color3.fromRGB(40, 200, 100)}):Play()
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

closeBtn.Activated:Connect(function()
	showUnloadModal()
end)

minBtn.Activated:Connect(function()
	toggleHub()
end)

yesBtn.Activated:Connect(function()
	Notify("RITOD Hub", "Unloading script...", 2)
	if AutoRollModule then AutoRollModule.Stop() end
	if AFKModule then AFKModule.Disable() end
	if _G.InfJumpConn then _G.InfJumpConn:Disconnect() end
	_G.InfJump = false
	
	TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset, 1.2, 0)
	}):Play()
	TweenService:Create(floatWidget, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	
	task.wait(0.35)
	screenGui:Destroy()
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
	tabBtn.Text = (icon and (icon .. "  ") or "") .. name
	tabBtn.TextColor3 = Color3.fromRGB(160, 140, 175)
	tabBtn.TextSize = 13
	tabBtn.Font = Enum.Font.GothamMedium
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

	tabBtn.MouseButton1Click:Connect(selectTab)
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
		btn.MouseButton1Click:Connect(function()
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

		local switch = Instance.new("TextButton")
		switch.AnchorPoint = Vector2.new(1, 0.5)
		switch.Position = UDim2.new(1, -12, 0.5, 0)
		switch.Size = UDim2.new(0, 48, 0, 24)
		switch.BackgroundColor3 = state and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(50, 38, 60)
		switch.AutoButtonColor = false
		switch.Text = ""
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

		switch.MouseButton1Click:Connect(function()
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

		checkBtn.MouseButton1Click:Connect(toggle)

		local fullClick = Instance.new("TextButton")
		fullClick.Size = UDim2.new(1, 0, 1, 0)
		fullClick.BackgroundTransparency = 1
		fullClick.Text = ""
		fullClick.ZIndex = 14
		fullClick.Parent = card
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

huntToggleRef = RollTab:AddToggle("Auto Hunt (Continuous Roll & Sniper)", savedConfig.AutoHuntEnabled or false, function(state)
	if state then
		startHunt()
	else
		stopHunt()
	end
end)

RollTab:AddSlider("Roll Delay (Detik)", 1, 5, math.floor(rollInterval), function(val)
	rollInterval = val
	if ConfigManager then
		ConfigManager.Save({ RollInterval = val })
	end
end)

RollTab:AddSection("Quick Rarity Select")

RollTab:AddButton("🌟 Pilih Semua Secret (13 Unit) & God (14 Unit)", function()
	selectedUnits = {}
	if CatalogModule then
		for _, u in ipairs(CatalogModule.UnitsByRarity["Secret"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
		for _, u in ipairs(CatalogModule.UnitsByRarity["God"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
	end
	for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	Notify("Preset Target", "Target diatur ke Secret & God saja!", 2.5)
end)

RollTab:AddButton("🔥 Pilih Secret, God, & Mythic", function()
	if CatalogModule then
		for _, u in ipairs(CatalogModule.UnitsByRarity["Secret"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
		for _, u in ipairs(CatalogModule.UnitsByRarity["God"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
		for _, u in ipairs(CatalogModule.UnitsByRarity["Mythic"] or {}) do selectedUnits[u.name:lower()] = true selectedUnits[u.displayName:lower()] = true end
	end
	for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	if ConfigManager then ConfigManager.Save({ SelectedUnits = selectedUnits }) end
	Notify("Preset Target", "Target ditambah Mythic!", 2.5)
end)

RollTab:AddButton("🧹 Hapus Semua Pilihan (Deselect All)", function()
	selectedUnits = {}
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

PlayerTab:AddSection("Movement & Safety")
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

PlayerTab:AddSlider("WalkSpeed", 16, 250, savedConfig.WalkSpeed or 16, function(val)
	if ConfigManager then ConfigManager.Save({ WalkSpeed = val }) end
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.WalkSpeed = val
	end
end)

PlayerTab:AddSlider("JumpPower", 50, 350, savedConfig.JumpPower or 50, function(val)
	if ConfigManager then ConfigManager.Save({ JumpPower = val }) end
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.JumpPower = val
	end
end)

PlayerTab:AddToggle("Infinite Jump", savedConfig.InfJump or false, function(state)
	if ConfigManager then ConfigManager.Save({ InfJump = state }) end
	_G.InfJump = state
	if state then
		_G.InfJumpConn = UserInputService.JumpRequest:Connect(function()
			if _G.InfJump and player.Character and player.Character:FindFirstChild("Humanoid") then
				player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	else
		if _G.InfJumpConn then _G.InfJumpConn:Disconnect() end
	end
end)

-- 4. TAB ⚙️ SETTINGS & CONFIG
local MiscTab = RitodLib:CreateTab("Settings", "⚙️")

MiscTab:AddSection("Graphics & Performance")

local updateFarmModeBtn
updateFarmModeBtn = MiscTab:AddToggle("🚜 Farm Mode (3D Render Off)", savedConfig.FarmMode or false, function(state)
	if ConfigManager then ConfigManager.Save({ FarmMode = state }) end
	if GraphicsModule then
		GraphicsModule.SetFarmMode(state, function(newState)
			if ConfigManager then ConfigManager.Save({ FarmMode = newState }) end
			if updateFarmModeBtn then updateFarmModeBtn:Set(newState, false) end
		end)
	end
end)

MiscTab:AddToggle("🥔 Low Graphics / Potato Mode", savedConfig.PotatoGraphics or false, function(state)
	if ConfigManager then ConfigManager.Save({ PotatoGraphics = state }) end
	if GraphicsModule then
		GraphicsModule.EnablePotato(state)
	end
end)

MiscTab:AddToggle("❄️ Anti-Lag (FPS Cap 5)", savedConfig.AntiLag or false, function(state)
	if ConfigManager then ConfigManager.Save({ AntiLag = state }) end
	if GraphicsModule then
		GraphicsModule.SetAntiLag(state)
	end
end)

local function applyRollAnimeConfig(loaded)
	if not loaded then return end
	for k, v in pairs(loaded) do
		savedConfig[k] = v
	end

	if loaded.SelectedUnits then
		selectedUnits = {}
		for name, val in pairs(loaded.SelectedUnits) do
			if val then selectedUnits[name:lower()] = true end
		end
		for _, item in ipairs(unitCheckUpdaterCallbacks) do item.sync() end
	end

	if loaded.WalkSpeed and player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.WalkSpeed = loaded.WalkSpeed
	end
	if loaded.JumpPower and player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.JumpPower = loaded.JumpPower
	end
	if loaded.InfJump ~= nil then
		_G.InfJump = loaded.InfJump
	end

	if loaded.PotatoGraphics ~= nil and GraphicsModule then
		GraphicsModule.EnablePotato(loaded.PotatoGraphics)
	end
	if loaded.AntiLag ~= nil and GraphicsModule then
		GraphicsModule.SetAntiLag(loaded.AntiLag)
	end
	if loaded.FarmMode ~= nil and GraphicsModule then
		GraphicsModule.SetFarmMode(loaded.FarmMode)
	end
end

if ModernSettings then
	local ProfileManager = ModernSettings.CreateProfileManager(
		"RitodHub/RollAnimeForFight",
		{
			AutoHuntEnabled = false,
			RollInterval = 2.5,
			SelectedUnits = selectedUnits,
			WalkSpeed = 16,
			JumpPower = 50,
			InfJump = false,
			PotatoGraphics = false,
			FarmMode = false,
			AntiLag = false
		},
		function()
			return {
				AutoHuntEnabled = AutoRollModule and AutoRollModule.IsRunning() or false,
				RollInterval = rollInterval or 2.5,
				SelectedUnits = selectedUnits,
				WalkSpeed = (player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.WalkSpeed) or 16,
				JumpPower = (player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.JumpPower) or 50,
				InfJump = _G.InfJump or false,
				PotatoGraphics = savedConfig.PotatoGraphics or false,
				FarmMode = savedConfig.FarmMode or false,
				AntiLag = savedConfig.AntiLag or false
			}
		end,
		applyRollAnimeConfig,
		Notify
	)
	ModernSettings.BuildUI(
		MiscTab.Page,
		ProfileManager,
		"https://raw.githubusercontent.com/RyuZeed/capybara/main/roll_anime.lua",
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
-- 🚀 AUTO-RESUME JIKA TERAKHIR KALI AUTO-HUNT / GRAPHICS AKTIF
-- ==========================================
if savedConfig.PotatoGraphics and GraphicsModule then
	task.spawn(function()
		task.wait(0.5)
		GraphicsModule.EnablePotato(true)
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

-- Pop up notifikasi awal
Notify("⚡RITOD HUB⚡", "Loaded! File Config: " .. cfgPath, 4)
