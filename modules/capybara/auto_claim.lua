--[[
	===============================================================
	⚡ RITOD HUB - SMART AUTO CLAIM ENGINE (DUAL ENGINE & ANTI-SPAM)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 UPGRADES & FIXES:
	- 🛑 100% TEMPLATE IMMUNITY: Memblokir total DailyQuestTemplate & RewardTemplate agar tidak spam!
	- 🚀 DUAL-ENGINE ARCHITECTURE: Direct Remote Invocation + Deep Universal UI Scanner
	- 🔄 RETRY COOLDOWN SYSTEM: Cooldown 3.5 detik per item tanpa lockout permanen prematur!
	- 🟢 STATE-DRIVEN EVALUATION:
	  • "READY"   -> Eksekusi klaim saat hadiah/misi selesai (progress >= max, timer 00:00, atau teks "Claim").
	  • "CLAIMED" -> Dicatat jika visual/teks "Claimed" aktif agar tidak membuang resource.
	  • "LOCKED"  -> Dilewati saat timer countdown masih berjalan atau progress belum lengkap.
	- 🎁 Playtime Rewards & Online Gifts Tracker (12 Slots + 00:00 Countdown Detector)
	- 📅 Daily Login Rewards Tracker (7-Day Calendar)
	- 📜 Daily Quests, Lifetime Quests & Missions Tracker
	- ✨ Smart "Claim All" Auto-Detector
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
    Quest         = true, -- Auto Claim Daily Quests & Missions
    CheckInterval = 2.5,  -- Interval pengecekan (detik)
}

local isRunning        = false
local loopThread       = nil
local claimedHistory   = {} -- [key] = true (hanya jika visualnya terkonfirmasi CLAIMED)
local clickDebounce    = {} -- [key] = timestamp (cooldown antar klik)
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
-- 🔍 HELPER: FILTER TEMPLATE & STRING CLEANER
-- =================================================================

-- Cek apakah object merupakan template murni yang tidak boleh diklaim
local function isTemplateObject(obj)
    if not obj then return true end
    local name = obj.Name:lower()

    -- 🛑 Blokir total semua frame template / sample / placeholder
    if name:find("template") or name:find("sample") or name:find("placeholder") or name:find("dummy") or name:find("mockup") then
        return true
    end

    -- Cek juga apakah parent berada di dalam folder/frame Templates
    local current = obj.Parent
    while current and current:IsA("GuiObject") do
        local pName = current.Name:lower()
        if pName:find("template") or pName == "templates" then
            return true
        end
        current = current.Parent
    end

    return false
end

-- Ekstrak teks bersih tanpa tag HTML dan spasi berlebih
local function cleanString(str)
    if not str then return "" end
    return str:gsub("<[^>]*>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Ambil teks dari button atau TextLabel di dalamnya
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

-- Cek apakah teks atau tombol mengindikasikan siap diklaim
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

-- Cek apakah teks atau item sudah terklaim
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

-- =================================================================
-- 🎯 REWARD CARD & BUTTON EVALUATOR (STATE-DRIVEN)
-- =================================================================

local function evaluateRewardCard(card)
    if not card or not card:IsA("GuiObject") then return "INVALID", nil, "" end
    if isTemplateObject(card) then return "INVALID", nil, "" end

    local cardKey = card:GetFullName()
    if claimedHistory[cardKey] then return "CLAIMED", nil, "" end

    -- 1. Cek visual/label status "CLAIMED" di seluruh kartu
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local txt = extractButtonText(desc)
            if isClaimedKeyword(txt) then
                claimedHistory[cardKey] = true
                return "CLAIMED", nil, ""
            end
        end

        -- Cek visual overlay / icon ceklis
        local dName = desc.Name:lower()
        if (dName:find("claimed") or dName:find("check") or dName:find("tick") or dName == "done") and desc:IsA("GuiObject") then
            if (desc:IsA("ImageLabel") and desc.ImageTransparency < 0.5 and desc.Image ~= "")
               or (desc:IsA("Frame") and desc.BackgroundTransparency < 0.5 and desc.Visible) then
                claimedHistory[cardKey] = true
                return "CLAIMED", nil, ""
            end
        end
    end

    -- 2. Cek apakah ada status READY eksplisit di kartu (Claim / 00:00)
    local cardHasReadyLabel = false
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local txt = extractButtonText(desc)
            if isClaimReadyKeyword(txt) then
                cardHasReadyLabel = true
                break
            end
        end
    end

    -- 3. Cek apakah ada countdown timer yang AKTIF (dan kartu TIDAK memiliki label Ready/Claim)
    if not cardHasReadyLabel then
        for _, desc in ipairs(card:GetDescendants()) do
            if desc:IsA("TextLabel") then
                local txt = cleanString(desc.Text)
                local min, sec = txt:match("(%d+)%s*:%s*(%d+)")
                if min and sec then
                    local nMin, nSec = tonumber(min), tonumber(sec)
                    if (nMin and nMin > 0) or (nSec and nSec > 0) then
                        return "LOCKED", nil, "" -- Timer masih berjalan
                    end
                end

                -- Format Xm Ys atau Xs (kecuali 0s / 00:00)
                if (txt:match("%d+%s*m") or txt:match("%d+%s*s") or txt:match("%d+%s*h")) and not (txt:find("0s") or txt:find("00:00") or txt:lower():find("ready") or txt:lower():find("claim")) then
                    return "LOCKED", nil, ""
                end
            end
        end
    end

    -- 4. Cari tombol klik di dalam card
    local targetBtn = nil

    -- A. Cari GuiButton langsung
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("GuiButton") and not isTemplateObject(desc) then
            local btnTxt = extractButtonText(desc)
            local bName = desc.Name:lower()

            if isClaimReadyKeyword(btnTxt) or isClaimReadyKeyword(bName) then
                targetBtn = desc
                break
            end

            if (bName:find("claim") or bName:find("collect") or bName:find("reward") or bName == "button" or bName == "btn")
               and not btnTxt:find(":") and not isClaimedKeyword(btnTxt) then
                targetBtn = desc
                break
            end
        end
    end

    -- B. Jika card itu sendiri adalah GuiButton (misal slot Playtime gift atau Daily gift)
    if not targetBtn and card:IsA("GuiButton") then
        local cardTxt = extractButtonText(card)
        if isClaimReadyKeyword(cardTxt) or not (cardTxt:find(":") or isClaimedKeyword(cardTxt)) then
            targetBtn = card
        end
    end

    -- C. Fallback: Cari button apa saja yang bukan template jika ada label "CLAIM" / Ready
    if not targetBtn then
        for _, desc in ipairs(card:GetDescendants()) do
            if desc:IsA("TextLabel") and isClaimReadyKeyword(cleanString(desc.Text)) then
                local anyBtn = card:FindFirstChildWhichIsA("GuiButton", true)
                if anyBtn and not isTemplateObject(anyBtn) then
                    targetBtn = anyBtn
                    break
                end
            end
        end
    end

    -- Ambil label nama reward
    local rName = card.Name
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") and desc ~= targetBtn and not desc:IsDescendantOf(targetBtn or card) then
            local t = cleanString(desc.Text)
            if t ~= "" and not t:find(":") and #t > 2 and not isClaimReadyKeyword(t) and not isClaimedKeyword(t) then
                rName = t
                break
            end
        end
    end

    if targetBtn then
        return "READY", targetBtn, rName
    end

    return "LOCKED", nil, ""
end

-- =================================================================
-- 📜 QUEST CARD EVALUATOR (PROGRESS BAR & FRACTIONS)
-- =================================================================

local function evaluateQuestCard(questCard)
    if not questCard or not questCard:IsA("GuiObject") then return "INVALID", nil, "" end
    if isTemplateObject(questCard) then return "INVALID", nil, "" end

    local cardKey = questCard:GetFullName()
    if claimedHistory[cardKey] then return "CLAIMED", nil, "" end

    -- 1. Cek visual / label status "CLAIMED"
    for _, desc in ipairs(questCard:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local txt = extractButtonText(desc)
            if isClaimedKeyword(txt) then
                claimedHistory[cardKey] = true
                return "CLAIMED", nil, ""
            end
        end

        local dName = desc.Name:lower()
        if (dName:find("claimed") or dName:find("check") or dName:find("tick") or dName == "done") and desc:IsA("GuiObject") then
            if (desc:IsA("ImageLabel") and desc.ImageTransparency < 0.5 and desc.Image ~= "")
               or (desc:IsA("Frame") and desc.BackgroundTransparency < 0.5 and desc.Visible) then
                claimedHistory[cardKey] = true
                return "CLAIMED", nil, ""
            end
        end
    end

    -- 2. Cari tombol di dalam questCard
    local btn = questCard:FindFirstChild("Button")
        or questCard:FindFirstChild("ClaimButton")
        or questCard:FindFirstChild("Claim")
        or questCard:FindFirstChildWhichIsA("ImageButton", true)
        or questCard:FindFirstChildWhichIsA("TextButton", true)

    if not btn or isTemplateObject(btn) then
        return "LOCKED", nil, ""
    end

    local btnTxt = extractButtonText(btn)
    if isClaimedKeyword(btnTxt) then
        claimedHistory[cardKey] = true
        return "CLAIMED", nil, ""
    end

    -- 3. Cek progress fraksi di TextLabel (contoh: "25/25 Plants Defeated", "5/5 Eggs Hatched", "100%")
    local hasFraction = false
    local isCompleted = false

    for _, desc in ipairs(questCard:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Parent ~= btn and not desc:IsDescendantOf(btn) then
            local txt = cleanString(desc.Text)
            local cur, max = txt:match("(%d+)%s*/%s*(%d+)")
            if cur and max then
                hasFraction = true
                local nCur = tonumber(cur)
                local nMax = tonumber(max)
                if nCur and nMax and nMax > 0 then
                    if nCur >= nMax then
                        isCompleted = true
                    else
                        return "LOCKED", nil, "" -- Belum selesai (cur < max)
                    end
                end
            end

            -- Cek format persentase (100%)
            local pct = txt:match("(%d+)%%")
            if pct then
                hasFraction = true
                if tonumber(pct) >= 100 then
                    isCompleted = true
                else
                    return "LOCKED", nil, ""
                end
            end
        end
    end

    -- 4. Ambil judul / deskripsi quest untuk log
    local qTitle = questCard.Name
    for _, desc in ipairs(questCard:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Parent ~= btn and not desc:IsDescendantOf(btn) then
            local t = cleanString(desc.Text)
            if t ~= "" and not t:find("/") and not t:find("%%") and #t > 3 and not isClaimReadyKeyword(t) and not isClaimedKeyword(t) then
                qTitle = t
                break
            end
        end
    end

    -- Jika progress bar selesai atau tombol eksplisit bertuliskan CLAIM
    if (isCompleted or not hasFraction) and (isClaimReadyKeyword(btnTxt) or isClaimReadyKeyword(btn.Name)) then
        return "READY", btn, qTitle
    end

    if not hasFraction and (btn:IsA("GuiButton") or btn:IsA("ImageButton") or btn:IsA("TextButton")) then
        return "READY", btn, qTitle
    end

    return "LOCKED", nil, ""
end

-- =================================================================
-- 🚀 EKSEKUTOR KLAIM DENGAN COOLDOWN
-- =================================================================

local function tryClaim(btn, label, itemKey)
    local key = itemKey or btn:GetFullName()
    if claimedHistory[key] then return false end

    local now = tick()
    if now - (clickDebounce[key] or 0) > 3.5 then -- Cooldown 3.5 detik antar percobaan
        clickDebounce[key] = now
        print(string.format("🎁 [Auto Claim] %s! Mengklaim...", tostring(label)))
        clickButton(btn)
        return true
    end
    return false
end

-- =================================================================
-- 🌐 1. DIRECT REMOTE DISPATCHER (BACKEND ENGINE)
-- =================================================================

local function sweepRemoteClaims()
    local now = tick()
    if now - lastRemoteSweep < 4 then return end
    lastRemoteSweep = now

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        or ReplicatedStorage:FindFirstChild("Remotes", true)
        or ReplicatedStorage

    if not remotes then return end

    -- A. Claim Playtime via Remote
    if AutoClaim.Config.PlaytimeDaily then
        pcall(function()
            local claimPlay = remotes:FindFirstChild("ClaimPlaytimeReward")
                or remotes:FindFirstChild("ClaimPlaytime")
                or remotes:FindFirstChild("ClaimGift")
                or remotes:FindFirstChild("ClaimTimeReward")
                or remotes:FindFirstChild("ClaimPlaytimeGift")

            local reqPlay = remotes:FindFirstChild("RequestPlaytime") or remotes:FindFirstChild("RequestPlaytimeRewards")

            if reqPlay and reqPlay:IsA("RemoteFunction") and claimPlay then
                local data = reqPlay:InvokeServer()
                if typeof(data) == "table" then
                    for slotId, slotInfo in pairs(data) do
                        if typeof(slotInfo) == "table" then
                            local isClaimed = slotInfo.Claimed or slotInfo.IsClaimed
                            local isReady = (not isClaimed) and (slotInfo.Ready or (slotInfo.TimeLeft and slotInfo.TimeLeft <= 0))
                            local rKey = "RemotePlaytime_" .. tostring(slotId)
                            if isReady and not claimedHistory[rKey] then
                                if tick() - (clickDebounce[rKey] or 0) > 3.5 then
                                    clickDebounce[rKey] = tick()
                                    print(string.format("🎁 [Auto Claim] Playtime Gift READY (Slot %s)! Mengklaim via Remote...", tostring(slotId)))
                                    if claimPlay:IsA("RemoteEvent") then
                                        claimPlay:FireServer(slotId)
                                    elseif claimPlay:IsA("RemoteFunction") then
                                        claimPlay:InvokeServer(slotId)
                                    end
                                end
                            end
                        end
                    end
                end
            elseif claimPlay then
                -- Blind sweep untuk 12 slot playtime jika tidak ada RequestPlaytime
                for slot = 1, 12 do
                    local rKey = "BlindPlaytime_" .. tostring(slot)
                    if not claimedHistory[rKey] and tick() - (clickDebounce[rKey] or 0) > 10 then
                        clickDebounce[rKey] = tick()
                        if claimPlay:IsA("RemoteEvent") then
                            claimPlay:FireServer(slot)
                        elseif claimPlay:IsA("RemoteFunction") then
                            claimPlay:InvokeServer(slot)
                        end
                    end
                end
            end
        end)

        -- B. Claim Daily Login via Remote
        pcall(function()
            local claimDaily = remotes:FindFirstChild("ClaimDailyReward")
                or remotes:FindFirstChild("ClaimDaily")
                or remotes:FindFirstChild("ClaimLoginReward")
                or remotes:FindFirstChild("ClaimDailyLogin")
                or remotes:FindFirstChild("Claim7Day")

            local reqDaily = remotes:FindFirstChild("RequestDailyRewards") or remotes:FindFirstChild("RequestDailyLogin")

            if reqDaily and reqDaily:IsA("RemoteFunction") and claimDaily then
                local data = reqDaily:InvokeServer()
                if typeof(data) == "table" then
                    for dayId, dayInfo in pairs(data) do
                        if typeof(dayInfo) == "table" then
                            local isClaimed = dayInfo.Claimed or dayInfo.IsClaimed
                            local isReady = (not isClaimed) and (dayInfo.Ready or dayInfo.Available)
                            local rKey = "RemoteDaily_" .. tostring(dayId)
                            if isReady and not claimedHistory[rKey] then
                                if tick() - (clickDebounce[rKey] or 0) > 3.5 then
                                    clickDebounce[rKey] = tick()
                                    print(string.format("📅 [Auto Claim] Daily Login READY (Day %s)! Mengklaim via Remote...", tostring(dayId)))
                                    if claimDaily:IsA("RemoteEvent") then
                                        claimDaily:FireServer(dayId)
                                    elseif claimDaily:IsA("RemoteFunction") then
                                        claimDaily:InvokeServer(dayId)
                                    end
                                end
                            end
                        end
                    end
                end
            elseif claimDaily then
                -- Blind sweep untuk 7 hari
                for day = 1, 7 do
                    local rKey = "BlindDaily_" .. tostring(day)
                    if not claimedHistory[rKey] and tick() - (clickDebounce[rKey] or 0) > 10 then
                        clickDebounce[rKey] = tick()
                        if claimDaily:IsA("RemoteEvent") then
                            claimDaily:FireServer(day)
                        elseif claimDaily:IsA("RemoteFunction") then
                            claimDaily:InvokeServer(day)
                        end
                    end
                end
            end
        end)
    end

    -- C. Claim Quests via Remote
    if AutoClaim.Config.Quest then
        pcall(function()
            local claimAll = remotes:FindFirstChild("ClaimAllQuests") or remotes:FindFirstChild("ClaimAll")
            if claimAll and claimAll:IsA("RemoteEvent") then
                claimAll:FireServer()
            end

            local reqQuests = remotes:FindFirstChild("RequestQuests")
            local claimQuest = remotes:FindFirstChild("ClaimQuest")
                or remotes:FindFirstChild("ClaimDailyQuest")
                or remotes:FindFirstChild("ClaimLifetimeQuest")
                or remotes:FindFirstChild("ClaimMission")
                or remotes:FindFirstChild("ClaimAchievement")

            if reqQuests and reqQuests:IsA("RemoteFunction") and claimQuest then
                local qData = reqQuests:InvokeServer()
                if typeof(qData) == "table" then
                    for category, list in pairs(qData) do
                        if typeof(list) == "table" then
                            for qId, qInfo in pairs(list) do
                                if typeof(qInfo) == "table" then
                                    local isClaimed = qInfo.Claimed or qInfo.IsClaimed
                                    local isReady = (not isClaimed) and ((qInfo.Progress and qInfo.Max and qInfo.Progress >= qInfo.Max) or qInfo.Completed == true or qInfo.Ready == true)
                                    local rKey = "RemoteQuest_" .. tostring(qId)
                                    if isReady and not claimedHistory[rKey] then
                                        if tick() - (clickDebounce[rKey] or 0) > 3.5 then
                                            clickDebounce[rKey] = tick()
                                            print(string.format("📜 [Auto Claim] Quest READY (%s: %s)! Mengklaim via Remote...", tostring(category), tostring(qId)))
                                            if claimQuest:IsA("RemoteEvent") then
                                                claimQuest:FireServer(qId)
                                                claimQuest:FireServer(category, qId)
                                            elseif claimQuest:IsA("RemoteFunction") then
                                                claimQuest:InvokeServer(qId)
                                                claimQuest:InvokeServer(category, qId)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- =================================================================
-- ⏳ 2. PLAYTIME REWARDS SCANNER (UI ENGINE)
-- =================================================================

local function scanPlaytimeRewards()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local scannedPanels = {}

    -- 1. Scan seluruh frame di MainGui.Root.Frames
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

        -- Cari juga di MainGui.Root langsung (Floating gift icon / notification bar)
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

    -- 2. Scan ScreenGui lain di PlayerGui
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= mainGui and not gui.Name:lower():find("ritod") and not gui.Name:lower():find("core") then
            local gName = gui.Name:lower()
            if gName:find("play") or gName:find("gift") or gName:find("online") or gName:find("time") or gName:find("reward") then
                table.insert(scannedPanels, gui)
            end
        end
    end

    -- 3. Evaluasi setiap slot hadiah Playtime di panel yang ditemukan
    for _, panel in ipairs(scannedPanels) do
        -- Cari tombol "Claim All" jika ada
        for _, desc in ipairs(panel:GetDescendants()) do
            if desc:IsA("GuiButton") and not isTemplateObject(desc) then
                local bTxt = extractButtonText(desc):upper():gsub("%s+", "")
                if bTxt == "CLAIMALL" or desc.Name:lower():find("claimall") then
                    tryClaim(desc, "Playtime [Claim All]", desc:GetFullName())
                end
            end
        end

        -- Scan item-item slot hadiah
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

-- =================================================================
-- 📅 3. DAILY LOGIN REWARDS SCANNER (UI ENGINE)
-- =================================================================

local function scanDailyLoginRewards()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local scannedPanels = {}

    -- 1. Cari Frame Daily di MainGui.Root.Frames
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

    -- 2. Scan ScreenGui lain di PlayerGui
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= mainGui and not gui.Name:lower():find("ritod") and not gui.Name:lower():find("core") then
            local gName = gui.Name:lower()
            if gName:find("daily") or gName:find("login") or gName:find("7day") or gName:find("calendar") then
                table.insert(scannedPanels, gui)
            end
        end
    end

    -- 3. Evaluasi setiap hari di kalender Daily Login
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
-- 📜 4. QUESTS SCANNER (DAILY, LIFETIME & MISSIONS)
-- =================================================================

local function scanQuestsAndMissions()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local questFrames = {}

    -- 1. Cari target utama: MainGui.Root.Frames.Quests
    local mainGui = pg:FindFirstChild("MainGui")
    if mainGui then
        local root = mainGui:FindFirstChild("Root")
        local frames = root and root:FindFirstChild("Frames")
        if frames then
            local qf = frames:FindFirstChild("Quests") or frames:FindFirstChild("DailyQuests") or frames:FindFirstChild("Missions")
            if qf then table.insert(questFrames, qf) end
        end
    end

    -- 2. Cari di ScreenGui lain jika ada
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= mainGui and not gui.Name:lower():find("ritod") and not gui.Name:lower():find("core") then
            local gName = gui.Name:lower()
            if gName:find("quest") or gName:find("mission") or gName:find("task") or gName:find("achievement") then
                table.insert(questFrames, gui)
            end
        end
    end

    -- 3. Evaluasi Quests
    for _, qf in ipairs(questFrames) do
        -- A. Cek apakah ada tombol "Claim All" di Quests
        for _, desc in ipairs(qf:GetDescendants()) do
            if desc:IsA("GuiButton") and not isTemplateObject(desc) then
                local bTxt = extractButtonText(desc):upper():gsub("%s+", "")
                if bTxt == "CLAIMALL" or desc.Name:lower():find("claimall") then
                    tryClaim(desc, "Quests [Claim All]", desc:GetFullName())
                end
            end
        end

        -- B. Scan LifetimeQuests
        local lifetime = qf:FindFirstChild("LifetimeQuests", true)
        if lifetime then
            for _, item in ipairs(lifetime:GetChildren()) do
                if item:IsA("GuiObject") and not item:IsA("UIListLayout") and not item:IsA("UIGridLayout") and not isTemplateObject(item) then
                    local state, btn, qTitle = evaluateQuestCard(item)
                    if state == "READY" and btn then
                        tryClaim(btn, "🏆 Lifetime Quest [" .. qTitle .. "]", item:GetFullName())
                    end
                end
            end
        end

        -- C. Scan DailyQuests (DailyQuestFrame -> DailyQuests)
        local dailyFrame = qf:FindFirstChild("DailyQuestFrame", true)
        local dailyQuests = (dailyFrame and dailyFrame:FindFirstChild("DailyQuests", true)) or qf:FindFirstChild("DailyQuests", true)
        if dailyQuests then
            for _, item in ipairs(dailyQuests:GetChildren()) do
                if item:IsA("GuiObject") and not item:IsA("UIListLayout") and not item:IsA("UIGridLayout") and not isTemplateObject(item) then
                    local state, btn, qTitle = evaluateQuestCard(item)
                    if state == "READY" and btn then
                        tryClaim(btn, "📜 Daily Quest [" .. qTitle .. "]", item:GetFullName())
                    end
                end
            end
        end

        -- D. Fallback Generic Scanner untuk seluruh card quest di dalam qf
        for _, desc in ipairs(qf:GetDescendants()) do
            if desc:IsA("GuiObject") and not desc:IsA("ScrollingFrame") and not isTemplateObject(desc) then
                local dName = desc.Name:lower()
                if (dName:find("quest") or dName:find("mission") or dName:find("task") or dName:find("card") or dName:find("item"))
                   and not (dName:find("list") or dName:find("holder") or dName:find("container") or dName:find("content") or dName:find("frame")) then
                    local state, btn, qTitle = evaluateQuestCard(desc)
                    if state == "READY" and btn then
                        tryClaim(btn, "📜 Quest [" .. qTitle .. "]", desc:GetFullName())
                    end
                end
            end
        end
    end
end

-- =================================================================
-- 🚀 5. GENERIC FREE REWARDS & CHEST SCANNER (BACKUP)
-- =================================================================

local function scanGenericFreeRewards()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local mainGui = pg:FindFirstChild("MainGui")
    if not mainGui then return end

    local root = mainGui:FindFirstChild("Root")
    local frames = root and root:FindFirstChild("Frames")
    if not frames then return end

    -- Scan frame Reward / FreeGifts / Chest / Group / Spin
    for _, f in ipairs(frames:GetChildren()) do
        if f:IsA("GuiObject") and not isTemplateObject(f) then
            local fName = f.Name:lower()
            if fName:find("reward") or fName:find("chest") or fName:find("group") or fName:find("spin") or fName:find("free") then
                for _, desc in ipairs(f:GetDescendants()) do
                    if desc:IsA("GuiButton") and not isTemplateObject(desc) then
                        local bTxt = extractButtonText(desc)
                        if isClaimReadyKeyword(bTxt) then
                            tryClaim(desc, "Free Reward [" .. f.Name .. "]", desc:GetFullName())
                        end
                    end
                end
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
    print("🎁 [Ritod Hub] Dual-Engine Auto Claim (Playtime, Daily & Quests) Aktif!")

    loopThread = task.spawn(function()
        while isRunning do
            pcall(function()
                -- 1. Direct Remote Sweep (Backend)
                sweepRemoteClaims()

                -- 2. Playtime & Daily Login Scanner (UI)
                if AutoClaim.Config.PlaytimeDaily then
                    scanPlaytimeRewards()
                    scanDailyLoginRewards()
                end

                -- 3. Quests Scanner (UI)
                if AutoClaim.Config.Quest then
                    scanQuestsAndMissions()
                end

                -- 4. Generic Free Rewards Backup
                scanGenericFreeRewards()
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
