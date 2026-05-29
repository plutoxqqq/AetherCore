function toggleFastPickup(enabled)
    cleanupModule("FastPickup")
    if not enabled then
        return
    end
    addConnection("FastPickup", RunService.Heartbeat:Connect(function()
        if not moduleStates["FastPickup"] then
            return
        end
        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myHRP then
            return
        end
        local pickupRemote = resolveClientRemote("PickupItemDrop")
        if not pickupRemote then
            return
        end
        local range = math.clamp(tonumber((moduleSettings["FastPickup"] or {}).range) or 14, 4, 30)
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {myChar}
        for _, part in ipairs(Workspace:GetPartBoundsInRadius(myHRP.Position, range, overlapParams)) do
            if part:IsA("BasePart") then
                local parent = part.Parent
                local nameLower = part.Name:lower()
                local parentLower = parent and parent.Name:lower() or ""
                if nameLower:find("drop") or nameLower:find("pickup") or parentLower:find("drop") then
                    pcall(function()
                        pickupRemote:FireServer({itemDrop = parent or part})
                    end)
                end
            end
        end
    end))
end


Aether.RegisterModule({
    Name = "FastPickup",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["FastPickup"] or {},
    Start = function(ctx)
        toggleFastPickup(true)
    end,
    Stop = function(ctx)
        toggleFastPickup(false)
    end
})
