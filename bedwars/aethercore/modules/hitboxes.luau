function toggleHitBoxes(enabled)
    toggleReach(enabled)
end

Aether.RegisterModule({
    Name = "HitBoxes",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["HitBoxes"] or {},
    Start = function(ctx)
        toggleHitBoxes(true)
    end,
    Stop = function(ctx)
        toggleHitBoxes(false)
    end
})
