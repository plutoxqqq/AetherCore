moduleSettings["AntiVoid"] = {
    method = "Normal",
    bouncePower = 100
}

function createAntiVoidVisual()
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

function toggleAntiVoid(enabled)
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
    local lastRescueUpdate = 0

    local function refreshVoidReference()
        local myChar = getCharacter(lplr)
        local hrp = getHRP(myChar)
        if not myChar or not hrp then
            return
        end
        local groundPos = findNearestGroundPosition(hrp.Position, myChar, 12, 6, 0)
        local referenceY = groundPos and groundPos.Y or hrp.Position.Y
        voidTriggerY = referenceY - 38
    end

    local function findRescueTarget(origin, character)
        local best = nil
        local bestScore = math.huge
        for radius = 12, 96, 12 do
            local candidate = findNearestGroundPosition(origin, character, radius, 6, 3)
            if candidate then
                local planarDistance = (Vector3.new(origin.X, 0, origin.Z) - Vector3.new(candidate.X, 0, candidate.Z)).Magnitude
                local heightPenalty = math.max(0, origin.Y - candidate.Y)
                local score = planarDistance + (heightPenalty * 0.25)
                if score < bestScore then
                    bestScore = score
                    best = candidate
                end
            end
        end
        return best
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
                if not rescueTarget or tick() - lastRescueUpdate > 0.4 then
                    rescueTarget = findRescueTarget(hrp.Position, myChar)
                    lastRescueUpdate = tick()
                end
                if rescueTarget then
                    hrp.CFrame = CFrame.new(rescueTarget + Vector3.new(0, 2, 0))
                    if pullVelocity then
                        pullVelocity:Destroy()
                    end
                    pullVelocity = Instance.new("BodyVelocity")
                    pullVelocity.Name = "AntiVoidPull"
                    pullVelocity.MaxForce = Vector3.new(2e5, 9e4, 2e5)
                    pullVelocity.Parent = hrp
                end
            elseif method == "Bounce" then
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, moduleSettings["AntiVoid"].bouncePower, hrp.AssemblyLinearVelocity.Z)
            end
        end

        if pullVelocity and rescueTarget then
            local goal = Vector3.new(rescueTarget.X, hrp.Position.Y, rescueTarget.Z)
            local planarDelta = goal - Vector3.new(hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
            local upwardAssist = hrp.Position.Y < rescueTarget.Y + 3 and 10 or 0
            local planarVelocity = planarDelta.Magnitude > 0.5 and planarDelta.Unit * 22 or Vector3.zero
            pullVelocity.Velocity = Vector3.new(planarVelocity.X, upwardAssist, planarVelocity.Z)
            local closeToGround = hrp.Position.Y <= rescueTarget.Y + 5
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

Aether.RegisterModule({
    Name = "AntiVoid",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AntiVoid"] or {},
    Start = function(ctx)
        toggleAntiVoid(true)
    end,
    Stop = function(ctx)
        toggleAntiVoid(false)
    end
})
