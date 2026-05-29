-- Alias module preserved from the legacy AetherCore module list.
local function toggleAutoKit(enabled)
    toggleAutoBuy(enabled)
end

Aether.RegisterModule({
    Name = "AutoKit",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoKit"] or {},
    Start = function(ctx)
        toggleAutoKit(true)
    end,
    Stop = function(ctx)
        toggleAutoKit(false)
    end
})
