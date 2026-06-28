local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local modules = ReplicatedStorage:WaitForChild("Modules")
local SprayData = require(modules:WaitForChild("SprayData"))
local cachedModules = require(script.Parent.Parent.Server.CachedModules)

local SprayEffectService = {}

-- Multiplier config layout for NPC checkout math & purchase math
local SPRAY_MULTIPLIERS = {
	["None"] = 1.0,
	["Dew Drop Bottle"] = 1.2,
	["Velvet Suede Bottle"] = 1.5,
	["Retro Neon Bottle"] = 2.0,
	["Chameleon Bottle"] = 2.5,
	["Liquid Chrome Bottle"] = 3.0,
	["Glitch Bottle"] = 4.5,
	["Cosmic Bottle"] = 6.0,
	["Vamp Era Bottle"] = 10.0,

	-- Fallback variants to protect against naming discrepancies
	["Dew Drop Spray"] = 1.2,
	["Velvet Suede Spray"] = 1.5,
	["Retro Neon Spray"] = 2.0,
	["Chameleon Spray"] = 2.5,
	["Liquid Chrome Spray"] = 3.0,
	["Glitch Spray"] = 4.5,
	["Cosmic Spray"] = 6.0,
	["Vamp Era Spray"] = 10.0,

	["Dew Drop"] = 1.2,
	["Velvet Suede"] = 1.5,
	["Retro Neon"] = 2.0,
	["Chameleon"] = 2.5,
	["Liquid Chrome"] = 3.0,
	["Glitch"] = 4.5,
	["Cosmic"] = 6.0,
	["Vamp Era"] = 10.0,
}

-- ==========================================
-- STATE MANAGEMENT FUNCTIONS
-- ==========================================

--[[
	Applies a spray effect name to a rack instance via attributes.
	Example: SprayEffectService.setSprayEffect(rack, "Glitch Spray")
--]]
function SprayEffectService.setSprayEffect(rack: Instance, sprayName: string)
	if not rack then 
		warn("Cannot apply spray: Target rack instance is nil")
		return 
	end

	-- If clearing the spray or setting to none
	if not sprayName or sprayName == "" or sprayName == "None" then
		rack:SetAttribute("SprayEffect", "None")
		return
	end

	-- Validation check against SprayData module to ensure the spray exists
	local validSprays = SprayData.getSprayOrder()
	if table.find(validSprays, sprayName) then
		rack:SetAttribute("SprayEffect", sprayName)
		print(`[Server State] Applied {sprayName} attribute to {rack.Name}`)
	else
		warn("⚠️ Attempted to apply invalid spray effect name: " .. tostring(sprayName))
	end
end

--[[
	Gets the current active spray effect on a rack.
	Returns a string (e.g., "Glitch Spray" or "None")
--]]
function SprayEffectService.getSprayEffect(rack: Instance): string
	if not rack then return "None" end
	return rack:GetAttribute("SprayEffect") or "None"
end

--[[
	Calculates income multiplier based on active spray.
	Your upcoming Customer Pathfinding/Purchase AI will call this directly for cash updates!
--]]
function SprayEffectService.getMultiplier(rack: Instance): number
	if not rack then return 1.0 end
	local currentEffect = rack:GetAttribute("SprayEffect") or "None"
	return SPRAY_MULTIPLIERS[currentEffect] or 1.0
end

--[[
	Clears the spray effect off a rack completely.
--]]
function SprayEffectService.clearSprayEffect(rack: Instance)
	if rack then
		rack:SetAttribute("SprayEffect", "None")
	end
end

-- ==========================================
-- INIT / CORE LOOPS
-- ==========================================
function SprayEffectService.init()
	print("SprayEffectService Successfully Initialized!")
end

return SprayEffectService