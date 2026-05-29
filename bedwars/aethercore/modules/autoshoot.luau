function toggleAutoShoot(enabled)
    cleanupModule("AutoShoot")
    if not enabled then return end
    addConnection("AutoShoot", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates["AutoShoot"] then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.delay(0.05, performPrimaryClick)
        end
    end))
end


Aether.RegisterModule({
    Name = "AutoShoot",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoShoot"] or {},
    Start = function(ctx)
        toggleAutoShoot(true)
    end,
    Stop = function(ctx)
        toggleAutoShoot(false)
    end
})
