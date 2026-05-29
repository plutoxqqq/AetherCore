moduleSettings["TrapDisabler"] = {
    range = 18,
    disableSnapTraps = true,
    disableTesla = true,
    delay = 0.2
}

local function disableTrap(trap)
    local position = getObjectPivotPosition(trap)
    local remote = getNearestRemoteByKeywords({"trap"}, {"RemoteEvent", "RemoteFunction"})
        or getDamageBlockRemote()
    return invokeBedwarsRemote(remote, {trap = trap, position = position, blockPosition = position, action = "disable"})
end

function toggleTrapDisabler(enabled)
    cleanupModule("TrapDisabler")
    if not enabled then return end
    addConnection("TrapDisabler", task.spawn(function()
        while moduleStates["TrapDisabler"] do
            local settings = moduleSettings["TrapDisabler"] or {}
            local terms = {}
            if settings.disableSnapTraps ~= false then table.insert(terms, "trap") end
            if settings.disableTesla ~= false then table.insert(terms, "tesla") end
            local trap = getNearestTaggedOrNamedObject(terms, math.clamp(tonumber(settings.range) or 18, 4, 32), nil)
            if trap then disableTrap(trap) end
            task.wait(math.max(0.05, tonumber(settings.delay) or 0.2))
        end
    end))
end

Aether.RegisterModule({
    Name = "TrapDisabler",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["TrapDisabler"] or {},
    Start = function(ctx)
        toggleTrapDisabler(true)
    end,
    Stop = function(ctx)
        toggleTrapDisabler(false)
    end
})
