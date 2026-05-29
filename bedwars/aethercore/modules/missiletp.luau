function toggleMissileTP(enabled)
    cleanupModule("MissileTP")
    if not enabled then return end
    addConnection("MissileTP", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates.MissileTP or input.KeyCode ~= Enum.KeyCode.M then return end
        local root = getHRP(lplr.Character)
        if root then
            root.CFrame = root.CFrame + (root.CFrame.LookVector * 26)
        end
    end))
end

Aether.RegisterModule({
    Name = "MissileTP",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["MissileTP"] or {},
    Start = function(ctx)
        toggleMissileTP(true)
    end,
    Stop = function(ctx)
        toggleMissileTP(false)
    end
})
