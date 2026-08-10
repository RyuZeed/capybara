--[[
	===============================================================
	⚡ RITOD HUB - MODERN CONFIG & SETTINGS UI ENGINE
	Game: Capybaras vs Plants
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎨 FEATURES (MATCHING USER SETTINGS DESIGN):
	- 📂 Multi-Profile Config Manager (Profiles.json + per-config .json files)
	- 💾 Save / Overwrite profile with custom name
	- 🔄 Load Selected Profile
	- ⚡ Set as Auto-Load & Clear Auto-Load (Auto executes on script start)
	- 🗑️ Delete Selected Profile
	- 📤 Export (Copy JSON) with one-click clipboard copy
	- 📥 Import (Paste JSON) with direct parser & applier
	- 🛡️ Rejoin on Kick (Auto re-connect on disconnect/error prompt)
	- 🔁 Auto Execute (queue_on_teleport support)
	- 📐 Pixel-perfect Dark UI matching the reference design
	===============================================================
]]

local ModernSettings = {}
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

-- =================================================================
-- 📁 PERSISTENCE ENGINE (MULTI-PROFILE)
-- =================================================================
function ModernSettings.CreateProfileManager(gameFolder, defaultConfig, getActiveConfig, applyConfigCallback, notifyFunc)
    local ProfileManager = {}
    local ROOT_DIR = "RitodHub"
    local GAME_DIR = gameFolder or "RitodHub/Capybara"
    local CONFIGS_DIR = GAME_DIR .. "/Configs"
    local PROFILES_INDEX_PATH = GAME_DIR .. "/profiles_v2.json"

    local function ensureFolders()
        pcall(function()
            if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
                if not isfolder(ROOT_DIR) then makefolder(ROOT_DIR) end
                if not isfolder(GAME_DIR) then makefolder(GAME_DIR) end
                if not isfolder(CONFIGS_DIR) then makefolder(CONFIGS_DIR) end
            end
        end)
    end

    local function deepCopy(tbl)
        if type(tbl) ~= "table" then return tbl end
        local copy = {}
        for k, v in pairs(tbl) do
            copy[deepCopy(k)] = deepCopy(v)
        end
        return copy
    end

    local State = {
        CurrentProfile = "Default",
        AutoLoad = "Default",
        Profiles = {
            ["Default"] = deepCopy(defaultConfig)
        },
        Utility = {
            RejoinOnKick = false,
            AutoExecute = false
        }
    }

    function ProfileManager.SaveIndex()
        ensureFolders()
        pcall(function()
            if typeof(writefile) == "function" then
                local dataToSave = {
                    CurrentProfile = State.CurrentProfile,
                    AutoLoad = State.AutoLoad,
                    Profiles = State.Profiles,
                    Utility = State.Utility
                }
                writefile(PROFILES_INDEX_PATH, HttpService:JSONEncode(dataToSave))

                -- Simpan juga file per-profile
                if State.CurrentProfile and State.Profiles[State.CurrentProfile] then
                    local singleFile = string.format("%s/%s.json", CONFIGS_DIR, State.CurrentProfile)
                    writefile(singleFile, HttpService:JSONEncode(State.Profiles[State.CurrentProfile]))
                end
            end
        end)
    end

    function ProfileManager.LoadIndex()
        ensureFolders()
        pcall(function()
            if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(PROFILES_INDEX_PATH) then
                local content = readfile(PROFILES_INDEX_PATH)
                if content and #content > 0 then
                    local decoded = HttpService:JSONDecode(content)
                    if typeof(decoded) == "table" then
                        if decoded.CurrentProfile then State.CurrentProfile = decoded.CurrentProfile end
                        if decoded.AutoLoad then State.AutoLoad = decoded.AutoLoad end
                        if typeof(decoded.Profiles) == "table" then
                            for pName, pData in pairs(decoded.Profiles) do
                                State.Profiles[pName] = pData
                            end
                        end
                        if typeof(decoded.Utility) == "table" then
                            State.Utility.RejoinOnKick = (decoded.Utility.RejoinOnKick == true)
                            State.Utility.AutoExecute = (decoded.Utility.AutoExecute == true)
                        end
                    end
                end
            end
        end)
        return State
    end

    function ProfileManager.GetState() return State end
    function ProfileManager.GetProfilesList()
        local list = {}
        for pName, _ in pairs(State.Profiles) do
            table.insert(list, pName)
        end
        table.sort(list)
        if #list == 0 then table.insert(list, "Default") end
        return list
    end

    function ProfileManager.SaveProfile(name, configData)
        if not name or name:gsub("%s+", "") == "" then name = "Default" end
        State.CurrentProfile = name
        State.Profiles[name] = deepCopy(configData or getActiveConfig())
        ProfileManager.SaveIndex()
        if notifyFunc then notifyFunc("Config Saved", string.format("Profile '%s' berhasil disimpan!", name), 2.5) end
        return true
    end

    function ProfileManager.LoadProfile(name)
        if not name or not State.Profiles[name] then
            if notifyFunc then notifyFunc("Config Error", string.format("Profile '%s' tidak ditemukan.", tostring(name)), 2.5) end
            return false
        end
        State.CurrentProfile = name
        local cfg = State.Profiles[name]
        if applyConfigCallback then
            applyConfigCallback(deepCopy(cfg))
        end
        ProfileManager.SaveIndex()
        if notifyFunc then notifyFunc("Config Loaded", string.format("Profile '%s' berhasil dimuat!", name), 2.5) end
        return true
    end

    function ProfileManager.SetAutoLoad(name)
        if not name or not State.Profiles[name] then name = "Default" end
        State.AutoLoad = name
        ProfileManager.SaveIndex()
        if notifyFunc then notifyFunc("Auto-Load Set", string.format("Profile '%s' diset sebagai Auto-Load!", name), 2.5) end
    end

    function ProfileManager.ClearAutoLoad()
        State.AutoLoad = "None"
        ProfileManager.SaveIndex()
        if notifyFunc then notifyFunc("Auto-Load Cleared", "Auto-Load dinonaktifkan (None).", 2.5) end
    end

    function ProfileManager.DeleteProfile(name)
        if name == "Default" then
            State.Profiles["Default"] = deepCopy(defaultConfig)
            if notifyFunc then notifyFunc("Config Reset", "Profile 'Default' direset ke bawaan.", 2.5) end
        else
            State.Profiles[name] = nil
            pcall(function()
                local singleFile = string.format("%s/%s.json", CONFIGS_DIR, name)
                if typeof(delfile) == "function" and isfile(singleFile) then delfile(singleFile) end
            end)
            if State.CurrentProfile == name then State.CurrentProfile = "Default" end
            if State.AutoLoad == name then State.AutoLoad = "None" end
            if notifyFunc then notifyFunc("Config Deleted", string.format("Profile '%s' berhasil dihapus.", name), 2.5) end
        end
        ProfileManager.SaveIndex()
    end

    function ProfileManager.ExportJSON()
        local cur = getActiveConfig()
        local json = HttpService:JSONEncode(cur)
        if setclipboard then
            setclipboard(json)
        end
        if notifyFunc then notifyFunc("Export Config", "JSON konfigurasi disalin ke Clipboard!", 2.5) end
        return json
    end

    function ProfileManager.ImportJSON(jsonString, targetProfileName)
        if not jsonString or jsonString:gsub("%s+", "") == "" then
            if notifyFunc then notifyFunc("Import Error", "Teks JSON kosong!", 2.5) end
            return false
        end
        local success, decoded = pcall(function() return HttpService:JSONDecode(jsonString) end)
        if success and typeof(decoded) == "table" then
            local pName = targetProfileName or State.CurrentProfile or "Imported"
            State.Profiles[pName] = decoded
            State.CurrentProfile = pName
            if applyConfigCallback then applyConfigCallback(decoded) end
            ProfileManager.SaveIndex()
            if notifyFunc then notifyFunc("Import Success", string.format("JSON berhasil diimpor ke profile '%s'!", pName), 2.5) end
            return true
        else
            if notifyFunc then notifyFunc("Import Error", "Format JSON tidak valid!", 2.5) end
            return false
        end
    end

    -- Muat indeks awal
    ProfileManager.LoadIndex()
    return ProfileManager
end

-- =================================================================
-- 🛡️ REJOIN ON KICK & AUTO EXECUTE HANDLER
-- =================================================================
local _rejoinEnabled = false
local _autoExecEnabled = false

local function setupRejoinOnKick(enabled, notifyFunc)
    _rejoinEnabled = enabled
    if not enabled then return end

    if not _G.RitodRejoinConn then
        _G.RitodRejoinConn = true

        local function triggerRejoin()
            if not _rejoinEnabled then return end
            print("🛡️ [Ritod Hub] Kick terdeteksi! Mencoba Rejoin server dalam 3 detik...")
            if notifyFunc then notifyFunc("Rejoin on Kick", "Terputus dari server. Rejoining...", 3) end
            task.wait(3)
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end

        pcall(function()
            local prompt = CoreGui:FindFirstChild("RobloxPromptGui")
            local overlay = prompt and prompt:FindFirstChild("promptOverlay")
            if overlay then
                overlay.ChildAdded:Connect(function(child)
                    if _rejoinEnabled and child.Name == "ErrorPrompt" then
                        triggerRejoin()
                    end
                end)
            end
        end)

        pcall(function()
            GuiService.ErrorMessageChanged:Connect(function()
                if _rejoinEnabled then
                    triggerRejoin()
                end
            end)
        end)
    end
end

local function setupAutoExecute(enabled, scriptUrl, notifyFunc)
    _autoExecEnabled = enabled
    if enabled and typeof(queue_on_teleport) == "function" and scriptUrl then
        pcall(function()
            queue_on_teleport(string.format('loadstring(game:HttpGet("%s"))()', scriptUrl))
            if notifyFunc then notifyFunc("Auto Execute", "Script auto-execute didaftarkan untuk teleport berikutnya!", 2.5) end
        end)
    end
end

-- =================================================================
-- 🎨 MODERN UI BUILDER (MATCHING USER SCREENSHOT)
-- =================================================================
function ModernSettings.BuildUI(parentPage, manager, scriptUrl, notifyFunc)
    local state = manager.GetState()

    -- Wrapper container untuk 2 Kolom Card
    local settingsContainer = Instance.new("Frame")
    settingsContainer.Name = "ModernSettingsContainer"
    settingsContainer.Size = UDim2.new(1, 0, 0, 0)
    settingsContainer.AutomaticSize = Enum.AutomaticSize.Y
    settingsContainer.BackgroundTransparency = 1
    settingsContainer.BorderSizePixel = 0
    settingsContainer.ZIndex = 14
    settingsContainer.Parent = parentPage

    local mainLayout = Instance.new("UIListLayout")
    mainLayout.FillDirection = Enum.FillDirection.Horizontal
    mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    mainLayout.Padding = UDim.new(0, 10)
    mainLayout.Parent = settingsContainer

    -- 2 Kolom Kiri & Kanan
    local leftCol = Instance.new("Frame")
    leftCol.Name = "LeftColumn"
    leftCol.Size = UDim2.new(0.485, 0, 0, 0)
    leftCol.AutomaticSize = Enum.AutomaticSize.Y
    leftCol.BackgroundTransparency = 1
    leftCol.Parent = settingsContainer

    local leftLayout = Instance.new("UIListLayout")
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Padding = UDim.new(0, 10)
    leftLayout.Parent = leftCol

    local rightCol = Instance.new("Frame")
    rightCol.Name = "RightColumn"
    rightCol.Size = UDim2.new(0.485, 0, 0, 0)
    rightCol.AutomaticSize = Enum.AutomaticSize.Y
    rightCol.BackgroundTransparency = 1
    rightCol.Parent = settingsContainer

    local rightLayout = Instance.new("UIListLayout")
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Padding = UDim.new(0, 10)
    rightLayout.Parent = rightCol

    -- Helper pembuat Card Container
    local function createCard(title, parent)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Color3.fromRGB(20, 16, 26)
        card.BorderSizePixel = 0
        card.ZIndex = 15
        card.Parent = parent

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 10)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Thickness = 1
        cStroke.Color = Color3.fromRGB(45, 36, 56)
        cStroke.Parent = card

        -- Card Header (Clickable Accordion)
        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 36)
        header.BackgroundTransparency = 1
        header.Text = ""
        header.AutoButtonColor = false
        header.ZIndex = 16
        header.Parent = card

        local hTitle = Instance.new("TextLabel")
        hTitle.Position = UDim2.new(0, 12, 0, 0)
        hTitle.Size = UDim2.new(1, -40, 1, 0)
        hTitle.BackgroundTransparency = 1
        hTitle.Text = title
        hTitle.TextColor3 = Color3.fromRGB(240, 235, 245)
        hTitle.TextSize = 13
        hTitle.Font = Enum.Font.GothamBold
        hTitle.TextXAlignment = Enum.TextXAlignment.Left
        hTitle.ZIndex = 16
        hTitle.Parent = header

        local hCaret = Instance.new("TextLabel")
        hCaret.AnchorPoint = Vector2.new(1, 0.5)
        hCaret.Position = UDim2.new(1, -12, 0.5, 0)
        hCaret.Size = UDim2.new(0, 20, 0, 20)
        hCaret.BackgroundTransparency = 1
        hCaret.Text = "⌃"
        hCaret.TextColor3 = Color3.fromRGB(180, 175, 195)
        hCaret.TextSize = 14
        hCaret.Font = Enum.Font.GothamBold
        hCaret.ZIndex = 16
        hCaret.Parent = header

        -- Body Container
        local body = Instance.new("Frame")
        body.Position = UDim2.new(0, 0, 0, 36)
        body.Size = UDim2.new(1, 0, 0, 0)
        body.AutomaticSize = Enum.AutomaticSize.Y
        body.BackgroundTransparency = 1
        body.ZIndex = 16
        body.Parent = card

        local bPad = Instance.new("UIPadding")
        bPad.PaddingLeft = UDim.new(0, 10)
        bPad.PaddingRight = UDim.new(0, 10)
        bPad.PaddingBottom = UDim.new(0, 10)
        bPad.PaddingTop = UDim.new(0, 2)
        bPad.Parent = body

        local bLayout = Instance.new("UIListLayout")
        bLayout.SortOrder = Enum.SortOrder.LayoutOrder
        bLayout.Padding = UDim.new(0, 6)
        bLayout.Parent = body

        local isExpanded = true
        header.MouseButton1Click:Connect(function()
            isExpanded = not isExpanded
            body.Visible = isExpanded
            hCaret.Text = isExpanded and "⌃" or "⌄"
        end)

        return body
    end

    -- Helper Action Button
    local function createActionButton(parent, text, isPrimary, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = isPrimary and Color3.fromRGB(222, 226, 235) or Color3.fromRGB(28, 22, 36)
        btn.AutoButtonColor = false
        btn.Text = ""
        btn.ZIndex = 17
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 7)
        corner.Parent = btn

        if not isPrimary then
            local stroke = Instance.new("UIStroke")
            stroke.Thickness = 1
            stroke.Color = Color3.fromRGB(48, 38, 60)
            stroke.Parent = btn
        end

        local lbl = Instance.new("TextLabel")
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.Size = UDim2.new(1, -30, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = isPrimary and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(235, 230, 245)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.ZIndex = 18
        lbl.Parent = btn

        local arrow = Instance.new("TextLabel")
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -10, 0.5, 0)
        arrow.Size = UDim2.new(0, 16, 0, 16)
        arrow.BackgroundTransparency = 1
        arrow.Text = "›"
        arrow.TextColor3 = isPrimary and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(160, 150, 175)
        arrow.TextSize = 16
        arrow.Font = Enum.Font.GothamBold
        arrow.ZIndex = 18
        arrow.Parent = btn

        btn.MouseEnter:Connect(function()
            if isPrimary then
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(240, 242, 250)}):Play()
            else
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(38, 30, 48)}):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if isPrimary then
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(222, 226, 235)}):Play()
            else
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(28, 22, 36)}):Play()
            end
        end)

        btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
        return btn
    end

    -- =============================================================
    -- 📑 1. CARD "CONFIG" (KOLOM KIRI)
    -- =============================================================
    local configBody = createCard("Config", leftCol)

    -- A. Config Name Label & Input
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = "Config Name"
    nameLbl.TextColor3 = Color3.fromRGB(170, 160, 185)
    nameLbl.TextSize = 11
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 17
    nameLbl.Parent = configBody

    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, 0, 0, 32)
    nameBox.BackgroundColor3 = Color3.fromRGB(14, 11, 18)
    nameBox.Text = state.CurrentProfile or ""
    nameBox.PlaceholderText = "my config"
    nameBox.PlaceholderColor3 = Color3.fromRGB(90, 85, 105)
    nameBox.TextColor3 = Color3.fromRGB(235, 230, 245)
    nameBox.TextSize = 12
    nameBox.Font = Enum.Font.GothamMedium
    nameBox.TextXAlignment = Enum.TextXAlignment.Left
    nameBox.ClearTextOnFocus = false
    nameBox.ZIndex = 17
    nameBox.Parent = configBody

    local nbCorner = Instance.new("UICorner")
    nbCorner.CornerRadius = UDim.new(0, 6)
    nbCorner.Parent = nameBox

    local nbStroke = Instance.new("UIStroke")
    nbStroke.Thickness = 1
    nbStroke.Color = Color3.fromRGB(45, 36, 56)
    nbStroke.Parent = nameBox

    local nbPad = Instance.new("UIPadding")
    nbPad.PaddingLeft = UDim.new(0, 10)
    nbPad.PaddingRight = UDim.new(0, 10)
    nbPad.Parent = nameBox

    -- B. Saved Configs Dropdown
    local savedLbl = Instance.new("TextLabel")
    savedLbl.Size = UDim2.new(1, 0, 0, 14)
    savedLbl.BackgroundTransparency = 1
    savedLbl.Text = "Saved Configs"
    savedLbl.TextColor3 = Color3.fromRGB(170, 160, 185)
    savedLbl.TextSize = 11
    savedLbl.Font = Enum.Font.GothamMedium
    savedLbl.TextXAlignment = Enum.TextXAlignment.Left
    savedLbl.ZIndex = 17
    savedLbl.Parent = configBody

    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(1, 0, 0, 32)
    dropBtn.BackgroundColor3 = Color3.fromRGB(14, 11, 18)
    dropBtn.AutoButtonColor = false
    dropBtn.Text = ""
    dropBtn.ZIndex = 17
    dropBtn.Parent = configBody

    local dbCorner = Instance.new("UICorner")
    dbCorner.CornerRadius = UDim.new(0, 6)
    dbCorner.Parent = dropBtn

    local dbStroke = Instance.new("UIStroke")
    dbStroke.Thickness = 1
    dbStroke.Color = Color3.fromRGB(45, 36, 56)
    dbStroke.Parent = dropBtn

    local dbSelectedTxt = Instance.new("TextLabel")
    dbSelectedTxt.Position = UDim2.new(0, 10, 0, 0)
    dbSelectedTxt.Size = UDim2.new(1, -35, 1, 0)
    dbSelectedTxt.BackgroundTransparency = 1
    dbSelectedTxt.Text = state.CurrentProfile or "Default"
    dbSelectedTxt.TextColor3 = Color3.fromRGB(235, 230, 245)
    dbSelectedTxt.TextSize = 12
    dbSelectedTxt.Font = Enum.Font.GothamMedium
    dbSelectedTxt.TextXAlignment = Enum.TextXAlignment.Left
    dbSelectedTxt.ZIndex = 18
    dbSelectedTxt.Parent = dropBtn

    local dbCaret = Instance.new("TextLabel")
    dbCaret.AnchorPoint = Vector2.new(1, 0.5)
    dbCaret.Position = UDim2.new(1, -10, 0.5, 0)
    dbCaret.Size = UDim2.new(0, 16, 0, 16)
    dbCaret.BackgroundTransparency = 1
    dbCaret.Text = "⌄"
    dbCaret.TextColor3 = Color3.fromRGB(170, 160, 185)
    dbCaret.TextSize = 14
    dbCaret.Font = Enum.Font.GothamBold
    dbCaret.ZIndex = 18
    dbCaret.Parent = dropBtn

    local dropListFrame = Instance.new("Frame")
    dropListFrame.Size = UDim2.new(1, 0, 0, 0)
    dropListFrame.BackgroundColor3 = Color3.fromRGB(18, 14, 24)
    dropListFrame.BorderSizePixel = 0
    dropListFrame.Visible = false
    dropListFrame.ZIndex = 25
    dropListFrame.Parent = configBody

    local dlCorner = Instance.new("UICorner")
    dlCorner.CornerRadius = UDim.new(0, 6)
    dlCorner.Parent = dropListFrame

    local dlStroke = Instance.new("UIStroke")
    dlStroke.Thickness = 1
    dlStroke.Color = Color3.fromRGB(55, 45, 70)
    dlStroke.Parent = dropListFrame

    local dlScroll = Instance.new("ScrollingFrame")
    dlScroll.Size = UDim2.new(1, 0, 1, 0)
    dlScroll.BackgroundTransparency = 1
    dlScroll.ScrollBarThickness = 3
    dlScroll.ScrollBarImageColor3 = Color3.fromRGB(150, 90, 230)
    dlScroll.ZIndex = 26
    dlScroll.Parent = dropListFrame

    local dlLayout = Instance.new("UIListLayout")
    dlLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dlLayout.Parent = dlScroll

    local function refreshDropdownList()
        for _, child in ipairs(dlScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local list = manager.GetProfilesList()
        local itemHeight = 28
        local totalH = math.min(#list * itemHeight, 140)
        dropListFrame.Size = UDim2.new(1, 0, 0, totalH)
        dlScroll.CanvasSize = UDim2.new(0, 0, 0, #list * itemHeight)

        for _, pName in ipairs(list) do
            local itemBtn = Instance.new("TextButton")
            itemBtn.Size = UDim2.new(1, 0, 0, itemHeight)
            itemBtn.BackgroundColor3 = (pName == state.CurrentProfile) and Color3.fromRGB(35, 28, 45) or Color3.fromRGB(18, 14, 24)
            itemBtn.AutoButtonColor = false
            itemBtn.Text = "  " .. pName
            itemBtn.TextColor3 = (pName == state.CurrentProfile) and Color3.fromRGB(205, 140, 255) or Color3.fromRGB(235, 230, 245)
            itemBtn.TextSize = 11
            itemBtn.Font = Enum.Font.GothamMedium
            itemBtn.TextXAlignment = Enum.TextXAlignment.Left
            itemBtn.ZIndex = 27
            itemBtn.Parent = dlScroll

            itemBtn.MouseButton1Click:Connect(function()
                state.CurrentProfile = pName
                dbSelectedTxt.Text = pName
                nameBox.Text = pName
                dropListFrame.Visible = false
                dbCaret.Text = "⌄"
                refreshDropdownList()
            end)
        end
    end

    dropBtn.MouseButton1Click:Connect(function()
        dropListFrame.Visible = not dropListFrame.Visible
        dbCaret.Text = dropListFrame.Visible and "⌃" or "⌄"
        if dropListFrame.Visible then refreshDropdownList() end
    end)

    -- C. Auto-Load Status Row
    local autoLoadRow = Instance.new("Frame")
    autoLoadRow.Size = UDim2.new(1, 0, 0, 24)
    autoLoadRow.BackgroundTransparency = 1
    autoLoadRow.ZIndex = 17
    autoLoadRow.Parent = configBody

    local alLabel = Instance.new("TextLabel")
    alLabel.Position = UDim2.new(0, 2, 0, 0)
    alLabel.Size = UDim2.new(0.5, 0, 1, 0)
    alLabel.BackgroundTransparency = 1
    alLabel.Text = "Auto-Load"
    alLabel.TextColor3 = Color3.fromRGB(170, 160, 185)
    alLabel.TextSize = 12
    alLabel.Font = Enum.Font.GothamMedium
    alLabel.TextXAlignment = Enum.TextXAlignment.Left
    alLabel.ZIndex = 18
    alLabel.Parent = autoLoadRow

    local alValue = Instance.new("TextLabel")
    alValue.Position = UDim2.new(0.5, 0, 0, 0)
    alValue.Size = UDim2.new(0.5, -2, 1, 0)
    alValue.BackgroundTransparency = 1
    alValue.Text = state.AutoLoad or "None"
    alValue.TextColor3 = (state.AutoLoad and state.AutoLoad ~= "None") and Color3.fromRGB(245, 240, 255) or Color3.fromRGB(150, 140, 165)
    alValue.TextSize = 12
    alValue.Font = Enum.Font.GothamBold
    alValue.TextXAlignment = Enum.TextXAlignment.Right
    alValue.ZIndex = 18
    alValue.Parent = autoLoadRow

    -- D. Action Buttons
    createActionButton(configBody, "Save / Overwrite", true, function()
        local chosenName = nameBox.Text
        if chosenName:gsub("%s+", "") == "" then chosenName = state.CurrentProfile or "Default" end
        manager.SaveProfile(chosenName)
        dbSelectedTxt.Text = chosenName
        refreshDropdownList()
    end)

    createActionButton(configBody, "Load Selected", false, function()
        local chosenName = dbSelectedTxt.Text
        manager.LoadProfile(chosenName)
    end)

    createActionButton(configBody, "Set as Auto-Load", false, function()
        local chosenName = dbSelectedTxt.Text
        manager.SetAutoLoad(chosenName)
        alValue.Text = chosenName
        alValue.TextColor3 = Color3.fromRGB(245, 240, 255)
    end)

    createActionButton(configBody, "Clear Auto-Load", false, function()
        manager.ClearAutoLoad()
        alValue.Text = "None"
        alValue.TextColor3 = Color3.fromRGB(150, 140, 165)
    end)

    createActionButton(configBody, "Delete Selected", false, function()
        local chosenName = dbSelectedTxt.Text
        manager.DeleteProfile(chosenName)
        dbSelectedTxt.Text = state.CurrentProfile
        nameBox.Text = state.CurrentProfile
        alValue.Text = state.AutoLoad
        refreshDropdownList()
    end)

    -- =============================================================
    -- 📑 2. CARD "IMPORT / EXPORT" (KOLOM KANAN ATAS)
    -- =============================================================
    local importExportBody = createCard("Import / Export", rightCol)

    local jsonInputBox = Instance.new("TextBox")

    createActionButton(importExportBody, "Export (Copy JSON)", true, function()
        local json = manager.ExportJSON()
        jsonInputBox.Text = json
    end)

    -- Multi-line JSON Input
    jsonInputBox.Size = UDim2.new(1, 0, 0, 75)
    jsonInputBox.BackgroundColor3 = Color3.fromRGB(14, 11, 18)
    jsonInputBox.Text = ""
    jsonInputBox.PlaceholderText = "paste config JSON here..."
    jsonInputBox.PlaceholderColor3 = Color3.fromRGB(90, 85, 105)
    jsonInputBox.TextColor3 = Color3.fromRGB(235, 230, 245)
    jsonInputBox.TextSize = 11
    jsonInputBox.Font = Enum.Font.GothamMedium
    jsonInputBox.TextXAlignment = Enum.TextXAlignment.Left
    jsonInputBox.TextYAlignment = Enum.TextYAlignment.Top
    jsonInputBox.MultiLine = true
    jsonInputBox.TextWrapped = true
    jsonInputBox.ClearTextOnFocus = false
    jsonInputBox.ZIndex = 17
    jsonInputBox.Parent = importExportBody

    local jbCorner = Instance.new("UICorner")
    jbCorner.CornerRadius = UDim.new(0, 6)
    jbCorner.Parent = jsonInputBox

    local jbStroke = Instance.new("UIStroke")
    jbStroke.Thickness = 1
    jbStroke.Color = Color3.fromRGB(45, 36, 56)
    jbStroke.Parent = jsonInputBox

    local jbPad = Instance.new("UIPadding")
    jbPad.PaddingLeft = UDim.new(0, 8)
    jbPad.PaddingRight = UDim.new(0, 8)
    jbPad.PaddingTop = UDim.new(0, 6)
    jbPad.PaddingBottom = UDim.new(0, 6)
    jbPad.Parent = jsonInputBox

    createActionButton(importExportBody, "Import (Paste JSON)", false, function()
        local text = jsonInputBox.Text
        local targetName = nameBox.Text
        if targetName:gsub("%s+", "") == "" then targetName = "Imported" end
        local ok = manager.ImportJSON(text, targetName)
        if ok then
            dbSelectedTxt.Text = targetName
            nameBox.Text = targetName
            refreshDropdownList()
        end
    end)

    -- =============================================================
    -- 📑 3. CARD "UTILITY" (KOLOM KANAN BAWAH)
    -- =============================================================
    local utilityBody = createCard("Utility", rightCol)

    local function createToggleRow(parent, labelText, defaultVal, onToggle)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundTransparency = 1
        row.ZIndex = 17
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Position = UDim2.new(0, 2, 0, 0)
        lbl.Size = UDim2.new(1, -55, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(235, 230, 245)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 18
        lbl.Parent = row

        local switch = Instance.new("TextButton")
        switch.AnchorPoint = Vector2.new(1, 0.5)
        switch.Position = UDim2.new(1, -2, 0.5, 0)
        switch.Size = UDim2.new(0, 42, 0, 20)
        switch.BackgroundColor3 = defaultVal and Color3.fromRGB(175, 75, 255) or Color3.fromRGB(50, 38, 60)
        switch.AutoButtonColor = false
        switch.Text = ""
        switch.ZIndex = 18
        switch.Parent = row

        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(1, 0)
        sCorner.Parent = switch

        local knob = Instance.new("Frame")
        knob.AnchorPoint = Vector2.new(0, 0.5)
        knob.Position = defaultVal and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.ZIndex = 19
        knob.Parent = switch

        local kCorner = Instance.new("UICorner")
        kCorner.CornerRadius = UDim.new(1, 0)
        kCorner.Parent = knob

        local curState = defaultVal
        local function setSwitch(val)
            curState = val
            if curState then
                TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(175, 75, 255)}):Play()
                TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(1, -17, 0.5, 0)}):Play()
            else
                TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 38, 60)}):Play()
                TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.5, 0)}):Play()
            end
            if onToggle then onToggle(curState) end
        end

        switch.MouseButton1Click:Connect(function()
            setSwitch(not curState)
        end)

        return {
            Set = setSwitch,
            Get = function() return curState end
        }
    end

    -- Toggle Rejoin on Kick
    createToggleRow(utilityBody, "Rejoin on Kick", state.Utility.RejoinOnKick, function(val)
        state.Utility.RejoinOnKick = val
        manager.SaveIndex()
        setupRejoinOnKick(val, notifyFunc)
        if notifyFunc then notifyFunc("Rejoin on Kick", val and "Rejoin on Kick diaktifkan!" or "Rejoin on Kick dimatikan.", 2) end
    end)

    -- Toggle Auto Execute
    createToggleRow(utilityBody, "Auto Execute", state.Utility.AutoExecute, function(val)
        state.Utility.AutoExecute = val
        manager.SaveIndex()
        setupAutoExecute(val, scriptUrl, notifyFunc)
        if notifyFunc then notifyFunc("Auto Execute", val and "Auto Execute diaktifkan!" or "Auto Execute dimatikan.", 2) end
    end)

    -- Initial setup
    if state.Utility.RejoinOnKick then setupRejoinOnKick(true, notifyFunc) end
    if state.Utility.AutoExecute then setupAutoExecute(true, scriptUrl, notifyFunc) end

    -- Jalankan Auto-Load jika ada saat startup
    if state.AutoLoad and state.AutoLoad ~= "None" and state.Profiles[state.AutoLoad] then
        task.spawn(function()
            task.wait(1)
            manager.LoadProfile(state.AutoLoad)
        end)
    end
end

return ModernSettings
