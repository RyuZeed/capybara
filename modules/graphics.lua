local GraphicsModule = {}

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local SETTINGS = {
    AFK_FPS_Cap         = 5,
    Normal_FPS_Cap      = 60,
    StopAllAudioThreads = true,
    ChunkSize           = 300,
}

local States = {
    PotatoGraphics = false,
    FarmMode       = false,
    AntiLag        = false,
}

local potatoConnection = nil
local screenOffGui = nil
local blackBtn = nil

local function isLocalCharacterItem(obj)
    local model = obj:FindFirstAncestorOfClass("Model")
    if not model then return false end
    return Players:GetPlayerFromCharacter(model) == LocalPlayer
end

local function purgeObject(v)
    if not States.PotatoGraphics or not v or not v.Parent then return end
    pcall(function()
        if SETTINGS.StopAllAudioThreads and v:IsA("Sound") then
            if not isLocalCharacterItem(v) then
                v:Stop()
                v.Volume = 0
                v.Playing = false
            end
            return
        end

        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")
            or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
            or v:IsA("Highlight") then
            if not isLocalCharacterItem(v) then v:Destroy() end
            return
        end

        if v:IsA("Decal") or v:IsA("Texture") or v:IsA("SurfaceAppearance") or v:IsA("ShirtGraphic") then
            v:Destroy()
            return
        end

        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("WrapLayer") then
            if not isLocalCharacterItem(v) then v:Destroy() end
            return
        end

        if v:IsA("BasePart") then
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
        end
    end)
end

local function processChunked(list)
    local i = 0
    local n = #list
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
                return
            end
            purgeObject(list[i])
        end
    end)
end

function GraphicsModule.EnablePotato(enable)
    States.PotatoGraphics = enable
    if enable then
        processChunked(Workspace:GetDescendants())
        processChunked(Lighting:GetDescendants())

        pcall(function()
            Lighting.Technology = Enum.Technology.Compatibility
            Lighting.GlobalShadows = false
            Lighting.Outlines = false
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0

            for _, child in ipairs(Lighting:GetChildren()) do
                if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") then
                    child:Destroy()
                end
            end
        end)

        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            pcall(function()
                terrain.WaterWaveSize     = 0
                terrain.WaterWaveSpeed    = 0
                terrain.WaterReflectance  = 0
                terrain.WaterTransparency = 0
                terrain.Decoration        = false
            end)
        end

        if not potatoConnection then
            potatoConnection = Workspace.DescendantAdded:Connect(function(v)
                if States.PotatoGraphics then task.defer(function() purgeObject(v) end) end
            end)
        end
        print("🥔 [Ritod Hub] Potato Graphics Enabled!")
    else
        if potatoConnection then
            potatoConnection:Disconnect()
            potatoConnection = nil
        end
        print("🛑 [Ritod Hub] Potato Graphics Disabled.")
    end
end

local function initScreenOffGui()
    if screenOffGui then return end
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10) or LocalPlayer.PlayerGui

    screenOffGui = Instance.new("ScreenGui")
    screenOffGui.Name = "AFKScreenOff"
    screenOffGui.IgnoreGuiInset = true
    screenOffGui.DisplayOrder = 999999
    screenOffGui.ResetOnSpawn = false
    screenOffGui.Enabled = false

    blackBtn = Instance.new("TextButton")
    blackBtn.Size = UDim2.new(1, 0, 1, 0)
    blackBtn.BackgroundColor3 = Color3.new(0, 0, 0)
    blackBtn.BorderSizePixel = 0
    blackBtn.Text = "🚜 FARM MODE AKTIF (LAYAR DIREDUPKAN)\n\n👉 Sentuh / Klik Layar Ini Untuk Matikan Farm Mode"
    blackBtn.TextColor3 = Color3.fromRGB(0, 230, 138)
    blackBtn.Font = Enum.Font.GothamBold
    blackBtn.TextSize = 14
    blackBtn.ZIndex = 999999
    blackBtn.Parent = screenOffGui
    screenOffGui.Parent = playerGui

    blackBtn.MouseButton1Click:Connect(function()
        GraphicsModule.SetFarmMode(false)
    end)
end

function GraphicsModule.SetFarmMode(enable)
    States.FarmMode = enable
    initScreenOffGui()
    if screenOffGui then screenOffGui.Enabled = enable end

    if typeof(setfpscap) == "function" then
        pcall(function()
            setfpscap(enable and SETTINGS.AFK_FPS_Cap or (States.AntiLag and SETTINGS.AFK_FPS_Cap or SETTINGS.Normal_FPS_Cap))
        end)
    end
    print("🚜 [Ritod Hub] Farm Mode: " .. (enable and "ON" or "OFF"))
end

function GraphicsModule.SetAntiLag(enable)
    States.AntiLag = enable
    if typeof(setfpscap) == "function" then
        pcall(function()
            setfpscap((enable or States.FarmMode) and SETTINGS.AFK_FPS_Cap or SETTINGS.Normal_FPS_Cap)
        end)
    end
    pcall(function() Lighting.GlobalShadows = not enable end)
    print("❄️ [Ritod Hub] Anti-Lag (FPS Cap 5): " .. (enable and "ON" or "OFF"))
end

return GraphicsModule
