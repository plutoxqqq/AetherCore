function toggleAutoBank(enabled)
    cleanupModule("AutoBank")
    if not enabled then return end
    -- Partial by design: personal chest deposit remotes are not consistently discoverable.
    addConnection("AutoBank", RunService.Heartbeat:Connect(function()
        if not moduleStates.AutoBank then return end
    end))
end

Aether.RegisterModule({
    Name = "AutoBank",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoBank"] or {},
    Start = function(ctx)
        toggleAutoBank(true)
    end,
    Stop = function(ctx)
        toggleAutoBank(false)
    end
})
