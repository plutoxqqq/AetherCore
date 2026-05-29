moduleSettings["AutoHotbar"] = {
    clearHotbar = false,
    slots = {
        [1] = "sword",
        [2] = "wool",
        [3] = "pickaxe",
        [4] = "axe",
        [5] = "bow",
        [6] = "pearl",
        [7] = "balloon",
        [8] = "apple"
    },
    delay = 0.5
}

local function setHotbarSlot(slot, tool)
    local itemType = getToolItemType(tool)
    if not itemType then return false end
    local remote = getNearestRemoteByKeywords({"hotbar"}, {"RemoteEvent", "RemoteFunction"})
        or getNearestRemoteByKeywords({"inventory"}, {"RemoteEvent", "RemoteFunction"})
    return invokeBedwarsRemote(remote, {type = "InventoryAddToHotbar", slot = slot, item = itemType, tool = tool})
end

local function toggleAutoHotbar(enabled)
    cleanupModule("AutoHotbar")
    if not enabled then return end
    addConnection("AutoHotbar", task.spawn(function()
        while moduleStates["AutoHotbar"] do
            local settings = moduleSettings["AutoHotbar"] or {}
            for slot, keyword in pairs(settings.slots or {}) do
                local tool = getHeldOrBackpackToolByKeywords({keyword})
                if tool then
                    setHotbarSlot(slot, tool)
                end
            end
            task.wait(math.max(0.2, tonumber(settings.delay) or 0.5))
        end
    end))
end

Aether.RegisterModule({
    Name = "AutoHotbar",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AutoHotbar"] or {},
    Start = function(ctx)
        toggleAutoHotbar(true)
    end,
    Stop = function(ctx)
        toggleAutoHotbar(false)
    end
})
