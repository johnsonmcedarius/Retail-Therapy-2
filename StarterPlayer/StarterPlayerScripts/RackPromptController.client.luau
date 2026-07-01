local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local ATTACHMENT_NAME = "InteractionPart"

-- Helper to safely grab the live tool state of the local avatar
local function getHoldingSprayState()
	local character = player.Character

	-- STRICT HAND CHECK ONLY
	if character then
		for _, tool in character:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("isSpray") == true then
				return true
			end
		end
	end

	return false
end

-- Universal prompt visibility manager
local function updateRackPrompts(rack: Instance)
	local attachment = rack:FindFirstChild(ATTACHMENT_NAME, true)
	if not attachment then return end

	local sprayPromptPart = attachment:FindFirstChild("RetailSprayPrompt")
	local restockPromptPart = attachment:FindFirstChild("RetailRestockPrompt")

	local sprayPrompt = sprayPromptPart and sprayPromptPart:FindFirstChildWhichIsA("ProximityPrompt")
	local restockPrompt = restockPromptPart and restockPromptPart:FindFirstChildWhichIsA("ProximityPrompt")

	-- If player is moving a build object, hide all prompts
	if player:GetAttribute("IsMovingBuild") == true then
		if sprayPrompt then sprayPrompt.Enabled = false end
		if restockPrompt then restockPrompt.Enabled = false end
		return
	end

	-- Fetch stock constraints dynamically
	local maxSlots = rack:GetAttribute("MaxSlots") or 5
	local currentStock = rack:GetAttribute("CurrentStock")
	if currentStock == nil then currentStock = rack:GetAttribute("StockAmount") end

	-- ✅ FIX: Instead of completely bailing and freezing, turn them off 
	-- safely until the server data fully replicates over the network.
	if currentStock == nil then 
		if sprayPrompt then sprayPrompt.Enabled = false end
		if restockPrompt then restockPrompt.Enabled = false end
		return 
	end 

	-- Pull the new boolean you added (or fallback to math just in case)
	local isEmpty = rack:GetAttribute("IsEmpty")
	if isEmpty == nil then isEmpty = (currentStock <= 0) end

	local holdingSpray = getHoldingSprayState()

	-- ✅ FIX: Decouple the prompts! If one is slow to load, it won't brick the other.
	if sprayPrompt then
		sprayPrompt.Enabled = holdingSpray
	end

	if restockPrompt then
		-- Restock prompts hide if player is holding a spray OR if the rack is not completely empty
		restockPrompt.Enabled = not holdingSpray and isEmpty
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

	-- ✅ FIX: Listen to the entire suite of state attributes. 
	-- Whichever one lands first from replication will instantly force a UI correction.
	rack:GetAttributeChangedSignal("CurrentStock"):Connect(function()
		updateRackPrompts(rack)
	end)
	rack:GetAttributeChangedSignal("StockAmount"):Connect(function()
		updateRackPrompts(rack)
	end)
	rack:GetAttributeChangedSignal("IsEmpty"):Connect(function()
		updateRackPrompts(rack)
	end)
	rack:GetAttributeChangedSignal("IsStocked"):Connect(function()
		updateRackPrompts(rack)
	end)
end

-- When move mode starts/stops, refresh all prompts globally
player:GetAttributeChangedSignal("IsMovingBuild"):Connect(function()
	globalPromptRefresh()
end)

-- Initialize listeners for current and future streamed-in retail racks
CollectionService:GetInstanceAddedSignal("RetailRack"):Connect(setupClientRackPromptTracking)
for _, rack in ipairs(CollectionService:GetTagged("RetailRack")) do
	task.spawn(setupClientRackPromptTracking, rack)
end

if player.Character then 
	setupCharacterEquipListeners(player.Character) 
	globalPromptRefresh()
end

player.CharacterAdded:Connect(function(char)
	setupCharacterEquipListeners(char)
	globalPromptRefresh()
end)
