-- Default AetherCore GUI bridge.
-- The project keeps the proven compatibility interface while the new loader
-- owns startup, module routing, profile loading, and finalisation.
local Gui = {}

function Gui.Load(context)
    local utility = context.Libraries.utility
    shared = type(shared) == "table" and shared or {}

    if utility.IsVapeCoreReady() then
        utility.ApplyVapeBranding()
        return true
    end

    if type(loadstring) ~= "function" then
        return false, "loadstring is not available in this executor"
    end

    shared.VapeIndependent = true
    if shared.vape ~= nil and not utility.IsVapeCoreReady() then
        shared.vape = nil
    end

    local success, result = pcall(function()
        local source = game:HttpGet(utility.VapeCoreUrl, true)
        local loader, compileError = loadstring(utility.BrandVapeCoreSource(source), "AetherCoreGUI")
        if not loader then
            error(string.format("compile error: %s", tostring(compileError)))
        end
        return loader()
    end)

    if not success then
        return false, tostring(result)
    end
    if not utility.IsVapeCoreReady() then
        return false, "GUI core loaded without the required Libraries and Categories APIs"
    end

    utility.ApplyVapeBranding()
    utility.ApplyVisibleBrandingOverrides()
    return true
end

function Gui.Finalize(context)
    local utility = context.Libraries.utility
    utility.ApplyVapeBranding()

    if type(shared) == "table" and type(shared.vape) == "table" and type(shared.vape.Init) == "function" then
        local success, result = pcall(function()
            shared.vape:Init()
        end)
        if not success then
            return false, tostring(result)
        end
    end

    utility.ApplyVapeBranding()
    utility.ApplyVisibleBrandingOverrides()
    if type(task) == "table" then
        if type(task.defer) == "function" then
            task.defer(utility.ApplyVisibleBrandingOverrides)
        end
        if type(task.delay) == "function" then
            task.delay(1, utility.ApplyVisibleBrandingOverrides)
        end
    end
    return true
end

return Gui
