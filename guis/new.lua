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

    local vape = type(shared) == "table" and shared.vape or nil
    if type(vape) ~= "table" then
        return false, "shared.vape is unavailable"
    end

    local initFallback = vape.Init
    vape.Init = nil
    if type(vape.Load) == "function" and not vape.Loaded then
        local success, result = pcall(function()
            vape:Load()
        end)
        if not success then
            return false, tostring(result)
        end
    elseif type(initFallback) == "function" then
        local success, result = pcall(function()
            initFallback(vape)
        end)
        if not success then
            return false, tostring(result)
        end
    end

    if type(vape.Save) == "function" and type(task) == "table" and type(task.spawn) == "function" and not vape.__AetherCoreAutosave then
        vape.__AetherCoreAutosave = true
        task.spawn(function()
            repeat
                pcall(function()
                    vape:Save()
                end)
                task.wait(10)
            until not vape.Loaded
            vape.__AetherCoreAutosave = nil
        end)
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
