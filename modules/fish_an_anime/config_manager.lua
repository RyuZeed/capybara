--[[
	===============================================================
	⚡ RITOD HUB - FISH AN ANIME RNG (CONFIG MANAGER)
	Module: modules/fish_an_anime/config_manager.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local ConfigManager = {}
ConfigManager.__index = ConfigManager

local HttpService = game:GetService("HttpService")

local GAME_FOLDER = "RitodHub/FishAnAnime"
local CONFIG_FILE = GAME_FOLDER .. "/config.json"

ConfigManager.DefaultConfig = {
    -- Auto Fishing
    AutoFish = false,
    FastClick = true,
    AutoFishDelay = 0.05,
    SelectedPond = "Auto",

    -- Backpack & Sell
    AutoEquipBest = false,
    AutoPickUpAll = false,
    AutoSellAll = false,
    AutoSellInterval = 10,
    AutoSellRarities = {
        Common = false,
        Uncommon = false,
        Rare = false,
        Epic = false,
        Legendary = false,
        Mythical = false,
        Secret = false,
        Cosmic = false
    },

    -- Quests & Index
    AutoClaimQuests = false,
    AutoClaimIndex = false,
    QuestClaimInterval = 5,

    -- Upgrades & Rebirth
    AutoUpgrades = false,
    AutoRebirth = false,
    UpgradesInterval = 3,

    -- Potions Active Uptime
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

    -- Auto Buy Boosts Store (Valora)
    AutoBuyBoosts = false,
    AutoBuyBoostsCurrency = "Cash", -- "Cash" or "Gems"
    AutoBuyBoostsInterval = 10,
    AutoBuyBoostsSelected = {
        Offer1 = true, -- Cash 2x ($7.5K)
        Offer2 = false, -- Cash 4x ($20B)
        Offer3 = false, -- Cash 8x ($10Qa)
        Offer4 = true, -- Gems 2x ($15M)
        Offer5 = false, -- Gems 4x ($30B)
        Offer6 = false, -- Gems 8x ($15Qa)
        Offer7 = false, -- Mutation 2x ($50T)
        Offer8 = true, -- Fast Catch 2x ($2.5M)
        Offer9 = false  -- Luck 2x ($10B)
    },

    -- Auto Buy Secret Merchant (Selene)
    AutoBuySelene = false,
    AutoBuySeleneSelected = {
        Offer1 = false, -- Character (5K Gems)
        Offer2 = true,  -- Luck Potion L3 (25K Gems)
        Offer3 = true,  -- Heaven's Collide (20K Gems)
        Offer4 = false, -- Luck Potion L2 ($2.5Qa Cash)
        Offer5 = true,  -- Meteorite ($11M Cash)
        Offer6 = true,  -- Honey ($2M Cash)
        Offer7 = true   -- Sinister ($200M Cash)
    },

    -- Auto Buy Secret Merchant (Angelia)
    AutoBuyAngelia = false,
    AutoBuyAngeliaSelected = {
        Offer1 = false, -- Forgotten Potion (5M Gems)
        Offer2 = true,  -- Backpack Storage +500 (75K Gems)
        Offer3 = false, -- Cybernetic Glitch (750K Gems)
        Offer4 = false, -- Dreamer Potion (200K Gems)
        Offer5 = true,  -- Party Potion (50K Gems)
        Offer6 = false, -- Fast Catch L2 ($100T Cash)
        Offer7 = true,  -- Luck Potion L3 (25K Gems)
        Offer8 = true,  -- EXE Potion (10K Gems)
        Offer9 = true   -- Cosmic Case ($100B Cash)
    },

    -- Auto Buy Fishing Rods & Carry
    AutoBuyFishingRods = false,
    AutoBuyCarry = false,

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
        Ascended = true,
        Divine = true,
        Supreme = true,
        Ancient = true,
        Celestial = true,
        God = true,
        Omniscient = true,
        Cosmic = true,
        Secret = true,
        Rainbow = true,
        Exclusive = true
    },

    -- Misc / Protection
    AntiAFK = true
}

ConfigManager.CurrentConfig = {}
for k, v in pairs(ConfigManager.DefaultConfig) do
    if typeof(v) == "table" then
        local copy = {}
        for subK, subV in pairs(v) do copy[subK] = subV end
        ConfigManager.CurrentConfig[k] = copy
    else
        ConfigManager.CurrentConfig[k] = v
    end
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
                        if typeof(v) == "table" and typeof(ConfigManager.CurrentConfig[k]) == "table" then
                            for subK, subV in pairs(v) do
                                ConfigManager.CurrentConfig[k][subK] = subV
                            end
                        else
                            ConfigManager.CurrentConfig[k] = v
                        end
                    end
                end
            end
        end
    end)
    return success
end

function ConfigManager.Reset()
    for k, v in pairs(ConfigManager.DefaultConfig) do
        if typeof(v) == "table" then
            local copy = {}
            for subK, subV in pairs(v) do copy[subK] = subV end
            ConfigManager.CurrentConfig[k] = copy
        else
            ConfigManager.CurrentConfig[k] = v
        end
    end
    ConfigManager.Save()
end

ConfigManager.Load()

_G.FishAnAnimeConfigManager = ConfigManager
return ConfigManager
