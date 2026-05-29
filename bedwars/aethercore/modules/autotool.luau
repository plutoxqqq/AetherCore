moduleSettings["AutoTool"] = {
    switchBack = true
}

local function getPointedBlock()
    local target = mouse and mouse.Target or nil
    local char = getCharacter(lplr)
    if target and char and target:IsDescendantOf(char) then
        return nil
    end
    return target
end

local function toggleAutoTool(enabled)
    cleanupModule("AutoTool")
    if not enabled then return end
    addConnection("AutoTool", UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not moduleStates["AutoTool"] or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local block = getPointedBlock()
        if not block then return end
        local tool = getBestToolForBlock(block)
        if tool then
            moduleRuntime.AutoToolPrevious = getCharacter(lplr) and getCharacter(lplr):FindFirstChildOfClass("Tool") or nil
            equipToolIfNeeded(tool)
        end
    end))
    addConnection("AutoTool", UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if (moduleSettings["AutoTool"] or {}).switchBack and moduleRuntime.AutoToolPrevious and moduleRuntime.AutoToolPrevious.Parent then
            equipToolIfNeeded(moduleRuntime.AutoToolPrevious)
        end
        moduleRuntime.AutoToolPrevious = nil
    end))
end

Aether.RegisterModule({
    Name = "AutoTool",
    Category = "World",
    Default = false,
    Settings = moduleSettings["AutoTool"] or {},
    Start = function(ctx)
        toggleAutoTool(true)
    end,
    Stop = function(ctx)
        toggleAutoTool(false)
    end
})
