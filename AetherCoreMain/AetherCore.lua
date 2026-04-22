-- AetherCore :)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")

local lplr = Players.LocalPlayer
local mouse = lplr:GetMouse()
local camera = Workspace.CurrentCamera


local moduleStates = {}
local moduleConnections = {}
local moduleKeybinds = {}
local moduleSettings = {}
local moduleUi = {}
local moduleHandlers = {}
local guiEnabled = true
local autoToxicEnabled = false
local originalCharacterValues = {}
local SETTINGS_STORE_KEY = "AetherCoreClientConfigV1"
local AUTO_TOXIC_CONNECTION_KEY = "AetherCoreAutoToxicMessageConnection"
local mouseMoveRelative = type(mousemoverel) == "function" and mousemoverel or nil
local clipboardSetter = type(setclipboard) == "function" and setclipboard or nil
local sharedEnvironmentGetter = type(getgenv) == "function" and getgenv or nil
local autoToxicMessageConnection
local moduleConflictMap = {
    Speed = {"Fly", "VerticalFly", "LongJump"},
    Fly = {"Speed", "VerticalFly", "LongJump", "AntiVoid"},
    VerticalFly = {"Speed", "Fly", "LongJump", "AntiVoid"},
    LongJump = {"Speed", "Fly", "VerticalFly", "Scaffold", "NoFallDamage"},
    Scaffold = {"LongJump"},
    AntiVoid = {"Fly", "VerticalFly"},
    KillAura = {"AimAssist"},
    AimAssist = {"KillAura", "Aimbot"},
    Aimbot = {"KillAura", "AimAssist"}
}

local function logError(scope, err)
    warn(string.format("[AetherCore][%s] %s", tostring(scope), tostring(err)))
end

local function safeCall(scope, fn, ...)
    local args = table.pack(...)
    local ok, result = xpcall(function()
        return fn(table.unpack(args, 1, args.n))
    end, debug.traceback)
    if not ok then
        logError(scope, result)
        return nil
    end
    return result
end

local function clampSetting(moduleName, settingName, value, min, max, fallback)
    local numeric = tonumber(value)
    if not numeric then
        numeric = fallback
    end
    local clamped = math.clamp(numeric or 0, min, max)
    moduleSettings[moduleName] = moduleSettings[moduleName] or {}
    moduleSettings[moduleName][settingName] = clamped
    return clamped
end


local function sayInChat(message)
    pcall(function()
        local channel = TextChatService.ChatInputBarConfiguration.TargetTextChannel
        if channel then
            channel:SendAsync(message)
        end
    end)
end


local KnitClient, CombatController, BedwarsShopController, BlockPlacementController, ClientHandler
local resolvedCombatController, resolvedBlockPlacementController
local cachedNetManagedFolder
local cachedDropItemRemote
local cachedDamageBlockRemote

local function fetchControllers()
    local knitPaths = {
        ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Knit"),
        ReplicatedStorage:FindFirstChild("rbxts_include") and ReplicatedStorage.rbxts_include:FindFirstChild("node_modules"):FindFirstChild("@rbxts"):FindFirstChild("net"):FindFirstChild("out")
    }
    for _, knit in ipairs(knitPaths) do
        if knit then
            KnitClient = knit:FindFirstChild("Client")
            if KnitClient then break end
        end
    end
    if not KnitClient then return end
    local controllers = KnitClient:FindFirstChild("Controllers")
    if controllers then
        CombatController = controllers:FindFirstChild("CombatController")
        BedwarsShopController = controllers:FindFirstChild("BedwarsShopController")
        BlockPlacementController = controllers:FindFirstChild("BlockPlacementController") or controllers:FindFirstChild("BlockController")
        ClientHandler = controllers:FindFirstChild("ClientHandler")
    end
end
fetchControllers()

local function getNetManagedFolder()
    if cachedNetManagedFolder and cachedNetManagedFolder.Parent then
        return cachedNetManagedFolder
    end
    local rbxtsInclude = ReplicatedStorage:FindFirstChild("rbxts_include")
    if not rbxtsInclude then return nil end
    local nodeModules = rbxtsInclude:FindFirstChild("node_modules")
    if not nodeModules then return nil end
    local rbxtsNet = nodeModules:FindFirstChild("@rbxts")
    rbxtsNet = rbxtsNet and rbxtsNet:FindFirstChild("net")
    rbxtsNet = rbxtsNet and rbxtsNet:FindFirstChild("out")
    local netManaged = rbxtsNet and rbxtsNet:FindFirstChild("_NetManaged")
    cachedNetManagedFolder = netManaged
    return cachedNetManagedFolder
end

local function getDropItemRemote()
    if cachedDropItemRemote and cachedDropItemRemote.Parent then
        return cachedDropItemRemote
    end
    local netManaged = getNetManagedFolder()
    cachedDropItemRemote = netManaged and netManaged:FindFirstChild("DropItem")
    return cachedDropItemRemote
end

local function getDamageBlockRemote()
    if cachedDamageBlockRemote and cachedDamageBlockRemote.Parent then
        return cachedDamageBlockRemote
    end
    local netManaged = getNetManagedFolder()
    cachedDamageBlockRemote = netManaged and netManaged:FindFirstChild("DamageBlock")
    return cachedDamageBlockRemote
end


local function getCharacter(player)
    return player and player.Character
end

local function isPlayerCharacterModel(model)
    if not model or not model:IsA("Model") then
        return false
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == model then
            return true
        end
    end
    return false
end

local function getHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function raycastToGround(origin, ignoreList, castDistance)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList or {}
    return Workspace:Raycast(origin, Vector3.new(0, -(castDistance or 400), 0), params)
end

local function findNearestGroundPosition(origin, character, sampleRadius, sampleStep, verticalOffset)
    local bestPosition = nil
    local closestPlanar = math.huge
    local radius = sampleRadius or 14
    local step = sampleStep or 7
    local originPlanar = Vector3.new(origin.X, 0, origin.Z)

    for x = -radius, radius, step do
        for z = -radius, radius, step do
            local sampleOrigin = origin + Vector3.new(x, 35, z)
            local hit = raycastToGround(sampleOrigin, {character}, 420)
            if hit then
                local planar = Vector3.new(hit.Position.X, 0, hit.Position.Z)
                local planarDistance = (planar - originPlanar).Magnitude
                if planarDistance < closestPlanar then
                    closestPlanar = planarDistance
                    bestPosition = hit.Position + Vector3.new(0, verticalOffset or 3, 0)
                end
            end
        end
    end

    return bestPosition
end

local function getCombatController()
    if resolvedCombatController then
        return resolvedCombatController
    end
    if not CombatController then return nil end
    local ok, controller = pcall(require, CombatController)
    if ok and controller then
        resolvedCombatController = controller
    end
    return resolvedCombatController
end

local function getBlockPlacementController()
    if resolvedBlockPlacementController then
        return resolvedBlockPlacementController
    end
    if not BlockPlacementController then return nil end
    local ok, controller = pcall(require, BlockPlacementController)
    if ok and controller then
        resolvedBlockPlacementController = controller
    end
    return resolvedBlockPlacementController
end

local function doesToolNameMatch(tool, query)
    if not tool or not tool:IsA("Tool") or type(query) ~= "string" then
        return false
    end
    local normalizedToolName = tool.Name:lower()
    local normalizedQuery = query:lower()
    return normalizedToolName == normalizedQuery or normalizedToolName:find(normalizedQuery, 1, true) ~= nil
end

local function findToolInContainer(container, query)
    if not container then
        return nil
    end

    local exactMatch = container:FindFirstChild(query)
    if exactMatch and exactMatch:IsA("Tool") then
        return exactMatch
    end

    for _, descendant in ipairs(container:GetChildren()) do
        if descendant:IsA("Tool") and doesToolNameMatch(descendant, query) then
            return descendant
        end
    end

    return nil
end

local function hasItem(itemName)
    if type(itemName) ~= "string" or itemName == "" then
        return false, nil
    end

    local char = getCharacter(lplr)
    local backpack = lplr:FindFirstChildOfClass("Backpack")
    local equippedTool = char and findToolInContainer(char, itemName) or nil
    if equippedTool then
        return true, equippedTool
    end

    local backpackTool = backpack and findToolInContainer(backpack, itemName) or nil
    if backpackTool then
        return true, backpackTool
    end

    return false, nil
end

local function getHeldOrBackpackToolByKeywords(keywords)
    if type(keywords) ~= "table" or #keywords == 0 then
        return nil
    end

    local function matches(tool)
        if not tool or not tool:IsA("Tool") then
            return false
        end
        local loweredName = tool.Name:lower()
        for _, keyword in ipairs(keywords) do
            local loweredKeyword = tostring(keyword):lower()
            if loweredKeyword ~= "" and loweredName:find(loweredKeyword, 1, true) then
                return true
            end
        end
        return false
    end

    local char = getCharacter(lplr)
    if char then
        local heldTool = char:FindFirstChildOfClass("Tool")
        if matches(heldTool) then
            return heldTool
        end
        for _, tool in ipairs(char:GetChildren()) do
            if matches(tool) then
                return tool
            end
        end
    end

    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if matches(tool) then
                return tool
            end
        end
    end

    return nil
end

local function getHeldOrBackpackBlockTool()
    return getHeldOrBackpackToolByKeywords({"wool", "clay", "stone", "plank", "obsidian", "concrete", "glass"})
end

local function getHeldOrBackpackVoidDropTool()
    return getHeldOrBackpackToolByKeywords({"diamond", "emerald", "iron", "gold"})
end

local function getHeldOrBackpackDaoTool()
    local _, tool = hasItem("dao")
    return tool
end

local function equipToolIfNeeded(tool)
    local char = getCharacter(lplr)
    local hum = getHumanoid(char)
    if not tool or not hum or not char then
        return false
    end
    if tool.Parent == char then
        return true
    end
    local equipped = safeCall("EquipTool", function()
        hum:EquipTool(tool)
        return true
    end)
    if equipped then
        task.wait()
        return true
    end
    return false
end

local function isDaoTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end
    local lowered = tool.Name:lower()
    return lowered:find("dao") ~= nil
end

local function useDaoAbility()
    local char = getCharacter(lplr)
    if not char then return false end
    local dao = getHeldOrBackpackDaoTool()
    if not dao then return false end
    if not equipToolIfNeeded(dao) then
        return false
    end

    local used = false
    safeCall("DaoActivate", function()
        dao:Activate()
        used = true
    end)

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        for _, remote in ipairs(remotes:GetDescendants()) do
            if remote:IsA("RemoteEvent") and (remote.Name:lower():find("ability") or remote.Name:lower():find("use")) then
                safeCall("DaoRemoteString", function()
                    remote:FireServer(dao.Name)
                    used = true
                end)
                safeCall("DaoRemoteTable", function()
                    remote:FireServer({item = dao.Name})
                    used = true
                end)
            end
        end
    end

    return used
end

local function getTargetByFilters(range, attackPlayers, attackNPCs, ignoreTeammates)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    if not myHRP then
        return nil
    end
    local nearest
    local nearestDistance = range or math.huge

    if attackPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            local isSelf = player == lplr
            local sameTeam = player.Team ~= nil and lplr.Team ~= nil and player.Team == lplr.Team
            if not isSelf and (not ignoreTeammates or not sameTeam) then
                local targetChar = getCharacter(player)
                local targetHum = getHumanoid(targetChar)
                local targetHRP = getHRP(targetChar)
                if targetHum and targetHRP and targetHum.Health > 0 then
                    local distance = (targetHRP.Position - myHRP.Position).Magnitude
                    if distance < nearestDistance then
                        nearest = targetChar
                        nearestDistance = distance
                    end
                end
            end
        end
    end

    if attackNPCs then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model ~= myChar then
                local targetHum = model:FindFirstChildOfClass("Humanoid")
                local targetHRP = model:FindFirstChild("HumanoidRootPart")
                if targetHum and targetHRP and targetHum.Health > 0 then
                    if not isPlayerCharacterModel(model) then
                        local distance = (targetHRP.Position - myHRP.Position).Magnitude
                        if distance < nearestDistance then
                            nearest = model
                            nearestDistance = distance
                        end
                    end
                end
            end
        end
    end

    return nearest, nearestDistance
end


local function getNearestEnemy(range, ignoreTeam)
    local myChar = getCharacter(lplr)
    if not myChar then return nil, nil end
    local myTeam = ignoreTeam and lplr.Team or nil
    local myHRP = getHRP(myChar)
    if not myHRP then return nil, nil end

    local nearest = nil
    local shortest = range or math.huge


    for _, player in ipairs(Players:GetPlayers()) do
        if player == lplr then continue end
        if myTeam and player.Team == myTeam then continue end
        local char = getCharacter(player)
        local hrp = getHRP(char)
        if hrp then
            local hum = getHumanoid(char)
            if hum and hum.Health > 0 then
                local dist = (myHRP.Position - hrp.Position).Magnitude
                if dist < shortest then
                    shortest = dist
                    nearest = char
                end
            end
        end
    end


    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and model ~= myChar then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                if not isPlayerCharacterModel(model) then
                    local dist = (myHRP.Position - hrp.Position).Magnitude
                    if dist < shortest then
                        shortest = dist
                        nearest = model
                    end
                end
            end
        end
    end

    return nearest, shortest
end

local function getPlayerBedwarsTeamId(player)
    if not player then
        return nil
    end
    local directTeam = player:GetAttribute("Team")
        or player:GetAttribute("team")
        or player:GetAttribute("BedwarsTeam")
        or player:GetAttribute("bedwarsTeam")
    if directTeam ~= nil then
        return tostring(directTeam)
    end

    local character = player.Character
    if character then
        local charTeam = character:GetAttribute("Team")
            or character:GetAttribute("team")
            or character:GetAttribute("BedwarsTeam")
            or character:GetAttribute("bedwarsTeam")
        if charTeam ~= nil then
            return tostring(charTeam)
        end
    end

    return nil
end

local function arePlayersTeammates(playerA, playerB)
    if not playerA or not playerB then
        return false
    end
    if playerA.Team ~= nil and playerB.Team ~= nil and playerA.Team == playerB.Team then
        return true
    end
    local teamA = getPlayerBedwarsTeamId(playerA)
    local teamB = getPlayerBedwarsTeamId(playerB)
    return teamA ~= nil and teamB ~= nil and teamA == teamB
end

local function attackTargetWithBedwarsApi(targetCharacter)
    if not targetCharacter then
        return false
    end

    local controller = getCombatController()
    if not controller then
        return false
    end

    local targetHum = getHumanoid(targetCharacter)
    local targetRoot = getHRP(targetCharacter)
    if not targetHum or not targetRoot then
        return false
    end

    if type(controller.attackEntity) == "function" then
        return safeCall("KillAura_attackEntity", function()
            controller.attackEntity(controller, targetHum, targetRoot.Position)
            return true
        end) or false
    end

    if type(controller.AttackEntity) == "function" then
        return safeCall("KillAura_AttackEntity", function()
            controller.AttackEntity(controller, targetHum, targetRoot.Position)
            return true
        end) or false
    end

    return false
end

local function getEffectiveCombatRange(baseRange)
    local effectiveRange = baseRange or 0
    if moduleStates["Reach"] and moduleSettings["Reach"] then
        effectiveRange = math.max(effectiveRange, moduleSettings["Reach"].hitRange or effectiveRange)
    end
    return effectiveRange
end

local function getTargetAimPart(targetCharacter)
    return targetCharacter and (targetCharacter:FindFirstChild("Head") or getHRP(targetCharacter))
end

local function isTargetWithinFov(targetCharacter, fovRadius)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getTargetAimPart(targetCharacter)
    if not myHRP or not targetPart then
        return false
    end

    local clampedFov = math.clamp(tonumber(fovRadius) or 360, 1, 360)
    if clampedFov >= 359 then
        return true
    end

    local direction = (targetPart.Position - myHRP.Position)
    if direction.Magnitude <= 0 then
        return true
    end
    local look = camera.CFrame.LookVector
    local dot = math.clamp(look:Dot(direction.Unit), -1, 1)
    local angle = math.deg(math.acos(dot))
    return angle <= (clampedFov / 2)
end

local function hasLineOfSight(targetCharacter)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getTargetAimPart(targetCharacter)
    if not myHRP or not targetPart then
        return false
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {myChar}
    rayParams.IgnoreWater = true

    local direction = targetPart.Position - myHRP.Position
    local raycastResult = Workspace:Raycast(myHRP.Position, direction, rayParams)
    if not raycastResult then
        return true
    end

    return raycastResult.Instance and raycastResult.Instance:IsDescendantOf(targetCharacter)
end

local function faceCharacterTarget(targetCharacter)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getTargetAimPart(targetCharacter)
    if not myHRP or not targetPart then
        return
    end

    local targetPosition = Vector3.new(targetPart.Position.X, myHRP.Position.Y, targetPart.Position.Z)
    myHRP.CFrame = CFrame.lookAt(myHRP.Position, targetPosition)
end


local function addConnection(moduleName, connection)
    if not moduleConnections[moduleName] then
        moduleConnections[moduleName] = {}
    end
    table.insert(moduleConnections[moduleName], connection)
end

local function cleanupModule(moduleName)
    if moduleConnections[moduleName] then
        for _, conn in ipairs(moduleConnections[moduleName]) do
            pcall(function() conn:Disconnect() end)
        end
        moduleConnections[moduleName] = nil
    end
end

local function disableConflictingModules(moduleName)
    local conflicts = moduleConflictMap[moduleName]
    if type(conflicts) ~= "table" then
        return
    end
    for _, conflictName in ipairs(conflicts) do
        if moduleStates[conflictName] then
            moduleStates[conflictName] = false
            if moduleHandlers[conflictName] then
                safeCall(conflictName .. "ConflictDisable", moduleHandlers[conflictName], false)
            end
            if moduleUi[conflictName] then
                moduleUi[conflictName].setEnabled(false)
            end
        end
    end
end

local function setModuleEnabled(moduleName, enabled)
    moduleStates[moduleName] = enabled
    if moduleUi[moduleName] then
        moduleUi[moduleName].setEnabled(enabled)
    end
    if moduleHandlers[moduleName] then
        safeCall(moduleName .. "ProgrammaticToggle", moduleHandlers[moduleName], enabled)
    end
end

local function performPrimaryClick()
    return safeCall("PrimaryClick", function()
        local mouseLocation = UserInputService:GetMouseLocation()
        local currentCamera = Workspace.CurrentCamera or camera
        if not currentCamera then
            return false
        end
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(mouseLocation, currentCamera.CFrame)
        task.wait()
        VirtualUser:Button1Up(mouseLocation, currentCamera.CFrame)
        return true
    end) or false
end


local function legacyCreateSlider(parent, name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 42)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueButton = Instance.new("TextButton")
    valueButton.Size = UDim2.new(0.3, -4, 0, 18)
    valueButton.Position = UDim2.new(0.7, 4, 0, 0)
    valueButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    valueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueButton.Font = Enum.Font.Gotham
    valueButton.TextSize = 12
    valueButton.Parent = frame
    Instance.new("UICorner", valueButton).CornerRadius = UDim.new(0, 7)

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 10)
    slider.Position = UDim2.new(0, 0, 0, 24)
    slider.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
    slider.Parent = frame
    Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 6)

    local fill = Instance.new("Frame")
    local range = max - min
    local percent = (default - min) / range
    fill.Size = UDim2.new(percent, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

    local dragging = false
    local function formatValue(v)
        if math.abs(v - math.floor(v)) < 0.001 then
            return tostring(math.floor(v))
        end
        return string.format("%.2f", v)
    end
    local function setValue(v)
        default = math.clamp(v, min, max)
        local newPercent = (default - min) / range
        TweenService:Create(fill, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(newPercent, 0, 1, 0)}):Play()
        valueButton.Text = formatValue(default)
        callback(default)
    end

    valueButton.Text = formatValue(default)

    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relativeX = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
            local val = min + relativeX * range
            if math.abs(val - default) > 0.001 then
                setValue(val)
            end
        end
    end)

    local lastClick = 0
    valueButton.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClick > 0.35 then
            lastClick = now
            return
        end
        lastClick = 0

        local inputBox = Instance.new("TextBox")
        inputBox.Size = valueButton.Size
        inputBox.Position = valueButton.Position
        inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        inputBox.Font = Enum.Font.Gotham
        inputBox.TextSize = 12
        inputBox.Text = valueButton.Text
        inputBox.ClearTextOnFocus = false
        inputBox.Parent = frame
        Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 7)
        inputBox:CaptureFocus()

        inputBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local typed = tonumber(inputBox.Text)
                if typed then
                    setValue(typed)
                end
            end
            inputBox:Destroy()
        end)
    end)

    return {
        GetValue = function() return default end,
        SetValue = function(v)
            setValue(v)
        end
    }
end

local function legacyCreateToggle(parent, name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = Instance.new("Frame")
    button.Size = UDim2.new(0, 36, 0, 20)
    button.Position = UDim2.new(1, -36, 0.5, -10)
    button.BackgroundColor3 = default and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(56, 56, 56)
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

    local buttonClick = Instance.new("TextButton")
    buttonClick.Size = UDim2.fromScale(1, 1)
    buttonClick.BackgroundTransparency = 1
    buttonClick.Text = ""
    buttonClick.Parent = button

    local stateText = Instance.new("TextLabel")
    stateText.Size = UDim2.new(1, 0, 1, 0)
    stateText.BackgroundTransparency = 1
    stateText.Text = default and "ON" or "OFF"
    stateText.TextColor3 = Color3.fromRGB(255, 255, 255)
    stateText.Font = Enum.Font.GothamBold
    stateText.TextSize = 9
    stateText.Parent = button

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = button
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default
    local function updateToggleVisual()
        TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = state and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(56, 56, 56)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        stateText.Text = state and "ON" or "OFF"
    end

    buttonClick.MouseButton1Click:Connect(function()
        state = not state
        updateToggleVisual()
        callback(state)
    end)

    return {
        GetValue = function() return state end,
        SetValue = function(v)
            state = v
            updateToggleVisual()
            callback(v)
        end
    }
end

local function legacyCreateDropdown(parent, name, options, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 80, 0, 20)
    button.Position = UDim2.new(1, -80, 0.5, -10)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.Text = default
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)

    local selected = default
    button.MouseButton1Click:Connect(function()

        local idx = table.find(options, selected) or 1
        idx = idx % #options + 1
        selected = options[idx]
        button.Text = selected
        callback(selected)
    end)

    return {
        GetValue = function() return selected end,
        SetValue = function(v)
            selected = v
            button.Text = v
            callback(v)
        end
    }
end

local function legacyCreateTextBox(parent, name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 80, 0, 20)
    box.Position = UDim2.new(1, -80, 0.5, -10)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.Text = default
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 7)

    box.FocusLost:Connect(function(enterPressed)
        callback(box.Text)
    end)

    return {
        GetValue = function() return box.Text end,
        SetValue = function(v)
            box.Text = v
            callback(v)
        end
    }
end




moduleSettings["KillAura"] = {
    range = 14,
    fov = 360,
    swingSpeed = 18,
    faceTarget = false,
    requireSword = false,
    attackThroughWalls = true,
    ignoreTeammates = true,

    fovRadius = 360,
    attackPlayers = true,
    attackNPCs = false,
    fallbackToClickSimulation = false,

    targetSwitchDelay = 0.2
}

local killAuraLastSwing = 0

local function isSwordTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end

    local n = tool.Name:lower()
    return n:find("sword") ~= nil
        or n:find("blade") ~= nil
        or n:find("katana") ~= nil
        or n:find("dao") ~= nil
end

local function getHeldSword()
    local char = getCharacter(lplr)
    if not char then
        return nil
    end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool and isSwordTool(tool) then
        return tool
    end

    return nil
end

local function getHeldOrBackpackSword()
    local char = getCharacter(lplr)
    if char then
        local heldTool = char:FindFirstChildOfClass("Tool")
        if heldTool and isSwordTool(heldTool) then
            return heldTool
        end
    end

    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if not backpack then
        return nil
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and isSwordTool(tool) then
            return tool
        end
    end

    return nil
end

local function getKillAuraTarget(range, settings)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    if not myHRP then
        return nil
    end

    local bestTarget = nil
    local bestDistance = math.huge

    local function considerTarget(targetChar)
        if not targetChar then
            return
        end

        local hum = getHumanoid(targetChar)
        local root = getHRP(targetChar)
        if not hum or not root or hum.Health <= 0 then
            return
        end

        local distance = (root.Position - myHRP.Position).Magnitude
        if distance > range then
            return
        end

        if not isTargetWithinFov(targetChar, settings.fovRadius or settings.fov or 360) then
            return
        end

        if settings.attackThroughWalls == false and not hasLineOfSight(targetChar) then
            return
        end

        if distance < bestDistance then
            bestDistance = distance
            bestTarget = targetChar
        end
    end

    if settings.attackPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr then
                local sameTeam = player.Team ~= nil and lplr.Team ~= nil and player.Team == lplr.Team
                if not (settings.ignoreTeammates ~= false and sameTeam) then
                    considerTarget(getCharacter(player))
                end
            end
        end
    end

    if settings.attackNPCs then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model ~= myChar then
                local hum = model:FindFirstChildOfClass("Humanoid")
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local isPlayerModel = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then
                            isPlayerModel = true
                            break
                        end
                    end
                    if not isPlayerModel then
                        considerTarget(model)
                    end
                end
            end
        end
    end

    return bestTarget
end

local function toggleKillAura(enabled)
    cleanupModule("KillAura")
    if not enabled then
        return
    end

    local lockedTarget = nil
    local lastTargetSwitch = 0

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["KillAura"] then
            return
        end

        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myChar or not myHRP then
            return
        end

        local settings = moduleSettings["KillAura"] or {}
        if not settings.attackPlayers and not settings.attackNPCs then
            return
        end

        local sword = getHeldSword()
        if not sword then
            local backpackSword = getHeldOrBackpackSword()
            if backpackSword then
                equipToolIfNeeded(backpackSword)
                sword = getHeldSword()
            end
        end

        if settings.requireSword and not sword then
            return
        end

        local effectiveRange = getEffectiveCombatRange(settings.range or 14)

        local function isStillValidTarget(targetChar)
            if not targetChar then
                return false
            end

            local hum = getHumanoid(targetChar)
            local root = getHRP(targetChar)
            if not hum or not root or hum.Health <= 0 then
                return false
            end

            if (root.Position - myHRP.Position).Magnitude > effectiveRange then
                return false
            end

            if not isTargetWithinFov(targetChar, settings.fovRadius or settings.fov or 360) then
                return false
            end

            if settings.attackThroughWalls == false and not hasLineOfSight(targetChar) then
                return false
            end

            return true
        end

        if not isStillValidTarget(lockedTarget) then
            lockedTarget = nil
        end

        local now = tick()
        if not lockedTarget or (now - lastTargetSwitch >= (settings.targetSwitchDelay or 0.2)) then
            local newTarget = getKillAuraTarget(effectiveRange, settings)
            if newTarget ~= lockedTarget then
                lockedTarget = newTarget
                lastTargetSwitch = now
            end
        end

        if not lockedTarget then
            return
        end

        local swingDelay = 1 / math.max(settings.swingSpeed or 1, 1)
        if now - killAuraLastSwing < swingDelay then
            return
        end

        if settings.faceTarget then
            faceCharacterTarget(lockedTarget)
        end

        local attacked = attackTargetWithBedwarsApi(lockedTarget)

        if not attacked and sword then
            attacked = safeCall("KillAura_ToolActivate", function()
                sword:Activate()
                return true
            end) or false
        end

        if not attacked and settings.fallbackToClickSimulation then
            attacked = performPrimaryClick() or false
        end

        if attacked then
            killAuraLastSwing = now
        end
    end)

    addConnection("KillAura", connection)
end


moduleSettings["Reach"] = {
    mode = "Both",
    hitRange = 12,
    mineRange = 12,
    placeRange = 12
}

local function toggleReach(enabled)
    cleanupModule("Reach")

    local function resetToolReach(tool)
        local grip = tool:FindFirstChild("AetherOriginalGripPos")
        if grip then
            tool.GripPos = Vector3.new(grip.Value.X, grip.Value.Y, grip.Value.Z)
            grip:Destroy()
        end

        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            local originalSize = handle:FindFirstChild("AetherOriginalHandleSize")
            if originalSize then
                handle.Size = Vector3.new(originalSize.Value.X, originalSize.Value.Y, originalSize.Value.Z)
                originalSize:Destroy()
            end
            handle.Massless = false
            handle.CanCollide = true
            handle.Transparency = 0
        end
    end

    local function applyToolReach(tool, rangeAmount)
        if not tool:IsA("Tool") then
            return
        end
        if not tool:FindFirstChild("AetherOriginalGripPos") then
            local originalGripPos = Instance.new("Vector3Value")
            originalGripPos.Name = "AetherOriginalGripPos"
            originalGripPos.Value = tool.GripPos
            originalGripPos.Parent = tool
        end

        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            if not handle:FindFirstChild("AetherOriginalHandleSize") then
                local originalHandleSize = Instance.new("Vector3Value")
                originalHandleSize.Name = "AetherOriginalHandleSize"
                originalHandleSize.Value = handle.Size
                originalHandleSize.Parent = handle
            end
            handle.Size = Vector3.new(math.max(handle.Size.X, 2), math.max(handle.Size.Y, 2), math.max(rangeAmount, 4))
            handle.Massless = true
            handle.CanCollide = false
            handle.Transparency = 0.35
        end

        local gripExtension = -math.max(rangeAmount - 4, 0)
        tool.GripPos = Vector3.new(tool.GripPos.X, tool.GripPos.Y, gripExtension)
    end

    local function forEachTool(callback)
        local char = getCharacter(lplr)
        local backpack = lplr:FindFirstChildOfClass("Backpack")
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    callback(tool)
                end
            end
        end
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    callback(tool)
                end
            end
        end
    end

    if not enabled then
        forEachTool(function(tool)
            resetToolReach(tool)
        end)
        lplr:SetAttribute("Reach", nil)
        return
    end

    local function applyReach()
        local char = getCharacter(lplr)
        if not char then return end
        local settings = moduleSettings["Reach"]

        if settings.mode == "Attribute" or settings.mode == "Both" then
            lplr:SetAttribute("Reach", math.max(settings.hitRange, settings.mineRange, settings.placeRange))
        else
            lplr:SetAttribute("Reach", nil)
        end

        local maxRange = math.max(settings.hitRange, settings.mineRange, settings.placeRange)
        forEachTool(function(tool)
            if settings.mode == "Handle" or settings.mode == "Both" then
                applyToolReach(tool, maxRange)
            else
                resetToolReach(tool)
            end
        end)
    end

    applyReach()
    addConnection("Reach", lplr.CharacterAdded:Connect(applyReach))
    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if backpack then
        addConnection("Reach", backpack.ChildAdded:Connect(function()
            if moduleStates["Reach"] then
                task.wait()
                applyReach()
            end
        end))
    end
end


moduleSettings["Speed"] = { speed = 24 }

local function toggleSpeed(enabled)
    cleanupModule("Speed")
    if not enabled then
        local char = getCharacter(lplr)
        if char then
            local hum = getHumanoid(char)
            if hum then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
            end
        end
        return
    end

    local function applySpeed()
        local char = getCharacter(lplr)
        if not char then return end
        local hum = getHumanoid(char)
        if hum then
            hum.WalkSpeed = moduleSettings["Speed"].speed
            hum.JumpPower = 60
        end
    end

    applySpeed()
    addConnection("Speed", lplr.CharacterAdded:Connect(applySpeed))
    addConnection("Speed", RunService.Heartbeat:Connect(function()
        if not moduleStates["Speed"] then return end
        applySpeed()
    end))
end

moduleSettings["Step"] = {
    maxHeight = 6,
    forwardCheckDistance = 2.6
}

local function toggleStep(enabled)
    cleanupModule("Step")
    if not enabled then
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        if hum then
            hum.StepHeight = 2
        end
        return
    end

    addConnection("Step", RunService.Heartbeat:Connect(function()
        if not moduleStates["Step"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end

        local settings = moduleSettings["Step"]
        hum.StepHeight = math.clamp(settings.maxHeight or 6, 2, 14)
        if hum.MoveDirection.Magnitude < 0.05 then
            return
        end

        local moveDirection = hum.MoveDirection.Unit
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        rayParams.IgnoreWater = true

        local forwardDistance = math.clamp(settings.forwardCheckDistance or 2.6, 1.5, 5)
        local basePosition = hrp.Position
        local wallHit = Workspace:Raycast(basePosition + Vector3.new(0, 1.2, 0), moveDirection * forwardDistance, rayParams)
        if not wallHit then
            return
        end

        local maxHeight = math.clamp(settings.maxHeight or 6, 2, 14)
        local topCastOrigin = wallHit.Position + Vector3.new(0, maxHeight + 2.5, 0)
        local topHit = Workspace:Raycast(topCastOrigin, Vector3.new(0, -(maxHeight + 4.5), 0), rayParams)
        if not topHit then
            return
        end

        local targetY = topHit.Position.Y + 3
        local verticalDelta = targetY - hrp.Position.Y
        if verticalDelta > 0.6 and verticalDelta <= maxHeight + 0.5 then
            hrp.CFrame = CFrame.new(
                hrp.Position.X + (moveDirection.X * 1.2),
                targetY,
                hrp.Position.Z + (moveDirection.Z * 1.2)
            )
        end
    end))
end

moduleSettings["SafeWalk"] = {
    mode = "Normal",
    maxDrop = 4.5
}

local function toggleSafeWalk(enabled)
    cleanupModule("SafeWalk")
    if not enabled then return end

    local lastSafePosition
    local lastGroundedAt = 0

    addConnection("SafeWalk", RunService.Heartbeat:Connect(function()
        if not moduleStates["SafeWalk"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end

        local settings = moduleSettings["SafeWalk"]
        local moveDirection = hum.MoveDirection
        local horizontalSpeed = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
        if moveDirection.Magnitude < 0.02 and horizontalSpeed < 0.2 then
            return
        end

        local humanoidState = hum:GetState()
        local isAirborne = hum.FloorMaterial == Enum.Material.Air
            or humanoidState == Enum.HumanoidStateType.Freefall
            or humanoidState == Enum.HumanoidStateType.Jumping
        if isAirborne then
            return
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        rayParams.IgnoreWater = true

        local footRay = Workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rayParams)
        if footRay then
            lastSafePosition = hrp.Position
            lastGroundedAt = tick()
        end

        local probeDirection = moveDirection.Magnitude > 0 and moveDirection.Unit or Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
        local probeDistance = 1.9
        local probeOrigin = hrp.Position + (probeDirection * probeDistance)
        local edgeRay = Workspace:Raycast(probeOrigin + Vector3.new(0, 0.5, 0), Vector3.new(0, -math.max(settings.maxDrop or 4.5, 2), 0), rayParams)

        if edgeRay then
            return
        end

        if settings.mode == "Normal" then
            if lastSafePosition then
                hrp.CFrame = CFrame.new(lastSafePosition.X, hrp.Position.Y, lastSafePosition.Z)
                hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            end
        else
            local shouldRescue = tick() - lastGroundedAt > 0.05 or hrp.AssemblyLinearVelocity.Y < -8
            if shouldRescue and lastSafePosition then
                hrp.CFrame = CFrame.new(lastSafePosition + Vector3.new(0, 1.5, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end))
end

moduleSettings["HighJump"] = {
    boost = 40
}

local function toggleHighJump(enabled)
    cleanupModule("HighJump")
    if not enabled then
        return
    end

    local char = getCharacter(lplr)
    local hum = getHumanoid(char)
    local hrp = getHRP(char)
    if not hum or not hrp then
        setModuleEnabled("HighJump", false)
        return
    end

    local boost = math.clamp(moduleSettings["HighJump"].boost or 40, 10, 180)
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, boost, hrp.AssemblyLinearVelocity.Z)
    task.delay(0.08, function()
        setModuleEnabled("HighJump", false)
    end)
end


moduleSettings["Fly"] = {
    horizontalSpeed = 40,
    verticalSpeed = 40,
    tpDownEnabled = false,
    tpDownInterval = 2.5,
    tpDownLast = 0,
    tpDownAirStart = nil,
    tpDownReturnDelay = 0.2
}

local function toggleFly(enabled)
    cleanupModule("Fly")
    if not enabled then
        local char = getCharacter(lplr)
        if char then
            local hrp = getHRP(char)
            if hrp then
                local bv = hrp:FindFirstChild("FlyVelocity")
                if bv then bv:Destroy() end
            end
        end
        return
    end

    local function setupFly()
        local char = getCharacter(lplr)
        if not char then return end
        local hrp = getHRP(char)
        if not hrp then return end

        local bv = hrp:FindFirstChild("FlyVelocity") or Instance.new("BodyVelocity")
        bv.Name = "FlyVelocity"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp

        return bv
    end

    local flyConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not moduleStates["Fly"] then return end
        local bv = setupFly()
        if not bv then return end
        local settings = moduleSettings["Fly"]

        local moveDir = Vector3.zero


        local camLook = camera.CFrame.LookVector
        local camRight = camera.CFrame.RightVector
        local flatLookVec = Vector3.new(camLook.X, 0, camLook.Z)
        local flatRightVec = Vector3.new(camRight.X, 0, camRight.Z)
        local flatLook = flatLookVec.Magnitude > 0 and flatLookVec.Unit or Vector3.new(0, 0, -1)
        local flatRight = flatRightVec.Magnitude > 0 and flatRightVec.Unit or Vector3.new(1, 0, 0)

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += flatRight end


        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir += Vector3.new(0, 1, 0)
        elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir -= Vector3.new(0, 1, 0)
        end

        local horizontal = Vector3.new(moveDir.X, 0, moveDir.Z)
        if horizontal.Magnitude > 1 then
            horizontal = horizontal.Unit
        end

        if moveDir.Magnitude > 0 then
            local hSpeed = settings.horizontalSpeed
            local vSpeed = settings.verticalSpeed
            local vel = Vector3.new(horizontal.X, moveDir.Y, horizontal.Z)
            vel = Vector3.new(vel.X * hSpeed, vel.Y * vSpeed, vel.Z * hSpeed)
            bv.Velocity = vel
        else
            bv.Velocity = Vector3.zero
        end


        if settings.tpDownEnabled then
            local now = tick()
            local char = getCharacter(lplr)
            local hrp = getHRP(char)
            local hum = getHumanoid(char)
            local isAirborne = hum and (hum.FloorMaterial == Enum.Material.Air or hum:GetState() == Enum.HumanoidStateType.Freefall)
            if not isAirborne then
                settings.tpDownAirStart = nil
            end
            if hrp and isAirborne then
                settings.tpDownAirStart = settings.tpDownAirStart or now
            end
            if hrp and isAirborne and settings.tpDownAirStart and now - settings.tpDownAirStart >= settings.tpDownInterval then
                settings.tpDownLast = now
                settings.tpDownAirStart = now
                local airbornePosition = hrp.Position
                local rayOrigin = hrp.Position
                local rayDirection = Vector3.new(0, -120, 0)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {char}
                local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                if rayResult then
                    local targetPos = rayResult.Position + Vector3.new(0, 2.5, 0)
                    hrp.CFrame = CFrame.new(targetPos)
                    task.delay(settings.tpDownReturnDelay, function()
                        if moduleStates["Fly"] then
                            local liveChar = getCharacter(lplr)
                            local liveHrp = getHRP(liveChar)
                            if liveHrp then
                                liveHrp.CFrame = CFrame.new(airbornePosition)
                            end
                        end
                    end)
                end
            end
        end
    end)
    addConnection("Fly", flyConnection)
end

moduleSettings["VerticalFly"] = {
    horizontalSpeed = 28,
    verticalSpeed = 45,
    groundOffset = 3.2
}

local function toggleVerticalFly(enabled)
    cleanupModule("VerticalFly")
    local state = moduleSettings["VerticalFly"]

    local function resetCameraOffset()
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        if hum then
            hum.CameraOffset = Vector3.zero
        end
    end

    if not enabled then
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        resetCameraOffset()
        if hrp and state and state.lastVisualPosition then
            hrp.CFrame = CFrame.new(state.lastVisualPosition)
        end
        if hrp then
            local mover = hrp:FindFirstChild("VerticalFlyVelocity")
            if mover then mover:Destroy() end
        end
        return
    end

    local function ensureMover()
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if not hrp then return nil end
        local mover = hrp:FindFirstChild("VerticalFlyVelocity") or Instance.new("BodyVelocity")
        mover.Name = "VerticalFlyVelocity"
        mover.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        mover.Velocity = Vector3.zero
        mover.Parent = hrp
        return mover, hrp, char
    end

    addConnection("VerticalFly", RunService.Heartbeat:Connect(function(dt)
        if not moduleStates["VerticalFly"] then return end
        local mover, hrp, char = ensureMover()
        if not mover or not hrp then return end
        local settings = moduleSettings["VerticalFly"]
        settings.virtualAltitude = settings.virtualAltitude or 0

        local cameraLook = camera.CFrame.LookVector
        local cameraRight = camera.CFrame.RightVector
        local flatLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
        local flatRight = Vector3.new(cameraRight.X, 0, cameraRight.Z)
        flatLook = flatLook.Magnitude > 0 and flatLook.Unit or Vector3.new(0, 0, -1)
        flatRight = flatRight.Magnitude > 0 and flatRight.Unit or Vector3.new(1, 0, 0)

        local moveDirection = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection += flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection -= flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection -= flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection += flatRight end

        local planarMove = Vector3.new(moveDirection.X, 0, moveDirection.Z)
        if planarMove.Magnitude > 1 then
            planarMove = planarMove.Unit
        end

        local verticalInput = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            verticalInput += 1
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            verticalInput -= 1
        end

        settings.virtualAltitude = math.max(0, settings.virtualAltitude + (verticalInput * settings.verticalSpeed * dt))

        local currentGround = settings.lastGroundPosition or hrp.Position
        local desiredPlanar = currentGround + (planarMove * settings.horizontalSpeed * dt)
        local rayOrigin = Vector3.new(desiredPlanar.X, math.max(hrp.Position.Y, desiredPlanar.Y) + 900, desiredPlanar.Z)
        local groundHit = raycastToGround(rayOrigin, {char}, 1800)

        local groundY = groundHit and groundHit.Position.Y or currentGround.Y
        local groundedPosition = Vector3.new(desiredPlanar.X, groundY + settings.groundOffset, desiredPlanar.Z)
        local visualPosition = groundedPosition + Vector3.new(0, settings.virtualAltitude, 0)

        settings.lastGroundPosition = groundedPosition
        settings.lastVisualPosition = visualPosition

        local hum = getHumanoid(char)
        if hum then
            hum.CameraOffset = Vector3.new(0, math.clamp(settings.virtualAltitude, 0, 1500), 0)
        end

        local delta = groundedPosition - hrp.Position
        local smoothVelocity = delta * 14
        smoothVelocity = Vector3.new(
            math.clamp(smoothVelocity.X, -settings.horizontalSpeed, settings.horizontalSpeed),
            math.clamp(smoothVelocity.Y, -120, 120),
            math.clamp(smoothVelocity.Z, -settings.horizontalSpeed, settings.horizontalSpeed)
        )
        mover.Velocity = smoothVelocity
    end))
end

moduleSettings["AntiDeath"] = {
    healthThreshold = 25,
    belowDuration = 2,
    slowMode = 1.5,
    voidOffset = 130
}

local function toggleAntiDeath(enabled)
    cleanupModule("AntiDeath")
    if not enabled then
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if hrp then
            hrp.Anchored = false
        end
        return
    end

    local state = {
        phase = "up",
        phaseUntil = 0,
        anchorCFrame = nil,
        anchorFloorY = nil
    }

    local function floorSnap(origin, character, yOffset)
        local ray = raycastToGround(origin + Vector3.new(0, 80, 0), {character}, 420)
        if ray then
            return ray.Position + Vector3.new(0, yOffset or 3, 0), ray.Position.Y
        end
        local sampled = findNearestGroundPosition(origin, character, 14, 7, yOffset or 3)
        return sampled, sampled and (sampled.Y - (yOffset or 3)) or nil
    end

    addConnection("AntiDeath", RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiDeath"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end
        local settings = moduleSettings["AntiDeath"]
        local now = tick()
        local lowHealth = hum.Health <= settings.healthThreshold

        if not lowHealth then
            state.phase = "up"
            state.phaseUntil = 0
            state.anchorCFrame = nil
            hrp.Anchored = false
            return
        end

        if state.phaseUntil <= now then
            if state.phase == "up" then
                state.phase = "down"
                state.phaseUntil = now + settings.belowDuration
                state.anchorCFrame = hrp.CFrame
                local floorPosition, floorY = floorSnap(hrp.Position, char, 3)
                if floorPosition then
                    state.anchorCFrame = CFrame.new(floorPosition)
                end
                state.anchorFloorY = floorY
            else
                state.phase = "up"
                state.phaseUntil = now + settings.slowMode
            end
        end

        if state.phase == "down" then
            local anchor = state.anchorCFrame or hrp.CFrame
            hrp.Anchored = true
            local floorY = state.anchorFloorY or (anchor.Position.Y - 3)
            hrp.CFrame = CFrame.new(anchor.Position.X, floorY - settings.voidOffset, anchor.Position.Z)
            hrp.AssemblyLinearVelocity = Vector3.zero
        else
            hrp.Anchored = false
            if state.anchorCFrame then
                local anchorPosition = state.anchorCFrame.Position
                local floorPosition = floorSnap(anchorPosition, char, 3)
                hrp.CFrame = CFrame.new(floorPosition or anchorPosition)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end))
end

moduleSettings["FastBreak"] = {
    cooldown = 0.03,
    attemptsPerPulse = 2
}

local function toggleFastBreak(enabled)
    cleanupModule("FastBreak")
    if not enabled then return end

    moduleSettings["FastBreak"].lastBreak = 0
    moduleSettings["FastBreak"].cachedController = getBlockPlacementController()
    addConnection("FastBreak", RunService.Heartbeat:Connect(function()
        if not moduleStates["FastBreak"] then return end
        local settings = moduleSettings["FastBreak"]
        local now = tick()
        if now - (settings.lastBreak or 0) < settings.cooldown then return end
        local target = mouse and mouse.Target
        if not target or not target:IsA("BasePart") then return end
        settings.lastBreak = now

        local targetPosition = target.Position
        local blockController = settings.cachedController or getBlockPlacementController()
        settings.cachedController = blockController
        local damageRemote = getDamageBlockRemote()

        for _ = 1, settings.attemptsPerPulse do
            if blockController then
                for _, methodName in ipairs({"breakBlock", "BreakBlock", "breakBlockAt", "damageBlock"}) do
                    local method = blockController[methodName]
                    if type(method) == "function" then
                        safeCall("FastBreakController_" .. methodName, function()
                            method(blockController, targetPosition)
                        end)
                    end
                end
            end
            if damageRemote then
                safeCall("FastBreakDamageRemote", function()
                    damageRemote:FireServer({
                        blockRef = {blockPosition = targetPosition},
                        hitPosition = targetPosition,
                        hitNormal = Vector3.new(0, 1, 0)
                    })
                end)
            end
            performPrimaryClick()
        end
    end))
end

moduleSettings["AutoVoidDrop"] = {
    triggerOffset = 18,
    dropInterval = 0.45
}

local function toggleAutoVoidDrop(enabled)
    cleanupModule("AutoVoidDrop")
    if not enabled then return end

    moduleSettings["AutoVoidDrop"].lastDrop = 0
    moduleSettings["AutoVoidDrop"].dropRemote = getDropItemRemote()
    addConnection("AutoVoidDrop", RunService.Heartbeat:Connect(function()
        if not moduleStates["AutoVoidDrop"] then return end
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if not hrp then return end
        local settings = moduleSettings["AutoVoidDrop"]
        local now = tick()
        if now - (settings.lastDrop or 0) < settings.dropInterval then return end

        local nearbyGround = findNearestGroundPosition(hrp.Position, char, 10, 10, 0)
        if nearbyGround and hrp.Position.Y > nearbyGround.Y - settings.triggerOffset then
            return
        end
        if hrp.AssemblyLinearVelocity.Y > -8 then
            return
        end

        local dropRemote = settings.dropRemote or getDropItemRemote()
        settings.dropRemote = dropRemote
        if not dropRemote then return end

        local dropTargets = {"diamond", "iron", "emerald", "gold"}
        local dropTool = getHeldOrBackpackVoidDropTool()
        if dropTool then
            table.insert(dropTargets, dropTool.Name)
            equipToolIfNeeded(dropTool)
        end

        for _, resourceName in ipairs(dropTargets) do
            pcall(function()
                dropRemote:FireServer({item = resourceName, amount = 999})
            end)
            pcall(function()
                dropRemote:FireServer(resourceName)
            end)
        end
        settings.lastDrop = now
    end))
end


local function toggleESP(enabled)
    cleanupModule("ESP")
    if not enabled then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "ESP_Highlight" then
                obj:Destroy()
            end
        end
        return
    end

    local function removeESPFromModel(model)
        if not model then return end
        local old = model:FindFirstChild("ESP_Highlight")
        if old then
            old:Destroy()
        end
    end

    local function shouldHighlightModel(model)
        if not model then
            return false
        end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            return false
        end
        return true
    end

    local function addESPtoModel(model)
        if not shouldHighlightModel(model) then
            removeESPFromModel(model)
            return
        end
        if model:FindFirstChild("ESP_Highlight") then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = model
        highlight.Parent = model
    end

    local function scanAndAddESP()
        if not moduleStates["ESP"] then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                addESPtoModel(player.Character)
            end
        end

        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local isPlayerChar = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then isPlayerChar = true break end
                    end
                    if not isPlayerChar then
                        addESPtoModel(model)
                    end
                else
                    removeESPFromModel(model)
                end
            end
        end
    end

    scanAndAddESP()
    addConnection("ESP", Players.PlayerAdded:Connect(function(player)
        addConnection("ESP", player.CharacterAdded:Connect(function(character)
            if moduleStates["ESP"] then
                addESPtoModel(character)
            end
        end))
    end))
    addConnection("ESP", Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            removeESPFromModel(player.Character)
        end
    end))
    local lastScan = 0
    addConnection("ESP", RunService.Heartbeat:Connect(function()
        if tick() - lastScan < 0.45 then return end
        lastScan = tick()
        scanAndAddESP()
    end))
end


moduleSettings["Tracers"] = { transparency = 0.5 }

local function clearTracerArtifacts()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Beam") and obj.Name == "TracerBeam" then
            obj:Destroy()
        elseif obj:IsA("Attachment") and (obj.Name == "TracerAttach0" or obj.Name == "TracerAttach1") then
            obj:Destroy()
        elseif obj:IsA("Part") and obj.Name == "TracerAnchorPart" then
            obj:Destroy()
        end
    end
end

local function toggleTracers(enabled)
    cleanupModule("Tracers")
    if not enabled then
        clearTracerArtifacts()
        return
    end
    clearTracerArtifacts()

    local function createTracerForModel(model)
        if not model or model:FindFirstChild("TracerBeam") then return end
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if not head then return end

        local anchorPart = Instance.new("Part")
        anchorPart.Name = "TracerAnchorPart"
        anchorPart.Size = Vector3.new(0.2, 0.2, 0.2)
        anchorPart.Transparency = 1
        anchorPart.Anchored = true
        anchorPart.CanCollide = false
        anchorPart.CanQuery = false
        anchorPart.CanTouch = false
        anchorPart.CFrame = camera.CFrame
        anchorPart.Parent = Workspace

        local attach0 = Instance.new("Attachment")
        attach0.Name = "TracerAttach0"
        attach0.Parent = anchorPart

        local attach1 = Instance.new("Attachment")
        attach1.Name = "TracerAttach1"
        attach1.Parent = head

        local beam = Instance.new("Beam")
        beam.Name = "TracerBeam"
        beam.Attachment0 = attach0
        beam.Attachment1 = attach1
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        beam.Transparency = NumberSequence.new(moduleSettings["Tracers"].transparency)
        beam.Width0 = 0.1
        beam.Width1 = 0.1
        beam.Parent = model

        local updateConn = RunService.RenderStepped:Connect(function()
            if not moduleStates["Tracers"] then return end
            if not attach0 or not attach0.Parent then return end
            if not camera then return end
            anchorPart.CFrame = camera.CFrame
            beam.Transparency = NumberSequence.new(moduleSettings["Tracers"].transparency)
        end)
        addConnection("Tracers", updateConn)
    end

    local function scanAndAddTracers()
        if not moduleStates["Tracers"] then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                createTracerForModel(player.Character)
            end
        end
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local isPlayerChar = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then isPlayerChar = true break end
                    end
                    if not isPlayerChar then
                        createTracerForModel(model)
                    end
                end
            end
        end
    end

    scanAndAddTracers()
    local lastScan = 0
    addConnection("Tracers", RunService.Heartbeat:Connect(function()
        if tick() - lastScan < 0.45 then return end
        lastScan = tick()
        scanAndAddTracers()
    end))
end


moduleSettings["AutoToxic"] = {
    finalKillMessage = "ez final kill",
    bedBreakMessage = "bed gone lol",
    gameWinMessage = "gg ez",
    enabledFinalKill = true,
    enabledBedBreak = true,
    enabledGameWin = true
}

local function setupAutoToxic()
    local sharedEnvironment = sharedEnvironmentGetter and sharedEnvironmentGetter() or nil
    local existingConnection = sharedEnvironment and sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY]
    if existingConnection then
        pcall(function()
            existingConnection:Disconnect()
        end)
        sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] = nil
    end

    if autoToxicMessageConnection then
        autoToxicMessageConnection:Disconnect()
        autoToxicMessageConnection = nil
    end

    local lastMessageTime = 0
    local function sendToxicMessage(kind)
        if not autoToxicEnabled then
            return
        end
        if tick() - lastMessageTime < 1.5 then
            return
        end
        local settings = moduleSettings["AutoToxic"]
        if kind == "final" and settings.enabledFinalKill then
            sayInChat(settings.finalKillMessage)
            lastMessageTime = tick()
        elseif kind == "bed" and settings.enabledBedBreak then
            sayInChat(settings.bedBreakMessage)
            lastMessageTime = tick()
        elseif kind == "win" and settings.enabledGameWin then
            sayInChat(settings.gameWinMessage)
            lastMessageTime = tick()
        end
    end

    if TextChatService and TextChatService.MessageReceived then
        autoToxicMessageConnection = TextChatService.MessageReceived:Connect(function(message)
            local text = (message.Text or ""):lower()
            local me = lplr.Name:lower()
            if text:find(me) and text:find("final kill") then
                sendToxicMessage("final")
            elseif text:find(me) and text:find("bed") and (text:find("break") or text:find("destroy")) then
                sendToxicMessage("bed")
            elseif text:find("victory") or text:find("you win") then
                sendToxicMessage("win")
            end
        end)
        if sharedEnvironment then
            sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] = autoToxicMessageConnection
        end
    end
end
setupAutoToxic()


moduleSettings["Nuker"] = {
    mineBeds = true,
    mineIron = true,
    mineGold = true,
    mineDiamond = true,
    mineEmerald = true,
    mineRadius = 10
}

local function toggleNuker(enabled)
    cleanupModule("Nuker")
    if not enabled then return end

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["Nuker"] then return end
        local settings = moduleSettings["Nuker"]
        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myHRP then return end

        moduleSettings["Nuker"].lastScan = moduleSettings["Nuker"].lastScan or 0
        if tick() - moduleSettings["Nuker"].lastScan < 0.3 then return end
        moduleSettings["Nuker"].lastScan = tick()

        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {myChar}
        local nearbyParts = Workspace:GetPartBoundsInRadius(myHRP.Position, settings.mineRadius, overlapParams)

        for _, obj in ipairs(nearbyParts) do
            if obj:IsA("BasePart") then
                local shouldMine = false
                local nameLower = obj.Name:lower()
                if settings.mineBeds and nameLower == "bed" and obj.Parent and obj.Parent.Name ~= lplr.Name then
                    shouldMine = true
                elseif settings.mineIron and nameLower:find("iron") then
                    shouldMine = true
                elseif settings.mineGold and nameLower:find("gold") then
                    shouldMine = true
                elseif settings.mineDiamond and nameLower:find("diamond") then
                    shouldMine = true
                elseif settings.mineEmerald and nameLower:find("emerald") then
                    shouldMine = true
                end

                if shouldMine then
                    local tool = myChar:FindFirstChildOfClass("Tool")
                    if tool then
                        safeCall("NukerActivateTool", function()
                            tool:Activate()
                        end)
                        performPrimaryClick()
                    end
                end
            end
        end
    end)
    addConnection("Nuker", connection)
end


moduleSettings["Scaffold"] = {
    allowTowering = true
}

local function getTeamWoolName()
    local team = lplr.Team
    if not team then return "wool_white" end
    local teamName = team.Name:lower()
    if teamName:find("blue") then return "wool_blue"
    elseif teamName:find("red") then return "wool_red"
    elseif teamName:find("green") then return "wool_green"
    elseif teamName:find("yellow") then return "wool_yellow"
    elseif teamName:find("aqua") then return "wool_cyan"
    elseif teamName:find("pink") then return "wool_pink"
    elseif teamName:find("gray") then return "wool_gray"
    elseif teamName:find("white") then return "wool_white"
    else return "wool_white" end
end

local function toggleScaffold(enabled)
    cleanupModule("Scaffold")
    if not enabled then return end

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["Scaffold"] then return end
        local myChar = getCharacter(lplr)
        local hrp = getHRP(myChar)
        if not hrp then return end

        local woolName = getTeamWoolName()
        local blockTool = getHeldOrBackpackBlockTool()
        if not blockTool then
            return
        end
        if blockTool.Parent ~= myChar then
            equipToolIfNeeded(blockTool)
        end

        local downParams = RaycastParams.new()
        downParams.FilterType = Enum.RaycastFilterType.Exclude
        downParams.FilterDescendantsInstances = {myChar}
        downParams.IgnoreWater = true
        local downRay = Workspace:Raycast(hrp.Position, Vector3.new(0, -4.5, 0), downParams)
        if downRay and (hrp.Position.Y - downRay.Position.Y) <= 3.2 then
            return
        end

        local basePos = hrp.Position - Vector3.new(0, 3, 0)
        local function snapToGrid(position)
            local blockSize = 3
            local function snap(value)
                return math.floor((value / blockSize) + 0.5) * blockSize
            end
            return Vector3.new(snap(position.X), snap(position.Y), snap(position.Z))
        end
        local placePos = snapToGrid(basePos)


        if moduleSettings["Scaffold"].allowTowering then
            local hum = getHumanoid(myChar)
            if hum and hum:GetState() == Enum.HumanoidStateType.Jumping then
                placePos = snapToGrid(hrp.Position - Vector3.new(0, 0.5, 0))
            end
        end


        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {myChar}
        local parts = Workspace:GetPartBoundsInBox(CFrame.new(placePos), Vector3.new(2, 2, 2), overlapParams)
        local blockExists = false
        for _, part in ipairs(parts) do
            if part:IsA("BasePart") and not part.Parent:IsA("Model") then
                blockExists = true
                break
            end
        end
        if blockExists then return end

        local blockController = getBlockPlacementController()
        if blockController then
            local didPlace = false
            for _, fnName in ipairs({"placeBlock", "PlaceBlock", "placeBlockAt", "placeBlockRequest"}) do
                local fn = blockController[fnName]
                if type(fn) == "function" then
                    safeCall("Scaffold_" .. fnName .. "_CFrame", function()
                        fn(blockController, CFrame.new(placePos))
                        didPlace = true
                    end)
                    safeCall("Scaffold_" .. fnName .. "_Vector3", function()
                        fn(blockController, placePos)
                        didPlace = true
                    end)
                    safeCall("Scaffold_" .. fnName .. "_ItemAndCFrame", function()
                        fn(blockController, blockTool.Name or woolName, CFrame.new(placePos))
                        didPlace = true
                    end)
                end
            end
            if didPlace then
                performPrimaryClick()
                return
            end
        end

        if BedwarsShopController then
            safeCall("ScaffoldShopFallback", function()
                local shopController = require(BedwarsShopController)
                local blockItem = shopController.GetItem and shopController:GetItem(woolName)
                if blockItem and shopController.PlaceBlock then
                    shopController:PlaceBlock(blockItem, CFrame.new(placePos))
                    performPrimaryClick()
                end
            end)
        else

            local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
            if remotes then
                for _, remote in ipairs(remotes:GetDescendants()) do
                    if remote:IsA("RemoteEvent") and remote.Name:lower():find("place") and remote.Name:lower():find("block") then
                        safeCall("ScaffoldRemoteTable", function()
                            remote:FireServer({
                                position = placePos,
                                blockType = blockTool.Name or woolName
                            })
                            performPrimaryClick()
                        end)
                        safeCall("ScaffoldRemoteArgs", function()
                            remote:FireServer(placePos, blockTool.Name or woolName)
                            performPrimaryClick()
                        end)
                    end
                end
            end
        end
    end)
    addConnection("Scaffold", connection)
end


moduleSettings["Aimbot"] = {
    enabled = true,
    fov = 160,
    smoothness = 0.55,
    wallCheck = true,
    teamCheck = true,
    targetPart = "Head",
    maxDistance = 260,
    targetNPCs = true,
    predictionStrength = 1,
    arrowSpeed = 185,
    gravity = Workspace.Gravity
}

local function getAimbotTargetPart(character, requestedPart)
    if not character then
        return nil
    end
    if requestedPart == "Head" then
        return character:FindFirstChild("Head") or getHRP(character)
    end
    if requestedPart == "HumanoidRootPart" then
        return getHRP(character) or character:FindFirstChild("Head")
    end
    return character:FindFirstChild(requestedPart) or character:FindFirstChild("Head") or getHRP(character)
end

local function getProjectileVelocityEstimate(targetCharacter)
    local hrp = getHRP(targetCharacter)
    if not hrp then
        return Vector3.zero
    end
    local velocity = hrp.AssemblyLinearVelocity
    local hum = getHumanoid(targetCharacter)
    if hum then
        velocity += hum.MoveDirection * hum.WalkSpeed
    end
    return velocity
end

local function solveProjectileLead(origin, targetPosition, targetVelocity, projectileSpeed, gravity, predictionStrength)
    projectileSpeed = math.max(projectileSpeed or 185, 1)
    local gravityVector = Vector3.new(0, -(gravity or Workspace.Gravity), 0)
    local estimatedTime = math.clamp((targetPosition - origin).Magnitude / projectileSpeed, 0.05, 4)
    local strength = math.clamp(predictionStrength or 1, 0, 2)

    for _ = 1, 4 do
        local futurePosition = targetPosition + (targetVelocity * estimatedTime * strength)
        local displacement = futurePosition - origin
        estimatedTime = math.clamp(displacement.Magnitude / projectileSpeed, 0.05, 4)
    end

    local finalFuture = targetPosition + (targetVelocity * estimatedTime * strength)
    local gravityCompensation = gravityVector * (0.5 * estimatedTime * estimatedTime)
    return finalFuture - gravityCompensation
end

local function isVisibleForAimbot(targetCharacter, requestedPart)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    local targetPart = getAimbotTargetPart(targetCharacter, requestedPart)
    if not myHRP or not targetPart then
        return false
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {myChar}
    rayParams.IgnoreWater = true

    local direction = targetPart.Position - myHRP.Position
    local raycastResult = Workspace:Raycast(myHRP.Position, direction, rayParams)
    if not raycastResult then
        return true
    end
    return raycastResult.Instance and raycastResult.Instance:IsDescendantOf(targetCharacter)
end

local function getAimbotCandidates(includeNPCs)
    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lplr then
            table.insert(candidates, {
                player = player,
                character = getCharacter(player)
            })
        end
    end

    if includeNPCs then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and not isPlayerCharacterModel(model) then
                table.insert(candidates, {
                    player = nil,
                    character = model
                })
            end
        end
    end

    return candidates
end

local function toggleAimbot(enabled)
    cleanupModule("Aimbot")
    if not enabled then return end

    addConnection("Aimbot", RunService.RenderStepped:Connect(function(deltaTime)
        if not moduleStates["Aimbot"] then return end
        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myChar or not myHRP then return end
        local settings = moduleSettings["Aimbot"]

        local bestCharacter
        local bestScreenDistance = math.huge
        local viewportCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

        for _, entry in ipairs(getAimbotCandidates(settings.targetNPCs ~= false)) do
            local player = entry.player
            local character = entry.character
            if player and settings.teamCheck and arePlayersTeammates(lplr, player) then
                continue
            end
            local hum = getHumanoid(character)
            local targetPart = getAimbotTargetPart(character, settings.targetPart)
            if hum and hum.Health > 0 and targetPart then
                local distance = (targetPart.Position - myHRP.Position).Magnitude
                if distance <= (settings.maxDistance or 260) then
                    if not settings.wallCheck or isVisibleForAimbot(character, settings.targetPart) then
                        local screenPosition, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local pixelDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - viewportCenter).Magnitude
                            if pixelDistance <= (settings.fov or 160) and pixelDistance < bestScreenDistance then
                                bestCharacter = character
                                bestScreenDistance = pixelDistance
                            end
                        end
                    end
                end
            end
        end

        if not bestCharacter then
            return
        end

        local targetPart = getAimbotTargetPart(bestCharacter, settings.targetPart)
        if not targetPart then
            return
        end
        local targetVelocity = getProjectileVelocityEstimate(bestCharacter)
        local predictedPosition = solveProjectileLead(
            camera.CFrame.Position,
            targetPart.Position,
            targetVelocity,
            settings.arrowSpeed,
            settings.gravity,
            settings.predictionStrength
        )

        local desiredDirection = (predictedPosition - camera.CFrame.Position)
        if desiredDirection.Magnitude <= 0.01 then
            return
        end
        desiredDirection = desiredDirection.Unit

        local lookAtCFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + desiredDirection)
        local smoothness = math.clamp(settings.smoothness or 0.55, 0.01, 1)
        local alpha = math.clamp((smoothness * 1.35) * (deltaTime * 60), 0.06, 1)
        camera.CFrame = camera.CFrame:Lerp(lookAtCFrame, alpha)
    end))
end

moduleSettings["AimAssist"] = {
    speed = 0.1,
    range = 30
}

local function toggleAimAssist(enabled)
    cleanupModule("AimAssist")
    if not enabled then return end
    if not mouseMoveRelative then
        warn("[AetherCore][AimAssist] mousemoverel is unavailable in this executor.")
        return
    end

    local connection = RunService.RenderStepped:Connect(function(deltaTime)
        if not moduleStates["AimAssist"] then return end
        local settings = moduleSettings["AimAssist"]
        local nearest = getNearestEnemy(settings.range, true)
        if not nearest then return end
        local head = nearest:FindFirstChild("Head")
        if not head then return end

        local screenPos, onScreen = camera:WorldToScreenPoint(head.Position)
        if not onScreen then return end

        local targetPos = Vector2.new(screenPos.X, screenPos.Y)
        local mousePos = Vector2.new(mouse.X, mouse.Y)
        local smoothing = math.clamp(settings.speed * deltaTime * 60, 0.01, 1)
        local delta = (targetPos - mousePos) * smoothing
        mouseMoveRelative(delta.X, delta.Y)
    end)
    addConnection("AimAssist", connection)
end


moduleSettings["AutoClicker"] = { cps = 10 }

local function toggleAutoClicker(enabled)
    cleanupModule("AutoClicker")
    if not enabled then return end

    local holding = false
    local lastClick = 0

    local conn1 = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = true
        end
    end)
    local conn2 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = false
        end
    end)
    local conn3 = RunService.Heartbeat:Connect(function()
        if holding and moduleStates["AutoClicker"] then
            local now = tick()
            local delay = 1 / math.clamp(moduleSettings["AutoClicker"].cps, 1, 20)
            if now - lastClick >= delay then
                lastClick = now
                performPrimaryClick()
                local nearest = getTargetByFilters(18, true, false)
                if nearest then
                    attackTargetWithBedwarsApi(nearest)
                end
                local char = getCharacter(lplr)
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then
                    pcall(function() tool:Activate() end)
                end
            end
        end
    end)

    addConnection("AutoClicker", conn1)
    addConnection("AutoClicker", conn2)
    addConnection("AutoClicker", conn3)
end


moduleSettings["Velocity"] = {
    horizontalReduction = 100,
    verticalReduction = 100
}

local function toggleVelocity(enabled)
    cleanupModule("Velocity")
    if not enabled then return end

    local function applyVelocity(char)
        local hum = char:WaitForChild("Humanoid")
        local root = char:WaitForChild("HumanoidRootPart")
        local recentlyDamagedUntil = 0
        local lastHealth = hum.Health

        addConnection("Velocity", hum.HealthChanged:Connect(function(newHealth)
            if newHealth < lastHealth then
                recentlyDamagedUntil = tick() + 0.35
            end
            lastHealth = newHealth
        end))

        addConnection("Velocity", RunService.Heartbeat:Connect(function()
            if not moduleStates["Velocity"] or not root.Parent then return end
            if tick() > recentlyDamagedUntil then return end
            local settings = moduleSettings["Velocity"]
            local horizontalReduction = math.clamp(settings.horizontalReduction / 100, 0, 1)
            local verticalReduction = math.clamp(settings.verticalReduction / 100, 0, 1)
            local current = root.AssemblyLinearVelocity
            local moveDirection = hum.MoveDirection
            local baseHorizontal = moveDirection.Magnitude > 0 and moveDirection.Unit * hum.WalkSpeed or Vector3.zero
            local currentHorizontal = Vector3.new(current.X, 0, current.Z)
            local knockbackHorizontal = currentHorizontal - Vector3.new(baseHorizontal.X, 0, baseHorizontal.Z)
            local reducedHorizontal = knockbackHorizontal * (1 - horizontalReduction)
            local targetHorizontal = Vector3.new(baseHorizontal.X, 0, baseHorizontal.Z) + reducedHorizontal
            root.AssemblyLinearVelocity = Vector3.new(
                targetHorizontal.X,
                current.Y * (1 - verticalReduction),
                targetHorizontal.Z
            )
        end))
    end

    if lplr.Character then applyVelocity(lplr.Character) end
    addConnection("Velocity", lplr.CharacterAdded:Connect(applyVelocity))
end


moduleSettings["LongJump"] = { speed = 110, duration = 2 }

local function toggleLongJump(enabled)
    cleanupModule("LongJump")
    if not enabled then
        local char = getCharacter(lplr)
        if char then
            local hum = getHumanoid(char)
            local hrp = getHRP(char)
            if hum then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
            end
            if hrp then
                local bv = hrp:FindFirstChild("LongJumpVelocity")
                if bv then bv:Destroy() end
                hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            end
        end
        return
    end

    local function setupLongJump()
        local char = getCharacter(lplr)
        if not char then return end
        local hrp = getHRP(char)
        if not hrp then return end

        local bv = hrp:FindFirstChild("LongJumpVelocity") or Instance.new("BodyVelocity")
        bv.Name = "LongJumpVelocity"
        bv.MaxForce = Vector3.new(1e5, 0, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp
        return bv
    end

    local originalMovement = {walkSpeed = nil, jumpPower = nil}
    local boostUntil = 0
    local lastDaoActivation = 0

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["LongJump"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not char or not hum or not hrp then return end

        if not originalMovement.walkSpeed then
            originalMovement.walkSpeed = hum.WalkSpeed
            originalMovement.jumpPower = hum.JumpPower
        end

        local heldTool = char:FindFirstChildOfClass("Tool")
        if not isDaoTool(heldTool) then
            local daoTool = getHeldOrBackpackDaoTool()
            if not daoTool then
                daoTool = getHeldOrBackpackToolByKeywords({"dash", "jump", "leap"})
            end
            if daoTool and daoTool.Parent ~= char then
                hum:EquipTool(daoTool)
                heldTool = daoTool
            end
        end
        local isHoldingDao = isDaoTool(heldTool)
        if not isHoldingDao then
            hum.WalkSpeed = originalMovement.walkSpeed or hum.WalkSpeed
            hum.JumpPower = originalMovement.jumpPower or hum.JumpPower
            local waitingBv = hrp:FindFirstChild("LongJumpVelocity")
            if waitingBv then
                waitingBv.Velocity = Vector3.zero
            end
            boostUntil = 0
            return
        end

        hum.WalkSpeed = originalMovement.walkSpeed
        hum.JumpPower = originalMovement.jumpPower

        local bv = setupLongJump()
        if not bv then return end

        if boostUntil <= tick() then
            if tick() - lastDaoActivation > 0.2 then
                useDaoAbility()
                lastDaoActivation = tick()
            end
            boostUntil = tick() + moduleSettings["LongJump"].duration
        end

        if boostUntil > tick() then
            local moveDirection = hum.MoveDirection
            local forward = moveDirection.Magnitude > 0 and moveDirection or Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
            if forward.Magnitude <= 0 then
                forward = Vector3.new(0, 0, -1)
            else
                forward = forward.Unit
            end
            bv.Velocity = forward * moduleSettings["LongJump"].speed
        else
            bv.Velocity = Vector3.zero
        end
    end)
    addConnection("LongJump", connection)
end


moduleSettings["NoFallDamage"] = {
    method = "Landing"
}

local function toggleNoFallDamage(enabled)
    cleanupModule("NoFallDamage")
    if not enabled then return end

    local function applyNoFall(char)
        local hum = char:WaitForChild("Humanoid")
        if moduleSettings["NoFallDamage"].method == "Landing" then
            local conn = hum.StateChanged:Connect(function(old, new)
                if new == Enum.HumanoidStateType.Freefall then
                    task.delay(0.1, function()
                        local hrp = getHRP(char)
                        if moduleStates["NoFallDamage"] and hum.Parent and hrp then
                            local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -8, 0))
                            if ray then
                                hum:ChangeState(Enum.HumanoidStateType.Landed)
                            end
                        end
                    end)
                end
            end)
            addConnection("NoFallDamage", conn)
        elseif moduleSettings["NoFallDamage"].method == "NegateVelocity" then
            local conn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP(char)
                if hrp and hrp.AssemblyLinearVelocity.Y < -35 then
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -2, hrp.AssemblyLinearVelocity.Z)
                end
            end)
            addConnection("NoFallDamage", conn)
        elseif moduleSettings["NoFallDamage"].method == "Teleport" then
            local conn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP(char)
                if hrp and hrp.AssemblyLinearVelocity.Y < -65 then
                    local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -25, 0))
                    if ray then
                        hrp.CFrame = CFrame.new(hrp.Position.X, ray.Position.Y + 4, hrp.Position.Z)
                    else
                        hrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
                    end
                end
            end)
            addConnection("NoFallDamage", conn)
        elseif moduleSettings["NoFallDamage"].method == "DaoExploit" then
            local daoCooldown = 0
            local charging = false
            local conn = RunService.Heartbeat:Connect(function()
                local hrp = getHRP(char)
                if not hrp then return end

                local velocityY = hrp.AssemblyLinearVelocity.Y
                local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -30, 0))
                local groundDistance = ray and (hrp.Position.Y - ray.Position.Y) or math.huge
                local dao = getHeldOrBackpackDaoTool()

                if velocityY < -30 and groundDistance > 10 and tick() > daoCooldown and dao and not charging then
                    local activated = useDaoAbility()
                    if activated then
                        charging = true
                    end
                end

                if charging and (groundDistance < 8 or velocityY > -5) then
                    local held = char:FindFirstChildOfClass("Tool")
                    if held and isDaoTool(held) then
                        pcall(function()
                            held:Deactivate()
                        end)
                    end
                    charging = false
                    daoCooldown = tick() + 0.45
                end
            end)
            addConnection("NoFallDamage", conn)
        end
    end

    if lplr.Character then
        applyNoFall(lplr.Character)
    end
    addConnection("NoFallDamage", lplr.CharacterAdded:Connect(applyNoFall))
end


moduleSettings["AntiVoid"] = {
    method = "Normal",
    bouncePower = 100
}

local function createAntiVoidVisual()
    local indicator = Instance.new("Part")
    indicator.Name = "AntiVoidIndicator"
    indicator.Anchored = true
    indicator.CanCollide = false
    indicator.Size = Vector3.new(10, 0.5, 10)
    indicator.Material = Enum.Material.Neon
    indicator.BrickColor = BrickColor.new("Bright red")
    indicator.Transparency = 0.5
    indicator.Parent = Workspace
    return indicator
end

local function toggleAntiVoid(enabled)
    cleanupModule("AntiVoid")
    if not enabled then
        local indicator = Workspace:FindFirstChild("AntiVoidIndicator")
        if indicator then indicator:Destroy() end
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if hrp then
            local existingPull = hrp:FindFirstChild("AntiVoidPull")
            if existingPull then existingPull:Destroy() end
        end
        return
    end

    local indicator = createAntiVoidVisual()
    local pullVelocity = nil
    local rescueTarget = nil
    local voidTriggerY = nil
    local lastRescueUpdate = 0

    local function refreshVoidReference()
        local myChar = getCharacter(lplr)
        local hrp = getHRP(myChar)
        if not myChar or not hrp then
            return
        end
        local groundPos = findNearestGroundPosition(hrp.Position, myChar, 12, 6, 0)
        local referenceY = groundPos and groundPos.Y or hrp.Position.Y
        voidTriggerY = referenceY - 38
    end

    local function findRescueTarget(origin, character)
        local best = nil
        local bestScore = math.huge
        for radius = 12, 96, 12 do
            local candidate = findNearestGroundPosition(origin, character, radius, 6, 3)
            if candidate then
                local planarDistance = (Vector3.new(origin.X, 0, origin.Z) - Vector3.new(candidate.X, 0, candidate.Z)).Magnitude
                local heightPenalty = math.max(0, origin.Y - candidate.Y)
                local score = planarDistance + (heightPenalty * 0.25)
                if score < bestScore then
                    bestScore = score
                    best = candidate
                end
            end
        end
        return best
    end

    refreshVoidReference()
    addConnection("AntiVoid", lplr.CharacterAdded:Connect(function()
        task.wait(0.2)
        local existingIndicator = Workspace:FindFirstChild("AntiVoidIndicator")
        if not existingIndicator then
            indicator = createAntiVoidVisual()
        end
        refreshVoidReference()
    end))

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiVoid"] then return end
        local myChar = getCharacter(lplr)
        local hrp = getHRP(myChar)
        if not hrp then return end
        if not voidTriggerY then
            refreshVoidReference()
        end
        if not voidTriggerY then return end
        indicator.Position = Vector3.new(hrp.Position.X, voidTriggerY, hrp.Position.Z)

        if hrp.Position.Y <= voidTriggerY then
            local method = moduleSettings["AntiVoid"].method
            if method == "Normal" then
                if not rescueTarget or tick() - lastRescueUpdate > 0.4 then
                    rescueTarget = findRescueTarget(hrp.Position, myChar)
                    lastRescueUpdate = tick()
                end
                if rescueTarget then
                    hrp.CFrame = CFrame.new(rescueTarget + Vector3.new(0, 2, 0))
                    if pullVelocity then
                        pullVelocity:Destroy()
                    end
                    pullVelocity = Instance.new("BodyVelocity")
                    pullVelocity.Name = "AntiVoidPull"
                    pullVelocity.MaxForce = Vector3.new(2e5, 9e4, 2e5)
                    pullVelocity.Parent = hrp
                end
            elseif method == "Bounce" then
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, moduleSettings["AntiVoid"].bouncePower, hrp.AssemblyLinearVelocity.Z)
            end
        end

        if pullVelocity and rescueTarget then
            local goal = Vector3.new(rescueTarget.X, hrp.Position.Y, rescueTarget.Z)
            local planarDelta = goal - Vector3.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
            local upwardAssist = hrp.Position.Y < rescueTarget.Y + 3 and 10 or 0
            local planarVelocity = planarDelta.Magnitude > 0.5 and planarDelta.Unit * 22 or Vector3.zero
            pullVelocity.Velocity = Vector3.new(planarVelocity.X, upwardAssist, planarVelocity.Z)
            local closeToGround = hrp.Position.Y <= rescueTarget.Y + 5
            local closeToTarget = planarDelta.Magnitude < 3.5
            if closeToGround and closeToTarget then
                pullVelocity:Destroy()
                pullVelocity = nil
                rescueTarget = nil
                refreshVoidReference()
            end
        end

        if pullVelocity and rescueTarget then
            local horizontal = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(rescueTarget.X, 0, rescueTarget.Z)).Magnitude
            if horizontal < 4 and hrp.Position.Y <= rescueTarget.Y + 5 then
                pullVelocity:Destroy()
                pullVelocity = nil
            end
        end
    end)
    addConnection("AntiVoid", connection)
end


local function toggleInfiniteJump(enabled)
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





local palette = {
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

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AetherCoreUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = lplr:WaitForChild("PlayerGui")

local panelFrames = {}
local moduleDefinitions = {}
local categoryPanels = {}
local categoryToggleButtons = {}
local categoryManualVisibility = {}
local categoryOrder = {"Combat", "Blatant", "Render", "Utility", "World", "Legend"}
local keybindListening = false
local searchText = ""
local settingsOpenByModule = {}
local loadedCategoryPositions = {}
local saveClientSettings

moduleHandlers = {
    KillAura = toggleKillAura,
    Reach = toggleReach,
    AimAssist = toggleAimAssist,
    AutoClicker = toggleAutoClicker,
    Velocity = toggleVelocity,
    Speed = toggleSpeed,
    Step = toggleStep,
    SafeWalk = toggleSafeWalk,
    HighJump = toggleHighJump,
    Fly = toggleFly,
    VerticalFly = toggleVerticalFly,
    LongJump = toggleLongJump,
    Aimbot = toggleAimbot,
    Scaffold = toggleScaffold,
    ESP = toggleESP,
    Tracers = toggleTracers,
    AutoToxic = function(enabled) autoToxicEnabled = enabled end,
    AntiDeath = toggleAntiDeath,
    NoFallDamage = toggleNoFallDamage,
    AntiVoid = toggleAntiVoid,
    InfiniteJump = toggleInfiniteJump,
    Nuker = toggleNuker,
    FastBreak = toggleFastBreak,
    AutoVoidDrop = toggleAutoVoidDrop
}

local function addCorner(target, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = target
end

local function stylePanel(panel)
    panel.BackgroundColor3 = palette.panel
    panel.BorderSizePixel = 0
    addCorner(panel, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(36, 36, 36)
    stroke.Thickness = 1
    stroke.Transparency = 0.2
    stroke.Parent = panel
end

local function createPanel(name, size, position)
    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = size
    panel.Position = position
    panel.Parent = screenGui
    stylePanel(panel)
    panelFrames[name] = panel
    return panel
end

local function makeDraggable(frame, dragBar)
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

local mainPanel = createPanel("MainPanel", UDim2.new(0, 190, 0, 430), UDim2.new(0, 80, 0, 120))
local topBar = createPanel("TopBar", UDim2.new(0, 350, 0, 40), UDim2.new(0, 285, 0, 120))
local statusPanel = createPanel("StatusPanel", UDim2.new(0, 265, 0, 24), UDim2.new(0, 80, 0, 560))

local mainTop = Instance.new("Frame")
mainTop.Size = UDim2.new(1, 0, 0, 40)
mainTop.BackgroundColor3 = palette.deep
mainTop.BorderSizePixel = 0
mainTop.Parent = mainPanel
addCorner(mainTop, 8)

local mainTitle = Instance.new("TextLabel")
mainTitle.Size = UDim2.new(1, -16, 1, 0)
mainTitle.Position = UDim2.new(0, 12, 0, 0)
mainTitle.BackgroundTransparency = 1
mainTitle.Text = "AetherCore"
mainTitle.TextXAlignment = Enum.TextXAlignment.Left
mainTitle.Font = Enum.Font.GothamBold
mainTitle.TextSize = 18
mainTitle.TextColor3 = palette.accent
mainTitle.Parent = mainTop

local mainList = Instance.new("Frame")
mainList.Size = UDim2.new(1, -10, 1, -50)
mainList.Position = UDim2.new(0, 5, 0, 45)
mainList.BackgroundTransparency = 1
mainList.Parent = mainPanel

local mainListLayout = Instance.new("UIListLayout")
mainListLayout.Padding = UDim.new(0, 6)
mainListLayout.Parent = mainList

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -130, 0, 26)
searchBox.Position = UDim2.new(0, 8, 0, 7)
searchBox.BackgroundColor3 = palette.module
searchBox.PlaceholderText = "Search modules..."
searchBox.ClearTextOnFocus = false
searchBox.Text = ""
searchBox.TextColor3 = palette.text
searchBox.PlaceholderColor3 = palette.secondary
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.Parent = topBar
addCorner(searchBox, 6)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 112, 0, 26)
closeButton.Position = UDim2.new(1, -120, 0, 7)
closeButton.BackgroundColor3 = palette.danger
closeButton.Text = "Uninject"
closeButton.TextColor3 = palette.text
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 12
closeButton.Parent = topBar
addCorner(closeButton, 6)

local statusDiscord = Instance.new("TextButton")
statusDiscord.Size = UDim2.new(0, 150, 1, 0)
statusDiscord.BackgroundTransparency = 1
statusDiscord.Text = "discord.gg/mMMFRaUgDz"
statusDiscord.TextColor3 = palette.secondary
statusDiscord.Font = Enum.Font.Gotham
statusDiscord.TextSize = 11
statusDiscord.TextXAlignment = Enum.TextXAlignment.Left
statusDiscord.Parent = statusPanel

local statusTime = Instance.new("TextLabel")
statusTime.Size = UDim2.new(0, 110, 1, 0)
statusTime.Position = UDim2.new(1, -110, 0, 0)
statusTime.BackgroundTransparency = 1
statusTime.Text = "Time: 0s"
statusTime.TextColor3 = palette.secondary
statusTime.Font = Enum.Font.Gotham
statusTime.TextSize = 11
statusTime.TextXAlignment = Enum.TextXAlignment.Right
statusTime.Parent = statusPanel

statusDiscord.MouseButton1Click:Connect(function()
    if clipboardSetter then
        safeCall("CopyDiscord", function()
            clipboardSetter("https://discord.gg/mMMFRaUgDz")
        end)
    else
        warn("[AetherCore][CopyDiscord] setclipboard is unavailable in this executor.")
    end
end)

local function updateStatusTime()
    local startTick = tick()
    RunService.RenderStepped:Connect(function()
        if statusTime and statusTime.Parent then
            statusTime.Text = string.format("Time: %ds", math.floor(tick() - startTick))
        end
    end)
end
updateStatusTime()

makeDraggable(mainPanel, mainTop)
makeDraggable(topBar, topBar)
makeDraggable(statusPanel, statusPanel)

local function filterMatches(name)
    local q = string.lower(searchText or "")
    return q == "" or string.find(string.lower(name), q, 1, true) ~= nil
end

local function validateModuleSettings()
    clampSetting("KillAura", "range", moduleSettings.KillAura.range, 5, 20, 14)
    clampSetting("KillAura", "swingSpeed", moduleSettings.KillAura.swingSpeed, 1, 20, 18)
    clampSetting("AutoClicker", "cps", moduleSettings.AutoClicker.cps, 1, 20, 10)
    clampSetting("Speed", "speed", moduleSettings.Speed.speed, 16, 50, 24)
    clampSetting("Step", "maxHeight", moduleSettings.Step.maxHeight, 2, 14, 6)
    clampSetting("Step", "forwardCheckDistance", moduleSettings.Step.forwardCheckDistance, 1.5, 5, 2.6)
    clampSetting("SafeWalk", "maxDrop", moduleSettings.SafeWalk.maxDrop, 2, 10, 4.5)
    clampSetting("HighJump", "boost", moduleSettings.HighJump.boost, 10, 180, 40)
    clampSetting("Aimbot", "fov", moduleSettings.Aimbot.fov, 20, 450, 160)
    clampSetting("Aimbot", "smoothness", moduleSettings.Aimbot.smoothness, 0.01, 1, 0.55)
    clampSetting("Aimbot", "predictionStrength", moduleSettings.Aimbot.predictionStrength, 0, 2, 1)
    clampSetting("Aimbot", "arrowSpeed", moduleSettings.Aimbot.arrowSpeed, 40, 350, 185)
    clampSetting("Aimbot", "gravity", moduleSettings.Aimbot.gravity, 40, 350, Workspace.Gravity)
    clampSetting("Aimbot", "maxDistance", moduleSettings.Aimbot.maxDistance, 60, 400, 260)
    clampSetting("Reach", "hitRange", moduleSettings.Reach.hitRange, 6, 20, 12)
    clampSetting("Reach", "mineRange", moduleSettings.Reach.mineRange, 6, 20, 12)
    clampSetting("Reach", "placeRange", moduleSettings.Reach.placeRange, 6, 20, 12)
    clampSetting("VerticalFly", "horizontalSpeed", moduleSettings.VerticalFly.horizontalSpeed, 8, 60, 28)
    clampSetting("VerticalFly", "verticalSpeed", moduleSettings.VerticalFly.verticalSpeed, 10, 120, 45)
    clampSetting("VerticalFly", "groundOffset", moduleSettings.VerticalFly.groundOffset or moduleSettings.VerticalFly.hoverHeight, 1, 8, 3.2)
    clampSetting("AntiDeath", "healthThreshold", moduleSettings.AntiDeath.healthThreshold, 1, 95, 25)
    clampSetting("AntiDeath", "belowDuration", moduleSettings.AntiDeath.belowDuration, 0.5, 4, 2)
    clampSetting("AntiDeath", "slowMode", moduleSettings.AntiDeath.slowMode, 0.2, 5, 1.5)
    clampSetting("AntiDeath", "voidOffset", moduleSettings.AntiDeath.voidOffset, 60, 250, 130)
    clampSetting("FastBreak", "cooldown", moduleSettings.FastBreak.cooldown, 0, 0.3, 0.03)
    clampSetting("FastBreak", "attemptsPerPulse", moduleSettings.FastBreak.attemptsPerPulse, 1, 6, 2)
    clampSetting("AutoVoidDrop", "triggerOffset", moduleSettings.AutoVoidDrop.triggerOffset, 4, 60, 18)
    clampSetting("AutoVoidDrop", "dropInterval", moduleSettings.AutoVoidDrop.dropInterval, 0.1, 2, 0.45)
end

saveClientSettings = function()
    safeCall("SaveClientSettings", function()
        local payload = {
            keybinds = {},
            settings = moduleSettings,
            categoryPositions = {}
        }
        for moduleName, key in pairs(moduleKeybinds) do
            payload.keybinds[moduleName] = key and key.Name or nil
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

local function loadClientSettings()
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
    validateModuleSettings()
end
loadClientSettings()

local function createCategoryColumn(categoryName, index)
    local panel = createPanel(categoryName .. "Column", UDim2.new(0, 240, 0, 530), UDim2.new(0, 285 + ((index - 1) * 246), 0, 170))
    panel.Visible = false

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 34)
    top.BackgroundColor3 = palette.deep
    top.BorderSizePixel = 0
    top.Parent = panel
    addCorner(top, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = categoryName
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = palette.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = top

    local list = Instance.new("ScrollingFrame")
    list.Name = "ModuleList"
    list.Size = UDim2.new(1, -10, 1, -44)
    list.Position = UDim2.new(0, 5, 0, 39)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.ScrollBarThickness = 4
    list.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
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

local categoryLists = {}
for i, name in ipairs(categoryOrder) do
    local panel, list = createCategoryColumn(name, i)
    categoryLists[name] = list
end

local categoryData = {
    {name = "Combat", icon = "⚔️"},
    {name = "Blatant", icon = "🚀"},
    {name = "Render", icon = "👁️"},
    {name = "Utility", icon = "🛠️"},
    {name = "World", icon = "🌍"},
    {name = "Legend", icon = "📜"}
}

for _, category in ipairs(categoryData) do
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 32)
    button.BackgroundColor3 = palette.panel
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = string.format("  %s  %s", category.icon, category.name)
    button.TextColor3 = palette.text
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = mainList
    addCorner(button, 6)
    categoryToggleButtons[category.name] = button

    button.MouseButton1Click:Connect(function()
        local panel = categoryPanels[category.name]
        local newVisibility = not panel.Visible
        panel.Visible = newVisibility
        categoryManualVisibility[category.name] = newVisibility
        button.BackgroundColor3 = panel.Visible and palette.active or palette.panel
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

local function uiCreateSlider(parent, name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 38)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = palette.secondary
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueButton = Instance.new("TextButton")
    valueButton.Size = UDim2.new(0.35, -4, 0, 16)
    valueButton.Position = UDim2.new(0.65, 4, 0, 0)
    valueButton.BackgroundColor3 = palette.hover
    valueButton.TextColor3 = palette.text
    valueButton.Font = Enum.Font.Gotham
    valueButton.TextSize = 11
    valueButton.Parent = frame
    addCorner(valueButton, 5)

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 8)
    slider.Position = UDim2.new(0, 0, 0, 22)
    slider.BackgroundColor3 = palette.hover
    slider.Parent = frame
    addCorner(slider, 5)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = palette.accent
    fill.Parent = slider
    addCorner(fill, 5)

    local dragging = false
    local range = max - min
    local function apply(v)
        local clamped = math.clamp(v, min, max)
        fill.Size = UDim2.new((clamped - min) / range, 0, 1, 0)
        valueButton.Text = tostring(math.floor(clamped * 100) / 100)
        callback(clamped)
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
            apply(min + (percent * range))
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
        box.BackgroundColor3 = palette.module
        box.TextColor3 = palette.text
        box.Font = Enum.Font.Gotham
        box.TextSize = 11
        box.ClearTextOnFocus = false
        box.Text = valueButton.Text
        box.Parent = frame
        addCorner(box, 5)
        box:CaptureFocus()

        box.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local typed = tonumber(box.Text)
                if typed then
                    apply(typed)
                end
            end
            box:Destroy()
        end)
    end)
end

local function uiCreateToggle(parent, name, default, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 24)
    button.BackgroundColor3 = default and palette.active or palette.module
    button.TextColor3 = palette.text
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Text = "  " .. name .. (default and ": ON" or ": OFF")
    button.Parent = parent
    addCorner(button, 6)

    local state = default
    button.MouseButton1Click:Connect(function()
        state = not state
        button.BackgroundColor3 = state and palette.active or palette.module
        button.Text = "  " .. name .. (state and ": ON" or ": OFF")
        callback(state)
    end)
end

local function uiCreateDropdown(parent, name, options, default, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 24)
    button.BackgroundColor3 = palette.module
    button.TextColor3 = palette.text
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = parent
    addCorner(button, 6)

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

local function uiCreateTextBox(parent, name, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 24)
    holder.BackgroundColor3 = palette.module
    holder.Parent = parent
    addCorner(holder, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "  " .. name
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = palette.text
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.Parent = holder

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.55, -6, 1, -6)
    box.Position = UDim2.new(0.45, 3, 0, 3)
    box.BackgroundColor3 = palette.hover
    box.Text = tostring(default)
    box.TextColor3 = palette.text
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    box.Parent = holder
    addCorner(box, 5)

    box.FocusLost:Connect(function()
        callback(box.Text)
    end)
end

local function createSettingsContent(parent, moduleName)
    local defs = moduleDefinitions[moduleName] or {}
    if #defs == 0 then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 22)
        label.BackgroundTransparency = 1
        label.Text = "No configurable settings"
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = palette.secondary
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.Parent = parent
        return
    end

    for _, setting in ipairs(defs) do
        if setting.type == "slider" then
            uiCreateSlider(parent, setting.name, setting.min, setting.max, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                saveClientSettings()
            end)
        elseif setting.type == "toggle" then
            uiCreateToggle(parent, setting.name, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                saveClientSettings()
            end)
        elseif setting.type == "dropdown" then
            uiCreateDropdown(parent, setting.name, setting.options, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                saveClientSettings()
            end)
        elseif setting.type == "textbox" then
            uiCreateTextBox(parent, setting.name, moduleSettings[moduleName][setting.settingName], function(val)
                moduleSettings[moduleName][setting.settingName] = val
                saveClientSettings()
            end)
        end
    end
end

local function createModule(category, moduleName, defaultEnabled, toggleCallback)
    local list = categoryLists[category]
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, 42)
    card.BackgroundColor3 = palette.module
    card.BorderSizePixel = 0
    card.Parent = list
    addCorner(card, 6)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.55, 0, 0, 22)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = moduleName
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = palette.text
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 13
    title.Parent = card

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(0, 48, 0, 20)
    keybindBtn.Position = UDim2.new(1, -112, 0, 11)
    keybindBtn.BackgroundColor3 = palette.hover
    keybindBtn.TextColor3 = palette.text
    keybindBtn.Text = moduleKeybinds[moduleName] and moduleKeybinds[moduleName].Name or "NONE"
    keybindBtn.Font = Enum.Font.Gotham
    keybindBtn.TextSize = 10
    keybindBtn.Parent = card
    addCorner(keybindBtn, 6)

    local settingsBtn = Instance.new("TextButton")
    settingsBtn.Size = UDim2.new(0, 24, 0, 20)
    settingsBtn.Position = UDim2.new(1, -56, 0, 11)
    settingsBtn.BackgroundColor3 = palette.hover
    settingsBtn.Text = "⚙"
    settingsBtn.TextColor3 = palette.text
    settingsBtn.Font = Enum.Font.GothamBold
    settingsBtn.TextSize = 12
    settingsBtn.Parent = card
    addCorner(settingsBtn, 6)

    local settingsHolder = Instance.new("Frame")
    settingsHolder.Size = UDim2.new(1, -14, 0, 0)
    settingsHolder.Position = UDim2.new(0, 7, 0, 40)
    settingsHolder.BackgroundTransparency = 1
    settingsHolder.ClipsDescendants = true
    settingsHolder.Parent = card

    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 4)
    settingsLayout.Parent = settingsHolder

    local enabled = defaultEnabled
    moduleStates[moduleName] = enabled

    local function updateCardVisual()
        card.BackgroundColor3 = enabled and palette.active or palette.module
    end

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
    end)

    settingsBtn.MouseButton1Click:Connect(function()
        settingsOpenByModule[moduleName] = not settingsOpenByModule[moduleName]
        for _, child in ipairs(settingsHolder:GetChildren()) do
            if not child:IsA("UIListLayout") then
                child:Destroy()
            end
        end
        if settingsOpenByModule[moduleName] then
            createSettingsContent(settingsHolder, moduleName)
            task.wait()
            local openSize = settingsLayout.AbsoluteContentSize.Y
            TweenService:Create(settingsHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -14, 0, openSize)}):Play()
            TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -4, 0, 46 + openSize)}):Play()
        else
            TweenService:Create(settingsHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -14, 0, 0)}):Play()
            TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -4, 0, 42)}):Play()
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
                            moduleUi[existingModule].setKeyText("NONE")
                        end
                    end
                end
                if moduleKeybinds[moduleName] == key then
                    moduleKeybinds[moduleName] = nil
                    keybindBtn.Text = "NONE"
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
            updateCardVisual()
        end,
        setKeyText = function(text)
            keybindBtn.Text = text
        end,
        setVisible = function(visible)
            card.Visible = visible
        end,
        category = category,
        name = moduleName
    }

    updateCardVisual()
    if defaultEnabled and toggleCallback then
        safeCall(moduleName .. "InitialToggle", toggleCallback, true)
    end
end

local function createRegisteredModule(category, name, defaultEnabled, toggleCallback, settingsDefinition)
    moduleDefinitions[name] = settingsDefinition or {}
    createModule(category, name, defaultEnabled, toggleCallback)
end

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
    {type = "slider", name = "Speed", min = 0.01, max = 0.5, settingName = "speed"},
    {type = "slider", name = "Range", min = 10, max = 50, settingName = "range"}
})
createRegisteredModule("Combat", "Aimbot", false, toggleAimbot, {
    {type = "slider", name = "FOV", min = 20, max = 450, settingName = "fov"},
    {type = "slider", name = "Smoothness", min = 0.01, max = 1, settingName = "smoothness"},
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
createRegisteredModule("Combat", "Velocity", false, toggleVelocity, {
    {type = "slider", name = "Horizontal %", min = 0, max = 100, settingName = "horizontalReduction"},
    {type = "slider", name = "Vertical %", min = 0, max = 100, settingName = "verticalReduction"}
})
createRegisteredModule("Blatant", "Speed", false, toggleSpeed, {
    {type = "slider", name = "Speed", min = 16, max = 50, settingName = "speed"}
})
createRegisteredModule("Blatant", "Step", false, toggleStep, {
    {type = "slider", name = "Max Height", min = 2, max = 14, settingName = "maxHeight"},
    {type = "slider", name = "Forward Check", min = 1.5, max = 5, settingName = "forwardCheckDistance"}
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
    {type = "slider", name = "Ground Offset", min = 1, max = 8, settingName = "groundOffset"}
})
createRegisteredModule("Blatant", "LongJump", false, toggleLongJump, {
    {type = "slider", name = "Speed", min = 50, max = 200, settingName = "speed"},
    {type = "slider", name = "Duration", min = 0.5, max = 3, settingName = "duration"}
})
createRegisteredModule("Blatant", "Scaffold", false, toggleScaffold, {
    {type = "toggle", name = "Allow Towering", settingName = "allowTowering"}
})
createRegisteredModule("Render", "ESP", false, toggleESP, {})
createRegisteredModule("Render", "Tracers", false, toggleTracers, {
    {type = "slider", name = "Transparency", min = 0, max = 1, settingName = "transparency"}
})
createRegisteredModule("Utility", "AutoToxic", false, nil, {
    {type = "toggle", name = "Final Kill Message", settingName = "enabledFinalKill"},
    {type = "textbox", name = "Final Kill Text", settingName = "finalKillMessage"},
    {type = "toggle", name = "Bed Break Message", settingName = "enabledBedBreak"},
    {type = "textbox", name = "Bed Break Text", settingName = "bedBreakMessage"},
    {type = "toggle", name = "Game Win Message", settingName = "enabledGameWin"},
    {type = "textbox", name = "Game Win Text", settingName = "gameWinMessage"}
})
createRegisteredModule("Utility", "NoFallDamage", false, toggleNoFallDamage, {
    {type = "dropdown", name = "Method", options = {"Landing", "NegateVelocity", "Teleport", "DaoExploit"}, settingName = "method"}
})
createRegisteredModule("Utility", "AntiDeath", false, toggleAntiDeath, {
    {type = "slider", name = "HP Threshold", min = 1, max = 95, settingName = "healthThreshold"},
    {type = "slider", name = "Down Duration", min = 0.5, max = 4, settingName = "belowDuration"},
    {type = "slider", name = "Slow Mode", min = 0.2, max = 5, settingName = "slowMode"},
    {type = "slider", name = "Void Offset", min = 60, max = 250, settingName = "voidOffset"}
})
createRegisteredModule("Utility", "AntiVoid", false, toggleAntiVoid, {
    {type = "dropdown", name = "Method", options = {"Normal", "Bounce"}, settingName = "method"},
    {type = "slider", name = "Bounce Power", min = 50, max = 200, settingName = "bouncePower"}
})
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

local function refreshSearch()
    local visibleModulesByCategory = {}
    for _, ui in pairs(moduleUi) do
        local moduleVisible = filterMatches(ui.name)
        ui.setVisible(moduleVisible)
        if moduleVisible then
            visibleModulesByCategory[ui.category] = true
        end
    end

    local searching = string.lower(searchText or "") ~= ""
    for categoryName, panel in pairs(categoryPanels) do
        local manuallyVisible = categoryManualVisibility[categoryName] == true
        local hasVisibleModules = visibleModulesByCategory[categoryName] == true
        panel.Visible = searching and manuallyVisible and hasVisibleModules or manuallyVisible

        local categoryButton = categoryToggleButtons[categoryName]
        if categoryButton then
            categoryButton.BackgroundColor3 = panel.Visible and palette.active or palette.panel
        end
    end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchText = searchBox.Text or ""
    refreshSearch()
end)
refreshSearch()

closeButton.MouseButton1Click:Connect(function()
    if autoToxicMessageConnection then
        autoToxicMessageConnection:Disconnect()
        autoToxicMessageConnection = nil
    end
    local sharedEnvironment = sharedEnvironmentGetter and sharedEnvironmentGetter() or nil
    if sharedEnvironment and sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] then
        sharedEnvironment[AUTO_TOXIC_CONNECTION_KEY] = nil
    end

    for name, enabled in pairs(moduleStates) do
        if enabled then
            moduleStates[name] = false
            if moduleHandlers[name] then
                safeCall(name .. "Disable", moduleHandlers[name], false)
            end
            if moduleUi[name] then
                moduleUi[name].setEnabled(false)
            end
        end
    end
    screenGui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or keybindListening then return end

    if input.KeyCode == Enum.KeyCode.RightShift then
        guiEnabled = not guiEnabled
        screenGui.Enabled = guiEnabled
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
    for name, enabled in pairs(moduleStates) do
        if enabled and moduleHandlers[name] then
            safeCall(name .. "CharacterAddedToggle", moduleHandlers[name], true)
        end
    end
end)
