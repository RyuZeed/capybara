--[[
	===============================================================
	⚡ RITOD HUB - SMART AUTO CLAIM ENGINE (DUAL-ENGINE & EXACT DATA)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES & FIXES:
	- 📜 ACCURATE DATA-DRIVEN QUEST ENGINE:
	  • Membaca database resmi game (ReplicatedStorage.Modules.QuestData).
	  • Memverifikasi progress real-time dari RequestQuests (LifetimeStats & Daily.Progress).
	  • Mengklaim otomatis Lifetime Quests, Tree Level Rewards, Daily Quests, dan Daily 3/3 Bonus.
	- 🎁 PLAYTIME & DAILY LOGIN ENGINE:
	  • UI Scanner & Data Scanner yang stabil, akurat, dan zero-spam.
	- 🛑 ZERO SPAM & STRICT COOLDOWN:
	  • Tidak ada blind remote call acak.
	  • Item yang berstatus CLAIMED langsung dicatat permanen dalam sesi permainan.
	- 🖱️ Multi-Vector Hardware/Event Click Dispatcher (firesignal + getconnections + VIM + VirtualUser + Activate)
	===============================================================
]]

local AutoClaim = {}
_G.AutoClaim = AutoClaim

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

AutoClaim.Config = {
    PlaytimeDaily = true, -- Auto Claim Playtime & Daily Login
    Quest         = true, -- Auto Claim Daily Quests & Lifetime Quests
    CheckInterval = 3,    -- Interval pengecekan (detik)
}

local isRunning        = false
local loopThread       = nil
local claimedHistory   = {} -- [key] = true (Tercatat permanen jika sudah CLAIMED)
local clickDebounce    = {} -- [key] = timestamp (Cooldown klik per item)
local lastRemoteSweep  = 0

-- =================================================================
-- 🛠️ MULTI-VECTOR HARDWARE & EVENT CLICK DISPATCHER
-- =================================================================

local function clickButton(btn)
    if not btn or not btn:IsA("GuiObject") then return end

    -- 1. firesignal (Roblox Executor Signal Dispatch)
    if typeof(firesignal) == "function" then
        if btn:IsA("GuiButton") then
            if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
            if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
            if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
            if btn.MouseButton1Up then pcall(function() firesignal(btn.MouseButton1Up) end) end
            if btn.TouchTap then pcall(function() firesignal(btn.TouchTap) end) end
        end
    end

    -- 2. getconnections (Direct Lua Event Dispatch)
    if typeof(getconnections) == "function" then
        for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "TouchTap"}) do
            pcall(function()
                if btn[evName] then
                    local conns = getconnections(btn[evName])
                    if conns then
                        for _, conn in ipairs(conns) do
                            if conn.Function then
                                conn.Function()
                            elseif conn.Fire then
                                conn:Fire()
                            end
                        end
                    end
                end
            end)
        end
    end

    -- 3. VirtualInputManager (Simulasi Hardware Mouse & Touch di Center Titik Tombol)
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        if size.X > 0 and size.Y > 0 then
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
        end
    end)

    -- 4. VirtualUser Fallback
    pcall(function()
        if VirtualUser then
            VirtualUser:CaptureController()
            local pos = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            if size.X > 0 and size.Y > 0 then
                VirtualUser:ClickButton1(Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2))
            end
        end
    end)

    -- 5. GuiObject:Activate() method fallback
    pcall(function()
        if typeof(btn.Activate) == "function" then
            btn:Activate()
        end
    end)
end

-- =================================================================
-- 🔍 HELPER: STRING CLEANER & TEMPLATE DETECTOR
-- =================================================================

local function cleanString(str)
    if not str then return "" end
    return str:gsub("<[^>]*>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function isTemplateObject(obj)
    if not obj then return true end

    -- Jika berada di dalam folder khusus templates non-aktif
    if obj.Parent and (obj.Parent.Name:lower() == "templates" or obj.Parent.Name:lower() == "template") then
        return true
    end

    -- Jika object tersembunyi dan murni template
    if obj:IsA("GuiObject") and not obj.Visible and (obj.Name == "DailyQuestTemplate" or obj.Name == "RewardTemplate") then
        return true
    end

    return false
end

local function extractButtonText(btn)
    if not btn then return "" end
    local texts = {}
    if btn:IsA("TextButton") and btn.Text and btn.Text ~= "" then
        table.insert(texts, cleanString(btn.Text))
    end
    for _, desc in ipairs(btn:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and desc.Text ~= "" then
            table.insert(texts, cleanString(desc.Text))
        end
    end
    return table.concat(texts, " ")
end

local function isClaimReadyKeyword(txt)
    local upper = txt:upper():gsub("%s+", "")
    if upper == "CLAIM" or upper == "COLLECT" or upper == "CLAIMALL" or upper == "REDEEM"
       or upper == "FREE" or upper == "GET" or upper == "TAKE" or upper == "READY"
       or upper == "CLAIMREWARD" or upper == "COLLECTREWARD" or upper == "CLAIMNOW"
       or upper == "00:00" or upper == "0:00" then
        return true
    end
    if (upper:find("CLAIM") or upper:find("COLLECT") or upper:find("REDEEM")) and not upper:find("CLAIMED") and not upper:find("COLLECTED") then
        return true
    end
    return false
end

local function isClaimedKeyword(txt)
    local upper = txt:upper():gsub("%s+", "")
    if upper == "CLAIMED" or upper == "COLLECTED" or upper == "TERKLAIM" or upper == "SUDAH"
       or upper == "OBTAINED" or upper == "RECEIVED" or upper == "DONE" or upper == "COMPLETED" then
        return true
    end
    if upper:find("CLAIMED") or upper:find("COLLECTED") or upper:find("TERKLAIM") then
        return true
    end
    return false
end

local function isLockedKeyword(txt)
    local upper = txt:upper():gsub("%s+", "")
    if upper == "LOCKED" or upper == "LOCK" or upper == "TERKUNCI" or upper == "WAIT" or upper == "COOLDOWN" then
        return true
    end
    if upper:find("LOCKED") or upper:find("TERKUNCI") or upper:find("COOLDOWN") then
        return true
    end
    return false
end

-- =================================================================
-- 🎯 REWARD CARD EVALUATOR (PLAYTIME & DAILY UI)
-- =================================================================

local function evaluateRewardCard(card)
    if not card or not card:IsA("GuiObject") then return "INVALID", nil, "" end
    if isTemplateObject(card) then return "INVALID", nil, "" end

    local cardKey = card:GetFullName()
    if claimedHistory[cardKey] then return "CLAIMED", nil, "" end

    local allTexts = {}
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local t = cleanString(desc.Text)
            if t ~= "" then table.insert(allTexts, t) end
        end
    end
    if card:IsA("TextButton") and card.Text and card.Text ~= "" then
        table.insert(allTexts, cleanString(card.Text))
    end
    local combinedText = table.concat(allTexts, " ")
    local upperCombined = combinedText:upper():gsub("%s+", "")

    if isClaimedKeyword(upperCombined) then
        claimedHistory[cardKey] = true
        return "CLAIMED", nil, ""
    end

    for _, desc in ipairs(card:GetDescendants()) do
        local dName = desc.Name:lower()
        if (dName:find("claimed") or dName:find("check") or dName:find("tick") or dName == "done") and desc:IsA("GuiObject") then
            if (desc:IsA("ImageLabel") and desc.ImageTransparency < 0.5 and desc.Image ~= "")
               or (desc:IsA("Frame") and desc.BackgroundTransparency < 0.5 and desc.Visible) then
                claimedHistory[cardKey] = true
                return "CLAIMED", nil, ""
            end
        end
    end

    if isLockedKeyword(upperCombined) then
        return "LOCKED", nil, ""
    end

    for _, desc in ipairs(card:GetDescendants()) do
        local dName = desc.Name:lower()
        if dName:find("lock") and desc:IsA("ImageLabel") and desc.ImageTransparency < 0.5 and desc.Image ~= "" then
            return "LOCKED", nil, ""
        end
    end

    local hasActiveCountdown = false
    local hasExplicitZeroTime = false
    for _, txt in ipairs(allTexts) do
        local min, sec = txt:match("(%d+)%s*:%s*(%d+)")
        if min and sec then
            local nMin, nSec = tonumber(min), tonumber(sec)
            if (nMin and nMin > 0) or (nSec and nSec > 0) then
                hasActiveCountdown = true
            elseif (nMin == 0 and nSec == 0) then
                hasExplicitZeroTime = true
            end
        end
        if (txt:match("%d+%s*m") or txt:match("%d+%s*s") or txt:match("%d+%s*h")) then
            if not (txt:find("0s") or txt:find("00:00") or txt:lower():find("ready") or txt:lower():find("claim")) then
                hasActiveCountdown = true
            end
        end
    end

    if hasActiveCountdown and not hasExplicitZeroTime then
        return "LOCKED", nil, ""
    end

    local isExplicitlyReady = false
    for _, txt in ipairs(allTexts) do
        if isClaimReadyKeyword(txt) then
            isExplicitlyReady = true
            break
        end
    end

    if not isExplicitlyReady then
        return "LOCKED", nil, ""
    end

    local targetBtn = nil
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("GuiButton") and not isTemplateObject(desc) then
            local btnTxt = extractButtonText(desc)
            if isClaimReadyKeyword(btnTxt) or isClaimReadyKeyword(desc.Name) then
                targetBtn = desc
                break
            end
        end
    end

    if not targetBtn and card:IsA("GuiButton") and not isTemplateObject(card) then
        targetBtn = card
    end

    if not targetBtn then
        targetBtn = card:FindFirstChildWhichIsA("GuiButton", true)
    end

    local rName = card.Name
    for _, t in ipairs(allTexts) do
        if #t > 2 and not isClaimReadyKeyword(t) and not isClaimedKeyword(t) and not isLockedKeyword(t) and not t:find(":") then
            rName = t
            break
        end
    end

    if targetBtn and isExplicitlyReady then
        return "READY", targetBtn, rName
    end

    return "LOCKED", nil, ""
end

-- =================================================================
-- 🚀 EKSEKUTOR KLAIM DENGAN COOLDOWN & ANTI-SPAM
-- =================================================================

local function tryClaim(btn, label, itemKey)
    local key = itemKey or btn:GetFullName()
    if claimedHistory[key] then return false end

    local now = tick()
    if now - (clickDebounce[key] or 0) > 5 then
        clickDebounce[key] = now
        print(string.format("🎁 [Auto Claim] %s READY! Mengklaim...", tostring(label)))
        clickButton(btn)
        return true
    end
    return false
end

-- =================================================================
-- 📜 QUEST ENGINE: DATA-DRIVEN & DIRECT REMOTES
-- =================================================================

-- Mengambil module QuestData resmi game
local function getQuestDataModule()
    local qdMod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("QuestData")
    if not qdMod then
        qdMod = ReplicatedStorage:FindFirstChild("QuestData", true)
    end
    if qdMod and qdMod:IsA("ModuleScript") then
        local success, res = pcall(function() return require(qdMod) end)
        if success and typeof(res) == "table" then
            return res
        end
    end
    return nil
end

local function processQuestsDataEngine()
    if not AutoClaim.Config.Quest then return end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        or ReplicatedStorage:FindFirstChild("Remotes", true)
        or ReplicatedStorage

    if not remotes then return end

    local reqQuests = remotes:FindFirstChild("RequestQuests") or remotes:FindFirstChild("GetQuests")
    local claimQuest = remotes:FindFirstChild("ClaimQuest")
        or remotes:FindFirstChild("ClaimDailyQuest")
        or remotes:FindFirstChild("ClaimLifetimeQuest")
        or remotes:FindFirstChild("ClaimQuests")

    if not reqQuests or not claimQuest then return end

    local function fireClaimQuest(...)
        local args = {...}
        if claimQuest:IsA("RemoteFunction") then
            pcall(function() claimQuest:InvokeServer(unpack(args)) end)
        elseif claimQuest:IsA("RemoteEvent") then
            pcall(function() claimQuest:FireServer(unpack(args)) end)
        end
    end

    pcall(function()
        local serverData = nil
        if reqQuests:IsA("RemoteFunction") then
            serverData = reqQuests:InvokeServer()
        end

        if typeof(serverData) ~= "table" then return end

        local lifetimeStats = serverData.LifetimeStats or serverData.lifetime_stats or serverData.Stats or {}
        local lifetimeClaimed = serverData.LifetimeClaimed or serverData.lifetime_claimed or serverData.ClaimedLifetime or {}
        local daily = serverData.Daily or serverData.daily or {}
        local dailyClaimed = daily.Claimed or daily.claimed or serverData.DailyClaimed or {}
        local dailyProgress = daily.Progress or daily.progress or serverData.DailyProgress or {}
        local dailyActive = daily.Active or daily.active or serverData.DailyActive or {}

        local QuestData = getQuestDataModule()

        -- 1. 🏆 PROSES LIFETIME QUESTS
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
                                    print(string.format("🏆 [Auto Claim] Lifetime Quest READY: %s (%s) [%d/%d]! Mengklaim...", tostring(q.Label or qId), tostring(qId), currentStat, target))
                                    
                                    task.spawn(function()
                                        fireClaimQuest(qId)
                                        fireClaimQuest("Lifetime", qId)
                                        fireClaimQuest(levelObj.Level or 1, qId)
                                    end)
                                end
                            end
                        end
                    end
                end

                -- Klaim Tree Level Final Reward (misal: Magic Egg / Trophy per Level)
                local lvl = levelObj.Level or 1
                local allQuestsDone = true
                if typeof(levelObj.Quests) == "table" and #levelObj.Quests > 0 then
                    for _, q in ipairs(levelObj.Quests) do
                        if not lifetimeClaimed[q.Id] then
                            allQuestsDone = false
                            break
                        end
                    end
                else
                    allQuestsDone = false
                end

                local lvlRewardKey = "LevelReward_" .. tostring(lvl)
                local isRewardClaimed = false
                if typeof(serverData.LevelRewardClaimed) == "table" then
                    for _, rLvl in pairs(serverData.LevelRewardClaimed) do
                        if rLvl == lvl or rLvl == tostring(lvl) then
                            isRewardClaimed = true
                        end
                    end
                end

                if allQuestsDone and not isRewardClaimed and not claimedHistory[lvlRewardKey] then
                    local lastClick = clickDebounce[lvlRewardKey] or 0
                    if tick() - lastClick > 5 then
                        clickDebounce[lvlRewardKey] = tick()
                        claimedHistory[lvlRewardKey] = true
                        print(string.format("🌟 [Auto Claim] Tree Level %d Final Reward READY! Mengklaim...", lvl))
                        task.spawn(function()
                            fireClaimQuest(lvl)
                            fireClaimQuest("Level", lvl)
                            fireClaimQuest("LevelReward", lvl)
                        end)
                    end
                end
            end
        end

        -- 2. 📜 PROSES DAILY QUESTS
        if QuestData and typeof(QuestData.Daily) == "table" then
            local dailyMap = {}
            for _, dq in ipairs(QuestData.Daily) do
                if dq.Id then dailyMap[dq.Id] = dq end
            end

            -- Jika dailyActive berupa array daftar ID misi aktif hari ini
            local activeList = (typeof(dailyActive) == "table" and #dailyActive > 0) and dailyActive or QuestData.Daily
            for _, item in pairs(activeList) do
                local qId = (typeof(item) == "table" and item.Id) or item
                if qId and not dailyClaimed[qId] and not claimedHistory[qId] then
                    local dqInfo = dailyMap[qId] or (typeof(item) == "table" and item)
                    local target = (dqInfo and dqInfo.Target) or 1
                    local curProg = dailyProgress[qId] or (dailyProgress[tostring(qId)]) or 0

                    if curProg >= target then
                        local lastClick = clickDebounce[qId] or 0
                        if tick() - lastClick > 4 then
                            clickDebounce[qId] = tick()
                            claimedHistory[qId] = true
                            print(string.format("📜 [Auto Claim] Daily Quest READY: %s (%s) [%d/%d]! Mengklaim...", tostring(dqInfo and dqInfo.Label or qId), tostring(qId), curProg, target))
                            
                            task.spawn(function()
                                fireClaimQuest(qId)
                                fireClaimQuest("Daily", qId)
                            end)
                        end
                    end
                end
            end

            -- Klaim Bonus Harian jika seluruh misi harian selesai (3/3)
            local claimedCount = serverData.DailyClaimedCount or 0
            if claimedCount >= 3 and daily.BonusClaimed == false and not claimedHistory["DailyBonus"] then
                local lastClick = clickDebounce["DailyBonus"] or 0
                if tick() - lastClick > 5 then
                    clickDebounce["DailyBonus"] = tick()
                    claimedHistory["DailyBonus"] = true
                    print("🎁 [Auto Claim] Daily 3/3 Bonus READY! Mengklaim...")
                    task.spawn(function()
                        fireClaimQuest("Bonus")
                        fireClaimQuest("DailyBonus")
                        fireClaimQuest("Daily", "Bonus")
                    end)
                end
            end
        end
    end)
end

-- =================================================================
-- 🌐 PLAYTIME & DAILY LOGIN REMOTE DISPATCHER
-- =================================================================

local function sweepPlaytimeAndDailyRemotes()
    local now = tick()
    if now - lastRemoteSweep < 5 then return end
    lastRemoteSweep = now

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        or ReplicatedStorage:FindFirstChild("Remotes", true)
        or ReplicatedStorage

    if not remotes then return end

    if AutoClaim.Config.PlaytimeDaily then
        -- Playtime
        pcall(function()
            local claimPlay = remotes:FindFirstChild("ClaimPlaytimeReward")
                or remotes:FindFirstChild("ClaimPlaytime")
                or remotes:FindFirstChild("ClaimGift")
                or remotes:FindFirstChild("ClaimTimeReward")
            local reqPlay = remotes:FindFirstChild("RequestPlaytime") or remotes:FindFirstChild("RequestPlaytimeRewards")

            if reqPlay and reqPlay:IsA("RemoteFunction") and claimPlay then
                local data = reqPlay:InvokeServer()
                if typeof(data) == "table" then
                    for slotId, slotInfo in pairs(data) do
                        if typeof(slotInfo) == "table" then
                            local isClaimed = slotInfo.Claimed or slotInfo.IsClaimed
                            local isReady = (not isClaimed) and (slotInfo.Ready == true or (slotInfo.TimeLeft and slotInfo.TimeLeft <= 0))
                            local rKey = "RemotePlaytime_" .. tostring(slotId)
                            if isReady and not claimedHistory[rKey] then
                                if tick() - (clickDebounce[rKey] or 0) > 5 then
                                    clickDebounce[rKey] = tick()
                                    print(string.format("🎁 [Auto Claim] Playtime Gift READY (Slot %s)! Mengklaim via Remote...", tostring(slotId)))
                                    if claimPlay:IsA("RemoteEvent") then
                                        claimPlay:FireServer(slotId)
                                    elseif claimPlay:IsA("RemoteFunction") then
                                        claimPlay:InvokeServer(slotId)
                                    end
                                end
                            elseif isClaimed then
                                claimedHistory[rKey] = true
                            end
                        end
                    end
                end
            end
        end)

        -- Daily Login
        pcall(function()
            local claimDaily = remotes:FindFirstChild("ClaimDailyReward")
                or remotes:FindFirstChild("ClaimDaily")
                or remotes:FindFirstChild("ClaimLoginReward")
                or remotes:FindFirstChild("Claim7Day")
            local reqDaily = remotes:FindFirstChild("RequestDailyRewards") or remotes:FindFirstChild("RequestDailyLogin")

            if reqDaily and reqDaily:IsA("RemoteFunction") and claimDaily then
                local data = reqDaily:InvokeServer()
                if typeof(data) == "table" then
                    for dayId, dayInfo in pairs(data) do
                        if typeof(dayInfo) == "table" then
                            local isClaimed = dayInfo.Claimed or dayInfo.IsClaimed
                            local isReady = (not isClaimed) and (dayInfo.Ready == true or dayInfo.Available == true)
                            local rKey = "RemoteDaily_" .. tostring(dayId)
                            if isReady and not claimedHistory[rKey] then
                                if tick() - (clickDebounce[rKey] or 0) > 5 then
                                    clickDebounce[rKey] = tick()
                                    print(string.format("📅 [Auto Claim] Daily Login READY (Day %s)! Mengklaim via Remote...", tostring(dayId)))
                                    if claimDaily:IsA("RemoteEvent") then
                                        claimDaily:FireServer(dayId)
                                    elseif claimDaily:IsA("RemoteFunction") then
                                        claimDaily:InvokeServer(dayId)
                                    end
                                end
                            elseif isClaimed then
                                claimedHistory[rKey] = true
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- =================================================================
-- ⏳ UI SCANNER: PLAYTIME & DAILY LOGIN
-- =================================================================

local function scanPlaytimeRewards()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local scannedPanels = {}
    local mainGui = pg:FindFirstChild("MainGui")
    if mainGui then
        local root = mainGui:FindFirstChild("Root")
        local frames = root and root:FindFirstChild("Frames")
        if frames then
            for _, f in ipairs(frames:GetChildren()) do
                local fName = f.Name:lower()
                if f:IsA("GuiObject") and not isTemplateObject(f) then
                    if fName:find("play") or fName:find("gift") or fName:find("online") or fName:find("time") or fName:find("reward") or fName:find("free") then
                        table.insert(scannedPanels, f)
                    end
                end
            end
        end
        if root then
            for _, f in ipairs(root:GetChildren()) do
                local fName = f.Name:lower()
                if f:IsA("GuiObject") and not isTemplateObject(f) and f ~= frames then
                    if fName:find("play") or fName:find("gift") or fName:find("online") or fName:find("reward") then
                        table.insert(scannedPanels, f)
                    end
                end
            end
        end
    end

    for _, panel in ipairs(scannedPanels) do
        for _, desc in ipairs(panel:GetDescendants()) do
            if desc:IsA("GuiButton") and not isTemplateObject(desc) then
                local bTxt = extractButtonText(desc):upper():gsub("%s+", "")
                if bTxt == "CLAIMALL" or desc.Name:lower():find("claimall") then
                    tryClaim(desc, "Playtime [Claim All]", desc:GetFullName())
                end
            end
        end

        for _, child in ipairs(panel:GetDescendants()) do
            if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") and not isTemplateObject(child) then
                local cName = child.Name:lower()
                if cName:find("slot") or cName:find("gift") or cName:find("reward") or cName:find("card") or tonumber(child.Name) ~= nil or cName:find("item") or cName:find("box") then
                    local state, btn, itemName = evaluateRewardCard(child)
                    if state == "READY" and btn then
                        tryClaim(btn, "Playtime Gift [" .. (itemName ~= "" and itemName or child.Name) .. "]", child:GetFullName())
                    end
                end
            end
        end
    end
end

local function scanDailyLoginRewards()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local scannedPanels = {}
    local mainGui = pg:FindFirstChild("MainGui")
    if mainGui then
        local root = mainGui:FindFirstChild("Root")
        local frames = root and root:FindFirstChild("Frames")
        if frames then
            for _, f in ipairs(frames:GetChildren()) do
                local fName = f.Name:lower()
                if f:IsA("GuiObject") and not isTemplateObject(f) then
                    if fName:find("daily") or fName:find("login") or fName:find("7day") or fName:find("calendar") or fName:find("day") then
                        table.insert(scannedPanels, f)
                    end
                end
            end
        end
    end

    for _, panel in ipairs(scannedPanels) do
        for _, child in ipairs(panel:GetDescendants()) do
            if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not isTemplateObject(child) then
                local cName = child.Name:lower()
                if cName:find("day") or cName:find("reward") or tonumber(child.Name) ~= nil or cName:find("final") or cName:find("item") or cName:find("card") then
                    local state, btn, itemName = evaluateRewardCard(child)
                    if state == "READY" and btn then
                        tryClaim(btn, "Daily Login [" .. (itemName ~= "" and itemName or child.Name) .. "]", child:GetFullName())
                    end
                end
            end
        end
    end
end

-- =================================================================
-- 📜 UI BACKUP SCANNER: QUESTS
-- =================================================================

local function scanQuestsUIBackup()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local mainGui = pg:FindFirstChild("MainGui")
    local questsFrame = mainGui and mainGui:FindFirstChild("Root") and mainGui.Root:FindFirstChild("Frames") and mainGui.Root.Frames:FindFirstChild("Quests")
    if not questsFrame then return end

    for _, desc in ipairs(questsFrame:GetDescendants()) do
        if desc:IsA("GuiButton") and not isTemplateObject(desc) then
            local bTxt = extractButtonText(desc)
            if isClaimReadyKeyword(bTxt) then
                tryClaim(desc, "UI Quest Button [" .. desc.Name .. "]", desc:GetFullName())
            end
        end
    end
end

-- =================================================================
-- 🚀 MAIN LOOP CONTROLLER
-- =================================================================

function AutoClaim.Start()
    if isRunning then return end
    isRunning = true
    print("🎁 [Ritod Hub] Dual-Engine Auto Claim (Data-Driven Quests, Playtime & Daily) Aktif!")

    loopThread = task.spawn(function()
        while isRunning do
            pcall(function()
                -- 1. Direct Backend Sweep (Data-Driven)
                sweepPlaytimeAndDailyRemotes()
                processQuestsDataEngine()

                -- 2. UI Scanners
                if AutoClaim.Config.PlaytimeDaily then
                    scanPlaytimeRewards()
                    scanDailyLoginRewards()
                end

                if AutoClaim.Config.Quest then
                    scanQuestsUIBackup()
                end
            end)

            task.wait(AutoClaim.Config.CheckInterval or 2.5)
        end
    end)
end

function AutoClaim.Stop()
    isRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
    print("🛑 [Ritod Hub] Auto Claim Dimatikan.")
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

function AutoClaim.ResetHistory()
    claimedHistory  = {}
    clickDebounce   = {}
    lastRemoteSweep = 0
    print("🔄 [Auto Claim] Riwayat status klaim & debounce berhasil direset.")
end

-- Otomatis aktifkan jika script dieksekusi secara mandiri (Standalone di executor)
if not _G.RitodHubLoaded and not isRunning then
    task.spawn(function()
        task.wait(0.5)
        if not isRunning then
            AutoClaim.Start()
        end
    end)
end

return AutoClaim
