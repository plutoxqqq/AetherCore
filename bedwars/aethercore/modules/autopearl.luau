function toggleAutoPearl(enabled)
    cleanupModule("AutoPearl")
    if not enabled then return end
    addConnection("AutoPearl", RunService.Heartbeat:Connect(function()
        if not moduleStates.AutoPearl then return end
        local character = lplr.Character
        local humanoid = getHumanoid(character)
        local root = getHRP(character)
        if not humanoid or not root or humanoid.Health <= 0 then return end
        if humanoid.FloorMaterial == Enum.Material.Air and root.Velocity.Y < -moduleSettings.AutoPearl.fallTrigger then
            performPrimaryClick()
        end
    end))
end


Aether.RegisterModule({
    Name = "AutoPearl",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoPearl"] or {},
    Start = function(ctx)
        toggleAutoPearl(true)
    end,
    Stop = function(ctx)
        toggleAutoPearl(false)
    end
})
