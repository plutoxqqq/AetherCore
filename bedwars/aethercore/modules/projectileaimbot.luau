function toggleProjectileAimbot(enabled)
    toggleAimbot(enabled)
end

Aether.RegisterModule({
    Name = "ProjectileAimbot",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["ProjectileAimbot"] or {},
    Start = function(ctx)
        toggleProjectileAimbot(true)
    end,
    Stop = function(ctx)
        toggleProjectileAimbot(false)
    end
})
