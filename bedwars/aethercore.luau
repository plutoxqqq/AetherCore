-- AetherCore legacy entrypoint
-- Kept for backwards compatibility; the real BedWars loader now lives at
-- bedwars/aethercore/aethercore.luau.

local MODULAR_ENTRY_PATH = "bedwars/aethercore/aethercore.luau"
local MODULAR_ENTRY_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/bedwars/aethercore/aethercore.luau"

local function fetchModularEntry()
    local ok, source = pcall(function()
        return game:HttpGet(MODULAR_ENTRY_URL)
    end)

    if ok and type(source) == "string" and source ~= "" then
        return true, source
    end

    if type(readfile) == "function" then
        local readOk, localSource = pcall(readfile, MODULAR_ENTRY_PATH)
        if readOk and type(localSource) == "string" and localSource ~= "" then
            warn("[AetherCore] Using local modular entry fallback.")
            return true, localSource
        end
    end

    return false, tostring(source)
end

local ok, sourceOrError = fetchModularEntry()
if not ok then
    error("[AetherCore] Failed to fetch modular entry: " .. tostring(sourceOrError))
end

local chunk, compileError = loadstring(sourceOrError)
if not chunk then
    error("[AetherCore] Failed to compile modular entry: " .. tostring(compileError))
end

local ran, runtimeError = pcall(chunk)
if not ran then
    error("[AetherCore] Failed to run modular entry: " .. tostring(runtimeError))
end
