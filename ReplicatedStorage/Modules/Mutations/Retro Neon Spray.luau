local BaseMutation = require(script.Parent.BaseMutationController)
local RetroNeon = {}

function RetroNeon.applyEffect(rack) BaseMutation.applyTemplate(rack, script) end
function RetroNeon.removeEffect(rack) BaseMutation.removeTemplate(rack) end

return RetroNeon