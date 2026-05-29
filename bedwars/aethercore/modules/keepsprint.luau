moduleSettings["KeepSprint"] = {
    enabled = true
}

local function findSprintController()
    if moduleRuntime.SprintController then return moduleRuntime.SprintController end
    if type(getgc) ~= "function" then return nil end
    for _, value in ipairs(getgc(true)) do
        if type(value) == "table" and type(rawget(value, "startSprinting")) == "function" and type(rawget(value, "stopSprinting")) == "function" then
            moduleRuntime.SprintController = value
            return value
        end
    end
    return nil
end

local function toggleKeepSprint(enabled)
    cleanupModule("KeepSprint")
    local controller = findSprintController()
    if not controller or type(debug) ~= "table" or type(debug.setconstant) ~= "function" then
        if enabled then
            toggleSprint(true)
        end
        return
    end

    if moduleRuntime.KeepSprintOriginalConstant == nil and type(debug.getconstant) == "function" then
        moduleRuntime.KeepSprintOriginalConstant = debug.getconstant(controller.startSprinting, 5)
    end

    safeCall("KeepSprintPatch", function()
        debug.setconstant(controller.startSprinting, 5, enabled and "blockSprinting" or (moduleRuntime.KeepSprintOriginalConstant or "blockSprint"))
        controller:stopSprinting()
    end)
end

Aether.RegisterModule({
    Name = "KeepSprint",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["KeepSprint"] or {},
    Start = function(ctx)
        toggleKeepSprint(true)
    end,
    Stop = function(ctx)
        toggleKeepSprint(false)
    end
})
