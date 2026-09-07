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

local dailyRE = nil
local groupRE = nil
local offlineRE = nil
local rebirthRE = nil

local function getRemotes()
    local net = ReplicatedStorage:FindFirstChild("Network")
    if not net then return end

    if not dailyRE then
        local svc = net:FindFirstChild("DailyRewardService")
        local re = svc and svc:FindFirstChild("RE")
        dailyRE = re and re:FindFirstChild("Claim")
    end

    if not groupRE then
        local svc = net:FindFirstChild("GroupRewardService")
        local re = svc and svc:FindFirstChild("RE")
        groupRE = re and re:FindFirstChild("Claim")
    end

    if not offlineRE then
        local svc = net:FindFirstChild("OfflineEarningsService")
        local re = svc and svc:FindFirstChild("RE")
        offlineRE = re and re:FindFirstChild("Claim")
    end

    if not rebirthRE then
        local svc = net:FindFirstChild("RebirthService")
        local re = svc and svc:FindFirstChild("RE")
        rebirthRE = re and re:FindFirstChild("Rebirth")
    end
end

function AutoRewards.ClaimDaily()
    getRemotes()
    if dailyRE then return pcall(function() dailyRE:FireServer() end) end
    return false
end

function AutoRewards.ClaimGroup()
    getRemotes()
    if groupRE then return pcall(function() groupRE:FireServer() end) end
    return false
end

function AutoRewards.ClaimOffline()
    getRemotes()
    if offlineRE then return pcall(function() offlineRE:FireServer() end) end
    return false
end

function AutoRewards.RebirthOnce()
    getRemotes()
    if rebirthRE then return pcall(function() rebirthRE:FireServer() end) end
    return false
end

function AutoRewards.ClaimAllOnce()
    AutoRewards.ClaimDaily()
    AutoRewards.ClaimGroup()
    AutoRewards.ClaimOffline()
end

AutoRewards.IsRunning = false
local loopThread = nil

function AutoRewards.Start()
    if AutoRewards.IsRunning then return end
    AutoRewards.IsRunning = true

    loopThread = task.spawn(function()
        local tickRewards = 0
        local tickRebirth = 0

        while AutoRewards.IsRunning do
            local cfg = _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig or {}
            local now = tick()

            -- Claim Rewards every 30s
            if (now - tickRewards) >= 30 then
                tickRewards = now
                if cfg.AutoClaimDaily then AutoRewards.ClaimDaily() end
                if cfg.AutoClaimGroup then AutoRewards.ClaimGroup() end
                if cfg.AutoClaimOffline then AutoRewards.ClaimOffline() end
            end

            -- Rebirth check every 15s
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
