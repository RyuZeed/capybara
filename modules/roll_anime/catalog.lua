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
            if desc:IsA("ModuleScript") and (desc.Name == "CharactersInfo" or desc.Name == "CharacterInfo") then
                CharInfo = require(desc)
                break
            end
        end
    end)
end

CharInfo = CharInfo or { Characters = {} }

CatalogModule.ALLOWED_RARITIES = {
    ["Supreme"] = true,
    ["God"]     = true,
    ["Secret"]  = true,
    ["Mythic"]  = true,
    ["Limited"] = true,
    ["Divine"]  = true,
    ["Special"] = true,
}

CatalogModule.DEFAULT_RARITY_ORDER = { "Supreme", "God", "Secret", "Mythic", "Limited", "Divine", "Special" }
CatalogModule.RARITY_ORDER = {}

CatalogModule.RARITY_COLORS = {
    ["Supreme"]   = Color3.fromRGB(255, 45, 140),
    ["God"]       = Color3.fromRGB(255, 215, 0),
    ["Secret"]    = Color3.fromRGB(0, 255, 230),
    ["Mythic"]    = Color3.fromRGB(255, 60, 80),
    ["Limited"]   = Color3.fromRGB(255, 105, 180),
    ["Divine"]    = Color3.fromRGB(255, 230, 100),
    ["Special"]   = Color3.fromRGB(140, 255, 170),
}

CatalogModule.UnitsByRarity = {}
CatalogModule.AllUnitsMap = {}

local rawTable = CharInfo.Characters or CharInfo.Units or CharInfo.CharacterList or CharInfo

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

local function isNonRollableUnit(rawName, displayName, data)
    -- 1. Deteksi SubUnit / Spawn / Clone / Summon
    if data.IsSubUnit or data.SubUnit or data.Summon or data.IsSummon or data.IsClone or data.Clone or data.SpawnOnly or data.CantRoll or data.NoGacha or data.NoRoll then
        return true
    end

    -- 2. Deteksi Unit dari hasil Evolusi / Fusion / Crafting
    if data.IsEvolution or data.Evolution or data.Evolve or data.Evolved or data.IsEvolve then
        return true
    end
    if data.IsFusion or data.Fusion or data.Fused or data.IsFused then
        return true
    end
    if data.Craft or data.IsCraftable or data.Craftable or data.IsCraft then
        return true
    end
    if data.RequireUnits or data.Ingredients or data.Materials or data.Recipe or data.Formula or data.Requirements then
        return true
    end
    if data.ObtainMethod and (data.ObtainMethod == "Evolve" or data.ObtainMethod == "Fusion" or data.ObtainMethod == "Craft" or data.ObtainMethod == "Evolution") then
        return true
    end
    if data.Obtain and (data.Obtain == "Evolve" or data.Obtain == "Fusion" or data.Obtain == "Craft" or data.Obtain == "Evolution") then
        return true
    end

    local n1 = tostring(rawName):lower()
    local n2 = tostring(displayName):lower()
    local clean1 = n1:gsub("%s+", "")
    local clean2 = n2:gsub("%s+", "")

    -- Blacklist unit summon / clone
    if SUB_UNITS_BLACKLIST[n1] or SUB_UNITS_BLACKLIST[n2] or SUB_UNITS_BLACKLIST[clean1] or SUB_UNITS_BLACKLIST[clean2] then
        return true
    end

    if n1:find("clone") or n2:find("clone") or n1:find("summon") or n2:find("summon") or n1:find("limbo") or n2:find("limbo") then
        return true
    end

    -- Filter nama berakhiran (evolved), (evolution), (fusion), (fused), (craft)
    if n1:find("%(evolve") or n2:find("%(evolve") or n1:find("%(evolution") or n2:find("%(evolution") or 
       n1:find("%(fused") or n2:find("%(fused") or n1:find("%(fusion") or n2:find("%(fusion") or 
       n1:find("%(craft") or n2:find("%(craft") then
        return true
    end

    return false
end

local seenRarities = {}

-- 1. Scan and Parse Units (Hanya unit rollable & rarity tinggi)
for id, data in pairs(rawTable) do
    if type(data) == "table" then
        local sid = tostring(id)
        local r = tostring(data.Rarity or data.rarity or "Common")
        local price = tonumber(data.Price or data.price or data.Cost or data.cost or data.GachaPrice or 0) or 0
        local rawName = tostring(data.Name or data.name or sid)
        local displayName = tostring(data.DisplayName or data.displayName or data.Title or rawName)

        -- Filter: Hilangkan Common, Rare, Epic, Legendary & Hilangkan Sub-unit / Fusion / Evolution
        if CatalogModule.ALLOWED_RARITIES[r] and not isNonRollableUnit(rawName, displayName, data) then
            if not CatalogModule.UnitsByRarity[r] then
                CatalogModule.UnitsByRarity[r] = {}
            end
            seenRarities[r] = true

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
            local k1 = rawName:lower()
            local k2 = displayName:lower()
            local k3 = k1:gsub("%s+", "")
            local k4 = k2:gsub("%s+", "")
            local k5 = k1:gsub("[^%w%s]", ""):gsub("%s+", "")
            local k6 = k2:gsub("[^%w%s]", ""):gsub("%s+", "")

            CatalogModule.AllUnitsMap[k1] = entry
            CatalogModule.AllUnitsMap[k2] = entry
            CatalogModule.AllUnitsMap[k3] = entry
            CatalogModule.AllUnitsMap[k4] = entry
            CatalogModule.AllUnitsMap[k5] = entry
            CatalogModule.AllUnitsMap[k6] = entry
            CatalogModule.AllUnitsMap[sid] = entry
            CatalogModule.AllUnitsMap[sid:lower()] = entry
        end
    end
end

-- 2. Build complete RARITY_ORDER (Supreme selalu di paling atas)
local rarityOrderMap = {}
for _, r in ipairs(CatalogModule.DEFAULT_RARITY_ORDER) do
    if seenRarities[r] or CatalogModule.UnitsByRarity[r] then
        table.insert(CatalogModule.RARITY_ORDER, r)
        rarityOrderMap[r] = true
    end
end

for r, _ in pairs(seenRarities) do
    if not rarityOrderMap[r] and CatalogModule.ALLOWED_RARITIES[r] then
        table.insert(CatalogModule.RARITY_ORDER, r)
        rarityOrderMap[r] = true
        if not CatalogModule.RARITY_COLORS[r] then
            CatalogModule.RARITY_COLORS[r] = Color3.fromRGB(200, 160, 255)
        end
    end
end

-- 3. Sort each rarity group by price descending
for r, list in pairs(CatalogModule.UnitsByRarity) do
    table.sort(list, function(a, b) return (a.price or 0) > (b.price or 0) end)
end

return CatalogModule

