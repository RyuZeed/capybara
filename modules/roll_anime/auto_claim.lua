-- =================================================================
-- 🎁 RITOD HUB | AUTO QUEST & CLAIM REWARDS ENGINE
-- Game: Roll Anime For Fight / Anime Auto Roll
-- Description: Otomatis klaim Daily Quest, Weekly Quest, Battlepass,
--              Free Group Rewards, VIP, dan Playtime Gifts.
-- =================================================================

local AutoClaim = {}
_G.AutoClaim = AutoClaim

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

AutoClaim.Config = {
    DailyQuest    = true,
    WeeklyQuest   = true,
    Battlepass    = true,
    FreeRewards   = true,
    VIPAndGroup   = true,
    CheckInterval = 4
}

local isRunning = false
local claimThread = nil
local claimedTracker = {}

-- =================================================================
-- 📡 RESOLVE REMOTES & MODULES SECURELY
-- =================================================================
local function getRemote(parent, name)
    if not parent then return nil end
    local r = parent:FindFirstChild(name)
    if not r then
        for _, desc in ipairs(parent:GetDescendants()) do
            if (desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction")) and desc.Name == name then
                return desc
            end
        end
    end
    return r
end

-- =================================================================
-- 🖱️ MULTI-VECTOR UI BUTTON CLICK DISPATCHER
-- =================================================================
local function clickButton(btn)
    if not btn or not btn:IsA("GuiObject") then return end
    pcall(function()
        if typeof(firesignal) == "function" then
            if btn:IsA("GuiButton") then
                if btn.Activated then firesignal(btn.Activated) end
                if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
            end
        end
        if typeof(getconnections) == "function" then
            for _, ev in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down"}) do
                if btn[ev] then
                    for _, conn in ipairs(getconnections(btn[ev])) do
                        if conn.Function then conn.Function() elseif conn.Fire then conn:Fire() end
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 1. 📜 AUTO CLAIM DAILY & WEEKLY QUESTS (HANYA KETIKA SUDAH SELESAI)
-- =================================================================
function AutoClaim.ClaimQuests()
    pcall(function()
        local bpQuestFolder = RS:FindFirstChild("Modules") 
            and RS.Modules:FindFirstChild("Battlepass") 
            and RS.Modules.Battlepass:FindFirstChild("BattlepassQuest")
        
        if not bpQuestFolder then
            for _, desc in ipairs(RS:GetDescendants()) do
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

        -- Ambil data quest real-time pemain
        local s, questData = pcall(function() return getQuestFunc:InvokeServer() end)
        if not (s and type(questData) == "table") then return end

        local categories = {}
        if AutoClaim.Config.DailyQuest and type(questData.Daily) == "table" then
            categories["Daily"] = questData.Daily
        end
        if AutoClaim.Config.WeeklyQuest and type(questData.Weekly) == "table" then
            categories["Weekly"] = questData.Weekly
        end

        -- HANYA KLAIM JIKA: Completed == true DAN Claimed == false
        for category, list in pairs(categories) do
            for idx, qInfo in ipairs(list) do
                if type(qInfo) == "table" then
                    local isDone = (qInfo.Completed == true) or (qInfo.Progress and qInfo.Requirement and qInfo.Progress >= qInfo.Requirement)
                    local isNotClaimed = (qInfo.Claimed == false)

                    if isDone and isNotClaimed then
                        pcall(function() claimRemote:FireServer(category, idx) end)
                        if qInfo.ID then
                            pcall(function() claimRemote:FireServer(category, qInfo.ID) end)
                        end
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 2. 🏆 AUTO CLAIM BATTLEPASS TIER REWARDS (HANYA JIKA TERBUKA)
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
                if bpReward.Name == "BattlepassReward" then
                    -- Cek tombol reward yang aktif/siap klaim
                    for _, btn in ipairs(bpReward:GetDescendants()) do
                        if btn:IsA("GuiButton") and btn.Visible and btn.Active then
                            local txt = tostring(btn:IsA("TextButton") and btn.Text or ""):lower()
                            if txt:find("claim") or txt == "" then
                                clickButton(btn)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 3. 🎁 AUTO CLAIM FREE REWARDS, VIP & GROUP (HANYA JIKA SIAP)
-- =================================================================
function AutoClaim.ClaimFreeRewards()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local mainUI = pGui and pGui:FindFirstChild("MainUI")
        local frames = mainUI and mainUI:FindFirstChild("Frames")

        -- 1. VIP Claim (Hanya jika tombol aktif)
        if AutoClaim.Config.VIPAndGroup and frames and frames:FindFirstChild("VIPRewards") then
            local vipBtn = frames.VIPRewards:FindFirstChild("Frame")
                and frames.VIPRewards.Frame:FindFirstChild("Main")
                and frames.VIPRewards.Frame.Main:FindFirstChild("Claim")
                and frames.VIPRewards.Frame.Main.Claim:FindFirstChild("Claim")

            if vipBtn and vipBtn:IsA("GuiButton") and vipBtn.Visible and vipBtn.Active then
                clickButton(vipBtn)
            end
        end

        -- 2. Group Claim (Hanya jika tombol aktif)
        if AutoClaim.Config.VIPAndGroup and frames and frames:FindFirstChild("GroupRewards") then
            local grpBtn = frames.GroupRewards:FindFirstChild("Frame")
                and frames.GroupRewards.Frame:FindFirstChild("Main")
                and frames.GroupRewards.Frame.Main:FindFirstChild("Claim")
                and frames.GroupRewards.Frame.Main.Claim:FindFirstChild("Start")

            if grpBtn and grpBtn:IsA("GuiButton") and grpBtn.Visible and grpBtn.Active then
                clickButton(grpBtn)
            end
        end
    end)
end

-- =================================================================
-- 4. 🖥️ DEEP UI BUTTON CLAIM SCANNER (EXACT MAINUI.FRAMES ENGINE)
-- =================================================================
function AutoClaim.ScanAndClaimUI()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pGui then return end

        local mainUI = pGui:FindFirstChild("MainUI")
        local frames = mainUI and mainUI:FindFirstChild("Frames")

        -- 1. Klaim Tombol Quest di MainUI.Frames.Battlepass
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
                    if questReward.Name == "QuestReward" or questReward.Name:find("Quest") then
                        for _, desc in ipairs(questReward:GetDescendants()) do
                            if desc:IsA("GuiButton") and (desc.Name == "Button" or desc.Name:find("Claim")) then
                                clickButton(desc)
                            end
                        end
                    end
                end
            end
        end

        -- 2. Klaim Tombol Battlepass Tier di MainUI.Frames.Battlepass
        if AutoClaim.Config.Battlepass then
            local bpFrame = frames and frames:FindFirstChild("Battlepass")
            local bpContent = bpFrame and bpFrame:FindFirstChild("Frame")
                and bpFrame.Frame:FindFirstChild("Main")
                and bpFrame.Frame.Main:FindFirstChild("Battlepass")
                and bpFrame.Frame.Main.Battlepass:FindFirstChild("ScrollingFrame")
                and bpFrame.Frame.Main.Battlepass.ScrollingFrame:FindFirstChild("Content")
                and bpFrame.Frame.Main.Battlepass.ScrollingFrame.Content:FindFirstChild("Rewards")

            if bpContent then
                for _, bpReward in ipairs(bpContent:GetChildren()) do
                    if bpReward.Name == "BattlepassReward" or bpReward.Name:find("Reward") then
                        for _, desc in ipairs(bpReward:GetDescendants()) do
                            if desc:IsA("GuiButton") and (desc.Name == "Button" or desc.Name:find("Claim")) then
                                clickButton(desc)
                            end
                        end
                    end
                end
            end
        end

        -- 3. Klaim VIP Rewards
        if AutoClaim.Config.VIPAndGroup and frames and frames:FindFirstChild("VIPRewards") then
            local vipClaimBtn = frames.VIPRewards:FindFirstChild("Frame")
                and frames.VIPRewards.Frame:FindFirstChild("Main")
                and frames.VIPRewards.Frame.Main:FindFirstChild("Claim")
                and frames.VIPRewards.Frame.Main.Claim:FindFirstChild("Claim")

            if vipClaimBtn and vipClaimBtn:IsA("GuiButton") then
                clickButton(vipClaimBtn)
            end
        end

        -- 4. Klaim Group Rewards
        if AutoClaim.Config.VIPAndGroup and frames and frames:FindFirstChild("GroupRewards") then
            local groupClaimBtn = frames.GroupRewards:FindFirstChild("Frame")
                and frames.GroupRewards.Frame:FindFirstChild("Main")
                and frames.GroupRewards.Frame.Main:FindFirstChild("Claim")
                and frames.GroupRewards.Frame.Main.Claim:FindFirstChild("Start")

            if groupClaimBtn and groupClaimBtn:IsA("GuiButton") then
                clickButton(groupClaimBtn)
            end
        end

        -- 5. Generic Safe Sweep untuk tombol Claim lainnya
        for _, desc in ipairs(pGui:GetDescendants()) do
            if desc:IsA("GuiButton") then
                local txt = tostring(desc:IsA("TextButton") and desc.Text or ""):lower():gsub("%s+", "")
                local bName = desc.Name:lower():gsub("%s+", "")
                local pName = desc.Parent and desc.Parent.Name:lower() or ""

                if (txt == "claim" or txt == "claimall" or txt == "collect" or txt == "ambil") or
                   (bName == "claim" or bName == "claimbtn" or bName == "claimbutton") or
                   (pName:find("quest") and (txt:find("claim") or bName:find("claim"))) then
                    clickButton(desc)
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

    claimThread = task.spawn(function()
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

            task.wait(AutoClaim.Config.CheckInterval or 8)
        end
    end)
end

function AutoClaim.Stop()
    isRunning = false
    if claimThread then
        task.cancel(claimThread)
        claimThread = nil
    end
end

function AutoClaim.IsRunning()
    return isRunning
end

return AutoClaim
