-- Alias module preserved from the legacy AetherCore module list.
local function toggleAutoTool(enabled)
    toggleNuker(enabled)
end

Aether.RegisterModule({
    Name = "AutoTool",
    Category = "World",
    Default = false,
    Settings = moduleSettings["AutoTool"] or {},
    Start = function(ctx)
        toggleAutoTool(true)
    end,
    Stop = function(ctx)
        toggleAutoTool(false)
    end
})
