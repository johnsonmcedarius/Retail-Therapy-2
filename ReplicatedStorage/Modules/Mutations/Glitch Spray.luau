local BaseMutation = require(script.Parent.BaseMutationController)
local Glitch = {}

function Glitch.applyEffect(rack) BaseMutation.applyTemplate(rack, script) end
function Glitch.removeEffect(rack) BaseMutation.removeTemplate(rack) end

return Glitch