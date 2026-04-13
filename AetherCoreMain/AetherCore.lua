-- BedWars Vape GUI - Complete & Functional
-- Press RightShift to toggle GUI
-- Features: KillAura, Reach, Speed, Fly, ESP, Tracers, AutoToxic, Nuker, Scaffold, AimAssist, AutoClicker
-- New: Velocity, LongJump, NoFallDamage, AntiVoid, InfiniteJump
-- Each module has Keybind and expandable Settings

-- ==================== SERVICES ====================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local lplr = Players.LocalPlayer
local mouse = lplr:GetMouse()
local camera = Workspace.CurrentCamera

-- ==================== STATE ====================
local moduleStates = {}          -- { [moduleName] = enabled }
local moduleConnections = {}     -- { [moduleName] = { connection1, connection2, ... } }
local moduleKeybinds = {}        -- { [moduleName] = keyCode or nil }
local moduleSettings = {}        -- { [moduleName] = { settingName = value } }
local guiEnabled = true
local autoToxicEnabled = false

-- ==================== CHAT UTILITY ====================
local function sayInChat(message)
    pcall(function()
        local channel = TextChatService.ChatInputBarConfiguration.TargetTextChannel
        if channel then
            channel:SendAsync(message)
        end
    end)
end

-- ==================== BEDWARS CONTROLLER FETCH ====================
local KnitClient, CombatController, BedwarsShopController, BlockPlacementController, ClientHandler
local resolvedCombatController, resolvedBlockPlacementController
local bedwarsNetRoot

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

local function getBedwarsNetRoot()
    if bedwarsNetRoot and bedwarsNetRoot.Parent then
        return bedwarsNetRoot
    end

    local direct = ReplicatedStorage:FindFirstChild("rbxts_include")
    if direct then
        local okPath = direct:FindFirstChild("node_modules")
        if okPath then
            local rbxts = okPath:FindFirstChild("@rbxts")
            local netFolder = rbxts and rbxts:FindFirstChild("net")
            local outFolder = netFolder and netFolder:FindFirstChild("out")
            if outFolder then
                local managed = outFolder:FindFirstChild("_NetManaged")
                if managed then
                    bedwarsNetRoot = managed
                    return managed
                end
            end
        end
    end

    local fallback = ReplicatedStorage:FindFirstChild("_NetManaged", true)
    if fallback then
        bedwarsNetRoot = fallback
    end
    return bedwarsNetRoot
end

local function getBedwarsRemote(remoteName)
    local netRoot = getBedwarsNetRoot()
    if not netRoot then
        return nil
    end
    return netRoot:FindFirstChild(remoteName, true)
end

local function fireBedwarsRemote(remoteName, payload)
    local remote = getBedwarsRemote(remoteName)
    if not remote then
        return false
    end
    local ok = pcall(function()
        remote:FireServer(payload)
    end)
    return ok
end

-- ==================== HELPER FUNCTIONS ====================
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

-- Get nearest enemy (players + NPCs) excluding teammates
local function getNearestEnemy(range, ignoreTeam)
    local myChar = getCharacter(lplr)
    if not myChar then return nil, nil end
    local myTeam = ignoreTeam and nil or lplr.Team
    local myHRP = getHRP(myChar)
    if not myHRP then return nil, nil end

    local nearest = nil
    local shortest = range or math.huge

    -- Players
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

    -- NPCs (any model with Humanoid, not belonging to a player)
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
    local targetHum = getHumanoid(targetCharacter)
    local targetRoot = getHRP(targetCharacter)

    if controller then
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

    if not attacked and targetRoot then
        attacked = fireBedwarsRemote("SwordHit", {
            entityInstance = targetCharacter,
            validate = {
                targetPosition = targetRoot.Position,
                selfPosition = char and getHRP(char) and getHRP(char).Position or targetRoot.Position
            },
            weapon = tool
        }) or attacked
    end

    if tool and not attacked then
        pcall(function()
            tool:Activate()
            attacked = true
        end)
    end

    return attacked
end

-- Safe connection management
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
    local x = mouse.X
    local y = mouse.Y
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button1Down(Vector2.new(x, y), camera.CFrame)
        VirtualUser:Button1Up(Vector2.new(x, y), camera.CFrame)
    end)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

-- ==================== SETTINGS UI HELPERS ====================
local function createSlider(parent, name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 44)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueButton = Instance.new("TextButton")
    valueButton.Size = UDim2.new(0.3, -4, 0, 20)
    valueButton.Position = UDim2.new(0.7, 4, 0, 0)
    valueButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    valueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueButton.Font = Enum.Font.Gotham
    valueButton.TextSize = 12
    valueButton.Parent = frame
    Instance.new("UICorner", valueButton).CornerRadius = UDim.new(0, 4)

    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(1, 0, 0, 18)
    slider.Position = UDim2.new(0, 0, 0, 24)
    slider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    slider.Parent = frame
    Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame")
    local range = max - min
    local percent = (default - min) / range
    fill.Size = UDim2.new(percent, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(140, 80, 255)
    fill.BorderSizePixel = 0
    fill.Parent = slider
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

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
        fill.Size = UDim2.new(newPercent, 0, 1, 0)
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
        inputBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        inputBox.Font = Enum.Font.Gotham
        inputBox.TextSize = 12
        inputBox.Text = valueButton.Text
        inputBox.ClearTextOnFocus = false
        inputBox.Parent = frame
        Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 4)
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
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 40, 0, 20)
    button.Position = UDim2.new(1, -40, 0.5, -10)
    button.BackgroundColor3 = default and Color3.fromRGB(140, 80, 255) or Color3.fromRGB(50, 50, 50)
    button.Text = default and "ON" or "OFF"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)

    local state = default
    button.MouseButton1Click:Connect(function()
        state = not state
        button.BackgroundColor3 = state and Color3.fromRGB(140, 80, 255) or Color3.fromRGB(50, 50, 50)
        button.Text = state and "ON" or "OFF"
        callback(state)
    end)

    return {
        GetValue = function() return state end,
        SetValue = function(v)
            state = v
            button.BackgroundColor3 = state and Color3.fromRGB(140, 80, 255) or Color3.fromRGB(50, 50, 50)
            button.Text = state and "ON" or "OFF"
            callback(v)
        end
    }
end

local function createDropdown(parent, name, options, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 80, 0, 20)
    button.Position = UDim2.new(1, -80, 0.5, -10)
    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    button.Text = default
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)

    local selected = default
    button.MouseButton1Click:Connect(function()
        -- Simple cycle through options
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
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 80, 0, 20)
    box.Position = UDim2.new(1, -80, 0.5, -10)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    box.Text = default
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

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

-- ==================== MODULE IMPLEMENTATIONS ====================

-- 1. KILLAURA
moduleSettings["KillAura"] = {
    attackRange = 16,
    swingsPerSecond = 10,
    faceTarget = true,
    requireWeapon = true,
    attackPlayers = true,
    attackNPCs = false,
    lineOfSight = true,
    targetPart = "HumanoidRootPart"
}

local function isSwordTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end
    local lowered = tool.Name:lower()
    return lowered:find("sword") or lowered:find("blade")
end

local function toggleKillAura(enabled)
    cleanupModule("KillAura")
    if not enabled then
        return
    end

    local lastSwingAt = 0

    local function hasLineOfSight(originPart, targetPart, ignoreList)
        if not moduleSettings["KillAura"].lineOfSight then
            return true
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = ignoreList
        local direction = targetPart.Position - originPart.Position
        local result = Workspace:Raycast(originPart.Position, direction, params)
        return (not result) or result.Instance:IsDescendantOf(targetPart.Parent)
    end

    addConnection("KillAura", RunService.Heartbeat:Connect(function()
        if not moduleStates["KillAura"] then
            return
        end

        local settings = moduleSettings["KillAura"]
        local myChar = getCharacter(lplr)
        local myRoot = getHRP(myChar)
        if not myRoot then
            return
        end

        local heldTool = myChar:FindFirstChildOfClass("Tool")
        if settings.requireWeapon and not isSwordTool(heldTool) then
            return
        end

        local targetModel = getTargetByFilters(settings.attackRange, settings.attackPlayers, settings.attackNPCs)
        if not targetModel then
            return
        end

        local desiredPart = targetModel:FindFirstChild(settings.targetPart)
            or targetModel:FindFirstChild("HumanoidRootPart")
            or targetModel:FindFirstChild("Head")
        if not desiredPart then
            return
        end

        if not hasLineOfSight(myRoot, desiredPart, {myChar, camera}) then
            return
        end

        if settings.faceTarget then
            myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(desiredPart.Position.X, myRoot.Position.Y, desiredPart.Position.Z))
        end

        local interval = 1 / math.max(settings.swingsPerSecond, 1)
        local now = tick()
        if now - lastSwingAt >= interval then
            lastSwingAt = now
            attackTargetWithBedwarsApi(targetModel)
            if heldTool then
                pcall(function()
                    heldTool:Activate()
                end)
            end
        end
    end))
end

-- 2. REACH
moduleSettings["Reach"] = {
    mode = "Hybrid",
    combatReach = 15,
    miningReach = 12,
    placementReach = 12,
    visibleHandle = false
}

local function toggleReach(enabled)
    cleanupModule("Reach")

    local function forEachTool(callback)
        local char = getCharacter(lplr)
        local backpack = lplr:FindFirstChildOfClass("Backpack")
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") then callback(item) end
            end
        end
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then callback(item) end
            end
        end
    end

    local function restoreTool(tool)
        if not tool:IsA("Tool") then return end
        local originalGrip = tool:FindFirstChild("AetherOriginalGripPos")
        if originalGrip then
            tool.GripPos = originalGrip.Value
            originalGrip:Destroy()
        end
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            local originalSize = handle:FindFirstChild("AetherOriginalHandleSize")
            if originalSize then
                handle.Size = originalSize.Value
                originalSize:Destroy()
            end
            handle.Massless = false
            handle.CanCollide = true
            handle.Transparency = 0
        end
    end

    local function applyToolReach(tool, rangeValue)
        if not tool:IsA("Tool") then return end
        local handle = tool:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then return end

        if not tool:FindFirstChild("AetherOriginalGripPos") then
            local holder = Instance.new("Vector3Value")
            holder.Name = "AetherOriginalGripPos"
            holder.Value = tool.GripPos
            holder.Parent = tool
        end
        if not handle:FindFirstChild("AetherOriginalHandleSize") then
            local sizeHolder = Instance.new("Vector3Value")
            sizeHolder.Name = "AetherOriginalHandleSize"
            sizeHolder.Value = handle.Size
            sizeHolder.Parent = handle
        end

        local zSize = math.clamp(rangeValue, 4, 25)
        handle.Size = Vector3.new(math.max(2, handle.Size.X), math.max(2, handle.Size.Y), zSize)
        handle.Massless = true
        handle.CanCollide = false
        handle.Transparency = moduleSettings["Reach"].visibleHandle and 0.35 or 1
        tool.GripPos = Vector3.new(tool.GripPos.X, tool.GripPos.Y, -math.max(rangeValue - 4, 0))
    end

    if not enabled then
        lplr:SetAttribute("Reach", nil)
        forEachTool(restoreTool)
        return
    end

    local function applyReach()
        if not moduleStates["Reach"] then return end
        local settings = moduleSettings["Reach"]
        local maxReach = math.max(settings.combatReach, settings.miningReach, settings.placementReach)

        if settings.mode == "Attribute" or settings.mode == "Hybrid" then
            lplr:SetAttribute("Reach", maxReach)
        else
            lplr:SetAttribute("Reach", nil)
        end

        forEachTool(function(tool)
            if settings.mode == "Handle" or settings.mode == "Hybrid" then
                applyToolReach(tool, maxReach)
            else
                restoreTool(tool)
            end
        end)
    end

    applyReach()
    addConnection("Reach", RunService.Heartbeat:Connect(applyReach))
    addConnection("Reach", lplr.CharacterAdded:Connect(function()
        task.wait(0.2)
        applyReach()
    end))

    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if backpack then
        addConnection("Reach", backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.wait()
                applyReach()
            end
        end))
    end
end

-- 3. SPEED (with configurable speed value)
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

-- 4. FLY (horizontal level maintained, with TP down)
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

        -- Horizontal (flatten camera vectors)
        local camLook = camera.CFrame.LookVector
        local camRight = camera.CFrame.RightVector
        local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
        local flatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += flatRight end

        -- Vertical
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

        -- TP Down
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

-- 5. ESP
local function removeEspFromModel(model)
    local existing = model and model:FindFirstChild("ESP_Highlight")
    if existing and existing:IsA("Highlight") then
        existing:Destroy()
    end
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

    local function addOrRepairESP(model, isEnemyPlayer)
        if not model then return end
        if isEnemyPlayer == false then
            removeEspFromModel(model)
            return
        end

        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            removeEspFromModel(model)
            return
        end

        local highlight = model:FindFirstChild("ESP_Highlight")
        if not highlight or not highlight:IsA("Highlight") then
            removeEspFromModel(model)
            highlight = Instance.new("Highlight")
            highlight.Name = "ESP_Highlight"
            highlight.Parent = model
        end

        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = model
        highlight.Enabled = true
    end

    local function refreshESP()
        if not moduleStates["ESP"] then return end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                addOrRepairESP(player.Character, player.Team ~= lplr.Team)
            end
        end

        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model ~= lplr.Character then
                local hum = model:FindFirstChildOfClass("Humanoid")
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hum and hrp then
                    local isPlayerChar = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then
                            isPlayerChar = true
                            break
                        end
                    end
                    if not isPlayerChar then
                        addOrRepairESP(model, true)
                    end
                end
            end
        end
    end

    refreshESP()
    addConnection("ESP", RunService.Heartbeat:Connect(refreshESP))
end

-- 6. TRACERS (works on NPCs too, transparency setting)
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
        addConnection("Tracers_" .. model:GetFullName(), updateConn)
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

-- 7. AUTO TOXIC
moduleSettings["AutoToxic"] = {
    finalKillMessage = "Good fight.",
    bedBreakMessage = "Your bed is gone.",
    gameWinMessage = "Good game.",
    enabledFinalKill = true,
    enabledBedBreak = true,
    enabledGameWin = true,
    minDelaySeconds = 1.4
}

local function setupAutoToxic()
    local lastSentAt = 0
    if not (TextChatService and TextChatService.MessageReceived) then
        return
    end

    TextChatService.MessageReceived:Connect(function(message)
        if not autoToxicEnabled then
            return
        end

        local settings = moduleSettings["AutoToxic"]
        if (tick() - lastSentAt) < math.max(settings.minDelaySeconds, 0.5) then
            return
        end

        local text = (message.Text or ""):lower()
        local username = lplr.Name:lower()
        local displayName = (lplr.DisplayName or ""):lower()
        local mentionsMe = text:find(username, 1, true) or (displayName ~= "" and text:find(displayName, 1, true))

        local isFinalKillEvent = mentionsMe and settings.enabledFinalKill
            and (text:find("final kill", 1, true) or text:find("final eliminated", 1, true))
            and (text:find("bed", 1, true) or text:find("no bed", 1, true) or text:find("without a bed", 1, true))

        if isFinalKillEvent then
            sayInChat(settings.finalKillMessage)
            lastSentAt = tick()
            return
        end

        local isMyBedBreakEvent = settings.enabledBedBreak
            and (text:find(username .. " broke", 1, true) or (displayName ~= "" and text:find(displayName .. " broke", 1, true)))
            and text:find("bed", 1, true)

        if isMyBedBreakEvent then
            sayInChat(settings.bedBreakMessage)
            lastSentAt = tick()
            return
        end

        local isVictory = settings.enabledGameWin
            and (text:find("victory", 1, true) or text:find("you win", 1, true) or text:find("winner", 1, true))
            and not text:find("defeat", 1, true)
            and not text:find("lost", 1, true)

        if isVictory then
            sayInChat(settings.gameWinMessage)
            lastSentAt = tick()
        end
    end)
end
setupAutoToxic()

-- 8. NUKER
moduleSettings["Nuker"] = {
    mineBeds = true,
    mineIron = true,
    mineRadius = 18,
    targetProtectedBeds = true
}

local function scoreBlockForNuker(part, rootPos)
    local distance = (part.Position - rootPos).Magnitude
    local name = part.Name:lower()
    if name == "bed" then
        return 1000 - distance
    end
    if name:find("iron") and name:find("ore") then
        return 500 - distance
    end
    return -math.huge
end

local function toggleNuker(enabled)
    cleanupModule("Nuker")
    if not enabled then return end

    local lastMineAt = 0

    addConnection("Nuker", RunService.Heartbeat:Connect(function()
        if not moduleStates["Nuker"] then return end
        if tick() - lastMineAt < 0.08 then return end

        local settings = moduleSettings["Nuker"]
        local myRoot = getHRP(getCharacter(lplr))
        if not myRoot then return end

        local best, bestScore
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = obj.Name:lower()
                local isBed = settings.mineBeds and n == "bed"
                local isIron = settings.mineIron and n:find("iron") and n:find("ore")
                if (isBed or isIron) and (myRoot.Position - obj.Position).Magnitude <= settings.mineRadius then
                    local score = scoreBlockForNuker(obj, myRoot.Position)
                    if not bestScore or score > bestScore then
                        best = obj
                        bestScore = score
                    end
                end
            end
        end

        if not best then return end

        local targetQueue = {best}
        if settings.targetProtectedBeds and best.Name:lower() == "bed" then
            for _, obj in ipairs(Workspace:GetPartBoundsInRadius(best.Position, 6)) do
                if obj:IsA("BasePart") and obj.CanCollide and obj.Name:lower() ~= "bed" then
                    table.insert(targetQueue, obj)
                end
            end
            table.sort(targetQueue, function(a, b)
                return (a.Position - myRoot.Position).Magnitude < (b.Position - myRoot.Position).Magnitude
            end)
        end

        for _, block in ipairs(targetQueue) do
            local remoteName = block.Name:lower() == "bed" and "DamageBlock" or "BreakBlock"
            local fired = fireBedwarsRemote(remoteName, {blockRef = block, position = block.Position})
            if fired then
                lastMineAt = tick()
                break
            end
        end
    end))
end

-- 9. SCAFFOLD
moduleSettings["Scaffold"] = {
    allowPillaring = true
}

local function isBlockTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local lowered = tool.Name:lower()
    return lowered:find("wool") or lowered:find("clay") or lowered:find("concrete") or lowered:find("plank")
end

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
    else return "wool_white" end
end

local function toggleScaffold(enabled)
    cleanupModule("Scaffold")
    if not enabled then return end

    local lastPlaceAt = 0
    addConnection("Scaffold", RunService.Heartbeat:Connect(function()
        if not moduleStates["Scaffold"] then return end
        if tick() - lastPlaceAt < 0.08 then return end

        local char = getCharacter(lplr)
        local root = getHRP(char)
        local hum = getHumanoid(char)
        local held = char and char:FindFirstChildOfClass("Tool")
        if not root or not hum or not isBlockTool(held) then return end

        local placePos = root.Position - Vector3.new(0, 3.1, 0)
        if moduleSettings["Scaffold"].allowPillaring and hum:GetState() == Enum.HumanoidStateType.Jumping then
            placePos = root.Position - Vector3.new(0, 1.2, 0)
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.FilterDescendantsInstances = {char}
        if Workspace:Raycast(placePos + Vector3.new(0, 2.2, 0), Vector3.new(0, -3.5, 0), rayParams) then
            return
        end

        local blockPos = Vector3.new(math.floor(placePos.X / 3) * 3, math.floor(placePos.Y / 3) * 3, math.floor(placePos.Z / 3) * 3)
        local placed = fireBedwarsRemote("PlaceBlock", {
            blockType = getTeamWoolName(),
            position = blockPos
        })

        if not placed then
            local blockController = getBlockPlacementController()
            local placeFn = blockController and (blockController.placeBlock or blockController.PlaceBlock)
            if type(placeFn) == "function" then
                pcall(function()
                    placeFn(blockController, CFrame.new(blockPos))
                    placed = true
                end)
            end
        end

        if placed then
            lastPlaceAt = tick()
        end
    end))
end

-- 10. AIM ASSIST
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
        local nearest = getTargetByFilters(settings.range, true, false)
        if not nearest then return end

        local root = getHRP(nearest)
        local myRoot = getHRP(getCharacter(lplr))
        if not root or not myRoot then return end

        local current = camera.CFrame
        local targetLook = CFrame.lookAt(current.Position, root.Position)
        local alpha = math.clamp(settings.speed * deltaTime * 60, 0.02, 0.35)
        camera.CFrame = current:Lerp(targetLook, alpha)
    end)
    addConnection("AimAssist", connection)
end

-- 11. AUTO CLICKER
moduleSettings["AutoClicker"] = {
    cps = 14,
    weaponOnly = false
}

local function toggleAutoClicker(enabled)
    cleanupModule("AutoClicker")
    if not enabled then
        return
    end

    local mouseHeld = false
    local lastClickAt = 0

    addConnection("AutoClicker", UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseHeld = true
        end
    end))

    addConnection("AutoClicker", UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            mouseHeld = false
        end
    end))

    addConnection("AutoClicker", RunService.RenderStepped:Connect(function()
        if not moduleStates["AutoClicker"] or not mouseHeld then return end

        local settings = moduleSettings["AutoClicker"]
        local char = getCharacter(lplr)
        local tool = char and char:FindFirstChildOfClass("Tool")
        if settings.weaponOnly and not isSwordTool(tool) then
            return
        end

        local now = tick()
        local interval = 1 / math.max(settings.cps, 1)
        if now - lastClickAt < interval then
            return
        end
        lastClickAt = now

        performPrimaryClick()
        if tool then
            pcall(function() tool:Activate() end)
        end
    end))
end

-- 12. VELOCITY
moduleSettings["Velocity"] = {
    horizontalPercent = 100,
    verticalPercent = 100,
    reactionWindow = 0.45,
    velocitySpikeThreshold = 18
}

local function toggleVelocity(enabled)
    cleanupModule("Velocity")
    if not enabled then return end

    local function bindCharacter(char)
        local hum = char:WaitForChild("Humanoid")
        local root = char:WaitForChild("HumanoidRootPart")
        local recentlyDamagedUntil = 0

        addConnection("Velocity", hum.HealthChanged:Connect(function(newHealth)
            if newHealth < hum.MaxHealth then
                recentlyDamagedUntil = tick() + moduleSettings["Velocity"].reactionWindow
            end
        end))

        addConnection("Velocity", RunService.Heartbeat:Connect(function()
            if not moduleStates["Velocity"] or not root.Parent then return end

            local v = root.AssemblyLinearVelocity
            local settings = moduleSettings["Velocity"]
            local horizontalMag = Vector2.new(v.X, v.Z).Magnitude
            local suddenImpulse = horizontalMag >= settings.velocitySpikeThreshold or v.Y > 20
            local damageWindow = tick() <= recentlyDamagedUntil

            if not suddenImpulse and not damageWindow then
                return
            end

            local hMul = math.clamp(1 - (settings.horizontalPercent / 100), 0, 1)
            local vMul = math.clamp(1 - (settings.verticalPercent / 100), 0, 1)
            local y = v.Y
            if y > 0 then
                y = y * vMul
            end
            root.AssemblyLinearVelocity = Vector3.new(v.X * hMul, y, v.Z * hMul)
        end))
    end

    if lplr.Character then bindCharacter(lplr.Character) end
    addConnection("Velocity", lplr.CharacterAdded:Connect(bindCharacter))
end

-- 13. LONGJUMP
moduleSettings["LongJump"] = {
    horizontalSpeed = 90,
    verticalBoost = 30,
    boostDuration = 0.65,
    cooldown = 0.75
}

local function isHeldDao(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    return n == "stone_dao" or n == "iron_dao"
end

local function toggleLongJump(enabled)
    cleanupModule("LongJump")
    if not enabled then return end

    local boostingUntil = 0
    local cooldownUntil = 0

    addConnection("LongJump", UserInputService.JumpRequest:Connect(function()
        if not moduleStates["LongJump"] or tick() < cooldownUntil then return end

        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local root = getHRP(char)
        local held = char and char:FindFirstChildOfClass("Tool")
        if not hum or not root or not isHeldDao(held) then return end

        useDaoAbility()

        local settings = moduleSettings["LongJump"]
        local lookFlat = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        local dir = hum.MoveDirection.Magnitude > 0 and hum.MoveDirection.Unit or (lookFlat.Magnitude > 0 and lookFlat.Unit or Vector3.new(0, 0, -1))
        root.AssemblyLinearVelocity = Vector3.new(dir.X * settings.horizontalSpeed, settings.verticalBoost, dir.Z * settings.horizontalSpeed)
        boostingUntil = tick() + settings.boostDuration
        cooldownUntil = tick() + settings.cooldown
    end))

    addConnection("LongJump", RunService.Heartbeat:Connect(function()
        if not moduleStates["LongJump"] or tick() > boostingUntil then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local root = getHRP(char)
        local held = char and char:FindFirstChildOfClass("Tool")
        if not hum or not root or not isHeldDao(held) then return end

        local settings = moduleSettings["LongJump"]
        local lookFlat = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
        local dir = hum.MoveDirection.Magnitude > 0 and hum.MoveDirection.Unit or (lookFlat.Magnitude > 0 and lookFlat.Unit or Vector3.new(0, 0, -1))
        local currentY = root.AssemblyLinearVelocity.Y
        root.AssemblyLinearVelocity = Vector3.new(dir.X * settings.horizontalSpeed, math.max(currentY, settings.verticalBoost * 0.35), dir.Z * settings.horizontalSpeed)
    end))
end

-- 14. NOFALLDAMAGE
moduleSettings["NoFallDamage"] = {
    method = "BruteForce Mode",
    triggerVelocity = -42,
    releaseHeight = 8,
    chargeSeconds = 0.55
}

local function toggleNoFallDamage(enabled)
    cleanupModule("NoFallDamage")
    if not enabled then return end

    local function bindCharacter(char)
        local hum = char:WaitForChild("Humanoid")
        local root = char:WaitForChild("HumanoidRootPart")
        local charging = false

        addConnection("NoFallDamage", RunService.Heartbeat:Connect(function()
            if not moduleStates["NoFallDamage"] or not root.Parent then return end

            local settings = moduleSettings["NoFallDamage"]
            local velocityY = root.AssemblyLinearVelocity.Y
            local hit = Workspace:Raycast(root.Position, Vector3.new(0, -45, 0))

            if settings.method == "DaoExploit Mode" then
                local dao = getHeldOrBackpackDaoTool()
                if not dao then return end

                if velocityY <= settings.triggerVelocity and not charging then
                    charging = true
                    if dao.Parent ~= char then
                        hum:EquipTool(dao)
                    end
                    pcall(function() dao:Activate() end)
                end

                if charging and hit and (root.Position.Y - hit.Position.Y) <= settings.releaseHeight then
                    charging = false
                    pcall(function() dao:Activate() end)
                    performPrimaryClick()
                end
                return
            end

            if velocityY <= settings.triggerVelocity then
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X * 0.6, -1, root.AssemblyLinearVelocity.Z * 0.6)
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                if hit and (root.Position.Y - hit.Position.Y) <= 5 then
                    root.CFrame = CFrame.new(root.Position.X, hit.Position.Y + 3.8, root.Position.Z)
                end
            end
        end))
    end

    if lplr.Character then bindCharacter(lplr.Character) end
    addConnection("NoFallDamage", lplr.CharacterAdded:Connect(bindCharacter))
end

-- 15. ANTIVOID
moduleSettings["AntiVoid"] = {
    mode = "Smart Recovery",
    triggerOffset = 36,
    refreshInterval = 1.5
}

local function createAntiVoidVisual()
    local marker = Instance.new("Part")
    marker.Name = "AntiVoidIndicator"
    marker.Anchored = true
    marker.CanCollide = false
    marker.Size = Vector3.new(10, 0.35, 10)
    marker.Material = Enum.Material.Neon
    marker.Color = Color3.fromRGB(255, 70, 70)
    marker.Transparency = 0.45
    marker.Parent = Workspace
    return marker
end

local function findNearestSafeLand(origin, blacklist)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = blacklist or {}

    local bestPos
    local bestDist
    local offsets = {
        Vector3.new(0, 0, 0), Vector3.new(12, 0, 0), Vector3.new(-12, 0, 0),
        Vector3.new(0, 0, 12), Vector3.new(0, 0, -12), Vector3.new(24, 0, 0),
        Vector3.new(-24, 0, 0), Vector3.new(0, 0, 24), Vector3.new(0, 0, -24)
    }

    for _, offset in ipairs(offsets) do
        local castOrigin = origin + offset + Vector3.new(0, 80, 0)
        local hit = Workspace:Raycast(castOrigin, Vector3.new(0, -220, 0), params)
        if hit then
            local candidate = hit.Position + Vector3.new(0, 4, 0)
            local dist = (candidate - origin).Magnitude
            if not bestDist or dist < bestDist then
                bestDist = dist
                bestPos = candidate
            end
        end
    end

    return bestPos
end

local function toggleAntiVoid(enabled)
    cleanupModule("AntiVoid")
    local oldVisual = Workspace:FindFirstChild("AntiVoidIndicator")
    if oldVisual then
        oldVisual:Destroy()
    end
    if not enabled then return end

    local marker = createAntiVoidVisual()
    local safeGroundY
    local lastRefresh = 0

    local function refreshGroundReference(root)
        local hit = Workspace:Raycast(root.Position + Vector3.new(0, 30, 0), Vector3.new(0, -200, 0))
        if hit then
            safeGroundY = hit.Position.Y
            lastRefresh = tick()
        end
    end

    addConnection("AntiVoid", lplr.CharacterAdded:Connect(function(char)
        local root = getHRP(char)
        if root then
            task.wait(0.2)
            refreshGroundReference(root)
        end
    end))

    addConnection("AntiVoid", RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiVoid"] then return end
        local char = getCharacter(lplr)
        local root = getHRP(char)
        if not root then return end

        if not safeGroundY or (tick() - lastRefresh > moduleSettings["AntiVoid"].refreshInterval) then
            refreshGroundReference(root)
        end
        if not safeGroundY then return end

        local triggerY = safeGroundY - moduleSettings["AntiVoid"].triggerOffset
        marker.Position = Vector3.new(root.Position.X, triggerY, root.Position.Z)
        if root.Position.Y > triggerY then return end

        local targetLand = findNearestSafeLand(root.Position, {char})
        if not targetLand then return end

        if moduleSettings["AntiVoid"].mode == "Smart Recovery" then
            local mid = Vector3.new(root.Position.X, targetLand.Y, root.Position.Z)
            root.CFrame = CFrame.new(mid)
            task.wait()
            root.CFrame = CFrame.new(targetLand)
        else
            root.CFrame = CFrame.new(targetLand)
        end
        root.AssemblyLinearVelocity = Vector3.zero
        refreshGroundReference(root)
    end))
end

-- 16. INFINITE JUMP
moduleSettings["InfiniteJump"] = {
    tpDownEnabled = false,
    tpDownInterval = 2.5,
    tpDownAirStart = nil
}

local function toggleInfiniteJump(enabled)
    cleanupModule("InfiniteJump")
    if not enabled then
        return
    end

    addConnection("InfiniteJump", UserInputService.JumpRequest:Connect(function()
        if moduleStates["InfiniteJump"] and lplr.Character then
            local hum = getHumanoid(lplr.Character)
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end))

    addConnection("InfiniteJump", RunService.Heartbeat:Connect(function()
        if not moduleStates["InfiniteJump"] then return end
        local settings = moduleSettings["InfiniteJump"]
        if not settings.tpDownEnabled then
            settings.tpDownAirStart = nil
            return
        end

        local char = getCharacter(lplr)
        local root = getHRP(char)
        local hum = getHumanoid(char)
        if not root or not hum then return end

        local now = tick()
        local isAirborne = hum.FloorMaterial == Enum.Material.Air or hum:GetState() == Enum.HumanoidStateType.Freefall
        if isAirborne then
            settings.tpDownAirStart = settings.tpDownAirStart or now
            if now - settings.tpDownAirStart >= settings.tpDownInterval then
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {char}
                local ray = Workspace:Raycast(root.Position, Vector3.new(0, -120, 0), raycastParams)
                if ray then
                    root.CFrame = CFrame.new(ray.Position + Vector3.new(0, 2.5, 0))
                    root.AssemblyLinearVelocity = Vector3.zero
                end
                settings.tpDownAirStart = now
            end
        else
            settings.tpDownAirStart = nil
        end
    end))
end

-- ==================== GUI CONSTRUCTION ====================
-- (GUI code remains similar but enhanced with settings panel for each module)
-- We'll provide the complete GUI creation with dynamic settings.

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VapeUtility"
screenGui.ResetOnSpawn = false
screenGui.Parent = lplr:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 1000, 0, 520)
mainFrame.Position = UDim2.new(0.5, -500, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(19, 19, 19)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 48)
topBar.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 140, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "AetherCore"
title.TextColor3 = Color3.fromRGB(180, 80, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local uninjectButton = Instance.new("TextButton")
uninjectButton.Size = UDim2.new(0, 110, 0, 30)
uninjectButton.Position = UDim2.new(1, -130, 0.5, -15)
uninjectButton.BackgroundColor3 = Color3.fromRGB(120, 45, 45)
uninjectButton.Text = "Uninject"
uninjectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
uninjectButton.Font = Enum.Font.GothamBold
uninjectButton.TextSize = 13
uninjectButton.Parent = topBar
Instance.new("UICorner", uninjectButton).CornerRadius = UDim.new(0, 8)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 160, 1, -48)
sidebar.Position = UDim2.new(0, 0, 0, 48)
sidebar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Padding = UDim.new(0, 2)
sidebarLayout.Parent = sidebar

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -160, 1, -48)
contentArea.Position = UDim2.new(0, 160, 0, 48)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local contentScroller = Instance.new("ScrollingFrame")
contentScroller.Size = UDim2.new(1, 0, 1, 0)
contentScroller.Position = UDim2.new(0, 0, 0, 0)
contentScroller.BackgroundTransparency = 1
contentScroller.BorderSizePixel = 0
contentScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
contentScroller.ScrollBarThickness = 4
contentScroller.ScrollingDirection = Enum.ScrollingDirection.X
contentScroller.AutomaticCanvasSize = Enum.AutomaticSize.X
contentScroller.Parent = contentArea

local columnsList = Instance.new("UIListLayout")
columnsList.FillDirection = Enum.FillDirection.Horizontal
columnsList.SortOrder = Enum.SortOrder.LayoutOrder
columnsList.Padding = UDim.new(0, 10)
columnsList.Parent = contentScroller

local categories = {"Combat", "Blatant", "Render", "Utility", "World", "Legit", "Movement"}
local columns = {}
local columnOrder = 0

local function createCategory(name)
    local defaultOpen = false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 46)
    btn.BackgroundColor3 = defaultOpen and Color3.fromRGB(32, 32, 32) or Color3.fromRGB(22, 22, 22)
    btn.BorderSizePixel = 0
    btn.Text = "  " .. name
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 15
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar

    local highlight = Instance.new("Frame")
    highlight.Name = "Highlight"
    highlight.Size = UDim2.new(0, 4, 1, 0)
    highlight.BackgroundColor3 = Color3.fromRGB(180, 80, 255)
    highlight.BorderSizePixel = 0
    highlight.Visible = defaultOpen
    highlight.Parent = btn

    local column = Instance.new("Frame")
    column.Name = name
    column.Size = UDim2.new(0, 200, 1, 0)
    column.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
    column.BorderSizePixel = 0
    column.Visible = defaultOpen
    column.LayoutOrder = columnOrder
    column.Parent = contentScroller

    Instance.new("UICorner", column).CornerRadius = UDim.new(0, 10)

    local colTitle = Instance.new("TextLabel")
    colTitle.Size = UDim2.new(1, 0, 0, 42)
    colTitle.BackgroundTransparency = 1
    colTitle.Text = name
    colTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    colTitle.Font = Enum.Font.GothamBold
    colTitle.TextSize = 16
    colTitle.Parent = column

    local layout = Instance.new("UIListLayout")
    layout.Name = "ModuleList"
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = column

    columns[name] = column
    columnOrder += 1

    btn.MouseButton1Click:Connect(function()
        column.Visible = not column.Visible
        highlight.Visible = column.Visible
        btn.BackgroundColor3 = column.Visible and Color3.fromRGB(32, 32, 32) or Color3.fromRGB(22, 22, 22)
    end)
end

for _, cat in ipairs(categories) do
    createCategory(cat)
end

-- Module creation with Keybind and dynamic Settings
local keybindListening = false
local currentModuleForKeybind = nil
local keybindButton = nil

local function createModule(parent, name, defaultEnabled, toggleCallback, settingsDefinition)
    local frame = Instance.new("Frame")
    frame.Name = name .. "Module"
    frame.Size = UDim2.new(1, -16, 0, 58)
    frame.BackgroundColor3 = defaultEnabled and Color3.fromRGB(140, 80, 255) or Color3.fromRGB(35, 35, 35)
    frame.BorderSizePixel = 0
    frame.LayoutOrder = #parent:GetChildren()
    frame.Parent = parent

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 58)
    header.BackgroundTransparency = 1
    header.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = header

    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(1, -90, 1, 0)
    toggleButton.BackgroundTransparency = 1
    toggleButton.Text = ""
    toggleButton.Parent = header

    -- Keybind display button
    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(0, 30, 0, 30)
    keybindBtn.Position = UDim2.new(1, -80, 0.5, -15)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    keybindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindBtn.Text = moduleKeybinds[name] and moduleKeybinds[name].Name or "🔑"
    keybindBtn.Font = Enum.Font.Gotham
    keybindBtn.TextSize = 14
    keybindBtn.Parent = header
    Instance.new("UICorner", keybindBtn).CornerRadius = UDim.new(0, 6)

    keybindBtn.MouseButton1Click:Connect(function()
        if keybindListening then return end
        keybindListening = true
        currentModuleForKeybind = name
        keybindButton = keybindBtn
        keybindBtn.Text = "..."
        keybindBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 255)

        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                if moduleKeybinds[name] == key then
                    moduleKeybinds[name] = nil
                    keybindBtn.Text = "🔑"
                else
                    moduleKeybinds[name] = key
                    keybindBtn.Text = key.Name
                end
                keybindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                keybindListening = false
                currentModuleForKeybind = nil
                keybindButton = nil
                conn:Disconnect()
            end
        end)
    end)

    -- Settings button
    local settingsBtn = Instance.new("TextButton")
    settingsBtn.Size = UDim2.new(0, 30, 0, 30)
    settingsBtn.Position = UDim2.new(1, -40, 0.5, -15)
    settingsBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    settingsBtn.Text = "⚙"
    settingsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    settingsBtn.Font = Enum.Font.GothamBold
    settingsBtn.TextSize = 24
    settingsBtn.Parent = header
    Instance.new("UICorner", settingsBtn).CornerRadius = UDim.new(0, 6)

    -- Settings panel (hidden initially)
    local settingsPanel = Instance.new("Frame")
    settingsPanel.Name = "SettingsPanel"
    settingsPanel.Size = UDim2.new(1, 0, 0, 0)
    settingsPanel.Position = UDim2.new(0, 0, 0, 58)
    settingsPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    settingsPanel.BorderSizePixel = 0
    settingsPanel.ClipsDescendants = true
    settingsPanel.Visible = true
    settingsPanel.Parent = frame

    Instance.new("UICorner", settingsPanel).CornerRadius = UDim.new(0, 6)
    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 4)
    settingsLayout.Parent = settingsPanel

    -- Populate settings based on definition
    local settingControls = {}
    if settingsDefinition then
        for _, setting in ipairs(settingsDefinition) do
            if setting.type == "slider" then
                local ctrl = createSlider(settingsPanel, setting.name, setting.min, setting.max, moduleSettings[name][setting.settingName], function(val)
                    moduleSettings[name][setting.settingName] = val
                end)
                table.insert(settingControls, ctrl)
            elseif setting.type == "toggle" then
                local ctrl = createToggle(settingsPanel, setting.name, moduleSettings[name][setting.settingName], function(val)
                    moduleSettings[name][setting.settingName] = val
                end)
                table.insert(settingControls, ctrl)
            elseif setting.type == "dropdown" then
                local ctrl = createDropdown(settingsPanel, setting.name, setting.options, moduleSettings[name][setting.settingName], function(val)
                    moduleSettings[name][setting.settingName] = val
                end)
                table.insert(settingControls, ctrl)
            elseif setting.type == "textbox" then
                local ctrl = createTextBox(settingsPanel, setting.name, moduleSettings[name][setting.settingName], function(val)
                    moduleSettings[name][setting.settingName] = val
                end)
                table.insert(settingControls, ctrl)
            end
        end
    end

    local settingsOpen = false
    settingsBtn.MouseButton1Click:Connect(function()
        settingsOpen = not settingsOpen
        local targetHeight = 0
        if settingsOpen then
            task.wait()
            targetHeight = settingsLayout.AbsoluteContentSize.Y + 8
        end
        TweenService:Create(settingsPanel, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = UDim2.new(1, -16, 0, 58 + targetHeight)}):Play()
    end)

    local enabled = defaultEnabled
    moduleStates[name] = enabled

    local function updateVisual()
        frame.BackgroundColor3 = enabled and Color3.fromRGB(140, 80, 255) or Color3.fromRGB(35, 35, 35)
    end

    local toggleDebounce = false
    toggleButton.MouseButton1Click:Connect(function()
        if toggleDebounce then return end
        toggleDebounce = true
        enabled = not enabled
        moduleStates[name] = enabled
        updateVisual()
        if name == "AutoToxic" then
            autoToxicEnabled = enabled
        end
        if toggleCallback then
            toggleCallback(enabled)
        end
        task.delay(0.1, function()
            toggleDebounce = false
        end)
    end)

    frame.MouseEnter:Connect(function()
        if not enabled then
            TweenService:Create(frame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}):Play()
        end
    end)
    frame.MouseLeave:Connect(updateVisual)

    updateVisual()
    if defaultEnabled and toggleCallback then
        toggleCallback(true)
    end
end

-- Define modules with settings
createModule(columns["Combat"], "KillAura", false, toggleKillAura, {
    {type = "toggle", name = "Face Target", settingName = "faceTarget"},
    {type = "slider", name = "Attack Range", min = 5, max = 25, settingName = "attackRange"},
    {type = "slider", name = "Swings/Sec", min = 1, max = 20, settingName = "swingsPerSecond"},
    {type = "toggle", name = "Require Weapon", settingName = "requireWeapon"},
    {type = "toggle", name = "Attack Players", settingName = "attackPlayers"},
    {type = "toggle", name = "Attack NPCs", settingName = "attackNPCs"},
    {type = "toggle", name = "Line Of Sight", settingName = "lineOfSight"},
    {type = "dropdown", name = "Target Part", options = {"HumanoidRootPart", "Head", "UpperTorso"}, settingName = "targetPart"}
})

createModule(columns["Combat"], "Reach", false, toggleReach, {
    {type = "dropdown", name = "Mode", options = {"Hybrid", "Attribute", "Handle"}, settingName = "mode"},
    {type = "slider", name = "Combat Reach", min = 6, max = 25, settingName = "combatReach"},
    {type = "slider", name = "Mining Reach", min = 6, max = 25, settingName = "miningReach"},
    {type = "slider", name = "Placement Reach", min = 6, max = 25, settingName = "placementReach"},
    {type = "toggle", name = "Visible Handle", settingName = "visibleHandle"}
})

createModule(columns["Blatant"], "Speed", false, toggleSpeed, {
    {type = "slider", name = "Speed", min = 16, max = 50, settingName = "speed"}
})

createModule(columns["Blatant"], "Fly", false, toggleFly, {
    {type = "slider", name = "Horizontal Speed", min = 10, max = 100, settingName = "horizontalSpeed"},
    {type = "slider", name = "Vertical Speed", min = 10, max = 100, settingName = "verticalSpeed"},
    {type = "toggle", name = "TP Down", settingName = "tpDownEnabled"},
    {type = "slider", name = "TP Interval", min = 1, max = 5, settingName = "tpDownInterval"},
    {type = "slider", name = "TP Return Delay", min = 0.05, max = 1, settingName = "tpDownReturnDelay"}
})

createModule(columns["Render"], "ESP", false, toggleESP, {})

createModule(columns["Render"], "Tracers", false, toggleTracers, {
    {type = "slider", name = "Transparency", min = 0, max = 1, settingName = "transparency"}
})

createModule(columns["Utility"], "AutoToxic", false, nil, {
    {type = "toggle", name = "Final Kill Message", settingName = "enabledFinalKill"},
    {type = "textbox", name = "Final Kill Text", settingName = "finalKillMessage"},
    {type = "toggle", name = "Bed Break Message", settingName = "enabledBedBreak"},
    {type = "textbox", name = "Bed Break Text", settingName = "bedBreakMessage"},
    {type = "toggle", name = "Game Win Message", settingName = "enabledGameWin"},
    {type = "textbox", name = "Game Win Text", settingName = "gameWinMessage"},
    {type = "slider", name = "Delay (s)", min = 0.5, max = 5, settingName = "minDelaySeconds"}
})

createModule(columns["World"], "Nuker", false, toggleNuker, {
    {type = "toggle", name = "Mine Beds", settingName = "mineBeds"},
    {type = "toggle", name = "Mine Iron", settingName = "mineIron"},
    {type = "toggle", name = "Target Protected Beds", settingName = "targetProtectedBeds"},
    {type = "slider", name = "Radius", min = 5, max = 20, settingName = "mineRadius"}
})

createModule(columns["World"], "Scaffold", false, toggleScaffold, {
    {type = "toggle", name = "Allow Pillaring", settingName = "allowPillaring"}
})

createModule(columns["Legit"], "AimAssist", false, toggleAimAssist, {
    {type = "slider", name = "Speed", min = 0.01, max = 0.5, settingName = "speed"},
    {type = "slider", name = "Range", min = 10, max = 50, settingName = "range"}
})

createModule(columns["Legit"], "AutoClicker", false, toggleAutoClicker, {
    {type = "slider", name = "CPS", min = 1, max = 25, settingName = "cps"},
    {type = "toggle", name = "Weapon Only", settingName = "weaponOnly"}
})

createModule(columns["Movement"], "Velocity", false, toggleVelocity, {
    {type = "slider", name = "Horizontal %", min = 0, max = 100, settingName = "horizontalPercent"},
    {type = "slider", name = "Vertical %", min = 0, max = 100, settingName = "verticalPercent"},
    {type = "slider", name = "Reaction Window", min = 0.05, max = 1, settingName = "reactionWindow"},
    {type = "slider", name = "Spike Threshold", min = 1, max = 20, settingName = "velocitySpikeThreshold"}
})

createModule(columns["Movement"], "LongJump", false, toggleLongJump, {
    {type = "slider", name = "Horizontal Speed", min = 40, max = 220, settingName = "horizontalSpeed"},
    {type = "slider", name = "Vertical Boost", min = 0, max = 90, settingName = "verticalBoost"},
    {type = "slider", name = "Boost Duration", min = 0.1, max = 2, settingName = "boostDuration"},
    {type = "slider", name = "Cooldown", min = 0.1, max = 3, settingName = "cooldown"}
})

createModule(columns["Movement"], "NoFallDamage", false, toggleNoFallDamage, {
    {type = "dropdown", name = "Method", options = {"BruteForce Mode", "DaoExploit Mode"}, settingName = "method"},
    {type = "slider", name = "Trigger Velocity", min = -100, max = -20, settingName = "triggerVelocity"},
    {type = "slider", name = "Release Height", min = 3, max = 25, settingName = "releaseHeight"},
    {type = "slider", name = "Charge Seconds", min = 0.2, max = 1.2, settingName = "chargeSeconds"}
})

createModule(columns["Movement"], "AntiVoid", false, toggleAntiVoid, {
    {type = "dropdown", name = "Mode", options = {"Smart Recovery", "Instant Recovery"}, settingName = "mode"},
    {type = "slider", name = "Trigger Offset", min = 15, max = 80, settingName = "triggerOffset"},
    {type = "slider", name = "Refresh Interval", min = 0.2, max = 5, settingName = "refreshInterval"}
})

createModule(columns["Movement"], "InfiniteJump", false, toggleInfiniteJump, {
    {type = "toggle", name = "TP Down", settingName = "tpDownEnabled"},
    {type = "slider", name = "TP Interval", min = 1, max = 5, settingName = "tpDownInterval"}
})

local function applyModuleToggle(moduleName, enabled)
    if moduleName == "KillAura" then toggleKillAura(enabled)
    elseif moduleName == "Reach" then toggleReach(enabled)
    elseif moduleName == "Speed" then toggleSpeed(enabled)
    elseif moduleName == "Fly" then toggleFly(enabled)
    elseif moduleName == "ESP" then toggleESP(enabled)
    elseif moduleName == "Tracers" then toggleTracers(enabled)
    elseif moduleName == "AutoToxic" then autoToxicEnabled = enabled
    elseif moduleName == "Nuker" then toggleNuker(enabled)
    elseif moduleName == "Scaffold" then toggleScaffold(enabled)
    elseif moduleName == "AimAssist" then toggleAimAssist(enabled)
    elseif moduleName == "AutoClicker" then toggleAutoClicker(enabled)
    elseif moduleName == "Velocity" then toggleVelocity(enabled)
    elseif moduleName == "LongJump" then toggleLongJump(enabled)
    elseif moduleName == "NoFallDamage" then toggleNoFallDamage(enabled)
    elseif moduleName == "AntiVoid" then toggleAntiVoid(enabled)
    elseif moduleName == "InfiniteJump" then toggleInfiniteJump(enabled)
    end
end

uninjectButton.MouseButton1Click:Connect(function()
    for name, enabled in pairs(moduleStates) do
        if enabled then
            moduleStates[name] = false
            applyModuleToggle(name, false)
        end
    end
    screenGui:Destroy()
end)

-- ==================== DRAGGING ====================
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
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

makeDraggable(mainFrame, topBar)
for _, col in pairs(columns) do
    makeDraggable(col, col:FindFirstChildWhichIsA("TextLabel"))
end

-- ==================== KEYBIND HANDLER ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if keybindListening then return end

    for moduleName, key in pairs(moduleKeybinds) do
        if input.KeyCode == key then
            local enabled = not moduleStates[moduleName]
            moduleStates[moduleName] = enabled
            for _, col in pairs(columns) do
                local moduleFrame = col:FindFirstChild(moduleName .. "Module")
                if moduleFrame then
                    moduleFrame.BackgroundColor3 = enabled and Color3.fromRGB(140, 80, 255) or Color3.fromRGB(35, 35, 35)
                end
            end
            applyModuleToggle(moduleName, enabled)
            break
        end
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        guiEnabled = not guiEnabled
        screenGui.Enabled = guiEnabled
    end
end)

-- ==================== RESPAWN HANDLING ====================
lplr.CharacterAdded:Connect(function(char)
    for name, enabled in pairs(moduleStates) do
        if enabled then
            applyModuleToggle(name, true)
        end
    end
end)
