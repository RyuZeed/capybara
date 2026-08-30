--[[
	===============================================================
	💾 RITOD HUB - ROLL ANIME TO FIGHT (CONFIG MANAGER)
	Module: modules/roll_anime/config_manager.lua
	Game: Roll Anime to Fight! / Anime Auto Roll
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local ConfigManager = {}
ConfigManager.__index = ConfigManager
_G.ConfigManager = ConfigManager

local HttpService = game:GetService("HttpService")
local FILE_NAME = "RitodHub_RollAnime_Config.json"
local LEGACY_FILES = {
    "RitodHub/RollAnimeForFight/config.json",
    "RitodHub_RollAnimeForFight_Config.json"
}

ConfigManager.DefaultConfig = {
    -- 🎰 Auto Roll / Gacha
    AutoHuntEnabled       = false,
    AutoSniperOnly        = false,
    AutoSecretGod         = false,
    RollInterval          = 2.5,
    SelectedUnits         = {},

    -- 📜 Quests & Free Rewards
    AutoClaimQuests       = true,
    AutoClaimRewards      = true,

    -- 🛒 Trader / Merchant
    AutoBuyMerchant       = true,
    MerchantBuyAll        = false,
    MerchantBuyPotions    = true,
    MerchantBuyEssences   = true,
    MerchantBuyCapsules   = true,
    MerchantBuyTickets    = true,
    MerchantBuyMaterials  = true,
    MerchantSelectedItems = {},
    MerchantMinGold       = 0,

    -- 🏃 Player Stats & Movement
    WalkSpeed             = 16,
    JumpPower             = 50,
    InfJump               = false,

    -- 🖥️ Graphics & Performance
    PotatoGraphics        = false,
    FarmMode              = false,
    AntiLag               = false,
    HideOtherPlayers      = false,
    FreezeNPCs            = false,
    DisableVFX            = false,
    TargetFPS             = 60,

    -- 🌐 Server & Connection
    AutoPrivateServer     = true,
    AntiAFK               = true
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

function ConfigManager.Save(customData)
    if typeof(writefile) ~= "function" then return false end
    if customData and type(customData) == "table" then
        for k, v in pairs(customData) do
            if type(v) == "table" then
                ConfigManager.CurrentConfig[k] = {}
                for subK, subV in pairs(v) do
                    ConfigManager.CurrentConfig[k][subK] = subV
                end
            else
                ConfigManager.CurrentConfig[k] = v
            end
        end
    end

    local success = pcall(function()
        local json = HttpService:JSONEncode(ConfigManager.CurrentConfig)
        writefile(FILE_NAME, json)
    end)
    return success
end

function ConfigManager.Load()
    if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return ConfigManager.CurrentConfig end

    local raw = nil
    if isfile(FILE_NAME) then
        pcall(function() raw = readfile(FILE_NAME) end)
    else
        for _, leg in ipairs(LEGACY_FILES) do
            if isfile(leg) then
                pcall(function() raw = readfile(leg) end)
                if raw and #raw > 0 then break end
            end
        end
    end

    if not raw or #raw == 0 then
        ConfigManager.Save()
        return ConfigManager.CurrentConfig
    end

    local success, result = pcall(function()
        local data = HttpService:JSONDecode(raw)
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
    return ConfigManager.CurrentConfig
end

function ConfigManager.Reset()
    pcall(function()
        if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(FILE_NAME) then
            delfile(FILE_NAME)
        end
    end)
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
    return ConfigManager.CurrentConfig
end

ConfigManager.Load()
_G.RollAnimeConfigManager = ConfigManager
return ConfigManager
