local AutoClaim = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local MainGui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainGui")

local running = false

function AutoClaim.Start()
    if running then return end
    running = true
    print("🎁 [Ritod Hub] Smart Auto Claim Active...")

    task.spawn(function()
        while running do
            pcall(function()
                local ptFrame = MainGui.Root.Frames:FindFirstChild("PlaytimeRewards")

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
                                if btn and typeof(firesignal) == "function" then
                                    firesignal(btn.MouseButton1Click)
                                    firesignal(btn.Activated)
                                end
                                task.wait(0.1)
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
                                    if btn and typeof(firesignal) == "function" then
                                        firesignal(btn.MouseButton1Click)
                                        firesignal(btn.Activated)
                                    end
                                    task.wait(0.1)
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
                            if btn and typeof(firesignal) == "function" then
                                firesignal(btn.MouseButton1Click)
                                firesignal(btn.Activated)
                            end
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
