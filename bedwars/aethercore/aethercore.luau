-- AetherCore compatibility entrypoint
-- The old modular BedWars path now delegates to the single combined payload so
-- direct legacy users do not load the removed custom module tree.

local UNIFIED_ENTRY_PATH = "bedwars/aethercore.luau"
local UNIFIED_ENTRY_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/bedwars/aethercore.luau"

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
