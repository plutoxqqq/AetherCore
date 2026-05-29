function toggleRavenTP(enabled)
    cleanupModule("RavenTP")
    if not enabled then return end
    addConnection("RavenTP", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates.RavenTP or input.KeyCode ~= Enum.KeyCode.R then return end
        local root = getHRP(lplr.Character)
        if root then
            root.CFrame = root.CFrame + Vector3.new(0, 12, 0)
        end
    end))
end

Aether.RegisterModule({
    Name = "RavenTP",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["RavenTP"] or {},
    Start = function(ctx)
        toggleRavenTP(true)
    end,
    Stop = function(ctx)
        toggleRavenTP(false)
    end
})
