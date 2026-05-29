moduleSettings["VerticalFly"] = {
    horizontalSpeed = 28,
    verticalSpeed = 45,
    groundOffset = 3.2,
    antiKickSink = 1.4
}

function toggleVerticalFly(enabled)
    cleanupModule("VerticalFly")
    local state = moduleSettings["VerticalFly"]

    local function resetCameraOffset()
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        if hum then
            hum.CameraOffset = Vector3.zero
        end
    end

    if not enabled then
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        resetCameraOffset()
        if state then
            state.virtualAltitude = 0
        end
        if hrp and state and state.lastVisualPosition then
            hrp.CFrame = CFrame.new(state.lastVisualPosition)
        end
        if hrp then
            local mover = hrp:FindFirstChild("VerticalFlyVelocity")
            if mover then mover:Destroy() end
        end
        return
    end

    local function ensureMover()
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if not hrp then return nil end
        local mover = hrp:FindFirstChild("VerticalFlyVelocity") or Instance.new("BodyVelocity")
        mover.Name = "VerticalFlyVelocity"
        mover.MaxForce = Vector3.new(9e4, 9e4, 9e4)
        mover.P = 8e3
        mover.Velocity = Vector3.zero
        mover.Parent = hrp
        return mover, hrp, char
    end

    addConnection("VerticalFly", RunService.Heartbeat:Connect(function(dt)
        if not moduleStates["VerticalFly"] then return end
        local mover, hrp, char = ensureMover()
        if not mover or not hrp then return end
        local settings = moduleSettings["VerticalFly"]

        local cameraLook = camera.CFrame.LookVector
        local cameraRight = camera.CFrame.RightVector
        local flatLook = Vector3.new(cameraLook.X, 0, cameraLook.Z)
        local flatRight = Vector3.new(cameraRight.X, 0, cameraRight.Z)
        flatLook = flatLook.Magnitude > 0 and flatLook.Unit or Vector3.new(0, 0, -1)
        flatRight = flatRight.Magnitude > 0 and flatRight.Unit or Vector3.new(1, 0, 0)

        local moveDirection = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection += flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection -= flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection -= flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection += flatRight end

        local planarMove = Vector3.new(moveDirection.X, 0, moveDirection.Z)
        if planarMove.Magnitude > 1 then
            planarMove = planarMove.Unit
        end

        local verticalInput = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            verticalInput += 1
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            verticalInput -= 1
        end

        local hum = getHumanoid(char)
        if hum then
            hum.CameraOffset = Vector3.zero
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end

        local horizontalSpeed = math.clamp(settings.horizontalSpeed or 28, 5, 80)
        local verticalSpeed = math.clamp(settings.verticalSpeed or 45, 8, 120)
        local antiKickSink = math.clamp(settings.antiKickSink or 1.4, 0, 6)

        local desiredVelocity = Vector3.new(planarMove.X * horizontalSpeed, verticalInput * verticalSpeed, planarMove.Z * horizontalSpeed)
        if verticalInput == 0 then
            desiredVelocity = Vector3.new(desiredVelocity.X, -antiKickSink, desiredVelocity.Z)
        end
        mover.Velocity = desiredVelocity
        state.lastVisualPosition = hrp.Position
    end))
end


Aether.RegisterModule({
    Name = "VerticalFly [bro this thing cooked]",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["VerticalFly"] or {},
    Start = function(ctx)
        toggleVerticalFly(true)
    end,
    Stop = function(ctx)
        toggleVerticalFly(false)
    end
})
