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
-- 🎯 SMART REWARD STATE EVALUATOR (EXACTLY LIKE HAS_STOCK)
-- States:
--   "CLAIMED" -> Sudah diambil / diceklis (Diabaikan permanen)
--   "LOCKED"  -> Masih hitung mundur / progress belum selesai (Diabaikan)
--   "READY"   -> Siap diklaim (Countdown selesai / Progress 100% / Tombol Claim)
-- =================================================================

local function evaluateRewardCard(card)
    if not card or not card:IsA("GuiObject") then
        return "INVALID", nil
    end

    local cardKey = card:GetFullName()

    -- 1. CEK CLAIMED STATE (Apakah sudah pernah diklaim sebelumnya)
    if claimedHistory[cardKey] == true then
        return "CLAIMED", nil
    end

    -- Cek attribute Claimed pada kartu
    if card:GetAttribute("Claimed") == true or card:GetAttribute("IsClaimed") == true or card:GetAttribute("Completed") == true then
        claimedHistory[cardKey] = true
        return "CLAIMED", nil
    end

    -- Cek teks status di seluruh anak kartu (tanpa mempedulikan apakah window sedang terbuka/tertutup)
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local rawTxt = desc.Text or ""
            local txt = rawTxt:gsub("<[^>]*>", ""):lower():gsub("%s+", "")
            if txt == "claimed" or txt == "terklaim" or txt == "sudahdiklaim" or txt == "collected" or txt == "received" or txt:find("sudah") then
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

    -- 2. CEK LOCKED STATE (Apakah kartu masih cooldown / progress belum selesai)
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local rawTxt = desc.Text or ""
            local clean = rawTxt:gsub("<[^>]*>", ""):gsub("%s+", ""):lower()

            -- Timer Countdown aktif (misal "05:20", "12:00:00", "01:30")
            -- Catatan: jika "00:00" atau "0:00", berarti countdown SELESAI (READY)!
            if (clean:match("^%d+:%d+$") or clean:match("^%d+:%d+:%d+$")) then
                if clean ~= "00:00" and clean ~= "0:00" and clean ~= "00:00:00" and clean ~= "0:00:00" then
                    return "LOCKED", nil
                end
            end

            -- Progress fraksi (misal "0/5", "2/10", "3/10")
            local cur, max = clean:match("(%d+)%s*/%s*(%d+)")
            if cur and max then
                local nCur = tonumber(cur)
                local nMax = tonumber(max)
                if nCur and nMax and nMax > 0 and nCur < nMax then
                    return "LOCKED", nil
                end
            end

            -- Progress persentase (misal "50%", "0%")
            local pct = clean:match("(%d+)%%")
            if pct then
                local nPct = tonumber(pct)
                if nPct and nPct < 100 then
                    return "LOCKED", nil
                end
            end

            -- Teks eksplisit terkunci
            if clean:find("locked") or clean:find("cooldown") or clean:find("terkunci") or clean:find("inprogress") or clean:find("belum") then
                return "LOCKED", nil
            end
        end
    end

    -- 3. CEK READY TO CLAIM (Mencari tombol Claim yang aktif)
    local foundBtn = nil

    local function checkButtonReady(btn)
        if not btn or not (btn:IsA("GuiButton") or btn:IsA("TextButton") or btn:IsA("ImageButton")) then
            return false
        end

        local btnText = ""
        if btn:IsA("TextButton") then
            btnText = (btn.Text or ""):gsub("<[^>]*>", ""):lower():gsub("%s+", "")
        end

        for _, c in ipairs(btn:GetChildren()) do
            if c:IsA("TextLabel") then
                local t = (c.Text or ""):gsub("<[^>]*>", ""):lower():gsub("%s+", "")
                if t ~= "" then btnText = t end
            end
        end

        -- Teks tombol eksplisit mengindikasikan klaim
        if btnText == "claim" or btnText == "klaim" or btnText == "collect" or btnText == "ambil" or btnText == "get" or btnText == "ready" then
            return true
        end

        -- Nama tombol adalah Claim / ClaimButton dan bukan countdown/fraksi
        local bName = btn.Name:lower()
        if (bName == "claim" or bName == "claimbutton" or bName == "claimbtn" or bName == "btnclaim" or bName == "collectbutton") then
            if not (btnText:find("/") or btnText:find(":") or btnText:find("claimed") or btnText:find("terklaim")) then
                return true
            end
        end

        return false
    end

    for _, desc in ipairs(card:GetDescendants()) do
        if checkButtonReady(desc) then
            foundBtn = desc
            break
        end
    end

    if not foundBtn and checkButtonReady(card) then
        foundBtn = card
    end

    if foundBtn then
        return "READY", foundBtn
    end

    -- Jika card sendiri memiliki text "Claim" atau "Ready" di labelnya
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local t = (desc.Text or ""):gsub("<[^>]*>", ""):lower():gsub("%s+", "")
            if t == "claim" or t == "klaim" or t == "collect" or t == "ready" or t == "00:00" then
                -- Cari button apapun di dalam card
                local anyBtn = card:FindFirstChildWhichIsA("GuiButton", true) or card:FindFirstChildWhichIsA("TextButton", true) or card:FindFirstChildWhichIsA("ImageButton", true)
                if anyBtn then return "READY", anyBtn end
            end
        end
    end

    return "LOCKED", nil
end

-- =================================================================
-- 📦 PROCESS CARD (EKSEKUSI KLAIM SECARA TEPAT + DUAL REMOTE TRIGGER)
-- =================================================================

local function processRewardCard(card, cardType)
    local state, claimBtn = evaluateRewardCard(card)
    local cardKey = card:GetFullName()

    if state == "READY" and claimBtn then
        -- Cooldown per kartu (hindari spam klik ganda)
        local lastClick = clickDebounce[cardKey] or 0
        if tick() - lastClick > 4 then
            clickDebounce[cardKey] = tick()
            print(string.format("🎁 [Auto Claim] Hadiah READY! Mengklaim %s (%s)...", tostring(cardType), tostring(card.Name)))
            
            -- 1. Klik tombol UI via multi-event simulation
            clickButton(claimBtn)

            -- 2. Pemicu Remote Langsung berdasarkan tipe hadiah
            local itemNum = tonumber(card.Name:match("(%d+)"))
            if cardType == "Playtime Gift" then
                if itemNum then
                    callRemote("ClaimPlaytimeReward", itemNum)
                    callRemote("ClaimPlaytimeReward", "Reward" .. tostring(itemNum))
                    callRemote("ClaimPlaytime", itemNum)
                    callRemote("ClaimFreeGift", itemNum)
                end
            elseif cardType == "Daily Login" then
                if itemNum then
                    callRemote("ClaimDailyReward", itemNum)
                    callRemote("ClaimDailyReward", "Day" .. tostring(itemNum))
                    callRemote("ClaimDaily", itemNum)
                    callRemote("ClaimDay", itemNum)
                end
            elseif cardType == "Quest" then
                if itemNum then
                    callRemote("ClaimQuest", itemNum)
                    callRemote("ClaimQuest", "DailyQuest" .. tostring(itemNum))
                    callRemote("ClaimDailyQuest", itemNum)
                    callRemote("ClaimQuestReward", itemNum)
                else
                    callRemote("ClaimQuest", card.Name)
                end
            end

            -- Tunggu sebentar dan periksa apakah status berubah menjadi CLAIMED
            task.delay(0.5, function()
                local newState = evaluateRewardCard(card)
                if newState == "CLAIMED" then
                    claimedHistory[cardKey] = true
                    print(string.format("✅ [Auto Claim] Sukses! %s (%s) sudah CLAIMED.", tostring(cardType), tostring(card.Name)))
                end
            end)
            return true
        end
    end

    return false
end

-- =================================================================
-- ⏳ 1. PLAYTIME REWARDS SCANNER (ONLINE GIFTS)
-- =================================================================
local function scanPlaytimeRewards()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local processed = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
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
-- 📅 2. DAILY LOGIN REWARDS SCANNER
-- =================================================================
local function scanDailyLoginRewards()
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
-- 📜 3. QUESTS SCANNER (DAILY QUESTS & ACHIEVEMENTS)
-- =================================================================
local function scanQuestsAndMissions()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local processed = {}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiObject") and not processed[desc] then
                    local dName = desc.Name:lower()

                    -- Deteksi Container Quest
                    if (dName:find("quest") or dName:find("task") or dName:find("achievement") or dName:find("mission")) then
                        -- Cek apakah ada tombol "Claim All" dan ada misi yang berstatus READY
                        local claimAllBtn = nil
                        local hasAnyReady = false

                        for _, sub in ipairs(desc:GetDescendants()) do
                            if sub:IsA("GuiButton") and sub.Visible then
                                local bTxt = (sub:IsA("TextButton") and sub.Text or ""):lower():gsub("%s+", "")
                                if bTxt:find("all") or sub.Name:lower():find("all") then
                                    claimAllBtn = sub
                                end
                            end
                        end

                        -- Scan setiap kartu misi individual
                        for _, questItem in ipairs(desc:GetDescendants()) do
                            if questItem:IsA("GuiObject") and not processed[questItem] then
                                local qName = questItem.Name:lower()
                                if not qName:find("holder") and not qName:find("list") and not qName:find("container") and not qName:find("frame") and not qName:find("main") then
                                    if qName:find("quest") or qName:find("task") or qName:find("item") or tonumber(questItem.Name) ~= nil or qName:find("card") or qName:find("row") then
                                        processed[questItem] = true
                                        local isClaimedOrReady = processRewardCard(questItem, "Quest")
                                        if isClaimedOrReady then hasAnyReady = true end
                                    end
                                end
                            end
                        end

                        -- Jika ada tombol Claim All dan terdeteksi misi ready, klik Claim All
                        if claimAllBtn and hasAnyReady then
                            local allKey = claimAllBtn:GetDebugId() or tostring(claimAllBtn)
                            if not clickDebounce[allKey] or tick() - clickDebounce[allKey] > 6 then
                                clickDebounce[allKey] = tick()
                                print("📜 [Auto Claim] Menekan tombol Claim All Quests!")
                                clickButton(claimAllBtn)
                            end
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
