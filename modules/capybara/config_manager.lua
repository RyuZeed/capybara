-- =================================================================
-- 💾 RITOD HUB | CONFIG MANAGER (UNIVERSAL SINGLE-FILE PERSISTENCE)
-- Game: Capybaras vs Plants
-- Path: RitodHub/Capybara/config.json
-- =================================================================

local ConfigManager = {}
_G.CapybaraConfigManager = ConfigManager

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local ROOT_FOLDER = "RitodHub"
local GAME_FOLDER = "RitodHub/Capybara"
local CONFIG_PATH = "RitodHub/Capybara/config.json"

ConfigManager.ConfigPath = CONFIG_PATH
ConfigManager.GameFolder = GAME_FOLDER

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

ConfigManager.DefaultConfig = {
    AutoTutorial       = true,
    AutoCollectMoney   = false,
    AutoDelete         = false,
    AutoClaim          = true,
    AutoClaimQuest     = true,
    AutoGift           = false,
    AutoAcceptGift     = true,
    GiftTarget         = "",
    SelectedGiftItems  = {},
    WalkSpeed          = 16,
    JumpPower          = 50,
    InfJump            = false,
    AutoBuyEgg         = false,
    BuyAllStock        = true,
    AutoPlaceEgg       = false,
    AutoHatchEgg       = false,
    SelectedEggs       = {
        ["capybara egg"] = true,
    },
    AutoBuyShop        = false,
    HatchWait          = 8,
    FarmMode           = false,
    AntiLag            = false,
    PotatoGraphics     = true,
    AntiAFK            = true,
    PinkRemover        = true,
    ProtectEquipped    = true,
    AutoEquipBestFirst = true,
    AutoSyncInGameUI   = true,
    SelectedPlants     = {
        ["carrot"]              = true,
        ["potato"]              = true,
        ["orange tulip"]        = true,
        ["broccoli"]            = true,
        ["sunflower"]           = true,
        ["tomato"]              = true,
        ["fancy avocado"]       = true,
        ["cocotree"]            = true,
        ["fancy ghost avocado"] = true,
    }
}

ConfigManager.CurrentConfig = deepCopy(ConfigManager.DefaultConfig)

local function ensureFolders()
    pcall(function()
        if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
            if not isfolder(ROOT_FOLDER) then makefolder(ROOT_FOLDER) end
            if not isfolder(GAME_FOLDER) then makefolder(GAME_FOLDER) end
            if not isfolder(GAME_FOLDER .. "/Configs") then makefolder(GAME_FOLDER .. "/Configs") end
        end
    end)
end

function ConfigManager.Save(newConfig)
    if newConfig and type(newConfig) == "table" then
        for k, v in pairs(newConfig) do
            if type(v) == "table" then
                ConfigManager.CurrentConfig[k] = deepCopy(v)
            else
                ConfigManager.CurrentConfig[k] = v
            end
        end
    end

    local success = pcall(function()
        if typeof(writefile) == "function" then
            ensureFolders()
            local jsonString = HttpService:JSONEncode(ConfigManager.CurrentConfig)
            writefile(CONFIG_PATH, jsonString)
            -- Sync ke Default profile juga untuk ModernSettings
            pcall(function()
                writefile(GAME_FOLDER .. "/Configs/Default.json", jsonString)
            end)
        end
    end)

    return success
end

function ConfigManager.Load()
    ensureFolders()
    pcall(function()
        local raw = nil
        if typeof(readfile) == "function" and typeof(isfile) == "function" then
            if isfile(CONFIG_PATH) then
                raw = readfile(CONFIG_PATH)
            elseif isfile(GAME_FOLDER .. "/Configs/Default.json") then
                raw = readfile(GAME_FOLDER .. "/Configs/Default.json")
            end
        end

        if raw and #raw > 0 then
            local data = HttpService:JSONDecode(raw)
            if typeof(data) == "table" then
                for k, v in pairs(data) do
                    if type(v) == "table" then
                        ConfigManager.CurrentConfig[k] = deepCopy(v)
                    else
                        ConfigManager.CurrentConfig[k] = v
                    end
                end
            end
        end
    end)
    return ConfigManager.CurrentConfig
end

function ConfigManager.Reset()
    pcall(function()
        if typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(CONFIG_PATH) then
            delfile(CONFIG_PATH)
        end
    end)
    for k in pairs(ConfigManager.CurrentConfig) do ConfigManager.CurrentConfig[k] = nil end
    for k, v in pairs(ConfigManager.DefaultConfig) do ConfigManager.CurrentConfig[k] = deepCopy(v) end
    return ConfigManager.CurrentConfig
end

return ConfigManager
