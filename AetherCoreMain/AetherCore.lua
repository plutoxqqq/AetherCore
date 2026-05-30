-- AetherCore bootstrapper
-- Keeps the public loadstring unchanged while executing the single unified
-- BedWars payload at bedwars/aethercore.luau.

local BEDWARS_ENTRY_PATH = "bedwars/aethercore.luau"
local BEDWARS_ENTRY_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/bedwars/aethercore.luau"

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

local ok, sourceOrError = fetchBedwarsSource()
if not ok then
    error(string.format("[AetherCore] Failed to fetch unified payload: %s", tostring(sourceOrError)))
end

local ran, runtimeError = compileAndRun(sourceOrError)
if not ran then
    error(string.format("[AetherCore] Failed to start unified payload from '%s': %s", BEDWARS_ENTRY_PATH, tostring(runtimeError)))
end
