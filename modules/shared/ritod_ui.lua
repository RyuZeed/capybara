--[[
	===============================================================
	⚡ RITOD HUB - UNIVERSAL REUSABLE UI LIBRARY (RitodUI)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 CARA PENGGUNAAN DI GAME APAPUN:
	
	local RitodUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/ritod_ui.lua"))()

	local Window = RitodUI:CreateWindow({
		Title = "⚡RITOD HUB⚡",
		GameName = "Nama Game Kamu",
		Size = Vector2.new(700, 460),
		OnUnload = function()
			-- Matikan semua worker / loop game di sini
		end
	})

	local MainTab = Window:CreateTab("Main", "🏠")
	MainTab:AddSection("Fitur Utama")
	MainTab:AddToggle("Auto Farm", false, function(state) print("Auto Farm:", state) end)
	MainTab:AddSlider("Speed", 16, 250, 16, function(val) print("Speed:", val) end)
	MainTab:AddButton("Teleport Spawn", function() print("Teleporting...") end)

	-- Otomatis buat Tab Settings 3-Card (Config, Import/Export, Utility)
	Window:CreateSettingsTab({
		GameFolder = "RitodHub/NamaGame",
		DefaultConfig = { AutoFarm = false, Speed = 16 },
		GetCurrentConfig = function() return { AutoFarm = true, Speed = 20 } end,
		ApplyConfig = function(cfg) print("Applying config:", cfg) end,
		ScriptUrl = "https://raw.githubusercontent.com/.../main.lua"
	})
	===============================================================
]]

local RitodUI = {}
RitodUI.__index = RitodUI
_G.RitodUI = RitodUI

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

-- ─── Cached TweenInfos ─────────────────────────────────────────
local TW_FAST = TweenInfo.new(0.15)
local TW_MED  = TweenInfo.new(0.2)
local TW_BOUNCE = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- ─── Helper Instance Builder ───────────────────────────────────
local function n(cls, props, parent)
	local inst = Instance.new(cls)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(r, p) return n("UICorner", {CornerRadius = UDim.new(0, r)}, p) end
local function stroke(t, c, p) return n("UIStroke", {Thickness = t, Color = c}, p) end
local function pad(l, r, t, b, p)
	return n("UIPadding", {PaddingLeft=UDim.new(0,l), PaddingRight=UDim.new(0,r), PaddingTop=UDim.new(0,t), PaddingBottom=UDim.new(0,b)}, p)
end

-- ─── Draggable Helper ──────────────────────────────────────────
local function makeDraggable(frame, dragHandle, onClick)
	dragHandle = dragHandle or frame
	local dragging = false
	local dragStart, startPos
	local hasMoved = false
	local pressStartTime = 0
	local lastClickTime = 0

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			hasMoved = false
			pressStartTime = tick()
			dragStart = input.Position
			startPos = frame.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			if delta.Magnitude > 12 then
				hasMoved = true
				frame.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			local duration = tick() - pressStartTime
			if not hasMoved and onClick and duration < 0.5 then
				local now = tick()
				if now - lastClickTime > 0.08 then
					lastClickTime = now
					onClick()
				end
			end
		end
	end)
end

-- ===============================================================
-- 🖥️ CREATE WINDOW
-- ===============================================================
function RitodUI:CreateWindow(options)
	options = options or {}
	local titleText = options.Title or "⚡RITOD HUB⚡"
	local winWidth  = options.Size and options.Size.X or 700
	local winHeight = options.Size and options.Size.Y or 460
	local onUnloadCallback = options.OnUnload

	local parentGui
	if typeof(gethui) == "function" then
		parentGui = gethui()
	elseif run_secure_function or getexecutorname then
		parentGui = CoreGui
	else
		parentGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui
	end

	-- Bersihkan instance lama jika ada
	if parentGui:FindFirstChild("RitodHubUltra") then
		parentGui:FindFirstChild("RitodHubUltra"):Destroy()
	end

	local screenGui = n("ScreenGui", {
		Name = "RitodHubUltra",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	}, parentGui)

	_G.RitodHubGui = screenGui

	-- ── Notif Holder ───────────────────────────────────────────
	local notifHolder = n("Frame", {
		Name = "NotifHolder",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.new(0, 300, 1, -48),
		BackgroundTransparency = 1,
		ZIndex = 200
	}, screenGui)

	n("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 10)
	}, notifHolder)

	local function Notify(title, desc, duration)
		duration = duration or 3.0
		local notif = n("Frame", {
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = Color3.fromRGB(18, 14, 24),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Position = UDim2.new(1, 100, 0, 0),
			ZIndex = 201
		}, notifHolder)
		corner(12, notif)
		stroke(1.4, Color3.fromRGB(185, 90, 255), notif)

		local glow = n("Frame", {
			Size = UDim2.new(0, 4, 1, -16),
			Position = UDim2.new(0, 8, 0, 8),
			BackgroundColor3 = Color3.fromRGB(185, 90, 255),
			BorderSizePixel = 0,
			ZIndex = 202
		}, notif)
		corner(1, glow)

		n("TextLabel", {
			Position = UDim2.new(0, 22, 0, 10),
			Size = UDim2.new(1, -30, 0, 18),
			BackgroundTransparency = 1,
			Text = title or "⚡RITOD HUB⚡",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 202
		}, notif)

		n("TextLabel", {
			Position = UDim2.new(0, 22, 0, 30),
			Size = UDim2.new(1, -30, 0, 24),
			BackgroundTransparency = 1,
			Text = desc or "",
			TextColor3 = Color3.fromRGB(190, 175, 205),
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ZIndex = 202
		}, notif)

		TweenService:Create(notif, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

		task.delay(duration, function()
			if notif and notif.Parent then
				local out = TweenService:Create(notif, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 150, 0, 0)})
				out:Play()
				out.Completed:Connect(function() notif:Destroy() end)
			end
		end)
	end

	-- ── Main Hub Window ────────────────────────────────────────
	local mainFrame = n("Frame", {
		Name = "MainHub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, winWidth, 0, winHeight),
		BackgroundColor3 = Color3.fromRGB(15, 12, 20),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 10
	}, screenGui)
	corner(16, mainFrame)
	stroke(1.6, Color3.fromRGB(165, 85, 255), mainFrame)

	-- TopBar
	local topBar = n("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Color3.fromRGB(22, 17, 30),
		BorderSizePixel = 0,
		ZIndex = 11
	}, mainFrame)
	corner(16, topBar)

	n("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -16),
		BackgroundColor3 = Color3.fromRGB(22, 17, 30),
		BorderSizePixel = 0,
		ZIndex = 11
	}, topBar)

	makeDraggable(mainFrame, topBar)

	-- TopBar Title (⚡RITOD HUB⚡)
	n("TextLabel", {
		Position = UDim2.new(0, 18, 0, 0),
		Size = UDim2.new(0, 360, 1, 0),
		BackgroundTransparency = 1,
		Text = titleText,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12
	}, topBar)

	-- Stats Label (FPS & Ping)
	local statsLabel = n("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -95, 0.5, 0),
		Size = UDim2.new(0, 160, 0, 24),
		BackgroundTransparency = 1,
		Text = "FPS: 60  |  PING: 35ms",
		TextColor3 = Color3.fromRGB(160, 145, 175),
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 12
	}, topBar)

	task.spawn(function()
		local lastTime = tick()
		local frameCount = 0
		RunService.RenderStepped:Connect(function()
			frameCount = frameCount + 1
			local curTime = tick()
			if curTime - lastTime >= 1 then
				local fps = math.floor(frameCount / (curTime - lastTime))
				local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
				statsLabel.Text = string.format("FPS: %d  |  PING: %dms", fps, ping)
				frameCount = 0
				lastTime = curTime
			end
		end)
	end)

	-- Close & Minimize Buttons
	local closeBtn = n("TextButton", {
		Name = "CloseBtn",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 32, 0, 32),
		BackgroundColor3 = Color3.fromRGB(48, 22, 34),
		AutoButtonColor = false,
		Text = "X",
		TextColor3 = Color3.fromRGB(255, 110, 130),
		TextSize = 14,
		Font = Enum.Font.GothamBlack,
		ZIndex = 25
	}, topBar)
	corner(8, closeBtn)

	local minBtn = n("TextButton", {
		Name = "MinBtn",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -50, 0.5, 0),
		Size = UDim2.new(0, 32, 0, 32),
		BackgroundColor3 = Color3.fromRGB(32, 26, 42),
		AutoButtonColor = false,
		Text = "-",
		TextColor3 = Color3.fromRGB(180, 160, 205),
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		ZIndex = 25
	}, topBar)
	corner(8, minBtn)

	closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TW_FAST, {BackgroundColor3 = Color3.fromRGB(235, 45, 75), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end)
	closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TW_FAST, {BackgroundColor3 = Color3.fromRGB(48, 22, 34), TextColor3 = Color3.fromRGB(255, 110, 130)}):Play() end)

	minBtn.MouseEnter:Connect(function() TweenService:Create(minBtn, TW_FAST, {BackgroundColor3 = Color3.fromRGB(55, 42, 70), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end)
	minBtn.MouseLeave:Connect(function() TweenService:Create(minBtn, TW_FAST, {BackgroundColor3 = Color3.fromRGB(32, 26, 42), TextColor3 = Color3.fromRGB(180, 160, 205)}):Play() end)

	-- ── Unload Modal ───────────────────────────────────────────
	local modalOverlay = n("Frame", {
		Name = "ModalOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 150
	}, mainFrame)

	local modalBox = n("Frame", {
		Name = "ModalBox",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 360, 0, 175),
		BackgroundColor3 = Color3.fromRGB(22, 17, 28),
		BorderSizePixel = 0,
		ZIndex = 151
	}, modalOverlay)
	corner(14, modalBox)
	stroke(1.8, Color3.fromRGB(255, 75, 100), modalBox)

	n("TextLabel", {
		Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = "⚠️ Unload RITOD Hub?",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		ZIndex = 152
	}, modalBox)

	n("TextLabel", {
		Position = UDim2.new(0, 24, 0, 48),
		Size = UDim2.new(1, -48, 0, 40),
		BackgroundTransparency = 1,
		Text = "Apakah kamu yakin ingin menutup dan menghentikan seluruh script Ritod Hub?",
		TextColor3 = Color3.fromRGB(180, 165, 195),
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextWrapped = true,
		ZIndex = 152
	}, modalBox)

	local yesBtn = n("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -18),
		Size = UDim2.new(0, 145, 0, 38),
		BackgroundColor3 = Color3.fromRGB(235, 45, 75),
		AutoButtonColor = false,
		Text = "Yes, Unload",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		ZIndex = 153
	}, modalBox)
	corner(8, yesBtn)

	local cancelBtn = n("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -18),
		Size = UDim2.new(0, 145, 0, 38),
		BackgroundColor3 = Color3.fromRGB(40, 32, 48),
		AutoButtonColor = false,
		Text = "Cancel",
		TextColor3 = Color3.fromRGB(200, 185, 215),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		ZIndex = 153
	}, modalBox)
	corner(8, cancelBtn)

	local function showUnloadModal()
		modalOverlay.Visible = true
		modalBox.Position = UDim2.new(0.5, 0, 0.55, 0)
		TweenService:Create(modalOverlay, TW_MED, {BackgroundTransparency = 0.5}):Play()
		TweenService:Create(modalBox, TW_BOUNCE, {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
	end

	local function hideUnloadModal()
		local t = TweenService:Create(modalOverlay, TW_MED, {BackgroundTransparency = 1})
		TweenService:Create(modalBox, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0.55, 0)}):Play()
		t:Play()
		t.Completed:Connect(function() modalOverlay.Visible = false end)
	end

	closeBtn.Activated:Connect(showUnloadModal)
	cancelBtn.Activated:Connect(hideUnloadModal)

	yesBtn.Activated:Connect(function()
		print("🛑 [Ritod Hub] Meng-unload script...")
		if onUnloadCallback then pcall(onUnloadCallback) end
		if screenGui then screenGui:Destroy() end
		print("✅ [Ritod Hub] Berhasil di-unload bersih!")
	end)

	-- ── Floating Widget (Icon ⚡ + Gradient + Pulse) ─────────────
	local floatWidget = n("TextButton", {
		Name = "FloatWidget",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.5, 0),
		Size = UDim2.new(0, 60, 0, 60),
		BackgroundColor3 = Color3.fromRGB(20, 14, 28),
		BorderSizePixel = 0,
		ZIndex = 100,
		Active = true,
		AutoButtonColor = false,
		Text = ""
	}, screenGui)
	corner(18, floatWidget)

	local floatStroke = stroke(2.5, Color3.fromRGB(190, 90, 255), floatWidget)
	floatStroke.Transparency = 0.2

	local strokeGrad = n("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 160)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 90, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 210, 255)),
		}),
		Rotation = 45
	}, floatStroke)

	local floatBgGrad = n("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 20, 48)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 10, 24)),
		}),
		Rotation = 90
	}, floatWidget)

	-- ⚡ Icon Petir
	n("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "⚡",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 26,
		Font = Enum.Font.GothamBlack,
		ZIndex = 101
	}, floatWidget)

	local statusDot = n("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.new(0, 10, 0, 10),
		BackgroundColor3 = Color3.fromRGB(70, 255, 140),
		BorderSizePixel = 0,
		ZIndex = 102
	}, floatWidget)
	corner(1, statusDot)
	stroke(2, Color3.fromRGB(20, 14, 28), statusDot)

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
	local hubSavedPosition = mainFrame.Position

	local function toggleHub()
		isHubVisible = not isHubVisible
		if isHubVisible then
			mainFrame.Visible = true
			mainFrame.Position = UDim2.new(hubSavedPosition.X.Scale, hubSavedPosition.X.Offset, hubSavedPosition.Y.Scale, hubSavedPosition.Y.Offset + 20)
			TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = hubSavedPosition}):Play()
		else
			local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(hubSavedPosition.X.Scale, hubSavedPosition.X.Offset, hubSavedPosition.Y.Scale, hubSavedPosition.Y.Offset + 20)
			})
			closeTween:Play()
			closeTween.Completed:Connect(function()
				if not isHubVisible then mainFrame.Visible = false end
				mainFrame.Position = hubSavedPosition
			end)
		end
	end

	local lastFloatClick = 0
	local function triggerFloatToggle()
		local now = tick()
		if now - lastFloatClick < 0.1 then return end
		lastFloatClick = now
		TweenService:Create(floatWidget, TweenInfo.new(0.06), {Size = UDim2.new(0, 52, 0, 52)}):Play()
		task.delay(0.07, function()
			pcall(function()
				TweenService:Create(floatWidget, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 60, 0, 60)}):Play()
			end)
		end)
		toggleHub()
	end

	makeDraggable(floatWidget, floatWidget, triggerFloatToggle)
	floatWidget.Activated:Connect(triggerFloatToggle)
	minBtn.Activated:Connect(toggleHub)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
			toggleHub()
		end
	end)

	-- ── Sidebar & Content Area ─────────────────────────────────
	local sideBar = n("Frame", {
		Name = "SideBar",
		Position = UDim2.new(0, 0, 0, 50),
		Size = UDim2.new(0, 170, 1, -50),
		BackgroundColor3 = Color3.fromRGB(18, 14, 25),
		BorderSizePixel = 0,
		ZIndex = 11
	}, mainFrame)
	pad(10, 10, 14, 0, sideBar)

	n("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder
	}, sideBar)

	local contentArea = n("Frame", {
		Name = "ContentArea",
		Position = UDim2.new(0, 170, 0, 50),
		Size = UDim2.new(1, -170, 1, -50),
		BackgroundTransparency = 1,
		ZIndex = 11
	}, mainFrame)

	-- ── Window Instance ────────────────────────────────────────
	local WindowObj = {
		ScreenGui = screenGui,
		MainFrame = mainFrame,
		ContentArea = contentArea,
		Notify = Notify,
		Toggle = toggleHub,
		Tabs = {},
		ActiveTab = nil
	}

	-- ── CreateTab Method ───────────────────────────────────────
	function WindowObj:CreateTab(name, icon)
		local tabBtn = n("TextButton", {
			Name = name .. "Tab",
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = Color3.fromRGB(30, 22, 40),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = (icon and (icon .. "  ") or "") .. name,
			TextColor3 = Color3.fromRGB(160, 140, 175),
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Active = true
		}, sideBar)
		corner(10, tabBtn)
		pad(12, 0, 0, 0, tabBtn)

		local indicator = n("Frame", {
			Size = UDim2.new(0, 4, 0, 20),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -8, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(190, 90, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 13
		}, tabBtn)
		corner(1, indicator)

		local page = n("ScrollingFrame", {
			Name = name .. "Page",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(160, 80, 240),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			ZIndex = 12
		}, contentArea)
		pad(14, 14, 14, 14, page)

		n("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8)
		}, page)

		local tabData = { Button = tabBtn, Page = page, Name = name }

		local function activateTab()
			for _, t in pairs(WindowObj.Tabs) do
				t.Page.Visible = false
				TweenService:Create(t.Button, TW_FAST, {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(160, 140, 175)}):Play()
				local ind = t.Button:FindFirstChildWhichIsA("Frame")
				if ind then TweenService:Create(ind, TW_FAST, {BackgroundTransparency = 1}):Play() end
			end
			page.Visible = true
			TweenService:Create(tabBtn, TW_FAST, {BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = Color3.fromRGB(150, 65, 240)}):Play()
			TweenService:Create(indicator, TW_FAST, {BackgroundTransparency = 0}):Play()
			WindowObj.ActiveTab = tabData
		end

		tabBtn.Activated:Connect(activateTab)
		tabBtn.MouseButton1Click:Connect(activateTab)

		if not WindowObj.ActiveTab then
			activateTab()
		end

		table.insert(WindowObj.Tabs, tabData)

		-- ── Tab Elements Builder ───────────────────────────────
		local elements = { Page = page, Window = WindowObj }

		function elements:AddSection(title)
			local sec = n("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, ZIndex = 13}, page)
			n("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = string.upper(title),
				TextColor3 = Color3.fromRGB(180, 120, 255),
				TextSize = 11,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 13
			}, sec)
			return sec
		end

		function elements:AddButton(text, callback)
			local btn = n("TextButton", {
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundColor3 = Color3.fromRGB(26, 20, 34),
				AutoButtonColor = false,
				Text = text,
				TextColor3 = Color3.fromRGB(235, 225, 245),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				ZIndex = 14,
				Active = true
			}, page)
			corner(8, btn)
			local bStroke = stroke(1, Color3.fromRGB(70, 50, 85), btn)

			btn.MouseEnter:Connect(function()
				TweenService:Create(btn, TW_FAST, {BackgroundColor3 = Color3.fromRGB(38, 28, 50), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
				TweenService:Create(bStroke, TW_FAST, {Color = Color3.fromRGB(180, 90, 255)}):Play()
			end)
			btn.MouseLeave:Connect(function()
				TweenService:Create(btn, TW_FAST, {BackgroundColor3 = Color3.fromRGB(26, 20, 34), TextColor3 = Color3.fromRGB(235, 225, 245)}):Play()
				TweenService:Create(bStroke, TW_FAST, {Color = Color3.fromRGB(70, 50, 85)}):Play()
			end)

			local lastBtnClick = 0
			local function onClick()
				local now = tick()
				if now - lastBtnClick < 0.15 then return end
				lastBtnClick = now
				TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(160, 75, 250)}):Play()
				task.delay(0.12, function()
					pcall(function() TweenService:Create(btn, TW_FAST, {BackgroundColor3 = Color3.fromRGB(26, 20, 34)}):Play() end)
				end)
				if callback then callback() end
			end

			btn.Activated:Connect(onClick)
			btn.MouseButton1Click:Connect(onClick)
			return btn
		end

		function elements:AddToggle(text, default, callback)
			local state = default or false
			local toggleFrame = n("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(26, 20, 34), BorderSizePixel = 0, ZIndex = 14}, page)
			corner(8, toggleFrame)

			n("TextLabel", {
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(1, -70, 1, 0),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = Color3.fromRGB(235, 225, 245),
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 15
			}, toggleFrame)

			local switch = n("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0, 44, 0, 22),
				BackgroundColor3 = state and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(50, 38, 60),
				BorderSizePixel = 0,
				ZIndex = 15
			}, toggleFrame)
			corner(1, switch)

			local knob = n("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.new(0, 16, 0, 16),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				ZIndex = 16
			}, switch)
			corner(1, knob)

			local function updateToggle(fireCallback)
				if state then
					TweenService:Create(switch, TW_MED, {BackgroundColor3 = Color3.fromRGB(175, 75, 255)}):Play()
					TweenService:Create(knob, TW_MED, {Position = UDim2.new(1, -19, 0.5, 0)}):Play()
				else
					TweenService:Create(switch, TW_MED, {BackgroundColor3 = Color3.fromRGB(50, 38, 60)}):Play()
					TweenService:Create(knob, TW_MED, {Position = UDim2.new(0, 3, 0.5, 0)}):Play()
				end
				if fireCallback and callback then callback(state) end
			end

			local fullClick = n("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 20,
				Active = true
			}, toggleFrame)

			local lastToggleClick = 0
			local function onToggleClick()
				local now = tick()
				if now - lastToggleClick < 0.15 then return end
				lastToggleClick = now
				state = not state
				updateToggle(true)
			end

			fullClick.Activated:Connect(onToggleClick)
			fullClick.MouseButton1Click:Connect(onToggleClick)

			return {
				Set = function(self, val, fireCallback)
					state = val
					updateToggle(fireCallback)
				end,
				Get = function(self) return state end
			}
		end

		function elements:AddSlider(text, min, max, default, callback)
			local val = default or min
			local sliderFrame = n("Frame", {Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Color3.fromRGB(26, 20, 34), BorderSizePixel = 0, ZIndex = 14}, page)
			corner(8, sliderFrame)

			n("TextLabel", {
				Position = UDim2.new(0, 12, 0, 8),
				Size = UDim2.new(1, -80, 0, 16),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = Color3.fromRGB(235, 225, 245),
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 15
			}, sliderFrame)

			local valLabel = n("TextLabel", {
				Position = UDim2.new(1, -68, 0, 8),
				Size = UDim2.new(0, 56, 0, 16),
				BackgroundTransparency = 1,
				Text = tostring(val),
				TextColor3 = Color3.fromRGB(205, 140, 255),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 15
			}, sliderFrame)

			local barBack = n("Frame", {
				Position = UDim2.new(0, 12, 0, 32),
				Size = UDim2.new(1, -24, 0, 8),
				BackgroundColor3 = Color3.fromRGB(48, 38, 58),
				BorderSizePixel = 0,
				ZIndex = 15
			}, sliderFrame)
			corner(1, barBack)

			local initRatio = math.clamp((val - min) / math.max(max - min, 1), 0, 1)
			local barFill = n("Frame", {
				Size = UDim2.new(initRatio, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(180, 85, 255),
				BorderSizePixel = 0,
				ZIndex = 16
			}, barBack)
			corner(1, barFill)

			local sliding = false
			local function setSlider(input)
				local absPos = barBack.AbsolutePosition.X
				local absSize = barBack.AbsoluteSize.X
				if absSize <= 0 then return end
				local relX = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
				barFill.Size = UDim2.new(relX, 0, 1, 0)
				local current = math.floor(min + ((max - min) * relX))
				val = current
				valLabel.Text = tostring(current)
				if callback then callback(current) end
			end

			local slideClick = n("TextButton", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 20,
				Active = true
			}, sliderFrame)

			slideClick.InputBegan:Connect(function(input)
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
				Get = function(self) return val end
			}
		end

		function elements:AddInput(placeholder, callback)
			local inputFrame = n("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Color3.fromRGB(26, 20, 34),
				BorderSizePixel = 0,
				ZIndex = 14
			}, page)
			corner(8, inputFrame)

			local tb = n("TextBox", {
				Size = UDim2.new(1, -24, 1, 0),
				Position = UDim2.new(0, 12, 0, 0),
				BackgroundTransparency = 1,
				PlaceholderText = placeholder or "Type here...",
				PlaceholderColor3 = Color3.fromRGB(140, 120, 155),
				Text = "",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
				ZIndex = 15
			}, inputFrame)

			tb:GetPropertyChangedSignal("Text"):Connect(function()
				if callback then callback(tb.Text) end
			end)
			tb.FocusLost:Connect(function()
				if callback then callback(tb.Text) end
			end)
			return tb
		end

		function elements:AddDropdown(text, list, default, callback)
			local open = false
			local selected = default or (list and list[1]) or ""
			local itemH = 32
			local dropFrame = n("Frame", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = Color3.fromRGB(26, 20, 34),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				ZIndex = 20
			}, page)
			corner(8, dropFrame)

			local header = n("TextButton", {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 21,
				Active = true
			}, dropFrame)

			local titleLbl = n("TextLabel", {
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = Color3.fromRGB(235, 225, 245),
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 22
			}, header)

			local selLbl = n("TextLabel", {
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.new(0.5, -30, 1, 0),
				BackgroundTransparency = 1,
				Text = tostring(selected),
				TextColor3 = Color3.fromRGB(190, 120, 255),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 22
			}, header)

			local arrow = n("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0, 16, 0, 16),
				BackgroundTransparency = 1,
				Text = "▼",
				TextColor3 = Color3.fromRGB(160, 140, 175),
				TextSize = 10,
				Font = Enum.Font.GothamBold,
				ZIndex = 22
			}, header)

			local listContainer = n("Frame", {
				Position = UDim2.new(0, 0, 0, 42),
				Size = UDim2.new(1, 0, 0, #(list or {}) * itemH),
				BackgroundTransparency = 1,
				ZIndex = 21
			}, dropFrame)

			local function toggleDrop()
				open = not open
				local targetH = open and (42 + (#(list or {}) * itemH)) or 42
				TweenService:Create(dropFrame, TW_MED, {Size = UDim2.new(1, 0, 0, targetH)}):Play()
				arrow.Text = open and "▲" or "▼"
			end

			header.Activated:Connect(toggleDrop)

			for i, itemText in ipairs(list or {}) do
				local itemBtn = n("TextButton", {
					Position = UDim2.new(0, 0, 0, (i - 1) * itemH),
					Size = UDim2.new(1, 0, 0, itemH),
					BackgroundColor3 = Color3.fromRGB(32, 24, 42),
					BackgroundTransparency = (itemText == selected) and 0.3 or 0.8,
					Text = "   " .. tostring(itemText),
					TextColor3 = (itemText == selected) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 165, 195),
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 23,
					Active = true
				}, listContainer)

				itemBtn.Activated:Connect(function()
					selected = itemText
					selLbl.Text = tostring(selected)
					toggleDrop()
					if callback then callback(selected) end
				end)
			end

			return {
				Set = function(self, val, fireCb)
					selected = val
					selLbl.Text = tostring(val)
					if fireCb and callback then callback(val) end
				end,
				Get = function(self) return selected end
			}
		end

		return elements
	end

	-- ── CreateSettingsTab (Plug & Play 3-Card Modern Settings) ──
	function WindowObj:CreateSettingsTab(settingsOptions)
		settingsOptions = settingsOptions or {}
		local SettingsTab = self:CreateTab("Settings", "⚙️")
		
		local ModernSettings
		local sharedPath = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/modern_settings.lua"
		pcall(function()
			ModernSettings = loadstring(game:HttpGet(sharedPath))()
		end)

		if ModernSettings then
			local ProfileManager = ModernSettings.CreateProfileManager(
				settingsOptions.GameFolder or "RitodHub/Game",
				settingsOptions.DefaultConfig or {},
				settingsOptions.GetCurrentConfig or function() return {} end,
				settingsOptions.ApplyConfig or function() end,
				Notify
			)
			ModernSettings.BuildUI(
				SettingsTab.Page,
				ProfileManager,
				settingsOptions.ScriptUrl or "",
				Notify
			)
		end

		SettingsTab:AddSection("Kontrol GUI")
		SettingsTab:AddButton("➖ Minimize GUI", function() toggleHub() end)
		SettingsTab:AddButton("🛑 Tutup & Unload Script", function() showUnloadModal() end)
		return SettingsTab
	end

	return WindowObj
end

return RitodUI
