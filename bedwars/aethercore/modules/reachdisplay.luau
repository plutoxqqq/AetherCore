function toggleReachDisplay(enabled)
    cleanupModule("Reach Display")
    if not enabled then
        if moduleRuntime.ReachDisplayLabel then
            moduleRuntime.ReachDisplayLabel:Destroy()
            moduleRuntime.ReachDisplayLabel = nil
        end
        return
    end

    local label = Instance.new("TextLabel")
    label.Name = "AetherReachDisplay"
    label.Size = UDim2.fromOffset(110, 24)
    label.Position = UDim2.new(0.5, -55, 1, -90)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundTransparency = 0.35
    label.BackgroundColor3 = Color3.new(0, 0, 0)
    label.Parent = screenGui
    moduleRuntime.ReachDisplayLabel = label

    addConnection("Reach Display", RunService.RenderStepped:Connect(function()
        local hit = mouse.Target
        local root = getHRP(lplr.Character)
        if moduleRuntime.ReachDisplayLabel then
            local distance = (hit and root) and (hit.Position - root.Position).Magnitude or 0
            moduleRuntime.ReachDisplayLabel.Text = string.format("%.2f studs", distance)
        end
    end))
end

Aether.RegisterModule({
    Name = "Reach Display",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Reach Display"] or {},
    Start = function(ctx)
        toggleReachDisplay(true)
    end,
    Stop = function(ctx)
        toggleReachDisplay(false)
    end
})
