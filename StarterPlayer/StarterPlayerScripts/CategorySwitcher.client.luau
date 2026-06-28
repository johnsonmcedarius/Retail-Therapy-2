local Players = game:GetService("Players")

local player: Player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local buildGui = playerGui:WaitForChild("Build")
local buttonsFrame = buildGui:WaitForChild("Buttons")

-- Map each category button name to its scrolling frame name (Build Mode)
local categories = {
	Furniture = "Furniture",
	Decorations = "Decorations",
	Construction = "Construction",
	Inventory = "Inventory",
}

local function showCategory(categoryName: string)
	for buttonName, frameName in categories do
		local frame = buildGui:FindFirstChild(frameName)
		if frame then
			frame.Visible = (buttonName == categoryName)
		end
	end
end

-- When the Build menu is opened, always default to Furniture
buildGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if buildGui.Enabled then
		showCategory("Furniture")
	end
end)

-- Connect each category button
for buttonName in categories do
	local button = buttonsFrame:FindFirstChild(buttonName)
	if button then
		button.MouseButton1Click:Connect(function()
			showCategory(buttonName)
		end)
	end
end