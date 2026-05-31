-- Shared target-selection helpers; game modules decide when to use them.
local Target = {}

function Target.IsAlive(player)
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

function Target.GetNearest(players, origin, maxDistance)
    local nearest, nearestDistance = nil, maxDistance or math.huge
    for _, player in ipairs(players or {}) do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and Target.IsAlive(player) then
            local distance = (root.Position - origin).Magnitude
            if distance < nearestDistance then
                nearest, nearestDistance = player, distance
            end
        end
    end
    return nearest, nearestDistance
end

return Target
