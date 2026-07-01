local debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local cachedModules = require(game.ServerScriptService.Server.CachedModules)
local plotService = cachedModules.Cache.PlotService
local inventoryService = cachedModules.Cache.InventoryService
local sprayEffectService = cachedModules.Cache.SprayEffectService 

local SprayActivator = {}
local tool: Tool = script.Parent

tool.Activated:Connect(function()
	local character = tool.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Snappy cooldown check for spraying
	if player:FindFirstChild("SprayToolDebounce") then return end
	local db = Instance.new("BoolValue")
	db.Name = "SprayToolDebounce"
	db.Parent = player
	debris:AddItem(db, 0.3)

	-- BULLETPROOF DURABILITY CHECK
	local remainingUses = tool:GetAttribute("Uses") or tool:GetAttribute("UsesLeft") or 5
	if remainingUses <= 0 then 
		print("⚠️ This spray bottle is completely empty!")
		return 
	end

	local sprayID = tool:GetAttribute("sprayID")
	local toolName = tool:GetAttribute("SprayName") or tool:GetAttribute("Name") or tool.Name
	local itemKey = sprayID or toolName 

	-- Clean name text if it already has usage counters appended
	local cleanSprayName = string.gsub(toolName, "%s*%([0-9]+%s*[Uu]ses%)", "")

	local sound = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Sound")
	if sound then 
		sound:Play() 
	end

	-- Secure spatial verification over plot infrastructure
	local playerPlot: Model = plotService.getPlot(player) 
	if playerPlot then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Include
			raycastParams.FilterDescendantsInstances = {playerPlot}

			local rayOrigin = rootPart.Position
			local rayDirection = rootPart.CFrame.LookVector * 12 -- 12 studs maximum spray distance

			local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
			if raycastResult and raycastResult.Instance then
				local hitInstance = raycastResult.Instance

				-- Identify if the targeted component belongs to a valid rack system
				local rackModel = hitInstance:FindFirstAncestorWithTag("RetailRack") 
					or (CollectionService:HasTag(hitInstance.Parent, "RetailRack") and hitInstance.Parent)

				if rackModel then
					-- Apply the sleek visual texture mutation
					sprayEffectService.setSprayEffect(rackModel, cleanSprayName) 
					print(`[Spray Success] {player.Name} customized {rackModel.Name} with {cleanSprayName}!`)

					-- Deduct a single use instead of deleting the whole item asset
					remainingUses -= 1
					tool:SetAttribute("Uses", remainingUses)
					tool:SetAttribute("UsesLeft", remainingUses)

					-- Save updated rack state to player data
					if plotService and plotService.savePlotState then
						plotService.savePlotState(player)
					end

					if remainingUses <= 0 then
						print("💥 Spray empty! Removing asset from inventory pipeline...")
						inventoryService.removeItem(player, itemKey, 1)
						tool:Destroy() -- Delete the empty handle instance from character hands
					else
						-- Update display name layout dynamically
						tool.Name = `{cleanSprayName} ({remainingUses} Uses)`
					end
				end
			end
		end
	end
end)

return SprayActivator
