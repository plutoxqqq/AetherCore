function toggleUICleanup(enabled)
    cleanupModule("UI Cleanup")
    if enabled then
        moduleRuntime.UICleanup = {FogEnd = Lighting.FogEnd, Bloom = Lighting:FindFirstChildOfClass("BloomEffect")}
        Lighting.FogEnd = 100000
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true) end)
    else
        if moduleRuntime.UICleanup then Lighting.FogEnd = moduleRuntime.UICleanup.FogEnd end
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
    end
end

Aether.RegisterModule({
    Name = "UI Cleanup",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["UI Cleanup"] or {},
    Start = function(ctx)
        toggleUICleanup(true)
    end,
    Stop = function(ctx)
        toggleUICleanup(false)
    end
})
