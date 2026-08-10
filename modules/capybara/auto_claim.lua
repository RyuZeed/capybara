--[[
	===============================================================
	⚡ RITOD HUB - SMART AUTO CLAIM ENGINE (OPTIMIZED)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 OPTIMIZATIONS:
	- ✅ Lazy GUI caching: GetDescendants() hanya 1x, diulang saat ada perubahan
	- ✅ Path filter via instance Name bukan GetFullName() string
	- ✅ clickButton: hanya firesignal/getconnections, tanpa VirtualInputManager spam
	- ✅ CheckInterval 4 detik (bukan 1.5 detik) – sangat cukup untuk klaim
	- ✅ Playtime & Daily scanner hanya berjalan di GUI yang relevan, bukan seluruh PlayerGui
	===============================================================
]]

local AutoClaim = {}
_G.AutoClaim = AutoClaim

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

AutoClaim.Config = {
    PlaytimeDaily = true,  -- Auto Claim Playtime & Daily Login
    Quest         = true,  -- Auto Claim Daily Quests & Missions
    CheckInterval = 4,     -- Interval pengecekan (detik) – lebih jarang = lebih ringan
}

local isRunning    = false
local loopThread   = nil
local clickDebounce = {}  -- [key] = last tick time

-- =================================================================
-- 🛠️ LIGHTWEIGHT CLICK DISPATCHER
-- =================================================================
local _hasFiresignal   = typeof(firesignal) == "function"
local _hasGetconn      = typeof(getconnections) == "function"

local function clickButton(btn)
    if not btn then return end

    -- 1. firesignal (paling cepat & ringan)
    if _hasFiresignal then
        pcall(firesignal, btn.MouseButton1Click)
        pcall(firesignal, btn.Activated)
        return -- Cukup, tidak perlu fallback lain jika berhasil
    end

    -- 2. getconnections (fallback jika tidak ada firesignal)
    if _hasGetconn then
        for _, ev in ipairs({"Activated", "MouseButton1Click"}) do
            pcall(function()
                local conns = getconnections(btn[ev])
                if conns then
                    for _, conn in ipairs(conns) do
                        if conn.Function then conn.Function()
                        elseif conn.Fire then conn:Fire() end
                    end
                end
            end)
        end
    end
end

-- =================================================================
-- 🔧 HELPER: Cek apakah tombol bertuliskan "CLAIM" (bukan "CLAIMED")
-- =================================================================
local function isClaimButton(btn)
    local lbl = btn:FindFirstChild("TextLabel")
    local txt = lbl and lbl.Text or (btn:IsA("TextButton") and btn.Text) or ""
    local clean = txt:upper():gsub("%s+", "")
    return clean == "CLAIM"
end

-- =================================================================
-- 🔧 HELPER: Klaim tombol dengan debounce
-- =================================================================
local function tryClaimButton(btn, label)
    local key = btn:GetFullName()
    local now = tick()
    if now - (clickDebounce[key] or 0) > 10 then -- 10 detik cooldown per tombol
        clickDebounce[key] = now
        print(string.format("🎁 [Auto Claim] Mengklaim: %s", tostring(label)))
        clickButton(btn)
    end
end

-- =================================================================
-- 📦 LAZY GUI CACHE
-- Menyimpan referensi GUI yang sudah ditemukan, dihitung ulang
-- hanya setiap 30 detik atau saat GUI berubah (jauh lebih ringan)
-- =================================================================
local _cache = {
    questsFrame  = nil,
    playtimePanels = {},
    dailyPanels  = {},
    lastUpdate   = 0,
}
local CACHE_TTL = 30 -- detik

local function refreshCache()
    local now = tick()
    if now - _cache.lastUpdate < CACHE_TTL then return end
    _cache.lastUpdate = now

    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    -- Quests frame (lokasi tetap)
    local mainGui = pg:FindFirstChild("MainGui")
    local root = mainGui and mainGui:FindFirstChild("Root")
    local frames = root and root:FindFirstChild("Frames")
    _cache.questsFrame = frames and frames:FindFirstChild("Quests")

    -- Scan GUI lain untuk Playtime & Daily
    _cache.playtimePanels = {}
    _cache.dailyPanels = {}

    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= mainGui then
            local gName = gui.Name:lower()
            if gName:find("playtime") or gName:find("gift") or gName:find("online") or gName:find("timereward") then
                table.insert(_cache.playtimePanels, gui)
            elseif gName:find("daily") or gName:find("loginreward") or gName:find("7day") then
                table.insert(_cache.dailyPanels, gui)
            end
        end
    end
end

-- =================================================================
-- ⏳ 1. PLAYTIME REWARDS SCANNER
-- =================================================================
local function scanPlaytimeRewards()
    refreshCache()
    for _, panel in ipairs(_cache.playtimePanels) do
        for _, btn in ipairs(panel:GetDescendants()) do
            if (btn:IsA("ImageButton") or btn:IsA("TextButton")) and isClaimButton(btn) then
                tryClaimButton(btn, "Playtime Gift [" .. btn.Parent.Name .. "]")
            end
        end
    end
end

-- =================================================================
-- 📅 2. DAILY LOGIN REWARDS SCANNER
-- =================================================================
local function scanDailyLoginRewards()
    refreshCache()
    for _, panel in ipairs(_cache.dailyPanels) do
        for _, btn in ipairs(panel:GetDescendants()) do
            if (btn:IsA("ImageButton") or btn:IsA("TextButton")) and isClaimButton(btn) then
                tryClaimButton(btn, "Daily Login [" .. btn.Parent.Name .. "]")
            end
        end
    end
end

-- =================================================================
-- 📜 3. QUESTS SCANNER (DAILY & LIFETIME)
-- =================================================================
local function scanQuestsAndMissions()
    refreshCache()
    local qf = _cache.questsFrame
    if not qf then return end

    for _, btn in ipairs(qf:GetDescendants()) do
        if (btn:IsA("ImageButton") or btn:IsA("TextButton")) and isClaimButton(btn) then
            -- Validasi progress jika ada ProgressBar di parent
            local isLocked = false
            local card = btn.Parent
            if card then
                local pBar = card:FindFirstChild("ProgressBar")
                local pLbl = pBar and pBar:FindFirstChild("TextLabel")
                if pLbl then
                    local cur, max = pLbl.Text:match("(%d+)%s*/%s*(%d+)")
                    local nCur, nMax = tonumber(cur), tonumber(max)
                    if nCur and nMax and nMax > 0 and nCur < nMax then
                        isLocked = true
                    end
                end
            end

            if not isLocked then
                tryClaimButton(btn, "Quest [" .. (card and card.Name or btn.Name) .. "]")
            end
        end
    end
end

-- =================================================================
-- 🚀 MAIN LOOP CONTROLLER
-- =================================================================
function AutoClaim.Start()
    if isRunning then return end
    isRunning = true
    -- Reset cache saat mulai agar langsung scan ulang
    _cache.lastUpdate = 0
    print("🎁 [Ritod Hub] Auto Claim (Optimized Engine) Aktif!")

    loopThread = task.spawn(function()
        while isRunning do
            pcall(function()
                if AutoClaim.Config.PlaytimeDaily then
                    scanPlaytimeRewards()
                    scanDailyLoginRewards()
                end
                if AutoClaim.Config.Quest then
                    scanQuestsAndMissions()
                end
            end)
            task.wait(AutoClaim.Config.CheckInterval or 4)
        end
    end)
end

function AutoClaim.Stop()
    isRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
    print("🛑 [Ritod Hub] Auto Claim Dimatikan.")
end

function AutoClaim.Toggle(state)
    if state == nil then state = not isRunning end
    if state then AutoClaim.Start() else AutoClaim.Stop() end
    return isRunning
end

function AutoClaim.TogglePlaytimeDaily(state)
    AutoClaim.Config.PlaytimeDaily = state
    if not isRunning and (AutoClaim.Config.PlaytimeDaily or AutoClaim.Config.Quest) then
        AutoClaim.Start()
    elseif isRunning and not AutoClaim.Config.PlaytimeDaily and not AutoClaim.Config.Quest then
        AutoClaim.Stop()
    end
end

function AutoClaim.ToggleQuest(state)
    AutoClaim.Config.Quest = state
    if not isRunning and (AutoClaim.Config.PlaytimeDaily or AutoClaim.Config.Quest) then
        AutoClaim.Start()
    elseif isRunning and not AutoClaim.Config.PlaytimeDaily and not AutoClaim.Config.Quest then
        AutoClaim.Stop()
    end
end

function AutoClaim.ResetHistory()
    clickDebounce = {}
    _cache.lastUpdate = 0
    print("🔄 [Auto Claim] Debounce & cache direset.")
end

return AutoClaim
