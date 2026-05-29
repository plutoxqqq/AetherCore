function toggleNameTags(enabled)
    cleanupModule("NameTags")
    if not enabled then return end
    local tags = {}
    local function clearTag(plr)
        if tags[plr] then
            tags[plr]:Destroy()
            tags[plr] = nil
        end
    end
    addConnection("NameTags", RunService.Heartbeat:Connect(function()
        if not moduleStates["NameTags"] then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lplr and plr.Character then
                local head = plr.Character:FindFirstChild("Head")
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local root = getHRP(plr.Character)
                if head and hum and root then
                    local bb = tags[plr]
                    if not bb then
                        bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.fromOffset(220, 34)
                        bb.AlwaysOnTop = true
                        bb.StudsOffset = Vector3.new(0, 2.5, 0)
                        bb.Adornee = head
                        local label = Instance.new("TextLabel")
                        label.Name = "Label"
                        label.Size = UDim2.fromScale(1, 1)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.GothamBold
                        label.TextScaled = true
                        label.Parent = bb
                        bb.Parent = head
                        tags[plr] = bb
                    end
                    local dist = math.floor((root.Position - camera.CFrame.Position).Magnitude / 3)
                    local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    local r = math.floor(255 * (1 - hpRatio))
                    local g = math.floor(255 * hpRatio)
                    local tool = plr.Character:FindFirstChildOfClass("Tool")
                    local item = tool and (" | " .. tool.Name) or ""
                    bb.Label.TextColor3 = Color3.fromRGB(r, g, 40)
                    bb.Label.Text = string.format("%s [%d❤] [%db]%s", plr.DisplayName, math.floor(hum.Health), dist, item)
                else
                    clearTag(plr)
                end
            else
                clearTag(plr)
            end
        end
    end))
end

Aether.RegisterModule({
    Name = "NameTags",
    Category = "Render",
    Default = false,
    Settings = moduleSettings["NameTags"] or {},
    Start = function(ctx)
        toggleNameTags(true)
    end,
    Stop = function(ctx)
        toggleNameTags(false)
    end
})
