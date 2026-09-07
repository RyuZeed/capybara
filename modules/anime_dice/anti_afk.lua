--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (BULLETPROOF ANTI-AFK 24/7)
	Module: modules/anime_dice/anti_afk.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AntiAFK = {}
AntiAFK.__index = AntiAFK

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

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

local function triggerReconnect(reason)
    if isReconnecting then return end
    isReconnecting = true
    queueAutoExecute()

    task.spawn(function()
        for attempt = 1, 5 do
            task.wait(1.5)
            local ok = pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
            if ok then break end
        end
    end)
end

local function simulateActivity()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end

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

    disableIdledConnections()

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

    if not loopThread then
        loopThread = task.spawn(function()
            while AntiAFK.Enabled do
                disableIdledConnections()
                simulateActivity()
                task.wait(60)
            end
        end)
    end

    setupDisconnectCatchers()
end

function AntiAFK.Stop()
    AntiAFK.Enabled = false
    if idledConn then
        pcall(function() idledConn:Disconnect() end)
        idledConn = nil
    end
    if loopThread then
        task.cancel(loopThread)
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

_G.AnimeDiceAntiAFK = AntiAFK
return AntiAFK
