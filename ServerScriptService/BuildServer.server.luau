local RepS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = RepS.BuildMode
local events = RepS.RemoteEvents

local Validation = require(shared.Modules.Validation)
local PlotService = require(ServerScriptService.Services.PlotService)
local cachedModules = require(ServerScriptService.Server.CachedModules)

-- Refund percentage when deleting a placed object (70%)
local REFUND_PERCENTAGE = 0.7

local nextBuildId: number = 1

-- Trash folder holds deleted objects so they can be restored with full state intact
local trash = Instance.new("Folder")
trash.Name = "BuildTrash"
trash.Parent = ServerStorage

-- Helper: send inventory update to client
local function sendInventoryUpdate(player: Player)
	local dataService = cachedModules.Cache.DataService
	if not dataService then return end
	local playerData = dataService.getData(player)
	if not playerData then return end
	events.InventoryUpdate:FireClient(player, playerData.BuildInventory or {})
end

events.Place.OnServerEvent:Connect(function(player: Player, arguments: {[string]: any})
	local objectName: string = arguments.ObjectName
	local CF: CFrame = arguments.CF
	local fromInventory: boolean = arguments.FromInventory == true

	assert(typeof(objectName) == "string", `"ObjectName" was not specified`)
	assert(typeof(CF) == "CFrame", `"CF" was not specified`)

	-- Find the player's plot
	local plot: Model? = PlotService.getPlot(player)
	if not plot then
		warn(`{player.Name} has no assigned plot — cannot place objects`)
		return
	end

	-- Ensure BuildObjects folder exists
	local buildObjects: Folder = plot:FindFirstChild("BuildObjects")
	if not buildObjects then
		buildObjects = Instance.new("Folder")
		buildObjects.Name = "BuildObjects"
		buildObjects.Parent = plot
	end

	local object: Instance? 
	for _, folder in shared.Assets:GetChildren() do
		if folder:IsA("Folder") then
			object = folder:FindFirstChild(objectName)
			if object then break end
		end
	end
	assert(object, `{objectName} couldn't not found in {shared.Assets}`)

	local moneyService = cachedModules.Cache.MoneyService

	-- If placing from inventory, deduct from inventory instead of currency
	if fromInventory then
		local dataService = cachedModules.Cache.DataService
		if not dataService then return end
		local playerData = dataService.getData(player)
		if not playerData then return end
		playerData.BuildInventory = playerData.BuildInventory or {}
		local count = playerData.BuildInventory[objectName] or 0
		if count <= 0 then
			warn(`{player.Name} does not have {objectName} in inventory`)
			return
		end
		playerData.BuildInventory[objectName] = count - 1
	else
		-- Check and deduct currency before placing
		local coinPrice: number? = object:GetAttribute("CoinPrice")
		local diamondPrice: number? = object:GetAttribute("DiamondPrice")

		if coinPrice and coinPrice > 0 then
			if not moneyService or not moneyService.hasEnoughCoins(player, coinPrice) then
				warn(`{player.Name} does not have enough coins to place {objectName}`)
				return
			end
		elseif diamondPrice and diamondPrice > 0 then
			if not moneyService or not moneyService.hasEnoughDiamonds(player, diamondPrice) then
				warn(`{player.Name} does not have enough diamonds to place {objectName}`)
				return
			end
		end

		local newObject: Instance = object:Clone()
		newObject:PivotTo(CF)

		local hasValidPlacement: boolean = Validation.HasValidPlacement(newObject, { buildObjects })
		if not hasValidPlacement then
			newObject:Destroy()
			warn(`{objectName} has invalid placement for {player.Name}`)
			return
		end

		-- Deduct currency after validation passes
		if coinPrice and coinPrice > 0 then
			if not moneyService.removeCoins(player, coinPrice) then
				newObject:Destroy()
				warn(`{player.Name} failed to deduct {coinPrice} coins for {objectName}`)
				return
			end
		elseif diamondPrice and diamondPrice > 0 then
			if not moneyService.removeDiamonds(player, diamondPrice) then
				newObject:Destroy()
				warn(`{player.Name} failed to deduct {diamondPrice} diamonds for {objectName}`)
				return
			end
		end
	end

	-- Clone and place the object
	local newObject: Instance = object:Clone()
	newObject:PivotTo(CF)

	local hasValidPlacement: boolean = Validation.HasValidPlacement(newObject, { buildObjects })
	if not hasValidPlacement then
		newObject:Destroy()
		warn(`{objectName} has invalid placement for {player.Name}`)
		return
	end

	local buildId: number = nextBuildId
	newObject:SetAttribute("BuildId", buildId)
	newObject.Parent = buildObjects
	events.PlacementResult:FireClient(player, {
		ObjectId = buildId,
		ObjectName = objectName,
		CF = CF,
	})
	nextBuildId += 1

	-- Send updated inventory if placed from inventory
	if fromInventory then
		sendInventoryUpdate(player)
	end

	-- Notify PlotService that an object was placed
	PlotService.updatePlot(player, "buildPlaced", {
		ObjectId = buildId,
		ObjectName = objectName,
		CF = CF,
	})
end)

events.DeleteObject.OnServerEvent:Connect(function(player: Player, arguments: {[string]: any})
	local objectId: number = arguments.ObjectId
	local reason: string? = arguments.Reason

	local plot: Model? = PlotService.getPlot(player)
	if not plot then return end

	local buildObjects: Folder? = plot:FindFirstChild("BuildObjects")
	if not buildObjects then return end

	for _, object in buildObjects:GetChildren() do
		if object:GetAttribute("BuildId") == objectId then
			-- Refund: 100% for undo of placement, 70% for direct delete or redo of deletion
			local refundRate: number = (reason == "undo") and 1.0 or REFUND_PERCENTAGE
			local coinPrice: number? = object:GetAttribute("CoinPrice")
			local diamondPrice: number? = object:GetAttribute("DiamondPrice")
			local moneyService = cachedModules.Cache.MoneyService

			if moneyService then
				if coinPrice and coinPrice > 0 then
					moneyService.giveCoins(player, math.floor(coinPrice * refundRate))
				elseif diamondPrice and diamondPrice > 0 then
					moneyService.giveDiamonds(player, math.floor(diamondPrice * refundRate))
				end
			end

			object.Parent = trash
			PlotService.savePlotState(player)
			break
		end
	end
end)

events.RestoreObject.OnServerEvent:Connect(function(player: Player, arguments: {[string]: any})
	local objectId: number = arguments.ObjectId
	local reason: string? = arguments.Reason

	local plot: Model? = PlotService.getPlot(player)
	if not plot then return end

	local buildObjects: Folder = plot:FindFirstChild("BuildObjects")
	if not buildObjects then
		buildObjects = Instance.new("Folder")
		buildObjects.Name = "BuildObjects"
		buildObjects.Parent = plot
	end

	for _, object in trash:GetChildren() do
		if object:GetAttribute("BuildId") == objectId then
			-- On undo delete: give remaining (100% - 70% = 30%) so total refund = 100%
			-- On redo place: deduct 100% (same as original placement)
			local coinPrice: number? = object:GetAttribute("CoinPrice")
			local diamondPrice: number? = object:GetAttribute("DiamondPrice")
			local moneyService = cachedModules.Cache.MoneyService

			if moneyService then
				if reason == "undo" then
					-- Give remaining amount so total refund = 100%
					if coinPrice and coinPrice > 0 then
						local refundAlreadyGiven = math.floor(coinPrice * REFUND_PERCENTAGE)
						moneyService.giveCoins(player, coinPrice - refundAlreadyGiven)
					elseif diamondPrice and diamondPrice > 0 then
						local refundAlreadyGiven = math.floor(diamondPrice * REFUND_PERCENTAGE)
						moneyService.giveDiamonds(player, diamondPrice - refundAlreadyGiven)
					end
				elseif reason == "redo" then
					-- Deduct 100% (same as original placement)
					if coinPrice and coinPrice > 0 then
						if not moneyService.removeCoins(player, coinPrice) then
							warn(`{player.Name} cannot afford to redo place {object.Name} — needs {coinPrice} coins`)
							return
						end
					elseif diamondPrice and diamondPrice > 0 then
						if not moneyService.removeDiamonds(player, diamondPrice) then
							warn(`{player.Name} cannot afford to redo place {object.Name} — needs {diamondPrice} diamonds`)
							return
						end
					end
				end
			end

			object.Parent = buildObjects
			PlotService.savePlotState(player)
			break
		end
	end
end)

-- Store an object from the plot into the player's build inventory
events.StoreObject.OnServerEvent:Connect(function(player: Player, arguments: {[string]: any})
	local objectId: number = arguments.ObjectId

	local plot: Model? = PlotService.getPlot(player)
	if not plot then return end

	local buildObjects: Folder? = plot:FindFirstChild("BuildObjects")
	if not buildObjects then return end

	for _, object in buildObjects:GetChildren() do
		if object:GetAttribute("BuildId") == objectId then
			local objectName = object.Name

			-- Add to player's build inventory
			local dataService = cachedModules.Cache.DataService
			if dataService then
				local playerData = dataService.getData(player)
				if playerData then
					playerData.BuildInventory = playerData.BuildInventory or {}
					playerData.BuildInventory[objectName] = (playerData.BuildInventory[objectName] or 0) + 1
				end
			end

			-- Remove the physical object
			object.Parent = nil

			sendInventoryUpdate(player)
			PlotService.savePlotState(player)
			break
		end
	end
end)

-- Move an object to a new position on the plot
events.MoveObject.OnServerEvent:Connect(function(player: Player, arguments: {[string]: any})
	local objectId: number = arguments.ObjectId
	local CF: CFrame = arguments.CF

	assert(typeof(CF) == "CFrame", `"CF" was not specified for MoveObject`)

	local plot: Model? = PlotService.getPlot(player)
	if not plot then return end

	local buildObjects: Folder? = plot:FindFirstChild("BuildObjects")
	if not buildObjects then return end

	for _, object in buildObjects:GetChildren() do
		if object:GetAttribute("BuildId") == objectId then
			object:PivotTo(CF)
			PlotService.savePlotState(player)
			break
		end
	end
end)
