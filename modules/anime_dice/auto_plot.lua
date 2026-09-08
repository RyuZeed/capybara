--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO PLOT & FARM ENGINE)
	Module: modules/anime_dice/auto_plot.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AutoPlot = {}
AutoPlot.__index = AutoPlot

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local plotRE = network and network:FindFirstChild("PlotService") and network.PlotService:FindFirstChild("RE")
local collectRE = plotRE and plotRE:FindFirstChild("CollectBalance")
local equipBestRE = plotRE and plotRE:FindFirstChild("EquipBest")
local levelUpSlotRE = plotRE and plotRE:FindFirstChild("LevelUpSlot")

AutoPlot.MAX_SLOTS = 13
AutoPlot.IsRunning = false
AutoPlot.CollectCash = true
AutoPlot.CollectInterval = 30
AutoPlot.EquipBest = true
AutoPlot.UpgradeSlots = false
AutoPlot.LevelUpByRebirth = false
AutoPlot.LevelMultiplierPerRebirth = 10

local SLOT_REBIRTH_REQS = {
    [1] = 0, [2] = 0, [3] = 0, [4] = 0,
    [5] = 1, [6] = 2, [7] = 3, [8] = 4,
    [9] = 6, [10] = 7, [11] = 8, [12] = 9, [13] = 10
}

function AutoPlot.GetPlayerRebirth()
    local rebirth = 0
    pcall(function()
        local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
        rebirth = (DataController.Rebirth and DataController.Rebirth()) or 0
    end)
    return rebirth
end

function AutoPlot.GetSlotRebirthRequirement(slot)
    if SLOT_REBIRTH_REQS[slot] ~= nil then
        return SLOT_REBIRTH_REQS[slot]
    end
    local req = nil
    pcall(function()
        local PlotConfig = require(ReplicatedStorage.Framework.Features.Plot.PlotConfig)
        req = PlotConfig.GetSlotRebirthRequirement and PlotConfig.GetSlotRebirthRequirement(slot)
    end)
    return req or 0
end

function AutoPlot.IsSlotUnlocked(slot)
    local req = AutoPlot.GetSlotRebirthRequirement(slot)
    return AutoPlot.GetPlayerRebirth() >= req
end

function AutoPlot.GetTargetLevelForRebirth()
    local rebirth = AutoPlot.GetPlayerRebirth()
    local mult = AutoPlot.LevelMultiplierPerRebirth or 10
    return math.max(10, (rebirth + 1) * mult)
end

local loopThread = nil

local function getRemotes()
    if not collectRE or not equipBestRE or not levelUpSlotRE then
        local net = ReplicatedStorage:FindFirstChild("Network")
        if net and net:FindFirstChild("PlotService") and net.PlotService:FindFirstChild("RE") then
            collectRE = net.PlotService.RE:FindFirstChild("CollectBalance") or collectRE
            equipBestRE = net.PlotService.RE:FindFirstChild("EquipBest") or equipBestRE
            levelUpSlotRE = net.PlotService.RE:FindFirstChild("LevelUpSlot") or levelUpSlotRE
        end
    end
end

local function playCollectSound()
    pcall(function()
        local sound = ReplicatedStorage:FindFirstChild("Assets")
            and ReplicatedStorage.Assets:FindFirstChild("Sounds")
            and ReplicatedStorage.Assets.Sounds:FindFirstChild("Collect")
        if sound then
            local s = sound:Clone()
            s.Parent = workspace
            s:Play()
            game:GetService("Debris"):AddItem(s, 1.2)
        end
    end)
end

function AutoPlot.CollectBalanceOnce(slotIndex)
    getRemotes()
    if collectRE then
        local collectedAny = false
        pcall(function()
            local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
            if DataController and DataController.Slots then
                if slotIndex then
                    local sData = DataController.Slots[tostring(slotIndex)] and DataController.Slots[tostring(slotIndex)]()
                    if sData and sData.balance and sData.balance > 0 then
                        collectedAny = true
                    end
                else
                    for slot = 1, AutoPlot.MAX_SLOTS do
                        if AutoPlot.IsSlotUnlocked(slot) then
                            local sData = DataController.Slots[tostring(slot)] and DataController.Slots[tostring(slot)]()
                            if sData and sData.balance and sData.balance > 0 then
                                collectedAny = true
                                break
                            end
                        end
                    end
                end
            end
        end)

        if slotIndex then
            pcall(function() collectRE:FireServer(slotIndex) end)
        else
            for slot = 1, AutoPlot.MAX_SLOTS do
                if AutoPlot.IsSlotUnlocked(slot) then
                    pcall(function() collectRE:FireServer(slot) end)
                end
            end
        end

        if collectedAny then
            playCollectSound()
        end
        return true
    end
    return false
end

function AutoPlot.EquipBestOnce()
    getRemotes()
    if equipBestRE then
        return pcall(function() equipBestRE:FireServer() end)
    end
    return false
end

AutoPlot.UpgradeTimes = 5 -- Berapa kali upgrade default
AutoPlot.TargetSlot = 0 -- 0 = Semua Slot, 1..13 = Slot tertentu
AutoPlot.SlotRemaining = {} -- [slotIndex] = remainingQuota
AutoPlot.OnUpgradeCompleted = nil -- callback ketika kuota upgrade selesai

function AutoPlot.StartAutoUpgradeSession(times, targetSlot)
    times = math.max(1, tonumber(times) or 1)
    targetSlot = tonumber(targetSlot) or 0
    AutoPlot.UpgradeTimes = times
    AutoPlot.TargetSlot = targetSlot
    AutoPlot.SlotRemaining = {}

    if targetSlot > 0 then
        AutoPlot.SlotRemaining[targetSlot] = times
    else
        for s = 1, AutoPlot.MAX_SLOTS do
            if AutoPlot.IsSlotUnlocked(s) then
                local info = AutoPlot.GetSlotUnitInfo(s)
                if info.hasUnit then
                    AutoPlot.SlotRemaining[s] = times
                end
            end
        end
    end
    AutoPlot.UpgradeSlots = true
end

function AutoPlot.StopAutoUpgradeSession()
    AutoPlot.UpgradeSlots = false
    AutoPlot.SlotRemaining = {}
end

function AutoPlot.GetRemainingQuota(slotIndex)
    if slotIndex and slotIndex > 0 then
        return AutoPlot.SlotRemaining[slotIndex] or 0
    end
    local total = 0
    for _, rem in pairs(AutoPlot.SlotRemaining) do
        total = total + rem
    end
    return total
end

function AutoPlot.GetSlotUnitInfo(slotIdx)
    local info = {
        slot = slotIdx,
        hasUnit = false,
        unitId = nil,
        unitName = "Kosong",
        level = 0,
        rarity = "None",
        grade = "-",
        mutation = "None",
        trait = "None",
        price = 0,
        canAfford = false,
        balance = 0
    }
    pcall(function()
        local DataController = require(ReplicatedStorage.Framework.Features.Data.DataController)
        local EntryRegistry = require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry)
        local UnitUtil = require(ReplicatedStorage.Framework.Features.Inventory.Kinds.Unit.UnitUtil)

        local slots = DataController.Slots and DataController.Slots()
        local slotData = slots and slots[tostring(slotIdx)]
        if slotData then
            info.balance = slotData.balance or 0
            if slotData.unitId then
                local unitItem = DataController.Inventory[slotData.unitId] and DataController.Inventory[slotData.unitId]()
                if unitItem then
                    local attrs = unitItem.attributes or {}
                    local cfg = EntryRegistry.getEntryConfig(unitItem.name)
                    local price = UnitUtil.GetLevelPrice(unitItem.name, attrs)
                    local myMoney = DataController.Money and DataController.Money() or 0

                    info.hasUnit = true
                    info.unitId = slotData.unitId
                    info.unitName = unitItem.name
                    info.level = attrs.level or 1
                    info.rarity = cfg and cfg.rarity or "Common"
                    info.grade = attrs.grade or "F"
                    info.mutation = attrs.mutation or "None"
                    info.trait = attrs.trait or "None"
                    info.price = price
                    info.canAfford = (myMoney >= price)
                end
            end
        end
    end)
    info.isUnlocked = AutoPlot.IsSlotUnlocked(slotIdx)
    info.requiredRebirth = AutoPlot.GetSlotRebirthRequirement(slotIdx)
    return info
end

function AutoPlot.GetAllSlotsInfo()
    local all = {}
    for i = 1, AutoPlot.MAX_SLOTS do
        table.insert(all, AutoPlot.GetSlotUnitInfo(i))
    end
    return all
end

function AutoPlot.UpgradeSlot(slotIndex)
    getRemotes()
    if levelUpSlotRE then
        return pcall(function() levelUpSlotRE:FireServer(slotIndex) end)
    end
    return false
end

function AutoPlot.UpgradeSlotTimes(slotIndex, times)
    getRemotes()
    times = math.max(1, tonumber(times) or 1)
    local upgraded = 0
    for i = 1, times do
        local info = AutoPlot.GetSlotUnitInfo(slotIndex)
        if not info.hasUnit or not info.canAfford then
            break
        end
        local ok = AutoPlot.UpgradeSlot(slotIndex)
        if ok then
            upgraded = upgraded + 1
            task.wait(0.2)
        else
            break
        end
    end
    return upgraded
end

function AutoPlot.UpgradeAllSlotsTimes(times)
    times = math.max(1, tonumber(times) or 1)
    local total = 0
    for slot = 1, AutoPlot.MAX_SLOTS do
        if AutoPlot.IsSlotUnlocked(slot) then
            local count = AutoPlot.UpgradeSlotTimes(slot, times)
            total = total + count
            task.wait(0.05)
        end
    end
    return total
end

function AutoPlot.UpgradeAllSlotsOnce()
    return AutoPlot.UpgradeAllSlotsTimes(1)
end

function AutoPlot.LevelUpSlotsByRebirthOnce()
    local targetLv = AutoPlot.GetTargetLevelForRebirth()
    local upgraded = 0
    for slot = 1, AutoPlot.MAX_SLOTS do
        if AutoPlot.IsSlotUnlocked(slot) then
            local info = AutoPlot.GetSlotUnitInfo(slot)
            if info.hasUnit and info.level < targetLv and info.canAfford then
                local ok = AutoPlot.UpgradeSlot(slot)
                if ok then
                    upgraded = upgraded + 1
                    task.wait(0.15)
                end
            end
        end
    end
    return upgraded
end

function AutoPlot.Start()
    if AutoPlot.IsRunning then return end
    AutoPlot.IsRunning = true

    loopThread = task.spawn(function()
        local tickCollect = 0
        local tickEquip = 0
        local tickUpgrade = 0
        local tickLevelUpRebirth = 0

        while AutoPlot.IsRunning do
            local now = tick()
            local cfg = _G.AnimeDiceConfigManager and _G.AnimeDiceConfigManager.CurrentConfig

            -- Prioritas: AutoPlot.CollectCash property atau Config
            local shouldCollect = AutoPlot.CollectCash
            if cfg and cfg.AutoCollectCash ~= nil then
                shouldCollect = cfg.AutoCollectCash
            end

            -- Auto Collect Cash (cooldown default 30 detik)
            local interval = AutoPlot.CollectInterval or 30
            if cfg and cfg.CollectCashInterval then
                interval = tonumber(cfg.CollectCashInterval) or interval
            end
            if shouldCollect and (now - tickCollect) >= interval then
                tickCollect = now
                AutoPlot.CollectBalanceOnce()
            end

            -- Auto Equip Best (setiap 3.5 detik)
            local shouldEquip = AutoPlot.EquipBest
            if cfg and cfg.AutoEquipBest ~= nil then
                shouldEquip = cfg.AutoEquipBest
            end
            if shouldEquip and (now - tickEquip) >= 3.5 then
                tickEquip = now
                AutoPlot.EquipBestOnce()
            end

            -- Auto Upgrade Slots dengan target unit & batasan kuota (tidak lebih dari X kali)
            local shouldUpgrade = AutoPlot.UpgradeSlots
            if cfg and cfg.AutoUpgradeSlots ~= nil then
                shouldUpgrade = cfg.AutoUpgradeSlots
            end
            local targetSlot = AutoPlot.TargetSlot or 0
            if cfg and cfg.SlotUpgradeTargetSlot ~= nil then
                targetSlot = tonumber(cfg.SlotUpgradeTargetSlot) or 0
            end
            local targetTimes = AutoPlot.UpgradeTimes or 5
            if cfg and cfg.SlotUpgradeTargetTimes ~= nil then
                targetTimes = tonumber(cfg.SlotUpgradeTargetTimes) or 5
            end

            if shouldUpgrade and (now - tickUpgrade) >= 2.0 then
                tickUpgrade = now

                -- Inisialisasi kuota jika kosong
                local hasAnySlot = false
                for _, _ in pairs(AutoPlot.SlotRemaining) do
                    hasAnySlot = true
                    break
                end
                if not hasAnySlot then
                    AutoPlot.StartAutoUpgradeSession(targetTimes, targetSlot)
                end

                local hasRemaining = false

                if targetSlot > 0 then
                    local rem = AutoPlot.SlotRemaining[targetSlot] or 0
                    if rem > 0 then
                        local did = AutoPlot.UpgradeSlotTimes(targetSlot, rem)
                        if did > 0 then
                            AutoPlot.SlotRemaining[targetSlot] = math.max(0, rem - did)
                        end
                        if (AutoPlot.SlotRemaining[targetSlot] or 0) > 0 then
                            hasRemaining = true
                        end
                    end
                else
                    for s = 1, AutoPlot.MAX_SLOTS do
                        if AutoPlot.IsSlotUnlocked(s) then
                            local rem = AutoPlot.SlotRemaining[s] or 0
                            if rem > 0 then
                                local did = AutoPlot.UpgradeSlotTimes(s, rem)
                                if did > 0 then
                                    AutoPlot.SlotRemaining[s] = math.max(0, rem - did)
                                end
                                if (AutoPlot.SlotRemaining[s] or 0) > 0 then
                                    hasRemaining = true
                                end
                            end
                        end
                    end
                end

                -- Jika kuota telah terpenuhi (tidak lebih dari target):
                if not hasRemaining then
                    AutoPlot.UpgradeSlots = false
                    AutoPlot.SlotRemaining = {}
                    if cfg then cfg.AutoUpgradeSlots = false end
                    if _G.AnimeDiceConfigManager then _G.AnimeDiceConfigManager.Save() end
                    if AutoPlot.OnUpgradeCompleted then
                        pcall(AutoPlot.OnUpgradeCompleted, targetTimes, targetSlot)
                    end
                end
            end

            -- Auto Level Up Sesuai Rebirth (target level otomatis mengikuti Rebirth player)
            local shouldLevelUpByRebirth = AutoPlot.LevelUpByRebirth
            if cfg and cfg.AutoLevelUpByRebirth ~= nil then
                shouldLevelUpByRebirth = cfg.AutoLevelUpByRebirth
            end
            if cfg and cfg.LevelUpRebirthMultiplier ~= nil then
                AutoPlot.LevelMultiplierPerRebirth = tonumber(cfg.LevelUpRebirthMultiplier) or 10
            end

            if shouldLevelUpByRebirth and (now - tickLevelUpRebirth) >= 1.5 then
                tickLevelUpRebirth = now
                AutoPlot.LevelUpSlotsByRebirthOnce()
            end

            task.wait(0.5)
        end
    end)
end

function AutoPlot.Stop()
    AutoPlot.IsRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

function AutoPlot.StopAll()
    AutoPlot.Stop()
end

_G.AnimeDiceAutoPlot = AutoPlot
return AutoPlot
