-- AetherCore NewMainScript.lua
-- Compatibility entrypoint for users or tooling that expect a VapeV4-style name.
local rootUrl = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/"
local startup = getgenv and getgenv().AetherCoreStartup or {}
startup.RootUrl = startup.RootUrl or rootUrl
startup.RootFolder = startup.RootFolder or "AetherCore"
startup.EntryPoint = "NewMainScript.lua"
if getgenv then
    getgenv().AetherCoreStartup = startup
end

return loadstring(game:HttpGet(startup.RootUrl .. "loader.lua", true), "AetherCore/loader.lua")()
