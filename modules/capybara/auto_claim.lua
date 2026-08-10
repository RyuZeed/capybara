--[[
	===============================================================
	⚡ RITOD HUB - SMART AUTO CLAIM ENGINE (STATE-DRIVEN)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES (SAME ARCHITECTURE AS AUTO BUY EGG):
	- 🛑 ZERO SPAM: Remote/Click TIDAK AKAN dikirim jika belum READY!
	- ⚡ SMART STATE-DRIVEN:
	  • 🟢 "READY"   -> Otomatis claim 1x saat hadiah/misi sudah siap.
	  • ⚪ "CLAIMED" -> Dilewati permanen, tidak akan mengklaim ulang.
	  • 🔴 "LOCKED"  -> Dilewati saat timer countdown aktif atau progress belum 100%.
	- 🎁 12 Playtime Online Gifts Tracker (00:00 Countdown Detector)
	- 📅 7-Day Login Rewards Tracker
	- 📜 Daily Quests, Missions & Achievements Tracker + Smart "Claim All"
	- 🤫 SILENT OPERATION: Bersih tanpa spam terminal/console.
	===============================================================
]]

local AutoClaim = {}
_G.AutoClaim = AutoClaim

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

AutoClaim.Config = {
    PlaytimeDaily = true, -- Auto Claim Playtime & Daily Login
    Quest         = true, -- Auto Claim Daily Quests & Missions
    CheckInterval = 1.5,  -- Interval pengecekan state (detik)
}

local isRunning = false
local loopThread = nil
local claimedHistory = {}  -- [cardKey] = true (Menyimpan item yang sudah terklaim)
local clickDebounce = {}   -- [cardKey] = timestamp (Cooldown klik per item)
local lastRemoteSweep = 0

-- =================================================================
-- 🛠️ HELPER FUNCTIONS & CLICK SIMULATOR
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

local function clickButton(btn)
    if not btn then return end

    -- 1. firesignal (Roblox Executor Signal Trigger)
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.Activated) end)
    end

    -- 2. getconnections (Direct Lua Event Dispatch)
    if typeof(getconnections) == "function" then
        for _, ev in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "TouchTap"}) do
            pcall(function()
                if btn[ev] then
                    for _, conn in ipairs(getconnections(btn[ev])) do
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

    -- 3. VirtualInputManager (Simulasi Touch & Mouse Hardware)
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = math.floor(pos.X + size.X / 2)
        local cy = math.floor(pos.Y + size.Y / 2)

        if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
            pcall(function()
                VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.02)
                VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
            end)
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
-- 🎯 STRICT REWARD STATE EVALUATOR ("Claim" vs "Claimed")
-- =================================================================

local function evaluateRewardCard(card)
    if not card or not card:IsA("GuiObject") then
        return "INVALID", nil
    end

    local cardKey = card:GetFullName()

    -- 1. Cek apakah sudah pernah diklaim di sesi ini
    if claimedHistory[cardKey] == true then
        return "CLAIMED", nil
    end

    -- 2. Cek apakah ada teks "Claimed" di dalam kartu
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local clean = (desc.Text or ""):gsub("<[^>]*>", ""):lower():gsub("%s+", "")
            if clean:find("claimed") or clean:find("terklaim") or clean:find("collected") or clean:find("sudah") then
                claimedHistory[cardKey] = true
                return "CLAIMED", nil
            end
        end

        -- Cek visual icon ceklis/claimed
        local dName = desc.Name:lower()
        if (dName == "claimed" or dName == "check" or dName == "tick" or dName == "done" or dName == "checkmark") and desc:IsA("GuiObject") then
            if (desc:IsA("ImageLabel") and desc.ImageTransparency < 0.8 and desc.Image ~= "") or (desc:IsA("Frame") and desc.BackgroundTransparency < 0.8) then
                claimedHistory[cardKey] = true
                return "CLAIMED", nil
            end
        end
    end

    -- 3. Cek apakah ada tombol / TextLabel bertuliskan "Claim"
    local claimBtn = nil
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("GuiButton") or desc:IsA("TextButton") or desc:IsA("ImageButton") then
            local btnTxt = (desc:IsA("TextButton") and desc.Text or ""):gsub("<[^>]*>", ""):lower():gsub("%s+", "")
            for _, c in ipairs(desc:GetChildren()) do
                if c:IsA("TextLabel") then
                    local ct = (c.Text or ""):gsub("<[^>]*>", ""):lower():gsub("%s+", "")
                    if ct ~= "" then btnTxt = ct end
                end
            end

            -- Jika bertuliskan "Claim" (dan bukan "Claimed")
            if btnTxt == "claim" or (btnTxt:find("claim") and not btnTxt:find("claimed")) then
                claimBtn = desc
                break
            end

            -- Jika nama tombolnya Claim dan bukan countdown
            local bName = desc.Name:lower()
            if (bName == "claim" or bName == "claimbutton" or bName == "claimbtn") and not (btnTxt:find(":") or btnTxt:find("claimed")) then
                claimBtn = desc
                break
            end
        end
    end

    -- Jika tombol tidak punya teks langsung, cek apakah ada TextLabel di dalam card bertuliskan "Claim"
    if not claimBtn then
        for _, desc in ipairs(card:GetDescendants()) do
            if desc:IsA("TextLabel") then
                local txt = (desc.Text or ""):gsub("<[^>]*>", ""):lower():gsub("%s+", "")
                if txt == "claim" or (txt:find("claim") and not txt:find("claimed")) then
                    local anyBtn = card:FindFirstChildWhichIsA("GuiButton", true) or card:FindFirstChildWhichIsA("TextButton", true) or card:FindFirstChildWhichIsA("ImageButton", true)
                    if anyBtn then
                        claimBtn = anyBtn
                        break
                    end
                end
            end
        end
    end

    if claimBtn then
        return "READY", claimBtn
    end

    return "LOCKED", nil
end

-- =================================================================
-- 📦 PROCESS CARD (EKSEKUSI KLAIM 1X BERSIH)
-- =================================================================

local function processRewardCard(card, cardType)
    local state, claimBtn = evaluateRewardCard(card)
    local cardKey = card:GetFullName()

    if state == "READY" and claimBtn then
        -- Cooldown per kartu (hindari spam klik ganda)
        local lastClick = clickDebounce[cardKey] or 0
        if tick() - lastClick > 4 then
            clickDebounce[cardKey] = tick()
            claimedHistory[cardKey] = true -- Langsung kunci permanen agar tidak pernah diklik ulang
            print(string.format("🎁 [Auto Claim] %s READY! Mengklaim (%s)...", tostring(cardType), tostring(card.Name)))
            
            -- Eksekusi 1x klik bersih pada tombol claim
            clickButton(claimBtn)
            return true
        end
    end

    return false
end

-- =================================================================
-- =================================================================
-- ⏳ 1. PLAYTIME REWARDS SCANNER (SERVER DATA + UI BACKUP)
-- =================================================================
local function scanPlaytimeRewards()
    -- 1. Direct Server Data
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local reqPlay = remotes:FindFirstChild("RequestPlaytime")
            local claimPlay = remotes:FindFirstChild("ClaimPlaytimeReward")
            if reqPlay and reqPlay:IsA("RemoteFunction") and claimPlay and claimPlay:IsA("RemoteEvent") then
                local playData = reqPlay:InvokeServer()
                if typeof(playData) == "table" then
                    for slotId, slotInfo in pairs(playData) do
                        if typeof(slotInfo) == "table" then
                            local isClaimed = slotInfo.Claimed or slotInfo.IsClaimed
                            local isReady = (not isClaimed) and (slotInfo.Ready or (slotInfo.TimeLeft and slotInfo.TimeLeft <= 0))
                            local cardKey = "RemotePlaytime_" .. tostring(slotId)
                            if isReady and not claimedHistory[cardKey] then
                                local lastClick = clickDebounce[cardKey] or 0
                                if tick() - lastClick > 4 then
                                    clickDebounce[cardKey] = tick()
                                    claimedHistory[cardKey] = true
                                    print(string.format("🎁 [Auto Claim] Playtime Gift READY (Slot %s)! Mengklaim...", tostring(slotId)))
                                    claimPlay:FireServer(slotId)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    -- 2. UI Fallback
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local processed = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and not gui.Name:lower():find("hub") then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiObject") and not processed[desc] then
                    local dName = desc.Name:lower()
                    if (dName:find("playtime") or dName:find("online") or dName:find("timegift") or dName:find("freegift") or dName:find("gift")) then
                        for _, item in ipairs(desc:GetDescendants()) do
                            if item:IsA("GuiObject") and not processed[item] then
                                local rName = item.Name:lower()
                                if rName:find("reward") or tonumber(item.Name) ~= nil or rName:find("slot") or rName:find("gift") or rName:find("item") then
                                    processed[item] = true
                                    processRewardCard(item, "Playtime Gift")
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
-- 📅 2. DAILY LOGIN REWARDS SCANNER (SERVER DATA + UI BACKUP)
-- =================================================================
local function scanDailyLoginRewards()
    -- 1. Direct Server Data
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local reqDaily = remotes:FindFirstChild("RequestDailyRewards")
            local claimDaily = remotes:FindFirstChild("ClaimDailyReward")
            if reqDaily and reqDaily:IsA("RemoteFunction") and claimDaily and claimDaily:IsA("RemoteEvent") then
                local dailyData = reqDaily:InvokeServer()
                if typeof(dailyData) == "table" then
                    for dayId, dayInfo in pairs(dailyData) do
                        if typeof(dayInfo) == "table" then
                            local isClaimed = dayInfo.Claimed or dayInfo.IsClaimed
                            local isReady = (not isClaimed) and (dayInfo.Ready or dayInfo.CanClaim)
                            local cardKey = "RemoteDaily_" .. tostring(dayId)
                            if isReady and not claimedHistory[cardKey] then
                                local lastClick = clickDebounce[cardKey] or 0
                                if tick() - lastClick > 4 then
                                    clickDebounce[cardKey] = tick()
                                    claimedHistory[cardKey] = true
                                    print(string.format("📅 [Auto Claim] Daily Login Reward READY (Day %s)! Mengklaim...", tostring(dayId)))
                                    claimDaily:FireServer(dayId)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    -- 2. UI Fallback
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local processed = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and not gui.Name:lower():find("hub") then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiObject") and not processed[desc] then
                    local dName = desc.Name:lower()
                    if (dName:find("daily") or dName:find("loginreward") or dName:find("7day") or dName:find("dayreward")) then
                        for _, dayItem in ipairs(desc:GetDescendants()) do
                            if dayItem:IsA("GuiObject") and not processed[dayItem] then
                                local dyName = dayItem.Name:lower()
                                if dyName:find("day") or dyName:find("reward") or tonumber(dayItem.Name) ~= nil or dyName:find("final") or dyName:find("item") then
                                    processed[dayItem] = true
                                    processRewardCard(dayItem, "Daily Login")
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
-- 📜 3. QUESTS SCANNER & AUTO-CLAIMER (DIRECT QUESTDATA ENGINE)
-- =================================================================

local function scanQuestsAndMissions()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end

    local claimQuest = remotes:FindFirstChild("ClaimQuest")
    local reqQuests = remotes:FindFirstChild("RequestQuests")
    if not claimQuest or not reqQuests then return end

    pcall(function()
        local serverData = reqQuests:InvokeServer()
        if typeof(serverData) ~= "table" then return end

        local lifetimeStats = serverData.LifetimeStats or {}
        local lifetimeClaimed = serverData.LifetimeClaimed or {}
        local daily = serverData.Daily or {}
        local dailyClaimed = daily.Claimed or {}
        local dailyProgress = daily.Progress or {}
        local dailyActive = daily.Active or {}

        -- Muat database resmi QuestData dari game
        local QuestData = nil
        pcall(function()
            local qdMod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("QuestData")
            if qdMod then QuestData = require(qdMod) end
        end)

        -- 1. PROSES LIFETIME QUESTS
        if QuestData and typeof(QuestData.Lifetime) == "table" then
            for _, levelObj in ipairs(QuestData.Lifetime) do
                if typeof(levelObj.Quests) == "table" then
                    for _, q in ipairs(levelObj.Quests) do
                        local qId = q.Id
                        local statName = q.Stat
                        local target = q.Target or 1
                        local currentStat = lifetimeStats[statName] or 0

                        -- Jika belum diklaim dan progress sudah mencapai target
                        if qId and not lifetimeClaimed[qId] and not claimedHistory[qId] then
                            if currentStat >= target then
                                local lastClick = clickDebounce[qId] or 0
                                if tick() - lastClick > 4 then
                                    clickDebounce[qId] = tick()
                                    claimedHistory[qId] = true
                                    print(string.format("🏆 [Auto Claim] Lifetime Quest READY: %s (%s) [%d/%d]! Mengklaim...", tostring(q.Label), tostring(qId), currentStat, target))
                                    
                                    task.spawn(function()
                                        pcall(function() claimQuest:InvokeServer(qId) end)
                                        pcall(function() claimQuest:InvokeServer("Lifetime", qId) end)
                                        pcall(function() claimQuest:InvokeServer(levelObj.Level or 1, qId) end)
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 2. PROSES DAILY QUESTS
        if QuestData and typeof(QuestData.Daily) == "table" then
            -- Buat map target harian dari QuestData
            local dailyMap = {}
            for _, dq in ipairs(QuestData.Daily) do
                if dq.Id then dailyMap[dq.Id] = dq end
            end

            for _, qId in ipairs(dailyActive) do
                if not dailyClaimed[qId] and not claimedHistory[qId] then
                    local dqInfo = dailyMap[qId]
                    local target = (dqInfo and dqInfo.Target) or 1
                    local curProg = dailyProgress[qId] or 0

                    if curProg >= target then
                        local lastClick = clickDebounce[qId] or 0
                        if tick() - lastClick > 4 then
                            clickDebounce[qId] = tick()
                            claimedHistory[qId] = true
                            print(string.format("📜 [Auto Claim] Daily Quest READY: %s (%s) [%d/%d]! Mengklaim...", tostring(dqInfo and dqInfo.Label or qId), tostring(qId), curProg, target))
                            
                            task.spawn(function()
                                pcall(function() claimQuest:InvokeServer(qId) end)
                                pcall(function() claimQuest:InvokeServer("Daily", qId) end)
                            end)
                        end
                    end
                end
            end

            -- Klaim Bonus Harian jika semua 3 misi selesai
            if (serverData.DailyClaimedCount or 0) >= 3 and daily.BonusClaimed == false and not claimedHistory["DailyBonus"] then
                local lastClick = clickDebounce["DailyBonus"] or 0
                if tick() - lastClick > 5 then
                    clickDebounce["DailyBonus"] = tick()
                    claimedHistory["DailyBonus"] = true
                    print("🎁 [Auto Claim] Daily Bonus READY! Mengklaim...")
                    task.spawn(function()
                        pcall(function() claimQuest:InvokeServer("Bonus") end)
                        pcall(function() claimQuest:InvokeServer("DailyBonus") end)
                        pcall(function() claimQuest:InvokeServer("Daily", "Bonus") end)
                    end)
                end
            end
        end
    end)

    -- 3. UI Backup Simulator (Menekan tombol UI jika masih ada yang tersisa)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        local mainGui = pg:FindFirstChild("MainGui")
        local questsFrame = mainGui and mainGui:FindFirstChild("Root") and mainGui.Root:FindFirstChild("Frames") and mainGui.Root.Frames:FindFirstChild("Quests")
        if questsFrame then
            for _, desc in ipairs(questsFrame:GetDescendants()) do
                if desc:IsA("GuiObject") and not desc:IsA("ScrollingFrame") then
                    local state, btn = evaluateQuestCard(desc)
                    if state == "READY" and btn then
                        local cardKey = desc:GetFullName()
                        local lastClick = clickDebounce[cardKey] or 0
                        if tick() - lastClick > 4 then
                            clickDebounce[cardKey] = tick()
                            claimedHistory[cardKey] = true
                            print(string.format("🖱️ [Auto Claim] UI Quest READY (%s)! Menekan tombol...", tostring(desc.Name)))
                            clickButton(btn)
                        end
                    end
                end
            end
        end
    end
end

-- =================================================================
-- 🚀 MAIN LOOP CONTROLLER (PURE STATE-DRIVEN)
-- =================================================================

function AutoClaim.Start()
    if isRunning then return end
    isRunning = true
    print("🎁 [Ritod Hub] Smart Auto Claim (State-Driven Engine) Aktif!")

    loopThread = task.spawn(function()
        while isRunning do
            pcall(function()
                if AutoClaim.Config.PlaytimeDaily then
                    scanPlaytimeRewards()
                    scanDailyLoginRewards()
                end

                if AutoClaim.Config.Quest then
                    scanQuestsAndMissions()
                end
            end)

            task.wait(AutoClaim.Config.CheckInterval or 1.5)
        end
    end)
end

function AutoClaim.Stop()
    isRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
    print("🛑 [Ritod Hub] Smart Auto Claim Dimatikan.")
end

function AutoClaim.Toggle(state)
    if state == nil then state = not isRunning end
    if state then AutoClaim.Start() else AutoClaim.Stop() end
    return isRunning
end

function AutoClaim.TogglePlaytimeDaily(state)
    AutoClaim.Config.PlaytimeDaily = state
    if not isRunning and (AutoClaim.Config.PlaytimeDaily or AutoClaim.Config.Quest) then
        AutoClaim.Start()
    elseif isRunning and not AutoClaim.Config.PlaytimeDaily and not AutoClaim.Config.Quest then
        AutoClaim.Stop()
    end
end

function AutoClaim.ToggleQuest(state)
    AutoClaim.Config.Quest = state
    if not isRunning and (AutoClaim.Config.PlaytimeDaily or AutoClaim.Config.Quest) then
        AutoClaim.Start()
    elseif isRunning and not AutoClaim.Config.PlaytimeDaily and not AutoClaim.Config.Quest then
        AutoClaim.Stop()
    end
end

-- Reset riwayat claimed jika player ingin memindai ulang secara manual
function AutoClaim.ResetHistory()
    claimedHistory = {}
    clickDebounce = {}
    print("🔄 [Auto Claim] Riwayat status claimed direset.")
end

return AutoClaim
