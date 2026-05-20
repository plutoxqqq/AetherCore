-- AetherCore bootstrapper
-- Delegates execution to bedwars/aethercore.luau.

local BEDWARS_ENTRY_PATH = "bedwars/aethercore.luau"

local function runBedwarsEntryFromDisk()
    if type(loadfile) == "function" then
        local loadedChunk, loadError = loadfile(BEDWARS_ENTRY_PATH)
        if not loadedChunk then
            return false, string.format("loadfile failed: %s", tostring(loadError))
        end

        loadedChunk()
        return true
    end

    if type(readfile) == "function" and type(loadstring) == "function" then
        local readSuccess, sourceOrError = pcall(readfile, BEDWARS_ENTRY_PATH)
        if not readSuccess then
            return false, string.format("readfile failed: %s", tostring(sourceOrError))
        end

        local compiledChunk, compileError = loadstring(sourceOrError)
        if not compiledChunk then
            return false, string.format("loadstring failed: %s", tostring(compileError))
        end

        compiledChunk()
        return true
    end

    return false, "no supported file loader found (expected loadfile or readfile+loadstring)"
end

local ok, err = runBedwarsEntryFromDisk()
if not ok then
    error(string.format("[AetherCore] Failed to start from '%s': %s", BEDWARS_ENTRY_PATH, tostring(err)))
end
