moduleSettings["AutoClicker"] = { cps = 10 }

function toggleAutoClicker(enabled)
    cleanupModule("AutoClicker")
    if not enabled then return end

    local holding = false
    local lastClick = 0

    local conn1 = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = true
        end
    end)
    local conn2 = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            holding = false
        end
    end)
    local conn3 = RunService.Heartbeat:Connect(function()
        if holding and moduleStates["AutoClicker"] then
            local now = tick()
            local delay = 1 / math.clamp(moduleSettings["AutoClicker"].cps, 1, 20)
            if now - lastClick >= delay then
                lastClick = now
                performPrimaryClick()
                local nearest = getTargetByFilters(18, true, false)
                if nearest then
                    attackTargetWithBedwarsApi(nearest)
                end
                local char = getCharacter(lplr)
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then
                    pcall(function() tool:Activate() end)
                end
            end
        end
    end)

    addConnection("AutoClicker", conn1)
    addConnection("AutoClicker", conn2)
    addConnection("AutoClicker", conn3)
end

Aether.RegisterModule({
    Name = "AutoClicker",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["AutoClicker"] or {},
    Start = function(ctx)
        toggleAutoClicker(true)
    end,
    Stop = function(ctx)
        toggleAutoClicker(false)
    end
})
