-- =================================================================
-- 🌟 RITOD HUB | CATALOG MODULE (FILTERED REAL GACHA UNITS)
-- Game: Roll Anime For Fight / Anime Auto Roll
-- =================================================================

local CatalogModule = {}

local RS = game:GetService("ReplicatedStorage")
local CharInfo = require(RS:WaitForChild("Modules"):WaitForChild("Characters"):WaitForChild("CharactersInfo"))

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

-- Filter Real Purchasable Gacha Units (Exclude Sub-Units / Skill Summons)
for id, data in pairs(CharInfo.Characters) do
    local sid = tostring(id)
    local r = data.Rarity or "Common"
    local price = data.Price or 0
    local rawName = data.Name or sid
    local displayName = data.DisplayName or rawName
    
    local isSubUnit = (price <= 0) or data.IsSubUnit or data.SubUnit or data.Summon or data.IsSummon
    
    if not isSubUnit then
        if not CatalogModule.UnitsByRarity[r] then CatalogModule.UnitsByRarity[r] = {} end
        
        local entry = {
            id = sid,
            name = rawName,
            displayName = displayName,
            rarity = r,
            price = price,
        }
        
        table.insert(CatalogModule.UnitsByRarity[r], entry)
        CatalogModule.AllUnitsMap[rawName:lower()] = entry
        CatalogModule.AllUnitsMap[displayName:lower()] = entry
    end
end

-- Sort each rarity group by price descending
for r, list in pairs(CatalogModule.UnitsByRarity) do
    table.sort(list, function(a, b) return a.price > b.price end)
end

print(string.format("🌟 [Catalog] Loaded %d Secret & %d God Units Asli!", 
    #(CatalogModule.UnitsByRarity["Secret"] or {}),
    #(CatalogModule.UnitsByRarity["God"] or {})
))

return CatalogModule
