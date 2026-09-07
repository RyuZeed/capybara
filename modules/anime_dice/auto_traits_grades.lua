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
AutoTraitsGrades.TargetSlot = 1
AutoTraitsGrades.TargetTrait = "Transcendent"
AutoTraitsGrades.TargetGrade = "S+"
AutoTraitsGrades.GradeModeOrHigher = true -- true: stop jika grade >= target (misal target S+, maka S+, Z, Z+ juga stop)
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

-- ─── HELPER: BACA UNIT DI SLOT (ANTI-BUG RELOG/REJOIN) ─────────────
function AutoTraitsGrades.GetSlotUnit(slotIndex)
    local dc = AutoTraitsGrades.GetDataController()
    if not dc or not dc.Slots or not dc.Inventory then return nil end

    local slotData = dc.Slots[tostring(slotIndex)] and dc.Slots[tostring(slotIndex)]()
    if not slotData or not slotData.unitId then return nil end

    local unitItem = dc.Inventory[slotData.unitId] and dc.Inventory[slotData.unitId]()
    if not unitItem then return nil end

    local attrs = unitItem.attributes or {}
    return {
        unitId = slotData.unitId,
        unitName = unitItem.name,
        slot = slotIndex,
        trait = attrs.trait or "None",
        grade = attrs.grade or "D",
        level = attrs.level or 1
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

    -- Preset: "Damage Max" (Damage III)
    if targetTrait == "Damage Max" and currentTrait == "Damage III" then return true end
    -- Preset: "Money Max" (Money III)
    if targetTrait == "Money Max" and currentTrait == "Money III" then return true end

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
function AutoTraitsGrades.StartAutoTrait(targetSlot, targetTrait)
    AutoTraitsGrades.StopAutoTrait()
    getRemotes()

    targetSlot = tonumber(targetSlot) or AutoTraitsGrades.TargetSlot or 1
    targetTrait = targetTrait or AutoTraitsGrades.TargetTrait or "Transcendent"
    AutoTraitsGrades.TargetSlot = targetSlot
    AutoTraitsGrades.TargetTrait = targetTrait
    AutoTraitsGrades.AutoTrait = true

    traitThread = task.spawn(function()
        print(string.format("[AUTO TRAIT] Memulai auto trait untuk Slot %d (Target: %s)...", targetSlot, targetTrait))

        -- 1. BACA UNIT TERLEBIH DAHULU (Pencegahan Bug Rejoin / Double Roll)
        task.wait(0.3)
        local initialUnit = AutoTraitsGrades.GetSlotUnit(targetSlot)
        if not initialUnit then
            warn("[AUTO TRAIT] Tidak ada unit di Slot " .. targetSlot .. "! Menghentikan.")
            AutoTraitsGrades.StopAutoTrait()
            if AutoTraitsGrades.OnTraitFinished then
                pcall(AutoTraitsGrades.OnTraitFinished, false, "Tidak ada unit di slot ini!")
            end
            return
        end

        print(string.format("[AUTO TRAIT] Unit dibaca: %s | Trait saat ini: %s", initialUnit.unitName, initialUnit.trait))
        if AutoTraitsGrades.IsTraitTargetReached(initialUnit.trait, targetTrait) then
            print("[AUTO TRAIT] Unit SUDAH memiliki trait target! Tidak perlu me-roll.")
            AutoTraitsGrades.StopAutoTrait()
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
                AutoTraitsGrades.StopAutoTrait()
                if AutoTraitsGrades.OnTraitFinished then
                    pcall(AutoTraitsGrades.OnTraitFinished, false, "Kehabisan Trait Reroll!")
                end
                break
            end

            -- Cek ulang unit sebelum melempar remote
            local u = AutoTraitsGrades.GetSlotUnit(targetSlot)
            if not u then
                AutoTraitsGrades.StopAutoTrait()
                break
            end

            if AutoTraitsGrades.IsTraitTargetReached(u.trait, targetTrait) then
                print(string.format("[AUTO TRAIT] 🎉 TARGET TERCAPAI: %s! STOP ROLL.", u.trait))
                AutoTraitsGrades.StopAutoTrait()
                if AutoTraitsGrades.OnTraitFinished then
                    pcall(AutoTraitsGrades.OnTraitFinished, true, string.format("Selamat! Target Trait %s berhasil didapat!", u.trait))
                end
                break
            end

            -- Eksekusi Roll dengan bypass protect (argumen kedua true)
            if traitRE then
                pcall(function()
                    traitRE:FireServer(u.unitId, true)
                end)
            end

            task.wait(AutoTraitsGrades.RollDelay or 0.35)

            -- Verifikasi hasil roll setelah delay
            local uAfter = AutoTraitsGrades.GetSlotUnit(targetSlot)
            if uAfter and AutoTraitsGrades.IsTraitTargetReached(uAfter.trait, targetTrait) then
                print(string.format("[AUTO TRAIT] 🎉 TARGET TERCAPAI: %s! STOP ROLL.", uAfter.trait))
                AutoTraitsGrades.StopAutoTrait()
                if AutoTraitsGrades.OnTraitFinished then
                    pcall(AutoTraitsGrades.OnTraitFinished, true, string.format("Selamat! Target Trait %s berhasil didapat!", uAfter.trait))
                end
                break
            end
        end
    end)
end

function AutoTraitsGrades.StopAutoTrait()
    AutoTraitsGrades.AutoTrait = false
    if traitThread then
        task.cancel(traitThread)
        traitThread = nil
    end
end

-- ─── AUTO GRADE ENGINE ────────────────────────────────────────────
function AutoTraitsGrades.StartAutoGrade(targetSlot, targetGrade, orHigher)
    AutoTraitsGrades.StopAutoGrade()
    getRemotes()

    targetSlot = tonumber(targetSlot) or AutoTraitsGrades.TargetSlot or 1
    targetGrade = targetGrade or AutoTraitsGrades.TargetGrade or "S+"
    if orHigher == nil then orHigher = AutoTraitsGrades.GradeModeOrHigher end

    AutoTraitsGrades.TargetSlot = targetSlot
    AutoTraitsGrades.TargetGrade = targetGrade
    AutoTraitsGrades.GradeModeOrHigher = orHigher
    AutoTraitsGrades.AutoGrade = true

    gradeThread = task.spawn(function()
        print(string.format("[AUTO GRADE] Memulai auto grade untuk Slot %d (Target: %s, OrHigher: %s)...",
            targetSlot, targetGrade, tostring(orHigher)))

        -- 1. BACA UNIT TERLEBIH DAHULU (Pencegahan Bug Rejoin / Double Roll)
        task.wait(0.3)
        local initialUnit = AutoTraitsGrades.GetSlotUnit(targetSlot)
        if not initialUnit then
            warn("[AUTO GRADE] Tidak ada unit di Slot " .. targetSlot .. "! Menghentikan.")
            AutoTraitsGrades.StopAutoGrade()
            if AutoTraitsGrades.OnGradeFinished then
                pcall(AutoTraitsGrades.OnGradeFinished, false, "Tidak ada unit di slot ini!")
            end
            return
        end

        print(string.format("[AUTO GRADE] Unit dibaca: %s | Grade saat ini: %s", initialUnit.unitName, initialUnit.grade))
        if AutoTraitsGrades.IsGradeTargetReached(initialUnit.grade, targetGrade, orHigher) then
            print("[AUTO GRADE] Unit SUDAH memiliki grade target! Tidak perlu me-roll.")
            AutoTraitsGrades.StopAutoGrade()
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
                AutoTraitsGrades.StopAutoGrade()
                if AutoTraitsGrades.OnGradeFinished then
                    pcall(AutoTraitsGrades.OnGradeFinished, false, "Kehabisan Gems!")
                end
                break
            end

            -- Cek ulang unit sebelum melempar remote
            local u = AutoTraitsGrades.GetSlotUnit(targetSlot)
            if not u then
                AutoTraitsGrades.StopAutoGrade()
                break
            end

            if AutoTraitsGrades.IsGradeTargetReached(u.grade, targetGrade, orHigher) then
                print(string.format("[AUTO GRADE] 🎉 TARGET TERCAPAI: %s! STOP ROLL.", u.grade))
                AutoTraitsGrades.StopAutoGrade()
                if AutoTraitsGrades.OnGradeFinished then
                    pcall(AutoTraitsGrades.OnGradeFinished, true, string.format("Selamat! Target Grade %s berhasil didapat!", u.grade))
                end
                break
            end

            -- Eksekusi Roll Grade dengan bypass protect (argumen kedua true)
            if gradeRE then
                pcall(function()
                    gradeRE:FireServer(u.unitId, true)
                end)
            end

            task.wait(AutoTraitsGrades.RollDelay or 0.35)

            -- Verifikasi hasil roll setelah delay
            local uAfter = AutoTraitsGrades.GetSlotUnit(targetSlot)
            if uAfter and AutoTraitsGrades.IsGradeTargetReached(uAfter.grade, targetGrade, orHigher) then
                print(string.format("[AUTO GRADE] 🎉 TARGET TERCAPAI: %s! STOP ROLL.", uAfter.grade))
                AutoTraitsGrades.StopAutoGrade()
                if AutoTraitsGrades.OnGradeFinished then
                    pcall(AutoTraitsGrades.OnGradeFinished, true, string.format("Selamat! Target Grade %s berhasil didapat!", uAfter.grade))
                end
                break
            end
        end
    end)
end

function AutoTraitsGrades.StopAutoGrade()
    AutoTraitsGrades.AutoGrade = false
    if gradeThread then
        task.cancel(gradeThread)
        gradeThread = nil
    end
end

function AutoTraitsGrades.StopAll()
    AutoTraitsGrades.StopAutoTrait()
    AutoTraitsGrades.StopAutoGrade()
end

_G.AnimeDiceAutoTraitsGrades = AutoTraitsGrades
return AutoTraitsGrades
