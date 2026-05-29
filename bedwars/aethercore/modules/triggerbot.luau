function toggleTriggerBot(enabled)
    toggleAutoClicker(enabled)
end

Aether.RegisterModule({
    Name = "TriggerBot",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["TriggerBot"] or {},
    Start = function(ctx)
        toggleTriggerBot(true)
    end,
    Stop = function(ctx)
        toggleTriggerBot(false)
    end
})
