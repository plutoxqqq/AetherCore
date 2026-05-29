-- Alias module preserved from the legacy AetherCore module list.
local function toggleKillaura(enabled)
    toggleKillAura(enabled)
end

Aether.RegisterModule({
    Name = "Killaura",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["Killaura"] or {},
    Start = function(ctx)
        toggleKillaura(true)
    end,
    Stop = function(ctx)
        toggleKillaura(false)
    end
})
