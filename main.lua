-- AetherCore main.lua
-- Central controller: waits for Roblox, installs compatibility fallbacks, loads
-- libraries and GUI, routes universal and place-specific modules, profiles, custom modules,
-- then finalizes or cleanly reloads/uninjects.
return function(startup)
    startup = startup or {}
    local unpack = table.unpack or unpack

    local context = {
        RootUrl = startup.RootUrl or "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/",
        RootFolder = startup.RootFolder or "AetherCore",
        Version = startup.Version or "3.2.0",
        Libraries = {},
        LoadedGames = {},
        LoadedModules = {},
        LoadOrder = {},
        SelectedGui = "new",
        Profile = {},
        RequiredLibraries = {"utility", "storage", "theme"},
        OptionalLibraries = {"signal", "tween", "entity", "drawing", "prediction", "target", "hash", "vm"}
    }

    local function warnf(format, ...)
        warn("[AetherCore] " .. string.format(format, ...))
    end

    local function fail(message)
        error("[AetherCore] " .. tostring(message))
    end

    local function joinPath(...)
        local parts = {...}
        local output = {}
        for _, part in ipairs(parts) do
            part = tostring(part or "")
            part = part:gsub("^/+", ""):gsub("/+$", "")
            if part ~= "" then
                table.insert(output, part)
            end
        end
        return table.concat(output, "/")
    end

    context.JoinPath = joinPath

    local function readLocal(path)
        if type(readfile) ~= "function" then
            return nil
        end
        local candidates = {joinPath(context.RootFolder, path), path}
        for _, candidate in ipairs(candidates) do
            local ok, result = pcall(readfile, candidate)
            if ok and type(result) == "string" and result ~= "" then
                return result, candidate
            end
        end
        return nil
    end

    function context.Fetch(path)
        path = tostring(path)
        if type(startup.Fetch) == "function" then
            local ok, result = pcall(startup.Fetch, path)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        end
        local localSource = readLocal(path)
        if localSource then
            return localSource
        end
        return game:HttpGet(context.RootUrl .. path, true)
    end

    function context.LoadModule(path)
        if context.LoadedModules[path] ~= nil then
            return context.LoadedModules[path]
        end

        local source = context.Fetch(path)
        local chunk, compileError = loadstring(source, "AetherCore/" .. path)
        if not chunk then
            error(string.format("[AetherCore] Failed to compile %s: %s", path, tostring(compileError)))
        end

        local previousSource = context.CurrentSource
        context.CurrentSource = path
        local ok, result = xpcall(chunk, debug.traceback)
        context.CurrentSource = previousSource
        if not ok then
            error(string.format("[AetherCore] Failed to run %s: %s", path, tostring(result)))
        end

        context.LoadedModules[path] = result == nil and true or result
        table.insert(context.LoadOrder, path)
        return context.LoadedModules[path]
    end

    function context.RunFunctionModule(path, ...)
        local module = context.LoadModule(path)
        if type(module) == "function" then
            local previousSource = context.CurrentSource
            local args = {...}
            local results
            context.CurrentSource = path
            local ok, runtimeError = xpcall(function()
                results = {module(context, unpack(args))}
            end, debug.traceback)
            context.CurrentSource = previousSource
            if not ok then
                error(string.format("[AetherCore] Failed to run function module %s: %s", path, tostring(runtimeError)))
            end
            return unpack(results)
        end
        return module
    end

    function context.LoadGameModule(path)
        if context.LoadedGames[path] then
            return true
        end

        local results
        local ok, runtimeError = xpcall(function()
            results = {context.RunFunctionModule(path)}
        end, debug.traceback)
        if not ok then
            return false, tostring(runtimeError)
        end
        if results[1] == false then
            return false, tostring(results[2] or "module returned false")
        end
        context.LoadedGames[path] = true
        return true, results[1]
    end

    local function loadRequiredLibrary(name)
        local ok, result = pcall(context.LoadModule, "libraries/" .. name .. ".lua")
        if not ok or type(result) ~= "table" then
            fail("required library '" .. name .. "' failed to load: " .. tostring(result))
        end
        context.Libraries[name] = result
        return result
    end

    local function loadOptionalLibrary(name)
        local ok, result = pcall(context.LoadModule, "libraries/" .. name .. ".lua")
        if not ok or result == nil then
            warnf("optional library '%s' failed to load: %s", name, tostring(result))
            return nil
        end
        context.Libraries[name] = result
        return result
    end

    for _, name in ipairs(context.RequiredLibraries) do
        loadRequiredLibrary(name)
    end
    for _, name in ipairs(context.OptionalLibraries) do
        loadOptionalLibrary(name)
    end

    local utility = context.Libraries.utility
    local storage = context.Libraries.storage

    utility.SetRuntimeContext(context)
    utility.WaitForGameLoaded()
    utility.InstallExecutorCompatibility()

    local state = getgenv and getgenv().AetherCore or {}
    state.Name = "AetherCore"
    state.Version = context.Version
    state.Context = context
    state.ModuleRegistrationCount = 0
    state.RegisteredModules = {}
    state.Uninjected = false
    if getgenv then
        getgenv().AetherCore = state
    end

    context.State = state

    function context.RegisterModuleRecord(name, category, status, source)
        state.ModuleRegistrationCount = (tonumber(state.ModuleRegistrationCount) or 0) + 1
        table.insert(state.RegisteredModules, {
            Name = tostring(name or "Unknown"),
            Category = tostring(category or "Unknown"),
            Status = tostring(status or "registered"),
            Source = tostring(source or context.CurrentSource or "unknown")
        })
    end

    function context.Uninject()
        state.Uninjected = true
        if type(shared) == "table" and type(shared.vape) == "table" then
            if type(shared.vape.Uninject) == "function" then
                pcall(function() shared.vape:Uninject() end)
            elseif type(shared.vape.SelfDestruct) == "function" then
                pcall(function() shared.vape:SelfDestruct() end)
            end
        end
        warn("[AetherCore] Uninjected")
    end

    function context.Reload()
        context.Uninject()
        local source = context.Fetch("init.lua")
        local chunk, compileError = loadstring(source, "AetherCore/init.lua")
        if not chunk then
            fail("Failed to compile init.lua during reload: " .. tostring(compileError))
        end
        return chunk()
    end

    local guiChoice = context.Fetch("profiles/gui.txt")
    guiChoice = type(guiChoice) == "string" and guiChoice:gsub("%s+", ""):lower() or "new"
    local validGuis = {new = true, old = true, rise = true, wurst = true}
    if not validGuis[guiChoice] then
        warnf("unknown GUI '%s'; falling back to new", tostring(guiChoice))
        guiChoice = "new"
    end
    context.SelectedGui = guiChoice

    local gui = context.LoadModule("guis/" .. guiChoice .. ".lua")
    if type(gui) == "function" then
        gui = gui(context)
    end
    if type(gui) ~= "table" or type(gui.Load) ~= "function" or type(gui.Finalize) ~= "function" then
        fail("selected GUI '" .. guiChoice .. "' does not expose Load and Finalize")
    end

    local guiLoaded, guiError = gui.Load(context)
    if not guiLoaded then
        fail("Failed to load GUI: " .. tostring(guiError))
    end
    warnf("GUI loaded: %s", guiChoice)

    if not utility.IsVapeCoreReady() then
        fail("GUI core is not ready after loading " .. guiChoice)
    end

    utility.InstallGetCustomAssetFallback()
    utility.InstallTargetInfoFallback()
    utility.InstallSessionInfoFallback()
    utility.InstallVapeLibraryFallbacks()
    utility.InstallCategoryFallbacks()
    utility.InstallHumanoidScaleFallbacks()

    for categoryName, category in pairs(shared.vape.Categories) do
        if type(category) == "table" and type(category.CreateModule) == "function" and category.__AetherCoreOriginalCreateModule == nil then
            local originalCreateModule = category.CreateModule
            category.__AetherCoreOriginalCreateModule = originalCreateModule
            category.CreateModule = function(self, moduleOptions, ...)
                local module = originalCreateModule(self, moduleOptions, ...)
                if module ~= nil then
                    local moduleName = type(moduleOptions) == "table" and moduleOptions.Name or type(module) == "table" and module.Name or nil
                    context.RegisterModuleRecord(moduleName, categoryName, "loaded", context.CurrentSource)
                end
                return module
            end
        end
    end

    local profileKey = tostring(game.GameId or "universal") .. "_" .. tostring(game.PlaceId or "place")
    context.ProfilePath = joinPath(context.RootFolder, "profiles", profileKey .. ".json")
    context.DefaultProfile = storage.DecodeJson(context.Fetch("profiles/default.txt"), {}) or {}
    context.Profile = storage.LoadProfile and storage.LoadProfile(context.ProfilePath, context.DefaultProfile) or context.DefaultProfile
    if storage.MigrateLegacyProfiles then
        storage.MigrateLegacyProfiles(context)
    end

    local universalOk, universalError = context.RunFunctionModule("games/universal.luau")
    if universalOk == false then
        fail("Failed to load universal modules: " .. tostring(universalError))
    end
    warn("[AetherCore] Universal modules loaded")

    local currentPlaceId = tonumber(game.PlaceId)
    local placePath = "games/" .. tostring(currentPlaceId or "unknown") .. ".luau"
    local ok, loadError = context.LoadGameModule(placePath)
    if ok then
        warnf("Loaded place module: %s", placePath)
    else
        warnf("No place module loaded for PlaceId %s: %s", tostring(currentPlaceId or "unknown"), tostring(loadError))
    end

    local customOk, customResult = pcall(function()
        return context.RunFunctionModule("custom_modules.luau")
    end)
    if not customOk then
        warnf("custom_modules.luau is unavailable or failed: %s", tostring(customResult))
    else
        warn("[AetherCore] Custom modules loaded")
    end

    if (tonumber(state.ModuleRegistrationCount) or 0) == 0 then
        warn("[AetherCore] No modules were registered. Check game payload and module routing.")
    end

    if storage.SaveProfile then
        storage.SaveProfile(context.ProfilePath, context.Profile)
    end

    local finalized, finalizeError = gui.Finalize(context)
    if not finalized then
        fail("Failed to finalize GUI: " .. tostring(finalizeError))
    end

    warn("[AetherCore] Ready")
    return context
end
