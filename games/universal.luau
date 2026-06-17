-- Universal modules load before game-specific modules.
-- Keep this file limited to modules that only use Roblox-wide services and the
-- AetherCore runtime. BedWars-specific modules belong in the BedWars PlaceId files.
return function(context)
    local utility = context.Libraries.utility

    for _, libraryName in ipairs({"entity", "prediction"}) do
        local loaded, loadError = utility.LoadVapeRuntimeLibrary(libraryName)
        if not loaded then
            return false, loadError
        end
    end

    utility.InstallGetCustomAssetFallback()
    utility.InstallTargetInfoFallback()
    utility.InstallSessionInfoFallback()
    utility.InstallVapeLibraryFallbacks()

    local libraries = shared.vape.Libraries
    for _, libraryName in ipairs({"entity", "targetinfo", "sessioninfo", "prediction", "uipallet", "tween", "color", "getfontsize", "getcustomasset"}) do
        if libraries[libraryName] == nil then
            return false, string.format("missing '%s'", libraryName)
        end
    end

    local vape = shared and shared.vape
    if type(vape) ~= "table" or type(vape.Categories) ~= "table" then
        return false, "GUI categories are unavailable"
    end

    local category = vape.Categories.Utility or vape.Categories.Render
    if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
        return false, "universal module category is unavailable"
    end

    local universalState = context.UniversalModules or {}
    context.UniversalModules = universalState

    local function disconnectAll(connections)
        for _, connection in ipairs(connections) do
            if typeof(connection) == "RBXScriptConnection" then
                pcall(function()
                    connection:Disconnect()
                end)
            end
        end
        table.clear(connections)
    end

    local function getPlayerGui()
        local playersService = game:GetService("Players")
        local localPlayer = playersService.LocalPlayer
        if localPlayer == nil then
            return nil
        end
        return localPlayer:FindFirstChildOfClass("PlayerGui")
    end

    category:CreateModule({
        Name = "Aether Status",
        Tooltip = "Shows AetherCore runtime, place, and module registration information.",
        Function = function(enabled)
            if enabled then
                local playerGui = getPlayerGui()
                if playerGui == nil then
                    return
                end

                local existing = playerGui:FindFirstChild("AetherCoreStatus")
                if existing then
                    existing:Destroy()
                end

                local gui = Instance.new("ScreenGui")
                gui.Name = "AetherCoreStatus"
                gui.ResetOnSpawn = false
                gui.IgnoreGuiInset = true
                gui.Parent = playerGui

                local label = Instance.new("TextLabel")
                label.Name = "Status"
                label.AnchorPoint = Vector2.new(1, 0)
                label.Position = UDim2.new(1, -18, 0, 150)
                label.Size = UDim2.fromOffset(260, 104)
                label.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
                label.BackgroundTransparency = 0.22
                label.BorderSizePixel = 0
                label.Font = Enum.Font.GothamMedium
                label.TextColor3 = Color3.fromRGB(236, 243, 255)
                label.TextSize = 13
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextYAlignment = Enum.TextYAlignment.Top
                label.TextWrapped = true
                label.Text = string.format(
                    "AetherCore Ready\nPlaceId: %s\nGUI: %s\nRegistered modules: %s",
                    tostring(game.PlaceId),
                    tostring(context.SelectedGui or "unknown"),
                    tostring(context.State and context.State.ModuleRegistrationCount or 0)
                )
                label.Parent = gui

                local padding = Instance.new("UIPadding")
                padding.PaddingBottom = UDim.new(0, 8)
                padding.PaddingLeft = UDim.new(0, 10)
                padding.PaddingRight = UDim.new(0, 10)
                padding.PaddingTop = UDim.new(0, 8)
                padding.Parent = label

                universalState.StatusGui = gui
            elseif typeof(universalState.StatusGui) == "Instance" then
                universalState.StatusGui:Destroy()
                universalState.StatusGui = nil
            end
        end
    })

    category:CreateModule({
        Name = "Fullbright",
        Tooltip = "Improves client-side visibility by keeping lighting bright while enabled.",
        Function = function(enabled)
            local lighting = game:GetService("Lighting")
            local runService = game:GetService("RunService")
            universalState.FullbrightConnections = universalState.FullbrightConnections or {}

            if enabled then
                universalState.FullbrightOriginal = universalState.FullbrightOriginal or {
                    Brightness = lighting.Brightness,
                    ClockTime = lighting.ClockTime,
                    FogEnd = lighting.FogEnd,
                    GlobalShadows = lighting.GlobalShadows
                }

                local function applyLighting()
                    lighting.Brightness = 2
                    lighting.ClockTime = 14
                    lighting.FogEnd = 100000
                    lighting.GlobalShadows = false
                end

                applyLighting()
                table.insert(universalState.FullbrightConnections, runService.RenderStepped:Connect(applyLighting))
            else
                disconnectAll(universalState.FullbrightConnections or {})
                local original = universalState.FullbrightOriginal
                if type(original) == "table" then
                    lighting.Brightness = original.Brightness
                    lighting.ClockTime = original.ClockTime
                    lighting.FogEnd = original.FogEnd
                    lighting.GlobalShadows = original.GlobalShadows
                end
                universalState.FullbrightOriginal = nil
            end
        end
    })

    return true
end
