local PinkRemover = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local descendantConn = nil
local running = false

local function checkAndHidePinkLabel(label)
    if label:IsA("TextLabel") then
        local txt = label.Text:lower()
        if txt:find("can't claim") or txt:find("already claimed") or txt:find("you've already") or txt:find("claim this yet") then
            label.Visible = false
            if label.Parent and label.Parent:IsA("GuiObject") then
                label.Parent.Visible = false
            end
        end
    end
end

function PinkRemover.Start()
    if running then return end
    running = true

    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then return end

    -- Realtime detection via DescendantAdded (Zero Lag)
    descendantConn = playerGui.DescendantAdded:Connect(function(descendant)
        pcall(checkAndHidePinkLabel, descendant)
    end)

    local pinkPollThread = nil
    -- Polling backup every 1.5 seconds
    pinkPollThread = task.spawn(function()
        while running do
            pcall(function()
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                if pg then
                    for _, label in ipairs(pg:GetDescendants()) do
                        if label:IsA("TextLabel") and label.Visible then
                            checkAndHidePinkLabel(label)
                        end
                    end
                end
            end)
            task.wait(1.5)
        end
    end)

    print("🚫 [Ritod Hub] Pink Notification Destroyer Aktif!")
end

function PinkRemover.Stop()
    running = false
    if descendantConn then
        descendantConn:Disconnect()
        descendantConn = nil
    end
    if pinkPollThread then
        task.cancel(pinkPollThread)
        pinkPollThread = nil
    end
    print("🛑 [Ritod Hub] Pink Notification Destroyer Dimatikan.")
end

return PinkRemover
