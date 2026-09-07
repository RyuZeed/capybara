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
    AutoRoll = false,
    RollDelay = 0.1,
    InGameAutoRoll = false,
    AutoCollectCash = true,
    AutoEquipBest = true,
    AutoUpgradeSlots = false,
    AutoSellInventory = false,
    AutoClaimDaily = true,
    AutoClaimGroup = true,
    AutoClaimQuests = true,
    AutoClaimOffline = true,
    AutoRebirth = false,
    SelectedDice = "Lightning",
    AutoEquipSelectedDice = false,
    AutoBuySelectedDice = false,
    AntiAFK = true
}

ConfigManager.CurrentConfig = {}
for k, v in pairs(ConfigManager.DefaultConfig) do
    if type(v) == "table" then
        ConfigManager.CurrentConfig[k] = {}
        for subK, subV in pairs(v) do
            ConfigManager.CurrentConfig[k][subK] = subV
        end
    else
        ConfigManager.CurrentConfig[k] = v
    end
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

    local success, result = pcall(function()
        local json = readfile(FILE_NAME)
        local data = HttpService:JSONDecode(json)
        if type(data) == "table" then
            for k, v in pairs(data) do
                if type(v) == "table" and type(ConfigManager.CurrentConfig[k]) == "table" then
                    for subK, subV in pairs(v) do
                        ConfigManager.CurrentConfig[k][subK] = subV
                    end
                else
                    ConfigManager.CurrentConfig[k] = v
                end
            end
        end
    end)
    return success
end

function ConfigManager.Reset()
    for k, v in pairs(ConfigManager.DefaultConfig) do
        if type(v) == "table" then
            ConfigManager.CurrentConfig[k] = {}
            for subK, subV in pairs(v) do
                ConfigManager.CurrentConfig[k][subK] = subV
            end
        else
            ConfigManager.CurrentConfig[k] = v
        end
    end
    ConfigManager.Save()
end

ConfigManager.Load()
_G.AnimeDiceConfigManager = ConfigManager
return ConfigManager
