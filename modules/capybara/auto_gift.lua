--[[
    ===========================================================================
    🌌 GALAXY AUTO GIFT & AUTO ACCEPT ENGINE (UNIFIED & 5S TP EDITION)
    Game: Capybaras vs Plants (Roblox PlaceId: 104973076655377)
    Author: Feldway / Ritod Hub
    Compatibility: Solara, Wave, Delta, Fluxus, Codex, Synapse, Arceus, etc.
    ===========================================================================
    📋 FITUR UTAMA & UPDATE TATA LETAK:
      1. ⚡ UNIFIED AUTO GIFT TAB:
         - Menu "Pilih Player" kini disatukan LANGSUNG di dalam Tab Auto Gift!
         - Tidak perlu lagi berpindah-pindah tab untuk memilih akun target.
      2. 🎁 AUTO ACCEPT GIFT (TERIMA HADIAH OTOMATIS):
         - Ditambahkan tepat di bawah toggle Smart Auto Gift.
         - Otomatis menekan "Accept" / "Terima" / "Yes" / "Confirm" saat menerima
           kiriman gift dari akun lain (cocok untuk akun penerima/alt).
      3. 🧬 OFFICIAL IN-GAME MUTATION DATABASE (MutationData):
         - 14 Mutasi resmi (Radiant, Rainbow, Gold, Scorched, Permafrost, dll.)
           otomatis dinormalisasi ke Base Name dan dihitung total stoknya.
      4. ⚡ INSTANT CHAIN-GIFTING:
         - Deteksi real-time cepat (0.15s) saat target menekan "Accept".
         - Begitu item diterima, langsung lanjut meng-equip & men-gift item berikutnya!
      5. 📍 5-SECOND TELEPORT PACING:
         - Teleport ke target hanya setiap 5 detik sekali (halus, stabil, anti-jitter).
      6. 🛑 SMART ANTI-SPAM:
         - Hanya menembak prompt 1 kali per item dan menunggu respon target.
      7. 💎 KHUSUS PLANT & CAPYBARA DIVINE, GODLY, SECRET (Gift-able).
      8. ⌨️ KEYBIND: Tekan [Right Control] untuk Buka/Tutup GUI.
    ===========================================================================
--]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local CoreGui             = game:GetService("CoreGui")
local StarterGui          = game:GetService("StarterGui")

local LocalPlayer         = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

-- ─── GLOBAL CLEANUP PADA EKSEKUSI ULANG ─────────────────────────────────────
if getgenv and getgenv().CapybaraAutoGift_Cleanup then
    pcall(getgenv().CapybaraAutoGift_Cleanup)
end

local ScriptActive = true
local CleanupConnections = {}

local function GlobalCleanup()
    ScriptActive = false
    for _, conn in ipairs(CleanupConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(CleanupConnections)

    local pGui = CoreGui:FindFirstChild("RobloxGui") or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))
    if pGui and pGui:FindFirstChild("Capybara_Feldway_AutoGift") then
        pGui.Capybara_Feldway_AutoGift:Destroy()
    end
end

if getgenv then
    getgenv().CapybaraAutoGift_Cleanup = GlobalCleanup
end

-- ─── 🧬 OFFICIAL IN-GAME MUTATION DATABASE (MutationData) ───────────────────
local OFFICIAL_MUTATIONS = {
    ["Radiant"]    = { mult = 3.00, icon = "🌟" },
    ["Rainbow"]    = { mult = 2.00, icon = "🌈" },
    ["Gold"]       = { mult = 1.00, icon = "🪙" },
    ["Golden"]     = { mult = 1.00, icon = "🪙" },
    ["Glitched"]   = { mult = 1.00, icon = "👾" },
    ["Flipped"]    = { mult = 1.00, icon = "🔄" },
    ["Taco"]       = { mult = 1.00, icon = "🌮" },
    ["Scorched"]   = { mult = 0.90, icon = "🔥" },
    ["Permafrost"] = { mult = 0.80, icon = "❄️" },
    ["Celestial"]  = { mult = 0.70, icon = "🌌" },
    ["Shocked"]    = { mult = 0.60, icon = "⚡" },
    ["Tranquil"]   = { mult = 0.45, icon = "🍃" },
    ["Toasty"]     = { mult = 0.40, icon = "🍞" },
    ["Chilly"]     = { mult = 0.40, icon = "🧊" },
    ["Moonlit"]    = { mult = 0.30, icon = "🌙" },
}

pcall(function()
    local mod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("MutationData")
    if mod and mod:IsA("ModuleScript") then
        local data = require(mod)
        if type(data) == "table" then
            for mName, val in pairs(data) do
                if type(val) == "number" and not OFFICIAL_MUTATIONS[mName] then
                    OFFICIAL_MUTATIONS[mName] = { mult = val, icon = "🧬" }
                end
            end
        end
    end
end)

-- ─── 🎨 RARITY COLORS & OFFICIAL GIFT-ABLE DIVINE+ CATALOG ──────────────────
local RARITY_COLORS = {
    ["Divine"] = Color3.fromRGB(255, 160, 220), -- Sakura Magenta
    ["Godly"]  = Color3.fromRGB(255, 110, 240), -- Neon Fuchsia
    ["Secret"] = Color3.fromRGB(0, 255, 230),   -- Electric Aqua Cyan
}

local DIVINE_PLUS_CATALOG = {
    -- ─── ✨ DIVINE TIER ───
    { name = "Carnivorous Plant",   rarity = "Divine", category = "Plant",    icon = "🪴" },
    { name = "Mandrake",            rarity = "Divine", category = "Plant",    icon = "🌱" },
    { name = "Golem Capybara",      rarity = "Divine", category = "Capybara", icon = "🦫" },

    -- ─── ⚡ GODLY TIER ───
    { name = "Ghost Pepper",        rarity = "Godly",  category = "Plant",    icon = "🌶️" },
    { name = "Magic Mushroom",      rarity = "Godly",  category = "Plant",    icon = "🍄" },
    { name = "Robot Mushroom",      rarity = "Godly",  category = "Plant",    icon = "🤖" },
    { name = "Robot Capybara",      rarity = "Godly",  category = "Capybara", icon = "🦫" },

    -- ─── 🔮 SECRET TIER ───
    { name = "Pumpking",            rarity = "Secret", category = "Plant",    icon = "🎃" },
    { name = "True Carrot",         rarity = "Secret", category = "Plant",    icon = "🥕" },
    { name = "Disco Carrot",        rarity = "Secret", category = "Plant",    icon = "🪩" },
    { name = "Disco True Carrot",   rarity = "Secret", category = "Plant",    icon = "✨" },
    { name = "Pumpkin",             rarity = "Secret", category = "Plant",    icon = "🎃" },
    { name = "Dragonfruit",         rarity = "Secret", category = "Plant",    icon = "🐉" },
    { name = "Disco Capybara",      rarity = "Secret", category = "Capybara", icon = "🦫" },
    { name = "Angel Capybara",      rarity = "Secret", category = "Capybara", icon = "🦫" },
}

local SORTED_CATALOG = {}
for _, item in ipairs(DIVINE_PLUS_CATALOG) do
    table.insert(SORTED_CATALOG, item)
end
table.sort(SORTED_CATALOG, function(a, b)
    return #a.name > #b.name
end)

-- ─── 🧬 SMART MUTATION & ITEM PARSER ────────────────────────────────────────
local function ParseItemAndMutation(rawToolName)
    if not rawToolName or type(rawToolName) ~= "string" then return nil, nil end

    local clean = rawToolName:lower()
    clean = clean:gsub("%b[]", " ")
    clean = clean:gsub("%b()", " ")
    clean = clean:gsub("%b{}", " ")
    clean = clean:gsub("[^%w%s]", " ")
    clean = clean:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    local matchedItem = nil
    for _, item in ipairs(SORTED_CATALOG) do
        local baseClean = item.name:lower():gsub("[^%w%s]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if clean:find(baseClean, 1, true) or rawToolName:lower():find(item.name:lower(), 1, true) then
            matchedItem = item
            break
        end
    end

    if not matchedItem then return nil, nil end

    local detectedMutation = nil
    for mutName, mutData in pairs(OFFICIAL_MUTATIONS) do
        local mLower = mutName:lower()
        if clean:find(mLower, 1, true) or rawToolName:lower():find(mLower, 1, true) then
            detectedMutation = { name = mutName, mult = mutData.mult, icon = mutData.icon }
            break
        end
    end

    return matchedItem, detectedMutation
end

local function GetBaseCatalogItem(rawToolName)
    local item, _ = ParseItemAndMutation(rawToolName)
    return item
end

-- ─── CONFIGURATION & STATE ──────────────────────────────────────────────────
local Config = {
    GiftEnabled       = false,
    AutoAcceptGift    = true,     -- Default ON: Otomatis terima hadiah masuk
    AttackDelay       = 0.15,     -- Polling 0.15s saat menunggu respon
    TeleportOffset    = "Front",  -- "Front", "Close", "Behind", "Above"
    TeleportInterval  = 5.0,      -- Teleport hanya setiap 5 detik sekali
    TargetPlayerName  = "",
    SelectedItems     = {},       -- [baseNameLower] = true (Checklist Map)
    AutoEquipTool     = true,
    AutoConfirmPopup  = true,
    Keybind           = Enum.KeyCode.RightControl
}

local Stats = {
    TotalGiftsAccepted= 0,
    TotalGiftsReceived= 0,
    TotalPromptsFired = 0,
    CurrentToolIndex  = 1,
    CurrentToolName   = "None",
    CurrentStatus     = "Menunggu konfigurasi...",
    StartTime         = tick()
}

-- ─── THEME PALETTE (FELDWAY GALAXY EDITION) ─────────────────────────────────
local T = {
    BG          = Color3.fromRGB(10, 16, 28),
    Sidebar     = Color3.fromRGB(14, 22, 38),
    Panel       = Color3.fromRGB(16, 26, 44),
    Card        = Color3.fromRGB(18, 30, 52),
    CardStroke  = Color3.fromRGB(34, 56, 92),
    CardActive  = Color3.fromRGB(24, 48, 88),
    Row         = Color3.fromRGB(22, 36, 60),
    RowOn       = Color3.fromRGB(24, 62, 48),
    Accent      = Color3.fromRGB(0, 195, 255),       -- Stellar Cyan
    Purple      = Color3.fromRGB(138, 75, 255),     -- Nebula Purple
    Green       = Color3.fromRGB(46, 204, 113),     -- Emerald
    Red         = Color3.fromRGB(231, 76, 60),      -- Crimson
    Orange      = Color3.fromRGB(243, 156, 18),
    Text        = Color3.fromRGB(240, 245, 255),
    Sub         = Color3.fromRGB(130, 150, 185),
    Dim         = Color3.fromRGB(75, 95, 130),
    Border      = Color3.fromRGB(32, 52, 86),
    ToggleOff   = Color3.fromRGB(26, 36, 60),
}

-- ─── HELPER UTILITIES ───────────────────────────────────────────────────────
local function corner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 6)
    return c
end

local function stroke(p, color, thickness)
    local s = Instance.new("UIStroke", p)
    s.Color = color or T.Border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function gradient(p, rot)
    local g = Instance.new("UIGradient", p)
    g.Rotation = rot or 45
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, T.Accent),
        ColorSequenceKeypoint.new(0.5, T.Purple),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(180, 100, 255))
    })
    return g
end

local function mkLabel(parent, text, size, color, font)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1
    l.Text = text or ""
    l.TextSize = size or 11
    l.TextColor3 = color or T.Text
    l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 1, 0)
    return l
end

local function mkBtn(parent, text, sz, pos, color)
    local b = Instance.new("TextButton", parent)
    b.Size = sz
    b.Position = pos or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3 = color or T.Panel
    b.Text = text
    b.TextColor3 = T.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.BorderSizePixel = 0
    corner(b, 6)
    return b
end

local function GetRoot(char)
    char = char or LocalPlayer.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

local function GetTargetPlayer()
    if not Config.TargetPlayerName or Config.TargetPlayerName == "" then return nil end
    local query = Config.TargetPlayerName:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if p.Name:lower() == query or p.DisplayName:lower() == query then
                return p
            end
        end
    end
    return nil
end

-- ─── FAST PROMPT CACHE SYSTEM ───────────────────────────────────────────────
local knownPrompts = {}

local function RegisterPrompt(inst)
    if inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
        knownPrompts[inst] = true
    end
end

for _, inst in ipairs(workspace:GetDescendants()) do
    RegisterPrompt(inst)
end

local addPromptConn = workspace.DescendantAdded:Connect(RegisterPrompt)
local remPromptConn = workspace.DescendantRemoving:Connect(function(inst)
    knownPrompts[inst] = nil
end)
table.insert(CleanupConnections, addPromptConn)
table.insert(CleanupConnections, remPromptConn)

-- ─── 🛠️ MULTI-VECTOR CLICK DISPATCHER ──────────────────────────────────────
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser         = game:GetService("VirtualUser")

local function ClickButtonElement(btn)
    if not btn or not (btn:IsA("GuiObject") or btn:IsA("Instance")) then return end

    -- Target actual button if btn is a wrapper frame
    local actualBtn = btn
    if btn:IsA("Frame") or btn:IsA("CanvasGroup") then
        local childBtn = btn:FindFirstChildWhichIsA("GuiButton") or btn:FindFirstChild("Button")
        if childBtn then actualBtn = childBtn end
    end

    -- 1. firesignal (Roblox Executor Signal Dispatch)
    if typeof(firesignal) == "function" then
        pcall(function()
            if actualBtn:IsA("GuiButton") then
                if actualBtn.Activated then pcall(firesignal, actualBtn.Activated) end
                if actualBtn.MouseButton1Click then pcall(firesignal, actualBtn.MouseButton1Click) end
                if actualBtn.MouseButton1Down then pcall(firesignal, actualBtn.MouseButton1Down) end
                if actualBtn.MouseButton1Up then pcall(firesignal, actualBtn.MouseButton1Up) end
                if actualBtn.TouchTap then pcall(firesignal, actualBtn.TouchTap) end
            end
            if btn ~= actualBtn and btn:IsA("GuiObject") then
                if btn.InputBegan then pcall(firesignal, btn.InputBegan) end
            end
        end)
    end

    -- 2. getconnections (Direct Lua Event Dispatch)
    if typeof(getconnections) == "function" then
        for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "TouchTap", "InputBegan"}) do
            pcall(function()
                local target = actualBtn[evName] and actualBtn or (btn[evName] and btn or nil)
                if target and target[evName] then
                    local conns = getconnections(target[evName])
                    if conns then
                        for _, conn in ipairs(conns) do
                            if conn.Function then
                                pcall(conn.Function)
                            elseif conn.Fire then
                                pcall(function() conn:Fire() end)
                            end
                        end
                    end
                end
            end)
        end
    end

    -- 3. VirtualInputManager (Hardware Mouse Simulation)
    pcall(function()
        local pos = actualBtn.AbsolutePosition
        local size = actualBtn.AbsoluteSize
        if size.X > 0 and size.Y > 0 then
            local cx = math.floor(pos.X + size.X / 2)
            local cy = math.floor(pos.Y + size.Y / 2)

            if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
                pcall(function()
                    VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                    task.wait(0.01)
                    VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
                end)
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                    task.wait(0.01)
                    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
                end)
            end
        end
    end)

    -- 4. VirtualUser Fallback
    pcall(function()
        if VirtualUser then
            VirtualUser:CaptureController()
            local pos = actualBtn.AbsolutePosition
            local size = actualBtn.AbsoluteSize
            if size.X > 0 and size.Y > 0 then
                VirtualUser:ClickButton1(Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2))
            end
        end
    end)

    -- 5. GuiObject:Activate() method fallback
    pcall(function()
        if typeof(actualBtn.Activate) == "function" then
            actualBtn:Activate()
        end
        if actualBtn ~= btn and typeof(btn.Activate) == "function" then
            btn:Activate()
        end
    end)
end

-- ─── 🌐 NETWORK LAYER HOOKS (INSTANT CLIENT-SIDE ACCEPT) ────────────────────
local function HookGiftAndConfirmRemotes()
    local searchContainers = {
        ReplicatedStorage,
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage:FindFirstChild("Packages")
    }

    for _, container in ipairs(searchContainers) do
        if container then
            for _, item in ipairs(container:GetDescendants()) do
                if item:IsA("RemoteFunction") then
                    local nameLower = item.Name:lower()
                    if nameLower:find("gift") or nameLower:find("confirm") or nameLower:find("answer") or nameLower:find("trade") or nameLower:find("request") then
                        pcall(function()
                            local rawCallback = item.OnClientInvoke
                            item.OnClientInvoke = function(...)
                                if Config.AutoAcceptGift or Config.AutoConfirmPopup then
                                    return true
                                end
                                if rawCallback then
                                    return rawCallback(...)
                                end
                                return true
                            end
                        end)
                    end
                elseif item:IsA("RemoteEvent") then
                    local nameLower = item.Name:lower()
                    if nameLower:find("gift") or nameLower:find("confirm") or nameLower:find("trade") then
                        pcall(function()
                            item.OnClientEvent:Connect(function(...)
                                if Config.AutoAcceptGift or Config.AutoConfirmPopup then
                                    local answerRF = container:FindFirstChild("RequestGiftAnswer") or container:FindFirstChild("GiftAnswer") or container:FindFirstChild("ConfirmGift")
                                    if answerRF and answerRF:IsA("RemoteEvent") then
                                        pcall(function() answerRF:FireServer(true) end)
                                    end
                                end
                            end)
                        end)
                    end
                end
            end
        end
    end
end

pcall(HookGiftAndConfirmRemotes)

-- ─── 🎁 EXACT UI SCANNER & AUTO-ACCEPT GIFT ENGINE ─────────────────────────
local function AutoAcceptAndConfirmPopups()
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pGui then return end

    -- 1. Scan MainGui Root Frames if present
    local mainGui = pGui:FindFirstChild("MainGui")
    if mainGui and mainGui:FindFirstChild("Root") and mainGui.Root:FindFirstChild("Frames") then
        local frames = mainGui.Root.Frames
        local popupNames = {"GiftRequest", "GiftPrompt", "Gift", "Confirm", "ConfirmFrame", "ReceiveGift", "Prompt"}

        for _, pName in ipairs(popupNames) do
            local popFrame = frames:FindFirstChild(pName)
            if popFrame and popFrame.Visible then
                for _, yesName in ipairs({"Yes", "Accept", "Confirm", "Button", "Ok"}) do
                    local yesFrame = popFrame:FindFirstChild(yesName)
                    if yesFrame then
                        ClickButtonElement(yesFrame)
                    end
                end
            end
        end
    end

    -- 2. Dynamic Fallback Scanner (Scan all visible popups in PlayerGui)
    local confirmKeywords = {"accept", "terima", "yes", "confirm", "send", "ok", "give", "gift", "ya", "setuju", "kirim", "trade", "claim", "ambil", "allow", "receive"}
    local rejectKeywords  = {"no", "exit", "close", "decline", "cancel", "reject", "batal", "tidak"}

    for _, sg in ipairs(pGui:GetChildren()) do
        if sg:IsA("ScreenGui") and sg.Enabled and sg.Name ~= "Capybara_Feldway_AutoGift" then
            for _, elem in ipairs(sg:GetDescendants()) do
                if elem:IsA("GuiObject") and elem.Visible then
                    local p = elem.Parent
                    local gp = p and p.Parent
                    local text = (elem:IsA("TextButton") or elem:IsA("TextLabel") and elem.Text or ""):lower()
                    local name = elem.Name:lower()
                    local pName = p and p.Name:lower() or ""
                    local gpName = gp and gp.Name:lower() or ""

                    local isMatch = false
                    for _, kw in ipairs(confirmKeywords) do
                        if text == kw or text:find(kw, 1, true) or name == kw or name:find(kw, 1, true) or pName == kw or pName:find(kw, 1, true) or gpName == kw or gpName:find(kw, 1, true) then
                            local isReject = false
                            for _, rkw in ipairs(rejectKeywords) do
                                if text:find(rkw, 1, true) or name:find(rkw, 1, true) or pName:find(rkw, 1, true) then
                                    isReject = true
                                    break
                                end
                            end
                            if not isReject then
                                isMatch = true
                                break
                            end
                        end
                    end

                    if isMatch then
                        ClickButtonElement(elem)
                    end
                end
            end
        end
    end
end

-- Auto Accept Worker Loop (Fast 0.05s polling + Instant Descendant Listener)
local pGuiRef = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if pGuiRef then
    pGuiRef.DescendantAdded:Connect(function(desc)
        if Config.AutoAcceptGift or Config.AutoConfirmPopup then
            task.wait(0.02)
            AutoAcceptAndConfirmPopups()
        end
    end)
end

task.spawn(function()
    while ScriptActive do
        task.wait(0.05)
        if Config.AutoAcceptGift or Config.AutoConfirmPopup then
            AutoAcceptAndConfirmPopups()
            HookGiftAndConfirmRemotes()
        end
    end
end)

-- ─── INVENTORY SCANNER & SMART MUTATION COMBINER ────────────────────────────
local function ScanAvailableTools()
    local toolsCountByBaseName = {}
    local mutationCountByBase = {}
    local toolsList = {}

    local function processTool(t)
        if not t:IsA("Tool") then return end
        local baseItem, mut = ParseItemAndMutation(t.Name)
        if baseItem then
            local bName = baseItem.name
            local bKey  = bName:lower()
            toolsCountByBaseName[bName] = (toolsCountByBaseName[bName] or 0) + 1
            toolsCountByBaseName[bKey]  = (toolsCountByBaseName[bKey] or 0) + 1
            
            if mut then
                mutationCountByBase[bKey] = (mutationCountByBase[bKey] or 0) + 1
            end

            table.insert(toolsList, { tool = t, baseName = bName, baseKey = bKey, mutation = mut })
        end
    end

    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do processTool(t) end
    end

    local char = LocalPlayer.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do processTool(t) end
    end

    return toolsCountByBaseName, mutationCountByBase, toolsList
end

local function IsItemMatchSelected(toolName)
    local baseItem = GetBaseCatalogItem(toolName)
    if baseItem then
        local bKey = baseItem.name:lower()
        return Config.SelectedItems[bKey] == true
    end
    return false
end

local function GetNextToolToEquip(char)
    if not Config.AutoEquipTool then return nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp and not char then return nil end

    local candidateTools = {}
    
    local function checkContainer(container)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") and IsItemMatchSelected(t.Name) then
                table.insert(candidateTools, t)
            end
        end
    end

    checkContainer(char)
    checkContainer(bp)

    if #candidateTools == 0 then
        return char and char:FindFirstChildOfClass("Tool")
    end

    if Stats.CurrentToolIndex > #candidateTools then
        Stats.CurrentToolIndex = 1
    end

    local selectedTool = candidateTools[Stats.CurrentToolIndex]

    if selectedTool and selectedTool.Parent ~= char then
        pcall(function()
            selectedTool.Parent = char
        end)
        task.wait(0.04)
    end

    local baseItem, mut = ParseItemAndMutation(selectedTool and selectedTool.Name or "")
    if baseItem then
        if mut then
            Stats.CurrentToolName = string.format("[%s%s] %s", mut.icon, mut.name, baseItem.name)
        else
            Stats.CurrentToolName = baseItem.name
        end
    else
        Stats.CurrentToolName = selectedTool and selectedTool.Name or "None"
    end

    return selectedTool
end

-- ─── TELEPORT & 5-DETIK POSITIONING ENGINE ──────────────────────────────────
local lastTeleportTick = 0

local function CalculateTargetCFrame(targetRoot)
    local pos = targetRoot.Position
    local look = targetRoot.CFrame.LookVector

    if Config.TeleportOffset == "Front" then
        local frontPos = pos + (look * 2.2)
        return CFrame.new(frontPos, pos)
    elseif Config.TeleportOffset == "Behind" then
        local behindPos = pos - (look * 2.0)
        return CFrame.new(behindPos, pos)
    elseif Config.TeleportOffset == "Above" then
        return CFrame.new(pos + Vector3.new(0, 1.8, 0))
    else
        return CFrame.new(pos + (look * 1.2), pos)
    end
end

local function StepTeleport5s(root, targetRoot, force)
    local now = tick()
    if force or (now - lastTeleportTick) >= Config.TeleportInterval then
        lastTeleportTick = now
        local targetCF = CalculateTargetCFrame(targetRoot)
        pcall(function()
            if root:IsA("BasePart") then
                root.CFrame = targetCF
                if root.AssemblyLinearVelocity then
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                else
                    root.Velocity = Vector3.new(0, 0, 0)
                    root.RotVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    end
end

-- ─── SMART INSTANT-CHAIN AUTO-GIFT ENGINE THREAD ────────────────────────────
local statusLabelRef = nil
local targetStatsLabelRef = nil
local toolStatsLabelRef = nil

local pendingGiftTool   = nil   -- Tool instance yang sedang menunggu di-accept
local pendingToolName   = ""
local pendingStartTime  = 0
local PENDING_TIMEOUT   = 8.0   -- Maksimal detik menunggu sebelum timeout jika target tidak klik Accept
local giftCycleSignal   = Instance.new("BindableEvent")

local function TriggerNextGiftCycle()
    pcall(function() giftCycleSignal:Fire() end)
end

task.spawn(function()
    while ScriptActive do
        local stepWait = Config.AttackDelay
        if not Config.GiftEnabled then
            if statusLabelRef then
                statusLabelRef.Text = "  Status : 🔴 Nonaktif"
                statusLabelRef.TextColor3 = T.Sub
            end
            pendingGiftTool = nil
            task.wait(0.2)
            continue
        end

        local targetPlayer = GetTargetPlayer()
        if not targetPlayer or not targetPlayer.Parent then
            if statusLabelRef then
                statusLabelRef.Text = "  Status : ⚠️ Target player tidak ada di server"
                statusLabelRef.TextColor3 = T.Orange
            end
            pendingGiftTool = nil
            task.wait(0.5)
            continue
        end

        local char = LocalPlayer.Character
        local root = GetRoot(char)
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not char or not root then
            task.wait(0.2)
            continue
        end

        local targetChar = targetPlayer.Character
        local targetRoot = targetChar and GetRoot(targetChar)
        if not targetChar or not targetRoot then
            if statusLabelRef then
                statusLabelRef.Text = ("  Status : Menunggu spawn %s..."):format(targetPlayer.DisplayName)
                statusLabelRef.TextColor3 = T.Orange
            end
            task.wait(0.3)
            continue
        end

        -- 1. 📍 TELEPORT HANYA SETIAP 5 DETIK SEKALI
        StepTeleport5s(root, targetRoot, false)

        -- 2. ⚡ DETEKSI REAL-TIME HASIL ACCEPT TARGET (INSTANT CHAIN-GIFTING)
        if pendingGiftTool then
            local stillExists = false
            if pendingGiftTool.Parent and (pendingGiftTool:IsDescendantOf(char) or (bp and pendingGiftTool:IsDescendantOf(bp))) then
                stillExists = true
            end

            if not stillExists then
                -- 🎉 TARGET SUDAH MENERIMA GIFT! SEGERA KIRIM HADIAH BERIKUTNYA TAMPA DELAY!
                Stats.TotalGiftsAccepted = Stats.TotalGiftsAccepted + 1
                if statusLabelRef then
                    statusLabelRef.Text = ("  Status : 🟢 %s DITERIMA %s! (Total: %d)"):format(
                        pendingToolName,
                        targetPlayer.DisplayName,
                        Stats.TotalGiftsAccepted
                    )
                    statusLabelRef.TextColor3 = T.Green
                end
                if toolStatsLabelRef then
                    local count = 0
                    for _, isSel in pairs(Config.SelectedItems) do if isSel then count = count + 1 end end
                    toolStatsLabelRef.Text = string.format("  Divine+ Terpilih: %d Item  |  Total Berhasil Diterima: %d", count, Stats.TotalGiftsAccepted)
                end

                pendingGiftTool = nil
                pendingStartTime = 0
                Stats.CurrentToolIndex = 1 -- Reset index ke item pertama yang tersedia di tas
                -- ALUR LANGSUNG DILANJUTKAN KE STEP 3 DI BAWAH TANPA CONTINUE!
            else
                local elapsed = tick() - pendingStartTime
                if elapsed < PENDING_TIMEOUT then
                    if statusLabelRef then
                        statusLabelRef.Text = ("  Status : ⏳ Menunggu %s menerima %s (%.1fs)..."):format(
                            targetPlayer.DisplayName,
                            pendingToolName,
                            elapsed
                        )
                        statusLabelRef.TextColor3 = T.Orange
                    end
                    AutoAcceptAndConfirmPopups()
                    -- Tunggu sinyal real-time jika item di-accept atau timeout singkat
                    local race = false
                    local conn = pendingGiftTool.AncestryChanged:Connect(function()
                        race = true
                        TriggerNextGiftCycle()
                    end)
                    task.spawn(function()
                        task.wait(0.2)
                        if not race then TriggerNextGiftCycle() end
                    end)
                    giftCycleSignal.Event:Wait()
                    if conn then pcall(function() conn:Disconnect() end) end
                    continue
                else
                    pendingGiftTool = nil
                    pendingStartTime = 0
                    Stats.CurrentToolIndex = 1
                end
            end
        end

        -- 3. AUTO-EQUIP SELECTED DIVINE+ TOOL & ACTIVATE
        local tool = GetNextToolToEquip(char)
        if not tool then
            if statusLabelRef then
                statusLabelRef.Text = "  Status : ⚠️ Tidak ada item Divine+ terpilih di dalam tas"
                statusLabelRef.TextColor3 = T.Orange
            end
            task.wait(0.5)
            continue
        end

        pcall(function() tool:Activate() end)

        -- 4. SCAN PROXIMITY PROMPT PADA TARGET PLAYER & WORKSPACE
        local targetPrompts = {}
        local distThreshold = 30

        for _, d in ipairs(targetChar:GetDescendants()) do
            if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
                table.insert(targetPrompts, d)
            end
        end

        for prompt, _ in pairs(knownPrompts) do
            if prompt and prompt.Parent and prompt:IsDescendantOf(workspace) and not prompt:IsDescendantOf(char) then
                local pParent = prompt.Parent
                local pPart = pParent:IsA("BasePart") and pParent or pParent:FindFirstChildWhichIsA("BasePart")
                if pPart then
                    local d = (pPart.Position - targetRoot.Position).Magnitude
                    if d <= distThreshold then
                        table.insert(targetPrompts, prompt)
                    end
                end
            end
        end

        -- 5. TEMBAK PROMPT GIFT & TRANSMIT KE TARGET
        local firedCount = 0
        for _, prompt in ipairs(targetPrompts) do
            if prompt:IsA("ProximityPrompt") and prompt.Parent then
                local origMax = prompt.MaxActivationDistance
                local origHold = prompt.HoldDuration
                local origLos = prompt.RequiresLineOfSight
                local origEnabled = prompt.Enabled

                pcall(function()
                    prompt.Enabled = true
                    prompt.MaxActivationDistance = 9999
                    prompt.RequiresLineOfSight = false
                    prompt.HoldDuration = 0
                end)

                pcall(fireproximityprompt, prompt)
                firedCount = firedCount + 1

                pcall(function()
                    prompt.MaxActivationDistance = origMax
                    prompt.HoldDuration = origHold
                    prompt.RequiresLineOfSight = origLos
                    prompt.Enabled = origEnabled
                end)
            elseif prompt:IsA("ClickDetector") and prompt.Parent then
                pcall(fireclickdetector, prompt)
                firedCount = firedCount + 1
            end
        end

        -- 6. TOUCH INTEREST & AUTO-CONFIRM DIALOGS
        pcall(firetouchinterest, root, targetRoot, 0)
        pcall(firetouchinterest, root, targetRoot, 1)
        AutoAcceptAndConfirmPopups()

        -- 7. KUNCI STATUS PENDING & PASANG REAL-TIME ANCESTRY LISTENER
        if tool then
            local baseItem, mut = ParseItemAndMutation(tool.Name)
            if baseItem and mut then
                pendingToolName = string.format("[%s%s] %s", mut.icon, mut.name, baseItem.name)
            else
                pendingToolName = baseItem and baseItem.name or tool.Name
            end
            
            pendingGiftTool = tool
            pendingStartTime = tick()
            Stats.TotalPromptsFired = Stats.TotalPromptsFired + (firedCount > 0 and firedCount or 1)

            -- Real-time Ancestry Listener: Begitu tool meninggalkan sender, langsung trigger gift berikutnya!
            local conn
            conn = tool.AncestryChanged:Connect(function()
                if not (tool.Parent and (tool:IsDescendantOf(char) or (bp and tool:IsDescendantOf(bp)))) then
                    if conn then pcall(function() conn:Disconnect() end) end
                    TriggerNextGiftCycle()
                end
            end)

            if statusLabelRef then
                statusLabelRef.Text = ("  Status : 📤 Mengirim %s ke %s..."):format(
                    pendingToolName,
                    targetPlayer.DisplayName
                )
                statusLabelRef.TextColor3 = T.Accent
            end
        end
    end
end)

-- ─── GALAXY USER INTERFACE BUILDER ──────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Capybara_Feldway_AutoGift"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true

local parentGui = CoreGui:FindFirstChild("RobloxGui") or (LocalPlayer and LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Parent = parentGui

local WIN_W = 600
local WIN_H = 475

local Main = Instance.new("Frame", ScreenGui)
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, WIN_W, 0, WIN_H)
Main.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)
Main.BackgroundColor3 = T.BG
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
corner(Main, 10)
stroke(Main, T.Border, 1.5)

-- Draggable Logic
local isDragging = false
local dragStart, startPos

local TopBar = Instance.new("Frame", Main)
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.BackgroundColor3 = T.Sidebar
TopBar.BorderSizePixel = 0

local TopGrad = Instance.new("Frame", TopBar)
TopGrad.Size = UDim2.new(1, 0, 0, 2)
TopGrad.Position = UDim2.new(0, 0, 1, -2)
TopGrad.BorderSizePixel = 0
gradient(TopGrad, 0)

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

local TitleLbl = mkLabel(TopBar, "🌌 SMART AUTO GIFT & AUTO ACCEPT (5S TP)", 12, T.Text, Enum.Font.GothamBold)
TitleLbl.Position = UDim2.new(0, 14, 0, 0)
TitleLbl.Size = UDim2.new(0.75, 0, 1, 0)

local CloseBtn = mkBtn(TopBar, "✕", UDim2.new(0, 26, 0, 26), UDim2.new(1, -36, 0.5, -13), T.Card)
CloseBtn.TextColor3 = T.Red
stroke(CloseBtn, T.Border, 1)
CloseBtn.MouseButton1Click:Connect(GlobalCleanup)

local MinBtn = mkBtn(TopBar, "—", UDim2.new(0, 26, 0, 26), UDim2.new(1, -68, 0.5, -13), T.Card)
MinBtn.TextColor3 = T.Sub
stroke(MinBtn, T.Border, 1)

local isMin = false
MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    TweenService:Create(Main, TweenInfo.new(0.22), { Size = isMin and UDim2.new(0, WIN_W, 0, 44) or UDim2.new(0, WIN_W, 0, WIN_H) }):Play()
end)

-- ─── SIDEBAR & 2 STREAMLINED TABS ───────────────────────────────────────────
local SIDE_W = 145
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0, SIDE_W, 1, -44)
Sidebar.Position = UDim2.new(0, 0, 0, 44)
Sidebar.BackgroundColor3 = T.Sidebar
Sidebar.BorderSizePixel = 0
stroke(Sidebar, T.Border, 1)

local Container = Instance.new("Frame", Main)
Container.Size = UDim2.new(1, -SIDE_W, 1, -44)
Container.Position = UDim2.new(0, SIDE_W, 0, 44)
Container.BackgroundTransparency = 1

local Pages = {}
local TabBtns = {}
local ActiveTab = "AutoGift"

local function ShowTab(name)
    ActiveTab = name
    for n, page in pairs(Pages) do page.Visible = (n == name) end
    for n, btn in pairs(TabBtns) do
        local on = (n == name)
        btn.BackgroundColor3 = on and T.CardActive or T.Sidebar
        btn.TextColor3 = on and T.Accent or T.Sub
    end
end

local TabConfig = {
    { Id = "AutoGift", Label = "⚡ Auto Gift" },
    { Id = "Tools",    Label = "💎 Divine+ Items" },
}

local sLayout = Instance.new("UIListLayout", Sidebar)
sLayout.Padding = UDim.new(0, 6)
sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local sPad = Instance.new("UIPadding", Sidebar)
sPad.PaddingTop = UDim.new(0, 10)

for _, tDef in ipairs(TabConfig) do
    local btn = mkBtn(Sidebar, "  " .. tDef.Label, UDim2.new(0.9, 0, 0, 38), nil, T.Sidebar)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextColor3 = T.Sub
    btn.TextSize = 11
    stroke(btn, T.Border, 1)
    TabBtns[tDef.Id] = btn

    local page = Instance.new("ScrollingFrame", Container)
    page.Name = tDef.Id .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = T.Accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false

    local pPad = Instance.new("UIPadding", page)
    pPad.PaddingTop = UDim.new(0, 10)
    pPad.PaddingBottom = UDim.new(0, 12)
    pPad.PaddingLeft = UDim.new(0, 10)
    pPad.PaddingRight = UDim.new(0, 10)

    local pLayout = Instance.new("UIListLayout", page)
    pLayout.Padding = UDim.new(0, 8)
    pLayout.SortOrder = Enum.SortOrder.LayoutOrder

    Pages[tDef.Id] = page
    btn.MouseButton1Click:Connect(function() ShowTab(tDef.Id) end)
end

-- ─── TAB 1: UNIFIED AUTO GIFT (TOGGLES + ACCEPT + PILIH PLAYER) ─────────────
local GiftPage = Pages["AutoGift"]

-- 1. Master Auto Gift Toggle Card
local MasterCard = Instance.new("Frame", GiftPage)
MasterCard.Size = UDim2.new(1, 0, 0, 68)
MasterCard.BackgroundColor3 = T.Card
corner(MasterCard, 8)
stroke(MasterCard, T.Border, 1)

local MasterTitle = mkLabel(MasterCard, "⚡ SMART AUTO GIFT (MUTATION INTEGRATED)", 11, T.Accent, Enum.Font.GothamBold)
MasterTitle.Position = UDim2.new(0, 14, 0, 8)
MasterTitle.Size = UDim2.new(0.68, 0, 0, 18)

statusLabelRef = mkLabel(MasterCard, "  Status : 🔴 Nonaktif", 10, T.Sub, Enum.Font.GothamSemibold)
statusLabelRef.Position = UDim2.new(0, 10, 0, 28)
statusLabelRef.Size = UDim2.new(0.68, 0, 0, 16)

local detailLabel = mkLabel(MasterCard, "  Otomatis satukan semua mutasi resmi ke default name & chain-gift", 9, T.Dim)
detailLabel.Position = UDim2.new(0, 10, 0, 46)
detailLabel.Size = UDim2.new(0.68, 0, 0, 16)

local MasterToggleBtn = mkBtn(MasterCard, "OFF", UDim2.new(0, 75, 0, 32), UDim2.new(1, -88, 0.5, -16), T.ToggleOff)
MasterToggleBtn.TextSize = 11
corner(MasterToggleBtn, 16)

MasterToggleBtn.MouseButton1Click:Connect(function()
    Config.GiftEnabled = not Config.GiftEnabled
    MasterToggleBtn.BackgroundColor3 = Config.GiftEnabled and T.Green or T.ToggleOff
    MasterToggleBtn.Text = Config.GiftEnabled and "ON" or "OFF"
    pendingGiftTool = nil
    lastTeleportTick = 0
end)

-- 2. Auto Accept Gift Toggle Card
local AcceptCard = Instance.new("Frame", GiftPage)
AcceptCard.Size = UDim2.new(1, 0, 0, 64)
AcceptCard.BackgroundColor3 = T.Card
corner(AcceptCard, 8)
stroke(AcceptCard, T.Border, 1)

local AcceptTitle = mkLabel(AcceptCard, "🎁 AUTO ACCEPT GIFT (TERIMA HADIAH OTOMATIS)", 11, Color3.fromRGB(160, 230, 255), Enum.Font.GothamBold)
AcceptTitle.Position = UDim2.new(0, 14, 0, 8)
AcceptTitle.Size = UDim2.new(0.68, 0, 0, 18)

local acceptStatusLbl = mkLabel(AcceptCard, Config.AutoAcceptGift and "  Status : 🟢 Aktif (Otomatis Accept Hadiah Masuk)" or "  Status : 🔴 Nonaktif", 10, Config.AutoAcceptGift and T.Green or T.Sub, Enum.Font.GothamSemibold)
acceptStatusLbl.Position = UDim2.new(0, 10, 0, 28)
acceptStatusLbl.Size = UDim2.new(0.68, 0, 0, 16)

local acceptSubLbl = mkLabel(AcceptCard, "  Otomatis klik 'Accept'/'Terima' saat menerima kiriman gift dari akun lain", 9, T.Dim)
acceptSubLbl.Position = UDim2.new(0, 10, 0, 44)
acceptSubLbl.Size = UDim2.new(0.68, 0, 0, 16)

local AcceptToggleBtn = mkBtn(AcceptCard, Config.AutoAcceptGift and "ON" or "OFF", UDim2.new(0, 75, 0, 32), UDim2.new(1, -88, 0.5, -16), Config.AutoAcceptGift and T.Green or T.ToggleOff)
AcceptToggleBtn.TextSize = 11
corner(AcceptToggleBtn, 16)

AcceptToggleBtn.MouseButton1Click:Connect(function()
    Config.AutoAcceptGift = not Config.AutoAcceptGift
    AcceptToggleBtn.BackgroundColor3 = Config.AutoAcceptGift and T.Green or T.ToggleOff
    AcceptToggleBtn.Text = Config.AutoAcceptGift and "ON" or "OFF"
    acceptStatusLbl.Text = Config.AutoAcceptGift and "  Status : 🟢 Aktif (Otomatis Accept Hadiah Masuk)" or "  Status : 🔴 Nonaktif"
    acceptStatusLbl.TextColor3 = Config.AutoAcceptGift and T.Green or T.Sub
end)

-- 3. Target Monitor Card
local MonitorCard = Instance.new("Frame", GiftPage)
MonitorCard.Size = UDim2.new(1, 0, 0, 68)
MonitorCard.BackgroundColor3 = T.Card
corner(MonitorCard, 8)
stroke(MonitorCard, T.Border, 1)

local MonHeader = mkLabel(MonitorCard, "🎯 TARGET & HASIL GIFTING", 11, T.Text, Enum.Font.GothamBold)
MonHeader.Position = UDim2.new(0, 14, 0, 8)
MonHeader.Size = UDim2.new(1, -28, 0, 16)

targetStatsLabelRef = mkLabel(MonitorCard, "  Belum memilih target player!", 10, T.Orange)
targetStatsLabelRef.Position = UDim2.new(0, 10, 0, 26)
targetStatsLabelRef.Size = UDim2.new(1, -20, 0, 16)

toolStatsLabelRef = mkLabel(MonitorCard, "  Divine+ Terpilih: 0 Item  |  Total Berhasil Diterima: 0", 9, T.Sub)
toolStatsLabelRef.Position = UDim2.new(0, 10, 0, 46)
toolStatsLabelRef.Size = UDim2.new(1, -20, 0, 16)

local function UpdateToolStatsLabel()
    local count = 0
    for _, isSel in pairs(Config.SelectedItems) do
        if isSel then count = count + 1 end
    end
    toolStatsLabelRef.Text = string.format("  Divine+ Terpilih: %d Item  |  Total Berhasil Diterima: %d", count, Stats.TotalGiftsAccepted)
end

-- 4. Unified Player Selector Section
local PlayerSelectorCard = Instance.new("Frame", GiftPage)
PlayerSelectorCard.Size = UDim2.new(1, 0, 0, 0)
PlayerSelectorCard.AutomaticSize = Enum.AutomaticSize.Y
PlayerSelectorCard.BackgroundColor3 = T.Card
corner(PlayerSelectorCard, 8)
stroke(PlayerSelectorCard, T.Border, 1)

local pPadCard = Instance.new("UIPadding", PlayerSelectorCard)
pPadCard.PaddingTop = UDim.new(0, 8)
pPadCard.PaddingBottom = UDim.new(0, 10)
pPadCard.PaddingLeft = UDim.new(0, 10)
pPadCard.PaddingRight = UDim.new(0, 10)

local pCardLayout = Instance.new("UIListLayout", PlayerSelectorCard)
pCardLayout.Padding = UDim.new(0, 6)
pCardLayout.SortOrder = Enum.SortOrder.LayoutOrder

local PHeader = mkLabel(PlayerSelectorCard, "👥 PILIH TARGET PLAYER (SERVER)", 11, T.Text, Enum.Font.GothamBold)
PHeader.Size = UDim2.new(1, 0, 0, 18)

local SearchBar = Instance.new("TextBox", PlayerSelectorCard)
SearchBar.Size = UDim2.new(1, 0, 0, 30)
SearchBar.BackgroundColor3 = T.Sidebar
SearchBar.PlaceholderText = "🔍 Cari nama / display name player..."
SearchBar.PlaceholderColor3 = T.Dim
SearchBar.Text = ""
SearchBar.TextColor3 = T.Text
SearchBar.TextSize = 10
SearchBar.Font = Enum.Font.Gotham
corner(SearchBar, 6)
stroke(SearchBar, T.Border, 1)

local PlayerListContainer = Instance.new("Frame", PlayerSelectorCard)
PlayerListContainer.Size = UDim2.new(1, 0, 0, 0)
PlayerListContainer.AutomaticSize = Enum.AutomaticSize.Y
PlayerListContainer.BackgroundTransparency = 1

local pListLayout = Instance.new("UIListLayout", PlayerListContainer)
pListLayout.Padding = UDim.new(0, 4)

local function RefreshPlayerListUI()
    for _, child in ipairs(PlayerListContainer:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end

    local query = SearchBar.Text:lower()
    local count = 0

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local pName = p.Name:lower()
            local dName = p.DisplayName:lower()

            if query == "" or pName:find(query, 1, true) or dName:find(query, 1, true) then
                count = count + 1
                local isSelected = (Config.TargetPlayerName:lower() == p.Name:lower())

                local row = Instance.new("Frame", PlayerListContainer)
                row.Size = UDim2.new(1, 0, 0, 36)
                row.BackgroundColor3 = isSelected and T.CardActive or T.Sidebar
                corner(row, 6)
                stroke(row, isSelected and T.Accent or T.Border, 1)

                local pLabel = mkLabel(row, string.format("  👤 %s (@%s)", p.DisplayName, p.Name), 10, isSelected and T.Accent or T.Text, Enum.Font.GothamSemibold)
                pLabel.Size = UDim2.new(1, -95, 1, 0)

                local pickBtn = mkBtn(row, isSelected and "✓ TERPILIH" or "PILIH", UDim2.new(0, 78, 0, 24), UDim2.new(1, -84, 0.5, -12), isSelected and T.Green or T.Card)
                pickBtn.TextSize = 9

                pickBtn.MouseButton1Click:Connect(function()
                    Config.TargetPlayerName = p.Name
                    targetStatsLabelRef.Text = string.format("  🎯 %s (@%s) — UserId: %d", p.DisplayName, p.Name, p.UserId)
                    targetStatsLabelRef.TextColor3 = T.Accent
                    pendingGiftTool = nil
                    lastTeleportTick = 0
                    RefreshPlayerListUI()
                end)
            end
        end
    end

    if count == 0 then
        local emptyRow = Instance.new("Frame", PlayerListContainer)
        emptyRow.Size = UDim2.new(1, 0, 0, 30)
        emptyRow.BackgroundTransparency = 1
        local emptyLbl = mkLabel(emptyRow, "  (Tidak ada player lain di server saat ini)", 9, T.Dim)
        emptyLbl.Size = UDim2.new(1, 0, 1, 0)
    end
end

SearchBar:GetPropertyChangedSignal("Text"):Connect(RefreshPlayerListUI)
Players.PlayerAdded:Connect(RefreshPlayerListUI)
Players.PlayerRemoving:Connect(RefreshPlayerListUI)

-- 5. Quick Position Offset Selector
local PosCard = Instance.new("Frame", GiftPage)
PosCard.Size = UDim2.new(1, 0, 0, 56)
PosCard.BackgroundColor3 = T.Card
corner(PosCard, 8)
stroke(PosCard, T.Border, 1)

local PosTitle = mkLabel(PosCard, "📍 POSISI TELEPORTASI (DIPERBARUI TIAP 5 DETIK):", 10, T.Dim, Enum.Font.GothamBold)
PosTitle.Position = UDim2.new(0, 14, 0, 8)
PosTitle.Size = UDim2.new(1, -28, 0, 14)

local posOptions = {
    { Id = "Front",  Label = "Depan Target" },
    { Id = "Close",  Label = "Menempel" },
    { Id = "Behind", Label = "Belakang" },
    { Id = "Above",  Label = "Di Atas (Y+1.8)" }
}

local pWidth = 1 / #posOptions
local posBtns = {}

for i, opt in ipairs(posOptions) do
    local b = mkBtn(PosCard, opt.Label, UDim2.new(pWidth, -6, 0, 24), UDim2.new((i - 1) * pWidth, 3, 0, 26), (Config.TeleportOffset == opt.Id and T.CardActive or T.Sidebar))
    b.TextSize = 9
    stroke(b, T.Border, 1)
    posBtns[opt.Id] = b

    b.MouseButton1Click:Connect(function()
        Config.TeleportOffset = opt.Id
        for id, btnRef in pairs(posBtns) do
            btnRef.BackgroundColor3 = (id == opt.Id and T.CardActive or T.Sidebar)
            btnRef.TextColor3 = (id == opt.Id and T.Accent or T.Sub)
        end
        lastTeleportTick = 0
        UpdateToolStatsLabel()
    end)
end

-- ─── TAB 2: DIVINE+ PLANTS & CAPYBARAS SELECTOR ─────────────────────────────
local ToolsPage = Pages["Tools"]
local ActiveRarityFilter = "ALL"

-- 1. Rarity Quick Filter Buttons
local FilterBar = Instance.new("Frame", ToolsPage)
FilterBar.Size = UDim2.new(1, 0, 0, 28)
FilterBar.BackgroundTransparency = 1

local filterTabs = {
    { Id = "ALL",    Label = "⭐ SEMUA",  Color = T.Accent },
    { Id = "Divine", Label = "✨ DIVINE", Color = RARITY_COLORS["Divine"] },
    { Id = "Godly",  Label = "⚡ GODLY",  Color = RARITY_COLORS["Godly"] },
    { Id = "Secret", Label = "🔮 SECRET", Color = RARITY_COLORS["Secret"] },
}

local fWidth = 1 / #filterTabs
local filterBtnRefs = {}

-- 2. Batch Action Toolbar
local BatchToolbar = Instance.new("Frame", ToolsPage)
BatchToolbar.Size = UDim2.new(1, 0, 0, 30)
BatchToolbar.BackgroundTransparency = 1

local SelectAllBtn = mkBtn(BatchToolbar, "✓ PILIH SEMUA", UDim2.new(0.24, -2, 1, 0), UDim2.new(0, 0, 0, 0), T.Green)
SelectAllBtn.TextSize = 9

local SelectBagOnlyBtn = mkBtn(BatchToolbar, "🎒 HANYA DI TAS", UDim2.new(0.26, -2, 1, 0), UDim2.new(0.24, 2, 0, 0), T.Purple)
SelectBagOnlyBtn.TextSize = 9

local ClearAllBtn = mkBtn(BatchToolbar, "✕ BATAL SEMUA", UDim2.new(0.25, -2, 1, 0), UDim2.new(0.50, 4, 0, 0), T.Card)
ClearAllBtn.TextSize = 9

local RefreshBtn = mkBtn(BatchToolbar, "🔄 REFRESH TAS", UDim2.new(0.25, -4, 1, 0), UDim2.new(0.75, 4, 0, 0), T.Sidebar)
RefreshBtn.TextSize = 9

-- 3. Search Bar
local ToolSearchBar = Instance.new("TextBox", ToolsPage)
ToolSearchBar.Size = UDim2.new(1, 0, 0, 30)
ToolSearchBar.BackgroundColor3 = T.Card
ToolSearchBar.PlaceholderText = "🔍 Cari nama Plant / Capybara Divine+..."
ToolSearchBar.PlaceholderColor3 = T.Dim
ToolSearchBar.Text = ""
ToolSearchBar.TextColor3 = T.Text
ToolSearchBar.TextSize = 10
ToolSearchBar.Font = Enum.Font.Gotham
corner(ToolSearchBar, 6)
stroke(ToolSearchBar, T.Border, 1)

-- 4. Item List Container
local ToolsListContainer = Instance.new("Frame", ToolsPage)
ToolsListContainer.Size = UDim2.new(1, 0, 0, 0)
ToolsListContainer.AutomaticSize = Enum.AutomaticSize.Y
ToolsListContainer.BackgroundTransparency = 1

local tLayout = Instance.new("UIListLayout", ToolsListContainer)
tLayout.Padding = UDim.new(0, 4)

local function RefreshToolsListUI()
    for _, child in ipairs(ToolsListContainer:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end

    local query = ToolSearchBar.Text:lower()
    local bagToolsCount, mutCountByBase, _ = ScanAvailableTools()

    -- Group items by Rarity
    local rarityGroups = {
        ["Divine"] = {},
        ["Godly"]  = {},
        ["Secret"] = {},
    }

    for _, item in ipairs(DIVINE_PLUS_CATALOG) do
        local matchesFilter = (ActiveRarityFilter == "ALL" or ActiveRarityFilter == item.rarity)
        local matchesQuery  = (query == "" or item.name:lower():find(query, 1, true) or item.rarity:lower():find(query, 1, true) or item.category:lower():find(query, 1, true))

        if matchesFilter and matchesQuery then
            table.insert(rarityGroups[item.rarity], item)
        end
    end

    local renderedRarities = {"Divine", "Godly", "Secret"}
    local totalRendered = 0

    for _, rName in ipairs(renderedRarities) do
        local itemsInGroup = rarityGroups[rName]
        if itemsInGroup and #itemsInGroup > 0 then
            local rColor = RARITY_COLORS[rName] or T.Accent
            local groupHeader = Instance.new("Frame", ToolsListContainer)
            groupHeader.Size = UDim2.new(1, 0, 0, 28)
            groupHeader.BackgroundColor3 = T.Sidebar
            corner(groupHeader, 6)
            stroke(groupHeader, rColor, 1)

            local gLbl = mkLabel(groupHeader, string.format("  ● %s TIER (%d Item)", rName:upper(), #itemsInGroup), 10, rColor, Enum.Font.GothamBold)
            gLbl.Size = UDim2.new(0.65, 0, 1, 0)

            local allInGroupSelected = true
            for _, it in ipairs(itemsInGroup) do
                if not Config.SelectedItems[it.name:lower()] then
                    allInGroupSelected = false
                    break
                end
            end

            local groupToggleBtn = mkBtn(groupHeader, allInGroupSelected and "✓ SEMUA ON" or "PILIH SEMUA", UDim2.new(0, 92, 0, 20), UDim2.new(1, -96, 0.5, -10), allInGroupSelected and T.Green or T.Card)
            groupToggleBtn.TextSize = 8
            groupToggleBtn.MouseButton1Click:Connect(function()
                local targetState = not allInGroupSelected
                for _, it in ipairs(itemsInGroup) do
                    if targetState then
                        Config.SelectedItems[it.name:lower()] = true
                    else
                        Config.SelectedItems[it.name:lower()] = nil
                    end
                end
                UpdateToolStatsLabel()
                RefreshToolsListUI()
            end)

            for _, item in ipairs(itemsInGroup) do
                totalRendered = totalRendered + 1
                local itemKey = item.name:lower()
                local isSel = Config.SelectedItems[itemKey] == true

                local bagCount = bagToolsCount[item.name] or bagToolsCount[itemKey] or 0
                local mutCount = mutCountByBase[itemKey] or 0
                local hasInBag = bagCount > 0

                local row = Instance.new("Frame", ToolsListContainer)
                row.Size = UDim2.new(1, 0, 0, 36)
                row.BackgroundColor3 = isSel and T.CardActive or T.Card
                corner(row, 6)
                stroke(row, isSel and rColor or T.Border, 1)

                local nameText = string.format("  %s %s", item.icon, item.name)
                local tLbl = mkLabel(row, nameText, 10, isSel and T.Text or Color3.fromRGB(215, 225, 245), Enum.Font.GothamSemibold)
                tLbl.Size = UDim2.new(0.52, 0, 1, 0)

                local stockTag = Instance.new("TextLabel", row)
                stockTag.BackgroundTransparency = 1
                stockTag.Size = UDim2.new(0.25, 0, 1, 0)
                stockTag.Position = UDim2.new(0.52, 0, 0, 0)
                stockTag.Font = Enum.Font.GothamBold
                stockTag.TextSize = 9
                stockTag.TextXAlignment = Enum.TextXAlignment.Center

                if hasInBag then
                    if mutCount > 0 then
                        stockTag.Text = string.format("🎒 x%d (%d mutasi)", bagCount, mutCount)
                    else
                        stockTag.Text = string.format("🎒 x%d di tas", bagCount)
                    end
                    stockTag.TextColor3 = T.Green
                else
                    stockTag.Text = "(tidak di tas)"
                    stockTag.TextColor3 = T.Dim
                end

                local checkBtn = mkBtn(row, isSel and "✓ [DIPILIH]" or "[  ] OFF", UDim2.new(0, 84, 0, 24), UDim2.new(1, -88, 0.5, -12), isSel and T.Green or T.Sidebar)
                checkBtn.TextSize = 9

                checkBtn.MouseButton1Click:Connect(function()
                    if Config.SelectedItems[itemKey] then
                        Config.SelectedItems[itemKey] = nil
                    else
                        Config.SelectedItems[itemKey] = true
                    end
                    UpdateToolStatsLabel()
                    RefreshToolsListUI()
                end)
            end
        end
    end

    if totalRendered == 0 then
        local emptyRow = Instance.new("Frame", ToolsListContainer)
        emptyRow.Size = UDim2.new(1, 0, 0, 36)
        emptyRow.BackgroundColor3 = T.Card
        corner(emptyRow, 6)
        local emptyLbl = mkLabel(emptyRow, "  (Tidak ada Plant / Capybara Divine+ yang cocok dengan filter)", 9, T.Dim)
        emptyLbl.Size = UDim2.new(1, 0, 1, 0)
    end
end

-- Filter Button Generation
for i, fDef in ipairs(filterTabs) do
    local b = mkBtn(FilterBar, fDef.Label, UDim2.new(fWidth, -4, 1, 0), UDim2.new((i - 1) * fWidth, 2, 0, 0), (ActiveRarityFilter == fDef.Id and T.CardActive or T.Sidebar))
    b.TextSize = 9
    b.TextColor3 = (ActiveRarityFilter == fDef.Id and fDef.Color or T.Sub)
    stroke(b, (ActiveRarityFilter == fDef.Id and fDef.Color or T.Border), 1)
    filterBtnRefs[fDef.Id] = b

    b.MouseButton1Click:Connect(function()
        ActiveRarityFilter = fDef.Id
        for id, btnRef in pairs(filterBtnRefs) do
            local isAct = (id == fDef.Id)
            btnRef.BackgroundColor3 = isAct and T.CardActive or T.Sidebar
            btnRef.TextColor3 = isAct and filterTabs[i].Color or T.Sub
            local s = btnRef:FindFirstChildWhichIsA("UIStroke")
            if s then s.Color = isAct and filterTabs[i].Color or T.Border end
        end
        RefreshToolsListUI()
    end)
end

-- Toolbar Button Actions
SelectAllBtn.MouseButton1Click:Connect(function()
    for _, item in ipairs(DIVINE_PLUS_CATALOG) do
        Config.SelectedItems[item.name:lower()] = true
    end
    UpdateToolStatsLabel()
    RefreshToolsListUI()
end)

SelectBagOnlyBtn.MouseButton1Click:Connect(function()
    local bagToolsCount, _, _ = ScanAvailableTools()
    Config.SelectedItems = {}
    for _, item in ipairs(DIVINE_PLUS_CATALOG) do
        local key = item.name:lower()
        if (bagToolsCount[item.name] and bagToolsCount[item.name] > 0) or (bagToolsCount[key] and bagToolsCount[key] > 0) then
            Config.SelectedItems[key] = true
        end
    end
    UpdateToolStatsLabel()
    RefreshToolsListUI()
end)

ClearAllBtn.MouseButton1Click:Connect(function()
    Config.SelectedItems = {}
    UpdateToolStatsLabel()
    RefreshToolsListUI()
end)

RefreshBtn.MouseButton1Click:Connect(RefreshToolsListUI)
ToolSearchBar:GetPropertyChangedSignal("Text"):Connect(RefreshToolsListUI)

-- ─── KEYBIND TOGGLE (RIGHT CONTROL) ─────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Config.Keybind then
        Main.Visible = not Main.Visible
    end
end)

-- ─── NOTIFIKASI LOADED ──────────────────────────────────────────────────────
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Smart Auto Gift",
        Text = "Script berhasil dimuat! Auto Accept Gift & Player Selector aktif.",
        Duration = 5
    })
end)

-- ─── INIT ───────────────────────────────────────────────────────────────────
ShowTab("AutoGift")
RefreshPlayerListUI()
RefreshToolsListUI()
UpdateToolStatsLabel()
print("[Galaxy AutoGift Engine - Unified Auto Accept Edition] Loaded successfully!")
