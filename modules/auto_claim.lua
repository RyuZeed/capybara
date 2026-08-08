local AutoClaim = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local running = false

local function getMainGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
    if not pg then return nil end
    return pg:FindFirstChild("MainGui") or pg:WaitForChild("MainGui", 5) or pg:FindFirstChildWhichIsA("ScreenGui")
end

local function clickButton(btn)
    if not btn then return end

    if typeof(firesignal) == "function" then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.Activated) end)
    end

    if typeof(getconnections) == "function" then
        for _, eventName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "TouchTap"}) do
            pcall(function()
                if btn[eventName] then
                    for _, conn in ipairs(getconnections(btn[eventName])) do
                        if conn.Function then
                            conn.Function()
                        elseif conn.Fire then
                            conn:Fire()
                        end
                    end
                end
            end)
        end
    end

    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = math.floor(pos.X + size.X / 2)
        local cy = math.floor(pos.Y + size.Y / 2)

        if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
            VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
            task.wait(0.02)
            VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end
    end)

    pcall(function()
        VirtualUser:CaptureController()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        VirtualUser:ClickButton1(Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2))
    end)
end

function AutoClaim.Start()
    if running then return end
    running = true
    print("🎁 [Ritod Hub] Smart Auto Claim Active (Mobile & PC)...")

    task.spawn(function()
        while running do
            pcall(function()
                local mainGui = getMainGui()
                if not mainGui or not mainGui:FindFirstChild("Root") or not mainGui.Root:FindFirstChild("Frames") then
                    return
                end

                local ptFrame = mainGui.Root.Frames:FindFirstChild("PlaytimeRewards")

                -- 1. KLAIM PLAYTIME REWARDS
                if ptFrame and ptFrame:FindFirstChild("RewardsFrame") then
                    local rewardsFolder = ptFrame.RewardsFrame
                    for i = 1, 11 do
                        if not running then break end
                        local rewardBox = rewardsFolder:FindFirstChild("Reward" .. tostring(i))
                        if rewardBox then
                            local isClaimed = rewardBox:FindFirstChild("Claimed") or rewardBox:FindFirstChild("Checkmark") or rewardBox:FindFirstChild("Tick")
                            local claimFrame = rewardBox:FindFirstChild("Claim")

                            if claimFrame and claimFrame.Visible and not isClaimed then
                                local btn = claimFrame:FindFirstChild("Button")
                                clickButton(btn)
                                task.wait(0.15)
                            end
                        end
                    end
                end

                -- 2. KLAIM DAILY REWARDS
                if ptFrame and ptFrame:FindFirstChild("DailyFrame") then
                    local dailyRewardsFolder = ptFrame.DailyFrame:FindFirstChild("DailyRewardsFrame")
                    if dailyRewardsFolder then
                        for i = 1, 6 do
                            if not running then break end
                            local rewardBox = dailyRewardsFolder:FindFirstChild("Reward" .. tostring(i))
                            if rewardBox then
                                local isClaimed = rewardBox:FindFirstChild("Claimed") or rewardBox:FindFirstChild("Checkmark")
                                local claimFrame = rewardBox:FindFirstChild("Claim")
                                if claimFrame and claimFrame.Visible and not isClaimed then
                                    local btn = claimFrame:FindFirstChild("Button")
                                    clickButton(btn)
                                    task.wait(0.15)
                                end
                            end
                        end
                    end

                    local finalBox = ptFrame.DailyFrame:FindFirstChild("FinalReward")
                    if finalBox then
                        local isClaimed = finalBox:FindFirstChild("Claimed") or finalBox:FindFirstChild("Checkmark")
                        local claimFrame = finalBox:FindFirstChild("Claim")
                        if claimFrame and claimFrame.Visible and not isClaimed then
                            local btn = claimFrame:FindFirstChild("Button")
                            clickButton(btn)
                        end
                    end
                end
            end)

            task.wait(60) -- Scan klaim setiap 60 detik
        end
    end)
end

function AutoClaim.Stop()
    running = false
    print("🛑 [Ritod Hub] Smart Auto Claim Dimatikan.")
end

return AutoClaim

