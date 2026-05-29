function toggleAutoHotbar(enabled)
    cleanupModule("AutoHotbar")
    if not enabled then return end
    addConnection("AutoHotbar", RunService.Heartbeat:Connect(function()
        if not moduleStates.AutoHotbar then return end
    end))
end

Aether.RegisterModule({
    Name = "AutoHotbar",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoHotbar"] or {},
    Start = function(ctx)
        toggleAutoHotbar(true)
    end,
    Stop = function(ctx)
        toggleAutoHotbar(false)
    end
})
