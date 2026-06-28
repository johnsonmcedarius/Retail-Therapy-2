local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local Service = {}

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

-- Core layout loader for when data loads or when objects are built
function Service.updatePlot(player: Player, action: string, data: any)
	local playerData = cachedModules.Cache.DataService.getData(player)
	if not playerData then return end

	if action == "buildPlaced" then
		print(`[Build Placed] {player.Name} placed "{data.ObjectName}" (ID: {data.ObjectId}) on plot`)
		-- TODO: Save the placed object to player data here
		-- Example: table.insert(playerData.PlotObjects, {Name = data.ObjectName, CF = data.CF, BuildId = data.ObjectId})
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

		-- 🧹 Clear all build objects from the plot
		local buildObjects = foundPlot:FindFirstChild("BuildObjects")
		if buildObjects then
			for _, obj in buildObjects:GetChildren() do
				obj.Parent = nil
			end
		end
	end
end

function Service.init()
	
end

return Service