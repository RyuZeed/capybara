local AutoClaim = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local running = false

-- =================================================================
-- 🛠️ HELPER FUNCTIONS (MOBILE & PC READY)
-- =================================================================

local function getMainGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
    if not pg then return nil end
    return pg:FindFirstChild("MainGui") or pg:WaitForChild("MainGui", 5) or pg:FindFirstChildWhichIsA("ScreenGui")
end

local function getRemotes()
    return ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Remotes", true)
end

local function callRemote(name, ...)
    local remotes = getRemotes()
    local remote = remotes and remotes:FindFirstChild(name)
    if not remote then
        remote = ReplicatedStorage:FindFirstChild(name, true)
    end
    if remote then
        if remote:IsA("RemoteEvent") then
            return remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        end
    end
end

-- Universal Button Clicker (Mendukung Mobile Delta/Codex/Arceus & PC)
local function clickButton(btn)
    if not btn then return end

    -- 1. firesignal (Mobile/PC Executor)
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.Activated) end)
    end

    -- 2. getconnections
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

    -- 3. VirtualInputManager Touch/Mouse Simulation
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = math.floor(pos.X + size.X / 2)
        local cy = math.floor(pos.Y + size.Y / 2)

        if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
            -- Touch Simulation (Mobile)
            pcall(function()
                VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.02)
                VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
            end)
            -- Mouse Simulation (PC)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
        end
    end)

    -- 4. VirtualUser Fallback
    pcall(function()
        VirtualUser:CaptureController()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        VirtualUser:ClickButton1(Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2))
    end)
end

-- =================================================================
-- 🔍 SMART REWARD STATUS DETECTOR (CLAIM vs CLAIMED)
-- =================================================================

-- Memeriksa status box: "CLAIMED" (abaikan), "CLAIMABLE" (klaim sekarang), atau "LOCKED" (tunggu)
local function getRewardAction(box)
    if not box or not box:IsA("GuiObject") then return "LOCKED", nil end

    local isExplicitlyClaimed = false
    local claimButtonFound = nil
    local hasClaimText = false

    -- 1. Cek tanda atau tulisan CLAIMED terlebih dahulu
    for _, item in ipairs(box:GetDescendants()) do
        local itemName = item.Name:lower()

        -- Indikator Visual CLAIMED (Checkmark, Tick, Claimed Frame yang aktif/visible)
        if itemName == "claimed" or itemName:find("check") or itemName:find("tick") or itemName == "done" then
            if (item:IsA("GuiObject") and item.Visible) or (not item:IsA("GuiObject")) then
                isExplicitlyClaimed = true
                break
            end
        end

        -- Indikator Teks CLAIMED
        if item:IsA("TextLabel") or item:IsA("TextButton") then
            local txt = (item.Text or ""):lower()
            if txt:find("claimed") or txt:find("collected") or txt:find("terklaim") or txt:find("sudah") then
                isExplicitlyClaimed = true
                break
            end
        end
    end

    if isExplicitlyClaimed then
        return "CLAIMED", nil
    end

    -- 2. Cek apakah ada tulisan "CLAIM" atau tombol Claim yang aktif
    for _, item in ipairs(box:GetDescendants()) do
        if item:IsA("TextLabel") or item:IsA("TextButton") then
            local cleanText = (item.Text or ""):lower():gsub("%s+", "")
            if cleanText == "claim" or cleanText == "klaim" or cleanText == "collect" or cleanText == "ready" or cleanText == "get" then
                hasClaimText = true
                if item:IsA("TextButton") or item:IsA("ImageButton") then
                    claimButtonFound = item
                else
                    -- Cari tombol di parent atau child terdekat
                    claimButtonFound = item:FindFirstAncestorWhichIsA("GuiButton")
                        or (item.Parent and item.Parent:FindFirstChildWhichIsA("GuiButton"))
                        or (item.Parent and item.Parent:FindFirstChild("Button"))
                end
            end
        end

        -- Cek button/frame bernama Claim
        local iname = item.Name:lower()
        if (iname == "claim" or iname == "claimbutton") and item:IsA("GuiObject") and item.Visible then
            if item:IsA("GuiButton") then
                claimButtonFound = item
            else
                local innerBtn = item:FindFirstChild("Button") or item:FindFirstChildWhichIsA("GuiButton")
                if innerBtn then claimButtonFound = innerBtn end
            end
        end
    end

    -- Jika tulisan CLAIM atau tombol Claim aktif ditemukan
    if hasClaimText or claimButtonFound then
        if not claimButtonFound then
            claimButtonFound = box:FindFirstChild("Claim", true) or box:FindFirstChildWhichIsA("GuiButton", true)
        end
        return "CLAIMABLE", claimButtonFound
    end

    return "LOCKED", nil
end

-- =================================================================
-- 🚀 AUTO CLAIM SCANNER & EXECUTOR
-- =================================================================

local function processRewardBox(box, index, rewardType)
    if not box then return end

    local status, buttonToClick = getRewardAction(box)

    if status == "CLAIMED" then
        -- Sudah di-claim, TIDAK PERLU diklaim lagi
        return
    elseif status == "CLAIMABLE" then
        print(string.format("🎁 [Auto Claim] Mendeteksi tulisan CLAIM pada %s #%s -> Langsung Mengklaim!", tostring(rewardType), tostring(index or "?")))
        
        -- 1. Klik tombol UI secara otomatis
        if buttonToClick then
            clickButton(buttonToClick)
            task.wait(0.1)
        end

        -- 2. Backup Remote Call (Playtime & Daily)
        if rewardType == "Playtime" and index then
            callRemote("ClaimPlaytimeReward", index)
            callRemote("ClaimPlaytime", index)
            callRemote("ClaimReward", index)
        elseif rewardType == "Daily" and index then
            callRemote("ClaimDailyReward", index)
            callRemote("ClaimDaily", index)
        elseif rewardType == "FinalDaily" then
            callRemote("ClaimDailyReward", 7)
            callRemote("ClaimFinalReward")
        end
    end
end

function AutoClaim.Start()
    if running then return end
    running = true
    print("🎁 [Ritod Hub] Smart Auto Claim Berjalan (Real-time Instant Claim)...")

    task.spawn(function()
        while running do
            pcall(function()
                local mainGui = getMainGui()
                if not mainGui or not mainGui:FindFirstChild("Root") or not mainGui.Root:FindFirstChild("Frames") then
                    return
                end

                local ptFrame = mainGui.Root.Frames:FindFirstChild("PlaytimeRewards")
                if not ptFrame then
                    ptFrame = mainGui:FindFirstChild("PlaytimeRewards", true)
                end

                if ptFrame then
                    -- 1. SCAN PLAYTIME REWARDS (Reward 1 - 12+)
                    local rewardsFolder = ptFrame:FindFirstChild("RewardsFrame") or ptFrame:FindFirstChild("Rewards")
                    if rewardsFolder then
                        for i = 1, 15 do
                            if not running then break end
                            local rewardBox = rewardsFolder:FindFirstChild("Reward" .. tostring(i)) or rewardsFolder:FindFirstChild(tostring(i))
                            if rewardBox then
                                processRewardBox(rewardBox, i, "Playtime")
                            end
                        end
                    end

                    -- 2. SCAN DAILY REWARDS (Reward 1 - 7)
                    local dailyFrame = ptFrame:FindFirstChild("DailyFrame") or ptFrame:FindFirstChild("Daily")
                    if dailyFrame then
                        local dailyFolder = dailyFrame:FindFirstChild("DailyRewardsFrame") or dailyFrame:FindFirstChild("RewardsFrame") or dailyFrame
                        for i = 1, 7 do
                            if not running then break end
                            local rewardBox = dailyFolder:FindFirstChild("Reward" .. tostring(i)) or dailyFolder:FindFirstChild(tostring(i))
                            if rewardBox then
                                processRewardBox(rewardBox, i, "Daily")
                            end
                        end

                        -- Final Reward (Day 7 / Bonus)
                        local finalBox = dailyFrame:FindFirstChild("FinalReward") or dailyFrame:FindFirstChild("Reward7")
                        if finalBox then
                            processRewardBox(finalBox, 7, "FinalDaily")
                        end
                    end
                end

                -- 3. SCAN GENERAL REWARD CONTAINERS (Jika ada event popup / Free Gifts)
                local freeGifts = mainGui.Root.Frames:FindFirstChild("FreeGifts") or mainGui.Root.Frames:FindFirstChild("Gifts")
                if freeGifts then
                    for _, child in ipairs(freeGifts:GetChildren()) do
                        if child:IsA("GuiObject") and child.Name:find("Reward") then
                            processRewardBox(child, child.Name, "FreeGift")
                        end
                    end
                end
            end)

            -- Scan interval cepat (1.5 detik) agar saat tulisan berubah jadi "CLAIM", langsung otomatis ter-klaim seketika
            task.wait(1.5)
        end
    end)
end

function AutoClaim.Stop()
    running = false
    print("🛑 [Ritod Hub] Smart Auto Claim Dimatikan.")
end

return AutoClaim
