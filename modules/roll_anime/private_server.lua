--[[
	===============================================================
	⚡ RITOD HUB - PRIVATE SERVER & SERVER HOP ENGINE
	Game: Roll Anime For Fight / Anime Auto Roll
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- 🏠 IN-GAME PRIVATE SERVER TRIGGER:
	  • Otomatis mencari dan mengklik tombol 'Private Server' di Menu UI game.
	  • Membuka Menu dropdown jika masih tertutup.
	- 📡 DIRECT REMOTE TELEPORT DISPATCHER:
	  • Mencari RemoteEvent/RemoteFunction PrivateServer di ReplicatedStorage.
	- 🌐 API SERVER HOP FALLBACK (Server Sepi / Kosong):
	  • Jika tombol game belum ready, otomatis mencari server dengan 1 pemain via Roblox Public API.
	- 🔄 AUTO-EXECUTE PERSISTENCE:
	  • Menanamkan script ke queue_on_teleport agar Ritod Hub langsung aktif saat masuk ke Private Server.
	===============================================================
]]

local PrivateServer = {}
_G.PrivateServer = PrivateServer
_G.PrivateServerModule = PrivateServer

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local TeleportService     = game:GetService("TeleportService")
local HttpService         = game:GetService("HttpService")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local VirtualUser         = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

local SCRIPT_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/refs/heads/main/main.lua"

-- =================================================================
-- 🛠️ MULTI-VECTOR HARDWARE & EVENT CLICK DISPATCHER
-- =================================================================
local function clickButton(btn)
    if not btn or not btn:IsA("GuiObject") then return end

    if typeof(firesignal) == "function" then
        if btn:IsA("GuiButton") then
            if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
            if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
            if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
            if btn.MouseButton1Up then pcall(function() firesignal(btn.MouseButton1Up) end) end
            if btn.TouchTap then pcall(function() firesignal(btn.TouchTap) end) end
        end
    end

    if typeof(getconnections) == "function" then
        for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "TouchTap"}) do
            pcall(function()
                if btn[evName] then
                    local conns = getconnections(btn[evName])
                    if conns then
                        for _, conn in ipairs(conns) do
                            if conn.Function then conn.Function() elseif conn.Fire then conn:Fire() end
                        end
                    end
                end
            end)
        end
    end

    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        if size.X > 0 and size.Y > 0 and VirtualInputManager then
            local cx = math.floor(pos.X + size.X / 2)
            local cy = math.floor(pos.Y + size.Y / 2)
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
        if VirtualUser then
            VirtualUser:CaptureController()
            local pos = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            if size.X > 0 and size.Y > 0 then
                VirtualUser:ClickButton1(Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2))
            end
        end
    end)

    pcall(function()
        if btn and type(rawget(getmetatable(btn) or {}, "Activate")) == "function" then
            btn:Activate()
        end
    end)
end

local HANDSHAKE_FILE = "RitodHub_PSTeleportHandshake.txt"

-- =================================================================
-- 🔍 HELPER: CEK APAKAH SUDAH DI PRIVATE SERVER
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
    -- 5. Session Handshake Flag (Sudah berhasil berpindah via auto-teleport)
    if _G.AlreadyInPrivateServer == true then
        return true
    end
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(HANDSHAKE_FILE) then
        pcall(function()
            if typeof(delfile) == "function" then delfile(HANDSHAKE_FILE) end
        end)
        _G.AlreadyInPrivateServer = true
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
-- 🚀 QUEUE ON TELEPORT HANDLER (DEBOUNCED: Hanya queue 1x per sesi)
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
-- 🏠 1. TRIGGER IN-GAME 'PRIVATE SERVER' BUTTON (TOPBAR & DROPDOWN)
-- =================================================================
function PrivateServer.TriggerInGamePrivateServer()
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pGui then return false end

    -- 1. Cari dan klik tombol "Menu" di TopbarStandard
    local menuBtn = nil
    for _, guiName in ipairs({"TopbarStandard", "TopbarCentered", "TopbarApp"}) do
        local topGui = pGui:FindFirstChild(guiName)
        if topGui then
            for _, desc in ipairs(topGui:GetDescendants()) do
                if (desc:IsA("TextLabel") and desc.Text:lower() == "menu") or (desc:IsA("GuiButton") and desc.Name:lower():find("menu")) then
                    local spot = desc:FindFirstAncestor("IconButton") or desc:FindFirstAncestor("IconSpot") or desc.Parent
                    local mBtn = spot and (spot:FindFirstChild("ClickRegion", true) or spot:FindFirstChildOfClass("TextButton") or spot:FindFirstChildOfClass("ImageButton")) or (desc:IsA("GuiButton") and desc)
                    if mBtn then
                        menuBtn = mBtn
                        break
                    end
                end
            end
        end
        if menuBtn then break end
    end

    if menuBtn then
        clickButton(menuBtn)
        task.wait(0.35)
    end

    -- 2. Cari tombol "Private Server" di Dropdown / TopbarStandardClipped
    for _, guiName in ipairs({"TopbarStandardClipped", "TopbarCenteredClipped", "TopbarStandard", "TopbarCentered"}) do
        local topGui = pGui:FindFirstChild(guiName)
        if topGui then
            for _, desc in ipairs(topGui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text:lower():find("private") and desc.Text:lower():find("server") then
                    local spot = desc:FindFirstAncestor("IconSpot") or desc:FindFirstAncestor("IconButton") or desc.Parent
                    if spot then
                        local btn = spot:FindFirstChild("ClickRegion", true) or spot:FindFirstChildOfClass("TextButton") or spot:FindFirstChildOfClass("ImageButton")
                        if btn then
                            PrivateServer.QueueScript()
                            clickButton(btn)
                            return true
                        end
                    end
                end
            end
        end
    end

    -- 3. General fallback search di seluruh PlayerGui
    for _, desc in ipairs(pGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text:lower():find("private") and desc.Text:lower():find("server") then
            if desc:IsA("TextButton") then
                PrivateServer.QueueScript()
                clickButton(desc)
                return true
            end
            local spot = desc:FindFirstAncestor("IconSpot") or desc:FindFirstAncestor("IconButton") or desc.Parent
            if spot then
                local btn = spot:FindFirstChild("ClickRegion", true) or spot:FindFirstChildOfClass("TextButton") or spot:FindFirstChildOfClass("ImageButton")
                if btn then
                    PrivateServer.QueueScript()
                    clickButton(btn)
                    return true
                end
            end
        end
    end

    return false
end

-- =================================================================
-- 📡 2. TRIGGER DIRECT REMOTES JIKA ADA
-- =================================================================
function PrivateServer.TriggerRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        for _, r in ipairs(remotes:GetDescendants()) do
            local rName = r.Name:lower()
            if rName:find("privateserver") or rName:find("vipserver") or rName:find("createserver") then
                PrivateServer.QueueScript()
                if r:IsA("RemoteEvent") then
                    pcall(function() r:FireServer() end)
                    return true
                elseif r:IsA("RemoteFunction") then
                    pcall(function() r:InvokeServer() end)
                    return true
                end
            end
        end
    end
    return false
end

-- =================================================================
-- 🌐 3. SERVER HOP KE SERVER SEPI (1 PEMAIN / KOSONG) VIA API
-- =================================================================
function PrivateServer.HopToLowPlayerServer()
    PrivateServer.QueueScript()
    
    local placeId = game.PlaceId
    local currentJob = game.JobId
    
    local success, res = pcall(function()
        local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", tostring(placeId))
        return game:HttpGet(url)
    end)

    if success and res and #res > 0 then
        local sData, parsed = pcall(function() return HttpService:JSONDecode(res) end)
        if sData and parsed and type(parsed.data) == "table" then
            for _, srv in ipairs(parsed.data) do
                if srv.id ~= currentJob and (srv.playing or 0) < (srv.maxPlayers or 12) then
                    local sId = srv.id
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, sId, LocalPlayer)
                    end)
                    return true
                end
            end
        end
    end

    -- Fallback normal teleport
    pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
    return true
end

-- =================================================================
-- ⚡ 4. MASTER FUNCTION: JOIN / RELOG KE PRIVATE SERVER
-- =================================================================
function PrivateServer.JoinPrivateServer(notify)
    PrivateServer.MarkTeleportHandshake()
    PrivateServer.QueueScript()
    if notify then pcall(function() notify("Private Server", "Mempersiapkan teleport ke Private Server...", 3) end) end

    -- Coba Metode 1: In-Game Private Server Button (Sesuai Menu game)
    local ok1 = PrivateServer.TriggerInGamePrivateServer()
    if ok1 then
        if notify then pcall(function() notify("Private Server", "Membuka Private Server in-game...", 3) end) end
        return true
    end

    -- Coba Metode 2: Direct Remote
    local ok2 = PrivateServer.TriggerRemotes()
    if ok2 then
        if notify then pcall(function() notify("Private Server", "Menghubungi Server Private...", 3) end) end
        return true
    end

    -- Coba Metode 3: Server Hop ke Server Sepi
    if notify then pcall(function() notify("Private Server", "Mencari server sepi (Server Hop)...", 3) end) end
    PrivateServer.HopToLowPlayerServer()
    return true
end

return PrivateServer
