local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player: Player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local mainButtonsGui = playerGui:WaitForChild("MainButtonsGui")
local buildGui = playerGui:WaitForChild("Build")

local buildButton = mainButtonsGui.Buttons:WaitForChild("BuildButton")
local exitButton = buildGui:WaitForChild("ExitButton")

-- NotificationController BindableEvent for firing warnings
local notificationController = player:WaitForChild("PlayerScripts"):WaitForChild("NotificationController")
local notifyEvent = notificationController:WaitForChild("Notify")

--==================================================
-- CONFIG: Max distance from plot pivot to allow building
--==================================================
local MAX_BUILD_DISTANCE = 120 -- studs (plot base is 128x128, so 120 allows full plot coverage)

--==================================================
-- Find the player's assigned plot by USERID attribute
--==================================================
local function getPlayerPlot()
	for _, plot in ipairs(Workspace.Plots:GetChildren()) do
		if plot:IsA("Model") and plot:GetAttribute("USERID") == player.UserId then
			return plot
		end
	end
	return nil
end

--==================================================
-- Check if the player is close enough to their plot
--==================================================
local function isWithinBuildRange()
	local character = player.Character
	if not character then return false end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local plot = getPlayerPlot()
	if not plot then return false end

	local plotPivot = plot:GetPivot().Position
	local distance = (hrp.Position - plotPivot).Magnitude

	return distance <= MAX_BUILD_DISTANCE
end

buildButton.MouseButton1Click:Connect(function()
	-- Only check distance when OPENING the build menu (not when closing)
	if not buildGui.Enabled then
		if not isWithinBuildRange() then
			notifyEvent:Fire("Warning", "Too far from plot!")
			return
		end
	end

	buildGui.Enabled = not buildGui.Enabled
end)

exitButton.MouseButton1Click:Connect(function()
	buildGui.Enabled = false
end)
