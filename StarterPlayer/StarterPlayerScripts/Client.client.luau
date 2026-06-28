local UserInputS = game:GetService("UserInputService")
local RepS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modules = script.Parent.Modules
local shared = RepS.BuildMode
local events = RepS.RemoteEvents

local libraries = RepS.Libraries

local Settings = require(shared.Settings)

local Trove = require(libraries.Trove)
local LemonSignal = require(libraries.LemonSignal)

local PlacingService = require(modules.PlacingService)

local player: Player = Players.LocalPlayer
local Build: ScreenGui = player.PlayerGui:WaitForChild("Build")

local guiVisual: Folder = Build.Visual

local previewHighlight: Highlight = guiVisual.PreviewHighlight

local canPlaceColor: Color3 = Settings.CanPlaceColor
local cannotPlaceColor: Color3 = Settings.CannotPlaceColor

local previewTrove: Trove = Trove.new()
local renderedEvent: Signal<Instance, number, boolean> = PlacingService.Rendered

type Trove = Trove.Trove
type Signal<T...> = LemonSignal.Signal<T...>

-- Category scrolling frames and their template names
local categories = {
	{frame = Build.Furniture, templateName = "BuildTemplate", assetFolder = "Furniture"},
	{frame = Build.Decorations, templateName = "BuildTemplate", assetFolder = "Decorations"},
	{frame = Build.Construction, templateName = "BuildTemplate", assetFolder = "Construction"},
}

local function setupViewport(viewportFrame: ViewportFrame, object: Instance)
	local clone: Instance = object:Clone()
	clone:PivotTo(CFrame.new(Vector3.zero))
	
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	
	clone.Parent = viewportFrame

	local camera = Instance.new("Camera")
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	local cf, size = clone:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	local distance = maxDim * 1.5
	camera.CFrame = CFrame.new(cf.Position + Vector3.new(distance, distance * 0.6, distance), cf.Position)
end

local function createButton(template: TextButton, object: Instance, parent: Frame)
	local newButton: TextButton = template:Clone()
	newButton.Name = object.Name
	newButton.Parent = parent

	local nameLabel: TextLabel? = newButton:FindFirstChild("BuildNameLabel")
	if nameLabel then
		nameLabel.Text = object.Name
	end

	-- Setup coin price label (visible only if CoinPrice attribute exists)
	local coinPriceLabel: TextLabel? = newButton:FindFirstChild("CoinPriceLabel")
	if coinPriceLabel then
		local coinPrice = object:GetAttribute("CoinPrice")
		if typeof(coinPrice) == "number" and coinPrice > 0 then
			coinPriceLabel.Text = tostring(coinPrice)
			coinPriceLabel.Visible = true
		else
			coinPriceLabel.Visible = false
		end
	end

	-- Setup diamond price label (visible only if DiamondPrice attribute exists)
	local diamondPriceLabel: TextLabel? = newButton:FindFirstChild("DiamondPriceLabel")
	if diamondPriceLabel then
		local diamondPrice = object:GetAttribute("DiamondPrice")
		if typeof(diamondPrice) == "number" and diamondPrice > 0 then
			diamondPriceLabel.Text = tostring(diamondPrice)
			diamondPriceLabel.Visible = true
		else
			diamondPriceLabel.Visible = false
		end
	end

	local viewportFrame: ViewportFrame? = newButton:FindFirstChild("ViewportFrame")
	if viewportFrame then
		setupViewport(viewportFrame, object)
	end

	return newButton
end

local function setupCategory(category)
	local frame: ScrollingFrame = category.frame
	local template: TextButton = frame:FindFirstChild(category.templateName)
	if not template then return end

	template.Parent = nil

	local assetFolder: Folder? = shared.Assets:FindFirstChild(category.assetFolder)
	if not assetFolder then return end

	for _, object: Instance in assetFolder:GetChildren() do
		assert(
			object:IsA("BasePart") or object:IsA("Model"),
			`{object} is not a valid object`
		)

		local newButton = createButton(template, object, frame)

		newButton.MouseButton1Click:Connect(function()
			previewTrove:Clean()

			PlacingService.SetPreview(object)
			previewTrove:Connect(renderedEvent, function(preview: Model, _, canPlace: boolean)
				previewHighlight.Adornee = preview

				if canPlace then previewHighlight.OutlineColor, previewHighlight.FillColor = canPlaceColor, canPlaceColor
				else previewHighlight.OutlineColor, previewHighlight.FillColor = cannotPlaceColor, cannotPlaceColor end
			end)

			previewTrove:Connect(UserInputS.InputBegan, function(inputObject: InputObject, gameProcessedEvent: boolean)
				if gameProcessedEvent then return end

				local rotateY: Enum.KeyCode = Settings.RotateY
				local cancel: Enum.KeyCode = Settings.Cancel

				if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then 
					local preview: Instance? = PlacingService.GetPreview()
					if not preview then return end

					local CF: CFrame = PlacingService._CF
					local canPlace: boolean = PlacingService.CanPlace

					if not canPlace then return end

					local objectName: string = object.Name

					preview:PivotTo(CF)
					events.Place:FireServer({
						ObjectName = objectName,
						CF = CF
					})

					if UserInputS:IsKeyDown(Enum.KeyCode.LeftControl) then return end

					previewTrove:Clean()
					PlacingService.Cancel()

					previewHighlight.Adornee = nil
				elseif inputObject.KeyCode == rotateY then PlacingService.Rotate(Vector3.yAxis)
				elseif inputObject.KeyCode == cancel then
					previewTrove:Clean()
					PlacingService.Cancel()

					previewHighlight.Adornee = nil
				end
			end)
		end)
	end
end

for _, category in categories do
	setupCategory(category)
end

do
	local function OnCharacterAdded(char: Model)
		for _, child: Instance in char:GetChildren() do
			if not child:IsA("BasePart") then continue end

			child.CollisionGroup = "Player"
		end
	end

	player.CharacterAdded:Connect(OnCharacterAdded)

	local char: Model? = player.Character
	if char then OnCharacterAdded(char) end
end
