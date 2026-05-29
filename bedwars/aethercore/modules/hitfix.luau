-- Alias module preserved from the legacy AetherCore module list.
local function toggleHitFix(enabled)
    toggleReach(enabled)
end

Aether.RegisterModule({
    Name = "HitFix",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["HitFix"] or {},
    Start = function(ctx)
        toggleHitFix(true)
    end,
    Stop = function(ctx)
        toggleHitFix(false)
    end
})
