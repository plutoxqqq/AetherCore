function togglePickupRange(enabled)
    if enabled then moduleStates.FastPickup = true; toggleFastPickup(true) else toggleFastPickup(false); moduleStates.FastPickup = false end
end


Aether.RegisterModule({
    Name = "PickupRange",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["PickupRange"] or {},
    Start = function(ctx)
        togglePickupRange(true)
    end,
    Stop = function(ctx)
        togglePickupRange(false)
    end
})
