-- Shared utility helpers for AetherCore's CatV6-style loader.
local Utility = {}

Utility.BrandName = "AetherCore"
Utility.RuntimeContext = nil
Utility.BrandTextAsset = "assets/new/aethercore_text.png"
Utility.VapeCoreBaseUrl = "https://raw.githubusercontent.com/7GrandDadPGN/Vape" .. string.char(86, 52) .. "ForRoblox/main/"
Utility.VapeCoreUrl = Utility.VapeCoreBaseUrl .. "NewMainScript.lua"

function Utility.SetRuntimeContext(context)
    if type(context) == "table" then
        Utility.RuntimeContext = context
    end
end

function Utility.GetRuntimeAssetPath(relativePath)
    local context = Utility.RuntimeContext or {}
    local rootFolder = type(context.RootFolder) == "string" and context.RootFolder ~= "" and context.RootFolder or "AetherCore"
    local cachePath = rootFolder .. "/" .. relativePath

    if type(readfile) == "function" then
        local readOk, contents = pcall(readfile, cachePath)
        if readOk and type(contents) == "string" and contents ~= "" then
            return cachePath
        end
    end

    if type(writefile) == "function" and game ~= nil and type(game.HttpGet) == "function" then
        local rootUrl = type(context.RootUrl) == "string" and context.RootUrl ~= "" and context.RootUrl or nil
        if rootUrl then
            local fetchOk, contents = pcall(function()
                return game:HttpGet(rootUrl .. relativePath, true)
            end)
            if fetchOk and type(contents) == "string" and contents ~= "" then
                pcall(writefile, cachePath, contents)
                return cachePath
            end
        end
    end

    return cachePath
end

function Utility.GetCustomAssetPath(relativePath)
    local runtimePath = Utility.GetRuntimeAssetPath(relativePath)
    if type(getcustomasset) == "function" then
        local ok, asset = pcall(getcustomasset, runtimePath)
        if ok and type(asset) == "string" and asset ~= "" then
            return asset
        end
    end
    return runtimePath
end

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

function Utility.IsLegacyLogoText(text)
    if type(text) ~= "string" then
        return false
    end

    local normalizedText = text:gsub("%s+", "")
    local versionText = string.char(86, 52)
    return normalizedText == "AERO"
        or normalizedText == "Ae" .. "ro"
        or normalizedText == "AERO" .. versionText
        or normalizedText == "Ae" .. "ro" .. versionText
end

function Utility.ApplyBrandLogoImage(textObject)
    if typeof(textObject) ~= "Instance" then
        return
    end

    local logo = textObject:FindFirstChild("AetherCoreTextLogo")
    if logo == nil then
        logo = Instance.new("ImageLabel")
        logo.Name = "AetherCoreTextLogo"
        logo.BackgroundTransparency = 1
        logo.BorderSizePixel = 0
        logo.AnchorPoint = Vector2.new(0.5, 0.5)
        logo.Position = UDim2.fromScale(0.5, 0.5)
        logo.Size = UDim2.fromScale(1, 1)
        logo.Parent = textObject
    end

    logo.Image = Utility.GetCustomAssetPath(Utility.BrandTextAsset)
    logo.ScaleType = Enum.ScaleType.Fit
    logo.ZIndex = textObject.ZIndex + 1
    textObject.TextTransparency = 1
end

function Utility.ApplyVisibleBrandingOverrides()
    local function patchObject(object)
        if typeof(object) ~= "Instance" or not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
            return
        end

        if Utility.IsLegacyLogoText(object.Text) then
            Utility.ApplyBrandLogoImage(object)
            return
        end

        local brandedText = Utility.BrandVisibleText(object.Text)
        if brandedText ~= object.Text then
            object.Text = brandedText
        end
    end

    local function watchTextObject(object)
        if typeof(object) ~= "Instance" or not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
            return
        end
        if object:GetAttribute("AetherCoreBrandWatcher") then
            return
        end

        object:SetAttribute("AetherCoreBrandWatcher", true)
        pcall(function()
            object:GetPropertyChangedSignal("Text"):Connect(function()
                patchObject(object)
            end)
        end)
    end

    local function scan(container)
        if typeof(container) ~= "Instance" then
            return
        end

        patchObject(container)
        watchTextObject(container)
        for _, object in ipairs(container:GetDescendants()) do
            patchObject(object)
            watchTextObject(object)
        end

        if not container:GetAttribute("AetherCoreBrandDescendantWatcher") then
            container:SetAttribute("AetherCoreBrandDescendantWatcher", true)
            container.DescendantAdded:Connect(function(object)
                patchObject(object)
                watchTextObject(object)
            end)
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


function Utility.InstallCategoryFallbacks()
    if not Utility.IsVapeCoreReady() then
        return
    end

    local categories = shared.vape.Categories
    local fallbackCategory = nil
    for _, category in pairs(categories) do
        if type(category) == "table" and type(category.CreateModule) == "function" then
            fallbackCategory = category
            break
        end
    end
    if not fallbackCategory then
        return
    end

    local aliases = {
        BoostFPS = "Render",
        Friends = "Utility",
        Inventory = "Utility",
        Kits = "Utility",
        Legit = "Utility",
        Minigames = "World",
        Other = "Utility",
        Profiles = "Utility",
        Search = "Utility"
    }

    for missingName, preferredName in pairs(aliases) do
        if type(categories[missingName]) ~= "table" or type(categories[missingName].CreateModule) ~= "function" then
            local preferredCategory = categories[preferredName]
            if type(preferredCategory) == "table" and type(preferredCategory.CreateModule) == "function" then
                categories[missingName] = preferredCategory
            else
                categories[missingName] = fallbackCategory
            end
        end
    end

    local currentMetatable = getmetatable(categories)
    if type(currentMetatable) ~= "table" then
        currentMetatable = {}
        setmetatable(categories, currentMetatable)
    end
    if currentMetatable.__AetherCoreCategoryFallback ~= true then
        local previousIndex = currentMetatable.__index
        currentMetatable.__AetherCoreCategoryFallback = true
        currentMetatable.__index = function(tableValue, key)
            local previousValue
            if type(previousIndex) == "function" then
                previousValue = previousIndex(tableValue, key)
            elseif type(previousIndex) == "table" then
                previousValue = previousIndex[key]
            end
            if previousValue ~= nil then
                return previousValue
            end
            rawset(tableValue, key, fallbackCategory)
            return fallbackCategory
        end
    end
end

function Utility.EnsureHumanoidScaleValues(character)
    if typeof(character) ~= "Instance" then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:FindFirstChild("Humanoid")
    if typeof(humanoid) ~= "Instance" then
        return
    end

    local defaults = {
        BodyDepthScale = 1,
        BodyHeightScale = 1,
        BodyProportionScale = 0,
        BodyTypeScale = 0,
        BodyWidthScale = 1,
        HeadScale = 1
    }

    for scaleName, defaultValue in pairs(defaults) do
        if humanoid:FindFirstChild(scaleName) == nil then
            pcall(function()
                local scaleValue = Instance.new("NumberValue")
                scaleValue.Name = scaleName
                scaleValue.Value = defaultValue
                scaleValue.Parent = humanoid
            end)
        end
    end
end

function Utility.InstallHumanoidScaleFallbacks()
    local players = game and game:GetService("Players")
    if not players then
        return
    end

    local function watchPlayer(player)
        if typeof(player) ~= "Instance" then
            return
        end

        if player.Character then
            Utility.EnsureHumanoidScaleValues(player.Character)
        end
        pcall(function()
            player.CharacterAdded:Connect(function(character)
                Utility.EnsureHumanoidScaleValues(character)
                if type(task) == "table" and type(task.defer) == "function" then
                    task.defer(Utility.EnsureHumanoidScaleValues, character)
                end
            end)
        end)
    end

    for _, player in ipairs(players:GetPlayers()) do
        watchPlayer(player)
    end
    pcall(function()
        players.PlayerAdded:Connect(watchPlayer)
    end)
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
