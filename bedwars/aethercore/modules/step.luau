moduleSettings["Step"] = {
    maxHeight = 6,
    forwardCheckDistance = 2.6,
    stepCooldown = 0.09
}

function toggleStep(enabled)
    cleanupModule("Step")
    moduleSettings["Step"].lastStepAt = 0

    local function applyStep(char)
        char = char or getCharacter(lplr)
        local hum = getHumanoid(char)
        if hum then
            hum.StepHeight = enabled and math.clamp(moduleSettings["Step"].maxHeight or 6, 2, 14) or 2
        end
    end

    if not enabled then
        applyStep()
        return
    end

    applyStep()
    addConnection("Step", lplr.CharacterAdded:Connect(function(char)
        applyStep(char)
    end))

    addConnection("Step", RunService.Heartbeat:Connect(function()
        if not moduleStates["Step"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end

        if hum.MoveDirection.Magnitude < 0.05 then return end

        local settings = moduleSettings["Step"] or {}
        local now = tick()
        local cooldown = math.clamp(settings.stepCooldown or 0.09, 0.03, 0.25)
        if now - (settings.lastStepAt or 0) < cooldown then return end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        rayParams.IgnoreWater = true

        local moveDir = hum.MoveDirection.Unit
        local forwardDist = math.clamp(settings.forwardCheckDistance or 2.6, 1.2, 5)

        local wallHit = Workspace:Raycast(hrp.Position + Vector3.new(0, 1.2, 0), moveDir * forwardDist, rayParams)
        if not wallHit or math.abs(wallHit.Normal.Y) > 0.35 then return end

        local maxHeight = math.clamp(settings.maxHeight or 6, 2, 14)
        local probeOrigin = wallHit.Position + Vector3.new(0, maxHeight + 1.1, 0)
        local surfaceHit = Workspace:Raycast(probeOrigin, Vector3.new(0, -(maxHeight + 0.6), 0), rayParams)
        if not surfaceHit or surfaceHit.Normal.Y < 0.5 then return end

        local verticalDelta = surfaceHit.Position.Y - hrp.Position.Y
        if verticalDelta <= 0.4 or verticalDelta > maxHeight then return end
        local clearanceHit = Workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, verticalDelta + 0.6, 0), rayParams)
        if clearanceHit then return end

        settings.lastStepAt = now

        hrp.CFrame = hrp.CFrame + Vector3.new(0, verticalDelta, 0)
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
    end
})
