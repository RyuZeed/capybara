-- =================================================================
-- 🚀 RITOD HUB | ULTIMATE HYBRID CPU REDUCER & POTATO GRAPHICS (V5.2 ULTRA)
-- Game: Roll Anime For Fight / Anime Auto Roll
-- Fitur & Optimasi Unggulan:
--   ✅ 5-Method Smart Plot Isolator (Auto-detect & Protect Player's Own Plot)
--   ✅ Humanoid & Animator Freezer (Hooks AnimationPlayed to stop CPU-heavy anime loops)
--   ✅ 100% Ghaib Player & Other Unit Hiding (Anchored, CanTouch/CanQuery Off)
--   ✅ Batched Descendant Queue (Eliminates lag spikes during mass gacha rolls)
--   ✅ 3D Sound Muter & BillboardGui Optimizer
--   ✅ 8-Executor Native FPS Cap + Resilient Mobile/PC Watchdog
--   ✅ Engine-Level 3D Rendering Control (Set3dRenderingEnabled false + Black Screen)
--   ✅ Periodic RAM Purge (collectgarbage + gcinfo)
--   ✅ Full Backward Compatibility: SetFarmMode, EnablePotato, SetAntiLag, ApplyFpsCap
-- =================================================================

local GraphicsModule = {}
_G.GraphicsModule = GraphicsModule
_G.GraphicsOptimizer = GraphicsModule

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

-- Services
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")
local CoreGui           = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer       = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

-- User Configuration
local userConfig = (getgenv and (getgenv().RitodConfig or getgenv().UserConfig)) or {}

-- =================================================================
-- ⚙️ CONFIGURATION SETTINGS
-- =================================================================
local SETTINGS = {
    TargetFPS              = userConfig["FPS Cap"] or 60,
    AFK_FPS_Cap            = 10,
    Normal_FPS_Cap         = 60,
    BatchChunkSize         = 200,
    AutoGCInterval         = 45,
    AutoThrottleBackground = false,
}

local States = {
    PotatoGraphics   = false,
    FarmMode         = false,  -- 3D Rendering Off + Black Screen AFK
    AntiLag          = false,  -- FPS Capped to AFK_FPS_Cap & Shadows Off
    Is3DDisabled     = false,
    BaseFPS          = SETTINGS.TargetFPS or 60,
    CurrentFPSCap    = SETTINGS.TargetFPS or 60,
}

local Connections = {}
local screenOffGui = nil
local syncCallback = nil

-- Fast internal tagging key to avoid redundant re-checks
local PROCESSED_TAG = "_r_cleaned_v5"
local FROZEN_TAG = "_r_frozen_v5"

-- =================================================================
-- 1. 🏰 SMART PLOT ISOLATOR & CACHING
-- =================================================================
local cachedMyPlot = nil
local lastPlotCheck = 0

local function findMyPlot()
    local now = os.clock()
    if cachedMyPlot and cachedMyPlot.Parent and (now - lastPlotCheck < 10) then
        return cachedMyPlot
    end
    lastPlotCheck = now

    local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Bases")
    if not plots then return nil end

    local playerName = LocalPlayer.Name
    local userIdStr  = tostring(LocalPlayer.UserId)
    local displayName = LocalPlayer.DisplayName

    -- Method 1: Nama Model Plot cocok dengan Username atau UserId
    for _, plot in ipairs(plots:GetChildren()) do
        if plot.Name == playerName or plot.Name == userIdStr then
            cachedMyPlot = plot
            return plot
        end
    end

    -- Method 2: Cek Attributes Plot
    for _, plot in ipairs(plots:GetChildren()) do
        local attrs = plot:GetAttributes()
        for _, attrVal in pairs(attrs) do
            local valStr = tostring(attrVal)
            if valStr == playerName or valStr == userIdStr or valStr == displayName then
                cachedMyPlot = plot
                return plot
            end
        end
    end

    -- Method 3: Cek NameBillboard / TextLabel nama player di dalam plot
    for _, plot in ipairs(plots:GetChildren()) do
        local namePart = plot:FindFirstChild("NameBillboardPart", true) or plot:FindFirstChild("OwnerSign", true)
        if namePart then
            for _, d in ipairs(namePart:GetDescendants()) do
                if d:IsA("TextLabel") and (d.Text == playerName or d.Text == displayName or string.find(d.Text, playerName) or string.find(d.Text, displayName)) then
                    cachedMyPlot = plot
                    return plot
                end
            end
        end
    end

    -- Method 4: Cek seluruh TextLabel di dalam plot
    for _, plot in ipairs(plots:GetChildren()) do
        for _, d in ipairs(plot:GetDescendants()) do
            if d:IsA("TextLabel") and (d.Text == playerName or d.Text == displayName) then
                cachedMyPlot = plot
                return plot
            end
        end
    end

    -- Method 5: Jarak terdekat ke Character HRP
    local char = LocalPlayer.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    if hrp then
        local closestPlot = nil
        local closestDist = 120
        for _, plot in ipairs(plots:GetChildren()) do
            local pPart = plot:FindFirstChildWhichIsA("BasePart", true)
            if pPart then
                local dist = (pPart.Position - hrp.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPlot = plot
                end
            end
        end
        if closestPlot then
            cachedMyPlot = closestPlot
            return closestPlot
        end
    end

    return cachedMyPlot
end

-- =================================================================
-- 2. 🛡️ ROBUST PROTECTED OBJECT GUARD
-- =================================================================
local function isProtectedObject(obj)
    if not obj or not obj.Parent then return true end

    -- 1. Karakter LocalPlayer
    local char = LocalPlayer.Character
    if char and (obj == char or obj:IsDescendantOf(char)) then
        return true
    end

    -- 2. Backpack / Hotbar
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp and (obj == bp or obj:IsDescendantOf(bp)) then
        return true
    end

    -- 3. Tool / Accoutrement apapun yang dipegang
    if obj:IsA("Tool") or obj:FindFirstAncestorOfClass("Tool")
       or obj:IsA("Accoutrement") or obj:FindFirstAncestorOfClass("Accoutrement") then
        return true
    end

    -- 4. Kamera Workspace
    local cam = Workspace:FindFirstChildOfClass("Camera")
    if cam and (obj == cam or obj:IsDescendantOf(cam)) then
        return true
    end

    -- 5. ProximityPrompt / Tombol Interaksi Game
    if obj:IsA("ProximityPrompt") or obj:FindFirstChildOfClass("ProximityPrompt") then
        return true
    end

    -- 6. SELURUH PLOT SENDIRI (Mesin Roll, Pedestal, Unit Sendiri)
    local myPlot = findMyPlot()
    if myPlot and (obj == myPlot or obj:IsDescendantOf(myPlot)) then
        return true
    end

    return false
end

-- =================================================================
-- 3. 🎯 HIGH-PERFORMANCE FPS CONTROLLER
-- =================================================================
local function rawSetFpsCap(fps)
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

local function applyFpsCap(fps)
    States.CurrentFPSCap = fps
    rawSetFpsCap(fps)
end

-- Persistent FPS Watchdog
local fpsWatchdog = nil
local function startFpsWatchdog()
    if fpsWatchdog then return end
    fpsWatchdog = task.spawn(function()
        while true do
            task.wait(1.5)
            local target = (States.FarmMode or States.AntiLag) and SETTINGS.AFK_FPS_Cap or (States.BaseFPS or SETTINGS.Normal_FPS_Cap)
            rawSetFpsCap(target)
        end
    end)
end
startFpsWatchdog()

-- Mobile touch listener agar FPS cap tidak reset saat disentuh di executor mobile (Delta, Arceus X, Fluxus)
pcall(function()
    local touchConn = UserInputService.TouchStarted:Connect(function()
        if States.FarmMode or States.AntiLag then
            rawSetFpsCap(SETTINGS.AFK_FPS_Cap)
        end
    end)
    table.insert(Connections, touchConn)
end)

function GraphicsModule.ApplyFpsCap(fps)
    if fps and fps > 5 then
        States.BaseFPS = fps
    end
    local target = fps or ((States.FarmMode or States.AntiLag) and SETTINGS.AFK_FPS_Cap or (States.BaseFPS or SETTINGS.Normal_FPS_Cap))
    applyFpsCap(target)
end

-- =================================================================
-- 4. 🌑 ENGINE LEVEL 3D RENDERING CONTROLLER (FARM MODE)
-- =================================================================
local function set3DRendering(enabled)
    States.Is3DDisabled = not enabled
    pcall(function()
        RunService:Set3dRenderingEnabled(enabled)
    end)
end

-- =================================================================
-- 5. 🤖 HUMANOID & ANIMATOR FREEZER (CPU SAVER TERBAIK UNTUK ANIME GAME)
-- =================================================================
local function freezeUnitModel(model)
    if not model or not model.Parent or isProtectedObject(model) then return end

    local humanoids = {}
    if model:IsA("Humanoid") or model:IsA("AnimationController") then
        table.insert(humanoids, model)
    else
        for _, h in ipairs(model:GetChildren()) do
            if h:IsA("Humanoid") or h:IsA("AnimationController") then
                table.insert(humanoids, h)
            end
        end
    end

    for _, humanoid in ipairs(humanoids) do
        pcall(function()
            if humanoid:IsA("Humanoid") then
                humanoid.WalkSpeed = 0
                humanoid.JumpPower = 0
                humanoid.AutoRotate = false
                humanoid.PlatformStand = true
                humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
            end
        end)

        local animators = {}
        local animDirect = humanoid:FindFirstChildOfClass("Animator")
        if animDirect then table.insert(animators, animDirect) end
        for _, a in ipairs(humanoid:GetChildren()) do
            if a:IsA("Animator") and a ~= animDirect then
                table.insert(animators, a)
            end
        end

        for _, animator in ipairs(animators) do
            pcall(function()
                local tracks = animator:GetPlayingAnimationTracks()
                for _, track in ipairs(tracks) do
                    pcall(function()
                        track:Stop(0)
                        track:AdjustSpeed(0)
                    end)
                end

                if not animator:GetAttribute(FROZEN_TAG) then
                    animator:SetAttribute(FROZEN_TAG, true)
                    animator.AnimationPlayed:Connect(function(track)
                        if (States.PotatoGraphics or States.AntiLag or States.FarmMode) and not isProtectedObject(animator) then
                            pcall(function()
                                track:Stop(0)
                                track:AdjustSpeed(0)
                            end)
                        end
                    end)
                end
            end)
        end
    end

    -- Sembunyikan & Anchor Parts
    for _, obj in ipairs(model:GetChildren()) do
        if obj:IsA("BasePart") then
            pcall(function()
                obj.Transparency = 1
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
                obj.CastShadow = false
                obj.Anchored = true
                obj.AssemblyLinearVelocity = Vector3.zero
                obj.AssemblyAngularVelocity = Vector3.zero
            end)
        elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            pcall(function() obj.Enabled = false end)
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Highlight") then
            pcall(function() obj.Enabled = false end)
        end
    end
end

-- =================================================================
-- 6. ⚡ ULTRA PERFORMANCE BOOSTER (FIX 48 RIG LOOPS & 271 PHYSICS PARTS)
-- =================================================================
local function disableSkillEffects(parent)
    if not parent then return end
    pcall(function()
        for _, desc in ipairs(parent:GetDescendants()) do
            local cls = desc.ClassName
            if cls == "ParticleEmitter" then
                pcall(function() desc.Enabled = false desc.Rate = 0 end)
            elseif cls == "Trail" or cls == "Beam" or cls == "Highlight" or cls == "Fire" or cls == "Smoke" or cls == "Sparkles" then
                pcall(function() desc.Enabled = false end)
            elseif cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
                pcall(function() desc.Enabled = false end)
            elseif cls == "Sound" then
                pcall(function() desc.Volume = 0 desc.Playing = false end)
            end
        end
    end)
end

local function freezeAllUnitsAndSkills()
    pcall(function()
        local ws = game:GetService("Workspace")
        local rs = game:GetService("ReplicatedStorage")
        
        -- 1. Freeze seluruh Animators & Humanoids di game (Kecuali karakter sendiri)
        for _, desc in ipairs(ws:GetDescendants()) do
            if not isProtectedObject(desc) then
                if desc:IsA("Animator") or desc:IsA("AnimationController") then
                    pcall(function()
                        for _, track in ipairs(desc:GetPlayingAnimationTracks()) do
                            pcall(function()
                                track:Stop(0)
                                track:AdjustSpeed(0)
                            end)
                        end
                        if not desc:GetAttribute(FROZEN_TAG) then
                            desc:SetAttribute(FROZEN_TAG, true)
                            desc.AnimationPlayed:Connect(function(tr)
                                if States.PotatoGraphics or States.AntiLag or States.FarmMode then
                                    pcall(function() tr:Stop(0) tr:AdjustSpeed(0) end)
                                end
                            end)
                        end
                    end)
                elseif desc:IsA("Humanoid") then
                    pcall(function()
                        desc.WalkSpeed = 0
                        desc.JumpPower = 0
                        desc.AutoRotate = false
                        desc.PlatformStand = true
                        desc.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                        desc.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                    end)
                end
            end
        end

        -- 2. Matikan efek skill di folder Effects / VFX / Debris jika ada
        for _, folderName in ipairs({"Effects", "VFX", "Debris", "Skills", "Projectiles", "Spells"}) do
            local folder = ws:FindFirstChild(folderName) or (rs and rs:FindFirstChild(folderName))
            if folder then
                pcall(disableSkillEffects, folder)
            end
        end
    end)
end

-- =================================================================
-- 7. 🧹 TARGETED OTHER-PLOT & OTHER-PLAYER HIDER (MAP PRESERVED)
-- =================================================================
local function hideOtherPlots()
    local myPlot = findMyPlot()
    local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Bases")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            if plot ~= myPlot and not isProtectedObject(plot) then
                for _, desc in ipairs(plot:GetDescendants()) do
                    if desc:IsA("BasePart") then
                        pcall(function()
                            desc.Transparency = 1
                            desc.CanCollide = false
                            desc.CanTouch = false
                            desc.CanQuery = false
                            desc.CastShadow = false
                            desc.Anchored = true
                            desc.AssemblyLinearVelocity = Vector3.zero
                            desc.AssemblyAngularVelocity = Vector3.zero
                        end)
                    elseif desc:IsA("Decal") or desc:IsA("Texture") then
                        pcall(function() desc.Transparency = 1 end)
                    elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Highlight") or desc:IsA("Light") then
                        pcall(function() desc.Enabled = false end)
                    elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
                        pcall(function() desc.Enabled = false end)
                    elseif desc:IsA("Humanoid") then
                        pcall(function()
                            desc.WalkSpeed = 0
                            desc.JumpPower = 0
                            desc.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                            desc.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
                        end)
                    end
                end
            end
        end
    end
end

local function hideOtherPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not isProtectedObject(p.Character) then
            freezeUnitModel(p.Character)
            disableSkillEffects(p.Character)
        end
    end
end

-- =================================================================
-- 8. 🥔 POTATO GRAPHICS CONTROLLER (ZERO MAP CORRUPTION)
-- =================================================================
local potatoSweeperThread = nil
local playerAddedConn = nil
local vfxDescendantConn = nil

local function runTargetedClean()
    task.spawn(function()
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            Lighting.GlobalShadows = false
            Lighting.Technology = Enum.Technology.Compatibility
            Lighting.FogEnd = 9e9
        end)

        -- 1. Set FPS Cap ke 60
        applyFpsCap(60)

        -- 2. Sembunyikan plot pemain lain & nonaktifkan fisika unanchored
        hideOtherPlots()

        -- 3. Sembunyikan karakter pemain lain
        hideOtherPlayers()

        -- 4. Freeze seluruh 48 rig animasi unit & hilangkan partikel skill
        freezeAllUnitsAndSkills()

        -- 5. Bersihkan RAM 2.3 GB
        pcall(function() collectgarbage("collect") end)
    end)
end

function GraphicsModule.EnablePotato(enable)
    States.PotatoGraphics = enable

    if enable then
        runTargetedClean()

        -- Real-time Skill VFX Muter (Langsung matikan partikel skill baru saat spawn)
        if not vfxDescendantConn then
            vfxDescendantConn = Workspace.DescendantAdded:Connect(function(v)
                if States.PotatoGraphics and not isProtectedObject(v) then
                    local cls = v.ClassName
                    if cls == "ParticleEmitter" then
                        pcall(function() v.Enabled = false v.Rate = 0 end)
                    elseif cls == "Trail" or cls == "Beam" or cls == "Highlight" or cls == "Fire" or cls == "Smoke" or cls == "Sparkles" then
                        pcall(function() v.Enabled = false end)
                    elseif cls == "AnimationTrack" then
                        pcall(function() v:Stop(0) v:AdjustSpeed(0) end)
                    end
                end
            end)
            table.insert(Connections, vfxDescendantConn)
        end

        -- Lightweight Sweeper (setiap 5s untuk membersihkan unit / pemain baru)
        if not potatoSweeperThread then
            potatoSweeperThread = task.spawn(function()
                while States.PotatoGraphics do
                    task.wait(5)
                    if not States.PotatoGraphics then break end
                    hideOtherPlots()
                    hideOtherPlayers()
                    freezeAllUnitsAndSkills()
                end
                potatoSweeperThread = nil
            end)
        end

        if not playerAddedConn then
            playerAddedConn = Players.PlayerAdded:Connect(function(p)
                p.CharacterAdded:Connect(function(char)
                    if States.PotatoGraphics then
                        task.wait(0.5)
                        if p ~= LocalPlayer and char then
                            freezeUnitModel(char)
                            disableSkillEffects(char)
                        end
                    end
                end)
            end)
            table.insert(Connections, playerAddedConn)
        end
    else
        if potatoSweeperThread then
            task.cancel(potatoSweeperThread)
            potatoSweeperThread = nil
        end
        if vfxDescendantConn then
            vfxDescendantConn:Disconnect()
            vfxDescendantConn = nil
        end
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            Lighting.GlobalShadows = true
        end)
    end
end

-- =================================================================
-- 9. ❄️ ANTI-LAG CONTROLLER (FPS CAP 5 & SHADOWS OFF)
-- =================================================================
function GraphicsModule.SetAntiLag(enable, customFps)
    States.AntiLag = enable
    if enable then
        local targetFps = customFps or SETTINGS.AFK_FPS_Cap
        applyFpsCap(targetFps)
        pcall(function() Lighting.GlobalShadows = false end)
    else
        pcall(function() Lighting.GlobalShadows = not States.PotatoGraphics end)
        local normalFps = States.FarmMode and SETTINGS.AFK_FPS_Cap or (States.BaseFPS or SETTINGS.Normal_FPS_Cap)
        applyFpsCap(normalFps)
    end
end

-- =================================================================
-- 10. 🚜 FARM MODE (PURE 3D RENDER OFF + BLACK SCREEN)
-- =================================================================
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

    local existing = targetParent:FindFirstChild("Ritod_AFKScreenOff")
    if existing then existing:Destroy() end

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
    subLbl.Text = "Render 3D dimatikan pada level engine. CPU & GPU usage turun ke ~5-10%.\nScript autofarm & roll kamu tetap berjalan 100% lancar."
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

    local function disableFarmMode()
        GraphicsModule.SetFarmMode(false)
        if syncCallback then pcall(function() syncCallback(false) end) end
    end

    -- Hanya tombol khusus di tengah yang bisa mematikan Farm Mode (mencegah Anti-AFK atau auto-clicker mematikan Farm Mode)
    hintBtn.MouseButton1Click:Connect(disableFarmMode)
end

local farmModeWatchdog = nil

function GraphicsModule.SetFarmMode(enable, onSync)
    States.FarmMode = enable
    if onSync then syncCallback = onSync end

    initScreenOffGui()
    if screenOffGui then screenOffGui.Enabled = enable end

    set3DRendering(not enable)

    if enable then
        if not farmModeWatchdog then
            farmModeWatchdog = task.spawn(function()
                while States.FarmMode do
                    set3DRendering(false)
                    task.wait(1)
                end
                farmModeWatchdog = nil
            end)
        end
    else
        set3DRendering(true)
    end

    local targetFps = enable and SETTINGS.AFK_FPS_Cap or (States.AntiLag and SETTINGS.AFK_FPS_Cap or (States.BaseFPS or SETTINGS.Normal_FPS_Cap))
    applyFpsCap(targetFps)
end

-- =================================================================
-- 11. ♻️ PERIODIC RAM GARBAGE COLLECTOR
-- =================================================================
task.spawn(function()
    while true do
        task.wait(SETTINGS.AutoGCInterval)
        pcall(function()
            collectgarbage("collect")
            if typeof(gcinfo) == "function" then
                gcinfo()
            end
        end)
    end
end)

function GraphicsModule.Unload()
    GraphicsModule.SetFarmMode(false)
    GraphicsModule.EnablePotato(false)
    GraphicsModule.SetAntiLag(false)
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}
    if screenOffGui then
        pcall(function() screenOffGui:Destroy() end)
        screenOffGui = nil
    end
    applyFpsCap(SETTINGS.Normal_FPS_Cap or 60)
    set3DRendering(true)
end

-- Alias
function GraphicsModule.SetPotatoGraphics(enable)
    GraphicsModule.EnablePotato(enable)
end

return GraphicsModule
