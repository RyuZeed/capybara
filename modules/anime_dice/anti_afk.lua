--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (ZERO-INTERFERENCE ANTI-AFK 24/7)
	Module: modules/anime_dice/anti_afk.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🛡️ 100% PURE CONNECTION BYPASS:
	  Disables Roblox CoreScript 'Idled' connections via getconnections().
	- 🚫 ZERO MOUSE / KEYBOARD SIMULATION:
	  No VirtualUser, no RightShift, no mouse clicks. Guaranteed
	  zero shift-lock activation and zero camera interference.
	- 🔓 AUTOMATIC SHIFTLOCK DEFUSER:
	  Disables the game's internal ShiftlockController so pressing
	  Shift never locks the cursor to the center.
	===============================================================
]]

local AntiAFK = {}
AntiAFK.__index = AntiAFK

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- ─── 1. Reconnection Daemon ──────────────────────────────────────
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

-- ─── 2. Shiftlock Defuser ────────────────────────────────────────
local function defuseGameShiftlock()
    pcall(function()
        local slMod = ReplicatedStorage:FindFirstChild("Framework")
            and ReplicatedStorage.Framework:FindFirstChild("Features")
            and ReplicatedStorage.Framework.Features:FindFirstChild("Player")
            and ReplicatedStorage.Framework.Features.Player:FindFirstChild("ShiftlockController")
        if slMod then
            local sl = require(slMod)
            if sl then
                if typeof(sl.Disable) == "function" then
                    sl:Disable()
                elseif sl.Enabled then
                    sl:ToggleShiftLock(false)
                end
            end
        end
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)
end

-- ─── 3. Pure Idled Connection Bypass ─────────────────────────────
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

-- ─── 4. Error / Disconnect Listeners ─────────────────────────────
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

-- ─── 5. Public Controller ────────────────────────────────────────
function AntiAFK.Start()
    if AntiAFK.Enabled then return end
    AntiAFK.Enabled = true
    isReconnecting = false

    -- 1. Defuse game shift lock immediately
    defuseGameShiftlock()

    -- 2. Disable Roblox 20-minute idle connections
    disableIdledConnections()

    -- 3. Listener fallback: if Idled ever fires, re-disable without moving camera or mouse
    if idledConn then
        pcall(function() idledConn:Disconnect() end)
        idledConn = nil
    end

    local lp = Players.LocalPlayer or LocalPlayer
    if lp then
        idledConn = lp.Idled:Connect(function()
            if AntiAFK.Enabled then
                disableIdledConnections()
                defuseGameShiftlock()
            end
        end)
    end

    -- 4. Passive heartbeat loop (every 60s) to keep connections disabled
    if not loopThread then
        loopThread = task.spawn(function()
            while AntiAFK.Enabled do
                disableIdledConnections()
                defuseGameShiftlock()
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
