moduleSettings["ProjectileAimbot"] = {
    range = 120,
    fov = 90,
    prediction = 0.18,
    requireLineOfSight = true
}

local function aimProjectileAtTarget(target)
    local targetPart = getTargetAimPart(target)
    if not targetPart then return end
    local settings = moduleSettings["ProjectileAimbot"] or {}
    local predicted = targetPart.Position + (targetPart.AssemblyLinearVelocity * math.clamp(tonumber(settings.prediction) or 0.18, 0, 1))
    local camPosition = camera.CFrame.Position
    camera.CFrame = CFrame.lookAt(camPosition, predicted)
end

function toggleProjectileAimbot(enabled)
    cleanupModule("ProjectileAimbot")
    if not enabled then return end
    addConnection("ProjectileAimbot", RunService.RenderStepped:Connect(function()
        if not moduleStates["ProjectileAimbot"] then return end
        local held = getCharacter(lplr) and getCharacter(lplr):FindFirstChildOfClass("Tool")
        local heldName = held and held.Name:lower() or ""
        if not (heldName:find("bow", 1, true) or heldName:find("crossbow", 1, true) or heldName:find("snowball", 1, true) or heldName:find("fireball", 1, true)) then
            return
        end
        local settings = moduleSettings["ProjectileAimbot"] or {}
        local target = getNearestEnemy(math.clamp(tonumber(settings.range) or 120, 16, 250), true)
        if target and isTargetWithinFov(target, tonumber(settings.fov) or 90) and (settings.requireLineOfSight ~= true or hasLineOfSight(target)) then
            aimProjectileAtTarget(target)
        end
    end))
end

Aether.RegisterModule({
    Name = "ProjectileAimbot",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["ProjectileAimbot"] or {},
    Start = function(ctx)
        toggleProjectileAimbot(true)
    end,
    Stop = function(ctx)
        toggleProjectileAimbot(false)
    end
})
