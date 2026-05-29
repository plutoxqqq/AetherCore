--// KillAura
-- category: combat
-- purpose: handles nearby target attacking.
moduleSettings["KillAura"] = {
    range = 14,
    fov = 360,
    swingSpeed = 18,
    faceTarget = false,
    requireSword = false,
    attackThroughWalls = true,
    ignoreTeammates = true,

    fovRadius = 360,
    attackPlayers = true,
    attackNPCs = false,
    fallbackToClickSimulation = false,

    targetSwitchDelay = 0.2
}

killAuraLastSwing = 0

function isSwordTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end

    local n = tool.Name:lower()
    return n:find("sword") ~= nil
        or n:find("blade") ~= nil
        or n:find("katana") ~= nil
        or n:find("dao") ~= nil
end

function getHeldSword()
    local char = getCharacter(lplr)
    if not char then
        return nil
    end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool and isSwordTool(tool) then
        return tool
    end

    return nil
end

function getHeldOrBackpackSword()
    local char = getCharacter(lplr)
    if char then
        local heldTool = char:FindFirstChildOfClass("Tool")
        if heldTool and isSwordTool(heldTool) then
            return heldTool
        end
    end

    local backpack = lplr:FindFirstChildOfClass("Backpack")
    if not backpack then
        return nil
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and isSwordTool(tool) then
            return tool
        end
    end

    return nil
end

function getKillAuraTarget(range, settings)
    local myChar = getCharacter(lplr)
    local myHRP = getHRP(myChar)
    if not myHRP then
        return nil
    end

    local bestTarget = nil
    local bestDistance = math.huge

    local function considerTarget(targetChar)
        if not targetChar then
            return
        end

        local hum = getHumanoid(targetChar)
        local root = getHRP(targetChar)
        if not hum or not root or hum.Health <= 0 then
            return
        end

        local distance = (root.Position - myHRP.Position).Magnitude
        if distance > range then
            return
        end

        if not isTargetWithinFov(targetChar, settings.fovRadius or settings.fov or 360) then
            return
        end

        if settings.attackThroughWalls == false and not hasLineOfSight(targetChar) then
            return
        end

        if distance < bestDistance then
            bestDistance = distance
            bestTarget = targetChar
        end
    end

    if settings.attackPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr then
                local sameTeam = player.Team ~= nil and lplr.Team ~= nil and player.Team == lplr.Team
                if not (settings.ignoreTeammates ~= false and sameTeam) then
                    considerTarget(getCharacter(player))
                end
            end
        end
    end

    if settings.attackNPCs then
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model ~= myChar then
                local hum = model:FindFirstChildOfClass("Humanoid")
                local hrp = model:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local isPlayerModel = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Character == model then
                            isPlayerModel = true
                            break
                        end
                    end
                    if not isPlayerModel then
                        considerTarget(model)
                    end
                end
            end
        end
    end

    return bestTarget
end

function toggleKillAura(enabled)
    cleanupModule("KillAura")
    if not enabled then
        return
    end

    local lockedTarget = nil
    local lastTargetSwitch = 0

    local connection = RunService.Heartbeat:Connect(function()
        if not moduleStates["KillAura"] then
            return
        end

        local myChar = getCharacter(lplr)
        local myHRP = getHRP(myChar)
        if not myChar or not myHRP then
            return
        end

        local settings = moduleSettings["KillAura"] or {}
        if not settings.attackPlayers and not settings.attackNPCs then
            return
        end

        local sword = getHeldSword()
        if not sword then
            local backpackSword = getHeldOrBackpackSword()
            if backpackSword then
                equipToolIfNeeded(backpackSword)
                sword = getHeldSword()
            end
        end

        if settings.requireSword and not sword then
            return
        end

        local effectiveRange = getEffectiveCombatRange(settings.range or 14)

        local function isStillValidTarget(targetChar)
            if not targetChar then
                return false
            end

            local hum = getHumanoid(targetChar)
            local root = getHRP(targetChar)
            if not hum or not root or hum.Health <= 0 then
                return false
            end

            if (root.Position - myHRP.Position).Magnitude > effectiveRange then
                return false
            end

            if not isTargetWithinFov(targetChar, settings.fovRadius or settings.fov or 360) then
                return false
            end

            if settings.attackThroughWalls == false and not hasLineOfSight(targetChar) then
                return false
            end

            return true
        end

        if not isStillValidTarget(lockedTarget) then
            lockedTarget = nil
        end

        local now = tick()
        if not lockedTarget or (now - lastTargetSwitch >= (settings.targetSwitchDelay or 0.2)) then
            local newTarget = getKillAuraTarget(effectiveRange, settings)
            if newTarget ~= lockedTarget then
                lockedTarget = newTarget
                lastTargetSwitch = now
            end
        end

        if not lockedTarget then
            return
        end

        local swingDelay = 1 / math.max(settings.swingSpeed or 1, 1)
        if now - killAuraLastSwing < swingDelay then
            return
        end

        if settings.faceTarget then
            faceCharacterTarget(lockedTarget)
        end

        local attacked = attackTargetWithBedwarsApi(lockedTarget)

        if not attacked and sword then
            attacked = safeCall("KillAura_ToolActivate", function()
                sword:Activate()
                return true
            end) or false
        end

        if not attacked and settings.fallbackToClickSimulation then
            attacked = performPrimaryClick() or false
        end

        if attacked then
            killAuraLastSwing = now
        end
    end)

    addConnection("KillAura", connection)
end



Aether.RegisterModule({
    Name = "KillAura",
    Category = "Combat",
    Default = false,
    Settings = moduleSettings["KillAura"] or {},
    Start = function(ctx)
        toggleKillAura(true)
    end,
    Stop = function(ctx)
        toggleKillAura(false)
    end
})
