--[[
	===============================================================
	⚡ RITOD HUB - ANIME DICE (AUTO TRAITS & AUTO GRADES)
	Module: modules/anime_dice/auto_traits_grades.lua
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
]]

local AutoTraitsGrades = {}
AutoTraitsGrades.__index = AutoTraitsGrades

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local network = ReplicatedStorage:WaitForChild("Network", 5)

local traitRE = network and network:FindFirstChild("TraitService") and network.TraitService:FindFirstChild("RE") and network.TraitService.RE:FindFirstChild("Roll")
local gradeRE = network and network:FindFirstChild("GradeService") and network.GradeService:FindFirstChild("RE") and network.GradeService.RE:FindFirstChild("Roll")

local function getRemotes()
    if not traitRE or not gradeRE then
        local net = ReplicatedStorage:FindFirstChild("Network")
        if net then
            if net:FindFirstChild("TraitService") and net.TraitService:FindFirstChild("RE") then
                traitRE = net.TraitService.RE:FindFirstChild("Roll") or traitRE
            end
            if net:FindFirstChild("GradeService") and net.GradeService:FindFirstChild("RE") then
                gradeRE = net.GradeService.RE:FindFirstChild("Roll") or gradeRE
            end
        end
    end
end

-- ─── DAFTAR LENGKAP TRAITS & GRADES DARI GAME ────────────────────
AutoTraitsGrades.TraitsList = {
    "Transcendent",
    "Monarch",
    "Shogun",
    "Samurai",
    "Damage III",
    "Money III",
    "Health III",
    "Damage II",
    "Money II",
    "Health II",
    "Damage I",
    "Money I",
    "Health I"
}

AutoTraitsGrades.GradesList = {
    "Z+",
    "Z",
    "S+",
    "S",
    "A+",
    "A",
    "B",
    "C",
    "D"
}

AutoTraitsGrades.GradeRanks = {
    ["Z+"] = 9,
    ["Z"]  = 8,
    ["S+"] = 7,
    ["S"]  = 6,
    ["A+"] = 5,
    ["A"]  = 4,
    ["B"]  = 3,
    ["C"]  = 2,
    ["D"]  = 1
}

-- State
AutoTraitsGrades.IsRunning = false
AutoTraitsGrades.AutoTrait = false
AutoTraitsGrades.AutoGrade = false
AutoTraitsGrades.TargetUnitId = nil
AutoTraitsGrades.TargetTrait = "Transcendent"
AutoTraitsGrades.TargetGrade = "S+"
AutoTraitsGrades.GradeModeOrHigher = true
AutoTraitsGrades.RollDelay = 0.35

AutoTraitsGrades.OnTraitFinished = nil -- callback
AutoTraitsGrades.OnGradeFinished = nil -- callback

local traitThread = nil
local gradeThread = nil

-- ─── HELPER: DATA GETTERS ─────────────────────────────────────────
function AutoTraitsGrades.GetDataController()
    local ok, dc = pcall(function()
        return require(ReplicatedStorage.Framework.Features.Data.DataController)
    end)
    return ok and dc or nil
end

function AutoTraitsGrades.GetTraitRerolls()
    local dc = AutoTraitsGrades.GetDataController()
    if not dc or not dc.Inventory then return 0 end
    local count = 0
    pcall(function()
        local item = dc.Inventory["Trait Reroll"] and dc.Inventory["Trait Reroll"]()
        count = (item and item.amount) or 0
    end)
    return count
end

function AutoTraitsGrades.GetGems()
    local dc = AutoTraitsGrades.GetDataController()
    if not dc or not dc.Inventory then return 0 end
    local count = 0
    pcall(function()
        local item = dc.Inventory["Gems"] and dc.Inventory["Gems"]()
        count = (item and item.amount) or 0
    end)
    return count
end

-- ─── AMBIL SEMUA UNIT DARI INVENTORY (TANPA PERLU SLOT PLOT) ──────
function AutoTraitsGrades.GetAllInventoryUnits()
    local dc = AutoTraitsGrades.GetDataController()
    if not dc or not dc.Inventory then return {} end

    local inv = nil
    pcall(function()
        if typeof(dc.Inventory) == "function" then
            inv = dc.Inventory()
        elseif typeof(dc.Inventory) == "table" and getmetatable(dc.Inventory) and getmetatable(dc.Inventory).__call then
            inv = dc.Inventory()
        end
    end)
    if not inv then return {} end

    local EntryRegistry = nil
    pcall(function()
        EntryRegistry = require(ReplicatedStorage.Framework.Features.Entries.EntryRegistry)
    end)
    if not EntryRegistry then
        pcall(function()
            EntryRegistry = require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry)
        end)
    end

    local list = {}
    for id, item in pairs(inv) do
        if typeof(item) == "table" and item.name then
            local isUnit = false
            local rarity = "Common"
            if EntryRegistry and EntryRegistry.getEntryConfig then
                local cfg = EntryRegistry.getEntryConfig(item.name)
                if cfg and cfg.kind == "Unit" then
                    isUnit = true
                    rarity = cfg.rarity or "Common"
                end
            elseif item.attributes and (item.attributes.level or item.attributes.grade) then
                isUnit = true
            end

            if isUnit then
                local attrs = item.attributes or {}
                table.insert(list, {
                    id = id,
                    name = item.name,
                    rarity = rarity,
                    level = attrs.level or 1,
                    grade = attrs.grade or "D",
                    trait = attrs.trait or "None",
                    mutation = attrs.mutation or "None"
                })
            end
        end
    end

    -- Urutkan berdasarkan level tertinggi lalu nama
    table.sort(list, function(a, b)
        if a.level ~= b.level then
            return a.level > b.level
        end
        return a.name < b.name
    end)

    return list
end

-- ─── AMBIL DETAIL 1 UNIT BERDASARKAN ID ────────────────────────────
function AutoTraitsGrades.GetUnitById(unitId)
    if not unitId then return nil end
    local dc = AutoTraitsGrades.GetDataController()
    if not dc or not dc.Inventory then return nil end

    local unitItem = nil
    pcall(function()
        if dc.Inventory[unitId] and typeof(dc.Inventory[unitId]) == "function" then
            unitItem = dc.Inventory[unitId]()
        end
    end)
    if not unitItem then
        -- Fallback: cari dari GetAllInventoryUnits
        for _, u in ipairs(AutoTraitsGrades.GetAllInventoryUnits()) do
            if u.id == unitId then return u end
        end
        return nil
    end

    local EntryRegistry = nil
    pcall(function()
        EntryRegistry = require(ReplicatedStorage.Framework.Features.Entries.EntryRegistry)
    end)
    if not EntryRegistry then
        pcall(function()
            EntryRegistry = require(ReplicatedStorage.Framework.Features.Inventory.EntryRegistry)
        end)
    end
    local cfg = EntryRegistry and EntryRegistry.getEntryConfig and EntryRegistry.getEntryConfig(unitItem.name)
    local attrs = unitItem.attributes or {}

    return {
        id = unitId,
        name = unitItem.name,
        rarity = cfg and cfg.rarity or "Common",
        level = attrs.level or 1,
        grade = attrs.grade or "D",
        trait = attrs.trait or "None",
        mutation = attrs.mutation or "None"
    }
end

-- ─── PENGECEKAN KONDISI TARGET ────────────────────────────────────
function AutoTraitsGrades.IsTraitTargetReached(currentTrait, targetTrait)
    if not currentTrait or currentTrait == "None" or currentTrait == "" then return false end
    if not targetTrait or targetTrait == "None" or targetTrait == "" then return false end

    -- Check exact match
    if currentTrait:lower() == targetTrait:lower() then
        return true
    end

    -- Preset: "Any Mythic" (Transcendent, Monarch, Shogun)
    if targetTrait == "Any Mythic" then
        if currentTrait == "Transcendent" or currentTrait == "Monarch" or currentTrait == "Shogun" then
            return true
        end
    end

    return false
end

function AutoTraitsGrades.IsGradeTargetReached(currentGrade, targetGrade, orHigher)
    if not currentGrade or currentGrade == "" then return false end
    if not targetGrade or targetGrade == "" then return false end

    if currentGrade:upper() == targetGrade:upper() then
        return true
    end

    if orHigher then
        local curRank = AutoTraitsGrades.GradeRanks[currentGrade:upper()] or 0
        local tgtRank = AutoTraitsGrades.GradeRanks[targetGrade:upper()] or 0
        if curRank >= tgtRank and tgtRank > 0 then
            return true
        end
    end

    return false
end

-- ─── AUTO TRAIT ENGINE ────────────────────────────────────────────
function AutoTraitsGrades.StartAutoTrait(unitId, targetTrait)
    AutoTraitsGrades.StopAutoTrait()
    getRemotes()

    unitId = unitId or AutoTraitsGrades.TargetUnitId
    targetTrait = targetTrait or AutoTraitsGrades.TargetTrait or "Transcendent"
    AutoTraitsGrades.TargetUnitId = unitId
    AutoTraitsGrades.TargetTrait = targetTrait
    AutoTraitsGrades.AutoTrait = true

    traitThread = task.spawn(function()
        print(string.format("[AUTO TRAIT] Memulai auto trait untuk Unit %s (Target: %s)...", tostring(unitId), targetTrait))

        -- 1. BACA UNIT DARI INVENTORY TERLEBIH DAHULU (Pencegahan Bug Rejoin / Double Roll)
        task.wait(0.3)
        local initialUnit = AutoTraitsGrades.GetUnitById(unitId)
        if not initialUnit then
            warn("[AUTO TRAIT] Unit tidak ditemukan di inventory! Menghentikan.")
            AutoTraitsGrades.AutoTrait = false
            traitThread = nil
            if AutoTraitsGrades.OnTraitFinished then
                pcall(AutoTraitsGrades.OnTraitFinished, false, "Unit tidak ditemukan di inventory!")
            end
            return
        end

        print(string.format("[AUTO TRAIT] Unit dibaca: %s | Trait saat ini: %s", initialUnit.name, initialUnit.trait))
        if AutoTraitsGrades.IsTraitTargetReached(initialUnit.trait, targetTrait) then
            print("[AUTO TRAIT] Unit SUDAH memiliki trait target! Tidak perlu me-roll.")
            AutoTraitsGrades.AutoTrait = false
            traitThread = nil
            if AutoTraitsGrades.OnTraitFinished then
                pcall(AutoTraitsGrades.OnTraitFinished, true, string.format("Unit sudah memiliki target trait: %s!", initialUnit.trait))
            end
            return
        end

        -- 2. LOOP ROLLING TRAIT
        while AutoTraitsGrades.AutoTrait do
            -- Cek sisa bahan Trait Reroll
            local rerolls = AutoTraitsGrades.GetTraitRerolls()
            if rerolls < 1 then
                warn("[AUTO TRAIT] Kehabisan Trait Reroll!")
                AutoTraitsGrades.AutoTrait = false
                traitThread = nil
                if AutoTraitsGrades.OnTraitFinished then
                    pcall(AutoTraitsGrades.OnTraitFinished, false, "Kehabisan Trait Reroll!")
                end
                return
            end

            -- Cek ulang unit sebelum melempar remote
            local u = AutoTraitsGrades.GetUnitById(unitId)
            if not u then
                AutoTraitsGrades.AutoTrait = false
                traitThread = nil
                return
            end

            if AutoTraitsGrades.IsTraitTargetReached(u.trait, targetTrait) then
                print(string.format("[AUTO TRAIT] 🎉 TARGET TERCAPAI: %s! STOP ROLL.", u.trait))
                AutoTraitsGrades.AutoTrait = false
                traitThread = nil
                if AutoTraitsGrades.OnTraitFinished then
                    pcall(AutoTraitsGrades.OnTraitFinished, true, string.format("Selamat! Target Trait %s berhasil didapat!", u.trait))
                end
                return
            end

            -- Eksekusi Roll dengan bypass protect (argumen kedua true)
            if traitRE then
                pcall(function()
                    traitRE:FireServer(unitId, true)
                end)
            end

            task.wait(AutoTraitsGrades.RollDelay or 0.35)

            -- Verifikasi hasil roll setelah delay
            local uAfter = AutoTraitsGrades.GetUnitById(unitId)
            if uAfter and AutoTraitsGrades.IsTraitTargetReached(uAfter.trait, targetTrait) then
                print(string.format("[AUTO TRAIT] 🎉 TARGET TERCAPAI: %s! STOP ROLL.", uAfter.trait))
                AutoTraitsGrades.AutoTrait = false
                traitThread = nil
                if AutoTraitsGrades.OnTraitFinished then
                    pcall(AutoTraitsGrades.OnTraitFinished, true, string.format("Selamat! Target Trait %s berhasil didapat!", uAfter.trait))
                end
                return
            end
        end
    end)
end

function AutoTraitsGrades.StopAutoTrait()
    AutoTraitsGrades.AutoTrait = false
    if traitThread then
        local t = traitThread
        traitThread = nil
        pcall(function()
            if t ~= coroutine.running() then
                task.cancel(t)
            end
        end)
    end
end

-- ─── AUTO GRADE ENGINE ────────────────────────────────────────────
function AutoTraitsGrades.StartAutoGrade(unitId, targetGrade, orHigher)
    AutoTraitsGrades.StopAutoGrade()
    getRemotes()

    unitId = unitId or AutoTraitsGrades.TargetUnitId
    targetGrade = targetGrade or AutoTraitsGrades.TargetGrade or "S+"
    if orHigher == nil then orHigher = AutoTraitsGrades.GradeModeOrHigher end

    AutoTraitsGrades.TargetUnitId = unitId
    AutoTraitsGrades.TargetGrade = targetGrade
    AutoTraitsGrades.GradeModeOrHigher = orHigher
    AutoTraitsGrades.AutoGrade = true

    gradeThread = task.spawn(function()
        print(string.format("[AUTO GRADE] Memulai auto grade untuk Unit %s (Target: %s, OrHigher: %s)...",
            tostring(unitId), targetGrade, tostring(orHigher)))

        -- 1. BACA UNIT DARI INVENTORY TERLEBIH DAHULU (Pencegahan Bug Rejoin / Double Roll)
        task.wait(0.3)
        local initialUnit = AutoTraitsGrades.GetUnitById(unitId)
        if not initialUnit then
            warn("[AUTO GRADE] Unit tidak ditemukan di inventory! Menghentikan.")
            AutoTraitsGrades.AutoGrade = false
            gradeThread = nil
            if AutoTraitsGrades.OnGradeFinished then
                pcall(AutoTraitsGrades.OnGradeFinished, false, "Unit tidak ditemukan di inventory!")
            end
            return
        end

        print(string.format("[AUTO GRADE] Unit dibaca: %s | Grade saat ini: %s", initialUnit.name, initialUnit.grade))
        if AutoTraitsGrades.IsGradeTargetReached(initialUnit.grade, targetGrade, orHigher) then
            print("[AUTO GRADE] Unit SUDAH memiliki grade target! Tidak perlu me-roll.")
            AutoTraitsGrades.AutoGrade = false
            gradeThread = nil
            if AutoTraitsGrades.OnGradeFinished then
                pcall(AutoTraitsGrades.OnGradeFinished, true, string.format("Unit sudah memiliki target grade: %s!", initialUnit.grade))
            end
            return
        end

        -- 2. LOOP ROLLING GRADE
        while AutoTraitsGrades.AutoGrade do
            -- Cek sisa bahan Gems
            local gems = AutoTraitsGrades.GetGems()
            if gems < 1 then
                warn("[AUTO GRADE] Kehabisan Gems!")
                AutoTraitsGrades.AutoGrade = false
                gradeThread = nil
                if AutoTraitsGrades.OnGradeFinished then
                    pcall(AutoTraitsGrades.OnGradeFinished, false, "Kehabisan Gems!")
                end
                return
            end

            -- Cek ulang unit sebelum melempar remote
            local u = AutoTraitsGrades.GetUnitById(unitId)
            if not u then
                AutoTraitsGrades.AutoGrade = false
                gradeThread = nil
                return
            end

            if AutoTraitsGrades.IsGradeTargetReached(u.grade, targetGrade, orHigher) then
                print(string.format("[AUTO GRADE] 🎉 TARGET TERCAPAI: %s! STOP ROLL.", u.grade))
                AutoTraitsGrades.AutoGrade = false
                gradeThread = nil
                if AutoTraitsGrades.OnGradeFinished then
                    pcall(AutoTraitsGrades.OnGradeFinished, true, string.format("Selamat! Target Grade %s berhasil didapat!", u.grade))
                end
                return
            end

            -- Eksekusi Roll Grade dengan bypass protect (argumen kedua true)
            if gradeRE then
                pcall(function()
                    gradeRE:FireServer(unitId, true)
                end)
            end

            task.wait(AutoTraitsGrades.RollDelay or 0.35)

            -- Verifikasi hasil roll setelah delay
            local uAfter = AutoTraitsGrades.GetUnitById(unitId)
            if uAfter and AutoTraitsGrades.IsGradeTargetReached(uAfter.grade, targetGrade, orHigher) then
                print(string.format("[AUTO GRADE] 🎉 TARGET TERCAPAI: %s! STOP ROLL.", uAfter.grade))
                AutoTraitsGrades.AutoGrade = false
                gradeThread = nil
                if AutoTraitsGrades.OnGradeFinished then
                    pcall(AutoTraitsGrades.OnGradeFinished, true, string.format("Selamat! Target Grade %s berhasil didapat!", uAfter.grade))
                end
                return
            end
        end
    end)
end

function AutoTraitsGrades.StopAutoGrade()
    AutoTraitsGrades.AutoGrade = false
    if gradeThread then
        local t = gradeThread
        gradeThread = nil
        pcall(function()
            if t ~= coroutine.running() then
                task.cancel(t)
            end
        end)
    end
end

function AutoTraitsGrades.StopAll()
    AutoTraitsGrades.StopAutoTrait()
    AutoTraitsGrades.StopAutoGrade()
end

_G.AnimeDiceAutoTraitsGrades = AutoTraitsGrades
return AutoTraitsGrades
