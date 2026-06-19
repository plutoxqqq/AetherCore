--!nocheck
-- AetherCore CatV6-style cache initializer.
local startup = getgenv and getgenv().AetherCoreStartup or {}
local rootUrl = startup.RootUrl or "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/"
local rootFolder = startup.RootFolder or "AetherCore"
local selectedGui = startup.SelectedGui or startup.Gui or "new"

local cloneref = cloneref or function(ref) return ref end
local coreGui = gethui and gethui() or cloneref(game:GetService("CoreGui"))
local isfile = isfile or function(file)
    local ok, result = pcall(function()
        return readfile(file)
    end)
    return ok and type(result) == "string" and result ~= ""
end

local downloader = Instance.new("TextLabel")
downloader.Size = UDim2.new(1, 0, 0, 40)
downloader.BackgroundTransparency = 1
downloader.TextStrokeTransparency = 0
downloader.TextSize = 20
downloader.TextColor3 = Color3.new(1, 1, 1)
downloader.Font = Enum.Font.Arial
downloader.Text = ""
downloader.Parent = Instance.new("ScreenGui", coreGui)

local function ensureFolder(path)
    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(path) then
        downloader.Text = "Preparing " .. path
        makefolder(path)
    end
end

for _, folder in ipairs({rootFolder, rootFolder .. "/games", rootFolder .. "/profiles", rootFolder .. "/assets", rootFolder .. "/libraries", rootFolder .. "/guis"}) do
    ensureFolder(folder)
end

local function missing(contents)
    if type(contents) ~= "string" then return true end
    local trimmed = contents:gsub("^%s+", ""):gsub("%s+$", "")
    return trimmed == "" or trimmed == "404: Not Found" or trimmed:find("^404", 1, false) ~= nil
end

local function downloadFile(path)
    local cachePath = rootFolder .. "/" .. path
    if not isfile(cachePath) then
        downloader.Text = "Downloading " .. path
        local ok, result = pcall(function()
            return game:HttpGet(rootUrl .. path, true)
        end)
        if not ok or missing(result) then
            error("[AetherCore] Unable to download " .. path .. ": " .. tostring(result))
        end
        if type(writefile) == "function" then
            writefile(cachePath, result)
        end
        downloader.Text = ""
    end
    return readfile(cachePath)
end

if type(writefile) == "function" and not isfile(rootFolder .. "/profiles/gui.txt") then
    writefile(rootFolder .. "/profiles/gui.txt", selectedGui)
end

startup.RootUrl = rootUrl
startup.RootFolder = rootFolder
startup.SelectedGui = selectedGui
if getgenv then
    getgenv().AetherCoreStartup = startup
end

downloader.Text = ""
local source = downloadFile("main.lua")
local chunk, compileError = loadstring(source, "AetherCore/main.lua")
if not chunk then
    error("[AetherCore] Failed to compile main.lua: " .. tostring(compileError))
end
local controller = chunk()
if type(controller) ~= "function" then
    error("[AetherCore] main.lua did not return a controller function")
end
return controller(startup)
