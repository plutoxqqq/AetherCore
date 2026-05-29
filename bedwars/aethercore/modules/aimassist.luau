moduleSettings["AimAssist"] = {
    range = 30,
    prediction = 1.4,
    smoothing = 12,
    maxAngle = 85,
    sortMethod = "Angle",
    lagResolver = true,
    humanization = true,
    wallCheck = true,
    targetPlayers = true,
    targetNPCs = false,
    mode = "Smooth"
}

function toggleAimAssist(enabled)
    cleanupModule("AimAssist")
    if not enabled then return end

    local randomizer = Random.new()
    local function getSortScore(character, rootPart, sortMethod)
        local targetRoot = character:FindFirstChild("HumanoidRootPart")
        local targetHum = getHumanoid(character)
        if not targetRoot or not targetHum then
            return math.huge
        end
        if sortMethod == "Health" then
            return targetHum.Health
        elseif sortMethod == "Damage" or sortMethod == "Threat" then
            local myRoot = getHRP(getCharacter(lplr))
            return myRoot and (targetRoot.Position - myRoot.Position).Magnitude or math.huge
        end
        return math.huge
    end

    local connection = RunService.PostSimulation:Connect(function(dt)
        if not moduleStates["AimAssist"] then return end
        local character = getCharacter(lplr)
        local root = getHRP(character)
        if not (character and root) then return end

        local settings = moduleSettings["AimAssist"]
        local bestTarget, bestMetric = nil, math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and isEnemyPlayer(player) then
                local targetChar = getCharacter(player)
                local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                if targetRoot and isAliveCharacter(targetChar) then
                    local distance = (targetRoot.Position - root.Position).Magnitude
                    if distance <= (settings.range or 30) then
                        local blocked = settings.wallCheck and isTargetBehindWall(root.Position, targetRoot.Position)
                        if not blocked then
                            local metric
                            if settings.sortMethod == "Angle" then
                                local dir = (targetRoot.Position - root.Position).Unit
                                metric = math.acos(math.clamp(root.CFrame.LookVector:Dot(dir), -1, 1))
                            else
                                metric = getSortScore(targetChar, root, settings.sortMethod)
                            end
                            if metric < bestMetric then
                                bestMetric = metric
                                bestTarget = targetChar
                            end
                        end
                    end
                end
            end
        end

        if not bestTarget then return end
        local targetRoot = bestTarget:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end

        local targetPos = targetRoot.Position
        local targetVel = targetRoot.AssemblyLinearVelocity
        local predicted = targetPos + (targetVel * (settings.prediction or 1.4) * 0.035)
        if settings.lagResolver then
            predicted += targetVel * lplr:GetNetworkPing() * 0.8
        end

        local lookDir = (predicted - root.Position)
        if lookDir.Magnitude < 0.001 then return end
        local angle = math.deg(math.acos(math.clamp(root.CFrame.LookVector:Dot(lookDir.Unit), -1, 1)))
        if angle > (settings.maxAngle or 85) then return end

        local baseSmoothing = settings.mode == "Aggressive" and math.max((settings.smoothing or 12) * 1.35, 1) or (settings.smoothing or 12)
        local factor = math.clamp(baseSmoothing * dt, 0.01, 1)
        if settings.humanization then
            factor = factor * (0.85 + randomizer:NextNumber() * 0.3)
        end

        local targetCFrame = CFrame.lookAt(camera.CFrame.Position, predicted)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, factor)
    end)

    addConnection("AimAssist", connection)
end

Aether.RegisterModule({
    Name = "AimAssist",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["AimAssist"] or {},
    Start = function(ctx)
        toggleAimAssist(true)
    end,
    Stop = function(ctx)
        toggleAimAssist(false)
    end
})
