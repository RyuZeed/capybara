local AutoTutorial = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local isRunning = false

-- =================================================================
-- 🛠️ HELPER FUNCTIONS (MOBILE & PC COMPATIBLE)
-- =================================================================

local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getChar()
    return char:WaitForChild("HumanoidRootPart", 10) or char:FindFirstChild("HumanoidRootPart")
end

local function getMainGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
    if not pg then return nil end
    return pg:FindFirstChild("MainGui") or pg:WaitForChild("MainGui", 5) or pg:FindFirstChildWhichIsA("ScreenGui")
end

local function getRemotes()
    return ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
end

local function callRemote(name, ...)
    local remotes = getRemotes()
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
    else
        warn("⚠️ [Ritod Hub] Remote tidak ditemukan: " .. tostring(name))
    end
end

-- Universal Button Clicker (Mendukung Mobile Delta/Codex/Arceus & PC)
local function clickButton(btn)
    if not btn then return end

    -- 1. firesignal (Mobile/PC Executor)
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.Activated) end)
    end

    -- 2. getconnections (Delta, Codex, Arceus X, Solara, etc.)
    if typeof(getconnections) == "function" then
        for _, eventName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "TouchTap"}) do
            pcall(function()
                if btn[eventName] then
                    for _, conn in ipairs(getconnections(btn[eventName])) do
                        if conn.Function then
                            conn.Function()
                        elseif conn.Fire then
                            conn:Fire()
                        end
                    end
                end
            end)
        end
    end

    -- 3. VirtualInputManager Touch/Mouse Simulation
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = math.floor(pos.X + size.X / 2)
        local cy = math.floor(pos.Y + size.Y / 2)

        if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
            -- Touch Simulation (Khusus Mobile)
            pcall(function()
                VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.02)
                VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
            end)
            -- Mouse Simulation (Khusus PC)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
        end
    end)

    -- 4. VirtualUser Fallback
    pcall(function()
        VirtualUser:CaptureController()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        VirtualUser:ClickButton1(Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2))
    end)
end

-- Universal ProximityPrompt Trigger (Mobile & PC)
local function triggerPrompt(keyword)
    local hrp = getHRP()
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local actText = (prompt.ActionText or ""):lower()
            local objText = (prompt.ObjectText or ""):lower()
            local nameText = (prompt.Name or ""):lower()

            if actText:find(keyword) or objText:find(keyword) or nameText:find(keyword) or keyword == "all" then
                local parentPart = prompt:FindFirstAncestorWhichIsA("BasePart") or prompt.Parent
                if hrp and parentPart and parentPart:IsA("BasePart") then
                    pcall(function()
                        hrp.CFrame = parentPart.CFrame * CFrame.new(0, 2, 2)
                    end)
                    task.wait(0.2)
                end

                -- Method 1: fireproximityprompt
                if typeof(fireproximityprompt) == "function" then
                    pcall(function() fireproximityprompt(prompt) end)
                end

                -- Method 2: InputHoldBegin / End (Universal Fallback)
                pcall(function()
                    local oldDur = prompt.HoldDuration
                    prompt.HoldDuration = 0
                    prompt:InputHoldBegin()
                    task.wait(0.05)
                    prompt:InputHoldEnd()
                    prompt.HoldDuration = oldDur
                end)

                return true
            end
        end
    end
    return false
end

-- Mencari Plot Milik Player Secara Dinamis
local function getMyPlot()
    local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("Plots")
    if not plots then
        plots = workspace:FindFirstChild("Plots", true)
    end
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local owner = plot:FindFirstChild("Owner") or plot:FindFirstChild("Player") or plot:FindFirstChild("OwnerValue")
            if owner then
                if (owner:IsA("ValueBase") and (owner.Value == LocalPlayer or owner.Value == LocalPlayer.Name or owner.Value == tostring(LocalPlayer.UserId))) then
                    return plot
                end
            end
            if plot:GetAttribute("Owner") == LocalPlayer.Name or plot:GetAttribute("Owner") == LocalPlayer.UserId or plot:GetAttribute("OwnerId") == LocalPlayer.UserId then
                return plot
            end
            if plot.Name == LocalPlayer.Name or plot.Name == tostring(LocalPlayer.UserId) then
                return plot
            end
        end
        return plots:FindFirstChild("1") or plots:GetChildren()[1]
    end
    return nil
end

local function getEggShop()
    local map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
    if map and map:FindFirstChild("EggShop") then
        return map.EggShop
    end
    return workspace:FindFirstChild("EggShop", true)
end

-- Mencari Tool Egg / Capybara di Backpack / Character
local function findEggTool()
    local char = getChar()
    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)

    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and (t.Name:lower():find("egg") or t.Name:lower():find("capybara") or t.Name:lower():find("plant")) then
                return t
            end
        end
    end

    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") and (t.Name:lower():find("egg") or t.Name:lower():find("capybara") or t.Name:lower():find("plant")) then
                return t
            end
        end
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") then return t end
        end
    end
    return nil
end

-- Universal Place Egg On Lane (Mendukung Mobile & PC)
local function placeEggOnLane(targetPosition)
    local char = getChar()
    local hrp = getHRP()
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp then return end

    if targetPosition then
        hrp.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
        task.wait(0.3)
    end

    local eggTool = findEggTool()
    if eggTool then
        if humanoid then
            humanoid:EquipTool(eggTool)
        else
            eggTool.Parent = char
        end
        task.wait(0.5)
    end

    local camera = workspace.CurrentCamera
    if camera and hrp then
        local targetLook = hrp.Position + (hrp.CFrame.LookVector * 4) - Vector3.new(0, 2, 0)
        camera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 4, 0), targetLook)
    end
    task.wait(0.2)

    local viewSize = camera and camera.ViewportSize or Vector2.new(800, 600)
    local centerX = math.floor(viewSize.X / 2)
    local centerY = math.floor(viewSize.Y / 2)

    for _ = 1, 3 do
        local activeTool = char:FindFirstChildOfClass("Tool")
        if activeTool then
            pcall(function() activeTool:Activate() end)
        end

        -- Mobile Touch
        pcall(function()
            VirtualInputManager:SendTouchEvent(1, 0, centerX, centerY)
            task.wait(0.05)
            VirtualInputManager:SendTouchEvent(1, 2, centerX, centerY)
        end)

        -- PC Click
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
        end)

        -- VirtualUser Click
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(centerX, centerY))
        end)

        if typeof(mousemoveabs) == "function" then pcall(function() mousemoveabs(centerX, centerY) end) end
        if typeof(mouse1click) == "function" then pcall(mouse1click) end
        if typeof(mouse1press) == "function" then
            pcall(function()
                mouse1press()
                task.wait(0.05)
                mouse1release()
            end)
        end

        task.wait(0.2)
    end
end

-- =================================================================
-- 🚀 AUTO TUTORIAL MAIN SEQUENCE (12 STEPS)
-- =================================================================

function AutoTutorial.Start()
    if isRunning then
        print("ℹ️ [Ritod Hub] Auto Tutorial sedang berjalan...")
        return
    end
    isRunning = true
    print("🚀 [Ritod Hub] Auto Tutorial Dimulai (Mobile & PC Ready)...")

    task.spawn(function()
        pcall(function()
            local HATCH_WAIT = 8
            local hrp = getHRP()
            if not hrp then
                warn("⚠️ [Ritod Hub] Gagal mendapatkan HumanoidRootPart.")
                isRunning = false
                return
            end

            local myPlot = getMyPlot()
            local eggShop = getEggShop()
            local mainGui = getMainGui()

            -- STEP 1: BELI CAPYBARA EGG PERTAMA
            print("📦 [Step 1/12] Membeli Capybara Egg Pertama...")
            if eggShop then
                hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5)
            end
            task.wait(1)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(6)

            -- STEP 2: TARUH EGG PERTAMA DI LANE
            print("🥚 [Step 2/12] Menaruh Egg Pertama di Lane...")
            myPlot = myPlot or getMyPlot()
            local towerArea = myPlot and (myPlot:FindFirstChild("TowerArea") or myPlot:FindFirstChild("TowerArea", true))
            local purchasedLane = towerArea and (towerArea:FindFirstChild("Purchased4") or towerArea:GetChildren()[1])
            local lanePos = nil
            if purchasedLane then
                local targetPart = purchasedLane:FindFirstChild("TowerAreaPart") or purchasedLane:FindFirstChildWhichIsA("BasePart") or purchasedLane:GetChildren()[1]
                if targetPart and targetPart:IsA("BasePart") then
                    lanePos = targetPart.Position
                elseif targetPart and targetPart:IsA("Model") then
                    lanePos = targetPart:GetPivot().Position
                end
            end
            placeEggOnLane(lanePos)
            task.wait(HATCH_WAIT)

            -- STEP 3: HATCH EGG PERTAMA
            print("🐣 [Step 3/12] Hatching Egg Pertama...")
            triggerPrompt("hatch")
            callRemote("Hatch")
            task.wait(12)

            -- STEP 4: PASANG CARROT VIA EQUIP BEST PLANTS
            print("🥕 [Step 4/12] Memasang Tanaman Terbaik...")
            callRemote("EquipBestPlants")
            task.wait(5)

            -- STEP 5: GROW TREE (REBIRTH)
            print("🌳 [Step 5/12] Upgrade Tree (Rebirth)...")
            mainGui = mainGui or getMainGui()
            if mainGui and mainGui:FindFirstChild("Root") then
                local root = mainGui.Root
                local mainBtns = root:FindFirstChild("MainButtonsFrame")
                local treeMenuBtn = mainBtns and mainBtns:FindFirstChild("TreeButton")
                clickButton(treeMenuBtn)
                task.wait(1.5)

                local frames = root:FindFirstChild("Frames")
                local treeFrame = frames and frames:FindFirstChild("Tree")
                local growBtn = treeFrame and treeFrame:FindFirstChild("Grow") and treeFrame.Grow:FindFirstChild("Button")
                clickButton(growBtn)
                task.wait(1.5)

                local confirmFrame = frames and frames:FindFirstChild("Confirm")
                local yesBtn = confirmFrame and confirmFrame:FindFirstChild("Yes") and confirmFrame.Yes:FindFirstChild("Button")
                clickButton(yesBtn)
            end
            task.wait(1)
            callRemote("BuyTreeUpgrade")
            task.wait(6)

            -- STEP 6: BELI POT KEDUA
            print("🪴 [Step 6/12] Membeli Pot Kedua...")
            local map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
            local carrotModel = map and map:FindFirstChild("PottedPlants") and map.PottedPlants:FindFirstChild("Server") and map.PottedPlants.Server:GetChildren()[1]
            if not carrotModel then
                carrotModel = workspace:FindFirstChild("PottedPlants", true)
            end

            if carrotModel then
                local carrotPos = carrotModel:GetPivot().Position
                hrp.CFrame = CFrame.new(carrotPos + Vector3.new(5, 2, 0))
                task.wait(1)

                local targetParts = (map or workspace):GetDescendants()
                for _, part in ipairs(targetParts) do
                    if part:IsA("BasePart") and (part.Position - carrotPos).Magnitude <= 15 then
                        if typeof(firetouchinterest) == "function" then
                            pcall(function()
                                firetouchinterest(hrp, part, 0)
                                task.wait(0.05)
                                firetouchinterest(hrp, part, 1)
                            end)
                        else
                            -- Mobile Fallback: Sentuh part secara fisik
                            pcall(function()
                                local oldCF = hrp.CFrame
                                hrp.CFrame = part.CFrame
                                task.wait(0.05)
                                hrp.CFrame = oldCF
                            end)
                        end
                    end
                end
            end
            task.wait(1)

            mainGui = mainGui or getMainGui()
            if mainGui and mainGui:FindFirstChild("Root") and mainGui.Root:FindFirstChild("Frames") then
                local confirmFrame = mainGui.Root.Frames:FindFirstChild("Confirm")
                local confirmYes = confirmFrame and confirmFrame:FindFirstChild("Yes") and confirmFrame.Yes:FindFirstChild("Button")
                clickButton(confirmYes)
            end
            callRemote("BuyItem", "Pot2")
            task.wait(10)

            -- STEP 7: KLAIM SEMUA UANG
            print("💰 [Step 7/12] Mengambil Uang dari Collection Machine...")
            myPlot = myPlot or getMyPlot()
            local colMachine = myPlot and (myPlot:FindFirstChild("CollectionMachine") or myPlot:FindFirstChild("CollectionMachine", true))
            if not colMachine then
                colMachine = workspace:FindFirstChild("CollectionMachine", true)
            end

            if colMachine then
                hrp.CFrame = CFrame.new(colMachine:GetPivot().Position + Vector3.new(0, 2, 3))
                task.wait(1)
                triggerPrompt("collect")
            end
            callRemote("CollectMoneyFromPlant")
            task.wait(6)

            -- STEP 8: BELI EGG KEDUA
            print("📦 [Step 8/12] Membeli Capybara Egg Kedua...")
            eggShop = eggShop or getEggShop()
            if eggShop then
                hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5)
            end
            task.wait(1)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(6)

            -- STEP 9: TARUH EGG KEDUA DI LANE
            print("🥚 [Step 9/12] Menaruh Egg Kedua di Lane...")
            myPlot = myPlot or getMyPlot()
            towerArea = myPlot and (myPlot:FindFirstChild("TowerArea") or myPlot:FindFirstChild("TowerArea", true))
            purchasedLane = towerArea and (towerArea:FindFirstChild("Purchased4") or towerArea:GetChildren()[1])
            local lanePos2 = nil
            if purchasedLane then
                local parts = purchasedLane:GetChildren()
                local targetPart = parts[2] or parts[1]
                if targetPart and targetPart:IsA("BasePart") then
                    lanePos2 = targetPart.Position
                elseif targetPart and targetPart:IsA("Model") then
                    lanePos2 = targetPart:GetPivot().Position
                end
            end
            placeEggOnLane(lanePos2)
            task.wait(HATCH_WAIT)

            -- STEP 10: HATCH EGG KEDUA
            print("🐣 [Step 10/12] Hatching Egg Kedua...")
            triggerPrompt("hatch")
            callRemote("Hatch")
            task.wait(6)

            -- STEP 11: SUMMON BOSS "Scarlet Carrot"
            print("⚔️ [Step 11/12] Memanggil Boss Scarlet Carrot...")
            mainGui = mainGui or getMainGui()
            if mainGui and mainGui:FindFirstChild("Root") and mainGui.Root:FindFirstChild("Frames") then
                local frames = mainGui.Root.Frames
                local bossFrame = frames:FindFirstChild("BossSummoner")
                local bossInfo = bossFrame and bossFrame:FindFirstChild("BossInfo")
                local summonBtn = bossInfo and bossInfo:FindFirstChild("SummonButton") and bossInfo.SummonButton:FindFirstChild("Button")
                clickButton(summonBtn)
            end
            callRemote("SummonBoss", "Scarlet Carrot")
            task.wait(25)

            -- STEP 12: EQUIP BEST PLANTS & SELESAI
            print("🏆 [Step 12/12] Menyelesaikan Tutorial Game...")
            callRemote("EquipBestPlants")
            task.wait(4)
            callRemote("SaveTutorialStage", 99)
            callRemote("RequestTutorialCompleted")
            print("🎉 [Ritod Hub] AUTO TUTORIAL SELESAI DENGAN SUKSES!")
        end)

        isRunning = false
    end)
end

function AutoTutorial.Stop()
    isRunning = false
    print("🛑 [Ritod Hub] Auto Tutorial Dihentikan.")
end

return AutoTutorial

