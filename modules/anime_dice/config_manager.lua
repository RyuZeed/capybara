--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (CONFIG MANAGER)
	Module: modules/anime_dice/config_manager.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local HttpService = game:GetService("HttpService")
local FILE_NAME = "RitodHub_AnimeDice_Config.json"

ConfigManager.DefaultConfig = {
    NativeAutoRoll = false,
    FastRoll = false,
    RollDelay = 0.1,
    AutoCollectCash = true,
    AutoEquipBest = true,
    AutoUpgradeSlots = false,
    AutoClaimDaily = true,
    AutoClaimGroup = true,
    AutoClaimOffline = true,
    AutoRebirth = false,
    AntiAFK = true
}

ConfigManager.CurrentConfig = {}
for k, v in pairs(ConfigManager.DefaultConfig) do
    ConfigManager.CurrentConfig[k] = v
end

function ConfigManager.Save()
    if typeof(writefile) ~= "function" then return false end
    local success = pcall(function()
        local json = HttpService:JSONEncode(ConfigManager.CurrentConfig)
        writefile(FILE_NAME, json)
    end)
    return success
end

function ConfigManager.Load()
    if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return false end
    if not isfile(FILE_NAME) then
        ConfigManager.Save()
        return true
    end

    local success = pcall(function()
        local json = readfile(FILE_NAME)
        local data = HttpService:JSONDecode(json)
        if type(data) == "table" then
            for k, v in pairs(data) do
                if ConfigManager.DefaultConfig[k] ~= nil then
                    ConfigManager.CurrentConfig[k] = v
                end
            end
        end
    end)
    return success
end

function ConfigManager.Reset()
    for k, v in pairs(ConfigManager.DefaultConfig) do
        ConfigManager.CurrentConfig[k] = v
    end
    ConfigManager.Save()
end

ConfigManager.Load()
_G.AnimeDiceConfigManager = ConfigManager
return ConfigManager
