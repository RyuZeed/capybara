--[[
	===============================================================
	⚡ RITOD HUB - ROLL ANIME FOR FIGHT (ULTRA GRAPHICS OPTIMIZER V6.0)
	Module: modules/roll_anime/graphics.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🌟 FEATURES (STANDARDIZED WITH FISH AN ANIME ENGINE):
	- 🥔 Potato Graphics Engine (Level01, SmoothPlastic, No Shadows, Fog Strip)
	- 👻 Other Player & Plot Hider (Ghost Mode, 100% Invisible, Zero Physics Lag)
	- 🤖 Enemy & NPC Animation Pauser (CPU Saver Terbesar - Non-Breaking)
	- 💀 Disable All VFX & Skill Particles (Particles, Trails, Beams, Lights, 3D Sounds)
	- 🌑 AMOLED Screen Off / Farm Mode (Engine 3D Rendering Disabled, CPU/GPU ~5%)
	- 🎯 Multi-Executor Native FPS Cap Controller (8 Fallback Vectors)
	- 🧹 Periodic RAM Purge & Garbage Collector
	- 🔄 Realtime DescendantAdded Hook (Instant Strip on Mass Roll & Spawn)
	- 🛡️ Strict LocalPlayer, Plot, and Interactive Prompt Guardian
	===============================================================
]]

local Graphics = {}
Graphics.__index = Graphics
_G.GraphicsModule = Graphics
_G.GraphicsOptimizer = Graphics

-- 🔇 SILENT MODE (Zero console spam)
local print = function(...) end
local warn = function(...) end

-- Services
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

-- =================================================================
-- ⚙️ STATE & CONFIGURATION
-- =================================================================
Graphics.PotatoEnabled           = false
Graphics.ScreenOffEnabled         = false
Graphics.AutoMemoryCleanupEnabled = true
Graphics.HideOtherPlayersEnabled  = false
Graphics.FreezeNPCsEnabled        = false
Graphics.DisableVFXEnabled        = false
Graphics.TargetFPS                = 60
Graphics.AntiLagEnabled           = false

local memoryCleanupThread = nil
local screenOffGui        = nil
local potatoSweeperThread = nil
local guardianThread      = nil
local descendantConn      = nil
local playerAddedConn     = nil
local originalLighting    = {}
local connections         = {}
local syncCallback        = nil
local farmModeWatchdog    = nil

local FROZEN_TAG = "_r_frozen_v6"
local STRIPPED_TAG = "_r_stripped_v6"

-- Cache Plot Milik Sendiri
local cachedMyPlot = nil
local lastPlotCheck = 0

-- =================================================================
-- 🏰 SMART PLOT ISOLATOR (PROTECT LOCAL PLAYER & OWN PLOT)
-- =================================================================
local function getMyPlot()
	local now = os.clock()
	if cachedMyPlot and cachedMyPlot.Parent and (now - lastPlotCheck < 10) then
		return cachedMyPlot
	end
	lastPlotCheck = now

	local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Bases")
	if not plots then return nil end

	local pName = LocalPlayer.Name
	local uId = tostring(LocalPlayer.UserId)
	local dName = LocalPlayer.DisplayName

	-- Method 1: Nama Plot
	for _, plot in ipairs(plots:GetChildren()) do
		if plot.Name == pName or plot.Name == uId then
			cachedMyPlot = plot
			return plot
		end
	end

	-- Method 2: Attributes
	for _, plot in ipairs(plots:GetChildren()) do
		for _, attrVal in pairs(plot:GetAttributes()) do
			local s = tostring(attrVal)
			if s == pName or s == uId or s == dName then
				cachedMyPlot = plot
				return plot
			end
		end
	end

	-- Method 3: Billboard / TextLabels
	for _, plot in ipairs(plots:GetChildren()) do
		local sign = plot:FindFirstChild("NameBillboardPart", true) or plot:FindFirstChild("OwnerSign", true)
		if sign then
			for _, d in ipairs(sign:GetDescendants()) do
				if d:IsA("TextLabel") and (d.Text == pName or d.Text == dName or string.find(d.Text, pName) or string.find(d.Text, dName)) then
					cachedMyPlot = plot
					return plot
				end
			end
		end
	end

	-- Method 4: Jarak Terdekat ke HRP
	local char = LocalPlayer.Character
	local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
	if hrp then
		local closest, cDist = nil, 100
		for _, plot in ipairs(plots:GetChildren()) do
			local part = plot:FindFirstChildWhichIsA("BasePart", true)
			if part then
				local dist = (part.Position - hrp.Position).Magnitude
				if dist < cDist then
					cDist = dist
					closest = plot
				end
			end
		end
		if closest then
			cachedMyPlot = closest
			return closest
		end
	end

	return nil
end

-- =================================================================
-- 1. 🛡️ STRICT OBJECT & INTERACTION PROTECTOR
-- =================================================================
local function isProtectedObject(obj)
	if not obj or not obj.Parent then return true end

	-- 1. LocalPlayer Character
	local char = LocalPlayer.Character
	if char and (obj == char or obj:IsDescendantOf(char)) then
		return true
	end

	-- 2. Player Model Check
	local p = Players:GetPlayerFromCharacter(obj) or Players:GetPlayerFromCharacter(obj.Parent)
	if p and p == LocalPlayer then
		return true
	end

	-- 3. Backpack & Tools
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
	if bp and (obj == bp or obj:IsDescendantOf(bp)) then
		return true
	end

	-- 4. Camera
	local cam = Workspace.CurrentCamera
	if cam and (obj == cam or obj:IsDescendantOf(cam)) then
		return true
	end

	-- 5. ProximityPrompts & Interactive Roll Buttons
	if obj:IsA("ProximityPrompt") or obj:FindFirstChildOfClass("ProximityPrompt")
	   or obj:IsA("ClickDetector") or obj:FindFirstChildOfClass("ClickDetector") then
		return true
	end

	-- 6. Plot Sendiri & Tombol Roll di Plot
	local myPlot = getMyPlot()
	if myPlot and (obj == myPlot or obj:IsDescendantOf(myPlot)) then
		-- Jangan sentuh tombol roll atau slot unit milik sendiri
		if obj.Name:find("Roll") or obj.Name:find("Summon") or obj.Name:find("Button") or obj.Name:find("slot") then
			return true
		end
	end

	-- 7. NPC Trader & Machine Interaction
	if obj.Name == "TraderChar" or obj.Name == "TraderPlatform" or obj.Name == "NPCTalk" then
		return true
	end

	return false
end

-- =================================================================
-- 2. 🛡️ PLAYER MOVEMENT GUARDIAN
-- =================================================================
local function ensurePlayerMovementNormal()
	pcall(function()
		local char = LocalPlayer.Character
		if not char then return end

		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			if hum.PlatformStand then hum.PlatformStand = false end
			if not hum.AutoRotate then hum.AutoRotate = true end
		end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Anchored then
			hrp.Anchored = false
		end

		for _, part in ipairs(char:GetChildren()) do
			if part:IsA("BasePart") and part.Anchored and part.Name ~= "HumanoidRootPart" then
				part.Anchored = false
			end
		end
	end)
end

local function startGuardian()
	if guardianThread then return end
	guardianThread = task.spawn(function()
		while Graphics.PotatoEnabled or Graphics.FreezeNPCsEnabled or Graphics.HideOtherPlayersEnabled or Graphics.DisableVFXEnabled do
			ensurePlayerMovementNormal()
			task.wait(2.0)
		end
		guardianThread = nil
	end)
end

-- =================================================================
-- 3. 🥔 POTATO GRAPHICS ENGINE
-- =================================================================
pcall(function()
	originalLighting = {
		GlobalShadows = Lighting.GlobalShadows,
		FogEnd        = Lighting.FogEnd,
		Brightness    = Lighting.Brightness,
		ClockTime     = Lighting.ClockTime,
		Technology    = Lighting.Technology
	}
end)

local function stripObject(v)
	if not v or not v.Parent or isProtectedObject(v) then return end
	if v:GetAttribute(STRIPPED_TAG) then return end
	v:SetAttribute(STRIPPED_TAG, true)

	pcall(function()
		local cls = v.ClassName
		if v:IsA("BasePart") then
			v.Material = Enum.Material.SmoothPlastic
			v.Reflectance = 0
			v.CastShadow = false
		elseif cls == "Decal" or cls == "Texture" then
			v.Transparency = 1
		elseif cls == "ParticleEmitter" then
			v.Enabled = false
			v.Rate = 0
		elseif cls == "Trail" or cls == "Beam" or cls == "Highlight"
			or cls == "Fire" or cls == "Smoke" or cls == "Sparkles" then
			v.Enabled = false
		elseif cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
			v.Enabled = false
		end
	end)
end

function Graphics.EnablePotatoGraphics()
	Graphics.PotatoEnabled = true
	startGuardian()

	pcall(function()
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 9e9
		Lighting.Brightness = 2
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)

		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect")
				or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect")
				or effect:IsA("Atmosphere") or effect:IsA("Sky") then
				pcall(function() effect.Enabled = false end)
			end
		end

		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			terrain.WaterWaveSize = 0
			terrain.WaterWaveSpeed = 0
			terrain.WaterReflectance = 0
			terrain.WaterTransparency = 0
		end
	end)

	-- Real-time DescendantAdded Hook
	if not descendantConn then
		descendantConn = Workspace.DescendantAdded:Connect(function(v)
			if Graphics.PotatoEnabled and not isProtectedObject(v) then
				stripObject(v)
			end
		end)
		table.insert(connections, descendantConn)
	end

	-- Sweep Workspace in chunks
	task.spawn(function()
		local count = 0
		for _, v in ipairs(Workspace:GetDescendants()) do
			if not Graphics.PotatoEnabled then break end
			if not isProtectedObject(v) then
				stripObject(v)
			end
			count = count + 1
			if count % 300 == 0 then task.wait() end
		end
	end)

	ensurePlayerMovementNormal()
end

function Graphics.DisablePotatoGraphics()
	Graphics.PotatoEnabled = false
	if descendantConn then
		pcall(function() descendantConn:Disconnect() end)
		descendantConn = nil
	end

	pcall(function()
		pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
		if originalLighting.GlobalShadows ~= nil then
			Lighting.GlobalShadows = originalLighting.GlobalShadows
			Lighting.FogEnd = originalLighting.FogEnd or 10000
			Lighting.Brightness = originalLighting.Brightness or 2
		end
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("PostEffect") then pcall(function() effect.Enabled = true end) end
		end
	end)

	ensurePlayerMovementNormal()
end

-- =================================================================
-- 4. 🤖 ENEMY & NPC ANIMATION PAUSER (CPU SAVER TERBESAR)
-- =================================================================
local function pauseAnimatorTracks(animator)
	if not animator or not animator.Parent or isProtectedObject(animator) then return end
	pcall(function()
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function() track:AdjustSpeed(0) end)
		end
		if not animator:GetAttribute(FROZEN_TAG) then
			animator:SetAttribute(FROZEN_TAG, true)
			animator.AnimationPlayed:Connect(function(track)
				if Graphics.FreezeNPCsEnabled and not isProtectedObject(animator) then
					pcall(function() track:AdjustSpeed(0) end)
				end
			end)
		end
	end)
end

function Graphics.FreezeAllNPCsAndAnimations()
	Graphics.FreezeNPCsEnabled = true
	startGuardian()

	task.spawn(function()
		local count = 0
		for _, desc in ipairs(Workspace:GetDescendants()) do
			if not Graphics.FreezeNPCsEnabled then break end
			if not isProtectedObject(desc) then
				if desc:IsA("Animator") or desc:IsA("AnimationController") then
					pauseAnimatorTracks(desc)
				end
			end
			count = count + 1
			if count % 400 == 0 then task.wait() end
		end
	end)

	ensurePlayerMovementNormal()
end

function Graphics.UnfreezeNPCs()
	Graphics.FreezeNPCsEnabled = false
	task.spawn(function()
		for _, desc in ipairs(Workspace:GetDescendants()) do
			if desc:IsA("Animator") or desc:IsA("AnimationController") then
				pcall(function()
					for _, track in ipairs(desc:GetPlayingAnimationTracks()) do
						pcall(function() track:AdjustSpeed(1) end)
					end
				end)
			end
		end
	end)
	ensurePlayerMovementNormal()
end

-- =================================================================
-- 5. 👻 OTHER PLAYER & PLOT HIDER (GHOST MODE)
-- =================================================================
local function hideOtherPlayerCharacter(char)
	if not char or not char.Parent or isProtectedObject(char) then return end
	local p = Players:GetPlayerFromCharacter(char)
	if p and p == LocalPlayer then return end

	pcall(function()
		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Transparency = 1
				obj.CastShadow = false
			elseif obj:IsA("Decal") or obj:IsA("Texture") then
				obj.Transparency = 1
			elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight") then
				obj.Enabled = false
			elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
				obj.Enabled = false
			end
		end
	end)
end

local function restoreOtherPlayerCharacter(char)
	if not char or not char.Parent then return end
	local p = Players:GetPlayerFromCharacter(char)
	if p and p == LocalPlayer then return end

	pcall(function()
		for _, obj in ipairs(char:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
				obj.Transparency = 0
			elseif obj:IsA("Decal") then
				obj.Transparency = 0
			elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight") then
				obj.Enabled = true
			elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
				obj.Enabled = true
			end
		end
	end)
end

local function hideOtherPlots()
	local myPlot = getMyPlot()
	local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("plots")
	if not plots then return end

	for _, plot in ipairs(plots:GetChildren()) do
		if plot ~= myPlot then
			pcall(function()
				for _, obj in ipairs(plot:GetDescendants()) do
					if obj:IsA("BasePart") then
						obj.Transparency = 1
						obj.CastShadow = false
					elseif obj:IsA("Decal") or obj:IsA("Texture") then
						obj.Transparency = 1
					elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight") then
						obj.Enabled = false
					elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
						obj.Enabled = false
					end
				end
			end)
		end
	end
end

function Graphics.HideOtherPlayers()
	Graphics.HideOtherPlayersEnabled = true
	startGuardian()

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			hideOtherPlayerCharacter(p.Character)
		end
	end

	hideOtherPlots()

	if not playerAddedConn then
		playerAddedConn = Players.PlayerAdded:Connect(function(p)
			p.CharacterAdded:Connect(function(char)
				if Graphics.HideOtherPlayersEnabled and p ~= LocalPlayer then
					task.wait(0.3)
					if char and char.Parent then hideOtherPlayerCharacter(char) end
				end
			end)
		end)
		table.insert(connections, playerAddedConn)
	end

	ensurePlayerMovementNormal()
end

function Graphics.ShowOtherPlayers()
	Graphics.HideOtherPlayersEnabled = false
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			restoreOtherPlayerCharacter(p.Character)
		end
	end
	ensurePlayerMovementNormal()
end

-- =================================================================
-- 6. 💀 DISABLE ALL VFX & PARTICLE SKILLS
-- =================================================================
local function disableVFXObject(v)
	if not v or not v.Parent or isProtectedObject(v) then return end
	pcall(function()
		local cls = v.ClassName
		if cls == "ParticleEmitter" then
			v.Enabled = false
			v.Rate = 0
		elseif cls == "Trail" or cls == "Beam" or cls == "Highlight"
			or cls == "Fire" or cls == "Smoke" or cls == "Sparkles" then
			v.Enabled = false
		elseif cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
			v.Enabled = false
		elseif cls == "Sound" then
			if not v:FindFirstAncestorOfClass("ScreenGui") then
				v.Volume = 0
			end
		end
	end)
end

function Graphics.DisableAllVFX()
	Graphics.DisableVFXEnabled = true
	startGuardian()

	task.spawn(function()
		local count = 0
		for _, v in ipairs(Workspace:GetDescendants()) do
			if not Graphics.DisableVFXEnabled then break end
			disableVFXObject(v)
			count = count + 1
			if count % 400 == 0 then task.wait() end
		end
	end)

	ensurePlayerMovementNormal()
end

function Graphics.RestoreVFX()
	Graphics.DisableVFXEnabled = false
	ensurePlayerMovementNormal()
end

-- =================================================================
-- 7. 🎯 FPS CAP CONTROLLER (MULTI-EXECUTOR VECTORS)
-- =================================================================
local function applyFpsCap(fps)
	fps = tonumber(fps) or 60
	Graphics.TargetFPS = fps

	local success = false

	-- Vector 1: setfpscap
	if typeof(setfpscap) == "function" then
		pcall(function() setfpscap(fps) success = true end)
	end
	-- Vector 2: set_fps_cap
	if not success and typeof(set_fps_cap) == "function" then
		pcall(function() set_fps_cap(fps) success = true end)
	end
	-- Vector 3: setfps
	if not success and typeof(setfps) == "function" then
		pcall(function() setfps(fps) success = true end)
	end
	-- Vector 4: SetFps
	if not success and typeof(SetFps) == "function" then
		pcall(function() SetFps(fps) success = true end)
	end
	-- Vector 5: set_fps
	if not success and typeof(set_fps) == "function" then
		pcall(function() set_fps(fps) success = true end)
	end
	-- Vector 6: settargetfps / SetTargetFPS
	if not success and typeof(settargetfps) == "function" then
		pcall(function() settargetfps(fps) success = true end)
	end
	if not success and typeof(SetTargetFPS) == "function" then
		pcall(function() SetTargetFPS(fps) success = true end)
	end
	-- Vector 7: setfpslimit / SetFPSLimit
	if not success and typeof(setfpslimit) == "function" then
		pcall(function() setfpslimit(fps) success = true end)
	end
	-- Vector 8: MaxFPS Setting
	if not success then
		pcall(function()
			if settings and settings().Rendering and settings().Rendering.MaxFPS ~= nil then
				settings().Rendering.MaxFPS = fps
				success = true
			end
		end)
	end
	-- Vector 9: TargetFrameRate
	if not success then
		pcall(function()
			if settings and settings().Rendering and settings().Rendering.TargetFrameRate ~= nil then
				settings().Rendering.TargetFrameRate = fps
				success = true
			end
		end)
	end

	return success
end

function Graphics.SetFPSCap(fps)
	return applyFpsCap(fps)
end

function Graphics.ApplyFpsCap(fps)
	return applyFpsCap(fps)
end

-- =================================================================
-- 8. 🌑 AMOLED SCREEN OFF / FARM MODE (ENGINE 3D RENDER OFF)
-- =================================================================
local function set3DRendering(enabled)
	pcall(function()
		if typeof(set3drenderingenabled) == "function" then
			set3drenderingenabled(enabled)
		elseif typeof(Set3dRenderingEnabled) == "function" then
			Set3dRenderingEnabled(enabled)
		elseif typeof(set_3d_rendering_enabled) == "function" then
			set_3d_rendering_enabled(enabled)
		elseif RunService:IsStudio() then
			-- Studio fallback
		else
			RunService:Set3dRenderingEnabled(enabled)
		end
	end)
end

local function initScreenOffGui()
	if screenOffGui and screenOffGui.Parent then return end

	local targetParent = nil
	if typeof(gethui) == "function" then
		targetParent = gethui()
	elseif LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
		targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	elseif CoreGui then
		targetParent = CoreGui
	end

	if not targetParent then return end

	local old = targetParent:FindFirstChild("Ritod_ScreenOff_RollAnime")
	if old then old:Destroy() end

	screenOffGui = Instance.new("ScreenGui")
	screenOffGui.Name = "Ritod_ScreenOff_RollAnime"
	screenOffGui.IgnoreGuiInset = true
	screenOffGui.DisplayOrder = 2147483647
	screenOffGui.ResetOnSpawn = false
	screenOffGui.Enabled = false
	pcall(function() screenOffGui.Parent = targetParent end)

	local black = Instance.new("TextButton")
	black.Size = UDim2.new(1, 0, 1, 0)
	black.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	black.BorderSizePixel = 0
	black.Text = ""
	black.AutoButtonColor = false
	black.ZIndex = 999990
	black.Parent = screenOffGui

	local center = Instance.new("Frame")
	center.Size = UDim2.new(0, 420, 0, 180)
	center.Position = UDim2.new(0.5, -210, 0.5, -90)
	center.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
	center.BorderSizePixel = 0
	center.ZIndex = 999991
	center.Parent = black

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 12)
	cCorner.Parent = center

	local cStroke = Instance.new("UIStroke")
	cStroke.Color = Color3.fromRGB(175, 75, 255)
	cStroke.Thickness = 1.6
	cStroke.Parent = center

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 14)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(190, 90, 255)
	title.Text = "🌑 FARM MODE (3D RENDER OFF)"
	title.ZIndex = 999992
	title.Parent = center

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -30, 0, 44)
	desc.Position = UDim2.new(0, 15, 0, 52)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.TextColor3 = Color3.fromRGB(180, 190, 205)
	desc.TextWrapped = true
	desc.Text = "Render 3D dimatikan pada level engine. CPU & GPU usage turun ke ~5-10%.\nScript autofarm & roll kamu tetap berjalan 100% lancar."
	desc.ZIndex = 999992
	desc.Parent = center

	local hint = Instance.new("TextButton")
	hint.Size = UDim2.new(1, -40, 0, 40)
	hint.Position = UDim2.new(0, 20, 0, 116)
	hint.BackgroundColor3 = Color3.fromRGB(150, 65, 240)
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 13
	hint.TextColor3 = Color3.fromRGB(255, 255, 255)
	hint.Text = "👉 KLIK DI SINI UNTUK KEMBALI KE GAME"
	hint.ZIndex = 999993
	hint.Parent = center

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 8)
	hCorner.Parent = hint

	hint.MouseButton1Click:Connect(function()
		Graphics.SetFarmMode(false)
		if syncCallback then pcall(function() syncCallback(false) end) end
	end)
end

function Graphics.SetFarmMode(enable, onSync)
	Graphics.ScreenOffEnabled = enable
	if onSync then syncCallback = onSync end

	initScreenOffGui()
	if screenOffGui then screenOffGui.Enabled = enable end

	set3DRendering(not enable)

	if enable then
		if not farmModeWatchdog then
			farmModeWatchdog = task.spawn(function()
				while Graphics.ScreenOffEnabled do
					set3DRendering(false)
					task.wait(1)
				end
				farmModeWatchdog = nil
			end)
		end
		applyFpsCap(10)
	else
		set3DRendering(true)
		local normalFps = Graphics.AntiLagEnabled and 10 or (Graphics.TargetFPS or 60)
		applyFpsCap(normalFps)
	end
end

-- =================================================================
-- 9. ❄️ ANTI-LAG PRESET (FPS CAP 10 & SHADOWS OFF)
-- =================================================================
function Graphics.SetAntiLag(enable, customFps)
	Graphics.AntiLagEnabled = enable
	if enable then
		applyFpsCap(customFps or 10)
		pcall(function() Lighting.GlobalShadows = false end)
	else
		pcall(function() Lighting.GlobalShadows = not Graphics.PotatoEnabled end)
		local normalFps = Graphics.ScreenOffEnabled and 10 or (Graphics.TargetFPS or 60)
		applyFpsCap(normalFps)
	end
end

-- =================================================================
-- 10. 🧹 AUTOMATIC MEMORY CLEANUP
-- =================================================================
function Graphics.StartAutoMemoryCleanup(interval)
	Graphics.AutoMemoryCleanupEnabled = true
	interval = interval or 45

	if memoryCleanupThread then task.cancel(memoryCleanupThread) end
	memoryCleanupThread = task.spawn(function()
		while Graphics.AutoMemoryCleanupEnabled do
			pcall(function()
				collectgarbage("collect")
				if typeof(gcinfo) == "function" then gcinfo() end
			end)
			task.wait(interval)
		end
		memoryCleanupThread = nil
	end)
end

function Graphics.StopAutoMemoryCleanup()
	Graphics.AutoMemoryCleanupEnabled = false
	if memoryCleanupThread then
		task.cancel(memoryCleanupThread)
		memoryCleanupThread = nil
	end
end

-- Auto-start GC cleaner
Graphics.StartAutoMemoryCleanup(45)

-- =================================================================
-- 11. 🎮 IN-GAME SETTINGS AUTO PRESET ENFORCER
-- =================================================================
Graphics.GameSettingsPreset = {
	Sounds              = false, -- OFF (Screenshot 1)
	Music               = false, -- OFF (Screenshot 1)
	ShowText            = false, -- OFF (Screenshot 1)
	FPSBoost            = true,  -- ON  (Screenshot 2)
	Effects             = false, -- OFF (Screenshot 2)
	AutoAbility         = true,  -- ON  (Screenshot 2)
	OtherPlayerEffects  = true,  -- ON  (Screenshot 2)
	HideOtherCharacters = true,  -- ON  (Screenshot 2 - Hide Other Player Animes)
}

Graphics.AutoGameSettingsEnabled = true
local gameSettingsWatchdogThread = nil

function Graphics.ApplyGameSettingsPreset(customPreset)
	local target = customPreset or Graphics.GameSettingsPreset
	local RS = game:GetService("ReplicatedStorage")
	local settingsRemote = nil
	pcall(function()
		settingsRemote = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Settings")
	end)

	local client = nil
	pcall(function()
		if RS:FindFirstChild("Data") and RS.Data:FindFirstChild("DataService") then
			local ds = require(RS.Data.DataService)
			if ds and ds.client then client = ds.client end
		end
	end)

	local pGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local scroll = nil
	pcall(function()
		scroll = pGui and pGui:FindFirstChild("MainUI")
			and pGui.MainUI:FindFirstChild("Frames")
			and pGui.MainUI.Frames:FindFirstChild("Settings")
			and pGui.MainUI.Frames.Settings:FindFirstChild("Frame")
			and pGui.MainUI.Frames.Settings.Frame:FindFirstChild("Main")
			and pGui.MainUI.Frames.Settings.Frame.Main:FindFirstChild("ScrollingFrame")
	end)

	local anyChanged = false
	for key, desired in pairs(target) do
		local curVal = nil
		if client then
			pcall(function() curVal = client:get({ "Settings", key }) end)
		end

		if curVal == nil and scroll then
			pcall(function()
				local f = scroll:FindFirstChild(key)
				if f and f:FindFirstChild("Button") and f.Button:FindFirstChild("Frame") and f.Button.Frame:FindFirstChild("TextLabel") then
					curVal = (f.Button.Frame.TextLabel.Text == "ON")
				end
			end)
		end

		if curVal ~= desired then
			anyChanged = true
			if settingsRemote and typeof(settingsRemote.FireServer) == "function" then
				pcall(function() settingsRemote:FireServer(key) end)
			end
			if scroll then
				pcall(function()
					local f = scroll:FindFirstChild(key)
					local btn = f and f:FindFirstChild("Button") and f.Button:FindFirstChild("Button")
					if btn then
						if typeof(getconnections) == "function" then
							for _, evName in ipairs({"MouseButton1Click", "Activated"}) do
								pcall(function()
									if btn[evName] then
										for _, conn in ipairs(getconnections(btn[evName])) do
											if conn.Function then conn.Function() elseif conn.Fire then conn:Fire() end
										end
									end
								end)
							end
						end
						if typeof(firesignal) == "function" then
							pcall(function() if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end end)
							pcall(function() if btn.Activated then firesignal(btn.Activated) end end)
						end
					end
				end)
			end
			task.wait(0.08)
		end
	end

	return anyChanged
end

function Graphics.StartGameSettingsWatchdog(interval)
	interval = interval or 10
	Graphics.AutoGameSettingsEnabled = true
	if gameSettingsWatchdogThread then task.cancel(gameSettingsWatchdogThread) end
	gameSettingsWatchdogThread = task.spawn(function()
		while Graphics.AutoGameSettingsEnabled do
			pcall(function()
				Graphics.ApplyGameSettingsPreset()
			end)
			task.wait(interval)
		end
		gameSettingsWatchdogThread = nil
	end)
end

function Graphics.StopGameSettingsWatchdog()
	Graphics.AutoGameSettingsEnabled = false
	if gameSettingsWatchdogThread then
		task.cancel(gameSettingsWatchdogThread)
		gameSettingsWatchdogThread = nil
	end
end

-- =================================================================
-- 12. 🚀 ONE-CLICK ULTRA POTATO PRESET
-- =================================================================
function Graphics.EnableUltraPotato()
	Graphics.EnablePotatoGraphics()
	Graphics.HideOtherPlayers()
	Graphics.FreezeAllNPCsAndAnimations()
	Graphics.DisableAllVFX()
	Graphics.SetAntiLag(true, 60)
	Graphics.ApplyGameSettingsPreset()
end

function Graphics.DisableUltraPotato()
	Graphics.DisablePotatoGraphics()
	Graphics.ShowOtherPlayers()
	Graphics.UnfreezeNPCs()
	Graphics.RestoreVFX()
	Graphics.SetAntiLag(false)
end

-- =================================================================
-- 13. 🔄 BACKWARD COMPATIBILITY WRAPPERS
-- =================================================================
function Graphics.EnablePotato(enable)
	if enable then
		Graphics.EnableUltraPotato()
	else
		Graphics.DisableUltraPotato()
	end
end

function Graphics.SetPotatoGraphics(enable)
	Graphics.EnablePotato(enable)
end

function Graphics.Unload()
	Graphics.SetFarmMode(false)
	Graphics.DisableUltraPotato()
	Graphics.StopAutoMemoryCleanup()
	Graphics.StopGameSettingsWatchdog()

	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	connections = {}

	if screenOffGui then
		pcall(function() screenOffGui:Destroy() end)
		screenOffGui = nil
	end

	applyFpsCap(60)
	set3DRendering(true)
end

return Graphics
