local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService") 

local cachedModules = require(game.ServerScriptService.Server.CachedModules)

local RackInteractionService = {}

local function onPromptTriggered(prompt, player)
	local character = player.Character
	if not character then return end

	-- 🛠️ DYNAMIC SERVICE LOOKUP (Prevents startup race-condition nil errors)
	local inventoryService = cachedModules.Cache.InventoryService
	local sprayEffectService = cachedModules.Cache.SprayEffectService
	local moneyService = cachedModules.Cache.MoneyService

	if not inventoryService or not sprayEffectService then
		warn("⚠️ Core gameplay services are still initializing in CachedModules!")
		return
	end

	-- Walk up the hierarchy to find the tagged rack model
	local rackModel = prompt
	while rackModel and not CollectionService:HasTag(rackModel, "RetailRack") do
		rackModel = rackModel.Parent
	end
	if not rackModel then return end

	-- The prompt's parent Part is named "RetailSprayPrompt" or "RetailRestockPrompt"
	local promptPartName = prompt.Parent and prompt.Parent.Name or ""

	-- ==========================================
	-- HANDLE SPRAY ACTION
	-- ==========================================
	if promptPartName == "RetailSprayPrompt" then
		-- BULLETPROOF EQUIPPED LOOKUP GATE
		local equippedTool = character:FindFirstChildWhichIsA("Tool")

		-- Fallback to inventory tracking if replication frames are lagging
		if not equippedTool then
			equippedTool = player.Backpack:FindFirstChildWhichIsA("Tool")
		end

		if not equippedTool or not equippedTool:GetAttribute("isSpray") then
			print("❌ Player does not have a spray bottle equipped!")
			return
		end

		-- SMART RECOVERY: Fallback to attribute first, then tool text name string
		local sprayID = equippedTool:GetAttribute("sprayID")
		local sprayName = equippedTool:GetAttribute("SprayName") or equippedTool:GetAttribute("Name") or equippedTool.Name

		-- Clean name text if it already has usage counters appended (e.g., "Dew Drop Spray (4 Uses)" -> "Dew Drop Spray")
		sprayName = string.gsub(sprayName, "%s*%([0-9]+%s*[Uu]ses%)", "")

		-- Verify durability / remaining uses on the tool instance cleanly
		local remainingUses = equippedTool:GetAttribute("Uses") or equippedTool:GetAttribute("UsesLeft") or 5
		if remainingUses <= 0 then 
			print("⚠️ This spray bottle is completely empty!")
			return 
		end

		-- Apply the premium visual customization via server states
		sprayEffectService.setSprayEffect(rackModel, sprayName)

		-- Save the updated rack state to player data
		local plotService = cachedModules.Cache.PlotService
		if plotService and plotService.savePlotState then
			plotService.savePlotState(player)
		end

		-- Deduct a use from the bottle asset
		remainingUses -= 1
		equippedTool:SetAttribute("Uses", remainingUses)
		equippedTool:SetAttribute("UsesLeft", remainingUses)

		if remainingUses <= 0 then
			-- Wipe it cleanly from database memory profile tables if empty
			print("💥 Spray empty! Removing asset from inventory pipeline...")
			inventoryService.removeItem(player, sprayID, 1)
		else
			-- Update display name layout dynamically while preserving internal base configurations
			equippedTool.Name = `{sprayName} ({remainingUses} Uses)`
		end

		-- ==========================================
		-- HANDLE RESTOCK ACTION
		-- ==========================================
	elseif promptPartName == "RetailRestockPrompt" then
		local maxSlots = rackModel:GetAttribute("MaxSlots") or 5
		local currentStock = rackModel:GetAttribute("CurrentStock") or rackModel:GetAttribute("StockAmount") or 0
		local costPerItem = rackModel:GetAttribute("RestockCostPerItem") or 0

		-- If the rack is already packed out, ignore the input
		if currentStock >= maxSlots then return end

		-- Calculate cost to fill only the empty slots: (Max - Current) * Wholesale Price
		local emptySlots = maxSlots - currentStock
		local totalRestockCost = emptySlots * costPerItem

		-- Securely check and deduct cash on the server
		if moneyService and moneyService.removeCoins(player, totalRestockCost) then
			-- Instantly max out the stock variables
			rackModel:SetAttribute("CurrentStock", maxSlots)
			rackModel:SetAttribute("StockAmount", maxSlots) -- Syncs layout with your custom Plot data fields

			-- Save the updated rack state to player data
			local plotService = cachedModules.Cache.PlotService
			if plotService and plotService.savePlotState then
				plotService.savePlotState(player)
			end

			print(`[Restock Success] {player.Name} filled {rackModel.Name} for {totalRestockCost} Coins.`)
		else
			print(`[Restock Failed] {player.Name} doesn't have enough coins for this restock ({totalRestockCost} Coins required).`)
		end
	end
end

-- Automated listener treating CurrentStock as the absolute source of truth for IsStocked
local function trackRackStockState(rack: Model)
	local function verifyStockState()
		local currentStock = rack:GetAttribute("CurrentStock") or rack:GetAttribute("StockAmount") or 0
		local isStocked = currentStock > 0
		-- Automatically updates the boolean dynamically based on actual numerical stock counts
		rack:SetAttribute("IsStocked", isStocked)

		-- Track if the rack has been stocked at least once
		if isStocked then
			rack:SetAttribute("HasBeenStocked", true)
		end
		local hasBeenStocked = rack:GetAttribute("HasBeenStocked") or false

		-- Only show out-of-stock visual if the rack has been stocked before and is now empty
		local showOutOfStock = not isStocked and hasBeenStocked

		-- Toggle Out of Stock GUI visibility
		local interactionPart = rack:FindFirstChild("InteractionPart")
		if interactionPart then
			local outofstockPart = interactionPart:FindFirstChild("OutofstockPart")
			if outofstockPart then
				local outofstockGUI = outofstockPart:FindFirstChild("OutofstockGUI")
				if outofstockGUI and outofstockGUI:IsA("BillboardGui") then
					outofstockGUI.Enabled = showOutOfStock
				end
			end
		end
	end

	-- Listen for live stock deductions/additions across the entire server pipeline
	rack:GetAttributeChangedSignal("CurrentStock"):Connect(verifyStockState)
	rack:GetAttributeChangedSignal("StockAmount"):Connect(verifyStockState)
	verifyStockState() -- Initial run to sync data on startup
end

function RackInteractionService.init()
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)

	-- Hook up state machines for newly streamed or existing retail racks
	CollectionService:GetInstanceAddedSignal("RetailRack"):Connect(trackRackStockState)
	for _, rack in ipairs(CollectionService:GetTagged("RetailRack")) do
		task.spawn(trackRackStockState, rack)
	end

	print("🛒 RackInteractionService is now actively listening for prompt inputs and automating stock attributes!")
end

return RackInteractionService
