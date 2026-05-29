function toggleBedESP(enabled)
    cleanupModule("BedESP")
    if not enabled then return end
    local folder = Instance.new("Folder")
    folder.Name = "AetherCoreBedESP"
    folder.Parent = Workspace
    addConnection("BedESP", RunService.Heartbeat:Connect(function()
        if not moduleStates["BedESP"] then return end
        folder:ClearAllChildren()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower() == "bed" then
                local box = Instance.new("BoxHandleAdornment")
                box.Adornee = obj
                box.Size = obj.Size + Vector3.new(0.3, 0.3, 0.3)
                box.AlwaysOnTop = true
                box.ZIndex = 4
                box.Transparency = 0.55
                box.Color3 = Color3.fromRGB(255, 80, 80)
                box.Parent = folder
            end
        end
    end))
end

Aether.RegisterModule({
    Name = "BedESP",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["BedESP"] or {},
    Start = function(ctx)
        toggleBedESP(true)
    end,
    Stop = function(ctx)
        toggleBedESP(false)
    end
})
