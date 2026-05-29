-- Alias module preserved from the legacy AetherCore module list.
local function toggleAntiFall(enabled)
    toggleAntiVoid(enabled)
end

Aether.RegisterModule({
    Name = "AntiFall",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["AntiFall"] or {},
    Start = function(ctx)
        toggleAntiFall(true)
    end,
    Stop = function(ctx)
        toggleAntiFall(false)
    end
})
