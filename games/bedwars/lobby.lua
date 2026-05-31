-- BedWars lobby entry.
-- The current module set is shared with the in-match payload so lobby users keep
-- the same feature list instead of receiving an empty module page.
return function(context)
    return context.LoadGameModule("games/bedwars/main.lua")
end
