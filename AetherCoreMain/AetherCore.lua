-- AetherCore bootstrapper
-- Keeps the public loadstring unchanged while executing the single unified
-- BedWars payload at bedwars/aethercore.luau.

local BEDWARS_ENTRY_PATH = "bedwars/aethercore.luau"
local BEDWARS_ENTRY_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/bedwars/aethercore.luau"
local VAPE_CORE_BASE_URL = "https://raw.githubusercontent.com/7GrandDadPGN/Vape" .. string.char(86, 52) .. "ForRoblox/main/"
local VAPE_CORE_URL = VAPE_CORE_BASE_URL .. "NewMainScript.lua"

local BRAND_NAME = "AetherCore"

local function brandVapeCoreSource(source)
    if type(source) ~= "string" then
        return source
    end

    return source
        :gsub("Vape " .. string.char(86, 52), BRAND_NAME)
        :gsub("VAPE " .. string.char(86, 52), BRAND_NAME)
end

local function isVapeCoreReady()
    return type(shared) == "table"
        and type(shared.vape) == "table"
        and type(shared.vape.Libraries) == "table"
        and type(shared.vape.Categories) == "table"
end

local function applyVapeBranding()
    if not isVapeCoreReady() then
        return
    end

    local vape = shared.vape
    for _, key in {"Name", "Title", "Brand", "BrandName", "DisplayName", "WindowTitle"} do
        if type(vape[key]) == "string" then
            vape[key] = BRAND_NAME
        end
    end
end

local function brandVisibleText(text)
    if type(text) ~= "string" or text == "" then
        return text
    end

    local versionText = string.char(86, 52)
    local legacyAeroText = "Ae" .. "ro"
    local brandedText = text
        :gsub(legacyAeroText .. "%s*" .. versionText, BRAND_NAME)
        :gsub(string.upper(legacyAeroText) .. "%s*" .. versionText, BRAND_NAME)
        :gsub(legacyAeroText, BRAND_NAME)
        :gsub(string.upper(legacyAeroText), BRAND_NAME)
        :gsub("Vape%s*" .. versionText, BRAND_NAME)
        :gsub("Vape" .. versionText, BRAND_NAME)
        :gsub("%s+" .. versionText, "")
        :gsub(versionText .. "%s+", "")

    if brandedText == versionText or brandedText == "" then
        return BRAND_NAME
    end

    return brandedText
end

local function applyVisibleBrandingOverrides()
    local function scan(container)
        if container == nil or type(container.GetDescendants) ~= "function" then
            return
        end

        for _, object in container:GetDescendants() do
            if typeof(object) == "Instance" and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
                local brandedText = brandVisibleText(object.Text)
                if brandedText ~= object.Text then
                    object.Text = brandedText
                end
            end
        end
    end

    pcall(function()
        scan(game:GetService("CoreGui"))
    end)

    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        scan(player and player:FindFirstChildOfClass("PlayerGui"))
    end)
end

local function ensureVapeCore()
    if isVapeCoreReady() then
        applyVapeBranding()
        return true
    end

    if type(loadstring) ~= "function" then
        return false, "loadstring is not available in this executor"
    end

    shared.VapeIndependent = true
    if shared.vape ~= nil and not isVapeCoreReady() then
        shared.vape = nil
    end

    local success, result = pcall(function()
        local source = game:HttpGet(VAPE_CORE_URL, true)
        local loader, compileError = loadstring(brandVapeCoreSource(source), BRAND_NAME)
        if not loader then
            error(string.format("compile error: %s", tostring(compileError)))
        end
        return loader()
    end)

    if not success then
        return false, tostring(result)
    end

    if not isVapeCoreReady() then
        return false, "Vape core loaded without the required Libraries and Categories APIs"
    end

    applyVapeBranding()
    applyVisibleBrandingOverrides()
    if type(task) == "table" then
        if type(task.defer) == "function" then
            task.defer(applyVisibleBrandingOverrides)
        end
        if type(task.delay) == "function" then
            task.delay(1, applyVisibleBrandingOverrides)
        end
    end
    return true
end

local function initializeVapeCore()
    applyVapeBranding()

    if type(shared) == "table" and type(shared.vape) == "table" and type(shared.vape.Init) == "function" then
        local success, result = pcall(function()
            shared.vape:Init()
        end)

        if not success then
            return false, tostring(result)
        end
    end

    applyVapeBranding()
    applyVisibleBrandingOverrides()
    if type(task) == "table" then
        if type(task.defer) == "function" then
            task.defer(applyVisibleBrandingOverrides)
        end
        if type(task.delay) == "function" then
            task.delay(1, applyVisibleBrandingOverrides)
        end
    end
    return true
end

local function loadVapeRuntimeLibrary(libraryName)
    if not isVapeCoreReady() then
        return false, "Vape core is not ready"
    end

    local libraries = shared.vape.Libraries
    if type(libraries[libraryName]) == "table" then
        return true
    end

    local success, result = pcall(function()
        local source = game:HttpGet(VAPE_CORE_BASE_URL .. "libraries/" .. libraryName .. ".lua", true)
        local loader, compileError = loadstring(source, "AetherCoreRuntimeLibrary:" .. libraryName)
        if not loader then
            error(string.format("compile error: %s", tostring(compileError)))
        end
        return loader()
    end)

    if not success then
        return false, string.format("failed to load '%s': %s", libraryName, tostring(result))
    end

    if type(result) ~= "table" then
        return false, string.format("'%s' returned %s instead of a table", libraryName, typeof(result))
    end

    libraries[libraryName] = result
    return true
end

local function installGetCustomAssetFallback()
    local libraries = shared.vape.Libraries
    if type(libraries.getcustomasset) == "function" then
        return
    end

    libraries.getcustomasset = function(path)
        if type(getcustomasset) == "function" then
            local success, asset = pcall(getcustomasset, path)
            if success and asset ~= nil then
                return asset
            end
        end

        if type(getsynasset) == "function" then
            local success, asset = pcall(getsynasset, path)
            if success and asset ~= nil then
                return asset
            end
        end

        return path
    end
end

local function installTargetInfoFallback()
    local libraries = shared.vape.Libraries
    if type(libraries.targetinfo) == "table" then
        libraries.targetinfo.Targets = type(libraries.targetinfo.Targets) == "table" and libraries.targetinfo.Targets or {}
        return
    end

    libraries.targetinfo = {
        Targets = {},
        Priority = {},
        Render = function() end,
        Reset = function(self)
            if type(self.Targets) == "table" then
                table.clear(self.Targets)
            end
        end
    }
end

local function installSessionInfoFallback()
    local libraries = shared.vape.Libraries
    if type(libraries.sessioninfo) == "table" and type(libraries.sessioninfo.AddItem) == "function" then
        return
    end

    local sessionInfo = type(libraries.sessioninfo) == "table" and libraries.sessioninfo or {}
    sessionInfo.Items = type(sessionInfo.Items) == "table" and sessionInfo.Items or {}
    sessionInfo.AddItem = function(self, name, defaultValue, valueCallback, numeric)
        local item = {
            Name = tostring(name),
            Value = defaultValue or 0,
            Numeric = numeric ~= false,
            GetValue = type(valueCallback) == "function" and valueCallback or nil
        }

        function item:SetValue(value)
            self.Value = value
            return self.Value
        end

        function item:Increment(amount)
            amount = tonumber(amount) or 1
            self.Value = (tonumber(self.Value) or 0) + amount
            return self.Value
        end

        function item:Get()
            if self.GetValue then
                return self.GetValue()
            end
            return self.Value
        end

        self.Items[item.Name] = item
        return item
    end

    libraries.sessioninfo = sessionInfo
end

local function hasRequiredVapeRuntime()
    if not isVapeCoreReady() then
        return false, "Vape core is not ready"
    end

    for _, libraryName in {"entity", "prediction"} do
        local loaded, loadError = loadVapeRuntimeLibrary(libraryName)
        if not loaded then
            return false, loadError
        end
    end

    installGetCustomAssetFallback()
    installTargetInfoFallback()
    installSessionInfoFallback()

    local libraries = shared.vape.Libraries
    for _, libraryName in {"entity", "targetinfo", "sessioninfo", "prediction", "uipallet", "tween", "color", "getfontsize", "getcustomasset"} do
        if libraries[libraryName] == nil then
            return false, string.format("missing '%s'", libraryName)
        end
    end

    return true
end

local function installModuleRegistrationTracker()
    if not isVapeCoreReady() then
        return
    end

    local state = getgenv().AetherCore or {}
    getgenv().AetherCore = state
    state.ModuleRegistrationCount = 0
    state.RegisteredModules = {}

    for categoryName, category in pairs(shared.vape.Categories) do
        if type(category) == "table" and type(category.CreateModule) == "function" and category.__AetherCoreOriginalCreateModule == nil then
            local originalCreateModule = category.CreateModule
            category.__AetherCoreOriginalCreateModule = originalCreateModule
            category.CreateModule = function(self, moduleOptions, ...)
                local module = originalCreateModule(self, moduleOptions, ...)
                if module ~= nil then
                    state.ModuleRegistrationCount += 1
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
end

local function countRegisteredModulesFromCategories()
    if not isVapeCoreReady() then
        return 0
    end

    local seen = {}
    local count = 0
    local function mark(module)
        if type(module) == "table" and not seen[module] then
            seen[module] = true
            count += 1
        end
    end

    for _, category in pairs(shared.vape.Categories) do
        if type(category) == "table" then
            for _, key in {"Modules", "ModuleList", "List", "Objects"} do
                if type(category[key]) == "table" then
                    for _, module in pairs(category[key]) do
                        mark(module)
                    end
                end
            end
        end
    end

    return count
end

local function getRegisteredModuleCount()
    local state = type(getgenv) == "function" and getgenv().AetherCore or nil
    local trackedCount = type(state) == "table" and tonumber(state.ModuleRegistrationCount) or 0
    return math.max(trackedCount or 0, countRegisteredModulesFromCategories())
end

local function compileAndRun(source)
    if type(loadstring) ~= "function" then
        return false, "loadstring is not available in this executor"
    end

    local fn, compileErr = loadstring(source, "AetherCoreUnifiedPayload")
    if not fn then
        return false, string.format("compile error: %s", tostring(compileErr))
    end

    local ran, runtimeErr = xpcall(fn, debug.traceback)
    if not ran then
        return false, string.format("runtime error: %s", tostring(runtimeErr))
    end

    return true
end

local function fetchBedwarsSource()
    local success, source = pcall(function()
        return game:HttpGet(BEDWARS_ENTRY_URL)
    end)

    if success and type(source) == "string" and source ~= "" then
        return true, source
    end

    if type(readfile) == "function" then
        local readOk, localSource = pcall(readfile, BEDWARS_ENTRY_PATH)
        if readOk and type(localSource) == "string" and localSource ~= "" then
            warn(string.format("[AetherCore] Remote download failed, using local file '%s'.", BEDWARS_ENTRY_PATH))
            return true, localSource
        end
    end

    return false, string.format("failed to download '%s': %s", BEDWARS_ENTRY_URL, tostring(source))
end

local coreReady, coreError = ensureVapeCore()
if not coreReady then
    error(string.format("[AetherCore] Failed to load Vape core: %s", tostring(coreError)))
end
warn("[AetherCore] Vape core loaded")

local runtimeReady, runtimeError = hasRequiredVapeRuntime()
if not runtimeReady then
    error(string.format("[AetherCore] Vape core is missing required runtime libraries: %s", tostring(runtimeError)))
end

installModuleRegistrationTracker()

local ok, sourceOrError = fetchBedwarsSource()
if not ok then
    error(string.format("[AetherCore] Failed to fetch unified payload: %s", tostring(sourceOrError)))
end
warn("[AetherCore] Payload fetched")

local ran, runtimeError = compileAndRun(sourceOrError)
if not ran then
    error(string.format("[AetherCore] Failed to start unified payload from '%s': %s", BEDWARS_ENTRY_PATH, tostring(runtimeError)))
end
warn("[AetherCore] Payload executed")

if getRegisteredModuleCount() == 0 then
    warn("[AetherCore] No modules were registered. Check payload order or initialization timing.")
end

local initialized, initError = initializeVapeCore()
if not initialized then
    error(string.format("[AetherCore] Failed to initialize Vape core: %s", tostring(initError)))
end
warn("[AetherCore] Vape UI initialized")
