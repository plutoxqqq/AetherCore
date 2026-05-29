function toggleAutoPlay(enabled)
    cleanupModule("AutoPlay")
    if not enabled then return end
    addConnection("AutoPlay", task.spawn(function()
        while moduleStates["AutoPlay"] do
            task.wait(math.max(0.2, tonumber((moduleSettings["AutoQueue"] or {}).delay) or 1))
            pcall(function()
                local queueRemote = getNetManagedFolder() and getNetManagedFolder():FindFirstChild("JoinQueue")
                if queueRemote then
                    local queueType = "bedwars_test_squads"
                    queueRemote:InvokeServer({queueType = queueType})
                end
            end)
        end
    end))
end


Aether.RegisterModule({
    Name = "AutoPlay",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoPlay"] or {},
    Start = function(ctx)
        toggleAutoPlay(true)
    end,
    Stop = function(ctx)
        toggleAutoPlay(false)
    end
})
