local AutoTutorial = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()
local MainGui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainGui", 10)

-- =================================================================
-- 🛠️ HELPER FUNCTIONS
-- =================================================================

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 10) or char:FindFirstChild("HumanoidRootPart")
end

local function callRemote(name, ...)
    local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
    local remote = remotes and remotes:FindFirstChild(name)
    if not remote then
        remote = ReplicatedStorage:FindFirstChild(name, true)
    end
    if remote then
        if remote:IsA("RemoteEvent") then
            return remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        end
    end
end

-- =================================================================
-- 🏡 DETEKSI PLOT OWNER MILIK SENDIRI
-- =================================================================

local function getMyPlot()
    local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("Plots")
    if not plots then
        plots = workspace:FindFirstChild("Plots", true)
    end

    if plots then
        -- 1. Cek berdasarkan atribut Owner / OwnerId / Player
        for _, plot in ipairs(plots:GetChildren()) do
            local ownerAttr = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerId") or plot:GetAttribute("OwnerName") or plot:GetAttribute("Player")
            if ownerAttr and (ownerAttr == LocalPlayer.Name or ownerAttr == LocalPlayer.UserId or ownerAttr == tostring(LocalPlayer.UserId)) then
                return plot
            end

            -- 2. Cek ValueBase (Owner / Player)
            local ownerVal = plot:FindFirstChild("Owner") or plot:FindFirstChild("Player") or plot:FindFirstChild("OwnerValue")
            if ownerVal then
                if ownerVal:IsA("ObjectValue") and (ownerVal.Value == LocalPlayer or ownerVal.Value == LocalPlayer.Character) then
                    return plot
                elseif (ownerVal:IsA("StringValue") or ownerVal:IsA("IntValue")) and (ownerVal.Value == LocalPlayer.Name or ownerVal.Value == LocalPlayer.UserId or ownerVal.Value == tostring(LocalPlayer.UserId)) then
                    return plot
                end
            end

            -- 3. Cek Nama Plot
            if plot.Name == LocalPlayer.Name or plot.Name == tostring(LocalPlayer.UserId) then
                return plot
            end

            -- 4. Cek TextLabel / Papan Nama di dalam Plot
            for _, desc in ipairs(plot:GetDescendants()) do
                if desc:IsA("TextLabel") and (desc.Text == LocalPlayer.Name or desc.Text:find(LocalPlayer.Name)) then
                    return plot
                end
            end
        end

        -- Fallback aman
        return plots:FindFirstChild("1") or plots:GetChildren()[1]
    end
    return nil
end

local function triggerPrompt(keyword)
    local myPlot = getMyPlot()
    local container = myPlot or (workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")) or workspace

    for _, prompt in ipairs(container:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local text = ((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "") .. " " .. (prompt.Name or "")):lower()
            if not keyword or text:find(keyword:lower()) then
                pcall(function()
                    prompt.HoldDuration = 0
                    prompt.RequiresLineOfSight = false
                    prompt.MaxActivationDistance = 100
                end)
                if typeof(fireproximityprompt) == "function" then
                    pcall(function() fireproximityprompt(prompt, 0) end)
                    pcall(function() fireproximityprompt(prompt, 1) end)
                    pcall(function() fireproximityprompt(prompt) end)
                end
                pcall(function()
                    prompt:InputHoldBegin()
                    task.wait(0.04)
                    prompt:InputHoldEnd()
                end)
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.04)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
            end
        end
    end
end

-- =================================================================
-- 🥚 PLACE EGG ON LANE
-- =================================================================

local function placeEggOnLane()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = getHRP()
    if not hrp then return end

    local backpack = LocalPlayer:WaitForChild("Backpack")
    local camera = workspace.CurrentCamera

    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then t.Parent = backpack end
    end
    task.wait(0.5)

    local eggTool = nil
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("egg") or tool.Name:lower():find("capybara")) then
            eggTool = tool
            break
        end
    end

    if eggTool then
        eggTool.Parent = char
        eggTool:Activate()
    else
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    end
    task.wait(1)

    local targetLook = hrp.Position + (hrp.CFrame.LookVector * 4) - Vector3.new(0, 2, 0)
    camera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 4, 0), targetLook)
    task.wait(0.3)

    local viewSize = camera.ViewportSize
    local centerX = math.floor(viewSize.X / 2)
    local centerY = math.floor(viewSize.Y / 2)

    if typeof(mousemoveabs) == "function" then mousemoveabs(centerX, centerY) end
    task.wait(0.1)

    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
    task.wait(0.08)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)

    if typeof(mouse1press) == "function" then
        mouse1press()
        task.wait(0.08)
        mouse1release()
    end
end

-- =================================================================
-- 🚀 RUN AUTO TUTORIAL
-- =================================================================

local function runAutoTutorial()
    if _G.AutoTutorialRunning then return end
    _G.AutoTutorialRunning = true
    print("🚀 [Ritod Hub] Auto Tutorial Started...")

    task.spawn(function()
        pcall(function()
            local HATCH_WAIT = 8
            local hrp = getHRP()
            if not hrp then return end

            -- Deteksi Plot Owner
            local myPlot = getMyPlot()
            local eggShop = workspace.World.Map:FindFirstChild("EggShop") or workspace:FindFirstChild("EggShop", true)
            MainGui = MainGui or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("MainGui"))

            -- STEP 1: BELI CAPYBARA EGG PERTAMA
            if eggShop then hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5) end
            task.wait(1)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(8)

            -- STEP 2: TARUH EGG PERTAMA DI LANE
            local purchasedLane = myPlot and myPlot:FindFirstChild("TowerArea") and (myPlot.TowerArea:FindFirstChild("Purchased4") or myPlot.TowerArea:GetChildren()[1])
            if purchasedLane then
                local targetPart = purchasedLane:FindFirstChild("TowerAreaPart") or purchasedLane:GetChildren()[1]
                if targetPart then
                    if targetPart:IsA("BasePart") then
                        hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0))
                    else
                        hrp.CFrame = CFrame.new(targetPart:GetPivot().Position + Vector3.new(0, 3, 0))
                    end
                end
            end
            task.wait(1)
            placeEggOnLane()
            task.wait(HATCH_WAIT)

            -- STEP 3: HATCH EGG PERTAMA
            triggerPrompt("hatch")
            callRemote("Hatch")
            task.wait(15)

            -- STEP 4: PASANG CARROT VIA EQUIP BEST PLANTS
            callRemote("EquipBestPlants")
            task.wait(7)

            -- STEP 5: GROW TREE (REBIRTH)
            local treeMenuBtn = MainGui and MainGui.Root.MainButtonsFrame:FindFirstChild("TreeButton")
            if treeMenuBtn and typeof(firesignal) == "function" then
                firesignal(treeMenuBtn.MouseButton1Click)
                firesignal(treeMenuBtn.Activated)
            end
            task.wait(1.5)

            local growBtn = MainGui and MainGui.Root.Frames.Tree.Grow:FindFirstChild("Button")
            if growBtn and typeof(firesignal) == "function" then
                firesignal(growBtn.MouseButton1Click)
                firesignal(growBtn.Activated)
            end
            task.wait(1.5)

            local yesBtn = MainGui and MainGui.Root.Frames.Confirm.Yes:FindFirstChild("Button")
            if yesBtn and typeof(firesignal) == "function" then
                firesignal(yesBtn.MouseButton1Click)
                firesignal(yesBtn.Activated)
            end
            task.wait(1)
            callRemote("BuyTreeUpgrade")
            task.wait(7)

            -- STEP 6: BELI POT KEDUA
            local pottedPlants = workspace.World.Map:FindFirstChild("PottedPlants") or workspace:FindFirstChild("PottedPlants", true)
            local carrotModel = pottedPlants and pottedPlants:FindFirstChild("Server") and pottedPlants.Server:GetChildren()[1]
            if carrotModel then
                local carrotPos = carrotModel:GetPivot().Position
                hrp.CFrame = CFrame.new(carrotPos + Vector3.new(5, 2, 0))
                task.wait(1)
                for _, part in ipairs(workspace.World.Map:GetDescendants()) do
                    if part:IsA("BasePart") and (part.Position - carrotPos).Magnitude <= 15 then
                        if typeof(firetouchinterest) == "function" then
                            firetouchinterest(hrp, part, 0)
                            task.wait(0.1)
                            firetouchinterest(hrp, part, 1)
                        end
                    end
                end
            end
            task.wait(1)
            local confirmYes = MainGui and MainGui.Root.Frames.Confirm.Yes:FindFirstChild("Button")
            if confirmYes and typeof(firesignal) == "function" then
                firesignal(confirmYes.MouseButton1Click)
                firesignal(confirmYes.Activated)
            end
            callRemote("BuyItem", "Pot2")
            task.wait(12)

            -- STEP 7: KLAIM SEMUA UANG
            local colMachine = (myPlot and myPlot:FindFirstChild("CollectionMachine")) or workspace.World.Map:FindFirstChild("CollectionMachine", true) or workspace:FindFirstChild("CollectionMachine", true)
            if colMachine then
                hrp.CFrame = CFrame.new(colMachine:GetPivot().Position + Vector3.new(0, 2, 3))
                task.wait(1)
                triggerPrompt("collect")
            end
            callRemote("CollectMoneyFromPlant")
            task.wait(7)

            -- STEP 8: BELI EGG KEDUA
            if eggShop then hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5) end
            task.wait(1)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(7)

            -- STEP 9: TARUH EGG KEDUA DI LANE
            if purchasedLane then
                local parts = purchasedLane:GetChildren()
                local targetPart = parts[2] or parts[1]
                if targetPart then
                    if targetPart:IsA("BasePart") then
                        hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0))
                    else
                        hrp.CFrame = CFrame.new(targetPart:GetPivot().Position + Vector3.new(0, 3, 0))
                    end
                end
            end
            task.wait(1)
            placeEggOnLane()
            task.wait(HATCH_WAIT)

            -- STEP 10: HATCH EGG KEDUA
            triggerPrompt("hatch")
            callRemote("Hatch")
            task.wait(5)

            -- STEP 11: SUMMON BOSS "Scarlet Carrot"
            local summonBtn = MainGui and MainGui.Root.Frames.BossSummoner.BossInfo.SummonButton:FindFirstChild("Button")
            if summonBtn and typeof(firesignal) == "function" then
                firesignal(summonBtn.MouseButton1Click)
                firesignal(summonBtn.Activated)
            end
            callRemote("SummonBoss", "Scarlet Carrot")
            task.wait(30)

            -- STEP 12: LANGSUNG EQUIP BEST PLANTS
            callRemote("EquipBestPlants")
            task.wait(5)
            callRemote("SaveTutorialStage", 99)
            callRemote("RequestTutorialCompleted")
        end)

        _G.AutoTutorialRunning = false
        print("🏆 [Ritod Hub] AUTO TUTORIAL COMPLETE!")
    end)
end

-- =================================================================
-- 📦 EXPORT MODUL
-- =================================================================

function AutoTutorial.Start()
    runAutoTutorial()
end

function AutoTutorial.Stop()
    _G.AutoTutorialRunning = false
    print("🛑 [Ritod Hub] Auto Tutorial Dihentikan.")
end

return AutoTutorial
