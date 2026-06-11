-- BedWars lobby entrypoint.
-- This file is loaded only when the current Roblox PlaceId is the BedWars
-- lobby, so match-specific modules stay out of the lobby.
return function(context)
    context.BedWars = context.BedWars or {}
    context.BedWars.IsLobby = true
    context.BedWars.IsMatch = false

    if type(shared) == "table" and type(shared.vape) == "table" and type(shared.vape.CreateNotification) == "function" then
        pcall(function()
            shared.vape:CreateNotification("AetherCore", "BedWars lobby loaded. Match modules will load in-game.", 5)
        end)
    end

    return true
end
