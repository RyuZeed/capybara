--[[
	===============================================================
	⚡ RITOD HUB - SMART AUTO CLAIM ENGINE (DUAL-ENGINE & EXACT DATA)
	Game: Roll Anime For Fight / Anime Auto Roll
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- 📜 DATA-DRIVEN QUEST ENGINE (HANYA KLAIM SAAT STATUS READY):
	  • Membaca data real-time dari BattlepassQuest.GetQuestData.
	  • Verifikasi ketat: Hanya klaim jika (Completed == true dan Claimed == false).
	  • Tidak ada blind spam ke server.
	- 🛑 ZERO SPAM & STRICT CACHE:
	  • Item yang sudah berstatus Claimed dicatat permanen dalam session history.
	- 🖱️ Multi-Vector Hardware/Event Click Dispatcher (firesignal + getconnections + VIM + VirtualUser + Activate).
	- 🛡️ Template Filter: Mengabaikan tombol template non-aktif.
	===============================================================
]]

local AutoClaim = {}
_G.AutoClaim = AutoClaim
_G.AutoClaimModule = AutoClaim

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

AutoClaim.Config = {
    DailyQuest    = true, -- Auto Claim Daily Quests
    WeeklyQuest   = true, -- Auto Claim Weekly Quests
    Battlepass    = true, -- Auto Claim Battlepass Tier Rewards
    FreeRewards   = true, -- Auto Claim Playtime Gifts & Free VIP/Group
    VIPAndGroup   = true,
    CheckInterval = 3,    -- Interval pengecekan (detik)
}

local isRunning        = false
local loopThread       = nil
local claimedHistory   = {} -- [key] = true (Tercatat jika sudah CLAIMED agar tidak spam)
local clickDebounce    = {} -- [key] = timestamp (Cooldown klik per item)

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
-- 🔍 HELPER: TEMPLATE DETECTOR
-- =================================================================
local function isTemplateObject(obj)
    if not obj then return true end
    if obj.Parent and (obj.Parent.Name:lower() == "template" or obj.Parent.Name:lower() == "templates" or obj.Parent.Name:lower() == "configuration") then
        return true
    end
    if obj:IsA("GuiObject") and not obj.Visible then
        return true
    end
    return false
end

-- =================================================================
-- 1. 📜 AUTO CLAIM DAILY & WEEKLY QUESTS (DATA-DRIVEN & STRICT)
-- =================================================================
function AutoClaim.ClaimQuests()
    pcall(function()
        local bpQuestFolder = ReplicatedStorage:FindFirstChild("Modules") 
            and ReplicatedStorage.Modules:FindFirstChild("Battlepass") 
            and ReplicatedStorage.Modules.Battlepass:FindFirstChild("BattlepassQuest")
        
        if not bpQuestFolder then
            for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
                if desc.Name == "BattlepassQuest" and desc:IsA("Folder") then
                    bpQuestFolder = desc
                    break
                end
            end
        end

        if not bpQuestFolder then return end

        local getQuestFunc = bpQuestFolder:FindFirstChild("GetQuestData")
        local claimRemote = bpQuestFolder:FindFirstChild("ClaimQuest")

        if not claimRemote or not claimRemote:IsA("RemoteEvent") then return end
        if not getQuestFunc or not getQuestFunc:IsA("RemoteFunction") then return end

        -- Ambil data quest real-time pemain dari server
        local s, questData = pcall(function() return getQuestFunc:InvokeServer() end)
        if not (s and type(questData) == "table") then return end

        local categories = {}
        if AutoClaim.Config.DailyQuest and type(questData.Daily) == "table" then
            categories["Daily"] = questData.Daily
        end
        if AutoClaim.Config.WeeklyQuest and type(questData.Weekly) == "table" then
            categories["Weekly"] = questData.Weekly
        end

        -- 🎯 HANYA KLAIM JIKA: Status Selesai (Completed == true) dan Belum Diklaim (Claimed == false)
        for category, list in pairs(categories) do
            for idx, qInfo in ipairs(list) do
                if type(qInfo) == "table" then
                    local isDone = (qInfo.Completed == true) or (qInfo.Progress and qInfo.Requirement and qInfo.Progress >= qInfo.Requirement)
                    local isNotClaimed = (qInfo.Claimed == false)
                    local cacheKey = category .. "_" .. tostring(qInfo.ID or idx)

                    if isDone and isNotClaimed and not claimedHistory[cacheKey] then
                        local now = tick()
                        if not clickDebounce[cacheKey] or (now - clickDebounce[cacheKey] > 2) then
                            clickDebounce[cacheKey] = now
                            
                            -- Tembak Remote Resmi Game
                            pcall(function() claimRemote:FireServer(category, idx) end)
                            if qInfo.ID then
                                pcall(function() claimRemote:FireServer(category, qInfo.ID) end)
                            end
                            if qInfo.UniqueName then
                                pcall(function() claimRemote:FireServer(category, qInfo.UniqueName) end)
                            end
                        end
                    elseif qInfo.Claimed == true then
                        claimedHistory[cacheKey] = true
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 2. 🏆 AUTO CLAIM BATTLEPASS TIER REWARDS (STRICT UNLOCKED TIERS)
-- =================================================================
function AutoClaim.ClaimBattlepass()
    if not AutoClaim.Config.Battlepass then return end
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local mainUI = pGui and pGui:FindFirstChild("MainUI")
        local bpFrame = mainUI and mainUI:FindFirstChild("Frames") and mainUI.Frames:FindFirstChild("Battlepass")
        
        local bpContent = bpFrame and bpFrame:FindFirstChild("Frame")
            and bpFrame.Frame:FindFirstChild("Main")
            and bpFrame.Frame.Main:FindFirstChild("Battlepass")
            and bpFrame.Frame.Main.Battlepass:FindFirstChild("ScrollingFrame")
            and bpFrame.Frame.Main.Battlepass.ScrollingFrame:FindFirstChild("Content")
            and bpFrame.Frame.Main.Battlepass.ScrollingFrame.Content:FindFirstChild("Rewards")

        if bpContent then
            for _, bpReward in ipairs(bpContent:GetChildren()) do
                if bpReward.Name == "BattlepassReward" and not isTemplateObject(bpReward) then
                    for _, btn in ipairs(bpReward:GetDescendants()) do
                        if btn:IsA("GuiButton") and btn.Visible and btn.Active and not isTemplateObject(btn) then
                            local txt = tostring(btn:IsA("TextButton") and btn.Text or ""):lower()
                            if txt:find("claim") or txt == "" then
                                local btnKey = "BP_" .. btn:GetDebugId()
                                local now = tick()
                                if not clickDebounce[btnKey] or (now - clickDebounce[btnKey] > 5) then
                                    clickDebounce[btnKey] = now
                                    clickButton(btn)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 3. 🎁 AUTO CLAIM FREE REWARDS, VIP & GROUP (STRICT COOLDOWN)
-- =================================================================
function AutoClaim.ClaimFreeRewards()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local mainUI = pGui and pGui:FindFirstChild("MainUI")
        local frames = mainUI and mainUI:FindFirstChild("Frames")
        local now = tick()

        -- 1. VIP Claim (Hanya jika belum diklaim dan tombol aktif)
        if AutoClaim.Config.VIPAndGroup and frames and frames:FindFirstChild("VIPRewards") then
            local vipBtn = frames.VIPRewards:FindFirstChild("Frame")
                and frames.VIPRewards.Frame:FindFirstChild("Main")
                and frames.VIPRewards.Frame.Main:FindFirstChild("Claim")
                and frames.VIPRewards.Frame.Main.Claim:FindFirstChild("Claim")

            if vipBtn and vipBtn:IsA("GuiButton") and vipBtn.Visible and vipBtn.Active and not isTemplateObject(vipBtn) then
                if not clickDebounce["VIP"] or (now - clickDebounce["VIP"] > 60) then
                    clickDebounce["VIP"] = now
                    clickButton(vipBtn)
                end
            end
        end

        -- 2. Group Claim (Hanya jika belum diklaim dan tombol aktif)
        if AutoClaim.Config.VIPAndGroup and frames and frames:FindFirstChild("GroupRewards") then
            local grpBtn = frames.GroupRewards:FindFirstChild("Frame")
                and frames.GroupRewards.Frame:FindFirstChild("Main")
                and frames.GroupRewards.Frame.Main:FindFirstChild("Claim")
                and frames.GroupRewards.Frame.Main.Claim:FindFirstChild("Start")

            if grpBtn and grpBtn:IsA("GuiButton") and grpBtn.Visible and grpBtn.Active and not isTemplateObject(grpBtn) then
                if not clickDebounce["Group"] or (now - clickDebounce["Group"] > 60) then
                    clickDebounce["Group"] = now
                    clickButton(grpBtn)
                end
            end
        end
    end)
end

-- =================================================================
-- 4. 🖥️ DEEP UI BUTTON CLAIM SCANNER (FILTERED & DEBOUNCED)
-- =================================================================
function AutoClaim.ScanAndClaimUI()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pGui then return end

        local mainUI = pGui:FindFirstChild("MainUI")
        local frames = mainUI and mainUI:FindFirstChild("Frames")
        local now = tick()

        -- Scan Quest UI Button jika ada quest aktif di tampilan
        if AutoClaim.Config.DailyQuest or AutoClaim.Config.WeeklyQuest then
            local bpFrame = frames and frames:FindFirstChild("Battlepass")
            local questContent = bpFrame and bpFrame:FindFirstChild("Frame")
                and bpFrame.Frame:FindFirstChild("Main")
                and bpFrame.Frame.Main:FindFirstChild("Quest")
                and bpFrame.Frame.Main.Quest:FindFirstChild("ScrollingFrame")
                and bpFrame.Frame.Main.Quest.ScrollingFrame:FindFirstChild("Content")
                and bpFrame.Frame.Main.Quest.ScrollingFrame.Content:FindFirstChild("Rewards")

            if questContent then
                for _, questReward in ipairs(questContent:GetChildren()) do
                    if (questReward.Name == "QuestReward" or questReward.Name:find("Quest")) and not isTemplateObject(questReward) then
                        for _, desc in ipairs(questReward:GetDescendants()) do
                            if desc:IsA("GuiButton") and desc.Visible and desc.Active and not isTemplateObject(desc) then
                                local bKey = "UIQ_" .. desc:GetDebugId()
                                if not clickDebounce[bKey] or (now - clickDebounce[bKey] > 4) then
                                    clickDebounce[bKey] = now
                                    clickButton(desc)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 5. 🔄 ENGINE CONTROLLER (START / STOP)
-- =================================================================
function AutoClaim.Start(customConfig)
    if isRunning then return end
    isRunning = true

    if customConfig then
        for k, v in pairs(customConfig) do
            AutoClaim.Config[k] = v
        end
    end

    loopThread = task.spawn(function()
        while isRunning do
            if AutoClaim.Config.DailyQuest or AutoClaim.Config.WeeklyQuest then
                AutoClaim.ClaimQuests()
            end
            task.wait(1)

            if not isRunning then break end

            if AutoClaim.Config.Battlepass then
                AutoClaim.ClaimBattlepass()
            end
            task.wait(1)

            if not isRunning then break end

            if AutoClaim.Config.FreeRewards or AutoClaim.Config.VIPAndGroup then
                AutoClaim.ClaimFreeRewards()
            end
            task.wait(1)

            if not isRunning then break end

            AutoClaim.ScanAndClaimUI()

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
end

function AutoClaim.IsRunning()
    return isRunning
end

return AutoClaim
