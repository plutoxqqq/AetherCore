function toggleFastDrop(enabled)
    cleanupModule("FastDrop")
    if not enabled then return end
    addConnection("FastDrop", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not moduleStates.FastDrop or input.KeyCode ~= Enum.KeyCode.Backspace then return end
        local dropRemote = getDropItemRemote()
        if dropRemote then
            pcall(function() dropRemote:FireServer({}) end)
        end
    end))
end

Aether.RegisterModule({
    Name = "FastDrop",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["FastDrop"] or {},
    Start = function(ctx)
        toggleFastDrop(true)
    end,
    Stop = function(ctx)
        toggleFastDrop(false)
    end
})
