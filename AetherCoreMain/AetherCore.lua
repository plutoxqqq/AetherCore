-- AetherCore compatibility bootstrapper.
-- Existing public loadstrings can keep pointing here; this delegates to the
-- root loadstring, which then executes loader.lua and main.lua.
local ROOT_FOLDER = "AetherCore"
local ROOT_LOADSTRING = "loadstring"
local ROOT_LOADSTRING_URL = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/loadstring"

local function read(path)
    if type(readfile) ~= "function" then return nil end
    local ok, result = pcall(readfile, path)
    if ok and type(result) == "string" and result ~= "" then return result end
    return nil
end

local source = read(ROOT_FOLDER .. "/" .. ROOT_LOADSTRING) or read(ROOT_LOADSTRING)
if source == nil then
    source = game:HttpGet(ROOT_LOADSTRING_URL, true)
end
return loadstring(source, "AetherCore/loadstring")()
