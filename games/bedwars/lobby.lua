-- BedWars lobby entry.
-- Lobby and match places share the BedWars controller so users never receive an
-- empty payload when Roblox routes them through the BedWars lobby.
return function(context)
    return context.LoadGameModule("games/bedwars/main.luau")
end
