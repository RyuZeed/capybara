--[[
	===============================================================
	⚡ RITOD HUB - AUTO DELETE ENGINE (BACKEND MODULE)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	Pure backend engine for Auto Delete & Bulk Sell Plants.
	UI is handled centrally by capybara.lua (Ultra HD GUI).
	===============================================================
]]

local AutoDeletePlant = {}
_G.AutoDeletePlant = AutoDeletePlant

-- 🔇 SILENT MODE: Matikan seluruh text/log terminal
local print = function(...) end
local warn = function(...) end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- =================================================================
-- 🎨 RARITY COLORS & EXACT CATALOG DUMP
-- =================================================================

AutoDeletePlant.RARITY_COLORS = {
    ["Common"]    = Color3.fromRGB(180, 180, 180),
    ["Rare"]      = Color3.fromRGB(75, 170, 255),
    ["Epic"]      = Color3.fromRGB(195, 85, 255),
    ["Legendary"] = Color3.fromRGB(255, 200, 50),
    ["Mythic"]    = Color3.fromRGB(255, 65, 95),
    ["Divine"]    = Color3.fromRGB(255, 160, 220),
    ["Godly"]     = Color3.fromRGB(255, 110, 240),
    ["Secret"]    = Color3.fromRGB(0, 255, 230),
    ["BOSS"]      = Color3.fromRGB(255, 45, 65),
}

AutoDeletePlant.REAL_PLANTS_CATALOG = {
    -- Common
    { name = "Carrot", rarity = "Common" },
    { name = "Potato", rarity = "Common" },

    -- Rare
    { name = "Orange Tulip", rarity = "Rare" },
    { name = "Broccoli", rarity = "Rare" },

    -- Epic
    { name = "Sunflower", rarity = "Epic" },
    { name = "Tomato", rarity = "Epic" },

    -- Legendary
    { name = "Watermelon", rarity = "Legendary" },
    { name = "Garlic", rarity = "Legendary" },

    -- Mythic
    { name = "Fancy Avocado", rarity = "Mythic" },
    { name = "Cocotree", rarity = "Mythic" },
    { name = "Fancy Ghost Avocado", rarity = "Mythic" },

    -- Divine
    { name = "Carnivorous Plant", rarity = "Divine" },
    { name = "Mandrake", rarity = "Divine" },

    -- Godly
    { name = "Ghost Pepper", rarity = "Godly" },
    { name = "Magic Mushroom", rarity = "Godly" },
    { name = "Robot Mushroom", rarity = "Godly" },

    -- Secret
    { name = "Pumpking", rarity = "Secret" },
    { name = "True Carrot", rarity = "Secret" },
    { name = "Disco Carrot", rarity = "Secret" },
    { name = "Disco True Carrot", rarity = "Secret" },
    { name = "Pumpkin", rarity = "Secret" },
    { name = "Dragonfruit", rarity = "Secret" },

    -- Boss Plants
    { name = "Scarlet Carrot", rarity = "BOSS" },
    { name = "Red Potato", rarity = "BOSS" },
    { name = "Dark Tomato", rarity = "BOSS" },
    { name = "Skull Flower", rarity = "BOSS" },
    { name = "Holy Grailic", rarity = "BOSS" },
    { name = "Carnivorous Jester", rarity = "BOSS" },
    { name = "Pumpkin Tyrant", rarity = "BOSS" },
    { name = "Golem King", rarity = "BOSS" },
    { name = "Conqueror Carrot", rarity = "BOSS" },
}

AutoDeletePlant.Config = {
    Enabled            = false,
    ScanInterval       = 1.5,
    ProtectEquipped    = true,
    AutoEquipBestFirst = true,
    AutoSyncInGameUI   = true,
    Rarities = {
        Common    = true,
        Rare      = true,
        Epic      = true,
        Mythic    = true,
        Legendary = false,
        Divine    = false,
        Godly     = false,
        Secret    = false,
    },
    SelectedPlants = {
        ["carrot"]              = true,
        ["potato"]              = true,
        ["orange tulip"]        = true,
        ["broccoli"]            = true,
        ["sunflower"]           = true,
        ["tomato"]              = true,
        ["fancy avocado"]       = true,
        ["cocotree"]            = true,
        ["fancy ghost avocado"] = true,
    }
}

local isRunning = false
local deleteThread = nil
local totalDeletedCount = 0

local function clickImageButton(btn)
    if not btn then return end
    if typeof(firesignal) == "function" then
        if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
        if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
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
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

function AutoDeletePlant.GetPlantCount()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local c = 0
    for _, t in ipairs(backpack:GetChildren()) do
        if t:IsA("Tool") then
            local n = t.Name:lower()
            if n:find("carrot") or n:find("potato") or n:find("tulip") or n:find("broccoli")
                or n:find("sunflower") or n:find("tomato") or n:find("watermelon") or n:find("garlic")
                or n:find("avocado") or n:find("cocotree") or n:find("pepper") or n:find("mushroom")
                or n:find("plant") or n:find("mandrake") or n:find("pumpkin") or n:find("dragonfruit") then
                c = c + 1
            end
        end
    end
    return c
end

function AutoDeletePlant.SyncInGameRarityButtons(rarities)
    rarities = rarities or {"Common", "Rare", "Epic", "Mythic"}
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local mainGui = pg and pg:FindFirstChild("MainGui")
        local autoSellFrame = mainGui and mainGui.Root and mainGui.Root.Frames:FindFirstChild("AutoSell")
        local rarityOptions = autoSellFrame and autoSellFrame:FindFirstChild("RarityOptions")

        if rarityOptions then
            for _, rName in ipairs(rarities) do
                local rFrame = rarityOptions:FindFirstChild(rName)
                if rFrame and rFrame:FindFirstChild("Button") then
                    clickImageButton(rFrame.Button)
                    task.wait(0.03)
                end
            end
        end

        if Remotes:FindFirstChild("ChangeAutosellOptions") then
            for _, rName in ipairs(rarities) do
                Remotes.ChangeAutosellOptions:InvokeServer(rName, true)
            end
        end
    end)
end

function AutoDeletePlant.InstantSellAllPlants()
    local before = AutoDeletePlant.GetPlantCount()

    -- 1. Pasang Tanaman Terbaik (Proteksi) jika aktif
    if AutoDeletePlant.Config.AutoEquipBestFirst and Remotes:FindFirstChild("EquipBestPlants") then
        pcall(function() Remotes.EquipBestPlants:FireServer() end)
        task.wait(0.08)
    end

    -- 2. Scan Backpack & Lindungi Tanaman yang TIDAK dicentang (Treat as Favorite)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    local selectedPlants = AutoDeletePlant.Config.SelectedPlants or {}

    if backpack and Remotes:FindFirstChild("ChangeFavoriteStatus") then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local tKey = tool.Name:lower()
                if selectedPlants[tKey] == true then
                    -- Tanaman dicentang = MAU DIJUAL / DIBUANG
                    pcall(function() Remotes.ChangeFavoriteStatus:FireServer(tool, false) end)
                else
                    -- Tanaman TIDAK dicentang = SIMPAN / LINDUNGI (FAVORITE)
                    pcall(function() Remotes.ChangeFavoriteStatus:FireServer(tool, true) end)
                end
            end
        end
    end

    -- 3. Jual Tanaman
    pcall(function()
        if Remotes:FindFirstChild("Sell") then
            -- Bulk sell server akan otomatis melewati item yang berstatus Favorite
            Remotes.Sell:FireServer("bulkSell", "Plant")

            -- Fallback single tool sell untuk item yang dicentang
            if backpack then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and selectedPlants[tool.Name:lower()] == true then
                        Remotes.Sell:FireServer(tool)
                    end
                end
            end
        end
    end)

    task.wait(0.3)
    local after = AutoDeletePlant.GetPlantCount()
    totalDeletedCount = totalDeletedCount + 1
    return before, after
end

function AutoDeletePlant.RunSingleCycle()
    AutoDeletePlant.InstantSellAllPlants()
end

function AutoDeletePlant.Start()
    if isRunning then return end
    isRunning = true
    AutoDeletePlant.Config.Enabled = true
    print("🗑️ [Ritod Hub] Auto Delete Plants Engine: [ ON ]")

    local syncList = {}
    if AutoDeletePlant.Config.Rarities then
        if AutoDeletePlant.Config.Rarities.Common then table.insert(syncList, "Common") end
        if AutoDeletePlant.Config.Rarities.Rare then table.insert(syncList, "Rare") end
        if AutoDeletePlant.Config.Rarities.Epic then table.insert(syncList, "Epic") end
        if AutoDeletePlant.Config.Rarities.Mythic then table.insert(syncList, "Mythic") end
        if AutoDeletePlant.Config.Rarities.Legendary then table.insert(syncList, "Legendary") end
        if AutoDeletePlant.Config.Rarities.Divine then table.insert(syncList, "Divine") end
        if AutoDeletePlant.Config.Rarities.Godly then table.insert(syncList, "Godly") end
        if AutoDeletePlant.Config.Rarities.Secret then table.insert(syncList, "Secret") end
    end

    if #syncList > 0 then
        AutoDeletePlant.SyncInGameRarityButtons(syncList)
    end

    AutoDeletePlant.RunSingleCycle()

    deleteThread = task.spawn(function()
        while isRunning and AutoDeletePlant.Config.Enabled do
            AutoDeletePlant.RunSingleCycle()
            task.wait(AutoDeletePlant.Config.ScanInterval or 1.5)
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
    print("🛑 [Ritod Hub] Auto Delete Plants Engine: [ OFF ]")
end

function AutoDeletePlant.Toggle(state)
    if state == nil then state = not isRunning end
    if state then AutoDeletePlant.Start() else AutoDeletePlant.Stop() end
    return isRunning
end

return AutoDeletePlant
