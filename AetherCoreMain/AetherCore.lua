-- AetherCore :)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
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
local guiEnabled = true
local autoToxicEnabled = false


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


local function getCharacter(player)
    return player and player.Character
end

local function getHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart")
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

local function getHeldOrBackpackDaoTool()
    local char = getCharacter(lplr)
    if not char then return nil end
    local heldTool = char:FindFirstChildOfClass("Tool")
    if heldTool and heldTool.Name:lower():find("dao") then
        return heldTool
    end
    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if not backpack then return nil end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():find("dao") then
            return tool
        end
    end
    return nil
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
    local hum = getHumanoid(char)
    if not char or not hum then return false end
    local dao = getHeldOrBackpackDaoTool()
    if not dao then return false end
    if dao.Parent ~= char then
        hum:EquipTool(dao)
        task.wait()
    end

    local used = false
    pcall(function()
        dao:Activate()
        used = true
    end)

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        for _, remote in ipairs(remotes:GetDescendants()) do
            if remote:IsA("RemoteEvent") and (remote.Name:lower():find("ability") or remote.Name:lower():find("use")) then
                pcall(function()
                    remote:FireServer(dao.Name)
                    used = true
                end)
                pcall(function()
                    remote:FireServer({item = dao.Name})
                    used = true
                end)
            end
        end
    end

    return used
end

local function getTargetByFilters(range, attackPlayers, attackNPCs)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    if not myHRP then
        return nil
    end
    local nearest
    local nearestDistance = range or math.huge

    if attackPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and player.Team ~= lplr.Team then
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
                    local isPlayerModel = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then
                            isPlayerModel = true
                            break
                        end
                    end
                    if not isPlayerModel then
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
    local myTeam = ignoreTeam and nil or lplr.Team
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
                local isPlayerChar = false
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character == model then isPlayerChar = true break end
                end
                if not isPlayerChar then
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

local function attackTargetWithBedwarsApi(targetCharacter)
    local char = getCharacter(lplr)
    local tool = char and char:FindFirstChildOfClass("Tool")
    local controller = getCombatController()
    local attacked = false

    if controller then
        local targetHum = getHumanoid(targetCharacter)
        local targetRoot = getHRP(targetCharacter)
        for _, fnName in ipairs({"attackEntity", "AttackEntity", "swingSwordAtMouse", "swingSword"}) do
            local fn = controller[fnName]
            if type(fn) == "function" then
                pcall(function()
                    if fnName == "swingSwordAtMouse" then
                        fn(controller)
                    elseif fnName == "attackEntity" or fnName == "AttackEntity" then
                        fn(controller, targetHum or targetCharacter, targetRoot and targetRoot.Position or nil)
                    else
                        fn(controller, targetHum or targetCharacter)
                    end
                    attacked = true
                end)
            end
        end
    end

    if tool and not attacked then
        pcall(function()
            tool:Activate()
            attacked = true
        end)
    end

    return attacked
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

local function performPrimaryClick()
    local clicked = false
    pcall(function()
        local mouseLocation = UserInputService:GetMouseLocation()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(mouseLocation, camera.CFrame)
        task.wait()
        VirtualUser:Button1Up(mouseLocation, camera.CFrame)
        clicked = true
    end)
    return clicked
end


local function createSlider(parent, name, min, max, default, callback)
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

local function createToggle(parent, name, default, callback)
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

local function createDropdown(parent, name, options, default, callback)
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

local function createTextBox(parent, name, default, callback)
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
    multiTarget = true,
    multiTargetLimit = 3,
    targetMode = "Players",
    priority = "Closest",
    silent = true,
    faceTarget = false,
    requireSword = false,
    attackThroughWalls = true,
    ignoreTeammates = true,

    fovRadius = 360,
    attackPlayers = true,
    attackNPCs = false
}

local killAuraLastSwing = 0

local function isSwordTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    return n:find("sword") or n:find("blade") or n:find("katana") or n:find("dao")
end

local function getHeldSword()
    local char = getCharacter(lplr)
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and isSwordTool(tool) then return tool end
    return nil
end

local function toggleKillAura(enabled)
    cleanupModule("KillAura")
    if not enabled then return end


    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["KillAura"] then return end

        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myHRP then return end

        local sword = getHeldSword()
        if moduleSettings["KillAura"].requireSword and not sword then return end


        local targetChar, dist = getNearestEnemy(moduleSettings["KillAura"].range, moduleSettings["KillAura"].ignoreTeammates)
        if not targetChar or dist > moduleSettings["KillAura"].range then return end

        local now = tick()
        if now - killAuraLastSwing < (1 / moduleSettings["KillAura"].swingSpeed) then return end


        local attacked = false


        local controller = getCombatController()
        if controller then
            local hum = getHumanoid(targetChar)
            pcall(function()
                if controller.attackEntity then
                    controller.attackEntity(controller, hum)
                    attacked = true
                elseif controller.AttackEntity then
                    controller.AttackEntity(controller, hum)
                    attacked = true
                end
            end)
            pcall(function()
                if controller.swingSword then controller.swingSword(controller) end
            end)
        end


        if sword and not attacked then
            pcall(function()
                sword:Activate()
                attacked = true
            end)
        end


        if not attacked then
            attacked = attackTargetWithBedwarsApi(targetChar)
        end

        if attacked then
            performPrimaryClick()
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
    addConnection("Reach", RunService.Heartbeat:Connect(function()
        if not moduleStates["Reach"] then return end
        applyReach()
    end))
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

    local function addESPtoModel(model)
        if not model or model:FindFirstChild("ESP_Highlight") then return end
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
                end
            end
        end
    end

    scanAndAddESP()
    addConnection("ESP", RunService.Heartbeat:Connect(scanAndAddESP))
end


moduleSettings["Tracers"] = { transparency = 0.5 }

local function toggleTracers(enabled)
    cleanupModule("Tracers")
    if not enabled then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Beam") and obj.Name == "TracerBeam" then obj:Destroy() end
        end
        return
    end

    local function createTracerForModel(model)
        if not model or model:FindFirstChild("TracerBeam") then return end
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if not head then return end

        local attach0 = Instance.new("Attachment")
        attach0.Name = "TracerAttach0"
        attach0.Parent = camera

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
            attach0.WorldPosition = camera.CFrame.Position
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
    addConnection("Tracers", RunService.Heartbeat:Connect(scanAndAddTracers))
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
        TextChatService.MessageReceived:Connect(function(message)
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

        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local dist = (myHRP.Position - obj.Position).Magnitude
                if dist > settings.mineRadius then continue end

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
                        firetouchinterest(obj, tool.Handle, 0)
                        firetouchinterest(obj, tool.Handle, 1)
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


        local hasWool = false
        local woolName = getTeamWoolName()
        for _, tool in ipairs(myChar:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:lower():find("wool") then
                hasWool = true
                break
            end
        end
        if not hasWool then return end

        local placePos = hrp.Position - Vector3.new(0, 3, 0)


        if moduleSettings["Scaffold"].allowTowering then
            local hum = getHumanoid(myChar)
            if hum and hum:GetState() == Enum.HumanoidStateType.Jumping then
                placePos = hrp.Position - Vector3.new(0, 0.5, 0)
            end
        end


        local region = Region3.new(placePos - Vector3.new(1,1,1), placePos + Vector3.new(1,1,1))
        local parts = Workspace:FindPartsInRegion3(region, nil, 100)
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
                    pcall(function()
                        fn(blockController, CFrame.new(placePos))
                        didPlace = true
                    end)
                    pcall(function()
                        fn(blockController, placePos)
                        didPlace = true
                    end)
                    pcall(function()
                        fn(blockController, woolName, CFrame.new(placePos))
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
            pcall(function()
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
                        pcall(function()
                            remote:FireServer({
                                position = placePos,
                                blockType = woolName
                            })
                            performPrimaryClick()
                        end)
                        pcall(function()
                            remote:FireServer(placePos, woolName)
                            performPrimaryClick()
                        end)
                    end
                end
            end
        end
    end)
    addConnection("Scaffold", connection)
end


moduleSettings["AimAssist"] = {
    speed = 0.1,
    range = 30
}

local function toggleAimAssist(enabled)
    cleanupModule("AimAssist")
    if not enabled then return end

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
        mousemoverel(delta.X, delta.Y)
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
            local delay = 1 / math.max(moduleSettings["AutoClicker"].cps, 1)
            if now - lastClick >= delay then
                lastClick = now
                performPrimaryClick()
                local nearest = getTargetByFilters(18, true, true)
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
        local isHoldingDao = isDaoTool(heldTool)
        if not isHoldingDao then
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hrp.AssemblyLinearVelocity = Vector3.zero
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

    local function getNearestGroundPosition(origin, character)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {character}

        local offsets = {
            Vector3.new(0, 0, 0),
            Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0),
            Vector3.new(0, 0, 6), Vector3.new(0, 0, -6),
            Vector3.new(12, 0, 0), Vector3.new(-12, 0, 0),
            Vector3.new(0, 0, 12), Vector3.new(0, 0, -12)
        }
        local best
        local bestDist = math.huge
        for _, offset in ipairs(offsets) do
            local start = origin + offset + Vector3.new(0, 20, 0)
            local hit = Workspace:Raycast(start, Vector3.new(0, -300, 0), raycastParams)
            if hit then
                local dist = (Vector3.new(origin.X, 0, origin.Z) - Vector3.new(hit.Position.X, 0, hit.Position.Z)).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    best = hit.Position
                end
            end
        end
        return best
    end

    local function refreshVoidReference()
        local myChar = getCharacter(lplr)
        local hrp = getHRP(myChar)
        if not myChar or not hrp then
            return
        end
        local groundPos = getNearestGroundPosition(hrp.Position, myChar)
        local referenceY = groundPos and groundPos.Y or hrp.Position.Y
        voidTriggerY = referenceY - 38
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
                if not rescueTarget then
                    rescueTarget = getNearestGroundPosition(hrp.Position, myChar)
                end
                if rescueTarget then
                    hrp.CFrame = CFrame.new(hrp.Position.X, rescueTarget.Y + 3, hrp.Position.Z)
                    if pullVelocity then
                        pullVelocity:Destroy()
                    end
                    pullVelocity = Instance.new("BodyVelocity")
                    pullVelocity.Name = "AntiVoidPull"
                    pullVelocity.MaxForce = Vector3.new(2e5, 0, 2e5)
                    pullVelocity.Parent = hrp
                end
            elseif method == "Bounce" then
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, moduleSettings["AntiVoid"].bouncePower, hrp.AssemblyLinearVelocity.Z)
            end
        end

        if pullVelocity and rescueTarget then
            local goal = Vector3.new(rescueTarget.X, hrp.Position.Y, rescueTarget.Z)
            local planarDelta = goal - Vector3.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
            pullVelocity.Velocity = planarDelta.Magnitude > 0.5 and planarDelta.Unit * 38 or Vector3.zero
            local closeToGround = hrp.Position.Y <= rescueTarget.Y + 4
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
            if hum then hum.JumpPower = 50 end
        end
        return
    end

    local function applyJump(char)
        local hum = getHumanoid(char)
        if hum then hum.JumpPower = 0 end
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





local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AetherCoreUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = lplr:WaitForChild("PlayerGui")

local shadow = Instance.new("ImageLabel")
shadow.Name = "WindowShadow"
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Size = UDim2.new(0, 1028, 0, 548)
shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
shadow.ImageColor3 = Color3.new(0, 0, 0)
shadow.ImageTransparency = 0.82
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(4, 4, 252, 252)
shadow.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 1000, 0, 520)
mainFrame.Position = UDim2.new(0.5, -500, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local function syncShadow()
    shadow.Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset + (mainFrame.Size.X.Offset / 2), mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset + (mainFrame.Size.Y.Offset / 2))
end
syncShadow()

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 48)
topBar.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 180, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Text = "AetherCore"
title.TextColor3 = Color3.fromRGB(155, 89, 182)
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0, 210, 0, 30)
searchBox.Position = UDim2.new(1, -258, 0.5, -15)
searchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
searchBox.Text = ""
searchBox.PlaceholderText = "Search modules..."
searchBox.ClearTextOnFocus = false
searchBox.TextColor3 = Color3.fromRGB(235, 235, 235)
searchBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.Parent = topBar
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 7)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 28, 0, 28)
closeButton.Position = UDim2.new(1, -38, 0.5, -14)
closeButton.BackgroundColor3 = Color3.fromRGB(44, 44, 44)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(225, 225, 225)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Parent = topBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(1, 0)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 140, 1, -48)
sidebar.Position = UDim2.new(0, 0, 0, 48)
sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame

local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.PaddingTop = UDim.new(0, 8)
sidebarPadding.PaddingLeft = UDim.new(0, 4)
sidebarPadding.PaddingRight = UDim.new(0, 4)
sidebarPadding.Parent = sidebar

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Padding = UDim.new(0, 3)
sidebarLayout.Parent = sidebar

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -140, 1, -48)
contentArea.Position = UDim2.new(0, 140, 0, 48)
contentArea.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
contentArea.BorderSizePixel = 0
contentArea.Parent = mainFrame

local contentScroller = Instance.new("ScrollingFrame")
contentScroller.Size = UDim2.new(1, -12, 1, -12)
contentScroller.Position = UDim2.new(0, 6, 0, 6)
contentScroller.BackgroundTransparency = 1
contentScroller.BorderSizePixel = 0
contentScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
contentScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentScroller.ScrollBarThickness = 4
contentScroller.ScrollingDirection = Enum.ScrollingDirection.Y
contentScroller.Parent = contentArea

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 6)
contentLayout.Parent = contentScroller

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 2)
contentPadding.PaddingBottom = UDim.new(0, 8)
contentPadding.PaddingLeft = UDim.new(0, 2)
contentPadding.PaddingRight = UDim.new(0, 2)
contentPadding.Parent = contentScroller

local categories = {
    {name = "Combat", icon = "⚔️"},
    {name = "Blatant", icon = "🚀"},
    {name = "Render", icon = "👁️"},
    {name = "Utility", icon = "🛠️"},
    {name = "World", icon = "🌍"},
    {name = "Legit", icon = "🎯"},
    {name = "Movement", icon = "🏃"}
}

local activeCategory = "Combat"
local categoryButtons = {}
local categoryFrames = {}
local moduleRegistry = {}
local moduleUi = {}

local function updateCategoryVisuals()
    for categoryName, button in pairs(categoryButtons) do
        local isActive = categoryName == activeCategory
        local accent = button:FindFirstChild("Accent")
        if accent then
            accent.Visible = isActive
        end
        TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
            BackgroundColor3 = isActive and Color3.fromRGB(44, 44, 44) or Color3.fromRGB(30, 30, 30)
        }):Play()
    end

    for categoryName, frame in pairs(categoryFrames) do
        frame.Visible = categoryName == activeCategory
    end
end

local function refreshModuleFiltering()
    local query = string.lower(searchBox.Text or "")
    for moduleName, info in pairs(moduleRegistry) do
        local categoryMatches = info.category == activeCategory
        local textMatches = query == "" or string.find(string.lower(moduleName), query, 1, true) ~= nil
        info.frame.Visible = categoryMatches and textMatches
    end
end

for index, category in ipairs(categories) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = string.format("  %s  %s", category.icon, category.name)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.LayoutOrder = index
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
    accent.Visible = false
    accent.Parent = btn

    local catFrame = Instance.new("Frame")
    catFrame.Name = category.name .. "Modules"
    catFrame.Size = UDim2.new(1, -2, 0, 0)
    catFrame.BackgroundTransparency = 1
    catFrame.Visible = false
    catFrame.Parent = contentScroller
    catFrame.AutomaticSize = Enum.AutomaticSize.Y

    local catLayout = Instance.new("UIListLayout")
    catLayout.Padding = UDim.new(0, 6)
    catLayout.Parent = catFrame

    categoryButtons[category.name] = btn
    categoryFrames[category.name] = catFrame

    btn.MouseEnter:Connect(function()
        if activeCategory ~= category.name then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(38, 38, 38)}):Play()
        end
    end)

    btn.MouseLeave:Connect(function()
        if activeCategory ~= category.name then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        activeCategory = category.name
        updateCategoryVisuals()
        refreshModuleFiltering()
    end)
end

local keybindListening = false

local function createModule(parent, name, defaultEnabled, toggleCallback, settingsDefinition)
    local frame = Instance.new("Frame")
    frame.Name = name .. "Module"
    frame.Size = UDim2.new(1, -2, 0, 48)
    frame.BackgroundColor3 = defaultEnabled and Color3.fromRGB(76, 49, 89) or Color3.fromRGB(44, 44, 44)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 7)

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundTransparency = 1
    header.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.48, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(245, 245, 245)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = header

    local toggleHitbox = Instance.new("TextButton")
    toggleHitbox.Name = "ToggleButton"
    toggleHitbox.Size = UDim2.new(1, -132, 1, 0)
    toggleHitbox.BackgroundTransparency = 1
    toggleHitbox.Text = ""
    toggleHitbox.Parent = header

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(0, 56, 0, 22)
    keybindBtn.Position = UDim2.new(1, -120, 0.5, -11)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    keybindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindBtn.Text = moduleKeybinds[name] and moduleKeybinds[name].Name or "NONE"
    keybindBtn.Font = Enum.Font.GothamMedium
    keybindBtn.TextSize = 11
    keybindBtn.Parent = header
    Instance.new("UICorner", keybindBtn).CornerRadius = UDim.new(1, 0)

    local settingsBtn = Instance.new("TextButton")
    settingsBtn.Size = UDim2.new(0, 22, 0, 22)
    settingsBtn.Position = UDim2.new(1, -58, 0.5, -11)
    settingsBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    settingsBtn.Text = "⚙"
    settingsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    settingsBtn.Font = Enum.Font.GothamBold
    settingsBtn.TextSize = 12
    settingsBtn.Parent = header
    Instance.new("UICorner", settingsBtn).CornerRadius = UDim.new(1, 0)

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0, 36, 0, 20)
    switch.Position = UDim2.new(1, -32, 0.5, -10)
    switch.BackgroundColor3 = defaultEnabled and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(56, 56, 56)
    switch.BorderSizePixel = 0
    switch.Parent = header
    Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)

    local switchText = Instance.new("TextLabel")
    switchText.Size = UDim2.new(1, 0, 1, 0)
    switchText.BackgroundTransparency = 1
    switchText.Text = defaultEnabled and "ON" or "OFF"
    switchText.TextColor3 = Color3.fromRGB(255, 255, 255)
    switchText.Font = Enum.Font.GothamBold
    switchText.TextSize = 9
    switchText.Parent = switch

    local switchKnob = Instance.new("Frame")
    switchKnob.Size = UDim2.new(0, 16, 0, 16)
    switchKnob.Position = defaultEnabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    switchKnob.Parent = switch
    Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

    local settingsPanel = Instance.new("Frame")
    settingsPanel.Name = "SettingsPanel"
    settingsPanel.Size = UDim2.new(1, 0, 0, 0)
    settingsPanel.Position = UDim2.new(0, 0, 0, 48)
    settingsPanel.BackgroundColor3 = Color3.fromRGB(34, 34, 34)
    settingsPanel.BorderSizePixel = 0
    settingsPanel.ClipsDescendants = true
    settingsPanel.Parent = frame
    Instance.new("UICorner", settingsPanel).CornerRadius = UDim.new(0, 7)

    local settingsPadding = Instance.new("UIPadding")
    settingsPadding.PaddingTop = UDim.new(0, 6)
    settingsPadding.PaddingBottom = UDim.new(0, 6)
    settingsPadding.PaddingLeft = UDim.new(0, 8)
    settingsPadding.PaddingRight = UDim.new(0, 8)
    settingsPadding.Parent = settingsPanel

    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 4)
    settingsLayout.Parent = settingsPanel

    if settingsDefinition then
        for _, setting in ipairs(settingsDefinition) do
            if setting.type == "slider" then
                createSlider(settingsPanel, setting.name, setting.min, setting.max, moduleSettings[name][setting.settingName], function(val)
                    moduleSettings[name][setting.settingName] = val
                end)
            elseif setting.type == "toggle" then
                createToggle(settingsPanel, setting.name, moduleSettings[name][setting.settingName], function(val)
                    moduleSettings[name][setting.settingName] = val
                end)
            elseif setting.type == "dropdown" then
                createDropdown(settingsPanel, setting.name, setting.options, moduleSettings[name][setting.settingName], function(val)
                    moduleSettings[name][setting.settingName] = val
                end)
            elseif setting.type == "textbox" then
                createTextBox(settingsPanel, setting.name, moduleSettings[name][setting.settingName], function(val)
                    moduleSettings[name][setting.settingName] = val
                end)
            end
        end
    end

    local settingsOpen = false
    local enabled = defaultEnabled
    moduleStates[name] = enabled

    local function updateVisual()
        TweenService:Create(frame, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
            BackgroundColor3 = enabled and Color3.fromRGB(76, 49, 89) or Color3.fromRGB(44, 44, 44)
        }):Play()
        TweenService:Create(switch, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
            BackgroundColor3 = enabled and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(56, 56, 56)
        }):Play()
        TweenService:Create(switchKnob, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
            Position = enabled and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        switchText.Text = enabled and "ON" or "OFF"
    end

    settingsBtn.MouseButton1Click:Connect(function()
        settingsOpen = not settingsOpen
        local targetHeight = 0
        if settingsOpen then
            targetHeight = settingsLayout.AbsoluteContentSize.Y + 12
        end
        TweenService:Create(settingsPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(1, -2, 0, 48 + targetHeight)}):Play()
    end)

    keybindBtn.MouseButton1Click:Connect(function()
        if keybindListening then return end
        keybindListening = true
        keybindBtn.Text = "Press a key..."
        keybindBtn.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                if moduleKeybinds[name] == key then
                    moduleKeybinds[name] = nil
                    keybindBtn.Text = "NONE"
                else
                    moduleKeybinds[name] = key
                    keybindBtn.Text = key.Name
                end
                keybindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                keybindListening = false
                conn:Disconnect()
            end
        end)
    end)

    local toggleDebounce = false
    toggleHitbox.MouseButton1Click:Connect(function()
        if toggleDebounce then return end
        toggleDebounce = true
        enabled = not enabled
        moduleStates[name] = enabled
        if name == "AutoToxic" then
            autoToxicEnabled = enabled
        end
        if toggleCallback then
            toggleCallback(enabled)
        end
        updateVisual()
        task.delay(0.08, function()
            toggleDebounce = false
        end)
    end)

    frame.MouseEnter:Connect(function()
        if not enabled then
            TweenService:Create(frame, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(52, 52, 52)}):Play()
        end
    end)

    frame.MouseLeave:Connect(function()
        if not enabled then
            TweenService:Create(frame, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(44, 44, 44)}):Play()
        end
    end)

    moduleUi[name] = {
        frame = frame,
        setEnabled = function(state)
            enabled = state
            moduleStates[name] = state
            updateVisual()
        end,
        setKeyText = function(txt)
            keybindBtn.Text = txt
        end
    }

    updateVisual()
    if defaultEnabled and toggleCallback then
        toggleCallback(true)
    end
    return frame
end

local moduleHandlers = {
    KillAura = toggleKillAura,
    Reach = toggleReach,
    Speed = toggleSpeed,
    Fly = toggleFly,
    ESP = toggleESP,
    Tracers = toggleTracers,
    AutoToxic = function(enabled) autoToxicEnabled = enabled end,
    Nuker = toggleNuker,
    Scaffold = toggleScaffold,
    AimAssist = toggleAimAssist,
    AutoClicker = toggleAutoClicker,
    Velocity = toggleVelocity,
    LongJump = toggleLongJump,
    NoFallDamage = toggleNoFallDamage,
    AntiVoid = toggleAntiVoid,
    InfiniteJump = toggleInfiniteJump
}

local function createRegisteredModule(category, name, defaultEnabled, toggleCallback, settingsDefinition)
    local container = categoryFrames[category]
    local moduleFrame = createModule(container, name, defaultEnabled, toggleCallback, settingsDefinition)
    moduleRegistry[name] = {frame = moduleFrame, category = category}
end

createRegisteredModule("Combat", "KillAura", false, toggleKillAura, {
    {type = "toggle", name = "Face Target", settingName = "faceTarget"},
    {type = "slider", name = "FOV Radius", min = 50, max = 600, settingName = "fovRadius"},
    {type = "slider", name = "Range", min = 5, max = 20, settingName = "range"},
    {type = "slider", name = "Swing Speed", min = 1, max = 20, settingName = "swingSpeed"},
    {type = "toggle", name = "Require Sword", settingName = "requireSword"},
    {type = "toggle", name = "Attack Players", settingName = "attackPlayers"},
    {type = "toggle", name = "Attack NPCs", settingName = "attackNPCs"}
})

createRegisteredModule("Combat", "Reach", false, toggleReach, {
    {type = "dropdown", name = "Mode", options = {"Both", "Attribute", "Handle"}, settingName = "mode"},
    {type = "slider", name = "Hit Range", min = 6, max = 20, settingName = "hitRange"},
    {type = "slider", name = "Mine Range", min = 6, max = 20, settingName = "mineRange"},
    {type = "slider", name = "Place Range", min = 6, max = 20, settingName = "placeRange"}
})

createRegisteredModule("Blatant", "Speed", false, toggleSpeed, {
    {type = "slider", name = "Speed", min = 16, max = 50, settingName = "speed"}
})

createRegisteredModule("Blatant", "Fly", false, toggleFly, {
    {type = "slider", name = "Horizontal Speed", min = 10, max = 100, settingName = "horizontalSpeed"},
    {type = "slider", name = "Vertical Speed", min = 10, max = 100, settingName = "verticalSpeed"},
    {type = "toggle", name = "TP Down", settingName = "tpDownEnabled"},
    {type = "slider", name = "TP Interval", min = 1, max = 5, settingName = "tpDownInterval"},
    {type = "slider", name = "TP Return Delay", min = 0.05, max = 1, settingName = "tpDownReturnDelay"}
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

createRegisteredModule("World", "Nuker", false, toggleNuker, {
    {type = "toggle", name = "Mine Beds", settingName = "mineBeds"},
    {type = "toggle", name = "Mine Iron", settingName = "mineIron"},
    {type = "toggle", name = "Mine Gold", settingName = "mineGold"},
    {type = "toggle", name = "Mine Diamond", settingName = "mineDiamond"},
    {type = "toggle", name = "Mine Emerald", settingName = "mineEmerald"},
    {type = "slider", name = "Radius", min = 5, max = 20, settingName = "mineRadius"}
})

createRegisteredModule("World", "Scaffold", false, toggleScaffold, {
    {type = "toggle", name = "Allow Towering", settingName = "allowTowering"}
})

createRegisteredModule("Legit", "AimAssist", false, toggleAimAssist, {
    {type = "slider", name = "Speed", min = 0.01, max = 0.5, settingName = "speed"},
    {type = "slider", name = "Range", min = 10, max = 50, settingName = "range"}
})

createRegisteredModule("Legit", "AutoClicker", false, toggleAutoClicker, {
    {type = "slider", name = "CPS", min = 1, max = 20, settingName = "cps"}
})

createRegisteredModule("Movement", "Velocity", false, toggleVelocity, {
    {type = "slider", name = "Horizontal %", min = 0, max = 100, settingName = "horizontalReduction"},
    {type = "slider", name = "Vertical %", min = 0, max = 100, settingName = "verticalReduction"}
})

createRegisteredModule("Movement", "LongJump", false, toggleLongJump, {
    {type = "slider", name = "Speed", min = 50, max = 200, settingName = "speed"},
    {type = "slider", name = "Duration", min = 0.5, max = 3, settingName = "duration"}
})

createRegisteredModule("Movement", "NoFallDamage", false, toggleNoFallDamage, {
    {type = "dropdown", name = "Method", options = {"Landing", "NegateVelocity", "Teleport", "DaoExploit"}, settingName = "method"}
})

createRegisteredModule("Movement", "AntiVoid", false, toggleAntiVoid, {
    {type = "dropdown", name = "Method", options = {"Normal", "Bounce"}, settingName = "method"},
    {type = "slider", name = "Bounce Power", min = 50, max = 200, settingName = "bouncePower"}
})

createRegisteredModule("Movement", "InfiniteJump", false, toggleInfiniteJump, {})

local function applyModuleToggle(moduleName, enabled)
    local handler = moduleHandlers[moduleName]
    if handler then
        handler(enabled)
    end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(refreshModuleFiltering)
updateCategoryVisuals()
refreshModuleFiltering()

closeButton.MouseButton1Click:Connect(function()
    for name, enabled in pairs(moduleStates) do
        if enabled then
            moduleStates[name] = false
            applyModuleToggle(name, false)
            if moduleUi[name] then
                moduleUi[name].setEnabled(false)
            end
        end
    end
    screenGui:Destroy()
end)

local function makeDraggable(frame, dragBar)
    local dragging = false
    local dragStart, startPos

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
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            syncShadow()
        end
    end)
end

makeDraggable(mainFrame, topBar)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if keybindListening then return end

    for moduleName, key in pairs(moduleKeybinds) do
        if input.KeyCode == key then
            local enabled = not moduleStates[moduleName]
            moduleStates[moduleName] = enabled
            if moduleUi[moduleName] then
                moduleUi[moduleName].setEnabled(enabled)
            end
            applyModuleToggle(moduleName, enabled)
            break
        end
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        guiEnabled = not guiEnabled
        screenGui.Enabled = guiEnabled
        shadow.Visible = guiEnabled
    end
end)

lplr.CharacterAdded:Connect(function()
    for name, enabled in pairs(moduleStates) do
        if enabled then
            applyModuleToggle(name, true)
        end
    end
end)
