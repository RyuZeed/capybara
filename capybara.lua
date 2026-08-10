--[[
	===============================================================
	⚡ RITOD HUB - CAPYBARAS VS PLANTS (ULTRA HD EDITION)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- 🖥️ Ultra HD GUI (700x460) with Neon Floating Widget & Minimize
	- 💾 Per-User Persistent Config: RitodHub/Capybara/<Username>.json
	- 🚀 12 Steps Auto Tutorial Engine with Plot Isolation
	- 🗑️ Smart Auto Delete & Bulk Sell Plant with Catalog Checkers
	- 🎁 Smart Auto Claim Rewards (Playtime & Daily Gifts)
	- 🥔 Potato Graphics, Farm Mode (Screen Off), Anti-Lag & Anti-AFK
	===============================================================
]]

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
task.wait(0.3)

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- 🧹 HAPUS PAKSA UI LAMA BILA ADA
pcall(function()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    for _, name in ipairs({"CPU_RAM_Saver_GUI", "AFKScreenOff", "RitodHubLite", "RitodHubUltra", "RitodHubAutoDelete", "PerfectAutoClaimTester"}) do
        if pg and pg:FindFirstChild(name) then pg[name]:Destroy() end
        if CoreGui and CoreGui:FindFirstChild(name) then CoreGui[name]:Destroy() end
    end
end)

-- =================================================================
-- 🌐 IMPORT MODUL CAPYBARA (LOCAL & GITHUB CLOUD SUPPORT)
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/capybara/"

local function loadModule(name)
    -- 1. Local path check
    local localPaths = {
        "modules/capybara/" .. name .. ".lua",
        name .. ".lua",
        "RitodHub/modules/capybara/" .. name .. ".lua"
    }
    if typeof(readfile) == "function" and typeof(isfile) == "function" then
        for _, path in ipairs(localPaths) do
            if isfile(path) then
                local success, result = pcall(function()
                    return loadstring(readfile(path))()
                end)
                if success and result then
                    print("📁 [Ritod Hub] Loaded local module: " .. path)
                    return result
                end
            end
        end
    end

    -- 2. Fallback load from GitHub Cloud
    local success, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. name .. ".lua"))()
    end)
    if success and result then
        print("🌐 [Ritod Hub] Loaded cloud module: " .. name)
        return result
    else
        warn("⚠️ [Ritod Hub] Gagal memuat modul: " .. name .. " -> " .. tostring(result))
        return nil
    end
end

local AFKModule      = loadModule("anti_afk")
local PinkRemover    = loadModule("pink_remover")
local GraphicsModule = loadModule("graphics")
local AutoClaim      = loadModule("auto_claim")
local AutoTutorial   = loadModule("auto_tutorial")
local AutoDelete     = loadModule("auto_delete")

-- =================================================================
-- 💾 CONFIG MANAGER (PER-USER JSON FILE PERSISTENCE)
-- =================================================================
local ROOT_FOLDER = "RitodHub"
local GAME_FOLDER = "RitodHub/Capybara"
local CONFIG_PATH = string.format("RitodHub/Capybara/%s.json", LocalPlayer.Name)

local ConfigManager = {}
ConfigManager.ConfigPath = CONFIG_PATH

local DEFAULT_CONFIG = {
    AutoTutorial       = true,
    AutoDelete         = false,
    AutoClaim          = true,
    FarmMode           = false,
    AntiLag            = false,
    PotatoGraphics     = true,
    AntiAFK            = true,
    PinkRemover        = true,
    ProtectEquipped    = true,
    AutoEquipBestFirst = true,
    AutoSyncInGameUI   = true,
    SelectedPlants     = {
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
        for k, v in next, orig, nil do
            copy[deepCopy(k)] = deepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

local CurrentConfig = deepCopy(DEFAULT_CONFIG)

-- Override with getgenv().Config if provided
local USER_CFG = (typeof(getgenv) == "function" and getgenv().Config) or _G.Config
if typeof(USER_CFG) == "table" then
    for k, v in pairs(USER_CFG) do
        CurrentConfig[k] = v
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
    local cfgToSave = customCfg or CurrentConfig
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
                    for k, v in pairs(data) do
                        CurrentConfig[k] = v
                    end
                    print("💾 [ConfigManager] Berhasil memuat config dari: " .. CONFIG_PATH)
                end
            end
        end
    end)

    if not success then
        warn("⚠️ [ConfigManager] Gagal membaca config: " .. tostring(err))
    end
    return CurrentConfig
end

function ConfigManager.Reset()
    pcall(function()
        if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(CONFIG_PATH) then
            delfile(CONFIG_PATH)
        end
    end)
    CurrentConfig = deepCopy(DEFAULT_CONFIG)
    print("🗑️ [ConfigManager] Config direset ke default.")
    return CurrentConfig
end

-- Muat config tersimpan di disk
ConfigManager.Load()

-- =================================================================
-- 🎨 REAL PLANT CATALOG & COLORS
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

local function cleanPlantName(rawText)
    if not rawText or type(rawText) ~= "string" then return "" end
    return rawText:gsub("%b[]", ""):gsub("^%s*(.-)%s*$", "%1")
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

-- =================================================================
-- 🎨 GUI INITIALIZATION (ULTRA HD 700x460 - ROLL ANIME STYLE)
-- =================================================================
local parentGui
if typeof(gethui) == "function" then
    parentGui = gethui()
elseif run_secure_function or getexecutorname then
    parentGui = CoreGui
else
    parentGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RitodHubUltra"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = parentGui
_G.RitodHubGui = screenGui

-- ===================== DRAGGABLE & CLICK HANDLER =====================
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
    duration = duration or 3.0
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
    nDesc.Size = UDim2.new(1, -30, 0, 24)
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
-- 🖥️ MAIN HUB WINDOW (700x460)
-- ==============================================================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainHub"
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size = UDim2.new(0, 700, 0, 460)
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
hubTitle.Text = "⚡ RITOD HUB <font color='#c47aff'>CAPYBARAS VS PLANTS v3.2</font>"
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

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(235, 45, 75), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(48, 22, 34), TextColor3 = Color3.fromRGB(255, 110, 130)}):Play()
end)

minBtn.MouseEnter:Connect(function()
    TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(55, 42, 70), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
end)
minBtn.MouseLeave:Connect(function()
    TweenService:Create(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(32, 26, 42), TextColor3 = Color3.fromRGB(180, 160, 205)}):Play()
end)

-- Unload Modal
local modalOverlay = Instance.new("Frame")
modalOverlay.Name = "ModalOverlay"
modalOverlay.Size = UDim2.new(1, 0, 1, 0)
modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
modalOverlay.BackgroundTransparency = 1
modalOverlay.Visible = false
modalOverlay.ZIndex = 150
modalOverlay.Parent = mainFrame

local modalBox = Instance.new("Frame")
modalBox.Name = "ModalBox"
modalBox.AnchorPoint = Vector2.new(0.5, 0.5)
modalBox.Position = UDim2.new(0.5, 0, 0.5, 0)
modalBox.Size = UDim2.new(0, 360, 0, 175)
modalBox.BackgroundColor3 = Color3.fromRGB(22, 17, 28)
modalBox.BorderSizePixel = 0
modalBox.ZIndex = 151
modalBox.Parent = modalOverlay

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 14)
modalCorner.Parent = modalBox

local modalStroke = Instance.new("UIStroke")
modalStroke.Thickness = 1.8
modalStroke.Color = Color3.fromRGB(255, 75, 100)
modalStroke.Parent = modalBox

local mTitle = Instance.new("TextLabel")
mTitle.Position = UDim2.new(0, 0, 0, 18)
mTitle.Size = UDim2.new(1, 0, 0, 24)
mTitle.BackgroundTransparency = 1
mTitle.Text = "⚠️ Unload RITOD Hub?"
mTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
mTitle.TextSize = 16
mTitle.Font = Enum.Font.GothamBold
mTitle.ZIndex = 152
mTitle.Parent = modalBox

local mDesc = Instance.new("TextLabel")
mDesc.Position = UDim2.new(0, 24, 0, 48)
mDesc.Size = UDim2.new(1, -48, 0, 40)
mDesc.BackgroundTransparency = 1
mDesc.Text = "Apakah kamu yakin ingin menutup dan menghentikan seluruh script Ritod Hub?"
mDesc.TextColor3 = Color3.fromRGB(180, 165, 195)
mDesc.TextSize = 12
mDesc.Font = Enum.Font.GothamMedium
mDesc.TextWrapped = true
mDesc.ZIndex = 152
mDesc.Parent = modalBox

local yesBtn = Instance.new("TextButton")
yesBtn.AnchorPoint = Vector2.new(0, 1)
yesBtn.Position = UDim2.new(0, 24, 1, -18)
yesBtn.Size = UDim2.new(0, 145, 0, 38)
yesBtn.BackgroundColor3 = Color3.fromRGB(235, 45, 75)
yesBtn.AutoButtonColor = false
yesBtn.Text = "Yes, Unload"
yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
yesBtn.TextSize = 13
yesBtn.Font = Enum.Font.GothamBold
yesBtn.ZIndex = 153
yesBtn.Parent = modalBox

local yesCorner = Instance.new("UICorner")
yesCorner.CornerRadius = UDim.new(0, 8)
yesCorner.Parent = yesBtn

local cancelBtn = Instance.new("TextButton")
cancelBtn.AnchorPoint = Vector2.new(1, 1)
cancelBtn.Position = UDim2.new(1, -24, 1, -18)
cancelBtn.Size = UDim2.new(0, 145, 0, 38)
cancelBtn.BackgroundColor3 = Color3.fromRGB(40, 32, 48)
cancelBtn.AutoButtonColor = false
cancelBtn.Text = "Cancel"
cancelBtn.TextColor3 = Color3.fromRGB(200, 185, 215)
cancelBtn.TextSize = 13
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.ZIndex = 153
cancelBtn.Parent = modalBox

local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 8)
cancelCorner.Parent = cancelBtn

local function showUnloadModal()
    modalOverlay.Visible = true
    modalBox.Position = UDim2.new(0.5, 0, 0.55, 0)
    TweenService:Create(modalOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
    TweenService:Create(modalBox, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
end

local function hideUnloadModal()
    local t = TweenService:Create(modalOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 1})
    TweenService:Create(modalBox, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0.55, 0)}):Play()
    t:Play()
    t.Completed:Connect(function()
        modalOverlay.Visible = false
    end)
end

closeBtn.Activated:Connect(showUnloadModal)
cancelBtn.Activated:Connect(hideUnloadModal)

yesBtn.Activated:Connect(function()
    if AutoTutorial then AutoTutorial.Stop() end
    if AutoDelete then AutoDelete.Stop() end
    if AutoClaim then AutoClaim.Stop() end
    if AFKModule then AFKModule.Disable() end
    if PinkRemover then PinkRemover.Stop() end
    screenGui:Destroy()
end)

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

local floatIcon = Instance.new("TextLabel")
floatIcon.Size = UDim2.new(1, 0, 1, 0)
floatIcon.BackgroundTransparency = 1
floatIcon.Text = "👑"
floatIcon.TextSize = 24
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

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
        toggleHub()
    end
end)

-- Sidebar & Content
local sideBar = Instance.new("Frame")
sideBar.Name = "SideBar"
sideBar.Position = UDim2.new(0, 0, 0, 50)
sideBar.Size = UDim2.new(0, 170, 1, -50)
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
contentArea.Position = UDim2.new(0, 170, 0, 50)
contentArea.Size = UDim2.new(1, -170, 1, -50)
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

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38, 28, 50), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(26, 20, 34), TextColor3 = Color3.fromRGB(235, 225, 245)}):Play()
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

        local isChecked = (CurrentConfig.SelectedPlants and CurrentConfig.SelectedPlants[pKey] == true)

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
            local newState = not (CurrentConfig.SelectedPlants and CurrentConfig.SelectedPlants[pKey] == true)
            if not CurrentConfig.SelectedPlants then CurrentConfig.SelectedPlants = {} end
            CurrentConfig.SelectedPlants[pKey] = newState and true or nil
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
                if not CurrentConfig.SelectedPlants then CurrentConfig.SelectedPlants = {} end
                CurrentConfig.SelectedPlants[pKey] = val and true or nil
                checkBtn.BackgroundColor3 = val and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(45, 35, 55)
                checkBtn.Text = val and "✓" or ""
            end,
            Card = card
        }
    end

    return elements
end

-- =========================================================================
-- 📑 TAB 1: 🚀 AUTO TUTORIAL
-- =========================================================================
local TutorialTab = CreateTab("Auto Tutorial", "🚀")

local tutCard = Instance.new("Frame")
tutCard.Size = UDim2.new(1, 0, 0, 50)
tutCard.BackgroundColor3 = Color3.fromRGB(24, 18, 32)
tutCard.BorderSizePixel = 0
tutCard.ZIndex = 14
tutCard.Parent = TutorialTab.Page

local tcCorner = Instance.new("UICorner")
tcCorner.CornerRadius = UDim.new(0, 10)
tcCorner.Parent = tutCard

local tutStatus = Instance.new("TextLabel")
tutStatus.Position = UDim2.new(0, 12, 0, 0)
tutStatus.Size = UDim2.new(1, -24, 1, 0)
tutStatus.BackgroundTransparency = 1
tutStatus.Text = "🚀 Tutorial Status: Siap / Standby"
tutStatus.TextColor3 = Color3.fromRGB(0, 230, 140)
tutStatus.TextSize = 12
tutStatus.Font = Enum.Font.GothamBold
tutStatus.TextXAlignment = Enum.TextXAlignment.Left
tutStatus.ZIndex = 15
tutStatus.Parent = tutCard

TutorialTab:AddSection("Kontrol Auto Tutorial")
local tutToggle = TutorialTab:AddToggle("Jalankan Auto Tutorial (Step 1 - 12)", CurrentConfig.AutoTutorial, function(state)
    CurrentConfig.AutoTutorial = state
    if AutoTutorial then
        AutoTutorial.Toggle(state)
    end
    Notify("Auto Tutorial", state and "Auto Tutorial dimulai!" or "Auto Tutorial dihentikan.", 2.5)
end)

TutorialTab:AddSection("Aksi Cepat & Navigasi")
TutorialTab:AddButton("🥚 Teleport ke EggShop & Beli Egg", function()
    pcall(function()
        local eggShop = workspace:FindFirstChild("EggShop", true)
        if eggShop and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = (eggShop:IsA("Model") and eggShop:GetPivot() or eggShop.CFrame) + Vector3.new(0, 3, 0)
            Notify("Teleport", "Berhasil teleport ke EggShop!", 2)
        end
    end)
end)

TutorialTab:AddButton("🏡 Teleport ke Plot Sendiri", function()
    pcall(function()
        local plots = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("PlayerPlots")
        if plots and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            for _, p in ipairs(plots:GetChildren()) do
                local owner = p:GetAttribute("Owner") or (p:FindFirstChild("Owner") and p.Owner.Value)
                if owner == LocalPlayer.Name or owner == LocalPlayer.UserId then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = p:GetPivot() + Vector3.new(0, 4, 0)
                    Notify("Teleport", "Teleport ke Plot Anda!", 2)
                    return
                end
            end
        end
    end)
end)

TutorialTab:AddButton("👑 Equip Best Plants Sekarang", function()
    if Remotes:FindFirstChild("EquipBestPlants") then
        Remotes.EquipBestPlants:FireServer()
        Notify("Equip Best", "Tanaman terbaik berhasil dipasang!", 2)
    end
end)

-- =========================================================================
-- 📑 TAB 2: 🗑️ AUTO DELETE & BULK SELL
-- =========================================================================
local DeleteTab = CreateTab("Auto Delete", "🗑️")

local delCard = Instance.new("Frame")
delCard.Size = UDim2.new(1, 0, 0, 48)
delCard.BackgroundColor3 = Color3.fromRGB(24, 18, 32)
delCard.BorderSizePixel = 0
delCard.ZIndex = 14
delCard.Parent = DeleteTab.Page

local dcCorner = Instance.new("UICorner")
dcCorner.CornerRadius = UDim.new(0, 10)
dcCorner.Parent = delCard

local delInfo = Instance.new("TextLabel")
delInfo.Position = UDim2.new(0, 12, 0, 0)
delInfo.Size = UDim2.new(0.5, 0, 1, 0)
delInfo.BackgroundTransparency = 1
delInfo.Text = "🗑️ Auto Delete: Aktif"
delInfo.TextColor3 = Color3.fromRGB(255, 110, 130)
delInfo.TextSize = 12
delInfo.Font = Enum.Font.GothamBold
delInfo.TextXAlignment = Enum.TextXAlignment.Left
delInfo.ZIndex = 15
delInfo.Parent = delCard

local plantCountInfo = Instance.new("TextLabel")
plantCountInfo.Position = UDim2.new(0.5, 0, 0, 0)
plantCountInfo.Size = UDim2.new(0.5, -12, 1, 0)
plantCountInfo.BackgroundTransparency = 1
plantCountInfo.Text = "🔍 Sisa: " .. tostring(getPlantCount()) .. " item"
plantCountInfo.TextColor3 = Color3.fromRGB(0, 230, 140)
plantCountInfo.TextSize = 12
plantCountInfo.Font = Enum.Font.GothamBold
plantCountInfo.TextXAlignment = Enum.TextXAlignment.Right
plantCountInfo.ZIndex = 15
plantCountInfo.Parent = delCard

task.spawn(function()
    while delCard and delCard.Parent do
        plantCountInfo.Text = "🔍 Sisa Tanaman: " .. tostring(getPlantCount()) .. " item"
        task.wait(1)
    end
end)

DeleteTab:AddSection("Kontrol Auto Delete")
local deleteToggle = DeleteTab:AddToggle("Aktifkan Auto Delete & Auto Sell", CurrentConfig.AutoDelete, function(state)
    CurrentConfig.AutoDelete = state
    if AutoDelete then
        AutoDelete.Toggle(state)
    end
    Notify("Auto Delete", state and "Auto Delete aktif!" or "Auto Delete dimatikan.", 2.5)
end)

DeleteTab:AddSection("Proteksi & Keamanan")
DeleteTab:AddToggle("🛡️ Lindungi Tanaman Terpasang (Equipped)", CurrentConfig.ProtectEquipped, function(val)
    CurrentConfig.ProtectEquipped = val
    if AutoDelete and AutoDelete.Config then AutoDelete.Config.ProtectEquipped = val end
end)

DeleteTab:AddToggle("🌟 Pasang Tanaman Terbaik Sebelum Jual", CurrentConfig.AutoEquipBestFirst, function(val)
    CurrentConfig.AutoEquipBestFirst = val
    if AutoDelete and AutoDelete.Config then AutoDelete.Config.AutoEquipBestFirst = val end
end)

DeleteTab:AddSection("Aksi Manual & Sinkronisasi")
DeleteTab:AddButton("⚡ Hapus & Bersihkan Sampah Sekarang (Manual)", function()
    if AutoDelete and AutoDelete.InstantSellAllPlants then
        local b, a = AutoDelete.InstantSellAllPlants()
        Notify("Instant Sell", "Sebelum: " .. tostring(b) .. " | Sisa: " .. tostring(a), 2.5)
    else
        pcall(function() Remotes.Sell:FireServer("bulkSell", "Plant") end)
        Notify("Instant Sell", "Bulk Sell terkirim ke server!", 2)
    end
end)

DeleteTab:AddButton("🔄 Sinkronkan Menu Jual In-Game (Biasa -> Rahasia)", function()
    local allRarities = {"Common", "Rare", "Epic", "Mythic", "Legendary", "Divine", "Godly", "Secret"}
    if AutoDelete and AutoDelete.SyncInGameRarityButtons then
        AutoDelete.SyncInGameRarityButtons(allRarities)
    else
        pcall(function()
            for _, r in ipairs(allRarities) do
                Remotes.ChangeAutosellOptions:InvokeServer(r, true)
            end
        end)
    end
    Notify("In-Game Menu", "Biasa, Aneh, Epik, Mistik, Divine, Godly, dan Secret Aktif di menu game!", 2.5)
end)

DeleteTab:AddSection("Filter Rarity Cepat")
local plantCardRefs = {}

local function selectRarity(rarityName, state)
    for _, plant in ipairs(REAL_PLANTS_CATALOG) do
        if plant.rarity:lower() == rarityName:lower() then
            local pKey = plant.name:lower()
            if not CurrentConfig.SelectedPlants then CurrentConfig.SelectedPlants = {} end
            CurrentConfig.SelectedPlants[pKey] = state and true or nil
            if plantCardRefs[pKey] then
                plantCardRefs[pKey]:SetChecked(state)
            end
        end
    end
    if state and AutoDelete and AutoDelete.SyncInGameRarityButtons then
        AutoDelete.SyncInGameRarityButtons({rarityName})
    end
end

DeleteTab:AddButton("⚡ AUTO SELECT ALL: Biasa + Aneh + Epik + Mistik", function()
    selectRarity("Common", true)
    selectRarity("Rare", true)
    selectRarity("Epic", true)
    selectRarity("Mythic", true)
    Notify("Auto Select All", "Biasa, Aneh, Epik, & Mistik Terpilih!", 2.5)
end)

DeleteTab:AddButton("⚪ Common (Biasa)", function() selectRarity("Common", true); Notify("Filter", "Common dipilih!", 1.5) end)
DeleteTab:AddButton("🔵 Rare (Aneh)", function() selectRarity("Rare", true); Notify("Filter", "Rare dipilih!", 1.5) end)
DeleteTab:AddButton("🟣 Epic (Epik)", function() selectRarity("Epic", true); Notify("Filter", "Epic dipilih!", 1.5) end)
DeleteTab:AddButton("🔴 Mythic (Mistik)", function() selectRarity("Mythic", true); Notify("Filter", "Mythic dipilih!", 1.5) end)
DeleteTab:AddButton("🟡 Legendary (Legendaris)", function() selectRarity("Legendary", true); Notify("Filter", "Legendary dipilih!", 1.5) end)
DeleteTab:AddButton("🌸 Divine (Ilahi)", function() selectRarity("Divine", true); Notify("Filter", "Divine dipilih!", 1.5) end)
DeleteTab:AddButton("✨ Godly (Dewa)", function() selectRarity("Godly", true); Notify("Filter", "Godly dipilih!", 1.5) end)
DeleteTab:AddButton("👑 Secret (Rahasia)", function() selectRarity("Secret", true); Notify("Filter", "Secret dipilih!", 1.5) end)
DeleteTab:AddButton("⬜ Kosongkan Pilihan (Uncheck All)", function()
    table.clear(CurrentConfig.SelectedPlants)
    for _, ref in pairs(plantCardRefs) do ref:SetChecked(false) end
    Notify("Deselect All", "Semua pilihan tanaman dikosongkan.", 2)
end)

DeleteTab:AddSection("Checklist Tanaman In-Game")
for _, plant in ipairs(REAL_PLANTS_CATALOG) do
    local ref = DeleteTab:AddPlantCard(plant.name, plant.rarity)
    plantCardRefs[plant.name:lower()] = ref
end

-- =========================================================================
-- 📑 TAB 3: 🎁 AUTO CLAIM
-- =========================================================================
local ClaimTab = CreateTab("Auto Claim", "🎁")

local claimCard = Instance.new("Frame")
claimCard.Size = UDim2.new(1, 0, 0, 48)
claimCard.BackgroundColor3 = Color3.fromRGB(24, 18, 32)
claimCard.BorderSizePixel = 0
claimCard.ZIndex = 14
claimCard.Parent = ClaimTab.Page

local clCorner = Instance.new("UICorner")
clCorner.CornerRadius = UDim.new(0, 10)
clCorner.Parent = claimCard

local claimLabel = Instance.new("TextLabel")
claimLabel.Position = UDim2.new(0, 12, 0, 0)
claimLabel.Size = UDim2.new(1, -24, 1, 0)
claimLabel.BackgroundTransparency = 1
claimLabel.Text = "🎁 Smart Auto Claim: Playtime & Daily Ready"
claimLabel.TextColor3 = Color3.fromRGB(0, 230, 140)
claimLabel.TextSize = 12
claimLabel.Font = Enum.Font.GothamBold
claimLabel.TextXAlignment = Enum.TextXAlignment.Left
claimLabel.ZIndex = 15
claimLabel.Parent = claimCard

ClaimTab:AddSection("Pengaturan Klaim Hadiah")
local claimToggle = ClaimTab:AddToggle("Aktifkan Auto Claim Playtime & Daily", CurrentConfig.AutoClaim, function(state)
    CurrentConfig.AutoClaim = state
    if AutoClaim then
        AutoClaim.Toggle(state)
    end
    Notify("Auto Claim", state and "Auto Claim hadiah aktif!" or "Auto Claim dimatikan.", 2.5)
end)

ClaimTab:AddSection("Aksi Manual")
ClaimTab:AddButton("⚡ Scan & Klaim Semua Hadiah Sekarang", function()
    if AutoClaim and AutoClaim.Start then
        AutoClaim.Start()
        Notify("Auto Claim", "Memindai hadiah yang siap diklaim...", 2.5)
    end
end)

-- =========================================================================
-- 📑 TAB 4: ❄️ GRAPHICS & UTILITIES
-- =========================================================================
local UtilTab = CreateTab("Utilities", "❄️")

UtilTab:AddSection("Optimasi Grafis & FPS")
local potatoToggle = UtilTab:AddToggle("🥔 Potato Graphics (Hapus Partikel & Tekstur)", CurrentConfig.PotatoGraphics, function(state)
    CurrentConfig.PotatoGraphics = state
    if GraphicsModule then GraphicsModule.SetPotatoGraphics(state) end
    Notify("Graphics", state and "Potato Graphics diaktifkan!" or "Potato Graphics dimatikan.", 2)
end)

local antiLagToggle = UtilTab:AddToggle("❄️ Anti-Lag (FPS Cap 5 & Shadow Off)", CurrentConfig.AntiLag, function(state)
    CurrentConfig.AntiLag = state
    if GraphicsModule then GraphicsModule.SetAntiLag(state) end
    Notify("Anti-Lag", state and "Anti-Lag aktif (FPS 5)!" or "Anti-Lag dimatikan.", 2)
end)

local farmModeToggle = UtilTab:AddToggle("🚜 Farm Mode (Screen Off / Layar Gelap Saat AFK)", CurrentConfig.FarmMode, function(state)
    CurrentConfig.FarmMode = state
    if GraphicsModule then GraphicsModule.SetFarmMode(state) end
    Notify("Farm Mode", state and "Farm Mode aktif!" or "Farm Mode dimatikan.", 2)
end)

UtilTab:AddSection("Background Utilities")
local afkToggle = UtilTab:AddToggle("🛡️ Anti-AFK 24/7 (Idled Interception)", CurrentConfig.AntiAFK, function(state)
    CurrentConfig.AntiAFK = state
    if AFKModule then
        if state then AFKModule.Enable() else AFKModule.Disable() end
    end
    Notify("Anti-AFK", state and "Anti-AFK Aktif 24/7!" or "Anti-AFK Dimatikan.", 2)
end)

local pinkToggle = UtilTab:AddToggle("🚫 Destroyer Notifikasi Pink (Pop-up Cleaner)", CurrentConfig.PinkRemover, function(state)
    CurrentConfig.PinkRemover = state
    if PinkRemover then
        if state then PinkRemover.Start() else PinkRemover.Stop() end
    end
    Notify("Pink Destroyer", state and "Notifikasi pink dibersihkan!" or "Destroyer dimatikan.", 2)
end)

-- =========================================================================
-- 📑 TAB 5: ⚙️ SETTINGS & CONFIG MANAGER (ROLL ANIME STYLE)
-- =========================================================================
local SettingsTab = CreateTab("Settings", "⚙️")

SettingsTab:AddSection("💾 Simpan & Muat Config File")
SettingsTab:AddButton("💾 Simpan Config (Save Config)", function()
    local success = ConfigManager.Save(CurrentConfig)
    if success then
        Notify("Config Saved", "Pengaturan tersimpan di: " .. CONFIG_PATH, 3.0)
    else
        Notify("Config Error", "Gagal menyimpan file konfigurasi.", 2.5)
    end
end)

SettingsTab:AddButton("🔄 Muat Ulang Config (Load Config)", function()
    local loaded = ConfigManager.Load()
    if loaded then
        tutToggle:Set(loaded.AutoTutorial, false)
        deleteToggle:Set(loaded.AutoDelete, false)
        claimToggle:Set(loaded.AutoClaim, false)
        potatoToggle:Set(loaded.PotatoGraphics, false)
        antiLagToggle:Set(loaded.AntiLag, false)
        farmModeToggle:Set(loaded.FarmMode, false)
        afkToggle:Set(loaded.AntiAFK, false)
        pinkToggle:Set(loaded.PinkRemover, false)

        for _, plant in ipairs(REAL_PLANTS_CATALOG) do
            local pKey = plant.name:lower()
            local isChk = (loaded.SelectedPlants and loaded.SelectedPlants[pKey] == true)
            if plantCardRefs[pKey] then
                plantCardRefs[pKey]:SetChecked(isChk)
            end
        end
        Notify("Config Loaded", "Pengaturan berhasil dimuat dari file JSON!", 2.5)
    else
        Notify("Config Error", "File konfigurasi belum ada atau rusak.", 2.5)
    end
end)

SettingsTab:AddButton("🗑️ Reset Config ke Default", function()
    ConfigManager.Reset()
    tutToggle:Set(DEFAULT_CONFIG.AutoTutorial, false)
    deleteToggle:Set(DEFAULT_CONFIG.AutoDelete, false)
    claimToggle:Set(DEFAULT_CONFIG.AutoClaim, false)
    potatoToggle:Set(DEFAULT_CONFIG.PotatoGraphics, false)
    antiLagToggle:Set(DEFAULT_CONFIG.AntiLag, false)
    farmModeToggle:Set(DEFAULT_CONFIG.FarmMode, false)
    afkToggle:Set(DEFAULT_CONFIG.AntiAFK, false)
    pinkToggle:Set(DEFAULT_CONFIG.PinkRemover, false)

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
SettingsTab:AddButton("🛑 Tutup & Unload Script", function() showUnloadModal() end)

-- =================================================================
-- ⚡ INITIAL EXECUTION BERDASARKAN CONFIG TERSIMPAN
-- =================================================================
task.spawn(function()
    task.wait(0.5)
    if CurrentConfig.PotatoGraphics and GraphicsModule then GraphicsModule.SetPotatoGraphics(true) end
    if CurrentConfig.AntiLag and GraphicsModule then GraphicsModule.SetAntiLag(true) end
    if CurrentConfig.FarmMode and GraphicsModule then GraphicsModule.SetFarmMode(true) end
    if CurrentConfig.AntiAFK and AFKModule then AFKModule.Enable() end
    if CurrentConfig.PinkRemover and PinkRemover then PinkRemover.Start() end
    if CurrentConfig.AutoClaim and AutoClaim then AutoClaim.Start() end
    if CurrentConfig.AutoDelete and AutoDelete then AutoDelete.Start() end
    if CurrentConfig.AutoTutorial and AutoTutorial then AutoTutorial.Start() end
end)

print("👑 [RITOD HUB] Capybaras vs Plants Ultra HD Loaded successfully with Config!")
