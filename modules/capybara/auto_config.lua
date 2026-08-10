-- Auto Config for Ritod Hub Auto Delete UI
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG_FOLDER_NAME = "RitodHubAutoDeleteConfig"

local function getFolder()
    local folder = ReplicatedStorage:FindFirstChild(CONFIG_FOLDER_NAME)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = CONFIG_FOLDER_NAME
        folder.Parent = ReplicatedStorage
    end
    return folder
end

local Config = {}

function Config.Load()
    local folder = getFolder()
    local cfg = {}
    cfg.EnableAutoDelete = (folder:FindFirstChild("EnableAutoDelete") and folder.EnableAutoDelete.Value) or true
    cfg.EnableAutoDeleteRarity = (folder:FindFirstChild("EnableAutoDeleteRarity") and folder.EnableAutoDeleteRarity.Value) or true
    return cfg
end

function Config.Save(configTable)
    local folder = getFolder()
    local function ensureBool(name, val)
        local boolVal = folder:FindFirstChild(name)
        if not boolVal then
            boolVal = Instance.new("BoolValue")
            boolVal.Name = name
            boolVal.Parent = folder
        end
        boolVal.Value = val
    end
    ensureBool("EnableAutoDelete", configTable.EnableAutoDelete)
    ensureBool("EnableAutoDeleteRarity", configTable.EnableAutoDeleteRarity)
end

function Config.Set(key, value)
    local cfg = Config.Load()
    cfg[key] = value
    Config.Save(cfg)
end

function Config.Get(key)
    local cfg = Config.Load()
    return cfg[key]
end

return Config
