function toggleSprint(enabled)
    cleanupModule("Sprint")
    local function restoreSprint(char)
        local hum = getHumanoid(char)
        if not hum then return end
        local defaultSpeed = hum:GetAttribute("AetherDefaultWalkSpeed")
        hum:SetAttribute("AetherSprintEnabled", false)
        hum.WalkSpeed = type(defaultSpeed) == "number" and defaultSpeed or 16
    end
    if not enabled then
        restoreSprint(getCharacter(lplr))
        return
    end
    local function primeSprint(char)
        local hum = getHumanoid(char)
        if not hum then return end
        if type(hum:GetAttribute("AetherDefaultWalkSpeed")) ~= "number" then
            hum:SetAttribute("AetherDefaultWalkSpeed", hum.WalkSpeed)
        end
        hum:SetAttribute("AetherSprintEnabled", true)
    end
    addConnection("Sprint", RunService.Heartbeat:Connect(function()
        if not moduleStates["Sprint"] then return end
        local char = getCharacter(lplr)
        local hum = getHumanoid(char)
        if not hum or hum.Health <= 0 then return end
        if type(hum:GetAttribute("AetherDefaultWalkSpeed")) ~= "number" then
            hum:SetAttribute("AetherDefaultWalkSpeed", hum.WalkSpeed)
        end
        local baseSpeed = hum:GetAttribute("AetherDefaultWalkSpeed") or 16
        local target = hum.MoveDirection.Magnitude > 0 and math.max(baseSpeed, 16) or baseSpeed
        if hum.WalkSpeed ~= target then
            hum.WalkSpeed = target
        end
    end))
    primeSprint(getCharacter(lplr))
    addConnection("Sprint", lplr.CharacterAdded:Connect(function()
        task.defer(function()
            local char = getCharacter(lplr)
            primeSprint(char)
            restoreSprint(char)
        end)
    end))
end


Aether.RegisterModule({
    Name = "Sprint",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["Sprint"] or {},
    Start = function(ctx)
        toggleSprint(true)
    end,
    Stop = function(ctx)
        toggleSprint(false)
    end
})
