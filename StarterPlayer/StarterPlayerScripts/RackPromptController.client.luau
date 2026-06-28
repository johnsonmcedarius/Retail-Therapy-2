local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local ATTACHMENT_NAME = "InteractionPart"

-- Helper to safely grab the live tool state of the local avatar
local function getHoldingSprayState()
	local character = player.Character
	local equippedTool = character and character:FindFirstChildWhichIsA("Tool")
	return equippedTool and equippedTool:GetAttribute("isSpray") == true
end

-- Universal prompt visibility manager
local function updateRackPrompts(rack: Instance)
	local attachment = rack:FindFirstChild(ATTACHMENT_NAME, true)
	if not attachment then return end

	local sprayPromptPart = attachment:FindFirstChild("RetailSprayPrompt")
	local restockPromptPart = attachment:FindFirstChild("RetailRestockPrompt")

	local sprayPrompt = sprayPromptPart and sprayPromptPart:FindFirstChildWhichIsA("ProximityPrompt")
	local restockPrompt = restockPromptPart and restockPromptPart:FindFirstChildWhichIsA("ProximityPrompt")

	-- Fetch stock constraints dynamically
	local maxSlots = rack:GetAttribute("MaxSlots") or 5
	local currentStock = rack:GetAttribute("CurrentStock") or 0
	local isFull = currentStock >= maxSlots
	local isEmpty = currentStock <= 0
	local holdingSpray = getHoldingSprayState()

	if sprayPrompt and restockPrompt then
		-- Spray prompts display ONLY when actively holding a spray bottle, nothing else
		sprayPrompt.Enabled = holdingSpray

		-- Restock prompts hide if player is holding a spray OR if the rack is already full
		restockPrompt.Enabled = not holdingSpray and not isFull
	end
end

-- Global refresh function to scan all active retail zones
local function globalPromptRefresh()
	for _, rack in ipairs(CollectionService:GetTagged("RetailRack")) do
		updateRackPrompts(rack)
	end
end

-- Monitor the player's character for tool equipping changes
local function setupCharacterEquipListeners(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then globalPromptRefresh() end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then globalPromptRefresh() end
	end)
end

-- Safe initialization sequence for individual racks (handles streaming safely)
local function setupClientRackPromptTracking(rack: Instance)
	updateRackPrompts(rack)

	-- Force prompts to instantly update on screen when stock counts fluctuate live
	rack:GetAttributeChangedSignal("CurrentStock"):Connect(function()
		updateRackPrompts(rack)
	end)
end

-- Initialize listeners for current and future streamed-in retail racks
CollectionService:GetInstanceAddedSignal("RetailRack"):Connect(setupClientRackPromptTracking)
for _, rack in ipairs(CollectionService:GetTagged("RetailRack")) do
	task.spawn(setupClientRackPromptTracking, rack)
end

if player.Character then setupCharacterEquipListeners(player.Character) end
player.CharacterAdded:Connect(setupCharacterEquipListeners)