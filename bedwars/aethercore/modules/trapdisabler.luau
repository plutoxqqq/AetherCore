function toggleTrapDisabler(enabled)
    moduleStates["TrapDisabler"] = enabled and true or false
end

Aether.RegisterModule({
    Name = "TrapDisabler",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["TrapDisabler"] or {},
    Start = function(ctx)
        toggleTrapDisabler(true)
    end,
    Stop = function(ctx)
        toggleTrapDisabler(false)
    end
})
