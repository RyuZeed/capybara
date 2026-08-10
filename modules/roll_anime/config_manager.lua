-- =================================================================
-- 💾 RITOD HUB | CONFIG MANAGER (PER-USER FILE PERSISTENCE)
-- Game: Roll Anime For Fight / Anime Auto Roll
-- Path: RitodHub/RollAnimeForFight/<Username>.json
-- =================================================================

local ConfigManager = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local ROOT_FOLDER = "RitodHub"
local GAME_FOLDER = "RitodHub/RollAnimeForFight"
local CONFIG_PATH = string.format("RitodHub/RollAnimeForFight/%s.json", LocalPlayer.Name)

ConfigManager.ConfigPath = CONFIG_PATH

ConfigManager.CurrentConfig = {
    AutoHuntEnabled = false,
    RollInterval = 2.5,
    SelectedUnits = {},
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false
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

    if success then
        print("💾 [ConfigManager] Tersimpan ke: " .. CONFIG_PATH)
    else
        warn("⚠️ [ConfigManager] Gagal menyimpan config: " .. tostring(err))
    end
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
                    if data.RollInterval ~= nil then ConfigManager.CurrentConfig.RollInterval = data.RollInterval end
                    if data.WalkSpeed ~= nil then ConfigManager.CurrentConfig.WalkSpeed = data.WalkSpeed end
                    if data.JumpPower ~= nil then ConfigManager.CurrentConfig.JumpPower = data.JumpPower end
                    if data.InfJump ~= nil then ConfigManager.CurrentConfig.InfJump = data.InfJump end
                    
                    if typeof(data.SelectedUnits) == "table" then
                        ConfigManager.CurrentConfig.SelectedUnits = {}
                        for name, val in pairs(data.SelectedUnits) do
                            if val then
                                ConfigManager.CurrentConfig.SelectedUnits[name:lower()] = true
                            end
                        end
                    end
                    print("💾 [ConfigManager] Berhasil memuat config dari: " .. CONFIG_PATH)
                end
            end
        end
    end)

    if not success then
        warn("⚠️ [ConfigManager] Gagal membaca config: " .. tostring(err))
    end
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
        RollInterval = 2.5,
        SelectedUnits = {},
        WalkSpeed = 16,
        JumpPower = 50,
        InfJump = false
    }
    print("🗑️ [ConfigManager] Config direset ke default.")
    return ConfigManager.CurrentConfig
end

return ConfigManager
