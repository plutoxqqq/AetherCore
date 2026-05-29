function toggleProjectileAura(enabled)
    toggleAimbot(enabled)
end

Aether.RegisterModule({
    Name = "ProjectileAura",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["ProjectileAura"] or {},
    Start = function(ctx)
        toggleProjectileAura(true)
    end,
    Stop = function(ctx)
        toggleProjectileAura(false)
    end
})
