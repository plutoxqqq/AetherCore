function toggleBedBreakEffect(enabled)
    cleanupModule("Bed Break Effect")
    if not enabled then return end
    addConnection("Bed Break Effect", TextChatService.MessageReceived:Connect(function(msg)
        if not moduleStates["Bed Break Effect"] then return end
        if string.lower(msg.Text or ""):find("bed") and string.lower(msg.Text or ""):find("broken") then
            local root = getHRP(lplr.Character)
            if root then
                local emitter = Instance.new("ParticleEmitter")
                emitter.Rate = 200
                emitter.Lifetime = NumberRange.new(0.4)
                emitter.Speed = NumberRange.new(10)
                emitter.Parent = root
                Debris:AddItem(emitter, 0.5)
            end
        end
    end))
end

Aether.RegisterModule({
    Name = "Bed Break Effect",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Bed Break Effect"] or {},
    Start = function(ctx)
        toggleBedBreakEffect(true)
    end,
    Stop = function(ctx)
        toggleBedBreakEffect(false)
    end
})
