-- Shared undo/redo history for build actions
-- Used by both BuildActions and InteractionService

local BuildHistory = {
	undoStack = {},
	redoStack = {},
}

function BuildHistory.pushUndo(action: {[string]: any})
	table.insert(BuildHistory.undoStack, action)
	BuildHistory.redoStack = {}
end

function BuildHistory.popUndo(): {[string]: any}?
	return table.remove(BuildHistory.undoStack)
end

function BuildHistory.peekUndo(): {[string]: any}?
	return BuildHistory.undoStack[#BuildHistory.undoStack]
end

function BuildHistory.pushRedo(action: {[string]: any})
	table.insert(BuildHistory.redoStack, action)
end

function BuildHistory.popRedo(): {[string]: any}?
	return table.remove(BuildHistory.redoStack)
end

function BuildHistory.clearRedo()
	BuildHistory.redoStack = {}
end

function BuildHistory.undoCount(): number
	return #BuildHistory.undoStack
end

function BuildHistory.redoCount(): number
	return #BuildHistory.redoStack
end

return BuildHistory