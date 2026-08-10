--[[
	===============================================================
	⚡ RITOD HUB - AUTO DELETE & AUTO SELL PLANTS (ULTRA HD & CONFIG)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- Roll Anime Style Ultra HD GUI (Draggable, Smooth Glow, Float Button)
	- JSON File Config Manager (Save & Auto-Load per Player)
	- Fast In-Game Remote & UI Sync (Common -> Mythic / All Rarities)
	- Exact Plant Catalog Filtering & Bulk Sell Engine
	===============================================================
]]

local AutoDeletePlant = {}
_G.AutoDeletePlant = AutoDeletePlant

-- Tunggu game ter-load sempurna
if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.2)

-- Services
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- 🧹 HAPUS PAKSA SEMUA GUI LAMA YANG MENEMPEL DI MEMORI
pcall(function()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg and pg:FindFirstChild("RitodHubAutoDelete") then pg.RitodHubAutoDelete:Destroy() end
    if CoreGui and CoreGui:FindFirstChild("RitodHubAutoDelete") then CoreGui.RitodHubAutoDelete:Destroy() end
end)

-- =================================================================
-- 🎨 RARITY COLORS & EXACT CATALOG DUMP
-- =================================================================

local RARITY_COLORS = {
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

-- 100% REAL IN-GAME PLANT CATALOG FROM GAME DUMP
local REAL_PLANTS_CATALOG = {
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

-- =================================================================
-- 💾 CONFIG MANAGER (PER-PLAYER JSON FILE PERSISTENCE)
-- =================================================================

local ROOT_FOLDER = "RitodHub"
local GAME_FOLDER = "RitodHub/Capybara"
local CONFIG_PATH = string.format("RitodHub/Capybara/%s.json", LocalPlayer.Name)

local ConfigManager = {}
ConfigManager.ConfigPath = CONFIG_PATH

local DEFAULT_CONFIG = {
    Enabled            = true,
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

local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
    else
        copy = orig
    end
    return copy
end

AutoDeletePlant.Config = deepCopy(DEFAULT_CONFIG)

-- Override with getgenv() if provided
local USER_CFG = (typeof(getgenv) == "function" and getgenv().AutoDeleteConfig) or _G.AutoDeleteConfig
if typeof(USER_CFG) == "table" then
    for k, v in pairs(USER_CFG) do
        AutoDeletePlant.Config[k] = v
    end
end

local function ensureFolders()
    pcall(function()
        if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
            if not isfolder(ROOT_FOLDER) then makefolder(ROOT_FOLDER) end
            if not isfolder(GAME_FOLDER) then makefolder(GAME_FOLDER) end
        end
    end)
end

function ConfigManager.Save(customCfg)
    local cfgToSave = customCfg or AutoDeletePlant.Config
    local success, err = pcall(function()
        if typeof(writefile) == "function" then
            ensureFolders()
            local jsonString = HttpService:JSONEncode(cfgToSave)
            writefile(CONFIG_PATH, jsonString)
        end
    end)

    if success then
        print("💾 [ConfigManager] Config tersimpan ke: " .. CONFIG_PATH)
    else
        warn("⚠️ [ConfigManager] Gagal menyimpan config: " .. tostring(err))
    end
    return success
end

function ConfigManager.Load()
    ensureFolders()
    local success, err = pcall(function()
        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(CONFIG_PATH) then
            local content = readfile(CONFIG_PATH)
            if content and #content > 0 then
                local data = HttpService:JSONDecode(content)
                if typeof(data) == "table" then
                    if data.Enabled ~= nil then AutoDeletePlant.Config.Enabled = data.Enabled end
                    if data.ScanInterval ~= nil then AutoDeletePlant.Config.ScanInterval = data.ScanInterval end
                    if data.ProtectEquipped ~= nil then AutoDeletePlant.Config.ProtectEquipped = data.ProtectEquipped end
                    if data.AutoEquipBestFirst ~= nil then AutoDeletePlant.Config.AutoEquipBestFirst = data.AutoEquipBestFirst end
                    if data.AutoSyncInGameUI ~= nil then AutoDeletePlant.Config.AutoSyncInGameUI = data.AutoSyncInGameUI end
                    if typeof(data.Rarities) == "table" then
                        AutoDeletePlant.Config.Rarities = data.Rarities
                    end
                    if typeof(data.SelectedPlants) == "table" then
                        AutoDeletePlant.Config.SelectedPlants = data.SelectedPlants
                    end
                    print("💾 [ConfigManager] Berhasil memuat config dari: " .. CONFIG_PATH)
                end
            end
        end
    end)

    if not success then
        warn("⚠️ [ConfigManager] Gagal membaca config: " .. tostring(err))
    end
    return AutoDeletePlant.Config
end

function ConfigManager.Reset()
    pcall(function()
        if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(CONFIG_PATH) then
            delfile(CONFIG_PATH)
        end
    end)
    AutoDeletePlant.Config = deepCopy(DEFAULT_CONFIG)
    print("🗑️ [ConfigManager] Config direset ke default.")
    return AutoDeletePlant.Config
end

-- Auto Load on initial run
ConfigManager.Load()

AutoDeletePlant.ConfigManager = ConfigManager

local isRunning = false
local deleteThread = nil
local totalDeletedCount = 0

-- =================================================================
-- 🛠️ HELPER FUNCTIONS & UI CLICKER
-- =================================================================

local function cleanPlantName(rawText)
    if not rawText or type(rawText) ~= "string" then return "" end
    local cleaned = rawText:gsub("%b[]", ""):gsub("^%s*(.-)%s*$", "%1")
    return cleaned
end

local function getPlantCount()
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

-- =================================================================
-- 🔄 SINKRONISASI TOMBOL "JUAL OTOMATIS" DI MENU GAME
-- =================================================================

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

-- =================================================================
-- 🎯 100% EXACT BULK SELL PLANTS FROM GAME SOURCE CODE
-- =================================================================

function AutoDeletePlant.InstantSellAllPlants()
    local before = getPlantCount()

    -- 1. Pasang Tanaman Terbaik (Proteksi) jika aktif
    if AutoDeletePlant.Config.AutoEquipBestFirst and Remotes:FindFirstChild("EquipBestPlants") then
        Remotes.EquipBestPlants:FireServer()
        task.wait(0.08)
    end

    -- 2. EKSEKUSI ENGINE ASLI BULK SELL
    if Remotes:FindFirstChild("Sell") then
        Remotes.Sell:FireServer("bulkSell", "Plant")
    end

    task.wait(0.3)
    local after = getPlantCount()
    totalDeletedCount = totalDeletedCount + 1
    return before, after
end

function AutoDeletePlant.RunSingleCycle()
    AutoDeletePlant.InstantSellAllPlants()
end

-- =================================================================
-- 🎨 ULTRA HD GUI BUILDER (ROLL ANIME STYLE)
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
        duration = duration or 2.5
        local n = Instance.new("Frame")
        n.Size = UDim2.new(1, 0, 0, 60)
        n.BackgroundColor3 = Color3.fromRGB(20, 15, 28)
        n.BackgroundTransparency = 0.1
        n.BorderSizePixel = 0
        n.Position = UDim2.new(1, 100, 0, 0)
        n.ZIndex = 201
        n.Parent = notifHolder

        local nCorner = Instance.new("UICorner")
        nCorner.CornerRadius = UDim.new(0, 10)
        nCorner.Parent = n

        local nStroke = Instance.new("UIStroke")
        nStroke.Thickness = 1.4
        nStroke.Color = Color3.fromRGB(185, 90, 255)
        nStroke.Parent = n

        local nTitle = Instance.new("TextLabel")
        nTitle.Position = UDim2.new(0, 12, 0, 8)
        nTitle.Size = UDim2.new(1, -24, 0, 18)
        nTitle.BackgroundTransparency = 1
        nTitle.Text = title
        nTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        nTitle.TextSize = 13
        nTitle.Font = Enum.Font.GothamBold
        nTitle.TextXAlignment = Enum.TextXAlignment.Left
        nTitle.ZIndex = 202
        nTitle.Parent = n

        local nDesc = Instance.new("TextLabel")
        nDesc.Position = UDim2.new(0, 12, 0, 28)
        nDesc.Size = UDim2.new(1, -24, 0, 22)
        nDesc.BackgroundTransparency = 1
        nDesc.Text = desc
        nDesc.TextColor3 = Color3.fromRGB(190, 175, 205)
        nDesc.TextSize = 11
        nDesc.Font = Enum.Font.GothamMedium
        nDesc.TextXAlignment = Enum.TextXAlignment.Left
        nDesc.ZIndex = 202
        nDesc.Parent = n

        TweenService:Create(n, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

        task.delay(duration, function()
            if n and n.Parent then
                local out = TweenService:Create(n, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 150, 0, 0)})
                out:Play()
                out.Completed:Connect(function() n:Destroy() end)
            end
        end)
    end

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainHub"
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, 680, 0, 440)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 20)
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
    hubTitle.Text = "⚡ RITOD HUB <font color='#c47aff'>AUTO DELETE & AUTO SELL</font>"
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
    statsLabel.Text = "FPS: 60  |  PING: 24ms"
    statsLabel.TextColor3 = Color3.fromRGB(160, 145, 175)
    statsLabel.TextSize = 11
    statsLabel.Font = Enum.Font.GothamMedium
    statsLabel.TextXAlignment = Enum.TextXAlignment.Right
    statsLabel.ZIndex = 12
    statsLabel.Parent = topBar

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

    local floatWidget = Instance.new("Frame")
    floatWidget.Name = "FloatWidget"
    floatWidget.AnchorPoint = Vector2.new(0, 0.5)
    floatWidget.Position = UDim2.new(0, 24, 0.5, 0)
    floatWidget.Size = UDim2.new(0, 56, 0, 56)
    floatWidget.BackgroundColor3 = Color3.fromRGB(20, 14, 28)
    floatWidget.BorderSizePixel = 0
    floatWidget.ZIndex = 100
    floatWidget.Active = true
    floatWidget.Parent = screenGui

    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 16)
    floatCorner.Parent = floatWidget

    local floatStroke = Instance.new("UIStroke")
    floatStroke.Thickness = 2.5
    floatStroke.Color = Color3.fromRGB(190, 90, 255)
    floatStroke.Parent = floatWidget

    local floatIcon = Instance.new("TextLabel")
    floatIcon.Size = UDim2.new(1, 0, 1, 0)
    floatIcon.BackgroundTransparency = 1
    floatIcon.Text = "🗑️"
    floatIcon.TextSize = 22
    floatIcon.Font = Enum.Font.GothamBlack
    floatIcon.ZIndex = 101
    floatIcon.Parent = floatWidget

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
            card.Size = UDim2.new(1, 0, 0, 48)
            card.BackgroundColor3 = Color3.fromRGB(24, 18, 32)
            card.BorderSizePixel = 0
            card.ZIndex = 14
            card.Parent = page

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 10)
            cCorner.Parent = card

            local subInfo = Instance.new("TextLabel")
            subInfo.Position = UDim2.new(0, 12, 0, 0)
            subInfo.Size = UDim2.new(0.5, 0, 1, 0)
            subInfo.BackgroundTransparency = 1
            subInfo.Text = "🗑️ Terjual: 0 siklus"
            subInfo.TextColor3 = Color3.fromRGB(255, 110, 130)
            subInfo.TextSize = 12
            subInfo.Font = Enum.Font.GothamBold
            subInfo.TextXAlignment = Enum.TextXAlignment.Left
            subInfo.ZIndex = 15
            subInfo.Parent = card

            local scanInfo = Instance.new("TextLabel")
            scanInfo.Position = UDim2.new(0.5, 0, 0, 0)
            scanInfo.Size = UDim2.new(0.5, -12, 1, 0)
            scanInfo.BackgroundTransparency = 1
            scanInfo.Text = "🔍 Sisa: " .. tostring(getPlantCount()) .. " item"
            scanInfo.TextColor3 = Color3.fromRGB(0, 230, 140)
            scanInfo.TextSize = 12
            scanInfo.Font = Enum.Font.GothamBold
            scanInfo.TextXAlignment = Enum.TextXAlignment.Right
            scanInfo.ZIndex = 15
            scanInfo.Parent = card

            task.spawn(function()
                while card and card.Parent do
                    subInfo.Text = "🗑️ Siklus Jual: " .. tostring(totalDeletedCount) .. "x"
                    scanInfo.Text = "🔍 Sisa Tanaman: " .. tostring(getPlantCount()) .. " item"
                    task.wait(0.8)
                end
            end)

            return card
        end

        function elements:AddPlantCard(plantName, plantRarity, onStateChanged)
            local pKey = cleanPlantName(plantName):lower()
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

            local rColor = RARITY_COLORS[plantRarity] or Color3.fromRGB(180, 180, 180)
            local badge = Instance.new("TextLabel")
            badge.Size = UDim2.new(0, 75, 0, 18)
            badge.Position = UDim2.new(0, 34, 0.5, -9)
            badge.BackgroundColor3 = rColor
            badge.BackgroundTransparency = 0.8
            badge.Text = plantRarity or "Common"
            badge.TextColor3 = rColor
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

        return elements
    end

    -- =========================================================================
    -- 📑 TAB 1: 🗑️ AUTO DELETE (MASTER CONTROLLER)
    -- =========================================================================
    local MainTab = CreateTab("Auto Delete", "🗑️")
    MainTab:AddStatusCard()

    local masterToggle = MainTab:AddToggle("Aktifkan Auto Delete Plant", AutoDeletePlant.Config.Enabled, function(state)
        AutoDeletePlant.Config.Enabled = state
        if state then
            AutoDeletePlant.Start()
            Notify("Auto Delete", "Auto Delete Aktif! Menjual tanaman otomatis...", 2.5)
        else
            AutoDeletePlant.Stop()
            Notify("Auto Delete", "Auto Delete Dimatikan.", 2.5)
        end
    end)

    MainTab:AddSection("Proteksi & Fitur Aman")
    MainTab:AddToggle("🛡️ Lindungi Tanaman Terpasang (Equipped)", AutoDeletePlant.Config.ProtectEquipped, function(val)
        AutoDeletePlant.Config.ProtectEquipped = val
    end)

    MainTab:AddToggle("🌟 Pasang Tanaman Terbaik Dulu (Equip Best)", AutoDeletePlant.Config.AutoEquipBestFirst, function(val)
        AutoDeletePlant.Config.AutoEquipBestFirst = val
    end)

    MainTab:AddSection("Aksi Cepat")
    MainTab:AddButton("⚡ Hapus & Bersihkan Sekarang (Manual)", function()
        local b, a = AutoDeletePlant.InstantSellAllPlants()
        Notify("Instant Sell", "Sebelum: " .. tostring(b) .. " | Sisa: " .. tostring(a), 2.5)
    end)

    MainTab:AddButton("🔄 Sinkronkan Menu Jual Game (Biasa -> Mistik)", function()
        AutoDeletePlant.SyncInGameRarityButtons({"Common", "Rare", "Epic", "Mythic"})
        Notify("AutoSell Game", "Biasa, Aneh, Epik, dan Mistik Aktif!", 2)
    end)

    MainTab:AddButton("🛡️ Equip Best Plants Sekarang", function()
        if Remotes:FindFirstChild("EquipBestPlants") then
            Remotes.EquipBestPlants:FireServer()
            Notify("Equip Best", "Tanaman terbaik berhasil dipasang!", 2)
        end
    end)

    -- =========================================================================
    -- 📑 TAB 2: 🌿 PLANTS CATALOG (AUTO SELECT COMMON, RARE, EPIC, MYTHIC)
    -- =========================================================================
    local CatalogTab = CreateTab("Plants Catalog", "🌿")
    CatalogTab:AddSection("Auto Select Berdasarkan Rarity")

    local plantCardRefs = {}

    local function selectRarity(rarityName, state)
        for _, plant in ipairs(REAL_PLANTS_CATALOG) do
            if plant.rarity:lower() == rarityName:lower() then
                local pKey = plant.name:lower()
                AutoDeletePlant.Config.SelectedPlants[pKey] = state and true or nil
                if plantCardRefs[pKey] then
                    plantCardRefs[pKey]:SetChecked(state)
                end
            end
        end
        if state and AutoDeletePlant.Config.AutoSyncInGameUI then
            AutoDeletePlant.SyncInGameRarityButtons({rarityName})
        end
    end

    CatalogTab:AddButton("⚪ Auto Select Common (Biasa)", function()
        selectRarity("Common", true)
        Notify("Auto Select", "Semua Common (Carrot, Potato) dipilih!", 2)
    end)

    CatalogTab:AddButton("🔵 Auto Select Rare (Aneh)", function()
        selectRarity("Rare", true)
        Notify("Auto Select", "Semua Rare (Orange Tulip, Broccoli) dipilih!", 2)
    end)

    CatalogTab:AddButton("🟣 Auto Select Epic (Epik)", function()
        selectRarity("Epic", true)
        Notify("Auto Select", "Semua Epic (Sunflower, Tomato) dipilih!", 2)
    end)

    CatalogTab:AddButton("🔴 Auto Select Mythic (Mistik)", function()
        selectRarity("Mythic", true)
        Notify("Auto Select", "Semua Mythic dipilih!", 2)
    end)

    CatalogTab:AddButton("⚡ AUTO SELECT ALL: Biasa + Aneh + Epik + Mistik", function()
        selectRarity("Common", true)
        selectRarity("Rare", true)
        selectRarity("Epic", true)
        selectRarity("Mythic", true)
        AutoDeletePlant.SyncInGameRarityButtons({"Common", "Rare", "Epic", "Mythic"})
        Notify("Auto Select All", "Biasa, Aneh, Epik, dan Mistik SEMUA TERPILIH!", 2.5)
    end)

    CatalogTab:AddButton("⬜ Kosongkan Pilihan (Uncheck All)", function()
        table.clear(AutoDeletePlant.Config.SelectedPlants)
        for _, ref in pairs(plantCardRefs) do
            ref:SetChecked(false)
        end
        Notify("Deselect All", "Semua pilihan tanaman dikosongkan.", 2)
    end)

    CatalogTab:AddSection("Checklist Tanaman In-Game")
    for _, plant in ipairs(REAL_PLANTS_CATALOG) do
        local ref = CatalogTab:AddPlantCard(plant.name, plant.rarity)
        plantCardRefs[plant.name:lower()] = ref
    end

    -- =========================================================================
    -- 📑 TAB 3: ⚙️ SETTINGS & CONFIG MANAGER (ROLL ANIME STYLE)
    -- =========================================================================
    local SettingsTab = CreateTab("Settings", "⚙️")
    
    SettingsTab:AddSection("💾 Simpan & Muat Config")
    SettingsTab:AddButton("💾 Simpan Config (Save Config)", function()
        local success = ConfigManager.Save()
        if success then
            Notify("Config Saved", "Pengaturan berhasil disimpan ke file JSON!", 2.5)
        else
            Notify("Config Error", "Gagal menyimpan file config.", 2.5)
        end
    end)

    SettingsTab:AddButton("🔄 Muat Ulang Config (Load Config)", function()
        local loaded = ConfigManager.Load()
        if loaded then
            masterToggle:Set(loaded.Enabled, false)
            for _, plant in ipairs(REAL_PLANTS_CATALOG) do
                local pKey = plant.name:lower()
                local isChk = (loaded.SelectedPlants and loaded.SelectedPlants[pKey] == true)
                if plantCardRefs[pKey] then
                    plantCardRefs[pKey]:SetChecked(isChk)
                end
            end
            Notify("Config Loaded", "Pengaturan berhasil dimuat dari file JSON!", 2.5)
        else
            Notify("Config Error", "File config belum ada atau rusak.", 2.5)
        end
    end)

    SettingsTab:AddButton("🗑️ Reset Config ke Default", function()
        ConfigManager.Reset()
        masterToggle:Set(DEFAULT_CONFIG.Enabled, false)
        for _, plant in ipairs(REAL_PLANTS_CATALOG) do
            local pKey = plant.name:lower()
            local isChk = (DEFAULT_CONFIG.SelectedPlants and DEFAULT_CONFIG.SelectedPlants[pKey] == true)
            if plantCardRefs[pKey] then
                plantCardRefs[pKey]:SetChecked(isChk)
            end
        end
        Notify("Config Reset", "Semua pengaturan dikembalikan ke default.", 2.5)
    end)

    SettingsTab:AddSection("Informasi Sesi")
    SettingsTab:AddButton("Player: " .. LocalPlayer.Name, function() end)

    SettingsTab:AddSection("Kontrol GUI")
    SettingsTab:AddButton("➖ Minimize GUI", function() toggleHub() end)
    SettingsTab:AddButton("🛑 Tutup & Matikan Script", function()
        AutoDeletePlant.Stop()
        screenGui:Destroy()
    end)

    return {
        ScreenGui = screenGui,
        Notify = Notify
    }
end

-- =================================================================
-- 🚀 PUBLIC CONTROL API & AUTO EXECUTE
-- =================================================================

local guiInstance = nil

function AutoDeletePlant.Start()
    if isRunning then return end
    isRunning = true
    AutoDeletePlant.Config.Enabled = true
    print("🗑️ [Ritod Hub] Auto Delete Plants: [ ON ]")

    -- 1. Sinkronkan tombol game berdasarkan pilihan config
    local syncList = {}
    if AutoDeletePlant.Config.Rarities then
        if AutoDeletePlant.Config.Rarities.Common then table.insert(syncList, "Common") end
        if AutoDeletePlant.Config.Rarities.Rare then table.insert(syncList, "Rare") end
        if AutoDeletePlant.Config.Rarities.Epic then table.insert(syncList, "Epic") end
        if AutoDeletePlant.Config.Rarities.Mythic then table.insert(syncList, "Mythic") end
        if AutoDeletePlant.Config.Rarities.Legendary then table.insert(syncList, "Legendary") end
    end

    if #syncList > 0 then
        AutoDeletePlant.SyncInGameRarityButtons(syncList)
    end

    -- 2. Langsung jalankan 1x instant sell
    AutoDeletePlant.RunSingleCycle()

    -- 3. Loop terus menerus setiap interval
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
    print("🛑 [Ritod Hub] Auto Delete Plants: [ OFF ]")
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

-- ⚡ AUTO EXECUTE: LANGSUNG JALANKAN OTOMATIS SAAT SCRIPT DI-EXECUTE!
task.spawn(function()
    pcall(function()
        guiInstance = buildUltraHDGui()
        if AutoDeletePlant.Config.Enabled then
            AutoDeletePlant.Start()
        end
    end)
end)

return AutoDeletePlant
