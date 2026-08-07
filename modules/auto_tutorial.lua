local AutoTutorial = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MainGui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainGui")

local isRunning = false

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function callRemote(name, ...)
    local remote = Remotes:FindFirstChild(name)
    if remote then
        if remote:IsA("RemoteEvent") then
            return remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        end
    end
end

local function triggerPrompt(keyword)
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local actText = prompt.ActionText:lower()
            local objText = prompt.ObjectText:lower()
            if actText:find(keyword) or objText:find(keyword) then
                if typeof(fireproximityprompt) == "function" then
                    fireproximityprompt(prompt)
                    return true
                end
            end
        end
    end
    return false
end

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

function AutoTutorial.Start()
    if isRunning then return end
    isRunning = true
    print("🚀 [Ritod Hub] Auto Tutorial Started...")

    task.spawn(function()
        pcall(function()
            local HATCH_WAIT = 8
            local hrp = getHRP()
            if not hrp then return end

            local myPlot = workspace.World.Map.Plots:FindFirstChild("1") or workspace.World.Map.Plots:GetChildren()[1]
            local eggShop = workspace.World.Map:FindFirstChild("EggShop")

            -- STEP 1: BELI CAPYBARA EGG PERTAMA
            if eggShop then hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5) end
            task.wait(1)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(8)

            -- STEP 2: TARUH EGG PERTAMA DI LANE
            local purchasedLane = myPlot.TowerArea:FindFirstChild("Purchased4") or myPlot.TowerArea:GetChildren()[1]
            if purchasedLane then
                local targetPart = purchasedLane:FindFirstChild("TowerAreaPart") or purchasedLane:GetChildren()[1]
                if targetPart then hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0)) end
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
            local treeMenuBtn = MainGui.Root.MainButtonsFrame:FindFirstChild("TreeButton")
            if treeMenuBtn and typeof(firesignal) == "function" then
                firesignal(treeMenuBtn.MouseButton1Click)
                firesignal(treeMenuBtn.Activated)
            end
            task.wait(1.5)

            local growBtn = MainGui.Root.Frames.Tree.Grow:FindFirstChild("Button")
            if growBtn and typeof(firesignal) == "function" then
                firesignal(growBtn.MouseButton1Click)
                firesignal(growBtn.Activated)
            end
            task.wait(1.5)

            local yesBtn = MainGui.Root.Frames.Confirm.Yes:FindFirstChild("Button")
            if yesBtn and typeof(firesignal) == "function" then
                firesignal(yesBtn.MouseButton1Click)
                firesignal(yesBtn.Activated)
            end
            task.wait(1)
            callRemote("BuyTreeUpgrade")
            task.wait(7)

            -- STEP 6: BELI POT KEDUA
            local carrotModel = workspace.World.Map.PottedPlants.Server:GetChildren()[1]
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
            local confirmYes = MainGui.Root.Frames.Confirm.Yes:FindFirstChild("Button")
            if confirmYes and typeof(firesignal) == "function" then
                firesignal(confirmYes.MouseButton1Click)
                firesignal(confirmYes.Activated)
            end
            callRemote("BuyItem", "Pot2")
            task.wait(12)

            -- STEP 7: KLAIM SEMUA UANG
            local colMachine = myPlot:FindFirstChild("CollectionMachine") or workspace.World.Map:FindFirstChild("CollectionMachine", true)
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
                if targetPart then hrp.CFrame = CFrame.new(targetPart:GetPivot().Position + Vector3.new(0, 3, 0)) end
            end
            task.wait(1)
            placeEggOnLane()
            task.wait(HATCH_WAIT)

            -- STEP 10: HATCH EGG KEDUA
            triggerPrompt("hatch")
            callRemote("Hatch")
            task.wait(5)

            -- STEP 11: SUMMON BOSS "Scarlet Carrot"
            local summonBtn = MainGui.Root.Frames.BossSummoner.BossInfo.SummonButton:FindFirstChild("Button")
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

        isRunning = false
        print("🏆 [Ritod Hub] AUTO TUTORIAL COMPLETE!")
    end)
end

return AutoTutorial
