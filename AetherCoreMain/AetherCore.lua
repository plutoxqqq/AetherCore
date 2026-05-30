-- AetherCore bootstrapper
-- Keeps the public loadstring unchanged while executing the single unified
-- BedWars payload at bedwars/aethercore.luau.

local BEDWARS_ENTRY_PATH = "bedwars/aethercore.luau"
local BEDWARS_ENTRY_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/bedwars/aethercore.luau"
local VAPE_CORE_URL = "https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua"

local function isVapeCoreReady()
    return type(shared) == "table"
        and type(shared.vape) == "table"
        and type(shared.vape.Libraries) == "table"
        and type(shared.vape.Categories) == "table"
end

local function ensureVapeCore()
    if isVapeCoreReady() then
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
        local loader, compileError = loadstring(source, "VapeV4")
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

    return true
end

local function initializeVapeCore()
    if type(shared) == "table" and type(shared.vape) == "table" and type(shared.vape.Init) == "function" then
        local success, result = pcall(function()
            shared.vape:Init()
        end)

        if not success then
            return false, tostring(result)
        end
    end

    return true
end

local function hasRequiredVapeRuntime()
    return isVapeCoreReady()
        and type(shared.vape.Libraries.entity) == "table"
        and type(shared.vape.Libraries.targetinfo) == "table"
        and type(shared.vape.Libraries.sessioninfo) == "table"
end

local function compileAndRun(source)
    if type(loadstring) ~= "function" then
        return false, "loadstring is not available in this executor"
    end

    local fn, compileErr = loadstring(source)
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

local initialized, initError = initializeVapeCore()
if not initialized then
    error(string.format("[AetherCore] Failed to initialize Vape core: %s", tostring(initError)))
end

if not hasRequiredVapeRuntime() then
    error("[AetherCore] Vape core is missing required runtime libraries after initialization")
end

local ok, sourceOrError = fetchBedwarsSource()
if not ok then
    error(string.format("[AetherCore] Failed to fetch unified payload: %s", tostring(sourceOrError)))
end

local ran, runtimeError = compileAndRun(sourceOrError)
if not ran then
    error(string.format("[AetherCore] Failed to start unified payload from '%s': %s", BEDWARS_ENTRY_PATH, tostring(runtimeError)))
end

local initialized, initError = initializeVapeCore()
if not initialized then
    error(string.format("[AetherCore] Failed to initialize Vape core: %s", tostring(initError)))
end
