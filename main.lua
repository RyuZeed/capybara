-- =================================================================
-- 👑 RITOD HUB LITE (MODULAR & CLOUD LOADED)
-- Game: Capybaras vs Plants
-- GitHub: https://github.com/RyuZeed/capybara
-- =================================================================

task.wait(1)

-- 🧹 HAPUS PAKSA UI LAMA BILA ADA
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    for _, child in ipairs(pg:GetChildren()) do
        if child.Name == "CPU_RAM_Saver_GUI" or child.Name == "AFKScreenOff" or child.Name == "RitodHubLite" or child.Name == "PerfectAutoClaimTester" then
            child:Destroy()
        end
    end
end)

if _G.RitodHubLoaded and _G.RitodHubGui then
    pcall(function() _G.RitodHubGui:Destroy() end)
end
_G.RitodHubLoaded = true

-- =================================================================
-- 🌐 IMPORT MODUL DARI GITHUB
-- =================================================================
local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/"

local function loadModule(name)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. name .. ".lua"))()
    end)
    if success and result then
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

-- Auto Start background utilities
if AFKModule then AFKModule.Enable() end
if PinkRemover then PinkRemover.Start() end

-- =================================================================
-- 🎨 GUI CREATION (RITOD HUB LITE)
-- =================================================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RitodHubLite"
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
_G.RitodHubGui = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 280)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local ToggleIconBtn = Instance.new("TextButton")
ToggleIconBtn.Size = UDim2.new(0, 120, 0, 32)
ToggleIconBtn.Position = UDim2.new(0, 10, 0, 10)
ToggleIconBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
ToggleIconBtn.Text = "👑 RITOD HUB"
ToggleIconBtn.TextColor3 = Color3.fromRGB(0, 230, 138)
ToggleIconBtn.TextSize = 12
ToggleIconBtn.Font = Enum.Font.FredokaOne
ToggleIconBtn.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleIconBtn

ToggleIconBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 0, 30)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "👑 RITOD HUB LITE"
Title.TextColor3 = Color3.fromRGB(0, 230, 138)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
MinimizeBtn.Position = UDim2.new(1, -30, 0, 3)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Text = "➖"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.TextSize = 12
MinimizeBtn.Parent = MainFrame

MinimizeBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Size = UDim2.new(1, -16, 1, -40)
ContentScroll.Position = UDim2.new(0, 8, 0, 35)
ContentScroll.BackgroundTransparency = 1
ContentScroll.ScrollBarThickness = 3
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentScroll.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = ContentScroll

-- Canvas otomatis mengikuti tinggi tombol
UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ContentScroll.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
end)

local function createToggle(text, initialState, callback)
    local state = initialState or false

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = ContentScroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local function updateVisual(val)
        state = (val ~= nil) and val or state
        if state then
            btn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
            btn.Text = text .. " [ ON ]"
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            btn.Text = text .. " [ OFF ]"
            btn.TextColor3 = Color3.fromRGB(170, 170, 170)
        end
    end

    updateVisual(initialState)

    btn.MouseButton1Click:Connect(function()
        state = not state
        updateVisual(state)
        callback(state)
    end)

    return updateVisual
end

-- =================================================================
-- 🔘 DAFTAR TOMBOL FITUR DI GUI
-- =================================================================

createToggle("🚀 Auto Tutorial", true, function(state)
    if state and AutoTutorial then
        AutoTutorial.Start()
    end
end)

local updateFarmModeBtn
updateFarmModeBtn = createToggle("🚜 Farm Mode (Screen Off)", false, function(state)
    if GraphicsModule then GraphicsModule.SetFarmMode(state) end
end)

createToggle("❄️ Anti-Lag (FPS Cap 5)", false, function(state)
    if GraphicsModule then GraphicsModule.SetAntiLag(state) end
end)

createToggle("🥔 Potato Graphics", false, function(state)
    if GraphicsModule then GraphicsModule.EnablePotato(state) end
end)

createToggle("🎁 Auto Claim Rewards", true, function(state)
    if AutoClaim then
        if state then AutoClaim.Start() else AutoClaim.Stop() end
    end
end)

-- Auto start initial toggles
if AutoClaim then task.spawn(AutoClaim.Start) end
if AutoTutorial then task.spawn(AutoTutorial.Start) end

print("👑 [RITOD HUB LITE] Modular Cloud Edition Loaded Successfully!")
