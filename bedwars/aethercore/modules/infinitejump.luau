function toggleInfiniteJump(enabled)
    cleanupModule("InfiniteJump")
    if not enabled then
        if lplr.Character then
            local hum = getHumanoid(lplr.Character)
            local original = originalCharacterValues["InfiniteJumpJumpPower"]
            if hum and original then
                hum.JumpPower = original
            elseif hum then
                hum.JumpPower = 50
            end
        end
        return
    end

    local function applyJump(char)
        local hum = getHumanoid(char)
        if hum then
            if not originalCharacterValues["InfiniteJumpJumpPower"] then
                originalCharacterValues["InfiniteJumpJumpPower"] = hum.JumpPower
            end
            hum.JumpPower = 0
        end
    end

    local connection = UserInputService.JumpRequest:Connect(function()
        if moduleStates["InfiniteJump"] and lplr.Character then
            local hum = getHumanoid(lplr.Character)
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)

    if lplr.Character then applyJump(lplr.Character) end
    addConnection("InfiniteJump", lplr.CharacterAdded:Connect(applyJump))
    addConnection("InfiniteJump", connection)
end





palette = {
    deep = Color3.fromRGB(15, 15, 15),
    panel = Color3.fromRGB(24, 24, 24),
    module = Color3.fromRGB(31, 31, 31),
    hover = Color3.fromRGB(42, 42, 42),
    active = Color3.fromRGB(51, 32, 74),
    accent = Color3.fromRGB(164, 94, 233),
    text = Color3.fromRGB(255, 255, 255),
    secondary = Color3.fromRGB(170, 170, 170),
    danger = Color3.fromRGB(180, 65, 65)
}

screenGui = Instance.new("ScreenGui")
screenGui.Name = "AetherCoreUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = lplr:WaitForChild("PlayerGui")

panelFrames = {}
moduleDefinitions = {}
categoryPanels = {}
categoryToggleButtons = {}
categoryManualVisibility = {}
categoryOrder = {"Combat", "Blatant", "Render", "Utility", "World", "Inventory", "Kits", "Minigames", "BoostFPS", "Legit"}
homeTabButton = nil
settingsTabButton = nil
scriptHubTabButton = nil
homeDashboardPanel = nil
settingsDashboardPanel = nil
scriptHubDashboardPanel = nil
activeSidebarTab = "Home"
keybindListening = false
searchText = ""
settingsOpenByModule = {}
loadedCategoryPositions = {}
loadedModuleStates = {}
saveClientSettings = nil

Aether.RegisterModule({
    Name = "InfiniteJump",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["InfiniteJump"] or {},
    Start = function(ctx)
        toggleInfiniteJump(true)
    end,
    Stop = function(ctx)
        toggleInfiniteJump(false)
    end
})
