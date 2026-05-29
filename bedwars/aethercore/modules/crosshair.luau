function toggleCrosshair(enabled)
    cleanupModule("Crosshair")
    local current = lplr:GetMouse()
    if enabled then
        moduleRuntime.CrosshairIcon = current.Icon
        current.Icon = "rbxassetid://" .. tostring(moduleSettings.Crosshair.imageId)
    else
        current.Icon = moduleRuntime.CrosshairIcon or ""
    end
end


Aether.RegisterModule({
    Name = "Crosshair",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Crosshair"] or {},
    Start = function(ctx)
        toggleCrosshair(true)
    end,
    Stop = function(ctx)
        toggleCrosshair(false)
    end
})
