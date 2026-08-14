--[[
    ===============================================================
    🎁 RITOD HUB - SMART AUTO GIFT ENGINE (DIVINE+ CATALOG)
    Game: Capybaras vs Plants (PlaceId: 104973076655377)
    GitHub: https://github.com/RyuZeed/capybara
    ===============================================================
    🎯 FEATURES:
      - 💎 Strict Divine+ Catalog Filter (Divine, Godly, Secret)
      - 🛡️ 100% Skip Eggs, Seeds, & Gear/Utility Tools
      - ⚡ Single Prompt Activation per Item (Zero Spam & Zero Lag)
      - ⏳ 1.2s Server Transaction Pacing (Anti 'Please wait before gifting again')
      - 🎁 Auto Accept Gift Listener for Receiver Alt Accounts
      - 🔄 Dual Compatibility: Modular in Capybara Hub & Standalone GUI
    ===============================================================
--]]

local AutoGift = {}
_G.AutoGift = AutoGift

-- 🔇 SILENT MODE
local print = function(...) end
local warn = function(...) end

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local CoreGui           = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

-- ─── CONFIG & STATE ──────────────────────────────────────────────────────────
AutoGift.Config = {
    Enabled       = false,
    AutoAccept    = true,
    TargetName    = "",
    SelectedItems = {}, -- [itemNameLower] = true
}

AutoGift.Stats = {
    TotalSent     = 0,
    CurrentTarget = "",
    LastStatus    = "Idle",
    IsRunning     = false,
}

-- ─── 💎 DAFTAR RESMI PLANT & CAPYBARA DIURUTKAN SESUAI RARITY ───────────────
AutoGift.DIVINE_PLUS_LIST = {
    -- ─── ✨ DIVINE TIER ───
    { name = "Carnivorous Plant",   rarity = "Divine", type = "Plant",    badge = "DIVINE",   icon = "🪴" },
    { name = "Mandrake",            rarity = "Divine", type = "Plant",    badge = "DIVINE",   icon = "🌱" },
    { name = "Golem Capybara",      rarity = "Divine", type = "Capybara", badge = "DIVINE",   icon = "🦫" },

    -- ─── ⚡ GODLY TIER ───
    { name = "Ghost Pepper",        rarity = "Godly",  type = "Plant",    badge = "GODLY",    icon = "🌶️" },
    { name = "Magic Mushroom",      rarity = "Godly",  type = "Plant",    badge = "GODLY",    icon = "🍄" },
    { name = "Robot Mushroom",      rarity = "Godly",  type = "Plant",    badge = "GODLY",    icon = "🤖" },
    { name = "Robot Capybara",      rarity = "Godly",  type = "Capybara", badge = "GODLY",    icon = "🦫" },

    -- ─── 🔮 SECRET TIER ───
    { name = "Pumpking",            rarity = "Secret", type = "Plant",    badge = "SECRET",   icon = "🎃" },
    { name = "Pumpkin",             rarity = "Secret", type = "Plant",    badge = "SECRET",   icon = "🎃" },
    { name = "True Carrot",         rarity = "Secret", type = "Plant",    badge = "SECRET",   icon = "🥕" },
    { name = "Disco Carrot",        rarity = "Secret", type = "Plant",    badge = "SECRET",   icon = "✨" },
    { name = "Disco True Carrot",   rarity = "Secret", type = "Plant",    badge = "SECRET",   icon = "✨" },
    { name = "Dragonfruit",         rarity = "Secret", type = "Plant",    badge = "SECRET",   icon = "🐉" },
    { name = "Disco Capybara",      rarity = "Secret", type = "Capybara", badge = "SECRET",   icon = "🦫" },
    { name = "Angel Capybara",      rarity = "Secret", type = "Capybara", badge = "SECRET",   icon = "🦫" },
}

AutoGift.RARITY_COLORS = {
    ["Divine"] = Color3.fromRGB(255, 160, 220),
    ["Godly"]  = Color3.fromRGB(255, 110, 240),
    ["Secret"] = Color3.fromRGB(0, 255, 230),
}

-- ─── SMART ITEM & MUTATION PARSER ───────────────────────────────────────────
function AutoGift.GetDivinePlusItem(toolName)
    if not toolName or type(toolName) ~= "string" then return nil end
    local clean = toolName:lower():gsub("%b[]", " "):gsub("%b()", " "):gsub("[^%w%s]", " ")
    clean = clean:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    for _, item in ipairs(AutoGift.DIVINE_PLUS_LIST) do
        local baseClean = item.name:lower():gsub("[^%w%s]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if clean:find(baseClean, 1, true) or toolName:lower():find(item.name:lower(), 1, true) then
            return item
        end
    end
    return nil
end

local function HasAnyCustomSelection()
    if not AutoGift.Config.SelectedItems then return false end
    for _, sel in pairs(AutoGift.Config.SelectedItems) do
        if sel == true then return true end
    end
    return false
end

function AutoGift.IsGiftableDivinePlus(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local rawName = tool.Name:lower()

    -- Strict Reject: JANGAN PERNAH GIFT EGG ATAU GEAR
    if rawName:find("egg") or rawName:find("telur") or rawName:find("can") or rawName:find("watering") or rawName:find("shovel") or rawName:find("pickaxe") or rawName:find("axe") or rawName:find("sword") or rawName:find("rod") or rawName:find("potion") or rawName:find("seed") then
        return false
    end

    local matched = AutoGift.GetDivinePlusItem(tool.Name)
    if not matched then return false end

    if HasAnyCustomSelection() then
        return AutoGift.Config.SelectedItems[matched.name:lower()] == true
    end

    return true
end

-- ─── INVENTORY SCANNER ───────────────────────────────────────────────────────
function AutoGift.ScanInventoryDivineStats()
    local itemCounts = {}
    local totalDivine = 0

    local function checkItem(t)
        if t:IsA("Tool") then
            local matched = AutoGift.GetDivinePlusItem(t.Name)
            if matched then
                local k = matched.name:lower()
                itemCounts[k] = (itemCounts[k] or 0) + 1
                totalDivine = totalDivine + 1
            end
        end
    end

    local bp   = LP:FindFirstChildOfClass("Backpack")
    local char = LP.Character
    if bp then
        for _, t in ipairs(bp:GetChildren()) do checkItem(t) end
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do checkItem(t) end
    end

    return itemCounts, totalDivine
end

local function GetNextDivinePlusTool()
    local bp   = LP:FindFirstChildOfClass("Backpack")
    local char = LP.Character

    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if AutoGift.IsGiftableDivinePlus(t) then return t end
        end
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if AutoGift.IsGiftableDivinePlus(t) then return t end
        end
    end
    return nil
end

-- ─── HELPER: Equip Tool ──────────────────────────────────────────────────────
local function EquipTool(tool)
    if not tool then return false end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then return false end

    if tool.Parent ~= char then
        pcall(function() hum:UnequipTools() end)
        task.wait(0.08)
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.12)
    end
    return tool.Parent == char
end

-- ─── HELPER: Teleport ────────────────────────────────────────────────────────
local function TeleportToTarget(targetRoot)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not targetRoot then return end

    local dist = (root.Position - targetRoot.Position).Magnitude
    if dist > 3.0 then
        local look = targetRoot.CFrame.LookVector
        local pos  = targetRoot.Position + (look * 2.0)
        pcall(function()
            root.CFrame = CFrame.new(pos, targetRoot.Position)
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- ─── HELPER: Target Player ───────────────────────────────────────────────────
local function GetTarget()
    local targetName = AutoGift.Config.TargetName
    if targetName and targetName ~= "" then
        local q = targetName:lower()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and (p.Name:lower() == q or p.DisplayName:lower() == q) then
                return p
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            AutoGift.Config.TargetName = p.Name
            return p
        end
    end
    return nil
end

-- ─── AUTO ACCEPT & CONFIRM POPUP (RINGAN) ───────────────────────────────────
local confirmKeywords = {"accept", "terima", "yes", "ya", "ok", "confirm", "receive", "give", "ambil", "kirim", "setuju"}
local rejectKeywords  = {"decline", "no", "tidak", "batal", "cancel", "close", "exit", "reject"}

local function ClickButton(btn)
    if not btn or not btn:IsA("GuiObject") then return end
    pcall(function()
        if typeof(firesignal) == "function" and btn:IsA("GuiButton") then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        end
    end)
    pcall(function()
        if typeof(getconnections) == "function" and btn:IsA("GuiButton") then
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                if c.Function then pcall(c.Function) end
            end
            for _, c in ipairs(getconnections(btn.Activated)) do
                if c.Function then pcall(c.Function) end
            end
        end
    end)
end

local function ScanAndAcceptPopups()
    local pGui = LP:FindFirstChildOfClass("PlayerGui")
    if not pGui then return end

    for _, sg in ipairs(pGui:GetChildren()) do
        if sg:IsA("ScreenGui") and sg.Enabled and sg.Name ~= "AG_GUI" and sg.Name ~= "RitodHubUltra" then
            for _, elem in ipairs(sg:GetDescendants()) do
                if elem:IsA("TextButton") and elem.Visible then
                    local txt  = elem.Text:lower()
                    local name = elem.Name:lower()

                    local isReject = false
                    for _, rw in ipairs(rejectKeywords) do
                        if txt:find(rw, 1, true) or name:find(rw, 1, true) then
                            isReject = true
                            break
                        end
                    end

                    if not isReject then
                        for _, cw in ipairs(confirmKeywords) do
                            if txt:find(cw, 1, true) or name:find(cw, 1, true) then
                                ClickButton(elem)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Hook Remote Network 1 kali saat startup
pcall(function()
    for _, cont in ipairs({ ReplicatedStorage, ReplicatedStorage:FindFirstChild("Remotes"), ReplicatedStorage:FindFirstChild("Events") }) do
        if cont then
            for _, item in ipairs(cont:GetChildren()) do
                if item:IsA("RemoteFunction") then
                    local nl = item.Name:lower()
                    if nl:find("gift") or nl:find("accept") or nl:find("confirm") then
                        pcall(function() item.OnClientInvoke = function() return true end end)
                    end
                end
            end
        end
    end
end)

-- ─── ENGINE THREADS ──────────────────────────────────────────────────────────
local mainLoopThread   = nil
local acceptLoopThread = nil

local function startAcceptThread()
    if acceptLoopThread then return end
    acceptLoopThread = task.spawn(function()
        while AutoGift.Config.AutoAccept or AutoGift.Config.Enabled do
            task.wait(0.25)
            pcall(ScanAndAcceptPopups)
        end
        acceptLoopThread = nil
    end)
end

function AutoGift.Start()
    if AutoGift.Stats.IsRunning then return end
    AutoGift.Stats.IsRunning = true
    AutoGift.Config.Enabled  = true

    startAcceptThread()

    if mainLoopThread then task.cancel(mainLoopThread) end

    mainLoopThread = task.spawn(function()
        while AutoGift.Config.Enabled do
            task.wait(0.15)

            local target = GetTarget()
            if not target then
                AutoGift.Stats.LastStatus = "⚠️ Target tidak ditemukan"
                task.wait(0.5)
                continue
            end

            AutoGift.Stats.CurrentTarget = target.DisplayName

            local targetChar = target.Character
            local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            if not targetChar or not targetRoot then
                AutoGift.Stats.LastStatus = "⏳ Menunggu " .. target.DisplayName .. " spawn..."
                task.wait(0.4)
                continue
            end

            -- 1. Ambil item Divine+ sesuai filter
            local tool = GetNextDivinePlusTool()
            if not tool then
                AutoGift.Stats.LastStatus = "✅ Selesai! Semua item Divine+ terpilih sudah dikirim."
                task.wait(0.8)
                continue
            end

            local itemInfo = AutoGift.GetDivinePlusItem(tool.Name)
            local displayName = itemInfo and string.format("%s [%s] %s", itemInfo.icon, itemInfo.rarity, itemInfo.name) or tool.Name

            -- 2. Equip tool
            EquipTool(tool)
            TeleportToTarget(targetRoot)
            task.wait(0.15)

            -- 3. Cari ProximityPrompt
            local foundPrompt = nil
            for _, d in ipairs(targetChar:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    local act = d.ActionText:lower()
                    if act:find("give") or act:find("gift") or act:find("send") or act:find("beri") or act:find("item") then
                        foundPrompt = d
                        break
                    else
                        foundPrompt = d
                    end
                end
            end

            if not foundPrompt then
                AutoGift.Stats.LastStatus = "⚠️ Menunggu prompt Gift di " .. target.DisplayName
                task.wait(0.3)
                continue
            end

            -- 4. TEMBAK PROMPT 1 KALI (ANTI-SPAM & ANTI-LAG)
            pcall(function()
                foundPrompt.Enabled = true
                foundPrompt.MaxActivationDistance = 9999
                foundPrompt.RequiresLineOfSight   = false
                foundPrompt.HoldDuration = 0
            end)
            if typeof(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, foundPrompt)
                pcall(fireproximityprompt, foundPrompt, 0)
            end

            task.wait(0.08)
            pcall(ScanAndAcceptPopups)

            AutoGift.Stats.LastStatus = "📤 Mengirim " .. displayName .. " ke " .. target.DisplayName

            -- 5. SMART DETECT: Tunggu target Accept (Item hilang dari tas)
            local accepted  = false
            local toolRef   = tool
            local conn      = nil

            local function checkItemGone()
                local char = LP.Character
                local bp   = LP:FindFirstChildOfClass("Backpack")
                local stillOurs = toolRef.Parent and (
                    (char and toolRef:IsDescendantOf(char)) or
                    (bp   and toolRef:IsDescendantOf(bp))
                )
                if not stillOurs then
                    accepted = true
                    AutoGift.Stats.TotalSent = AutoGift.Stats.TotalSent + 1
                    AutoGift.Stats.LastStatus = "🟢 " .. displayName .. " DITERIMA " .. target.DisplayName
                end
            end

            conn = toolRef.AncestryChanged:Connect(function()
                checkItemGone()
            end)

            local deadline = tick() + 5.0
            while tick() < deadline and not accepted and AutoGift.Config.Enabled do
                task.wait(0.2)
                checkItemGone()
                if accepted then break end
                pcall(ScanAndAcceptPopups)
            end

            if conn then pcall(function() conn:Disconnect() end) end

            -- 6. COOLDOWN PASING SERVER (1.2s)
            if accepted then
                task.wait(1.2)
            else
                AutoGift.Stats.LastStatus = "⏱️ Timeout " .. displayName .. ", mencoba ulang..."
                task.wait(0.5)
            end
        end
        AutoGift.Stats.IsRunning = false
    end)
end

function AutoGift.Stop()
    AutoGift.Config.Enabled  = false
    AutoGift.Stats.IsRunning = false
    AutoGift.Stats.LastStatus = "🔴 Nonaktif"
    if mainLoopThread then
        task.cancel(mainLoopThread)
        mainLoopThread = nil
    end
end

function AutoGift.Toggle(state)
    if state == nil then state = not AutoGift.Config.Enabled end
    if state then AutoGift.Start() else AutoGift.Stop() end
    return AutoGift.Config.Enabled
end

-- Start background accept listener if enabled
if AutoGift.Config.AutoAccept then
    startAcceptThread()
end

return AutoGift
