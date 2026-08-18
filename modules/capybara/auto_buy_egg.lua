--[[
	===============================================================
	⚡ RITOD HUB - AUTO BUY EGG ENGINE (SMART STOCK-DRIVEN)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- 🛑 ZERO SPAM: Remote TIDAK AKAN dikirim jika stock = 0 / NO STOCK!
	- ⚡ SMART STOCK-DRIVEN: Hanya membeli saat stock = true (ada stok > 0).
	- 🥚 CHECKLIST SELECTION (Centang 1 atau Banyak Telur)
	- ⚡ BULK INSTANT BUY (Membeli seluruh kuantiti stok yang muncul)
	- 🤫 SILENT MODE (Zero terminal/console spam)
	- 📡 Pure Remote Buying Jarak Jauh (No Teleport)
	- 🥚 Optional Step 2 (Auto Place on Lane - Default OFF)
	- 🐣 Optional Step 3 (Auto Hatch - Default OFF)
	===============================================================
]]

local AutoBuyEgg = {}
_G.AutoBuyEgg = AutoBuyEgg

-- 🔇 SILENT MODE: Matikan seluruh text/log terminal
local print = function(...) end
local warn = function(...) end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- =================================================================
-- 📋 OFFICIAL 9 EGG CATALOG (EXACT IN-GAME RARITIES)
-- =================================================================
AutoBuyEgg.OFFICIAL_EGGS = {
    { name = "Capybara Egg",        rarity = "Common" },
    { name = "Alpha Capybara Egg",  rarity = "Rare" },
    { name = "Archer Capybara Egg", rarity = "Epic" },
    { name = "Magic Capybara Egg",  rarity = "Legendary" },
    { name = "Ghost Capybara Egg",  rarity = "Mythic" },
    { name = "Robot Capybara Egg",  rarity = "Godly" },
    { name = "Golem Capybara Egg",  rarity = "Divine" },
    { name = "Disco Capybara Egg",  rarity = "Secret" },
    { name = "Angel Capybara Egg",  rarity = "Secret" },
}

AutoBuyEgg.DiscoveredEggs = AutoBuyEgg.OFFICIAL_EGGS

AutoBuyEgg.Config = {
    Enabled       = false,
    SelectedEggs  = {
        ["capybara egg"] = true,
    },
    BuyAllStock   = true,    -- Default TRUE: Borong seluruh stok yang ada
    AutoPlace     = false,   -- Default OFF
    AutoHatch     = false,   -- Default OFF
    HatchWait     = 8,       -- Jeda waktu hatch (jika aktif)
    AutoTeleport  = false,   -- Default FALSE: Beli Jarak Jauh (Remote Buy Tanpa Teleport)
    CheckInterval = 1.0,     -- Jeda pengecekan stok lokal (detik)
}

local isRunning = false
local loopThread = nil
local stockConnections = {}
local totalEggsBought = 0
local totalEggsPlaced = 0
local totalEggsHatched = 0

AutoBuyEgg.OnCatalogUpdated = nil

-- =================================================================
-- 🛠️ HELPER FUNCTIONS
-- =================================================================

local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
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
                if btn[ev] then
                    for _, conn in ipairs(getconnections(btn[ev])) do
                        if conn.Function then conn.Function() elseif conn.Fire then conn:Fire() end
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
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end
    end)
end

-- =================================================================
-- 📦 SMART STOCK DETECTOR (ANTI-SPAM)
-- =================================================================

function AutoBuyEgg.HasStock(eggName)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false, 0 end

    local eggFrame = pg:FindFirstChild(eggName, true)
    if not eggFrame then
        local shortName = eggName:gsub("%s*[Ee]gg%s*", "")
        eggFrame = pg:FindFirstChild(shortName, true) or pg:FindFirstChild(shortName .. " Egg", true)
    end
    if not eggFrame then return false, 0 end

    -- 1. Cek attribute OutOfStock
    if eggFrame:GetAttribute("OutOfStock") == true then
        return false, 0
    end

    -- 2. Cek label Stock
    local stockLabel = eggFrame:FindFirstChild("Stock", true)
    if stockLabel and stockLabel.Text then
        local txt = stockLabel.Text
        if txt:lower():find("no stock") then
            return false, 0
        end
        local count = tonumber(txt:match("(%d+)"))
        if count and count > 0 then
            return true, count
        end
        if txt:lower():find("in stock") then
            return true, 1
        end
    end

    return false, 0
end

function AutoBuyEgg.GetEggStock(eggName)
    local hasStock, count = AutoBuyEgg.HasStock(eggName)
    return hasStock and count or 0
end

-- =================================================================
-- 🔍 IN-GAME EGG & SHOP SCANNER
-- =================================================================

function AutoBuyEgg.ScanEggs()
    local eggMap = {}
    local discoveredList = {}

    for _, egg in ipairs(AutoBuyEgg.OFFICIAL_EGGS) do
        local key = egg.name:lower()
        eggMap[key] = {
            name = egg.name,
            rarity = egg.rarity
        }
        table.insert(discoveredList, eggMap[key])
    end

    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local eggShopList = pg and pg:FindFirstChild("EggShop", true) and pg.EggShop:FindFirstChild("List", true)
        if not eggShopList and pg then
            eggShopList = pg:FindFirstChild("List", true)
        end

        if eggShopList then
            for _, eggFrame in ipairs(eggShopList:GetChildren()) do
                if eggFrame:IsA("GuiObject") then
                    local rLabel = eggFrame:FindFirstChild("Rarity", true)
                    local rName = (rLabel and rLabel.Text) or "Common"
                    local key = eggFrame.Name:lower()

                    if eggMap[key] then
                        eggMap[key].rarity = rName
                        eggMap[key].outOfStock = eggFrame:GetAttribute("OutOfStock") == true
                    else
                        local entry = {
                            name = eggFrame.Name,
                            rarity = rName,
                            outOfStock = eggFrame:GetAttribute("OutOfStock") == true
                        }
                        eggMap[key] = entry
                        table.insert(discoveredList, entry)
                    end
                end
            end
        end
    end)

    AutoBuyEgg.DiscoveredEggs = discoveredList

    if AutoBuyEgg.OnCatalogUpdated then
        pcall(function() AutoBuyEgg.OnCatalogUpdated(discoveredList) end)
    end

    return discoveredList
end

-- =================================================================
-- 🛒 PURE AUTO BUY EGG ENGINE (HANYA MEMBELI JIKA ADA STOK)
-- =================================================================

function AutoBuyEgg.BuyEgg(eggName, forceCount)
    eggName = eggName or "Capybara Egg"

    -- 🛑 PERIKSA STOK TERLEBIH DAHULU: Jangan kirim request jika stok = 0
    local hasStock, availableStock = AutoBuyEgg.HasStock(eggName)
    if not hasStock or availableStock <= 0 then
        return false -- Stok habis, skip tanpa spam remote
    end

    local hrp = getHRP()
    local eggShop = (workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("EggShop"))
        or workspace:FindFirstChild("EggShop", true)
        or workspace:FindFirstChild("Shop", true)

    -- Teleport HANYA jika diaktifkan secara eksplisit oleh user (Default FALSE)
    if AutoBuyEgg.Config.AutoTeleport and eggShop and hrp then
        local targetPos = (eggShop:IsA("Model") and eggShop:GetPivot() or eggShop.CFrame) * CFrame.new(0, 2, 5)
        hrp.CFrame = targetPos
        task.wait(0.5)
    end

    local targetCount = 1
    if forceCount and forceCount > 0 then
        targetCount = forceCount
    elseif AutoBuyEgg.Config.BuyAllStock then
        targetCount = math.max(1, availableStock)
    end

    -- Eksekusi pembelian murni hanya jika ada stok (Silent Mode)
    local boughtCount = 0
    pcall(function()
        callRemote("BuyItem", eggName, targetCount)
    end)

    for _ = 1, targetCount do
        local ok = pcall(function()
            callRemote("BuyItem", eggName)
        end)
        if ok then boughtCount = boughtCount + 1 end
        if targetCount > 1 then task.wait(0.04) end
    end

    -- Fallback UI Button jika remote tidak merespons
    if boughtCount == 0 then
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local eggFrame = pg and pg:FindFirstChild(eggName, true)
            if eggFrame then
                for _, desc in ipairs(eggFrame:GetDescendants()) do
                    if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                        local costLbl = desc:FindFirstChild("Cost") or desc:FindFirstChildWhichIsA("TextLabel")
                        local txt = (costLbl and costLbl.Text) or desc.Text or ""
                        if txt:find("%$") or txt:find("k") or txt:find("M") or txt:find("B") or desc.Name:lower():find("coin") then
                            clickButton(desc)
                            boughtCount = boughtCount + 1
                        end
                    end
                end
            end
        end)
    end

    totalEggsBought = totalEggsBought + boughtCount
    return boughtCount > 0
end

function AutoBuyEgg.BuyAllStock(eggName)
    local hasStock, stock = AutoBuyEgg.HasStock(eggName)
    if not hasStock or stock <= 0 then return false end
    return AutoBuyEgg.BuyEgg(eggName, stock)
end

-- =================================================================
-- 🏡 OPTIONAL STEP 2 / STEP 3 ENGINE
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
        pcall(function()
            for _, prompt in ipairs(workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                    local act = (prompt.ActionText or ""):lower()
                    if act:find("hatch") and typeof(fireproximityprompt) == "function" then
                        fireproximityprompt(prompt)
                    end
                end
            end
        end)
    end

    pcall(function()
        callRemote("Hatch")
    end)

    totalEggsHatched = totalEggsHatched + 1
    return true
end

-- =================================================================
-- 🔄 SINGLE CYCLE & CONTINUOUS LOOP (SMART EVENT & MONITOR)
-- =================================================================

function AutoBuyEgg.RunSingleCycle()
    local selectedEggs = AutoBuyEgg.Config.SelectedEggs or {}

    for _, egg in ipairs(AutoBuyEgg.OFFICIAL_EGGS) do
        local key = egg.name:lower()
        if selectedEggs[key] == true or selectedEggs[egg.name] == true then
            -- Cek stok: HANYA jika ada stok (stock > 0), baru jalankan pembelian!
            local hasStock, stockCount = AutoBuyEgg.HasStock(egg.name)
            if hasStock and stockCount > 0 then
                local bought = AutoBuyEgg.BuyEgg(egg.name, stockCount)
                if bought and AutoBuyEgg.Config.AutoPlace then
                    task.wait(0.6)
                    local myPlot = AutoBuyEgg.GetMyPlot()
                    local targetPart = nil
                    if myPlot then
                        local lanes = AutoBuyEgg.GetTowerAreaLanes(myPlot)
                        if #lanes > 0 then targetPart = lanes[1].Part end
                    end
                    AutoBuyEgg.PlaceEggOnLane(targetPart)

                    if AutoBuyEgg.Config.AutoHatch then
                        local hatchWait = AutoBuyEgg.Config.HatchWait or 8
                        task.wait(hatchWait)
                        AutoBuyEgg.HatchEgg(targetPart)
                    end
                end
            end
        end
    end
end

local function setupStockListeners()
    for _, conn in ipairs(stockConnections) do
        if conn and conn.Disconnect then conn:Disconnect() end
    end
    table.clear(stockConnections)

    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local eggShopList = pg and pg:FindFirstChild("EggShop", true) and pg.EggShop:FindFirstChild("List", true)
        if not eggShopList and pg then eggShopList = pg:FindFirstChild("List", true) end

        if eggShopList then
            for _, eggFrame in ipairs(eggShopList:GetChildren()) do
                if eggFrame:IsA("GuiObject") then
                    local stockLbl = eggFrame:FindFirstChild("Stock", true)
                    if stockLbl and stockLbl:IsA("TextLabel") then
                        local c = stockLbl:GetPropertyChangedSignal("Text"):Connect(function()
                            if isRunning then
                                AutoBuyEgg.RunSingleCycle()
                            end
                        end)
                        table.insert(stockConnections, c)
                    end

                    local cAttr = eggFrame:GetAttributeChangedSignal("OutOfStock"):Connect(function()
                        if isRunning and eggFrame:GetAttribute("OutOfStock") == false then
                            AutoBuyEgg.RunSingleCycle()
                        end
                    end)
                    table.insert(stockConnections, cAttr)
                end
            end
        end
    end)
end

function AutoBuyEgg.Start()
    if isRunning then return end
    isRunning = true
    AutoBuyEgg.Config.Enabled = true

    setupStockListeners()

    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end

    loopThread = task.spawn(function()
        while isRunning do
            pcall(function()
                AutoBuyEgg.RunSingleCycle()
            end)
            -- Jeda pengecekan stok lokal tanpa mengirim remote apapun jika stok kosong
            task.wait(AutoBuyEgg.Config.CheckInterval or 1.0)
        end
    end)
end

function AutoBuyEgg.Stop()
    isRunning = false
    AutoBuyEgg.Config.Enabled = false

    for _, conn in ipairs(stockConnections) do
        if conn and conn.Disconnect then conn:Disconnect() end
    end
    table.clear(stockConnections)

    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
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

return AutoBuyEgg
