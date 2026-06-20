-- AetherCore main.lua
-- CatV6-style runtime bootstrap adapted for AetherCore's existing modules.
return function(startup)
    startup = type(startup) == "table" and startup or {}
    repeat task.wait() until game:IsLoaded()

    local rootUrl = startup.RootUrl or "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/"
    local rootFolder = startup.RootFolder or "AetherCore"
    local selectedGui = startup.SelectedGui or "new"
    local context = {
        RootUrl = rootUrl,
        RootFolder = rootFolder,
        SelectedGui = selectedGui,
        Libraries = {},
        State = {
            ModuleRegistrationCount = 0,
            LoadedModules = {},
            FailedModules = {}
        }
    }

    local function ensureFolder(path)
        if type(isfolder) == "function" and type(makefolder) == "function" then
            local ok, exists = pcall(isfolder, path)
            if ok and not exists then
                pcall(makefolder, path)
            end
        end
    end

    for _, folder in ipairs({rootFolder, rootFolder .. "/games", rootFolder .. "/profiles", rootFolder .. "/assets", rootFolder .. "/assets/new", rootFolder .. "/libraries", rootFolder .. "/guis"}) do
        ensureFolder(folder)
    end

    local function isMissingSource(contents)
        if type(contents) ~= "string" then
            return true
        end
        local trimmed = contents:gsub("^%s+", ""):gsub("%s+$", "")
        return trimmed == "" or trimmed == "404: Not Found" or trimmed:find("^404", 1, false) ~= nil
    end

    local function isFile(path)
        if type(isfile) == "function" then
            local ok, result = pcall(isfile, path)
            if ok then return result end
        end
        if type(readfile) == "function" then
            local ok, result = pcall(readfile, path)
            return ok and type(result) == "string" and result ~= ""
        end
        return false
    end

    local function read(path)
        if type(readfile) ~= "function" then return nil end
        local ok, result = pcall(readfile, path)
        if ok and not isMissingSource(result) then
            return result
        end
        return nil
    end

    local function write(path, contents)
        if type(writefile) == "function" and type(contents) == "string" then
            pcall(writefile, path, contents)
        end
    end

    local function fetch(path)
        local cachePath = rootFolder .. "/" .. path
        local cached = read(cachePath) or read(path)
        if cached then
            return cached
        end

        local remote
        local ok, result = pcall(function()
            return game:HttpGet(rootUrl .. path, true)
        end)
        if ok and not isMissingSource(result) then
            remote = result
            write(cachePath, remote)
        end
        if remote then
            return remote
        end
        error("[AetherCore] Unable to load " .. tostring(path))
    end

    if type(writefile) == "function" and not isFile(rootFolder .. "/profiles/commit.txt") then
        write(rootFolder .. "/profiles/commit.txt", "main")
    end

    if not startup.SelectedGui and not startup.Gui then
        local profileGui = read(rootFolder .. "/profiles/gui.txt") or read("profiles/gui.txt")
        if type(profileGui) == "string" and profileGui ~= "" then
            selectedGui = profileGui:gsub("^%s+", ""):gsub("%s+$", "")
            context.SelectedGui = selectedGui
        end
    end

    local function runSource(path, chunkName, ...)
        local source = fetch(path)
        local chunk, compileError = loadstring(source, chunkName or path)
        if not chunk then
            error("[AetherCore] Failed to compile " .. tostring(path) .. ": " .. tostring(compileError))
        end
        return chunk(...)
    end

    if shared.vape and type(shared.vape.Uninject) == "function" then
        pcall(function() shared.vape:Uninject() end)
    end

    if selectedGui == "wurst" then
        selectedGui = "new"
        context.SelectedGui = selectedGui
    end

    local guiPath = "guis/" .. selectedGui .. ".lua"
    if not isFile(rootFolder .. "/" .. guiPath) and not isFile(guiPath) then
        selectedGui = "new"
        guiPath = "guis/new.lua"
        context.SelectedGui = selectedGui
    end

    local vape = runSource(guiPath, "AetherCore/gui", startup.License or {})
    _G.vape = vape
    shared.vape = vape

    local utility = runSource("libraries/utility.lua", "AetherCore/libraries/utility")
    context.Libraries.utility = utility
    if type(utility) == "table" then
        if type(utility.SetRuntimeContext) == "function" then
            utility.SetRuntimeContext(context)
        end
        if type(utility.InstallExecutorCompatibility) == "function" then
            utility.InstallExecutorCompatibility()
        end
        if type(utility.InstallCategoryFallbacks) == "function" then
            utility.InstallCategoryFallbacks()
        end
        if type(utility.ApplyVapeBranding) == "function" then
            utility.ApplyVapeBranding()
        end
    end

    local function notify(title, message, duration, kind)
        if type(vape) == "table" and type(vape.CreateNotification) == "function" then
            pcall(function()
                vape:CreateNotification(title, message, duration or 5, kind)
            end)
        else
            warn("[" .. title .. "] " .. tostring(message))
        end
    end

    local originalCreateModule = {}
    if type(vape) == "table" and type(vape.Categories) == "table" then
        for _, category in pairs(vape.Categories) do
            if type(category) == "table" and type(category.CreateModule) == "function" and originalCreateModule[category] == nil then
                originalCreateModule[category] = category.CreateModule
                category.CreateModule = function(self, moduleDefinition)
                    context.State.ModuleRegistrationCount += 1
                    return originalCreateModule[self](self, moduleDefinition)
                end
            end
        end
    end

    local function loadModule(path, required)
        local ok, result, extra = pcall(function()
            local loaded = runSource(path, "AetherCore/" .. path)
            if type(loaded) == "function" then
                return loaded(context)
            end
            return loaded
        end)
        if ok and result ~= false then
            table.insert(context.State.LoadedModules, path)
            return true
        end

        local message = ok and tostring(extra or result or "module returned false") or tostring(result)
        table.insert(context.State.FailedModules, {Path = path, Error = message})
        if required then
            notify("AetherCore", "Failed to load " .. path .. ": " .. message, 12, "alert")
        else
            warn("[AetherCore] Optional module skipped: " .. path .. ": " .. message)
        end
        return false, message
    end

    if not shared.VapeIndependent then
        loadModule("games/universal.luau", true)
        loadModule("games/" .. tostring(game.PlaceId) .. ".luau", false)
        loadModule("custom_modules.luau", false)
    end

    if type(vape) == "table" then
        if type(vape.Load) == "function" then
            vape:Load()
        end
        if type(vape.Save) == "function" then
            task.spawn(function()
                repeat
                    vape:Save()
                    task.wait(10)
                until not vape.Loaded
            end)
        end
    end

    notify("AetherCore", "Finished loading " .. tostring(#context.State.LoadedModules) .. " module file(s).", 5, "info")
    return shared.VapeIndependent and vape or context
end
