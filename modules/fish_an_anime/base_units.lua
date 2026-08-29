--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (BASE UNITS & LEVEL UP ENGINE V2.2)
	Module: modules/fish_an_anime/base_units.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🌟 FEATURES:
	- Realtime Base Plot Detector & Unit Scanner
	- Detailed Unit Stats (Name, Rarity, Level, CPS, Type, Stand ID, Cost)
	- Smart Food Cost Parser & Affordability Check
	- 100% Robux Popup Blocker (Anti-Skip10 / Anti-Purchase Prompt)
	- Smooth Fast Sweep & Return to Origin Spot
	- Background Auto Level Up Daemon (Zero Spam)
	===============================================================
]]

local BaseUnits = {}
BaseUnits.__index = BaseUnits

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerPlots = Workspace:WaitForChild("PlayerPlots", 10)

BaseUnits.AutoLevelUpEnabled = false
local autoLevelUpThread = nil
local cachedPlot = nil
local isLevelingUp = false

-- ── 🛡️ 1. Block Robux Purchase Popups (100% Elimination) ──
local plotDescendantConn = nil

local function neutralizePrompt(desc)
    if not desc or not desc:IsA("ProximityPrompt") then return end
    if desc.Name == "LevelUp10Prompt" or desc.Name == "PurchasePrompt" then
        pcall(function()
            desc.Enabled = false
            desc.MaxActivationDistance = 0
            desc.RequiresLineOfSight = true
            desc:Destroy()
        end)
    end
end

local function blockRobuxPrompts(plot)
    if not plot then return end
    local purchases = plot:FindFirstChild("Purchases")
    if not purchases then return end

    for _, desc in ipairs(purchases:GetDescendants()) do
        neutralizePrompt(desc)
    end

    if not plotDescendantConn then
        plotDescendantConn = plot.DescendantAdded:Connect(function(desc)
            neutralizePrompt(desc)
        end)
    end
end

-- Hook MarketplaceService to prevent unwanted DevProduct Robux dialogs
pcall(function()
    if typeof(hookfunction) == "function" and typeof(MarketplaceService.PromptProductPurchase) == "function" then
        local oldPromptProduct
        oldPromptProduct = hookfunction(MarketplaceService.PromptProductPurchase, function(self, player, productId, ...)
            if BaseUnits.AutoLevelUpEnabled or isLevelingUp then
                return
            end
            return oldPromptProduct(self, player, productId, ...)
        end)
    end
end)

-- ── 💰 2. Parse Food Cost from Prompt Text ──
function BaseUnits.ParseFoodCost(text)
    if not text or type(text) ~= "string" then return math.huge end
    local numStr, unit = string.match(text, "%(([%d%.]+)%s*([KkMmBbTtQq]*)%s*[Ff]ood%)")
    if not numStr then return 0 end
    local num = tonumber(numStr) or 0
    unit = string.upper(unit or "")
    if unit == "K" then return num * 1e3
    elseif unit == "M" then return num * 1e6
    elseif unit == "B" then return num * 1e9
    elseif unit == "T" then return num * 1e12
    elseif unit == "Q" or unit == "QA" then return num * 1e15
    else return num end
end

function BaseUnits.GetPlayerFood()
    return tonumber(LocalPlayer:GetAttribute("FoodNumber")) or 0
end

-- ── 🏡 3. Detect Local Player's Plot ──
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
                blockRobuxPrompts(plot)
                return plot
            end
        end
    end

    return nil
end

local RARITY_TIERS = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythical = 6,
    Cosmic = 7,
    Secret = 8,
    Rainbow = 9,
    Ascended = 10,
    Divine = 11,
    Supreme = 12,
    Celestial = 13,
    Ancient = 14,
    God = 15,
    Omniscient = 16,
    Exclusive = 17
}

function BaseUnits.GetRarityRank(rarity)
    return RARITY_TIERS[rarity] or 0
end

-- ── 🔍 4. Realtime Scan Base Units ──
function BaseUnits.ScanUnits()
    local plot = BaseUnits.GetPlayerPlot()
    if not plot then return {} end

    blockRobuxPrompts(plot)

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

            local maxPrompt = nil
            local upgradeCostText = "N/A"
            local foodCost = 0

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
                                foodCost = BaseUnits.ParseFoodCost(desc.ActionText)
                            end
                            break
                        end
                    end
                end
            end

            table.insert(unitsList, {
                Name = charName,
                Rarity = rarity,
                RarityRank = RARITY_TIERS[rarity] or 0,
                Level = tonumber(level) or 1,
                CPS = tonumber(cps) or 0,
                BaseCPS = tonumber(baseCps) or 0,
                Type = (charType ~= "" and charType) or "Normal",
                StandId = standId,
                Model = item,
                Prompt = maxPrompt,
                UpgradeCostText = upgradeCostText,
                FoodCost = foodCost
            })
        end
    end

    -- Sort by lowest level first (then highest rarity, then highest CPS)
    table.sort(unitsList, function(a, b)
        if a.Level ~= b.Level then
            return a.Level < b.Level -- Lowest level first
        end
        if a.RarityRank ~= b.RarityRank then
            return a.RarityRank > b.RarityRank
        end
        return a.CPS > b.CPS
    end)

    return unitsList
end

-- ── ⚡ 5. Level Up Specific Stand ──
function BaseUnits.LevelUpStand(standId)
    if isLevelingUp then return false end
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
        if desc:IsA("ProximityPrompt") then
            if desc.Name == "MaxLevelUpPrompt" and desc:GetAttribute("ServerEnabled") == true then
                maxPrompt = desc
            elseif desc.Name == "LevelUp10Prompt" or desc.Name == "PurchasePrompt" then
                desc.Enabled = false
            end
        end
    end
    if not maxPrompt then return false end

    local cost = BaseUnits.ParseFoodCost(maxPrompt.ActionText)
    local currentFood = BaseUnits.GetPlayerFood()
    if cost > 0 and currentFood < cost then
        return false, "Not enough food"
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not root or not camera then return false end

    local promptPart = maxPrompt.Parent
    if not promptPart or not promptPart:IsA("BasePart") then return false end

    isLevelingUp = true

    -- 🎣 Seamless AutoFish Pause Coordination
    local autoFish = _G.FishAnAnimeAutoFish
    local wasFishing = autoFish and autoFish.IsFishing
    local hadNativeAutoFish = (LocalPlayer:GetAttribute("AutoFishActive") == true) or (LocalPlayer:GetAttribute("AutoFishOwned") == true)

    if wasFishing and typeof(autoFish.PauseFishing) == "function" then
        autoFish.PauseFishing()
        task.wait(0.12)
    end

    local originalCF = root.CFrame
    local originalCamCF = camera.CFrame
    local originalCamType = camera.CameraType

    pcall(function()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = originalCamCF
    end)

    root.CFrame = CFrame.new(promptPart.Position + Vector3.new(0, 2.0, 0))
    task.wait(0.06)

    pcall(function()
        maxPrompt.Enabled = true
        maxPrompt.RequiresLineOfSight = false
        maxPrompt.MaxActivationDistance = 30
    end)

    local holdTime = maxPrompt.HoldDuration or 0.2
    if typeof(fireproximityprompt) == "function" then
        fireproximityprompt(maxPrompt, holdTime)
        task.wait(0.04)
        fireproximityprompt(maxPrompt, 0)
    end
    task.wait(math.max(0.15, holdTime + 0.08))

    root.CFrame = originalCF
    task.wait(0.04)

    pcall(function()
        camera.CFrame = originalCamCF
        camera.CameraType = originalCamType
    end)

    -- 🎣 Seamless AutoFish Resume Coordination
    if (wasFishing or hadNativeAutoFish) and autoFish and typeof(autoFish.ResumeFishing) == "function" then
        task.wait(0.2)
        autoFish.ResumeFishing()
    end

    isLevelingUp = false
    return true
end

BaseUnits.FilterByRarity = false
BaseUnits.SelectedRarities = {}

-- ── 🌟 6. Level Up All Units on Base (Safe & Filtered by Rarity) ──
function BaseUnits.LevelUpAllUnitsOnce()
    if isLevelingUp then return 0 end
    local plot = BaseUnits.GetPlayerPlot()
    if not plot then return 0 end

    local units = BaseUnits.ScanUnits()
    if #units == 0 then return 0 end

    local currentFood = BaseUnits.GetPlayerFood()
    local affordableUnits = {}

    for _, unit in ipairs(units) do
        local rarityAllowed = true
        if BaseUnits.FilterByRarity and BaseUnits.SelectedRarities then
            rarityAllowed = (BaseUnits.SelectedRarities[unit.Rarity] == true)
        end

        if rarityAllowed and unit.Prompt and unit.Prompt:GetAttribute("ServerEnabled") == true then
            if unit.FoodCost > 0 and currentFood >= unit.FoodCost then
                table.insert(affordableUnits, unit)
                currentFood = currentFood - unit.FoodCost
            elseif unit.FoodCost == 0 then
                table.insert(affordableUnits, unit)
            end
        end
    end

    if #affordableUnits == 0 then return 0 end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not root or not camera then return 0 end

    isLevelingUp = true

    -- 🎣 Seamless AutoFish Pause Coordination
    local autoFish = _G.FishAnAnimeAutoFish
    local wasFishing = autoFish and autoFish.IsFishing
    local hadNativeAutoFish = (LocalPlayer:GetAttribute("AutoFishActive") == true) or (LocalPlayer:GetAttribute("AutoFishOwned") == true)

    if wasFishing and typeof(autoFish.PauseFishing) == "function" then
        autoFish.PauseFishing()
        task.wait(0.12)
    end

    local originalCF = root.CFrame
    local originalCamCF = camera.CFrame
    local originalCamType = camera.CameraType

    pcall(function()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = originalCamCF
    end)

    local leveledCount = 0

    for _, unit in ipairs(affordableUnits) do
        local prompt = unit.Prompt
        local promptPart = prompt and prompt.Parent
        if prompt and promptPart and promptPart:IsA("BasePart") then
            root.CFrame = CFrame.new(promptPart.Position + Vector3.new(0, 2.0, 0))
            task.wait(0.06)

            pcall(function()
                prompt.Enabled = true
                prompt.RequiresLineOfSight = false
                prompt.MaxActivationDistance = 30
            end)

            local holdTime = prompt.HoldDuration or 0.2
            if typeof(fireproximityprompt) == "function" then
                fireproximityprompt(prompt, holdTime)
                task.wait(0.04)
                fireproximityprompt(prompt, 0)
            end
            task.wait(math.max(0.15, holdTime + 0.08))
            leveledCount = leveledCount + 1
        end
    end

    task.wait(0.04)
    root.CFrame = originalCF
    task.wait(0.04)

    pcall(function()
        camera.CFrame = originalCamCF
        camera.CameraType = originalCamType
    end)

    -- 🎣 Seamless AutoFish Resume Coordination
    if (wasFishing or hadNativeAutoFish) and autoFish and typeof(autoFish.ResumeFishing) == "function" then
        task.wait(0.2)
        autoFish.ResumeFishing()
    end

    isLevelingUp = false
    return leveledCount
end

-- ── 🔄 7. Auto Level Up Loop (Daemon) ──
function BaseUnits.StartAutoLevelUp(interval)
    BaseUnits.AutoLevelUpEnabled = true
    interval = interval or 15

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
