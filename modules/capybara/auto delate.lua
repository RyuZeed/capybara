-- =================================================================
-- 🗑️ RITOD HUB | AUTO DELETE PLANT MODULE
-- Game: Capybaras vs Plants (PlaceId: 104973076655377)
-- =================================================================

local AutoDeletePlant = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

-- =================================================================
-- ⚙️ CONFIGURATION & SETTINGS
-- =================================================================
AutoDeletePlant.Config = {
    Enabled = false,
    ScanInterval = 2.5,        -- Detik antar scanning inventory & plot
    
    -- Filter Berdasarkan Rarity / Tier
    DeleteCommon = true,       -- Hapus tanaman Common (Carrot, Tomato, Potato, dll)
    DeleteUncommon = false,    -- Hapus tanaman Uncommon
    DeleteRare = false,        -- Hapus tanaman Rare
    DeleteDuplicates = false,  -- Hapus duplikat jika inventory penuh
    
    -- Proteksi
    ProtectEquipped = true,    -- JANGAN PERNAH hapus tanaman yang sedang di-equip
    AutoEquipBestFirst = true, -- Jalankan Equip Best Plants sebelum menghapus agar tanaman terbaik aman
    
    -- Custom Whitelist (Nama tanaman yang TIDAK BOLEH dihapus sama sekali)
    Whitelist = {
        "dragonfruit", "watermelon", "pumpkin", "sakura", "thunder", 
        "void", "phoenix", "celestial", "astral", "divine", "godly"
    },
    
    -- Custom Blacklist (Nama tanaman yang SELALU dihapus jika ditemukan)
    Blacklist = {
        "carrot", "basic carrot", "potato", "tomato", "corn", 
        "cabbage", "wheat", "beetroot", "onion", "lettuce"
    }
}

local isRunning = false
local deleteThread = nil

-- =================================================================
-- 🛠️ HELPER FUNCTIONS (UNIVERSAL EXECUTOR & MOBILE READY)
-- =================================================================

local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getChar()
    return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
end

local function getMainGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    if not pg then return nil end
    return pg:FindFirstChild("MainGui") or pg:WaitForChild("MainGui", 3) or pg:FindFirstChildWhichIsA("ScreenGui")
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

    -- 1. firesignal (Mobile/PC Executors)
    if typeof(firesignal) == "function" then
        if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
        if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
        if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
    end

    -- 2. getconnections
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

    -- 3. VirtualInputManager Touch & Mouse Simulation
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local cx = math.floor(pos.X + size.X / 2)
        local cy = math.floor(pos.Y + size.Y / 2)

        if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
            pcall(function()
                VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.02)
                VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
            end)
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

local function triggerSinglePromptInstant(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end

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
        task.wait(0.02)
        prompt:InputHoldEnd()
    end)

    return true
end

local function handleConfirmPopup(maxWait)
    local waitTime = maxWait or 1.5
    local startTime = tick()

    while (tick() - startTime) < waitTime do
        local clicked = false
        pcall(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if not playerGui then return end

            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled then
                    for _, obj in ipairs(gui:GetDescendants()) do
                        if obj:IsA("GuiObject") and obj.Visible then
                            local objName = obj.Name:lower()
                            if objName:find("confirm") or objName:find("prompt") or objName:find("modal") or objName:find("popup") or objName:find("delete") or objName:find("sell") or objName:find("trash") then
                                for _, btn in ipairs(obj:GetDescendants()) do
                                    if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                                        local btnName = btn.Name:lower()
                                        local btnText = (btn:IsA("TextButton") and btn.Text or ""):lower()

                                        if btnName == "yes" or btnName:find("confirm") or btnName:find("accept") or btnName:find("agree") or btnName:find("delete") or btnName:find("sell") or btnName:find("trash")
                                            or btnText == "yes" or btnText == "ya" or btnText:find("confirm") or btnText:find("delete") or btnText:find("sell") or btnText:find("hapus") or btnText:find("jual") or btnText == "ok" then
                                            clickButton(btn)
                                            clicked = true
                                            task.wait(0.1)
                                            break
                                        end
                                    end
                                end
                            end
                            if clicked then break end
                        end
                    end
                end
                if clicked then break end
            end
        end)

        if clicked then
            task.wait(0.15)
            return true
        end
        task.wait(0.1)
    end
    return false
end

-- =================================================================
-- 🔍 PLANT CLASSIFICATION & FILTER ENGINE
-- =================================================================

-- Memeriksa apakah tanaman boleh dihapus berdasarkan Rarity, Whitelist, dan Blacklist
function AutoDeletePlant.ShouldDelete(plantName, plantRarity, isEquipped)
    if not plantName then return false end
    local name = tostring(plantName):lower()
    local rarity = tostring(plantRarity or ""):lower()

    -- 1. Cek Proteksi Tanaman yang Sedang Digunakan (Equipped)
    if AutoDeletePlant.Config.ProtectEquipped and isEquipped then
        return false
    end

    -- 2. Cek Whitelist (Paling Prioritas: Tidak boleh dihapus)
    for _, safe in ipairs(AutoDeletePlant.Config.Whitelist) do
        if name:find(safe:lower()) or rarity:find(safe:lower()) then
            return false
        end
    end

    -- 3. Cek Blacklist (Selalu dihapus jika cocok)
    for _, target in ipairs(AutoDeletePlant.Config.Blacklist) do
        if name:find(target:lower()) then
            return true
        end
    end

    -- 4. Cek Berdasarkan Rarity Config
    if AutoDeletePlant.Config.DeleteCommon then
        if rarity == "common" or rarity:find("common") or rarity == "biasa" or rarity == "1" then
            return true
        end
        -- Deteksi nama umum jika rarity tidak tertera
        if name:find("carrot") or name:find("tomato") or name:find("potato") or name:find("corn") or name:find("cabbage") or name:find("wheat") then
            return true
        end
    end

    if AutoDeletePlant.Config.DeleteUncommon then
        if rarity == "uncommon" or rarity:find("uncommon") or rarity == "2" then
            return true
        end
    end

    if AutoDeletePlant.Config.DeleteRare then
        if rarity == "rare" or rarity:find("rare") or rarity == "3" then
            return true
        end
    end

    return false
end

-- =================================================================
-- ⚡ METHODS FOR DELETING / SELLING PLANTS
-- =================================================================

-- METODE 1: Remote Execution (Paling Cepat & Efisien)
local function deleteViaRemotes(targetIdOrName)
    local remoteNames = {
        "DeletePlant", "DeletePlants", "SellPlant", "SellPlants",
        "RemovePlant", "RemovePlants", "TrashPlant", "TrashPlants",
        "DestroyPlant", "DiscardPlant", "ClearPlant", "SellAllPlants",
        "QuickSell", "DeleteUnit", "SellUnit", "TrashUnit"
    }

    local executed = false
    for _, rName in ipairs(remoteNames) do
        if targetIdOrName then
            pcall(function()
                callRemote(rName, targetIdOrName)
                callRemote(rName, { targetIdOrName })
                callRemote(rName, 1, targetIdOrName)
                executed = true
            end)
        else
            -- Batch mode jika remote mendukung
            pcall(function()
                callRemote(rName)
            end)
        end
    end
    return executed
end

-- METODE 2: Scanning UI Inventory / Storage
local function scanAndCleanInventoryUI()
    local mainGui = getMainGui()
    if not mainGui then return 0 end

    local deletedCount = 0

    pcall(function()
        -- Cari frame inventory/tanaman
        local targetContainers = {}
        for _, desc in ipairs(mainGui:GetDescendants()) do
            if desc:IsA("Frame") or desc:IsA("ScrollingFrame") then
                local dName = desc.Name:lower()
                if dName:find("plant") or dName:find("inventory") or dName:find("storage") or dName:find("bag") or dName:find("item") then
                    table.insert(targetContainers, desc)
                end
            end
        end

        for _, container in ipairs(targetContainers) do
            for _, itemCard in ipairs(container:GetChildren()) do
                if itemCard:IsA("GuiObject") and itemCard.Visible then
                    local itemName = itemCard.Name
                    local itemRarity = ""
                    local isEquipped = false

                    -- Cari metadata dalam item card
                    for _, child in ipairs(itemCard:GetDescendants()) do
                        local cName = child.Name:lower()

                        if child:IsA("TextLabel") then
                            local text = child.Text or ""
                            if cName:find("name") or cName == "title" then
                                itemName = text
                            elseif cName:find("rarity") or cName:find("tier") then
                                itemRarity = text
                            elseif text:lower():find("equipped") or text:lower():find("in use") or text:lower():find("terpasang") then
                                isEquipped = true
                            end
                        end

                        if cName:find("equipped") or cName:find("checkmark") or cName:find("active") then
                            if child.Visible then isEquipped = true end
                        end
                    end

                    -- Evaluasi apakah harus dihapus
                    if AutoDeletePlant.ShouldDelete(itemName, itemRarity, isEquipped) then
                        -- Cari tombol delete/trash/sell di dalam kartu tanaman
                        local trashBtn = nil
                        for _, btn in ipairs(itemCard:GetDescendants()) do
                            if btn:IsA("GuiButton") then
                                local bName = btn.Name:lower()
                                local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                if bName:find("trash") or bName:find("del") or bName:find("sell") or bName:find("remove") or bName:find("drop")
                                    or bText:find("trash") or bText:find("del") or bText:find("sell") or bText:find("hapus") or bText:find("jual") then
                                    trashBtn = btn
                                    break
                                end
                            end
                        end

                        if trashBtn then
                            clickButton(trashBtn)
                            task.wait(0.05)
                            handleConfirmPopup(0.8)
                            deletedCount = deletedCount + 1
                        else
                            -- Jika tidak ada tombol langsung, klik item untuk membuka detail lalu hapus
                            clickButton(itemCard)
                            task.wait(0.08)

                            -- Cek popup info/detail yang muncul
                            for _, obj in ipairs(mainGui:GetDescendants()) do
                                if obj:IsA("GuiButton") and obj.Visible then
                                    local bName = obj.Name:lower()
                                    local bText = (obj:IsA("TextButton") and obj.Text or ""):lower()
                                    if bName:find("trash") or bName:find("delete") or bName:find("sell") or bName:find("remove")
                                        or bText:find("trash") or bText:find("delete") or bText:find("sell") or bText:find("hapus") or bText:find("jual") then
                                        clickButton(obj)
                                        task.wait(0.05)
                                        handleConfirmPopup(0.8)
                                        deletedCount = deletedCount + 1
                                        break
                                    end
                                end
                            end
                        end

                        -- Coba juga lewat remote ID/Name
                        deleteViaRemotes(itemName)
                        task.wait(0.1)
                    end
                end
            end
        end
    end)

    return deletedCount
end

-- METODE 3: Auto Clean Plot / Pots dari Tanaman Sampah
local function scanAndCleanPlotPots()
    local myPlot = nil
    pcall(function()
        local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("Plots")
        if not plots then plots = workspace:FindFirstChild("Plots", true) end
        if plots then
            for _, plot in ipairs(plots:GetChildren()) do
                if plot:GetAttribute("Owner") == LocalPlayer.Name or plot:GetAttribute("OwnerId") == LocalPlayer.UserId or plot.Name == LocalPlayer.Name then
                    myPlot = plot
                    break
                end
            end
            if not myPlot then myPlot = plots:FindFirstChild("1") or plots:GetChildren()[1] end
        end
    end)

    if not myPlot then return end

    pcall(function()
        local pottedPlants = myPlot:FindFirstChild("PottedPlants") or myPlot:FindFirstChild("Pots") or myPlot:FindFirstChild("TowerArea")
        if not pottedPlants then return end

        for _, pot in ipairs(pottedPlants:GetChildren()) do
            for _, prompt in ipairs(pot:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                    local actText = (prompt.ActionText or ""):lower()
                    local objText = (prompt.ObjectText or ""):lower()
                    local nameText = (prompt.Name or ""):lower()

                    -- Jika ada opsi Remove / Shovel / Clear / Delete di pot
                    if actText:find("shovel") or actText:find("remove") or actText:find("delete") or actText:find("clear") or actText:find("sell")
                        or objText:find("shovel") or objText:find("remove") or objText:find("delete")
                        or nameText:find("shovel") or nameText:find("remove") or nameText:find("delete") then
                        
                        -- Cek apakah tanaman di pot adalah tanaman yang ingin dihapus
                        local potPlantName = pot.Name:lower()
                        for _, child in ipairs(pot:GetChildren()) do
                            if child:IsA("Model") or child:IsA("Folder") then
                                potPlantName = child.Name:lower()
                            end
                        end

                        if AutoDeletePlant.ShouldDelete(potPlantName, "common", false) then
                            triggerSinglePromptInstant(prompt)
                            task.wait(0.1)
                            handleConfirmPopup(0.8)
                        end
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 🔄 MAIN SCANNING & CLEANING CYCLE
-- =================================================================

function AutoDeletePlant.RunSingleCycle()
    pcall(function()
        -- 1. Selalu pastikan tanaman terbaik terpasang aman (Equip Best)
        if AutoDeletePlant.Config.AutoEquipBestFirst then
            callRemote("EquipBestPlants")
            task.wait(0.2)
        end

        -- 2. Bersihkan via UI Inventory
        scanAndCleanInventoryUI()

        -- 3. Bersihkan via Blacklist Remotes
        for _, blacklistedName in ipairs(AutoDeletePlant.Config.Blacklist) do
            deleteViaRemotes(blacklistedName)
        end

        -- 4. Bersihkan pot jika ada tanaman sampah
        scanAndCleanPlotPots()
    end)
end

-- =================================================================
-- 🚀 PUBLIC CONTROL API (START / STOP / TOGGLE)
-- =================================================================

function AutoDeletePlant.Start()
    if isRunning then return end
    isRunning = true
    AutoDeletePlant.Config.Enabled = true
    print("🗑️ [Ritod Hub] Auto Delete Plant: [ ON ]")

    deleteThread = task.spawn(function()
        while isRunning and AutoDeletePlant.Config.Enabled do
            AutoDeletePlant.RunSingleCycle()
            task.wait(AutoDeletePlant.Config.ScanInterval or 2.5)
        end
        isRunning = false
    end)
end

function AutoDeletePlant.Stop()
    isRunning = false
    AutoDeletePlant.Config.Enabled = false
    if deleteThread then
        task.cancel(deleteThread)
        deleteThread = nil
    end
    print("🛑 [Ritod Hub] Auto Delete Plant: [ OFF ]")
end

function AutoDeletePlant.Toggle(state)
    if state == nil then state = not isRunning end
    if state then
        AutoDeletePlant.Start()
    else
        AutoDeletePlant.Stop()
    end
    return isRunning
end

function AutoDeletePlant.IsRunning()
    return isRunning
end

function AutoDeletePlant.SetFilter(options)
    if type(options) ~= "table" then return end
    for k, v in pairs(options) do
        AutoDeletePlant.Config[k] = v
    end
    print("⚙️ [Ritod Hub] Auto Delete Plant Filter Diperbarui.")
end

-- Return Module Table
return AutoDeletePlant
