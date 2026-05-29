moduleSettings["BedProtector"] = {
    range = 30,
    radius = 3,
    delay = 0.12,
    blockKeywords = {"wool", "stone", "wood", "plank"}
}

local function getOwnBed()
    return getNearestTaggedOrNamedObject({"bed"}, math.clamp(tonumber((moduleSettings["BedProtector"] or {}).range) or 30, 8, 80), nil)
end

local function placeProtectionBlock(position)
    local tool = getHeldOrBackpackToolByKeywords((moduleSettings["BedProtector"] or {}).blockKeywords or {"wool", "stone", "wood"})
    if not tool or not equipToolIfNeeded(tool) then return false end
    local controller = getBlockPlacementController()
    if controller and type(controller.placeBlock) == "function" then
        return safeCall("BedProtectorPlaceBlock", function()
            controller:placeBlock(position, getToolItemType(tool))
            return true
        end) or false
    end
    local remote = getNearestRemoteByKeywords({"place", "block"}, {"RemoteEvent", "RemoteFunction"})
    return invokeBedwarsRemote(remote, {blockPosition = position, position = position, item = getToolItemType(tool)})
end

local function toggleBedProtector(enabled)
    cleanupModule("BedProtector")
    if not enabled then return end
    addConnection("BedProtector", task.spawn(function()
        while moduleStates["BedProtector"] do
            local bed = getOwnBed()
            local bedPosition = getObjectPivotPosition(bed)
            if bedPosition then
                local radius = math.clamp(tonumber((moduleSettings["BedProtector"] or {}).radius) or 3, 1, 5)
                for x = -radius, radius do
                    for y = 0, radius do
                        for z = -radius, radius do
                            if math.abs(x) == radius or math.abs(z) == radius or y == radius then
                                placeProtectionBlock(Vector3.new(math.floor(bedPosition.X / 3 + x), math.floor(bedPosition.Y / 3 + y), math.floor(bedPosition.Z / 3 + z)))
                                task.wait(math.max(0.03, tonumber((moduleSettings["BedProtector"] or {}).delay) or 0.12))
                                if not moduleStates["BedProtector"] then return end
                            end
                        end
                    end
                end
            end
            task.wait(1)
        end
    end))
end

Aether.RegisterModule({
    Name = "BedProtector",
    Category = "World",
    Default = false,
    Settings = moduleSettings["BedProtector"] or {},
    Start = function(ctx)
        toggleBedProtector(true)
    end,
    Stop = function(ctx)
        toggleBedProtector(false)
    end
})
