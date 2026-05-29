-- Alias module preserved from the legacy AetherCore module list.
local function toggleChestSteal(enabled)
    toggleFastPickup(enabled)
end

Aether.RegisterModule({
    Name = "ChestSteal",
    Category = "World",
    Default = false,
    Settings = moduleSettings["ChestSteal"] or {},
    Start = function(ctx)
        toggleChestSteal(true)
    end,
    Stop = function(ctx)
        toggleChestSteal(false)
    end
})
