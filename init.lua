-- AetherCore init.lua
-- Prepares cache folders, updates core cached files when possible, then executes
-- main.lua with a startup context. Feature logic belongs in main.lua/modules.
local startup = getgenv and getgenv().AetherCoreStartup or {}
local rootUrl = startup.RootUrl or "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/"
local rootFolder = startup.RootFolder or "AetherCore"
local versionPath = rootFolder .. "/profiles/version.txt"
local remoteVersionPath = "profiles/version.txt"

local function hasFileSupport()
    return type(isfolder) == "function" and type(makefolder) == "function"
end

local function ensureFolder(path)
    if hasFileSupport() then
        local ok, exists = pcall(isfolder, path)
        if not ok or not exists then
            pcall(makefolder, path)
        end
    end
end

local folders = {
    rootFolder,
    rootFolder .. "/assets",
    rootFolder .. "/assets/new",
    rootFolder .. "/assets/old",
    rootFolder .. "/assets/rise",
    rootFolder .. "/assets/wurst",
    rootFolder .. "/assets/shared",
    rootFolder .. "/games",
    rootFolder .. "/guis",
    rootFolder .. "/libraries",
    rootFolder .. "/profiles",
    rootFolder .. "/profiles/premade"
}
for _, folder in ipairs(folders) do
    ensureFolder(folder)
end

local function read(path)
    if type(readfile) ~= "function" then return nil end
    local ok, result = pcall(readfile, path)
    if ok and type(result) == "string" and result ~= "" then
        return result
    end
    return nil
end

local function write(path, contents)
    if type(writefile) == "function" and type(contents) == "string" then
        pcall(writefile, path, contents)
    end
end

local function isMissingRemote(contents)
    if type(contents) ~= "string" then
        return true
    end
    local trimmed = contents:gsub("^%s+", ""):gsub("%s+$", "")
    return trimmed == ""
        or trimmed == "404: Not Found"
        or trimmed:find("^404", 1, false) ~= nil
end

local function fetchRemote(path)
    return game:HttpGet(rootUrl .. path, true)
end

local remoteVersion
pcall(function()
    remoteVersion = fetchRemote(remoteVersionPath)
end)
if type(remoteVersion) == "string" then
    remoteVersion = remoteVersion:gsub("^%s+", ""):gsub("%s+$", "")
    if isMissingRemote(remoteVersion) then
        remoteVersion = nil
    end
end
local localVersion = read(versionPath)
local shouldRefresh = remoteVersion and localVersion ~= remoteVersion

local cacheManifest = {
    "loader.lua",
    "loadstring",
    "init.lua",
    "main.lua",
    "NewMainScript.lua",
    "a.txt",
    "games/universal.luau",
    "games/6872265039.luau",
    "games/6872274481.luau",
    "guis/new.lua",
    "guis/old.lua",
    "guis/rise.lua",
    "guis/wurst.lua",
    "libraries/utility.lua",
    "libraries/storage.lua",
    "libraries/theme.lua",
    "libraries/signal.lua",
    "libraries/tween.lua",
    "libraries/entity.lua",
    "libraries/prediction.lua",
    "libraries/target.lua",
    "libraries/drawing.lua",
    "libraries/hash.lua",
    "libraries/vm.lua",
    "libraries/moduleassist.lua",
    "profiles/gui.txt",
    "profiles/default.txt",
    "profiles/supported.json",
    "profiles/version.txt",
    "custom_modules.luau"
}

local function fetch(path)
    local cachePath = rootFolder .. "/" .. path
    if not shouldRefresh then
        local cached = read(cachePath)
        if cached then return cached end
    end

    local ok, remote = pcall(fetchRemote, path)
    if ok and not isMissingRemote(remote) then
        write(cachePath, remote)
        return remote
    end

    local cached = read(cachePath)
    if cached then return cached end

    -- Legacy local fallback is intentionally last; AetherCore/<path> is the
    -- supported cache root.
    local legacy = read(path)
    if legacy then return legacy end

    error("[AetherCore] Unable to load " .. tostring(path) .. ": " .. tostring(remote))
end

if shouldRefresh then
    for _, path in ipairs(cacheManifest) do
        pcall(fetch, path)
    end
    if remoteVersion then
        write(versionPath, remoteVersion)
    end
end

local state = getgenv and getgenv().AetherCore or {}
state.Name = "AetherCore"
state.Version = (remoteVersion and remoteVersion:gsub("%s+", "")) or state.Version or "3.2.0"
state.RootUrl = rootUrl
state.RootFolder = rootFolder
state.CacheFolders = folders
state.LoaderStage = "main"
state.StartedAt = os.time()
if getgenv then
    getgenv().AetherCore = state
    getgenv().AetherCoreStartup = startup
end

local mainSource = fetch("main.lua")
local mainChunk, compileError = loadstring(mainSource, "AetherCore/main.lua")
if not mainChunk then
    error("[AetherCore] Failed to compile main.lua: " .. tostring(compileError))
end

local mainController = mainChunk()
if type(mainController) ~= "function" then
    error("[AetherCore] main.lua did not return the central controller function")
end

return mainController({
    RootUrl = rootUrl,
    RootFolder = rootFolder,
    Fetch = fetch,
    Version = state.Version,
    Startup = startup
})
