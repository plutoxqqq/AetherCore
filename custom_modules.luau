-- Optional extension point loaded after universal and game-specific modules.
return function(context)
    local vape = shared and shared.vape
    local categories = vape and vape.Categories
    local category = categories and (categories.Utility or categories.Render or categories.World)

    if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
        return false, "module category is unavailable"
    end

    local playersService = game:GetService("Players")
    local inputService = game:GetService("UserInputService")
    local runService = game:GetService("RunService")
    local localPlayer = playersService.LocalPlayer

    if not localPlayer then
        return false, "LocalPlayer is unavailable"
    end

    local state = context.CustomModules or {}
    context.CustomModules = state

    local boostState = state.GBoost or {
        Enabled = false,
        Boosting = false,
        Speed = 250,
        StopDistance = 2,
        Connections = {},
        OriginalCollisions = {}
    }
    state.GBoost = boostState

    local function disconnect(connectionName)
        local connection = boostState[connectionName]
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
        boostState[connectionName] = nil
    end

    local function getCharacterRoot()
        local character = localPlayer.Character
        if not character then
            return nil
        end
        return character:FindFirstChild("HumanoidRootPart")
    end

    local function getTargetBlock()
        local mouse = localPlayer:GetMouse()
        local target = mouse and mouse.Target
        if not target or not target:IsA("BasePart") then
            return nil
        end

        local character = localPlayer.Character
        if character and target:IsDescendantOf(character) then
            return nil
        end

        return target.CanCollide and target or nil
    end

    local function getLandingPoint(block)
        local mouse = localPlayer:GetMouse()
        local hit = mouse.Hit.Position
        local position = block.Position
        local size = block.Size
        local dx, dy, dz = hit.X - position.X, hit.Y - position.Y, hit.Z - position.Z
        local ax, ay, az = math.abs(dx), math.abs(dy), math.abs(dz)
        local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2

        if ay > ax and ay > az then
            return Vector3.new(hit.X, position.Y + (dy > 0 and hy + 0.1 or -hy - 0.1), hit.Z)
        end

        if ax > ay and ax > az then
            return Vector3.new(position.X + (dx > 0 and hx + 0.1 or -hx - 0.1), hit.Y, hit.Z)
        end

        return Vector3.new(hit.X, hit.Y, position.Z + (dz > 0 and hz + 0.1 or -hz - 0.1))
    end

    local function setNoclip(enabled)
        local character = localPlayer.Character
        if not character then
            return
        end

        if enabled then
            table.clear(boostState.OriginalCollisions)
            for _, descendant in ipairs(character:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    boostState.OriginalCollisions[descendant] = descendant.CanCollide
                    descendant.CanCollide = false
                end
            end
            return
        end

        for part, canCollide in pairs(boostState.OriginalCollisions) do
            if part and part.Parent then
                part.CanCollide = canCollide
            end
        end
        table.clear(boostState.OriginalCollisions)
    end

    local function setStatus(text, color)
        if boostState.StatusLabel then
            boostState.StatusLabel.Text = text
            boostState.StatusLabel.TextColor3 = color
        end
    end

    local function cleanup()
        disconnect("BoostConnection")
        if boostState.BodyVelocity then
            boostState.BodyVelocity:Destroy()
            boostState.BodyVelocity = nil
        end
        setNoclip(false)
        boostState.Boosting = false
        if boostState.Enabled then
            setStatus("Ready", Color3.fromRGB(100, 255, 100))
        end
    end

    local function startBoost()
        if not boostState.Enabled or boostState.Boosting then
            return
        end

        local block = getTargetBlock()
        if not block then
            setStatus("Aim at a solid block", Color3.fromRGB(255, 100, 100))
            task.delay(0.5, function()
                if boostState.Enabled and not boostState.Boosting then
                    setStatus("Ready", Color3.fromRGB(100, 255, 100))
                end
            end)
            return
        end

        local root = getCharacterRoot()
        if not root then
            return
        end

        local target = getLandingPoint(block)
        local direction = target - root.Position
        if direction.Magnitude <= boostState.StopDistance then
            return
        end

        setNoclip(true)
        boostState.Boosting = true
        setStatus(string.format("Boosting: %.0f studs", direction.Magnitude), Color3.fromRGB(255, 200, 100))

        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bodyVelocity.Velocity = direction.Unit * boostState.Speed
        bodyVelocity.Parent = root
        boostState.BodyVelocity = bodyVelocity

        boostState.BoostConnection = runService.RenderStepped:Connect(function()
            local currentRoot = getCharacterRoot()
            if not boostState.Boosting or not currentRoot or not boostState.BodyVelocity then
                cleanup()
                return
            end

            local remainingVector = target - currentRoot.Position
            local remainingDistance = remainingVector.Magnitude
            if remainingDistance <= boostState.StopDistance then
                currentRoot.AssemblyLinearVelocity = Vector3.zero
                cleanup()
                return
            end

            boostState.BodyVelocity.Velocity = remainingVector.Unit * boostState.Speed
            setStatus(string.format("Boosting: %.0f studs", remainingDistance), Color3.fromRGB(255, 200, 100))
        end)

        task.delay(5, function()
            if boostState.Boosting then
                cleanup()
            end
        end)
    end

    local function createStatusGui()
        if boostState.ScreenGui then
            boostState.ScreenGui:Destroy()
            boostState.ScreenGui = nil
        end

        local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            return
        end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "AetherGBoostStatus"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui

        local label = Instance.new("TextLabel")
        label.Name = "Status"
        label.Size = UDim2.fromOffset(180, 32)
        label.Position = UDim2.fromOffset(10, 10)
        label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        label.BackgroundTransparency = 0.1
        label.BorderSizePixel = 0
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 13
        label.Text = "Ready"
        label.TextColor3 = Color3.fromRGB(100, 255, 100)
        label.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = label

        boostState.ScreenGui = screenGui
        boostState.StatusLabel = label
    end

    local function updateFeedback()
        if not boostState.Enabled or boostState.Boosting then
            return
        end

        local block = getTargetBlock()
        local root = getCharacterRoot()
        if block and root then
            local target = getLandingPoint(block)
            setStatus(string.format("Target: %.0f studs", (target - root.Position).Magnitude), Color3.fromRGB(100, 255, 100))
        else
            setStatus("No solid block", Color3.fromRGB(255, 100, 100))
        end
    end

    category:CreateModule({
        Name = "G Boost",
        Tooltip = "Press G while aiming at a solid block to boost to the selected surface with temporary noclip.",
        Function = function(enabled)
            boostState.Enabled = enabled
            if enabled then
                createStatusGui()
                setStatus("Ready", Color3.fromRGB(100, 255, 100))
                boostState.InputConnection = inputService.InputBegan:Connect(function(input, gameProcessed)
                    if not gameProcessed and input.KeyCode == Enum.KeyCode.G then
                        startBoost()
                    end
                end)
                boostState.FeedbackConnection = runService.RenderStepped:Connect(updateFeedback)
            else
                disconnect("InputConnection")
                disconnect("FeedbackConnection")
                cleanup()
                if boostState.ScreenGui then
                    boostState.ScreenGui:Destroy()
                    boostState.ScreenGui = nil
                    boostState.StatusLabel = nil
                end
            end
        end
    })

    return true
end
