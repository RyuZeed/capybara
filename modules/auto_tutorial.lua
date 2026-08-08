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
        if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
        if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
    end

    -- 2. getconnections (Delta, Codex, Arceus X, Solara, etc.)
    if typeof(getconnections) == "function" then
        for _, eventName in ipairs({"Activated", "MouseButton1Click"}) do
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

-- Helper untuk mendeteksi tombol Negatif (No, Cancel, Close, Batal, Tutup) -> JANGAN DIKLIK
local function isNegativeButton(btn)
    if not btn then return true end
    local name = (btn.Name or ""):lower()
    local pName = (btn.Parent and btn.Parent.Name or ""):lower()
    local text = (btn:IsA("TextButton") and btn.Text or ""):lower()

    if name == "no" or name:find("cancel") or name:find("close") or name:find("decline") or name:find("back") or name == "x" or name == "exit" then
        return true
    end
    if pName == "no" or pName:find("cancel") or pName:find("close") or pName:find("decline") or pName:find("back") or pName == "exit" then
        return true
    end
    if text == "no" or text:find("cancel") or text:find("batal") or text:find("tidak") or text:find("close") or text:find("tutup") or text == "x" or text == "keluar" then
        return true
    end
    return false
end

-- Helper untuk mendeteksi tombol Positif (Yes, Confirm, Accept, Rebirth, Grow, Upgrade, Beli, OK)
local function isPositiveButton(btn)
    if not btn or not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then return false end
    if not btn.Visible then return false end
    if isNegativeButton(btn) then return false end

    local name = (btn.Name or ""):lower()
    local pName = (btn.Parent and btn.Parent.Name or ""):lower()
    local text = (btn:IsA("TextButton") and btn.Text or ""):lower()

    -- 1. Berdasarkan nama tombol atau parent
    if name == "yes" or name:find("confirm") or name:find("accept") or name:find("agree") or name:find("rebirth") or name:find("grow") or name:find("upgrade") or name:find("buy") or name:find("beli") then
        return true
    end
    if pName == "yes" or pName:find("confirm") or pName:find("accept") or pName:find("agree") or pName:find("rebirth") or pName:find("grow") or pName:find("upgrade") then
        return true
    end

    -- 2. Berdasarkan teks pada tombol
    if text == "yes" or text == "ya" or text:find("confirm") or text:find("accept") or text:find("setuju") or text:find("rebirth") or text:find("grow") or text:find("upgrade") or text:find("beli") or text:find("buy") or text == "ok" or text == "oke" then
        return true
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

-- Universal ProximityPrompt Trigger (Aman, terisolasi ke target container agar tidak teleport sembarangan)
local function triggerPrompt(keyword, targetContainer)
    local hrp = getHRP()
    local container = targetContainer or (getMyPlot()) or workspace
    local key = (keyword or "all"):lower()

    for _, prompt in ipairs(container:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local actText = (prompt.ActionText or ""):lower()
            local objText = (prompt.ObjectText or ""):lower()
            local nameText = (prompt.Name or ""):lower()

            local match = false
            if key == "all" then
                -- Hanya izinkan "all" jika container spesifik diberikan (bukan seluruh workspace)
                if targetContainer ~= nil then
                    match = true
                end
            elseif actText:find(key) or objText:find(key) or nameText:find(key) then
                match = true
            end

            if match then
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

-- Universal Confirmation Popup Clicker (Akurat mengklik tombol Yes/Confirm dan mengabaikan No/Cancel/Close)
local function handleConfirmPopup(maxWait)
    local waitTime = maxWait or 5
    local startTime = tick()

    while (tick() - startTime) < waitTime do
        local clicked = false
        pcall(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
            if not playerGui then return end

            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled then
                    for _, obj in ipairs(gui:GetDescendants()) do
                        if obj:IsA("GuiObject") and obj.Visible then
                            local objName = obj.Name:lower()

                            -- 1. Cek frame konfirmasi (Confirm, Prompt, Modal, Popup, Dialog, Rebirth, Alert)
                            if objName:find("confirm") or objName:find("prompt") or objName:find("modal") or objName:find("popup") or objName:find("dialog") or objName:find("alert") or objName:find("rebirth") then
                                for _, child in ipairs(obj:GetDescendants()) do
                                    if isPositiveButton(child) then
                                        print("👉 [Auto Tutorial] Mengonfirmasi popup via tombol: " .. child.Name .. " (Text: " .. tostring(child:IsA("TextButton") and child.Text or "") .. ")")
                                        clickButton(child)
                                        clicked = true
                                        task.wait(0.2)
                                        break
                                    end
                                end
                            end

                            if clicked then break end

                            -- 2. Cek tombol mandiri yang berstatus positif dan terlihat di layar
                            if isPositiveButton(obj) then
                                print("👉 [Auto Tutorial] Mengonfirmasi standalone tombol: " .. obj.Name)
                                clickButton(obj)
                                clicked = true
                                task.wait(0.2)
                                break
                            end
                        end
                    end
                end
                if clicked then break end
            end
        end)

        if clicked then
            task.wait(0.4)
            return true
        end
        task.wait(0.25)
    end
    return false
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
            triggerPrompt("hatch", myPlot)
            callRemote("Hatch")
            task.wait(12)

            -- STEP 4: PASANG CARROT VIA EQUIP BEST PLANTS
            print("🥕 [Step 4/12] Memasang Tanaman Terbaik...")
            callRemote("EquipBestPlants")
            task.wait(5)

            -- STEP 5: GROW TREE (REBIRTH / LEVEL UP)
            print("🌳 [Step 5/12] Upgrade Tree (Rebirth / Level Up)...")
            myPlot = myPlot or getMyPlot()
            mainGui = mainGui or getMainGui()

            -- 1. Cari Tree di plot player jika ada dan dekati
            local treeModel = myPlot and (myPlot:FindFirstChild("Tree") or myPlot:FindFirstChild("WorldTree") or myPlot:FindFirstChild("TreeModel", true))
            if treeModel and treeModel:IsA("Model") then
                pcall(function()
                    hrp.CFrame = treeModel:GetPivot() * CFrame.new(0, 2, 5)
                end)
                task.wait(0.3)
                triggerPrompt("upgrade", treeModel)
                triggerPrompt("grow", treeModel)
                triggerPrompt("tree", treeModel)
                triggerPrompt("rebirth", treeModel)
            end

            -- 2. Buka menu Tree di GUI & Klik Tombol Grow/Upgrade
            if mainGui and mainGui:FindFirstChild("Root") then
                local root = mainGui.Root
                local mainBtns = root:FindFirstChild("MainButtonsFrame")
                local treeMenuBtn = mainBtns and (mainBtns:FindFirstChild("TreeButton") or mainBtns:FindFirstChild("Tree") or mainBtns:FindFirstChild("RebirthButton"))
                if treeMenuBtn then
                    clickButton(treeMenuBtn)
                    task.wait(1.5)
                end

                local frames = root:FindFirstChild("Frames")
                local treeFrame = frames and (frames:FindFirstChild("Tree") or frames:FindFirstChild("TreeUpgrade") or frames:FindFirstChild("Rebirth"))
                if treeFrame then
                    local growBtn = (treeFrame:FindFirstChild("Grow") and treeFrame.Grow:FindFirstChild("Button"))
                        or treeFrame:FindFirstChild("Grow")
                        or treeFrame:FindFirstChild("Upgrade")
                        or (treeFrame:FindFirstChild("Upgrade") and treeFrame.Upgrade:FindFirstChild("Button"))
                        or treeFrame:FindFirstChildWhichIsA("GuiButton", true)
                    if growBtn then
                        clickButton(growBtn)
                        task.wait(1)
                    end
                end

                -- Otomatis konfirmasi Yes Rebirth / Tree Popup
                print("👉 [Step 5/12] Mengonfirmasi Popup Level Up Tree (Klik Yes)...")
                handleConfirmPopup(5)
            end

            task.wait(0.5)
            -- 3. Panggil Remotes Upgrade Tree / Rebirth sebagai Backup
            callRemote("BuyTreeUpgrade")
            callRemote("UpgradeTree")
            callRemote("TreeUpgrade")
            callRemote("Rebirth")
            callRemote("GrowTree")
            callRemote("ConfirmRebirth")
            callRemote("LevelUpTree")
            task.wait(6)

            -- STEP 6: BELI POT KEDUA
            print("🪴 [Step 6/12] Membeli Pot Kedua...")
            myPlot = myPlot or getMyPlot()
            local pot2Model = nil

            -- 1. Cari Pot 2 di plot milik player terlebih dahulu
            if myPlot then
                local pottedPlantsInPlot = myPlot:FindFirstChild("PottedPlants") or myPlot:FindFirstChild("Pots") or myPlot:FindFirstChild("TowerArea")
                if pottedPlantsInPlot then
                    for _, p in ipairs(pottedPlantsInPlot:GetChildren()) do
                        local pName = p.Name:lower()
                        if pName == "2" or pName:find("pot2") or pName:find("second") or pName == "purchased2" or pName == "locked2" then
                            pot2Model = p
                            break
                        end
                    end
                    if not pot2Model then
                        local kids = pottedPlantsInPlot:GetChildren()
                        if #kids >= 2 then
                            pot2Model = kids[2]
                        end
                    end
                end
            end

            -- 2. Jika tidak ada di plot, cari di World/Map
            if not pot2Model then
                local map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
                local pottedPlants = (map and map:FindFirstChild("PottedPlants")) or workspace:FindFirstChild("PottedPlants", true)
                if pottedPlants then
                    local serverFolder = pottedPlants:FindFirstChild("Server") or pottedPlants
                    for _, p in ipairs(serverFolder:GetChildren()) do
                        local pName = p.Name:lower()
                        if pName == "2" or pName:find("pot2") or pName:find("second") then
                            pot2Model = p
                            break
                        end
                    end
                    if not pot2Model then
                        local pots = serverFolder:GetChildren()
                        pot2Model = pots[2] or pots[1]
                    end
                end
            end

            -- 3. Teleport 1 KALI secara presisi ke Pot Kedua (TANPA spam teleport)
            if pot2Model then
                local potPos = nil
                if pot2Model:IsA("Model") then
                    potPos = pot2Model:GetPivot().Position
                elseif pot2Model:IsA("BasePart") then
                    potPos = pot2Model.Position
                else
                    local bp = pot2Model:FindFirstChildWhichIsA("BasePart", true)
                    if bp then potPos = bp.Position end
                end

                if potPos then
                    hrp.CFrame = CFrame.new(potPos + Vector3.new(0, 2, 2.5))
                    task.wait(0.5)
                end

                -- Sentuh Part Utama Pot 2 (hanya 1 part utama, aman)
                local mainPart = (pot2Model:IsA("BasePart") and pot2Model) or pot2Model:FindFirstChildWhichIsA("BasePart") or pot2Model.PrimaryPart
                if mainPart and typeof(firetouchinterest) == "function" then
                    pcall(function()
                        firetouchinterest(hrp, mainPart, 0)
                        task.wait(0.05)
                        firetouchinterest(hrp, mainPart, 1)
                    end)
                end

                -- Picu ProximityPrompt HANYA di dalam pot2Model
                triggerPrompt("pot", pot2Model)
                triggerPrompt("buy", pot2Model)
                triggerPrompt("all", pot2Model)
            end
            task.wait(0.5)

            -- 4. Otomatis Klik YES pada Popup Konfirmasi Pembelian Pot Kedua
            print("👉 Mengonfirmasi Pembelian Pot Kedua (Klik Yes Popup)...")
            handleConfirmPopup(5)

            -- 5. Panggil Remote Pembelian Pot Sebagai Backup
            callRemote("BuyItem", "Pot2")
            callRemote("BuyPot", 2)
            callRemote("BuyPottedPlant", 2)
            callRemote("BuyItem", "Pot 2")
            callRemote("BuyItem", "Potted Plant 2")
            task.wait(8)

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
                triggerPrompt("collect", colMachine)
            end
            callRemote("CollectMoneyFromPlant")
            callRemote("CollectMoney")
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
            triggerPrompt("hatch", myPlot)
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

