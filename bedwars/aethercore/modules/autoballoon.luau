-- Alias module preserved from the legacy AetherCore module list.
local function toggleAutoBalloon(enabled)
    toggleFly(enabled)
end

Aether.RegisterModule({
    Name = "AutoBalloon",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoBalloon"] or {},
    Start = function(ctx)
        toggleAutoBalloon(true)
    end,
    Stop = function(ctx)
        toggleAutoBalloon(false)
    end
})
