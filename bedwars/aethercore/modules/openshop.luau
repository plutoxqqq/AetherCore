function toggleOpenShop(enabled)
    cleanupModule("OpenShop")
    if enabled then
        pcall(function()
            local remote = getNetManagedFolder() and getNetManagedFolder():FindFirstChild("SetShownApp")
            if remote then
                remote:FireServer(5)
            end
        end)
        task.defer(function() moduleStates["OpenShop"] = false end)
    end
end

Aether.RegisterModule({
    Name = "OpenShop",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["OpenShop"] or {},
    Start = function(ctx)
        toggleOpenShop(true)
    end,
    Stop = function(ctx)
        toggleOpenShop(false)
    end
})
