-- =================================================================
-- 🔍 RITOD HUB | ROLL ANIME IN-GAME SCANNER & DUMPER v2.0
-- Game: Roll Anime For Fight / Anime Auto Roll
-- Description: Deep scanner untuk CharactersInfo, Traits, Evolution,
--              Mutations, Remotes, dan Prompts.
-- =================================================================

local Scanner = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

local function log(prefix, msg)
    local tag = string.format("[🔍 %s]", prefix)
    print(tag, msg)
    if rconsoleprint then
        rconsoleprint(tag .. " " .. tostring(msg) .. "\n")
    end
end

-- Sanitizer agar aman di-encode ke JSON (menghapus function, userdata, cyclic refs)
local function sanitizeForJSON(value, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 8 then return "<Max Depth>" end

    local vType = typeof(value)
    if vType == "table" then
        if visited[value] then return "<Cyclic Reference>" end
        visited[value] = true
        
        local clean = {}
        for k, v in pairs(value) do
            local cleanKey = tostring(k)
            local cleanVal = sanitizeForJSON(v, depth + 1, visited)
            if cleanVal ~= nil then
                clean[cleanKey] = cleanVal
            end
        end
        return clean
    elseif vType == "string" or vType == "number" or vType == "boolean" then
        return value
    elseif vType == "Instance" then
        return value:GetFullName()
    elseif vType == "Vector3" then
        return { X = value.X, Y = value.Y, Z = value.Z }
    elseif vType == "Color3" then
        return { R = value.R, G = value.G, B = value.B }
    elseif vType == "CFrame" then
        return tostring(value)
    elseif vType == "function" then
        return "<Function>"
    else
        return tostring(value)
    end
end

-- =================================================================
-- 1. SCANNER & DUMPER MODULES LENGKAP
-- =================================================================
function Scanner.ScanAllGameModules()
    log("MODULES", "Scanning all modules in ReplicatedStorage...")
    local discovered = {}
    local rawModules = {}

    local modulesFolder = RS:FindFirstChild("Modules")
    local searchList = modulesFolder and modulesFolder:GetDescendants() or RS:GetDescendants()

    for _, desc in ipairs(searchList) do
        if desc:IsA("ModuleScript") then
            local modName = desc.Name
            local s, res = pcall(function() return require(desc) end)
            if s and type(res) == "table" then
                discovered[modName] = {
                    Path = desc:GetFullName(),
                    KeyCount = (function()
                        local c = 0
                        for _ in pairs(res) do c = c + 1 end
                        return c
                    end)(),
                    SampleKeys = (function()
                        local keys = {}
                        for k in pairs(res) do
                            if #keys < 10 then table.insert(keys, tostring(k)) end
                        end
                        return keys
                    end)()
                }
                rawModules[modName] = res
                log("MODULES", string.format("✅ Loaded [%s] (%d keys)", modName, discovered[modName].KeyCount))
            else
                log("WARN", "Gagal require " .. modName .. ": " .. tostring(res))
            end
        end
    end

    return discovered, rawModules
end

-- =================================================================
-- 2. PARSER KHUSUS CHARACTERS INFO (UNIT GACHA & SECRET/GOD)
-- =================================================================
function Scanner.ParseCharacters(rawModules)
    local charMod = rawModules["CharactersInfo"] or rawModules["CharacterInfo"] or rawModules["Characters"]
    if not charMod then
        -- Coba cari di module lain
        for name, mod in pairs(rawModules) do
            if mod.Characters or mod.CharacterList then
                charMod = mod
                break
            end
        end
    end

    if not charMod then
        return { error = "CharactersInfo module not found" }
    end

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

    local function isSpawnOrSubUnit(rawName, displayName, info, price)
        if price <= 0 then return true end
        if info.IsSubUnit or info.SubUnit or info.Summon or info.IsSummon or info.IsClone or info.Clone or info.SpawnOnly or info.CantRoll or info.NoGacha then
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

    local charTable = charMod.Characters or charMod.CharacterList or charMod
    local parsed = {
        Total = 0,
        Rarities = {},
        UnitsList = {},
        GachaOnly = {},
        SecretAndGod = {},
        SubUnitsSpawns = {}
    }

    for id, info in pairs(charTable) do
        if type(info) == "table" then
            parsed.Total = parsed.Total + 1
            local sid = tostring(id)
            local r = info.Rarity or "Common"
            local price = tonumber(info.Price) or 0
            local name = info.Name or info.DisplayName or sid
            local dispName = info.DisplayName or name
            local isSub = isSpawnOrSubUnit(name, dispName, info, price)

            if not isSub then
                parsed.Rarities[r] = (parsed.Rarities[r] or 0) + 1
            end

            local unitObj = {
                id = sid,
                name = name,
                displayName = dispName,
                rarity = r,
                price = price,
                isSubUnit = isSub,
                baseDamage = info.Damage or info.BaseDamage,
                baseRange = info.Range or info.BaseRange,
                baseCooldown = info.Cooldown or info.BaseCooldown,
                attributes = info.Attributes or info.Traits or nil
            }

            table.insert(parsed.UnitsList, unitObj)

            if not isSub then
                table.insert(parsed.GachaOnly, unitObj)
                if r == "Secret" or r == "God" or r == "Mythic" then
                    table.insert(parsed.SecretAndGod, unitObj)
                end
            else
                table.insert(parsed.SubUnitsSpawns, unitObj)
            end
        end
    end

    table.sort(parsed.SecretAndGod, function(a, b) return a.price > b.price end)
    table.sort(parsed.GachaOnly, function(a, b) return a.price > b.price end)
    table.sort(parsed.UnitsList, function(a, b) return a.price > b.price end)

    return parsed
end

-- =================================================================
-- 3. SCANNER REMOTES & NETWORK
-- =================================================================
function Scanner.ScanRemotes()
    log("REMOTES", "Scanning all Remotes...")
    local remotes = {
        RemoteEvents = {},
        RemoteFunctions = {},
        CharactersRemotes = {}
    }

    for _, desc in ipairs(RS:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            local entry = {
                Name = desc.Name,
                Class = desc.ClassName,
                Path = desc:GetFullName()
            }
            if desc:IsA("RemoteEvent") then
                table.insert(remotes.RemoteEvents, entry)
            else
                table.insert(remotes.RemoteFunctions, entry)
            end

            if desc:GetFullName():find("Character") or desc:GetFullName():find("Roll") or desc:GetFullName():find("Buy") then
                table.insert(remotes.CharactersRemotes, entry)
            end
        end
    end

    return remotes
end

-- =================================================================
-- 4. SCANNER PLOT & PROMPTS
-- =================================================================
function Scanner.ScanPlot()
    log("PLOT", "Scanning player plot...")
    local plotInfo = {
        found = false,
        plotName = nil,
        rollPrompt = nil,
        pedestals = {}
    }

    local plots = WS:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local match = false
            for _, val in pairs(plot:GetAttributes()) do
                if tostring(val) == LocalPlayer.Name or tostring(val) == tostring(LocalPlayer.UserId) then
                    match = true; break
                end
            end
            if not match then
                local nb = plot:FindFirstChild("NameBillboardPart", true)
                if nb then
                    for _, lbl in ipairs(nb:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Text:find(LocalPlayer.Name) then
                            match = true; break
                        end
                    end
                end
            end

            if match then
                plotInfo.found = true
                plotInfo.plotName = plot.Name
                for _, p in ipairs(plot:GetDescendants()) do
                    if p:IsA("ProximityPrompt") then
                        local pObj = {
                            Name = p.Name,
                            Action = p.ActionText,
                            Parent = p.Parent.Name,
                            Hold = p.HoldDuration
                        }
                        if p.Name:lower():find("roll") or tostring(p.ActionText):lower():find("roll") then
                            plotInfo.rollPrompt = pObj
                        else
                            table.insert(plotInfo.pedestals, pObj)
                        end
                    end
                end
                break
            end
        end
    end

    return plotInfo
end

-- =================================================================
-- 5. RUN FULL SCAN & EXPORT
-- =================================================================
function Scanner.RunFullScan()
    print("=========================================================")
    print("🚀 [RITOD HUB] MEMULAI PEMINDAIAN LENGKAP ROLL ANIME...")
    print("=========================================================")

    local modMeta, rawModules = Scanner.ScanAllGameModules()
    local charData = Scanner.ParseCharacters(rawModules)
    local remotes = Scanner.ScanRemotes()
    local plot = Scanner.ScanPlot()

    print("\n=========================================================")
    print("📊 [HASIL ANALISIS DATA UNIT TERBARU]")
    print(string.format("⭐ Total Unit di Database: %d unit", charData.Total or 0))
    print(string.format("🎰 Unit Gacha Asli (Purchasable): %d unit", #(charData.GachaOnly or {})))
    
    print("\n🏷️ Breakdown Jumlah Unit per Rarity:")
    for rarity, count in pairs(charData.Rarities or {}) do
        print(string.format("   - %-12s: %d unit", rarity, count))
    end

    print("\n👑 DAFTAR UNIT TOP SECRET & GOD:")
    for i, u in ipairs(charData.SecretAndGod or {}) do
        if i <= 15 then
            print(string.format("   [%d] [%s] %s | Harga: $%s (ID: %s)", i, u.rarity, u.displayName, tostring(u.price), u.id))
        end
    end
    if #(charData.SecretAndGod or {}) > 15 then
        print(string.format("   ... dan %d unit langka lainnya!", #(charData.SecretAndGod) - 15))
    end

    print("\n📡 REMOTES PENTING TERDETEKSI:")
    for _, r in ipairs(remotes.CharactersRemotes) do
        print(string.format("   - [%s] %s -> %s", r.Class, r.Name, r.Path))
    end

    if plot.found then
        print(string.format("\n🏡 Plot Pemain: %s (RollPrompt: %s, %d Pedestal)", 
            plot.plotName, 
            plot.rollPrompt and "✅ Ada" or "❌ Tidak Ada",
            #plot.pedestals
        ))
    end

    -- Build clean export object
    local fullExport = {
        ScanTime = os.date("!%Y-%m-%d %H:%M:%S UTC"),
        Player = LocalPlayer.Name,
        Summary = {
            TotalUnits = charData.Total,
            PurchasableUnits = #(charData.GachaOnly or {}),
            Rarities = charData.Rarities,
            RemotesCount = #remotes.RemoteEvents + #remotes.RemoteFunctions
        },
        Units = {
            SecretAndGod = charData.SecretAndGod,
            AllGachaUnits = charData.GachaOnly
        },
        Remotes = remotes,
        Plot = plot,
        OtherModulesDiscovered = modMeta,
        Traits = sanitizeForJSON(rawModules["TraitInfo"]),
        Mutations = sanitizeForJSON(rawModules["MutationInfo"]),
        Evolutions = sanitizeForJSON(rawModules["EvolutionInfo"])
    }

    local sanitizedExport = sanitizeForJSON(fullExport)
    local s, jsonStr = pcall(function() return HttpService:JSONEncode(sanitizedExport) end)
    
    if s and jsonStr then
        if writefile then
            pcall(function()
                writefile("RollAnime_Dump.json", jsonStr)
                print("\n💾 [FILE] Berhasil dump lengkap ke: RollAnime_Dump.json")
            end)
        end
        if setclipboard then
            pcall(function()
                setclipboard(jsonStr)
                print("📋 [CLIPBOARD] Data JSON lengkap telah disalin ke Clipboard!")
            end)
        end
    else
        log("WARN", "Gagal serialize JSON: " .. tostring(jsonStr))
    end

    print("=========================================================\n")
    return fullExport
end

-- Auto execute
task.spawn(function()
    Scanner.RunFullScan()
end)

return Scanner
