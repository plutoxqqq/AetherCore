-- AetherCore main.lua
-- Central controller: waits for Roblox, prepares executor compatibility,
-- loads libraries and GUI, routes universal/game modules, then finalises the UI.
return function(startup)
    startup = startup or {}

    local context = {
        RootUrl = startup.RootUrl or "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/",
        RootFolder = startup.RootFolder or "AetherCore",
        Version = startup.Version or "3.1.0",
        Libraries = {},
        LoadedGames = {},
        LoadedModules = {},
        SelectedGui = "new"
    }

    local function readLocal(path)
        if type(readfile) ~= "function" then
            return nil
        end
        local ok, result = pcall(readfile, path)
        if ok and type(result) == "string" and result ~= "" then
            return result
        end
        return nil
    end

    function context.Fetch(path)
        if type(startup.Fetch) == "function" then
            local ok, result = pcall(startup.Fetch, path)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        end
        return readLocal(path) or game:HttpGet(context.RootUrl .. path, true)
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

        local ok, result = xpcall(chunk, debug.traceback)
        if not ok then
            error(string.format("[AetherCore] Failed to run %s: %s", path, tostring(result)))
        end

        context.LoadedModules[path] = result == nil and true or result
        return context.LoadedModules[path]
    end

    function context.RunFunctionModule(path, ...)
        local module = context.LoadModule(path)
        if type(module) == "function" then
            return module(context, ...)
        end
        return module
    end

    function context.LoadGameModule(path)
        if context.LoadedGames[path] then
            return true
        end

        local fetchOk, source = pcall(context.Fetch, path)
        if not fetchOk or type(source) ~= "string" or source == "" then
            return false, string.format("fetch error: %s", tostring(source))
        end

        local chunk, compileError = loadstring(source, "AetherCore/" .. path)
        if not chunk then
            return false, string.format("compile error: %s", tostring(compileError))
        end

        local ok, result = xpcall(chunk, debug.traceback)
        if not ok then
            return false, string.format("runtime error: %s", tostring(result))
        end

        context.LoadedGames[path] = true
        if type(result) == "function" then
            return result(context)
        end
        return true
    end

    local function fail(message)
        error("[AetherCore] " .. tostring(message))
    end

    local function loadLibrary(name)
        local result = context.LoadModule("libraries/" .. name .. ".lua")
        context.Libraries[name] = result
        return result
    end

    for _, name in ipairs({"utility", "signal", "storage", "theme", "tween", "entity", "drawing", "prediction", "target"}) do
        loadLibrary(name)
    end

    local utility = context.Libraries.utility
    local storage = context.Libraries.storage

    utility.WaitForGameLoaded()
    utility.InstallExecutorCompatibility()

    local state = getgenv and getgenv().AetherCore or {}
    state.Name = "AetherCore"
    state.Version = context.Version
    state.Context = context
    state.ModuleRegistrationCount = 0
    state.RegisteredModules = {}
    if getgenv then
        getgenv().AetherCore = state
    end

    local guiChoice = context.Fetch("profiles/gui.txt")
    guiChoice = type(guiChoice) == "string" and guiChoice:gsub("%s+", "") or "new"
    if guiChoice ~= "new" and guiChoice ~= "old" and guiChoice ~= "rise" then
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
    warn("[AetherCore] GUI loaded: " .. guiChoice)

    if not utility.IsVapeCoreReady() then
        fail("GUI core is not ready after loading " .. guiChoice)
    end

    utility.InstallGetCustomAssetFallback()
    utility.InstallTargetInfoFallback()
    utility.InstallSessionInfoFallback()
    utility.InstallCategoryFallbacks()
    utility.InstallHumanoidScaleFallbacks()

    for categoryName, category in pairs(shared.vape.Categories) do
        if type(category) == "table" and type(category.CreateModule) == "function" and category.__AetherCoreOriginalCreateModule == nil then
            local originalCreateModule = category.CreateModule
            category.__AetherCoreOriginalCreateModule = originalCreateModule
            category.CreateModule = function(self, moduleOptions, ...)
                local module = originalCreateModule(self, moduleOptions, ...)
                if module ~= nil then
                    state.ModuleRegistrationCount = (tonumber(state.ModuleRegistrationCount) or 0) + 1
                    local moduleName = type(moduleOptions) == "table" and moduleOptions.Name or type(module) == "table" and module.Name or nil
                    table.insert(state.RegisteredModules, {
                        Category = tostring(categoryName),
                        Name = moduleName ~= nil and tostring(moduleName) or "Unknown"
                    })
                end
                return module
            end
        end
    end

    local universalOk, universalError = context.RunFunctionModule("games/universal.lua")
    if universalOk == false then
        fail("Failed to load universal modules: " .. tostring(universalError))
    end
    warn("[AetherCore] Universal modules loaded")

    local supported = storage.DecodeJson(context.Fetch("profiles/supported.json"), {}) or {}
    local currentGameId = game.GameId
    local currentPlaceId = game.PlaceId
    local matchedPath = nil

    for gameName, gameInfo in pairs(supported) do
        if type(gameInfo) == "table" and tonumber(gameInfo.gameid) == tonumber(currentGameId) then
            for placeName, placeInfo in pairs(gameInfo) do
                if type(placeInfo) == "table" then
                    if tonumber(placeInfo.Place) == tonumber(currentPlaceId) then
                        matchedPath = "games/" .. tostring(gameName) .. "/" .. tostring(placeName) .. ".lua"
                        break
                    end
                    if type(placeInfo.Ids) == "table" then
                        for _, id in ipairs(placeInfo.Ids) do
                            if tonumber(id) == tonumber(currentPlaceId) then
                                matchedPath = "games/" .. tostring(gameName) .. "/" .. tostring(placeName) .. ".lua"
                                break
                            end
                        end
                    end
                end
                if matchedPath then
                    break
                end
            end
        end
        if matchedPath then
            break
        end
    end

    if matchedPath then
        local ok, loadError = context.LoadGameModule(matchedPath)
        if not ok then
            fail("Failed to load " .. matchedPath .. ": " .. tostring(loadError))
        end
        warn("[AetherCore] Loaded supported game module: " .. matchedPath)
    else
        local placePath = "games/" .. tostring(currentPlaceId) .. ".lua"
        local ok, loadError = context.LoadGameModule(placePath)
        if ok then
            warn("[AetherCore] Loaded place module: " .. placePath)
        else
            warn("[AetherCore] No supported game profile matched; place fallback failed: " .. tostring(loadError))
        end
    end

    local customOk, customResult = pcall(function()
        local custom = context.LoadModule("custom_modules.luau")
        if type(custom) == "function" then
            return custom(context)
        end
        return custom
    end)
    if not customOk then
        warn("[AetherCore] custom_modules.luau is unavailable or failed: " .. tostring(customResult))
    else
        warn("[AetherCore] Custom modules loaded")
    end

    if (tonumber(state.ModuleRegistrationCount) or 0) == 0 then
        warn("[AetherCore] No modules were registered. Check payload order or initialization timing.")
    end

    local finalized, finalizeError = gui.Finalize(context)
    if not finalized then
        fail("Failed to finalize GUI: " .. tostring(finalizeError))
    end

    warn("[AetherCore] Ready")
    return context
end
