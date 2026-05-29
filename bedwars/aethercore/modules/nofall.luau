function toggleNoFall(enabled)
    toggleNoFallDamage(enabled)
end

Aether.RegisterModule({
    Name = "NoFall",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["NoFall"] or {},
    Start = function(ctx)
        toggleNoFall(true)
    end,
    Stop = function(ctx)
        toggleNoFall(false)
    end
})
