--[[
	===============================================================
	⚡ RITOD HUB - GROW A CHICKEN FIGHTER (CONFIG MANAGER)
	Module: modules/chicken_fighter/config_manager.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local GAME_FOLDER = "RitodHub/GrowAChickenFighter"
local CONFIG_FILE = GAME_FOLDER .. "/config.json"

ConfigManager.DefaultConfig = {
    AutoCollectEgg = false,
    EggInterval = 0.8,
    AutoClaimIncubator = false,
    IncubatorInterval = 2.0,
    MaxIncubatorSlots = 7,
    AntiAFK = true
}

ConfigManager.CurrentConfig = {}
for k, v in pairs(ConfigManager.DefaultConfig) do
    ConfigManager.CurrentConfig[k] = v
end

local function ensureFolder()
    pcall(function()
        if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
            if not isfolder("RitodHub") then makefolder("RitodHub") end
            if not isfolder(GAME_FOLDER) then makefolder(GAME_FOLDER) end
        end
    end)
end

function ConfigManager.Save(customData)
    local dataToSave = customData or ConfigManager.CurrentConfig
    local success, err = pcall(function()
        ensureFolder()
        if typeof(writefile) == "function" then
            local encoded = HttpService:JSONEncode(dataToSave)
            writefile(CONFIG_FILE, encoded)
        end
    end)
    return success
end

function ConfigManager.Load()
    ensureFolder()
    local success, err = pcall(function()
        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            if raw and #raw > 0 then
                local decoded = HttpService:JSONDecode(raw)
                if typeof(decoded) == "table" then
                    for k, v in pairs(decoded) do
                        ConfigManager.CurrentConfig[k] = v
                    end
                end
            end
        end
    end)
    return ConfigManager.CurrentConfig
end

function ConfigManager.Reset()
    for k in pairs(ConfigManager.CurrentConfig) do
        ConfigManager.CurrentConfig[k] = nil
    end
    for k, v in pairs(ConfigManager.DefaultConfig) do
        ConfigManager.CurrentConfig[k] = v
    end
    ConfigManager.Save()
    return ConfigManager.CurrentConfig
end

-- Muat saat inisialisasi
ConfigManager.Load()

_G.ChickenFighterConfigManager = ConfigManager
return ConfigManager
