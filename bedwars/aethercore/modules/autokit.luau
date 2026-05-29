moduleSettings["AutoKit"] = {
    legitRange = true,
    repeatDelay = 0.5
}

local kitActions = {
    baker = function()
        local _, apple = hasItem("apple")
        if apple then equipToolIfNeeded(apple); apple:Activate() end
    end,
    spirit = function()
        local _, spirit = hasItem("spirit")
        if spirit then equipToolIfNeeded(spirit); spirit:Activate() end
    end,
    grimreaper = function()
        local remote = getNearestRemoteByKeywords({"consume", "soul"}, {"RemoteEvent", "RemoteFunction"})
        invokeBedwarsRemote(remote, {})
    end,
    eldertree = function()
        local orb = getNearestTaggedOrNamedObject({"tree", "orb"}, 18, nil)
        local remote = getNearestRemoteByKeywords({"tree", "orb"}, {"RemoteEvent", "RemoteFunction"})
        if orb then
            invokeBedwarsRemote(remote, {treeOrbSecret = orb:GetAttribute("TreeOrbSecret"), orb = orb})
        end
    end,
    battery = function()
        local remote = getNearestRemoteByKeywords({"consume", "battery"}, {"RemoteEvent", "RemoteFunction"})
        invokeBedwarsRemote(remote, {})
    end
}

local function getEquippedKitName()
    return tostring(lplr:GetAttribute("Kit") or lplr:GetAttribute("kit") or lplr:GetAttribute("EquippedKit") or ""):lower():gsub("%s+", "")
end

local function toggleAutoKit(enabled)
    cleanupModule("AutoKit")
    if not enabled then return end
    addConnection("AutoKit", task.spawn(function()
        while moduleStates["AutoKit"] do
            local kitName = getEquippedKitName()
            for key, callback in pairs(kitActions) do
                if kitName:find(key, 1, true) then
                    safeCall("AutoKit_" .. key, callback)
                    break
                end
            end
            task.wait(math.max(0.2, tonumber((moduleSettings["AutoKit"] or {}).repeatDelay) or 0.5))
        end
    end))
end

Aether.RegisterModule({
    Name = "AutoKit",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoKit"] or {},
    Start = function(ctx)
        toggleAutoKit(true)
    end,
    Stop = function(ctx)
        toggleAutoKit(false)
    end
})
