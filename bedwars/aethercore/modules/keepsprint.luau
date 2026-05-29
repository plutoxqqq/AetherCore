-- Alias module preserved from the legacy AetherCore module list.
local function toggleKeepSprint(enabled)
    toggleSprint(enabled)
end

Aether.RegisterModule({
    Name = "KeepSprint",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["KeepSprint"] or {},
    Start = function(ctx)
        toggleKeepSprint(true)
    end,
    Stop = function(ctx)
        toggleKeepSprint(false)
    end
})
