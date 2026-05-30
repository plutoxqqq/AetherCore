function initHelpers()
    local Helpers = Aether.Helpers

    function Helpers.logError(scope, err)
        warn(string.format("[AetherCore][%s] %s", tostring(scope), tostring(err)))
    end

    function Helpers.safeCall(scope, fn, ...)
        local args = table.pack(...)
        local ok, result = xpcall(function()
            return fn(table.unpack(args, 1, args.n))
        end, debug.traceback)
        if not ok then
            Helpers.logError(scope, result)
            return nil
        end
        return result
    end

    function Helpers.warnMissingOnce(key, message)
        if Aether.State.warnedMissingObjects[key] then
            return
        end
        Aether.State.warnedMissingObjects[key] = true
        warn(message)
    end

    function Helpers.getHandleInvItem(model)
        if not model then return nil end
        local handle = model:FindFirstChild("HandleInvItem")
        if not handle then
            Helpers.warnMissingOnce("HandleInvItem:" .. model:GetFullName(), "[AetherCore] HandleInvItem missing for: " .. model:GetFullName())
            return nil
        end
        return handle
    end

    function Helpers.getHumanoidScaleValue(humanoid, scaleName)
        if not humanoid then return nil end
        local scaleValue = humanoid:FindFirstChild(scaleName)
        if not scaleValue then
            Helpers.warnMissingOnce(scaleName .. ":" .. humanoid:GetFullName(), "[AetherCore] Missing humanoid scale '" .. scaleName .. "' for: " .. humanoid:GetFullName())
            return nil
        end
        return scaleValue
    end

    function Helpers.clampSetting(moduleName, settingName, value, min, max, fallback)
        local numeric = tonumber(value) or fallback
        local clamped = math.clamp(numeric or 0, min, max)
        local moduleSettings = Aether.Settings.moduleSettings
        moduleSettings[moduleName] = moduleSettings[moduleName] or {}
        moduleSettings[moduleName][settingName] = clamped
        return clamped
    end

    function Helpers.sayInChat(message)
        pcall(function()
            local chatService = Aether.Services.TextChatService
            local channel = chatService.ChatInputBarConfiguration.TargetTextChannel
            if channel then channel:SendAsync(message) end
        end)
    end
end

initHelpers()

Players = Aether.Services.Players
UserInputService = Aether.Services.UserInputService
TextChatService = Aether.Services.TextChatService
TweenService = Aether.Services.TweenService
HttpService = Aether.Services.HttpService
ReplicatedStorage = Aether.Services.ReplicatedStorage
RunService = Aether.Services.RunService
Workspace = Aether.Services.Workspace
Debris = Aether.Services.Debris
VirtualUser = Aether.Services.VirtualUser
CollectionService = Aether.Services.CollectionService
Lighting = Aether.Services.Lighting
StarterGui = Aether.Services.StarterGui

lplr = Aether.Services.LocalPlayer
mouse = Aether.Services.Mouse
camera = Aether.Services.Camera

moduleSettings = Aether.Settings.moduleSettings
moduleStates = Aether.State.moduleStates
moduleConnections = Aether.State.moduleConnections
moduleKeybinds = Aether.State.moduleKeybinds
moduleUi = Aether.State.moduleUi
moduleHandlers = Aether.State.moduleHandlers
guiEnabled = Aether.State.guiEnabled
autoToxicEnabled = Aether.State.autoToxicEnabled
originalCharacterValues = Aether.State.originalCharacterValues
SETTINGS_STORE_KEY = Aether.State.SETTINGS_STORE_KEY
AUTO_TOXIC_CONNECTION_KEY = Aether.State.AUTO_TOXIC_CONNECTION_KEY
mouseMoveRelative = Aether.State.mouseMoveRelative
clipboardSetter = Aether.State.clipboardSetter
sharedEnvironmentGetter = Aether.State.sharedEnvironmentGetter
autoToxicMessageConnection = Aether.State.autoToxicMessageConnection
moduleConflictMap = Aether.State.moduleConflictMap

logError = Aether.Helpers.logError
safeCall = Aether.Helpers.safeCall
warnMissingOnce = Aether.Helpers.warnMissingOnce
getHandleInvItem = Aether.Helpers.getHandleInvItem
getHumanoidScaleValue = Aether.Helpers.getHumanoidScaleValue
clampSetting = Aether.Helpers.clampSetting
sayInChat = Aether.Helpers.sayInChat
