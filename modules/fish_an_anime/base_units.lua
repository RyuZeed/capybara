--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (BASE UNITS & LEVEL UP ENGINE)
	Module: modules/fish_an_anime/base_units.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🌟 FEATURES:
	- Realtime Base Plot Detector & Unit Scanner
	- Detailed Unit Stats (Name, Rarity, Level, CPS, Type, Stand ID, Cost)
	- Smart Max Level Up for All Base Units
	- Stand-by-Stand Targeted Level Up
	- Background Auto Level Up Daemon (Zero Spam)
	===============================================================
]]

local BaseUnits = {}
BaseUnits.__index = BaseUnits

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerPlots = Workspace:WaitForChild("PlayerPlots", 10)

BaseUnits.AutoLevelUpEnabled = false
local autoLevelUpThread = nil
local cachedPlot = nil

-- ── 🏡 1. Detect Local Player's Plot ──
function BaseUnits.GetPlayerPlot()
    if cachedPlot and cachedPlot.Parent == PlayerPlots then
        local ownerPart = cachedPlot:FindFirstChild("PlotOwner")
        if ownerPart then
            local billboard = ownerPart:FindFirstChild("PlayerBillboard")
            local textLabel = billboard and billboard:FindFirstChild("TextLabel")
            if textLabel and (textLabel.Text == LocalPlayer.Name or textLabel.Text == LocalPlayer.DisplayName) then
                return cachedPlot
            end
        end
    end

    if not PlayerPlots then return nil end

    for _, plot in ipairs(PlayerPlots:GetChildren()) do
        local ownerPart = plot:FindFirstChild("PlotOwner")
        if ownerPart then
            local billboard = ownerPart:FindFirstChild("PlayerBillboard")
            local textLabel = billboard and billboard:FindFirstChild("TextLabel")
            if textLabel and (textLabel.Text == LocalPlayer.Name or textLabel.Text == LocalPlayer.DisplayName) then
                cachedPlot = plot
                return plot
            end
        end
    end

    return nil
end

-- ── 🔍 2. Realtime Scan Base Units ──
function BaseUnits.ScanUnits()
    local plot = BaseUnits.GetPlayerPlot()
    if not plot then return {} end

    local unitsList = {}
    local purchases = plot:FindFirstChild("Purchases")

    for _, item in ipairs(plot:GetChildren()) do
        if item:IsA("Model") and item:GetAttribute("IsPlacedCharacter") == true then
            local charName = item:GetAttribute("CharacterName") or item.Name:gsub("Placed_", "")
            local rarity = item:GetAttribute("Rarity") or "Common"
            local level = item:GetAttribute("Level") or 1
            local cps = item:GetAttribute("CPS") or 0
            local charType = item:GetAttribute("CharacterType") or "Normal"
            local standId = tostring(item:GetAttribute("StandId") or "")
            local baseCps = item:GetAttribute("BaseCPS") or 0

            -- Temukan prompt level up untuk stand ini jika ada
            local maxPrompt = nil
            local upgradeCostText = "N/A"

            if purchases then
                local standFolder = purchases:FindFirstChild(standId) or purchases:FindFirstChild(standId .. "PAID")
                if not standFolder then
                    for _, folder in ipairs(purchases:GetChildren()) do
                        if folder.Name == standId or folder.Name == (standId .. "PAID") then
                            standFolder = folder
                            break
                        end
                    end
                end

                if standFolder then
                    for _, desc in ipairs(standFolder:GetDescendants()) do
                        if desc:IsA("ProximityPrompt") and desc.Name == "MaxLevelUpPrompt" then
                            maxPrompt = desc
                            if desc.ActionText and #desc.ActionText > 0 then
                                upgradeCostText = desc.ActionText
                            end
                            break
                        end
                    end
                end
            end

            table.insert(unitsList, {
                Name = charName,
                Rarity = rarity,
                Level = tonumber(level) or 1,
                CPS = tonumber(cps) or 0,
                BaseCPS = tonumber(baseCps) or 0,
                Type = (charType ~= "" and charType) or "Normal",
                StandId = standId,
                Model = item,
                Prompt = maxPrompt,
                UpgradeCostText = upgradeCostText
            })
        end
    end

    -- Urutkan berdasarkan CPS tertinggi ke terendah
    table.sort(unitsList, function(a, b)
        return a.CPS > b.CPS
    end)

    return unitsList
end

-- ── ⚡ 3. Level Up Specific Stand (Seamless Remote-Like Bypass) ──
function BaseUnits.LevelUpStand(standId)
    local plot = BaseUnits.GetPlayerPlot()
    if not plot then return false end

    local purchases = plot:FindFirstChild("Purchases")
    if not purchases then return false end

    local targetFolder = purchases:FindFirstChild(tostring(standId)) or purchases:FindFirstChild(tostring(standId) .. "PAID")
    if not targetFolder then
        for _, folder in ipairs(purchases:GetChildren()) do
            if folder.Name == tostring(standId) or folder.Name == (tostring(standId) .. "PAID") then
                targetFolder = folder
                break
            end
        end
    end
    if not targetFolder then return false end

    local maxPrompt = nil
    for _, desc in ipairs(targetFolder:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Name == "MaxLevelUpPrompt" and desc:GetAttribute("ServerEnabled") == true then
            maxPrompt = desc
            break
        end
    end
    if not maxPrompt then return false end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not root or not camera then return false end

    local promptPart = maxPrompt.Parent
    if not promptPart or not promptPart:IsA("BasePart") then return false end

    -- 🛡️ Freeze camera visual so player screen never jerks or shifts
    local originalCF = root.CFrame
    local originalCamCF = camera.CFrame
    local originalCamType = camera.CameraType

    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = originalCamCF

    -- ⚡ Silent Pulse to Stand Prompt
    root.CFrame = CFrame.new(promptPart.Position + Vector3.new(0, 2.5, 0))
    task.wait(0.04)

    maxPrompt.Enabled = true
    local holdTime = maxPrompt.HoldDuration or 0.2
    if typeof(fireproximityprompt) == "function" then
        fireproximityprompt(maxPrompt, holdTime)
    else
        maxPrompt:InputHoldBegin()
        task.wait(holdTime + 0.03)
        maxPrompt:InputHoldEnd()
    end
    task.wait(holdTime + 0.05)

    -- 🔄 Restore original position & camera
    root.CFrame = originalCF
    camera.CFrame = originalCamCF
    camera.CameraType = originalCamType
    return true
end

-- ── 🌟 4. Level Up All Units on Base (Seamless Remote-Like Bypass) ──
function BaseUnits.LevelUpAllUnitsOnce()
    local plot = BaseUnits.GetPlayerPlot()
    if not plot then return 0 end

    local units = BaseUnits.ScanUnits()
    if #units == 0 then return 0 end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not root or not camera then return 0 end

    -- 🛡️ Freeze camera visual so player screen stays 100% frozen in place
    local originalCF = root.CFrame
    local originalCamCF = camera.CFrame
    local originalCamType = camera.CameraType

    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = originalCamCF

    local leveledCount = 0

    for _, unit in ipairs(units) do
        if unit.Prompt and unit.Prompt:GetAttribute("ServerEnabled") == true then
            local promptPart = unit.Prompt.Parent
            if promptPart and promptPart:IsA("BasePart") then
                root.CFrame = CFrame.new(promptPart.Position + Vector3.new(0, 2.5, 0))
                task.wait(0.03)

                unit.Prompt.Enabled = true
                local holdTime = unit.Prompt.HoldDuration or 0.2
                if typeof(fireproximityprompt) == "function" then
                    fireproximityprompt(unit.Prompt, holdTime)
                else
                    unit.Prompt:InputHoldBegin()
                    task.wait(holdTime + 0.03)
                    unit.Prompt:InputHoldEnd()
                end

                task.wait(holdTime + 0.04)
                leveledCount = leveledCount + 1
            end
        end
    end

    -- 🔄 Restore original position & camera seamlessly
    root.CFrame = originalCF
    camera.CFrame = originalCamCF
    camera.CameraType = originalCamType
    return leveledCount
end

-- ── 🔄 5. Auto Level Up Loop (Daemon) ──
function BaseUnits.StartAutoLevelUp(interval)
    BaseUnits.AutoLevelUpEnabled = true
    interval = interval or 10

    if autoLevelUpThread then task.cancel(autoLevelUpThread) end
    autoLevelUpThread = task.spawn(function()
        while BaseUnits.AutoLevelUpEnabled do
            BaseUnits.LevelUpAllUnitsOnce()
            task.wait(interval)
        end
    end)
end

function BaseUnits.StopAutoLevelUp()
    BaseUnits.AutoLevelUpEnabled = false
    if autoLevelUpThread then
        pcall(function() task.cancel(autoLevelUpThread) end)
        autoLevelUpThread = nil
    end
end

_G.FishAnAnimeBaseUnits = BaseUnits
return BaseUnits
