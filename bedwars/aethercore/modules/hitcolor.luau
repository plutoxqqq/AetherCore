function toggleHitColor(enabled)
    cleanupModule("HitColor")
    if not enabled then return end
    addConnection("HitColor", RunService.Heartbeat:Connect(function()
        if not moduleStates["Hit Color"] then return end
        local settings = moduleSettings["HitColor"] or {}
        local color = Color3.new(settings.r or 1, settings.g or 0, settings.b or 0)
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "_DamageHighlight_" then
                obj.FillColor = color
                obj.FillTransparency = settings.a or 0.4
            end
        end
    end))
end


Aether.RegisterModule({
    Name = "Hit Color",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Hit Color"] or {},
    Start = function(ctx)
        toggleHitColor(true)
    end,
    Stop = function(ctx)
        toggleHitColor(false)
    end
})
