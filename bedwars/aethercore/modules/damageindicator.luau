function toggleDamageIndicator(enabled)
    cleanupModule("Damage Indicator")
    if not enabled then return end
    addConnection("Damage Indicator", Workspace.DescendantAdded:Connect(function(obj)
        if not moduleStates["Damage Indicator"] then return end
        if obj:IsA("TextLabel") and string.find(string.lower(obj.Name), "damage", 1, true) then
            obj.TextColor3 = Color3.fromRGB(255, 90, 90)
            obj.TextStrokeTransparency = 0.15
        end
    end))
end

Aether.RegisterModule({
    Name = "Damage Indicator",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Damage Indicator"] or {},
    Start = function(ctx)
        toggleDamageIndicator(true)
    end,
    Stop = function(ctx)
        toggleDamageIndicator(false)
    end
})
