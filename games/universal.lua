-- Universal modules load before game-specific modules.
-- Current AetherCore features are BedWars-specific, so this file only prepares
-- shared runtime compatibility and intentionally does not register fake modules.
return function(context)
    local utility = context.Libraries.utility

    for _, libraryName in ipairs({"entity", "prediction"}) do
        local loaded, loadError = utility.LoadVapeRuntimeLibrary(libraryName)
        if not loaded then
            return false, loadError
        end
    end

    utility.InstallGetCustomAssetFallback()
    utility.InstallTargetInfoFallback()
    utility.InstallSessionInfoFallback()

    local libraries = shared.vape.Libraries
    for _, libraryName in ipairs({"entity", "targetinfo", "sessioninfo", "prediction", "uipallet", "tween", "color", "getfontsize", "getcustomasset"}) do
        if libraries[libraryName] == nil then
            return false, string.format("missing '%s'", libraryName)
        end
    end

    return true
end
