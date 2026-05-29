moduleSettings["Breaker"] = {
    range = 30,
    updateRate = 0.2,
    beds = true,
    tesla = true,
    luckyBlocks = true,
    ironOre = true,
    autoTool = true
}

local function isBreakerTarget(obj)
    local name = obj.Name:lower()
    local settings = moduleSettings["Breaker"] or {}
    return (settings.beds ~= false and name:find("bed", 1, true))
        or (settings.tesla ~= false and name:find("tesla", 1, true))
        or (settings.luckyBlocks ~= false and name:find("lucky", 1, true))
        or (settings.ironOre ~= false and name:find("iron_ore", 1, true))
end

local function breakObject(obj)
    local position = getObjectPivotPosition(obj)
    if not position then return false end
    if (moduleSettings["Breaker"] or {}).autoTool ~= false then
        local tool = getBestToolForBlock(obj)
        if tool then
            equipToolIfNeeded(tool)
        end
    end
    local remote = getDamageBlockRemote() or getNearestRemoteByKeywords({"damage", "block"}, {"RemoteEvent", "RemoteFunction"})
    return invokeBedwarsRemote(remote, {
        blockRef = {blockPosition = position},
        blockPosition = position,
        position = position
    })
end

function toggleBreaker(enabled)
    cleanupModule("Breaker")
    if not enabled then return end
    addConnection("Breaker", task.spawn(function()
        while moduleStates["Breaker"] do
            local settings = moduleSettings["Breaker"] or {}
            local target = getNearestTaggedOrNamedObject({}, math.clamp(tonumber(settings.range) or 30, 4, 50), isBreakerTarget)
            if target then
                breakObject(target)
            end
            task.wait(math.max(0.05, tonumber(settings.updateRate) or 0.2))
        end
    end))
end

Aether.RegisterModule({
    Name = "Breaker",
    Category = "World",
    Default = false,
    Settings = moduleSettings["Breaker"] or {},
    Start = function(ctx)
        toggleBreaker(true)
    end,
    Stop = function(ctx)
        toggleBreaker(false)
    end
})
