local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
---------------------------------

--[[ SOUND CLICKING ]]--

local clickSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Click"):Clone()
clickSound.Parent = playerGui

local function playClickSound()
	clickSound.TimePosition = 0
	clickSound:Play()
end

for _, object in ipairs(playerGui:GetDescendants()) do
	if (object:IsA("TextButton") or object:IsA("ImageButton")) and CollectionService:HasTag(object, "Clicked") then
		object.MouseButton1Click:Connect(function()
			playClickSound()
		end)
	end
end

CollectionService:GetInstanceAddedSignal("Clicked"):Connect(function(object)
	if (object:IsA("TextButton") or object:IsA("ImageButton")) and object:IsDescendantOf(playerGui) then
		object.MouseButton1Click:Connect(function()
			playClickSound()
		end)
	end
end)

---------------------------------

--[[ HOVER EFFECT ]]--

local function applyHoverEffect(button)
	local SprayFrame = button:WaitForChild("SprayFrame")
	local viewportFrame = SprayFrame:WaitForChild("ViewportFrame")
	local model = viewportFrame:FindFirstChildWhichIsA("Model")

	if not model or not model:FindFirstChild("PrimaryPart") then
		warn("⚠️ Missing model or PrimaryPart in:", button.Name)
		return
	end

	local originalCamera = viewportFrame:FindFirstChild("ViewportCamera")
	local originalCFrame = originalCamera and originalCamera.CFrame

	local primaryPart = model.PrimaryPart
	local baseCenter = primaryPart.Position
	local baseSize = model:GetExtentsSize().Magnitude
	local baseZoom = baseSize / 2 + 1
	local closerZoom = baseZoom + 0.10

	local bounceTimer = 0
	local connection
	local hoverCam

	button.MouseEnter:Connect(function()
		hoverCam = Instance.new("Camera")
		hoverCam.Name = "HoverCamera"
		viewportFrame.CurrentCamera = hoverCam
		hoverCam.Parent = viewportFrame

		connection = RunService.RenderStepped:Connect(function(dt)
			bounceTimer += dt * 6
			local offsetZ = math.sin(bounceTimer) * 0.1
			local angleX = math.sin(bounceTimer * 1.2) * math.rad(1.5)
			local angleY = math.cos(bounceTimer * 1.5) * math.rad(1.5)

			local camPos = baseCenter + Vector3.new(0, 0, closerZoom + offsetZ)
			local jiggleRotation = CFrame.Angles(angleX, angleY, 0)

			if hoverCam then
				hoverCam.CFrame = CFrame.new(camPos, baseCenter) * jiggleRotation
			end
		end)
	end)

	button.MouseLeave:Connect(function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if hoverCam then
			hoverCam:Destroy()
			hoverCam = nil
		end

		local restoreCam = Instance.new("Camera")
		restoreCam.Name = "ViewportCamera"
		restoreCam.CFrame = originalCFrame or CFrame.new(baseCenter + Vector3.new(0, 0, baseZoom), baseCenter)
		viewportFrame.CurrentCamera = restoreCam
		restoreCam.Parent = viewportFrame
	end)
end

for _, object in ipairs(playerGui:GetDescendants()) do
	if (object:IsA("TextButton") or object:IsA("ImageButton")) and CollectionService:HasTag(object, "Hover") then
		applyHoverEffect(object)
	end
end

CollectionService:GetInstanceAddedSignal("Hover"):Connect(function(object)
	if (object:IsA("TextButton") or object:IsA("ImageButton")) and object:IsDescendantOf(playerGui) then
		applyHoverEffect(object)
	end
end)

----------------------------------------------------------

--[[ CURRENCY NOTIFICATIONS ]]--

local screenGui = playerGui:WaitForChild("Currency") 
local coinLabel = screenGui:WaitForChild("CoinLabel")
local diamondLabel = screenGui:WaitForChild("DiamondLabel")

local coinSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Coins"):Clone()
coinSound.Parent = playerGui

local diamondSound = ReplicatedStorage:WaitForChild("Sounds"):WaitForChild("Coins"):Clone() -- Swap to a gem sound later if you want!
diamondSound.Parent = playerGui

-- Dynamic Smart Formatter: Commas for small numbers, Suffixes for 1M+
local function formatNumber(n)
	local absN = math.abs(n)

	if absN < 1000000 then
		-- Standard comma formatting (e.g., 999,999)
		return tostring(n):reverse():gsub("%d%d%d", "%0,"):reverse():gsub("^,", "")
	else
		-- Tycoon Suffix formatting (M, B, T, etc.)
		local suffixes = {"", "K", "M", "B", "T", "Qa", "Qi"}
		local index = math.floor(math.log10(absN) / 3) + 1
		index = math.clamp(index, 1, #suffixes)

		local suffix = suffixes[index]
		local shortVal = n / (10 ^ ((index - 1) * 3))

		-- Keeps up to 2 clean decimal places (e.g., 1.25M instead of 1.250000M)
		return string.format("%.2f", shortVal):gsub("%.?0+$", "") .. suffix
	end
end

-- Generates floating text popups dynamically for both currencies
local function createFloatingText(amount, targetLabel, isDiamond)
	local floatingLabel = targetLabel:Clone()
	floatingLabel.Text = ""
	floatingLabel.Name = "FloatingVisual"
	floatingLabel.Parent = screenGui

	local basePos = targetLabel.Position
	floatingLabel.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale - 0.05, basePos.Y.Offset)
	floatingLabel.AnchorPoint = targetLabel.AnchorPoint
	floatingLabel.BackgroundTransparency = 1
	floatingLabel.TextStrokeTransparency = 0.6
	floatingLabel.TextScaled = true

	if amount > 0 then
		floatingLabel.Text = "+" .. formatNumber(amount)
		-- Electric cyan for diamonds, bright green for coins
		floatingLabel.TextColor3 = isDiamond and Color3.fromRGB(0, 225, 255) or Color3.fromRGB(0, 255, 0)
	else
		floatingLabel.Text = "-" .. formatNumber(math.abs(amount))
		floatingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
	end

	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenGoal = {
		Position = UDim2.new(basePos.X.Scale, basePos.X.Offset, basePos.Y.Scale - 0.1, basePos.Y.Offset),
		TextTransparency = 1,
		TextStrokeTransparency = 1
	}

	local tween = TweenService:Create(floatingLabel, tweenInfo, tweenGoal)
	tween:Play()

	tween.Completed:Connect(function()
		floatingLabel:Destroy()
	end)
end

-- Animates number rolling up/down smoothly
local function animateCurrencyLabel(label, startValue, endValue, duration, prefix)
	local startTime = os.clock()
	local connection

	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local alpha = math.clamp((now - startTime) / duration, 0, 1)
		local currentValue = math.floor(startValue + (endValue - startValue) * alpha)
		label.Text = prefix .. formatNumber(currentValue)

		if alpha >= 1 then
			label.Text = prefix .. formatNumber(endValue)
			connection:Disconnect()
		end
	end)
end

-- Track and update Coins stat
local function setupCoinsTracker()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = player:WaitForChild("leaderstats", 10)
	end
	if not leaderstats then
		warn("[UIEffects] leaderstats not found after 10s, coins tracker aborted.")
		return
	end
	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then
		coins = leaderstats:WaitForChild("Coins", 10)
	end
	if not coins then return end
	local lastCoins = coins.Value

	coinLabel.Text = "$" .. formatNumber(lastCoins)

	coins:GetPropertyChangedSignal("Value"):Connect(function()
		local newCoins = coins.Value
		local diff = newCoins - lastCoins

		animateCurrencyLabel(coinLabel, lastCoins, newCoins, 0.6, "$")
		coinSound:Play()

		if diff ~= 0 then
			createFloatingText(diff, coinLabel, false)
		end

		lastCoins = newCoins
	end)
end

-- Track and update Diamonds stat
local function setupDiamondsTracker()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = player:WaitForChild("leaderstats", 10)
	end
	if not leaderstats then
		warn("[UIEffects] leaderstats not found after 10s, diamonds tracker aborted.")
		return
	end
	local diamonds = leaderstats:FindFirstChild("Diamonds")
	if not diamonds then
		diamonds = leaderstats:WaitForChild("Diamonds", 10)
	end
	if not diamonds then return end
	local lastDiamonds = diamonds.Value

	diamondLabel.Text = formatNumber(lastDiamonds)

	diamonds:GetPropertyChangedSignal("Value"):Connect(function()
		local newDiamonds = diamonds.Value
		local diff = newDiamonds - lastDiamonds

		animateCurrencyLabel(diamondLabel, lastDiamonds, newDiamonds, 0.6, "")
		diamondSound:Play()

		if diff ~= 0 then
			createFloatingText(diff, diamondLabel, true)
		end

		lastDiamonds = newDiamonds
	end)
end

-- Start both tracking loops safely
setupCoinsTracker()
setupDiamondsTracker()