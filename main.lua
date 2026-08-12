--[[
	===============================================================
	⚡ RITOD HUB - UNIVERSAL MASTER LAUNCHER (V3.3)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	- 🎮 PLACE ID DETECTION (INSTANT 100% ACCURATE):
	  • 107653945083776 -> Roll Anime To fight (roll_anime.lua)
	  • 104973076655377 -> Capybaras vs Plants (capybara.lua)
	===============================================================
]]

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.3)

-- 🔇 SILENT MODE: Matikan seluruh text/log terminal
local print = function(...) end
local warn = function(...) end

-- 🎯 DAFTAR PLACE ID GAME RESMI
local PLACE_IDS = {
    ROLL_ANIME = 107653945083776,
    CAPYBARA   = 104973076655377,
}

local BASE_URL = "https://raw.githubusercontent.com/RyuZeed/capybara/main/"

local function executeScript(filename)
    -- 1. Load langsung dari GitHub Cloud (Raw dengan Cache Buster)
    local success, result = pcall(function()
        local url = BASE_URL .. filename .. "?t=" .. tostring(os.time())
        return loadstring(game:HttpGet(url))()
    end)
    if success and result ~= false then
        print("🌐 [Ritod Launcher] Sukses memuat script cloud: " .. filename)
        return true
    end

    -- 2. Fallback jika offline: coba load dari file lokal di folder workspace executor
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(filename) then
        local lSuccess, lResult = pcall(function()
            return loadstring(readfile(filename))()
        end)
        if lSuccess then
            print("📁 [Ritod Launcher] Sukses memuat script lokal: " .. filename)
            return true
        end
    end

    warn("⚠️ [Ritod Launcher] Gagal memuat " .. filename .. " -> " .. tostring(result))
    return false
end

-- =================================================================
-- 🔍 DETEKSI GAME VIA PLACE ID
-- =================================================================
local currentPlaceId = game.PlaceId
print("🎮 [Ritod Launcher] Checking PlaceId: " .. tostring(currentPlaceId))

if currentPlaceId == PLACE_IDS.ROLL_ANIME then
    print("⚡ [Ritod Launcher] Terdeteksi Game: Roll Anime To fight!")
    executeScript("roll_anime.lua")

elseif currentPlaceId == PLACE_IDS.CAPYBARA then
    print("👑 [Ritod Launcher] Terdeteksi Game: Capybaras vs Plants!")
    executeScript("capybara.lua")

else
    -- Fallback jika ada update PlaceId / sub-place
    local RS = game:GetService("ReplicatedStorage")
    local WS = game:GetService("Workspace")

    if RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Characters") then
        print("⚡ [Ritod Launcher] Fallback Terdeteksi: Roll Anime To fight!")
        executeScript("roll_anime.lua")
    elseif WS:FindFirstChild("EggShop", true) or WS:FindFirstChild("PottedPlants", true) then
        print("👑 [Ritod Launcher] Fallback Terdeteksi: Capybaras vs Plants!")
        executeScript("capybara.lua")
    else
        warn("⚠️ [Ritod Launcher] PlaceId tidak terdaftar (" .. tostring(currentPlaceId) .. "). Memuat default Roll Anime...")
        executeScript("roll_anime.lua")
    end
end
