function toggleViewmodel(enabled)
    cleanupModule("Viewmodel")
    local function applyOffsets()
        local char = lplr.Character
        local hum = char and getHumanoid(char)
        if hum then
            hum.CameraOffset = Vector3.new(moduleSettings.Viewmodel.xOffset, moduleSettings.Viewmodel.yOffset, moduleSettings.Viewmodel.zOffset)
        end
    end
    if enabled then
        applyOffsets()
        addConnection("Viewmodel", RunService.RenderStepped:Connect(applyOffsets))
    else
        local hum = lplr.Character and getHumanoid(lplr.Character)
        if hum then hum.CameraOffset = Vector3.zero end
    end
end


Aether.RegisterModule({
    Name = "Viewmodel",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Viewmodel"] or {},
    Start = function(ctx)
        toggleViewmodel(true)
    end,
    Stop = function(ctx)
        toggleViewmodel(false)
    end
})
