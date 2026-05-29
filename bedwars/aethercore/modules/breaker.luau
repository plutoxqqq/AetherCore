function toggleBreaker(enabled)
    -- Partial by design: this uses AetherCore Nuker path instead of Vape block-break controller hooks.
    toggleNuker(enabled)
end

Aether.RegisterModule({
    Name = "Breaker",
    Category = "World",
    Default = false,
    Settings = moduleSettings["Breaker"] or {},
    Start = function(ctx)
        toggleBreaker(true)
    end,
    Stop = function(ctx)
        toggleBreaker(false)
    end
})
