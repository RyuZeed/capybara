-- =================================================================
-- 🎰 RITOD HUB | AUTO ROLL & UNIT SNIPER ENGINE
-- Game: Roll Anime For Fight / Anime Auto Roll
-- =================================================================

local AutoRollModule = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local CharRemotes = RS:WaitForChild("Remotes"):WaitForChild("Characters")
local RollRemote = CharRemotes:WaitForChild("Roll")
local BuyRemote = CharRemotes:WaitForChild("Buy")

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

function AutoRollModule.MoveToRollButton(rollBtn)
    local hrp = AutoRollModule.GetHRP()
    if hrp and rollBtn and rollBtn:IsA("BasePart") then
        local btnPos = rollBtn.Position
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = CFrame.new(btnPos + Vector3.new(0, 0.5, 3), btnPos)
        task.wait(0.15)
    end
end

function AutoRollModule.FindMyPlot()
    local plots = WS:FindFirstChild("Plots")
    if not plots then return nil end
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
                if d:IsA("TextLabel") and d.Text == LocalPlayer.Name then
                    return plot
                end
            end
        end
    end
    return nil
end

function AutoRollModule.GetRollPrompt(plot)
    local roll = plot:FindFirstChild("Roll")
    if not roll then return nil, nil end
    for _, p in ipairs(roll:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Name == "RollPrompt" then
            p.Enabled = true
            return p, p.Parent
        end
    end
    return nil, nil
end

function AutoRollModule.TriggerRoll(prompt)
    if not prompt then return end
    pcall(function()
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 100
        prompt.RequiresLineOfSight = false
    end)
    if typeof(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(prompt, 0) end)
        pcall(function() fireproximityprompt(prompt) end)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.2)
            prompt:InputHoldEnd()
        end)
    end
end

function AutoRollModule.GetTargetUnitsOnPedestals(plot, selectedUnitsMap, allUnitsMap)
    local targetsFound = {}
    local roll = plot:FindFirstChild("Roll")
    local rollOrigin = roll and roll:GetPivot().Position or plot:GetPivot().Position
    
    for _, model in ipairs(plot:GetDescendants()) do
        if model:IsA("Model") then
            local buyPrompt = nil
            for _, p in ipairs(model:GetDescendants()) do
                if p:IsA("ProximityPrompt") and p.Name ~= "RollPrompt" then
                    local act = tostring(p.ActionText):lower()
                    local pName = p.Name:lower()
                    if act:find("buy") or pName:find("buy") or act:find("$") then
                        buyPrompt = p
                        break
                    end
                end
            end
            
            if buyPrompt then
                local charData = nil
                local mName = model.Name:lower()
                if selectedUnitsMap[mName] and allUnitsMap[mName] then 
                    charData = allUnitsMap[mName] 
                end
                
                if not charData then
                    for _, lbl in ipairs(model:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Text and #lbl.Text > 0 then
                            local txt = lbl.Text:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                            if selectedUnitsMap[txt] and allUnitsMap[txt] then
                                charData = allUnitsMap[txt]
                                break
                            end
                        end
                    end
                end
                
                if charData then
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

function AutoRollModule.BuySpecificTarget(target, rollBtn)
    if not target or not target.prompt or not target.prompt.Parent then return false end
    local p = target.prompt
    
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
        task.wait(0.8)
        p:InputHoldEnd()
    end)
    
    AutoRollModule.MoveToRollButton(rollBtn)
    
    local isGone = (p == nil) or (p.Parent == nil) or (not p:IsDescendantOf(workspace))
    return isGone
end

function AutoRollModule.Start(options)
    if isRunning then return end
    isRunning = true
    
    local selectedUnits = options.SelectedUnits or {}
    local allUnitsMap = options.AllUnitsMap or {}
    local getInterval = options.GetInterval or function() return 2.5 end
    local onStatus = options.OnStatus or function() end
    local onBought = options.OnBought or function() end
    local onError = options.OnError or function() end
    
    rollThread = task.spawn(function()
        local myPlot = AutoRollModule.FindMyPlot()
        if not myPlot then
            onError("Plot kamu tidak ditemukan!")
            isRunning = false
            return
        end
        
        local rollPrompt, rollBtn = AutoRollModule.GetRollPrompt(myPlot)
        if not rollPrompt or not rollBtn then
            onError("RollPrompt tidak ditemukan di plot!")
            isRunning = false
            return
        end
        
        rollPrompt.Enabled = true
        AutoRollModule.MoveToRollButton(rollBtn)
        task.wait(0.5)
        
        local rollCount = 0
        
        while isRunning do
            rollCount += 1
            onStatus(string.format("Status: 🎰 Roll #%d | Plot: %s", rollCount, myPlot.Name), "rolling", rollCount)
            
            AutoRollModule.MoveToRollButton(rollBtn)
            AutoRollModule.TriggerRoll(rollPrompt)
            
            task.wait(getInterval())
            
            if not isRunning then break end
            
            local targets = AutoRollModule.GetTargetUnitsOnPedestals(myPlot, selectedUnits, allUnitsMap)
            
            if #targets > 0 then
                onStatus(string.format("Status: 🎯 %d Unit Target Ditemukan! Membeli...", #targets), "found", #targets)
                
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
                        local bought = AutoRollModule.BuySpecificTarget(t, rollBtn)
                        if bought then break end
                        task.wait(0.3)
                    end
                    
                    onBought(t)
                    task.wait(0.4)
                end
                
                AutoRollModule.MoveToRollButton(rollBtn)
                onStatus("Status: 🎉 Sukses Beli! Melanjutkan Hunt...", "resuming")
                task.wait(1.5)
            end
        end
        
        if not isRunning then
            onStatus("Status: ⚪ OFF (Idle)", "idle")
        end
    end)
end

function AutoRollModule.Stop()
    isRunning = false
    local myPlot = AutoRollModule.FindMyPlot()
    if myPlot then
        local rollPrompt = AutoRollModule.GetRollPrompt(myPlot)
        if rollPrompt then rollPrompt.Enabled = true end
    end
end

function AutoRollModule.IsRunning()
    return isRunning
end

return AutoRollModule
