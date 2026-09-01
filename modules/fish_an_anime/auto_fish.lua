--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (AUTO FISHING & BACKPACK ENGINE V3.0)
	Module: modules/fish_an_anime/auto_fish.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎣 FEATURES:
	- Event-Driven Instant Auto Fishing Loop (Zero Delay Reel)
	- Smart Pond & Water Detection / Area Targeting
	- State Recovery & Desync Watchdog
	- Auto Equip Best Character
	- Auto Pick Up All Drops
	- Full-Stack Auto Sell Engine (Direct Remote & Summary SellSelected)
	- Selective Auto Sell by Rarity (All 17 Rarities with Server-Lock Bypass)
	===============================================================
]]

local AutoFish = {}
AutoFish.__index = AutoFish

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- Configuration & State
AutoFish.IsFishing = false
AutoFish.IsPaused = false
AutoFish.FastClick = true
AutoFish.SelectedPond = "Auto"

AutoFish.AutoEquipBestEnabled = false
AutoFish.AutoPickUpAllEnabled = false
AutoFish.AutoSellAllEnabled = false
AutoFish.AutoSellByRarityEnabled = false
AutoFish.AutoSellRarities = {
    Common = true,
    Uncommon = true,
    Rare = true,
    Epic = true,
    Legendary = false,
    Mythical = false,
    Cosmic = false,
    Secret = false,
    Rainbow = false,
    Ascended = false,
    Divine = false,
    Supreme = false,
    Celestial = false,
    Ancient = false,
    God = false,
    Omniscient = false,
    Exclusive = false
}

-- Internal Variables
local fishingStateConn = nil
local fishingLoopThread = nil
local equipBestLoopThread = nil
local pickUpLoopThread = nil
local autoSellAllLoopThread = nil
local autoSellByRarityLoopThread = nil
local lastStateTime = tick()
local isCastPending = false

-- ── 🌊 Pond & Water Resolver ──
function AutoFish.GetPonds()
    local ponds = {}
    pcall(function()
        local pondAreas = Workspace:FindFirstChild("Scripted") and Workspace.Scripted:FindFirstChild("PondAreas")
        if pondAreas then
            for _, p in ipairs(pondAreas:GetChildren()) do
                if p:IsA("BasePart") then
                    table.insert(ponds, p)
                end
            end
        end
    end)

    if #ponds == 0 then
        pcall(function()
            local waterMid = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Water")
            if waterMid then
                for _, p in ipairs(waterMid:GetChildren()) do
                    if p:IsA("BasePart") then
                        table.insert(ponds, p)
                    end
                end
            end
        end)
    end
    return ponds
end

function AutoFish.GetBestPond()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local pos = root and root.Position or Vector3.zero

    local ponds = AutoFish.GetPonds()
    local bestPond = nil
    local bestDist = math.huge

    for _, pond in ipairs(ponds) do
        if pond:IsA("BasePart") then
            local dist = (pond.Position - pos).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestPond = pond
            end
        end
    end

    if not bestPond and Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Water") then
        local w = Workspace.Map.Water:FindFirstChild("WaterMIDCIRC") or Workspace.Map.Water:FindFirstChild("WaterMIDDLE")
        if w and w:IsA("BasePart") then
            bestPond = w
        end
    end

    return bestPond
end

-- ── 🎣 Fishing Rod & Positioning Helpers ──
function AutoFish.EquipBestRod()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end

    -- Check if a fishing rod is already held in character
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and (t:GetAttribute("IsFishingRod") == true or string.find(t.Name:lower(), "rod")) then
            return t
        end
    end

    -- Collect rods from backpack
    local rods = {}
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and (t:GetAttribute("IsFishingRod") == true or string.find(t.Name:lower(), "rod")) then
                local speed = tonumber(t:GetAttribute("RodSpeed")) or 1
                local luck = tonumber(t:GetAttribute("RodLuck")) or 1
                local strength = tonumber(t:GetAttribute("RodStrength")) or 0
                table.insert(rods, { tool = t, speed = speed, luck = luck, strength = strength })
            end
        end
    end

    if #rods == 0 then return nil end

    table.sort(rods, function(a, b)
        if a.speed ~= b.speed then return a.speed > b.speed end
        if a.luck ~= b.luck then return a.luck > b.luck end
        return a.strength > b.strength
    end)

    local bestRod = rods[1].tool
    pcall(function()
        hum:EquipTool(bestRod)
    end)
    task.wait(0.25)
    return bestRod
end

function AutoFish.GoToNearestPond(force)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local pond = AutoFish.GetBestPond()
    local pondPos = pond and pond.Position or Vector3.new(5617, 54, 1290)
    local dist = (pondPos - root.Position).Magnitude

    -- If forced or player is further than 20 studs from valid fishing dock, position player at dock edge
    if force or dist > 20 then
        root.CFrame = CFrame.new(5617, 56.5, 1250)
        task.wait(0.25)
    end
end

-- ── 🎣 Core Fishing Action ──
function AutoFish.ClosestPointOnPond(pond, playerPos)
    if not pond or not pond:IsA("BasePart") then return nil end
    local objPos = pond.CFrame:PointToObjectSpace(playerPos)
    local halfSize = pond.Size * 0.5
    local clampX = math.clamp(objPos.X, -halfSize.X, halfSize.X)
    local clampZ = math.clamp(objPos.Z, -halfSize.Z, halfSize.Z)
    return pond.CFrame:PointToWorldSpace(Vector3.new(clampX, halfSize.Y + 0.1, clampZ))
end

function AutoFish.CastRod()
    if AutoFish.IsPaused or not AutoFish.IsFishing then return false end
    if not Remotes or not Remotes:FindFirstChild("FishingRequestStart") then return false end

    -- 1. Ensure fishing rod is held
    AutoFish.EquipBestRod()

    local pond = AutoFish.GetBestPond()
    if not pond then return false end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    -- 2. If player wandered off (> 25 studs from dock edge), reposition
    if (Vector3.new(5617, 56.5, 1250) - root.Position).Magnitude > 25 then
        AutoFish.GoToNearestPond(true)
    end

    local playerPos = root.Position
    local targetPos = AutoFish.ClosestPointOnPond(pond, playerPos) or (playerPos + Vector3.new(0, -2, 10))

    -- Ensure targetPos is within close proximity (<= 15 studs from player)
    if (targetPos - playerPos).Magnitude > 20 then
        targetPos = playerPos + (targetPos - playerPos).Unit * 12
    end

    isCastPending = true
    lastStateTime = tick()
    Remotes.FishingRequestStart:FireServer(pond, targetPos)
    return true
end

function AutoFish.DoClick()
    if AutoFish.IsPaused then return end
    if Remotes and Remotes:FindFirstChild("FishingClick") then
        Remotes.FishingClick:FireServer()
    end
end

function AutoFish.CancelFishing()
    if Remotes and Remotes:FindFirstChild("FishingCancel") then
        Remotes.FishingCancel:FireServer()
    end
    isCastPending = false
end

function AutoFish.PauseFishing()
    AutoFish.IsPaused = true
    AutoFish.CancelFishing()
end

function AutoFish.ResumeFishing()
    AutoFish.IsPaused = false

    if AutoFish.IsFishing then
        task.wait(0.2)
        AutoFish.CastRod()
    end
end

-- ── 🎣 Auto Fishing Controller ──
function AutoFish.StartFishing()
    if AutoFish.IsFishing then return end
    AutoFish.IsFishing = true
    lastStateTime = tick()

    -- 1. Ensure best rod equipped & in valid fishing spot ONCE at start
    AutoFish.EquipBestRod()
    AutoFish.GoToNearestPond(true)
    task.wait(0.3)

    -- 2. Event listener
    if Remotes and Remotes:FindFirstChild("FishingState") then
        if fishingStateConn then fishingStateConn:Disconnect() end
        fishingStateConn = Remotes.FishingState.OnClientEvent:Connect(function(data)
            if not AutoFish.IsFishing or AutoFish.IsPaused then return end
            lastStateTime = tick()

            if typeof(data) == "table" then
                local kind = data.kind
                if kind == "Hooked" then
                    isCastPending = false
                    if AutoFish.IsPaused then return end
                    -- Instant Hook Catch: Click immediately
                    if AutoFish.FastClick then
                        AutoFish.DoClick()
                    else
                        task.wait(0.05)
                        AutoFish.DoClick()
                    end
                elseif kind == "Completed" then
                    isCastPending = false
                    -- Instant seamless recast
                    task.wait(0.02)
                    if AutoFish.IsFishing and not AutoFish.IsPaused then
                        AutoFish.CastRod()
                    end
                    -- Real-time instant auto sell for newly caught fish
                    if AutoFish.AutoSellByRarityEnabled then
                        task.defer(function()
                            AutoFish.SellSelectedRaritiesOnce()
                        end)
                    end
                elseif kind == "Started" then
                    isCastPending = false
                elseif kind == "Stopped" or kind == "Denied" then
                    isCastPending = false
                    -- Auto recovery if out of range or rod unequipped
                    if typeof(data) == "table" and data.reason == "TOO_FAR" then
                        AutoFish.GoToNearestPond(true)
                    elseif typeof(data) == "table" and data.reason == "NO_ROD" then
                        AutoFish.EquipBestRod()
                    end
                    task.delay(0.2, function()
                        if AutoFish.IsFishing and not AutoFish.IsPaused and not isCastPending then
                            AutoFish.CastRod()
                        end
                    end)
                end
            end
        end)
    end

    -- 3. Initial Cast & Watchdog Loop
    if fishingLoopThread then task.cancel(fishingLoopThread) end
    fishingLoopThread = task.spawn(function()
        AutoFish.CastRod()
        while AutoFish.IsFishing do
            task.wait(1.5)
            if not AutoFish.IsFishing then break end

            -- Watchdog: jika tidak ada event > 3 detik saat memancing
            if tick() - lastStateTime > 3.0 then
                AutoFish.CancelFishing()
                task.wait(0.2)
                if AutoFish.IsFishing then
                    AutoFish.CastRod()
                end
            end
        end
    end)
end

function AutoFish.StopFishing()
    AutoFish.IsFishing = false
    if fishingStateConn then
        pcall(function() fishingStateConn:Disconnect() end)
        fishingStateConn = nil
    end
    if fishingLoopThread then
        pcall(function() task.cancel(fishingLoopThread) end)
        fishingLoopThread = nil
    end
    AutoFish.CancelFishing()
end

-- ── 🎒 Auto Equip Best ──
function AutoFish.StartAutoEquipBest(interval)
    AutoFish.AutoEquipBestEnabled = true
    interval = interval or 5
    if equipBestLoopThread then task.cancel(equipBestLoopThread) end
    equipBestLoopThread = task.spawn(function()
        while AutoFish.AutoEquipBestEnabled do
            if Remotes and Remotes:FindFirstChild("BackpackEquipBest") then
                pcall(function() Remotes.BackpackEquipBest:FireServer() end)
            end
            task.wait(interval)
        end
    end)
end

function AutoFish.StopAutoEquipBest()
    AutoFish.AutoEquipBestEnabled = false
    if equipBestLoopThread then
        pcall(function() task.cancel(equipBestLoopThread) end)
        equipBestLoopThread = nil
    end
end

function AutoFish.EquipBestOnce()
    if Remotes and Remotes:FindFirstChild("BackpackEquipBest") then
        pcall(function() Remotes.BackpackEquipBest:FireServer() end)
        return true
    end
    return false
end

-- ── 🎒 Auto Pick Up All ──
function AutoFish.StartAutoPickUpAll(interval)
    AutoFish.AutoPickUpAllEnabled = true
    interval = interval or 3
    if pickUpLoopThread then task.cancel(pickUpLoopThread) end
    pickUpLoopThread = task.spawn(function()
        while AutoFish.AutoPickUpAllEnabled do
            if Remotes and Remotes:FindFirstChild("BackpackPickUpAll") then
                pcall(function() Remotes.BackpackPickUpAll:FireServer() end)
            end
            task.wait(interval)
        end
    end)
end

function AutoFish.StopAutoPickUpAll()
    AutoFish.AutoPickUpAllEnabled = false
    if pickUpLoopThread then
        pcall(function() task.cancel(pickUpLoopThread) end)
        pickUpLoopThread = nil
    end
end

function AutoFish.PickUpAllOnce()
    if Remotes and Remotes:FindFirstChild("BackpackPickUpAll") then
        pcall(function() Remotes.BackpackPickUpAll:FireServer() end)
        return true
    end
    return false
end

-- ── 💰 1. Auto Sell All ──
function AutoFish.SellAllOnce()
    if not Remotes then return false end

    -- Method 1: Game Native Bulk Sell All
    if Remotes:FindFirstChild("BackpackSellAllRequest") then
        local success, res = pcall(function() return Remotes.BackpackSellAllRequest:InvokeServer() end)
        if success and typeof(res) == "table" and res.ok == true then
            return true, tonumber(res.sold) or 0, tonumber(res.payout) or 0
        end
    end

    -- Method 2: Fallback to iterating through BackpackCharSummaryGet and selling non-favorited groups
    if Remotes:FindFirstChild("BackpackCharSummaryGet") and Remotes:FindFirstChild("BackpackSellSelectedRequest") then
        local s, summary = pcall(function() return Remotes.BackpackCharSummaryGet:InvokeServer() end)
        if s and typeof(summary) == "table" then
            local totalSold = 0
            local totalPayout = 0
            for groupKey, data in pairs(summary) do
                local count = tonumber(data.c) or 1
                for _ = 1, count do
                    local sellOk, sellRes = pcall(function()
                        return Remotes.BackpackSellSelectedRequest:InvokeServer(groupKey)
                    end)
                    if sellOk and typeof(sellRes) == "table" and sellRes.ok == true then
                        totalSold = totalSold + (tonumber(sellRes.sold) or 1)
                        totalPayout = totalPayout + (tonumber(sellRes.payout) or 0)
                    else
                        break
                    end
                    task.wait(0.04)
                end
            end
            return totalSold > 0, totalSold, totalPayout
        end
    end

    return false
end

function AutoFish.StartAutoSellAll(interval)
    AutoFish.AutoSellAllEnabled = true
    interval = interval or 10
    if autoSellAllLoopThread then task.cancel(autoSellAllLoopThread) end
    autoSellAllLoopThread = task.spawn(function()
        while AutoFish.AutoSellAllEnabled do
            AutoFish.SellAllOnce()
            task.wait(interval)
        end
    end)
end

function AutoFish.StopAutoSellAll()
    AutoFish.AutoSellAllEnabled = false
    if autoSellAllLoopThread then
        pcall(function() task.cancel(autoSellAllLoopThread) end)
        autoSellAllLoopThread = nil
    end
end

-- ── 💎 2. Sell By Specific Rarity (Rock-Solid Hybrid Engine) ──
function AutoFish.SellRarityOnce(targetRarity)
    if not Remotes then return false, 0, 0 end
    local targetLower = string.lower(tostring(targetRarity or ""))
    if targetLower == "" then return false, 0, 0 end

    -- Method 1: Try Native BackpackSellRarityRequest
    if Remotes:FindFirstChild("BackpackSellRarityRequest") then
        local success, res = pcall(function() return Remotes.BackpackSellRarityRequest:InvokeServer(targetRarity) end)
        if success and typeof(res) == "table" and res.ok == true then
            return true, tonumber(res.sold) or 0, tonumber(res.payout) or 0
        end
    end

    -- Method 2: Smart Summary + SellSelected (Bypasses the "Locked" / Rsh_B10 Research Gate!)
    if Remotes:FindFirstChild("BackpackCharSummaryGet") and Remotes:FindFirstChild("BackpackSellSelectedRequest") then
        local s, summary = pcall(function() return Remotes.BackpackCharSummaryGet:InvokeServer() end)
        if s and typeof(summary) == "table" then
            local totalSold = 0
            local totalPayout = 0
            for groupKey, data in pairs(summary) do
                if typeof(data) == "table" and data.ra then
                    local itemRarityLower = string.lower(tostring(data.ra))
                    if itemRarityLower == targetLower then
                        local maxAttempts = tonumber(data.c) or 1
                        for _ = 1, maxAttempts do
                            local sellSuccess, sellRes = pcall(function()
                                return Remotes.BackpackSellSelectedRequest:InvokeServer(groupKey)
                            end)
                            if sellSuccess and typeof(sellRes) == "table" and sellRes.ok == true then
                                totalSold = totalSold + (tonumber(sellRes.sold) or 1)
                                totalPayout = totalPayout + (tonumber(sellRes.payout) or 0)
                            else
                                break
                            end
                            task.wait(0.04)
                        end
                    end
                end
            end
            return totalSold > 0, totalSold, totalPayout
        end
    end

    return false, 0, 0
end

-- ── 💎 3. Sell Selected Rarities Batch ──
function AutoFish.SellSelectedRaritiesOnce()
    if not Remotes or not Remotes:FindFirstChild("BackpackCharSummaryGet") or not Remotes:FindFirstChild("BackpackSellSelectedRequest") then
        return false, 0, 0
    end

    local s, summary = pcall(function() return Remotes.BackpackCharSummaryGet:InvokeServer() end)
    if not s or typeof(summary) ~= "table" then return false, 0, 0 end

    local totalSold = 0
    local totalPayout = 0

    for groupKey, data in pairs(summary) do
        if typeof(data) == "table" and data.ra then
            local rarityName = tostring(data.ra)
            local isSelected = (AutoFish.AutoSellRarities[rarityName] == true) or (AutoFish.AutoSellRarities[string.lower(rarityName)] == true)
            if isSelected then
                local maxAttempts = tonumber(data.c) or 1
                for _ = 1, maxAttempts do
                    local sellSuccess, sellRes = pcall(function()
                        return Remotes.BackpackSellSelectedRequest:InvokeServer(groupKey)
                    end)
                    if sellSuccess and typeof(sellRes) == "table" and sellRes.ok == true then
                        totalSold = totalSold + (tonumber(sellRes.sold) or 1)
                        totalPayout = totalPayout + (tonumber(sellRes.payout) or 0)
                    else
                        break
                    end
                    task.wait(0.04)
                end
            end
        end
    end

    return totalSold > 0, totalSold, totalPayout
end

-- ── 💎 4. Auto Sell by Selected Rarities Loop ──
function AutoFish.StartAutoSellByRarity(interval)
    AutoFish.AutoSellByRarityEnabled = true
    interval = interval or 5

    -- Sync In-Game Auto Sell with Server for enabled rarities
    if Remotes and Remotes:FindFirstChild("RarityAutoSellSet") then
        for rarityName, enabled in pairs(AutoFish.AutoSellRarities) do
            pcall(function()
                Remotes.RarityAutoSellSet:InvokeServer(rarityName, enabled == true)
            end)
        end
    end

    if autoSellByRarityLoopThread then task.cancel(autoSellByRarityLoopThread) end
    autoSellByRarityLoopThread = task.spawn(function()
        -- Instant initial sweep
        AutoFish.SellSelectedRaritiesOnce()
        while AutoFish.AutoSellByRarityEnabled do
            task.wait(interval)
            if not AutoFish.AutoSellByRarityEnabled then break end
            AutoFish.SellSelectedRaritiesOnce()
        end
    end)
end

function AutoFish.StopAutoSellByRarity()
    AutoFish.AutoSellByRarityEnabled = false
    if autoSellByRarityLoopThread then
        pcall(function() task.cancel(autoSellByRarityLoopThread) end)
        autoSellByRarityLoopThread = nil
    end
end

function AutoFish.SetRarityAutoSell(rarityName, state)
    AutoFish.AutoSellRarities[rarityName] = state
    AutoFish.AutoSellRarities[string.lower(rarityName)] = state

    -- Check if at least one rarity toggle is active
    local hasAnyActive = false
    for _, enabled in pairs(AutoFish.AutoSellRarities) do
        if enabled == true then
            hasAnyActive = true
            break
        end
    end

    if hasAnyActive then
        AutoFish.StartAutoSellByRarity(5)
    else
        AutoFish.StopAutoSellByRarity()
    end

    -- Sync with server remote if available
    if Remotes and Remotes:FindFirstChild("RarityAutoSellSet") then
        pcall(function()
            Remotes.RarityAutoSellSet:InvokeServer(rarityName, state == true)
        end)
    end
end

-- ── 🛑 Stop All ──
function AutoFish.StopAll()
    AutoFish.StopFishing()
    AutoFish.StopAutoEquipBest()
    AutoFish.StopAutoPickUpAll()
    AutoFish.StopAutoSellAll()
    AutoFish.StopAutoSellByRarity()
end

_G.FishAnAnimeAutoFish = AutoFish
return AutoFish
