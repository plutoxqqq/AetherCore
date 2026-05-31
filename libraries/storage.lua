-- Executor-safe profile storage helpers.
local Storage = {}

function Storage.Read(path)
    if type(readfile) ~= "function" then
        return nil
    end
    local ok, result = pcall(readfile, path)
    if ok then
        return result
    end
    return nil
end

function Storage.Write(path, contents)
    if type(writefile) ~= "function" then
        return false
    end
    local ok = pcall(writefile, path, contents)
    return ok
end

function Storage.Exists(path)
    if type(isfile) == "function" then
        local ok, result = pcall(isfile, path)
        return ok and result or false
    end
    return Storage.Read(path) ~= nil
end

function Storage.DecodeJson(contents, fallback)
    if type(contents) ~= "string" or contents == "" then
        return fallback
    end
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONDecode(contents)
    end)
    if ok then
        return result
    end
    return fallback
end

function Storage.EncodeJson(value)
    local ok, result = pcall(function()
        return game:GetService("HttpService"):JSONEncode(value)
    end)
    if ok then
        return result
    end
    return "{}"
end

return Storage
