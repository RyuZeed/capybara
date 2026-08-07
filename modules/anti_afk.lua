local AFKModule = {}

local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local connection = nil

function AFKModule.Enable()
    if connection then return end
    connection = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
    print("🛡️ [Ritod Hub] Anti-AFK Aktif 24/7!")
end

function AFKModule.Disable()
    if connection then
        connection:Disconnect()
        connection = nil
        print("🛑 [Ritod Hub] Anti-AFK Dimatikan.")
    end
end

return AFKModule
