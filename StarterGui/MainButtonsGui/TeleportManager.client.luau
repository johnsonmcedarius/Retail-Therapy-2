
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local buttons = script.Parent:WaitForChild("Buttons")
local player = Players.LocalPlayer
local TeleportEvent = ReplicatedStorage.RemoteEvents:WaitForChild("Teleport")

local SHOP_ICON = "http://www.roblox.com/asset/?id=96226541857519"
local HOME_ICON = "http://www.roblox.com/asset/?id=13060262529"


local function getMyBoutique()
	for _, boutique in ipairs(workspace.Plots:GetChildren()) do
		
		if boutique:GetAttribute("USERID") == player.UserId then
			return boutique
		end
	end
	return nil
end

local function isPlayerAtBoutique(boutique)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local plotFloor = boutique:FindFirstChild("Floor") or boutique:FindFirstChild("SpawnLocation")
	if plotFloor then
		
		local distance = (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(plotFloor.Position.X, plotFloor.Position.Z)).Magnitude
		return distance <= 80 
	end
	return false
end

local function updateButtonVisuals(button)
	local boutique = getMyBoutique()
	local textLabel = button:FindFirstChild("TextLabel")
	local logoLabel = button:FindFirstChild("ImageLabel")

	if boutique and isPlayerAtBoutique(boutique) then
		if logoLabel then logoLabel.Image = SHOP_ICON end
		if textLabel then textLabel.Text = "SHOP" end
	else
		if logoLabel then logoLabel.Image = HOME_ICON end
		if textLabel then textLabel.Text = "HOME" end
	end
end


for _, button in ipairs(buttons:GetChildren()) do
	if button.Name == "TeleportButton" and button:IsA("ImageButton") then

		
		task.spawn(function()
			while task.wait(0.1) do
				updateButtonVisuals(button)
			end
		end)

		
		button.MouseButton1Click:Connect(function()
			local boutique = getMyBoutique()

			if boutique then
				if isPlayerAtBoutique(boutique) then
					
					local shopZone = workspace:FindFirstChild("Shop") and workspace.Shop:FindFirstChild("SpawnLocation")
					if shopZone then
						TeleportEvent:FireServer(shopZone.Position)
					end
				else
					
					local homeSpawn = boutique:FindFirstChild("SpawnLocation")
					if homeSpawn then
						TeleportEvent:FireServer(homeSpawn.Position)
					end
				end
			end
		end)
	end
end