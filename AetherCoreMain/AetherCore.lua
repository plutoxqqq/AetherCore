-- AetherCore compatibility bootstrapper.
-- Existing public loadstrings can keep pointing here; this now delegates to the
-- CatV6-style root loadstring, which then executes init.lua and main.lua.
local ROOT_LOADSTRING = "loadstring"
local ROOT_LOADSTRING_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/loadstring"

local source
if type(readfile) == "function" then
    local ok, result = pcall(readfile, ROOT_LOADSTRING)
    if ok and type(result) == "string" and result ~= "" then
        source = result
    end
end
if source == nil then
    source = game:HttpGet(ROOT_LOADSTRING_URL, true)
end
return loadstring(source, "AetherCore/loadstring")()
