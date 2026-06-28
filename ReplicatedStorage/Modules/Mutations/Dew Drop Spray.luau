local BaseMutation = require(script.Parent.BaseMutationController)
local DewDrop = {}

function DewDrop.applyEffect(rack) BaseMutation.applyTemplate(rack, script) end
function DewDrop.removeEffect(rack) BaseMutation.removeTemplate(rack) end

return DewDrop