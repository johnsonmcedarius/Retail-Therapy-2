local debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local cachedModules = require(game.ServerScriptService.Server.CachedModules)
local plotService = cachedModules.Cache.PlotService
local inventoryService = cachedModules.Cache.InventoryService
local sprayEffectService = cachedModules.Cache.SprayEffectService 

local SprayActivator = {}

local tool: Tool = script.Parent

tool.Activated:Connect(function()
	-- FIXED: Dynamically fetch the player. tool.Parent.Parent breaks on equip!
	local character = tool.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	-- Snappy cooldown check for spraying
	if player:FindFirstChild("SprayToolDebounce") then return end
	local db = Instance.new("BoolValue")
	db.Name = "SprayToolDebounce"
	db.Parent = player
	debris:AddItem(db, 0.3)

	local sprayID = tool:GetAttribute("sprayID") -- Unique inventory GUID key
	local toolName = tool:GetAttribute("Name")   -- Base spray name/type
	local itemKey = sprayID or toolName          -- Fallback logic for safety

	local sound = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Sound")
	if sound then 
		sound:Play() 
	end

	-- Secure spatial verification over plot infrastructure
	local playerPlot: Model = plotService.getPlot(player) 
	if playerPlot then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- FIXED: Ditched InvokeClient. We use a secure server-side raycast 
			-- based on where the avatar is facing to see what they sprayed.
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Include
			raycastParams.FilterDescendantsInstances = {playerPlot} -- Can only spray things on your own lot!

			local rayOrigin = rootPart.Position
			local rayDirection = rootPart.CFrame.LookVector * 12 -- 12 studs maximum spray distance

			local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
			if raycastResult and raycastResult.Instance then
				local hitInstance = raycastResult.Instance

				-- Identify if the targeted component belongs to a valid rack system
				local rackModel = hitInstance:FindFirstAncestorWithTag("RetailRack") 
					or (CollectionService:HasTag(hitInstance.Parent, "RetailRack") and hitInstance.Parent)

				if rackModel then
					-- Apply the sleek visual texture mutation to the boutique layout asset
					sprayEffectService.setSprayEffect(rackModel, toolName) 
					print(`[Spray Success] {player.Name} customized {rackModel.Name} with {toolName}!`)
				end
			end
		end
	end

	-- Deduct weapon asset from datastore layout cleanly using correct inventory key
	inventoryService.removeItem(player, itemKey, 1) 
end)

return SprayActivator