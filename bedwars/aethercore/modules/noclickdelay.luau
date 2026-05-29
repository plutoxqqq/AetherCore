function toggleNoClickDelay(enabled)
    cleanupModule("NoClickDelay")
    if not enabled then
        return
    end
    addConnection("NoClickDelay", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates["NoClickDelay"] then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            performPrimaryClick()
        end
    end))
end

Aether.RegisterModule({
    Name = "NoClickDelay",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["NoClickDelay"] or {},
    Start = function(ctx)
        toggleNoClickDelay(true)
    end,
    Stop = function(ctx)
        toggleNoClickDelay(false)
    end
})
