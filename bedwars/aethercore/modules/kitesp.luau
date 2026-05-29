function toggleKitESP(enabled)
    cleanupModule("KitESP")
    local tags = {"lucky_block", "void_regent", "fisherman_catch"}
    if not enabled then
        for _, tag in ipairs(tags) do
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                local hl = obj:FindFirstChild("AetherKitHL")
                if hl then hl:Destroy() end
            end
        end
        return
    end

    local function mark(obj)
        if not obj:IsA("Model") then return end
        if obj:FindFirstChild("AetherKitHL") then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "AetherKitHL"
        highlight.FillTransparency = 0.7
        highlight.OutlineColor = Color3.fromRGB(255, 170, 0)
        highlight.Adornee = obj
        highlight.Parent = obj
    end

    for _, tag in ipairs(tags) do
        for _, obj in ipairs(CollectionService:GetTagged(tag)) do mark(obj) end
        addConnection("KitESP", CollectionService:GetInstanceAddedSignal(tag):Connect(mark))
    end
end

Aether.RegisterModule({
    Name = "KitESP",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["KitESP"] or {},
    Start = function(ctx)
        toggleKitESP(true)
    end,
    Stop = function(ctx)
        toggleKitESP(false)
    end
})
