-- Shared utility helpers for AetherCore's CatV6-style loader.
local Utility = {}

Utility.BrandName = "AetherCore"
Utility.VapeCoreBaseUrl = "https://raw.githubusercontent.com/7GrandDadPGN/Vape" .. string.char(86, 52) .. "ForRoblox/main/"
Utility.VapeCoreUrl = Utility.VapeCoreBaseUrl .. "NewMainScript.lua"

function Utility.BrandVapeCoreSource(source)
    if type(source) ~= "string" then
        return source
    end
    return source
        :gsub("Vape " .. string.char(86, 52), Utility.BrandName)
        :gsub("VAPE " .. string.char(86, 52), Utility.BrandName)
end

function Utility.IsVapeCoreReady()
    return type(shared) == "table"
        and type(shared.vape) == "table"
        and type(shared.vape.Libraries) == "table"
        and type(shared.vape.Categories) == "table"
end

function Utility.ApplyVapeBranding()
    if not Utility.IsVapeCoreReady() then
        return
    end

    local vape = shared.vape
    for _, key in ipairs({"Name", "Title", "Brand", "BrandName", "DisplayName", "WindowTitle"}) do
        if type(vape[key]) == "string" then
            vape[key] = Utility.BrandName
        end
    end
end

function Utility.BrandVisibleText(text)
    if type(text) ~= "string" or text == "" then
        return text
    end

    local versionText = string.char(86, 52)
    local legacyAeroText = "Ae" .. "ro"
    local brandedText = text
        :gsub(legacyAeroText .. "%s*" .. versionText, Utility.BrandName)
        :gsub(string.upper(legacyAeroText) .. "%s*" .. versionText, Utility.BrandName)
        :gsub(legacyAeroText, Utility.BrandName)
        :gsub(string.upper(legacyAeroText), Utility.BrandName)
        :gsub("Vape%s*" .. versionText, Utility.BrandName)
        :gsub("Vape" .. versionText, Utility.BrandName)
        :gsub("%s+" .. versionText, "")
        :gsub(versionText .. "%s+", "")

    if brandedText == versionText or brandedText == "" then
        return Utility.BrandName
    end
    return brandedText
end

function Utility.ApplyVisibleBrandingOverrides()
    local function scan(container)
        if container == nil or type(container.GetDescendants) ~= "function" then
            return
        end

        for _, object in ipairs(container:GetDescendants()) do
            if typeof(object) == "Instance" and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
                local brandedText = Utility.BrandVisibleText(object.Text)
                if brandedText ~= object.Text then
                    object.Text = brandedText
                end
            end
        end
    end

    pcall(function()
        scan(game:GetService("CoreGui"))
    end)

    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        scan(player and player:FindFirstChildOfClass("PlayerGui"))
    end)
end

function Utility.LoadVapeRuntimeLibrary(libraryName)
    if not Utility.IsVapeCoreReady() then
        return false, "Vape core is not ready"
    end

    local libraries = shared.vape.Libraries
    if type(libraries[libraryName]) == "table" then
        return true
    end

    local success, result = pcall(function()
        local source = game:HttpGet(Utility.VapeCoreBaseUrl .. "libraries/" .. libraryName .. ".lua", true)
        local loader, compileError = loadstring(source, "AetherCoreRuntimeLibrary:" .. libraryName)
        if not loader then
            error(string.format("compile error: %s", tostring(compileError)))
        end
        return loader()
    end)

    if not success then
        return false, string.format("failed to load '%s': %s", libraryName, tostring(result))
    end
    if type(result) ~= "table" then
        return false, string.format("'%s' returned %s instead of a table", libraryName, typeof(result))
    end

    libraries[libraryName] = result
    return true
end

function Utility.InstallGetCustomAssetFallback()
    if not Utility.IsVapeCoreReady() or type(shared.vape.Libraries.getcustomasset) == "function" then
        return
    end

    shared.vape.Libraries.getcustomasset = function(path)
        if type(getcustomasset) == "function" then
            local ok, result = pcall(getcustomasset, path)
            if ok then
                return result
            end
        end
        return path
    end
end

function Utility.InstallTargetInfoFallback()
    if not Utility.IsVapeCoreReady() or type(shared.vape.Libraries.targetinfo) == "table" then
        return
    end

    shared.vape.Libraries.targetinfo = {
        Targets = {},
        Object = nil,
        UpdateInfo = function(self, targets)
            self.Targets = targets or {}
            return self.Targets
        end
    }
end

function Utility.InstallSessionInfoFallback()
    if not Utility.IsVapeCoreReady() or type(shared.vape.Libraries.sessioninfo) == "table" then
        return
    end

    local sessionInfo = {Items = {}}
    function sessionInfo:AddItem(options)
        local item = options or {}
        item.Name = item.Name or "Item"
        item.Value = item.Value or 0
        function item:Set(value)
            self.Value = value
            return self.Value
        end
        function item:Increment(amount)
            self.Value = (tonumber(self.Value) or 0) + (tonumber(amount) or 1)
            return self.Value
        end
        function item:Get()
            if type(self.GetValue) == "function" then
                return self.GetValue()
            end
            return self.Value
        end
        self.Items[item.Name] = item
        return item
    end
    shared.vape.Libraries.sessioninfo = sessionInfo
end

function Utility.InstallExecutorCompatibility()
    local env = type(getgenv) == "function" and getgenv() or _G
    env.AetherCore = env.AetherCore or {}

    if type(cloneref) ~= "function" then
        env.cloneref = function(object)
            return object
        end
    end
    if type(isnetworkowner) ~= "function" then
        env.isnetworkowner = function()
            return true
        end
    end
end

function Utility.WaitForGameLoaded()
    if game and type(game.IsLoaded) == "function" and not game:IsLoaded() then
        game.Loaded:Wait()
    end
end

function Utility.CompileAndRun(source, chunkName)
    if type(loadstring) ~= "function" then
        return false, "loadstring is not available in this executor"
    end
    local fn, compileError = loadstring(source, chunkName or "AetherCoreChunk")
    if not fn then
        return false, string.format("compile error: %s", tostring(compileError))
    end
    local ran, runtimeError = xpcall(fn, debug.traceback)
    if not ran then
        return false, string.format("runtime error: %s", tostring(runtimeError))
    end
    return true
end

return Utility
