--[[
	===============================================================
	⚡ RITOD HUB - AUTO DEPOLARIZER MODULE (V1.1 - ANTI SPAM & SAFE)
	Game: Fish an Anime RNG 🎲
	Function: Otomatis memasukkan unit dengan mutasi yang dipilih ke
	          mesin Depolarizer saat mesin KOSONG / READY.
	          Tidak akan memproses jika mesin sedang ada unit / berjalan.
	          Hanya memproses unit yang memiliki MUTASI sesuai filter.
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
AutoDepolarizer.ProcessingUnit = false

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

-- Selected Mutations / Types to Depolarize (Hanya mutasi yang dipilih yang akan di-strip)
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

-- ── 🏭 2. Helper: Get Depolarizer Machine State ──
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

    -- 1. Check ButtonModel for Skip (Robux) prompt (Artinya sedang ada unit di dalam mesin)
    local buttonModel = charInsert:FindFirstChild("ButtonModel")
    local skipPrompt = buttonModel and buttonModel:FindFirstChildWhichIsA("ProximityPrompt", true)

    -- 2. Check TimePart / StatsGui / TimeLeft (Recursive TextLabel search)
    local timePart = charInsert:FindFirstChild("TimePart")
    local statsGui = timePart and timePart:FindFirstChild("StatsGui")
    local timeLeftLabel = statsGui and statsGui:FindFirstChildWhichIsA("TextLabel", true)

    local remainingText = ""
    local isBusy = false

    if timeLeftLabel and timeLeftLabel.Text ~= "" and timeLeftLabel.Text ~= "0s" then
        isBusy = true
        remainingText = timeLeftLabel.Text
    end

    if skipPrompt and skipPrompt.Enabled == true and string.find(string.lower(skipPrompt.ActionText or ""), "skip") then
        isBusy = true
        if remainingText == "" then
            remainingText = "Sedang Berjalan"
        end
    end

    -- 3. Check PromptPart for Character Insert ProximityPrompt
    local promptPart = charInsert:FindFirstChild("PromptPart")
    local insertPrompt = promptPart and promptPart:FindFirstChildWhichIsA("ProximityPrompt", true)

    -- Mesin HANYA READY jika TIDAK BUSY dan insertPrompt ADA & ENABLED
    local isReady = (not isBusy) and (insertPrompt ~= nil) and (insertPrompt.Enabled == true)

    return {
        model = depolarizer,
        charInsert = charInsert,
        prompt = insertPrompt,
        promptPart = promptPart,
        isBusy = isBusy,
        isReady = isReady,
        remainingText = remainingText
    }
end

-- ── 🎒 3. Helper: Get Eligible Units (HANYA YANG MEMILIKI MUTASI) ──
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
            local mutation = tostring(data.ty or "")
            local rarity = tostring(data.ra or "")
            local count = tonumber(data.c) or 1

            -- PASTIKAN unit BENAR-BENAR MEMILIKI MUTASI (Bukan kosong / nil / None)
            if mutation ~= "" and mutation ~= "nil" and mutation ~= "None" and #mutation > 1 then
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

    -- Prioritaskan level terendah / cps terendah
    table.sort(eligible, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.cps < b.cps
    end)

    return eligible
end

-- ── 🧹 Helper: Unequip Hand ──
function AutoDepolarizer.UnequipHand()
    pcall(function()
        if Remotes:FindFirstChild("BackpackHoldCharacter") then
            Remotes.BackpackHoldCharacter:FireServer("")
        end
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:UnequipTools()
            end
            for _, t in ipairs(LocalPlayer.Character:GetChildren()) do
                if t:IsA("Tool") and t:GetAttribute("IsCharacterTool") == true then
                    t.Parent = LocalPlayer:FindFirstChildOfClass("Backpack") or t.Parent
                end
            end
        end
    end)
end

-- ── ⚡ 4. Action: Depolarize Single Unit (Safe Execution) ──
function AutoDepolarizer.DepolarizeUnit(unit)
    if not unit or not unit.key then
        return false, "Unit tidak valid"
    end

    -- Pastikan unit benar-benar punya mutasi sebelum dimasukkan
    if not unit.mutation or unit.mutation == "" or unit.mutation == "nil" or unit.mutation == "None" then
        return false, "Unit tidak memiliki mutasi (Dibatalkan untuk keamanan)"
    end

    local info, err = AutoDepolarizer.GetDepolarizerInfo()
    if not info then
        AutoDepolarizer.UnequipHand()
        return false, err
    end

    if info.isBusy then
        AutoDepolarizer.UnequipHand()
        return false, "Mesin sedang berjalan (" .. tostring(info.remainingText) .. ")"
    end

    if not info.isReady or not info.prompt then
        AutoDepolarizer.UnequipHand()
        return false, "Mesin Depolarizer belum siap (Prompt belum muncul)"
    end

    AutoDepolarizer.ProcessingUnit = true

    -- 1. Hold character in hand
    if Remotes:FindFirstChild("BackpackHoldCharacter") then
        Remotes.BackpackHoldCharacter:FireServer(unit.key)
        task.wait(0.35)
    end

    -- 2. Trigger ProximityPrompt
    if info.prompt and info.prompt.Parent then
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
    task.wait(0.35)

    -- 3. Confirm dialog
    if Remotes:FindFirstChild("DepolarizrConfirm") then
        Remotes.DepolarizrConfirm:FireServer(true)
    end
    task.wait(0.3)

    -- 4. Reset hand
    AutoDepolarizer.UnequipHand()

    AutoDepolarizer.ProcessingUnit = false
    return true, string.format("Unit %s (%s [%s]) berhasil dimasukkan ke Depolarizer!", unit.name, unit.rarity, unit.mutation)
end

-- ── 🔄 5. Action: Step Once ──
function AutoDepolarizer.StepOnce()
    local info, err = AutoDepolarizer.GetDepolarizerInfo()
    if not info then
        AutoDepolarizer.UnequipHand()
        AutoDepolarizer.LastStatus = "Status: " .. tostring(err)
        return false, err
    end

    -- JIKA MESIN SEDANG SIBUK: JANGAN LAKUKAN APA-APA, PASTIKAN TANGAN KOSONG & TUNGGU SAMPAI SELESAI
    if info.isBusy then
        AutoDepolarizer.UnequipHand()
        AutoDepolarizer.LastStatus = string.format("Sedang Berjalan: %s tersisa (Menunggu mesin kosong)", tostring(info.remainingText))
        return false, AutoDepolarizer.LastStatus
    end

    -- JIKA MESIN BELUM READY
    if not info.isReady then
        AutoDepolarizer.UnequipHand()
        AutoDepolarizer.LastStatus = "Menunggu mesin Depolarizer siap..."
        return false, AutoDepolarizer.LastStatus
    end

    -- CARI UNIT DI TAS DENGAN MUTASI SESUAI FILTER
    local eligibleUnits = AutoDepolarizer.GetEligibleUnits()
    if #eligibleUnits == 0 then
        AutoDepolarizer.UnequipHand()
        AutoDepolarizer.LastStatus = "Mesin Kosong (Tidak ada unit di tas dengan mutasi & rarity terpilih)"
        return false, AutoDepolarizer.LastStatus
    end

    local targetUnit = eligibleUnits[1]
    AutoDepolarizer.LastStatus = string.format("Memasukkan %s (%s [%s]) ke Depolarizer...", targetUnit.name, targetUnit.rarity, targetUnit.mutation)
    
    local success, msg = AutoDepolarizer.DepolarizeUnit(targetUnit)
    if success then
        AutoDepolarizer.LastStatus = msg
    else
        AutoDepolarizer.UnequipHand()
        AutoDepolarizer.LastStatus = "Gagal: " .. tostring(msg)
    end
    return success, msg
end

-- ── ▶️ 6. Start / Stop Automation (Smart Interval) ──
function AutoDepolarizer.StartAutoDepolarizer(interval)
    AutoDepolarizer.Enabled = true
    interval = interval or AutoDepolarizer.Interval or 5

    -- Make sure hand is clear
    AutoDepolarizer.UnequipHand()

    if depolarizerThread then task.cancel(depolarizerThread) end
    depolarizerThread = task.spawn(function()
        while AutoDepolarizer.Enabled do
            local info = AutoDepolarizer.GetDepolarizerInfo()
            
            if info and info.isBusy then
                -- Pastikan tangan selalu kosong saat menunggu
                AutoDepolarizer.UnequipHand()
                AutoDepolarizer.LastStatus = string.format("Sedang Berjalan: %s tersisa (Menunggu mesin kosong)", tostring(info.remainingText))
                task.wait(15)
            elseif info and info.isReady then
                -- Mesin ready, coba masukkan 1 unit
                local success = AutoDepolarizer.StepOnce()
                if success then
                    -- Berhasil masuk, tunggu 5 detik agar state mesin ter-update
                    task.wait(5)
                else
                    -- Tidak ada unit yang cocok, tunggu sebelum scan ulang
                    AutoDepolarizer.UnequipHand()
                    task.wait(interval)
                end
            else
                AutoDepolarizer.UnequipHand()
                task.wait(interval)
            end
        end
    end)
end

function AutoDepolarizer.StopAutoDepolarizer()
    AutoDepolarizer.Enabled = false
    if depolarizerThread then
        pcall(function() task.cancel(depolarizerThread) end)
        depolarizerThread = nil
    end
    AutoDepolarizer.ProcessingUnit = false
    AutoDepolarizer.UnequipHand()
    AutoDepolarizer.LastStatus = "Nonaktif"
end

function AutoDepolarizer.StopAll()
    AutoDepolarizer.StopAutoDepolarizer()
end

-- ── 🔔 7. Auto Confirm Remote Event Listener ──
if Remotes:FindFirstChild("DepolarizrUI") then
    Remotes.DepolarizrUI.OnClientEvent:Connect(function(data)
        -- Hanya confirm jika AutoDepolarizer sedang memproses unit secara aktif
        if AutoDepolarizer.Enabled and AutoDepolarizer.ProcessingUnit and data and data.action == "ShowConfirm" then
            task.wait(0.1)
            if Remotes:FindFirstChild("DepolarizrConfirm") then
                Remotes.DepolarizrConfirm:FireServer(true)
            end
        end
    end)
end

_G.FishAnAnimeAutoDepolarizer = AutoDepolarizer
return AutoDepolarizer
