--[[
	===============================================================
	⚡ RITOD HUB - AUTO DEPOLARIZER MODULE (V1.0)
	Game: Fish an Anime RNG 🎲
	Function: Automatically inserts units with unwanted mutations
	          into the Depolarizer machine to strip/purify mutations.
	===============================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local AutoDepolarizer = {}
AutoDepolarizer.Enabled = false
AutoDepolarizer.Interval = 5
AutoDepolarizer.LastStatus = "Idle"

-- Selected Rarities to Depolarize
AutoDepolarizer.SelectedRarities = {
    ["Common"] = false,
    ["Uncommon"] = false,
    ["Rare"] = false,
    ["Epic"] = false,
    ["Legendary"] = false,
    ["Mythical"] = false,
    ["Cosmic"] = false,
    ["Secret"] = false,
    ["Rainbow"] = false,
    ["Ascended"] = false,
    ["Divine"] = false,
    ["Supreme"] = false,
    ["Celestial"] = false,
    ["Ancient"] = false,
    ["God"] = false,
    ["Omniscient"] = false,
    ["Transcendent"] = false,
    ["Exclusive"] = false
}

-- Selected Mutations / Types to Depolarize (Remove)
AutoDepolarizer.SelectedMutations = {
    ["Mars"] = false,
    ["Electric"] = false,
    ["Ghost"] = false,
    ["Party"] = false,
    ["Gold"] = false,
    ["Lava"] = false,
    ["Complexity"] = false,
    ["Slime"] = true,
    ["Zombie"] = true,
    ["Diamond"] = false,
    ["Demonic"] = false,
    ["Solar"] = false,
    ["Angelic"] = false,
    ["Blood"] = false,
    ["Nightmare"] = false,
    ["Dracula"] = false,
    ["Lunar"] = false,
    ["Sinister"] = false,
    ["Void"] = false,
    ["Toxic"] = false,
    ["Honey"] = false,
    ["Frozen"] = false
}

local depolarizerThread = nil

-- ── 📍 1. Helper: Find Player's Plot ──
function AutoDepolarizer.GetMyPlot()
    local plots = workspace:FindFirstChild("PlayerPlots")
    if not plots then return nil end

    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("Owner")
        if owner and (owner.Value == LocalPlayer or tostring(owner.Value) == LocalPlayer.Name) then
            return plot
        end
        if tonumber(plot:GetAttribute("OwnerUserId")) == LocalPlayer.UserId then
            return plot
        end
    end

    -- Fallback: check placed units owner
    for _, plot in ipairs(plots:GetChildren()) do
        for _, child in ipairs(plot:GetChildren()) do
            if string.find(child.Name, "Placed_") and tonumber(child:GetAttribute("OwnerUserId")) == LocalPlayer.UserId then
                return plot
            end
        end
    end

    return nil
end

-- ── 🏭 2. Helper: Get Depolarizer Machine Info ──
function AutoDepolarizer.GetDepolarizerInfo()
    local plot = AutoDepolarizer.GetMyPlot()
    if not plot then
        return nil, "Plot tidak ditemukan"
    end

    local purchases = plot:FindFirstChild("Purchases")
    if not purchases then
        return nil, "Purchases folder tidak ditemukan di Plot"
    end

    local depolarizer = purchases:FindFirstChild("Depolarizer")
    if not depolarizer then
        return nil, "Depolarizer belum dibeli di Plot"
    end

    local charInsert = depolarizer:FindFirstChild("CharacterInsert")
    if not charInsert then
        return nil, "CharacterInsert tidak ditemukan"
    end

    -- Check if busy (timer running)
    local isBusy = false
    local remainingText = ""
    local timePart = charInsert:FindFirstChild("TimePart")
    if timePart then
        local statsGui = timePart:FindFirstChild("StatsGui")
        local timeLeft = statsGui and statsGui:FindFirstChild("TimeLeft")
        if timeLeft and timeLeft:IsA("TextLabel") and timeLeft.Text ~= "" and timeLeft.Text ~= "0s" then
            isBusy = true
            remainingText = timeLeft.Text
        end
    end

    local promptPart = charInsert:FindFirstChild("PromptPart")
    local prompt = promptPart and promptPart:FindFirstChildWhichIsA("ProximityPrompt", true)

    return {
        model = depolarizer,
        charInsert = charInsert,
        prompt = prompt,
        promptPart = promptPart,
        isBusy = isBusy,
        remainingText = remainingText
    }
end

-- ── 🎒 3. Helper: Get Eligible Backpack Units ──
function AutoDepolarizer.GetEligibleUnits()
    local summary = nil
    if Remotes:FindFirstChild("BackpackCharSummaryGet") then
        local ok, res = pcall(function()
            return Remotes.BackpackCharSummaryGet:InvokeServer()
        end)
        if ok and typeof(res) == "table" then
            summary = res
        end
    end

    if not summary and rawget(_G, "__BP_CharSummary") then
        summary = _G.__BP_CharSummary
    end

    local eligible = {}
    if not summary then return eligible end

    for key, data in pairs(summary) do
        if typeof(data) == "table" then
            local mutation = data.ty or ""
            local rarity = data.ra or ""
            local count = tonumber(data.c) or 1

            if mutation ~= "" and mutation ~= "nil" and mutation ~= "None" then
                local mutMatch = (AutoDepolarizer.SelectedMutations[mutation] == true)
                local rarMatch = (AutoDepolarizer.SelectedRarities[rarity] == true)

                if mutMatch and rarMatch then
                    table.insert(eligible, {
                        key = key,
                        name = data.n or "Unknown",
                        mutation = mutation,
                        rarity = rarity,
                        level = tonumber(data.bl) or 1,
                        cps = tonumber(data.bc) or 0,
                        count = count
                    })
                end
            end
        end
    end

    -- Sort by lowest rarity / level first
    table.sort(eligible, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.cps < b.cps
    end)

    return eligible
end

-- ── ⚡ 4. Action: Depolarize Single Unit ──
function AutoDepolarizer.DepolarizeUnit(unit)
    if not unit or not unit.key then
        return false, "Unit tidak valid"
    end

    local info, err = AutoDepolarizer.GetDepolarizerInfo()
    if not info then
        return false, err
    end

    if info.isBusy then
        return false, "Depolarizer sedang berjalan (" .. tostring(info.remainingText) .. ")"
    end

    -- 1. Hold character in hand
    if Remotes:FindFirstChild("BackpackHoldCharacter") then
        Remotes.BackpackHoldCharacter:FireServer(unit.key)
        task.wait(0.25)
    end

    -- 2. Trigger ProximityPrompt
    if info.prompt then
        if fireproximityprompt then
            fireproximityprompt(info.prompt, 0, true)
        else
            pcall(function()
                info.prompt:InputHoldBegin()
                task.wait(info.prompt.HoldDuration or 0.1)
                info.prompt:InputHoldEnd()
            end)
        end
    end
    task.wait(0.3)

    -- 3. Confirm dialog
    if Remotes:FindFirstChild("DepolarizrConfirm") then
        Remotes.DepolarizrConfirm:FireServer(true)
    end
    task.wait(0.2)

    -- 4. Reset hand
    if Remotes:FindFirstChild("BackpackHoldCharacter") then
        Remotes.BackpackHoldCharacter:FireServer("")
    end

    return true, string.format("Unit %s (%s [%s]) berhasil dimasukkan ke Depolarizer!", unit.name, unit.rarity, unit.mutation)
end

-- ── 🔄 5. Action: Step Once ──
function AutoDepolarizer.StepOnce()
    local info, err = AutoDepolarizer.GetDepolarizerInfo()
    if not info then
        AutoDepolarizer.LastStatus = "Error: " .. tostring(err)
        return false, err
    end

    if info.isBusy then
        AutoDepolarizer.LastStatus = string.format("Sedang Depolarize: %s tersisa", tostring(info.remainingText))
        return false, AutoDepolarizer.LastStatus
    end

    local eligibleUnits = AutoDepolarizer.GetEligibleUnits()
    if #eligibleUnits == 0 then
        AutoDepolarizer.LastStatus = "Idle (Tidak ada unit yang cocok dengan filter Rarity & Mutasi)"
        return false, AutoDepolarizer.LastStatus
    end

    local targetUnit = eligibleUnits[1]
    AutoDepolarizer.LastStatus = string.format("Memproses %s [%s]...", targetUnit.name, targetUnit.mutation)
    local success, msg = AutoDepolarizer.DepolarizeUnit(targetUnit)
    if success then
        AutoDepolarizer.LastStatus = msg
    else
        AutoDepolarizer.LastStatus = "Gagal: " .. tostring(msg)
    end
    return success, msg
end

-- ── ▶️ 6. Start / Stop Automation ──
function AutoDepolarizer.StartAutoDepolarizer(interval)
    AutoDepolarizer.Enabled = true
    interval = interval or AutoDepolarizer.Interval or 5

    if depolarizerThread then task.cancel(depolarizerThread) end
    depolarizerThread = task.spawn(function()
        -- Initial check
        AutoDepolarizer.StepOnce()
        while AutoDepolarizer.Enabled do
            task.wait(interval)
            if not AutoDepolarizer.Enabled then break end
            AutoDepolarizer.StepOnce()
        end
    end)
end

function AutoDepolarizer.StopAutoDepolarizer()
    AutoDepolarizer.Enabled = false
    if depolarizerThread then
        pcall(function() task.cancel(depolarizerThread) end)
        depolarizerThread = nil
    end
    AutoDepolarizer.LastStatus = "Nonaktif"
end

function AutoDepolarizer.StopAll()
    AutoDepolarizer.StopAutoDepolarizer()
end

-- ── 🔔 7. Auto Confirm Remote Event Listener ──
if Remotes:FindFirstChild("DepolarizrUI") then
    Remotes.DepolarizrUI.OnClientEvent:Connect(function(data)
        if AutoDepolarizer.Enabled and data and data.action == "ShowConfirm" then
            task.wait(0.1)
            if Remotes:FindFirstChild("DepolarizrConfirm") then
                Remotes.DepolarizrConfirm:FireServer(true)
            end
        end
    end)
end

_G.FishAnAnimeAutoDepolarizer = AutoDepolarizer
return AutoDepolarizer
