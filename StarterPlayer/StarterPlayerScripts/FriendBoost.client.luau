local Players = game:GetService("Players")
local player = Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local remotes = replicatedStorage:WaitForChild("RemoteEvents")

remotes.UpdateFriendBoost.OnClientEvent:Connect(function(boostPercentage)
	local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("MainButtonsGui")
	local friendBoostLabel = mainGui:WaitForChild("FriendBoost")

	-- Enable the GUI if it's not currently enabled
	if not friendBoostLabel.Visible then
		friendBoostLabel.Visible = true
	end

	friendBoostLabel.Text = `Friend Boost: +{boostPercentage}%`
end)
