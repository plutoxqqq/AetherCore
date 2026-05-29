function toggleBedPlates(enabled)
    cleanupModule("BedPlates")
    if not enabled then
        for _, taggedBed in ipairs(CollectionService:GetTagged("bed")) do
            local existing = taggedBed:FindFirstChild("AetherBedPlate")
            if existing then existing:Destroy() end
        end
        return
    end

    local function decorate(bed)
        if not bed:IsA("BasePart") and not bed:IsA("Model") then return end
        if bed:FindFirstChild("AetherBedPlate") then return end
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "AetherBedPlate"
        billboard.Size = UDim2.fromOffset(130, 24)
        billboard.AlwaysOnTop = true
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
        billboard.Parent = bed

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 0.35
        label.BackgroundColor3 = Color3.new(0, 0, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = "Bed"
        label.Parent = billboard
    end

    for _, bed in ipairs(CollectionService:GetTagged("bed")) do decorate(bed) end
    addConnection("BedPlates", CollectionService:GetInstanceAddedSignal("bed"):Connect(decorate))
end

Aether.RegisterModule({
    Name = "BedPlates",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["BedPlates"] or {},
    Start = function(ctx)
        toggleBedPlates(true)
    end,
    Stop = function(ctx)
        toggleBedPlates(false)
    end
})
