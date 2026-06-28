local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

-- BuildId counter for restored objects (starts high to avoid conflicts with BuildServer's counter)
local restoreBuildId = 100000

-- Helper: find an asset template by name in BuildMode.Assets
local function findAsset(objectName: string)
	local assets = ReplicatedStorage.BuildMode.Assets
	for _, folder in assets:GetChildren() do
		if folder:IsA("Folder") then
			local object = folder:FindFirstChild(objectName)
			if object then return object end
		end
	end
	return nil
end

-- Cached asset fallbacks
local DEFAULT_THUMBNAIL = "rbxassetid://0"

function Service.getMaxPlots()
	return #workspace.Plots:GetChildren()
end


function Service.getPlot(player: Player)
	for _, plot: Model in ipairs(workspace.Plots:GetChildren()) do
		if plot:GetAttribute("Taken") == true and plot:GetAttribute("USERID") == player.UserId then
			return plot
		end
	end
	return nil
end


function Service.getAvailablePlot(player: Player)
	for _, plot in ipairs(workspace.Plots:GetChildren()) do
		if plot:IsA("Model") and plot:GetAttribute("Taken") ~= true then
			return plot
		end
	end
	return nil
end

-- Serialize all build objects on a player's plot into their saved PlotData
function Service.savePlotState(player: Player)
	local plot = Service.getPlot(player)
	if not plot then return end

	local buildObjects = plot:FindFirstChild("BuildObjects")
	if not buildObjects then return end

	local dataService = cachedModules.Cache.DataService
	if not dataService then return end
	local playerData = dataService.getData(player)
	if not playerData then return end

	local savedObjects = {}
	for _, obj in buildObjects:GetChildren() do
		local pivot = obj:GetPivot()
		local entry = {
			Name = obj.Name,
			CFrame = {pivot:GetComponents()},
		}

		-- Save rack-specific attributes
		if CollectionService:HasTag(obj, "RetailRack") then
			entry.CurrentStock = obj:GetAttribute("CurrentStock") or 0
			entry.SprayEffect = obj:GetAttribute("SprayEffect") or "None"
		end

		table.insert(savedObjects, entry)
	end

	playerData.PlotData = savedObjects
end

-- Recreate build objects from saved PlotData onto a player's plot
function Service.restorePlotState(player: Player, plot: Model)
	local dataService = cachedModules.Cache.DataService
	if not dataService then return end
	local playerData = dataService.getData(player)
	if not playerData or not playerData.PlotData then return end

	-- Ensure BuildObjects folder exists
	local buildObjects = plot:FindFirstChild("BuildObjects")
	if not buildObjects then
		buildObjects = Instance.new("Folder")
		buildObjects.Name = "BuildObjects"
		buildObjects.Parent = plot
	end

	for _, entry in ipairs(playerData.PlotData) do
		local template = findAsset(entry.Name)
		if template then
			local newObject = template:Clone()
			newObject:PivotTo(CFrame.new(table.unpack(entry.CFrame)))

			-- Restore rack-specific attributes before parenting
			if CollectionService:HasTag(newObject, "RetailRack") then
				if entry.CurrentStock then
					newObject:SetAttribute("CurrentStock", entry.CurrentStock)
					newObject:SetAttribute("StockAmount", entry.CurrentStock)
				end
				if entry.SprayEffect then
					newObject:SetAttribute("SprayEffect", entry.SprayEffect)
				end
			end

			-- Assign a unique BuildId (high range to avoid BuildServer conflicts)
			newObject:SetAttribute("BuildId", restoreBuildId)
			restoreBuildId += 1

			newObject.Parent = buildObjects
		else
			warn(`[PlotService] Could not find asset template for "{entry.Name}" while restoring plot`)
		end
	end

	print(`[PlotService] Restored {#playerData.PlotData} objects for {player.Name}`)
end

-- Core layout loader for when data loads or when objects are built
function Service.updatePlot(player: Player, action: string, data: any)
	local playerData = cachedModules.Cache.DataService.getData(player)
	if not playerData then return end

	if action == "buildPlaced" then
		print(`[Build Placed] {player.Name} placed "{data.ObjectName}" (ID: {data.ObjectId}) on plot`)
		Service.savePlotState(player)
	end
end

-- Fired by your core server manager when a player's data successfully loads
function Service.dataLoaded(player: Player)
	local plot = Service.getAvailablePlot(player)
	if not plot then 
		warn("No available plots left in the server for:", player.Name)
		return 
	end

	-- 🧱 Claim the physical plot spatial frame
	plot:SetAttribute("Taken", true)
	plot:SetAttribute("USERID", player.UserId)

	-- Update display signage strings safely
	local playerSign = plot:WaitForChild("PlayerSign", 5)
	if playerSign then
		playerSign.Main.SurfaceGui.TextLabel.Text = player.Name .. "'s Store"
	end

	-- 🖼️ Fetch Player Thumbnail ONCE safely using pcall
	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size420x420
	local content, isReady = DEFAULT_THUMBNAIL, false

	local success, err = pcall(function()
		content, isReady = Players:GetUserThumbnailAsync(player.UserId, thumbType, thumbSize)
	end)

	if not success then
		warn(`Failed to fetch thumbnail for {player.Name}: {err}`)
	end

	local finalImage = (success and isReady) and content or DEFAULT_THUMBNAIL

	-- 🧍‍♂️ Handle Owner Tag Billboards (Avatar displays over the lot)
	local ownerTag = plot:FindFirstChild("Owner_Tag")
	if ownerTag then
		local existingBillboard = ownerTag:FindFirstChild("AvatarGui")
		if existingBillboard then existingBillboard:Destroy() end

		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "AvatarGui"
		billboardGui.Size = UDim2.new(15, 0, 15, 0)
		billboardGui.StudsOffset = Vector3.new(0, 4, 0)
		billboardGui.AlwaysOnTop = true
		billboardGui.MaxDistance = 100
		billboardGui.Parent = ownerTag

		local imageLabel = Instance.new("ImageLabel")
		imageLabel.Size = UDim2.new(1, 0, 1, 0)
		imageLabel.BackgroundTransparency = 1
		imageLabel.Image = finalImage

		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = UDim.new(0.5, 0)
		uiCorner.Parent = imageLabel
		imageLabel.Parent = billboardGui
	end

	-- 🖼️ Update Storefront Sign Image using the same fetched asset
	if playerSign then
		local ImgLbl = playerSign.Main.SurfaceGui:FindFirstChild("ImageLabel")
		if ImgLbl and ImgLbl:IsA("ImageLabel") then
			ImgLbl.ImageTransparency = 0
			ImgLbl.Image = finalImage
		end
	end

	print(`[Plot Claimed] {player.Name} has claimed Plot {plot.Name}`)

	-- Restore saved build objects and rack states
	Service.restorePlotState(player, plot)

	-- Teleport the player to their newly claimed plot if they already have a character
	if player.Character then
		Service.characterAdded(player, player.Character)
	end
end

-- Clear out settings safely when a player disconnects from the server
function Service.playerRemoved(player: Player)
	local foundPlot = Service.getPlot(player)

	if foundPlot then
		foundPlot:SetAttribute("Taken", false)
		foundPlot:SetAttribute("USERID", 0)

		local playerSign = foundPlot:FindFirstChild("PlayerSign")
		if playerSign then
			playerSign.Main.SurfaceGui.TextLabel.Text = "Empty Store"

			local ImgLbl = playerSign.Main.SurfaceGui:FindFirstChild("ImageLabel")
			if ImgLbl and ImgLbl:IsA("ImageLabel") then
				ImgLbl.ImageTransparency = 1
				ImgLbl.Image = ""
			end
		end

		-- 🧹 Only wipe the generated billboard GUI, leave map architecture intact
		local ownerTag = foundPlot:FindFirstChild("Owner_Tag")
		if ownerTag then
			local avatarGui = ownerTag:FindFirstChild("AvatarGui")
			if avatarGui then 
				avatarGui:Destroy() 
			end
		end

		-- Save build objects and rack states before clearing
		Service.savePlotState(player)

		-- 🧹 Clear all build objects from the plot
		local buildObjects = foundPlot:FindFirstChild("BuildObjects")
		if buildObjects then
			for _, obj in buildObjects:GetChildren() do
				obj.Parent = nil
			end
		end
	end
end

function Service.characterAdded(player: Player, character: Model)
	local plot = Service.getPlot(player)
	if not plot then return end

	local spawnPart = plot:FindFirstChild("SpawnLocation")
	if not spawnPart or not spawnPart:IsA("BasePart") then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		hrp = character:WaitForChild("HumanoidRootPart", 5)
		if not hrp then return end
	end

	-- Teleport the player to their plot's spawn location
	hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
end


function Service.init()
	local Players = game:GetService("Players")

	local function setupPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			Service.characterAdded(player, character)
		end)

		-- Handle character that already exists (e.g. player joined before init ran)
		if player.Character then
			Service.characterAdded(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end
end

return Service
