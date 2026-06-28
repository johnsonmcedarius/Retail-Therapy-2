--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

--// Assets
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")

--// Player
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

--// State
local activeUI = {
	Highlight = nil
}

--// Toggle Prompts Utility
local function toggleAllPrompts(enable)
	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			if not enable then
				-- Blindly disable absolutely everything when a fullscreen UI opens
				prompt.Enabled = false
			else
				-- FIXED: When closing UI, do NOT blindly enable rack prompts.
				-- Let your RackPromptController handle them natively based on tools/stock!
				if prompt.Name ~= "RetailSprayPrompt" and prompt.Name ~= "RetailRestockPrompt" then
					prompt.Enabled = true
				end
			end
		end
	end
end

--// Object Highlighting (Shop Counter / Models)
local function highlightModel(model)
	if activeUI.Highlight then activeUI.Highlight:Destroy() end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = Color3.new(1, 1, 1) -- Clean white outline
	hl.OutlineTransparency = 0
	hl.Adornee = model
	hl.Parent = model
	activeUI.Highlight = hl
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	-- Highlights the counter model the prompt is nested inside
	local model = prompt.Parent.Parent
	if model and model:IsA("Model") then
		highlightModel(model)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if activeUI.Highlight then
		activeUI.Highlight:Destroy()
		activeUI.Highlight = nil
	end
end)

--// Spray Shop GUI Handlers
local ShopUI = PlayerGui:WaitForChild("Shop"):WaitForChild("ShopFrame")
local closeShopBtn = ShopUI:WaitForChild("CloseShop")
local blur = game.Lighting:WaitForChild("Blur")

local function toggleBlur(enable)
	TweenService:Create(blur, TweenInfo.new(0.3), {Size = enable and 15 or 0}):Play()
end

local function showShopUI()
	ShopUI.Size = UDim2.new(0, 0, 0, 0)
	ShopUI.Visible = true
	toggleBlur(true)
	TweenService:Create(ShopUI, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0.414, 0, 0.8, 0)}):Play()
end

local function hideShopUI()
	TweenService:Create(ShopUI, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)}):Play()
	toggleBlur(false)
	task.delay(0.2, function()
		ShopUI.Visible = false
	end)
end

closeShopBtn.MouseButton1Click:Connect(hideShopUI)

--// Global Proximity Prompt Trigger Tracking
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
	if triggeredPlayer ~= player then return end

	-- Instant open action for your main Shop UI[cite: 12]
	if prompt.Name == "OpenShop" then
		toggleAllPrompts(false)
		showShopUI()
		closeShopBtn.MouseButton1Click:Once(function()
			toggleAllPrompts(true)
		end)
	end
end)