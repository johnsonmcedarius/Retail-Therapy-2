local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService") -- Upgraded storage feature
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Module Requirements
local SprayData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SprayData"))
local Monetization = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Monetization"))
local cachedModules = require(script.Parent.Parent.Server.CachedModules) -- Used only for external dependencies (Money/Inventory)

-- Remote Event References
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PurchaseEvent = RemoteEvents:FindFirstChild("Purchase")

-- Keys, Tuning, and Sorted Map Setup
local stockMemoryKey = "GLOBAL_SPRAY_STOCK"
local timeMemoryKey = "GLOBAL_SPRAY_RESTOCK_TIME"
local restockInterval = 300 
local RESTOCK_PRODUCT_ID = Monetization.DevProducts.RestockShop

-- High-throughput memory map for instant cross-server synchronization
local memoryMap = MemoryStoreService:GetSortedMap("GlobalSprayShop")

local SprayShopService = {
	RestockInterval = restockInterval,
	LastRestockTime = os.time(),
}

local SETTINGS = {
	-- This defines the absolute limits of UNIQUE spray types on display at once
	SHOP_SLOTS_RANGE = {Min = 2, Max = 8}, 

	-- Individual items will roll a stock quantity within this range if chosen
	STOCK_RANGE = {Min = 1, Max = 5}, 

	RARITY_CHANCE = {
		Common = 70,
		Uncommon = 15,
		Rare = 12,
		Epic = 3,
		Legendary = 1,
	},
}

-- Mapping DevProduct IDs to Luxury Spray Names dynamically
local ProductIdToSpray = {}
for _, sprayName in ipairs(SprayData.getSprayOrder()) do
	local sprayDataFolder = SprayData.getData(sprayName)
	if sprayDataFolder and sprayDataFolder:FindFirstChild("DevProduct") then
		local devProductId = sprayDataFolder.DevProduct.Value
		ProductIdToSpray[devProductId] = sprayName
	end
end

local function FormatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

-- Secure, Fallback-Protected Stock Generation (Pool Selection Variant)
local function GenerateStock()
	local sprayStock = {}
	local sprayOrder = SprayData.getSprayOrder()

	-- 1. Initialize all sprays as out of stock/default values first
	local eligiblePool = {}
	for _, sprayName in ipairs(sprayOrder) do
		local folderData = SprayData.getData(sprayName)
		local rarity = folderData and folderData:FindFirstChild("Rarity") and folderData.Rarity.Value or "Common"
		local price = folderData and folderData:FindFirstChild("Price") and folderData.Price.Value or 0
		local layoutOrder = folderData and folderData:FindFirstChild("LayoutOrder") and folderData.LayoutOrder.Value or 0

		sprayStock[sprayName] = {
			Name = sprayName,
			StockAmount = 0,
			Price = price,
			Rarity = rarity,
			LayoutOrder = layoutOrder,
			IsInStock = false
		}

		if folderData then
			table.insert(eligiblePool, sprayName)
		else
			warn(`[SprayShopService] Missing folder data configurations for: {sprayName}. Slotted defaults.`)
		end
	end

	-- 2. Determine exactly how many total UNIQUE slots are open this restock cycle
	local totalSlotsToFill = math.random(SETTINGS.SHOP_SLOTS_RANGE.Min, SETTINGS.SHOP_SLOTS_RANGE.Max)
	totalSlotsToFill = math.min(totalSlotsToFill, #eligiblePool) -- Can't fill more slots than total existing items

	-- 3. Weighted selection loop until slots are fully populated
	local selectedCount = 0
	local attempts = 0 -- Anti-infinite loop protection

	while selectedCount < totalSlotsToFill and #eligiblePool > 0 and attempts < 100 do
		attempts += 1

		-- Grab a random index from our remaining eligible pool
		local poolIndex = math.random(1, #eligiblePool)
		local candidateName = eligiblePool[poolIndex]
		local itemData = sprayStock[candidateName]

		-- Run the standard rarity weight check on the candidate
		local weight = SETTINGS.RARITY_CHANCE[itemData.Rarity] or 100
		local roll = math.random(1, 100)

		if roll <= weight then
			-- Passed! Give it a random stock quantity and remove it from candidate pool
			itemData.StockAmount = math.random(SETTINGS.STOCK_RANGE.Min, SETTINGS.STOCK_RANGE.Max)
			itemData.IsInStock = true

			selectedCount += 1
			table.remove(eligiblePool, poolIndex) -- Prevents picking the same spray twice
		end
	end

	-- FAILSAFE PROTECTION: If strict rarity weights caused us to completely fail rolls,
	-- force-fill slots using pure randomness until our minimum unique slot target is met.
	if selectedCount < SETTINGS.SHOP_SLOTS_RANGE.Min and #eligiblePool > 0 then
		print("[SprayShopService] Weight constraints starved stock generation. Forcing fallback slot allocation.")
		while selectedCount < SETTINGS.SHOP_SLOTS_RANGE.Min and #eligiblePool > 0 do
			local poolIndex = math.random(1, #eligiblePool)
			local candidateName = eligiblePool[poolIndex]
			local itemData = sprayStock[candidateName]

			itemData.StockAmount = math.random(SETTINGS.STOCK_RANGE.Min, SETTINGS.STOCK_RANGE.Max)
			itemData.IsInStock = true

			selectedCount += 1
			table.remove(eligiblePool, poolIndex)
		end
	end

	return sprayStock
end

function SprayShopService:GetCurrentStock()
	local success, raw = pcall(function()
		return memoryMap:GetAsync(stockMemoryKey)
	end)
	if success and raw then
		return HttpService:JSONDecode(raw)
	end

	-- Failover backup layer using standard DataStores
	local backupDataStore = DataStoreService:GetDataStore("GLOBAL_SPRAY_SHOP")
	local backupSuccess, backupRaw = pcall(function()
		return backupDataStore:GetAsync(stockMemoryKey)
	end)
	if backupSuccess and backupRaw then
		return HttpService:JSONDecode(backupRaw)
	end
	return nil
end

function SprayShopService:GetTimeUntilRestock()
	local success, timestamp = pcall(function()
		return memoryMap:GetAsync(timeMemoryKey)
	end)
	if success and timestamp then
		self.LastRestockTime = timestamp
	else
		-- Failover backup layer for timestamps
		local backupDataStore = DataStoreService:GetDataStore("GLOBAL_SPRAY_SHOP")
		pcall(function()
			local ts = backupDataStore:GetAsync(timeMemoryKey)
			if ts then self.LastRestockTime = ts end
		end)
	end
	local elapsed = os.time() - self.LastRestockTime
	return math.max(0, restockInterval - elapsed)
end

function SprayShopService:SaveStockToMemoryStore(stockData)
	local jsonData = HttpService:JSONEncode(stockData)

	-- Updates the rapid Memory Store map (expires naturally in 1 hour to optimize memory quotas)
	pcall(function()
		memoryMap:SetAsync(stockMemoryKey, jsonData, 3600)
	end)

	-- Silently commits a persistent copy to the standard DataStore backup layer
	task.spawn(function()
		local backupDataStore = DataStoreService:GetDataStore("GLOBAL_SPRAY_SHOP")
		pcall(function()
			backupDataStore:SetAsync(stockMemoryKey, jsonData)
		end)
	end)
end

-- Atomic cross-server transaction handler to completely eliminate stock-stealing race conditions
function SprayShopService:PurchaseStockTransaction(sprayName, amountToDecrement)
	local updatedStockData = nil

	local success = pcall(function()
		memoryMap:UpdateAsync(stockMemoryKey, function(rawJson)
			if not rawJson then return nil end
			local currentStock = HttpService:JSONDecode(rawJson)

			if currentStock[sprayName] and currentStock[sprayName].StockAmount >= amountToDecrement then
				currentStock[sprayName].StockAmount -= amountToDecrement
				currentStock[sprayName].IsInStock = currentStock[sprayName].StockAmount > 0
				updatedStockData = currentStock -- Export mutated copy out of closure
				return HttpService:JSONEncode(currentStock)
			end
			return nil -- Aborts the transaction safely if item ran out of stock right as request hit
		end, 3600)
	end)

	if success and updatedStockData then
		task.spawn(function()
			local backupDataStore = DataStoreService:GetDataStore("GLOBAL_SPRAY_SHOP")
			pcall(function()
				backupDataStore:SetAsync(stockMemoryKey, HttpService:JSONEncode(updatedStockData))
			end)
		end)
	end

	return success and updatedStockData ~= nil, updatedStockData
end

function SprayShopService:SaveRestockTime()
	local timestamp = os.time()

	pcall(function()
		memoryMap:SetAsync(timeMemoryKey, timestamp, 3600)
	end)

	task.spawn(function()
		local backupDataStore = DataStoreService:GetDataStore("GLOBAL_SPRAY_SHOP")
		pcall(function()
			backupDataStore:SetAsync(timeMemoryKey, timestamp)
		end)
	end)
end

function SprayShopService:BroadcastRestock()
	local stock = GenerateStock()
	self:SaveStockToMemoryStore(stock)
	self:SaveRestockTime()
	self.LastRestockTime = os.time()

	-- Fire directly to local clients so stock shows up immediately
	RemoteEvents.ResetSprayShop:FireAllClients(stock, true)
	-- Sync to other servers via MessagingService
	MessagingService:PublishAsync("GlobalSprayShopRestock", true)
end

local function HandleDevProductRestock(player)
	local freshStock = GenerateStock()
	if freshStock then
		SprayShopService:SaveRestockTime()
		SprayShopService.LastRestockTime = os.time()

		RemoteEvents.ResetSprayShop:FireAllClients(freshStock, true)
		MessagingService:PublishAsync("GlobalSprayShopRestock", true)

		player:SetAttribute("PersonalRestockActive", true)
		print("[SprayShopService] Shop instantly restocked via DevProduct by", player.Name)
	end
end

-- Messaging Service Listeners
local function OnRestockMessage()
	local stock = SprayShopService:GetCurrentStock()
	if stock then
		RemoteEvents.ResetSprayShop:FireAllClients(stock, true)
	end
end

local function OnStockUpdateMessage()
	local stock = SprayShopService:GetCurrentStock()
	if stock then
		RemoteEvents.ResetSprayShop:FireAllClients(stock, false)
	end
end

function SprayShopService:ForceRestock()
	self:BroadcastRestock()
end

function SprayShopService.init()
	-- Subscribe to Cross-Server Event channels
	MessagingService:SubscribeAsync("GlobalSprayShopRestock", OnRestockMessage)
	MessagingService:SubscribeAsync("GlobalSprayShopStockUpdate", OnStockUpdateMessage)

	local existingStock = SprayShopService:GetCurrentStock()
	if not existingStock then
		local initialStock = GenerateStock()
		SprayShopService:SaveStockToMemoryStore(initialStock)
		SprayShopService:SaveRestockTime()
		SprayShopService.LastRestockTime = os.time()

		RemoteEvents.ResetSprayShop:FireAllClients(initialStock, true)
		print("[SprayShopService] Initial global stock generated.")
	else
		SprayShopService:GetTimeUntilRestock()
		RemoteEvents.ResetSprayShop:FireAllClients(existingStock, false)
	end

	-- ==========================================
	-- ROBLOX NATIVE MARKETPLACE PROCESSRECEIPT
	-- ==========================================
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local productId = receiptInfo.ProductId

		-- 🧪 Handle Premium Single Spray Purchases via DevProduct IDs
		local sprayName = ProductIdToSpray[productId]
		if sprayName then
			local success, err = pcall(function()
				local inventoryService = cachedModules.Cache.InventoryService
				return inventoryService.giveSpray(player, sprayName, { Mutations = "" })
			end)

			if success then
				print("✅ Granted premium native spray asset:", sprayName, "to", player.Name)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			else
				warn("❌ Failed to grant native spray asset:", err)
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end

		-- 🛒 Handle Instant Robux Shop Restocks
		if productId == RESTOCK_PRODUCT_ID then
			if PurchaseEvent then 
				PurchaseEvent:FireClient(player) 
			end
			HandleDevProductRestock(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- RemoteEvent for DevProduct Restock Purchase
	RemoteEvents.BuySpray.OnServerEvent:Connect(function(player, sprayName)
		local folderData = SprayData.getData(sprayName)
		if not folderData then return end

		local price = folderData.Price.Value
		local currencyType = folderData:FindFirstChild("CurrencyType") and folderData.CurrencyType.Value or "Coins"

		local moneyService = cachedModules.Cache.MoneyService
		local inventoryService = cachedModules.Cache.InventoryService

		if not moneyService or not inventoryService then
			warn("[SprayShopService] MoneyService or InventoryService are missing from Cache definitions!")
			return
		end

		-- Verify funds locally BEFORE verifying and modifying the global memory store stock
		local hasFunds = false
		if currencyType == "Diamonds" then
			hasFunds = moneyService.hasEnoughDiamonds(player, price)
		else
			hasFunds = moneyService.hasEnoughCoins(player, price)
		end

		if not hasFunds then
			warn(`[Purchase Failed] {player.Name} has insufficient local funds for {sprayName}.`)
			return
		end

		-- Execute atomic global stock reduction transaction
		local txSuccess, updatedStock = SprayShopService:PurchaseStockTransaction(sprayName, 1)

		if txSuccess and updatedStock then
			local transactionSuccess = false

			-- Deduct local currencies securely now that stock block is locked
			if currencyType == "Diamonds" then
				transactionSuccess = moneyService.removeDiamonds(player, price)
			else
				transactionSuccess = moneyService.removeCoins(player, price)
			end

			if transactionSuccess then
				RemoteEvents.ResetSprayShop:FireAllClients(updatedStock, false)
				MessagingService:PublishAsync("GlobalSprayShopStockUpdate", true)

				inventoryService.giveSpray(player, sprayName, { Mutations = "" })
				print(`[Purchase Approved] {player.Name} bought {sprayName} for {price} {currencyType}.`)
			else
				-- FAILSAFE RECOVERY: If currency deduction crashed mid-execution, restore the stock amount atomically
				warn(`[Purchase Critical Fail] Currency deduction failed for {player.Name}. Reverting global stock block.`)
				SprayShopService:PurchaseStockTransaction(sprayName, -1)
			end
		else
			warn(`[Purchase Failed] {player.Name} tried buying {sprayName} but it sold out in another server transaction.`)
		end
	end)

	-- Timer Loop (Adapts instantly to developer products resetting LastRestockTime)
	task.spawn(function()
		while true do
			local remaining = SprayShopService:GetTimeUntilRestock()
			while remaining > 0 do
				RemoteEvents.SprayShopTimer:FireAllClients(FormatTime(remaining))
				task.wait(1)
				local elapsed = os.time() - SprayShopService.LastRestockTime
				remaining = math.max(0, restockInterval - elapsed)
			end
			SprayShopService:BroadcastRestock()
		end
	end)

	-- Inbound Player Stock Replicater
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			for _ = 1, 10 do
				local stock = SprayShopService:GetCurrentStock()
				if stock then
					RemoteEvents.ResetSprayShop:FireClient(player, stock, false)
					return
				end
				task.wait(1)
			end
		end)
	end)
end

return SprayShopService