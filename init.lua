-- AetherCore init.lua
-- Sets startup arguments, prepares cache folders when available, and then loads main.lua.
local startup = getgenv and getgenv().AetherCoreStartup or {}
local rootUrl = startup.RootUrl or "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/"
local rootFolder = startup.RootFolder or "AetherCore"

local function executorHasFileSupport()
    return type(isfolder) == "function" and type(makefolder) == "function"
end

local function ensureFolder(path)
    if executorHasFileSupport() then
        local ok, exists = pcall(isfolder, path)
        if not ok or not exists then
            pcall(makefolder, path)
        end
    end
end

local cacheFolders = {
    rootFolder,
    rootFolder .. "/assets",
    rootFolder .. "/assets/new",
    rootFolder .. "/assets/old",
    rootFolder .. "/assets/rise",
    rootFolder .. "/assets/wurst",
    rootFolder .. "/games",
    rootFolder .. "/guis",
    rootFolder .. "/libraries",
    rootFolder .. "/profiles"
}
for _, folder in ipairs(cacheFolders) do
    ensureFolder(folder)
end

local state = getgenv and getgenv().AetherCore or {}
state.Name = "AetherCore"
state.Version = state.Version or "3.1.0"
state.RootUrl = rootUrl
state.RootFolder = rootFolder
state.CacheFolders = cacheFolders
state.StartedAt = os.time()
if getgenv then
    getgenv().AetherCore = state
    getgenv().AetherCoreStartup = startup
end

local function readLocal(path)
    if type(readfile) ~= "function" then
        return nil
    end
    local ok, result = pcall(readfile, path)
    if ok and type(result) == "string" and result ~= "" then
        return result
    end
    return nil
end

local function fetch(path)
    return readLocal(path) or game:HttpGet(rootUrl .. path, true)
end

local mainSource = fetch("main.lua")
local mainChunk, compileError = loadstring(mainSource, "AetherCore/main.lua")
if not mainChunk then
    error("[AetherCore] Failed to compile main.lua: " .. tostring(compileError))
end

-- main.lua returns the central controller function. Compile and execute the
-- chunk first, then call that returned function with the prepared startup data.
local mainController = mainChunk()
if type(mainController) ~= "function" then
    error("[AetherCore] main.lua did not return the central controller function")
end

state.LoaderStage = "main"
return mainController({
    RootUrl = rootUrl,
    RootFolder = rootFolder,
    Fetch = fetch,
    Version = state.Version,
    Startup = startup
})
