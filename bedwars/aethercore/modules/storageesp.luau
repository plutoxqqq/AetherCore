function toggleStorageESP(enabled)
    cleanupModule("StorageESP")
    if not enabled then
        for _, chest in ipairs(CollectionService:GetTagged("chest")) do
            local hl = chest:FindFirstChild("AetherStorageHL")
            if hl then hl:Destroy() end
        end
        return
    end

    local function mark(obj)
        if not obj:IsA("Model") then return end
        if obj:FindFirstChild("AetherStorageHL") then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "AetherStorageHL"
        highlight.FillTransparency = 0.7
        highlight.OutlineColor = Color3.fromRGB(0, 255, 255)
        highlight.Adornee = obj
        highlight.Parent = obj
    end

    for _, chest in ipairs(CollectionService:GetTagged("chest")) do mark(chest) end
    addConnection("StorageESP", CollectionService:GetInstanceAddedSignal("chest"):Connect(mark))
end

Aether.RegisterModule({
    Name = "StorageESP",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["StorageESP"] or {},
    Start = function(ctx)
        toggleStorageESP(true)
    end,
    Stop = function(ctx)
        toggleStorageESP(false)
    end
})
