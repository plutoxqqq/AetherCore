-- Entity helpers are intentionally shared-only; game modules own game-specific logic.
local Entity = {}

function Entity.GetLocalPlayer()
    return game:GetService("Players").LocalPlayer
end

function Entity.GetCharacter(player)
    player = player or Entity.GetLocalPlayer()
    return player and player.Character or nil
end

function Entity.GetRootPart(character)
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

function Entity.GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

return Entity
