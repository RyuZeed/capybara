-- =================================================================
-- 🌟 RITOD HUB | CATALOG MODULE (FILTERED REAL GACHA UNITS)
-- Game: Roll Anime For Fight / Anime Auto Roll
-- =================================================================

local CatalogModule = {}
_G.CatalogModule = CatalogModule

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local RS = game:GetService("ReplicatedStorage")
local CharInfo = nil
pcall(function()
    local modules = RS:FindFirstChild("Modules")
    if modules then
        local chars = modules:FindFirstChild("Characters")
        if chars then
            local info = chars:FindFirstChild("CharactersInfo")
            if info then CharInfo = require(info) end
        end
    end
end)

if not CharInfo then
    pcall(function()
        for _, desc in ipairs(RS:GetDescendants()) do
            if desc:IsA("ModuleScript") and desc.Name == "CharactersInfo" then
                CharInfo = require(desc)
                break
            end
        end
    end)
end

CharInfo = CharInfo or { Characters = {} }

CatalogModule.RARITY_ORDER = { "Secret", "God", "Mythic", "Legendary", "Epic", "Rare", "Common" }

CatalogModule.RARITY_COLORS = {
    ["Secret"]    = Color3.fromRGB(0, 255, 230),
    ["God"]       = Color3.fromRGB(255, 215, 0),
    ["Mythic"]    = Color3.fromRGB(255, 60, 80),
    ["Legendary"] = Color3.fromRGB(255, 145, 0),
    ["Epic"]      = Color3.fromRGB(180, 80, 255),
    ["Rare"]      = Color3.fromRGB(60, 160, 255),
    ["Common"]    = Color3.fromRGB(180, 190, 205),
}

CatalogModule.UnitsByRarity = {}
CatalogModule.AllUnitsMap = {}

for _, r in ipairs(CatalogModule.RARITY_ORDER) do
    CatalogModule.UnitsByRarity[r] = {}
end

local rawTable = CharInfo.Characters or CharInfo.Units or CharInfo

local SUB_UNITS_BLACKLIST = {
    ["mahoraga"] = true,
    ["rika"] = true,
    ["spider (entoma)"] = true,
    ["spider"] = true,
    ["death knight"] = true,
    ["madara (clone)"] = true,
    ["madara (limbo)"] = true,
    ["madara clone"] = true,
    ["madara limbo"] = true,
    ["narutoclone"] = true,
    ["naruto clone"] = true,
    ["naruto (six path) clone"] = true,
    ["britain army"] = true,
    ["cell jr"] = true,
    ["red ant"] = true,
    ["black ant"] = true,
    ["summonertest"] = true,
    ["base"] = true,
    ["grunt"] = true,
}

local function isSpawnOrSubUnit(rawName, displayName, data, price)
    if price <= 0 then return true end
    if data.IsSubUnit or data.SubUnit or data.Summon or data.IsSummon or data.IsClone or data.Clone or data.SpawnOnly or data.CantRoll or data.NoGacha then
        return true
    end
    
    local n1 = tostring(rawName):lower()
    local n2 = tostring(displayName):lower()
    local clean1 = n1:gsub("%s+", "")
    local clean2 = n2:gsub("%s+", "")
    
    if SUB_UNITS_BLACKLIST[n1] or SUB_UNITS_BLACKLIST[n2] or SUB_UNITS_BLACKLIST[clean1] or SUB_UNITS_BLACKLIST[clean2] then
        return true
    end
    
    if n1:find("clone") or n2:find("clone") or n1:find("summon") or n2:find("summon") or n1:find("limbo") or n2:find("limbo") then
        return true
    end
    
    return false
end

-- Filter Real Purchasable Gacha Units (Exclude Sub-Units / Skill Summons / Clones)
for id, data in pairs(rawTable) do
    if type(data) == "table" then
        local sid = tostring(id)
        local r = data.Rarity or "Common"
        local price = tonumber(data.Price) or 0
        local rawName = data.Name or sid
        local displayName = data.DisplayName or rawName
        
        local isSubUnit = isSpawnOrSubUnit(rawName, displayName, data, price)
        
        if not isSubUnit then
            if not CatalogModule.UnitsByRarity[r] then CatalogModule.UnitsByRarity[r] = {} end
            
            local entry = {
                id = sid,
                name = rawName,
                displayName = displayName,
                rarity = r,
                price = price,
                damage = data.Damage or data.BaseDamage or 0,
                range = data.Range or data.BaseRange or 0,
                cooldown = data.Cooldown or data.BaseCooldown or 0,
            }
            
            table.insert(CatalogModule.UnitsByRarity[r], entry)
            
            -- Multi-alias indexing for exact detection
            local key1 = rawName:lower()
            local key2 = displayName:lower()
            local key3 = key1:gsub("%s+", "")
            local key4 = key2:gsub("%s+", "")
            
            CatalogModule.AllUnitsMap[key1] = entry
            CatalogModule.AllUnitsMap[key2] = entry
            CatalogModule.AllUnitsMap[key3] = entry
            CatalogModule.AllUnitsMap[key4] = entry
            CatalogModule.AllUnitsMap[sid] = entry
        end
    end
end

-- Sort each rarity group by price descending
for r, list in pairs(CatalogModule.UnitsByRarity) do
    table.sort(list, function(a, b) return (a.price or 0) > (b.price or 0) end)
end

return CatalogModule

