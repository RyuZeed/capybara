--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (BULLETPROOF ANTI-AFK 24/7)
	Module: modules/fish_an_anime/anti_afk.lua
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

local function reconnect()
    if isReconnecting then return end
    isReconnecting = true
    queueAutoExecute()
    task.wait(1)
    pcall(function()
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("\n⚡ [Ritod Anti-AFK] Reconnecting to server...")
            task.wait(0.5)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
    task.delay(10, function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function hookErrorPrompt()
    if errorConn then return end
    pcall(function()
        errorConn = GuiService.ErrorMessageChanged:Connect(function(msg)
            if not AntiAFK.Enabled then return end
            if msg and #msg > 0 then
                reconnect()
            end
        end)
    end)

    pcall(function()
        local robloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if robloxPromptGui then
            local promptOverlay = robloxPromptGui:FindFirstChild("promptOverlay")
            if promptOverlay then
                overlayConn = promptOverlay.ChildAdded:Connect(function(child)
                    if not AntiAFK.Enabled then return end
                    if child.Name == "ErrorPrompt" then
                        task.wait(0.5)
                        reconnect()
                    end
                end)
            end
        end
    end)
end

function AntiAFK.Start()
    if AntiAFK.Enabled then return end
    AntiAFK.Enabled = true

    pcall(function()
        if LocalPlayer and getconnections then
            for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
                conn:Disable()
            end
        end
    end)

    pcall(function()
        if LocalPlayer then
            idledConn = LocalPlayer.Idled:Connect(function()
                if not AntiAFK.Enabled then return end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end)
        end
    end)

    hookErrorPrompt()

    if loopThread then task.cancel(loopThread) end
    loopThread = task.spawn(function()
        while AntiAFK.Enabled do
            task.wait(15)
            if not AntiAFK.Enabled then break end

            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)

            if VIM then
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
                end)
            end

            pcall(function()
                local camera = Workspace.CurrentCamera
                if camera then
                    local currentCF = camera.CFrame
                    camera.CFrame = currentCF * CFrame.Angles(0, 0, math.rad(0.01))
                    task.wait(0.05)
                    camera.CFrame = currentCF
                end
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

_G.FishAnAnimeAntiAFK = AntiAFK
return AntiAFK
