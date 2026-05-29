function toggleArmorSwitch(enabled)
    cleanupModule("ArmorSwitch")
    if not enabled then return end
    -- Partial by design: inventory-slot swap APIs vary between BedWars versions.
    addConnection("ArmorSwitch", RunService.Heartbeat:Connect(function()
        if not moduleStates.ArmorSwitch then return end
    end))
end

Aether.RegisterModule({
    Name = "ArmorSwitch",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["ArmorSwitch"] or {},
    Start = function(ctx)
        toggleArmorSwitch(true)
    end,
    Stop = function(ctx)
        toggleArmorSwitch(false)
    end
})
