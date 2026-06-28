local Monetization = {}

-- DevProducts (Single items)
Monetization.DevProducts = {
	RestockShop = 3605784130,
}

-- Currency Packages
Monetization.Coins = {
	["Pocket Change"]     = { ID = 0, Amount = 1000 },
	["Boutique Budget"]   = { ID = 0, Amount = 5000 },
	["Store Funding"]     = { ID = 0, Amount = 12000 },
	["Luxury Capital"]    = { ID = 0, Amount = 35000 },
	["Millionaire Edge"]  = { ID = 0, Amount = 100000 },
}

Monetization.Diamonds = {
	["Handful"]          = { ID = 0, Amount = 10 },
	["Pouch"]            = { ID = 0, Amount = 50 },
	["Jewelry Box"]      = { ID = 0, Amount = 120 },
	["Boutique Vault"]   = { ID = 0, Amount = 500 },
	["Centauri Fortune"] = { ID = 0, Amount = 1200 },
}

-- Spray Bundles (Special bulk value packs)
Monetization.Bundles = {
	["Starter Pack"] = {
		ID = 0,
		Items = {
			{ Name = "Dew Drop Spray", Count = 3 },
			{ Name = "Velvet Suede Spray", Count = 1 }
		}
	},
	["Hypebeast Bundle"] = {
		ID = 0,
		Items = {
			{ Name = "Retro Neon Spray", Count = 2 },
			{ Name = "Liquid Chrome Spray", Count = 2 }
		}
	},
	["Luxury Vault Drop"] = {
		ID = 0,
		Items = {
			{ Name = "Cosmic Spray", Count = 1 },
			{ Name = "Vamp Era Spray", Count = 1 }
		}
	}
}

-- Gamepasses (Persistent unlocks)
Monetization.Gamepasses = {
	VIP = 1151017770,
}

-- Badges
Monetization.Badges = {
	Welcome = 1151017770,
	Level10 = 1151017770,
	Level20 = 1151017770,
	Level30 = 1151017770,
	Level40 = 1151017770,
	Level50 = 1151017770,
	Level60 = 1151017770,
	Level70 = 1151017770,
}

return Monetization