moduleSettings["HitBoxes"] = {
    expand = 2.5,
    transparency = 0.75
}

local function restoreHitBox(character)
    local runtime = moduleRuntime.HitBoxes and moduleRuntime.HitBoxes[character]
    local root = getHRP(character)
    if root and runtime then
        root.Size = runtime.Size
        root.Transparency = runtime.Transparency
        root.CanCollide = runtime.CanCollide
    end
    if moduleRuntime.HitBoxes then
        moduleRuntime.HitBoxes[character] = nil
    end
end

function toggleHitBoxes(enabled)
    cleanupModule("HitBoxes")
    moduleRuntime.HitBoxes = moduleRuntime.HitBoxes or {}
    for character in pairs(moduleRuntime.HitBoxes) do
        restoreHitBox(character)
    end
    if not enabled then return end

    local function applyHitBox(character)
        if not character or character == getCharacter(lplr) then return end
        local root = getHRP(character)
        local hum = getHumanoid(character)
        if not root or not hum or hum.Health <= 0 then return end
        if not moduleRuntime.HitBoxes[character] then
            moduleRuntime.HitBoxes[character] = {
                Size = root.Size,
                Transparency = root.Transparency,
                CanCollide = root.CanCollide
            }
        end
        local expand = math.clamp(tonumber((moduleSettings["HitBoxes"] or {}).expand) or 2.5, 0, 8)
        root.Size = Vector3.new(2 + expand, 2 + expand, 1 + expand)
        root.Transparency = math.clamp(tonumber((moduleSettings["HitBoxes"] or {}).transparency) or 0.75, 0, 1)
        root.CanCollide = false
    end

    addConnection("HitBoxes", RunService.Heartbeat:Connect(function()
        if not moduleStates["HitBoxes"] then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= lplr and not arePlayersTeammates(lplr, player) then
                applyHitBox(player.Character)
            end
        end
    end))
end

Aether.RegisterModule({
    Name = "HitBoxes",
    Category = "Blatant",
    Default = false,
    Settings = moduleSettings["HitBoxes"] or {},
    Start = function(ctx)
        toggleHitBoxes(true)
    end,
    Stop = function(ctx)
        toggleHitBoxes(false)
    end
})
