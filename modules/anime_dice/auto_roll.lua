--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO ROLL ENGINE)
	Module: modules/anime_dice/auto_roll.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AutoRoll = {}
AutoRoll.__index = AutoRoll

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local rollServiceRF = network and network:FindFirstChild("RollService") and network.RollService:FindFirstChild("RF") and network.RollService.RF:FindFirstChild("RollDice")
local rollServiceRE = network and network:FindFirstChild("RollService") and network.RollService:FindFirstChild("RE") and network.RollService.RE:FindFirstChild("SetAutoRoll")

AutoRoll.IsRolling = false
local rollThread = nil

function AutoRoll.RollOnce()
    if not rollServiceRF then
        local rf = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network.RollService.RF:FindFirstChild("RollDice")
        if rf then rollServiceRF = rf end
    end
    if rollServiceRF then
        local ok, res = pcall(function()
            return rollServiceRF:InvokeServer()
        end)
        return ok, res
    end
    return false, "RollDice RemoteFunction not found"
end

function AutoRoll.SetInGameAutoRoll(state)
    if not rollServiceRE then
        local re = ReplicatedStorage:FindFirstChild("Network") and ReplicatedStorage.Network.RollService.RE:FindFirstChild("SetAutoRoll")
        if re then rollServiceRE = re end
    end
    if rollServiceRE then
        pcall(function()
            rollServiceRE:FireServer(state)
        end)
    end
end

function AutoRoll.Start(delaySec)
    if AutoRoll.IsRolling then return end
    AutoRoll.IsRolling = true

    rollThread = task.spawn(function()
        while AutoRoll.IsRolling do
            local delay = delaySec
            if _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig then
                delay = _G.AnimeDiceConfigManager.CurrentConfig.RollDelay or delay
            end
            delay = math.max(0.05, tonumber(delay) or 0.1)

            AutoRoll.RollOnce()
            task.wait(delay)
        end
    end)
end

function AutoRoll.Stop()
    AutoRoll.IsRolling = false
    if rollThread then
        task.cancel(rollThread)
        rollThread = nil
    end
end

function AutoRoll.StopAll()
    AutoRoll.Stop()
    AutoRoll.SetInGameAutoRoll(false)
end

_G.AnimeDiceAutoRoll = AutoRoll
return AutoRoll
