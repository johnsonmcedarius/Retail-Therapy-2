--[==[
	NotificationController (LocalScript)
	=====================================
	Modular notification system that clones template labels from the Notifications ScreenGui,
	stacks them via UIListLayout, and handles fade-out + destruction automatically.

	HOW TO ADD A NEW NOTIFICATION TYPE:
		1. Create a TextLabel template inside StarterGui.Notifications.NotificationContainer
		2. Add an entry to the NOTIFICATION_CONFIG table below
		3. (Optional) Add a Sound to ReplicatedStorage.Sounds and reference it
		4. Fire it via RemoteEvent, the BindableEvent, or from another script

	TRIGGERING NOTIFICATIONS FROM OTHER SCRIPTS:
		-- Via BindableEvent (any LocalScript):
		local controller = player.PlayerScripts:WaitForChild("NotificationController")
		controller.Notify:Fire("Warning", "You have been warned!")

		-- Via RemoteEvent (server fires to client):
		RemoteEvents.Purchase:FireClient(player, "Vamp Era Spray")
]==]

--==================================================
-- SERVICES
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

--==================================================
-- NOTIFICATION CONFIG — Add new types here!
--==================================================
-- Each entry:
--   template     (string)  : Name of the TextLabel template in NotificationContainer
--   sound        (string?) : Name of the Sound in ReplicatedStorage.Sounds (nil = silent)
--   duration     (number)  : Seconds the notification stays fully visible before fading out
--   fadeInTime   (number)  : Fade-in tween duration in seconds
--   fadeOutTime  (number)  : Fade-out tween duration in seconds

local NOTIFICATION_CONFIG = {
	Restock = {
		template = "RestockNotifications",
		sound = "Restock",
		duration = 2.5,
		fadeInTime = 0.5,
		fadeOutTime = 0.5,
	},
	Purchase = {
		template = "PurchaseNotification",
		sound = "Purchase",
		duration = 2.5,
		fadeInTime = 0.5,
		fadeOutTime = 0.5,
	},
	Decline = {
		template = "DeclineNotification",
		sound = "Coins", -- Placeholder; swap for a dedicated decline sound when available
		duration = 2.5,
		fadeInTime = 0.5,
		fadeOutTime = 0.5,
	},
	Weather = {
		template = "WeatherNotification",
		sound = nil, -- Add a weather sound when available
		duration = 3,
		fadeInTime = 0.5,
		fadeOutTime = 0.5,
	},
	Warning = {
		template = "WarningNotification",
		sound = nil, -- Add a warning sound when available
		duration = 3,
		fadeInTime = 0.5,
		fadeOutTime = 0.5,
	},
	Player = {
		template = "PlayerNotification",
		sound = nil, -- Add a player event sound when available
		duration = 3,
		fadeInTime = 0.5,
		fadeOutTime = 0.5,
	},
	GlobalPlayer = {
		template = "GlobalPlayerNotification",
		sound = nil, -- Add a global event sound when available
		duration = 3.5,
		fadeInTime = 0.5,
		fadeOutTime = 0.5,
	},
}

--==================================================
-- REFERENCES
--==================================================
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local Sounds = ReplicatedStorage:WaitForChild("Sounds")

--==================================================
-- CORE: Get the container fresh (ScreenGui resets on spawn)
--==================================================
local function getContainer()
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return nil end
	local notificationsGui = gui:FindFirstChild("Notifications")
	if not notificationsGui then return nil end
	return notificationsGui:FindFirstChild("NotificationContainer")
end

--==================================================
-- CORE: showNotification(typeName, text)
--==================================================
local layoutOrderCounter = 0

local function showNotification(typeName, text)
	local config = NOTIFICATION_CONFIG[typeName]
	if not config then
		warn("[NotificationController] Unknown notification type:", tostring(typeName))
		return
	end

	local container = getContainer()
	if not container then
		warn("[NotificationController] NotificationContainer not found")
		return
	end

	local template = container:FindFirstChild(config.template)
	if not template then
		warn("[NotificationController] Template not found:", config.template)
		return
	end

	-- Clone the template
	local clone = template:Clone()
	clone.Name = config.template .. "_" .. tostring(layoutOrderCounter)
	clone.Text = text or ""
	clone.TextTransparency = 1
	clone.Visible = true
	clone.LayoutOrder = layoutOrderCounter
	layoutOrderCounter += 1
	clone.Parent = container

	-- Play associated sound
	if config.sound then
		local sound = Sounds:FindFirstChild(config.sound)
		if sound then
			-- Clone the sound so overlapping notifications don't cut each other off
			local soundClone = sound:Clone()
			soundClone.Parent = clone
			soundClone:Play()
			task.delay(soundClone.TimeLength > 0 and soundClone.TimeLength or 5, function()
				soundClone:Destroy()
			end)
		end
	end

	-- Fade in → hold → fade out → destroy
	task.spawn(function()
		local fadeIn = TweenService:Create(clone, TweenInfo.new(config.fadeInTime), {TextTransparency = 0})
		local fadeOut = TweenService:Create(clone, TweenInfo.new(config.fadeOutTime), {TextTransparency = 1})

		fadeIn:Play()
		fadeIn.Completed:Wait()

		task.wait(config.duration)

		-- Guard against the clone being destroyed early (e.g. ScreenGui reset on respawn)
		if not clone.Parent then return end

		fadeOut:Play()
		fadeOut.Completed:Wait()

		clone:Destroy()
	end)
end

--==================================================
-- BINDABLE EVENT — Public API for other LocalScripts
--==================================================
local notifyBindable = Instance.new("BindableEvent")
notifyBindable.Name = "Notify"
notifyBindable.Parent = script

notifyBindable.Event:Connect(function(typeName, text)
	showNotification(typeName, text)
end)

--==================================================
-- REMOTE EVENT HOOKS
--==================================================

-- Restock Notification (fired by SprayShopService on server restock)
RemoteEvents.ResetSprayShop.OnClientEvent:Connect(function(sprayData, isRestock)
	if isRestock then
		showNotification("Restock", "Spray Grounds have been restocked!")
	end
end)

-- Purchase Notification (fired by server on successful purchase)
-- If the server sends an item name, it will display dynamically; otherwise a generic message is shown.
RemoteEvents.Purchase.OnClientEvent:Connect(function(itemName)
	if itemName and itemName ~= "" then
		showNotification("Purchase", "Purchased " .. tostring(itemName) .. "!")
	else
		showNotification("Purchase", "Purchase Successful!")
	end
end)

-- Customer Notification (VIP customer entered the store, fired by NPCController)
RemoteEvents.CustomerNotification.OnClientEvent:Connect(function(customerType, message)
	showNotification("Player", message)
end)

-- Weather Notification (placeholder — uncomment when WeatherChanged RemoteEvent is created)
-- local weatherChanged = RemoteEvents:FindFirstChild("WeatherChanged")
-- if weatherChanged then
-- 	weatherChanged.OnClientEvent:Connect(function(weatherName)
-- 		showNotification("Weather", tostring(weatherName) .. " event has started!")
-- 	end)
-- end

--==================================================
-- READY
--==================================================
-- Other scripts can now fire notifications via:
--   script.Parent.NotificationController.Notify:Fire("Warning", "Text here")

