local RunService = game:GetService("RunService")
local BaseMutation = {}
local activeRacks = {}

local VISIBLE_FACES = { Enum.NormalId.Front, 
	Enum.NormalId.Back, 
	Enum.NormalId.Left, 
	Enum.NormalId.Right, 
	Enum.NormalId.Top, 
	Enum.NormalId.Bottom }

function BaseMutation.applyTemplate(rack: Model, effectScriptInstance)
	if activeRacks[rack] then return end 

	-- Find the designated canvas part or fallback to a primary part safely
	local basePart = rack:FindFirstChild("RackTexture") or rack.PrimaryPart or rack:FindFirstChildWhichIsA("BasePart")
	if not basePart then return end

	local trackingData = { Textures = {}, Attachment = nil, Connection = nil }

	
	for _, child in ipairs(rack:GetDescendants()) do
		if (child:IsA("MeshPart") or child:IsA("Part")) and child.Name == "RackTexture" then
			if effectScriptInstance:FindFirstChild("MovingTexture") then
				for _, face in ipairs(VISIBLE_FACES) do
					local newTexture = effectScriptInstance.MovingTexture:Clone()
					newTexture.Face = face
					newTexture.Parent = child
					table.insert(trackingData.Textures, newTexture)
				end
			else
				warn(`[Mutation Error] Missing 'MovingTexture' template inside {effectScriptInstance.Name}!`)
			end
		end
	end

	-- 🛠️ FIX 2: Bulletproof Asset Safe-Check (No more breaking the script if missing!)
	local assetsFolder = effectScriptInstance:FindFirstChild("Assets")
	local particleTemplate = assetsFolder and assetsFolder:FindFirstChild("BoutiqueSprayEffect")

	if particleTemplate then
		local clonedAttachment = particleTemplate:Clone()
		clonedAttachment.Parent = basePart
		trackingData.Attachment = clonedAttachment
	else
		print(`[Mutation Info] No particles found for {effectScriptInstance.Name}, skipping attachment setup.`)
	end

	-- Custom speed modifiers
	local scrollSpeedX = effectScriptInstance:GetAttribute("ScrollSpeedX") or 0.02
	local scrollSpeedY = effectScriptInstance:GetAttribute("ScrollSpeedY") or -0.15

	trackingData.Connection = RunService.RenderStepped:Connect(function(dt)
		local moveX = scrollSpeedX * (dt * 60) -- Normalized for frame rates
		local moveY = scrollSpeedY * (dt * 60)
		for _, texture in ipairs(trackingData.Textures) do
			if texture.Parent then
				texture.OffsetStudsU += moveX
				texture.OffsetStudsV += moveY
			end
		end
	end)

	activeRacks[rack] = trackingData
end

function BaseMutation.removeTemplate(rack: Model)
	local trackingData = activeRacks[rack]
	if not trackingData then return end

	if trackingData.Connection then trackingData.Connection:Disconnect() end
	for _, texture in ipairs(trackingData.Textures) do if texture then texture:Destroy() end end
	if trackingData.Attachment then trackingData.Attachment:Destroy() end
	activeRacks[rack] = nil
end

return BaseMutation