local BaseMutation = require(script.Parent.BaseMutationController)
local LiquidChrome = {}

function LiquidChrome.applyEffect(rack) BaseMutation.applyTemplate(rack, script) end
function LiquidChrome.removeEffect(rack) BaseMutation.removeTemplate(rack) end

return LiquidChrome