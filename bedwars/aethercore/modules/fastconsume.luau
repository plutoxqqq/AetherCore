function toggleFastConsume(enabled)
    cleanupModule("FastConsume")
    if not enabled then return end
    addConnection("FastConsume", RunService.Heartbeat:Connect(function()
        if not moduleStates.FastConsume then return end
    end))
end

Aether.RegisterModule({
    Name = "FastConsume",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["FastConsume"] or {},
    Start = function(ctx)
        toggleFastConsume(true)
    end,
    Stop = function(ctx)
        toggleFastConsume(false)
    end
})
