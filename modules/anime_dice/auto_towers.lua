--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO TOWERS MODULE)
	Module: modules/anime_dice/auto_towers.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	Fitur:
	- 4 Tower Resmi:
	  1. Dragon Tower (Easy, max 100 floors)
	  2. Cursed Tower (Medium, max 100 floors)
	  3. Pirate Tower (Hard, max 100 floors)
	  4. Infinity Tower (Infinity difficulty, infinite floors)
	- 2 Mode Operasi:
	  1. Single Tower Repeat: Fokus 1 tower dan repeat terus-menerus.
	  2. Farm Potion Rotation: Rotasi Dragon -> Cursed -> Pirate -> Infinity.
	     Khusus Infinity Tower: saat mencapai floor 140, langsung keluar (exit)
	     dan me-repeat rotasi kembali dari Dragon Tower (Easy)!
	- Fitur Tambahan:
	  - Auto Equip Best Tower Team sebelum bermain
	  - Auto Hide Battle Animation (mode hemat FPS & anti-lag game)
	  - Deteksi Floor Realtime & Status Telemetri
	===============================================================
]]

local AutoTowers = {}
AutoTowers.__index = AutoTowers

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Network & Controllers
local NetworkFolder = ReplicatedStorage:WaitForChild("Network", 5)
local TowersNetwork = NetworkFolder and NetworkFolder:FindFirstChild("Towers")
local TowersRF = TowersNetwork and TowersNetwork:FindFirstChild("RF")
local TowersRE = TowersNetwork and TowersNetwork:FindFirstChild("RE")

local PlayTowerRF = TowersRF and TowersRF:FindFirstChild("PlayTower")
local CompleteFloorRF = TowersRF and TowersRF:FindFirstChild("CompleteTowerFloor")
local CancelTowerRF = TowersRF and TowersRF:FindFirstChild("CancelTower")
local EquipBestTeamRE = TowersRE and TowersRE:FindFirstChild("EquipBestTowerTeam")

-- Game Framework Controllers
local Framework = ReplicatedStorage:WaitForChild("Framework", 5)
local Features = Framework and Framework:WaitForChild("Features", 5)

local TowerController = nil
pcall(function()
    if Features and Features:FindFirstChild("Towers") and Features.Towers:FindFirstChild("TowerController") then
        TowerController = require(Features.Towers.TowerController)
    end
end)

local MenuController = nil
pcall(function()
    if Features and Features:FindFirstChild("UI") and Features.UI:FindFirstChild("MenuController") then
        MenuController = require(Features.UI.MenuController)
    end
end)

local UIReferences = nil
pcall(function()
    if Features and Features:FindFirstChild("UI") and Features.UI:FindFirstChild("UIReferences") then
        UIReferences = require(Features.UI.UIReferences)
    end
end)

-- Daftar 4 Tower Resmi Game
AutoTowers.TowersList = {
    { id = "Dragon Tower", name = "Dragon Tower", difficulty = "Easy", maxFloors = 100 },
    { id = "Cursed Tower", name = "Cursed Tower", difficulty = "Medium", maxFloors = 100 },
    { id = "Pirate Tower", name = "Pirate Tower", difficulty = "Hard", maxFloors = 100 },
    { id = "Infinity Tower", name = "Infinity Tower", difficulty = "Infinity", maxFloors = math.huge }
}

-- Pengaturan Konfigurasi & State
AutoTowers.Enabled = false
AutoTowers.Mode = "Farm Potion" -- "Farm Potion" atau "Single Repeat"
AutoTowers.SelectedSingleTower = "Dragon Tower"
AutoTowers.InfinityExitFloor = 140
AutoTowers.AutoEquipBestTeam = true
AutoTowers.HideBattleScreen = true

-- Telemetri & State Realtime
AutoTowers.IsRunning = false
AutoTowers.CurrentTower = nil
AutoTowers.CurrentFloor = 0
AutoTowers.StatusText = "Siaga"
AutoTowers.CompletedTowersCount = 0
AutoTowers.CompletedRotationsCount = 0
AutoTowers.RotationIndex = 1

-- Callback UI jika ada
AutoTowers.OnStatusChanged = nil

local workerThread = nil

-- Utility: Mendapatkan referensi UI Layar Tower
local function getScreenUI()
    if UIReferences and UIReferences.Root and UIReferences.Root:FindFirstChild("Tower") then
        local towerUI = UIReferences.Root.Tower
        local screen = towerUI:FindFirstChild("Screen")
        local hidden = towerUI:FindFirstChild("Hidden")
        return screen, hidden
    end
    return nil, nil
end

-- Cek apakah player sedang berada di dalam tower
function AutoTowers.IsInTower()
    local screen, hidden = getScreenUI()
    if screen and screen.Visible then return true end
    if hidden and hidden.Visible then return true end
    return false
end

-- Dapatkan nomor floor saat ini
function AutoTowers.GetCurrentFloor()
    local screen, hidden = getScreenUI()
    local text = ""
    if screen and screen.Visible and screen:FindFirstChild("Floor") then
        text = tostring(screen.Floor.Text or "")
    elseif hidden and hidden.Visible and hidden:FindFirstChild("Label") then
        text = tostring(hidden.Label.Text or "")
    end
    local floorNum = tonumber(string.match(text, "%d+"))
    return floorNum or 0
end

-- Pasang Tim Terbaik untuk Tower
function AutoTowers.EquipBestTeam()
    if EquipBestTeamRE then
        pcall(function()
            EquipBestTeamRE:FireServer()
        end)
        return true
    end
    return false
end

-- Keluar dari Tower (Cancel / Exit)
function AutoTowers.CancelTower()
    if CancelTowerRF then
        local success, result = pcall(function()
            return CancelTowerRF:InvokeServer()
        end)
        return success and result
    end
    return false
end

-- Tutup Menu Rewards agar tidak menghalangi layar
function AutoTowers.CloseRewardsMenu()
    pcall(function()
        if MenuController and typeof(MenuController.CloseMenu) == "function" then
            MenuController.CloseMenu()
        end
    end)
end

-- Atur mode Hidden untuk menyembunyikan animasi kartu tower
function AutoTowers.SetHidden(shouldHide)
    local screen, hidden = getScreenUI()
    if not hidden or not hidden.Visible then return end

    if shouldHide and screen and screen.Visible then
        -- Jika layar terbuka dan kita ingin hide: klik tombol hidden
        if typeof(firesignal) == "function" and hidden:FindFirstChild("Activated") then
            pcall(function() firesignal(hidden.Activated) end)
        end
    elseif not shouldHide and screen and not screen.Visible then
        -- Jika layar tersembunyi dan kita ingin un-hide
        if typeof(firesignal) == "function" and hidden:FindFirstChild("Activated") then
            pcall(function() firesignal(hidden.Activated) end)
        end
    end
end

-- Update status dan kirim ke callback jika ada
local function updateStatus(text, floorNum)
    AutoTowers.StatusText = text or AutoTowers.StatusText
    if floorNum ~= nil then
        AutoTowers.CurrentFloor = floorNum
    end
    if typeof(AutoTowers.OnStatusChanged) == "function" then
        pcall(AutoTowers.OnStatusChanged, AutoTowers.StatusText, AutoTowers.CurrentTower, AutoTowers.CurrentFloor)
    end
end

-- Dapatkan nama tower berikutnya sesuai mode
function AutoTowers.GetNextTower()
    if AutoTowers.Mode == "Single Repeat" then
        return AutoTowers.SelectedSingleTower or "Dragon Tower"
    else
        -- Mode Farm Potion: rotasi 1 (Dragon) -> 2 (Cursed) -> 3 (Pirate) -> 4 (Infinity) -> 1
        if AutoTowers.RotationIndex < 1 or AutoTowers.RotationIndex > #AutoTowers.TowersList then
            AutoTowers.RotationIndex = 1
        end
        local towerData = AutoTowers.TowersList[AutoTowers.RotationIndex]
        return towerData and towerData.name or "Dragon Tower"
    end
end

-- Memulai tower resmi game
local function startTowerSession(towerName)
    if not towerName then return false end

    -- 1. Auto equip best team jika diaktifkan
    if AutoTowers.AutoEquipBestTeam then
        AutoTowers.EquipBestTeam()
        task.wait(0.3)
    end

    -- 2. Memulai tower melalui TowerController resmi game
    local started = false
    if TowerController and typeof(TowerController.startTower) == "function" then
        local success, res = pcall(function()
            return TowerController.startTower(towerName)
        end)
        if success and res then
            started = true
        end
    end

    -- Fallback via direct RemoteFunction jika TowerController belum siap
    if not started and PlayTowerRF then
        local success, res = pcall(function()
            return PlayTowerRF:InvokeServer(towerName)
        end)
        if success and res then
            started = true
        end
    end

    return started
end

-- Main Loop Worker
local function runTowerWorker()
    while AutoTowers.IsRunning do
        -- Pastikan menu reward tertutup
        AutoTowers.CloseRewardsMenu()

        -- Tentukan target tower
        local targetTowerName = AutoTowers.GetNextTower()
        AutoTowers.CurrentTower = targetTowerName
        AutoTowers.CurrentFloor = 0

        updateStatus(string.format("Mempersiapkan %s...", targetTowerName), 0)
        task.wait(0.5)
        if not AutoTowers.IsRunning then break end

        -- Jika masih ada sisa sesi sebelumnya, bersihkan
        if AutoTowers.IsInTower() then
            updateStatus("Menunggu sesi tower sebelumnya ditutup...", 0)
            task.wait(1.5)
            if AutoTowers.IsInTower() then
                AutoTowers.CancelTower()
                task.wait(1.5)
            end
        end

        -- Mulai tower
        updateStatus(string.format("Memulai %s...", targetTowerName), 1)
        local started = startTowerSession(targetTowerName)

        if not started then
            updateStatus(string.format("Gagal memulai %s, mencoba lagi dalam 3s...", targetTowerName), 0)
            task.wait(3.0)
            continue
        end

        -- Tunggu tower masuk ke sesi (Screen atau Hidden terlihat)
        local waitStartTime = tick()
        while AutoTowers.IsRunning and not AutoTowers.IsInTower() and (tick() - waitStartTime) < 5 do
            task.wait(0.2)
        end

        if not AutoTowers.IsInTower() then
            updateStatus("Sesi tower tidak merespons, mencoba kembali...", 0)
            task.wait(2.0)
            continue
        end

        -- Aktifkan Hide Battle Screen jika diinginkan
        if AutoTowers.HideBattleScreen then
            task.wait(0.4)
            AutoTowers.SetHidden(true)
        end

        -- Loop pantau progres floor
        local isInfinity = (targetTowerName == "Infinity Tower")
        local exitTargetFloor = tonumber(AutoTowers.InfinityExitFloor) or 140

        while AutoTowers.IsRunning and AutoTowers.IsInTower() do
            task.wait(0.3)
            local floor = AutoTowers.GetCurrentFloor()
            if floor > 0 then
                AutoTowers.CurrentFloor = floor
                local maxFloorStr = isInfinity and string.format("Target Exit: %d", exitTargetFloor) or "Max: 100"
                updateStatus(string.format("Bermain %s (Floor %d | %s)", targetTowerName, floor, maxFloorStr), floor)

                -- KHUSUS INFINITY TOWER: Keluar saat mencapai target exit floor (default 140)
                if isInfinity and floor >= exitTargetFloor then
                    updateStatus(string.format("Floor %d tercapai di Infinity Tower! Otomatis keluar...", floor), floor)
                    AutoTowers.CancelTower()
                    -- Beri jeda agar server dan UI selesai
                    task.wait(1.5)
                    break
                end
            end

            -- Pastikan screen tetap hidden jika opsi aktif
            if AutoTowers.HideBattleScreen then
                local screen, hidden = getScreenUI()
                if screen and screen.Visible and hidden and hidden.Visible then
                    AutoTowers.SetHidden(true)
                end
            end
        end

        -- Sesi tower ini telah selesai atau di-exit
        AutoTowers.CompletedTowersCount = AutoTowers.CompletedTowersCount + 1
        updateStatus(string.format("%s Selesai! Mengambil reward...", targetTowerName), AutoTowers.CurrentFloor)

        -- Tutup popup rewards
        task.wait(0.8)
        AutoTowers.CloseRewardsMenu()

        -- Logika Rotasi / Repeat
        if AutoTowers.Mode == "Farm Potion" then
            if targetTowerName == "Infinity Tower" then
                -- Selesai putaran 4 tower penuh -> reset kembali ke 1 (Dragon Tower)
                AutoTowers.RotationIndex = 1
                AutoTowers.CompletedRotationsCount = AutoTowers.CompletedRotationsCount + 1
                updateStatus("Satu putaran Farm Potion selesai! Kembali ke Dragon Tower...", 0)
            else
                -- Pindah ke tower berikutnya dalam rotasi
                AutoTowers.RotationIndex = AutoTowers.RotationIndex + 1
                local nextData = AutoTowers.TowersList[AutoTowers.RotationIndex]
                local nextName = nextData and nextData.name or "Dragon Tower"
                updateStatus(string.format("Pindah ke tower berikutnya: %s...", nextName), 0)
            end
        else
            updateStatus(string.format("Repeat mode: Memulai ulang %s...", targetTowerName), 0)
        end

        -- Jeda istirahat singkat sebelum tower berikutnya
        task.wait(1.5)
    end

    AutoTowers.IsRunning = false
    AutoTowers.CurrentTower = nil
    AutoTowers.CurrentFloor = 0
    updateStatus("Auto Towers Dimatikan.", 0)
end

-- Mulai Auto Towers
function AutoTowers.Start()
    if AutoTowers.IsRunning then return end
    AutoTowers.IsRunning = true
    AutoTowers.Enabled = true

    if AutoTowers.Mode == "Farm Potion" then
        AutoTowers.RotationIndex = 1
    end

    workerThread = task.spawn(runTowerWorker)
    print("🏰 [Auto Towers] Dimulai. Mode:", AutoTowers.Mode, "| Target Single:", AutoTowers.SelectedSingleTower)
end

-- Hentikan Auto Towers
function AutoTowers.Stop()
    AutoTowers.IsRunning = false
    AutoTowers.Enabled = false
    if workerThread then
        task.cancel(workerThread)
        workerThread = nil
    end
    updateStatus("Auto Towers Dinonaktifkan.", 0)
    print("🏰 [Auto Towers] Dihentikan.")
end

function AutoTowers.StopAll()
    AutoTowers.Stop()
    pcall(AutoTowers.CloseRewardsMenu)
end

-- Global reference
_G.AnimeDiceAutoTowers = AutoTowers

return AutoTowers
