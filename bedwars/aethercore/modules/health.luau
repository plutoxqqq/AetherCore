function toggleHealth(enabled)
    cleanupModule("Health")
    if not enabled then
        if moduleRuntime.HealthLabel then
            moduleRuntime.HealthLabel:Destroy()
            moduleRuntime.HealthLabel = nil
        end
        return
    end

    if not moduleRuntime.HealthLabel then
        local label = Instance.new("TextLabel")
        label.Name = "AetherHealthLabel"
        label.Size = UDim2.fromOffset(120, 24)
        label.Position = UDim2.new(0.5, -60, 1, -120)
        label.BackgroundTransparency = 0.3
        label.BackgroundColor3 = Color3.new(0, 0, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Parent = screenGui
        moduleRuntime.HealthLabel = label
    end

    addConnection("Health", RunService.RenderStepped:Connect(function()
        local character = lplr.Character
        local hp = character and character:GetAttribute("Health")
        local maxHp = character and character:GetAttribute("MaxHealth")
        if moduleRuntime.HealthLabel then
            moduleRuntime.HealthLabel.Text = string.format("%d / %d", math.floor(hp or 0), math.floor(maxHp or 0))
        end
    end))
end

Aether.RegisterModule({
    Name = "Health",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Health"] or {},
    Start = function(ctx)
        toggleHealth(true)
    end,
    Stop = function(ctx)
        toggleHealth(false)
    end
})
