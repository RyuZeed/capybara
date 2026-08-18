--[[
	===============================================================
	⚡ RITOD HUB - UNIVERSAL CONFIG & PROFILE MANAGER (SHARED)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 TUJUAN:
	  Satu sistem Config Manager terpadu untuk SELURUH game Ritod Hub
	  (Roll Anime, Capybaras vs Plants, dan game berikutnya).

	CARA PENGGUNAAN DI GAME BARU:
	  local ConfigManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/RyuZeed/capybara/main/modules/shared/config_manager.lua"))()

	  local GameConfig = ConfigManager.Init({
	      GameFolder    = "RitodHub/NamaGame",
	      DefaultConfig = {
	          AutoFarm  = true,
	          WalkSpeed = 16,
	      }
	  })

	  -- Simpan / Muat kapan saja:
	  GameConfig.Save()
	  GameConfig.Load()
	  GameConfig.Reset()
	===============================================================
--]]

local ConfigManager = {}
_G.UniversalConfigManager = ConfigManager

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for k, v in next, orig, nil do copy[deepCopy(k)] = deepCopy(v) end
    else
        copy = orig
    end
    return copy
end

function ConfigManager.Init(options)
    options = options or {}
    local ROOT_FOLDER = "RitodHub"
    local GAME_FOLDER = options.GameFolder or ("RitodHub/" .. tostring(game.PlaceId))
    local CONFIG_PATH = string.format("%s/config.json", GAME_FOLDER)

    local DEFAULT_CONFIG = deepCopy(options.DefaultConfig or {})
    local CurrentConfig  = deepCopy(DEFAULT_CONFIG)

    local function ensureFolders()
        pcall(function()
            if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
                if not isfolder(ROOT_FOLDER) then makefolder(ROOT_FOLDER) end
                if not isfolder(GAME_FOLDER) then makefolder(GAME_FOLDER) end
            end
        end)
    end

    local Manager = {
        ConfigPath    = CONFIG_PATH,
        GameFolder    = GAME_FOLDER,
        DefaultConfig = DEFAULT_CONFIG,
        CurrentConfig = CurrentConfig,
    }

    function Manager.Save(customData)
        local dataToSave = customData or CurrentConfig
        local success, err = pcall(function()
            if typeof(writefile) == "function" then
                ensureFolders()
                local json = HttpService:JSONEncode(dataToSave)
                writefile(CONFIG_PATH, json)
            end
        end)
        return success
    end

    function Manager.Load()
        ensureFolders()
        local success, err = pcall(function()
            if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(CONFIG_PATH) then
                local raw = readfile(CONFIG_PATH)
                if raw and #raw > 0 then
                    local data = HttpService:JSONDecode(raw)
                    if typeof(data) == "table" then
                        for k, v in pairs(data) do
                            CurrentConfig[k] = v
                        end
                    end
                end
            end
        end)
        return CurrentConfig
    end

    function Manager.Reset()
        pcall(function()
            if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(CONFIG_PATH) then
                delfile(CONFIG_PATH)
            end
        end)
        for k in pairs(CurrentConfig) do CurrentConfig[k] = nil end
        for k, v in pairs(DEFAULT_CONFIG) do CurrentConfig[k] = deepCopy(v) end
        return CurrentConfig
    end

    -- Muat otomatis saat inisialisasi
    Manager.Load()

    return Manager
end

return ConfigManager
