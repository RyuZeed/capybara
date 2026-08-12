--[[
	===============================================================
	⚡ RITOD HUB - SMART AUTO CLAIM ENGINE (ZERO SPAM & 100% READY-ONLY)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 ZERO-SPAM GUARANTEES:
	- 🛑 STRICT READY-ONLY: Hanya mengklaim jika tombol/server eksplisit bertuliskan "CLAIM", "COLLECT", "READY", atau "00:00".
	- 🛑 TIDAK AKAN MENGKLAIM ITEM LOCKED: Menolak mutlak teks "LOCKED", "LOCK", countdown timer aktif (> 00:00), atau misi belum selesai.
	- 🛑 TIDAK ADA BLIND SPAM: Menghapus total pengiriman remote acak slot 1..12 yang menyebabkan "You've already claimed this" / "You can't claim this yet".
	- 🛑 TEMPLATE IMMUNITY: Memblokir total DailyQuestTemplate & RewardTemplate.
	- 🔒 PERMANENT CLAIM CACHE: Item yang terdeteksi "CLAIMED" / ceklis langsung dicatat agar tidak pernah diklik ulang.
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
    CheckInterval = 3,    -- Interval pengecekan (detik)
}

local isRunning        = false
local loopThread       = nil
local claimedHistory   = {} -- [key] = true (Tercatat permanen jika visual/data sudah CLAIMED)
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

-- Cek apakah teks atau tombol mengindikasikan siap diklaim secara eksplisit
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

-- Cek apakah teks mengindikasikan sudah terklaim
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

-- Cek apakah teks mengindikasikan item masih terkunci
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
-- 🎯 REWARD CARD & BUTTON EVALUATOR (STRICT READY-ONLY)
-- =================================================================

local function evaluateRewardCard(card)
    if not card or not card:IsA("GuiObject") then return "INVALID", nil, "" end
    if isTemplateObject(card) then return "INVALID", nil, "" end

    local cardKey = card:GetFullName()
    if claimedHistory[cardKey] then return "CLAIMED", nil, "" end

    -- 1. Kumpulkan semua teks dari seluruh descendants di dalam card
    local allTexts = {}
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local t = cleanString(desc.Text)
            if t ~= "" then
                table.insert(allTexts, t)
            end
        end
    end
    if card:IsA("TextButton") and card.Text and card.Text ~= "" then
        table.insert(allTexts, cleanString(card.Text))
    end
    local combinedText = table.concat(allTexts, " ")
    local upperCombined = combinedText:upper():gsub("%s+", "")

    -- 2. Cek apakah CLAIMED
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

    -- 3. 🛑 Cek apakah LOCKED (Mengandung kata LOCKED, LOCK, atau timer countdown > 00:00)
    if isLockedKeyword(upperCombined) then
        return "LOCKED", nil, ""
    end

    for _, desc in ipairs(card:GetDescendants()) do
        local dName = desc.Name:lower()
        if dName:find("lock") and desc:IsA("ImageLabel") and desc.ImageTransparency < 0.5 and desc.Image ~= "" then
            return "LOCKED", nil, ""
        end
    end

    -- Cek countdown timer yang masih aktif (> 00:00)
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

    -- 4. 🟢 Harus ada indikator READY yang EKSPLISIT ("CLAIM", "COLLECT", "READY", "FREE", "00:00")
    local isExplicitlyReady = false
    for _, txt in ipairs(allTexts) do
        if isClaimReadyKeyword(txt) then
            isExplicitlyReady = true
            break
        end
    end

    if not isExplicitlyReady then
        -- 🛑 TIDAK ADA TEKS CLAIM/READY/00:00 -> JANGAN PERNAH DIKLAIM!
        return "LOCKED", nil, ""
    end

    -- 5. Cari tombol target yang valid
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

    -- Ambil label nama reward
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
-- 📜 QUEST CARD EVALUATOR (PROGRESS BAR & FRACTIONS)
-- =================================================================

local function evaluateQuestCard(questCard)
    if not questCard or not questCard:IsA("GuiObject") then return "INVALID", nil, "" end
    if isTemplateObject(questCard) then return "INVALID", nil, "" end

    local cardKey = questCard:GetFullName()
    if claimedHistory[cardKey] then return "CLAIMED", nil, "" end

    -- 1. Kumpulkan semua teks
    local allTexts = {}
    for _, desc in ipairs(questCard:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local t = cleanString(desc.Text)
            if t ~= "" then table.insert(allTexts, t) end
        end
    end
    local combinedText = table.concat(allTexts, " ")
    local upperCombined = combinedText:upper():gsub("%s+", "")

    -- 2. Cek apakah CLAIMED
    if isClaimedKeyword(upperCombined) then
        claimedHistory[cardKey] = true
        return "CLAIMED", nil, ""
    end

    for _, desc in ipairs(questCard:GetDescendants()) do
        local dName = desc.Name:lower()
        if (dName:find("claimed") or dName:find("check") or dName:find("tick") or dName == "done") and desc:IsA("GuiObject") then
            if (desc:IsA("ImageLabel") and desc.ImageTransparency < 0.5 and desc.Image ~= "")
               or (desc:IsA("Frame") and desc.BackgroundTransparency < 0.5 and desc.Visible) then
                claimedHistory[cardKey] = true
                return "CLAIMED", nil, ""
            end
        end
    end

    -- 3. Cari tombol di dalam questCard
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

    -- 4. Cek progress fraksi di TextLabel (contoh: "25/25 Plants Defeated", "5/5 Eggs Hatched", "100%")
    local hasFraction = false
    local isCompleted = false

    for _, txt in ipairs(allTexts) do
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

    -- 5. Harus ada indikasi CLAIM eksplisit
    local isExplicitClaim = isClaimReadyKeyword(btnTxt) or isClaimReadyKeyword(btn.Name) or isClaimReadyKeyword(upperCombined)
    if not isExplicitClaim and not isCompleted then
        return "LOCKED", nil, ""
    end

    -- Ambil judul quest
    local qTitle = questCard.Name
    for _, t in ipairs(allTexts) do
        if #t > 3 and not t:find("/") and not t:find("%%") and not isClaimReadyKeyword(t) and not isClaimedKeyword(t) and not isLockedKeyword(t) then
            qTitle = t
            break
        end
    end

    if (isCompleted or not hasFraction) and isExplicitClaim then
        return "READY", btn, qTitle
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
    if now - (clickDebounce[key] or 0) > 6 then -- 6 detik cooldown per item agar tidak spam
        clickDebounce[key] = now
        print(string.format("🎁 [Auto Claim] %s READY! Mengklaim...", tostring(label)))
        clickButton(btn)
        return true
    end
    return false
end

-- =================================================================
-- 🌐 1. DIRECT REMOTE DISPATCHER (STRICT DATA-VERIFIED ONLY)
-- =================================================================

local function sweepRemoteClaims()
    local now = tick()
    if now - lastRemoteSweep < 6 then return end
    lastRemoteSweep = now

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        or ReplicatedStorage:FindFirstChild("Remotes", true)
        or ReplicatedStorage

    if not remotes then return end

    -- A. Claim Playtime via Remote (HANYA JIKA TERVERIFIKASI READY DARI DATA SERVER)
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
                            local isReady = (not isClaimed) and (slotInfo.Ready == true or (slotInfo.TimeLeft and slotInfo.TimeLeft <= 0))
                            local rKey = "RemotePlaytime_" .. tostring(slotId)
                            if isReady and not claimedHistory[rKey] then
                                if tick() - (clickDebounce[rKey] or 0) > 6 then
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

        -- B. Claim Daily Login via Remote (HANYA JIKA TERVERIFIKASI READY DARI DATA SERVER)
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
                            local isReady = (not isClaimed) and (dayInfo.Ready == true or dayInfo.Available == true)
                            local rKey = "RemoteDaily_" .. tostring(dayId)
                            if isReady and not claimedHistory[rKey] then
                                if tick() - (clickDebounce[rKey] or 0) > 6 then
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

    -- C. Claim Quests via Remote (HANYA JIKA TERVERIFIKASI READY DARI DATA SERVER)
    if AutoClaim.Config.Quest then
        pcall(function()
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
                                        if tick() - (clickDebounce[rKey] or 0) > 6 then
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
                                    elseif isClaimed then
                                        claimedHistory[rKey] = true
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
    print("🎁 [Ritod Hub] Strict Auto Claim Engine (Ready-Only & Zero Spam) Aktif!")

    loopThread = task.spawn(function()
        while isRunning do
            pcall(function()
                -- 1. Direct Remote Sweep (Hanya jika terverifikasi READY)
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

            task.wait(AutoClaim.Config.CheckInterval or 3)
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
