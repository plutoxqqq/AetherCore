moduleSettings["Step"] = {
    maxHeight = 6,
    forwardCheckDistance = 2.6,
    stepCooldown = 0.09,
    originalStepHeight = nil,
    lastStepAt = 0
}

function toggleStep(enabled)
    cleanupModule("Step")

    local settings = moduleSettings["Step"] or {}
    settings.lastStepAt = 0

    local function setStepHeight(char, value)
        local hum = getHumanoid(char or getCharacter(lplr))
        if not hum then return end

        if enabled and settings.originalStepHeight == nil then
            settings.originalStepHeight = hum.StepHeight
        end

        hum.StepHeight = value
    end

    local function applyStepHeight(char)
        setStepHeight(char, math.clamp(tonumber(settings.maxHeight) or 6, 2, 14))
    end

    local function restoreStepHeight()
        local hum = getHumanoid(getCharacter(lplr))
        if hum and settings.originalStepHeight ~= nil then
            hum.StepHeight = settings.originalStepHeight
        elseif hum then
            hum.StepHeight = 2
        end
        settings.originalStepHeight = nil
    end

    if not enabled then
        restoreStepHeight()
        return
    end

    applyStepHeight()

    addConnection("Step", lplr.CharacterAdded:Connect(function(char)
        task.defer(function()
            if moduleStates["Step"] then
                settings.originalStepHeight = nil
                applyStepHeight(char)
            end
        end)
    end))

    addConnection("Step", RunService.Heartbeat:Connect(function()
        if not moduleStates["Step"] then return end

        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not char or not hum or not hrp or hum.Health <= 0 then return end
        if hum.Sit or hum.PlatformStand then return end
        if hum.FloorMaterial == Enum.Material.Air then return end

        local moveDir = hum.MoveDirection
        if moveDir.Magnitude < 0.05 then return end

        local flatMove = Vector3.new(moveDir.X, 0, moveDir.Z)
        if flatMove.Magnitude < 0.05 then return end
        flatMove = flatMove.Unit

        local now = tick()
        local cooldown = math.clamp(tonumber(settings.stepCooldown) or 0.09, 0.03, 0.25)
        if now - (settings.lastStepAt or 0) < cooldown then return end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        rayParams.IgnoreWater = true

        local forwardDist = math.clamp(tonumber(settings.forwardCheckDistance) or 2.6, 1.2, 5)
        local maxHeight = math.clamp(tonumber(settings.maxHeight) or 6, 2, 14)

        local wallOrigin = hrp.Position + Vector3.new(0, 1.15, 0)
        local wallHit = Workspace:Raycast(wallOrigin, flatMove * forwardDist, rayParams)
        if not wallHit or math.abs(wallHit.Normal.Y) > 0.35 then return end

        local topProbeOffset = flatMove * 1.15
        local topProbeOrigin = wallHit.Position + topProbeOffset + Vector3.new(0, maxHeight + 1.25, 0)
        local topHit = Workspace:Raycast(topProbeOrigin, Vector3.new(0, -(maxHeight + 1.6), 0), rayParams)
        if not topHit or topHit.Normal.Y < 0.55 then return end

        local targetY = topHit.Position.Y + 2.85
        local verticalDelta = targetY - hrp.Position.Y
        if verticalDelta <= 0.25 or verticalDelta > maxHeight + 3 then return end

        local targetPosition = Vector3.new(hrp.Position.X, targetY, hrp.Position.Z) + (flatMove * 0.55)
        local clearanceOrigin = targetPosition + Vector3.new(0, 2.25, 0)
        local clearanceHit = Workspace:Raycast(clearanceOrigin, Vector3.new(0, 2.6, 0), rayParams)
        if clearanceHit then return end

        settings.lastStepAt = now
        hrp.CFrame = CFrame.new(targetPosition, targetPosition + hrp.CFrame.LookVector)
    end))
end


Aether.RegisterModule({
    Name = "Step",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["Step"] or {},
    Start = function(ctx)
        toggleStep(true)
    end,
    Stop = function(ctx)
        toggleStep(false)
    end,
})
