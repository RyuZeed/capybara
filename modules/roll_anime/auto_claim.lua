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
    CheckInterval = 8
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
-- 1. 📜 AUTO CLAIM DAILY & WEEKLY QUESTS
-- =================================================================
function AutoClaim.ClaimQuests()
    pcall(function()
        local bpFolder = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Battlepass")
        local questFolder = bpFolder and bpFolder:FindFirstChild("BattlepassQuest")
        
        if not questFolder then
            for _, desc in ipairs(RS:GetDescendants()) do
                if desc.Name == "BattlepassQuest" and desc:IsA("Folder") then
                    questFolder = desc; break
                end
            end
        end

        if questFolder then
            local claimQuestRemote = questFolder:FindFirstChild("ClaimQuest")
            local getQuestDataFunc = questFolder:FindFirstChild("GetQuestData")

            if getQuestDataFunc and getQuestDataFunc:IsA("RemoteFunction") then
                local s, data = pcall(function() return getQuestDataFunc:InvokeServer() end)
                if s and type(data) == "table" then
                    -- Scan Daily Quests
                    if AutoClaim.Config.DailyQuest and data.Daily then
                        for qId, qInfo in pairs(data.Daily) do
                            if type(qInfo) == "table" and qInfo.Completed and not qInfo.Claimed then
                                if claimQuestRemote and claimQuestRemote:IsA("RemoteEvent") then
                                    claimQuestRemote:FireServer("Daily", qId)
                                end
                            end
                        end
                    end
                    -- Scan Weekly Quests
                    if AutoClaim.Config.WeeklyQuest and data.Weekly then
                        for qId, qInfo in pairs(data.Weekly) do
                            if type(qInfo) == "table" and qInfo.Completed and not qInfo.Claimed then
                                if claimQuestRemote and claimQuestRemote:IsA("RemoteEvent") then
                                    claimQuestRemote:FireServer("Weekly", qId)
                                end
                            end
                        end
                    end
                end
            end

            -- Direct safety sweep for generic quest index slots
            if claimQuestRemote and claimQuestRemote:IsA("RemoteEvent") then
                for i = 1, 10 do
                    if AutoClaim.Config.DailyQuest then
                        pcall(function() claimQuestRemote:FireServer("Daily", i) end)
                        pcall(function() claimQuestRemote:FireServer(i) end)
                    end
                    if AutoClaim.Config.WeeklyQuest then
                        pcall(function() claimQuestRemote:FireServer("Weekly", i) end)
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 2. 🏆 AUTO CLAIM BATTLEPASS TIER REWARDS
-- =================================================================
function AutoClaim.ClaimBattlepass()
    if not AutoClaim.Config.Battlepass then return end
    pcall(function()
        local bpFolder = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Battlepass")
        if bpFolder then
            local bpClaimRemote = bpFolder:FindFirstChild("Claim")
            if bpClaimRemote and bpClaimRemote:IsA("RemoteEvent") then
                for tier = 1, 50 do
                    pcall(function() bpClaimRemote:FireServer(tier) end)
                end
            end
        end
    end)
end

-- =================================================================
-- 3. 🎁 AUTO CLAIM FREE REWARDS, VIP & GROUP REWARDS
-- =================================================================
function AutoClaim.ClaimFreeRewards()
    pcall(function()
        local remotes = RS:FindFirstChild("Remotes")
        if remotes then
            -- 1. Free Rewards / Playtime gifts
            if AutoClaim.Config.FreeRewards then
                local freeRewards = remotes:FindFirstChild("FreeRewards")
                if freeRewards then
                    local updateProgress = freeRewards:FindFirstChild("UpdateProgress")
                    if updateProgress and updateProgress:IsA("RemoteEvent") then
                        for slot = 1, 12 do
                            pcall(function() updateProgress:FireServer(slot) end)
                        end
                    end
                    local freeGroup = freeRewards:FindFirstChild("FreeGroup")
                    if freeGroup and freeGroup:IsA("RemoteEvent") then
                        pcall(function() freeGroup:FireServer() end)
                    end
                end
            end

            -- 2. VIP Reward
            if AutoClaim.Config.VIPAndGroup then
                local claimVIP = remotes:FindFirstChild("ClaimVIP")
                if claimVIP and claimVIP:IsA("RemoteEvent") then
                    pcall(function() claimVIP:FireServer() end)
                end
            end
        end
    end)
end

-- =================================================================
-- 4. 🖥️ SCAN GUI BUTTONS UNTUK KLAIM TAMPILAN
-- =================================================================
function AutoClaim.ScanAndClaimUI()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pGui then return end

        for _, desc in ipairs(pGui:GetDescendants()) do
            if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                local txt = tostring(desc.Text or ""):lower()
                local bName = desc.Name:lower()
                if txt == "claim" or txt == "claim all" or txt == "collect" or bName == "claimbutton" or bName == "claim" then
                    if desc.Visible and desc.Active then
                        clickButton(desc)
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
