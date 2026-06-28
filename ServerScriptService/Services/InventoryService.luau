local players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local modules = ReplicatedStorage:WaitForChild("Modules")
local toolStorage = ServerStorage:WaitForChild("SprayBottles")

local SprayData = require(modules.SprayData)

local Service = {
	mutationsEffectCache = {},
}


for _, v in modules.Mutations:GetChildren() do
	if v:IsA("ModuleScript") then
		Service.mutationsEffectCache[string.gsub(v.Name, " ", "")] = require(v) 
	end
end

function Service.generateSprayKey(sprayName: string)
	return sprayName .. ":" .. string.sub((HttpService:GenerateGUID(false)), 1, 8)
end

function Service.giveSpray(target: Player, sprayName: string, sprayAttributes: any)
	local dataService = Service.cachedModules.DataService
	local sprayData = SprayData.getData(sprayName)

	if target and sprayName and sprayAttributes and sprayData then
		local targetData = dataService.getData(target)
		if not targetData then return end

		local playerInventory = targetData.Inventory
		local mutations = sprayAttributes.Mutations or ""

		-- Save clean, user-readable strings with mutation prefixes
		local stringToSave = ""
		if mutations ~= "" then
			stringToSave = "[" .. mutations .. "] " .. sprayName
		else
			stringToSave = sprayName
		end

		local sprayKey = Service.generateSprayKey(sprayName)
		playerInventory[sprayKey] = stringToSave

		print(`[Inventory] Added Spray to {target.Name}: {stringToSave}`)
		Service.inventoryUpdated(target, sprayKey)
	end
end

function Service.removeItem(player: Player, itemName: string, count: number)
	if player and itemName and count then
		local dataService = Service.cachedModules.DataService
		local playerData = dataService.getData(player)

		if playerData then
			local inventory = playerData.Inventory
			local foundItem = inventory[itemName]

			if foundItem then
				local removeItem = false

				
				if typeof(foundItem) == "table" and foundItem.Count then
					foundItem.Count = math.clamp(foundItem.Count - 1, 0, math.huge)
					if foundItem.Count <= 0 then
						removeItem = true
					else
						Service.inventoryUpdated(player, itemName)
					end
				else
					removeItem = true
					
				end

				if removeItem then
					inventory[itemName] = nil

					
					local backpack = player.Backpack
					for _, v in ipairs(backpack:GetChildren()) do
						if v.Name == itemName or v:GetAttribute("sprayID") == itemName or v:GetAttribute("Name") == itemName then
							v:Destroy()
						end
					end

					
					local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
					if tool then
						if tool.Name == itemName or tool:GetAttribute("sprayID") == itemName or tool:GetAttribute("Name") == itemName then
							tool:Destroy()
						end
					end
				end
			end
		end
	end
end

function Service.createNewTool(player: Player, itemName: string)
	local dataService = Service.cachedModules.DataService
	local playerData = dataService.getData(player)
	local itemData = playerData and playerData.Inventory[itemName]
	if not itemData then return end

	local isGear = toolStorage:FindFirstChild(itemName)

	
	if isGear and typeof(itemData) == "table" and itemData.Count then
		local toolClone = isGear:Clone()
		toolClone.Name = itemName .. " (X" .. tostring(itemData.Count) .. ")"
		toolClone:SetAttribute("Name", itemName)
		toolClone:SetAttribute("Count", itemData.Count)
		toolClone:SetAttribute("isGear", true)

		toolClone.Parent = player.Backpack

		local gearActivator = script:FindFirstChild("GearActivator")
		if gearActivator then
			local activatorClone = gearActivator:Clone()
			activatorClone.Parent = toolClone
			require(activatorClone)
		end
		return
	end

	
	if typeof(itemData) == "string" then
		
		local mutations = {}
		local baseSprayName = itemData

		local prefix = string.match(itemData, "%[(.-)%]")
		if prefix then
			table.insert(mutations, prefix)
			baseSprayName = string.gsub(itemData, "%[.-%]%s*", "")
		end

		local foundModel = ReplicatedStorage.SprayModels:FindFirstChild(baseSprayName) 
		if foundModel then
			local toolClone = foundModel:Clone()
			toolClone.Name = itemData 
			toolClone:SetAttribute("sprayID", itemName) -- Assign the unique dictionary GUID key
			toolClone:SetAttribute("isSpray", true)

			
			task.spawn(function()
				for _, mutation in ipairs(mutations) do
					local cleanMutationName = string.gsub(mutation, " ", "")
					local effectModule = Service.mutationsEffectCache[cleanMutationName]
					if effectModule and effectModule.applyToolEffect then
						effectModule.applyToolEffect(toolClone)
					end
				end
			end)

			toolClone.Parent = player.Backpack
		end
	end
end

function Service.inventoryUpdated(player: Player, ...)
	local dataService = Service.cachedModules.DataService
	local playerData = dataService.getData(player)

	if playerData then
		local inventory = playerData.Inventory
		local arguments = {...}

		for _, itemUpdated in ipairs(arguments) do
			local foundItemInInventory = inventory[itemUpdated]
			if foundItemInInventory then

				local isGear = toolStorage:FindFirstChild(itemUpdated)

				if isGear and typeof(foundItemInInventory) == "table" then
					local foundItem = nil
					for _, v in ipairs(player.Backpack:GetChildren()) do
						if v:IsA("Tool") and v:GetAttribute("Name") == itemUpdated then
							foundItem = v
							break
						end
					end

					local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
					if tool and tool:GetAttribute("Name") == itemUpdated then
						foundItem = tool
					end

					if foundItem then
						foundItem.Name = itemUpdated .. " (X" .. tostring(foundItemInInventory.Count) .. ")"
						foundItem:SetAttribute("Count", foundItemInInventory.Count)
					else
						Service.createNewTool(player, itemUpdated)
					end
				else
					-- FIXED: Patched infinite backpack duplication loop by checking the unique sprayID attribute
					local toolExists = false
					for _, v in ipairs(player.Backpack:GetChildren()) do
						if v:GetAttribute("sprayID") == itemUpdated or v.Name == itemUpdated then
							toolExists = true
							break
						end
					end

					if not toolExists then
						local equippedTool = player.Character:FindFirstChildWhichIsA("Tool")
						if equippedTool and (equippedTool:GetAttribute("sprayID") == itemUpdated or equippedTool.Name == itemUpdated) then
							toolExists = true
						end
					end

					if not toolExists then
						Service.createNewTool(player, itemUpdated)
					end
				end
			end
		end
	end
end

function Service.characterAdded(character: Model)
	if typeof(character) ~= "Instance" or not character:IsA("Model") then return end
	local player = players:GetPlayerFromCharacter(character)
	if not player then return end

	local dataService = Service.cachedModules.DataService
	local playerData = dataService.getData(player)
	if not playerData then return end

	-- Re-populate player items cleanly upon respawning
	for itemName, _ in pairs(playerData.Inventory) do
		Service.createNewTool(player, itemName)
	end
end

function Service.init() end

return Service