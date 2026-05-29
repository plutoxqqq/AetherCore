function toggleCleanKit(enabled)
    cleanupModule("Clean Kit")
    if enabled then
        local gui = lplr:FindFirstChildOfClass("PlayerGui")
        if gui then
            local wind = gui:FindFirstChild("WindWalkerEffect", true)
            if wind and wind:IsA("GuiObject") then
                wind.Visible = false
            end
        end
    end
end

Aether.RegisterModule({
    Name = "Clean Kit",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Clean Kit"] or {},
    Start = function(ctx)
        toggleCleanKit(true)
    end,
    Stop = function(ctx)
        toggleCleanKit(false)
    end
})
