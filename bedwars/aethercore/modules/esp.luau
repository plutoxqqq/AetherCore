function toggleESP(enabled)
    cleanupModule("ESP")
    if not enabled then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "ESP_Highlight" then
                obj:Destroy()
            end
        end
        return
    end

    local function removeESPFromModel(model)
        if not model then return end
        local old = model:FindFirstChild("ESP_Highlight")
        if old then
            old:Destroy()
        end
    end

    local function shouldHighlightModel(model)
        if not model then
            return false
        end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            return false
        end
        return true
    end

    local function addESPtoModel(model)
        if not shouldHighlightModel(model) then
            removeESPFromModel(model)
            return
        end
        if model:FindFirstChild("ESP_Highlight") then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = model
        highlight.Parent = model
    end

    local function scanAndAddESP()
        if not moduleStates["ESP"] then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                addESPtoModel(player.Character)
            end
        end

        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local isPlayerChar = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then isPlayerChar = true break end
                    end
                    if not isPlayerChar then
                        addESPtoModel(model)
                    end
                else
                    removeESPFromModel(model)
                end
            end
        end
    end

    scanAndAddESP()
    addConnection("ESP", Players.PlayerAdded:Connect(function(player)
        addConnection("ESP", player.CharacterAdded:Connect(function(character)
            if moduleStates["ESP"] then
                addESPtoModel(character)
            end
        end))
    end))
    addConnection("ESP", Players.PlayerRemoving:Connect(function(player)
        if player.Character then
            removeESPFromModel(player.Character)
        end
    end))
    local lastScan = 0
    addConnection("ESP", RunService.Heartbeat:Connect(function()
        if tick() - lastScan < 0.45 then return end
        lastScan = tick()
        scanAndAddESP()
    end))
end

Aether.RegisterModule({
    Name = "ESP",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["ESP"] or {},
    Start = function(ctx)
        toggleESP(true)
    end,
    Stop = function(ctx)
        toggleESP(false)
    end
})
