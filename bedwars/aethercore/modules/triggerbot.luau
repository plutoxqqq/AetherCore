moduleSettings["TriggerBot"] = {
    range = 18,
    cps = 10,
    requireLineOfSight = true
}

function toggleTriggerBot(enabled)
    cleanupModule("TriggerBot")
    if not enabled then return end
    addConnection("TriggerBot", task.spawn(function()
        while moduleStates["TriggerBot"] do
            local settings = moduleSettings["TriggerBot"] or {}
            local target = getNearestEnemy(math.clamp(tonumber(settings.range) or 18, 4, 40), true)
            if target and (settings.requireLineOfSight ~= true or hasLineOfSight(target)) then
                faceCharacterTarget(target)
                attackTargetWithBedwarsApi(target)
                pcall(function()
                    mouse1click()
                end)
            end
            task.wait(1 / math.clamp(tonumber(settings.cps) or 10, 1, 20))
        end
    end))
end

Aether.RegisterModule({
    Name = "TriggerBot",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["TriggerBot"] or {},
    Start = function(ctx)
        toggleTriggerBot(true)
    end,
    Stop = function(ctx)
        toggleTriggerBot(false)
    end
})
