function toggleAntiAFK(enabled)
    if enabled then
        moduleConnections["AntiAFKPulse"] = moduleConnections["AntiAFKPulse"] or RunService.Heartbeat:Connect(function()
            local character = lplr.Character
            local humanoid = character and getHumanoid(character)
            if humanoid and humanoid.MoveDirection.Magnitude <= 0.01 then
                humanoid:Move(Vector3.new(0.001, 0, 0), true)
            end
        end)
    else
        local connection = moduleConnections["AntiAFKPulse"]
        if connection then
            connection:Disconnect()
            moduleConnections["AntiAFKPulse"] = nil
        end
    end
end

Aether.RegisterModule({
    Name = "Anti-AFK",
    Category = "World",
    Default = false,
    Settings = moduleSettings["Anti-AFK"] or {},
    Start = function(ctx)
        toggleAntiAFK(true)
    end,
    Stop = function(ctx)
        toggleAntiAFK(false)
    end
})
