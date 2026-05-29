function toggleWinEffect(enabled)
    cleanupModule("WinEffect")
    if not enabled then return end
    addConnection("WinEffect", TextChatService.MessageReceived:Connect(function(msg)
        local text = string.lower(msg.Text or "")
        if text:find("victory") and lplr.Character and getHRP(lplr.Character) then
            local p = Instance.new("ParticleEmitter")
            p.Texture = "rbxassetid://296874871"
            p.Lifetime = NumberRange.new(1.2)
            p.Rate = 150
            p.Speed = NumberRange.new(7,12)
            p.Parent = getHRP(lplr.Character)
            Debris:AddItem(p, 2)
        end
    end))
end

Aether.RegisterModule({
    Name = "WinEffect",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["WinEffect"] or {},
    Start = function(ctx)
        toggleWinEffect(true)
    end,
    Stop = function(ctx)
        toggleWinEffect(false)
    end
})
