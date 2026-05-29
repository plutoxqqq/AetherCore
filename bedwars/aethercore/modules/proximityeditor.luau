moduleSettings["ProximityEditor"] = {
    holdDuration = 0,
    affectNewPrompts = false
}

function toggleProximityEditor(enabled)
    cleanupModule("ProximityEditor")
    if not enabled then
        return
    end

    local function applyPrompt(prompt)
        if not (prompt and prompt:IsA("ProximityPrompt")) then
            return
        end
        prompt.HoldDuration = math.clamp(tonumber((moduleSettings["ProximityEditor"] or {}).holdDuration) or 0, 0, 5)
    end

    for _, obj in ipairs(game:GetDescendants()) do
        applyPrompt(obj)
    end

    if (moduleSettings["ProximityEditor"] or {}).affectNewPrompts then
        addConnection("ProximityEditor", game.DescendantAdded:Connect(function(obj)
            if not moduleStates["ProximityEditor"] then
                return
            end
            applyPrompt(obj)
        end))
    end
end

Aether.RegisterModule({
    Name = "ProximityEditor",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["ProximityEditor"] or {},
    Start = function(ctx)
        toggleProximityEditor(true)
    end,
    Stop = function(ctx)
        toggleProximityEditor(false)
    end
})
