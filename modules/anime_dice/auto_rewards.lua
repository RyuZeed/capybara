--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO REWARDS & REBIRTH ENGINE)
	Module: modules/anime_dice/auto_rewards.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AutoRewards = {}
AutoRewards.__index = AutoRewards

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local dailyRE = network and network:FindFirstChild("DailyRewardService") and network.DailyRewardService:FindFirstChild("RE") and network.DailyRewardService.RE:FindFirstChild("Claim")
local groupRE = network and network:FindFirstChild("GroupRewardService") and network.GroupRewardService:FindFirstChild("RE") and network.GroupRewardService.RE:FindFirstChild("Claim")
local offlineRE = network and network:FindFirstChild("OfflineEarningsService") and network.OfflineEarningsService:FindFirstChild("RE") and network.OfflineEarningsService.RE:FindFirstChild("Claim")
local questRE = network and network:FindFirstChild("QuestService") and network.QuestService:FindFirstChild("RE") and network.QuestService.RE:FindFirstChild("Claim")
local rebirthRE = network and network:FindFirstChild("RebirthService") and network.RebirthService:FindFirstChild("RE") and network.RebirthService.RE:FindFirstChild("Rebirth")

local QUEST_LIST = {"Playtime", "Rolls", "Towers", "UnitsSold"}

local function getRemotes()
    local net = ReplicatedStorage:FindFirstChild("Network")
    if not net then return end
    if not dailyRE then
        local svc = net:FindFirstChild("DailyRewardService")
        if svc then
            local re = svc:FindFirstChild("RE")
            if re then dailyRE = re:FindFirstChild("Claim") end
        end
    end
    if not groupRE then
        local svc = net:FindFirstChild("GroupRewardService")
        if svc then
            local re = svc:FindFirstChild("RE")
            if re then groupRE = re:FindFirstChild("Claim") end
        end
    end
    if not offlineRE then
        local svc = net:FindFirstChild("OfflineEarningsService")
        if svc then
            local re = svc:FindFirstChild("RE")
            if re then offlineRE = re:FindFirstChild("Claim") end
        end
    end
    if not questRE then
        local svc = net:FindFirstChild("QuestService")
        if svc then
            local re = svc:FindFirstChild("RE")
            if re then questRE = re:FindFirstChild("Claim") end
        end
    end
    if not rebirthRE then
        local svc = net:FindFirstChild("RebirthService")
        if svc then
            local re = svc:FindFirstChild("RE")
            if re then rebirthRE = re:FindFirstChild("Rebirth") end
        end
    end
end

function AutoRewards.ClaimDaily()
    getRemotes()
    if dailyRE then pcall(function() dailyRE:FireServer() end) end
end

function AutoRewards.ClaimGroup()
    getRemotes()
    if groupRE then pcall(function() groupRE:FireServer() end) end
end

function AutoRewards.ClaimOffline()
    getRemotes()
    if offlineRE then pcall(function() offlineRE:FireServer() end) end
end

function AutoRewards.ClaimQuests()
    getRemotes()
    if questRE then
        for _, q in ipairs(QUEST_LIST) do
            pcall(function() questRE:FireServer(q) end)
            task.wait(0.05)
        end
    end
end

function AutoRewards.RebirthOnce()
    getRemotes()
    if rebirthRE then
        return pcall(function() rebirthRE:FireServer() end)
    end
    return false
end

function AutoRewards.ClaimAllOnce()
    AutoRewards.ClaimDaily()
    AutoRewards.ClaimGroup()
    AutoRewards.ClaimOffline()
    AutoRewards.ClaimQuests()
end

AutoRewards.IsRunning = false
local loopThread = nil

function AutoRewards.Start()
    if AutoRewards.IsRunning then return end
    AutoRewards.IsRunning = true

    loopThread = task.spawn(function()
        local tickRewards = 0
        local tickQuests = 0
        local tickRebirth = 0

        while AutoRewards.IsRunning do
            local cfg = _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig or {}
            local now = tick()

            -- Rewards (every 30s)
            if (now - tickRewards) >= 30 then
                tickRewards = now
                if cfg.AutoClaimDaily then AutoRewards.ClaimDaily() end
                if cfg.AutoClaimGroup then AutoRewards.ClaimGroup() end
                if cfg.AutoClaimOffline then AutoRewards.ClaimOffline() end
            end

            -- Quests (every 10s)
            if cfg.AutoClaimQuests and (now - tickQuests) >= 10 then
                tickQuests = now
                AutoRewards.ClaimQuests()
            end

            -- Rebirth (every 15s)
            if cfg.AutoRebirth and (now - tickRebirth) >= 15 then
                tickRebirth = now
                AutoRewards.RebirthOnce()
            end

            task.wait(1.0)
        end
    end)
end

function AutoRewards.Stop()
    AutoRewards.IsRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

function AutoRewards.StopAll()
    AutoRewards.Stop()
end

_G.AnimeDiceAutoRewards = AutoRewards
return AutoRewards
