local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player: Player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local mainButtonsGui = playerGui:WaitForChild("MainButtonsGui")
local buildGui = playerGui:WaitForChild("Build")

local buildButton = mainButtonsGui.Buttons:WaitForChild("BuildButton")
local exitButton = buildGui:WaitForChild("ExitButton")

buildButton.MouseButton1Click:Connect(function()
	buildGui.Enabled = not buildGui.Enabled
end)

exitButton.MouseButton1Click:Connect(function()
	buildGui.Enabled = false
end)