moduleSettings["FastBreak"] = {
    cooldown = 0.03,
    attemptsPerPulse = 2
}

function toggleFastBreak(enabled)
    cleanupModule("FastBreak")
    if not enabled then return end

    moduleSettings["FastBreak"].lastBreak = 0
    addConnection("FastBreak", RunService.Heartbeat:Connect(function()
        if not moduleStates["FastBreak"] then return end
        local settings = moduleSettings["FastBreak"]
        local now = tick()
        if now - (settings.lastBreak or 0) < settings.cooldown then return end
        local target = mouse and mouse.Target
        if not target or not target:IsA("BasePart") then return end
        settings.lastBreak = now

        local targetPosition = target.Position
        local damageRemote = getDamageBlockRemote()
        if not damageRemote then return end

        for _ = 1, settings.attemptsPerPulse do
            safeCall("FastBreakDamageRemote", function()
                damageRemote:FireServer({
                    blockRef = {blockPosition = targetPosition},
                    hitPosition = targetPosition,
                    hitNormal = Vector3.new(0, 1, 0)
                })
            end)
        end
    end))
end


Aether.RegisterModule({
    Name = "FastBreak",
    Category = "World",
    Default = false,
    Settings = moduleSettings["FastBreak"] or {},
    Start = function(ctx)
        toggleFastBreak(true)
    end,
    Stop = function(ctx)
        toggleFastBreak(false)
    end
})
