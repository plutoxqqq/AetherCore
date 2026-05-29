moduleSettings["Velocity"] = {
    direction = "Random",
    chance = 100,
    onlyWhenTargeting = false,
    horizontalReduction = 100,
    verticalReduction = 100
}

function rotateYVector(v, deg)
    local r = math.rad(deg)
    return Vector3.new(
        v.X * math.cos(r) - v.Z * math.sin(r),
        0,
        v.X * math.sin(r) + v.Z * math.cos(r)
    )
end

function toggleVelocity(enabled)
    cleanupModule("Velocity")
    if not enabled then return end

    local randomizer = Random.new()
    local function applyVelocity(char)
        local hum = getHumanoid(char)
        local root = getHRP(char)
        if not hum or not root then return end

        local recentlyDamagedUntil = 0
        local lastHealth = hum.Health
        addConnection("Velocity", hum.HealthChanged:Connect(function(newHealth)
            if newHealth < lastHealth then
                recentlyDamagedUntil = tick() + 0.35
            end
            lastHealth = newHealth
        end))

        addConnection("Velocity", RunService.Heartbeat:Connect(function()
            if not moduleStates["Velocity"] or not root.Parent or tick() > recentlyDamagedUntil then return end
            local settings = moduleSettings["Velocity"]
            if randomizer:NextNumber(0, 100) > (settings.chance or 100) then return end

            if settings.onlyWhenTargeting then
                local target = getNearestEnemy(50, settings.wallCheck ~= true)
                if not target then return end
            end

            local current = root.AssemblyLinearVelocity
            local flat = Vector3.new(current.X, 0, current.Z)
            if flat.Magnitude < 0.001 then return end
            local awayVec = flat.Unit

            local chosen = settings.direction or "Random"
            if chosen == "Random" then
                local options = {"Left", "Right", "Pull"}
                chosen = options[randomizer:NextInteger(1, #options)]
            end

            local desiredAway = awayVec
            if chosen == "Left" then
                desiredAway = rotateYVector(awayVec, 90)
            elseif chosen == "Right" then
                desiredAway = rotateYVector(awayVec, -90)
            elseif chosen == "Pull" then
                desiredAway = -awayVec
            end

            local speed = flat.Magnitude
            local redirected = desiredAway * speed
            root.AssemblyLinearVelocity = Vector3.new(redirected.X, current.Y, redirected.Z)
        end))
    end

    if lplr.Character then applyVelocity(lplr.Character) end
    addConnection("Velocity", lplr.CharacterAdded:Connect(applyVelocity))
end

Aether.RegisterModule({
    Name = "Velocity",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["Velocity"] or {},
    Start = function(ctx)
        toggleVelocity(true)
    end,
    Stop = function(ctx)
        toggleVelocity(false)
    end
})
