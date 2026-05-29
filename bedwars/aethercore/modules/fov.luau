function toggleFOV(enabled)
    cleanupModule("FOV")
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if enabled then
        moduleRuntime.FOVOriginal = cam.FieldOfView
        cam.FieldOfView = moduleSettings.FOV.value
    else
        cam.FieldOfView = moduleRuntime.FOVOriginal or 70
    end
end


Aether.RegisterModule({
    Name = "FOV",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["FOV"] or {},
    Start = function(ctx)
        toggleFOV(true)
    end,
    Stop = function(ctx)
        toggleFOV(false)
    end
})
