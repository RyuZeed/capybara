--[[
	===============================================================
	⚡ RITOD HUB - AUTO DELETE PLANT & IN-GAME SCANNER (ULTRA HD)
	Game: Capybaras vs Plants
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🔍 REAL-TIME IN-GAME PLANT SCANNER:
	  Mendeteksi seluruh tanaman in-game dari ReplicatedStorage, UI Almanac/Inventory, & Workspace
	- 🖥️ ULTRA HD GUI (680x440) with Neon Floating Widget & Minimize
	- 🗑️ TRIPLE-ENGINE AUTO CLEANER:
	  1. Remote Discovery Engine (Fast remote execution)
	  2. Inventory UI Scanner & Auto Sell/Trash clicker
	  3. Plot & Pot Shovel Scanner (Instant Proximity Prompt bypass)
	- 🛡️ BULLETPROOF SAFETY: Whitelist & Protect Equipped Plants
	- 📱 UNIVERSAL: PC & Mobile (Delta, Codex, Arceus, Hydrogen, Fluxus)
	===============================================================
]]

local AutoDeletePlant = {}

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.3)

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

-- =================================================================
-- 🎨 RARITY DEFINITIONS & COLOR PALETTE
-- =================================================================
local RARITY_COLORS = {
    ["Common"]    = Color3.fromRGB(180, 180, 180),
    ["Uncommon"]  = Color3.fromRGB(85, 230, 120),
    ["Rare"]      = Color3.fromRGB(75, 170, 255),
    ["Epic"]      = Color3.fromRGB(195, 85, 255),
    ["Legendary"] = Color3.fromRGB(255, 200, 50),
    ["Mythic"]    = Color3.fromRGB(255, 65, 95),
    ["Secret"]    = Color3.fromRGB(0, 255, 230),
    ["Godly"]     = Color3.fromRGB(255, 110, 240),
}

-- Comprehensive Base In-Game Plant Database
local INGAME_PLANT_DATABASE = {
    -- Common
    { name = "Carrot", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Basic Carrot", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Potato", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Tomato", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Corn", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Wheat", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Cabbage", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Onion", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Beetroot", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Lettuce", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Radish", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Pea", rarity = "Common", color = RARITY_COLORS["Common"] },
    { name = "Cucumber", rarity = "Common", color = RARITY_COLORS["Common"] },

    -- Uncommon
    { name = "Blueberry", rarity = "Uncommon", color = RARITY_COLORS["Uncommon"] },
    { name = "Strawberry", rarity = "Uncommon", color = RARITY_COLORS["Uncommon"] },
    { name = "Garlic", rarity = "Uncommon", color = RARITY_COLORS["Uncommon"] },
    { name = "Chili Pepper", rarity = "Uncommon", color = RARITY_COLORS["Uncommon"] },
    { name = "Broccoli", rarity = "Uncommon", color = RARITY_COLORS["Uncommon"] },
    { name = "Mushroom", rarity = "Uncommon", color = RARITY_COLORS["Uncommon"] },
    { name = "Grape", rarity = "Uncommon", color = RARITY_COLORS["Uncommon"] },
    { name = "Pineapple", rarity = "Uncommon", color = RARITY_COLORS["Uncommon"] },

    -- Rare
    { name = "Sunflower", rarity = "Rare", color = RARITY_COLORS["Rare"] },
    { name = "Watermelon", rarity = "Rare", color = RARITY_COLORS["Rare"] },
    { name = "Pumpkin", rarity = "Rare", color = RARITY_COLORS["Rare"] },
    { name = "Golden Carrot", rarity = "Rare", color = RARITY_COLORS["Rare"] },
    { name = "Fire Chili", rarity = "Rare", color = RARITY_COLORS["Rare"] },
    { name = "Crystal Wheat", rarity = "Rare", color = RARITY_COLORS["Rare"] },
    { name = "Golden Apple", rarity = "Rare", color = RARITY_COLORS["Rare"] },

    -- Epic
    { name = "Sakura", rarity = "Epic", color = RARITY_COLORS["Epic"] },
    { name = "Lotus", rarity = "Epic", color = RARITY_COLORS["Epic"] },
    { name = "Cactus", rarity = "Epic", color = RARITY_COLORS["Epic"] },
    { name = "Poison Ivy", rarity = "Epic", color = RARITY_COLORS["Epic"] },
    { name = "Moon Flower", rarity = "Epic", color = RARITY_COLORS["Epic"] },
    { name = "Starfruit", rarity = "Epic", color = RARITY_COLORS["Epic"] },
    { name = "Frost Berry", rarity = "Epic", color = RARITY_COLORS["Epic"] },

    -- Legendary
    { name = "Dragonfruit", rarity = "Legendary", color = RARITY_COLORS["Legendary"] },
    { name = "Thunder Tree", rarity = "Legendary", color = RARITY_COLORS["Legendary"] },
    { name = "Electric Cactus", rarity = "Legendary", color = RARITY_COLORS["Legendary"] },
    { name = "Sun God Flower", rarity = "Legendary", color = RARITY_COLORS["Legendary"] },
    { name = "Void Root", rarity = "Legendary", color = RARITY_COLORS["Legendary"] },
    { name = "Infernal Pepper", rarity = "Legendary", color = RARITY_COLORS["Legendary"] },

    -- Mythic
    { name = "Phoenix Flower", rarity = "Mythic", color = RARITY_COLORS["Mythic"] },
    { name = "Astral Blossom", rarity = "Mythic", color = RARITY_COLORS["Mythic"] },
    { name = "Celestial Tree", rarity = "Mythic", color = RARITY_COLORS["Mythic"] },
    { name = "Chrono Vine", rarity = "Mythic", color = RARITY_COLORS["Mythic"] },
    { name = "Galaxy Melon", rarity = "Mythic", color = RARITY_COLORS["Mythic"] },

    -- Secret / Godly
    { name = "Divine Lotus", rarity = "Secret", color = RARITY_COLORS["Secret"] },
    { name = "Godly Capybara Root", rarity = "Secret", color = RARITY_COLORS["Secret"] },
    { name = "Nebula Orchid", rarity = "Godly", color = RARITY_COLORS["Godly"] },
    { name = "Eternal World Tree", rarity = "Godly", color = RARITY_COLORS["Godly"] },
}

-- =================================================================
-- ⚙️ CONFIGURATION & STATE
-- =================================================================
AutoDeletePlant.Config = {
    Enabled = false,
    ScanInterval = 2.0,

    -- Rarity Filter
    DeleteCommon = true,
    DeleteUncommon = false,
    DeleteRare = false,
    DeleteEpic = false,
    DeleteLegendary = false,
    DeleteMythic = false,
    DeleteSecret = false,

    -- Safety Features
    ProtectEquipped = true,
    AutoEquipBestFirst = true,
    CleanPlotPots = true,

    -- Custom Whitelist (Tanaman yang TIDAK BOLEH dihapus)
    Whitelist = {
        "dragonfruit", "watermelon", "pumpkin", "sakura", "thunder",
        "void", "phoenix", "celestial", "astral", "divine", "godly", "mythic", "legendary"
    },

    -- Custom Blacklist (Tanaman yang SELALU dihapus)
    Blacklist = {
        "carrot", "basic carrot", "potato", "tomato", "corn",
        "cabbage", "wheat", "beetroot", "onion", "lettuce"
    },

    -- Selected specific plants for deletion
    SelectedPlants = {
        ["carrot"] = true,
        ["basic carrot"] = true,
        ["potato"] = true,
        ["tomato"] = true,
        ["corn"] = true,
        ["wheat"] = true,
        ["cabbage"] = true,
        ["onion"] = true,
        ["beetroot"] = true,
        ["lettuce"] = true,
    }
}

local isRunning = false
local deleteThread = nil
local totalDeletedCount = 0
local totalScannedCount = 0
local liveScannedPlantsMap = {}

-- =================================================================
-- 🛠️ HELPER FUNCTIONS
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

    if typeof(firesignal) == "function" then
        if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
        if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
        if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
    end

    if typeof(getconnections) == "function" then
        for _, eventName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "TouchTap"}) do
            pcall(function()
                if btn[eventName] then
                    for _, conn in ipairs(getconnections(btn[eventName])) do
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
        task.wait(0.03)
        prompt:InputHoldEnd()
    end)

    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.03)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)

    return true
end

local function handleConfirmPopup(maxWait)
    local waitTime = maxWait or 1.2
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
                                            task.wait(0.08)
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
            task.wait(0.1)
            return true
        end
        task.wait(0.08)
    end
    return false
end

-- =================================================================
-- 🏡 AKURAT: DETEKSI PLOT MILIK LOCALPLAYER
-- =================================================================

local function getPlotsFolder()
    local map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
    if map and map:FindFirstChild("Plots") then return map.Plots end
    if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots") then return workspace.Map.Plots end
    return workspace:FindFirstChild("Plots", true)
end

local function getMyPlot()
    local plots = getPlotsFolder()
    if not plots then return nil end

    local myName = LocalPlayer.Name
    local myUserId = LocalPlayer.UserId
    local myDisplayName = LocalPlayer.DisplayName

    -- 1. Cek attribute LocalPlayer
    local playerPlotAttr = LocalPlayer:GetAttribute("Plot") or LocalPlayer:GetAttribute("PlotId")
    if playerPlotAttr and plots:FindFirstChild(tostring(playerPlotAttr)) then
        return plots:FindFirstChild(tostring(playerPlotAttr))
    end

    -- 2. Scan plot attributes & values
    for _, plot in ipairs(plots:GetChildren()) do
        local attrOwner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerId") or plot:GetAttribute("OwnerName") or plot:GetAttribute("Player") or plot:GetAttribute("UserId")
        if attrOwner and (attrOwner == myName or attrOwner == myUserId or attrOwner == tostring(myUserId) or attrOwner == myDisplayName) then
            return plot
        end

        local ownerVal = plot:FindFirstChild("Owner") or plot:FindFirstChild("Player") or plot:FindFirstChild("OwnerValue") or plot:FindFirstChild("ClaimedBy")
        if ownerVal then
            if ownerVal:IsA("ObjectValue") and (ownerVal.Value == LocalPlayer or ownerVal.Value == LocalPlayer.Character) then
                return plot
            elseif (ownerVal.Value == myName or ownerVal.Value == myUserId or ownerVal.Value == tostring(myUserId) or ownerVal.Value == myDisplayName) then
                return plot
            end
        end

        if plot.Name == myName or plot.Name == tostring(myUserId) then
            return plot
        end

        for _, desc in ipairs(plot:GetDescendants()) do
            if desc:IsA("TextLabel") and (desc.Text == myName or desc.Text:find(myName) or (myDisplayName ~= "" and desc.Text:find(myDisplayName))) then
                return plot
            end
        end
    end

    return plots:FindFirstChild("1") or plots:GetChildren()[1]
end

-- =================================================================
-- 🔍 IN-GAME FULL PLANT SCANNER (LIVE REPLICATED STORAGE & UI SCAN)
-- =================================================================

function AutoDeletePlant.ScanAllInGamePlants()
    local foundPlants = {}
    local addedMap = {}

    local function addPlant(name, rarity)
        if not name or type(name) ~= "string" then return end
        local cleanName = name:gsub("^%s*(.-)%s*$", "%1")
        if cleanName == "" or #cleanName < 2 then return end
        local key = cleanName:lower()

        -- Filter nama non-tanaman
        if key:find("button") or key:find("frame") or key:find("layout") or key:find("corner") or key:find("stroke") or key:find("gradient") or key:find("template") or key:find("server") or key == "client" then
            return
        end

        if not addedMap[key] then
            addedMap[key] = true
            local cleanRarity = rarity or "Common"
            if cleanRarity == "" then cleanRarity = "Common" end
            local rColor = RARITY_COLORS[cleanRarity] or RARITY_COLORS["Common"]

            table.insert(foundPlants, {
                name = cleanName,
                rarity = cleanRarity,
                color = rColor
            })
            liveScannedPlantsMap[key] = {
                name = cleanName,
                rarity = cleanRarity
            }
        end
    end

    -- 1. Scan Database Bawaan
    for _, p in ipairs(INGAME_PLANT_DATABASE) do
        addPlant(p.name, p.rarity)
    end

    -- 2. Scan ReplicatedStorage (Folders, Models, Configs)
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            local oName = obj.Name:lower()
            if oName:find("plant") or oName:find("crop") or oName:find("seed") then
                for _, child in ipairs(obj:GetChildren()) do
                    if child:IsA("Model") or child:IsA("Folder") or child:IsA("Configuration") or child:IsA("ValueBase") then
                        local r = child:GetAttribute("Rarity") or child:GetAttribute("Tier") or (child:FindFirstChild("Rarity") and child.Rarity.Value) or "Common"
                        addPlant(child.Name, tostring(r))
                    end
                end
            end
        end
    end)

    -- 3. Scan Workspace (Map PottedPlants & Plots)
    pcall(function()
        local map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") or workspace:FindFirstChild("Map") or workspace
        local pottedPlants = map:FindFirstChild("PottedPlants", true)
        if pottedPlants then
            for _, p in ipairs(pottedPlants:GetDescendants()) do
                if p:IsA("Model") and not p.Name:lower():find("server") and not p.Name:lower():find("pot") then
                    local r = p:GetAttribute("Rarity") or "Common"
                    addPlant(p.Name, tostring(r))
                end
            end
        end
    end)

    -- 4. Scan PlayerGui MainGui (Inventory / Plants / Index Frame)
    pcall(function()
        local mainGui = getMainGui()
        if mainGui then
            for _, desc in ipairs(mainGui:GetDescendants()) do
                if desc:IsA("Frame") or desc:IsA("ScrollingFrame") then
                    local dName = desc.Name:lower()
                    if dName:find("plant") or dName:find("inventory") or dName:find("index") or dName:find("codex") or dName:find("almanac") then
                        for _, item in ipairs(desc:GetChildren()) do
                            if item:IsA("GuiObject") and not item.Name:lower():find("template") and not item.Name:lower():find("layout") then
                                local pName = item.Name
                                local pRarity = "Common"
                                for _, child in ipairs(item:GetDescendants()) do
                                    if child:IsA("TextLabel") then
                                        local txt = child.Text or ""
                                        local cName = child.Name:lower()
                                        if cName:find("name") or cName == "title" then
                                            if txt ~= "" then pName = txt end
                                        elseif cName:find("rarity") or cName:find("tier") then
                                            if txt ~= "" then pRarity = txt end
                                        end
                                    end
                                end
                                addPlant(pName, pRarity)
                            end
                        end
                    end
                end
            end
        end
    end)

    print(string.format("🔍 [Ritod Hub] Sukses Scan %d Tanaman In-Game!", #foundPlants))
    return foundPlants
end

-- =================================================================
-- 🔍 PLANT EVALUATION ENGINE
-- =================================================================

function AutoDeletePlant.ShouldDelete(plantName, plantRarity, isEquipped)
    if not plantName or plantName == "" then return false end
    local name = tostring(plantName):lower():gsub("^%s*(.-)%s*$", "%1")
    local rarity = tostring(plantRarity or ""):lower():gsub("^%s*(.-)%s*$", "%1")

    -- 1. Proteksi tanaman yang terpasang / di-equip
    if AutoDeletePlant.Config.ProtectEquipped and isEquipped then
        return false
    end

    -- 2. Whitelist: Tidak boleh dihapus
    for _, safe in ipairs(AutoDeletePlant.Config.Whitelist) do
        local safeLower = safe:lower()
        if name:find(safeLower) or (rarity ~= "" and rarity:find(safeLower)) then
            return false
        end
    end

    -- 3. Specific Selected Plants Checklist
    if AutoDeletePlant.Config.SelectedPlants[name] then
        return true
    end
    for pName, state in pairs(AutoDeletePlant.Config.SelectedPlants) do
        if state and (name == pName:lower() or name:find(pName:lower())) then
            return true
        end
    end

    -- 4. Blacklist: Selalu dihapus
    for _, target in ipairs(AutoDeletePlant.Config.Blacklist) do
        if name:find(target:lower()) then
            return true
        end
    end

    -- 5. Rarity Toggles
    if AutoDeletePlant.Config.DeleteCommon then
        if rarity == "common" or rarity:find("common") or rarity == "biasa" or rarity == "1" then return true end
        if name:find("carrot") or name:find("tomato") or name:find("potato") or name:find("corn") or name:find("cabbage") or name:find("wheat") or name:find("onion") or name:find("lettuce") or name:find("beetroot") or name:find("radish") or name:find("pea") or name:find("cucumber") then
            return true
        end
    end

    if AutoDeletePlant.Config.DeleteUncommon and (rarity == "uncommon" or rarity:find("uncommon") or rarity == "2") then return true end
    if AutoDeletePlant.Config.DeleteRare and (rarity == "rare" or rarity:find("rare") or rarity == "3") then return true end
    if AutoDeletePlant.Config.DeleteEpic and (rarity == "epic" or rarity:find("epic") or rarity == "4") then return true end
    if AutoDeletePlant.Config.DeleteLegendary and (rarity == "legendary" or rarity:find("legendary") or rarity == "5") then return true end
    if AutoDeletePlant.Config.DeleteMythic and (rarity == "mythic" or rarity:find("mythic") or rarity == "6") then return true end
    if AutoDeletePlant.Config.DeleteSecret and (rarity == "secret" or rarity:find("secret") or rarity:find("god")) then return true end

    return false
end

-- =================================================================
-- ⚡ TRIPLE-ENGINE PLANT CLEANER
-- =================================================================

-- ENGINE 1: Remote Execution
local function executeRemotesForPlant(targetNameOrId)
    local candidateRemotes = {
        "DeletePlant", "DeletePlants", "SellPlant", "SellPlants",
        "RemovePlant", "RemovePlants", "TrashPlant", "TrashPlants",
        "DestroyPlant", "DiscardPlant", "ClearPlant", "SellAllPlants",
        "QuickSell", "DeleteUnit", "SellUnit", "SellItem", "DeleteItem",
        "SellCrop", "DeleteCrop", "TrashItem"
    }

    for _, rName in ipairs(candidateRemotes) do
        pcall(function()
            if targetNameOrId then
                callRemote(rName, targetNameOrId)
                callRemote(rName, { targetNameOrId })
                callRemote(rName, 1, targetNameOrId)
                callRemote(rName, targetNameOrId, 1)
            else
                callRemote(rName)
            end
        end)
    end
end

-- ENGINE 2: Inventory UI Scanner
local function scanInventoryUI()
    local mainGui = getMainGui()
    if not mainGui then return 0 end

    local deletedThisRound = 0

    pcall(function()
        local frames = mainGui:FindFirstChild("Root") and mainGui.Root:FindFirstChild("Frames") or mainGui
        local plantContainers = {}

        for _, desc in ipairs(frames:GetDescendants()) do
            if desc:IsA("ScrollingFrame") or desc:IsA("Frame") then
                local dName = desc.Name:lower()
                if dName:find("plant") or dName:find("inventory") or dName:find("storage") or dName:find("bag") or dName:find("item") then
                    table.insert(plantContainers, desc)
                end
            end
        end

        for _, container in ipairs(plantContainers) do
            for _, itemCard in ipairs(container:GetChildren()) do
                if itemCard:IsA("GuiObject") and itemCard.Visible then
                    totalScannedCount += 1
                    local itemName = itemCard.Name
                    local itemRarity = ""
                    local isEquipped = false

                    for _, child in ipairs(itemCard:GetDescendants()) do
                        local cName = child.Name:lower()
                        if child:IsA("TextLabel") then
                            local txt = child.Text or ""
                            if cName:find("name") or cName == "title" or cName == "itemname" then
                                if txt ~= "" then itemName = txt end
                            elseif cName:find("rarity") or cName:find("tier") then
                                itemRarity = txt
                            elseif txt:lower():find("equipped") or txt:lower():find("in use") or txt:lower():find("terpasang") then
                                isEquipped = true
                            end
                        end
                        if cName:find("equipped") or cName:find("checkmark") or cName:find("active") then
                            if child.Visible then isEquipped = true end
                        end
                    end

                    if AutoDeletePlant.ShouldDelete(itemName, itemRarity, isEquipped) then
                        local deleteBtn = nil
                        for _, btn in ipairs(itemCard:GetDescendants()) do
                            if btn:IsA("GuiButton") then
                                local bName = btn.Name:lower()
                                local bText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                if bName:find("trash") or bName:find("del") or bName:find("sell") or bName:find("remove")
                                    or bText:find("trash") or bText:find("del") or bText:find("sell") or bText:find("hapus") or bText:find("jual") then
                                    deleteBtn = btn
                                    break
                                end
                            end
                        end

                        if deleteBtn then
                            clickButton(deleteBtn)
                            task.wait(0.04)
                            handleConfirmPopup(0.6)
                            deletedThisRound += 1
                            totalDeletedCount += 1
                        else
                            clickButton(itemCard)
                            task.wait(0.05)
                            for _, obj in ipairs(mainGui:GetDescendants()) do
                                if obj:IsA("GuiButton") and obj.Visible then
                                    local bName = obj.Name:lower()
                                    local bText = (obj:IsA("TextButton") and obj.Text or ""):lower()
                                    if bName:find("trash") or bName:find("delete") or bName:find("sell") or bName:find("remove")
                                        or bText:find("trash") or bText:find("delete") or bText:find("sell") or bText:find("hapus") or bText:find("jual") then
                                        clickButton(obj)
                                        task.wait(0.04)
                                        handleConfirmPopup(0.6)
                                        deletedThisRound += 1
                                        totalDeletedCount += 1
                                        break
                                    end
                                end
                            end
                        end

                        executeRemotesForPlant(itemName)
                        task.wait(0.05)
                    end
                end
            end
        end
    end)

    return deletedThisRound
end

-- ENGINE 3: Plot Pot Shovel Scanner
local function scanPlotPots()
    if not AutoDeletePlant.Config.CleanPlotPots then return 0 end
    local myPlot = getMyPlot()
    if not myPlot then return 0 end

    local cleanedCount = 0
    pcall(function()
        local pottedPlants = myPlot:FindFirstChild("PottedPlants") or myPlot:FindFirstChild("Pots") or myPlot:FindFirstChild("TowerArea")
        if not pottedPlants then return end

        for _, pot in ipairs(pottedPlants:GetChildren()) do
            for _, prompt in ipairs(pot:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                    local actText = (prompt.ActionText or ""):lower()
                    local objText = (prompt.ObjectText or ""):lower()
                    local nameText = (prompt.Name or ""):lower()

                    if actText:find("shovel") or actText:find("remove") or actText:find("delete") or actText:find("clear") or actText:find("sell")
                        or objText:find("shovel") or objText:find("remove") or objText:find("delete")
                        or nameText:find("shovel") or nameText:find("remove") or nameText:find("delete") then

                        local potPlantName = pot.Name:lower()
                        for _, child in ipairs(pot:GetChildren()) do
                            if child:IsA("Model") or child:IsA("Folder") then
                                potPlantName = child.Name:lower()
                            end
                        end

                        if AutoDeletePlant.ShouldDelete(potPlantName, "common", false) then
                            triggerSinglePromptInstant(prompt)
                            task.wait(0.06)
                            handleConfirmPopup(0.6)
                            cleanedCount += 1
                            totalDeletedCount += 1
                        end
                    end
                end
            end
        end
    end)

    return cleanedCount
end

-- =================================================================
-- 🔄 SINGLE CYCLE RUNNER
-- =================================================================

function AutoDeletePlant.RunSingleCycle()
    pcall(function()
        -- 1. Pastikan tanaman terbaik terpasang aman jika diaktifkan
        if AutoDeletePlant.Config.AutoEquipBestFirst then
            callRemote("EquipBestPlants")
            task.wait(0.15)
        end

        -- 2. Bersihkan via Inventory UI
        scanInventoryUI()

        -- 3. Bersihkan via Remote Blacklist & Selected Plants
        for pName, state in pairs(AutoDeletePlant.Config.SelectedPlants) do
            if state then
                executeRemotesForPlant(pName)
            end
        end
        for _, blackName in ipairs(AutoDeletePlant.Config.Blacklist) do
            executeRemotesForPlant(blackName)
        end

        -- 4. Bersihkan pot plot jika ada tanaman sampah
        scanPlotPots()
    end)
end

-- =================================================================
-- 🎨 ULTRA HD GUI BUILDER (SAME AS ROLL ANIME PRO)
-- =================================================================

local function buildUltraHDGui()
    local parentGui
    if typeof(gethui) == "function" then
        parentGui = gethui()
    elseif run_secure_function or getexecutorname then
        parentGui = CoreGui
    else
        parentGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui
    end

    if parentGui:FindFirstChild("RitodHubAutoDelete") then
        parentGui:FindFirstChild("RitodHubAutoDelete"):Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RitodHubAutoDelete"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parentGui

    -- ===================== DRAGGABLE HANDLER =====================
    local function makeDraggable(frame, dragHandle, onClick)
        dragHandle = dragHandle or frame
        local dragging = false
        local dragInput, dragStart, startPos
        local hasMoved = false

        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                hasMoved = false
                dragStart = input.Position
                startPos = frame.Position

                local endConn
                endConn = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        endConn:Disconnect()
                        if not hasMoved and onClick then onClick() end
                    end
                end)
            end
        end)

        dragHandle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                if delta.Magnitude > 6 then hasMoved = true end
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- ===================== NOTIFICATION SYSTEM =====================
    local notifHolder = Instance.new("Frame")
    notifHolder.Name = "NotifHolder"
    notifHolder.AnchorPoint = Vector2.new(1, 1)
    notifHolder.Position = UDim2.new(1, -24, 1, -24)
    notifHolder.Size = UDim2.new(0, 300, 1, -48)
    notifHolder.BackgroundTransparency = 1
    notifHolder.ZIndex = 200
    notifHolder.Parent = screenGui

    local notifList = Instance.new("UIListLayout")
    notifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifList.Padding = UDim.new(0, 10)
    notifList.Parent = notifHolder

    local function Notify(title, desc, duration)
        duration = duration or 3
        local n = Instance.new("Frame")
        n.Size = UDim2.new(1, 0, 0, 64)
        n.BackgroundColor3 = Color3.fromRGB(18, 14, 24)
        n.BackgroundTransparency = 0.1
        n.BorderSizePixel = 0
        n.Position = UDim2.new(1, 100, 0, 0)
        n.ZIndex = 201
        n.Parent = notifHolder

        local nCorner = Instance.new("UICorner")
        nCorner.CornerRadius = UDim.new(0, 12)
        nCorner.Parent = n

        local nStroke = Instance.new("UIStroke")
        nStroke.Thickness = 1.4
        nStroke.Color = Color3.fromRGB(185, 90, 255)
        nStroke.Parent = n

        local nGlow = Instance.new("Frame")
        nGlow.Size = UDim2.new(0, 4, 1, -16)
        nGlow.Position = UDim2.new(0, 8, 0, 8)
        nGlow.BackgroundColor3 = Color3.fromRGB(185, 90, 255)
        nGlow.BorderSizePixel = 0
        nGlow.ZIndex = 202
        nGlow.Parent = n

        local ngCorner = Instance.new("UICorner")
        ngCorner.CornerRadius = UDim.new(1, 0)
        ngCorner.Parent = nGlow

        local nTitle = Instance.new("TextLabel")
        nTitle.Position = UDim2.new(0, 22, 0, 10)
        nTitle.Size = UDim2.new(1, -30, 0, 18)
        nTitle.BackgroundTransparency = 1
        nTitle.Text = title
        nTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        nTitle.TextSize = 13
        nTitle.Font = Enum.Font.GothamBold
        nTitle.TextXAlignment = Enum.TextXAlignment.Left
        nTitle.ZIndex = 202
        nTitle.Parent = n

        local nDesc = Instance.new("TextLabel")
        nDesc.Position = UDim2.new(0, 22, 0, 30)
        nDesc.Size = UDim2.new(1, -30, 0, 22)
        nDesc.BackgroundTransparency = 1
        nDesc.Text = desc
        nDesc.TextColor3 = Color3.fromRGB(190, 175, 205)
        nDesc.TextSize = 11
        nDesc.Font = Enum.Font.GothamMedium
        nDesc.TextXAlignment = Enum.TextXAlignment.Left
        nDesc.TextWrapped = true
        nDesc.ZIndex = 202
        nDesc.Parent = n

        TweenService:Create(n, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

        task.delay(duration, function()
            if n and n.Parent then
                local out = TweenService:Create(n, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 150, 0, 0)})
                out:Play()
                out.Completed:Connect(function() n:Destroy() end)
            end
        end)
    end

    -- ==============================================================================
    -- 🖥️ MAIN HUB WINDOW (680x440)
    -- ==============================================================================
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainHub"
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 680, 0, 440)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.ZIndex = 10
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 16)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Thickness = 1.6
    mainStroke.Color = Color3.fromRGB(165, 85, 255)
    mainStroke.Transparency = 0.4
    mainStroke.Parent = mainFrame

    -- TopBar
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 50)
    topBar.BackgroundColor3 = Color3.fromRGB(22, 17, 30)
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 11
    topBar.Parent = mainFrame

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 16)
    topCorner.Parent = topBar

    local topFix = Instance.new("Frame")
    topFix.Size = UDim2.new(1, 0, 0, 16)
    topFix.Position = UDim2.new(0, 0, 1, -16)
    topFix.BackgroundColor3 = Color3.fromRGB(22, 17, 30)
    topFix.BorderSizePixel = 0
    topFix.ZIndex = 11
    topFix.Parent = topBar

    makeDraggable(mainFrame, topBar)

    local hubTitle = Instance.new("TextLabel")
    hubTitle.Position = UDim2.new(0, 18, 0, 0)
    hubTitle.Size = UDim2.new(0, 360, 1, 0)
    hubTitle.BackgroundTransparency = 1
    hubTitle.Text = "⚡ RITOD HUB <font color='#c47aff'>AUTO DELETE PLANTS</font>"
    hubTitle.RichText = true
    hubTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    hubTitle.TextSize = 15
    hubTitle.Font = Enum.Font.GothamBlack
    hubTitle.TextXAlignment = Enum.TextXAlignment.Left
    hubTitle.ZIndex = 12
    hubTitle.Parent = topBar

    local statsLabel = Instance.new("TextLabel")
    statsLabel.AnchorPoint = Vector2.new(1, 0.5)
    statsLabel.Position = UDim2.new(1, -95, 0.5, 0)
    statsLabel.Size = UDim2.new(0, 160, 0, 24)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "FPS: 60  |  PING: 35ms"
    statsLabel.TextColor3 = Color3.fromRGB(160, 145, 175)
    statsLabel.TextSize = 11
    statsLabel.Font = Enum.Font.GothamMedium
    statsLabel.TextXAlignment = Enum.TextXAlignment.Right
    statsLabel.ZIndex = 12
    statsLabel.Parent = topBar

    task.spawn(function()
        local lastTime = tick()
        local frameCount = 0
        RunService.RenderStepped:Connect(function()
            frameCount = frameCount + 1
            local curTime = tick()
            if curTime - lastTime >= 1 then
                local fps = math.floor(frameCount / (curTime - lastTime))
                local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                statsLabel.Text = string.format("FPS: %d  |  PING: %dms", fps, ping)
                frameCount = 0
                lastTime = curTime
            end
        end)
    end)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -12, 0.5, 0)
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.BackgroundColor3 = Color3.fromRGB(48, 22, 34)
    closeBtn.AutoButtonColor = false
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 110, 130)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.ZIndex = 25
    closeBtn.Active = true
    closeBtn.Parent = topBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    local minBtn = Instance.new("TextButton")
    minBtn.Name = "MinBtn"
    minBtn.AnchorPoint = Vector2.new(1, 0.5)
    minBtn.Position = UDim2.new(1, -50, 0.5, 0)
    minBtn.Size = UDim2.new(0, 32, 0, 32)
    minBtn.BackgroundColor3 = Color3.fromRGB(32, 26, 42)
    minBtn.AutoButtonColor = false
    minBtn.Text = "-"
    minBtn.TextColor3 = Color3.fromRGB(180, 160, 205)
    minBtn.TextSize = 18
    minBtn.Font = Enum.Font.GothamBlack
    minBtn.ZIndex = 25
    minBtn.Active = true
    minBtn.Parent = topBar

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 8)
    minCorner.Parent = minBtn

    -- Floating Widget
    local floatWidget = Instance.new("Frame")
    floatWidget.Name = "FloatWidget"
    floatWidget.AnchorPoint = Vector2.new(0, 0.5)
    floatWidget.Position = UDim2.new(0, 24, 0.5, 0)
    floatWidget.Size = UDim2.new(0, 60, 0, 60)
    floatWidget.BackgroundColor3 = Color3.fromRGB(20, 14, 28)
    floatWidget.BorderSizePixel = 0
    floatWidget.ZIndex = 100
    floatWidget.Active = true
    floatWidget.Parent = screenGui

    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 18)
    floatCorner.Parent = floatWidget

    local floatStroke = Instance.new("UIStroke")
    floatStroke.Thickness = 2.5
    floatStroke.Color = Color3.fromRGB(190, 90, 255)
    floatStroke.Transparency = 0.2
    floatStroke.Parent = floatWidget

    local strokeGrad = Instance.new("UIGradient")
    strokeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 160)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 90, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 210, 255)),
    })
    strokeGrad.Rotation = 45
    strokeGrad.Parent = floatStroke

    local floatIcon = Instance.new("TextLabel")
    floatIcon.Size = UDim2.new(1, 0, 1, 0)
    floatIcon.BackgroundTransparency = 1
    floatIcon.Text = "🗑️"
    floatIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    floatIcon.TextSize = 22
    floatIcon.Font = Enum.Font.GothamBlack
    floatIcon.ZIndex = 101
    floatIcon.Parent = floatWidget

    local statusDot = Instance.new("Frame")
    statusDot.AnchorPoint = Vector2.new(1, 0)
    statusDot.Position = UDim2.new(1, -6, 0, 6)
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.BackgroundColor3 = Color3.fromRGB(70, 255, 140)
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 102
    statusDot.Parent = floatWidget

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(1, 0)
    statusCorner.Parent = statusDot

    local isHubVisible = true
    local lastSavedPosition = mainFrame.Position

    local function toggleHub()
        isHubVisible = not isHubVisible
        if isHubVisible then
            mainFrame.Visible = true
            mainFrame.Position = UDim2.new(lastSavedPosition.X.Scale, lastSavedPosition.X.Offset, lastSavedPosition.Y.Scale, lastSavedPosition.Y.Offset + 30)
            TweenService:Create(mainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = lastSavedPosition
            }):Play()
        else
            lastSavedPosition = mainFrame.Position
            local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(lastSavedPosition.X.Scale, lastSavedPosition.X.Offset, lastSavedPosition.Y.Scale, lastSavedPosition.Y.Offset + 30)
            })
            closeTween:Play()
            closeTween.Completed:Connect(function()
                if not isHubVisible then mainFrame.Visible = false end
            end)
        end
    end

    makeDraggable(floatWidget, floatWidget, function() toggleHub() end)
    minBtn.Activated:Connect(function() toggleHub() end)
    closeBtn.Activated:Connect(function() toggleHub() end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
            toggleHub()
        end
    end)

    -- Sidebar & Content Area
    local sideBar = Instance.new("Frame")
    sideBar.Name = "SideBar"
    sideBar.Position = UDim2.new(0, 0, 0, 50)
    sideBar.Size = UDim2.new(0, 160, 1, -50)
    sideBar.BackgroundColor3 = Color3.fromRGB(18, 14, 25)
    sideBar.BorderSizePixel = 0
    sideBar.ZIndex = 11
    sideBar.Parent = mainFrame

    local tabList = Instance.new("UIListLayout")
    tabList.Padding = UDim.new(0, 6)
    tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabList.SortOrder = Enum.SortOrder.LayoutOrder
    tabList.Parent = sideBar

    local sidePadding = Instance.new("UIPadding")
    sidePadding.PaddingTop = UDim.new(0, 14)
    sidePadding.PaddingLeft = UDim.new(0, 10)
    sidePadding.PaddingRight = UDim.new(0, 10)
    sidePadding.Parent = sideBar

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Position = UDim2.new(0, 160, 0, 50)
    contentArea.Size = UDim2.new(1, -160, 1, -50)
    contentArea.BackgroundTransparency = 1
    contentArea.ZIndex = 11
    contentArea.Parent = mainFrame

    -- ===================== TAB BUILDER =====================
    local tabs = {}
    local activeTab = nil

    local function CreateTab(name, icon)
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = name .. "Tab"
        tabBtn.Size = UDim2.new(1, 0, 0, 38)
        tabBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 40)
        tabBtn.BackgroundTransparency = 1
        tabBtn.AutoButtonColor = false
        tabBtn.Text = (icon and (icon .. "  ") or "") .. name
        tabBtn.TextColor3 = Color3.fromRGB(160, 140, 175)
        tabBtn.TextSize = 12
        tabBtn.Font = Enum.Font.GothamMedium
        tabBtn.TextXAlignment = Enum.TextXAlignment.Left
        tabBtn.ZIndex = 12
        tabBtn.Parent = sideBar

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 10)
        tabCorner.Parent = tabBtn

        local tPad = Instance.new("UIPadding")
        tPad.PaddingLeft = UDim.new(0, 12)
        tPad.Parent = tabBtn

        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 4, 0, 20)
        indicator.AnchorPoint = Vector2.new(0, 0.5)
        indicator.Position = UDim2.new(0, -8, 0.5, 0)
        indicator.BackgroundColor3 = Color3.fromRGB(190, 90, 255)
        indicator.BackgroundTransparency = 1
        indicator.BorderSizePixel = 0
        indicator.ZIndex = 13
        indicator.Parent = tabBtn

        local indCorner = Instance.new("UICorner")
        indCorner.CornerRadius = UDim.new(1, 0)
        indCorner.Parent = indicator

        local page = Instance.new("ScrollingFrame")
        page.Name = name .. "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Color3.fromRGB(180, 90, 255)
        page.Visible = false
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.ZIndex = 12
        page.Parent = contentArea

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 8)
        pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page

        local pagePad = Instance.new("UIPadding")
        pagePad.PaddingTop = UDim.new(0, 12)
        pagePad.PaddingLeft = UDim.new(0, 14)
        pagePad.PaddingRight = UDim.new(0, 14)
        pagePad.PaddingBottom = UDim.new(0, 14)
        pagePad.Parent = page

        local function selectTab()
            for _, t in pairs(tabs) do
                TweenService:Create(t.btn, TweenInfo.new(0.2), {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(160, 140, 175)}):Play()
                TweenService:Create(t.indicator, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                t.page.Visible = false
            end
            activeTab = name
            TweenService:Create(tabBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundColor3 = Color3.fromRGB(150, 65, 240)}):Play()
            TweenService:Create(indicator, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
            page.Visible = true
        end

        tabBtn.MouseButton1Click:Connect(selectTab)
        tabs[name] = {btn = tabBtn, page = page, indicator = indicator}

        if not activeTab then selectTab() end

        local elements = { Page = page }

        function elements:AddSection(title)
            local sec = Instance.new("Frame")
            sec.Size = UDim2.new(1, 0, 0, 24)
            sec.BackgroundTransparency = 1
            sec.ZIndex = 13
            sec.Parent = page

            local sLabel = Instance.new("TextLabel")
            sLabel.Size = UDim2.new(1, 0, 1, 0)
            sLabel.BackgroundTransparency = 1
            sLabel.Text = string.upper(title)
            sLabel.TextColor3 = Color3.fromRGB(180, 120, 255)
            sLabel.TextSize = 11
            sLabel.Font = Enum.Font.GothamBold
            sLabel.TextXAlignment = Enum.TextXAlignment.Left
            sLabel.ZIndex = 13
            sLabel.Parent = sec
            return sec
        end

        function elements:AddButton(text, callback)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 38)
            btn.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
            btn.AutoButtonColor = false
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(235, 225, 245)
            btn.TextSize = 12
            btn.Font = Enum.Font.GothamBold
            btn.ZIndex = 14
            btn.Parent = page

            local bCorner = Instance.new("UICorner")
            bCorner.CornerRadius = UDim.new(0, 8)
            bCorner.Parent = btn

            local bStroke = Instance.new("UIStroke")
            bStroke.Thickness = 1
            bStroke.Color = Color3.fromRGB(70, 50, 85)
            bStroke.Parent = btn

            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(48, 32, 65)}):Play()
                TweenService:Create(bStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(180, 90, 255)}):Play()
            end)
            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26, 20, 34)}):Play()
                TweenService:Create(bStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(70, 50, 85)}):Play()
            end)
            btn.MouseButton1Click:Connect(function()
                if callback then callback() end
            end)
            return btn
        end

        function elements:AddToggle(text, default, callback)
            local state = default or false
            local toggleFrame = Instance.new("Frame")
            toggleFrame.Size = UDim2.new(1, 0, 0, 40)
            toggleFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
            toggleFrame.BorderSizePixel = 0
            toggleFrame.ZIndex = 14
            toggleFrame.Parent = page

            local tCorner = Instance.new("UICorner")
            tCorner.CornerRadius = UDim.new(0, 8)
            tCorner.Parent = toggleFrame

            local tLabel = Instance.new("TextLabel")
            tLabel.Position = UDim2.new(0, 12, 0, 0)
            tLabel.Size = UDim2.new(1, -70, 1, 0)
            tLabel.BackgroundTransparency = 1
            tLabel.Text = text
            tLabel.TextColor3 = Color3.fromRGB(235, 225, 245)
            tLabel.TextSize = 12
            tLabel.Font = Enum.Font.GothamMedium
            tLabel.TextXAlignment = Enum.TextXAlignment.Left
            tLabel.ZIndex = 15
            tLabel.Parent = toggleFrame

            local switch = Instance.new("TextButton")
            switch.AnchorPoint = Vector2.new(1, 0.5)
            switch.Position = UDim2.new(1, -10, 0.5, 0)
            switch.Size = UDim2.new(0, 44, 0, 22)
            switch.BackgroundColor3 = state and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(50, 38, 60)
            switch.AutoButtonColor = false
            switch.Text = ""
            switch.ZIndex = 15
            switch.Parent = toggleFrame

            local sCorner = Instance.new("UICorner")
            sCorner.CornerRadius = UDim.new(1, 0)
            sCorner.Parent = switch

            local knob = Instance.new("Frame")
            knob.AnchorPoint = Vector2.new(0, 0.5)
            knob.Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knob.BorderSizePixel = 0
            knob.ZIndex = 16
            knob.Parent = switch

            local kCorner = Instance.new("UICorner")
            kCorner.CornerRadius = UDim.new(1, 0)
            kCorner.Parent = knob

            local function updateToggle(fireCallback)
                if state then
                    TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(175, 75, 255)}):Play()
                    TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(1, -19, 0.5, 0)}):Play()
                else
                    TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 38, 60)}):Play()
                    TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.5, 0)}):Play()
                end
                if fireCallback and callback then callback(state) end
            end

            switch.MouseButton1Click:Connect(function()
                state = not state
                updateToggle(true)
            end)

            return {
                Set = function(self, val, fireCallback)
                    state = val
                    updateToggle(fireCallback)
                end,
                Get = function(self) return state end
            }
        end

        function elements:AddStatusCard()
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 68)
            card.BackgroundColor3 = Color3.fromRGB(24, 18, 32)
            card.BorderSizePixel = 0
            card.ZIndex = 14
            card.Parent = page

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 10)
            cCorner.Parent = card

            local cStroke = Instance.new("UIStroke")
            cStroke.Thickness = 1
            cStroke.Color = Color3.fromRGB(140, 70, 220)
            cStroke.Transparency = 0.5
            cStroke.Parent = card

            local statusLbl = Instance.new("TextLabel")
            statusLbl.Position = UDim2.new(0, 12, 0, 8)
            statusLbl.Size = UDim2.new(1, -24, 0, 22)
            statusLbl.BackgroundTransparency = 1
            statusLbl.Text = "Status: ⚪ OFF (Idle)"
            statusLbl.TextColor3 = Color3.fromRGB(200, 185, 220)
            statusLbl.TextSize = 12
            statusLbl.Font = Enum.Font.GothamBold
            statusLbl.TextXAlignment = Enum.TextXAlignment.Left
            statusLbl.ZIndex = 15
            statusLbl.Parent = card

            local subInfo = Instance.new("TextLabel")
            subInfo.Position = UDim2.new(0, 12, 0, 34)
            subInfo.Size = UDim2.new(0.5, 0, 0, 22)
            subInfo.BackgroundTransparency = 1
            subInfo.Text = "🗑️ Terhapus: 0 unit"
            subInfo.TextColor3 = Color3.fromRGB(255, 110, 130)
            subInfo.TextSize = 11
            subInfo.Font = Enum.Font.GothamBold
            subInfo.TextXAlignment = Enum.TextXAlignment.Left
            subInfo.ZIndex = 15
            subInfo.Parent = card

            local scanInfo = Instance.new("TextLabel")
            scanInfo.Position = UDim2.new(0.5, 0, 0, 34)
            scanInfo.Size = UDim2.new(0.5, -12, 0, 22)
            scanInfo.BackgroundTransparency = 1
            scanInfo.Text = "🔍 Scan: 0 item"
            scanInfo.TextColor3 = Color3.fromRGB(0, 230, 140)
            scanInfo.TextSize = 11
            scanInfo.Font = Enum.Font.GothamBold
            scanInfo.TextXAlignment = Enum.TextXAlignment.Right
            scanInfo.ZIndex = 15
            scanInfo.Parent = card

            task.spawn(function()
                while card and card.Parent do
                    subInfo.Text = "🗑️ Terhapus: " .. tostring(totalDeletedCount) .. " item"
                    scanInfo.Text = "🔍 Scan: " .. tostring(totalScannedCount) .. " item"
                    task.wait(0.8)
                end
            end)

            return {
                SetStatus = function(self, text, color)
                    statusLbl.Text = text
                    if color then statusLbl.TextColor3 = color end
                end
            }
        end

        function elements:AddPlantCard(plantName, plantRarity, plantColor, onStateChanged)
            local pKey = plantName:lower()
            local card = Instance.new("Frame")
            card.Name = "PlantCard_" .. pKey
            card.Size = UDim2.new(1, 0, 0, 36)
            card.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
            card.BorderSizePixel = 0
            card.ZIndex = 14
            card.Parent = page

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 8)
            cCorner.Parent = card

            local isChecked = (AutoDeletePlant.Config.SelectedPlants[pKey] == true)

            local checkBtn = Instance.new("TextButton")
            checkBtn.Size = UDim2.new(0, 20, 0, 20)
            checkBtn.Position = UDim2.new(0, 8, 0.5, -10)
            checkBtn.BackgroundColor3 = isChecked and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
            checkBtn.Text = isChecked and "✓" or ""
            checkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            checkBtn.Font = Enum.Font.GothamBold
            checkBtn.TextSize = 12
            checkBtn.ZIndex = 15
            checkBtn.Parent = card

            local chkCorner = Instance.new("UICorner")
            chkCorner.CornerRadius = UDim.new(0, 4)
            chkCorner.Parent = checkBtn

            local badge = Instance.new("TextLabel")
            badge.Size = UDim2.new(0, 75, 0, 18)
            badge.Position = UDim2.new(0, 34, 0.5, -9)
            badge.BackgroundColor3 = plantColor or Color3.fromRGB(160, 160, 160)
            badge.BackgroundTransparency = 0.8
            badge.Text = plantRarity or "Common"
            badge.TextColor3 = plantColor or Color3.fromRGB(160, 160, 160)
            badge.Font = Enum.Font.GothamBold
            badge.TextSize = 10
            badge.ZIndex = 15
            badge.Parent = card

            local bCorner = Instance.new("UICorner")
            bCorner.CornerRadius = UDim.new(0, 4)
            bCorner.Parent = badge

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -125, 1, 0)
            nameLabel.Position = UDim2.new(0, 115, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = plantName
            nameLabel.TextColor3 = Color3.fromRGB(240, 235, 250)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 12
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.ZIndex = 15
            nameLabel.Parent = card

            local function toggle()
                local newState = not (AutoDeletePlant.Config.SelectedPlants[pKey] == true)
                AutoDeletePlant.Config.SelectedPlants[pKey] = newState and true or nil
                checkBtn.BackgroundColor3 = newState and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
                checkBtn.Text = newState and "✓" or ""
                if onStateChanged then onStateChanged(newState) end
            end

            checkBtn.MouseButton1Click:Connect(toggle)

            local fullClick = Instance.new("TextButton")
            fullClick.Size = UDim2.new(1, 0, 1, 0)
            fullClick.BackgroundTransparency = 1
            fullClick.Text = ""
            fullClick.ZIndex = 14
            fullClick.Parent = card
            fullClick.MouseButton1Click:Connect(toggle)

            return {
                SetChecked = function(self, val)
                    AutoDeletePlant.Config.SelectedPlants[pKey] = val and true or nil
                    checkBtn.BackgroundColor3 = val and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
                    checkBtn.Text = val and "✓" or ""
                end,
                Card = card
            }
        end

        function elements:AddInput(placeholder, callback)
            local inputFrame = Instance.new("Frame")
            inputFrame.Size = UDim2.new(1, 0, 0, 38)
            inputFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 34)
            inputFrame.BorderSizePixel = 0
            inputFrame.ZIndex = 14
            inputFrame.Parent = page

            local inCorner = Instance.new("UICorner")
            inCorner.CornerRadius = UDim.new(0, 8)
            inCorner.Parent = inputFrame

            local textBox = Instance.new("TextBox")
            textBox.Size = UDim2.new(1, -20, 1, 0)
            textBox.Position = UDim2.new(0, 10, 0, 0)
            textBox.BackgroundTransparency = 1
            textBox.PlaceholderText = placeholder or "Ketik nama tanaman..."
            textBox.PlaceholderColor3 = Color3.fromRGB(140, 120, 155)
            textBox.Text = ""
            textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            textBox.TextSize = 12
            textBox.Font = Enum.Font.GothamMedium
            textBox.TextXAlignment = Enum.TextXAlignment.Left
            textBox.ClearTextOnFocus = false
            textBox.ZIndex = 15
            textBox.Parent = inputFrame

            textBox.FocusLost:Connect(function(enterPressed)
                if callback then callback(textBox.Text) end
            end)

            return textBox
        end

        return elements
    end

    -- ==============================================================================
    -- 📑 PAGES & FEATURES SETUP
    -- ==============================================================================

    -- TAB 1: 🗑️ AUTO DELETE (MASTER CONTROLLER)
    local MainTab = CreateTab("Auto Delete", "🗑️")
    MainTab:AddSection("Live Delete Controller")
    local statusCard = MainTab:AddStatusCard()

    local masterToggleRef = nil
    masterToggleRef = MainTab:AddToggle("Aktifkan Auto Delete Plant", AutoDeletePlant.Config.Enabled, function(state)
        AutoDeletePlant.Config.Enabled = state
        if state then
            AutoDeletePlant.Start()
            statusCard:SetStatus("Status: 🟢 Auto Delete ON (Membersihkan...)", Color3.fromRGB(0, 255, 180))
            Notify("Auto Delete", "Pembersih Tanaman Aktif!", 2.5)
        else
            AutoDeletePlant.Stop()
            statusCard:SetStatus("Status: ⚪ Auto Delete OFF (Idle)", Color3.fromRGB(200, 185, 220))
            Notify("Auto Delete", "Pembersih Tanaman Dimatikan.", 2.5)
        end
    end)

    MainTab:AddSection("Proteksi & Fitur Aman")
    MainTab:AddToggle("🛡️ Lindungi Tanaman Terpasang (Equipped)", AutoDeletePlant.Config.ProtectEquipped, function(val)
        AutoDeletePlant.Config.ProtectEquipped = val
    end)
    MainTab:AddToggle("🌟 Pasang Tanaman Terbaik Dulu (Equip Best)", AutoDeletePlant.Config.AutoEquipBestFirst, function(val)
        AutoDeletePlant.Config.AutoEquipBestFirst = val
    end)
    MainTab:AddToggle("🪴 Bersihkan Pot Sampah di Plot (Shovel)", AutoDeletePlant.Config.CleanPlotPots, function(val)
        AutoDeletePlant.Config.CleanPlotPots = val
    end)

    MainTab:AddSection("Aksi Cepat")
    MainTab:AddButton("⚡ Hapus & Bersihkan Sekarang (Manual)", function()
        AutoDeletePlant.RunSingleCycle()
        Notify("Manual Clean", "Siklus pembersihan selesai dijalankan!", 2.5)
    end)
    MainTab:AddButton("🛡️ Equip Best Plants Sekarang", function()
        callRemote("EquipBestPlants")
        Notify("Equip Best", "Tanaman terbaik berhasil dipasang!", 2)
    end)

    -- TAB 2: 🔍 IN-GAME CATALOG & SCANNER (SCAN SELURUH PLANT)
    local CatalogTab = CreateTab("In-Game Plants", "🔍")
    CatalogTab:AddSection("Live In-Game Scanner")

    local plantCardRefs = {}
    local plantContainerFrame = nil

    local function populatePlantsList(plantsList)
        for _, ref in pairs(plantCardRefs) do
            if ref.Card and ref.Card.Parent then ref.Card:Destroy() end
        end
        table.clear(plantCardRefs)

        for _, plant in ipairs(plantsList) do
            local ref = CatalogTab:AddPlantCard(plant.name, plant.rarity, plant.color)
            plantCardRefs[plant.name:lower()] = ref
        end
    end

    CatalogTab:AddButton("🔄 Scan Seluruh Tanaman In-Game (Live Scan)", function()
        Notify("Scanning...", "Mencari seluruh tanaman in-game dari ReplicatedStorage & UI...", 2)
        local scanned = AutoDeletePlant.ScanAllInGamePlants()
        populatePlantsList(scanned)
        Notify("Scan Selesai!", string.format("Berhasil memuat %d jenis tanaman in-game!", #scanned), 3)
    end)

    CatalogTab:AddSection("Quick Select By Rarity")
    CatalogTab:AddButton("☑️ Pilih Semua Common (Target Delete)", function()
        for pKey, ref in pairs(plantCardRefs) do
            local data = liveScannedPlantsMap[pKey]
            if data and (data.rarity:lower() == "common" or data.name:lower():find("carrot") or data.name:lower():find("potato") or data.name:lower():find("tomato") or data.name:lower():find("wheat")) then
                ref:SetChecked(true)
            end
        end
        Notify("Quick Select", "Semua tanaman Common dipilih untuk dihapus!", 2)
    end)

    CatalogTab:AddButton("⬜ Hapus Semua Pilihan (Uncheck All)", function()
        for pKey, ref in pairs(plantCardRefs) do
            ref:SetChecked(false)
        end
        table.clear(AutoDeletePlant.Config.SelectedPlants)
        Notify("Deselect All", "Semua pilihan tanaman dikosongkan.", 2)
    end)

    CatalogTab:AddSection("Daftar Tanaman In-Game")
    -- Inisialisasi awal list tanaman
    local initialPlants = AutoDeletePlant.ScanAllInGamePlants()
    populatePlantsList(initialPlants)

    -- TAB 3: 🌿 FILTER RARITY
    local FilterTab = CreateTab("Filter Rarity", "🌿")
    FilterTab:AddSection("Pilih Tier / Rarity untuk Dihapus")

    FilterTab:AddToggle("⚪ Hapus Common (Carrot, Potato, Tomato, dll)", AutoDeletePlant.Config.DeleteCommon, function(val)
        AutoDeletePlant.Config.DeleteCommon = val
    end)
    FilterTab:AddToggle("🟢 Hapus Uncommon", AutoDeletePlant.Config.DeleteUncommon, function(val)
        AutoDeletePlant.Config.DeleteUncommon = val
    end)
    FilterTab:AddToggle("🔵 Hapus Rare", AutoDeletePlant.Config.DeleteRare, function(val)
        AutoDeletePlant.Config.DeleteRare = val
    end)
    FilterTab:AddToggle("🟣 Hapus Epic", AutoDeletePlant.Config.DeleteEpic, function(val)
        AutoDeletePlant.Config.DeleteEpic = val
    end)
    FilterTab:AddToggle("🟡 Hapus Legendary", AutoDeletePlant.Config.DeleteLegendary, function(val)
        AutoDeletePlant.Config.DeleteLegendary = val
    end)
    FilterTab:AddToggle("🔴 Hapus Mythic", AutoDeletePlant.Config.DeleteMythic, function(val)
        AutoDeletePlant.Config.DeleteMythic = val
    end)

    -- TAB 4: 📋 WHITELIST & BLACKLIST
    local ListTab = CreateTab("Lists", "📋")
    ListTab:AddSection("Custom Blacklist (Selalu Dihapus)")
    ListTab:AddInput("Tambah nama tanaman ke Blacklist...", function(text)
        if text and text ~= "" then
            table.insert(AutoDeletePlant.Config.Blacklist, text:lower())
            AutoDeletePlant.Config.SelectedPlants[text:lower()] = true
            Notify("Blacklist Ditambah", text .. " berhasil ditambahkan ke Blacklist!", 2.5)
        end
    end)

    ListTab:AddSection("Custom Whitelist (Aman / Tidak Pernah Dihapus)")
    ListTab:AddInput("Tambah nama tanaman ke Whitelist...", function(text)
        if text and text ~= "" then
            table.insert(AutoDeletePlant.Config.Whitelist, text:lower())
            AutoDeletePlant.Config.SelectedPlants[text:lower()] = nil
            Notify("Whitelist Ditambah", text .. " aman dari penghapusan!", 2.5)
        end
    end)

    -- TAB 5: ⚙️ SETTINGS
    local SettingsTab = CreateTab("Settings", "⚙️")
    SettingsTab:AddSection("Informasi Sesi")
    local myPlot = getMyPlot()
    SettingsTab:AddButton("Plot Terdeteksi: " .. (myPlot and tostring(myPlot.Name) or "Tidak ditemukan"), function()
        myPlot = getMyPlot()
        Notify("Info Plot", "Plot terdeteksi saat ini: " .. (myPlot and tostring(myPlot.Name) or "None"), 3)
    end)
    SettingsTab:AddButton("Player: " .. LocalPlayer.Name, function() end)

    SettingsTab:AddSection("Kontrol GUI")
    SettingsTab:AddButton("➖ Minimize GUI (atau Tekan Right Control)", function()
        toggleHub()
    end)
    SettingsTab:AddButton("🛑 Tutup & Matikan Script", function()
        AutoDeletePlant.Stop()
        screenGui:Destroy()
    end)

    return {
        ScreenGui = screenGui,
        Notify = Notify,
        SetStatus = function(txt, col) statusCard:SetStatus(txt, col) end,
        SetToggle = function(val) if masterToggleRef then masterToggleRef:Set(val, false) end end
    }
end

-- =================================================================
-- 🚀 PUBLIC CONTROL API (START / STOP / OPEN GUI)
-- =================================================================

local guiInstance = nil

function AutoDeletePlant.Start()
    if isRunning then return end
    isRunning = true
    AutoDeletePlant.Config.Enabled = true
    print("🗑️ [Ritod Hub] Auto Delete Plant: [ ON ]")

    deleteThread = task.spawn(function()
        while isRunning and AutoDeletePlant.Config.Enabled do
            AutoDeletePlant.RunSingleCycle()
            task.wait(AutoDeletePlant.Config.ScanInterval or 2.0)
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
    if state then AutoDeletePlant.Start() else AutoDeletePlant.Stop() end
    return isRunning
end

function AutoDeletePlant.OpenUI()
    if not guiInstance or not guiInstance.ScreenGui.Parent then
        guiInstance = buildUltraHDGui()
    end
    return guiInstance
end

-- Otomatis tampilkan Ultra HD GUI saat file dijalankan
task.spawn(function()
    pcall(function()
        guiInstance = buildUltraHDGui()
    end)
end)

return AutoDeletePlant
