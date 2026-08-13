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
-- 1. 📜 AUTO CLAIM DAILY & WEEKLY QUESTS (COMPREHENSIVE ENGINE)
-- =================================================================
function AutoClaim.ClaimQuests()
    pcall(function()
        -- 1. Cari Remote ClaimQuest & GetQuestData
        local claimQuestRemote = nil
        local getQuestDataFunc = nil
        local questDataModule = nil

        for _, desc in ipairs(RS:GetDescendants()) do
            if desc.Name == "ClaimQuest" and desc:IsA("RemoteEvent") then
                claimQuestRemote = desc
            elseif desc.Name == "GetQuestData" and desc:IsA("RemoteFunction") then
                getQuestDataFunc = desc
            elseif desc.Name == "Quest" and desc:IsA("ModuleScript") and desc.Parent and desc.Parent.Name == "BattlepassQuest" then
                pcall(function() questDataModule = require(desc) end)
            end
        end

        -- 2. Coba baca data quest aktif dari server jika RemoteFunction tersedia
        if getQuestDataFunc then
            local s, data = pcall(function() return getQuestDataFunc:InvokeServer() end)
            if s and type(data) == "table" and claimQuestRemote then
                -- Scan Daily Quests dari data server
                if AutoClaim.Config.DailyQuest and data.Daily then
                    for qKey, qVal in pairs(data.Daily) do
                        if type(qVal) == "table" then
                            local isDone = qVal.Completed or qVal.Done or (qVal.Progress and qVal.Target and qVal.Progress >= qVal.Target)
                            if isDone and not qVal.Claimed then
                                pcall(function() claimQuestRemote:FireServer("Daily", qKey) end)
                                pcall(function() claimQuestRemote:FireServer(qKey) end)
                                if qVal.Name then pcall(function() claimQuestRemote:FireServer("Daily", qVal.Name) end) end
                                if qVal.Id then pcall(function() claimQuestRemote:FireServer("Daily", qVal.Id) end) end
                            end
                        else
                            pcall(function() claimQuestRemote:FireServer("Daily", qKey) end)
                        end
                    end
                end

                -- Scan Weekly Quests dari data server
                if AutoClaim.Config.WeeklyQuest and data.Weekly then
                    for qKey, qVal in pairs(data.Weekly) do
                        if type(qVal) == "table" then
                            local isDone = qVal.Completed or qVal.Done or (qVal.Progress and qVal.Target and qVal.Progress >= qVal.Target)
                            if isDone and not qVal.Claimed then
                                pcall(function() claimQuestRemote:FireServer("Weekly", qKey) end)
                                pcall(function() claimQuestRemote:FireServer(qKey) end)
                                if qVal.Name then pcall(function() claimQuestRemote:FireServer("Weekly", qVal.Name) end) end
                                if qVal.Id then pcall(function() claimQuestRemote:FireServer("Weekly", qVal.Id) end) end
                            end
                        else
                            pcall(function() claimQuestRemote:FireServer("Weekly", qKey) end)
                        end
                    end
                end
            end
        end

        -- 3. Coba klaim berdasarkan modul definisi quest internal game
        if questDataModule and claimQuestRemote then
            if AutoClaim.Config.DailyQuest and questDataModule.Daily then
                for qKey, qVal in pairs(questDataModule.Daily) do
                    pcall(function() claimQuestRemote:FireServer("Daily", qKey) end)
                    if type(qVal) == "table" and qVal.Name then
                        pcall(function() claimQuestRemote:FireServer("Daily", qVal.Name) end)
                    end
                end
            end
            if AutoClaim.Config.WeeklyQuest and questDataModule.Weekly then
                for qKey, qVal in pairs(questDataModule.Weekly) do
                    pcall(function() claimQuestRemote:FireServer("Weekly", qKey) end)
                    if type(qVal) == "table" and qVal.Name then
                        pcall(function() claimQuestRemote:FireServer("Weekly", qVal.Name) end)
                    end
                end
            end
        end

        -- 4. Pola Index Universal (Slot 1 sampai 15)
        if claimQuestRemote then
            for i = 1, 15 do
                if AutoClaim.Config.DailyQuest then
                    pcall(function() claimQuestRemote:FireServer("Daily", i) end)
                    pcall(function() claimQuestRemote:FireServer("Daily", tostring(i)) end)
                    pcall(function() claimQuestRemote:FireServer(i) end)
                    pcall(function() claimQuestRemote:FireServer(tostring(i)) end)
                end
                if AutoClaim.Config.WeeklyQuest then
                    pcall(function() claimQuestRemote:FireServer("Weekly", i) end)
                    pcall(function() claimQuestRemote:FireServer("Weekly", tostring(i)) end)
                end
            end
        end

        -- 5. Faction Quest Support
        for _, desc in ipairs(RS:GetDescendants()) do
            if (desc.Name == "ClaimFactionQuest" or desc.Name == "FactionClaim") and desc:IsA("RemoteEvent") then
                for i = 1, 10 do
                    pcall(function() desc:FireServer(i) end)
                    pcall(function() desc:FireServer("Daily", i) end)
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
        for _, desc in ipairs(RS:GetDescendants()) do
            if (desc.Name == "Claim" or desc.Name == "ClaimBattlepass" or desc.Name == "ClaimReward") and desc:IsA("RemoteEvent") then
                local pName = desc.Parent and desc.Parent.Name or ""
                if pName:find("Battlepass") or pName:find("Reward") or desc.Name:find("Battlepass") then
                    for tier = 1, 50 do
                        pcall(function() desc:FireServer(tier) end)
                        pcall(function() desc:FireServer("Free", tier) end)
                        pcall(function() desc:FireServer("Premium", tier) end)
                    end
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
            -- Playtime gifts
            if AutoClaim.Config.FreeRewards then
                local freeRewards = remotes:FindFirstChild("FreeRewards")
                if freeRewards then
                    local updateProgress = freeRewards:FindFirstChild("UpdateProgress")
                    if updateProgress and updateProgress:IsA("RemoteEvent") then
                        for slot = 1, 15 do
                            pcall(function() updateProgress:FireServer(slot) end)
                        end
                    end
                    local freeGroup = freeRewards:FindFirstChild("FreeGroup")
                    if freeGroup and freeGroup:IsA("RemoteEvent") then
                        pcall(function() freeGroup:FireServer() end)
                    end
                end
            end

            -- VIP Reward
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
-- 4. 🖥️ DEEP UI BUTTON CLAIM SCANNER (AUTO CLICK IN-GAME CLAIM BUTTONS)
-- =================================================================
function AutoClaim.ScanAndClaimUI()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pGui then return end

        for _, desc in ipairs(pGui:GetDescendants()) do
            if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                local txt = tostring(desc.Text or ""):lower():gsub("%s+", "")
                local bName = desc.Name:lower():gsub("%s+", "")
                local pName = desc.Parent and desc.Parent.Name:lower() or ""
                
                local isClaim = (txt == "claim" or txt == "claimall" or txt == "collect" or txt == "ambil" or txt == "klaim") or
                                (bName == "claim" or bName == "claimbtn" or bName == "claimbutton" or bName == "collectbtn" or bName == "rewardbtn") or
                                (pName:find("quest") and (txt:find("claim") or bName:find("claim")))

                if isClaim and desc.Visible then
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
