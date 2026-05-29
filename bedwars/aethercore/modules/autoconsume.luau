function toggleAutoConsume(enabled)
    cleanupModule("AutoConsume")
    if not enabled then return end
    addConnection("AutoConsume", RunService.Heartbeat:Connect(function()
        if not moduleStates.AutoConsume then return end
    end))
end

Aether.RegisterModule({
    Name = "AutoConsume",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoConsume"] or {},
    Start = function(ctx)
        toggleAutoConsume(true)
    end,
    Stop = function(ctx)
        toggleAutoConsume(false)
    end
})
