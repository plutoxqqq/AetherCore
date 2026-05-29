moduleSettings["HitFix"] = {
    enabled = true
}

local function findSwordController()
    if moduleRuntime.HitFixSwordController then return moduleRuntime.HitFixSwordController end
    if type(getgc) ~= "function" then return nil end
    for _, value in ipairs(getgc(true)) do
        if type(value) == "table" and type(rawget(value, "swingSwordAtMouse")) == "function" then
            moduleRuntime.HitFixSwordController = value
            return value
        end
    end
    return nil
end

local function findQueryUtil()
    if moduleRuntime.HitFixQueryUtil then return moduleRuntime.HitFixQueryUtil end
    if type(getgc) ~= "function" then return nil end
    for _, value in ipairs(getgc(true)) do
        if type(value) == "table" and (rawget(value, "raycast") or rawget(value, "Raycast")) then
            moduleRuntime.HitFixQueryUtil = value
            return value
        end
    end
    return nil
end

local function toggleHitFix(enabled)
    cleanupModule("HitFix")
    local controller = findSwordController()
    if not controller or type(debug) ~= "table" or type(debug.setconstant) ~= "function" then return end
    local swing = controller.swingSwordAtMouse
    if not moduleRuntime.HitFixOriginalConstant and type(debug.getconstant) == "function" then
        moduleRuntime.HitFixOriginalConstant = debug.getconstant(swing, 23)
    end
    if not moduleRuntime.HitFixOriginalUpvalue and type(debug.getupvalue) == "function" then
        local ok, value = pcall(debug.getupvalue, swing, 4)
        if ok then moduleRuntime.HitFixOriginalUpvalue = value end
    end
    safeCall("HitFixPatch", function()
        debug.setconstant(swing, 23, enabled and "raycast" or (moduleRuntime.HitFixOriginalConstant or "Raycast"))
        if type(debug.setupvalue) == "function" then
            debug.setupvalue(swing, 4, enabled and (findQueryUtil() or Workspace) or (moduleRuntime.HitFixOriginalUpvalue or Workspace))
        end
    end)
end

Aether.RegisterModule({
    Name = "HitFix",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["HitFix"] or {},
    Start = function(ctx)
        toggleHitFix(true)
    end,
    Stop = function(ctx)
        toggleHitFix(false)
    end
})
