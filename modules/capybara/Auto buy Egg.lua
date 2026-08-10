--[[
	===============================================================
	⚡ RITOD HUB - AUTO BUY EGG & IN-GAME EGG SCANNER
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- 🔍 Deep In-Game Egg & Shop Scanner (ReplicatedStorage, Workspace, UI)
	- 📋 Dynamic Egg Catalog Generator (Auto-detects all eggs & prices)
	- 🛒 Pure Fast Auto Buy Egg Engine (Remote, Prompt, Shop UI)
	- 🥚 Optional Auto Place on Lane (Step 2 Engine - Default OFF)
	- 🐣 Optional Auto Hatch (Step 3 Engine - Default OFF)
	- 💾 Exports Discovered Eggs to JSON / Console / Clipboard
	===============================================================
]]

local AutoBuyEgg = {}
_G.AutoBuyEgg = AutoBuyEgg

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- =================================================================
-- 📋 DEFAULT & DISCOVERED EGG CATALOG
-- =================================================================
AutoBuyEgg.DiscoveredEggs = {
    { name = "Capybara Egg", price = "Default", currency = "Coins/Money", source = "Default" },
}

AutoBuyEgg.Config = {
    Enabled       = false,
    SelectedEgg   = "Capybara Egg",
    BuyInterval   = 1.2,     -- Jeda antar pembelian (detik)
    AutoPlace     = false,   -- Default OFF (tidak langsung taruh)
    AutoHatch     = false,   -- Default OFF (tidak langsung hatch)
    HatchWait     = 8,       -- Jeda waktu hatch (jika aktif)
    AutoTeleport  = true,    -- Dekat ke EggShop untuk lolos distance check server
}

local isRunning = false
local loopThread = nil
local totalEggsBought = 0
local totalEggsPlaced = 0
local totalEggsHatched = 0

-- Callback saat scanner menemukan egg baru (untuk refresh GUI secara dinamis)
AutoBuyEgg.OnCatalogUpdated = nil

-- =================================================================
-- 🛠️ HELPER FUNCTIONS
-- =================================================================

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function getMainGui()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    return playerGui:FindFirstChild("MainGui") or playerGui:FindFirstChildWhichIsA("ScreenGui")
end

local function getRemotes()
    return ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Remotes", true)
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
    return nil
end

local function triggerNearbyKeywordPrompts(pos, maxDist, keyword)
    maxDist = maxDist or 15
    keyword = keyword and keyword:lower() or nil
    local count = 0
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
            local parentPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
            if parentPart and (parentPart.Position - pos).Magnitude <= maxDist then
                if keyword then
                    local actText = (prompt.ActionText or ""):lower()
                    local objText = (prompt.ObjectText or ""):lower()
                    if actText:find(keyword, 1, true) or objText:find(keyword, 1, true) then
                        if typeof(fireproximityprompt) == "function" then
                            fireproximityprompt(prompt)
                            count = count + 1
                        end
                    end
                else
                    if typeof(fireproximityprompt) == "function" then
                        fireproximityprompt(prompt)
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

-- =================================================================
-- 🔍 IN-GAME EGG & SHOP SCANNER (DEEP INSPECTOR)
-- =================================================================

function AutoBuyEgg.ScanEggs()
    print("===============================================================")
    print("🔍 [Ritod Hub] MEMULAI SCAN EGG & SHOP IN-GAME...")
    print("===============================================================")

    local eggMap = {}
    local discoveredList = {}

    local function addEgg(name, price, currency, source, extra)
        if not name or type(name) ~= "string" or #name < 2 then return end
        -- Bersihkan spasi berlebih
        name = name:gsub("^%s*(.-)%s*$", "%1")
        local key = name:lower()

        if not eggMap[key] then
            eggMap[key] = {
                name = name,
                price = price or "Unknown",
                currency = currency or "Coins",
                source = source or "Scanner",
                extra = extra or {}
            }
            table.insert(discoveredList, eggMap[key])
            print(string.format("  🥚 Ditemukan Egg: [%s] | Harga: %s %s | Sumber: %s", name, tostring(price), tostring(currency), source))
        end
    end

    -- 1. Scan ReplicatedStorage ModuleScripts (Config, Shop, Catalog, Data)
    pcall(function()
        for _, item in ipairs(ReplicatedStorage:GetDescendants()) do
            if item:IsA("ModuleScript") then
                local n = item.Name:lower()
                if n:find("egg") or n:find("shop") or n:find("catalog") or n:find("item") or n:find("data") or n:find("config") then
                    local ok, modData = pcall(function() return require(item) end)
                    if ok and typeof(modData) == "table" then
                        -- Scan keys & values
                        for k, v in pairs(modData) do
                            local kStr = tostring(k)
                            if kStr:lower():find("egg") then
                                local p = (typeof(v) == "table" and (v.Price or v.Cost or v.price or v.cost)) or "Unknown"
                                local cur = (typeof(v) == "table" and (v.Currency or v.currency)) or "Coins"
                                addEgg(kStr, p, cur, "Module: " .. item.Name)
                            end

                            if typeof(v) == "table" then
                                local itemName = v.Name or v.name or v.Item or v.item or v.Title or v.title or kStr
                                if tostring(itemName):lower():find("egg") then
                                    local p = v.Price or v.Cost or v.price or v.cost or "Unknown"
                                    local cur = v.Currency or v.currency or "Coins"
                                    addEgg(tostring(itemName), p, cur, "Module: " .. item.Name)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    -- 2. Scan Workspace for Egg Models, Stands, & ProximityPrompts
    pcall(function()
        local eggShop = (workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("EggShop"))
            or (workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("Shop"))
            or workspace:FindFirstChild("EggShop", true)
            or workspace:FindFirstChild("Shop", true)

        if eggShop then
            for _, desc in ipairs(eggShop:GetDescendants()) do
                -- Cek ProximityPrompt
                if desc:IsA("ProximityPrompt") then
                    local act = desc.ActionText or ""
                    local obj = desc.ObjectText or ""
                    if act:lower():find("egg") or obj:lower():find("egg") then
                        local eggTitle = (obj ~= "" and obj) or act
                        addEgg(eggTitle, "Prompt", "In-Game", "EggShop ProximityPrompt")
                    end
                end

                -- Cek TextLabel di BillboardGui / SurfaceGui
                if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                    local text = desc.Text
                    if text and text:lower():find("egg") and not text:lower():find("shop") then
                        addEgg(text, "World UI", "In-Game", "EggShop Text: " .. desc.Name)
                    end
                end

                -- Cek Model Name dengan kata "Egg"
                if desc:IsA("Model") or desc:IsA("Folder") then
                    if desc.Name:lower():find("egg") and desc.Name ~= "EggShop" and desc.Name ~= "EggStand" then
                        addEgg(desc.Name, "World Model", "In-Game", "Workspace Model: " .. desc.Name)
                    end
                end
            end
        end

        -- Global ProximityPrompt search for any Egg prompt
        for _, prompt in ipairs(workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") then
                local act = prompt.ActionText or ""
                local obj = prompt.ObjectText or ""
                if act:lower():find("egg") or obj:lower():find("egg") then
                    local name = (obj ~= "" and obj) or act
                    addEgg(name, "Prompt", "In-Game", "Prompt @" .. (prompt.Parent and prompt.Parent.Name or "World"))
                end
            end
        end
    end)

    -- 3. Scan PlayerGui for Shop/Egg Frames & Buttons
    pcall(function()
        local mainGui = getMainGui()
        if mainGui then
            for _, desc in ipairs(mainGui:GetDescendants()) do
                if desc:IsA("GuiObject") and desc.Name:lower():find("egg") then
                    -- Cek jika ada title label di dalamnya
                    local titleLbl = desc:FindFirstChild("Title", true) or desc:FindFirstChild("Name", true) or desc:FindFirstChildWhichIsA("TextLabel")
                    local priceLbl = desc:FindFirstChild("Price", true) or desc:FindFirstChild("Cost", true)
                    local name = (titleLbl and titleLbl.Text) or desc.Name
                    local price = priceLbl and priceLbl.Text or "UI Item"
                    if name:lower():find("egg") then
                        addEgg(name, price, "UI", "PlayerGui: " .. desc.Name)
                    end
                end
            end
        end
    end)

    -- 4. Pastikan "Capybara Egg" selalu ada sebagai basis default
    addEgg("Capybara Egg", "Standard", "Coins", "Default Base")

    -- Simpan hasil scan ke state
    AutoBuyEgg.DiscoveredEggs = discoveredList

    -- Simpan ke file JSON jika didukung executor
    pcall(function()
        if typeof(writefile) == "function" and typeof(makefolder) == "function" then
            if not isfolder("RitodHub") then makefolder("RitodHub") end
            if not isfolder("RitodHub/Capybara") then makefolder("RitodHub/Capybara") end
            local jsonStr = HttpService:JSONEncode(discoveredList)
            writefile("RitodHub/Capybara/DiscoveredEggs.json", jsonStr)
            print("💾 [Ritod Hub] Hasil scan telur tersimpan di: RitodHub/Capybara/DiscoveredEggs.json")
        end
    end)

    -- Salin ke clipboard jika ada
    pcall(function()
        if typeof(setclipboard) == "function" then
            local names = {}
            for _, e in ipairs(discoveredList) do table.insert(names, e.name) end
            setclipboard(table.concat(names, "\n"))
        end
    end)

    print("===============================================================")
    print(string.format("✅ [Ritod Hub] SCAN SELESAI: %d Jenis Egg Ditemukan!", #discoveredList))
    print("===============================================================")

    if AutoBuyEgg.OnCatalogUpdated then
        pcall(function() AutoBuyEgg.OnCatalogUpdated(discoveredList) end)
    end

    return discoveredList
end

-- =================================================================
-- 🛒 PURE AUTO BUY EGG ENGINE
-- =================================================================

function AutoBuyEgg.GetEggShop()
    return (workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("EggShop"))
        or (workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("Shop"))
        or workspace:FindFirstChild("EggShop", true)
        or workspace:FindFirstChild("Shop", true)
end

function AutoBuyEgg.BuyEgg(eggName)
    eggName = eggName or AutoBuyEgg.Config.SelectedEgg or "Capybara Egg"
    local hrp = getHRP()
    local eggShop = AutoBuyEgg.GetEggShop()

    -- 1. Teleportasi ke EggShop jika diaktifkan (agar lolos distance check server)
    if AutoBuyEgg.Config.AutoTeleport and eggShop and hrp then
        pcall(function()
            local targetPos = (eggShop:IsA("Model") and eggShop:GetPivot() or eggShop.CFrame) * CFrame.new(0, 2, 5)
            hrp.CFrame = targetPos
        end)
        task.wait(0.3)
    end

    -- 2. Beli via Remote
    local bought = false
    pcall(function()
        if Remotes:FindFirstChild("BuyItem") then
            callRemote("BuyItem", eggName)
            bought = true
        elseif Remotes:FindFirstChild("BuyEgg") then
            callRemote("BuyEgg", eggName)
            bought = true
        elseif Remotes:FindFirstChild("PurchaseItem") then
            callRemote("PurchaseItem", eggName)
            bought = true
        end
    end)

    -- 3. Fallback ProximityPrompt di EggShop
    if not bought and eggShop then
        triggerNearbyKeywordPrompts(eggShop:GetPivot().Position, 20, "egg")
        triggerNearbyKeywordPrompts(eggShop:GetPivot().Position, 20, "buy")
    end

    totalEggsBought = totalEggsBought + 1
    print(string.format("🛒 [Auto Buy Egg] Membeli Telur: %s (Total: %d)", eggName, totalEggsBought))
    return bought
end

-- =================================================================
-- 🏡 PLOT & OPTIONAL STEP 2 / STEP 3 ENGINE
-- =================================================================

function AutoBuyEgg.GetMyPlot()
    local plots = (workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("Plots"))
        or workspace:FindFirstChild("Plots", true)
        or workspace:FindFirstChild("PlayerPlots", true)

    if not plots then return nil end

    local myUserId = tostring(LocalPlayer.UserId)
    local myName = LocalPlayer.Name:lower()

    for _, plot in ipairs(plots:GetChildren()) do
        for _, attrName in ipairs({"Owner", "UserId", "PlayerId", "OwnerId", "Player"}) do
            local val = plot:GetAttribute(attrName)
            if val and (tostring(val):lower() == myUserId or tostring(val):lower() == myName) then
                return plot
            end
        end
    end

    for _, plot in ipairs(plots:GetChildren()) do
        for _, child in ipairs(plot:GetChildren()) do
            if child:IsA("ValueBase") then
                local v = child.Value
                if tostring(v):lower() == myUserId or tostring(v):lower() == myName or v == LocalPlayer then
                    return plot
                end
            end
        end
    end

    local hrp = getHRP()
    if hrp then
        local myPos = hrp.Position
        local minDist = math.huge
        local bestPlot = nil
        for _, plot in ipairs(plots:GetChildren()) do
            local ok, pivot = pcall(function() return plot:GetPivot() end)
            if ok then
                local dist = (pivot.Position - myPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    bestPlot = plot
                end
            end
        end
        return bestPlot
    end

    return nil
end

function AutoBuyEgg.GetTowerAreaLanes(myPlot)
    myPlot = myPlot or AutoBuyEgg.GetMyPlot()
    if not myPlot then return {} end

    local towerArea = myPlot:FindFirstChild("TowerArea")
    if not towerArea then return {} end

    local lanes = {}
    for _, child in ipairs(towerArea:GetChildren()) do
        local targetPart = child:FindFirstChild("TowerAreaPart")
            or child:FindFirstChildWhichIsA("BasePart")
            or (child:IsA("BasePart") and child)
            or (child:IsA("Model") and child.PrimaryPart)
            or child:GetChildren()[1]

        if targetPart then
            table.insert(lanes, {
                Container = child,
                Part = targetPart,
                Name = child.Name,
            })
        end
    end
    return lanes
end

function AutoBuyEgg.PlaceEggOnLane(targetLanePart)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = getHRP()
    if not hrp then return false end

    local myPlot = AutoBuyEgg.GetMyPlot()
    if not myPlot then return false end

    if not targetLanePart then
        local lanes = AutoBuyEgg.GetTowerAreaLanes(myPlot)
        if #lanes > 0 then targetLanePart = lanes[1].Part end
    end

    if targetLanePart then
        local lPos = targetLanePart:IsA("BasePart") and targetLanePart.Position or targetLanePart:GetPivot().Position
        hrp.CFrame = CFrame.new(lPos + Vector3.new(0, 3, 0))
    else
        hrp.CFrame = CFrame.new(myPlot:GetPivot().Position + Vector3.new(0, 5, 0))
    end
    task.wait(0.4)

    local backpack = LocalPlayer:WaitForChild("Backpack", 5)
    local camera = workspace.CurrentCamera

    if backpack then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then t.Parent = backpack end
        end
        task.wait(0.2)

        local eggTool = nil
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:lower():find("egg") or tool.Name:lower():find("capybara")) then
                eggTool = tool
                break
            end
        end

        if eggTool then
            eggTool.Parent = char
            task.wait(0.3)
            pcall(function() eggTool:Activate() end)
        end
    end
    task.wait(0.5)

    pcall(function()
        local targetLook = hrp.Position + (hrp.CFrame.LookVector * 4) - Vector3.new(0, 2, 0)
        camera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 4, 0), targetLook)
        task.wait(0.1)

        local viewSize = camera.ViewportSize
        local centerX = math.floor(viewSize.X / 2)
        local centerY = math.floor(viewSize.Y / 2)

        if typeof(mousemoveabs) == "function" then mousemoveabs(centerX, centerY) end
        task.wait(0.05)

        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
        task.wait(0.06)
        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)

        if typeof(mouse1press) == "function" then
            mouse1press()
            task.wait(0.06)
            mouse1release()
        end
    end)

    totalEggsPlaced = totalEggsPlaced + 1
    return true
end

function AutoBuyEgg.HatchEgg(targetLanePart)
    local hrp = getHRP()
    if targetLanePart and hrp then
        local lPos = targetLanePart:IsA("BasePart") and targetLanePart.Position or targetLanePart:GetPivot().Position
        hrp.CFrame = CFrame.new(lPos + Vector3.new(0, 2, 0))
        task.wait(0.2)
        triggerNearbyKeywordPrompts(lPos, 12, "hatch")
    end

    pcall(function()
        callRemote("Hatch")
    end)

    totalEggsHatched = totalEggsHatched + 1
    return true
end

-- =================================================================
-- 🔄 SINGLE CYCLE & CONTINUOUS LOOP
-- =================================================================

function AutoBuyEgg.RunSingleCycle()
    -- 1. Beli Egg
    AutoBuyEgg.BuyEgg(AutoBuyEgg.Config.SelectedEgg)

    -- 2. Taruh Egg di Lane HANYA jika opsi AutoPlace dicentang
    if AutoBuyEgg.Config.AutoPlace then
        task.wait(1.0)
        local myPlot = AutoBuyEgg.GetMyPlot()
        local targetPart = nil
        if myPlot then
            local lanes = AutoBuyEgg.GetTowerAreaLanes(myPlot)
            if #lanes > 0 then targetPart = lanes[1].Part end
        end
        AutoBuyEgg.PlaceEggOnLane(targetPart)

        -- 3. Hatch Telur HANYA jika opsi AutoHatch dicentang
        if AutoBuyEgg.Config.AutoHatch then
            local hatchWait = AutoBuyEgg.Config.HatchWait or 8
            task.wait(hatchWait)
            AutoBuyEgg.HatchEgg(targetPart)
        end
    end
end

function AutoBuyEgg.Start()
    if isRunning then return end
    isRunning = true
    AutoBuyEgg.Config.Enabled = true
    print("🚀 [Ritod Hub] Auto Buy Egg Engine Dimulai!")

    loopThread = task.spawn(function()
        while isRunning do
            local success, err = pcall(function()
                AutoBuyEgg.RunSingleCycle()
            end)
            if not success then
                warn("⚠️ [Auto Buy Egg] Error saat siklus: " .. tostring(err))
            end
            task.wait(AutoBuyEgg.Config.BuyInterval or 1.2)
        end
    end)
end

function AutoBuyEgg.Stop()
    isRunning = false
    AutoBuyEgg.Config.Enabled = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
    print("🛑 [Ritod Hub] Auto Buy Egg Engine Dihentikan.")
end

function AutoBuyEgg.Toggle(state)
    if state == nil then state = not isRunning end
    if state then
        AutoBuyEgg.Start()
    else
        AutoBuyEgg.Stop()
    end
    return isRunning
end

function AutoBuyEgg.IsRunning()
    return isRunning
end

function AutoBuyEgg.GetStats()
    return {
        Bought = totalEggsBought,
        Placed = totalEggsPlaced,
        Hatched = totalEggsHatched,
        IsRunning = isRunning,
    }
end

-- Jalankan scan awal saat modul dimuat pertama kali
task.spawn(function()
    task.wait(0.5)
    AutoBuyEgg.ScanEggs()
end)

return AutoBuyEgg
