function toggleOpenTeamUpgrades(enabled)
    cleanupModule("OpenTeamUpgrades")
    if enabled then
        pcall(function()
            local remote = getNetManagedFolder() and getNetManagedFolder():FindFirstChild("SetShownApp")
            if remote then
                remote:FireServer(4)
            end
        end)
        task.defer(function() moduleStates["OpenTeamUpgrades"] = false end)
    end
end

Aether.RegisterModule({
    Name = "OpenTeamUpgrades",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["OpenTeamUpgrades"] or {},
    Start = function(ctx)
        toggleOpenTeamUpgrades(true)
    end,
    Stop = function(ctx)
        toggleOpenTeamUpgrades(false)
    end
})
