moduleSettings["AutoBalloon"] = {
    healthThreshold = 35,
    voidDistance = 16,
    useShop = true,
    cooldown = 0.8
}

local function useBalloonTool()
    local _, balloon = hasItem("balloon")
    if not balloon then
        return false
    end
    if not equipToolIfNeeded(balloon) then
        return false
    end
    return safeCall("AutoBalloonActivate", function()
        balloon:Activate()
        return true
    end) or false
end

local function buyBalloonsIfMissing()
    if (moduleSettings["AutoBalloon"] or {}).useShop == false then
        return false
    end
    local remote = getNearestRemoteByKeywords({"purchase"}, {"RemoteEvent", "RemoteFunction"})
        or getNearestRemoteByKeywords({"shop"}, {"RemoteEvent", "RemoteFunction"})
    return invokeBedwarsRemote(remote, {shopItem = "balloon", item = "balloon", amount = 1})
end

local function toggleAutoBalloon(enabled)
    cleanupModule("AutoBalloon")
    if not enabled then return end
    moduleRuntime.AutoBalloonLastUse = 0
    addConnection("AutoBalloon", RunService.Heartbeat:Connect(function()
        if not moduleStates["AutoBalloon"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local root = getHRP(char)
        if not hum or not root or hum.Health <= 0 then return end
        local settings = moduleSettings["AutoBalloon"] or {}
        if tick() - (moduleRuntime.AutoBalloonLastUse or 0) < math.max(0.2, tonumber(settings.cooldown) or 0.8) then return end

        local ground = raycastToGround(root.Position, {char}, 260)
        local fallingIntoVoid = (not ground) or ((root.Position.Y - ground.Position.Y) >= math.max(8, tonumber(settings.voidDistance) or 16) and root.AssemblyLinearVelocity.Y < -18)
        local lowHealth = hum.Health <= math.clamp(tonumber(settings.healthThreshold) or 35, 1, hum.MaxHealth)
        if fallingIntoVoid or lowHealth then
            if useBalloonTool() or (buyBalloonsIfMissing() and useBalloonTool()) then
                moduleRuntime.AutoBalloonLastUse = tick()
            end
        end
    end))
end

Aether.RegisterModule({
    Name = "AutoBalloon",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoBalloon"] or {},
    Start = function(ctx)
        toggleAutoBalloon(true)
    end,
    Stop = function(ctx)
        toggleAutoBalloon(false)
    end
})
