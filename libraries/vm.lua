-- Internal runtime helpers for compiling and running AetherCore chunks.
local VM = {}
local unpack = table.unpack or unpack

function VM.Compile(source, chunkName)
    if type(loadstring) ~= "function" then
        return nil, "loadstring is not available in this executor"
    end
    if type(source) ~= "string" or source == "" then
        return nil, "source is empty"
    end
    return loadstring(source, chunkName or "AetherCoreChunk")
end

function VM.Run(source, chunkName, ...)
    local chunk, compileError = VM.Compile(source, chunkName)
    if not chunk then
        return false, compileError
    end

    local args = {...}
    local results
    local ok, runtimeError = xpcall(function()
        results = {chunk(unpack(args))}
    end, debug.traceback)

    if not ok then
        return false, runtimeError
    end

    return true, unpack(results)
end

function VM.LoadModule(context, path)
    if type(context) ~= "table" or type(context.LoadModule) ~= "function" then
        return false, "invalid runtime context"
    end

    local ok, result = xpcall(function()
        return context.LoadModule(path)
    end, debug.traceback)

    if not ok then
        return false, result
    end
    return true, result
end

return VM
