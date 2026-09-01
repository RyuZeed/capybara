--[[
	===============================================================
	⚡ RITOD HUB - PRIVATE SERVER ENGINE (IN-GAME MENU & DIRECT REMOTE)
	Game: Roll Anime To Fight!
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local PrivateServer = {}
_G.PrivateServer = PrivateServer
_G.PrivateServerModule = PrivateServer

-- 🔇 SILENT MODE
local print = function(...) end
local warn = function(...) end

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local TeleportService     = game:GetService("TeleportService")
local GuiService          = game:GetService("GuiService")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local VirtualUser         = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

local SCRIPT_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/refs/heads/main/main.lua"
local HANDSHAKE_FILE = "RitodHub_PSTeleportHandshake.txt"

-- =================================================================
-- 🛠️ MULTI-VECTOR HARDWARE & EVENT CLICK DISPATCHER
-- =================================================================
local function clickButton(btn)
    if not btn or not btn:IsA("GuiObject") then return end

    -- 1. firesignal
    if typeof(firesignal) == "function" then
        if btn:IsA("GuiButton") then
            if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
            if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
            if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
            if btn.MouseButton1Up then pcall(function() firesignal(btn.MouseButton1Up) end) end
            if btn.TouchTap then pcall(function() firesignal(btn.TouchTap) end) end
        end
    end

    -- 2. getconnections
    if typeof(getconnections) == "function" then
        for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "TouchTap"}) do
            pcall(function()
                if btn[evName] then
                    local conns = getconnections(btn[evName])
                    if conns then
                        for _, conn in ipairs(conns) do
                            if conn.Function then pcall(conn.Function) elseif conn.Fire then pcall(function() conn:Fire() end) end
                        end
                    end
                end
            end)
        end
    end

    -- 3. TopbarPlus Icon selected object handler
    if typeof(getconnections) == "function" and typeof(getupvalues) == "function" and btn.MouseButton1Click then
        pcall(function()
            local conns = getconnections(btn.MouseButton1Click)
            if #conns > 0 then
                local upvals = getupvalues(conns[1].Function)
                local iconObj = upvals and upvals[2]
                if type(iconObj) == "table" then
                    if iconObj.selected and iconObj.selected.Fire then
                        pcall(function() iconObj.selected:Fire() end)
                    end
                    if type(iconObj.select) == "function" then
                        pcall(function() iconObj:select() end)
                    end
                end
            end
        end)
    end

    -- 4. VirtualInputManager with Topbar Inset calculation
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local inset, _ = GuiService:GetGuiInset()
        if size.X > 0 and size.Y > 0 and VirtualInputManager then
            local cx = math.floor(pos.X + size.X / 2 + (inset and inset.X or 0))
            local cy = math.floor(pos.Y + size.Y / 2 + (inset and inset.Y or 0))
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

    -- 5. VirtualUser
    pcall(function()
        if VirtualUser then
            VirtualUser:CaptureController()
            local pos = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            local inset, _ = GuiService:GetGuiInset()
            if size.X > 0 and size.Y > 0 then
                local cx = math.floor(pos.X + size.X / 2 + (inset and inset.X or 0))
                local cy = math.floor(pos.Y + size.Y / 2 + (inset and inset.Y or 0))
                VirtualUser:ClickButton1(Vector2.new(cx, cy))
            end
        end
    end)
end

-- =================================================================
-- 🔍 HELPER: CEK APAKAH SUDAH BERADA DI PRIVATE SERVER (ANTI-LOOP)
-- =================================================================
function PrivateServer.IsPrivateServer()
    -- 1. Reserved Server (Roblox ReservedServerId)
    if game.PrivateServerId and game.PrivateServerId ~= "" then
        return true
    end
    -- 2. VIP Server (Roblox VIPServerId)
    if game.VIPServerId and game.VIPServerId ~= "" then
        return true
    end
    -- 3. Private Server Owner ID
    if game.PrivateServerOwnerId and game.PrivateServerOwnerId > 0 then
        return true
    end
    -- 4. Game Attribute Flags
    if workspace:GetAttribute("PrivateServer") == true or workspace:GetAttribute("IsPrivate") == true or workspace:GetAttribute("Private") == true then
        return true
    end
    if ReplicatedStorage:GetAttribute("PrivateServer") == true or ReplicatedStorage:GetAttribute("IsPrivate") == true then
        return true
    end
    -- 5. Session Flag (Sudah ditandai di sesi ini)
    if _G.AlreadyInPrivateServer == true or _G.AutoPrivateServerDone == true then
        return true
    end
    -- 6. Handshake Token File (Dibuat saat teleport sebelum load)
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(HANDSHAKE_FILE) then
        pcall(function()
            if typeof(delfile) == "function" then delfile(HANDSHAKE_FILE) end
        end)
        _G.AlreadyInPrivateServer = true
        _G.AutoPrivateServerDone = true
        return true
    end

    return false
end

function PrivateServer.MarkTeleportHandshake()
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(HANDSHAKE_FILE, tostring(game.JobId))
        end
    end)
end

-- =================================================================
-- 🚀 QUEUE ON TELEPORT HANDLER
-- =================================================================
local _queuedThisSession = false

function PrivateServer.QueueScript(customUrl)
    if _queuedThisSession then return end
    _queuedThisSession = true

    local url = customUrl or SCRIPT_URL
    local queueFunc = (typeof(queue_on_teleport) == "function" and queue_on_teleport)
        or (syn and typeof(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
        or (fluxus and typeof(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)
    
    if queueFunc then
        pcall(queueFunc, ('loadstring(game:HttpGet("%s"))()'):format(url))
    end
end

-- =================================================================
-- 🏠 1. TRIGGER IN-GAME 'PRIVATE SERVER' BUTTON (MENU GAME)
-- =================================================================
function PrivateServer.TriggerInGamePrivateServer()
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pGui then return false end

    -- 1. Buka Dropdown 'Menu' di Topbar
    for _, guiName in ipairs({"TopbarStandard", "TopbarCentered", "TopbarApp"}) do
        local topGui = pGui:FindFirstChild(guiName)
        if topGui then
            for _, desc in ipairs(topGui:GetDescendants()) do
                if (desc:IsA("TextLabel") and desc.Text:lower() == "menu") or (desc:IsA("GuiButton") and desc.Name:lower():find("menu")) then
                    local spot = desc:FindFirstAncestor("IconButton") or desc:FindFirstAncestor("IconSpot") or desc.Parent
                    local mBtn = spot and (spot:FindFirstChild("ClickRegion", true) or spot:FindFirstChildOfClass("TextButton") or spot:FindFirstChildOfClass("ImageButton")) or (desc:IsA("GuiButton") and desc)
                    if mBtn then
                        clickButton(mBtn)
                        break
                    end
                end
            end
        end
    end

    task.wait(0.35)

    -- 2. Klik tombol 'Private Server' di Dropdown
    for _, guiName in ipairs({"TopbarStandardClipped", "TopbarCenteredClipped", "TopbarStandard", "TopbarCentered"}) do
        local topGui = pGui:FindFirstChild(guiName)
        if topGui then
            for _, desc in ipairs(topGui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text:lower():find("private") and desc.Text:lower():find("server") then
                    local spot = desc:FindFirstAncestor("IconSpot") or desc:FindFirstAncestor("IconButton") or desc.Parent
                    if spot then
                        local btn = spot:FindFirstChild("ClickRegion", true) or spot:FindFirstChildOfClass("TextButton") or spot:FindFirstChildOfClass("ImageButton")
                        if btn then
                            clickButton(btn)
                            return true
                        end
                    end
                end
            end
        end
    end

    -- 3. Fallback scan di seluruh PlayerGui
    for _, desc in ipairs(pGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text:lower():find("private") and desc.Text:lower():find("server") then
            if desc:IsA("TextButton") then
                clickButton(desc)
                return true
            end
            local spot = desc:FindFirstAncestor("IconSpot") or desc:FindFirstAncestor("IconButton") or desc.Parent
            if spot then
                local btn = spot:FindFirstChild("ClickRegion", true) or spot:FindFirstChildOfClass("TextButton") or spot:FindFirstChildOfClass("ImageButton")
                if btn then
                    clickButton(btn)
                    return true
                end
            end
        end
    end

    return false
end

-- =================================================================
-- 📡 2. DIRECT REMOTE TELEPORT DISPATCHER (AFKTeleport: "PrivateServer")
-- =================================================================
function PrivateServer.TriggerRemotes()
    local ok = false
    -- Remote utama bawaan game Roll Anime:
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local afkRem = remotes:FindFirstChild("AFKTeleport")
        if afkRem and afkRem:IsA("RemoteEvent") then
            pcall(function()
                afkRem:FireServer("PrivateServer")
                ok = true
            end)
        end

        for _, r in ipairs(remotes:GetDescendants()) do
            local rName = r.Name:lower()
            if rName:find("privateserver") or rName:find("vipserver") then
                if r:IsA("RemoteEvent") then
                    pcall(function() r:FireServer() ok = true end)
                elseif r:IsA("RemoteFunction") then
                    pcall(function() r:InvokeServer() ok = true end)
                end
            end
        end
    end
    return ok
end

-- =================================================================
-- ⚡ 3. MASTER FUNCTION: JOIN / RELOG KE PRIVATE SERVER
-- =================================================================
function PrivateServer.JoinPrivateServer(notify)
    -- Jika sudah di private server, batalkan agar tidak loop
    if PrivateServer.IsPrivateServer() then
        if notify then pcall(function() notify("Private Server", "Anda sudah berada di Private Server ✅", 2.5) end) end
        return true
    end

    PrivateServer.MarkTeleportHandshake()
    PrivateServer.QueueScript()
    if notify then pcall(function() notify("Private Server", "Membuka Private Server bawaan game...", 3) end) end

    -- Eksekusi Remote & In-Game Menu Click secara bersamaan
    task.spawn(function()
        PrivateServer.TriggerRemotes()
    end)
    task.spawn(function()
        PrivateServer.TriggerInGamePrivateServer()
    end)

    return true
end

-- =================================================================
-- 🔄 LIFECYCLE CONTROLLER (START / STOP DAEMON)
-- =================================================================
local isRunning = false
local psThread = nil

function PrivateServer.Start(notify)
    if isRunning then return end
    isRunning = true
    if psThread then pcall(function() task.cancel(psThread) end) end
    psThread = task.spawn(function()
        task.wait(2)
        while isRunning do
            pcall(function()
                if not PrivateServer.IsPrivateServer() then
                    PrivateServer.JoinPrivateServer(notify)
                    task.wait(15)
                end
            end)
            task.wait(10)
        end
        isRunning = false
    end)
end

function PrivateServer.Stop()
    isRunning = false
    if psThread then
        pcall(function() task.cancel(psThread) end)
        psThread = nil
    end
end

function PrivateServer.IsRunning()
    return isRunning
end

return PrivateServer
