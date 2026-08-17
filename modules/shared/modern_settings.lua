--[[
	===========================================================
	⚡ RITOD HUB | MODERN SETTINGS ENGINE (SHARED/OPTIMIZED)
	GitHub: https://github.com/RyuZeed/capybara
	===========================================================
	ONE file, TWO games. Zero duplication.
	===========================================================
]]

local ModernSettings = {}
_G.ModernSettings = ModernSettings
local Http    = game:GetService("HttpService")
local Tween   = game:GetService("TweenService")
local Teleport = game:GetService("TeleportService")
local GuiSvc  = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LP      = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()

-- ─── Cached tween infos ────────────────────────────────────────
local TW_FAST  = TweenInfo.new(0.15)
local TW_MED   = TweenInfo.new(0.2)

-- ─── Compact instance builder ──────────────────────────────────
local function n(cls, props, parent)
	local i = Instance.new(cls)
	for k, v in next, props do i[k] = v end
	if parent then i.Parent = parent end
	return i
end

local function corner(r, p) return n("UICorner", {CornerRadius = UDim.new(0, r)}, p) end
local function stroke(t, c, p) return n("UIStroke", {Thickness = t, Color = c}, p) end
local function pad(l, r, t, b, p)
	return n("UIPadding", {PaddingLeft=UDim.new(0,l), PaddingRight=UDim.new(0,r), PaddingTop=UDim.new(0,t), PaddingBottom=UDim.new(0,b)}, p)
end

-- ─── Colors ────────────────────────────────────────────────────
local C = {
	BG      = Color3.fromRGB(20, 16, 26),
	BG2     = Color3.fromRGB(14, 11, 18),
	BGDROP  = Color3.fromRGB(18, 14, 24),
	BGHOV   = Color3.fromRGB(28, 22, 36),
	BGHOV2  = Color3.fromRGB(38, 30, 48),
	STROKE  = Color3.fromRGB(45, 36, 56),
	STROKE2 = Color3.fromRGB(55, 45, 70),
	TEXT    = Color3.fromRGB(235, 230, 245),
	TEXTSUB = Color3.fromRGB(170, 160, 185),
	TEXTLOW = Color3.fromRGB(150, 140, 165),
	PURPLE  = Color3.fromRGB(175, 75, 255),
	PURPLEDIM = Color3.fromRGB(205, 140, 255),
	PURPLEDARK = Color3.fromRGB(50, 38, 60),
	BTNPRI  = Color3.fromRGB(222, 226, 235),
	BTNPRIDIM = Color3.fromRGB(240, 242, 250),
	BTNPRITXT = Color3.fromRGB(20, 20, 25),
	BTNPRICARET = Color3.fromRGB(60, 60, 70),
	CARET   = Color3.fromRGB(180, 175, 195),
	SELROW  = Color3.fromRGB(35, 28, 45),
	WHITE   = Color3.fromRGB(255, 255, 255),
}

-- =================================================================
-- 📁 PROFILE MANAGER
-- =================================================================
function ModernSettings.CreateProfileManager(gameFolder, defaultCfg, getActiveCfg, applyCfg, notify)
    local Mgr  = {}
    local ROOT = "RitodHub"
    local DIR  = gameFolder or "RitodHub/Default"
    local CFGS = DIR .. "/Configs"
    local IDX  = DIR .. "/profiles_v2.json"

    local function mkdirs()
        pcall(function()
            if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
                if not isfolder(ROOT) then makefolder(ROOT) end
                if not isfolder(DIR)  then makefolder(DIR)  end
                if not isfolder(CFGS) then makefolder(CFGS) end
            end
        end)
    end

    local function copy(v)
        if type(v) ~= "table" then return v end
        local c = {}
        for k, vv in next, v do c[copy(k)] = copy(vv) end
        return c
    end

    local S = {
        Current  = "Default",
        AutoLoad = "Default",
        Profiles = { Default = copy(defaultCfg) },
        Utility  = { RejoinOnKick = false, AutoExecute = false }
    }

    function Mgr.SaveIdx()
        mkdirs()
        pcall(function()
            if typeof(writefile) == "function" then
                writefile(IDX, Http:JSONEncode({Current=S.Current, AutoLoad=S.AutoLoad, Profiles=S.Profiles, Utility=S.Utility}))
                if S.Profiles[S.Current] then
                    writefile(CFGS.."/"..S.Current..".json", Http:JSONEncode(S.Profiles[S.Current]))
                end
            end
        end)
    end

    function Mgr.LoadIdx()
        mkdirs()
        pcall(function()
            if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(IDX) then
                local d = Http:JSONDecode(readfile(IDX))
                if typeof(d) == "table" then
                    if d.Current  then S.Current  = d.Current  end
                    if d.AutoLoad then S.AutoLoad  = d.AutoLoad end
                    if typeof(d.Profiles) == "table" then
                        for k, v in next, d.Profiles do S.Profiles[k] = v end
                    end
                    if typeof(d.Utility) == "table" then
                        S.Utility.RejoinOnKick = d.Utility.RejoinOnKick == true
                        S.Utility.AutoExecute  = d.Utility.AutoExecute  == true
                    end
                end
            end
        end)
        return S
    end

    function Mgr.State()        return S end
    function Mgr.Profiles()
        local list = {}
        for k in next, S.Profiles do list[#list+1] = k end
        table.sort(list)
        if #list == 0 then list[1] = "Default" end
        return list
    end

    function Mgr.Save(name, data)
        name = (name and name:gsub("%s+","") ~= "" and name) or "Default"
        S.Current = name; S.Profiles[name] = copy(data or getActiveCfg())
        Mgr.SaveIdx()
        if notify then notify("Config Saved", "Profile '"..name.."' tersimpan!", 2.5) end
        return true
    end

    function Mgr.Load(name)
        if not name or not S.Profiles[name] then
            if notify then notify("Config Error", "Profile '"..tostring(name).."' tidak ditemukan.", 2.5) end
            return false
        end
        S.Current = name
        if applyCfg then applyCfg(copy(S.Profiles[name])) end
        Mgr.SaveIdx()
        if notify then notify("Config Loaded", "Profile '"..name.."' dimuat!", 2.5) end
        return true
    end

    function Mgr.SetAutoLoad(name)
        S.AutoLoad = (name and S.Profiles[name]) and name or "Default"
        Mgr.SaveIdx()
        if notify then notify("Auto-Load Set", "Profile '"..S.AutoLoad.."' jadi Auto-Load!", 2.5) end
    end

    function Mgr.ClearAutoLoad()
        S.AutoLoad = "None"; Mgr.SaveIdx()
        if notify then notify("Auto-Load Cleared", "Auto-Load dinonaktifkan.", 2.5) end
    end

    function Mgr.Delete(name)
        if name == "Default" then
            S.Profiles.Default = copy(defaultCfg)
            if notify then notify("Config Reset", "Profile 'Default' direset.", 2.5) end
        else
            S.Profiles[name] = nil
            pcall(function() if typeof(delfile) == "function" and isfile(CFGS.."/"..name..".json") then delfile(CFGS.."/"..name..".json") end end)
            if S.Current  == name then S.Current  = "Default" end
            if S.AutoLoad == name then S.AutoLoad  = "None"    end
            if notify then notify("Config Deleted", "Profile '"..name.."' dihapus.", 2.5) end
        end
        Mgr.SaveIdx()
    end

    function Mgr.Export()
        local j = Http:JSONEncode(getActiveCfg())
        if setclipboard then setclipboard(j) end
        if notify then notify("Export Config", "JSON disalin ke Clipboard!", 2.5) end
        return j
    end

    function Mgr.Import(json, targetName)
        if not json or json:gsub("%s+","") == "" then
            if notify then notify("Import Error", "Teks JSON kosong!", 2.5) end; return false
        end
        local ok, d = pcall(Http.JSONDecode, Http, json)
        if ok and typeof(d) == "table" then
            local pName = (targetName and targetName:gsub("%s+","") ~= "" and targetName) or "Imported"
            S.Profiles[pName] = d; S.Current = pName
            if applyCfg then applyCfg(d) end
            Mgr.SaveIdx()
            if notify then notify("Import OK", "JSON diimpor ke '"..pName.."'!", 2.5) end
            return true
        end
        if notify then notify("Import Error", "Format JSON tidak valid!", 2.5) end
        return false
    end

    Mgr.LoadIdx()
    return Mgr
end

-- =================================================================
-- 🛡️ UTILITY (REJOIN + AUTO EXECUTE)
-- =================================================================
local _rejoin, _autoExec = false, false

local function enableRejoin(on, notify)
    _rejoin = on
    if not on or _G._RitodRejoinInit then return end
    _G._RitodRejoinInit = true
    local function doRejoin()
        if not _rejoin then return end
        if notify then notify("Rejoin on Kick", "Terputus! Rejoining dalam 3 detik...", 3) end
        task.wait(3); pcall(Teleport.Teleport, Teleport, game.PlaceId, LP)
    end
    pcall(function()
        local p = CoreGui:FindFirstChild("RobloxPromptGui")
        local o = p and p:FindFirstChild("promptOverlay")
        if o then o.ChildAdded:Connect(function(c) if _rejoin and c.Name=="ErrorPrompt" then doRejoin() end end) end
    end)
    pcall(function() GuiSvc.ErrorMessageChanged:Connect(function() if _rejoin then doRejoin() end end) end)
end

local function enableAutoExec(on, url, notify)
    _autoExec = on
    if on and url and typeof(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, ('loadstring(game:HttpGet("%s"))()'):format(url))
        if notify then notify("Auto Execute", "Terdaftar untuk teleport berikutnya!", 2.5) end
    end
end

-- =================================================================
-- 🎨 UI BUILDER
-- =================================================================
function ModernSettings.BuildUI(page, mgr, scriptUrl, notify)
    local S = mgr.State()

    -- ── Layout root ─────────────────────────────────────────────
    local root = n("Frame", {
        Name="ModernSettings", Size=UDim2.new(1,0,0,0),
        AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, ZIndex=14
    }, page)
    n("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal,
        HorizontalAlignment=Enum.HorizontalAlignment.Center,
        SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10)}, root)

    local function col()
        local f = n("Frame", {Size=UDim2.new(0.485,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1}, root)
        n("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10)}, f)
        return f
    end
    local LEFT, RIGHT = col(), col()

    -- ── Card builder ────────────────────────────────────────────
    local function card(title, parent)
        local frame = n("Frame", {Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundColor3=C.BG, BorderSizePixel=0, ZIndex=15}, parent)
        corner(10, frame); stroke(1, C.STROKE, frame)

        local hdr = n("TextButton", {Size=UDim2.new(1,0,0,36), BackgroundTransparency=1,
            Text="", AutoButtonColor=false, ZIndex=16}, frame)
        local htl = n("TextLabel", {Position=UDim2.new(0,12,0,0), Size=UDim2.new(1,-40,1,0),
            BackgroundTransparency=1, Text=title, TextColor3=C.TEXT, TextSize=13,
            Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16}, hdr)
        local hca = n("TextLabel", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-12,.5,0),
            Size=UDim2.new(0,20,0,20), BackgroundTransparency=1, Text="⌃",
            TextColor3=C.CARET, TextSize=14, Font=Enum.Font.GothamBold, ZIndex=16}, hdr)
        htl:GetPropertyChangedSignal("Text") -- suppress unused warning

        local body = n("Frame", {Position=UDim2.new(0,0,0,36), Size=UDim2.new(1,0,0,0),
            AutomaticSize=Enum.AutomaticSize.Y, BackgroundTransparency=1, ZIndex=16}, frame)
        pad(10,10,2,10,body)
        n("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)}, body)

        local open = true
        hdr.MouseButton1Click:Connect(function()
            open = not open; body.Visible = open; hca.Text = open and "⌃" or "⌄"
        end)
        return body
    end

    -- ── Action button ───────────────────────────────────────────
    local function actbtn(parent, text, primary, cb)
        local btn = n("TextButton", {
            Size=UDim2.new(1,0,0,34),
            BackgroundColor3=primary and C.BTNPRI or C.BGHOV,
            AutoButtonColor=false, Text="", ZIndex=17
        }, parent)
        corner(7, btn)
        if not primary then stroke(1, Color3.fromRGB(48,38,60), btn) end
        n("TextLabel", {Position=UDim2.new(0,10,0,0), Size=UDim2.new(1,-30,1,0),
            BackgroundTransparency=1, Text=text,
            TextColor3=primary and C.BTNPRITXT or C.TEXT,
            TextSize=12, Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Center, ZIndex=18}, btn)
        n("TextLabel", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-10,.5,0),
            Size=UDim2.new(0,16,0,16), BackgroundTransparency=1, Text="›",
            TextColor3=primary and C.BTNPRICARET or C.CARET,
            TextSize=16, Font=Enum.Font.GothamBold, ZIndex=18}, btn)

        local ON  = primary and C.BTNPRIDIM or C.BGHOV2
        local OFF = primary and C.BTNPRI    or C.BGHOV
        btn.MouseEnter:Connect(function()  Tween:Create(btn, TW_FAST, {BackgroundColor3=ON}):Play()  end)
        btn.MouseLeave:Connect(function()  Tween:Create(btn, TW_FAST, {BackgroundColor3=OFF}):Play() end)
        btn.MouseButton1Click:Connect(function() if cb then cb() end end)
        return btn
    end

    -- ── TextBox helper ──────────────────────────────────────────
    local function textbox(parent, ph, h, multiline)
        local box = n("TextBox", {
            Size=UDim2.new(1,0,0,h or 32),
            BackgroundColor3=C.BG2, Text="", PlaceholderText=ph,
            PlaceholderColor3=Color3.fromRGB(90,85,105), TextColor3=C.TEXT,
            TextSize=12, Font=Enum.Font.GothamMedium,
            TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false,
            MultiLine=multiline or false, TextWrapped=multiline or false,
            TextYAlignment=multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
            ZIndex=17
        }, parent)
        corner(6, box); stroke(1, C.STROKE, box)
        pad(10, 10, multiline and 6 or 0, multiline and 6 or 0, box)
        return box
    end

    -- ── Label helper ────────────────────────────────────────────
    local function lbl(parent, text, sub)
        return n("TextLabel", {
            Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Text=text,
            TextColor3=sub and C.TEXTSUB or C.TEXT, TextSize=11,
            Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=17
        }, parent)
    end

    -- ══════════════════════════════════════════════════════════════
    -- 📑 CARD 1 — CONFIG (LEFT)
    -- ══════════════════════════════════════════════════════════════
    local cfgBody = card("Config", LEFT)

    lbl(cfgBody, "Config Name", true)
    local nameBox = textbox(cfgBody, "my config")
    nameBox.Text = S.Current or ""

    lbl(cfgBody, "Saved Configs", true)

    -- Dropdown
    local dropBtn = n("TextButton", {Size=UDim2.new(1,0,0,32), BackgroundColor3=C.BG2,
        AutoButtonColor=false, Text="", ZIndex=17}, cfgBody)
    corner(6, dropBtn); stroke(1, C.STROKE, dropBtn)
    local selTxt = n("TextLabel", {Position=UDim2.new(0,10,0,0), Size=UDim2.new(1,-35,1,0),
        BackgroundTransparency=1, Text=S.Current or "Default", TextColor3=C.TEXT,
        TextSize=12, Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=18}, dropBtn)
    local caret  = n("TextLabel", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-10,.5,0),
        Size=UDim2.new(0,16,0,16), BackgroundTransparency=1, Text="⌄",
        TextColor3=C.TEXTSUB, TextSize=14, Font=Enum.Font.GothamBold, ZIndex=18}, dropBtn)

    -- Dropdown list (built once, reused)
    local dropFrame = n("Frame", {Size=UDim2.new(1,0,0,0), BackgroundColor3=C.BGDROP,
        BorderSizePixel=0, Visible=false, ZIndex=25}, cfgBody)
    corner(6, dropFrame); stroke(1, C.STROKE2, dropFrame)
    local scroll = n("ScrollingFrame", {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
        ScrollBarThickness=3, ScrollBarImageColor3=C.PURPLE, ZIndex=26}, dropFrame)
    n("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder}, scroll)

    local dropItems = {}  -- cached item buttons
    local function rebuildDrop()
        local list = mgr.Profiles()
        local H    = 28
        dropFrame.Size = UDim2.new(1,0,0, math.min(#list*H, 140))
        scroll.CanvasSize = UDim2.new(0,0,0, #list*H)

        -- Reuse existing buttons, create new ones only if needed
        for i, pName in ipairs(list) do
            if not dropItems[i] then
                dropItems[i] = n("TextButton", {Size=UDim2.new(1,0,0,H), AutoButtonColor=false,
                    TextSize=11, Font=Enum.Font.GothamMedium,
                    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=27}, scroll)
                local idx = i
                dropItems[i].MouseButton1Click:Connect(function()
                    S.Current = dropItems[idx].Text:sub(3)
                    selTxt.Text = S.Current; nameBox.Text = S.Current
                    dropFrame.Visible = false; caret.Text = "⌄"
                    rebuildDrop()  -- just recolor
                end)
            end
            local isCur = (pName == S.Current)
            dropItems[i].Text = "  " .. pName
            dropItems[i].BackgroundColor3 = isCur and C.SELROW or C.BGDROP
            dropItems[i].TextColor3 = isCur and C.PURPLEDIM or C.TEXT
            dropItems[i].Visible = true
        end
        -- Hide leftover items
        for i = #list+1, #dropItems do
            dropItems[i].Visible = false
        end
    end

    dropBtn.MouseButton1Click:Connect(function()
        dropFrame.Visible = not dropFrame.Visible
        caret.Text = dropFrame.Visible and "⌃" or "⌄"
        if dropFrame.Visible then rebuildDrop() end
    end)

    -- Auto-load row
    local alRow = n("Frame", {Size=UDim2.new(1,0,0,24), BackgroundTransparency=1, ZIndex=17}, cfgBody)
    n("TextLabel", {Position=UDim2.new(0,2,0,0), Size=UDim2.new(.5,0,1,0), BackgroundTransparency=1,
        Text="Auto-Load", TextColor3=C.TEXTSUB, TextSize=12, Font=Enum.Font.GothamMedium,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=18}, alRow)
    local alVal = n("TextLabel", {Position=UDim2.new(.5,0,0,0), Size=UDim2.new(.5,-2,1,0), BackgroundTransparency=1,
        Text=S.AutoLoad or "None", TextColor3=(S.AutoLoad and S.AutoLoad~="None") and C.TEXT or C.TEXTLOW,
        TextSize=12, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=18}, alRow)

    -- Action buttons
    actbtn(cfgBody, "Save / Overwrite", true, function()
        local nm = nameBox.Text:gsub("%s+","")~="" and nameBox.Text or "Default"
        mgr.Save(nm); selTxt.Text = nm; rebuildDrop()
    end)
    actbtn(cfgBody, "Load Selected", false, function() mgr.Load(selTxt.Text) end)
    actbtn(cfgBody, "Set as Auto-Load", false, function()
        mgr.SetAutoLoad(selTxt.Text)
        alVal.Text = S.AutoLoad; alVal.TextColor3 = C.TEXT
    end)
    actbtn(cfgBody, "Clear Auto-Load", false, function()
        mgr.ClearAutoLoad(); alVal.Text = "None"; alVal.TextColor3 = C.TEXTLOW
    end)
    actbtn(cfgBody, "Delete Selected", false, function()
        mgr.Delete(selTxt.Text)
        selTxt.Text = S.Current; nameBox.Text = S.Current
        alVal.Text  = S.AutoLoad
        rebuildDrop()
    end)

    -- ══════════════════════════════════════════════════════════════
    -- 📤 CARD 2 — IMPORT / EXPORT (RIGHT TOP)
    -- ══════════════════════════════════════════════════════════════
    local ieBody  = card("Import / Export", RIGHT)
    local jsonBox = textbox(nil, "paste config JSON here...", 75, true)  -- deferred parent

    actbtn(ieBody, "Export (Copy JSON)", true, function()
        jsonBox.Text = mgr.Export()
    end)

    jsonBox.Parent = ieBody

    actbtn(ieBody, "Import (Paste JSON)", false, function()
        local nm = nameBox.Text:gsub("%s+","")~="" and nameBox.Text or "Imported"
        if mgr.Import(jsonBox.Text, nm) then
            selTxt.Text = S.Current; nameBox.Text = S.Current; rebuildDrop()
            -- Langsung terapkan config yg diimpor ke semua modul aktif
            task.defer(function()
                mgr.Load(S.Current)
            end)
        end
    end)

    -- ══════════════════════════════════════════════════════════════
    -- 🛡️ CARD 3 — UTILITY (RIGHT BOTTOM)
    -- ══════════════════════════════════════════════════════════════
    local utBody = card("Utility", RIGHT)

    local function toggleRow(parent, label, default, onChange)
        local row = n("Frame", {Size=UDim2.new(1,0,0,32), BackgroundTransparency=1, ZIndex=17}, parent)
        n("TextLabel", {Position=UDim2.new(0,2,0,0), Size=UDim2.new(1,-55,1,0),
            BackgroundTransparency=1, Text=label, TextColor3=C.TEXT, TextSize=12,
            Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=18}, row)

        local sw = n("TextButton", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-2,.5,0),
            Size=UDim2.new(0,42,0,20), BackgroundColor3=default and C.PURPLE or C.PURPLEDARK,
            AutoButtonColor=false, Text="", ZIndex=18}, row)
        corner(20, sw)
        local kb = n("Frame", {AnchorPoint=Vector2.new(0,.5),
            Position=default and UDim2.new(1,-17,.5,0) or UDim2.new(0,3,.5,0),
            Size=UDim2.new(0,14,0,14), BackgroundColor3=C.WHITE, BorderSizePixel=0, ZIndex=19}, sw)
        corner(9, kb)

        local cur = default
        local function apply(v)
            cur = v
            Tween:Create(sw, TW_MED, {BackgroundColor3=v and C.PURPLE or C.PURPLEDARK}):Play()
            Tween:Create(kb, TW_MED, {Position=v and UDim2.new(1,-17,.5,0) or UDim2.new(0,3,.5,0)}):Play()
            if onChange then onChange(v) end
        end
        sw.MouseButton1Click:Connect(function() apply(not cur) end)
        return { Set=apply, Get=function() return cur end }
    end

    toggleRow(utBody, "Rejoin on Kick", S.Utility.RejoinOnKick, function(v)
        S.Utility.RejoinOnKick = v; mgr.SaveIdx(); enableRejoin(v, notify)
        if notify then notify("Rejoin on Kick", v and "Aktif!" or "Dimatikan.", 2) end
    end)

    toggleRow(utBody, "Auto Execute", S.Utility.AutoExecute, function(v)
        S.Utility.AutoExecute = v; mgr.SaveIdx(); enableAutoExec(v, scriptUrl, notify)
        if notify then notify("Auto Execute", v and "Aktif!" or "Dimatikan.", 2) end
    end)

    -- ── Initial startup logic ───────────────────────────────────
    if S.Utility.RejoinOnKick then enableRejoin(true, notify) end
    if S.Utility.AutoExecute  then enableAutoExec(true, scriptUrl, notify) end

    if S.AutoLoad and S.AutoLoad ~= "None" and S.Profiles[S.AutoLoad] then
        task.defer(mgr.Load, S.AutoLoad)
    end
end

return ModernSettings
