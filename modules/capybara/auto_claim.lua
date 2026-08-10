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

local clickedDebounce = {}

-- Memeriksa apakah kartu dalam kondisi locked (countdown timer aktif atau progress belum 100%)
local function isCardLockedOrIncomplete(card)
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Visible then
            local txt = desc.Text or ""
            local clean = txt:gsub("%s+", ""):lower()

            -- 1. Cek countdown timer (e.g. "05:20", "12:00:00", "01:30")
            if clean:match("^%d+:%d+$") or clean:match("^%d+:%d+:%d+$") then
                return true, "Countdown Timer Active (" .. txt .. ")"
            end

            -- 2. Cek teks progress fraksi (e.g. "0/5", "2/10", "3/10")
            local cur, max = clean:match("(%d+)%s*/%s*(%d+)")
            if cur and max then
                local nCur = tonumber(cur)
                local nMax = tonumber(max)
                if nCur and nMax and nMax > 0 and nCur < nMax then
                    return true, string.format("Progress Incomplete (%d/%d)", nCur, nMax)
                end
            end

            -- 3. Cek persentase (e.g. "50%", "0%")
            local pct = clean:match("(%d+)%%")
            if pct then
                local nPct = tonumber(pct)
                if nPct and nPct < 100 then
                    return true, string.format("Percentage Incomplete (%d%%)", nPct)
                end
            end

            -- 4. Cek teks locked eksplisit
            if clean:find("locked") or clean:find("cooldown") or clean:find("terkunci") or clean:find("inprogress") or clean:find("belum") then
                return true, "Explicitly Locked"
            end
        end
    end
    return false, nil
end

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

    -- Tombol HARUS memiliki teks eksplisit Claim / Klaim / Collect / Get / Ready
    if btnText == "claim" or btnText == "klaim" or btnText == "collect" or btnText == "ambil" or btnText == "get" or btnText == "ready" then
        return true
    end

    -- Jika nama tombol adalah Claim / ClaimButton dan memiliki teks yang valid (bukan angka/timer/in-progress)
    local bName = obj.Name:lower()
    if (bName == "claim" or bName == "claimbutton" or bName == "claimbtn" or bName == "btnclaim" or bName == "collectbutton") and obj.Visible then
        if not (btnText:find("/") or btnText:find(":") or btnText:find("claimed") or btnText:find("terklaim") or btnText:find("sudah")) then
            return true
        end
    end

    return false
end

local function scanAndProcessCard(card, cardType)
    if not card or not card:IsA("GuiObject") then return false end

    -- 1. Cek Debounce (Jangan spam klik kartu yang sama dalam 8 detik)
    local cardKey = card:GetDebugId() or tostring(card)
    local lastClick = clickedDebounce[cardKey] or 0
    if tick() - lastClick < 8 then
        return false
    end

    -- 2. Cek apakah kartu sudah claimed
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local txt = (desc.Text or ""):lower()
            if txt:find("claimed") or txt:find("terklaim") or txt:find("sudah") or txt:find("collected") then
                return false
            end
        end
        local dName = desc.Name:lower()
        if (dName == "claimed" or dName == "check" or dName == "tick" or dName == "done") and desc:IsA("GuiObject") and desc.Visible then
            if desc:IsA("ImageLabel") and desc.ImageTransparency < 0.8 and desc.Image ~= "" then
                return false
            elseif desc:IsA("Frame") and desc.BackgroundTransparency < 0.8 then
                return false
            end
        end
    end

    -- 3. Cek apakah kartu terkunci / progress belum selesai
    local isLocked, reason = isCardLockedOrIncomplete(card)
    if isLocked then
        return false
    end

    -- 4. Cari tombol Claim di dalam kartu
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
        clickedDebounce[cardKey] = tick()
        print(string.format("🎁 [Auto Claim] Mengklaim %s (%s) yang sudah siap!", tostring(cardType), tostring(card.Name)))
        clickButton(claimBtn)
        task.wait(0.15)
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

    local processed = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiObject") and not processed[desc] then
                    local dName = desc.Name:lower()
                    if (dName:find("playtime") or dName:find("online") or dName:find("timegift") or dName:find("freegift")) then
                        for _, rewardItem in ipairs(desc:GetDescendants()) do
                            if rewardItem:IsA("GuiObject") and not processed[rewardItem] then
                                local rName = rewardItem.Name:lower()
                                if rName:find("reward") or tonumber(rewardItem.Name) ~= nil or rName:find("slot") or rName:find("gift") or rName:find("item") then
                                    processed[rewardItem] = true
                                    scanAndProcessCard(rewardItem, "Playtime Gift")
                                end
                            end
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

    local processed = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiObject") and not processed[desc] then
                    local dName = desc.Name:lower()
                    if (dName:find("daily") or dName:find("loginreward") or dName:find("7day") or dName:find("dayreward")) then
                        for _, dayItem in ipairs(desc:GetDescendants()) do
                            if dayItem:IsA("GuiObject") and not processed[dayItem] then
                                local dyName = dayItem.Name:lower()
                                if dyName:find("day") or dyName:find("reward") or tonumber(dayItem.Name) ~= nil or dyName:find("final") or dyName:find("item") then
                                    processed[dayItem] = true
                                    scanAndProcessCard(dayItem, "Daily Reward")
                                end
                            end
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

    local processed = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiObject") and not processed[desc] then
                    local dName = desc.Name:lower()

                    -- 1. Deteksi tombol Claim All
                    if desc:IsA("GuiButton") and isClaimableButton(desc) then
                        local bText = (desc:IsA("TextButton") and desc.Text or ""):lower():gsub("%s+", "")
                        if bText:find("all") or dName:find("all") then
                            local bKey = desc:GetDebugId() or tostring(desc)
                            if not clickedDebounce[bKey] or tick() - clickedDebounce[bKey] > 8 then
                                clickedDebounce[bKey] = tick()
                                print("📜 [Auto Claim] Menekan tombol Claim All Quests!")
                                clickButton(desc)
                                task.wait(0.2)
                            end
                        end
                    end

                    -- 2. Deteksi Container Quest (DailyQuests, Achievements, dll)
                    if (dName:find("quest") or dName:find("task") or dName:find("achievement") or dName:find("mission")) then
                        for _, questItem in ipairs(desc:GetDescendants()) do
                            if questItem:IsA("GuiObject") and not processed[questItem] then
                                local qName = questItem.Name:lower()
                                -- Hanya proses kartu individual (bukan container frame/holder)
                                if not qName:find("holder") and not qName:find("list") and not qName:find("container") and not qName:find("frame") and not qName:find("main") then
                                    if qName:find("quest") or qName:find("task") or qName:find("item") or tonumber(questItem.Name) ~= nil or qName:find("card") or qName:find("row") then
                                        processed[questItem] = true
                                        scanAndProcessCard(questItem, "Quest")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- =================================================================
-- ⚡ 4. DYNAMIC REMOTE DISCOVERY & SWEEPER
-- =================================================================
local function sweepDirectRemotes()
    local now = tick()
    if now - lastRemoteSweep < 5 then return end
    lastRemoteSweep = now

    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local oName = obj.Name:lower()
                
                -- Playtime / Gifts Remotes
                if AutoClaim.Config.PlaytimeDaily and (oName:find("playtime") or oName:find("freegift") or oName:find("timereward")) then
                    for i = 1, 12 do
                        pcall(function()
                            if obj:IsA("RemoteEvent") then
                                obj:FireServer(i)
                                obj:FireServer("Reward" .. tostring(i))
                            elseif obj:IsA("RemoteFunction") then
                                obj:InvokeServer(i)
                            end
                        end)
                    end
                end

                -- Daily Remotes
                if AutoClaim.Config.PlaytimeDaily and (oName:find("daily") or oName:find("loginreward") or oName:find("dayreward")) then
                    for i = 1, 7 do
                        pcall(function()
                            if obj:IsA("RemoteEvent") then
                                obj:FireServer(i)
                                obj:FireServer("Day" .. tostring(i))
                            elseif obj:IsA("RemoteFunction") then
                                obj:InvokeServer(i)
                            end
                        end)
                    end
                    pcall(function()
                        if obj:IsA("RemoteEvent") then obj:FireServer("FinalReward") end
                    end)
                end

                -- Quest Remotes
                if AutoClaim.Config.Quest and (oName:find("quest") or oName:find("task") or oName:find("achievement") or oName:find("mission")) then
                    pcall(function()
                        if obj:IsA("RemoteEvent") then
                            obj:FireServer()
                            obj:FireServer("All")
                            obj:FireServer("Daily")
                            for i = 1, 10 do obj:FireServer(i) end
                        end
                    end)
                end
            end
        end
    end)
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

                -- Jalankan remote sweeper sebagai backup
                sweepDirectRemotes()
            end)

            task.wait(2.0)
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
