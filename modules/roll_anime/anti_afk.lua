-- =================================================================
-- 🛡️ RITOD HUB | MODULAR ANTI-AFK 24/7 (MULTI-LAYER BULLETPROOF)
-- Game: Roll Anime For Fight / Anime Auto Roll
-- =================================================================

local AFKModule = {}
_G.AFKModule = AFKModule

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

local isEnabled = false
local afkThread = nil
local idledConn = nil

local function simulateActivity()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)

    pcall(function()
        local cam = Workspace.CurrentCamera
        local cf = cam and cam.CFrame or CFrame.new()
        VirtualUser:Button2Down(Vector2.new(0, 0), cf)
        task.wait(0.05)
        VirtualUser:Button2Up(Vector2.new(0, 0), cf)
    end)

    if VIM then
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
            task.wait(0.03)
            VIM:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
        end)
        pcall(function()
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.03)
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    end
end

local function disableIdledConnections()
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
end

function AFKModule.Enable()
    if isEnabled then return end
    isEnabled = true

    -- 1. Segera bersihkan koneksi idled bawaan
    disableIdledConnections()

    -- 2. Intercept event Idled secara langsung jika terpanggil
    if idledConn then idledConn:Disconnect() end
    idledConn = LocalPlayer.Idled:Connect(function()
        simulateActivity()
    end)

    -- 3. Loop hemat daya: Disable koneksi CoreScript & standby
    if not afkThread then
        afkThread = task.spawn(function()
            while isEnabled do
                disableIdledConnections()
                task.wait(120)
            end
        end)
    end

    -- 4. Anti-Kick Metatable Hook
    pcall(function()
        if typeof(hookmetamethod) == "function" and not _G.RitodAntiKickHooked then
            _G.RitodAntiKickHooked = true
            local oldKick
            oldKick = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if tostring(method):lower() == "kick" and self == LocalPlayer then
                    return nil
                end
                return oldKick(self, ...)
            end)
        end
    end)
end

function AFKModule.Disable()
    isEnabled = false
    if afkThread then
        task.cancel(afkThread)
        afkThread = nil
    end
    if idledConn then
        idledConn:Disconnect()
        idledConn = nil
    end
end

function AFKModule.IsEnabled()
    return isEnabled
end

return AFKModule
