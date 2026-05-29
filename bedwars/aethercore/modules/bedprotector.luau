-- Alias module preserved from the legacy AetherCore module list.
local function toggleBedProtector(enabled)
    toggleScaffold(enabled)
end

Aether.RegisterModule({
    Name = "BedProtector",
    Category = "World",
    Default = false,
    Settings = moduleSettings["BedProtector"] or {},
    Start = function(ctx)
        toggleBedProtector(true)
    end,
    Stop = function(ctx)
        toggleBedProtector(false)
    end
})
