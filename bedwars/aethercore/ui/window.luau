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


-- moduleHandlers are registered by module files.

function addCorner(target, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = target
end

function stylePanel(panel)
    panel.BackgroundColor3 = palette.panel
    panel.BorderSizePixel = 0
    addCorner(panel, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 36)
    stroke.Thickness = 1
    stroke.Transparency = 0.2
    stroke.Parent = panel
end

function styleDashboardCard(card)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    card.BorderSizePixel = 0
    addCorner(card, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(82, 58, 122)
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = card
end

function createDashboardSectionTitle(parent, text)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 0, 24)
    title.Position = UDim2.new(0, 12, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 17
    title.TextColor3 = palette.text
    title.Parent = parent
    return title
end

function createPanel(name, size, position)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = size
    panel.Position = position
    panel.Parent = screenGui
    stylePanel(panel)
    panelFrames[name] = panel
    return panel
end

function makeDraggable(frame, dragBar)
    local dragging = false
    local dragStart
    local startPos

    dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    dragBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            local cameraInstance = Workspace.CurrentCamera
            if cameraInstance then
                local viewport = cameraInstance.ViewportSize
                local maxX = math.max(10, viewport.X - frame.AbsoluteSize.X - 10)
                local maxY = math.max(10, viewport.Y - frame.AbsoluteSize.Y - 10)
                local clampedX = math.clamp(frame.Position.X.Offset, 10, maxX)
                local clampedY = math.clamp(frame.Position.Y.Offset, 10, maxY)
                frame.Position = UDim2.new(0, clampedX, 0, clampedY)
            end
            if saveClientSettings then
                saveClientSettings()
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

mainPanel = createPanel("MainPanel", UDim2.new(0, 190, 0, 430), UDim2.new(0, 80, 0, 120))
topBar = createPanel("TopBar", UDim2.new(0, 350, 0, 40), UDim2.new(0, 285, 0, 120))
statusPanel = createPanel("StatusPanel", UDim2.new(0, 265, 0, 24), UDim2.new(0, 80, 0, 560))

mainTop = Instance.new("Frame")
mainTop.Size = UDim2.new(1, 0, 0, 40)
mainTop.BackgroundColor3 = palette.deep
mainTop.BorderSizePixel = 0
mainTop.Parent = mainPanel
addCorner(mainTop, 8)

mainTitle = Instance.new("TextLabel")
mainTitle.Size = UDim2.new(1, -16, 1, 0)
mainTitle.Position = UDim2.new(0, 12, 0, 0)
mainTitle.BackgroundTransparency = 1
mainTitle.Text = "AetherCore"
mainTitle.TextXAlignment = Enum.TextXAlignment.Left
mainTitle.Font = Enum.Font.GothamBold
mainTitle.TextSize = 18
mainTitle.TextColor3 = palette.accent
mainTitle.Parent = mainTop

mainList = Instance.new("ScrollingFrame")
mainList.Size = UDim2.new(1, -10, 1, -50)
mainList.Position = UDim2.new(0, 5, 0, 45)
mainList.BackgroundTransparency = 1
mainList.BorderSizePixel = 0
mainList.CanvasSize = UDim2.new(0, 0, 0, 0)
mainList.AutomaticCanvasSize = Enum.AutomaticSize.Y
mainList.ScrollBarThickness = 3
mainList.Parent = mainPanel

mainListLayout = Instance.new("UIListLayout")
mainListLayout.Padding = UDim.new(0, 6)
mainListLayout.Parent = mainList

dashboardContent = Instance.new("Frame")
dashboardContent.Name = "DashboardContent"
dashboardContent.Size = UDim2.new(1, -295, 1, -170)
dashboardContent.Position = UDim2.new(0, 285, 0, 120)
dashboardContent.BackgroundTransparency = 1
dashboardContent.Parent = screenGui

function createDashboardBase(name)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundColor3 = Color3.fromRGB(11, 11, 20)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = dashboardContent
    addCorner(panel, 12)

    local panelGradient = Instance.new("UIGradient")
    panelGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 13, 24)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 15, 42))
    })
    panelGradient.Rotation = 180
    panelGradient.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(67, 48, 103)
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = panel

    return panel
end

homeDashboardPanel = createDashboardBase("HomeDashboard")
settingsDashboardPanel = createDashboardBase("SettingsDashboard")
scriptHubDashboardPanel = createDashboardBase("ScriptHubDashboard")

function setupHomeDashboardPanel()
    local welcomeCard = Instance.new("Frame")
    welcomeCard.Size = UDim2.new(1, -20, 0, 84)
    welcomeCard.Position = UDim2.new(0, 10, 0, 12)
    welcomeCard.Parent = homeDashboardPanel
    styleDashboardCard(welcomeCard)

    local welcomeTitle = Instance.new("TextLabel")
    welcomeTitle.Size = UDim2.new(1, -30, 0, 33)
    welcomeTitle.Position = UDim2.new(0, 15, 0, 12)
    welcomeTitle.BackgroundTransparency = 1
    welcomeTitle.Text = "Welcome back, Player!"
    welcomeTitle.TextXAlignment = Enum.TextXAlignment.Left
    welcomeTitle.TextColor3 = palette.text
    welcomeTitle.Font = Enum.Font.GothamBold
    welcomeTitle.TextSize = 30
    welcomeTitle.Parent = welcomeCard

    local welcomeSubtitle = Instance.new("TextLabel")
    welcomeSubtitle.Size = UDim2.new(1, -30, 0, 24)
    welcomeSubtitle.Position = UDim2.new(0, 15, 0, 47)
    welcomeSubtitle.BackgroundTransparency = 1
    welcomeSubtitle.Text = "AetherCore – Advanced BedWars Client"
    welcomeSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    welcomeSubtitle.TextColor3 = palette.secondary
    welcomeSubtitle.Font = Enum.Font.Gotham
    welcomeSubtitle.TextSize = 16
    welcomeSubtitle.Parent = welcomeCard

    local playerInfoCard = Instance.new("Frame")
    playerInfoCard.Size = UDim2.new(0.5, -16, 0, 222)
    playerInfoCard.Position = UDim2.new(0, 10, 0, 106)
    playerInfoCard.Parent = homeDashboardPanel
    styleDashboardCard(playerInfoCard)
    createDashboardSectionTitle(playerInfoCard, "Player Info")

    local playerInfoLines = {
        "Username: " .. lplr.Name,
        "User ID: " .. tostring(lplr.UserId),
        "Ping: Measuring...",
        "FPS: Measuring...",
        "Server: BedWars (Lobby)"
    }

    for index, text in ipairs(playerInfoLines) do
        local line = Instance.new("TextLabel")
        line.Size = UDim2.new(1, -24, 0, 25)
        line.Position = UDim2.new(0, 12, 0, 38 + ((index - 1) * 32))
        line.BackgroundTransparency = 1
        line.Text = text
        line.TextXAlignment = Enum.TextXAlignment.Left
        line.Font = Enum.Font.Gotham
        line.TextSize = 15
        line.TextColor3 = Color3.fromRGB(215, 215, 215)
        line.Parent = playerInfoCard

        if text:find("Ping:") == 1 then
            RunService.Heartbeat:Connect(function()
                if line.Parent then
                    local ping = math.floor(Players.LocalPlayer:GetNetworkPing() * 1000)
                    line.Text = ("Ping: %dms"):format(ping)
                end
            end)
        elseif text:find("FPS:") == 1 then
            local rollingDt = 1 / 60
            RunService.RenderStepped:Connect(function(dt)
                rollingDt = (rollingDt * 0.92) + (dt * 0.08)
                if line.Parent then
                    line.Text = ("FPS: %d"):format(math.clamp(math.floor(1 / math.max(rollingDt, 0.0001) + 0.5), 1, 999))
                end
            end)
        end
    end

    local quickActionsCard = Instance.new("Frame")
    quickActionsCard.Size = UDim2.new(0.5, -16, 0, 222)
    quickActionsCard.Position = UDim2.new(0.5, 6, 0, 106)
    quickActionsCard.Parent = homeDashboardPanel
    styleDashboardCard(quickActionsCard)
    createDashboardSectionTitle(quickActionsCard, "Quick Actions")

    local actionButtons = {
        "Rejoin Server",
        "Reset Character",
        "Server Hop",
        "Join Discord"
    }

    for index, label in ipairs(actionButtons) do
        local actionButton = Instance.new("TextButton")
        actionButton.Size = UDim2.new(1, -24, 0, 38)
        actionButton.Position = UDim2.new(0, 12, 0, 40 + ((index - 1) * 44))
        actionButton.BackgroundColor3 = index == 1 and Color3.fromRGB(109, 57, 201) or Color3.fromRGB(31, 31, 47)
        actionButton.Text = label
        actionButton.TextColor3 = palette.text
        actionButton.Font = Enum.Font.GothamSemibold
        actionButton.TextSize = 14
        actionButton.AutoButtonColor = false
        actionButton.Parent = quickActionsCard
        addCorner(actionButton, 8)
    end

    local statusCard = Instance.new("Frame")
    statusCard.Size = UDim2.new(1, -20, 0, 88)
    statusCard.Position = UDim2.new(0, 10, 1, -100)
    statusCard.Parent = homeDashboardPanel
    styleDashboardCard(statusCard)
    createDashboardSectionTitle(statusCard, "Status")

    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -24, 0, 24)
    statusText.Position = UDim2.new(0, 12, 0, 38)
    statusText.BackgroundTransparency = 1
    statusText.Text = "AetherCore is up to date!"
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextColor3 = Color3.fromRGB(103, 224, 132)
    statusText.Font = Enum.Font.GothamSemibold
    statusText.TextSize = 16
    statusText.Parent = statusCard

    local versionText = Instance.new("TextLabel")
    versionText.Size = UDim2.new(1, -24, 0, 18)
    versionText.Position = UDim2.new(0, 12, 0, 62)
    versionText.BackgroundTransparency = 1
    versionText.Text = "Version: v1.0.0"
    versionText.TextXAlignment = Enum.TextXAlignment.Left
    versionText.TextColor3 = palette.secondary
    versionText.Font = Enum.Font.Gotham
    versionText.TextSize = 13
    versionText.Parent = statusCard
end

setupHomeDashboardPanel()

Aether.UI.ScriptHub = Aether.UI.ScriptHub or {}

function Aether.UI.ScriptHub.createHeader(parentPanel)
    local scriptHubHeader = Instance.new("Frame")
    scriptHubHeader.Size = UDim2.new(1, -20, 0, 84)
    scriptHubHeader.Position = UDim2.new(0, 10, 0, 12)
    scriptHubHeader.Parent = parentPanel
    styleDashboardCard(scriptHubHeader)

    local scriptHubTitle = Instance.new("TextLabel")
    scriptHubTitle.Size = UDim2.new(1, -30, 0, 34)
    scriptHubTitle.Position = UDim2.new(0, 15, 0, 12)
    scriptHubTitle.BackgroundTransparency = 1
    scriptHubTitle.Text = "AetherCore Assistant"
    scriptHubTitle.TextXAlignment = Enum.TextXAlignment.Left
    scriptHubTitle.TextColor3 = palette.text
    scriptHubTitle.Font = Enum.Font.GothamBold
    scriptHubTitle.TextSize = 30
    scriptHubTitle.Parent = scriptHubHeader

    local scriptHubSubtitle = Instance.new("TextLabel")
    scriptHubSubtitle.Size = UDim2.new(1, -30, 0, 24)
    scriptHubSubtitle.Position = UDim2.new(0, 15, 0, 48)
    scriptHubSubtitle.BackgroundTransparency = 1
    scriptHubSubtitle.Text = "Ask what a module does, how it works, or how to use AetherCore."
    scriptHubSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    scriptHubSubtitle.TextColor3 = palette.secondary
    scriptHubSubtitle.Font = Enum.Font.Gotham
    scriptHubSubtitle.TextSize = 16
    scriptHubSubtitle.Parent = scriptHubHeader
end

function Aether.UI.ScriptHub.createChatPanel(parentPanel)
    local chatCard = Instance.new("Frame")
    chatCard.Size = UDim2.new(1, -20, 1, -120)
    chatCard.Position = UDim2.new(0, 10, 0, 106)
    chatCard.Parent = parentPanel
    styleDashboardCard(chatCard)

    local chatLog = Instance.new("ScrollingFrame")
    chatLog.Size = UDim2.new(1, -24, 1, -74)
    chatLog.Position = UDim2.new(0, 12, 0, 12)
    chatLog.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    chatLog.BorderSizePixel = 0
    chatLog.ScrollBarThickness = 5
    chatLog.CanvasSize = UDim2.new(0, 0, 0, 0)
    chatLog.Parent = chatCard
    addCorner(chatLog, 8)

    local chatLayout = Instance.new("UIListLayout")
    chatLayout.Padding = UDim.new(0, 6)
    chatLayout.Parent = chatLog

    local chatInput = Instance.new("TextBox")
    chatInput.Size = UDim2.new(1, -118, 0, 44)
    chatInput.Position = UDim2.new(0, 12, 1, -56)
    chatInput.BackgroundColor3 = Color3.fromRGB(21, 21, 33)
    chatInput.BorderSizePixel = 0
    chatInput.PlaceholderText = "Ask: what does KillAura do? how does Scaffold work? what is AutoPearl?"
    chatInput.Text = ""
    chatInput.TextColor3 = palette.text
    chatInput.PlaceholderColor3 = palette.secondary
    chatInput.Font = Enum.Font.Gotham
    chatInput.TextSize = 14
    chatInput.TextXAlignment = Enum.TextXAlignment.Left
    chatInput.ClearTextOnFocus = false
    chatInput.Parent = chatCard
    addCorner(chatInput, 8)

    local sendButton = Instance.new("TextButton")
    sendButton.Size = UDim2.new(0, 94, 0, 44)
    sendButton.Position = UDim2.new(1, -106, 1, -56)
    sendButton.BackgroundColor3 = Color3.fromRGB(109, 57, 201)
    sendButton.Text = "Send"
    sendButton.TextColor3 = palette.text
    sendButton.Font = Enum.Font.GothamSemibold
    sendButton.TextSize = 14
    sendButton.AutoButtonColor = false
    sendButton.Parent = chatCard
    addCorner(sendButton, 8)

    return chatLog, chatLayout, chatInput, sendButton
end

function Aether.UI.ScriptHub.createKnowledge()
    local moduleKnowledge = {
        ["killaura"] = "KillAura automatically attacks nearby valid targets while active.",
        ["autoclicker"] = "AutoClicker repeatedly performs clicks at the configured rate.",
        ["aimbot"] = "Aimbot adjusts aim toward a selected target while aiming.",
        ["reach"] = "Reach extends hit registration distance within this script's limits.",
        ["antihit"] = "AntiHit reduces how easily enemies can land hits on you.",
        ["antideath"] = "AntiDeath attempts to prevent death using this script's safety checks.",
        ["speed"] = "Speed increases movement speed while the module is enabled.",
        ["step"] = "Step lets your character climb higher ledges without jumping.",
        ["safewalk"] = "SafeWalk helps prevent accidental edge walk-offs.",
        ["highjump"] = "HighJump boosts jump height above normal movement.",
        ["verticalfly"] = "VerticalFly gives controlled vertical movement while active.",
        ["scaffold"] = "Scaffold places blocks under or ahead of you while moving.",
        ["fov"] = "FOV changes your field-of-view camera setting.",
        ["crosshair"] = "Crosshair customizes or overlays the on-screen crosshair.",
        ["viewmodel"] = "Viewmodel adjusts first-person hand or item view positioning.",
        ["bedplates"] = "BedPlates displays bed-related markers or plate visuals.",
        ["wineffect"] = "WinEffect plays a visual effect when a win condition is met.",
        ["fastpickup"] = "FastPickup improves how quickly nearby drops are collected.",
        ["fastbreak"] = "FastBreak reduces the time needed to break valid blocks.",
        ["autotoxic"] = "AutoToxic sends preset chat taunts automatically based on events.",
        ["interface"] = "Interface controls parts of the script UI presentation.",
        ["ui cleanup"] = "UI Cleanup removes or hides unnecessary on-screen UI clutter.",
        ["breaker"] = "Breaker automatically targets and breaks specific nearby objectives.",
        ["nuker"] = "Nuker rapidly breaks multiple valid nearby blocks.",
        ["autovoiddrop"] = "AutoVoidDrop automatically drops selected items into the void.",
        ["autopearl"] = "AutoPearl automatically uses a pearl in supported situations.",
        ["autobank"] = "AutoBank automatically deposits or stores resources when possible.",
        ["raventp"] = "RavenTP teleports using the script's RavenTP routine.",
        ["missiletp"] = "MissileTP teleports using the script's missile-based teleport routine.",
        ["armorswitch"] = "ArmorSwitch swaps armor sets based on module logic or conditions."
    }

    local moduleAliases = {
        ["kill aura"] = "killaura",
        ["ka"] = "killaura",
        ["scafold"] = "scaffold",
        ["auto pearl"] = "autopearl",
        ["autoperal"] = "autopearl",
        ["missle tp"] = "missiletp",
        ["missile tp"] = "missiletp",
        ["raven tp"] = "raventp",
        ["bed plates"] = "bedplates",
        ["ui cleanup"] = "ui cleanup",
        ["uicleanup"] = "ui cleanup",
        ["auto void drop"] = "autovoiddrop",
        ["fast break"] = "fastbreak",
        ["fast pickup"] = "fastpickup",
        ["auto toxic"] = "autotoxic",
        ["vertical fly"] = "verticalfly",
        ["high jump"] = "highjump",
        ["win effect"] = "wineffect"
    }

    local moduleCategoriesReply = "Combat: KillAura, AutoClicker, Aimbot, Reach, AntiHit, AntiDeath\nBlatant: Speed, Step, SafeWalk, HighJump, VerticalFly, Scaffold\nRender: FOV, Crosshair, Viewmodel, BedPlates, WinEffect\nUtility: FastPickup, FastBreak, AutoToxic, Interface, UI Cleanup\nWorld: Breaker, Nuker, AutoVoidDrop, AutoPearl, AutoBank\nLegend: RavenTP, MissileTP, ArmorSwitch"
    return moduleKnowledge, moduleAliases, moduleCategoriesReply
end

function Aether.UI.ScriptHub.setupChatBehavior(chatLog, chatLayout, chatInput, sendButton)
    local moduleKnowledge, moduleAliases, moduleCategoriesReply = Aether.UI.ScriptHub.createKnowledge()

    local function normalizeText(text)
        local value = (text or ""):lower()
        return value:gsub("[%s%p_%-]+", "")
    end

    local function buildLevenshteinMatrix(lenA, lenB)
        local matrix = {}
        for i = 0, lenA do
            matrix[i] = {[0] = i}
        end
        for j = 0, lenB do
            matrix[0][j] = j
        end
        return matrix
    end

    local function computeLevenshteinCell(matrix, left, right, i, j)
        local cost = left:sub(i, i) == right:sub(j, j) and 0 or 1
        local deletion = matrix[i - 1][j] + 1
        local insertion = matrix[i][j - 1] + 1
        local substitution = matrix[i - 1][j - 1] + cost
        matrix[i][j] = math.min(deletion, insertion, substitution)
    end

    local function levenshtein(a, b)
        local left = a or ""
        local right = b or ""
        local lenA = #left
        local lenB = #right
        if lenA == 0 then
            return lenB
        end
        if lenB == 0 then
            return lenA
        end

        local matrix = buildLevenshteinMatrix(lenA, lenB)
        for i = 1, lenA do
            for j = 1, lenB do
                computeLevenshteinCell(matrix, left, right, i, j)
            end
        end

        return matrix[lenA][lenB]
    end

    local function findClosestModule(prompt)
        local rawPrompt = (prompt or ""):lower()
        local normalizedPrompt = normalizeText(rawPrompt)

        for alias, canonical in pairs(moduleAliases) do
            local aliasRaw = alias:lower()
            local aliasNormalized = normalizeText(aliasRaw)
            if rawPrompt:find(aliasRaw, 1, true) or normalizedPrompt:find(aliasNormalized, 1, true) then
                return canonical
            end
        end

        for moduleName in pairs(moduleKnowledge) do
            local moduleNormalized = normalizeText(moduleName)
            if normalizedPrompt:find(moduleNormalized, 1, true) then
                return moduleName
            end
        end

        local bestMatch, bestDistance
        for moduleName in pairs(moduleKnowledge) do
            local moduleNormalized = normalizeText(moduleName)
            local distance = levenshtein(normalizedPrompt, moduleNormalized)
            if normalizedPrompt:find(moduleNormalized, 1, true) then
                distance = 0
            elseif #normalizedPrompt > #moduleNormalized and normalizedPrompt:find(moduleNormalized:sub(1, math.max(1, #moduleNormalized - 2)), 1, true) then
                distance = math.min(distance, 2)
            end

            if not bestDistance or distance < bestDistance then
                bestDistance = distance
                bestMatch = moduleName
            end
        end

        if bestDistance and bestDistance <= 2 then
            return bestMatch
        end

        return nil
    end

    local function addChatBubble(message, isUser)
        local bubble = Instance.new("TextLabel")
        bubble.Size = UDim2.new(1, -12, 0, 0)
        bubble.AutomaticSize = Enum.AutomaticSize.Y
        bubble.BackgroundColor3 = isUser and Color3.fromRGB(68, 45, 110) or Color3.fromRGB(29, 29, 45)
        bubble.BorderSizePixel = 0
        bubble.Text = (isUser and "You: " or "Aether AI: ") .. message
        bubble.TextColor3 = palette.text
        bubble.Font = Enum.Font.Gotham
        bubble.TextSize = 14
        bubble.TextWrapped = true
        bubble.TextXAlignment = Enum.TextXAlignment.Left
        bubble.TextYAlignment = Enum.TextYAlignment.Top
        bubble.Parent = chatLog
        addCorner(bubble, 8)

        task.wait()
        chatLog.CanvasSize = UDim2.new(0, 0, 0, chatLayout.AbsoluteContentSize.Y + 10)
        chatLog.CanvasPosition = Vector2.new(0, math.max(0, chatLog.CanvasSize.Y.Offset - chatLog.AbsoluteWindowSize.Y))
    end

    local function buildAssistantReply(prompt)
        local rawPrompt = (prompt or "")
        local loweredPrompt = rawPrompt:lower()
        local normalizedPrompt = normalizeText(rawPrompt)

        local asksForList = loweredPrompt:find("list modules", 1, true)
            or loweredPrompt:find("show modules", 1, true)
            or loweredPrompt:find("what modules", 1, true)
            or loweredPrompt:find("categories", 1, true)

        if asksForList then
            return moduleCategoriesReply
        end

        if loweredPrompt:find("help", 1, true) then
            return "Try asking: what does KillAura do? how does Scaffold work? what is AutoPearl? explain FastBreak. You can also ask: list modules."
        end

        local questionWords = {"what", "how", "does", "do", "work", "explain", "describe", "is"}
        local soundsLikeQuestion = false
        for _, word in ipairs(questionWords) do
            if loweredPrompt:find(word, 1, true) then
                soundsLikeQuestion = true
                break
            end
        end

        local moduleKey = findClosestModule(rawPrompt)
        if moduleKey and soundsLikeQuestion then
            return moduleKnowledge[moduleKey]
        end

        return "I can help with AetherCore modules and script usage. Ask what a module does, how it works, or type 'list modules' to see categories."
    end

    local function submitChatPrompt()
        local prompt = (chatInput.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if prompt == "" then
            return
        end
        addChatBubble(prompt, true)
        chatInput.Text = ""
        addChatBubble(buildAssistantReply(prompt), false)
    end

    sendButton.MouseButton1Click:Connect(submitChatPrompt)
    chatInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            submitChatPrompt()
        end
    end)

    addChatBubble("Hello. I am your AetherCore assistant. Ask me what a module does, how a module works, or how to use the script.", false)
end

function Aether.UI.ScriptHub.setupDashboardPanel()
    Aether.UI.ScriptHub.createHeader(scriptHubDashboardPanel)

    local chatLog, chatLayout, chatInput, sendButton =
        Aether.UI.ScriptHub.createChatPanel(scriptHubDashboardPanel)

    Aether.UI.ScriptHub.setupChatBehavior(chatLog, chatLayout, chatInput, sendButton)
end

Aether.UI.ScriptHub.setupDashboardPanel()


Aether.UI.Settings = Aether.UI.Settings or {}

function Aether.UI.Settings.setupDashboardPanel()
    local settingsHeader = Instance.new("Frame")
    settingsHeader.Size = UDim2.new(1, -20, 0, 84)
    settingsHeader.Position = UDim2.new(0, 10, 0, 12)
    settingsHeader.Parent = settingsDashboardPanel
    styleDashboardCard(settingsHeader)

    local settingsTitle = Instance.new("TextLabel")
    settingsTitle.Size = UDim2.new(1, -30, 0, 34)
    settingsTitle.Position = UDim2.new(0, 15, 0, 12)
    settingsTitle.BackgroundTransparency = 1
    settingsTitle.Text = "Settings"
    settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
    settingsTitle.TextColor3 = palette.text
    settingsTitle.Font = Enum.Font.GothamBold
    settingsTitle.TextSize = 30
    settingsTitle.Parent = settingsHeader

    local settingsSubtitle = Instance.new("TextLabel")
    settingsSubtitle.Size = UDim2.new(1, -30, 0, 24)
    settingsSubtitle.Position = UDim2.new(0, 15, 0, 48)
    settingsSubtitle.BackgroundTransparency = 1
    settingsSubtitle.Text = "Configure AetherCore to your preference."
    settingsSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    settingsSubtitle.TextColor3 = palette.secondary
    settingsSubtitle.Font = Enum.Font.Gotham
    settingsSubtitle.TextSize = 16
    settingsSubtitle.Parent = settingsHeader

    local function createSettingsCard(titleText, items, positionScaleX)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0.3333, -14, 0, 236)
        card.Position = UDim2.new(positionScaleX, 10, 0, 106)
        card.Parent = settingsDashboardPanel
        styleDashboardCard(card)
        createDashboardSectionTitle(card, titleText)

        for index, itemText in ipairs(items) do
            local item = Instance.new("TextLabel")
            item.Size = UDim2.new(1, -24, 0, 32)
            item.Position = UDim2.new(0, 12, 0, 40 + ((index - 1) * 44))
            item.BackgroundColor3 = Color3.fromRGB(31, 31, 47)
            item.BorderSizePixel = 0
            item.Text = itemText
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.TextColor3 = Color3.fromRGB(225, 225, 225)
            item.Font = Enum.Font.Gotham
            item.TextSize = 14
            item.Parent = card
            addCorner(item, 8)
            item.Text = "  " .. itemText
        end
    end

    createSettingsCard("General", {"Notifications", "Auto Rejoin", "Auto Respawn", "Reduce Lag"}, 0)
    createSettingsCard("UI", {"Theme", "UI Scale", "UI Position", "Show Keybinds"}, 0.3333)
    createSettingsCard("Config", {"Save Config", "Load Config", "Reset Config", "Auto Save"}, 0.6666)

    local infoCard = Instance.new("Frame")
    infoCard.Size = UDim2.new(1, -20, 0, 84)
    infoCard.Position = UDim2.new(0, 10, 1, -96)
    infoCard.Parent = settingsDashboardPanel
    styleDashboardCard(infoCard)

    local infoTitle = Instance.new("TextLabel")
    infoTitle.Size = UDim2.new(1, -24, 0, 24)
    infoTitle.Position = UDim2.new(0, 12, 0, 12)
    infoTitle.BackgroundTransparency = 1
    infoTitle.Text = "Info"
    infoTitle.TextXAlignment = Enum.TextXAlignment.Left
    infoTitle.TextColor3 = palette.text
    infoTitle.Font = Enum.Font.GothamSemibold
    infoTitle.TextSize = 17
    infoTitle.Parent = infoCard

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -24, 0, 32)
    infoText.Position = UDim2.new(0, 12, 0, 40)
    infoText.BackgroundTransparency = 1
    infoText.Text = "Settings are saved automatically and configuration changes can be restored at any time."
    infoText.TextWrapped = true
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextColor3 = palette.secondary
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 13
    infoText.Parent = infoCard
end

Aether.UI.Settings.setupDashboardPanel()

function setupTopBarAndStatusControls()
    local refs = {}

    refs.searchBox = Instance.new("TextBox")
    refs.searchBox.Size = UDim2.new(1, -130, 0, 26)
    refs.searchBox.Position = UDim2.new(0, 8, 0, 7)
    refs.searchBox.BackgroundColor3 = palette.module
    refs.searchBox.PlaceholderText = "Search modules..."
    refs.searchBox.ClearTextOnFocus = false
    refs.searchBox.Text = ""
    refs.searchBox.TextColor3 = palette.text
    refs.searchBox.PlaceholderColor3 = palette.secondary
    refs.searchBox.Font = Enum.Font.Gotham
    refs.searchBox.TextSize = 13
    refs.searchBox.Parent = topBar
    addCorner(refs.searchBox, 6)

    refs.closeButton = Instance.new("TextButton")
    refs.closeButton.Size = UDim2.new(0, 112, 0, 26)
    refs.closeButton.Position = UDim2.new(1, -120, 0, 7)
    refs.closeButton.BackgroundColor3 = palette.danger
    refs.closeButton.Text = "Uninject"
    refs.closeButton.TextColor3 = palette.text
    refs.closeButton.Font = Enum.Font.GothamBold
    refs.closeButton.TextSize = 12
    refs.closeButton.Parent = topBar
    addCorner(refs.closeButton, 6)

    refs.statusDiscord = Instance.new("TextButton")
    refs.statusDiscord.Size = UDim2.new(0, 150, 1, 0)
    refs.statusDiscord.BackgroundTransparency = 1
    refs.statusDiscord.Text = "discord.gg/mMMFRaUgDz"
    refs.statusDiscord.TextColor3 = palette.secondary
    refs.statusDiscord.Font = Enum.Font.Gotham
    refs.statusDiscord.TextSize = 11
    refs.statusDiscord.TextXAlignment = Enum.TextXAlignment.Left
    refs.statusDiscord.Parent = statusPanel

    refs.statusTime = Instance.new("TextLabel")
    refs.statusTime.Size = UDim2.new(0, 110, 1, 0)
    refs.statusTime.Position = UDim2.new(1, -110, 0, 0)
    refs.statusTime.BackgroundTransparency = 1
    refs.statusTime.Text = "Time: 0s"
    refs.statusTime.TextColor3 = palette.secondary
    refs.statusTime.Font = Enum.Font.Gotham
    refs.statusTime.TextSize = 11
    refs.statusTime.TextXAlignment = Enum.TextXAlignment.Right
    refs.statusTime.Parent = statusPanel

    refs.statusDiscord.MouseButton1Click:Connect(function()
        if clipboardSetter then
            safeCall("CopyDiscord", function()
                clipboardSetter("https://discord.gg/mMMFRaUgDz")
            end)
        else
            warn("[AetherCore][CopyDiscord] setclipboard is unavailable in this executor.")
        end
    end)

    local startTick = tick()
    RunService.RenderStepped:Connect(function()
        if refs.statusTime and refs.statusTime.Parent then
            refs.statusTime.Text = string.format("Time: %ds", math.floor(tick() - startTick))
        end
    end)

    return refs
end

topBarStatusRefs = setupTopBarAndStatusControls()

makeDraggable(mainPanel, mainTop)
makeDraggable(topBar, topBar)
makeDraggable(statusPanel, statusPanel)

function AetherFilterMatches(name, searchText)
    local q = string.lower(searchText or "")
    return q == "" or string.find(string.lower(name), q, 1, true) ~= nil
end

function filterMatches(name)
    return AetherFilterMatches(name, searchText)
end

AetherValidationRules = {
    {"KillAura", "range", 5, 20, 14},
    {"KillAura", "swingSpeed", 1, 20, 18},
    {"AutoClicker", "cps", 1, 20, 10},
    {"Speed", "speed", 16, 50, 24},
    {"Step", "maxHeight", 2, 14, 6},
    {"Step", "forwardCheckDistance", 1.5, 5, 2.6},
    {"SafeWalk", "maxDrop", 2, 10, 4.5},
    {"HighJump", "boost", 10, 180, 40},
    {"Aimbot", "fov", 20, 450, 160},
    {"Aimbot", "smoothness", 0.01, 1, 0.55},
    {"Aimbot", "predictionStrength", 0, 2, 1},
    {"Aimbot", "arrowSpeed", 40, 350, 185},
    {"Aimbot", "gravity", 40, 350, Workspace.Gravity},
    {"Aimbot", "maxDistance", 60, 400, 260},
    {"Reach", "hitRange", 6, 20, 12},
    {"Reach", "mineRange", 6, 20, 12},
    {"Reach", "placeRange", 6, 20, 12},
    {"VerticalFly", "horizontalSpeed", 8, 60, 28},
    {"VerticalFly", "verticalSpeed", 10, 120, 45},
    {"AntiDeath", "belowDuration", 0.5, 4, 2},
    {"AntiDeath", "slowMode", 0.2, 5, 1.5},
    {"AntiDeath", "voidOffset", 60, 250, 130},
    {"AntiHit", "slowMode", 0.2, 5, 1},
    {"AntiHit", "riseWindow", 0.08, 0.35, 0.14},
    {"AntiHit", "voidOffset", 60, 260, 130},
    {"AntiHit", "antiDamageJitter", 0, 6, 2.2},
    {"FastBreak", "cooldown", 0, 0.3, 0.03},
    {"FastBreak", "attemptsPerPulse", 1, 6, 2},
    {"AutoVoidDrop", "triggerOffset", 4, 60, 18},
    {"AutoVoidDrop", "dropInterval", 0.1, 2, 0.45}
}

function AetherValidateModuleSettings()

    for _, rule in ipairs(AetherValidationRules) do
        local moduleName, settingName, minValue, maxValue, fallbackValue = rule[1], rule[2], rule[3], rule[4], rule[5]
        local moduleTable = moduleSettings[moduleName]
        if moduleTable then
            clampSetting(moduleName, settingName, moduleTable[settingName], minValue, maxValue, fallbackValue)
        end
    end

    local verticalFly = moduleSettings.VerticalFly
    if verticalFly then
        clampSetting("VerticalFly", "groundOffset", verticalFly.groundOffset or verticalFly.hoverHeight, 1, 8, 3.2)
    end

    moduleSettings.AntiDeath.healthThreshold = math.max(1, tonumber(moduleSettings.AntiDeath.healthThreshold) or 25)
end

--====================================================
-- settings save and load system
--====================================================

function initializeClientSettingsPersistence()
    saveClientSettings = function()
        safeCall("SaveClientSettings", function()
            local payload = {
                keybinds = {},
                moduleStates = {},
                settings = moduleSettings,
                categoryPositions = {}
            }
            for moduleName, key in pairs(moduleKeybinds) do
                payload.keybinds[moduleName] = key and key.Name or nil
            end
            for moduleName, enabled in pairs(moduleStates) do
                payload.moduleStates[moduleName] = enabled == true
            end
            for categoryName, panel in pairs(categoryPanels) do
                payload.categoryPositions[categoryName] = {x = panel.Position.X.Offset, y = panel.Position.Y.Offset}
            end
            local encoded = HttpService:JSONEncode(payload)
            if sharedEnvironmentGetter then
                sharedEnvironmentGetter()[SETTINGS_STORE_KEY] = encoded
            end
        end)
    end

    local function loadClientSettingsNow()
        safeCall("LoadClientSettings", function()
            local raw = sharedEnvironmentGetter and sharedEnvironmentGetter()[SETTINGS_STORE_KEY]
            if type(raw) ~= "string" then return end
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) ~= "table" then return end
            if type(decoded.keybinds) == "table" then
                for moduleName, keyName in pairs(decoded.keybinds) do
                    if Enum.KeyCode[keyName] then
                        moduleKeybinds[moduleName] = Enum.KeyCode[keyName]
                    end
                end
            end
            if type(decoded.moduleStates) == "table" then
                for moduleName, enabled in pairs(decoded.moduleStates) do
                    if type(enabled) == "boolean" then
                        loadedModuleStates[moduleName] = enabled
                    end
                end
            end
            if type(decoded.settings) == "table" then
                for moduleName, values in pairs(decoded.settings) do
                    if moduleSettings[moduleName] and type(values) == "table" then
                        for key, value in pairs(values) do
                            moduleSettings[moduleName][key] = value
                        end
                    end
                end
            end
            if type(decoded.categoryPositions) == "table" then
                loadedCategoryPositions = decoded.categoryPositions
            end
        end)
        AetherValidateModuleSettings()
    end

    loadClientSettingsNow()
end

initializeClientSettingsPersistence()

--====================================================
-- startup
--====================================================

-- startup stays at the bottom so it is easy to see load order


-- module toggles live in bedwars/aethercore/modules/*.luau

function toggleAlias(handler)
    return function(enabled)
        if handler then
            handler(enabled)
        end
    end
end


vapePalette = {
    bg = Color3.fromRGB(18, 18, 18),
    bg2 = Color3.fromRGB(22, 22, 22),
    window = Color3.fromRGB(28, 28, 28),
    window2 = Color3.fromRGB(34, 34, 34),
    row = Color3.fromRGB(38, 38, 38),
    rowHover = Color3.fromRGB(47, 47, 47),
    rowOn = Color3.fromRGB(134, 72, 214),
    rowOn2 = Color3.fromRGB(103, 53, 174),
    accent = palette.accent or Color3.fromRGB(164, 94, 233),
    text = Color3.fromRGB(245, 245, 245),
    muted = Color3.fromRGB(175, 175, 175),
    darkText = Color3.fromRGB(125, 125, 125),
    stroke = Color3.fromRGB(52, 52, 52),
    danger = palette.danger or Color3.fromRGB(180, 65, 65)
}

function clearChildrenExceptLayout(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

function addStroke(target, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or vapePalette.stroke
    stroke.Transparency = transparency or 0.35
    stroke.Thickness = thickness or 1
    stroke.Parent = target
    return stroke
end

function addGradient(target, colorA, colorB, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorA),
        ColorSequenceKeypoint.new(1, colorB)
    })
    gradient.Rotation = rotation or 90
    gradient.Parent = target
    return gradient
end

function styleVapeWindow(frame)
    frame.BackgroundColor3 = vapePalette.window
    frame.BorderSizePixel = 0
    addCorner(frame, 4)
    addStroke(frame, vapePalette.stroke, 0.25, 1)
end

function styleVapeHeader(frame)
    frame.BackgroundColor3 = vapePalette.bg
    frame.BorderSizePixel = 0
    addCorner(frame, 4)
    addGradient(frame, Color3.fromRGB(31, 31, 31), Color3.fromRGB(18, 18, 18), 90)
end

function setButtonState(button, active)
    button.BackgroundColor3 = active and vapePalette.rowOn or vapePalette.row
    button.TextColor3 = active and vapePalette.text or vapePalette.muted
end

function createVapeSidebarButton(parent, label, icon, active)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = active and vapePalette.rowOn or vapePalette.row
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = string.format("  %s  %s", icon or "", label)
    button.TextColor3 = active and vapePalette.text or vapePalette.muted
    button.Font = Enum.Font.SourceSans
    button.TextSize = 18
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = parent
    addCorner(button, 3)

    button.MouseEnter:Connect(function()
        if button.BackgroundColor3 ~= vapePalette.rowOn then
            button.BackgroundColor3 = vapePalette.rowHover
        end
    end)
    button.MouseLeave:Connect(function()
        if button.BackgroundColor3 ~= vapePalette.rowOn then
            button.BackgroundColor3 = vapePalette.row
        end
    end)

    return button
end

-- Main sidebar restyle: more Vape-like, less dashboard-y.
mainPanel.Size = UDim2.new(0, 205, 0, 455)
mainPanel.Position = UDim2.new(0, 75, 0, 105)
styleVapeWindow(mainPanel)

mainTop.Size = UDim2.new(1, 0, 0, 42)
styleVapeHeader(mainTop)

mainTitle.Text = "AetherCore"
mainTitle.Font = Enum.Font.SourceSansBold
mainTitle.TextSize = 24
mainTitle.TextColor3 = vapePalette.text
mainTitle.Position = UDim2.new(0, 12, 0, 0)
mainTitle.Size = UDim2.new(1, -24, 1, 0)

mainAccentLine = Instance.new("Frame")
mainAccentLine.Size = UDim2.new(1, 0, 0, 2)
mainAccentLine.Position = UDim2.new(0, 0, 1, -2)
mainAccentLine.BackgroundColor3 = vapePalette.accent
mainAccentLine.BorderSizePixel = 0
mainAccentLine.Parent = mainTop

mainList.Size = UDim2.new(1, -14, 1, -58)
mainList.Position = UDim2.new(0, 7, 0, 50)
mainList.BackgroundTransparency = 1
mainList.BorderSizePixel = 0
mainList.CanvasSize = UDim2.new(0, 0, 0, 0)
mainList.AutomaticCanvasSize = Enum.AutomaticSize.Y
mainList.ScrollBarThickness = 3
mainList.ScrollBarImageColor3 = vapePalette.accent
mainListLayout.Padding = UDim.new(0, 5)

-- Top bar restyle to match Vape's simple utility strip.
topBar.Size = UDim2.new(0, 370, 0, 38)
topBar.Position = UDim2.new(0, 295, 0, 105)
styleVapeWindow(topBar)

topBarStatusRefs.searchBox.Size = UDim2.new(1, -130, 0, 24)
topBarStatusRefs.searchBox.Position = UDim2.new(0, 8, 0, 7)
topBarStatusRefs.searchBox.BackgroundColor3 = vapePalette.row
topBarStatusRefs.searchBox.TextColor3 = vapePalette.text
topBarStatusRefs.searchBox.PlaceholderColor3 = vapePalette.darkText
topBarStatusRefs.searchBox.Font = Enum.Font.SourceSans
topBarStatusRefs.searchBox.TextSize = 16

topBarStatusRefs.closeButton.Size = UDim2.new(0, 112, 0, 24)
topBarStatusRefs.closeButton.Position = UDim2.new(1, -120, 0, 7)
topBarStatusRefs.closeButton.BackgroundColor3 = vapePalette.danger
topBarStatusRefs.closeButton.Font = Enum.Font.SourceSansBold
topBarStatusRefs.closeButton.TextSize = 15
topBarStatusRefs.closeButton.Text = "Self Destruct"

statusPanel.Size = UDim2.new(0, 275, 0, 25)
statusPanel.Position = UDim2.new(0, 75, 0, 570)
styleVapeWindow(statusPanel)
topBarStatusRefs.statusDiscord.Font = Enum.Font.SourceSans
topBarStatusRefs.statusDiscord.TextSize = 14
topBarStatusRefs.statusTime.Font = Enum.Font.SourceSans
topBarStatusRefs.statusTime.TextSize = 14

function createCategoryColumn(categoryName, index)
    local panel = createPanel(categoryName .. "Column", UDim2.new(0, 220, 0, 520), UDim2.new(0, 295 + ((index - 1) * 228), 0, 155))
    panel.Visible = false
    styleVapeWindow(panel)

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 36)
    top.BackgroundColor3 = vapePalette.bg
    top.BorderSizePixel = 0
    top.Parent = panel
    styleVapeHeader(top)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -42, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = categoryName
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = vapePalette.text
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.Parent = top

    local countTag = Instance.new("TextLabel")
    countTag.Name = "CountTag"
    countTag.Size = UDim2.new(0, 30, 0, 20)
    countTag.Position = UDim2.new(1, -36, 0, 8)
    countTag.BackgroundColor3 = vapePalette.row
    countTag.BorderSizePixel = 0
    countTag.Text = "0"
    countTag.TextColor3 = vapePalette.muted
    countTag.Font = Enum.Font.SourceSansBold
    countTag.TextSize = 14
    countTag.Parent = top
    addCorner(countTag, 3)

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BorderSizePixel = 0
    line.BackgroundColor3 = vapePalette.accent
    line.Parent = top

    local list = Instance.new("ScrollingFrame")
    list.Name = "ModuleList"
    list.Size = UDim2.new(1, -10, 1, -46)
    list.Position = UDim2.new(0, 5, 0, 41)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.ScrollBarThickness = 3
    list.ScrollBarImageColor3 = vapePalette.accent
    list.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = list

    local savedPos = loadedCategoryPositions[categoryName]
    if type(savedPos) == "table" then
        panel.Position = UDim2.new(0, tonumber(savedPos.x) or panel.Position.X.Offset, 0, tonumber(savedPos.y) or panel.Position.Y.Offset)
    end

    local cameraInstance = Workspace.CurrentCamera
    if cameraInstance then
        local viewport = cameraInstance.ViewportSize
        local maxX = math.max(10, viewport.X - panel.Size.X.Offset - 10)
        local maxY = math.max(10, viewport.Y - panel.Size.Y.Offset - 10)
        panel.Position = UDim2.new(0, math.clamp(panel.Position.X.Offset, 10, maxX), 0, math.clamp(panel.Position.Y.Offset, 10, maxY))
    end

    makeDraggable(panel, top)
    categoryPanels[categoryName] = panel
    categoryManualVisibility[categoryName] = panel.Visible
    panelFrames[categoryName] = panel
    return panel, list
end

categoryLists = {}
for i, name in ipairs(categoryOrder) do
    local panel, list = createCategoryColumn(name, i)
    categoryLists[name] = list
end

categoryData = {
    {name = "Combat", icon = "⚔"},
    {name = "Blatant", icon = "◆"},
    {name = "Render", icon = "◉"},
    {name = "Utility", icon = "◈"},
    {name = "World", icon = "◇"},
    {name = "Inventory", icon = "▣"},
    {name = "Kits", icon = "✦"},
    {name = "Minigames", icon = "◎"},
    {name = "BoostFPS", icon = "△"},
    {name = "Legit", icon = "✓"}
}

homeTabButton = createVapeSidebarButton(mainList, "Home", "⌂", true)

for _, category in ipairs(categoryData) do
    local button = createVapeSidebarButton(mainList, category.name, category.icon, false)
    categoryToggleButtons[category.name] = button

    button.MouseButton1Click:Connect(function()
        local panel = categoryPanels[category.name]
        local newVisibility = not panel.Visible
        panel.Visible = newVisibility
        categoryManualVisibility[category.name] = newVisibility
        setButtonState(button, panel.Visible)

        if panel.Visible then
            local cameraInstance = Workspace.CurrentCamera
            if cameraInstance then
                local viewport = cameraInstance.ViewportSize
                local maxX = math.max(10, viewport.X - panel.AbsoluteSize.X - 10)
                local maxY = math.max(10, viewport.Y - panel.AbsoluteSize.Y - 10)
                local visibleCount = 0
                for _, categoryName in ipairs(categoryOrder) do
                    local categoryPanel = categoryPanels[categoryName]
                    if categoryPanel and categoryPanel.Visible and categoryPanel ~= panel then
                        visibleCount += 1
                    end
                end
                local preferredX = topBar.Position.X.Offset + topBar.Size.X.Offset + 10 + (visibleCount * (panel.Size.X.Offset + 8))
                local preferredY = mainPanel.Position.Y.Offset + 50
                panel.Position = UDim2.new(0, math.clamp(preferredX, 10, maxX), 0, math.clamp(preferredY, 10, maxY))
            end
        end

        saveClientSettings()
    end)
end

settingsTabSeparator = Instance.new("Frame")
settingsTabSeparator.Size = UDim2.new(1, 0, 0, 10)
settingsTabSeparator.BackgroundTransparency = 1
settingsTabSeparator.Parent = mainList

settingsTabButton = createVapeSidebarButton(mainList, "Settings", "⚙", false)
scriptHubTabButton = createVapeSidebarButton(mainList, "ScriptHub", "✦", false)

function uiCreateSlider(parent, name, min, max, default, callback, options)
    options = options or {}

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = vapePalette.muted
    label.Font = Enum.Font.SourceSans
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueButton = Instance.new("TextButton")
    valueButton.Size = UDim2.new(0.35, -4, 0, 18)
    valueButton.Position = UDim2.new(0.65, 4, 0, 0)
    valueButton.BackgroundColor3 = vapePalette.row
    valueButton.BorderSizePixel = 0
    valueButton.TextColor3 = vapePalette.text
    valueButton.Font = Enum.Font.SourceSans
    valueButton.TextSize = 14
    valueButton.Parent = frame
    addCorner(valueButton, 3)

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 7)
    slider.Position = UDim2.new(0, 0, 0, 27)
    slider.BackgroundColor3 = vapePalette.row
    slider.BorderSizePixel = 0
    slider.Parent = frame
    addCorner(slider, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = vapePalette.accent
    fill.BorderSizePixel = 0
    fill.Parent = slider
    addCorner(fill, 3)

    local dragging = false
    local range = max - min

    local function apply(v, fromTextEntry)
        local numeric = tonumber(v)
        if not numeric then return end
        local safeNumeric = math.clamp(numeric, -1000000, 1000000)
        local allowBeyondMax = fromTextEntry and (options.allowTextInputBeyondMax ~= false)
        local appliedValue = allowBeyondMax and math.max(safeNumeric, min) or math.clamp(safeNumeric, min, max)
        local visualValue = math.clamp(appliedValue, min, max)
        fill.Size = UDim2.new((visualValue - min) / range, 0, 1, 0)
        valueButton.Text = tostring(math.floor(appliedValue * 100) / 100)
        callback(appliedValue)
    end

    apply(default)

    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local percent = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            apply(min + (percent * range), false)
        end
    end)

    local lastClick = 0
    valueButton.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClick >= 0.35 then
            lastClick = now
            return
        end
        lastClick = 0

        local box = Instance.new("TextBox")
        box.Size = valueButton.Size
        box.Position = valueButton.Position
        box.BackgroundColor3 = vapePalette.bg2
        box.BorderSizePixel = 0
        box.TextColor3 = vapePalette.text
        box.Font = Enum.Font.SourceSans
        box.TextSize = 14
        box.ClearTextOnFocus = false
        box.Text = valueButton.Text
        box.Parent = frame
        addCorner(box, 3)
        box:CaptureFocus()
        box.FocusLost:Connect(function()
            apply(box.Text, true)
            box:Destroy()
        end)
    end)
end

function uiCreateToggle(parent, name, default, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 28)
    button.BackgroundColor3 = default and vapePalette.rowOn or vapePalette.row
    button.BorderSizePixel = 0
    button.TextColor3 = vapePalette.text
    button.Font = Enum.Font.SourceSans
    button.TextSize = 15
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.AutoButtonColor = false
    button.Parent = parent
    addCorner(button, 3)

    local state = default == true
    local function refresh()
        button.BackgroundColor3 = state and vapePalette.rowOn or vapePalette.row
        button.Text = "  " .. name .. (state and "  ON" or "  OFF")
    end
    refresh()

    button.MouseButton1Click:Connect(function()
        state = not state
        refresh()
        callback(state)
    end)
end

function uiCreateDropdown(parent, name, options, default, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 28)
    button.BackgroundColor3 = vapePalette.row
    button.BorderSizePixel = 0
    button.TextColor3 = vapePalette.text
    button.Font = Enum.Font.SourceSans
    button.TextSize = 15
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.AutoButtonColor = false
    button.Parent = parent
    addCorner(button, 3)

    local selected = default
    local function refreshText()
        button.Text = string.format("  %s: %s", name, tostring(selected))
    end
    refreshText()

    button.MouseButton1Click:Connect(function()
        local idx = table.find(options, selected) or 1
        idx = (idx % #options) + 1
        selected = options[idx]
        refreshText()
        callback(selected)
    end)
end

function uiCreateTextBox(parent, name, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 30)
    holder.BackgroundColor3 = vapePalette.row
    holder.BorderSizePixel = 0
    holder.Parent = parent
    addCorner(holder, 3)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "  " .. name
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = vapePalette.text
    label.Font = Enum.Font.SourceSans
    label.TextSize = 15
    label.Parent = holder

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.55, -6, 1, -8)
    box.Position = UDim2.new(0.45, 3, 0, 4)
    box.BackgroundColor3 = vapePalette.bg2
    box.BorderSizePixel = 0
    box.Text = tostring(default)
    box.TextColor3 = vapePalette.text
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.SourceSans
    box.TextSize = 14
    box.Parent = holder
    addCorner(box, 3)

    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
end

function createSettingsContent(parent, moduleName)
    local defs = moduleDefinitions[moduleName] or {}
    if #defs == 0 then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 24)
        label.BackgroundTransparency = 1
        label.Text = "No configurable settings"
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = vapePalette.darkText
        label.Font = Enum.Font.SourceSans
        label.TextSize = 15
        label.Parent = parent
        return
    end

    for _, setting in ipairs(defs) do
        if setting.type == "slider" then
            uiCreateSlider(parent, setting.name, setting.min, setting.max, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                if setting.onChange then
                    safeCall(moduleName .. "SettingChange", setting.onChange, val)
                end
                if moduleStates[moduleName] and moduleHandlers[moduleName] then
                    safeCall(moduleName .. "SettingsSliderUpdate", moduleHandlers[moduleName], true)
                end
                saveClientSettings()
            end, { allowTextInputBeyondMax = setting.allowTextInputBeyondMax })
        elseif setting.type == "toggle" then
            uiCreateToggle(parent, setting.name, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                if setting.onChange then
                    safeCall(moduleName .. "SettingChange", setting.onChange, val)
                end
                if moduleStates[moduleName] and moduleHandlers[moduleName] then
                    safeCall(moduleName .. "SettingsToggleUpdate", moduleHandlers[moduleName], true)
                end
                saveClientSettings()
            end)
        elseif setting.type == "dropdown" then
            uiCreateDropdown(parent, setting.name, setting.options, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                if setting.onChange then
                    safeCall(moduleName .. "SettingChange", setting.onChange, val)
                end
                if moduleStates[moduleName] and moduleHandlers[moduleName] then
                    safeCall(moduleName .. "SettingsDropdownUpdate", moduleHandlers[moduleName], true)
                end
                saveClientSettings()
            end)
        elseif setting.type == "textbox" then
            uiCreateTextBox(parent, setting.name, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                if setting.onChange then
                    safeCall(moduleName .. "SettingChange", setting.onChange, val)
                end
                if moduleStates[moduleName] and moduleHandlers[moduleName] then
                    safeCall(moduleName .. "SettingsTextUpdate", moduleHandlers[moduleName], true)
                end
                saveClientSettings()
            end)
        end
    end
end

function createModule(category, moduleName, defaultEnabled, toggleCallback)
    local list = categoryLists[category]
    if not list then return end

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -2, 0, 34)
    card.BackgroundColor3 = vapePalette.row
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = list
    addCorner(card, 3)

    local toggleArea = Instance.new("TextButton")
    toggleArea.Size = UDim2.new(1, -64, 0, 34)
    toggleArea.Position = UDim2.new(0, 0, 0, 0)
    toggleArea.BackgroundTransparency = 1
    toggleArea.AutoButtonColor = false
    toggleArea.Text = ""
    toggleArea.Parent = card

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, 0)
    accentBar.Position = UDim2.new(0, 0, 0, 0)
    accentBar.BackgroundColor3 = vapePalette.accent
    accentBar.BorderSizePixel = 0
    accentBar.Visible = false
    accentBar.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -82, 0, 34)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = moduleName
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = vapePalette.muted
    title.Font = Enum.Font.SourceSans
    title.TextSize = 18
    title.Parent = card

    local settingsBtn = Instance.new("TextButton")
    settingsBtn.Size = UDim2.new(0, 25, 0, 24)
    settingsBtn.Position = UDim2.new(1, -58, 0, 5)
    settingsBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    settingsBtn.BackgroundTransparency = 0.1
    settingsBtn.BorderSizePixel = 0
    settingsBtn.Text = "…"
    settingsBtn.TextColor3 = vapePalette.muted
    settingsBtn.Font = Enum.Font.SourceSansBold
    settingsBtn.TextSize = 18
    settingsBtn.Parent = card
    addCorner(settingsBtn, 3)

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(0, 28, 0, 24)
    keybindBtn.Position = UDim2.new(1, -30, 0, 5)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    keybindBtn.BackgroundTransparency = 0.1
    keybindBtn.BorderSizePixel = 0
    keybindBtn.TextColor3 = vapePalette.muted
    keybindBtn.Text = moduleKeybinds[moduleName] and moduleKeybinds[moduleName].Name or "-"
    keybindBtn.Font = Enum.Font.SourceSans
    keybindBtn.TextSize = 14
    keybindBtn.Parent = card
    addCorner(keybindBtn, 3)

    local settingsHolder = Instance.new("Frame")
    settingsHolder.Size = UDim2.new(1, -14, 0, 0)
    settingsHolder.Position = UDim2.new(0, 7, 0, 38)
    settingsHolder.BackgroundTransparency = 1
    settingsHolder.ClipsDescendants = true
    settingsHolder.Parent = card

    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 5)
    settingsLayout.Parent = settingsHolder

    local enabled = defaultEnabled
    if type(loadedModuleStates[moduleName]) == "boolean" then
        enabled = loadedModuleStates[moduleName]
    end
    moduleStates[moduleName] = enabled
    if moduleName == "AutoToxic" then
        autoToxicEnabled = enabled
    end

    local function updateCardVisual()
        card.BackgroundColor3 = enabled and vapePalette.rowOn2 or vapePalette.row
        title.TextColor3 = enabled and vapePalette.text or vapePalette.muted
        accentBar.Visible = enabled
    end

    local function toggleModule()
        enabled = not enabled
        if enabled then
            disableConflictingModules(moduleName)
        end
        moduleStates[moduleName] = enabled
        if moduleName == "AutoToxic" then
            autoToxicEnabled = enabled
        end
        if toggleCallback then
            safeCall(moduleName .. "Toggle", toggleCallback, enabled)
        end
        updateCardVisual()
        saveClientSettings()
    end

    toggleArea.MouseButton1Click:Connect(toggleModule)

    toggleArea.MouseEnter:Connect(function()
        if not enabled then card.BackgroundColor3 = vapePalette.rowHover end
    end)
    toggleArea.MouseLeave:Connect(function()
        if not enabled then card.BackgroundColor3 = vapePalette.row end
    end)

    settingsBtn.MouseButton1Click:Connect(function()
        settingsOpenByModule[moduleName] = not settingsOpenByModule[moduleName]
        clearChildrenExceptLayout(settingsHolder)

        if settingsOpenByModule[moduleName] then
            createSettingsContent(settingsHolder, moduleName)
            task.wait()
            local openSize = settingsLayout.AbsoluteContentSize.Y
            TweenService:Create(settingsHolder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -14, 0, openSize)
            }):Play()
            TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -2, 0, 44 + openSize)
            }):Play()
        else
            TweenService:Create(settingsHolder, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -14, 0, 0)
            }):Play()
            TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, -2, 0, 34)
            }):Play()
        end
    end)

    keybindBtn.MouseButton1Click:Connect(function()
        if keybindListening then return end
        keybindListening = true
        keybindBtn.Text = "..."
        local connection
        connection = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                for existingModule, existingKey in pairs(moduleKeybinds) do
                    if existingModule ~= moduleName and existingKey == key then
                        moduleKeybinds[existingModule] = nil
                        if moduleUi[existingModule] then
                            moduleUi[existingModule].setKeyText("-")
                        end
                    end
                end
                if moduleKeybinds[moduleName] == key then
                    moduleKeybinds[moduleName] = nil
                    keybindBtn.Text = "-"
                else
                    moduleKeybinds[moduleName] = key
                    keybindBtn.Text = key.Name
                end
                keybindListening = false
                if connection then connection:Disconnect() end
                saveClientSettings()
            end
        end)
    end)

    moduleUi[moduleName] = {
        setEnabled = function(state)
            enabled = state
            moduleStates[moduleName] = state
            if moduleName == "AutoToxic" then
                autoToxicEnabled = state
            end
            updateCardVisual()
        end,
        setKeyText = function(text)
            keybindBtn.Text = text == "NONE" and "-" or text
        end,
        setVisible = function(visible)
            card.Visible = visible
        end,
        category = category,
        name = moduleName
    }

    local header = categoryPanels[category] and categoryPanels[category]:FindFirstChildWhichIsA("Frame")
    local countTag = header and header:FindFirstChild("CountTag")
    if countTag then
        local count = 0
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("Frame") then count += 1 end
        end
        countTag.Text = tostring(count)
    end

    updateCardVisual()
    if enabled and toggleCallback then
        safeCall(moduleName .. "InitialToggle", toggleCallback, true)
    end
end


--====================================================
-- external module source bridge
--====================================================

Aether.ProviderModules = Aether.ProviderModules or {}
Aether.ProviderModuleLookup = Aether.ProviderModuleLookup or {}
Aether.ProviderStats = Aether.ProviderStats or {loaded = 0, skipped = 0, failed = 0}

PROVIDER_SOURCE_FILES = {
    {name = "CatVape", path = "bedwars/catvape.luau", url = "https://raw.githubusercontent.com/plutoxqqq/AetherCore/main/bedwars/catvape.luau"}
}

AETHER_PROVIDER_MODULE_MANIFEST = {
    {source = "CatVape", category = "Kits", name = "Auto Drill"},
    {source = "CatVape", category = "Combat", name = "Aim Assist"},
    {source = "CatVape", category = "Combat", name = "Bow Assist"},
    {source = "CatVape", category = "Combat", name = "Auto Clicker"},
    {source = "CatVape", category = "Combat", name = "Reach"},
    {source = "CatVape", category = "Combat", name = "Sprint"},
    {source = "CatVape", category = "Combat", name = "Trigger Bot"},
    {source = "CatVape", category = "Combat", name = "Velocity Plus"},
    {source = "CatVape", category = "Combat", name = "Velocity"},
    {source = "CatVape", category = "Blatant", name = "Auto Dodge"},
    {source = "CatVape", category = "Blatant", name = "Anti Fall"},
    {source = "CatVape", category = "Blatant", name = "Fast Break"},
    {source = "CatVape", category = "Blatant", name = "Fly"},
    {source = "CatVape", category = "Blatant", name = "Hit Boxes"},
    {source = "CatVape", category = "Blatant", name = "Keep Sprint"},
    {source = "CatVape", category = "Blatant", name = "Killaura"},
    {source = "CatVape", category = "Blatant", name = "Long Jump"},
    {source = "CatVape", category = "Blatant", name = "Mouse TP"},
    {source = "CatVape", category = "Blatant", name = "No Slow"},
    {source = "CatVape", category = "Blatant", name = "Projectile Aimbot"},
    {source = "CatVape", category = "Blatant", name = "Projectile Aura"},
    {source = "CatVape", category = "Blatant", name = "Speed"},
    {source = "CatVape", category = "Blatant", name = "Damage Boost"},
    {source = "CatVape", category = "Render", name = "Custom Tags"},
    {source = "CatVape", category = "Render", name = "Bed ESP"},
    {source = "CatVape", category = "Render", name = "Projectile Tracers"},
    {source = "CatVape", category = "Render", name = "Stream Remover"},
    {source = "CatVape", category = "Render", name = "Health"},
    {source = "CatVape", category = "Render", name = "Beehive ESP"},
    {source = "CatVape", category = "Render", name = "Kit ESP"},
    {source = "CatVape", category = "Render", name = "Generator ESP"},
    {source = "CatVape", category = "Render", name = "Item ESP"},
    {source = "CatVape", category = "Render", name = "Name Tags"},
    {source = "CatVape", category = "Render", name = "Storage ESP"},
    {source = "CatVape", category = "Utility", name = "Auto Balloon"},
    {source = "CatVape", category = "Utility", name = "Auto Kit"},
    {source = "CatVape", category = "Kits", name = "Auto Hannah"},
    {source = "CatVape", category = "Kits", name = "Auto Gingerbread Man"},
    {source = "CatVape", category = "Utility", name = "Auto Pearl"},
    {source = "CatVape", category = "Utility", name = "Auto Play"},
    {source = "CatVape", category = "Utility", name = "Anti Suffocate"},
    {source = "CatVape", category = "Utility", name = "Auto Release"},
    {source = "CatVape", category = "Utility", name = "Auto Shoot"},
    {source = "CatVape", category = "Utility", name = "Auto Toxic"},
    {source = "CatVape", category = "Utility", name = "Auto Void Drop"},
    {source = "CatVape", category = "Utility", name = "Knockback Delay"},
    {source = "CatVape", category = "Utility", name = "Missile TP"},
    {source = "CatVape", category = "Utility", name = "Pickup Range"},
    {source = "CatVape", category = "Utility", name = "Raven TP"},
    {source = "CatVape", category = "Utility", name = "Scaffold"},
    {source = "CatVape", category = "Utility", name = "Shop Tier Bypass"},
    {source = "CatVape", category = "Utility", name = "Staff Detector"},
    {source = "CatVape", category = "Utility", name = "Trap Disabler"},
    {source = "CatVape", category = "Utility", name = "Anti-AFK"},
    {source = "CatVape", category = "World", name = "Auto Suffocate"},
    {source = "CatVape", category = "World", name = "Auto Tool"},
    {source = "CatVape", category = "World", name = "Block-In"},
    {source = "CatVape", category = "World", name = "Chest Steal"},
    {source = "CatVape", category = "World", name = "Schematica"},
    {source = "CatVape", category = "World", name = "Fast Place"},
    {source = "CatVape", category = "Inventory", name = "Auto Steal"},
    {source = "CatVape", category = "Inventory", name = "Auto Fish"},
    {source = "CatVape", category = "Inventory", name = "Armor Switch"},
    {source = "CatVape", category = "Inventory", name = "Auto Bank"},
    {source = "CatVape", category = "Inventory", name = "Auto Buy"},
    {source = "CatVape", category = "Inventory", name = "Auto Consume"},
    {source = "CatVape", category = "Inventory", name = "Auto Hotbar"},
    {source = "CatVape", category = "Inventory", name = "Fast Consume"},
    {source = "CatVape", category = "Inventory", name = "Fast Drop"},
    {source = "CatVape", category = "Render", name = "Trap ESP"},
    {source = "CatVape", category = "Minigames", name = "Bed Plates"},
    {source = "CatVape", category = "Minigames", name = "Breaker"},
    {source = "CatVape", category = "Blatant", name = "Auto Kaida"},
    {source = "CatVape", category = "Kits", name = "Auto Ember"},
    {source = "CatVape", category = "Kits", name = "Auto Uma"},
    {source = "CatVape", category = "Kits", name = "Auto Adetunde"},
    {source = "CatVape", category = "Kits", name = "Auto Pyro"},
    {source = "CatVape", category = "Kits", name = "Auto Lani"},
    {source = "CatVape", category = "Kits", name = "Auto Noelle"},
    {source = "CatVape", category = "Kits", name = "Auto Marina"},
    {source = "CatVape", category = "Kits", name = "Auto Builder"},
    {source = "CatVape", category = "Kits", name = "Auto Nyx"},
    {source = "CatVape", category = "Kits", name = "Auto Sheep Herder"},
    {source = "CatVape", category = "Kits", name = "Auto Melody"},
    {source = "CatVape", category = "Kits", name = "Auto Ramil"},
    {source = "CatVape", category = "Kits", name = "Auto Caitlyn"},
    {source = "CatVape", category = "Kits", name = "Auto Zeno"},
    {source = "CatVape", category = "Kits", name = "Auto Metal"},
    {source = "CatVape", category = "Kits", name = "Auto Kaliyah"},
    {source = "CatVape", category = "Kits", name = "Auto Elder"},
    {source = "CatVape", category = "Kits", name = "Auto Taliyah"},
    {source = "CatVape", category = "Kits", name = "Auto Star Collector"},
    {source = "CatVape", category = "Kits", name = "Auto Whisper"},
    {source = "CatVape", category = "Kits", name = "Auto Beekeeper"},
    {source = "CatVape", category = "Kits", name = "Fisherman Spy"},
    {source = "CatVape", category = "Kits", name = "Auto Davey"},
    {source = "CatVape", category = "Kits", name = "Davey Aim"},
    {source = "CatVape", category = "Kits", name = "Infinite Sigrid"},
    {source = "CatVape", category = "Kits", name = "Infinite Krystal"},
    {source = "CatVape", category = "Legit", name = "Bed Alarm"},
    {source = "CatVape", category = "Legit", name = "Bed Break Effect"},
    {source = "CatVape", category = "Legit", name = "Clean Kit"},
    {source = "CatVape", category = "Legit", name = "Crosshair"},
    {source = "CatVape", category = "Legit", name = "Damage Indicator"},
    {source = "CatVape", category = "Legit", name = "FOV"},
    {source = "CatVape", category = "Legit", name = "FPS Boost"},
    {source = "CatVape", category = "Legit", name = "Hit Color"},
    {source = "CatVape", category = "Legit", name = "Hit Fix"},
    {source = "CatVape", category = "Legit", name = "Interface"},
    {source = "CatVape", category = "Render", name = "Kit Display"},
    {source = "CatVape", category = "Legit", name = "Kill Effect"},
    {source = "CatVape", category = "Legit", name = "Reach Display"},
    {source = "CatVape", category = "Legit", name = "Song Beats"},
    {source = "CatVape", category = "Legit", name = "Sound Changer"},
    {source = "CatVape", category = "Legit", name = "Texture Pack"},
    {source = "CatVape", category = "Legit", name = "No Click Delay"},
    {source = "CatVape", category = "Legit", name = "UI Cleanup"},
    {source = "CatVape", category = "Legit", name = "Viewmodel"},
    {source = "CatVape", category = "Legit", name = "Win Effect"},
}

function normalizeModuleName(name)
    return string.lower(tostring(name or ""):gsub("[^%w]", ""))
end

function createAetherProviderObject()
    local provider = {
        Loaded = true,
        Connections = {},
        Libraries = {},
        Categories = {}
    }

    local dummyObject = {Visible = true}
    local function cleanConnection(conn)
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        elseif type(conn) == "thread" then
            pcall(task.cancel, conn)
        elseif type(conn) == "function" then
            pcall(conn)
        end
    end

    function provider:Clean(conn)
        if conn then
            table.insert(self.Connections, conn)
        end
        return conn
    end

    function provider:Remove(module)
        if module and module.SetState then
            module:SetState(false)
        end
        return module
    end

    provider.Libraries.entity = {
        List = {},
        Connections = {},
        PlayerConnections = {},
        EntityThreads = {},
        Events = setmetatable({}, {__index = function(self, key)
            self[key] = Instance.new("BindableEvent")
            return self[key]
        end}),
        isAlive = false,
        character = {},
        EntityPosition = function() return nil end,
        EntityMouse = function() return nil end,
        Wallcheck = function() return false end,
        getUpdateConnections = function() return {} end,
        targetCheck = function() return true end,
        refreshEntity = function() end,
        addEntity = function() end,
        removeEntity = function() end,
        addPlayer = function() end,
        start = function() end
    }
    provider.Libraries.targetinfo = {Targets = {}}
    provider.Libraries.sessioninfo = {AddItem = function(_, itemName)
        return {Name = itemName, Value = 0, Increment = function(self) self.Value = (self.Value or 0) + 1 end, SetValue = function(self, value) self.Value = value end}
    end}
    provider.Libraries.uipallet = {}
    provider.Libraries.tween = function(...) return TweenService:Create(...) end
    provider.Libraries.color = {}
    provider.Libraries.whitelist = {}
    provider.Libraries.prediction = {SolveTrajectory = function() return nil end}
    provider.Libraries.getfontsize = function(_, size) return size end
    provider.Libraries.getcustomasset = function(path) return path end

    local function coerceSettingName(options, fallback)
        local name = tostring((options and options.Name) or fallback or "Setting")
        return name:gsub("%s+", "")
    end

    local function addSetting(module, definition, object, onChange)
        module.Settings = module.Settings or {}
        table.insert(module.Settings, object)
        table.insert(module.SettingsDefinition, definition)
        if definition.settingName then
            moduleSettings[module.Name] = moduleSettings[module.Name] or {}
            if moduleSettings[module.Name][definition.settingName] == nil then
                moduleSettings[module.Name][definition.settingName] = definition.default
            end
            definition.onChange = onChange
        end
        return object
    end

    local function buildModule(categoryName, config)
        config = config or {}
        local moduleName = tostring(config.Name or "Unnamed")
        local normalized = normalizeModuleName(moduleName)
        if Aether.ProviderModuleLookup[normalized] then
            Aether.ProviderStats.skipped += 1
            return Aether.ProviderModuleLookup[normalized].object
        end

        moduleSettings[moduleName] = moduleSettings[moduleName] or {}
        local module = {
            Name = moduleName,
            Category = categoryName,
            Tooltip = config.Tooltip,
            Enabled = false,
            Connections = {},
            Settings = {},
            SettingsDefinition = {},
            Function = config.Function
        }

        function module:Clean(conn)
            if conn then
                table.insert(self.Connections, conn)
            end
            return conn
        end

        function module:SetState(state)
            self.Enabled = state == true
            if self.Function then
                safeCall(self.Name .. "ProviderToggle", self.Function, self.Enabled)
            end
            if not self.Enabled then
                for _, conn in ipairs(self.Connections) do
                    cleanConnection(conn)
                end
                table.clear(self.Connections)
            end
        end

        function module:CreateToggle(options)
            options = options or {}
            local settingName = coerceSettingName(options, "Toggle")
            local object = {Name = options.Name or settingName, Enabled = options.Default == true, Object = dummyObject, Function = options.Function}
            return addSetting(self, {type = "toggle", name = object.Name, settingName = settingName, default = object.Enabled}, object, function(value)
                object.Enabled = value == true
                if object.Function then safeCall(self.Name .. settingName, object.Function, object.Enabled) end
            end)
        end

        function module:CreateSlider(options)
            options = options or {}
            local settingName = coerceSettingName(options, "Slider")
            local minValue = tonumber(options.Min) or 0
            local maxValue = tonumber(options.Max) or math.max(minValue + 1, tonumber(options.Default) or 100)
            local defaultValue = tonumber(options.Default) or minValue
            local object = {Name = options.Name or settingName, Value = defaultValue, Min = minValue, Max = maxValue, Object = dummyObject, Function = options.Function}
            return addSetting(self, {type = "slider", name = object.Name, min = minValue, max = maxValue, settingName = settingName, default = defaultValue, allowTextInputBeyondMax = true}, object, function(value)
                object.Value = tonumber(value) or object.Value
                if object.Function then safeCall(self.Name .. settingName, object.Function, object.Value) end
            end)
        end

        function module:CreateDropdown(options)
            options = options or {}
            local settingName = coerceSettingName(options, "Dropdown")
            local list = options.List or options.Options or {}
            local defaultValue = options.Default or list[1] or ""
            local object = {Name = options.Name or settingName, Value = defaultValue, List = list, Object = dummyObject, Function = options.Function}
            return addSetting(self, {type = "dropdown", name = object.Name, options = list, settingName = settingName, default = defaultValue}, object, function(value)
                object.Value = value
                if object.Function then safeCall(self.Name .. settingName, object.Function, object.Value) end
            end)
        end

        function module:CreateTextBox(options)
            options = options or {}
            local settingName = coerceSettingName(options, "Text")
            local defaultValue = tostring(options.Default or "")
            local object = {Name = options.Name or settingName, Value = defaultValue, Object = dummyObject, Function = options.Function}
            return addSetting(self, {type = "textbox", name = object.Name, settingName = settingName, default = defaultValue}, object, function(value)
                object.Value = tostring(value or "")
                if object.Function then safeCall(self.Name .. settingName, object.Function, object.Value) end
            end)
        end

        function module:CreateTwoSlider(options)
            options = options or {}
            local first = self:CreateSlider({Name = (options.Name or "Range") .. " Min", Min = options.Min or 0, Max = options.Max or 100, Default = options.DefaultMin or options.Min or 0, Function = options.Function})
            local second = self:CreateSlider({Name = (options.Name or "Range") .. " Max", Min = options.Min or 0, Max = options.Max or 100, Default = options.DefaultMax or options.Max or 100, Function = options.Function})
            return {Min = first, Max = second, Object = dummyObject}
        end

        function module:CreateColorSlider(options)
            return self:CreateSlider(options)
        end

        function module:CreateTargets(options)
            options = options or {}
            local object = {Object = dummyObject}
            for _, targetName in ipairs({"Players", "NPCs", "Walls", "Friends"}) do
                object[targetName] = {Enabled = options[targetName] == true, Object = dummyObject}
                self:CreateToggle({Name = targetName, Default = object[targetName].Enabled, Function = function(value)
                    object[targetName].Enabled = value
                end})
            end
            return object
        end

        function module:CreateTextList(options)
            options = options or {}
            return {Name = options.Name or "List", ListEnabled = {}, Object = dummyObject, Add = function(self, value) table.insert(self.ListEnabled, value) end}
        end

        function module:CreateHotbarList(options)
            return self:CreateTextList(options)
        end

        function module:CreateButton(options)
            options = options or {}
            local object = {Name = options.Name or "Button", Object = dummyObject, Function = options.Function}
            if options.Function then
                task.defer(function() safeCall(self.Name .. object.Name .. "ButtonInit", options.Function) end)
            end
            return object
        end

        function module:CreateFont(options)
            return self:CreateDropdown({Name = (options and options.Name) or "Font", List = {"SourceSans", "Gotham", "Arial"}, Default = (options and options.Default) or "SourceSans", Function = options and options.Function})
        end

        function module:CreateNotification(options)
            return self:CreateToggle(options)
        end

        Aether.ProviderModuleLookup[normalized] = {name = moduleName, object = module}
        table.insert(Aether.ProviderModules, module)
        Aether.ProviderStats.loaded += 1

        createRegisteredModule(categoryName, moduleName, false, function(enabled)
            module:SetState(enabled)
        end, module.SettingsDefinition)
        return module
    end

    setmetatable(provider.Categories, {__index = function(self, categoryName)
        local category = rawget(self, categoryName)
        if not category then
            category = {Name = categoryName}
            function category:CreateModule(config)
                return buildModule(self.Name, config)
            end
            rawset(self, categoryName, category)
        end
        return category
    end})

    return provider
end

function readProviderSource(providerInfo)
    if type(readfile) == "function" then
        local ok, source = pcall(readfile, providerInfo.path)
        if ok and type(source) == "string" and source ~= "" then
            return source
        end
    end
    local ok, source = pcall(function()
        return game:HttpGet(providerInfo.url)
    end)
    if ok and type(source) == "string" and source ~= "" then
        return source
    end
    return nil
end

function normalizeProviderSource(source)
    return source:gsub("local run = function%(%s*func%s*%)%s*\n%s*func%(%s*%)%s*\nend", "local run = function(func) local ok, err = pcall(func) if not ok then warn('[AetherCore] provider module failed: ' .. tostring(err)) end end")
end

function getQuotedProviderValue(block, key)
    local singleQuoted = block:match(key .. "%s*=%s*'([^']*)'")
    if singleQuoted then
        return singleQuoted
    end
    return block:match(key .. '%s*=%s*"([^"]*)"')
end

function getNumericProviderValue(block, key, fallback)
    local value = block:match(key .. "%s*=%s*([%-%.%d]+)")
    return tonumber(value) or fallback
end

function getBooleanProviderValue(block, key, fallback)
    local value = block:match(key .. "%s*=%s*(true)") or block:match(key .. "%s*=%s*(false)")
    if value == "true" then
        return true
    elseif value == "false" then
        return false
    end
    return fallback
end

function sanitizeProviderSettingName(name, fallback)
    local cleaned = tostring(name or fallback or "Setting"):gsub("[^%w]", "")
    return cleaned ~= "" and cleaned or tostring(fallback or "Setting")
end

function getProviderDropdownOptions(block)
    local listBlock = block:match("List%s*=%s*{(.-)}") or block:match("Options%s*=%s*{(.-)}")
    local options = {}
    if listBlock then
        for option in listBlock:gmatch("'([^']*)'") do
            table.insert(options, option)
        end
        for option in listBlock:gmatch('"([^"]*)"') do
            table.insert(options, option)
        end
    end
    if #options == 0 then
        table.insert(options, getQuotedProviderValue(block, "Default") or "Default")
    end
    return options
end

function getStaticProviderHandler(moduleName)
    local normalized = normalizeModuleName(moduleName)
    for handlerName, handler in pairs(moduleHandlers) do
        if normalizeModuleName(handlerName) == normalized then
            return handler
        end
    end

    local aliases = {
        killaura = "KillAura",
        aimassist = "AimAssist",
        autoclicker = "AutoClicker",
        triggerbot = "TriggerBot",
        velocityplus = "Velocity",
        antifall = "AntiVoid",
        fastbreak = "FastBreak",
        hitboxes = "HitBoxes",
        keepsprint = "Sprint",
        noslow = "Sprint",
        noslowdown = "Sprint",
        projectileaimbot = "Aimbot",
        speed = "Speed",
        bedesp = "BedESP",
        nametags = "NameTags",
        storageesp = "StorageESP",
        fpsboost = "FPS Boost",
        hitcolor = "Hit Color",
        hitfix = "Reach",
        viewmodel = "Viewmodel",
        nofalldamage = "NoFallDamage",
        nofall = "NoFall",
        autovoiddrop = "AutoVoidDrop",
        autobuy = "AutoBuy",
        staffdetector = "StaffDetector",
        trapdisabler = "TrapDisabler",
        pickuprange = "PickupRange",
        scaffold = "Scaffold",
        nuker = "Nuker"
    }

    local alias = aliases[normalized]
    return alias and moduleHandlers[alias] or nil
end

function addStaticProviderSetting(settings, moduleName, definition)
    moduleSettings[moduleName] = moduleSettings[moduleName] or {}
    if definition.settingName and moduleSettings[moduleName][definition.settingName] == nil then
        moduleSettings[moduleName][definition.settingName] = definition.default
    end
    table.insert(settings, definition)
end

function importStaticProviderSettings(segment, variableName, moduleName)
    local settings = {}
    local escapedVariable = variableName:gsub("([^%w])", "%%%1")

    for block in segment:gmatch(escapedVariable .. ":CreateSlider%s*%(%s*{(.-)}%)") do
        local name = getQuotedProviderValue(block, "Name") or "Slider"
        local minValue = getNumericProviderValue(block, "Min", 0)
        local maxValue = getNumericProviderValue(block, "Max", math.max(minValue + 1, getNumericProviderValue(block, "Default", 100)))
        local defaultValue = getNumericProviderValue(block, "Default", minValue)
        addStaticProviderSetting(settings, moduleName, {
            type = "slider",
            name = name,
            min = minValue,
            max = maxValue,
            settingName = sanitizeProviderSettingName(name, "Slider"),
            default = defaultValue,
            allowTextInputBeyondMax = true
        })
    end

    for block in segment:gmatch(escapedVariable .. ":CreateToggle%s*%(%s*{(.-)}%)") do
        local name = getQuotedProviderValue(block, "Name") or "Toggle"
        addStaticProviderSetting(settings, moduleName, {
            type = "toggle",
            name = name,
            settingName = sanitizeProviderSettingName(name, "Toggle"),
            default = getBooleanProviderValue(block, "Default", false)
        })
    end

    for block in segment:gmatch(escapedVariable .. ":CreateDropdown%s*%(%s*{(.-)}%)") do
        local name = getQuotedProviderValue(block, "Name") or "Dropdown"
        local options = getProviderDropdownOptions(block)
        addStaticProviderSetting(settings, moduleName, {
            type = "dropdown",
            name = name,
            options = options,
            settingName = sanitizeProviderSettingName(name, "Dropdown"),
            default = getQuotedProviderValue(block, "Default") or options[1]
        })
    end

    for block in segment:gmatch(escapedVariable .. ":CreateTextBox%s*%(%s*{(.-)}%)") do
        local name = getQuotedProviderValue(block, "Name") or "Text"
        addStaticProviderSetting(settings, moduleName, {
            type = "textbox",
            name = name,
            settingName = sanitizeProviderSettingName(name, "Text"),
            default = getQuotedProviderValue(block, "Default") or ""
        })
    end

    return settings
end

function importStaticProviderModules(providerInfo, source)
    local imported = 0
    local position = 1

    while true do
        local moduleStart, moduleEnd, variableName, categoryName = source:find("([%w_]+)%s*=%s*vape%.Categories%.([%w_]+):CreateModule%s*%(%s*{", position)
        if not moduleStart then
            break
        end

        local nextModuleStart = source:find("[%w_]+%s*=%s*vape%.Categories%.[%w_]+:CreateModule%s*%(%s*{", moduleEnd + 1) or (#source + 1)
        local segment = source:sub(moduleEnd + 1, nextModuleStart - 1)
        local moduleName = getQuotedProviderValue(segment:sub(1, 1200), "Name")

        if moduleName and moduleName ~= "" then
            local normalized = normalizeModuleName(moduleName)
            if not Aether.ProviderModuleLookup[normalized] then
                Aether.ProviderModuleLookup[normalized] = {name = moduleName, source = providerInfo.name, static = true}
                local settings = importStaticProviderSettings(segment, variableName, moduleName)
                createRegisteredModule(categoryName, moduleName, false, getStaticProviderHandler(moduleName), settings)
                imported += 1
            end
        end

        position = moduleEnd + 1
    end

    if imported > 0 then
        consoleLog(string.format("AetherCore statically imported %d modules from %s.", imported, providerInfo.name))
    end
end

function importEmbeddedProviderManifest()
    local imported = 0

    for _, moduleInfo in ipairs(AETHER_PROVIDER_MODULE_MANIFEST) do
        local moduleName = moduleInfo.name
        local normalized = normalizeModuleName(moduleName)
        if not Aether.ProviderModuleLookup[normalized] then
            createRegisteredModule(moduleInfo.category, moduleName, false, getStaticProviderHandler(moduleName), {})
            Aether.ProviderModuleLookup[normalized] = {name = moduleName, source = moduleInfo.source, manifest = true}
            imported += 1
        end
    end

    if imported > 0 then
        consoleLog(string.format("AetherCore imported %d embedded CatVape modules.", imported))
    end
end

function loadExternalModuleSources()
    if type(getgenv) ~= "function" then
        getgenv = function()
            return _G
        end
    end
    local originalSharedVape = shared and shared.vape or nil
    shared = shared or {}
    local provider = createAetherProviderObject()
    local providerSources = {}
    shared.vape = provider

    for _, providerInfo in ipairs(PROVIDER_SOURCE_FILES) do
        local source = readProviderSource(providerInfo)
        if source then
            table.insert(providerSources, {info = providerInfo, source = source})
            local compiled, compileError = loadstring(normalizeProviderSource(source))
            if compiled then
                local ok, runtimeError = pcall(compiled)
                if not ok then
                    Aether.ProviderStats.failed += 1
                    warn(string.format("[AetherCore] %s source bridge stopped early: %s", providerInfo.name, tostring(runtimeError)))
                end
            else
                Aether.ProviderStats.failed += 1
                warn(string.format("[AetherCore] %s source bridge could not compile: %s", providerInfo.name, tostring(compileError)))
            end
        else
            Aether.ProviderStats.failed += 1
            warn(string.format("[AetherCore] Could not read provider source: %s", providerInfo.path))
        end
    end

    for _, providerSource in ipairs(providerSources) do
        importStaticProviderModules(providerSource.info, providerSource.source)
    end

    importEmbeddedProviderManifest()

    shared.vape = originalSharedVape or provider
    consoleLog(string.format("AetherCore imported %d modules from CatVape (%d duplicates skipped).", Aether.ProviderStats.loaded, Aether.ProviderStats.skipped))
end

function createRegisteredModule(category, name, defaultEnabled, toggleCallback, settingsDefinition)
    local normalized = normalizeModuleName(name)
    if Aether.ProviderModuleLookup[normalized] and not (Aether.ProviderModuleLookup[normalized].name == name and moduleUi[name] == nil) then
        return
    end
    moduleDefinitions[name] = settingsDefinition or {}
    moduleHandlers[name] = toggleCallback
    createModule(category, name, defaultEnabled, toggleCallback)
end

-- AetherCore-only fallback modules. Provider matches are skipped so CatVape remains authoritative.
function registerAetherModules()
createRegisteredModule("Combat", "TriggerBot", false, toggleTriggerBot, {})
createRegisteredModule("Blatant", "AntiFall", false, toggleAlias(toggleAntiVoid), {})
createRegisteredModule("Blatant", "HitBoxes", false, toggleHitBoxes, {})
createRegisteredModule("Blatant", "KeepSprint", false, toggleAlias(toggleSprint), {})
createRegisteredModule("Blatant", "Killaura", false, toggleAlias(toggleKillAura), {})
createRegisteredModule("Blatant", "NoSlowdown", false, toggleAlias(toggleSprint), {})
createRegisteredModule("Blatant", "ProjectileAimbot", false, toggleProjectileAimbot, {})
createRegisteredModule("Blatant", "ProjectileAura", false, toggleProjectileAura, {})
createRegisteredModule("Render", "Health", false, toggleHealth, {})
createRegisteredModule("Render", "KitESP", false, toggleKitESP, {})
createRegisteredModule("Render", "StorageESP", false, toggleStorageESP, {})
createRegisteredModule("Utility", "AutoBalloon", false, toggleAlias(toggleFly), {})
createRegisteredModule("Utility", "AutoKit", false, toggleAlias(toggleAutoBuy), {})
createRegisteredModule("Utility", "AutoPearl", false, toggleAutoPearl, {{type = "slider", name = "Fall Trigger", min = 10, max = 80, settingName = "fallTrigger"}})
createRegisteredModule("Utility", "AutoPlay", false, toggleAutoPlay, {})
createRegisteredModule("Utility", "AutoShoot", false, toggleAutoShoot, {})
createRegisteredModule("Utility", "MissileTP", false, toggleMissileTP, {})
createRegisteredModule("Utility", "PickupRange", false, togglePickupRange, {{type = "slider", name = "Range", min = 6, max = 30, settingName = "range"}})
createRegisteredModule("Utility", "RavenTP", false, toggleRavenTP, {})
createRegisteredModule("Utility", "ShopTierBypass", false, toggleShopTierBypass, {})
createRegisteredModule("Utility", "StaffDetector", false, toggleStaffDetector, {})
createRegisteredModule("Utility", "TrapDisabler", false, toggleTrapDisabler, {})
createRegisteredModule("World", "Anti-AFK", false, toggleAntiAFK, {})
createRegisteredModule("World", "AutoSuffocate", false, toggleAutoSuffocate, {})
createRegisteredModule("World", "AutoTool", false, toggleAlias(toggleNuker), {})
createRegisteredModule("World", "BedProtector", false, toggleAlias(toggleScaffold), {})
createRegisteredModule("World", "ChestSteal", false, toggleAlias(toggleFastPickup), {})
createRegisteredModule("World", "Schematica", false, toggleAlias(toggleScaffold), {})
createRegisteredModule("Utility", "ArmorSwitch", false, toggleArmorSwitch, {})
createRegisteredModule("Utility", "AutoBank", false, toggleAutoBank, {})
createRegisteredModule("Utility", "AutoConsume", false, toggleAutoConsume, {})
createRegisteredModule("Utility", "AutoHotbar", false, toggleAutoHotbar, {})
createRegisteredModule("Utility", "FastConsume", false, toggleFastConsume, {})
createRegisteredModule("Utility", "FastDrop", false, toggleFastDrop, {})
createRegisteredModule("Render", "BedPlates", false, toggleBedPlates, {})
createRegisteredModule("World", "Breaker", false, toggleBreaker, {})
createRegisteredModule("Render", "Bed Break Effect", false, toggleBedBreakEffect, {})
createRegisteredModule("Render", "Clean Kit", false, toggleCleanKit, {})
createRegisteredModule("Render", "Crosshair", false, toggleCrosshair, {{type = "textbox", name = "Image ID", settingName = "imageId"}})
createRegisteredModule("Render", "Damage Indicator", false, toggleDamageIndicator, {})
createRegisteredModule("Render", "FOV", false, toggleFOV, {{type = "slider", name = "Field Of View", min = 50, max = 120, settingName = "value"}})
createRegisteredModule("Render", "FPS Boost", false, toggleFPSBoost, {})
createRegisteredModule("Render", "Hit Color", false, toggleHitColor, {})
createRegisteredModule("Render", "HitFix", false, toggleAlias(toggleReach), {})
createRegisteredModule("Render", "Interface", false, toggleInterface, {})
createRegisteredModule("Render", "Kill Effect", false, toggleKillEffect, {})
createRegisteredModule("Render", "Reach Display", false, toggleReachDisplay, {})
createRegisteredModule("Render", "Song Beats", false, toggleSongBeats, {})
createRegisteredModule("Render", "SoundChanger", false, toggleSoundChanger, {})
createRegisteredModule("Render", "UI Cleanup", false, toggleUICleanup, {})
createRegisteredModule("Render", "Viewmodel", false, toggleViewmodel, {{type = "slider", name = "X Offset", min = -3, max = 3, settingName = "xOffset"}, {type = "slider", name = "Y Offset", min = -3, max = 3, settingName = "yOffset"}, {type = "slider", name = "Z Offset", min = -3, max = 3, settingName = "zOffset"}})
createRegisteredModule("Render", "WinEffect", false, toggleWinEffect, {})

createRegisteredModule("Combat", "KillAura", false, toggleKillAura, {
    {type = "toggle", name = "Face Target", settingName = "faceTarget"},
    {type = "slider", name = "FOV Radius", min = 50, max = 600, settingName = "fovRadius"},
    {type = "slider", name = "Range", min = 5, max = 20, settingName = "range"},
    {type = "slider", name = "Swing Speed", min = 1, max = 20, settingName = "swingSpeed"},
    {type = "toggle", name = "Require Sword", settingName = "requireSword"},
    {type = "toggle", name = "Click Simulation", settingName = "fallbackToClickSimulation"},
    {type = "toggle", name = "Attack Players", settingName = "attackPlayers"},
    {type = "toggle", name = "Attack NPCs", settingName = "attackNPCs"}
})
createRegisteredModule("Combat", "Reach", false, toggleReach, {
    {type = "dropdown", name = "Mode", options = {"Both", "Attribute", "Handle"}, settingName = "mode"},
    {type = "slider", name = "Hit Range", min = 6, max = 20, settingName = "hitRange"},
    {type = "slider", name = "Mine Range", min = 6, max = 20, settingName = "mineRange"},
    {type = "slider", name = "Place Range", min = 6, max = 20, settingName = "placeRange"}
})
createRegisteredModule("Combat", "AimAssist", false, toggleAimAssist, {
    {type = "slider", name = "Range", min = 10, max = 50, settingName = "range"},
    {type = "slider", name = "Prediction", min = 0, max = 2.5, settingName = "prediction"},
    {type = "slider", name = "Smoothing", min = 4, max = 25, settingName = "smoothing"},
    {type = "slider", name = "Max Angle", min = 30, max = 180, settingName = "maxAngle"},
    {type = "dropdown", name = "Sort Method", options = {"Angle", "Threat", "Damage", "Health"}, settingName = "sortMethod"},
    {type = "dropdown", name = "Mode", options = {"Smooth", "Aggressive"}, settingName = "mode"},
    {type = "toggle", name = "Lag Resolver", settingName = "lagResolver"},
    {type = "toggle", name = "Humanization", settingName = "humanization"},
    {type = "toggle", name = "Wall Check", settingName = "wallCheck"},
    {type = "toggle", name = "Target Players", settingName = "targetPlayers"},
    {type = "toggle", name = "Target NPCs", settingName = "targetNPCs"}
})
createRegisteredModule("Combat", "Aimbot", false, toggleAimbot, {
    {type = "slider", name = "FOV", min = 20, max = 450, settingName = "fov"},
    {type = "slider", name = "Smoothness", min = 0.01, max = 1, settingName = "smoothness"},
    {type = "slider", name = "Snap Strength", min = 0.1, max = 1, settingName = "snapStrength"},
    {type = "slider", name = "Prediction", min = 0, max = 2, settingName = "predictionStrength"},
    {type = "slider", name = "Max Distance", min = 60, max = 400, settingName = "maxDistance"},
    {type = "dropdown", name = "Target Part", options = {"Head", "HumanoidRootPart"}, settingName = "targetPart"},
    {type = "toggle", name = "Wall Check", settingName = "wallCheck"},
    {type = "toggle", name = "Team Check", settingName = "teamCheck"},
    {type = "toggle", name = "Target NPCs", settingName = "targetNPCs"}
})
createRegisteredModule("Combat", "AutoClicker", false, toggleAutoClicker, {
    {type = "slider", name = "CPS", min = 1, max = 20, settingName = "cps"}
})
createRegisteredModule("Combat", "Sprint", false, toggleSprint, {
    {type = "toggle", name = "Omni Sprint", settingName = "omni"}
})
createRegisteredModule("Combat", "AutoQueue", false, toggleAutoQueue, {
    {type = "slider", name = "Queue Delay", min = 0.1, max = 5, settingName = "delay"}
})
createRegisteredModule("Combat", "Velocity", false, toggleVelocity, {
    {type = "dropdown", name = "Direction", options = {"Left", "Right", "Pull", "Random"}, settingName = "direction"},
    {type = "slider", name = "Chance", min = 0, max = 100, settingName = "chance"},
    {type = "toggle", name = "Only when targeting", settingName = "onlyWhenTargeting"}
})
createRegisteredModule("Combat", "NoClickDelay", false, toggleNoClickDelay, {})
createRegisteredModule("Blatant", "Speed", false, toggleSpeed, {
    {type = "slider", name = "Speed", min = 16, max = 50, settingName = "speed"}
})
createRegisteredModule("Blatant", "Step", false, toggleStep, {
    {type = "slider", name = "Max Height", min = 2, max = 14, settingName = "maxHeight"},
    {type = "slider", name = "Forward Check", min = 1.5, max = 5, settingName = "forwardCheckDistance"},
    {type = "slider", name = "Step Cooldown", min = 0.03, max = 0.25, settingName = "stepCooldown"}
})
createRegisteredModule("Blatant", "SafeWalk", false, toggleSafeWalk, {
    {type = "dropdown", name = "Mode", options = {"Normal", "TP"}, settingName = "mode"},
    {type = "slider", name = "Max Drop", min = 2, max = 10, settingName = "maxDrop"}
})
createRegisteredModule("Blatant", "HighJump", false, toggleHighJump, {
    {type = "slider", name = "Boost", min = 10, max = 180, settingName = "boost"}
})
createRegisteredModule("Blatant", "Fly", false, toggleFly, {
    {type = "slider", name = "Horizontal Speed", min = 10, max = 100, settingName = "horizontalSpeed"},
    {type = "slider", name = "Vertical Speed", min = 10, max = 100, settingName = "verticalSpeed"},
    {type = "toggle", name = "TP Down", settingName = "tpDownEnabled"},
    {type = "slider", name = "TP Interval", min = 1, max = 5, settingName = "tpDownInterval"},
    {type = "slider", name = "TP Return Delay", min = 0.05, max = 1, settingName = "tpDownReturnDelay"}
})
createRegisteredModule("Blatant", "VerticalFly", false, toggleVerticalFly, {
    {type = "slider", name = "Horizontal Speed", min = 8, max = 60, settingName = "horizontalSpeed"},
    {type = "slider", name = "Vertical Speed", min = 10, max = 120, settingName = "verticalSpeed"},
    {type = "slider", name = "Ground Offset", min = 1, max = 8, settingName = "groundOffset"},
    {type = "slider", name = "Anti Kick Sink", min = 0, max = 6, settingName = "antiKickSink"}
})
createRegisteredModule("Blatant", "LongJump", false, toggleLongJump, {
    {type = "slider", name = "Speed", min = 1, max = 37, settingName = "speed"},
    {type = "toggle", name = "Camera Direction", settingName = "cameraDirection"}
})
createRegisteredModule("Blatant", "Blink", false, toggleBlink, {
    {type = "slider", name = "Pulse Seconds", min = 0, max = 5, settingName = "pulseSeconds"}
})
createRegisteredModule("Blatant", "BedNuker", false, toggleBedNuker, {
    {type = "slider", name = "Range", min = 8, max = 40, settingName = "range"}
})
createRegisteredModule("Blatant", "NoFall", false, toggleNoFall, {
    {type = "dropdown", name = "Method", options = {"Landing", "NegateVelocity", "Teleport", "DaoExploit"}, settingName = "method"}
})
createRegisteredModule("Blatant", "Scaffold", false, toggleScaffold, {
    {type = "toggle", name = "Allow Towering", settingName = "allowTowering"},
    {type = "slider", name = "Place Ahead", min = 0, max = 2, settingName = "placeAhead"}
})
createRegisteredModule("Render", "ESP", false, toggleESP, {})
createRegisteredModule("Render", "Tracers", false, toggleTracers, {
    {type = "slider", name = "Transparency", min = 0, max = 1, settingName = "transparency"}
})
createRegisteredModule("Render", "BedESP", false, toggleBedESP, {})
createRegisteredModule("Render", "NameTags", false, toggleNameTags, {})
createRegisteredModule("Utility", "AutoToxic", false, toggleAutoToxic, {
    {type = "toggle", name = "Final Kill Message", settingName = "enabledFinalKill"},
    {type = "textbox", name = "Final Kill Text", settingName = "finalKillMessage"},
    {type = "toggle", name = "Bed Break Message", settingName = "enabledBedBreak"},
    {type = "textbox", name = "Bed Break Text", settingName = "bedBreakMessage"},
    {type = "toggle", name = "Game Win Message", settingName = "enabledGameWin"},
    {type = "textbox", name = "Game Win Text", settingName = "gameWinMessage"},
    {type = "toggle", name = "Auto GG", settingName = "autoGG"},
    {type = "toggle", name = "Sponsor Mode", settingName = "sponsorMode"},
    {type = "textbox", name = "Custom Phrases (|)", settingName = "customPhrases"}
})
createRegisteredModule("Utility", "AutoBuy", false, toggleAutoBuy, {
    {type = "toggle", name = "Auto Sword", settingName = "sword"},
    {type = "toggle", name = "Auto Armor", settingName = "armor"},
    {type = "toggle", name = "Auto Upgrades", settingName = "upgrades"}
})
createRegisteredModule("Utility", "OpenShop", false, toggleOpenShop, {})
createRegisteredModule("Utility", "OpenTeamUpgrades", false, toggleOpenTeamUpgrades, {})
createRegisteredModule("Utility", "NoFallDamage", false, toggleNoFallDamage, {
    {type = "dropdown", name = "Method", options = {"Landing", "NegateVelocity", "Teleport", "DaoExploit"}, settingName = "method"}
})
createRegisteredModule("Utility", "AntiDeath", false, toggleAntiDeath, {
    {type = "slider", name = "HP Threshold", min = 1, max = 95, settingName = "healthThreshold", allowTextInputBeyondMax = true},
    {type = "slider", name = "Down Duration", min = 0.5, max = 4, settingName = "belowDuration"},
    {type = "slider", name = "Slow Mode", min = 0.2, max = 5, settingName = "slowMode"},
    {type = "slider", name = "Void Offset", min = 60, max = 250, settingName = "voidOffset"}
})
createRegisteredModule("Utility", "AntiHit", false, toggleAntiHit, {
    {type = "slider", name = "Slow Mode", min = 0.2, max = 5, settingName = "slowMode"},
    {type = "slider", name = "Rise Window", min = 0.08, max = 0.35, settingName = "riseWindow"},
    {type = "slider", name = "Void Offset", min = 60, max = 260, settingName = "voidOffset"},
    {type = "slider", name = "Damage Jitter", min = 0, max = 6, settingName = "antiDamageJitter"}
})
createRegisteredModule("Utility", "AntiVoid", false, toggleAntiVoid, {
    {type = "dropdown", name = "Method", options = {"Normal", "Bounce"}, settingName = "method"},
    {type = "slider", name = "Bounce Power", min = 50, max = 200, settingName = "bouncePower"}
})
createRegisteredModule("Utility", "FastPickup", false, toggleFastPickup, {
    {type = "slider", name = "Range", min = 4, max = 30, settingName = "range"}
})
createRegisteredModule("Utility", "ProximityEditor", false, toggleProximityEditor, {
    {type = "slider", name = "Hold Duration", min = 0, max = 5, settingName = "holdDuration"},
    {type = "toggle", name = "Affect New Prompts", settingName = "affectNewPrompts"}
})
createRegisteredModule("Utility", "AutoLeave", false, toggleAutoLeave, {
    {type = "toggle", name = "Staff Only", settingName = "staffOnly"},
    {type = "toggle", name = "Leave On Match End", settingName = "leaveOnMatchEnd"}
})
createRegisteredModule("Utility", "AntiCrash", false, toggleAntiCrash, {})
createRegisteredModule("Utility", "InfiniteJump", false, toggleInfiniteJump, {})
createRegisteredModule("Utility", "AutoVoidDrop", false, toggleAutoVoidDrop, {
    {type = "slider", name = "Void Trigger Offset", min = 4, max = 60, settingName = "triggerOffset"},
    {type = "slider", name = "Drop Interval", min = 0.1, max = 2, settingName = "dropInterval"}
})
createRegisteredModule("World", "FastBreak", false, toggleFastBreak, {
    {type = "slider", name = "Break Cooldown", min = 0, max = 0.3, settingName = "cooldown"},
    {type = "slider", name = "Attempts/Pulse", min = 1, max = 6, settingName = "attemptsPerPulse"}
})
createRegisteredModule("World", "Nuker", false, toggleNuker, {
    {type = "toggle", name = "Mine Beds", settingName = "mineBeds"},
    {type = "toggle", name = "Mine Iron", settingName = "mineIron"},
    {type = "toggle", name = "Mine Gold", settingName = "mineGold"},
    {type = "toggle", name = "Mine Diamond", settingName = "mineDiamond"},
    {type = "toggle", name = "Mine Emerald", settingName = "mineEmerald"},
    {type = "slider", name = "Radius", min = 5, max = 20, settingName = "mineRadius"}
})
end

loadExternalModuleSources()
registerAetherModules()

function refreshSearch()
    local visibleModulesByCategory = {}
    for _, ui in pairs(moduleUi) do
        local moduleVisible = AetherFilterMatches(ui.name, searchText)
        ui.setVisible(moduleVisible)
        if moduleVisible then
            visibleModulesByCategory[ui.category] = true
        end
    end

    local searching = string.lower(searchText or "") ~= ""
    local showingCategories = activeSidebarTab == "Modules"
    for categoryName, panel in pairs(categoryPanels) do
        local manuallyVisible = categoryManualVisibility[categoryName] == true
        local hasVisibleModules = visibleModulesByCategory[categoryName] == true
        panel.Visible = showingCategories and (searching and manuallyVisible and hasVisibleModules or manuallyVisible)

        local categoryButton = categoryToggleButtons[categoryName]
        if categoryButton then
            categoryButton.BackgroundColor3 = panel.Visible and palette.active or palette.panel
        end
    end
end

function setActiveSidebarTab(tabName)
    activeSidebarTab = tabName
    homeDashboardPanel.Visible = tabName == "Home"
    settingsDashboardPanel.Visible = tabName == "Settings"
    scriptHubDashboardPanel.Visible = tabName == "ScriptHub"

    if homeTabButton then
        homeTabButton.BackgroundColor3 = tabName == "Home" and palette.active or palette.panel
    end
    if settingsTabButton then
        settingsTabButton.BackgroundColor3 = tabName == "Settings" and palette.active or palette.panel
    end
    if scriptHubTabButton then
        scriptHubTabButton.BackgroundColor3 = tabName == "ScriptHub" and palette.active or palette.panel
    end

    refreshSearch()
end

selfDestructing = false

function selfDestructAether()
    if selfDestructing then
        return
    end

    selfDestructing = true

    if screenGui then
        pcall(function()
            screenGui.Enabled = false
        end)
    end

    if autoToxicMessageConnection then
        pcall(function()
            autoToxicMessageConnection:Disconnect()
        end)
        autoToxicMessageConnection = nil
    end

    local sharedEnvironment = sharedEnvironmentGetter and sharedEnvironmentGetter() or nil
    if sharedEnvironment then
        sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] = nil
    end

    for moduleName, _ in pairs(moduleStates) do
        moduleStates[moduleName] = false

        if moduleHandlers[moduleName] then
            pcall(function()
                moduleHandlers[moduleName](false)
            end)
        end

        pcall(function()
            cleanupModule(moduleName)
        end)

        if moduleUi[moduleName] then
            pcall(function()
                moduleUi[moduleName].setEnabled(false)
            end)
        end
    end

    for moduleName, connections in pairs(moduleConnections) do
        if typeof(connections) == "RBXScriptConnection" then
            pcall(function()
                connections:Disconnect()
            end)
        elseif type(connections) == "table" then
            for _, connection in pairs(connections) do
                if typeof(connection) == "RBXScriptConnection" then
                    pcall(function()
                        connection:Disconnect()
                    end)
                end
            end
        end

        moduleConnections[moduleName] = nil
    end

    if type(moduleRuntime) == "table" then
        for key, value in pairs(moduleRuntime) do
            if typeof(value) == "Instance" then
                pcall(function()
                    value:Destroy()
                end)
            elseif type(value) == "table" then
                for _, nestedValue in pairs(value) do
                    if typeof(nestedValue) == "Instance" then
                        pcall(function()
                            nestedValue:Destroy()
                        end)
                    end
                end
            end

            moduleRuntime[key] = nil
        end
    end

    if screenGui then
        pcall(function()
            screenGui:Destroy()
        end)
        screenGui = nil
    end

    warn("[AetherCore] Self Destruct complete")
end

function setupNavigationAndCloseHandlers()
    topBarStatusRefs.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchText = topBarStatusRefs.searchBox.Text or ""
        refreshSearch()
    end)
    homeTabButton.MouseButton1Click:Connect(function()
        setActiveSidebarTab("Home")
    end)

    settingsTabButton.MouseButton1Click:Connect(function()
        setActiveSidebarTab("Settings")
    end)

    scriptHubTabButton.MouseButton1Click:Connect(function()
        setActiveSidebarTab("ScriptHub")
    end)

    for _, category in ipairs(categoryData) do
        local categoryButton = categoryToggleButtons[category.name]
        if categoryButton then
            categoryButton.MouseButton1Click:Connect(function()
                activeSidebarTab = "Modules"
                homeDashboardPanel.Visible = false
                settingsDashboardPanel.Visible = false
                if homeTabButton then homeTabButton.BackgroundColor3 = palette.panel end
                if settingsTabButton then settingsTabButton.BackgroundColor3 = palette.panel end
                if scriptHubTabButton then scriptHubTabButton.BackgroundColor3 = palette.panel end
                refreshSearch()
            end)
        end
    end

    setActiveSidebarTab("Home")
end

topBarStatusRefs.closeButton.MouseButton1Click:Connect(function()
    selfDestructAether()
end)

setupNavigationAndCloseHandlers()

--====================================================
-- key binds
--====================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if selfDestructing then return end
    if gameProcessed or keybindListening then return end

    if input.KeyCode == Enum.KeyCode.RightShift then
        if screenGui and screenGui.Parent then
            guiEnabled = not guiEnabled
            screenGui.Enabled = guiEnabled
        else
            warn("[AetherCore] UI is unavailable to toggle.")
        end
        return
    end

    for moduleName, key in pairs(moduleKeybinds) do
        if input.KeyCode == key then
            local enabled = not moduleStates[moduleName]
            if enabled then
                disableConflictingModules(moduleName)
            end
            moduleStates[moduleName] = enabled
            if moduleUi[moduleName] then
                moduleUi[moduleName].setEnabled(enabled)
            end
            if moduleHandlers[moduleName] then
                safeCall(moduleName .. "KeybindToggle", moduleHandlers[moduleName], enabled)
            end
            saveClientSettings()
            break
        end
    end
end)

lplr.CharacterAdded:Connect(function()
    if selfDestructing then return end

    for name, enabled in pairs(moduleStates) do
        if enabled and moduleHandlers[name] then
            safeCall(name .. "CharacterAddedToggle", moduleHandlers[name], true)
        end
    end
end)
