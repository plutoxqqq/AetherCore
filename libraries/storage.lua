-- Executor-safe cache and profile storage helpers.
local Storage = {}

local function ensureParent(path)
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then
        return
    end
    local current = ""
    for part in tostring(path):gmatch("[^/]+") do
        if part:find("%.") and not tostring(path):find("/" .. part .. "/") then
            break
        end
        current = current == "" and part or current .. "/" .. part
        local ok, exists = pcall(isfolder, current)
        if not ok or not exists then
            pcall(makefolder, current)
        end
    end
end

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
    ensureParent(path)
    local ok = pcall(writefile, path, tostring(contents or ""))
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
    warn("[AetherCore] Failed to decode JSON profile data; using fallback")
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

function Storage.LoadProfile(path, defaults)
    local profile = {}
    for key, value in pairs(defaults or {}) do
        profile[key] = value
    end

    local saved = Storage.DecodeJson(Storage.Read(path), nil)
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            profile[key] = value
        end
    end
    profile.profileVersion = profile.profileVersion or profile.profilesVersion or 1
    return profile
end

function Storage.SaveProfile(path, profile)
    if type(profile) ~= "table" then
        return false
    end
    profile.profileVersion = profile.profileVersion or 1
    return Storage.Write(path, Storage.EncodeJson(profile))
end

function Storage.MigrateLegacyProfiles(context)
    if type(context) ~= "table" or type(context.RootFolder) ~= "string" then
        return false
    end

    local legacyPaths = {
        context.RootFolder .. "/profiles/default.json",
        "profiles/default.json"
    }
    for _, legacyPath in ipairs(legacyPaths) do
        local legacy = Storage.DecodeJson(Storage.Read(legacyPath), nil)
        if type(legacy) == "table" and type(context.Profile) == "table" then
            for key, value in pairs(legacy) do
                if context.Profile[key] == nil then
                    context.Profile[key] = value
                end
            end
            context.Profile.migratedFrom = context.Profile.migratedFrom or legacyPath
            return true
        end
    end
    return false
end

function Storage.ListPremadeProfiles(context)
    local root = type(context) == "table" and context.RootFolder or "AetherCore"
    local folder = root .. "/profiles/premade"
    local files = {}
    if type(listfiles) == "function" then
        local ok, result = pcall(listfiles, folder)
        if ok and type(result) == "table" then
            for _, file in ipairs(result) do
                table.insert(files, file)
            end
        end
    end
    return files
end

return Storage
