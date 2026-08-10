-- =================================================================
-- 🚀 RITOD HUB - AUTO TUTORIAL TO AUTO DELETE (100% PROVEN WORKING)
-- Game: Capybaras vs Plants
-- =================================================================

task.wait(0.2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
-- Safely obtain MainGui with timeout handling
local function getMainGui()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local timeout = 0
    while not playerGui and timeout < 10 do
        task.wait(1)
        timeout = timeout + 1
        playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    end
    if not playerGui then return nil end
    local mainGui = playerGui:FindFirstChild("MainGui")
    timeout = 0
    while not mainGui and timeout < 10 do
        task.wait(1)
        timeout = timeout + 1
        mainGui = playerGui:FindFirstChild("MainGui")
    end
    return mainGui
end
local MainGui = getMainGui()  -- may be nil initially, will be waited for later

_G.AutoTutorialRunning = false

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function callRemote(name, ...)
    if not Remotes then return nil end
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
    keyword = keyword:lower()
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local actText = (prompt.ActionText or ""):lower()
            local objText = (prompt.ObjectText or ""):lower()
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

-- Trigger nearby prompts BUT only those matching a keyword (to avoid opening shop UI, etc.)
local function triggerNearbyKeywordPrompts(pos, maxDist, keyword)
    maxDist = maxDist or 15
    keyword = keyword and keyword:lower() or nil
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local parentPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
            if parentPart and (parentPart.Position - pos).Magnitude <= maxDist then
                if keyword then
                    local actText = (prompt.ActionText or ""):lower()
                    local objText = (prompt.ObjectText or ""):lower()
                    if actText:find(keyword) or objText:find(keyword) then
                        if typeof(fireproximityprompt) == "function" then
                            fireproximityprompt(prompt)
                        end
                    end
                else
                    if typeof(fireproximityprompt) == "function" then
                        fireproximityprompt(prompt)
                    end
                end
            end
        end
    end
end

local function clickButton(btn)
    if not btn then return end
    if typeof(firesignal) == "function" then
        if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
        if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
        if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
    end
    if typeof(getconnections) == "function" then
        for _, ev in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down"}) do
            pcall(function()
                for _, conn in ipairs(getconnections(btn[ev])) do
                    if conn.Function then conn.Function() elseif conn.Fire then conn:Fire() end
                end
            end)
        end
    end
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = math.floor(pos.X + size.X / 2)
        local cy = math.floor(pos.Y + size.Y / 2)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

-- =================================================================
-- 🥚 PLACE EGG ON LANE ENGINE
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
-- 🚀 AUTO TUTORIAL MAIN ENGINE (STEPS 1 - 12)
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

            -- Cari plot milik sendiri: cek attribute Owner/UserId/PlayerId terlebih dahulu
            local myPlot = nil
            do
                local plots = workspace.World.Map:FindFirstChild("Plots")
                if plots then
                    local myUserId = tostring(LocalPlayer.UserId)
                    local myName = LocalPlayer.Name:lower()

                    -- 1st priority: cek attribute langsung
                    for _, plot in ipairs(plots:GetChildren()) do
                        for _, attrName in ipairs({"Owner", "UserId", "PlayerId", "OwnerId", "Player"}) do
                            local val = plot:GetAttribute(attrName)
                            if val then
                                local s = tostring(val):lower()
                                if s == myUserId or s == myName then
                                    myPlot = plot
                                    break
                                end
                            end
                        end
                        if myPlot then break end
                    end

                    -- 2nd priority: cek Value object di dalam plot
                    if not myPlot then
                        for _, plot in ipairs(plots:GetChildren()) do
                            for _, child in ipairs(plot:GetChildren()) do
                                if child:IsA("ValueBase") then
                                    local v = child.Value
                                    if tostring(v):lower() == myUserId or tostring(v):lower() == myName or v == LocalPlayer then
                                        myPlot = plot
                                        break
                                    end
                                end
                            end
                            if myPlot then break end
                        end
                    end

                    -- 3rd priority: cek TextLabel di dalam plot
                    if not myPlot then
                        for _, plot in ipairs(plots:GetChildren()) do
                            for _, desc in ipairs(plot:GetDescendants()) do
                                if desc:IsA("TextLabel") then
                                    local t = desc.Text:lower()
                                    if t:find(myName, 1, true) then
                                        myPlot = plot
                                        break
                                    end
                                end
                            end
                            if myPlot then break end
                        end
                    end

                    -- 4th priority fallback: proximity HRP
                    if not myPlot then
                        print("⚠️ [Ritod Hub] Attribute tidak ditemukan, fallback ke proximity...")
                        local myPos = hrp.Position
                        local minDist = math.huge
                        for _, plot in ipairs(plots:GetChildren()) do
                            local ok, pivot = pcall(function() return plot:GetPivot() end)
                            if ok then
                                local dist = (pivot.Position - myPos).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    myPlot = plot
                                end
                            end
                        end
                        print("🏡 [Ritod Hub] Fallback plot: " .. tostring(myPlot and myPlot.Name) .. " (jarak: " .. math.floor(minDist) .. ")")
                    else
                        print("🏡 [Ritod Hub] Plot sendiri (attribute): " .. tostring(myPlot.Name))
                    end
                end
            end
            if not myPlot then
                print("⚠️ [Ritod Hub] Plot tidak ditemukan! Script berhenti.")
                return
            end
            -- Cari eggShop dengan beberapa kemungkinan path
            local eggShop = workspace.World.Map:FindFirstChild("EggShop")
                or workspace.World.Map:FindFirstChild("Shop")
                or workspace:FindFirstChild("EggShop", true)
                or workspace:FindFirstChild("Shop", true)
            print("🏪 [Ritod Hub] EggShop: " .. tostring(eggShop and eggShop.Name or "NOT FOUND!"))

            -- =================================================================
            -- 🔍 CEK STATUS TUTORIAL: Deteksi akun apakah sudah selesai tutorial
            -- =================================================================
            local isCompleted = false

            if LocalPlayer:GetAttribute("TutorialCompleted") == true or LocalPlayer:GetAttribute("TutorialDone") == true then
                isCompleted = true
            end
            local tStage = LocalPlayer:GetAttribute("TutorialStage") or LocalPlayer:GetAttribute("TutorialStep")
            if tStage and typeof(tStage) == "number" and (tStage >= 12 or tStage == 99) then
                isCompleted = true
            end

            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            local mainGui = playerGui and playerGui:FindFirstChild("MainGui")
            if mainGui then
                local tutFrame = mainGui:FindFirstChild("Tutorial", true) or (mainGui:FindFirstChild("Root") and mainGui.Root:FindFirstChild("Tutorial", true))
                if tutFrame and tutFrame:IsA("GuiObject") and tutFrame.Visible == false then
                    isCompleted = true
                end
            end

            if myPlot then
                local potted = myPlot:FindFirstChild("PottedPlants") or myPlot:FindFirstChild("Pots")
                if potted and (potted:FindFirstChild("2") or potted:FindFirstChild("Pot2")) then
                    local pot2 = potted:FindFirstChild("2") or potted:FindFirstChild("Pot2")
                    if pot2 and (pot2:FindFirstChild("Plant") or pot2:FindFirstChild("Soil") or pot2:GetAttribute("Unlocked") == true) then
                        isCompleted = true
                    end
                end
            end

            if isCompleted then
                print("✅ [Ritod Hub] Akun owner SUDAH SELESAI tutorial! Auto Tutorial dilewati (SKIP).")
                _G.AutoTutorialRunning = false
                return
            end

            print("🚀 [Ritod Hub] Akun owner BELUM selesai tutorial. Melanjutkan Step 1 - 12...")

            -- STEP 1: BELI CAPYBARA EGG PERTAMA
            print("📍 [Step 1] Pergi ke EggShop & Beli Egg 1...")
            if eggShop then hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5) end
            task.wait(1.5)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(10)

            -- STEP 2: TARUH EGG PERTAMA DI LANE (PAKSA DI PLOT SENDIRI)
            print("📍 [Step 2] Menaruh Egg 1 di Lane plot sendiri: " .. myPlot.Name)
            -- Pastikan HRP kembali ke tengah plot sendiri dulu
            local plotCenter = myPlot:GetPivot().Position
            hrp.CFrame = CFrame.new(plotCenter + Vector3.new(0, 5, 0))
            task.wait(0.5)

            local towerArea = myPlot:FindFirstChild("TowerArea")
            local purchasedLane = nil
            if towerArea then
                purchasedLane = towerArea:FindFirstChild("Purchased4")
                    or towerArea:FindFirstChild("Lane1")
                    or towerArea:GetChildren()[1]
            end
            local targetPart = nil
            if purchasedLane then
                targetPart = purchasedLane:FindFirstChild("TowerAreaPart")
                    or purchasedLane:FindFirstChildWhichIsA("BasePart")
                    or purchasedLane:GetChildren()[1]
                if targetPart then
                    -- Teleport ke lane DI PLOT SENDIRI
                    hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0))
                    print("✅ [Step 2] Berhasil ke lane: " .. tostring(targetPart.Name) .. " di " .. myPlot.Name)
                end
            else
                print("⚠️ [Step 2] TowerArea tidak ditemukan di " .. myPlot.Name .. ", stay di tengah plot.")
            end
            task.wait(1)
            placeEggOnLane()
            task.wait(HATCH_WAIT)

            -- STEP 3: HATCH EGG PERTAMA (HANYA DI AREA LANE SENDIRI)
            print("📍 [Step 3] Hatch Egg 1...")
            if targetPart then
                hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 2, 0))
                task.wait(0.3)
                -- HANYA trigger keyword 'hatch' di sekitar lane (bukan global search)
                triggerNearbyKeywordPrompts(targetPart.Position, 12, "hatch")
            end
            -- Jangan pakai triggerPrompt('egg') karena akan trigger EggShop juga!
            callRemote("Hatch")
            task.wait(15)

            -- STEP 4: PASANG CARROT VIA EQUIP BEST PLANTS
            print("📍 [Step 4] EquipBestPlants...")
            callRemote("EquipBestPlants")
            task.wait(7)

            -- STEP 5: GROW TREE (REBIRTH)
            print("📍 [Step 5] Grow Tree...")
            local treeMenuBtn = MainGui.Root.MainButtonsFrame:FindFirstChild("TreeButton")
            if treeMenuBtn then clickButton(treeMenuBtn) end
            task.wait(1.5)

            local growBtn = MainGui.Root.Frames.Tree.Grow:FindFirstChild("Button")
            if growBtn then clickButton(growBtn) end
            task.wait(1.5)

            local yesBtn = MainGui.Root.Frames.Confirm.Yes:FindFirstChild("Button")
            if yesBtn then clickButton(yesBtn) end
            task.wait(1)
            callRemote("BuyTreeUpgrade")
            task.wait(7)

            -- STEP 6: BELI POT KEDUA (CARI POTTED PLANT DI DALAM AREA PLOT SENDIRI)
            print("📍 [Step 6] Cari Carrot & Beli Pot 2...")
            local serverPotted = workspace.World.Map.PottedPlants:FindFirstChild("Server")
            local carrotModel = nil
            if serverPotted and myPlot then
                local plotPos = myPlot:GetPivot().Position
                local minDist = math.huge
                -- Batas jarak maksimal 50 stud dari pusat plot sendiri
                local MAX_CARROT_DIST = 50
                for _, model in ipairs(serverPotted:GetChildren()) do
                    local ok, pivot = pcall(function() return model:GetPivot() end)
                    if ok then
                        local dist = (pivot.Position - plotPos).Magnitude
                        if dist < minDist and dist <= MAX_CARROT_DIST then
                            minDist = dist
                            carrotModel = model
                        end
                    end
                end
                if carrotModel then
                    print("🥕 [Ritod Hub] Carrot ditemukan di plot sendiri: " .. carrotModel.Name .. " (jarak: " .. math.floor(minDist) .. ")")
                else
                    print("⚠️ [Ritod Hub] Carrot tidak ditemukan dalam radius " .. MAX_CARROT_DIST .. " stud dari plot! Teleport ke plot dulu.")
                    -- Teleport ke tengah plot lalu coba cari dengan radius lebih besar
                    hrp.CFrame = CFrame.new(plotPos + Vector3.new(0, 5, 0))
                    task.wait(1)
                    for _, model in ipairs(serverPotted:GetChildren()) do
                        local ok2, pivot2 = pcall(function() return model:GetPivot() end)
                        if ok2 then
                            local dist2 = (pivot2.Position - plotPos).Magnitude
                            if dist2 < minDist then
                                minDist = dist2
                                carrotModel = model
                            end
                        end
                    end
                    print("🥕 [Ritod Hub] Carrot fallback: " .. tostring(carrotModel and carrotModel.Name) .. " (jarak: " .. math.floor(minDist) .. ")")
                end
            end

            if carrotModel then
                local carrotPos = carrotModel:GetPivot().Position
                hrp.CFrame = CFrame.new(carrotPos + Vector3.new(5, 2, 0))
                task.wait(1)
                -- Cari proximity prompt "buy pot" / "pot" di sekitar carrot
                triggerNearbyKeywordPrompts(carrotPos, 15, "pot")
                triggerNearbyKeywordPrompts(carrotPos, 15, "buy")
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
            if confirmYes then clickButton(confirmYes) end
            callRemote("BuyItem", "Pot2")
            task.wait(12)

            -- STEP 7: KLAIM UANG (DEKAT PLANT 1)
            print("📍 [Step 7] Klaim Uang di Plant 1...")
            if carrotModel then
                local carrotPos = carrotModel:GetPivot().Position
                hrp.CFrame = CFrame.new(carrotPos + Vector3.new(0, 2, 2))
                task.wait(1)
                triggerPrompt("collect")
                triggerPrompt("claim")
                -- Hanya trigger prompt collect/claim di sekitar carrot (bukan semua prompt)
                triggerNearbyKeywordPrompts(carrotPos, 15, "collect")
                triggerNearbyKeywordPrompts(carrotPos, 15, "claim")
            end

            local colMachine = myPlot:FindFirstChild("CollectionMachine") or workspace.World.Map:FindFirstChild("CollectionMachine", true)
            if colMachine then
                hrp.CFrame = CFrame.new(colMachine:GetPivot().Position + Vector3.new(0, 2, 3))
                task.wait(1)
                triggerPrompt("collect")
            end
            callRemote("CollectMoneyFromPlant")
            task.wait(7)

            -- STEP 8: BELI EGG KEDUA
            print("📍 [Step 8] Pergi ke EggShop & Beli Egg 2...")
            if eggShop then
                hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5)
            else
                -- Fallback: coba cari ulang eggShop
                eggShop = workspace.World.Map:FindFirstChild("EggShop")
                    or workspace:FindFirstChild("EggShop", true)
                    or workspace:FindFirstChild("Shop", true)
                if eggShop then
                    hrp.CFrame = eggShop:GetPivot() * CFrame.new(0, 2, 5)
                    print("🏪 [Ritod Hub] EggShop ditemukan (fallback): " .. eggShop.Name)
                else
                    print("⚠️ [Ritod Hub] EggShop tidak ditemukan! Coba beli via remote langsung.")
                end
            end
            task.wait(1.5)
            callRemote("BuyItem", "Capybara Egg")
            task.wait(10)

            -- STEP 9: TARUH EGG KEDUA DI LANE (PAKSA DI PLOT SENDIRI)
            print("📍 [Step 9] Menaruh Egg 2 di Lane...")
            local secondPart = nil
            if purchasedLane then
                local parts = purchasedLane:GetChildren()
                -- Coba slot ke-2, fallback ke slot ke-1
                for i = 2, 1, -1 do
                    if parts[i] and (parts[i]:IsA("BasePart") or parts[i]:IsA("Model")) then
                        secondPart = parts[i]
                        break
                    end
                end
                if secondPart then
                    local sPos = secondPart:GetPivot().Position
                    hrp.CFrame = CFrame.new(sPos + Vector3.new(0, 3, 0))
                    print("✅ [Step 9] Berhasil ke lane slot 2: " .. secondPart.Name)
                end
            end
            task.wait(1)
            placeEggOnLane()
            task.wait(HATCH_WAIT)

            -- STEP 10: HATCH EGG KEDUA (HANYA DI AREA LANE SENDIRI)
            print("📍 [Step 10] Hatch Egg 2...")
            if secondPart then
                hrp.CFrame = CFrame.new(secondPart:GetPivot().Position + Vector3.new(0, 2, 0))
                task.wait(0.3)
                -- HANYA trigger keyword 'hatch' di sekitar lane (bukan global search)
                triggerNearbyKeywordPrompts(secondPart:GetPivot().Position, 12, "hatch")
            end
            -- Jangan pakai triggerPrompt('egg') karena akan trigger EggShop juga!
            callRemote("Hatch")
            task.wait(5)

            -- STEP 11: SUMMON BOSS "Scarlet Carrot"
            print("📍 [Step 11] Summon Boss Scarlet Carrot...")
            pcall(function()
                local mainGui = nil
                local attempts = 0
                while attempts < 20 do
                    mainGui = getMainGui()
                    if mainGui then break end
                    task.wait(0.5)
                    attempts = attempts + 1
                end
                if not mainGui then
                    print("⚠️ [Step 11] MainGui not found after waiting, skipping UI summon.")
                else
                    local bossSummonerFrame = mainGui.Root.Frames:FindFirstChild("BossSummoner")
                    local bossInfo = bossSummonerFrame and bossSummonerFrame:FindFirstChild("BossInfo")
                    local summonButton = bossInfo and bossInfo:FindFirstChild("SummonButton")
                    local summonBtn = summonButton and summonButton:FindFirstChild("Button")
                    if summonBtn then
                        clickButton(summonBtn)
                        print("✅ [Step 11] Summon button diklik!")
                    else
                        print("⚠️ [Step 11] Summon button tidak ditemukan, pakai remote langsung.")
                    end
                end
                if Remotes:FindFirstChild("SummonBoss") then
                    Remotes.SummonBoss:FireServer("Scarlet Carrot")
                    print("✅ [Step 11] Remote SummonBoss fired.")
                else
                    print("⚠️ [Step 11] Remote SummonBoss tidak ditemukan.")
                end
            end)
            task.wait(30)

            -- STEP 12: EQUIP BEST PLANTS & SELESAIKAN TUTORIAL
            print("📍 [Step 12] Selesaikan Tutorial...")
            if Remotes:FindFirstChild("EquipBestPlants") then
                Remotes.EquipBestPlants:FireServer()
                print("✅ [Step 12] EquipBestPlants remote fired.")
            else
                print("⚠️ [Step 12] EquipBestPlants remote tidak ditemukan.")
            end
            task.wait(5)
            if Remotes:FindFirstChild("SaveTutorialStage") then
                Remotes.SaveTutorialStage:FireServer(99)
                print("✅ [Step 12] SaveTutorialStage remote fired.")
            else
                print("⚠️ [Step 12] SaveTutorialStage remote tidak ditemukan.")
            end
            if Remotes:FindFirstChild("RequestTutorialCompleted") then
                Remotes.RequestTutorialCompleted:FireServer()
                print("✅ [Step 12] RequestTutorialCompleted remote fired.")
            else
                print("⚠️ [Step 12] RequestTutorialCompleted remote tidak ditemukan.")
            end
            task.wait(3)

            print("🏆 [Ritod Hub] AUTO TUTORIAL COMPLETE!")
        end) -- ← end pcall tutorial steps

        -- ================================================================
        -- 🎯 AUTO CHAIN: SELALU DIJALANKAN, BAHKAN JIKA ADA ERROR DI ATAS
        -- Diletakkan di LUAR pcall utama tutorial supaya pasti jalan!
        -- ================================================================
        task.wait(1)
        print("⚡ [Ritod Hub] Memulai AutoSell 5 Rarity + Bulk Sell...")

        -- 1. Sinkronkan tombol AutoSell di UI game
        local function syncAutoSellButtons(rarities)
            rarities = rarities or {"Common", "Rare", "Epic", "Legendary", "Mythic"}
            pcall(function()
                -- Wait until MainGui is available before proceeding
                local mainGui = nil
                local waitAttempts = 0
                while waitAttempts < 20 do
                    mainGui = getMainGui()
                    if mainGui then break end
                    task.wait(0.5)
                    waitAttempts = waitAttempts + 1
                end
                if not mainGui then
                    print("⚠️ [AutoSell] MainGui still not found after waiting, skipping UI sync.")
                    return
                end
                -- Ensure UI hierarchy is loaded
                local root = mainGui:FindFirstChild("Root") or mainGui:WaitForChild("Root", 5)
                local frames = root and (root:FindFirstChild("Frames") or root:WaitForChild("Frames", 5))
                local autoSellFrame = frames and frames:FindFirstChild("AutoSell")
                local rarityOptions = autoSellFrame and autoSellFrame:FindFirstChild("RarityOptions")

                if rarityOptions then
                    for _, rName in ipairs(rarities) do
                        local rFrame = rarityOptions:FindFirstChild(rName)
                        if rFrame and rFrame:FindFirstChild("Button") then
                            clickButton(rFrame.Button)
                            print("  👉 UI AutoSell klik: " .. rName)
                            task.wait(0.05)
                        end
                    end
                end

                if Remotes:FindFirstChild("ChangeAutosellOptions") then
                    for _, rName in ipairs(rarities) do
                        pcall(function()
                            Remotes.ChangeAutosellOptions:InvokeServer(rName, true)
                            print("  ✅ Remote AutoSell: " .. rName)
                        end)
                    end
                end
            end)
        end

        -- 2. Bulk Sell langsung pakai FireServer
        local function executeBulkSell()
            pcall(function()
                if Remotes:FindFirstChild("EquipBestPlants") then
                    Remotes.EquipBestPlants:FireServer()
                    task.wait(0.08)
                end
                if Remotes:FindFirstChild("Sell") then
                    Remotes.Sell:FireServer("bulkSell", "Plant")
                end
            end)
        end

        -- 3. Jalankan sinkronisasi dan bulk sell selesai tutorial
        syncAutoSellButtons({"Common", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Godly", "Secret"})
        task.wait(0.5)
        executeBulkSell()
        print("🗑️ [Ritod Hub] Tutorial Selesai: Bulk Sell & Auto Delete Diaktifkan!")

        -- Aktifkan engine AutoDelete jika tersedia
        if _G.AutoDeletePlant and _G.AutoDeletePlant.Start then
            _G.AutoDeletePlant.Start()
        end

        -- 4. Loop terus setiap 1.5s
        task.spawn(function()
            while true do
                executeBulkSell()
                task.wait(1.5)
            end
        end)

        _G.AutoTutorialRunning = false
    end) -- ← end task.spawn
end

local function toggleTutorial(state)
    if state == nil then state = not _G.AutoTutorialRunning end
    if state then
        task.spawn(runAutoTutorial)
    else
        _G.AutoTutorialRunning = false
    end
    return _G.AutoTutorialRunning
end

return {
    Start = function() task.spawn(runAutoTutorial) end,
    Stop = function() _G.AutoTutorialRunning = false end,
    Toggle = toggleTutorial,
    runAutoTutorial = runAutoTutorial,
}
