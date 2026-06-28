local BaseMutation = require(script.Parent.BaseMutationController)
local VampEra = {}

function VampEra.applyEffect(rack) BaseMutation.applyTemplate(rack, script) end
function VampEra.removeEffect(rack) BaseMutation.removeTemplate(rack) end

return VampEra