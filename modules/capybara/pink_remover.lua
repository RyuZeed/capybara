local PinkRemover = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local descendantConn = nil
local running = false

local function checkAndHidePinkLabel(label)
    if not label or not label:IsA("TextLabel") then return end

    local rawTxt = label.Text or ""
    local txt = rawTxt:lower():gsub("%s+", " ")

    local isMatch = txt:find("please try again")
        or txt:find("try again")
        or txt:find("can't claim")
        or txt:find("cannot claim")
        or txt:find("already claimed")
        or txt:find("you've already")
        or txt:find("claim this yet")
        or txt:find("too fast")
        or txt:find("slow down")
        or txt:find("cooldown")
        or txt:find("wait a bit")
        or txt:find("not ready")
        or txt:find("error")

    -- Deteksi warna teks pink/merah notification popup
    local c = label.TextColor3
    local isPinkish = (c.R > 0.8 and c.G < 0.75 and c.B < 0.75) or (c.R > 0.8 and c.B > 0.6 and c.G < 0.7)
    if isMatch or (isPinkish and (txt:find("again") or txt:find("claim") or txt:find("wait"))) then
        label.Visible = false
        label.Text = ""
        pcall(function()
            if label.Parent and label.Parent:IsA("GuiObject") and not label.Parent.Name:lower():find("hub") then
                label.Parent.Visible = false
            end
        end)
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
