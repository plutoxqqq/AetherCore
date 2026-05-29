function toggleSongBeats(enabled)
    cleanupModule("Song Beats")
    if not enabled then return end
    local sound = Instance.new("Sound")
    sound.Name = "AetherSongBeats"
    sound.Volume = 0.2
    sound.Parent = Workspace
    moduleRuntime.SongBeatsSound = sound
    addConnection("Song Beats", sound.Ended:Connect(function() end))
    addConnection("Song Beats", RunService.RenderStepped:Connect(function()
        if not moduleStates["Song Beats"] and moduleRuntime.SongBeatsSound then
            moduleRuntime.SongBeatsSound:Destroy()
            moduleRuntime.SongBeatsSound = nil
        end
    end))
end

Aether.RegisterModule({
    Name = "Song Beats",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Song Beats"] or {},
    Start = function(ctx)
        toggleSongBeats(true)
    end,
    Stop = function(ctx)
        toggleSongBeats(false)
    end
})
