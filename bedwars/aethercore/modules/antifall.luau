moduleSettings["AntiFall"] = {
    mode = "Collide",
    yOffset = 10,
    recoverySpeed = 22,
    visible = false
}

local function destroyAntiFallPart()
    if moduleRuntime.AntiFallPart then
        moduleRuntime.AntiFallPart:Destroy()
        moduleRuntime.AntiFallPart = nil
    end
end

local function toggleAntiFall(enabled)
    cleanupModule("AntiFall")
    destroyAntiFallPart()
    if not enabled then
        moduleRuntime.AntiFallDirection = nil
        return
    end

    local part = Instance.new("Part")
    part.Name = "AetherCoreAntiFallPart"
    part.Size = Vector3.new(10000, 1, 10000)
    part.Anchored = true
    part.CanQuery = false
    part.CanTouch = true
    part.Material = Enum.Material.ForceField
    part.Color = Color3.fromRGB(120, 85, 255)
    part.Transparency = moduleSettings["AntiFall"].visible and 0.55 or 1
    part.Parent = Workspace
    moduleRuntime.AntiFallPart = part
    addConnection("AntiFall", function()
        destroyAntiFallPart()
    end)

    addConnection("AntiFall", RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiFall"] then return end
        local char = getCharacter(lplr)
        local root = getHRP(char)
        if not root then return end

        local settings = moduleSettings["AntiFall"] or {}
        local ground = raycastToGround(root.Position + Vector3.new(0, 12, 0), {char, part}, 240)
        local floorY = ground and ground.Position.Y or (root.Position.Y - math.max(6, tonumber(settings.yOffset) or 10))
        part.Position = Vector3.new(0, floorY - math.max(2, tonumber(settings.yOffset) or 10), 0)
        part.CanCollide = tostring(settings.mode or "Collide") == "Collide"
        part.Transparency = settings.visible and 0.55 or 1

        if root.Position.Y <= part.Position.Y + 5 then
            local velocity = root.AssemblyLinearVelocity
            local moveDirection = getHumanoid(char) and getHumanoid(char).MoveDirection or Vector3.zero
            root.AssemblyLinearVelocity = Vector3.new(
                moveDirection.X * (tonumber(settings.recoverySpeed) or 22),
                math.max(34, velocity.Y),
                moveDirection.Z * (tonumber(settings.recoverySpeed) or 22)
            )
        end
    end))
end

Aether.RegisterModule({
    Name = "AntiFall",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["AntiFall"] or {},
    Start = function(ctx)
        toggleAntiFall(true)
    end,
    Stop = function(ctx)
        toggleAntiFall(false)
    end
})
