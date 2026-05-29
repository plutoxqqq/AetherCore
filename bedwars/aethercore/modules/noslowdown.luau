moduleSettings["NoSlowdown"] = {
    minimumMultiplier = 1
}

local function findSprintControllerForNoSlow()
    if moduleRuntime.NoSlowSprintController then return moduleRuntime.NoSlowSprintController end
    if type(getgc) ~= "function" then return nil end
    for _, value in ipairs(getgc(true)) do
        if type(value) == "table" and type(rawget(value, "getMovementStatusModifier")) == "function" then
            moduleRuntime.NoSlowSprintController = value
            return value
        end
    end
    return nil
end

local function toggleNoSlowdown(enabled)
    if enabled then
        cleanupModule("NoSlowdown")
    end
    local controller = findSprintControllerForNoSlow()
    local modifier = controller and safeCall("NoSlowdownGetModifier", function()
        return controller:getMovementStatusModifier()
    end)
    if not modifier then return end

    if enabled then
        if not moduleRuntime.NoSlowdownOriginalAddModifier then
            moduleRuntime.NoSlowdownOriginalAddModifier = modifier.addModifier
        end
        modifier.addModifier = function(self, data)
            if type(data) == "table" and data.moveSpeedMultiplier then
                data.moveSpeedMultiplier = math.max(data.moveSpeedMultiplier, tonumber((moduleSettings["NoSlowdown"] or {}).minimumMultiplier) or 1)
            end
            return moduleRuntime.NoSlowdownOriginalAddModifier(self, data)
        end
        if type(modifier.removeModifier) == "function" and type(modifier.modifiers) == "table" then
            for activeModifier in pairs(modifier.modifiers) do
                if type(activeModifier) == "table" and (activeModifier.moveSpeedMultiplier or 1) < 1 then
                    modifier:removeModifier(activeModifier)
                end
            end
        end
    elseif moduleRuntime.NoSlowdownOriginalAddModifier then
        modifier.addModifier = moduleRuntime.NoSlowdownOriginalAddModifier
        moduleRuntime.NoSlowdownOriginalAddModifier = nil
    end
end

Aether.RegisterModule({
    Name = "NoSlowdown",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["NoSlowdown"] or {},
    Start = function(ctx)
        toggleNoSlowdown(true)
    end,
    Stop = function(ctx)
        toggleNoSlowdown(false)
    end
})
