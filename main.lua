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
        Version = startup.Version or "3.2.2",
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

    function context.RegisterModuleRecord(name, category, status, source, details)
        state.ModuleRegistrationCount = (tonumber(state.ModuleRegistrationCount) or 0) + 1
        details = type(details) == "table" and details or {}
        table.insert(state.RegisteredModules, {
            Name = tostring(name or "Unknown"),
            Category = tostring(category or "Unknown"),
            Status = tostring(status or "registered"),
            Source = tostring(source or context.CurrentSource or "unknown"),
            Tooltip = type(details.Tooltip) == "string" and details.Tooltip or nil,
            Description = type(details.Description) == "string" and details.Description or nil
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

    function context.ValidateRequiredCategories()
        if type(shared) ~= "table" or type(shared.vape) ~= "table" or type(shared.vape.Categories) ~= "table" then
            return false, "GUI categories are unavailable"
        end

        local moduleAssistCategory = shared.vape.Categories["Module Assist"] or shared.vape.Categories.ModuleAssist
        if type(moduleAssistCategory) == "table" and type(moduleAssistCategory.CreateModule) == "function" then
            shared.vape.Categories.ModuleAssist = moduleAssistCategory
            shared.vape.Categories["Module Assist"] = moduleAssistCategory
        end

        local requiredCategories = {
            "Combat",
            "Blatant",
            "Render",
            "Utility",
            "World",
            "Inventory",
            "Minigames",
            "Kits",
            "Legit",
            "BoostFPS",
            "VibeCoded",
            "Module Assist",
            "Friends",
            "Targets",
            "Profiles"
        }
        local missing = {}
        for _, categoryName in ipairs(requiredCategories) do
            local category = shared.vape.Categories[categoryName]
            if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
                table.insert(missing, categoryName)
            end
        end

        if #missing > 0 then
            return false, "missing categories: " .. table.concat(missing, ", ")
        end
        return true
    end

    local categoriesOk, categoriesError = context.ValidateRequiredCategories()
    if not categoriesOk then
        fail("GUI category validation failed: " .. tostring(categoriesError))
    end

    function context.NormalizeModuleName(name)
        if type(name) ~= "string" then
            return nil
        end

        local normalized = name:lower():gsub("[^%w]", "")
        if normalized == "" then
            return nil
        end

        return normalized
    end

    local function createDuplicateModuleStub(moduleName, categoryName)
        local optionTemplate = {Value = nil, Enabled = false, List = {}}
        function optionTemplate:SetValue(value)
            self.Value = value
        end
        function optionTemplate:Toggle(value)
            self.Enabled = value == nil and not self.Enabled or value == true
        end
        function optionTemplate:Change(value)
            self.List = type(value) == "table" and value or self.List
        end
        function optionTemplate:SetList(value)
            self.List = type(value) == "table" and value or self.List
        end
        function optionTemplate:SetVisible() end
        function optionTemplate:Refresh(value)
            if type(value) == "table" then
                self.List = value
            end
        end

        local moduleStub = {
            Name = moduleName,
            Category = tostring(categoryName),
            Enabled = false,
            Options = {},
            Duplicate = true
        }

        local function createOption(self, options)
            options = type(options) == "table" and options or {}
            local option = {}
            for key, value in pairs(optionTemplate) do
                option[key] = value
            end
            option.Name = options.Name
            if options.Default ~= nil then
                option.Value = options.Default
            elseif options.Value ~= nil then
                option.Value = options.Value
            end
            option.Enabled = options.Default == true or options.Enabled == true
            self.Options[tostring(option.Name or #self.Options + 1)] = option
            return option
        end

        moduleStub.CreateToggle = createOption
        moduleStub.CreateSlider = createOption
        moduleStub.CreateDropdown = createOption
        moduleStub.CreateColorSlider = createOption
        moduleStub.CreateTextBox = createOption
        moduleStub.CreateButton = createOption
        moduleStub.CreateFont = createOption
        moduleStub.CreateBind = createOption
        function moduleStub:Clean() end
        function moduleStub:Toggle() end

        return moduleStub
    end

    function context.InstallModuleRegistrationHooks()
        if type(shared) ~= "table" or type(shared.vape) ~= "table" or type(shared.vape.Categories) ~= "table" then
            return false, "GUI categories are unavailable"
        end

        shared.vape.Modules = type(shared.vape.Modules) == "table" and shared.vape.Modules or {}
        state.RegisteredModuleNames = type(state.RegisteredModuleNames) == "table" and state.RegisteredModuleNames or {}

        for categoryName, category in pairs(shared.vape.Categories) do
            if type(category) == "table" and type(category.CreateModule) == "function" and category.__AetherCoreOriginalCreateModule == nil then
                local originalCreateModule = category.CreateModule
                category.__AetherCoreOriginalCreateModule = originalCreateModule
                category.CreateModule = function(self, moduleOptions, ...)
                    local moduleName = type(moduleOptions) == "table" and moduleOptions.Name or nil
                    local normalizedName = context.NormalizeModuleName(moduleName)
                    if normalizedName and state.RegisteredModuleNames[normalizedName] then
                        local originalRecord = state.RegisteredModuleNames[normalizedName]
                        warnf(
                            "Skipped duplicate module '%s' from %s; already loaded as '%s' from %s",
                            tostring(moduleName),
                            tostring(context.CurrentSource or "unknown"),
                            tostring(originalRecord.Name or "Unknown"),
                            tostring(originalRecord.Source or "unknown")
                        )
                        state.DuplicateModulesSkipped = (tonumber(state.DuplicateModulesSkipped) or 0) + 1
                        table.insert(state.RegisteredModules, {
                            Name = tostring(moduleName or "Unknown"),
                            Category = tostring(categoryName or "Unknown"),
                            Status = "duplicate-skipped",
                            Source = tostring(context.CurrentSource or "unknown"),
                            Tooltip = type(moduleOptions) == "table" and type(moduleOptions.Tooltip) == "string" and moduleOptions.Tooltip or nil,
                            Description = type(moduleOptions) == "table" and type(moduleOptions.Description) == "string" and moduleOptions.Description or nil
                        })
                        return createDuplicateModuleStub(moduleName, categoryName)
                    end

                    local module = originalCreateModule(self, moduleOptions, ...)
                    if module ~= nil then
                        moduleName = moduleName or type(module) == "table" and module.Name or nil
                        normalizedName = context.NormalizeModuleName(moduleName)
                        if type(module) == "table" then
                            module.Name = module.Name or moduleName
                            module.Category = module.Category or tostring(categoryName)
                            if type(moduleName) == "string" and moduleName ~= "" then
                                shared.vape.Modules[moduleName] = module
                                shared.vape.Modules[moduleName:gsub("%s+", "")] = shared.vape.Modules[moduleName:gsub("%s+", "")] or module
                            end
                        end
                        if normalizedName then
                            state.RegisteredModuleNames[normalizedName] = {
                                Name = tostring(moduleName or "Unknown"),
                                Source = tostring(context.CurrentSource or "unknown")
                            }
                        end
                        context.RegisterModuleRecord(moduleName, categoryName, "loaded", context.CurrentSource, moduleOptions)
                    end
                    return module
                end
            end
        end

        return true
    end

    local hooksOk, hooksError = context.InstallModuleRegistrationHooks()
    if not hooksOk then
        fail("Failed to install module registration hooks: " .. tostring(hooksError))
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

    local function appendUniquePath(paths, path)
        if type(path) ~= "string" or path == "" then
            return
        end
        for _, existingPath in ipairs(paths) do
            if existingPath == path then
                return
            end
        end
        table.insert(paths, path)
    end

    local function idListContains(list, id)
        if type(list) ~= "table" or id == nil then
            return false
        end
        for _, value in pairs(list) do
            if tonumber(value) == id then
                return true
            end
        end
        return false
    end

    local function collectSupportedGamePaths(currentGameId, currentPlaceId)
        local supported = storage.DecodeJson(context.Fetch("profiles/supported.json"), {}) or {}
        local paths = {}
        local lobbyFallbackPath = nil
        local mainFallbackPath = nil

        for _, gameInfo in pairs(supported) do
            if type(gameInfo) == "table" and tonumber(gameInfo.gameid or gameInfo.GameId) == currentGameId then
                for groupName, groupInfo in pairs(gameInfo) do
                    if type(groupInfo) == "table" then
                        local groupPath = groupInfo.Path or groupInfo.path
                        local groupPlace = tonumber(groupInfo.Place or groupInfo.place)
                        local exactMatch = groupPlace == currentPlaceId or idListContains(groupInfo.Ids or groupInfo.ids, currentPlaceId)

                        local normalizedGroupName = tostring(groupName):lower()
                        if exactMatch then
                            appendUniquePath(paths, groupPath)
                        elseif normalizedGroupName == "lobby" then
                            lobbyFallbackPath = groupPath
                        elseif normalizedGroupName == "main" or normalizedGroupName == "match" then
                            mainFallbackPath = groupPath
                        end
                    end
                end
            end
        end

        if #paths == 0 then
            -- Never use a lobby payload as the default for an unknown place in a
            -- supported game. BedWars can rotate or add match PlaceIds, and using
            -- the lobby payload there registers lobby-only modules in real matches.
            appendUniquePath(paths, mainFallbackPath)
            if #paths == 0 and currentPlaceId ~= nil then
                appendUniquePath(paths, lobbyFallbackPath)
            end
        end

        return paths
    end

    local currentGameId = tonumber(game.GameId)
    local currentPlaceId = tonumber(game.PlaceId)
    local placePath = "games/" .. tostring(currentPlaceId or "unknown") .. ".luau"
    local gamePaths = {placePath}
    for _, supportedPath in ipairs(collectSupportedGamePaths(currentGameId, currentPlaceId)) do
        appendUniquePath(gamePaths, supportedPath)
    end

    local loadedPlaceModule = false
    local loadedGamePaths = {}
    local loadErrors = {}
    for _, candidatePath in ipairs(gamePaths) do
        local ok, loadError = context.LoadGameModule(candidatePath)
        if ok then
            loadedPlaceModule = true
            table.insert(loadedGamePaths, candidatePath)
            warnf("Loaded place module: %s", candidatePath)
        else
            table.insert(loadErrors, candidatePath .. ": " .. tostring(loadError))
        end
    end
    context.DetectedGame = {
        GameId = currentGameId,
        PlaceId = currentPlaceId,
        CandidatePaths = gamePaths,
        LoadedPaths = loadedGamePaths,
        Errors = loadErrors
    }

    if not loadedPlaceModule then
        warnf("No place module loaded for GameId %s PlaceId %s: %s", tostring(currentGameId or "unknown"), tostring(currentPlaceId or "unknown"), table.concat(loadErrors, " | "))
    end

    local customOk, customResult = pcall(function()
        return context.RunFunctionModule("custom_modules.luau")
    end)
    if not customOk then
        warnf("custom_modules.luau is unavailable or failed: %s", tostring(customResult))
    else
        warn("[AetherCore] Custom modules loaded")
    end

    function context.SynchronizeExistingModules()
        if type(shared) ~= "table" or type(shared.vape) ~= "table" then
            return 0
        end
        local modules = type(shared.vape.Modules) == "table" and shared.vape.Modules or {}
        shared.vape.Modules = modules
        local synchronized = 0

        for moduleName, module in pairs(modules) do
            if type(module) == "table" and type(moduleName) == "string" and moduleName ~= "" then
                module.Name = module.Name or moduleName
                modules[module.Name] = module
                modules[module.Name:gsub("%s+", "")] = modules[module.Name:gsub("%s+", "")] or module
                synchronized = synchronized + 1
            end
        end

        return synchronized
    end

    local synchronizedModules = context.SynchronizeExistingModules()
    if synchronizedModules > 0 then
        warnf("Synchronized %s existing module records", tostring(synchronizedModules))
    end

    local moduleAssistOk, moduleAssistResult = pcall(function()
        local moduleAssist = context.LoadModule("libraries/moduleassist.lua")
        if type(moduleAssist) == "table" and type(moduleAssist.Install) == "function" then
            return moduleAssist.Install(context)
        end
        return false, "library did not expose Install"
    end)
    if not moduleAssistOk or moduleAssistResult == false then
        warnf("Module Assist failed to load: %s", tostring(moduleAssistResult))
    else
        warn("[AetherCore] Module Assist loaded")
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
