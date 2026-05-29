moduleSettings["ChestSteal"] = {
    range = 18,
    delay = 0.15,
    requireOpenGui = false
}

local function stealFromChest(chest)
    local remote = getNearestRemoteByKeywords({"chest"}, {"RemoteEvent", "RemoteFunction"})
        or getNearestRemoteByKeywords({"inventory"}, {"RemoteEvent", "RemoteFunction"})
    local chestId = chest:GetAttribute("ChestId") or chest:GetAttribute("chestId") or chest.Name
    return invokeBedwarsRemote(remote, {chest = chest, chestId = chestId, action = "take_all"})
end

local function toggleChestSteal(enabled)
    cleanupModule("ChestSteal")
    if not enabled then return end
    addConnection("ChestSteal", task.spawn(function()
        while moduleStates["ChestSteal"] do
            local settings = moduleSettings["ChestSteal"] or {}
            if settings.requireOpenGui ~= true or (lplr.PlayerGui and lplr.PlayerGui:FindFirstChildWhichIsA("ScreenGui")) then
                local chest = getNearestTaggedOrNamedObject({"chest"}, math.clamp(tonumber(settings.range) or 18, 4, 32), function(obj)
                    return obj:IsA("Model") or obj:IsA("BasePart")
                end)
                if chest then
                    stealFromChest(chest)
                end
            end
            task.wait(math.max(0.05, tonumber(settings.delay) or 0.15))
        end
    end))
end

Aether.RegisterModule({
    Name = "ChestSteal",
    Category = "World",
    Default = false,
    Settings = moduleSettings["ChestSteal"] or {},
    Start = function(ctx)
        toggleChestSteal(true)
    end,
    Stop = function(ctx)
        toggleChestSteal(false)
    end
})
