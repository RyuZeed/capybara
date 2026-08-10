-- =================================================================
-- 🎁 RITOD HUB - SMART AUTO CLAIM (PLAYTIME, DAILY & QUEST ENGINE)
-- Game: Capybaras vs Plants
-- Features:
--   1. ⏳ Auto Claim Playtime / Online Rewards (1 - 12 Slots)
--   2. 📅 Auto Claim Daily Login Rewards (Day 1 - 7 + Bonus)
--   3. 📜 Auto Claim Quests (Daily Quests, Missions & Achievements)
--   4. ⚡ Universal UI Hunter + Direct Remote Sweeper
-- =================================================================

local AutoClaim = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

AutoClaim.Config = {
    PlaytimeDaily = true,
    Quest         = true,
}

local running = false
local claimThread = nil
local lastRemoteSweep = 0

-- =================================================================
-- 🛠️ HELPER FUNCTIONS & UNIVERSAL BUTTON CLICKER
-- =================================================================

local function getRemotesFolder()
    return ReplicatedStorage:FindFirstChild("Remotes") 
        or ReplicatedStorage:FindFirstChild("Remotes", true)
        or ReplicatedStorage
end

local function callRemote(name, ...)
    local remotes = getRemotesFolder()
    local remote = (remotes and remotes:FindFirstChild(name)) or ReplicatedStorage:FindFirstChild(name, true)
    if remote then
        pcall(function(...)
            if remote:IsA("RemoteEvent") then
                remote:FireServer(...)
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(...)
            end
        end, ...)
        return true
    end
    return false
end

-- Memeriksa apakah GuiObject benar-benar visible hingga root ScreenGui
local function isGuiVisible(gui)
    if not gui or not gui:IsA("GuiObject") then return false end
    if not gui.Visible then return false end

    local current = gui.Parent
    while current and current ~= game and not current:IsA("ScreenGui") do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        current = current.Parent
    end

    if current and current:IsA("ScreenGui") and not current.Enabled then
        return false
    end

    return true
end

-- Universal Button Clicker (Mendukung Mobile Executors & PC)
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
            -- Touch Simulation
            pcall(function()
                VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.02)
                VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
            end)
            -- Mouse Simulation
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
-- 🔍 SMART REWARD STATUS DETECTOR (CLAIM vs CLAIMED vs LOCKED)
-- =================================================================

local function isClaimableButton(obj)
    if not obj then return false end
    if not (obj:IsA("GuiButton") or obj:IsA("TextButton") or obj:IsA("ImageButton")) then
        return false
    end

    -- Cek text pada tombol itu sendiri
    local btnText = ""
    if obj:IsA("TextButton") then
        btnText = (obj.Text or ""):lower():gsub("%s+", "")
    end

    -- Cek text pada child TextLabel
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("TextLabel") and child.Visible then
            local t = (child.Text or ""):lower():gsub("%s+", "")
            if t ~= "" then btnText = t end
        end
    end

    -- Cek apakah tulisan mengindikasikan claim
    if btnText:find("claim") or btnText:find("klaim") or btnText:find("collect") or btnText:find("ambil") or btnText:find("get") or btnText:find("ready") then
        if not (btnText:find("claimed") or btnText:find("terklaim") or btnText:find("sudah") or btnText:find("collected")) then
            return true
        end
    end

    -- Cek nama tombol jika namanya Claim / ClaimButton
    local bName = obj.Name:lower()
    if (bName == "claim" or bName == "claimbutton" or bName == "claimbtn" or bName == "btnclaim" or bName == "collectbutton") and obj.Visible then
        return true
    end

    return false
end

local function scanAndProcessCard(card, cardType)
    if not card or not card:IsA("GuiObject") then return false end

    -- 1. Cek apakah kartu sudah claimed
    local alreadyClaimed = false
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local txt = (desc.Text or ""):lower()
            if txt:find("claimed") or txt:find("terklaim") or txt:find("sudah") or txt:find("collected") then
                alreadyClaimed = true
                break
            end
        end
        local dName = desc.Name:lower()
        if (dName == "claimed" or dName == "check" or dName == "tick" or dName == "done") and desc:IsA("GuiObject") and desc.Visible then
            if desc:IsA("ImageLabel") and desc.ImageTransparency < 0.8 and desc.Image ~= "" then
                alreadyClaimed = true
                break
            elseif desc:IsA("Frame") and desc.BackgroundTransparency < 0.8 then
                alreadyClaimed = true
                break
            end
        end
    end

    if alreadyClaimed then
        return false
    end

    -- 2. Cari tombol Claim di dalam kartu
    local claimBtn = nil
    for _, desc in ipairs(card:GetDescendants()) do
        if isClaimableButton(desc) and desc.Visible then
            claimBtn = desc
            break
        end
    end

    if not claimBtn and card:IsA("GuiButton") and isClaimableButton(card) then
        claimBtn = card
    end

    if claimBtn then
        print(string.format("🎁 [Auto Claim] Mengklaim %s (%s)!", tostring(cardType), tostring(card.Name)))
        clickButton(claimBtn)
        task.wait(0.1)
        return true
    end

    return false
end

-- =================================================================
-- ⏳ 1. PLAYTIME REWARDS SCANNER
-- =================================================================
local function scanPlaytimeGifts()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    -- Scan semua ScreenGui untuk mencari Frame Playtime
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                local dName = desc.Name:lower()
                if (dName:find("playtime") or dName:find("online") or dName:find("timegift") or dName:find("freegift")) and desc:IsA("GuiObject") then
                    for _, rewardItem in ipairs(desc:GetDescendants()) do
                        if rewardItem:IsA("GuiObject") and (rewardItem.Name:lower():find("reward") or tonumber(rewardItem.Name) ~= nil or rewardItem.Name:lower():find("slot") or rewardItem.Name:lower():find("gift")) then
                            scanAndProcessCard(rewardItem, "Playtime Gift")
                        end
                    end
                end
            end
        end
    end
end

-- =================================================================
-- 📅 2. DAILY LOGIN REWARDS SCANNER
-- =================================================================
local function scanDailyRewards()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                local dName = desc.Name:lower()
                if (dName:find("daily") or dName:find("loginreward") or dName:find("7day") or dName:find("dayreward")) and desc:IsA("GuiObject") then
                    for _, dayItem in ipairs(desc:GetDescendants()) do
                        if dayItem:IsA("GuiObject") and (dayItem.Name:lower():find("day") or dayItem.Name:lower():find("reward") or tonumber(dayItem.Name) ~= nil or dayItem.Name:lower():find("final")) then
                            scanAndProcessCard(dayItem, "Daily Reward")
                        end
                    end
                end
            end
        end
    end
end

-- =================================================================
-- 📜 3. QUESTS SCANNER (DAILY QUESTS & ACHIEVEMENTS)
-- =================================================================
local function scanQuests()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                local dName = desc.Name:lower()
                if (dName:find("quest") or dName:find("task") or dName:find("achievement") or dName:find("mission")) and desc:IsA("GuiObject") then
                    -- 1. Cari tombol "Claim All" / "Klaim Semua"
                    for _, btn in ipairs(desc:GetDescendants()) do
                        if btn:IsA("GuiButton") and btn.Visible then
                            local bText = (btn:IsA("TextButton") and btn.Text or ""):lower():gsub("%s+", "")
                            for _, l in ipairs(btn:GetChildren()) do
                                if l:IsA("TextLabel") and l.Visible then
                                    local lt = (l.Text or ""):lower():gsub("%s+", "")
                                    if lt ~= "" then bText = lt end
                                end
                            end
                            if bText:find("claimall") or bText:find("klaimsemua") or bText:find("collectall") then
                                print("📜 [Auto Claim] Menekan tombol Claim All Quests!")
                                clickButton(btn)
                                task.wait(0.2)
                            end
                        end
                    end

                    -- 2. Scan setiap item quest di dalam list
                    for _, questItem in ipairs(desc:GetDescendants()) do
                        if questItem:IsA("GuiObject") and (questItem.Name:lower():find("quest") or questItem.Name:lower():find("task") or questItem.Name:lower():find("item") or tonumber(questItem.Name) ~= nil or questItem.Name:lower():find("card") or questItem.Name:lower():find("row")) then
                            scanAndProcessCard(questItem, "Quest")
                        end
                    end
                end
            end
        end
    end
end

-- =================================================================
-- ⚡ 4. DIRECT REMOTE SWEEPER (BACKUP ENGINE)
-- =================================================================
local function sweepDirectRemotes()
    local now = tick()
    if now - lastRemoteSweep < 4 then return end
    lastRemoteSweep = now

    local remotes = getRemotesFolder()
    if not remotes then return end

    -- Direct Playtime Remotes
    if AutoClaim.Config.PlaytimeDaily then
        for i = 1, 12 do
            callRemote("ClaimPlaytimeReward", i)
            callRemote("ClaimPlaytimeReward", "Reward" .. tostring(i))
            callRemote("ClaimPlaytime", i)
            callRemote("ClaimPlaytime", "Reward" .. tostring(i))
            callRemote("ClaimReward", i)
            callRemote("ClaimFreeGift", i)
            callRemote("ClaimTimeReward", i)
        end

        -- Direct Daily Remotes
        for i = 1, 7 do
            callRemote("ClaimDailyReward", i)
            callRemote("ClaimDailyReward", "Reward" .. tostring(i))
            callRemote("ClaimDailyReward", "Day" .. tostring(i))
            callRemote("ClaimDaily", i)
            callRemote("ClaimDay", i)
            callRemote("ClaimDailyGift", i)
        end
        callRemote("ClaimDailyReward", "FinalReward")
        callRemote("ClaimFinalReward")
    end

    -- Direct Quest Remotes
    if AutoClaim.Config.Quest then
        callRemote("ClaimAllQuests")
        callRemote("ClaimAllDailyQuests")
        callRemote("ClaimQuests")
        for i = 1, 15 do
            callRemote("ClaimQuest", i)
            callRemote("ClaimQuest", "Quest" .. tostring(i))
            callRemote("ClaimQuestReward", i)
            callRemote("ClaimQuestReward", "Quest" .. tostring(i))
            callRemote("CompleteQuest", i)
            callRemote("ClaimTask", i)
            callRemote("ClaimAchievement", i)
            callRemote("ClaimDailyQuest", i)
        end
    end
end

-- =================================================================
-- 🚀 MAIN LOOP CONTROLLER
-- =================================================================

function AutoClaim.Start()
    if running then return end
    running = true
    print("🎁 [Ritod Hub] Smart Auto Claim (Playtime, Daily & Quest) Aktif!")

    claimThread = task.spawn(function()
        while running do
            pcall(function()
                if AutoClaim.Config.PlaytimeDaily then
                    scanPlaytimeGifts()
                    scanDailyRewards()
                end

                if AutoClaim.Config.Quest then
                    scanQuests()
                end

                -- Jalankan remote sweep sebagai backup
                sweepDirectRemotes()
            end)

            task.wait(1.5)
        end
    end)
end

function AutoClaim.Stop()
    running = false
    if claimThread then
        task.cancel(claimThread)
        claimThread = nil
    end
    print("🛑 [Ritod Hub] Smart Auto Claim Dimatikan.")
end

function AutoClaim.Toggle(state)
    if state == nil then state = not running end
    if state then AutoClaim.Start() else AutoClaim.Stop() end
    return running
end

function AutoClaim.TogglePlaytimeDaily(state)
    AutoClaim.Config.PlaytimeDaily = state
    if not running and (AutoClaim.Config.PlaytimeDaily or AutoClaim.Config.Quest) then
        AutoClaim.Start()
    elseif running and not AutoClaim.Config.PlaytimeDaily and not AutoClaim.Config.Quest then
        AutoClaim.Stop()
    end
end

function AutoClaim.ToggleQuest(state)
    AutoClaim.Config.Quest = state
    if not running and (AutoClaim.Config.PlaytimeDaily or AutoClaim.Config.Quest) then
        AutoClaim.Start()
    elseif running and not AutoClaim.Config.PlaytimeDaily and not AutoClaim.Config.Quest then
        AutoClaim.Stop()
    end
end

return AutoClaim
