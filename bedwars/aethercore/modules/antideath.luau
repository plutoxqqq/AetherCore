moduleSettings["AntiDeath"] = {
    healthThreshold = 25,
    belowDuration = 2,
    slowMode = 1.5,
    voidOffset = 130
}

function floorSnapPosition(origin, character, yOffset)
    local offset = yOffset or 3
    local ray = raycastToGround(origin + Vector3.new(0, 80, 0), {character}, 420)
    if ray then
        return ray.Position + Vector3.new(0, offset, 0), ray.Position.Y
    end
    local sampled = findNearestGroundPosition(origin, character, 14, 7, offset)
    return sampled, sampled and (sampled.Y - offset) or nil
end

function toggleAntiDeath(enabled)
    cleanupModule("AntiDeath")
    if not enabled then
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if hrp then
            hrp.Anchored = false
        end
        return
    end

    local state = {
        phase = "up",
        phaseUntil = 0,
        anchorCFrame = nil,
        anchorFloorY = nil
    }

    addConnection("AntiDeath", RunService.Heartbeat:Connect(function()
        if not moduleStates["AntiDeath"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        local hrp = getHRP(char)
        if not hum or not hrp or hum.Health <= 0 then return end
        local settings = moduleSettings["AntiDeath"]
        local now = tick()
        local lowHealth = hum.Health <= settings.healthThreshold

        if not lowHealth then
            if state.phase == "down" and state.anchorCFrame then
                local anchorPosition = state.anchorCFrame.Position
                local floorPosition = floorSnapPosition(anchorPosition + Vector3.new(0, 200, 0), char, 3)
                hrp.Anchored = false
                hrp.CFrame = CFrame.new(floorPosition or anchorPosition)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                task.wait()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            else
                hrp.Anchored = false
            end
            state.phase = "up"
            state.phaseUntil = 0
            state.anchorCFrame = nil
            state.anchorFloorY = nil
            return
        end

        if state.phaseUntil <= now then
            if state.phase == "up" then
                state.phase = "down"
                state.phaseUntil = now + settings.belowDuration
                state.anchorCFrame = hrp.CFrame
                local floorPosition, floorY = floorSnapPosition(hrp.Position, char, 3)
                if floorPosition then
                    state.anchorCFrame = CFrame.new(floorPosition)
                end
                state.anchorFloorY = floorY
            else
                state.phase = "up"
                state.phaseUntil = now + settings.slowMode
            end
        end

        if state.phase == "down" then
            local anchor = state.anchorCFrame or hrp.CFrame
            hrp.Anchored = true
            local floorY = state.anchorFloorY or (anchor.Position.Y - 3)
            hrp.CFrame = CFrame.new(anchor.Position.X, floorY - settings.voidOffset, anchor.Position.Z)
            hrp.AssemblyLinearVelocity = Vector3.zero
        else
            hrp.Anchored = false
            if state.anchorCFrame then
                local anchorPosition = state.anchorCFrame.Position
                local floorPosition = floorSnapPosition(anchorPosition + Vector3.new(0, 200, 0), char, 3)
                hrp.CFrame = CFrame.new(floorPosition or anchorPosition)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hum:ChangeState(Enum.HumanoidStateType.Landed)
                task.wait()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end))
end


Aether.RegisterModule({
    Name = "AntiDeath",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["AntiDeath"] or {},
    Start = function(ctx)
        toggleAntiDeath(true)
    end,
    Stop = function(ctx)
        toggleAntiDeath(false)
    end
})
