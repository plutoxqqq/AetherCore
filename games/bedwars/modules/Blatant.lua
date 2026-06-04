-- BedWars Blatant module group.
-- Lightweight AetherCore-owned registrations live here; the full compatibility
-- payload is loaded separately by games/bedwars/libraries/loader.lua.
return function(context)
    local vape = shared and shared.vape
    if type(vape) ~= "table" or type(vape.Categories) ~= "table" then
        return false, "GUI categories are unavailable"
    end

    local category = vape.Categories["Blatant"] or vape.Categories.Utility
    if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
        return false, "Blatant category is unavailable"
    end

    context.BedWars = context.BedWars or {Groups = {}}
    context.BedWars.Groups = context.BedWars.Groups or {}
    context.BedWars.Groups["Blatant"] = true

    category:CreateModule({
        Name = "Anti Fall Guard",
        Function = function(callback)
            if callback and type(shared.vape.CreateNotification) == "function" then
                shared.vape:CreateNotification("AetherCore", "Anti Fall Guard enabled", 3)
            end
        end,
        Tooltip = "AetherCore BedWars Blatant bridge module."
    })

    category:CreateModule({
        Name = "Movement Watchdog",
        Function = function(callback)
            if callback and type(shared.vape.CreateNotification) == "function" then
                shared.vape:CreateNotification("AetherCore", "Movement Watchdog enabled", 3)
            end
        end,
        Tooltip = "AetherCore BedWars Blatant bridge module."
    })

    return true
end
