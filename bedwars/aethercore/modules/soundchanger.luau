function toggleSoundChanger(enabled)
    cleanupModule("SoundChanger")
    if not enabled then return end
    addConnection("SoundChanger", RunService.Heartbeat:Connect(function()
        if not moduleStates.SoundChanger then return end
    end))
end

Aether.RegisterModule({
    Name = "SoundChanger",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["SoundChanger"] or {},
    Start = function(ctx)
        toggleSoundChanger(true)
    end,
    Stop = function(ctx)
        toggleSoundChanger(false)
    end
})
