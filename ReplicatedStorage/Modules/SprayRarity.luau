local replicatedStorage = game:GetService("ReplicatedStorage")
local GradientFolder = replicatedStorage:WaitForChild("RarityGradients")

local SprayRarity = {
	Common = Color3.fromRGB(58, 205, 255),
	Uncommon = Color3.fromRGB(255, 170, 0),
	Rare = Color3.fromRGB(221, 0, 255),
	Epic = Color3.fromRGB(255, 213, 0),
	Legendary = GradientFolder:WaitForChild("Legendary")
}

return SprayRarity