function toggleFPSBoost(enabled)
    cleanupModule("FPSBoost")
    if enabled then
        Workspace.GlobalShadows = false
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    else
        Workspace.GlobalShadows = true
    end
end


Aether.RegisterModule({
    Name = "FPS Boost",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["FPS Boost"] or {},
    Start = function(ctx)
        toggleFPSBoost(true)
    end,
    Stop = function(ctx)
        toggleFPSBoost(false)
    end
})
