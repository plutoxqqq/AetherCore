moduleSettings["AntiHit"] = {
    slowMode = 1,
    riseWindow = 0.14,
    voidOffset = 130,
    antiDamageJitter = 2.2
}

function toggleAntiHit(enabled)
    cleanupModule("AntiHit")
    if not enabled then
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if hrp then
            hrp.Anchored = false
        end
        return
    end

    local state = {
        phase = "down",
        phaseUntil = 0,
        surfaceCFrame = nil,
        surfaceFloorY = nil,
        lastHealth = nil,
        damagePulseUntil = 0
    }

    addConnection("AntiHit", RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiHit"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end

        local settings = moduleSettings["AntiHit"]
        local now = tick()
        local downDuration = math.clamp(settings.slowMode or 1, 0.2, 5)
        local upDuration = math.clamp(settings.riseWindow or 0.14, 0.08, 0.35)
        local voidOffset = math.clamp(settings.voidOffset or 130, 60, 260)
        local jitter = math.clamp(settings.antiDamageJitter or 2.2, 0, 6)
        local currentHealth = hum.Health

        if state.lastHealth and currentHealth < state.lastHealth then
            state.damagePulseUntil = now + 1.2
        end
        state.lastHealth = currentHealth

        if state.phaseUntil <= now then
            if state.phase == "down" then
                state.phase = "up"
                state.phaseUntil = now + (state.damagePulseUntil > now and math.max(0.08, upDuration * 0.7) or upDuration)
                local surfacePosition, floorY = floorSnapPosition(hrp.Position + Vector3.new(0, 220, 0), char, 3)
                if surfacePosition then
                    state.surfaceCFrame = CFrame.new(surfacePosition)
                    state.surfaceFloorY = floorY
                elseif state.surfaceCFrame == nil then
                    state.surfaceCFrame = hrp.CFrame
                    state.surfaceFloorY = hrp.Position.Y - 3
                end
            else
                state.phase = "down"
                state.phaseUntil = now + downDuration
                local snapPosition, floorY = floorSnapPosition(hrp.Position, char, 3)
                if snapPosition then
                    state.surfaceCFrame = CFrame.new(snapPosition)
                    state.surfaceFloorY = floorY
                end
            end
        end

        if state.phase == "up" then
            hrp.Anchored = false
            if state.surfaceCFrame then
                local anchorPosition = state.surfaceCFrame.Position
                local resnapPosition = floorSnapPosition(anchorPosition + Vector3.new(0, 150, 0), char, 3)
                hrp.CFrame = CFrame.new(resnapPosition or anchorPosition)
            end
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.92, math.clamp(v.Y, -35, 70), v.Z * 0.92)
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        else
            hrp.Anchored = false
            local surface = state.surfaceCFrame and state.surfaceCFrame.Position or hrp.Position
            local floorY = state.surfaceFloorY or (surface.Y - 3)
            local timeFactor = math.sin(now * 7.2) * 0.5 + 0.5
            local yJitter = jitter * timeFactor
            local xJitter = math.sin(now * 13.1) * (jitter * 0.25)
            local zJitter = math.cos(now * 11.7) * (jitter * 0.25)
            hrp.CFrame = CFrame.new(surface.X + xJitter, floorY - voidOffset - yJitter, surface.Z + zJitter)
            hrp.AssemblyLinearVelocity = Vector3.new(0, math.min(hrp.AssemblyLinearVelocity.Y, 0), 0)
        end
    end))
end


Aether.RegisterModule({
    Name = "AntiHit",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AntiHit"] or {},
    Start = function(ctx)
        toggleAntiHit(true)
    end,
    Stop = function(ctx)
        toggleAntiHit(false)
    end
})
