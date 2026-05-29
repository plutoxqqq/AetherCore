Aether.RegisterModule({
    Name = "Nuker",
    Category = "World",
    Default = false,
    Settings = moduleSettings["Nuker"] or {},
    Start = function(ctx)
        toggleNuker(true)
    end,
    Stop = function(ctx)
        toggleNuker(false)
    end
})
