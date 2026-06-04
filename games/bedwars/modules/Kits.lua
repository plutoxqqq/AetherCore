-- BedWars Kits module group.
-- Lightweight AetherCore-owned registrations live here; the full compatibility
-- payload is loaded separately by games/bedwars/libraries/loader.lua.
return function(context)
    local vape = shared and shared.vape
    if type(vape) ~= "table" or type(vape.Categories) ~= "table" then
        return false, "GUI categories are unavailable"
    end

    local category = vape.Categories["Kits"] or vape.Categories.Utility
    if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
        return false, "Kits category is unavailable"
    end

    context.BedWars = context.BedWars or {Groups = {}}
    context.BedWars.Groups = context.BedWars.Groups or {}
    context.BedWars.Groups["Kits"] = true

    category:CreateModule({
        Name = "Kit Helper",
        Function = function(callback)
            if callback and type(shared.vape.CreateNotification) == "function" then
                shared.vape:CreateNotification("AetherCore", "Kit Helper enabled", 3)
            end
        end,
        Tooltip = "AetherCore BedWars Kits bridge module."
    })

    return true
end
