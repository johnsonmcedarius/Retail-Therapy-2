local UserInputS = game:GetService("UserInputService")
local RepS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local shared = RepS.BuildMode
local events = RepS.RemoteEvents

local Settings = require(shared.Settings)
local BuildHistory = require(shared.Modules.BuildHistory)

local modules = script.Parent:WaitForChild("Modules")
local PlacingService = require(modules.PlacingService)

local player: Player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local buildGui = playerGui:WaitForChild("Build")

-- Find the local player's plot by checking USERID attribute
local function getPlot(): Model?
	local userId: number = player.UserId
	for _, plot: Model in workspace.Plots:GetChildren() do
		if plot:GetAttribute("USERID") == userId then
			return plot
		end
	end
	return nil
end

local toolbar = buildGui:WaitForChild("Toolbar")
local undoButton = toolbar:WaitForChild("Undo")
local redoButton = toolbar:WaitForChild("Redo")
local deleteButton = toolbar:WaitForChild("Delete")
local gridButton = toolbar:WaitForChild("Grid")
local gridSizeLabel = gridButton:WaitForChild("GridSizeLabel")

local cancelFrame = buildGui:WaitForChild("CancelFrame")
local cancelButton = cancelFrame:WaitForChild("CancelButton")

local undoStack = BuildHistory.undoStack
local redoStack = BuildHistory.redoStack

local deleteMode = false
local originalDeleteColor = deleteButton.ImageColor3

-- Grid size cycling
local gridIndex = 1
local function getCurrentGridSize()
	return Settings.GridSizes[gridIndex]
end
local function updateGridLabel()
	gridSizeLabel.Text = tostring(getCurrentGridSize())
end
-- Initialize grid size
Settings.GridUnit = getCurrentGridSize()
updateGridLabel()

-- Delete mode helpers
local function enterDeleteMode()
	deleteMode = true
	player:SetAttribute("DeleteMode", true)
	deleteButton.ImageColor3 = Color3.fromRGB(255, 100, 100)
	PlacingService.Cancel()
end

local function exitDeleteMode()
	deleteMode = false
	player:SetAttribute("DeleteMode", false)
	deleteButton.ImageColor3 = originalDeleteColor
end

-- Listen for placement results from the server (normal placements only)
events.PlacementResult.OnClientEvent:Connect(function(result)
	BuildHistory.pushUndo({
		action = "Place",
		objectName = result.ObjectName,
		cframe = result.CF,
		objectId = result.ObjectId,
	})
end)

-- Undo button
undoButton.MouseButton1Click:Connect(function()
	if BuildHistory.undoCount() == 0 then return end

	local action = BuildHistory.popUndo()

	if action.action == "Place" then
		-- Undo a placement by deleting the object (100% refund)
		events.DeleteObject:FireServer({ObjectId = action.objectId, Reason = "undo"})
		BuildHistory.pushRedo(action)
	elseif action.action == "Delete" then
		-- Undo a deletion by restoring the exact object from server trash (re-deduct 70%)
		events.RestoreObject:FireServer({ObjectId = action.objectId, Reason = "undo"})
		BuildHistory.pushRedo(action)
	end
end)

-- Redo button
redoButton.MouseButton1Click:Connect(function()
	if BuildHistory.redoCount() == 0 then return end

	local action = BuildHistory.popRedo()

	if action.action == "Place" then
		-- Redo a placement by restoring the exact object from server trash (deduct 100%)
		events.RestoreObject:FireServer({ObjectId = action.objectId, Reason = "redo"})
		BuildHistory.pushUndo(action)
	elseif action.action == "Delete" then
		-- Redo a deletion by deleting the object (70% refund)
		events.DeleteObject:FireServer({ObjectId = action.objectId, Reason = "redo"})
		BuildHistory.pushUndo(action)
	end
end)

-- Grid button cycles grid size
gridButton.MouseButton1Click:Connect(function()
	gridIndex = gridIndex + 1
	if gridIndex > #Settings.GridSizes then
		gridIndex = 1
	end
	Settings.GridUnit = getCurrentGridSize()
	updateGridLabel()
end)

-- Delete button toggles delete mode
deleteButton.MouseButton1Click:Connect(function()
	if deleteMode then
		exitDeleteMode()
	else
		enterDeleteMode()
	end
end)

-- Cancel button also exits delete mode
cancelButton.MouseButton1Click:Connect(function()
	if deleteMode then
		exitDeleteMode()
	end
end)

-- Handle mouse clicks in delete mode
UserInputS.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if not deleteMode then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	local plot: Model? = getPlot()
	if not plot then return end

	local buildObjects: Folder? = plot:FindFirstChild("BuildObjects")
	if not buildObjects then return end

	local mousePos: Vector2 = UserInputS:GetMouseLocation()
	local camera: Camera = workspace.CurrentCamera
	local ray: Ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local raycastParams: RaycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { buildObjects }

	local result: RaycastResult? = workspace:Raycast(ray.Origin, ray.Direction * 2048, raycastParams)
	if not result then return end

	-- Find the top-level object inside BuildObjects that was hit
	local hitInstance: Instance = result.Instance
	local targetObject: Instance? = hitInstance

	while targetObject and targetObject.Parent ~= buildObjects do
		targetObject = targetObject.Parent
	end

	if not targetObject then return end

	local objectId: number? = targetObject:GetAttribute("BuildId")
	if not objectId then return end

	local objectName: string = targetObject.Name
	local cframe: CFrame = targetObject:GetPivot()

	events.DeleteObject:FireServer({ObjectId = objectId, Reason = "delete"})

	BuildHistory.pushUndo({
		action = "Delete",
		objectName = objectName,
		cframe = cframe,
		objectId = objectId,
	})
end)

-- Exit delete mode when Build GUI is closed
buildGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not buildGui.Enabled then
		exitDeleteMode()
	end
end)
