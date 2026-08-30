--[[
	===============================================================
	⚡ RITOD HUB - AUTO BUY MERCHANT ENGINE (TRADER EVENT V2.0 ULTRA)
	Game: Roll Anime For Fight / Anime Auto Roll
	GitHub: https://github.com/RyuZeed/capybara
	===============================================================
	🎯 FEATURES:
	- 🛒 100% UNSTOPPABLE AUTO-BUY (EVENT EVERY 20 MINUTES):
	  • Memantau atribut 'TraderEventActive', 'TraderEventId', dan 'TraderEventEndsAt'.
	  • Otomatis mendeteksi NPC 'TraderChar' / 'TraderPlatform' di Workspace.
	  • Polling berkala via GetStock RemoteFunction & UI Frame Reader.
	- ⚡ ZERO-MISS RAPID SNIPER:
	  • Direct Remote Call: ReplicatedStorage.Remotes.Trader.Buy:FireServer(itemName).
	  • Hardware / Event Click Dispatcher ke tombol UI.
	  • Auto-Trigger ProximityPrompt NPC Trader jika berada di map.
	- 📦 KATEGORI & FILTER LENGKAP:
	  • Potions, Essences, Capsules, Tickets, Rare Materials.
	- 💰 SMART GOLD GUARD:
	  • Cek saldo gold sebelum transaksi + opsi sisa cadangan minimum.
	===============================================================
]]

local AutoMerchant = {}
_G.AutoMerchant = AutoMerchant
_G.AutoMerchantModule = AutoMerchant

-- 🔇 SILENT MODE (Zero console spam)
local print = function(...) end
local warn = function(...) end

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer or (function() local t = tick() while not Players.LocalPlayer and (tick() - t) < 3 do task.wait(0.05) end return Players.LocalPlayer end)()

-- =================================================================
-- 📋 DATABASE ITEM TRADER & HARGA LENGKAP
-- =================================================================
AutoMerchant.ItemsCatalog = {
	-- 💊 Potions
	["Super Time Potion"]   = { Category = "Potions",   Rarity = "Secret",    Price = 1000000,  MaxStock = 2, DisplayName = "Super Time Potion" },
	["Time Potion"]         = { Category = "Potions",   Rarity = "Secret",    Price = 250000,   MaxStock = 2, DisplayName = "Time Potion" },
	["Super Gold Potion"]   = { Category = "Potions",   Rarity = "Mythic",    Price = 500000,   MaxStock = 5, DisplayName = "Super Gold Potion" },
	["Gold Potion"]         = { Category = "Potions",   Rarity = "Mythic",    Price = 100000,   MaxStock = 5, DisplayName = "Gold Potion" },
	["Super Luck Potion"]   = { Category = "Potions",   Rarity = "Mythic",    Price = 500000,   MaxStock = 5, DisplayName = "Super Luck Potion" },
	["Luck Potion"]         = { Category = "Potions",   Rarity = "Mythic",    Price = 100000,   MaxStock = 5, DisplayName = "Luck Potion" },

	-- ✨ Essences
	["Supreme Essence"]     = { Category = "Essences",  Rarity = "Supreme",   Price = 10000000, MaxStock = 1, DisplayName = "Supreme Essence" },
	["God Essence"]         = { Category = "Essences",  Rarity = "God",       Price = 5000000,  MaxStock = 2, DisplayName = "God Essence" },
	["Secret Essence"]      = { Category = "Essences",  Rarity = "Secret",    Price = 2500000,  MaxStock = 3, DisplayName = "Secret Essence" },
	["Mythic Essence"]      = { Category = "Essences",  Rarity = "Mythic",    Price = 750000,   MaxStock = 5, DisplayName = "Mythic Essence" },
	["Legendary Essence"]   = { Category = "Essences",  Rarity = "Legendary", Price = 250000,   MaxStock = 5, DisplayName = "Legendary Essence" },
	["Epic Essence"]        = { Category = "Essences",  Rarity = "Epic",      Price = 100000,   MaxStock = 5, DisplayName = "Epic Essence" },
	["Rare Essence"]        = { Category = "Essences",  Rarity = "Rare",      Price = 50000,    MaxStock = 5, DisplayName = "Rare Essence" },
	["Common Essence"]      = { Category = "Essences",  Rarity = "Common",    Price = 25000,    MaxStock = 5, DisplayName = "Common Essence" },

	-- 📦 Capsules
	["God Capsule"]         = { Category = "Capsules",  Rarity = "God",       Price = 10000000, MaxStock = 1, DisplayName = "God Capsule" },
	["Secret Capsule"]      = { Category = "Capsules",  Rarity = "Secret",    Price = 5000000,  MaxStock = 2, DisplayName = "Secret Capsule" },
	["Mythic Capsule"]      = { Category = "Capsules",  Rarity = "Mythic",    Price = 1000000,  MaxStock = 3, DisplayName = "Mythic Capsule" },

	-- 📜 Tickets
	["Infinite Ticket"]     = { Category = "Tickets",   Rarity = "Legendary", Price = 375000,   MaxStock = 2, DisplayName = "Infinite Ticket" },
	["Trading Ticket"]      = { Category = "Tickets",   Rarity = "Legendary", Price = 375000,   MaxStock = 1, DisplayName = "Trading Ticket" },

	-- 💎 Rare Materials
	["Setzu's Husk"]        = { Category = "Materials", Rarity = "Supreme",   Price = 10000000, MaxStock = 1, DisplayName = "Setzu's Husk" },
	["Nuclear Core"]        = { Category = "Materials", Rarity = "Supreme",   Price = 10000000, MaxStock = 1, DisplayName = "Nuclear Core" },
	["God's Eye"]           = { Category = "Materials", Rarity = "God",       Price = 5000000,  MaxStock = 2, DisplayName = "God's Eye" },
	["Truth Orb"]           = { Category = "Materials", Rarity = "God",       Price = 5000000,  MaxStock = 2, DisplayName = "Truth Orb" },
	["Six Eyes"]            = { Category = "Materials", Rarity = "God",       Price = 3000000,  MaxStock = 2, DisplayName = "Six Eyes" },
	["Sakuna's Fragment"]   = { Category = "Materials", Rarity = "God",       Price = 3000000,  MaxStock = 2, DisplayName = "Sakuna's Fragment" },
	["Cursed Finger"]       = { Category = "Materials", Rarity = "God",       Price = 3000000,  MaxStock = 2, DisplayName = "Cursed Finger" },
	["Cursed Womb"]         = { Category = "Materials", Rarity = "God",       Price = 3000000,  MaxStock = 2, DisplayName = "Cursed Womb" },
	["Tailed Chakra"]       = { Category = "Materials", Rarity = "God",       Price = 3000000,  MaxStock = 2, DisplayName = "Tailed Chakra" },
	["S-Rank Badge"]        = { Category = "Materials", Rarity = "God",       Price = 2500000,  MaxStock = 2, DisplayName = "S-Rank Badge" },
	["Byakugou Seal"]       = { Category = "Materials", Rarity = "Secret",    Price = 2500000,  MaxStock = 2, DisplayName = "Byakugou Seal" },
	["Ice Dagger"]          = { Category = "Materials", Rarity = "Secret",    Price = 2500000,  MaxStock = 2, DisplayName = "Ice Dagger" },
	["Trait Shard"]         = { Category = "Materials", Rarity = "Mythic",    Price = 75000,    MaxStock = 5, DisplayName = "Trait Shard" },
}

-- =================================================================
-- ⚙️ CONFIGURATION STATE
-- =================================================================
AutoMerchant.Config = {
	Enabled         = true,  -- Default ON
	BuyAllStock     = false, -- Beli semua stok item
	BuyPotions      = true,  -- Auto buy Potions
	BuyEssences     = true,  -- Auto buy Essences
	BuyCapsules     = true,  -- Auto buy Capsules
	BuyTickets      = true,  -- Auto buy Tickets
	BuyMaterials    = true,  -- Auto buy Rare Materials
	SelectedItems   = {},    -- Whitelist nama item tertentu
	MinGoldReserve  = 0,     -- Batas minimum sisa gold
	CheckInterval   = 2,     -- Interval pengecekan saat idle (detik)
	ActiveInterval  = 0.5,   -- Interval pengecekan saat event aktif (detik)
}

local isRunning = false
local loopThread = nil
local conns = {}
local lastBoughtEventId = nil
local lastBuyCooldown = {}

-- =================================================================
-- 🛠️ UTILITY: GOLD & STATUS
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
	-- Vector 1: Workspace Attribute
	if Workspace:GetAttribute("TraderEventActive") == true then return true end
	
	-- Vector 2: Remaining EndsAt timestamp
	local endsAt = Workspace:GetAttribute("TraderEventEndsAt")
	if typeof(endsAt) == "number" and endsAt > 0 then
		local now = Workspace:GetServerTimeNow()
		if endsAt > now then return true end
	end
	
	-- Vector 3: NPC di Workspace
	if Workspace:FindFirstChild("TraderChar") or Workspace:FindFirstChild("TraderPlatform") then
		return true
	end
	
	-- Vector 4: UI Frame memiliki item aktif
	local hasActiveUI = false
	pcall(function()
		local pGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
		if pGui and pGui:FindFirstChild("MainUI") and pGui.MainUI:FindFirstChild("Frames") then
			local tFrame = pGui.MainUI.Frames:FindFirstChild("Trader (Merchant)")
			if tFrame and tFrame:FindFirstChild("Frame") and tFrame.Frame:FindFirstChild("Frames") and tFrame.Frame.Frames:FindFirstChild("Main") then
				for _, c in ipairs(tFrame.Frame.Frames.Main:GetChildren()) do
					if c:IsA("Frame") and c.Name ~= "Template" and c.Name ~= "Configuration" then
						hasActiveUI = true
						break
					end
				end
			end
		end
	end)
	
	return hasActiveUI
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
-- 🔍 FILTER CEK ITEM
-- =================================================================
function AutoMerchant.ShouldBuyItem(itemName)
	if not itemName or #itemName == 0 then return false end
	
	if AutoMerchant.Config.BuyAllStock then return true end
	
	if AutoMerchant.Config.SelectedItems and AutoMerchant.Config.SelectedItems[itemName] == true then
		return true
	end
	
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
						if conn.Function then conn.Function() elseif conn.Fire then conn:Fire() end
					end
				end
			end)
		end
	end
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
		if price > 0 and currentGold - price < minGold then
			break
		end
		
		-- 1. Direct Remote
		if buyRemote and typeof(buyRemote.FireServer) == "function" then
			pcall(function()
				buyRemote:FireServer(itemName)
			end)
		end
		
		-- 2. UI Button Trigger
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
		
		task.wait(0.05)
		currentGold = AutoMerchant.GetGold()
	end
end

-- =================================================================
-- ⚡ SCAN & BUY CURRENT MERCHANT STOCK
-- =================================================================
function AutoMerchant.ScanAndBuyAllStock()
	-- Auto trigger ProximityPrompt NPC jika ada di Workspace
	pcall(function()
		local traderChar = Workspace:FindFirstChild("TraderChar") or Workspace:FindFirstChild("TraderPlatform")
		if traderChar then
			local prompt = traderChar:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt and typeof(fireproximityprompt) == "function" then
				fireproximityprompt(prompt)
			end
		end
	end)

	local boughtAny = false

	-- 1. Scan dari PlayerGui Trader Frame
	pcall(function()
		local pGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
		if pGui and pGui:FindFirstChild("MainUI") and pGui.MainUI:FindFirstChild("Frames") then
			local tFrame = pGui.MainUI.Frames:FindFirstChild("Trader (Merchant)")
			if tFrame and tFrame:FindFirstChild("Frame") and tFrame.Frame:FindFirstChild("Frames") and tFrame.Frame.Frames:FindFirstChild("Main") then
				local mainFrame = tFrame.Frame.Frames.Main
				for _, itemFrame in ipairs(mainFrame:GetChildren()) do
					if itemFrame:IsA("Frame") and itemFrame.Name ~= "Template" and itemFrame.Name ~= "Configuration" then
						local itemName = itemFrame.Name
						local stockCount = 1
						local isSoldOut = false
						
						pcall(function()
							if itemFrame:FindFirstChild("Inner3") then
								local inner3 = itemFrame.Inner3
								if inner3:FindFirstChild("ItemName") and inner3.ItemName.Text ~= "" then
									itemName = inner3.ItemName.Text
								end
								if inner3:FindFirstChild("StockNumber") then
									local cur, max = inner3.StockNumber.Text:match("(%d+)/(%d+)")
									if cur then
										stockCount = tonumber(cur) or 1
										if stockCount <= 0 then isSoldOut = true end
									end
								end
							end
						end)
						
						if not isSoldOut and stockCount > 0 and AutoMerchant.ShouldBuyItem(itemName) then
							AutoMerchant.PurchaseItem(itemName, stockCount)
							boughtAny = true
						end
					end
				end
			end
		end
	end)

	-- 2. Query GetStock RemoteFunction
	pcall(function()
		local getStockRemote = ReplicatedStorage.Remotes.Trader.GetStock
		local stockData = getStockRemote:InvokeServer()
		if stockData and typeof(stockData) == "table" and stockData.Items and #stockData.Items > 0 then
			for _, itm in ipairs(stockData.Items) do
				local iName = typeof(itm) == "table" and (itm.Name or itm.Item or itm.ItemName) or tostring(itm)
				local count = (typeof(itm) == "table" and tonumber(itm.Amount or itm.Stock)) or 1
				if AutoMerchant.ShouldBuyItem(iName) then
					AutoMerchant.PurchaseItem(iName, count)
					boughtAny = true
				end
			end
		end
	end)

	-- 3. Fallback: Jika event terdeteksi aktif tapi data stock tertunda, tembak semua item terpilih
	if not boughtAny and AutoMerchant.IsMerchantActive() then
		for itemName, info in pairs(AutoMerchant.ItemsCatalog) do
			if AutoMerchant.ShouldBuyItem(itemName) then
				local now = tick()
				if not lastBuyCooldown[itemName] or (now - lastBuyCooldown[itemName]) > 4 then
					lastBuyCooldown[itemName] = now
					AutoMerchant.PurchaseItem(itemName, info.MaxStock or 2)
				end
			end
		end
	end

	-- 4. Auto Close Merchant UI setelah transaksi selesai
	task.delay(0.5, function()
		AutoMerchant.CloseMerchantUI()
	end)
end

-- =================================================================
-- 🚪 AUTO CLOSE MERCHANT UI HANDLER
-- =================================================================
function AutoMerchant.CloseMerchantUI()
	pcall(function()
		local pGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not pGui then return end
		local mainUI = pGui:FindFirstChild("MainUI")
		if mainUI and mainUI:FindFirstChild("Frames") then
			local tFrame = mainUI.Frames:FindFirstChild("Trader (Merchant)")
			if tFrame then
				-- 1. Klik Close Button di header
				local closeBtn = tFrame:FindFirstChild("Frame")
					and tFrame.Frame:FindFirstChild("Header")
					and tFrame.Frame.Header:FindFirstChild("CloseButton")
					and tFrame.Frame.Header.CloseButton:FindFirstChild("CloseButton")
				if closeBtn then
					if typeof(firesignal) == "function" then
						if closeBtn.Activated then pcall(function() firesignal(closeBtn.Activated) end) end
						if closeBtn.MouseButton1Click then pcall(function() firesignal(closeBtn.MouseButton1Click) end) end
					end
				end
				-- 2. Sembunyikan langsung frame
				tFrame.Visible = false
				if tFrame:FindFirstChild("Frame") then
					tFrame.Frame.Visible = false
				end
			end
		end

		-- 3. Hapus sisa efek Blur & DepthOfField di Lighting agar layar jernih kembali
		local Lighting = game:GetService("Lighting")
		if Lighting then
			for _, effect in ipairs(Lighting:GetDescendants()) do
				if effect:IsA("BlurEffect") then
					effect.Size = 0
					effect.Enabled = false
				end
			end
			for _, effect in ipairs(Lighting:GetChildren()) do
				if effect:IsA("BlurEffect") then
					effect.Size = 0
					effect.Enabled = false
				end
			end
		end
	end)
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

	-- Disconnect koneksi lama
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}

	-- Event 1: TraderEventActive berubah
	pcall(function()
		local c1 = Workspace:GetAttributeChangedSignal("TraderEventActive"):Connect(function()
			if not isRunning or not AutoMerchant.Config.Enabled then return end
			if Workspace:GetAttribute("TraderEventActive") == true then
				task.wait(0.2)
				AutoMerchant.ScanAndBuyAllStock()
			end
		end)
		table.insert(conns, c1)
	end)

	-- Event 2: TraderEventId berubah (merchant spawn baru setiap 20 menit)
	pcall(function()
		local c2 = Workspace:GetAttributeChangedSignal("TraderEventId"):Connect(function()
			if not isRunning or not AutoMerchant.Config.Enabled then return end
			task.wait(0.2)
			AutoMerchant.ScanAndBuyAllStock()
		end)
		table.insert(conns, c2)
	end)

	-- Event 3: Deteksi TraderChar ditambahkan ke Workspace
	pcall(function()
		local c3 = Workspace.ChildAdded:Connect(function(child)
			if not isRunning or not AutoMerchant.Config.Enabled then return end
			if child.Name == "TraderChar" or child.Name == "TraderPlatform" then
				task.wait(0.2)
				AutoMerchant.ScanAndBuyAllStock()
			end
		end)
		table.insert(conns, c3)
	end)

	-- Event 4: Deteksi frame item muncul di UI
	pcall(function()
		local pGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
		if pGui and pGui:FindFirstChild("MainUI") and pGui.MainUI:FindFirstChild("Frames") then
			local tFrame = pGui.MainUI.Frames:FindFirstChild("Trader (Merchant)")
			if tFrame and tFrame:FindFirstChild("Frame") and tFrame.Frame:FindFirstChild("Frames") and tFrame.Frame.Frames:FindFirstChild("Main") then
				local c4 = tFrame.Frame.Frames.Main.ChildAdded:Connect(function(child)
					if not isRunning or not AutoMerchant.Config.Enabled then return end
					if child:IsA("Frame") and child.Name ~= "Template" and child.Name ~= "Configuration" then
						task.wait(0.1)
						AutoMerchant.ScanAndBuyAllStock()
					end
				end)
				table.insert(conns, c4)
			end
		end
	end)

	-- 5. Polling Loop Daemon
	if loopThread then pcall(function() task.cancel(loopThread) end) end
	loopThread = task.spawn(function()
		while isRunning and AutoMerchant.Config.Enabled do
			pcall(function()
				if AutoMerchant.IsMerchantActive() then
					AutoMerchant.ScanAndBuyAllStock()
					task.wait(AutoMerchant.Config.ActiveInterval or 0.5)
				else
					task.wait(AutoMerchant.Config.CheckInterval or 2)
				end
			end)
		end
		isRunning = false
	end)
end

function AutoMerchant.Stop()
	isRunning = false
	AutoMerchant.Config.Enabled = false
	
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}

	if loopThread then
		pcall(function() task.cancel(loopThread) end)
		loopThread = nil
	end
end

function AutoMerchant.IsRunning()
	return isRunning
end

return AutoMerchant
