-- AetherCore loader.lua
-- Minimal bootstrap: fetch and execute the main controller only.
local rootUrl = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/"
local rootFolder = "AetherCore"

local startup = getgenv and getgenv().AetherCoreStartup or {}
startup.RootUrl = startup.RootUrl or rootUrl
startup.RootFolder = startup.RootFolder or rootFolder
if getgenv then
    getgenv().AetherCoreStartup = startup
end

local function isMissingSource(contents)
    if type(contents) ~= "string" then
        return true
    end
    local trimmed = contents:gsub("^%s+", ""):gsub("%s+$", "")
    return trimmed == "" or trimmed == "404: Not Found" or trimmed:find("^404", 1, false) ~= nil
end

local function read(path)
    if type(readfile) ~= "function" then
        return nil
    end

    local ok, result = pcall(readfile, path)
    if ok and not isMissingSource(result) then
        return result
    end
    return nil
end

local source = read(rootFolder .. "/main.lua") or read("main.lua")
if source == nil then
    source = game:HttpGet(startup.RootUrl .. "main.lua", true)
end
if isMissingSource(source) then
    error("[AetherCore] Unable to load a valid main.lua source")
end

local chunk, compileError = loadstring(source, "AetherCore/main.lua")
if not chunk then
    error("[AetherCore] Failed to compile main.lua: " .. tostring(compileError))
end

local controller = chunk()
if type(controller) == "function" then
    return controller(startup)
end
return controller
