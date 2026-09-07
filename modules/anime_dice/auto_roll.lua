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

local function getRemotes()
    local net = ReplicatedStorage:FindFirstChild("Network")
    if not net then return nil, nil end
    local rollSvc = net:FindFirstChild("RollService")
    if not rollSvc then return nil, nil end

    local re = rollSvc:FindFirstChild("RE")
    local rf = rollSvc:FindFirstChild("RF")

    local setAutoRollRE = re and re:FindFirstChild("SetAutoRoll")
    local rollDiceRF = rf and rf:FindFirstChild("RollDice")

    return setAutoRollRE, rollDiceRF
end

AutoRoll.IsRolling = false
local rollThread = nil

-- 1. Native In-Game Auto Roll Toggle
function AutoRoll.SetNativeAutoRoll(state)
    local setAutoRollRE = getRemotes()
    if setAutoRollRE then
        return pcall(function()
            setAutoRollRE:FireServer(state)
        end)
    end
    return false
end

-- 2. Fast Server Roll Single Invocation
function AutoRoll.RollOnce()
    local _, rollDiceRF = getRemotes()
    if rollDiceRF then
        return pcall(function()
            return rollDiceRF:InvokeServer()
        end)
    end
    return false
end

-- 3. Custom Fast Roll Loop
function AutoRoll.Start(delaySec)
    if AutoRoll.IsRolling then return end
    AutoRoll.IsRolling = true
    delaySec = math.max(0.05, tonumber(delaySec) or 0.1)

    rollThread = task.spawn(function()
        while AutoRoll.IsRolling do
            local delay = delaySec
            if _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig then
                local cfgDelay = _G.AnimeDiceConfigManager.CurrentConfig.RollDelay
                if cfgDelay then delay = cfgDelay end
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
    AutoRoll.SetNativeAutoRoll(false)
end

_G.AnimeDiceAutoRoll = AutoRoll
return AutoRoll
