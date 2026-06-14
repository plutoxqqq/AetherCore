-- Shared utility helpers for AetherCore's VapeV4-style loader.
local Utility = {}

Utility.BrandName = "AetherCore"
Utility.RuntimeContext = nil
Utility.BrandTextAsset = nil -- Binary branding assets are intentionally not tracked in Git.
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

    local versionText = string.char(86, 52)
    local brandedSource = source
        :gsub("Vape " .. versionText, Utility.BrandName)
        :gsub("VAPE " .. versionText, Utility.BrandName)

    if type(Utility.BrandTextAsset) == "string" and Utility.BrandTextAsset ~= "" then
        brandedSource = brandedSource
            :gsub("newvape/assets/new/vape%.png", Utility.BrandTextAsset)
            :gsub("newvape/assets/new/logo%.png", Utility.BrandTextAsset)
            :gsub("newvape/assets/new/vapelogo%.png", Utility.BrandTextAsset)
            :gsub("newvape/assets/new/VapeLogo%.png", Utility.BrandTextAsset)
    end

    local categoryInsertions = {
        "'Combat', 'Blatant', 'Render', 'Utility', 'World', 'Inventory', 'Minigames'",
        "'Combat','Blatant','Render','Utility','World','Inventory','Minigames'",
        '"Combat", "Blatant", "Render", "Utility", "World", "Inventory", "Minigames"',
        '"Combat","Blatant","Render","Utility","World","Inventory","Minigames"'
    }
    for _, categoryList in ipairs(categoryInsertions) do
        local quote = categoryList:sub(1, 1)
        local extendedList = categoryList .. ", " .. quote .. "Kits" .. quote .. ", " .. quote .. "Legit" .. quote .. ", " .. quote .. "BoostFPS" .. quote .. ", " .. quote .. "VibeCoded" .. quote .. ", " .. quote .. "Module Assist" .. quote
        brandedSource = brandedSource:gsub(categoryList, extendedList)
    end

    local vibeCategoryInsertions = {
        "'Kits', 'Legit', 'BoostFPS'",
        "'Kits','Legit','BoostFPS'",
        '"Kits", "Legit", "BoostFPS"',
        '"Kits","Legit","BoostFPS"'
    }
    for _, categoryList in ipairs(vibeCategoryInsertions) do
        local quote = categoryList:sub(1, 1)
        if not brandedSource:find(quote .. "VibeCoded" .. quote, 1, true) then
            brandedSource = brandedSource:gsub(categoryList, categoryList .. ", " .. quote .. "VibeCoded" .. quote)
        end
        if not brandedSource:find(quote .. "Module Assist" .. quote, 1, true) then
            brandedSource = brandedSource:gsub(categoryList, categoryList .. ", " .. quote .. "Module Assist" .. quote)
        end
    end

    return brandedSource
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
        :gsub("VAPE%s*" .. versionText, Utility.BrandName)
        :gsub("Vape" .. versionText, Utility.BrandName)
        :gsub("VAPE" .. versionText, Utility.BrandName)
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
        or normalizedText == "VAPE"
        or normalizedText == "Vape"
        or normalizedText == "VAPE" .. versionText
        or normalizedText == "Vape" .. versionText
end

function Utility.ApplyBrandLogoImage(textObject)
    if typeof(textObject) ~= "Instance" then
        return
    end

    local logo = textObject:FindFirstChild("AetherCoreTextLogo")
    if type(Utility.BrandTextAsset) ~= "string" or Utility.BrandTextAsset == "" then
        if logo then
            logo.Visible = false
        end
        textObject.Text = Utility.BrandName
        textObject.TextTransparency = 0
        return
    end

    if logo == nil then
        logo = Instance.new("ImageLabel")
        logo.Name = "AetherCoreTextLogo"
        logo.BackgroundTransparency = 1
        logo.BorderSizePixel = 0
        logo.Parent = textObject
    end

    logo.AnchorPoint = Vector2.new(0, 0.5)
    logo.Position = UDim2.new(0, 0, 0.5, 0)
    logo.Size = UDim2.fromOffset(108, 36)
    logo.Image = Utility.GetCustomAssetPath(Utility.BrandTextAsset)
    logo.ImageTransparency = 0
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Visible = true
    logo.ZIndex = textObject.ZIndex + 1
    textObject.Text = ""
    textObject.TextTransparency = 1
end

function Utility.ApplyVisibleBrandingOverrides()
    local function patchImageObject(object)
        if typeof(object) ~= "Instance" or not (object:IsA("ImageLabel") or object:IsA("ImageButton")) then
            return
        end

        local imageText = type(object.Image) == "string" and object.Image:lower() or ""
        local nameText = type(object.Name) == "string" and object.Name:lower() or ""
        local looksLikeVapeLogo = (nameText:find("logo", 1, true) ~= nil or imageText:find("logo", 1, true) ~= nil or imageText:find("vape", 1, true) ~= nil)
            and imageText:find("aethercore", 1, true) == nil
        if not looksLikeVapeLogo then
            return
        end

        if type(Utility.BrandTextAsset) ~= "string" or Utility.BrandTextAsset == "" then
            object.Visible = false
            return
        end

        object.Image = Utility.GetCustomAssetPath(Utility.BrandTextAsset)
        object.ScaleType = Enum.ScaleType.Fit
        object.BackgroundTransparency = 1
        object.ImageTransparency = 0
        if object.AbsoluteSize.X > 0 and object.AbsoluteSize.X < 96 then
            object.Size = UDim2.fromOffset(108, math.max(28, object.AbsoluteSize.Y))
        end
    end

    local function patchObject(object)
        if typeof(object) ~= "Instance" then
            return
        end

        patchImageObject(object)
        if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
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

    local function watchBrandedObject(object)
        if typeof(object) ~= "Instance" then
            return
        end
        if object:GetAttribute("AetherCoreBrandWatcher") then
            return
        end

        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            object:SetAttribute("AetherCoreBrandWatcher", true)
            pcall(function()
                object:GetPropertyChangedSignal("Text"):Connect(function()
                    patchObject(object)
                end)
            end)
            return
        end

        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            object:SetAttribute("AetherCoreBrandWatcher", true)
            pcall(function()
                object:GetPropertyChangedSignal("Image"):Connect(function()
                    patchObject(object)
                end)
            end)
        end
    end

    local function scan(container)
        if typeof(container) ~= "Instance" then
            return
        end

        patchObject(container)
        watchBrandedObject(container)
        for _, object in ipairs(container:GetDescendants()) do
            patchObject(object)
            watchBrandedObject(object)
        end

        if not container:GetAttribute("AetherCoreBrandDescendantWatcher") then
            container:SetAttribute("AetherCoreBrandDescendantWatcher", true)
            container.DescendantAdded:Connect(function(object)
                patchObject(object)
                watchBrandedObject(object)
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
        return false, "GUI core is not ready"
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


function Utility.InstallVapeLibraryFallbacks()
    if not Utility.IsVapeCoreReady() then
        return
    end

    local libraries = shared.vape.Libraries

    if type(libraries.getfontsize) ~= "function" then
        libraries.getfontsize = function(text, size, font, bounds)
            local textService = game:GetService("TextService")
            local success, result = pcall(function()
                return textService:GetTextSize(tostring(text or ""), tonumber(size) or 14, Enum.Font.SourceSans, bounds or Vector2.new(100000, 100000))
            end)
            if success then
                return result
            end
            return Vector2.new(#tostring(text or "") * ((tonumber(size) or 14) * 0.5), tonumber(size) or 14)
        end
    end

    if type(libraries.color) ~= "table" then
        local function clampChannel(value)
            return math.clamp(value, 0, 1)
        end
        libraries.color = {
            Dark = function(colorValue, amount)
                amount = tonumber(amount) or 0
                return Color3.new(
                    clampChannel(colorValue.R - amount),
                    clampChannel(colorValue.G - amount),
                    clampChannel(colorValue.B - amount)
                )
            end,
            Light = function(colorValue, amount)
                amount = tonumber(amount) or 0
                return Color3.new(
                    clampChannel(colorValue.R + amount),
                    clampChannel(colorValue.G + amount),
                    clampChannel(colorValue.B + amount)
                )
            end
        }
    end

    if type(libraries.uipallet) ~= "table" then
        libraries.uipallet = {
            Main = Color3.fromRGB(18, 18, 22),
            Text = Color3.fromRGB(220, 220, 225),
            Accent = Color3.fromRGB(0, 170, 140),
            Font = Font.fromEnum(Enum.Font.SourceSans)
        }
    end

    if type(libraries.tween) ~= "table" then
        libraries.tween = {
            Tween = function(instance, tweenInfo, properties)
                local tween = game:GetService("TweenService"):Create(instance, tweenInfo, properties)
                tween:Play()
                return tween
            end,
            Create = function(instance, tweenInfo, properties)
                return game:GetService("TweenService"):Create(instance, tweenInfo, properties)
            end
        }
    end
end


function Utility.InstallCategoryFallbacks()
    if not Utility.IsVapeCoreReady() then
        return
    end

    local categories = shared.vape.Categories
    local vape = shared.vape

    local function getAsset(path)
        local assetLoader = type(vape.Libraries) == "table" and vape.Libraries.getcustomasset or nil
        if type(assetLoader) == "function" then
            local ok, asset = pcall(assetLoader, path)
            if ok and type(asset) == "string" and asset ~= "" then
                return asset
            end
        end
        if type(getcustomasset) == "function" then
            local ok, asset = pcall(getcustomasset, path)
            if ok and type(asset) == "string" and asset ~= "" then
                return asset
            end
        end
        return path
    end

    local function createWindowCategory(name, iconPath, size)
        if type(categories[name]) == "table" and type(categories[name].CreateModule) == "function" then
            return categories[name]
        end
        if type(vape.CreateCategory) ~= "function" then
            return nil
        end

        local ok, category = pcall(function()
            return vape:CreateCategory({
                Name = name,
                Icon = getAsset(iconPath or "newvape/assets/new/utilityicon.png"),
                Size = size or UDim2.fromOffset(15, 14)
            })
        end)
        if ok and type(category) == "table" then
            categories[name] = category
            return category
        end
        return nil
    end

    local function createListCategory(name, iconPath, size, options)
        if type(categories[name]) == "table" and type(categories[name].CreateModule) == "function" then
            return categories[name]
        end
        if type(vape.CreateCategoryList) ~= "function" then
            return nil
        end

        options = options or {}
        options.Name = name
        options.Icon = getAsset(iconPath or "newvape/assets/new/friendstab.png")
        options.Size = size or UDim2.fromOffset(17, 16)
        local ok, category = pcall(function()
            return vape:CreateCategoryList(options)
        end)
        if ok and type(category) == "table" then
            categories[name] = category
            return category
        end
        return nil
    end

    createWindowCategory("Inventory", "newvape/assets/new/inventoryicon.png", UDim2.fromOffset(15, 14))
    createWindowCategory("Minigames", "newvape/assets/new/miniicon.png", UDim2.fromOffset(19, 12))
    createWindowCategory("Kits", "newvape/assets/new/utilityicon.png", UDim2.fromOffset(15, 14))
    createWindowCategory("Legit", "newvape/assets/new/legittab.png", UDim2.fromOffset(16, 16))
    createWindowCategory("BoostFPS", "newvape/assets/new/rendericon.png", UDim2.fromOffset(15, 14))
    createWindowCategory("VibeCoded", "newvape/assets/new/utilityicon.png", UDim2.fromOffset(15, 14))
    local moduleAssistCategory = createWindowCategory("Module Assist", "newvape/assets/new/utilityicon.png", UDim2.fromOffset(15, 14))
    if moduleAssistCategory then
        categories.ModuleAssist = moduleAssistCategory
    end

    createListCategory("Friends", "newvape/assets/new/friendstab.png", UDim2.fromOffset(17, 16), {
        Placeholder = "Roblox username",
        Color = Color3.fromRGB(5, 134, 105)
    })
    createListCategory("Profiles", "newvape/assets/new/profilesicon.png", UDim2.fromOffset(17, 10), {
        Position = UDim2.fromOffset(12, 16),
        Placeholder = "Type name",
        Profiles = true
    })
    createListCategory("Targets", "newvape/assets/new/friendstab.png", UDim2.fromOffset(17, 16), {
        Placeholder = "Roblox username"
    })

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

    local function delegateCreateModule(category)
        if type(category) == "table" and type(category.CreateModule) ~= "function" then
            category.CreateModule = function(_, moduleOptions, ...)
                return fallbackCategory:CreateModule(moduleOptions, ...)
            end
        end
    end

    delegateCreateModule(categories.Friends)
    delegateCreateModule(categories.Profiles)
    delegateCreateModule(categories.Targets)

    if type(categories.Friends) ~= "table" then
        categories.Friends = {
            ListEnabled = {},
            Options = {
                ["Use friends"] = {Enabled = false},
                ["Recolor visuals"] = {Enabled = true}
            },
            CreateModule = function(_, moduleOptions, ...)
                return fallbackCategory:CreateModule(moduleOptions, ...)
            end
        }
    end
    categories.Friends.ListEnabled = categories.Friends.ListEnabled or {}
    categories.Friends.Options = categories.Friends.Options or {}
    categories.Friends.Options["Use friends"] = categories.Friends.Options["Use friends"] or {Enabled = false}
    categories.Friends.Options["Recolor visuals"] = categories.Friends.Options["Recolor visuals"] or {Enabled = true}

    if type(categories.Targets) ~= "table" then
        categories.Targets = {
            ListEnabled = {},
            Options = {},
            CreateModule = function(_, moduleOptions, ...)
                return fallbackCategory:CreateModule(moduleOptions, ...)
            end
        }
    end
    categories.Targets.ListEnabled = categories.Targets.ListEnabled or {}
    categories.Targets.Options = categories.Targets.Options or {}

    local aliases = {
        BoostFPS = "Render",
        Inventory = "Utility",
        Kits = "Utility",
        Legit = "Utility",
        Minigames = "World",
        Other = "Utility",
        Profiles = "Utility",
        Search = "Utility",
        VibeCoded = "Utility",
        ModuleAssist = "Utility",
        ["Module Assist"] = "Utility"
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

    for categoryName, category in pairs(categories) do
        if type(category) == "table" and type(category.CreateModule) == "function" and shared.vape[categoryName] == nil then
            shared.vape[categoryName] = category
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
