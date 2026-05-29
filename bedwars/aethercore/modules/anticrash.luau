function toggleAntiCrash(enabled)
    cleanupModule("AntiCrash")
    if not enabled then
        return
    end
    addConnection("AntiCrash", Workspace.DescendantAdded:Connect(function(obj)
        if not moduleStates["AntiCrash"] then
            return
        end
        if obj and obj.Name == "LightningStrike" then
            pcall(function() obj:Destroy() end)
        end
    end))
end

Aether.RegisterModule({
    Name = "AntiCrash",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AntiCrash"] or {},
    Start = function(ctx)
        toggleAntiCrash(true)
    end,
    Stop = function(ctx)
        toggleAntiCrash(false)
    end
})
