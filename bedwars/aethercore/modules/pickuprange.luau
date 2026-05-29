moduleSettings["PickupRange"] = {
    range = 24,
    feetCheck = false,
    networkPull = true
}

function togglePickupRange(enabled)
    cleanupModule("PickupRange")
    if not enabled then return end
    addConnection("PickupRange", task.spawn(function()
        while moduleStates["PickupRange"] do
            local char = getCharacter(lplr)
            local root = getHRP(char)
            if root then
                local settings = moduleSettings["PickupRange"] or {}
                local range = math.clamp(tonumber(settings.range) or 24, 4, 40)
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    local lowered = obj.Name:lower()
                    if (lowered:find("item", 1, true) or lowered:find("drop", 1, true) or CollectionService:HasTag(obj, "ItemDrop")) then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part and (part.Position - root.Position).Magnitude <= range then
                            local targetPosition = settings.feetCheck and (root.Position - Vector3.new(0, 2.8, 0)) or root.Position
                            if settings.networkPull ~= false then
                                pcall(function()
                                    part:SetNetworkOwner(lplr)
                                end)
                            end
                            part.CFrame = CFrame.new(targetPosition)
                            part.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end))
end

Aether.RegisterModule({
    Name = "PickupRange",
    Category = "Utility",
    Default = false,
    Settings = moduleSettings["PickupRange"] or {},
    Start = function(ctx)
        togglePickupRange(true)
    end,
    Stop = function(ctx)
        togglePickupRange(false)
    end
})
