-- Alias module preserved from the legacy AetherCore module list.
local function toggleSchematica(enabled)
    toggleScaffold(enabled)
end

Aether.RegisterModule({
    Name = "Schematica",
    Category = "World",
    Default = false,
    Settings = moduleSettings["Schematica"] or {},
    Start = function(ctx)
        toggleSchematica(true)
    end,
    Stop = function(ctx)
        toggleSchematica(false)
    end
})
