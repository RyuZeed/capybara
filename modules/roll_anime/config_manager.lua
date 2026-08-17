-- =================================================================
-- 💾 RITOD HUB | CONFIG MANAGER (PER-USER FILE PERSISTENCE)
-- Game: Roll Anime For Fight / Anime Auto Roll
-- Path: RitodHub/RollAnimeForFight/<Username>.json
-- =================================================================

local ConfigManager = {}
_G.ConfigManager = ConfigManager

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local ROOT_FOLDER = "RitodHub"
local GAME_FOLDER = "RitodHub/RollAnimeForFight"
local CONFIG_PATH = "RitodHub/RollAnimeForFight/config.json"

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
    AutoHuntEnabled  = false,
    AutoSecretGod    = false,
    AutoClaimQuests  = true,
    AutoClaimRewards = true,
    RollInterval     = 2.5,
    SelectedUnits    = {},
    WalkSpeed        = 16,
    JumpPower        = 50,
    InfJump          = false,
    PotatoGraphics   = false,
    FarmMode         = false,
    AntiLag          = false,
    AutoPrivateServer = false
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
            if k == "SelectedUnits" and type(v) == "table" then
                ConfigManager.CurrentConfig.SelectedUnits = deepCopy(v)
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
            -- Sync to Default profile as well for ModernSettings
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
                    if k == "SelectedUnits" and type(v) == "table" then
                        ConfigManager.CurrentConfig.SelectedUnits = {}
                        for name, val in pairs(v) do
                            if val then
                                ConfigManager.CurrentConfig.SelectedUnits[tostring(name):lower()] = true
                            end
                        end
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
