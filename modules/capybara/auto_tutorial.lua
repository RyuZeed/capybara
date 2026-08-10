local AutoTutorial = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
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
    end
end

-- =================================================================
-- 🔍 AKURAT & KUAT: DETEKSI PLOT MILIK LOCALPLAYER (PLOT OWNER)
-- =================================================================

local function getPlotsFolder()
    local map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
    if map and map:FindFirstChild("Plots") then
        return map.Plots
    end
    if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots") then
        return workspace.Map.Plots
    end
    return workspace:FindFirstChild("Plots", true)
end

local function isPlotOwnedByPlayer(plot)
    if not plot then return false end

    local myName = LocalPlayer.Name
    local myUserId = LocalPlayer.UserId
    local myDisplayName = LocalPlayer.DisplayName

    -- 1. Cek Attributes pada Plot
    local attrOwner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerId") or plot:GetAttribute("OwnerName") or plot:GetAttribute("Player") or plot:GetAttribute("UserId")
    if attrOwner then
        if attrOwner == myName or attrOwner == myUserId or attrOwner == tostring(myUserId) or attrOwner == myDisplayName then
            return true
        end
    end

    -- 2. Cek ValueBase di dalam Plot
    local ownerVal = plot:FindFirstChild("Owner") or plot:FindFirstChild("Player") or plot:FindFirstChild("OwnerValue") or plot:FindFirstChild("ClaimedBy") or plot:FindFirstChild("OwnerPlayer")
    if ownerVal then
        if ownerVal:IsA("ObjectValue") then
            if ownerVal.Value == LocalPlayer or ownerVal.Value == LocalPlayer.Character then
                return true
            end
        elseif ownerVal:IsA("StringValue") then
            if ownerVal.Value == myName or ownerVal.Value == tostring(myUserId) or ownerVal.Value == myDisplayName then
                return true
            end
        elseif ownerVal:IsA("IntValue") or ownerVal:IsA("NumberValue") then
            if ownerVal.Value == myUserId then
                return true
            end
        end
    end

    -- 3. Cek Nama Folder / Model Plot
    if plot.Name == myName or plot.Name == tostring(myUserId) then
        return true
    end

    -- 4. Cek Papan Nama / Signboard / TextLabel di dalam Plot
    for _, item in ipairs(plot:GetDescendants()) do
        if item:IsA("TextLabel") or item:IsA("SurfaceGui") or item:IsA("BillboardGui") then
            local label = item:IsA("TextLabel") and item or item:FindFirstChildWhichIsA("TextLabel", true)
            if label and label.Text then
                local text = label.Text
                if text == myName or text:find(myName) or (myDisplayName ~= "" and text:find(myDisplayName)) then
                    -- Pastikan bukan tulisan random yang mengandung huruf yang sama
                    if text:lower():find("plot") or text:lower():find("owner") or text:lower():find("garden") or text == myName or text == myDisplayName then
                        return true
                    end
                end
            end
        end
    end

    -- 5. Cek Komponen Khusus (TowerArea / CollectionMachine / Tree) jika ada tanda kepemilikan
    local colMachine = plot:FindFirstChild("CollectionMachine")
    if colMachine then
        local machineOwner = colMachine:GetAttribute("Owner") or colMachine:FindFirstChild("Owner")
        if machineOwner then
            if typeof(machineOwner) == "string" and (machineOwner == myName or machineOwner == tostring(myUserId)) then
                return true
            elseif typeof(machineOwner) == "Instance" and machineOwner:IsA("ValueBase") and (machineOwner.Value == LocalPlayer or machineOwner.Value == myName) then
                return true
            end
        end
    end

    return false
end

local function getMyPlot(maxWaitSec)
    local maxWait = maxWaitSec or 3
    local startTime = tick()

    -- 1. Cek apakah LocalPlayer memiliki attribute/value yang menunjuk ke plot
    local playerPlotAttr = LocalPlayer:GetAttribute("Plot") or LocalPlayer:GetAttribute("PlotId") or LocalPlayer:GetAttribute("ClaimedPlot") or LocalPlayer:GetAttribute("PlotNumber")
    local plots = getPlotsFolder()

    if playerPlotAttr and plots then
        local directPlot = plots:FindFirstChild(tostring(playerPlotAttr))
        if directPlot then
            return directPlot
        end
    end

    local playerPlotVal = LocalPlayer:FindFirstChild("Plot") or LocalPlayer:FindFirstChild("PlotId") or LocalPlayer:FindFirstChild("ClaimedPlot")
    if playerPlotVal and playerPlotVal:IsA("ValueBase") and playerPlotVal.Value then
        if typeof(playerPlotVal.Value) == "Instance" and playerPlotVal.Value:IsA("Model") or playerPlotVal.Value:IsA("Folder") then
            return playerPlotVal.Value
        elseif plots and plots:FindFirstChild(tostring(playerPlotVal.Value)) then
            return plots:FindFirstChild(tostring(playerPlotVal.Value))
        end
    end

    -- 2. Scan folder plots secara berulang hingga data kepemilikan tereplikasi dari server
    while (tick() - startTime) < maxWait do
        plots = getPlotsFolder()
        if plots then
            for _, plot in ipairs(plots:GetChildren()) do
                if isPlotOwnedByPlayer(plot) then
                    return plot
                end
            end
        end
        task.wait(0.2)
    end

    -- 3. Jika scan pemilik belum berhasil (misal solo/single plot), scan sekali lagi tanpa fallback sembarangan
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            if isPlotOwnedByPlayer(plot) then
                return plot
            end
        end

        -- Jika hanya ada 1 plot di dalam server, bisa dipastikan itu milik kita
        local children = plots:GetChildren()
        if #children == 1 then
            return children[1]
        end

        -- Cari plot yang paling dekat dengan karakter saat ini jika sudah berdiri di plot
        local hrp = getHRP()
        if hrp then
            for _, plot in ipairs(children) do
                local pPos = nil
                if plot:IsA("Model") then
                    pPos = plot:GetPivot().Position
                elseif plot:FindFirstChildWhichIsA("BasePart") then
                    pPos = plot:FindFirstChildWhichIsA("BasePart").Position
                end
                if pPos and (hrp.Position - pPos).Magnitude < 40 then
                    return plot
                end
            end
        end

        -- Fallback aman terakhir
        return plots:FindFirstChild("1") or children[1]
    end

    return nil
end

-- =================================================================
-- ⚡ PROXIMITY PROMPT & UI INTERACTION
-- =================================================================

local function triggerSinglePromptInstant(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end

    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 100
        prompt.Enabled = true
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

    return true
end

local function triggerPrompt(keyword, targetContainer)
    local container = targetContainer or getMyPlot()
    if not container then
        container = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") or workspace
    end

    local key = (keyword or "all"):lower()
    local triggered = false

    for _, prompt in ipairs(container:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local actText = (prompt.ActionText or ""):lower()
            local objText = (prompt.ObjectText or ""):lower()
            local nameText = (prompt.Name or ""):lower()

            local match = false
            if key == "all" then
                match = true
            elseif actText:find(key) or objText:find(key) or nameText:find(key) then
                match = true
            end

            if match then
                triggerSinglePromptInstant(prompt)
                triggered = true
            end
        end
    end
    return triggered
end

local function clickButton(btn)
    if not btn then return end

    if typeof(firesignal) == "function" then
        if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
        if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
        if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
    end

    if typeof(getconnections) == "function" then
        for _, eventName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "TouchTap"}) do
            pcall(function()
                if btn[eventName] then
                    for _, conn in ipairs(getconnections(btn[eventName])) do
                        if conn.Fire then
                            pcall(function() conn:Fire() end)
                        elseif conn.Function then
                            pcall(function() conn.Function() end)
                        end
                    end
                end
            end)
        end
    end

    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = math.floor(pos.X + size.X / 2)
        local cy = math.floor(pos.Y + size.Y / 2)

        if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
            pcall(function()
                VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.04)
                VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
            end)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.04)
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
        end
    end)

    pcall(function()
        VirtualUser:CaptureController()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        VirtualUser:ClickButton1(Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2))
    end)
end

-- =================================================================
-- 🥚 PLACE EGG ON LANE (PERSISI SESUAI SPESIFIKASI & TASK.WAIT)
-- =================================================================

local function placeEggOnLane()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = getHRP()
    if not hrp then return end

    local backpack = LocalPlayer:WaitForChild("Backpack", 5) or LocalPlayer:FindFirstChild("Backpack")
    local camera = workspace.CurrentCamera

    if backpack then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                t.Parent = backpack
            end
        end
    end
    task.wait(0.5)

    local eggTool = nil
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:lower():find("egg") or tool.Name:lower():find("capybara")) then
                eggTool = tool
                break
            end
        end
    end

    if eggTool then
        eggTool.Parent = char
        pcall(function() eggTool:Activate() end)
    else
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
        end)
    end
    task.wait(1)

    if camera and hrp then
        local targetLook = hrp.Position + (hrp.CFrame.LookVector * 4) - Vector3.new(0, 2, 0)
        camera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 4, 0), targetLook)
    end
    task.wait(0.3)

    local viewSize = (camera and camera.ViewportSize) or Vector2.new(800, 600)
    local centerX = math.floor(viewSize.X / 2)
    local centerY = math.floor(viewSize.Y / 2)

    if typeof(mousemoveabs) == "function" then
        pcall(function() mousemoveabs(centerX, centerY) end)
    end
    task.wait(0.1)

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
        task.wait(0.08)
        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
    end)

    if typeof(mouse1press) == "function" and typeof(mouse1release) == "function" then
        pcall(function()
            mouse1press()
            task.wait(0.08)
            mouse1release()
        end)
    end

    -- Tambahan Touch & Click Fallback untuk Mobile / Executor lainnya
    pcall(function()
        if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
            VirtualInputManager:SendTouchEvent(1, 0, centerX, centerY)
            task.wait(0.04)
            VirtualInputManager:SendTouchEvent(1, 2, centerX, centerY)
        end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton1(Vector2.new(centerX, centerY))
    end)
end

-- =================================================================
-- 🚀 RUN AUTO TUTORIAL (STEP 1 - 12 LENGKAP & STABIL)
-- =================================================================

local function runAutoTutorial()
    if isRunning or _G.AutoTutorialRunning then return end
    isRunning = true
    _G.AutoTutorialRunning = true
    print("🚀 [Ritod Hub] Auto Tutorial Started...")

    task.spawn(function()
        pcall(function()
            local HATCH_WAIT = 8
            local hrp = getHRP()
            if not hrp then
                warn("⚠️ [Ritod Hub] Gagal mendapatkan HumanoidRootPart!")
                return
            end

            -- DETEKSI PLOT MILIK SENDIRI SECARA AKURAT
            local myPlot = getMyPlot(4)
            if myPlot then
                print("🏡 [Ritod Hub] Plot Terdeteksi: " .. tostring(myPlot.Name))
            else
                warn("⚠️ [Ritod Hub] Tidak dapat menemukan plot milik sendiri, mencari fallback...")
                local plots = getPlotsFolder()
                myPlot = plots and (plots:FindFirstChild("1") or plots:GetChildren()[1])
            end

            local map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") or workspace:FindFirstChild("Map") or workspace
            local eggShop = map:FindFirstChild("EggShop") or workspace:FindFirstChild("EggShop", true)
            local MainGui = getMainGui()

            -- STEP 1: BELI CAPYBARA EGG PERTAMA
            print("📦 [Step 1/12] Membeli Capybara Egg Pertama...")
            if eggShop then
                hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5)
            end
            task.wait(1)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(8)

            -- STEP 2: TARUH EGG PERTAMA DI LANE
            print("🥚 [Step 2/12] Menaruh Egg Pertama di Lane Plot...")
            myPlot = myPlot or getMyPlot(2)
            local towerArea = myPlot and (myPlot:FindFirstChild("TowerArea") or myPlot:FindFirstChild("TowerArea", true))
            local purchasedLane = towerArea and (towerArea:FindFirstChild("Purchased4") or towerArea:FindFirstChild("Purchased1") or towerArea:GetChildren()[1])
            if purchasedLane then
                local targetPart = purchasedLane:FindFirstChild("TowerAreaPart") or purchasedLane:FindFirstChildWhichIsA("BasePart") or purchasedLane:GetChildren()[1]
                if targetPart and targetPart:IsA("BasePart") then
                    hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0))
                elseif targetPart and targetPart:IsA("Model") then
                    hrp.CFrame = CFrame.new(targetPart:GetPivot().Position + Vector3.new(0, 3, 0))
                end
            end
            task.wait(1)
            placeEggOnLane()
            task.wait(HATCH_WAIT)

            -- STEP 3: HATCH EGG PERTAMA
            print("🐣 [Step 3/12] Hatching Egg Pertama...")
            triggerPrompt("hatch", myPlot)
            callRemote("Hatch")
            callRemote("HatchEgg")
            task.wait(15)

            -- STEP 4: PASANG CARROT VIA EQUIP BEST PLANTS
            print("🥕 [Step 4/12] Memasang Tanaman (Equip Best Plants)...")
            callRemote("EquipBestPlants")
            task.wait(7)

            -- STEP 5: GROW TREE (REBIRTH)
            print("🌳 [Step 5/12] Upgrade / Grow Tree...")
            MainGui = MainGui or getMainGui()
            if MainGui and MainGui:FindFirstChild("Root") then
                local root = MainGui.Root
                local mainBtns = root:FindFirstChild("MainButtonsFrame")
                local treeMenuBtn = mainBtns and (mainBtns:FindFirstChild("TreeButton") or mainBtns:FindFirstChild("Tree"))
                if treeMenuBtn then
                    if typeof(firesignal) == "function" then
                        pcall(function() firesignal(treeMenuBtn.MouseButton1Click) end)
                        pcall(function() firesignal(treeMenuBtn.Activated) end)
                    end
                    clickButton(treeMenuBtn)
                end
            end
            task.wait(1.5)

            if MainGui and MainGui:FindFirstChild("Root") and MainGui.Root:FindFirstChild("Frames") then
                local treeFrame = MainGui.Root.Frames:FindFirstChild("Tree")
                local growBtn = treeFrame and treeFrame:FindFirstChild("Grow") and treeFrame.Grow:FindFirstChild("Button")
                if growBtn then
                    if typeof(firesignal) == "function" then
                        pcall(function() firesignal(growBtn.MouseButton1Click) end)
                        pcall(function() firesignal(growBtn.Activated) end)
                    end
                    clickButton(growBtn)
                end
            end
            task.wait(1.5)

            if MainGui and MainGui:FindFirstChild("Root") and MainGui.Root:FindFirstChild("Frames") then
                local confirmFrame = MainGui.Root.Frames:FindFirstChild("Confirm")
                local yesBtn = confirmFrame and confirmFrame:FindFirstChild("Yes") and confirmFrame.Yes:FindFirstChild("Button")
                if yesBtn then
                    if typeof(firesignal) == "function" then
                        pcall(function() firesignal(yesBtn.MouseButton1Click) end)
                        pcall(function() firesignal(yesBtn.Activated) end)
                    end
                    clickButton(yesBtn)
                end
            end
            task.wait(1)
            callRemote("BuyTreeUpgrade")
            callRemote("UpgradeTree")
            callRemote("GrowTree")
            task.wait(7)

            -- STEP 6: BELI POT KEDUA
            print("🪴 [Step 6/12] Membeli Pot Kedua...")
            local pottedPlants = (map:FindFirstChild("PottedPlants")) or workspace:FindFirstChild("PottedPlants", true)
            local serverFolder = pottedPlants and (pottedPlants:FindFirstChild("Server") or pottedPlants)
            local carrotModel = serverFolder and serverFolder:GetChildren()[1]

            if carrotModel then
                local carrotPos = carrotModel:GetPivot().Position
                hrp.CFrame = CFrame.new(carrotPos + Vector3.new(5, 2, 0))
                task.wait(1)
                for _, part in ipairs(map:GetDescendants()) do
                    if part:IsA("BasePart") and (part.Position - carrotPos).Magnitude <= 15 then
                        if typeof(firetouchinterest) == "function" then
                            pcall(function()
                                firetouchinterest(hrp, part, 0)
                                task.wait(0.1)
                                firetouchinterest(hrp, part, 1)
                            end)
                        end
                    end
                end
            end
            task.wait(1)

            if MainGui and MainGui:FindFirstChild("Root") and MainGui.Root:FindFirstChild("Frames") then
                local confirmFrame = MainGui.Root.Frames:FindFirstChild("Confirm")
                local confirmYes = confirmFrame and confirmFrame:FindFirstChild("Yes") and confirmFrame.Yes:FindFirstChild("Button")
                if confirmYes then
                    if typeof(firesignal) == "function" then
                        pcall(function() firesignal(confirmYes.MouseButton1Click) end)
                        pcall(function() firesignal(confirmYes.Activated) end)
                    end
                    clickButton(confirmYes)
                end
            end
            callRemote("BuyItem", "Pot2")
            callRemote("BuyPot", 2)
            task.wait(12)

            -- STEP 7: KLAIM SEMUA UANG
            print("💰 [Step 7/12] Mengklaim Uang dari Collection Machine...")
            myPlot = myPlot or getMyPlot(2)
            local colMachine = (myPlot and myPlot:FindFirstChild("CollectionMachine"))
                or (map and map:FindFirstChild("CollectionMachine", true))
                or workspace:FindFirstChild("CollectionMachine", true)

            if colMachine then
                hrp.CFrame = CFrame.new(colMachine:GetPivot().Position + Vector3.new(0, 2, 3))
                task.wait(1)
                triggerPrompt("collect", colMachine)
            end
            callRemote("CollectMoneyFromPlant")
            callRemote("CollectMoney")
            task.wait(7)

            -- STEP 8: BELI EGG KEDUA
            print("📦 [Step 8/12] Membeli Capybara Egg Kedua...")
            if eggShop then
                hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5)
            end
            task.wait(1)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(7)

            -- STEP 9: TARUH EGG KEDUA DI LANE
            print("🥚 [Step 9/12] Menaruh Egg Kedua di Lane...")
            myPlot = myPlot or getMyPlot(2)
            towerArea = myPlot and (myPlot:FindFirstChild("TowerArea") or myPlot:FindFirstChild("TowerArea", true))
            purchasedLane = towerArea and (towerArea:FindFirstChild("Purchased4") or towerArea:FindFirstChild("Purchased1") or towerArea:GetChildren()[1])
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
            print("🐣 [Step 10/12] Hatching Egg Kedua...")
            triggerPrompt("hatch", myPlot)
            callRemote("Hatch")
            callRemote("HatchEgg")
            task.wait(5)

            -- STEP 11: SUMMON BOSS "Scarlet Carrot"
            print("⚔️ [Step 11/12] Memanggil Boss Scarlet Carrot...")
            MainGui = MainGui or getMainGui()
            if MainGui and MainGui:FindFirstChild("Root") and MainGui.Root:FindFirstChild("Frames") then
                local bossFrame = MainGui.Root.Frames:FindFirstChild("BossSummoner")
                local bossInfo = bossFrame and bossFrame:FindFirstChild("BossInfo")
                local summonBtn = bossInfo and bossInfo:FindFirstChild("SummonButton") and bossInfo.SummonButton:FindFirstChild("Button")
                if summonBtn then
                    if typeof(firesignal) == "function" then
                        pcall(function() firesignal(summonBtn.MouseButton1Click) end)
                        pcall(function() firesignal(summonBtn.Activated) end)
                    end
                    clickButton(summonBtn)
                end
            end
            callRemote("SummonBoss", "Scarlet Carrot")
            task.wait(30)

            -- STEP 12: LANGSUNG EQUIP BEST PLANTS
            print("🏆 [Step 12/12] Finalisasi Tutorial...")
            callRemote("EquipBestPlants")
            task.wait(5)
            callRemote("SaveTutorialStage", 99)
            callRemote("RequestTutorialCompleted")
            print("🏆 [Ritod Hub] AUTO TUTORIAL COMPLETE!")
        end)

        isRunning = false
        _G.AutoTutorialRunning = false
    end)
end

-- =================================================================
-- 📦 EXPORT MODULE
-- =================================================================

function AutoTutorial.Start()
    runAutoTutorial()
end

function AutoTutorial.Stop()
    isRunning = false
    _G.AutoTutorialRunning = false
    print("🛑 [Ritod Hub] Auto Tutorial Dihentikan.")
end

-- Menjalankan langsung jika script di-execute standalone
if not ... or type(...) ~= "table" then
    -- Optional standalone fallback
end

return AutoTutorial
