local BaseMutation = require(script.Parent.BaseMutationController)
local Cosmic = {}

function Cosmic.applyEffect(rack) BaseMutation.applyTemplate(rack, script) end
function Cosmic.removeEffect(rack) BaseMutation.removeTemplate(rack) end

return Cosmic