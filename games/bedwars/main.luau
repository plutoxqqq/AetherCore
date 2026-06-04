-- AetherCore BedWars game controller.
-- This file intentionally stays small: it prepares BedWars helpers, then loads
-- logical module groups plus the compatibility payload that preserves existing
-- AetherCore BedWars features.
return function(context)
    local loader = context.RunFunctionModule("games/bedwars/libraries/loader.lua")
    if type(loader) ~= "table" or type(loader.Load) ~= "function" then
        return false, "BedWars loader library did not return a Load function"
    end
    return loader.Load(context)
end
