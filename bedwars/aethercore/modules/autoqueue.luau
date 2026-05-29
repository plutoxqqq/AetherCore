function toggleAutoQueue(enabled)
    cleanupModule("AutoQueue")
    if not enabled then return end
    addConnection("AutoQueue", task.spawn(function()
        while moduleStates["AutoQueue"] do
            task.wait(math.max(0.1, tonumber((moduleSettings["AutoQueue"] or {}).delay) or 1))
            pcall(function()
                local queueRemote = getNetManagedFolder() and getNetManagedFolder():FindFirstChild("JoinQueue")
                if queueRemote then
                    queueRemote:InvokeServer({queueType = "bedwars_test_squads"})
                end
            end)
        end
    end))
end


Aether.RegisterModule({
    Name = "AutoQueue",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["AutoQueue"] or {},
    Start = function(ctx)
        toggleAutoQueue(true)
    end,
    Stop = function(ctx)
        toggleAutoQueue(false)
    end
})
