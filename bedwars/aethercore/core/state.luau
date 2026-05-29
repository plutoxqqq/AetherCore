function initState()
    local State = Aether.State
    State.moduleStates = {}
    State.moduleConnections = {}
    State.moduleKeybinds = {}
    State.moduleUi = {}
    State.moduleHandlers = {}
    State.guiEnabled = true
    State.autoToxicEnabled = false
    State.originalCharacterValues = {}
    State.SETTINGS_STORE_KEY = "AetherCoreClientConfigV1"
    State.AUTO_TOXIC_CONNECTION_KEY = "AetherCoreAutoToxicMessageConnection"
    State.mouseMoveRelative = type(mousemoverel) == "function" and mousemoverel or nil
    State.clipboardSetter = type(setclipboard) == "function" and setclipboard or nil
    State.sharedEnvironmentGetter = type(getgenv) == "function" and getgenv or nil
    State.autoToxicMessageConnection = nil
    State.moduleConflictMap = {Speed = {}}
    State.warnedMissingObjects = {}
end

initState()
moduleRuntime = {}
