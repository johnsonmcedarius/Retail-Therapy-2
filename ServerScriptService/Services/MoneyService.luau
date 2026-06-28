local replicatedStorage = game:GetService("ReplicatedStorage")
local debris = game:GetService("Debris")
local Players = game:GetService("Players")

local cachedModules = require(script.Parent.Parent.Server.CachedModules)
local remotes = replicatedStorage:WaitForChild("RemoteEvents")

local Service = {}

local MAX_FRIENDS = 2 
local BOOST_PER_FRIEND = 0.2 

local function updateFriendBoost(player: Player)
	local friendsInGame = 0

	pcall(function()
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player and player:IsFriendsWithAsync(otherPlayer.UserId) then
				friendsInGame += 1
				if friendsInGame >= MAX_FRIENDS then
					break
				end
			end
		end
	end)

	local boostMultiplier = 1 + (friendsInGame * BOOST_PER_FRIEND)
	local boostPercentage = math.floor((boostMultiplier - 1) * 100)
	player:SetAttribute("FriendBoost", boostMultiplier)

	if remotes:FindFirstChild("UpdateFriendBoost") then
		remotes.UpdateFriendBoost:FireClient(player, boostPercentage)
	end
end

function Service.updateLeaderstats(player: Player)
	-- FIXED: Correctly pathing to your cached DataService module
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(player)

	if profileData then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			-- Coins 
			local coinsValue = leaderstats:FindFirstChild("Coins")
			if coinsValue then
				coinsValue.Value = profileData.Coins or 0
			end

			-- Diamonds 
			local diamondsValue = leaderstats:FindFirstChild("Diamonds")
			if diamondsValue then
				diamondsValue.Value = profileData.Diamonds or 0
			end
		end
	end
end

function Service.dataLoaded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	-- Coins Setup
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 100000
	coins.Parent = leaderstats

	-- Diamonds Setup
	local diamonds = Instance.new("IntValue")
	diamonds.Name = "Diamonds"
	diamonds.Value = 100000
	diamonds.Parent = leaderstats

	leaderstats.Parent = player
	player:SetAttribute("FriendBoost", 1)

	Service.updateLeaderstats(player)
	updateFriendBoost(player)
end

-- ==========================================
-- COINS FUNCTIONS
-- ==========================================
function Service.giveCoins(target: Player, amount: number)
	-- FIXED: Path corrected
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData then
		local boostMultiplier = target:GetAttribute("FriendBoost") or 1
		local boostedAmount = math.floor(amount * boostMultiplier)

		profileData.Coins = (profileData.Coins or 0) + boostedAmount
		Service.updateLeaderstats(target)
	end
end

function Service.removeCoins(target: Player, amount: number)
	-- FIXED: Path corrected
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData then
		local currentCoins = profileData.Coins or 0
		if currentCoins >= amount then
			profileData.Coins = currentCoins - amount
			Service.updateLeaderstats(target)
			return true
		end
	end
	return false
end

function Service.hasEnoughCoins(target: Player, amount: number): boolean
	-- FIXED: Path corrected
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData then
		return (profileData.Coins or 0) >= amount
	end
	return false
end

-- ==========================================
-- DIAMONDS FUNCTIONS
-- ==========================================
function Service.hasEnoughDiamonds(target: Player, amount: number): boolean
	-- FIXED: Path corrected
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData then
		return (profileData.Diamonds or 0) >= amount
	end
	return false
end

function Service.giveDiamonds(target: Player, amount: number)
	-- FIXED: Path corrected
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData then
		profileData.Diamonds = (profileData.Diamonds or 0) + amount
		Service.updateLeaderstats(target)
	end
end

function Service.removeDiamonds(target: Player, amount: number)
	-- FIXED: Path corrected
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData then
		local currentDiamonds = profileData.Diamonds or 0
		if currentDiamonds >= amount then
			profileData.Diamonds = currentDiamonds - amount
			Service.updateLeaderstats(target)
			return true
		end
	end
	return false
end

-- ==========================================
-- SPRAY BOTTLES / INVENTORY HELPERS
-- ==========================================
function Service.giveSprayBottles(target: Player, amount: number)
	-- FIXED: Path corrected
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData then
		profileData.SprayBottles = (profileData.SprayBottles or 0) + amount
		print(target.Name .. " now has " .. profileData.SprayBottles .. " Spray Bottles")
	end
end

function Service.useSprayBottle(target: Player): boolean
	-- FIXED: Path corrected
	local DataService = cachedModules.Cache.DataService
	local profileData = DataService.getData(target)

	if profileData and profileData.SprayBottles and profileData.SprayBottles > 0 then
		profileData.SprayBottles -= 1
		return true
	end
	return false
end

-- ==========================================
-- INIT / CORE LOOPS
-- ==========================================
function Service.init()
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		updateFriendBoost(player)
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player and player:IsFriendsWithAsync(otherPlayer.UserId) then
				updateFriendBoost(otherPlayer)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			for _, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer ~= player then
					updateFriendBoost(otherPlayer)
				end
			end
		end)
	end)
end

return Service