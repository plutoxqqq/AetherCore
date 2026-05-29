function toggleKillEffect(enabled)
    cleanupModule("Kill Effect")
    if not enabled then return end
    addConnection("Kill Effect", TextChatService.MessageReceived:Connect(function(msg)
        if not moduleStates["Kill Effect"] then return end
        local text = string.lower(msg.Text or "")
        if text:find("final kill") then
            local effectPart = Instance.new("Part")
            effectPart.Anchored = true
            effectPart.CanCollide = false
            effectPart.Material = Enum.Material.Neon
            effectPart.Color = Color3.fromRGB(170, 120, 255)
            effectPart.Size = Vector3.new(0.6, 0.6, 0.6)
            local root = getHRP(lplr.Character)
            effectPart.Position = root and (root.Position + Vector3.new(0, 4, 0)) or Vector3.zero
            effectPart.Parent = Workspace
            Debris:AddItem(effectPart, 1)
        end
    end))
end

Aether.RegisterModule({
    Name = "Kill Effect",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Kill Effect"] or {},
    Start = function(ctx)
        toggleKillEffect(true)
    end,
    Stop = function(ctx)
        toggleKillEffect(false)
    end
})
