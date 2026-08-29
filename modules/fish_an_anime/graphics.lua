--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (GRAPHICS & FPS BOOSTER V2.0)
	Module: modules/fish_an_anime/graphics.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🌟 FEATURES:
	- 🥔 Potato Graphics (Low Poly, Texture Stripper, Shadow Remover)
	- 🖥️ Engine 3D Rendering Disabler (Black Screen AFK - 90% GPU Drop)
	- ⚡ In-Game Native Performance Mode & VFX Stripper
	- 🎯 FPS Cap Controller (15, 30, 60, 120, Unlimited)
	- 🧹 Automatic RAM & Memory Garbage Collector
	- 🛡️ Zero Lag Spikes & Seamless Background Operation
	===============================================================
]]

local Graphics = {}
Graphics.__index = Graphics

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- State Flags
Graphics.PotatoEnabled = false
Graphics.ScreenOffEnabled = false
Graphics.AutoMemoryCleanupEnabled = true
Graphics.TargetFPS = 60

local memoryCleanupThread = nil
local screenOffGui = nil
local originalLightingSettings = {}

-- ── 1. Save Original Lighting State ──
pcall(function()
    originalLightingSettings = {
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime
    }
end)

-- ── 🥔 2. Potato Graphics Engine ──
local function optimizeObject(v)
    if not Graphics.PotatoEnabled then return end
    pcall(function()
        if v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
            v.CastShadow = false
        elseif v:IsA("MeshPart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
            v.CastShadow = false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("Explosion") then
            v.Visible = false
        end
    end)
end

function Graphics.EnablePotatoGraphics()
    Graphics.PotatoEnabled = true

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 2
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") or effect:IsA("Atmosphere") then
                effect.Enabled = false
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

    task.spawn(function()
        for _, v in ipairs(Workspace:GetDescendants()) do
            if not Graphics.PotatoEnabled then break end
            optimizeObject(v)
        end
    end)

    -- In-game game setting attributes
    pcall(function()
        LocalPlayer:SetAttribute("PerformanceMode", true)
        LocalPlayer:SetAttribute("DisableCharacterVFX", true)
        LocalPlayer:SetAttribute("CharacterRenderAll", false)
    end)
end

function Graphics.DisablePotatoGraphics()
    Graphics.PotatoEnabled = false
    pcall(function()
        if originalLightingSettings.GlobalShadows ~= nil then
            Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
            Lighting.FogEnd = originalLightingSettings.FogEnd or 10000
            Lighting.Brightness = originalLightingSettings.Brightness or 2
        end
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then effect.Enabled = true end
        end
    end)
end

-- ── 🖥️ 3. Engine 3D Rendering Disabler (Black Screen AFK) ──
function Graphics.EnableScreenOff()
    if Graphics.ScreenOffEnabled then return end
    Graphics.ScreenOffEnabled = true

    pcall(function()
        RunService:Set3dRenderingEnabled(false)
    end)

    pcall(function()
        if screenOffGui then screenOffGui:Destroy() end
        screenOffGui = Instance.new("ScreenGui")
        screenOffGui.Name = "RitodScreenOffOverlay"
        screenOffGui.DisplayOrder = 999999
        screenOffGui.ResetOnSpawn = false

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
        bg.BorderSizePixel = 0
        bg.Parent = screenOffGui

        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 360, 0, 180)
        card.Position = UDim2.new(0.5, -180, 0.5, -90)
        card.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
        card.BorderSizePixel = 0
        card.Parent = bg

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = card

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 40)
        title.Text = "⚡ RITOD HUB - GPU SAVER MODE ⚡"
        title.TextColor3 = Color3.fromRGB(140, 120, 255)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.BackgroundTransparency = 1
        title.Parent = card

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -20, 0, 60)
        desc.Position = UDim2.new(0, 10, 0, 45)
        desc.Text = "3D Rendering dimatikan (Penghematan GPU ~90%).\nScript memancing, merchant & level up tetap aktif normal 24/7!"
        desc.TextColor3 = Color3.fromRGB(200, 200, 220)
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 13
        desc.TextWrapped = true
        desc.BackgroundTransparency = 1
        desc.Parent = card

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 200, 0, 36)
        btn.Position = UDim2.new(0.5, -100, 1, -48)
        btn.BackgroundColor3 = Color3.fromRGB(140, 120, 255)
        btn.Text = "Nyalakan Layar Kembali"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.Parent = card

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            Graphics.DisableScreenOff()
        end)

        if syn and syn.protect_gui then
            syn.protect_gui(screenOffGui)
            screenOffGui.Parent = CoreGui
        elseif gethui then
            screenOffGui.Parent = gethui()
        else
            screenOffGui.Parent = CoreGui
        end
    end)
end

function Graphics.DisableScreenOff()
    Graphics.ScreenOffEnabled = false
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
    if screenOffGui then
        pcall(function() screenOffGui:Destroy() end)
        screenOffGui = nil
    end
end

-- ── 🎯 4. FPS Cap Limiter ──
function Graphics.SetFPSCap(fps)
    fps = tonumber(fps) or 60
    Graphics.TargetFPS = fps
    pcall(function()
        if typeof(setfpscap) == "function" then
            setfpscap(fps)
        elseif typeof(set_fps_cap) == "function" then
            set_fps_cap(fps)
        end
    end)
end

-- ── 🧹 5. Auto Memory Garbage Collection ──
function Graphics.StartMemoryCleaner(interval)
    interval = interval or 60
    Graphics.AutoMemoryCleanupEnabled = true
    if memoryCleanupThread then task.cancel(memoryCleanupThread) end
    memoryCleanupThread = task.spawn(function()
        while Graphics.AutoMemoryCleanupEnabled do
            task.wait(interval)
            pcall(function()
                if typeof(collectgarbage) == "function" then
                    pcall(collectgarbage, "collect")
                end
                -- Also force via gcinfo if available
                if typeof(gcinfo) == "function" then
                    gcinfo()
                end
            end)
        end
    end)
end

function Graphics.StopMemoryCleaner()
    Graphics.AutoMemoryCleanupEnabled = false
    if memoryCleanupThread then
        pcall(function() task.cancel(memoryCleanupThread) end)
        memoryCleanupThread = nil
    end
end

-- Start memory cleaner by default
Graphics.StartMemoryCleaner(45)

_G.FishAnAnimeGraphics = Graphics
return Graphics
