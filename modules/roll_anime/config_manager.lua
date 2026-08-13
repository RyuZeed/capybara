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
local CONFIG_PATH = string.format("RitodHub/RollAnimeForFight/%s.json", LocalPlayer.Name)

ConfigManager.ConfigPath = CONFIG_PATH

ConfigManager.CurrentConfig = {
    AutoHuntEnabled = false,
    AutoSecretGod = false,
    AutoClaimQuests = true,
    AutoClaimRewards = true,
    RollInterval = 2.5,
    SelectedUnits = {},
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    PotatoGraphics = false,
    FarmMode = false,
    AntiLag = false
}

local function ensureFolders()
    pcall(function()
        if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
            if not isfolder(ROOT_FOLDER) then
                makefolder(ROOT_FOLDER)
            end
            if not isfolder(GAME_FOLDER) then
                makefolder(GAME_FOLDER)
            end
        end
    end)
end

function ConfigManager.Save(newConfig)
    if newConfig then
        for k, v in pairs(newConfig) do
            ConfigManager.CurrentConfig[k] = v
        end
    end

    local success, err = pcall(function()
        if typeof(writefile) == "function" then
            ensureFolders()
            local jsonString = HttpService:JSONEncode(ConfigManager.CurrentConfig)
            writefile(CONFIG_PATH, jsonString)
        end
    end)

    return success
end

function ConfigManager.Load()
    ensureFolders()
    local success, err = pcall(function()
        if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(CONFIG_PATH) then
            local content = readfile(CONFIG_PATH)
            if content and #content > 0 then
                local data = HttpService:JSONDecode(content)
                if typeof(data) == "table" then
                    if data.AutoHuntEnabled ~= nil then ConfigManager.CurrentConfig.AutoHuntEnabled = data.AutoHuntEnabled end
                    if data.AutoSecretGod ~= nil then ConfigManager.CurrentConfig.AutoSecretGod = data.AutoSecretGod end
                    if data.AutoClaimQuests ~= nil then ConfigManager.CurrentConfig.AutoClaimQuests = data.AutoClaimQuests end
                    if data.AutoClaimRewards ~= nil then ConfigManager.CurrentConfig.AutoClaimRewards = data.AutoClaimRewards end
                    if data.RollInterval ~= nil then ConfigManager.CurrentConfig.RollInterval = data.RollInterval end
                    if data.WalkSpeed ~= nil then ConfigManager.CurrentConfig.WalkSpeed = data.WalkSpeed end
                    if data.JumpPower ~= nil then ConfigManager.CurrentConfig.JumpPower = data.JumpPower end
                    if data.InfJump ~= nil then ConfigManager.CurrentConfig.InfJump = data.InfJump end
                    if data.PotatoGraphics ~= nil then ConfigManager.CurrentConfig.PotatoGraphics = data.PotatoGraphics end
                    if data.FarmMode ~= nil then ConfigManager.CurrentConfig.FarmMode = data.FarmMode end
                    if data.AntiLag ~= nil then ConfigManager.CurrentConfig.AntiLag = data.AntiLag end
                    
                    if typeof(data.SelectedUnits) == "table" then
                        ConfigManager.CurrentConfig.SelectedUnits = {}
                        for name, val in pairs(data.SelectedUnits) do
                            if val then
                                ConfigManager.CurrentConfig.SelectedUnits[name:lower()] = true
                            end
                        end
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
    ConfigManager.CurrentConfig = {
        AutoHuntEnabled = false,
        AutoSecretGod = false,
        RollInterval = 2.5,
        SelectedUnits = {},
        WalkSpeed = 16,
        JumpPower = 50,
        InfJump = false,
        PotatoGraphics = false,
        FarmMode = false,
        AntiLag = false
    }
    return ConfigManager.CurrentConfig
end

return ConfigManager
