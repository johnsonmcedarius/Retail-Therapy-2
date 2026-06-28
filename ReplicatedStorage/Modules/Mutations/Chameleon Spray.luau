local BaseMutation = require(script.Parent.BaseMutationController)
local Chameleon = {}

function Chameleon.applyEffect(rack) BaseMutation.applyTemplate(rack, script) end
function Chameleon.removeEffect(rack) BaseMutation.removeTemplate(rack) end

return Chameleon