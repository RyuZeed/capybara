-- =================================================================
-- 🛡️ RITOD HUB | MODULAR ANTI-AFK 24/7 (MULTI-LAYER BYPASS)
-- Game: Roll Anime For Fight / Anime Auto Roll
-- =================================================================

local AFKModule = {}

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local idledConn = nil
local heartbeatRunning = false

function AFKModule.Enable()
    -- 1. Disable native Idled connections
    pcall(function()
        if typeof(getconnections) == "function" then
            for _, conn in ipairs(getconnections(LocalPlayer.Idled)) do
                if conn.Disable then
                    conn:Disable()
                elseif conn.Disconnect then
                    conn:Disconnect()
                end
            end
        end
    end)

    -- 2. Intercept Idled event
    if not idledConn then
        idledConn = LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end)
    end

    -- 3. Periodic Hardware Virtual Pulse (Every 45 seconds)
    if not heartbeatRunning then
        heartbeatRunning = true
        task.spawn(function()
            while heartbeatRunning do
                task.wait(45)
                if not heartbeatRunning then break end
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
                end)
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
            end
        end)
    end

    -- 4. Anti-Kick Metatable Hook
    pcall(function()
        local oldKick
        oldKick = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if tostring(method):lower() == "kick" and self == LocalPlayer then
                print("🛡️ [Ritod Anti-AFK] Blocked Kick attempt!")
                return nil
            end
            return oldKick(self, ...)
        end)
    end)

    print("🛡️ [Ritod Hub] Bulletproof Anti-AFK 24/7 Aktif!")
end

function AFKModule.Disable()
    heartbeatRunning = false
    if idledConn then
        idledConn:Disconnect()
        idledConn = nil
    end
    print("🛑 [Ritod Hub] Anti-AFK Dimatikan.")
end

return AFKModule
