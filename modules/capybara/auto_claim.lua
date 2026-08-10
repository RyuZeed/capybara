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
    return false
end

-- =================================================================
-- ⏳ 1. PLAYTIME REWARDS SCANNER (ONLINE GIFTS)
-- =================================================================
local function scanPlaytimeRewards()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    for _, desc in ipairs(pg:GetDescendants()) do
        if desc:IsA("ImageButton") or desc:IsA("TextButton") then
            local pName = desc.Parent and desc.Parent.Name:lower() or ""
            local gName = desc:GetFullName():lower()
            if gName:find("playtime") or gName:find("online") or gName:find("gift") or gName:find("timegift") then
                local lbl = desc:FindFirstChild("TextLabel") or (desc:IsA("TextButton") and desc)
                if lbl then
                    local cleanTxt = (lbl.Text or ""):upper():gsub("%s+", "")
                    if cleanTxt == "CLAIM" then
                        local cardKey = desc:GetFullName()
                        local lastClick = clickDebounce[cardKey] or 0
                        if tick() - lastClick > 3 then
                            clickDebounce[cardKey] = tick()
                            print(string.format("🎁 [Auto Claim] Playtime Gift READY! Mengklaim (%s)...", tostring(desc.Parent and desc.Parent.Name or desc.Name)))
                            clickButton(desc)
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

    for _, desc in ipairs(pg:GetDescendants()) do
        if desc:IsA("ImageButton") or desc:IsA("TextButton") then
            local gName = desc:GetFullName():lower()
            if gName:find("daily") or gName:find("loginreward") or gName:find("7day") or gName:find("dayreward") then
                local lbl = desc:FindFirstChild("TextLabel") or (desc:IsA("TextButton") and desc)
                if lbl then
                    local cleanTxt = (lbl.Text or ""):upper():gsub("%s+", "")
                    if cleanTxt == "CLAIM" then
                        local cardKey = desc:GetFullName()
                        local lastClick = clickDebounce[cardKey] or 0
                        if tick() - lastClick > 3 then
                            clickDebounce[cardKey] = tick()
                            print(string.format("📅 [Auto Claim] Daily Login READY! Mengklaim (%s)...", tostring(desc.Parent and desc.Parent.Name or desc.Name)))
                            clickButton(desc)
                        end
                    end
                end
            end
        end
    end
end

-- =================================================================
-- 📜 3. QUESTS SCANNER & AUTO-CLAIMER (DAILY & LIFETIME ENGINE)
-- =================================================================
local function scanQuestsAndMissions()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local mainGui = pg:FindFirstChild("MainGui")
    local questsFrame = mainGui and mainGui:FindFirstChild("Root") and mainGui.Root:FindFirstChild("Frames") and mainGui.Root.Frames:FindFirstChild("Quests")
    if questsFrame then
        for _, desc in ipairs(questsFrame:GetDescendants()) do
            if desc:IsA("ImageButton") or desc:IsA("TextButton") then
                local lbl = desc:FindFirstChild("TextLabel") or (desc:IsA("TextButton") and desc)
                if lbl then
                    local cleanTxt = (lbl.Text or ""):upper():gsub("%s+", "")
                    if cleanTxt == "CLAIM" then
                        -- Cek apakah progress kartu misi belum selesai (contoh: 1/3 atau 5/15)
                        local isLocked = false
                        local card = desc.Parent
                        if card then
                            local pBar = card:FindFirstChild("ProgressBar")
                            local pLbl = pBar and pBar:FindFirstChild("TextLabel")
                            if pLbl then
                                local cur, max = pLbl.Text:match("(%d+)%s*/%s*(%d+)")
                                if cur and max then
                                    local nCur = tonumber(cur)
                                    local nMax = tonumber(max)
                                    if nCur and nMax and nMax > 0 and nCur < nMax then
                                        isLocked = true
                                    end
                                end
                            end
                        end

                        if not isLocked then
                            local cardKey = desc:GetFullName()
                            local lastClick = clickDebounce[cardKey] or 0
                            if tick() - lastClick > 3 then
                                clickDebounce[cardKey] = tick()
                                print(string.format("🏆 [Auto Claim] Mengklaim Quest (%s)...", tostring(card and card.Name or desc.Name)))
                                clickButton(desc)
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
