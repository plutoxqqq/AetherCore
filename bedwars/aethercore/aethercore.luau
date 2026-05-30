-- AetherCore compatibility entrypoint
-- The old modular BedWars path now delegates to the single combined payload so
-- direct legacy users do not load the removed custom module tree.

local UNIFIED_ENTRY_PATH = "bedwars/aethercore.luau"
local UNIFIED_ENTRY_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/bedwars/aethercore.luau"
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

local function fetchUnifiedSource()
    local success, source = pcall(function()
        return game:HttpGet(UNIFIED_ENTRY_URL)
    end)

    if success and type(source) == "string" and source ~= "" then
        return true, source
    end

    if type(readfile) == "function" then
        local readOk, localSource = pcall(readfile, UNIFIED_ENTRY_PATH)
        if readOk and type(localSource) == "string" and localSource ~= "" then
            warn(string.format("[AetherCore] Remote download failed, using local file '%s'.", UNIFIED_ENTRY_PATH))
            return true, localSource
        end
    end

    return false, string.format("failed to download '%s': %s", UNIFIED_ENTRY_URL, tostring(source))
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

local ok, sourceOrError = fetchUnifiedSource()
if not ok then
    error(string.format("[AetherCore] Failed to fetch unified payload: %s", tostring(sourceOrError)))
end

local chunk, compileError = loadstring(sourceOrError)
if not chunk then
    error(string.format("[AetherCore] Failed to compile unified payload: %s", tostring(compileError)))
end

local ran, runtimeError = xpcall(chunk, debug.traceback)
if not ran then
    error(string.format("[AetherCore] Failed to run unified payload: %s", tostring(runtimeError)))
end

local initialized, initError = initializeVapeCore()
if not initialized then
    error(string.format("[AetherCore] Failed to initialize Vape core: %s", tostring(initError)))
end
