local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local remotes = replicatedStorage.RemoteEvents

local profileStore = require(script.ProfileStore)
local profileTemplate = require(script.Template)
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local PlayerStore = profileStore.New("PlayerStore_006", profileTemplate)

local Service = {
	Profiles = {}
}

function Service.getData(target:Player)
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		warn("getData was called with an invalid argument:", target)
		print(debug.traceback("getData traceback →"))
	end
	if not target:GetAttribute("DataLoaded") then return nil end
	local profile = Service.Profiles[target]
	if profile then
		--print(profile.Data)
		return profile.Data
	end
	return nil
end

function Service.init()

	local moneyService = cachedModules.Cache.MoneyService
	local plotService = cachedModules.Cache.PlotService
	local inventoryService = cachedModules.Cache.InventoryService

	local function onCharacterAdded(character: Model)
		inventoryService.characterAdded(character)
	end

	local function dataLoaded(player:Player)
		local profile = Service.Profiles[player]
		if profile then
			moneyService.dataLoaded(player)
			plotService.dataLoaded(player)

			if player.Character then
				onCharacterAdded(player.Character)
			end
			player.CharacterAdded:Connect(onCharacterAdded)
		end
	end

	local function playerAdded(player:Player)
		local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
			Cancel = function()
				return player.Parent ~= players
			end,
		})

		if profile ~= nil then
			profile:AddUserId(player.UserId) 
			profile:Reconcile() 

			profile.OnSessionEnd:Connect(function()
				Service.Profiles[player] = nil
				player:Kick(`Profile session end - Please rejoin`)
			end)
			if player.Parent == players then
				Service.Profiles[player] = profile
				print(`Profile loaded for {player.DisplayName}!`)

				-- Player Data Loaded

				player:SetAttribute("DataLoaded", true)
				dataLoaded(player)

			else
				profile:EndSession()
			end
		else
			player:Kick(`Profile load fail - Please rejoin`)
		end
	end

	local function playerRemoved(player:Player)
		local profile = Service.Profiles[player]
		if profile ~= nil then
			plotService.playerRemoved(player)
			profile:EndSession()
		end
	end

	players.PlayerAdded:Connect(playerAdded)
	players.PlayerRemoving:Connect(playerRemoved)

	for _,player: Player in players:GetPlayers() do
		playerAdded(player)
	end

end

return Service
