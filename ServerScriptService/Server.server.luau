local servicesFolder = script.Parent.Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StartTime = os.clock()

local cachedModules = {}

for _, moduleScript: ModuleScript in servicesFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		cachedModules[moduleScript.Name] = require(moduleScript)
	end
end

local requiredModule = require(script.CachedModules) 
requiredModule.Cache = cachedModules


for moduleName, moduleScript in cachedModules do
	moduleScript.cachedModules = cachedModules
end

for moduleName, moduleScript in cachedModules do
	if typeof(moduleScript.init) == "function" then
		moduleScript.init()
	end
end

ReplicatedStorage.RemoteEvents.Teleport.OnServerEvent:Connect(function(plr, Position)
	plr.Character:WaitForChild("HumanoidRootPart").Position = Position
end)