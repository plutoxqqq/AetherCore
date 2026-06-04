-- BedWars Render module group.
-- Lightweight AetherCore-owned registrations live here; the full compatibility
-- payload is loaded separately by games/bedwars/libraries/loader.lua.
return function(context)
    local vape = shared and shared.vape
    if type(vape) ~= "table" or type(vape.Categories) ~= "table" then
        return false, "GUI categories are unavailable"
    end

    local category = vape.Categories["Render"] or vape.Categories.Utility
    if type(category) ~= "table" or type(category.CreateModule) ~= "function" then
        return false, "Render category is unavailable"
    end

    context.BedWars = context.BedWars or {Groups = {}}
    context.BedWars.Groups = context.BedWars.Groups or {}
    context.BedWars.Groups["Render"] = true

    category:CreateModule({
        Name = "Interface Branding",
        Function = function(callback)
            if callback and type(shared.vape.CreateNotification) == "function" then
                shared.vape:CreateNotification("AetherCore", "Interface Branding enabled", 3)
            end
        end,
        Tooltip = "AetherCore BedWars Render bridge module."
    })

    category:CreateModule({
        Name = "Target Overlay Bridge",
        Function = function(callback)
            if callback and type(shared.vape.CreateNotification) == "function" then
                shared.vape:CreateNotification("AetherCore", "Target Overlay Bridge enabled", 3)
            end
        end,
        Tooltip = "AetherCore BedWars Render bridge module."
    })

    return true
end
