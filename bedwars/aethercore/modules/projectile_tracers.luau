moduleSettings["Tracers"] = { transparency = 0.5 }

function clearTracerArtifacts()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Beam") and obj.Name == "TracerBeam" then
            obj:Destroy()
        elseif obj:IsA("Attachment") and (obj.Name == "TracerAttach0" or obj.Name == "TracerAttach1") then
            obj:Destroy()
        elseif obj:IsA("Part") and obj.Name == "TracerAnchorPart" then
            obj:Destroy()
        end
    end
end

function toggleTracers(enabled)
    cleanupModule("Tracers")
    if not enabled then
        clearTracerArtifacts()
        return
    end
    clearTracerArtifacts()

    local function createTracerForModel(model)
        if not model or model:FindFirstChild("TracerBeam") then return end
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if not head then return end

        local anchorPart = Instance.new("Part")
        anchorPart.Name = "TracerAnchorPart"
        anchorPart.Size = Vector3.new(0.2, 0.2, 0.2)
        anchorPart.Transparency = 1
        anchorPart.Anchored = true
        anchorPart.CanCollide = false
        anchorPart.CanQuery = false
        anchorPart.CanTouch = false
        anchorPart.CFrame = camera.CFrame
        anchorPart.Parent = model

        local attach0 = Instance.new("Attachment")
        attach0.Name = "TracerAttach0"
        attach0.Parent = anchorPart

        local attach1 = Instance.new("Attachment")
        attach1.Name = "TracerAttach1"
        attach1.Parent = head

        local beam = Instance.new("Beam")
        beam.Name = "TracerBeam"
        beam.Attachment0 = attach0
        beam.Attachment1 = attach1
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        beam.Transparency = NumberSequence.new(moduleSettings["Tracers"].transparency)
        beam.Width0 = 0.1
        beam.Width1 = 0.1
        beam.Parent = model

        local updateConn = RunService.RenderStepped:Connect(function()
            if not moduleStates["Tracers"] then return end
            if not attach0 or not attach0.Parent then return end
            if not camera then return end
            anchorPart.CFrame = camera.CFrame
            beam.Transparency = NumberSequence.new(moduleSettings["Tracers"].transparency)
        end)
        addConnection("Tracers", updateConn)
    end

    local function scanAndAddTracers()
        if not moduleStates["Tracers"] then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and player.Character then
                createTracerForModel(player.Character)
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
                        createTracerForModel(model)
                    end
                end
            end
        end
    end

    scanAndAddTracers()
    local lastScan = 0
    addConnection("Tracers", RunService.Heartbeat:Connect(function()
        if tick() - lastScan < 0.45 then return end
        lastScan = tick()
        scanAndAddTracers()
    end))
end

Aether.RegisterModule({
    Name = "Tracers",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["Tracers"] or {},
    Start = function(ctx)
        toggleTracers(true)
    end,
    Stop = function(ctx)
        toggleTracers(false)
    end
})
