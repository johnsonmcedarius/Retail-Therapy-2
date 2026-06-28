local SprayData = {
	cachedModules = {},
	SprayOrder = {
		"Dew Drop Spray",
		"Velvet Suede Spray",
		"Retro Neon Spray",
		"Chameleon Spray",
		"Liquid Chrome Spray",
		"Glitch Spray",
		"Cosmic Spray",
		"Vamp Era Spray"
	}
}

function SprayData.getSprayOrder()
	return SprayData.SprayOrder 
end

function SprayData.getData(sprayName: string)

	return script:FindFirstChild(sprayName) or nil
end

return SprayData