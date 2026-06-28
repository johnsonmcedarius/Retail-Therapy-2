local gradient = script.Parent

if gradient then
	while true do
		for i = 0, 1, 0.001 do
			gradient.Rotation = i * 360
			task.wait(0.001)
		end
	end
end