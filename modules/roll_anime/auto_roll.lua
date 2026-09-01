-- =================================================================
-- 🎰 RITOD HUB | AUTO ROLL & UNIT SNIPER ENGINE
-- Game: Roll Anime For Fight / Anime Auto Roll
-- =================================================================

local AutoRollModule = {}
_G.AutoRollModule = AutoRollModule
_G.AutoRoll = AutoRollModule

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

local CharRemotes = nil
local RollRemote = nil
local BuyRemote = nil

pcall(function()
    local remotes = RS:FindFirstChild("Remotes")
    if remotes then
        CharRemotes = remotes:FindFirstChild("Characters")
        if CharRemotes then
            RollRemote = CharRemotes:FindFirstChild("Roll")
            BuyRemote = CharRemotes:FindFirstChild("Buy")
        end
    end
end)

local isRunning = false
local rollThread = nil

function AutoRollModule.GetGold()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, c in ipairs(ls:GetChildren()) do
            if c.Name:find("Gold") or c.Name:find("💰") then
                return c.Value or 0
            end
        end
    end
    return 0
end

function AutoRollModule.GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

function AutoRollModule.MoveToRollButton(rollBtn, maxDist)
    maxDist = maxDist or 0
    local hrp = AutoRollModule.GetHRP()
    if hrp and rollBtn and rollBtn:IsA("BasePart") then
        local btnPos = rollBtn.Position
        local currentDist = (hrp.Position - btnPos).Magnitude
        if maxDist <= 0 or currentDist > maxDist then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            hrp.CFrame = CFrame.new(btnPos + Vector3.new(0, 0.5, 3), btnPos)
            task.wait(0.1)
        end
    end
end

function AutoRollModule.WaitForCharacter(timeout)
    local start = tick()
    timeout = timeout or 15
    while tick() - start < timeout do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then return char, hrp end
        task.wait(0.5)
    end
    local char = LocalPlayer.Character
    return char, char and char:FindFirstChild("HumanoidRootPart")
end

function AutoRollModule.FindMyPlot(timeout)
    timeout = timeout or 0
    local start = tick()
    repeat
        local plots = WS:FindFirstChild("Plots")
        if plots then
            for _, plot in ipairs(plots:GetChildren()) do
                for attrName, attrVal in pairs(plot:GetAttributes()) do
                    if tostring(attrVal) == LocalPlayer.Name or tostring(attrVal) == tostring(LocalPlayer.UserId) then
                        return plot
                    end
                end
            end
            for _, plot in ipairs(plots:GetChildren()) do
                local namePart = plot:FindFirstChild("NameBillboardPart", true)
                if namePart then
                    for _, d in ipairs(namePart:GetDescendants()) do
                        if d:IsA("TextLabel") and (d.Text == LocalPlayer.Name or d.Text:find(LocalPlayer.Name)) then
                            return plot
                        end
                    end
                end
            end
        end
        if timeout > 0 and (tick() - start < timeout) then
            task.wait(0.5)
        else
            break
        end
    until false
    return nil
end

local ProximityPromptService = game:GetService("ProximityPromptService")
pcall(function()
    ProximityPromptService.PromptShown:Connect(function(p)
        if isRunning and p then
            local pName = tostring(p.Name):lower()
            local act = tostring(p.ActionText):lower()
            if pName:find("roll") or act:find("summon") or act:find("roll") then
                pcall(function()
                    p.Style = Enum.ProximityPromptStyle.Custom
                    p.MaxActivationDistance = 0
                    p.UIOffset = Vector2.new(0, 999999)
                end)
            end
        end
    end)
end)

function AutoRollModule.GetRollPrompt(plot, timeout)
    if not plot then return nil, nil end
    timeout = timeout or 0
    local start = tick()
    repeat
        -- 1. Cari di child Roll / Button
        for _, p in ipairs(plot:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                local pName = p.Name:lower()
                local act = tostring(p.ActionText):lower()
                if pName == "rollprompt" or pName:find("roll") or act:find("summon") or act:find("roll") then
                    pcall(function()
                        p.Style = Enum.ProximityPromptStyle.Custom
                        p.MaxActivationDistance = 0
                        p.UIOffset = Vector2.new(0, 999999)
                    end)
                    return p, p.Parent
                end
            end
        end

        if timeout > 0 and (tick() - start < timeout) then
            task.wait(0.5)
        else
            break
        end
    until false
    return nil, nil
end

function AutoRollModule.TriggerRoll(prompt)
    if not prompt then return end
    pcall(function()
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 0
        prompt.RequiresLineOfSight = false
        prompt.Style = Enum.ProximityPromptStyle.Custom
        prompt.UIOffset = Vector2.new(0, 999999)
    end)
    if typeof(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(prompt, 0) end)
        pcall(function() fireproximityprompt(prompt) end)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.1)
            prompt:InputHoldEnd()
        end)
    end
end

local function getInstancePosition(inst)
    if not inst then return Vector3.zero end
    if inst:IsA("Model") then
        local prim = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        if prim then return prim.Position end
        local ok, piv = pcall(function() return inst:GetPivot().Position end)
        if ok and piv then return piv end
    elseif inst:IsA("BasePart") then
        return inst.Position
    elseif inst:IsA("Folder") or inst:IsA("Instance") then
        local part = inst:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.Position end
    end
    return Vector3.zero
end

function AutoRollModule.GetTargetUnitsOnPedestals(plot, selectedUnitsMap, allUnitsMap, autoSecretGod)
    local targetsFound = {}
    local seenModels = {}
    if not plot then return targetsFound end

    local roll = plot:FindFirstChild("Roll")
    local rollOrigin = getInstancePosition(roll)
    if rollOrigin == Vector3.zero then
        rollOrigin = getInstancePosition(plot)
    end
    
    for _, model in ipairs(plot:GetDescendants()) do
        if model:IsA("Model") and not seenModels[model] then
            local buyPrompt = nil
            for _, p in ipairs(model:GetDescendants()) do
                if p:IsA("ProximityPrompt") then
                    local act = tostring(p.ActionText):lower()
                    local pName = p.Name:lower()
                    if pName ~= "rollprompt" and not act:find("summon") then
                        if act:find("buy") or pName:find("buy") or act:find("pick") or pName:find("placement") or act:find("$") or act:find("claim") then
                            buyPrompt = p
                            break
                        end
                    end
                end
            end
            
            if buyPrompt then
                local charData = nil
                
                local function findMatch(raw)
                    if not raw or #raw == 0 then return nil end
                    local text = tostring(raw):gsub("%[.-%]", ""):gsub("%$[%d,]+", ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if #text == 0 then return nil end
                    
                    local k1 = text:lower()
                    local k2 = k1:gsub("%s+", "")
                    local k3 = k1:gsub("[^%w%s]", ""):gsub("%s+", "")
                    
                    local matched = allUnitsMap[k1] or allUnitsMap[k2] or allUnitsMap[k3] or allUnitsMap[text]
                    if not matched then
                        -- Check sub-string match from allUnitsMap
                        for unitKey, uEntry in pairs(allUnitsMap) do
                            if #unitKey > 3 and (k1 == unitKey or k2 == unitKey or k1:find(unitKey, 1, true)) then
                                matched = uEntry
                                break
                            end
                        end
                    end
                    
                    if not matched then return nil end
                    
                    -- Mode 1: Auto Supreme / Secret / God / Limited / Divine
                    if autoSecretGod then
                        local r = tostring(matched.rarity):lower()
                        if r == "supreme" or r == "secret" or r == "god" or r == "limited" or r == "divine" or r == "special" then
                            return matched
                        end
                    end
                    
                    -- Mode 2: Manual Checklist (Hanya beli jika terpilih di checklist)
                    if selectedUnitsMap and type(selectedUnitsMap) == "table" then
                        local rawLower  = tostring(matched.name):lower()
                        local dispLower = tostring(matched.displayName):lower()
                        local rawClean  = rawLower:gsub("%s+", "")
                        local dispClean = dispLower:gsub("%s+", "")
                        local sid       = tostring(matched.id or "")
                        
                        local isSelected = (selectedUnitsMap[rawLower] == true)
                            or (selectedUnitsMap[dispLower] == true)
                            or (selectedUnitsMap[rawClean] == true)
                            or (selectedUnitsMap[dispClean] == true)
                            or (sid ~= "" and selectedUnitsMap[sid] == true)
                            or (sid ~= "" and selectedUnitsMap[sid:lower()] == true)
                            
                        if isSelected then
                            return matched
                        end
                    end
                    
                    return nil
                end
                
                charData = findMatch(model.Name)
                
                if not charData then
                    for _, lbl in ipairs(model:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Text and #lbl.Text > 0 then
                            charData = findMatch(lbl.Text)
                            if charData then break end
                        end
                    end
                end
                
                if charData then
                    seenModels[model] = true
                    local targetPart = model.PrimaryPart or 
                                       model:FindFirstChild("HumanoidRootPart") or 
                                       model:FindFirstChild("Head") or 
                                       model:FindFirstChild("Torso") or 
                                       model:FindFirstChildWhichIsA("BasePart")
                    
                    if targetPart then
                        local slot = 1
                        local relX = targetPart.Position.X - rollOrigin.X
                        if relX < -3 then slot = 1
                        elseif relX > 3 then slot = 3
                        else slot = 2 end
                        
                        table.insert(targetsFound, {
                            model = model,
                            name = charData.displayName,
                            rarity = charData.rarity,
                            price = charData.price,
                            id = charData.id,
                            slot = slot,
                            part = targetPart,
                            prompt = buyPrompt
                        })
                    end
                end
            end
        end
    end
    
    return targetsFound
end

function AutoRollModule.BuySpecificTarget(target, returnCFrame)
    if not target or not target.prompt or not target.prompt.Parent then return false end
    local p = target.prompt
    local hrp = AutoRollModule.GetHRP()
    
    -- 1. Teleport ke depan unit target untuk menjamin interaksi prompt
    if hrp and target.part and target.part:IsA("BasePart") then
        local partPos = target.part.Position
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = CFrame.new(partPos + Vector3.new(0, 0.5, 2.5), partPos)
        task.wait(0.1)
    end
    
    pcall(function()
        p.HoldDuration = 0
        p.MaxActivationDistance = 999999
        p.RequiresLineOfSight = false
        p.Enabled = true
    end)
    
    if typeof(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(p, 0) end)
        pcall(function() fireproximityprompt(p) end)
    end
    
    pcall(function()
        p:InputHoldBegin()
        task.wait(0.3)
        p:InputHoldEnd()
    end)
    
    -- 2. Teleport kembali ke posisi awal sebelum beli
    if hrp and returnCFrame then
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = returnCFrame
        task.wait(0.08)
    end
    
    local isGone = (p == nil) or (p.Parent == nil) or (not p:IsDescendantOf(workspace))
    return isGone
end

function AutoRollModule.GetQuestRollProgress()
    local dailyCurrent, dailyMax = 0, 250
    local weeklyCurrent, weeklyMax = 0, 5000
    local dailyCompleted = false
    local weeklyCompleted = false
    
    pcall(function()
        local pGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local mainUI = pGui and pGui:FindFirstChild("MainUI")
        local frames = mainUI and mainUI:FindFirstChild("Frames")
        local bp = frames and frames:FindFirstChild("Battlepass")
        
        if bp then
            for _, desc in ipairs(bp:GetDescendants()) do
                if desc:IsA("TextLabel") then
                    local text = desc.Text:upper()
                    if text:find("ROLL 250") or (text:find("ROLL") and text:find("250")) then
                        local parent = desc.Parent
                        if parent then
                            local progLabel = parent:FindFirstChild("Progress", true)
                            if progLabel and progLabel:IsA("TextLabel") then
                                local c, m = progLabel.Text:match("(%d+)/(%d+)")
                                if c and m then
                                    dailyCurrent = tonumber(c) or 0
                                    dailyMax = tonumber(m) or 250
                                end
                            end
                        end
                    elseif text:find("ROLL 5000") or (text:find("ROLL") and text:find("5000")) then
                        local parent = desc.Parent
                        if parent then
                            local progLabel = parent:FindFirstChild("Progress", true)
                            if progLabel and progLabel:IsA("TextLabel") then
                                local c, m = progLabel.Text:match("(%d+)/(%d+)")
                                if c and m then
                                    weeklyCurrent = tonumber(c) or 0
                                    weeklyMax = tonumber(m) or 5000
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    if dailyCurrent >= dailyMax and dailyMax > 0 then dailyCompleted = true end
    if weeklyCurrent >= weeklyMax and weeklyMax > 0 then weeklyCompleted = true end
    
    return {
        DailyCurrent = dailyCurrent,
        DailyMax = dailyMax,
        DailyCompleted = dailyCompleted,
        WeeklyCurrent = weeklyCurrent,
        WeeklyMax = weeklyMax,
        WeeklyCompleted = weeklyCompleted,
    }
end

function AutoRollModule.Start(options)
    if isRunning then return end
    isRunning = true
    
    local selectedUnits = options.SelectedUnits or {}
    local allUnitsMap = options.AllUnitsMap or {}
    local getAutoSecretGod = options.GetAutoSecretGod or function() return options.AutoSecretGod or false end
    local getQuestRollMode = options.GetQuestRollMode or function() return options.QuestRollMode or false end
    local getInterval = options.GetInterval or function() return 2.5 end
    local onStatus = options.OnStatus or function() end
    local onBought = options.OnBought or function() end
    local onError = options.OnError or function() end
    
    rollThread = task.spawn(function()
        onStatus("Status: ⏳ Menunggu karakter siap...", "waiting")
        AutoRollModule.WaitForCharacter(15)
        if not isRunning then return end
        
        onStatus("Status: ⏳ Menunggu plot dimuat...", "waiting_plot")
        local myPlot = AutoRollModule.FindMyPlot(25)
        if not isRunning then return end
        if not myPlot then
            onError("Plot kamu tidak ditemukan (timeout 25 detik)!")
            isRunning = false
            return
        end
        
        onStatus("Status: ⏳ Menunggu stasiun RollPrompt...", "waiting_prompt")
        local rollPrompt, rollBtn = AutoRollModule.GetRollPrompt(myPlot, 25)
        if not isRunning then return end
        if not rollPrompt or not rollBtn then
            onError("RollPrompt tidak ditemukan di plot (timeout 25 detik)!")
            isRunning = false
            return
        end
        
        rollPrompt.Enabled = true
        task.wait(0.2)
        
        local rollCount = 0
        
        while isRunning do
            -- Cek Mode Auto Roll Daily & Weekly Quest
            local isQuestMode = (type(getQuestRollMode) == "function" and getQuestRollMode()) or (getQuestRollMode == true)
            local questModeText = ""
            
            if isQuestMode then
                local qProg = AutoRollModule.GetQuestRollProgress()
                
                -- Kasus 1: Daily Quest belum selesai -> Roll Daily (250x)
                if not qProg.DailyCompleted then
                    questModeText = string.format(" [🎯 Daily Quest: %d/%d]", qProg.DailyCurrent, qProg.DailyMax)
                -- Kasus 2: Daily selesai, Weekly belum selesai -> Pindah ke Weekly (5000x)
                elseif not qProg.WeeklyCompleted then
                    questModeText = string.format(" [🏆 Weekly Quest: %d/%d (Daily Selesai)]", qProg.WeeklyCurrent, qProg.WeeklyMax)
                -- Kasus 3: Daily dan Weekly keduanya sudah selesai -> Tunggu Reset
                else
                    onStatus(string.format("Status: ✅ [Selesai] Daily (%d/%d) & Weekly (%d/%d) Tercapai! Menunggu Reset...", qProg.DailyCurrent, qProg.DailyMax, qProg.WeeklyCurrent, qProg.WeeklyMax), "quest_done")
                    task.wait(5)
                    continue
                end
            end

            -- Jika prompt atau button hilang karena respawn/streaming, re-acquire dengan sabar
            if not rollPrompt or not rollPrompt.Parent or not rollBtn or not rollBtn.Parent then
                onStatus("Status: 🔄 Memperbarui koneksi RollPrompt...", "reacquiring")
                rollPrompt, rollBtn = AutoRollModule.GetRollPrompt(myPlot, 10)
                if not rollPrompt or not rollBtn then
                    myPlot = AutoRollModule.FindMyPlot(10) or myPlot
                    rollPrompt, rollBtn = AutoRollModule.GetRollPrompt(myPlot, 10)
                end
            end
            
            if rollPrompt and rollBtn then
                rollCount += 1
                local modeText = questModeText
                local isAutoSG = (type(getAutoSecretGod) == "function" and getAutoSecretGod()) or (getAutoSecretGod == true)
                if isAutoSG then
                    modeText = modeText .. " [👑 Auto Secret/God]"
                end
                
                onStatus(string.format("Status: 🎰 Roll #%d%s | Plot: %s", rollCount, modeText, myPlot.Name), "rolling", rollCount)
                
                -- Trigger roll langsung tanpa teleportasi konstan
                AutoRollModule.TriggerRoll(rollPrompt)
            end
            
            task.wait(getInterval())
            
            if not isRunning then break end
            
            local isAutoSG = (type(getAutoSecretGod) == "function" and getAutoSecretGod()) or (getAutoSecretGod == true)
            local targets = AutoRollModule.GetTargetUnitsOnPedestals(myPlot, selectedUnits, allUnitsMap, isAutoSG)
            
            if #targets > 0 then
                onStatus(string.format("Status: 🎯 %d Unit Target Ditemukan! Membeli...", #targets), "found", #targets)
                local curHrp = AutoRollModule.GetHRP()
                local initialCF = curHrp and curHrp.CFrame
                
                for idx, t in ipairs(targets) do
                    onStatus(string.format("Status: 💰 Membeli [%s] %s ($%d)...", t.rarity, t.name, t.price), "buying", t)
                    
                    if t.price > 0 and AutoRollModule.GetGold() < t.price then
                        onStatus(string.format("Status: ⏳ Menunggu gold ($%d / $%d)...", AutoRollModule.GetGold(), t.price), "waiting_gold", t)
                        while isRunning and AutoRollModule.GetGold() < t.price do
                            task.wait(2)
                        end
                    end
                    
                    if not isRunning then break end
                    
                    for attempt = 1, 3 do
                        local bought = AutoRollModule.BuySpecificTarget(t, initialCF)
                        if bought then break end
                        task.wait(0.3)
                    end
                    
                    onBought(t)
                    task.wait(0.3)
                end
                
                onStatus("Status: 🎉 Sukses Beli! Melanjutkan Hunt...", "resuming")
                task.wait(1.2)
            end
        end
        
        if not isRunning then
            onStatus("Status: ⚪ OFF (Idle)", "idle")
        end
    end)
end

function AutoRollModule.Stop()
    isRunning = false
    if rollThread then
        task.cancel(rollThread)
        rollThread = nil
    end
    local myPlot = AutoRollModule.FindMyPlot()
    if myPlot then
        for _, p in ipairs(myPlot:GetDescendants()) do
            if p:IsA("ProximityPrompt") then
                local pName = tostring(p.Name):lower()
                local act = tostring(p.ActionText):lower()
                if pName:find("roll") or act:find("summon") or act:find("roll") then
                    pcall(function()
                        p.Enabled = true
                        p.Style = Enum.ProximityPromptStyle.Default
                        p.MaxActivationDistance = 10
                        p.UIOffset = Vector2.new(0, 0)
                        p.HoldDuration = 0.5
                    end)
                end
            end
        end
    end
end

function AutoRollModule.IsRunning()
    return isRunning
end

-- =================================================================
-- 🎯 STANDALONE AUTO BUY / SNIPER (NON-ROLLING / CONVEYOR WATCHER)
-- =================================================================
local isSniperRunning = false
local sniperThread = nil

function AutoRollModule.StartAutoSniper(options)
    if isSniperRunning then return end
    isSniperRunning = true

    local selectedUnits = options.SelectedUnits or {}
    local allUnitsMap = options.AllUnitsMap or {}
    local getAutoSecretGod = options.GetAutoSecretGod or function() return options.AutoSecretGod or false end
    local onBought = options.OnBought or function() end
    local onStatus = options.OnStatus or function() end

    sniperThread = task.spawn(function()
        local myPlot = AutoRollModule.FindMyPlot(20)
        onStatus("Status: 🎯 Auto Sniper Aktif (Memantau Conveyor)...", "sniper_active")

        while isSniperRunning do
            if not myPlot or not myPlot.Parent then
                myPlot = AutoRollModule.FindMyPlot(5)
            end

            if myPlot then
                local isAutoSG = (type(getAutoSecretGod) == "function" and getAutoSecretGod()) or (getAutoSecretGod == true)
                local targets = AutoRollModule.GetTargetUnitsOnPedestals(myPlot, selectedUnits, allUnitsMap, isAutoSG)

                if #targets > 0 then
                    local curHrp = AutoRollModule.GetHRP()
                    local initialCF = curHrp and curHrp.CFrame

                    for _, t in ipairs(targets) do
                        if not isSniperRunning then break end

                        if t.price > 0 and AutoRollModule.GetGold() < t.price then
                            onStatus(string.format("Sniper: ⏳ Menunggu gold ($%d / $%d)...", AutoRollModule.GetGold(), t.price), "waiting_gold")
                            while isSniperRunning and AutoRollModule.GetGold() < t.price do
                                task.wait(1.5)
                            end
                        end

                        if not isSniperRunning then break end

                        onStatus(string.format("Sniper: 💰 Membeli [%s] %s ($%d)...", t.rarity, t.name, t.price), "buying")
                        for attempt = 1, 3 do
                            local bought = AutoRollModule.BuySpecificTarget(t, initialCF)
                            if bought then break end
                            task.wait(0.2)
                        end
                        onBought(t)
                        task.wait(0.3)
                    end
                end
            end
            task.wait(0.4)
        end
    end)
end

function AutoRollModule.StopAutoSniper()
    isSniperRunning = false
    if sniperThread then
        task.cancel(sniperThread)
        sniperThread = nil
    end
end

function AutoRollModule.IsSniperRunning()
    return isSniperRunning
end

return AutoRollModule
