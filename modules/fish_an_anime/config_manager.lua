--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (CONFIG MANAGER V2.5)
	Module: modules/fish_an_anime/config_manager.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local HttpService = game:GetService("HttpService")
local FILE_NAME = "RitodHub_FishAnAnime_Config.json"

ConfigManager.DefaultConfig = {
    -- Auto Fishing
    AutoFish = false,
    FastClick = true,
    AutoEquipBest = false,
    AutoPickUpAll = false,
    AutoSellAll = false,
    AutoSellInterval = 10,
    AutoSellByRarity = false,
    AutoSellRarities = {
        Common = true,
        Uncommon = true,
        Rare = true,
        Epic = true,
        Legendary = false,
        Mythical = false,
        Cosmic = false,
        Secret = false,
        Rainbow = false,
        Ascended = false,
        Divine = false,
        Supreme = false,
        Celestial = false,
        Ancient = false,
        God = false,
        Omniscient = false,
        Exclusive = false
    },

    -- Base Units Level Up & Scanner
    AutoLevelUpBaseUnits = false,
    BaseUnitsInterval = 10,
    FilterLevelUpByRarity = false,
    LevelUpSelectedRarities = {
        Common = false,
        Uncommon = false,
        Rare = false,
        Epic = false,
        Legendary = true,
        Mythical = true,
        Cosmic = true,
        Secret = true,
        Rainbow = true,
        Ascended = true,
        Divine = true,
        Supreme = true,
        Celestial = true,
        Ancient = true,
        God = true,
        Omniscient = true,
        Exclusive = true
    },

    -- Quests & Rewards
    AutoClaimQuests = false,
    QuestClaimInterval = 5,
    AutoClaimIndex = false,
    AutoClaimPlaytime = false,
    AutoClaimDaily = false,
    AutoClaimMedals = false,

    -- Specific Upgrades
    AutoUpgrades = false,
    UpgradesInterval = 3,
    AutoUpgradesSelected = {
        T1O1 = true, -- Cash
        T1O2 = true, -- Luck
        T2O1 = true, -- Mutation Chance
        T2O2 = true, -- Better Mutations
        T2O3 = true, -- Level Discount
        T3O1 = true, -- Offline Earnings
        T3O2 = true, -- Potion Time
        T3O3 = true, -- Faster Catch
        T4O1 = true, -- Secret Catch Rate
        T4O2 = true, -- Rainbow Catch Rate
        T4O3 = true, -- Ancient Catch Rate
        T5O1 = true, -- God Catch Rate
        T5O2 = true  -- Omniscient Catch Rate
    },

    -- Rebirth
    AutoRebirth = false,
    RebirthInterval = 3,

    -- Potions Uptime Buffer
    AutoPotions = false,
    PotionInterval = 10,
    SelectedPotions = {
        ["Luck Potion Lvl. 1"] = true,
        ["Luck Potion Lvl. 2"] = true,
        ["Luck Potion Lvl. 3"] = true,
        ["Fast Catch Potion Lvl. 1"] = true,
        ["Fast Catch Potion Lvl. 2"] = true,
        ["Mutation Potion Lvl. 1"] = true,
        ["Gems Potion Lvl. 1"] = true,
        ["Gems Potion Lvl. 2"] = true,
        ["Gems Potion Lvl. 3"] = true,
        ["Cash Potion Lvl. 1"] = true,
        ["Cash Potion Lvl. 2"] = true,
        ["Cash Potion Lvl. 3"] = true
    },

    -- Boosts Store (NPC Valora)
    AutoBuyBoosts = false,
    AutoBuyBoostsCurrency = "Cash",
    AutoBuyBoostsSelected = {
        Offer1 = true,
        Offer2 = true,
        Offer3 = true,
        Offer4 = true,
        Offer5 = true,
        Offer6 = true,
        Offer7 = true,
        Offer8 = true,
        Offer9 = true
    },

    -- Secret Merchant: Selene
    AutoBuySelene = false,
    AutoBuySeleneSelected = {
        Offer1 = true,
        Offer2 = true,
        Offer3 = true,
        Offer4 = true,
        Offer5 = true,
        Offer6 = true,
        Offer7 = true,
        OfferFood = true,
        OfferAbility1 = false,
        OfferAbility2 = false,
        OfferAbility3 = false,
        OfferAbility4 = false
    },

    -- Secret Merchant: Angelia
    AutoBuyAngelia = false,
    AutoBuyAngeliaSelected = {
        Offer1 = true,
        Offer2 = true,
        Offer3 = true,
        Offer4 = true,
        Offer5 = true,
        Offer6 = true,
        Offer7 = true,
        Offer8 = true,
        Offer9 = true,
        OfferAbility3 = false
    },

    -- Secret Merchant: Yang
    AutoBuyYang = false,
    AutoBuyYangSelected = {
        OfferAbility1 = false
    },

    -- Auto Buy Fishing Rods & Carry
    AutoBuyFishingRods = false,
    AutoBuyCarry = false,

    -- Graphics & Performance
    PotatoGraphics = false,
    BlackScreenAFK = false,
    PerformanceMode = true,
    DisableVFX = true,
    TargetFPS = 60,

    -- Misc / Protection
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
_G.FishAnAnimeConfigManager = ConfigManager
return ConfigManager
