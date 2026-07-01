local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local MutationsFolder = Modules:WaitForChild("Mutations")

-- Cache our dynamic visual mutation module blocks
local mutationModules = {}

-- ✅ FIXED BUG: A dynamic fetcher that guarantees late-loading modules are caught when a player rejoins
local function getMutationModule(effectName)
	local cleanName = string.gsub(effectName, " ", "")
	if mutationModules[cleanName] then return mutationModules[cleanName] end

	for _, child in ipairs(MutationsFolder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local childCleanName = string.gsub(child.Name, " ", "")
			mutationModules[childCleanName] = require(child)
		end
	end

	return mutationModules[cleanName]
end

local SprayEffectClient = {}

-- ==========================================
-- CLIENT VISUAL HANDLERS
-- ==========================================

-- 🛒 DYNAMIC VISUAL STOCK CONTROLLER
local function updateVisualStock(rack: Instance)
	-- Wait for real replicated data. Do not assume 0 if nil!
	local currentStock = rack:GetAttribute("CurrentStock")
	if currentStock == nil then currentStock = rack:GetAttribute("StockAmount") end

	if currentStock == nil then return end 

	local displayFolder = rack:FindFirstChild("DisplayItems")

	if displayFolder then
		local shouldBeVisible = (currentStock > 0)

		for _, item in ipairs(displayFolder:GetDescendants()) do
			if item:IsA("BasePart") then
				item.Transparency = shouldBeVisible and 0 or 1
				item.CanCollide = false 
			elseif item:IsA("Decal") or item:IsA("Texture") then
				item.Transparency = shouldBeVisible and 0 or 1
			end
		end
	else
		warn(`[Client Visuals] {rack.Name} is missing 'DisplayItems' folder!`)
	end
end

-- 🎨 VISUAL SPRAY COATING CONTROL
local function handleRackEffect(rack: Instance)
	local currentEffect = rack:GetAttribute("SprayEffect")
	if currentEffect == nil then return end -- Await replication

	-- Clean up any old moving textures/particles first
	for _, module in pairs(mutationModules) do
		if module.removeEffect then
			module.removeEffect(rack)
		end
	end

	-- Run the local RenderStepped visual loops if a spray is active
	if currentEffect ~= "None" then
		-- Dynamically fetch to solve the Rejoin / late-streaming bug
		local targetModule = getMutationModule(currentEffect)

		if targetModule and targetModule.applyEffect then
			targetModule.applyEffect(rack)
			print(`[Client Visuals] Rendered local {currentEffect} loops on {rack.Name}`)
		else
			warn(`Visual module script layout not found for effect name: {currentEffect}`)
		end
	end
end

-- ==========================================
-- RACK INITIALIZATION & HOOKS
-- ==========================================

-- 🏗️ AUTOMATED INSTANCE HOOKS
local function setupRack(rack: Instance)
	local displayFolder = rack:WaitForChild("DisplayItems", 5)
	if displayFolder then
		-- Catch late streaming items
		displayFolder.DescendantAdded:Connect(function()
			updateVisualStock(rack)
		end)
	end

	-- Listen for dynamic spray mods
	rack:GetAttributeChangedSignal("SprayEffect"):Connect(function()
		handleRackEffect(rack)
	end)

	-- Listen for live stock updates (Handles both naming variations)
	rack:GetAttributeChangedSignal("CurrentStock"):Connect(function()
		updateVisualStock(rack)
	end)

	rack:GetAttributeChangedSignal("StockAmount"):Connect(function()
		updateVisualStock(rack)
	end)

	-- Run initial frames on load / streaming instantiation
	handleRackEffect(rack)
	updateVisualStock(rack)
end

function SprayEffectClient.init()
	CollectionService:GetInstanceAddedSignal("RetailRack"):Connect(setupRack)
	for _, rack in ipairs(CollectionService:GetTagged("RetailRack")) do
		task.spawn(setupRack, rack)
	end

	print("SprayEffectClient is fully merged and handling visuals live!")
end

-- Initialize the handler loops
SprayEffectClient.init()

return SprayEffectClient
