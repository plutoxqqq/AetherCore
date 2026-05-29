moduleSettings["SafeWalk"] = {
    mode = "Normal",
    maxDrop = 4.5
}

function toggleSafeWalk(enabled)
    cleanupModule("SafeWalk")
    if not enabled then return end

    addConnection("SafeWalk", RunService.Heartbeat:Connect(function()
        if not moduleStates["SafeWalk"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end

        local moveDirection = hum.MoveDirection
        if moveDirection.Magnitude < 0.02 then return end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        rayParams.IgnoreWater = true

        local settings = moduleSettings["SafeWalk"] or {}
        local maxDrop = math.clamp(tonumber(settings.maxDrop) or 4.5, 1, 20)
        local probeDirection = Vector3.new(moveDirection.X, 0, moveDirection.Z)
        if probeDirection.Magnitude < 0.01 then return end
        local probeOrigin = hrp.Position + (probeDirection.Unit * 1.7) + Vector3.new(0, 0.5, 0)
        local edgeRay = Workspace:Raycast(probeOrigin, Vector3.new(0, -maxDrop, 0), rayParams)
        if edgeRay then return end
        local vel = hrp.AssemblyLinearVelocity
        hrp.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
    end))
end


Aether.RegisterModule({
    Name = "SafeWalk",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["SafeWalk"] or {},
    Start = function(ctx)
        toggleSafeWalk(true)
    end,
    Stop = function(ctx)
        toggleSafeWalk(false)
    end
})
