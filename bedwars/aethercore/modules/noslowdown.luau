-- Alias module preserved from the legacy AetherCore module list.
local function toggleNoSlowdown(enabled)
    toggleSprint(enabled)
end

Aether.RegisterModule({
    Name = "NoSlowdown",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["NoSlowdown"] or {},
    Start = function(ctx)
        toggleNoSlowdown(true)
    end,
    Stop = function(ctx)
        toggleNoSlowdown(false)
    end
})
