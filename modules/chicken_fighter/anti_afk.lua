--[[
	===============================================================
	⚡ RITOD HUB - GROW A CHICKEN FIGHTER (SAFE ANTI-AFK)
	Module: modules/chicken_fighter/anti_afk.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AntiAFK = {}
AntiAFK.__index = AntiAFK

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or (function()
    local t = tick()
    while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end
    return Players.LocalPlayer
end)()

AntiAFK.Enabled = false
local idledConnection = nil
local loopThread = nil

function AntiAFK.Start()
    if AntiAFK.Enabled then return end
    AntiAFK.Enabled = true

    -- Layer 1: Idled Interception (Safe Camera Angle Micro-Jitter)
    if not idledConnection then
        idledConnection = LocalPlayer.Idled:Connect(function()
            if AntiAFK.Enabled then
                pcall(function()
                    local camera = workspace.CurrentCamera
                    if camera then
                        camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, 0)
                    end
                end)
            end
        end)
    end

    -- Layer 2: Safe Heartbeat Daemon (Tiap 120 detik)
    if not loopThread then
        loopThread = task.spawn(function()
            while AntiAFK.Enabled do
                task.wait(120)
            end
        end)
    end
end

function AntiAFK.Stop()
    AntiAFK.Enabled = false
    if idledConnection then
        pcall(function() idledConnection:Disconnect() end)
        idledConnection = nil
    end
    if loopThread then
        pcall(function() task.cancel(loopThread) end)
        loopThread = nil
    end
end

_G.ChickenFighterAntiAFK = AntiAFK
return AntiAFK
