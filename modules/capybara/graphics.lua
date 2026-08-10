-- =================================================================
-- 🚀 RITOD HUB | ULTIMATE HYBRID CPU REDUCER & POTATO GRAPHICS (V4.2)
-- Independent Modular Control: Potato Graphics vs Anti-Lag (FPS Cap) vs Farm Mode
-- Supports getgenv().RitodConfig / getgenv().UserConfig Auto-Execute Setup
-- =================================================================

local GraphicsModule = {}

local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer       = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

-- Ambil UserConfig dari getgenv() jika tersedia
local userConfig = (getgenv and (getgenv().RitodConfig or getgenv().UserConfig)) or {}

-- =================================================================
-- ⚙️ CONFIGURATION SETTINGS
-- =================================================================
local SETTINGS = {
    TargetFPS              = userConfig["FPS Cap"] or 60,
    AFK_FPS_Cap            = 5,
    Normal_FPS_Cap         = 60,
    ChunkSize              = 350,
    AutoGCInterval         = 60,
    AutoThrottleBackground = true,
}

local States = {
    PotatoGraphics   = false,
    FarmMode         = false,  -- 3D Rendering Off + Black Screen
    AntiLag          = false,  -- FPS Capped to 5 & Shadows Off
    Is3DDisabled     = false,
    CurrentFPSCap    = SETTINGS.TargetFPS,
}

local Connections = {}
local potatoConnection = nil
local screenOffGui = nil
local syncCallback = nil
local gcThread = nil

-- =================================================================
-- 1. 🎯 FPS CONTROLLER (INDEPENDENT)
-- =================================================================
local function applyFpsCap(fps)
    States.CurrentFPSCap = fps
    if typeof(setfpscap) == "function" then
        pcall(setfpscap, fps)
    elseif typeof(set_fps_cap) == "function" then
        pcall(set_fps_cap, fps)
    elseif typeof(setfps) == "function" then
        pcall(setfps, fps)
    end
end

function GraphicsModule.ApplyFpsCap(fps)
    applyFpsCap(fps or (States.FarmMode and SETTINGS.AFK_FPS_Cap or (States.AntiLag and SETTINGS.AFK_FPS_Cap or SETTINGS.Normal_FPS_Cap)))
end

-- =================================================================
-- 2. 🌑 ENGINE LEVEL 3D RENDERING CONTROLLER (FARM MODE)
-- =================================================================
local function set3DRendering(enabled)
    States.Is3DDisabled = not enabled
    pcall(function()
        RunService:Set3dRenderingEnabled(enabled)
    end)
end

-- =================================================================
-- 3. 🛡️ LOCAL CHARACTER SAFETY & OBJECT PURGE
-- =================================================================
local function isLocalCharacterItem(obj)
    if not obj then return false end
    local model = obj:FindFirstAncestorOfClass("Model")
    if not model then return false end
    return Players:GetPlayerFromCharacter(model) == LocalPlayer
end

local function cleanObject(v)
    if not States.PotatoGraphics or not v or not v.Parent then return end
    if isLocalCharacterItem(v) then return end

    pcall(function()
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Fire") 
           or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Highlight") or v:IsA("Explosion") then
            v.Enabled = false
        elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("SurfaceAppearance") or v:IsA("ShirtGraphic") then
            v:Destroy()
        elseif v:IsA("BasePart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
            v.CastShadow = false
            if v:IsA("MeshPart") then
                v.TextureID = ""
                v.RenderFidelity = Enum.RenderFidelity.Performance
                v.CollisionFidelity = Enum.CollisionFidelity.Box
            end
        elseif v:IsA("SpecialMesh") then
            v.TextureId = ""
        elseif v:IsA("Light") then
            v.Shadows = false
        elseif v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("Clouds") then
            v:Destroy()
        elseif v:IsA("PostEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("BloomEffect") 
           or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
            v.Enabled = false
        end
    end)
end

-- =================================================================
-- 4. ⚡ CHUNKED BATCH CLEANER (ZERO-FREEZE POTATO)
-- =================================================================
local function runSmoothBatchClean()
    task.spawn(function()
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Always
            Lighting.GlobalShadows = false
            Lighting.Outlines = false
            Lighting.FogEnd = 9e9
            Lighting.Technology = Enum.Technology.Compatibility
        end)

        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            pcall(function()
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0
                terrain.Decoration = false
            end)
        end

        local descendants = Workspace:GetDescendants()
        local n = #descendants
        local i = 0

        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not States.PotatoGraphics then
                conn:Disconnect()
                return
            end
            for _ = 1, SETTINGS.ChunkSize do
                i += 1
                if i > n then
                    conn:Disconnect()
                    break
                end
                cleanObject(descendants[i])
            end
        end)
    end)
end

-- =================================================================
-- 5. 🥔 POTATO GRAPHICS CONTROLLER (TERPISAH DARI ANTI-LAG)
-- =================================================================
function GraphicsModule.EnablePotato(enable)
    States.PotatoGraphics = enable
    if enable then
        runSmoothBatchClean()

        if not potatoConnection then
            potatoConnection = Workspace.DescendantAdded:Connect(function(v)
                if States.PotatoGraphics then
                    task.defer(function() cleanObject(v) end)
                end
            end)
        end
        print("🥔 [Ritod Hub] Low / Potato Graphics: ON")
    else
        if potatoConnection then
            potatoConnection:Disconnect()
            potatoConnection = nil
        end
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Default
            Lighting.GlobalShadows = true
        end)
        print("🛑 [Ritod Hub] Low / Potato Graphics: OFF")
    end
end

-- =================================================================
-- 6. ❄️ ANTI-LAG CONTROLLER (FPS CAP 5 & SHADOWS OFF)
-- =================================================================
function GraphicsModule.SetAntiLag(enable, customFps)
    States.AntiLag = enable
    local targetFps = enable and (customFps or SETTINGS.AFK_FPS_Cap) or SETTINGS.Normal_FPS_Cap
    applyFpsCap(targetFps)
    pcall(function() Lighting.GlobalShadows = not enable end)
    print("❄️ [Ritod Hub] Anti-Lag (FPS Cap " .. tostring(targetFps) .. "): " .. (enable and "ON" or "OFF"))
end

-- =================================================================
-- 7. 🚜 FARM MODE (PURE 3D RENDER OFF)
-- =================================================================
local function initScreenOffGui()
    if screenOffGui then return end
    
    local targetParent = nil
    if typeof(gethui) == "function" then
        targetParent = gethui()
    elseif LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
        targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    elseif CoreGui then
        targetParent = CoreGui
    end

    if not targetParent then return end

    if targetParent:FindFirstChild("Ritod_AFKScreenOff") then
        targetParent.Ritod_AFKScreenOff:Destroy()
    end

    screenOffGui = Instance.new("ScreenGui")
    screenOffGui.Name = "Ritod_AFKScreenOff"
    screenOffGui.IgnoreGuiInset = true
    screenOffGui.DisplayOrder = 2147483647
    screenOffGui.ResetOnSpawn = false
    screenOffGui.Enabled = false
    pcall(function() screenOffGui.Parent = targetParent end)

    local blackFrame = Instance.new("TextButton")
    blackFrame.Size = UDim2.new(1, 0, 1, 0)
    blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    blackFrame.BorderSizePixel = 0
    blackFrame.Text = ""
    blackFrame.AutoButtonColor = false
    blackFrame.ZIndex = 999990
    blackFrame.Parent = screenOffGui

    local centerBox = Instance.new("Frame")
    centerBox.Size = UDim2.new(0, 440, 0, 170)
    centerBox.Position = UDim2.new(0.5, -220, 0.5, -85)
    centerBox.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
    centerBox.BorderSizePixel = 0
    centerBox.ZIndex = 999991
    centerBox.Parent = blackFrame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 12)
    boxCorner.Parent = centerBox

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(0, 255, 170)
    boxStroke.Thickness = 1.6
    boxStroke.Parent = centerBox

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 36)
    titleLbl.Position = UDim2.new(0, 0, 0, 15)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 19
    titleLbl.TextColor3 = Color3.fromRGB(0, 255, 170)
    titleLbl.Text = "🌑 FARM MODE (3D RENDER OFF)"
    titleLbl.ZIndex = 999992
    titleLbl.Parent = centerBox

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -30, 0, 42)
    subLbl.Position = UDim2.new(0, 15, 0, 52)
    subLbl.BackgroundTransparency = 1
    subLbl.Font = Enum.Font.Gotham
    subLbl.TextSize = 12
    subLbl.TextColor3 = Color3.fromRGB(180, 190, 205)
    subLbl.TextWrapped = true
    subLbl.Text = "Render 3D dimatikan pada level engine. CPU & GPU usage turun ke ~10%.\nScript autofarm & roll kamu tetap berjalan 100% lancar."
    subLbl.ZIndex = 999992
    subLbl.Parent = centerBox

    local hintBtn = Instance.new("TextButton")
    hintBtn.Size = UDim2.new(1, -40, 0, 38)
    hintBtn.Position = UDim2.new(0, 20, 0, 110)
    hintBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    hintBtn.Font = Enum.Font.GothamBold
    hintBtn.TextSize = 13
    hintBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hintBtn.Text = "👉 KLIK DI SINI UNTUK KEMBALI KE GAME"
    hintBtn.ZIndex = 999993
    hintBtn.Parent = centerBox

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = hintBtn

    local function disableFarmMode()
        GraphicsModule.SetFarmMode(false)
        if syncCallback then pcall(function() syncCallback(false) end) end
    end

    hintBtn.MouseButton1Click:Connect(disableFarmMode)
    blackFrame.MouseButton1Click:Connect(disableFarmMode)
end

function GraphicsModule.SetFarmMode(enable, onSync)
    States.FarmMode = enable
    if onSync then syncCallback = onSync end

    initScreenOffGui()
    if screenOffGui then screenOffGui.Enabled = enable end

    set3DRendering(not enable)

    local targetFps = enable and SETTINGS.AFK_FPS_Cap or (States.AntiLag and SETTINGS.AFK_FPS_Cap or States.CurrentFPSCap)
    applyFpsCap(targetFps)

    print("🚜 [Ritod Hub] Farm Mode (3D Render Off): " .. (enable and "ON" or "OFF"))
end

-- =================================================================
-- 8. 🪟 WINDOW FOCUS AUTO-THROTTLE
-- =================================================================
if SETTINGS.AutoThrottleBackground then
    local blurConn = UserInputService.WindowFocusReleased:Connect(function()
        applyFpsCap(SETTINGS.AFK_FPS_Cap)
    end)
    table.insert(Connections, blurConn)

    local focusConn = UserInputService.WindowFocused:Connect(function()
        local currentTarget = (States.FarmMode or States.AntiLag) and SETTINGS.AFK_FPS_Cap or States.CurrentFPSCap
        applyFpsCap(currentTarget)
    end)
    table.insert(Connections, focusConn)
end

-- =================================================================
-- 9. ♻️ PERIODIC RAM GARBAGE COLLECTOR
-- =================================================================
if not gcThread then
    gcThread = task.spawn(function()
        while true do
            task.wait(SETTINGS.AutoGCInterval)
            pcall(function()
                collectgarbage("collect")
            end)
        end
    end)
end

function GraphicsModule.SetPotatoGraphics(enable)
    GraphicsModule.EnablePotato(enable)
end

return GraphicsModule
