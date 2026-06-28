-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")

-- Modules
local SprayRarityColors = require(ReplicatedStorage:WaitForChild("Modules").SprayRarity)
local SprayData = require(ReplicatedStorage:WaitForChild("Modules").SprayData)
local Monetization = require(ReplicatedStorage:WaitForChild("Modules").Monetization)

-- Remotes & Sounds
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")

-- UI References
local player = Players.LocalPlayer
local gui = script.Parent
local shopFrame = gui:WaitForChild("ShopFrame")
local Notification = gui:WaitForChild("RestockNotification")
local scrollFrame = shopFrame:WaitForChild("ScrollingFrame")
local timerLabel = shopFrame:WaitForChild("Timer")
local sprayFrameTemplate = script:WaitForChild("SprayFrameTemplate")
local RestockSound = Sounds:WaitForChild("Restock")
local PurchaseSound = Sounds:WaitForChild("Purchase")

-- State
local CurrentShopData = {} 
local dataLoaded = false 
local playerShopData = {} 

-- Sound Connections
RemoteEvents.Purchase.OnClientEvent:Connect(function()
	PurchaseSound:Play()
end)

RemoteEvents.SprayShopTimer.OnClientEvent:Connect(function(timeLeft)
	timerLabel.Text = "Restocks in: " .. tostring(timeLeft)
end)

-- Developer Product Restock Configuration
local restockButton = shopFrame:WaitForChild("RestockButton")
local RESTOCK_PRODUCT_ID = Monetization.DevProducts.RestockShop
restockButton.MouseButton1Click:Connect(function()
	MarketplaceService:PromptProductPurchase(player, RESTOCK_PRODUCT_ID)
end)

-- Notification Tween Generation Setup
Notification.TextTransparency = 1
Notification.Visible = false
local fadeInTween = TweenService:Create(Notification, TweenInfo.new(0.5), {TextTransparency = 0})
local fadeOutTween = TweenService:Create(Notification, TweenInfo.new(0.5), {TextTransparency = 1})

--// Universal Frame UI Updater (Handles Coin/Diamond UI layouts cleanly)
local function updateFrameUI(sprayFrame, data)
	if not sprayFrame then return end

	sprayFrame.LayoutOrder = data.LayoutOrder
	sprayFrame.SprayName.Text = data.Name
	sprayFrame.Rarity.Text = data.Rarity

	
	local currencySuffix = data.CurrencyType == "Diamonds" and " 💎" or " Coins"
	sprayFrame.SprayPrice.Text = tostring(data.Price) .. currencySuffix

	local buyButton = sprayFrame:WaitForChild("BuyButton")
	local stockLabel = sprayFrame:WaitForChild("SprayStock")
	local isOutOfStock = data.StockAmount <= 0

	-- Handle purchase button design bounds dynamically
	buyButton.Text = isOutOfStock and "OUT OF STOCK" or "Purchase"
	buyButton.BackgroundColor3 = isOutOfStock and Color3.fromRGB(150,150,150) or Color3.fromRGB(50,200,50)
	buyButton.TextColor3 = Color3.fromRGB(255,255,255)
	buyButton.UIStroke.Color = isOutOfStock and Color3.fromRGB(0,0,0) or Color3.fromRGB(24,147,24)
	buyButton.AutoButtonColor = not isOutOfStock
	stockLabel.Text = isOutOfStock and "OUT OF STOCK" or "X" .. data.StockAmount .. " Stock"

	-- Handle Developer Product Robux Frame Bounds
	local robuxButton = sprayFrame:WaitForChild("RobuxButton")
	if data.DevProduct then
		robuxButton.Visible = true
		robuxButton:SetAttribute("DevProductId", data.DevProduct)
	else
		robuxButton.Visible = false
	end

	-- Render Rarity Gradients or Solid Colors
	local rarityStyle = SprayRarityColors[data.Rarity]
	local oldGradient = sprayFrame.Rarity:FindFirstChildOfClass("UIGradient")
	if oldGradient then oldGradient:Destroy() end

	if typeof(rarityStyle) == "Color3" then
		sprayFrame.Rarity.BackgroundColor3 = rarityStyle
	elseif rarityStyle then
		rarityStyle:Clone().Parent = sprayFrame.Rarity
	end

	-- Sync element attribute engine states
	sprayFrame:SetAttribute("Price", data.Price)
	sprayFrame:SetAttribute("CurrencyType", data.CurrencyType)
	sprayFrame:SetAttribute("StockAmount", data.StockAmount)
	sprayFrame:SetAttribute("InStock", not isOutOfStock)
end

--// Initialize all spray frames as hidden pools initially
local sprayOrder = SprayData.getSprayOrder()

for _, sprayName in ipairs(sprayOrder) do
	local dataFolder = SprayData.getData(sprayName)
	if not dataFolder then
		warn("Couldn't find data for", sprayName)
		continue
	end

	local sprayClone = sprayFrameTemplate:Clone()
	sprayClone.Name = sprayName
	sprayClone.Visible = false -- Kept hidden until server dictates stock
	sprayClone.Parent = scrollFrame

	local name = dataFolder:FindFirstChild("Name") and dataFolder.Name.Value or sprayName
	local price = dataFolder:FindFirstChild("Price") and dataFolder.Price.Value or 0
	local rarity = dataFolder:FindFirstChild("Rarity") and dataFolder.Rarity.Value or "Common"
	local layoutOrder = dataFolder:FindFirstChild("LayoutOrder") and dataFolder.LayoutOrder.Value or 0
	local devProductId = dataFolder:FindFirstChild("DevProduct") and dataFolder.DevProduct.Value or nil

	-- Pull currency preference from data folder configuration, default to Coins
	local currencyType = dataFolder:FindFirstChild("CurrencyType") and dataFolder.CurrencyType.Value or "Coins"

	-- Default tracking maps setup
	playerShopData[sprayName] = {
		Name = name,
		Price = price,
		CurrencyType = currencyType,
		Rarity = rarity,
		LayoutOrder = layoutOrder,
		StockAmount = 0, -- Default to 0 until server updates data
		DevProduct = devProductId
	}

	-- Run initial visual compilation pass
	updateFrameUI(sprayClone, playerShopData[sprayName])

	-- Fetch and display Dev Product Robux Price details safely
	local robuxButton = sprayClone:WaitForChild("RobuxButton")
	if devProductId then
		task.spawn(function()
			local success, productInfo = pcall(function()
				return MarketplaceService:GetProductInfoAsync(devProductId, Enum.InfoType.Product)
			end)
			if success and productInfo and productInfo.PriceInRobux then
				robuxButton.Text = "R$ " .. tostring(productInfo.PriceInRobux)
			else
				robuxButton.Text = "N/A"
			end
		end)
	end

	
	local buyButton = sprayClone:WaitForChild("BuyButton")
	buyButton.MouseButton1Click:Connect(function()
		local currentData = playerShopData[sprayName]
		if currentData and currentData.StockAmount > 0 then
			local leaderstats = player:FindFirstChild("leaderstats")

			-- Strictly looks up matching target node currency value defined by MoneyService
			local playerCurrency = leaderstats and leaderstats:FindFirstChild(currentData.CurrencyType)

			if playerCurrency and playerCurrency.Value >= currentData.Price then
				RemoteEvents.BuySpray:FireServer(sprayName, currentData.Price)

				-- Optimistic local updating
				currentData.StockAmount -= 1
				updateFrameUI(sprayClone, currentData)
			end
		end
	end)

	-- Robux Purchase Connection (Bound once at runtime)
	robuxButton.MouseButton1Click:Connect(function()
		local productId = robuxButton:GetAttribute("DevProductId")
		if productId then
			MarketplaceService:PromptProductPurchase(player, productId)
		end
	end)

	CollectionService:AddTag(sprayClone, "Hover")
end

dataLoaded = true

--// Handle Server Restocks / Updates Completely Driven by Server Configuration
RemoteEvents.ResetSprayShop.OnClientEvent:Connect(function(sprayData, isRestock)
	CurrentShopData = sprayData 

	-- 1. Reset visibility of ALL pre-generated frames before applying current stock
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child.Visible = false
		end
	end

	-- 2. Process incoming server stock definitions
	for sprayName, data in pairs(sprayData) do
		local sprayFrame = scrollFrame:FindFirstChild(sprayName)

		-- Safely handle fallback schema definitions if server model data structure lacks field
		if not data.CurrencyType then data.CurrencyType = "Coins" end
		playerShopData[sprayName] = table.clone(data)

		if sprayFrame then
			sprayFrame.Visible = true 
			updateFrameUI(sprayFrame, data)

			
			local viewportFrame = sprayFrame.SprayFrame:WaitForChild("ViewportFrame")

			
			local oldModel = viewportFrame:FindFirstChildWhichIsA("Model")
			if oldModel then oldModel:Destroy() end

			local model = ReplicatedStorage.SprayModels:FindFirstChild(data.Name)
			if model then
				local modelClone = model:Clone()
				modelClone.Parent = viewportFrame

				local cam = viewportFrame:FindFirstChild("ViewportCamera")
				if not cam then
					cam = Instance.new("Camera")
					cam.Name = "ViewportCamera"
					cam.Parent = viewportFrame
				end
				viewportFrame.CurrentCamera = cam

				local primaryPart = modelClone:FindFirstChild("PrimaryPart")
				if primaryPart then
					local center = primaryPart.Position
					local size = modelClone:GetExtentsSize().Magnitude
					local zoomDistance = size / 2 + 1.5
					cam.CFrame = CFrame.new(center + Vector3.new(0, 0, zoomDistance), center)
				else
					warn("Missing PrimaryPart for model asset configuration:", data.Name)
				end
			end
		end
	end

	if isRestock then
		RestockSound:Play()

		-- 3. Run visual UI banners inside a safe background thread
		task.spawn(function()
			Notification.Text = "Spray Grounds have been restocked!"
			Notification.Visible = true
			fadeInTween:Play()
			task.wait(2.5)
			fadeOutTween:Play()
			fadeOutTween.Completed:Wait()
			Notification.Visible = false
		end)
	end
end)