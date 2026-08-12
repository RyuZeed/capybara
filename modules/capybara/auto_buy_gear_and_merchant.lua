--[[
	===============================================================
	⚡ RITOD HUB - AUTO BUY GEAR & TRAVELING MERCHANTS (ALL-IN-ONE)
	Game: Capybaras vs Plants (PlaceId: 104973076655377)
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 UPGRADED FEATURES:
	- 🛒 BORONG SEMUA: Default membeli SEMUA Gear & SEMUA Merchant item yang ada stok!
	- 🛑 ANTI-SPAM: Cek stok di UI & attribute sebelum remote dikirim
	- 🎯 SMART DUAL-DISPATCH: Remote + UI Button Clicker (Auto Click tombol Buy non-robux)
	- 🔢 MULTI-STOCK BUYER: Jika stok ada 2 atau 3, akan dibeli sampai habis
	- 👑 FULL 4 MERCHANTS: King Capybara, Martian, Timbles, Jester
	===============================================================
]]

local AutoBuyGearAndMerchant = {}
_G.AutoBuyGearAndMerchant = AutoBuyGearAndMerchant

-- 🔇 SILENT MODE: Matikan seluruh text/log terminal
local print = function(...) end
local warn = function(...) end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.PlayerAdded:Wait()
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

-- =================================================================
-- 📋 OFFICIAL CATALOGS
-- =================================================================

-- ⚙️ 1. GEAR SHOP CATALOG (5 Items)
AutoBuyGearAndMerchant.GEAR_CATALOG = {
	{ name = "Hatch Hammer",       rarity = "Common",    price = "$1k",   category = "Gear" },
	{ name = "Nametag",            rarity = "Rare",      price = "$5k",   category = "Gear" },
	{ name = "Mutation Sponge",    rarity = "Rare",      price = "$10k",  category = "Gear" },
	{ name = "Boombox",            rarity = "Legendary", price = "$50k",  category = "Gear" },
	{ name = "Bizarre Stopwatch",  rarity = "Mythic",    price = "$750k", category = "Gear" },
}

-- 🏪 2. TRAVELING MERCHANTS POOL (15 Items dari 4 Merchant)
AutoBuyGearAndMerchant.MERCHANTS = {
	["King Capybara"] = {
		name = "King Capybara",
		icon = "👑",
		items = {
			{ name = "Gilded Hatch Hammer", rarity = "Divine", merchant = "King Capybara" },
			{ name = "Gold Scroll",         rarity = "Divine", merchant = "King Capybara" },
			{ name = "Totem Of Status",     rarity = "Godly",  merchant = "King Capybara" },
		}
	},
	["Martian"] = {
		name = "Martian",
		icon = "👽",
		items = {
			{ name = "Raygun",          rarity = "Epic",   merchant = "Martian" },
			{ name = "Alien Tesla",     rarity = "Divine", merchant = "Martian" },
			{ name = "Totem Of Stars",  rarity = "Godly",  merchant = "Martian" },
		}
	},
	["Timbles"] = {
		name = "Timbles",
		icon = "🐿️",
		items = {
			{ name = "Totem Of Might",   rarity = "Divine", merchant = "Timbles" },
			{ name = "Totem Of Marrow",  rarity = "Godly",  merchant = "Timbles" },
			{ name = "Rainbow Scroll",   rarity = "Divine", merchant = "Timbles" },
		}
	},
	["Jester"] = {
		name = "Jester",
		icon = "🃏",
		items = {
			{ name = "Moonlit Scroll",   rarity = "Rare",      merchant = "Jester" },
			{ name = "Chilly Scroll",    rarity = "Epic",      merchant = "Jester" },
			{ name = "Toasty Scroll",    rarity = "Epic",      merchant = "Jester" },
			{ name = "Tranquil Scroll",  rarity = "Legendary", merchant = "Jester" },
			{ name = "Shocked Scroll",   rarity = "Legendary", merchant = "Jester" },
			{ name = "Glitched Scroll",  rarity = "Divine",    merchant = "Jester" },
		}
	}
}

local fullMerchantList = {}
for _, mData in pairs(AutoBuyGearAndMerchant.MERCHANTS) do
	for _, item in ipairs(mData.items) do
		table.insert(fullMerchantList, item)
	end
end
AutoBuyGearAndMerchant.MERCHANT_CATALOG = fullMerchantList

-- =================================================================
-- ⚙️ CONFIGURATION (DEFAULT: AKTIFKAN SEMUA ITEM & SEMUA MERCHANT)
-- =================================================================

AutoBuyGearAndMerchant.Config = {
	-- Gear Settings
	GearEnabled  = true,
	BuyAllGear   = true,   -- Default TRUE: Membeli seluruh gear yang ada stok
	SelectedGear = {
		["hatch hammer"]      = true,
		["nametag"]           = true,
		["mutation sponge"]   = true,
		["boombox"]           = true,
		["bizarre stopwatch"] = true,
	},

	-- Merchant Settings
	MerchantEnabled  = true,
	BuyAllMerchant   = true,   -- Default TRUE: Membeli seluruh item dari merchant yang aktif
	SelectedMerchant = {
		-- King Capybara
		["gilded hatch hammer"] = true,
		["gold scroll"]         = true,
		["totem of status"]     = true,

		-- Martian
		["raygun"]              = true,
		["alien tesla"]         = true,
		["totem of stars"]      = true,

		-- Timbles
		["totem of might"]      = true,
		["totem of marrow"]     = true,
		["rainbow scroll"]      = true,

		-- Jester
		["moonlit scroll"]      = true,
		["chilly scroll"]       = true,
		["toasty scroll"]       = true,
		["tranquil scroll"]     = true,
		["shocked scroll"]      = true,
		["glitched scroll"]     = true,
	},

	-- Merchant Groups (Semua merchant diaktifkan secara default)
	MerchantGroups = {
		["King Capybara"] = true,
		["Martian"]       = true,
		["Timbles"]       = true,
		["Jester"]        = true,
	},

	-- Timing
	GearCheckInterval     = 1.0,
	MerchantCheckInterval = 1.0,
	DebounceTime          = 1.5,
}

-- =================================================================
-- 📊 STATE
-- =================================================================

local isGearRunning     = false
local isMerchantRunning = false
local gearThread        = nil
local merchantThread    = nil
local stockConnections  = {}
local remoteConnections = {}
local lastBuyTime       = {}

local totalGearBought     = 0
local totalMerchantBought = 0

AutoBuyGearAndMerchant.OnGearCatalogUpdated     = nil
AutoBuyGearAndMerchant.OnMerchantCatalogUpdated = nil
AutoBuyGearAndMerchant.OnItemBought             = nil

-- =================================================================
-- 🛠️ HELPER FUNCTIONS
-- =================================================================

local function getMainGui()
	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	return pg and pg:FindFirstChild("MainGui")
end

local function getFramesRoot()
	local mainGui = getMainGui()
	local root = mainGui and mainGui:FindFirstChild("Root")
	return root and root:FindFirstChild("Frames")
end

local function getRemotes()
	return ReplicatedStorage:FindFirstChild("Remotes")
		or ReplicatedStorage:FindFirstChild("Remotes", true)
end

local function callRemote(name, ...)
	local remotes = getRemotes()
	local remote = remotes and remotes:FindFirstChild(name)
	if not remote then remote = ReplicatedStorage:FindFirstChild(name, true) end
	if remote then
		if remote:IsA("RemoteEvent") then
			return remote:FireServer(...)
		elseif remote:IsA("RemoteFunction") then
			return remote:InvokeServer(...)
		end
	end
	return nil
end

local function clickButton(btn)
	if not btn then return end

	if typeof(firesignal) == "function" then
		if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
		if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
		if btn.MouseButton1Down then pcall(function() firesignal(btn.MouseButton1Down) end) end
	end

	if typeof(getconnections) == "function" then
		for _, ev in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down"}) do
			pcall(function()
				if btn[ev] then
					for _, conn in ipairs(getconnections(btn[ev])) do
						if conn.Function then conn.Function() elseif conn.Fire then conn:Fire() end
					end
				end
			end)
		end
	end

	pcall(function()
		local pos = btn.AbsolutePosition
		local size = btn.AbsoluteSize
		local cx = math.floor(pos.X + size.X / 2)
		local cy = math.floor(pos.Y + size.Y / 2)
		if typeof(VirtualInputManager) == "userdata" or typeof(VirtualInputManager) == "table" then
			VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
			task.wait(0.02)
			VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
		end
	end)
end

-- Cari tombol beli (bukan tombol robux) di dalam frame item
local function findBuyButton(itemFrame)
	if not itemFrame then return nil end

	-- 1. Cek folder/frame Buy
	local buyContainer = itemFrame:FindFirstChild("Buy")
	if buyContainer then
		if buyContainer:IsA("GuiButton") then return buyContainer end
		local innerBtn = buyContainer:FindFirstChildWhichIsA("GuiButton", true)
		if innerBtn then return innerBtn end
	end

	-- 2. Scan descendants untuk tombol non-robux
	for _, desc in ipairs(itemFrame:GetDescendants()) do
		if desc:IsA("GuiButton") then
			local nameLow = desc.Name:lower()
			local parentName = desc.Parent and desc.Parent.Name:lower() or ""
			if not nameLow:find("robux") and not parentName:find("robux") then
				return desc
			end
		end
	end

	return nil
end

local function isDebounced(itemKey)
	local last = lastBuyTime[itemKey]
	if not last then return false end
	return (tick() - last) < (AutoBuyGearAndMerchant.Config.DebounceTime or 1.5)
end

local function markBought(itemKey)
	lastBuyTime[itemKey] = tick()
end

-- =================================================================
-- 📦 MERCHANT & STOCK DETECTORS (ANTI-SPAM & ZERO FALSE-POSITIVE)
-- =================================================================

local lastKnownMerchant = nil

function AutoBuyGearAndMerchant.IsMerchantPresent(merchantName)
	local found = false
	local merchantNames = {"king capybara", "martian", "timbles", "jester"}

	-- 1. Cek apakah ada NPC Traveling Merchant spesifik di Workspace
	pcall(function()
		local searchFolders = {
			workspace,
			workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map"),
			workspace:FindFirstChild("Map"),
			workspace:FindFirstChild("NPCs"),
			workspace:FindFirstChild("Merchants"),
			workspace:FindFirstChild("TravelingMerchants")
		}
		for _, folder in ipairs(searchFolders) do
			if folder then
				for _, obj in ipairs(folder:GetChildren()) do
					if obj:IsA("Model") or obj:IsA("Folder") then
						local oName = obj.Name:lower()
						if oName:find("traveling") or oName:find("travelling") then
							found = true
							return
						end
						for _, mName in ipairs(merchantNames) do
							if oName:find(mName) then
								found = true
								return
							end
						end
					end
				end
			end
		end
	end)

	if found then return true end

	-- 2. Cek apakah UI MerchantShop aktif dan benar-benar Visible
	local frames = getFramesRoot()
	local merchantShop = frames and frames:FindFirstChild("MerchantShop")
	if merchantShop and merchantShop:IsA("GuiObject") and merchantShop.Visible then
		local list = merchantShop:FindFirstChild("List")
		if list then
			for _, itemFrame in ipairs(list:GetChildren()) do
				if itemFrame:IsA("GuiObject") and itemFrame.Visible and not itemFrame.Name:find("Layout") then
					local sLbl = itemFrame:FindFirstChild("Stock", true)
					if sLbl and sLbl:IsA("TextLabel") and sLbl.Text then
						local cnt = tonumber(sLbl.Text:match("(%d+)"))
						if cnt and cnt > 0 then
							return true
						end
					end
				end
			end
		end
	end

	return false
end

function AutoBuyGearAndMerchant.HasGearStock(gearName)
	local frames = getFramesRoot()
	local gearShop = frames and frames:FindFirstChild("GearShop")
	local list = gearShop and gearShop:FindFirstChild("List")
	if not list then
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		list = pg and pg:FindFirstChild("GearShop", true) and pg.GearShop:FindFirstChild("List", true)
	end
	if not list then return false, 0 end

	local itemFrame = list:FindFirstChild(gearName)
	if not itemFrame then return false, 0 end

	-- 1. Cek visibilitas item frame
	if itemFrame:IsA("GuiObject") and itemFrame.Visible == false then
		return false, 0
	end

	-- 2. Cek attribute OutOfStock
	if itemFrame:GetAttribute("OutOfStock") == true then
		return false, 0
	end

	-- 3. Cek attribute Stock / Count
	local attrStock = itemFrame:GetAttribute("Stock") or itemFrame:GetAttribute("Count")
	if typeof(attrStock) == "number" then
		if attrStock <= 0 then return false, 0 end
		return true, attrStock
	end

	-- 4. Cek label Stock
	local stockLabel = itemFrame:FindFirstChild("Stock", true)
	if stockLabel and stockLabel.Text then
		local txt = stockLabel.Text:lower()
		if txt:find("no stock") or txt:find("out of stock") or txt:find("sold out") or txt:find("habis") then
			return false, 0
		end
		local count = tonumber(txt:match("(%d+)"))
		if count ~= nil then
			if count > 0 then
				return true, count
			else
				return false, 0 -- STOK 0 -> LANGSUNG RETURN FALSE
			end
		end
		if txt:find("in stock") then
			return true, 1
		end
	end

	-- 5. Tombol Buy hanya valid jika frame visible dan bukan out of stock
	local buyBtn = findBuyButton(itemFrame)
	if buyBtn and itemFrame:IsA("GuiObject") and itemFrame.Visible and itemFrame:GetAttribute("OutOfStock") ~= true then
		return true, 1
	end

	return false, 0
end

function AutoBuyGearAndMerchant.HasMerchantStock(itemName)
	-- Pastikan merchant sedang aktif terlebih dahulu
	if not AutoBuyGearAndMerchant.IsMerchantPresent() then
		return false, 0
	end

	local frames = getFramesRoot()
	local merchantShop = frames and frames:FindFirstChild("MerchantShop")
	if not merchantShop or not merchantShop.Visible then
		return false, 0
	end

	local list = merchantShop:FindFirstChild("List")
	if not list then return false, 0 end

	local itemFrame = list:FindFirstChild(itemName)
	if not itemFrame or not itemFrame:IsA("GuiObject") or not itemFrame.Visible then
		return false, 0
	end

	-- 1. Cek attribute OutOfStock
	if itemFrame:GetAttribute("OutOfStock") == true then
		return false, 0
	end

	-- 2. Cek attribute Stock / Count
	local attrStock = itemFrame:GetAttribute("Stock") or itemFrame:GetAttribute("Count")
	if typeof(attrStock) == "number" then
		if attrStock <= 0 then return false, 0 end
		return true, attrStock
	end

	-- 3. Cek label Stock
	local stockLabel = itemFrame:FindFirstChild("Stock", true)
	if stockLabel and stockLabel.Text then
		local txt = stockLabel.Text:lower()
		if txt:find("no stock") or txt:find("out of stock") or txt:find("sold out") or txt:find("habis") then
			return false, 0
		end
		local count = tonumber(txt:match("(%d+)"))
		if count ~= nil then
			if count > 0 then
				return true, count
			else
				return false, 0
			end
		end
		if txt:find("in stock") then
			return true, 1
		end
	end

	return false, 0
end

-- =================================================================
-- 🔍 DYNAMIC SCANNER
-- =================================================================

function AutoBuyGearAndMerchant.ScanGear()
	local gearMap = {}
	local discoveredList = {}

	for _, gear in ipairs(AutoBuyGearAndMerchant.GEAR_CATALOG) do
		local key = gear.name:lower()
		gearMap[key] = {
			name = gear.name,
			rarity = gear.rarity,
			price = gear.price,
			category = "Gear"
		}
		table.insert(discoveredList, gearMap[key])
	end

	pcall(function()
		local frames = getFramesRoot()
		local gearShop = frames and frames:FindFirstChild("GearShop")
		local list = gearShop and gearShop:FindFirstChild("List")

		if list then
			for _, itemFrame in ipairs(list:GetChildren()) do
				if itemFrame:IsA("GuiObject") and itemFrame.Name ~= "" and not itemFrame.Name:find("Layout") then
					local key = itemFrame.Name:lower()
					local rLabel = itemFrame:FindFirstChild("Rarity", true)
					local cLabel = itemFrame:FindFirstChild("Cost", true) or itemFrame:FindFirstChild("Price", true)

					local rName = rLabel and rLabel.Text or "Common"
					local cPrice = cLabel and cLabel.Text or ""
					local oos = (itemFrame:GetAttribute("OutOfStock") == true) or (itemFrame.Visible == false)

					if gearMap[key] then
						gearMap[key].rarity = rName
						gearMap[key].price = cPrice
						gearMap[key].outOfStock = oos
					else
						local entry = {
							name = itemFrame.Name,
							rarity = rName,
							price = cPrice,
							category = "Gear",
							outOfStock = oos,
						}
						gearMap[key] = entry
						table.insert(discoveredList, entry)
					end
				end
			end
		end
	end)

	AutoBuyGearAndMerchant.GEAR_CATALOG = discoveredList
	if AutoBuyGearAndMerchant.OnGearCatalogUpdated then
		pcall(function() AutoBuyGearAndMerchant.OnGearCatalogUpdated(discoveredList) end)
	end
	return discoveredList
end

function AutoBuyGearAndMerchant.ScanMerchant()
	local merchantMap = {}
	local discoveredList = {}

	for _, item in ipairs(AutoBuyGearAndMerchant.MERCHANT_CATALOG) do
		local key = item.name:lower()
		merchantMap[key] = {
			name = item.name,
			rarity = item.rarity,
			price = item.price,
			merchant = item.merchant,
			category = "Merchant"
		}
		table.insert(discoveredList, merchantMap[key])
	end

	pcall(function()
		local frames = getFramesRoot()
		local merchantShop = frames and frames:FindFirstChild("MerchantShop")
		local list = merchantShop and merchantShop:FindFirstChild("List")

		if list then
			for _, itemFrame in ipairs(list:GetChildren()) do
				if itemFrame:IsA("GuiObject") and itemFrame.Name ~= "" and not itemFrame.Name:find("Layout") then
					local key = itemFrame.Name:lower()
					local rLabel = itemFrame:FindFirstChild("Rarity", true)
					local cLabel = itemFrame:FindFirstChild("Cost", true) or itemFrame:FindFirstChild("Price", true)

					local rName = rLabel and rLabel.Text or "Common"
					local cPrice = cLabel and cLabel.Text or ""
					local oos = (itemFrame:GetAttribute("OutOfStock") == true) or (itemFrame.Visible == false)

					if merchantMap[key] then
						merchantMap[key].rarity = rName
						merchantMap[key].price = cPrice
						merchantMap[key].outOfStock = oos
					else
						local entry = {
							name = itemFrame.Name,
							rarity = rName,
							price = cPrice,
							category = "Merchant",
							outOfStock = oos,
						}
						merchantMap[key] = entry
						table.insert(discoveredList, entry)
					end
				end
			end
		end
	end)

	AutoBuyGearAndMerchant.MERCHANT_CATALOG = discoveredList
	if AutoBuyGearAndMerchant.OnMerchantCatalogUpdated then
		pcall(function() AutoBuyGearAndMerchant.OnMerchantCatalogUpdated(discoveredList) end)
	end
	return discoveredList
end

-- =================================================================
-- 🛒 REAL BUY ENGINES (DUAL DISPATCH: REMOTE + UI CLICK)
-- =================================================================

function AutoBuyGearAndMerchant.BuyGear(gearName, forceCount)
	local key = gearName:lower()
	if isDebounced(key) then return false end

	local hasStock, stockCount = AutoBuyGearAndMerchant.HasGearStock(gearName)
	if not hasStock or stockCount <= 0 then return false end

	local targetCount = forceCount or stockCount or 1
	local boughtSuccess = 0

	for i = 1, targetCount do
		local ok = false

		-- 1. Remote BuyItem
		pcall(function()
			if Remotes:FindFirstChild("BuyItem") then
				Remotes.BuyItem:FireServer(gearName)
				ok = true
			end
		end)

		-- 2. Fallback UI Click
		pcall(function()
			local frames = getFramesRoot()
			local gearShop = frames and frames:FindFirstChild("GearShop")
			local list = gearShop and gearShop:FindFirstChild("List")
			local itemFrame = list and list:FindFirstChild(gearName)
			if itemFrame and itemFrame.Visible then
				local btn = findBuyButton(itemFrame)
				if btn then
					clickButton(btn)
					ok = true
				end
			end
		end)

		if ok then boughtSuccess = boughtSuccess + 1 end
		if targetCount > 1 then task.wait(0.08) end
	end

	if boughtSuccess > 0 then
		markBought(key)
		totalGearBought = totalGearBought + boughtSuccess
		print(string.format("⚙️ [Ritod Hub] Membeli Gear: %s (x%d)", gearName, boughtSuccess))
		if AutoBuyGearAndMerchant.OnItemBought then
			pcall(function() AutoBuyGearAndMerchant.OnItemBought("Gear", gearName, boughtSuccess) end)
		end
	end

	return boughtSuccess > 0
end

function AutoBuyGearAndMerchant.BuyMerchantItem(itemName, forceCount)
	local key = itemName:lower()
	if isDebounced(key) then return false end

	local hasStock, stockCount = AutoBuyGearAndMerchant.HasMerchantStock(itemName)
	if not hasStock or stockCount <= 0 then return false end

	local targetCount = forceCount or stockCount or 1
	local boughtSuccess = 0

	for i = 1, targetCount do
		local ok = false

		-- 1. Remote BuyMerchantItem / BuyItem
		pcall(function()
			if Remotes:FindFirstChild("BuyMerchantItem") then
				Remotes.BuyMerchantItem:FireServer(itemName)
				ok = true
			elseif Remotes:FindFirstChild("BuyItem") then
				Remotes.BuyItem:FireServer(itemName)
				ok = true
			end
		end)

		-- 2. Direct UI Button Clicker
		pcall(function()
			local frames = getFramesRoot()
			local merchantShop = frames and frames:FindFirstChild("MerchantShop")
			local list = merchantShop and merchantShop:FindFirstChild("List")
			local itemFrame = list and list:FindFirstChild(itemName)
			if itemFrame and itemFrame.Visible then
				local btn = findBuyButton(itemFrame)
				if btn then
					clickButton(btn)
					ok = true
				end
			end
		end)

		if ok then boughtSuccess = boughtSuccess + 1 end
		if targetCount > 1 then task.wait(0.08) end
	end

	if boughtSuccess > 0 then
		markBought(key)
		totalMerchantBought = totalMerchantBought + boughtSuccess
		print(string.format("🏪 [Ritod Hub] Membeli Merchant Item: %s (x%d)", itemName, boughtSuccess))
		if AutoBuyGearAndMerchant.OnItemBought then
			pcall(function() AutoBuyGearAndMerchant.OnItemBought("Merchant", itemName, boughtSuccess) end)
		end
	end

	return boughtSuccess > 0
end

-- =================================================================
-- 🔄 SINGLE CYCLE RUNNERS
-- =================================================================

function AutoBuyGearAndMerchant.RunGearCycle()
	local cfg = AutoBuyGearAndMerchant.Config
	local selected = cfg.SelectedGear or {}

	for _, gear in ipairs(AutoBuyGearAndMerchant.GEAR_CATALOG) do
		local key = gear.name:lower()
		local shouldBuy = cfg.BuyAllGear or (selected[key] == true) or (selected[gear.name] == true)

		if shouldBuy then
			local hasStock, count = AutoBuyGearAndMerchant.HasGearStock(gear.name)
			if hasStock and count > 0 then
				AutoBuyGearAndMerchant.BuyGear(gear.name, count)
			end
		end
	end
end

function AutoBuyGearAndMerchant.RunMerchantCycle()
	-- Pastikan merchant sedang aktif sebelum menjalankan pengecekan
	if not AutoBuyGearAndMerchant.IsMerchantPresent() then
		return
	end

	local cfg = AutoBuyGearAndMerchant.Config
	local selected = cfg.SelectedMerchant or {}
	local groups = cfg.MerchantGroups or {}

	for _, item in ipairs(AutoBuyGearAndMerchant.MERCHANT_CATALOG) do
		local key = item.name:lower()
		local shouldBuy = cfg.BuyAllMerchant or (selected[key] == true) or (selected[item.name] == true)

		if not shouldBuy and item.merchant and groups[item.merchant] == true then
			shouldBuy = true
		end

		if shouldBuy then
			local hasStock, count = AutoBuyGearAndMerchant.HasMerchantStock(item.name)
			if hasStock and count > 0 then
				AutoBuyGearAndMerchant.BuyMerchantItem(item.name, count)
			end
		end
	end
end

-- =================================================================
-- 📡 EVENT LISTENERS
-- =================================================================

local function setupStockListeners()
	for _, conn in ipairs(stockConnections) do
		if conn and conn.Disconnect then conn:Disconnect() end
	end
	table.clear(stockConnections)

	pcall(function()
		local frames = getFramesRoot()
		if not frames then return end

		-- Gear Shop UI Listeners
		local gearShop = frames:FindFirstChild("GearShop")
		local gearList = gearShop and gearShop:FindFirstChild("List")
		if gearList then
			for _, itemFrame in ipairs(gearList:GetChildren()) do
				if itemFrame:IsA("GuiObject") then
					local stockLbl = itemFrame:FindFirstChild("Stock", true)
					if stockLbl and stockLbl:IsA("TextLabel") then
						local c = stockLbl:GetPropertyChangedSignal("Text"):Connect(function()
							if isGearRunning then AutoBuyGearAndMerchant.RunGearCycle() end
						end)
						table.insert(stockConnections, c)
					end

					local cAttr = itemFrame:GetAttributeChangedSignal("OutOfStock"):Connect(function()
						if isGearRunning and itemFrame:GetAttribute("OutOfStock") == false then
							AutoBuyGearAndMerchant.RunGearCycle()
						end
					end)
					table.insert(stockConnections, cAttr)
				end
			end
		end

		-- Merchant Shop UI Listeners
		local merchantShop = frames:FindFirstChild("MerchantShop")
		local merchantList = merchantShop and merchantShop:FindFirstChild("List")
		if merchantList then
			for _, itemFrame in ipairs(merchantList:GetChildren()) do
				if itemFrame:IsA("GuiObject") then
					local stockLbl = itemFrame:FindFirstChild("Stock", true)
					if stockLbl and stockLbl:IsA("TextLabel") then
						local c = stockLbl:GetPropertyChangedSignal("Text"):Connect(function()
							if isMerchantRunning then AutoBuyGearAndMerchant.RunMerchantCycle() end
						end)
						table.insert(stockConnections, c)
					end

					local cAttr = itemFrame:GetAttributeChangedSignal("OutOfStock"):Connect(function()
						if isMerchantRunning and itemFrame:GetAttribute("OutOfStock") == false then
							AutoBuyGearAndMerchant.RunMerchantCycle()
						end
					end)
					table.insert(stockConnections, cAttr)
				end
			end
		end
	end)
end

local function setupRemoteListeners()
	for _, conn in ipairs(remoteConnections) do
		if conn and conn.Disconnect then conn:Disconnect() end
	end
	table.clear(remoteConnections)

	pcall(function()
		if Remotes:FindFirstChild("UpdateTravelingMerchantStock") then
			local c = Remotes.UpdateTravelingMerchantStock.OnClientEvent:Connect(function(merchantName)
				if isMerchantRunning then
					print("🏪 [Ritod Hub] Traveling Merchant Restock/Spawn Event! (" .. tostring(merchantName) .. ")")
					task.wait(0.3)
					AutoBuyGearAndMerchant.ScanMerchant()
					AutoBuyGearAndMerchant.RunMerchantCycle()
				end
			end)
			table.insert(remoteConnections, c)
		end

		if Remotes:FindFirstChild("UpdateMerchantPersonalStock") then
			local c = Remotes.UpdateMerchantPersonalStock.OnClientEvent:Connect(function()
				if isMerchantRunning then
					task.wait(0.2)
					AutoBuyGearAndMerchant.ScanMerchant()
					AutoBuyGearAndMerchant.RunMerchantCycle()
				end
			end)
			table.insert(remoteConnections, c)
		end
	end)
end

-- =================================================================
-- 🚀 GEAR CONTROL: START / STOP / TOGGLE
-- =================================================================

function AutoBuyGearAndMerchant.StartGear()
	if isGearRunning then return end
	isGearRunning = true
	AutoBuyGearAndMerchant.Config.GearEnabled = true

	AutoBuyGearAndMerchant.ScanGear()
	setupStockListeners()
	print("⚙️ [Ritod Hub] Auto Buy Gear: AKTIF")

	if gearThread then task.cancel(gearThread); gearThread = nil end
	gearThread = task.spawn(function()
		while isGearRunning do
			pcall(function() AutoBuyGearAndMerchant.RunGearCycle() end)
			task.wait(AutoBuyGearAndMerchant.Config.GearCheckInterval or 1.0)
		end
	end)
end

function AutoBuyGearAndMerchant.StopGear()
	isGearRunning = false
	AutoBuyGearAndMerchant.Config.GearEnabled = false
	if gearThread then task.cancel(gearThread); gearThread = nil end
	print("🛑 [Ritod Hub] Auto Buy Gear: DIMATIKAN")
end

function AutoBuyGearAndMerchant.ToggleGear(state)
	if state == nil then state = not isGearRunning end
	if state then AutoBuyGearAndMerchant.StartGear() else AutoBuyGearAndMerchant.StopGear() end
	return isGearRunning
end

-- =================================================================
-- 🚀 MERCHANT CONTROL: START / STOP / TOGGLE
-- =================================================================

function AutoBuyGearAndMerchant.StartMerchant()
	if isMerchantRunning then return end
	isMerchantRunning = true
	AutoBuyGearAndMerchant.Config.MerchantEnabled = true

	pcall(function()
		if Remotes:FindFirstChild("RequestMerchantStock") then
			Remotes.RequestMerchantStock:InvokeServer()
		end
	end)

	AutoBuyGearAndMerchant.ScanMerchant()
	setupStockListeners()
	setupRemoteListeners()
	print("🏪 [Ritod Hub] Auto Buy Traveling Merchants: AKTIF")

	if merchantThread then task.cancel(merchantThread); merchantThread = nil end
	merchantThread = task.spawn(function()
		while isMerchantRunning do
			pcall(function() AutoBuyGearAndMerchant.RunMerchantCycle() end)
			task.wait(AutoBuyGearAndMerchant.Config.MerchantCheckInterval or 1.0)
		end
	end)
end

function AutoBuyGearAndMerchant.StopMerchant()
	isMerchantRunning = false
	AutoBuyGearAndMerchant.Config.MerchantEnabled = false

	for _, conn in ipairs(remoteConnections) do
		if conn and conn.Disconnect then conn:Disconnect() end
	end
	table.clear(remoteConnections)

	if merchantThread then task.cancel(merchantThread); merchantThread = nil end
	print("🛑 [Ritod Hub] Auto Buy Traveling Merchants: DIMATIKAN")
end

function AutoBuyGearAndMerchant.ToggleMerchant(state)
	if state == nil then state = not isMerchantRunning end
	if state then AutoBuyGearAndMerchant.StartMerchant() else AutoBuyGearAndMerchant.StopMerchant() end
	return isMerchantRunning
end

-- =================================================================
-- 🚀 UNIFIED SHOP CONTROL: START / STOP / TOGGLE (GEAR + MERCHANT)
-- =================================================================

function AutoBuyGearAndMerchant.Start()
	AutoBuyGearAndMerchant.Config.BuyAllGear = true
	AutoBuyGearAndMerchant.Config.BuyAllMerchant = true
	AutoBuyGearAndMerchant.StartGear()
	AutoBuyGearAndMerchant.StartMerchant()
end

function AutoBuyGearAndMerchant.Stop()
	AutoBuyGearAndMerchant.StopGear()
	AutoBuyGearAndMerchant.StopMerchant()
end

function AutoBuyGearAndMerchant.Toggle(state)
	if state == nil then state = not (isGearRunning or isMerchantRunning) end
	if state then AutoBuyGearAndMerchant.Start() else AutoBuyGearAndMerchant.Stop() end
	return isGearRunning or isMerchantRunning
end

-- =================================================================
-- 🔧 CONFIG UTILITIES
-- =================================================================

function AutoBuyGearAndMerchant.SelectGear(gearName, enabled)
	AutoBuyGearAndMerchant.Config.SelectedGear[gearName:lower()] = (enabled ~= false)
end

function AutoBuyGearAndMerchant.SelectMerchantItem(itemName, enabled)
	AutoBuyGearAndMerchant.Config.SelectedMerchant[itemName:lower()] = (enabled ~= false)
end

function AutoBuyGearAndMerchant.SelectMerchantGroup(merchantName, enabled)
	AutoBuyGearAndMerchant.Config.MerchantGroups[merchantName] = (enabled ~= false)
	local mData = AutoBuyGearAndMerchant.MERCHANTS[merchantName]
	if mData then
		for _, item in ipairs(mData.items) do
			AutoBuyGearAndMerchant.Config.SelectedMerchant[item.name:lower()] = (enabled ~= false)
		end
	end
end

function AutoBuyGearAndMerchant.SelectAllGear(enabled)
	AutoBuyGearAndMerchant.Config.BuyAllGear = (enabled ~= false)
	for _, gear in ipairs(AutoBuyGearAndMerchant.GEAR_CATALOG) do
		AutoBuyGearAndMerchant.Config.SelectedGear[gear.name:lower()] = (enabled ~= false)
	end
end

function AutoBuyGearAndMerchant.SelectAllMerchant(enabled)
	AutoBuyGearAndMerchant.Config.BuyAllMerchant = (enabled ~= false)
	for _, item in ipairs(AutoBuyGearAndMerchant.MERCHANT_CATALOG) do
		AutoBuyGearAndMerchant.Config.SelectedMerchant[item.name:lower()] = (enabled ~= false)
	end
	for mName in pairs(AutoBuyGearAndMerchant.MERCHANTS) do
		AutoBuyGearAndMerchant.Config.MerchantGroups[mName] = (enabled ~= false)
	end
end

function AutoBuyGearAndMerchant.ResetCooldowns()
	lastBuyTime = {}
	print("🔄 [Ritod Hub] Cooldowns reset.")
end

function AutoBuyGearAndMerchant.GetStats()
	return {
		GearBought        = totalGearBought,
		MerchantBought    = totalMerchantBought,
		IsGearRunning     = isGearRunning,
		IsMerchantRunning = isMerchantRunning,
	}
end

function AutoBuyGearAndMerchant.IsGearRunning() return isGearRunning end
function AutoBuyGearAndMerchant.IsMerchantRunning() return isMerchantRunning end

_G.AutoBuyGearAndMerchant = AutoBuyGearAndMerchant
_G.AutoBuyGear = AutoBuyGearAndMerchant

return AutoBuyGearAndMerchant
