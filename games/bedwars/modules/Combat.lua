-- BedWars Combat module group.
-- Lightweight AetherCore-owned registrations live here; the full compatibility
-- payload is loaded separately by games/bedwars/libraries/loader.lua.
return function(context)
    local vape = shared and shared.vape
    if type(vape) ~= "table" or type(vape.Categories) ~= "table" then
        return false, "GUI categories are unavailable"
    end

    local category = vape.Categories["Combat"] or vape.Categories.Utility
    if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
        return false, "Combat category is unavailable"
    end

    context.BedWars = context.BedWars or {Groups = {}}
    context.BedWars.Groups = context.BedWars.Groups or {}
    context.BedWars.Groups["Combat"] = true

    category:CreateModule({
        Name = "Aim Assist",
        Function = function(callback)
            if callback and type(shared.vape.CreateNotification) == "function" then
                shared.vape:CreateNotification("AetherCore", "Aim Assist enabled", 3)
            end
        end,
        Tooltip = "AetherCore BedWars Combat bridge module."
    })

    category:CreateModule({
        Name = "Auto Clicker",
        Function = function(callback)
            if callback and type(shared.vape.CreateNotification) == "function" then
                shared.vape:CreateNotification("AetherCore", "Auto Clicker enabled", 3)
            end
        end,
        Tooltip = "AetherCore BedWars Combat bridge module."
    })

    category:CreateModule({
        Name = "Reach Monitor",
        Function = function(callback)
            if callback and type(shared.vape.CreateNotification) == "function" then
                shared.vape:CreateNotification("AetherCore", "Reach Monitor enabled", 3)
            end
        end,
        Tooltip = "AetherCore BedWars Combat bridge module."
    })

    return true
end
