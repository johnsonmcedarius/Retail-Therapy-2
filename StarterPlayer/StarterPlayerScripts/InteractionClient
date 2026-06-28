local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local modules = script.Parent:WaitForChild("Modules")
local PlacingService = require(modules:WaitForChild("PlacingService"))
local Settings = require(ReplicatedStorage.BuildMode:WaitForChild("Settings"))
local Trove = require(ReplicatedStorage.Libraries:WaitForChild("Trove"))

local events = ReplicatedStorage:WaitForChild("RemoteEvents")
local deleteEvent = events:FindFirstChild("DeleteObject")
local storeEvent = events:FindFirstChild("StoreObject")
local moveEvent = events:FindFirstChild("MoveObject")
local placeEvent = events:FindFirstChild("Place")
local inventoryUpdateEvent = events:FindFirstChild("InventoryUpdate")
local requestInventoryEvent = events:FindFirstChild("RequestInventory")

local bbguiTemplate = ReplicatedStorage:WaitForChild("BBGUIs"):FindFirstChild("InteractionBB")
local buildGui = playerGui:WaitForChild("Build")
local buildAssets = ReplicatedStorage.BuildMode:WaitForChild("Assets")

-- ============================================================
-- STATE
-- ============================================================
local selectedObject = nil
local activeBBGUI = nil
local isMoving = false
local moveTrove = nil
local moveHighlight = nil
local currentInventory = {}

-- ============================================================
-- HELPERS
-- ============================================================

-- Find the local player's plot
local function getPlot()
	for _, plot in workspace.Plots:GetChildren() do
		if plot:GetAttribute("USERID") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Find an asset by name in BuildMode.Assets folders
local function findAssetByName(name)
	for _, folder in buildAssets:GetChildren() do
		if folder:IsA("Folder") then
			local asset = folder:FindFirstChild(name)
			if asset then return asset end
		end
	end
	return nil
end

-- Get the adornment part for a build object (PrimaryPart for Model, itself for Part)
local function getAdornee(object)
	if object:IsA("BasePart") then return object end
	if object:IsA("Model") then
		if object.PrimaryPart then return object.PrimaryPart end
		for _, child in object:GetChildren() do
			if child:IsA("BasePart") then return child end
		end
	end
	return nil
end

-- Collect all BaseParts in an object with their current properties
local function collectPartStates(object)
	local states = {}
	if object:IsA("BasePart") then
		table.insert(states, {part = object, transparency = object.Transparency, canQuery = object.CanQuery})
	elseif object:IsA("Model") then
		for _, descendant in object:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(states, {part = descendant, transparency = descendant.Transparency, canQuery = descendant.CanQuery})
			end
		end
	end
	return states
end

-- Hide/show proximity prompts and out-of-stock visuals on a rack
local function setRackVisualsHidden(rack, hidden)
	local interactionPart = rack:FindFirstChild("InteractionPart", true)
	if not interactionPart then return end

	-- Toggle proximity prompts
	for _, descendant in interactionPart:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.Enabled = not hidden
		end
	end

	-- Toggle out-of-stock part and GUI
	local outofstockPart = interactionPart:FindFirstChild("OutofstockPart")
	if outofstockPart and outofstockPart:IsA("BasePart") then
		outofstockPart.Transparency = hidden and 1 or 0
		local outofstockGUI = outofstockPart:FindFirstChild("OutofstockGUI")
		if outofstockGUI and outofstockGUI:IsA("BillboardGui") then
			outofstockGUI.Enabled = not hidden
		end
	end
end

-- Restore part states after move
local function restorePartStates(states)
	for _, state in states do
		state.part.Transparency = state.transparency
		state.part.CanQuery = state.canQuery
	end
end

-- ============================================================
-- BBGUI MANAGEMENT
-- ============================================================

local startMove  -- forward declaration so showBBGUI can reference it

local function removeBBGUI()
	if activeBBGUI then
		activeBBGUI:Destroy()
		activeBBGUI = nil
	end
	selectedObject = nil
end

local function showBBGUI(object)
	removeBBGUI()
	selectedObject = object

	local clone = bbguiTemplate:Clone()
	clone.Enabled = true
	clone.Active = true
	local adornee = getAdornee(object)
	clone.Adornee = adornee
	clone.Parent = object

	local buildId = object:GetAttribute("BuildId")

	local moveBB = clone:FindFirstChild("MoveBB")
	local sellBB = clone:FindFirstChild("SellBB")
	local storeBB = clone:FindFirstChild("StoreBB")
	local cancelBB = clone:FindFirstChild("CancelBB")

	if moveBB then
		moveBB.MouseButton1Click:Connect(function()
			local id = object:GetAttribute("BuildId")
			removeBBGUI()
			if id then startMove(object, id) end
		end)
	end

	if sellBB then
		sellBB.MouseButton1Click:Connect(function()
			local id = object:GetAttribute("BuildId")
			if id then
				deleteEvent:FireServer({ObjectId = id, Reason = "delete"})
			end
			removeBBGUI()
		end)
	end

	if storeBB then
		storeBB.MouseButton1Click:Connect(function()
			local id = object:GetAttribute("BuildId")
			if id then
				storeEvent:FireServer({ObjectId = id})
			end
			removeBBGUI()
		end)
	end

	if cancelBB then
		cancelBB.MouseButton1Click:Connect(function()
			removeBBGUI()
		end)
	end

	activeBBGUI = clone
end

-- ============================================================
-- MOVE MODE
-- ============================================================

function startMove(object, buildId)	-- assigns to the forward-declared local
	if isMoving then return end
	isMoving = true

	local asset = findAssetByName(object.Name)
	if not asset then
		isMoving = false
		return
	end

	-- Store original part states and make object ghost-like
	local partStates = collectPartStates(object)
	for _, state in partStates do
		state.part.Transparency = 0.7
		state.part.CanQuery = false
	end

	-- Hide rack visuals (prompts, out-of-stock)
	setRackVisualsHidden(object, true)

	-- Set player attribute so RackPromptController hides all prompts
	player:SetAttribute("IsMovingBuild", true)

	-- Create highlight for preview
	moveHighlight = Instance.new("Highlight")
	moveHighlight.Parent = workspace

	-- Start placement preview
	PlacingService.SetPreview(asset)

	moveTrove = Trove.new()

	-- Update highlight color on render
	moveTrove:Connect(PlacingService.Rendered, function(preview, cf, canPlace)
		moveHighlight.Adornee = preview
		local color = canPlace and Settings.CanPlaceColor or Settings.CannotPlaceColor
		moveHighlight.OutlineColor = color
		moveHighlight.FillColor = color
	end)

	local function cleanupMove()
		moveTrove:Clean()
		moveTrove = nil
		PlacingService.Cancel()
		if moveHighlight then
			moveHighlight:Destroy()
			moveHighlight = nil
		end
		restorePartStates(partStates)
		setRackVisualsHidden(object, false)
		player:SetAttribute("IsMovingBuild", false)
		isMoving = false
	end

	-- Handle input during move mode
	moveTrove:Connect(UserInputService.InputBegan, function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local preview = PlacingService.GetPreview()
			if not preview then return end

			local cf = PlacingService._CF
			local canPlace = PlacingService.CanPlace
			if not cf or not canPlace then return end

			-- Fire move event to server
			moveEvent:FireServer({ObjectId = buildId, CF = cf})
			cleanupMove()

		elseif input.KeyCode == Settings.RotateY then
			PlacingService.Rotate(Vector3.yAxis)

		elseif input.KeyCode == Settings.Cancel then
			cleanupMove()
		end
	end)
end

-- ============================================================
-- CLICK DETECTION
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	-- Skip if in move mode
	if isMoving then return end

	-- Skip if placing something (build menu placement active)
	if PlacingService.GetPreview() then return end

	-- Skip if in delete mode (BuildActions handles it)
	if player:GetAttribute("DeleteMode") == true then return end

	-- Skip if clicking on a UI element (check mouse target)
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local plot = getPlot()
	if not plot then return end

	local buildObjects = plot:FindFirstChild("BuildObjects")
	if not buildObjects then return end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { buildObjects }

	local result = workspace:Raycast(ray.Origin, ray.Direction * 2048, raycastParams)
	if not result then
		-- Clicked empty space, remove any active BBGUI
		removeBBGUI()
		return
	end

	-- Find the top-level BuildObjects child that was hit
	local targetObject = result.Instance
	while targetObject and targetObject.Parent ~= buildObjects do
		targetObject = targetObject.Parent
	end

	if not targetObject then return end
	if not targetObject:GetAttribute("BuildId") then return end

	-- If clicking the same object that already has BBGUI, remove it (toggle off)
	if selectedObject == targetObject and activeBBGUI then
		removeBBGUI()
		return
	end

	showBBGUI(targetObject)
end)

-- Remove BBGUI when pressing X (cancel key)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if isMoving then return end
	if input.KeyCode == Settings.Cancel then
		removeBBGUI()
	end
end)

-- Remove BBGUI when build mode opens
buildGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if buildGui.Enabled then
		removeBBGUI()
	end
end)

-- ============================================================
-- INVENTORY SYSTEM
-- ============================================================

local inventoryFrame = buildGui:WaitForChild("Inventory")
local inventoryTemplate = inventoryFrame:WaitForChild("InventoryTemplate")
inventoryTemplate.Parent = nil -- Remove template from visible list

local function setupViewport(viewportFrame, object)
	local clone = object:Clone()
	clone:PivotTo(CFrame.new(Vector3.zero))
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	clone.Parent = viewportFrame

	local cam = Instance.new("Camera")
	cam.Parent = viewportFrame
	viewportFrame.CurrentCamera = cam

	local cf, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	local distance = maxDim * 1.5
	cam.CFrame = CFrame.new(cf.Position + Vector3.new(distance, distance * 0.6, distance), cf.Position)
end

local function populateInventory(inventoryData)
	-- Clear existing buttons (keep template hidden)
	for _, child in inventoryFrame:GetChildren() do
		if child.Name ~= "InventoryTemplate" and child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for itemName, count in pairs(inventoryData) do
		if count > 0 then
			local asset = findAssetByName(itemName)
			if asset then
				local button = inventoryTemplate:Clone()
				button.Name = itemName
				button.Parent = inventoryFrame

				local nameLabel = button:FindFirstChild("BuildNameLabel")
				if nameLabel then
					nameLabel.Text = itemName .. " (x" .. count .. ")"
				end

				-- Hide price labels for inventory items
				local coinLabel = button:FindFirstChild("CoinPriceLabel")
				if coinLabel then coinLabel.Visible = false end
				local diamondLabel = button:FindFirstChild("DiamondPriceLabel")
				if diamondLabel then diamondLabel.Visible = false end

				local viewport = button:FindFirstChild("ViewportFrame")
				if viewport then
					setupViewport(viewport, asset)
				end

				-- Click handler: place from inventory
				button.MouseButton1Click:Connect(function()
					removeBBGUI()

					local previewTrove = Trove.new()

					PlacingService.SetPreview(asset)

					local highlight = Instance.new("Highlight")
					highlight.Parent = workspace

					previewTrove:Connect(PlacingService.Rendered, function(preview, cf, canPlace)
						highlight.Adornee = preview
						local color = canPlace and Settings.CanPlaceColor or Settings.CannotPlaceColor
						highlight.OutlineColor = color
						highlight.FillColor = color
					end)

					previewTrove:Connect(UserInputService.InputBegan, function(inputObj, processed)
						if processed then return end

						if inputObj.UserInputType == Enum.UserInputType.MouseButton1 then
							local preview = PlacingService.GetPreview()
							if not preview then return end

							local cf = PlacingService._CF
							local canPlace = PlacingService.CanPlace
							if not cf or not canPlace then return end

							placeEvent:FireServer({
								ObjectName = itemName,
								CF = cf,
								FromInventory = true,
							})

							if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
								previewTrove:Clean()
								PlacingService.Cancel()
								highlight:Destroy()
							end

						elseif inputObj.KeyCode == Settings.RotateY then
							PlacingService.Rotate(Vector3.yAxis)

						elseif inputObj.KeyCode == Settings.Cancel then
							previewTrove:Clean()
							PlacingService.Cancel()
							highlight:Destroy()
						end
					end)
				end)
			end
		end
	end
end

-- Listen for inventory updates from server
inventoryUpdateEvent.OnClientEvent:Connect(function(inventoryData)
	currentInventory = inventoryData or {}
	populateInventory(currentInventory)
end)

-- Request initial inventory on start
requestInventoryEvent:FireServer()

print("InteractionClient initialized - BBGUI click system, move mode, and inventory populated")
