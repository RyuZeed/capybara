--[[
	===============================================================
	⚡ RITOD HUB - SMART AUTO CLAIM ENGINE (DUAL-ENGINE & EXACT DATA)
	Game: Roll Anime For Fight / Anime Auto Roll
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- 📜 DATA-DRIVEN QUEST ENGINE (HANYA KLAIM SAAT STATUS READY):
	  • Membaca data real-time dari BattlepassQuest.GetQuestData.
	  • Verifikasi ketat: Hanya klaim jika (Completed == true dan Claimed ~= true).
	  • Mengirim single-target remote yang terarah tanpa spam berulang.
	- 🛑 ZERO SPAM & STRICT CACHE:
	  • Item yang sudah berstatus Claimed dicatat permanen dalam session history.
	  • Tombol yang memiliki teks 'Claimed', 'Locked', atau Timer dilewati secara otomatis.
	- 🖱️ Multi-Vector Hardware/Event Click Dispatcher (firesignal + getconnections + VIM + VirtualUser + Activate).
	- 🛡️ Template & State Filter: Memvalidasi teks dan visual tombol sebelum dieksekusi.
	===============================================================
]]

local AutoClaim = {}
_G.AutoClaim = AutoClaim
_G.AutoClaimModule = AutoClaim

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local VirtualUser         = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

AutoClaim.Config = {
    DailyQuest    = true, -- Auto Claim Daily Quests
    WeeklyQuest   = true, -- Auto Claim Weekly Quests
    Battlepass    = true, -- Auto Claim Battlepass Tier Rewards
    FreeRewards   = true, -- Auto Claim Playtime Gifts & Free VIP/Group
    VIPAndGroup   = true,
    CheckInterval = 10,   -- Interval pengecekan berkala (detik)
}

local isRunning        = false
local loopThread       = nil
local claimedHistory   = {} -- [key] = true (Tercatat jika sudah CLAIMED agar tidak pernah di-spam)
local clickDebounce    = {} -- [key] = timestamp (Cooldown klik per item)
local lastQuestQuery   = 0

-- =================================================================
-- 🛠️ MULTI-VECTOR HARDWARE & EVENT CLICK DISPATCHER
-- =================================================================
local function clickButton(btn)
    if not btn or not btn:IsA("GuiObject") then return end

    -- 1. firesignal (Roblox Executor Signal Dispatch)
    if typeof(firesignal) == "function" then
        if btn:IsA("GuiButton") then
            if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
            if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
            if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
            if btn.MouseButton1Up then pcall(function() firesignal(btn.MouseButton1Up) end) end
            if btn.TouchTap then pcall(function() firesignal(btn.TouchTap) end) end
        end
    end

    -- 2. getconnections (Direct Lua Event Dispatch)
    if typeof(getconnections) == "function" then
        for _, evName in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "TouchTap"}) do
            pcall(function()
                if btn[evName] then
                    local conns = getconnections(btn[evName])
                    if conns then
                        for _, conn in ipairs(conns) do
                            if conn.Function then
                                conn.Function()
                            elseif conn.Fire then
                                conn:Fire()
                            end
                        end
                    end
                end
            end)
        end
    end

    -- 3. VirtualInputManager (Simulasi Hardware Mouse & Touch di Center Titik Tombol)
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        if size.X > 0 and size.Y > 0 and VirtualInputManager then
            local cx = math.floor(pos.X + size.X / 2)
            local cy = math.floor(pos.Y + size.Y / 2)
            pcall(function()
                VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.02)
                VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
            end)
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
        end
    end)

    -- 4. VirtualUser Fallback
    pcall(function()
        if VirtualUser then
            VirtualUser:CaptureController()
            local pos = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            if size.X > 0 and size.Y > 0 then
                VirtualUser:ClickButton1(Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2))
            end
        end
    end)

    -- 5. GuiObject:Activate() method fallback
    pcall(function()
        if typeof(btn.Activate) == "function" then
            btn:Activate()
        end
    end)
end

-- =================================================================
-- 🔍 HELPER: TEMPLATE & CLAIMABLE DETECTOR
-- =================================================================
local function isTemplateObject(obj)
    if not obj then return true end
    local cur = obj
    while cur and cur ~= game do
        local cName = tostring(cur.Name):lower()
        if cName == "template" or cName == "templates" or cName == "configuration" then
            return true
        end
        if cur:IsA("GuiObject") and not cur.Visible then
            return true
        end
        cur = cur.Parent
    end
    return false
end

local function isClaimableButton(btn)
    if not btn or not btn:IsA("GuiObject") then return false end
    if not btn.Visible or isTemplateObject(btn) then return false end

    local text = ""
    if btn:IsA("TextButton") or btn:IsA("TextLabel") then
        text = tostring(btn.Text):lower()
    end
    for _, desc in ipairs(btn:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Visible and #desc.Text > 0 then
            text = text .. " " .. desc.Text:lower()
        end
    end
    
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    
    -- JANGAN KLIK jika teks kosong!
    if #text == 0 then return false end
    
    -- Filter out explicitly unclaimable states
    if text:find("claimed") or text:find("terklaim") or text:find("completed") or text:find("selesai") or text:find("sudah") then
        return false
    end
    if text:find("lock") or text:find("kunci") or text:find("tier") or text:find("level") then
        return false
    end
    if text:find(":") then -- Timer like 01:23:45
        return false
    end

    -- Match positive claim words ONLY
    if text:find("claim") or text:find("klaim") or text:find("collect") or text:find("ambil") then
        return true
    end

    return false
end

-- =================================================================
-- 1. 📜 AUTO CLAIM DAILY & WEEKLY QUESTS (DATA-DRIVEN & STRICT)
-- =================================================================
function AutoClaim.ClaimQuests()
    pcall(function()
        local now = tick()
        if now - lastQuestQuery < 6 then return end
        lastQuestQuery = now

        local bpQuestFolder = ReplicatedStorage:FindFirstChild("Modules") 
            and ReplicatedStorage.Modules:FindFirstChild("Battlepass") 
            and ReplicatedStorage.Modules.Battlepass:FindFirstChild("BattlepassQuest")
        
        if not bpQuestFolder then
            for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
                if desc.Name == "BattlepassQuest" and desc:IsA("Folder") then
                    bpQuestFolder = desc
                    break
                end
            end
        end

        if bpQuestFolder then
            local getQuestFunc = bpQuestFolder:FindFirstChild("GetQuestData")
            local claimRemote = bpQuestFolder:FindFirstChild("ClaimQuest")

            if claimRemote and getQuestFunc and getQuestFunc:IsA("RemoteFunction") then
                local s, questData = pcall(function() return getQuestFunc:InvokeServer() end)
                if s and type(questData) == "table" then
                    local categories = {}
                    if AutoClaim.Config.DailyQuest and type(questData.Daily) == "table" then
                        categories["Daily"] = questData.Daily
                    end
                    if AutoClaim.Config.WeeklyQuest and type(questData.Weekly) == "table" then
                        categories["Weekly"] = questData.Weekly
                    end

                    for category, list in pairs(categories) do
                        for idx, qInfo in ipairs(list) do
                            if type(qInfo) == "table" then
                                local isDone = (qInfo.Completed == true) or (qInfo.Progress and qInfo.Requirement and qInfo.Progress >= qInfo.Requirement)
                                local isNotClaimed = (qInfo.Claimed ~= true)
                                local questIdentifier = qInfo.ID or qInfo.UniqueName or idx
                                local cacheKey = category .. "_" .. tostring(questIdentifier)

                                if isDone and isNotClaimed and not claimedHistory[cacheKey] then
                                    local curTime = tick()
                                    if not clickDebounce[cacheKey] or (curTime - clickDebounce[cacheKey] > 8) then
                                        clickDebounce[cacheKey] = curTime
                                        
                                        pcall(function()
                                            if claimRemote:IsA("RemoteEvent") then
                                                claimRemote:FireServer(category, questIdentifier)
                                            elseif claimRemote:IsA("RemoteFunction") then
                                                claimRemote:InvokeServer(category, questIdentifier)
                                            end
                                        end)
                                        
                                        claimedHistory[cacheKey] = true
                                        task.wait(0.2)
                                    end
                                elseif qInfo.Claimed == true then
                                    claimedHistory[cacheKey] = true
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Fallback: Scan tombol quest langsung di UI
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local mainUI = pGui and pGui:FindFirstChild("MainUI")
        local bpFrame = mainUI and mainUI:FindFirstChild("Frames") and mainUI.Frames:FindFirstChild("Battlepass")
        if bpFrame then
            for _, desc in ipairs(bpFrame:GetDescendants()) do
                if desc:IsA("GuiButton") and isClaimableButton(desc) then
                    local btnKey = "UI_Q_" .. desc:GetFullName()
                    if not claimedHistory[btnKey] and (not clickDebounce[btnKey] or (now - clickDebounce[btnKey] > 10)) then
                        clickDebounce[btnKey] = now
                        clickButton(desc)
                        claimedHistory[btnKey] = true
                        task.wait(0.2)
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 🔍 HELPER: BATTLEPASS PREMIUM & CARD CLAIM DETECTOR
-- =================================================================
local function playerHasBattlepass(bpFrame)
    if not bpFrame then return false end
    
    -- 1. Cek tombol Purchase/Buy pass (Jika terlihat aktif, berarti belum beli Premium)
    for _, desc in ipairs(bpFrame:GetDescendants()) do
        if desc:IsA("GuiObject") and desc.Visible then
            local n = desc.Name:lower()
            if n:find("purchase") or n:find("buy") or n:find("passbtn") then
                if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                    local t = desc.Text:lower()
                    if t:find("purchase") or t:find("buy") or t:find("749") or t:find("robux") then
                        return false
                    end
                end
                return false
            end
        end
    end
    
    -- 2. Cek atribut player jika ada
    if LocalPlayer:GetAttribute("Battlepass") == true or LocalPlayer:GetAttribute("PremiumPass") == true or LocalPlayer:GetAttribute("HasBattlepass") == true then
        return true
    end
    
    return false
end

local function isBattlepassCardClaimable(card, hasPremium)
    if not card or not card:IsA("GuiObject") or not card.Visible then return false end
    if isTemplateObject(card) then return false end
    if card.AbsoluteSize.X < 24 or card.AbsoluteSize.Y < 24 then return false end

    -- Cek apakah card berada di track/row Premium
    local isPremiumTrack = false
    local cur = card
    while cur and cur.Parent and cur.Name ~= "Battlepass" do
        local cn = cur.Name:lower()
        if cn:find("premium") or cn:find("vip") or cn:find("paid") then
            isPremiumTrack = true
            break
        end
        cur = cur.Parent
    end

    -- Jika berada di track Premium dan player TIDAK memiliki premium pass, SKIP!
    if isPremiumTrack and not hasPremium then
        return false
    end

    -- Cek indikator Lock (🔒 Terkunci / Belum Terbuka)
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("GuiObject") and desc.Visible then
            local dName = desc.Name:lower()
            if dName:find("lock") or dName:find("padlock") or dName:find("kunci") then
                return false
            end
            if desc:IsA("ImageLabel") and desc.Image:lower():find("lock") then
                return false
            end
            if desc:IsA("TextLabel") and desc.Text:lower():find("lock") then
                return false
            end
        end
    end

    -- Cek indikator Checkmark (✔️ Sudah Diklaim / Claimed)
    for _, desc in ipairs(card:GetDescendants()) do
        if desc:IsA("GuiObject") and desc.Visible then
            local dName = desc.Name:lower()
            if dName:find("check") or dName:find("claimed") or dName:find("tick") or dName:find("done") or dName:find("centang") then
                return false
            end
            if desc:IsA("ImageLabel") and (desc.Image:lower():find("check") or desc.Image:lower():find("tick") or desc.Image:lower():find("claimed")) then
                return false
            end
        end
    end

    return true
end

-- =================================================================
-- 2. 🏆 AUTO CLAIM BATTLEPASS TIER REWARDS (SMART FREE & PREMIUM)
-- =================================================================
function AutoClaim.ClaimBattlepass()
    if not AutoClaim.Config.Battlepass then return end
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local mainUI = pGui and (pGui:FindFirstChild("MainUI") or pGui:FindFirstChild("Main") or pGui:FindFirstChild("GameUI") or pGui:FindFirstChild("ScreenGui"))
        local bpFrame = nil
        
        if mainUI then
            bpFrame = (mainUI:FindFirstChild("Frames") and mainUI.Frames:FindFirstChild("Battlepass")) or mainUI:FindFirstChild("Battlepass", true)
        end
        if not bpFrame and pGui then
            bpFrame = pGui:FindFirstChild("Battlepass", true)
        end

        local hasPremium = playerHasBattlepass(bpFrame)

        -- 1. Coba Server Remote Claim (jika tersedia)
        local bpFolder = ReplicatedStorage:FindFirstChild("Modules") 
            and ReplicatedStorage.Modules:FindFirstChild("Battlepass")
        if not bpFolder then
            for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
                if desc.Name == "Battlepass" and (desc:IsA("Folder") or desc:IsA("ModuleScript")) then
                    bpFolder = desc
                    break
                end
            end
        end
        if bpFolder then
            local claimRemote = bpFolder:FindFirstChild("ClaimReward") or bpFolder:FindFirstChild("ClaimTier") or bpFolder:FindFirstChild("ClaimBattlepass")
            if claimRemote then
                pcall(function()
                    for tier = 1, 100 do
                        if claimRemote:IsA("RemoteEvent") then
                            claimRemote:FireServer(tier, "Free")
                            if hasPremium then claimRemote:FireServer(tier, "Premium") end
                        elseif claimRemote:IsA("RemoteFunction") then
                            claimRemote:InvokeServer(tier, "Free")
                            if hasPremium then claimRemote:InvokeServer(tier, "Premium") end
                        end
                    end
                end)
            end
        end

        -- 2. Scan Langsung Kartu Battlepass di UI
        if bpFrame then
            local now = tick()
            
            -- Pastikan Tab Rewards aktif
            for _, tabBtn in ipairs(bpFrame:GetDescendants()) do
                if tabBtn:IsA("TextButton") and tabBtn.Text:upper():find("REWARD") then
                    pcall(function() clickButton(tabBtn) end)
                    break
                end
            end

            -- Scan seluruh reward card (Free & Unlocked Premium)
            for _, desc in ipairs(bpFrame:GetDescendants()) do
                if desc:IsA("GuiObject") and desc.Visible and desc.AbsoluteSize.X > 28 and desc.AbsoluteSize.Y > 28 then
                    if isBattlepassCardClaimable(desc, hasPremium) then
                        local cardKey = "BP_CARD_" .. desc:GetFullName()
                        if not claimedHistory[cardKey] and (not clickDebounce[cardKey] or (now - clickDebounce[cardKey] > 8)) then
                            clickDebounce[cardKey] = now
                            
                            local targetBtn = (desc:IsA("GuiButton") and desc)
                                or desc:FindFirstChildOfClass("GuiButton")
                                or desc:FindFirstChild("Button", true)
                                or desc
                            
                            clickButton(targetBtn)
                            task.wait(0.15)
                        end
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 3. 🎁 AUTO CLAIM FREE REWARDS, VIP & GROUP (STRICT COOLDOWN)
-- =================================================================
function AutoClaim.ClaimFreeRewards()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local mainUI = pGui and pGui:FindFirstChild("MainUI")
        local frames = mainUI and mainUI:FindFirstChild("Frames")
        local now = tick()

        if frames then
            for _, fName in ipairs({"VIPRewards", "GroupRewards", "FreeRewards", "PlaytimeRewards", "DailyRewards"}) do
                local frame = frames:FindFirstChild(fName)
                if frame then
                    for _, desc in ipairs(frame:GetDescendants()) do
                        if desc:IsA("GuiButton") and isClaimableButton(desc) then
                            local bKey = "FREE_" .. fName .. "_" .. desc:GetFullName()
                            if not claimedHistory[bKey] and (not clickDebounce[bKey] or (now - clickDebounce[bKey] > 30)) then
                                clickDebounce[bKey] = now
                                clickButton(desc)
                                claimedHistory[bKey] = true
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 4. 🖥️ DEEP UI BUTTON CLAIM SCANNER (FILTERED & DEBOUNCED)
-- =================================================================
function AutoClaim.ScanAndClaimUI()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pGui then return end

        local mainUI = pGui:FindFirstChild("MainUI")
        local frames = mainUI and mainUI:FindFirstChild("Frames")
        local now = tick()

        if frames then
            for _, desc in ipairs(frames:GetDescendants()) do
                if desc:IsA("GuiButton") and isClaimableButton(desc) then
                    local bKey = "DEEP_UI_" .. desc:GetFullName()
                    if not claimedHistory[bKey] and (not clickDebounce[bKey] or (now - clickDebounce[bKey] > 15)) then
                        clickDebounce[bKey] = now
                        clickButton(desc)
                        claimedHistory[bKey] = true
                        task.wait(0.2)
                    end
                end
            end
        end
    end)
end

-- =================================================================
-- 5. 🔄 ENGINE CONTROLLER (START / STOP)
-- =================================================================
function AutoClaim.Start(customConfig)
    if isRunning then return end
    isRunning = true

    if customConfig then
        for k, v in pairs(customConfig) do
            AutoClaim.Config[k] = v
        end
    end

    loopThread = task.spawn(function()
        while isRunning do
            if AutoClaim.Config.DailyQuest or AutoClaim.Config.WeeklyQuest then
                AutoClaim.ClaimQuests()
            end
            task.wait(1.5)

            if not isRunning then break end

            if AutoClaim.Config.Battlepass then
                AutoClaim.ClaimBattlepass()
            end
            task.wait(1.5)

            if not isRunning then break end

            if AutoClaim.Config.FreeRewards or AutoClaim.Config.VIPAndGroup then
                AutoClaim.ClaimFreeRewards()
            end
            task.wait(1.5)

            if not isRunning then break end

            AutoClaim.ScanAndClaimUI()

            task.wait(AutoClaim.Config.CheckInterval or 10)
        end
    end)
end

function AutoClaim.Stop()
    isRunning = false
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

function AutoClaim.IsRunning()
    return isRunning
end

return AutoClaim
