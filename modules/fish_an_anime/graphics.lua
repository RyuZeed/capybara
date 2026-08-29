--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (ULTRA GRAPHICS OPTIMIZER V3.0)
	Module: modules/fish_an_anime/graphics.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🌟 FEATURES:
	- 🥔 Potato Graphics (Material, Shadow, VFX, Texture Stripper)
	- 👻 Other Player Hider (Invisible + Animation Freeze)
	- 🤖 NPC Animation Freezer (CPU Saver Terbesar)
	- 💀 Particle/Trail/Beam/Sound Muter (VFX Kill)
	- 🖥️ Engine 3D Rendering Disabler (Black Screen AFK)
	- 🎯 FPS Cap Controller (Multi-Executor Support)
	- 🧹 Periodic RAM Garbage Collector
	- 🔄 Realtime DescendantAdded Hook (Auto-Strip New Objects)
	===============================================================
]]

local Graphics = {}
Graphics.__index = Graphics

-- 🔇 SILENT MODE
local _print = print
local print = function() end
local warn = function() end

-- Services
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ═════════════════════════════════════════════════════════════════
-- ⚙️ STATE & CONFIGURATION
-- ═════════════════════════════════════════════════════════════════
Graphics.PotatoEnabled = false
Graphics.ScreenOffEnabled = false
Graphics.AutoMemoryCleanupEnabled = false
Graphics.HideOtherPlayersEnabled = false
Graphics.FreezeNPCsEnabled = false
Graphics.DisableVFXEnabled = false
Graphics.TargetFPS = 60

local memoryCleanupThread = nil
local screenOffGui = nil
local potatoSweeperThread = nil
local descendantConn = nil
local playerAddedConn = nil
local originalLightingSettings = {}
local connections = {}

local PROCESSED_TAG = "_ritod_cleaned_v3"
local FROZEN_TAG = "_ritod_frozen_v3"

-- ═════════════════════════════════════════════════════════════════
-- 1. 🛡️ PROTECTED OBJECT GUARD
-- ═════════════════════════════════════════════════════════════════
local function isProtectedObject(obj)
    if not obj or not obj.Parent then return true end

    -- LocalPlayer Character
    local char = LocalPlayer.Character
    if char and (obj == char or obj:IsDescendantOf(char)) then
        return true
    end

    -- Backpack
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp and (obj == bp or obj:IsDescendantOf(bp)) then
        return true
    end

    -- Camera
    local cam = Workspace.CurrentCamera
    if cam and (obj == cam or obj:IsDescendantOf(cam)) then
        return true
    end

    -- Tool / Accoutrement
    if obj:IsA("Tool") or obj:FindFirstAncestorOfClass("Tool")
       or obj:IsA("Accoutrement") or obj:FindFirstAncestorOfClass("Accoutrement") then
        return true
    end

    -- ProximityPrompt (Game interaction)
    if obj:IsA("ProximityPrompt") or obj:FindFirstChildOfClass("ProximityPrompt") then
        return true
    end

    return false
end

-- ═════════════════════════════════════════════════════════════════
-- 2. 🥔 POTATO GRAPHICS ENGINE (Material + Shadow + VFX Strip)
-- ═════════════════════════════════════════════════════════════════
pcall(function()
    originalLightingSettings = {
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime
    }
end)

local function stripObject(v)
    if not v or not v.Parent then return end
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
        elseif cls == "Explosion" then
            v.Visible = false
        elseif cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
            v.Enabled = false
        end
    end)
end

function Graphics.EnablePotatoGraphics()
    Graphics.PotatoEnabled = true

    -- Lighting overrides
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

    -- Strip all existing objects in workspace (batched to avoid spike)
    task.spawn(function()
        local count = 0
        for _, v in ipairs(Workspace:GetDescendants()) do
            if not Graphics.PotatoEnabled then break end
            if not isProtectedObject(v) then
                stripObject(v)
            end
            count = count + 1
            if count % 300 == 0 then task.wait() end -- yield every 300 to avoid freeze
        end
    end)

    -- In-game performance attributes
    pcall(function()
        LocalPlayer:SetAttribute("PerformanceMode", true)
        LocalPlayer:SetAttribute("DisableCharacterVFX", true)
        LocalPlayer:SetAttribute("CharacterRenderAll", false)
    end)
end

function Graphics.DisablePotatoGraphics()
    Graphics.PotatoEnabled = false
    pcall(function()
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
        if originalLightingSettings.GlobalShadows ~= nil then
            Lighting.GlobalShadows = originalLightingSettings.GlobalShadows
            Lighting.FogEnd = originalLightingSettings.FogEnd or 10000
            Lighting.Brightness = originalLightingSettings.Brightness or 2
        end
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then pcall(function() effect.Enabled = true end) end
        end
    end)
end

-- ═════════════════════════════════════════════════════════════════
-- 3. 🤖 NPC & ANIMATION FREEZER (Biggest CPU Saver)
-- ═════════════════════════════════════════════════════════════════
local function freezeAnimator(animator)
    if not animator or not animator.Parent then return end
    if isProtectedObject(animator) then return end
    pcall(function()
        -- Stop all currently playing animation tracks
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function()
                track:Stop(0)
                track:AdjustSpeed(0)
            end)
        end
        -- Hook future animations to auto-stop them
        if not animator:GetAttribute(FROZEN_TAG) then
            animator:SetAttribute(FROZEN_TAG, true)
            animator.AnimationPlayed:Connect(function(track)
                if Graphics.FreezeNPCsEnabled or Graphics.PotatoEnabled then
                    if not isProtectedObject(animator) then
                        pcall(function()
                            track:Stop(0)
                            track:AdjustSpeed(0)
                        end)
                    end
                end
            end)
        end
    end)
end

local function freezeHumanoid(humanoid)
    if not humanoid or not humanoid.Parent then return end
    if isProtectedObject(humanoid) then return end
    pcall(function()
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.AutoRotate = false
        humanoid.PlatformStand = true
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    end)
end

local function freezeCharacterModel(model)
    if not model or not model.Parent or isProtectedObject(model) then return end

    -- Freeze humanoids & animators
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("Humanoid") then
            freezeHumanoid(child)
        elseif child:IsA("Animator") or child:IsA("AnimationController") then
            freezeAnimator(child)
        end
    end

    -- Hide parts & disable VFX
    for _, obj in ipairs(model:GetDescendants()) do
        pcall(function()
            if obj:IsA("BasePart") then
                obj.Transparency = 1
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
                obj.CastShadow = false
                obj.Anchored = true
                obj.AssemblyLinearVelocity = Vector3.zero
                obj.AssemblyAngularVelocity = Vector3.zero
            elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                obj.Enabled = false
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
                or obj:IsA("Highlight") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("Sound") then
                obj.Volume = 0
                obj.Playing = false
            end
        end)
    end
end

function Graphics.FreezeAllNPCsAndAnimations()
    Graphics.FreezeNPCsEnabled = true
    task.spawn(function()
        local count = 0
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if not Graphics.FreezeNPCsEnabled then break end
            if not isProtectedObject(desc) then
                if desc:IsA("Animator") or desc:IsA("AnimationController") then
                    freezeAnimator(desc)
                elseif desc:IsA("Humanoid") then
                    freezeHumanoid(desc)
                end
            end
            count = count + 1
            if count % 500 == 0 then task.wait() end
        end
    end)
end

function Graphics.UnfreezeNPCs()
    Graphics.FreezeNPCsEnabled = false
end

-- ═════════════════════════════════════════════════════════════════
-- 4. 👻 OTHER PLAYER HIDER (Character + Animations + VFX)
-- ═════════════════════════════════════════════════════════════════
local function hidePlayer(player)
    if player == LocalPlayer then return end
    if player.Character and not isProtectedObject(player.Character) then
        freezeCharacterModel(player.Character)
    end
end

function Graphics.HideOtherPlayers()
    Graphics.HideOtherPlayersEnabled = true

    -- Hide all current players
    for _, p in ipairs(Players:GetPlayers()) do
        hidePlayer(p)
    end

    -- Auto-hide new players & respawns
    if not playerAddedConn then
        playerAddedConn = Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function(char)
                if Graphics.HideOtherPlayersEnabled and p ~= LocalPlayer then
                    task.wait(0.3)
                    if char and char.Parent then
                        freezeCharacterModel(char)
                    end
                end
            end)
        end)
        table.insert(connections, playerAddedConn)

        -- Also hook existing players' CharacterAdded
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                p.CharacterAdded:Connect(function(char)
                    if Graphics.HideOtherPlayersEnabled then
                        task.wait(0.3)
                        if char and char.Parent then
                            freezeCharacterModel(char)
                        end
                    end
                end)
            end
        end
    end
end

function Graphics.ShowOtherPlayers()
    Graphics.HideOtherPlayersEnabled = false
end

-- ═════════════════════════════════════════════════════════════════
-- 5. 💀 DISABLE ALL VFX (Particles, Trails, Sounds, Lights)
-- ═════════════════════════════════════════════════════════════════
local function disableVFXObject(v)
    if not v or not v.Parent then return end
    if isProtectedObject(v) then return end
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
            -- Only kill 3D positioned sounds, keep UI sounds
            if v:FindFirstAncestorOfClass("ScreenGui") then return end
            v.Volume = 0
        end
    end)
end

function Graphics.DisableAllVFX()
    Graphics.DisableVFXEnabled = true
    task.spawn(function()
        local count = 0
        for _, v in ipairs(Workspace:GetDescendants()) do
            if not Graphics.DisableVFXEnabled then break end
            disableVFXObject(v)
            count = count + 1
            if count % 400 == 0 then task.wait() end
        end

        -- Also clean Effects/VFX folders
        for _, folderName in ipairs({"Effects", "VFX", "Debris", "Skills", "Projectiles", "Spells", "SkillEffects"}) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                for _, desc in ipairs(folder:GetDescendants()) do
                    disableVFXObject(desc)
                end
            end
        end
    end)
end

function Graphics.EnableAllVFX()
    Graphics.DisableVFXEnabled = false
end

-- ═════════════════════════════════════════════════════════════════
-- 6. 🔄 REALTIME DESCENDANT HOOK (Auto-strip new spawned objects)
-- ═════════════════════════════════════════════════════════════════
local function startDescendantHook()
    if descendantConn then return end
    descendantConn = Workspace.DescendantAdded:Connect(function(v)
        if isProtectedObject(v) then return end

        local cls = v.ClassName

        -- Auto-strip VFX
        if Graphics.PotatoEnabled or Graphics.DisableVFXEnabled then
            if cls == "ParticleEmitter" then
                pcall(function() v.Enabled = false v.Rate = 0 end)
            elseif cls == "Trail" or cls == "Beam" or cls == "Highlight"
                or cls == "Fire" or cls == "Smoke" or cls == "Sparkles" then
                pcall(function() v.Enabled = false end)
            elseif cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
                pcall(function() v.Enabled = false end)
            end
        end

        -- Auto-strip materials
        if Graphics.PotatoEnabled then
            if v:IsA("BasePart") then
                pcall(function()
                    v.Material = Enum.Material.SmoothPlastic
                    v.CastShadow = false
                    v.Reflectance = 0
                end)
            elseif cls == "Decal" or cls == "Texture" then
                pcall(function() v.Transparency = 1 end)
            end
        end

        -- Auto-freeze new animations
        if Graphics.FreezeNPCsEnabled then
            if v:IsA("Animator") or v:IsA("AnimationController") then
                task.defer(function() freezeAnimator(v) end)
            elseif v:IsA("Humanoid") then
                task.defer(function() freezeHumanoid(v) end)
            end
        end
    end)
    table.insert(connections, descendantConn)
end

local function stopDescendantHook()
    if descendantConn then
        pcall(function() descendantConn:Disconnect() end)
        descendantConn = nil
    end
end

-- ═════════════════════════════════════════════════════════════════
-- 7. 🖥️ ENGINE 3D RENDERING DISABLER (Black Screen AFK)
-- ═════════════════════════════════════════════════════════════════
function Graphics.EnableScreenOff()
    if Graphics.ScreenOffEnabled then return end
    Graphics.ScreenOffEnabled = true

    pcall(function() RunService:Set3dRenderingEnabled(false) end)

    pcall(function()
        if screenOffGui then screenOffGui:Destroy() end
        screenOffGui = Instance.new("ScreenGui")
        screenOffGui.Name = "RitodScreenOffOverlay"
        screenOffGui.DisplayOrder = 2147483647
        screenOffGui.ResetOnSpawn = false
        screenOffGui.IgnoreGuiInset = true

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
        bg.BorderSizePixel = 0
        bg.Parent = screenOffGui

        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 400, 0, 170)
        card.Position = UDim2.new(0.5, -200, 0.5, -85)
        card.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
        card.BorderSizePixel = 0
        card.Parent = bg

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = card

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(100, 80, 220)
        stroke.Thickness = 1.5
        stroke.Parent = card

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 36)
        title.Position = UDim2.new(0, 0, 0, 12)
        title.Text = "⚡ RITOD HUB - GPU SAVER MODE ⚡"
        title.TextColor3 = Color3.fromRGB(140, 120, 255)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 17
        title.BackgroundTransparency = 1
        title.Parent = card

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -20, 0, 50)
        desc.Position = UDim2.new(0, 10, 0, 48)
        desc.Text = "3D Rendering dimatikan (GPU ~90% hemat).\nScript memancing, merchant & level up tetap aktif 24/7!"
        desc.TextColor3 = Color3.fromRGB(180, 180, 200)
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 13
        desc.TextWrapped = true
        desc.BackgroundTransparency = 1
        desc.Parent = card

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 240, 0, 36)
        btn.Position = UDim2.new(0.5, -120, 1, -48)
        btn.BackgroundColor3 = Color3.fromRGB(100, 80, 220)
        btn.Text = "👉 Nyalakan Layar Kembali"
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
        elseif typeof(gethui) == "function" then
            screenOffGui.Parent = gethui()
        else
            screenOffGui.Parent = CoreGui
        end
    end)
end

function Graphics.DisableScreenOff()
    Graphics.ScreenOffEnabled = false
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    if screenOffGui then
        pcall(function() screenOffGui:Destroy() end)
        screenOffGui = nil
    end
end

-- ═════════════════════════════════════════════════════════════════
-- 8. 🎯 FPS CAP CONTROLLER (Multi-Executor Support)
-- ═════════════════════════════════════════════════════════════════
function Graphics.SetFPSCap(fps)
    fps = tonumber(fps) or 60
    Graphics.TargetFPS = fps
    pcall(function()
        if typeof(setfpscap) == "function" then
            setfpscap(fps)
        elseif typeof(set_fps_cap) == "function" then
            set_fps_cap(fps)
        elseif typeof(setfps) == "function" then
            setfps(fps)
        elseif typeof(set_fps) == "function" then
            set_fps(fps)
        elseif typeof(SetFpsCap) == "function" then
            SetFpsCap(fps)
        elseif typeof(SetFPSCap) == "function" then
            SetFPSCap(fps)
        elseif typeof(setfpslimit) == "function" then
            setfpslimit(fps)
        elseif typeof(setframerate) == "function" then
            setframerate(fps)
        end
    end)
end

-- ═════════════════════════════════════════════════════════════════
-- 9. 🧹 PERIODIC RAM GARBAGE COLLECTOR
-- ═════════════════════════════════════════════════════════════════
function Graphics.StartMemoryCleaner(interval)
    interval = interval or 60
    Graphics.AutoMemoryCleanupEnabled = true
    if memoryCleanupThread then pcall(function() task.cancel(memoryCleanupThread) end) end
    memoryCleanupThread = task.spawn(function()
        while Graphics.AutoMemoryCleanupEnabled do
            task.wait(interval)
            pcall(function()
                if typeof(collectgarbage) == "function" then
                    pcall(collectgarbage, "collect")
                end
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

-- ═════════════════════════════════════════════════════════════════
-- 10. 🚀 ULTRA MODE (All-In-One: Potato + Hide Players + Freeze NPCs + Kill VFX)
-- ═════════════════════════════════════════════════════════════════
function Graphics.EnableUltraMode()
    Graphics.EnablePotatoGraphics()
    Graphics.HideOtherPlayers()
    Graphics.FreezeAllNPCsAndAnimations()
    Graphics.DisableAllVFX()
    startDescendantHook()

    -- Lightweight sweeper for new units/players (every 8s)
    if not potatoSweeperThread then
        potatoSweeperThread = task.spawn(function()
            while Graphics.PotatoEnabled do
                task.wait(8)
                if not Graphics.PotatoEnabled then break end
                -- Re-hide any new players that joined
                if Graphics.HideOtherPlayersEnabled then
                    for _, p in ipairs(Players:GetPlayers()) do
                        hidePlayer(p)
                    end
                end
                -- Re-freeze any new NPCs/animators
                if Graphics.FreezeNPCsEnabled then
                    local count = 0
                    for _, desc in ipairs(Workspace:GetDescendants()) do
                        if not isProtectedObject(desc) then
                            if desc:IsA("Animator") or desc:IsA("AnimationController") then
                                freezeAnimator(desc)
                            elseif desc:IsA("Humanoid") then
                                freezeHumanoid(desc)
                            end
                        end
                        count = count + 1
                        if count % 500 == 0 then task.wait() end
                    end
                end
            end
            potatoSweeperThread = nil
        end)
    end
end

function Graphics.DisableUltraMode()
    Graphics.DisablePotatoGraphics()
    Graphics.ShowOtherPlayers()
    Graphics.UnfreezeNPCs()
    Graphics.EnableAllVFX()
    stopDescendantHook()
    if potatoSweeperThread then
        pcall(function() task.cancel(potatoSweeperThread) end)
        potatoSweeperThread = nil
    end
end

-- ═════════════════════════════════════════════════════════════════
-- 🛑 FULL UNLOAD / CLEANUP
-- ═════════════════════════════════════════════════════════════════
function Graphics.Unload()
    Graphics.DisableUltraMode()
    Graphics.DisableScreenOff()
    Graphics.StopMemoryCleaner()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    Graphics.SetFPSCap(60)
end

-- Start memory cleaner by default (every 60s)
Graphics.StartMemoryCleaner(60)

_G.FishAnAnimeGraphics = Graphics
return Graphics
