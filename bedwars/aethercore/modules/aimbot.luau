moduleSettings["Aimbot"] = {
    enabled = true,
    fov = 160,
    smoothness = 0.55,
    snapStrength = 0.85,
    wallCheck = true,
    teamCheck = true,
    targetPart = "Head",
    maxDistance = 260,
    targetNPCs = true,
    predictionStrength = 1,
    arrowSpeed = 185,
    gravity = Workspace.Gravity
}

function getAimbotTargetPart(character, requestedPart)
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

function getProjectileVelocityEstimate(targetCharacter)
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

function solveProjectileLead(origin, targetPosition, targetVelocity, projectileSpeed, gravity, predictionStrength)
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

function isVisibleForAimbot(targetCharacter, requestedPart)
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

function getAimbotCandidates(includeNPCs)
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

function toggleAimbot(enabled)
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

        local targetViewportPoint, isOnScreen = camera:WorldToViewportPoint(predictedPosition)
        if mouseMoveRelative and isOnScreen then
            local viewportCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            local offset = Vector2.new(targetViewportPoint.X, targetViewportPoint.Y) - viewportCenter
            local smoothness = math.clamp(settings.smoothness or 0.55, 0.01, 1)
            local snapStrength = math.clamp(settings.snapStrength or 0.85, 0.1, 1)
            local interpolation = math.clamp((smoothness * snapStrength) * (deltaTime * 60), 0.05, 1)
            mouseMoveRelative(offset.X * interpolation, offset.Y * interpolation)
            return
        end

        local lookAtCFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + desiredDirection)
        local smoothness = math.clamp(settings.smoothness or 0.55, 0.01, 1)
        local alpha = math.clamp((smoothness * 1.35) * (deltaTime * 60), 0.06, 1)
        camera.CFrame = camera.CFrame:Lerp(lookAtCFrame, alpha)
    end))
end


Aether.RegisterModule({
    Name = "Aimbot",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["Aimbot"] or {},
    Start = function(ctx)
        toggleAimbot(true)
    end,
    Stop = function(ctx)
        toggleAimbot(false)
    end
})
