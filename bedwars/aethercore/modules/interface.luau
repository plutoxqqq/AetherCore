function toggleInterface(enabled)
    setScreenGuiEnabled(enabled)
end

Aether.RegisterModule({
    Name = "Interface",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Interface"] or {},
    Start = function(ctx)
        toggleInterface(true)
    end,
    Stop = function(ctx)
        toggleInterface(false)
    end
})
