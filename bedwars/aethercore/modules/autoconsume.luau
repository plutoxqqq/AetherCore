moduleSettings["AutoConsume"] = {
    health = 70,
    speedPotion = true,
    apple = true,
    shieldPotion = true,
    delay = 0.35
}

local function consumeTool(tool)
    if not tool or not equipToolIfNeeded(tool) then
        return false
    end
    local itemType = getToolItemType(tool)
    local remote = getNearestRemoteByKeywords({"consume"}, {"RemoteEvent", "RemoteFunction"})
    if invokeBedwarsRemote(remote, {item = itemType, tool = tool}) then
        return true
    end
    return safeCall("AutoConsumeActivate", function()
        tool:Activate()
        return true
    end) or false
end

local function findConsumable(settings, hum)
    if settings.apple ~= false and hum and hum.Health <= math.clamp(tonumber(settings.health) or 70, 1, hum.MaxHealth) then
        local _, apple = hasItem("apple")
        if apple then return apple end
    end
    if settings.shieldPotion ~= false then
        local _, shield = hasItem("shield")
        if shield then return shield end
    end
    if settings.speedPotion ~= false then
        local _, speed = hasItem("speed")
        if speed then return speed end
    end
    return nil
end

function toggleAutoConsume(enabled)
    cleanupModule("AutoConsume")
    if not enabled then return end
    addConnection("AutoConsume", task.spawn(function()
        while moduleStates["AutoConsume"] do
            local hum = getHumanoid(getCharacter(lplr))
            local settings = moduleSettings["AutoConsume"] or {}
            local tool = findConsumable(settings, hum)
            if tool then
                consumeTool(tool)
            end
            task.wait(math.max(0.1, tonumber(settings.delay) or 0.35))
        end
    end))
end

Aether.RegisterModule({
    Name = "AutoConsume",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoConsume"] or {},
    Start = function(ctx)
        toggleAutoConsume(true)
    end,
    Stop = function(ctx)
        toggleAutoConsume(false)
    end
})
