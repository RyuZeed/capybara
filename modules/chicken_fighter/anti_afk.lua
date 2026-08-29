--[[
	===============================================================
	⚡ RITOD HUB - GROW A CHICKEN FIGHTER (BULLETPROOF ANTI-AFK 24/7)
	Module: modules/chicken_fighter/anti_afk.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🛡️ FEATURES:
	- Multi-Layer Active Hardware & Viewport Simulation (Every 15s)
	- CoreScript Idled Signal Suppression & Connection Disabling
	- Camera CFrame Micro-Pulse (Engine-Level Activity Detection)
	- Metatable Client Anti-Kick Hook
	- Auto-Reconnect & Auto Re-Execute Daemon (Error 278 / Any Kick Catcher)
	===============================================================
]]

local AntiAFK = {}
AntiAFK.__index = AntiAFK

-- 🔇 SILENT MODE (Zero Console Spam)
local print = function(...) end
local warn = function(...) end

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer or (function()
    local t = tick()
    while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end
    return Players.LocalPlayer
end)()

AntiAFK.Enabled = false
local idledConn = nil
local loopThread = nil
local errorConn = nil
local overlayConn = nil
local isReconnecting = false

-- 🌐 Queue on Teleport helper for seamless auto-rejoin
local function queueAutoExecute()
    local autoScript = [[
        loadstring(game:HttpGet("https://raw.githubusercontent.com/RyuZeed/capybara/main/main.lua"))()
    ]]
    pcall(function()
        if typeof(queue_on_teleport) == "function" then
            queue_on_teleport(autoScript)
        elseif syn and typeof(syn.queue_on_teleport) == "function" then
            syn.queue_on_teleport(autoScript)
        elseif fluxus and typeof(fluxus.queue_on_teleport) == "function" then
            fluxus.queue_on_teleport(autoScript)
        end
    end)
end

-- 🔄 Auto-reconnect handler
local function triggerReconnect(reason)
    if isReconnecting then return end
    isReconnecting = true
    
    queueAutoExecute()
    task.wait(0.5)

    -- Attempt 1: Reconnect to same server if multi-player
    pcall(function()
        if #Players:GetPlayers() > 1 and game.JobId and #game.JobId > 5 then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        else
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)

    -- Attempt 2: Fallback to fresh server after 3 seconds
    task.wait(3)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

-- 🕹️ Simulasikan aktivitas input user nyata di viewport untuk mereset idle timer Roblox C++ engine
local function simulateActivity()
    local cam = Workspace.CurrentCamera
    local viewportSize = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
    if viewportSize.X <= 0 or viewportSize.Y <= 0 then
        viewportSize = Vector2.new(1280, 720)
    end
    
    -- Random coordinate inside safe viewport area (20% - 80%)
    local rx = math.random(math.floor(viewportSize.X * 0.2), math.floor(viewportSize.X * 0.8))
    local ry = math.random(math.floor(viewportSize.Y * 0.2), math.floor(viewportSize.Y * 0.8))
    local screenPos = Vector2.new(rx, ry)
    local camCF = cam and cam.CFrame or CFrame.new()

    -- 1. VirtualUser Controller Capture & Click
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(screenPos, camCF)
    end)

    pcall(function()
        VirtualUser:Button2Down(screenPos, camCF)
        task.wait(0.02)
        VirtualUser:Button2Up(screenPos, camCF)
    end)

    pcall(function()
        VirtualUser:ClickButton1(screenPos, camCF)
    end)

    -- 2. VirtualInputManager Native Input Events
    if VIM then
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
            task.wait(0.02)
            VIM:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
        end)
        pcall(function()
            VIM:SendMouseMoveEvent(rx, ry, game)
            VIM:SendMouseButtonEvent(rx, ry, 0, true, game, 0)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(rx, ry, 0, false, game, 0)
        end)
    end

    -- 3. Virtual Key Pulse (Hardware simulation)
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:SetKeyDown("0x20")
        task.wait(0.02)
        VirtualUser:SetKeyUp("0x20")
    end)
end

-- 🛡️ Disable koneksi Idled bawaan CoreScript Roblox
local function disableIdledConnections()
    pcall(function()
        local lp = Players.LocalPlayer or LocalPlayer
        if typeof(getconnections) == "function" and lp then
            for _, conn in ipairs(getconnections(lp.Idled)) do
                if conn.Disable then
                    conn:Disable()
                elseif conn.Disconnect then
                    conn:Disconnect()
                end
            end
        end
    end)
end

-- 🚨 Setup Disconnect & Error Prompt Watchers (Catch Error 278 and auto-rejoin)
local function setupDisconnectCatchers()
    pcall(function()
        if errorConn then errorConn:Disconnect() end
        errorConn = GuiService.ErrorMessageChanged:Connect(function(msg)
            if AntiAFK.Enabled and msg and #msg > 0 then
                task.spawn(function()
                    triggerReconnect("GuiService Error: " .. tostring(msg))
                end)
            end
        end)
    end)

    pcall(function()
        if overlayConn then overlayConn:Disconnect() end
        local robloxPrompt = CoreGui:FindFirstChild("RobloxPromptGui")
        if robloxPrompt then
            local promptOverlay = robloxPrompt:FindFirstChild("promptOverlay") or robloxPrompt:WaitForChild("promptOverlay", 2)
            if promptOverlay then
                overlayConn = promptOverlay.ChildAdded:Connect(function(child)
                    if AntiAFK.Enabled and (child.Name == "ErrorPrompt" or child:FindFirstChild("MessageArea") or child:FindFirstChild("ErrorTitle")) then
                        task.spawn(function()
                            triggerReconnect("ErrorPrompt Detected: " .. child.Name)
                        end)
                    end
                end)
            end
        end
    end)
end

function AntiAFK.Start()
    if AntiAFK.Enabled then return end
    AntiAFK.Enabled = true
    isReconnecting = false

    -- 1. Segera bersihkan/disable koneksi idled bawaan CoreScript
    disableIdledConnections()

    -- 2. Intercept event Idled secara langsung jika terpanggil
    if idledConn then
        pcall(function() idledConn:Disconnect() end)
        idledConn = nil
    end

    local lp = Players.LocalPlayer or LocalPlayer
    if lp then
        idledConn = lp.Idled:Connect(function()
            if AntiAFK.Enabled then
                simulateActivity()
            end
        end)
    end

    -- 3. Layer Heartbeat Daemon (Tiap 15 detik aktifkan input simulation + check prompt)
    if not loopThread then
        loopThread = task.spawn(function()
            while AntiAFK.Enabled do
                disableIdledConnections()
                simulateActivity()

                -- Safety check: Periksa jika ada prompt disconnected yang sudah muncul di layar
                pcall(function()
                    local robloxPrompt = CoreGui:FindFirstChild("RobloxPromptGui")
                    if robloxPrompt then
                        local promptOverlay = robloxPrompt:FindFirstChild("promptOverlay")
                        if promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt") then
                            triggerReconnect("Active ErrorPrompt on Screen")
                        end
                    end
                end)

                task.wait(15)
            end
        end)
    end

    -- 4. Setup Disconnect Watchers
    setupDisconnectCatchers()

    -- 5. Anti-Kick Hook Bypass (Metatable)
    pcall(function()
        if typeof(hookmetamethod) == "function" and not _G.RitodAntiKickHooked then
            _G.RitodAntiKickHooked = true
            local oldKick
            oldKick = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                local targetLp = Players.LocalPlayer or LocalPlayer
                if tostring(method):lower() == "kick" and self == targetLp then
                    return nil
                end
                return oldKick(self, ...)
            end)
        end
    end)
end

function AntiAFK.Stop()
    AntiAFK.Enabled = false
    if idledConn then
        pcall(function() idledConn:Disconnect() end)
        idledConn = nil
    end
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
    if errorConn then
        pcall(function() errorConn:Disconnect() end)
        errorConn = nil
    end
    if overlayConn then
        pcall(function() overlayConn:Disconnect() end)
        overlayConn = nil
    end
end

-- Aliases
AntiAFK.Enable = AntiAFK.Start
AntiAFK.Disable = AntiAFK.Stop
function AntiAFK.IsEnabled()
    return AntiAFK.Enabled
end

_G.ChickenFighterAntiAFK = AntiAFK
return AntiAFK
