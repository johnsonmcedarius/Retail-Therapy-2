local BaseMutation = require(script.Parent.BaseMutationController)
local VelvetSuede = {}

function VelvetSuede.applyEffect(rack) BaseMutation.applyTemplate(rack, script) end
function VelvetSuede.removeEffect(rack) BaseMutation.removeTemplate(rack) end

return VelvetSuede