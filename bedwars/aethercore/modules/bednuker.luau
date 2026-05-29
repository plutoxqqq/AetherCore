moduleSettings["Nuker"] = {
    mineBeds = true,
    mineIron = true,
    mineGold = true,
    mineDiamond = true,
    mineEmerald = true,
    mineRadius = 10
}

function toggleNuker(enabled)
    cleanupModule("Nuker")
    if not enabled then return end

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["Nuker"] then return end
        local settings = moduleSettings["Nuker"]
        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myHRP then return end

        moduleSettings["Nuker"].lastScan = moduleSettings["Nuker"].lastScan or 0
        if tick() - moduleSettings["Nuker"].lastScan < 0.3 then return end
        moduleSettings["Nuker"].lastScan = tick()

        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = {myChar}
        local nearbyParts = Workspace:GetPartBoundsInRadius(myHRP.Position, settings.mineRadius, overlapParams)
        local damageRemote = getDamageBlockRemote()
        if not damageRemote then return end
        local firedPositions = {}

        for _, obj in ipairs(nearbyParts) do
            if obj:IsA("BasePart") then
                local shouldMine = false
                local nameLower = obj.Name:lower()
                if settings.mineBeds and nameLower == "bed" and obj.Parent and obj.Parent.Name ~= lplr.Name then
                    shouldMine = true
                elseif settings.mineIron and nameLower:find("iron") then
                    shouldMine = true
                elseif settings.mineGold and nameLower:find("gold") then
                    shouldMine = true
                elseif settings.mineDiamond and nameLower:find("diamond") then
                    shouldMine = true
                elseif settings.mineEmerald and nameLower:find("emerald") then
                    shouldMine = true
                end

                if shouldMine then
                    local targetPosition = obj.Position
                    local key = string.format("%.3f|%.3f|%.3f", targetPosition.X, targetPosition.Y, targetPosition.Z)
                    if not firedPositions[key] then
                        firedPositions[key] = true
                        safeCall("NukerDamageRemote", function()
                            damageRemote:FireServer({
                                blockRef = {blockPosition = targetPosition},
                                hitPosition = targetPosition,
                                hitNormal = Vector3.new(0, 1, 0)
                            })
                        end)
                    end
                end
            end
        end
    end)
    addConnection("Nuker", connection)
end


function toggleBedNuker(enabled)
    cleanupModule("BedNuker")
    if not enabled then return end
    addConnection("BedNuker", RunService.Heartbeat:Connect(function()
        if not moduleStates["BedNuker"] then return end
        local char = getCharacter(lplr)
        local hrp = getHRP(char)
        if not hrp then return end
        local range = math.max(6, tonumber((moduleSettings["BedNuker"] or {}).range) or 28)
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:lower():find("bed") and obj:IsA("BasePart") and (obj.Position - hrp.Position).Magnitude <= range then
                local remote = getDamageBlockRemote()
                if remote then
                    pcall(function()
                        remote:InvokeServer({blockRef = {blockPosition = obj.Position}})
                    end)
                end
            end
        end
    end))
end


Aether.RegisterModule({
    Name = "BedNuker",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["BedNuker"] or {},
    Start = function(ctx)
        toggleBedNuker(true)
    end,
    Stop = function(ctx)
        toggleBedNuker(false)
    end
})
