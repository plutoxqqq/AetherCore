moduleSettings["Speed"] = { speed = 23 }

function toggleSpeed(enabled)
    cleanupModule("Speed")
    if not enabled then
        local hum = getHumanoid(getCharacter(lplr))
        if hum then hum:SetAttribute("AetherSpeedEnabled", false) end
        return
    end

    local function markSpeedState(char)
        local hum = getHumanoid(char)
        if hum then hum:SetAttribute("AetherSpeedEnabled", true) end
    end

    local function applySpeed()
        if not moduleStates["Speed"] or moduleStates["Sprint"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude < 0.01 then return end
        local direction = Vector3.new(moveDir.X, 0, moveDir.Z)
        if direction.Magnitude < 0.001 then return end
        local horizontalTarget = direction.Unit * math.clamp(tonumber((moduleSettings["Speed"] or {}).speed) or 23, 16, 80)
        local currentVel = hrp.AssemblyLinearVelocity
        local currentHorizontal = Vector3.new(currentVel.X, 0, currentVel.Z)
        local nextHorizontal = currentHorizontal:Lerp(horizontalTarget, 0.35)
        hrp.AssemblyLinearVelocity = Vector3.new(nextHorizontal.X, currentVel.Y, nextHorizontal.Z)
    end

    markSpeedState(getCharacter(lplr))
    addConnection("Speed", lplr.CharacterAdded:Connect(function(char)
        task.defer(markSpeedState, char)
    end))
    addConnection("Speed", RunService.Heartbeat:Connect(applySpeed))
end


Aether.RegisterModule({
    Name = "Speed",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["Speed"] or {},
    Start = function(ctx)
        toggleSpeed(true)
    end,
    Stop = function(ctx)
        toggleSpeed(false)
    end
})
