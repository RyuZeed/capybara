--[[
	===============================================================
	⚡ RITOD HUB - AUTO BUY MERCHANT ENGINE (TRADER EVENT V1.0)
	Game: Roll Anime For Fight / Anime Auto Roll
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- 🛒 INSTANT AUTO BUY TRADER/MERCHANT STOCK:
	  • Memantau atribut 'TraderEventActive' & 'TraderEventEndsAt' secara real-time.
	  • Auto-snipe stok saat Merchant spawn/tiba di map tanpa delay.
	  • Dual-Engine Purchase: Direct Remote invocation + Hardware/Event UI Dispatcher.
	- 📦 KATEGORI & FILTER ITEM LENGKAP:
	  • Potions (Super Time, Time, Super Gold, Gold, Super Luck, Luck)
	  • Essences (Supreme, God, Secret, Mythic, Legendary, Epic, Rare, Common)
	  • Capsules (God, Secret, Mythic)
	  • Tickets (Infinite Ticket, Trading Ticket)
	  • Rare Materials (Six Eyes, God's Eye, Sukuna's Fragment, Cursed Finger, Nuclear Core, dll.)
	- 💰 GOLD RESERVE & SMART BUDGET GUARD:
	  • Mengecek ketersediaan Gold sebelum membeli item.
	  • Mencegah saldo terkuras habis dengan opsi minimum gold reserve.
	- 🛡️ ZERO-SPAM & CLEAN LIFECYCLE:
	  • Membeli sesuai kuantitas stok hingga item berstatus Sold Out.
	  • Thread terisolasi dengan auto-cleanup saat script di-reload.
	===============================================================
]]

local AutoMerchant = {}
_G.AutoMerchant = AutoMerchant
_G.AutoMerchantModule = AutoMerchant

-- 🔇 SILENT MODE (Zero terminal/console spam)
local print = function(...) end
local warn = function(...) end

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local VirtualUser         = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

-- =================================================================
-- 📋 DATABASE ITEM TRADER & HARGA LENGKAP
-- =================================================================
AutoMerchant.ItemsCatalog = {
	-- 💊 Potions
	["Super Time Potion"]   = { Category = "Potions",   Rarity = "Secret",    Price = 1000000,  DisplayName = "Super Time Potion" },
	["Time Potion"]         = { Category = "Potions",   Rarity = "Secret",    Price = 250000,   DisplayName = "Time Potion" },
	["Super Gold Potion"]   = { Category = "Potions",   Rarity = "Mythic",    Price = 500000,   DisplayName = "Super Gold Potion" },
	["Gold Potion"]         = { Category = "Potions",   Rarity = "Mythic",    Price = 100000,   DisplayName = "Gold Potion" },
	["Super Luck Potion"]   = { Category = "Potions",   Rarity = "Mythic",    Price = 500000,   DisplayName = "Super Luck Potion" },
	["Luck Potion"]         = { Category = "Potions",   Rarity = "Mythic",    Price = 100000,   DisplayName = "Luck Potion" },

	-- ✨ Essences
	["Supreme Essence"]     = { Category = "Essences",  Rarity = "Supreme",   Price = 10000000, DisplayName = "Supreme Essence" },
	["God Essence"]         = { Category = "Essences",  Rarity = "God",       Price = 5000000,  DisplayName = "God Essence" },
	["Secret Essence"]      = { Category = "Essences",  Rarity = "Secret",    Price = 2500000,  DisplayName = "Secret Essence" },
	["Mythic Essence"]      = { Category = "Essences",  Rarity = "Mythic",    Price = 750000,   DisplayName = "Mythic Essence" },
	["Legendary Essence"]   = { Category = "Essences",  Rarity = "Legendary", Price = 250000,   DisplayName = "Legendary Essence" },
	["Epic Essence"]        = { Category = "Essences",  Rarity = "Epic",      Price = 100000,   DisplayName = "Epic Essence" },
	["Rare Essence"]        = { Category = "Essences",  Rarity = "Rare",      Price = 50000,    DisplayName = "Rare Essence" },
	["Common Essence"]      = { Category = "Essences",  Rarity = "Common",    Price = 25000,    DisplayName = "Common Essence" },

	-- 📦 Capsules
	["God Capsule"]         = { Category = "Capsules",  Rarity = "God",       Price = 10000000, DisplayName = "God Capsule" },
	["Secret Capsule"]      = { Category = "Capsules",  Rarity = "Secret",    Price = 5000000,  DisplayName = "Secret Capsule" },
	["Mythic Capsule"]      = { Category = "Capsules",  Rarity = "Mythic",    Price = 1000000,  DisplayName = "Mythic Capsule" },

	-- 📜 Tickets
	["Infinite Ticket"]     = { Category = "Tickets",   Rarity = "Legendary", Price = 375000,   DisplayName = "Infinite Ticket" },
	["Trading Ticket"]      = { Category = "Tickets",   Rarity = "Legendary", Price = 375000,   DisplayName = "Trading Ticket" },

	-- 💎 Rare Materials
	["Setzu's Husk"]        = { Category = "Materials", Rarity = "Supreme",   Price = 10000000, DisplayName = "Setzu's Husk" },
	["Nuclear Core"]        = { Category = "Materials", Rarity = "Supreme",   Price = 10000000, DisplayName = "Nuclear Core" },
	["God's Eye"]           = { Category = "Materials", Rarity = "God",       Price = 5000000,  DisplayName = "God's Eye" },
	["Truth Orb"]           = { Category = "Materials", Rarity = "God",       Price = 5000000,  DisplayName = "Truth Orb" },
	["Six Eyes"]            = { Category = "Materials", Rarity = "God",       Price = 3000000,  DisplayName = "Six Eyes" },
	["Sakuna's Fragment"]   = { Category = "Materials", Rarity = "God",       Price = 3000000,  DisplayName = "Sakuna's Fragment" },
	["Cursed Finger"]       = { Category = "Materials", Rarity = "God",       Price = 3000000,  DisplayName = "Cursed Finger" },
	["Cursed Womb"]         = { Category = "Materials", Rarity = "God",       Price = 3000000,  DisplayName = "Cursed Womb" },
	["Tailed Chakra"]       = { Category = "Materials", Rarity = "God",       Price = 3000000,  DisplayName = "Tailed Chakra" },
	["S-Rank Badge"]        = { Category = "Materials", Rarity = "God",       Price = 2500000,  DisplayName = "S-Rank Badge" },
	["Byakugou Seal"]       = { Category = "Materials", Rarity = "Secret",    Price = 2500000,  DisplayName = "Byakugou Seal" },
	["Ice Dagger"]          = { Category = "Materials", Rarity = "Secret",    Price = 2500000,  DisplayName = "Ice Dagger" },
	["Trait Shard"]         = { Category = "Materials", Rarity = "Mythic",    Price = 75000,    DisplayName = "Trait Shard" },
}

-- =================================================================
-- ⚙️ CONFIGURATION STATE
-- =================================================================
AutoMerchant.Config = {
	Enabled         = false,
	BuyAllStock     = false, -- Beli seluruh stok item apa saja yang tersedia
	BuyPotions      = true,  -- Auto buy semua jenis Potion
	BuyEssences     = true,  -- Auto buy semua jenis Essence
	BuyCapsules     = true,  -- Auto buy semua jenis Capsule
	BuyTickets      = true,  -- Auto buy semua jenis Ticket
	BuyMaterials    = true,  -- Auto buy semua Rare Material
	SelectedItems   = {},    -- Custom Whitelist per-item nama [ "Super Time Potion" ] = true
	MinGoldReserve  = 0,     -- Batas minimum sisa gold
	CheckInterval   = 3,     -- Interval pengecekan saat merchant idle
	ActiveInterval  = 0.8,   -- Interval pengecekan saat merchant aktif
}

local isRunning = false
local loopThread = nil
local eventConn = nil
local lastBuyTick = {}

-- =================================================================
-- 🛠️ UTILITY: GET GOLD & PLAYER INFO
-- =================================================================
function AutoMerchant.GetGold()
	if not LocalPlayer then return 0 end
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	if ls then
		for _, c in ipairs(ls:GetChildren()) do
			if c.Name:find("Gold") or c.Name:find("💰") then
				return tonumber(c.Value) or 0
			end
		end
	end
	return 0
end

function AutoMerchant.IsMerchantActive()
	local active = Workspace:GetAttribute("TraderEventActive")
	if active == true then return true end
	
	-- Fallback: Cek apakah UI merchant memiliki item aktif
	pcall(function()
		local pGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
		if pGui and pGui:FindFirstChild("MainUI") and pGui.MainUI:FindFirstChild("Frames") then
			local tFrame = pGui.MainUI.Frames:FindFirstChild("Trader (Merchant)")
			if tFrame and tFrame:FindFirstChild("Frame") and tFrame.Frame:FindFirstChild("Frames") and tFrame.Frame.Frames:FindFirstChild("Main") then
				for _, c in ipairs(tFrame.Frame.Frames.Main:GetChildren()) do
					if c:IsA("Frame") and c.Name ~= "Template" and c.Name ~= "Configuration" then
						active = true
						break
					end
				end
			end
		end
	end)
	
	return active == true
end

function AutoMerchant.GetMerchantRemainingTime()
	local endsAt = Workspace:GetAttribute("TraderEventEndsAt")
	if typeof(endsAt) == "number" and endsAt > 0 then
		local now = Workspace:GetServerTimeNow()
		return math.max(0, math.floor(endsAt - now))
	end
	return 0
end

-- =================================================================
-- 🔍 FILTER CEK APAKAH ITEM HARUS DIBELI
-- =================================================================
function AutoMerchant.ShouldBuyItem(itemName)
	if not itemName or #itemName == 0 then return false end
	
	-- 1. Jika mode Beli Semua aktif
	if AutoMerchant.Config.BuyAllStock then
		return true
	end
	
	-- 2. Jika item dicentang di whitelist individual
	if AutoMerchant.Config.SelectedItems and AutoMerchant.Config.SelectedItems[itemName] == true then
		return true
	end
	
	-- 3. Cek berdasarkan kategori
	local info = AutoMerchant.ItemsCatalog[itemName]
	if info then
		if info.Category == "Potions" and AutoMerchant.Config.BuyPotions then return true end
		if info.Category == "Essences" and AutoMerchant.Config.BuyEssences then return true end
		if info.Category == "Capsules" and AutoMerchant.Config.BuyCapsules then return true end
		if info.Category == "Tickets" and AutoMerchant.Config.BuyTickets then return true end
		if info.Category == "Materials" and AutoMerchant.Config.BuyMaterials then return true end
	end
	
	return false
end

-- =================================================================
-- 🖱️ MULTI-VECTOR BUTTON CLICK (FALLBACK)
-- =================================================================
local function clickBuyButton(btn)
	if not btn or not btn:IsA("GuiObject") then return end

	if typeof(firesignal) == "function" then
		if btn:IsA("GuiButton") then
			if btn.Activated then pcall(function() firesignal(btn.Activated) end) end
			if btn.MouseButton1Click then pcall(function() firesignal(btn.MouseButton1Click) end) end
		end
	end

	if typeof(getconnections) == "function" then
		for _, evName in ipairs({"Activated", "MouseButton1Click"}) do
			pcall(function()
				if btn[evName] then
					for _, conn in ipairs(getconnections(btn[evName])) do
						if conn.Function then
							conn.Function()
						elseif conn.Fire then
							conn:Fire()
						end
					end
				end
			end)
		end
	end

	pcall(function()
		local pos = btn.AbsolutePosition
		local size = btn.AbsoluteSize
		if size.X > 0 and size.Y > 0 and VirtualInputManager then
			local cx = math.floor(pos.X + size.X / 2)
			local cy = math.floor(pos.Y + size.Y / 2)
			pcall(function()
				VirtualInputManager:SendTouchEvent(1, 0, cx, cy)
				task.wait(0.01)
				VirtualInputManager:SendTouchEvent(1, 2, cx, cy)
			end)
		end
	end)
end

-- =================================================================
-- 🛒 CORE EXECUTE PURCHASE
-- =================================================================
function AutoMerchant.PurchaseItem(itemName, count)
	count = count or 1
	if not itemName then return end
	
	local currentGold = AutoMerchant.GetGold()
	local minGold = AutoMerchant.Config.MinGoldReserve or 0
	local itemInfo = AutoMerchant.ItemsCatalog[itemName]
	local price = itemInfo and itemInfo.Price or 0
	
	local buyRemote = nil
	pcall(function()
		buyRemote = ReplicatedStorage.Remotes.Trader.Buy
	end)
	
	for i = 1, count do
		if currentGold - price < minGold and price > 0 then
			break
		end
		
		-- 1. Direct Remote Call
		if buyRemote and typeof(buyRemote.FireServer) == "function" then
			pcall(function()
				buyRemote:FireServer(itemName)
			end)
		end
		
		-- 2. UI Fallback Trigger jika frame tersedia
		pcall(function()
			local pGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
			if pGui and pGui:FindFirstChild("MainUI") and pGui.MainUI:FindFirstChild("Frames") then
				local tFrame = pGui.MainUI.Frames:FindFirstChild("Trader (Merchant)")
				if tFrame and tFrame:FindFirstChild("Frame") and tFrame.Frame:FindFirstChild("Frames") and tFrame.Frame.Frames:FindFirstChild("Main") then
					local itemFrame = tFrame.Frame.Frames.Main:FindFirstChild(itemName)
					if itemFrame and itemFrame:FindFirstChild("Inner3") and itemFrame.Inner3:FindFirstChild("Start") and itemFrame.Inner3.Start:FindFirstChild("Start") then
						clickBuyButton(itemFrame.Inner3.Start.Start)
					end
				end
			end
		end)
		
		task.wait(0.06)
		currentGold = AutoMerchant.GetGold()
	end
end

-- =================================================================
-- ⚡ SCAN & BUY CURRENT MERCHANT STOCK
-- =================================================================
function AutoMerchant.ScanAndBuyAllStock()
	if not AutoMerchant.IsMerchantActive() then return end
	
	local pGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	if not pGui or not pGui:FindFirstChild("MainUI") or not pGui.MainUI:FindFirstChild("Frames") then return end
	
	local tFrame = pGui.MainUI.Frames:FindFirstChild("Trader (Merchant)")
	if not tFrame or not tFrame:FindFirstChild("Frame") or not tFrame.Frame:FindFirstChild("Frames") or not tFrame.Frame.Frames:FindFirstChild("Main") then return end
	
	local mainFrame = tFrame.Frame.Frames.Main
	local itemsFound = 0
	
	for _, itemFrame in ipairs(mainFrame:GetChildren()) do
		if itemFrame:IsA("Frame") and itemFrame.Name ~= "Template" and itemFrame.Name ~= "Configuration" then
			local itemName = itemFrame.Name
			local stockRemaining = 1
			local isSoldOut = false
			
			pcall(function()
				if itemFrame:FindFirstChild("Inner3") then
					local inner3 = itemFrame.Inner3
					if inner3:FindFirstChild("ItemName") and inner3.ItemName.Text ~= "" then
						itemName = inner3.ItemName.Text
					end
					
					-- Cek teks tombol apakah Sold Out
					if inner3:FindFirstChild("Start") and inner3.Start:FindFirstChild("Frame") and inner3.Start.Frame:FindFirstChild("TextLabel") then
						local btnText = inner3.Start.Frame.TextLabel.Text:upper()
						if btnText:find("SOLD") or btnText:find("OUT") or btnText:find("HABIS") then
							isSoldOut = true
						end
					end
					
					-- Parse kuantitas stok (contoh: "2/2" -> 2)
					if inner3:FindFirstChild("StockNumber") then
						local sText = inner3.StockNumber.Text
						local current, max = sText:match("(%d+)/(%d+)")
						if current and tonumber(current) then
							stockRemaining = tonumber(current)
							if stockRemaining <= 0 then
								isSoldOut = true
							end
						end
					end
				end
			end)
			
			if not isSoldOut and AutoMerchant.ShouldBuyItem(itemName) then
				itemsFound = itemsFound + 1
				AutoMerchant.PurchaseItem(itemName, stockRemaining)
			end
		end
	end
	
	-- Fallback jika UI belum ter-render tapi GetStock remote tersedia
	if itemsFound == 0 then
		pcall(function()
			local getStockRemote = ReplicatedStorage.Remotes.Trader.GetStock
			local stockData = getStockRemote:InvokeServer()
			if stockData and typeof(stockData) == "table" and stockData.Items and typeof(stockData.Items) == "table" then
				for _, itm in ipairs(stockData.Items) do
					local iName = typeof(itm) == "table" and (itm.Name or itm.Item or itm.ItemName) or tostring(itm)
					local count = (typeof(itm) == "table" and tonumber(itm.Amount or itm.Stock)) or 1
					if AutoMerchant.ShouldBuyItem(iName) then
						AutoMerchant.PurchaseItem(iName, count)
					end
				end
			end
		end)
	end
end

-- =================================================================
-- 🔄 BACKGROUND ENGINE DAEMON
-- =================================================================
function AutoMerchant.Start(customConfig)
	if isRunning then
		if customConfig and type(customConfig) == "table" then
			for k, v in pairs(customConfig) do AutoMerchant.Config[k] = v end
		end
		return
	end
	
	isRunning = true
	AutoMerchant.Config.Enabled = true
	
	if customConfig and type(customConfig) == "table" then
		for k, v in pairs(customConfig) do AutoMerchant.Config[k] = v end
	end
	
	-- 1. Sambungkan sinyal atribut TraderEventActive untuk respon instan
	pcall(function()
		if eventConn then eventConn:Disconnect() end
		eventConn = Workspace:GetAttributeChangedSignal("TraderEventActive"):Connect(function()
			if not isRunning or not AutoMerchant.Config.Enabled then return end
			if Workspace:GetAttribute("TraderEventActive") == true then
				task.wait(0.3) -- Berikan jeda frame agar UI tereplikasi
				AutoMerchant.ScanAndBuyAllStock()
			end
		end)
	end)
	
	-- 2. Daemon Polling Loop
	if loopThread then pcall(function() task.cancel(loopThread) end) end
	loopThread = task.spawn(function()
		while isRunning and AutoMerchant.Config.Enabled do
			pcall(function()
				if AutoMerchant.IsMerchantActive() then
					AutoMerchant.ScanAndBuyAllStock()
					task.wait(AutoMerchant.Config.ActiveInterval or 1)
				else
					task.wait(AutoMerchant.Config.CheckInterval or 3)
				end
			end)
		end
		isRunning = false
	end)
end

function AutoMerchant.Stop()
	isRunning = false
	AutoMerchant.Config.Enabled = false
	
	if eventConn then
		pcall(function() eventConn:Disconnect() end)
		eventConn = nil
	end
	if loopThread then
		pcall(function() task.cancel(loopThread) end)
		loopThread = nil
	end
end

function AutoMerchant.IsRunning()
	return isRunning
end

return AutoMerchant
